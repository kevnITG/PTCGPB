;===============================================================================
; CockpitMetrics.ahk - Pure stats: ring buffer, ETA, sparkline, 6h trend bins
;===============================================================================
; All functions are pure (no I/O), used by Aggregator.ahk to compute the
; numbers that are then serialized into CockpitState.ini.
;
; Conventions:
;   - Durations are in SECONDS unless otherwise stated.
;   - Epochs are UNIX seconds (UTC). See CockpitState_NowEpoch().
;   - Ring buffer = AHK array, capped via Metrics_RingPush()
;
;===============================================================================

global METRICS_RING_CAP     := 50
global METRICS_TREND_BINS   := 12
global METRICS_TREND_BIN_S  := 1800   ; 30 min * 12 = 6h window

;-------------------------------------------------------------------------------
; Ring buffer
;-------------------------------------------------------------------------------
Metrics_NewRing() {
    return []
}

Metrics_RingPush(ring, value) {
    if (value <= 0)
        return
    ring.Push(value + 0)
    while (ring.Length() > METRICS_RING_CAP)
        ring.RemoveAt(1)
}

Metrics_RingSize(ring) {
    return ring.Length()
}

;-------------------------------------------------------------------------------
; Basic statistics
;-------------------------------------------------------------------------------
Metrics_Mean(arr) {
    n := arr.Length()
    if (n = 0)
        return 0
    sum := 0
    Loop, % n
        sum += arr[A_Index]
    return sum / n
}

Metrics_Stddev(arr) {
    n := arr.Length()
    if (n < 2)
        return 0
    avg := Metrics_Mean(arr)
    sq := 0
    Loop, % n {
        d := arr[A_Index] - avg
        sq += d * d
    }
    return Sqrt(sq / (n - 1))
}

Metrics_Median(arr) {
    n := arr.Length()
    if (n = 0)
        return 0
    sorted := Metrics_SortedCopy(arr)
    mid := n // 2
    if (Mod(n, 2) = 1)
        return sorted[mid + 1]
    return (sorted[mid] + sorted[mid + 1]) / 2
}

Metrics_Percentile(arr, p) {
    n := arr.Length()
    if (n = 0)
        return 0
    sorted := Metrics_SortedCopy(arr)
    ; nearest-rank
    rank := Ceil(p / 100 * n)
    if (rank < 1)
        rank := 1
    if (rank > n)
        rank := n
    return sorted[rank]
}

Metrics_SortedCopy(arr) {
    ; Numeric sort using a temp delimited string + AHK Sort
    tmp := ""
    Loop, % arr.Length() {
        if (tmp != "")
            tmp .= "`n"
        tmp .= arr[A_Index]
    }
    Sort, tmp, N
    out := []
    Loop, Parse, tmp, `n, `r
    {
        if (A_LoopField = "")
            continue
        out.Push(A_LoopField + 0)
    }
    return out
}

;-------------------------------------------------------------------------------
; ETA
;-------------------------------------------------------------------------------
; computeInstanceEta(injCount, ringOfRunTimes, globalAvgFallback)
;   returns object: { seconds: N, confidence: "high"|"medium"|"low"|"unknown"
;                   , avg: N, samples: N, label: "" }
;-------------------------------------------------------------------------------
Metrics_InstanceEta(injCount, ring, globalAvgFallback := 0) {
    result := { "seconds": 0, "confidence": "unknown", "avg": 0
        , "samples": 0, "label": "" }

    if (injCount <= 0) {
        result.seconds := 0
        result.label   := "0h 0m"
        result.confidence := "unknown"
        return result
    }

    samples := ring.Length()
    result.samples := samples

    if (samples >= 5) {
        avg := Metrics_Mean(ring)
        sd  := Metrics_Stddev(ring)
        cv  := (avg > 0) ? (sd / avg) : 1
        result.avg := Round(avg)
        result.seconds := Round(injCount * avg)
        result.confidence := "low"
        if (samples >= 20 && cv < 0.30)
            result.confidence := "medium"
        if (samples >= 50 && cv < 0.15)
            result.confidence := "high"
    } else if (globalAvgFallback > 0) {
        result.avg := Round(globalAvgFallback)
        result.seconds := Round(injCount * globalAvgFallback)
        result.confidence := "unknown"
    }

    return result
}

;-------------------------------------------------------------------------------
; Global ETA = max(instanceETA). Returns the bottleneck info too.
;   etaList = [ {instance:N, seconds:S, confidence:C, ...}, ... ]
;-------------------------------------------------------------------------------
Metrics_GlobalEta(etaList) {
    out := { "seconds": 0, "confidence": "unknown", "bottleneck": 0 }
    bestSec := -1
    confidenceRank := { "high": 3, "medium": 2, "low": 1, "unknown": 0 }
    minRank := 99

    for idx, item in etaList {
        sec := item["seconds"] + 0
        if (sec > bestSec) {
            bestSec := sec
            out.bottleneck := item["instance"]
        }
        cr := confidenceRank.HasKey(item["confidence"])
            ? confidenceRank[item["confidence"]] : 0
        if (cr < minRank)
            minRank := cr
    }
    if (bestSec < 0)
        bestSec := 0
    out.seconds := bestSec

    for label, rank in confidenceRank {
        if (rank = minRank) {
            out.confidence := label
            break
        }
    }
    return out
}

;-------------------------------------------------------------------------------
; 6h trend bins (12 bins of 30 min)
;   Trend objs are AHK arrays of length METRICS_TREND_BINS, value = number.
;   Aggregator increments via Metrics_TrendIncrement(trend, sessionStartEpoch, nowEpoch, amount)
;   Set explicit value via Metrics_TrendSet(trend, sessionStartEpoch, nowEpoch, value)
;-------------------------------------------------------------------------------
Metrics_NewTrend() {
    arr := []
    Loop, % METRICS_TREND_BINS
        arr.Push(0)
    return arr
}

;-------------------------------------------------------------------------------
; Sliding window model:
;   bin[N] is the most recent 30-min slot (where "now" is)
;   bin[N-1] is 30-60 min ago, ..., bin[1] is 5.5h-6h ago
; All new events go into bin[N]. Time advancement is handled by
; Metrics_AdvanceTrend(trend, shifts), which drops bin[1] and appends a 0
; `shifts` times. Returns nothing (mutates in place).
;-------------------------------------------------------------------------------
Metrics_LatestBinIndex() {
    return METRICS_TREND_BINS
}

Metrics_AdvanceTrend(trend, shifts) {
    if (shifts <= 0)
        return
    if (shifts > METRICS_TREND_BINS) {
        Loop, % METRICS_TREND_BINS
            trend[A_Index] := 0
        return
    }
    Loop, % shifts {
        trend.RemoveAt(1)
        trend.Push(0)
    }
}

Metrics_TrendIncrement(trend, binIndex, amount := 1) {
    if (binIndex < 1 || binIndex > trend.Length())
        return
    trend[binIndex] := trend[binIndex] + amount
}

;-------------------------------------------------------------------------------
; Sparkline rendering (Unicode block characters)
;-------------------------------------------------------------------------------
Metrics_Sparkline(values) {
    ; Use Chr() so that this source file is pure ASCII and AHK 1.1 reads it
    ; correctly regardless of file encoding (default is Windows-1252).
    chars := [Chr(0x2581), Chr(0x2582), Chr(0x2583), Chr(0x2584)
            , Chr(0x2585), Chr(0x2586), Chr(0x2587), Chr(0x2588)]
    n := values.Length()
    if (n = 0)
        return ""

    maxV := 0
    Loop, % n {
        v := values[A_Index] + 0
        if (v > maxV)
            maxV := v
    }

    out := ""
    Loop, % n {
        v := values[A_Index] + 0
        if (maxV <= 0) {
            out .= chars[1]
        } else {
            idx := Floor(v / maxV * 7) + 1
            if (idx < 1)
                idx := 1
            if (idx > 8)
                idx := 8
            out .= chars[idx]
        }
    }
    return out
}

;-------------------------------------------------------------------------------
; CSV helper for storing arrays in INI values
;-------------------------------------------------------------------------------
Metrics_ArrayToCsv(arr) {
    out := ""
    Loop, % arr.Length() {
        if (A_Index > 1)
            out .= ","
        out .= arr[A_Index]
    }
    return out
}

Metrics_CsvToArray(csv) {
    out := []
    Loop, Parse, csv, `,
        out.Push(Trim(A_LoopField) + 0)
    return out
}

;-------------------------------------------------------------------------------
; Pretty-format helpers
;-------------------------------------------------------------------------------
Metrics_FormatDurationHM(seconds) {
    if (seconds <= 0)
        return "0m"
    d := seconds // 86400
    rest := seconds - d * 86400
    h := rest // 3600
    m := (rest - h * 3600) // 60
    if (d > 0)
        return d . "d " . h . "h " . m . "m"
    if (h > 0 && m > 0)
        return h . "h " . m . "m"
    if (h > 0)
        return h . "h"
    return m . "m"
}

; Injection Queue-style countdown: units zero-padded, e.g. "05h 03m 12s", "01d 03h 00m 09s"
Metrics_FormatDurationHMSecs(seconds) {
    if (seconds < 0)
        seconds := 0
    d := seconds // 86400
    rest := seconds - d * 86400
    h := rest // 3600
    rest := rest - h * 3600
    m := rest // 60
    s := rest - m * 60
    if (d > 0)
        return Format("{:02}", d) . "d " . Format("{:02}", h) . "h " . Format("{:02}", m) . "m " . Format("{:02}", s) . "s"
    return Format("{:02}", h) . "h " . Format("{:02}", m) . "m " . Format("{:02}", s) . "s"
}

Metrics_FormatDurationMS(seconds) {
    if (seconds < 0)
        seconds := 0
    m := seconds // 60
    s := seconds - m * 60
    return Format("{:02}", m) . ":" . Format("{:02}", s)
}

; Instance Average column: padded minutes + seconds with unit suffix, e.g. "05m 07s".
Metrics_FormatDurationMmSs(seconds) {
    if (seconds < 0)
        seconds := 0
    m := seconds // 60
    s := seconds - m * 60
    return Format("{:02}", m) . "m " . Format("{:02}", s) . "s"
}

Metrics_FormatDurationHMS(seconds) {
    if (seconds < 0)
        seconds := 0
    h := seconds // 3600
    rest := seconds - h * 3600
    m := rest // 60
    s := rest - m * 60
    return Format("{:02}", h) . ":" . Format("{:02}", m) . ":" . Format("{:02}", s)
}
