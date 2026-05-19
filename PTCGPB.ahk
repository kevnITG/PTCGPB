#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
#SingleInstance, force
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen
SetTitleMatchMode, 3
ListLines Off
Process, Priority, , A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
SendMode Input
DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution)

DllCall("Sleep","UInt",1)
DllCall("ntdll\ZwDelayExecution","Int",0,"Int64*",-5000)

#Include %A_ScriptDir%\Scripts\Include\
#Include Config.ahk
#Include Session.ahk
#Include Data.ahk
#Include ExtraConfig.ahk
#Include Gdip_All.ahk
#Include Gdip_Imagesearch.ahk
#Include ADB.ahk
#Include Logging.ahk
#Include FontListHelper.ahk
#Include ChooseColors.ahk
#Include DropDownColor.ahk
#Include SpecialEvent.ahk
#Include Utils.ahk
#Include AccountMetadata.ahk
#Include GitManager.ahk

version = Arturos PTCGP Bot

OnError("ErrorHandler")

githubUser := "kevnITG"
    ,repoName := "PTCGPB"
    ,localVersion := "v9.6.4"
    ,modVersion := "v0.9.6"
    ,scriptFolder := A_ScriptDir
    ,zipPath := A_Temp . "\update.zip"
    ,extractPath := A_Temp . "\update"
    ,modRepoUser := "Leanny"

global GUI_WIDTH := 690
global GUI_HEIGHT := 410
global MainGuiName

global ProcessedIDs := {}
global botMetadata := {}

OnMessage(0x4A, "ReceiveData")

if not A_IsAdmin
{
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

global botConfig := new BotConfig()
global session := new Session()
global dict := ""
global g_botStarted := false

PTCGPB_ResetCockpitLaunchMarker()
PTCGPB_RebuildTrayMenu()

lastPackID := parsePackData()
if(botConfig.packSettings.Count() = 0 || botConfig.packSettings.Count() = "")
    botConfig.set(lastPackID, 1, "Pack")

pokemonList := getKeyList(session.get("pokemonPackObj"))
parseDictionaryData("en")
parseDictionaryData("de")
parseDictionaryData("jp")
parseDictionaryData("cn")

botConfig.loadSettingsToConfig("ALL")
global g_runMainPref := (botConfig.get("runMain") ? 1 : 0)
global g_mainsPref := botConfig.get("Mains")
if (g_mainsPref = "" || (g_mainsPref + 0) <= 0)
    g_mainsPref := 1
global g_prevDeleteMethod := Trim(botConfig.get("deleteMethod"))

SetTimer, ShowSwipeSpeedToolTip, 50

hasInvalidScale := false
monitorScaleList := GetAllMonitorScales()
For idx, scaleValue in monitorScaleList {
    if(scaleValue != 100){
        hasInvalidScale := true
        break
    }
}

if (hasInvalidScale) {
    msgTitle := "Display Scale Warning"
    msgText := "WARNING: Display scale issue detected!`n`n"
        . "To ensure the program works correctly, ALL monitors must be set to 100% scale in Windows settings.`n`n"
        . "Please change your display scale to 100% and restart the program.`n`n"
        . "[!] If you are ABSOLUTELY SURE all your monitors are already at 100% (script detection error), you can choose to ignore this warning.`n`n"
        . "Do you want to ignore this warning and continue anyway?"

    MsgBox, 308, %msgTitle%, %msgText%

    IfMsgBox, No
    {
        ExitApp
    }
}

GuiLabel(labelText) {
    return RegExReplace(labelText, "[:：]\s*$", "")
}

BotLanguage := botConfig.get("BotLanguage")
if (!botConfig.get("IsLanguageSet")) {
    Gui, Add, Text,, Select Language
    BotLanguagelist := "English|中文|日本語|Deutsch"
    defaultChooseLang := 1
    if (botConfig.get("BotLanguage") != "") {
        Loop, Parse, BotLanguagelist, |
            if (A_LoopField = botConfig.get("BotLanguage")) {
                defaultChooseLang := A_Index
                break
            }
    }
    Gui, Add, DropDownList, vui_BotLanguage w200 choose%defaultChooseLang%, %BotLanguagelist%
    Gui, Add, Button, Default gNextStep, Next
    Gui, Show,, Language Selection
    Return
}

NextStep:
    Gui, Submit, NoHide
    GuiControlGet, BotLanguage, , ui_BotLanguage
    botConfig.set("BotLanguage", BotLanguage, "General")
    botConfig.set("IsLanguageSet", 1, "General")
    langMap := { "English": "en", "中文": "cn", "日本語": "jp", "Deutsch": "de" }
    botConfig.set("defaultBotLanguage", (langMap.HasKey(botConfig.get("BotLanguage")) ? langMap[botConfig.get("BotLanguage")] : 1), "General")
    botLang := botConfig.get("defaultBotLanguage")
    dict := dictionaryData[botLang]
    Gui, Destroy

    RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
    if (!botConfig.get("debugMode") && !botConfig.get("shownLicense")) {
        MsgBox, 64, % dict["Title"], % dict["Content"]
        botConfig.set("shownLicense", 1, "General")
        if (proxyEnabled)
            MsgBox, 64,, % dict["Notice"]
    }

    KillADBProcesses()
    CheckForUpdate()

    scriptName := StrReplace(A_ScriptName, ".ahk")
    winTitle := scriptName

    ; Reset InjectionCycleCount in all Scripts/*.ini files on startup
    Loop, Files, %A_ScriptDir%\Scripts\*.ini
    {
        IniRead, cycleCount, %A_LoopFileFullPath%, Metrics, InjectionCycleCount, ERROR
        if (cycleCount != "ERROR" && cycleCount != 0)
            IniWrite, 0, %A_LoopFileFullPath%, Metrics, InjectionCycleCount
    }

    Gui,+HWNDSGUI +Resize
    Gui, Color, 1E1E1E, 333333
    Gui, Font, s10 cWhite, Segoe UI
    MainGuiName := SGUI

    sectionColor := "cWhite"
    Gui, Add, GroupBox, x5 y0 w240 h50 %sectionColor%, Friend ID
    Gui, Add, Edit, vui_FriendID w180 x35 y20 h20 -E0x200 Background2A2A2A cWhite, % ((botConfig.get("FriendID") || botConfig.get("FriendID") = "ERROR") ? botConfig.get("FriendID") : "")

    if (botConfig.get("deleteMethod") != "Inject Wonderpick 96P+") {
        GuiControl, Hide, ui_FriendID
    }

    ; =================== UI - Instance Settings ===================
    sectionColor := "cWhite"
    Gui, Add, GroupBox, x5 y50 w240 h130 %sectionColor%, % dict["InstanceSettings"]
    Gui, Add, Text, x20 y75 %sectionColor%, % GuiLabel(dict["Txt_Instances"])
    Gui, Add, Edit, vui_Instances w50 x125 y75 h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("Instances")
    Gui, Add, Text, x20 y100 %sectionColor%, % GuiLabel(dict["Txt_Columns"])
    Gui, Add, Edit, vui_Columns w50 x125 y100 h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("Columns")
    Gui, Font, s8 cWhite, Segoe UI
    Gui, Add, Button, x185 y100 w50 h20 gArrangeWindows BackgroundTrans, % dict["btn_arrange"]
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, Text, x20 y125 %sectionColor%, % GuiLabel(dict["Txt_InstanceStartDelay"])
    Gui, Add, Edit, vui_instanceStartDelay w50 x125 y125 h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("instanceStartDelay")

    startupMethod := Trim(botConfig.get("deleteMethod"))
    runMainVisible := (startupMethod = "Inject Wonderpick 96P+") ? "" : " Hidden"
    mainsVisible := (startupMethod = "Inject Wonderpick 96P+" && botConfig.get("runMain")) ? "" : " Hidden"
    Gui, Add, Checkbox, % (botConfig.get("runMain") ? "Checked" : "") " vui_runMain gmainSettings x20 y150 " . sectionColor . runMainVisible, % GuiLabel(dict["Txt_runMain"])
    Gui, Add, Edit, % "vui_Mains w50 x125 y150 h20 -E0x200 Background2A2A2A " . sectionColor . " Center" . mainsVisible, % botConfig.get("Mains")

    ; =================== UI - Bot Settings ===================
    sectionColor := "c39FF14"
    ; Near top for Bot Mode + DDL; middle rows use botSettings_yShift; Sort anchored from inner bottom mirroring botSettings_topPad.
    botSettings_grpY := 185
    botSettings_grpH := 220
    botSettings_titleBand := 22
    botSettings_origY1 := 207
    botSettings_topPad := 6
    botSettings_bottomPad := botSettings_topPad
    botSettings_innerTop := botSettings_grpY + botSettings_titleBand
    botSettings_innerBot := botSettings_grpY + botSettings_grpH
    botSettings_yShift := (botSettings_innerTop + botSettings_topPad) - botSettings_origY1
    ; Lift label + DDL slightly more toward group top (does not shift rows below Min Packs).
    botSettings_modeLift := 4
    botY207 := botSettings_origY1 + botSettings_yShift - botSettings_modeLift
    botY227 := 227 + botSettings_yShift - botSettings_modeLift
    botY257 := 257 + botSettings_yShift
    botY277 := 277 + botSettings_yShift
    ; Lower only checkboxes slightly (spacing from Min Packs unchanged).
    botSettings_chkNudge := 10
    ; Three checkboxes evenly spaced (was 297→322 = +25 vs +20 above, so Spend looked “floating”).
    botSettings_chkStride := 20
    botY_chkPack := botY277 + botSettings_chkNudge
    botY_chkOpen := botY_chkPack + botSettings_chkStride
    botY_chkSpend := botY_chkOpen + botSettings_chkStride
    ; Sort block ~DDL plus label row; reserve bottom gap = botSettings_bottomPad (same knob as top).
    botSettings_sortTail := 24
    botY_sortDDL := botSettings_innerBot - botSettings_bottomPad - botSettings_sortTail
    botY_floorAboveSort := botY_chkSpend + 22 + 8
    if (botY_sortDDL < botY_floorAboveSort)
        botY_sortDDL := botY_floorAboveSort
    ; Nudge Sort slightly up (~air vs row above); reclamp vs floor against overlap with Spend HG.
    botSettings_sortVent := 6
    botY_sortDDL -= botSettings_sortVent
    if (botY_sortDDL < botY_floorAboveSort)
        botY_sortDDL := botY_floorAboveSort
    botY_sortTxt := botY_sortDDL + 5

    botY_accountRow := 260 + botSettings_yShift

    Gui, Add, GroupBox, x5 y%botSettings_grpY% w240 h%botSettings_grpH% %sectionColor%, % dict["BotSettings"]

    defaultDelete := 1
    botMethod := botConfig.get("deleteMethod")
    if (botMethod = "Create Bots (13P)")
        defaultDelete := 1
    else if (botMethod = "Inject 13P+")
        defaultDelete := 2
    else if (botMethod = "Inject Wonderpick 96P+")
        defaultDelete := 3
    else if (botMethod = "Inject Rewards")
        defaultDelete := 4
    Gui, Add, Text, x20 y%botY207% %sectionColor%, Bot Mode
    Gui, Add, DropDownList, vui_deleteMethod gdeleteSettings choose%defaultDelete% x20 y%botY227% w200 Background2A2A2A cWhite, Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+|Inject Rewards

    Gui, Add, Text, % "vui_injectWonderpickMinPacksText x20 y" . botY257 . " " . sectionColor . ((botMethod = "Inject Wonderpick 96P+") ? "" : " Hidden"), Min Packs:
    Gui, Add, Edit, % "vui_injectWonderpickMinPacks w40 x130 y" . botY257 . " h20 -E0x200 Background2A2A2A cWhite Center" . ((botMethod = "Inject Wonderpick 96P+") ? "" : " Hidden"), % botConfig.get("injectWonderpickMinPacks")
    Gui, Add, Checkbox, % (botConfig.get("packMethod") ? "Checked" : "") " vui_packMethod x20 y" . botY_chkPack . " " . sectionColor . ((botMethod = "Inject Wonderpick 96P+") ? "" : " Hidden"), % dict["Txt_packMethod"]
    Gui, Add, Checkbox, % (botConfig.get("openExtraPack") ? "Checked" : "") " vui_openExtraPack gopenExtraPackSettings x20 y" . botY_chkOpen . " " . sectionColor . ((botMethod = "Inject Wonderpick 96P+" || botMethod = "Inject 13P+") ? "" : " Hidden"), % dict["Txt_openExtraPack"]
    Gui, Add, Checkbox, % (botConfig.get("spendHourGlass") ? "Checked" : "") " vui_spendHourGlass gspendHourGlassSettings x20 y" . botY_chkSpend . " " . sectionColor . ((botMethod = "Create Bots (13P)" || botMethod = "Inject Rewards")? " Hidden":""), % dict["Txt_spendHourGlass"]

    Gui, Add, Text, % "x20 y" . botY_sortTxt . " " . sectionColor . " vui_SortByText", % dict["SortByText"]
    sortOption := 1
    if (botConfig.get("injectSortMethod") = "ModifiedDesc")
        sortOption := 2
    else if (botConfig.get("injectSortMethod") = "PacksAsc")
        sortOption := 3
    else if (botConfig.get("injectSortMethod") = "PacksDesc")
        sortOption := 4
    else if (botConfig.get("injectSortMethod") = "LastLoginAsc")
        sortOption := 5
    Gui, Add, DropDownList, % "vui_SortByDropdown gSortByDropdownHandler choose" . sortOption . " x90 y" . botY_sortDDL . " w150 Background2A2A2A cWhite", Oldest First|Newest First|Fewest Packs First|Most Packs First|Oldest Last Login

    Gui, Add, Text, % "x20 y" . botY_accountRow . " " . sectionColor . " vui_AccountNameText", % GuiLabel(dict["Txt_AccountName"])
    Gui, Add, Edit, % "vui_AccountName w90 x130 y" . botY_accountRow . " h20 -E0x200 Background2A2A2A cWhite Center", % botConfig.get("AccountName")

    GuiControlGet, curMethod, , ui_deleteMethod
    if (curMethod = "Create Bots (13P)") {
        GuiControl, Hide, ui_FriendID
        GuiControl, Hide, ui_SortByText
        GuiControl, Hide, ui_SortByDropdown
    } else {
        GuiControl, Hide, ui_AccountNameText
        GuiControl, Hide, ui_AccountName
    }

    ; =================== UI - Pack Selection ===================
    sectionColor := "cFFD700"
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, GroupBox, x255 y0 w215 h52 %sectionColor%, % dict["PackHeading"]

    Gui, Add, Button, x277 y19 w170 h25 gShowPackSelection vui_PackSelectionButton BackgroundTrans, Loading...
    UpdatePackSelectionButtonText()

    ; =================== UI - Inject WP Card Detection ===================
    sectionColor := "cFF4500"
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, GroupBox, x255 y57 w215 h52 %sectionColor%, % dict["CardDetection"]

    Gui, Add, Button, x277 y76 w170 h25 gShowCardDetection vui_CardDetectionButton BackgroundTrans, Loading...

    UpdateCardDetectionButtonText()

    ; =================== UI - Save for Trade ===================
    sectionColor := "c4169E1"
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, GroupBox, x255 y114 w215 h78 %sectionColor%, % dict["SaveForTrade"]

    Gui, Add, Button, x277 y133 w170 h25 gShowS4TSettings vui_S4TButton BackgroundTrans, Loading...

    Gui, Font, s7 cWhite, Segoe UI
    Gui, Add, Button, x297 y163 w130 h20 gOpenCardDatabase BackgroundTrans, Open Card Database

    UpdateS4TButtonText()

    ; =================== UI - Group Settings ===================
    sectionColor := "cWhite"
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, GroupBox, x255 y197 w215 h50 %sectionColor%, % dict["GroupSettings"]

    Gui, Add, Button, x277 y216 w170 h25 gShowGroupRerollSettings vui_GroupRerollButton BackgroundTrans, Loading...

    UpdateGroupRerollButtonText()

    ; =================== UI - Discord Settings ===================
    sectionColor := "c00FFFF"
    Gui, Font, s10 cWhite, Segoe UI
    Gui, Add, GroupBox, x255 y252 w215 h55 %sectionColor%, % dict["DiscordSettingsHeading"]
    Gui, Add, Button, x277 y271 w170 h25 gShowDiscordSettings vui_DiscordSettingsButton BackgroundTrans, Loading...
    UpdateDiscordSettingsButtonText()

    ; =================== UI - Time Settings ===================
    Gui, Font, s10 cWhite, Segoe UI
    sectionColor := "c9370DB"
    Gui, Add, GroupBox, x255 y312 w215 h93 %sectionColor%, % dict["TimeSettings"]
    Gui, Add, Text, x270 y332 %sectionColor%, % GuiLabel(dict["Txt_Delay"])
    Gui, Add, Edit, vui_Delay w34 x427 y330 h19 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("Delay")
    Gui, Add, Text, x270 y356 %sectionColor%, % GuiLabel(dict["Txt_SwipeSpeed"])
    Gui, Add, Edit, vui_swipeSpeed w34 x427 y354 h19 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("swipeSpeed")
    Gui, Add, Text, x270 y380 w150 %sectionColor%, % GuiLabel(dict["Txt_WaitTime"])
    Gui, Add, Edit, vui_waitTime w34 x427 y378 h19 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("waitTime")

    ; =================== UI - Description & Button ===================
    sectionColor := "cWhite"
    Gui, Add, GroupBox, x480 y0 w205 h405 %sectionColor%

    Gui, Font, s12 cWhite Bold
    Gui, Add, Text, x493 y20 w180 h50 Center BackgroundTrans cWhite, % dict["title_main"]
    Gui, Font, s10 cWhite Bold
    Gui, Add, Text, x493 y43 w180 h20 Center BackgroundTrans cWhite, % localVersion
    Gui, Font, s8 cWhite Bold
    Gui, Add, Text, x485 y63 w195 h18 Center BackgroundTrans cWhite, (Mod: Improve Card Detection)
    Gui, Font, s10 cWhite Bold
    Gui, Add, Text, x493 y93 w180 h20 Center BackgroundTrans cWhite, Modder: Lean && xedranort
    Gui, Add, Text, x493 y113 w180 h20 Center BackgroundTrans cWhite, % modVersion

    Gui, Add, Picture, gBuyMeCoffee x508 y145 w150, %A_ScriptDir%\GUI\Images\support_me_on_kofi.png

    ; =================== UI - Icon ===================
    Gui, Font, s10 cWhite
    Gui, Add, Picture, gOpenDiscord x518 y194 w32 h32, %A_ScriptDir%\GUI\Images\discord-icon.png
    Gui, Add, Picture, gOpenToolTip x568 y194 w32 h32, %A_ScriptDir%\GUI\Images\help-icon.png
    Gui, Add, Picture, gShowToolsAndSystemSettings vui_ToolsPicture x618 y195 w30 h30, %A_ScriptDir%\GUI\Images\tools-icon.png

    Gui, Font, s10 cWhite Bold
    Gui, Add, Button, x497 y246 w170 h34 gBalanceXMLs BackgroundTrans, % dict["btn_balance"]
    Gui, Add, Button, x497 y292 w170 h34 gLaunchAllMumu BackgroundTrans, % dict["btn_mumu"]
    Gui, Add, Button, gSave vui_StartBotButton x497 y338 w170 h34, Start Bot

    Gui, Font, s7 cGray
    Gui, Add, Text, x489 y376 w190 Center BackgroundTrans, CC BY-NC 4.0 international license

    Gui, Show, w%GUI_WIDTH% h%GUI_HEIGHT%, Arturo's PTCGP BOT

Return

mainSettings:
    global g_runMainPref, g_mainsPref
    Gui, Submit, NoHide
    GuiControlGet, isMainChecked, , ui_runMain
    visible := isMainChecked ? "Show" : "Hide"
    GuiControl, %visible%, ui_Mains
    GuiControlGet, curDeleteMethod, , ui_deleteMethod
    if (curDeleteMethod = "Inject Wonderpick 96P+") {
        g_runMainPref := isMainChecked ? 1 : 0
        GuiControlGet, curMains, , ui_Mains
        if (curMains != "")
            g_mainsPref := curMains
    }
return

deleteSettings:
    global g_runMainPref, g_mainsPref, g_prevDeleteMethod
    Gui, Submit, NoHide

    GuiControlGet, curDeleteMethod, , ui_deleteMethod
    curDeleteMethod := Trim(curDeleteMethod)
    if (curDeleteMethod = "")
        curDeleteMethod := Trim(botConfig.get("deleteMethod"))
    if (g_prevDeleteMethod = "Inject Wonderpick 96P+" && curDeleteMethod != "Inject Wonderpick 96P+") {
        GuiControlGet, snapRunMain, , ui_runMain
        GuiControlGet, snapMains, , ui_Mains
        g_runMainPref := snapRunMain ? 1 : 0
        if (snapMains != "")
            g_mainsPref := snapMains
    }
    if (curDeleteMethod != "Inject Wonderpick 96P+") {
        ; Save-for-trade Wonderpick-inject knobs only matter in Inject Wonderpick mode.
        botConfig.set("s4tWP", 0, "SaveForTrade")
        botConfig.set("s4tWPMinCards", 1, "SaveForTrade")
    }

    if (curDeleteMethod = "Create Bots (13P)") {
        GuiControl, Hide, ui_FriendID
        GuiControl, Hide, ui_spendHourGlass
        GuiControl, Hide, ui_packMethod
        GuiControl, Hide, ui_injectWonderpickMinPacksText
        GuiControl, Hide, ui_injectWonderpickMinPacks
        GuiControl, Hide, ui_openExtraPack
        GuiControl, Hide, ui_SortByText
        GuiControl, Hide, ui_SortByDropdown
        GuiControl, Show, ui_AccountNameText
        GuiControl, Show, ui_AccountName
        GuiControl, Hide, ui_WaitTime
        ; FriendID kept stored but only used when deleteMethod = "Inject Wonderpick 96P+"
    } else if (curDeleteMethod = "Inject Wonderpick 96P+") {
        GuiControl, Show, ui_FriendID
        GuiControl, Show, ui_spendHourGlass
        GuiControl, Show, ui_packMethod
        GuiControl, Show, ui_injectWonderpickMinPacksText
        GuiControl, Show, ui_injectWonderpickMinPacks
        GuiControl, Show, ui_openExtraPack
        GuiControl, Show, ui_SortByText
        GuiControl, Show, ui_SortByDropdown
        GuiControl, Hide, ui_AccountNameText
        GuiControl, Hide, ui_AccountName
        GuiControl, Show, ui_WaitTime
        GuiControl, Show, ui_runMain
        GuiControl,, ui_runMain, %g_runMainPref%
        GuiControl,, ui_Mains, %g_mainsPref%
        visible := g_runMainPref ? "Show" : "Hide"
        GuiControl, %visible%, ui_Mains
    } else if (curDeleteMethod = "Inject 13P+") {
        GuiControl, Hide, ui_FriendID
        GuiControl, Show, ui_spendHourGlass
        GuiControl, Hide, ui_packMethod
        GuiControl, Hide, ui_injectWonderpickMinPacksText
        GuiControl, Hide, ui_injectWonderpickMinPacks
        GuiControl, Show, ui_openExtraPack
        GuiControl, Show, ui_SortByText
        GuiControl, Show, ui_SortByDropdown
        GuiControl, Hide, ui_AccountNameText
        GuiControl, Hide, ui_AccountName
        GuiControl, Hide, ui_WaitTime
        ; FriendID kept stored but only used when deleteMethod = "Inject Wonderpick 96P+"
    } else if (curDeleteMethod = "Inject Rewards") {
        GuiControl, Hide, ui_FriendID
        GuiControl, Hide, ui_spendHourGlass
        GuiControl, Hide, ui_packMethod
        GuiControl, Hide, ui_injectWonderpickMinPacksText
        GuiControl, Hide, ui_injectWonderpickMinPacks
        GuiControl, Hide, ui_openExtraPack
        GuiControl, Show, ui_SortByText
        GuiControl, Show, ui_SortByDropdown
        GuiControl, Hide, ui_AccountNameText
        GuiControl, Hide, ui_AccountName
        GuiControl, Hide, ui_WaitTime
    }

    if (curDeleteMethod != "Inject Wonderpick 96P+") {
        GuiControl,, ui_runMain, 0
        GuiControl, Hide, ui_runMain
        GuiControl, Hide, ui_Mains
    }
    g_prevDeleteMethod := curDeleteMethod
    UpdateCardDetectionButtonText()
return

openExtraPackSettings:
    Gui, Submit, NoHide
    botConfig.set("openExtraPack", 1, "General")
    botConfig.set("spendHourGlass", 0, "General")
    GuiControl,, ui_spendHourGlass, 0
Return

spendHourGlassSettings:
    Gui, Submit, NoHide
    botConfig.set("openExtraPack", 0, "General")
    botConfig.set("spendHourGlass", 1, "General")
    GuiControl,, ui_openExtraPack, 0
Return

SortByDropdownHandler:
    Gui, Submit, NoHide
    GoSub, saveSortOption
return

saveSortOption:
    GuiControlGet, selectedOption,, ui_SortByDropdown
    if (selectedOption = "Oldest First")
        botConfig.set("injectSortMethod", "ModifiedAsc", "General")
    else if (selectedOption = "Newest First")
        botConfig.set("injectSortMethod", "ModifiedDesc", "General")
    else if (selectedOption = "Fewest Packs First")
        botConfig.set("injectSortMethod", "PacksAsc", "General")
    else if (selectedOption = "Most Packs First")
        botConfig.set("injectSortMethod", "PacksDesc", "General")
    else if (selectedOption = "Oldest Last Login")
        botConfig.set("injectSortMethod", "LastLoginAsc", "General")
    else
        botConfig.set("injectSortMethod", "ModifiedAsc", "General")
return

UpdateDiscordSettingsButtonText() {
    global botConfig, dict

    activeProfile := botConfig.get("groupRerollEnabled") ? "Group" : "Solo"
    activeWebhook := botConfig.get("groupRerollEnabled") ? botConfig.get("groupRerollDiscordWebhookURL") : botConfig.get("discordWebhookURL")
    statusText := dict["btn_discord"]
    fontColor := "cWhite"

    if (activeWebhook = "") {
        statusText := activeProfile . " webhook missing"
        fontColor := "cFF6666"
    } else {
        statusText := activeProfile . " Discord configured"
        fontColor := "cLime"
    }

    Gui, Font, s8 %fontColor%, Segoe UI
    GuiControl, Font, ui_DiscordSettingsButton
    GuiControl,, ui_DiscordSettingsButton, %statusText%
}

ShowDiscordSettings:
    ShowDiscordSettingsPopup(A_GuiControl)
return

ShowDiscordSettingsPopup(anchorCtl := "") {
    global botConfig, dict

    Gui, Submit, NoHide
    popupWidth := 540
    PTCGPB_PopupRightOfCtl(Trim(anchorCtl), popupWidth, 12, popupX, popupY)

    Gui, DiscordSettingsSelect:Destroy
    Gui, DiscordSettingsSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Discord Settings
    Gui, DiscordSettingsSelect:Color, 1E1E1E, 333333
    Gui, DiscordSettingsSelect:Font, s10 cWhite, Segoe UI

    soloDiscordColor := "cWhite"
    groupDiscordColor := "cFF4500"
    s4tDiscordColor := "c4169E1"
    heartBeatDiscordColor := "c00FFFF"
    ; S4T + Heartbeat: right-aligned labels immediately left of edits (widest heartbeat label drives column).
    discordRightLblW := 226
    discordLblEditGap := 10
    discordEditLX := 15 + discordRightLblW + discordLblEditGap
    discordEditWide := 259
    discordS4tSendXmlWide := discordEditLX + discordEditWide - 15

    Gui, DiscordSettingsSelect:Add, GroupBox, x10 y10 w255 h150 %soloDiscordColor%, Solo Reroll InjectWP
    Gui, DiscordSettingsSelect:Add, Text, x20 y35 %soloDiscordColor%, Discord ID
    Gui, DiscordSettingsSelect:Add, Edit, vui_soloDiscordUserId_Popup w225 x20 y55 h20 -E0x200 Background2A2A2A cWhite, % botConfig.get("discordUserId")
    Gui, DiscordSettingsSelect:Add, Text, x20 y82 %soloDiscordColor%, Webhook URL
    Gui, DiscordSettingsSelect:Add, Edit, vui_soloDiscordWebhookURL_Popup w225 x20 y102 h20 -E0x200 Background2A2A2A cWhite, % botConfig.get("discordWebhookURL")
    Gui, DiscordSettingsSelect:Add, Checkbox, % (botConfig.get("sendAccountXml") ? "Checked" : "") " vui_soloSendAccountXml_Popup x20 y130 w225 Right " . soloDiscordColor, Send Account XML

    Gui, DiscordSettingsSelect:Add, GroupBox, x275 y10 w255 h150 %groupDiscordColor%, Group Reroll InjectWP
    Gui, DiscordSettingsSelect:Add, Text, x285 y35 %groupDiscordColor%, Discord ID
    Gui, DiscordSettingsSelect:Add, Edit, vui_groupDiscordUserId_Popup w225 x285 y55 h20 -E0x200 Background2A2A2A cWhite, % botConfig.get("groupRerollDiscordUserId")
    Gui, DiscordSettingsSelect:Add, Text, x285 y82 %groupDiscordColor%, Webhook URL
    Gui, DiscordSettingsSelect:Add, Edit, vui_groupDiscordWebhookURL_Popup w225 x285 y102 h20 -E0x200 Background2A2A2A cWhite, % botConfig.get("groupRerollDiscordWebhookURL")
    Gui, DiscordSettingsSelect:Add, Checkbox, % (botConfig.get("groupRerollSendAccountXml") ? "Checked" : "") " vui_groupSendAccountXml_Popup x285 y130 w225 Right " . groupDiscordColor, Send Account XML

    Gui, DiscordSettingsSelect:Add, GroupBox, x10 y170 w520 h120 %s4tDiscordColor%, Save for Trade
    Gui, DiscordSettingsSelect:Add, Text, x15 y195 w%discordRightLblW% Right %s4tDiscordColor%, Discord ID
    Gui, DiscordSettingsSelect:Add, Edit, vui_s4tDiscordUserId_Popup x%discordEditLX% y192 h20 w%discordEditWide% -E0x200 Background2A2A2A cWhite, % botConfig.get("s4tDiscordUserId")
    Gui, DiscordSettingsSelect:Add, Text, x15 y225 w%discordRightLblW% Right %s4tDiscordColor%, Webhook URL
    Gui, DiscordSettingsSelect:Add, Edit, vui_s4tDiscordWebhookURL_Popup x%discordEditLX% y222 h20 w%discordEditWide% -E0x200 Background2A2A2A cWhite, % botConfig.get("s4tDiscordWebhookURL")
    Gui, DiscordSettingsSelect:Add, Checkbox, % (botConfig.get("s4tSendAccountXml") ? "Checked" : "") " vui_s4tSendAccountXml_Popup x15 y255 w" . discordS4tSendXmlWide . " Right " . s4tDiscordColor, Send Account XML

    Gui, DiscordSettingsSelect:Add, GroupBox, x10 y300 w520 h205 %heartBeatDiscordColor%, Heartbeat
    Gui, DiscordSettingsSelect:Add, Checkbox, % (botConfig.get("heartBeat") ? "Checked" : "") " vui_heartBeat_Popup x20 y325 " . heartBeatDiscordColor, % dict["Txt_heartBeat"]
    Gui, DiscordSettingsSelect:Add, Text, x15 y355 w%discordRightLblW% Right %heartBeatDiscordColor%, Name
    Gui, DiscordSettingsSelect:Add, Edit, vui_heartBeatName_Popup x%discordEditLX% y352 h20 w%discordEditWide% -E0x200 Background2A2A2A cWhite, % botConfig.get("heartBeatName")
    Gui, DiscordSettingsSelect:Add, Text, x15 y385 w%discordRightLblW% Right %heartBeatDiscordColor%, Solo HB Webhook URL
    Gui, DiscordSettingsSelect:Add, Edit, vui_heartBeatWebhookURL_Popup x%discordEditLX% y382 h20 w%discordEditWide% -E0x200 Background2A2A2A cWhite, % botConfig.get("heartBeatWebhookURL")
    Gui, DiscordSettingsSelect:Add, Text, x15 y415 w%discordRightLblW% Right %heartBeatDiscordColor%, Solo Detailed HB Webhook URL
    Gui, DiscordSettingsSelect:Add, Edit, vui_heartBeatOwnerWebHookURL_Popup x%discordEditLX% y412 h20 w%discordEditWide% -E0x200 Background2A2A2A cWhite, % botConfig.get("heartBeatOwnerWebHookURL")
    Gui, DiscordSettingsSelect:Add, Text, x15 y445 w%discordRightLblW% Right %heartBeatDiscordColor%, Group HB Webhook URL
    Gui, DiscordSettingsSelect:Add, Edit, vui_groupHeartBeatWebhookURL_Popup x%discordEditLX% y442 h20 w%discordEditWide% -E0x200 Background2A2A2A cWhite, % botConfig.get("groupRerollHeartBeatWebhookURL")
    Gui, DiscordSettingsSelect:Add, Text, x15 y475 w%discordRightLblW% Right %heartBeatDiscordColor%, HB Delay (min)
    Gui, DiscordSettingsSelect:Add, Edit, vui_heartBeatDelay_Popup w60 x%discordEditLX% y472 h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("heartBeatDelay")

    Gui, DiscordSettingsSelect:Add, Button, x185 y520 w80 h30 gApplyDiscordSettings, Apply
    Gui, DiscordSettingsSelect:Add, Button, x275 y520 w80 h30 gCancelDiscordSettings, Cancel
    Gui, DiscordSettingsSelect:Show, x%popupX% y%popupY% w540 h565
}
return

ApplyDiscordSettings:
    Gui, DiscordSettingsSelect:Submit, NoHide

    GoSub, saveDiscordSettings

    Gui, DiscordSettingsSelect:Destroy

    Gui, 1:Default

    UpdateDiscordSettingsButtonText()
return

saveDiscordSettings:
    botConfig.set("discordUserId", ui_soloDiscordUserId_Popup, "Wonderpick")
    botConfig.set("discordWebhookURL", ui_soloDiscordWebhookURL_Popup, "Wonderpick")
    botConfig.set("sendAccountXml", ui_soloSendAccountXml_Popup, "Wonderpick")

    botConfig.set("groupRerollDiscordUserId", ui_groupDiscordUserId_Popup, "GroupReroll")
    botConfig.set("groupRerollDiscordWebhookURL", ui_groupDiscordWebhookURL_Popup, "GroupReroll")
    botConfig.set("groupRerollSendAccountXml", ui_groupSendAccountXml_Popup, "GroupReroll")

    botConfig.set("s4tDiscordUserId", ui_s4tDiscordUserId_Popup, "SaveForTrade")
    botConfig.set("s4tDiscordWebhookURL", ui_s4tDiscordWebhookURL_Popup, "SaveForTrade")
    botConfig.set("s4tSendAccountXml", ui_s4tSendAccountXml_Popup, "SaveForTrade")

    botConfig.set("heartBeat", ui_heartBeat_Popup, "General")
    botConfig.set("heartBeatName", ui_heartBeatName_Popup, "General")
    botConfig.set("heartBeatWebhookURL", ui_heartBeatWebhookURL_Popup, "General")
    botConfig.set("groupRerollHeartBeatWebhookURL", ui_groupHeartBeatWebhookURL_Popup, "GroupReroll")
    botConfig.set("heartBeatOwnerWebHookURL", ui_heartBeatOwnerWebHookURL_Popup, "General")
    if (ui_heartBeatDelay_Popup = "" || (ui_heartBeatDelay_Popup + 0) <= 0)
        botConfig.set("heartBeatDelay", 30, "General")
    else
        botConfig.set("heartBeatDelay", ui_heartBeatDelay_Popup, "General")
return

CancelDiscordSettings:
    Gui, DiscordSettingsSelect:Destroy
return

GetActiveHeartbeatWebhookURL() {
    global botConfig

    if (botConfig.get("groupRerollEnabled"))
        return botConfig.get("groupRerollHeartBeatWebhookURL")

    return botConfig.get("heartBeatWebhookURL")
}

ValidateDiscordSettingsBeforeStart() {
    global botConfig

    missing := ""

    if (botConfig.get("groupRerollEnabled")) {
        if (botConfig.get("groupRerollDiscordWebhookURL") = "")
            missing .= "- Group Reroll webhook is empty. If your old webhook was used for Group Reroll, copy it into the Group Reroll profile.`n"
    } else {
        if (botConfig.get("discordWebhookURL") = "")
            missing .= "- Solo webhook is empty.`n"
    }

    if (botConfig.get("s4tEnabled") && !botConfig.get("s4tSilent") && botConfig.get("s4tDiscordWebhookURL") = "")
        missing .= "- Save for Trade webhook is empty.`n"

    heartbeatNeedsUserWebhook := botConfig.get("heartBeat") && (botConfig.get("groupRerollEnabled") || botConfig.get("heartBeatOwnerWebHookURL") = "")
    if (heartbeatNeedsUserWebhook && GetActiveHeartbeatWebhookURL() = "") {
        activeHeartbeatProfile := botConfig.get("groupRerollEnabled") ? "Group Reroll" : "Solo"
        missing .= "- " . activeHeartbeatProfile . " heartbeat webhook is empty.`n"
    }

    if (missing = "")
        return true

    msg := "Some Discord webhook settings are missing:`n`n" . missing
    msg .= "`nOpen Discord Settings now? Select No to continue without those Discord messages."
    MsgBox, 52, Missing Discord Webhooks, %msg%
    IfMsgBox, Yes
    {
        ShowDiscordSettingsPopup()
        return false
    }

    return true
}

; Opens a popup to the right of a main-window control at the same baseline (top-aligned).
; If anchorCtl is empty, center horizontally from popupWidth in the active or main window client area.
PTCGPB_PopupRightOfCtl(anchorCtl, popupWidth, gapPx, ByRef outX, ByRef outY) {
    global MainGuiName

    ctl := Trim(anchorCtl)
    mainWinTit := "ahk_id " . MainGuiName
    WinGetPos, mwX, mwY, mwW,, %mainWinTit%
    if !mwW
        WinGetPos, mwX, mwY, mwW,, A

    outY := mwY + 30
    if (ctl = "") {
        outX := mwW ? (mwX + Floor((mwW - popupWidth) / 2)) : (mwX + 40)
        return
    }
    GuiControlGet, tcx,, x, %ctl%, %mainWinTit%
    if ErrorLevel {
        outX := mwW ? (mwX + Floor((mwW - popupWidth) / 2)) : (mwX + 40)
        return
    }
    GuiControlGet, tcy,, y, %ctl%, %mainWinTit%
    GuiControlGet, tcw,, w, %ctl%, %mainWinTit%

    outX := mwX + tcx + tcw + gapPx
    outY := mwY + tcy
}

; =================== UI - Pack Selection(New Window, Details) ===================

UpdatePackSelectionButtonText() {
    global botConfig, dict

    selectedPacks := []

    For idx, value in botConfig.packSettings {
        if(value)
            selectedPacks.Push(dict["Txt_" . idx])
    }

    packCount := selectedPacks.MaxIndex() ? selectedPacks.MaxIndex() : 0

    if (packCount = 0) {
        buttonText := "Select..."
        fontSize := 8
    } else if (packCount = 1) {
        buttonText := selectedPacks[1]
        if (StrLen(buttonText) > 15)
            fontSize := 7
        else
            fontSize := 8
    } else if (packCount <= 2) {
        buttonText := ""
        Loop, % packCount {
            buttonText .= selectedPacks[A_Index]
            if (A_Index < packCount)
                buttonText .= ", "
        }
        fontSize := 7
    } else {
        buttonText := selectedPacks[1] . " +" . (packCount - 1) . " more"
        fontSize := 7
    }

    Gui, Font, s%fontSize% cWhite, Segoe UI
    GuiControl,, ui_PackSelectionButton, %buttonText%
    GuiControl, Font, ui_PackSelectionButton
}

ShowPackSelection:
    Gui, Submit, NoHide

    Gui, PackSelect:Destroy
    Gui, PackSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Pack Selection
    Gui, PackSelect:Color, 1E1E1E, 333333
    Gui, PackSelect:Font, s10 cWhite, Segoe UI

    windowWidth := 10
    seriesColumnSize := 170
    yInitSeries := 35
    xInitSeries := 10
    xUncategorized := 360
    maxHeight := 35
    lastSeriesXPos := 10

    seriesList := {}
    For idx, packInfo in session.get("pokemonPackObj") {
        packSeriesValue := packInfo["Series"]
        seriesList[packSeriesValue] := true
    }

    seriesLoopIdx := 1
    For seriesValue, notUsedValue in seriesList {
        if(seriesValue == "U")
            Continue

        seriesXPos := xInitSeries + ((seriesLoopIdx - 1) * seriesColumnSize)
        packYPos := yInitSeries
        Gui, PackSelect:Add, Text, % "x" . seriesXPos . " y10 cWhite", % seriesValue . "-Series"

        For idx, packInfo in session.get("pokemonPackObj") {
            if(packInfo["Series"] != seriesValue)
                continue

            packID := packInfo.PackID
            viewPackName := dict["Txt_" . packID] ? dict["Txt_" . packID] : packID
            isChecked := BotConfig.get(packID) ? "Checked" : ""

            Gui, PackSelect:Add, Checkbox, vui_Select_%packID% %isChecked% x%seriesXPos% y%packYPos% cWhite, %viewPackName%
            packYPos += 25
        }

        if (maxHeight < packYPos)
            maxHeight := packYPos

        lastSeriesXPos := seriesXPos
        seriesLoopIdx += 1
    }
    windowWidth := lastSeriesXPos + seriesColumnSize

    ; Uncategorized(For future)
    uncategorizedList := []
    For idx, packInfo in session.get("pokemonPackObj") {
        if(packInfo["Series"] != "U")
            continue

        uncategorizedList.Push(packInfo["PackID"])
    }

    if(uncategorizedList.MaxIndex() > 0){
        xUncategorized := lastSeriesXPos + seriesColumnSize
        yUncategorized := 53
        windowWidth := xUncategorized + seriesColumnSize
        Gui, PackSelect:Add, Text, % "x" . xUncategorized . " y10 cWhite", Uncategorized`n(Temporary, Update)

        For idx, packID in uncategorizedList {
            viewPackName := dict["Txt_" . packID] ? dict["Txt_" . packID] : packID
            isChecked := BotConfig.get(packID) ? "Checked" : ""

            Gui, PackSelect:Add, Checkbox, vui_Select_%packID% %isChecked% x%xUncategorized% y%yUncategorized% cWhite, %viewPackName%
            yUncategorized += 25
        }
    }

    yPos := maxHeight + 10
    packButtonX := (windowWidth - 170) / 2
    packCancelButtonX := packButtonX + 90
    Gui, PackSelect:Add, Button, x%packButtonX% y%yPos% w80 h30 gApplyPackSelection, Apply
    Gui, PackSelect:Add, Button, x%packCancelButtonX% y%yPos% w80 h30 gCancelPackSelection, Cancel
    yPos += 40

    PTCGPB_PopupRightOfCtl("ui_PackSelectionButton", windowWidth, 12, popupX, popupY)
    Gui, PackSelect:Show, x%popupX% y%popupY% w%windowWidth% h%yPos%
return

ApplyPackSelection:
    Gui, PackSelect:Submit, NoHide
    GoSub, savePackSelection
    Gui, PackSelect:Destroy

    Gui, 1:Default

    UpdatePackSelectionButtonText()
return

savePackSelection:
    For idx, packObj in session.get("pokemonPackObj") {
        packID := packObj.PackID

        GuiControlGet, state,, ui_Select_%packID%
        botConfig.set(packID, (state == "") ? botConfig.get(packID) : state, "Pack")
    }
return

CancelPackSelection:
    Gui, PackSelect:Destroy
return

; =================== UI - Inject WP Card Detection(New Window, Details) ===================
UpdateCardDetectionButtonText() {
    global botConfig

    curDm := ""
    GuiControlGet, curDm,, ui_deleteMethod
    if (ErrorLevel || curDm = "")
        curDm := botConfig.get("deleteMethod")

    if (curDm != "Inject Wonderpick 96P+") {
        Gui, Font, s8 cGray, Segoe UI
        GuiControl, Font, ui_CardDetectionButton
        GuiControl,, ui_CardDetectionButton, Inject 96P+ only
        return
    }

    enabledOptions := []

    if (botConfig.get("FullArtCheck"))
        enabledOptions.Push("Full Art")
    if (botConfig.get("TrainerCheck"))
        enabledOptions.Push("Trainer")
    if (botConfig.get("RainbowCheck"))
        enabledOptions.Push("Rainbow")
    if (botConfig.get("PseudoGodPack"))
        enabledOptions.Push("Double 2★")
    if (botConfig.get("WishlistCheck"))
        enabledOptions.Push("Wishlist")
    if (botConfig.get("InvalidCheck"))
        enabledOptions.Push("Ignore Invalid")

    statusText := ""
    if (botConfig.get("minStars") > 0)
        statusText := "Min GP 2★: " . botConfig.get("minStars")

    if (enabledOptions.Length() > 0) {
        if (statusText != "")
            statusText .= " | "
        statusText .= enabledOptions[1]
        if (enabledOptions.Length() > 1)
            statusText .= " +" . (enabledOptions.Length() - 1)
    } else if (statusText = "") {
        statusText := "Configure settings..."
    }

    Gui, Font, s8 cWhite, Segoe UI
    GuiControl, Font, ui_CardDetectionButton
    GuiControl,, ui_CardDetectionButton, %statusText%
}

ShowCardDetection:
    Gui, Submit, NoHide

    GuiControlGet, curMethod, , ui_deleteMethod
    if (curMethod = "Create Bots (13P)" || curMethod = "Inject 13P+"  || curMethod = "Inject Rewards") {
        MsgBox, 64, InjectWP Card Detection, Wonderpick Card Detection is for 'Inject Wonderpick 96P+' mode.`n`nTo find cards to trade, use 'Save for Trade' settings instead.
        return
    }

    PTCGPB_PopupRightOfCtl("ui_CardDetectionButton", 230, 12, popupX, popupY)

    Gui, CardDetect:Destroy
    Gui, CardDetect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Wonderpick Card Detection Settings
    Gui, CardDetect:Color, 1E1E1E, 333333
    Gui, CardDetect:Font, s10 cWhite, Segoe UI

    yPos := 15

    Gui, CardDetect:Add, Text, x15 y%yPos% cWhite, Min GP 2★:
    Gui, CardDetect:Add, Edit, vui_minStars_Popup w20 x140 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, % (botConfig.get("minStars") ? botConfig.get("minStars") : 0)
    yPos += 25

    Gui, CardDetect:Add, Checkbox, % (botConfig.get("FullArtCheck") ? "Checked" : "") " vui_FullArtCheck_Popup x15 y" . yPos . " cWhite", Single Full Art 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (botConfig.get("TrainerCheck") ? "Checked" : "") " vui_TrainerCheck_Popup x15 y" . yPos . " cWhite", Single Trainer 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (botConfig.get("RainbowCheck") ? "Checked" : "") " vui_RainbowCheck_Popup x15 y" . yPos . " cWhite", Single Rainbow 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (botConfig.get("PseudoGodPack") ? "Checked" : "") " vui_PseudoGodPack_Popup x15 y" . yPos . " cWhite", Double 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (botConfig.get("WishlistCheck") ? "Checked" : "") " vui_WishlistCheck_Popup x15 y" . yPos . " cWhite", Wishlist 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (botConfig.get("InvalidCheck") ? "Checked" : "") " vui_InvalidCheck_Popup x15 y" . yPos . " cWhite", Ignore Invalid Packs
    yPos += 35

    Gui, CardDetect:Add, Button, x20 y%yPos% w90 h30 gApplyCardDetection, Apply
    Gui, CardDetect:Add, Button, x120 y%yPos% w90 h30 gCancelCardDetection, Cancel
    yPos += 40

    Gui, CardDetect:Show, x%popupX% y%popupY% w230 h%yPos%
return

ApplyCardDetection:
    Gui, CardDetect:Submit, NoHide

    GoSub, saveCardDetection

    Gui, CardDetect:Destroy

    Gui, 1:Default

    UpdateCardDetectionButtonText()
return

saveCardDetection:
    botConfig.set("minStars", ui_minStars_Popup, "Wonderpick")
    botConfig.set("FullArtCheck", ui_FullArtCheck_Popup, "Wonderpick")
    botConfig.set("TrainerCheck", ui_TrainerCheck_Popup, "Wonderpick")
    botConfig.set("RainbowCheck", ui_RainbowCheck_Popup, "Wonderpick")
    botConfig.set("PseudoGodPack", ui_PseudoGodPack_Popup, "Wonderpick")
    botConfig.set("WishlistCheck", ui_WishlistCheck_Popup, "Wonderpick")
    botConfig.set("InvalidCheck", ui_InvalidCheck_Popup, "Wonderpick")
return

CancelCardDetection:
    Gui, CardDetect:Destroy
return

; =================== UI - Group Settings(New Window, Details) ===================
UpdateGroupRerollButtonText() {
    global botConfig, dict

    if (!botConfig.get("groupRerollEnabled")) {
        Gui, Font, s8 cRed, Segoe UI
        GuiControl, Font, ui_GroupRerollButton
        GuiControl,, ui_GroupRerollButton, % dict["Txt_Disabled"]
        return
    }

    idsStatus := (botConfig.get("mainIdsURL") != "" && StrLen(botConfig.get("mainIdsURL")) > 5) ? "✓" : "✗"
    vipStatus := (botConfig.get("vipIdsURL") != "" && StrLen(botConfig.get("vipIdsURL")) > 5) ? "✓" : "✗"

    statusText := "Enabled"
    if (botConfig.get("autoUseGPTest"))
        statusText .= " + Auto"
    if (botConfig.get("applyRoleFilters"))
        statusText .= " + Roles"
    statusText .= " | IDs " . idsStatus . " VIP " . vipStatus

    Gui, Font, s7 cLime, Segoe UI
    GuiControl, Font, ui_GroupRerollButton
    GuiControl,, ui_GroupRerollButton, %statusText%
}

ShowGroupRerollSettings:
    Gui, Submit, NoHide
    PTCGPB_PopupRightOfCtl("ui_GroupRerollButton", 250, 12, popupX, popupY)

    Gui, GroupRerollSelect:Destroy
    Gui, GroupRerollSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Group Reroll Settings
    Gui, GroupRerollSelect:Color, 1E1E1E, 333333
    Gui, GroupRerollSelect:Font, s10 cWhite, Segoe UI

    if (botConfig.get("gpTestWaitTime") = "" || (botConfig.get("gpTestWaitTime") + 0) <= 0)
        botConfig.set("gpTestWaitTime", 150, "GroupReroll")

    yPos := 15
    Gui, GroupRerollSelect:Add, Checkbox, % (botConfig.get("groupRerollEnabled") ? "Checked" : "") " vui_groupRerollEnabled_Popup x15 y" . yPos . " cWhite", Enable Group Reroll
    yPos += 35

    Gui, GroupRerollSelect:Add, Text, x15 y%yPos% cWhite, ids.txt API URL:
    yPos += 20
    Gui, GroupRerollSelect:Add, Edit, vui_mainIdsURL_Popup w220 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, % botConfig.get("mainIdsURL")
    yPos += 35

    Gui, GroupRerollSelect:Add, Text, x15 y%yPos% cWhite, vip_ids.txt API URL:
    yPos += 20
    Gui, GroupRerollSelect:Add, Edit, vui_vipIdsURL_Popup w220 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, % botConfig.get("vipIdsURL")
    yPos += 35

    Gui, GroupRerollSelect:Add, Checkbox, % (botConfig.get("autoUseGPTest") ? "Checked" : "") " vui_autoUseGPTest_Popup x15 y" . yPos . " cWhite", Auto GPTest (s)
    yPos += 20
    Gui, GroupRerollSelect:Add, Edit, vui_TestTime_Popup w50 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("TestTime")
    yPos += 35
    Gui, GroupRerollSelect:Add, Text, x15 y%yPos% cWhite, GP Test mode:
    yPos += 20
    gpTestModeChoose := botConfig.get("hasUnopenedPack") ? 2 : 1
    Gui, GroupRerollSelect:Add, DropDownList, vui_gpTestMode_Popup choose%gpTestModeChoose% gGroupRerollGpTestMode x15 y%yPos% w210 Background2A2A2A cWhite, Standard|Unopened Pack
    yPos += 30
    Gui, GroupRerollSelect:Add, Text, vui_gpTestWaitLabel x15 y%yPos% cWhite, GP Test Wait (s):
    yPos += 20
    Gui, GroupRerollSelect:Add, Edit, vui_gpTestWaitTime_Popup w50 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("gpTestWaitTime")
    yPos += 30
    GroupReroll_yRoleExpanded := yPos
    GroupReroll_yRoleCollapsed := GroupReroll_yRoleExpanded - 50
    Gui, GroupRerollSelect:Add, Checkbox, % (botConfig.get("applyRoleFilters") ? "Checked" : "") " vui_applyRoleFilters_Popup x15 y" . yPos . " cWhite", Role-Based Filters
    yPos += 40
    Gui, GroupRerollSelect:Add, Button, vui_GroupRerollApplyBtn x30 y%yPos% w90 h30 gApplyGroupRerollSettings, Apply
    Gui, GroupRerollSelect:Add, Button, vui_GroupRerollCancelBtn x130 y%yPos% w90 h30 gCancelGroupRerollSettings, Cancel
    GroupReroll_yBtnExpanded := yPos
    GroupReroll_yBtnCollapsed := GroupReroll_yBtnExpanded - 50
    yPos += 40

    Gui, GroupRerollSelect:Default
    if (botConfig.get("hasUnopenedPack")) {
        GuiControl, Hide, ui_gpTestWaitLabel
        GuiControl, Hide, ui_gpTestWaitTime_Popup
        GuiControl, Move, ui_applyRoleFilters_Popup, x15 y%GroupReroll_yRoleCollapsed%
        GuiControl, Move, ui_GroupRerollApplyBtn, x30 y%GroupReroll_yBtnCollapsed%
        GuiControl, Move, ui_GroupRerollCancelBtn, x130 y%GroupReroll_yBtnCollapsed%
        groupRerollShowH := GroupReroll_yBtnCollapsed + 40
    } else
        groupRerollShowH := yPos
    Gui, GroupRerollSelect:Show, x%popupX% y%popupY% w250 h%groupRerollShowH%
return

GroupRerollGpTestMode:
    Gui, GroupRerollSelect:Default
    GuiControlGet, gpModeNow,, ui_gpTestMode_Popup
    isUnopened := (gpModeNow = "Unopened Pack")
    if (isUnopened) {
        GuiControl, Hide, ui_gpTestWaitLabel
        GuiControl, Hide, ui_gpTestWaitTime_Popup
        GuiControl, Move, ui_applyRoleFilters_Popup, x15 y%GroupReroll_yRoleCollapsed%
        GuiControl, Move, ui_GroupRerollApplyBtn, x30 y%GroupReroll_yBtnCollapsed%
        GuiControl, Move, ui_GroupRerollCancelBtn, x130 y%GroupReroll_yBtnCollapsed%
        hNow := GroupReroll_yBtnCollapsed + 40
    } else {
        GuiControl, Show, ui_gpTestWaitLabel
        GuiControl, Show, ui_gpTestWaitTime_Popup
        GuiControl, Move, ui_applyRoleFilters_Popup, x15 y%GroupReroll_yRoleExpanded%
        GuiControl, Move, ui_GroupRerollApplyBtn, x30 y%GroupReroll_yBtnExpanded%
        GuiControl, Move, ui_GroupRerollCancelBtn, x130 y%GroupReroll_yBtnExpanded%
        hNow := GroupReroll_yBtnExpanded + 40
    }
    Gui, GroupRerollSelect:Show, w250 h%hNow%
return

ApplyGroupRerollSettings:
    Gui, GroupRerollSelect:Submit, NoHide

    GoSub, saveGroupReroll

    Gui, GroupRerollSelect:Destroy

    Gui, 1:Default

    UpdateGroupRerollButtonText()
    UpdateDiscordSettingsButtonText()
return

saveGroupReroll:
    botConfig.set("groupRerollEnabled", ui_groupRerollEnabled_Popup, "GroupReroll")
    botConfig.set("mainIdsURL", ui_mainIdsURL_Popup, "GroupReroll")
    botConfig.set("vipIdsURL", ui_vipIdsURL_Popup, "GroupReroll")
    botConfig.set("autoUseGPTest", ui_autoUseGPTest_Popup, "GroupReroll")
    botConfig.set("TestTime", ui_TestTime_Popup, "GroupReroll")
    botConfig.set("gpTestWaitTime", ui_gpTestWaitTime_Popup, "GroupReroll")

    if (ui_gpTestWaitTime_Popup = "" || (ui_gpTestWaitTime_Popup + 0) <= 0)
        botConfig.set("gpTestWaitTime", 150, "GroupReroll")
    else
        botConfig.set("gpTestWaitTime", ui_gpTestWaitTime_Popup, "GroupReroll")

    newUnopened := (ui_gpTestMode_Popup = "Unopened Pack") ? 1 : 0
    priorHasUnopened := (botConfig.get("hasUnopenedPack") + 0)
    if (newUnopened && !priorHasUnopened) {
        confirmUP := dict["Msg_UnopenedPack_p1"] . "`n`n" . dict["Msg_UnopenedPack_p2"] . "`n`n" . dict["Msg_UnopenedPack_p3"] . "`n`n" . dict["Msg_UnopenedPack_p4"]
        MsgBox, 48, % dict["Msg_UnopenedPackTitle"], %confirmUP%
    }
    botConfig.set("hasUnopenedPack", newUnopened, "GroupReroll")
    botConfig.set("applyRoleFilters", ui_applyRoleFilters_Popup, "GroupReroll")
return

CancelGroupRerollSettings:
    Gui, GroupRerollSelect:Destroy
return

; =================== UI - Save for Trade(New Window, Details) ===================
UpdateS4TButtonText() {
    global botConfig, dict

    if (!botConfig.get("s4tEnabled")) {
        Gui, Font, s8 cRed, Segoe UI
        GuiControl, Font, ui_S4TButton
        GuiControl,, ui_S4TButton, % dict["Txt_S4TDisabled"]
        return
    }

    enabledOptions := []
    if (botConfig.get("s4t1Star"))
        enabledOptions.Push("1★")
    if (botConfig.get("s4t4Dmnd"))
        enabledOptions.Push("4◆")
    if (botConfig.get("s4t3Dmnd"))
        enabledOptions.Push("3◆")
    if (botConfig.get("s4tTrainer"))
        enabledOptions.Push("Trainer")
    if (botConfig.get("s4tRainbow"))
        enabledOptions.Push("Rainbow")
    if (botConfig.get("s4tFullArt"))
        enabledOptions.Push("Full Art")
    if (botConfig.get("s4tCrown"))
        enabledOptions.Push("Crown")
    if (botConfig.get("s4tImmersive"))
        enabledOptions.Push("Immersive")
    if (botConfig.get("s4tShiny1Star"))
        enabledOptions.Push("Shiny1★")
    if (botConfig.get("s4tShiny2Star"))
        enabledOptions.Push("Shiny2★")
    if (botConfig.get("s4tWishlist"))
        enabledOptions.Push("Wishlist")

    statusText := dict["Txt_S4TEnabled"]
    if (enabledOptions.Length() > 0) {
        statusText .= " - " . enabledOptions[1]
        if (enabledOptions.Length() > 1)
            statusText .= " +" . (enabledOptions.Length() - 1)
    }

    Gui, Font, s8 cLime, Segoe UI
    GuiControl, Font, ui_S4TButton
    GuiControl,, ui_S4TButton, %statusText%
}

ShowS4TSettings:
    Gui, Submit, NoHide
    PTCGPB_PopupRightOfCtl("ui_S4TButton", 200, 12, popupX, popupY)

    Gui, S4TSettingsSelect:Destroy
    Gui, S4TSettingsSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Save for Trade Settings
    Gui, S4TSettingsSelect:Color, 1E1E1E, 333333
    Gui, S4TSettingsSelect:Font, s10 cWhite, Segoe UI

    sectionColor := "c4169E1"

    yPos := 15
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tEnabled") ? "Checked" : "") " vui_s4tEnabled_Popup x15 y" . yPos . " cWhite", Enable S4T
    yPos += 25

    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4t3Dmnd") ? "Checked" : "") " vui_s4t3Dmnd_Popup x15 y" . yPos . " " . sectionColor, ◆◆◆
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4t4Dmnd") ? "Checked" : "") " vui_s4t4Dmnd_Popup x15 y" . yPos . " " . sectionColor, ◆◆◆◆
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4t1Star") ? "Checked" : "") " vui_s4t1Star_Popup x15 y" . yPos . " " . sectionColor, ★
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tShiny1Star") ? "Checked" : "") " vui_s4tShiny1Star_Popup x15 y" . yPos . " " . sectionColor, ★ Shiny
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tTrainer") ? "Checked" : "") " vui_s4tTrainer_Popup x15 y" . yPos . " " . sectionColor, ★★ Trainer
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tRainbow") ? "Checked" : "") " vui_s4tRainbow_Popup x15 y" . yPos . " " . sectionColor, ★★ Rainbow
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tFullArt") ? "Checked" : "") " vui_s4tFullArt_Popup x15 y" . yPos . " " . sectionColor, ★★ Full Art
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tShiny2Star") ? "Checked" : "") " vui_s4tShiny2Star_Popup x15 y" . yPos . " " . sectionColor, ★★ Shiny
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tImmersive") ? "Checked" : "") " vui_s4tImmersive_Popup x15 y" . yPos . " " . sectionColor, Immersive
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tCrown") ? "Checked" : "") " vui_s4tCrown_Popup x15 y" . yPos . " " . sectionColor, ♚ Crown Rare
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tWishlist") ? "Checked" : "") " vui_s4tWishlist_Popup x15 y" . yPos . " " . sectionColor, Wishlist
    yPos += 25

    ; Wonderpick section
    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tWP") ? "Checked" : "") " vui_s4tWP_Popup x15 y" . yPos . " cWhite", % dict["Txt_s4tWP"]
    yPos += 20
    Gui, S4TSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, % dict["Txt_s4tWPMinCards"]
    Gui, S4TSettingsSelect:Add, Edit, cFDFDFD w40 x135 y%yPos% h20 vui_s4tWPMinCards_Popup -E0x200 Background2A2A2A Center cWhite, % botConfig.get("s4tWPMinCards")
    yPos += 30
    if (botConfig.get("deleteMethod") != "Inject Wonderpick 96P+") {
        GuiControl, S4TSettingsSelect:Hide, ui_s4tWP_Popup
        GuiControl, S4TSettingsSelect:Hide, ui_s4tWPMinCardsText_Popup
        GuiControl, S4TSettingsSelect:Hide, ui_s4tWPMinCards_Popup
        yPos -= 50  ; Adjust yPos since we're hiding these controls
    }

    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("s4tKeepSyntheticScreenshots") ? "Checked" : "") " vui_s4tKeepSyntheticScreenshots_Popup x15 y" . yPos . " " . sectionColor, Save Screenshots
    yPos += 20

    Gui, S4TSettingsSelect:Add, Checkbox, % (botConfig.get("ocrShinedust") ? "Checked" : "") " vui_ocrShinedust_Popup x15 y" . yPos . " " . sectionColor, Track Shinedust
    yPos += 25

    Gui, S4TSettingsSelect:Add, Button, x25 y%yPos% w70 h30 gApplyS4TSettings, Apply
    Gui, S4TSettingsSelect:Add, Button, x105 y%yPos% w70 h30 gCancelS4TSettings, Cancel
    yPos += 40

    Gui, S4TSettingsSelect:Show, x%popupX% y%popupY% w200 h%yPos%
return

ApplyS4TSettings:
    Gui, S4TSettingsSelect:Submit, NoHide

    GoSub, saveS4T

    Gui, S4TSettingsSelect:Destroy

    Gui, 1:Default

    UpdateS4TButtonText()
return

saveS4T:
    botConfig.set("s4tEnabled", ui_s4tEnabled_Popup, "SaveForTrade")
    botConfig.set("s4tSilent", 0, "SaveForTrade")
    botConfig.set("s4tGholdengo", 0, "SaveForTrade")
    botConfig.set("s4t1Star", ui_s4t1Star_Popup, "SaveForTrade")
    botConfig.set("s4t4Dmnd", ui_s4t4Dmnd_Popup, "SaveForTrade")
    botConfig.set("s4t3Dmnd", ui_s4t3Dmnd_Popup, "SaveForTrade")
    botConfig.set("s4tTrainer", ui_s4tTrainer_Popup, "SaveForTrade")
    botConfig.set("s4tRainbow", ui_s4tRainbow_Popup, "SaveForTrade")
    botConfig.set("s4tFullArt", ui_s4tFullArt_Popup, "SaveForTrade")
    botConfig.set("s4tCrown", ui_s4tCrown_Popup, "SaveForTrade")
    botConfig.set("s4tImmersive", ui_s4tImmersive_Popup, "SaveForTrade")
    botConfig.set("s4tShiny1Star", ui_s4tShiny1Star_Popup, "SaveForTrade")
    botConfig.set("s4tShiny2Star", ui_s4tShiny2Star_Popup, "SaveForTrade")
    botConfig.set("s4tWishlist", ui_s4tWishlist_Popup, "SaveForTrade")
    botConfig.set("s4tWP", ui_s4tWP_Popup, "SaveForTrade")
    botConfig.set("s4tWPMinCards", ui_s4tWPMinCards_Popup, "SaveForTrade")
    botConfig.set("s4tKeepSyntheticScreenshots", ui_s4tKeepSyntheticScreenshots_Popup, "SaveForTrade")
    botConfig.set("ocrShinedust", ui_ocrShinedust_Popup, "SaveForTrade")

    if (ui_s4tWPMinCards_Popup < 1)
        botConfig.set("s4tWPMinCards", 1, "SaveForTrade")
    if (ui_s4tWPMinCards_Popup > 2)
        botConfig.set("s4tWPMinCards", 2, "SaveForTrade")
return

CancelS4TSettings:
    Gui, S4TSettingsSelect:Destroy
return

; =================== UI - Tools and System Settings(New Window, Details) ===================
ShowToolsAndSystemSettings:
    Gui, Submit, NoHide
    PTCGPB_PopupRightOfCtl(A_GuiControl, 410, 12, popupX, popupY)

    Gui, ToolsAndSystemSelect:Destroy
    Gui, ToolsAndSystemSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Tools & System Settings
    Gui, ToolsAndSystemSelect:Color, 1E1E1E, 333333
    Gui, ToolsAndSystemSelect:Font, s10 cWhite, Segoe UI

    currentDeleteMethod := botConfig.get("deleteMethod")
    GuiControlGet, selectedDeleteMethod, 1:, ui_deleteMethod
    if (selectedDeleteMethod != "")
        currentDeleteMethod := selectedDeleteMethod

    col1X := 15
    col1W := 190
    yPos := 15
    leftStep := 24

    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("showcaseEnabled") ? "Checked" : "") " vui_showcaseEnabled_Popup x" . col1X . " y" . yPos . " cWhite", 5x Showcase Likes
    yPos += leftStep
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("claimDailyMission") ? "Checked" : "") " vui_claimDailyMission_Popup x" . col1X . " y" . yPos . " cWhite", Claim Daily 4 Hourglasses
    yPos += leftStep
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("receiveGift") ? "Checked" : "") " vui_receiveGift_Popup x" . col1X . " y" . yPos . " cWhite", Receive Gift
    yPos += leftStep
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("slowMotion") ? "Checked" : "") " vui_slowMotion_Popup x" . col1X . " y" . yPos . " cWhite", No Speedmod Menu Clicks
    yPos += leftStep
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("useSoloIdsFile") ? "Checked" : "") " vui_UseSoloIdsFile_Popup x" . col1X . " y" . yPos . " cWhite", Use ids.txt in Solo Reroll
    yPos += leftStep
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("importHistory") ? "Checked" : "") " vui_importHistory_Popup x" . col1X . " y" . yPos . " cWhite", Import History
    yPos += 31

    sectionColor := "cWhite"
    eventMissionBoxH := 140
    eventMissionBoxBottom := yPos + eventMissionBoxH
    Gui, ToolsAndSystemSelect:Add, GroupBox, x%col1X% y%yPos% w%col1W% h%eventMissionBoxH% %sectionColor%, Special Event Missions
    yPos += 20
    Gui, ToolsAndSystemSelect:Add, Button, x25 y%yPos% w170 h20 gOpenSpecialEventExtractor BackgroundTrans, Special Event Extractor
    yPos += 24
    Gui, ToolsAndSystemSelect:Add, Button, x25 y%yPos% w170 h20 gClearSpecialMissionHistory BackgroundTrans, Reset Claim Status
    yPos += 24
    Gui, ToolsAndSystemSelect:Add, Button, x25 y%yPos% w170 h20 gClearReceiveGiftHistory BackgroundTrans, Reset Receive Gift Status
    yPos += 24
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("claimSpecialMissions") ? "Checked" : "") " vui_claimSpecialMissions_Popup x25 y" . yPos . " cWhite", Claim Rewards
    yPos += 22
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("wonderpickForEventMissions") ? "Checked" : "") " vui_wonderpickForEventMissions_Popup x40 y" . yPos . " cWhite", Wonderpick

    col2X := 220
    col2W := 190
    yPos2 := 15
    sectionColor := "cWhite"

    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, % dict["Txt_Monitor"]
    yPos2 += 20
    SysGet, MonitorCount, MonitorCount
    MonitorOptions := ""
    Loop, %MonitorCount% {
        SysGet, MonitorName, MonitorName, %A_Index%
        SysGet, Monitor, Monitor, %A_Index%
        MonitorOptions .= (A_Index > 1 ? "|" : "") "" A_Index ": (" MonitorRight - MonitorLeft "x" MonitorBottom - MonitorTop ")"
    }
    SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
    Gui, ToolsAndSystemSelect:Add, DropDownList, x%col2X% y%yPos2% w170 vui_SelectedMonitorIndex_Popup Choose%SelectedMonitorIndex% Background2A2A2A cWhite, %MonitorOptions%
    yPos2 += 30

    rowGapY := yPos2 + 2
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%rowGapY% %sectionColor%, % dict["Txt_RowGap"]
    Gui, ToolsAndSystemSelect:Add, Edit, vui_RowGap_Popup w25 x300 y%rowGapY% h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("RowGap")
    yPos2 += 30

    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, % dict["Txt_FolderPath"]
    yPos2 += 20
    mumuFolderPath := botConfig.get("folderPath")
    if(mumuFolderPath = "" || mumuFolderPath = "C:\Program Files\Netease"){
        mumuFolderPath := getMuMuFolderInConfig()
        botConfig.set("folderPath", mumuFolderPath, "ToolsAndSystem")
    }
    Gui, ToolsAndSystemSelect:Add, Edit, vui_folderPath_Popup w170 x%col2X% y%yPos2% h20 -E0x200 Background2A2A2A cWhite, % mumuFolderPath
    yPos2 += 30

    ocrTextY := yPos2 + 2
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%ocrTextY% %sectionColor%, OCR:
    ocrLanguageList := "en|zh|es|de|fr|ja|ru|pt|ko|it|tr|pl|nl|sv|ar|uk|id|vi|th|he|cs|no|da|fi|hu|el|zh-TW"
    defaultOcrLang := 1
    if (botConfig.get("ocrLanguage") != "") {
        index := 0
        Loop, Parse, ocrLanguageList, |
        {
            index++
            if (A_LoopField = botConfig.get("ocrLanguage")) {
                defaultOcrLang := index
                break
            }
        }
    }
    Gui, ToolsAndSystemSelect:Add, DropDownList, vui_ocrLanguage_Popup choose%defaultOcrLang% x255 y%yPos2% w40 Background2A2A2A cWhite, %ocrLanguageList%

    clientTextY := yPos2 + 2
    Gui, ToolsAndSystemSelect:Add, Text, x305 y%clientTextY% %sectionColor%, Client:
    clientLanguageList := "en|es|fr|de|it|pt|jp|ko|cn"
    defaultClientLang := 1
    if (botConfig.get("clientLanguage") != "") {
        index := 0
        Loop, Parse, clientLanguageList, |
        {
            index++
            if (A_LoopField = botConfig.get("clientLanguage")) {
                defaultClientLang := index
                break
            }
        }
    }
    Gui, ToolsAndSystemSelect:Add, DropDownList, vui_clientLanguage_Popup choose%defaultClientLang% x345 y%yPos2% w40 Background2A2A2A cWhite, %clientLanguageList%
    yPos2 += 30

    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, % dict["Txt_InstanceLaunchDelay"]
    Gui, ToolsAndSystemSelect:Add, Edit, vui_instanceLaunchDelay_Popup w30 x355 y%yPos2% h20 -E0x200 Background2A2A2A cWhite Center, % botConfig.get("instanceLaunchDelay")
    yPos2 += 30

    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("autoLaunchMonitor") ? "Checked" : "") " vui_autoLaunchMonitor_Popup x" . col2X . " y" . yPos2 . " " . sectionColor, % dict["Txt_autoLaunchMonitor"]
    yPos2 += 26
    if (currentDeleteMethod != "Create Bots (13P)") {
        Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("startCockpitWithBot") ? "Checked" : "") " vui_startCockpitWithBot_Popup x" . col2X . " y" . yPos2 . " " . sectionColor, Auto-open Cockpit
        yPos2 += 26
    }
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (botConfig.get("saveToGit") ? "Checked" : "") " vui_saveToGit_Popup gsaveToGit_Click x" . col2X . " y" . yPos2 . " " . sectionColor, Auto Save to Git (hourly)
    yPos2 += 30

    logLevel := botConfig.get("logLevel")
    StringLower, logLevel, logLevel
    logLevelChoose := 3
    if (logLevel = "error")
        logLevelChoose := 1
    else if (logLevel = "warn" || logLevel = "warning")
        logLevelChoose := 2
    else if (logLevel = "debug")
        logLevelChoose := 4
    else if (logLevel = "trace")
        logLevelChoose := 5
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, Log Level
    Gui, ToolsAndSystemSelect:Add, DropDownList, vui_logLevel_Popup choose%logLevelChoose% x300 y%yPos2% w85 Background2A2A2A cWhite, error|warn|info|debug|trace
    yPos2 += 40

    Gui, ToolsAndSystemSelect:Font, s8 cWhite, Segoe UI
    xmlSortY := yPos2 - 5
    Gui, ToolsAndSystemSelect:Add, Button, x%col2X% y%xmlSortY% w170 h20 gRunXMLSortTool BackgroundTrans, XML pack counts
    yPos2 += 25
    xmlDupY := yPos2 - 5
    Gui, ToolsAndSystemSelect:Add, Button, x%col2X% y%xmlDupY% w170 h20 gRunXMLDuplicateTool BackgroundTrans, XML Duplicate Remover
    yPos2 += 30

    Gui, ToolsAndSystemSelect:Font, s10 cWhite, Segoe UI

    finalY := (yPos2 > eventMissionBoxBottom ? yPos2 : eventMissionBoxBottom)
    buttonY := finalY + 15
    Gui, ToolsAndSystemSelect:Add, Button, x130 y%buttonY% w70 h30 gApplyToolsAndSystemSettings, Apply
    Gui, ToolsAndSystemSelect:Add, Button, x210 y%buttonY% w70 h30 gCancelToolsAndSystemSettings, Cancel
    finalY := buttonY + 45

    Gui, ToolsAndSystemSelect:Show, x%popupX% y%popupY% w410 h%finalY%
return

ApplyToolsAndSystemSettings:
    Gui, ToolsAndSystemSelect:Submit, NoHide

    GoSub, saveToolsAndSystemSettings

    Gui, ToolsAndSystemSelect:Destroy

    Gui, 1:Default
return

saveToolsAndSystemSettings:
    botConfig.set("showcaseEnabled", ui_showcaseEnabled_Popup, "ToolsAndSystem")
    botConfig.set("claimDailyMission", ui_claimDailyMission_Popup, "ToolsAndSystem")
    botConfig.set("slowMotion", ui_slowMotion_Popup, "ToolsAndSystem")
    botConfig.set("useSoloIdsFile", ui_UseSoloIdsFile_Popup, "ToolsAndSystem")
    botConfig.set("importHistory", ui_importHistory_Popup, "ToolsAndSystem")
    botConfig.set("claimSpecialMissions", ui_claimSpecialMissions_Popup, "ToolsAndSystem")
    botConfig.set("wonderpickForEventMissions", ui_wonderpickForEventMissions_Popup, "ToolsAndSystem")

    botConfig.set("SelectedMonitorIndex", ui_SelectedMonitorIndex_Popup, "ToolsAndSystem")
    botConfig.set("RowGap", ui_RowGap_Popup, "ToolsAndSystem")
    botConfig.set("folderPath", ui_folderPath_Popup, "ToolsAndSystem")
    botConfig.set("ocrLanguage", ui_ocrLanguage_Popup, "ToolsAndSystem")
    botConfig.set("clientLanguage", ui_clientLanguage_Popup, "ToolsAndSystem")
    botConfig.set("instanceLaunchDelay", ui_instanceLaunchDelay_Popup, "ToolsAndSystem")
    botConfig.set("autoLaunchMonitor", ui_autoLaunchMonitor_Popup, "ToolsAndSystem")
    botConfig.set("logLevel", ui_logLevel_Popup, "ToolsAndSystem")
    currentDeleteMethod := botConfig.get("deleteMethod")
    GuiControlGet, selectedDeleteMethod, 1:, ui_deleteMethod
    if (selectedDeleteMethod != "")
        currentDeleteMethod := selectedDeleteMethod
    if (currentDeleteMethod != "Create Bots (13P)")
        botConfig.set("startCockpitWithBot", ui_startCockpitWithBot_Popup, "ToolsAndSystem")
    botConfig.set("saveToGit", ui_saveToGit_Popup, "ToolsAndSystem")
    botConfig.set("receiveGift", ui_receiveGift_Popup, "ToolsAndSystem")

    if(botConfig.get("SelectedMonitorIndex") = "")
        botConfig.set("SelectedMonitorIndex", "1:", "ToolsAndSystem")
return

CancelToolsAndSystemSettings:
    Gui, ToolsAndSystemSelect:Destroy
return

OpenSpecialEventExtractor:
    extractorPath := A_ScriptDir . "\SpecialEvents\SpecialEventExtractor.ahk"
    if (FileExist(extractorPath)) {
        Run, %extractorPath%
    } else {
        MsgBox, 48, Special Event Extractor, % "SpecialEventExtractor.ahk not found at:`n" extractorPath
    }
return

saveToGit_Click:
    GuiControlGet, saveToGit_Popup, ToolsAndSystemSelect:, saveToGit_Popup
    if (saveToGit_Popup) {
        gitRoot := A_ScriptDir
        if (!IsGitRepo(gitRoot)) {
            GuiControl, ToolsAndSystemSelect:, saveToGit_Popup, 0
            MsgBox, 48, Git Error, The script directory is not a git repository.`nAuto Save to Git cannot be enabled.`n`nTo fix this, run: git init`nIt is also recommended to connect it to a remote repository.
        }
    }
return

ClearSpecialMissionHistory:
    MsgBox, 4, Clear Special Mission History, Reset Special Mission completion history for the current account metadata files? This will clear the X flag in Accounts\Cards\accounts so that PTCGPB will try collecting Special Missions again for those accounts.
    IfMsgBox, Yes
    {
        changed := AccountMetadata_ClearFlagEverywhere("X")
        changed := changed = "" ? 0 : changed + 0

        MsgBox, 64, Clear Special Mission History Complete, % "Done`nAccounts changed: " . changed
    }
return

ClearReceiveGiftHistory:
    MsgBox, 4, Clear Receive Gift History, Reset Receive Gift history for the current account metadata files? This will clear the R flag in Accounts\Cards\accounts so that PTCGPB will try Receive Gift again for those accounts.
    IfMsgBox, Yes
    {
        changed := AccountMetadata_ClearFlagEverywhere("R")
        changed := changed = "" ? 0 : changed + 0

        MsgBox, 64, Clear Receive Gift History Complete, % "Done`nAccounts changed: " . changed
    }
return

; =================== Logic - Start Bot Button Action ===================
Save:
    Gui, Submit, NoHide

    ;Deluxe := 0 ; Turn off Deluxe for all users now that pack is removed

    if (!SaveAllSettings())
        return

    if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
        MsgBox, 0x40000,, % dict["Error_BotPathTooLong"]
        return
    }

    confirmMsg := dict["Confirm_SelectedMethod"] . botConfig.get("deleteMethod") . "`n"

    confirmMsg .= "Instances: " . botConfig.get("Instances")
    if (botConfig.get("runMain")) {
        confirmMsg .= " + " . botConfig.get("Mains") . " Main"
    }
    confirmMsg .= "`n"

    confirmMsg .= "`n" . dict["Confirm_SelectedPacks"] . "`n"

    For idx, value in botConfig.packSettings {
        packID := idx
        viewPackName := dict["Txt_" . packID] ? dict["Txt_" . packID] : packID
        if value
            confirmMsg .= "• " . viewPackName . "`n"
    }

    additionalSettings := ""
    if (botConfig.get("deleteMethod") == "Inject Wonderpick 96P+" && botConfig.get("packMethod"))
        additionalSettings .= dict["Confirm_1PackMethod"] . "`n"
    if (botConfig.get("openExtraPack"))
        additionalSettings .= dict["Confirm_openExtraPack"] . "`n"
    if (botConfig.get("spendHourGlass"))
        additionalSettings .= dict["Confirm_SpendHourGlass"] . "`n"
    if (botConfig.get("claimSpecialMissions"))
        additionalSettings .= dict["Confirm_ClaimMissions"] . "`n"
    if (botConfig.get("showcaseEnabled"))
        additionalSettings .= "• Showcase Likes`n"
    if (botConfig.get("ocrShinedust") && botConfig.get("s4tEnabled"))
        additionalSettings .= "• Track Shinedust`n"
    if (InStr(botConfig.get("deleteMethod"), "Inject")) {
        additionalSettings .= dict["Confirm_SortBy"] . " "
        if (botConfig.get("injectSortMethod") = "ModifiedAsc")
            additionalSettings .= "Oldest First`n"
        else if (botConfig.get("injectSortMethod") = "ModifiedDesc")
            additionalSettings .= "Newest First`n"
        else if (botConfig.get("injectSortMethod") = "PacksAsc")
            additionalSettings .= "Fewest Packs First`n"
        else if (botConfig.get("injectSortMethod") = "PacksDesc")
            additionalSettings .= "Most Packs First`n"
        else if (botConfig.get("injectSortMethod") = "LastLoginAsc")
            additionalSettings .= "Oldest Last Login`n"
    }

    if (additionalSettings != "") {
        confirmMsg .= "`n" . dict["Confirm_AdditionalSettings"] . "`n" . additionalSettings
    }

    cardDetection := ""
    if (botConfig.get("deleteMethod") = "Inject Wonderpick 96P+") {
        if (botConfig.get("FullArtCheck"))
            cardDetection .= dict["Confirm_SingleFullArt"] . "`n"
        if (botConfig.get("TrainerCheck"))
            cardDetection .= dict["Confirm_SingleTrainer"] . "`n"
        if (botConfig.get("RainbowCheck"))
            cardDetection .= dict["Confirm_SingleRainbow"] . "`n"
        if (botConfig.get("PseudoGodPack"))
            cardDetection .= dict["Confirm_Double2Star"] . "`n"
        if (botConfig.get("WishlistCheck"))
            cardDetection .= "• Wishlist 2★`n"
        if (botConfig.get("CrownCheck"))
            cardDetection .= dict["Confirm_SaveCrowns"] . "`n"
        if (botConfig.get("ShinyCheck"))
            cardDetection .= dict["Confirm_SaveShiny"] . "`n"
        if (botConfig.get("ImmersiveCheck"))
            cardDetection .= dict["Confirm_SaveImmersives"] . "`n"
        if (botConfig.get("InvalidCheck"))
            cardDetection .= dict["Confirm_IgnoreInvalid"] . "`n"

        if (cardDetection != "") {
            confirmMsg .= "`n" . dict["Confirm_CardDetection"] . "`n" . cardDetection
        }
    }

    if (botConfig.get("s4tEnabled")) {
        confirmMsg .= "`n" . dict["Confirm_SaveForTrade"] . ": " . dict["Confirm_Enabled"] . "`n"
        s4tSettings := ""
        if (botConfig.get("s4t1Star"))
            s4tSettings .= "• 1 Star`n"
        if (botConfig.get("s4t3Dmnd"))
            s4tSettings .= "• 3 Diamond`n"
        if (botConfig.get("s4t4Dmnd"))
            s4tSettings .= "• 4 Diamond`n"
        if (botConfig.get("s4tShiny1Star"))
            s4tSettings .= "• 1 Star Shiny`n"
        if (botConfig.get("s4tShiny2Star"))
            s4tSettings .= "• 2 Star Shiny`n"
        if (botConfig.get("s4tTrainer"))
            s4tSettings .= "• 2 Star Trainer`n"
        if (botConfig.get("s4tRainbow"))
            s4tSettings .= "• 2 Star Rainbow`n"
        if (botConfig.get("s4tFullArt"))
            s4tSettings .= "• 2 Star Full Art`n"
        if (botConfig.get("s4tImmersive"))
            s4tSettings .= "• Immersive`n"
        if (botConfig.get("s4tCrown"))
            s4tSettings .= "• Crown Rare`n"
        if (botConfig.get("s4tWishlist"))
            s4tSettings .= "• Wishlist`n"
        if (botConfig.get("s4tWP"))
            s4tSettings .= "• " . dict["Confirm_WonderPick"] . " (" . botConfig.get("s4tWPMinCards") . " " . dict["Confirm_MinCards"] . ")`n"

        confirmMsg .= s4tSettings
    }

    if ((botConfig.get("s4tSendAccountXml") && botConfig.get("s4tEnabled")) || DiscordShouldSendAccountXml()) {
        confirmMsg .= "`n" . dict["Confirm_XMLWarning"] . "`n"
    }

    if (botConfig.get("deleteMethod") != "Inject Rewards") {
        confirmMsg .= "`n" . dict["Confirm_StartBot"]

        MsgBox, 4, Confirm Bot Settings, %confirmMsg%
        IfMsgBox, No
            return
    }
    if (botConfig.get("deleteMethod") = "Inject Rewards") {
        irClaimChecked := botConfig.get("claimSpecialMissions") ? "Checked" : ""
        irGiftChecked := botConfig.get("receiveGift") ? "Checked" : ""
        irWPChecked := botConfig.get("wonderpickForEventMissions") ? "Checked" : ""
        irShinedustChecked := botConfig.get("ocrShinedust") ? "Checked" : ""

        g_irDialogResult := "cancel"
        Gui, InjectReqDlg:New, +AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Inject Rewards Options
        Gui, InjectReqDlg:Font, s9, Segoe UI
        Gui, InjectReqDlg:Add, Text, x12 y12 w285, Confirm the actions for 'Inject Rewards'. You can leave every option unchecked to only log in and out.
        Gui, InjectReqDlg:Add, Checkbox, x12 y60 vui_irClaim %irClaimChecked%, Claim Special Missions
        Gui, InjectReqDlg:Add, Checkbox, x12 y82 vui_irGift %irGiftChecked%, Receive Gift
        Gui, InjectReqDlg:Add, Checkbox, x12 y104 vui_irWP %irWPChecked%, Wonderpick
        Gui, InjectReqDlg:Add, Checkbox, x12 y126 vui_irShinedust %irShinedustChecked%, Track Shinedust
        Gui, InjectReqDlg:Add, Button, x12 y160 w80 h26 gInjectReqDlgOK Default, OK
        Gui, InjectReqDlg:Add, Button, x102 y160 w80 h26 gInjectReqDlgCancel, Cancel
        PTCGPB_PopupRightOfCtl("ui_StartBotButton", 310, 12, dlgX, dlgY)
        Gui, InjectReqDlg:Show, x%dlgX% y%dlgY% w310 h200
        irDlgHwnd := WinExist()
        WinWaitClose, ahk_id %irDlgHwnd%
        if (g_irDialogResult = "cancel")
            return
    }

    isIncorrectEventSetting := false
    if(isSevtFileExist() && !botConfig.get("claimSpecialMissions")){
        isIncorrectEventSetting := true
        MsgBox, 4, Setting Recommendation, A .sevt file was found, but the 'Claim Special Mission' setting is currently disabled.`n`nWould you like to enable and apply this setting now?
        IfMsgBox, Yes
            botConfig.set("claimSpecialMissions", 1, "ToolsAndSystem")
    }
    else if(!isSevtFileExist() && botConfig.get("claimSpecialMissions")){
        isIncorrectEventSetting := true
        MsgBox, 48, Notice, The 'Claim Special Mission' option is enabled, but the required .sevt file is missing, so the event cannot be recognized.`n`nThis setting will be automatically disabled.
        botConfig.set("claimSpecialMissions", 0, "ToolsAndSystem")
    }

    if (botConfig.get("deleteMethod") = "Inject Rewards" && !botConfig.get("claimSpecialMissions") && !botConfig.get("receiveGift") && !botConfig.get("wonderpickForEventMissions") && !(botConfig.get("ocrShinedust") && botConfig.get("s4tEnabled"))) {
        MsgBox, 48, Setting Warning, No actions are enabled for 'Inject Rewards'. The game will only log in and out for each account.
    }

    Gui, 1:Destroy

    AccountMetadata_Ensure()
    StartBot()
return

; =================== Logic - Balance XMLs Button Action ===================
BalanceXMLs:
    Gui, Submit, NoHide
    if (!SaveAllSettings())
        return

    if(botConfig.get("Instances")>0) {
        helperPath := AccountMetadata_HelperPath()
        if (FileExist(helperPath)) {
            root := A_ScriptDir
            command := """" . helperPath . """ --root """ . root . """ balance-xmls"
            command .= " --instances """ . botConfig.get("Instances") . """"
            command .= " --delete-method """ . botConfig.get("deleteMethod") . """"
            command .= " --sort-method """ . botConfig.get("injectSortMethod") . """"
            command .= " --inject-wonderpick-min-packs """ . botConfig.get("injectWonderpickMinPacks") . """"
            if (botConfig.get("wonderpickForEventMissions"))
                command .= " --wonderpick-for-event-missions"
            if (botConfig.get("claimSpecialMissions"))
                command .= " --claim-special-missions"
            if (botConfig.get("receiveGift"))
                command .= " --receive-gift"
            if (botConfig.get("ocrShinedust"))
                command .= " --ocr-shinedust"
            if (botConfig.get("s4tEnabled"))
                command .= " --s4t-enabled"
            if (botConfig.get("spendHourGlass"))
                command .= " --spend-hourglass"
            balanceOk := BalanceXMLs_RunWithProgress(command)
            resultPath := A_ScriptDir . "\Accounts\Saved\balance_result.txt"
            counter := 0
            if (FileExist(resultPath)) {
                FileRead, counter, %resultPath%
                counter := Trim(counter)
            }
            Tooltip
            errorPath := A_ScriptDir . "\Accounts\Saved\carddb_error.txt"
            if (!balanceOk || FileExist(errorPath)) {
                errorText := ""
                if (FileExist(errorPath))
                    FileRead, errorText, %errorPath%
                MsgBox, 0x40000, XML Balance, % "carddb balance-xmls failed.`n`n" . errorText
            } else {
                MsgBox, 0x40000, XML Balance, % XMLBalanceResultMessage(botConfig.get("Instances"), counter)
            }
            return
        }

        AccountMetadata_MergeAllTemp()
        AccountMetadata_Ensure()

        saveDir := A_ScriptDir "\Accounts\Saved\"
        if !FileExist(saveDir)
            FileCreateDir, %saveDir%

        tmpDir := A_ScriptDir "\Accounts\Saved\tmp"
        if !FileExist(tmpDir)
            FileCreateDir, %tmpDir%

        Tooltip, Moving Files and Folders to tmp
        Loop, Files, %saveDir%*, D
        {
            if (A_LoopFilePath == tmpDir)
                continue
            dest := tmpDir . "\" . A_LoopFileName

            FileMoveDir, %A_LoopFilePath%, %dest%, 1
        }
        Loop, Files, %saveDir%\*, F
        {
            if (A_LoopFileName = "metadata.json")
                continue
            dest := tmpDir . "\" . A_LoopFileName
            FileMove, %A_LoopFilePath%, %dest%, 1
        }
        Loop , % botConfig.get("Instances")
        {
            instanceDir := saveDir . "\" . A_Index
            if !FileExist(instanceDir)
                FileCreateDir, %instanceDir%
            listfile := instanceDir . "\list.txt"
            if FileExist(listfile)
                FileDelete, %listfile%
        }

        ToolTip, Checking for Duplicate names
        fileList := ""
        seenFiles := {}
        packCountMap := AccountMetadata_GetPackCountMap()
        Loop, Files, %tmpDir%\*.xml, R
        {
            fileName := A_LoopFileName
            fileTime := A_LoopFileTimeModified
            fileTime := A_LoopFileTimeCreated
            filePath := A_LoopFileFullPath

            if seenFiles.HasKey(fileName)
            {
                prevTime := seenFiles[fileName].Time
                prevPath := seenFiles[fileName].Path

                if (fileTime > prevTime)
                {
                    FileDelete, %prevPath%
                    seenFiles[fileName] := {Time: fileTime, Path: filePath}
                }
                else
                {
                    FileDelete, %filePath%
                }
                continue
            }

            ; Uncomment below version to sort by file last modified dates
            ; seenFiles[fileName] := {Time: fileTime, Path: filePath}
            ; fileList .= fileTime "`t" filePath "`n"

            ; Sort by metadata pack count instead of filename pack count.
            packCount := ""
            if (IsObject(packCountMap) && packCountMap.HasKey(fileName))
                packCount := packCountMap[fileName]
            if (packCount = "") {
                RegExMatch(fileName, "(\d+)P_", packMatch)
                packCount := packMatch1 ? packMatch1 : 0
            }

            seenFiles[fileName] := {Time: fileTime, Path: filePath}
            fileList .= packCount "`t" filePath "`n"
        }

        ToolTip, Sorting by pack count
        Sort, fileList, R

        ToolTip, Distributing XMLs between folders...please wait
        instance := 1
        metadataMoves := []
        Loop, Parse, fileList, `n
        {
            if (A_LoopField = "")
                continue

            StringSplit, parts, A_LoopField, %A_Tab%
            tmpFile := parts2
            toDir := saveDir . "\" . instance

            FileMove, %tmpFile%, %toDir%, 1
            SplitPath, tmpFile, movedFileName
            metadataMoves.Push({"fileName": movedFileName, "instance": instance})

            instance++
            if (instance > botConfig.get("Instances"))
                instance := 1
        }

        ToolTip, Updating metadata indexes...please wait
        AccountMetadata_BulkMoveToInstances(metadataMoves)

        counter := 0
        ToolTip, Counting XMLs older than 24 hours...
        Loop, % botConfig.get("Instances")
        {
            instanceDir := saveDir . A_Index
            Loop, Files, %instanceDir%\*.xml
            {
                FileGetTime, fileModifiedTime, %A_LoopFileFullPath%, M
                if (fileModifiedTime = "")
                    continue
                fileModifiedTimeDiff := A_Now
                EnvSub, fileModifiedTimeDiff, %fileModifiedTime%, Hours
                if (fileModifiedTimeDiff >= 24)
                    counter++
            }
        }

        Tooltip
        MsgBox, 0x40000, XML Balance, % XMLBalanceResultMessage(botConfig.get("Instances"), counter)
    }
return

XMLBalanceResultMessage(instances, eligibleCount) {
    instances += 0
    eligibleCount += 0
    averagePerInstance := instances > 0 ? Round(eligibleCount / instances, 0) : 0
    return "Done balancing XMLs between " instances " instances.`nEligible for injection now: " eligibleCount "`nAverage per instance: " averagePerInstance
}

BalanceXMLs_RunWithProgress(command) {
    resultPath := A_ScriptDir . "\Accounts\Saved\balance_result.txt"
    errorPath := A_ScriptDir . "\Accounts\Saved\carddb_error.txt"
    progressPath := A_ScriptDir . "\Accounts\Saved\balance_progress.txt"
    logPath := A_ScriptDir . "\Accounts\Saved\carddb_balance.log"
    FileDelete, %resultPath%
    FileDelete, %errorPath%
    FileDelete, %progressPath%
    FormatTime, balanceStartTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, [%balanceStartTime%] AHK BalanceXMLs starting command: %command%`n, %logPath%

    Progress, M B1 FS10 ZH0 FM10 WM700 W480, Starting XML balance..., XML Balance, XML Balance
    Run, %command%,, Hide, helperPid
    if (ErrorLevel) {
        FormatTime, balanceErrorTime,, yyyy-MM-dd HH:mm:ss
        errorText := "AHK failed to launch carddb balance-xmls. ErrorLevel=" . ErrorLevel . "`nCommand=" . command . "`n"
        FileAppend, %errorText%, %errorPath%
        FileAppend, [%balanceErrorTime%] %errorText%, %logPath%
        Progress, Off
        return false
    }
    FormatTime, balanceLaunchTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, [%balanceLaunchTime%] AHK launched carddb pid=%helperPid%`n, %logPath%

    lastPercent := 0
    lastMessage := "Starting XML balance..."

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
                Progress, %lastPercent%, %lastMessage%, XML Balance, XML Balance
            }
        } else {
            if (lastPercent < 5)
                Progress, 5, Preparing XML balance..., XML Balance, XML Balance
        }

        Process, Exist, %helperPid%
        if (!ErrorLevel)
            break
        Sleep, 250
    }

    Progress, 100, XML balance complete, XML Balance, XML Balance
    Sleep, 300
    Progress, Off

    Process, WaitClose, %helperPid%, 1
    FormatTime, balanceEndTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, [%balanceEndTime%] AHK observed carddb pid=%helperPid% closed. Last progress=%lastPercent% %lastMessage%`n, %logPath%
    if (FileExist(errorPath))
        return false
    if (!FileExist(resultPath)) {
        errorText := "carddb balance-xmls ended without writing balance_result.txt.`nLast progress: " . lastPercent . " " . lastMessage . "`nCommand=" . command . "`n"
        FileAppend, %errorText%, %errorPath%
        FileAppend, [%balanceEndTime%] %errorText%, %logPath%
        return false
    }
    return true
}

; =================== Logic - Launch All Mumu Button Action ===================
LaunchAllMumu:
    Gui, Submit, NoHide
    if (!SaveAllSettings())
        return

    if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
        MsgBox, 0x40000,, ERROR: bot folder path is too long or contains blank spaces. Move to a shorter path without spaces such as C:\PTCGPB
        return
    }

    launchAllFile := A_ScriptDir . "\Scripts\Include\LaunchAllMumu.ahk"
    if(FileExist(launchAllFile)) {
        Run, %launchAllFile%

        totalInstances := botConfig.get("Instances") + (botConfig.get("runMain") ? botConfig.get("Mains") : 0)
        estimatedLaunchTime := (botConfig.get("instanceLaunchDelay") * totalInstances * 1000) + 500

        Sleep, %estimatedLaunchTime%

        Gosub, ArrangeWindows
    }
return

; =================== Logic - Arrange Button Action ===================
ArrangeWindows:
    Gui, Submit, NoHide

    if (!SaveAllSettings())
        return

    scaleParam := 283
    windowsPositioned := 0
    titleHeight := 40

    if(botConfig.get("SelectedMonitorIndex") = "")
        botConfig.set("SelectedMonitorIndex", "1:", "ToolsAndSystem")

    if (botConfig.get("runMain") && botConfig.get("Mains") > 0) {
        Loop % botConfig.get("Mains") {
            mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")  . " ahk_class Qt5156QWindowIcon"
            SetTitleMatchMode, 3
            if (WinExist(mainInstanceName)) {
                WinActivate, %mainInstanceName%
                WinGetPos, curX, curY, curW, curH, %mainInstanceName%

                SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
                SysGet, Monitor, Monitor, %SelectedMonitorIndex%

                instanceIndex := A_Index
                borderWidth := 4 - 1
                rowHeight := titleHeight + 492
                currentRow := Floor((instanceIndex - 1) / botConfig.get("Columns"))
                y := MonitorTop + (currentRow * rowHeight) + (currentRow * botConfig.get("rowGap"))
                x := MonitorLeft + (Mod((instanceIndex - 1), botConfig.get("Columns")) * (scaleParam - borderWidth * 2))

                WinMove, %mainInstanceName%,, %x%, %y%, %scaleParam%, %rowHeight%
                WinSet, Redraw, , %mainInstanceName%

                windowsPositioned++
                sleep, 100
            }
        }
    }

    if (botConfig.get("Instances") > 0) {
        Loop % botConfig.get("Instances") {
            SetTitleMatchMode, 3
            windowTitle := A_Index . " ahk_class Qt5156QWindowIcon"

            if (WinExist(windowTitle)) {
                WinActivate, %windowTitle%
                WinGetPos, curX, curY, curW, curH, %windowTitle%

                SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
                SysGet, Monitor, Monitor, %SelectedMonitorIndex%

                instanceIndex := A_Index
                if (botConfig.get("runMain"))
                    instanceIndex := (botConfig.get("Mains") - 1) + A_Index + 1

                borderWidth := 4 - 1
                rowHeight := titleHeight + 492
                currentRow := Floor((instanceIndex - 1) / botConfig.get("Columns"))
                y := MonitorTop + (currentRow * rowHeight) + (currentRow * botConfig.get("rowGap"))
                x := MonitorLeft + (Mod((instanceIndex - 1), botConfig.get("Columns")) * (scaleParam - borderWidth * 2))
                if(x < 0)
                    x := 0

                WinMove, %windowTitle%,, %x%, %y%, %scaleParam%, %rowHeight%
                WinSet, Redraw, , %windowTitle%

                windowsPositioned++
                sleep, 100
            }
        }
    }

    if (botConfig.get("debugMode") && windowsPositioned == 0)
        MsgBox, 0x40000,, No windows found to arrange

return

DiscordLink:
    Run, https://discord.com/invite/C9Nyf7P4sT
Return

BuyMeCoffee:
    Run, https://ko-fi.com/kevnitg
return

OpenToolTip:
    Run, https://mixman208.github.io/PTCGPB/
return

OpenDiscord:
    Run, https://discord.gg/C9Nyf7P4sT
return

PTCGPB_ResetCockpitLaunchMarker() {
    markerPath := A_ScriptDir . "\Scripts\Include\Cockpit\CockpitLaunch.ini"
    if (FileExist(markerPath))
        FileDelete, %markerPath%
}

PTCGPB_SetCockpitLaunchMarker(active := 0) {
    markerPath := A_ScriptDir . "\Scripts\Include\Cockpit\CockpitLaunch.ini"
    IniWrite, % (active ? 1 : 0), %markerPath%, Runtime, BotStarted
}

PTCGPB_RebuildTrayMenu() {
    global g_botStarted
    Menu, Tray, NoStandard
    if (g_botStarted)
        Menu, Tray, Add, Open Cockpit, OpenCockpit
    Menu, Tray, Add
    Menu, Tray, Standard
}

OpenCockpit:
    global g_botStarted
    if (!g_botStarted) {
        MsgBox, 48,, Start the bot first, then open Cockpit from tray.
        return
    }
    cockpitFile := A_ScriptDir . "\Scripts\Include\Cockpit\Cockpit.ahk"
    if (FileExist(cockpitFile)) {
        Run, %cockpitFile%
    } else {
        MsgBox, 48,, Cockpit.ahk not found at:`n%cockpitFile%
    }
return

OpenCardDatabase:
    cardDbStartScript := A_ScriptDir . "\Accounts\Cards\start_card_dashboard.bat"
    cardDbHtml := A_ScriptDir . "\Accounts\Cards\card_database.html"

    if (FileExist(cardDbStartScript)) {
        Run, %cardDbStartScript%
    } else if (FileExist(cardDbHtml)) {
        Run, %cardDbHtml%
    } else {
        MsgBox, 48, Card Database, Could not find Card Database launcher.`nChecked:`n%cardDbStartScript%
    }
return

RunXMLSortTool:
    Tool := A_ScriptDir . "\Accounts\xmlCounter.ahk"
    RunWait, %Tool%
Return

RunXMLDuplicateTool:
    Tool := A_ScriptDir . "\Accounts\xml_duplicate_finder.ahk"
    RunWait, %Tool%
Return

InjectReqDlgOK:
    Gui, InjectReqDlg:Submit, NoHide
    botConfig.set("claimSpecialMissions", ui_irClaim, "ToolsAndSystem")
    botConfig.set("receiveGift", ui_irGift, "ToolsAndSystem")
    botConfig.set("wonderpickForEventMissions", ui_irWP, "ToolsAndSystem")
    botConfig.set("ocrShinedust", ui_irShinedust, "SaveForTrade")
    botConfig.saveConfigToSettings("ALL")
    g_irDialogResult := "ok"
    Gui, InjectReqDlg:Destroy
return

InjectReqDlgCancel:
InjectReqDlgGuiClose:
    g_irDialogResult := "cancel"
    Gui, InjectReqDlg:Destroy
return

GuiClose:
    Gui, Submit, NoHide
    if (!SaveAllSettings())
        return

    KillAllScripts()

ExitApp
return

CheckForUpdates:
    CheckForUpdate()
return

; =================== Logic - Swipe speed hint (focus + ToolTip) ===================
ShowSwipeSpeedToolTip:
    GuiControlGet, currentFocus, FocusV

    if (currentFocus = "ui_swipeSpeed") {
        MouseGetPos, mouseX, mouseY
        global dict
        message := dict["RecommandSwipeSpeedNoModMenu"] . "`n" . dict["RecommandSwipeSpeedUseModMenu"] . "`n" . dict["HideSwipeToolTip"]
        ShowCustomToolTip(message, (mouseX + 15), (mouseY + 20))
    } else {
        HideCustomToolTip()
    }
return

; =================== Logic - Save all settings - LEGACY ===================
SaveAllSettings() {
    global botConfig, dict

    For uiID, configName in botConfig.mainConfigUIMap {
        configValue := ""
        GuiControlGet, configValue, , %uiID%
        botConfig.set(configName, configValue, "General")
    }

    if (botConfig.get("injectWonderpickMinPacks") = "")
        botConfig.set("injectWonderpickMinPacks", 96, "General")
    else if (!RegExMatch(botConfig.get("injectWonderpickMinPacks"), "^\d+$") || botConfig.get("injectWonderpickMinPacks") < 70 || botConfig.get("injectWonderpickMinPacks") > 999) {
        MsgBox, 0x40000, Invalid Setting, Inject Wonderpick minimum packs must be between 70 and 999.
        GuiControl, Focus, ui_injectWonderpickMinPacks
        return false
    }

    if(botConfig.get("debugMode") = 0)
        botConfig.set("debugMode", 0, "Extra")

    botConfig.set("showcaseLikes", 5, "Extra")
    botConfig.set("waitForEligibleAccounts", 1, "Extra")
    botConfig.loadIniSectionFromSettingsFile("Extra")
    botConfig.set("stopPreference", botConfig.get("stopPreference"), "Extra")
    botConfig.set("stopPreferenceSingle", botConfig.get("stopPreferenceSingle"), "Extra")
    botConfig.set("stopPreferenceMain", botConfig.get("stopPreferenceMain"), "Extra")

    botConfig.saveConfigToSettings("ALL")

    if (botConfig.get("debugMode")) {
        FileAppend, % A_Now . " - Settings saved. DeleteMethod: " . botConfig.get("deleteMethod") . "`n", %A_ScriptDir%\debug_settings.log
    }

    return true
}

; =================== Logic - Reset account lists ===================
ResetAccountLists() {
    resetListsPath := A_ScriptDir . "\Scripts\Include\ResetLists.ahk"

    if (FileExist(resetListsPath)) {
        Run, %resetListsPath%,, Hide UseErrorLevel
        Sleep, 50
        LogInfo("Account lists reset via ResetLists.ahk. New lists will be generated on next injection.")
        CreateStatusMessage("Account lists reset. New lists will use current method settings.",,,, false)
    } else {
        LogError("ResetLists.ahk not found at: " . resetListsPath)

        if (botConfig.get("debugMode")) {
            MsgBox, 0x40000, Reset list issue, ResetLists.ahk not found at:`n%resetListsPath%
        }
    }
}

; =================== Logic - Start bot function ===================
StartBot() {
    global botConfig, dict, localVersion, githubUser, modVersion, modRepoUser, rerollTime, PackGuiBuild, botMetadata, typeMsg
        , g_botStarted

    PackGuiBuild := 0
    rerollTime := A_TickCount

    if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
        MsgBox, 0x40000,, ERROR: bot folder path is too long or contains blank spaces. Move to a shorter path without spaces such as C:\PTCGPB
        return
    }

    ResetAccountLists()

    if (inStr(botConfig.get("FriendID"), "http")) {
        MsgBox,To provide a URL for friend IDs, please use the ids.txt API field and leave the Friend ID field empty.

        if (botConfig.get("mainIdsURL") = "") {
            botConfig.set("FriendID", "")
            botConfig.set("mainIdsURL", botConfig.get("FriendID"))
        }

        Reload
    }

    if (botConfig.get("showcaseEnabled")) {
        if (!FileExist("showcase_ids.txt")) {
            MsgBox, 48, Showcase Warning, Showcase is enabled but showcase_ids.txt does not exist.`nPlease create this file in the same directory as the script.
        }
    }

    if (botConfig.get("runMain")) {
        Loop, % botConfig.get("Mains")
        {
            if (A_Index != 1) {
                SourceFile := "Scripts\Main.ahk"
                TargetFolder := "Scripts\"
                TargetFile := TargetFolder . "Main" . A_Index . ".ahk"
                FileDelete, %TargetFile%
                FileCopy, %SourceFile%, %TargetFile%, 1
                if (ErrorLevel)
                    MsgBox, Failed to create %TargetFile%. Ensure permissions and paths are correct.
            }

            mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
            FileName := "Scripts\" . mainInstanceName . ".ahk"
            Command := FileName

            if (A_Index > 1 && botConfig.get("instanceStartDelay") > 0) {
                instanceStartDelayMS := botConfig.get("instanceStartDelay") * 1000
                Sleep, instanceStartDelayMS
            }

            Run, %Command%
        }
    }

    ; Anchor Cockpit session lifecycle to bot start (not Cockpit window lifetime).
    cockpitSessionEpoch := A_NowUTC
    EnvSub, cockpitSessionEpoch, 1970, Seconds
    cockpitSessionId := A_NowUTC
    cockpitSessionPath := A_ScriptDir . "\Scripts\Include\Cockpit\CockpitSession.ini"
    IniWrite, %cockpitSessionEpoch%, %cockpitSessionPath%, Session, StartEpoch
    IniWrite, %cockpitSessionId%, %cockpitSessionPath%, Session, SessionId
    PTCGPB_SetCockpitLaunchMarker(1)
    cockpitRuntimePath := A_ScriptDir . "\Scripts\Include\Cockpit\CockpitRuntime.ini"
    if (FileExist(cockpitRuntimePath))
        FileDelete, %cockpitRuntimePath%

    g_botStarted := true
    PTCGPB_RebuildTrayMenu()

    Loop, % botConfig.get("Instances")
    {
        if (A_Index != 1) {
            SourceFile := "Scripts\1.ahk"
            TargetFolder := "Scripts\"
            TargetFile := TargetFolder . A_Index . ".ahk"
            if(botConfig.get("Instances") > 1) {
                FileDelete, %TargetFile%
                FileCopy, %SourceFile%, %TargetFile%, 1
            }
            if (ErrorLevel)
                MsgBox, Failed to create %TargetFile%. Ensure permissions and paths are correct.
        }

        FileName := "Scripts\" . A_Index . ".ahk"
        Command := FileName

        if ((botConfig.get("Mains") > 1 || A_Index > 1) && botConfig.get("instanceStartDelay") > 0) {
            instanceStartDelayMS := botConfig.get("instanceStartDelay") * 1000
            Sleep, instanceStartDelayMS
        }

        metricFile := A_ScriptDir . "\Scripts\" . A_Index . ".ini"
        if (FileExist(metricFile)) {
            IniWrite, 0, %metricFile%, Metrics, LastEndEpoch
            IniWrite, 0, %metricFile%, UserSettings, DeadCheck
            IniWrite, 0, %metricFile%, Metrics, rerolls
            now := A_TickCount
            IniWrite, %now%, %metricFile%, Metrics, rerollStartTime
        }

        Run, %Command%
    }

    if(botConfig.get("autoLaunchMonitor")) {
        monitorFile := A_ScriptDir . "\Scripts\Include\Monitor.ahk"
        if(FileExist(monitorFile)) {
            Run, %monitorFile%
        }
    }

    ; Cockpit autostarts only in modes where it is applicable.
    if (botConfig.get("startCockpitWithBot") && botConfig.get("deleteMethod") != "Create Bots (13P)") {
        cockpitFile := A_ScriptDir . "\Scripts\Include\Cockpit\Cockpit.ahk"
        if(FileExist(cockpitFile)) {
            Run, %cockpitFile%
        }
    }

    SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
    SysGet, Monitor, Monitor, %SelectedMonitorIndex%
    rerollTime := A_TickCount

    typeMsg := "\nType: " . botConfig.get("deleteMethod")
    injectMethod := false
    if(InStr(botConfig.get("deleteMethod"), "Inject"))
        injectMethod := true
    if(botConfig.get("packMethod") && botConfig.get("deleteMethod") == "Inject Wonderpick 96P+")
        typeMsg .= " (1P Method)"

    Selected := []
    selectMsg := "\nOpening: "

    For idx, value in botConfig.packSettings {
        if(value)
            Selected.Push(idx)
    }

    for index, value in Selected {
        if (value) {
            if (index > 1)
                selectMsg .= ", "
            selectMsg .= dict["Txt_" . value]
        }
    }

    Loop {
        Sleep, 30000

        total := getTotalOpenPacks()
        totalSeconds := Round((A_TickCount - rerollTime) / 1000)
        mminutes := Floor(totalSeconds / 60)

        packStatus := "Time: " . mminutes . "m Packs: " . total
        packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"

        if(botConfig.get("heartBeat")) {
            heartbeatIterations := botConfig.get("heartBeatDelay") * 2

            if (A_Index = 1 || Mod(A_Index, heartbeatIterations) = 0) {
                onlineAHK := ""
                offlineAHK := ""
                Online := []

                Loop % botConfig.get("Instances") {
                    IniRead, value, HeartBeat.ini, HeartBeat, Instance%A_Index%
                    if(value)
                        Online.Push(1)
                    else
                        Online.Push(0)
                    IniWrite, 0, HeartBeat.ini, HeartBeat, Instance%A_Index%
                }

                for index, value in Online {
                    if(index = Online.MaxIndex())
                        commaSeparate := ""
                    else
                        commaSeparate := ", "
                    if(value)
                        onlineAHK .= A_Index . commaSeparate
                    else
                        offlineAHK .= A_Index . commaSeparate
                }

                if(botConfig.get("runMain")) {
                    IniRead, value, HeartBeat.ini, HeartBeat, Main
                    if(value) {
                        if (onlineAHK)
                            onlineAHK := "Main, " . onlineAHK
                        else
                            onlineAHK := "Main"
                    }
                    else {
                        if (offlineAHK)
                            offlineAHK := "Main, " . offlineAHK
                        else
                            offlineAHK := "Main"
                    }
                    IniWrite, 0, HeartBeat.ini, HeartBeat, Main
                }

                if(offlineAHK = "")
                    offlineAHK := "Offline: none"
                else
                    offlineAHK := "Offline: " . RTrim(offlineAHK, ", ")
                if(onlineAHK = "")
                    onlineAHK := "Online: none"
                else
                    onlineAHK := "Online: " . RTrim(onlineAHK, ", ")

                discMessage := botConfig.get("heartBeatName") ? "\n" . botConfig.get("heartBeatName") : ""

                discMessage .= "\n" . onlineAHK . "\n" . offlineAHK . "\n" . packStatus . "\n" . VersionStatusText()
                discMessage .= typeMsg
                discMessage .= selectMsg

                heartBeatWebhookURL := GetActiveHeartbeatWebhookURL()
                if((botConfig.get("groupRerollEnabled") || (!botConfig.get("groupRerollEnabled") && botConfig.get("heartBeatOwnerWebHookURL") = "")) && heartBeatWebhookURL)
                    LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)

                if(botConfig.get("heartBeatOwnerWebHookURL")){
                    FormatTime, currentTime, , yyyy-MM-dd HH:mm:ss
                    messageHeader := "\n\n[Instance status - " . currentTime . " (Elapsed time: " . mminutes . "m)]"

                    instanceStatusMessage := ""

                    for instanceNo, dataObject in botMetadata {
                        ; "[Number of packs opened per instance]"
                        ; 1.ahk: Time: 20m | Packs: 2345 | Avg: 4 packs/min
                        inRerollStartTime := dataObject.StartTime
                        inTotalOpenPacks := dataObject.TotalValue
                        inLastReceivedTime := dataObject.LastReceivedTime

                        elapsedMs := A_TickCount - inLastReceivedTime
                        timeAgo := FormatMsToAgo(elapsedMs)

                        inPackStatus := instanceNo . ".ahk: "
                        inPackStatus .= "Packs: " . inTotalOpenPacks
                        inPackStatus .= " | Avg: " . Round(inTotalOpenPacks / mminutes, 2) . " packs/min"
                        inPackStatus .= " | Last updated: " . timeAgo

                        instanceStatusMessage .= "\n" . inPackStatus
                    }
                    discMessage .= messageHeader
                    if(instanceStatusMessage = "")
                        discMessage .= "\n(No data has arrived from the instance.)"
                    else
                        discMessage .= instanceStatusMessage

                    discMessage .= "\n--------------------------------------------------"

                    LogToDiscord(discMessage,, false,,, botConfig.get("heartBeatOwnerWebHookURL"))
                }

                if (botConfig.get("debugMode")) {
                    FileAppend, % A_Now . " - Heartbeat sent at iteration " . A_Index . "`n", %A_ScriptDir%\heartbeat_log.txt
                }
            }
        }
    }
}

SendAllInstancesOfflineStatus() {
    global localVersion, githubUser, modVersion, modRepoUser, typeMsg, selectMsg, rerollTime

    offlineInstances := ""
    if (botConfig.get("runMain")) {
        offlineInstances := "Main"
        if (botConfig.get("Mains") > 1) {
            Loop, % botConfig.get("Mains") - 1
                offlineInstances .= ", Main" . (A_Index + 1)
        }
        if (botConfig.get("Instances") > 0)
            offlineInstances .= ", "
    }

    Loop, % botConfig.get("Instances") {
        offlineInstances .= A_Index
        if (A_Index < botConfig.get("Instances"))
            offlineInstances .= ", "
    }

    discMessage := botConfig.get("heartBeatName") ? "\n" . botConfig.get("heartBeatName") : ""
    discMessage .= "\nOnline: none"
    discMessage .= "\nOffline: " . offlineInstances

    total := getTotalOpenPacks()
    totalSeconds := Round((A_TickCount - rerollTime) / 1000)
    mminutes := Floor(totalSeconds / 60)
    packStatus := "Time: " . mminutes . "m | Packs: " . total
    packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"

    discMessage .= "\n" . packStatus . "\n" . VersionStatusText()
    discMessage .= typeMsg
    discMessage .= selectMsg
    discMessage .= "\n\n All instances marked as OFFLINE"

    heartBeatWebhookURL := GetActiveHeartbeatWebhookURL()
    if (heartBeatWebhookURL)
        LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)
}

ReceiveData(wParam, lParam) {
    global ProcessedIDs, botMetadata

    StringAddress := NumGet(lParam + 2*A_PtrSize)
    receivedString := StrGet(StringAddress)

    parts := StrSplit(receivedString, "|")
    if (parts.MaxIndex() != 3)
        return -1

    msgID := parts[1]
    subID := parts[2]
    receivedValue := parts[3]

    if (ProcessedIDs.HasKey(msgID))
        return 2

    if (!botMetadata.HasKey(subID)) {
        botMetadata[subID] := {}
        botMetadata[subID].TotalValue := 0
    }

    botMetadata[subID].StartTime := rerollStartTime
    botMetadata[subID].TotalValue += receivedValue
    botMetadata[subID].LastReceivedTime := A_TickCount

    ProcessedIDs[msgID] := true

    return 1
}

getTotalOpenPacks() {
    global botMetadata
    totalOpenPacks := 0
    for currentSubID, dataObject in botMetadata {
        totalOpenPacks += dataObject.TotalValue
    }
    return totalOpenPacks
}

CheckForUpdate() {
    global githubUser, repoName, localVersion, modVersion, modRepoUser

    if (FetchLatestRelease(githubUser, repoName, latestVersion, latestReleaseBody, zipDownloadURL)) {
        if (VersionCompare(latestVersion, localVersion) > 0) {
            DownloadAndInstallUpdate("Version", latestVersion, latestReleaseBody, zipDownloadURL)
            return
        }
    } else {
        return
    }

    if (FetchLatestRelease(modRepoUser, repoName, latestVersion, latestReleaseBody, zipDownloadURL)) {
        if (VersionCompare(latestVersion, modVersion) > 0) {
            DownloadAndInstallUpdate("Mod Version", latestVersion, latestReleaseBody, zipDownloadURL)
            return
        }
    }
}

VersionStatusText() {
    global githubUser, localVersion, modRepoUser, modVersion
    return "Version: " . RegExReplace(githubUser, "-.*$") . "-" . localVersion . "\nMod Version: " . RegExReplace(modRepoUser, "-.*$") . "-" . modVersion
}

FetchLatestRelease(repoUser, repoName, ByRef latestVersion, ByRef latestReleaseBody, ByRef zipDownloadURL) {
    url := "https://api.github.com/repos/" repoUser "/" repoName "/releases/latest"

    response := HttpGet(url)
    if !response
    {
        MsgBox, 0x40000, Check for Update, Failed to fetch latest version info
        return false
    }

    latestReleaseBody := FixFormat(ExtractJSONValue(response, "body"))
    latestVersion := ExtractJSONValue(response, "tag_name")
    zipDownloadURL := ExtractJSONValue(response, "zipball_url")

    if (zipDownloadURL = "" || !InStr(zipDownloadURL, "http"))
    {
        MsgBox, 0x40000, Check for Update, Failed to get download URL
        return false
    }

    if (latestVersion = "")
    {
        MsgBox, 0x40000, Check for Update, Failed to get version info
        return false
    }

    return true
}

DownloadAndInstallUpdate(updateLabel, latestVersion, releaseNotes, zipDownloadURL) {
    global zipPath, scriptFolder

    updateAvailable := updateLabel . " Update Available: "
    MsgBox, 262148, %updateAvailable% %latestVersion%, %releaseNotes%`n`nDo you want to download the latest version?

    IfMsgBox, Yes
    {
        MsgBox, 262208, Downloading..., Downloading update...

        URLDownloadToFile, %zipDownloadURL%, %zipPath%
        if ErrorLevel
        {
            MsgBox, 0x40000, Check for Update, Download failed
            return
        }
        else {
            MsgBox, 0x40000, Check for Update, Download complete

            tempExtractPath := A_Temp "\PTCGPB_Temp"
            FileCreateDir, %tempExtractPath%

            RunWait, powershell -Command "Expand-Archive -Path '%zipPath%' -DestinationPath '%tempExtractPath%' -Force",, Hide

            if !FileExist(tempExtractPath)
            {
                MsgBox, 0x40000, Check for Update, Extraction failed
                return
            }

            Loop, Files, %tempExtractPath%\*, D
            {
                extractedFolder := A_LoopFileFullPath
                break
            }

            if (extractedFolder)
            {
                MoveFilesRecursively(extractedFolder, scriptFolder)

                FileRemoveDir, %tempExtractPath%, 1
                MsgBox, 0x40000, Check for Update, Update installed successfully
                Reload
            } else {
                MsgBox, 0x40000, Check for Update, Update files not found
                return
            }
        }
    } else {
        MsgBox, 0x40000, Check for Update, Update cancelled
        return
    }
}

MoveFilesRecursively(srcFolder, destFolder) {
    Loop, Files, % srcFolder . "\*", R
    {
        relativePath := SubStr(A_LoopFileFullPath, StrLen(srcFolder) + 2)

        destPath := destFolder . "\" . relativePath

        if (A_LoopIsDir)
            FileCreateDir, % destPath
        else {
            if ((relativePath = "ids.txt" && FileExist(destPath))
                || (relativePath = "usernames.txt" && FileExist(destPath))
                || (relativePath = "discord.txt" && FileExist(destPath))
                || (relativePath = "vip_ids.txt" && FileExist(destPath))) {
                continue
            }
            FileCreateDir, % SubStr(destPath, 1, InStr(destPath, "\", 0, 0) - 1)
            FileMove, % A_LoopFileFullPath, % destPath, 1
        }
    }
}

FixFormat(text) {
    text := StrReplace(text, "\r\n", "`n")
    text := StrReplace(text, "\n", "`n")

    text := StrReplace(text, "\player", "player")
    text := StrReplace(text, "\None", "None")
    text := StrReplace(text, "\Welcome", "Welcome")

    ; text := StrReplace(text, ",", "")

    return text
}

ErrorHandler(exception) {
    errorMessage := "Error in PTCGPB.ahk`n`n"
        . "Message: " exception.Message "`n"
        . "What: " exception.What "`n"
        . "Line: " exception.Line "`n`n"
        . "Click OK to close all related scripts and exit."

    MsgBox, 262160, PTCGPB Error, %errorMessage%

    KillAllScripts()

    ExitApp, 1
    return true
}

~+F7::
    SendAllInstancesOfflineStatus()
ExitApp
return

~+F12::
    ListVars
    Pause ; 변수 목록을 확인하기 위해 스크립트를 잠시 멈춥니다.
return
