#Include %A_ScriptDir%\Config.ahk
#Include %A_ScriptDir%\Logging.ahk
#Include %A_ScriptDir%\GitManager.ahk
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

lastReduceMemory := 0
lastGitCommit := 0

waitAfterBulkLaunch := botConfig.get("waitAfterBulkLaunch")
instanceLaunchDelay := botConfig.get("instanceLaunchDelay")
Instances := botConfig.get("Instances")
saveToGit := botConfig.get("saveToGit")
deleteMethod := botConfig.get("deleteMethod")

mumuFolder := getMuMuFolder()

if !FileExist(mumuFolder){
    MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
    ExitApp
}

; Reset LastEndEpoch for all instances at startup so stale timestamps from
; a previous session don't immediately trigger the stuck detection.
nowEpoch := A_NowUTC
EnvSub, nowEpoch, 1970, seconds
Loop %Instances% {
    instanceNum := Format("{:u}", A_Index)
    IniWrite, %nowEpoch%, %A_ScriptDir%\..\%instanceNum%.ini, Metrics, LastEndEpoch
}

Loop {
    ; Loop through each instance, check if it's started, and start it if it's not
    launched := 0
    
    Loop %Instances% {
        ; Recalculate epoch each iteration so it stays fresh after restart sleeps
        nowEpoch := A_NowUTC
        EnvSub, nowEpoch, 1970, seconds

        if(A_TickCount - lastReduceMemory > 120000) {
            LogToFile("Memory reduction process start.", "Monitor.txt")
            ReduceVMMemory()
            LogToFile("Memory reduction process complete.", "Monitor.txt")
            lastReduceMemory := A_TickCount
        }

        instanceNum := Format("{:u}", A_Index)

        IniRead, LastEndEpoch, %A_ScriptDir%\..\%instanceNum%.ini, Metrics, LastEndEpoch, 0
        IniRead, LastStartEpoch, %A_ScriptDir%\..\%instanceNum%.ini, Metrics, LastStartEpoch, 0
        secondsSinceLastEnd := nowEpoch - LastEndEpoch
        ; Set threshold: 30 minutes for Create Bots, 11 minutes for others
        threshold := (deleteMethod == "Create Bots (13P)") ? (30 * 60) : (11 * 60)
        ; Use LastEndEpoch if available, otherwise fall back to LastStartEpoch for first-run detection
        if (LastEndEpoch > 0) {
            secondsSinceLastEnd := nowEpoch - LastEndEpoch
            isStuck := (secondsSinceLastEnd > threshold)
        } else if (LastStartEpoch > 0) {
            secondsSinceLastEnd := nowEpoch - LastStartEpoch
            isStuck := (secondsSinceLastEnd > threshold)
        } else {
            secondsSinceLastEnd := 0
            isStuck := false
        }
        if(isStuck)
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

    if (saveToGit && A_TickCount - lastGitCommit > 3600000) {
        LogToFile("Git auto-commit start.", "Monitor.txt")
        gitRoot := A_ScriptDir . "\..\.."
        paths := []
        paths.Push({path: "Accounts/Saved", suffix: ".xml"})
        paths.Push({path: "Screenshots", suffix: ".png"})
        paths.Push({path: "Accounts/Trades/Trades_Database.csv", suffix: ""})
        paths.Push({path: "Accounts/Trades/Trades_Index.json", suffix: ""})
        isCommit := CommitAndPushGit(gitRoot, "Monitor.txt", paths)
        if (isCommit) {
            lastGitCommit := A_TickCount
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
                ;LogToFile(ResultLine, "Development.txt")
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
                ; Use Process Close (TerminateProcess) instead of WinKill (WM_CLOSE)
                ; to guarantee the process dies even if blocked on ADB/Sleep
                WinGet, ahkPID, PID, ahk_id %ID%
                Process, Close, %ahkPID%
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

~+F7::ExitApp