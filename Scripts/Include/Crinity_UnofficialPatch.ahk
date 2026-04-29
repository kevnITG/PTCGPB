; FindOrLoseImage EL = 0, Found Mode, Found image - Return xy pos / Not Found image - Return 0
; FindOrLoseImage EL = 1, Loose Mode, Found image - Return 0 / Not Found image - Return 1
; ====================================================================
; #Include %A_ScriptDir%\Include\Crinity_UnofficialPatch.ahk

/*
processPrivacyAgreement()
{
    if(!FindOrLoseImage("newPrivacyTOSpopup", 0))
        return

    CreateStatusMessage("Accepting Privacy and TOS popup.",,,, false)
    
    FindImageAndClick("NewPrivacyAgreement_Main", 142, 372) ; Click First alert OK
    FindImageAndClick("NewPrivacyAgreement_DescX", 140, 336) ; Click Description Button
    FindImageAndClick("NewPrivacyAgreement_Main", 138, 487) ; Close Description Window
    Loop, {
        adbClick_wbb(47, 371) ; Click Check button
        Delay(2)
        if(FindOrLoseImage("NewPrivacyAgreement_Checked", 0))
            break
    }
    
    Loop, {
        adbClick_wbb(143, 488) ; Click Main OK Button
        Delay(1)
        if(FindOrLoseImage("NewPrivacyAgreement_Main", 1)) {
            Delay(2)
            adbClick_wbb(142, 372) ; Click Second alert OK
            break
        }
    }
    Delay(1)
    adbClick_wbb(142, 372) ; Click Second alert OK(One more)

    FindImageAndClick("NewPrivacyAgreement_DescX", 140, 336) ; Click Description Button
    FindImageAndClick("NewPrivacyAgreement_Main", 138, 487) ; Close Description Window
    Loop, {
        adbClick_wbb(47, 371) ; Click Check button
        Delay(2)
        if(FindOrLoseImage("NewPrivacyAgreement_Checked", 0))
            break
    }

    Loop, {
        adbClick_wbb(143, 488) ; Click Main OK Button
        Delay(2)
        if(FindOrLoseImage("NewPrivacyAgreement_Checked", 1))
            break
    }
}
*/

getPackCoordXInHome(){
    global botConfig, session

    mapPackX := {"Left":60, "Middle":140, "Right":215}
    packx := mapPackX["Middle"]

    if(botConfig.get("deleteMethod") = "Inject 13p+" || session.get("isReloadAfterAddFriends")){
        session.set("isSkipSelectExpansion", 1)
        if(session.get("openPack") != session.get("mainScreenPackList")["Middle"])
            session.set("isSkipSelectExpansion", 0)
    }
    else if(botConfig.get("deleteMethod") = "Inject Wonderpick 96P+"){
        for index, value in session.get("mainScreenPackList") {
            if (value = session.get("openPack")){
                session.set("isSkipSelectExpansion", 1)
                packx := mapPackX[index]
                break
            }
        }
    }
    return packx
}

startPreProcess(methodType){
    global session, needlesDict

    findImageName := ""
    clickX := 0
    clickY := 0
    
    if(methodType = "Create Bots (13P)"){
        findImageName := "Country"
        needleName := "Create_CountryComboBoxButton"
        clickX := 143
        clickY := 370
    }
    else if(methodType = "Inject 13p+"){
        findImageName := "Points"
        needleName := "Pack_PackPointButton"
        clickX := getPackCoordXInHome()
        clickY := 203
    }
    else if(methodType = "Inject Wonderpick 96P+"){
        findImageName := "Social"
        needleName := "Common_ActivatedSocialInMainMenu"
        clickX := 143
        clickY := 518
    }
    findImageName .= "`n(Selected pack: " . session.get("openPack") . ")"

    imagePath := A_ScriptDir . "\Needles\"
    searchVariation := 20
    pBitmap := 0
    session.set("isSkipSelectExpansion", 0)
    isSkip := false

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop, {
        if(FindOrLoseImage(needleName, 0, failSafeTime, , true))
            break

        adbClick_wbb(clickX, clickY)
        Delay(0.5)

        pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))

        Path = %imagePath%CrashWhilePackOpen.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 20, 180, 35, 182, searchVariation)
        if(vRet = 1){
            CreateStatusMessage("Clearing problem opening pack pop-up",,,, false)
            adbClick_wbb(145, 370)
            Delay(1)
        }
/*
        Path = %imagePath%HardwareReqs.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 306, 38, 316, searchVariation)
        if(vRet){
            CreateStatusMessage("Clearing hardware requirements pop-up",,,, false)
            adbClick_wbb(199, 370)
            Delay(1)
        }

        Path = %imagePath%HardwareReq2.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 41, 388, 92, 403, searchVariation)
        if(vRet){
            CreateStatusMessage("Clearing hardware requirements pop-up",,,, false)
            Sleep, 3000
            adbClick_wbb(199,370)
            adbClick_wbb(199,370)
            adbClick_wbb(199,370)
            Sleep, 2000
        }
*/
        Path = %imagePath%closeduringpack.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY
                                    , needlesDict.Get("Common_AlertForAppCrachDuringOpenPack").coords.startX
                                    , needlesDict.Get("Common_AlertForAppCrachDuringOpenPack").coords.startY
                                    , needlesDict.Get("Common_AlertForAppCrachDuringOpenPack").coords.endX
                                    , needlesDict.Get("Common_AlertForAppCrachDuringOpenPack").coords.endY
                                    , searchVariation)
        if(vRet = 1){
            CreateStatusMessage("Found closing during pack pop-up",,,, false)
            Delay(1)
            adbClick_wbb(138, 365)
        }

        Path = %imagePath%DataDownload.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 41, 378, 92, 393, searchVariation)
        if(vRet = 1){
            CreateStatusMessage("Downloading data",,,, false)
            Sleep, 1000
            adbClick_wbb(198, 375)
            adbClick_wbb(198, 375)
            Sleep, 10000

            ;processPrivacyAgreement()
        }

        Path = %imagePath%Button.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 95, 350, 195, 530, 80)
        if(vRet = 1){
            if (InStr(vPosXY, ",")) {
                StringSplit, pos, vPosXY, `,
                adbClick_wbb(pos1, pos2)
            } else
                adbClick(137, 365)
        }

        DelayH(20)
    
        Gdip_DisposeImage(pBitmap)

        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Entering...(" . failSafeTime "/90 seconds)`nFinding: " . findImageName)
    }
}

ReceiveGift(){
    global session, receivedGiftOnly

    if (HasFlagInMetadata(session.get("accountFileName"), "R"))
        return false  ; Not a R flag account

    Loop, {
        if(FindOrLoseImage("Common_ShopButtonInMain", 0)) {
            adbClick_wbb(247, 93)
            Delay(4)
        }

        if(FindOrLoseImage("Gift_ClaimAllButton", 0)) {
            break
        }
    }

    ; Try 5 times
    Loop, 5 {
        adbClick(212, 427)
        Delay(2)
        if (FindOrLoseImage("Gift_ReceivedWindowRightBorder", 0)) {
            adbInputEvent("111") ;send ESC
            Delay(2)
            break
        }
    }
    Delay(1)
    FindImageAndClick("Common_ShopButtonInMain", 138, 505, , 1000)

    receivedGiftOnly := true
}

getDevelopmentScreenShot(packCardType, pBitmap := 0){
    global session

    fileDir := A_ScriptDir "\..\Screenshots\Development"

    if !FileExist(fileDir)
        FileCreateDir, %fileDir%

    ; File path for saving the screenshot locally
    fileName := A_Now . "_" . session.get("scriptName") . "_" . packCardType . ".png"
    filePath := fileDir . "\" . fileName

    if(pBitmap = 0)
        pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    
    Gdip_SaveBitmapToFile(pBitmap, filePath)
}