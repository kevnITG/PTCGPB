IsGitRepo(path) {
    tmpFile := A_Temp . "\ptcgpb_git_check.txt"
    RunWait, %ComSpec% /c git -C "%path%" rev-parse --git-dir > "%tmpFile%" 2>&1,, Hide
    FileRead, output, %tmpFile%
    return (Trim(output) != "" && !RegExMatch(output, "not a git repository"))
}

; =======================================================================
; == CommitAndPushGit ==
; Commit and push account XMLs, and screenshots PNGs.
; Commit message is account +X-Y, Screenshots +X-Y for easier tracking.
; Adding git_history.csv log to track commits with timestamp and message.
; =======================================================================
CommitAndPushGit(gitRoot, logFile, pathsList) {
    try {
        tmpFile := A_Temp . "\ptcgpb_git_diff.txt"
        gitHistoryFile := gitRoot . "\git_history.csv"

        ; Build git add command - scope to suffix glob when provided
        addPaths := ""
        for i, entry in pathsList {
            ; Normalize backslashes to forward slashes. Assumes entry.path already ends with '/'
            normPath := StrReplace(entry.path, "\", "/")

            if (entry.suffix != "")
                addPaths .= " """ . normPath . "**/*" . entry.suffix . """"
            else
                addPaths .= " """ . normPath . """"
        }

        if (addPaths = "") {
            LogToFile("No files to commit.", logFile)
            return True
        }

        RunWait, %ComSpec% /c git -C "%gitRoot%" add%addPaths% > "%tmpFile%" 2>&1,, Hide
        FileRead, addOutput, %tmpFile%
        LogToFile("git add output: " . addOutput, logFile)

        ; Get staged changes
        RunWait, %ComSpec% /c git -C "%gitRoot%" diff --cached --name-status > "%tmpFile%" 2>&1,, Hide
        FileRead, diffOutput, %tmpFile%
        LogToFile("git diff --cached --name-status output: " . diffOutput, logFile)

        if (diffOutput = "") {
            LogToFile("No changes to commit.", logFile)
            return True
        }

        ; Initialize per-entry counters
        added := {}
        removed := {}
        for i, entry in pathsList {
            added[i] := 0
            removed[i] := 0
        }

        Loop, Parse, diffOutput, `n, `r
        {
            line := Trim(A_LoopField)
            if (line = "")
                continue
            ; Format: STATUS<tab>PATH
            RegExMatch(line, "^([A-Z])\t(.+)$", m)
            status := m1
            filePath := m2
            for i, entry in pathsList {
                if (entry.suffix != "" && !RegExMatch(filePath, "\" . entry.suffix . "$"))
                    continue
                if (entry.suffix = "" && filePath != entry.path)
                    continue
                if (status = "A" || status = "M")
                    added[i]++
                else if (status = "D")
                    removed[i]++
            }
        }

        ; Build commit message, skip entries with no changes
        commitMsg := "Auto-commit:"
        firstPart := True
        for i, entry in pathsList {
            if (added[i] = 0 && removed[i] = 0)
                continue
            if (!firstPart)
                commitMsg .= " |"
            commitMsg .= " " . entry.path . " +" . added[i] . " -" . removed[i]
            firstPart := False
        }

        if (firstPart) {
            LogToFile("No tracked changes staged. Skipping commit.", logFile)
            return True
        }

        LogToFile("Committing: " . commitMsg, logFile)

        ; Commit
        RunWait, %ComSpec% /c git -C "%gitRoot%" commit -m "%commitMsg%" > "%tmpFile%" 2>&1,, Hide
        FileRead, commitOutput, %tmpFile%
        LogToFile("git commit output: " . commitOutput, logFile)

        try {
            ; Push
            RunWait, %ComSpec% /c git -C "%gitRoot%" push > "%tmpFile%" 2>&1,, Hide
            FileRead, pushOutput, %tmpFile%
            LogToFile("git push output: " . pushOutput, logFile)
        } catch pushError {
            LogToFile("Git push error: " . pushError.Message, logFile)
        }

        ; Append to git_history.csv
        if (!FileExist(gitHistoryFile))
            FileAppend, % "timestamp,message`n", %gitHistoryFile%

        FormatTime, nowStr, %A_Now%, yyyy-MM-dd HH:mm:ss
        FileAppend, % nowStr . "," . commitMsg . "`n", %gitHistoryFile%

        LogToFile("Git auto-commit complete.", logFile)
    } catch e {
        LogToFile("Git auto-commit error: " . e.Message, logFile)
        return False
    }
    return True
}
