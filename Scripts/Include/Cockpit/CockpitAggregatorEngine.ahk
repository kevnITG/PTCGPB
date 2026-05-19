;===============================================================================
; CockpitAggregatorEngine.ahk
; In-process Aggregator engine used by Cockpit.ahk
;===============================================================================

global g_aggSessionStartEpoch := 0
global g_aggSessionId := ""
global g_aggStartEpoch := 0
global g_aggLastShiftEpoch := 0
global g_aggState := {}
global g_aggLastMode := ""
global g_aggOverlayPollingEnabled := false
global g_aggIgnoreHistoricalLogs := false
global g_aggPackCountMap := {}
global g_aggPackCountMapLastEpoch := 0

Agg_InitEngine() {
    global g_aggSessionStartEpoch, g_aggSessionId, g_aggStartEpoch
        , g_aggLastShiftEpoch, g_aggState, g_aggLastMode, g_aggIgnoreHistoricalLogs
        , g_aggPackCountMap, g_aggPackCountMapLastEpoch

    marker := Agg_ReadSessionMarker()
    if (marker.startEpoch > 0) {
        g_aggSessionStartEpoch := marker.startEpoch
        g_aggSessionId := marker.sessionId
    } else {
        prevState := CockpitState_Read()
        prevStart := 0
        prevId := ""
        if (IsObject(prevState) && IsObject(prevState.global)) {
            prevStart := prevState.global.sessionStartEpoch + 0
            prevId := prevState.global.sessionId
        }
        if (prevStart > 0) {
            g_aggSessionStartEpoch := prevStart
            g_aggSessionId := (prevId != "") ? prevId : A_NowUTC
        } else {
            g_aggSessionStartEpoch := CockpitState_NowEpoch()
            g_aggSessionId := A_NowUTC
        }
    }

    g_aggStartEpoch := g_aggSessionStartEpoch
    g_aggLastShiftEpoch := g_aggSessionStartEpoch
    g_aggState := Agg_NewState()
    g_aggLastMode := ""
    g_aggIgnoreHistoricalLogs := false
    g_aggPackCountMap := {}
    g_aggPackCountMapLastEpoch := 0

    if (!Agg_LoadRuntimeState(g_aggSessionId)) {
        ; Fresh bot session: ignore historical instance logs on first observation
        ; so stale STUCK lines from previous runs are not replayed into this session.
        g_aggIgnoreHistoricalLogs := true
        LogToFile("Cockpit in-process Aggregator starting. sessionStartEpoch=" . g_aggSessionStartEpoch, "Aggregator.txt")
        Agg_EmitEvent("info", "global", 0, "session", "Session started")
    }
}

Agg_TickBody() {
    global g_aggState, g_aggSessionStartEpoch, g_aggLastShiftEpoch, g_aggLastMode, botConfig

    botConfig.loadSettingsToConfig("ALL")
    instancesConfigured := (botConfig.get("Instances") + 0)
    if (instancesConfigured <= 0)
        instancesConfigured := 1
    mainEnabled := (botConfig.get("runMain") + 0) ? 1 : 0
    mode := botConfig.get("deleteMethod")
    if (mode = "")
        mode := "Inject Wonderpick 96P+"

    nowEpoch := CockpitState_NowEpoch()

    elapsedShift := nowEpoch - g_aggLastShiftEpoch
    if (elapsedShift >= METRICS_TREND_BIN_S) {
        shifts := elapsedShift // METRICS_TREND_BIN_S
        Metrics_AdvanceTrend(g_aggState.trendInjPerHour, shifts)
        Metrics_AdvanceTrend(g_aggState.trendAvgRunSum, shifts)
        Metrics_AdvanceTrend(g_aggState.trendAvgRunCount, shifts)
        Metrics_AdvanceTrend(g_aggState.trendStuckRate, shifts)
        g_aggLastShiftEpoch := g_aggLastShiftEpoch + shifts * METRICS_TREND_BIN_S
    }

    if (g_aggLastMode != "" && g_aggLastMode != mode) {
        g_aggState.globalRing := []
        if (!g_aggState.modeRings.HasKey(mode))
            g_aggState.modeRings[mode] := []
        Injectables_InvalidateCache()
    }
    g_aggLastMode := mode
    if (!g_aggState.modeRings.HasKey(mode))
        g_aggState.modeRings[mode] := []

    instanceData := {}
    instancesRunning := 0
    instancesStuck := 0
    instancesDead := 0
    instancesIdle := 0

    Loop, % instancesConfigured {
        N := A_Index
        info := Agg_ReadInstanceIni(N)
        isFirstObservation := !g_aggState.instances.HasKey(N)
        prev := isFirstObservation
            ? { "ring": [], "lastSeenEnd": 0, "stuckCount": 0, "lastStatus": ""
                , "accountFileName": "", "lastEvent": "", "lastEventEpoch": 0
                , "lastLogSize": -1, "stuckActive": false, "stuckSinceEpoch": 0
                , "livePacks": -1, "totalRunSecCompleted": 0, "gpFoundCount": 0 }
            : g_aggState.instances[N]
        if (!prev.HasKey("totalRunSecCompleted"))
            prev.totalRunSecCompleted := 0
        if (!prev.HasKey("gpFoundCount"))
            prev.gpFoundCount := 0

        if (!isFirstObservation
            && info.lastEndEpoch > 0
            && info.lastEndEpoch > prev.lastSeenEnd
            && prev.lastStatus = "running"
            && info.lastStartEpoch > 0
            && info.lastEndEpoch >= info.lastStartEpoch) {
            runDuration := info.lastEndEpoch - info.lastStartEpoch
            if (runDuration > 0 && runDuration < 6 * 3600) {
                Metrics_RingPush(prev.ring, runDuration)
                Metrics_RingPush(g_aggState.globalRing, runDuration)
                Metrics_RingPush(g_aggState.modeRings[mode], runDuration)
                g_aggState.totalRunsCompleted += 1
                prev.totalRunSecCompleted += runDuration
                latestBin := Metrics_LatestBinIndex()
                Metrics_TrendIncrement(g_aggState.trendInjPerHour, latestBin, 1)
                Metrics_TrendIncrement(g_aggState.trendAvgRunSum, latestBin, runDuration)
                Metrics_TrendIncrement(g_aggState.trendAvgRunCount, latestBin, 1)
            }
        }
        prev.lastSeenEnd := info.lastEndEpoch

        signals := Agg_PollInstanceLogSignals(N, prev, nowEpoch)
        if (signals.stuckHits > 0) {
            prev.stuckCount += signals.stuckHits
            if (!prev.stuckActive)
                prev.stuckSinceEpoch := nowEpoch
            prev.stuckActive := true
            Agg_EmitEvent("warn", "inst", N, "stuck"
                , "Instance " . N . " marked stuck (" . signals.lastStuckReason . ")")
            Loop, % signals.stuckHits
                Metrics_TrendIncrement(g_aggState.trendStuckRate, Metrics_LatestBinIndex(), 1)
        }
        if (signals.restarted && prev.stuckActive) {
            prev.stuckActive := false
            prev.stuckSinceEpoch := 0
            Agg_EmitEvent("info", "inst", N, "restart", "Instance " . N . " resumed")
        }

        accountFromIni := Trim(info.currentAccount)
        if (accountFromIni != "") {
            if (accountFromIni != prev.accountFileName) {
                prev.accountFileName := accountFromIni
                prev.livePacks := -1
            }
        }

        ; Overlays/AvgRuns/StatusMessage are AutoHotkeyGUI on the script PID (+Owner MuMu).
        ; WinGetText title match fails for Gui names reliably; enumerate by PID instead.
        guiTxt := Agg_ReadInstanceOverlayText(N)
        if (guiTxt = "")
            guiTxt := Agg_ReadInstanceStatusGuiText(N)
        uiState := Agg_ParseOverlayStatus(guiTxt)
        livePacks := Agg_ParseOverlayPacks(guiTxt)
        if (livePacks >= 0)
            prev.livePacks := livePacks

        overlayRuns := Agg_ParseOverlayRuns(guiTxt)
        ; ListView Runs: prefer AvgRuns "Runs:" (same scrape as packs); else INI Metrics\rerolls; else ring samples.
        if (overlayRuns >= 0)
            prev.runsDisplayed := overlayRuns + 0
        else {
            prev.runsDisplayed := (info.rerolls + 0)
            if (prev.runsDisplayed = 0 && prev.ring.Length() > 0)
                prev.runsDisplayed := prev.ring.Length()
        }
        if (prev.livePacks < 0 && prev.accountFileName != "") {
            livePacksMeta := Agg_GetAccountPackCount(prev.accountFileName)
            if (livePacksMeta >= 0)
                prev.livePacks := livePacksMeta
        }
        isAlive := Agg_IsInstanceScriptAlive(N)
        status := "idle"
        statusSince := nowEpoch
        if (!isAlive
            && (info.lastStartEpoch > 0 || info.lastEndEpoch > 0 || prev.lastStatus != "")) {
            status := "dead"
        } else if (uiState = "pausing") {
            status := "pausing"
            statusSince := nowEpoch
        } else if (prev.stuckActive) {
            status := "stuck"
            statusSince := (prev.stuckSinceEpoch > 0) ? prev.stuckSinceEpoch : nowEpoch
        } else if (info.lastStartEpoch = 0 && info.lastEndEpoch = 0) {
            status := "idle"
        } else if (info.lastStartEpoch > info.lastEndEpoch) {
            status := "running"
            statusSince := info.lastStartEpoch
        } else {
            status := "idle"
            statusSince := info.lastEndEpoch
        }
        prev.lastStatus := status

        currentRunSeconds := 0
        if (status = "running" || status = "stuck" || status = "pausing") {
            if (info.lastStartEpoch > 0)
                currentRunSeconds := Agg_Max(0, nowEpoch - info.lastStartEpoch)
        }

        if (signals.gpFound) {
            prev.gpFoundCount += 1
            details := "God Pack found"
            if (info.currentAccount != "")
                details .= " (" . info.currentAccount . ")"
            Agg_EmitEvent("info", "inst", N, "gp", details)
        }

        prev.lastSeenEpoch := nowEpoch
        prev.lastStartEpoch := info.lastStartEpoch
        prev.lastEndEpoch := info.lastEndEpoch
        prev.rerolls := info.rerolls
        prev.currentRunSec := currentRunSeconds
        prev.status := status
        prev.statusSince := statusSince
        prev.mode := mode

        g_aggState.instances[N] := prev
        instanceData[N] := prev

        if (status = "running")
            instancesRunning += 1
        else if (status = "stuck")
            instancesStuck += 1
        else if (status = "dead")
            instancesDead += 1
        else
            instancesIdle += 1
    }

    inj := Injectables_GetAll(instancesConfigured, mode)

    globalAvg := Metrics_Mean(g_aggState.globalRing)
    etaList := []
    Loop, % instancesConfigured {
        N := A_Index
        instData := instanceData[N]
        injN := (inj.perInstance.HasKey(N)) ? (inj.perInstance[N] + 0) : 0
        instEta := Metrics_InstanceEta(injN, instData.ring, 0)
        instData.eta := instEta
        instData.injectables := injN
        if (instData.status != "dead") {
            etaList.Push({ "instance": N, "seconds": instEta.seconds
                , "confidence": instEta.confidence })
        }
        instanceData[N] := instData
    }
    globalEta := Metrics_GlobalEta(etaList)

    mainData := ""
    if (mainEnabled)
        mainData := Agg_ReadMainIni()

    runsCompletedSession := g_aggState.totalRunsCompleted
    instancesAlive := instancesConfigured - instancesDead
    if (instancesAlive < 0)
        instancesAlive := 0
    avgRunSec := (globalAvg > 0) ? Round(globalAvg) : 0
    runsPerHourGlobal := (avgRunSec > 0 && instancesAlive > 0)
        ? Round(instancesAlive * 3600 / avgRunSec) : 0
    medianRunSec := Round(Metrics_Median(g_aggState.globalRing))
    p95RunSec := Round(Metrics_Percentile(g_aggState.globalRing, 95))

    avgRunBins := []
    Loop, % METRICS_TREND_BINS {
        cnt := g_aggState.trendAvgRunCount[A_Index]
        sum := g_aggState.trendAvgRunSum[A_Index]
        avgRunBins.Push(cnt > 0 ? Round(sum / cnt) : 0)
    }

    prevAlerts := g_aggState.alerts
    alerts := {}
    alerts["zeroInjectablesPending"] := (inj.total = 0 && mode != "Create Bots (13P)") ? 1 : 0
    alerts["allInstancesStuck"] := (instancesConfigured > 0 && instancesStuck >= instancesConfigured) ? 1 : 0
    alerts["heartbeatLost"] := Agg_HeartbeatLost() ? 1 : 0

    if (alerts["zeroInjectablesPending"]
        && (!prevAlerts.HasKey("zeroInjectablesPending") || !prevAlerts["zeroInjectablesPending"]))
        Agg_EmitEvent("warn", "global", 0, "alert", "Zero injectable accounts for " . mode)
    if (alerts["allInstancesStuck"]
        && (!prevAlerts.HasKey("allInstancesStuck") || !prevAlerts["allInstancesStuck"]))
        Agg_EmitEvent("warn", "global", 0, "alert", "All instances are stuck")
    g_aggState.alerts := alerts

    Agg_WriteState(instancesConfigured, instancesRunning, instancesStuck
        , instancesIdle, instancesDead, mainEnabled, mainData, mode
        , inj, globalEta, etaList, runsCompletedSession, runsPerHourGlobal
        , avgRunSec, medianRunSec, p95RunSec, avgRunBins, nowEpoch, instanceData)
    Agg_SaveRuntimeState()
}

Agg_ReadInstanceIni(N) {
    path := getScriptBaseFolder() . "\Scripts\" . N . ".ini"
    info := { "lastStartEpoch": 0, "lastEndEpoch": 0, "rerolls": 0
        , "currentAccount": "" }

    if (!FileExist(path))
        return info

    IniRead, ls, %path%, Metrics, LastStartEpoch, 0
    if (ls != "ERROR" && ls != "")
        info.lastStartEpoch := (ls + 0)
    IniRead, le, %path%, Metrics, LastEndEpoch, 0
    if (le != "ERROR" && le != "")
        info.lastEndEpoch := (le + 0)
    IniRead, rr, %path%, Metrics, rerolls, 0
    if (rr != "ERROR" && rr != "")
        info.rerolls := (rr + 0)
    IniRead, ca, %path%, Metrics, currentAccount, %A_Space%
    if (ca != "ERROR" && ca != "")
        info.currentAccount := ca

    return info
}

Agg_ReadMainIni() {
    global g_aggOverlayPollingEnabled
    path := getScriptBaseFolder() . "\Scripts\Main.ini"
    info := { "isDead": 0, "lastSeenEpoch": 0, "status": "idle" }
    if (!FileExist(path))
        return info

    IniRead, id, %path%, Metrics, isDead, 0
    if (id != "ERROR" && id != "")
        info.isDead := (id + 0)

    alive := Agg_IsMainScriptAlive()
    uiState := ""
    if (g_aggOverlayPollingEnabled)
        uiState := Agg_ParseOverlayStatus(Agg_ReadMainOverlayText())
    if (!alive) {
        info.status := "dead"
    } else if (uiState = "pausing") {
        info.status := "pausing"
    } else {
        info.status := "running"
    }
    info.lastSeenEpoch := CockpitState_NowEpoch()
    return info
}

Agg_HeartbeatLost() {
    path := getScriptBaseFolder() . "\HeartBeat.ini"
    if (!FileExist(path))
        return false
    FileGetTime, mtime, %path%, M
    nowLocal := A_Now
    EnvSub, nowLocal, %mtime%, Seconds
    return (nowLocal > 120)
}

Agg_IsInstanceScriptAlive(N) {
    prevMode := A_TitleMatchMode
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    SetTitleMatchMode, 2
    title := N . ".ahk ahk_class AutoHotkey"
    found := WinExist(title) ? true : false
    SetTitleMatchMode, %prevMode%
    DetectHiddenWindows, %prevHidden%
    return found
}

Agg_ReadInstanceOverlayText(N) {
    scriptPid := Agg_GetInstanceScriptPid(N)
    ownerHwnd := Agg_GetInstanceWindowHwnd(N)
    return Agg_ReadOwnedGuiOverlayText(scriptPid, ownerHwnd)
}

Agg_GetInstanceScriptPid(N) {
    prevMode := A_TitleMatchMode
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    SetTitleMatchMode, 2
    WinGet, pid, PID, % N . ".ahk ahk_class AutoHotkey"
    SetTitleMatchMode, %prevMode%
    DetectHiddenWindows, %prevHidden%
    return pid ? pid : 0
}

Agg_GetInstanceWindowHwnd(N) {
    prevMode := A_TitleMatchMode
    SetTitleMatchMode, 3
    hwnd := WinExist(N . " ahk_class Qt5156QWindowIcon")
    SetTitleMatchMode, %prevMode%
    return hwnd
}

Agg_IsMainScriptAlive() {
    prevMode := A_TitleMatchMode
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    SetTitleMatchMode, 2
    WinGet, pid, PID, Main.ahk ahk_class AutoHotkey
    SetTitleMatchMode, %prevMode%
    DetectHiddenWindows, %prevHidden%
    return pid ? true : false
}

Agg_ReadMainOverlayText() {
    prevMode := A_TitleMatchMode
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    SetTitleMatchMode, 2
    WinGet, scriptPid, PID, Main.ahk ahk_class AutoHotkey
    SetTitleMatchMode, %prevMode%
    DetectHiddenWindows, %prevHidden%

    prevMode := A_TitleMatchMode
    SetTitleMatchMode, 3
    ownerHwnd := WinExist("Main ahk_class Qt5156QWindowIcon")
    SetTitleMatchMode, %prevMode%
    return Agg_ReadOwnedGuiOverlayText(scriptPid, ownerHwnd)
}

Agg_ReadOwnedGuiOverlayText(scriptPid, ownerHwnd) {
    if (!scriptPid && !ownerHwnd)
        return ""
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGet, guiList, List, ahk_class AutoHotkeyGUI
    outTxt := ""
    Loop, % guiList {
        guiHwnd := guiList%A_Index%
        match := false
        if (scriptPid) {
            WinGet, guiPid, PID, ahk_id %guiHwnd%
            if (guiPid = scriptPid)
                match := true
        }
        if (!match && ownerHwnd) {
            ownedBy := DllCall("GetWindow", "Ptr", guiHwnd, "UInt", 4, "Ptr")
            if (ownedBy = ownerHwnd)
                match := true
        }
        if (!match)
            continue
        txt := ""
        WinGetText, txt, ahk_id %guiHwnd%
        if (txt = "")
            continue
        if (outTxt != "")
            outTxt .= "`n"
        outTxt .= txt
    }
    DetectHiddenWindows, %prevHidden%
    return outTxt
}

Agg_ParseOverlayStatus(rawText) {
    if (rawText = "")
        return ""
    low := rawText
    StringLower, low, low
    if (InStr(low, "pausing") || InStr(low, "paused"))
        return "pausing"
    return ""
}

Agg_ReadInstanceStatusGuiText(N) {
    prevMode := A_TitleMatchMode
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    SetTitleMatchMode, 2
    ; generateStatusText() (Packs:, Runs:, timing) updates AvgRuns<N> with Persist=true.
    ; Short-lived messages use StatusMessage<N>; read both so packs are not missed.
    WinGetText, avgTxt, % "AvgRuns" . N . " ahk_class AutoHotkeyGUI"
    WinGetText, statusTxt, % "StatusMessage" . N . " ahk_class AutoHotkeyGUI"
    SetTitleMatchMode, %prevMode%
    DetectHiddenWindows, %prevHidden%
    txt := ""
    if (avgTxt != "") {
        txt := avgTxt
    }
    if (statusTxt != "") {
        if (txt != "")
            txt .= "`n" . statusTxt
        else
            txt := statusTxt
    }
    return txt
}

Agg_ParseOverlayPacks(rawText) {
    if (rawText = "")
        return -1
    ; generateStatusText(): "Packs: " N " |" - allow stray spaces / fullwidth colon
    if (RegExMatch(rawText, "i)Packs\s*[:：]\s*(\d+)", m))
        return m1 + 0
    return -1
}

Agg_ParseOverlayRuns(rawText) {
    if (rawText = "")
        return -1
    ; generateStatusText(): "Runs: " N " |" - same allowances as Agg_ParseOverlayPacks
    if (RegExMatch(rawText, "i)Runs\s*[:：]\s*(\d+)", m))
        return m1 + 0
    return -1
}

Agg_EmitEvent(level, scope, instance, category, details) {
    global g_aggState
    g_aggState.eventCounter += 1
    ev := { "id": g_aggState.eventCounter, "epoch": CockpitState_NowEpoch()
        , "level": level, "scope": scope, "instance": instance
        , "category": category, "details": details }
    g_aggState.events.Push(ev)

    if (scope = "inst" && instance > 0 && g_aggState.instances.HasKey(instance)) {
        g_aggState.instances[instance].lastEvent := details
        g_aggState.instances[instance].lastEventEpoch := ev.epoch
    }
}

Agg_WriteState(instancesConfigured, instancesRunning, instancesStuck
    , instancesIdle, instancesDead, mainEnabled, mainData, mode
    , inj, globalEta, etaList, runsCompletedSession, runsPerHourGlobal
    , avgRunSec, medianRunSec, p95RunSec, avgRunBins, nowEpoch, instanceData) {

    global g_aggState, g_aggSessionStartEpoch, g_aggSessionId

    b := CockpitState_NewBuilder()

    CockpitState_AddSection(b, "Schema")
    CockpitState_AddKey(b, "version", 1)

    CockpitState_AddSection(b, "Global")
    CockpitState_AddKey(b, "sessionId", g_aggSessionId)
    CockpitState_AddKey(b, "sessionStartEpoch", g_aggSessionStartEpoch)
    CockpitState_AddKey(b, "modeActive", mode)
    CockpitState_AddKey(b, "instancesConfigured", instancesConfigured)
    CockpitState_AddKey(b, "mainEnabled", mainEnabled)
    CockpitState_AddKey(b, "instancesRunning", instancesRunning)
    CockpitState_AddKey(b, "instancesStuck", instancesStuck)
    CockpitState_AddKey(b, "instancesIdle", instancesIdle)
    CockpitState_AddKey(b, "instancesDead", instancesDead)
    CockpitState_AddKey(b, "heartbeatPresent", Agg_HeartbeatLost() ? 0 : 1)
    CockpitState_AddKey(b, "lastAggregatorEpoch", nowEpoch)

    CockpitState_AddSection(b, "Eta")
    CockpitState_AddKey(b, "etaSecondsGlobal", globalEta.seconds)
    CockpitState_AddKey(b, "etaConfidence", globalEta.confidence)
    CockpitState_AddKey(b, "etaBottleneck", globalEta.bottleneck)
    CockpitState_AddKey(b, "etaTargetSnapshot", inj.total)
    CockpitState_AddKey(b, "etaSamplesUsed", g_aggState.globalRing.Length())
    CockpitState_AddKey(b, "etaAvgRunSeconds", avgRunSec)
    CockpitState_AddKey(b, "etaCalcEpoch", nowEpoch)

    CockpitState_AddSection(b, "Queues")
    CockpitState_AddKey(b, "injectableNow", inj.total)
    CockpitState_AddKey(b, "injectableSource", inj.source)
    Loop, % instancesConfigured {
        N := A_Index
        cnt := inj.perInstance.HasKey(N) ? inj.perInstance[N] : 0
        CockpitState_AddKey(b, "injectable_" . N, cnt)
    }

    CockpitState_AddSection(b, "Throughput")
    CockpitState_AddKey(b, "runsCompletedSession", runsCompletedSession)
    CockpitState_AddKey(b, "runsPerHourGlobal", runsPerHourGlobal)
    CockpitState_AddKey(b, "avgRunSecondsSession", avgRunSec)
    CockpitState_AddKey(b, "medianRunSecondsSession", medianRunSec)
    CockpitState_AddKey(b, "p95RunSecondsSession", p95RunSec)
    CockpitState_AddKey(b, "trendInjPerHour_6h", Metrics_ArrayToCsv(g_aggState.trendInjPerHour))
    CockpitState_AddKey(b, "trendAvgRunSec_6h", Metrics_ArrayToCsv(avgRunBins))
    CockpitState_AddKey(b, "trendStuckRate_6h", Metrics_ArrayToCsv(g_aggState.trendStuckRate))

    CockpitState_AddSection(b, "ModeStats")
    for modeKey, ring in g_aggState.modeRings {
        cnt := ring.Length()
        avg := Round(Metrics_Mean(ring))
        med := Round(Metrics_Median(ring))
        p95v := Round(Metrics_Percentile(ring, 95))
        sanK := RegExReplace(modeKey, "[^A-Za-z0-9]", "_")
        CockpitState_AddKey(b, sanK . "_count", cnt)
        CockpitState_AddKey(b, sanK . "_avgSec", avg)
        CockpitState_AddKey(b, sanK . "_medSec", med)
        CockpitState_AddKey(b, sanK . "_p95Sec", p95v)
    }

    CockpitState_AddSection(b, "Runtime")
    Loop, % instancesConfigured {
        N := A_Index
        d := instanceData[N]
        if (!IsObject(d))
            continue
        CockpitState_AddKey(b, "lastStart_" . N, d.lastStartEpoch)
        CockpitState_AddKey(b, "lastEnd_" . N, d.lastEndEpoch)
    }

    if (mainEnabled && IsObject(mainData)) {
        CockpitState_AddSection(b, "Main")
        CockpitState_AddKey(b, "status", mainData.status)
        CockpitState_AddKey(b, "isDead", mainData.isDead)
        CockpitState_AddKey(b, "lastSeenEpoch", mainData.lastSeenEpoch)
    }

    Loop, % instancesConfigured {
        N := A_Index
        d := instanceData[N]
        if (!IsObject(d))
            continue
        CockpitState_AddSection(b, "Instance:" . N)
        CockpitState_AddKey(b, "instanceId", N)
        CockpitState_AddKey(b, "mode", d.mode)
        CockpitState_AddKey(b, "status", d.status)
        CockpitState_AddKey(b, "statusSince", d.statusSince)
        CockpitState_AddKey(b, "lastSeenEpoch", d.lastSeenEpoch)
        CockpitState_AddKey(b, "lastStartEpoch", d.lastStartEpoch)
        CockpitState_AddKey(b, "lastEndEpoch", d.lastEndEpoch)
        CockpitState_AddKey(b, "runsSession", d.HasKey("runsDisplayed") ? (d.runsDisplayed + 0) : d.ring.Length())
        CockpitState_AddKey(b, "avgRunSeconds", Round(Metrics_Mean(d.ring)))
        CockpitState_AddKey(b, "rerolls", d.rerolls)
        CockpitState_AddKey(b, "accountFileName", d.accountFileName)
        CockpitState_AddKey(b, "livePacks", d.livePacks)
        CockpitState_AddKey(b, "currentRunSeconds", d.currentRunSec)
        CockpitState_AddKey(b, "stuckCountSession", d.stuckCount)
        CockpitState_AddKey(b, "totalRunSeconds", d.totalRunSecCompleted)
        CockpitState_AddKey(b, "gpFoundCount", d.gpFoundCount)
        CockpitState_AddKey(b, "injectables", d.injectables)
        CockpitState_AddKey(b, "etaSeconds", d.eta.seconds)
        CockpitState_AddKey(b, "etaConfidence", d.eta.confidence)
        CockpitState_AddKey(b, "etaLabel", d.eta.label)
        CockpitState_AddKey(b, "etaAvgSec", d.eta.avg)
        CockpitState_AddKey(b, "lastEvent", d.lastEvent)
        CockpitState_AddKey(b, "lastEventEpoch", d.lastEventEpoch)
    }

    CockpitState_AddSection(b, "Events")
    Loop, % g_aggState.events.Length() {
        ev := g_aggState.events[A_Index]
        key := "event_" . Format("{:06}", ev.id)
        val := ev.epoch . "|" . ev.level . "|" . ev.scope . "|" . ev.instance
            . "|" . ev.category . "|" . ev.details
        CockpitState_AddKey(b, key, val)
    }

    CockpitState_AddSection(b, "Alerts")
    for k, v in g_aggState.alerts
        CockpitState_AddKey(b, k, v)

    ok := CockpitState_Commit(b)
    if (!ok)
        LogToFile("Cockpit in-process aggregator: failed to commit CockpitState.ini", "Aggregator.txt")
}

Agg_Max(a, b) {
    return (a > b) ? a : b
}

Agg_PollInstanceLogSignals(instanceNum, instState, nowEpoch := 0) {
    global g_aggIgnoreHistoricalLogs
    result := { "gpFound": false, "stuckHits": 0, "restarted": false
        , "lastStuckReason": "log signal" }
    logsDir := getScriptBaseFolder() . "\Logs"
    logPath := logsDir . "\Log_" . instanceNum . ".txt"
    if (!FileExist(logPath)) {
        instState.lastLogSize := 0
        return result
    }

    FileGetSize, sizeNow, %logPath%
    if (sizeNow = "")
        sizeNow := 0

    if (instState.lastLogSize < 0) {
        if (g_aggIgnoreHistoricalLogs) {
            instState.lastLogSize := sizeNow
            return result
        }
        ; First observation: inspect only a short tail so we can recover
        ; current stuck state without replaying the full historical log.
        tailBytes := 4096
        startPos := (sizeNow > tailBytes) ? (sizeNow - tailBytes) : 0
        f := FileOpen(logPath, "r")
        if (!f) {
            instState.lastLogSize := sizeNow
            return result
        }
        f.Pos := startPos
        chunk := f.Read(sizeNow - startPos)
        f.Close()
        instState.lastLogSize := sizeNow
    } else {
        if (sizeNow < instState.lastLogSize)
            instState.lastLogSize := 0

        if (sizeNow <= instState.lastLogSize)
            return result

        f := FileOpen(logPath, "r")
        if (!f) {
            instState.lastLogSize := sizeNow
            return result
        }
        f.Pos := instState.lastLogSize
        chunk := f.Read(sizeNow - instState.lastLogSize)
        f.Close()
        instState.lastLogSize := sizeNow
    }

    Loop, Parse, chunk, `n, `r
    {
        line := A_LoopField
        if (line = "")
            continue
        if (InStr(line, "God Pack found. Continuing..."))
            result.gpFound := true

        if (InStr(line, "STUCK DETECTED")) {
            result.stuckHits += 1
            reason := line
            if (RegExMatch(line, "i)Reason:\s*([^|]+)", mr))
                reason := Trim(mr1)
            result.lastStuckReason := reason
        } else if (InStr(line, "has been stuck")) {
            result.stuckHits += 1
            result.lastStuckReason := "stuck watchdog"
        }

        if (InStr(line, "Restarted MuMu instance. Reason:")
            || InStr(line, "Restarted game. Reason:")
            || InStr(line, "Restart complete!")) {
            result.restarted := true
        }
    }
    return result
}

Agg_NewState() {
    state := { "instances": {}, "globalRing": []
        , "modeRings": {}, "trendInjPerHour": "", "trendAvgRunSum": ""
        , "trendAvgRunCount": "", "trendStuckRate": "", "events": []
        , "eventCounter": 0, "alerts": {}, "totalRunsCompleted": 0 }
    state.trendInjPerHour := Metrics_NewTrend()
    state.trendAvgRunSum := Metrics_NewTrend()
    state.trendAvgRunCount := Metrics_NewTrend()
    state.trendStuckRate := Metrics_NewTrend()
    return state
}

Agg_SessionMarkerPath() {
    return getScriptBaseFolder() . "\Scripts\Include\Cockpit\CockpitSession.ini"
}

Agg_RuntimeStatePath() {
    return getScriptBaseFolder() . "\Scripts\Include\Cockpit\CockpitRuntime.ini"
}

Agg_ReadSessionMarker() {
    out := { "startEpoch": 0, "sessionId": "" }
    path := Agg_SessionMarkerPath()
    if (!FileExist(path))
        return out
    IniRead, ss, %path%, Session, StartEpoch, 0
    IniRead, sid, %path%, Session, SessionId, %A_Space%
    out.startEpoch := (ss + 0)
    out.sessionId := (sid = "ERROR") ? "" : sid
    if (out.sessionId = "")
        out.sessionId := A_NowUTC
    return out
}

Agg_SaveRuntimeState() {
    global g_aggState, g_aggSessionStartEpoch, g_aggSessionId, g_aggLastShiftEpoch, g_aggLastMode
    path := Agg_RuntimeStatePath()

    IniWrite, %g_aggSessionStartEpoch%, %path%, Runtime, SessionStartEpoch
    IniWrite, %g_aggSessionId%, %path%, Runtime, SessionId
    IniWrite, %g_aggLastShiftEpoch%, %path%, Runtime, LastShiftEpoch
    IniWrite, %g_aggLastMode%, %path%, Runtime, LastMode
    IniWrite, % (g_aggState.eventCounter + 0), %path%, Runtime, EventCounter
    IniWrite, % (g_aggState.totalRunsCompleted + 0), %path%, Runtime, TotalRunsCompleted
    IniWrite, % Metrics_ArrayToCsv(g_aggState.globalRing), %path%, Runtime, GlobalRing
    IniWrite, % Metrics_ArrayToCsv(g_aggState.trendInjPerHour), %path%, Runtime, TrendInjPerHour
    IniWrite, % Metrics_ArrayToCsv(g_aggState.trendAvgRunSum), %path%, Runtime, TrendAvgRunSum
    IniWrite, % Metrics_ArrayToCsv(g_aggState.trendAvgRunCount), %path%, Runtime, TrendAvgRunCount
    IniWrite, % Metrics_ArrayToCsv(g_aggState.trendStuckRate), %path%, Runtime, TrendStuckRate

    modeNames := ""
    for mk, ring in g_aggState.modeRings {
        key := RegExReplace(mk, "[^A-Za-z0-9]", "_")
        if (modeNames != "")
            modeNames .= "|"
        modeNames .= key
        IniWrite, %mk%, %path%, ModeRings, % key . "_Name"
        IniWrite, % Metrics_ArrayToCsv(ring), %path%, ModeRings, % key . "_Ring"
    }
    IniWrite, %modeNames%, %path%, ModeRings, Keys

    evCount := g_aggState.events.Length()
    IniWrite, %evCount%, %path%, Events, Count
    Loop, %evCount% {
        ev := g_aggState.events[A_Index]
        evLine := ev.id . "|" . ev.epoch . "|" . ev.level . "|" . ev.scope . "|"
            . ev.instance . "|" . ev.category . "|" . ev.details
        IniWrite, %evLine%, %path%, Events, % "E" . A_Index
    }

    for ak, av in g_aggState.alerts
        IniWrite, %av%, %path%, Alerts, %ak%

    for instId, inst in g_aggState.instances {
        sec := "Instance:" . instId
        IniWrite, % Metrics_ArrayToCsv(inst.ring), %path%, %sec%, Ring
        IniWrite, % (inst.lastSeenEnd + 0), %path%, %sec%, LastSeenEnd
        IniWrite, % (inst.stuckCount + 0), %path%, %sec%, StuckCount
        IniWrite, % inst.lastStatus, %path%, %sec%, LastStatus
        IniWrite, % inst.accountFileName, %path%, %sec%, AccountFileName
        IniWrite, % inst.lastEvent, %path%, %sec%, LastEvent
        IniWrite, % (inst.lastEventEpoch + 0), %path%, %sec%, LastEventEpoch
        IniWrite, % (inst.lastLogSize + 0), %path%, %sec%, LastLogSize
        IniWrite, % (inst.stuckActive ? 1 : 0), %path%, %sec%, StuckActive
        IniWrite, % (inst.stuckSinceEpoch + 0), %path%, %sec%, StuckSinceEpoch
        IniWrite, % (inst.livePacks + 0), %path%, %sec%, LivePacks
        IniWrite, % (inst.totalRunSecCompleted + 0), %path%, %sec%, TotalRunSecCompleted
        IniWrite, % (inst.gpFoundCount + 0), %path%, %sec%, GpFoundCount
    }
}

Agg_LoadRuntimeState(sessionId) {
    global g_aggState, g_aggSessionStartEpoch, g_aggSessionId, g_aggLastShiftEpoch, g_aggLastMode
    path := Agg_RuntimeStatePath()
    if (!FileExist(path))
        return false

    IniRead, sid, %path%, Runtime, SessionId, %A_Space%
    if (sid = "ERROR" || sid = "" || sid != sessionId)
        return false

    IniRead, ss, %path%, Runtime, SessionStartEpoch, 0
    IniRead, lse, %path%, Runtime, LastShiftEpoch, 0
    IniRead, lm, %path%, Runtime, LastMode, %A_Space%
    IniRead, ec, %path%, Runtime, EventCounter, 0
    IniRead, tr, %path%, Runtime, TotalRunsCompleted, 0
    IniRead, gr, %path%, Runtime, GlobalRing, %A_Space%
    IniRead, ti, %path%, Runtime, TrendInjPerHour, %A_Space%
    IniRead, ts, %path%, Runtime, TrendAvgRunSum, %A_Space%
    IniRead, tc, %path%, Runtime, TrendAvgRunCount, %A_Space%
    IniRead, tt, %path%, Runtime, TrendStuckRate, %A_Space%

    g_aggSessionId := sid
    g_aggSessionStartEpoch := (ss + 0)
    g_aggLastShiftEpoch := (lse + 0)
    g_aggLastMode := (lm = "ERROR") ? "" : lm
    g_aggState.eventCounter := (ec + 0)
    g_aggState.totalRunsCompleted := (tr + 0)
    g_aggState.globalRing := Agg_CsvToNumArray(gr)
    g_aggState.trendInjPerHour := Agg_FitTrendArray(Agg_CsvToNumArray(ti))
    g_aggState.trendAvgRunSum := Agg_FitTrendArray(Agg_CsvToNumArray(ts))
    g_aggState.trendAvgRunCount := Agg_FitTrendArray(Agg_CsvToNumArray(tc))
    g_aggState.trendStuckRate := Agg_FitTrendArray(Agg_CsvToNumArray(tt))

    g_aggState.modeRings := {}
    IniRead, modeKeys, %path%, ModeRings, Keys, %A_Space%
    if (modeKeys != "ERROR" && modeKeys != "") {
        Loop, Parse, modeKeys, |
        {
            k := A_LoopField
            if (k = "")
                continue
            IniRead, realName, %path%, ModeRings, % k . "_Name", %A_Space%
            IniRead, ringCsv, %path%, ModeRings, % k . "_Ring", %A_Space%
            if (realName = "ERROR" || realName = "")
                continue
            g_aggState.modeRings[realName] := Agg_CsvToNumArray(ringCsv)
        }
    }

    g_aggState.events := []
    IniRead, evCount, %path%, Events, Count, 0
    evCount := evCount + 0
    Loop, %evCount% {
        IniRead, evLine, %path%, Events, % "E" . A_Index, %A_Space%
        if (evLine = "ERROR" || evLine = "")
            continue
        p := StrSplit(evLine, "|")
        if (p.Length() < 7)
            continue
        g_aggState.events.Push({ "id": p[1] + 0, "epoch": p[2] + 0, "level": p[3]
            , "scope": p[4], "instance": p[5] + 0, "category": p[6], "details": p[7] })
    }

    g_aggState.alerts := {}
    IniRead, rawAlerts, %path%, Alerts
    if (rawAlerts != "ERROR" && rawAlerts != "") {
        Loop, Parse, rawAlerts, `n, `r
        {
            line := A_LoopField
            if (line = "")
                continue
            pos := InStr(line, "=")
            if (pos <= 0)
                continue
            k := SubStr(line, 1, pos - 1)
            v := SubStr(line, pos + 1)
            g_aggState.alerts[k] := v + 0
        }
    }

    g_aggState.instances := {}
    botConfig.loadSettingsToConfig("ALL")
    instancesConfigured := (botConfig.get("Instances") + 0)
    if (instancesConfigured <= 0)
        instancesConfigured := 1
    Loop, % instancesConfigured {
        N := A_Index
        sec := "Instance:" . N
        IniRead, ringCsv, %path%, %sec%, Ring, %A_Space%
        IniRead, lse2, %path%, %sec%, LastSeenEnd, 0
        IniRead, sc, %path%, %sec%, StuckCount, 0
        IniRead, ls2, %path%, %sec%, LastStatus, %A_Space%
        IniRead, af, %path%, %sec%, AccountFileName, %A_Space%
        IniRead, le, %path%, %sec%, LastEvent, %A_Space%
        IniRead, lee, %path%, %sec%, LastEventEpoch, 0
        IniRead, lls, %path%, %sec%, LastLogSize, -1
        IniRead, sa, %path%, %sec%, StuckActive, 0
        IniRead, sse, %path%, %sec%, StuckSinceEpoch, 0
        IniRead, lp, %path%, %sec%, LivePacks, -1
        IniRead, trc, %path%, %sec%, TotalRunSecCompleted, 0
        IniRead, gpc, %path%, %sec%, GpFoundCount, 0
        g_aggState.instances[N] := { "ring": Agg_CsvToNumArray(ringCsv), "lastSeenEnd": lse2 + 0
            , "stuckCount": sc + 0, "lastStatus": (ls2 = "ERROR") ? "" : ls2
            , "accountFileName": (af = "ERROR") ? "" : af, "lastEvent": (le = "ERROR") ? "" : le
            , "lastEventEpoch": lee + 0, "lastLogSize": lls + 0
            , "stuckActive": (sa + 0) ? true : false, "stuckSinceEpoch": sse + 0
            , "livePacks": lp + 0, "totalRunSecCompleted": trc + 0, "gpFoundCount": gpc + 0 }
    }

    LogToFile("Cockpit in-process Aggregator resumed session " . g_aggSessionId, "Aggregator.txt")
    return true
}

Agg_CsvToNumArray(csv) {
    arr := []
    if (csv = "ERROR" || csv = "")
        return arr
    Loop, Parse, csv, `,
    {
        v := Trim(A_LoopField)
        if (v = "")
            continue
        arr.Push(v + 0)
    }
    return arr
}

Agg_FitTrendArray(arr) {
    out := Metrics_NewTrend()
    n := arr.Length()
    if (n <= 0)
        return out
    start := METRICS_TREND_BINS - n + 1
    if (start < 1)
        start := 1
    idx := 1
    Loop, % METRICS_TREND_BINS {
        pos := A_Index
        if (pos < start)
            continue
        if (idx > n)
            break
        out[pos] := arr[idx]
        idx++
    }
    return out
}

Agg_GetAccountPackCount(accountFileName) {
    global g_aggPackCountMap

    Agg_RefreshPackCountMap()
    if (accountFileName = "")
        return -1

    normalized := Agg_NormalizePackMapKey(accountFileName)
    if (normalized != "" && g_aggPackCountMap.HasKey(normalized))
        return g_aggPackCountMap[normalized] + 0

    baseName := Agg_BaseName(accountFileName)
    normalizedBase := Agg_NormalizePackMapKey(baseName)
    if (normalizedBase != "" && g_aggPackCountMap.HasKey(normalizedBase))
        return g_aggPackCountMap[normalizedBase] + 0

    return -1
}

Agg_RefreshPackCountMap(force := false) {
    global g_aggPackCountMap, g_aggPackCountMapLastEpoch

    nowEpoch := CockpitState_NowEpoch()
    if (!force && g_aggPackCountMapLastEpoch > 0 && (nowEpoch - g_aggPackCountMapLastEpoch) < 15)
        return

    rawMap := AccountMetadata_GetPackCountMap()
    newMap := {}
    for fileName, packCount in rawMap {
        keyFull := Agg_NormalizePackMapKey(fileName)
        if (keyFull != "")
            newMap[keyFull] := packCount + 0

        baseName := Agg_BaseName(fileName)
        keyBase := Agg_NormalizePackMapKey(baseName)
        if (keyBase != "" && !newMap.HasKey(keyBase))
            newMap[keyBase] := packCount + 0
    }

    g_aggPackCountMap := newMap
    g_aggPackCountMapLastEpoch := nowEpoch
}

Agg_NormalizePackMapKey(value) {
    value := Trim(value)
    if (value = "")
        return ""
    StringLower, out, value
    return out
}

Agg_BaseName(path) {
    if (path = "")
        return ""
    SplitPath, path, fileName
    return fileName
}
