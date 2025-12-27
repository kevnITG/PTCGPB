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
; Dependencies: None (pure utilities)
; Used by: Multiple modules throughout 1.ahk
;===============================================================================

;-------------------------------------------------------------------------------
; Delay - Configurable delay based on global Delay setting
;-------------------------------------------------------------------------------
Delay(n) {
    global Delay
    msTime := Delay * n
    Sleep, msTime
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
        cleanVal := RegExReplace(val, "[^a-zA-Z0-9]") ; Remove non-alphanumeric characters
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
    global beginnerMissionsDone, deleteMethod, injectMethod, loadedAccount, friendIDs, friendID, accountOpenPacks, maxAccountPackNum, verboseLogging

    if (beginnerMissionsDone) {
        return false
    }

    if (deleteMethod = "Create Bots (13P)") {
        return (!friendIDs && friendID = "" && accountOpenPacks < maxAccountPackNum) || (friendIDs || friendID != "")
    }
    else if (deleteMethod = "Inject Missions") {
        IniRead, skipMissions, %A_ScriptDir%\..\Settings.ini, UserSettings, skipMissionsInjectMissions, 0
        if (skipMissions = 1) {
            ; if(verboseLogging)
                ; LogToFile("Skipping missions for Inject Missions method (user setting)")
            return false
        }
        ; if(verboseLogging)
            ; LogToFile("Executing missions for Inject Missions method (user setting enabled)")
        return true
    }
    else if (deleteMethod = "Inject 13P+" || deleteMethod = "Inject Wonderpick 96P+") {
        ; if(verboseLogging)
            ; LogToFile("Skipping missions for " . deleteMethod . " method - missions only run for 'Inject Missions'")
        return false
    }
    else {
        ; For non-injection methods (like regular delete methods)
        return (!friendIDs && friendID = "" && accountOpenPacks < maxAccountPackNum) || (friendIDs || friendID != "")
    }
}

;-------------------------------------------------------------------------------
; isMuMuv5 - Detect if MuMu Player version 5 is being used
;-------------------------------------------------------------------------------
isMuMuv5(){
    global folderPath
    mumuFolder := folderPath . "\MuMuPlayerGlobal-12.0"
    if !FileExist(mumuFolder)
        mumuFolder := folderPath . "\MuMu Player 12"
    if FileExist(mumuFolder . "\nx_main")
        return true
    return false
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
; Find the monitor index with device name 
;-------------------------------------------------------------------------------
GetMonitorIndexFromDeviceName(TargetDeviceName) {
    SysGet, MonitorCount, MonitorCount
    Loop, %MonitorCount% {
        SysGet, ThisName, MonitorName, %A_Index%
        if (ThisName = TargetDeviceName)
            return A_Index
    }
    ; Find the 125% scale monitor
    scale125MonitorName := Find125ScaleMonitor()
    Loop, %MonitorCount% {
        SysGet, ThisName, MonitorName, %A_Index%
        if (ThisName = scale125MonitorName)
            return A_Index
    }
    ; Fallback to monitor 1 if not found
    return 1
}

Find125ScaleMonitor() {
    SysGet, MonitorCount, MonitorCount
    
    Loop %MonitorCount% {
        ; Get unscaled bounds (works best as admin for consistency)
        SysGet, mon, Monitor, %A_Index%
        unscaledWidth := monRight - monLeft
        unscaledHeight := monBottom - monTop
        
        ; Get monitor handle from center point
        cx := monLeft + unscaledWidth // 2
        cy := monTop + unscaledHeight // 2
        point := (cy << 32) | (cx & 0xFFFFFFFF)
        hMon := DllCall("MonitorFromPoint", "Int64", point, "UInt", 2, "Ptr")
        
        ; Get effective DPI
        if (DllCall("Shcore\GetDpiForMonitor", "Ptr", hMon, "Int", 0, "UInt*", dpiX, "UInt*", dpiY) = 0) {
            dpi := dpiX  ; Usually dpiX = dpiY
            scalePercent := Round(dpi / 96 * 100)  ; 96 = base 100%
            
            ; Approximate scaled (logical) resolution
            scaledWidth := Round(unscaledWidth * 96 / dpi)
            scaledHeight := Round(unscaledHeight * 96 / dpi)
            
            ; Get monitor name
            SysGet, name, MonitorName, %A_Index%
            
            if (dpi = 120)
                return name
        }
    }
}