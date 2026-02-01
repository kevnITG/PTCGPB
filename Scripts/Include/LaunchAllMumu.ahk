#Include %A_ScriptDir%\Utils.ahk

#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

settingsPath := A_ScriptDir "\..\..\Settings.ini"

IniRead, instanceLaunchDelay, %settingsPath%, UserSettings, instanceLaunchDelay, 5
IniRead, waitAfterBulkLaunch, %settingsPath%, UserSettings, waitAfterBulkLaunch, 40000
IniRead, Instances, %settingsPath%, UserSettings, Instances, 1
IniRead, folderPath, %settingsPath%, UserSettings, folderPath, C:\Program Files\Netease
IniRead, runMain, %settingsPath%, UserSettings, runMain, 1
IniRead, Mains, %settingsPath%, UserSettings, Mains, 1

mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder)
    mumuFolder = %folderPath%\MuMu Player 12
if !FileExist(mumuFolder) ;MuMu Player 12 v5 supported
    mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder) ;MuMu Player 12 v5 supported
    mumuFolder = %folderPath%\MuMu Player 12
if !FileExist(mumuFolder) ;MuMu Player 12 v5 supported
    mumuFolder = %folderPath%\MuMuPlayer
if !FileExist(mumuFolder){
    MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
    ExitApp
}

; Loop through each instance, check if it's started, and start it if it's not
launched := 0

; Allows launching Main2, Main3, etc.
if(runMain && Mains > 0)
{
    Loop %Mains% {
        instanceNum := "Main" . (A_Index > 1 ? A_Index : "")
        pID := checkInstance(instanceNum)
        if not pID {
            launchInstance(instanceNum)

            sleepTime := instanceLaunchDelay * 1000
            Sleep, % sleepTime
            launched := launched + 1
        }
    }
}

Loop %Instances% {
    instanceNum := Format("{:u}", A_Index)
    pID := checkInstance(instanceNum)
    if not pID {
        launchInstance(instanceNum)

        sleepTime := instanceLaunchDelay * 1000
        Sleep, % sleepTime
        launched := launched + 1
    }
}

ExitApp





killInstance(instanceNum := "")
{
    pID := checkInstance(instanceNum)
    if pID {
        Process, Close, %pID%
    }
}

checkInstance(instanceNum := "")
{
    ret := WinExist(instanceNum)
    if(ret)
    {
        WinGet, temp_pid, PID, ahk_id %ret%
        return temp_pid
    }

    return ""
}

launchInstance(instanceNum := "")
{
    global mumuFolder

    if(instanceNum != "") {
        mumuNum := getMumuInstanceNum(instanceNum, mumuFolder)
        if(mumuNum != "") {
            mumuExe := mumuFolder . "\shell\MuMuPlayer.exe"
            if !FileExist(mumuExe)
                mumuExe := mumuFolder . "\nx_main\MuMuNxMain.exe"
            Run_(mumuExe, "-v " . mumuNum)
        }
    }
}
