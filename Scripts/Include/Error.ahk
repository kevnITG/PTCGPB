global errorImageList := ["Common_Error"
                        , "Common_Error_Cache"
                        , "Common_Error_NoResponse"
                        , "Common_Error_NoResponseDark"
                        , "Common_Error_NoBackground_1Button"
                        , "Common_Error_3ButtonError_Nodata"]
global errorFuncList := {}
global interceptProc := false

errorFuncList["Common_Error"] := Func("procError_Common")
errorFuncList["Common_Error_Cache"] := Func("procError_Cache")
errorFuncList["Common_Error_NoResponse"] := Func("procError_NoResponse")
errorFuncList["Common_Error_NoResponseDark"] := Func("procError_NoResponseDark")
errorFuncList["Common_Error_NoBackground_1Button"] := Func("procError_Common")
errorFuncList["Common_Error_3ButtonError_Nodata"] := Func("procError_NoSaveData")

ErrorCheckInScreen(pBitmap, searchVariation := 20){
    global needlesDict, errorImageList, errorFuncList, interceptProc

    imagePath := A_ScriptDir . "\Needles\"
    For key, value in errorImageList {
        needleObj := needlesDict.Get(value)

        Path := imagePath . needleObj.imageName . ".png"
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY
                                        , needleObj.coords.startX
                                        , needleObj.coords.startY
                                        , needleObj.coords.endX
                                        , needleObj.coords.endY
                                        , searchVariation)
        if (vRet = 1 && !interceptProc) {
            errorFuncList[value].Call()
        }
    }

}   

procError_Common(){
    CreateStatusMessage("Found error message in " . A_ScriptName . ". Clicking Button...",,,, false)
    adbClick_wbb(137, 380)
    Sleep, 1000
}

procError_Cache(){
    global botConfig

    if(botConfig.get("heartBeatOwnerWebHookURL") != "")
        LogToDiscord(A_ScriptName . " It appears a cache deletion error message appeared on the instance. Delete the instance, then copy it and reload the script.",, true,,, botConfig.get("heartBeatOwnerWebHookURL"))

    Pause, On
    return
}

procError_NoResponse(){
    CreateStatusMessage("No response in " . A_ScriptName . ". Clicking retry...",,,, false)
    adbClick_wbb(46, 299)
    Sleep, 1000
}

procError_NoResponseDark(){
    CreateStatusMessage("No response in " . A_ScriptName . ". Clicking retry...",,,, false)
    adbClick_wbb(46, 299)
    Sleep, 1000
}

procError_NoSaveData(){
    global botConfig

    LogToDiscord(A_ScriptName . " An error has occurred indicating that no save data exists, or an unknown error has occurred.`nThe bot is currently paused. Please resolve the error and reload.",, true,,, botConfig.get("heartBeatOwnerWebHookURL"))
    Pause, On
    return
}