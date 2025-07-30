#SingleInstance on
;SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
;SetWinDelay, -1
;SetControlDelay, -1
SetBatchLines, -1
SetTitleMatchMode, 3

global adbShell, adbPath, adbPorts, winTitle, folderPath, selectedFilePath

IniRead, winTitle, InjectAccount.ini, UserSettings, winTitle, 1
IniRead, fileName, InjectAccount.ini, UserSettings, fileName, name
IniRead, folderPath, InjectAccount.ini, UserSettings, folderPath, C:\Program Files\Netease
IniRead, selectedFilePath, InjectAccount.ini, UserSettings, selectedFilePath, ""

; Set a custom font and size for better appearance
Gui, Font, s10, Segoe UI
Gui, Color, 1E1E1E  ; Dark background color
Gui, Font, cDCDCDC  ; Light text color

; Add a title with warning styling
Gui, Add, Text, x10 y10 w450 cRed, This tool is to INJECT the account into the instance.
Gui, Add, Text, x10 y+5 w450 cRed, It will OVERWRITE any current account in that instance and you will LOSE it!

; Create a horizontal line for visual separation
Gui, Add, Text, x10 y+15 w450 h1 0x10 c3F3F3F ; Darker separator

; Instance section
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
Gui, Add, Text, x10 y+15, Instance Name:
Gui, Add, DropDownList, x10 y+5 vwinTitle w200 Choose%selectedIndex%, %instanceList%
Gui, Add, Button, x+10 yp w80 gRefreshInstances, Refresh

; File section
Gui, Add, Text, x10 y+15 cDCDCDC, File Name (without spaces and without .xml):
Gui, Add, Edit, x10 y+5 vfileName w300 c000000 BackgroundFFFFFF, %fileName%
Gui, Add, Button, x+10 yp w80 gBrowseFile, Browse

; Folder section
Gui, Add, Text, x10 y+15 cDCDCDC, MuMu Folder same as main script (C:\Program Files\Netease)
Gui, Add, Edit, x10 y+5 vfolderPath w300 c000000 BackgroundFFFFFF, %folderPath%

; Add another separator
Gui, Add, Text, x10 y+15 w450 h1 0x10 c3F3F3F ; Darker separator

; Submit button with better styling - making it more prominent
; Submit and Run Instance buttons centered with adjusted spacing
Gui, Add, Button, x130 y+30 w100 h40 gSaveSettings cBlue, Submit
Gui, Add, Button, x+10 yp w100 h40 gRunInstance cGreen, Run Instance

; Show the GUI with a proper size
Gui, Show, w470 h400, Arturo's Account Injection Tool ;'
Return

OnGuiClose:
    ExitApp

GuiClose:
    ExitApp

BrowseFile:
    FileSelectFile, selectedFile, 3, , Select XML File, XML Files (*.xml)
    if (selectedFile != "")
    {
        SplitPath, selectedFile, fileNameNoExt, , , fileNameNoExtNoPath
        GuiControl,, fileName, %fileNameNoExtNoPath%
        selectedFilePath := selectedFile
    }
    return

SaveSettings:
    Gui, Submit, NoHide
    ; Removed: Gui, Destroy
    IniWrite, %winTitle%, InjectAccount.ini, UserSettings, winTitle
    IniWrite, %fileName%, InjectAccount.ini, UserSettings, fileName
    IniWrite, %folderPath%, InjectAccount.ini, UserSettings, folderPath
    IniWrite, %selectedFilePath%, InjectAccount.ini, UserSettings, selectedFilePath

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

filePath := selectedFilePath
if (filePath = "")
    filePath := A_ScriptDir . "\" . fileName . ".xml"

if(!FileExist(filePath)) {
    Msgbox, 16, , Can't find XML file: %filePath% ;'
    ExitApp
}
RunWait, %adbPath% connect 127.0.0.1:%adbPorts%,, Hide

MaxRetries := 10
    RetryCount := 0
    Loop {
        try {
            if (!adbShell) {
                adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s 127.0.0.1:" . adbPorts . " shell")
                processID := adbShell.ProcessID
                WinWait, ahk_pid %processID%
                WinMinimize, ahk_pid %processID%  ; Minimize immediately after window appears
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
                Pause
            }
        }
        Sleep, 1000
    }

    loadAccount()
    if (adbShell) {
        WinClose, ahk_pid %processID%  ; Force close the window
        adbShell.Terminate()
        adbShell := ""
    }
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

loadAccount() {
    global adbShell, adbPath, adbPorts, fileName, selectedFilePath

    static UserPreferencesPath := "/data/data/jp.pokemon.pokemontcgp/files/UserPreferences/v1/"
    static UserPreferences := ["BattleUserPrefs"
        ,"FeedUserPrefs"
        ,"FilterConditionUserPrefs"
        ,"HomeBattleMenuUserPrefs"
        ,"MissionUserPrefs"
        ,"NotificationUserPrefs"
        ,"PackUserPrefs"
        ,"PvPBattleResumeUserPrefs"
        ,"RankMatchPvEResumeUserPrefs"
        ,"RankMatchUserPrefs"
        ,"SoloBattleResumeUserPrefs"
        ,"SortConditionUserPrefs"]

    if (!adbShell) {
        adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s 127.0.0.1:" . adbPorts . " shell")
        ; Extract the Process ID
        processID := adbShell.ProcessID

        ; Wait for the console window to open using the process ID
        WinWait, ahk_pid %processID%

        ; Minimize the window using the process ID
        WinMinimize, ahk_pid %processID%
    }

    adbShell.StdIn.WriteLine("am force-stop jp.pokemon.pokemontcgp")
    Sleep, 200

    ; Clear app data to ensure no previous account information remains
    adbShell.StdIn.WriteLine("rm -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml")
    Sleep, 200

    Loop, % UserPreferences.MaxIndex() {
        adbShell.StdIn.WriteLine("rm -f " . UserPreferencesPath . UserPreferences[A_Index])
        Sleep, 200
    }

    loadDir := selectedFilePath
    if (loadDir = "")
        loadDir := A_ScriptDir . "\" . fileName . ".xml"
    else {
        ; Don't append .xml if the path already ends with it
        SplitPath, loadDir, , , fileExt
        if (fileExt != "xml")
            loadDir := loadDir . ".xml"
    }

    ; Make sure the file exists before trying to push it
    if (!FileExist(loadDir)) {
        MsgBox, 16, Error, Cannot find the XML file: %loadDir%
        ExitApp
    }

    ; Push the file to the device with better error handling
    RunWait, % adbPath . " -s 127.0.0.1:" . adbPorts . " push """ . loadDir . """ /sdcard/deviceAccount.xml",, Hide
    Sleep, 150

    ; Create the shared_prefs directory if it doesn't exist
    adbShell.StdIn.WriteLine("mkdir -p /data/data/jp.pokemon.pokemontcgp/shared_prefs")
    Sleep, 100

    ; Copy the file with proper permissions
    adbShell.StdIn.WriteLine("cp /sdcard/deviceAccount.xml /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml")
    Sleep, 100

    ; Set proper permissions and ownership (combined commands with shorter delay)
    adbShell.StdIn.WriteLine("chmod 664 /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml && chown system:system /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml")
    Sleep, 200

    ; Clean up and launch app (reduced delay between operations)
    adbShell.StdIn.WriteLine("rm /sdcard/deviceAccount.xml")

    ; Launch the app with both commands in quick succession
    adbShell.StdIn.WriteLine("am start -n jp.pokemon.pokemontcgp/jp.pokemon.pokemontcgp.UnityPlayerActivity")
    Sleep, 100

    adbShell.StdIn.WriteLine("am start -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity")

    ; Close the shell after all operations complete
    adbShell.Terminate()
    adbShell := ""
}

; New function to get instance list
GetInstanceList(baseFolder) {
    instanceList := ""
    mumuFolder := baseFolder . "\MuMuPlayerGlobal-12.0"
    if !FileExist(mumuFolder)
        mumuFolder := baseFolder . "\MuMu Player 12"

    ; Loop through all VM directories
    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"

        if InStr(FileExist(configFolder), "D") {
            extraConfigFile := configFolder "\extra_config.json"

            if FileExist(extraConfigFile) {
                FileRead, fileContent, %extraConfigFile%
                RegExMatch(fileContent, """playerName"":\s*""(.*?)""", playerName)
                if (playerName1 != "") {
                    if (instanceList != "")
                        instanceList .= "|"
                    instanceList .= playerName1
                }
            }
        }
    }

    return instanceList
}

; Refresh button handler
RefreshInstances:
    refreshedList := GetInstanceList(folderPath)
    GuiControl,, winTitle, |%refreshedList%
    return

RunInstance:
    Gui, Submit, NoHide
    ; Find the MuMu folder
    mumuFolder := folderPath . "\MuMuPlayerGlobal-12.0"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMu Player 12"
    ; Find the instance number matching the selected name
    instanceNum := ""
    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"
        if InStr(FileExist(configFolder), "D") {
            extraConfigFile := configFolder "\extra_config.json"
            if FileExist(extraConfigFile) {
                FileRead, fileContent, %extraConfigFile%
                RegExMatch(fileContent, """playerName"":\s*""(.*?)""", playerName)
                if (playerName1 = winTitle) {
                    RegExMatch(folder, "[^-]+$", instanceNum)
                    break
                }
            }
        }
    }
    if (instanceNum != "") {
        mumuExe := mumuFolder . "\shell\MuMuPlayer.exe"
        if FileExist(mumuExe) {
            Run, "%mumuExe%" -v "%instanceNum%"
        } else {
            MsgBox, 16, Error, Could not find MuMuPlayer.exe at %mumuExe%
        }
    } else {
        MsgBox, 16, Error, Could not find instance number for %winTitle%
    }
    return
