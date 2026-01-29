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

lastReduceMemory := 0
settingsPath := A_ScriptDir "\..\..\Settings.ini"

IniRead, instanceLaunchDelay, %settingsPath%, UserSettings, instanceLaunchDelay, 5
IniRead, waitAfterBulkLaunch, %settingsPath%, UserSettings, waitAfterBulkLaunch, 40000
IniRead, Instances, %settingsPath%, UserSettings, Instances, 1
IniRead, folderPath, %settingsPath%, UserSettings, folderPath, C:\Program Files\Netease
mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder)
mumuFolder = %folderPath%\MuMu Player 12
if !FileExist(mumuFolder) ;MuMu Player 12 v5 supported
    mumuFolder := %folderPath%\MuMuPlayerGlobal-12.0\nx_main
if !FileExist(mumuFolder) ;MuMu Player 12 v5 supported
    mumuFolder := %folderPath%\MuMu Player 12\nx_main
if !FileExist(mumuFolder) ;MuMu Player 12 v5 supported
    mumuFolder := %folderPath%\MuMuPlayer\nx_main
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
        mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
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

getMumuInstanceNumFromPlayerName(scriptName := "") {
    global mumuFolder
    
    if(scriptName == "") {
        return ""
    }
    
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
                if(playerName1 == scriptName) {
                    RegExMatch(A_LoopFileFullPath, "[^-]+$", mumuNum)
                    return mumuNum
                }
            }
        }
    }
}

; Temporary function to avoid an error in Logging.ahk
ReadFile(filename) {
    return false
}

; Function to run as a NON-adminstrator, since MuMu has issues if run as Administrator
; See: https://www.reddit.com/r/AutoHotkey/comments/bfd6o1/how_to_run_without_administrator_privileges/
/*
  ShellRun by Lexikos
    requires: AutoHotkey v1.1
    license: http://creativecommons.org/publicdomain/zero/1.0/
  
  Credit for explaining this method goes to BrandonLive:
  http://brandonlive.com/2008/04/27/getting-the-shell-to-run-an-application-for-you-part-2-how/
  
  Shell.ShellExecute(File [, Arguments, Directory, Operation, Show])
  http://msdn.microsoft.com/en-us/library/windows/desktop/gg537745
*/
Run_(target, args:="", workdir:="") {
    try
    ShellRun(target, args, workdir)
    catch e
        Run % args="" ? target : target " " args, % workdir
}
ShellRun(prms*)
{
    shellWindows := ComObjCreate("Shell.Application").Windows
    VarSetCapacity(_hwnd, 4, 0)
    desktop := shellWindows.FindWindowSW(0, "", 8, ComObj(0x4003, &_hwnd), 1)
    
    ; Retrieve top-level browser object.
    if ptlb := ComObjQuery(desktop
        , "{4C96BE40-915C-11CF-99D3-00AA004AE837}" ; SID_STopLevelBrowser
        , "{000214E2-0000-0000-C000-000000000046}") ; IID_IShellBrowser
    {
        ; IShellBrowser.QueryActiveShellView -> IShellView
        if DllCall(NumGet(NumGet(ptlb+0)+15*A_PtrSize), "ptr", ptlb, "ptr*", psv:=0) = 0
        {
            ; Define IID_IDispatch.
            VarSetCapacity(IID_IDispatch, 16)
            NumPut(0x46000000000000C0, NumPut(0x20400, IID_IDispatch, "int64"), "int64")
            
            ; IShellView.GetItemObject -> IDispatch (object which implements IShellFolderViewDual)
            DllCall(NumGet(NumGet(psv+0)+15*A_PtrSize), "ptr", psv
                , "uint", 0, "ptr", &IID_IDispatch, "ptr*", pdisp:=0)
            
            ; Get Shell object.
            shell := ComObj(9,pdisp,1).Application
            
            ; IShellDispatch2.ShellExecute
            shell.ShellExecute(prms*)
            
            ObjRelease(psv)
        }
        ObjRelease(ptlb)
    }
}

isMuMuv5(){
    global folderPath
    mumuFolder := folderPath . "\MuMuPlayerGlobal-12.0"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMu Player 12"
    if FileExist(mumuFolder . "\nx_main")
        return true
    return false
}

~+F7::ExitApp
