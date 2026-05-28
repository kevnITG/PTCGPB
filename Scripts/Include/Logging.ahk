global ScriptDir := RegExReplace(A_LineFile, "\\[^\\]+$"), LogsDir := ScriptDir . "\..\..\Logs"
global Debug, discordWebhookURL, discordUserId, sendAccountXml
global DEFAULT_STATUS_MESSAGE := "..."

; Read settings.
settingsPath := ScriptDir . "\..\..\Settings.ini"

IniRead, discordWebhookURL, %settingsPath%, UserSettings, discordWebhookURL
if (discordWebhookURL = "ERROR" || discordWebhookURL = "")
    IniRead, discordWebhookURL, %settingsPath%, Wonderpick, discordWebhookURL
if (discordWebhookURL = "ERROR")
    discordWebhookURL := ""
IniRead, discordUserId, %settingsPath%, UserSettings, discordUserId
if (discordUserId = "ERROR" || discordUserId = "")
    IniRead, discordUserId, %settingsPath%, Wonderpick, discordUserId
if (discordUserId = "ERROR")
    discordUserId := ""
IniRead, sendAccountXml, %settingsPath%, UserSettings, sendAccountXml, 0
if (sendAccountXml = "ERROR" || sendAccountXml = "")
    IniRead, sendAccountXml, %settingsPath%, Wonderpick, sendAccountXml, 0
IniRead, Debug, %settingsPath%, UserSettings, debugMode, 0

; Enable debugging to get more status messages and logging.

ResetStatusMessage() {
    CreateStatusMessage(DEFAULT_STATUS_MESSAGE,,,, false, true)
}

CreateStatusMessage(Message, GuiName := "StatusMessage", X := 0, Y := 565, debugOnly := true, Persist := false) {
    global session

    static hwnds := {}
    static resetStatusFunc := Func("ResetStatusMessage")
    static timerReposition
    if (!timerReposition)
        timerReposition := Func("SetReposition")

    if (Debug && Message != DEFAULT_STATUS_MESSAGE)
        LogToFile(GuiName . ": " . Message)

    guiWidth := 275
    guiheight := 40
    Y := NormalizeStatusMessageY(Y)
	if(GuiName = "AvgRuns" || GuiName = "AutoGPTest" || GuiName = "AccountInfo")
		guiheight := 30

    if(GuiName = "AccountInfo"){
        guiWidth := 260
        guiheight := 25
    }

    try {

        ; Check if GUI with this name already exists.
        GuiName := GuiName . session.get("scriptName")
		
        if !hwnds.HasKey(GuiName) {
            WinGetPos, xpos, ypos, Width, Height, % session.get("winTitle") . " ahk_class Qt5156QWindowIcon"
            X := X + xpos + 5 -1
            Y := Y + ypos + 5 - 11
            if (!X)
                X := 0
            if (!Y)
                Y := 0

            ; Create a new GUI with the given name, position, and message
            Gui, %GuiName%:New, -AlwaysOnTop +ToolWindow -Caption -DPIScale
            Gui, %GuiName%:Margin, 2, 2  ; Set margin for the GUI
            Gui, %GuiName%:Font, s8  ; Set the font size to 8 (adjust as needed)
            Gui, %GuiName%:Add, Text, hwndhCtrl,
            hwnds[GuiName] := hCtrl
            OwnerWND := WinExist(session.get("winTitle") . " ahk_class Qt5156QWindowIcon")
            if(OwnerWND){
                Gui, %GuiName%:+Owner%OwnerWND% +LastFound
                DllCall("SetWindowPos", "Ptr", WinExist(), "Ptr", 1  ; HWND_BOTTOM
                    , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)  ; SWP_NOSIZE, SWP_NOMOVE, SWP_NOACTIVATE

                Gui, %GuiName%:Show, NoActivate x%X% y%Y% w%guiWidth% h%guiheight%
            }
            SetTimer, % timerReposition, 2000
        }
        SetTextAndResize(hwnds[GuiName], Message)
        Gui, %GuiName%:Show, NoActivate  w%guiWidth% h%guiheight%

        ; Clear any previous timers.
        SetTimer, % resetStatusFunc, Off

        if (!Debug && !Persist) {
            ; Reset status message to default after 2 seconds.
            SetTimer, % resetStatusFunc, -2000
        }
    }
}

SetReposition(){
    global session

    PosOption := ""
    GuiName := "StatusMessage" . session.get("scriptName")
    instanceHwnd := WinExist(session.get("winTitle") . " ahk_class Qt5156QWindowIcon")

    if(instanceHwnd){
        WinGetPos, xpos, ypos, Width, Height, % session.get("winTitle") . " ahk_class Qt5156QWindowIcon"
        X := xpos + 5 -1
        Y := ypos + 5 + NormalizeStatusMessageY(565) - 11

        if (!X)
            X := 0
        if (!Y)
            Y := 0

        Gui, %GuiName%:+LastFound
        CurrentHwnd := WinExist()
        WinGetPos, CurX, CurY,,, ahk_id %CurrentHwnd%

        if(CurX == X && CurY == Y)
            return

        PosOption := "x" . X . " y" . Y
    }
    else
        return

    Gui, %GuiName%:Show, NoActivate %PosOption%
}

NormalizeStatusMessageY(Y) {
    windowMetrics := GetMumuWindowMetrics()

    if (Y = 565)
        return windowMetrics.rowHeight + 33

    if (Y = 605)
        return windowMetrics.rowHeight + 73

    return Y
}

;Modified from https://stackoverflow.com/a/49354127
SetTextAndResize(controlHwnd, newText) {
    dc := DllCall("GetDC", "Ptr", controlHwnd)

    ; 0x31 = WM_GETFONT
    SendMessage 0x31,,,, ahk_id %controlHwnd%
    hFont := ErrorLevel
    oldFont := 0
    if (hFont != "FAIL")
        oldFont := DllCall("SelectObject", "Ptr", dc, "Ptr", hFont)

    VarSetCapacity(rect, 16, 0)
    ; 0x440 = DT_CALCRECT | DT_EXPANDTABS
    h := DllCall("DrawText", "Ptr", dc, "Ptr", &newText, "Int", -1, "Ptr", &rect, "UInt", 0x440)
    ; width = rect.right - rect.left
    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")

    if oldFont
        DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
    DllCall("ReleaseDC", "Ptr", controlHwnd, "Ptr", dc)

    GuiControl,, %controlHwnd%, %newText%
    GuiControl MoveDraw, %controlHwnd%, % "h" h " w" w
}

LogToFile(message, logFile := "") {
    if (logFile = "") {
        logFile := LogsDir . "\Log_" . StrReplace(A_ScriptName, ".ahk") . ".txt"
    }
    else
        logFile := LogsDir . "\" . logFile
    if !FileExist(LogsDir)
        FileCreateDir, %LogsDir%
    RotateLogFileIfNeeded(logFile)
    FormatTime, readableTime, %A_Now%, MMMM dd, yyyy HH:mm:ss

    Loop, {
        FileAppend, % "[" readableTime "] " message "`n", %logFile%
        if !ErrorLevel
            break
        Sleep, 10
    }
}

LogDebugToFile(message, logFile := "") {
    global Debug

    if (Debug)
        LogToFile(message, logFile)
}

RotateLogFileIfNeeded(logFile) {
    static lastCheck := {}
    maxBytes := 5 * 1024 * 1024
    checkIntervalMs := 60000

    if (logFile = "" || !FileExist(logFile))
        return

    last := lastCheck.HasKey(logFile) ? lastCheck[logFile] : 0
    elapsed := A_TickCount - last
    if (last && elapsed >= 0 && elapsed < checkIntervalMs)
        return
    lastCheck[logFile] := A_TickCount

    FileGetSize, fileSize, %logFile%
    if (ErrorLevel || fileSize < maxBytes)
        return

    SplitPath, logFile, fileName, logDir, ext, nameNoExt
    if (logDir = "" || nameNoExt = "")
        return
    if (ext = "")
        ext := "log"

    archiveDir := logDir . "\Archive"
    if !FileExist(archiveDir)
        FileCreateDir, %archiveDir%

    FormatTime, stamp, %A_Now%, yyyyMMdd_HHmmss
    pid := DllCall("GetCurrentProcessId")
    archivePath := archiveDir . "\" . nameNoExt . "_" . stamp . "_" . pid . "_" . A_TickCount . "." . ext
    FileMove, %logFile%, %archivePath%, 0
    if ErrorLevel
        return

    PruneLogArchives(archiveDir, nameNoExt, ext)
}

PruneLogArchives(archiveDir, nameNoExt, ext) {
    keepArchives := 3
    archiveList := ""
    archivePattern := archiveDir . "\" . nameNoExt . "_*." . ext

    Loop, Files, %archivePattern%, F
    {
        FileGetTime, fileTime, %A_LoopFileFullPath%, M
        if !ErrorLevel
            archiveList .= fileTime . A_Tab . A_LoopFileFullPath . "`n"
    }

    if (archiveList = "")
        return

    Sort, archiveList, R
    archiveCount := 0
    Loop, Parse, archiveList, `n, `r
    {
        if (A_LoopField = "")
            continue

        archiveCount++
        if (archiveCount <= keepArchives)
            continue

        tabPos := InStr(A_LoopField, A_Tab)
        if (!tabPos)
            continue

        oldArchive := SubStr(A_LoopField, tabPos + 1)
        FileDelete, %oldArchive%
    }
}

LogToDiscord(message, screenshotFile := "", ping := false, xmlFile := "", screenshotFile2 := "", altWebhookURL := "", altUserId := "", logSuccessfulDelivery := true) {
    discordPing := ""

    if (ping) {
        userId := (altUserId ? altUserId : discordUserId)

        discordPing := "<@" . userId . "> "
        discordFriends := ReadFile("discord")
        if (discordFriends) {
            for index, value in discordFriends {
                if (value = userId)
                    continue
                discordPing .= "<@" . value . "> "
            }
        }
    }

    webhookURL := (altWebhookURL ? altWebhookURL : discordWebhookURL)

    if (webhookURL = "") {
        LogToFile("Discord send skipped: missing webhook URL", "Discord.txt")
        return
    }

    if (webhookURL != "") {
        MaxRetries := 3
        RetryCount := 0
        discordTraceId := CreateDiscordTraceId()
        try {
        RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
        RegRead, proxyServer, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyServer
        } catch {
            ProxyEnable := false
            ProxyServer := ""
        }
        if (proxyEnabled && proxyServer != "") {
            curlChar := "curl.exe -k -sS --retry 2 --retry-delay 2 --connect-timeout 10 --max-time 60 -o NUL -w ""HTTP_STATUS:%{http_code}"" -x """ . proxyServer . """ "
        } else {
            curlChar := "curl.exe -k -sS --retry 2 --retry-delay 2 --connect-timeout 10 --max-time 60 -o NUL -w ""HTTP_STATUS:%{http_code}"" "
        }

        payloadFile := CreateDiscordPayloadFile(discordPing . message)
        if (payloadFile = "") {
            LogToFile("Discord send failed before curl: could not create payload file | trace=" . discordTraceId . " | webhook=" . RedactDiscordWebhookURL(webhookURL), "Discord.txt")
            return
        }

        Loop {
            RetryCount++
            try {
                ; Base command
                curlCommand := curlChar . "-F ""payload_json=<" . payloadFile . ";type=application/json;charset=UTF-8"" "

                ; If an screenshot or xml file is provided, send it
                sendScreenshot1 := screenshotFile != "" && FileExist(screenshotFile)
                sendScreenshot2 := screenshotFile2 != "" && FileExist(screenshotFile2)
                sendAccountXml := xmlFile != "" && FileExist(xmlFile)
                fileCount := sendScreenshot1 + sendScreenshot2 + sendAccountXml
                if (sendScreenshot1 + sendScreenshot2 + sendAccountXml > 1) {
                    fileIndex := 0
                    if (sendScreenshot1) {
                        fileIndex++
                        curlCommand := curlCommand . "-F ""file" . fileIndex . "=@" . screenshotFile . """ "
                    }
                    if (sendScreenshot2) {
                        fileIndex++
                        curlCommand := curlCommand . "-F ""file" . fileIndex . "=@" . screenshotFile2 . """ "
                    }
                    if (sendAccountXml) {
                        fileIndex++
                        curlCommand := curlCommand . "-F ""file" . fileIndex . "=@" . xmlFile . """ "
                    }
                }
                else if (sendScreenshot1 + sendScreenshot2 + sendAccountXml == 1) {
                    if (sendScreenshot1)
                        curlCommand := curlCommand . "-F ""file=@" . screenshotFile . """ "
                    if (sendScreenshot2)
                        curlCommand := curlCommand . "-F ""file=@" . screenshotFile2 . """ "
                    if (sendAccountXml)
                        curlCommand := curlCommand . "-F ""file=@" . xmlFile . """ "
                }
                ; Add the webhook
                curlCommand := curlCommand . """" . webhookURL . """"

                if(logSuccessfulDelivery)
                    LogToFile("Discord send attempt | trace=" . discordTraceId . " | attempt=" . RetryCount . "/" . MaxRetries . " | webhook=" . RedactDiscordWebhookURL(webhookURL) . " | files=" . fileCount . " | messageLen=" . StrLen(message), "Discord.txt")

                ; Send the message using curl
                if (IsFunc("CmdRet")) {
                    cmdFn := Func("CmdRet")
                    curlResult := cmdFn.Call(curlCommand)
                } else {
                    RunWait, %curlCommand%,, Hide
                    curlResult := "HTTP_STATUS:" . ErrorLevel
                }

                httpStatus := GetDiscordCurlHttpStatus(curlResult)
                if (httpStatus >= 200 && httpStatus < 300) {
                    if(logSuccessfulDelivery || RetryCount > 1)
                        LogToFile("Discord send complete | trace=" . discordTraceId . " | status=" . httpStatus . " | webhook=" . RedactDiscordWebhookURL(webhookURL) . " | files=" . fileCount . " | messageLen=" . StrLen(message), "Discord.txt")
                    break
                }

                LogToFile("Discord send failed | trace=" . discordTraceId . " | attempt=" . RetryCount . "/" . MaxRetries . " | status=" . httpStatus . " | webhook=" . RedactDiscordWebhookURL(webhookURL) . " | files=" . fileCount . " | result=" . TrimDiscordCurlResult(curlResult), "Discord.txt")
            }
            catch e {
                LogToFile("Discord send exception | trace=" . discordTraceId . " | attempt=" . RetryCount . "/" . MaxRetries . " | webhook=" . RedactDiscordWebhookURL(webhookURL) . " | error=" . FormatDiscordException(e), "Discord.txt")
            }

            if (RetryCount >= MaxRetries) {
                LogToFile("Discord send exhausted | trace=" . discordTraceId . " | attempts=" . RetryCount . " | webhook=" . RedactDiscordWebhookURL(webhookURL), "Discord.txt")
                CreateStatusMessage("Failed to send discord message.")
                break
            }
            Sleep, % 1000 * RetryCount
        }

        FileDelete, %payloadFile%
    }
}

CreateDiscordTraceId() {
    static sequence := 0
    sequence++
    return A_Now . "_" . DllCall("GetCurrentProcessId") . "_" . A_TickCount . "_" . sequence
}

CreateDiscordPayloadFile(content) {
    payloadJson := "{""content"":""" . DiscordEscapeJson(content) . """}"
    payloadFile := A_Temp . "\ptcgpb_discord_payload_" . DllCall("GetCurrentProcessId") . "_" . A_TickCount . ".json"

    FileDelete, %payloadFile%
    FileAppend, %payloadJson%, %payloadFile%, UTF-8-RAW
    if (ErrorLevel || !FileExist(payloadFile))
        return ""

    return payloadFile
}

DiscordEscapeJson(text) {
    text := StrReplace(text, "\n", "`n")
    text := StrReplace(text, Chr(92), Chr(92) . Chr(92))
    text := StrReplace(text, Chr(34), Chr(92) . Chr(34))
    text := StrReplace(text, "`r", "")
    text := StrReplace(text, "`n", Chr(92) . "n")
    text := StrReplace(text, "`t", Chr(92) . "t")
    return text
}

GetDiscordCurlHttpStatus(curlResult) {
    if RegExMatch(curlResult, "HTTP_STATUS:(\d{3})", match)
        return match1 + 0
    return 0
}

TrimDiscordCurlResult(curlResult) {
    curlResult := StrReplace(curlResult, "`r", " ")
    curlResult := StrReplace(curlResult, "`n", " ")
    curlResult := Trim(curlResult)

    if (StrLen(curlResult) > 500)
        curlResult := SubStr(curlResult, 1, 500) . "..."

    return curlResult
}

RedactDiscordWebhookURL(webhookURL) {
    return RegExReplace(webhookURL, "i)(/api/webhooks/[^/]+/)[^?\s]+", "$1<redacted>")
}

FormatDiscordException(e) {
    if (IsObject(e)) {
        if (e.Message != "")
            return e.Message
        if (e.What != "")
            return e.What
    }
    return e
}
