#Persistent
#SingleInstance Force
#NoTrayIcon
DetectHiddenWindows, On ; Important to find hidden windows later if needed

; Allocate and hide the console window
DllCall("AllocConsole")
WinHide % "ahk_id " DllCall("GetConsoleWindow", "ptr")

; global variables
global scriptName, adbPort, adbPath, adbSerial, managerWindowTitle
global adbShell := "" ; Make it global so OnMessage handler can access it

; --- Configuration ---
scriptName := StrReplace(A_ScriptName, ".adbmanager.ahk")
folderPath := "C:\Program Files\Netease"
adbPort := findAdbPorts(folderPath)
adbSerial := "127.0.0.1:" . adbPort
managerWindowTitle := scriptName . "adbmanager" ; Unique title for finding this script for command sending

; --- Create a visible window for the manager ---
Gui, New
Gui, Show, w10 h10, %managerWindowTitle%
Gui, Hide

; --- Set ADB path
adbPath := folderPath . "\MuMuPlayerGlobal-12.0\shell\adb.exe"

if !FileExist(adbPath)
    MsgBox Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease

if(!adbPort) {
    Msgbox, Invalid port... Check the common issues section in the readme/github guide.
    ExitApp
}

; --- Initialize ADB shell ---
ConnectAdbFirst(adbPath, adbSerial)
Try
{
    adbShell := ComObjCreate("WScript.Shell").Exec(adbPath . " -s " . adbSerial . " shell")


    adbShell.StdIn.WriteLine("su")
    
}
Catch e
{
    GuiControl,, StatusText, Failed to start ADB shell:`n%e%
    MsgBox, 16, ADB Manager Error, Failed to start ADB shell:`n%e%`nPlease check ADB path, serial, and if ADB server is running.
    ExitApp
}

; --- Listen for Commands ---
; WM_COPYDATA = 0x4A
OnMessage(0x4A, "ReceiveCommand")

Return ; End of auto-execute section

ReceiveCommand(wParam, lParam) {
    global adbShell
    If (!IsObject(adbShell) || adbShell = "") {
        GuiControl,, StatusText, Error: ADB shell object is not valid
        OutputDebug, ADB Manager: Received command but ADB shell object is not valid.
        Return 0
    }

    ; Get the data from COPYDATASTRUCT
    dataSize := NumGet(lParam + A_PtrSize, 0, "UInt")
    dataPtr := NumGet(lParam + 2*A_PtrSize, 0, "Ptr")

    If (dataPtr = 0 || dataSize = 0) {
        GuiControl,, StatusText, Error: Invalid data pointer or size
        Return 0
    }

    ; Create buffer and copy data
    VarSetCapacity(receivedCommand, dataSize, 0)
    DllCall("Kernel32\RtlMoveMemory", "Ptr", &receivedCommand, "Ptr", dataPtr, "Ptr", dataSize)
    fullCommand := StrGet(&receivedCommand, dataSize, "CP0")

    Try
    {
        adbShell.StdIn.WriteLine(fullCommand)
    }
    Catch e
    {
        OutputDebug, ADB Manager: Error writing command '%fullCommand%' to ADB shell: %e%
        Return 0
    }

    Return 1
}

findAdbPorts(baseFolder := "C:\Program Files\Netease") {
	global scriptName
	
    mumuFolder = %baseFolder%\MuMuPlayerGlobal-12.0\vms\*
    if !FileExist(mumuFolder){
        mumuFolder = %baseFolder%\MuMu Player 12\vms\*
    }

	if !FileExist(mumuFolder){
		MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
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

CmdRet(sCmd, callBackFuncObj := "", encoding := "")
{
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

ConnectAdbFirst(adbPath, adbSerial) {
    MaxRetries := 3
    RetryCount := 0
    connected := false

	Loop %MaxRetries% {
		; Attempt to connect using CmdRet
		connectionResult := CmdRet(adbPath . " connect " . adbSerial)

		; Check for successful connection in the output
		if InStr(connectionResult, "connected to " . ip) {
			connected := true
			return true
		} else {
			RetryCount++
			Sleep, 1000
		}
	}

	if !connected {
		Reload
	}
}