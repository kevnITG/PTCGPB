#SingleInstance Force
#NoEnv

; Define custom log file for ResetLists (self-contained, no external dependencies)
resetListLogFile := A_ScriptDir . "\..\..\Logs\log_resetlist.txt"
resetListLogFile := StrReplace(resetListLogFile, "\\", "\")

; Create Logs directory if it doesn't exist
logsDir := A_ScriptDir . "\..\..\Logs"
logsDir := StrReplace(logsDir, "\\", "\")
if (!FileExist(logsDir)) {
    FileCreateDir, %logsDir%
}

; Custom logging function for ResetLists (self-contained)
LogToResetListFile(message) {
    global resetListLogFile
    timestamp := A_Now
    FormatTime, formattedTime, %timestamp%, yyyy-MM-dd HH:mm:ss
    logEntry := formattedTime . " - " . message . "`n"
    FileAppend, %logEntry%, %resetListLogFile%
}

; Log script start
LogToResetListFile("ResetLists.ahk started - Beginning cleanup session")

; Define the primary paths more efficiently
scriptDir := A_ScriptDir
saveDir := scriptDir . "\..\..\Accounts\Saved"

; Clean up path efficiently
saveDir := StrReplace(saveDir, "\\", "\")

LogToResetListFile("Attempting to access primary path: " . saveDir)

; Quick directory existence check with fallback
if (!FileExist(saveDir)) {
    LogToResetListFile("Primary path not found, trying fallback path")
    ; Try alternative path directly
    saveDir := scriptDir . "\..\Accounts\Saved" 
    saveDir := StrReplace(saveDir, "\\", "\")
    
    LogToResetListFile("Attempting fallback path: " . saveDir)
    
    ; Exit immediately if neither path exists
    if (!FileExist(saveDir)) {
        LogToResetListFile("ERROR: Neither primary nor fallback path exists. Exiting.")
        ExitApp
    }
}

LogToResetListFile("Successfully found Accounts\Saved directory at: " . saveDir)

; Count existing files before deletion for logging
totalFilesFound := 0
foldersProcessed := 0
filesFoundDetails := ""

Loop, Files, %saveDir%\*, D
{
    foldersProcessed++
    folderPath := A_LoopFileFullPath
    folderName := A_LoopFileName
    
    ; Count files in this folder and track specific files
    filesInFolder := 0
    folderFiles := ""
    
    if (FileExist(folderPath . "\list.txt")) {
        filesInFolder++
        totalFilesFound++
        folderFiles .= "list.txt, "
    }
    if (FileExist(folderPath . "\list_current.txt")) {
        filesInFolder++
        totalFilesFound++
        folderFiles .= "list_current.txt, "
    }
    if (FileExist(folderPath . "\list_last_generated.txt")) {
        filesInFolder++
        totalFilesFound++
        folderFiles .= "list_last_generated.txt, "
    }
    
    if (filesInFolder > 0) {
        folderFiles := RTrim(folderFiles, ", ")
        LogToResetListFile("Found " . filesInFolder . " list files in folder " . folderName . ": " . folderFiles)
        filesFoundDetails .= folderName . " (" . folderFiles . "), "
    }
}

if (filesFoundDetails != "") {
    filesFoundDetails := RTrim(filesFoundDetails, ", ")
}

LogToResetListFile("Pre-deletion summary: Found " . totalFilesFound . " list files across " . foldersProcessed . " folders")
if (totalFilesFound > 0) {
    LogToResetListFile("Files to be deleted: " . filesFoundDetails)
}

; Use batch file deletion for maximum speed
; Create a temporary batch script for bulk deletion
tempBatchFile := A_Temp . "\reset_lists_" . A_TickCount . ".bat"

LogToResetListFile("Creating temporary batch file: " . tempBatchFile)

; Build the batch commands for ultra-fast deletion
batchContent := "@echo off`n"
batchContent .= "cd /d """ . saveDir . """`n"

; Add deletion commands for all possible list files in all subdirectories
; This processes all folders and files in a single batch operation
batchContent .= "for /d %%i in (*) do (`n"
batchContent .= "    if exist ""%%i\list.txt"" del /q ""%%i\list.txt"" 2>nul`n"
batchContent .= "    if exist ""%%i\list_current.txt"" del /q ""%%i\list_current.txt"" 2>nul`n"
batchContent .= "    if exist ""%%i\list_last_generated.txt"" del /q ""%%i\list_last_generated.txt"" 2>nul`n"
batchContent .= ")`n"

; Write the batch file
FileDelete, %tempBatchFile%
FileAppend, %batchContent%, %tempBatchFile%

if (ErrorLevel) {
    LogToResetListFile("ERROR: Failed to create batch file")
    ExitApp
}

LogToResetListFile("Batch file created successfully, executing deletion commands...")

; Execute the batch file and wait for completion
RunWait, "%tempBatchFile%",, Hide

if (ErrorLevel) {
    LogToResetListFile("WARNING: Batch execution completed with error level: " . ErrorLevel)
} else {
    LogToResetListFile("Batch deletion completed successfully")
}

; Clean up the temporary batch file
FileDelete, %tempBatchFile%

; Verify deletion by counting remaining files and track what was actually deleted
remainingFiles := 0
foldersChecked := 0
actuallyDeleted := ""
failedDeletions := ""

Loop, Files, %saveDir%\*, D
{
    foldersChecked++
    folderPath := A_LoopFileFullPath
    folderName := A_LoopFileName
    
    ; Check what was successfully deleted and what remains
    folderDeleted := ""
    folderRemaining := ""
    
    if (FileExist(folderPath . "\list.txt")) {
        remainingFiles++
        folderRemaining .= "list.txt, "
        LogToResetListFile("WARNING: list.txt still exists in folder: " . folderName)
    } else {
        ; Check if it existed before (from our earlier scan)
        if (InStr(filesFoundDetails, folderName . " (list.txt") || InStr(filesFoundDetails, ", list.txt")) {
            folderDeleted .= "list.txt, "
        }
    }
    
    if (FileExist(folderPath . "\list_current.txt")) {
        remainingFiles++
        folderRemaining .= "list_current.txt, "
        LogToResetListFile("WARNING: list_current.txt still exists in folder: " . folderName)
    } else {
        ; Check if it existed before
        if (InStr(filesFoundDetails, folderName . " (list_current.txt") || InStr(filesFoundDetails, ", list_current.txt")) {
            folderDeleted .= "list_current.txt, "
        }
    }
    
    if (FileExist(folderPath . "\list_last_generated.txt")) {
        remainingFiles++
        folderRemaining .= "list_last_generated.txt, "
        LogToResetListFile("WARNING: list_last_generated.txt still exists in folder: " . folderName)
    } else {
        ; Check if it existed before
        if (InStr(filesFoundDetails, folderName . " (list_last_generated.txt") || InStr(filesFoundDetails, ", list_last_generated.txt")) {
            folderDeleted .= "list_last_generated.txt, "
        }
    }
    
    ; Log what was deleted from this folder
    if (folderDeleted != "") {
        folderDeleted := RTrim(folderDeleted, ", ")
        LogToResetListFile("Successfully deleted from folder " . folderName . ": " . folderDeleted)
        actuallyDeleted .= folderName . " (" . folderDeleted . "), "
    }
    
    ; Track failed deletions
    if (folderRemaining != "") {
        folderRemaining := RTrim(folderRemaining, ", ")
        failedDeletions .= folderName . " (" . folderRemaining . "), "
    }
}

; Clean up trailing commas
if (actuallyDeleted != "") {
    actuallyDeleted := RTrim(actuallyDeleted, ", ")
}
if (failedDeletions != "") {
    failedDeletions := RTrim(failedDeletions, ", ")
}

; Final summary log with detailed file information
deletedFiles := totalFilesFound - remainingFiles
LogToResetListFile("Deletion summary: " . deletedFiles . " files deleted, " . remainingFiles . " files remaining")
LogToResetListFile("Processed " . foldersChecked . " folders in total")

if (actuallyDeleted != "") {
    LogToResetListFile("Successfully deleted files: " . actuallyDeleted)
}

if (remainingFiles = 0) {
    LogToResetListFile("SUCCESS: All account list files have been successfully deleted")
} else {
    LogToResetListFile("WARNING: " . remainingFiles . " files could not be deleted")
    if (failedDeletions != "") {
        LogToResetListFile("Failed deletions: " . failedDeletions)
    }
}

LogToResetListFile("ResetLists.ahk completed")

ExitApp