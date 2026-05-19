#SingleInstance on
;SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
;SetWinDelay, -1
;SetControlDelay, -1
SetBatchLines, -1
SetTitleMatchMode, 3

global adbShell, adbPath, adbPorts, winTitle, folderPath, selectedFilePath, mumuFolder, headless, injectInProgress

IniRead, winTitle, InjectAccount.ini, UserSettings, winTitle, 1
IniRead, fileName, InjectAccount.ini, UserSettings, fileName, name
IniRead, folderPath, InjectAccount.ini, UserSettings, folderPath, C:\Program Files\Netease
IniRead, selectedFilePath, InjectAccount.ini, UserSettings, selectedFilePath, ""
IniRead, sendFriendRequestAfterInject, InjectAccount.ini, UserSettings, sendFriendRequestAfterInject, 0
IniRead, injectExtraFriendIDsIni, InjectAccount.ini, UserSettings, injectExtraFriendIDs,
if (injectExtraFriendIDsIni = "ERROR")
    injectExtraFriendIDsIni := ""

settingsIniFriend := A_ScriptDir . "\..\Settings.ini"
IniRead, injectFriendPrimary, %settingsIniFriend%, General, FriendID, ERROR
if (injectFriendPrimary = "ERROR")
    injectFriendPrimary := ""

injectFriend2 := ""
injectFriend3 := ""
injectFriend4 := ""
injectFriend5 := ""
injectFriend6 := ""
injectFriend7 := ""
injectFriend8 := ""
injectFriend9 := ""
injectFriend10 := ""
injectExtraCsv := injectExtraFriendIDsIni
StringReplace, injectExtraCsv, injectExtraCsv, |, `,, All
slotN := 0
Loop, Parse, injectExtraCsv, `,
{
    id := Trim(A_LoopField)
    if (id = "")
        continue
    slotN += 1
    if (slotN > 9)
        break
    vn := "injectFriend" . (slotN + 1)
    %vn% := id
}

; --- Headless mode (called from the Card Dashboard HTML server) ---------
headless := false
Loop, %0%
{
    arg := %A_Index%
    if (arg = "/headless" || arg = "--headless" || arg = "-headless")
    {
        headless := true
        break
    }
}

if (headless)
{
    Gosub, RunInjectFlow
    ExitApp
}
; -------------------------------------------------------------------------

; Set a custom font and size for better appearance
Gui, Font, s10, Segoe UI
Gui, Color, 1E1E1E  ; Dark background color
Gui, Font, cDCDCDC  ; Light text color

; Add a title with warning styling
Gui, Add, Text, x10 y10 w450 cWhite, This tool is to INJECT (login to) the selected account.
Gui, Add, Text, x10 y+5 w450 cRed, It will LOG OUT OF any current account in that instance.
Gui, Add, Text, x10 y+5 w450 cWhite, Ensure you have the login info of the current account (either a .xml file, nintendo account link, etc.) or you will LOSE it.

; Create a horizontal line for visual separation
Gui, Add, Text, x10 y+15 w450 h1 0x10 c3F3F3F ; Darker separator

; Instance section
instanceList := GetInstanceList(folderPath)
selectedIndex := 1
if (instanceList != "") {
    StringSplit, arr, instanceList, |
    Loop, %arr0%
    {
        if (arr%A_Index% = winTitle) {
            selectedIndex := A_Index
            break
        }
    }
}
Gui, Add, Text, x10 y+15 w450, Instance Name:
Gui, Add, DropDownList, x10 y+5 vwinTitle w340 Choose%selectedIndex%, %instanceList%
Gui, Add, Button, x+10 yp w100 gRefreshInstances, Refresh

; File section
Gui, Add, Text, x10 y+15 w450 cDCDCDC, File Name (without spaces and without .xml):
Gui, Add, Edit, x10 y+5 vfileName w340 c000000 BackgroundFFFFFF, %fileName%
Gui, Add, Button, x+10 yp w100 gBrowseFile, Browse

; Folder section
Gui, Add, Text, x10 y+15 w450 cDCDCDC, MuMu Folder same as main script (C:\Program Files\Netease)
Gui, Add, Edit, x10 y+5 vfolderPath w450 c000000 BackgroundFFFFFF, %folderPath%

; Friend request option
friendCheckText := "Send friend request(s) after inject"
Gui, Add, Checkbox, x10 y+12 vsendFriendRequestAfterInject Checked%sendFriendRequestAfterInject% cDCDCDC, %friendCheckText%
Gui, Add, Text, x10 y+8 w450 cGray, Friend IDs (max 10)
Gui, Add, Text, x10 y+6 w14 Right +0x200 section, 1
Gui, Add, Edit, x28 ys-2 w200 h22 vinjectFriendPrimary ReadOnly Disabled cDCDCDC Background303030, %injectFriendPrimary%
Gui, Add, Text, x238 ys w20 Right +0x200, 2
Gui, Add, Edit, x260 ys-2 w200 h22 vinjectFriend2 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend2%
Gui, Add, Text, x10 y+8 w14 Right +0x200 section, 3
Gui, Add, Edit, x28 ys-2 w200 h22 vinjectFriend3 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend3%
Gui, Add, Text, x238 ys w20 Right +0x200, 4
Gui, Add, Edit, x260 ys-2 w200 h22 vinjectFriend4 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend4%
Gui, Add, Text, x10 y+8 w14 Right +0x200 section, 5
Gui, Add, Edit, x28 ys-2 w200 h22 vinjectFriend5 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend5%
Gui, Add, Text, x238 ys w20 Right +0x200, 6
Gui, Add, Edit, x260 ys-2 w200 h22 vinjectFriend6 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend6%
Gui, Add, Text, x10 y+8 w14 Right +0x200 section, 7
Gui, Add, Edit, x28 ys-2 w200 h22 vinjectFriend7 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend7%
Gui, Add, Text, x238 ys w20 Right +0x200, 8
Gui, Add, Edit, x260 ys-2 w200 h22 vinjectFriend8 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend8%
Gui, Add, Text, x10 y+8 w14 Right +0x200 section, 9
Gui, Add, Edit, x28 ys-2 w200 h22 vinjectFriend9 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend9%
Gui, Add, Text, x238 ys w20 Right +0x200, 10
Gui, Add, Edit, x260 ys-2 w200 h22 vinjectFriend10 Number Limit16 c000000 BackgroundFFFFFF, %injectFriend10%

; Add another separator
Gui, Add, Text, x10 y+12 w450 h1 0x10 c3F3F3F ; Darker separator

Gui, Add, Text, x10 y+10 w450 vInjectStatusText c8FD18A, Ready.
Gui, Add, Progress, x10 y+6 w450 h8 vInjectProgress c4AAE3A Background303030, 0
Gui, Add, Button, x130 y+16 w100 h40 vSubmitBtn gSaveSettings cBlue, Submit
Gui, Add, Button, x+10 yp w100 h40 vRunInstanceBtn gRunInstance cGreen, Run Instance

; Show the GUI with a proper size
Gui, Show, w484 h628, Arturo's Account Injection Tool ;'
Return

OnGuiClose:
ExitApp

GuiClose:
ExitApp

BrowseFile:
    FileSelectFile, selectedFile, 3, , Select XML File, XML Files (*.xml)
    if (selectedFile != "")
    {
        SplitPath, selectedFile, fileNameNoExt, , , fileNameNoExtNoPath
        GuiControl,, fileName, %fileNameNoExtNoPath%
        selectedFilePath := selectedFile
    }
return

SaveSettings:
    if (injectInProgress)
        return
    Gui, Submit, NoHide
    if (!ValidateInjectFriendSlots())
        return
    extraFriendIDs := injectFriendSlotsToCsv()
    settingsIni := A_ScriptDir . "\..\Settings.ini"
    IniRead, prSid, %settingsIni%, General, FriendID, ERROR
    mergedN := FriendRequestMergedCount(prSid, extraFriendIDs)
    if (mergedN > 10) {
        MsgBox, 48, Friend codes, Maximum 10 friend codes total (Settings.ini FriendID + optional extras in this window).`n`nYou have: %mergedN%.
        return
    }
    injectInProgress := 1
    SetInjectUiBusy(true)
    UpdateInjectUi("Saving settings...", 5)
    ; Removed: Gui, Destroy
    IniWrite, %winTitle%, InjectAccount.ini, UserSettings, winTitle
    IniWrite, %fileName%, InjectAccount.ini, UserSettings, fileName
    IniWrite, %folderPath%, InjectAccount.ini, UserSettings, folderPath
    IniWrite, %selectedFilePath%, InjectAccount.ini, UserSettings, selectedFilePath
    IniWrite, %sendFriendRequestAfterInject%, InjectAccount.ini, UserSettings, sendFriendRequestAfterInject
    extraFriendForIni := extraFriendIDs
    Loop {
        if (!InStr(extraFriendForIni, ",,"))
            break
        StringReplace, extraFriendForIni, extraFriendForIni, `,,`,, All
    }
    extraFriendForIni := Trim(extraFriendForIni, " `t,")
    IniWrite, %extraFriendForIni%, InjectAccount.ini, UserSettings, injectExtraFriendIDs
; fall through into RunInjectFlow

RunInjectFlow:
    UpdateInjectUi("Resolving MuMu folder...", 10)
    mumuFolder := getMumuFolder(folderPath)

    UpdateInjectUi("Locating ADB and instance port...", 18)
    adbPath := mumuFolder . "\shell\adb.exe"
    if !FileExist(adbPath)
        adbPath := mumuFolder . "\nx_main\adb.exe"
    findAdbPorts(mumuFolder)

    if(!WinExist(winTitle)) {
        Msgbox, 16, , Can't find instance: %winTitle%. Make sure that instance is running.'
        UpdateInjectUi("Selected instance is not running.", 0)
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }

    if !FileExist(adbPath) ;if international mumu file path isn't found look for chinese domestic path
        adbPath := folderPath . "\MuMu Player 12\shell\adb.exe"
    if !FileExist(adbPath)
        adbPath := folderPath . "\MuMuPlayer-12.0\shell\adb.exe"
    if !FileExist(adbPath) ;MuMu Player 12 v5
        adbPath := folderPath . "\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
    if !FileExist(adbPath) ;MuMu Player 12 v5
        adbPath := folderPath . "\MuMu Player 12\nx_main\adb.exe"
    if !FileExist(adbPath)
        adbPath := folderPath . "\MuMuPlayer-12.0\nx_main\adb.exe"
    if !FileExist(adbPath) ;MuMu Player 12 v5
        adbPath := folderPath . "\MuMuPlayer\nx_main\adb.exe"
    if !FileExist(adbPath)
        adbPath := folderPath . "\MuMuPlayer-12\shell\adb.exe"
    if !FileExist(adbPath)
        adbPath := folderPath . "\MuMuPlayer-12\nx_main\adb.exe"
    if !FileExist(adbPath)
        adbPath := folderPath . "\MuMuPlayer12\shell\adb.exe"
    if !FileExist(adbPath)
        adbPath := folderPath . "\MuMuPlayer12\nx_main\adb.exe"

    if !FileExist(adbPath) {
        MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
        UpdateInjectUi("Invalid MuMu folder path.", 0)
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }

    if(!adbPorts) {
        Msgbox, 16, , Invalid port... Check the common issues section in the readme/github guide.
        UpdateInjectUi("Could not resolve ADB port.", 0)
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }

    filePath := selectedFilePath
    if (filePath = "")
        filePath := A_ScriptDir . "\" . fileName . ".xml"

    if(!FileExist(filePath)) {
        Msgbox, 16, , Can't find XML file: %filePath% ;'
        UpdateInjectUi("XML file not found.", 0)
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }
    UpdateInjectUi("Connecting to emulator...", 30)
    RunWait, %adbPath% connect 127.0.0.1:%adbPorts%,, Hide
    if (ErrorLevel != 0) {
        MsgBox, 16, , Failed to connect ADB on port %adbPorts%.
        UpdateInjectUi("Connection failed.", 0)
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }

    UpdateInjectUi("Injecting account data...", 45)
    if !loadAccount() {
        UpdateInjectUi("Inject failed.", 0)
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }
    UpdateInjectUi("Account injected.", 85)

    ; Optional: send a friend request to the account whose code is set in
    ; Settings.ini ([General] FriendID). The worker script reuses the bot's
    ; image-search + ADB primitives (same as 1.ahk) and runs a focused
    ; friend-request flow only.
    if (sendFriendRequestAfterInject) {
        UpdateInjectUi("Sending friend request(s)...", 92)
        sendFRScript := A_ScriptDir . "\_SendFriendRequest.ahk"
        if (FileExist(sendFRScript)) {
            RunWait, %A_AhkPath% "%sendFRScript%" "%winTitle%" "%folderPath%"
        } else {
            MsgBox, 48, , Cannot find _SendFriendRequest.ahk next to _InjectAccount.ahk.
        }
    }
    UpdateInjectUi("Done.", 100)
    SetInjectUiBusy(false)
    injectInProgress := 0
return

getMumuFolder(folderPath) {
    candidateFolders := [folderPath . "\MuMu"
        , folderPath . "\MuMuPlayerGlobal-12.0"
        , folderPath . "\MuMuPlayerGlobal"
        , folderPath . "\MuMuPlayer-12.0"
        , folderPath . "\MuMu Player 12"
        , folderPath . "\MuMuPlayer"
        , folderPath . "\MuMuPlayer-12"
        , folderPath . "\MuMuPlayer12"]

    for _, candidateFolder in candidateFolders {
        if FileExist(candidateFolder)
            return candidateFolder
    }

    return folderPath . "\MuMuPlayerGlobal-12.0"
}

GetVmDisplayName(folder) {
    configFolder := folder "\configs"
    extraConfigFile := configFolder "\extra_config.json"

    if FileExist(extraConfigFile) {
        FileRead, fileContent, %extraConfigFile%
        RegExMatch(fileContent, """playerName"":\s*""(.*?)""", playerName)
        if (playerName1 != "")
            return playerName1
    }

    SplitPath, folder, folderName
    return folderName
}

findAdbPorts(mumuFolderParam) {
    global adbPorts, winTitle
    ; Initialize variables
    adbPorts := 0  ; Create an empty associative array for adbPorts
    mumuFolderPath = %mumuFolderParam%\vms\*
    if !FileExist(mumuFolderPath){
        MsgBox, 16, , Double check your folder path! It should be the one that contains the MuMuPlayer 12 folder! `nDefault is just C:\Program Files\Netease
        return
    }
    ; Loop through all directories in the base folder
    Loop, Files, %mumuFolderPath%, D  ; D flag to include directories only
    {
        folder := A_LoopFileFullPath
        configFolder := folder "\configs"  ; The config folder inside each directory
        displayName := GetVmDisplayName(folder)

        ; Check if config folder exists
        IfExist, %configFolder%
        {
            ; Define paths to vm_config.json and extra_config.json
            vmConfigFile := configFolder "\vm_config.json"
            extraConfigFile := configFolder "\extra_config.json"

            ; Check if vm_config.json exists and read adb host port
            IfExist, %vmConfigFile%
            {
                FileRead, vmConfigContent, %vmConfigFile%
                ; Parse the JSON for adb host port
                RegExMatch(vmConfigContent, """host_port"":\s*""(\d+)""", adbHostPort)
                adbPort := adbHostPort1  ; Capture the adb host port value
            }

            ; Check if extra_config.json exists and read playerName
            IfExist, %extraConfigFile%
            {
                FileRead, extraConfigContent, %extraConfigFile%
                ; Parse the JSON for playerName
                RegExMatch(extraConfigContent, """playerName"":\s*""(.*?)""", playerName)
                if(playerName1 = winTitle || displayName = winTitle) {
                    adbPorts := adbPort
                }
            }
            else if (displayName = winTitle) {
                adbPorts := adbPort
            }
        }
    }
}

RunAdbRootCommand(shellCommand) {
    global adbPath, adbPorts
    q := Chr(34)
    sq := Chr(39)

    fullCommand := q . adbPath . q . " -s 127.0.0.1:" . adbPorts . " shell su -c " . sq . shellCommand . sq
    RunWait, %fullCommand%,, Hide
    if (ErrorLevel = 0)
        return 1

    ; Fallback for builds where su uses positional uid instead of -c.
    fallbackCommand := q . adbPath . q . " -s 127.0.0.1:" . adbPorts . " shell su 0 sh -c " . sq . shellCommand . sq
    RunWait, %fallbackCommand%,, Hide
    if (ErrorLevel = 0)
        return 1

    ; Last fallback: run as shell user (works for some commands like am force-stop).
    nonRootCommand := q . adbPath . q . " -s 127.0.0.1:" . adbPorts . " shell " . sq . shellCommand . sq
    RunWait, %nonRootCommand%,, Hide
    if (ErrorLevel = 0)
        return 1

    return 0
}

RunAdbPush(localPath, remotePath) {
    global adbPath, adbPorts
    pushCommand := Chr(34) . adbPath . Chr(34) . " -s 127.0.0.1:" . adbPorts . " push " . Chr(34) . localPath . Chr(34) . " " . remotePath
    RunWait, %pushCommand%,, Hide
    return (ErrorLevel = 0)
}

ShowInjectStepError(stepName) {
    MsgBox, 16, , Inject failed at step:`n%stepName%
}

SetInjectUiBusy(isBusy) {
    global headless
    if (headless)
        return

    if (isBusy) {
        GuiControl, Disable, SubmitBtn
        GuiControl, Disable, RunInstanceBtn
    } else {
        GuiControl, Enable, SubmitBtn
        GuiControl, Enable, RunInstanceBtn
    }
}

UpdateInjectUi(statusText, progressValue := "") {
    global headless
    if (headless)
        return

    GuiControl,, InjectStatusText, %statusText%
    if (progressValue != "")
        GuiControl,, InjectProgress, %progressValue%
    Sleep, 10
}

loadAccount() {
    global adbShell, adbPath, adbPorts, fileName, selectedFilePath

    static UserPreferencesPath := "/data/data/jp.pokemon.pokemontcgp/files/UserPreferences/v1/"
    static UserPreferences := ["BattleUserPrefs"
        ,"FeedUserPrefs"
        ,"FilterConditionUserPrefs"
        ,"HomeBattleMenuUserPrefs"
        ,"MissionUserPrefs"
        ,"NotificationUserPrefs"
        ,"PackUserPrefs"
        ,"PvPBattleResumeUserPrefs"
        ,"RankMatchPvEResumeUserPrefs"
        ,"RankMatchUserPrefs"
        ,"SoloBattleResumeUserPrefs"
        ,"SortConditionUserPrefs"]

    UpdateInjectUi("Stopping app...", 50)
    if !RunAdbRootCommand("am force-stop jp.pokemon.pokemontcgp") {
        ShowInjectStepError("am force-stop")
        return 0
    }
    Sleep, 200

    ; Clear app data to ensure no previous account information remains
    UpdateInjectUi("Clearing old account...", 58)
    if !RunAdbRootCommand("rm -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") {
        ShowInjectStepError("remove deviceAccount xml")
        return 0
    }
    Sleep, 200

    Loop, % UserPreferences.MaxIndex() {
        if !RunAdbRootCommand("rm -f " . UserPreferencesPath . UserPreferences[A_Index]) {
            ShowInjectStepError("clear user preferences")
            return 0
        }
        Sleep, 200
    }

    loadDir := selectedFilePath
    if (loadDir = "")
        loadDir := A_ScriptDir . "\" . fileName . ".xml"
    else {
        ; Don't append .xml if the path already ends with it
        SplitPath, loadDir, , , fileExt
        if (fileExt != "xml")
            loadDir := loadDir . ".xml"
    }

    ; Make sure the file exists before trying to push it
    if (!FileExist(loadDir)) {
        MsgBox, 16, Error, Cannot find the XML file: %loadDir%
        return 0
    }

    ; Push the file to the device with better error handling
    UpdateInjectUi("Uploading XML...", 68)
    if !RunAdbPush(loadDir, "/sdcard/deviceAccount.xml") {
        ShowInjectStepError("push deviceAccount xml")
        return 0
    }
    Sleep, 150

    ; Create the shared_prefs directory if it doesn't exist
    UpdateInjectUi("Applying account on device...", 74)
    if !RunAdbRootCommand("mkdir -p /data/data/jp.pokemon.pokemontcgp/shared_prefs") {
        ShowInjectStepError("create shared_prefs")
        return 0
    }
    Sleep, 100

    ; Copy the file with proper permissions
    if !RunAdbRootCommand("cp /sdcard/deviceAccount.xml /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") {
        ShowInjectStepError("copy deviceAccount xml")
        return 0
    }
    Sleep, 100

    ; Set proper permissions and ownership (combined commands with shorter delay)
    if !RunAdbRootCommand("chmod 664 /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml && chown system:system /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") {
        ShowInjectStepError("chmod/chown deviceAccount xml")
        return 0
    }
    Sleep, 200

    ; Clean up and launch app (reduced delay between operations)
    if !RunAdbRootCommand("rm -f /sdcard/deviceAccount.xml") {
        ShowInjectStepError("cleanup temp xml")
        return 0
    }

    ; Launch the app with both commands in quick succession
    UpdateInjectUi("Launching game...", 80)
    if !RunAdbRootCommand("am start -n jp.pokemon.pokemontcgp/jp.pokemon.pokemontcgp.UnityPlayerActivity") {
        ShowInjectStepError("start UnityPlayerActivity")
        return 0
    }
    Sleep, 100

    if !RunAdbRootCommand("am start -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity") {
        ShowInjectStepError("start com.unity3d.player.UnityPlayerActivity")
        return 0
    }

    return 1
}

; New function to get instance list
GetInstanceList(baseFolder) {
    instanceList := ""
    mumuFolder := getMumuFolder(baseFolder)

    ; Loop through all VM directories
    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        displayName := GetVmDisplayName(folder)

        if (displayName != "") {
            if (instanceList != "")
                instanceList .= "|"
            instanceList .= displayName
        }
    }

    return instanceList
}

FriendListHasId(list, id) {
    if (!IsObject(list) || !list.MaxIndex())
        return false
    Loop, % list.MaxIndex()
    {
        if (list[A_Index] = id)
            return true
    }
    return false
}

injectFriendSlotsToCsv() {
    global injectFriend2, injectFriend3, injectFriend4, injectFriend5, injectFriend6, injectFriend7, injectFriend8, injectFriend9, injectFriend10
    arr := [Trim(injectFriend2), Trim(injectFriend3), Trim(injectFriend4), Trim(injectFriend5), Trim(injectFriend6), Trim(injectFriend7), Trim(injectFriend8), Trim(injectFriend9), Trim(injectFriend10)]
    out := ""
    Loop % arr.MaxIndex() {
        val := arr[A_Index]
        if (val = "")
            continue
        if (out != "")
            out .= ","
        out .= val
    }
    return out
}

ValidateInjectFriendSlots() {
    global injectFriend2, injectFriend3, injectFriend4, injectFriend5, injectFriend6, injectFriend7, injectFriend8, injectFriend9, injectFriend10
    vals := [injectFriend2, injectFriend3, injectFriend4, injectFriend5, injectFriend6, injectFriend7, injectFriend8, injectFriend9, injectFriend10]
    Loop % vals.MaxIndex() {
        slot := A_Index + 1
        v := Trim(vals[A_Index])
        if (v = "")
            continue
        if (!RegExMatch(v, "^\d{16}$")) {
            MsgBox, 48, Friend codes, Slot %slot% must contain exactly 16 digits (numbers only).
            return false
        }
    }
    return true
}

; Count unique 16-digit friend codes after merging Settings.ini FriendID + optional extra field (same rules as _SendFriendRequest.ahk).
FriendRequestMergedCount(primaryRaw, extraGuiText) {
    list := []
    sid := Trim(primaryRaw)
    if (sid != "" && sid != "ERROR" && RegExMatch(sid, "^\d{16}$"))
        list.Push(sid)
    cleaned := RegExReplace(extraGuiText, "[\r\n]+", ",")
    cleaned := RegExReplace(cleaned, "\|+", ",")
    cleaned := RegExReplace(cleaned, "[\t; ]+", ",")
    Loop {
        if (!InStr(cleaned, ",,"))
            break
        StringReplace, cleaned, cleaned, `,,`,, All
    }
    cleaned := Trim(cleaned, " `t,")
    Loop, Parse, cleaned, `,
    {
        id := Trim(A_LoopField)
        if (!RegExMatch(id, "^\d{16}$"))
            continue
        if (!FriendListHasId(list, id))
            list.Push(id)
    }
    return list.MaxIndex() ? list.MaxIndex() : 0
}

; Refresh button handler
RefreshInstances:
    refreshedList := GetInstanceList(folderPath)
    GuiControl,, winTitle, |%refreshedList%
return

RunInstance:
    if (injectInProgress)
        return
    injectInProgress := 1
    SetInjectUiBusy(true)
    UpdateInjectUi("Starting selected instance...", 12)
    Gui, Submit, NoHide
    if (!ValidateInjectFriendSlots()) {
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }
    extraFriendIDs := injectFriendSlotsToCsv()
    settingsIni := A_ScriptDir . "\..\Settings.ini"
    IniRead, prSid, %settingsIni%, General, FriendID, ERROR
    mergedN := FriendRequestMergedCount(prSid, extraFriendIDs)
    if (mergedN > 10) {
        MsgBox, 48, Friend codes, Maximum 10 friend codes total (Settings.ini FriendID + optional extras in this window).`n`nYou have: %mergedN%.
        SetInjectUiBusy(false)
        injectInProgress := 0
        return
    }
    extraFriendForIni := extraFriendIDs
    Loop {
        if (!InStr(extraFriendForIni, ",,"))
            break
        StringReplace, extraFriendForIni, extraFriendForIni, `,,`,, All
    }
    extraFriendForIni := Trim(extraFriendForIni, " `t,")
    IniWrite, %extraFriendForIni%, InjectAccount.ini, UserSettings, injectExtraFriendIDs
    IniWrite, %sendFriendRequestAfterInject%, InjectAccount.ini, UserSettings, sendFriendRequestAfterInject
    mumuFolder := getMumuFolder(folderPath)
    ; Find the instance number matching the selected name
    instanceNum := ""
    Loop, Files, %mumuFolder%\vms\*, D
    {
        folder := A_LoopFileFullPath
        displayName := GetVmDisplayName(folder)
        if (displayName = winTitle) {
            RegExMatch(folder, "[^-]+$", instanceNum)
            break
        }
    }
    if (instanceNum != "") {
        mumuExe := mumuFolder . "\shell\MuMuPlayer.exe"
        if !FileExist(mumuExe)
            mumuExe := mumuFolder . "\nx_main\MuMuNxMain.exe"
        if FileExist(mumuExe) {
            Run, "%mumuExe%" -v "%instanceNum%"
            UpdateInjectUi("Instance launch command sent.", 100)
        } else {
            MsgBox, 16, Error, Could not find MuMuPlayer.exe at %mumuExe%
            UpdateInjectUi("Could not find MuMu executable.", 0)
        }
    }
    else {
        MsgBox, 16, Error, Could not find instance number for %winTitle%
        UpdateInjectUi("Selected instance not found in folder.", 0)
    }
    SetInjectUiBusy(false)
    injectInProgress := 0
return
