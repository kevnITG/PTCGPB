class SpecialEvent{
    eventName := ""
    expiryDate := ""
    expiryTime := "055959"
    redBoxCoords := ""
    blueBoxCoords := ""
    redBoxImageData := ""
    blueBoxImageData := ""
    validate := false
    isValidateComplete := false
    validationFailedMessage := ""

    redBoxBitmap := -1
    blueBoxBitmap := -1

    __New(eventName, expiryDate, expiryTime, redBoxCoords, blueBoxCoords, redBoxImageData, blueBoxImageData){
        this.eventName := eventName
        this.expiryDate := expiryDate
        this.expiryTime := expiryTime
        this.redBoxCoords := redBoxCoords
        this.blueBoxCoords := blueBoxCoords
        this.redBoxImageData := redBoxImageData
        this.blueBoxImageData := blueBoxImageData
    }

    __Delete() {
        if (this.redBoxBitmap) {
            Gdip_DisposeImage(this.redBoxBitmap)
            this.redBoxBitmap := 0
        }
        if (this.blueBoxBitmap) {
            Gdip_DisposeImage(this.blueBoxBitmap)
            this.blueBoxBitmap := 0
        }
    }

    getRedBoxBitmap(){
        if(this.redBoxBitmap = -1)
            this.redBoxBitmap := Base64ToBitmap(this.redBoxImageData)
        return this.redBoxBitmap
    }

    getBlueBoxBitmap(){
        if(this.blueBoxBitmap = -1)
            this.blueBoxBitmap := Base64ToBitmap(this.blueBoxImageData)
        return this.blueBoxBitmap
    }

    disposeBitmapObject(){
        if (this.redBoxBitmap != 0) {
            Gdip_DisposeImage(this.redBoxBitmap)
            this.redBoxBitmap := 0
        }
        if (this.blueBoxBitmap != 0) {
            Gdip_DisposeImage(this.blueBoxBitmap)
            this.blueBoxBitmap := 0
        }
    }

    isExpiredSpecialEvent(){
        if(this.expiryDate = "" || this.expiryTime = "")
            return true
        
        waitTime := -5
        currentDateTime := A_Now
        offset := A_Now
        currenttimeutc := A_NowUTC

        EnvSub, offset, %currenttimeutc%, Hours   ;offset from local timezone to UTC
        expireEventTime := this.expiryDate . this.expiryTime

        expireEventTime += offset, Hours
        expireEventTime += waitTime, Minutes

        if (currentDateTime <= expireEventTime)
        {
            return false
        }
        return true
    }

    isExistNeedleInScreen(winTitle){
        existResult := 0
        pBitmap := from_window(getMuMuHwnd(winTitle . " ahk_class Qt5156QWindowIcon"))

        Loop, 2{
            currentNeedleCoords := Object()
            tempNeedleObj := Object()
            loopIdx := A_Index

            needleBitmap := 0
            if(loopIdx = 1){
                needleBitmap := this.getRedBoxBitmap()
                currentNeedleCoords := this.redBoxCoords
            }
            else if(loopIdx = 2){
                needleBitmap := this.getBlueBoxBitmap()
                currentNeedleCoords := this.blueBoxCoords
            }

            tempNeedleObj.needle := needleBitmap
            vRet := Gdip_ImageSearch(pBitmap, needleBitmap, vPosXY, currentNeedleCoords.startX, currentNeedleCoords.startY
                                    , currentNeedleCoords.endX, currentNeedleCoords.endY, 20)

            existResult += vRet
        }
        
        if(existResult = 2)
            return 2
        else if(existResult < 0)
            return existResult
        else
            return false
    }

    getValidate(){
        if(!this.isValidateComplete)
            this.isValidate()
        
        return this.validate
    }

    isValidate(){
        this.isValidateComplete := true
        if (this.eventName = "ERROR" || this.eventName = ""){
            this.validationFailedMessage := "Missing or invalid Name."
            return
        }
        if !RegExMatch(this.expiryDate, "^\d{8}$"){
            this.validationFailedMessage := "Invalid ExpiryDate format."
            return
        }
        if !RegExMatch(this.expiryTime, "^\d{6}$"){
            this.validationFailedMessage := "Invalid ExpiryTime format."
            return
        }
        if (!this.redBoxCoords.isValid){
            this.validationFailedMessage := "Invalid RedBox Coords."
            return
        }
        if (!this.blueBoxCoords.isValid){
            this.validationFailedMessage := "Invalid BlueBox Coords."
            return
        }
        if (this.redBoxImageData = "" || this.blueBoxImageData = ""){
            this.validationFailedMessage := "Missing ImageData."
            return
        }

        pTestRed := Base64ToBitmap(this.redBoxImageData)
        if (!pTestRed) {
            this.validationFailedMessage := "RedBox image data is corrupted and cannot be converted to a Bitmap."
            return
        }
        Gdip_DisposeImage(pTestRed)

        pTestBlue := Base64ToBitmap(this.blueBoxImageData)
        if (!pTestBlue) {
            this.validationFailedMessage := "BlueBox image data is corrupted and cannot be converted to a Bitmap."
            return
        }
        Gdip_DisposeImage(pTestBlue)

        this.validate := true
    }
}

loadSevtFile(FilePath){
    global session
    
    FileRead, FileContent, %FilePath%

    IniRead, vName, %FilePath%, TargetInfo, EventName

    if (vName = "ERROR" || vName = "")
        return

    IniRead, vDate, %FilePath%, TargetInfo, ExpiryDate
    IniRead, vTime, %FilePath%, TargetInfo, ExpiryTime

    IniRead, rCoords, %FilePath%, RedBox, Coords
    IniRead, bCoords, %FilePath%, BlueBox, Coords

    RegExMatch(FileContent, "i)\[RedBox\][^\[]*ImageData=([A-Za-z0-9+/=]+)", mRed)
    rImage := mRed1

    RegExMatch(FileContent, "i)\[BlueBox\][^\[]*ImageData=([A-Za-z0-9+/=]+)", mBlue)
    bImage := mBlue1

    rArr := StrSplit(rCoords, ",")
    bArr := StrSplit(bCoords, ",")

    tempSpecialEventObj := new SpecialEvent(vName, vDate, vTime, new Coordinate(Trim(rArr[1]), Trim(rArr[2]), Trim(rArr[3]), Trim(rArr[4]))
                                                , new Coordinate(Trim(bArr[1]), Trim(bArr[2]), Trim(bArr[3]), Trim(bArr[4]))
                                                , rImage, bImage)
    tempSpecialEventObj.isValidate()

    if(tempSpecialEventObj.getValidate())
        session.get("specialEventList")[vName] := tempSpecialEventObj
    else
        tempSpecialEventObj.disposeBitmapObject()
    
    return
}

loadAllSevtFiles() {
    TargetPath := getScriptBaseFolder() . "\SpecialEvents\Events"

    Loop, Files, %TargetPath%\*.sevt, F
    {
        FilePath := A_LoopFileFullPath
        loadSevtFile(FilePath)
    }
}

allSpecialEventDispose(){
    global session
    for specialEventName, specialEventObj in session.get("specialEventList") {
        specialEventObj.disposeBitmapObject()
    }
}

initEventResult(){
    global session

    eventResult := {}
    for eventName, value in session.get("specialEventList") {
        eventResult[eventName] := false
    }

    return eventResult
}

isAllEventGotReward(eventResult) {
    totalResult := true
    for eventName, result in eventResult {
        if(!eventResult[eventName]){
            totalResult := false
            break
        }
    }
    return totalResult
}

syncSpecialEvents() {
    global session
    TargetPath := getScriptBaseFolder() . "\SpecialEvents\Events"
    
    CurrentFileNames := {}

    Loop, Files, %TargetPath%\*.sevt, F
    {
        FilePath := A_LoopFileFullPath
        IniRead, vName, %FilePath%, TargetInfo, EventName
        if (vName = "ERROR" || vName = "")
            continue
            
        CurrentFileNames[vName] := true

        if (!session.get("specialEventList").HasKey(vName)) {
            loadSevtFile(FilePath)
        } else {
            session.get("specialEventList")[vName].disposeBitmapObject()
            loadSevtFile(FilePath)
        }
    }

    For vName, oMission in session.get("specialEventList") 
    {
        if (!CurrentFileNames.HasKey(vName)) {
            oMission.disposeBitmapObject()
            session.get("specialEventList").Delete(vName)
        }
    }
}

Base64ToBitmap(sBase64) {
    if !DllCall("Crypt32.dll\CryptStringToBinary", "ptr", &sBase64, "uint", 0, "uint", 0x01, "ptr", 0, "uint*", nSize, "ptr", 0, "ptr", 0)
        return 0
    
    hData := DllCall("GlobalAlloc", "uint", 0x2, "ptr", nSize, "ptr")
    pData := DllCall("GlobalLock", "ptr", hData, "ptr")
    
    if !DllCall("Crypt32.dll\CryptStringToBinary", "ptr", &sBase64, "uint", 0, "uint", 0x01, "ptr", pData, "uint*", nSize, "ptr", 0, "ptr", 0) {
        DllCall("GlobalUnlock", "ptr", hData)
        DllCall("GlobalFree", "ptr", hData)
        return 0
    }
    
    DllCall("GlobalUnlock", "ptr", hData)
    
    DllCall("ole32\CreateStreamOnHGlobal", "ptr", hData, "int", 1, "ptr*", pStream)
    
    DllCall("gdiplus\GdipCreateBitmapFromStream", "ptr", pStream, "ptr*", pTempBitmap)
    
    if (pTempBitmap) {
        hBitmap := Gdip_CreateHBITMAPFromBitmap(pTempBitmap)
        pCleanBitmap := Gdip_CreateBitmapFromHBITMAP(hBitmap)
        
        DeleteObject(hBitmap)
        Gdip_DisposeImage(pTempBitmap)
    } else {
        pCleanBitmap := 0
    }
    
    ObjRelease(pStream) 
    
    return pCleanBitmap
}