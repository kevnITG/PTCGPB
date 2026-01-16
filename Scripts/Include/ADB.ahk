global adbPort, adbShell, adbPath
#Include *i %A_LineFile%\..\Gdip_All.ahk

global NOTIFY_ADB_SERVER_HANG := 0x9000
global isADBHang := false
global currentInstanceNo := 0
RegExMatch(A_ScriptName, "\d+", currentInstanceNo)

OnMessage(NOTIFY_ADB_SERVER_HANG, "procADBClient")

procADBClient(wParam, lParam){
    if(wParam = 20) {
        isADBHang := true
    }
    else if (wParam = 40) {
        Sleep, 250

        CreateStatusMessage("Resume operations.")
        
        ConnectAdb()
        initializeAdbShell()
        
        isADBHang := false
        LogToFile("[" . A_ScriptName . "] Resume operations.", "ADB.txt")

        Sleep, 1500
    }
    else if(wParam = 51){
        if(lParam = 0)
            sendNotifyADBStatus(40, currentInstanceNo, A_ScriptName)
    }
}

findAdbPorts(baseFolder := "C:\Program Files\Netease") {
    global scriptName

    ; Initialize variables
    mumuFolder = %baseFolder%\MuMuPlayerGlobal-12.0\vms\*
    if !FileExist(mumuFolder)
        mumuFolder = %baseFolder%\MuMu Player 12\vms\*

    if !FileExist(mumuFolder){
        MsgBox, 16, , Can't Find MuMu, try old MuMu installer in Discord #announcements, otherwise double check your folder path setting!`nDefault path is C:\Program Files\Netease`nFolder Path:%mumuFolder%
        ExitApp
    }
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
                adbPort := adbHostPort1  ; Capture the adb host port value
            }

            ; Check if extra_config.json exists and read playerName
            IfExist, %extraConfigFile%
            {
                FileRead, extraConfigContent, %extraConfigFile%
                ; Parse the JSON for playerName
                RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                if(playerName1 = scriptName) {
                    return adbPort
                }
            }
        }
    }
}

ConnectAdb(folderPath := "C:\Program Files\Netease") {
    IniRead, folderPath, %A_ScriptDir%\..\Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
    adbPort := findAdbPorts(folderPath)
    adbPath := folderPath . "\MuMuPlayerGlobal-12.0\shell\adb.exe"

    if !FileExist(adbPath) ;if international mumu file path isn't found look for chinese domestic path
        adbPath := folderPath . "\MuMu Player 12\shell\adb.exe"
    if !FileExist(adbPath) ;MuMu Player 12 v5 supported
        adbPath := folderPath . "\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
    if !FileExist(adbPath) ;MuMu Player 12 v5 supported
        adbPath := folderPath . "\MuMu Player 12\nx_main\adb.exe"

    if !FileExist(adbPath)
        MsgBox Check folder path! It must contain the MuMuPlayer12 folder! `nDefault is C:\Program Files\Netease

    if(!adbPort) {
        Msgbox, Invalid port... Check the common issues section in the readme/github guide.
        ExitApp
    }

    MaxRetries := 5
    RetryCount := 1
    connected := false
    ip := "127.0.0.1:" . adbPort ; Specify the connection IP:port

    CreateStatusMessage("Connecting to ADB...",,,, false)

    Loop %MaxRetries% {
        ; Attempt to connect using CmdRet
        connectionResult := CmdRet(adbPath . " connect " . ip)

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
            adbPort := findAdbPorts(folderPath)
            disconnectionResult := CmdRet(adbPath . " disconnect 127.0.0.1:" . adbPort)

            adbPort := findAdbPorts(folderPath)
            connectionResult := CmdRet(adbPath . " connect 127.0.0.1:" . adbPort)
            LogToFile("ADB connection failed in ConnectAdb. Bot is reconnecting to ADB.(" . RetryCount . "/" . MaxRetries . ") Connection result: " . connectionResult, "ADB.txt")

            if (RetryCount > MaxRetries) {
                if(!isADBHang){
                    LogToFile("Found hang Instance: " . currentInstanceNo, "ADB.txt")
                    sendNotifyADBStatus(10, currentInstanceNo, "ADBManager.ahk")
                    isADBHang := true
                    break
                }
                else
                    isADBHang()
            }
        }
    }
}

DisableBackgroundServices() {
    global adbPath, adbPort

    if (!adbPath || !adbPort)
        return

    deviceAddress := "127.0.0.1:" . adbPort
    commands := []
    commands.Push("pm disable-user --user 0 ""com.google.android.gms/.chimera.PersistentIntentOperationService"" 2> /dev/null")
    commands.Push("pm disable-user --user 0 ""com.google.android.gms/com.google.android.location.reporting.service.ReportingAndroidService"" 2> /dev/null")
    commands.Push("pm disable-user --user 0 com.mumu.store 2> /dev/null")

    for index, command in commands {
        fullCommand := """" . adbPath . """ -s " . deviceAddress . " shell " . command
        result := CmdRet(fullCommand)
        ;LogToFile("DisableService result (" . command . "): " . result, "ADB.txt")
    }
}

CmdRet(sCmd, callBackFuncObj := "", encoding := "") {
    static HANDLE_FLAG_INHERIT := 0x00000001, flags := HANDLE_FLAG_INHERIT
        , STARTF_USESTDHANDLES := 0x100, CREATE_NO_WINDOW := 0x08000000

   (encoding = "" && encoding := "cp" . DllCall("GetOEMCP", "UInt"))
   DllCall("CreatePipe", "PtrP", hPipeRead, "PtrP", hPipeWrite, "Ptr", 0, "UInt", 0)
   DllCall("SetHandleInformation", "Ptr", hPipeWrite, "UInt", flags, "UInt", HANDLE_FLAG_INHERIT)

   VarSetCapacity(STARTUPINFO , siSize :=    A_PtrSize*4 + 4*8 + A_PtrSize*5, 0)
   NumPut(siSize              , STARTUPINFO)
   NumPut(STARTF_USESTDHANDLES, STARTUPINFO, A_PtrSize*4 + 4*7)
   NumPut(hPipeWrite          , STARTUPINFO, A_PtrSize*4 + 4*8 + A_PtrSize*3)
   NumPut(hPipeWrite          , STARTUPINFO, A_PtrSize*4 + 4*8 + A_PtrSize*4)

   VarSetCapacity(PROCESS_INFORMATION, A_PtrSize*2 + 4*2, 0)

   if !DllCall("CreateProcess", "Ptr", 0, "Str", sCmd, "Ptr", 0, "Ptr", 0, "UInt", true, "UInt", CREATE_NO_WINDOW
                              , "Ptr", 0, "Ptr", 0, "Ptr", &STARTUPINFO, "Ptr", &PROCESS_INFORMATION)
   {
      DllCall("CloseHandle", "Ptr", hPipeRead)
      DllCall("CloseHandle", "Ptr", hPipeWrite)
      throw "CreateProcess is failed"
   }
   DllCall("CloseHandle", "Ptr", hPipeWrite)
   VarSetCapacity(sTemp, 4096), nSize := 0
   while DllCall("ReadFile", "Ptr", hPipeRead, "Ptr", &sTemp, "UInt", 4096, "UIntP", nSize, "UInt", 0) {
      sOutput .= stdOut := StrGet(&sTemp, nSize, encoding)
      ( callBackFuncObj && callBackFuncObj.Call(stdOut) )
   }
   DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION))
   DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION, A_PtrSize))
   DllCall("CloseHandle", "Ptr", hPipeRead)
   Return sOutput
}

initializeAdbShell() {
    global adbShell, adbPath, adbPort, Debug
    IniRead, folderPath, %A_ScriptDir%\..\Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
    RetryCount := 1
    MaxRetries := 5
    BackoffTime := 1000  ; Initial backoff time in milliseconds
    MaxBackoff := 5000   ; Prevent excessive waiting

    Loop {
        try {
            if (!adbShell || adbShell.Status != 0) {
                adbShell := ""  ; Reset before reattempting

                ; Validate adbPath and adbPort
                if (!FileExist(adbPath)) {
                    throw Exception("ADB path is invalid: " . adbPath)
                }
                if (adbPort < 0 || adbPort > 65535) {
                    throw Exception("ADB port is invalid: " . adbPort)
                }

                ; Attempt to start adb shell
                adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s 127.0.0.1:" . adbPort . " shell")

                ; Ensure adbShell is running before sending 'su'
                Sleep, 500
                if (adbShell.Status != 0) {
                    adbPort := findAdbPorts(folderPath)
                    disconnectionResult := CmdRet(adbPath . " disconnect 127.0.0.1:" . adbPort)

                    adbPort := findAdbPorts(folderPath)
                    connectionResult := CmdRet(adbPath . " connect 127.0.0.1:" . adbPort)
                    LogToFile("ADB connection failed in initializeAdbShell. Bot is reconnecting to ADB.(" . RetryCount . "/" . MaxRetries . ") Connection result: " . connectionResult, "ADB.txt")

                    RetryCount++
                    if (RetryCount > MaxRetries) {
                        throw Exception("Failed to start ADB shell.")
                    }
                    else
                        continue
                }

                try {
                    adbShell.StdIn.WriteLine("su")
                } catch e2 {
                    RetryCount++
                    if (RetryCount > MaxRetries) {
                        throw Exception("Failed to elevate shell: " . (IsObject(e2) ? e2.Message : e2))
                    }
                }
            }

            ; If adbShell is running, break loop
            if (adbShell.Status = 0) {
                break
            }
        } catch e {
            if(!isADBHang){
                LogToFile("Found hang Instance: " . currentInstanceNo, "ADB.txt")
                sendNotifyADBStatus(10, currentInstanceNo, "ADBManager.ahk")
                isADBHang := true
                break
            }
            else
                isADBHang()
        }

        Sleep, BackoffTime
        BackoffTime := Min(BackoffTime + 1000, MaxBackoff)  ; Limit backoff time
    }
}

isADBHang() {
    global isADBHang, currentInstanceNo
    
    currentRetryTime := 0
    maxRetryTime := 10
    nextFailTime := failTime

    Loop, {
        if(isADBHang) {
            CreateStatusMessage("Waiting for ADB server to recover...",,,, false)
            sendNotifyADBStatus(21, currentInstanceNo, "ADBManager.ahk")

            StartSkipTime := A_TickCount ;reset stuck timers
            failSafe := A_TickCount

            Sleep, 1000
        }
        else
            break

        if(failTime)
        {
            failSafeTime := (A_TickCount - nextFailTime) // 1000

            if(failSafeTime > 120){
                LogToFile("[" . A_ScriptName . "] The time this bot was waiting to be restored has expired. message will be resent. ", "ADB.txt")
                hangInstanceNo := currentInstanceNo
                sendNotifyADBStatus(21, currentInstanceNo, "ADBManager.ahk")
                sendNotifyADBStatus(50, currentInstanceNo, "ADBManager.ahk")
                nextFailTime := A_TickCount
                currentRetryTime += 1
            }

            if(currentRetryTime >= maxRetryTime){
                LogToFile("[" . A_ScriptName . "] Maximum wait time exceeded. Reloading bot.", "ADB.txt")
                Reload
            }
        }
    }
}

adbEnsureShell() {
    global adbShell
    if (!IsObject(adbShell) || adbShell.Status != 0) {
        adbShell := ""
        initializeAdbShell()
    }
    
    isADBHang()
}

adbWriteRaw(command) {
    global adbShell

    retries := 0
    MaxRetries := 3

    Loop {
        adbEnsureShell()
        try {
            adbShell.StdIn.WriteLine(command)
            return true
        } catch e {
            errorMessage := IsObject(e) ? e.Message : e
            retries++
            LogToFile("ADB write error: " . errorMessage, "ADB.txt")
            adbShell := ""
            if (retries >= MaxRetries)
                throw e
            Sleep, 300
        }
    }
}

waitadb() {
    global adbShell

    retries := 0
    MaxRetries := 3

    Loop {
        adbEnsureShell()
        try {
            adbWriteRaw("echo done")
            startTick := A_TickCount
            while (A_TickCount - startTick) < 6000 {
                if (adbShell.Status != 0)
                    throw Exception("ADB shell terminated while waiting.")
                if !adbShell.StdOut.AtEndOfStream {
                    line := adbShell.StdOut.ReadLine()
                    if (line = "done")
                        return
                } else {
                    Sleep, 50
                }
            }
            throw Exception("Timeout while waiting for ADB response.")
        } catch e {
            errorMessage := IsObject(e) ? e.Message : e
            retries++
            LogToFile("waitadb error: " . errorMessage, "ADB.txt")
            adbShell := ""
            if (retries >= MaxRetries)
                throw e
            Sleep, 300
        }
    }
}

adbClick(X, Y) {
    static clickCommands := Object()
    static convX := 540/277, convY := 960/489, offset := -44

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
    isADBHang()

    ; Percroy Optimization
    global winTitle, adbPort, adbPath
    
    static pTokenLocal := 0
    if (!pTokenLocal) {
        pTokenLocal := Gdip_Startup()
    }
    
    hwnd := WinExist(winTitle)
    if (!hwnd) {
        deviceAddress := "127.0.0.1:" . adbPort
        command := """" . adbPath . """ -s " . deviceAddress . " exec-out screencap -p > """ .  outputFile . """"
        RunWait, %ComSpec% /c "%command%", , Hide
        return
    }

    pBitmap := Gdip_BitmapFromHWND(hwnd)

    if (!pBitmap || pBitmap = "") {
        deviceAddress := "127.0.0.1:" . adbPort
        command := """" . adbPath . """ -s " . deviceAddress . " exec-out screencap -p > """ .  outputFile . """"
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
        deviceAddress := "127.0.0.1:" . adbPort
        command := """" . adbPath . """ -s " . deviceAddress . " exec-out screencap -p > """ .  outputFile . """"
        RunWait, %ComSpec% /c "%command%", , Hide
        return
    }
}
