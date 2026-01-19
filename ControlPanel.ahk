#SingleInstance, Ignore
CoordMode, Mouse, Screen
SetTitleMatchMode, 3
Menu, Tray, Icon, %A_ScriptDir%\GUI\Icons\control-panel2.ico

if not A_IsAdmin
{
    ; Relaunch script with admin rights
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

global useADBManager, Instances

; Read settings from the main script's settings file
IniRead, Instances, Settings.ini, UserSettings, Instances, 1
IniRead, runMain, Settings.ini, UserSettings, runMain, 1
IniRead, Mains, Settings.ini, UserSettings, Mains, 1
IniRead, folderPath, Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
IniRead, useADBManager, Settings.ini, UserSettings, useADBManager, 0

mumuFolder = %folderPath%\MuMuPlayerGlobal-12.0
if !FileExist(mumuFolder){
    mumuFolder = %folderPath%\MuMu Player 12
}

; Set MuMuManager.exe location
mumuManagerPath := mumuFolder "\shell\MuMuManager.exe"

; Monokai Soda theme colors
global monokaiBg := "1A1A1A"      ; Darker background
global monokaiText := "F8F8F2"    ; Light text
global monokaiAccent := "66D9EF"  ; Blue accent
global monokaiButton := "49483E"  ; Button background
global monokaiButtonHover := "75715E" ; Button hover
global monokaiGroup := "2D2D2D"   ; Group box background
global monokaiGroupTitle := "A6E22E" ; Group title color
global monokaiBorder := "3E3D32"  ; Border color

; Store base button text
global baseButtonText := {}

; Create GUI with Monokai Soda theme
Gui, New
Gui, Color, %monokaiBg%, %monokaiGroup%
Gui, Font, s10 c%monokaiText%, Segoe UI

; MuMu Instance Control Section
Gui, Add, GroupBox, x10 y10 w300 h240 c%monokaiGroupTitle% Background%monokaiGroup%, MuMu Instance Control
Gui, Add, Button, x20 y30 w280 h30 gKillAllMumu Background%monokaiButton% c%monokaiText%, Kill All MuMu Instances
Gui, Add, Text, x20 y70 c%monokaiText%, Toggle MuMu Instances:
Gui, Add, Button, x20 y90 w40 h30 gToggleMumu1 vToggleMumu1 Background%monokaiButton% c%monokaiText%, 1
baseButtonText["ToggleMumu1"] := "1"
Gui, Add, Button, x65 y90 w40 h30 gToggleMumu2 vToggleMumu2 Background%monokaiButton% c%monokaiText%, 2
baseButtonText["ToggleMumu2"] := "2"
Gui, Add, Button, x110 y90 w40 h30 gToggleMumu3 vToggleMumu3 Background%monokaiButton% c%monokaiText%, 3
baseButtonText["ToggleMumu3"] := "3"
Gui, Add, Button, x155 y90 w40 h30 gToggleMumu4 vToggleMumu4 Background%monokaiButton% c%monokaiText%, 4
baseButtonText["ToggleMumu4"] := "4"
Gui, Add, Button, x200 y90 w40 h30 gToggleMumu5 vToggleMumu5 Background%monokaiButton% c%monokaiText%, 5
baseButtonText["ToggleMumu5"] := "5"
Gui, Add, Button, x245 y90 w40 h30 gToggleMumu6 vToggleMumu6 Background%monokaiButton% c%monokaiText%, 6
baseButtonText["ToggleMumu6"] := "6"

; Disk Cache Cleaning Section
Gui, Add, Text, x20 y130 c%monokaiText%, Clean Disk Cache:
Gui, Add, Button, x20 y150 w40 h30 gCleanDisk1 Background%monokaiButton% c%monokaiText%, 1
Gui, Add, Button, x65 y150 w40 h30 gCleanDisk2 Background%monokaiButton% c%monokaiText%, 2
Gui, Add, Button, x110 y150 w40 h30 gCleanDisk3 Background%monokaiButton% c%monokaiText%, 3
Gui, Add, Button, x155 y150 w40 h30 gCleanDisk4 Background%monokaiButton% c%monokaiText%, 4
Gui, Add, Button, x200 y150 w40 h30 gCleanDisk5 Background%monokaiButton% c%monokaiText%, 5
Gui, Add, Button, x245 y150 w40 h30 gCleanDisk6 Background%monokaiButton% c%monokaiText%, 6

; AHK Script Control Section
Gui, Add, GroupBox, x10 y260 w300 h180 c%monokaiGroupTitle% Background%monokaiGroup%, AHK Script Control
Gui, Add, Button, x20 y280 w280 h30 gKillAllAHK Background%monokaiButton% c%monokaiText%, Kill All AHK Scripts
Gui, Add, Text, x20 y320 c%monokaiText%, Toggle AHK Scripts:
Gui, Add, Button, x20 y340 w40 h30 gToggleAHK1 vToggleAHK1 Background%monokaiButton% c%monokaiText%, 1
baseButtonText["ToggleAHK1"] := "1"
Gui, Add, Button, x65 y340 w40 h30 gToggleAHK2 vToggleAHK2 Background%monokaiButton% c%monokaiText%, 2
baseButtonText["ToggleAHK2"] := "2"
Gui, Add, Button, x110 y340 w40 h30 gToggleAHK3 vToggleAHK3 Background%monokaiButton% c%monokaiText%, 3
baseButtonText["ToggleAHK3"] := "3"
Gui, Add, Button, x155 y340 w40 h30 gToggleAHK4 vToggleAHK4 Background%monokaiButton% c%monokaiText%, 4
baseButtonText["ToggleAHK4"] := "4"
Gui, Add, Button, x200 y340 w40 h30 gToggleAHK5 vToggleAHK5 Background%monokaiButton% c%monokaiText%, 5
baseButtonText["ToggleAHK5"] := "5"
Gui, Add, Button, x245 y340 w40 h30 gToggleAHK6 vToggleAHK6 Background%monokaiButton% c%monokaiText%, 6
baseButtonText["ToggleAHK6"] := "6"

; Main Instance Control Section
Gui, Add, GroupBox, x10 y450 w300 h60 c%monokaiGroupTitle% Background%monokaiGroup%, Main Instance Control
Gui, Add, Button, x20 y470 w280 h30 gKillMainInstance Background%monokaiButton% c%monokaiText%, Kill Main Instance

; Status Section
Gui, Add, GroupBox, x10 y520 w300 h120 c%monokaiGroupTitle% Background%monokaiGroup%, Running Instances / AHK
Gui, Add, Text, x20 y540 w280 h60 vStatusText c%monokaiText%, Checking instances...
Gui, Add, Button, x20 y610 w280 h20 gRefreshStatus Background%monokaiButton% c%monokaiText%, Refresh Status

; Utility Section
Gui, Add, GroupBox, x320 y10 w200 h240 c%monokaiGroupTitle% Background%monokaiGroup%, Utilities
Gui, Add, Button, x330 y30 w180 h30 gOpenProjectFolder Background%monokaiButton% c%monokaiText%, Open Project Folder
Gui, Add, Button, x330 y65 w180 h30 gArrangeWindows Background%monokaiButton% c%monokaiText%, Arrange Windows
Gui, Add, Button, x330 y100 w180 h30 gToggleMonitor vToggleMonitor Background%monokaiButton% c%monokaiText%, Toggle Monitor.ahk
baseButtonText["ToggleMonitor"] := "Toggle Monitor.ahk"
Gui, Add, Button, x330 y135 w180 h30 gTogglePTCGPB vTogglePTCGPB Background%monokaiButton% c%monokaiText%, Toggle PTCGPB.ahk
baseButtonText["TogglePTCGPB"] := "Toggle PTCGPB.ahk"
Gui, Add, Button, x330 y170 w180 h30 gxmlCounter vxmlCounter Background%monokaiButton% c%monokaiText%, XML Counter
baseButtonText["xmlCounter"] := "XML Counter"
Gui, Add, Button, x330 y205 w180 h30 gOpenSettings Background%monokaiButton% c%monokaiText%, Open Settings.ini

; ========== Statistics Section ==========
Gui, Add, GroupBox, x320 y260 w200 h150 c%monokaiGroupTitle% Background%monokaiGroup%, Statistics
Gui, Add, Text, x330 y280 w180 h20 vTimeElapsed c%monokaiText%, Time Elapsed: 0m
Gui, Add, Text, x330 y300 w180 h20 vAccProcessed c%monokaiText%, Acc Processed: 0
Gui, Add, Text, x330 y320 w180 h20 vAccRate c%monokaiText%, Rate: 0 acc/hr
Gui, Add, Text, x330 y340 w180 h20 vAccLeft c%monokaiText%, Acc Left: 0
Gui, Add, Text, x330 y360 w180 h20 vETATime c%monokaiText%, ETA Time Left: 0m

; Show GUI
Gui, Show, w530 h650, PTCGP Control Panel

; Initial status check
SetTimer, UpdateStatus, 2000
Gosub, UpdateStatus
return

; Functions for killing MuMu instances
; Functions for killing MuMu instances
KillAllMumu:
    MsgBox, 4,, Shutting down takes about 5 seconds per instance, is that ok?
    IfMsgBox No
        return
        
    Loop %Instances% {
        killInstance(A_Index)
    }
    if (runMain) {
        Loop %Mains% {
            mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
            killInstance(mainInstanceName)
        }
    }
    Sleep, 3000

    ; Force kill even stuborn stuck background process.
    killFreezeMuMuBackgroundService()
    MsgBox, All instances have been shutdown.
    Gosub, UpdateStatus
return

; Functions for toggling MuMu instances
ToggleMumu1:
    toggleInstance(1)
    Gosub, UpdateStatus
return

ToggleMumu2:
    toggleInstance(2)
    Gosub, UpdateStatus
return

ToggleMumu3:
    toggleInstance(3)
    Gosub, UpdateStatus
return

ToggleMumu4:
    toggleInstance(4)
    Gosub, UpdateStatus
return

ToggleMumu5:
    toggleInstance(5)
    Gosub, UpdateStatus
return

ToggleMumu6:
    toggleInstance(6)
    Gosub, UpdateStatus
return

; Functions for cleaning disk cache
CleanDisk1:
    cleanInstanceDisk(1)
return

CleanDisk2:
    cleanInstanceDisk(2)
return

CleanDisk3:
    cleanInstanceDisk(3)
return

CleanDisk4:
    cleanInstanceDisk(4)
return

CleanDisk5:
    cleanInstanceDisk(5)
return

CleanDisk6:
    cleanInstanceDisk(6)
return

; Functions for killing AHK scripts
KillAllAHK:
    Loop 6 {
        killAHK(A_Index . ".ahk")
    }
    if (useADBManager) {
        Loop 6 {
            killAHK(A_Index . ".adbmanager.ahk")
        }
    }
    killAHK("Monitor.ahk")
    killAHK("PowerSaving.ahk")
    killAHK("PTCGPB.ahk")
    if (runMain) {
        Loop %Mains% {
            mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
            killAHK(mainInstanceName . ".ahk")
        }
    }
    Sleep, 500
    Gosub, UpdateStatus
return

; Functions for toggling AHK scripts
ToggleAHK1:
    toggleAHK("1.ahk")
    Gosub, UpdateStatus
return

ToggleAHK2:
    toggleAHK("2.ahk")
    Gosub, UpdateStatus
return

ToggleAHK3:
    toggleAHK("3.ahk")
    Gosub, UpdateStatus
return

ToggleAHK4:
    toggleAHK("4.ahk")
    Gosub, UpdateStatus
return

ToggleAHK5:
    toggleAHK("5.ahk")
    Gosub, UpdateStatus
return

ToggleAHK6:
    toggleAHK("6.ahk")
    Gosub, UpdateStatus
return

KillMainInstance:
    if (runMain) {
        Loop %Mains% {
            mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
            killInstance(mainInstanceName)
            killAHK(mainInstanceName . ".ahk")
        }
    }
    Gosub, UpdateStatus
return

RefreshStatus:
    Gosub, UpdateStatus
return

UpdateStatus:
    IniRead, Instances, Settings.ini, UserSettings, Instances, 1
    status := ""
    
    ; Check main instances
    if (runMain) {
        Loop %Mains% {
            mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
            if (checkInstance(mainInstanceName))
                status .= mainInstanceName . ", "
            if (checkAHK(mainInstanceName . ".ahk"))
                status .= mainInstanceName . ".ahk, "
        }
    }
    
    ; Check regular instances
    Loop 6 {
        if (checkInstance(A_Index))
            status .= A_Index . ", "
        if (checkAHK(A_Index . ".ahk"))
            status .= A_Index . ".ahk, "
        if (useADBManager) {
            if (checkAHK(A_Index . ".adbmanager.ahk")) {
                status .= A_Index . ".adb, "
            }
        }
    }
    
    ; Check additional scripts
    if (checkAHK("PTCGPB.ahk"))
        status .= "PTCGPB.ahk, "
    if (checkAHK("Monitor.ahk"))
        status .= "Monitor.ahk, "
    if (checkAHK("PowerSaving.ahk"))
        status .= "PowerSaving.ahk, "
    
    GuiControl,, StatusText, %status%
    Sleep, 200 ; Add a small delay to allow launched processes to register
    updateButtonColors()
    
    ; Update statistics
    updateStatistics()
return

; Utility functions
OpenProjectFolder:
    Run, explorer.exe %A_ScriptDir%
return

ArrangeWindows:
    ; MuMuv5 := isMuMuv5()
    LoadSettingsFromIni()
    MuMuv5 := 0

    if (defaultLanguage = "Scale125") {
       if (MuMuv5) {
         scaleParam := 283
	} else {
         scaleParam := 277
     }
   }

    windowsPositioned := 0

    ; Initialize titleHeight based on MuMuv5
    if (MuMuv5) {
        titleHeight := 50
    } else {
        titleHeight := 45
    }

    if (runMain && Mains > 0) {
       Loop %Mains% {
          mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
          SetTitleMatchMode, 3
          if (WinExist(mainInstanceName)) {
             WinActivate, %mainInstanceName%
             WinGetPos, curX, curY, curW, curH, %mainInstanceName%

             SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
             SysGet, Monitor, Monitor, %SelectedMonitorIndex%

             instanceIndex := A_Index
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

             WinMove, %mainInstanceName%,, %x%, %y%, %scaleParam%, %rowHeight%
             WinSet, Redraw, , %mainInstanceName%

             windowsPositioned++
             sleep, 100
          }
       }
    }

    if (Instances > 0) {
       Loop %Instances% {
          SetTitleMatchMode, 3
          windowTitle := A_Index

          if (WinExist(windowTitle)) {
             WinActivate, %windowTitle%
             WinGetPos, curX, curY, curW, curH, %windowTitle%

             SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
             SysGet, Monitor, Monitor, %SelectedMonitorIndex%

             if (runMain) {
                instanceIndex := (Mains - 1) + A_Index + 1
             } else {
                instanceIndex := A_Index
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

             WinMove, %windowTitle%,, %x%, %y%, %scaleParam%, %rowHeight%
             WinSet, Redraw, , %windowTitle%

             windowsPositioned++
             sleep, 100
          }
       }
    }

    if (debugMode && windowsPositioned == 0) {
       MsgBox, 0x40000,, No windows found to arrange
    }
 return

ToggleMonitor:
    
    if (checkAHK("Monitor.ahk")) {
        ; Kill Monitor.ahk
        killAHK("Monitor.ahk")
    } else {
        ; Launch Monitor.ahk
        Run, %A_ScriptDir%\Scripts\Include\Monitor.ahk
        Sleep, 500
    }
    
    Gosub, UpdateStatus
return

; New utility functions
TogglePTCGPB:
    toggleAHK("PTCGPB.ahk")
    Sleep, 500
    Gosub, UpdateStatus
return

xmlCounter:
    Run, %A_ScriptDir%\Accounts\xmlCounter.ahk
    Sleep, 500
    Gosub, UpdateStatus
return

OpenSettings:
    Run, notepad %A_ScriptDir%\Settings.ini
return

; Helper functions from your existing codebase
killAHK(scriptName := "") {
    killed := 0
    if(scriptName != "") {
        DetectHiddenWindows, On
        WinGet, IDList, List, ahk_class AutoHotkey
        Loop %IDList% {
            ID:=IDList%A_Index%
            WinGetTitle, ATitle, ahk_id %ID%
            if InStr(ATitle, "\" . scriptName) {
                WinGet, pid, PID, ahk_id %ID%
                WinKill, ahk_id %ID%
                killed := killed + 1
                
                ; Verify process is actually dead
                Process, Exist, %pid%
                if (ErrorLevel) {
                    RunWait, taskkill /f /pid %pid% /t,, Hide
                }
            }
        }
    }
    return killed
}

checkAHK(scriptName := "") {
    cnt := 0
    if(scriptName != "") {
        DetectHiddenWindows, On
        WinGet, IDList, List, ahk_class AutoHotkey
        Loop %IDList% {
            ID:=IDList%A_Index%
            WinGetTitle, ATitle, ahk_id %ID%
            if InStr(ATitle, "\" . scriptName) {
                cnt := cnt + 1
            }
        }
    }
    return cnt
}

killInstance(instanceNum := "") {
    global mumuManagerPath, mumuFolder
    killed := 0
    
    ; --- 1. Graceful API shutdown ---
    mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
    if (mumuNum != "") {
        RunWait, %mumuManagerPath% api -v %mumuNum% shutdown_player,, Hide
        Sleep, 8000
        if (!checkInstance(instanceNum)) {
            LogToFile("Proper shutdown via MuMuManager for instance " . instanceNum, "ControlPanel.txt")
            return 1
        }
        LogToFile("API shutdown attempted but instance " . instanceNum . " still running – falling back.", "ControlPanel.txt")
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
            LogToFile("Successfully terminated instance " . instanceNum . " via WinKill.", "ControlPanel.txt")
            return 1
        }
        LogToFile("WinKill attempted but instance partially remains – trying PID force kill.", "ControlPanel.txt")
    }
    
    ; --- 3. Final PID hard kill ---
    pID := checkInstance(instanceNum)
    if (pID) {
        Process, Close, %pID%
        Sleep, 2000

        if (!checkInstance(instanceNum)) {
            LogToFile("Successfully terminated instance " . instanceNum . " via PID Hard kill.", "ControlPanel.txt")
            return 1
        }
        LogToFile("Failed to terminate the insance " . instanceNum . " with all 3 method", "ControlPanel.txt")
        killed := 1
    }
    return killed
}

checkInstance(instanceNum := "") {
    ret := WinExist(instanceNum)
    if(ret) {
        WinGet, temp_pid, PID, ahk_id %ret%
        return temp_pid
    }
    return ""
}

; Function to clean disk cache for a specific instance
cleanInstanceDisk(instanceNum) {
    global mumuFolder
    
    ; We need to kill the instance to be able to delete the cache disk
    killInstance(instanceNum)
    Sleep, 1000
    ; Get the mumu instance number for this script
    mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
    if (mumuNum != "") {
        ; Loop through all directories in the vms folder
        Loop, Files, %mumuFolder%\vms\*, D  ; D flag to include directories only
        {
            folder := A_LoopFileFullPath
            configFolder := folder "\configs"  ; The config folder inside each directory

            ; Check if config folder exists
            IfExist, %configFolder%
            {
                ; Define path to extra_config.json
                extraConfigFile := configFolder "\extra_config.json"

                ; Check if extra_config.json exists and read playerName
                IfExist, %extraConfigFile%
                {
                    FileRead, extraConfigContent, %extraConfigFile%
                    ; Parse the JSON for playerName
                    RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                    if(playerName1 == instanceNum) {
                        ; Found the correct folder, now delete ota.vdi
                        otaPath := folder . "\ota.vdi"
                        if FileExist(otaPath) {
                            FileDelete, %otaPath%
                            if FileExist(otaPath) {
                                MsgBox, 16, Disk Cache, Failed to delete cache disk for instance %instanceNum%
                                LogToFile("Failed to delete cache disk for instance " . instanceNum, "ControlPanel.txt")
                            } else {
                                MsgBox, 64, Disk Cache, Deleted cache disk for instance %instanceNum%
                                LogToFile("Deleted cache disk for instance " . instanceNum, "ControlPanel.txt")
                            }
                        }
                        break
                    }
                }
            }
        }
    }
}

; Function to get MuMu instance number from player name
getMumuInstanceNumFromPlayerName(scriptName := "") {
    global mumuFolder

    if(scriptName == "") {
        return ""
    }

    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolder%\vms\*, D  ; D flag to include directories only
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"  ; The config folder inside each directory

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

; Function to log to file
LogToFile(message, logFile) {
    logFile := A_ScriptDir . "\Logs\" . logFile
    FormatTime, readableTime, %A_Now%, MMMM dd, yyyy HH:mm:ss
    FileAppend, % "[" readableTime "] " message "`n", %logFile%
}

; Function to toggle a MuMu instance
toggleInstance(instanceNum := "") {
    if(instanceNum != "") {
        ; Check if the instance is running
        pID := checkInstance(instanceNum)
        
        if(pID) {
            ; Kill the instance if it's running
            killInstance(instanceNum)
            LogToFile("Killed instance " . instanceNum, "ControlPanel.txt")
            Sleep, 500
        } else {
            ; Launch the instance if it's not running
            launchInstance(instanceNum)
            LogToFile("Launched instance " . instanceNum, "ControlPanel.txt")
            Sleep, 1000
        }
        Gosub, UpdateStatus
    }
}

; Function to launch a MuMu instance
launchInstance(instanceNum := "") {
    global mumuFolder

    if(instanceNum != "") {
        mumuNum := getMumuInstanceNumFromPlayerName(instanceNum)
        if(mumuNum != "") {
            ; Run, %mumuFolder%\shell\MuMuPlayer.exe -v %mumuNum%
            Run_(mumuFolder . "\shell\MuMuPlayer.exe", "-v " . mumuNum)
        }
    }
}

; Function to run as a NON-administrator, since MuMu has issues if run as Administrator
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
        , "{4C96BE40-915C-11CF-99D3-00AA004AE837}"  ; SID_STopLevelBrowser
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

; Function to toggle an AHK script
toggleAHK(scriptName := "") {
    global useADBManager
    if(scriptName != "") {
        ; Check if the script is running
        isRunning := checkAHK(scriptName) > 0
        
        ; Check if this is a numbered script and ADB manager is enabled
        if (RegExMatch(scriptName, "^(\d+)\.ahk$", match) && useADBManager) {
            adbScriptName := match1 . ".adbmanager.ahk"
            
            if(isRunning) {
                ; Kill both the main script and its ADB manager
                killAHK(scriptName)
                killAHK(adbScriptName)
                LogToFile("Killed scripts " . scriptName . " and " . adbScriptName, "ControlPanel.txt")
            } else {
                ; First check and kill any running ADB manager script
                if (checkAHK(adbScriptName) > 0) {
                    killAHK(adbScriptName)
                    LogToFile("Killed existing " . adbScriptName . " before launch", "ControlPanel.txt")
                }
                
                ; Launch ADB manager first, wait, then launch main script
                Run, %A_ScriptDir%\Scripts\%adbScriptName%
                Sleep, 2000  ; Wait 2 seconds
                Run, %A_ScriptDir%\Scripts\%scriptName%
                LogToFile("Launched scripts " . adbScriptName . " and " . scriptName, "ControlPanel.txt")
            }
        } else {
            ; Handle non-numbered scripts or when ADB manager is disabled
            if(isRunning) {
                ; Kill the script if it's running
                killAHK(scriptName)
                LogToFile("Killed script " . scriptName, "ControlPanel.txt")
            } else {
                ; Launch the script if it's not running
                if RegExMatch(scriptName, "^\d+\.ahk$")
                    Run, %A_ScriptDir%\Scripts\%scriptName%
                else
                    Run, %A_ScriptDir%\%scriptName%
                LogToFile("Launched script " . scriptName, "ControlPanel.txt")
            }
        }
    }
    Sleep, 500
    Gosub, UpdateStatus
}

GuiClose:
ExitApp

; Function to update button text based on status
updateButtonColors() {
    global baseButtonText

    ; Update MuMu instance buttons
    Loop 6 {
        btnName := "ToggleMumu" . A_Index
        baseText := baseButtonText[btnName]
        if (checkInstance(A_Index)) {
            GuiControl,, %btnName%, % baseText . " *"
        } else {
            GuiControl,, %btnName%, % baseText  ; Show only base text when OFF
        }
    }
    
    ; Update AHK script buttons
    Loop 6 {
        btnName := "ToggleAHK" . A_Index
        baseText := baseButtonText[btnName]
        if (checkAHK(A_Index . ".ahk")) {
            GuiControl,, %btnName%, % baseText . " *"
        } else {
            GuiControl,, %btnName%, % baseText  ; Show only base text when OFF
        }
    }
    
    ; Update utility script buttons
    btnName := "ToggleMonitor"
    baseText := baseButtonText[btnName]
    if (checkAHK("Monitor.ahk")) {
        GuiControl,, %btnName%, % baseText . " *"
    } else {
        GuiControl,, %btnName%, % baseText  ; Show only base text when OFF
    }
    
    btnName := "TogglePTCGPB"
    baseText := baseButtonText[btnName]
    if (checkAHK("PTCGPB.ahk")) {
        GuiControl,, %btnName%, % baseText . " *"
    } else {
        GuiControl,, %btnName%, % baseText  ; Show only base text when OFF
    }
    
    btnName := "xmlCounter"
    baseText := baseButtonText[btnName]
    if (checkAHK("PowerSaving.ahk")) {
        GuiControl,, %btnName%, % baseText . " *"
    } else {
        GuiControl,, %btnName%, % baseText  ; Show only base text when OFF
    }
}

; Function to update statistics
updateStatistics() {
    ; Get start time from Settings.ini
    metricFile := A_ScriptDir . "\Scripts\1.ini"
    IniRead, rerollStartTime, %metricFile%, Metrics, rerollStartTime, 0
    
    ; Calculate time elapsed in minutes
    timeElapsed := Floor((A_TickCount - rerollStartTime) / 60000)
    GuiControl,, TimeElapsed, Time Elapsed: %timeElapsed% min
    
    ; Get total accounts processed
    accountProcessed := 0
    Loop, %Instances% {
        saveDir := A_ScriptDir . "\Accounts\Saved\" . A_Index
        tmpaccountProcessed := countProcessedXmlThisRun(saveDir, rerollStartTime)
        accountProcessed += tmpaccountProcessed
    }
    GuiControl,, AccProcessed, Acc Processed: %accountProcessed%
    
    ; Calculate rate (accounts per hour)
    hours := timeElapsed / 60
    rate := hours > 0 ? Round(accountProcessed / hours, 2) : 0
    GuiControl,, AccRate, Rate: %rate% acc/hr
    
    ; Calculate accounts left
    accountsLeft := 0
    ; Debug: Check Instances value
    Loop, %Instances% {
        saveDir := A_ScriptDir . "\Accounts\Saved\" . A_Index
        tmpaccountsLeft := CountOldXmlFiles(saveDir)
        accountsLeft += tmpaccountsLeft
    }
    GuiControl,, AccLeft, Acc Left: %accountsLeft%
    
    ; Calculate ETA in minutes
    etaMinutes := rate > 0 ? Round(accountsLeft / rate * 60) : 0
    GuiControl,, ETATime, ETA Time Left: %etaMinutes%m
}

countProcessedXmlThisRun(directory, rerollStartTime) {
    count := 0
    if !FileExist(directory)
        return 0
    
    if (rerollStartTime = 0 || rerollStartTime = "" || rerollStartTime = "ERROR")
        return 0
    
    nowLocal := A_Now
    
    ; Correct: Subtract 24 hours using EnvAdd with negative value
    twentyFourHoursAgo := A_Now
    EnvAdd, twentyFourHoursAgo, -24, Hours
    
    Loop, Files, %directory%\*.xml
    {
        FileGetTime, modTime, %A_LoopFileFullPath%, M
        if (modTime = "")
            continue
        
        ; First: skip if file is 24 hours old or older (fast early check)
        if (modTime < twentyFourHoursAgo)
            continue
        
        ; Second: estimate file's TickCount
        diff := A_Now
        EnvSub, diff, %modTime%, Seconds  ; diff now holds seconds since modification
        
        estimatedFileTick := A_TickCount - (diff * 1000)
        
        ; Count only if modified AFTER reroll started
        if (estimatedFileTick > rerollStartTime)
            count++
    }
    return count
}

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

; Function to sum variables in JSON file (copied from PTCGPB.ahk)
SumVariablesInJsonFile() {
    jsonFileName := A_ScriptDir . "\json\Packs.json"
    if (jsonFileName = "") {
        return 0
    }

    ; Read the file content
    FileRead, jsonContent, %jsonFileName%
    if (jsonContent = "") {
        return 0
    }

    ; Parse the JSON and calculate the sum
    sum := 0
    ; Clean and parse JSON content
    jsonContent := StrReplace(jsonContent, "[", "") ; Remove starting bracket
    jsonContent := StrReplace(jsonContent, "]", "") ; Remove ending bracket
    Loop, Parse, jsonContent, {, }
    {
        ; Match each variable value
        if (RegExMatch(A_LoopField, """variable"":\s*(-?\d+)", match)) {
            sum += match1
        }
    }

    return sum
}

killFreezeMuMuBackgroundService() {
    for _, proc in ["MuMuPlayer.exe", "MuMuPlayerService.exe", "MuMuVMMHeadless.exe", "MuMuVMMSVC.exe"] {
        Loop {
            Process, Exist, %proc%
            pid := ErrorLevel
            if (!pid)
                break
            Process, Close, %pid%
            Sleep, 500
            Process, Exist, %pid%
            if (ErrorLevel) {
                RunWait, taskkill /f /pid %pid%,, Hide
                killed++
            }
        }
    }
}

LoadSettingsFromIni() {
   global
   if (FileExist("Settings.ini")) {
      IniRead, useAdbManager, Settings.ini, UserSettings, useAdbManager, 0
      IniRead, IsLanguageSet, Settings.ini, UserSettings, IsLanguageSet, 1
      IniRead, defaultBotLanguage, Settings.ini, UserSettings, defaultBotLanguage, 1
      IniRead, BotLanguage, Settings.ini, UserSettings, BotLanguage, English
      
      IniRead, shownLicense, Settings.ini, UserSettings, shownLicense, 0
      IniRead, currentfont, Settings.ini, UserSettings, currentfont, segoe UI
      IniRead, FontColor, Settings.ini, UserSettings, FontColor, FDFDFD
      IniRead, CurrentTheme, Settings.ini, UserSettings, CurrentTheme, Dark
      
      IniRead, FriendID, Settings.ini, UserSettings, FriendID, ""
      IniRead, Instances, Settings.ini, UserSettings, Instances, 1
      IniRead, instanceStartDelay, Settings.ini, UserSettings, instanceStartDelay, 10
      IniRead, Columns, Settings.ini, UserSettings, Columns, 5
      IniRead, runMain, Settings.ini, UserSettings, runMain, 1
      IniRead, Mains, Settings.ini, UserSettings, Mains, 1
      IniRead, AccountName, Settings.ini, UserSettings, AccountName, ""
      IniRead, autoLaunchMonitor, Settings.ini, UserSettings, autoLaunchMonitor, 1
      IniRead, TestTime, Settings.ini, UserSettings, TestTime, 3600
      IniRead, Delay, Settings.ini, UserSettings, Delay, 250
      IniRead, waitTime, Settings.ini, UserSettings, waitTime, 5
      IniRead, swipeSpeed, Settings.ini, UserSettings, swipeSpeed, 500
      IniRead, slowMotion, Settings.ini, UserSettings, slowMotion, 1 ; default is now OFF for no-mod-menu support
      
      IniRead, SelectedMonitorIndex, Settings.ini, UserSettings, SelectedMonitorIndex, 1
      IniRead, SelectedMonitorDeviceName, Settings.ini, UserSettings, SelectedMonitorDeviceName, "\\.\DISPLAY1"
      IniRead, defaultLanguage, Settings.ini, UserSettings, defaultLanguage, Scale125
      if (defaultLanguage = "Scale100") defaultLanguage := "Scale125"
      IniRead, rowGap, Settings.ini, UserSettings, rowGap, 90
      IniRead, folderPath, Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
      IniRead, ocrLanguage, Settings.ini, UserSettings, ocrLanguage, en
      IniRead, clientLanguage, Settings.ini, UserSettings, clientLanguage, en
      IniRead, instanceLaunchDelay, Settings.ini, UserSettings, instanceLaunchDelay, 2
      
      IniRead, tesseractPath, Settings.ini, UserSettings, tesseractPath, C:\Program Files\Tesseract-OCR\tesseract.exe
      IniRead, debugMode, Settings.ini, UserSettings, debugMode, 0
      IniRead, useTesseract, Settings.ini, UserSettings, tesseractOption, 0
      IniRead, statusMessage, Settings.ini, UserSettings, statusMessage, 1
      
      IniRead, minStars, Settings.ini, UserSettings, minStars, 0
      IniRead, minStarsShiny, Settings.ini, UserSettings, minStarsShiny, 0
      IniRead, minStarsEnabled, Settings.ini, UserSettings, minStarsEnabled, 0

      IniRead, packMethod, Settings.ini, UserSettings, packMethod, 0
      IniRead, nukeAccount, Settings.ini, UserSettings, nukeAccount, 0
      nukeAccount := 0 ; forced to always be disabled
      IniRead, spendHourGlass, Settings.ini, UserSettings, spendHourGlass, 0
      IniRead, openExtraPack, Settings.ini, UserSettings, openExtraPack, 0
      IniRead, injectSortMethod, Settings.ini, UserSettings, injectSortMethod, PacksDesc
      IniRead, godPack, Settings.ini, UserSettings, godPack, Continue
      IniRead, claimSpecialMissions, Settings.ini, UserSettings, claimSpecialMissions, 0
      ; Force claimSpecialMissions to always be 0
      claimSpecialMissions := 0
      IniWrite, %claimSpecialMissions%, Settings.ini, UserSettings, claimSpecialMissions
      IniRead, claimDailyMission, Settings.ini, UserSettings, claimDailyMission, 0
      IniRead, wonderpickForEventMissions, Settings.ini, UserSettings, wonderpickForEventMissions, 0
      ; wonderpickForEventMissions := 0 ; forced turned off during Sneak Peek for now...
      IniRead, checkWPthanks, Settings.ini, UserSettings, checkWPthanks, 0
      
      IniRead, Palkia, Settings.ini, UserSettings, Palkia, 0
      IniRead, Dialga, Settings.ini, UserSettings, Dialga, 0
      IniRead, Arceus, Settings.ini, UserSettings, Arceus, 0
      IniRead, Shining, Settings.ini, UserSettings, Shining, 0
      IniRead, Mew, Settings.ini, UserSettings, Mew, 0
      IniRead, Pikachu, Settings.ini, UserSettings, Pikachu, 0
      IniRead, Charizard, Settings.ini, UserSettings, Charizard, 0
      IniRead, Mewtwo, Settings.ini, UserSettings, Mewtwo, 0
      IniRead, Solgaleo, Settings.ini, UserSettings, Solgaleo, 0
      IniRead, Lunala, Settings.ini, UserSettings, Lunala, 0
      IniRead, Buzzwole, Settings.ini, UserSettings, Buzzwole, 0
      IniRead, Eevee, Settings.ini, UserSettings, Eevee, 0
      IniRead, HoOh, Settings.ini, UserSettings, HoOh, 0
      IniRead, Lugia, Settings.ini, UserSettings, Lugia, 0
      IniRead, Springs, Settings.ini, UserSettings, Springs, 0
      IniRead, Deluxe, Settings.ini, UserSettings, Deluxe, 0
      IniRead, CrimsonBlaze, Settings.ini, UserSettings, CrimsonBlaze, 1
      IniRead, MegaGyarados, Settings.ini, UserSettings, MegaGyarados, 0
      IniRead, MegaBlaziken, Settings.ini, UserSettings, MegaBlaziken, 0
      IniRead, MegaAltaria, Settings.ini, UserSettings, MegaAltaria, 0
      
      IniRead, CheckShinyPackOnly, Settings.ini, UserSettings, CheckShinyPackOnly, 0
      IniRead, TrainerCheck, Settings.ini, UserSettings, TrainerCheck, 0
      IniRead, FullArtCheck, Settings.ini, UserSettings, FullArtCheck, 0
      IniRead, RainbowCheck, Settings.ini, UserSettings, RainbowCheck, 0
      IniRead, ShinyCheck, Settings.ini, UserSettings, ShinyCheck, 0
      IniRead, CrownCheck, Settings.ini, UserSettings, CrownCheck, 0
      IniRead, ImmersiveCheck, Settings.ini, UserSettings, ImmersiveCheck, 0
      IniRead, InvalidCheck, Settings.ini, UserSettings, InvalidCheck, 0
      IniRead, PseudoGodPack, Settings.ini, UserSettings, PseudoGodPack, 0
      
      ; Start users with s4t enabled so they don't have to know to manually check it. Also pre-enabling all 2star and up cards.
      IniRead, s4tEnabled, Settings.ini, UserSettings, s4tEnabled, 1
      IniRead, s4tSilent, Settings.ini, UserSettings, s4tSilent, 0
        s4tSilent := 0 ; always disable, removing feature for now. -Kevin
      IniRead, s4t3Dmnd, Settings.ini, UserSettings, s4t3Dmnd, 0
      IniRead, s4t4Dmnd, Settings.ini, UserSettings, s4t4Dmnd, 0
      IniRead, s4t1Star, Settings.ini, UserSettings, s4t1Star, 0
      IniRead, s4tGholdengo, Settings.ini, UserSettings, s4tGholdengo, 0
      IniRead, s4tTrainer, Settings.ini, UserSettings, s4tTrainer, 1
      IniRead, s4tRainbow, Settings.ini, UserSettings, s4tRainbow, 1
      IniRead, s4tFullArt, Settings.ini, UserSettings, s4tFullArt, 1
      IniRead, s4tCrown, Settings.ini, UserSettings, s4tCrown, 1
      IniRead, s4tImmersive, Settings.ini, UserSettings, s4tImmersive, 1
      IniRead, s4tShiny1Star, Settings.ini, UserSettings, s4tShiny1Star, 0
      IniRead, s4tShiny2Star, Settings.ini, UserSettings, s4tShiny2Star, 1
      IniRead, s4tWP, Settings.ini, UserSettings, s4tWP, 0
      IniRead, s4tWPMinCards, Settings.ini, UserSettings, s4tWPMinCards, 1
      IniRead, s4tDiscordWebhookURL, Settings.ini, UserSettings, s4tDiscordWebhookURL, ""
      IniRead, s4tDiscordUserId, Settings.ini, UserSettings, s4tDiscordUserId, ""
      IniRead, s4tSendAccountXml, Settings.ini, UserSettings, s4tSendAccountXml, 0
      IniRead, ocrShinedust, Settings.ini, UserSettings, ocrShinedust, 0
      
      IniRead, DiscordWebhookURL, Settings.ini, UserSettings, DiscordWebhookURL, ""
      IniRead, DiscordUserId, Settings.ini, UserSettings, DiscordUserId, ""
      IniRead, heartBeat, Settings.ini, UserSettings, heartBeat, 0
      IniRead, heartBeatWebhookURL, Settings.ini, UserSettings, heartBeatWebhookURL, ""
      IniRead, heartBeatName, Settings.ini, UserSettings, heartBeatName, ""
      IniRead, heartBeatDelay, Settings.ini, UserSettings, heartBeatDelay, 30
      IniRead, sendAccountXml, Settings.ini, UserSettings, sendAccountXml, 0
      
      IniRead, groupRerollEnabled, Settings.ini, UserSettings, groupRerollEnabled, 0
      IniRead, mainIdsURL, Settings.ini, UserSettings, mainIdsURL, ""
      IniRead, vipIdsURL, Settings.ini, UserSettings, vipIdsURL, ""
      IniRead, showcaseEnabled, Settings.ini, UserSettings, showcaseEnabled, 0
      IniRead, showcaseLikes, Settings.ini, UserSettings, showcaseLikes, 5
      IniRead, autoUseGPTest, Settings.ini, UserSettings, autoUseGPTest, 0
      IniRead, applyRoleFilters, Settings.ini, UserSettings, applyRoleFilters, 0
	  
	  IniRead, ClaimGiftsPacks, Settings.ini, UserSettings, ClaimGiftsPacks, 0

      IniRead, minStarsA1Charizard, Settings.ini, UserSettings, minStarsA1Charizard, 0
      IniRead, minStarsA1Mewtwo, Settings.ini, UserSettings, minStarsA1Mewtwo, 0
      IniRead, minStarsA1Pikachu, Settings.ini, UserSettings, minStarsA1Pikachu, 0
      IniRead, minStarsA1a, Settings.ini, UserSettings, minStarsA1a, 0
      IniRead, minStarsA2Dialga, Settings.ini, UserSettings, minStarsA2Dialga, 0
      IniRead, minStarsA2Palkia, Settings.ini, UserSettings, minStarsA2Palkia, 0
      IniRead, minStarsA2a, Settings.ini, UserSettings, minStarsA2a, 0
      IniRead, minStarsA3Solgaleo, Settings.ini, UserSettings, minStarsA3Solgaleo, 0
      IniRead, minStarsA3Lunala, Settings.ini, UserSettings, minStarsA3Lunala, 0
      IniRead, minStarsA3a, Settings.ini, UserSettings, minStarsA3a, 0
      IniRead, minStarsA3b, Settings.ini, UserSettings, minStarsA3b, 0
      IniRead, minStarsA4HoOh, Settings.ini, UserSettings, minStarsA4HoOh, 0
      IniRead, minStarsA4Lugia, Settings.ini, UserSettings, minStarsA4Lugia, 0
      IniRead, minStarsA4Springs, Settings.ini, UserSettings, minStarsA4Springs, 0
      IniRead, minStarsA4Deluxe, Settings.ini, UserSettings, minStarsA4Deluxe, 0
      IniRead, minStarsCrimsonBlaze, Settings.ini, UserSettings, minStarsCrimsonBlaze, 0
      IniRead, minStarsMegaGyarados, Settings.ini, UserSettings, minStarsMegaGyarados, 0
      IniRead, minStarsMegaBlaziken, Settings.ini, UserSettings, minStarsMegaBlaziken, 0
      IniRead, minStarsMegaAltaria, Settings.ini, UserSettings, minStarsMegaAltaria, 0
      
      IniRead, waitForEligibleAccounts, Settings.ini, UserSettings, waitForEligibleAccounts, 1
      IniRead, maxWaitHours, Settings.ini, UserSettings, maxWaitHours, 24
      IniRead, menuExpanded, Settings.ini, UserSettings, menuExpanded, True
      
      if (!IsNumeric(Instances))
         Instances := 1
      if (!IsNumeric(Columns) || Columns < 1)
         Columns := 5
      if (!IsNumeric(waitTime))
         waitTime := 5
      if (!IsNumeric(Delay) || Delay < 10)
         Delay := 250
      if (s4tWPMinCards < 1 || s4tWPMinCards > 2)
         s4tWPMinCards := 1
         
      validMethods := "Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+"
      if (!InStr(validMethods, deleteMethod)) {
         deleteMethod := "Create Bots (13P)"
         IniWrite, %deleteMethod%, Settings.ini, UserSettings, deleteMethod
      }

      ; clear card detection when not wonderpicking
      if (deleteMethod != "Inject Wonderpick 96P+") {
         FullArtCheck := 0
         TrainerCheck := 0
         RainbowCheck := 0
         PseudoGodPack := 0
         CheckShinyPackOnly := 0
         InvalidCheck := 0
         CrownCheck := 0
         ShinyCheck := 0
         ImmersiveCheck := 0
         minStars := 0
         minStarsShiny := 0
      }

      return true
   } else {
      return false
   }
}

IsNumeric(var) {
   if var is number
      return true
   return false
}