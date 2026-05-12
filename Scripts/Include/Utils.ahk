;===============================================================================
; Utils.ahk - Utility Functions
;===============================================================================
; This file contains general-purpose utility functions used throughout the bot.
; These functions handle:
;   - Delays and timing
;   - File operations (read, download)
;   - Date/time calculations
;   - Array sorting and comparison
;   - Settings migration
;   - Mission checking logic
;   - MuMu version detection
;
; Dependencies: None for core helpers. Do not call LogToFile here ? use AppendGPlog for GPlog.txt
;   (Utils is #included by LaunchAllMumu.ahk without Logging.ahk).
; Used by: Multiple modules throughout 1.ahk
;===============================================================================

;-------------------------------------------------------------------------------
; Delay - Configurable delay based on global Delay setting
;-------------------------------------------------------------------------------
Delay(n) {
    global botConfig
    msTime := botConfig.get("Delay") * n
    Sleep, msTime
}

DelayH(ms) {
    StartTime := A_TickCount
    
    while (A_TickCount - StartTime < ms) {
        Sleep, 10
    }
}
;-------------------------------------------------------------------------------
; MonthToDays - Convert month number to days elapsed in year
;-------------------------------------------------------------------------------
MonthToDays(year, month) {
    static DaysInMonths := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    days := 0
    Loop, % month - 1 {
        days += DaysInMonths[A_Index]
    }
    if (month > 2 && IsLeapYear(year))
        days += 1
    return days
}

;-------------------------------------------------------------------------------
; IsLeapYear - Check if a year is a leap year
;-------------------------------------------------------------------------------
IsLeapYear(year) {
    return (Mod(year, 4) = 0 && Mod(year, 100) != 0) || Mod(year, 400) = 0
}

;-------------------------------------------------------------------------------
; DownloadFile - Download file from URL to local path
;-------------------------------------------------------------------------------
DownloadFile(url, filename) {
    url := url  ; Change to your hosted .txt URL "https://pastebin.com/raw/vYxsiqSs"
    RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
	RegRead, proxyServer, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyServer
    localPath = %A_ScriptDir%\..\%filename% ; Change to the folder you want to save the file
    errored := false
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        if (proxyEnabled)
			whr.SetProxy(2, proxyServer)
        whr.Open("GET", url, true)
        whr.Send()
        whr.WaitForResponse()
        ids := whr.ResponseText
    } catch {
        errored := true
    }
    if(!errored) {
        FileDelete, %localPath%
        FileAppend, %ids%, %localPath%
        return true
    }
    return !errored
}

;-------------------------------------------------------------------------------
; ReadFile - Read text file and return cleaned array of values
;-------------------------------------------------------------------------------
ReadFile(filename, numbers := false) {
    FileRead, content, %A_ScriptDir%\..\%filename%.txt

    if (!content)
        return false

    values := []
    for _, val in StrSplit(Trim(content), "`n") {
        cleanVal := RegExReplace(val, "[^a-zA-Z0-9_]") ; Remove non-alphanumeric characters
        if (cleanVal != "")
            values.Push(cleanVal)
    }

    return values.MaxIndex() ? values : false
}

;-------------------------------------------------------------------------------
; MigrateDeleteMethod - Migrate old delete method names to new format
;-------------------------------------------------------------------------------
MigrateDeleteMethod(oldMethod) {
    if (oldMethod = "13 Pack") {
        return "Create Bots (13P)"
    } else if (oldMethod = "Inject") {
        return "Inject 13P+"
    } else if (oldMethod = "Inject for Reroll") {
        return "Inject Wonderpick 96P+"
    } else if (oldMethod = "Inject Missions") {
        return "Inject 13P+"
    }
    return oldMethod
}

;-------------------------------------------------------------------------------
; getChangeDateTime - Calculate the server reset time in local timezone
;-------------------------------------------------------------------------------
getChangeDateTime() {
	offset := A_Now
	currenttimeutc := A_NowUTC
	EnvSub, offset, %currenttimeutc%, Hours   ;offset from local timezone to UTC

    resetTime := SubStr(A_Now, 1, 8) "060000" ;today at 6am [utc] zero seconds is the reset time at UTC
	resetTime += offset, Hours                ;reset time in local timezone

	;find the closest reset time
	currentTime := A_Now
	timeToReset := resetTime
	EnvSub, timeToReset, %currentTime%, Hours
	if(timeToReset > 12) {
		resetTime += -1, Days
	} else if (timeToReset < -12) {
		resetTime += 1, Days
	}

    return resetTime
}

;-------------------------------------------------------------------------------
; checkShouldDoMissions - Determine if missions should be executed
;-------------------------------------------------------------------------------
checkShouldDoMissions() {
    global botConfig, session

    if (session.get("missionDoneList")["beginnerMissionsDone"]) {
        return false
    }

    if (botConfig.get("deleteMethod") = "Create Bots (13P)") {
        return (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") < session.get("maxAccountPackNum")) || (session.get("friendIDs") || botConfig.get("FriendID") != "")
    }
    else if (botConfig.get("deleteMethod") = "Inject Missions") {
        return true
    }
    else if (botConfig.get("deleteMethod") = "Inject 13P+" || botConfig.get("deleteMethod") = "Inject Wonderpick 96P+") {
        ; if(verboseLogging)
            ; LogToFile("Skipping missions for " . deleteMethod . " method - missions only run for 'Inject Missions'")
        return false
    }
    else {
        ; For non-injection methods (like regular delete methods)
        return (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") < session.get("maxAccountPackNum")) || (session.get("friendIDs") || botConfig.get("FriendID") != "")
    }
}

;===============================================================================
; Array Sorting Functions
;===============================================================================

;-------------------------------------------------------------------------------
; SortArraysByProperty - Sort multiple parallel arrays by a property
;-------------------------------------------------------------------------------
SortArraysByProperty(fileNames, fileTimes, packCounts, property, ascending) {
    n := fileNames.MaxIndex()

    ; Create an array of indices for sorting
    indices := []
    Loop, %n% {
        indices.Push(A_Index)
    }

    ; Sort the indices based on the specified property
    if (property == "time") {
        if (ascending) {
            ; Sort by time ascending
            Sort(indices, Func("CompareIndicesByTimeAsc").Bind(fileTimes))
        } else {
            ; Sort by time descending
            Sort(indices, Func("CompareIndicesByTimeDesc").Bind(fileTimes))
        }
    } else if (property == "packs") {
        if (ascending) {
            ; Sort by pack count ascending
            Sort(indices, Func("CompareIndicesByPacksAsc").Bind(packCounts))
        } else {
            ; Sort by pack count descending
            Sort(indices, Func("CompareIndicesByPacksDesc").Bind(packCounts))
        }
    }

    ; Create temporary arrays for sorted values
    sortedFileNames := []
    sortedFileTimes := []
    sortedPackCounts := []

    ; Populate sorted arrays based on sorted indices
    Loop, %n% {
        idx := indices[A_Index]
        sortedFileNames.Push(fileNames[idx])
        sortedFileTimes.Push(fileTimes[idx])
        sortedPackCounts.Push(packCounts[idx])
    }

    ; Copy sorted values back to original arrays
    Loop, %n% {
        fileNames[A_Index] := sortedFileNames[A_Index]
        fileTimes[A_Index] := sortedFileTimes[A_Index]
        packCounts[A_Index] := sortedPackCounts[A_Index]
    }
}

;-------------------------------------------------------------------------------
; Sort - Helper function to sort an array using a custom comparison function
;-------------------------------------------------------------------------------
Sort(array, compareFunc) {
    QuickSort(array, 1, array.MaxIndex(), compareFunc)
    return array
}

;-------------------------------------------------------------------------------
; QuickSort - Iterative quicksort implementation
;-------------------------------------------------------------------------------
QuickSort(array, left, right, compareFunc) {
    ; Create a manual stack to avoid deep recursion
    stack := []
    stack.Push([left, right])

    ; Process all partitions iteratively
    while (stack.Length() > 0) {
        current := stack.Pop()
        currentLeft := current[1]
        currentRight := current[2]

        if (currentLeft < currentRight) {
            ; Use middle element as pivot
            pivotIndex := Floor((currentLeft + currentRight) / 2)
            pivotValue := array[pivotIndex]

            ; Move pivot to end
            temp := array[pivotIndex]
            array[pivotIndex] := array[currentRight]
            array[currentRight] := temp

            ; Move all elements smaller than pivot to the left
            storeIndex := currentLeft
            i := currentLeft
            while (i < currentRight) {
                if (compareFunc.Call(array[i], array[currentRight]) < 0) {
                    ; Swap elements
                    temp := array[i]
                    array[i] := array[storeIndex]
                    array[storeIndex] := temp
                    storeIndex++
                }
                i++
            }

            ; Move pivot to its final place
            temp := array[storeIndex]
            array[storeIndex] := array[currentRight]
            array[currentRight] := temp

            ; Push the larger partition first (optimization)
            if (storeIndex - currentLeft < currentRight - storeIndex) {
                stack.Push([storeIndex + 1, currentRight])
                stack.Push([currentLeft, storeIndex - 1])
            } else {
                stack.Push([currentLeft, storeIndex - 1])
                stack.Push([storeIndex + 1, currentRight])
            }
        }
    }
}

;===============================================================================
; Comparison Functions for Sorting
;===============================================================================

CompareIndicesByTimeAsc(times, a, b) {
    timeA := times[a]
    timeB := times[b]
    return timeA < timeB ? -1 : (timeA > timeB ? 1 : 0)
}

CompareIndicesByTimeDesc(times, a, b) {
    timeA := times[a]
    timeB := times[b]
    return timeB < timeA ? -1 : (timeB > timeA ? 1 : 0)
}

CompareIndicesByPacksAsc(packs, a, b) {
    packsA := packs[a]
    packsB := packs[b]
    return packsA < packsB ? -1 : (packsA > packsB ? 1 : 0)
}

CompareIndicesByPacksDesc(packs, a, b) {
    packsA := packs[a]
    packsB := packs[b]
    return packsB < packsA ? -1 : (packsB > packsA ? 1 : 0)
}

;-------------------------------------------------------------------------------
; SafeReload - Restart the script without race conditions
;-------------------------------------------------------------------------------
; Launches a new instance then immediately kills the current process.
; Unlike Reload (which keeps the old process alive and relies on the NEW
; instance to close it via WM_CLOSE), this has the OLD process kill itself.
; ExitApp terminates in microseconds; the new AHK process takes hundreds of
; milliseconds to load and reach #SingleInstance - so the old process is
; long dead before any conflict can occur.
SafeReload() {
    ;Run, "%A_AhkPath%" "%A_ScriptFullPath%"
    ;ExitApp
    Reload
}

;-------------------------------------------------------------------------------
; getMumuInstanceNum - Get MuMu instance number from player name
;-------------------------------------------------------------------------------
getMumuInstanceNum(scriptName, mumuFolder) {
    if (scriptName == "") {
        return ""
    }

    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"

        IfExist, %configFolder%
        {
            extraConfigFile := configFolder "\extra_config.json"

            IfExist, %extraConfigFile%
            {
                FileRead, extraConfigContent, %extraConfigFile%
                RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                if (playerName1 == scriptName) {
                    RegExMatch(A_LoopFileFullPath, "[^-]+$", mumuNum)
                    return mumuNum
                }
            }
        }
    }
    return ""
}

;-------------------------------------------------------------------------------
; Run_ - Run as non-administrator (required for MuMu)
;-------------------------------------------------------------------------------
Run_(target, args:="", workdir:="") {
    try
        ShellRun(target, args, workdir)
    catch e
        Run % args="" ? target : target " " args, % workdir
}

;-------------------------------------------------------------------------------
; ShellRun - Shell execution helper for running as non-admin
; By Lexikos - http://creativecommons.org/publicdomain/zero/1.0/
;-------------------------------------------------------------------------------
ShellRun(prms*) {
    shellWindows := ComObjCreate("Shell.Application").Windows
    VarSetCapacity(_hwnd, 4, 0)
    desktop := shellWindows.FindWindowSW(0, "", 8, ComObj(0x4003, &_hwnd), 1)

    if ptlb := ComObjQuery(desktop
        , "{4C96BE40-915C-11CF-99D3-00AA004AE837}"
        , "{000214E2-0000-0000-C000-000000000046}") {
        if DllCall(NumGet(NumGet(ptlb+0)+15*A_PtrSize), "ptr", ptlb, "ptr*", psv:=0) = 0 {
            VarSetCapacity(IID_IDispatch, 16)
            NumPut(0x46000000000000C0, NumPut(0x20400, IID_IDispatch, "int64"), "int64")

            DllCall(NumGet(NumGet(psv+0)+15*A_PtrSize), "ptr", psv
                , "uint", 0, "ptr", &IID_IDispatch, "ptr*", pdisp:=0)

            shell := ComObj(9,pdisp,1).Application
            shell.ShellExecute(prms*)

            ObjRelease(psv)
        }
        ObjRelease(ptlb)
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

writeLastEndEpoch(scriptName) {
    if(InStr(scriptName, "Main"))
        return

    scriptName := StrReplace(scriptName, ".ahk")

    now := A_NowUTC
    EnvSub, now, 1970, seconds
    IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastEndEpoch
}

SerializeArray(arr) {
    str := ""
    for index, value in arr {
        str .= index . ":" . value . ", "
    }
    return RTrim(str, ",")
}

restartInstance(){
    global session

    killInstance(session.get("scriptName"))
    Sleep, 2000
    launchInstance(session.get("scriptName"))
    Sleep, 5000
}

GetVRAMByScriptName(scriptName) {
    mumuFolder := getMuMuFolder()

    mumuInstanceNo := getMumuInstanceNum(scriptName, mumuFolder)
    TargetProcessName := "MuMuVMMHeadless.exe"
    TargetFolder := "MuMuPlayerGlobal-12.0-" . mumuInstanceNo . " -"

    objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    TargetPID := 0
    processQuery := "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = '" TargetProcessName "'"
    colProcesses := objWMIService.ExecQuery(processQuery)

    for objProcess in colProcesses {
        if InStr(objProcess.CommandLine, TargetFolder) {
            TargetPID := objProcess.ProcessId
            break 
        }
    }

    VRAM_Result := GetGPUProcessMemory(TargetPID)

    if (VRAM_Result != "")
        return VRAM_Result
    else
        return 0
}

killInstance(instanceNum := "")
{
    killed := 0
    
    pID := checkInstance(instanceNum)
    if pID {
        Process, Close, %pID%
        killed := killed + 1
    }
    
    return killed
}

checkInstance(instanceNum := "")
{
    ret := WinExist(instanceNum . " ahk_class Qt5156QWindowIcon")
    if(ret)
    {
        WinGet, temp_pid, PID, ahk_id %ret%
        return temp_pid
    }
    
    return ""
}

launchInstance(instanceNum := "")
{
    mumuFolder := getMuMuFolder()
    
    if(instanceNum != "") {
        mumuNum := getMumuInstanceNum(instanceNum, mumuFolder)
        if(mumuNum != "") {
            mumuExe := mumuFolder . "\shell\MuMuPlayer.exe"
            if !FileExist(mumuExe)
                mumuExe := mumuFolder . "\nx_main\MuMuNxMain.exe"
            Run_(mumuExe, "-v " . mumuNum)
        }
    }
}

getScriptBaseFolder(){
    SplitPath, A_LineFile,, currentDir
    SplitPath, currentDir,, parentDir
    SplitPath, parentDir,, grandParentDir

    return grandParentDir
}

getMuMuFolderInConfig(){
    jsonPath := A_AppData . "\Netease\MuMuPlayerGlobal\install_config.json"

    if (!FileExist(jsonPath)) {
        return -1
    }

    FileRead, jsonText, %jsonPath%

    if (RegExMatch(jsonText, "U)""install_dir""\s*:\s*""(.*)""", match)) {
        rawPath := match1
        fullPath := StrReplace(rawPath, "\\", "\")
        
        ;SplitPath, fullPath,, parentDir
        
        if (InStr(FileExist(fullPath), "D")) {
            return fullPath
        } else {
            return -2
        }
    } else {
        return -3
    }
}
getMuMuFolder(){
    global botConfig
    static subFolderList

    mumuFolder := getMuMuFolderInConfig()

    if(!IsNumeric(mumuFolder))
        return mumuFolder
    
    baseFolder := botConfig.get("folderPath")
    subFolderList := ["MuMuPlayerGlobal-12.0", "MuMu Player 12", "MuMuPlayer-12.0", "MuMuPlayer", "MuMuPlayer-12", "MuMuPlayer12"]

    For idx, value in subFolderList {
        mumuFolder = %baseFolder%\%value%
        if InStr(FileExist(mumuFolder), "D")
            return mumuFolder
    }
    
    MsgBox, 16, , Can't Find MuMu, try old MuMu installer in Discord #announcements, otherwise double check your folder path setting!`nDefault path is C:\Program Files\Netease
    return
}

GetGPUMemoryByWMI(pid){
    ; First try WMI GPU perf counters (more stable across systems than PDH wildcard reads).
    try {
        objPerfWMI := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
        perfQuery := "SELECT LocalUsage FROM Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory WHERE Name LIKE 'pid_" . pid . "%'"
        colPerf := objPerfWMI.ExecQuery(perfQuery)
        totalLocalUsage := 0
        sampleCount := 0
        for perfItem in colPerf {
            value := perfItem.LocalUsage + 0
            totalLocalUsage += value
            sampleCount++
        }
        if (sampleCount > 0 && totalLocalUsage > 0)
            return totalLocalUsage
    }
}

GetGPUMemoryByPDH(pid, bClose := false){
    static isExit := false
    static hModule := 0, hQuery := 0, hCounter := 0, currentPID := 0
    static PDH_FMT_LARGE := 0x400

    if(isExit)
        return 0.00

    if (bClose) {
        if (hQuery)
            DllCall("pdh\PdhCloseQuery", "Ptr", hQuery)
        if (hModule)
            DllCall("FreeLibrary", "Ptr", hModule)
        
        hModule := 0, hQuery := 0, hCounter := 0, currentPID := 0
        isExit := true
        return 0.00
    }

    if (!hQuery || currentPID != pid) {
        if (hQuery)
            DllCall("pdh\PdhCloseQuery", "Ptr", hQuery)

        if (!hModule)
            hModule := DllCall("LoadLibrary", "Str", "pdh.dll", "Ptr")

        DllCall("pdh\PdhOpenQuery", "Ptr", 0, "Ptr", 0, "Ptr*", hQuery)
        counterPath := "\GPU Process Memory(pid_" . pid . "_*)\Local Usage"
        DllCall("pdh\PdhAddEnglishCounterW", "Ptr", hQuery, "WStr", counterPath, "Ptr", 0, "Ptr*", hCounter)

        currentPID := pid
    }

    DllCall("pdh\PdhCollectQueryData", "Ptr", hQuery)

    bufferSize := 0
    itemCount := 0

    DllCall("pdh\PdhGetFormattedCounterArrayW", "Ptr", hCounter, "UInt", PDH_FMT_LARGE, "UInt*", bufferSize, "UInt*", itemCount, "Ptr", 0)

    totalBytes := 0

    if (bufferSize > 0) {
        VarSetCapacity(itemBuffer, bufferSize, 0)
        status := DllCall("pdh\PdhGetFormattedCounterArrayW", "Ptr", hCounter, "UInt", PDH_FMT_LARGE, "UInt*", bufferSize, "UInt*", itemCount, "Ptr", &itemBuffer)
        
        if (status == 0) {
            offset := 0
            is64bit := (A_PtrSize == 8)
            itemSize := is64bit ? 24 : 16       
            valueOffset := is64bit ? 16 : 8     
            
            Loop, %itemCount% {
                val := NumGet(itemBuffer, offset + valueOffset, "Int64")
                totalBytes += val
                offset += itemSize
            }
        }
    }

    return totalBytes
}

GetGPUProcessMemory(pid) {
    mode := "PDH"

    gpuMemValue := GetGPUMemoryByPDH(pid)
    if(gpuMemValue = 0){
        mode := "WMI"
        gpuMemValue := GetGPUMemoryByWMI(pid)
    }

    if(gpuMemValue = 0)
        return {"Usage":0.00, "Mode":mode}
    else
        return {"Usage":Round(gpuMemValue / 1024 / 1024 / 1024, 2), "Mode":mode}
}

getScreenHandle(ParentTitle){
    WinGet, ControlList, ControlList, %ParentTitle%
    Loop, Parse, ControlList, `n
    {
        ControlGet, hCtrl, Hwnd,, %A_LoopField%, %ParentTitle%
        if (A_LoopField = "nemuwin1") {
            return hCtrl
        }
    }
}

FixInstanceScreen(instanceNo){
    instanceTitle := instanceNo . " ahk_class Qt5156QWindowIcon"
    SendMessage, 0x0005, 1, 0,, %instanceTitle%
    Sleep, 50
    SendMessage, 0x0005, 0, 0,, %instanceTitle%
    Sleep, 500
    WinMove, %instanceTitle%, , , , 283, 532
}

getMuMuHwnd(winTitle) {
    static cachedHwnd := 0
    
    if (cachedHwnd && WinExist("ahk_id " . cachedHwnd)) {
        return cachedHwnd
    }
    
    cachedHwnd := WinExist(winTitle . " ahk_class Qt5156QWindowIcon")
    return cachedHwnd
}

FormatMsToAgo(ms) {
    totalSec := ms // 1000
    if (totalSec < 1) return "Just now"
    
    m := totalSec // 60
    s := Mod(totalSec, 60)
    
    result := ""
    if (m > 0)
        result .= m "m "
    result .= s "s ago"
    
    return result
}

updateTotalTime(){
    global session

    totalSeconds := Round((A_TickCount - session.get("rerollStartTime")) / 1000) ; Total time in seconds

    session.set("hhours", Floor(totalSeconds / 3600)) ; Total Seconds
    session.set("mminutes", Floor(Mod(totalSeconds, 3600) / 60)) ; Total minutes
    session.set("sseconds", Mod(totalSeconds, 60)) ; Total remaining seconds
}

;-------------------------------------------------------------------------------
; AppendGPlog ? log under repo Logs\ (same folder as LogToFile in Logging.ahk).
; Utils.ahk is #included by scripts that do not load Logging.ahk (e.g. LaunchAllMumu),
; so we must not call LogToFile() here.
;-------------------------------------------------------------------------------
AppendGPlog(message) {
    utilDir := RegExReplace(A_LineFile, "\\[^\\]+$")
    logPath := utilDir . "\..\..\Logs\GPlog.txt"
    SplitPath, logPath,, logDir
    if !FileExist(logDir)
        FileCreateDir, %logDir%
    FormatTime, readableTime, %A_Now%, MMMM dd, yyyy HH:mm:ss
    Loop, {
        FileAppend, % "[" readableTime "] " message "`n", %logPath%
        if !ErrorLevel
            break
        Sleep, 10
    }
}

;-------------------------------------------------------------------------------
; AppendFriendCodeToManualVipIds - Solo reroll: persist GP account for Main GP Test
; Same format as manual_vip_ids.txt (see GetFriendAccountsFromFile in Main.ahk).
;-------------------------------------------------------------------------------
AppendFriendCodeToManualVipIds(friendCodeRaw) {
    if (friendCodeRaw = "" || friendCodeRaw = "Unknown")
        return
    clean := RegExReplace(friendCodeRaw, "\D", "")
    if (!RegExMatch(clean, "^\d{14,17}$")) {
        AppendGPlog("AppendFriendCodeToManualVipIds: skip invalid code: " . friendCodeRaw)
        return
    }
    manualPath := A_ScriptDir . "\..\manual_vip_ids.txt"
    if FileExist(manualPath) {
        FileRead, existing, %manualPath%
        Loop, Parse, existing, `n, `r
        {
            line := Trim(A_LoopField)
            if (line = "")
                continue
            if InStr(line, " | ") {
                parts := StrSplit(line, " | ")
                lineDigits := RegExReplace(Trim(parts[1]), "\D", "")
            } else {
                lineDigits := RegExReplace(line, "\D", "")
            }
            if (lineDigits = clean)
                return
        }
    }
    FileAppend, %clean%`n, %manualPath%
    AppendGPlog("Solo reroll: appended to manual_vip_ids.txt: " . clean)
}

HasVal(haystack, needle) {
    if !(IsObject(haystack)) || (haystack.Length() = 0)
        return 0
    for index, value in haystack
        if (value = needle)
            return index
    return 0
}

from_window(ByRef image) {
    ; Thanks tic - https://www.autohotkey.com/boards/viewtopic.php?t=6517

    ; Get the handle to the window.
    image := (hwnd := WinExist(image)) ? hwnd : image

    ; Restore the window if minimized! Must be visible for capture.
    if DllCall("IsIconic", "ptr", image)
        DllCall("ShowWindow", "ptr", image, "int", 4)

    ; Get the width and height of the client window.
    VarSetCapacity(Rect, 16) ; sizeof(RECT) = 16
    DllCall("GetClientRect", "ptr", image, "ptr", &Rect)
        , width  := NumGet(Rect, 8, "int")
        , height := NumGet(Rect, 12, "int")

    ; struct BITMAPINFOHEADER - https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
    hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    VarSetCapacity(bi, 40, 0)                ; sizeof(bi) = 40
        , NumPut(       40, bi,  0,   "uint") ; Size
        , NumPut(    width, bi,  4,   "uint") ; Width
        , NumPut(  -height, bi,  8,    "int") ; Height - Negative so (0, 0) is top-left.
        , NumPut(        1, bi, 12, "ushort") ; Planes
        , NumPut(       32, bi, 14, "ushort") ; BitCount / BitsPerPixel
        , NumPut(        0, bi, 16,   "uint") ; Compression = BI_RGB
        , NumPut(        3, bi, 20,   "uint") ; Quality setting (3 = low quality, no anti-aliasing)
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", &bi, "uint", 0, "ptr*", pBits:=0, "ptr", 0, "uint", 0, "ptr")
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

    ; Print the window onto the hBitmap using an undocumented flag. https://stackoverflow.com/a/40042587
    DllCall("PrintWindow", "ptr", image, "ptr", hdc, "uint", 0x3) ; PW_CLIENTONLY | PW_RENDERFULLCONTENT
    ; Additional info on how this is implemented: https://www.reddit.com/r/windows/comments/8ffr56/altprintscreen/

    ; Convert the hBitmap to a Bitmap using a built in function as there is no transparency.
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", pBitmap:=0)

    ; Cleanup the hBitmap and device contexts.
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC",     "ptr", hdc)

    return pBitmap
}
         
isSevtFileExist(){
    TargetPath := getScriptBaseFolder() . "\SpecialEvents\Events"

    FileCount := 0
    Loop, Files, %TargetPath%\*.sevt, F
    {
        FileCount++
    }
    
    return FileCount
}

getKeyList(obj, type := "LIST"){
    keyList := []
    if(type = "STRING")
        keyList := ""

    For k, v in obj {
        if(type = "LIST")
            keyList.Push(k)
        else if(type = "STRING")
            keyList .= k . ", "
    }

    return keyList
}

IsNumeric(var) {
    if var is number
        return true
    return false
}

HttpGet(url) {
    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", url, false)
    http.Send()
    return http.ResponseText
}

ExtractJSONValue(json, key1, key2:="", ext:="") {
    ; Extract JSON string value using regex (handles commas and braces within values)
    needle := """" . key1 . """\s*:\s*""((?:[^""\\]|\\.)*)"""
    if (RegExMatch(json, needle, match))
        return match1
    ; Fallback for non-string values (numbers, booleans)
    needle := """" . key1 . """\s*:\s*([^,}\s]+)"
    if (RegExMatch(json, needle, match))
        return Trim(match1)
    return ""
}

KillAllScripts() {
    Process, Exist, Monitor.ahk
    if (ErrorLevel)
        Process, Close, %ErrorLevel%
    
    Loop, 50 {
        scriptName := A_Index . ".ahk"
        Process, Exist, %scriptName%
        if (ErrorLevel)
            Process, Close, %ErrorLevel%
        
        if (A_Index = 1) {
            Process, Exist, Main.ahk
            if (ErrorLevel)
                Process, Close, %ErrorLevel%

        } else {
            mainScript := "Main" . A_Index . ".ahk"
            Process, Exist, %mainScript%
            if (ErrorLevel)
                Process, Close, %ErrorLevel%
        }
    }
    
    Gui, PackStatusGUI:Destroy

    Return
}

VersionCompare(v1, v2) {
    cleanV1 := RegExReplace(v1, "[^\d.]")
    cleanV2 := RegExReplace(v2, "[^\d.]")
    
    v1Parts := StrSplit(cleanV1, ".")
    v2Parts := StrSplit(cleanV2, ".")
    
    Loop, % Max(v1Parts.MaxIndex(), v2Parts.MaxIndex()) {
        p1 := v1Parts[A_Index]
        p2 := v2Parts[A_Index]
        num1 := (p1 = "" ? 0 : p1 + 0)
        num2 := (p2 = "" ? 0 : p2 + 0)
        if (num1 > num2)
            return 1
        if (num1 < num2)
            return -1
    }
    
    isV1Alpha := InStr(v1, "alpha") || InStr(v1, "beta")
    isV2Alpha := InStr(v2, "alpha") || InStr(v2, "beta")
    
    if (isV1Alpha && !isV2Alpha)
        return -1
    if (!isV1Alpha && isV2Alpha)
        return 1
    
    return 0
}

ShowCustomToolTip(text, x, y) {
    static hToolTipText := 0 

    Gui, ShowSwipeDesc:+AlwaysOnTop -Caption +ToolWindow +Border    
    Gui, ShowSwipeDesc:Color, FFFFAA
    Gui, ShowSwipeDesc:Font, s12 cBlack, Malgun Gothic
    
    GuiControlGet, isExist, ShowSwipeDesc:Pos, ToolTipText
    if (isExist) {
        GuiControl, ShowSwipeDesc:, ToolTipText, %text%
    } else {
        Gui, ShowSwipeDesc:Add, Text, HwndhToolTipText, %text%
    }
    
    Gui, ShowSwipeDesc:Show, x%x% y%y% NoActivate
}

HideCustomToolTip() {
    Gui, ShowSwipeDesc:Destroy
}

generateStatusText(){
    global session

    viewStr := "Total time: "
    viewStr .= session.get("hhours") . "h "
    viewStr .= session.get("mminutes") . "m "
    viewStr .= session.get("sseconds") . "s | "
    viewStr .= "Avg: " . session.get("aminutes") . "m "
    viewStr .= session.get("aseconds") . "s`n"
    viewStr .= "Runs: " . session.get("rerolls") . " | "
    viewStr .= "Packs: " . session.get("accountOpenPacks") . " | "
    viewStr .= "VRAM(" . session.get("VRAMUsage").Mode . "): " . session.get("VRAMUsage").Usage . " GB"

    return viewStr
}

findAdbPath(targetDir) {
    rootPath := targetDir . "\adb.exe"
    if (FileExist(rootPath)) {
        return rootPath
    }

    Loop, Files, %targetDir%\*, D
    {
        checkPath := A_LoopFileFullPath . "\adb.exe"
        
        if (FileExist(checkPath)) {
            return checkPath
        }
    }
    
    return ""
}

GetAllMonitorScales() {
    scales := {}
    
    SysGet, monitorCount, MonitorCount
    
    Loop, %monitorCount% {
        SysGet, Mon, Monitor, %A_Index%
        
        VarSetCapacity(RECT, 16, 0)
        NumPut(MonLeft,   RECT, 0,  "Int")
        NumPut(MonTop,    RECT, 4,  "Int")
        NumPut(MonRight,  RECT, 8,  "Int")
        NumPut(MonBottom, RECT, 12, "Int")
        
        hMon := DllCall("User32\MonitorFromRect", "Ptr", &RECT, "UInt", 2, "Ptr")
        hr := DllCall("Shcore\GetDpiForMonitor", "Ptr", hMon, "Int", 0, "UIntP", dpiX, "UIntP", dpiY)
        
        if (hr == 0) {
            scalePercent := Round((dpiX / 96) * 100)
            scales[A_Index] := scalePercent
        }
    }
    
    return scales
}