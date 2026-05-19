global ScriptDir := RegExReplace(A_LineFile, "\\[^\\]+$"), LogsDir := ScriptDir . "\..\..\Logs"
global Debug, discordWebhookURL, discordUserId, sendAccountXml, botConfig
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

    if (Message != DEFAULT_STATUS_MESSAGE)
        LogDebug(GuiName . ": " . Message)

    Cockpit_WriteLiveMetrics(Message)

    guiWidth := 275
    guiheight := 40
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
            if (!isController)
                SetTimer, % timerReposition, 2000
        }
        if (isController) {
            ; Force the window to exist (hidden) so SendMessage can find it.
            Gui, %GuiName%:Show, Hide
            return
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

Cockpit_WriteLiveMetrics(message) {
    global session

    if (!IsObject(session))
        return

    scriptName := session.get("scriptName")
    if (scriptName = "")
        return

    if !(RegExMatch(scriptName, "^\d+$") || scriptName = "Main")
        return
    return
}

SetReposition(){
    global session

    PosOption := ""
    GuiName := "StatusMessage" . session.get("scriptName")
    instanceHwnd := WinExist(session.get("winTitle") . " ahk_class Qt5156QWindowIcon")

    if(instanceHwnd){
        WinGetPos, xpos, ypos, Width, Height, % session.get("winTitle") . " ahk_class Qt5156QWindowIcon"
        X := xpos + 5 -1
        Y := ypos + 5 + 565 - 11

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
    FormatTime, readableTime, %A_Now%, MMMM dd, yyyy HH:mm:ss

    Loop, {
        FileAppend, % "[" readableTime "] " message "`n", %logFile%
        if !ErrorLevel
            break
        Sleep, 10
    }
}

LogLevelValue(level) {
    level := Trim(level)
    StringLower, level, level
    if (level = "error")
        return 0
    if (level = "warn" || level = "warning")
        return 1
    if (level = "info")
        return 2
    if (level = "debug")
        return 3
    if (level = "trace")
        return 4
    return 2
}

LogConfiguredLevel() {
    global botConfig, Debug

    configured := "info"
    if (IsObject(botConfig)) {
        configured := botConfig.get("logLevel")
        if (configured = "")
            configured := "info"
        if (botConfig.get("verboseLogging") && LogLevelValue(configured) < LogLevelValue("debug"))
            configured := "debug"
    } else if (Debug) {
        configured := "debug"
    }
    return configured
}

ShouldLog(level := "info") {
    return LogLevelValue(level) <= LogLevelValue(LogConfiguredLevel())
}

LogMessage(level, message, logFile := "") {
    level := Trim(level)
    if (level = "")
        level := "info"
    StringLower, level, level
    if (!ShouldLog(level))
        return
    LogToFile("[" . level . "] " . message, logFile)
}

LogError(message, logFile := "") {
    LogMessage("error", message, logFile)
}

LogWarn(message, logFile := "") {
    LogMessage("warn", message, logFile)
}

LogInfo(message, logFile := "") {
    LogMessage("info", message, logFile)
}

LogDebug(message, logFile := "") {
    LogMessage("debug", message, logFile)
}

LogTrace(message, logFile := "") {
    LogMessage("trace", message, logFile)
}

GetActiveDiscordProfile() {
    global botConfig, discordWebhookURL, discordUserId, sendAccountXml

    profile := {"name": "Solo", "webhookURL": discordWebhookURL, "userId": discordUserId, "sendAccountXml": sendAccountXml}

    if (!IsObject(botConfig))
        return profile

    if (botConfig.get("groupRerollEnabled")) {
        profile.name := "Group Reroll"
        profile.webhookURL := botConfig.get("groupRerollDiscordWebhookURL")
        profile.userId := botConfig.get("groupRerollDiscordUserId")
        profile.sendAccountXml := botConfig.get("groupRerollSendAccountXml")
    } else {
        profile.webhookURL := botConfig.get("discordWebhookURL")
        profile.userId := botConfig.get("discordUserId")
        profile.sendAccountXml := botConfig.get("sendAccountXml")
    }

    return profile
}

DiscordShouldSendAccountXml() {
    profile := GetActiveDiscordProfile()
    return profile.sendAccountXml
}

LogMissingDiscordWebhook(profileName) {
    static warnedProfiles := {}

    if (warnedProfiles.HasKey(profileName))
        return

    warnedProfiles[profileName] := true
    LogWarn(profileName . " Discord webhook URL is not configured. Message was not sent.", "Discord.txt")
    CreateStatusMessage(profileName . " Discord webhook missing.",,,, false)
}

LogToDiscord(message, screenshotFile := "", ping := false, xmlFile := "", screenshotFile2 := "", altWebhookURL := "", altUserId := "") {
    profile := GetActiveDiscordProfile()
    discordPing := ""

    if (ping) {
        userId := (altUserId ? altUserId : profile.userId)

        if (userId)
            discordPing := "<@" . userId . "> "
        discordFriends := ReadFile("discord")
        if (discordFriends) {
            for index, value in discordFriends {
                if (value = "" || value = userId)
                    continue
                discordPing .= "<@" . value . "> "
            }
        }
    }

    webhookURL := (altWebhookURL ? altWebhookURL : profile.webhookURL)

    if (webhookURL = "") {
        if (!altWebhookURL)
            LogMissingDiscordWebhook(profile.name)
        return
    }

    if (webhookURL != "") {
        MaxRetries := 10
        RetryCount := 0
        try {
            RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
            RegRead, proxyServer, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyServer
        } catch {
            ProxyEnable := false
            ProxyServer := ""
        }
        if (proxyEnabled) {
            curlChar := "curl -k -x " . proxyServer . "/ "
        } else {
            curlChar := "curl -k "
        }
        Loop {
            try {
                ; Base command
                curlCommand := curlChar
                    . "-F ""payload_json={\""content\"":\""" . discordPing . message . "\""};type=application/json;charset=UTF-8"" "

                ; If an screenshot or xml file is provided, send it
                sendScreenshot1 := screenshotFile != "" && FileExist(screenshotFile)
                sendScreenshot2 := screenshotFile2 != "" && FileExist(screenshotFile2)
                sendXmlFile := xmlFile != "" && FileExist(xmlFile)
                if (sendScreenshot1 + sendScreenshot2 + sendXmlFile > 1) {
                    fileIndex := 0
                    if (sendScreenshot1) {
                        fileIndex++
                        curlCommand := curlCommand . "-F ""file" . fileIndex . "=@" . screenshotFile . """ "
                    }
                    if (sendScreenshot2) {
                        fileIndex++
                        curlCommand := curlCommand . "-F ""file" . fileIndex . "=@" . screenshotFile2 . """ "
                    }
                    if (sendXmlFile) {
                        fileIndex++
                        curlCommand := curlCommand . "-F ""file" . fileIndex . "=@" . xmlFile . """ "
                    }
                }
                else if (sendScreenshot1 + sendScreenshot2 + sendXmlFile == 1) {
                    if (sendScreenshot1)
                        curlCommand := curlCommand . "-F ""file=@" . screenshotFile . """ "
                    if (sendScreenshot2)
                        curlCommand := curlCommand . "-F ""file=@" . screenshotFile2 . """ "
                    if (sendXmlFile)
                        curlCommand := curlCommand . "-F ""file=@" . xmlFile . """ "
                }
                ; Add the webhook
                curlCommand := curlCommand . webhookURL

                LogDebug(curlCommand, "Discord.txt")

                ; Send the message using curl
                RunWait, %curlCommand%,, Hide
                break
            }
            catch {
                RetryCount++
                if (RetryCount >= MaxRetries) {
                    CreateStatusMessage("Failed to send discord message.")
                    break
                }
                Sleep, 250
            }
            Sleep, 250
        }
    }
}
