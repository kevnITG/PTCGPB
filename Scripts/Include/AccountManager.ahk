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
    global beginnerMissionsDone, soloBattleMissionDone, intermediateMissionsDone, specialMissionsDone
    global accountHasPackInTesting, resetSpecialMissionsDone, stopToggle, winTitle, loadDir
    global accountFileName, accountOpenPacks, accountFileNameTmp, accountFileNameOrig, accountHasPackInfo
    global currentLoadedAccountIndex, adbShell, adbPath, adbPort
    global deleteMethod, folderPath

    beginnerMissionsDone := 0
    soloBattleMissionDone := 0
    intermediateMissionsDone := 0
    specialMissionsDone := 0
    accountHasPackInTesting := 0
    resetSpecialMissionsDone := 0

    if (stopToggle) {
        CreateStatusMessage("Stopping...",,,, false)
        ExitApp
    }

    CreateStatusMessage("Loading account...",,,, false)

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    loadDir := saveDir
    outputTxt := saveDir . "\list_current.txt"

    accountFileName := ""
    accountOpenPacks := 0
    accountFileNameTmp := ""
    accountFileNameOrig := ""
    accountHasPackInfo := 0
    currentLoadedAccountIndex := 0

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
                    accountFileName := currentFile
                    foundValidAccount := true
                    foundIndex := A_Index
                    currentLoadedAccountIndex := A_Index
                    break
                }

				if(InStr(fileLines[1], "T")) {
					; account has a pack under test

				}
				if (accountModifiedTimeDiff >= 24){
					if(!InStr(fileLines[1], "T") || accountModifiedTimeDiff >= 5*24) {
						; otherwise account has a pack under test
						accountFileName := fileLines[1]
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

    adbWriteRaw("input keyevent 3")
    waitadb()

    adbWriteRaw("am stop-app jp.pokemon.pokemontcgp")
    Sleep, 500
    adbWriteRaw("cmd activity stop-app jp.pokemon.pokemontcgp")
    Sleep, 500

    adbWriteRaw("am kill jp.pokemon.pokemontcgp")
    Sleep, 500
    adbWriteRaw("am force-stop jp.pokemon.pokemontcgp")
    Sleep, 500

    adbWriteRaw("sync")
    Sleep, 3000

    ; Injection cycle restart logic for "Inject 13P+" and "Inject Wonderpick 96P+" to mitigate MuMu memory leak / PTCGP incompatibility issues.
    ; Read auto-restart settings from PTCGPB settings
    IniRead, autoRestartMumu, %A_ScriptDir%\..\Settings.ini, UserSettings, autoRestartMumu, 1
    IniRead, runsBeforeRestart, %A_ScriptDir%\..\Settings.ini, UserSettings, runsBeforeRestart, 13

    if (autoRestartMumu = 1 && runsBeforeRestart > 0 && (deleteMethod = "Inject 13P+" || deleteMethod = "Inject Wonderpick 96P+")) {
        IniRead, InjectionCycleCount, %A_ScriptDir%\%winTitle%.ini, Metrics, InjectionCycleCount, 0
        InjectionCycleCount := InjectionCycleCount + 1
        IniWrite, %InjectionCycleCount%, %A_ScriptDir%\%winTitle%.ini, Metrics, InjectionCycleCount

        if (InjectionCycleCount >= runsBeforeRestart) {
            InjectionCycleCount := 0
            IniWrite, %InjectionCycleCount%, %A_ScriptDir%\%winTitle%.ini, Metrics, InjectionCycleCount

            CreateStatusMessage("Restarting MuMu instance (" . runsBeforeRestart . " cycle)",,,, false)
            LogToFile("Restarting MuMu instance after " . runsBeforeRestart . " injection cycles - full script reload")

            killInstance(winTitle)
            Sleep, 2000
            launchInstance(winTitle)
            Sleep, 5000  ; Give MuMu a head start before script reload

            Reload  ; Clean restart handles ADB reconnection automatically
        }
    }

    waitadb()
    RunWait, % adbPath . " -s 127.0.0.1:" . adbPort . " push " . loadFile . " /sdcard/deviceAccount.xml",, Hide
    waitadb()
    adbWriteRaw("cp /sdcard/deviceAccount.xml /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml")
    waitadb()
    adbWriteRaw("rm /sdcard/deviceAccount.xml")
    waitadb()
    ; Reliably restart the app: Wait for launch, and start in a clean, new task without animation.
    adbWriteRaw("am start -W -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity -f 0x10018000")
    waitadb()
    Sleep, 6000   ; Reduced from 1000
    ; Parse account filename for pack info (unchanged)
    if (InStr(accountFileName, "P")) {
        accountFileNameParts := StrSplit(accountFileName, "P")
        accountOpenPacks := accountFileNameParts[1]
        accountFileNameTmp := accountFileNameParts[2]
        accountHasPackInfo := 1
    } else {
        accountFileNameOrig := accountFileName
    }

    getMetaData()

    return loadFile
}

;-------------------------------------------------------------------------------
; MarkAccountAsUsed - Mark account as successfully used and remove from queue
;-------------------------------------------------------------------------------
MarkAccountAsUsed() {
    global currentLoadedAccountIndex, accountFileName, winTitle

    if (!currentLoadedAccountIndex || !accountFileName) {
        LogToFile("Warning: MarkAccountAsUsed called but no current account tracked")
        return
    }

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    outputTxt := saveDir . "\list_current.txt"

    ; Remove the account from list_current.txt
    if FileExist(outputTxt) {
        FileRead, fileContent, %outputTxt%
        fileLines := StrSplit(fileContent, "`n", "`r")

        newListContent := ""
        Loop, % fileLines.MaxIndex() {
            if (A_Index != currentLoadedAccountIndex)
                newListContent .= fileLines[A_Index] "`r`n"
        }

        FileDelete, %outputTxt%
        FileAppend, %newListContent%, %outputTxt%
    }

    ; Track as used with timestamp
    TrackUsedAccount(accountFileName)

    ; Reset tracking
    currentLoadedAccountIndex := 0
}

;-------------------------------------------------------------------------------
; saveAccount - Save current account from game to XML file
;-------------------------------------------------------------------------------
saveAccount(file := "Valid", ByRef filePath := "", packDetails := "", addWFlag := false) {
    global accountOpenPacks, beginnerMissionsDone, soloBattleMissionDone, intermediateMissionsDone
    global specialMissionsDone, accountHasPackInTesting, winTitle, packsInPool, scriptName
    global adbShell, adbPath, adbPort, Debug

    filePath := ""
    xmlFile := ""  ; Initialize xmlFile for all branches

    if (file = "All") {
        metadata := ""
        if(beginnerMissionsDone)
            metadata .= "B"
        if(soloBattleMissionDone)
            metadata .= "S"
        if(intermediateMissionsDone)
            metadata .= "I"
        if(specialMissionsDone)
            metadata .= "X"
        if(accountHasPackInTesting)
            metadata .= "T"
        if(addWFlag)
            metadata .= "W"

        saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle

        ; Create filename components
        timestamp := A_Now
        xmlFile := accountOpenPacks . "P_" . timestamp . "_" . winTitle . "(" . metadata . ").xml"
        filePath := saveDir . "\" . xmlFile

    } else if (file = "Valid" || file = "Invalid") {
        metadata := ""
        if(addWFlag)
            metadata .= "W"

        saveDir := A_ScriptDir "\..\Accounts\GodPacks\"
        xmlFile := A_Now . "_" . winTitle . "_" . file . "_" . packsInPool . "_packs"
        if(metadata != "")
            xmlFile .= "(" . metadata . ")"
        xmlFile .= ".xml"
        filePath := saveDir . xmlFile

    } else if (file = "Tradeable") {
        saveDir := A_ScriptDir "\..\Accounts\Trades\"
        ;packsInPool doesn't make sense but nothing does, really.
        xmlFile := A_Now . "_" . winTitle . (packDetails ? "_" . packDetails : "") . "_" . packsInPool . "_packs.xml"
        filePath := saveDir . xmlFile

    } else {
        metadata := ""
        if(addWFlag)
            metadata .= "W"

        saveDir := A_ScriptDir "\..\Accounts\SpecificCards\"
        xmlFile := A_Now . "_" . winTitle . "_" . file . "_" . packsInPool . "_packs"
        if(metadata != "")
            xmlFile .= "(" . metadata . ")"
        xmlFile .= ".xml"
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

        RunWait, % adbPath . " -s 127.0.0.1:" . adbPort . " pull /sdcard/deviceAccount.xml """ . filePath,, Hide

        Sleep, 500

        adbWriteRaw("rm /sdcard/deviceAccount.xml")

        Sleep, 500

        FileGetSize, OutputVar, %filePath%

        if(OutputVar > 0)
            break

        if(count > 10 && file != "All") {
            CreateStatusMessage("Account not saved. Pausing...",,,, false)
            LogToDiscord("Attempted to save account in " . scriptName . " but was unsuccessful. Pausing. You will need to manually extract.", Screenshot(), true)
            Pause, On
        }
        count++
    }

    ;Add metrics tracking whenever desired card is found
    now := A_NowUTC
    IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastEndTimeUTC
    EnvSub, now, 1970, seconds
    IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastEndEpoch

    return xmlFile  ; Now returns the filename for all branches
}

;-------------------------------------------------------------------------------
; TrackUsedAccount - Track account as used with timestamp
;-------------------------------------------------------------------------------
TrackUsedAccount(fileName) {
    global winTitle
    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    usedAccountsLog := saveDir . "\used_accounts.txt"

    ; Append with timestamp only (no epoch needed)
    currentTime := A_Now
    FileAppend, % fileName . "|" . currentTime . "`n", %usedAccountsLog%
}

;-------------------------------------------------------------------------------
; CleanupUsedAccounts - Remove stale used account tracking data
;-------------------------------------------------------------------------------
CleanupUsedAccounts() {
    global winTitle, verboseLogging
    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
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
                if(verboseLogging)
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
                if(verboseLogging)
                    LogToFile("Removed stale used account: " . fileName . " (used: " . timestamp . ")")
            }
        }
    }

    ; Always rewrite the file to update it
    FileDelete, %usedAccountsLog%
    if (cleanedContent) {
        FileAppend, %cleanedContent%, %usedAccountsLog%
    }

    if(verboseLogging && removedCount > 0)
        LogToFile("Cleaned up used accounts: kept " . keptCount . ", removed " . removedCount)
}

;-------------------------------------------------------------------------------
; UpdateAccount - Update account filename with pack count
;-------------------------------------------------------------------------------
UpdateAccount() {
    global accountOpenPacks, accountFileName, accountFileNameParts, accountFileNameOrig, ocrSuccess, winTitle
    global aminutes, aseconds, rerolls

    accountOpenPacksStr := accountOpenPacks
    if(accountOpenPacks<10)
        accountOpenPacksStr := "0" . accountOpenPacks ; add a trailing 0 for sorting

    if(InStr(accountFileName, "P")){
        AccountName := StrSplit(accountFileName , "P")
        accountFileNameParts := StrSplit(accountFileName, "P")  ; Split at P
        AccountNewName := accountOpenPacksStr . "P" . accountFileNameParts[2]
    } else if (ocrSuccess)
        AccountNewName := accountOpenPacksStr . "P_" . accountFileNameOrig
    else
        return ; if OCR is not successful, don't modify account file

    if(!InStr(accountFileName, "P") || accountOpenPacks > 0) {
        saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
        accountFile := saveDir . "\" . accountFileName
        accountNewFile := saveDir . "\" . AccountNewName
        FileMove, %accountFile% , %accountNewFile% ;TODO enable
        FileSetTime,, %accountNewFile%
        accountFileName := AccountNewName
    }

    ; Direct display of metrics rather than calling function
    CreateStatusMessage("Avg: " . aminutes . "m " . aseconds . "s | Runs: " . rerolls . " | Account Packs " . accountOpenPacks, "AvgRuns", 0, 605, false, true)
}

;-------------------------------------------------------------------------------
; getMetaData - Read metadata flags from account filename
;-------------------------------------------------------------------------------
getMetaData() {
    global accountFileName, beginnerMissionsDone, soloBattleMissionDone, intermediateMissionsDone
    global specialMissionsDone, accountHasPackInTesting, resetSpecialMissionsDone, winTitle

    beginnerMissionsDone := 0
    soloBattleMissionDone := 0
    intermediateMissionsDone := 0
    specialMissionsDone := 0
    accountHasPackInTesting := 0

    ; check if account file has metadata information
    if(InStr(accountFileName, "(")) {
        accountFileNameParts1 := StrSplit(accountFileName, "(")  ; Split at (
        if(InStr(accountFileNameParts1[2], ")")) {
            ; has metadata information
            accountFileNameParts2 := StrSplit(accountFileNameParts1[2], ")")  ; Split at )
            metadata := accountFileNameParts2[1]
            if(InStr(metadata, "B"))
                beginnerMissionsDone := 1
            if(InStr(metadata, "S"))
                soloBattleMissionDone := 1
            if(InStr(metadata, "I"))
                intermediateMissionsDone := 1
            if(InStr(metadata, "X"))
                specialMissionsDone := 1
            if(InStr(metadata, "T")) {
                saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
                accountFile := saveDir . "\" . accountFileName
                FileGetTime, fileTime, %accountFile%, M  ; M for modification time
                EnvSub, fileTime, %A_Now%, hours
                hoursDiff := Abs(fileTime)
                if(hoursDiff >= 5*24) {
                    accountHasPackInTesting := 0
                    setMetaData()
                } else {
                    accountHasPackInTesting := 1
                }
            }
        }
    }

    if(resetSpecialMissionsDone)
        specialMissionsDone := 0
}

;-------------------------------------------------------------------------------
; setMetaData - Write metadata flags to account filename
;-------------------------------------------------------------------------------
setMetaData() {
    global accountFileName, beginnerMissionsDone, soloBattleMissionDone, intermediateMissionsDone
    global specialMissionsDone, accountHasPackInTesting, winTitle

    hasMetaData := 0
    NamePartRightOfMeta := ""
    NamePartLeftOfMeta := ""

    ; check if account file has metadata information
    if(InStr(accountFileName, "(")) {
        accountFileNameParts1 := StrSplit(accountFileName, "(")  ; Split at (
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
    if(beginnerMissionsDone)
        metadata .= "B"
    if(soloBattleMissionDone)
        metadata .= "S"
    if(intermediateMissionsDone)
        metadata .= "I"
    if(specialMissionsDone)
        metadata .= "X"
    if(accountHasPackInTesting)
        metadata .= "T"

    ; Remove parentheses if no flags remain, helpful if there is only a T flag or manual removal of X flag
    if(hasMetaData) {
        if (metadata = "") {
            AccountNewName := NamePartLeftOfMeta . NamePartRightOfMeta
        } else {
            AccountNewName := NamePartLeftOfMeta . "(" . metadata . ")" . NamePartRightOfMeta
        }
    } else {
        if (metadata = "") {
            NameAndExtension := StrSplit(accountFileName, ".")
            AccountNewName := NameAndExtension[1] . ".xml"
        } else {
            NameAndExtension := StrSplit(accountFileName, ".")
            AccountNewName := NameAndExtension[1] . "(" . metadata . ").xml"
        }
    }

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    accountFile := saveDir . "\" . accountFileName
    accountNewFile := saveDir . "\" . AccountNewName
    FileMove, %accountFile% , %accountNewFile%
    accountFileName := AccountNewName
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
    global deviceAccountXmlMap
    deviceAccountXmlMap := {}
}

;-------------------------------------------------------------------------------
; killInstance - Kill MuMu instance by instance number
;-------------------------------------------------------------------------------
killInstance(instanceNum := "") {
    killed := 0

    pID := checkInstance(instanceNum)
    if pID {
        Process, Close, %pID%
        killed := killed + 1
    }

    return killed
}

;-------------------------------------------------------------------------------
; checkInstance - Check if MuMu instance exists and get its process ID
;-------------------------------------------------------------------------------
checkInstance(instanceNum := "") {
    ret := WinExist(instanceNum)
    if(ret) {
        WinGet, temp_pid, PID, ahk_id %ret%
        return temp_pid
    }

    return ""
}

;-------------------------------------------------------------------------------
; launchInstance - Launch MuMu instance by instance number
;-------------------------------------------------------------------------------
launchInstance(instanceNum := "") {
    global folderPath

    ; Determine MuMu folder path
    mumuFolder := folderPath . "\MuMuPlayerGlobal-12.0"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMu Player 12"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMuPlayer"

    if(instanceNum != "") {
        mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
        if(mumuNum != "") {
            mumuExe := mumuFolder . "\shell\MuMuPlayer.exe"
            if !FileExist(mumuExe)
                mumuExe := mumuFolder . "\nx_main\MuMuNxMain.exe"
            Run_(mumuExe, "-v " . mumuNum)
        }
    }
}

;-------------------------------------------------------------------------------
; getMumuInstanceNumFromPlayerName - Get MuMu instance number from player name
;-------------------------------------------------------------------------------
getMumuInstanceNumFromPlayerName(scriptName := "") {
    global folderPath

    if(scriptName == "") {
        return ""
    }

    ; Determine MuMu folder path
    mumuFolder := folderPath . "\MuMuPlayerGlobal-12.0"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMu Player 12"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMuPlayer"

    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"

        IfExist, %configFolder%
        {
            extraConfigFile := configFolder "\extra_config.json"

            IfExist, %extraConfigFile%
            {
                FileRead, extraConfigContent, %extraConfigFile%
                RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                if(playerName1 == scriptName) {
                    RegExMatch(A_LoopFileFullPath, "[^-]+$", mumuNum)
                    return mumuNum
                }
            }
        }
    }
}

;-------------------------------------------------------------------------------
; Run_ - Run as non-administrator (MuMu has issues running as admin)
;-------------------------------------------------------------------------------
Run_(target, args:="", workdir:="") {
    try
        ShellRun(target, args, workdir)
    catch e
        Run % args="" ? target : target " " args, % workdir
}

;-------------------------------------------------------------------------------
; ShellRun - Helper function for Run_ to execute as non-admin
;-------------------------------------------------------------------------------
ShellRun(prms*) {
    shellWindows := ComObjCreate("Shell.Application").Windows
    VarSetCapacity(_hwnd, 4, 0)
    desktop := shellWindows.FindWindowSW(0, "", 8, ComObj(0x4003, &_hwnd), 1)

    if ptlb := ComObjQuery(desktop
        , "{4C96BE40-915C-11CF-99D3-00AA004AE837}"
        , "{000214E2-0000-0000-C000-000000000046}")
    {
        if DllCall(NumGet(NumGet(ptlb+0)+15*A_PtrSize), "ptr", ptlb, "ptr*", psv:=0) = 0
        {
            VarSetCapacity(IID_IDispatch, 16)
            NumPut(0x46000000000000C0, NumPut(0x20400, IID_IDispatch, "int64"), "int64")

            DllCall(NumGet(NumGet(psv+0)+15*A_PtrSize), "ptr", psv
                , "uint", 0, "ptr", &IID_IDispatch, "ptr*", pdisp:=0)

            shell := ComObj(9,pdisp,1).Application
            shell.ShellExecute(prms*)

            ObjRelease(psv)
        }
        ObjRelease(ptlb)
    }
}

;-------------------------------------------------------------------------------
; UpdateSavedXml - Update saved XML file with current game state
;-------------------------------------------------------------------------------
UpdateSavedXml(xmlPath) {
    global adbPath, adbPort, adbShell

    count := 0
    Loop {
        CreateStatusMessage("Updating saved XML...",,,, false)

        adbWriteRaw("cp -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")
        waitadb()
        Sleep, 500

        RunWait, % adbPath . " -s 127.0.0.1:" . adbPort . " pull /sdcard/deviceAccount.xml """ . xmlPath,, Hide

        Sleep, 500

        adbWriteRaw("rm /sdcard/deviceAccount.xml")
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
    global injectSortMethod, deleteMethod, winTitle, verboseLogging

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

    if (!injectSortMethod)
        injectSortMethod := "ModifiedAsc"

    parseInjectType := "Inject 13P+"  ; Default

    ; Determine injection type and pack ranges
    if (deleteMethod = "Inject 13P+") {
        parseInjectType := "Inject 13P+"
        minPacks := 0
        maxPacks := 9999
    }
    else if (deleteMethod = "Inject Missions") {
        parseInjectType := "Inject Missions"
        minPacks := 0
        maxPacks := 38
    }
    else if (deleteMethod = "Inject Wonderpick 96P+") {
        parseInjectType := "Inject Wonderpick 96P+"
        minPacks := 35
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
            if (verboseLogging)
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
            if (verboseLogging)
                LogToFile("Skipping account less than 24 hours old: " . A_LoopFileName . " (age: " . hoursDiff . " hours)")
            continue
        }

        ; Check if account has "T" flag and needs more time (always 5 days)
        ; BUT skip this check if account also has "W" flag (W takes precedence)
        if(InStr(A_LoopFileName, "(") && InStr(A_LoopFileName, "T") && !InStr(A_LoopFileName, "W")) {
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
        sortMethod := (injectSortMethod) ? injectSortMethod : "ModifiedAsc"

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

    ; Clean up WP metadata
    CleanupWPMetadata()
}
