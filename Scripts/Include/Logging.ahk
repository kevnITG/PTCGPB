global ScriptDir := RegExReplace(A_LineFile, "\\[^\\]+$"), LogsDir := ScriptDir . "\..\..\Logs"
global Debug, discordWebhookURL, discordUserId, sendAccountXml
global DEFAULT_STATUS_MESSAGE := "..."

; Read settings.
settingsPath := ScriptDir . "\..\..\Settings.ini"

IniRead, discordWebhookURL, %settingsPath%, UserSettings, discordWebhookURL
IniRead, discordUserId, %settingsPath%, UserSettings, discordUserId
IniRead, sendAccountXml, %settingsPath%, UserSettings, sendAccountXml, 0
IniRead, showStatus, %settingsPath%, UserSettings, statusMessage, 1
IniRead, Debug, %settingsPath%, UserSettings, debugMode, 0

; Enable debugging to get more status messages and logging.

ResetStatusMessage() {
    CreateStatusMessage(DEFAULT_STATUS_MESSAGE,,,, false, true)
}

CreateStatusMessage(Message, GuiName := "StatusMessage", X := 0, Y := 565, debugOnly := true, Persist := false) {
    static hwnds := {}
    static resetStatusFunc := Func("ResetStatusMessage")

    if (!showStatus)
        return

    if (Debug && Message != DEFAULT_STATUS_MESSAGE)
        LogToFile(GuiName . ": " . Message)

    if(GuiName = "AvgRuns" || GuiName = "AutoGPTest")
        guiheight := 20
    else
        guiheight := 40

    try {
        ; Check if GUI with this name already exists.
        GuiName := GuiName . scriptName

        if !hwnds.HasKey(GuiName) {
            WinGetPos, xpos, ypos, Width, Height, %winTitle%
            X := X + xpos + 5
            Y := Y + ypos
            if (!X)
                X := 0
            if (!Y)
                Y := 0

            ; Create a new GUI with the given name, position, and message
            Gui, %GuiName%:New, -AlwaysOnTop +ToolWindow -Caption -DPIScale
            Gui, %GuiName%:Margin, 2, 2  ; Set margin for the GUI
            Gui, %GuiName%:Font, s8  ; Set the font size to 8 (adjust as needed)
            Gui, %GuiName%:Add, Text, hwndhCtrl vStatusText,
            hwnds[GuiName] := hCtrl
            OwnerWND := WinExist(winTitle)
            Gui, %GuiName%:+Owner%OwnerWND% +LastFound
            DllCall("SetWindowPos", "Ptr", WinExist(), "Ptr", 1  ; HWND_BOTTOM
                , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)  ; SWP_NOSIZE, SWP_NOMOVE, SWP_NOACTIVATE

            Gui, %GuiName%:Show, NoActivate x%X% y%Y% w275 h%guiheight%
        }
        SetTextAndResize(hwnds[GuiName], Message)
        Gui, %GuiName%:Show, NoActivate  w275 h%guiheight%

        ; Clear any previous timers.
        SetTimer, % resetStatusFunc, Off

        if (!Debug && !Persist) {
            ; Reset status message to default after 2 seconds.
            SetTimer, % resetStatusFunc, -2000
        }
    }
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
    FileAppend, % "[" readableTime "] " message "`n", %logFile%
}

LogToDiscord(message, screenshotFile := "", ping := false, xmlFile := "", screenshotFile2 := "", altWebhookURL := "", altUserId := "") {
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
                sendAccountXml := xmlFile != "" && FileExist(xmlFile)
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
                curlCommand := curlCommand . webhookURL

                LogToFile(curlCommand, "Discord.txt")

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
