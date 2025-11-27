; XML Duplicate Finder
; Scans for duplicate XML files in Accounts\Saved folder and removes duplicates
; Keeps files with higher P numbers or older timestamps

#NoEnv
#SingleInstance Force

; Get the script's directory (should be in Accounts folder)
ScriptDir := A_ScriptDir
SavedDir := ScriptDir . "\Saved"

; Check if Saved directory exists
if !FileExist(SavedDir) {
    MsgBox, 16, Error, Could not find Saved directory at:`n%SavedDir%`n`nMake sure this script is placed in the Accounts folder.
    ExitApp
}

; Initialize variables
ContentGroups := {}  ; Group files by content
FileCount := 0
DuplicateCount := 0
DeletedCount := 0

; First pass: Count all XML files
Progress, M, Counting XML files..., XML Duplicate Finder
TotalFileCount := CountXMLFiles(SavedDir)
Progress, Off

if (TotalFileCount = 0) {
    MsgBox, 64, No Files Found, No XML files found in the Saved directory.
    ExitApp
}

; Second pass: Scan and group files
Progress, M, Scanning XML files (0/%TotalFileCount%)..., XML Duplicate Finder
ScanAndGroupFiles(SavedDir, ContentGroups, FileCount, TotalFileCount)
Progress, Off

; Process duplicates directly from content groups
Progress, M, Processing duplicates..., XML Duplicate Finder
ProcessResults := ProcessContentGroups(ContentGroups)
Progress, Off

DuplicateCount := ProcessResults.DuplicateCount

if (DuplicateCount = 0) {
    MsgBox, 64, No Duplicates, No duplicate XML files found.`n`nTotal files scanned: %FileCount%
    ExitApp
}

; Ask for confirmation before deletion
MsgBox, 4, Confirm Deletion, Found %DuplicateCount% duplicate files.`n`nProceed with deletion?`n`nThis action cannot be undone.

IfMsgBox No
{
    MsgBox, 64, Cancelled, Duplicate removal cancelled by user.
    ExitApp
}

; Perform actual deletion
Progress, M, Deleting duplicates..., XML Duplicate Finder
ActualDeleted := ExecuteDeletions(ProcessResults.FilesToDelete)
Progress, Off

; Show final results
MsgBox, 64, Completed, Duplicate XML removal completed!`n`nFiles scanned: %FileCount%`nDuplicates found: %DuplicateCount%`nFiles deleted: %ActualDeleted%

ExitApp

; Count all XML files
CountXMLFiles(RootDir) {
    FileCount := 0
    Loop, Files, %RootDir%\*.xml, R
    {
        FileCount++
        if (Mod(FileCount, 50) = 0) {
            Progress, , Counting... (%FileCount% files found)
        }
    }
    return FileCount
}

; Group files directly by deviceAccount
ScanAndGroupFiles(RootDir, ByRef ContentGroups, ByRef FileCount, TotalFiles) {
    ProcessedFiles := 0
    
    Loop, Files, %RootDir%\*.xml, R
    {
        ProcessedFiles++
        FilePath := A_LoopFileFullPath
        
        ; Update progress for every single file
        ProgressPercent := Round((ProcessedFiles / TotalFiles) * 100)
        Progress, %ProgressPercent%, Scanning (%ProcessedFiles%/%TotalFiles%)..., XML Duplicate Finder
        
        ; Extract deviceAccount as the grouping key
        DeviceAccount := ExtractContentKey(FilePath)
        
        ; Skip files that couldn't be processed (but still count them)
        if (DeviceAccount = "") {
            continue
        }
        
        FileCount++  ; Only count successfully processed files
        
        ; Get file metadata once
        FileGetTime, FileTime, %FilePath%, M
        FileGetSize, FileSize, %FilePath%
        SplitPath, FilePath, FileName
        
        ; Create file info object
        FileInfo := CreateFileInfo(FilePath, FileName, FileSize, FileTime)
        
        ; Group directly by deviceAccount
        if (ContentGroups[DeviceAccount] = "")
            ContentGroups[DeviceAccount] := []
        
        ContentGroups[DeviceAccount].Push(FileInfo)
    }
}

; Extract only the deviceAccount
ExtractContentKey(FilePath) {
    FileRead, Content, %FilePath%
    if ErrorLevel
        return ""
    
    ; Ensure the files have a deviceAccount
    if (!InStr(Content, "deviceAccount"))
        return ""
    
    ; Extract deviceAccount with single regex
    if RegExMatch(Content, "deviceAccount"">([^<]+)", Match) {
        DeviceAccount := Match1
        
        ; Return empty if deviceAccount is empty or whitespace
        if (DeviceAccount = "" or RegExMatch(DeviceAccount, "^\s*$"))
            return ""
        
        return DeviceAccount
    }
    
    return ""
}

; Create file info object with extracted filename data
CreateFileInfo(FilePath, FileName, FileSize, FileTime) {
    FileInfo := {Path: FilePath, Name: FileName, Size: FileSize, Time: FileTime}
    
    ; Extract P number and timestamp
    if RegExMatch(FileName, "(\d+)P", PMatch) {
        FileInfo.PNumber := PMatch1 + 0  ; Convert to number
        FileInfo.HasP := true
    } else {
        FileInfo.PNumber := 0
        FileInfo.HasP := false
    }
    
    if RegExMatch(FileName, "(\d{14}_?\d?)", TMatch) {
        FileInfo.Timestamp := TMatch1
    } else {
        FileInfo.Timestamp := "99999999999999"  ; Default to "newest" for sorting
    }
    
    return FileInfo
}

; Process deviceAccount groups to find duplicates
ProcessContentGroups(ContentGroups) {
    FilesToDelete := []
    DuplicateCount := 0
    ProcessedGroups := 0
    TotalGroups := 0
    
    ; Count total groups for progress
    for DeviceAccount, FileGroup in ContentGroups {
        TotalGroups++
    }
    
    for DeviceAccount, FileGroup in ContentGroups {
        ProcessedGroups++
        
        ; Update progress for every group processed
        ProgressPercent := Round((ProcessedGroups / TotalGroups) * 100)
        Progress, %ProgressPercent%, Processing (%ProcessedGroups%/%TotalGroups%)..., XML Duplicate Finder
        
        ; Only process groups with duplicates
        if (FileGroup.Length() < 2)
            continue
        
        ; Select the best file to keep using optimized selection
        FileToKeep := SelectBestFile(FileGroup)
        
        ; Add all other files to deletion list
        for Index, FileInfo in FileGroup {
            if (FileInfo.Path != FileToKeep.Path) {
                FilesToDelete.Push(FileInfo.Path)
                DuplicateCount++
            }
        }
    }
    
    return {FilesToDelete: FilesToDelete, DuplicateCount: DuplicateCount}
}

; Select the correct file between the duplicates
SelectBestFile(FileGroup) {
    BestFile := FileGroup[1]
    
    ; Find the best file in a single pass
    Loop % FileGroup.Length() - 1 {
        Index := A_Index + 1
        CurrentFile := FileGroup[Index]
        
        ; Priority 1: Prefer files with P numbers
        if (CurrentFile.HasP and !BestFile.HasP) {
            BestFile := CurrentFile
            continue
        } else if (!CurrentFile.HasP and BestFile.HasP) {
            continue
        }
        
        ; Priority 2: If both have P numbers, prefer higher P number
        if (CurrentFile.HasP and BestFile.HasP) {
            if (CurrentFile.PNumber > BestFile.PNumber) {
                BestFile := CurrentFile
                continue
            } else if (CurrentFile.PNumber < BestFile.PNumber) {
                continue
            }
        }
        
        ; Priority 3: Prefer older timestamp (smaller timestamp value)
        if (CurrentFile.Timestamp < BestFile.Timestamp) {
            BestFile := CurrentFile
        }
    }
    
    return BestFile
}

; Delete duplicates
ExecuteDeletions(FilesToDelete) {
    DeletedCount := 0
    TotalFiles := FilesToDelete.Length()
    
    Loop % TotalFiles {
        Index := A_Index
        FilePath := FilesToDelete[Index]
        
        ; Update progress for every single file deletion
        ProgressPercent := Round((Index / TotalFiles) * 100)
        Progress, %ProgressPercent%, Deleting (%Index%/%TotalFiles%)..., XML Duplicate Finder
        
        FileDelete, %FilePath%
        if !ErrorLevel
            DeletedCount++
    }
    
    return DeletedCount
}

; Emergency cleanup for script interruption
CleanupTempData() {
    ; Clear large objects from memory
    ContentGroups := ""
    FilesToDelete := ""
}