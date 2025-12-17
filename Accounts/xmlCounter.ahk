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
    
    ; Initialize regular packs (1-95) with 0 count
    Loop, 95 {
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
            
            if (PackNumber >= 96) {
                ; Reroll Ready category
                if (PackNumber >= 96 and PackNumber < 100) {
                    RangeName := "96-100"
                } else if (PackNumber >= 100 and PackNumber < 110) {
                    RangeName := "100-110"
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
            } else if (PackNumber >= 1 and PackNumber <= 95) {
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
    Gui, Summary:New
    Gui, Font, s10, Consolas

    Message := "=== XML Account Summary ===`n`n"
    Message .= "Total XML files found: " Result.TotalFiles "`n`n"
    Message .= "=== Regular Pack Folders ===`n"

    ; Collect non-zero packs
    Packs := []
    for PackNum, Count in Result.RegularPacks
        if (Count > 0)
            Packs.Push({n:PackNum, c:Count})

    CountNonZero := Packs.Length()

    if (CountNonZero = 0) {
        Message .= "No regular pack files found.`n"
    } else {
        Columns := (CountNonZero <= 13) ? 1 : (CountNonZero <= 26 ? 2 : 3)
        Rows := Ceil(CountNonZero / Columns)

        ; Build true columns using fixed-width formatting
        Loop, %Rows% {
            row := A_Index
            Line := ""
            Loop, %Columns% {
                col := A_Index
                idx := row + (col - 1) * Rows
                if (idx <= CountNonZero) {
                    pack := Packs[idx]
                    Line .= Format("{:3} Packs: {:3}", pack.n, pack.c)
                    if (col < Columns)
                        Line .= "    "
                }
            }
            Message .= Line "`n"
        }
    }

    ; Reroll section stays the same
    if (Result.RerollSummary.Count() > 0) {
        Message .= "`n=== Reroll Ready ===`n"
        TotalReroll := 0
        for RangeName, Count in Result.RerollSummary
            TotalReroll += Count

        Message .= "Total: " TotalReroll " files`n"

        ; Display sorted
        Ranges := []
        for RangeName, Count in Result.RerollSummary {
            Start := RegExReplace(RangeName, "-.*")+0
            Ranges.Push({r:RangeName, c:Count, s:Start})
        }
        ; Sort
        Sort, Ranges, F SortRanges
		
		Loop, % Ranges.Length() - 1 {
		i := A_Index
		Loop, % Ranges.Length() - i {
        j := A_Index
        if (Ranges[j].s > Ranges[j+1].s) {
            tmp := Ranges[j]
            Ranges[j] := Ranges[j+1]
            Ranges[j+1] := tmp
        }
    }
}

        for i, rr in Ranges
            Message .= rr.r " Packs: " rr.c "`n"
    }

    Gui, Add, Edit, w600 h500 ReadOnly, %Message%
    Gui, Show, , Account Summary
}

SortRanges(a, b) {
    return (a.s - b.s)
}
