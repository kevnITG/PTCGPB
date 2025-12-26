#Include %A_ScriptDir%\Logging.ahk

#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

if not A_IsAdmin
{
    ; Relaunch script with admin rights
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

global useADBManager

settingsPath := A_ScriptDir "\..\..\Settings.ini"

IniRead, instanceLaunchDelay, %settingsPath%, UserSettings, instanceLaunchDelay, 5
IniRead, waitAfterBulkLaunch, %settingsPath%, UserSettings, waitAfterBulkLaunch, 40000
IniRead, Instances, %settingsPath%, UserSettings, Instances, 1
IniRead, folderPath, %settingsPath%, UserSettings, folderPath, C:\Program Files\Netease
IniRead, useADBManager, %settingsPath%, UserSettings, useADBManager, 0
IniRead, AutoDiskClean, %settingsPath%, UserSettings, AutoDiskClean, 0

mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder)
    mumuFolder = %folderPath%\MuMu Player 12

; Set MuMuManager.exe location
mumuManagerPath := mumuFolder "\shell\MuMuManager.exe"

if !FileExist(mumuFolder){
    MsgBox, 16, , Can't Find MuMu folder! Double check your folderPath in Settings.ini.`nDefault is C:\Program Files\Netease
    ExitApp
}

Loop {
    nowEpoch := A_NowUTC
    EnvSub, nowEpoch, 1970, seconds

    InstancesWithXmls := Instances

    Loop %Instances% {
        instanceNum := Format("{:u}", A_Index)

        ; Instance .ini files are one level up (new structure)
        instanceIni := A_ScriptDir "\..\" instanceNum ".ini"
        
        IniRead, LastEndEpoch, %instanceIni%, Metrics, LastEndEpoch, 0
        IniRead, deleteMethod, %A_ScriptDir%\..\%instanceNum%.ini, UserSettings, deleteMethod, Create Bots (13P)
        secondsSinceLastEnd := nowEpoch - LastEndEpoch
        
        if(LastEndEpoch > 0 && secondsSinceLastEnd > (5 * 60))
        {
            ; Directly count .xml files older than 24 hours in the instance's Saved folder
            saveDir := A_ScriptDir "\..\..\Accounts\Saved\" . instanceNum
            
            ; If it's in account creation mode dont kill the instance based on xmls>24hr count.
            if(deleteMethod == "Create Bots (13P)"){
                nonEmptyLines := 999
                ; wait 30 min before calling it stuck
                stuckThreshold := 30 * 60
            } else {
                nonEmptyLines := CountOldXmlFiles(saveDir)
                ; wait 15 min before calling it stuck
                stuckThreshold := 15 * 60
            }

            ; Determine what action to take
            doShutdown := false
            doRestart := false

            msg := "Instance " . instanceNum . ": " . nonEmptyLines . " accounts >24h old, last end " . secondsSinceLastEnd . "s ago"
            LogToFile(msg, "Monitor.txt")

            if (nonEmptyLines = 0) {
                ; No account left → safe to shut down (saves RAM/CPU)
                doShutdown := true
                InstancesWithXmls--
                LogToFile("Instance " . instanceNum . " has no remaining accounts. Scheduling shutdown.", "Monitor.txt")
            }
            else if (secondsSinceLastEnd > stuckThreshold) {
                ; Has account but no progress for 15+ min → likely frozen
                doRestart := true
                LogToFile("Instance " . instanceNum . " appears stuck (idle " . secondsSinceLastEnd . "s). Scheduling kill + restart.", "Monitor.txt")
            }
            else {
                ; Has accounts and recent activity → everything is fine
                LogToFile("Instance " . instanceNum . " is running normally.", "Monitor.txt")
            }

            ; Only act if needed
            if (doShutdown || doRestart) {
                ; --- Kill phase (common to both shutdown and restart) ---
                scriptName := instanceNum . ".ahk"
                killAHK(scriptName)
                
                if (useADBManager) {
                    adbScriptName := instanceNum . ".adbmanager.ahk"
                    killAHK(adbScriptName)
                }
                
                killInstance(instanceNum)
                
                ; Verify everything is actually dead
                cntAHK := checkAHK(scriptName)
                cntADB := useADBManager ? checkAHK(adbScriptName) : 0
                pID := checkInstance(instanceNum)
                
                if (pID || cntAHK || (useADBManager && cntADB)) {
                    LogToFile("Failed to fully terminate instance " . instanceNum . " during cleanup.", "Monitor.txt")
                } else {
                    LogToFile("Successfully terminated processes for instance " . instanceNum, "Monitor.txt")
                }
            }

            ; --- Restart phase (only if needed) ---
            if (doRestart) {
                ; Update timestamp to prevent immediate re-trigger
                IniWrite, %nowEpoch%, %instanceIni%, Metrics, LastEndEpoch
                
                ; Optional: clean disk and signal cache clear
                if (AutoDiskClean)
                    cleanInstanceDisk(instanceNum)
                                
                ; Launch emulator
                launchInstance(instanceNum)
                Sleep, % instanceLaunchDelay * 1000
                Sleep, %waitAfterBulkLaunch%
                
                ; Relaunch bot scripts
                scriptPath := A_ScriptDir "\..\" scriptName
                if (useADBManager) {
                    adbScriptPath := A_ScriptDir "\..\" adbScriptName
                    Run "%A_AhkPath%" /restart "%adbScriptPath%"
                    Sleep, 2000
                }
                Run "%A_AhkPath%" /restart "%scriptPath%"
                
                LogToFile("Restarted instance " . instanceNum . " and bot script(s).", "Monitor.txt")
            }
            
        }
    }

    if(InstancesWithXmls < 1){
        LogToFile("All instances have finished processing accounts (no Create Bots mode). Performing final cleanup and exiting.", "Monitor.txt")

        ; Kill all bot scripts
        Loop %Instances% {
            instanceNum := Format("{:u}", A_Index)
            killAHK(instanceNum . ".ahk")
            if (useADBManager)
                killAHK(instanceNum . ".adbmanager.ahk")
        }
        
        ; Kill all MuMu emulator instances
        Loop %Instances% {
            killInstance(A_Index)
        }
        
        ; Optional: kill other global scripts if still running
        killAHK("Main.ahk")
        killAHK("PTCGPB.ahk")
        killAHK("ControlPanel.ahk")
        
        ; Final log and exit
        LogToFile("Final cleanup complete. Monitor exiting.", "Monitor.txt")
        ExitApp

    }

    Sleep, 30000
}

killAHK(scriptName := "")
{
    killed := 0
    maxRetries := 3
    retryDelay := 2000

    if(scriptName != "") {
        DetectHiddenWindows, On
        WinGet, IDList, List, ahk_class AutoHotkey
        Loop %IDList%
        {
            ID:=IDList%A_Index%
            WinGetTitle, ATitle, ahk_id %ID%
            if InStr(ATitle, "\" . scriptName) {
                WinGet, pid, PID, ahk_id %ID%
                WinKill, ahk_id %ID%
                killed++

                Process, Exist, %pid%
                if (ErrorLevel) {
                    Loop %maxRetries% {
                        RunWait, taskkill /f /pid %pid% /t,, Hide
                        Sleep %retryDelay%
                        Process, Exist, %pid%
                        if (!ErrorLevel)
                            break
                    }
                }
            }
        }
    }
    return killed
}

checkAHK(scriptName := "")
{
    cnt := 0
    if(scriptName != "") {
        DetectHiddenWindows, On
        WinGet, IDList, List, ahk_class AutoHotkey
        Loop %IDList%
        {
            ID:=IDList%A_Index%
            WinGetTitle, ATitle, ahk_id %ID%
            if InStr(ATitle, "\" . scriptName)
                cnt++
        }
    }
    return cnt
}

killInstance(instanceNum := "") {
    global mumuManagerPath
    killed := 0
    maxRetries := 3
    retryDelay := 2000
    
    mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
    
    if (mumuNum != "") {
        RunWait, %mumuManagerPath% api -v %mumuNum% shutdown_player,, Hide
        Sleep, 5000
        if (!checkInstance(instanceNum)) {
            killed := 1
            LogToFile("Proper shutdown via MuMuManager for instance " . instanceNum, "Monitor.txt")
            return killed
        }
    }
    
    pID := checkInstance(instanceNum)
    if pID {
        Process, Close, %pID%
        killed++
        Process, Exist, %pID%
        if (ErrorLevel) {
            Loop %maxRetries% {
                RunWait, taskkill /f /pid %pID% /t,, Hide
                Sleep %retryDelay%
                Process, Exist, %pID%
                if (!ErrorLevel)
                    break
            }
        }
        LogToFile("Fallback kill for instance " . instanceNum, "Monitor.txt")
    }
    return killed
}

checkInstance(instanceNum := "")
{
    ret := WinExist(instanceNum)
    if(ret) {
        WinGet, temp_pid, PID, ahk_id %ret%
        return temp_pid
    }
    return ""
}

launchInstance(instanceNum := "")
{
    global mumuFolder
    if(instanceNum != "") {
        mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
        if(mumuNum != "") {
            mumuExe := mumuFolder "\shell\MuMuPlayer.exe"
            if !FileExist(mumuExe)
                mumuExe := mumuFolder "\nx_main\MuMuNxMain.exe"
            Run_(mumuExe, "-v " . mumuNum)
        }
    }
}

getMumuInstanceNumFromPlayerName(scriptName := "") {
    global mumuFolder
    if(scriptName == "")
        return ""
        
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
    return ""
}

; Temporary function to avoid an error in Logging.ahk
ReadFile(filename) {
    return false
}

Run_(target, args:="", workdir:="") {
    try
        ShellRun(target, args, workdir)
    catch
        Run % args="" ? target : target " " args, % workdir
}
ShellRun(prms*)
{
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

cleanInstanceDisk(instanceNum) {
    global mumuFolder
    mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
    if (mumuNum != "") {
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
                    if(playerName1 == instanceNum) {
                        otaPath := folder "\ota.vdi"
                        if FileExist(otaPath) {
                            FileDelete, %otaPath%
                            LogToFile("Deleted ota.vdi for instance " . instanceNum, "Monitor.txt")
                        }
                        break
                    }
                }
            }
        }
    }
}

; Implement later
; checkRestartCount(instanceNum) {
;     instanceIni := A_ScriptDir "\..\" instanceNum ".ini"
;     IniRead, tooManyRestarts, %instanceIni%, RestartTracking, TooManyRestarts, 0
;     if (tooManyRestarts) {
;         IniRead, restartCount, %instanceIni%, RestartTracking, RestartCount, 0
;         LogToFile("Instance " . instanceNum . " forced recovery (" . restartCount . " restarts)", "Monitor.txt")
;         IniWrite, 0, %instanceIni%, RestartTracking, TooManyRestarts
;         IniWrite, 0, %instanceIni%, RestartTracking, RestartCount
;         return true
;     }
;     return false
; }

CountOldXmlFiles(directory) {
    count := 0
    if !FileExist(directory)
        return 0
    
    Loop, Files, %directory%\*.xml
    {
        FileGetTime, modTime, %A_LoopFileFullPath%, M
        if (modTime = "")
            continue
        
        diff := A_Now
        diff -= modTime, Hours
        if (diff >= 24)
            count++
    }
    return count
}

~+F7::ExitApp