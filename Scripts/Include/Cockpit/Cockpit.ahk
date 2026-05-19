;===============================================================================
; Cockpit.ahk - Dashboard + in-process aggregator writer
;===============================================================================
; Runtime:
;   - in-process aggregator rewrites Scripts\Include\Cockpit\CockpitState.ini every 2s
;   - GUI refreshes every 1s
;
; Hotkeys:
;   Shift+F9   -> exit
;   F5         -> force refresh
;===============================================================================

#SingleInstance, force
#NoEnv
#KeyHistory 0
SetBatchLines, -1
ListLines, Off
SetTitleMatchMode, 3
SetWorkingDir %A_ScriptDir%\..\..

#Include %A_ScriptDir%\..\
#Include Config.ahk
#Include Logging.ahk
#Include Utils.ahk
#Include AccountMetadata.ahk
#Include Cockpit\CockpitState.ahk
#Include Cockpit\CockpitMetrics.ahk
#Include Cockpit\CockpitInjectables.ahk
#Include Cockpit\CockpitAggregatorEngine.ahk

global GUI_W := 850
global GUI_H := 430
global g_cockpitW := GUI_W
global COCKPIT_TAB_STRIP := 26       ; approximate tab caption row inside Tab2
global COCKPIT_EVENTS_FILTER := 34   ; filter row height inside Events tab (includes margin)
global COCKPIT_EVENTS_EDIT_MIN := 162 ; minimum Edit height so log is usable (few lines)
global COCKPIT_TAB_MARGIN_X := 14
global g_cockpitTabTopY := 0           ; SepTop-relative; used by Cockpit_Relayout
global g_cockpitMinTabInner := 220     ; COCKPIT_EVENTS_FILTER + COCKPIT_EVENTS_EDIT_MIN (+ margins): min usable Events tab body
global LV_HWND := 0
global g_cockpitHwnd := 0
global g_cockpitLastInstLayoutN := 0   ; last instancesConfigured used for tab/LV geometry; drives Relayout on change
global EV_HWND := 0
global SB_HWND := 0
global THEME_BG := "161A1D"
global THEME_BG_ALT := "0F1316"
global THEME_TEXT := "F2F4F5"
global THEME_MUTED := "95A1A8"
global THEME_ACCENT := "4CC9F0"
global THEME_SUCCESS := "63E6BE"
global THEME_WARN := "FFD166"
global THEME_DANGER := "EF476F"
global THEME_FONT := "Segoe UI"
global g_lvHasMainRow := 0
global g_lastLvRowSigs := []

global g_rowMetaByRow := []
global g_contextRow := 0
global g_lvSortKey := ""
global g_lvSortDir := 0
global g_lvAllColKeys := []
global g_lvColOrder := []
global g_lvColVisible := {}
global g_lvColWidths := {}
global g_lvColWidthsSig := ""
global g_lvLastAppliedLayoutSig := ""
global g_lvColsGuiBuilt := 0
global COLS_LV_HWND := 0
global ColsLv := ""
global g_lvColsEditorOrder := []
global g_lvColsEditorVisible := {}
global g_lvColsEditorSel := 1
global g_eventFilter := Cockpit_LoadEventFilter()
global g_lastEventsText := ""
global g_cockpitStartEpoch := CockpitState_NowEpoch()
global g_ageGuiBuilt := 0
global g_ageHwnd := 0
global AGE_INST_HWND := 0
global AGE_ACCT_HWND := 0
global g_ageFilterText := ""
global g_ageFilterStatus := "All"
global g_ageFilterInst := "All"
global g_ageEvalMode := "Inject Packs"
global g_ageRewardsWonder := 1
global g_ageRewardsSpecial := 1
global g_ageRewardsGift := 1
global g_ageRewardsShine := 0
global g_ageInstSortCol := 0
global g_ageInstSortDir := 1
global g_ageAcctSortCol := 4
global g_ageAcctSortDir := 1
global g_ageInstRowsCache := []
global g_ageAcctRowsCache := []
global g_ageAcctMenuRow := 0
global g_ageWindowH := 462
global g_ageStandalone := false
global g_emptySparkline := ""
global INST_SEG_X_RUN := 109
global INST_SEG_W_RUN := 128
global INST_SEG_W_STK := 94
global INST_SEG_W_IDLE := 84
global INST_SEG_W_DEAD := 88
global g_instSingleMode := true
global g_cockpitMainTabIdx := 1           ; Instances=1, Recent events=2 (skip expensive tab updates while hidden)
global g_instLayoutLineCache := ""        ; avoids redundant Moves in Cockpit_LayoutInstancesSingle
Loop, 12
    g_emptySparkline .= Chr(0x2581)

global botConfig := new BotConfig()
botConfig.loadSettingsToConfig("ALL")
g_lvAllColKeys := Cockpit_DefaultColumnKeys()
if (Cockpit_HasArg("--injection-queue"))
    g_ageStandalone := true
if (!g_ageStandalone && !Cockpit_IsLaunchAllowed()) {
    MsgBox, 48, PTCGPB Cockpit, Start the bot from PTCGPB first.
    ExitApp
}
OnMessage(0x111, "Cockpit_OnCommand")
OnMessage(0x20, "Cockpit_OnSetCursor")
OnMessage(0x0112, "Cockpit_OnWmSysCommand")
Menu, CockpitRowMenu, Add, Open Instance Log, Cockpit_MenuOpenLog
Menu, CockpitRowMenu, Add,,
Menu, CockpitRowMenu, Add, Open Account Folder, Cockpit_MenuOpenAccountFolder
Menu, CockpitRowMenu, Add, Open Account XML, Cockpit_MenuOpenAccountXml
Menu, CockpitRowMenu, Add, Copy Account XML Name, Cockpit_MenuCopyAccountXmlName
Menu, CockpitRowMenu, Add, Copy Account XML, Cockpit_MenuCopyAccountXml
Menu, CockpitRowMenu, Add,,
Menu, CockpitRowMenu, Add, Open Account Metadata, Cockpit_MenuOpenAccountMetadata
Menu, CockpitRowMenu, Add, Copy Account Metadata, Cockpit_MenuCopyAccountMetadata
Menu, CockpitRowMenu, Add, Copy Account Metadata Name, Cockpit_MenuCopyAccountMetadataName
Menu, CockpitAgeAcctMenu, Add, Open Account Folder, Cockpit_AgeMenuOpenAccountFolder
Menu, CockpitAgeAcctMenu, Add, Open Account XML, Cockpit_AgeMenuOpenAccountXml
Menu, CockpitAgeAcctMenu, Add, Copy Account XML Name, Cockpit_AgeMenuCopyAccountXmlName
Menu, CockpitAgeAcctMenu, Add, Copy Account XML, Cockpit_AgeMenuCopyAccountXml
Menu, CockpitAgeAcctMenu, Add,,
Menu, CockpitAgeAcctMenu, Add, Open Account Metadata, Cockpit_AgeMenuOpenAccountMetadata
Menu, CockpitAgeAcctMenu, Add, Copy Account Metadata, Cockpit_AgeMenuCopyAccountMetadata
Menu, CockpitAgeAcctMenu, Add, Copy Account Metadata Name, Cockpit_AgeMenuCopyAccountMetadataName
Cockpit_LoadColumnsPrefs()

if (g_ageStandalone) {
    Cockpit_AgeEnsureGui()
    Gui, CockpitAge:Show, Hide w680 h%g_ageWindowH%, Injection Queue
    Cockpit_AgeRefresh()
    agePos := Cockpit_LoadWindowPosition("Age")
    if (agePos.ok) {
        ax := agePos.x
        ay := agePos.y
        Gui, CockpitAge:Show, x%ax% y%ay% w680 h%g_ageWindowH%, Injection Queue
    }
    else
        Gui, CockpitAge:Show, Center w680 h%g_ageWindowH%, Injection Queue
} else {
    Cockpit_BuildGui()
    Agg_InitEngine()
    Agg_TickBody()
    mainPos := Cockpit_LoadWindowPosition("Main")
    if (mainPos.ok) {
        mx := mainPos.x
        my := mainPos.y
        Gui, Cockpit:Show, x%mx% y%my% w%GUI_W% h%GUI_H%, PTCGPB Cockpit
    }
    else
        Gui, Cockpit:Show, Center w%GUI_W% h%GUI_H%, PTCGPB Cockpit
    WinRestore, PTCGPB Cockpit
    WinActivate, PTCGPB Cockpit
    Cockpit_DisableMainWindowMaximize(g_cockpitHwnd)
    Cockpit_PollMainTab()
    ; Phase first UI tick away from aggregator (also run at Agg_TickBody) to reduce simultaneous GUI+INI work spikes.
    SetTimer, Cockpit_RefreshTicker, % -447
    SetTimer, Agg_Tick, % 1000
}
Return

;===============================================================================
; GUI construction
;===============================================================================

; Remove WS_MAXIMIZEBOX so the window cannot be maximized / pseudo-fullscreen from the title bar.
Cockpit_DisableMainWindowMaximize(hwnd) {
    if (!hwnd)
        return
    WinSet, Style, -0x10000, ahk_id %hwnd%
}

; Block SC_MAXIMIZE (Aero Snap to top, Win+Up, etc.). WinSet alone is not enough on modern Windows.
Cockpit_OnWmSysCommand(wParam, lParam, msg, hwnd) {
    global g_cockpitHwnd
    if (!g_cockpitHwnd || hwnd != g_cockpitHwnd)
        return
    cmd := wParam & 0xFFF0
    if (cmd = 0xF030) { ; SC_MAXIMIZE
        return 0
    }
}

Cockpit_BuildGui() {
    global
    local y, instancesConfigured, lvRows, lvHeight, eventsH, lvInstancesW

    instancesConfigured := (botConfig.get("Instances") + 0)
    if (instancesConfigured <= 0)
        instancesConfigured := 1
    lvRows := instancesConfigured

    Gui, Cockpit:New, +HwndhCockpit -Resize, PTCGPB Cockpit
    g_cockpitHwnd := hCockpit
    Gui, Cockpit:Default
    Gui, Color, %THEME_BG%, %THEME_BG%
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%

    ; --- MODE: big, prominent ---
    Gui, Font, s16 c%THEME_ACCENT% Bold, %THEME_FONT%
    ; Buttons start at GUI_W-264. Mode label stops 10px before that (lbl x14; w=W-288 -> right edge at W-274)
    Gui, Add, Text, % "x14 y8 w" . (GUI_W - 288) . " h32 vlblModeVal Background" . THEME_BG, (loading...)
    Gui, Font, s9 c%THEME_TEXT% Bold, %THEME_FONT%
    Gui, Add, Button, % "x" . (GUI_W - 264) . " y12 w120 h22 vbtnAgeView gCockpit_OpenAgeView", Injection Queue
    Gui, Add, Button, % "x" . (GUI_W - 134) . " y12 w120 h22 vbtnCols gCockpit_OpenColumns", Customise
    Cockpit_UpdateAgeButtonVisibility(botConfig.get("deleteMethod"))

    ; --- 2-column label/value grid ---
    y := 50
    Cockpit_AddPair("Session",     14, y, "lblSesVal")
    Cockpit_AddPair("ETA",        380, y, "lblEtaVal")
    y += 22
    Cockpit_AddPair("Injectable",  14, y, "lblInjVal")
    Cockpit_AddPair("Runs",       380, y, "lblRunsVal")
    y += 22
    Cockpit_AddPair("Throughput",  14, y, "lblPaceVal")
    Cockpit_AddPair("Average Run",380, y, "lblAvgVal")
    y += 22
    ; Instances full-width
    Gui, Font, s9 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, % "x14 y" . y . " w90 h18 Background" . THEME_BG, Instances
    Gui, Font, s9 c%THEME_SUCCESS%, %THEME_FONT%
    Gui, Add, Text, % "x" . INST_SEG_X_RUN . " y" . y . " w" . INST_SEG_W_RUN . " h18 vlblInstRunVal Background" . THEME_BG, -
    Gui, Font, s9 c%THEME_WARN%, %THEME_FONT%
    Gui, Add, Text, % "x" . (INST_SEG_X_RUN + INST_SEG_W_RUN) . " y" . y . " w" . INST_SEG_W_STK . " h18 vlblInstStkVal Background" . THEME_BG,
    Gui, Font, s9 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, % "x" . (INST_SEG_X_RUN + INST_SEG_W_RUN + INST_SEG_W_STK) . " y" . y . " w" . INST_SEG_W_IDLE . " h18 vlblInstIdleVal Background" . THEME_BG,
    Gui, Font, s9 c%THEME_DANGER%, %THEME_FONT%
    Gui, Add, Text, % "x" . (INST_SEG_X_RUN + INST_SEG_W_RUN + INST_SEG_W_STK + INST_SEG_W_IDLE) . " y" . y . " w" . INST_SEG_W_DEAD . " h18 vlblInstDeadVal Background" . THEME_BG,
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Text, % "x" . (INST_SEG_X_RUN + INST_SEG_W_RUN + INST_SEG_W_STK + INST_SEG_W_IDLE + INST_SEG_W_DEAD) . " y" . y . " w" . (GUI_W - (INST_SEG_X_RUN + INST_SEG_W_RUN + INST_SEG_W_STK + INST_SEG_W_IDLE + INST_SEG_W_DEAD + 20)) . " h18 vlblInstMainVal Background" . THEME_BG,
    y += 26

    ; Progress bar
    Gui, Add, Progress, % "x14 y" . y . " w" . (GUI_W - 28) . " h12 c4CC9F0 Background242A2E vlblPrgBar Range0-1000", 0
    y += 16
    Gui, Add, Text, % "x14 y" . y . " w" . (GUI_W - 28) . " h18 Center vlblPrgVal Background" . THEME_BG . " c" . THEME_MUTED, 0`%
    y += 28
    Gui, Add, Progress, % "x10 y" . y . " w" . (GUI_W - 20) . " h1 c2A3136 Background2A3136 vSepTop Disabled", 100
    y += 8
    tabTopY := y
    g_cockpitTabTopY := tabTopY
    tabCtrlW := GUI_W - 20

    provisionalTabOuter := COCKPIT_TAB_STRIP + g_cockpitMinTabInner + 40

    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Tab2, % "x10 y" . tabTopY . " w" . tabCtrlW . " h" . provisionalTabOuter
        . " vtxMainTabs gCockpit_MainTab Choose1 Background" . THEME_BG
        , % "Instances|Recent events"

    ; --- Tab: Instances ---
    Gui, Tab, Instances,, Exact
    lvInnerW := tabCtrlW - 2 * COCKPIT_TAB_MARGIN_X
    ; +0x2000 = LVS_NOSCROLL
    Gui, Add, ListView, % "x" . COCKPIT_TAB_MARGIN_X . " y10 w" . lvInnerW . " h200"
        . " vInstancesLv gCockpit_OnInstancesLv hwndhLv -Multi -ReadOnly Grid -0x100000 -0x200000 +0x2000 -0x200"
        , % Cockpit_BuildInstanceLvHeaderCsv()
    LV_HWND := hLv

    Gui, ListView, InstancesLv
    Cockpit_ApplyColumnsToListView()
    Cockpit_StyleListView(hLv)
    Cockpit_DisableColumnResize(hLv)

    lvHeight := Cockpit_MeasureLvHeight(hLv, lvRows)
    innerH := lvHeight + 24
    if (innerH < g_cockpitMinTabInner)
        innerH := g_cockpitMinTabInner
    tabOuter := innerH + COCKPIT_TAB_STRIP
    ddlXInner := tabCtrlW - COCKPIT_TAB_MARGIN_X - 120
    evtTopRel := COCKPIT_EVENTS_FILTER + 12
    evtEditH := innerH - evtTopRel - 10

    GuiControl, Cockpit:Move, txMainTabs, % "h" . tabOuter
    ; Do not stretch ListView to fill the tab: only measured rows (avoids blank "extra" rows).
    GuiControl, Cockpit:Move, InstancesLv, % "h" . lvHeight . " w" . lvInnerW

    ; --- Tab: Recent events ---
    Gui, Tab, Recent events,, Exact
    filterChoices := "All|Warnings|System"
    Loop, % instancesConfigured
        filterChoices .= "|Instance " . A_Index
    Gui, Font, s8 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, DropDownList, % "x" . ddlXInner . " y10 w120 vddlEventFilter gCockpit_OnEventFilterChange"
        , %filterChoices%
    if (g_eventFilter = "")
        g_eventFilter := "All"
    GuiControl, Cockpit:ChooseString, ddlEventFilter, %g_eventFilter%
    if (ErrorLevel) {
        g_eventFilter := "All"
        GuiControl, Cockpit:ChooseString, ddlEventFilter, All
    }

    Gui, Font, s9 c%THEME_TEXT%, Consolas
    Gui, Add, Edit, % "x" . COCKPIT_TAB_MARGIN_X . " y" . evtTopRel . " w" . lvInnerW . " h" . evtEditH . " vEventsLog hwndhEv ReadOnly +0x800 +VScroll Background" . THEME_BG_ALT . " cE7ECEF"
        , (No events yet)
    EV_HWND := hEv

    Gui, Tab
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%

    GUI_H := tabTopY + tabOuter + 10
    g_cockpitLastInstLayoutN := instancesConfigured
    Cockpit_DisableMainWindowMaximize(hCockpit)
}

;-------------------------------------------------------------------------------
; Cockpit_AddPair - 90-px gray label + bold white value at (x, y)
; (Same y + height for label and value so titles align with their values.)
;-------------------------------------------------------------------------------
Cockpit_AddPair(text, x, y, vname) {
    global
    Gui, Font, s9 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, % "x" . x . " y" . y . " w90 h18 Background" . THEME_BG, %text%
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Text, % "x" . (x + 95) . " y" . y . " w260 h18 v" . vname . " Background" . THEME_BG, -
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
}

Cockpit_HasArg(flag) {
    cmd := DllCall("GetCommandLine", "Str")
    return InStr(cmd, flag) ? true : false
}

Cockpit_IsLaunchAllowed() {
    markerPath := getScriptBaseFolder() . "\Scripts\Include\Cockpit\CockpitLaunch.ini"
    if (!FileExist(markerPath))
        return false
    IniRead, started, %markerPath%, Runtime, BotStarted, 0
    return (started != "ERROR" && (started + 0) = 1)
}

Cockpit_ListViewGetHeaderAndItemHeight(hLv, ByRef hdrH, ByRef itemH) {
    global g_lvColOrder
    hdrH := 22
    itemH := 17
    if (!hLv)
        return
    Gui, Cockpit:Default
    Gui, ListView, InstancesLv
    colN := g_lvColOrder.Length()
    if (colN <= 0)
        colN := 1
    cells := []
    cells.Push("1")
    Loop, % colN - 1
        cells.Push("")
    LV_Add("", cells*)
    VarSetCapacity(rcItem, 16, 0)
    NumPut(0, rcItem, 0, "Int")
    SendMessage, 0x100E, 0, &rcItem, , ahk_id %hLv%
    itemH := NumGet(rcItem, 12, "Int") - NumGet(rcItem, 4, "Int")
    LV_Delete()
    if (itemH <= 0)
        itemH := 17
    SendMessage, 0x101F, 0, 0, , ahk_id %hLv%
    hHdr := ErrorLevel
    hdrH := 0
    if (hHdr) {
        VarSetCapacity(rcH, 16, 0)
        DllCall("GetClientRect", "Ptr", hHdr, "Ptr", &rcH)
        hdrH := NumGet(rcH, 12, "Int") - NumGet(rcH, 4, "Int")
    }
    if (hdrH <= 0)
        hdrH := 22
}

Cockpit_MeasureLvHeight(hLv, lvRows) {
    Cockpit_ListViewGetHeaderAndItemHeight(hLv, hdrH, itemH)
    return hdrH + lvRows * itemH + 4
}

Cockpit_StyleListView(hLv) {
    LVS_EX_FULLROWSELECT := 0x20
    LVS_EX_DOUBLEBUFFER  := 0x10000
    exMask := LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER
    SendMessage, 0x1036, %exMask%, %exMask%, , ahk_id %hLv%
    SendMessage, 0x1003, 1, 0, , ahk_id %hLv%
    SendMessage, 0x1003, 2, 0, , ahk_id %hLv%
    SendMessage, 0x1001, 0, 0x1E1E1E,, ahk_id %hLv%
    SendMessage, 0x1024, 0, 0xF2F4F5,, ahk_id %hLv%
    SendMessage, 0x1026, 0, 0x1E1E1E,, ahk_id %hLv%
}

;-------------------------------------------------------------------------------
; Cockpit_DisableColumnResize - apply HDS_NOSIZING to the LV's header window
; so the user can't drag column separators to resize them.
;-------------------------------------------------------------------------------
Cockpit_DisableColumnResize(hLv) {
    HDS_NOSIZING := 0x0800
    GWL_STYLE    := -16
    SendMessage, 0x101F, 0, 0, , ahk_id %hLv%   ; LVM_GETHEADER
    hHdr := ErrorLevel
    if (!hHdr)
        return
    current := DllCall("GetWindowLong", "Ptr", hHdr, "Int", GWL_STYLE, "UInt")
    DllCall("SetWindowLong", "Ptr", hHdr, "Int", GWL_STYLE, "UInt", current | HDS_NOSIZING)
}

Cockpit_FillLastColumn(hLv, colIndex) {
    if (!hLv || colIndex <= 0)
        return
    ; LVM_SETCOLUMNWIDTH (0x101E), LVSCW_AUTOSIZE_USEHEADER (-2)
    SendMessage, 0x101E, % (colIndex - 1), -2, , ahk_id %hLv%
}

Cockpit_ForceNoHScroll(hLv) {
    if (!hLv)
        return
    GWL_STYLE := -16
    WS_HSCROLL := 0x00100000
    style := DllCall("GetWindowLong", "Ptr", hLv, "Int", GWL_STYLE, "UInt")
    DllCall("SetWindowLong", "Ptr", hLv, "Int", GWL_STYLE, "UInt", style & ~WS_HSCROLL)
}

Cockpit_SetRedraw(hwnd, enabled) {
    if (!hwnd)
        return
    ; WM_SETREDRAW (0x000B)
    SendMessage, 0x000B, % enabled ? 1 : 0, 0, , ahk_id %hwnd%
    if (enabled) {
        ; RedrawWindow: RDW_INVALIDATE|RDW_UPDATENOW|RDW_ALLCHILDREN
        DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001 | 0x0100 | 0x0080)
    }
}

;===============================================================================
; Periodic UI refresh (~1 Hz): see Cockpit_RefreshTicker
; Manual F5 calls Cockpit_RefreshBody directly.
;===============================================================================
Cockpit_Refresh:
    Cockpit_RefreshBody()
Return

Agg_Tick:
    Agg_TickBody()
Return

; First run is scheduled negatively from startup then every 1000 ms.
Cockpit_RefreshTicker:
    Cockpit_RefreshBody()
    SetTimer, Cockpit_RefreshTicker, % 1000
Return

; User switched main tab: defer content refresh so SysTabControl32 can finish painting first.
Cockpit_MainTab:
    SetTimer, Cockpit_AfterMainTab, -95
Return

Cockpit_AfterMainTab:
    ; Skip header bulk GuiControl churn; timer refresh updates session/ETA within ~1 s.
    Cockpit_RefreshBody(true)
Return

Cockpit_PollMainTab() {
    global g_ageStandalone, g_cockpitMainTabIdx
    if (g_ageStandalone)
        return
    Gui, Cockpit:Default
    GuiControlGet, tabName,, txMainTabs
    if ErrorLevel
        return
    tabName := Trim(tabName)
    ; Tab2 (no AltSubmit) returns the caption, not +0 index; numeric index gates cheap tab-specific UI work.
    if (tabName = "Recent events")
        g_cockpitMainTabIdx := 2
    else
        g_cockpitMainTabIdx := 1
}

Cockpit_RefreshBody(skipHeader := false) {
    global g_cockpitStartEpoch, g_ageStandalone
    Gui, Cockpit:Default
    Cockpit_PollMainTab()
    state := CockpitState_Read()
    age := CockpitState_AgeSeconds()
    stale := (age < 0 || age > 10)

    if (!state["Global"].HasKey("sessionStartEpoch")) {
        Cockpit_RenderStandalone()
        return
    }

    ; Keep placeholders until Aggregator writes at least once after Cockpit opens.
    lastAgg := state["Global"].HasKey("lastAggregatorEpoch")
        ? (state["Global"]["lastAggregatorEpoch"] + 0) : 0
    if (lastAgg < g_cockpitStartEpoch) {
        Cockpit_RenderStartupPlaceholders(state)
        return
    }

    if (!g_ageStandalone && Cockpit_ShouldAutoCloseOnAllDead(state)) {
        SetTimer, Agg_Tick, Off
        SetTimer, Cockpit_RefreshTicker, Off
        ExitApp
    }

    instCfg := state["Global"].HasKey("instancesConfigured") ? (state["Global"]["instancesConfigured"] + 0) : 0
    if (instCfg <= 0)
        instCfg := botConfig.get("Instances") + 0
    if (instCfg <= 0)
        instCfg := 1
    Cockpit_MaybeRelayoutForInstanceCount(instCfg)

    if (!skipHeader)
        Cockpit_RenderHeader(state, stale)
    Cockpit_RenderInstances(state)
    Cockpit_RenderEvents(state)
}

Cockpit_ShouldAutoCloseOnAllDead(state) {
    if (!IsObject(state) || !IsObject(state["Global"]))
        return false
    g := state["Global"]
    configured := g.HasKey("instancesConfigured") ? (g["instancesConfigured"] + 0) : 0
    dead := g.HasKey("instancesDead") ? (g["instancesDead"] + 0) : 0
    if (configured <= 0)
        return false
    return (dead >= configured)
}

;===============================================================================
; Header rendering
;===============================================================================
Cockpit_RenderHeader(state, stale := false) {
    global THEME_TEXT, THEME_MUTED, THEME_ACCENT, THEME_SUCCESS, THEME_WARN, THEME_DANGER
        , g_cockpitStartEpoch
    g := state["Global"]
    e := state["Eta"]
    q := state["Queues"]
    t := state["Throughput"]
    injReady := Cockpit_IsInjectablesReady(state)

    ; ---- Mode (prominent) ----
    mode := g["modeActive"]
    Cockpit_UpdateAgeButtonVisibility(mode)
    modeColor := stale ? THEME_WARN : THEME_ACCENT
    modeText := stale ? (mode . "  [STALE]") : mode
    GuiControl, Cockpit:+c%modeColor%, lblModeVal
    GuiControl, Cockpit:, lblModeVal, %modeText%

    ; ---- Instances summary ----
    runN := (g["instancesRunning"] + 0)
    stuckN := (g["instancesStuck"] + 0)
    idleN := (g["instancesIdle"] + 0)
    deadN := (g["instancesDead"] + 0)
    mainStatusL := ""
    if ((g["mainEnabled"] + 0)) {
        mainStatus := state["Main"].HasKey("status") ? state["Main"]["status"] : "idle"
        mainStatusL := Cockpit_ToLower(mainStatus)
    }
    instParts := []
    if (runN > 0)
        instParts.Push(runN . " running")
    if (stuckN > 0)
        instParts.Push(stuckN . " stuck")
    if (idleN > 0)
        instParts.Push(idleN . " idle")
    if (deadN > 0)
        instParts.Push(deadN . " dead")
    if ((g["mainEnabled"] + 0))
        instParts.Push("Main: " . mainStatusL)
    instLine := Cockpit_JoinWithSep(instParts, " - ")
    if (instLine = "")
        instLine := "-"
    GuiControl, Cockpit:+c%THEME_TEXT%, lblInstRunVal
    GuiControl, Cockpit:, lblInstRunVal, %instLine%
    Cockpit_LayoutInstancesSingle(instLine)

    ; ---- Injectable (no source suffix) ----
    injTotal := q.HasKey("injectableNow") ? (q["injectableNow"] + 0) : 0
    if (injReady)
        injColor := (injTotal > 0) ? THEME_SUCCESS : THEME_MUTED
    else
        injColor := THEME_MUTED
    GuiControl, Cockpit:+c%injColor%, lblInjVal
    GuiControl, Cockpit:, lblInjVal, % injReady ? (injTotal . " accounts") : "-"

    ; ---- Throughput / Avg run / Runs (three independent fields) ----
    runs := t.HasKey("runsCompletedSession") ? (t["runsCompletedSession"] + 0) : 0
    avg := t.HasKey("avgRunSecondsSession") ? (t["avgRunSecondsSession"] + 0) : 0
    rph := t.HasKey("runsPerHourGlobal") ? (t["runsPerHourGlobal"] + 0) : 0
    if (runs <= 0) {
        avg := 0
        rph := 0
    }
    GuiControl, Cockpit:, lblPaceVal, % (rph > 0 ? (rph . " injects/hour") : "-")
    GuiControl, Cockpit:, lblAvgVal,  % (avg > 0 ? Metrics_FormatDurationMS(avg) : "-")
    GuiControl, Cockpit:, lblRunsVal, % runs . " completed this session"

    ; ---- Session ----
    nowEpoch := CockpitState_NowEpoch()
    sStart := (g["sessionStartEpoch"] + 0)
    sessSec := nowEpoch - sStart
    GuiControl, Cockpit:, lblSesVal, % Metrics_FormatDurationHMS(sessSec)

    ; ---- ETA (no bottleneck parens) ----
    etaSec := (e["etaSecondsGlobal"] + 0)
    if (injReady && etaSec <= 0 && runs > 0) {
        maxInstEta := 0
        for _, inst in state["Instances"] {
            instId := inst.HasKey("instanceId") ? (inst["instanceId"] + 0) : 0
            instEta := inst.HasKey("etaSeconds") ? (inst["etaSeconds"] + 0) : 0
            if (instEta > 0) {
                if (instEta > maxInstEta)
                    maxInstEta := instEta
                continue
            }

            injN := q.HasKey("injectable_" . instId) ? (q["injectable_" . instId] + 0) : 0
            avgRunSec := inst.HasKey("avgRunSeconds") ? (inst["avgRunSeconds"] + 0) : 0

            candEta := (injN > 0 && avgRunSec > 0) ? (injN * avgRunSec) : 0
            if (candEta > maxInstEta)
                maxInstEta := candEta
        }
        etaSec := maxInstEta
    }
    if (injReady) {
        if (etaSec > 0)
            etaTxt := Metrics_FormatDurationHM(etaSec)
        else if (injTotal <= 0)
            etaTxt := "0h 0m"
        else
            etaTxt := "--"
        etaColor := (etaSec > 0) ? THEME_ACCENT : THEME_MUTED
    } else {
        etaTxt := "-"
        etaColor := THEME_MUTED
    }
    GuiControl, Cockpit:+c%etaColor%, lblEtaVal
    GuiControl, Cockpit:, lblEtaVal, %etaTxt%

    ; ---- Progress bar ----
    target := (e["etaTargetSnapshot"] + 0)
    done := runs
    total := done + target
    pct := (total > 0) ? Round(done / total * 1000) : 0
    GuiControl, Cockpit:, lblPrgBar, %pct%
    if (pct >= 700)
        GuiControl, Cockpit:+c%THEME_SUCCESS%, lblPrgVal
    else if (pct >= 300)
        GuiControl, Cockpit:+c%THEME_ACCENT%, lblPrgVal
    else
        GuiControl, Cockpit:+c%THEME_MUTED%, lblPrgVal
    pct100 := (total > 0) ? Round(done / total * 100) : 0
    GuiControl, Cockpit:, lblPrgVal, % pct100 . "%"
}

;===============================================================================
; Instance ListView rendering
;===============================================================================
Cockpit_RenderInstances(state) {
    global g_lastLvRowSigs, g_rowMetaByRow, g_lvSortKey, g_lvSortDir, g_lvColOrder
        , g_cockpitMainTabIdx

    ; ListView repaint is costly; defer row/column churn while Recent events tab is visible.
    if (g_cockpitMainTabIdx != 1)
        return

    g := state["Global"]
    instances := state["Instances"]
    injReady := Cockpit_IsInjectablesReady(state)
    rows := []

    for idx, inst in instances {
        N := inst["instanceId"]
        prefix := N
        statusTxt := inst["status"] != "" ? inst["status"] : "idle"
        statusLower := Cockpit_ToLower(statusTxt)
        statusTxt := Cockpit_CapitalizeFirst(statusTxt)
        isActiveStatus := (statusLower = "running" || statusLower = "stuck" || statusLower = "pausing")
        rawAccount := inst["accountFileName"]
        account := Cockpit_FormatAccountFile(rawAccount)
        livePacks := (inst.HasKey("livePacks") && inst["livePacks"] != "") ? (inst["livePacks"] + 0) : -1
        pks := (livePacks >= 0) ? livePacks : "-"
        stk := (inst["stuckCountSession"] + 0)
        injN := (inst["injectables"] + 0)
        injTxt := injReady ? injN : "-"
        currentRunSec := inst.HasKey("currentRunSeconds") ? (inst["currentRunSeconds"] + 0) : 0
        gpFoundCount := inst.HasKey("gpFoundCount") ? (inst["gpFoundCount"] + 0) : 0
        runsSessionInst := inst.HasKey("runsSession") ? (inst["runsSession"] + 0) : 0
        hasCompletedRun := (runsSessionInst > 0)
        runsTxt := runsSessionInst
        avgRunSec := hasCompletedRun ? (inst.HasKey("avgRunSeconds") ? (inst["avgRunSeconds"] + 0) : 0) : 0
        avgRunTxt := (avgRunSec > 0) ? Metrics_FormatDurationMmSs(avgRunSec) : "-"
        if (isActiveStatus)
            currentRunTxt := Metrics_FormatDurationMS(currentRunSec)
        else
            currentRunTxt := "-"
        gpTxt := Cockpit_GpFoundColumnEligible() ? gpFoundCount : ""
        etaSec := (inst["etaSeconds"] + 0)
        etaLabel := inst.HasKey("etaLabel") ? inst["etaLabel"] : ""
        if (!hasCompletedRun) {
            etaTxt := "--"
        } else if (etaLabel != "") {
            etaTxt := etaLabel
        } else if (etaSec > 0) {
            etaTxt := Metrics_FormatDurationHM(etaSec)
        } else if (injReady && avgRunSec > 0) {
            etaTxt := (injN <= 0) ? "0h 0m" : Metrics_FormatDurationHM(injN * avgRunSec)
        } else {
            etaTxt := "--"
        }
        if (!isActiveStatus) {
            account := "-"
            pks := "-"
            if (statusLower = "dead") {
                avgRunTxt := "-"
                etaTxt := "--"
            } else if (!hasCompletedRun) {
                avgRunTxt := "-"
                etaTxt := "--"
            }
        }
        etaTxt := Cockpit_FormatEtaAligned(etaTxt)
        etaTxt := Cockpit_CapitalizeFirst(etaTxt)
        rows.Push({ "id": prefix, "status": statusTxt, "account": account, "packs": pks
            , "stuck": stk, "queue": injTxt, "runs": runsTxt, "currentRun": currentRunTxt
            , "average": avgRunTxt, "eta": etaTxt, "gpFound": gpTxt
            , "instanceId": N, "accountFileName": rawAccount })
    }

    if (g_lvSortKey != "" && g_lvSortDir != 0)
        Cockpit_SortRows(rows, g_lvSortKey, g_lvSortDir)

    rowSigs := []
    g_rowMetaByRow := []
    Loop, % rows.Length() {
        r := rows[A_Index]
        rowSig := ""
        Loop, % g_lvColOrder.Length() {
            colKey := g_lvColOrder[A_Index]
            if (A_Index > 1)
                rowSig .= "|"
            rowSig .= Cockpit_GetColumnValue(r, colKey)
        }
        rowSigs.Push(rowSig)
        g_rowMetaByRow[A_Index] := { "instanceId": r.instanceId, "accountFileName": r.accountFileName }
    }

    Gui, Cockpit:Default
    Gui, ListView, InstancesLv
    rowCount := LV_GetCount()
    needsRebuild := (rowCount != rows.Length() || g_lastLvRowSigs.Length() != rowSigs.Length())

    if (needsRebuild) {
        GuiControl, -Redraw, InstancesLv
        LV_Delete()
        Loop, % rows.Length() {
            r := rows[A_Index]
            vals := Cockpit_LvValuesFromRow(r)
            LV_Add("", vals*)
        }
        GuiControl, +Redraw, InstancesLv
    } else {
        Loop, % rows.Length() {
            if (g_lastLvRowSigs[A_Index] = rowSigs[A_Index])
                continue
            r := rows[A_Index]
            vals := Cockpit_LvValuesFromRow(r)
            LV_Modify(A_Index, "", vals*)
        }
    }

    g_lastLvRowSigs := rowSigs
    Cockpit_ApplyColumnsToListView()
}

Cockpit_IsInjectablesReady(state) {
    q := state["Queues"]
    if (!IsObject(q))
        return false
    src := q.HasKey("injectableSource") ? Trim(q["injectableSource"]) : ""
    ; Only list_current is authoritative for the live queue.
    return (src = "list_current")
}

Cockpit_SortRows(ByRef rows, sortKey, sortDir) {
    count := rows.Length()
    if (count < 2)
        return
    start := 1
    outerMax := count - start
    if (outerMax <= 0)
        return
    Loop, % outerMax {
        i := start
        innerMax := count - A_Index
        while (i <= innerMax) {
            if (Cockpit_ShouldSwapRows(rows[i], rows[i + 1], sortKey, sortDir)) {
                tmp := rows[i]
                rows[i] := rows[i + 1]
                rows[i + 1] := tmp
            }
            i++
        }
    }
}

Cockpit_ShouldSwapRows(a, b, sortKey, sortDir) {
    cmp := Cockpit_CompareRows(a, b, sortKey)
    if (sortDir > 0)
        return (cmp > 0)
    return (cmp < 0)
}

Cockpit_CompareRows(a, b, sortKey) {
    va := Cockpit_GetSortValue(a, sortKey)
    vb := Cockpit_GetSortValue(b, sortKey)
    if (va.isNum && vb.isNum) {
        if (va.num > vb.num)
            return 1
        if (va.num < vb.num)
            return -1
        return 0
    }
    if (va.txt > vb.txt)
        return 1
    if (va.txt < vb.txt)
        return -1
    return 0
}

Cockpit_GetSortValue(row, sortKey) {
    v := row.HasKey(sortKey) ? row[sortKey] : ""
    out := { "isNum": false, "num": 0, "txt": Cockpit_ToLower(v) }
    if (v = "-" || v = "--" || v = "")
        return { "isNum": true, "num": -1, "txt": "" }
    if (RegExMatch(v, "^\d+$")) {
        out.isNum := true
        out.num := v + 0
        return out
    }
    if (RegExMatch(v, "^(\d+):(\d{2})$", m)) {
        out.isNum := true
        out.num := (m1 + 0) * 60 + (m2 + 0)
        return out
    }
    if (RegExMatch(v, "^(\d+)h(?:\s+(\d+)m)?$", m)) {
        out.isNum := true
        out.num := (m1 + 0) * 3600 + ((m2 = "") ? 0 : (m2 + 0) * 60)
        return out
    }
    if (RegExMatch(v, "^(\d+)m$", m)) {
        out.isNum := true
        out.num := (m1 + 0) * 60
        return out
    }
    if (RegExMatch(v, "^(\d+)d\s+(\d+)h\s+(\d+)m$", m)) {
        out.isNum := true
        out.num := (m1 + 0) * 86400 + (m2 + 0) * 3600 + (m3 + 0) * 60
        return out
    }
    return out
}

Cockpit_FormatEtaAligned(txt) {
    if (txt = "" || txt = "-" || txt = "--")
        return txt
    if (RegExMatch(txt, "^(\d+)h\s+(\d+)m$", m))
        return Format("{:02}", m1 + 0) . "h " . Format("{:02}", m2 + 0) . "m"
    if (RegExMatch(txt, "^(\d+)m$", m))
        return "00h " . Format("{:02}", m1 + 0) . "m"
    if (RegExMatch(txt, "^(\d+)h$", m))
        return Format("{:02}", m1 + 0) . "h 00m"
    if (RegExMatch(txt, "^(\d+)d\s+(\d+)h\s+(\d+)m$", m))
        return (m1 + 0) . "d " . Format("{:02}", m2 + 0) . "h " . Format("{:02}", m3 + 0) . "m"
    return txt
}

Cockpit_CapitalizeFirst(txt) {
    if (txt = "" || txt = "-")
        return txt
    first := SubStr(txt, 1, 1)
    StringUpper, firstU, first
    return firstU . SubStr(txt, 2)
}

Cockpit_ToLower(txt) {
    StringLower, out, txt
    return out
}

Cockpit_LayoutInstancesSingle(instLine) {
    global g_cockpitW, INST_SEG_X_RUN, g_instSingleMode, g_instLayoutLineCache
    mainW := g_cockpitW - INST_SEG_X_RUN - 20
    if (mainW < 40)
        mainW := 40
    if (g_instSingleMode && g_instLayoutLineCache = instLine)
        return
    GuiControl, Cockpit:Move, lblInstRunVal, % "x" . INST_SEG_X_RUN . " w" . mainW
    GuiControl, Cockpit:Move, lblInstStkVal, % "x" . INST_SEG_X_RUN . " w0"
    GuiControl, Cockpit:Move, lblInstIdleVal, % "x" . INST_SEG_X_RUN . " w0"
    GuiControl, Cockpit:Move, lblInstDeadVal, % "x" . INST_SEG_X_RUN . " w0"
    GuiControl, Cockpit:Move, lblInstMainVal, % "x" . INST_SEG_X_RUN . " w0"
    g_instSingleMode := true
    g_instLayoutLineCache := instLine
}

;-------------------------------------------------------------------------------
; Cockpit_RenderInstanceSegments - render the Instances summary line as multiple
; colored segments side by side, using the five pre-built colored Text controls.
; segments: array of {text, label, color}. Empty texts are skipped; unused
; labels are cleared and collapsed to width 0.
;-------------------------------------------------------------------------------
Cockpit_RenderInstanceSegments(segments) {
    global INST_SEG_X_RUN, g_instSingleMode, g_instLayoutLineCache
    g_instLayoutLineCache := ""
    slotOrder := ["lblInstRunVal", "lblInstStkVal", "lblInstIdleVal", "lblInstDeadVal", "lblInstMainVal"]
    used := {}
    x := INST_SEG_X_RUN
    slotIdx := 1
    Loop, % segments.Length() {
        seg := segments[A_Index]
        if (!IsObject(seg))
            continue
        txt := seg.text
        if (txt = "")
            continue
        if (slotIdx > slotOrder.Length())
            break
        lbl := slotOrder[slotIdx]
        slotIdx++
        col := seg.color
        GuiControl, Cockpit:+c%col%, %lbl%
        GuiControl, Cockpit:, %lbl%, %txt%
        w := Cockpit_MeasureLabelText(lbl, txt)
        if (w <= 0)
            w := Cockpit_TextPx(txt)
        w += 4
        GuiControl, Cockpit:Move, %lbl%, % "x" . x . " w" . w
        x += w
        used[lbl] := true
    }
    Loop, % slotOrder.Length() {
        lbl := slotOrder[A_Index]
        if (used.HasKey(lbl))
            continue
        GuiControl, Cockpit:, %lbl%,
        GuiControl, Cockpit:Move, %lbl%, % "x" . INST_SEG_X_RUN . " w0"
    }
    g_instSingleMode := false
}

;-------------------------------------------------------------------------------
; Cockpit_MeasureLabelText - measure rendered pixel width of `txt` using the
; font currently assigned to GUI control `controlName`. Returns 0 if anything
; fails so the caller can fall back to a heuristic.
;-------------------------------------------------------------------------------
Cockpit_MeasureLabelText(controlName, txt) {
    if (txt = "")
        return 0
    GuiControlGet, hCtl, Cockpit:Hwnd, %controlName%
    if (!hCtl)
        return 0
    dc := DllCall("GetDC", "Ptr", hCtl, "Ptr")
    if (!dc)
        return 0
    SendMessage, 0x31, 0, 0,, ahk_id %hCtl%   ; WM_GETFONT
    hFont := ErrorLevel
    oldFont := 0
    if (hFont != "FAIL" && hFont != 0)
        oldFont := DllCall("SelectObject", "Ptr", dc, "Ptr", hFont, "Ptr")
    VarSetCapacity(rect, 16, 0)
    ; DT_CALCRECT (0x400) | DT_EXPANDTABS (0x40) | DT_SINGLELINE (0x20) | DT_NOPREFIX (0x800)
    DllCall("DrawText", "Ptr", dc, "Ptr", &txt, "Int", -1, "Ptr", &rect, "UInt", 0x8E0)
    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    if (oldFont)
        DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont, "Ptr")
    DllCall("ReleaseDC", "Ptr", hCtl, "Ptr", dc)
    return w
}

Cockpit_TextPx(txt) {
    if (txt = "")
        return 0
    return 6 + StrLen(txt) * 5
}

Cockpit_JoinWithSep(parts, sep := " - ") {
    out := ""
    if (!IsObject(parts))
        return out
    Loop, % parts.Length() {
        part := parts[A_Index]
        if (part = "")
            continue
        if (out != "")
            out .= sep
        out .= part
    }
    return out
}

Cockpit_FormatAccountFile(filename) {
    if (filename = "" || filename = "-")
        return "-"
    ; Strip only the .xml extension; keep packs/timestamp/index/rarity visible.
    if (SubStr(filename, -3) = ".xml")
        return SubStr(filename, 1, StrLen(filename) - 4)
    return filename
}

;===============================================================================
; Event log helpers ( monospace columns: time | bucket | detail )
;===============================================================================
Cockpit_EventTypeBucket(level, scope, inst) {
    if (scope = "inst") {
        n := inst + 0
        if (n <= 0)
            return "Instance ?"
        return "Instance " . n
    }
    if (scope = "global")
        return (level = "warn") ? "Warnings" : "System"
    return "-"
}

Cockpit_PadFixed(field, width) {
    len := StrLen(field)
    if (len >= width)
        return SubStr(field, 1, width)
    pad := ""
    Loop, % (width - len)
        pad .= A_Space
    return field . pad
}

;===============================================================================
; Events rendering
;===============================================================================
Cockpit_RenderEvents(state) {
    global g_eventFilter, g_lastEventsText, g_cockpitMainTabIdx

    evtShowCtl := g_cockpitMainTabIdx = 2
    events := state["Events"]

    ; Always consume state fresh from CockpitState.ini; only repaint the Events tab control while it is visible
    ; (cheap enough vs ListView churn and avoids misleading placeholder text after reopen).
    if (events.Count() = 0) {
        if (!evtShowCtl)
            return
        if (g_lastEventsText != "(No events yet)") {
            GuiControl, Cockpit:-Redraw, EventsLog
            GuiControl, Cockpit:, EventsLog, (No events yet)
            GuiControl, Cockpit:+Redraw, EventsLog
            g_lastEventsText := "(No events yet)"
        }
        return
    }

    keys := []
    for k, v in events
        keys.Push(k)
    rawKeys := Cockpit_JoinKeys(keys, "`n")
    Sort, rawKeys, R   ; reverse lexicographic -> newest first (event_NNNN)

    maxBucketW := 8
    Loop, Parse, rawKeys, `n, `r
    {
        if (A_LoopField = "")
            continue
        line := events[A_LoopField]
        parts := StrSplit(line, "|")
        if (parts.Length() < 6)
            continue
        level := parts[2]
        scope := parts[3]
        inst  := parts[4]
        cat   := parts[5]
        det   := parts[6]
        if (!Cockpit_EventMatchesFilter(level, scope, inst, cat))
            continue
        bw := StrLen(Cockpit_EventTypeBucket(level, scope, inst))
        if (bw > maxBucketW)
            maxBucketW := bw
    }

    out := ""
    Loop, Parse, rawKeys, `n, `r
    {
        if (A_LoopField = "")
            continue
        line := events[A_LoopField]
        parts := StrSplit(line, "|")
        if (parts.Length() < 6)
            continue
        epoch := parts[1]
        level := parts[2]
        scope := parts[3]
        inst  := parts[4]
        cat   := parts[5]
        det   := parts[6]
        if (!Cockpit_EventMatchesFilter(level, scope, inst, cat))
            continue
        timeStr := Cockpit_EpochToLocalHMS(epoch)
        bucket := Cockpit_EventTypeBucket(level, scope, inst)
        out .= Cockpit_PadFixed(timeStr, 8) . " | " . Cockpit_PadFixed(bucket, maxBucketW) . " | " . det . "`r`n"
    }
    if (!evtShowCtl)
        return

    if (g_lastEventsText != out) {
        GuiControl, Cockpit:-Redraw, EventsLog
        GuiControl, Cockpit:, EventsLog, %out%
        GuiControl, Cockpit:+Redraw, EventsLog
        g_lastEventsText := out
    }
}

Cockpit_EventMatchesFilter(level, scope, inst, cat) {
    global g_eventFilter
    f := Trim(g_eventFilter)
    if (f = "" || f = "All")
        return true
    if (f = "Warnings")
        return (level = "warn")
    if (f = "System")
        return (scope = "global")
    if (RegExMatch(f, "^Instance (\d+)$", m))
        return (scope = "inst" && (inst + 0) = (m1 + 0))
    return true
}

Cockpit_LoadEventFilter() {
    ini := Cockpit_UIIniPath()
    IniRead, f, %ini%, Events, Filter, All
    if (f = "ERROR" || f = "")
        return "All"
    return f
}

Cockpit_SaveEventFilter(filter) {
    ini := Cockpit_UIIniPath()
    IniWrite, %filter%, %ini%, Events, Filter
}

Cockpit_GpFoundColumnEligible() {
    global botConfig
    if (!IsObject(botConfig))
        return false
    return (Trim(botConfig.get("deleteMethod")) = "Inject Wonderpick 96P+")
}

Cockpit_DefaultColumnKeys() {
    keys := ["id", "status", "account", "packs", "stuck", "queue"
        , "runs", "currentRun", "average", "eta"]
    if (Cockpit_GpFoundColumnEligible())
        keys.Push("gpFound")
    return keys
}

Cockpit_BuildInstanceLvHeaderCsv() {
    global g_lvColOrder
    meta := Cockpit_GetColumnMeta()
    hdr := ""
    Loop, % g_lvColOrder.Length() {
        key := g_lvColOrder[A_Index]
        if (!meta.HasKey(key))
            continue
        tit := Cockpit_GetTableHeaderTitle(key, meta[key].title)
        hdr .= (hdr != "" ? "|" : "") . tit
    }
    return hdr
}

Cockpit_GetColumnMeta() {
    meta := {}
    meta["id"] := { "title": "#", "width": 28 }
    meta["status"] := { "title": "Status", "width": 70 }
    meta["account"] := { "title": "Currently Injected", "width": 170 }
    meta["packs"] := { "title": "Packs", "width": 50 }
    meta["stuck"] := { "title": "Stuck", "width": 42 }
    meta["queue"] := { "title": "Queue", "width": 50 }
    meta["runs"] := { "title": "Runs", "width": 44 }
    meta["currentRun"] := { "title": "Current Run Duration", "width": 88 }
    meta["average"] := { "title": "Average", "width": 74 }
    meta["eta"] := { "title": "ETA", "width": 66 }
    meta["gpFound"] := { "title": "GP Found", "width": 72 }
    return meta
}

Cockpit_GetTableHeaderTitle(key, defaultTitle) {
    if (key = "gpFound")
        return "GP"
    if (key = "currentRun")
        return "Current"
    return defaultTitle
}

Cockpit_LoadColumnsPrefs() {
    global g_lvAllColKeys, g_lvColOrder, g_lvColVisible
    ini := Cockpit_UIIniPath()
    defaultOrder := []
    for _, key in g_lvAllColKeys
        defaultOrder.Push(key)
    g_lvColOrder := []
    IniRead, rawOrder, %ini%, Columns, Order, %A_Space%
    if (rawOrder = "ERROR" || rawOrder = "") {
        for _, key in defaultOrder
            g_lvColOrder.Push(key)
    } else {
        seen := {}
        Loop, Parse, rawOrder, |
        {
            key := Trim(A_LoopField)
            if (key = "" || seen.HasKey(key))
                continue
            if (Cockpit_ArrayHasValue(g_lvAllColKeys, key)) {
                g_lvColOrder.Push(key)
                seen[key] := true
            }
        }
        for _, key in defaultOrder {
            if (!seen.HasKey(key))
                g_lvColOrder.Push(key)
        }
    }
    g_lvColVisible := {}
    IniRead, rawVisible, %ini%, Columns, Visible, %A_Space%
    if (rawVisible = "ERROR" || rawVisible = "") {
        for _, key in g_lvAllColKeys
            g_lvColVisible[key] := true
    } else {
        Loop, Parse, rawVisible, |
        {
            key := Trim(A_LoopField)
            if (key != "")
                g_lvColVisible[key] := true
        }
        for _, key in g_lvAllColKeys {
            if (!g_lvColVisible.HasKey(key))
                g_lvColVisible[key] := false
        }
    }
    if (Cockpit_CountVisibleColumns() <= 0)
        g_lvColVisible["id"] := true
    ordered := []
    for _, key in g_lvColOrder {
        if (key = "id")
            continue
        ordered.Push(key)
    }
    g_lvColOrder := ["id"]
    for _, key in ordered
        g_lvColOrder.Push(key)
    g_lvColVisible["id"] := true
    Cockpit_ClearColumnsWidthCache()
    Cockpit_LoadColumnsWidthPrefs()
}

Cockpit_SaveColumnsPrefs() {
    global g_lvColOrder, g_lvColVisible
    ini := Cockpit_UIIniPath()
    IniWrite, % Cockpit_JoinKeys(g_lvColOrder, "|"), %ini%, Columns, Order
    visible := []
    for _, key in g_lvColOrder {
        if (g_lvColVisible.HasKey(key) && g_lvColVisible[key])
            visible.Push(key)
    }
    IniWrite, % Cockpit_JoinKeys(visible, "|"), %ini%, Columns, Visible
}

Cockpit_LoadColumnsWidthPrefs() {
    global g_lvAllColKeys, g_lvColWidths, g_lvColWidthsSig, g_lvLastAppliedLayoutSig
    ini := Cockpit_UIIniPath()
    g_lvColWidths := {}
    IniRead, sig, %ini%, ColumnWidths, Signature, %A_Space%
    IniRead, keysRaw, %ini%, ColumnWidths, Keys, %A_Space%
    if (keysRaw = "ERROR" || keysRaw = "")
        return
    Loop, Parse, keysRaw, |
    {
        key := Trim(A_LoopField)
        if (key = "")
            continue
        if (!Cockpit_ArrayHasValue(g_lvAllColKeys, key))
            continue
        IniRead, w, %ini%, ColumnWidths, %key%, %A_Space%
        if (w = "ERROR" || w = "")
            continue
        ww := w + 0
        if (ww > 0)
            g_lvColWidths[key] := ww
    }
    if (g_lvColWidths.Count() > 0)
        g_lvColWidthsSig := (sig = "ERROR") ? "" : sig
    g_lvLastAppliedLayoutSig := ""
}

Cockpit_SaveColumnsWidthPrefs() {
    global g_lvColWidths, g_lvColWidthsSig
    ini := Cockpit_UIIniPath()
    keys := []
    for key, w in g_lvColWidths {
        if ((w + 0) > 0)
            keys.Push(key)
    }
    IniWrite, %g_lvColWidthsSig%, %ini%, ColumnWidths, Signature
    IniWrite, % Cockpit_JoinKeys(keys, "|"), %ini%, ColumnWidths, Keys
    for _, key in keys
        IniWrite, % (g_lvColWidths[key] + 0), %ini%, ColumnWidths, %key%
}

Cockpit_ClearColumnsWidthCache() {
    global g_lvColWidths, g_lvColWidthsSig, g_lvLastAppliedLayoutSig
    g_lvColWidths := {}
    g_lvColWidthsSig := ""
    g_lvLastAppliedLayoutSig := ""
}

Cockpit_ColumnsLayoutSignature(targetW) {
    global g_lvColOrder, g_lvColVisible
    parts := [targetW]
    for _, key in g_lvColOrder {
        vis := (g_lvColVisible.HasKey(key) && g_lvColVisible[key]) ? "1" : "0"
        parts.Push(key . ":" . vis)
    }
    return Cockpit_JoinKeys(parts, "|")
}

Cockpit_CountVisibleColumns() {
    global g_lvColOrder, g_lvColVisible
    count := 0
    for _, key in g_lvColOrder {
        if (g_lvColVisible.HasKey(key) && g_lvColVisible[key])
            count += 1
    }
    return count
}

Cockpit_ApplyColumnsToListView(forceRecompute := false) {
    global g_lvColOrder, g_lvColVisible, g_cockpitW, LV_HWND, g_lvColWidths, g_lvColWidthsSig, g_lvLastAppliedLayoutSig
    if (!LV_HWND)
        return
    Gui, Cockpit:Default
    Gui, ListView, InstancesLv
    meta := Cockpit_GetColumnMeta()
    visibleCols := []
    GuiControlGet, lvPos, Cockpit:Pos, InstancesLv
    targetW := lvPosW - 4
    if (targetW <= 0)
        targetW := g_cockpitW - 24
    if (targetW < 120)
        targetW := 120
    sig := Cockpit_ColumnsLayoutSignature(targetW)
    hasRows := (LV_GetCount() > 0)
    useCache := (!forceRecompute && g_lvColWidthsSig = sig && IsObject(g_lvColWidths))
    if (useCache && g_lvLastAppliedLayoutSig = sig)
        return
    Loop, % g_lvColOrder.Length() {
        idx := A_Index
        key := g_lvColOrder[idx]
        if (!meta.HasKey(key))
            continue
        colTitle := Cockpit_GetTableHeaderTitle(key, meta[key].title)
        isVisible := (g_lvColVisible.HasKey(key) && g_lvColVisible[key])
        if (isVisible) {
            minW := Cockpit_MinColumnWidth(key)
            if (useCache && g_lvColWidths.HasKey(key)) {
                w := g_lvColWidths[key] + 0
                if (w < minW)
                    w := minW
                visibleCols.Push({ "idx": idx, "key": key, "title": colTitle, "nat": w, "min": minW, "w": w })
            } else {
                if (hasRows) {
                    LV_ModifyCol(idx, "AutoHdr Center", colTitle)
                    natW := Cockpit_GetLvColumnWidth(LV_HWND, idx)
                } else {
                    natW := meta[key].width + 0
                }
                if (natW < minW)
                    natW := minW
                visibleCols.Push({ "idx": idx, "key": key, "title": colTitle, "nat": natW, "min": minW, "w": natW })
            }
        } else {
            LV_ModifyCol(idx, "0 Center", colTitle)
        }
    }
    visCount := visibleCols.Length()
    if (visCount <= 0)
        return
    if (useCache) {
        Loop, % visCount {
            c := visibleCols[A_Index]
            LV_ModifyCol(c.idx, c.w . " Center", c.title)
        }
        g_lvLastAppliedLayoutSig := sig
        return
    }

    totalNat := 0
    totalMin := 0
    Loop, % visCount {
        c := visibleCols[A_Index]
        totalNat += c.nat
        totalMin += c.min
    }
    if (totalNat <= 0)
        totalNat := totalMin

    if (totalNat < targetW) {
        extra := targetW - totalNat
        rem := extra
        Loop, % visCount {
            i := A_Index
            c := visibleCols[i]
            add := Floor(extra * c.nat / totalNat)
            c.w := c.nat + add
            visibleCols[i] := c
            rem -= add
        }
        i := 1
        while (rem > 0) {
            if (i > visCount)
                i := 1
            c := visibleCols[i]
            c.w += 1
            visibleCols[i] := c
            rem -= 1
            i += 1
        }
    } else if (totalNat > targetW) {
        shrinkNeed := totalNat - targetW
        totalFlex := 0
        Loop, % visCount {
            c := visibleCols[A_Index]
            flex := c.nat - c.min
            if (flex > 0)
                totalFlex += flex
        }
        if (totalFlex > 0) {
            rem := shrinkNeed
            Loop, % visCount {
                i := A_Index
                c := visibleCols[i]
                flex := c.nat - c.min
                cut := (flex > 0) ? Floor(shrinkNeed * flex / totalFlex) : 0
                if (cut > flex)
                    cut := flex
                c.w := c.nat - cut
                visibleCols[i] := c
                rem -= cut
            }
            while (rem > 0) {
                reduced := false
                Loop, % visCount {
                    i := A_Index
                    c := visibleCols[i]
                    if (c.w > c.min) {
                        c.w -= 1
                        visibleCols[i] := c
                        rem -= 1
                        reduced := true
                        if (rem <= 0)
                            break
                    }
                }
                if (!reduced)
                    break
            }
        } else {
            Loop, % visCount {
                i := A_Index
                c := visibleCols[i]
                c.w := c.min
                visibleCols[i] := c
            }
        }
    }

    loopGuard := 0
    Loop, % visCount {
        i := A_Index
        c := visibleCols[i]
        maxW := Cockpit_MaxColumnWidth(c.key)
        if (maxW > 0 && c.w > maxW) {
            c.w := maxW
            visibleCols[i] := c
        }
    }
    while (true) {
        loopGuard += 1
        if (loopGuard > 2000)
            break
        sumW := 0
        Loop, % visCount
            sumW += visibleCols[A_Index].w
        if (sumW = targetW)
            break
        if (sumW < targetW) {
            rem := targetW - sumW
            expanded := false
            while (rem > 0) {
                grew := false
                Loop, % visCount {
                    i := A_Index
                    c := visibleCols[i]
                    maxW := Cockpit_MaxColumnWidth(c.key)
                    if (maxW > 0 && c.w >= maxW)
                        continue
                    c.w += 1
                    visibleCols[i] := c
                    rem -= 1
                    grew := true
                    expanded := true
                    if (rem <= 0)
                        break
                }
                if (!grew)
                    break
            }
            if (!expanded)
                break
        } else {
            rem := sumW - targetW
            reduced := false
            while (rem > 0) {
                shrunk := false
                Loop, % visCount {
                    i := visCount - A_Index + 1
                    c := visibleCols[i]
                    if (c.w > c.min) {
                        c.w -= 1
                        visibleCols[i] := c
                        rem -= 1
                        shrunk := true
                        reduced := true
                        if (rem <= 0)
                            break
                    }
                }
                if (!shrunk)
                    break
            }
            if (!reduced)
                break
        }
    }

    groupIdx := []
    groupSum := 0
    Loop, % visCount {
        i := A_Index
        c := visibleCols[i]
        if (Cockpit_IsUniformMetricColumn(c.key)) {
            groupIdx.Push(i)
            groupSum += c.w
        }
    }
    gCount := groupIdx.Length()
    if (gCount >= 2) {
        baseW := Floor(groupSum / gCount)
        remW := groupSum - (baseW * gCount)
        Loop, % gCount {
            j := groupIdx[A_Index]
            c := visibleCols[j]
            c.w := baseW + ((A_Index <= remW) ? 1 : 0)
            visibleCols[j] := c
        }
    }

    Loop, % visCount {
        c := visibleCols[A_Index]
        LV_ModifyCol(c.idx, c.w . " Center", c.title)
    }
    g_lvColWidths := {}
    Loop, % visCount {
        c := visibleCols[A_Index]
        g_lvColWidths[c.key] := c.w
    }
    g_lvColWidthsSig := sig
    g_lvLastAppliedLayoutSig := sig
    Cockpit_SaveColumnsWidthPrefs()
}

Cockpit_MinColumnWidth(key) {
    if (key = "id")
        return 28
    if (key = "status")
        return 62
    if (key = "account")
        return 130
    if (Cockpit_IsUniformMetricColumn(key))
        return 56
    return 42
}

Cockpit_MaxColumnWidth(key) {
    return 0
}

Cockpit_IsUniformMetricColumn(key) {
    return (key = "packs" || key = "stuck" || key = "gpFound" || key = "runs"
        || key = "queue" || key = "currentRun" || key = "average" || key = "eta")
}

Cockpit_GetLvColumnWidth(hLv, colIndex) {
    if (!hLv || colIndex <= 0)
        return 0
    ; LVM_GETCOLUMNWIDTH = 0x101D
    SendMessage, 0x101D, % (colIndex - 1), 0, , ahk_id %hLv%
    w := ErrorLevel + 0
    if (w < 0)
        w := 0
    return w
}

Cockpit_ArrayHasValue(arr, value) {
    for _, v in arr {
        if (v = value)
            return true
    }
    return false
}

Cockpit_GetColumnValue(row, key) {
    return row.HasKey(key) ? row[key] : ""
}

Cockpit_LvValuesFromRow(row) {
    global g_lvColOrder
    vals := []
    Loop, % g_lvColOrder.Length() {
        colKey := g_lvColOrder[A_Index]
        vals.Push(Cockpit_GetColumnValue(row, colKey))
    }
    return vals
}

Cockpit_ColsEnsureGui() {
    global g_lvColsGuiBuilt, THEME_BG, THEME_TEXT, THEME_MUTED, THEME_FONT, COLS_LV_HWND, ColsLv
    if (g_lvColsGuiBuilt)
        return
    Gui, CockpitCols:New, +HwndhCols +OwnerCockpit +ToolWindow, Cockpit Columns
    Gui, CockpitCols:Default
    Gui, Color, %THEME_BG%, %THEME_BG%
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Text, x12 y10 w360 h18, Order columns and toggle visibility
    Gui, Font, s8 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, x12 y30 w236 h16, Visible columns in table order
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, ListView, x12 y48 w236 h214 vColsLv gCockpit_OnColsLv hwndhColsLv Checked -Multi AltSubmit -Hdr, Column
    COLS_LV_HWND := hColsLv
    LV_ModifyCol(1, "214 Left")
    Gui, Add, Button, x258 y48 w110 h24 gCockpit_ColsMoveUp, Move up
    Gui, Add, Button, x258 y78 w110 h24 gCockpit_ColsMoveDown, Move down
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Button, x12 y272 w102 h24 gCockpit_ColsApply Default, Apply
    Gui, Add, Button, x122 y272 w122 h24 gCockpit_ColsResetDefaults, Reset default
    Gui, Add, Button, x252 y272 w116 h24 gCockpit_ColsCancel, Cancel
    g_lvColsGuiBuilt := 1
}

Cockpit_ColsEditorResetFromCurrent() {
    global g_lvColOrder, g_lvColVisible, g_lvColsEditorOrder, g_lvColsEditorVisible, g_lvColsEditorSel
    g_lvColsEditorOrder := []
    for _, key in g_lvColOrder {
        if (key = "id")
            continue
        g_lvColsEditorOrder.Push(key)
    }
    g_lvColsEditorVisible := {}
    for _, key in g_lvColsEditorOrder
        g_lvColsEditorVisible[key] := (g_lvColVisible.HasKey(key) && g_lvColVisible[key]) ? true : false
    g_lvColsEditorSel := 1
}

Cockpit_ColsEditorRefreshList() {
    global g_lvColsEditorOrder, g_lvColsEditorVisible, g_lvColsEditorSel
    meta := Cockpit_GetColumnMeta()
    maxIdx := g_lvColsEditorOrder.Length()
    if (maxIdx <= 0)
        return
    if (g_lvColsEditorSel <= 0)
        g_lvColsEditorSel := 1
    if (g_lvColsEditorSel > maxIdx)
        g_lvColsEditorSel := maxIdx
    Gui, CockpitCols:Default
    GuiControl, -Redraw, ColsLv
    LV_Delete()
    Loop, % maxIdx {
        key := g_lvColsEditorOrder[A_Index]
        title := meta.HasKey(key) ? meta[key].title : key
        rowOpt := (g_lvColsEditorVisible.HasKey(key) && g_lvColsEditorVisible[key]) ? "Check" : ""
        LV_Add(rowOpt, title)
    }
    LV_Modify(g_lvColsEditorSel, "Select Focus Vis")
    GuiControl, +Redraw, ColsLv
}

Cockpit_ColsCheckedCount() {
    global g_lvColsEditorOrder, g_lvColsEditorVisible
    count := 0
    for _, key in g_lvColsEditorOrder {
        if (g_lvColsEditorVisible.HasKey(key) && g_lvColsEditorVisible[key])
            count += 1
    }
    return count
}

Cockpit_ColsLvRowChecked(row) {
    if (row <= 0)
        return false
    chk := LV_GetNext(row - 1, "C")
    return (chk = row)
}

Cockpit_ColsClearSelection() {
    Gui, CockpitCols:Default
    LV_Modify(0, "-Select -Focus")
}

Cockpit_UIIniPath() {
    return getScriptBaseFolder() . "\Scripts\Include\Cockpit\CockpitUI.ini"
}

Cockpit_LoadWindowPosition(windowKey) {
    ini := Cockpit_UIIniPath()
    section := "Window_" . windowKey
    IniRead, x, %ini%, %section%, X, %A_Space%
    IniRead, y, %ini%, %section%, Y, %A_Space%
    out := { "ok": false, "x": 0, "y": 0 }
    if (x = "ERROR" || y = "ERROR")
        return out
    if (x = "" || y = "")
        return out
    out.ok := true
    out.x := x + 0
    out.y := y + 0
    return out
}

Cockpit_SaveWindowPosition(windowKey, hwnd) {
    if (!hwnd)
        return
    if (!DllCall("IsWindow", "Ptr", hwnd))
        return
    WinGetPos, wx, wy,,, ahk_id %hwnd%
    if (wx = "" || wy = "")
        return
    ini := Cockpit_UIIniPath()
    section := "Window_" . windowKey
    IniWrite, %wx%, %ini%, %section%, X
    IniWrite, %wy%, %ini%, %section%, Y
}

Cockpit_JoinKeys(arr, sep) {
    out := ""
    Loop, % arr.Length() {
        if (A_Index > 1)
            out .= sep
        out .= arr[A_Index]
    }
    return out
}

Cockpit_EpochToLocalHMS(epoch) {
    if (epoch = "" || (epoch + 0) <= 0)
        return "--:--:--"
    ; epoch (UTC seconds) -> explicit local time using current UTC offset
    ; to avoid showing UTC time directly in the Recent Events panel.
    utcStamp := 19700101000000
    utcStamp += (epoch + 0), Seconds
    utcOffsetSec := A_Now
    EnvSub, utcOffsetSec, %A_NowUTC%, Seconds
    localStamp := utcStamp
    localStamp += utcOffsetSec, Seconds
    FormatTime, t, %localStamp%, HH:mm:ss
    return t
}

Cockpit_RenderStandalone() {
    global botConfig, g_lastLvRowSigs, g_rowMetaByRow
        , g_lastEventsText
        , THEME_MUTED, THEME_SUCCESS, THEME_WARN
    botConfig.loadSettingsToConfig("ALL")
    mode := botConfig.get("deleteMethod")
    instances := botConfig.get("Instances") + 0
    if (instances <= 0)
        instances := 1
    inj := Injectables_GetAll(instances, mode)

    GuiControl, Cockpit:+c%THEME_WARN%, lblModeVal
    GuiControl, Cockpit:, lblModeVal, %mode% (offline)
    instLine := "(bot offline) - " . instances . " configured"
    GuiControl, Cockpit:+c%THEME_MUTED%, lblInstRunVal
    GuiControl, Cockpit:, lblInstRunVal, %instLine%
    GuiControl, Cockpit:, lblInstStkVal,
    GuiControl, Cockpit:, lblInstIdleVal,
    GuiControl, Cockpit:, lblInstDeadVal,
    GuiControl, Cockpit:, lblInstMainVal,
    Cockpit_LayoutInstancesSingle(instLine)
    GuiControl, Cockpit:+c%THEME_SUCCESS%, lblInjVal
    GuiControl, Cockpit:, lblInjVal,  % inj.total . " accounts (live scan)"
    GuiControl, Cockpit:, lblPaceVal, -
    GuiControl, Cockpit:, lblAvgVal,  -
    GuiControl, Cockpit:, lblRunsVal, (bot offline)
    GuiControl, Cockpit:, lblSesVal,  (not running)
    GuiControl, Cockpit:, lblEtaVal,  -
    GuiControl, Cockpit:, lblPrgBar,  0
    GuiControl, Cockpit:, lblPrgVal, (bot offline)
    g_lastLvRowSigs := []
    g_rowMetaByRow := []
    Gui, Cockpit:Default
    Gui, ListView, InstancesLv
    GuiControl, -Redraw, InstancesLv
    LV_Delete()
    Loop, % instances {
        N := A_Index
        injN := inj.perInstance.HasKey(N) ? inj.perInstance[N] : 0
        row := { "id": N, "status": "offline", "account": "-", "packs": "-", "stuck": "-"
            , "queue": injN, "runs": "0", "currentRun": "-"
            , "average": "-", "eta": "-", "gpFound": "-" }
        vals := Cockpit_LvValuesFromRow(row)
        LV_Add("", vals*)
    }
    GuiControl, +Redraw, InstancesLv
    GuiControl, Cockpit:, EventsLog, (cockpit standalone mode - aggregator not running)
    g_lastEventsText := "(cockpit standalone mode - aggregator not running)"
}

Cockpit_RenderStartupPlaceholders(state) {
    global botConfig, g_lastLvRowSigs, g_rowMetaByRow
        , g_lastEventsText
        , THEME_MUTED, THEME_WARN
    g := state["Global"]
    instances := g.HasKey("instancesConfigured") ? (g["instancesConfigured"] + 0) : (botConfig.get("Instances") + 0)
    if (instances <= 0)
        instances := 1
    mode := g.HasKey("modeActive") ? g["modeActive"] : botConfig.get("deleteMethod")

    GuiControl, Cockpit:+c%THEME_WARN%, lblModeVal
    GuiControl, Cockpit:, lblModeVal, % mode
    GuiControl, Cockpit:+c%THEME_MUTED%, lblInstRunVal
    GuiControl, Cockpit:, lblInstRunVal, -
    GuiControl, Cockpit:, lblInstStkVal,
    GuiControl, Cockpit:, lblInstIdleVal,
    GuiControl, Cockpit:, lblInstDeadVal,
    GuiControl, Cockpit:, lblInstMainVal,
    Cockpit_LayoutInstancesSingle("-")
    GuiControl, Cockpit:+c%THEME_MUTED%, lblInjVal
    GuiControl, Cockpit:, lblInjVal, -
    GuiControl, Cockpit:, lblPaceVal, -
    GuiControl, Cockpit:, lblAvgVal,  -
    GuiControl, Cockpit:, lblRunsVal, -
    GuiControl, Cockpit:, lblSesVal,  -
    GuiControl, Cockpit:, lblEtaVal,  -
    GuiControl, Cockpit:, lblPrgBar,  0
    GuiControl, Cockpit:, lblPrgVal, -
    GuiControl, Cockpit:, EventsLog, (Waiting for fresh data...)
    g_lastEventsText := "(Waiting for fresh data...)"

    g_lastLvRowSigs := []
    g_rowMetaByRow := []
    Gui, Cockpit:Default
    Gui, ListView, InstancesLv
    GuiControl, -Redraw, InstancesLv
    LV_Delete()
    Loop, % instances {
        N := A_Index
        row := { "id": N, "status": "-", "account": "-", "packs": "-", "stuck": "-"
            , "queue": "-", "runs": "0", "currentRun": "-"
            , "average": "-", "eta": "-", "gpFound": "-" }
        vals := Cockpit_LvValuesFromRow(row)
        LV_Add("", vals*)
    }
    GuiControl, +Redraw, InstancesLv
}

Cockpit_OnInstancesLv:
    global g_lvSortKey, g_lvSortDir, g_contextRow, g_lvColOrder, g_lvColVisible
    if (A_GuiEvent = "ColClick") {
        col := A_EventInfo + 0
        if (col <= 0)
            return
        if (col > g_lvColOrder.Length())
            return
        sortKey := g_lvColOrder[col]
        if (!g_lvColVisible.HasKey(sortKey) || !g_lvColVisible[sortKey])
            return
        if (g_lvSortKey != sortKey) {
            g_lvSortKey := sortKey
            g_lvSortDir := 1
        } else if (g_lvSortDir = 1) {
            g_lvSortDir := -1
        } else {
            g_lvSortKey := ""
            g_lvSortDir := 0
        }
        Cockpit_RefreshBody()
        return
    }
    if (A_GuiEvent = "RightClick" || A_GuiEvent = "R") {
        row := A_EventInfo + 0
        ; Ignore header/background right-click: no row actions in that case.
        if (row <= 0) {
            g_contextRow := 0
            return
        }
        Gui, Cockpit:Default
        g_contextRow := row
        Menu, CockpitRowMenu, Show
        return
    }
    if (A_GuiEvent = "Normal" || A_GuiEvent = "I" || A_GuiEvent = "DoubleClick") {
        Gui, Cockpit:Default
        Gui, ListView, InstancesLv
        row := A_EventInfo + 0
        if (row <= 0) {
            row := LV_GetNext(0, "F")
            if (!row)
                row := LV_GetNext(0)
        }
        if (row > 0)
            g_contextRow := row
        return
    }
return

CockpitGuiContextMenu:
    global g_contextRow
    if (A_GuiControl = "InstancesLv") {
        ; If the click is not on a row (e.g. header), do not show row menu.
        if ((A_EventInfo + 0) <= 0) {
            g_contextRow := 0
            return
        }
        Gui, Cockpit:Default
        Gui, ListView, InstancesLv
        row := LV_GetNext(0, "F")
        if (!row)
            row := LV_GetNext(0)
        if (row > 0) {
            g_contextRow := row
        } else {
            g_contextRow := 0
        }
        Menu, CockpitRowMenu, Show
        return
    }
return

Cockpit_OnEventFilterChange:
    global ddlEventFilter, g_eventFilter
    Gui, Cockpit:Submit, NoHide
    g_eventFilter := ddlEventFilter
    Cockpit_SaveEventFilter(g_eventFilter)
    Cockpit_RefreshBody()
return

Cockpit_OpenColumns:
    Cockpit_ColsEnsureGui()
    Cockpit_ColsEditorResetFromCurrent()
    Cockpit_ColsEditorRefreshList()
    Gui, CockpitCols:Show, AutoSize Center, Cockpit Columns
return

Cockpit_OnColsLv:
    global g_lvColsEditorSel, g_lvColsEditorOrder, g_lvColsEditorVisible
    row := A_EventInfo + 0
    if (row <= 0 || row > g_lvColsEditorOrder.Length())
        return
    g_lvColsEditorSel := row
    if (A_GuiEvent = "I" && InStr(ErrorLevel, "C")) {
        key := g_lvColsEditorOrder[row]
        isChecked := Cockpit_ColsLvRowChecked(row)
        if (!isChecked && Cockpit_ColsCheckedCount() <= 1) {
            LV_Modify(row, "Check")
            return
        }
        g_lvColsEditorVisible[key] := isChecked ? true : false
    }
return

Cockpit_ColsMoveUp:
    global g_lvColsEditorSel, g_lvColsEditorOrder
    if (g_lvColsEditorSel <= 1 || g_lvColsEditorOrder.Length() < 2)
        return
    i := g_lvColsEditorSel
    tmp := g_lvColsEditorOrder[i - 1]
    g_lvColsEditorOrder[i - 1] := g_lvColsEditorOrder[i]
    g_lvColsEditorOrder[i] := tmp
    g_lvColsEditorSel := i - 1
    Cockpit_ColsEditorRefreshList()
return

Cockpit_ColsMoveDown:
    global g_lvColsEditorSel, g_lvColsEditorOrder
    maxIdx := g_lvColsEditorOrder.Length()
    if (g_lvColsEditorSel <= 0 || g_lvColsEditorSel >= maxIdx)
        return
    i := g_lvColsEditorSel
    tmp := g_lvColsEditorOrder[i + 1]
    g_lvColsEditorOrder[i + 1] := g_lvColsEditorOrder[i]
    g_lvColsEditorOrder[i] := tmp
    g_lvColsEditorSel := i + 1
    Cockpit_ColsEditorRefreshList()
return

Cockpit_ColsApply:
    global g_lvColOrder, g_lvColVisible, g_lvColsEditorOrder, g_lvColsEditorVisible
        , g_lvSortKey, g_lvSortDir, g_lastLvRowSigs
    g_lvColOrder := ["id"]
    for _, key in g_lvColsEditorOrder
        g_lvColOrder.Push(key)
    g_lvColVisible := { "id": true }
    for _, key in g_lvColOrder
        if (key != "id")
            g_lvColVisible[key] := (g_lvColsEditorVisible.HasKey(key) && g_lvColsEditorVisible[key]) ? true : false
    if (Cockpit_CountVisibleColumns() <= 0)
        g_lvColVisible["id"] := true
    if (g_lvSortKey != "" && (!g_lvColVisible.HasKey(g_lvSortKey) || !g_lvColVisible[g_lvSortKey])) {
        g_lvSortKey := ""
        g_lvSortDir := 0
    }
    Cockpit_SaveColumnsPrefs()
    Cockpit_ClearColumnsWidthCache()
    g_lastLvRowSigs := []
    Cockpit_ApplyColumnsToListView(true)
    Cockpit_RefreshBody()
    botConfig.loadSettingsToConfig("ALL")
    Gui, CockpitCols:Hide
return

Cockpit_ColsResetDefaults:
    global g_lvColsEditorOrder, g_lvColsEditorVisible, g_lvAllColKeys, g_lvColsEditorSel
    g_lvColsEditorOrder := []
    g_lvColsEditorVisible := {}
    for _, key in g_lvAllColKeys {
        if (key = "id")
            continue
        g_lvColsEditorOrder.Push(key)
        g_lvColsEditorVisible[key] := true
    }
    g_lvColsEditorSel := 1
    Cockpit_ColsEditorRefreshList()
return

Cockpit_ColsCancel:
    Gui, CockpitCols:Hide
return

CockpitColsGuiClose:
CockpitColsGuiEscape:
    Gui, CockpitCols:Hide
return

Cockpit_OnCommand(wParam, lParam, msg, hwnd) {
    global EV_HWND
    ; EN_SETFOCUS (0x0100) from EventsLog edit -> move focus away
    notifyCode := (wParam >> 16) & 0xFFFF
    if (lParam = EV_HWND && notifyCode = 0x0100) {
        GuiControl, Cockpit:Focus, InstancesLv
        return 0
    }
}

Cockpit_OnSetCursor(wParam, lParam, msg, hwnd) {
    global EV_HWND
    if (wParam = EV_HWND) {
        ; Force arrow cursor over Recent Events (avoid text I-beam feel).
        hCur := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr") ; IDC_ARROW
        DllCall("SetCursor", "Ptr", hCur)
        return 1
    }
}

Cockpit_MenuCopyAccountXml:
    Cockpit_CopySelectedAccountXml()
return

Cockpit_MenuCopyAccountXmlName:
    Cockpit_CopySelectedAccountXmlName()
return

Cockpit_MenuOpenAccountXml:
    Cockpit_OpenSelectedAccountXml()
return

Cockpit_MenuCopyAccountMetadata:
    Cockpit_CopySelectedAccountMetadataFile()
return

Cockpit_MenuCopyAccountMetadataName:
    Cockpit_CopySelectedAccountMetadataName()
return

Cockpit_MenuOpenAccountMetadata:
    Cockpit_OpenSelectedAccountMetadata()
return

Cockpit_MenuOpenLog:
    Cockpit_OpenSelectedLog()
return

Cockpit_MenuOpenAccountFolder:
    Cockpit_OpenSelectedAccountFolder()
return

Cockpit_GetSelectedRowMeta() {
    global g_rowMetaByRow, g_contextRow
    Gui, Cockpit:Default
    Gui, ListView, InstancesLv
    if (g_contextRow > 0 && g_rowMetaByRow.HasKey(g_contextRow))
        return g_rowMetaByRow[g_contextRow]
    row := LV_GetNext(0, "F")
    if (!row)
        row := LV_GetNext(0)
    if (!row) {
        rowCount := LV_GetCount()
        if (rowCount > 0)
            row := 1
    }
    if (!row)
        return ""
    if (g_rowMetaByRow.HasKey(row))
        return g_rowMetaByRow[row]
    ; Fallback for placeholder/offline rows where metadata cache may be empty.
    LV_GetText(idTxt, row, 1)
    LV_GetText(accountTxt, row, 3)
    return { "instanceId": (idTxt + 0), "accountFileName": accountTxt }
}

Cockpit_GetResolvedAccountXmlPath() {
    meta := Cockpit_GetSelectedRowMeta()
    if (!IsObject(meta))
        return ""
    instanceId := meta.instanceId + 0
    accountFile := meta.accountFileName
    if (instanceId <= 0 || accountFile = "" || accountFile = "-")
        return ""
    base := getScriptBaseFolder() . "\Accounts\Saved\" . instanceId
    xmlPath := base . "\" . accountFile
    if (!FileExist(xmlPath) && SubStr(accountFile, -3) != ".xml")
        xmlPath := xmlPath . ".xml"
    return xmlPath
}

; Returns Accounts\Cards\accounts\<deviceAccount>.json path, or "" if XML / deviceAccount missing.
Cockpit_GetResolvedAccountMetadataPath() {
    xmlPath := Cockpit_GetResolvedAccountXmlPath()
    if (xmlPath = "" || !FileExist(xmlPath))
        return ""
    deviceAccount := AccountMetadata_GetDeviceAccountFromFile(xmlPath)
    if (deviceAccount = "")
        return ""
    return AccountMetadata_AccountPath(deviceAccount)
}

; Copy a file to the clipboard so it can be pasted (e.g. in Explorer). Falls back to full path as text.
Cockpit_CopyFileToClipboard(fullPath) {
    if (fullPath = "" || !FileExist(fullPath))
        return false
    psPath := StrReplace(fullPath, "'", "''")
    psCmd := "Set-Clipboard -LiteralPath '" . psPath . "'"
    q := Chr(34)
    RunWait, % "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command " . q . psCmd . q,, Hide
    if (ErrorLevel) {
        Clipboard := fullPath
        return false
    }
    return true
}

Cockpit_OpenSelectedLog() {
    meta := Cockpit_GetSelectedRowMeta()
    if (!IsObject(meta))
        return
    instanceId := meta.instanceId + 0
    logsDir := getScriptBaseFolder() . "\Logs"
    if (instanceId > 0) {
        logPath := logsDir . "\Log_" . instanceId . ".txt"
        if (FileExist(logPath)) {
            Run, % """" . logPath . """"
            return
        }
    }
    Run, % "explorer.exe """ . logsDir . """"
}

Cockpit_OpenSelectedAccountFolder() {
    meta := Cockpit_GetSelectedRowMeta()
    if (!IsObject(meta))
        return
    instanceId := meta.instanceId + 0
    if (instanceId <= 0)
        return
    folder := getScriptBaseFolder() . "\Accounts\Saved\" . instanceId
    Run, % "explorer.exe """ . folder . """"
}

Cockpit_OpenSelectedAccountXml() {
    xmlPath := Cockpit_GetResolvedAccountXmlPath()
    if (xmlPath = "")
        return
    if (FileExist(xmlPath)) {
        Run, % """" . xmlPath . """"
        return
    }
    SplitPath, xmlPath,, xmlDir
    if (xmlDir != "")
        Run, % "explorer.exe """ . xmlDir . """"
}

Cockpit_CopySelectedAccountXml() {
    xmlPath := Cockpit_GetResolvedAccountXmlPath()
    if (xmlPath = "")
        return
    if (!FileExist(xmlPath)) {
        nf := "Account XML not found:`n" . xmlPath
        MsgBox, 48, PTCGPB Cockpit, %nf%
        return
    }
    Cockpit_CopyFileToClipboard(xmlPath)
}

Cockpit_CopySelectedAccountXmlName() {
    xmlPath := Cockpit_GetResolvedAccountXmlPath()
    if (xmlPath = "")
        return
    SplitPath, xmlPath, xmlOnlyName
    Clipboard := xmlOnlyName
}

Cockpit_CopySelectedAccountMetadataFile() {
    jsonPath := Cockpit_GetResolvedAccountMetadataPath()
    if (jsonPath = "") {
        MsgBox, 48, PTCGPB Cockpit, Could not resolve account metadata (missing XML or deviceAccount).
        return
    }
    if (!FileExist(jsonPath)) {
        nf := "Metadata file not found:`n" . jsonPath
        MsgBox, 48, PTCGPB Cockpit, %nf%
        return
    }
    Cockpit_CopyFileToClipboard(jsonPath)
}

Cockpit_CopySelectedAccountMetadataName() {
    xmlPath := Cockpit_GetResolvedAccountXmlPath()
    if (xmlPath != "" && FileExist(xmlPath)) {
        da := AccountMetadata_GetDeviceAccountFromFile(xmlPath)
        if (da != "") {
            Clipboard := da
            return
        }
    }
    jsonPath := Cockpit_GetResolvedAccountMetadataPath()
    if (jsonPath != "") {
        SplitPath, jsonPath, jsonFn
        Clipboard := RegExReplace(jsonFn, "\.json$", "")
        return
    }
    MsgBox, 48, PTCGPB Cockpit, Could not copy metadata name.
}

Cockpit_OpenSelectedAccountMetadata() {
    jsonPath := Cockpit_GetResolvedAccountMetadataPath()
    if (jsonPath = "") {
        MsgBox, 48, PTCGPB Cockpit, Could not resolve account metadata (missing XML or deviceAccount).
        return
    }
    if (!FileExist(jsonPath)) {
        nf2 := "Metadata file not found:`n" . jsonPath
        MsgBox, 48, PTCGPB Cockpit, %nf2%
        return
    }
    Run, % """" . jsonPath . """"
}

Cockpit_OpenAgeView:
    global botConfig, g_ageWindowH
    botConfig.loadSettingsToConfig("ALL")
    if (botConfig.get("deleteMethod") = "Create Bots (13P)")
        return
    Cockpit_AgeEnsureGui()
    Gui, CockpitAge:Show, Hide w680 h%g_ageWindowH%, Injection Queue
    Cockpit_AgeRefresh()
    agePos := Cockpit_LoadWindowPosition("Age")
    if (agePos.ok) {
        ax := agePos.x
        ay := agePos.y
        Gui, CockpitAge:Show, x%ax% y%ay% w680 h%g_ageWindowH%, Injection Queue
    }
    else
        Gui, CockpitAge:Show, w680 h%g_ageWindowH%, Injection Queue
    SetTimer, Cockpit_AgeAutoRefresh, Off
return

Cockpit_AgeAutoRefresh:
    Cockpit_AgeRefresh()
return

Cockpit_AgeEnsureGui() {
    global
    if (g_ageGuiBuilt)
        return

    Gui, CockpitAge:New, +HwndhAge +MinSize680x462, Injection Queue
    g_ageHwnd := hAge
    Gui, CockpitAge:Default
    Gui, Color, %THEME_BG%, %THEME_BG%
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    botConfig.loadSettingsToConfig("ALL")
    g_ageRewardsWonder := (botConfig.get("wonderpickForEventMissions") + 0) ? 1 : 0
    g_ageRewardsSpecial := (botConfig.get("claimSpecialMissions") + 0) ? 1 : 0
    g_ageRewardsGift := (botConfig.get("receiveGift") + 0) ? 1 : 0
    g_ageRewardsShine := ((botConfig.get("ocrShinedust") + 0) && (botConfig.get("s4tEnabled") + 0)) ? 1 : 0

    Gui, Font, s15 c%THEME_ACCENT% Bold, %THEME_FONT%
    Gui, Add, Text, x14 y8 w260 h28 Background%THEME_BG%, Injection Queue
    Gui, Font, s8 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, x14 y34 w410 h16 vAgeDirLbl Background%THEME_BG%,
    GuiControl, CockpitAge:Hide, AgeDirLbl
    Gui, Font, s8 c%THEME_TEXT%, %THEME_FONT%
    if (g_ageEvalMode != "Inject Packs" && g_ageEvalMode != "Inject Rewards")
        g_ageEvalMode := "Inject Packs"
    Gui, Add, DropDownList, x428 y10 w126 vAgeEvalMode gCockpit_AgeEvalChanged, Inject Packs|Inject Rewards
    GuiControl, CockpitAge:ChooseString, AgeEvalMode, %g_ageEvalMode%
    Gui, Font, s8 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Button, x560 y10 w100 h22 gCockpit_AgeRefreshClick, Refresh now
    Gui, Font, s7 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Checkbox, x428 y36 w56 h16 vAgeRwWonder gCockpit_AgeEvalChanged, Wonder
    Gui, Add, Checkbox, x486 y36 w50 h16 vAgeRwSpecial gCockpit_AgeEvalChanged, Special
    Gui, Add, Checkbox, x538 y36 w40 h16 vAgeRwGift gCockpit_AgeEvalChanged, Gift
    Gui, Add, Checkbox, x580 y36 w74 h16 vAgeRwShine gCockpit_AgeEvalChanged, Shinedust
    GuiControl, CockpitAge:, AgeRwWonder, %g_ageRewardsWonder%
    GuiControl, CockpitAge:, AgeRwSpecial, %g_ageRewardsSpecial%
    GuiControl, CockpitAge:, AgeRwGift, %g_ageRewardsGift%
    GuiControl, CockpitAge:, AgeRwShine, %g_ageRewardsShine%

    Gui, Add, Progress, x10 y56 w654 h1 c2A3136 Background2A3136 Disabled, 100

    Gui, Font, s8 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, x10  y64 w218 h16 Center Background%THEME_BG%, Total
    Gui, Add, Text, x228 y64 w218 h16 Center Background%THEME_BG%, Injectable
    Gui, Add, Text, x446 y64 w218 h16 Center Background%THEME_BG%, Cooling

    Gui, Font, s15 c%THEME_TEXT% Bold, %THEME_FONT%
    Gui, Add, Text, x10  y82 w218 h26 Center vAgeCntTotal Background%THEME_BG%, 0
    Gui, Font, s15 c%THEME_SUCCESS% Bold, %THEME_FONT%
    Gui, Add, Text, x228 y82 w218 h26 Center vAgeCntReady Background%THEME_BG%, 0
    Gui, Font, s15 c%THEME_WARN% Bold, %THEME_FONT%
    Gui, Add, Text, x446 y82 w218 h26 Center vAgeCntWait Background%THEME_BG%, 0

    Gui, Add, Progress, x10 y116 w654 h1 c2A3136 Background2A3136 Disabled, 100

    Gui, Font, s9 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, x14 y124 w220 h16 Background%THEME_BG%, Instance summary
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, ListView, x10 y142 w654 h104 vAgeInstLv gCockpit_OnAgeInstLv hwndhAgeInstLv -Multi -ReadOnly Grid -0x100000 -0x200000 +0x2000 -0x200, Instance|Total|Injectable|Cooling
    AGE_INST_HWND := hAgeInstLv
    LV_ModifyCol(1, "160 Center")
    LV_ModifyCol(2, "160 Center")
    LV_ModifyCol(3, "160 Center")
    Cockpit_FillLastColumn(hAgeInstLv, 4)
    LV_ModifyCol(4, "Center")
    Cockpit_StyleListView(hAgeInstLv)
    Cockpit_DisableColumnResize(hAgeInstLv)
    Cockpit_ForceNoHScroll(hAgeInstLv)

    Gui, Add, Progress, x10 y252 w654 h1 vAgeSepAccounts c2A3136 Background2A3136 Disabled, 100
    Gui, Font, s9 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, x14 y260 w80 h16 vAgeLblAccounts Background%THEME_BG%, Accounts
    Gui, Font, s8 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, Edit, x120 y258 w188 h20 vAgeFilterText gCockpit_AgeFilterChanged
    Gui, Add, DropDownList, x324 y258 w118 vAgeFilterStatus gCockpit_AgeFilterChanged, All|Injectable|Cooling
    Gui, Add, DropDownList, x458 y258 w90 vAgeFilterInst gCockpit_AgeFilterChanged, All
    GuiControl, CockpitAge:ChooseString, AgeFilterStatus, All
    GuiControl, CockpitAge:ChooseString, AgeFilterInst, All
    Gui, Font, s9 c%THEME_TEXT%, %THEME_FONT%
    Gui, Add, ListView, x10 y286 w654 h214 vAgeAcctLv gCockpit_OnAgeAcctLv hwndhAgeAcctLv -Multi -ReadOnly Grid -0x100000 -0x200, XML|Instance|Last Login|Ready In|Status
    AGE_ACCT_HWND := hAgeAcctLv
    LV_ModifyCol(1, "250 Center")
    LV_ModifyCol(2, "64 Center")
    LV_ModifyCol(3, "116 Center")
    LV_ModifyCol(4, "132 Center")
    Cockpit_FillLastColumn(hAgeAcctLv, 5)
    LV_ModifyCol(5, "Center")
    Cockpit_StyleListView(hAgeAcctLv)
    Cockpit_DisableColumnResize(hAgeAcctLv)

    Gui, Font, s8 c%THEME_MUTED%, %THEME_FONT%
    Gui, Add, Text, x10 y504 w654 h16 Center vAgeStatusLbl Background%THEME_BG%, Ready

    g_ageGuiBuilt := 1
}

Cockpit_AgeRefreshClick:
    Cockpit_AgeRefresh()
return

Cockpit_AgeApplyDynamicLayout(instancesConfigured) {
    global AGE_INST_HWND, g_ageWindowH, g_ageHwnd
    if (instancesConfigured < 1)
        instancesConfigured := 1

    instY := 142
    Gui, CockpitAge:Default
    Gui, ListView, AgeInstLv
    instH := Cockpit_MeasureLvHeight(AGE_INST_HWND, instancesConfigured)
    minInstH := Cockpit_MeasureLvHeight(AGE_INST_HWND, 1)
    if (instH < minInstH)
        instH := minInstH

    sepY := instY + instH + 6
    labelY := sepY + 8
    filterY := sepY + 6
    acctY := filterY + 28
    acctH := 214
    statusY := acctY + acctH + 4
    winH := statusY + 22
    if (winH < 462)
        winH := 462
    g_ageWindowH := winH

    GuiControl, CockpitAge:Move, AgeInstLv, % "y" . instY . " h" . instH
    GuiControl, CockpitAge:Move, AgeSepAccounts, % "y" . sepY
    GuiControl, CockpitAge:Move, AgeLblAccounts, % "y" . labelY
    GuiControl, CockpitAge:Move, AgeFilterText, % "y" . filterY
    GuiControl, CockpitAge:Move, AgeFilterStatus, % "y" . filterY
    GuiControl, CockpitAge:Move, AgeFilterInst, % "y" . filterY
    GuiControl, CockpitAge:Move, AgeAcctLv, % "y" . acctY . " h" . acctH
    GuiControl, CockpitAge:Move, AgeStatusLbl, % "y" . statusY

    Gui, CockpitAge:+MinSize680x%winH%
    if (g_ageHwnd && DllCall("IsWindowVisible", "Ptr", g_ageHwnd))
        Gui, CockpitAge:Show, NA w680 h%winH%
}

Cockpit_AgeRefresh() {
    global g_ageGuiBuilt, botConfig, g_ageInstRowsCache, g_ageAcctRowsCache
    if (!g_ageGuiBuilt)
        return

    botConfig.loadSettingsToConfig("ALL")
    method := Cockpit_AgeResolveEvalMethod()
    Cockpit_AgeUpdateRewardsOptionsVisibility(method)
    dir := getScriptBaseFolder() . "\Accounts\Cards\accounts"
    if (!FileExist(dir)) {
        Cockpit_AgeApplyDynamicLayout(1)
        GuiControl, CockpitAge:, AgeStatusLbl, Account metadata folder not found.
        return
    }
    if (method = "Create Bots (13P)") {
        Cockpit_AgeApplyDynamicLayout(1)
        GuiControl, CockpitAge:, AgeStatusLbl, Not applicable in Create Bots mode.
        GuiControl, CockpitAge:, AgeCntTotal, 0
        GuiControl, CockpitAge:, AgeCntReady, 0
        GuiControl, CockpitAge:, AgeCntWait, 0
        Gui, CockpitAge:Default
        Gui, ListView, AgeInstLv
        LV_Delete()
        Gui, ListView, AgeAcctLv
        LV_Delete()
        g_ageInstRowsCache := []
        g_ageAcctRowsCache := []
        return
    }

    gTotal := 0
    gReady := 0
    gWait := 0
    instAgg := {}
    acctRows := []
    instSeen := {}
    rewardsOpts := Cockpit_AgeGetRewardsOptions()

    Loop, Files, %dir%\*.json
    {
        filePath := A_LoopFileFullPath
        fileName := A_LoopFileName
        accountName := SubStr(fileName, 1, StrLen(fileName) - 5)

        FileRead, content, %filePath%
        if (ErrorLevel)
            continue

        inst := "?"
        if (RegExMatch(content, "s)""instance""\s*:\s*""?([^"",\s}]+)", mInst))
            inst := mInst1
        instNorm := Cockpit_ToLower(Trim(inst))
        ; Injection Queue must never display Main pseudo-instance rows.
        if (instNorm = "m" || instNorm = "main" || instNorm = "0")
            continue
        metaFileName := ""
        if (RegExMatch(content, "s)""fileName""\s*:\s*""([^""]+)""", mFile))
            metaFileName := mFile1

        lastLogin := "0"
        if (RegExMatch(content, "s)""lastLoggedIn""\s*:\s*""?([0-9]{14})", mLog))
            lastLogin := mLog1
        hasLogin := (lastLogin != "" && lastLogin != "0")

        loginDisp := "--"
        status := "Cooling"
        if (hasLogin) {
            loginDisp := SubStr(lastLogin,1,4) . "-" . SubStr(lastLogin,5,2) . "-" . SubStr(lastLogin,7,2)
                . " " . SubStr(lastLogin,9,2) . ":" . SubStr(lastLogin,11,2)
        }
        baseEligible := Cockpit_AgeEligibleForMethod(method, content, lastLogin, rewardsOpts)
        gateValue := Cockpit_AgeDriverTimeForMethod(method, content, lastLogin, hasLogin, rewardsOpts)
        gateValue := Cockpit_AgeNormalizeGateDisplay(gateValue)
        if (baseEligible) {
            status := "Injectable"
            gateValue := "Ready"
            gReady++
        } else {
            status := "Cooling"
            gWait++
        }
        gTotal++

        if (!instAgg.HasKey(inst))
            instAgg[inst] := {"t":0, "r":0, "w":0}
        instAgg[inst]["t"]++
        if (status = "Injectable")
            instAgg[inst]["r"]++
        else
            instAgg[inst]["w"]++

        displayName := (metaFileName != "" && metaFileName != "-") ? metaFileName : accountName
        instanceIdNum := inst + 0
        acctRows.Push({"account": displayName, "inst": inst, "instanceId": instanceIdNum, "login": loginDisp, "gate": gateValue, "status": status, "jsonPath": filePath})
        if (!instSeen.HasKey(inst))
            instSeen[inst] := 1
    }

    FormatTime, upd,, HH:mm:ss
    GuiControl, CockpitAge:, AgeCntTotal, %gTotal%
    GuiControl, CockpitAge:, AgeCntReady, %gReady%
    GuiControl, CockpitAge:, AgeCntWait,  %gWait%

    instChoices := "|All"
    for instKey, _ in instSeen
        instChoices .= "|" . instKey
    GuiControl, CockpitAge:, AgeFilterInst, %instChoices%
    GuiControl, CockpitAge:ChooseString, AgeFilterInst, %g_ageFilterInst%
    if (ErrorLevel) {
        g_ageFilterInst := "All"
        GuiControl, CockpitAge:ChooseString, AgeFilterInst, All
    }

    instRows := []
    for instKey, agg in instAgg
        instRows.Push({"inst": instKey, "t": agg["t"], "r": agg["r"], "w": agg["w"]})
    Cockpit_AgeSortInstRows(instRows)
    visibleInstRows := instRows.Length()
    if (visibleInstRows < 1)
        visibleInstRows := 1
    Cockpit_AgeApplyDynamicLayout(visibleInstRows)

    filteredRows := []
    Loop, % acctRows.Length() {
        row := acctRows[A_Index]
        if (Cockpit_AgeRowMatchesFilters(row))
            filteredRows.Push(row)
    }
    Cockpit_AgeSortAcctRows(filteredRows)

    g_ageInstRowsCache := instRows
    g_ageAcctRowsCache := filteredRows
    Cockpit_AgeRenderInstRows(instRows)
    Cockpit_AgeRenderAcctRows(filteredRows)

    GuiControl, CockpitAge:, AgeStatusLbl, % "Mode: " . method . " | Updated: " . upd . " | Total: " . gTotal . " | Injectable: " . gReady . " | Cooling: " . gWait
}

Cockpit_AgeEligibleForMethod(method, jsonText, lastLoggedIn, rewardsOpts) {
    if (method = "Create Bots (13P)")
        return false

    if (method = "Inject Rewards") {
        doWonderpick := rewardsOpts.doWonderpick ? true : false
        doSpecial := rewardsOpts.doSpecial ? true : false
        doGift := rewardsOpts.doGift ? true : false
        doShine := rewardsOpts.doShine ? true : false

        if (!doWonderpick && !doSpecial && !doGift && !doShine)
            return !Cockpit_AgeWasAfterDailyReset(lastLoggedIn)

        if (doWonderpick && Cockpit_AgeFlagExpired(jsonText, "W", 24))
            return true
        if (doSpecial && !Cockpit_AgeFlagSet(jsonText, "X"))
            return true
        if (doGift && !Cockpit_AgeFlagSet(jsonText, "R"))
            return true
        if (doShine && Cockpit_AgeHoursSince(Cockpit_AgeShinedustLastUpdated(jsonText)) >= 24)
            return true
        return false
    }

    if (method = "Inject Packs") {
        if (Cockpit_AgeFlagSet(jsonText, "T") && !Cockpit_AgeFlagExpired(jsonText, "T", 5 * 24))
            return false
        lastPackPulled := Cockpit_AgeFieldTimestamp(jsonText, "lastPackPulled")
        if (lastPackPulled = "" || lastPackPulled = "0")
            return true
        return Cockpit_AgeHoursSince(lastPackPulled) >= 24
    }

    return true
}

Cockpit_AgeFieldTimestamp(jsonText, field) {
    p := "s)""" . field . """\s*:\s*""?([0-9]{14}|0)"
    if (RegExMatch(jsonText, p, m))
        return m1
    return "0"
}

Cockpit_AgeFlagBody(jsonText, flag) {
    p := "s)""" . flag . """\s*:\s*\{([^}]*)\}"
    if (RegExMatch(jsonText, p, m))
        return m1
    return ""
}

Cockpit_AgeFlagSet(jsonText, flag) {
    body := Cockpit_AgeFlagBody(jsonText, flag)
    if (body = "")
        return false
    if (RegExMatch(body, "s)""value""\s*:\s*(true|1)", mv))
        return true
    return false
}

Cockpit_AgeFlagSetAt(jsonText, flag) {
    body := Cockpit_AgeFlagBody(jsonText, flag)
    if (body = "")
        return ""
    if (RegExMatch(body, "s)""setAt""\s*:\s*""([0-9]{14})", ms))
        return ms1
    return ""
}

Cockpit_AgeFlagValidUntil(jsonText, flag) {
    body := Cockpit_AgeFlagBody(jsonText, flag)
    if (body = "")
        return ""
    if (RegExMatch(body, "s)""validUntil""\s*:\s*""([0-9]{14})", mv))
        return mv1
    return ""
}

Cockpit_AgeFlagExpired(jsonText, flag, hoursValid) {
    if (!Cockpit_AgeFlagSet(jsonText, flag))
        return true
    validUntil := Cockpit_AgeFlagValidUntil(jsonText, flag)
    if (validUntil != "")
        return (A_Now >= validUntil)
    setAt := Cockpit_AgeFlagSetAt(jsonText, flag)
    if (setAt = "")
        return false
    return Cockpit_AgeHoursSince(setAt) >= hoursValid
}

Cockpit_AgeHoursSince(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return 999999
    diff := A_Now
    EnvSub, diff, %timestamp%, Hours
    return diff
}

Cockpit_AgeToUTC(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return "0"
    offsetSeconds := A_NowUTC
    nowLocal := A_Now
    EnvSub, offsetSeconds, %nowLocal%, Seconds
    utcTimestamp := timestamp
    utcTimestamp += %offsetSeconds%, Seconds
    return utcTimestamp
}

Cockpit_AgeCurrentDailyResetUTC() {
    nowUTC := A_NowUTC
    resetUTC := SubStr(nowUTC, 1, 8) . "060000"
    if (nowUTC < resetUTC)
        resetUTC += -1, Days
    return resetUTC
}

Cockpit_AgeWasAfterDailyReset(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return false
    return Cockpit_AgeToUTC(timestamp) >= Cockpit_AgeCurrentDailyResetUTC()
}

Cockpit_AgeShinedustLastUpdated(jsonText) {
    if (RegExMatch(jsonText, "s)""shinedust""\s*:\s*\{([^}]*)\}", m)) {
        body := m1
        if (RegExMatch(body, "s)""lastUpdatedAt""\s*:\s*""([0-9]{14})", ms))
            return ms1
    }
    return "0"
}

Cockpit_UpdateAgeButtonVisibility(mode := "") {
    global botConfig
    if (mode = "")
        mode := botConfig.get("deleteMethod")
    if (mode = "Create Bots (13P)")
        GuiControl, Cockpit:Hide, btnAgeView
    else
        GuiControl, Cockpit:Show, btnAgeView
}

Cockpit_AgeResolveEvalMethod() {
    global g_ageEvalMode
    sel := Trim(g_ageEvalMode)
    if (sel = "Inject Rewards")
        return "Inject Rewards"
    return "Inject Packs"
}

Cockpit_AgeGetRewardsOptions() {
    global g_ageRewardsWonder, g_ageRewardsSpecial, g_ageRewardsGift, g_ageRewardsShine
    return { "doWonderpick": (g_ageRewardsWonder + 0) ? true : false
        , "doSpecial": (g_ageRewardsSpecial + 0) ? true : false
        , "doGift": (g_ageRewardsGift + 0) ? true : false
        , "doShine": (g_ageRewardsShine + 0) ? true : false }
}

Cockpit_AgeUpdateRewardsOptionsVisibility(method) {
    show := (method = "Inject Rewards")
    action := show ? "Show" : "Hide"
    GuiControl, CockpitAge:%action%, AgeRwWonder
    GuiControl, CockpitAge:%action%, AgeRwSpecial
    GuiControl, CockpitAge:%action%, AgeRwGift
    GuiControl, CockpitAge:%action%, AgeRwShine
}

Cockpit_AgeRowMatchesFilters(row) {
    global g_ageFilterText, g_ageFilterStatus, g_ageFilterInst
    if (g_ageFilterStatus != "" && g_ageFilterStatus != "All" && row.status != g_ageFilterStatus)
        return false
    if (g_ageFilterInst != "" && g_ageFilterInst != "All" && row.inst != g_ageFilterInst)
        return false
    q := Cockpit_ToLower(Trim(g_ageFilterText))
    if (q = "")
        return true
    blob := Cockpit_ToLower(row.account . " " . row.inst . " " . row.login . " " . row.gate . " " . row.status)
    return InStr(blob, q) ? true : false
}

Cockpit_AgeDriverTimeForMethod(method, jsonText, lastLoggedIn, hasLogin, rewardsOpts) {
    if (method = "Inject Rewards") {
        doWonderpick := rewardsOpts.doWonderpick ? true : false
        doSpecial := rewardsOpts.doSpecial ? true : false
        doGift := rewardsOpts.doGift ? true : false
        doShine := rewardsOpts.doShine ? true : false

        candidates := []
        if (doWonderpick && Cockpit_AgeFlagSet(jsonText, "W"))
            candidates.Push(Cockpit_AgeFlagSetAt(jsonText, "W"))
        if (doSpecial && Cockpit_AgeFlagSet(jsonText, "X"))
            candidates.Push(Cockpit_AgeFlagSetAt(jsonText, "X"))
        if (doGift && Cockpit_AgeFlagSet(jsonText, "R"))
            candidates.Push(Cockpit_AgeFlagSetAt(jsonText, "R"))
        if (doShine)
            candidates.Push(Cockpit_AgeShinedustLastUpdated(jsonText))

        if (!doWonderpick && !doSpecial && !doGift && !doShine)
            return Cockpit_AgeRemainingToDailyReset(lastLoggedIn)

        maxRemaining := 0
        Loop, % candidates.Length() {
            ts := candidates[A_Index]
            if (ts = "" || ts = "0")
                continue
            remaining := Cockpit_AgeRemainingSecondsFromTimestamp(ts, 24)
            if (remaining > maxRemaining)
                maxRemaining := remaining
        }
        return Metrics_FormatDurationHMSecs(maxRemaining)
    }

    if (method = "Inject Packs") {
        return Cockpit_AgeRemainingFromTimestamp(Cockpit_AgeFieldTimestamp(jsonText, "lastPackPulled"), 24)
    }

    if (!hasLogin)
        return "--"
    return Cockpit_AgeRemainingToDailyReset(lastLoggedIn)
}

Cockpit_AgeDurationFromTimestamp(timestamp) {
    if (timestamp = "" || timestamp = "0")
        return "--"
    sec := A_Now
    EnvSub, sec, %timestamp%, Seconds
    if (sec < 0)
        sec := 0
    return Metrics_FormatDurationHMSecs(sec)
}

Cockpit_AgeRemainingSecondsFromTimestamp(timestamp, requiredHours) {
    if (timestamp = "" || timestamp = "0")
        return 0
    elapsed := A_Now
    EnvSub, elapsed, %timestamp%, Seconds
    if (elapsed < 0)
        elapsed := 0
    remaining := (requiredHours * 3600) - elapsed
    if (remaining < 0)
        remaining := 0
    return remaining
}

Cockpit_AgeRemainingFromTimestamp(timestamp, requiredHours) {
    if (timestamp = "" || timestamp = "0")
        return "--"
    return Metrics_FormatDurationHMSecs(Cockpit_AgeRemainingSecondsFromTimestamp(timestamp, requiredHours))
}

Cockpit_AgeRemainingToDailyReset(lastLoggedIn) {
    if (lastLoggedIn = "" || lastLoggedIn = "0")
        return "--"
    if (!Cockpit_AgeWasAfterDailyReset(lastLoggedIn))
        return Metrics_FormatDurationHMSecs(0)

    nowUTC := A_NowUTC
    nextResetUTC := SubStr(nowUTC, 1, 8) . "060000"
    if (nowUTC >= nextResetUTC)
        nextResetUTC += 1, Days

    remaining := nextResetUTC
    EnvSub, remaining, %nowUTC%, Seconds
    if (remaining < 0)
        remaining := 0
    return Metrics_FormatDurationHMSecs(remaining)
}

Cockpit_AgeEvalChanged:
    global AgeEvalMode, AgeRwWonder, AgeRwSpecial, AgeRwGift, AgeRwShine
        , g_ageEvalMode, g_ageRewardsWonder, g_ageRewardsSpecial, g_ageRewardsGift, g_ageRewardsShine
    Gui, CockpitAge:Submit, NoHide
    g_ageEvalMode := AgeEvalMode
    g_ageRewardsWonder := (AgeRwWonder + 0) ? 1 : 0
    g_ageRewardsSpecial := (AgeRwSpecial + 0) ? 1 : 0
    g_ageRewardsGift := (AgeRwGift + 0) ? 1 : 0
    g_ageRewardsShine := (AgeRwShine + 0) ? 1 : 0
    Cockpit_AgeRefresh()
return

Cockpit_AgeFilterChanged:
    global AgeFilterText, AgeFilterStatus, AgeFilterInst
        , g_ageFilterText, g_ageFilterStatus, g_ageFilterInst
    Gui, CockpitAge:Submit, NoHide
    g_ageFilterText := AgeFilterText
    g_ageFilterStatus := AgeFilterStatus
    g_ageFilterInst := AgeFilterInst
    Cockpit_AgeRefresh()
return

Cockpit_OnAgeInstLv:
    global g_ageInstSortCol, g_ageInstSortDir
    if (A_GuiEvent != "ColClick")
        return
    col := A_EventInfo + 0
    if (col <= 0)
        return
    if (g_ageInstSortCol != col) {
        g_ageInstSortCol := col
        g_ageInstSortDir := 1
    } else {
        g_ageInstSortDir := (g_ageInstSortDir = 1) ? -1 : 1
    }
    Cockpit_AgeApplyInstSort()
return

Cockpit_OnAgeAcctLv:
    global g_ageAcctSortCol, g_ageAcctSortDir
    if (A_GuiEvent != "ColClick")
        return
    col := A_EventInfo + 0
    if (col <= 0)
        return
    if (g_ageAcctSortCol != col) {
        g_ageAcctSortCol := col
        g_ageAcctSortDir := 1
    } else {
        g_ageAcctSortDir := (g_ageAcctSortDir = 1) ? -1 : 1
    }
    Cockpit_AgeApplyAcctSort()
return

Cockpit_AgeApplyInstSort() {
    Cockpit_AgeResortInstList()
}

Cockpit_AgeApplyAcctSort() {
    Cockpit_AgeResortAcctList()
}

Cockpit_AgeResortInstList() {
    global g_ageInstRowsCache
    rows := []
    if (!IsObject(g_ageInstRowsCache) || g_ageInstRowsCache.Length() <= 1)
        return
    Loop, % g_ageInstRowsCache.Length()
        rows.Push(g_ageInstRowsCache[A_Index])
    Cockpit_AgeSortInstRows(rows)
    g_ageInstRowsCache := rows
    Cockpit_AgeWriteInstRowsInPlace(rows)
}

Cockpit_AgeResortAcctList() {
    global g_ageAcctRowsCache
    rows := []
    if (!IsObject(g_ageAcctRowsCache) || g_ageAcctRowsCache.Length() <= 1)
        return
    Loop, % g_ageAcctRowsCache.Length()
        rows.Push(g_ageAcctRowsCache[A_Index])
    Cockpit_AgeSortAcctRows(rows)
    g_ageAcctRowsCache := rows
    Cockpit_AgeWriteAcctRowsInPlace(rows)
}

Cockpit_AgeWriteInstRowsInPlace(ByRef rows) {
    Gui, CockpitAge:Default
    Gui, ListView, AgeInstLv
    rc := LV_GetCount()
    if (rc != rows.Length()) {
        Cockpit_AgeRenderInstRows(rows)
        return
    }
    Loop, % rows.Length() {
        row := rows[A_Index]
        LV_Modify(A_Index, "", row.inst)
        LV_Modify(A_Index, "Col2", row.t)
        LV_Modify(A_Index, "Col3", row.r)
        LV_Modify(A_Index, "Col4", row.w)
    }
}

Cockpit_AgeWriteAcctRowsInPlace(ByRef rows) {
    Gui, CockpitAge:Default
    Gui, ListView, AgeAcctLv
    rc := LV_GetCount()
    if (rc != rows.Length()) {
        Cockpit_AgeRenderAcctRows(rows)
        return
    }
    Loop, % rows.Length() {
        row := rows[A_Index]
        LV_Modify(A_Index, "", row.account)
        LV_Modify(A_Index, "Col2", row.inst)
        LV_Modify(A_Index, "Col3", row.login)
        LV_Modify(A_Index, "Col4", row.gate)
        LV_Modify(A_Index, "Col5", row.status)
    }
}

Cockpit_AgeRenderInstRows(ByRef rows) {
    global AGE_INST_HWND
    Gui, CockpitAge:Default
    Gui, ListView, AgeInstLv
    GuiControl, CockpitAge:-Redraw, AgeInstLv
    LV_Delete()
    Loop, % rows.Length() {
        row := rows[A_Index]
        LV_Add("", row.inst, row.t, row.r, row.w)
    }
    LV_ModifyCol(1, "Center")
    LV_ModifyCol(2, "Center")
    LV_ModifyCol(3, "Center")
    LV_ModifyCol(4, "Center")
    GuiControl, CockpitAge:+Redraw, AgeInstLv
}

Cockpit_AgeRenderAcctRows(ByRef rows) {
    global AGE_ACCT_HWND
    Gui, CockpitAge:Default
    Gui, ListView, AgeAcctLv
    GuiControl, CockpitAge:-Redraw, AgeAcctLv
    LV_Delete()
    Loop, % rows.Length() {
        row := rows[A_Index]
        LV_Add("", row.account, row.inst, row.login, row.gate, row.status)
    }
    Cockpit_FillLastColumn(AGE_ACCT_HWND, 5)
    LV_ModifyCol(1, "Center")
    LV_ModifyCol(2, "Center")
    LV_ModifyCol(3, "Center")
    LV_ModifyCol(4, "Center")
    LV_ModifyCol(5, "Center")
    GuiControl, CockpitAge:+Redraw, AgeAcctLv
}

Cockpit_AgeSortInstRows(ByRef rows) {
    global g_ageInstSortCol, g_ageInstSortDir
    if (!IsObject(rows) || rows.Length() <= 1 || g_ageInstSortCol <= 0)
        return
    sep := Chr(30)
    raw := ""
    Loop, % rows.Length() {
        row := rows[A_Index]
        key := Cockpit_AgeInstSortKey(row, g_ageInstSortCol)
        raw .= key . sep . A_Index . "`n"
    }
    opts := "D`n"
    if (g_ageInstSortDir < 0)
        opts .= " R"
    Sort, raw, %opts%
    sorted := []
    Loop, Parse, raw, `n, `r
    {
        line := A_LoopField
        if (line = "")
            continue
        p := InStr(line, sep)
        if (!p)
            continue
        idx := SubStr(line, p + 1) + 0
        if (idx >= 1 && idx <= rows.Length())
            sorted.Push(rows[idx])
    }
    rows := sorted
}

Cockpit_AgeSortAcctRows(ByRef rows) {
    global g_ageAcctSortCol, g_ageAcctSortDir
    if (!IsObject(rows) || rows.Length() <= 1 || g_ageAcctSortCol <= 0)
        return
    if (g_ageAcctSortCol = 4) {
        cooling := []
        ready := []
        Loop, % rows.Length() {
            r := rows[A_Index]
            if (Trim(r.gate) = "Ready")
                ready.Push(r)
            else
                cooling.Push(r)
        }
        if (cooling.Length() > 1) {
            sep := Chr(30)
            raw := ""
            Loop, % cooling.Length() {
                row := cooling[A_Index]
                key := Cockpit_AgeAcctSortKey(row, 4)
                raw .= key . sep . A_Index . "`n"
            }
            opts := "D`n"
            if (g_ageAcctSortDir < 0)
                opts .= " R"
            Sort, raw, %opts%
            sortedCool := []
            Loop, Parse, raw, `n, `r
            {
                line := A_LoopField
                if (line = "")
                    continue
                p := InStr(line, sep)
                if (!p)
                    continue
                idx := SubStr(line, p + 1) + 0
                if (idx >= 1 && idx <= cooling.Length())
                    sortedCool.Push(cooling[idx])
            }
            cooling := sortedCool
        }
        rows := []
        Loop, % cooling.Length()
            rows.Push(cooling[A_Index])
        Loop, % ready.Length()
            rows.Push(ready[A_Index])
        return
    }
    sep := Chr(30)
    raw := ""
    Loop, % rows.Length() {
        row := rows[A_Index]
        key := Cockpit_AgeAcctSortKey(row, g_ageAcctSortCol)
        raw .= key . sep . A_Index . "`n"
    }
    opts := "D`n"
    if (g_ageAcctSortDir < 0)
        opts .= " R"
    Sort, raw, %opts%
    sorted := []
    Loop, Parse, raw, `n, `r
    {
        line := A_LoopField
        if (line = "")
            continue
        p := InStr(line, sep)
        if (!p)
            continue
        idx := SubStr(line, p + 1) + 0
        if (idx >= 1 && idx <= rows.Length())
            sorted.Push(rows[idx])
    }
    rows := sorted
}

Cockpit_AgeInstSortKey(row, col) {
    if (col = 1) {
        if (row.inst is number)
            return "0" . Cockpit_AgePadInt(row.inst + 0, 8)
        return "1" . Cockpit_ToLower(row.inst)
    }
    if (col = 2)
        return Cockpit_AgePadInt(row.t + 0, 10)
    if (col = 3)
        return Cockpit_AgePadInt(row.r + 0, 10)
    if (col = 4)
        return Cockpit_AgePadInt(row.w + 0, 10)
    return ""
}

Cockpit_AgeAcctSortKey(row, col) {
    if (col = 1)
        return Cockpit_ToLower(row.account)

    if (col = 2) {
        if (row.inst is number)
            return "0" . Cockpit_AgePadInt(row.inst + 0, 8)
        return "1" . Cockpit_ToLower(row.inst)
    }

    if (col = 3) {
        if (row.login = "--")
            return "00000000000000"
        return RegExReplace(row.login, "[^\d]")
    }

    if (col = 4)
        return Cockpit_AgePadInt(Cockpit_AgeDurationTextToSeconds(row.gate), 10)

    if (col = 5)
        return Cockpit_AgePadInt(Cockpit_AgeStatusRank(row.status), 3) . Cockpit_ToLower(row.account)

    return ""
}

Cockpit_AgeDurationTextToSeconds(txt) {
    if (txt = "" || txt = "--" || Cockpit_ToLower(txt) = "ready")
        return 999999999
    t := Trim(txt)
    if (RegExMatch(t, "i)^\s*(\d+)\s*d\s+(\d+)\s*h\s+(\d+)\s*m\s+(\d+)\s*s\s*$", dms))
        return dms1 * 86400 + dms2 * 3600 + dms3 * 60 + dms4
    if (RegExMatch(t, "i)^\s*(\d+)\s*h\s+(\d+)\s*m\s+(\d+)\s*s\s*$", hmss))
        return hmss1 * 3600 + hmss2 * 60 + hmss3
    ; legacy formats (partial refresh / old strings)
    h := 0
    m := 0
    s := 0
    if (RegExMatch(t, "i)^\s*(\d+)\s*h\s+(\d+)\s*m\s*$", hmOnly)) {
        h := hmOnly1 + 0
        m := hmOnly2 + 0
        return (h * 3600) + (m * 60)
    }
    if (RegExMatch(t, "i)^\s*(\d+)\s*m\s*$", mOnly))
        return (mOnly1 + 0) * 60
    if (RegExMatch(t, "i)(\d+)\s*h", mh))
        h := mh1 + 0
    if (RegExMatch(t, "i)(\d+)\s*m", mm))
        m := mm1 + 0
    if (RegExMatch(t, "i)(\d+)\s*s", ms))
        s := ms1 + 0
    return (h * 3600) + (m * 60) + s
}

Cockpit_AgeNormalizeGateDisplay(txt) {
    t := Trim(txt)
    if (t = "")
        return "--"
    if (t = "--")
        return "--"
    if (RegExMatch(t, "i)^\s*(\d+)\s*d\s+(\d+)\s*h\s+(\d+)\s*m\s+(\d+)\s*s\s*$", dHm)) {
        return Format("{:02}", dHm1 + 0) . "d " . Format("{:02}", dHm2 + 0) . "h " . Format("{:02}", dHm3 + 0) . "m " . Format("{:02}", dHm4 + 0) . "s"
    }
    if (RegExMatch(t, "i)^\s*(\d+)\s*h\s+(\d+)\s*m\s+(\d+)\s*s\s*$", hMs)) {
        return Format("{:02}", hMs1 + 0) . "h " . Format("{:02}", hMs2 + 0) . "m " . Format("{:02}", hMs3 + 0) . "s"
    }
    if (RegExMatch(t, "i)^\s*(\d+)\s*h\s*(\d+)\s*m\s*$", mHm)) {
        return Format("{:02}", mHm1 + 0) . "h " . Format("{:02}", mHm2 + 0) . "m " . Format("{:02}", 0) . "s"
    }
    if (RegExMatch(t, "i)^\s*(\d+)\s*m\s*$", mOnlyN)) {
        return Format("{:02}", 0) . "h " . Format("{:02}", mOnlyN1 + 0) . "m " . Format("{:02}", 0) . "s"
    }
    return t
}

Cockpit_AgeStatusRank(status) {
    if (status = "Injectable")
        return 1
    if (status = "Cooling")
        return 2
    return 9
}

Cockpit_AgePadInt(n, width) {
    s := n . ""
    while (StrLen(s) < width)
        s := "0" . s
    return s
}

Cockpit_AgeMenuRowObject() {
    global g_ageAcctMenuRow, g_ageAcctRowsCache
    row := g_ageAcctMenuRow + 0
    if (row <= 0 || !IsObject(g_ageAcctRowsCache) || row > g_ageAcctRowsCache.Length())
        return ""
    return g_ageAcctRowsCache[row]
}

Cockpit_GetResolvedAgeRowXmlPath(r) {
    if (!IsObject(r))
        return ""
    instanceId := r.instanceId + 0
    accountFile := r.account
    if (instanceId <= 0 || accountFile = "" || accountFile = "-")
        return ""
    base := getScriptBaseFolder() . "\Accounts\Saved\" . instanceId
    xmlPath := base . "\" . accountFile
    if (!FileExist(xmlPath) && SubStr(accountFile, -3) != ".xml")
        xmlPath := xmlPath . ".xml"
    return xmlPath
}

; Prefer row's cards JSON path; else resolve from XML + deviceAccount.
Cockpit_GetResolvedAgeRowMetadataPath(r) {
    if (!IsObject(r))
        return ""
    if (r.HasKey("jsonPath") && r.jsonPath != "")
        return r.jsonPath
    xmlPath := Cockpit_GetResolvedAgeRowXmlPath(r)
    if (xmlPath = "" || !FileExist(xmlPath))
        return ""
    deviceAccount := AccountMetadata_GetDeviceAccountFromFile(xmlPath)
    if (deviceAccount = "")
        return ""
    return AccountMetadata_AccountPath(deviceAccount)
}

Cockpit_OpenAgeRowAccountFolder(r) {
    if (!IsObject(r))
        return
    instanceId := r.instanceId + 0
    if (instanceId <= 0)
        return
    folder := getScriptBaseFolder() . "\Accounts\Saved\" . instanceId
    Run, % "explorer.exe """ . folder . """"
}

Cockpit_OpenAgeRowAccountXml(r) {
    xmlPath := Cockpit_GetResolvedAgeRowXmlPath(r)
    if (xmlPath = "")
        return
    if (FileExist(xmlPath)) {
        Run, % """" . xmlPath . """"
        return
    }
    SplitPath, xmlPath,, xmlDir
    if (xmlDir != "")
        Run, % "explorer.exe """ . xmlDir . """"
}

Cockpit_CopyAgeRowAccountXml(r) {
    xmlPath := Cockpit_GetResolvedAgeRowXmlPath(r)
    if (xmlPath = "")
        return
    if (!FileExist(xmlPath)) {
        nf := "Account XML not found:`n" . xmlPath
        MsgBox, 48, Injection Queue, %nf%
        return
    }
    Cockpit_CopyFileToClipboard(xmlPath)
}

Cockpit_CopyAgeRowAccountXmlName(r) {
    xmlPath := Cockpit_GetResolvedAgeRowXmlPath(r)
    if (xmlPath = "")
        return
    SplitPath, xmlPath, xmlOnlyName
    Clipboard := xmlOnlyName
}

Cockpit_CopyAgeRowAccountMetadataFile(r) {
    jsonPath := Cockpit_GetResolvedAgeRowMetadataPath(r)
    if (jsonPath = "") {
        MsgBox, 48, Injection Queue, Could not resolve account metadata (missing XML or deviceAccount).
        return
    }
    if (!FileExist(jsonPath)) {
        nf := "Metadata file not found:`n" . jsonPath
        MsgBox, 48, Injection Queue, %nf%
        return
    }
    Cockpit_CopyFileToClipboard(jsonPath)
}

Cockpit_CopyAgeRowAccountMetadataName(r) {
    xmlPath := Cockpit_GetResolvedAgeRowXmlPath(r)
    if (xmlPath != "" && FileExist(xmlPath)) {
        da := AccountMetadata_GetDeviceAccountFromFile(xmlPath)
        if (da != "") {
            Clipboard := da
            return
        }
    }
    jsonPath := Cockpit_GetResolvedAgeRowMetadataPath(r)
    if (jsonPath != "") {
        SplitPath, jsonPath, jsonFn
        Clipboard := RegExReplace(jsonFn, "\.json$", "")
        return
    }
    MsgBox, 48, Injection Queue, Could not copy metadata name.
}

Cockpit_OpenAgeRowAccountMetadata(r) {
    jsonPath := Cockpit_GetResolvedAgeRowMetadataPath(r)
    if (jsonPath = "") {
        MsgBox, 48, Injection Queue, Could not resolve account metadata (missing XML or deviceAccount).
        return
    }
    if (!FileExist(jsonPath)) {
        nf := "Metadata file not found:`n" . jsonPath
        MsgBox, 48, Injection Queue, %nf%
        return
    }
    Run, % """" . jsonPath . """"
}

CockpitAgeGuiContextMenu:
    if (A_GuiControl != "AgeAcctLv")
        return
    Gui, CockpitAge:Default
    Gui, ListView, AgeAcctLv
    row := A_EventInfo + 0
    if (row <= 0)
        row := LV_GetNext(0, "F")
    if (row <= 0)
        return
    g_ageAcctMenuRow := row
    Menu, CockpitAgeAcctMenu, Show
return

Cockpit_AgeMenuOpenAccountFolder:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_OpenAgeRowAccountFolder(r)
return

Cockpit_AgeMenuOpenAccountXml:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_OpenAgeRowAccountXml(r)
return

Cockpit_AgeMenuCopyAccountXmlName:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_CopyAgeRowAccountXmlName(r)
return

Cockpit_AgeMenuCopyAccountXml:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_CopyAgeRowAccountXml(r)
return

Cockpit_AgeMenuOpenAccountMetadata:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_OpenAgeRowAccountMetadata(r)
return

Cockpit_AgeMenuCopyAccountMetadata:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_CopyAgeRowAccountMetadataFile(r)
return

Cockpit_AgeMenuCopyAccountMetadataName:
    r := Cockpit_AgeMenuRowObject()
    if (!IsObject(r))
        return
    Cockpit_CopyAgeRowAccountMetadataName(r)
return

CockpitAgeGuiClose:
CockpitAgeGuiEscape:
    global g_ageStandalone, g_ageHwnd
    SetTimer, Cockpit_AgeAutoRefresh, Off
    Cockpit_SaveWindowPosition("Age", g_ageHwnd)
    if (g_ageStandalone)
        ExitApp
    Gui, CockpitAge:Hide
return

;===============================================================================
; Window events
;===============================================================================
CockpitGuiClose:
CockpitGuiEscape:
    Gui, Cockpit:+LastFound
    Cockpit_SaveWindowPosition("Main", WinExist())
    SetTimer, Agg_Tick, Off
    SetTimer, Cockpit_RefreshTicker, Off
ExitApp

CockpitGuiSize:
    global g_cockpitHwnd
    if (A_EventInfo = 1)
        return
    if (g_cockpitHwnd) {
        WinGet, mm, MinMax, ahk_id %g_cockpitHwnd%
        if (mm = 1) {
            WinRestore, ahk_id %g_cockpitHwnd%
            return
        }
    }
    Cockpit_Relayout(A_GuiWidth, A_GuiHeight)
return

Cockpit_Relayout(w, h, forcedInstN := 0) {
    global botConfig, g_cockpitW, g_instSingleMode, g_cockpitTabTopY, COCKPIT_TAB_STRIP
        , COCKPIT_EVENTS_FILTER, COCKPIT_TAB_MARGIN_X
        , g_cockpitMinTabInner, LV_HWND, g_instLayoutLineCache

    bottomPad := 10
    if (w <= 0 || h <= 0)
        return
    g_cockpitW := w
    GuiControl, Cockpit:Move, lblModeVal, % "w" . (w - 288)
    GuiControl, Cockpit:Move, btnAgeView, % "x" . (w - 264)
    GuiControl, Cockpit:Move, btnCols, % "x" . (w - 134)

    availOuterRaw := h - g_cockpitTabTopY - bottomPad
    minOuter := g_cockpitMinTabInner + COCKPIT_TAB_STRIP
    if (availOuterRaw < minOuter)
        availOuterRaw := minOuter
    tabOuterH := availOuterRaw
    tabCtrlW := w - 20

    GuiControl, Cockpit:Move, txMainTabs
        , % "x10 y" . g_cockpitTabTopY . " w" . tabCtrlW . " h" . tabOuterH

    GuiControlGet, tp, Cockpit:Pos, txMainTabs

    innerH := Max((tpH + 0) - COCKPIT_TAB_STRIP, g_cockpitMinTabInner)
    ddlXRel := tpW - COCKPIT_TAB_MARGIN_X - 120
    evtTopRel := COCKPIT_EVENTS_FILTER + 12
    evtEditH := innerH - evtTopRel - 10
    lvInnerW := tpW - 2 * COCKPIT_TAB_MARGIN_X

    instN := (forcedInstN + 0)
    if (instN <= 0)
        instN := botConfig.get("Instances") + 0
    if (instN <= 0)
        instN := 1
    lvNeed := LV_HWND ? Cockpit_MeasureLvHeight(LV_HWND, instN) : (innerH - 16)
    lvSlotMax := innerH - 16
    lvListH := lvNeed > lvSlotMax ? lvSlotMax : lvNeed

    GuiControl, Cockpit:Move, InstancesLv, % "x" . (tpX + COCKPIT_TAB_MARGIN_X) . " y" . (tpY + COCKPIT_TAB_STRIP + 8)
        . " w" . lvInnerW . " h" . lvListH

    Cockpit_ApplyColumnsToListView()

    GuiControl, Cockpit:Move, ddlEventFilter
        , % "x" . (tpX + ddlXRel) . " y" . (tpY + COCKPIT_TAB_STRIP + 10) . " w120"

    GuiControl, Cockpit:Move, EventsLog
        , % "x" . (tpX + COCKPIT_TAB_MARGIN_X)
        . " y" . (tpY + COCKPIT_TAB_STRIP + evtTopRel)
        . " w" . lvInnerW
        . " h" . evtEditH

    GuiControl, Cockpit:Move, SepTop, % "w" . (w - 20)
    GuiControl, Cockpit:Move, lblPrgBar, % "w" . (w - 28)
    GuiControl, Cockpit:Move, lblPrgVal, % "w" . (w - 28)
    if (g_instSingleMode) {
        g_instLayoutLineCache := ""
        GuiControlGet, instTxt, Cockpit:, lblInstRunVal
        Cockpit_LayoutInstancesSingle(instTxt)
    }
}

; When Instances (N) changes while Cockpit is open, retab page + ListView height + Events filter DDL (fixed-size window skips GuiSize).
Cockpit_MaybeRelayoutForInstanceCount(instN) {
    global g_cockpitLastInstLayoutN, g_cockpitHwnd, GUI_W, GUI_H, botConfig
    if (instN <= 0)
        instN := 1
    if (instN = g_cockpitLastInstLayoutN)
        return
    g_cockpitLastInstLayoutN := instN
    if (!g_cockpitHwnd)
        return
    botConfig.loadSettingsToConfig("ALL")
    Gui, Cockpit:Default
    Cockpit_Relayout(GUI_W, GUI_H, instN)
    Cockpit_UpdateEventFilterDdl(instN)
}

Cockpit_UpdateEventFilterDdl(instN) {
    global g_eventFilter
    if (instN <= 0)
        instN := 1
    filterChoices := "All|Warnings|System"
    Loop, %instN%
        filterChoices .= "|Instance " . A_Index
    GuiControl, Cockpit:, ddlEventFilter, |%filterChoices%
    prev := g_eventFilter
    if (prev = "" || prev = "ERROR")
        prev := "All"
    GuiControl, Cockpit:ChooseString, ddlEventFilter, %prev%
    if ErrorLevel {
        g_eventFilter := "All"
        GuiControl, Cockpit:ChooseString, ddlEventFilter, % "All"
        Cockpit_SaveEventFilter("All")
    }
}

;===============================================================================
; Hotkeys
;===============================================================================
#IfWinActive, PTCGPB Cockpit
    F5::Cockpit_RefreshBody()
#IfWinActive

#IfWinActive, Injection Queue
    F5::Cockpit_AgeRefresh()
#IfWinActive

~+F9::
    SetTimer, Agg_Tick, Off
    SetTimer, Cockpit_RefreshTicker, Off
ExitApp
