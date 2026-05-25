;===============================================================================
; HistoryImport.ahk - Game pull history export and My Collection import
;===============================================================================

CollectionProfilesDir() {
    return getScriptBaseFolder() . "\Accounts\Cards\collections"
}

Collection_MakeFileKey(displayName) {
    key := Trim(displayName)
    if (key = "")
        return ""
    key := RegExReplace(key, "[\\/:*?""<>|]", "_")
    key := RegExReplace(key, "\s+", " ")
    return key
}

Collection_ListProfiles() {
    profiles := []
    dir := CollectionProfilesDir()
    if (!FileExist(dir))
        return profiles

    Loop, Files, % dir . "\*.json", F
    {
        fileKey := RegExReplace(A_LoopFileName, "\.json$", "")
        displayName := fileKey
        FileRead, jsonText, % A_LoopFileFullPath
        if (RegExMatch(jsonText, "i)""displayName""\s*:\s*""([^""]+)""", match))
            displayName := match1
        profiles.Push({ key: fileKey, displayName: displayName, path: A_LoopFileFullPath })
    }
    return profiles
}

Collection_DefaultDisplayName(instanceName, deviceAccount) {
    if (instanceName != "")
        return instanceName
    if (deviceAccount != "")
        return deviceAccount
    return "My Collection"
}

Collection_PromptNewName(defaultName) {
    InputBox, newName, Import My Collection, Name for the new collection file:`n(saved in Accounts\Cards\collections), , 440, 160,,, %defaultName%
    if ErrorLevel
        return { ok: false }
    displayName := Trim(newName)
    key := Collection_MakeFileKey(displayName)
    if (displayName = "" || key = "") {
        MsgBox, 48, Import My Collection, Enter a valid collection name.
        return { ok: false }
    }
    targetPath := CollectionProfilesDir() . "\" . key . ".json"
    if FileExist(targetPath) {
        MsgBox, 48, Import My Collection, A collection file with this name already exists.`nPick another name or update the existing collection.
        return { ok: false }
    }
    return { ok: true, mode: "new", displayName: displayName, key: key }
}

Collection_PromptPickExisting(profiles, deviceAccount := "") {
    global collectionImportChoice, CollectionImportExisting

    profileList := ""
    Loop, % profiles.Length() {
        profileList .= (A_Index > 1 ? "|" : "") . profiles[A_Index].displayName
    }

    choiceIndex := 1
    Loop, % profiles.Length() {
        if (deviceAccount != "" && profiles[A_Index].key = deviceAccount)
            choiceIndex := A_Index
    }

    collectionImportChoice := ""
    Gui, CollectionPick:New, +AlwaysOnTop +ToolWindow
    Gui, CollectionPick:Font, s10, Segoe UI
    Gui, CollectionPick:Margin, 16, 14
    Gui, CollectionPick:Add, Text, w360, Select the collection to update:
    Gui, CollectionPick:Add, DropDownList, w360 vCollectionImportExisting Choose%choiceIndex%, %profileList%
    Gui, CollectionPick:Add, Button, w90 h28 Default gCollectionPickOk, OK
    Gui, CollectionPick:Add, Button, x+10 w90 h28 gCollectionPickCancel, Cancel
    Gui, CollectionPick:Show, AutoSize Center, Select collection
    WinWaitClose, Select collection
    return collectionImportChoice
}

Collection_PromptImportMode(profiles, deviceAccount, defaultName) {
    global collectionModeChoice
    collectionModeChoice := ""
    Gui, CollectionMode:New, +AlwaysOnTop +ToolWindow
    Gui, CollectionMode:Font, s10, Segoe UI
    Gui, CollectionMode:Margin, 12, 12
    Gui, CollectionMode:Add, Button, w148 h30 gCollectionModeExisting, Update existing
    Gui, CollectionMode:Add, Button, x+10 w148 h30 gCollectionModeNew, Create new
    Gui, CollectionMode:Show, AutoSize Center, Import My Collection
    WinWaitClose, Import My Collection
    if (collectionModeChoice = "existing")
        return Collection_PromptPickExisting(profiles, deviceAccount)
    if (collectionModeChoice = "new")
        return Collection_PromptNewName(defaultName)
    return { ok: false }
}

Collection_PromptImportTarget(instanceName, deviceAccount) {
    profiles := Collection_ListProfiles()
    defaultName := Collection_DefaultDisplayName(instanceName, deviceAccount)

    if (profiles.Length() = 0)
        return Collection_PromptNewName(defaultName)

    return Collection_PromptImportMode(profiles, deviceAccount, defaultName)
}

; Labels below are gosub targets only (include must be after Main auto-exec Return).
CollectionModeExisting:
    global collectionModeChoice
    collectionModeChoice := "existing"
    Gui, CollectionMode:Destroy
return

CollectionModeNew:
    global collectionModeChoice
    collectionModeChoice := "new"
    Gui, CollectionMode:Destroy
return

CollectionPickOk:
    global collectionImportChoice, CollectionImportExisting
    Gui, CollectionPick:Submit
    selectedName := CollectionImportExisting
    profiles := Collection_ListProfiles()
    choice := { ok: true, mode: "existing", key: "", displayName: selectedName }
    Loop, % profiles.Length() {
        if (profiles[A_Index].displayName = selectedName) {
            choice.key := profiles[A_Index].key
            choice.displayName := profiles[A_Index].displayName
            break
        }
    }
    if (choice.key = "") {
        MsgBox, 48, Import My Collection, Could not resolve the selected collection.
        return
    }
    collectionImportChoice := choice
    Gui, CollectionPick:Destroy
return

CollectionPickCancel:
    global collectionImportChoice
    collectionImportChoice := { ok: false }
    Gui, CollectionPick:Destroy
return

ExportGameHistoryToFile(ByRef localPath) {
    global session

    deviceAccount := GetDeviceAccountFromXML()
    if (deviceAccount = "") {
        LogWarn("ExportGameHistoryToFile skipped because device account could not be resolved")
        return { ok: false, deviceAccount: "", localPath: "" }
    }

    safeName := RegExReplace(deviceAccount, "[^A-Za-z0-9_.-]", "_")
    filename := "history_" . safeName . ".txt"
    remotePath := "/data/ptcgp/" . filename
    sdcardPath := "/sdcard/" . filename
    localDir := A_ScriptDir . "\temp"
    if (!FileExist(localDir))
        FileCreateDir, %localDir%
    localPath := localDir . "\" . filename
    if (FileExist(localPath))
        FileDelete, %localPath%

    LogTrace("Ensuring ptcgpb helper exists before history export", "ADB.txt")
    if (!EnsurePTCGPBHelperInstalled())
        return false
    LogTrace("Clearing stale remote history files: " . remotePath . " and " . sdcardPath, "ADB.txt")
    adbWriteRaw("rm -f " . remotePath . " " . sdcardPath)
    LogTrace("Running ptcgpb history export to " . remotePath, "ADB.txt")
    adbWriteRaw("/data/ptcgp/ptcgpb history --out " . remotePath)
    LogTrace("Copying history export to sdcard path " . sdcardPath, "ADB.txt")
    adbWriteRaw("cp -f " . remotePath . " " . sdcardPath)

    LogTrace("Pulling history file to " . localPath, "ADB.txt")
    RunWait, % """" . session.get("adbPath") . """ -s 127.0.0.1:" . session.get("adbPort") . " pull """ . sdcardPath . """ """ . localPath . """",, Hide
    adbWriteRaw("rm -f " . remotePath . " " . sdcardPath)

    if (!FileExist(localPath)) {
        LogWarn("ExportGameHistoryToFile failed because pulled history file was not created: " . localPath)
        return { ok: false, deviceAccount: deviceAccount, localPath: localPath }
    }

    return { ok: true, deviceAccount: deviceAccount, localPath: localPath }
}

InvalidateDashboardAccountsCache() {
    cacheDir := getScriptBaseFolder() . "\Accounts\Cards\database_cache"
    cacheJson := cacheDir . "\accounts-data.cache.json"
    cacheMeta := cacheDir . "\accounts-data.cache.meta.json"
    if (FileExist(cacheJson))
        FileDelete, %cacheJson%
    if (FileExist(cacheMeta))
        FileDelete, %cacheMeta%
}

ImportMainCollection(instanceName := "") {
    global session, collectionImportChoice

    if (instanceName = "" && IsObject(session))
        instanceName := session.get("scriptName")
    if (instanceName = "")
        instanceName := "Main"

    helperPath := AccountMetadata_HelperPath()
    if (!FileExist(helperPath)) {
        CreateStatusMessage("Import failed: carddb helper is missing.")
        LogWarn("ImportMainCollection skipped because carddb helper is missing at " . helperPath)
        return false
    }

    CreateStatusMessage("Importing My Collection... Please wait.")
    LogInfo("ImportMainCollection started for instance " . instanceName)

    localPath := ""
    exportResult := ExportGameHistoryToFile(localPath)
    if (!exportResult.ok) {
        CreateStatusMessage("Import failed: could not export game history.")
        return false
    }

    deviceAccount := exportResult.deviceAccount
    localPath := exportResult.localPath

    target := Collection_PromptImportTarget(instanceName, deviceAccount)
    if (!IsObject(target) || !target.ok)
        return false

    root := getScriptBaseFolder()
    collectionsDir := CollectionProfilesDir()
    if (!FileExist(collectionsDir))
        FileCreateDir, %collectionsDir%

    importArgs := """" . helperPath . """ --root """ . root . """ import-collection --device-account """ . deviceAccount . """ --input """ . localPath . """ --instance """ . instanceName . """"
    if (target.mode = "new")
        importArgs .= " --name """ . target.displayName . """"
    else
        importArgs .= " --into """ . target.key . """"

    LogDebug("Importing collection with carddb: " . target.displayName)
    RunWait, %importArgs%,, Hide
    if (ErrorLevel) {
        CreateStatusMessage("Import failed: carddb import-collection error.")
        LogWarn("ImportMainCollection carddb import-collection failed ErrorLevel=" . ErrorLevel)
        return false
    }

    FileDelete, %localPath%
    InvalidateDashboardAccountsCache()

    label := target.displayName
    CreateStatusMessage("My Collection imported (" . label . ").")
    LogInfo("ImportMainCollection completed for collection " . label)
    return true
}
