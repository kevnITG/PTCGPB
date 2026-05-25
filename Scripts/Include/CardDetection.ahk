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
                    ;getDevelopmentScreenShot(totalCardsInPack, pBitmap)
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
FindGodPack(invalidPack := false, cards := "") {
    global botConfig, session

    currentPackInfo := session.get("currentPackInfo")

    ; Check for normal borders.
    normalBorders := currentPackInfo["TypeCount"]["normal"]
    if (normalBorders) {
        logMessage := "Instance: " . session.get("scriptName") " | Not a GP"
        LogDebug(logMessage, "debug_cards.txt")
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

        logMessage := "Instance: " . session.get("scriptName") " | tempStarCount " . tempStarCount
        LogDebug(logMessage, "debug_cards.txt")

        if (requiredStars > 0 && tempStarCount < requiredStars) {
            logMessage := "Instance: " . session.get("scriptName") " | passed check"
            LogDebug(logMessage, "debug_cards.txt")
            CreateStatusMessage("Pack doesn't contain enough 2 stars...",,,, false)
            invalidPack := true
        }
    }

    if (invalidPack) {
        GodPackFound("Invalid", cards)
        RemoveFriends()
        IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    } else {
        logMessage := "Instance: " . session.get("scriptName") " | passed check"
        LogDebug(logMessage, "debug_cards.txt")
        GodPackFound("Valid", cards)
    }

    return session.get("keepAccount")
}

;-------------------------------------------------------------------------------
; CardDetection_UseSavedAccountFriendInfo - Reuse metadata before opening Social
;-------------------------------------------------------------------------------
CardDetection_UseSavedAccountFriendInfo(ByRef username, ByRef friendCode) {
    global botConfig, session

    username := ""
    friendCode := ""

    if (botConfig.get("deleteMethod") != "Inject Wonderpick 96P+")
        return false
    if (!session.get("injectMethod") || !session.get("loadedAccount") || session.get("accountFileName") = "")
        return false

    accountMeta := AccountMetadata_Get(session.get("scriptName"), session.get("accountFileName"), session.get("loadedAccount"))
    savedFriendCode := RegExReplace(accountMeta["friendCode"], "\D", "")
    if (!RegExMatch(savedFriendCode, "^\d{16}$"))
        return false

    savedName := Trim(accountMeta["accountName"])
    if (savedName != "" && savedName != "Unknown")
        username := savedName

    friendCode := savedFriendCode
    session.set("friendCode", friendCode)
    if (username != "")
        session.set("accountName", username)

    CreateStatusMessage("Card notification`nUsing saved account info...",,,, false)
    return true
}

;-------------------------------------------------------------------------------
; FoundStars - Process found star/special cards
;-------------------------------------------------------------------------------
FoundStars(star, cards := "") {
    global botConfig, session, DeadCheck

    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    session.set("keepAccount", true)

    isWishlist := (star = "Wishlist")
    wishlistMatches := session.get("wishlistMatches")
    if (!IsObject(wishlistMatches))
        wishlistMatches := []

    ; Try synthetic image from card IDs, fallback to real screenshot
    isSyntheticGP := false
    screenShot := ""
    if (IsObject(cards) && cards.MaxIndex() > 0) {
        synthGPPath := ""
        highlightIds := isWishlist ? Wishlist_MatchIds(wishlistMatches) : ""
        if (GenerateSyntheticPackImage(cards, synthGPPath, highlightIds)) {
            persistedGPPath := PersistSyntheticScreenshot(synthGPPath, star)
            if (persistedGPPath != "") {
                screenShot := persistedGPPath
                if (FileExist(synthGPPath))
                    FileDelete, %synthGPPath%
            } else {
                screenShot := synthGPPath
            }
            isSyntheticGP := true
        }
    }
    if (!isSyntheticGP)
        screenShot := Screenshot(star)

    accountFullPath := ""
    username := ""

    accountFile := saveAccount(star, accountFullPath, "")
    fcScreenshot := ""
    usedSavedFriendInfo := CardDetection_UseSavedAccountFriendInfo(username, friendCode)
    if (!usedSavedFriendInfo) {
        friendCode := getFriendCode()
        session.set("friendCode", friendCode)

        Sleep, 5000
        fcScreenshot := Screenshot("FRIENDCODE")

        if(star = "Crown" || star = "Immersive" || star = "Shiny")
            RemoveFriends()
        else
            username := AccountFriendInfo_ReadNameFromFriendProfile("Card notification", 0)
    } else if(star = "Crown" || star = "Immersive" || star = "Shiny") {
        RemoveFriends()
    }

    ; Validate before saving metadata
    if (username = "" || !username)
        username := "Unknown"
    if (friendCode = "" || !friendCode)
        friendCode := "Unknown"

    CreateStatusMessage(star . " found!",,,, false)

    statusPrefix := isWishlist ? Chr(0x2B50) . " Wishlist match" : (star . " found")
    statusMessage := statusPrefix
    if (username && username != "Unknown")
        statusMessage .= " by " . username
    if (friendCode && friendCode != "Unknown")
        statusMessage .= " (" . friendCode . ")"

    logMessage := statusMessage . " in instance: " . session.get("scriptName")
    logMessage .= " (" . session.get("packsInPool") . " packs, " . session.get("openPack") . ")\n"
    if (isWishlist && wishlistMatches.MaxIndex() > 0)
        logMessage .= "Wishlist: " . Wishlist_FormatNames(wishlistMatches) . "\n"
    logMessage .= "File name: " . accountFile . "\nBacking up to the Accounts\\SpecificCards folder and continuing..."
    if (isWishlist) {
        mentionId := botConfig.get("discordUserId")
        if (mentionId = "")
            mentionId := session.get("discordUserId")
        if (mentionId != "")
            logMessage .= "\n<@" . mentionId . ">"
    }
    LogToDiscord(logMessage, screenShot, true, (DiscordShouldSendAccountXml() ? accountFullPath : ""), fcScreenshot)
    LogInfo(StrReplace(logMessage, "\n", " "), "GPlog.txt")
}

;-------------------------------------------------------------------------------
; GodPackFound - Process found god pack
;-------------------------------------------------------------------------------
GodPackFound(validity, cards := "", alreadyAtHome := false) {
    global botConfig, session, DeadCheck, dictionaryData

    currentPackInfo := session.get("currentPackInfo")
    username := ""
    session.set("manualVipValidity", validity)

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

    ; Try synthetic image from card IDs, fallback to real screenshot
    isSyntheticGP := false
    screenShot := ""
    if (IsObject(cards) && cards.MaxIndex() > 0) {
        synthGPPath := ""
        if (GenerateSyntheticPackImage(cards, synthGPPath)) {
            persistedGPPath := PersistSyntheticScreenshot(synthGPPath, validity)
            if (persistedGPPath != "") {
                screenShot := persistedGPPath
                if (FileExist(synthGPPath))
                    FileDelete, %synthGPPath%
            } else {
                screenShot := synthGPPath
            }
            isSyntheticGP := true
        }
    }
    if (!isSyntheticGP)
        screenShot := Screenshot(validity)
    accountFullPath := ""

    accountFile := saveAccount(validity, accountFullPath, "")

    fcScreenshot := ""
    if (!CardDetection_UseSavedAccountFriendInfo(username, friendCode)) {
        friendCode := getFriendCode(alreadyAtHome)
        session.set("friendCode", friendCode)

        Sleep, 5000
        fcScreenshot := Screenshot("FRIENDCODE")

        username := AccountFriendInfo_ReadNameFromFriendProfile("Card notification", 0)
    }

    ; Validate before saving
    if (username = "" || !username)
        username := "Unknown"
    if (friendCode = "" || !friendCode)
        friendCode := "Unknown"

    openPack := session.get("openPack")
    packDisplayName := ""
    try packDisplayName := dictionaryData[botConfig.get("defaultBotLanguage")][openPack]
    if (packDisplayName = "")
        packDisplayName := (openPack != "" ? openPack : "Unknown Pack")

    session.set("manualVipName", username)
    session.set("manualVipStarCount", starCount)

    CreateStatusMessage(Interjection . (invalid ? " " . invalid : "") . " God Pack found!",,,, false)

    logMessage := Interjection . "\n"
    if (username && username != "Unknown")
        logMessage .= username
    if (friendCode && friendCode != "Unknown")
        logMessage .= " (" . friendCode . ")"
    logMessage .= "\n[" . starCount . "/5][" . session.get("packsInPool") . "P][" . packDisplayName . "] "
    logMessage .= invalid . " God Pack found in instance: " . session.get("scriptName") . "\nFile name: " . accountFile . "\nBacking up to the Accounts\\GodPacks folder and continuing..."

    LogInfo(StrReplace(logMessage, "\n", " "), "GPlog.txt")

    if (validity = "Valid") {
        LogToDiscord(logMessage, screenShot, true, (DiscordShouldSendAccountXml() ? accountFullPath : ""), fcScreenshot)
    } else if (!botConfig.get("InvalidCheck")) {
        LogToDiscord(logMessage, screenShot, true, (DiscordShouldSendAccountXml() ? accountFullPath : ""))
    }
    ; Delete synthetic image after sending
    ; GP screenshots are always kept on disk, matching fallback persistence behavior.
}

PersistSyntheticScreenshot(sourcePath, fileType := "Valid", subDir := "") {
    global session

    if (!sourcePath || !FileExist(sourcePath))
        return ""

    fileDir := A_ScriptDir "\..\Screenshots"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%

    if (subDir) {
        fileDir .= "\\" . subDir
        if !FileExist(fileDir)
            FileCreateDir, %fileDir%
    }

    fileName := A_Now . "_" . session.get("scriptName") . "_" . fileType . "_" . session.get("packsInPool") . "_packs_synth.png"
    targetPath := fileDir "\\" . fileName

    FileCopy, %sourcePath%, %targetPath%, 1
    if (ErrorLevel)
        return ""

    return targetPath
}
;-------------------------------------------------------------------------------
; FoundTradeable - Process found tradeable cards
;-------------------------------------------------------------------------------
FoundTradeable(found3Dmnd := 0, found4Dmnd := 0, found1Star := 0, foundGimmighoul := 0, foundCrown := 0, foundImmersive := 0, foundShiny1Star := 0, foundShiny2Star := 0, foundTrainer := 0, foundRainbow := 0, foundFullArt := 0) {
    global botConfig, session, dictionaryData
    global screenShotFileName

    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck

    session.set("keepAccount", true)

    foundTradeable := found3Dmnd + found4Dmnd + found1Star + foundGimmighoul + foundCrown + foundImmersive + foundShiny1Star + foundShiny2Star + foundTrainer + foundRainbow + foundFullArt

    if (botConfig.get("s4tWP") && botConfig.get("s4tWPMinCards") = 2 && foundTradeable < 2) {
        CreateStatusMessage("s4t: insufficient cards (" . foundTradeable . "/2)",,,, false)
        session.set("keepAccount", false)
        return
    }
    session.set("s4tFoundTradeable", true)

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
            LogWarn("FoundTradeable: Could not find XML file. accountFileName=" . session.get("accountFileName") . ", savedXmlPath=" . savedXmlPath, "S4T.txt")
            savedXmlPath := ""  ; Clear it so we don't try to attach a non-existent file
        }
    }

    screenShot := Screenshot("Tradeable", "Trades", screenShotFileName)

    LogToTradesDatabase(deviceAccount, cardTypes, cardCounts, screenShotFileName)

    statusMessage := "Tradeable cards found"

    CreateStatusMessage("Tradeable cards found! Continuing...",,,, false)

    logMessage := statusMessage . " in instance: " . session.get("scriptName") . " (" . session.get("packsInPool") . " packs, " . dictionaryData[botConfig.get("defaultBotLanguage")][session.get("openPack")] . ") Screenshot file: " . screenShotFileName
    LogInfo(logMessage, "S4T.txt")

    if (!botConfig.get("s4tSilent") && botConfig.get("s4tDiscordWebhookURL")) {
        ; Legacy path has only count vars (no card IDs/rarity array). Reuse the
        ; shared builder via count-only fallback: Discord format stays consistent
        ; with the modern paths, just without per-card names.
        foundCards := { "3Diamond": found3Dmnd, "4Diamond": found4Dmnd, "1Star": found1Star
                      , "Crown": foundCrown, "Immersive": foundImmersive
                      , "Shiny1Star": foundShiny1Star, "Shiny2Star": foundShiny2Star
                      , "Trainer": foundTrainer, "Rainbow": foundRainbow, "FullArt": foundFullArt }
        packDetailsMessage := CardName_BuildFoundBlock("", "", foundCards)

        discordMessage := S4T_BuildDiscordHeader("Pack Opening results", session.get("scriptName"), session.get("packsInPool"), session.get("openPack"), Chr(0x1F4E6)) . "\n"
        if (packDetailsMessage != "")
            discordMessage .= "\n" . packDetailsMessage . "\n\n"
        discordMessage .= "File name: " . session.get("accountFileName")

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

CheckCardsSimple(result) {
    global botConfig, session

    cards := result.cards
    pack := result.pack
    rarity := result.rarity

    found1Dmnd       := CountOccurances(cards, rarity, 1)
    found2Dmnd       := CountOccurances(cards, rarity, 2)
    found3Dmnd       := CountOccurances(cards, rarity, 3)
    found4Dmnd       := CountOccurances(cards, rarity, 4)
    found1Star       := CountOccurances(cards, rarity, 7)
    foundTrainer     := CountOccurances(cards, rarity, 5, "TR_")
    foundFullArt     := CountOccurances(cards, rarity, 5, "PK_")
    foundRainbow     := CountOccurances(cards, rarity, 8)
    foundImmersive   := CountOccurances(cards, rarity, 9)
    foundCrown       := CountOccurances(cards, rarity, 10)
    foundShiny1Star  := CountOccurances(cards, rarity, 11)
    foundShiny2Star  := CountOccurances(cards, rarity, 12)

    Wishlist_EnsureFresh()
    wishlistMap      := session.get("wishlistMap")
    foundWishlist    := Wishlist_CountMatches(cards, wishlistMap)
    session.set("wishlistMatches", Wishlist_MatchEntries(cards, wishlistMap))

    tradeableList := []
    tradeableList.Push({key: "3Diamond",  flag: botConfig.get("s4t3Dmnd"),      count: found3Dmnd})
    tradeableList.Push({key: "4Diamond",  flag: botConfig.get("s4t4Dmnd"),      count: found4Dmnd})
    tradeableList.Push({key: "1Star",     flag: botConfig.get("s4t1Star"),      count: found1Star})
    tradeableList.Push({key: "Trainer",   flag: botConfig.get("s4tTrainer"),    count: foundTrainer})
    tradeableList.Push({key: "FullArt",   flag: botConfig.get("s4tFullArt"),    count: foundFullArt})
    tradeableList.Push({key: "Rainbow",   flag: botConfig.get("s4tRainbow"),    count: foundRainbow})
    tradeableList.Push({key: "Immersive", flag: botConfig.get("s4tImmersive"),  count: foundImmersive})
    tradeableList.Push({key: "Crown",     flag: botConfig.get("s4tCrown"),      count: foundCrown})
    tradeableList.Push({key: "Shiny1Star",flag: botConfig.get("s4tShiny1Star"), count: foundShiny1Star})
    tradeableList.Push({key: "Shiny2Star",flag: botConfig.get("s4tShiny2Star"), count: foundShiny2Star})
    tradeableList.Push({key: "Wishlist",  flag: botConfig.get("s4tWishlist"),   count: foundWishlist})

    foundCards := {}
    foundTradeable := 0
    for _, item in tradeableList {
        foundCards[item.key] := 0
        if (item.flag) {
            foundTradeable += item.count
            foundCards[item.key] := item.count
        }
    }

    if (foundTradeable > 0) {
        session.set("keepAccount", true)
        session.set("s4tFoundTradeable", true)

        scriptName := session.get("scriptName")
        winTitle := session.get("winTitle")
        packsInPool := session.get("packsInPool")
        openPack := session.get("openPack")
        loadDir := session.get("loadDir")
        accountFileName := session.get("accountFileName")

        order := ["1Diamond", "2Diamond", "3Diamond", "4Diamond", "1Star", "FullArt", "Rainbow", "Trainer", "Immersive", "Crown", "Shiny1Star", "Shiny2Star", "Wishlist"]
        out := ""
        for key, value in foundCards
            out .= key ": " value "`n"

        displayNames := {}
        displayNames["1Diamond"]   := "One Diamond"
        displayNames["2Diamond"]   := "Two Diamond"
        displayNames["3Diamond"]   := "Three Diamond"
        displayNames["4Diamond"]   := "Four Diamond EX"
        displayNames["1Star"]      := "One Star"
        displayNames["Crown"]      := "Crown"
        displayNames["Immersive"]  := "Immersive"
        displayNames["Shiny1Star"] := "Shiny 1-Star"
        displayNames["Shiny2Star"] := "Shiny 2-Star"
        displayNames["Trainer"]    := "Trainer"
        displayNames["Rainbow"]    := "Rainbow"
        displayNames["FullArt"]    := "Full Art"
        displayNames["Wishlist"]   := "Wishlist"

        foundTradeable := 0
        cardTypes := []
        cardCounts := []

        for _, type in order {
            count := foundCards.HasKey(type) ? foundCards[type] : 0
            foundTradeable += count

            if (count > 0) {
                cardTypes.Push(type)
                cardCounts.Push(count)
            }
        }

        ; Build the Discord rarity summary with per-rarity emoji + card names.
        ; CardName_BuildFoundBlock handles the cards/rarity-missing case gracefully.
        packDetailsMessage := CardName_BuildFoundBlock(cards, rarity, foundCards)
        deviceAccount := GetDeviceAccountFromXML()
        savedXmlPath := ""

        if (!loadDir) {
            if (session.get("deviceAccountXmlMap").HasKey(deviceAccount) && FileExist(session.get("deviceAccountXmlMap")[deviceAccount])) {
                savedXmlPath := session.get("deviceAccountXmlMap")[deviceAccount]
                UpdateSavedXml(savedXmlPath)

                SplitPath, savedXmlPath, xmlFileName
                accountFileName := xmlFileName
                session.set("accountFileName", accountFileName)
            } else {
                saveAccount("All", savedXmlPath)

                if (savedXmlPath) {
                    SplitPath, savedXmlPath, xmlFileName
                    accountFileName := xmlFileName
                    session.set("accountFileName", accountFileName)
                    session.get("deviceAccountXmlMap")[deviceAccount] := savedXmlPath
                }
            }

            tradeableData := {}
            tradeableData.xmlPath := savedXmlPath
            tradeableData.deviceAccount := deviceAccount
            session.get("s4tPendingTradeables").Push(tradeableData)
        } else {
            saveDir := A_ScriptDir "\..\Accounts\Saved\" . scriptName
            savedXmlPath := saveDir . "\" . accountFileName

            if (!FileExist(savedXmlPath)) {
                if (InStr(accountFileName, "_")) {
                    parts := StrSplit(accountFileName, "_")
                    if (parts.Length() >= 2) {
                        timestampPattern := parts[2]
                        Loop, Files, %saveDir%\*%timestampPattern%*.xml
                        {
                            savedXmlPath := A_LoopFileFullPath
                            accountFileName := A_LoopFileName
                            session.set("accountFileName", accountFileName)
                            break
                        }
                    }
                }
            }

            if (!FileExist(savedXmlPath)) {
                CreateStatusMessage("Warning: Could not find account XML file for attachment", "", 0, 0, false)
                LogWarn("FoundTradeable: Could not find XML file. accountFileName=" . accountFileName . ", savedXmlPath=" . savedXmlPath, "S4T.txt")
                savedXmlPath := ""
            }
        }

        statusMessage := "Giftpack cards found"
        wishlistMatches := session.get("wishlistMatches")
        if (!IsObject(wishlistMatches))
            wishlistMatches := []
        hasWishlist := botConfig.get("s4tWishlist") && wishlistMatches.MaxIndex() > 0
        ; Build filtered card list: only cards whose rarity is enabled in S4T settings
        filteredCards := FilterCardsByS4T(cards, rarity)
        ; Try to generate a synthetic image from card IDs
        synthScreenShot := ""
        if (filteredCards.MaxIndex() > 0) {
            highlightIds := hasWishlist ? Wishlist_MatchIds(wishlistMatches) : ""
            if (GenerateSyntheticPackImage(filteredCards, synthScreenShot, highlightIds, 6) && botConfig.get("s4tKeepSyntheticScreenshots")) {
                persistedGiftPath := PersistSyntheticScreenshot(synthScreenShot, "Tradeable", "Trades")
                if (persistedGiftPath != "") {
                    if (FileExist(synthScreenShot))
                        FileDelete, %synthScreenShot%
                    synthScreenShot := persistedGiftPath
                }
            }
        }

        if (!botConfig.get("s4tSilent") && botConfig.get("s4tDiscordWebhookURL")) {
            packName := (openPack != "") ? openPack : pack
            discordMessage := S4T_BuildDiscordHeader("Gift Pack Opening results", scriptName, packsInPool, packName, Chr(0x1F381)) . "\n"
            if (packDetailsMessage != "")
                discordMessage .= "\n" . packDetailsMessage . "\n\n"
            if (hasWishlist) {
                sparkle := Chr(0x2728)
                discordMessage .= sparkle . " WISHLIST: " . Wishlist_FormatNames(wishlistMatches) . " " . sparkle . "\n"
            }
            discordMessage .= "File name: " . accountFileName . "\n"

            xmlFileToSend := ""
            if (botConfig.get("s4tSendAccountXml") && savedXmlPath && FileExist(savedXmlPath))
                xmlFileToSend := savedXmlPath

            LogToDiscord(discordMessage, synthScreenShot, true, xmlFileToSend,, botConfig.get("s4tDiscordWebhookURL"), botConfig.get("s4tDiscordUserId"))
        }
        ; Delete synthetic image after sending
        if (synthScreenShot && !botConfig.get("s4tKeepSyntheticScreenshots") && FileExist(synthScreenShot))
            FileDelete, %synthScreenShot%
    }
}

FoundTradeableNew(foundCards, pack := "", cards := "", rarity := "", isTenPackOpening := false) {
    global botConfig, session
    global screenShotFileName

    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    session.set("keepAccount", true)

    scriptName := session.get("scriptName")
    winTitle := session.get("winTitle")
    packsInPool := session.get("packsInPool")
    openPack := session.get("openPack")
    loadDir := session.get("loadDir")
    accountFileName := session.get("accountFileName")

    order := ["1Diamond", "2Diamond", "3Diamond", "4Diamond", "1Star", "FullArt", "Rainbow", "Trainer", "Immersive", "Crown", "Shiny1Star", "Shiny2Star", "Wishlist"]
    out := ""
    for key, value in foundCards
        out .= key ": " value "`n"

    displayNames := {}
    displayNames["1Diamond"]   := "One Diamond"
    displayNames["2Diamond"]   := "Two Diamond"
    displayNames["3Diamond"]   := "Three Diamond"
    displayNames["4Diamond"]   := "Four Diamond EX"
    displayNames["1Star"]      := "One Star"
    displayNames["Crown"]      := "Crown"
    displayNames["Immersive"]  := "Immersive"
    displayNames["Shiny1Star"] := "Shiny 1-Star"
    displayNames["Shiny2Star"] := "Shiny 2-Star"
    displayNames["Trainer"]    := "Trainer"
    displayNames["Rainbow"]    := "Rainbow"
    displayNames["FullArt"]    := "Full Art"
    displayNames["Wishlist"]   := "Wishlist"

    foundTradeable := 0
    cardTypes := []
    cardCounts := []

    for _, type in order {
        count := foundCards.HasKey(type) ? foundCards[type] : 0
        foundTradeable += count

        if (count > 0) {
            cardTypes.Push(type)
            cardCounts.Push(count)
        }
    }

    ; Build the Discord rarity summary with per-rarity emoji + card names.
    ; CardName_BuildFoundBlock handles the cards/rarity-missing case gracefully.
    packDetailsMessage := CardName_BuildFoundBlock(cards, rarity, foundCards)

    if (botConfig.get("s4tWP") && botConfig.get("s4tWPMinCards") = 2 && foundTradeable < 2) {
        CreateStatusMessage("s4t: insufficient cards (" . foundTradeable . "/2)",,,, false)
        session.set("keepAccount", false)
        return
    }
    session.set("s4tFoundTradeable", true)

    deviceAccount := GetDeviceAccountFromXML()
    savedXmlPath := ""

    if (!loadDir) {
        if (session.get("deviceAccountXmlMap").HasKey(deviceAccount) && FileExist(session.get("deviceAccountXmlMap")[deviceAccount])) {
            savedXmlPath := session.get("deviceAccountXmlMap")[deviceAccount]
            UpdateSavedXml(savedXmlPath)

            SplitPath, savedXmlPath, xmlFileName
            accountFileName := xmlFileName
            session.set("accountFileName", accountFileName)
        } else {
            saveAccount("All", savedXmlPath)

            if (savedXmlPath) {
                SplitPath, savedXmlPath, xmlFileName
                accountFileName := xmlFileName
                session.set("accountFileName", accountFileName)
                session.get("deviceAccountXmlMap")[deviceAccount] := savedXmlPath
            }
        }

        tradeableData := {}
        tradeableData.xmlPath := savedXmlPath
        tradeableData.deviceAccount := deviceAccount
        session.get("s4tPendingTradeables").Push(tradeableData)
    } else {
        saveDir := A_ScriptDir "\..\Accounts\Saved\" . scriptName
        savedXmlPath := saveDir . "\" . accountFileName

        if (!FileExist(savedXmlPath)) {
            if (InStr(accountFileName, "_")) {
                parts := StrSplit(accountFileName, "_")
                if (parts.Length() >= 2) {
                    timestampPattern := parts[2]
                    Loop, Files, %saveDir%\*%timestampPattern%*.xml
                    {
                        savedXmlPath := A_LoopFileFullPath
                        accountFileName := A_LoopFileName
                        session.set("accountFileName", accountFileName)
                        break
                    }
                }
            }
        }

        if (!FileExist(savedXmlPath)) {
            CreateStatusMessage("Warning: Could not find account XML file for attachment", "", 0, 0, false)
            LogWarn("FoundTradeable: Could not find XML file. accountFileName=" . accountFileName . ", savedXmlPath=" . savedXmlPath, "S4T.txt")
            savedXmlPath := ""
        }
    }

    wishlistMatches := session.get("wishlistMatches")
    if (!IsObject(wishlistMatches))
        wishlistMatches := []
    hasWishlist := botConfig.get("s4tWishlist") && wishlistMatches.MaxIndex() > 0

    screenShotFileName := ""
    isSyntheticImage := false
    ; Try to generate a synthetic image from card IDs (avoids storing real screenshots on disk).
    ; Only multi-pull (10-pack) needs s4t filtering on the synth image — single-pull packs
    ; show all 5 cards regardless of rarity. The rarity array itself is always honored for
    ; the webhook name lookup (CardName_BuildFoundBlock).
    syntheticCards := (isTenPackOpening && IsObject(rarity)) ? FilterCardsByS4T(cards, rarity) : cards
    if (isTenPackOpening && IsObject(rarity) && (!IsObject(syntheticCards) || syntheticCards.MaxIndex() = "") && hasWishlist)
        syntheticCards := FilterCardsByWishlistMatches(cards, wishlistMatches)
    if (IsObject(syntheticCards) && syntheticCards.MaxIndex() > 0) {
        synthPath := ""
        highlightIds := hasWishlist ? Wishlist_MatchIds(wishlistMatches) : ""
        synthCols := isTenPackOpening ? 6 : 3
        if (GenerateSyntheticPackImage(syntheticCards, synthPath, highlightIds, synthCols)) {
            if (botConfig.get("s4tKeepSyntheticScreenshots")) {
                persistedTradePath := PersistSyntheticScreenshot(synthPath, "Tradeable", "Trades")
                if (persistedTradePath != "") {
                    if (FileExist(synthPath))
                        FileDelete, %synthPath%
                    synthPath := persistedTradePath
                }
            }

            screenShot := synthPath
            SplitPath, synthPath, screenShotFileName
            isSyntheticImage := true
        }
    }
    ; Fallback: real screenshot from emulator window
    if (!isSyntheticImage)
        screenShot := Screenshot("Tradeable", "Trades", screenShotFileName)

    LogToTradesDatabase(deviceAccount, cardTypes, cardCounts, screenShotFileName)

    statusMessage := isTenPackOpening ? "Tradeable cards found in 10-pack opening" : "Tradeable cards found"
    packName := (openPack != "") ? openPack : pack

    CreateStatusMessage(statusMessage . "! Continuing...",,,, false)

    logMessage := statusMessage . " in instance: " . scriptName . " (" . packsInPool . " packs, " . packName . ") Screenshot file: " . screenShotFileName
    LogInfo(logMessage, "S4T.txt")

    if (!botConfig.get("s4tSilent") && botConfig.get("s4tDiscordWebhookURL")) {
        headerTitle := isTenPackOpening ? "10-Packs Opening results" : "Pack Opening results"
        headerEmoji := Chr(0x1F4E6)
        discordMessage := S4T_BuildDiscordHeader(headerTitle, scriptName, packsInPool, packName, headerEmoji) . "\n"
        if (packDetailsMessage != "")
            discordMessage .= "\n" . packDetailsMessage . "\n\n"
        if (hasWishlist) {
            sparkle := Chr(0x2728)
            discordMessage .= sparkle . " WISHLIST: " . Wishlist_FormatNames(wishlistMatches) . " " . sparkle . "\n"
        }
        discordMessage .= "File name: " . accountFileName

        xmlFileToSend := ""
        if (botConfig.get("s4tSendAccountXml") && savedXmlPath && FileExist(savedXmlPath))
            xmlFileToSend := savedXmlPath

        LogToDiscord(discordMessage, screenShot, true, xmlFileToSend,, botConfig.get("s4tDiscordWebhookURL"), botConfig.get("s4tDiscordUserId"))
    }

    ; Delete synthetic image after sending (avoids accumulating screenshots on disk)
    if (isSyntheticImage && !botConfig.get("s4tKeepSyntheticScreenshots") && screenShot && FileExist(screenShot))
        FileDelete, %screenShot%

    return
}

S4T_BuildDiscordHeader(title, scriptName, packsInPool := "", packName := "", emoji := "") {
    separator := " " . Chr(0x00B7) . " "
    header := ""
    if (emoji != "")
        header .= emoji . " "
    header .= title . separator . "Instance: " . scriptName

    details := ""
    if (packsInPool != "")
        details .= packsInPool . " packs"
    if (packName != "") {
        if (details != "")
            details .= separator
        details .= packName
    }
    if (details != "")
        header .= " (" . details . ")"

    return header
}

;-------------------------------------------------------------------------------
; FilterCardsByS4T - Return only cards matching enabled S4T rarity settings
;-------------------------------------------------------------------------------
FilterCardsByS4T(cards, rarity) {
    global botConfig

    filteredCards := []
    if (!IsObject(cards) || !IsObject(rarity))
        return filteredCards

    total := cards.MaxIndex()
    Loop, % total {
        i := A_Index
        r := rarity[i] + 0
        c := cards[i]

        ; 1/2-diamond are never tradeable, always exclude from synthetic S4T images
        if (r = 1 || r = 2)
            continue

        if (r = 3) {
            if (botConfig.get("s4t3Dmnd") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 4) {
            if (botConfig.get("s4t4Dmnd") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 5) {
            prefix := SubStr(c, 1, 3)
            if (prefix = "TR_" && botConfig.get("s4tTrainer") = 1)
                filteredCards.Push(c)
            else if (prefix = "PK_" && botConfig.get("s4tFullArt") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 7) {
            if (botConfig.get("s4t1Star") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 8) {
            if (botConfig.get("s4tRainbow") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 9) {
            if (botConfig.get("s4tImmersive") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 10) {
            if (botConfig.get("s4tCrown") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 11) {
            if (botConfig.get("s4tShiny1Star") = 1)
                filteredCards.Push(c)
            continue
        }

        if (r = 12) {
            if (botConfig.get("s4tShiny2Star") = 1)
                filteredCards.Push(c)
            continue
        }
    }

    return filteredCards
}

FilterCardsByWishlistMatches(cards, wishlistMatches) {
    filteredCards := []
    if (!IsObject(cards) || !IsObject(wishlistMatches))
        return filteredCards

    wishlistIds := {}
    For _, match in wishlistMatches
        wishlistIds[match.id] := true

    For _, cardId in cards {
        if (wishlistIds.HasKey(cardId))
            filteredCards.Push(cardId)
    }

    return filteredCards
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

CountOccurances(cards, rarity, value, prefix := "") {
    count := 0
    total := cards.MaxIndex()

    Loop, % total {
        i := A_Index
        if (rarity[i] = value && (prefix = "" || SubStr(cards[i], 1, StrLen(prefix)) = prefix))
            count++
    }

    return count
}

WriteListToFile(list, filePath) {
    output := ""

    for index, value in list {
        if (index > 1)
            output .= ","
        output .= value
    }

    FileDelete, %filePath%      ; overwrite existing file
    FileAppend, %output%, %filePath%
}

AcquireCardImageLock(timeoutMs := 300000) {
    lockName := "Global\PTCGPB_CardImage"
    hMutex := DllCall("CreateMutex", "Ptr", 0, "Int", false, "Str", lockName, "Ptr")
    if (!hMutex)
        return 0

    waitResult := DllCall("WaitForSingleObject", "Ptr", hMutex, "UInt", timeoutMs, "UInt")
    ; WAIT_OBJECT_0 = 0, WAIT_ABANDONED = 0x80, WAIT_TIMEOUT = 0x102
    if (waitResult != 0 && waitResult != 0x80) {
        DllCall("CloseHandle", "Ptr", hMutex)
        return 0
    }
    return hMutex
}

ReleaseCardImageLock(hMutex) {
    if (!hMutex)
        return
    DllCall("ReleaseMutex", "Ptr", hMutex)
    DllCall("CloseHandle", "Ptr", hMutex)
}

GenerateSyntheticPackImage(cards, ByRef outputPath, highlightIds := "", maxCols := 3) {
    global session

    outputPath := ""
    if (!IsObject(cards) || cards.MaxIndex() = 0)
        return false

    scriptInst       := session.get("scriptName")
    helperDir        := A_ScriptDir "\..\Helper"
    helperTool       := helperDir "\cardimage.exe"
    tmpFile          := helperDir "\" scriptInst ".txt"
    tempDir          := A_ScriptDir . "\..\Screenshots\temp"

    if (!FileExist(helperTool))
        return false

    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    WriteListToFile(cards, tmpFile)

    outputPath := tempDir . "\synth_" . scriptInst . "_" . A_Now . ".png"

    highlightArg := ""
    if (IsObject(highlightIds) && highlightIds.MaxIndex() > 0) {
        highlightCsv := ""
        For _, hid in highlightIds {
            if (highlightCsv != "")
                highlightCsv .= ","
            highlightCsv .= hid
        }
        highlightArg := " --highlight """ . highlightCsv . """"
    } else if (highlightIds != "" && !IsObject(highlightIds)) {
        highlightArg := " --highlight """ . highlightIds . """"
    }
    colsArg := " --cols " . maxCols

    hCardImageLock := AcquireCardImageLock()
    if (!hCardImageLock) {
        outputPath := ""
        return false
    }

    RunWait, "%helperTool%" "%tmpFile%" "%outputPath%"%highlightArg%%colsArg%, %helperDir%, Hide
    ReleaseCardImageLock(hCardImageLock)
    if (ErrorLevel) {
        LogWarn("GenerateSyntheticPackImage failed. ErrorLevel=" . ErrorLevel . " outputPath=" . outputPath, "S4T.txt")
        outputPath := ""
        return false
    }

    if (!FileExist(outputPath)) {
        LogWarn("GenerateSyntheticPackImage did not create outputPath=" . outputPath, "S4T.txt")
        outputPath := ""
        return false
    }
    return true
}
