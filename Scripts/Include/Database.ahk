;===============================================================================
; Database.ahk - Database and Logging Functions
;===============================================================================
; This file contains functions for database operations and data persistence.
; These functions handle:
;   - Trade database logging (CSV format)
;   - JSON index updates
;   - Database searching and statistics
;   - Device account extraction from XML
;   - Shinedust tracking
;   - Screenshot cropping and saving
;   - General JSON file operations
;
; Dependencies: Logging.ahk (for LogToFile), Gdip_All.ahk (for image operations)
; Used by: Card detection, trading, account management
;===============================================================================

;-------------------------------------------------------------------------------
; GetDeviceAccountFromXML - Extract device account ID from XML
;-------------------------------------------------------------------------------
GetDeviceAccountFromXML() {
    global loadDir, accountFileName, adbPath, adbPort, scriptName, adbShell

    deviceAccount := ""

    if (loadDir && accountFileName) {
        targetClean := RegExReplace(accountFileName, "^\d+P_", "")
        targetClean := RegExReplace(targetClean, "_\d+(\([^)]+\))?\.xml$", "")

        Loop, Files, %loadDir%\*.xml
        {
            currentClean := RegExReplace(A_LoopFileName, "^\d+P_", "")
            currentClean := RegExReplace(currentClean, "_\d+(\([^)]+\))?\.xml$", "")

            if (currentClean = targetClean) {
                xmlPath := loadDir . "\" . A_LoopFileName
                FileRead, xmlContent, %xmlPath%

                if (RegExMatch(xmlContent, "i)<string name=""deviceAccount"">([^<]+)</string>", match)) {
                    deviceAccount := match1
                    return deviceAccount
                }
                break
            }
        }
    }

    tempDir := A_ScriptDir . "\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    tempPath := tempDir . "\current_device_" . scriptName . ".xml"

    adbWriteRaw("cp -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")
    Sleep, 500

    RunWait, % adbPath . " -s 127.0.0.1:" . adbPort . " pull /sdcard/deviceAccount.xml """ . tempPath . """",, Hide

    Sleep, 500

    if (FileExist(tempPath)) {
        FileRead, xmlContent, %tempPath%

        if (RegExMatch(xmlContent, "i)<string name=""deviceAccount"">([^<]+)</string>", match)) {
            deviceAccount := match1
        }
        FileDelete, %tempPath%

        adbWriteRaw("rm /sdcard/deviceAccount.xml")
    }

    return deviceAccount
}

;-------------------------------------------------------------------------------
; LogToTradesDatabase - Log card trades to CSV database
;-------------------------------------------------------------------------------
LogToTradesDatabase(deviceAccount, cardTypes, cardCounts, screenShotFileName := "", shinedustValue := "") {
    global scriptName, accountFileName, accountOpenPacks, openPack

    dbPath := A_ScriptDir . "\..\Accounts\Trades\Trades_Database.csv"

    if (!FileExist(dbPath)) {
        header := "Timestamp,OriginalFilename,CleanFilename,DeviceAccount,PackType,CardTypes,CardCounts,PackScreenshot,Shinedust`n"
        FileAppend, %header%, %dbPath%
    } else {
        ; Check if Shinedust column exists
        FileReadLine, headerLine, %dbPath%, 1
        if (!InStr(headerLine, "Shinedust")) {
            ; Read entire file and add Shinedust column
            FileRead, csvContent, %dbPath%
            csvContent := RegExReplace(csvContent, "^([^\n]+)`n", "$1,Shinedust`n")
            FileDelete, %dbPath%
            FileAppend, %csvContent%, %dbPath%
        }
    }

    cleanFilename := accountFileName
    cleanFilename := RegExReplace(cleanFilename, "^\d+P_", "")
    cleanFilename := RegExReplace(cleanFilename, "_\d+(\([^)]*\))?\.xml$", "")

    cardTypeStr := ""
    cardCountStr := ""

    Loop, % cardTypes.Length() {
        if (A_Index > 1) {
            cardTypeStr .= "|"
            cardCountStr .= "|"
        }
        cardTypeStr .= cardTypes[A_Index]
        cardCountStr .= cardCounts[A_Index]
    }

    timestamp := A_Now
    FormatTime, timestamp, %timestamp%, yyyy-MM-dd HH:mm:ss

    csvRow := timestamp . ","
        . accountFileName . ","
        . cleanFilename . ","
        . deviceAccount . ","
        . openPack . ","
        . cardTypeStr . ","
        . cardCountStr . ","
        . screenShotFileName . ","
        . shinedustValue . "`n"

    FileAppend, %csvRow%, %dbPath%

    UpdateTradesJSON(deviceAccount, cardTypes, cardCounts, timestamp, screenShotFileName, shinedustValue)
}

;-------------------------------------------------------------------------------
; UpdateTradesJSON - Update JSON index with trade information
;-------------------------------------------------------------------------------
UpdateTradesJSON(deviceAccount, cardTypes, cardCounts, timestamp, screenShotFileName := "", shinedustValue := "") {
    global scriptName, accountFileName, accountOpenPacks, openPack

    jsonPath := A_ScriptDir . "\..\Accounts\Trades\Trades_Index.json"

    cleanFilename := accountFileName
    cleanFilename := RegExReplace(cleanFilename, "^\d+P_", "")
    cleanFilename := RegExReplace(cleanFilename, "_\d+(\([^)]+\))?\.xml$", "")

    jsonEntry := "{"
        . """timestamp"": """ . timestamp . """, "
        . """deviceAccount"": """ . deviceAccount . """, "
        . """originalFilename"": """ . accountFileName . """, "
        . """cleanFilename"": """ . cleanFilename . """, "
        . """packType"": """ . openPack . """, "
        . """packScreenshot"": """ . screenShotFileName . """, "

    ; Add shinedust if provided
    if (shinedustValue != "") {
        jsonEntry .= """shinedust"": """ . shinedustValue . """, "
    }

    jsonEntry .= """cards"": ["

    Loop, % cardTypes.Length() {
        if (A_Index > 1)
            jsonEntry .= ", "
        jsonEntry .= "{""type"": """ . cardTypes[A_Index] . """, ""count"": " . cardCounts[A_Index] . "}"
    }

    jsonEntry .= "]}`n"

    FileAppend, %jsonEntry%, %jsonPath%
}

;-------------------------------------------------------------------------------
; SearchTradesDatabase - Search the trades database with filters
;-------------------------------------------------------------------------------
SearchTradesDatabase(searchPackType := "", searchCardType := "") {
    dbPath := A_ScriptDir . "\..\Accounts\Trades\Trades_Database.csv"

    if (!FileExist(dbPath))
        return []

    results := []
    FileRead, csvContent, %dbPath%

    Loop, Parse, csvContent, `n, `r
    {
        if (A_Index = 1)
            continue

        if (A_LoopField = "")
            continue

        fields := StrSplit(A_LoopField, ",")

        if (fields.Length() < 7)
            continue

        packType := fields[5]
        cardTypes := fields[6]

        if (searchPackType != "" && packType != searchPackType)
            continue

        if (searchCardType != "" && !InStr(cardTypes, searchCardType))
            continue

        result := {}
        result.Timestamp := fields[1]
        result.OriginalFilename := fields[2]
        result.CleanFilename := fields[3]
        result.DeviceAccount := fields[4]
        result.PackType := fields[5]
        result.CardTypes := fields[6]
        result.CardCounts := fields[7]

        results.Push(result)
    }

    return results
}

;-------------------------------------------------------------------------------
; GetTradesDatabaseStats - Get statistics from trades database
;-------------------------------------------------------------------------------
GetTradesDatabaseStats() {
    dbPath := A_ScriptDir . "\..\Accounts\Trades\Trades_Database.csv"

    if (!FileExist(dbPath))
        return ""

    stats := {}
    stats.TotalEntries := 0
    stats.UniqueAccounts := {}
    stats.PackTypes := {}
    stats.CardTypes := {}

    FileRead, csvContent, %dbPath%

    Loop, Parse, csvContent, `n, `r
    {
        if (A_Index = 1)
            continue

        if (A_LoopField = "")
            continue

        stats.TotalEntries++

        fields := StrSplit(A_LoopField, ",")

        if (fields.Length() < 7)
            continue

        deviceAccount := fields[4]
        if (!stats.UniqueAccounts.HasKey(deviceAccount))
            stats.UniqueAccounts[deviceAccount] := 0
        stats.UniqueAccounts[deviceAccount]++

        packType := fields[5]
        if (!stats.PackTypes.HasKey(packType))
            stats.PackTypes[packType] := 0
        stats.PackTypes[packType]++

        cardTypes := StrSplit(fields[6], "|")
        Loop, % cardTypes.Length() {
            cardType := cardTypes[A_Index]
            if (!stats.CardTypes.HasKey(cardType))
                stats.CardTypes[cardType] := 0
            stats.CardTypes[cardType]++
        }
    }

    return stats
}

;-------------------------------------------------------------------------------
; SaveCroppedImage - Crop and save a portion of an image
;-------------------------------------------------------------------------------
SaveCroppedImage(sourceFile, destFile, x, y, w, h) {
    if (!FileExist(sourceFile)) {
        LogToFile("SaveCroppedImage: Source file not found: " . sourceFile, "OCR.txt")
        return false
    }

    pBitmap := Gdip_CreateBitmapFromFile(sourceFile)

    if (!pBitmap || pBitmap <= 0) {
        LogToFile("SaveCroppedImage: Failed to load bitmap from: " . sourceFile, "OCR.txt")
        return false
    }

    Gdip_GetImageDimensions(pBitmap, imageWidth, imageHeight)

    if (x < 0 || y < 0 || x + w > imageWidth || y + h > imageHeight) {
        LogToFile("SaveCroppedImage: Invalid crop coordinates - Image: " . imageWidth . "x" . imageHeight . ", Crop: " . x . "," . y . "," . w . "," . h, "OCR.txt")
        Gdip_DisposeImage(pBitmap)
        return false
    }

    pCroppedBitmap := Gdip_CloneBitmapArea(pBitmap, x, y, w, h)

    if (!pCroppedBitmap || pCroppedBitmap <= 0) {
        LogToFile("SaveCroppedImage: Failed to crop bitmap", "OCR.txt")
        Gdip_DisposeImage(pBitmap)
        return false
    }

    saveResult := Gdip_SaveBitmapToFile(pCroppedBitmap, destFile)

    if (saveResult != 0) {
        LogToFile("SaveCroppedImage: Failed to save cropped image to: " . destFile . " (Error: " . saveResult . ")", "OCR.txt")
    }

    Gdip_DisposeImage(pCroppedBitmap)
    Gdip_DisposeImage(pBitmap)

    return (saveResult = 0)
}

;-------------------------------------------------------------------------------
; LogShinedustToDatabase - Log shinedust value to database
;-------------------------------------------------------------------------------
LogShinedustToDatabase(shinedustValue) {
    global accountFileName

    shinedustValueClean := StrReplace(shinedustValue, ",", "")

    if (shinedustValueClean < 99 || shinedustValueClean > 999999) {
        CreateStatusMessage("Invalid shinedust value: " . shinedustValue . " - not logging")
        Sleep, 2000
        return
    }

    dbPath := A_ScriptDir . "\..\Accounts\Trades\Trades_Database.csv"

    if (!FileExist(dbPath)) {
        header := "Timestamp,OriginalFilename,CleanFilename,DeviceAccount,PackType,CardTypes,CardCounts,PackScreenshot,Shinedust`n"
        FileAppend, %header%, %dbPath%
    } else {
        FileReadLine, headerLine, %dbPath%, 1
        if (!InStr(headerLine, "Shinedust")) {
            FileRead, csvContent, %dbPath%

            Lines := StrSplit(csvContent, "`n", "`r")
            newContent := Lines[1] . ",Shinedust`n"

            Loop, % Lines.Length()
            {
                if (A_Index = 1)
                    continue
                if (Lines[A_Index] = "")
                    continue
                newContent .= Lines[A_Index] . ",`n"
            }

            FileDelete, %dbPath%
            FileAppend, %newContent%, %dbPath%
        }
    }

    deviceAccount := GetDeviceAccountFromXML()

    timestamp := A_Now
    FormatTime, timestamp, %timestamp%, yyyy-MM-dd HH:mm:ss

    cleanFilename := accountFileName
    cleanFilename := RegExReplace(cleanFilename, "^\d+P_", "")
    cleanFilename := RegExReplace(cleanFilename, "_\d+(\([^)]*\))?\.xml$", "")

    csvRow := timestamp . ","
        . accountFileName . ","
        . cleanFilename . ","
        . deviceAccount . ","
        . ","
        . ","
        . ","
        . ","
        . shinedustValueClean . "`n"

    FileAppend, %csvRow%, %dbPath%

    UpdateShinedustJSON(deviceAccount, shinedustValueClean, timestamp, cleanFilename)
}

;-------------------------------------------------------------------------------
; UpdateShinedustJSON - Update JSON index with shinedust information
;-------------------------------------------------------------------------------
UpdateShinedustJSON(deviceAccount, shinedustValue, timestamp, cleanFilename) {
    global accountFileName

    jsonPath := A_ScriptDir . "\..\Accounts\Trades\Trades_Index.json"

    jsonEntry := "{"
        . """timestamp"": """ . timestamp . """, "
        . """deviceAccount"": """ . deviceAccount . """, "
        . """originalFilename"": """ . accountFileName . """, "
        . """cleanFilename"": """ . cleanFilename . """, "
        . """shinedust"": """ . shinedustValue . """"
        . "}`n"

    FileAppend, %jsonEntry%, %jsonPath%
}

;-------------------------------------------------------------------------------
; AppendToJsonFile - Append data to a JSON file
;-------------------------------------------------------------------------------
AppendToJsonFile(variableValue) {
    global jsonFileName
    if (!jsonFileName || !variableValue) {
        return
    }

    ; Read the current content of the JSON file
    FileRead, jsonContent, %jsonFileName%
    if (jsonContent = "") {
        jsonContent := "[]"
    }

    ; Parse and modify the JSON content
    jsonContent := SubStr(jsonContent, 1, StrLen(jsonContent) - 1) ; Remove trailing bracket
    if (jsonContent != "[")
        jsonContent .= ","
    jsonContent .= "{""time"": """ A_Now """, ""variable"": " variableValue "}]"

    ; Write the updated JSON back to the file
    FileDelete, %jsonFileName%
    FileAppend, %jsonContent%, %jsonFileName%
}
