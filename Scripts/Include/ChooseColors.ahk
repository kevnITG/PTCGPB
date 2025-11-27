ChooseColors(GuiOptions:="", Colors*) { ;                 ChooseColors() v0.97 by SKAN, on D46L/D47K @ tiny.cc/choosecolors
    Local
    _Batchlines:= A_BatchLines
    SetBatchLines -1

    TextFont  :=  ["s11", "Calibri"]
    MonoFont  :=  ["S12", "Consolas"]
    CancelW   :=   70    ;  min 60 px max 80 px
    CancelH   :=   24    ;  min 23 px max 32 px
    SliderH   :=    3    ;  min  1 px max 14 px
    KeyUp  :=  "F1"   ;  Key for adding colors to History

    Glob := { "Gui":{}, "Func":{}, "CoordMode":{}, "Settings":{}, "Paint":1, "Esc":0 }

    Loop % ( Min(Colors.Count(), 25), Var := "")
        Var .= Format("{:06X}", "0x" . Colors[A_Index]) . "|"
    Glob.Que := RTrim(Var, "|")

    Color          :=  OldColor := ( StrLen(Glob.Que) ? StrSplit(Glob.Que, "|",, 2).1 : "FF0000" )
    Glob.SysColor  :=  Format("0x{5:}{6:}{3:}{4:}{1:}{2:}", StrSplit( Format("{:06X}"
        , DllCall("User32.dll\GetSysColor", "Int",15)))* )

    Title          :=  StrLen(GuiOptions.Title) ? GuiOptions.Title : "ChooseColors()"
    NewOptions     :=  GuiOptions.New
    ShowOptions    :=  GuiOptions.Show
    DefaultOpts    :=  "-Resize +Sysmenu +LabelChooseColors_Gui +HwndhGui"
    Glob.Menu      :=  "|" . StrReplace(StrReplace(GuiOptions.Menu, "`r`n", "`n"), "`n", "|") . "|[]"
    _DefaultGui    :=  A_DefaultGUI
    Gui, ChooseColors: New, +AlwaysOnTop %NewOptions% %DefaultOpts%, %Title%
    Gui, %_DefaultGui%: Default

    ChooseColors_RegisterClass(Glob, True) ; Register "CcStatic"

    Glob.CCUI      := "ahk_id" . (Glob.Gui.Hwnd := hGui)
    Glob.Gui.Hicon := ChooseColors_GetIcon("caption.png")
    DllCall("SendMessage", "Ptr",Glob.Gui.Hwnd, "Int",WM_SETICON:=0x80, "Ptr",0, "Ptr",Glob.Gui.Hicon)
    Glob.Func.Keypressed        :=  Func("ChooseColors_Keypress").Bind(KeyUp)

    Glob.Func.Gui               :=  Func("ChooseColors_Gui").Bind(Glob)
    Glob.Func.GuiControl        :=  Func("ChooseColors_GuiControl").Bind(Glob)
    Glob.Func.GuiControlGet     :=  Func("ChooseColors_GuiControlGet").Bind(Glob)
    Glob.Func.SetImage          :=  Func("ChooseColors_SetImage")
    Glob.Func.CreateGradient    :=  Func("ChooseColors_CreateGradient")
    Glob.Func.CreateBitmap      :=  Func("ChooseColors_CreateBitmap")

    Glob.Func.CreateBitmapText  :=  Func("ChooseColors_CreateBitmapText").Bind(Glob)
    Glob.Func.Settings          :=  Func("ChooseColors_Settings").Bind(Glob)
    Glob.Func.CoordMode         :=  Func("ChooseColors_CoordMode").Bind(Glob)
    Glob.Func.GetHexColor       :=  Func("ChooseColors_GetHexColor").Bind(Glob)
    Glob.Func.SetColorName      :=  Func("ChooseColors_SetColorName").Bind(Glob)
    Glob.Func.HistorySetBitmap  :=  Func("ChooseColors_HistorySetBitmap").Bind(Glob)
    Glob.Func.SetImageAnimate   :=  Func("ChooseColors_SetImageAnimate").Bind(Glob)
    Glob.Func.EditHex           :=  Func("ChooseColors_Hex").Bind(Glob)
    Glob.Func.ClipCursor        :=  Func("ChooseColors_ClipCursor")
    Glob.Func.GetWindowRect     :=  Func("ChooseColors_GetWindowRect")
    Glob.Func.GetMonitorRect    :=  Func("ChooseColors_GetMonitorRect")
    Glob.Func.SetRect           :=  Func("ChooseColors_SetRect")
    Glob.Func.GetImage          :=  Func("ChooseColors_GetImage")
    Glob.Func.DeleteBitmap      :=  Func("ChooseColors_DeleteBitmap")
    Glob.Func.UpdateRGBHSL      :=  Func("ChooseColors_UpdateRGBHSL")
    Glob.Func.SetSystemCursor   :=  Func("ChooseColors_SetSystemCursor")
    Glob.Func.MemDC             :=  Func("ChooseColors_MemDC")

    Gui            :=  Glob.Func.Gui
    GuiControl     :=  Glob.Func.GuiControl
    GuiControlGet  :=  Glob.Func.GuiControlGet
    SetImage       :=  Glob.Func.SetImage
    CreateBitmap   :=  Glob.Func.CreateBitmap
    CreateGradient :=  Glob.Func.CreateGradient
    AddUpDown      :=  Func("ChooseColors_AddUpDown").Bind(Glob)
    AddGoSub       :=  Func("ChooseColors_GoSub").Bind(Glob)

    Gui.Call("+DpiScale")
    Gui.Call("Font", TextFont*)
    Gui.Call("Margin", 0, 0)

    Gui.Call("Add", "Button", "HwndCancelB x0 y0 w0 h0 -Tabstop", "&Cancel")
    AddGoSub.Call("CancelB", "ChooseColors_GuiCancel", Glob)
    Gui.Call("Add", "Button", "HwndOkayB Default x+0 yp w0 h0 -Tabstop", "&Ok")
    AddGoSub.Call("OkayB", "ChooseColors_GuiOkay", Glob)

    Gui.Call("Add", "Custom",   "HwndGradient CcStatic w288 h288 SS_NOTIFY SS_REALSIZECONTROL SS_BITMAP")
    AddGoSub.Call("Gradient", "ChooseColors_HueSelect", Glob)
    Gui.Call("Add", "Custom",   "HwndHue CcStatic x0 y+0 w288 h16 SS_NOTIFY SS_REALSIZECONTROL SS_BITMAP")
    AddGoSub.Call("Hue", "ChooseColors_HueSelect", Glob)
    HueColors := [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFF0000]
    Hbm := CreateGradient.Call(Glob.Hue.W, 1, False, HueColors*)
    SetImage.Call(Glob.Hue.Hwnd, Hbm, 1)

    SH := Max(2, Min(14, SliderH))
    Gui.Call("Margin", 16, 12)
    Gui.Call("Add", "Text",     "x16  w16 Section", "R")
    Gui.Call("Add", "Text",     "x+0 w0", "&R")
    Gui.Call("Add", "Edit",     "HwndEditR x+0 w40 h26 Number Limit3 Right")
    AddGoSub.Call("EditR", "ChooseColors_RGB", Glob)
    AddUpDown.Call("EditR",     "HwndUpdown Range0-255")
    Gui.Call("Add", "Custom",   "HwndSlider1 CcStatic x16 y+0 w56 h14 SS_NOTIFY SS_CENTERIMAGE SS_BITMAP", Glob.Updown.Hwnd)
    AddGoSub.Call("Slider1", "ChooseColors_Slider", Glob)
    Tbm := CreateBitmap.Call(Glob.Slider1.W, SH, 0xDD0000),   SetImage.Call(Glob.Slider1.Hwnd, Tbm)

    Gui.Call("Margin", 16, 6)
    Gui.Call("Add", "Text",     "x16  w16", "G")
    Gui.Call("Add", "Text",     "x+0 w0", "&G")
    Gui.Call("Add", "Edit",     "HwndEditG x+0 w40 h26 Number Limit3 Right")
    AddGoSub.Call("EditG", "ChooseColors_RGB", Glob)
    AddUpDown.Call("EditG",     "HwndUpdown Range0-255")
    Gui.Call("Add", "Custom",   "HwndSlider2 CcStatic x16 y+0 w56 h14 SS_NOTIFY SS_CENTERIMAGE SS_BITMAP", Glob.Updown.Hwnd)
    AddGoSub.Call("Slider2", "ChooseColors_Slider", Glob)
    Tbm := CreateBitmap.Call(Glob.Slider2.W, SH, 0x00DD00),   SetImage.Call(Glob.Slider2.Hwnd, Tbm)

    Gui.Call("Add", "Text",     "x16  w16", "B")
    Gui.Call("Add", "Text",     "x+0 w0", "&B")
    Gui.Call("Add", "Edit",     "HwndEditB x+0 w40 h26 Number Limit3 Right")
    AddGoSub.Call("EditB", "ChooseColors_RGB", Glob)
    AddUpDown.Call("EditB",     "HwndUpdown Range0-255")
    Gui.Call("Add", "Custom",   "HwndSlider3 CcStatic x16 y+0 w56 h14 SS_NOTIFY SS_CENTERIMAGE SS_BITMAP", Glob.Updown.Hwnd)
    AddGoSub.Call("Slider3", "ChooseColors_Slider", Glob)
    Tbm := CreateBitmap.Call(Glob.Slider3.W, SH, 0x0000DD),   SetImage.Call(Glob.Slider3.Hwnd, Tbm)

    Gui.Call("Add", "Text",     "x+m ys w16 Section", "H")
    Gui.Call("Add", "Text",     "x+0 w0", "&H")
    Gui.Call("Add", "Edit",     "HwndEditH x+0 w40 h26 Number Limit3 Right")
    AddGoSub.Call("EditH", "ChooseColors_HLS", Glob)
    AddUpDown.Call("EditH",     "HwndUpdown Range0-360 Wrap")
    Gui.Call("Add", "Text",     "x+4 w12 hp 0x200 Disabled", Chr(176))
    Gui.Call("Add", "Custom",   "HwndSlider4 CcStatic xs y+0 w56 h14 SS_NOTIFY SS_CENTERIMAGE SS_BITMAP", Glob.Updown.Hwnd)
    AddGoSub.Call("Slider4", "ChooseColors_Slider", Glob)
    Tbm := CreateGradient.Call(Glob.Slider4.W, SH, False, HueColors*),    SetImage.Call(Glob.Slider4.Hwnd, Tbm)

    Gui.Call("Add", "Text",     "xs w16 hp", "S")
    Gui.Call("Add", "Text",     "x+0 w0", "&S")
    Gui.Call("Add", "Edit",     "HwndEditS x+0 w40 h26 Number Limit3 Right")
    AddGoSub.Call("EditS", "ChooseColors_HLS", Glob)
    AddUpDown.Call("EditS",     "HwndUpdown Range0-100")
    Gui.Call("Add", "Text",     "x+4 w12 hp 0x200 Disabled", "%")
    Gui.Call("Add", "Custom",   "HwndSlider5 CcStatic xs y+0 w56 h14 SS_NOTIFY SS_CENTERIMAGE SS_BITMAP", Glob.Updown.Hwnd)
    AddGoSub.Call("Slider5", "ChooseColors_Slider", Glob)
    Tbm := CreateGradient.Call(Glob.Slider5.W, SH, False, 0x7F7F7F, 0x7F7F7F, 0x7F7F7F)
    SetImage.Call(Glob.Slider5.Hwnd, Tbm)

    Gui.Call("Add", "Text",     "xs w16 hp", "L")
    Gui.Call("Add", "Text",     "x+0 w0", "&L")
    Gui.Call("Add", "Edit",     "HwndEditL x+0 w40 h26 Number Limit3 Right")
    AddGoSub.Call("EditL", "ChooseColors_HLS", Glob)
    AddUpDown.Call("EditL",     "HwndUpdown Range0-100")
    Gui.Call("Add", "Text",     "x+2 w12 hp 0x200 Disabled", "%")
    Gui.Call("Add", "Custom",   "HwndSlider6 CcStatic xs y+0 w56 h14 SS_NOTIFY SS_CENTERIMAGE SS_BITMAP", Glob.Updown.Hwnd)
    AddGoSub.Call("Slider6", "ChooseColors_Slider", Glob)
    Tbm := CreateGradient.Call(Glob.Slider6.W, SH, False, 0x444444, 0xAAAAAA, 0xFFFFFF)
    SetImage.Call(Glob.Slider6.Hwnd, Tbm)

    Gui.Call("Add", "Text",     "HwndColorName x16 y+0 w250 h16 SS_CENTERIMAGE Right")
    Gui.Call("Add", "Custom",   "HwndHistory CcStatic y+2 w250 h12 SS_NOTIFY SS_REALSIZECONTROL SS_BITMAP +E0x20000")
    AddGoSub.Call("History", "ChooseColors_HueSelect2", Glob)
    Gui.Call("Add", "Button",   "HwndDelQB xp yp w0 hp -Tabstop", "&D", hDelQB:=0)
    AddGoSub.Call("DelQB", "ChooseColors_DelColorFmQ", Glob)

    Gui.Call("Margin", 16, 12)
    IH := Max(23, Min(32, CancelH))
    Gui.Call("Add", "Picture",  "HwndPickScr x16 y+m w24 Left SS_CENTERIMAGE SS_ICON h" . IH)
    GuiControl.Call("", Glob.PickScr.Hwnd, "*w0 *h0 hicon:" . ChooseColors_GetIcon("pickscr.png"))
    AddGoSub.Call("PickScr", "ChooseColors_PickScr", Glob)

    Gui.Call("Add", "Picture",  "HwndPickClr x+8 yp wp hp SS_CENTERIMAGE SS_ICON")
    GuiControl.Call("", Glob.PickClr.Hwnd, "*w0 *h0 hicon:" . ChooseColors_GetIcon("pickclr.png"))
    AddGoSub.Call("PickClr", "ChooseColors_PickScr", Glob)

    CW := Max(60, Min(80, CancelW))
    Gui.Call("Add", "Custom",     "HwndCancel CcStatic x+m hp -Tabstop Center SS_NOTIFY SS_BITMAP w" . CW, "&Cancel")
    AddGoSub.Call("Cancel", "ChooseColors_GuiCancel", Glob)
    Tbm := Glob.Func.CreateBitmapText.Call(Glob.Cancel.Hwnd)
    SetImage.Call(Glob.Cancel.Hwnd, Tbm)

    Gui.Call("Add", "Custom",     "HwndOkay   CcStatic x+m hp -Tabstop Center SS_NOTIFY SS_BITMAP w" . (CW//3)*2, "&OK")

    AddGoSub.Call("Okay", "ChooseColors_GuiOkay", Glob)
    Tbm := Glob.Func.CreateBitmapText.Call(Glob.Okay.Hwnd)
    SetImage.Call(Glob.Okay.Hwnd, Tbm)

    Gui.Call("Margin", 16, 6)
    Gui.Call("Add", "Text",     "x157 ys w40 Right Section h40 BackgroundTrans", "Old")
    Gui.Call("Add", "Progress", "x+6 w68 hp Disabled Border Background" . OldColor)
    Gui.Call("Add", "Custom",   "HwndOld CcStatic xp yp wp hp BackgroundTrans SS_NOTIFY WS_EX_STATICEDGE")
    AddGoSub.Call("Old", "ChooseColors_SetNew", Glob, OldColor)

    Gui.Call("Add", "Text",     "HwndRandom  xs w40 y+m hp Right", "New")
    Gui.Call("Add", "Button",   "HwndRandomB x+0 yp w0 hp -Tabstop", "&N")
    AddGoSub.Call("Random",  "ChooseColors_GenRandom", Glob)
    AddGoSub.Call("RandomB", "ChooseColors_GenRandom", Glob)
    Gui.Call("Add", "Progress", "HwndNew x+6 w68 hp Disabled Border Background" . OldColor)
    Gui.Call("Add", "Custom",   "HwndPreview CcStatic xp yp wp hp BackgroundTrans SS_NOTIFY WS_EX_STATICEDGE")
    AddGoSub.Call("Preview", "ChooseColors_Preview", Glob, Glob.Preview.Hwnd)

    Gui.Call("Add", "Text",     "HwndAddQ xs y+m w40 h26 Right", "#")
    Gui.Call("Add", "Button",   "HwndAddQB x+0 yp w0 h0 -Tabstop", "&A")
    AddGoSub.Call("AddQ",  "ChooseColors_AddColorToQ", Glob)
    AddGoSub.Call("AddQB", "ChooseColors_AddColorToQ", Glob)
    Gui.Call("Add", "Text",     "x+0 w0", "&X")

    Gui.Call("Font", MonoFont*)
    Gui.Call("Add", "Edit",     "HwndEdit0 x+6  w0 h0 ReadOnly -Tabstop", &Glob)
    Gui.Call("Add", "Edit",     "HwndEditHex xp yp w68 h26 Uppercase Limit6 Right", Color)
    AddGoSub.Call("EditHex", "ChooseColors_Hex", Glob)
    Gui.Call("Font", TextFont*)

    Gui.Call("-DpiScale")

    RM := Glob.Old.W + Glob.Old.X
    GuiControl.Call("Move", Glob.Okay.Hwnd,   "x" . RM - Glob.Okay.W )
    GuiControl.Call("Move", Glob.Cancel.Hwnd, "x" . RM - Glob.Okay.W - Glob.PickScr.X - Glob.Cancel.W)
    NW := (Glob.History.W // 25) * 25
    GuiControl.Call("Move", Glob.ColorName.Hwnd, "x" . (RM-NW) . " w" . (NW))
    GuiControl.Call("Move", Glob.History.Hwnd,   "x" . (RM-NW) . " w" . (NW))
    GuiControl.Call("Move", Glob.PickScr.Hwnd,   "x" . (RM-NW))
    GuiControlGet.Call("Pos", Glob.PickScr.Hwnd, X, Y, W, H)
    GuiControl.Call("Move", Glob.PickClr.Hwnd,   "x" . (X + W + (8*(A_ScreenDPI/96))))

    Gui.Call("+DpiScale")

    Dim := Glob.Hue.W
    ChooseColors_GradientStruct(Dim, VERT, MESH)
    hMainBM := CreateBitmap.Call(Dim, Dim)
    Glob.Func.MemDC.Call(hMainDC, hMainBM)

    Glob.Func.GradientPaint := Func("ChooseColors_GradientPaint").Bind(hMainDC, &VERT, &MESH, Dim, Glob.Gradient.Hwnd)
    Glob.Func.GradientSet   := Func("ChooseColors_GradientSet").Bind(Glob.Gradient.Hwnd, hMainBM)

    hMsimg32 := DllCall("Kernel32.dll\LoadLibrary", "Str","Msimg32.dll", "Ptr")
    hShlwapi := DllCall("Kernel32.dll\LoadLibrary", "Str","Shlwapi.dll", "Ptr")
    Glob.Func.HistorySetBitmap()

    Gui.Call("Margin", 0, 12)
    Gui.Call("Show", "Hide AutoSize xCenter yCenter")

    Glob.Func.GradientPaint.Call("0x" . Color)
    Glob.Func.GradientSet.Call()
    Gui.Call("Show", ShowOptions . " AutoSize")
    GuiControl.Call("", Glob.EditHex.Hwnd, Color)

    If ( WinActive("ahk_id" . Glob.Gui.Hwnd) )
        GuiControl.Call("Focus", Glob.EditHex.Hwnd)

    SetBatchLines, %_Batchlines%
    Glob.Okay := False
    WinWaitClose, % "ahk_id" . Glob.Gui.Hwnd

    Glob.Func.MemDC.Call(hMainDC, False)
    Glob.Func.DeleteBitmap.Call(hMainBM)
    DllCall("User32.dll\DestroyIcon", "Ptr",Glob.Gui.Hicon)
    DllCall("Kernel32.dll\FreeLibrary", "Ptr",hMsimg32)
    DllCall("Kernel32.dll\FreeLibrary", "Ptr",hShlwapi)
    ChooseColors_RegisterClass(Glob, False) ; Unregister "CcStatic"

    Return ( Glob.Okay ? StrSplit(Glob.Que, "|") : "" )
}
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

ChooseColors_GuiOkay(Glob) {
    If ! ( StrLen(Glob.Que) )
        SoundPlay *-1
    Else DllCall("SendMessage", "Ptr",Glob.Gui.Hwnd, "Int",0x10 * (Glob.Okay := True), "Ptr",0, "Ptr",0) ; WM_CLOSE
}

ChooseColors_GuiCancel(Glob) {
    DllCall("SendMessage", "Ptr",Glob.Gui.Hwnd, "Int",0x10, "Ptr",0, "Ptr",0)                       ; WM_CLOSE
}

ChooseColors_GuiEscape(hGui) {
    If ( GetKeyState("LButton", "P") = False )
        DllCall("SendMessage", "Ptr",hGui, "Int",0x10, "Ptr",0, "Ptr",0)                           ; WM_CLOSE
    Return
}

ChooseColors_GuiClose(hGui) {
    Gui, %hGui%:Destroy
}

ChooseColors_GuiContextMenu(GuiHwnd, CtrlHwnd, EventInfo, IsRightClick, X, Y) {
    Local
    GuiControlGet, ObjPtr, %GuiHwnd%:, Edit7
    Glob := Object(ObjPtr)
    MouseGetPos,,,, hCtrl, 2
    Switch ( hCtrl )
    {
    Case Glob.History.Hwnd  : ChooseColors_HistoryMenu(Glob)
    Case Glob.Gradient.Hwnd : ChooseColors_PaletteMenu(Glob, Glob.Gradient.Hwnd)
    Case Glob.Preview.Hwnd  : ChooseColors_PaletteMenu(Glob, Glob.Preview.Hwnd)
    }
}
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

ChooseColors_RegisterClass(Glob, Register:=1) {
    Local
    If ( Register=False )
    {
        DllCall("Kernel32.dll\GlobalFree", "Ptr",Glob.StaticProc, "Ptr")
        Return DllCall("User32.dll\UnregisterClass", "Str","CcStatic", "Ptr",0)
    }

    P8 := (A_PtrSize=8),    Classname   := "CcStatic"
    VarSetCapacity(WNDCLASS, P8 ? 72 : 40, 0)
    DllCall("User32.dll\GetClassInfo", "Ptr",0, "Str","Static", "Ptr",&WNDCLASS)

    OldProc     := NumGet(WNDCLASS, A_PtrSize, "Ptr")
    StaticProc  := Glob.StaticProc := RegisterCallback("ChooseColors_CcStaticProc",, 4, OldProc)
    hCursor     := DllCall("User32.dll\LoadCursor", "Ptr",0, "Int",32649, "Ptr") ; IDC_HAND

    NumPut(hCursor,     WNDCLASS, P8 ? 40 : 24, "Ptr")
    NumPut(StaticProc,  WNDCLASS, A_PtrSize, "Ptr")
    NumPut(&Classname,  WNDCLASS, P8 ? 64 : 36, "Ptr")

    Return DllCall("User32.dll\RegisterClass", "Ptr",&WNDCLASS)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_CcStaticProc(Hwnd, Msg, WP, LP) {
    Local
    If ( Msg = 2 ) ; WM_DESTROY
        If ( Hbm := DllCall("User32.dll\SendMessage", "Ptr",Hwnd, "Int",0x173, "Ptr",0, "Ptr",0, "Ptr") ) ; STM_GETIMAGE
            DllCall("Gdi32.dll\DeleteObject", "Ptr",Hbm)

    Return DllCall("User32.dll\CallWindowProc", "Ptr",A_EventInfo, "Int",Hwnd, "Int",Msg, "Ptr",WP, "Ptr",LP)
}
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

ChooseColors_Preview(Glob, hCtrl:=0) {
    Local
    If GetKeyState("Shift", "P")
        Return ChooseColors_AddColorToQ(Glob, hCtrl, "")

    Glob.Func.GetHexColor.Call(Color)
    Hbm := Glob.Func.CreateBitmap.Call(1, 1)
    DllCall("Gdi32.dll\SetBitmapBits", "Ptr",Hbm, "UInt",4*1, "UIntP","0x" . Color)
    Glob.Func.SetImage.Call(Glob.Gradient.Hwnd, Hbm, True)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_HLS(Glob, hCtrl, GuiEvent, EventInfo) {
    Local
    If ( DllCall("User32.dll\GetFocus", "Ptr") != hCtrl )
        Return

    GuiControl    := Glob.Func.GuiControl
    GuiControlGet := Glob.Func.GuiControlGet

    GuiControlGet.Call("", Glob.EditH.Hwnd, H:=0)
    GuiControlGet.Call("", Glob.EditL.Hwnd, L:=0)
    GuiControlGet.Call("", Glob.EditS.Hwnd, S:=0)

    Color := DllCall("Shlwapi.dll\ColorHLSToRGB", "Short",H/1.5, "Short",L*2.4, "Short",S*2.4, "UInt")
    Color := Format( "{5:}{6:}{3:}{4:}{1:}{2:}", StrSplit(Format("{:06X}", Color))*)
    GuiControl.Call("", Glob.EditHex.Hwnd, Color)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_RGB(Glob, hCtrl, GuiEvent, EventInfo) {
    Local
    If ( DllCall("User32.dll\GetFocus", "Ptr") != hCtrl )
        Return

    GuiControl    := Glob.Func.GuiControl
    GuiControlGet := Glob.Func.GuiControlGet

    GuiControlGet.Call("", Glob.EditR.Hwnd, R)
    GuiControlGet.Call("", Glob.EditG.Hwnd, G)
    GuiControlGet.Call("", Glob.EditB.Hwnd, B)

    Color := Format("{:02X}{:02X}{:02X}", Min(R, 255), Min(G, 255), Min(B, 255))
    GuiControl.Call("", Glob.EditHex.Hwnd, Color)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GetHexColor(Glob, ByRef Color:="") {
    Local
    Glob.Func.GuiControlGet.Call("", Glob.EditHex.Hwnd, Color:="")
    Return ( Color := Format("{:06X}", "0x" . Color) )
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_Hex(Glob, hEditHex, GuiEvent, EventInfo) {
    Local
    Critical On
    Glob.Func.GetHexColor.Call(Hex)
    Glob.Func.GuiControl.Call("+Background" . Hex, Glob.New.Hwnd)
    Glob.Func.SetColorName.Call(Hex)
    Glob.Func.UpdateRGBHSL.Call(Glob, Hex)

    If ( Glob.Paint=True )
        Glob.Func.GradientPaint.Call("0x" . Hex)

    If ( GetKeyState("LButton", "P")=False )
    {
        GradientSet := Glob.Func.GradientSet
        SetTimer, %GradientSet%, -100
    }
    Critical Off
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_UpdateRGBHSL(Glob, Hex) {
    Local
    hFocus        := DllCall("User32.dll\GetFocus", "Ptr")
    GuiControl    := Glob.Func.GuiControl
    Color  := Format( "0x{5:}{6:}{3:}{4:}{1:}{2:}", StrSplit(Hex)*)
    DllCall("Shlwapi.dll\ColorRGBToHLS", "Int",Color, "ShortP",H:=0, "ShortP",L:=0, "ShortP",S:=0)

    _ := ( Glob.EditH.Hwnd = hFocus ) ? 0 : GuiControl.Call("", Glob.EditH.Hwnd, Round(H*1.5))
        , _ := ( Glob.EditL.Hwnd = hFocus ) ? 0 : GuiControl.Call("", Glob.EditL.Hwnd, Round(L/2.4))
        , _ := ( Glob.EditS.Hwnd = hFocus ) ? 0 : GuiControl.Call("", Glob.EditS.Hwnd, Round(S/2.4))
        , RGB := Format("0x{:x}", "0x" . Hex) + 0
        , _ := ( Glob.EditR.Hwnd = hFocus ) ? 0 : GuiControl.Call("", Glob.EditR.Hwnd, RGB>>16 & 255)
        , _ := ( Glob.EditG.Hwnd = hFocus ) ? 0 : GuiControl.Call("", Glob.EditG.Hwnd, RGB>>8  & 255)
        , _ := ( Glob.EditB.Hwnd = hFocus ) ? 0 : GuiControl.Call("", Glob.EditB.Hwnd, RGB     & 255)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GetMonitorRect(Hwnd, ByRef RECT:="", ByRef x1:=0, ByRef y1:=0, ByRef x2:=0, ByRef y2:=0) {
    Local
    hMon := DllCall("User32.dll\MonitorFromWindow", "Ptr",HWnd, "Int",0x2, "Ptr") ; _DEFAULTTONEAREST = 0x2
        , VarSetCapacity(MONITORINFO, 40, 0), NumPut(40, MONITORINFO, "Int")
        , DllCall("User32.dll\GetMonitorInfo", "Ptr",hMon, "Ptr",&MONITORINFO)
        , VarSetCapacity(RECT, 16)
        , x1 := NumGet(MONITORINFO,  4, "Int"),    y1 := NumGet(MONITORINFO,  8, "Int")
        , x2 := NumGet(MONITORINFO, 12, "Int"),    y2 := NumGet(MONITORINFO, 16, "Int")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GetWindowRect(Hwnd, ByRef RECT:="", ByRef x1:=0, ByRef y1:=0, ByRef x2:=0, ByRef y2:=0) {
    Local
    VarSetCapacity(RECT, 16)
        , DllCall("User32.dll\GetWindowRect", "Ptr",Hwnd, "Ptr",&RECT)
        , x1 := NumGet(RECT,0, "Int"),   y1 := NumGet(RECT,4, "Int")
        , x2 := NumGet(RECT,8, "Int"),   y2 := NumGet(RECT,12,"Int")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_SetRect(ByRef RECT, x1, y1, x2, y2) {
    Local
    VarSetCapacity(RECT, 16)
    DllCall("User32.dll\SetRect", "Ptr",&RECT, "Int",x1, "Int",y1, "Int",x2, "Int",y2)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_SetSystemCursor(Which:=0, With:=0) {
    Local
    If ! ( Which ) ;                             SPI_SETCURSORS := 0x57
        Return DllCall("User32.dll\SystemParametersInfo", "Int",0x57, "Int",0, "Int",0, "Int",0)

    IDC := { "IDC_APPSTARTING":32650, "IDC_ARROW":32512, "IDC_CROSS":32515, "IDC_HAND":32649
        , "IDC_HELP":32651, "IDC_IBEAM":32513, "IDC_NO":32648, "IDC_SIZEALL":32646, "IDC_SIZENESW":32643
        , "IDC_SIZENS":32645, "IDC_SIZENWSE":32642, "IDC_SIZEWE":32644, "IDC_UPARROW":32516, "IDC_WAIT":32514 }

    hCursor  := DllCall("User32.dll\LoadCursor", "Ptr",0, "Int",IDC[With], "Ptr")
    DllCall("User32.dll\SetSystemCursor", "Ptr",hCursor, "Int",IDC[Which])
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_ClipCursor(ByRef RECT:=0) {
    Local
    DllCall("User32.dll\ClipCursor", "Ptr",IsByRef(RECT) ? &RECT : 0)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GradientSet(hGradient, hMainBM) {
    Local ; ; STM_GETIMAGE = 0x173
    Hbm := DllCall("User32.dll\CopyImage", "Ptr",hMainBM, "Int",0x0, "Int",0, "Int",0, "Int",0x2000, "Ptr")
    ChooseColors_SetImage(hGradient, Hbm)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GradientPaint(mDC, pVERT, pMESH, W, hGradient, Color) {
    Local
    Color := Format("{:06X}", Color & 0xFFFFFF)
        , Color := Format("0x{5:}{6:}00{3:}{4:}00{1:}{2:}00", StrSplit(Color)*)
        , NumPut(Color, pVERT+24, "Int64")
        , DllCall("Msimg32.dll\GradientFill", "Ptr",mDC, "Ptr",pVERT, "Int",4, "Ptr",pMESH, "Int",2, "Int",2)
        , hDC := DllCall("User32.dll\GetDC", "Ptr",hGradient, "Ptr")
        , DllCall("Gdi32.dll\GdiAlphaBlend"
        , "Ptr",hDC, "Int",0, "Int",0, "Int",W, "Int",W
        , "Ptr",mDC, "Int",0, "Int",0, "Int",W, "Int",W, "Int",16711680) ; 0x00FF0000 = 16711680
        , DllCall("User32.dll\ReleaseDC", "Ptr",hGradient, "Ptr",hDC)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GradientMemDC(ByRef mDC, W:=0) {
    Local
    If ( W )
        Hbm := DllCall("Gdi32.dll\CreateBitmap", "Int",1, "Int",1, "Int",0x1, "Int",24, "PtrP",0, "Ptr")
            , Hbm := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0x0, "Int",W, "Int",W, "Int",0x200C, "Ptr")
            , mDC := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr",0, "Ptr")
            , DllCall("Gdi32.dll\SaveDC", "Ptr",mDC)
            , DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",Hbm)
    Else
        DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
            , mDC := DllCall("Gdi32.dll\DeleteDC", "Ptr",mDC) * 0
            , Hbm := DllCall("Gdi32.dll\DeleteObject", "Ptr",Hbm) * 0
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GradientStruct(W, ByRef VERT, ByRef MESH) {
    Local
    VarSetCapacity(VERT, 4*16, 0),   VarSetCapacity(MESH, 2*12, 0)
        , NumPut(0xFE00CA00DE00, NumPut(0xFF00FF00FF00, VERT, 8, "Int64")+8, "Int64")
        , NumPut(W, NumPut(W, NumPut(W, NumPut(W, VERT, 16, "Int")+16, "Int")+8, "Int"), "Int")
        , NumPut(1, NumPut(3, NumPut(2, NumPut(2, NumPut(1, MESH, 4, "Int"), "Int"), "Int"), "Int"), "Int")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_SetNew(Glob, Color, Esc:=0) {
    Local
    Glob.Esc := Esc
    Glob.Func.GuiControl.Call("Focus", Glob.EditHex.Hwnd)
    Glob.Func.GuiControl.Call("", Glob.EditHex.Hwnd, Color)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_HueSelect2(Glob, hCtrl, GuiEvent, EventInfo) {
    Local
    Glob.Func.CoordMode.Call("Save")
    MouseGetPos, X, Y
    PixelGetColor, Color, %X%, %Y%, RGB
    Color := SubStr(Color, 3)
    Glob.Func.CoordMode.Call("Restore")

    If ( InStr(Glob.Que, Color) = False )
        Return

    If ( GetKeyState("Shift", "P")=False )
        Return ChooseColors_HueSelect(Glob, hCtrl, GuiEvent, EventInfo)

    ChooseColors_DelColorFmQ(Glob, 0, Color)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_HueSelect(Glob, hCtrl, GuiEvent, EventInfo) {
    Local
    Glob.Func.Settings.Call("Save")
    Glob.Func.GuiControl.Call("Focus", Glob.Edit0.Hwnd)

    Glob.Func.GetWindowRect.Call(hCtrl, RECT, x1, y1, x2, y2)
    If ( hCtrl = Glob.History.Hwnd )
        StrReplace(Glob.Que, "|", "|", nColors:=0)
            , W  := x2 - x1
            , x1 :=  x1 + (W // 25) * (24-nColors) + 1
            , x2 -= 1

    If   ( hCtrl != Glob.Gradient.Hwnd )
        y3 := y1 + ((y2-y1)//2)
            ,  _  := Glob.Func.SetRect.Call(RECT, x1, y3, x2, y3+1)
    Else ( Glob.Paint := False )

        Glob.Func.ClipCursor.Call(RECT)
    PColor := 0, Color := ""
    While ( WinActive(Glob.CCUI) && GetKeyState("LButton", "P") && !GetKeyState("Escape", "P") )
    {
        Sleep 1
        MouseGetPos, X, Y
        PixelGetColor, Color, %X%, %Y%, RGB
        Color := SubStr(Color,3)

        If ( Glob.Func.Keypressed() )
            ChooseColors_AddColorToQ(Glob, 0, Color)

        If ( PColor != Color )
            Glob.Func.GuiControl.Call("", Glob.EditHex.Hwnd, PColor:=Color)
    }

    Glob.Esc := ( GetKeyState("Escape", "P")=True || WinActive(Glob.CCUI)=False )
    Glob.Func.ClipCursor.Call(False)

    If ( Glob.Esc )
        Glob.Func.Settings.Call("Restore")
    Else
    {
        If ( hCtrl=Glob.History.Hwnd )
            ChooseColors_AddColorToQ(Glob, 0, Color)
        Glob.Func.Settings.Call("Clear")
    }
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_Slider(Glob, hCtrl, GuiEvent, EventInfo) {
    Local
    Glob.Func.Settings.Call("Save")

    Glob.Func.GuiControlGet.Call("", hCtrl, hUpDown:=0)
    DllCall("SendMessage", "Ptr",hUpDown, "Int",UDM_GETRANGE32 := 0x470, "PtrP",Min:=0, "PtrP",Max:=0)
    Glob.Func.GuiControlGet.Call("", hUpdown, Pos:=0)
    Glob.Func.GuiControl.Call("", hUpDown, Pos)
    hBuddy  := DllCall("User32.dll\SendMessage", "Ptr",hUpDown, "Int",UDM_GETBUDDY := 0x46A, "Ptr",0, "Ptr",0, "Ptr")
    Glob.Func.GuiControl.Call("Focus", hBuddy)

    Glob.Func.GetWindowRect.Call(hCtrl, RECT, x1, y1, x2, y2)
    y3 := y1 + ((y2-y1)//2)          ; Vertical center
    W  := x2 - x1 - 1                ; Width of control
    X  := X1 + Round(W * (Pos/Max))  ; Find X pos for MouseMove
    Glob.Func.SetRect.Call(RECT, x1, y3, x2, y3+1)

    SavedX := X
    MouseMove, %X%, %y3%, 0
    Glob.Func.ClipCursor.Call(RECT)

    PX := 0
    While ( WinActive(Glob.CCUI) && GetKeyState("LButton", "P") && !GetKeyState("Escape", "P") )
    {
        Sleep 1
        If ( Glob.Func.Keypressed() )
            Color := Glob.Func.GetHexColor.Call()
                , ChooseColors_AddColorToQ(Glob, 0, Color)

        MouseGetPos, X
        If ( PX =  X )
            Continue
        Else PX := X

            Val := ( (X-X1) / W )
        Glob.Func.GuiControl.Call("", hUpDown, Max*Val)

        If ( Max=255 )
            Tooltip % Round(Val*100) . "%",,, 20
    }

    Glob.Esc := ( GetKeyState("Escape", "P")=True || WinActive(Glob.CCUI)=False )
    Glob.Func.ClipCursor.Call(False)
    If ( Max=255 )
        Tooltip,,,, 20

    If ( Glob.Esc )
        Glob.Func.Settings.Call("Restore")
    Else Glob.Func.Settings.Call("Clear")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_PickScr(Glob, hCtrl, GuiEvent, EventInfo) {
    Local
    Glob.Func.Settings.Call("Save")

    TW            := Glob.Hue.W
    Glob.Func.GetWindowRect.Call(hCtrl, RECT, x1, y1, x2, y2)
    x1 := x1 + ((x2-x1)/2)
    y1 := y1 + ((y2-y1)/2)
    Glob.Func.SetRect.Call(RECT, x1, y1, x1+1, y1+1)
    Glob.Func.ClipCursor.Call(RECT)
    Glob.Func.ClipCursor.Call(False)

    Glob.Func.GuiControl.Call("Focus", Glob.Edit0.Hwnd)
    Glob.Func.GetHexColor.Call(CurrentColor)
    Glob.Func.GuiControlGet.Call("", Glob.ColorName.Hwnd, ColorName)

    PickClr := ( hCtrl = Glob.PickClr.Hwnd )
    SW  := ( PickClr ? 1 : 40*(A_ScreenDPI/96) )
    Off := ( PickClr ? 0 : SW//2 )

    Hbm := Glob.Func.CreateBitmap.Call(SW, SW)
    Glob.Func.MemDC.Call(mDC:=0, Hbm)
    sWnd := DllCall("User32.dll\GetDesktopWindow", "Ptr")
    sDC  := DllCall("User32.dll\GetWindowDC", "Ptr",sWnd, "Ptr")
    tDC  := DllCall("User32.dll\GetWindowDC", "Ptr",Glob.Gradient.Hwnd, "Ptr")

    Glob.Func.GetMonitorRect.Call(Glob.Gui.Hwnd, RECT, x1, y1, x2, y2)
    Glob.Func.SetRect.Call(RECT, x1+Off, y1+Off, x2-Off, y2-Off)
    DllCall("SetForegroundWindow","Ptr",A_ScriptHwnd)
    Glob.Func.ClipCursor.Call(RECT)
    If ( Glob.PickClr.Hwnd )
        ChooseColors_BoxCur(SW, SW)
    Else Glob.Func.SetSystemCursor.Call("IDC_ARROW", "IDC_HELP")

        Glob.Paint := False
    Color := ""
    While ( GetKeyState("LButton", "P") && ! GetKeyState("Escape", "P") )
    {
        Sleep 0
        Glob.Func.ClipCursor.Call(RECT)

        MouseGetPos, X, Y
        X -= Off, Y -= Off

        DllCall("Gdi32.dll\GdiAlphaBlend"
            , "Ptr",mDC, "Int",0, "Int",0, "Int",SW, "Int",SW
            , "Ptr",sDC, "Int",X, "Int",Y, "Int",SW, "Int",SW, "Int",0x00FF0000)

        DllCall("Gdi32.dll\GdiAlphaBlend"
            , "Ptr",tDC, "Int",0, "Int",0, "Int",TW, "Int",TW
            , "Ptr",mDC, "Int",0, "Int",0, "Int",SW, "Int",SW, "Int",0x00FF0000)

        Color := DllCall("Gdi32.dll\GetPixel", "Ptr",mDC, "Int",Off, "Int",Off, "UInt")
        Color := Format("{5:}{6:}{3:}{4:}{1:}{2:}", StrSplit(Format("{:06X}", Color))*)
        Glob.Func.GuiControl.Call("", Glob.EditHex.Hwnd, Color)

        If ( Glob.Func.Keypressed() )
            ChooseColors_AddColorToQ(Glob, 0, Color)
    }

    Glob.Esc   := ( GetKeyState("Escape", "P") || StrLen(Color)=0 )
    Glob.Func.GuiControl.Call("-g", Glob.EditHex.Hwnd)
    Glob.Func.SetSystemCursor.Call(False)
    Glob.Func.ClipCursor.Call(False)

    DllCall("User32.dll\ReleaseDC", "Ptr",sWnd, "Ptr",sDC)
    DllCall("User32.dll\ReleaseDC", "Ptr",Glob.Gradient.Hwnd, "Ptr",tDC)
    Glob.Func.MemDC.Call(mDC)

    If ( Glob.Esc )
        Glob.Func.DeleteBitmap.Call(Hbm)
            , Glob.Func.Settings.Call("Restore")
    Else Glob.Func.SetImage.Call(Glob.Gradient.Hwnd, Hbm, True)
        , Glob.Func.Settings.Call("Clear")

        Glob.Func.Gui.Call("Show")
    Glob.Func.GuiControl.Call("+g", Glob.EditHex.Hwnd, Glob.Func.EditHex)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GenRandom(Glob) {
    Local
    Hbm := Glob.Func.CreateBitmap.Call(5, 5)
    VarSetCapacity(BMBITS, 16*5, 0), pBits := &BMBITS
    DllCall("Advapi32.dll\SystemFunction036", "Ptr",&BMBITS, "Int",16*5)
    DllCall("Gdi32.dll\SetBitmapBits", "Ptr",Hbm, "UInt",16*5, "Ptr",&BMBITS)
    Color := Format("{3:02x}{2:02X}{1:02X}", *(pBits+38), *(pBits+39), *(pBits+40))

    Glob.Func.GuiControl.Call("-g", Glob.EditHex.Hwnd)
    Glob.Func.GuiControl.Call("Focus", Glob.EditHex.Hwnd)
    Glob.Func.UpdateRGBHSL.Call(Glob, Color)
    Glob.Func.GuiControl.Call("", Glob.EditHex.Hwnd, Color)
    Glob.Func.GuiControl.Call("+Background" . Color, Glob.New.Hwnd)
    Glob.Func.SetColorName.Call(Color)
    Glob.Func.GuiControl.Call("+g", Glob.EditHex.Hwnd, Glob.Func.EditHex)
    Glob.Func.SetImageAnimate.Call(Hbm)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_Settings(Glob, Mode) {
    Local
    If ( Mode="Save" )
    {
        Glob.Func.CoordMode.Call("Save")
        Glob.Func.GetImage.Call(Glob.Gradient.Hwnd, Obm)
        Glob.Func.GuiControlGet.Call("", Glob.ColorName.Hwnd, ColorName)
        Glob.Func.GetHexColor.Call(CurrentColor)
        Glob.Settings := { "Obm":Obm, "CurrentColor":CurrentColor, "ColorName":ColorName, "A_BatchLines":A_BatchLines }
        SetBatchLines -1
        Return
    }

    If ( Mode="Restore" )
    {
        Glob.Func.GuiControl.Call("-g", Glob.EditHex.Hwnd)
        Glob.Func.GuiControl.Call("Focus", Glob.EditHex.Hwnd)
        Glob.Func.UpdateRGBHSL.Call(Glob, Glob.Settings.CurrentColor)
        Glob.Func.GuiControl.Call("", Glob.EditHex.Hwnd,   Glob.Settings.CurrentColor)
        Glob.Func.GuiControl.Call("", Glob.ColorName.Hwnd, Glob.Settings.ColorName)
        Glob.Func.GuiControl.Call("+Background" . Glob.Settings.CurrentColor, Glob.New.Hwnd)
        Glob.Func.SetImageAnimate.Call(Glob.Settings.Obm)
        Glob.Settings.Obm := 0
        Glob.Func.GuiControl.Call("+g", Glob.EditHex.Hwnd, Glob.Func.EditHex)
    }

    If ( Glob.Settings.Obm )
    {
        Glob.Func.DeleteBitmap.Call(Glob.Settings.Obm)
        Glob.Func.GetHexColor.Call(Color)
        Glob.Func.GuiControl.Call("", Glob.EditHex.Hwnd, Color)
    }

    Glob.Esc := False
    Glob.Paint    := True
    Glob.Settings := {}
    Glob.Func.CoordMode.Call("Restore")
    SetBatchLines, % Glob.Settings.A_BatchLines
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_CoordMode(Glob, Mode) {
    Local
    Loop, Parse, % "A_CoordModeToolTip|A_CoordModePixel|A_CoordModeMouse|A_CoordModeCaret|A_CoordModeMenu", |
        If ( Mode="Save" )
            CoordMode, % SubStr(A_LoopField,12) . SubStr(Glob.CoordMode[A_LoopField] := %A_LoopField%, 1,0), Screen
        Else CoordMode, % SubStr(A_LoopField,12), % Glob.CoordMode[A_LoopField]
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_DelColorFmQ(Glob, hCtrl:=0, Color:="" ) {
    Local
    If ( hCtrl )
        Glob.Func.GetHexColor.Call(Color:="")

    If ( Color="" )
        Glob.Que := ""
    Else Glob.Que := ChooseColors_StrQ(Glob.Que, Color)
        , Glob.Que := StrSplit(Glob.Que, "|",, 2).2

        Glob.Func.HistorySetBitmap()
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_AddColorToQ(Glob, hCtrl, Color) {
    Local
    If ( hCtrl )
        Glob.Func.GetHexColor.Call(Color:="")

    Glob.Que := ChooseColors_StrQ(Glob.Que, Color)
    Glob.Func.HistorySetBitmap()
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_HistorySetBitmap(Glob) {
    Local
    Hbm := Glob.Func.CreateBitmap.Call(25, 1, 0, 32)
    VarSetCapacity(BMBITS, 100, 0),   n := pBits := &BMBITS+100,   i := Ok := 0

    Loop, Parse, % Glob.Que, |
        pBits := Numput("0x" . A_LoopField, pBits-4, "UInt") - 4,   i := Ok := A_Index
    Loop % ( 25-i )
        pBits := Numput(0xFFFFFF, pBits-4, "UInt") - 4

    DllCall("Gdi32.dll\SetBitmapBits", "Ptr",Hbm, "Int",100, "Ptr",&BMBITS)
    Glob.Func.SetImage.Call(Glob.History.Hwnd, Hbm, True)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_StrQ(Q, I, Max:=16, D:="|") { ;  StrQ v.0.91,  By SKAN on D09F/D46R @ tiny.cc/strq
    Return ( StrLen(Q)=0 ? I : InStr(I, D) ? Q : Q=I ? Q : SubStr(Q := StrLen(I) ? (I . D
        . Trim(StrReplace((D . Q . D), (D . I . D), D), D) . D) : (Q . D), 1
        , (I := InStr(Q, D, 0, 1, Max)) ? I-1 : Max<1 ? 0 : StrLen(Q)-1) )
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_MemDC(ByRef mDC, Hbm:=0) {
    Local
    If ( Hbm )
        mDC := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr",0, "Ptr")
            , DllCall("Gdi32.dll\SaveDC", "Ptr",mDC)
            , DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",Hbm)
    Else DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
        , mDC := DllCall("Gdi32.dll\DeleteDC", "Ptr",mDC) * 0
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_ShowMenu(Hwnd, MenuName, BottomAlign:=0) {
    Local
    VarSetCapacity(RECT, 16)
    DllCall("User32.dll\GetWindowRect", "Ptr",Hwnd, "Ptr",&RECT)
    x1 := NumGet(RECT,0, "Int"),   x2 := NumGet(RECT,8, "Int"),   XCenter := X1 + ((X2-X1)//2)

    DllCall("User32.dll\GetCursorPos", "Ptr",&RECT)
    CX := NumGet(RECT, 0, "Int"),   CY := NumGet(RECT, 4, "Int")

    TPM_RIGHTALIGN := 0x08,   TPM_BOTTOMALIGN := 0x20
    Flags := ( CX>XCenter ?  TPM_RIGHTALIGN : 0 ) | (BottomAlign ? TPM_BOTTOMALIGN : 0)
    CX    := ( CX>XCenter ? x2-4 : x1+4 )

    DllCall("User32.dll\TrackPopupMenu", "Ptr",MenuGetHandle(MenuName), "Int",Flags
        ,"Int",CX, "Int",CY, "Int",0, "Ptr",Hwnd, "Ptr",0, "UInt")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_HistoryMenu(Glob) {
    Local
    Glob.Func.CoordMode.Call("Save")
    MouseGetPos, X, Y
    PixelGetColor, Color, %X%, %Y%, RGB
    Color := SubStr(Color, 3)
    Glob.Func.CoordMode.Call("Restore")
    Glob.Func.GetHexColor.Call(Hex:="")

    ClearHistory  := Func("ChooseColors_DelColorFmQ").Bind(Glob, 0, "")
    DelColorFmQ   := Func("ChooseColors_DelColorFmQ").Bind(Glob, 0, Color)
    AddColorToQ   := Func("ChooseColors_AddColorToQ").Bind(Glob, 0, Color)

    Menu, ChooseColors, UseErrorLevel
    If ( InStr(Glob.Que, Color) )
    {
        Hbm := Glob.Func.CreateBitmap.Call(24, 24, ("0x" . Color), 32)
        MenuName := "Delete`tShift+Click"
        Menu, ChooseColors, Add, %MenuName%, %DelColorFmQ%
        Menu, ChooseColors, Icon, %MenuName%, HBITMAP:%Hbm%
        If ( Color != Hex )
        {
            Hbm := Glob.Func.CreateBitmap.Call(24, 24, ("0x" . Color), 32)
            MenuName  := "Set as New`tClick"
            SetNew    := Func("ChooseColors_SetNew").Bind(Glob, Color)
            Menu, ChooseColors, Add, %MenuName%, %SetNew%
            Menu, ChooseColors, Icon, %MenuName%, HBITMAP:%Hbm%
        }
    }

    If ( InStr(Glob.Que, Hex) = False )
    {
        Hbm := Glob.Func.CreateBitmap.Call(24, 24, ("0x" . Hex), 32)
        AddColorToQ := Func("ChooseColors_AddColorToQ").Bind(Glob, 0, Hex)
        MenuName    := "Add`tAlt+A"
        Menu, ChooseColors, Add, %MenuName%, %AddColorToQ%
        Menu, ChooseColors, Icon, %MenuName%, HBITMAP:%Hbm%
    }

    Menu, ChooseColors, Add, Clear History, %ClearHistory%
    If ( StrLen(Glob.Que) = 0 )
        Menu, ChooseColors, Disable, Clear History

    ChooseColors_ShowMenu(Glob.Gui.Hwnd, "ChooseColors", True)
    Menu, ChooseColors, DeleteAll
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_PaletteMenu(Glob, hCtrl) {
    Local
    Glob.Func.CoordMode.Call("Save")
    MouseGetPos, X, Y
    PixelGetColor, Color, %X%, %Y%, RGB
    Color := SubStr(Color, 3)
    Glob.Func.CoordMode.Call("Restore")

    CreatePalette := Func("ChooseColors_CreatePalette").Bind(Glob)
    CreateRandom  := Func("ChooseColors_GenRandom").Bind(Glob)
    AddColorToQ   := Func("ChooseColors_AddColorToQ").Bind(Glob, 0, Color)
    DelColorFmQ   := Func("ChooseColors_DelColorFmQ").Bind(Glob, 0, Color)
    Preview       := Func("ChooseColors_Preview").Bind(Glob)

    Menu, ChooseColors, UseErrorLevel
    Hbm := Glob.Func.CreateBitmap.Call(24, 24, ("0x" . Color), 32)
    MenuName := "Add #" . Color . (hCtrl = Glob.Preview.Hwnd ? "`tAlt+A" : "")
    Menu, ChooseColors, Add, %MenuName%, %AddColorToQ%
    Menu, ChooseColors, Icon, %MenuName%, HBITMAP:%Hbm%
    Menu, ChooseColors, Add, Random colors `tAlt+N, %CreateRandom%

    If ( hCtrl = Glob.Preview.Hwnd )
    {
        If InStr(Glob.Que, Color)
            Menu, ChooseColors, Insert, 2&, Delete #%Color% `tAlt+D, %DelColorFmQ%
        Menu, ChooseColors, Insert, 3&, Preview color`tClick, %Preview%
    }

    If ( hCtrl = Glob.Gradient.Hwnd )
    {
        Menu, ChooseColors, Add             ; Add separator

        N := 1, ErrorLevel := 0, I := 0
        While ( Section := ChooseColors_xStr(Glob.Menu,, "|[", "]|", N,,,, 0, 0) )
            If ( Section := Trim(Section, "[|]") )
            {
                I += 1
                Menu, ChooseColors, Add, %Section%, %CreatePalette%
            }

        If ( I = 0 )
            Menu, ChooseColors, Delete, 3& ; Remove separator
    }

    ChooseColors_ShowMenu(Glob.Gui.Hwnd, "ChooseColors", hCtrl = Glob.Preview.Hwnd)
    Menu, ChooseColors, DeleteAll
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_CreatePalette(Glob, Section) {
    Local
    Colors  := "",   Count := 0
    Section := ChooseColors_xStr(Glob.Menu,, "|[" . Section . "]|", "[")

    Loop, Parse, Section, |
        If ( StrLen(L := StrSplit(A_LoopField, "=", A_Space).1) = 6 )
            If L is xdigit
                Colors .= L . "|",  Count += 1

    If (  Count = 0  )
        Return
    Else  Colors := RTrim(Colors, "|")

        If ( Count <= 25 )
            W := ( H := 5 )
        Else W := ( H := Ceil(Sqrt(Count)) )

            VarSetCapacity(BMBITS, W*H*4),   pBits := &BMBITS
    Loop, Parse, Colors, |
        pBits := NumPut("0x" . A_LoopField, pBits+0, "Int"),   I := A_Index
    Loop % ((W*H)-I)
        pBits := NumPut(Glob.SysColor,        pBits+0, "Int")

    Hbm := Glob.Func.CreateBitmap.Call(W, H, 0, 32)
    DllCall("Gdi32.dll\SetBitmapBits", "Ptr",Hbm, "UInt",(W*4)*H, "Ptr",&BMBITS)
    Glob.Func.SetImageAnimate.Call(Hbm)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_SetColorName(Glob, Color) {
    Local
    ColorName  := ChooseColors_xStr(Glob.Menu,, "|" . Color . "=", "|")
    Glob.Func.GuiControl.Call("", Glob.ColorName.Hwnd, ColorName)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_xStr(ByRef H, C:=0, B:="", E:="",ByRef BO:=1, EO:="", BI:=1, EI:=1, BT:="", ET:="") {
    Local L, LB, LE, P1, P2, Q, N:="", F:=0                 ; xStr v0.97 by SKAN on D1AL/D343 @ tiny.cc/xstr
    Return SubStr(H,!(ErrorLevel:=!((P1:=(L:=StrLen(H))?(LB:=StrLen(B))?(F:=InStr(H,B,C&1,BO,BI))?F+(BT=N?LB
        :BT):0:(Q:=(BO=1&&BT>0?BT+1:BO>0?BO:L+BO))>1?Q:1:0)&&(P2:=P1?(LE:=StrLen(E))?(F:=InStr(H,E,C>>1,EO=N?(F
        ?F+LB:P1):EO,EI))?F+LE-(ET=N?LE:ET):0:EO=N?(ET>0?L-ET+1:L+1):P1+EO:0)>=P1))?P1:L+1,(BO:=Min(P2,L+1))-P1)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GoSub(Glob, HwndName, FunctionName, Bind*) {
    Local
    Glob.Func.GuiControl.Call("+g", Glob[HwndName].Hwnd, Func(FunctionName).Bind(Bind*))
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_Keypress(Keyname) {
    Local
    If ! GetKeyState(Keyname, "P")
        Return 0
    KeyWait, %KeyName%
    Return ! Errorlevel
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_Gui(Glob, SubCommand, Value1:="", Value2:="", Value3:="") {
    Local
    Subcommand := Glob.Gui.Hwnd . ":" . Subcommand

    Repl := { "SS_REALSIZECONTROL":0x40, "SS_BITMAP":0xE, "SS_ICON":0x3, "SS_NOTIFY":0x100
        , "CcStatic": "ClassCcStatic -Tabstop", "SS_CENTERIMAGE":0x200, "WS_EX_STATICEDGE":"E0x20000" }
    For K,V in Repl
        Value2 := StrReplace(Value2, K, V)

    Gui, %SubCommand%, %Value1%, % Value2 . (InStr(Value2, "Hwnd") ? " HwndHwnd" : ""), %Value3%
    If ( Var := StrSplit(StrSplit(Value2, "Hwnd").2, A_Space).1 )
    {
        Gui, % Glob.Gui.Hwnd . ":-DPIScale"
        GuiControlGet, _, % Glob.Gui.Hwnd . ":Pos", %Hwnd%
        Glob[Var] := {"Hwnd":Hwnd, "X":_X, "Y":_Y, "W":_W, "H":_H}
        Gui, % Glob.Gui.Hwnd . ":+DPIScale"
    }
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GuiControl(Glob, SubCommand:="", ControlID:="", Value:="") {
    Local
    Subcommand := Glob.Gui.Hwnd . ":" . Subcommand
    GuiControl, %SubCommand%, %ControlID%, %Value%
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GuiControlGet(Glob, SubCommand:="", ControlID:=""
    , ByRef _X:="", ByRef _Y:=0, ByRef _W:=0, ByRef _H:=0, ByRef _:="") {
    Local
    VarSetCapacity(_X, 3, 0)
    Subcommand := Glob.Gui.Hwnd . ":" . Subcommand
    GuiControlGet, _, %SubCommand%, %ControlID%
    _X := StrLen(_) ? _ : _X
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_AddUpDown(Glob, EditControl, Options, ByRef Hwnd:=0) {
    Local
    Glob.Func.Gui.Call("Add", "UpDown", Options)
    Glob.Func.Gui.Call("-Dpiscale")
    Glob.Func.GuiControl.Call("Move", Glob.Updown.Hwnd, "w0")
    Glob.Func.GuiControl.Call("Move", Glob[EditControl].Hwnd, "w" . Glob[EditControl].W)
    Glob.Func.Gui.Call("+Dpiscale")
    Func := Func("ChooseColors_UpDown").Bind(Glob, Glob.Updown.Hwnd, Glob[EditControl].Hwnd)
    Glob.Func.GuiControl.Call("+g", Glob.Updown.Hwnd, Func)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_UpDown(Glob, hUpDown, hBuddy) {
    Local
    If ( hBuddy = DllCall("User32.dll\GetFocus", "Ptr") )
        Return
    DllCall("User32.dll\SetFocus", "Ptr",hBuddy)
    Glob.Func.GuiControlGet.Call("", hUpDown, Val:=0)
    Glob.Func.GuiControl.Call("", hBuddy, Val)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_CreateBitmap(W:=0, H:=0, Color:=0, BPP:=24) {
    Local
    Hbm := DllCall("Gdi32.dll\CreateBitmap", "Int",1, "Int",1, "Int",0x1, "Int",BPP, "Ptr",0, "Ptr")
    Hbm := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0x0, "Int",1, "Int",1, "Int",0x2008, "Ptr")
    DllCall("Gdi32.dll\SetBitmapBits", "Ptr",Hbm, "UInt",4, "UIntP",Color)
    Return DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0x0, "Int",W, "Int",H, "Int",0x2008, "Ptr")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_DeleteBitmap(Hbm) {
    Local
    Return DllCall("Gdi32.dll\DeleteObject", "Ptr",Hbm)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_SetImage(Hwnd, Hbm, Redraw:=0) {
    Local STM_SETIMAGE = 0x172, STM_GETIMAGE := 0x173, WM_SETREDRAW := 0xB, Obm := 0

    DllCall("User32.dll\SendMessage", "Ptr",Hwnd, "Int",WM_SETREDRAW, "Ptr",Redraw, "Ptr",0, "Ptr")
    Obm := DllCall("User32.dll\SendMessage", "Ptr",Hwnd, "Int",STM_SETIMAGE, "Ptr",0, "Ptr",Hbm, "Ptr")
    DllCall("User32.dll\SendMessage", "Ptr",Hwnd, "Int",WM_SETREDRAW, "Ptr",True, "Ptr",0, "Ptr")

    If ( Obm )
        Obm := DllCall("Gdi32.dll\DeleteObject", "Ptr",Obm) * 0

    Obm := DllCall("User32.dll\SendMessage", "Ptr",Hwnd, "Int",STM_GETIMAGE, "Ptr",0, "Ptr",0, "Ptr")

    If ( Obm != Hbm )
        Hbm := DllCall("Gdi32.dll\DeleteObject", "Ptr",Hbm) * 0
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GetImage(Hwnd, ByRef Hbm:=0, Copy:=1) { ; this function returns copy of image
    Local STM_GETIMAGE := 0x173
    Hbm := DllCall("user32.dll\SendMessage", "Ptr",Hwnd, "Int",STM_GETIMAGE, "Ptr",0, "Ptr",0, "Ptr")
    If ( Copy )                                                     ; LR_CREATEDIBSECTION = 0x2000
        Hbm := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0, "Int",0, "Int",0, "Int",0x2000, "Ptr")
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_CreateGradient(W, H, V:=0, Colors*) {        ; by SKAN on D46L/D46L @ tiny.cc/creategradient
    Local
    N := ( Colors := Colors.Count()>1 ? Colors : [ 0, 16777215, 0 ] ).Count()

    xOFF := (X := V ? W : 0) ? 0 : Ceil(W/(N-1))
    yOFF := (Y := V ? 0 : H) ? 0 : Ceil(H/(N-1))
    VarSetCapacity(VERT, N*16, 0)
    VarSetCapacity(MESH, N*8,  0)

    Loop % ( N,  pVert:=&VERT,  pMesh:=&MESH )
        X :=   V ? (X=0 ? W : X:=0) : X
            , Y :=  !V ? (Y=0 ? H : Y:=0) : Y
            , Color :=  Format("{:06X}", Colors[A_Index] & 0xFFFFFF)
            , Color :=  Format("0x{5:}{6:}00{3:}{4:}00{1:}{2:}00", StrSplit(Color)*)
            , pVert :=  NumPut(Color, NumPut(Y, NumPut(X, pVert+0, "Int"), "Int"), "Int64")
            , pMesh :=  NumPut(A_Index, NumPut(A_Index-1, pMesh+0, "Int"), "Int")
            , Z :=  V ? (Y += yOFF) : (X += xOFF)

    Hbm := DllCall("Gdi32.dll\CreateBitmap", "Int",1, "Int",1, "Int",0x1, "Int",32, "PtrP",0, "Ptr")
    Hbm := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0x0, "Int",W, "Int",H, "Int",0x2008, "Ptr")
    mDC := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr",0, "Ptr")
    DllCall("Gdi32.dll\SaveDC", "Ptr",mDC)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",Hbm)
    DllCall("Msimg32.dll\GradientFill", "Ptr",mDC, "Ptr",&VERT, "Int",N, "Ptr",&MESH, "Int",N-1, "Int",!!V)
    DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
    DllCall("Gdi32.dll\DeleteDC", "Ptr",mDC)
    Return Hbm
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_GetIcon(Filename, W:=0, H:=0) {
    Local
    Switch ( FileName )
    {
    Case "caption.png" : Base64PNG := "
        ( LTrim Join
            iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAApUlEQVRIie1VAQqDMAy8yD7jK3XPlrRkWKyELFanLQO3gxAx5S5J05ZEZIQBEaUfIm
            JDLkrru0MMF/AX2MUjb5CHUuzo+vYVeKO1jt2EARFAAJKfjRcfFmOAejxxakwteTDk2UoVFKOa0Gavv08L5My91lSpQBNuifAVAS9b3R6uKdCkRVsZ
            B+VjywpijRaxIfuwRfORfXtwauLLd9HPP5k3EADwAsmVfeJ0bmDRAAAAAElFTkSuQmCC
        )"

    Case "pickscr.png" : Base64PNG := "
        ( LTrim Join
            iVBORw0KGgoAAAANSUhEUgAAABcAAAAXAgMAAACdRDwzAAAACVBMVEUAAAD///8AAABzxoNxAAAAA3RSTlMAv7/C9di0AAAAQUlEQVQI12NYtZKBcd
            UKhqmhDIyhEQwTGIBAAp3SWrVqAZBSDQ1NkGAIAFEiDAwgioF4CqoPYgrMTKz2Qd0CdRkAcTwhFlkgH1gAAAAASUVORK5CYII=
        )"

    Case "pickclr.png" : Base64PNG := "
        ( LTrim Join
            iVBORw0KGgoAAAANSUhEUgAAABcAAAAXAgMAAACdRDwzAAAACVBMVEUAAAD///8AAABzxoNxAAAAA3RSTlMAv7/C9di0AAAATUlEQVQI12NYtZKBcd
            UKhqmhDIyhEQwTGIBAAkixOoApNkwqAESJMDCAKBBgBVJAvQGioUBq1QSplVAeTA6qEqYP00y4fVDboW6BugwAhowXw6cdQ8QAAAAASUVORK5CYII=
        )"

        Default : Base64PNG := ""
    }
    Return ChooseColors_PNG2HICON(Base64PNG, W, H)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_PNG2HICON(Base64PNG, W:=0, H:=0) {          ;    By SKAN on D094/D46Q @ tiny.cc/t-36636
    Local
    VarSetCapacity(Bin, nBytes := Floor((B64Len := StrLen(Base64PNG := RTrim(Base64PNG,"=")))*3/4))
    Return DllCall("Crypt32.dll\CryptStringToBinary", "Str",Base64PNG, "Int",B64Len, "Int",1, "Ptr",&Bin
        ,"UIntP",nBytes, "Int",0, "Int",0)
        ?  DllCall("User32.dll\CreateIconFromResourceEx", "Ptr",&Bin, "Int",nBytes, "Int",True
        ,"Int",0x30000, "Int",W, "Int",H, "Int",0, "Ptr") : 0
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_CreateBitmapText(Glob, hTxt) { ;  modified ver of TextToPic() v0.50
    Local                                       ;  by SKAN on D475/D475 @ tiny.cc/t92338
    ControlGetText, Text,, ahk_id %hTxt%
    hFnt := DllCall("User32.dll\SendMessage", "Ptr",hTxt, "Int",0x31, "Ptr",0, "Ptr",0, "Ptr") ; WM_GETFONT
    VarSetCapacity(RECT, 16)
    DllCall("User32.dll\GetClientRect", "Ptr",hTxt, "Ptr",&RECT)
    x1 := NumGet(RECT,0, "Int"),   y1 := NumGet(RECT,4, "Int")
    x2 := NumGet(RECT,8, "Int"),   y2 := NumGet(RECT,12,"Int")
    W  := x2-x1,                   H  := y2-y1

    FileGetVersion, OSV, user32.dll
    LRFlag := Format("{1:}.{2:}", StrSplit(OSV,".")*) > 6.3 ? 0x8 : 0x2008

    WindowColor := Format("0x{5:}{6:}{3:}{4:}{1:}{2:}", StrSplit(Format("{:06X}"
        , DllCall("User32.dll\GetSysColor", "Int",15)))*)

    Hbm    := DllCall("Gdi32.dll\CreateBitmap", "Int",1, "Int",1, "Int",0x1, "Int",24, "Ptr",0, "Ptr")
    Hbm    := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0x0, "Int",1, "Int",1, "Int",0x2008, "Ptr")
    DllCall("Gdi32.dll\SetBitmapBits", "Ptr",Hbm, "UInt",4, "UIntP",WindowColor)
    Hbm    := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0x0, "Int",W, "Int",H, "Int",LRFlag, "Ptr")

    hBrush := DllCall("CreateSolidBrush", "Int",0x998877, "Ptr")
    hPen   := DllCall("CreatePen", "Int",0, "Int",1, "Int",0xFAFAFA, "Ptr" )

    mDC    := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr",0, "Ptr")
    DllCall("Gdi32.dll\SaveDC", "Ptr",mDC)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",hBrush)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",hPen)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",Hbm)
    DllCall("Gdi32.dll\RoundRect", "Ptr",mDC, "Int",0, "Int",0, "Int",W, "Int",H, "Int",H*.45, "Int",H*.45)
    DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
    DllCall("Gdi32.dll\DeleteObject", "Ptr",hBrush)
    DllCall("Gdi32.dll\DeleteObject", "Ptr",hPen)

    Hbm := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0, "Int",W*5, "Int",H*5, "Int",LRFlag, "Ptr")
    Hbm := DllCall("User32.dll\CopyImage", "Ptr",Hbm, "Int",0, "Int",W,   "Int",H,   "Int",0x2008, "Ptr")

    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",Hbm)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",hFnt)
    DllCall("Gdi32.dll\SetTextColor", "Ptr",mDC, "Int",0xE3E3E3)
    DllCall("Gdi32.dll\SetBkMode", "Ptr",mDC, "Int",1) ; TRANSPARENT=1
    DllCall("User32.dll\DrawText", "Ptr",mDC, "Str",Text, "Int",StrLen(Text), "Ptr",&RECT, "Int",0x25)
    DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
    DllCall("Gdi32.dll\DeleteDC", "Ptr",mDC)

    Return Hbm
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_SetImageAnimate(Glob, Hbm) {
    Local
    VarSetCapacity(BITMAP, Sz := A_PtrSize=8 ? 32 : 24 )
    DllCall("Gdi32.dll\GetObject", "Ptr",Hbm, "Int",Sz, "Ptr",&BITMAP)
    SW := Numget(BITMAP, 4, "UInt")
    SH := Numget(BITMAP, 8, "UInt")
    TH := TW := Glob.Gradient.W

    tDC  := DllCall("User32.dll\GetWindowDC", "Ptr",Glob.Gradient.Hwnd, "Ptr")
    mDC    := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr",0, "Ptr")
    DllCall("Gdi32.dll\SaveDC", "Ptr",mDC)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",Hbm)
    Loop , Parse, % "2,4,8,12,16,20,24,28,32,36,40,48,96,128,192,255", `,
    {
        DllCall("Gdi32.dll\GdiAlphaBlend"
            , "Ptr",tDC, "Int",0, "Int",0, "Int",TW, "Int",TH
            , "Ptr",mDC, "Int",0, "Int",0, "Int",SW, "Int",SH, "Int",A_LoopField<<16)
        Sleep 1
    }
    DllCall("User32.dll\ReleaseDC", "Ptr",Glob.Gradient.Hwnd, "Ptr",tDC)
    DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
    DllCall("Gdi32.dll\DeleteDC", "Ptr",mDC)
    Glob.Func.SetImage.Call(Glob.Gradient.Hwnd, Hbm, False)
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ChooseColors_BoxCur(P*) {  ; v0.3 by SKAN on D47J/D47K @ tiny.cc/boxcur
    Local
    If ! ( P.Count() )
        Return DllCall("User32.dll\SystemParametersInfo", "Int",SPI_SETCURSORS := 0x57, "Int",0, "Int",0, "Int",0)

    CW := Max( 32, Format("{:d}", P[1]) )
    CH := Max( 32, Format("{:d}", P[2]) )
    RegRead, m, HKEY_CURRENT_USER\Control Panel\Cursors, CursorBaseSize
    m  := ( (m := Format("{:d}", m)) > 32 ? m/32 : 1 )
    CW := Round(CW/m)
    CH := Round(CH/m)

    VarSetCapacity(BITMAPINFO, 40, 0)
    pBMI := &BITMAPINFO,  pBits := 0
    NumPut(1, NumPut(1,NumPut(CH,NumPut(CW,NumPut(40,pBMI+0,"Int"),"Int"),"Int"),"Short"),"Short")

    hBM   := DllCall("gdi32.dll\CreateDIBSection", "Ptr",0, "Ptr",pBMI, "Int",0, "PtrP",pBits, "Ptr",0, "Int", 0, "Ptr")
    hPen  := DllCall("Gdi32.dll\CreatePen", "Int",0, "Int",1, "Int",0xFFFFFF, "Ptr")
    hBrush  := DllCall("Gdi32.dll\CreateSolidBrush", "Int",m!=1 || P[3]!="" ? 0xFFFFFF : 0x000000, "Ptr")
    mDC     := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr",0, "Ptr")
    DllCall("Gdi32.dll\SaveDC", "Ptr",mDC)

    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",hBrush)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",hPen)
    DllCall("Gdi32.dll\SelectObject", "Ptr",mDC, "Ptr",hBM)
    DllCall("Gdi32.dll\RoundRect", "Ptr",mDC, "Int",0, "Int",0, "Int",CW, "Int",CH, "Int",0, "Int",0)

    DllCall("Gdi32.dll\RestoreDC", "Ptr",mDC, "Int",-1)
    DllCall("Gdi32.dll\DeleteDC", "Ptr",mDC)
    DllCall("Gdi32.dll\DeleteObject", "Ptr",hBrush)
    DllCall("Gdi32.dll\DeleteObject", "Ptr",hPen)

    VarSetCapacity( BITMAP, SzBITMAP := ( A_PtrSize = 8 ? 32 : 24 ) )
    DllCall("Gdi32.dll\GetObject", "Ptr",hBM, "Int",SzBITMAP, "Ptr",&BITMAP)
    WB      := Numget(BITMAP, 12, "Int")
    biSize  := (WB*CH) * 2
    ttlSize :=  22 + 40 + 8 + biSize

    pCURSOR := DllCall("Kernel32.dll\GlobalAlloc", "Int",0x40, "Ptr",ttlSize, "Ptr")

    NumPut(0x0100020000,    pCURSOR +  0, "Int64")
    NumPut(CW,              pCURSOR +  6, "UChar")
    NumPut(CH,              pCURSOR +  7, "UChar")
    NumPut(40 + 8 + biSize, pCURSOR + 14, "UInt")
    NumPut(22,              pCURSOR + 18, "UInt")
    NumPut(0xFFFFFF,        pCURSOR + 66, "UInt")
    NumPut(CW,     pBMI +  4, "UInt")
    NumPut(CH*2,   pBMI +  8, "UInt")
    NumPut(bisize, pBMI + 20, "UInt")
    NumPut(2,      pBMI + 32, "UInt")
    NumPut(2,      pBMI + 36, "UInt")

    DllCall("Kernel32.dll\RtlMoveMemory", "Ptr",pCURSOR + 22,         "Ptr",pBMI,    "Ptr",40)
    DllCall("Kernel32.dll\RtlMoveMemory", "Ptr",pCURSOR + 70,         "Ptr",pBits,   "Ptr",WB*CH)
    DllCall("Kernel32.dll\RtlFillMemory", "Ptr",pCURSOR + 70+(WB*CH), "Ptr",(WB*CH), "Int",255)
    DllCall("Gdi32.dll\DeleteObject", "Ptr",hBM)

    Loop, Parse, % "32512,32513,32514,32515,32516,32640,32641,32642,32643,32644,32645,32646,32648,32649,32650,32651", `,
        DllCall("User32.dll\SetSystemCursor", "Ptr",DllCall("User32.dll\CreateIconFromResourceEx", "Ptr",pCURSOR+22
            , "UInt",ttlSize-22, "Int",True, "Int",0x30000, "Int",CW, "Int",CH, "Int",0, "Ptr"), "Int",A_Loopfield)

    DllCall("Kernel32.dll\GlobalFree", "Ptr",pCURSOR)
    Return ttlSize
}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
