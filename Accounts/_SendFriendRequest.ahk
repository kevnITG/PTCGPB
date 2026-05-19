; _SendFriendRequest.ahk
; Sends friend request(s): first to [General] FriendID in Settings.ini, then to any
; extra 16-digit codes in InjectAccount.ini ([UserSettings] injectExtraFriendIDs=, comma-separated).
; At most 10 codes total are sent (order: Settings.ini first, then extras; further codes are dropped).
; Usage: _SendFriendRequest.ahk "<winTitle>" "<folderPath>"

#SingleInstance off
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetBatchLines, -1
SetTitleMatchMode, 3
CoordMode, Pixel, Screen
#NoEnv

DllCall("AllocConsole")
WinHide % "ahk_id " DllCall("GetConsoleWindow", "ptr")

if (A_Args.Length() < 2) {
    MsgBox, 16, Send Friend Request, Usage:`n`n_SendFriendRequest.ahk "<winTitle>" "<folderPath>"
    ExitApp, 1
}

global g_winTitle   := A_Args[1]
global g_folderPath := A_Args[2]

global g_settingsPath := A_ScriptDir . "\..\Settings.ini"
if (!FileExist(g_settingsPath)) {
    MsgBox, 16, Send Friend Request, Cannot find Settings.ini at:`n%g_settingsPath%
    ExitApp, 1
}
IniRead, g_friendIDRaw, %g_settingsPath%, General, FriendID, ERROR

SetWorkingDir, %A_ScriptDir%\..\Scripts

#Include %A_ScriptDir%\..\Scripts\Include\Config.ahk
#Include %A_ScriptDir%\..\Scripts\Include\Session.ahk
#Include %A_ScriptDir%\..\Scripts\Include\Gdip_All.ahk
#Include %A_ScriptDir%\..\Scripts\Include\Gdip_Imagesearch.ahk

global pToken := Gdip_Startup()

#Include %A_ScriptDir%\..\Scripts\Include\Utils.ahk
#Include %A_ScriptDir%\..\Scripts\Include\ADB.ahk
#Include %A_ScriptDir%\..\Scripts\Include\Coords.ahk

global g_injectIniPath := A_ScriptDir . "\InjectAccount.ini"
IniRead, g_injectExtraRaw, %g_injectIniPath%, UserSettings, injectExtraFriendIDs,
if (g_injectExtraRaw = "ERROR")
    g_injectExtraRaw := ""

; Stubs for the few Logging.ahk symbols ADB.ahk / Utils.ahk reference,
; without pulling in the floating status GUI from Logging.ahk itself.
global ScriptDir := RegExReplace(A_LineFile, "\\[^\\]+$")
global LogsDir   := A_ScriptDir . "\..\Logs"
global Debug := 0
global discordWebhookURL := ""
global discordUserId := ""
global sendAccountXml := 0

CreateStatusMessage(Message, GuiName := "StatusMessage", X := 0, Y := 565, debugOnly := true, Persist := false) {
}
ResetStatusMessage() {
}
LogToFile(message, logFile := "") {
    global LogsDir
    if (logFile = "")
        logFile := LogsDir . "\Log_" . StrReplace(A_ScriptName, ".ahk") . ".txt"
    else
        logFile := LogsDir . "\" . logFile
    FormatTime, readableTime, %A_Now%, MMMM dd, yyyy HH:mm:ss
    try {
        FileAppend, % "[" readableTime "] " message "`n", %logFile%
    } catch e {
    }
}
LogInfo(message, logFile := "") {
    LogToFile("[info] " . message, logFile)
}
LogWarn(message, logFile := "") {
    LogToFile("[warn] " . message, logFile)
}
LogError(message, logFile := "") {
    LogToFile("[error] " . message, logFile)
}
LogDebug(message, logFile := "") {
    global botConfig
    if (IsObject(botConfig) && (botConfig.get("logLevel") = "debug" || botConfig.get("logLevel") = "trace" || botConfig.get("verboseLogging")))
        LogToFile("[debug] " . message, logFile)
}
LogTrace(message, logFile := "") {
    global botConfig
    if (IsObject(botConfig) && botConfig.get("logLevel") = "trace")
        LogToFile("[trace] " . message, logFile)
}
LogToDiscord(message, screenshotFile := "", ping := false, xmlFile := "", screenshotFile2 := "", altWebhookURL := "", altUserId := "") {
}

global session   := new Session()
global botConfig := new BotConfig()

botConfig.loadSettingsToConfig("ALL")

runtimeFolder := botConfig.get("folderPath")
if (runtimeFolder = "" || !InStr(FileExist(runtimeFolder), "D"))
    botConfig.set("folderPath", g_folderPath, "General")

session.set("scriptName",    g_winTitle)
session.set("winTitle",      g_winTitle)
session.set("scriptIniFile", A_ScriptDir . "\..\Scripts\" . g_winTitle . ".ini")
session.set("dbg_bbox", 0)
session.set("dbg_bboxNpause", 0)
session.set("failSafe", A_TickCount)
session.set("baseTime", 0)

g_friendIDList := BuildFriendRequestIdList(g_friendIDRaw, g_injectExtraRaw)
if (!g_friendIDList.MaxIndex()) {
    MsgBox, 16, Send Friend Request, No friend codes to send.`n`nSet a valid 16-digit [General] FriendID= in Settings.ini and/or add optional extra codes in Inject Account (injectExtraFriendIDs).
    ExitApp, 1
}

hwnd := getMuMuHwnd(g_winTitle)
if (!hwnd) {
    MsgBox, 16, Send Friend Request, Cannot find MuMu instance window: %g_winTitle%`n`nMake sure the instance is running.
    ExitWithCleanup(2)
}

; Strip caption + force the canonical 283x532 client size the needle
; coordinates are calibrated against (matches DirectlyPositionWindow in 1.ahk).
WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
WinGet, curStyle, Style, ahk_id %hwnd%
needsCaptionStrip := (curStyle & 0x00C00000) != 0
needsResize := (ww != 283 || wh != 532)
if (needsCaptionStrip)
    WinSet, Style, -0xC00000, ahk_id %hwnd%
if (needsResize)
    WinMove, ahk_id %hwnd%, , %wx%, %wy%, 283, 532
if (needsCaptionStrip || needsResize)
    Sleep, 180

setADBBaseInfo()
ConnectAdb()
initializeAdbShell()

; The adb shell child process opens its own console window; hide it.
try {
    adbPid := session.get("adbShell").ProcessID
    if (adbPid) {
        WinWait, ahk_pid %adbPid%, , 2
        WinHide, ahk_pid %adbPid%
    }
} catch e {
}

allFriendRequestsOk := true
g_friendIdTotal := g_friendIDList.MaxIndex()
Loop, %g_friendIdTotal% {
    fid := g_friendIDList[A_Index]
    if (A_Index = 1) {
        if (!SendFriendRequestFromMainMenu(fid)) {
            allFriendRequestsOk := false
            LogWarn("SendFriendRequest failed for ID index " . A_Index . " / " . g_friendIdTotal)
        }
    } else {
        if (!PrepareNextFriendIdEntry()) {
            MsgBox, 48, Send Friend Request, Could not reset the add-friend dialog before request %A_Index%/%g_friendIdTotal%. Stopping.
            allFriendRequestsOk := false
            break
        }
        if (!SubmitFriendIdSearchAndWait(fid)) {
            allFriendRequestsOk := false
            LogWarn("SendFriendRequest failed for ID index " . A_Index . " / " . g_friendIdTotal)
        }
    }
    Sleep, 1200
}
ExitWithCleanup(allFriendRequestsOk ? 0 : 4)

GetNeedle(Path) {
    static NeedleBitmaps := Object()

    if (NeedleBitmaps.HasKey(Path))
        return NeedleBitmaps[Path]

    pNeedle := Gdip_CreateBitmapFromFile(Path)
    needleObj := Object()
    needleObj.Path := Path
    pathsplit := StrSplit(Path , "\")
    needleObj.Name := pathsplit[pathsplit.MaxIndex()]
    needleObj.needle := pNeedle
    NeedleBitmaps[Path] := needleObj
    return needleObj
}

findNeedle(needleName, searchVariation := 20) {
    global needlesDict, session

    needleObj := needlesDict.Get(needleName)
    if (!needleObj)
        return false

    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    if (!pBitmap)
        return false

    Path := A_ScriptDir . "\..\Scripts\Needles\" . needleObj.imageName . ".png"
    pNeedle := GetNeedle(Path)

    vPosXY := ""
    vRet := Gdip_ImageSearch(pBitmap, pNeedle.needle, vPosXY
        , needleObj.coords.startX, needleObj.coords.startY
        , needleObj.coords.endX,   needleObj.coords.endY
        , searchVariation)
    Gdip_DisposeImage(pBitmap)

    if (vRet = 1)
        return vPosXY ? vPosXY : true
    return false
}

waitForNeedle(needleName, timeoutSec := 60) {
    start := A_TickCount
    Loop {
        if (findNeedle(needleName))
            return true
        if ((A_TickCount - start) // 1000 >= timeoutSec)
            return false
        Sleep, 250
    }
    return false
}

tap(X, Y) {
    adbClick(X, Y)
}

clickUntilNeedle(needleName, clickX, clickY, timeoutSec := 30, retryMs := 800) {
    start := A_TickCount
    lastClick := 0
    Loop {
        if (findNeedle(needleName))
            return true

        if ((A_TickCount - lastClick) >= retryMs) {
            tap(clickX, clickY)
            lastClick := A_TickCount
        }

        if ((A_TickCount - start) // 1000 >= timeoutSec)
            return false

        Sleep, 250
    }
    return false
}

BuildFriendRequestIdList(settingsRaw, injectExtraRaw) {
    list := []
    sid := Trim(settingsRaw)
    if (sid != "" && sid != "ERROR" && RegExMatch(sid, "^\d{16}$"))
        list.Push(sid)
    cleaned := RegExReplace(injectExtraRaw, "[\r\n]+", ",")
    cleaned := RegExReplace(cleaned, "\|+", ",")
    cleaned := RegExReplace(cleaned, "[\t; ]+", ",")
    Loop {
        if (!InStr(cleaned, ",,"))
            break
        StringReplace, cleaned, cleaned, `,,`,, All
    }
    cleaned := Trim(cleaned, " `t,")
    Loop, Parse, cleaned, `,
    {
        id := Trim(A_LoopField)
        if (!RegExMatch(id, "^\d{16}$"))
            continue
        if (!HasVal(list, id))
            list.Push(id)
    }
    if (list.MaxIndex() > 10) {
        oldN := list.MaxIndex()
        fixed := []
        Loop, 10
            fixed.Push(list[A_Index])
        list := fixed
        LogInfo("Friend request list truncated to 10 codes (had " . oldN . ").")
    }
    return list
}

; Same pattern as FriendManager between multiple adds: close dialog, reopen blank field, clear text.
PrepareNextFriendIdEntry() {
    if (!clickUntilNeedle("Friend_SearchFriendWindowCancelButtonCorner", 143, 518, 25, 1500))
        return false
    Sleep, 400
    if (!clickUntilNeedle("Friend_FriendIDInputReady", 138, 265, 25, 1500))
        return false
    Loop, 12 {
        tap(138, 265)
        Sleep, 120
        adbInputEvent("59 122 67")
        Sleep, 200
        if (findNeedle("Friend_InputFormBlank"))
            return true
    }
    return true
}

SubmitFriendIdSearchAndWait(fid) {
    Sleep, 300
    adbInput(fid)
    Sleep, 500
    tap(187, 365)

    sent := false
    start := A_TickCount
    Loop {
        if (!sent && findNeedle("Friend_RequestButtonInSearchResult")) {
            tap(243, 258)
            sent := true
            Sleep, 700
            continue
        }

        if (findNeedle("Friend_WithdrawButton")) {
            Sleep, 800
            return true
        }
        if (findNeedle("Friend_AcceptedButtonInSearchResult")) {
            Sleep, 800
            return true
        }
        if (findNeedle("Friend_CannotFriendRequest")) {
            MsgBox, 48, Send Friend Request, Game refused the friend request:`n  - already friends, OR`n  - friend list full, OR`n  - invalid Friend ID.
            return false
        }

        if ((A_TickCount - start) // 1000 > 30) {
            MsgBox, 48, Send Friend Request, Timed out waiting for the friend-request confirmation. The request may or may not have gone through.
            return false
        }

        ; Dismiss soft keyboard if it stole focus.
        if (!sent)
            adbInputEvent("59 122 67")

        Sleep, 300
    }
}

SendFriendRequestFromMainMenu(fid) {
    if (!clickUntilNeedle("Common_ActivatedSocialInMainMenu", 143, 518, 240, 1500)) {
        MsgBox, 16, Send Friend Request, Timed out (4 min) waiting for the game to reach the main menu.
        return false
    }

    if (!gotoFriendSearchPanel(60)) {
        MsgBox, 16, Send Friend Request, Could not reach the Friend Search panel within 60 s.
        return false
    }

    if (!clickUntilNeedle("Friend_SearchFriendWindowCancelButtonCorner", 75, 440, 20, 1000)) {
        MsgBox, 16, Send Friend Request, Could not open the "Add Friend by ID" dialog.
        return false
    }
    if (!clickUntilNeedle("Friend_FriendIDInputReady", 138, 265, 20, 1000)) {
        MsgBox, 16, Send Friend Request, Could not focus the Friend ID input field.
        return false
    }

    return SubmitFriendIdSearchAndWait(fid)
}

gotoFriendSearchPanel(timeoutSec := 60) {
    start := A_TickCount
    Loop {
        if (findNeedle("Friend_SearchFriendButton"))
            return true

        if (findNeedle("Common_ActivatedSocialInMainMenu")) {
            tap(38, 460)
        }
        else if (findNeedle("Friend_AddButtonInFriendList")) {
            tap(240, 120)
            Sleep, 300
        }
        else {
            tap(155, 425)
        }

        if ((A_TickCount - start) // 1000 >= timeoutSec)
            return false

        Sleep, 400
    }
    return false
}

ExitWithCleanup(code := 0) {
    global pToken, session
    try {
        if (session.get("adbShell"))
            session.get("adbShell").Terminate()
    } catch e {
    }
    try {
        Gdip_Shutdown(pToken)
    } catch e {
    }
    ExitApp, % code
}

OnGuiClose:
GuiClose:
    ExitWithCleanup(0)
return
