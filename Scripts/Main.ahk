#SingleInstance on
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetBatchLines, -1
SetTitleMatchMode, 3
CoordMode, Pixel, Screen

#Include %A_ScriptDir%\Include\
#Include Config.ahk
#Include Session.ahk
#Include Data.ahk
#Include ExtraConfig.ahk

#Include Logging.ahk
#Include ADB.ahk
#Include Gdip_All.ahk
#Include Gdip_Imagesearch.ahk

#Include Gdip_Extra.ahk
#Include StringCompare.ahk
#Include OCR.ahk
#Include Database.ahk
#Include CardDetection.ahk
#Include AccountManager.ahk
#Include FriendManager.ahk
#Include Dictionary.ahk

#Include Coords.ahk
#Include Error.ahk

#Include Utils.ahk
#Include Crinity_UnofficialPatch.ahk

; Allocate and hide the console window to reduce flashing
DllCall("AllocConsole")
WinHide % "ahk_id " DllCall("GetConsoleWindow", "ptr")

pToken := Gdip_Startup()

global session := new Session()
global botConfig := new BotConfig()
botConfig.loadSettingsToConfig("ALL")

session.set("scriptName", StrReplace(A_ScriptName, ".ahk"))
session.set("winTitle", StrReplace(A_ScriptName, ".ahk"))
session.set("scriptIniFile", A_ScriptDir . "\" . session.get("scriptName") . ".ini")
session.set("autoUseGPTest", botConfig.get("autoUseGPTest"))
session.set("TestTime", botConfig.get("TestTime"))
session.set("hasUnopenedPack", botConfig.get("hasUnopenedPack"))

session.set("firstRun", true)
session.set("autotest", A_TickCount)
session.set("A_gptest", 0)
session.set("stopAfterGPTest", false)
session.set("gpTestFirstRun", true)
session.set("friendOpsCount", 0)
session.set("friendOpsWindowStart", A_TickCount)
session.set("rateLimitAction", "")

session.set("gptest_nonFriends", {})

if(botConfig.get("heartBeat"))
    IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, Main

IniRead, isDeadValue, % session.get("scriptIniFile"), Metrics, isDead, 0
session.set("isDead", isDeadValue)

(botConfig.get("gpTestWaitTime") = "" || botConfig.get("gpTestWaitTime") <= 0) ? session.set("gpTestWaitTime", 150) : session.set("gpTestWaitTime", botConfig.get("gpTestWaitTime"))
(session.get("hasUnopenedPack") = "") ? session.set("hasUnopenedPack", 0)

if (!botConfig.get("groupRerollEnabled")) {
    session.set("autoUseGPTest", 0)
    session.set("TestTime", 3600)
    session.set("hasUnopenedPack", 0)
}

session.set("vipListTrimMode", (!botConfig.get("vipListTrimMode")) ? "bottom" : botConfig.get("vipListTrimMode"))
session.set("vipListTrimCount", (!botConfig.get("vipListTrimCount")) ? 60 : botConfig.get("vipListTrimCount"))
(session.get("vipListTrimCount") = "" || session.get("vipListTrimCount") < 1) ? session.set("vipListTrimCount", 60)

DirectlyPositionWindow()
Sleep, 1000

setADBBaseInfo()

ConnectAdb()
Sleep, 1000

CreateStatusMessage("Disabling background services...")
DisableBackgroundServices()

resetWindows()
MaxRetries := 10
RetryCount := 0
Loop {
    try {
        WinGetPos, x, y, Width, Height, % session.get("winTitle")
        sleep, 2000
        OwnerWND := getMuMuHwnd(session.get("winTitle"))
        x4 := x + 4
        y4 := y + Height - 4 + 2
        buttonWidth := 50

        Gui, ToolBar:New, +Owner%OwnerWND% -AlwaysOnTop +ToolWindow -Caption +LastFound -DPIScale 
        Gui, ToolBar:Default
        Gui, ToolBar:Margin, 4, 4  ; Set margin for the GUI
        Gui, ToolBar:Font, s5 cGray Norm Bold, Segoe UI  ; Normal font for input labels
        Gui, ToolBar:Add, Button, % "x" . (buttonWidth * 0) . " y0 w" . buttonWidth . " h25 gReloadScript", Reload  (Shift+F5)
        Gui, ToolBar:Add, Button, % "x" . (buttonWidth * 1) . " y0 w" . buttonWidth . " h25 gPauseScript", Pause (Shift+F6)
        Gui, ToolBar:Add, Button, % "x" . (buttonWidth * 2) . " y0 w" . buttonWidth . " h25 gResumeScript", Resume (Shift+F6)
        Gui, ToolBar:Add, Button, % "x" . (buttonWidth * 3) . " y0 w" . buttonWidth . " h25 gStopScript", Stop (Shift+F10)
        Gui, ToolBar:Add, Button, % "x" . (buttonWidth * 4) . " y0 w" . buttonWidth . " h25 gTestScript", GP Test (Shift+F9)
        DllCall("SetWindowPos", "Ptr", WinExist(), "Ptr", 1  ; HWND_BOTTOM
                , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)  ; SWP_NOSIZE, SWP_NOMOVE, SWP_NOACTIVATE
        Gui, ToolBar:Show, NoActivate x%x4% y%y4%  w275 h30
        break
    }
    catch {
        RetryCount++
        if (RetryCount >= MaxRetries) {
            CreateStatusMessage("Failed to create button GUI.",,,, false)
            break
        }
        Sleep, 1000
    }
    Delay(1)
    CreateStatusMessage("Creating button GUI...",,,, false)
}

initializeAdbShell()
CreateStatusMessage("Initializing bot...",,,, false)
if(session.get("isDead")){
    closePTCGPApp()
    session.set("isDead", false)
    IniWrite, 0, % session.get("scriptIniFile"), Metrics, isDead
}
startPTCGPApp()
waitUntilActivatePTCGPApp()

if(botConfig.get("heartBeat"))
    IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, Main
FindImageAndClick("Common_ActivatedSocialInMainMenu", 143, 518, , 1000, 150)

global 99Configs := {}
99Configs["en"] := {leftx: 123, rightx: 162}
99Configs["es"] := {leftx: 68, rightx: 107}
99Configs["fr"] := {leftx: 56, rightx: 95}
99Configs["de"] := {leftx: 72, rightx: 111}
99Configs["it"] := {leftx: 60, rightx: 99}
99Configs["pt"] := {leftx: 127, rightx: 166}
99Configs["jp"] := {leftx: 84, rightx: 127}
99Configs["ko"] := {leftx: 65, rightx: 100}
99Configs["cn"] := {leftx: 63, rightx: 102}

99Path := "99" . botConfig.get("clientLanguage")
99Leftx := 99Configs[botConfig.get("clientLanguage")].leftx
99Rightx := 99Configs[botConfig.get("clientLanguage")].rightx

Loop {
    if (session.get("autoUseGPTest") && botConfig.get("groupRerollEnabled")) {
        session.set("autotest_time", (A_TickCount - session.get("autotest")) // 1000)
        CreateStatusMessage("Auto GP Test Timer : " . session.get("autotest_time") .  "/ " . session.get("TestTime") . " seconds", "AutoGPTest", 0, 605, false, true)
        if (session.get("autotest_time") >= session.get("TestTime")) {
            session.set("A_gptest", 1)
            session.set("autotest", A_TickCount)
            ToggleTestScript()
        }        
    }

    if (session.get("GPTest")) {
        if (session.get("triggerTestNeeded"))
            GPTestScript()
        if (session.get("stopAfterGPTest"))
            ExitApp
        Sleep, 1000
        if (botConfig.get("heartBeat") && (Mod(A_Index, 60) = 0))
            IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, Main
        Continue
    }

    if(botConfig.get("heartBeat"))
        IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, Main
    Delay(1)
    FindImageAndClick("Common_ActivatedSocialInMainMenu", 143, 518, , 1000, 30)
    FindImageAndClick("Friend_AddButtonInFriendList", 38, 460, , 500)
    FindImageAndClick("Friend_BlankFriendSlotAreaInApproveSubmenu", 228, 464)
    /* ; Deny all option
    if(firstRun) {
        Sleep, 1000
        adbClick(205, 510)
        Sleep, 1000
        adbClick(210, 372)
        firstRun := false
    }
    */
    done := false
    Loop 3 {
        Delay(1)
        if(FindOrLoseImage("Friend_AcceptButtonInApproveSubmenu", 0)) {
            session.set("failSafe", A_TickCount)
            failSafeTime := 0
            Loop {
                Delay(1)
                clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, failSafeTime, 80)
                requestAlreadyClosed := FindOrLoseImage("Friend_RequestAlreadyClosedInApproveSubmenu", 0, failSafeTime)
                if(FindOrLoseImage(99Path, 0, failSafeTime)) {
                    done := true
                    break
                } else if(FindOrLoseImage("Common_Error", 0, failSafeTime)) {
                    ; Handle communication error
                    CreateStatusMessage("Error message detected. Clicking retry...",,,, false)
                    LogToFile("Error message in Main " . session.get("scriptName") . ". Clicking retry...")
                    Sleep, 1000
                    adbClick(82, 389)  ; Click retry button
                    Sleep, 1000
                    adbClick(139, 386) ; Click OK/confirm
                    Sleep, 1000
                    SafeReload()
                } else if(FindOrLoseImage("StartupErrorX", 0, failSafeTime)) {
                    ; Handle startup error with X button
                    CreateStatusMessage("Start-up error detected. Clearing and reloading...",,,, false)
                    LogToFile("Start-up error in Main " . session.get("scriptName") . ". Reloading...")
                    Sleep, 2000
                    adbClick(139, 440)  ; Click X to close error
                    Sleep, 4000
                    SafeReload()
                } else if(requestAlreadyClosed || clickButton) {
                    okClickSpacing := botConfig.get("Delay") * 2
                    if (okClickSpacing < 700)
                        okClickSpacing := 700
                    coords := clickButton ? clickButton : requestAlreadyClosed
                    if (InStr(coords, ",")) {
                        StringSplit, pos, coords, `,
                        adbClick_wbb(pos1, pos2)
                    } else
                        adbClick(137, 365)
                    Sleep, %okClickSpacing%
                    Loop {
                        btnPos := FindOrLoseImage("Common_ColorChangeButton", 0, 0, 80, 1)
                        if (!btnPos)
                            break
                        if (InStr(btnPos, ",")) {
                            StringSplit, pos, btnPos, `,
                            adbClick_wbb(pos1, pos2)
                        } else
                            adbClick(137, 365)
                        Sleep, %okClickSpacing%
                    }
                    adbInputEvent("4")
                    Sleep, 500
                    Break, 2  ; inner loop + Loop 3 (else Pending re-taps)
                } else if(FindOrLoseImage("Friend_AcceptButtonInApproveSubmenu", 0, failSafeTime)) {
                    if (session.get("GPTest"))
                        break
                    adbClick(245, 210)
                } else if(FindOrLoseImage("Friend_DisabledDenyAllRequestButtonInApproveSubmenu", 0, failSafeTime)) {
                    done := true
                    break
                }
                if (session.get("GPTest"))
                    break
                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
                CreateStatusMessage("Failsafe " . failSafeTime . "/180 seconds")
            }
        }
        if(done || session.get("GPTest"))
            break
    }
}
return

FindOrLoseImage(needleName := "DEFAULT", EL := 1, safeTime := 0, searchVariation := 20, notShowFinding := 0) {
    global session, needlesDict
    static lastStatusTime := 0

    needleObj := needlesDict.Get(needleName)
    imageName := needleObj.imageName

    imagePath := A_ScriptDir . "\Needles\"
    confirmed := false

    if(A_TickCount - lastStatusTime > 500 and !notShowFinding) {
        lastStatusTime := A_TickCount
        CreateStatusMessage("Finding " . imageName . "...")
    }

    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    Path = %imagePath%%imageName%.png
    pNeedle := GetNeedle(Path)
    X1 := needleObj.coords.startX
    Y1 := needleObj.coords.startY
    X2 := needleObj.coords.endX
    Y2 := needleObj.coords.endY

    ;bboxAndPause(X1, Y1, X2, Y2)

    ; ImageSearch within the region
    vRet := Gdip_ImageSearch(pBitmap, pNeedle, vPosXY, X1, Y1, X2, Y2, searchVariation)
    ErrorCheckInScreen(pBitmap)
    Gdip_DisposeImage(pBitmap)
    if(EL = 0)
        GDEL := 1
    else
        GDEL := 0
    if (!confirmed && vRet = GDEL && GDEL = 1) {
        confirmed := vPosXY
    } else if(!confirmed && vRet = GDEL && GDEL = 0) {
        confirmed := true
    }
    if(imageName = "Country" || imageName = "Social")
        FSTime := 90
    else if(imageName = "Button")
        FSTime := 240
    else
        FSTime := 180
    if (safeTime >= FSTime) {
        LogToFile("Instance " . session.get("scriptName") . " has been stuck at " . imageName . " for 90s. (EL: " . EL . ", sT: " . safeTime . ") Killing it...")
        restartGameInstance("Stuck at " . imageName . "...")
        session.set("failSafe", A_TickCount)
    }
    return confirmed
}

FindImageAndClick(needleName := "DEFAULT", clickx := 0, clicky := 0, searchVariation := 20, sleepTime := "", skip := false, safeTime := 0) {
    global botConfig, session, needlesDict

    needleObj := needlesDict.Get(needleName)
    imageName := needleObj.imageName

    if (sleepTime = "") {
        sleepTime := botConfig.get("Delay")
    }
    imagePath := A_ScriptDir . "\Needles\"
    click := false
    if(clickx > 0 and clicky > 0)
        click := true
    x := 0
    y := 0
    session.set("StartSkipTime", A_TickCount)

    confirmed := false

    if(click) {
        adbClick(clickx, clicky)
        clickTime := A_TickCount
    }
    CreateStatusMessage("Finding and clicking " . imageName . "...")

    Loop { ; Main loop
        Sleep, 100

        if(click) {
            ElapsedClickTime := A_TickCount - clickTime
            if(ElapsedClickTime > sleepTime) {
                adbClick(clickx, clicky)
                clickTime := A_TickCount
            }
        }

        if (confirmed) {
            continue
        }

        pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
        Path = %imagePath%%imageName%.png
        pNeedle := GetNeedle(Path)
        X1 := needleObj.coords.startX
        Y1 := needleObj.coords.startY
        X2 := needleObj.coords.endX
        Y2 := needleObj.coords.endY
        ;bboxAndPause(X1, Y1, X2, Y2)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch(pBitmap, pNeedle, vPosXY, X1, Y1, X2, Y2, searchVariation)
        ErrorCheckInScreen(pBitmap)
        Gdip_DisposeImage(pBitmap)
        if (!confirmed && vRet = 1) {
            confirmed := vPosXY
        } else {
            if(skip < 45) {
                ElapsedTime := (A_TickCount - session.get("StartSkipTime")) // 1000
                FSTime := 45
                if (ElapsedTime >= FSTime || safeTime >= FSTime) {
                    LogToFile("Instance " . session.get("scriptName") . " has been stuck at " . imageName . " for 90s. (EL: " . ElapsedTime . ", sT: " . safeTime . ") Killing it...")
                    restartGameInstance("Stuck at " . imageName . "...") ; change to reset the instance and delete data then reload script
                    session.set("StartSkipTime", A_TickCount)
                    session.set("failSafe", A_TickCount)
                }
            }
        }

        pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
        Path = %imagePath%Error1.png
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch(pBitmap, pNeedle, vPosXY, 15, 155, 270, 420, searchVariation)
        Gdip_DisposeImage(pBitmap)
        if (vRet = 1) {
            CreateStatusMessage("Error message in " . session.get("scriptName") . ". Clicking retry...")
            LogToFile("Error message in " . session.get("scriptName") . ". Clicking retry...")
            adbClick(82, 389)
            Delay(1)
            adbClick(139, 386)
            Sleep, 1000
        }

        if(skip) {
            ElapsedTime := (A_TickCount - session.get("StartSkipTime")) // 1000
            if (ElapsedTime >= skip) {
                return false
                ElapsedTime := ElapsedTime/2
                break
            }
        }
        if (confirmed) {
            break
        }

    }
    return confirmed
}

resetWindows(){
    global botConfig

    scaleParam := 283
    CreateStatusMessage("Arranging window positions and sizes")
    RetryCount := 0
    MaxRetries := 10
    Loop {
        try {
            SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
            SysGet, Monitor, Monitor, %SelectedMonitorIndex%
            Title := session.get("winTitle")

            instanceIndex := StrReplace(Title, "Main", "")
            if (instanceIndex = "")
                instanceIndex := 1

            borderWidth := 4 - 1
            rowHeight := 40 + 492
            currentRow := Floor((instanceIndex - 1) / botConfig.get("Columns"))

            y := MonitorTop + (currentRow * rowHeight) + (currentRow * botConfig.get("rowGap"))
            x := MonitorLeft + (Mod((instanceIndex - 1), botConfig.get("Columns")) * (scaleParam - borderWidth * 2))
            
            WinSet, Style, -0xC00000, %Title%
            WinMove, %Title%, , %x%, %y%, %scaleParam%, %rowHeight%
            WinSet, Style, +0xC00000, %Title%
            WinSet, Redraw, , %Title%
            break
        }
        catch {
            RetryCount++
            if (RetryCount > MaxRetries) {
                CreateStatusMessage("Pausing. Can't find window " . session.get("winTitle") . ".",,,, false)
                Pause
            }
        }
        Sleep, 1000
    }
    return true
}

restartGameInstance(reason, RL := true){
    global botConfig, session

    if(botConfig.get("heartBeatOwnerWebHookURL") != "")
        LogToDiscord(A_ScriptName . " instance has begin restart. Please verify that GodPack has not disappeared upon entering the main screen.\nReasion: " . reason,, true,,, botConfig.get("heartBeatOwnerWebHookURL"))
    
    initializeAdbShell()

    if (Debug)
        CreateStatusMessage("Restarting game reason:`n" . reason)
    else
        CreateStatusMessage("Restarting game...",,,, false)

    adbWriteRaw("am force-stop jp.pokemon.pokemontcgp")
    Sleep, 3000
    adbWriteRaw("am start -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity")
    ;startPTCGPApp()
    if(RL) {
        LogToFile("Restarted game. Reason: " reason)
        session.set("isDead", true)
        IniWrite, 1, % session.get("scriptIniFile"), Metrics, isDead
        SafeReload()
    }
}

ControlClick(X, Y) {
    global session

    ControlClick, x%X% y%Y%, % session.get("winTitle")
}

RandomUsername() {
    FileRead, content, %A_ScriptDir%\..\usernames.txt

    values := StrSplit(content, "`r`n") ; Use `n if the file uses Unix line endings

    ; Get a random index from the array
    Random, randomIndex, 1, values.MaxIndex()

    ; Return the random value
    return values[randomIndex]
}

Screenshot(fileType := "Valid", subDir := "", ByRef fileName := "") {
    global session
    SetWorkingDir %A_ScriptDir%  ; Ensures the working directory is the script's directory

    ; Define folder and file paths
    fileDir := A_ScriptDir "\..\Screenshots"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%
    if (subDir) {
        fileDir .= "\" . subDir
		if !FileExist(fileDir)
			FileCreateDir, %fileDir%
    }
	if (fileType = "PACKSTATS") {
        fileDir .= "\temp"
		if !FileExist(fileDir)
			FileCreateDir, %fileDir%
	}

    ; File path for saving the screenshot locally
    fileName := A_Now . "_" . session.get("scriptName") . "_" . fileType . "_" . session.get("packsInPool") . "_packs.png"
    if (fileType = "PACKSTATS")
        fileName := "packstats_temp.png"
    filePath := fileDir "\" . fileName

    yBias := 40 - 45
    pBitmapW := from_window(getMuMuHwnd(session.get("winTitle")))
    pBitmap := Gdip_CloneBitmapArea(pBitmapW, 18, 71+yBias, 240, 165)

    ;scale 100%
    Gdip_DisposeImage(pBitmapW)
    Gdip_SaveBitmapToFile(pBitmap, filePath)

    ; Don't dispose pBitmap if it's a PACKSTATS screenshot
    if (fileType != "PACKSTATS") {
        Gdip_DisposeImage(pBitmap)
		return filePath
    }

    ; For PACKSTATS, return both values and delete temp file after OCR is done
    return {filepath: filePath, bitmap: pBitmap, deleteAfterUse: true}
}

; Pause Script
PauseScript:
    CreateStatusMessage("Pausing...",,,, false)
    Pause, On
return

; Resume Script
ResumeScript:
    CreateStatusMessage("Resuming...",,,, false)
    Pause, Off
    session.set("StartSkipTime", A_TickCount) ;reset stuck timers
    session.set("failSafe", A_TickCount)
return

; Stop Script - Main.ahk always exits immediately (no "end of run" concept)
StopScript:
    if (!botConfig.get("groupRerollEnabled")) {
        CreateStatusMessage("Stopping script...",,,, false)
        ExitApp
    }
    settingsPath := A_ScriptDir . "\..\Settings.ini"
    IniRead, savedStopPreferenceMain, %settingsPath%, UserSettings, stopPreferenceMain, none
    if (savedStopPreferenceMain = "immediate") {
        CreateStatusMessage("Stopping script...",,,, false)
        ExitApp
    } else if (savedStopPreferenceMain = "gp_test") {
        Gosub, StopMainAfterGPTest
    } else {
        Gui, StopMain:Destroy
        Gui, StopMain:New, +AlwaysOnTop, Stop Main Instance
        Gui, StopMain:Add, Text, x20 y15 w220 Center, What would you like to do?
        Gui, StopMain:Add, Button, x20 y45 w220 h30 gStopMainImmediately, Stop Immediately
        Gui, StopMain:Add, Button, x20 y80 w220 h30 gStopMainAfterGPTestButton, Run GP Test then Stop
        Gui, StopMain:Add, Checkbox, x20 y120 w220 vui_RememberStopPreferenceMain, Remember my choice
        Gui, StopMain:Show, w260 h150, Stop Main Instance
    }
return

StopMainImmediately:
    Gui, StopMain:Submit, NoHide
    GuiControlGet, RememberStopPreferenceMain, , ui_RememberStopPreferenceMain
    if (RememberStopPreferenceMain) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, immediate, %settingsPath%, UserSettings, stopPreferenceMain
    }
    Gui, StopMain:Destroy
    CreateStatusMessage("Stopping script...",,,, false)
    ExitApp
return

StopMainAfterGPTestButton:
    Gui, StopMain:Submit, NoHide
    Gui, StopMain:Destroy
    GuiControlGet, RememberStopPreferenceMain, , ui_RememberStopPreferenceMain
    if (RememberStopPreferenceMain) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, gp_test, %settingsPath%, UserSettings, stopPreferenceMain
    }

StopMainAfterGPTest:
    session.set("stopAfterGPTest", true)
    if (!session.get("GPTest")) {
        session.set("GPTest", true)
        session.set("triggerTestNeeded", true)
        session.set("testStartTime", A_TickCount)
        CreateStatusMessage("Running GP Test then stopping...",,,, false)
    } else {
        CreateStatusMessage("Will stop after current GP Test completes...",,,, false)
    }
return

StopMainGuiClose:
StopMainGuiEscape:
    Gui, StopMain:Destroy
return

RateLimitSleep:
    session.set("rateLimitAction", "sleep")
    Gui, RateLimit:Destroy
return

RateLimitContinue:
RateLimitGuiClose:
RateLimitGuiEscape:
    session.set("rateLimitAction", "continue")
    Gui, RateLimit:Destroy
return

VipTrimModeChanged:
    Gui, VipTrim:Submit, NoHide
    isCustom := VipTrimCustom
    GuiControl, % (isCustom ? "Enable" : "Disable"), ui_VipCustomCount
    GuiControl, % (isCustom ? "Enable" : "Disable"), ui_VipCustomDirTop
    GuiControl, % (isCustom ? "Enable" : "Disable"), ui_VipCustomDirBottom
return

VipTrimStart:
    Gui, VipTrim:Submit, NoHide

    GuiControlGet, VipTrimTopValue, , ui_VipTrimTop
    GuiControlGet, VipTrimBottomValue, , ui_VipTrimBottom
    GuiControlGet, VipCustomCountValue, , ui_VipCustomCount
    GuiControlGet, VipCustomDirTopValue, , ui_VipCustomDirTop
    GuiControlGet, VipCustomDirBottomValue, , ui_VipCustomDirBottom

    if (VipTrimTopValue) {
        session.set("vipListTrimMode", "top")
        session.set("vipListTrimCount", 60)
    } else if (VipTrimBottomValue) {
        session.set("vipListTrimMode", "bottom")
        session.set("vipListTrimCount", 60)
    } else {
        customCount := VipCustomCountValue + 0
        if (customCount < 1 || customCount > 99) {
            MsgBox, 48, Invalid Count, Please enter a number between 1 and 99.
            return
        }
        session.set("vipListTrimMode", ((VipCustomDirTopValue) ? "top" : "bottom"))
        session.set("vipListTrimCount", customCount)
    }
    session.set("vipListTrimApplied", true)
    settingsPath := A_ScriptDir . "\..\Settings.ini"
    IniWrite, % session.get("vipListTrimMode"), %settingsPath%, UserSettings, vipListTrimMode
    IniWrite, % session.get("vipListTrimCount"), %settingsPath%, UserSettings, vipListTrimCount
    Gui, VipTrim:Destroy
    session.set("vipTrimDialogDone", true)
return

VipTrimGuiClose:
VipTrimGuiEscape:
    Gui, VipTrim:Destroy
    session.set("vipTrimDialogDone", true)
return

ReloadScript:
    SafeReload()
return

TestScript:
    ToggleTestScript()
return

ToggleTestScript() {
    global session
    if(!session.get("GPTest")) {
        session.set("GPTest", true)
        session.set("triggerTestNeeded", true)
        session.set("testStartTime", A_TickCount)
        CreateStatusMessage("In GP Test Mode",,,, false)
        session.set("StartSkipTime", A_TickCount) ;reset stuck timers
        session.set("failSafe", A_TickCount)
    }
    else {
        session.set("GPTest", false)
        session.set("triggerTestNeeded", false)
        totalTestTime := (A_TickCount - session.get("testStartTime")) // 1000
        if (session.get("testStartTime") != "" && (totalTestTime >= 180))
        {
            session.set("firstRun", True)
            session.set("testStartTime", "")
        }
        CreateStatusMessage("Exiting GP Test Mode",,,, false)
    }
}

~+F5::SafeReload()
~+F6::Pause
~+F10::
    Gosub, StopScript
return
~+F9::ToggleTestScript() ; hoytdj Add

bboxAndPause(X1, Y1, X2, Y2, doPause := False) {
    BoxWidth := X2-X1
    BoxHeight := Y2-Y1
    ; Create a GUI
    Gui, BoundingBox:+AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, BoundingBox:Color, 123456
    Gui, BoundingBox:+LastFound  ; Make the GUI window the last found window for use by the line below. (straght from documentation)
    WinSet, TransColor, 123456 ; Makes that specific color transparent in the gui

    ; Create the borders and show
    Gui, BoundingBox:Add, Progress, x0 y0 w%BoxWidth% h2 BackgroundRed
    Gui, BoundingBox:Add, Progress, x0 y0 w2 h%BoxHeight% BackgroundRed
    Gui, BoundingBox:Add, Progress, x%BoxWidth% y0 w2 h%BoxHeight% BackgroundRed
    Gui, BoundingBox:Add, Progress, x0 y%BoxHeight% w%BoxWidth% h2 BackgroundRed
    Gui, BoundingBox:Show, x%X1% y%Y1% NoActivate
    Sleep, 100

    if (doPause) {
        Pause
    }

    if GetKeyState("F4", "P") {
        Pause
    }

    Gui, BoundingBox:Destroy
}

GetNeedle(Path) {
    static NeedleBitmaps := Object()
    if (NeedleBitmaps.HasKey(Path)) {
        return NeedleBitmaps[Path]
    } else {
        pNeedle := Gdip_CreateBitmapFromFile(Path)
        NeedleBitmaps[Path] := pNeedle
        return pNeedle
    }
}

; ^e::
; msgbox ss
; pToken := Gdip_Startup()
; Screenshot()
; return

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ~~~ GP Test Mode Everying Below ~~~
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GPTestScript() {
    global session
    session.set("triggerTestNeeded", false)
    session.set("rateLimitAction", "")
    session.set("vipListTrimApplied", false)
    FavoriteVipFriends()
    if (!session.get("GPTest") || session.get("rateLimitAction") = "sleep")
        return
    if (session.get("gpTestFirstRun")) {
        session.set("gpTestFirstRun", false)
    }
    if (!session.get("hasUnopenedPack")) {
        gpTestWaitStart := A_TickCount
        Loop {
            if (!session.get("GPTest"))
                return
            remaining := session.get("gpTestWaitTime") * 1000 - (A_TickCount - gpTestWaitStart)
            if (remaining <= 0)
                break
            CreateStatusMessage("Waiting for instances to remove friends (" . Ceil(remaining / 1000) . "s)...",,,, false)
            Sleep, 1000
        }
    }
    RemoveNonVipFriends()
}

; Returns true if a friend add/remove op can proceed (and increments the counter).
; In auto GP Test mode, returns false when the rate limit is reached ? caller should abort.
; In manual GP Test mode, waits for the 5-minute window to reset and returns true.
CheckFriendOpsRateLimit() {
    static RateLimitText
    global session
    if (session.get("friendOpsCount") = 0) {
        ; First operation of this window ? start the clock now
        session.set("friendOpsWindowStart", A_TickCount)
    } else {
        elapsed := A_TickCount - session.get("friendOpsWindowStart")
        if (elapsed >= 300000) {
            session.set("friendOpsCount", 0)
            session.set("friendOpsWindowStart", A_TickCount)
        }
    }
    if (session.get("friendOpsCount") >= 10) {
        remaining := 300000 - (A_TickCount - session.get("friendOpsWindowStart"))
        if (remaining <= 0) {
            session.set("friendOpsCount", 0)
            session.set("friendOpsWindowStart", A_TickCount)
        } else if (session.get("A_gptest")) {
            return false
        } else {
            ; Manual mode: show countdown dialog with two cancel options
            session.set("rateLimitAction", "")
            Gui, RateLimit:Destroy
            Gui, RateLimit:New, +AlwaysOnTop, GP Test - Rate Limit
            countdownText := "Rate limit reached. Waiting " . Ceil(remaining / 1000) . "s..."
            Gui, RateLimit:Add, Text, x20 y15 w220 Center hwndhRateLimitText, %countdownText%
            Gui, RateLimit:Add, Text, x20 y42 w220 Center, The next removal may trigger a network error. Please wait.
            Gui, RateLimit:Add, Button, x20 y72 w220 h30 gRateLimitSleep, Stop GP Test && Sleep
            Gui, RateLimit:Add, Button, x20 y107 w220 h30 gRateLimitContinue, Stop GP Test && Continue
            Gui, RateLimit:Show, w260 h150, GP Test - Rate Limit
            Loop {
                remaining := 300000 - (A_TickCount - session.get("friendOpsWindowStart"))
                if (remaining <= 0 || session.get("rateLimitAction") != "")
                    break
                countdownText := "Rate limit reached. Waiting " . Ceil(remaining / 1000) . "s..."
                GuiControl, RateLimit:, %hRateLimitText%, %countdownText%
                Sleep, 1000
            }
            Gui, RateLimit:Destroy
            if (session.get("rateLimitAction") = "sleep") {
                return false  ; "GPTest stays true ? main idles in "Ready to test" mode
            } else if (session.get("rateLimitAction") = "continue") {
                session.set("GPTest", false)
                return false
            }
            ; Timer expired ? reset and continue
            session.set("friendOpsCount", 0)
            session.set("friendOpsWindowStart", A_TickCount)
        }
    }
    session.set("friendOpsCount", session.get("friendOpsCount") + 1)
    return true
}

; FavoriteVipFriends - Mark all VIP friends as favourites 
FavoriteVipFriends() {
    global session, interceptProc

    ; Load persistent GP Test cache from disk.
    ; Always reload from file as it survives bot restarts.
    session.set("gptest_nonFriends", {})
    session.set("gptest_alreadyFavourited", {})
    gptestedFile := A_ScriptDir . "\..\FriendsGPTested_" . session.get("scriptName") . ".txt"
    if FileExist(gptestedFile) {
        Loop, Read, %gptestedFile%
        {
            line := A_LoopReadLine
            ; N: prefix indicates code was tested and is not a friend, 
            ; F: prefix indicates code was tested and is already favourited.
            if (SubStr(line, 1, 2) = "N:") {
                parts := StrSplit(SubStr(line, 3), "|")
                session.get("gptest_nonFriends")["_" . parts[1]] := {Name: parts[2], Time: parts[3]}
            } else if (SubStr(line, 1, 2) = "F:") {
                parts := StrSplit(SubStr(line, 3), "|")
                session.get("gptest_alreadyFavourited")["_" . parts[1]] := {Name: parts[2], Time: parts[3]}
            }
        }
    }

    ; Download and load VIP list
    CreateStatusMessage("Downloading vip_ids.txt.",,,, false)
    if (botConfig.get("groupRerollEnabled") && botConfig.get("vipIdsURL") != "" && !DownloadFile(botConfig.get("vipIdsURL"), "vip_ids.txt")) {
        CreateStatusMessage("Failed to download vip_ids.txt. Aborting FavoriteVipFriends...",,,, false)
        return
    }

    includesIdsAndNames := false
    vipFriendsArray := GetFriendAccountsFromFile(A_ScriptDir . "\..\vip_ids.txt", includesIdsAndNames)

    ; Build vipCodeSet from the FULL remote list before any trimming.
    ; This ensures out-of-trim accounts are never mistaken for ex-VIPs during cache pruning.
    vipCodeSet := {}
    for _, vipFriend in vipFriendsArray
        vipCodeSet[vipFriend.Code] := true

    ; If the remote list is large, trim it to a manageable subset (manual VIPs are never trimmed)
    if (vipFriendsArray.MaxIndex() > 60) {
        if (session.get("A_gptest") && session.get("autoUseGPTest")) {
            ; Auto mode: silently use the bottom 60 (most recently added accounts)
            session.set("vipListTrimMode", "bottom")
            session.set("vipListTrimCount", 60)
            session.set("vipListTrimApplied", true)
            vipFriendsArray := ApplyVipTrim(vipFriendsArray)
        } else {
            vipFriendsArray := PromptVipListTrim(vipFriendsArray)
            if (!session.get("GPTest"))
                return
        }
    }

    manualVipFile := A_ScriptDir . "\..\manual_vip_ids.txt"
    if FileExist(manualVipFile) {
        manualVipFriendsArray := GetFriendAccountsFromFile(manualVipFile, includesIdsAndNames)
        vipFriendsArray.push(manualVipFriendsArray*)
        for _, vipFriend in manualVipFriendsArray
            vipCodeSet[vipFriend.Code] := true
    }

    if (!vipFriendsArray.MaxIndex()) {
        CreateStatusMessage("No accounts found in vip_ids.txt. Aborting FavoriteVipFriends...",,,, false)
        return
    }

    ; Prune silently "N" entries not in VIP list: were never friends, no game action needed
    toDelete := []
    for key, _ in session.get("gptest_nonFriends")
        if (!vipCodeSet.HasKey(SubStr(key, 2)))
            toDelete.Push(key)
    for _, key in toDelete
        session.get("gptest_nonFriends").Delete(key)

    ; Collect "F" entries not in VIP list for in-game de-star + removal (do NOT prune yet)
    ; This tries to catch VIP friends not removed manually by the user
    ; after they lost VIP status, as they would otherwise be missed and left as favourites
    ; in the case they're unfriended and befriended again in the same main session (game bug?)
    toRemove := []
    for key, _ in session.get("gptest_alreadyFavourited")
        if (!vipCodeSet.HasKey(SubStr(key, 2)))
            toRemove.Push(SubStr(key, 2))
    SaveGPTestedCache()

    ; Check if all valid VIP codes are already cached AND no ex-VIPs to clean
    ; We can move to non favourite removal if so
    allCached := true
    for _, vipFriend in vipFriendsArray {
        vipCode := vipFriend.Code
        if (!session.get("gptest_nonFriends").HasKey("_" . vipCode) && !session.get("gptest_alreadyFavourited").HasKey("_" . vipCode)) {
            allCached := false
            break
        }
    }
    if (allCached && !toRemove.MaxIndex()) {
        CreateStatusMessage("All VIP accounts already processed (cached). Skipping FavoriteVipFriends.",,,, false)
        return
    }

    ; Navigate to Social screen
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick(143, 518)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime))
            break
        Delay(5)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("In failsafe for Social. " . failSafeTime "/90 seconds")
    }
    FindImageAndClick("Friend_AddButtonInFriendList", 38, 460, , 500) ; Friends tab
    FindImageAndClick("Friend_SearchFriendButton", 240, 120)
    Delay(1)
    FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 75, 440)
    FindImageAndClick("Friend_FriendIDInputReady", 138, 265)

    ; Build combined list: ex-VIP removals first, then uncached VIPs to star
    allVips := []
    for _, code in toRemove
        allVips.Push({isRemoval: 1, Code: code, Name: session.get("gptest_alreadyFavourited")["_" . code].Name})
    for _, vipFriend in vipFriendsArray
        if (!session.get("gptest_nonFriends").HasKey("_" . vipFriend.Code) && !session.get("gptest_alreadyFavourited").HasKey("_" . vipFriend.Code))
            allVips.Push({isRemoval: 0, Code: vipFriend.Code, Friend: vipFriend})

    n := allVips.MaxIndex()
    for index, vip in allVips {
        if (!session.get("GPTest")) {
            adbInputEvent("4") ; close keyboard
            Sleep, 300
            adbInputEvent("4") ; close search modal
            Sleep, 300
            return
        }

        vipCode := vip.Code

        if (vip.isRemoval)
            CreateStatusMessage("Removing ex-VIP " . index . "/" . n . ": " . vipCode . (vip.Name != "" ? "`n" . vip.Name : ""),,,, false)
        else
            CreateStatusMessage("Favouriting VIP " . index . "/" . n . "`n" . vip.Friend.ToString(),,,, false)

        ; Click search and check result on the search results screen
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            Delay(1)
            adbInput(vipCode)
            Delay(1)
            adbClick_wbb(187, 365)
            Delay(2)
            if(FindOrLoseImage("GPTest_FriendedInSearcResult", 0, failSafeTime)) {
                ; Friend ? enter profile
                failSafe2 := A_TickCount
                Loop {
                    if (!FindOrLoseImage("GPTest_FriendedInSearcResult", 0))
                        break
                    if ((A_TickCount - failSafe2) // 1000 > 30)
                        break
                    adbClick_wbb(143, 258)
                    Sleep, 500
                    CreateStatusMessage("Entering profile`n(" . (A_TickCount - failSafe2) // 1000 . "/30 seconds)")
                }
                ; Wait for FavouriteN or FavouriteY to confirm profile has loaded
                failSafe2 := A_TickCount
                Loop {
                    if (FindOrLoseImage("GPTest_NotFavouriteInDetails", 0)
                        || FindOrLoseImage("GPTest_FavouritedInDetails", 0))
                        break
                    if ((A_TickCount - failSafe2) // 1000 > 30)
                        break
                    Sleep, 500
                    CreateStatusMessage("Waiting for profile to load`n(" . (A_TickCount - failSafe2) // 1000 . "/30 seconds)")
                }
                if (vip.isRemoval) {
                    ; De-star if currently starred, then remove from friends
                    if (FindOrLoseImage("GPTest_FavouritedInDetails", 0)) {
                        adbClick(252, 81)
                        Delay(1)
                    }
                    if (!session.get("hasUnopenedPack") && !CheckFriendOpsRateLimit()) {
                        ; Auto mode rate limit: navigate back to Social and abort
                        FindImageAndClick("Common_ActivatedSocialInMainMenu", 143, 518, , 500)
                        return
                    }
                    rateLimitHit := false
                    FindImageAndClick("Friend_RemoveConfirmButtonInFriendDetails", 145, 407, , 500)
                    Loop {
                        adbClick_wbb(200, 372)
                        if (FindOrLoseImage("Friend_ReqeustButtonInFriendDetails", 0))
                            break
                        if (session.get("hasUnopenedPack") && FindOrLoseImage("Common_Error", 0)) {
                            CreateStatusMessage("Rate limit hit. Recovering...",,,, false)
                            interceptProc := true
                            Loop, 5 {
                                adbClick_wbb(139, 371)
                                Sleep, 500
                                if (!FindOrLoseImage("Common_Error", 0))
                                    break
                            }
                            interceptProc := false
                            session.set("failSafe", A_TickCount)
                            Loop {
                                adbClick_wbb(143, 518)
                                if (FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0))
                                    break
                                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
                                if (failSafeTime > 90) {
                                    session.set("GPTest", false)
                                    restartGameInstance("Stuck at Social after rate limit")
                                    break
                                }
                                CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
                                Delay(3)
                            }
                            FindImageAndClick("Friend_AddButtonInFriendList", 38, 460, , 500)
                            FindImageAndClick("Friend_SearchFriendButton", 240, 120)
                            Delay(2)                        
                            FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 75, 440)
                            FindImageAndClick("Friend_FriendIDInputReady", 138, 265)
                            rateLimitHit := true
                            break
                        }
                        Delay(1)
                    }
                    if (rateLimitHit)
                        continue 2
                    Delay(1)
                    session.get("gptest_alreadyFavourited").Delete("_" . vipCode)
                } else {
                    ; Star if not yet starred
                    if (FindOrLoseImage("GPTest_NotFavouriteInDetails", 0)) {
                        adbClick(252, 81)
                        Delay(1)
                        CreateStatusMessage("Favourited: " . vip.Friend.ToString(),,,, false)
                    } else {
                        CreateStatusMessage("Already favourited: " . vip.Friend.ToString(),,,, false)
                    }
                    FormatTime, checkedAt, , yyyy-MM-dd HH:mm
                    session.get("gptest_alreadyFavourited")["_" . vipCode] := {Name: vip.Friend.Name, Time: checkedAt}
                }
                SaveGPTestedCache()
                break
            }
            else if(FindOrLoseImage("Friend_RequestButtonInSearchResult", 0, failSafeTime)) {
                if (vip.isRemoval) {
                    CreateStatusMessage("Ex-VIP no longer a friend: " . vipCode . (vip.Name != "" ? " (" . vip.Name . ")" : "") . ". Skipping.",,,, false)
                    session.get("gptest_alreadyFavourited").Delete("_" . vipCode)
                } else {
                    CreateStatusMessage("Not friends with VIP: " . vip.Friend.ToString() . ". Skipping.",,,, false)
                    FormatTime, checkedAt, , yyyy-MM-dd HH:mm
                    session.get("gptest_nonFriends")["_" . vipCode] := {Name: vip.Friend.Name, Time: checkedAt}
                }
                SaveGPTestedCache()
                break
            }
            ; Account doesn't exist: banned, deleted, or code never existed
            else if(FindOrLoseImage("GPTest_AccountNotFound", 0, failSafeTime)) {
                adbClick_wbb(138, 380)
                Sleep, 500
                if (vip.isRemoval) {
                    CreateStatusMessage("Code not found (ex-VIP): " . vipCode . (vip.Name != "" ? " (" . vip.Name . ")" : "") . ". Removing from cache.",,,, false)
                    session.get("gptest_alreadyFavourited").Delete("_" . vipCode)
                } else {
                    CreateStatusMessage("Code not found (VIP): " . vip.Friend.ToString() . ". Marking as N.",,,, false)
                    FormatTime, checkedAt, , yyyy-MM-dd HH:mm
                    session.get("gptest_nonFriends")["_" . vipCode] := {Name: vip.Friend.Name, Time: checkedAt}
                }
                SaveGPTestedCache()
                if (index < n)
                    FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 143, 518, , 1000)
                    FindImageAndClick("Friend_FriendIDInputReady", 138, 265, , 1000)
                    EraseInput(index, n)
                continue 2 ; already back at search input ? skip the nav block below
            }
            ; Pending friend request from the account: either VIP that we weren't able to befriend in time,
            ; or ex-VIP that alrerady sent us a request as we were GP Testing
            else if(FindOrLoseImage("GPTest_ReqeustCancelButtonInSearchResult", 0, failSafeTime)) {
                if (vip.isRemoval) {
                    CreateStatusMessage("Pending request from ex-VIP: " . vipCode . (vip.Name != "" ? " (" . vip.Name . ")" : "") . ". Removing from cache.",,,, false)
                    session.get("gptest_alreadyFavourited").Delete("_" . vipCode)
                } else {
                    CreateStatusMessage("Pending request from VIP: " . vip.Friend.ToString() . ". Marking as N.",,,, false)
                    FormatTime, checkedAt, , yyyy-MM-dd HH:mm
                    session.get("gptest_nonFriends")["_" . vipCode] := {Name: vip.Friend.Name, Time: checkedAt}
                }
                SaveGPTestedCache()
                break
            }
            Delay(1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            if (failSafeTime > 20) {
                CreateStatusMessage("Search result unrecognised for: " . vipCode . ". Skipping.",,,, false)
                break
            }
            CreateStatusMessage("Waiting for search result`n(" . failSafeTime . "/20 seconds)")
        }

        ; Return to search input for next item
        if (index < n) {
            FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 143, 518, , 1000)
            FindImageAndClick("Friend_FriendIDInputReady", 138, 265, , 1000)
            EraseInput(index, n)
        }
    }

    ; Return to Social main screen
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop, {
        adbClick_wbb(143, 518)
        Delay(3)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime))
            break
        else if(FindOrLoseImage("Friend_SearchFriendWindowCancelButtonCorner", 0, failSafeTime))
            adbClick_wbb(80, 365)
    }
}

; Removes non-favourited friends starting from the bottom of the list.
; Stops when a favourited (VIP) friend is encountered.
RemoveNonVipFriends() {
    global session

    ; Navigate to Social screen
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick(143, 518)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime))
            break
        Delay(5)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("In failsafe for Social. " . failSafeTime "/90 seconds")
    }
    FindImageAndClick("Friend_AddButtonInFriendList", 38, 460, , 500)
    Delay(3)

    ; Re-download VIP list ? a GP may have been found during the wait, adding new VIPs
    if (botConfig.get("vipIdsURL") != "")
        DownloadFile(botConfig.get("vipIdsURL"), "vip_ids.txt")

    ; Load VIP list from file
    ; Any VIPs missed during favouriting will be caught and handled here
    includesIdsAndNames := false
    vipFriendsArray := GetFriendAccountsFromFile(A_ScriptDir . "\..\vip_ids.txt", includesIdsAndNames)

    manualVipFile := A_ScriptDir . "\..\manual_vip_ids.txt"
    if FileExist(manualVipFile) {
        manualVipFriendsArray := GetFriendAccountsFromFile(manualVipFile, includesIdsAndNames)
        vipFriendsArray.push(manualVipFriendsArray*)
    }

    ; Scroll to the bottom of the friend list 
    ; Might be too much of a scroll, but ensures all *99* friends are loaded and visible
    CreateStatusMessage("Scrolling to bottom of friend list...",,,, false)
    Loop, 20 {
        adbSwipe(143 . " " . 700 . " " . 143 . " " . 110 . " " . 300)
        Sleep, 200
    }
    Delay(2)

    ; Remove non-favourited friends from the bottom up
    ocrFailStreak := 0
    stoppedAtVip := false
    startY := 385 ; tracks the lowest position where a friend was last found
    Loop {
        if (!session.get("GPTest"))
            return

        ; Try to enter the bottommost visible friend's profile, starting from last known position
        enteredProfile := false
        friendRemovedUs := false
        friendClickY := startY
        numPositions := (startY - 195) // 95 + 1
        Loop, %numPositions% {
            ; Click until we navigate away from the list (max 3 attempts)
            Delay(1)
            Loop, 3 {
                adbClick_wbb(138, friendClickY)
                Sleep, 600
                if (!FindOrLoseImage("Friend_AddButtonInFriendList", 0))
                    break
            }
            ; If still on list after all attempts, slot is empty ? try next position
            if (FindOrLoseImage("Friend_AddButtonInFriendList", 0)) {
                friendClickY -= 95
                continue
            }
            ; Wait for profile to fully load ? any of the three states confirms it
            failSafe2 := A_TickCount
            Loop {
                ; Might happen that a friend removed us while we were busy scrolling the list 
                ; and we only realise it after clicking on their profile
                if (FindOrLoseImage("GPTest_FriendRequestButtonInUserDetails", 0)) {
                    CreateStatusMessage("Friend removed us. Skipping...",,,, false)
                    FindImageAndClick("Friend_AddButtonInFriendList", 143, 507, , 1500)
                    Delay(2)
                    friendRemovedUs := true
                    break
                }
                if (FindOrLoseImage("GPTest_NotFavouriteInDetails", 0)
                    || FindOrLoseImage("GPTest_FavouritedInDetails", 0)) {
                    enteredProfile := true
                    break
                }
                if ((A_TickCount - failSafe2) // 1000 > 15)
                    break
                Sleep, 300
            }
            if (enteredProfile || friendRemovedUs)
                break
            friendClickY -= 95
        }

        if (friendRemovedUs)
            continue

        if (!enteredProfile) {
            CreateStatusMessage("No friends found. Done.",,,, false)
            break
        }

        ; Remember lowest position where a friend was found
        startY := friendClickY

        ; Favourited friend reached ? stop removal
        if (FindOrLoseImage("GPTest_FavouritedInDetails", 0)) {
            CreateStatusMessage("Reached favourited (VIP) friend. Stopping removal.",,,, false)
            FindImageAndClick("Friend_AddButtonInFriendList", 143, 507, , 1500)
            stoppedAtVip := true
            break
        }

        ; Not favourited ? OCR check again VIP list in case we missed them during favouriting, 
        ; then remove if still not VIP
        parseFriendResult := ParseFriendInfo(friendCode, friendName, parseFriendCodeResult, parseFriendNameResult, includesIdsAndNames)
        friendAccount := new FriendAccount(friendCode, friendName)

        if (!parseFriendResult) {
            ocrFailStreak++
            CreateStatusMessage("Couldn't parse friend (streak: " . ocrFailStreak . "). Skipping...",,,, false)
            FindImageAndClick("Friend_AddButtonInFriendList", 143, 507, , 1500)
            Delay(2)
            if (ocrFailStreak >= 3) {
                ; Persistent OCR failure on the same position ? move on to avoid infinite loop
                ocrFailStreak := 0
                startY := friendClickY - 95
                if (startY < 195)
                    break
            }
            continue
        }

        ocrFailStreak := 0
        matchedFriend := ""
        isVipResult := IsFriendAccountInList(friendAccount, vipFriendsArray, matchedFriend)

        if (isVipResult) {
            ; VIP missed by FavoriteVipFriends() ? favourite them instead of removing
            CreateStatusMessage("VIP not favourited: " . friendAccount.ToString() . "`nFavouring...",,,, false)
            adbClick(252, 81) ; click favourite star
            Delay(1)
            FormatTime, checkedAt, , yyyy-MM-dd HH:mm
            session.get("gptest_alreadyFavourited")["_" . friendAccount.Code] := {Name: friendAccount.Name, Time: checkedAt}
            SaveGPTestedCache()
            FindImageAndClick("Friend_AddButtonInFriendList", 143, 507, , 1500)
            Delay(2)
            startY := 385 ; re-check from bottom after VIP have moved to top
        } else {
            ; Not VIP ? remove
            CreateStatusMessage("Removing non-VIP friend: " . friendAccount.ToString(),,,, false)
            if (!session.get("hasUnopenedPack") && !CheckFriendOpsRateLimit()) {
                ; Auto mode rate limit: navigate back and stop removal
                FindImageAndClick("Friend_AddButtonInFriendList", 143, 507, , 1500)
                if (session.get("A_gptest") && session.get("autoUseGPTest")) {
                    session.set("A_gptest", 0)
                    session.set("autotest", A_TickCount)
                    ToggleTestScript()
                }
                CreateStatusMessage("Rate limit reached. Stopping removal.",,,, false)
                return
            }
            rateLimitHit := false
            FindImageAndClick("Friend_RemoveConfirmButtonInFriendDetails", 145, 407, , 500)
            Loop {
                adbClick_wbb(200, 372)
                if (FindOrLoseImage("Friend_ReqeustButtonInFriendDetails", 0))
                    break
                if (session.get("hasUnopenedPack") && FindOrLoseImage("Common_Error", 0)) {
                    CreateStatusMessage("Rate limit hit. Recovering...",,,, false)
                    Loop, 5 {
                        adbClick_wbb(139, 371)
                        Sleep, 500
                        if (!FindOrLoseImage("Common_Error", 0))
                            break
                    }
                    session.set("failSafe", A_TickCount)
                    Loop {
                        adbClick_wbb(143, 518)
                        if (FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0))
                            break
                        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
                        if (failSafeTime > 90) {
                            session.set("GPTest", false)
                            restartGameInstance("Stuck at Social after rate limit")
                            break
                        }
                        CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
                        Delay(3)
                    }
                    FindImageAndClick("Friend_AddButtonInFriendList", 38, 460, , 500)
                    Delay(3)
                    Loop, 20 {
                        adbSwipe(143 . " " . 700 . " " . 143 . " " . 110 . " " . 300)
                        Sleep, 200
                    }
                    Delay(2)
                    startY := 385
                    rateLimitHit := true
                    break
                }
                Delay(1)
            }
            if (rateLimitHit)
                continue
            FindImageAndClick("Friend_AddButtonInFriendList", 143, 507, , 1500)
            Delay(2)
        }
    }

    if (stoppedAtVip) {
        if (session.get("A_gptest") && session.get("autoUseGPTest")) {
            session.set("A_gptest", 0)
            session.set("autotest", A_TickCount)
            ToggleTestScript()
        }
        CreateStatusMessage("Ready to test.",,,, false)
    } else if (session.get("A_gptest") && session.get("autoUseGPTest")) {
        session.set("A_gptest", 0)
        ToggleTestScript()
    }
}

; Writes "gptest_nonFriends" and "gptest_alreadyFavourited" to FriendsGPTested.txt.
; Called after each status update so the cache survives bot restarts.
; Keys are stored with a "_" prefix to prevent AHK v1 from normalising numeric strings
; to integers (which would strip leading zeros). The prefix is stripped when writing to file.
SaveGPTestedCache() {
    global session
    filePath := A_ScriptDir . "\..\FriendsGPTested_" . session.get("scriptName") . ".txt"
    FileDelete, %filePath%
    FileAppend, # F: = VIP already starred in-game | N: = not a friend / code not found`n# Format: TYPE:code|name|checked_at`n, %filePath%
    for key, entry in session.get("gptest_nonFriends") {
        code := SubStr(key, 2)
        line := code . "|" . entry.Name . "|" . entry.Time
        FileAppend, N:%line%`n, %filePath%
    }
    for key, entry in session.get("gptest_alreadyFavourited") {
        code := SubStr(key, 2)
        line := code . "|" . entry.Name . "|" . entry.Time
        FileAppend, F:%line%`n, %filePath%
    }
}

; Shows a pop-up when the remote VIP list has > 60 accounts, letting the user choose
; Top 60, Bottom 60, or a custom count from either end.
; Stores the choice in "vipListTrimMode/Count" globals so RemoveNonVipFriends can reuse it.
; Closing the dialog without clicking Start proceeds with the full unmodified list.
PromptVipListTrim(vipFriendsArray) {
    global session
    vipCount := vipFriendsArray.MaxIndex()
    session.set("vipTrimDialogDone", false)

    ; Determine initial dialog state from saved settings
    savedIsCustom := (session.get("vipListTrimCount") != 60 || (session.get("vipListTrimMode") != "top" && session.get("vipListTrimMode") != "bottom"))

    Gui, VipTrim:Destroy
    Gui, VipTrim:New, +AlwaysOnTop, Large VIP List Detected
    Gui, VipTrim:Add, Text, x20 y15 w280 Center, %vipCount% accounts found in the remote VIP list.
    Gui, VipTrim:Add, Text, x20 y35 w280 Center, Select which accounts to GP Test against:
    Gui, VipTrim:Add, Radio, x20 y65 w280 vui_VipTrimTop Group gVipTrimModeChanged, Top 60
    Gui, VipTrim:Add, Radio, x20 y88 w280 vui_VipTrimBottom gVipTrimModeChanged, Bottom 60
    Gui, VipTrim:Add, Radio, x20 y111 w280 vui_VipTrimCustom gVipTrimModeChanged, Custom
    Gui, VipTrim:Add, Text, x40 y138 w85, Count (1-99):
    Gui, VipTrim:Add, Edit, x130 y135 w60 vui_VipCustomCount Number, % session.get("vipListTrimCount")
    Gui, VipTrim:Add, Radio, x40 y162 w80 vui_VipCustomDirTop Group, Top
    Gui, VipTrim:Add, Radio, x130 y162 w80 vui_VipCustomDirBottom, Bottom
    Gui, VipTrim:Add, Button, x20 y195 w280 h30 gVipTrimStart, Start GP Test
    Gui, VipTrim:Show, w320 h242, Large VIP List Detected

    ; Apply saved state: select the right radio and enable/disable custom inputs
    if (savedIsCustom) {
        GuiControl, , ui_VipTrimCustom, 1
        if (session.get("vipListTrimMode") = "top")
            GuiControl, , ui_VipCustomDirTop, 1
        else
            GuiControl, , ui_VipCustomDirBottom, 1
    } else if (session.get("vipListTrimMode") = "top") {
        GuiControl, , ui_VipTrimTop, 1
        GuiControl, Disable, ui_VipCustomCount
        GuiControl, Disable, ui_VipCustomDirTop
        GuiControl, Disable, ui_VipCustomDirBottom
    } else {
        GuiControl, , ui_VipTrimBottom, 1
        GuiControl, Disable, ui_VipCustomCount
        GuiControl, Disable, ui_VipCustomDirTop
        GuiControl, Disable, ui_VipCustomDirBottom
    }

    Loop {
        if (session.get("vipTrimDialogDone"))
            break
        if (!session.get("GPTest")) {
            Gui, VipTrim:Destroy
            return vipFriendsArray
        }
        Sleep, 100
    }
    return ApplyVipTrim(vipFriendsArray)
}

; Applies the stored trim ("vipListTrimMode/Count") to an array without showing a dialog.
; Returns the original array if no trim was selected this run.
ApplyVipTrim(vipFriendsArray) {
    global session
    if (!session.get("vipListTrimApplied"))
        return vipFriendsArray

    vipCount := vipFriendsArray.MaxIndex()
    trimCount := (session.get("vipListTrimCount") < vipCount) ? session.get("vipListTrimCount") : vipCount
    trimmed := []
    if (session.get("vipListTrimMode") = "top") {
        Loop, %trimCount%
            trimmed.Push(vipFriendsArray[A_Index])
    } else {
        startIdx := vipCount - trimCount + 1
        Loop, %trimCount%
            trimmed.Push(vipFriendsArray[startIdx + A_Index - 1])
    }
    CreateStatusMessage("VIP list trimmed to " . trimCount . " accounts (" . session.get("vipListTrimMode") . ").",,,, false)
    return trimmed
}

; Attempts to extract a friend accounts's code and name from the screen, by taking screenshot and running OCR on specific regions.
ParseFriendInfo(ByRef friendCode, ByRef friendName, ByRef parseFriendCodeResult, ByRef parseFriendNameResult, includesIdsAndNames := False) {
    ; ------------------------------------------------------------------------------
    ; The function has a fail-safe mechanism to stop after 5 seconds.
    ;
    ; Parameters:
    ;   friendCode (ByRef String)          - A reference to store the extracted friend code.
    ;   friendName (ByRef String)          - A reference to store the extracted friend name.
    ;   parseFriendCodeResult (ByRef Bool) - A reference to store the result of parsing the friend code.
    ;   parseFriendNameResult (ByRef Bool) - A reference to store the result of parsing the friend name.
    ;   includesIdsAndNames (Bool)         - A flag indicating whether to parse the friend name, in addition to the code (default: False).
    ;
    ; Returns:
    ;   (Boolean) - True if EITHER the friend code OR name were successfully parsed, false otherwise.
    ; ------------------------------------------------------------------------------
    ; Initialize variables
    global session

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    friendCode := ""
    friendName := ""
    parseFriendCodeResult := False
    parseFriendNameResult := False

    Loop {
        ; Grab screenshot via Adb
        fullScreenshotFile := GetTempDirectory() . "\" .  session.get("scriptName") . "_FriendProfile.png"
        adbTakeScreenshot(fullScreenshotFile)

        ; Parse friend identifiers
        if (!parseFriendCodeResult)
            parseFriendCodeResult := ParseFriendInfoLoop(fullScreenshotFile, 265, 57, 240, 28, "0123456789", "^\d{14,17}$", friendCode)
        if (includesIdsAndNames && !parseFriendNameResult)
            parseFriendNameResult := ParseFriendInfoLoop(fullScreenshotFile, 107, 427, 325, 46, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", "^[a-zA-Z0-9]{5,20}$", friendName)
        if (parseFriendCodeResult && (!includesIdsAndNames || parseFriendNameResult))
            break

        ; Break and fail if this take more than 5 seconds
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        if (failSafeTime > 5)
            break
    }

    ; Return true if we were able to parse EITHER the code OR the name
    return parseFriendCodeResult || (includesIdsAndNames && parseFriendNameResult)
}

; Attempts to extract and validate text from a specified region of a screenshot using OCR.
ParseFriendInfoLoop(screenshotFile, x, y, w, h, allowedChars, validPattern, ByRef output) {
    ; ------------------------------------------------------------------------------
    ; The function crops, formats, and scales the screenshot, runs OCR,
    ; and checks if the result matches a valid pattern. It loops through multiple
    ; scaling factors to improve OCR accuracy.
    ;
    ; Parameters:
    ;   screenshotFile (String)   - The path to the screenshot file to process.
    ;   x (Integer)               - The X-coordinate of the crop region.
    ;   y (Integer)               - The Y-coordinate of the crop region.
    ;   w (Integer)               - The width of the crop region.
    ;   h (Integer)               - The height of the crop region.
    ;   allowedChars (String)     - A list of allowed characters for OCR filtering.
    ;   validPattern (String)     - A regular expression pattern to validate the OCR result.
    ;   output (ByRef)            - A reference variable to store the OCR output text.
    ;
    ; Returns:
    ;   (Boolean) - True if valid text was found and matched the pattern, false otherwise.
    ; ------------------------------------------------------------------------------
    success := False
    blowUp := [200, 500, 1000, 2000, 100, 250, 300, 350, 400, 450, 550, 600, 700, 800, 900]
    Loop, % blowUp.Length() {
        ; Get the formatted pBitmap
        pBitmap := CropAndFormatForOcr(screenshotFile, x, y, w, h, blowUp[A_Index])
        ; Run OCR
        output := GetTextFromBitmap(pBitmap, allowedChars)
        ; Validate result
        if (RegExMatch(output, validPattern)) {
            success := True
            break
        }
    }
    return success
}

; FriendAccount class that holds information about a friend account, including the account's code (ID) and name.
class FriendAccount {
    ; ------------------------------------------------------------------------------
    ; Properties:
    ;   Code (String)    - The unique identifier (ID) of the friend account.
    ;   Name (String)    - The name associated with the friend account.
    ;
    ; Methods:
    ;   __New(Code, Name) - Constructor method to initialize the friend account
    ;                       with a code and name.
    ;   ToString()        - Returns a string representation of the friend account.
    ;                       If both the code and name are provided, it returns
    ;                       "Name (Code)". If only one is available, it returns
    ;                       that value, and if both are missing, it returns "Null".
    ; ------------------------------------------------------------------------------
    __New(Code, Name) {
        this.Code := Code
        this.Name := Name
    }

    ToString() {
        if (this.Name != "" && this.Code != "")
            return this.Name . " (" . this.Code . ")"
        if (this.Name == "" && this.Code != "")
            return this.Code
        if (this.Name != "" && this.Code == "")
            return this.Name
        return "Null"
    }
}

; Reads a file containing friend account information, parses it, and returns a list of FriendAccount objects
GetFriendAccountsFromFile(filePath, ByRef includesIdsAndNames) {
    ; ------------------------------------------------------------------------------
    ; The function also determines if the file includes both IDs and names for each friend account.
    ; Friend accounts are only added to the output list if star and pack requirements are met.
    ;
    ; Parameters:
    ;   filePath (String)           - The path to the file to read.
    ;   includesIdsAndNames (ByRef) - A reference variable that will be set to true if the file includes both friend IDs and names.
    ;
    ; Returns:
    ;   (Array) - An array of FriendAccount objects, parsed from the file.
    ; ------------------------------------------------------------------------------
    global botConfig
    friendList := []  ; Create an empty array
    includesIdsAndNames := false

    FileRead, fileContent, %filePath%
    if (ErrorLevel) {
        MsgBox, Failed to read file!
        return friendList  ; Return empty array if file can't be read
    }

    Loop, Parse, fileContent, `n, `r  ; Loop through lines in file
    {
        line := A_LoopField
        if (line = "" || line ~= "^\s*$")  ; Skip empty lines
            continue

        friendCode := ""
        friendName := ""
        twoStarCount := ""
        packName := ""

        if InStr(line, " | ") {
            parts := StrSplit(line, " | ") ; Split by " | "

            ; Check for ID and Name parts
            friendCode := Trim(parts[1])
            friendName := Trim(parts[2])
            if (friendCode != "" && friendName != "")
                includesIdsAndNames := true

            ; Extract the number before "/" in TwoStarCount
            twoStarCount := RegExReplace(parts[3], "\D.*", "")  ; Remove everything after the first non-digit

            packName := Trim(parts[4])
        } else {
            friendCode := Trim(line)
        }

        friendCode := RegExReplace(friendCode, "\D") ; Clean the string (just in case)
        if (!RegExMatch(friendCode, "^\d{14,17}$")) ; Only accept valid IDs
            friendCode := ""
        if (friendCode = "" && friendName = "")
            continue

        ; Trim spaces and create a FriendAccount object
        if (twoStarCount == ""
            || (packName != "Shining" && twoStarCount >= botConfig.get("minStars"))
            || (packName == "" && (twoStarCount >= botConfig.get("minStars"))) ) {
            friend := new FriendAccount(friendCode, friendName)
            friendList.Push(friend)  ; Add to array
        }
    }
    return friendList
}

; Compares two friend accounts to check if they match based on their code and/or name.
MatchFriendAccounts(friend1, friend2, ByRef similarityScore := 1) {
    ; ------------------------------------------------------------------------------
    ; The similarity score between the two accounts is calculated and used to determine a match.
    ; If both the code and name match with a high enough similarity score, the function returns true.
    ;
    ; Parameters:
    ;   friend1 (Object)           - The first friend account to compare.
    ;   friend2 (Object)           - The second friend account to compare.
    ;   similarityScore (ByRef)    - A reference to store the calculated similarity score
    ;                                (defaults to 1).
    ;
    ; Returns:
    ;   (Bool) - True if the accounts match based on the similarity score, false otherwise.
    ; ------------------------------------------------------------------------------
    if (friend1.Code != "" && friend2.Code != "") {
        similarityScore := SimilarityScore(friend1.Code, friend2.Code)
        if (similarityScore > 0.6)
            return true
    }
    if (friend1.Name != "" && friend2.Name != "") {
        similarityScore := SimilarityScore(friend1.Name, friend2.Name)
        if (similarityScore > 0.8) {
            if (friend1.Code != "" && friend2.Code != "") {
                similarityScore := (SimilarityScore(friend1.Code, friend2.Code) + SimilarityScore(friend1.Name, friend2.Name)) / 2
                if (similarityScore > 0.7)
                    return true
            }
            else
                return true
        }
    }
    return false
}

; Checks if a given friend account exists in the friend list. If a match is found, the matching friend's information is returned via the matchedFriend parameter.
IsFriendAccountInList(inputFriend, friendList, ByRef matchedFriend) {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   inputFriend (String)  - The account to search for in the list.
    ;   friendList (Array)    - The list of friends to search through.
    ;   matchedFriend (ByRef) - The matching friend's account information, if found (passed by reference).
    ;
    ; Returns:
    ;   (Bool) - True if a matching friend account is found, false otherwise.
    ; ------------------------------------------------------------------------------
    matchedFriend := ""
    for index, friend in friendList {
        if (MatchFriendAccounts(inputFriend, friend)) {
            matchedFriend := friend
            return true
        }
    }
    return false
}

; Checks if an account has already been added to the friend list. If not, it adds the account to the list.
IsRecentlyCheckedAccount(inputFriend, ByRef friendList) {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   inputFriend (String) - The account to check against the list.
    ;   friendList (Array)   - The list of friends to check the account against.
    ;
    ; Returns:
    ;   (Bool) - True if the account is already in the list, false otherwise.
    ; ------------------------------------------------------------------------------
    if (inputFriend == "") {
        return false
    }

    ; Check if the account is already in the list
    if (IsFriendAccountInList(inputFriend, friendList, matchedFriend)) {
        return true
    }

    ; Add the account to the end of the list
    friendList.Push(inputFriend)

    return false  ; Account was not found and has been added
}

; Handles level up notifications during gameplay by clicking through them if detected.
LevelUp() {
    ; ------------------------------------------------------------------------------
    ; Checks if a level up notification is displayed and clicks through it.
    ; Uses the "LevelUp" image to detect the notification, then finds and clicks
    ; the confirmation button.
    ;
    ; Returns:
    ;   None - Function executes actions and returns
    ; ------------------------------------------------------------------------------
    Leveled := FindOrLoseImage("Common_LevelUpBackground", 0)
    if(Leveled) {
        clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, , 80)
        StringSplit, pos, clickButton, `,  ; Split at ", "
        adbClick(pos1, pos2)
    }
    Delay(1)
}

; Retrieves the path to the temporary directory for the script. If the directory does not exist, it is created.
GetTempDirectory() {
    ; ------------------------------------------------------------------------------
    ; Returns:
    ;   (String) - The full path to the temporary directory.
    ; ------------------------------------------------------------------------------
    tempDir := A_ScriptDir . "\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%
    return tempDir
}

; Wrapper for adbClick with optional bounding box debugging display.
adbClick_wbb(X,Y)  {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   X (Int) - X-coordinate to click
    ;   Y (Int) - Y-coordinate to click
    ;
    ; If dbg_bbox global is enabled, shows a bounding box before clicking.
    ; ------------------------------------------------------------------------------
    global session
    if(session.get("dbg_bbox"))
        bboxAndPause_click(X, Y, session.get("dbg_bboxNpause"))
    adbClick(X,Y)
}

; Displays a bounding box at click location for debugging purposes.
bboxAndPause_click(X, Y, doPause := False) {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   X (Int)       - X-coordinate center of box
    ;   Y (Int)       - Y-coordinate center of box
    ;   doPause (Bool) - Whether to pause execution after displaying box
    ;
    ; Shows a small box around the click point and optionally pauses for debugging.
    ; ------------------------------------------------------------------------------
    global session
    CreateStatusMessage("Clicking X " . X . " Y " . Y,,,, false)

    color := "BackgroundBlue"

    bboxDraw(X-5, Y-5, X+5, Y+5, color)

    if (doPause) {
        Pause
    }

    if GetKeyState("F4", "P") {
        Pause
    }
    guiSuffix := session.get("winTitle")
    Gui, BoundingBox%winTguiSuffixitle%:Destroy
}

; Draws a rectangular bounding box overlay on the screen for debugging.
bboxDraw(X1, Y1, X2, Y2, color) {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   X1 (Int)    - Top-left X coordinate
    ;   Y1 (Int)    - Top-left Y coordinate
    ;   X2 (Int)    - Bottom-right X coordinate
    ;   Y2 (Int)    - Bottom-right Y coordinate
    ;   color (Str) - Color name for the box borders
    ;
    ; Creates a transparent GUI overlay with colored borders to show a region.
    ; ------------------------------------------------------------------------------
    global session

    guiSuffix := session.get("winTitle")
    WinGetPos, xwin, ywin, Width, Height, %guiSuffix%
    BoxWidth := X2-X1
    BoxHeight := Y2-Y1
    ; Create a GUI
    Gui, BoundingBox%guiSuffix%:+AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, BoundingBox%guiSuffix%:Color, 123456
    Gui, BoundingBox%guiSuffix%:+LastFound  ; Make the GUI window the last found window for use by the line below. (straght from documentation)
    WinSet, TransColor, 123456 ; Makes that specific color transparent in the gui

    ; Create the borders and show
    Gui, BoundingBox%guiSuffix%:Add, Progress, x0 y0 w%BoxWidth% h2 %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x0 y0 w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%BoxWidth% y0 w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x0 y%BoxHeight% w%BoxWidth% h2 %color%

    xshow := X1+xwin
    yshow := Y1+ywin
    Gui, BoundingBox%guiSuffix%:Show, x%xshow% y%yshow% NoActivate
    Sleep, 100
}

; Displays a bounding box for image search debugging.
bboxAndPause_immage(X1, Y1, X2, Y2, pNeedleObj, vret := False, doPause := False) {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   X1 (Int)         - Top-left X coordinate of search region
    ;   Y1 (Int)         - Top-left Y coordinate of search region
    ;   X2 (Int)         - Bottom-right X coordinate of search region
    ;   Y2 (Int)         - Bottom-right Y coordinate of search region
    ;   pNeedleObj (Obj) - Needle object containing Name property
    ;   vret (Mixed)     - Return value from image search (for color coding)
    ;   doPause (Bool)   - Whether to pause if image found
    ;
    ; Shows green box if image found, red if not found.
    ; ------------------------------------------------------------------------------
    global session

    guiSuffix := session.get("winTitle")
    CreateStatusMessage("Searching " . pNeedleObj.Name . " returns " . vret,,,, false)

    if(vret>0) {
        color := "BackgroundGreen"
    } else {
        color := "BackgroundRed"
    }

    bboxDraw(X1, Y1, X2, Y2, color)

    if (doPause && vret) {
        Pause
    }

    if GetKeyState("F4", "P") {
        Pause
    }
    Gui, BoundingBox%guiSuffix%:Destroy
}

; Wrapper for Gdip_ImageSearch with bounding box debugging and title bar offset adjustment.
Gdip_ImageSearch_wbb(pBitmapHaystack,pNeedle,ByRef OutputList=""
,OuterX1=0,OuterY1=0,OuterX2=0,OuterY2=0,Variation=0,Trans=""
,SearchDirection=1,Instances=1,LineDelim="`n",CoordDelim=",") {
    ; ------------------------------------------------------------------------------
    ; Wrapper around Gdip_ImageSearch that:
    ;   1. Adjusts Y coordinates for title bar height
    ;   2. Optionally shows debug bounding box if dbg_bbox is enabled
    ;
    ; Parameters: Same as Gdip_ImageSearch
    ; Returns: Result from Gdip_ImageSearch
    ; ------------------------------------------------------------------------------
    global session
    yBias := 40 - 45
    vret := Gdip_ImageSearch(pBitmapHaystack,pNeedle.needle,OutputList,OuterX1,OuterY1+yBias,OuterX2,OuterY2+yBias,Variation,Trans,SearchDirection,Instances,LineDelim,CoordDelim)
    if(session.get("dbg_bbox"))
        bboxAndPause_immage(OuterX1, OuterY1+yBias, OuterX2, OuterY2+yBias, pNeedle, vret, session.get("dbg_bboxNpause"))
    return vret
}

DirectlyPositionWindow() {
    global botConfig, session
    
    scaleParam := 283
    rowGap := botConfig.get("RowGap")

    ; Get monitor information
    SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
    SysGet, Monitor, Monitor, %SelectedMonitorIndex%

    ; Calculate position based on instance number
    Title := session.get("winTitle")

    instanceIndex := StrReplace(Title, "Main", "")
    if (instanceIndex = "")
        instanceIndex := 1

    titleHeight := 40

    borderWidth := 4 - 1
    rowHeight := titleHeight + 492
    currentRow := Floor((instanceIndex - 1) / botConfig.get("Columns"))

    y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
    x := MonitorLeft + (Mod((instanceIndex - 1), botConfig.get("Columns")) * (scaleParam - borderWidth * 2))

    WinSet, Style, -0xC00000, %Title%
    WinMove, %Title%, , %x%, %y%, %scaleParam%, %rowHeight%
    WinSet, Style, +0xC00000, %Title%
    WinSet, Redraw, , %Title%

    CreateStatusMessage("Positioned window at x:" . x . " y:" . y,,,, false)

    return true
}
