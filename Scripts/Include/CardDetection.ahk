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
;
; Dependencies: GDIP, Database.ahk, AccountManager.ahk
; Used by: Pack opening and evaluation flow in main bot
;===============================================================================

;-------------------------------------------------------------------------------
; DetectSixCardPack - Detect if current pack is a 6-card pack
;-------------------------------------------------------------------------------
DetectSixCardPack() {
    global session

    searchVariation := 5 ; needed to tighten from 20 to avoid false positives

    imagePath := A_ScriptDir . "\Needles\"

    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))

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
    global session
    if (session.get("openPack") = "Deluxe") {
        return true
    }
    return false
}

CheckCardLoading(totalCardsInPack){
    global session

    count := 0
    if (totalCardsInPack = 4) {
        borderCoords := [[96, 279, 116, 281]  ; Card 1
            ,[181, 279, 201, 281] ; Card 2
            ,[96, 394, 116, 396] ; Card 3
            ,[181, 394, 201, 396]] ; Card 4
    } else if (totalCardsInPack = 6) {
        totalCardsInPack := 6
        borderCoords := [[56, 279, 76, 281]   ; Top row card 1
            ,[139, 279, 159, 281] ; Top row card 2
            ,[222, 279, 242, 281] ; Top row card 3
            ,[56, 394, 76, 396]   ; Bottom row card 1
            ,[139, 394, 159, 396] ; Bottom row card 2
            ,[222, 394, 242, 396]] ; Bottom row card 3
    } else {
        ; 5-card pack
        borderCoords := [[56, 279, 76, 281] ; Card 1
            ,[139, 279, 159, 281] ; Card 2
            ,[222, 279, 242, 281] ; Card 3
            ,[96, 394, 116, 396] ; Card 4
            ,[181, 394, 201, 396]] ; Card 5
    }

    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    for index, value in borderCoords {
        coords := borderCoords[A_Index]
        imageName := "lag" . A_Index

        Path := A_ScriptDir . "\Needles\" . imageName . ".png"
        if (FileExist(Path)) {
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coords[1], coords[2], coords[3], coords[4], 40)
            if (vRet = 1) {
                count += 1
            }
        }
    }

    Gdip_DisposeImage(pBitmap)
    return count
}

;-------------------------------------------------------------------------------
; AnalysisBorder - Find card borders of specific type in pack
;-------------------------------------------------------------------------------
AnalysisBorder(totalCardsInPack) {
    global session, isDevelopment, rarityCheckers

    currentPackInfo := {"isVerified": false, "CardSlot": [], "TypeCount": {}}
    loadingBorderCoords := [[121, 269, 154, 272], [121, 297, 154, 300]]
    pBitmap := 0
    Loop, {
        pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
        Path := A_ScriptDir . "\Needles\LoadingBox.png"
        if (FileExist(Path)) {
            pNeedle := GetNeedle(Path)
            vRet1 := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, loadingBorderCoords[1][1], loadingBorderCoords[1][2], loadingBorderCoords[1][3], loadingBorderCoords[1][4], 20)
            vRet2 := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, loadingBorderCoords[2][1], loadingBorderCoords[2][2], loadingBorderCoords[2][3], loadingBorderCoords[2][4], 20)
            isExistLoadingBox := vRet1 | vRet2

            if(isExistLoadingBox = 0){
                if(isDevelopment){
                    getDevelopmentScreenShot(totalCardsInPack, pBitmap)
                }
                break
            }
            Sleep, 100
        }
    }

    Loop, % totalCardsInPack {
        cardIndex := A_Index
        if(currentPackInfo["CardSlot"][cardIndex] != "")
            continue

        cardRarityName := ""
        for index, Checker in rarityCheckers {
            cardRarityName := Checker.RarityName

            isFound := Checker.Search(pBitmap, totalCardsInPack, cardIndex)
            ;if(cardRarityName = "fullart")
                ;LogToFile(A_ScriptName . " Fullart check - Pos: " . cardIndex . ", Found: " . isFound, "Development.txt")
            
            if (isFound) {
                if(currentPackInfo["TypeCount"][cardRarityName] = "")
                    currentPackInfo["TypeCount"][cardRarityName] := 0

                currentPackInfo["CardSlot"][cardIndex] := cardRarityName
                currentPackInfo["TypeCount"][cardRarityName] := (currentPackInfo["TypeCount"].HasKey(cardRarityName) ? currentPackInfo["TypeCount"][cardRarityName] : 0) + 1
                break
            }
        }
    }

    For idx, Checker in rarityCheckers {
        rarityName := Checker.RarityName
        if(!currentPackInfo["TypeCount"].HasKey(rarityName) || currentPackInfo["TypeCount"][rarityName] == "")
            currentPackInfo["TypeCount"][rarityName] := 0
    }

    Gdip_DisposeImage(pBitmap)
    currentPackInfo["isVerified"] := true
    return currentPackInfo
}

;-------------------------------------------------------------------------------
; FindCard - Find specific card in opened pack
;-------------------------------------------------------------------------------
FindCard(prefix) {
    global session

    count := 0
    searchVariation := 40
    borderCoords := [[23, 191, 76, 193]
        ,[106, 191, 159, 193]
        ,[189, 191, 242, 193]
        ,[63, 306, 116, 308]
        ,[146, 306, 199, 308]]
    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    for index, value in borderCoords {
        coords := borderCoords[A_Index]
        Path = %A_ScriptDir%\Needles\%prefix%%A_Index%.png
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
    global botConfig, session

    currentPackInfo := session.get("currentPackInfo")
    ; Check for normal borders.
    normalBorders := currentPackInfo["TypeCount"]["normal"]
    if (normalBorders) {
        CreateStatusMessage("Not a God Pack...",,,, false)
        return false
    }

    ; A god pack (although possibly invalid) has been found.
    session.set("keepAccount", true)

    ; Determine the required minimum stars based on pack type.
    requiredStars := botConfig.get("minStars") ; Default to general minStars

    ; Check if pack meets minimum stars requirement
    if (!invalidPack) {
        ; Calculate tempStarCount by counting only valid 2-star cards for minimum check
        tempStarCount := currentPackInfo["TypeCount"]["fullart"] + currentPackInfo["TypeCount"]["rainbow"] + currentPackInfo["TypeCount"]["trainer"]

        if (requiredStars > 0 && tempStarCount < requiredStars) {
            CreateStatusMessage("Pack doesn't contain enough 2 stars...",,,, false)
            invalidPack := true
        }
    }

    if (invalidPack) {
        GodPackFound("Invalid")
        RemoveFriends()
        IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    } else {
        GodPackFound("Valid")
    }

    return session.get("keepAccount")
}

;-------------------------------------------------------------------------------
; FoundStars - Process found star/special cards
;-------------------------------------------------------------------------------
FoundStars(star) {
    global botConfig, session, DeadCheck

    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    session.set("keepAccount", true)

    screenShot := Screenshot(star)
    accountFullPath := ""
    username := ""

    accountFile := saveAccount(star, accountFullPath, "")
    friendCode := getFriendCode()
    session.set("friendCode", friendCode)

    Sleep, 5000
    fcScreenshot := Screenshot("FRIENDCODE")

    tempDir := A_ScriptDir . "\..\Screenshots\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    usernameScreenshotFile := tempDir . "\" . session.get("scriptName") . "_Username.png"
    adbTakeScreenshot(usernameScreenshotFile)
    Sleep, 100

    if(star = "Crown" || star = "Immersive" || star = "Shiny")
        RemoveFriends()
    else {
        ; OCR username
        try {
            if (IsFunc("ocr")) {
                playerName := ""
                allowedUsernameChars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-+_"
                usernamePattern := "[\w-_]+"

                if(RefinedOCRText(usernameScreenshotFile, 145, 235, 250, 35, allowedUsernameChars, usernamePattern, playerName)) {
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

    CreateStatusMessage(star . " found!",,,, false)

    statusMessage := star . " found"
    if (username && username != "Unknown")
        statusMessage .= " by " . username
    if (friendCode && friendCode != "Unknown")
        statusMessage .= " (" . friendCode . ")"

    logMessage := statusMessage . " in instance: " . session.get("scriptName")
    logMessage .= " (" . session.get("packsInPool") . " packs, " . session.get("openPack") . ")\n"
    logMessage .= "File name: " . accountFile . "\nBacking up to the Accounts\\SpecificCards folder and continuing..."
    LogToDiscord(logMessage, screenShot, true, (botConfig.get("sendAccountXml") ? accountFullPath : ""), fcScreenshot)
    LogToFile(StrReplace(logMessage, "\n", " "), "GPlog.txt")
}

;-------------------------------------------------------------------------------
; GodPackFound - Process found god pack
;-------------------------------------------------------------------------------
GodPackFound(validity) {
    global botConfig, session, DeadCheck

    currentPackInfo := session.get("currentPackInfo")
    username := ""

    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck

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

    starCount := currentPackInfo["TypeCount"]["fullart"] + currentPackInfo["TypeCount"]["rainbow"] + currentPackInfo["TypeCount"]["trainer"]

    screenShot := Screenshot(validity)
    accountFullPath := ""

    accountFile := saveAccount(validity, accountFullPath, "")

    friendCode := getFriendCode()
    session.set("friendCode", friendCode)

    Sleep, 5000
    fcScreenshot := Screenshot("FRIENDCODE")

    tempDir := A_ScriptDir . "\..\Screenshots\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    usernameScreenshotFile := tempDir . "\" . session.get("scriptName") . "_Username.png"
    adbTakeScreenshot(usernameScreenshotFile)
    Sleep, 100

    try {
        if (IsFunc("ocr")) {
            playerName := ""
            allowedUsernameChars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-+_"
            usernamePattern := "[\w-_]+"

            if(RefinedOCRText(usernameScreenshotFile, 145, 235, 250, 35, allowedUsernameChars, usernamePattern, playerName)) {
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

    CreateStatusMessage(Interjection . (invalid ? " " . invalid : "") . " God Pack found!",,,, false)

    logMessage := Interjection . "\n"
    if (username && username != "Unknown")
        logMessage .= username
    if (friendCode && friendCode != "Unknown")
        logMessage .= " (" . friendCode . ")"
    logMessage .= "\n[" . starCount . "/5][" . session.get("packsInPool") . "P][" . session.get("openPack") . "] "
    logMessage .= invalid . " God Pack found in instance: " . session.get("scriptName") . "\nFile name: " . accountFile . "\nBacking up to the Accounts\\GodPacks folder and continuing..."

    LogToFile(StrReplace(logMessage, "\n", " "), "GPlog.txt")

    if (validity = "Valid") {
        LogToDiscord(logMessage, screenShot, true, (botConfig.get("sendAccountXml") ? accountFullPath : ""), fcScreenshot)
    } else if (!botConfig.get("InvalidCheck")) {
        LogToDiscord(logMessage, screenShot, true, (botConfig.get("sendAccountXml") ? accountFullPath : ""))
    }
}

;-------------------------------------------------------------------------------
; FoundTradeable - Process found tradeable cards
;-------------------------------------------------------------------------------
FoundTradeable(found3Dmnd := 0, found4Dmnd := 0, found1Star := 0, foundGimmighoul := 0, foundCrown := 0, foundImmersive := 0, foundShiny1Star := 0, foundShiny2Star := 0, foundTrainer := 0, foundRainbow := 0, foundFullArt := 0) {
    global botConfig, session
    global screenShotFileName

    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck

    session.set("keepAccount", true)

    foundTradeable := found3Dmnd + found4Dmnd + found1Star + foundGimmighoul + foundCrown + foundImmersive + foundShiny1Star + foundShiny2Star + foundTrainer + foundRainbow + foundFullArt

    if (botConfig.get("s4tWP") && botConfig.get("s4tWPMinCards") = 2 && foundTradeable < 2) {
        CreateStatusMessage("s4t: insufficient cards (" . foundTradeable . "/2)",,,, false)
        session.set("keepAccount", false)
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

    if (!session.get("loadDir")) {
        ; Create Bots mode: Check if XML already exists for this deviceAccount to prevent duplicates
        if (session.get("deviceAccountXmlMap").HasKey(deviceAccount) && FileExist(session.get("deviceAccountXmlMap")[deviceAccount])) {
            savedXmlPath := session.get("deviceAccountXmlMap")[deviceAccount]
            UpdateSavedXml(savedXmlPath)

            ; Update accountFileName from saved path
            SplitPath, savedXmlPath, xmlFileName
            session.set("accountFileName", xmlFileName)
        } else {
            ; Create new XML only if one doesn't exist
            saveAccount("All", savedXmlPath)

            ; Extract filename and update accountFileName
            if (savedXmlPath) {
                SplitPath, savedXmlPath, xmlFileName
                session.set("accountFileName", xmlFileName)

                ; Store mapping for future reference
                session.get("deviceAccountXmlMap")[deviceAccount] := savedXmlPath
            }
        }

        tradeableData := {}
        tradeableData.xmlPath := savedXmlPath
        tradeableData.deviceAccount := deviceAccount
        session.get("s4tPendingTradeables").Push(tradeableData)
    } else {
        ; Inject mode: Use the current accountFileName (which may have new name due to pack count)
        ; and construct the full path from it
        saveDir := A_ScriptDir "\..\Accounts\Saved\" . session.get("scriptName")
        savedXmlPath := saveDir . "\" . session.get("accountFileName")

        ; Verify the file exists at this path
        if (!FileExist(savedXmlPath)) {
            ; If the direct path doesn't work, search for it by the timestamp portion
            ; Extract timestamp from filename between first and last underscore

            if (InStr(session.get("accountFileName"), "_")) {
                parts := StrSplit(session.get("accountFileName"), "_")
                if (parts.Length() >= 2) {
                    ; parts[1] = pack count (e.g., "91P")
                    ; parts[2] = timestamp (e.g., "20250101120000")
                    timestampPattern := parts[2]

                    ; Search the directory for files containing this timestamp
                    Loop, Files, %saveDir%\*%timestampPattern%*.xml
                    {
                        savedXmlPath := A_LoopFileFullPath
                        session.set("accountFileName", A_LoopFileName)
                        break  ; Use the first match
                    }
                }
            }
        }

        ; verification
        if (!FileExist(savedXmlPath)) {
            CreateStatusMessage("Warning: Could not find account XML file for attachment", "", 0, 0, false)
            LogToFile("FoundTradeable: Could not find XML file. accountFileName=" . session.get("accountFileName") . ", savedXmlPath=" . savedXmlPath, "S4T.txt")
            savedXmlPath := ""  ; Clear it so we don't try to attach a non-existent file
        }
    }

    screenShot := Screenshot("Tradeable", "Trades", screenShotFileName)

    LogToTradesDatabase(deviceAccount, cardTypes, cardCounts, screenShotFileName)

    statusMessage := "Tradeable cards found"

    CreateStatusMessage("Tradeable cards found! Logged to database and continuing...",,,, false)

    logMessage := statusMessage . " in instance: " . session.get("scriptName") . " (" . session.get("packsInPool") . " packs, " . session.get("openPack") . ") Logged to Trades Database. Screenshot file: " . screenShotFileName
    LogToFile(logMessage, "S4T.txt")

    if (!botConfig.get("s4tSilent") && botConfig.get("s4tDiscordWebhookURL")) {
        packDetailsMessage := ""
        if (found3Dmnd > 0)
            packDetailsMessage .= "Three Diamond (x" . found3Dmnd . "), "
        if (found4Dmnd > 0)
            packDetailsMessage .= "Four Diamond EX (x" . found4Dmnd . "), "
        if (found1Star > 0)
            packDetailsMessage .= "One Star (x" . found1Star . "), "
        if (foundGimmighoul > 0)
            packDetailsMessage .= "Gimmighoul (x" . foundGimmighoul . "), "
        if (foundCrown > 0)
            packDetailsMessage .= "Crown (x" . foundCrown . "), "
        if (foundImmersive > 0)
            packDetailsMessage .= "Immersive (x" . foundImmersive . "), "
        if (foundShiny1Star > 0)
            packDetailsMessage .= "Shiny 1-Star (x" . foundShiny1Star . "), "
        if (foundShiny2Star > 0)
            packDetailsMessage .= "Shiny 2-Star (x" . foundShiny2Star . "), "
        if (foundTrainer > 0)
            packDetailsMessage .= "Trainer (x" . foundTrainer . "), "
        if (foundRainbow > 0)
            packDetailsMessage .= "Rainbow (x" . foundRainbow . "), "
        if (foundFullArt > 0)
            packDetailsMessage .= "Full Art (x" . foundFullArt . "), "

        packDetailsMessage := RTrim(packDetailsMessage, ", ")

        discordMessage := statusMessage . " in instance: " . session.get("scriptName")
        discordMessage .= " (" . session.get("packsInPool") . " packs, " . session.get("openPack") . ")\n"
        discordMessage .= "Found: " . packDetailsMessage . "\n"
        discordMessage .= "Screenshot File name: " . session.get("accountFileName") . "\nLogged to Trades Database and continuing..."

        ; Prepare XML file path for attachment
        xmlFileToSend := ""
        ; NOW savedXmlPath will have the correct path with the updated filename!
        if (botConfig.get("s4tSendAccountXml") && savedXmlPath && FileExist(savedXmlPath)) {
            xmlFileToSend := savedXmlPath
        }

        LogToDiscord(discordMessage, screenShot, true, xmlFileToSend,, botConfig.get("s4tDiscordWebhookURL"), botConfig.get("s4tDiscordUserId"))
    }
    return
}

;-------------------------------------------------------------------------------
; ProcessPendingTradeables - Update all pending tradeable XMLs
;-------------------------------------------------------------------------------
ProcessPendingTradeables() {
    global session

    if (session.get("s4tPendingTradeables").Length() = 0)
        return

    ; Update each saved XML with final account state
    for index, data in session.get("s4tPendingTradeables") {
        if (data.xmlPath && FileExist(data.xmlPath)) {
            UpdateSavedXml(data.xmlPath)
        }
    }

    session.set("s4tPendingTradeables", [])
}
