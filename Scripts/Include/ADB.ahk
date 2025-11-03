global adbPort, adbShell, adbPath

KillADBProcesses() {
    ; Use AHK's Process command to close adb.exe
    Process, Close, adb.exe
    ; Fallback to taskkill for robustness
    RunWait, %ComSpec% /c taskkill /IM adb.exe /F /T,, Hide
}

findAdbPorts(baseFolder := "C:\Program Files\Netease") {
    global scriptName

    ; Initialize variables
    mumuFolder = %baseFolder%\MuMuPlayerGlobal-12.0\vms\*
    if !FileExist(mumuFolder)
        mumuFolder = %baseFolder%\MuMu Player 12\vms\*

    if !FileExist(mumuFolder){
        MsgBox, 16, , Can't Find MuMu, try old MuMu installer in Discord #announcements, otherwise double check your folder path setting!`nDefault path is C:\Program Files\Netease
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
    adbPort := findAdbPorts(folderPath)

    adbPath := folderPath . "\MuMuPlayerGlobal-12.0\shell\adb.exe"

    if !FileExist(adbPath) ;if international mumu file path isn't found look for chinese domestic path
        adbPath := folderPath . "\MuMu Player 12\shell\adb.exe"

    if !FileExist(adbPath)
        MsgBox Check folder path! It must contain the MuMuPlayer12 folder! `nDefault is C:\Program Files\Netease

    if(!adbPort) {
        Msgbox, Invalid port... Check the common issues section in the readme/github guide.
        ExitApp
    }

    MaxRetries := 5
    RetryCount := 0
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
    }

    if !connected {
        if (Debug)
            CreateStatusMessage("Failed to connect to ADB after multiple retries. Please check your emulator and port settings.")
        else
            CreateStatusMessage("Failed to connect to ADB.",,,, false)
        Reload
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
    RetryCount := 0
    MaxRetries := 10
    BackoffTime := 1000  ; Initial backoff time in milliseconds
    MaxBackoff := 5000   ; Prevent excessive waiting

    Loop {
        try {
            if (!adbShell || adbShell.Status != 0) {
                adbShell := ""  ; Reset before reattempting

                ; Validate adbPath and adbPort
                if (!FileExist(adbPath)) {
                    throw "ADB path is invalid: " . adbPath
                }
                if (adbPort < 0 || adbPort > 65535) {
                    throw "ADB port is invalid: " . adbPort
                }

                ; Attempt to start adb shell
                adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s 127.0.0.1:" . adbPort . " shell")

                ; Ensure adbShell is running before sending 'su'
                Sleep, 500
                if (adbShell.Status != 0) {
                    throw "Failed to start ADB shell."
                }

                adbShell.StdIn.WriteLine("su")
            }

            ; If adbShell is running, break loop
            if (adbShell.Status = 0) {
                break
            }
        } catch e {
            RetryCount++
            LogToFile("ADB Shell Error: " . e.message, "ADB.txt")

            if (RetryCount >= MaxRetries) {
                if (Debug)
                    CreateStatusMessage("Failed to connect to shell after multiple attempts: " . e.message)
                else
                    CreateStatusMessage("Failed to connect to shell. Pausing.",,,, false)
                Pause
            }
        }

        Sleep, BackoffTime
        BackoffTime := Min(BackoffTime + 1000, MaxBackoff)  ; Limit backoff time
    }
}

waitadb() {
    adbShell.StdIn.WriteLine("echo done")
    while !adbShell.StdOut.AtEndOfStream {
        line := adbShell.StdOut.ReadLine()
        if (line = "done")
            break
        Sleep, 50
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
    adbShell.StdIn.WriteLine(clickCommands[key])
}

adbInput(name) {
    adbShell.StdIn.WriteLine("input text " . name)
    waitadb()
}

adbInputEvent(event) {
    if InStr(event, " ") {
        ; If the event uses a space, we use keycombination
        adbShell.StdIn.WriteLine("input keycombination " . event)
    } else {
        ; It's a single key event (e.g., "67")
        adbShell.StdIn.WriteLine("input keyevent " . event)
    }
    waitadb()
}

; Simulates a swipe gesture on an Android device, swiping from one X/Y-coordinate to another.
adbSwipe(params) {
    adbShell.StdIn.WriteLine("input swipe " . params)
    waitadb()
}

; Simulates a touch gesture on an Android device to scroll in a controlled way.
; Not currently supported.
adbGesture(params) {
    ; Example params (a 2-second hold-drag from a lower to an upper Y-coordinate): 0 2000 138 380 138 90 138 90
    adbShell.StdIn.WriteLine("input touchscreen gesture " . params)
    waitadb()
}

; Takes a screenshot of an Android device using ADB and saves it to a file.
adbTakeScreenshot(outputFile) {
    ; ------------------------------------------------------------------------------
    ; Parameters:
    ;   outputFile (String) - The path and filename where the screenshot will be saved.
    ; ------------------------------------------------------------------------------
    deviceAddress := "127.0.0.1:" . adbPort
    command := """" . adbPath . """ -s " . deviceAddress . " exec-out screencap -p > """ .  outputFile . """"
    RunWait, %ComSpec% /c "%command%", , Hide
}
