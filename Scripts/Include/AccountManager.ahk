;===============================================================================
; AccountManager.ahk - Account Management Functions
;===============================================================================
; This file contains functions for managing game accounts.
; These functions handle:
;   - Loading accounts from XML files into the game
;   - Saving accounts from the game to XML files
;   - Account metadata management (mission flags, pack counts)
;   - Creating and managing account queue lists
;   - Tracking used accounts to prevent re-use
;   - Cleaning up stale account tracking data
;   - Updating account filenames with pack counts
;
; Dependencies: ADB.ahk (for device communication), Utils.ahk (for sorting)
; Used by: Main bot loop for account injection and management
;===============================================================================

;-------------------------------------------------------------------------------
; loadAccount - Load an account XML file into the game
;-------------------------------------------------------------------------------
loadAccount() {
    global botConfig, session

    session.get("missionDoneList")["beginnerMissionsDone"] := 0
    session.get("missionDoneList")["soloBattleMissionDone"] := 0
    session.get("missionDoneList")["intermediateMissionsDone"] := 0
    session.get("missionDoneList")["specialMissionsDone"] := 0
    session.get("missionDoneList")["accountHasPackInTesting"] := 0
    session.get("missionDoneList")["receivedGiftDone"] := 0

    if (session.get("stopToggle")) {
        CreateStatusMessage("Stopping...",,,, false)
        ExitApp
    }

    CreateStatusMessage("Loading account...",,,, false)

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    session.set("loadDir", saveDir)
    outputTxt := saveDir . "\list_current.txt"

    session.set("accountFileName", "")
    session.set("accountOpenPacks", 0)
    session.set("accountFileNameOrig", "")
    session.set("accountHasPackInfo", 0)
    session.set("currentLoadedAccountIndex", 0)

    if FileExist(outputTxt) {
        cycle := 0
        Loop {
            FileRead, fileContent, %outputTxt%
            fileLines := StrSplit(fileContent, "`n", "`r")

            if (fileLines.MaxIndex() >= 1) {
                CreateStatusMessage("Loading first available account from list: " . cycle . " attempts")
                loadFile := ""
                foundValidAccount := false
                foundIndex := 0

                Loop, % fileLines.MaxIndex() {
                    currentFile := fileLines[A_Index]
                    if (StrLen(currentFile) < 5)
                        continue

                    testFile := saveDir . "\" . currentFile
                    if (!FileExist(testFile))
                        continue

                    if (!InStr(currentFile, "xml"))
                        continue

                    loadFile := testFile
                    session.set("accountFileName", currentFile)
                    foundValidAccount := true
                    foundIndex := A_Index
                    session.set("currentLoadedAccountIndex", A_Index)
                    break
                }

				if(InStr(fileLines[1], "T")) {
					; account has a pack under test

				}
				if (accountModifiedTimeDiff >= 24){
					if(!InStr(fileLines[1], "T") || accountModifiedTimeDiff >= 5*24) {
						; otherwise account has a pack under test
						session.set("accountFileName", fileLines[1])
						break
					}
				}

                if (foundValidAccount)
                    break

                cycle++

                if (cycle > 5) {  ; Reduced from 10 to 5 for faster failure
                    LogToFile("No valid accounts found in list_current.txt after " . cycle . " attempts")
                    return false
                }

                ; Reduced delay between attempts
                Sleep, 500  ; Reduced from Delay(1) which could be 250ms+
            } else {
                LogToFile("list_current.txt is empty or doesn't exist")
                return false
            }
        }
    } else {
        LogToFile("list_current.txt file doesn't exist")
        return false
    }

    CreateStatusMessage("Closing Pocket App.",,,, false, true)
    closePTCGPApp()
    Sleep, 50
    clearMissionCache()
    Sleep, 100

    RunWait, % session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort") . " push " . loadFile . " /sdcard/deviceAccount.xml",, Hide
    CreateStatusMessage("Injecting: " . session.get("accountFileName"),,,, false)
    adbWriteRaw("cp /sdcard/deviceAccount.xml /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml")
    adbWriteRaw("rm -f /sdcard/deviceAccount.xml")
    Sleep, 100
    ; Reliably restart the app: Wait for launch, and start in a clean, new task without animation.
    startPTCGPApp()
    ; Parse account filename for pack info (unchanged)
    if (InStr(session.get("accountFileName"), "P")) {
        accountFileNameParts := StrSplit(session.get("accountFileName"), "P")
        session.set("accountOpenPacks", accountFileNameParts[1])
        session.set("accountHasPackInfo", 1)
    } else {
        session.set("accountFileNameOrig", session.get("accountFileName"))
    }

    getMetaData()

    return loadFile
}

;-------------------------------------------------------------------------------
; MarkAccountAsUsed - Mark account as successfully used and remove from queue
;-------------------------------------------------------------------------------
MarkAccountAsUsed() {
    global session

    if (!session.get("currentLoadedAccountIndex") || !session.get("accountFileName")) {
        LogToFile("Warning: MarkAccountAsUsed called but no current account tracked")
        return
    }

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    outputTxt := saveDir . "\list_current.txt"

    ; Remove the account from list_current.txt
    if FileExist(outputTxt) {
        FileRead, fileContent, %outputTxt%
        fileLines := StrSplit(fileContent, "`n", "`r")

        newListContent := ""
        Loop, % fileLines.MaxIndex() {
            if (A_Index != session.get("currentLoadedAccountIndex"))
                newListContent .= fileLines[A_Index] "`r`n"
        }

        FileDelete, %outputTxt%
        FileAppend, %newListContent%, %outputTxt%
    }

    ; Track as used with timestamp
    TrackUsedAccount(session.get("accountFileName"))

    ; Reset tracking
    session.set("currentLoadedAccountIndex", 0)
}

;-------------------------------------------------------------------------------
; saveAccount - Save current account from game to XML file
;-------------------------------------------------------------------------------
saveAccount(file := "Valid", ByRef filePath := "", packDetails := "", addWFlag := false) {
    global session, Debug

    filePath := ""
    xmlFile := ""  ; Initialize xmlFile for all branches

    if (file = "All") {
        metadata := ""
        if(session.get("missionDoneList")["beginnerMissionsDone"])
            metadata .= "B"
        if(session.get("missionDoneList")["soloBattleMissionDone"])
            metadata .= "S"
        if(session.get("missionDoneList")["intermediateMissionsDone"])
            metadata .= "I"
        if(session.get("missionDoneList")["specialMissionsDone"])
            metadata .= "X"
        if(session.get("missionDoneList")["accountHasPackInTesting"])
            metadata .= "T"
        if(session.get("missionDoneList")["receivedGiftDone"])
            metadata .= "R"

        saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")

        ; Create filename components
        timestamp := A_Now
        xmlFile := session.get("accountOpenPacks") . "P_" . timestamp . "_" . session.get("scriptName") . "(" . metadata . ").xml"
        filePath := saveDir . "\" . xmlFile

    } else if (file = "Valid" || file = "Invalid") {
        saveDir := A_ScriptDir "\..\Accounts\GodPacks\"
        xmlFile := A_Now . "_" . session.get("scriptName") . "_" . file . "_" . session.get("packsInPool") . "_packs.xml"
        filePath := saveDir . xmlFile

    } else if (file = "Tradeable") {
        saveDir := A_ScriptDir "\..\Accounts\Trades\"
        xmlFile := A_Now . "_" . session.get("scriptName") . (packDetails ? "_" . packDetails : "") . "_" . session.get("packsInPool") . "_packs.xml"
        filePath := saveDir . xmlFile

    } else {
        saveDir := A_ScriptDir "\..\Accounts\SpecificCards\"
        xmlFile := A_Now . "_" . session.get("scriptName") . "_" . file . "_" . session.get("packsInPool") . "_packs.xml"
        filePath := saveDir . xmlFile
    }

    if !FileExist(saveDir) ; Check if the directory exists
        FileCreateDir, %saveDir% ; Create the directory if it doesn't exist

    count := 0
    Loop {
        if (Debug)
            CreateStatusMessage("Attempting to save account - " . count . "/10")
        else
            CreateStatusMessage("Saving account...",,,, false)

        adbWriteRaw("cp -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")
        waitadb()
        Sleep, 500

        RunWait, % session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort") . " pull /sdcard/deviceAccount.xml """ . filePath,, Hide

        Sleep, 500

        adbWriteRaw("rm -f /sdcard/deviceAccount.xml")

        Sleep, 500

        FileGetSize, OutputVar, %filePath%

        if(OutputVar > 0)
            break

        if(count > 10 && file != "All") {
            CreateStatusMessage("Account not saved. Pausing...",,,, false)
            LogToDiscord("Attempted to save account in " . session.get("scriptName") . " but was unsuccessful. Pausing. You will need to manually extract.", Screenshot(), true)
            Pause, On
        }
        count++
    }

    ;Add metrics tracking whenever desired card is found
    now := A_NowUTC
    IniWrite, %now%, % session.get("scriptIniFile"), Metrics, LastEndTimeUTC
    EnvSub, now, 1970, seconds
    IniWrite, %now%, % session.get("scriptIniFile"), Metrics, LastEndEpoch

    return xmlFile  ; Now returns the filename for all branches
}

;-------------------------------------------------------------------------------
; TrackUsedAccount - Track account as used with timestamp
;-------------------------------------------------------------------------------
TrackUsedAccount(fileName) {
    global session
    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    usedAccountsLog := saveDir . "\used_accounts.txt"

    ; Append with timestamp only (no epoch needed)
    currentTime := A_Now
    FileAppend, % fileName . "|" . currentTime . "`n", %usedAccountsLog%
}

;-------------------------------------------------------------------------------
; CleanupUsedAccounts - Remove stale used account tracking data
;-------------------------------------------------------------------------------
CleanupUsedAccounts() {
    global botConfig, session
    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    usedAccountsLog := saveDir . "\used_accounts.txt"

    if (!FileExist(usedAccountsLog)) {
        return
    }

    ; Read current used accounts
    FileRead, usedAccountsContent, %usedAccountsLog%
    if (!usedAccountsContent) {
        return
    }

    ; Calculate current time for comparison (24 hours ago instead of 48)
    cutoffTime := A_Now
    cutoffTime += -24, Hours  ; Reduced from 48 to 24 hours

    ; Keep accounts used within last 24 hours
    cleanedContent := ""
    removedCount := 0
    keptCount := 0

    ; Also check if the account files still exist
    Loop, Parse, usedAccountsContent, `n, `r
    {
        if (!A_LoopField)
            continue

        parts := StrSplit(A_LoopField, "|")
        if (parts.Length() >= 2) {
            fileName := parts[1]
            timestamp := parts[2]

            ; Check if account file still exists
            accountFilePath := saveDir . "\" . fileName
            if (!FileExist(accountFilePath)) {
                removedCount++
                if(botConfig.get("verboseLogging"))
                    LogToFile("Removed used account entry (file no longer exists): " . fileName)
                continue
            }

            ; Compare timestamps directly (YYYYMMDDHHMISS format)
            if (timestamp > cutoffTime) {
                ; Account was used within last 24 hours, keep it
                cleanedContent .= A_LoopField . "`n"
                keptCount++
            } else {
                ; Account is older than 24 hours, remove it
                removedCount++
                if(botConfig.get("verboseLogging"))
                    LogToFile("Removed stale used account: " . fileName . " (used: " . timestamp . ")")
            }
        }
    }

    ; Always rewrite the file to update it
    FileDelete, %usedAccountsLog%
    if (cleanedContent) {
        FileAppend, %cleanedContent%, %usedAccountsLog%
    }

    if(botConfig.get("verboseLogging") && removedCount > 0)
        LogToFile("Cleaned up used accounts: kept " . keptCount . ", removed " . removedCount)
}

;-------------------------------------------------------------------------------
; UpdateAccount - Update account filename with pack count
;-------------------------------------------------------------------------------
UpdateAccount() {
    global session

    accountOpenPacksStr := session.get("accountOpenPacks")
    if(session.get("accountOpenPacks") < 10)
        accountOpenPacksStr := "0" . session.get("accountOpenPacks") ; add a trailing 0 for sorting

    if(InStr(session.get("accountFileName"), "P")){
        accountFileNameParts := StrSplit(session.get("accountFileName"), "P")  ; Split at P
        AccountNewName := accountOpenPacksStr . "P" . accountFileNameParts[2]
    } else if (session.get("ocrSuccess"))
        AccountNewName := accountOpenPacksStr . "P_" . session.get("accountFileNameOrig")
    else
        return ; if OCR is not successful, don't modify account file

    if(!InStr(session.get("accountFileName"), "P") || session.get("accountOpenPacks") > 0) {
        saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
        session.set("accountFile", saveDir . "\" . session.get("accountFileName"))
        accountNewFile := saveDir . "\" . AccountNewName
        FileMove, % session.get("accountFile"), %accountNewFile% ;TODO enable
        FileSetTime,, %accountNewFile%
        session.set("accountFileName", AccountNewName)
    }

    updateTotalTime()
    
    session.set("VRAMUsage", GetVRAMByScriptName(session.get("scriptName")))
    ; Direct display of metrics rather than calling function
    CreateStatusMessage(generateStatusText(), "AvgRuns", 0, 605, false, true)
}

;-------------------------------------------------------------------------------
; getMetaData - Read metadata flags from account filename
;-------------------------------------------------------------------------------
getMetaData() {
    global session

    session.get("missionDoneList")["beginnerMissionsDone"] := 0
    session.get("missionDoneList")["soloBattleMissionDone"] := 0
    
    session.get("missionDoneList")["intermediateMissionsDone"] := 0
    session.get("missionDoneList")["specialMissionsDone"] := 0
    session.get("missionDoneList")["accountHasPackInTesting"] := 0
    session.get("missionDoneList")["receivedGiftDone"] := 0

    ; check if account file has metadata information
    if(InStr(session.get("accountFileName"), "(")) {
        accountFileNameParts1 := StrSplit(session.get("accountFileName"), "(")  ; Split at (
        if(InStr(accountFileNameParts1[2], ")")) {
            ; has metadata information
            accountFileNameParts2 := StrSplit(accountFileNameParts1[2], ")")  ; Split at )
            metadata := accountFileNameParts2[1]
            if(InStr(metadata, "R"))
                session.get("missionDoneList")["receivedGiftDone"] := 1
            if(InStr(metadata, "B"))
                session.get("missionDoneList")["beginnerMissionsDone"] := 1
            if(InStr(metadata, "S"))
                session.get("missionDoneList")["soloBattleMissionDone"] := 1
            if(InStr(metadata, "I"))
                session.get("missionDoneList")["intermediateMissionsDone"] := 1
            if(InStr(metadata, "X"))
                session.get("missionDoneList")["specialMissionsDone"] := 1
            if(InStr(metadata, "T")) {
                saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
                session.set("accountFile", saveDir . "\" . session.get("accountFileName"))
                FileGetTime, fileTime, % session.get("accountFile"), M  ; M for modification time
                EnvSub, fileTime, %A_Now%, hours
                hoursDiff := Abs(fileTime)
                if(hoursDiff >= 5*24) {
                    session.get("missionDoneList")["accountHasPackInTesting"] := 0
                    setMetaData()
                } else {
                    session.get("missionDoneList")["accountHasPackInTesting"] := 1
                }
            }
        }
    }
}

;-------------------------------------------------------------------------------
; setMetaData - Write metadata flags to account filename
;-------------------------------------------------------------------------------
setMetaData() {
    global session

    hasMetaData := 0
    NamePartRightOfMeta := ""
    NamePartLeftOfMeta := ""

    ; check if account file has metadata information
    if(InStr(session.get("accountFileName"), "(")) {
        accountFileNameParts1 := StrSplit(session.get("accountFileName"), "(")  ; Split at (
        NamePartLeftOfMeta := accountFileNameParts1[1]
        if(InStr(accountFileNameParts1[2], ")")) {
            ; has metadata information
            accountFileNameParts2 := StrSplit(accountFileNameParts1[2], ")")  ; Split at )
            NamePartRightOfMeta := accountFileNameParts2[2]
            ;metadata := accountFileNameParts2[1]

            hasMetaData := 1
        }
    }

    metadata := ""
    if(session.get("missionDoneList")["beginnerMissionsDone"])
        metadata .= "B"
    if(session.get("missionDoneList")["soloBattleMissionDone"])
        metadata .= "S"
    if(session.get("missionDoneList")["intermediateMissionsDone"])
        metadata .= "I"
    if(session.get("missionDoneList")["specialMissionsDone"])
        metadata .= "X"
    if(session.get("missionDoneList")["accountHasPackInTesting"])
        metadata .= "T"
    if(session.get("missionDoneList")["receivedGiftDone"])
        metadata .= "R"

    ; Remove parentheses if no flags remain, helpful if there is only a T flag or manual removal of X flag
    if(hasMetaData) {
        if (metadata = "") {
            AccountNewName := NamePartLeftOfMeta . NamePartRightOfMeta
        } else {
            AccountNewName := NamePartLeftOfMeta . "(" . metadata . ")" . NamePartRightOfMeta
        }
    } else {
        if (metadata = "") {
            NameAndExtension := StrSplit(session.get("accountFileName"), ".")
            AccountNewName := NameAndExtension[1] . ".xml"
        } else {
            NameAndExtension := StrSplit(session.get("accountFileName"), ".")
            AccountNewName := NameAndExtension[1] . "(" . metadata . ").xml"
        }
    }

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    session.set("accountFile", saveDir . "\" . session.get("accountFileName"))
    accountNewFile := saveDir . "\" . AccountNewName
    FileMove, % session.get("accountFile"), %accountNewFile%
    session.set("accountFileName", AccountNewName)
}

;-------------------------------------------------------------------------------
; ExtractMetadata - Extract metadata string from filename
;-------------------------------------------------------------------------------
ExtractMetadata(fileName) {
    if (!InStr(fileName, "(")) {
        return ""  ; No parentheses, no metadata
    }

    parts1 := StrSplit(fileName, "(")
    if (!InStr(parts1[2], ")")) {
        return ""  ; No closing parenthesis
    }

    parts2 := StrSplit(parts1[2], ")")
    return parts2[1]  ; Return just the metadata between ( and )
}

;-------------------------------------------------------------------------------
; HasFlagInMetadata - Check if a specific flag exists in metadata
;-------------------------------------------------------------------------------
HasFlagInMetadata(fileName, flag) {
    metadata := ExtractMetadata(fileName)
    return InStr(metadata, flag) > 0
}

;-------------------------------------------------------------------------------
; ClearDeviceAccountXmlMap - Clear tracked XML map for s4t
;-------------------------------------------------------------------------------
ClearDeviceAccountXmlMap() {
    global session
    session.set("deviceAccountXmlMap", {})
}

;-------------------------------------------------------------------------------
; UpdateSavedXml - Update saved XML file with current game state
;-------------------------------------------------------------------------------
UpdateSavedXml(xmlPath) {
    global session

    count := 0
    Loop {
        CreateStatusMessage("Updating saved XML...",,,, false)

        adbWriteRaw("cp -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")
        waitadb()
        Sleep, 500

        RunWait, % session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort") . " pull /sdcard/deviceAccount.xml """ . xmlPath,, Hide

        Sleep, 500

        adbWriteRaw("rm -f /sdcard/deviceAccount.xml")
        Sleep, 500

        FileGetSize, OutputVar, %xmlPath%
        if(OutputVar > 0)
            break

        if(count > 5)
            break
        count++
    }
}

;-------------------------------------------------------------------------------
; CreateAccountList - Create account queue list for injection
; Note: This is a large function (300+ lines) included in full for completeness
;-------------------------------------------------------------------------------
CreateAccountList(instance) {
    global botConfig

    ; Clean up stale used accounts first
    CleanupUsedAccounts()

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . instance
    outputTxt := saveDir . "\list.txt"
    outputTxt_current := saveDir . "\list_current.txt"
    lastGeneratedFile := saveDir . "\list_last_generated.txt"

    ; Check if we need to regenerate the lists
    needRegeneration := false
    forceRegeneration := false

    ; First check: Do list files exist and are they not empty?
    if (!FileExist(outputTxt) || !FileExist(outputTxt_current)) {
        needRegeneration := true
        LogToFile("List files don't exist, regenerating...")
    } else {
        ; Check if current list is empty or nearly empty
        FileRead, currentListContent, %outputTxt_current%
        currentListLines := StrSplit(Trim(currentListContent), "`n", "`r")
        eligibleAccountsInList := 0

        ; Count non-empty lines
        for index, line in currentListLines {
            if (StrLen(Trim(line)) > 5) {
                eligibleAccountsInList++
            }
        }

        ; If list is empty or has very few accounts, force regeneration
        if (eligibleAccountsInList <= 1) {
            LogToFile("Current list is empty or nearly empty, forcing regeneration...")
            forceRegeneration := true
            needRegeneration := true
        } else {
            ; Check time-based regeneration
            lastGenTime := 0
            if (FileExist(lastGeneratedFile)) {
                FileRead, lastGenTime, %lastGeneratedFile%
            }

            timeDiff := A_Now
            EnvSub, timeDiff, %lastGenTime%, Minutes

            regenerationInterval := 60  ; in minutes
            if (timeDiff > regenerationInterval || !lastGenTime) {
                needRegeneration := true
            } else {
                return
            }
        }
    }

    if (!needRegeneration) {
        return
    }

    ; If we're forcing regeneration due to empty lists, clear used accounts log
    if (forceRegeneration) {
        usedAccountsLog := saveDir . "\used_accounts.txt"
        LogToFile("Forcing regeneration - clearing used accounts log to recover all accounts")

        ; Backup the used accounts log before clearing
        if (FileExist(usedAccountsLog)) {
            backupLog := saveDir . "\used_accounts_backup_" . A_Now . ".txt"
            FileCopy, %usedAccountsLog%, %backupLog%
            LogToFile("Backed up used accounts log to: " . backupLog)
        }

        ; Clear the used accounts log
        FileDelete, %usedAccountsLog%
        LogToFile("Cleared used accounts log - all accounts now available again")
    }

    parseInjectType := "Inject 13P+"  ; Default

    ; Determine injection type and pack ranges
    if (botConfig.get("deleteMethod") = "Inject 13P+") {
        parseInjectType := "Inject 13P+"
        minPacks := 0
        maxPacks := 9999
    }
    else if (botConfig.get("deleteMethod") = "Inject Missions") {
        parseInjectType := "Inject Missions"
        minPacks := 0
        maxPacks := 38
    }
    else if (botConfig.get("deleteMethod") = "Inject Wonderpick 96P+") {
        parseInjectType := "Inject Wonderpick 96P+"
        minPacks := 96
        maxPacks := 9999
    }

    ; Load used accounts from cleaned up log (will be empty if we just cleared it)
    usedAccountsLog := saveDir . "\used_accounts.txt"
    usedAccounts := {}
    if (FileExist(usedAccountsLog)) {
        FileRead, usedAccountsContent, %usedAccountsLog%
        Loop, Parse, usedAccountsContent, `n, `r
        {
            if (A_LoopField) {
                parts := StrSplit(A_LoopField, "|")
                if (parts.Length() >= 1) {
                    usedAccounts[parts[1]] := 1
                }
            }
        }
    }

    ; Delete existing list files before regenerating
    if FileExist(outputTxt)
        FileDelete, %outputTxt%
    if FileExist(outputTxt_current)
        FileDelete, %outputTxt_current%

    ; Create arrays to store files with their timestamps
    fileNames := []
    fileTimes := []
    packCounts := []

    ; Gather all eligible files with their timestamps
    Loop, %saveDir%\*.xml {
        xml := saveDir . "\" . A_LoopFileName

        ; Skip if this account was recently used (unless we just cleared the log)
        if (usedAccounts.HasKey(A_LoopFileName)) {
            if (botConfig.get("verboseLogging"))
                LogToFile("Skipping recently used account: " . A_LoopFileName)
            continue
        }

        ; Get file modification time
        modTime := ""
        FileGetTime, modTime, %xml%, M

        ; Calculate hours difference properly
        hoursDiff := A_Now
        timeVar := modTime
        EnvSub, hoursDiff, %timeVar%, Hours

        ; Always maintain strict age requirements - never relax them
        if (hoursDiff < 24) {
            if (botConfig.get("verboseLogging"))
                LogToFile("Skipping account less than 24 hours old: " . A_LoopFileName . " (age: " . hoursDiff . " hours)")
            continue
        }

        ; Check if account has "T" flag and needs more time (always 5 days)
        if(HasFlagInMetadata(A_LoopFileName, "T")) {
            if(hoursDiff < 5*24) {  ; Always 5 days for T-flagged accounts
                ; if (verboseLogging)
                    ; LogToFile("Skipping account with T flag (testing): " . A_LoopFileName . " (age: " . hoursDiff . " hours, needs 5 days)")
                continue
            }
        }

        ; Extract pack count from filename
        packCount := 0

        ; Extract the number before P
        if (RegExMatch(A_LoopFileName, "^(\d+)P", packMatch)) {
            packCount := packMatch1 + 0  ; Force numeric conversion
        } else {
            packCount := 10  ; Default for unrecognized formats
            ; if (verboseLogging)
                ; LogToFile("Unknown filename format: " . A_LoopFileName . ", assigned default pack count: 10")
        }

        ; Check if pack count fits the current injection range
        if (packCount < minPacks || packCount > maxPacks) {
            ; if (verboseLogging)
                ; LogToFile("  - SKIPPING: " . A_LoopFileName . " - Pack count " . packCount . " outside range " . minPacks . "-" . maxPacks)
            continue
        }

        ; Store filename, modification time, and pack count
        fileNames.Push(A_LoopFileName)
        fileTimes.Push(modTime)
        packCounts.Push(packCount)
        ; if (verboseLogging)
            ; LogToFile("  - KEEPING: " . A_LoopFileName . " - Pack count " . packCount . " inside range " . minPacks . "-" . maxPacks . " (age: " . hoursDiff . " hours)")
    }

    ; Log counts
    totalEligible := (fileNames.MaxIndex() ? fileNames.MaxIndex() : 0)

    if (forceRegeneration) {
        LogToFile("FORCED REGENERATION: Found " . totalEligible . " eligible files (cleared used accounts, maintained strict age requirements)")
    } else {
        LogToFile("Found " . totalEligible . " eligible files (>= 24 hours old, not recently used, packs: " . minPacks . "-" . maxPacks . ")")
    }

    ; Sort regular files based on selected method
    if (fileNames.MaxIndex() > 0) {
        sortMethod := botConfig.get("injectSortMethod")

        if (sortMethod == "ModifiedAsc") {
            SortArraysByProperty(fileNames, fileTimes, packCounts, "time", 1)
        } else if (sortMethod == "ModifiedDesc") {
            SortArraysByProperty(fileNames, fileTimes, packCounts, "time", 0)
        } else if (sortMethod == "PacksAsc") {
            SortArraysByProperty(fileNames, fileTimes, packCounts, "packs", 1)
        } else if (sortMethod == "PacksDesc") {
            SortArraysByProperty(fileNames, fileTimes, packCounts, "packs", 0)
        } else {
            ; Default to ModifiedAsc if unknown sort method
            SortArraysByProperty(fileNames, fileTimes, packCounts, "time", 1)
        }
    }

    ; Write sorted files to list.txt and list_current.txt
    listContent := ""

    ; Add files to list
    Loop, % fileNames.MaxIndex() {
        listContent .= fileNames[A_Index] . "`r`n"
    }

    ; Write to both files
    if (listContent != "") {
        FileAppend, %listContent%, %outputTxt%
        FileAppend, %listContent%, %outputTxt_current%
    }

    ; Record generation timestamp
    currentTime := A_Now
    FileDelete, %lastGeneratedFile%
    FileAppend, %currentTime%, %lastGeneratedFile%
}
