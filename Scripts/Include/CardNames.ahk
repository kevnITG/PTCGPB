;===============================================================================
; CardNames.ahk - Card name + rarity emoji resolution for Discord webhooks
;===============================================================================
; Resolves cardId -> English name using Helper\cardmaster.json + Helper\en_US.json
; (same data the dashboard uses). The full cardId -> name map is parsed once on
; first lookup and cached in session under "cardNameMap" for the rest of the run.
; Also owns the bot-rarity emoji table used in Discord messages.
;===============================================================================

CardName_CardmasterUrl() {
    return "https://leanny.github.io/pocket_tcg_resources/data/cardmaster.json"
}

CardName_LocalisationUrl() {
    return "https://leanny.github.io/pocket_tcg_resources/data/en_US.json"
}

CardName_CardmasterPath() {
    return getScriptBaseFolder() . "\Helper\cardmaster.json"
}

CardName_LocalisationPath() {
    return getScriptBaseFolder() . "\Helper\en_US.json"
}

; Download JSON into Helper\ when missing (same sources as the card dashboard).
CardName_DownloadIfMissing(localPath, url) {
    if (FileExist(localPath))
        return true

    SplitPath, localPath, , destDir
    if (destDir != "" && !FileExist(destDir))
        FileCreateDir, %destDir%

    text := ""
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
        RegRead, proxyServer, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyServer
        if (proxyEnabled)
            whr.SetProxy(2, proxyServer)
        whr.Open("GET", url, true)
        whr.Send()
        whr.WaitForResponse()
        if (whr.Status != 200)
            return false
        text := whr.ResponseText
    } catch {
        return false
    }

    if (text = "" || SubStr(LTrim(text, " `t`r`n"), 1, 1) != "{")
        return false

    FileDelete, %localPath%
    FileAppend, %text%, %localPath%, UTF-8
    return FileExist(localPath)
}

CardName_EnsureLoaded() {
    global session
    if (IsObject(session.get("cardNameMap")))
        return

    nameMap := {}
    cardmasterPath := CardName_CardmasterPath()
    localePath     := CardName_LocalisationPath()

    CardName_DownloadIfMissing(cardmasterPath, CardName_CardmasterUrl())
    CardName_DownloadIfMissing(localePath, CardName_LocalisationUrl())

    if (!FileExist(cardmasterPath) || !FileExist(localePath)) {
        session.set("cardNameMap", nameMap)
        return
    }

    FileRead, cardmasterJson, %cardmasterPath%
    FileRead, localeJson, %localePath%

    locale := CardName_ParseLocale(localeJson)
    CardName_ParseCardmaster(cardmasterJson, locale, nameMap)

    session.set("cardNameMap", nameMap)
}

CardName_Get(cardId) {
    CardName_EnsureLoaded()
    global session
    nameMap := session.get("cardNameMap")
    if (IsObject(nameMap) && nameMap.HasKey(cardId)) {
        n := nameMap[cardId]
        if (n != "")
            return n
    }
    return cardId
}

CardName_ParseLocale(ByRef jsonText) {
    result := {}
    pos := 1
    pattern := "O)""([^""]+)""\s*:\s*""((?:[^""\\]|\\.)*)"""
    while (foundPos := RegExMatch(jsonText, pattern, m, pos)) {
        result[m.Value(1)] := CardName_Unescape(m.Value(2))
        pos := foundPos + m.Len(0)
    }
    return result
}

; Each card entry in cardmaster has flat fields (no nested objects), so the
; lazy `[^}]*?` body match never crosses an object boundary.
CardName_ParseCardmaster(ByRef jsonText, locale, ByRef out) {
    pos := 1
    pattern := "sO)""([A-Za-z0-9_]+)""\s*:\s*\{[^}]*?""Name""\s*:\s*""([^""]+)"""
    while (foundPos := RegExMatch(jsonText, pattern, m, pos)) {
        cardId  := m.Value(1)
        nameKey := m.Value(2)
        out[cardId] := locale.HasKey(nameKey) ? locale[nameKey] : nameKey
        pos := foundPos + m.Len(0)
    }
}

CardName_Unescape(s) {
    s := StrReplace(s, "\""", """")
    s := StrReplace(s, "\\", "\")
    s := StrReplace(s, "\/", "/")
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\r", "`r")
    s := StrReplace(s, "\t", "`t")
    s := CardName_DecodeUnicodeEscapes(s)
    return s
}

CardName_DecodeUnicodeEscapes(s) {
    out := ""
    pos := 1
    len := StrLen(s)
    while (pos <= len) {
        if (SubStr(s, pos, 2) = "\u" && pos + 5 <= len) {
            hex := SubStr(s, pos + 2, 4)
            if (RegExMatch(hex, "^[0-9A-Fa-f]{4}$")) {
                out .= Chr("0x" hex)
                pos += 6
                continue
            }
        }
        out .= SubStr(s, pos, 1)
        pos++
    }
    return out
}

;--- Rarity -> emoji + labels ---

CardName_TypeKeyFor(r, cardId) {
    if (r = 1)
        return "1Diamond"
    if (r = 2)
        return "2Diamond"
    if (r = 3)
        return "3Diamond"
    if (r = 4)
        return "4Diamond"
    if (r = 5) {
        prefix := SubStr(cardId, 1, 3)
        if (prefix = "TR_")
            return "Trainer"
        if (prefix = "PK_")
            return "FullArt"
        return ""
    }
    if (r = 7)
        return "1Star"
    if (r = 8)
        return "Rainbow"
    if (r = 9)
        return "Immersive"
    if (r = 10)
        return "Crown"
    if (r = 11)
        return "Shiny1Star"
    if (r = 12)
        return "Shiny2Star"
    return ""
}

CardName_TypeLabel(typeKey) {
    if (typeKey = "1Diamond")
        return "1 Diamond"
    if (typeKey = "2Diamond")
        return "2 Diamond"
    if (typeKey = "3Diamond")
        return "3 Diamond"
    if (typeKey = "4Diamond")
        return "4 Diamond EX"
    if (typeKey = "1Star")
        return "1 Star"
    if (typeKey = "Trainer")
        return "Trainer"
    if (typeKey = "FullArt")
        return "Full Art"
    if (typeKey = "Rainbow")
        return "Rainbow"
    if (typeKey = "Immersive")
        return "Immersive"
    if (typeKey = "Crown")
        return "Crown"
    if (typeKey = "Shiny1Star")
        return "Shiny 1-Star"
    if (typeKey = "Shiny2Star")
        return "Shiny 2-Star"
    return typeKey
}

CardName_RepeatToken(token, count) {
    out := ""
    Loop, %count% {
        if (out != "")
            out .= " "
        out .= token
    }
    return out
}

CardName_TypeEmoji(typeKey) {
    blueDiamond := Chr(0x1F539)
    star        := Chr(0x2B50)
    trainer     := Chr(0x1F393)
    palette     := Chr(0x1F3A8)
    rainbow     := Chr(0x1F308)
    immersive   := Chr(0x1F3AC)
    crown       := Chr(0x1F451)
    sparkle     := Chr(0x2728)
    if (typeKey = "1Diamond")
        return blueDiamond
    if (typeKey = "2Diamond")
        return CardName_RepeatToken(blueDiamond, 2)
    if (typeKey = "3Diamond")
        return CardName_RepeatToken(blueDiamond, 3)
    if (typeKey = "4Diamond")
        return CardName_RepeatToken(blueDiamond, 4)
    if (typeKey = "1Star")
        return star
    if (typeKey = "Trainer")
        return trainer
    if (typeKey = "FullArt")
        return palette
    if (typeKey = "Rainbow")
        return rainbow
    if (typeKey = "Immersive")
        return immersive
    if (typeKey = "Crown")
        return crown
    if (typeKey = "Shiny1Star")
        return sparkle
    if (typeKey = "Shiny2Star")
        return CardName_RepeatToken(sparkle, 2)
    return ""
}

; Builds the rarity/card-name section for a Discord webhook as grouped Markdown.
; Returns "" if nothing to show. When
; cards/rarity aren't available (legacy callers) falls back to a count-only line
; such as `emoji · **3 Diamond**` followed by `(x2)`.
CardName_BuildFoundBlock(cards, rarity, foundCards) {
    static typeOrder := ["1Diamond","2Diamond","3Diamond","4Diamond","1Star","Trainer","FullArt","Rainbow","Immersive","Crown","Shiny1Star","Shiny2Star"]

    if (!IsObject(foundCards))
        return ""

    hasCards := IsObject(cards) && IsObject(rarity) && cards.MaxIndex() > 0

    buckets := {}
    if (hasCards) {
        total := cards.MaxIndex()
        Loop, % total {
            i := A_Index
            r := rarity[i] + 0
            c := cards[i]
            key := CardName_TypeKeyFor(r, c)
            if (key = "" || !foundCards.HasKey(key) || foundCards[key] <= 0)
                continue
            if (!buckets.HasKey(key))
                buckets[key] := []
            buckets[key].Push(c)
        }
    }

    activeTypes := []
    For _, t in typeOrder {
        if (foundCards.HasKey(t) && foundCards[t] > 0)
            activeTypes.Push(t)
    }
    if (activeTypes.MaxIndex() = "")
        return ""

    if (hasCards)
        CardName_EnsureLoaded()

    lines := ""
    separator := " " . Chr(0x203A) . "  "
    For _, t in activeTypes {
        emoji := CardName_TypeEmoji(t)
        label := CardName_TypeLabel(t)

        rightSide := ""
        if (hasCards && buckets.HasKey(t)) {
            counts := {}
            orderedIds := []
            For _, id in buckets[t] {
                if (!counts.HasKey(id)) {
                    counts[id] := 0
                    orderedIds.Push(id)
                }
                counts[id] += 1
            }
            For _, id in orderedIds {
                if (rightSide != "")
                    rightSide .= ", "
                cardText := CardName_Get(id)
                if (counts[id] > 1)
                    cardText .= " (x" . counts[id] . ")"
                rightSide .= cardText
            }
        } else {
            rightSide := "(x" . foundCards[t] . ")"
        }
        if (rightSide = "")
            rightSide := "(x" . foundCards[t] . ")"

        if (lines != "")
            lines .= "\n\n"
        lines .= emoji . separator . "**" . label . "**\n" . rightSide
    }

    return lines
}
