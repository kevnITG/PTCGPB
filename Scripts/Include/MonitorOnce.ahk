#Include %A_ScriptDir%\Config.ahk
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

global botConfig := new BotConfig()
botConfig.loadSettingsToConfig("ALL")

waitAfterBulkLaunch := botConfig.get("waitAfterBulkLaunch")
instanceLaunchDelay := botConfig.get("instanceLaunchDelay")
Instances := botConfig.get("Instances")
mumuFolder := botConfig.get("folderPath")

; Loop through each instance, check if it's started, and start it if it's not
launched := 0

nowEpoch := A_NowUTC
EnvSub, nowEpoch, 1970, seconds

Loop %Instances% {
    instanceNum := Format("{:u}", A_Index)
    
    IniRead, LastEndEpoch, %A_ScriptDir%\..\%instanceNum%.ini, Metrics, LastEndEpoch, 0
    secondsSinceLastEnd := nowEpoch - LastEndEpoch
    if(LastEndEpoch > 0 && secondsSinceLastEnd > (15 * 60))
    {
        ; msgbox, Killing Instance %instanceNum%! Last Run Completed %secondsSinceLastEnd% Seconds Ago
        msg := "Killing Instance " . instanceNum . "! Last Run Completed " . secondsSinceLastEnd . " Seconds Ago"
        LogToFile(msg, "Monitor.txt")
        
        scriptName := instanceNum . ".ahk"
        coverHwnd := CaptureMuMuCoverWindow(instanceNum)
        StoreMuMuCoverWindow(instanceNum, coverHwnd)
        
        killedAHK := killAHK(scriptName)
        killedInstance := killInstance(instanceNum)
        Sleep, 3000
        
        cntAHK := checkAHK(scriptName)
        pID := checkInstance(instanceNum)
        if not pID && not cntAHK {
            ; Change the last end date to now so that we don't keep trying to restart this beast
            IniWrite, %nowEpoch%, %A_ScriptDir%\..\%instanceNum%.ini, Metrics, LastEndEpoch
            
            launchInstance(instanceNum)
            
            sleepTime := instanceLaunchDelay * 1000
            Sleep, % sleepTime
            launched := launched + 1
            
            Sleep, %waitAfterBulkLaunch%
            
            ;Command := "Scripts\" . scriptName
            ;Run, %Command%
            scriptPath := A_ScriptDir "\.." "\" scriptName
            Run, "%A_AhkPath%" /restart "%scriptPath%"
        }
    }
}

ExitApp

killAHK(scriptName := "")
{
    killed := 0
    
    if(scriptName != "") {
        DetectHiddenWindows, On
        killedPIDs := {}
        killed += killAHKWindowsByClass(scriptName, "AutoHotkey", killedPIDs)
        killed += killAHKWindowsByClass(scriptName, "#32770", killedPIDs)
        killed += killAHKWindowsByClass(scriptName, "ConsoleWindowClass", killedPIDs)
        killed += killAHKProcessesByCommandLine(scriptName, killedPIDs)
    }
    
    return killed
}

checkAHK(scriptName := "")
{
    cnt := 0
    
    if(scriptName != "") {
        DetectHiddenWindows, On
        seenPIDs := {}
        cnt += countAHKWindowsByClass(scriptName, "AutoHotkey", seenPIDs)
        cnt += countAHKWindowsByClass(scriptName, "#32770", seenPIDs)
        cnt += countAHKWindowsByClass(scriptName, "ConsoleWindowClass", seenPIDs)
        cnt += countAHKProcessesByCommandLine(scriptName, seenPIDs)
    }

    return cnt
}

killAHKWindowsByClass(scriptName, winClass, killedPIDs)
{
    killed := 0
    WinGet, IDList, List, ahk_class %winClass%
    Loop %IDList%
    {
        ID := IDList%A_Index%
        WinGetTitle, ATitle, ahk_id %ID%
        if (isAHKScriptWindowTitle(ATitle, scriptName)) {
            WinGet, ahkPID, PID, ahk_id %ID%
            if (ahkPID && !killedPIDs.HasKey(ahkPID)) {
                Process, Close, %ahkPID%
                killedPIDs[ahkPID] := true
                killed := killed + 1
            }
        }
    }

    return killed
}

countAHKWindowsByClass(scriptName, winClass, seenPIDs)
{
    cnt := 0
    WinGet, IDList, List, ahk_class %winClass%
    Loop %IDList%
    {
        ID := IDList%A_Index%
        WinGetTitle, ATitle, ahk_id %ID%
        if (isAHKScriptWindowTitle(ATitle, scriptName)) {
            WinGet, ahkPID, PID, ahk_id %ID%
            if (ahkPID && !seenPIDs.HasKey(ahkPID)) {
                seenPIDs[ahkPID] := true
                cnt := cnt + 1
            }
        }
    }

    return cnt
}

killAHKProcessesByCommandLine(scriptName, killedPIDs)
{
    killed := 0
    scriptNeedle := "\" . scriptName

    for process in ComObjGet("winmgmts:").ExecQuery("Select ProcessId, Name, CommandLine from Win32_Process Where Name like 'AutoHotkey%'")
    {
        commandLine := process.CommandLine
        if(commandLine != "" && InStr(commandLine, scriptNeedle)) {
            ahkPID := process.ProcessId
            if (ahkPID && !killedPIDs.HasKey(ahkPID)) {
                Process, Close, %ahkPID%
                killedPIDs[ahkPID] := true
                killed := killed + 1
            }
        }
    }

    return killed
}

countAHKProcessesByCommandLine(scriptName, seenPIDs)
{
    cnt := 0
    scriptNeedle := "\" . scriptName

    for process in ComObjGet("winmgmts:").ExecQuery("Select ProcessId, Name, CommandLine from Win32_Process Where Name like 'AutoHotkey%'")
    {
        commandLine := process.CommandLine
        if(commandLine != "" && InStr(commandLine, scriptNeedle)) {
            ahkPID := process.ProcessId
            if (ahkPID && !seenPIDs.HasKey(ahkPID)) {
                seenPIDs[ahkPID] := true
                cnt := cnt + 1
            }
        }
    }

    return cnt
}

isAHKScriptWindowTitle(ATitle, scriptName)
{
    return (InStr(ATitle, "\" . scriptName) || ATitle = scriptName)
}

~+F7::ExitApp
