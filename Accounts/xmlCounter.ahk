#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%

; Main execution
Main()

Main() {
    ; Get the script directory (should be in Accounts folder)
    ScriptDir := A_ScriptDir
    SavedDir := ScriptDir . "\Saved"
    
    ; Check if Saved directory exists
    if !FileExist(SavedDir) {
        MsgBox, 16, Error, Saved directory not found!`nExpected: %SavedDir%
        ExitApp
    }
    
    ; Show progress message
    Progress, b w300 h50, Analyzing XML files..., Please wait, Account Analysis
    
    ; Analyze directory
    Result := AnalyzeDirectory(SavedDir)
    
    ; Close progress
    Progress, Off
    
    ; Show results
    if (Result.TotalFiles = 0) {
        MsgBox, 48, No Files Found, No XML files found in the Saved directory.
    } else {
        ShowSummary(Result)
    }
}

AnalyzeDirectory(DirectoryPath) {
    ; Initialize result object
    Result := {}
    Result.TotalFiles := 0
    Result.RegularPacks := {}
    Result.RerollSummary := {}
    
    ; Initialize regular packs (1-38) with 0 count
    Loop, 38 {
        Result.RegularPacks[A_Index] := 0
    }
    
    ; Find all XML files recursively
    XMLFiles := []
    FindXMLFiles(DirectoryPath, XMLFiles)
    
    ; Filter out Account Vault files (if they exist)
    FilteredFiles := []
    for Index, FilePath in XMLFiles {
        if !InStr(FilePath, "\Account Vault\") {
            FilteredFiles.Push(FilePath)
        }
    }
    
    Result.TotalFiles := FilteredFiles.Length()
    
    ; Analyze each file
    for Index, FilePath in FilteredFiles {
        ; Extract filename from full path
        SplitPath, FilePath, FileName
        
        ; Parse filename using regex pattern: (\d+)P(_\d+)+(\([A-Za-z]+\))*(.*\.xml)
        if RegExMatch(FileName, "^(\d+)P(_\d+)+(\([A-Za-z]+\))*(.*\.xml)$", Match) {
            PackNumber := Match1 + 0  ; Convert to number
            
            if (PackNumber >= 39) {
                ; Reroll Ready category
                if (PackNumber >= 39 and PackNumber < 50) {
                    RangeName := "39-50"
                } else if (PackNumber >= 50 and PackNumber < 60) {
                    RangeName := "50-60"
                } else {
                    ; For higher ranges
                    RangeStart := Floor(PackNumber / 10) * 10
                    RangeEnd := RangeStart + 10
                    RangeName := RangeStart . "-" . RangeEnd
                }
                
                if !Result.RerollSummary.HasKey(RangeName) {
                    Result.RerollSummary[RangeName] := 0
                }
                Result.RerollSummary[RangeName]++
            } else if (PackNumber >= 1 and PackNumber <= 38) {
                ; Regular packs category
                Result.RegularPacks[PackNumber]++
            }
        }
    }
    
    return Result
}

FindXMLFiles(Directory, ByRef FileArray) {
    ; Search for XML files in current directory
    Loop, Files, %Directory%\*.xml
    {
        FileArray.Push(A_LoopFileFullPath)
    }
    
    ; Search subdirectories recursively
    Loop, Files, %Directory%\*.*, D
    {
        if (A_LoopFileName != "." and A_LoopFileName != "..") {
            FindXMLFiles(A_LoopFileFullPath, FileArray)
        }
    }
}

ShowSummary(Result) {
    ; Build summary message
    Message := "=== XML Account Summary ===" . "`n`n"
    Message .= "Total XML files found: " . Result.TotalFiles . "`n`n"
    
    ; Regular Packs section
    Message .= "=== Regular Pack Folders ===" . "`n"
    RegularTotal := 0
    
    ; Count non-zero regular packs first
    NonZeroCount := 0
    for PackNum, Count in Result.RegularPacks {
        if (Count > 0) {
            NonZeroCount++
            RegularTotal += Count
        }
    }
    
    if (NonZeroCount > 0) {
        ; Determine column layout based on number of non-zero packs
        if (NonZeroCount <= 13) {
            Columns := 1
        } else if (NonZeroCount <= 26) {
            Columns := 2
        } else {
            Columns := 3
        }
        
        CurrentColumn := 1
        ItemsInColumn := 0
        MaxItemsPerColumn := Ceil(NonZeroCount / Columns)
        
        ; Display packs in order
        Loop, 38 {
            PackNum := A_Index
            Count := Result.RegularPacks[PackNum]
            
            if (Count > 0) {
                if (ItemsInColumn >= MaxItemsPerColumn and CurrentColumn < Columns) {
                    Message .= "`n"  ; Start new column
                    CurrentColumn++
                    ItemsInColumn := 0
                }
                
                Message .= PackNum . " Packs: " . Count . " files"
                
                if (CurrentColumn < Columns and ItemsInColumn < MaxItemsPerColumn - 1) {
                    Message .= "    "  ; Add spacing for columns
                }
                
                Message .= "`n"
                ItemsInColumn++
            }
        }
    } else {
        Message .= "No regular pack files found.`n"
    }
    
    ; Reroll Ready section
    if (Result.RerollSummary.Count() > 0) {
        Message .= "`n=== Reroll Ready ===" . "`n"
        
        RerollTotal := 0
        for RangeName, Count in Result.RerollSummary {
            RerollTotal += Count
        }
        Message .= "Total: " . RerollTotal . " files`n"
        
        ; Sort reroll ranges by starting number
        SortedRanges := []
        for RangeName, Count in Result.RerollSummary {
            ; Extract starting number for sorting
            StartNum := RegExReplace(RangeName, "-.*", "") + 0
            SortedRanges.Push({Range: RangeName, Count: Count, StartNum: StartNum})
        }
        
        ; Simple bubble sort by StartNum
        Loop, % SortedRanges.Length() {
            Outer := A_Index
            Loop, % SortedRanges.Length() - Outer {
                Inner := A_Index
                if (SortedRanges[Inner].StartNum > SortedRanges[Inner + 1].StartNum) {
                    ; Swap elements
                    Temp := SortedRanges[Inner]
                    SortedRanges[Inner] := SortedRanges[Inner + 1]
                    SortedRanges[Inner + 1] := Temp
                }
            }
        }
        
        ; Display sorted reroll ranges
        for Index, Item in SortedRanges {
            Message .= Item.Range . " Packs: " . Item.Count . " files`n"
        }
    }
    
    ; Show the summary in a message box
    MsgBox, 0, Account Summary, %Message%
}