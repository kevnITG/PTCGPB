;===============================================================================
; Wishlist.ahk - Bot-side wishlist support
;===============================================================================
; Reads Accounts\Cards\wishlist.json (written by the dashboard server), keeps it
; cached in session under "wishlistMap" (cardId -> resolved card name), and
; reloads transparently when the file changes. Used by CheckPack to flag pack
; openings that contain wishlisted cards.
;===============================================================================

Wishlist_Path() {
    return getScriptBaseFolder() . "\Accounts\Cards\wishlist.json"
}

; Public: ensure session has the latest wishlist loaded. Call before each pack
; evaluation. Cheap: only re-reads the file if its mtime changed.
Wishlist_EnsureFresh() {
    global session

    path := Wishlist_Path()
    if (!FileExist(path)) {
        if (session.get("wishlistMap") = "" || !IsObject(session.get("wishlistMap")))
            session.set("wishlistMap", {})
        session.set("wishlistMtime", "")
        return
    }

    FileGetTime, mtime, %path%, M
    if (session.get("wishlistMtime") = mtime && IsObject(session.get("wishlistMap")))
        return

    FileRead, jsonText, %path%
    session.set("wishlistMap", Wishlist_Parse(jsonText))
    session.set("wishlistMtime", mtime)
}

; Returns a map { cardId => name } from the wishlist JSON. Tolerant: malformed
; JSON yields an empty map (bot keeps running).
Wishlist_Parse(jsonText) {
    result := {}
    if (Trim(jsonText) = "")
        return result

    arrayBody := Wishlist_ExtractArrayBody(jsonText, "cards")
    if (arrayBody = "")
        return result

    pos := 1
    Loop {
        entryStart := InStr(arrayBody, "{", false, pos)
        if (!entryStart)
            break
        entryEnd := Wishlist_FindMatchingBrace(arrayBody, entryStart)
        if (!entryEnd)
            break
        entry := SubStr(arrayBody, entryStart, entryEnd - entryStart + 1)

        cardId := Wishlist_ExtractStringValue(entry, "id")
        cardName := Wishlist_ExtractStringValue(entry, "name")
        if (cardId != "")
            result[cardId] := cardName

        pos := entryEnd + 1
    }

    return result
}

; Count how many entries in cards[] (cardId array from the pack) are present in
; the wishlist map.
Wishlist_CountMatches(cards, wishlistMap) {
    if (!IsObject(cards) || !IsObject(wishlistMap))
        return 0
    count := 0
    For _, cardId in cards {
        if (wishlistMap.HasKey(cardId))
            count++
    }
    return count
}

; Return [{id, name}, ...] for every wishlist match in the pack, preserving
; pack-slot order and counting duplicates.
Wishlist_MatchEntries(cards, wishlistMap) {
    matches := []
    if (!IsObject(cards) || !IsObject(wishlistMap))
        return matches
    For _, cardId in cards {
        if (wishlistMap.HasKey(cardId)) {
            name := wishlistMap[cardId]
            if (name = "")
                name := cardId
            matches.Push({ id: cardId, name: name })
        }
    }
    return matches
}

; Return the cardId array out of a match entries list (for highlight passing).
Wishlist_MatchIds(matches) {
    ids := []
    if (!IsObject(matches))
        return ids
    For _, m in matches
        ids.Push(m.id)
    return ids
}

; Render the match list inline (comma-separated names). Empty matches => "".
Wishlist_FormatNames(matches) {
    if (!IsObject(matches) || matches.MaxIndex() = "")
        return ""
    out := ""
    For _, m in matches {
        if (out != "")
            out .= ", "
        out .= m.name
    }
    return out
}

; --- JSON helpers (scoped to this module to keep wishlist self-contained) ---

Wishlist_ExtractArrayBody(ByRef jsonText, key) {
    keyPos := InStr(jsonText, """" . key . """")
    if (!keyPos)
        return ""
    bracketPos := InStr(jsonText, "[", false, keyPos)
    if (!bracketPos)
        return ""

    depth := 0
    inString := false
    escaped := false
    len := StrLen(jsonText)

    Loop, % len - bracketPos + 1 {
        idx := bracketPos + A_Index - 1
        ch := SubStr(jsonText, idx, 1)

        if (inString) {
            if (escaped) {
                escaped := false
            } else if (ch = "\") {
                escaped := true
            } else if (ch = """") {
                inString := false
            }
            continue
        }

        if (ch = """") {
            inString := true
        } else if (ch = "[") {
            depth++
        } else if (ch = "]") {
            depth--
            if (depth = 0)
                return SubStr(jsonText, bracketPos + 1, idx - bracketPos - 1)
        }
    }
    return ""
}

Wishlist_FindMatchingBrace(ByRef text, bracePos) {
    if (!bracePos || SubStr(text, bracePos, 1) != "{")
        return 0

    depth := 0
    inString := false
    escaped := false
    len := StrLen(text)

    Loop, % len - bracePos + 1 {
        idx := bracePos + A_Index - 1
        ch := SubStr(text, idx, 1)

        if (inString) {
            if (escaped) {
                escaped := false
            } else if (ch = "\") {
                escaped := true
            } else if (ch = """") {
                inString := false
            }
            continue
        }

        if (ch = """") {
            inString := true
        } else if (ch = "{") {
            depth++
        } else if (ch = "}") {
            depth--
            if (depth = 0)
                return idx
        }
    }
    return 0
}

Wishlist_ExtractStringValue(ByRef text, key) {
    pattern := "s)""" . key . """\s*:\s*""((?:[^""\\]|\\.)*)"""
    if (!RegExMatch(text, pattern, m))
        return ""
    return Wishlist_Unescape(m1)
}

Wishlist_Unescape(s) {
    s := StrReplace(s, "\""", """")
    s := StrReplace(s, "\\", "\")
    s := StrReplace(s, "\/", "/")
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\r", "`r")
    s := StrReplace(s, "\t", "`t")
    return s
}
