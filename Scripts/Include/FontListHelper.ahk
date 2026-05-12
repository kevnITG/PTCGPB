GetAllFontNames() {
    fontNames := "Segoe UI||Arial|Calibri|Times New Roman|"
    fontNames .= "Microsoft JhengHei|Microsoft YaHei|"
    fontNames .= "SimSun|Tahoma|Verdana|Courier New|"
    return fontNames
}

ShowFontListGui(ByRef selectedFont) {
    global FontChoice
    fontList := GetAllFontNames()
    if (fontList = "") {
        MsgBox, Can't get list！
        selectedFont := ""
        return
    }
    Gui, FontList:New
    Gui, FontList:+AlwaysOnTop
    Gui, FontList:Add, DropDownList, vFontChoice w300, %fontList%
    Gui, FontList:Add, Button, gFontListOK, Choose
    Gui, FontList:Show,, Font Choose
    WinWaitClose, Font Choose
    selectedFont := FontChoice
    Gui, FontList:Destroy
    return
}