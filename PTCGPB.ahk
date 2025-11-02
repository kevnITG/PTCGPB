DisplayPackStatus(Message, X := 0, Y := 625) {
   global SelectedMonitorIndex
   static GuiName := "ScreenPackStatus"
   
   bgColor := "F0F5F9"
   textColor := "2E3440"
   
   MaxRetries := 10
   RetryCount := 0
   
   try {
      SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
      SysGet, Monitor, Monitor, %SelectedMonitorIndex%
      X := MonitorLeft + X
      
      Y := MonitorTop + 348
      
      Gui %GuiName%:+LastFoundExist
      if (PackGuiBuild) {
         GuiControl, %GuiName%:, PackStatus, %Message%
      }
      else {
         PackGuiBuild := 1
         OwnerWND := WinExist(1)
         Gui, %GuiName%:Destroy
         if(!OwnerWND)
            Gui, %GuiName%:New, +ToolWindow -Caption +LastFound -DPIScale +AlwaysOnTop
         else
            Gui, %GuiName%:New, +Owner%OwnerWND% +ToolWindow -Caption +LastFound -DPIScale
         Gui, %GuiName%:Color, %bgColor%
         Gui, %GuiName%:Margin, 2, 2
         Gui, %GuiName%:Font, s8 c%textColor%
         Gui, %GuiName%:Add, Text, vPackStatus c%textColor%, %Message%
         Gui, %GuiName%:Show, NoActivate x%X% y%Y%, %GuiName%
      }
   } catch e {
   }
}

ClearCardDetectionSettings() {
    global FullArtCheck, TrainerCheck, RainbowCheck, PseudoGodPack
    global CheckShinyPackOnly, InvalidCheck, CrownCheck, ShinyCheck, ImmersiveCheck
    global minStars, minStarsShiny
    
    FullArtCheck := 0
    TrainerCheck := 0
    RainbowCheck := 0
    PseudoGodPack := 0
    CheckShinyPackOnly := 0  ; Always cleared
    InvalidCheck := 0
    CrownCheck := 0
    ShinyCheck := 0
    ImmersiveCheck := 0
    minStars := 0
    minStarsShiny := 0  ; Cleared along with minStars
    
    ; Update GUI controls if they exist
    GuiControl,, FullArtCheck, 0
    GuiControl,, TrainerCheck, 0
    GuiControl,, RainbowCheck, 0
    GuiControl,, PseudoGodPack, 0
    GuiControl,, CheckShinyPackOnly, 0
    GuiControl,, InvalidCheck, 0
    GuiControl,, CrownCheck, 0
    GuiControl,, ShinyCheck, 0
    GuiControl,, ImmersiveCheck, 0
    GuiControl,, minStars, 0
    GuiControl,, minStarsShiny, 0
    
    UpdateCardDetectionButtonText()
}

#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
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
#Include Dictionary.ahk
#Include ADB.ahk
#Include Logging.ahk
#Include FontListHelper.ahk
#Include ChooseColors.ahk
#Include DropDownColor.ahk

version = Arturos PTCGP Bot
#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

OnError("ErrorHandler")

githubUser := "kevnITG"
   ,repoName := "PTCGPB"
   ,localVersion := "v8.2.3"
   ,scriptFolder := A_ScriptDir
   ,zipPath := A_Temp . "\update.zip"
   ,extractPath := A_Temp . "\update"
   ,intro := "Mega Rising"

global GUI_WIDTH := 790
global GUI_HEIGHT := 370
global MainGuiName

if not A_IsAdmin
{
   Run *RunAs "%A_ScriptFullPath%"
   ExitApp
}

settingsLoaded := LoadSettingsFromIni()
if (!settingsLoaded) {
   CreateDefaultSettingsFile()
   LoadSettingsFromIni()
}

if (!IsLanguageSet) {
   Gui, Add, Text,, Select Language
   BotLanguagelist := "English|中文|日本語|Deutsch"
   defaultChooseLang := 1
   if (BotLanguage != "") {
      Loop, Parse, BotLanguagelist, |
         if (A_LoopField = BotLanguage) {
            defaultChooseLang := A_Index
            break
         }
   }
   Gui, Add, DropDownList, vBotLanguage w200 choose%defaultChooseLang%, %BotLanguagelist%
   Gui, Add, Button, Default gNextStep, Next
   Gui, Show,, Language Selection
   Return
}

NextStep:
   Gui, Submit, NoHide
   IniWrite, %BotLanguage%, Settings.ini, UserSettings, Botlanguage
   IniRead, BotLanguage, Settings.ini, UserSettings, Botlanguage
   IsLanguageSet := 1
   langMap := { "English": 1, "中文": 2, "日本語": 3, "Deutsch": 4 }
   defaultBotLanguage := langMap.HasKey(BotLanguage) ? langMap[BotLanguage] : 1
   Gui, Destroy
   global LicenseDictionary, ProxyDictionary, currentDictionary, SetUpDictionary, HelpDictionary
   LicenseDictionary := CreateLicenseNoteLanguage(defaultBotLanguage)
      ,ProxyDictionary := CreateProxyLanguage(defaultBotLanguage)
      ,currentDictionary := CreateGUITextByLanguage(defaultBotLanguage, localVersion)
      ,SetUpDictionary := CreateSetUpByLanguage(defaultBotLanguage)
      ,HelpDictionary := CreateHelpByLanguage(defaultBotLanguage)
   
   RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
   global saveSignalFile := A_ScriptDir "\Scripts\Include\save.signal"
   if (!debugMode && !shownLicense && !FileExist(saveSignalFile)) {
      MsgBox, 64, % LicenseDictionary.Title, % LicenseDictionary.Content
      shownLicense := 1
      if (proxyEnabled)
         MsgBox, 64,, % ProxyDictionary.Notice
   }
   
   if FileExist(saveSignalFile) {
      KillADBProcesses()
      FileDelete, %saveSignalFile%
   } else {
      KillADBProcesses()
      CheckForUpdate()
   }
   
   scriptName := StrReplace(A_ScriptName, ".ahk")
   winTitle := scriptName
   showStatus := true
   
   totalFile := A_ScriptDir . "\json\total.json"
   backupFile := A_ScriptDir . "\json\total-backup.json"
   if FileExist(totalFile) {
      FileCopy, %totalFile%, %backupFile%, 1
      if (ErrorLevel)
         MsgBox, 0x40000,, Failed to create %backupFile%. Ensure permissions and paths are correct.
      FileDelete, %totalFile%
   }
   
   packsFile := A_ScriptDir . "\json\Packs.json"
   backupFile := A_ScriptDir . "\json\Packs-backup.json"
   if FileExist(packsFile) {
      FileCopy, %packsFile%, %backupFile%, 1
      if (ErrorLevel)
         MsgBox, 0x40000,, Failed to create %backupFile%. Ensure permissions and paths are correct.
   }
   InitializeJsonFile()

   Gui,+HWNDSGUI +Resize
   Gui, Color, 1E1E1E, 333333
   Gui, Font, s10 cWhite, Segoe UI
   MainGuiName := SGUI

   sectionColor := "cWhite"
   Gui, Add, GroupBox, x5 y0 w240 h50 %sectionColor%, Friend ID (Wonderpick mode only)
   if(FriendID = "ERROR" || FriendID = "")
     FriendID =
   Gui, Add, Edit, vFriendID w180 x35 y20 h20 -E0x200 Background2A2A2A cWhite, %FriendID%

   if (deleteMethod = "Create Bots (13P)") {
      GuiControl, Hide, FriendID
   }

   sectionColor := "cWhite"
   Gui, Add, GroupBox, x5 y50 w240 h130 %sectionColor%, % currentDictionary.InstanceSettings
   Gui, Add, Text, x20 y75 %sectionColor%, % currentDictionary.Txt_Instances
   Gui, Add, Edit, vInstances w50 x125 y75 h20 -E0x200 Background2A2A2A cWhite Center, %Instances%
   Gui, Add, Text, x20 y100 %sectionColor%, % currentDictionary.Txt_Columns
   Gui, Add, Edit, vColumns w50 x125 y100 h20 -E0x200 Background2A2A2A cWhite Center, %Columns%
      Gui, Font, s8 cWhite, Segoe UI
   Gui, Add, Button, x185 y100 w50 h20 gArrangeWindows BackgroundTrans, % currentDictionary.btn_arrange
      Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, Text, x20 y125 %sectionColor%, % currentDictionary.Txt_InstanceStartDelay
   Gui, Add, Edit, vinstanceStartDelay w50 x125 y125 h20 -E0x200 Background2A2A2A cWhite Center, %instanceStartDelay%

   Gui, Add, Checkbox, % (runMain ? "Checked" : "") " vrunMain gmainSettings x20 y150 " . sectionColor, % currentDictionary.Txt_runMain
   Gui, Add, Edit, % "vMains w50 x125 y150 h20 -E0x200 Background2A2A2A " . sectionColor . " Center" . (runMain ? "" : " Hidden"), %Mains%

   sectionColor := "c39FF14"
   Gui, Add, GroupBox, x5 y185 w240 h175 %sectionColor%, % currentDictionary.BotSettings

   if (deleteMethod = "Create Bots (13P)")
   defaultDelete := 1
   else if (deleteMethod = "Inject 13P+")
   defaultDelete := 2
   else if (deleteMethod = "Inject Missions")
   defaultDelete := 2
   else if (deleteMethod = "Inject Wonderpick 96P+")
   defaultDelete := 3
   Gui, Add, DropDownList, vdeleteMethod gdeleteSettings choose%defaultDelete% x20 y210 w200 Background2A2A2A cWhite, Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+

   Gui, Add, Checkbox, % (packMethod ? "Checked" : "") " vpackMethod x20 y240 " . sectionColor . ((deleteMethod = "Inject Wonderpick 96P+") ? "" : " Hidden"), % currentDictionary.Txt_packMethod
   ; Gui, Add, Checkbox, % (nukeAccount ? "Checked" : "") " vnukeAccount x20 y240 " . sectionColor . ((deleteMethod = "Create Bots (13P)")? "": " Hidden"), % currentDictionary.Txt_nukeAccount
   Gui, Add, Checkbox, % (openExtraPack ? "Checked" : "") " vopenExtraPack gopenExtraPackSettings x20 y260 " . sectionColor . ((deleteMethod = "Inject Wonderpick 96P+" || deleteMethod = "Inject 13P+") ? "" : " Hidden"), % currentDictionary.Txt_openExtraPack
   Gui, Add, Checkbox, % (spendHourGlass ? "Checked" : "") " vspendHourGlass gspendHourGlassSettings x20 y280 " . sectionColor . ((deleteMethod = "Create Bots (13P)")? " Hidden":""), % currentDictionary.Txt_spendHourGlass

   Gui, Add, Text, x20 y305 %sectionColor% vSortByText, % currentDictionary.SortByText
   sortOption := 1
   if (injectSortMethod = "ModifiedDesc")
   sortOption := 2
   else if (injectSortMethod = "PacksAsc")
   sortOption := 3
   else if (injectSortMethod = "PacksDesc")
   sortOption := 4
   Gui, Add, DropDownList, vSortByDropdown gSortByDropdownHandler choose%sortOption% x20 y325 w130 Background2A2A2A cWhite, Oldest First|Newest First|Fewest Packs First|Most Packs First

   Gui, Add, Text, x20 y260 %sectionColor% vAccountNameText, % currentDictionary.Txt_AccountName
   Gui, Add, Edit, vAccountName w90 x130 y260 h20 -E0x200 Background2A2A2A cWhite Center, %AccountName%

   if (deleteMethod = "Create Bots (13P)") {
      GuiControl, Hide, SortByText
      GuiControl, Hide, SortByDropdown
   } else {
      GuiControl, Hide, AccountNameText
      GuiControl, Hide, AccountName
   }

   sectionColor := "cFFD700"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x255 y0 w180 h50 %sectionColor%, % currentDictionary.PackHeading

   UpdatePackSelectionButtonText()
   Gui, Add, Button, x275 y20 w140 h25 gShowPackSelection vPackSelectionButton BackgroundTrans, Loading...
   UpdatePackSelectionButtonText()

   sectionColor := "cFF4500"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x255 y55 w180 h50 %sectionColor%, % currentDictionary.CardDetection
   
   Gui, Add, Button, x275 y75 w140 h25 gShowCardDetection vCardDetectionButton BackgroundTrans, Loading...
   
   UpdateCardDetectionButtonText()

   sectionColor := "c4169E1"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x255 y110 w180 h70 %sectionColor%, % currentDictionary.SaveForTrade
   
   Gui, Add, Button, x275 y130 w140 h25 gShowS4TSettings vS4TButton BackgroundTrans, Loading...
   
   Gui, Font, s6 cWhite, Segoe UI
   Gui, Add, Button, x295 y160 w100 h15 gOpenTradesDashboard BackgroundTrans, Open Trades Dashboard
   
   UpdateS4TButtonText()

   sectionColor := "cWhite"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x255 y195 w180 h50 %sectionColor%, % currentDictionary.GroupSettings

   Gui, Add, Button, x275 y215 w140 h25 gShowGroupRerollSettings vGroupRerollButton BackgroundTrans, Loading...

   UpdateGroupRerollButtonText()

   Gui, Font, s10 cWhite, Segoe UI
   sectionColor := "c9370DB"
   Gui, Add, GroupBox, x255 y260 w180 h100 %sectionColor%, % currentDictionary.TimeSettings
   Gui, Add, Text, x270 y285 %sectionColor%, % currentDictionary.Txt_Delay
   Gui, Add, Edit, vDelay w30 x400 y285 h20 -E0x200 Background2A2A2A cWhite Center, %Delay%
   Gui, Add, Text, x270 y310 %sectionColor%, % currentDictionary.Txt_SwipeSpeed
   Gui, Add, Edit, vswipeSpeed w30 x400 y310 h20 -E0x200 Background2A2A2A cWhite Center, %swipeSpeed%
   Gui, Add, Text, x270 y335 %sectionColor%, % currentDictionary.Txt_WaitTime
   Gui, Add, Edit, vwaitTime w30 x400 y335 h20 -E0x200 Background2A2A2A cWhite Center, %waitTime%

   sectionColor := "cFF69B4"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x445 y0 w156 h130 %sectionColor%, % currentDictionary.DiscordSettingsHeading
   if(StrLen(discordUserID) < 3)
   discordUserID =
   if(StrLen(discordWebhookURL) < 3)
   discordWebhookURL =
   Gui, Add, Text, x455 y20 %sectionColor%, Discord ID:
   Gui, Add, Edit, vdiscordUserId w136 x455 y40 h20 -E0x200 Background2A2A2A cWhite, %discordUserId%
   Gui, Add, Text, x455 y60 %sectionColor%, Webhook URL:
   Gui, Add, Edit, vdiscordWebhookURL w136 x455 y80 h20 -E0x200 Background2A2A2A cWhite, %discordWebhookURL%
   Gui, Add, Checkbox, % (sendAccountXml ? "Checked" : "") " vsendAccountXml x455 y105 " . sectionColor, Send Account XML

   sectionColor := "c00FFFF"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x445 y130 w156 h180 %sectionColor%, % currentDictionary.HeartbeatSettingsSubHeading
   Gui, Add, Checkbox, % (heartBeat ? "Checked" : "") " vheartBeat x455 y155 gdiscordSettings " . sectionColor, % currentDictionary.Txt_heartBeat

   if(StrLen(heartBeatName) < 3)
   heartBeatName =
   if(StrLen(heartBeatWebhookURL) < 3)
   heartBeatWebhookURL =

   if (heartBeat) {
   Gui, Add, Text, vhbName x455 y175 %sectionColor%, % currentDictionary.hbName
   Gui, Add, Edit, vheartBeatName w136 x455 y195 h20 -E0x200 Background2A2A2A cWhite, %heartBeatName%
   Gui, Add, Text, vhbURL x455 y215 %sectionColor%, Webhook URL:
   Gui, Add, Edit, vheartBeatWebhookURL w136 x455 y235 h20 -E0x200 Background2A2A2A cWhite, %heartBeatWebhookURL%
   Gui, Add, Text, vhbDelay x455 y260 %sectionColor%, % currentDictionary.hbDelay
   Gui, Add, Edit, vheartBeatDelay w50 x455 y280 h20 -E0x200 Background2A2A2A cWhite Center, %heartBeatDelay%
   } else {
   Gui, Add, Text, vhbName x455 y175 Hidden %sectionColor%, % currentDictionary.hbName
   Gui, Add, Edit, vheartBeatName w136 x455 y195 h20 Hidden -E0x200 Background2A2A2A cWhite, %heartBeatName%
   Gui, Add, Text, vhbURL x455 y215 Hidden %sectionColor%, Webhook URL:
   Gui, Add, Edit, vheartBeatWebhookURL w136 x455 y235 h20 Hidden -E0x200 Background2A2A2A cWhite, %heartBeatWebhookURL%
   Gui, Add, Text, vhbDelay x455 y260 Hidden %sectionColor%, % currentDictionary.hbDelay
   Gui, Add, Edit, vheartBeatDelay w50 x455 y280 h20 Hidden -E0x200 Background2A2A2A cWhite Center, %heartBeatDelay%
   }

   Gui, Font, s10 cWhite
   Gui, Add, Picture, gOpenDiscord x455 y320 w36 h36, %A_ScriptDir%\GUI\Images\discord-icon.png
   Gui, Add, Picture, gOpenToolTip x505 y320 w36 h36, %A_ScriptDir%\GUI\Images\help-icon.png
   Gui, Add, Picture, gShowToolsAndSystemSettings x555 y322 w32 h32, %A_ScriptDir%\GUI\Images\tools-icon.png

   sectionColor := "cWhite"
   Gui, Add, GroupBox, x611 y0 w175 h360 %sectionColor%

   Gui, Font, s12 cWhite Bold
   Gui, Add, Text, x621 y20 w155 h50 Left BackgroundTrans cWhite, % currentDictionary.title_main
   Gui, Font, s10 cWhite Bold
   Gui, Add, Text, x621 y20 w155 h50 Left BackgroundTrans cWhite, % "`nv8.2.3 kevinnnn"

   Gui, Add, Picture, gBuyMeCoffee x625 y60, %A_ScriptDir%\GUI\Images\support_me_on_kofi.png

   Gui, Font, s10 cWhite Bold
   Gui, Add, Button, x621 y205 w155 h25 gBalanceXMLs BackgroundTrans, % currentDictionary.btn_balance
   Gui, Add, Button, x621 y240 w155 h40 gLaunchAllMumu BackgroundTrans, % currentDictionary.btn_mumu
   Gui, Add, Button, gSave x621 y290 w155 h40, Start Bot

   Gui, Font, s7 cGray
   Gui, Add, Text, x620 y340 w165 Center BackgroundTrans, CC BY-NC 4.0 international license

   Gui, Show, w%GUI_WIDTH% h%GUI_HEIGHT%, Arturo's PTCGP BOT

Return

mainSettings:
  Gui, Submit, NoHide
  if (runMain) {
    GuiControl, Show, Mains
  } else {
    GuiControl, Hide, Mains
  }
return

deleteSettings:
  Gui, Submit, NoHide

   if (deleteMethod != "Inject Wonderpick 96P+") {
    ClearCardDetectionSettings()
    s4tWP := false
    s4tWPMinCards := 1
   }

  if (deleteMethod = "Create Bots (13P)") {
    GuiControl, Hide, FriendID
    GuiControl, Hide, spendHourGlass
    GuiControl, Hide, packMethod
    GuiControl, Hide, openExtraPack
    ; GuiControl, Show, nukeAccount
    GuiControl, Hide, SortByText
    GuiControl, Hide, SortByDropdown
    GuiControl, Show, AccountNameText
    GuiControl, Show, AccountName
    GuiControl, Hide, WaitTime
    nukeAccount := false
    FriendID := ""
  } else if (deleteMethod = "Inject Wonderpick 96P+") {
    GuiControl, Show, FriendID
    GuiControl, Show, spendHourGlass
    GuiControl, Show, packMethod
    GuiControl, Show, openExtraPack
    ; GuiControl, Hide, nukeAccount
    GuiControl, Show, SortByText
    GuiControl, Show, SortByDropdown
    GuiControl, Hide, AccountNameText
    GuiControl, Hide, AccountName
    GuiControl, Show, WaitTime
    nukeAccount := false
  } else if (deleteMethod = "Inject 13P+") {
    GuiControl, Hide, FriendID
    GuiControl, Show, spendHourGlass
    GuiControl, Hide, packMethod
    GuiControl, Show, openExtraPack
    ; GuiControl, Hide, nukeAccount
    GuiControl, Show, SortByText
    GuiControl, Show, SortByDropdown
    GuiControl, Hide, AccountNameText
    GuiControl, Hide, AccountName
    GuiControl, Hide, WaitTime
    nukeAccount := false
    FriendID := ""  ; NEW: Clear Friend ID for Inject 13P+
  }
return

openExtraPackSettings:
  Gui, Submit, NoHide
  if (openExtraPack) {
    GuiControl,, spendHourGlass, 0
    spendHourGlass := false
  }
Return

spendHourGlassSettings:
  Gui, Submit, NoHide
  if (spendHourGlass) {
    GuiControl,, openExtraPack, 0
    openExtraPack := false
  }
Return

SortByDropdownHandler:
  Gui, Submit, NoHide
  GuiControlGet, selectedOption,, SortByDropdown
  if (selectedOption = "Oldest First")
    injectSortMethod := "ModifiedAsc"
  else if (selectedOption = "Newest First")
    injectSortMethod := "ModifiedDesc"
  else if (selectedOption = "Fewest Packs First")
    injectSortMethod := "PacksAsc"
  else if (selectedOption = "Most Packs First")
    injectSortMethod := "PacksDesc"
return

UpdatePackSelectionButtonText() {
    global MegaGyarados, MegaBlaziken, MegaAltaria, Deluxe, Springs, HoOh, Lugia, Eevee, Buzzwole, Solgaleo, Lunala, Shining, Arceus
    global Palkia, Dialga, Pikachu, Charizard, Mewtwo, Mew, currentDictionary
    
    selectedPacks := []

    if (MegaGyarados)
        selectedPacks.Push(currentDictionary.Txt_MegaGyarados)
    if (MegaBlaziken)
        selectedPacks.Push(currentDictionary.Txt_MegaBlaziken)
    if (MegaAltaria)
        selectedPacks.Push(currentDictionary.Txt_MegaAltaria)
    if (Deluxe)
        selectedPacks.Push(currentDictionary.Txt_Deluxe)
    if (Springs)
        selectedPacks.Push(currentDictionary.Txt_Springs)
    if (HoOh)
        selectedPacks.Push(currentDictionary.Txt_HoOh)
    if (Lugia)
        selectedPacks.Push(currentDictionary.Txt_Lugia)
    if (Eevee)
        selectedPacks.Push(currentDictionary.Txt_Eevee)
    if (Buzzwole)
        selectedPacks.Push(currentDictionary.Txt_Buzzwole)
    if (Solgaleo)
        selectedPacks.Push(currentDictionary.Txt_Solgaleo)
    if (Lunala)
        selectedPacks.Push(currentDictionary.Txt_Lunala)
    if (Shining)
        selectedPacks.Push("Shining Revelry")
    if (Arceus)
        selectedPacks.Push("Triumphant Light")
    if (Dialga)
        selectedPacks.Push(currentDictionary.Txt_Dialga)
    if (Palkia)
        selectedPacks.Push(currentDictionary.Txt_Palkia)
    if (Mew)
        selectedPacks.Push(currentDictionary.Txt_Mew)
    if (Charizard)
        selectedPacks.Push(currentDictionary.Txt_Charizard)
    if (Mewtwo)
        selectedPacks.Push(currentDictionary.Txt_Mewtwo)
    if (Pikachu)
        selectedPacks.Push(currentDictionary.Txt_Pikachu)
    
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
    GuiControl,, PackSelectionButton, %buttonText%
    GuiControl, Font, PackSelectionButton
}

ShowPackSelection:
    WinGetPos, mainWinX, mainWinY, mainWinW, mainWinH, A
    
    popupX := mainWinX + 275 + 140 + 10
    popupY := mainWinY - 50
    
    Gui, PackSelect:Destroy
    Gui, PackSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Pack Selection
    Gui, PackSelect:Color, 1E1E1E, 333333
    Gui, PackSelect:Font, s10 cWhite, Segoe UI

    yPos := 10
    Gui, PackSelect:Add, Checkbox, % (MegaGyarados ? "Checked" : "") " vMegaGyarados_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_MegaGyarados
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (MegaBlaziken ? "Checked" : "") " vMegaBlaziken_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_MegaBlaziken
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (MegaAltaria ? "Checked" : "") " vMegaAltaria_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_MegaAltaria
    yPos += 25
    ; Gui, PackSelect:Add, Checkbox, % (Deluxe ? "Checked" : "") " vDeluxe_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Deluxe
    ; yPos += 25    
    Gui, PackSelect:Add, Checkbox, % (Springs ? "Checked" : "") " vSprings_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Springs
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (HoOh ? "Checked" : "") " vHoOh_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_HoOh
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Lugia ? "Checked" : "") " vLugia_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Lugia
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Eevee ? "Checked" : "") " vEevee_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Eevee
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Buzzwole ? "Checked" : "") " vBuzzwole_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Buzzwole
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Solgaleo ? "Checked" : "") " vSolgaleo_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Solgaleo
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Lunala ? "Checked" : "") " vLunala_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Lunala
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Shining ? "Checked" : "") " vShining_Popup x10 y" . yPos . " cWhite", Shining Revelry
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Arceus ? "Checked" : "") " vArceus_Popup x10 y" . yPos . " cWhite", Triumphant Light
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Dialga ? "Checked" : "") " vDialga_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Dialga
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Palkia ? "Checked" : "") " vPalkia_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Palkia
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Mew ? "Checked" : "") " vMew_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Mew
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Charizard ? "Checked" : "") " vCharizard_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Charizard
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Mewtwo ? "Checked" : "") " vMewtwo_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Mewtwo
    yPos += 25
    Gui, PackSelect:Add, Checkbox, % (Pikachu ? "Checked" : "") " vPikachu_Popup x10 y" . yPos . " cWhite", % currentDictionary.Txt_Pikachu
    yPos += 35
    
    Gui, PackSelect:Add, Button, x10 y%yPos% w80 h30 gApplyPackSelection, Apply
    Gui, PackSelect:Add, Button, x100 y%yPos% w80 h30 gCancelPackSelection, Cancel
    yPos += 40
    
    Gui, PackSelect:Show, x%popupX% y%popupY% w200 h%yPos%
return

ApplyPackSelection:
    Gui, PackSelect:Submit, NoHide
    
    MegaGyarados := MegaGyarados_Popup
    MegaBlaziken := MegaBlaziken_Popup
    MegaAltaria := MegaAltaria_Popup
    Deluxe := Deluxe_Popup
    Springs := Springs_Popup
    HoOh := HoOh_Popup
    Lugia := Lugia_Popup
    Eevee := Eevee_Popup
    Buzzwole := Buzzwole_Popup
    Solgaleo := Solgaleo_Popup
    Lunala := Lunala_Popup
    Shining := Shining_Popup
    Arceus := Arceus_Popup
    Dialga := Dialga_Popup
    Palkia := Palkia_Popup
    Mew := Mew_Popup
    Charizard := Charizard_Popup
    Mewtwo := Mewtwo_Popup
    Pikachu := Pikachu_Popup
    
    Gui, PackSelect:Destroy
    
    Gui, 1:Default
    
    UpdatePackSelectionButtonText()
return

CancelPackSelection:
    Gui, PackSelect:Destroy
return

UpdateCardDetectionButtonText() {
    global FullArtCheck, TrainerCheck, RainbowCheck, PseudoGodPack
    global InvalidCheck, CrownCheck, ShinyCheck, ImmersiveCheck, minStars
    global currentDictionary
    
    enabledOptions := []
    
    if (FullArtCheck)
        enabledOptions.Push("Single Full Art")
    if (TrainerCheck)
        enabledOptions.Push("Single Trainer")
    if (RainbowCheck)
        enabledOptions.Push("Single Rainbow")
    if (PseudoGodPack)
        enabledOptions.Push("Double 2★")
    if (CrownCheck)
        enabledOptions.Push("Save Crowns")
    if (ShinyCheck)
        enabledOptions.Push("Save Shiny")
    if (ImmersiveCheck)
        enabledOptions.Push("Save Immersives")
    if (InvalidCheck)
        enabledOptions.Push("Ignore Invalid")
    
    statusText := ""
    if (minStars > 0) {
        statusText .= "Min GP 2★: " . minStars
    }
    
    if (enabledOptions.Length() > 0) {
        if (statusText != "")
            statusText .= "`n"
        statusText .= enabledOptions[1]
        if (enabledOptions.Length() > 1)
            statusText .= " +" . (enabledOptions.Length() - 1) . " more"
    } else {
        if (statusText != "")
            statusText .= "`n"
        statusText .= "No options selected"
    }
    
    if (statusText = "No options selected" && minStars = 0) {
        statusText := "Configure settings..."
    }
    
    Gui, Font, s8 cWhite, Segoe UI
    GuiControl, Font, CardDetectionButton
    GuiControl,, CardDetectionButton, %statusText%
}

ShowCardDetection:
    Gui, Submit, NoHide
    
    if (deleteMethod = "Create Bots (13P)" || deleteMethod = "Inject 13P+") {
        MsgBox, 64, InjectWP Card Detection, Wonderpick Card Detection is for 'Inject Wonderpick 96P+'' mode.`n`nTo find cards to trade, use 'Save for Trade' settings instead.
        return
    }
    
    WinGetPos, mainWinX, mainWinY, mainWinW, mainWinH, A
    
    popupX := mainWinX + 275 + 140 + 10
    popupY := mainWinY + 73 + 30
    
    Gui, CardDetect:Destroy
    Gui, CardDetect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Wonderpick Card Detection Settings
    Gui, CardDetect:Color, 1E1E1E, 333333
    Gui, CardDetect:Font, s10 cWhite, Segoe UI
    
    yPos := 15
    
    Gui, CardDetect:Add, Text, x15 y%yPos% cWhite, Min GP 2★:
    Gui, CardDetect:Add, Edit, vminStars_Popup w20 x140 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, %minStars%
    yPos += 25
      
    Gui, CardDetect:Add, Checkbox, % (FullArtCheck ? "Checked" : "") " vFullArtCheck_Popup x15 y" . yPos . " cWhite", Single Full Art 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (TrainerCheck ? "Checked" : "") " vTrainerCheck_Popup x15 y" . yPos . " cWhite", Single Trainer 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (RainbowCheck ? "Checked" : "") " vRainbowCheck_Popup x15 y" . yPos . " cWhite", Single Rainbow 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (PseudoGodPack ? "Checked" : "") " vPseudoGodPack_Popup x15 y" . yPos . " cWhite", Double 2★
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (InvalidCheck ? "Checked" : "") " vInvalidCheck_Popup x15 y" . yPos . " cWhite", Ignore Invalid Packs
    yPos += 35
    
    Gui, CardDetect:Add, Text, x15 y%yPos% w200 h2 +0x10
    yPos += 15
    
    Gui, CardDetect:Add, Checkbox, % (CrownCheck ? "Checked" : "") " vCrownCheck_Popup x15 y" . yPos . " cWhite", Save Crowns
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (ShinyCheck ? "Checked" : "") " vShinyCheck_Popup x15 y" . yPos . " cWhite", Save Shiny
    yPos += 25
    Gui, CardDetect:Add, Checkbox, % (ImmersiveCheck ? "Checked" : "") " vImmersiveCheck_Popup x15 y" . yPos . " cWhite", Save Immersives
    yPos += 40
    
    Gui, CardDetect:Add, Button, x15 y%yPos% w90 h30 gApplyCardDetection, Apply
    Gui, CardDetect:Add, Button, x115 y%yPos% w90 h30 gCancelCardDetection, Cancel
    yPos += 40
    
    Gui, CardDetect:Show, x%popupX% y%popupY% w230 h%yPos%
return

ApplyCardDetection:
    Gui, CardDetect:Submit, NoHide
    
    minStars := minStars_Popup
    minStarsShiny := minStars_Popup  ; Use same value for shiny packs
    FullArtCheck := FullArtCheck_Popup
    TrainerCheck := TrainerCheck_Popup
    RainbowCheck := RainbowCheck_Popup
    PseudoGodPack := PseudoGodPack_Popup
    CheckShinyPackOnly := 0  ; Always disabled
    InvalidCheck := InvalidCheck_Popup
    CrownCheck := CrownCheck_Popup
    ShinyCheck := ShinyCheck_Popup
    ImmersiveCheck := ImmersiveCheck_Popup
    
    Gui, CardDetect:Destroy
    
    Gui, 1:Default
    
    UpdateCardDetectionButtonText()
return

CancelCardDetection:
    Gui, CardDetect:Destroy
return

UpdateGroupRerollButtonText() {
    global groupRerollEnabled, mainIdsURL, vipIdsURL, autoUseGPTest, applyRoleFilters
    global currentDictionary
    
    if (!groupRerollEnabled) {
        Gui, Font, s8 cRed, Segoe UI
        GuiControl, Font, GroupRerollButton
        GuiControl,, GroupRerollButton, % currentDictionary.Txt_Disabled
        return
    }

    statusText := "Group reroll enabled"

    idsStatus := (mainIdsURL != "" && StrLen(mainIdsURL) > 5) ? "✓" : "✗"
    vipStatus := (vipIdsURL != "" && StrLen(vipIdsURL) > 5) ? "✓" : "✗"
    
    statusText .= "`n" . idsStatus . " ids API " . vipStatus . " vip_ids API"
    
    if (autoUseGPTest)
        statusText .= "`n• Auto GP Test"
    if (applyRoleFilters)
        statusText .= "`n• Role-Based filters"
    
    Gui, Font, s7 cLime, Segoe UI
    GuiControl, Font, GroupRerollButton
    GuiControl,, GroupRerollButton, %statusText%
}

ShowGroupRerollSettings:
    WinGetPos, mainWinX, mainWinY, mainWinW, mainWinH, A
    
    buttonCenterX := 345
    popupWidth := 250
    popupX := mainWinX + buttonCenterX - (popupWidth / 2)
    popupY := mainWinY + 183 + 30
    
    Gui, GroupRerollSelect:Destroy
    Gui, GroupRerollSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Group Reroll Settings
    Gui, GroupRerollSelect:Color, 1E1E1E, 333333
    Gui, GroupRerollSelect:Font, s10 cWhite, Segoe UI
    
    yPos := 15
    Gui, GroupRerollSelect:Add, Checkbox, % (groupRerollEnabled ? "Checked" : "") " vgroupRerollEnabled_Popup x15 y" . yPos . " cWhite", Enable Group Reroll
    yPos += 35
    
    Gui, GroupRerollSelect:Add, Text, x15 y%yPos% cWhite, ids.txt API URL:
    yPos += 20
    Gui, GroupRerollSelect:Add, Edit, vmainIdsURL_Popup w220 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, %mainIdsURL%
    yPos += 35
    
    Gui, GroupRerollSelect:Add, Text, x15 y%yPos% cWhite, vip_ids.txt API URL:
    yPos += 20  
    Gui, GroupRerollSelect:Add, Edit, vvipIdsURL_Popup w220 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, %vipIdsURL%
    yPos += 35
    
    Gui, GroupRerollSelect:Add, Checkbox, % (autoUseGPTest ? "Checked" : "") " vautoUseGPTest_Popup x15 y" . yPos . " cWhite", Auto GPTest (s)
    yPos += 20
    Gui, GroupRerollSelect:Add, Edit, vTestTime_Popup w50 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, %TestTime%
    yPos += 35
    
    Gui, GroupRerollSelect:Add, Checkbox, % (applyRoleFilters ? "Checked" : "") " vapplyRoleFilters_Popup x15 y" . yPos . " cWhite", Role-Based Filters
    yPos += 40
    
    Gui, GroupRerollSelect:Add, Button, x15 y%yPos% w90 h30 gApplyGroupRerollSettings, Apply
    Gui, GroupRerollSelect:Add, Button, x115 y%yPos% w90 h30 gCancelGroupRerollSettings, Cancel
    yPos += 40
    
    Gui, GroupRerollSelect:Show, x%popupX% y%popupY% w250 h%yPos%
return

ApplyGroupRerollSettings:
    Gui, GroupRerollSelect:Submit, NoHide
    
    groupRerollEnabled := groupRerollEnabled_Popup
    mainIdsURL := mainIdsURL_Popup
    vipIdsURL := vipIdsURL_Popup
    autoUseGPTest := autoUseGPTest_Popup
    TestTime := TestTime_Popup
    applyRoleFilters := applyRoleFilters_Popup
    
    Gui, GroupRerollSelect:Destroy
    
    Gui, 1:Default
    
    UpdateGroupRerollButtonText()
    
    GuiControl,, groupRerollEnabled, %groupRerollEnabled%
    GuiControl,, mainIdsURL, %mainIdsURL%
    GuiControl,, vipIdsURL, %vipIdsURL%
    GuiControl,, autoUseGPTest, %autoUseGPTest%
    GuiControl,, TestTime, %TestTime%
    GuiControl,, applyRoleFilters, %applyRoleFilters%
return

CancelGroupRerollSettings:
    Gui, GroupRerollSelect:Destroy
return

UpdateS4TButtonText() {
    global s4tEnabled, s4t1Star, s4t3Dmnd, s4t4Dmnd, currentDictionary
    global s4tTrainer, s4tRainbow, s4tFullArt, s4tCrown, s4tImmersive, s4tShiny1Star, s4tShiny2Star
    
    if (!s4tEnabled) {
        Gui, Font, s8 cRed, Segoe UI
        GuiControl, Font, S4TButton
        GuiControl,, S4TButton, % currentDictionary.Txt_S4TDisabled
        return
    }

    enabledOptions := []
    if (s4t1Star)
        enabledOptions.Push("1★")
    if (s4t4Dmnd)
        enabledOptions.Push("4◆")
    if (s4t3Dmnd)
        enabledOptions.Push("3◆")
    if (s4tTrainer)
        enabledOptions.Push("Trainer")
    if (s4tRainbow)
        enabledOptions.Push("Rainbow")
    if (s4tFullArt)
        enabledOptions.Push("Full Art")
    if (s4tCrown)
        enabledOptions.Push("Crown")
    if (s4tImmersive)
        enabledOptions.Push("Immersive")
    if (s4tShiny1Star)
        enabledOptions.Push("Shiny1★")
    if (s4tShiny2Star)
        enabledOptions.Push("Shiny2★")
    
    statusText := currentDictionary.Txt_S4TEnabled
    if (enabledOptions.Length() > 0) {
        statusText .= "`n" . enabledOptions[1]
        if (enabledOptions.Length() > 1)
            statusText .= " +" . (enabledOptions.Length() - 1) . " more"
    }
    
    Gui, Font, s8 cLime, Segoe UI
    GuiControl, Font, S4TButton
    GuiControl,, S4TButton, %statusText%
}

ShowSystemSettings:
    WinGetPos, mainWinX, mainWinY, mainWinW, mainWinH, A
    
    buttonCenterX := 698
    popupWidth := 280
    popupX := mainWinX + buttonCenterX - (popupWidth / 2)
    popupY := mainWinY + 125 + 30
    
    Gui, SystemSettingsSelect:Destroy
    Gui, SystemSettingsSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, % currentDictionary.Txt_SystemSettings
    Gui, SystemSettingsSelect:Color, 1E1E1E, 333333
    Gui, SystemSettingsSelect:Font, s10 cWhite, Segoe UI
    
    sectionColor := "c4169E1"
    
    yPos := 15
    Gui, SystemSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, % currentDictionary.Txt_Monitor
    yPos += 20
    SysGet, MonitorCount, MonitorCount
    MonitorOptions := ""
    Loop, %MonitorCount% {
        SysGet, MonitorName, MonitorName, %A_Index%
        SysGet, Monitor, Monitor, %A_Index%
        MonitorOptions .= (A_Index > 1 ? "|" : "") "" A_Index ": (" MonitorRight - MonitorLeft "x" MonitorBottom - MonitorTop ")"
    }
    SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
    Gui, SystemSettingsSelect:Add, DropDownList, x15 y%yPos% w125 vSelectedMonitorIndex_Popup Choose%SelectedMonitorIndex% Background2A2A2A cWhite, %MonitorOptions%
    
    Gui, SystemSettingsSelect:Add, Text, x155 y%yPos% %sectionColor%, % currentDictionary.Txt_Scale
    if (defaultLanguage = "Scale125") {
        defaultLang := 1
    } else if (defaultLanguage = "Scale100") {
        defaultLang := 2
    }
    Gui, SystemSettingsSelect:Add, DropDownList, x155 y%yPos% w75 vdefaultLanguage_Popup choose%defaultLang% Background2A2A2A cWhite, Scale125|Scale100
    yPos += 35
    
    Gui, SystemSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, % currentDictionary.Txt_RowGap
    Gui, SystemSettingsSelect:Add, Edit, vRowGap_Popup w50 x125 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, %RowGap%
    yPos += 35
    
    Gui, SystemSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, % currentDictionary.Txt_FolderPath
    yPos += 20
    Gui, SystemSettingsSelect:Add, Edit, vfolderPath_Popup w250 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, %folderPath%
    yPos += 35
    
    Gui, SystemSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, OCR:
    ocrLanguageList := "en|zh|es|de|fr|ja|ru|pt|ko|it|tr|pl|nl|sv|ar|uk|id|vi|th|he|cs|no|da|fi|hu|el|zh-TW"
    defaultOcrLang := 1
    if (ocrLanguage != "") {
        index := 0
        Loop, Parse, ocrLanguageList, |
        {
            index++
            if (A_LoopField = ocrLanguage) {
                defaultOcrLang := index
                break
            }
        }
    }
    Gui, SystemSettingsSelect:Add, DropDownList, vocrLanguage_Popup choose%defaultOcrLang% x60 y%yPos% w50 Background2A2A2A cWhite, %ocrLanguageList%
    
    Gui, SystemSettingsSelect:Add, Text, x125 y%yPos% %sectionColor%, Client: 
    clientLanguageList := "en|es|fr|de|it|pt|jp|ko|cn"
    defaultClientLang := 1
    if (clientLanguage != "") {
        index := 0
        Loop, Parse, clientLanguageList, |
        {
            index++
            if (A_LoopField = clientLanguage) {
                defaultClientLang := index
                break
            }
        }
    }
    Gui, SystemSettingsSelect:Add, DropDownList, vclientLanguage_Popup choose%defaultClientLang% x170 y%yPos% w50 Background2A2A2A cWhite, %clientLanguageList%
    yPos += 35
    
    Gui, SystemSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, % currentDictionary.Txt_InstanceLaunchDelay
    Gui, SystemSettingsSelect:Add, Edit, vinstanceLaunchDelay_Popup w50 x170 y%yPos% h20 -E0x200 Background2A2A2A cWhite Center, %instanceLaunchDelay%
    yPos += 35
    
    Gui, SystemSettingsSelect:Add, Checkbox, % (autoLaunchMonitor ? "Checked" : "") " vautoLaunchMonitor_Popup x15 y" . yPos . " " . sectionColor, % currentDictionary.Txt_autoLaunchMonitor
    yPos += 40
    
    Gui, SystemSettingsSelect:Add, Button, x15 y%yPos% w100 h30 gApplySystemSettings, Apply
    Gui, SystemSettingsSelect:Add, Button, x125 y%yPos% w100 h30 gCancelSystemSettings, Cancel
    yPos += 40
    
    Gui, SystemSettingsSelect:Show, x%popupX% y%popupY% w280 h%yPos%
return

ApplySystemSettings:
    Gui, SystemSettingsSelect:Submit, NoHide
    
    SelectedMonitorIndex := SelectedMonitorIndex_Popup
    defaultLanguage := defaultLanguage_Popup
    RowGap := RowGap_Popup
    folderPath := folderPath_Popup
    ocrLanguage := ocrLanguage_Popup
    clientLanguage := clientLanguage_Popup
    instanceLaunchDelay := instanceLaunchDelay_Popup
    autoLaunchMonitor := autoLaunchMonitor_Popup
    
    Gui, SystemSettingsSelect:Destroy
    
    Gui, 1:Default
return

CancelSystemSettings:
    Gui, SystemSettingsSelect:Destroy
return

ShowS4TSettings:
    WinGetPos, mainWinX, mainWinY, mainWinW, mainWinH, A
    
    buttonCenterX := 375
    popupWidth := 200
    popupX := mainWinX + buttonCenterX - (popupWidth / 2)
    popupY := mainWinY + 0
    
    Gui, S4TSettingsSelect:Destroy
    Gui, S4TSettingsSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Save for Trade Settings
    Gui, S4TSettingsSelect:Color, 1E1E1E, 333333
    Gui, S4TSettingsSelect:Font, s10 cWhite, Segoe UI
    
    sectionColor := "c4169E1"
    
    yPos := 15
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tEnabled ? "Checked" : "") " vs4tEnabled_Popup x15 y" . yPos . " cWhite", Enable S4T
    yPos += 25
    
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4t3Dmnd ? "Checked" : "") " vs4t3Dmnd_Popup x15 y" . yPos . " " . sectionColor, ◆◆◆
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4t4Dmnd ? "Checked" : "") " vs4t4Dmnd_Popup x15 y" . yPos . " " . sectionColor, ◆◆◆◆
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4t1Star ? "Checked" : "") " vs4t1Star_Popup x15 y" . yPos . " " . sectionColor, ★
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tShiny1Star ? "Checked" : "") " vs4tShiny1Star_Popup x15 y" . yPos . " " . sectionColor, ★ Shiny
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tTrainer ? "Checked" : "") " vs4tTrainer_Popup x15 y" . yPos . " " . sectionColor, ★★ Trainer
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tRainbow ? "Checked" : "") " vs4tRainbow_Popup x15 y" . yPos . " " . sectionColor, ★★ Rainbow
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tFullArt ? "Checked" : "") " vs4tFullArt_Popup x15 y" . yPos . " " . sectionColor, ★★ Full Art
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tShiny2Star ? "Checked" : "") " vs4tShiny2Star_Popup x15 y" . yPos . " " . sectionColor, ★★ Shiny
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tImmersive ? "Checked" : "") " vs4tImmersive_Popup x15 y" . yPos . " " . sectionColor, Immersive
    yPos += 18
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tCrown ? "Checked" : "") " vs4tCrown_Popup x15 y" . yPos . " " . sectionColor, ♚ Crown Rare
    yPos += 25
    
    ; Wonderpick section
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tWP ? "Checked" : "") " vs4tWP_Popup x15 y" . yPos . " cWhite", % currentDictionary.Txt_s4tWP
    yPos += 20
    Gui, S4TSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, % currentDictionary.Txt_s4tWPMinCards
    Gui, S4TSettingsSelect:Add, Edit, cFDFDFD w40 x135 y%yPos% h20 vs4tWPMinCards_Popup -E0x200 Background2A2A2A Center cWhite, %s4tWPMinCards%
    yPos += 30
    if (deleteMethod != "Inject Wonderpick 96P+") {
        GuiControl, S4TSettingsSelect:Hide, s4tWP_Popup
        GuiControl, S4TSettingsSelect:Hide, s4tWPMinCardsText_Popup
        GuiControl, S4TSettingsSelect:Hide, s4tWPMinCards_Popup
        yPos -= 50  ; Adjust yPos since we're hiding these controls
    }
    
    ; Discord settings
    if(StrLen(s4tDiscordUserId) < 3)
        s4tDiscordUserId := ""
    if(StrLen(s4tDiscordWebhookURL) < 3)
        s4tDiscordWebhookURL := ""
    
    Gui, S4TSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, S4T Discord ID:
    yPos += 20
    Gui, S4TSettingsSelect:Add, Edit, vs4tDiscordUserId_Popup w170 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, %s4tDiscordUserId%
    yPos += 25
    
    Gui, S4TSettingsSelect:Add, Text, x15 y%yPos% %sectionColor%, Webhook URL:
    yPos += 20
    Gui, S4TSettingsSelect:Add, Edit, vs4tDiscordWebhookURL_Popup w170 x15 y%yPos% h20 -E0x200 Background2A2A2A cWhite, %s4tDiscordWebhookURL%
    yPos += 25
    
    Gui, S4TSettingsSelect:Add, Checkbox, % (s4tSendAccountXml ? "Checked" : "") " vs4tSendAccountXml_Popup x15 y" . yPos . " " . sectionColor, % currentDictionary.Txt_s4tSendAccountXml
    yPos += 20
    
    Gui, S4TSettingsSelect:Add, Checkbox, % (ocrShinedust ? "Checked" : "") " vocrShinedust_Popup x15 y" . yPos . " " . sectionColor, Track Shinedust
    yPos += 25
    ; Gui, S4TSettingsSelect:Add, Checkbox, % (s4tSilent ? "Checked" : "") " vs4tSilent_Popup x15 y" . yPos . " " . sectionColor, Silent (No Ping)
    ; yPos += 35
    
    Gui, S4TSettingsSelect:Add, Button, x15 y%yPos% w70 h30 gApplyS4TSettings, Apply
    Gui, S4TSettingsSelect:Add, Button, x95 y%yPos% w70 h30 gCancelS4TSettings, Cancel
    yPos += 40
    
    Gui, S4TSettingsSelect:Show, x%popupX% y%popupY% w200 h%yPos%
return

ApplyS4TSettings:
    Gui, S4TSettingsSelect:Submit, NoHide
    
    s4tEnabled := s4tEnabled_Popup
    s4t1Star := s4t1Star_Popup
    s4t4Dmnd := s4t4Dmnd_Popup
    s4t3Dmnd := s4t3Dmnd_Popup
    s4tTrainer := s4tTrainer_Popup
    s4tRainbow := s4tRainbow_Popup
    s4tFullArt := s4tFullArt_Popup
    s4tCrown := s4tCrown_Popup
    s4tImmersive := s4tImmersive_Popup
    s4tShiny1Star := s4tShiny1Star_Popup
    s4tShiny2Star := s4tShiny2Star_Popup
    s4tWP := s4tWP_Popup
    s4tWPMinCards := s4tWPMinCards_Popup
    s4tDiscordUserId := s4tDiscordUserId_Popup
    s4tDiscordWebhookURL := s4tDiscordWebhookURL_Popup
    s4tSendAccountXml := s4tSendAccountXml_Popup
    ocrShinedust := ocrShinedust_Popup
    s4tSilent := 0
    ; s4tSilent := s4tSilent_Popup
    
    if (s4tWPMinCards < 1)
        s4tWPMinCards := 1
    if (s4tWPMinCards > 2)
        s4tWPMinCards := 2
    
    Gui, S4TSettingsSelect:Destroy
    
    Gui, 1:Default
    
    GuiControl,, s4tEnabled, %s4tEnabled%
    GuiControl,, s4t1Star, %s4t1Star%
    GuiControl,, s4t4Dmnd, %s4t4Dmnd%
    GuiControl,, s4t3Dmnd, %s4t3Dmnd%
    GuiControl,, s4tTrainer, %s4tTrainer%
    GuiControl,, s4tRainbow, %s4tRainbow%
    GuiControl,, s4tFullArt, %s4tFullArt%
    GuiControl,, s4tCrown, %s4tCrown%
    GuiControl,, s4tImmersive, %s4tImmersive%
    GuiControl,, s4tShiny1Star, %s4tShiny1Star%
    GuiControl,, s4tShiny2Star, %s4tShiny2Star%
    GuiControl,, s4tWP, %s4tWP%
    GuiControl,, s4tWPMinCards, %s4tWPMinCards%
    GuiControl,, s4tDiscordUserId, %s4tDiscordUserId%
    GuiControl,, s4tDiscordWebhookURL, %s4tDiscordWebhookURL%
    GuiControl,, ocrShinedust, %ocrShinedust%
    GuiControl,, s4tSendAccountXml, %s4tSendAccountXml%
    ; GuiControl,, s4tSilent, %s4tSilent%
    
    UpdateS4TButtonText()
return

CancelS4TSettings:
    Gui, S4TSettingsSelect:Destroy
return

ShowToolsAndSystemSettings:
    WinGetPos, mainWinX, mainWinY, mainWinW, mainWinH, A
    
    popupX := mainWinX + 555
    popupY := mainWinY - 25
    
    Gui, ToolsAndSystemSelect:Destroy
    Gui, ToolsAndSystemSelect:New, +ToolWindow -MaximizeBox -MinimizeBox +LastFound, Tools & System Settings
    Gui, ToolsAndSystemSelect:Color, 1E1E1E, 333333
    Gui, ToolsAndSystemSelect:Font, s10 cWhite, Segoe UI
    
    col1X := 15
    col1W := 190
    yPos := 15
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (debugMode ? "Checked" : "") " vdebugMode_Popup x" . col1X . " y" . yPos . " cWhite", Debug Mode
    yPos += 20
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (statusMessage ? "Checked" : "") " vstatusMessage_Popup x" . col1X . " y" . yPos . " cWhite", Status Messages
    yPos += 20
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (showcaseEnabled ? "Checked" : "") " vshowcaseEnabled_Popup x" . col1X . " y" . yPos . " cWhite", 5x Showcase Likes
    yPos += 20
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (claimDailyMission ? "Checked" : "") " vclaimDailyMission_Popup x" . col1X . " y" . yPos . " cWhite", Claim Daily 4 Hourglasses
    yPos += 20
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (checkWPthanks ? "Checked" : "") " vcheckWPthanks_Popup x" . col1X . " y" . yPos . " cWhite", Check for Wonderpick Thanks
    yPos += 20
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (slowMotion ? "Checked" : "") " vslowMotion_Popup x" . col1X . " y" . yPos . " cWhite", No Speedmod Menu Clicks
    yPos += 35
    
    sectionColor := "cWhite"
    eventMissionBoxH := 90
    Gui, ToolsAndSystemSelect:Add, GroupBox, x%col1X% y%yPos% w%col1W% h%eventMissionBoxH% %sectionColor%, Special Event Missions
    yPos += 20
    
    Gui, ToolsAndSystemSelect:Add, Button, x25 y%yPos% w170 h20 gClearSpecialMissionHistory BackgroundTrans, Reset Claim Status
    yPos += 25
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (claimSpecialMissions ? "Checked" : "") " vclaimSpecialMissions_Popup x25 y" . yPos . " cWhite", Claim Rewards
    yPos += 20
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (wonderpickForEventMissions ? "Checked" : "") " vwonderpickForEventMissions_Popup x40 y" . yPos . " cWhite", Wonderpick
    
    col2X := 220
    col2W := 190
    yPos2 := 15
    sectionColor := "cWhite"
    
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, % currentDictionary.Txt_Monitor
    yPos2 += 20
    SysGet, MonitorCount, MonitorCount
    MonitorOptions := ""
    Loop, %MonitorCount% {
        SysGet, MonitorName, MonitorName, %A_Index%
        SysGet, Monitor, Monitor, %A_Index%
        MonitorOptions .= (A_Index > 1 ? "|" : "") "" A_Index ": (" MonitorRight - MonitorLeft "x" MonitorBottom - MonitorTop ")"
    }
    SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
    Gui, ToolsAndSystemSelect:Add, DropDownList, x%col2X% y%yPos2% w100 vSelectedMonitorIndex_Popup Choose%SelectedMonitorIndex% Background2A2A2A cWhite, %MonitorOptions%
    
    Gui, ToolsAndSystemSelect:Add, Text, x325 y15 %sectionColor%, % currentDictionary.Txt_Scale
    if (defaultLanguage = "Scale125") {
        defaultLang := 1
    } else if (defaultLanguage = "Scale100") {
        defaultLang := 2
    }
    Gui, ToolsAndSystemSelect:Add, DropDownList, x325 y%yPos2% w75 vdefaultLanguage_Popup choose%defaultLang% Background2A2A2A cWhite, Scale125|Scale100
    yPos2 += 25
    
    rowGapY := yPos2 + 2
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%rowGapY% %sectionColor%, % currentDictionary.Txt_RowGap
    Gui, ToolsAndSystemSelect:Add, Edit, vRowGap_Popup w25 x300 y%rowGapY% h20 -E0x200 Background2A2A2A cWhite Center, %RowGap%
    yPos2 += 25
    
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, % currentDictionary.Txt_FolderPath
    yPos2 += 20
    Gui, ToolsAndSystemSelect:Add, Edit, vfolderPath_Popup w170 x%col2X% y%yPos2% h20 -E0x200 Background2A2A2A cWhite, %folderPath%
    yPos2 += 25
    
    ocrTextY := yPos2 + 2
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%ocrTextY% %sectionColor%, OCR:
    ocrLanguageList := "en|zh|es|de|fr|ja|ru|pt|ko|it|tr|pl|nl|sv|ar|uk|id|vi|th|he|cs|no|da|fi|hu|el|zh-TW"
    defaultOcrLang := 1
    if (ocrLanguage != "") {
        index := 0
        Loop, Parse, ocrLanguageList, |
        {
            index++
            if (A_LoopField = ocrLanguage) {
                defaultOcrLang := index
                break
            }
        }
    }
    Gui, ToolsAndSystemSelect:Add, DropDownList, vocrLanguage_Popup choose%defaultOcrLang% x255 y%yPos2% w40 Background2A2A2A cWhite, %ocrLanguageList%
    
    clientTextY := yPos2 + 2
    Gui, ToolsAndSystemSelect:Add, Text, x305 y%clientTextY% %sectionColor%, Client:
    clientLanguageList := "en|es|fr|de|it|pt|jp|ko|cn"
    defaultClientLang := 1
    if (clientLanguage != "") {
        index := 0
        Loop, Parse, clientLanguageList, |
        {
            index++
            if (A_LoopField = clientLanguage) {
                defaultClientLang := index
                break
            }
        }
    }
    Gui, ToolsAndSystemSelect:Add, DropDownList, vclientLanguage_Popup choose%defaultClientLang% x345 y%yPos2% w40 Background2A2A2A cWhite, %clientLanguageList%
    yPos2 += 25
    
    Gui, ToolsAndSystemSelect:Add, Text, x%col2X% y%yPos2% %sectionColor%, % currentDictionary.Txt_InstanceLaunchDelay
    Gui, ToolsAndSystemSelect:Add, Edit, vinstanceLaunchDelay_Popup w30 x355 y%yPos2% h20 -E0x200 Background2A2A2A cWhite Center, %instanceLaunchDelay%
    yPos2 += 25
    
    autoMonitorY := yPos2 - 5
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (autoLaunchMonitor ? "Checked" : "") " vautoLaunchMonitor_Popup x" . col2X . " y" . autoMonitorY . " " . sectionColor, % currentDictionary.Txt_autoLaunchMonitor
    yPos2 += 20
    
    Gui, ToolsAndSystemSelect:Font, s8 cWhite, Segoe UI
    xmlSortY := yPos2 - 5
    Gui, ToolsAndSystemSelect:Add, Button, x%col2X% y%xmlSortY% w170 h20 gRunXMLSortTool BackgroundTrans, XML Sort Tool
    yPos2 += 20
    xmlDupY := yPos2 - 5
    Gui, ToolsAndSystemSelect:Add, Button, x%col2X% y%xmlDupY% w170 h20 gRunXMLDuplicateTool BackgroundTrans, XML Duplicate Tool
    yPos2 += 25
    
    Gui, ToolsAndSystemSelect:Font, s10 cWhite, Segoe UI
    
    finalY := yPos2
    buttonY := finalY - 5
    Gui, ToolsAndSystemSelect:Add, Button, x140 y%buttonY% w70 h30 gApplyToolsAndSystemSettings, Apply
    Gui, ToolsAndSystemSelect:Add, Button, x220 y%buttonY% w70 h30 gCancelToolsAndSystemSettings, Cancel
    finalY += 35
    
    Gui, ToolsAndSystemSelect:Show, x%popupX% y%popupY% w410 h%finalY%
return

ApplyToolsAndSystemSettings:
    Gui, ToolsAndSystemSelect:Submit, NoHide
    
    debugMode := debugMode_Popup
    statusMessage := statusMessage_Popup
    showcaseEnabled := showcaseEnabled_Popup
    claimDailyMission := claimDailyMission_Popup
    slowMotion := slowMotion_Popup
    claimSpecialMissions := claimSpecialMissions_Popup
    wonderpickForEventMissions := wonderpickForEventMissions_Popup
    
    SelectedMonitorIndex := SelectedMonitorIndex_Popup
    defaultLanguage := defaultLanguage_Popup
    RowGap := RowGap_Popup
    folderPath := folderPath_Popup
    ocrLanguage := ocrLanguage_Popup
    clientLanguage := clientLanguage_Popup
    instanceLaunchDelay := instanceLaunchDelay_Popup
    autoLaunchMonitor := autoLaunchMonitor_Popup
    checkWPthanks := checkWPthanks_Popup
    
    Gui, ToolsAndSystemSelect:Destroy
    
    Gui, 1:Default
    
    GuiControl,, debugMode, %debugMode%
    GuiControl,, statusMessage, %statusMessage%
    GuiControl,, showcaseEnabled, %showcaseEnabled%
    GuiControl,, claimDailyMission, %claimDailyMission% 
    GuiControl,, slowMotion, %slowMotion%
    GuiControl,, claimSpecialMissions, %claimSpecialMissions%
    GuiControl,, wonderpickForEventMissions, %wonderpickForEventMissions%
    GuiControl,, checkWPthanks, %checkWPthanks%
return

CancelToolsAndSystemSettings:
    Gui, ToolsAndSystemSelect:Destroy
return

discordSettings:
  Gui, Submit, NoHide
  if (heartBeat) {
    GuiControl, Show, heartBeatName
    GuiControl, Show, heartBeatWebhookURL
    GuiControl, Show, heartBeatDelay
    GuiControl, Show, hbName
    GuiControl, Show, hbURL
    GuiControl, Show, hbDelay
  } else {
    GuiControl, Hide, heartBeatName
    GuiControl, Hide, heartBeatWebhookURL
    GuiControl, Hide, heartBeatDelay
    GuiControl, Hide, hbName
    GuiControl, Hide, hbURL
    GuiControl, Hide, hbDelay
  }
return

claimSpecialMissionsHandler:
    Gui, Submit, NoHide
    if (claimSpecialMissions = "" || claimSpecialMissions = 0)
        claimSpecialMissions := 0
    else
        claimSpecialMissions := 1
    
    IniWrite, %claimSpecialMissions%, Settings.ini, UserSettings, claimSpecialMissions
    return

ClearSpecialMissionHistory:
    MsgBox, 4, Clear Special Mission History, Reset ALL /Accounts/Saved/ .xml files Special Mission completion history? This will remove the 'X' suffix from all filenames so that PTCGPB will try collecting Special Missions again on all accounts.
    IfMsgBox, Yes
    {
        baseDir := A_ScriptDir . "\Accounts\Saved"
        
        filesProcessed := 0
        
        ; Process all XML files in base directory and subdirectories
        Loop, Files, %baseDir%\*.xml, R
        {
            filePath := A_LoopFileFullPath
            fileName := A_LoopFileName
            fileDir := A_LoopFileDir
            
            ; Check if filename contains (X) or ends with X before .xml
            if (InStr(fileName, "(") && InStr(fileName, "X") && InStr(fileName, ")"))
            {
                ; Remove X from metadata in parentheses
                newFileName := RegExReplace(fileName, "\(([^X)]*)?X([^)]*)?\)", "($1$2)")
                ; Clean up empty parentheses
                newFileName := RegExReplace(newFileName, "\(\)", "")
                
                if (newFileName != fileName)
                {
                    newFilePath := fileDir . "\" . newFileName
                    FileMove, %filePath%, %newFilePath%
                    if (!ErrorLevel)
                        filesProcessed++
                }
            }
        }
        
        MsgBox, 64, Clear Special Mission History Complete, Done
    }
    return

    
Save:
  Gui, Submit, NoHide

  if (deleteMethod != "Inject Wonderpick 96P+") {
   s4tWP := false
   s4tWPMinCards := 1
  }

  Deluxe := 0 ; Turn off Deluxe for all users now that pack is removed
  
  SaveAllSettings()
  
  if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
    MsgBox, 0x40000,, % SetUpDictionary.Error_BotPathTooLong
    return
  }

  confirmMsg := SetUpDictionary.Confirm_SelectedMethod . deleteMethod . "`n"
  
  confirmMsg .= "Instances: " . Instances
  if (runMain) {
    confirmMsg .= " + " . Mains . " Main"
  }
  confirmMsg .= "`n"
  
  confirmMsg .= "`n" . SetUpDictionary.Confirm_SelectedPacks . "`n"
  if (MegaGyarados)
    confirmMsg .= "• " . currentDictionary.Txt_MegaGyarados . "`n"
  if (MegaBlaziken)
    confirmMsg .= "• " . currentDictionary.Txt_MegaBlaziken . "`n"
  if (MegaAltaria)
    confirmMsg .= "• " . currentDictionary.Txt_MegaAltaria . "`n"  
  if (Deluxe)
    confirmMsg .= "• " . currentDictionary.Txt_Deluxe . "`n"
  if (Springs)
    confirmMsg .= "• " . currentDictionary.Txt_Springs . "`n"
  if (HoOh)
    confirmMsg .= "• " . currentDictionary.Txt_HoOh . "`n"
  if (Lugia)
    confirmMsg .= "• " . currentDictionary.Txt_Lugia . "`n"
  if (Eevee) 
    confirmMsg .= "• " . currentDictionary.Txt_Eevee . "`n"
  if (Buzzwole)
    confirmMsg .= "• " . currentDictionary.Txt_Buzzwole . "`n"
  if (Solgaleo)
    confirmMsg .= "• " . currentDictionary.Txt_Solgaleo . "`n"
  if (Lunala)
    confirmMsg .= "• " . currentDictionary.Txt_Lunala . "`n"
  if (Shining)
    confirmMsg .= "• " . currentDictionary.Txt_Shining . "`n"
  if (Arceus)
    confirmMsg .= "• " . currentDictionary.Txt_Arceus . "`n"
  if (Palkia)
    confirmMsg .= "• " . currentDictionary.Txt_Palkia . "`n"
  if (Dialga)
    confirmMsg .= "• " . currentDictionary.Txt_Dialga . "`n"
  if (Pikachu)
    confirmMsg .= "• " . currentDictionary.Txt_Pikachu . "`n"
  if (Charizard)
    confirmMsg .= "• " . currentDictionary.Txt_Charizard . "`n"
  if (Mewtwo)
    confirmMsg .= "• " . currentDictionary.Txt_Mewtwo . "`n"
  if (Mew)
    confirmMsg .= "• " . currentDictionary.Txt_Mew . "`n"
  
  additionalSettings := ""
  if (packMethod)
    additionalSettings .= SetUpDictionary.Confirm_1PackMethod . "`n"
  ; if (nukeAccount && !injectMethod)
    ; additionalSettings .= SetUpDictionary.Confirm_MenuDelete . "`n"
  if (openExtraPack)
    additionalSettings .= SetUpDictionary.Confirm_openExtraPack . "`n"
  if (spendHourGlass)
    additionalSettings .= SetUpDictionary.Confirm_SpendHourGlass . "`n"
  if (claimSpecialMissions)
    additionalSettings .= SetUpDictionary.Confirm_ClaimMissions . "`n"
  if (showcaseEnabled)
    additionalSettings .= "• Showcase Likes`n"
  if (injectMethod) {
    additionalSettings .= SetUpDictionary.Confirm_SortBy . " "
    if (injectSortMethod = "ModifiedAsc")
      additionalSettings .= "Oldest First`n"
    else if (injectSortMethod = "ModifiedDesc")
      additionalSettings .= "Newest First`n"
    else if (injectSortMethod = "PacksAsc")
      additionalSettings .= "Fewest Packs First`n"
    else if (injectSortMethod = "PacksDesc")
      additionalSettings .= "Most Packs First`n"
  }
  
  if (additionalSettings != "") {
    confirmMsg .= "`n" . SetUpDictionary.Confirm_AdditionalSettings . "`n" . additionalSettings
  }
  
   cardDetection := ""
   if (deleteMethod = "Inject Wonderpick 96P+") {
   if (FullArtCheck)
      cardDetection .= SetUpDictionary.Confirm_SingleFullArt . "`n"
   if (TrainerCheck)
      cardDetection .= SetUpDictionary.Confirm_SingleTrainer . "`n"
   if (RainbowCheck)
      cardDetection .= SetUpDictionary.Confirm_SingleRainbow . "`n"
   if (PseudoGodPack)
      cardDetection .= SetUpDictionary.Confirm_Double2Star . "`n"
   if (CrownCheck)
      cardDetection .= SetUpDictionary.Confirm_SaveCrowns . "`n"
   if (ShinyCheck)
      cardDetection .= SetUpDictionary.Confirm_SaveShiny . "`n"
   if (ImmersiveCheck)
      cardDetection .= SetUpDictionary.Confirm_SaveImmersives . "`n"
   if (CheckShinyPackOnly)
      cardDetection .= SetUpDictionary.Confirm_OnlyShinyPacks . "`n"
   if (InvalidCheck)
      cardDetection .= SetUpDictionary.Confirm_IgnoreInvalid . "`n"
      
   if (cardDetection != "") {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_CardDetection . "`n" . cardDetection
   }
   }
  
  if (s4tEnabled) {
    confirmMsg .= "`n" . SetUpDictionary.Confirm_SaveForTrade . ": " . SetUpDictionary.Confirm_Enabled . "`n"
    s4tSettings := ""
    if (s4t1Star)
      s4tSettings .= "• 1 Star`n"
    if (s4t3Dmnd)
      s4tSettings .= "• 3 Diamond`n"
    if (s4t4Dmnd)
      s4tSettings .= "• 4 Diamond`n"
    if (s4tShiny1Star)
      s4tSettings .= "• 1 Star Shiny`n"
   if (s4tShiny2Star)
      s4tSettings .= "• 2 Star Shiny`n"
   if (s4tTrainer)
      s4tSettings .= "• 2 Star Trainer`n"
   if (s4tRainbow)
      s4tSettings .= "• 2 Star Rainbow`n"
   if (s4tFullArt)
      s4tSettings .= "• 2 Star Full Art`n"
   if (s4tImmersive)
      s4tSettings .= "• Immersive`n"
   if (s4tCrown)
      s4tSettings .= "• Crown Rare`n"
    if (s4tWP)
      s4tSettings .= "• " . SetUpDictionary.Confirm_WonderPick . " (" . s4tWPMinCards . " " . SetUpDictionary.Confirm_MinCards . ")`n"
    ; if (s4tSilent)
      ; s4tSettings .= "• " . SetUpDictionary.Confirm_SilentPings . "`n"
    confirmMsg .= s4tSettings
  }
  
  if (s4tSendAccountXml && s4tEnabled) {
    confirmMsg .= "`n" . SetUpDictionary.Confirm_XMLWarning . "`n"
   }
  if (ocrShinedust && s4tEnabled) {
    confirmMsg .= "• Track Shinedust`n"
   }
  if (sendAccountXml) {
    confirmMsg .= "`n" . SetUpDictionary.Confirm_XMLWarning . "`n"
   }
  
  confirmMsg .= "`n" . SetUpDictionary.Confirm_StartBot
  
  MsgBox, 4, Confirm Bot Settings, %confirmMsg%
  IfMsgBox, No
    return
  
  Gui, Destroy
  
  StartBot()
return

LaunchAllMumu:
   Gui, Submit, NoHide
   SaveAllSettings()
   LoadSettingsFromIni()
   
   if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
      MsgBox, 0x40000,, ERROR: bot folder path is too long or contains blank spaces. Move to a shorter path without spaces such as C:\PTCGPB
      return
   }
   
   launchAllFile := A_ScriptDir . "\Scripts\Include\LaunchAllMumu.ahk"
   if(FileExist(launchAllFile)) {
      Run, %launchAllFile%

      totalInstances := Instances + (runMain ? Mains : 0)
      estimatedLaunchTime := (instanceLaunchDelay * totalInstances * 1000) + 500
      
      Sleep, %estimatedLaunchTime%
      
      Gosub, ArrangeWindows
   }
return

ArrangeWindows:
   Gui, Submit, NoHide
   SaveAllSettings()
   LoadSettingsFromIni()
   
   if (defaultLanguage = "Scale125") {
      scaleParam := 277
   } else if (defaultLanguage = "Scale100") {
      scaleParam := 287
   }
   
   windowsPositioned := 0
   
   if (runMain && Mains > 0) {
      Loop %Mains% {
         mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
         SetTitleMatchMode, 3
         if (WinExist(mainInstanceName)) {
            WinActivate, %mainInstanceName%
            WinGetPos, curX, curY, curW, curH, %mainInstanceName%
            
            SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
            SysGet, Monitor, Monitor, %SelectedMonitorIndex%
            
            instanceIndex := A_Index
            rowHeight := 533
            currentRow := Floor((instanceIndex - 1) / Columns)
            y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
            x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
            
            WinMove, %mainInstanceName%,, %x%, %y%, %scaleParam%, 537
            WinSet, Redraw, , %mainInstanceName%
            
            windowsPositioned++
            sleep, 100
         }
      }
   }
   
   if (Instances > 0) {
      Loop %Instances% {
         SetTitleMatchMode, 3
         windowTitle := A_Index
         
         if (WinExist(windowTitle)) {
            WinActivate, %windowTitle%
            WinGetPos, curX, curY, curW, curH, %windowTitle%
            
            SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
            SysGet, Monitor, Monitor, %SelectedMonitorIndex%
            
            if (runMain) {
               instanceIndex := (Mains - 1) + A_Index + 1
            } else {
               instanceIndex := A_Index
            }
            
            rowHeight := 533
            currentRow := Floor((instanceIndex - 1) / Columns)
            y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
            x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
            
            WinMove, %windowTitle%,, %x%, %y%, %scaleParam%, 537
            WinSet, Redraw, , %windowTitle%
            
            windowsPositioned++
            sleep, 100
         }
      }
   }
   
   if (debugMode && windowsPositioned == 0) {
      MsgBox, 0x40000,, No windows found to arrange
   }
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

OpenTradesDashboard:
   TradesFile := A_ScriptDir . "\Accounts\Trades\Trades_Dashboard.html"
   Run, %TradesFile%
return

RunXMLSortTool:
   Tool := A_ScriptDir . "\Accounts\xmlCounter.ahk"
   RunWait, %Tool%
Return

RunXMLDuplicateTool:
   Tool := A_ScriptDir . "\Accounts\xml_duplicate_finder.ahk"
   RunWait, %Tool%
Return

GuiClose:
   Gui, Submit, NoHide
   SaveAllSettings()
   
   KillAllScripts()

ExitApp
return

BalanceXMLs:
   Gui, Submit, NoHide
   SaveAllSettings()
   LoadSettingsFromIni()
   
   if(Instances>0) {
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
         dest := tmpDir . "\" . A_LoopFileName
         FileMove, %A_LoopFilePath%, %dest%, 1
      }
      Loop , %Instances%
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

         ; Below version is to sort by pack count instead (evenly distribute higher pack counts amongst instances)
         RegExMatch(fileName, "(\d+)P_", packMatch)
         packCount := packMatch1 ? packMatch1 : 0

         seenFiles[fileName] := {Time: fileTime, Path: filePath}
         fileList .= packCount "`t" filePath "`n"
      }
      
      ToolTip, Sorting by pack count
      Sort, fileList, R
      
      ToolTip, Distributing XMLs between folders...please wait
      instance := 1
      Loop, Parse, fileList, `n
      {
         if (A_LoopField = "")
            continue
         
         StringSplit, parts, A_LoopField, %A_Tab%
         tmpFile := parts2
         toDir := saveDir . "\" . instance
         
         FileMove, %tmpFile%, %toDir%, 1
         
         instance++
         if (instance > Instances)
            instance := 1
      }
      
      instanceOneDir := saveDir . "1"
      counter := 0
      counter2 := 0
      Loop, Files, %instanceOneDir%\*.xml
      {
         fileModifiedTimeDiff := A_Now
         FileGetTime, fileModifiedTime, %A_LoopFileFullPath%, M
         EnvSub, fileModifiedTimeDiff, %fileModifiedTime%, Hours
         if (fileModifiedTimeDiff >= 24)
            counter++
      }
      
      Tooltip
      MsgBox, 0x40000,XML Balance,Done balancing XMLs between %Instances% instances`n%counter% XMLs past 24 hours per instance
   }
return

CheckForUpdates:
   CheckForUpdate()
return

IsNumeric(var) {
   if var is number
      return true
   return false
}

MigrateDeleteMethod(oldMethod) {
    if (oldMethod = "13 Pack") {
        return "Create Bots (13P)"
    } else if (oldMethod = "Inject") {
        return "Inject 13P+"
    } else if (oldMethod = "Inject for Reroll") {
        return "Inject Wonderpick 96P+"
    } else if (oldMethod = "Inject Missions") {
        return "Inject 13P+"
    } else if (oldMethod = "Inject 13-39P") {
        return "Inject 13P+"
    } else if (oldMethod = "Inject Wonderpick 39P+") {
        return "Inject Wonderpick 96P+"
    }
    return oldMethod
}

LoadSettingsFromIni() {
   global
   if (FileExist("Settings.ini")) {
      IniRead, IsLanguageSet, Settings.ini, UserSettings, IsLanguageSet, 1
      IniRead, defaultBotLanguage, Settings.ini, UserSettings, defaultBotLanguage, 1
      IniRead, BotLanguage, Settings.ini, UserSettings, BotLanguage, English
      
      IniRead, shownLicense, Settings.ini, UserSettings, shownLicense, 0
      IniRead, currentfont, Settings.ini, UserSettings, currentfont, segoe UI
      IniRead, FontColor, Settings.ini, UserSettings, FontColor, FDFDFD
      IniRead, CurrentTheme, Settings.ini, UserSettings, CurrentTheme, Dark
      
      IniRead, FriendID, Settings.ini, UserSettings, FriendID, ""
      IniRead, Instances, Settings.ini, UserSettings, Instances, 1
      IniRead, instanceStartDelay, Settings.ini, UserSettings, instanceStartDelay, 10
      IniRead, Columns, Settings.ini, UserSettings, Columns, 5
      IniRead, runMain, Settings.ini, UserSettings, runMain, 1
      IniRead, Mains, Settings.ini, UserSettings, Mains, 1
      IniRead, AccountName, Settings.ini, UserSettings, AccountName, ""
      IniRead, autoLaunchMonitor, Settings.ini, UserSettings, autoLaunchMonitor, 1
      IniRead, TestTime, Settings.ini, UserSettings, TestTime, 3600
      IniRead, Delay, Settings.ini, UserSettings, Delay, 250
      IniRead, waitTime, Settings.ini, UserSettings, waitTime, 5
      IniRead, swipeSpeed, Settings.ini, UserSettings, swipeSpeed, 500
      IniRead, slowMotion, Settings.ini, UserSettings, slowMotion, 1 ; default is now OFF for no-mod-menu support
      
      IniRead, SelectedMonitorIndex, Settings.ini, UserSettings, SelectedMonitorIndex, 1
      IniRead, defaultLanguage, Settings.ini, UserSettings, defaultLanguage, Scale125
      IniRead, rowGap, Settings.ini, UserSettings, rowGap, 90
      IniRead, folderPath, Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
      IniRead, ocrLanguage, Settings.ini, UserSettings, ocrLanguage, en
      IniRead, clientLanguage, Settings.ini, UserSettings, clientLanguage, en
      IniRead, instanceLaunchDelay, Settings.ini, UserSettings, instanceLaunchDelay, 2
      
      IniRead, tesseractPath, Settings.ini, UserSettings, tesseractPath, C:\Program Files\Tesseract-OCR\tesseract.exe
      IniRead, debugMode, Settings.ini, UserSettings, debugMode, 0
      IniRead, useTesseract, Settings.ini, UserSettings, tesseractOption, 0
      IniRead, statusMessage, Settings.ini, UserSettings, statusMessage, 1
      
      IniRead, minStars, Settings.ini, UserSettings, minStars, 0
      IniRead, minStarsShiny, Settings.ini, UserSettings, minStarsShiny, 0
      IniRead, minStarsEnabled, Settings.ini, UserSettings, minStarsEnabled, 0
      IniRead, deleteMethod, Settings.ini, UserSettings, deleteMethod, Create Bots (13P)
        originalDeleteMethod := deleteMethod
        deleteMethod := MigrateDeleteMethod(deleteMethod)
        if (deleteMethod != originalDeleteMethod) {
            IniWrite, %deleteMethod%, Settings.ini, UserSettings, deleteMethod
        }
      IniRead, packMethod, Settings.ini, UserSettings, packMethod, 0
      IniRead, nukeAccount, Settings.ini, UserSettings, nukeAccount, 0
      nukeAccount := 0 ; forced to always be disabled
      IniRead, spendHourGlass, Settings.ini, UserSettings, spendHourGlass, 0
      IniRead, openExtraPack, Settings.ini, UserSettings, openExtraPack, 0
      IniRead, injectSortMethod, Settings.ini, UserSettings, injectSortMethod, PacksDesc
      IniRead, godPack, Settings.ini, UserSettings, godPack, Continue
      IniRead, claimSpecialMissions, Settings.ini, UserSettings, claimSpecialMissions, 0
      IniRead, claimDailyMission, Settings.ini, UserSettings, claimDailyMission, 0
      IniRead, wonderpickForEventMissions, Settings.ini, UserSettings, wonderpickForEventMissions, 0
      ; wonderpickForEventMissions := 0 ; forced turned off during Sneak Peek for now...
      IniRead, checkWPthanks, Settings.ini, UserSettings, checkWPthanks, 0
      
      IniRead, Palkia, Settings.ini, UserSettings, Palkia, 0
      IniRead, Dialga, Settings.ini, UserSettings, Dialga, 0
      IniRead, Arceus, Settings.ini, UserSettings, Arceus, 0
      IniRead, Shining, Settings.ini, UserSettings, Shining, 0
      IniRead, Mew, Settings.ini, UserSettings, Mew, 0
      IniRead, Pikachu, Settings.ini, UserSettings, Pikachu, 0
      IniRead, Charizard, Settings.ini, UserSettings, Charizard, 0
      IniRead, Mewtwo, Settings.ini, UserSettings, Mewtwo, 0
      IniRead, Solgaleo, Settings.ini, UserSettings, Solgaleo, 0
      IniRead, Lunala, Settings.ini, UserSettings, Lunala, 0
      IniRead, Buzzwole, Settings.ini, UserSettings, Buzzwole, 0
      IniRead, Eevee, Settings.ini, UserSettings, Eevee, 0
      IniRead, HoOh, Settings.ini, UserSettings, HoOh, 0
      IniRead, Lugia, Settings.ini, UserSettings, Lugia, 0
      IniRead, Springs, Settings.ini, UserSettings, Springs, 0
      IniRead, Deluxe, Settings.ini, UserSettings, Deluxe, 0
      IniRead, MegaGyarados, Settings.ini, UserSettings, MegaGyarados, 1
      IniRead, MegaBlaziken, Settings.ini, UserSettings, MegaBlaziken, 0
      IniRead, MegaAltaria, Settings.ini, UserSettings, MegaAltaria, 0
      
      IniRead, CheckShinyPackOnly, Settings.ini, UserSettings, CheckShinyPackOnly, 0
      IniRead, TrainerCheck, Settings.ini, UserSettings, TrainerCheck, 0
      IniRead, FullArtCheck, Settings.ini, UserSettings, FullArtCheck, 0
      IniRead, RainbowCheck, Settings.ini, UserSettings, RainbowCheck, 0
      IniRead, ShinyCheck, Settings.ini, UserSettings, ShinyCheck, 0
      IniRead, CrownCheck, Settings.ini, UserSettings, CrownCheck, 0
      IniRead, ImmersiveCheck, Settings.ini, UserSettings, ImmersiveCheck, 0
      IniRead, InvalidCheck, Settings.ini, UserSettings, InvalidCheck, 0
      IniRead, PseudoGodPack, Settings.ini, UserSettings, PseudoGodPack, 0
      
      IniRead, s4tEnabled, Settings.ini, UserSettings, s4tEnabled, 0
      IniRead, s4tSilent, Settings.ini, UserSettings, s4tSilent, 0
        s4tSilent := 0 ; always disable, removing feature for now. -Kevin
      IniRead, s4t3Dmnd, Settings.ini, UserSettings, s4t3Dmnd, 0
      IniRead, s4t4Dmnd, Settings.ini, UserSettings, s4t4Dmnd, 0
      IniRead, s4t1Star, Settings.ini, UserSettings, s4t1Star, 0
      IniRead, s4tGholdengo, Settings.ini, UserSettings, s4tGholdengo, 0
      IniRead, s4tTrainer, Settings.ini, UserSettings, s4tTrainer, 0
      IniRead, s4tRainbow, Settings.ini, UserSettings, s4tRainbow, 0
      IniRead, s4tFullArt, Settings.ini, UserSettings, s4tFullArt, 0
      IniRead, s4tCrown, Settings.ini, UserSettings, s4tCrown, 0
      IniRead, s4tImmersive, Settings.ini, UserSettings, s4tImmersive, 0
      IniRead, s4tShiny1Star, Settings.ini, UserSettings, s4tShiny1Star, 0
      IniRead, s4tShiny2Star, Settings.ini, UserSettings, s4tShiny2Star, 0
      IniRead, s4tWP, Settings.ini, UserSettings, s4tWP, 0
      IniRead, s4tWPMinCards, Settings.ini, UserSettings, s4tWPMinCards, 1
      IniRead, s4tDiscordWebhookURL, Settings.ini, UserSettings, s4tDiscordWebhookURL, ""
      IniRead, s4tDiscordUserId, Settings.ini, UserSettings, s4tDiscordUserId, ""
      IniRead, s4tSendAccountXml, Settings.ini, UserSettings, s4tSendAccountXml, 0
      IniRead, ocrShinedust, Settings.ini, UserSettings, ocrShinedust, 0
      
      IniRead, DiscordWebhookURL, Settings.ini, UserSettings, DiscordWebhookURL, ""
      IniRead, DiscordUserId, Settings.ini, UserSettings, DiscordUserId, ""
      IniRead, heartBeat, Settings.ini, UserSettings, heartBeat, 0
      IniRead, heartBeatWebhookURL, Settings.ini, UserSettings, heartBeatWebhookURL, ""
      IniRead, heartBeatName, Settings.ini, UserSettings, heartBeatName, ""
      IniRead, heartBeatDelay, Settings.ini, UserSettings, heartBeatDelay, 30
      IniRead, sendAccountXml, Settings.ini, UserSettings, sendAccountXml, 0
      
      IniRead, groupRerollEnabled, Settings.ini, UserSettings, groupRerollEnabled, 0
      IniRead, mainIdsURL, Settings.ini, UserSettings, mainIdsURL, ""
      IniRead, vipIdsURL, Settings.ini, UserSettings, vipIdsURL, ""
      IniRead, showcaseEnabled, Settings.ini, UserSettings, showcaseEnabled, 0
      IniRead, showcaseLikes, Settings.ini, UserSettings, showcaseLikes, 5
      IniRead, autoUseGPTest, Settings.ini, UserSettings, autoUseGPTest, 0
      IniRead, applyRoleFilters, Settings.ini, UserSettings, applyRoleFilters, 0

      IniRead, minStarsA1Charizard, Settings.ini, UserSettings, minStarsA1Charizard, 0
      IniRead, minStarsA1Mewtwo, Settings.ini, UserSettings, minStarsA1Mewtwo, 0
      IniRead, minStarsA1Pikachu, Settings.ini, UserSettings, minStarsA1Pikachu, 0
      IniRead, minStarsA1a, Settings.ini, UserSettings, minStarsA1a, 0
      IniRead, minStarsA2Dialga, Settings.ini, UserSettings, minStarsA2Dialga, 0
      IniRead, minStarsA2Palkia, Settings.ini, UserSettings, minStarsA2Palkia, 0
      IniRead, minStarsA2a, Settings.ini, UserSettings, minStarsA2a, 0
      IniRead, minStarsA3Solgaleo, Settings.ini, UserSettings, minStarsA3Solgaleo, 0
      IniRead, minStarsA3Lunala, Settings.ini, UserSettings, minStarsA3Lunala, 0
      IniRead, minStarsA3a, Settings.ini, UserSettings, minStarsA3a, 0
      IniRead, minStarsA3b, Settings.ini, UserSettings, minStarsA3b, 0
      IniRead, minStarsA4HoOh, Settings.ini, UserSettings, minStarsA4HoOh, 0
      IniRead, minStarsA4Lugia, Settings.ini, UserSettings, minStarsA4Lugia, 0
      IniRead, minStarsA4Springs, Settings.ini, UserSettings, minStarsA4Springs, 0
      IniRead, minStarsA4Deluxe, Settings.ini, UserSettings, minStarsA4Deluxe, 0
      IniRead, minStarsMegaGyarados, Settings.ini, UserSettings, minStarsMegaGyarados, 0
      IniRead, minStarsMegaBlaziken, Settings.ini, UserSettings, minStarsMegaBlaziken, 0
      IniRead, minStarsMegaAltaria, Settings.ini, UserSettings, minStarsMegaAltaria, 0
      
      IniRead, waitForEligibleAccounts, Settings.ini, UserSettings, waitForEligibleAccounts, 1
      IniRead, maxWaitHours, Settings.ini, UserSettings, maxWaitHours, 24
      IniRead, menuExpanded, Settings.ini, UserSettings, menuExpanded, True
      
      if (!IsNumeric(Instances))
         Instances := 1
      if (!IsNumeric(Columns) || Columns < 1)
         Columns := 5
      if (!IsNumeric(waitTime))
         waitTime := 5
      if (!IsNumeric(Delay) || Delay < 10)
         Delay := 250
      if (s4tWPMinCards < 1 || s4tWPMinCards > 2)
         s4tWPMinCards := 1
         
      validMethods := "Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+"
      if (!InStr(validMethods, deleteMethod)) {
         deleteMethod := "Create Bots (13P)"
         IniWrite, %deleteMethod%, Settings.ini, UserSettings, deleteMethod
      }

      ; clear card detection when not wonderpicking
      if (deleteMethod != "Inject Wonderpick 96P+") {
         FullArtCheck := 0
         TrainerCheck := 0
         RainbowCheck := 0
         PseudoGodPack := 0
         CheckShinyPackOnly := 0
         InvalidCheck := 0
         CrownCheck := 0
         ShinyCheck := 0
         ImmersiveCheck := 0
         minStars := 0
         minStarsShiny := 0
      }

      return true
   } else {
      return false
   }
}

CreateDefaultSettingsFile() {
   if (!FileExist("Settings.ini")) {
      iniContent := "[UserSettings]`n"
      iniContent .= "IsLanguageSet=0`n"
      iniContent .= "defaultBotLanguage=1`n"
      iniContent .= "BotLanguage=English`n"
      iniContent .= "shownLicense=0`n"
      iniContent .= "currentfont=Segoe UI`n"
      iniContent .= "FontColor=FDFDFD`n"
      iniContent .= "CurrentTheme=Dark`n"
      iniContent .= "FriendID=`n"
      iniContent .= "AccountName=`n"
      iniContent .= "waitTime=5`n"
      iniContent .= "Delay=250`n"
      iniContent .= "folderPath=C:\Program Files\Netease`n"
      iniContent .= "Columns=5`n"
      iniContent .= "godPack=Continue`n"
      iniContent .= "Instances=1`n"
      iniContent .= "instanceStartDelay=10`n"
      iniContent .= "defaultLanguage=Scale125`n"
      iniContent .= "SelectedMonitorIndex=1`n"
      iniContent .= "swipeSpeed=500`n"
      iniContent .= "runMain=0`n"
      iniContent .= "Mains=0`n"
      iniContent .= "autoUseGPTest=0`n"
      iniContent .= "TestTime=3600`n"
      iniContent .= "heartBeat=0`n"
      iniContent .= "heartBeatWebhookURL=`n"
      iniContent .= "heartBeatName=`n"
      iniContent .= "heartBeatDelay=30`n"
      iniContent .= "tesseractPath=C:\Program Files\Tesseract-OCR\tesseract.exe`n"
      iniContent .= "applyRoleFilters=0`n"
      iniContent .= "debugMode=0`n"
      iniContent .= "tesseractOption=0`n"
      iniContent .= "statusMessage=1`n"
      iniContent .= "minStarsEnabled=0`n"
      iniContent .= "showcaseEnabled=0`n"
      iniContent .= "showcaseLikes=5`n"
      iniContent .= "rowGap=90`n"
      iniContent .= "variablePackCount=15`n"
      iniContent .= "claimSpecialMissions=0`n"
      iniContent .= "spendHourGlass=0`n"
      iniContent .= "injectSortMethod=PacksDesc`n"
      iniContent .= "waitForEligibleAccounts=1`n"
      iniContent .= "maxWaitHours=24`n"
      iniContent .= "menuExpanded=True`n"
      iniContent .= "groupRerollEnabled=0`n"
      iniContent .= "checkWPthanks=0`n"
      
      FileAppend, %iniContent%, Settings.ini, UTF-16
      return true
   }
   return false
}


SaveAllSettings() {
   global IsLanguageSet, defaultBotLanguage, BotLanguage, currentfont, FontColor
   global CurrentTheme, shownLicense
   global FriendID, AccountName, waitTime, Delay, folderPath, discordWebhookURL, discordUserId, Columns, godPack
   global Instances, instanceStartDelay, defaultLanguage, SelectedMonitorIndex, swipeSpeed, deleteMethod
   global runMain, Mains, heartBeat, heartBeatWebhookURL, heartBeatName, nukeAccount, packMethod
   global autoLaunchMonitor, autoUseGPTest, TestTime, groupRerollEnabled
   global CheckShinyPackOnly, TrainerCheck, FullArtCheck, RainbowCheck, ShinyCheck, CrownCheck
   global InvalidCheck, ImmersiveCheck, PseudoGodPack, minStars, Palkia, Dialga, Arceus, Shining
   global Mew, Pikachu, Charizard, Mewtwo, Solgaleo, Lunala, Buzzwole, Eevee, HoOh, Lugia, Springs, Deluxe
   global MegaGyarados, MegaBlaziken, MegaAltaria, slowMotion, ocrLanguage, clientLanguage
   global CurrentVisibleSection, heartBeatDelay, sendAccountXml, showcaseEnabled, isDarkTheme
   global useBackgroundImage, tesseractPath, debugMode, useTesseract, statusMessage
   global s4tEnabled, s4tSilent, s4t3Dmnd, s4t4Dmnd, s4t1Star, s4tGholdengo, s4tWP, s4tWPMinCards
   global s4tDiscordUserId, s4tDiscordWebhookURL, s4tSendAccountXml, ocrShinedust, minStarsShiny, instanceLaunchDelay, applyRoleFilters, mainIdsURL, vipIdsURL
   global s4tCrown, s4tImmersive, s4tShiny1Star, s4tShiny2Star, s4tTrainer, s4tRainbow, s4tFullArt
   global spendHourGlass, openExtraPack, injectSortMethod, rowGap, SortByDropdown
   global waitForEligibleAccounts, maxWaitHours, skipMissionsInjectMissions
   global minStarsEnabled, minStarsA1Mewtwo, minStarsA1Charizard, minStarsA1Pikachu, minStarsA1a
   global minStarsA2Dialga, minStarsA2Palkia, minStarsA2a, minStarsA2b
   global minStarsA3Solgaleo, minStarsA3Lunala, minStarsA3a, minStarsA3b
   global minStarsA4HoOh, minStarsA4Lugia, minStarsA4Springs, minStarsA4Deluxe
   global minStarsMegaGyarados, minStarsMegaBlaziken, minStarsMegaAltaria
   global menuExpanded
   global claimSpecialMissions, claimDailyMission, wonderpickForEventMissions
   global checkWPthanks

   if (deleteMethod != "Inject Wonderpick 96P+") {
       packMethod := false
       ; Clear card detection settings
       FullArtCheck := 0
       TrainerCheck := 0
       RainbowCheck := 0
       PseudoGodPack := 0
       CheckShinyPackOnly := 0
       InvalidCheck := 0
       CrownCheck := 0
       ShinyCheck := 0
       ImmersiveCheck := 0
       minStars := 0
       minStarsShiny := 0
   }
   
   iniContent := "[UserSettings]`n"
   iniContent .= "isLanguageSet=" IsLanguageSet "`n"
   iniContent .= "defaultBotLanguage=" defaultBotLanguage "`n"
   iniContent .= "BotLanguage=" BotLanguage "`n"
   iniContent .= "shownLicense=" shownLicense "`n"
   iniContent .= "CurrentTheme=" CurrentTheme "`n"
   iniContent .= "FontColor=" FontColor "`n"
   iniContent .= "currentfont=" currentfont "`n"
   
   iniContent .= "runMain=" runMain "`n"
   iniContent .= "autoUseGPTest=" autoUseGPTest "`n"
   iniContent .= "slowMotion=" slowMotion "`n"
   iniContent .= "autoLaunchMonitor=" autoLaunchMonitor "`n"
   iniContent .= "applyRoleFilters=" applyRoleFilters "`n"
   iniContent .= "debugMode=" debugMode "`n"
   iniContent .= "tesseractOption=" useTesseract "`n"
   iniContent .= "statusMessage=" statusMessage "`n"
   iniContent .= "minStarsEnabled=" minStarsEnabled "`n"
   iniContent .= "nukeAccount=" nukeAccount "`n"
   iniContent .= "packMethod=" packMethod "`n"
   iniContent .= "spendHourGlass=" spendHourGlass "`n"
   iniContent .= "openExtraPack=" openExtraPack "`n"
   iniContent .= "Palkia=" Palkia "`n"
   iniContent .= "Dialga=" Dialga "`n"
   iniContent .= "Arceus=" Arceus "`n"
   iniContent .= "Shining=" Shining "`n"
   iniContent .= "Mew=" Mew "`n"
   iniContent .= "Pikachu=" Pikachu "`n"
   iniContent .= "Charizard=" Charizard "`n"
   iniContent .= "Mewtwo=" Mewtwo "`n"
   iniContent .= "Solgaleo=" Solgaleo "`n"
   iniContent .= "Lunala=" Lunala "`n"
   iniContent .= "Buzzwole=" Buzzwole "`n"
   iniContent .= "Eevee=" Eevee "`n"
   iniContent .= "HoOh=" HoOh "`n"
   iniContent .= "Lugia=" Lugia "`n"
   iniContent .= "Springs=" Springs "`n"
   iniContent .= "Deluxe=" Deluxe "`n"
   iniContent .= "MegaGyarados=" MegaGyarados "`n"
   iniContent .= "MegaBlaziken=" MegaBlaziken "`n"
   iniContent .= "MegaAltaria=" MegaAltaria "`n"
   iniContent .= "CheckShinyPackOnly=" CheckShinyPackOnly "`n"
   iniContent .= "TrainerCheck=" TrainerCheck "`n"
   iniContent .= "FullArtCheck=" FullArtCheck "`n"
   iniContent .= "RainbowCheck=" RainbowCheck "`n"
   iniContent .= "ShinyCheck=" ShinyCheck "`n"
   iniContent .= "CrownCheck=" CrownCheck "`n"
   iniContent .= "InvalidCheck=" InvalidCheck "`n"
   iniContent .= "ImmersiveCheck=" ImmersiveCheck "`n"
   iniContent .= "PseudoGodPack=" PseudoGodPack "`n"
   iniContent .= "s4tEnabled=" s4tEnabled "`n"
   iniContent .= "s4tSilent=" s4tSilent "`n"
   iniContent .= "s4t3Dmnd=" s4t3Dmnd "`n"
   iniContent .= "s4t4Dmnd=" s4t4Dmnd "`n"
   iniContent .= "s4t1Star=" s4t1Star "`n"
   iniContent .= "s4tGholdengo=" s4tGholdengo "`n"
   iniContent .= "s4tTrainer=" s4tTrainer "`n"
   iniContent .= "s4tRainbow=" s4tRainbow "`n"
   iniContent .= "s4tFullArt=" s4tFullArt "`n"
   iniContent .= "s4tCrown=" s4tCrown "`n"
   iniContent .= "s4tImmersive=" s4tImmersive "`n"
   iniContent .= "s4tShiny1Star=" s4tShiny1Star "`n"
   iniContent .= "s4tShiny2Star=" s4tShiny2Star "`n"
   iniContent .= "s4tWP=" s4tWP "`n"
   iniContent .= "s4tSendAccountXml=" s4tSendAccountXml "`n"
   iniContent .= "ocrShinedust=" ocrShinedust "`n"
   iniContent .= "sendAccountXml=" sendAccountXml "`n"
   iniContent .= "heartBeat=" heartBeat "`n"
   iniContent .= "menuExpanded=" menuExpanded "`n"
   iniContent .= "groupRerollEnabled=" groupRerollEnabled "`n"
   iniContent .= "claimSpecialMissions=" claimSpecialMissions "`n"
   iniContent .= "claimDailyMission=" claimDailyMission "`n"
   iniContent .= "wonderpickForEventMissions=" wonderpickForEventMissions "`n"
   iniContent .= "checkWPthanks=" checkWPthanks "`n"

   originalDeleteMethod := deleteMethod
   deleteMethod := MigrateDeleteMethod(deleteMethod)
   if (deleteMethod = "" || deleteMethod = "ERROR") {
      deleteMethod := "Create Bots (13P)"
   }
   validMethods := "Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+"
   if (!InStr(validMethods, deleteMethod)) {
      deleteMethod := "Create Bots (13P)"
   }

   if (!groupRerollEnabled) {
   mainIdsURL := ""
   vipIdsURL := ""
   autoUseGPTest := 0
   TestTime := 3600
   applyRoleFilters := 0
   }
   
   if (SortByDropdown = "Oldest First")
      injectSortMethod := "ModifiedAsc"
   else if (SortByDropdown = "Newest First")
      injectSortMethod := "ModifiedDesc"
   else if (SortByDropdown = "Fewest Packs First")
      injectSortMethod := "PacksAsc"
   else if (SortByDropdown = "Most Packs First")
      injectSortMethod := "PacksDesc"
   iniContent_Second := "deleteMethod=" deleteMethod "`n"
   if (deleteMethod = "Inject Wonderpick 96P+") {
      iniContent_Second .= "FriendID=" FriendID "`n"
      iniContent_Second .= "mainIdsURL=" mainIdsURL "`n"
   } else {
      iniContent_Second .= "FriendID=`n"
      iniContent_Second .= "mainIdsURL=`n"
      mainIdsURL := ""
      FriendID := ""
   }
   
   iniContent_Second .= "AccountName=" AccountName "`n"
   iniContent_Second .= "waitTime=" waitTime "`n"
   iniContent_Second .= "Delay=" Delay "`n"
   iniContent_Second .= "folderPath=" folderPath "`n"
   iniContent_Second .= "discordWebhookURL=" discordWebhookURL "`n"
   iniContent_Second .= "discordUserId=" discordUserId "`n"
   iniContent_Second .= "Columns=" Columns "`n"
   iniContent_Second .= "godPack=" godPack "`n"
   iniContent_Second .= "Instances=" Instances "`n"
   iniContent_Second .= "instanceStartDelay=" instanceStartDelay "`n"
   iniContent_Second .= "defaultLanguage=" defaultLanguage "`n"
   iniContent_Second .= "rowGap=" rowGap "`n"
   iniContent_Second .= "SelectedMonitorIndex=" SelectedMonitorIndex "`n"
   iniContent_Second .= "swipeSpeed=" swipeSpeed "`n"
   iniContent_Second .= "Mains=" Mains "`n"
   iniContent_Second .= "TestTime=" TestTime "`n"
   iniContent_Second .= "heartBeatWebhookURL=" heartBeatWebhookURL "`n"
   iniContent_Second .= "heartBeatName=" heartBeatName "`n"
   iniContent_Second .= "heartBeatDelay=" heartBeatDelay "`n"
   iniContent_Second .= "minStars=" minStars "`n"
   iniContent_Second .= "ocrLanguage=" ocrLanguage "`n"
   iniContent_Second .= "clientLanguage=" clientLanguage "`n"
   iniContent_Second .= "vipIdsURL=" vipIdsURL "`n"
   iniContent_Second .= "instanceLaunchDelay=" instanceLaunchDelay "`n"
   iniContent_Second .= "injectSortMethod=" injectSortMethod "`n"
   iniContent_Second .= "waitForEligibleAccounts=" waitForEligibleAccounts "`n"
   iniContent_Second .= "maxWaitHours=" maxWaitHours "`n"
   iniContent_Second .= "skipMissionsInjectMissions=" skipMissionsInjectMissions "`n"
   iniContent_Second .= "showcaseEnabled=" showcaseEnabled "`n"
   iniContent_Second .= "showcaseLikes=5`n"
   iniContent_Second .= "minStarsA1Mewtwo=" minStarsA1Mewtwo "`n"
   iniContent_Second .= "minStarsA1Charizard=" minStarsA1Charizard "`n"
   iniContent_Second .= "minStarsA1Pikachu=" minStarsA1Pikachu "`n"
   iniContent_Second .= "minStarsA1a=" minStarsA1a "`n"
   iniContent_Second .= "minStarsA2Dialga=" minStarsA2Dialga "`n"
   iniContent_Second .= "minStarsA2Palkia=" minStarsA2Palkia "`n"
   iniContent_Second .= "minStarsA2a=" minStarsA2a "`n"
   iniContent_Second .= "minStarsA2b=" minStarsA2b "`n"
   iniContent_Second .= "minStarsA3Solgaleo=" minStarsA3Solgaleo "`n"
   iniContent_Second .= "minStarsA3Lunala=" minStarsA3Lunala "`n"
   iniContent_Second .= "minStarsA3a=" minStarsA3a "`n"
   iniContent_Second .= "minStarsA3b=" minStarsA3b "`n"
   iniContent_Second .= "minStarsA4HoOh=" minStarsA4HoOh "`n"
   iniContent_Second .= "minStarsA4Lugia=" minStarsA4Lugia "`n"
   iniContent_Second .= "minStarsA4Springs=" minStarsA4Springs "`n"
   iniContent_Second .= "minStarsA4Deluxe=" minStarsA4Deluxe "`n"
   iniContent_Second .= "minStarsMegaGyarados=" minStarsMegaGyarados "`n"
   iniContent_Second .= "minStarsMegaBlaziken=" minStarsMegaBlaziken "`n"
   iniContent_Second .= "minStarsMegaMegaAltaria=" minStarsMegaAltaria "`n"
   iniContent_Second .= "s4tWPMinCards=" s4tWPMinCards "`n"
   iniContent_Second .= "s4tDiscordUserId=" s4tDiscordUserId "`n"
   iniContent_Second .= "s4tDiscordWebhookURL=" s4tDiscordWebhookURL "`n"
   iniContent_Second .= "minStarsShiny=" minStarsShiny "`n"
   iniContent_Second .= "tesseractPath=" tesseractPath "`n"
   
   iniFull := iniContent . iniContent_Second
   FileDelete, Settings.ini
   FileAppend, %iniFull%, Settings.ini, UTF-16
   
   if (debugMode) {
      FileAppend, % A_Now . " - Settings saved. DeleteMethod: " . deleteMethod . "`n", %A_ScriptDir%\debug_settings.log
   }
}

ResetAccountLists() {
   resetListsPath := A_ScriptDir . "\Scripts\Include\ResetLists.ahk"
   
   if (FileExist(resetListsPath)) {
      Run, %resetListsPath%,, Hide UseErrorLevel
      
      Sleep, 50
      
      LogToFile("Account lists reset via ResetLists.ahk. New lists will be generated on next injection.")
      
      CreateStatusMessage("Account lists reset. New lists will use current method settings.",,,, false)
   } else {
      LogToFile("ERROR: ResetLists.ahk not found at: " . resetListsPath)
      
      if (debugMode) {
         MsgBox, 0x40000, Reset list issue, ResetLists.ahk not found at:`n%resetListsPath%
      }
   }
}

StartBot() {
   global runMain, Mains, Instances, deleteMethod, instanceStartDelay, autoLaunchMonitor
   global mainIdsURL, showcaseEnabled, defaultLanguage, scaleParam, FriendID
   global heartBeat, heartBeatName, heartBeatWebhookURL, heartBeatDelay, debugMode
   global Shining, Arceus, Palkia, Dialga, Mew, Pikachu, Charizard, Mewtwo
   global Solgaleo, Lunala, Buzzwole, Eevee, HoOh, Lugia, Springs, Deluxe
   global MegaBlaziken, MegaGyarados, MegaAltaria, packMethod, nukeAccount
   global SelectedMonitorIndex, localVersion, githubUser, rerollTime, PackGuiBuild
   
   PackGuiBuild := 0
   rerollTime := A_TickCount
   
   SaveAllSettings()
   LoadSettingsFromIni()
   
   if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
      MsgBox, 0x40000,, ERROR: bot folder path is too long or contains blank spaces. Move to a shorter path without spaces such as C:\PTCGPB
      return
   }
   
   ResetAccountLists()
   
   if (inStr(FriendID, "http")) {
      MsgBox,To provide a URL for friend IDs, please use the ids.txt API field and leave the Friend ID field empty.
      
      if (mainIdsURL = "") {
         IniWrite, "", Settings.ini, UserSettings, FriendID
         IniWrite, %FriendID%, Settings.ini, UserSettings, mainIdsURL
      }
      
      Reload
   }
   
   if (mainIdsURL != "") {
      DownloadFile(mainIdsURL, "ids.txt")
   }
   
   if (showcaseEnabled) {
      if (!FileExist("showcase_ids.txt")) {
         MsgBox, 48, Showcase Warning, Showcase is enabled but showcase_ids.txt does not exist.`nPlease create this file in the same directory as the script.
      }
   }
   
   if (defaultLanguage = "Scale125") {
      scaleParam := 277
   } else if (defaultLanguage = "Scale100") {
      scaleParam := 287
   }
   
   if (runMain) {
      Loop, %Mains%
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
         
         if (A_Index > 1 && instanceStartDelay > 0) {
            instanceStartDelayMS := instanceStartDelay * 1000
            Sleep, instanceStartDelayMS
         }
         
         Run, %Command%
      }
   }
   
   Loop, %Instances%
   {
      if (A_Index != 1) {
         SourceFile := "Scripts\1.ahk"
         TargetFolder := "Scripts\"
         TargetFile := TargetFolder . A_Index . ".ahk"
         if(Instances > 1) {
            FileDelete, %TargetFile%
            FileCopy, %SourceFile%, %TargetFile%, 1
         }
         if (ErrorLevel)
            MsgBox, Failed to create %TargetFile%. Ensure permissions and paths are correct.
      }
      
      FileName := "Scripts\" . A_Index . ".ahk"
      Command := FileName
      
      if ((Mains > 1 || A_Index > 1) && instanceStartDelay > 0) {
         instanceStartDelayMS := instanceStartDelay * 1000
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
   
   if(autoLaunchMonitor) {
      monitorFile := A_ScriptDir . "\Scripts\Include\Monitor.ahk"
      if(FileExist(monitorFile)) {
         Run, %monitorFile%
      }
   }
   
   SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
   SysGet, Monitor, Monitor, %SelectedMonitorIndex%
   rerollTime := A_TickCount
   
   typeMsg := "\nType: " . deleteMethod
   injectMethod := false
   if(InStr(deleteMethod, "Inject"))
      injectMethod := true
   if(packMethod)
      typeMsg .= " (1P Method)"
   if(nukeAccount && !injectMethod)
      typeMsg .= " (Menu Delete)"
   
   Selected := []
   selectMsg := "\nOpening: "
   if(Shining)
      Selected.Push("Shining")
   if(Arceus)
      Selected.Push("Arceus")
   if(Palkia)
      Selected.Push("Palkia")
   if(Dialga)
      Selected.Push("Dialga")
   if(Mew)
      Selected.Push("Mew")
   if(Pikachu)
      Selected.Push("Pikachu")
   if(Charizard)
      Selected.Push("Charizard")
   if(Mewtwo)
      Selected.Push("Mewtwo")
   if(Solgaleo)
      Selected.Push("Solgaleo")
   if(Lunala)
      Selected.Push("Lunala")
   if(Buzzwole)
      Selected.Push("Buzzwole")
   if(Eevee)
      Selected.Push("Eevee")
   if(HoOh)
      Selected.Push("HoOh")
   if(Lugia)
      Selected.Push("Lugia")
   if(Springs)
      Selected.Push("Springs")
   if(Deluxe)
      Selected.Push("Deluxe")
   if(MegaGyarados)
      Selected.Push("MegaGyarados")
   if(MegaBlaziken)
      Selected.Push("MegaBlaziken")
   if(MegaAltaria)
      Selected.Push("MegaAltaria")

   for index, value in Selected {
      if(index = Selected.MaxIndex())
         commaSeparate := ","
      else
         commaSeparate := ", "
      if(value)
         selectMsg .= value . commaSeparate
      else
         selectMsg .= value . commaSeparate
   }
   
   Loop {
      Sleep, 30000
      
      IniRead, mainTestMode, HeartBeat.ini, TestMode, Main, -1
      if (mainTestMode != -1) {
         IniRead, mainStatus, HeartBeat.ini, HeartBeat, Main, 0
         
         onlineAHK := ""
         offlineAHK := ""
         Online := []
         
         Loop %Instances% {
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
         
         if (runMain) {
            if(mainStatus) {
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
         }
         
         if(offlineAHK = "")
            offlineAHK := "Offline: none"
         else
            offlineAHK := "Offline: " . RTrim(offlineAHK, ", ")
         if(onlineAHK = "")
            onlineAHK := "Online: none"
         else
            onlineAHK := "Online: " . RTrim(onlineAHK, ", ")
         
         discMessage := heartBeatName ? "\n" . heartBeatName : ""
         discMessage .= "\n" . onlineAHK . "\n" . offlineAHK
         
         total := SumVariablesInJsonFile()
         totalSeconds := Round((A_TickCount - rerollTime) / 1000)
         mminutes := Floor(totalSeconds / 60)
         packStatus := "Time: " . mminutes . "m | Packs: " . total
         packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"
         
         discMessage .= "\n" . packStatus . "\nVersion: " . RegExReplace(githubUser, "-.*$") . "-" . localVersion
         discMessage .= typeMsg
         discMessage .= selectMsg
         
         if (mainTestMode == "1")
            discMessage .= "\n\nMain entered GP Test Mode ✕"
         else
            discMessage .= "\n\nMain exited GP Test Mode ✓"
         
         LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)
         
         IniDelete, HeartBeat.ini, TestMode, Main
      }
      
      if(Mod(A_Index, 10) = 0) {
         if(mainIdsURL != "") {
            DownloadFile(mainIdsURL, "ids.txt")
         } else {
            if(FileExist("ids.txt"))
               FileDelete, ids.txt
         }
      }
      
      total := SumVariablesInJsonFile()
      totalSeconds := Round((A_TickCount - rerollTime) / 1000)
      mminutes := Floor(totalSeconds / 60)
      
      packStatus := "Time: " . mminutes . "m Packs: " . total
      packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"
      DisplayPackStatus(packStatus, ((runMain ? Mains * scaleParam : 0) + 5), 625)
      
      if(heartBeat) {
         heartbeatIterations := heartBeatDelay * 2
         
         if (A_Index = 1 || Mod(A_Index, heartbeatIterations) = 0) {
            
            onlineAHK := ""
            offlineAHK := ""
            Online := []
            
            Loop %Instances% {
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
            
            if(runMain) {
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
            
            discMessage := heartBeatName ? "\n" . heartBeatName : ""
            
            discMessage .= "\n" . onlineAHK . "\n" . offlineAHK . "\n" . packStatus . "\nVersion: " . RegExReplace(githubUser, "-.*$") . "-" . localVersion
            discMessage .= typeMsg
            discMessage .= selectMsg
            
            LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)
            
            if (debugMode) {
               FileAppend, % A_Now . " - Heartbeat sent at iteration " . A_Index . "`n", %A_ScriptDir%\heartbeat_log.txt
            }
         }
      }
   }
}

~+F7::
   SendAllInstancesOfflineStatus()
ExitApp
return

SendAllInstancesOfflineStatus() {
   global heartBeatName, heartBeatWebhookURL, localVersion, githubUser, Instances, runMain, Mains
   global typeMsg, selectMsg, rerollTime, scaleParam
   
   DisplayPackStatus("Shift+F7 pressed - Sending offline heartbeat to Discord...", ((runMain ? Mains * scaleParam : 0) + 5), 625)
   
   offlineInstances := ""
   if (runMain) {
      offlineInstances := "Main"
      if (Mains > 1) {
         Loop, % Mains - 1
            offlineInstances .= ", Main" . (A_Index + 1)
      }
      if (Instances > 0)
         offlineInstances .= ", "
   }
   
   Loop, %Instances% {
      offlineInstances .= A_Index
      if (A_Index < Instances)
         offlineInstances .= ", "
   }
   
   discMessage := heartBeatName ? "\n" . heartBeatName : ""
   discMessage .= "\nOnline: none"
   discMessage .= "\nOffline: " . offlineInstances
   
   total := SumVariablesInJsonFile()
   totalSeconds := Round((A_TickCount - rerollTime) / 1000)
   mminutes := Floor(totalSeconds / 60)
   packStatus := "Time: " . mminutes . "m | Packs: " . total
   packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"
   
   discMessage .= "\n" . packStatus . "\nVersion: " . RegExReplace(githubUser, "-.*$") . "-" . localVersion
   discMessage .= typeMsg
   discMessage .= selectMsg
   discMessage .= "\n\n All instances marked as OFFLINE"
   
   LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)
   
   DisplayPackStatus("Discord notification sent: All instances marked as OFFLINE", ((runMain ? Mains * scaleParam : 0) + 5), 625)
}

global jsonFileName := ""

InitializeJsonFile() {
   global jsonFileName
   fileName := A_ScriptDir . "\json\Packs.json"
   
   FileCreateDir, %A_ScriptDir%\json
   
   if FileExist(fileName)
      FileDelete, %fileName%
   if !FileExist(fileName) {
      FileAppend, [], %fileName%
      jsonFileName := fileName
      return
   }
}

AppendToJsonFile(variableValue) {
   global jsonFileName
   if (jsonFileName = "") {
      MsgBox, 0x40000, JSON, JSON file not initialized. Call InitializeJsonFile() first.
      return
   }
   
   FileRead, jsonContent, %jsonFileName%
   if (jsonContent = "") {
      jsonContent := "[]"
   }
   
   jsonContent := SubStr(jsonContent, 1, StrLen(jsonContent) - 1)
   if (jsonContent != "[")
      jsonContent .= ","
   jsonContent .= "{""time"": """ A_Now """, ""variable"": " variableValue "}]"
   
   FileDelete, %jsonFileName%
   FileAppend, %jsonContent%, %jsonFileName%
}

SumVariablesInJsonFile() {
   global jsonFileName
   if (jsonFileName = "") {
      return 0
   }
   FileRead, jsonContent, %jsonFileName%
   if (jsonContent = "") {
      return 0
   }
   
   sum := 0
   jsonContent := StrReplace(jsonContent, "[", "")
   jsonContent := StrReplace(jsonContent, "]", "")
   Loop, Parse, jsonContent, {, }
   {
      if (RegExMatch(A_LoopField, """variable"":\s*(-?\d+)", match)) {
         sum += match1
      }
   }
   
   if(sum > 0) {
      totalFile := A_ScriptDir . "\json\total.json"
      totalContent := "{""total_sum"": " sum "}"
      FileDelete, %totalFile%
      FileAppend, %totalContent%, %totalFile%
   }
   
   return sum
}

CheckForUpdate() {
   global githubUser, repoName, localVersion, zipPath, extractPath, scriptFolder, currentDictionary
   url := "https://api.github.com/repos/" githubUser "/" repoName "/releases/latest"
   
   response := HttpGet(url)
   if !response
   {
      MsgBox, 0x40000, Check for Update, Failed to fetch latest version info
      return
   }
   latestReleaseBody := FixFormat(ExtractJSONValue(response, "body"))
   latestVersion := ExtractJSONValue(response, "tag_name")
   zipDownloadURL := ExtractJSONValue(response, "zipball_url")
   Clipboard := latestReleaseBody
   if (zipDownloadURL = "" || !InStr(zipDownloadURL, "http"))
   {
      MsgBox, 0x40000, Check for Update, Failed to get download URL
      return
   }
   
   if (latestVersion = "")
   {
      MsgBox, 0x40000, Check for Update, Failed to get version info
      return
   }
   
   if (VersionCompare(latestVersion, localVersion) > 0)
   {
      releaseNotes := latestReleaseBody
      
      updateAvailable := "Update Available: "
      latestDownloaad := "Download Latest Version?"
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
            }
            else
            {
               MsgBox, 0x40000, Check for Update, Update files not found
               return
            }
         }
      }
      else
      {
         MsgBox, 0x40000, Check for Update, Update cancelled
         return
      }
   }
   else
   {
   }
}

MoveFilesRecursively(srcFolder, destFolder) {
   Loop, Files, % srcFolder . "\*", R
   {
      relativePath := SubStr(A_LoopFileFullPath, StrLen(srcFolder) + 2)
      
      destPath := destFolder . "\" . relativePath
      
      if (A_LoopIsDir)
      {
         FileCreateDir, % destPath
      }
      else
      {
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

HttpGet(url) {
   http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
   http.Open("GET", url, false)
   http.Send()
   return http.ResponseText
}

ExtractJSONValue(json, key1, key2:="", ext:="") {
   value := ""
   json := StrReplace(json, """", "")
   lines := StrSplit(json, ",")
   
   Loop, % lines.MaxIndex()
   {
      if InStr(lines[A_Index], key1 ":") {
         value := SubStr(lines[A_Index], InStr(lines[A_Index], ":") + 1)
         if (key2 != "")
         {
            if InStr(lines[A_Index+1], key2 ":") && InStr(lines[A_Index+1], ext)
               value := SubStr(lines[A_Index+1], InStr(lines[A_Index+1], ":") + 1)
         }
         break
      }
   }
   return Trim(value)
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

VersionCompare(v1, v2) {
   cleanV1 := RegExReplace(v1, "[^\d.]")
   cleanV2 := RegExReplace(v2, "[^\d.]")
   
   v1Parts := StrSplit(cleanV1, ".")
   v2Parts := StrSplit(cleanV2, ".")
   
   Loop, % Max(v1Parts.MaxIndex(), v2Parts.MaxIndex()) {
      num1 := v1Parts[A_Index] ? v1Parts[A_Index] : 0
      num2 := v2Parts[A_Index] ? v2Parts[A_Index] : 0
      if (num1 > num2)
         return 1
      if (num1 < num2)
         return -1
   }
   
   isV1Alpha := InStr(v1, "alpha") || InStr(v1, "beta")
   isV2Alpha := InStr(v2, "alpha") || InStr(v2, "beta")
   
   if (isV1Alpha && !isV2Alpha)
      return -1
   if (!isV1Alpha && isV2Alpha)
      return 1
   
   return 0
}

DownloadFile(url, filename) {
   url := url
   localPath = %A_ScriptDir%\%filename%
   
   URLDownloadToFile, %url%, %localPath%
}

ReadFile(filename, numbers := false) {
   FileRead, content, %A_ScriptDir%\%filename%.txt
   
   if (!content)
      return false
   
   values := []
   for _, val in StrSplit(Trim(content), "`n") {
      cleanVal := RegExReplace(val, "[^a-zA-Z0-9]")
      if (cleanVal != "")
         values.Push(cleanVal)
   }
   
   return values.MaxIndex() ? values : false
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

KillAllScripts() {
   Process, Exist, Monitor.ahk
   if (ErrorLevel) {
      Process, Close, %ErrorLevel%
   }
   
   Loop, 50 {
      scriptName := A_Index . ".ahk"
      Process, Exist, %scriptName%
      if (ErrorLevel) {
         Process, Close, %ErrorLevel%
      }
      
      if (A_Index = 1) {
         Process, Exist, Main.ahk
         if (ErrorLevel) {
            Process, Close, %ErrorLevel%
         }
      } else {
         mainScript := "Main" . A_Index . ".ahk"
         Process, Exist, %mainScript%
         if (ErrorLevel) {
            Process, Close, %ErrorLevel%
         }
      }
   }
   
   Gui, PackStatusGUI:Destroy

   Return
}


