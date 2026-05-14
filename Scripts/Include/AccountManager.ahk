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
    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    loadedAccountPath := saveDir . "\" . session.get("accountFileName")
    loadedAccountMeta := AccountMetadata_Get(session.get("scriptName"), session.get("accountFileName"), loadedAccountPath)
    if (loadedAccountMeta["packCount"] != "") {
        session.set("accountOpenPacks", loadedAccountMeta["packCount"] + 0)
        session.set("accountHasPackInfo", 1)
    } else if (InStr(session.get("accountFileName"), "P")) {
        accountFileNameParts := StrSplit(session.get("accountFileName"), "P")
        session.set("accountOpenPacks", accountFileNameParts[1])
        session.set("accountHasPackInfo", 1)
    } else {
        session.set("accountFileNameOrig", session.get("accountFileName"))
    }

    session.set("deviceAccount", GetDeviceAccountFromXML())
    currentAccountInfo .= "Account: " . session.get("accountFileName") . "`nDeviceAccount: " . session.get("deviceAccount")
    CreateStatusMessage(currentAccountInfo, "AccountInfo", 0, 46, false)
    SetTimer, DestoryAccountInfoUI, -15000

    getMetaData()

    return loadFile
}

DestoryAccountInfoUI(){
    SetTimer, DestoryAccountInfoUI, Off
    guiName := "AccountInfo" . session.get("scriptName")
    Gui, %guiName%:+LastFoundExist
    if WinExist()
        Gui, %guiName%:Destroy
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
; MarkAccountAsClaimed - Mark account as claimed (Inject Rewards) without 24h lock
;-------------------------------------------------------------------------------
MarkAccountAsClaimed() {
    global session

    if (!session.get("currentLoadedAccountIndex") || !session.get("accountFileName")) {
        LogToFile("Warning: MarkAccountAsClaimed called but no current account tracked")
        return
    }

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    outputTxt := saveDir . "\list_current.txt"

    ; Remove the account from list_current.txt (so this session doesn't reprocess it)
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

    ; Do NOT call TrackUsedAccount - account stays available for pack-opening immediately
    if(botConfig.get("verboseLogging"))
        LogToFile("Marked account as claimed (no 24h lock): " . session.get("accountFileName"))

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
        saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")

        deviceAccountForFile := session.get("deviceAccount")
        if (deviceAccountForFile = "")
            deviceAccountForFile := GetDeviceAccountFromXML()
        if (deviceAccountForFile != "")
            session.set("deviceAccount", deviceAccountForFile)
        if (deviceAccountForFile != "") {
            safeDeviceAccount := RegExReplace(deviceAccountForFile, "[\\/:*?""<>|]", "_")
            xmlFile := safeDeviceAccount . ".xml"
        } else {
            xmlFile := A_Now . "_" . session.get("scriptName") . ".xml"
        }
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

    if (xmlFile != "" && filePath != "") {
        FileGetTime, savedModTime, %filePath%, M
        accountMeta := AccountMetadata_Get(session.get("scriptName"), xmlFile, filePath)
        if (file = "All")
            accountMeta["packCount"] := session.get("accountOpenPacks")
        else
            accountMeta["packCount"] := AccountMetadata_ExtractPackCount(xmlFile)
        accountMeta["lastModified"] := savedModTime

        if (file = "All") {
            flags := {"B": session.get("missionDoneList")["beginnerMissionsDone"]
                , "X": session.get("missionDoneList")["specialMissionsDone"]
                , "T": session.get("missionDoneList")["accountHasPackInTesting"]
                , "R": session.get("missionDoneList")["receivedGiftDone"]}

            for flag, value in flags {
                if (!accountMeta["flags"].HasKey(flag))
                    accountMeta["flags"][flag] := AccountMetadata_NewFlag(0)
                accountMeta["flags"][flag]["value"] := value ? 1 : 0
                accountMeta["flags"][flag]["setAt"] := value ? AccountMetadata_Now() : ""
                if (flag = "T" && value) {
                    validUntil := savedModTime
                    validUntil += 5, Days
                    accountMeta["flags"][flag]["validUntil"] := validUntil
                } else if (!value) {
                    accountMeta["flags"][flag]["validUntil"] := ""
                }
            }
        }

        AccountMetadata_SaveAccount(session.get("scriptName"), xmlFile, accountMeta)
    }

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
; UpdateAccount - Update account metadata with pack count
;-------------------------------------------------------------------------------
UpdateAccount() {
    global session

    if (session.get("accountFileName") != "" && session.get("accountOpenPacks") > 0) {
        accountMeta := AccountMetadata_NewAccount(session.get("scriptName"), session.get("accountFileName"))
        accountMeta["deviceAccount"] := session.get("deviceAccount")
        accountMeta["packCount"] := session.get("accountOpenPacks") + 0
        AccountMetadata_SaveAccount(session.get("scriptName"), session.get("accountFileName"), accountMeta)
    }

    updateTotalTime()

    session.set("VRAMUsage", GetVRAMByScriptName(session.get("scriptName")))
    ; Direct display of metrics rather than calling function
    CreateStatusMessage(generateStatusText(), "AvgRuns", 0, 605, false, true)
}

;-------------------------------------------------------------------------------
; getMetaData - Read metadata flags
;-------------------------------------------------------------------------------
getMetaData() {
    global session

    session.get("missionDoneList")["beginnerMissionsDone"] := 0

    session.get("missionDoneList")["specialMissionsDone"] := 0
    session.get("missionDoneList")["accountHasPackInTesting"] := 0
    session.get("missionDoneList")["receivedGiftDone"] := 0

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    accountPath := saveDir . "\" . session.get("accountFileName")
    accountMeta := AccountMetadata_Get(session.get("scriptName"), session.get("accountFileName"), accountPath)

    if (IsObject(accountMeta["flags"])) {
        if(accountMeta["flags"]["R"]["value"])
            session.get("missionDoneList")["receivedGiftDone"] := 1
        if(accountMeta["flags"]["B"]["value"])
            session.get("missionDoneList")["beginnerMissionsDone"] := 1
        if(accountMeta["flags"]["X"]["value"])
            session.get("missionDoneList")["specialMissionsDone"] := 1
        if(accountMeta["flags"]["T"]["value"])
            session.get("missionDoneList")["accountHasPackInTesting"] := 1
    }

    if (session.get("missionDoneList")["accountHasPackInTesting"]) {
        modTime := AccountMetadata_GetLastModified(session.get("scriptName"), session.get("accountFileName"), accountPath)
        if (modTime = "")
            return

        hoursDiff := A_Now
        EnvSub, hoursDiff, %modTime%, Hours
        if(hoursDiff >= 5*24) {
            session.get("missionDoneList")["accountHasPackInTesting"] := 0
            setMetaData()
        }
    }
}

;-------------------------------------------------------------------------------
; setMetaData - Write metadata flags
;-------------------------------------------------------------------------------
setMetaData() {
    global session

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
    accountFileName := session.get("accountFileName")
    if (accountFileName = "")
        return

    accountPath := saveDir . "\" . accountFileName
    originalModTime := ""
    if (FileExist(accountPath))
        FileGetTime, originalModTime, %accountPath%, M

    accountMeta := AccountMetadata_Get(session.get("scriptName"), accountFileName, accountPath)
    flags := {"B": session.get("missionDoneList")["beginnerMissionsDone"]
        , "X": session.get("missionDoneList")["specialMissionsDone"]
        , "T": session.get("missionDoneList")["accountHasPackInTesting"]
        , "R": session.get("missionDoneList")["receivedGiftDone"]}

    for flag, value in flags {
        if (!accountMeta["flags"].HasKey(flag))
            accountMeta["flags"][flag] := AccountMetadata_NewFlag(0)
        oldValue := accountMeta["flags"][flag]["value"]
        accountMeta["flags"][flag]["value"] := value ? 1 : 0
        if (oldValue != accountMeta["flags"][flag]["value"])
            accountMeta["flags"][flag]["setAt"] := value ? AccountMetadata_Now() : ""
        if (flag = "T" && value && originalModTime != "") {
            validUntil := originalModTime
            validUntil += 5, Days
            accountMeta["flags"][flag]["validUntil"] := validUntil
        } else if (!value) {
            accountMeta["flags"][flag]["validUntil"] := ""
        }
    }

    if (originalModTime != "") {
        accountMeta["lastModified"] := originalModTime
    }

    AccountMetadata_SaveAccount(session.get("scriptName"), accountFileName, accountMeta)
}

;-------------------------------------------------------------------------------
; HasFlagInMetadata - Check if a specific flag exists in metadata
;-------------------------------------------------------------------------------
HasFlagInMetadata(fileName, flag) {
    global session

    if (IsObject(session) && session.get("scriptName") != "") {
        metadataFound := false
        metadataValue := AccountMetadata_GetFlag(session.get("scriptName"), fileName, flag, metadataFound)
        if (metadataFound)
            return metadataValue
    }

    return false
}

AccountEligibility_HoursSince(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return 999999

    hoursDiff := A_Now
    EnvSub, hoursDiff, %timestamp%, Hours
    return hoursDiff
}

AccountEligibility_ToUTC(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return "0"

    offsetSeconds := A_NowUTC
    nowLocal := A_Now
    EnvSub, offsetSeconds, %nowLocal%, Seconds

    utcTimestamp := timestamp
    utcTimestamp += %offsetSeconds%, Seconds
    return utcTimestamp
}

AccountEligibility_CurrentDailyResetUTC() {
    nowUTC := A_NowUTC
    resetUTC := SubStr(nowUTC, 1, 8) . "060000"
    if (nowUTC < resetUTC)
        resetUTC += -1, Days
    return resetUTC
}

AccountEligibility_WasAfterDailyReset(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return false

    return AccountEligibility_ToUTC(timestamp) >= AccountEligibility_CurrentDailyResetUTC()
}

AccountEligibility_GetFlag(accountMeta, flag) {
    if (!IsObject(accountMeta["flags"]))
        return AccountMetadata_NewFlag(0)
    if (!accountMeta["flags"].HasKey(flag))
        return AccountMetadata_NewFlag(0)
    if (!IsObject(accountMeta["flags"][flag]))
        return AccountMetadata_NewFlag(0)
    return accountMeta["flags"][flag]
}

AccountEligibility_FlagIsSet(accountMeta, flag) {
    flagObj := AccountEligibility_GetFlag(accountMeta, flag)
    return flagObj["value"] ? true : false
}

AccountEligibility_FlagIsExpired(accountMeta, flag, hoursValid) {
    flagObj := AccountEligibility_GetFlag(accountMeta, flag)
    if (!flagObj["value"])
        return true

    if (flagObj["validUntil"] != "")
        return A_Now >= flagObj["validUntil"]

    if (flagObj["setAt"] = "")
        return false

    return AccountEligibility_HoursSince(flagObj["setAt"]) >= hoursValid
}

AccountEligibility_TFlagBlocks(accountMeta) {
    if (!AccountEligibility_FlagIsSet(accountMeta, "T"))
        return false

    return !AccountEligibility_FlagIsExpired(accountMeta, "T", 5 * 24)
}

AccountEligibility_AddTimestamp(ByRef timestamps, timestamp) {
    if (timestamp != "" && timestamp != "0")
        timestamps.Push(timestamp)
}

AccountEligibility_AddFlagTimestamp(ByRef timestamps, accountMeta, flag) {
    flagObj := AccountEligibility_GetFlag(accountMeta, flag)
    if (flagObj["value"])
        AccountEligibility_AddTimestamp(timestamps, flagObj["setAt"])
}

AccountEligibility_GetEarliestTimestamp(timestamps) {
    earliest := ""
    maxIndex := timestamps.MaxIndex()
    if (!maxIndex)
        return ""
    Loop, % maxIndex {
        timestamp := timestamps[A_Index]
        if (timestamp = "" || timestamp = "0")
            continue
        if (earliest = "" || timestamp < earliest)
            earliest := timestamp
    }
    return earliest
}

AccountEligibility_GetShinedustLastUpdatedAt(accountMeta) {
    shinedust := AccountMetadata_NormalizeShinedust(accountMeta["shinedust"])
    return shinedust["lastUpdatedAt"]
}

AccountEligibility_InjectRewardsEligible(accountMeta) {
    global botConfig

    doWonderpick := botConfig.get("wonderpickForEventMissions")
    doSpecialMissions := botConfig.get("claimSpecialMissions")
    doGift := botConfig.get("receiveGift")
    doShinedust := botConfig.get("ocrShinedust") && botConfig.get("s4tEnabled")

    if (!doWonderpick && !doSpecialMissions && !doGift && !doShinedust)
        return !AccountEligibility_WasAfterDailyReset(accountMeta["lastLoggedIn"])

    if (doWonderpick && AccountEligibility_FlagIsExpired(accountMeta, "W", 24))
        return true
    if (doSpecialMissions && !AccountEligibility_FlagIsSet(accountMeta, "X"))
        return true
    if (doGift && !AccountEligibility_FlagIsSet(accountMeta, "R"))
        return true
    if (doShinedust && AccountEligibility_HoursSince(AccountEligibility_GetShinedustLastUpdatedAt(accountMeta)) >= 24)
        return true

    return false
}

AccountEligibility_InjectPackEligible(accountMeta, method) {
    global botConfig

    if ((method = "Inject 13P+" || method = "Inject Wonderpick 96P+") && AccountEligibility_TFlagBlocks(accountMeta))
        return false

    if (method = "Inject 13P+" && botConfig.get("spendHourGlass"))
        return AccountEligibility_FlagIsExpired(accountMeta, "SH", 24)

    lastPackPulled := accountMeta["lastPackPulled"]
    if (lastPackPulled = "" || lastPackPulled = "0")
        return true

    return AccountEligibility_HoursSince(lastPackPulled) >= 24
}

AccountEligibility_IsEligible(instance, fileName, filePath, accountMeta := "") {
    global botConfig

    method := botConfig.get("deleteMethod")
    if (method = "Create Bots (13P)")
        return true

    if (!IsObject(accountMeta))
        accountMeta := AccountMetadata_Get(instance, fileName, filePath)

    if (method = "Inject Rewards")
        return AccountEligibility_InjectRewardsEligible(accountMeta)

    if (method = "Inject 13P+" || method = "Inject Wonderpick 96P+")
        return AccountEligibility_InjectPackEligible(accountMeta, method)

    return true
}

AccountEligibility_GetSortTimestamp(instance, fileName, filePath, accountMeta) {
    sortTime := ""
    if (IsObject(accountMeta))
        sortTime := accountMeta["lastModified"]
    if (sortTime != "")
        return sortTime

    FileGetTime, sortTime, %filePath%, M
    return sortTime
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

    if (OutputVar > 0) {
        SplitPath, xmlPath, xmlFileName
        FileGetTime, updatedModTime, %xmlPath%, M
        AccountMetadata_SetLastModified(session.get("scriptName"), xmlFileName, updatedModTime)
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

    helperPath := AccountMetadata_HelperPath()
    if (!FileExist(helperPath)) {
        LogToFile("carddb.exe not found; cannot generate account schedule")
        return
    }

    root := getScriptBaseFolder()
    command := """" . helperPath . """ --root """ . root . """ schedule-accounts"
    command .= " --instance """ . instance . """"
    command .= " --delete-method """ . botConfig.get("deleteMethod") . """"
    command .= " --sort-method """ . botConfig.get("injectSortMethod") . """"
    if (botConfig.get("wonderpickForEventMissions"))
        command .= " --wonderpick-for-event-missions"
    if (botConfig.get("claimSpecialMissions"))
        command .= " --claim-special-missions"
    if (botConfig.get("receiveGift"))
        command .= " --receive-gift"
    if (botConfig.get("ocrShinedust"))
        command .= " --ocr-shinedust"
    if (botConfig.get("s4tEnabled"))
        command .= " --s4t-enabled"
    if (botConfig.get("spendHourGlass"))
        command .= " --spend-hourglass"
    if (forceRegeneration)
        command .= " --force-clear-used"

    RunWait, %command%,, Hide
    if (ErrorLevel)
        LogToFile("carddb schedule-accounts failed for instance " . instance)
}
