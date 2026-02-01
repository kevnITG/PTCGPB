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

lastReduceMemory := 0
settingsPath := A_ScriptDir "\..\..\Settings.ini"

IniRead, instanceLaunchDelay, %settingsPath%, UserSettings, instanceLaunchDelay, 5
IniRead, waitAfterBulkLaunch, %settingsPath%, UserSettings, waitAfterBulkLaunch, 40000
IniRead, Instances, %settingsPath%, UserSettings, Instances, 1
IniRead, folderPath, %settingsPath%, UserSettings, folderPath, C:\Program Files\Netease
mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder)
mumuFolder := folderPath "\MuMuPlayerGlobal-12.0"
if !FileExist(mumuFolder)
    mumuFolder := folderPath "\MuMu Player 12"
if !FileExist(mumuFolder)
    mumuFolder := folderPath "\MuMuPlayerGlobal-12.0"
if !FileExist(mumuFolder)
    mumuFolder := folderPath "\MuMu Player 12"
if !FileExist(mumuFolder)
    mumuFolder := folderPath "\MuMuPlayer"

if !FileExist(mumuFolder){
    MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
    ExitApp
}

Loop {
    ; Loop through each instance, check if it's started, and start it if it's not
    launched := 0
    
    nowEpoch := A_NowUTC
    EnvSub, nowEpoch, 1970, seconds
    
    Loop %Instances% {
        if(A_TickCount - lastReduceMemory > 120000) {
            LogToFile("Memory reduction process start.", "Monitor.txt")
            ReduceVMMemory()
            LogToFile("Memory reduction process complete.", "Monitor.txt")
            lastReduceMemory := A_TickCount
        }

        instanceNum := Format("{:u}", A_Index)
        
        IniRead, LastEndEpoch, %A_ScriptDir%\..\%instanceNum%.ini, Metrics, LastEndEpoch, 0
        IniRead, deleteMethod, %A_ScriptDir%\..\%instanceNum%.ini, UserSettings, deleteMethod, Create Bots (13P)
        secondsSinceLastEnd := nowEpoch - LastEndEpoch
        ; Set threshold: 30 minutes for Create Bots, 11 minutes for others
        threshold := (deleteMethod == "Create Bots (13P)") ? (30 * 60) : (11 * 60)
        if(LastEndEpoch > 0 && secondsSinceLastEnd > threshold)
        {
            ; msgbox, Killing Instance %instanceNum%! Last Run Completed %secondsSinceLastEnd% Seconds Ago
            msg := "Killing Instance " . instanceNum . "! Last Run Completed " . secondsSinceLastEnd . " Seconds Ago"
            LogToFile(msg, "Monitor.txt")
            
            scriptName := instanceNum . ".ahk"
            
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
    
    ; Check for dead instances every 30 seconds
    Sleep, 30000
}

ReduceVMMemory(){
    TargetProcess := "MuMuVMMHeadless.exe"
    CleanedCount := 0

    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process Where Name = '" TargetProcess "'")
    {
        PID := process.ProcessId
        
        hProcess := DllCall("OpenProcess", "UInt", 0x0400 | 0x0100 | 0x0010, "Int", false, "UInt", PID)
        
        if (hProcess)
        {
            MemBefore := GetProcessMemory(hProcess)
            Success := DllCall("psapi.dll\EmptyWorkingSet", "Ptr", hProcess)
            MemAfter := GetProcessMemory(hProcess)
            
            DllCall("CloseHandle", "Ptr", hProcess)
            
            if (Success) {
                ;ResultLine := "PID: " . PID . " | Before: " . Round(MemBefore, 1) . "KB | After: " . Round(MemAfter, 1) . "KB | Reduced size: " . Round(MemBefore-MemAfter, 1) . "KB`n"
                LogToFile(ResultLine, "Development.txt")
                CleanedCount++
            }
        }
    }
    LogToFile("Total reduce memory count: " . CleanedCount, "Monitor.txt")
    return CleanedCount
}

GetProcessMemory(hProcess) {
    VarSetCapacity(PMC, 72, 0)
    if (DllCall("psapi.dll\GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", &PMC, "UInt", 72)) {
        addrOffset := (A_PtrSize = 8) ? 16 : 12
        bytes := NumGet(PMC, addrOffset, "UPtr")
        return bytes / 1024 
    }
    return 0
}

killAHK(scriptName := "")
{
    killed := 0
    
    if(scriptName != "") {
        DetectHiddenWindows, On
        WinGet, IDList, List, ahk_class AutoHotkey
        Loop %IDList%
        {
            ID:=IDList%A_Index%
            WinGetTitle, ATitle, ahk_id %ID%
            if InStr(ATitle, "\" . scriptName) {
                ; MsgBox, Killing: %ATitle%
                WinKill, ahk_id %ID% ;kill
                ; WinClose, %fullScriptPath% ahk_class AutoHotkey
                killed := killed + 1
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
            if InStr(ATitle, "\" . scriptName) {
                cnt := cnt + 1
            }
        }
    }
    
    return cnt
}

killInstance(instanceNum := "")
{
    killed := 0
    
    pID := checkInstance(instanceNum)
    if pID {
        Process, Close, %pID%
        killed := killed + 1
    }
    
    return killed
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

~+F7::ExitApp