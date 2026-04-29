#Include *i %A_LineFile%\..\Gdip_All.ahk

setADBBaseInfo(){
    mumuFolder := getMuMuFolder()
    if(mumuFolder == ""){
        MsgBox, 16, , Can't Find MuMu, try old MuMu installer in Discord #announcements, otherwise double check your folder path setting!`nDefault path is C:\Program Files\Netease
        ExitApp
    }
    adbPath := findAdbPath(mumuFolder)

    adbPort := findAdbPorts()
    if(!adbPort) {
        Msgbox, Invalid port... Check the common issues section in the readme/github guide.
        ExitApp
    }

    session.set("adbPort", adbPort)
    session.set("adbPath", adbPath)
    session.set("baseTime", 0)
}

KillADBProcesses() {
    ; Use AHK's Process command to close adb.exe
    Process, Close, adb.exe
    ; Fallback to taskkill for robustness
    RunWait, %ComSpec% /c taskkill /IM adb.exe /F /T,, Hide
}

findAdbPorts() {
    global session

    ; Initialize variables
    mumuFolder := getMuMuFolder()
    if(mumuFolder == ""){
        MsgBox, 16, , Can't Find MuMu, try old MuMu installer in Discord #announcements, otherwise double check your folder path setting!`nDefault path is C:\Program Files\Netease
        ExitApp
    }
    
    mumuFolder = %mumuFolder%\vms\*

    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolder%, D  ; D flag to include directories only
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"  ; The config folder inside each directory

        ; Check if config folder exists
        IfExist, %configFolder%
        {
            ; Define paths to vm_config.json and extra_config.json
            vmConfigFile := configFolder "\vm_config.json"
            extraConfigFile := configFolder "\extra_config.json"

            ; Check if vm_config.json exists and read adb host port
            IfExist, %vmConfigFile%
            {
                FileRead, vmConfigContent, %vmConfigFile%
                ; Parse the JSON for adb host port
                RegExMatch(vmConfigContent, """host_port"":\s*""(\d+)""", adbHostPort)
                adbPortValue := adbHostPort1  ; Capture the adb host port value
            }

            ; Check if extra_config.json exists and read playerName
            IfExist, %extraConfigFile%
            {
                FileRead, extraConfigContent, %extraConfigFile%
                ; Parse the JSON for playerName
                RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                if(playerName1 = session.get("scriptName")) {
                    return adbPortValue
                }
            }
        }
    }
}

ConnectAdb() {
    global session

    MaxRetries := 5
    RetryCount := 1
    connected := false
    ip := "127.0.0.1:" . session.get("adbPort") ; Specify the connection IP:port

    CreateStatusMessage("Connecting to ADB...",,,, false)

    Loop %MaxRetries% {
        ; Attempt to connect using CmdRet
        connectionResult := CmdRet(session.get("adbPath") . " connect " . ip)

        ; Check for successful connection in the output
        if InStr(connectionResult, "connected to " . ip) {
            connected := true
            CreateStatusMessage("ADB connected successfully.",,,, false)
            return true
        } else {
            RetryCount++
            CreateStatusMessage("ADB connection failed.`nRetrying (" . RetryCount . "/" . MaxRetries . ")...",,,, false)
            Sleep, 2000
        }

        if !connected {
            disconnectionResult := CmdRet(session.get("adbPath") . " disconnect 127.0.0.1:" . session.get("adbPort"))
            connectionResult := CmdRet(session.get("adbPath") . " connect 127.0.0.1:" . session.get("adbPort"))
            LogToFile("[" . A_ScriptName . "] ADB connection failed in ConnectAdb. Bot is reconnecting to ADB.(" . RetryCount . "/" . MaxRetries . ") Connection result: " . connectionResult, "ADB.txt")

            if (RetryCount > MaxRetries) {
                if (Debug)
                    CreateStatusMessage("Failed to connect to ADB after multiple retries. Please check your emulator and port settings.")
                else
                    CreateStatusMessage("Failed to connect to ADB.",,,, false)
                Reload
            }
        }
    }
}

DisableBackgroundServices() {
    global session

    deviceAddress := "127.0.0.1:" . session.get("adbPort")
    commands := []
    ;commands.Push("pm disable-user --user 0 ""com.google.android.gms/.chimera.PersistentIntentOperationService"" 2> /dev/null")
    ;commands.Push("pm disable-user --user 0 ""com.google.android.gms/com.google.android.location.reporting.service.ReportingAndroidService"" 2> /dev/null")
    commands.Push("pm disable-user --user 0 com.mumu.store 2> /dev/null")
    ;commands.Push("pm disable-user --user 0 com.android.chromium 2> /dev/null")
    commands.Push("pm disable-user --user 0 com.android.documentsui 2> /dev/null")
    commands.Push("pm disable-user --user 0 com.android.gallery3d 2> /dev/null")
    commands.Push("pm disable-user --user 0 com.netease.mumu.cloner 2> /dev/null")

    for index, command in commands {
        fullCommand := """" . session.get("adbPath") . """ -s " . deviceAddress . " shell " . command
        result := CmdRet(fullCommand)
        ;LogToFile("DisableService result (" . command . "): " . result, "ADB.txt")
    }
}

initializeAdbShell() {
    global botConfig, session, Debug
    
    RetryCount := 1
    MaxRetries := 5
    BackoffTime := 1000  ; Initial backoff time in milliseconds
    MaxBackoff := 5000   ; Prevent excessive waiting

    Loop {
        try {
            if (!session.get("adbShell") || session.get("adbShell").Status != 0) {
                session.set("adbShell", "")  ; Reset before reattempting

                ; Validate adbPath and adbPort
                if (!FileExist(session.get("adbPath"))) {
                    throw Exception("ADB path is invalid: " . session.get("adbPath"))
                }
                if (session.get("adbPort") < 0 || session.get("adbPort") > 65535) {
                    throw Exception("ADB port is invalid: " . session.get("adbPort"))
                }

                ; Attempt to start adb shell
                session.set("adbShell", ComObjCreate("WScript.Shell").Exec(session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort") . " shell"))

                ; Ensure adbShell is running before sending 'su'
                Sleep, 500
                if (session.get("adbShell").Status != 0) {
                    RetryCount++
                    disconnectionResult := CmdRet(session.get("adbPath") . " disconnect 127.0.0.1:" . session.get("adbPort"))
                    connectionResult := CmdRet(session.get("adbPath") . " connect 127.0.0.1:" . session.get("adbPort"))
                    LogToFile("[" . A_ScriptName . "] ADB connection failed in initializeAdbShell. Bot is reconnecting to ADB.(" . RetryCount . "/" . MaxRetries . ") Connection result: " . connectionResult, "ADB.txt")

                    if (RetryCount > MaxRetries) {
                        throw Exception("Failed to start ADB shell.")
                    }
                    else
                        continue
                }

                try {
                    RetryCount++
                    session.get("adbShell").StdIn.WriteLine("su")
                } catch e2 {
                    if (RetryCount > MaxRetries) {
                        throw Exception("Failed to elevate shell: " . (IsObject(e2) ? e2.Message : e2))
                    }
                }
            }

            ; If adbShell is running, break loop
            if (session.get("adbShell").Status = 0) {
                break
            }
        } catch e {
            errorMessage := IsObject(e) ? e.Message : e
            LogToFile("[" . A_ScriptName . "] ADB Shell Error: " . errorMessage, "ADB.txt")

            if (RetryCount >= MaxRetries) {
                if (Debug)
                    CreateStatusMessage("Failed to connect to shell after multiple attempts: " . errorMessage)
                else
                    CreateStatusMessage("Failed to connect to shell. Retrying...",,,, false)

                RetryCount := 1  ; Reset retry count for next round
            }
        }

        Sleep, BackoffTime
        BackoffTime := Min(BackoffTime + 1000, MaxBackoff)  ; Limit backoff time
    }
}

waitUntilActivatePTCGPApp(){
    global session, Debug

    session.set("baseTime", A_TickCount)
    adbCommand := session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort")
    Loop, {
        result := CmdRet(adbCommand . " shell dumpsys window | grep -E 'mCurrentFocus'")
        if (InStr(result, "jp.pokemon.pokemontcgp"))
            break

        Sleep, 200
        if((A_TickCount - session.get("baseTime")) > 10000){
            return false
        }
    }

    return true
}

startPTCGPApp(){
    maxRetry := 5
    retryCount := 0

    stateResult := isCurrentScreenHome()
    if(stateResult)
        adbWriteRaw("am start -W -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity -f 0x10018000")

    Loop, {
        stateResult := waitUntilActivatePTCGPApp()
        if(!stateResult)
            retryCount++
        else
            break

        if(retryCount > maxRetry)
            break

        Sleep, 50
    }
    DelayH(100)
}

closePTCGPApp(){
    maxRetry := 5
    retryCount := 0
    stateResult := false

    stateResult := isCurrentScreenHome()
    if(!stateResult)
        adbWriteRaw("am start -W -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity -f 0x10018000")
    
    Loop, {
        stateResult := isCurrentScreenHome()
        if(!stateResult)
            retryCount++
        else
            break

        if(retryCount > maxRetry)
            break
        
        Sleep, 50
    }
    DelayH(100)
}

isCurrentScreenHome(){
    global session

    adbCommand := session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort")
    result := CmdRet(adbCommand . " shell dumpsys window | grep -E 'mCurrentFocus'")
    if (!InStr(result, "jp.pokemon.pokemontcgp")){
        Sleep, 250
        return true
    }
    else
        return false
}

isTerminatePTCGPAppByADBShell(){
    result := adbWriteRaw("pidof jp.pokemon.pokemontcgp", true)
    if (RegExMatch(result, "\d+")) {
        return false
    }
    else
        return true
}

isTerminatePTCGPApp(){
    global session

    adbCommand := session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort")
    result := CmdRet(adbCommand . " shell pidof jp.pokemon.pokemontcgp")
    if (RegExMatch(result, "\d+")) {
        return false
    }
    else
        return true
}

clearMissionCache() {
    adbWriteRaw("rm -f /data/data/jp.pokemon.pokemontcgp/files/UserPreferences/v1/MissionUserPrefs")
    Sleep, 250
}

adbEnsureShell() {
    global session

    pid := session.get("adbShell").ProcessID
    Process, Exist, %pid%

    if (!ErrorLevel || session.get("adbShell").Status != 0) {
        initializeAdbShell()
    }
}

adbWriteRaw(command, isReturnning := false) {
    global session
    retries := 0
    MaxRetries := 3
    loopCount := 0
    result := ""

    Loop {
        try {
            session.get("adbShell").StdIn.WriteLine(command . ";echo done;")
            while !session.get("adbShell").StdOut.AtEndOfStream {
                pid := session.get("adbShell").ProcessID
                Process, Exist, %pid%

                if (!ErrorLevel || session.get("adbShell").Status != 0) {
                    initializeAdbShell()
                    break
                }
                
                line := session.get("adbShell").StdOut.ReadLine()
                if (line = "done"){
                    if(isReturnning)
                        return result
                    else
                        return true
                }
                else if(isReturnning)
                    result .= line . "`n"

                Sleep, 50
            }

            if(loopCount > 5){
                throw Exception("[adbWriteRaw] Command was attempted more than 5 times but failed.")
                loopCount := 0
            }
            else
                loopCount++
            
        } catch e {
            errorMessage := IsObject(e) ? e.Message : e
            retries++
            LogToFile("[" . A_ScriptName . "] ADB write error(" . retries . "/" . MaxRetries . ") Command: " . command . ", Error: " . errorMessage, "ADB.txt")
            session.set("adbShell", "")
            if (retries >= MaxRetries){
                LogToFile("[" . A_ScriptName . "] Reconnect to ADB Server. command: " . command, "ADB.txt")
                adbEnsureShell()
            }
            Sleep, 300
        }
    }
}

waitadb(){
    return
}

adbClick(X, Y) {
    static clickCommands := Object()
    static convX := 540/283, convY := 960/488, offset := -40

    key := X << 16 | Y

    if (!clickCommands.HasKey(key)) {
        clickCommands[key] := Format("input tap {} {}"
            , Round(X * convX)
            , Round((Y + offset) * convY))
    }
    adbWriteRaw(clickCommands[key])
}

adbInput(name) {
    adbWriteRaw("input text " . name)
    waitadb()
}

adbInputEvent(event) {
    if InStr(event, " ") {
        ; If the event uses a space, we use keycombination
        adbWriteRaw("input keycombination " . event)
    } else {
        ; It's a single key event (e.g., "67")
        adbWriteRaw("input keyevent " . event)
    }
    waitadb()
}

; Simulates a swipe gesture on an Android device, swiping from one X/Y-coordinate to another.
adbSwipe(params) {
    adbWriteRaw("input swipe " . params)
    waitadb()
}

; Simulates a touch gesture on an Android device to scroll in a controlled way.
; Not currently supported.
adbGesture(params) {
    ; Example params (a 2-second hold-drag from a lower to an upper Y-coordinate): 0 2000 138 380 138 90 138 90
    adbWriteRaw("input touchscreen gesture " . params)
    waitadb()
}

; Takes a screenshot of an Android device using ADB and saves it to a file.
adbTakeScreenshot(outputFile) {
    ; Percroy Optimization
    global session
    
    static pTokenLocal := 0
    if (!pTokenLocal) {
        pTokenLocal := Gdip_Startup()
    }
    
    deviceAddress := "127.0.0.1:" . session.get("adbPort")
    baseCommand := """" . session.get("adbPath") . """ -s " . deviceAddress

    hwnd := getMuMuHwnd(session.get("winTitle"))
    if (!hwnd) {
        command := baseCommand . " exec-out screencap -p > """ .  outputFile . """"
        RunWait, %ComSpec% /c "%command%", , Hide
        return
    }

    pBitmap := Gdip_BitmapFromHWND(hwnd)

    if (!pBitmap || pBitmap = "") {
        deviceAddress := "127.0.0.1:" . session.get("adbPort")
        command := baseCommand . " exec-out screencap -p > """ .  outputFile . """"
        RunWait, %ComSpec% /c "%command%", , Hide
        return
    }

    SplitPath, outputFile, , outputDir
    if (outputDir && !FileExist(outputDir)) {
        FileCreateDir, %outputDir%
    }
    
    result := Gdip_SaveBitmapToFile(pBitmap, outputFile)
    
    Gdip_DisposeImage(pBitmap)
    
    if (!result || result = -1) {
        deviceAddress := "127.0.0.1:" . session.get("adbPort")
        command := baseCommand . " exec-out screencap -p > """ .  outputFile . """"
        RunWait, %ComSpec% /c "%command%", , Hide
        return
    }
}
