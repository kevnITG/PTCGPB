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
    global session

    deviceAccount := ""

    if (session.get("loadDir") && session.get("accountFileName")) {
        targetClean := RegExReplace(session.get("accountFileName"), "^\d+P_", "")
        targetClean := RegExReplace(targetClean, "_\d+(\([^)]+\))?\.xml$", "")

        Loop, Files, % session.get("loadDir") . "\*.xml"
        {
            currentClean := RegExReplace(A_LoopFileName, "^\d+P_", "")
            currentClean := RegExReplace(currentClean, "_\d+(\([^)]+\))?\.xml$", "")

            if (currentClean = targetClean) {
                xmlPath := session.get("loadDir") . "\" . A_LoopFileName
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

    tempPath := tempDir . "\current_device_" . session.get("scriptName") . ".xml"

    adbWriteRaw("cp -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml /sdcard/deviceAccount.xml")
    Sleep, 500

    RunWait, % session.get("adbPath") . " -s 127.0.0.1:" . session.get("adbPort") . " pull /sdcard/deviceAccount.xml """ . tempPath . """",, Hide

    Sleep, 500

    if (FileExist(tempPath)) {
        FileRead, xmlContent, %tempPath%

        if (RegExMatch(xmlContent, "i)<string name=""deviceAccount"">([^<]+)</string>", match)) {
            deviceAccount := match1
        }
        FileDelete, %tempPath%

        adbWriteRaw("rm -f /sdcard/deviceAccount.xml")
    }

    return deviceAccount
}

;-------------------------------------------------------------------------------
; LogToTradesDatabase - Compatibility no-op
;-------------------------------------------------------------------------------
LogToTradesDatabase(deviceAccount, cardTypes, cardCounts, screenShotFileName := "", shinedustValue := "") {
    return true
}

;-------------------------------------------------------------------------------
; LogToCardDatabase - Log cards to CSV database
;-------------------------------------------------------------------------------
CardDatabase_HelperPath() {
    return getScriptBaseFolder() . "\Helper\carddb.exe"
}

CloseCardDatabase(deviceAccount := "") {
    return true
}

MergeCardDatabase() {
    helperPath := CardDatabase_HelperPath()
    if (!FileExist(helperPath))
        return false

    root := getScriptBaseFolder()
    RunWait, % """" . helperPath . """ --root """ . root . """ merge-card-db",, Hide
    return !ErrorLevel
}

LogToCardDatabase(result) {
    deviceAccount := GetDeviceAccountFromXML()
    if (deviceAccount = "")
        return false

    cards := result.cards
    pack := result.pack

    cardStr := ""

    if (IsObject(cards)) {
        for _, card in cards {
            if (cardStr != "")
                cardStr .= "|"
            cardStr .= card
        }
    }

    timestamp := A_Now
    FormatTime, timestamp, %timestamp%, yyyy-MM-dd HH:mm:ss

    helperPath := CardDatabase_HelperPath()
    if (!FileExist(helperPath))
        return false

    root := getScriptBaseFolder()
    RunWait, % """" . helperPath . """ --root """ . root . """ append-pull --device-account """ . deviceAccount . """ --timestamp """ . timestamp . """ --pack """ . pack . """ --cards """ . cardStr . """",, Hide
    return !ErrorLevel
}

EnsureDirExists(dir) {
    if (InStr(FileExist(dir), "D"))
        return true

    SplitPath, dir,, parent
    if (parent && !InStr(FileExist(parent), "D")) {
        if (!EnsureDirExists(parent))
            return false
    }

    FileCreateDir, %dir%
    return InStr(FileExist(dir), "D")
}

EnsureCsvHeader(path, header) {
    if (!FileExist(path))
        return AppendTextWithRetry(path, header)

    FileGetSize, size, %path%
    if (size = 0)
        return AppendTextWithRetry(path, header)

    FileReadLine, firstLine, %path%, 1

    ; Remove UTF-8 BOM if present.
    if (SubStr(firstLine, 1, 1) = Chr(0xFEFF))
        firstLine := SubStr(firstLine, 2)

    ; Header already exists.
    if (SubStr(firstLine, 1, 9) = "Timestamp")
        return true

    FileRead, oldContent, %path%
    if (ErrorLevel) {
        MsgBox, 16, Error, Could not read existing CSV:`n%path%
        return false
    }

    tempPath := path . ".tmp"

    FileDelete, %tempPath%
    FileAppend, % header . oldContent, %tempPath%, UTF-8
    if (ErrorLevel) {
        MsgBox, 16, Error, Could not write temporary CSV:`n%tempPath%
        return false
    }

    FileMove, %tempPath%, %path%, 1
    if (ErrorLevel) {
        MsgBox, 16, Error, Could not replace CSV with repaired version:`n%path%
        return false
    }

    return true
}

CsvEscape(value) {
    q := Chr(34)
    value := "" . value
    value := StrReplace(value, q, q . q)
    return q . value . q
}

AppendTextWithRetry(path, text, retries := 50, sleepMs := 10) {
    Loop, %retries% {
        FileAppend, %text%, %path%, UTF-8
        if (!ErrorLevel)
            return true

        Sleep, %sleepMs%
    }

    MsgBox, 16, Error, Could not write to file after %retries% attempts:`n%path%
    return false
}

;-------------------------------------------------------------------------------
; UpdateTradesJSON - Compatibility no-op
;-------------------------------------------------------------------------------
UpdateTradesJSON(deviceAccount, cardTypes, cardCounts, timestamp, screenShotFileName := "", shinedustValue := "") {
    return true
}

;-------------------------------------------------------------------------------
; SearchTradesDatabase - Search the trades database with filters
;-------------------------------------------------------------------------------
SearchTradesDatabase(searchPackType := "", searchCardType := "") {
    return []
}

;-------------------------------------------------------------------------------
; GetTradesDatabaseStats - Get statistics from trades database
;-------------------------------------------------------------------------------
GetTradesDatabaseStats() {
    return ""
}

;-------------------------------------------------------------------------------
; SaveCroppedImage - Crop and save a portion of an image
;-------------------------------------------------------------------------------
SaveCroppedImage(sourceFile, destFile, x, y, w, h) {
    if (!FileExist(sourceFile)) {
        LogWarn("SaveCroppedImage: Source file not found: " . sourceFile, "OCR.txt")
        return false
    }

    pBitmap := Gdip_CreateBitmapFromFile(sourceFile)

    if (!pBitmap || pBitmap <= 0) {
        LogWarn("SaveCroppedImage: Failed to load bitmap from: " . sourceFile, "OCR.txt")
        return false
    }

    Gdip_GetImageDimensions(pBitmap, imageWidth, imageHeight)

    if (x < 0 || y < 0 || x + w > imageWidth || y + h > imageHeight) {
        LogWarn("SaveCroppedImage: Invalid crop coordinates - Image: " . imageWidth . "x" . imageHeight . ", Crop: " . x . "," . y . "," . w . "," . h, "OCR.txt")
        Gdip_DisposeImage(pBitmap)
        return false
    }

    pCroppedBitmap := Gdip_CloneBitmapArea(pBitmap, x, y, w, h)

    if (!pCroppedBitmap || pCroppedBitmap <= 0) {
        LogWarn("SaveCroppedImage: Failed to crop bitmap", "OCR.txt")
        Gdip_DisposeImage(pBitmap)
        return false
    }

    saveResult := Gdip_SaveBitmapToFile(pCroppedBitmap, destFile)

    if (saveResult != 0) {
        LogWarn("SaveCroppedImage: Failed to save cropped image to: " . destFile . " (Error: " . saveResult . ")", "OCR.txt")
    }

    Gdip_DisposeImage(pCroppedBitmap)
    Gdip_DisposeImage(pBitmap)

    return (saveResult = 0)
}

;-------------------------------------------------------------------------------
; LogShinedustToDatabase - Persist shinedust to account metadata
;-------------------------------------------------------------------------------
LogShinedustToDatabase(shinedustValue) {
    global session

    shinedustValueClean := StrReplace(shinedustValue, ",", "")

    if (shinedustValueClean < 99 || shinedustValueClean > 999999) {
        CreateStatusMessage("Invalid shinedust value: " . shinedustValue . " - not logging")
        Sleep, 2000
        return
    }

    deviceAccount := GetDeviceAccountFromXML()
    if (deviceAccount != "")
        AccountMetadata_SetShinedust(deviceAccount, shinedustValueClean, session.get("scriptName"), session.get("accountFileName"))

}

;-------------------------------------------------------------------------------
; UpdateShinedustJSON - Compatibility no-op
;-------------------------------------------------------------------------------
UpdateShinedustJSON(deviceAccount, shinedustValue, timestamp, cleanFilename) {
    return true
}

SendMetadataToPTCGPB(valueToSend) {
    global session

    Random, randNum, 10000, 99999
    msgID := A_Now . "_" . A_TickCount . "_" . randNum

    payload := msgID . "|" . session.get("scriptName") . "|" . valueToSend

    VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
    SizeInBytes := (StrLen(payload) + 1) * (A_IsUnicode ? 2 : 1)
    NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
    NumPut(&payload, CopyDataStruct, 2*A_PtrSize)

    SendMessage, 0x4A, 0, &CopyDataStruct,, PTCGPB.ahk
    response := ErrorLevel

    if (response == "FAIL") {
        return 0
    }

    return response
}
