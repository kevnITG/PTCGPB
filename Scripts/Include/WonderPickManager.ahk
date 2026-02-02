;===============================================================================
; WonderPickManager.ahk - Wonder Pick Tracking Functions
;===============================================================================
; This file contains functions for managing Wonder Pick tracking and verification.
; These functions handle:
;   - Checking for Wonder Pick thanks/gifts
;   - Saving and loading WP metadata (username, friend code)
;   - Converting W flags to W2 flags (first check to second check)
;   - Removing W/W2 flags after verification
;   - Cleaning up stale metadata
;   - Sending Discord notifications for WP status
;
; Dependencies: Logging.ahk, Database.ahk, AccountManager.ahk (for HasFlagInMetadata)
; Used by: Main bot loop when processing W-flagged accounts
;===============================================================================

;-------------------------------------------------------------------------------
; SaveWPMetadata - Save Wonder Pick metadata for an account
;-------------------------------------------------------------------------------
SaveWPMetadata(accountFileName, username, friendCode) {
    global winTitle

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle

    if !FileExist(saveDir) {
        FileCreateDir, %saveDir%
    }

    metadataFile := saveDir . "\wp_metadata.txt"

    if (username = "" || username = "ERROR")
        username := "Unknown"
    if (friendCode = "" || friendCode = "ERROR")
        friendCode := "Unknown"

    metadataKey := accountFileName
    if (InStr(accountFileName, "P")) {
        accountParts := StrSplit(accountFileName, "P")
        if (accountParts.Length() >= 2) {
            metadataKey := accountParts[2]  ; e.g., "_20250430105516_3(W).xml"
            metadataKey := LTrim(metadataKey, "_")  ; Remove leading underscore
        }
    }

    existingMetadata := ""
    if (FileExist(metadataFile)) {
        FileRead, existingMetadata, %metadataFile%
    }

    newEntry := metadataKey . "|" . username . "|" . friendCode

    updatedMetadata := ""
    entryExists := false

    Loop, Parse, existingMetadata, `n, `r
    {
        if (A_LoopField = "") {
            continue
        }

        parts := StrSplit(A_LoopField, "|")
        if (parts.Length() >= 1 && parts[1] = metadataKey) {
            ; Update existing entry
            updatedMetadata .= newEntry . "`n"
            entryExists := true
        } else {
            ; Keep existing entry
            updatedMetadata .= A_LoopField . "`n"
        }
    }

    if (!entryExists) {
        updatedMetadata .= newEntry . "`n"
    }

    FileDelete, %metadataFile%
    FileAppend, %updatedMetadata%, %metadataFile%

    if (!FileExist(metadataFile)) {
        return false
    }

    FileGetSize, fileSize, %metadataFile%

    return true
}

;-------------------------------------------------------------------------------
; LoadWPMetadata - Load Wonder Pick metadata for an account
;-------------------------------------------------------------------------------
LoadWPMetadata(accountFileName, ByRef username, ByRef friendCode) {
    global winTitle

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    metadataFile := saveDir . "\wp_metadata.txt"

    ; Default values
    username := "Unknown"
    friendCode := "Unknown"

    metadataKey := accountFileName
    if (InStr(accountFileName, "P")) {
        accountParts := StrSplit(accountFileName, "P")
        if (accountParts.Length() >= 2) {
            metadataKey := accountParts[2]
            metadataKey := LTrim(metadataKey, "_")
        }
    }

    if (!FileExist(metadataFile)) {
        return false
    }

    FileRead, metadataContent, %metadataFile%

    ; Parse to find the account
    Loop, Parse, metadataContent, `n, `r
    {
        if (A_LoopField = "") {
            continue
        }

        parts := StrSplit(A_LoopField, "|")
        if (parts.Length() >= 3 && parts[1] = metadataKey) {
            username := parts[2]
            friendCode := parts[3]

            if (username = "")
                username := "Unknown"
            if (friendCode = "")
                friendCode := "Unknown"

            return true
        }
    }

    return false
}

;-------------------------------------------------------------------------------
; CleanupWPMetadata - Remove metadata for accounts without W flags
;-------------------------------------------------------------------------------
CleanupWPMetadata() {
    global winTitle, verboseLogging

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    metadataFile := saveDir . "\wp_metadata.txt"

    if (!FileExist(metadataFile)) {
        return
    }

    FileRead, metadataContent, %metadataFile%
    if (metadataContent = "") {
        return
    }

    updatedMetadata := ""
    removedCount := 0
    keptCount := 0

    Loop, Parse, metadataContent, `n, `r
    {
        if (A_LoopField = "") {
            continue
        }

        parts := StrSplit(A_LoopField, "|")
        if (parts.Length() >= 3) {
            metadataKey := parts[1]  ; e.g., "20250428041228_2(BW).xml"

            ; Search for the account file with any pack count prefix
            searchPattern := "*P_" . metadataKey

            foundFile := false
            Loop, Files, %saveDir%\%searchPattern%
            {
                ; Check if file still has W or W2 flag
                if (InStr(A_LoopFileName, "W")) {
                    foundFile := true
                    break
                }
            }

            ; If no matching file with W flag found, remove metadata
            if (foundFile) {
                updatedMetadata .= A_LoopField . "`n"
                keptCount++
            } else {
                removedCount++
            }
        }
    }

    ; Only rewrite file if we actually removed something
    if (removedCount > 0) {
        FileDelete, %metadataFile%
        if (updatedMetadata != "") {
            FileAppend, %updatedMetadata%, %metadataFile%
        }
    }
}

;-------------------------------------------------------------------------------
; CheckWonderPickThanks - Check if account received Wonder Pick thanks
;-------------------------------------------------------------------------------
CheckWonderPickThanks() {
    ; NOTE: This function is deprecated and no longer called
    ; WonderPick thanks checking feature has been removed
    global accountFileName, wpThanksSavedUsername, wpThanksSavedFriendCode
    global discordWebhookURL, discordUserId, scriptName, packsInPool, openPack, scaleParam
    global username, friendCode

    if (!HasFlagInMetadata(accountFileName, "W")) {
        return false  ; Not a W flag account
    }

    isSecondCheck := HasFlagInMetadata(accountFileName, "W2")
    checkStage := isSecondCheck ? "FINAL" : "FIRST"

    CreateStatusMessage("Checking WonderPick Thanks (" . checkStage ") for account...",,,, false)
    LogToFile("Starting WonderPick " . checkStage . " check for: " . accountFileName)

    ; Load username and friend code from centralized metadata
    LoadWPMetadata(accountFileName, wpThanksSavedUsername, wpThanksSavedFriendCode)

    ; Set speed to 3x
    FindImageAndClick(25, 145, 70, 170, , "speedmodMenu", 18, 109, 2000)
    FindImageAndClick(182, 170, 194, 190, , "Three", 187, 180)
    Delay(1)
    adbClick_wbb(41, 339)
    Delay(1)

    ; Navigate to gifts/mail screen with timeout protection
    try {
        FindImageAndClick(240, 70, 270, 110, , "Mail", 34, 518, 1000)
        Delay(3)
        FindImageAndClick(164, 431, 224, 460, , "ClaimAll", 247, 93, 1000)
        Delay(20)
    } catch e {
        ; If anything fails during navigation, handle gracefully
        LogToFile("WP Thanks check failed during navigation for: " . accountFileName . " - " . e.message)
        RemoveWFlagFromAccount()
        SendWPStuckWarning("Navigation Error")
        return true
    }

    thanksFound := false
    screenshotPath := ""

    if(FindOrLoseImage(25, 137, 57, 161, 140, "ShopTicket", 0)) {
        thanksFound := true
        LogToFile("ShopTicket found")

        ; Take screenshot BEFORE clicking for LIVE packs
        screenshotPath := Screenshot("WP_THANKS_LIVE", "WonderPickThanks")

        adbClick(212, 427)
    }

    if (thanksFound) {
        CreateStatusMessage("Shop Ticket gift found! Pack is likely LIVE",,,, false)
        LogToFile("Shop Ticket found for account: " . accountFileName . " (User: " . wpThanksSavedUsername . ", FC: " . wpThanksSavedFriendCode . ")")
        Delay(20)

        ; For LIVE packs, remove W flag completely (no second check needed)
        RemoveWFlagFromAccount()
        LogToFile("LIVE pack found, removed W flag completely from: " . accountFileName)

    } else {
        CreateStatusMessage("Shop Ticket not found. Pack is likely DEAD",,,, false)
        LogToFile("No WonderPick Thanks found for account: " . accountFileName . " (User: " . wpThanksSavedUsername . ", FC: " . wpThanksSavedFriendCode . ")")
        Delay(5)

        ; Handle flag conversion or removal for DEAD packs
        if (isSecondCheck) {
            ; This was the final check - remove W2 flag completely
            RemoveWFlagFromAccount()
            LogToFile("Final WonderPick check completed, removed W2 flag from: " . accountFileName)
        } else {
            ; This was the first check - convert W to W2 for second check
            ConvertWToW2Flag()
            LogToFile("First WonderPick check completed, converted W to W2 flag for: " . accountFileName)
        }
    }

    ; Send Discord notification
    SendWPThanksReport(thanksFound, checkStage, screenshotPath)

    return true
}

;-------------------------------------------------------------------------------
; SendWPStuckWarning - Send Discord warning when WP check gets stuck
;-------------------------------------------------------------------------------
SendWPStuckWarning(stuckAt) {
    global wpThanksSavedUsername, wpThanksSavedFriendCode, accountFileName, scriptName
    global discordWebhookURL, discordUserId

    displayUsername := (wpThanksSavedUsername != "") ? wpThanksSavedUsername : "Unknown"
    displayFriendCode := (wpThanksSavedFriendCode != "") ? wpThanksSavedFriendCode : "Unknown"

    discordMessage := "**[WP CHECK STUCK]** " . displayUsername . " " . displayFriendCode . " - Bot got stuck at '" . stuckAt . "' during WonderPick thanks check. Removed W flag and continuing. Please check manually if this account received WonderPick thanks. Account: " . accountFileName

    ; Send with ping to alert user
    LogToDiscord(discordMessage, "", true, "", "", discordWebhookURL, discordUserId)
    LogToFile("WP thanks check stuck warning sent for: " . accountFileName . " (stuck at: " . stuckAt . ")")
}

;-------------------------------------------------------------------------------
; ConvertWToW2Flag - Convert W flag to W2 flag for second check
;-------------------------------------------------------------------------------
ConvertWToW2Flag() {
    global accountFileName, winTitle

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    oldFilePath := saveDir . "\" . accountFileName

    ; Check if file exists and has W flag (but not W2)
    if (!FileExist(oldFilePath) || !InStr(accountFileName, "W") || HasFlagInMetadata(accountFileName, "W2")) {
        return
    }

    ; Convert W to W2 in the metadata
    newFileName := StrReplace(accountFileName, "W", "W2")

    ; Rename the file
    if (newFileName != accountFileName) {
        newFilePath := saveDir . "\" . newFileName
        FileMove, %oldFilePath%, %newFilePath%
        LogToFile("Converted W to W2 flag: " . accountFileName . " -> " . newFileName)
        accountFileName := newFileName
    }
}

;-------------------------------------------------------------------------------
; SendWPThanksReport - Send Discord report with WP thanks check results
;-------------------------------------------------------------------------------
SendWPThanksReport(thanksFound, checkStage := "FIRST", screenshotPath := "") {
    global wpThanksSavedUsername, wpThanksSavedFriendCode, accountFileName, scriptName
    global discordWebhookURL, discordUserId

    ; Use the freshly obtained values
    displayUsername := (wpThanksSavedUsername != "") ? wpThanksSavedUsername : "Unknown"
    displayFriendCode := (wpThanksSavedFriendCode != "") ? wpThanksSavedFriendCode : "Unknown"

    if (thanksFound) {
        ; LIVE pack messaging - don't include <@> in message since LogToDiscord handles pinging
        discordMessage := "**[LIVE]** " . displayUsername . " " . displayFriendCode . " " . accountFileName

        ; Send with screenshot and ping user (LogToDiscord will handle the @mention)
        LogToDiscord(discordMessage, screenshotPath, true, "", "", discordWebhookURL, discordUserId)
    } else {
        ; DEAD pack messaging - don't include <@> in message
        if (checkStage = "FIRST") {
            discordMessage := displayUsername . " " . displayFriendCode . " did not receive any wonderpick thanks. [LIKELY DEAD] - checking again in 12 hours to confirm."
        } else {
            discordMessage := displayUsername . " " . displayFriendCode . " did not receive any wonderpick thanks after 12 hours. [LIKELY DEAD] - will not be checked again."
        }

        ; Send without pinging (empty user ID parameter)
        LogToDiscord(discordMessage, "", true, "", "", discordWebhookURL, "")
    }

    status := thanksFound ? "LIVE" : "DEAD"
    LogToFile("WP Thanks " . checkStage . " report sent: " . status . " for " . accountFileName . " (Username: " . displayUsername . ", FriendCode: " . displayFriendCode . ")")
}

;-------------------------------------------------------------------------------
; RemoveWFlagFromAccount - Remove W or W2 flag from account filename
;-------------------------------------------------------------------------------
RemoveWFlagFromAccount() {
    global accountFileName, winTitle

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    oldFilePath := saveDir . "\" . accountFileName

    ; Check if file exists and has any W flag
    if (!FileExist(oldFilePath) || !InStr(accountFileName, "W")) {
        LogToFile("RemoveWFlagFromAccount: No W flag found or file doesn't exist: " . accountFileName)
        return
    }

    isFinalCheck := HasFlagInMetadata(accountFileName, "W2")

    ; Remove W from the metadata
    newFileName := accountFileName
    if (InStr(accountFileName, "(")) {
        ; Extract metadata and remove W or W2
        parts1 := StrSplit(accountFileName, "(")
        leftPart := parts1[1]

        if (InStr(parts1[2], ")")) {
            parts2 := StrSplit(parts1[2], ")")
            metadata := parts2[1]
            rightPart := parts2[2]

            ; Remove both W2 and W from metadata
            newMetadata := StrReplace(metadata, "W2", "")
            newMetadata := StrReplace(newMetadata, "W", "")

            ; Reconstruct filename
            if (newMetadata = "") {
                newFileName := leftPart . rightPart
            } else {
                newFileName := leftPart . "(" . newMetadata . ")" . rightPart
            }
        }
    }

    ; Rename the file if it changed
    if (newFileName != accountFileName) {
        newFilePath := saveDir . "\" . newFileName
        FileMove, %oldFilePath%, %newFilePath%
        LogToFile("Removed W flag: " . accountFileName . " -> " . newFileName)
        accountFileName := newFileName

        ; ONLY cleanup metadata on final check (W2 removal), not on first check (W to W2 conversion)
        if (isFinalCheck) {
            CleanupSingleAccountMetadata(newFileName)
        }
    }
}

;-------------------------------------------------------------------------------
; CleanupSingleAccountMetadata - Remove WP metadata for a single account
;-------------------------------------------------------------------------------
CleanupSingleAccountMetadata(accountFileName) {
    global winTitle

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    metadataFile := saveDir . "\wp_metadata.txt"

    if (!FileExist(metadataFile)) {
        return
    }

    metadataKey := accountFileName
    if (InStr(accountFileName, "P")) {
        accountParts := StrSplit(accountFileName, "P")
        if (accountParts.Length() >= 2) {
            metadataKey := accountParts[2]
            metadataKey := LTrim(metadataKey, "_")
        }
    }

    FileRead, metadataContent, %metadataFile%
    updatedMetadata := ""

    Loop, Parse, metadataContent, `n, `r
    {
        if (A_LoopField = "") {
            continue
        }

        parts := StrSplit(A_LoopField, "|")
        ; Keep all entries EXCEPT the one matching this account
        if (parts.Length() >= 1 && parts[1] != metadataKey) {
            updatedMetadata .= A_LoopField . "`n"
        }
    }

    FileDelete, %metadataFile%
    if (updatedMetadata != "") {
        FileAppend, %updatedMetadata%, %metadataFile%
    }
}
