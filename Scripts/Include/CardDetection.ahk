;===============================================================================
; CardDetection.ahk - Card Detection Functions
;===============================================================================
; This file contains functions for detecting and processing cards in packs.
; These functions handle:
;   - Border detection (normal, full art, rainbow, trainer, shiny)
;   - Card type detection (6-card pack vs 5-card pack vs 4-card pack)
;   - God pack detection and validation
;   - Star/special card detection
;   - Tradeable card processing and logging
;   - W flag management for Wonder Pick tracking
;
; Dependencies: GDIP, Database.ahk, WonderPickManager.ahk, AccountManager.ahk
; Used by: Pack opening and evaluation flow in main bot
;===============================================================================

;-------------------------------------------------------------------------------
; DetectSixCardPack - Detect if current pack is a 6-card pack
;-------------------------------------------------------------------------------
DetectSixCardPack() {
    global winTitle, defaultLanguage
    searchVariation := 5 ; needed to tighten from 20 to avoid false positives

    imagePath := A_ScriptDir . "\" . defaultLanguage . "\"

    pBitmap := from_window(WinExist(winTitle))

    ; Look for 6cardpackindicator.png (background element visible only in 5-card packs)
    Path = %imagePath%6cardpackindicator.png
    if (FileExist(Path)) {
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 228, 324, 248, 351, searchVariation)
        if (vRet = 1) {
            ; Found the check image, so this is a 5-card pack
            Gdip_DisposeImage(pBitmap)
            return false  ; Return false = 5-card pack
        }
    }

    ; Did not find check image, so this must be a 6-card pack
    Gdip_DisposeImage(pBitmap)
    return true  ; Return true = 6-card pack
}

;-------------------------------------------------------------------------------
; DetectFourCardPack - Detect if current pack is a 4-card Deluxe pack
;-------------------------------------------------------------------------------
DetectFourCardPack() {
    global openPack
    if (openPack = "Deluxe") {
        return true
    }
    return false
}

;-------------------------------------------------------------------------------
; FindBorders - Find card borders of specific type in pack
;-------------------------------------------------------------------------------
FindBorders(prefix) {
    global currentPackIs6Card, currentPackIs4Card, scaleParam, winTitle, defaultLanguage
    count := 0
    searchVariation := 40 ;
    if (prefix = "normal") {
        searchVariation := 75 ; Increasing for megas patch...
    }
    searchVariation6Card := 60 ; looser tolerance for 6-card positions while we test if top row needles can be re-used for bottom row in 6-card packs
    searchVariation4Card := 60 ;

    if (prefix = "shiny2star") { ; some aren't being detected at lower variations
        searchVariation := 75
        searchVariation6Card := 75
        searchVariation4Card := 75
    }

    is6CardPack := currentPackIs6Card
    is4CardPack := currentPackIs4Card

    if (is4CardPack) {
        borderCoords := [[96, 284, 123, 286]  ; Card 1
            ,[181, 284, 208, 286] ; Card 2
            ,[96, 399, 123, 401] ; Card 3
            ,[181, 399, 208, 401]] ; Card 4
    } else if (is6CardPack) {
        borderCoords := [[56, 284, 83, 286]   ; Top row card 1
            ,[139, 284, 166, 286] ; Top row card 2
            ,[222, 284, 249, 286] ; Top row card 3
            ,[56, 399, 83, 401]   ; Bottom row card 1
            ,[139, 399, 166, 401] ; Bottom row card 2
            ,[256, 386, 260, 402]] ; Bottom row card 3
    } else {
        ; 5-card pack
        borderCoords := [[56, 284, 83, 286] ; Card 1
            ,[139, 284, 166, 286] ; Card 2
            ,[222, 284, 249, 286] ; Card 3
            ,[96, 399, 123, 401] ; Card 4
            ,[181, 399, 208, 401]] ; Card 5
    }

    ; custom smaller borders for Megas splash art compatiblity; currently removing 6 pixels in x from the right side.
    if (prefix = "fullArt") { 
        if (is4CardPack) {
            borderCoords := [[96, 284, 117, 286]  ; Card 1
                ,[181, 284, 202, 286] ; Card 2
                ,[96, 399, 117, 401] ; Card 3
                ,[181, 399, 202, 401]] ; Card 4
        } else if (is6CardPack) {
            borderCoords := [[58, 284, 77, 286]   ; Top row card 1
                ,[141, 284, 160, 286] ; Top row card 2
                ,[224, 284, 243, 286] ; Top row card 3
                ,[58, 399, 77, 401]   ; Bottom row card 1
                ,[141, 399, 160, 401] ; Bottom row card 2
                ,[258, 386, 254, 402]] ; Bottom row card 3
        } else {
            borderCoords := [[58, 284, 77, 286] ; Card 1
                ,[141, 284, 160, 286] ; Card 2
                ,[224, 284, 243, 286] ; Card 3
                ,[98, 399, 117, 401] ; Card 4
                ,[183, 399, 202, 401]] ; Card 5
        }
    }

    ; Changed Shiny 2star needles to improve detection after hours of testing previous needles.
    if (prefix = "shiny2star") {
        if (is4CardPack) {
            borderCoords := [[110, 175, 140, 187]    ; Top row card 1
                ,[192, 175, 223, 187]                ; Top row card 2
                ,[110, 293, 140, 305]                ; Bottom row card 1
                ,[192, 293, 223, 305]]               ; Bottom row card 2
        } else if (is6CardPack) {
            borderCoords := [[74, 175, 97, 187]
                ,[153, 175, 180, 187]
                ,[237, 175, 262, 187]
                ,[74, 293, 97, 305]
                ,[153, 293, 180, 305]
                ,[255, 388, 257, 399]]
        } else {
            borderCoords := [[74, 175, 97, 187]
                ,[153, 175, 180, 187]
                ,[237, 175, 262, 187]
                ,[110, 293, 140, 305]
                ,[192, 293, 223, 305]]
        }
    }

    if (prefix = "shiny1star") {
        if (is6CardPack) {
            borderCoords := [[90, 261, 93, 283]
                ,[173, 261, 176, 283]
                ,[255, 261, 258, 283]
                ,[90, 376, 93, 398]
                ,[173, 376, 176, 398]
                ,[255, 385, 257, 399]]
        } else {
            borderCoords := [[90, 261, 93, 283]
                ,[173, 261, 176, 283]
                ,[255, 261, 258, 283]
                ,[130, 376, 133, 398]
                ,[215, 376, 218, 398]]
        }
    }

    ; 100% scale adjustments
    if (scaleParam = 287) {
        if (prefix = "shiny1star" || prefix = "shiny2star") {
            if (is6CardPack) {
                borderCoords := [[91, 253, 95, 278]
                    ,[175, 253, 179, 278]
                    ,[259, 253, 263, 278]
                    ,[91, 370, 95, 395]
                    ,[175, 371, 179, 394]
                    ,[259, 371, 263, 394]]
            } else {
                borderCoords := [[91, 253, 95, 278]
                    ,[175, 253, 179, 278]
                    ,[259, 253, 263, 278]
                    ,[132, 370, 136, 395]
                    ,[218, 371, 222, 394]]
            }
        } else {
            if (is6CardPack) {
                borderCoords := [[55, 278, 84, 280]     ; Card 1
                    ,[139, 278, 168, 280]                ; Card 2
                    ,[223, 278, 252, 280]                ; Card 3
                    ,[55, 395, 84, 397]                  ; Card 4
                    ,[139, 395, 168, 397]                ; Card 5
                    ,[223, 395, 252, 397]]               ; Card 6
            } else {
                borderCoords := [[55, 278, 84, 280]     ; Card 1
                    ,[139, 278, 168, 280]                ; Card 2
                    ,[223, 278, 252, 280]                ; Card 3
                    ,[96, 395, 125, 397]                 ; Card 4
                    ,[182, 395, 211, 397]]               ; Card 5
            }
        }
    }

    pBitmap := from_window(WinExist(winTitle))
    for index, value in borderCoords {
        coords := borderCoords[A_Index]
        imageName := "" ; prevents accidentally reusing previously loaded imageName if imageName is undefined in custom one-off needles
        currentSearchVariation := searchVariation

        if (is6CardPack && A_Index >= 4) {
            ; Bottom row of 6-card pack (positions 4, 5, 6)
            if (A_Index = 6 && prefix = "shiny1star" || prefix = "shiny2star") {
                ; Use dedicated shiny1star6 needle for 6th card position
                imageName := prefix . "6card6"
            } else if (A_index = 4 && prefix = "normal" || prefix = "3diamond") {
                ; Use dedicated normal4 needle for 4th card position
                imageName := prefix . "6card4"
            } else if (A_Index = 5 && prefix = "normal" || prefix = "3diamond") {
                ; Use dedicated normal5 needle for 5th card position
                imageName := prefix . "6card5"
            } else {
                ; Re-use top row images for positions 4 and 5
                imageIndex := A_Index - 3  ; Card 4 -> uses Card 1 needle, 5->2
                imageName := prefix . imageIndex
            }
            currentSearchVariation := searchVariation6Card
        } else if (is4CardPack) {
            ; 4-card pack (Deluxe) - special needle logic
            if (A_Index <= 2) {
                ; Slots 1 and 2 - try deluxe-specific needle first, fall back to regular
                deluxeImageName := "deluxe" . prefix . A_Index
                regularImageName := prefix . A_Index

                ; Check if deluxe-specific needle exists
                deluxePath := A_ScriptDir . "\" . defaultLanguage . "\" . deluxeImageName . ".png"
                if (FileExist(deluxePath)) {
                    imageName := deluxeImageName
                } else {
                    imageName := regularImageName
                }
            } else {
                ; Slots 3 and 4 - reuse needles from regular 5-card pack slots 4 and 5
                ; Deluxe slot 3 (A_Index=3) uses regular slot 4 needle
                ; Deluxe slot 4 (A_Index=4) uses regular slot 5 needle
                imageName := prefix . (A_Index + 1)
            }
            currentSearchVariation := searchVariation4Card
        } else {
            ; Top row of 6-card pack, or any position in 5-card pack, use the 'real' needles
            imageName := prefix . A_Index
            currentSearchVariation := searchVariation
        }

        Path := A_ScriptDir . "\" . defaultLanguage . "\" . imageName . ".png"
        if (FileExist(Path)) {
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coords[1], coords[2], coords[3], coords[4], currentSearchVariation)
            if (vRet = 1) {
                count += 1
            }
        }
    }
    Gdip_DisposeImage(pBitmap)
    return count
}

;-------------------------------------------------------------------------------
; FindCard - Find specific card in opened pack
;-------------------------------------------------------------------------------
FindCard(prefix) {
    global winTitle, defaultLanguage, scaleParam
    count := 0
    searchVariation := 40
    borderCoords := [[23, 191, 76, 193]
        ,[106, 191, 159, 193]
        ,[189, 191, 242, 193]
        ,[63, 306, 116, 308]
        ,[146, 306, 199, 308]]
    ; 100% scale changes
    if (scaleParam = 287) {
        borderCoords := [[23, 184, 81, 186]
            ,[107, 184, 165, 186]
            ,[191, 184, 249, 186]
            ,[64, 301, 122, 303]
            ,[148, 301, 206, 303]]
    }
    pBitmap := from_window(WinExist(winTitle))
    for index, value in borderCoords {
        coords := borderCoords[A_Index]
        Path = %A_ScriptDir%\%defaultLanguage%\%prefix%%A_Index%.png
        if (FileExist(Path)) {
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coords[1], coords[2], coords[3], coords[4], searchVariation)
            if (vRet = 1) {
                count += 1
            }
        }
    }
    Gdip_DisposeImage(pBitmap)
    return count
}

;-------------------------------------------------------------------------------
; FindGodPack - Detect if current pack is a god pack
;-------------------------------------------------------------------------------
FindGodPack(invalidPack := false) {
    global keepAccount, openPack, minStars, minStarsCrimsonBlaze, minStarsMegaGyarados, minStarsMegaBlaziken, minStarsMegaAltaria
    global minStarsA4Deluxe, minStarsA4Springs, minStarsA4HoOh, minStarsA4Lugia, minStarsA3b, minStarsA3a
    global minStarsA3Solgaleo, minStarsA3Lunala, minStarsA2b, minStarsA2a, minStarsA2Dialga, minStarsA2Palkia
    global minStarsA1Mewtwo, minStarsA1Charizard, minStarsA1Pikachu, minStarsA1a, minStarsShiny, shinyPacks
    global scriptName

    ; Check for normal borders.
    normalBorders := FindBorders("normal")
    if (normalBorders) {
        CreateStatusMessage("Not a God Pack...",,,, false)
        return false
    }

    ; A god pack (although possibly invalid) has been found.
    keepAccount := true

    ; Determine the required minimum stars based on pack type.
    requiredStars := minStars ; Default to general minStars

    ; Check specific selections first, then default to shiny
        if (openPack == "CrimsonBlaze") {
            requiredStars := minStarsCrimsonBlaze
        } else if (openPack == "MegaGyarados") {
            requiredStars := minStarsMegaGyarados
        } else if (openPack == "MegaBlaziken") {
            requiredStars := minStarsMegaBlaziken
        } else if (openPack == "MegaAltaria") {
            requiredStars := minStarsMegaAltaria
        } else if (openPack == "Deluxe") {
            requiredStars := minStarsA4Deluxe
        } else if (openPack == "Springs") {
            requiredStars := minStarsA4Springs
        } else if (openPack == "HoOh") {
            requiredStars := minStarsA4HoOh
        } else if (openPack == "Lugia") {
            requiredStars := minStarsA4Lugia
        } else if (openPack == "Eevee") {
            requiredStars := minStarsA3b
        } else if (openPack == "Buzzwole") {
            requiredStars := minStarsA3a
        } else if (openPack == "Solgaleo") {
            requiredStars := minStarsA3Solgaleo
        } else if (openPack == "Lunala") {
            requiredStars := minStarsA3Lunala
        } else if (openPack = "Shining") {
            requiredStars := minStarsA2b
        } else if (openPack = "Arceus") {
            requiredStars := minStarsA2a
        } else if (openPack = "Dialga") {
            requiredStars := minStarsA2Dialga
        } else if (openPack = "Palkia") {
            requiredStars := minStarsA2Palkia
        } else if (openPack = "Mewtwo") {
            requiredStars := minStarsA1Mewtwo
        } else if (openPack = "Charizard") {
            requiredStars := minStarsA1Charizard
        } else if (openPack = "Pikachu") {
            requiredStars := minStarsA1Pikachu
        } else if (openPack = "Mew") {
            requiredStars := minStarsA1a
        } else if (shinyPacks.HasKey(openPack)) {
            requiredStars := minStarsShiny
        }

    ; Check if pack meets minimum stars requirement
    if (!invalidPack) {
        ; Calculate tempStarCount by counting only valid 2-star cards for minimum check
        tempStarCount := FindBorders("fullart") + FindBorders("rainbow") + FindBorders("trainer")

        if (requiredStars > 0 && tempStarCount < requiredStars) {
            CreateStatusMessage("Pack doesn't contain enough 2 stars...",,,, false)
            invalidPack := true
        }
    }

    if (invalidPack) {
        GodPackFound("Invalid")
        RemoveFriends()
        IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
    } else {
        GodPackFound("Valid")
    }

    return keepAccount
}

;-------------------------------------------------------------------------------
; FoundStars - Process found star/special cards
;-------------------------------------------------------------------------------
FoundStars(star) {
    global scriptName, DeadCheck, ocrLanguage, injectMethod, openPack, deleteMethod, checkWPthanks
    global wpThanksSavedUsername, wpThanksSavedFriendCode, username, friendCode, loadedAccount
    global accountFileName, sendAccountXml, winTitle, packsInPool

    IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
    keepAccount := true

    screenShot := Screenshot(star)
    accountFullPath := ""

    ; Determine if this should get (W) flag
    shouldAddWFlag := false
    if (checkWPthanks = 1 && deleteMethod = "Inject Wonderpick 96P+" && injectMethod && loadedAccount) {
        if (star = "Double two star" || star = "Trainer" || star = "Rainbow" || star = "Full Art") {
            shouldAddWFlag := true
        }
    }

    accountFile := saveAccount(star, accountFullPath, "", shouldAddWFlag)

    if (shouldAddWFlag) {
        AddWFlag()
    }

    friendCode := getFriendCode()

    Sleep, 5000
    fcScreenshot := Screenshot("FRIENDCODE")

    tempDir := A_ScriptDir . "\..\Screenshots\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    usernameScreenshotFile := tempDir . "\" . winTitle . "_Username.png"
    adbTakeScreenshot(usernameScreenshotFile)
    Sleep, 100

    if(star = "Crown" || star = "Immersive" || star = "Shiny")
        RemoveFriends()
    else {
        ; OCR username
        try {
            if (injectMethod && IsFunc("ocr")) {
                playerName := ""
                allowedUsernameChars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-+"
                usernamePattern := "[\w-]+"

                if(RefinedOCRText(usernameScreenshotFile, 125, 490, 290, 50, allowedUsernameChars, usernamePattern, playerName)) {
                    username := playerName
                }
            }
        } catch e {
            LogToFile("Failed to OCR username: " . e.message, "OCR.txt")
        }
    }

    if (FileExist(usernameScreenshotFile)) {
        FileDelete, %usernameScreenshotFile%
    }

    ; Validate before saving metadata
    if (username = "" || !username)
        username := "Unknown"
    if (friendCode = "" || !friendCode)
        friendCode := "Unknown"

    ; Save metadata
    if (shouldAddWFlag) {
        success := SaveWPMetadata(accountFileName, username, friendCode)
    }

    CreateStatusMessage(star . " found!",,,, false)

    statusMessage := star . " found"
    if (username && username != "Unknown")
        statusMessage .= " by " . username
    if (friendCode && friendCode != "Unknown")
        statusMessage .= " (" . friendCode . ")"

    logMessage := statusMessage . " in instance: " . scriptName . " (" . packsInPool . " packs, " . openPack . ")\nFile name: " . accountFile . "\nBacking up to the Accounts\\SpecificCards folder and continuing..."
    LogToDiscord(logMessage, screenShot, true, (sendAccountXml ? accountFullPath : ""), fcScreenshot)
    LogToFile(StrReplace(logMessage, "\n", " "), "GPlog.txt")
}

;-------------------------------------------------------------------------------
; GodPackFound - Process found god pack
;-------------------------------------------------------------------------------
GodPackFound(validity) {
    global scriptName, DeadCheck, ocrLanguage, injectMethod, openPack, deleteMethod, checkWPthanks
    global wpThanksSavedUsername, wpThanksSavedFriendCode, username, friendCode, loadedAccount
    global accountFileName, sendAccountXml, InvalidCheck, winTitle, packsInPool, starCount

    IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck

    if(validity = "Valid") {
        Praise := ["Congrats!", "Congratulations!", "GG!", "Whoa!", "Praise Helix!", "Way to go!", "You did it!", "Awesome!", "Nice!", "Cool!", "You deserve it!", "Keep going!", "This one has to be live!", "No duds, no duds, no duds!", "Fantastic!", "Bravo!", "Excellent work!", "Impressive!", "You're amazing!", "Well done!", "You're crushing it!", "Keep up the great work!", "You're unstoppable!", "Exceptional!", "You nailed it!", "Hats off to you!", "Sweet!", "Kudos!", "Phenomenal!", "Boom! Nailed it!", "Marvelous!", "Outstanding!", "Legendary!", "Youre a rock star!", "Unbelievable!", "Keep shining!", "Way to crush it!", "You're on fire!", "Killing it!", "Top-notch!", "Superb!", "Epic!", "Cheers to you!", "Thats the spirit!", "Magnificent!", "Youre a natural!", "Gold star for you!", "You crushed it!", "Incredible!", "Shazam!", "You're a genius!", "Top-tier effort!", "This is your moment!", "Powerful stuff!", "Wicked awesome!", "Props to you!", "Big win!", "Yesss!", "Champion vibes!", "Spectacular!"]
        invalid := ""
    } else {
        Praise := ["Uh-oh!", "Oops!", "Not quite!", "Better luck next time!", "Yikes!", "That didn't go as planned.", "Try again!", "Almost had it!", "Not your best effort.", "Keep practicing!", "Oh no!", "Close, but no cigar.", "You missed it!", "Needs work!", "Back to the drawing board!", "Whoops!", "That's rough!", "Don't give up!", "Ouch!", "Swing and a miss!", "Room for improvement!", "Could be better.", "Not this time.", "Try harder!", "Missed the mark.", "Keep at it!", "Bummer!", "That's unfortunate.", "So close!", "Gotta do better!"]
        invalid := validity
    }
    Randmax := Praise.Length()
    Random, rand, 1, Randmax
    Interjection := Praise[rand]

    starCount := FindBorders("fullart") + FindBorders("rainbow") + FindBorders("trainer")

    screenShot := Screenshot(validity)
    accountFullPath := ""

    shouldAddWFlag := false
    if (checkWPthanks = 1 && deleteMethod = "Inject Wonderpick 96P+" && validity = "Valid" && injectMethod && loadedAccount) {
        shouldAddWFlag := true
    }

    accountFile := saveAccount(validity, accountFullPath, "", shouldAddWFlag)

    if (shouldAddWFlag) {
        AddWflag()
    }

    friendCode := getFriendCode()

    Sleep, 5000
    fcScreenshot := Screenshot("FRIENDCODE")

    tempDir := A_ScriptDir . "\..\Screenshots\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    usernameScreenshotFile := tempDir . "\" . winTitle . "_Username.png"
    adbTakeScreenshot(usernameScreenshotFile)
    Sleep, 100

    try {
        if (injectMethod && IsFunc("ocr")) {
            playerName := ""
            allowedUsernameChars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-+"
            usernamePattern := "[\w-]+"

            if(RefinedOCRText(usernameScreenshotFile, 125, 490, 290, 50, allowedUsernameChars, usernamePattern, playerName)) {
                username := playerName
            }
        }
    } catch e {
        LogToFile("Failed to OCR username: " . e.message, "OCR.txt")
    }

    if (FileExist(usernameScreenshotFile)) {
        FileDelete, %usernameScreenshotFile%
    }

    ; Validate before saving
    if (username = "" || !username)
        username := "Unknown"
    if (friendCode = "" || !friendCode)
        friendCode := "Unknown"

    if (shouldAddWFlag) {
        success := SaveWPMetadata(accountFileName, username, friendCode)
    }

    CreateStatusMessage(Interjection . (invalid ? " " . invalid : "") . " God Pack found!",,,, false)

    logMessage := Interjection . "\n"
    if (username && username != "Unknown")
        logMessage .= username
    if (friendCode && friendCode != "Unknown")
        logMessage .= " (" . friendCode . ")"
    logMessage .= "\n[" . starCount . "/5][" . packsInPool . "P][" . openPack . "] " . invalid . " God Pack found in instance: " . scriptName . "\nFile name: " . accountFile . "\nBacking up to the Accounts\\GodPacks folder and continuing..."

    LogToFile(StrReplace(logMessage, "\n", " "), "GPlog.txt")

    if (validity = "Valid") {
        LogToDiscord(logMessage, screenShot, true, (sendAccountXml ? accountFullPath : ""), fcScreenshot)
    } else if (!InvalidCheck) {
        LogToDiscord(logMessage, screenShot, true, (sendAccountXml ? accountFullPath : ""))
    }
}

;-------------------------------------------------------------------------------
; AddWflag - Add W flag to current account filename
;-------------------------------------------------------------------------------
AddWflag() {
    global accountFileName, winTitle

    if (!accountFileName) {
        LogToFile("AddWflag: No accountFileName available")
        return
    }

    saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
    oldFilePath := saveDir . "\" . accountFileName

    ; Check if file exists
    if (!FileExist(oldFilePath)) {
        LogToFile("AddWflag: File not found: " . oldFilePath)
        return
    }

    ; Skip if already has W flag
    if (HasFlagInMetadata(accountFileName, "W")) {
        LogToFile("AddWflag: File already has W flag: " . accountFileName)
        return
    }

    ; Add W to the metadata
    newFileName := accountFileName
    if (InStr(accountFileName, "(")) {
        ; File has existing metadata - add W to it
        parts1 := StrSplit(accountFileName, "(")
        leftPart := parts1[1]

        if (InStr(parts1[2], ")")) {
            parts2 := StrSplit(parts1[2], ")")
            metadata := parts2[1]
            rightPart := parts2[2]

            ; Add W to existing metadata
            newMetadata := metadata . "W"
            newFileName := leftPart . "(" . newMetadata . ")" . rightPart
        }
    } else {
        ; File has no metadata - add (W)
        nameAndExtension := StrSplit(accountFileName, ".")
        newFileName := nameAndExtension[1] . "(W).xml"
    }

    ; Rename the file
    if (newFileName != accountFileName) {
        newFilePath := saveDir . "\" . newFileName
        FileMove, %oldFilePath%, %newFilePath%
        LogToFile("Added W flag to original account: " . accountFileName . " -> " . newFileName)
        accountFileName := newFileName
    }
}

;-------------------------------------------------------------------------------
; FoundTradeable - Process found tradeable cards
;-------------------------------------------------------------------------------
FoundTradeable(found3Dmnd := 0, found4Dmnd := 0, found1Star := 0, foundGimmighoul := 0, foundCrown := 0, foundImmersive := 0, foundShiny1Star := 0, foundShiny2Star := 0, foundTrainer := 0, foundRainbow := 0, foundFullArt := 0) {
    global scriptName, keepAccount, s4tWP, s4tWPMinCards, s4tSilent, s4tDiscordWebhookURL, s4tDiscordUserId
    global s4tSendAccountXml, loadDir, deviceAccountXmlMap, s4tPendingTradeables, accountFileName
    global winTitle, packsInPool, openPack, screenShotFileName

    IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck

    keepAccount := true

    foundTradeable := found3Dmnd + found4Dmnd + found1Star + foundGimmighoul + foundCrown + foundImmersive + foundShiny1Star + foundShiny2Star + foundTrainer + foundRainbow + foundFullArt

    if (s4tWP && s4tWPMinCards = 2 && foundTradeable < 2) {
        CreateStatusMessage("s4t: insufficient cards (" . foundTradeable . "/2)",,,, false)
        keepAccount := false
        return
    }

    cardTypes := []
    cardCounts := []

    if (found3Dmnd > 0) {
        cardTypes.Push("3Diamond")
        cardCounts.Push(found3Dmnd)
    }
    if (found4Dmnd > 0) {
        cardTypes.Push("4Diamond")
        cardCounts.Push(found4Dmnd)
    }
    if (found1Star > 0) {
        cardTypes.Push("1Star")
        cardCounts.Push(found1Star)
    }
    if (foundGimmighoul > 0) {
        cardTypes.Push("Gimmighoul")
        cardCounts.Push(foundGimmighoul)
    }
    if (foundCrown > 0) {
        cardTypes.Push("Crown")
        cardCounts.Push(foundCrown)
    }
    if (foundImmersive > 0) {
        cardTypes.Push("Immersive")
        cardCounts.Push(foundImmersive)
    }
    if (foundShiny1Star > 0) {
        cardTypes.Push("Shiny1Star")
        cardCounts.Push(foundShiny1Star)
    }
    if (foundShiny2Star > 0) {
        cardTypes.Push("Shiny2Star")
        cardCounts.Push(foundShiny2Star)
    }
    if (foundTrainer > 0) {
        cardTypes.Push("Trainer")
        cardCounts.Push(foundTrainer)
    }
    if (foundRainbow > 0) {
        cardTypes.Push("Rainbow")
        cardCounts.Push(foundRainbow)
    }
    if (foundFullArt > 0) {
        cardTypes.Push("FullArt")
        cardCounts.Push(foundFullArt)
    }

    deviceAccount := GetDeviceAccountFromXML()

    savedXmlPath := ""

    if (!loadDir) {
        ; Create Bots mode: Check if XML already exists for this deviceAccount to prevent duplicates
        if (deviceAccountXmlMap.HasKey(deviceAccount) && FileExist(deviceAccountXmlMap[deviceAccount])) {
            savedXmlPath := deviceAccountXmlMap[deviceAccount]
            UpdateSavedXml(savedXmlPath)

            ; Update accountFileName from saved path
            SplitPath, savedXmlPath, xmlFileName
            accountFileName := xmlFileName
        } else {
            ; Create new XML only if one doesn't exist
            saveAccount("All", savedXmlPath)

            ; Extract filename and update accountFileName
            if (savedXmlPath) {
                SplitPath, savedXmlPath, xmlFileName
                accountFileName := xmlFileName

                ; Store mapping for future reference
                deviceAccountXmlMap[deviceAccount] := savedXmlPath
            }
        }

        tradeableData := {}
        tradeableData.xmlPath := savedXmlPath
        tradeableData.deviceAccount := deviceAccount
        s4tPendingTradeables.Push(tradeableData)
    } else {
        ; Inject mode: Use the current accountFileName (which may have new name due to pack count)
        ; and construct the full path from it
        saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
        savedXmlPath := saveDir . "\" . accountFileName

        ; Verify the file exists at this path
        if (!FileExist(savedXmlPath)) {
            ; If the direct path doesn't work, search for it by the timestamp portion
            ; Extract timestamp from filename between first and last underscore

            if (InStr(accountFileName, "_")) {
                parts := StrSplit(accountFileName, "_")
                if (parts.Length() >= 2) {
                    ; parts[1] = pack count (e.g., "91P")
                    ; parts[2] = timestamp (e.g., "20250101120000")
                    timestampPattern := parts[2]

                    ; Search the directory for files containing this timestamp
                    Loop, Files, %saveDir%\*%timestampPattern%*.xml
                    {
                        savedXmlPath := A_LoopFileFullPath
                        accountFileName := A_LoopFileName
                        break  ; Use the first match
                    }
                }
            }
        }

        ; verification
        if (!FileExist(savedXmlPath)) {
            CreateStatusMessage("Warning: Could not find account XML file for attachment", "", 0, 0, false)
            LogToFile("FoundTradeable: Could not find XML file. accountFileName=" . accountFileName . ", savedXmlPath=" . savedXmlPath, "S4T.txt")
            savedXmlPath := ""  ; Clear it so we don't try to attach a non-existent file
        }
    }

    screenShot := Screenshot("Tradeable", "Trades", screenShotFileName)

    ; Extract just the filename from the full path for database logging
    SplitPath, screenShot, screenShotFileNameOnly

    LogToTradesDatabase(deviceAccount, cardTypes, cardCounts, screenShotFileNameOnly)

    statusMessage := "Tradeable cards found"

    CreateStatusMessage("Tradeable cards found! Logged to database and continuing...",,,, false)

    logMessage := statusMessage . " in instance: " . scriptName . " (" . packsInPool . " packs, " . openPack . ") Logged to Trades Database. Screenshot file: " . screenShotFileName
    LogToFile(logMessage, "S4T.txt")

    if (!s4tSilent && s4tDiscordWebhookURL) {
        packDetailsMessage := ""
        
        ; Report ALL detected card types and their positions, regardless of s4t settings
        if (found3Dmnd > 0)
            packDetailsMessage .= "Three Diamond (x" . found3Dmnd . ") [" . JoinCardPositions(cardPositions.3Diamond) . "], "
        if (found1Star > 0)
            packDetailsMessage .= "One Star (x" . found1Star . ") [" . JoinCardPositions(cardPositions.1Star) . "], "
        if (foundGimmighoul > 0)
            packDetailsMessage .= "Gimmighoul (x" . foundGimmighoul . ") [" . JoinCardPositions(cardPositions.Gimmighoul) . "], "
        if (foundCrown > 0)
            packDetailsMessage .= "Crown (x" . foundCrown . ") [" . JoinCardPositions(cardPositions.Crown) . "], "
        if (foundImmersive > 0)
            packDetailsMessage .= "Immersive (x" . foundImmersive . ") [" . JoinCardPositions(cardPositions.Immersive) . "], "
        if (foundShiny1Star > 0)
            packDetailsMessage .= "Shiny 1-Star (x" . foundShiny1Star . ") [" . JoinCardPositions(cardPositions.Shiny1Star) . "], "
        if (foundShiny2Star > 0)
            packDetailsMessage .= "Shiny 2-Star (x" . foundShiny2Star . ") [" . JoinCardPositions(cardPositions.Shiny2Star) . "], "
        if (foundTrainer > 0)
            packDetailsMessage .= "Trainer (x" . foundTrainer . ") [" . JoinCardPositions(cardPositions.Trainer) . "], "
        if (foundRainbow > 0)
            packDetailsMessage .= "Rainbow (x" . foundRainbow . ") [" . JoinCardPositions(cardPositions.Rainbow) . "], "
        if (foundFullArt > 0)
            packDetailsMessage .= "Full Art (x" . foundFullArt . ") [" . JoinCardPositions(cardPositions.FullArt) . "], "
        if (foundNormal > 0)
            packDetailsMessage .= "Normal (x" . foundNormal . ") [" . JoinCardPositions(cardPositions.Normal) . "], "

        ; Note: Four Diamond is NOT reported - you can deduce it by which slots have no border detected

        packDetailsMessage := RTrim(packDetailsMessage, ", ")

        discordMessage := statusMessage . " in instance: " . scriptName . " (" . packsInPool . " packs, " . openPack . ")\nFound: " . packDetailsMessage . "\nFile name: " . accountFileName . "\nLogged to Trades Database and continuing..."

        ; Prepare XML file path for attachment
        xmlFileToSend := ""
        ; NOW savedXmlPath will have the correct path with the updated filename!
        if (s4tSendAccountXml && savedXmlPath && FileExist(savedXmlPath)) {
            xmlFileToSend := savedXmlPath
        }

        LogToDiscord(discordMessage, screenShot, true, xmlFileToSend,, s4tDiscordWebhookURL, s4tDiscordUserId)
    }
    return
}

;-------------------------------------------------------------------------------
; FindBordersWithPositions - Find card borders and return their positions
;-------------------------------------------------------------------------------
FindBordersWithPositions(prefix) {
    global currentPackIs6Card, currentPackIs4Card, scaleParam, winTitle, defaultLanguage
    positions := []
    searchVariation := 40
    if (prefix = "normal") {
        searchVariation := 75 ; Increasing for megas patch...
    }
    searchVariation6Card := 60 ; looser tolerance for 6-card positions while we test if top row needles can be re-used for bottom row in 6-card packs
    searchVariation4Card := 60

    if (prefix = "shiny2star") { ; some aren't being detected at lower variations
        searchVariation := 75
        searchVariation6Card := 75
        searchVariation4Card := 75
    }

    is6CardPack := currentPackIs6Card
    is4CardPack := currentPackIs4Card

    if (is4CardPack) {
        borderCoords := [[96, 284, 123, 286]  ; Card 1
            ,[181, 284, 208, 286] ; Card 2
            ,[96, 399, 123, 401] ; Card 3
            ,[181, 399, 208, 401]] ; Card 4
    } else if (is6CardPack) {
        borderCoords := [[56, 284, 83, 286]   ; Top row card 1
            ,[139, 284, 166, 286] ; Top row card 2
            ,[222, 284, 249, 286] ; Top row card 3
            ,[56, 399, 83, 401]   ; Bottom row card 1
            ,[139, 399, 166, 401] ; Bottom row card 2
            ,[256, 386, 260, 402]] ; Bottom row card 3
    } else {
        ; 5-card pack
        borderCoords := [[56, 284, 83, 286] ; Card 1
            ,[139, 284, 166, 286] ; Card 2
            ,[222, 284, 249, 286] ; Card 3
            ,[96, 399, 123, 401] ; Card 4
            ,[181, 399, 208, 401]] ; Card 5
    }

    ; custom smaller borders for Megas splash art compatiblity; currently removing 6 pixels in x from the right side.
    if (prefix = "fullArt") {
        if (is4CardPack) {
            borderCoords := [[96, 284, 117, 286]  ; Card 1
                ,[181, 284, 202, 286] ; Card 2
                ,[96, 399, 117, 401] ; Card 3
                ,[181, 399, 202, 401]] ; Card 4
        } else if (is6CardPack) {
            borderCoords := [[56, 284, 77, 286]   ; Top row card 1
                ,[139, 284, 160, 286] ; Top row card 2
                ,[222, 284, 243, 286] ; Top row card 3
                ,[56, 399, 77, 401]   ; Bottom row card 1
                ,[139, 399, 160, 401] ; Bottom row card 2
                ,[256, 386, 254, 402]] ; Bottom row card 3
        } else {
            borderCoords := [[56, 284, 77, 286] ; Card 1
                ,[139, 284, 160, 286] ; Card 2
                ,[222, 284, 243, 286] ; Card 3
                ,[96, 399, 117, 401] ; Card 4
                ,[181, 399, 202, 401]] ; Card 5
        }
    }

    ; Changed Shiny 2star needles to improve detection after hours of testing previous needles.
    if (prefix = "shiny2star") {
        if (is4CardPack) {
            borderCoords := [[110, 175, 140, 187]    ; Top row card 1
                ,[192, 175, 223, 187]                ; Top row card 2
                ,[110, 293, 140, 305]                ; Bottom row card 1
                ,[192, 293, 223, 305]]               ; Bottom row card 2
        } else if (is6CardPack) {
            borderCoords := [[74, 175, 97, 187]
                ,[153, 175, 180, 187]
                ,[237, 175, 262, 187]
                ,[74, 293, 97, 305]
                ,[153, 293, 180, 305]
                ,[255, 385, 257, 399]]
        } else {
            borderCoords := [[74, 175, 97, 187]
                ,[153, 175, 180, 187]
                ,[237, 175, 262, 187]
                ,[110, 293, 140, 305]
                ,[192, 293, 223, 305]]
        }
    }

    if (prefix = "shiny1star") {
        if (is6CardPack) {
            borderCoords := [[90, 261, 93, 283]
                ,[173, 261, 176, 283]
                ,[255, 261, 258, 283]
                ,[90, 376, 93, 398]
                ,[173, 376, 176, 398]
                ,[255, 385, 257, 399]]
        } else {
            borderCoords := [[90, 261, 93, 283]
                ,[173, 261, 176, 283]
                ,[255, 261, 258, 283]
                ,[130, 376, 133, 398]
                ,[215, 376, 218, 398]]
        }
    }

    ; 100% scale adjustments
    if (scaleParam = 287) {
        if (prefix = "shiny1star" || prefix = "shiny2star") {
            if (is6CardPack) {
                borderCoords := [[91, 253, 95, 278]
                    ,[175, 253, 179, 278]
                    ,[259, 253, 263, 278]
                    ,[91, 370, 95, 395]
                    ,[175, 371, 179, 394]
                    ,[259, 371, 263, 394]]
            } else {
                borderCoords := [[91, 253, 95, 278]
                    ,[175, 253, 179, 278]
                    ,[259, 253, 263, 278]
                    ,[132, 370, 136, 395]
                    ,[218, 371, 222, 394]]
            }
        } else {
            if (is6CardPack) {
                borderCoords := [[55, 278, 84, 280]     ; Card 1
                    ,[139, 278, 168, 280]                ; Card 2
                    ,[223, 278, 252, 280]                ; Card 3
                    ,[55, 395, 84, 397]                  ; Card 4
                    ,[139, 395, 168, 397]                ; Card 5
                    ,[223, 395, 252, 397]]               ; Card 6
            } else {
                borderCoords := [[55, 278, 84, 280]     ; Card 1
                    ,[139, 278, 168, 280]                ; Card 2
                    ,[223, 278, 252, 280]                ; Card 3
                    ,[96, 395, 125, 397]                 ; Card 4
                    ,[182, 395, 211, 397]]               ; Card 5
            }
        }
    }

    pBitmap := from_window(WinExist(winTitle))
    for index, value in borderCoords {
        coords := borderCoords[A_Index]
        imageName := "" ; prevents accidentally reusing previously loaded imageName if imageName is undefined in custom one-off needles
        currentSearchVariation := searchVariation

        if (is6CardPack && A_Index >= 4) {
            ; Bottom row of 6-card pack (positions 4, 5, 6)
            if (A_Index = 6 && prefix = "shiny1star" || prefix = "shiny2star") {
                ; Use dedicated shiny1star6 needle for 6th card position
                imageName := prefix . "6card6"
            } else if (A_index = 4 && prefix = "normal" || prefix = "3diamond") {
                ; Use dedicated normal4 needle for 4th card position
                imageName := prefix . "6card4"
            } else if (A_Index = 5 && prefix = "normal" || prefix = "3diamond") {
                ; Use dedicated normal5 needle for 5th card position
                imageName := prefix . "6card5"
            } else {
                ; Re-use top row images for positions 4 and 5
                imageIndex := A_Index - 3  ; Card 4 -> uses Card 1 needle, 5->2
                imageName := prefix . imageIndex
            }
            currentSearchVariation := searchVariation6Card
        } else if (is4CardPack) {
            ; 4-card pack (Deluxe) - special needle logic
            if (A_Index <= 2) {
                ; Slots 1 and 2 - try deluxe-specific needle first, fall back to regular
                deluxeImageName := "deluxe" . prefix . A_Index
                regularImageName := prefix . A_Index

                ; Check if deluxe-specific needle exists
                deluxePath := A_ScriptDir . "\" . defaultLanguage . "\" . deluxeImageName . ".png"
                if (FileExist(deluxePath)) {
                    imageName := deluxeImageName
                } else {
                    imageName := regularImageName
                }
            } else {
                ; Slots 3 and 4 - reuse needles from regular 5-card pack slots 4 and 5
                ; Deluxe slot 3 (A_Index=3) uses regular slot 4 needle
                ; Deluxe slot 4 (A_Index=4) uses regular slot 5 needle
                imageName := prefix . (A_Index + 1)
            }
            currentSearchVariation := searchVariation4Card
        } else {
            ; Top row of 6-card pack, or any position in 5-card pack, use the 'real' needles
            imageName := prefix . A_Index
            currentSearchVariation := searchVariation
        }

        Path := A_ScriptDir . "\" . defaultLanguage . "\" . imageName . ".png"
        if (FileExist(Path)) {
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coords[1], coords[2], coords[3], coords[4], currentSearchVariation)
            if (vRet = 1) {
                positions.Push(A_Index)
            }
        } else {
            ; Fallback: if dedicated shiny1star6 needle doesn't exist, try alternative needles
            if (prefix = "shiny1star" && A_Index = 6) {
                ; Try shiny1star1 and shiny1star2 as fallbacks for card 6
                for fallbackIndex in [1, 2] {
                    fallbackName := prefix . fallbackIndex
                    fallbackPath := A_ScriptDir . "\" . defaultLanguage . "\" . fallbackName . ".png"
                    if (FileExist(fallbackPath)) {
                        pNeedle := GetNeedle(fallbackPath)
                        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coords[1], coords[2], coords[3], coords[4], currentSearchVariation)
                        if (vRet = 1) {
                            positions.Push(A_Index)
                            break  ; Found a match, no need to try other fallbacks
                        }
                    }
                }
            }
        }
    }
    Gdip_DisposeImage(pBitmap)
    return positions
}

;-------------------------------------------------------------------------------
; JoinCardPositions - Format card positions for display
;-------------------------------------------------------------------------------
JoinCardPositions(positions) {
    if (positions.Length() = 0) {
        return ""
    }
    result := ""
    for index, pos in positions {
        if (index > 1) {
            result .= ", "
        }
        result .= "Slot " . pos
    }
    return result
}

;-------------------------------------------------------------------------------
; ProcessPendingTradeables - Update all pending tradeable XMLs
;-------------------------------------------------------------------------------
ProcessPendingTradeables() {
    global s4tPendingTradeables

    if (s4tPendingTradeables.Length() = 0)
        return

    ; Update each saved XML with final account state
    for index, data in s4tPendingTradeables {
        if (data.xmlPath && FileExist(data.xmlPath)) {
            UpdateSavedXml(data.xmlPath)
        }
    }

    s4tPendingTradeables := []
}
