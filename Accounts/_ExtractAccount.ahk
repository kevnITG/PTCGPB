#SingleInstance on
;SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
;SetWinDelay, -1
;SetControlDelay, -1
SetBatchLines, -1
SetTitleMatchMode, 3

global adbShell, adbPath, adbPorts, winTitle, folderPath, mumuFolder, extractInProgress

IniRead, winTitle, ExtractAccount.ini, UserSettings, winTitle, 1
IniRead, fileName, ExtractAccount.ini, UserSettings, fileName, name
IniRead, folderPath, ExtractAccount.ini, UserSettings, folderPath, C:\Program Files\Netease

; Match Inject visual style
Gui, Font, s10, Segoe UI
Gui, Color, 1E1E1E
Gui, Font, cDCDCDC

Gui, Add, Text, x10 y10 w450 cWhite, This tool is to EXTRACT the account from the selected instance.
Gui, Add, Text, x10 y+5 w450 cRed, It will OVERWRITE any file named the same.
Gui, Add, Text, x10 y+5 w450 cWhite, Ensure the file name is unique before continuing.
Gui, Add, Text, x10 y+15 w450 h1 0x10 c3F3F3F

Gui, Add, Text, x10 y+15 w450, Instance Name:
instanceList := GetInstanceList(folderPath)
selectedIndex := 1
if (instanceList != "") {
    StringSplit, arr, instanceList, |
    Loop, %arr0%
    {
        if (arr%A_Index% = winTitle) {
            selectedIndex := A_Index
            break
        }
    }
}
Gui, Add, DropDownList, x10 y+5 vwinTitle w340 Choose%selectedIndex%, %instanceList%
Gui, Add, Button, x+10 yp w100 gRefreshInstances, Refresh

Gui, Add, Text, x10 y+15 w450 cDCDCDC, File Name (without spaces and without .xml):
Gui, Add, Edit, x10 y+5 vfileName w450 c000000 BackgroundFFFFFF, %fileName%

Gui, Add, Text, x10 y+15 w450 cDCDCDC, MuMu Folder same as main script (C:\Program Files\Netease)
Gui, Add, Edit, x10 y+5 vfolderPath w450 c000000 BackgroundFFFFFF, %folderPath%

Gui, Add, Text, x10 y+15 w450 h1 0x10 c3F3F3F
Gui, Add, Text, x10 y+12 w450 vExtractStatusText c8FD18A, Ready.
Gui, Add, Progress, x10 y+6 w450 h8 vExtractProgress c4AAE3A Background303030, 0
Gui, Add, Button, x185 y+16 w100 h40 vExtractSubmitBtn gSaveSettings cBlue, Submit
Gui, Show, w470 h420, Arturo's Account Extraction Tool ;'
Return

SaveSettings:
    if (extractInProgress)
        return
    Gui, Submit, NoHide
    extractInProgress := 1
    SetExtractUiBusy(true)
    UpdateExtractUi("Saving settings...", 5)
    IniWrite, %winTitle%, ExtractAccount.ini, UserSettings, winTitle
    IniWrite, %fileName%, ExtractAccount.ini, UserSettings, fileName
    IniWrite, %folderPath%, ExtractAccount.ini, UserSettings, folderPath

    UpdateExtractUi("Resolving MuMu folder...", 12)
    mumuFolder := getMumuFolder(folderPath)

    adbPath := mumuFolder . "\shell\adb.exe"
    if !FileExist(adbPath)
        adbPath := mumuFolder . "\nx_main\adb.exe"
    findAdbPorts(mumuFolder)

    if(!WinExist(winTitle)) {
        Msgbox, 16, , Can't find instance: %winTitle%. Make sure that instance is running.;'
        UpdateExtractUi("Selected instance is not running.", 0)
        SetExtractUiBusy(false)
        extractInProgress := 0
        return
    }

    if !FileExist(adbPath) {
        MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
        UpdateExtractUi("Invalid MuMu folder path.", 0)
        SetExtractUiBusy(false)
        extractInProgress := 0
        return
    }

    if(!adbPorts) {
        Msgbox, 16, , Invalid port... Check the common issues section in the readme/github guide.
        UpdateExtractUi("Could not resolve ADB port.", 0)
        SetExtractUiBusy(false)
        extractInProgress := 0
        return
    }

    UpdateExtractUi("Connecting to emulator...", 24)
    RunWait, %adbPath% connect 127.0.0.1:%adbPorts%,, Hide

    UpdateExtractUi("Preparing shell...", 35)
    if !RunAdbRootCommand("id") {
        Msgbox, Failed to connect to the shell. Try restarting your pc/instances and try again.
        UpdateExtractUi("Failed to connect to shell.", 0)
        SetExtractUiBusy(false)
        extractInProgress := 0
        return
    }

    if !saveAccount() {
        UpdateExtractUi("Extract failed.", 0)
        SetExtractUiBusy(false)
        extractInProgress := 0
        return
    }

    UpdateExtractUi("Done.", 100)
    SetExtractUiBusy(false)
    extractInProgress := 0
return

findAdbPorts(mumuFolderParam) {
    global adbPorts, winTitle
    ; Initialize variables
    adbPorts := 0  ; Create an empty associative array for adbPorts
    mumuFolderPath = %mumuFolderParam%\vms\*
    if !FileExist(mumuFolderPath){
        MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
        ExitApp
    }
    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolderPath%, D  ; D flag to include directories only
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"  ; The config folder inside each directory
        displayName := GetVmDisplayName(folder)

        ; Check if config folder exists
        IfExist, %configFolder%
        {
            ; Define paths to vm_config.json and extra_config.json
            vmConfigFile := configFolder "\vm_config.json"
            extraConfigFile := configFolder "\extra_config.json"

            ; Check if vm_config.json exists and read adb host port
            IfExist, %vmConfigFile%
            {
                FileRead, vmConfigContent, %vmConfigFile%
                ; Parse the JSON for adb host port
                RegExMatch(vmConfigContent, """host_port"":\s*""(\d+)""", adbHostPort)
                adbPort := adbHostPort1  ; Capture the adb host port value
            }

            ; Check if extra_config.json exists and read playerName
            IfExist, %extraConfigFile%
            {
                FileRead, extraConfigContent, %extraConfigFile%
                ; Parse the JSON for playerName
                RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                if(playerName1 = winTitle || displayName = winTitle) {
                    adbPorts := adbPort
                }
            }
            else if (displayName = winTitle) {
                adbPorts := adbPort
            }
        }
    }
}

saveAccount() {
    global adbPath, adbPorts, fileName

    saveDir := A_ScriptDir "\" . fileName . ".xml"

    if(FileExist(saveDir)) {
        MsgBox, 16, , File already exists! Delete it or input a different name then try again!
        return 0
    }

    count := 0

    Loop {

        UpdateExtractUi("Copying account data...", 55)

        if !RunAdbRootCommand("rm -f /sdcard/deviceAccount.xml")
            return 0

        Sleep, 500

        if !RunAdbRootCommand("cp /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")
            return 0

        Sleep, 500

        if !RunAdbPull("/sdcard/deviceAccount.xml", saveDir)
            return 0

        Sleep, 500

        FileGetSize, OutputVar, %saveDir%

        if(OutputVar > 0)
            break

        if(count > 10) {
            MsgBox, 16, , Tried 10 times. Failed to extract account.
            return 0
        }
        count++
    }

    UpdateExtractUi("Finalizing...", 85)

    if !RunAdbRootCommand("am force-stop jp.pokemon.pokemontcgp")
        return 0

    if !RunAdbRootCommand("rm -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") ; delete account data
        return 0

    MsgBox, Success! Extracted account '%fileName%.xml' to the Accounts folder, closed the game, and deleted the local save from the instance.
    return 1
}

RunAdbRootCommand(shellCommand) {
    global adbPath, adbPorts
    q := Chr(34)
    sq := Chr(39)

    fullCommand := q . adbPath . q . " -s 127.0.0.1:" . adbPorts . " shell su -c " . sq . shellCommand . sq
    RunWait, %fullCommand%,, Hide
    if (ErrorLevel = 0)
        return 1

    fallbackCommand := q . adbPath . q . " -s 127.0.0.1:" . adbPorts . " shell su 0 sh -c " . sq . shellCommand . sq
    RunWait, %fallbackCommand%,, Hide
    if (ErrorLevel = 0)
        return 1

    nonRootCommand := q . adbPath . q . " -s 127.0.0.1:" . adbPorts . " shell " . sq . shellCommand . sq
    RunWait, %nonRootCommand%,, Hide
    return (ErrorLevel = 0)
}

RunAdbPull(remotePath, localPath) {
    global adbPath, adbPorts
    pullCommand := Chr(34) . adbPath . Chr(34) . " -s 127.0.0.1:" . adbPorts . " pull " . remotePath . " " . Chr(34) . localPath . Chr(34)
    RunWait, %pullCommand%,, Hide
    return (ErrorLevel = 0)
}

getMumuFolder(folderPath) {
    candidateFolders := [folderPath . "\MuMu"
        , folderPath . "\MuMuPlayerGlobal-12.0"
        , folderPath . "\MuMuPlayerGlobal"
        , folderPath . "\MuMuPlayer-12.0"
        , folderPath . "\MuMu Player 12"
        , folderPath . "\MuMuPlayer"
        , folderPath . "\MuMuPlayer-12"
        , folderPath . "\MuMuPlayer12"]

    for _, candidateFolder in candidateFolders {
        if FileExist(candidateFolder)
            return candidateFolder
    }

    return folderPath . "\MuMuPlayerGlobal-12.0"
}

GetVmDisplayName(folder) {
    configFolder := folder "\configs"
    extraConfigFile := configFolder "\extra_config.json"

    if FileExist(extraConfigFile) {
        FileRead, fileContent, %extraConfigFile%
        RegExMatch(fileContent, """playerName"":\s*""(.*?)""", playerName)
        if (playerName1 != "")
            return playerName1
    }

    SplitPath, folder, folderName
    return folderName
}

SetExtractUiBusy(isBusy) {
    if (isBusy)
        GuiControl, Disable, ExtractSubmitBtn
    else
        GuiControl, Enable, ExtractSubmitBtn
}

UpdateExtractUi(statusText, progressValue := "") {
    GuiControl,, ExtractStatusText, %statusText%
    if (progressValue != "")
        GuiControl,, ExtractProgress, %progressValue%
    Sleep, 10
}

GetInstanceList(baseFolder) {
    instanceList := ""
    mumuFolder := getMumuFolder(baseFolder)

    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        displayName := GetVmDisplayName(folder)

        if (displayName != "") {
            if (instanceList != "")
                instanceList .= "|"
            instanceList .= displayName
        }
    }

    return instanceList
}

RefreshInstances:
    Gui, Submit, NoHide
    refreshedList := GetInstanceList(folderPath)
    GuiControl,, winTitle, |%refreshedList%
return
