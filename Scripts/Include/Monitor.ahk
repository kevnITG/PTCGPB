#Include %A_ScriptDir%\Logging.ahk
#Include %A_ScriptDir%\Utils.ahk

#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

if not A_IsAdmin
{
    ; Relaunch script with admin rights
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

Menu, Tray, Icon, %A_ScriptDir%\..\..\GUI\Icons\monitor.ico

global Columns, runMain, Mains, defaultLanguage, scaleParam, SelectedMonitorIndex, titleHeight, MuMuv5
global useADBManager

settingsPath := A_ScriptDir "\..\..\Settings.ini"
IniRead, instanceLaunchDelay, %settingsPath%, UserSettings, instanceLaunchDelay, 5
IniRead, waitAfterBulkLaunch, %settingsPath%, UserSettings, waitAfterBulkLaunch, 40000
IniRead, Instances, %settingsPath%, UserSettings, Instances, 1
IniRead, folderPath, %settingsPath%, UserSettings, folderPath, C:\Program Files\Netease
IniRead, useADBManager, %settingsPath%, UserSettings, useADBManager, 0
IniRead, AutoDiskClean, %settingsPath%, UserSettings, AutoDiskClean, 0
IniRead, runMain, %settingsPath%, UserSettings, runMain, 1
IniRead, Mains, %settingsPath%, UserSettings, Mains, 1
IniRead, defaultLanguage, %settingsPath%, UserSettings, defaultLanguage, Scale125
IniRead, Columns, %settingsPath%, UserSettings, Columns, 5
IniRead, SelectedMonitorDeviceName, %settingsPath%, UserSettings, SelectedMonitorDeviceName, "\\.\DISPLAY1"

SelectedMonitorIndex := GetMonitorIndexFromDeviceName(SelectedMonitorDeviceName)

MuMuv5 := isMuMuv5()

if (InStr(defaultLanguage, "100")) {
    scaleParam := 287
} else {
    if (MuMuv5) {
        scaleParam := 283
    } else {
        scaleParam := 277
    }
}

mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder)
    mumuFolder = %folderPath%\MuMu Player 12
if !FileExist(mumuFolder)
    mumuFolder = %folderPath%\MuMuPlayer

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
                ; wait 11 min before calling it stuck
                stuckThreshold := 11 * 60
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
                ; if (AutoDiskClean)
                ;     cleanInstanceDisk(instanceNum)
                                
                ; Launch emulator with retry
                launchSuccess := false
                Loop, 3 {
                    launchInstance(instanceNum)
                    Sleep, % instanceLaunchDelay * 1000
                    Sleep, %waitAfterBulkLaunch%
                    
                    if (checkInstance(instanceNum)) {
                        launchSuccess := true
                        break
                    }
                    LogToFile("Attempt " . A_Index . "/3: Failed to detect running instance " . instanceNum . " after launch.", "Monitor.txt")
                    Sleep, 10000  ; 10 sec delay before retry
                }
                
                if (!launchSuccess) {
                    LogToFile("FAILED: Could not successfully launch instance " . instanceNum . " after 3 attempts.", "Monitor.txt")
                } else {
                    ; Position the window
                    DirectlyPositionWindow(instanceNum)
                    Sleep, % instanceLaunchDelay * 500
                    
                    ; Relaunch bot scripts with retry
                    scriptPath := A_ScriptDir "\..\" scriptName
                    scriptSuccess := false
                    
                    if (useADBManager) {
                        adbScriptPath := A_ScriptDir "\..\" adbScriptName
                        Loop, 3 {
                            Run "%A_AhkPath%" /restart "%adbScriptPath%"
                            Sleep, 2000
                            
                            if (checkAHK(adbScriptName)) {
                                scriptSuccess := true
                                break
                            }
                            LogToFile("Attempt " . A_Index . "/3: Failed to detect running " . adbScriptName, "Monitor.txt")
                            Sleep, 3000
                        }
                        
                        if (!scriptSuccess) {
                            LogToFile("FAILED: Could not successfully launch ADB manager script " . adbScriptName . " after 3 attempts.", "Monitor.txt")
                        }
                    }
                    
                    ; Main bot script
                    scriptSuccess := false
                    Loop, 3 {
                        Run "%A_AhkPath%" /restart "%scriptPath%"
                        Sleep, 2000
                        
                        if (checkAHK(scriptName)) {
                            scriptSuccess := true
                            break
                        }
                        LogToFile("Attempt " . A_Index . "/3: Failed to detect running " . scriptName, "Monitor.txt")
                        Sleep, 3000
                    }
                    
                    if (!scriptSuccess) {
                        LogToFile("FAILED: Could not successfully launch main bot script " . scriptName . " after 3 attempts.", "Monitor.txt")
                    } else {
                        LogToFile("Restarted instance " . instanceNum . " and bot script(s).", "Monitor.txt")
                    }
                }
                
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
    
    ; --- 1. Graceful API shutdown ---
    mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
    if (mumuNum != "") {
        RunWait, %mumuManagerPath% api -v %mumuNum% shutdown_player,, Hide
        Sleep, 8000
        if (!checkInstance(instanceNum)) {
            LogToFile("Proper shutdown via MuMuManager for instance " . instanceNum, "Monitor.txt")
            return 1
        }
        LogToFile("API shutdown attempted but instance " . instanceNum . " still running – falling back.", "Monitor.txt")
    }

    ; --- 2. WinKill on window title ---
    if (WinExist(instanceNum)) {
        WinKill, % instanceNum
        WinWaitClose, % instanceNum,, 6
        if (ErrorLevel) {
            WinKill, % instanceNum
            Sleep, 3000
        }

        if (!checkInstance(instanceNum)) {
            LogToFile("Successfully terminated instance " . instanceNum . " via WinKill.", "Monitor.txt")
            return 1
        }
        LogToFile("WinKill attempted but instance partially remains – trying PID force kill.", "Monitor.txt")
    }
    
    ; --- 3. Final PID hard kill ---
    pID := checkInstance(instanceNum)
    if (pID) {
        Process, Close, %pID%
        Sleep, 2000
        Process, Exist, %pID%
        if (ErrorLevel) {
            Loop, 3 {
                RunWait, taskkill /f /pid %pID%,, Hide
                Sleep, 2000
                Process, Exist, %pID%
                if (!ErrorLevel)
                    break
            }
        }
        LogToFile("Fallback PID force kill applied for instance " . instanceNum, "Monitor.txt")
        killed := 1
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

DirectlyPositionWindow(instanceNum := "") {
    global Columns, runMain, Mains, scaleParam, SelectedMonitorIndex, titleHeight

    rowGap := 100

    ; Get monitor information
    SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
    SysGet, Monitor, Monitor, %SelectedMonitorIndex%

    ; Calculate position based on instance number
    Title := instanceNum

    if (runMain) {
        instanceIndex := (Mains - 1) + Title + 1
    } else {
        instanceIndex := Title
    }

    if (MuMuv5) {
        titleHeight := 50
    } else {
        titleHeight := 45
    }

    borderWidth := 4 - 1
    rowHeight := titleHeight + 489 + 4
    currentRow := Floor((instanceIndex - 1) / Columns)

    y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
    ;x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
    if (MuMuv5) {
        x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * (scaleParam - borderWidth * 2)) - borderWidth
    } else {
        x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
    }

    WinSet, Style, -0xC00000, %Title%
    WinMove, %Title%, , %x%, %y%, %scaleParam%, %rowHeight%
    WinSet, Style, +0xC00000, %Title%
    WinSet, Redraw, , %Title%

    CreateStatusMessage("Positioned window at x:" . x . " y:" . y,,,, false)

    return true
}


~+F7::ExitApp