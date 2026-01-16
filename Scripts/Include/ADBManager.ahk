#SingleInstance, force
#Persistent
DetectHiddenWindows, On
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

#Include %A_ScriptDir%\Logging.ahk
#Include %A_ScriptDir%\Utils.ahk

global NOTIFY_ADB_SERVER_HANG := 0x9000
global isADBHang := false
global hangInstanceNo := 0
global emulatorStatus := 0
global failTime := ""
global Instances := 1
global heartBeatWebhookURL := ""

IniRead, Instances, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Instances, 1
IniRead, heartBeatWebhookURL, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatWebhookURL, ""

OnMessage(NOTIFY_ADB_SERVER_HANG, "procADBManager")
return

~+F7::ExitApp

procADBManager(wParam, lParam)
{
    global isADBHang, Instances
    sourceScript := lParam . ".ahk"
    ; wParam value
    ; 10: ADB Server Down. So waiting until recovery ADB Server
    ; 20: Wait for all instances to acknowledge waiting
    ; 30: Recovery ADB Server
    ; 40: Reconnect to ADB Server and Resume operations
    if (wParam = 10) {
        if(!isADBHang){
            LogToDiscord("[ADBManager] Found hang in ADB server. Hang instance: " . lParam . " Recovery start!",, true,,, heartBeatWebhookURL)
            LogToFile("[ADBManager] Found ADB Server Hang. Instance: " . lParam, "ADB.txt")
            isADBHang := true
            failTime := A_Now
            hangInstanceNo := lParam
            setADBStatus(emulatorStatus, lParam, "WAIT")
            sendNotifyADBStatus(20, hangInstanceNo)
            LogToFile("[ADBManager] Waiting all instance to standby.", "ADB.txt")
        }
        else{
            LogToFile("[ADBManager] Already found hang. Message From: " . lParam . ", Prev hang Instance: " . hangInstanceNo, "ADB.txt")
            sendNotifyADBStatus(20, hangInstanceNo)
        }

    }
    else if(wParam = 21) {
        setADBStatus(emulatorStatus, hangInstanceNo, "WAIT")
        setADBStatus(emulatorStatus, lParam, "WAIT")
        checkResult := checkAllADBStatus(emulatorStatus, Instances)
        if(checkResult = "ALL"){
            LogToFile("[ADBManager] All instances have entered standby mode.", "ADB.txt")
            sendNotifyADBStatus(30, hangInstanceNo, A_ScriptName)
        }
        else
            sendNotifyADBStatus(20, hangInstanceNo)
    }
    else if (wParam = 30) {
        Sleep, 500
        LogToFile("[ADBManager] Start restore ADB Shell.", "ADB.txt")
        LogToFile("[ADBManager] Killing all ADB processses.", "ADB.txt")
        KillADBProcesses()
        LogToFile("[ADBManager] Restart hold instance.", "ADB.txt")
        restartInstance(hangInstanceNo)
        Sleep, 10000
        LogToFile("[ADBManager] Recovered ADB Server.", "ADB.txt")
        sendNotifyADBStatus(40, hangInstanceNo)

        isADBHang := false
        hangInstanceNo := 0
        emulatorStatus := 0
        
        failRecoveryTimeDiff := A_Now
        EnvSub, failRecoveryTimeDiff, %failTime%, Seconds
        LogToDiscord("[ADBManager] ADB server recovered. Total time: " . failRecoveryTimeDiff . " seconds",, true,,, heartBeatWebhookURL)
        failTime := ""
    }
    else if(wParam = 50){
        lParamValue := 0 ; Not Hang
        if(isADBHang)
            lParamValue := 1 ; Hang

        sendNotifyADBStatus(51, lParamValue, sourceScript)
    }
}

restartInstance(instanceNum)
{ 
    IniRead, folderPath, %A_ScriptDir%\..\..\Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
    mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
    if !FileExist(mumuFolder)
        mumuFolder = %folderPath%\MuMu Player 12
    if !FileExist(mumuFolder){
        MsgBox, 16, , Can't Find MuMu, try old MuMu installer in Discord #announcements, otherwise double check your folder path setting!`nDefault path is C:\Program Files\Netease
        ExitApp
    }

    killed := 0
    temp_pid := -1
    
    pID := WinExist(instanceNum . " ahk_class Qt5156QWindowIcon")
    if(pID)
    {
        WinGet, temp_pid, PID, ahk_id %pID%
        Process, Close, %temp_pid%
    }
    
    if(instanceNum != "") {
        mumuNum := ""
        
        ; Loop through all directories in the base folder
        Loop, Files, %mumuFolder%\vms\*, D ; D flag to include directories only
        {
            folder := A_LoopFileFullPath
            configFolder := folder "\configs" ; The config folder inside each directory
            
            ; Check if config folder exists
            IfExist, %configFolder%
            {
                ; Define paths to vm_config.json and extra_config.json
                extraConfigFile := configFolder "\extra_config.json"
                
                ; Check if extra_config.json exists and read playerName
                IfExist, %extraConfigFile%
                {
                    FileRead, extraConfigContent, %extraConfigFile%
                    ; Parse the JSON for playerName
                    RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                    if(playerName1 == instanceNum) {
                        RegExMatch(A_LoopFileFullPath, "[^-]+$", mumuNum)
                    }
                }
            }
        }

        if(mumuNum != "") {
            ; Run, %mumuFolder%\shell\MuMuPlayer.exe -v %mumuNum%
            ; Run_(mumuFolder . "\shell\MuMuPlayer.exe", "-v " . mumuNum)
            mumuExe := mumuFolder . "\shell\MuMuPlayer.exe"
            if !FileExist(mumuExe)
                mumuExe := mumuFolder . "\nx_main\MuMuNxMain.exe"
            Run_(mumuExe, "-v " . mumuNum)
        }
    }
}