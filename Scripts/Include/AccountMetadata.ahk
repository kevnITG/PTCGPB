;===============================================================================
; AccountMetadata.ahk - File-backed account metadata store
;===============================================================================
; Stores account metadata in Accounts\Cards\accounts\<deviceAccount>.json.
;===============================================================================

AccountMetadata_Path() {
    return getScriptBaseFolder() . "\Accounts\Cards\metadata.json"
}

AccountMetadata_AccountDir() {
    return getScriptBaseFolder() . "\Accounts\Cards\accounts"
}

AccountMetadata_AccountPath(deviceAccount) {
    safeName := RegExReplace(deviceAccount, "[\\/:*?""<>|]", "_")
    return AccountMetadata_AccountDir() . "\" . safeName . ".json"
}

AccountMetadata_AccountHasPulls(deviceAccount) {
    if (deviceAccount = "")
        return false

    path := AccountMetadata_AccountPath(deviceAccount)
    if (!FileExist(path))
        return false

    FileRead, jsonText, %path%
    pullsJson := AccountMetadata_ExtractArrayValue(jsonText, "pulls")
    pullsJson := RegExReplace(Trim(pullsJson), "\s")
    return pullsJson != "" && pullsJson != "[]"
}

AccountMetadata_FormatAccount(deviceAccount) {
    if (deviceAccount = "")
        return false
    helperPath := AccountMetadata_HelperPath()
    if (!FileExist(helperPath))
        return false
    root := getScriptBaseFolder()
    RunWait, % """" . helperPath . """ --root """ . root . """ format-account --device-account """ . deviceAccount . """",, Hide
    return !ErrorLevel
}

AccountMetadata_TempDir() {
    return AccountMetadata_AccountDir()
}

AccountMetadata_HelperPath() {
    return getScriptBaseFolder() . "\Helper\carddb.exe"
}

AccountMetadata_CurrentInstance() {
    global session

    if (IsObject(session) && session.get("scriptName") != "")
        return session.get("scriptName")

    SplitPath, A_ScriptName,,,, nameNoExt
    return nameNoExt
}

AccountMetadata_CurrentDeviceAccount() {
    global session

    if (IsObject(session) && session.get("deviceAccount") != "")
        return session.get("deviceAccount")

    return ""
}

AccountMetadata_UseTempWrites() {
    return RegExMatch(A_ScriptName, "i)^\d+\.ahk$")
}

AccountMetadata_MigrateOldStore(path) {
    if (FileExist(path))
        return

    oldPaths := []
    oldPaths.Push(getScriptBaseFolder() . "\Accounts\Saved\metadata.json")
    oldPaths.Push(getScriptBaseFolder() . "\Accounts\Saved\tmp\metadata.json")

    Loop, % oldPaths.MaxIndex() {
        oldPath := oldPaths[A_Index]
        if (FileExist(oldPath)) {
            SplitPath, path,, dir
            if (!FileExist(dir))
                FileCreateDir, %dir%
            FileCopy, %oldPath%, %path%, 1
            return
        }
    }
}

AccountMetadata_Now() {
    return A_Now
}

AccountMetadata_Key(instance, fileName) {
    return "legacy:" . instance . "/" . fileName
}

AccountMetadata_DeviceKey(deviceAccount) {
    return deviceAccount
}

AccountMetadata_DeviceFromKey(key) {
    if (SubStr(key, 1, 14) = "deviceAccount:")
        return SubStr(key, 15)
    if (SubStr(key, 1, 7) = "legacy:")
        return ""
    return key
}

AccountMetadata_GetDeviceAccountFromFile(filePath) {
    if (filePath = "" || !FileExist(filePath))
        return ""

    FileRead, xmlContent, %filePath%
    if (RegExMatch(xmlContent, "i)<string name=""deviceAccount"">([^<]+)</string>", match))
        return match1

    return ""
}

AccountMetadata_Escape(value) {
    quote := Chr(34)
    slash := Chr(92)
    value := StrReplace(value, slash, slash . slash)
    value := StrReplace(value, quote, slash . quote)
    value := StrReplace(value, "`r", "\r")
    value := StrReplace(value, "`n", "\n")
    value := StrReplace(value, "`t", "\t")
    return value
}

AccountMetadata_Unescape(value) {
    quote := Chr(34)
    slash := Chr(92)
    value := StrReplace(value, "\t", "`t")
    value := StrReplace(value, "\n", "`n")
    value := StrReplace(value, "\r", "`r")
    value := StrReplace(value, slash . quote, quote)
    value := StrReplace(value, slash . slash, slash)
    return value
}

AccountMetadata_Bool(value) {
    return value ? "true" : "false"
}

AccountMetadata_AcquireLock(timeoutMs := 10000) {
    lockName := "Global\PTCGPB_AccountMetadata"
    hMutex := DllCall("CreateMutex", "Ptr", 0, "Int", false, "Str", lockName, "Ptr")
    if (!hMutex)
        return 0

    waitResult := DllCall("WaitForSingleObject", "Ptr", hMutex, "UInt", timeoutMs, "UInt")
    ; WAIT_OBJECT_0 = 0, WAIT_ABANDONED = 0x80
    if (waitResult != 0 && waitResult != 0x80) {
        DllCall("CloseHandle", "Ptr", hMutex)
        return 0
    }
    return hMutex
}

AccountMetadata_ReleaseLock(hMutex) {
    if (!hMutex)
        return
    DllCall("ReleaseMutex", "Ptr", hMutex)
    DllCall("CloseHandle", "Ptr", hMutex)
}

AccountMetadata_NewStore() {
    return {"accounts": {}}
}

AccountMetadata_NewFlag(value := 0, setAt := "", validUntil := "") {
    return {"value": value ? 1 : 0, "setAt": setAt, "validUntil": validUntil}
}

AccountMetadata_NewShinedust(value := -1, lastUpdatedAt := "0") {
    if (value = "")
        value := -1
    if (lastUpdatedAt = "")
        lastUpdatedAt := "0"
    return {"value": value + 0, "lastUpdatedAt": lastUpdatedAt}
}

AccountMetadata_NormalizeShinedust(shinedust) {
    if (IsObject(shinedust))
        return AccountMetadata_NewShinedust(shinedust["value"], shinedust["lastUpdatedAt"])

    return AccountMetadata_NewShinedust(shinedust, "0")
}

AccountMetadata_NormalizeCreatedAt(value) {
    value := Trim(value)
    if (RegExMatch(value, "^\d{14}$"))
        return value
    if (RegExMatch(value, "^\d{9,12}$")) {
        createdAt := "19700101000000"
        EnvAdd, createdAt, %value%, Seconds
        return createdAt
    }
    return value
}

AccountMetadata_NewAccount(instance, fileName) {
    account := {}
    account["deviceAccount"] := ""
    account["instance"] := instance
    account["fileName"] := fileName
    account["accountName"] := ""
    account["friendCode"] := ""
    account["packCount"] := 0
    account["createdAt"] := "0"
    account["lastPackPulled"] := 0
    account["lastLoggedIn"] := "0"
    account["shinedust"] := AccountMetadata_NewShinedust()
    account["flags"] := {}

    flags := ["B", "X", "T", "R", "W", "H", "SH"]
    Loop, % flags.MaxIndex()
        account["flags"][flags[A_Index]] := AccountMetadata_NewFlag(0)

    return account
}

AccountMetadata_ExtractPackCount(fileName) {
    return 0
}

AccountMetadata_ExtractCreatedAt(fileName) {
    if (RegExMatch(fileName, "^\d+P_(\d{14})_", match))
        return match1
    return "0"
}

AccountMetadata_ReadStoreUnlocked() {
    path := AccountMetadata_Path()
    AccountMetadata_MigrateOldStore(path)
    if (!FileExist(path))
        return AccountMetadata_NewStore()

    FileRead, jsonText, %path%
    if (Trim(jsonText) = "")
        return AccountMetadata_NewStore()

    return AccountMetadata_ParseStore(jsonText)
}

AccountMetadata_WriteStoreUnlocked(store) {
    path := AccountMetadata_Path()
    SplitPath, path,, dir
    if (!FileExist(dir))
        FileCreateDir, %dir%

    tempPath := path . ".tmp"
    jsonText := AccountMetadata_SerializeStore(store)

    if FileExist(tempPath)
        FileDelete, %tempPath%
    FileAppend, %jsonText%, %tempPath%, UTF-8
    FileMove, %tempPath%, %path%, 1
}

AccountMetadata_ReadAccountUnlocked(deviceAccount, instance := "", fileName := "") {
    if (deviceAccount = "")
        return AccountMetadata_NewAccount(instance, fileName)

    path := AccountMetadata_AccountPath(deviceAccount)
    if (!FileExist(path))
        return AccountMetadata_NewAccount(instance, fileName)

    FileRead, jsonText, %path%
    metadataJson := AccountMetadata_ExtractObjectValue(jsonText, "metadata")
    if (metadataJson = "")
        account := AccountMetadata_NewAccount(instance, fileName)
    else
        account := AccountMetadata_ParseAccount(metadataJson)

    account["deviceAccount"] := deviceAccount
    if (account["instance"] = "" && instance != "")
        account["instance"] := instance
    if (account["fileName"] = "" && fileName != "")
        account["fileName"] := fileName
    return account
}

AccountMetadata_WriteAccountUnlocked(deviceAccount, account) {
    if (deviceAccount = "")
        deviceAccount := account["deviceAccount"]
    if (deviceAccount = "")
        return false

    path := AccountMetadata_AccountPath(deviceAccount)
    SplitPath, path,, dir
    if (!FileExist(dir))
        FileCreateDir, %dir%

    pullsJson := "[]"
    registeredCardsJson := "[]"
    if (FileExist(path)) {
        FileRead, oldJson, %path%
        pullsJson := AccountMetadata_ExtractArrayValue(oldJson, "pulls")
        if (pullsJson = "")
            pullsJson := "[]"
        registeredCardsJson := AccountMetadata_ExtractArrayValue(oldJson, "registeredCards")
        if (registeredCardsJson = "")
            registeredCardsJson := "[]"
    }

    tempPath := path . ".tmp"
    jsonText := "{`r`n"
    jsonText .= "  ""deviceAccount"": """ . AccountMetadata_Escape(deviceAccount) . """,`r`n"
    jsonText .= "  ""metadata"": " . AccountMetadata_SerializeAccount(account) . ",`r`n"
    jsonText .= "  ""pulls"": " . pullsJson . ",`r`n"
    jsonText .= "  ""registeredCards"": " . registeredCardsJson . "`r`n"
    jsonText .= "}`r`n"

    if FileExist(tempPath)
        FileDelete, %tempPath%
    FileAppend, %jsonText%, %tempPath%, UTF-8
    FileMove, %tempPath%, %path%, 1
    if (!ErrorLevel)
        AccountMetadata_FormatAccount(deviceAccount)
    return !ErrorLevel
}

AccountMetadata_ReadTempStoreUnlocked(instance := "", deviceAccount := "") {
    store := AccountMetadata_NewStore()
    account := AccountMetadata_ReadAccountUnlocked(deviceAccount, instance, "")
    key := deviceAccount != "" ? AccountMetadata_DeviceKey(deviceAccount) : AccountMetadata_Key(instance, account["fileName"])
    store["accounts"][key] := account
    return store
}

AccountMetadata_WriteTempStoreUnlocked(store, instance := "", deviceAccount := "") {
    for key, account in store["accounts"] {
        targetDevice := account["deviceAccount"] != "" ? account["deviceAccount"] : AccountMetadata_DeviceFromKey(key)
        if (targetDevice != "")
            AccountMetadata_WriteAccountUnlocked(targetDevice, account)
    }
}

AccountMetadata_ParseStore(jsonText) {
    store := AccountMetadata_NewStore()
    accountsPos := InStr(jsonText, """accounts""")
    if (!accountsPos)
        return store

    accountsBrace := InStr(jsonText, "{", false, accountsPos)
    accountsBody := AccountMetadata_ExtractObjectBody(jsonText, accountsBrace)
    if (accountsBody = "")
        return store

    pos := 1
    while (RegExMatch(accountsBody, "s)""((?:[^""\\]|\\.)*)""\s*:", keyMatch, pos)) {
        key := AccountMetadata_Unescape(keyMatch1)
        valueStart := InStr(accountsBody, "{", false, pos + StrLen(keyMatch))
        if (!valueStart)
            break

        accountJson := "{" . AccountMetadata_ExtractObjectBody(accountsBody, valueStart) . "}"
        if (accountJson = "{}")
            break

        store["accounts"][key] := AccountMetadata_ParseAccount(accountJson)
        if (store["accounts"][key]["deviceAccount"] = "")
            store["accounts"][key]["deviceAccount"] := AccountMetadata_DeviceFromKey(key)
        pos := valueStart + StrLen(accountJson)
    }

    return store
}

AccountMetadata_ExtractObjectBody(ByRef text, bracePos) {
    if (!bracePos || SubStr(text, bracePos, 1) != "{")
        return ""

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
                return SubStr(text, bracePos + 1, idx - bracePos - 1)
        }
    }

    return ""
}

AccountMetadata_ExtractArrayBody(ByRef text, bracketPos) {
    if (!bracketPos || SubStr(text, bracketPos, 1) != "[")
        return ""

    depth := 0
    inString := false
    escaped := false
    len := StrLen(text)

    Loop, % len - bracketPos + 1 {
        idx := bracketPos + A_Index - 1
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
        } else if (ch = "[") {
            depth++
        } else if (ch = "]") {
            depth--
            if (depth = 0)
                return SubStr(text, bracketPos + 1, idx - bracketPos - 1)
        }
    }

    return ""
}

AccountMetadata_ExtractObjectValue(ByRef jsonText, key) {
    keyPos := InStr(jsonText, """" . key . """")
    objStart := keyPos ? InStr(jsonText, "{", false, keyPos) : 0
    if (!objStart)
        return ""
    return "{" . AccountMetadata_ExtractObjectBody(jsonText, objStart) . "}"
}

AccountMetadata_ExtractArrayValue(ByRef jsonText, key) {
    keyPos := InStr(jsonText, """" . key . """")
    arrStart := keyPos ? InStr(jsonText, "[", false, keyPos) : 0
    if (!arrStart)
        return "[]"
    return "[" . AccountMetadata_ExtractArrayBody(jsonText, arrStart) . "]"
}

AccountMetadata_ParseString(json, key, defaultValue := "") {
    pattern := "s)""" . key . """\s*:\s*""((?:[^""\\]|\\.)*)"""
    if (RegExMatch(json, pattern, match))
        return AccountMetadata_Unescape(match1)
    return defaultValue
}

AccountMetadata_ParseNumber(json, key, defaultValue := 0) {
    pattern := "s)""" . key . """\s*:\s*(-?\d+)"
    if (RegExMatch(json, pattern, match))
        return match1 + 0
    return defaultValue
}

AccountMetadata_ParseBool(json, key, defaultValue := 0) {
    pattern := "s)""" . key . """\s*:\s*(true|false|1|0)"
    if (RegExMatch(json, pattern, match))
        return (match1 = "true" || match1 = "1") ? 1 : 0
    return defaultValue
}

AccountMetadata_ParseAccount(accountJson) {
    account := AccountMetadata_NewAccount(AccountMetadata_ParseString(accountJson, "instance"), AccountMetadata_ParseString(accountJson, "fileName"))
    account["deviceAccount"] := AccountMetadata_ParseString(accountJson, "deviceAccount")
    account["accountName"] := AccountMetadata_ParseString(accountJson, "accountName")
    if (account["accountName"] = "")
        account["accountName"] := AccountMetadata_ParseString(accountJson, "name")
    account["friendCode"] := AccountMetadata_ParseString(accountJson, "friendCode")
    account["packCount"] := AccountMetadata_ParseNumber(accountJson, "packCount", account["packCount"])
    account["createdAt"] := AccountMetadata_NormalizeCreatedAt(AccountMetadata_ParseString(accountJson, "createdAt", AccountMetadata_ParseNumber(accountJson, "createdAt", account["createdAt"])))
    account["lastPackPulled"] := AccountMetadata_ParseString(accountJson, "lastPackPulled", AccountMetadata_ParseNumber(accountJson, "lastPackPulled", 0))
    if (account["lastPackPulled"] = "" || account["lastPackPulled"] = "0")
        account["lastPackPulled"] := AccountMetadata_ParseString(accountJson, "lastModified", account["lastPackPulled"])
    account["lastLoggedIn"] := AccountMetadata_ParseString(accountJson, "lastLoggedIn", AccountMetadata_ParseNumber(accountJson, "lastLoggedIn", 0))

    shinedustPos := InStr(accountJson, """shinedust""")
    shinedustBrace := shinedustPos ? InStr(accountJson, "{", false, shinedustPos) : 0
    if (shinedustBrace) {
        shinedustBody := AccountMetadata_ExtractObjectBody(accountJson, shinedustBrace)
        shinedustJson := "{" . shinedustBody . "}"
        account["shinedust"] := AccountMetadata_NewShinedust(AccountMetadata_ParseNumber(shinedustJson, "value", AccountMetadata_ParseString(shinedustJson, "value", -1)), AccountMetadata_ParseString(shinedustJson, "lastUpdatedAt", "0"))
    } else {
        account["shinedust"] := AccountMetadata_NewShinedust(AccountMetadata_ParseNumber(accountJson, "shinedust", -1), "0")
    }

    flagsPos := InStr(accountJson, """flags""")
    flagsBrace := flagsPos ? InStr(accountJson, "{", false, flagsPos) : 0
    flagsBody := AccountMetadata_ExtractObjectBody(accountJson, flagsBrace)
    if (flagsBody != "") {
        flags := ["B", "X", "T", "R", "W", "H", "SH"]
        Loop, % flags.MaxIndex() {
            flag := flags[A_Index]
            flagPos := InStr(flagsBody, """" . flag . """")
            flagBrace := flagPos ? InStr(flagsBody, "{", false, flagPos) : 0
            flagBody := AccountMetadata_ExtractObjectBody(flagsBody, flagBrace)
            if (flagBody != "") {
                flagJson := "{" . flagBody . "}"
                account["flags"][flag] := AccountMetadata_NewFlag(AccountMetadata_ParseBool(flagJson, "value"), AccountMetadata_ParseString(flagJson, "setAt"), AccountMetadata_ParseString(flagJson, "validUntil"))
            }
        }
    }

    return account
}

AccountMetadata_SerializeStore(store) {
    json := "{`r`n"
    json .= "  ""accounts"": {"

    firstAccount := true
    for key, account in store["accounts"] {
        if (SubStr(key, 1, 14) = "deviceAccount:")
            key := SubStr(key, 15)
        if (!firstAccount)
            json .= ","
        json .= "`r`n    """ . AccountMetadata_Escape(key) . """: " . AccountMetadata_SerializeAccount(account)
        firstAccount := false
    }

    if (!firstAccount)
        json .= "`r`n  "
    json .= "}`r`n"
    json .= "}`r`n"
    return json
}

AccountMetadata_SerializeAccount(account, indent := "") {
    flags := ["B", "X", "T", "R", "W", "H", "SH"]
    json := "{`r`n"
    firstField := true

    if (account["instance"] != "")
        AccountMetadata_AppendJsonString(json, firstField, "instance", account["instance"], "      ")
    if (account["fileName"] != "")
        AccountMetadata_AppendJsonString(json, firstField, "fileName", account["fileName"], "      ")
    if (account["accountName"] != "")
        AccountMetadata_AppendJsonString(json, firstField, "accountName", account["accountName"], "      ")
    if (account["friendCode"] != "")
        AccountMetadata_AppendJsonString(json, firstField, "friendCode", account["friendCode"], "      ")

    if (account["packCount"] != "" && (account["packCount"] + 0) != 0)
        AccountMetadata_AppendJsonNumber(json, firstField, "packCount", account["packCount"] + 0, "      ")

    createdAt := AccountMetadata_NormalizeCreatedAt(account["createdAt"])
    if (createdAt != "" && createdAt != "0")
        AccountMetadata_AppendJsonString(json, firstField, "createdAt", createdAt, "      ")

    if (account["lastPackPulled"] != "" && account["lastPackPulled"] != "0")
        AccountMetadata_AppendJsonString(json, firstField, "lastPackPulled", account["lastPackPulled"], "      ")
    if (account["lastLoggedIn"] != "" && account["lastLoggedIn"] != "0")
        AccountMetadata_AppendJsonString(json, firstField, "lastLoggedIn", account["lastLoggedIn"], "      ")

    shinedust := AccountMetadata_NormalizeShinedust(account["shinedust"])
    if (shinedust["value"] != -1 || shinedust["lastUpdatedAt"] != "0") {
        AccountMetadata_AppendComma(json, firstField)
        json .= "      ""shinedust"": {"
        firstShinedust := true
        if (shinedust["value"] != -1)
            AccountMetadata_AppendJsonNumber(json, firstShinedust, "value", shinedust["value"] + 0, "")
        if (shinedust["lastUpdatedAt"] != "0")
            AccountMetadata_AppendJsonString(json, firstShinedust, "lastUpdatedAt", shinedust["lastUpdatedAt"], "")
        json .= "}"
    }

    flagsJson := ""
    firstFlag := true
    Loop, % flags.MaxIndex() {
        flag := flags[A_Index]
        flagObj := account["flags"][flag]
        if (!IsObject(flagObj))
            flagObj := AccountMetadata_NewFlag(0)

        if (!flagObj["value"] && flagObj["setAt"] = "" && flagObj["validUntil"] = "")
            continue

        if (!firstFlag)
            flagsJson .= ","
        flagsJson .= "`r`n        """ . flag . """: {"
        firstFlagField := true
        if (flagObj["value"])
            AccountMetadata_AppendJsonNumber(flagsJson, firstFlagField, "value", 1, "")
        if (flagObj["setAt"] != "")
            AccountMetadata_AppendJsonString(flagsJson, firstFlagField, "setAt", flagObj["setAt"], "")
        if (flagObj["validUntil"] != "")
            AccountMetadata_AppendJsonString(flagsJson, firstFlagField, "validUntil", flagObj["validUntil"], "")
        flagsJson .= "}"
        firstFlag := false
    }

    if (flagsJson != "") {
        AccountMetadata_AppendComma(json, firstField)
        json .= "      ""flags"": {" . flagsJson . "`r`n      }"
    }

    if (!firstField)
        json .= "`r`n"
    json .= "    }"
    return json
}

AccountMetadata_AppendComma(ByRef json, ByRef firstField) {
    if (!firstField)
        json .= ",`r`n"
    firstField := false
}

AccountMetadata_AppendJsonString(ByRef json, ByRef firstField, key, value, indent) {
    AccountMetadata_AppendComma(json, firstField)
    json .= indent . """" . key . """: """ . AccountMetadata_Escape(value) . """"
}

AccountMetadata_AppendJsonNumber(ByRef json, ByRef firstField, key, value, indent) {
    AccountMetadata_AppendComma(json, firstField)
    json .= indent . """" . key . """: " . value
}

AccountMetadata_FindKey(ByRef store, instance, fileName, filePath := "", deviceAccount := "") {
    if (deviceAccount = "")
        deviceAccount := AccountMetadata_GetDeviceAccountFromFile(filePath)

    if (deviceAccount != "") {
        deviceKey := AccountMetadata_DeviceKey(deviceAccount)
        if (store["accounts"].HasKey(deviceKey))
            return deviceKey

        legacyKey := AccountMetadata_Key(instance, fileName)
        if (store["accounts"].HasKey(legacyKey)) {
            account := store["accounts"][legacyKey]
            store["accounts"].Delete(legacyKey)
            account["deviceAccount"] := deviceAccount
            store["accounts"][deviceKey] := account
            return deviceKey
        }

        for key, account in store["accounts"] {
            if (account["deviceAccount"] = deviceAccount) {
                if (key != deviceKey) {
                    store["accounts"].Delete(key)
                    store["accounts"][deviceKey] := account
                }
                return deviceKey
            }
        }
    }

    legacyKey := AccountMetadata_Key(instance, fileName)
    if (store["accounts"].HasKey(legacyKey))
        return legacyKey

    for key, account in store["accounts"] {
        if (account["instance"] = instance && account["fileName"] = fileName)
            return key
    }

    return deviceAccount != "" ? AccountMetadata_DeviceKey(deviceAccount) : legacyKey
}

AccountMetadata_EnsureAccount(ByRef store, instance, fileName, filePath := "", deviceAccount := "") {
    key := AccountMetadata_FindKey(store, instance, fileName, filePath, deviceAccount)
    if (!store["accounts"].HasKey(key)) {
        account := AccountMetadata_NewAccount(instance, fileName)
        if (deviceAccount = "")
            deviceAccount := AccountMetadata_GetDeviceAccountFromFile(filePath)
        account["deviceAccount"] := deviceAccount

        store["accounts"][key] := account
    }

    if (deviceAccount = "")
        deviceAccount := AccountMetadata_GetDeviceAccountFromFile(filePath)
    if (deviceAccount != "" && store["accounts"][key]["deviceAccount"] = "")
        store["accounts"][key]["deviceAccount"] := deviceAccount
    store["accounts"][key]["instance"] := instance
    store["accounts"][key]["fileName"] := fileName
    if (store["accounts"][key]["createdAt"] = "" || store["accounts"][key]["createdAt"] = "0")
        store["accounts"][key]["createdAt"] := AccountMetadata_ExtractCreatedAt(fileName)

    return store["accounts"][key]
}

AccountMetadata_MergeAccount(baseAccount, patchAccount) {
    if (!IsObject(baseAccount))
        baseAccount := AccountMetadata_NewAccount(patchAccount["instance"], patchAccount["fileName"])

    if (patchAccount["deviceAccount"] != "")
        baseAccount["deviceAccount"] := patchAccount["deviceAccount"]
    if (patchAccount["instance"] != "")
        baseAccount["instance"] := patchAccount["instance"]
    if (patchAccount["fileName"] != "")
        baseAccount["fileName"] := patchAccount["fileName"]
    if (patchAccount["accountName"] != "" && patchAccount["accountName"] != "Unknown")
        baseAccount["accountName"] := patchAccount["accountName"]
    if (patchAccount["friendCode"] != "" && patchAccount["friendCode"] != "Unknown") {
        cleanFriendCode := RegExReplace(patchAccount["friendCode"], "\D", "")
        if (RegExMatch(cleanFriendCode, "^\d{16}$"))
            baseAccount["friendCode"] := cleanFriendCode
    }

    if (patchAccount["packCount"] != "" && (patchAccount["packCount"] + 0) > 0)
        baseAccount["packCount"] := patchAccount["packCount"] + 0
    if (patchAccount["createdAt"] != "" && patchAccount["createdAt"] != "0")
        baseAccount["createdAt"] := patchAccount["createdAt"]
    if (patchAccount["lastPackPulled"] != "" && patchAccount["lastPackPulled"] != "0")
        baseAccount["lastPackPulled"] := patchAccount["lastPackPulled"]
    if (patchAccount["lastLoggedIn"] != "" && patchAccount["lastLoggedIn"] != "0")
        baseAccount["lastLoggedIn"] := patchAccount["lastLoggedIn"]

    patchShinedust := AccountMetadata_NormalizeShinedust(patchAccount["shinedust"])
    if (patchShinedust["lastUpdatedAt"] != "0" || patchShinedust["value"] != -1)
        baseAccount["shinedust"] := patchShinedust

    if (!IsObject(baseAccount["flags"]))
        baseAccount["flags"] := {}
    flags := ["B", "X", "T", "R", "W", "H", "SH"]
    Loop, % flags.MaxIndex() {
        flag := flags[A_Index]
        patchFlag := patchAccount["flags"][flag]
        if (!IsObject(patchFlag))
            continue
        if (patchFlag["value"] || patchFlag["setAt"] != "" || patchFlag["validUntil"] != "")
            baseAccount["flags"][flag] := patchFlag
        else if (!baseAccount["flags"].HasKey(flag))
            baseAccount["flags"][flag] := AccountMetadata_NewFlag(0)
    }

    return baseAccount
}

AccountMetadata_ApplyPatchToStore(ByRef store, patchAccount) {
    key := AccountMetadata_FindKey(store, patchAccount["instance"], patchAccount["fileName"], "", patchAccount["deviceAccount"])
    baseAccount := store["accounts"].HasKey(key) ? store["accounts"][key] : AccountMetadata_NewAccount(patchAccount["instance"], patchAccount["fileName"])
    mergedAccount := AccountMetadata_MergeAccount(baseAccount, patchAccount)
    newKey := mergedAccount["deviceAccount"] != "" ? AccountMetadata_DeviceKey(mergedAccount["deviceAccount"]) : AccountMetadata_Key(mergedAccount["instance"], mergedAccount["fileName"])
    if (key != newKey && store["accounts"].HasKey(key))
        store["accounts"].Delete(key)
    store["accounts"][newKey] := mergedAccount
}

AccountMetadata_SaveTempAccount(instance, fileName, account) {
    if (instance = "")
        instance := AccountMetadata_CurrentInstance()
    deviceAccount := account["deviceAccount"]
    if (deviceAccount = "")
        deviceAccount := AccountMetadata_CurrentDeviceAccount()
    if (deviceAccount = "")
        return false
    account["deviceAccount"] := deviceAccount
    tempStore := AccountMetadata_ReadTempStoreUnlocked(instance, deviceAccount)
    key := AccountMetadata_FindKey(tempStore, instance, fileName, "", account["deviceAccount"])
    baseAccount := tempStore["accounts"].HasKey(key) ? tempStore["accounts"][key] : AccountMetadata_NewAccount(instance, fileName)
    account["instance"] := instance
    account["fileName"] := fileName
    mergedAccount := AccountMetadata_MergeAccount(baseAccount, account)
    newKey := mergedAccount["deviceAccount"] != "" ? AccountMetadata_DeviceKey(mergedAccount["deviceAccount"]) : AccountMetadata_Key(instance, fileName)
    if (key != newKey && tempStore["accounts"].HasKey(key))
        tempStore["accounts"].Delete(key)
    tempStore["accounts"][newKey] := mergedAccount
    AccountMetadata_WriteTempStoreUnlocked(tempStore, instance, deviceAccount)
    return true
}

AccountMetadata_CloseTempForInstance(instance := "", deviceAccount := "") {
    return true
}

AccountMetadata_CloseTempPath(tempPath) {
    return true
}

AccountMetadata_MergeTempForInstance(instance := "") {
    return true
}

AccountMetadata_MergeTempForInstance_AhkFallback(instance := "") {
    return true
}

AccountMetadata_MergeAllTemp() {
    helperPath := AccountMetadata_HelperPath()
    if (FileExist(helperPath)) {
        root := getScriptBaseFolder()
        RunWait, % """" . helperPath . """ --root """ . root . """ merge-metadata",, Hide
        return !ErrorLevel
    }

    return AccountMetadata_MergeAllTemp_AhkFallback()
}

AccountMetadata_Ensure() {
    helperPath := AccountMetadata_HelperPath()
    if (!FileExist(helperPath))
        return false

    root := getScriptBaseFolder()
    command := """" . helperPath . """ --root """ . root . """ ensure-metadata"
    if (AccountMetadata_MigrationNeeded()) {
        MsgBox, 64, Account Data Migration, PTCGPB needs to convert your legacy metadata and card database into per-account files.`n`nThis can take longer when you have many accounts. A progress window will be shown while the conversion runs.
        return AccountMetadata_RunWithMigrationProgress(command)
    }

    RunWait, %command%,, Hide
    return !ErrorLevel
}

AccountMetadata_MigrationNeeded() {
    accountDir := AccountMetadata_AccountDir()
    hasAccountFiles := false
    if (FileExist(accountDir)) {
        Loop, Files, %accountDir%\*.json, F
        {
            hasAccountFiles := true
            break
        }
    }

    if (FileExist(AccountMetadata_Path()))
        return true

    if (FileExist(getScriptBaseFolder() . "\Accounts\Cards\Card_Database.csv"))
        return true

    if (!hasAccountFiles) {
        savedDir := getScriptBaseFolder() . "\Accounts\Saved"
        if (FileExist(savedDir)) {
            Loop, Files, %savedDir%\*.xml, R
                return true
        }
    }

    return false
}

AccountMetadata_RunWithMigrationProgress(command) {
    progressPath := getScriptBaseFolder() . "\Accounts\Saved\metadata_migration_progress.txt"
    FileDelete, %progressPath%

    Run, %command%,, Hide, helperPid
    if (ErrorLevel)
        return false

    Progress, M B1 FS10 ZH0 FM10 WM700 W480, Starting account data migration..., Account Data Migration, Account Data Migration
    lastPercent := 0
    lastMessage := "Starting account data migration..."

    Loop {
        if (FileExist(progressPath)) {
            FileRead, progressText, %progressPath%
            progressText := Trim(progressText, "`r`n ")
            if (progressText != "") {
                parts := StrSplit(progressText, "|")
                if (parts.MaxIndex() >= 1)
                    lastPercent := parts[1] + 0
                if (parts.MaxIndex() >= 2 && parts[2] != "")
                    lastMessage := parts[2]
                Progress, %lastPercent%, %lastMessage%, Account Data Migration, Account Data Migration
            }
        } else {
            if (lastPercent < 5)
                Progress, 5, Preparing account data migration..., Account Data Migration, Account Data Migration
        }

        Process, Exist, %helperPid%
        if (!ErrorLevel)
            break
        Sleep, 250
    }

    Progress, 100, Account data migration complete, Account Data Migration, Account Data Migration
    Sleep, 300
    Progress, Off

    Process, WaitClose, %helperPid%, 1
    return true
}

AccountMetadata_MergeAllTemp_AhkFallback() {
    return true
}

AccountMetadata_Get(instance, fileName, filePath := "") {
    deviceAccount := AccountMetadata_GetDeviceAccountFromFile(filePath)

    if (deviceAccount != "")
        return AccountMetadata_ReadAccountUnlocked(deviceAccount, instance, fileName)

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return AccountMetadata_NewAccount(instance, fileName)

    store := AccountMetadata_ReadStoreUnlocked()
    account := AccountMetadata_EnsureAccount(store, instance, fileName, filePath, deviceAccount)
    AccountMetadata_ReleaseLock(hMutex)

    return account
}

AccountMetadata_GetPackCountMap() {
    result := {}

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return result

    store := AccountMetadata_ReadStoreUnlocked()
    for key, account in store["accounts"] {
        fileName := account["fileName"]
        if (fileName = "")
            continue

        packCount := account["packCount"]
        if (packCount = "")
            packCount := AccountMetadata_ExtractPackCount(fileName)

        result[fileName] := packCount + 0
    }

    AccountMetadata_ReleaseLock(hMutex)
    return result
}

AccountMetadata_GetAccountMap() {
    result := {}

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return result

    store := AccountMetadata_ReadStoreUnlocked()
    for key, account in store["accounts"] {
        fileName := account["fileName"]
        if (fileName = "")
            continue

        result[fileName] := account
    }

    AccountMetadata_ReleaseLock(hMutex)
    return result
}

AccountMetadata_SaveAccount(instance, fileName, account) {
    deviceAccount := account["deviceAccount"]
    if (deviceAccount != "") {
        existing := AccountMetadata_ReadAccountUnlocked(deviceAccount, instance, fileName)
        account["instance"] := instance
        account["fileName"] := fileName
        if ((account["packCount"] = "" || (account["packCount"] + 0) = 0) && (existing["packCount"] + 0) > 0)
            account["packCount"] := existing["packCount"]
        merged := AccountMetadata_MergeAccount(existing, account)
        return AccountMetadata_WriteAccountUnlocked(deviceAccount, merged)
    }

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    key := AccountMetadata_FindKey(store, instance, fileName, "", account["deviceAccount"])
    account["instance"] := instance
    account["fileName"] := fileName
    if ((account["createdAt"] = "" || account["createdAt"] = "0") && store["accounts"].HasKey(key) && store["accounts"][key]["createdAt"] != "" && store["accounts"][key]["createdAt"] != "0")
        account["createdAt"] := store["accounts"][key]["createdAt"]
    else if (account["createdAt"] = "" || account["createdAt"] = "0")
        account["createdAt"] := AccountMetadata_ExtractCreatedAt(fileName)
    if (store["accounts"].HasKey(key))
        account["shinedust"] := AccountMetadata_NormalizeShinedust(store["accounts"][key]["shinedust"])
    else
        account["shinedust"] := AccountMetadata_NormalizeShinedust(account["shinedust"])
    if (store["accounts"].HasKey(key) && store["accounts"][key]["lastLoggedIn"] != "")
        account["lastLoggedIn"] := store["accounts"][key]["lastLoggedIn"]
    else if (account["lastLoggedIn"] = "")
        account["lastLoggedIn"] := "0"
    if (store["accounts"].HasKey(key) && store["accounts"][key]["lastPackPulled"] != "" && store["accounts"][key]["lastPackPulled"] != "0")
        account["lastPackPulled"] := store["accounts"][key]["lastPackPulled"]
    else if (account["lastPackPulled"] = "")
        account["lastPackPulled"] := "0"
    if (!IsObject(account["flags"]))
        account["flags"] := {}
    if (store["accounts"].HasKey(key) && IsObject(store["accounts"][key]["flags"]) && store["accounts"][key]["flags"].HasKey("W"))
        account["flags"]["W"] := store["accounts"][key]["flags"]["W"]
    store["accounts"][key] := account
    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_MoveToInstance(fileName, newInstance, filePath := "") {
    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    AccountMetadata_MoveToInstanceInStore(store, fileName, newInstance, filePath)
    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_MoveToInstanceInStore(ByRef store, fileName, newInstance, filePath := "") {
    foundKey := ""
    account := ""
    deviceAccount := AccountMetadata_GetDeviceAccountFromFile(filePath)

    if (deviceAccount != "") {
        foundKey := AccountMetadata_FindKey(store, "", "", "", deviceAccount)
        if (store["accounts"].HasKey(foundKey))
            account := store["accounts"][foundKey]
    }

    if (!IsObject(account)) {
        suffix := "/" . fileName
        for key, candidate in store["accounts"] {
            if (candidate["fileName"] = fileName || (StrLen(key) >= StrLen(suffix) && SubStr(key, StrLen(key) - StrLen(suffix) + 1) = suffix)) {
                foundKey := key
                account := candidate
                break
            }
        }
    }

    if (foundKey != "")
        store["accounts"].Delete(foundKey)
    if (!IsObject(account))
        account := AccountMetadata_NewAccount(newInstance, fileName)

    if (deviceAccount != "")
        account["deviceAccount"] := deviceAccount
    account["instance"] := newInstance
    account["fileName"] := fileName
    if (account["packCount"] = "")
        account["packCount"] := AccountMetadata_ExtractPackCount(fileName)
    if (account["createdAt"] = "" || account["createdAt"] = "0")
        account["createdAt"] := AccountMetadata_ExtractCreatedAt(fileName)

    newKey := account["deviceAccount"] != "" ? AccountMetadata_DeviceKey(account["deviceAccount"]) : AccountMetadata_Key(newInstance, fileName)
    store["accounts"][newKey] := account
}

AccountMetadata_BulkMoveToInstances(moves) {
    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    fileNameToKey := {}
    deviceToKey := {}

    for key, account in store["accounts"] {
        existingFileName := account["fileName"]
        if (existingFileName != "")
            fileNameToKey[existingFileName] := key

        existingDevice := account["deviceAccount"]
        if (existingDevice != "")
            deviceToKey[existingDevice] := key
    }

    if (IsObject(moves)) {
        for _, move in moves {
            fileName := move["fileName"]
            newInstance := move["instance"]
            if (fileName = "" || newInstance = "")
                continue

            deviceAccount := move["deviceAccount"]
            foundKey := ""

            if (deviceAccount != "" && deviceToKey.HasKey(deviceAccount))
                foundKey := deviceToKey[deviceAccount]
            else if (fileNameToKey.HasKey(fileName))
                foundKey := fileNameToKey[fileName]

            account := ""
            if (foundKey != "" && store["accounts"].HasKey(foundKey)) {
                account := store["accounts"][foundKey]
                store["accounts"].Delete(foundKey)
            }
            if (!IsObject(account))
                account := AccountMetadata_NewAccount(newInstance, fileName)

            if (deviceAccount != "")
                account["deviceAccount"] := deviceAccount
            account["instance"] := newInstance
            account["fileName"] := fileName
            if (account["packCount"] = "")
                account["packCount"] := AccountMetadata_ExtractPackCount(fileName)
            if (account["createdAt"] = "" || account["createdAt"] = "0")
                account["createdAt"] := AccountMetadata_ExtractCreatedAt(fileName)

            newKey := account["deviceAccount"] != "" ? AccountMetadata_DeviceKey(account["deviceAccount"]) : AccountMetadata_Key(newInstance, fileName)
            store["accounts"][newKey] := account

            fileNameToKey[fileName] := newKey
            if (account["deviceAccount"] != "")
                deviceToKey[account["deviceAccount"]] := newKey
        }
    }

    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_SetFlag(instance, fileName, flag, value, validUntil := "") {
    if (AccountMetadata_UseTempWrites()) {
        account := AccountMetadata_NewAccount(instance, fileName)
        if (!account["flags"].HasKey(flag))
            account["flags"][flag] := AccountMetadata_NewFlag(0)

        oldValue := account["flags"][flag]["value"]
        account["flags"][flag]["value"] := value ? 1 : 0
        if (oldValue != account["flags"][flag]["value"] || account["flags"][flag]["setAt"] = "")
            account["flags"][flag]["setAt"] := value ? AccountMetadata_Now() : ""
        if (validUntil != "")
            account["flags"][flag]["validUntil"] := validUntil
        return AccountMetadata_SaveTempAccount(instance, fileName, account)
    }

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    account := AccountMetadata_EnsureAccount(store, instance, fileName, "")
    if (!account["flags"].HasKey(flag))
        account["flags"][flag] := AccountMetadata_NewFlag(0)

    oldValue := account["flags"][flag]["value"]
    account["flags"][flag]["value"] := value ? 1 : 0
    if (oldValue != account["flags"][flag]["value"] || account["flags"][flag]["setAt"] = "")
        account["flags"][flag]["setAt"] := value ? AccountMetadata_Now() : ""
    if (validUntil != "")
        account["flags"][flag]["validUntil"] := validUntil

    key := account["deviceAccount"] != "" ? AccountMetadata_DeviceKey(account["deviceAccount"]) : AccountMetadata_Key(instance, fileName)
    store["accounts"][key] := account
    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_SetShinedust(deviceAccount, shinedustValue, instance := "", fileName := "") {
    if (deviceAccount = "")
        return false
    if (AccountMetadata_UseTempWrites()) {
        account := AccountMetadata_NewAccount(instance, fileName)
        account["deviceAccount"] := deviceAccount
        if (instance != "")
            account["instance"] := instance
        if (fileName != "")
            account["fileName"] := fileName
        account["shinedust"] := AccountMetadata_NewShinedust(shinedustValue, AccountMetadata_Now())
        return AccountMetadata_SaveTempAccount(instance, fileName, account)
    }

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false
    store := AccountMetadata_ReadStoreUnlocked()
    key := AccountMetadata_FindKey(store, instance, fileName, "", deviceAccount)
    if (store["accounts"].HasKey(key)) {
        account := store["accounts"][key]
    } else {
        account := AccountMetadata_NewAccount(instance, fileName)
        account["deviceAccount"] := deviceAccount
    }
    account["deviceAccount"] := deviceAccount
    if (instance != "") {
        account["instance"] := instance
    }
    if (fileName != "") {
        account["fileName"] := fileName
        if (account["packCount"] = "") {
            account["packCount"] := AccountMetadata_ExtractPackCount(fileName)
        }
    }
    account["shinedust"] := AccountMetadata_NewShinedust(shinedustValue, AccountMetadata_Now())

    newKey := AccountMetadata_DeviceKey(deviceAccount)
    if (key != newKey && store["accounts"].HasKey(key)) {
        store["accounts"].Delete(key)
    }

    store["accounts"][newKey] := account
    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_SetLastPackPulledNow(deviceAccount, instance := "", fileName := "") {
    if (deviceAccount = "")
        return false
    if (AccountMetadata_UseTempWrites()) {
        account := AccountMetadata_NewAccount(instance, fileName)
        account["deviceAccount"] := deviceAccount
        if (instance != "")
            account["instance"] := instance
        if (fileName != "")
            account["fileName"] := fileName
        account["lastPackPulled"] := AccountMetadata_Now()
        return AccountMetadata_SaveTempAccount(instance, fileName, account)
    }

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    key := AccountMetadata_FindKey(store, instance, fileName, "", deviceAccount)
    if (store["accounts"].HasKey(key)) {
        account := store["accounts"][key]
    } else {
        account := AccountMetadata_NewAccount(instance, fileName)
        account["deviceAccount"] := deviceAccount
    }

    account["deviceAccount"] := deviceAccount
    if (instance != "")
        account["instance"] := instance
    if (fileName != "") {
        account["fileName"] := fileName
        if (account["createdAt"] = "" || account["createdAt"] = "0")
            account["createdAt"] := AccountMetadata_ExtractCreatedAt(fileName)
    }

    account["lastPackPulled"] := AccountMetadata_Now()

    newKey := AccountMetadata_DeviceKey(deviceAccount)
    if (key != newKey && store["accounts"].HasKey(key))
        store["accounts"].Delete(key)
    store["accounts"][newKey] := account
    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_SetLastLoggedInNow(deviceAccount, instance := "", fileName := "") {
    if (deviceAccount = "")
        return false
    if (AccountMetadata_UseTempWrites()) {
        account := AccountMetadata_NewAccount(instance, fileName)
        account["deviceAccount"] := deviceAccount
        if (instance != "")
            account["instance"] := instance
        if (fileName != "")
            account["fileName"] := fileName
        account["lastLoggedIn"] := AccountMetadata_Now()
        return AccountMetadata_SaveTempAccount(instance, fileName, account)
    }

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    key := AccountMetadata_FindKey(store, instance, fileName, "", deviceAccount)
    if (store["accounts"].HasKey(key)) {
        account := store["accounts"][key]
    } else {
        account := AccountMetadata_NewAccount(instance, fileName)
        account["deviceAccount"] := deviceAccount
    }

    account["deviceAccount"] := deviceAccount
    if (instance != "")
        account["instance"] := instance
    if (fileName != "") {
        account["fileName"] := fileName
        if (account["createdAt"] = "" || account["createdAt"] = "0")
            account["createdAt"] := AccountMetadata_ExtractCreatedAt(fileName)
    }

    account["lastLoggedIn"] := AccountMetadata_Now()

    newKey := AccountMetadata_DeviceKey(deviceAccount)
    if (key != newKey && store["accounts"].HasKey(key))
        store["accounts"].Delete(key)
    store["accounts"][newKey] := account
    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return true
}

AccountMetadata_HasFlag(instance, fileName, flag) {
    account := AccountMetadata_Get(instance, fileName)
    if (IsObject(account["flags"]) && account["flags"].HasKey(flag))
        return account["flags"][flag]["value"] ? true : false
    return false
}

AccountMetadata_GetFlag(instance, fileName, flag, ByRef found) {
    found := false

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return false

    store := AccountMetadata_ReadStoreUnlocked()
    key := AccountMetadata_FindKey(store, instance, fileName)
    if (store["accounts"].HasKey(key)) {
        account := store["accounts"][key]
        if (IsObject(account["flags"]) && account["flags"].HasKey(flag)) {
            found := true
            value := account["flags"][flag]["value"] ? true : false
            AccountMetadata_ReleaseLock(hMutex)
            return value
        }
    }

    AccountMetadata_ReleaseLock(hMutex)
    return false
}

AccountMetadata_ClearFlagEverywhere(flag) {
    if (AccountMetadata_MigrationNeeded())
        AccountMetadata_Ensure()

    helperPath := AccountMetadata_HelperPath()
    if (FileExist(helperPath)) {
        root := getScriptBaseFolder()
        resultPath := root . "\Accounts\Saved\clear_flag_result.txt"
        errorPath := root . "\Accounts\Saved\carddb_error.txt"
        progressPath := root . "\Accounts\Saved\clear_flag_progress.txt"
        FileDelete, %resultPath%
        FileDelete, %errorPath%
        FileDelete, %progressPath%

        title := flag = "X" ? "Reset Claim Status" : (flag = "R" ? "Reset Receive Gift Status" : "Reset Account Status")
        command := """" . helperPath . """ --root """ . root . """ clear-flag --flag """ . flag . """"
        Progress, M B1 FS10 ZH0 FM10 WM700 W480, Starting reset..., %title%, %title%
        Run, %command%,, Hide, helperPid
        if (ErrorLevel) {
            Progress, Off
            return 0
        }

        lastPercent := 0
        lastMessage := "Starting reset..."
        Loop {
            if (FileExist(progressPath)) {
                FileRead, progressText, %progressPath%
                progressText := Trim(progressText, "`r`n ")
                if (progressText != "") {
                    parts := StrSplit(progressText, "|")
                    if (parts.MaxIndex() >= 1)
                        lastPercent := parts[1] + 0
                    if (parts.MaxIndex() >= 2 && parts[2] != "")
                        lastMessage := parts[2]
                    Progress, %lastPercent%, %lastMessage%, %title%, %title%
                }
            } else {
                if (lastPercent < 5)
                    Progress, 5, Preparing reset..., %title%, %title%
            }

            Process, Exist, %helperPid%
            if (!ErrorLevel)
                break
            Sleep, 250
        }

        Progress, 100, Reset complete, %title%, %title%
        Sleep, 300
        Progress, Off

        if (FileExist(errorPath))
            return 0

        if (FileExist(resultPath)) {
            FileRead, resultText, %resultPath%
            resultText := Trim(resultText, "`r`n ")
            return resultText = "" ? 0 : resultText + 0
        }
        return 0
    }

    changed := AccountMetadata_ClearFlagInAccountFiles(flag)
    if (changed != "")
        return changed + 0

    hMutex := AccountMetadata_AcquireLock()
    if (!hMutex)
        return 0

    store := AccountMetadata_ReadStoreUnlocked()
    changed := 0
    for key, account in store["accounts"] {
        if (IsObject(account["flags"]) && account["flags"].HasKey(flag) && account["flags"][flag]["value"]) {
            account["flags"][flag]["value"] := 0
            account["flags"][flag]["setAt"] := ""
            store["accounts"][key] := account
            changed++
        }
    }

    AccountMetadata_WriteStoreUnlocked(store)
    AccountMetadata_ReleaseLock(hMutex)
    return changed
}

AccountMetadata_ClearFlagInAccountFiles(flag) {
    accountDir := AccountMetadata_AccountDir()
    if (!FileExist(accountDir))
        return ""

    changed := 0
    foundAny := false
    Loop, Files, %accountDir%\*.json, F
    {
        foundAny := true
        SplitPath, A_LoopFileName,,,, deviceAccount
        if (deviceAccount = "")
            continue

        account := AccountMetadata_ReadAccountUnlocked(deviceAccount)
        if (!IsObject(account["flags"]) || !account["flags"].HasKey(flag))
            continue
        if (!account["flags"][flag]["value"])
            continue

        account["flags"][flag]["value"] := 0
        account["flags"][flag]["setAt"] := ""
        account["flags"][flag]["validUntil"] := ""
        AccountMetadata_WriteAccountUnlocked(deviceAccount, account)
        changed++
    }

    if (!foundAny)
        return ""
    return changed
}
