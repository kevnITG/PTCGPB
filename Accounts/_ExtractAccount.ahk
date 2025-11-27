#SingleInstance on
;SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
;SetWinDelay, -1
;SetControlDelay, -1
SetBatchLines, -1
SetTitleMatchMode, 3

global adbShell, adbPath, adbPorts, winTitle, folderPath

IniRead, winTitle, ExtractAccount.ini, UserSettings, winTitle, 1
IniRead, fileName, ExtractAccount.ini, UserSettings, fileName, name
IniRead, folderPath, ExtractAccount.ini, UserSettings, folderPath, C:\Program Files\Netease

Gui, Add, Text,, This tool is to EXTRACT the account from the instance.`nMake sure the file name does not match any current account!`nIt will OVERWRITE any file named the same!
Gui, Add, Text,, Instance Name:
Gui, Add, Edit, vwinTitle w200, %winTitle%
Gui, Add, Text,, File Name (without spaces and without .xml):
Gui, Add, Edit, vfileName w200, %fileName%
Gui, Add, Text,, MuMu Folder same as main script (C:\Program Files\Netease)
Gui, Add, Edit, vfolderPath w200, %folderPath%
Gui, Add, Button, gSaveSettings, Submit
Gui, Show, , Arturo's Account Extraction Tool ;'
Return

SaveSettings:
    Gui, Submit, NoHide
    Gui, Destroy
    IniWrite, %winTitle%, ExtractAccount.ini, UserSettings, winTitle
    IniWrite, %fileName%, ExtractAccount.ini, UserSettings, fileName
    IniWrite, %folderPath%, ExtractAccount.ini, UserSettings, folderPath

    MsgBox, Settings submitted! Extracting Account. `nIt takes a few seconds. You'll get another message box telling you it's ready.

    adbPath := folderPath . "\MuMuPlayerGlobal-12.0\shell\adb.exe"
    findAdbPorts(folderPath)

    if(!WinExist(winTitle)) {
        Msgbox, 16, , Can't find instance: %winTitle%. Make sure that instance is running.;'
        ExitApp
    }

    if !FileExist(adbPath) ;if international mumu file path isn't found look for chinese domestic path
        adbPath := folderPath . "\MuMu Player 12\shell\adb.exe"

    if !FileExist(adbPath) {
        MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
        ExitApp
    }

    if(!adbPorts) {
        Msgbox, 16, , Invalid port... Check the common issues section in the readme/github guide.
        ExitApp
    }

    RunWait, %adbPath% connect 127.0.0.1:%adbPorts%,, Hide

    MaxRetries := 10
    RetryCount := 0
    Loop {
        try {
            if (!adbShell) {
                adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s 127.0.0.1:" . adbPorts . " shell")
                ; Extract the Process ID
                processID := adbShell.ProcessID

                ; Wait for the console window to open using the process ID
                WinWait, ahk_pid %processID%

                ; Minimize the window using the process ID
                WinMinimize, ahk_pid %processID%

                adbShell.StdIn.WriteLine("su")
            }
            else if (adbShell.Status != 0) {
                Sleep, 1000
            }
            else {
                Sleep, 1000
                break
            }
        }
        catch {
            RetryCount++
            if(RetryCount > MaxRetries) {
                Msgbox, Failed to connect to the shell. Try restarting your pc/instances and try again.
                ExitApp
            }
        }
        Sleep, 1000
    }

    saveAccount()

ExitApp
return

findAdbPorts(baseFolder := "C:\Program Files\Netease") {
    global adbPorts, winTitle
    ; Initialize variables
    adbPorts := 0  ; Create an empty associative array for adbPorts
    mumuFolder = %baseFolder%\MuMuPlayerGlobal-12.0\vms\*
    if !FileExist(mumuFolder)
        mumuFolder = %baseFolder%\MuMu Player 12\vms\*

    if !FileExist(mumuFolder){
        MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
        ExitApp
    }
    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolder%, D  ; D flag to include directories only
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"  ; The config folder inside each directory

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
                if(playerName1 = winTitle) {
                    adbPorts := adbPort
                }
            }
        }
    }
}

saveAccount() {
    global adbShell, adbPath, adbPorts, fileName
    if (!adbShell) {
        adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s 127.0.0.1:" . adbPorts . " shell")
        ; Extract the Process ID
        processID := adbShell.ProcessID

        ; Wait for the console window to open using the process ID
        WinWait, ahk_pid %processID%

        ; Minimize the window using the process ID
        WinMinimize, ahk_pid %processID%
    }

    saveDir := A_ScriptDir "\" . fileName . ".xml"

    if(FileExist(saveDir)) {
        MsgBox, 16, , File already exists! Delete it or input a different name then try again!
        ExitApp
    }

    count := 0

    Loop {

        adbShell.StdIn.WriteLine("rm /sdcard/deviceAccount.xml")

        Sleep, 500

        adbShell.StdIn.WriteLine("cp /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")

        Sleep, 500

        RunWait, % adbPath . " -s 127.0.0.1:" . adbPorts . " pull /sdcard/deviceAccount.xml """ . saveDir,, Hide

        Sleep, 500

        FileGetSize, OutputVar, %saveDir%

        if(OutputVar > 0)
            break

        if(count > 10) {
            MsgBox, 16, , Tried 10 times. Failed to extract account.
            ExitApp
        }
        count++
    }

    adbShell.StdIn.WriteLine("am force-stop jp.pokemon.pokemontcgp")

    adbShell.StdIn.WriteLine("rm /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") ; delete account data

    MsgBox, Success! Extracted account '%fileName%.xml' to the Accounts folder, closed the game, and deleted the local save from the instance.
}
