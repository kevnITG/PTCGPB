#Include %A_ScriptDir%\Dictionary.ahk
#SingleInstance Force

; GUI dimensions
global GUI_WIDTH := 1250
global GUI_HEIGHT := 600

if not A_IsAdmin
{
    ; Relaunch script with admin rights
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

isNumeric(var) {
  if var is number
    return true
  return false
}

MigrateDeleteMethod(oldMethod) {
    if (oldMethod = "13 Pack") {
        return "Create Bots (13P)"
    } else if (oldMethod = "Inject") {
        return "Inject 13-39P"
    } else if (oldMethod = "Inject for Reroll") {
        return "Inject Wonderpick 39P+"
    } else if (oldMethod = "Inject Missions") {
        return "Inject 13-39P"
    }
    return oldMethod
}

LoadSettingsFromIni() {
  global
  IniPath := A_ScriptDir . "\..\..\Settings.ini"
  ; Check if Settings.ini exists
  if (FileExist(IniPath)) {
    ; Read basic settings with default values if they don't exist in the file
    ;friend id
    IniRead, FriendID, %A_ScriptDir%\..\..\Settings.ini, UserSettings, FriendID, ""
    ;instance settings
    IniRead, Instances, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Instances, 1
    IniRead, instanceStartDelay, %A_ScriptDir%\..\..\Settings.ini, UserSettings, instanceStartDelay, 0
    IniRead, Columns, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Columns, 5
    IniRead, runMain, %A_ScriptDir%\..\..\Settings.ini, UserSettings, runMain, 1
    IniRead, Mains, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Mains, 1
    IniRead, AccountName, %A_ScriptDir%\..\..\Settings.ini, UserSettings, AccountName, ""
    IniRead, autoLaunchMonitor, %A_ScriptDir%\..\..\Settings.ini, UserSettings, autoLaunchMonitor, 1
    IniRead, autoUseGPTest, %A_ScriptDir%\..\..\Settings.ini, UserSettings, autoUseGPTest, 0
    IniRead, TestTime, %A_ScriptDir%\..\..\Settings.ini, UserSettings, TestTime, 3600
    ;Time settings
    IniRead, Delay, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Delay, 250
    IniRead, waitTime, %A_ScriptDir%\..\..\Settings.ini, UserSettings, waitTime, 5
    IniRead, swipeSpeed, %A_ScriptDir%\..\..\Settings.ini, UserSettings, swipeSpeed, 300
    IniRead, slowMotion, %A_ScriptDir%\..\..\Settings.ini, UserSettings, slowMotion, 0
    
    ;system settings
    IniRead, SelectedMonitorIndex, %A_ScriptDir%\..\..\Settings.ini, UserSettings, SelectedMonitorIndex, 1
    IniRead, defaultLanguage, %A_ScriptDir%\..\..\Settings.ini, UserSettings, defaultLanguage, Scale125
    IniRead, rowGap, %A_ScriptDir%\..\..\Settings.ini, UserSettings, rowGap, 100
    IniRead, folderPath, %A_ScriptDir%\..\..\Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
    IniRead, ocrLanguage, %A_ScriptDir%\..\..\Settings.ini, UserSettings, ocrLanguage, en
    IniRead, clientLanguage, %A_ScriptDir%\..\..\Settings.ini, UserSettings, clientLanguage, en
    IniRead, instanceLaunchDelay, %A_ScriptDir%\..\..\Settings.ini, UserSettings, instanceLaunchDelay, 5
    
    ; Extra Settings
    IniRead, tesseractPath, %A_ScriptDir%\..\..\Settings.ini, UserSettings, tesseractPath, C:\Program Files\Tesseract-OCR\tesseract.exe
    IniRead, applyRoleFilters, %A_ScriptDir%\..\..\Settings.ini, UserSettings, applyRoleFilters, 0
    IniRead, debugMode, %A_ScriptDir%\..\..\Settings.ini, UserSettings, debugMode, 0
    IniRead, tesseractOption, %A_ScriptDir%\..\..\Settings.ini, UserSettings, tesseractOption, 0
    IniRead, statusMessage, %A_ScriptDir%\..\..\Settings.ini, UserSettings, statusMessage, 1
    
    ;pack settings
    IniRead, minStars, %A_ScriptDir%\..\..\Settings.ini, UserSettings, minStars, 0
    IniRead, minStarsShiny, %A_ScriptDir%\..\..\Settings.ini, UserSettings, minStarsShiny, 0
    IniRead, deleteMethod, %A_ScriptDir%\..\..\Settings.ini, UserSettings, deleteMethod, Create Bots (13P)
      originalDeleteMethod := deleteMethod
      deleteMethod := MigrateDeleteMethod(deleteMethod)
      if (deleteMethod != originalDeleteMethod) {
      IniWrite, %deleteMethod%, Settings.ini, UserSettings, deleteMethod
      }
      validMethods := "Create Bots (13P)|Inject 13-39P|Inject Wonderpick 39P+"
      if (!InStr(validMethods, deleteMethod)) {
          deleteMethod := "Create Bots (13P)"
          IniWrite, %deleteMethod%, Settings.ini, UserSettings, deleteMethod
      }
    IniRead, packMethod, %A_ScriptDir%\..\..\Settings.ini, UserSettings, packMethod, 0
    IniRead, nukeAccount, %A_ScriptDir%\..\..\Settings.ini, UserSettings, nukeAccount, 0
    IniRead, spendHourGlass, %A_ScriptDir%\..\..\Settings.ini, UserSettings, spendHourGlass, 0
    IniRead, openExtraPack, %A_ScriptDir%\..\..\Settings.ini, UserSettings, openExtraPack, 0
    IniRead, injectSortMethod, %A_ScriptDir%\..\..\Settings.ini, UserSettings, injectSortMethod, ModifiedAsc
    
    IniRead, Palkia, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Palkia, 0
    IniRead, Dialga, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Dialga, 0
    IniRead, Arceus, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Arceus, 0
    IniRead, Shining, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Shining, 0
    IniRead, Mew, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Mew, 0
    IniRead, Pikachu, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Pikachu, 0
    IniRead, Charizard, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Charizard, 0
    IniRead, Mewtwo, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Mewtwo, 0
    IniRead, Solgaleo, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Solgaleo, 0
    IniRead, Lunala, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Lunala, 0
    IniRead, Buzzwole, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Buzzwole, 0
    IniRead, Eevee, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Eevee, 0
    IniRead, HoOh, %A_ScriptDir%\..\..\Settings.ini, UserSettings, HoOh, 0
    IniRead, Lugia, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Lugia, 0
    
    IniRead, CheckShinyPackOnly, %A_ScriptDir%\..\..\Settings.ini, UserSettings, CheckShinyPackOnly, 0
    IniRead, TrainerCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, TrainerCheck, 0
    IniRead, FullArtCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, FullArtCheck, 0
    IniRead, RainbowCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, RainbowCheck, 0
    IniRead, ShinyCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, ShinyCheck, 0
    IniRead, CrownCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, CrownCheck, 0
    IniRead, ImmersiveCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, ImmersiveCheck, 0
    IniRead, InvalidCheck, %A_ScriptDir%\..\..\Settings.ini, UserSettings, InvalidCheck, 0
    IniRead, PseudoGodPack, %A_ScriptDir%\..\..\Settings.ini, UserSettings, PseudoGodPack, 0
    
    ; Read S4T settings
    IniRead, s4tEnabled, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tEnabled, 0
    IniRead, s4tSilent, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tSilent, 1
    IniRead, s4t3Dmnd, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4t3Dmnd, 0
    IniRead, s4t4Dmnd, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4t4Dmnd, 0
    IniRead, s4t1Star, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4t1Star, 0
    IniRead, s4tGholdengo, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tGholdengo, 0
    IniRead, s4tWP, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tWP, 0
    IniRead, s4tWPMinCards, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tWPMinCards, 1
    IniRead, s4tDiscordWebhookURL, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tDiscordWebhookURL, ""
    IniRead, s4tDiscordUserId, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tDiscordUserId, ""
    IniRead, s4tSendAccountXml, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tSendAccountXml, 0
    
    ;discord settings
    IniRead, DiscordWebhookURL, %A_ScriptDir%\..\..\Settings.ini, UserSettings, DiscordWebhookURL, ""
    IniRead, DiscordUserId, %A_ScriptDir%\..\..\Settings.ini, UserSettings, DiscordUserId, ""
    IniRead, heartBeat, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeat, 0
    IniRead, heartBeatWebhookURL, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatWebhookURL, ""
    IniRead, heartBeatName, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatName, ""
    IniRead, heartBeatDelay, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatDelay, 30
    IniRead, sendAccountXml, %A_ScriptDir%\..\..\Settings.ini, UserSettings, sendAccountXml, 0

    ;download settings
    IniRead, mainIdsURL, %A_ScriptDir%\..\..\Settings.ini, UserSettings, mainIdsURL, ""
    IniRead, vipIdsURL, %A_ScriptDir%\..\..\Settings.ini, UserSettings, vipIdsURL, ""
    IniRead, showcaseEnabled, %A_ScriptDir%\..\..\Settings.ini, UserSettings, showcaseEnabled, 0
    
    ; Validate numeric values
    if (!IsNumeric(Instances))
      Instances := 1
    if (!IsNumeric(Columns) || Columns < 1)
      Columns := 5
    if (!IsNumeric(waitTime))
      waitTime := 5
    if (!IsNumeric(Delay) || Delay < 10)
      Delay := 250
    
    ; Return success
    return true
  } else {
    ; Settings file doesn't exist, will use defaults
    return false
  }
}

; Unified function to save all settings to INI file - FIXED VERSION
SaveAllSettings() {
  global FriendID, AccountName, waitTime, Delay, folderPath, discordWebhookURL, discordUserId, Columns, godPack
  global Instances, instanceStartDelay, defaultLanguage, SelectedMonitorIndex, swipeSpeed, deleteMethod
  global runMain, Mains, heartBeat, heartBeatWebhookURL, heartBeatName, nukeAccount, packMethod
  global autoLaunchMonitor, autoUseGPTest, TestTime
  global CheckShinyPackOnly, TrainerCheck, FullArtCheck, RainbowCheck, ShinyCheck, CrownCheck
  global InvalidCheck, ImmersiveCheck, PseudoGodPack, minStars, Palkia, Dialga, Arceus, Shining
  global Mew, Pikachu, Charizard, Mewtwo, Solgaleo, Lunala, Buzzwole, Eevee, HoOh, Lugia, slowMotion, ocrLanguage, clientLanguage
  global CurrentVisibleSection, heartBeatDelay, sendAccountXml, showcaseEnabled, showcaseURL, isDarkTheme
  global useBackgroundImage, tesseractPath, applyRoleFilters, debugMode, tesseractOption, statusMessage
  global s4tEnabled, s4tSilent, s4t3Dmnd, s4t4Dmnd, s4t1Star, s4tGholdengo, s4tWP, s4tWPMinCards
  global s4tDiscordUserId, s4tDiscordWebhookURL, s4tSendAccountXml, minStarsShiny, instanceLaunchDelay, mainIdsURL, vipIdsURL
  global spendHourGlass, openExtraPack, injectSortMethod, rowGap, SortByDropdown
  global waitForEligibleAccounts, maxWaitHours, skipMissionsInjectMissions
  
    
  ; FIXED: Make sure all values are properly synced from GUI before saving
  Gui, Submit, NoHide
  
  ; FIXED: Explicitly get the deleteMethod from the dropdown control with validation
  GuiControlGet, currentDeleteMethod,, deleteMethod
  if (currentDeleteMethod != "" && currentDeleteMethod != "ERROR") {
    deleteMethod := currentDeleteMethod
  } else if (deleteMethod = "" || deleteMethod = "ERROR") {
    ; Set default if empty or invalid
    deleteMethod := "Create Bots (13P)"
  }
  
  ; FIXED: Validate deleteMethod against known valid options
  validMethods := "Create Bots (13P)|Inject 13-39P|Inject Missions|Inject Wonderpick 39P+"
  if (!InStr(validMethods, deleteMethod)) {
    deleteMethod := "Create Bots (13P)" ; Reset to default if invalid
  }
  
  ; Update injectSortMethod based on dropdown if available
  if (sortByCreated) {
    GuiControlGet, selectedOption,, SortByDropdown
    if (selectedOption = "Oldest First")
      injectSortMethod := "ModifiedAsc"
    else if (selectedOption = "Newest First")
      injectSortMethod := "ModifiedDesc"
    else if (selectedOption = "Fewest Packs First")
      injectSortMethod := "PacksAsc"
    else if (selectedOption = "Most Packs First")
      injectSortMethod := "PacksDesc"
  }
  
  ; Do not initalize friend IDs or id.txt if Inject or Inject Missions
  IniWrite, %deleteMethod%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, deleteMethod
  if (deleteMethod = "Inject Wonderpick 39P+" || deleteMethod = "Create Bots (13P)") {
    IniWrite, %FriendID%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, FriendID
    IniWrite, %mainIdsURL%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, mainIdsURL
  } else {
    idsPath := A_ScriptDir . "\..\..\ids.txt"
    if(FileExist(idsPath))
      FileDelete, %idsPath%
    IniWrite, "", %A_ScriptDir%\..\..\Settings.ini, UserSettings, FriendID
    IniWrite, "", %A_ScriptDir%\..\..\Settings.ini, UserSettings, mainIdsURL
    mainIdsURL := ""
    FriendID := ""
  }
  ; Save Reroll settings
  IniWrite, %Instances%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Instances
  IniWrite, %instanceStartDelay%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, instanceStartDelay
  IniWrite, %Columns%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Columns
  IniWrite, %runMain%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, runMain
  IniWrite, %Mains%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Mains
  IniWrite, %autoUseGPTest%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, autoUseGPTest
  IniWrite, %TestTime%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, TestTime
  IniWrite, %AccountName%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, AccountName  
  IniWrite, %Delay%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Delay
  IniWrite, %waitTime%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, waitTime
  IniWrite, %swipeSpeed%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, swipeSpeed
  IniWrite, %slowMotion%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, slowMotion
  ; System Settings
  IniWrite, %SelectedMonitorIndex%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, SelectedMonitorIndex
  IniWrite, %defaultLanguage%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, defaultLanguage
  IniWrite, %rowGap%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, rowGap
  IniWrite, %folderPath%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, folderPath
  IniWrite, %ocrLanguage%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, ocrLanguage
  IniWrite, %clientLanguage%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, clientLanguage
  IniWrite, %autoLaunchMonitor%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, autoLaunchMonitor
  IniWrite, %instanceLaunchDelay%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, instanceLaunchDelay
  ; Save extra settings
  IniWrite, %tesseractPath%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, tesseractPath
  IniWrite, %applyRoleFilters%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, applyRoleFilters
  IniWrite, %debugMode%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, debugMode
  IniWrite, %tesseractOption%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, tesseractOption
  IniWrite, %statusMessage%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, statusMessage
  ; Save Pack Settings
  IniWrite, %minStars%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, minStars
  IniWrite, %minStarsShiny%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, minStarsShiny
  IniWrite, %nukeAccount%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, nukeAccount
  IniWrite, %packMethod%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, packMethod
  IniWrite, %spendHourGlass%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, spendHourGlass
  IniWrite, %openExtraPack%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, openExtraPack
  IniWrite, %injectSortMethod%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, injectSortMethod
  ; Save pack selections directly without resetting them
  IniWrite, %Palkia%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Palkia
  IniWrite, %Dialga%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Dialga
  IniWrite, %Arceus%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Arceus
  IniWrite, %Shining%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Shining
  IniWrite, %Mew%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Mew
  IniWrite, %Pikachu%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Pikachu
  IniWrite, %Charizard%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Charizard
  IniWrite, %Mewtwo%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Mewtwo
  IniWrite, %Solgaleo%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Solgaleo
  IniWrite, %Lunala%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Lunala
  IniWrite, %Buzzwole%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Buzzwole
  IniWrite, %Eevee%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Eevee
  IniWrite, %HoOh%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, HoOh
  IniWrite, %Lugia%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, Lugia
  ; Card Detection
  IniWrite, %CheckShinyPackOnly%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, CheckShinyPackOnly
  IniWrite, %TrainerCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, TrainerCheck
  IniWrite, %FullArtCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, FullArtCheck
  IniWrite, %RainbowCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, RainbowCheck
  IniWrite, %ShinyCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, ShinyCheck
  IniWrite, %CrownCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, CrownCheck
  IniWrite, %InvalidCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, InvalidCheck
  IniWrite, %ImmersiveCheck%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, ImmersiveCheck
  IniWrite, %PseudoGodPack%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, PseudoGodPack
  ; Save S4T settings
  IniWrite, %s4tEnabled%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tEnabled
  IniWrite, %s4tSilent%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tSilent
  IniWrite, %s4t3Dmnd%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4t3Dmnd
  IniWrite, %s4t4Dmnd%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4t4Dmnd
  IniWrite, %s4t1Star%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4t1Star
  IniWrite, %s4tGholdengo%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tGholdengo
  IniWrite, %s4tWP%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tWP
  IniWrite, %s4tWPMinCards%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tWPMinCards
  IniWrite, %s4tDiscordUserId%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tDiscordUserId
  IniWrite, %s4tDiscordWebhookURL%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tDiscordWebhookURL
  IniWrite, %s4tSendAccountXml%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, s4tSendAccountXml
  ; Save Discord Settings
  IniWrite, %discordWebhookURL%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, discordWebhookURL
  IniWrite, %discordUserId%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, discordUserId
  IniWrite, %sendAccountXml%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, sendAccountXml
  ; HeartBeat Settings
  IniWrite, %heartBeat%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeat
  IniWrite, %heartBeatWebhookURL%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatWebhookURL
  IniWrite, %heartBeatName%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatName
  IniWrite, %heartBeatDelay%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, heartBeatDelay
  ; Save Download Settings
  IniWrite, %mainIdsURL%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, mainIdsURL
  IniWrite, %vipIdsURL%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, vipIdsURL
  ; Save showcase settings
  IniWrite, %showcaseEnabled%, %A_ScriptDir%\..\..\Settings.ini, UserSettings, showcaseEnabled  
  ; FIXED: Debug logging if enabled
  if (debugMode) {
    FileAppend, % A_Now . " - Settings saved. DeleteMethod: " . deleteMethod . "`n", %A_ScriptDir%\..\..\debug_settings.log
  }
}
global saveSignalFile
saveSignalFile := A_ScriptDir "\save.signal"
global currentDictionary
LoadSettingsFromIni()
IniRead, IsLanguageSet, %A_ScriptDir%\..\..\Settings.ini, UserSettings, IsLanguageSet, 0
IniRead, defaultBotLanguage, %A_ScriptDir%\..\..\Settings.ini, UserSettings, defaultBotLanguage, 0
IniRead, BotLanguage, %A_ScriptDir%\..\..\Settings.ini, UserSettings, BotLanguage, English
currentDictionary := CreateGUITextByLanguage(defaultBotLanguage, "")
; Create a stylish GUI with custom colors and modern look
Gui, Color, 1E1E1E, 333333 ; Dark theme background
Gui, Font, s10 cWhite, Segoe UI ; Modern font

; ========== Friend ID Section ==========
sectionColor := "cWhite"
Gui, Add, GroupBox, x5 y0 w240 h50 %sectionColor%, Friend ID
if(FriendID = "ERROR" || FriendID = "")
  FriendID =
Gui, Add, Edit, vFriendID w180 x35 y20 h20 -E0x200 Background2A2A2A cWhite, %FriendID%

; Hide FriendID on initial load if "Create Accounts" is selected"
if (deleteMethod = "Create Bots (13P)") {
   GuiControl, Hide, FriendID
}

; ========== Instance Settings Section ==========
sectionColor := "cWhite"
Gui, Add, GroupBox, x5 y50 w240 h180 %sectionColor%, Instance Settings
Gui, Add, Text, x20 y75 %sectionColor%, % currentDictionary.Txt_Instances
Gui, Add, Edit, vInstances w50 x125 y73 h20 -E0x200 Background2A2A2A cWhite Center, %Instances%
Gui, Add, Text, x20 y100 %sectionColor%, % currentDictionary.Txt_Columns
Gui, Add, Edit, vColumns w50 x125 y98 h20 -E0x200 Background2A2A2A cWhite Center, %Columns%
Gui, Add, Text, x20 y125 %sectionColor%, % currentDictionary.Txt_InstanceStartDelay
Gui, Add, Edit, vinstanceStartDelay w50 x125 y123 h20 -E0x200 Background2A2A2A cWhite Center, %instanceStartDelay%

Gui, Add, Checkbox, % (runMain ? "Checked" : "") " vrunMain gmainSettings x20 y150 " . sectionColor, % currentDictionary.Txt_runMain
Gui, Add, Edit, % "vMains w50 x125 y148 h20 -E0x200 Background2A2A2A " . sectionColor . " Center" . (runMain ? "" : " Hidden"), %Mains%

Gui, Add, Checkbox, % (autoUseGPTest ? "Checked" : "") " vautoUseGPTest gautoUseGPTestSettings x20 y175 " . sectionColor, % currentDictionary.Txt_autoUseGPTest
Gui, Add, Edit, % "vTestTime w50 x185 y173 h20 -E0x200 Background2A2A2A " . sectionColor . " Center" . (autoUseGPTest ? "" : " Hidden"), %TestTime%

Gui, Add, Text, x20 y200 %sectionColor%, % currentDictionary.Txt_AccountName
Gui, Add, Edit, vAccountName w110 x125 y198 h20 -E0x200 Background2A2A2A cWhite Center, %AccountName%
; ========== Time Settings Section ==========
sectionColor := "c9370DB" ; Purple
Gui, Add, GroupBox, x5 y230 w240 h125 %sectionColor%, Time Settings
Gui, Add, Text, x20 y255 %sectionColor%, % currentDictionary.Txt_Delay
Gui, Add, Edit, vDelay w60 x145 y253 h20 -E0x200 Background2A2A2A cWhite Center, %Delay%
Gui, Add, Text, x20 y280 %sectionColor%, % currentDictionary.Txt_SwipeSpeed
Gui, Add, Edit, vswipeSpeed w60 x145 y278 h20 -E0x200 Background2A2A2A cWhite Center, %swipeSpeed%
Gui, Add, Text, x20 y305 %sectionColor%, % currentDictionary.Txt_WaitTime
Gui, Add, Edit, vwaitTime w60 x145 y303 h20 -E0x200 Background2A2A2A cWhite Center, %waitTime%
Gui, Add, Checkbox, % (slowMotion ? "Checked" : "") " vslowMotion x20 y330 " . sectionColor, Base Game Compatibility

; ========== System Settings Section ==========
sectionColor := "c4169E1" ; Royal Blue
Gui, Add, GroupBox, x5 y355 w240 h235 %sectionColor%, System Settings
Gui, Add, Text, x20 y375 %sectionColor%, % currentDictionary.Txt_Monitor
SysGet, MonitorCount, MonitorCount
MonitorOptions := ""
Loop, %MonitorCount% {
  SysGet, MonitorName, MonitorName, %A_Index%
  SysGet, Monitor, Monitor, %A_Index%
  MonitorOptions .= (A_Index > 1 ? "|" : "") "" A_Index ": (" MonitorRight - MonitorLeft "x" MonitorBottom - MonitorTop ")"
}
SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
Gui, Add, DropDownList, x20 y395 w125 vSelectedMonitorIndex Choose%SelectedMonitorIndex% Background2A2A2A cWhite, %MonitorOptions%
Gui, Add, Text, x155 y375 %sectionColor%, % currentDictionary.Txt_Scale
if (defaultLanguage = "Scale125") {
  defaultLang := 1
  scaleParam := 277
} else if (defaultLanguage = "Scale100") {
  defaultLang := 2
  scaleParam := 287
}
Gui, Add, DropDownList, x155 y395 w75 vdefaultLanguage choose%defaultLang% Background2A2A2A cWhite, Scale125
Gui, Add, Text, x20 y425 %sectionColor%, % currentDictionary.Txt_RowGap
Gui, Add, Edit, vRowGap w50 x125 y425 h20 -E0x200 Background2A2A2A cWhite Center, %RowGap%
Gui, Add, Text, x20 y450 %sectionColor%, % currentDictionary.Txt_FolderPath
Gui, Add, Edit, vfolderPath w210 x20 y470 h20 -E0x200 Background2A2A2A cWhite, %folderPath%

Gui, Add, Text, x20 y500 %sectionColor%, OCR:

; ========== Language Pack list ==========
ocrLanguageList := "en|zh|es|de|fr|ja|ru|pt|ko|it|tr|pl|nl|sv|ar|uk|id|vi|th|he|cs|no|da|fi|hu|el|zh-TW"

if (ocrLanguage != "")
{
  index := 0
  Loop, Parse, ocrLanguageList, |
  {
    index++
    if (A_LoopField = ocrLanguage)
    {
      defaultOcrLang := index
      break
    }
  }
}

Gui, Add, DropDownList, vocrLanguage choose%defaultOcrLang% x60 y495 w50 Background2A2A2A cWhite, %ocrLanguageList%

Gui, Add, Text, x125 y500 %sectionColor%, Client:

; ========== Client Language Pack list ==========
clientLanguageList := "en|es|fr|de|it|pt|jp|ko|cn"

if (clientLanguage != "")
{
  index := 0
  Loop, Parse, clientLanguageList, |
  {
    index++
    if (A_LoopField = clientLanguage)
    {
      defaultClientLang := index
      break
    }
  }
}

Gui, Add, DropDownList, vclientLanguage choose%defaultClientLang% x170 y495 w50 Background2A2A2A cWhite, %clientLanguageList%

Gui, Add, Text, x20 y530 %sectionColor%, % currentDictionary.Txt_InstanceLaunchDelay
Gui, Add, Edit, vinstanceLaunchDelay w50 x170 y528 h20 -E0x200 Background2A2A2A cWhite Center, %instanceLaunchDelay%
Gui, Add, Checkbox, % (autoLaunchMonitor ? "Checked" : "") " vautoLaunchMonitor x20 y555 " . sectionColor, % currentDictionary.Txt_autoLaunchMonitor

; ========== Column 2 ==========
; ==============================

; Extra Settings
sectionColor := "cFDFDFD"
Gui, Add, GroupBox, x255 y0 w240 h130 %sectionColor%, Extra Settings
Gui, Add, Checkbox, % (applyRoleFilters ? "Checked" : "") " vapplyRoleFilters x275 y25 " . sectionColor, % currentDictionary.Txt_applyRoleFilters
Gui, Add, Checkbox, % (debugMode ? "Checked" : "") " vdebugMode x275 y50 " . sectionColor, % currentDictionary.Txt_debugMode
Gui, Add, Checkbox, % (tesseractOption ? "Checked" : "") " vtesseractOption x275 y75 " . sectionColor, % currentDictionary.Txt_tesseractOption
Gui, Add, Checkbox, % (statusMessage ? "Checked" : "") " vstatusMessage x275 y100 " . sectionColor, % currentDictionary.Txt_statusMessage

; ========== God Pack Settings Section ==========
sectionColor := "c39FF14" ; Neon green
Gui, Add, GroupBox, x255 y130 w240 h200 %sectionColor%, God Pack Settings
Gui, Add, Text, x270 y155 %sectionColor%, % currentDictionary.Txt_MinStars
Gui, Add, Edit, vminStars w25 x350 y153 h20 -E0x200 Background2A2A2A cWhite Center, %minStars%
Gui, Add, Text, x270 y180 %sectionColor%, % currentDictionary.Txt_ShinyMinStars
Gui, Add, Edit, vminStarsShiny w25 x410 y178 h20 -E0x200 Background2A2A2A cWhite Center, %minStarsShiny%

Gui, Add, Text, x270 y203 %sectionColor%, % currentDictionary.Txt_DeleteMethod
if (deleteMethod = "Create Bots (13P)")
  defaultDelete := 1
else if (deleteMethod = "Inject 13-39P")
  defaultDelete := 2
else if (deleteMethod = "Inject Missions")
  defaultDelete := 2 ; If user somehow set to Inject Missions after I removed the UI, default to regular Inject 13-39P
else if (deleteMethod = "Inject Wonderpick 39P+")
  defaultDelete := 3
;	SquallTCGP 2025.03.12 - 	Adding the delete method 5 Pack (Fast) to the delete method dropdown list.
Gui, Add, DropDownList, vdeleteMethod gdeleteSettings choose%defaultDelete% x350 y203 w130 Background2A2A2A cWhite, Create Bots (13P)|Inject 13-39P|Inject Wonderpick 39P+
Gui, Add, Checkbox, % (packMethod ? "Checked" : "") " vpackMethod x270 y235 " . sectionColor . ((deleteMethod = "Inject Wonderpick 39P+") ? "" : " Hidden"), % currentDictionary.Txt_packMethod
Gui, Add, Checkbox, % (nukeAccount ? "Checked" : "") " vnukeAccount x270 y255 " . sectionColor . ((deleteMethod = "Create Bots (13P)")? "": " Hidden"), % currentDictionary.Txt_nukeAccount
Gui, Add, Checkbox, % (openExtraPack ? "Checked" : "") " vopenExtraPack gopenExtraPackSettings x270 y255 " . sectionColor . ((deleteMethod = "Inject Wonderpick 39P+") ? "" : " Hidden"), % currentDictionary.Txt_openExtraPack
Gui, Add, Checkbox, % (spendHourGlass ? "Checked" : "") " vspendHourGlass gspendHourGlassSettings x270 y275 " . sectionColor . ((deleteMethod = "Create Bots (13P)")? " Hidden":""), % currentDictionary.Txt_spendHourGlass

Gui, Add, Text, x270 y300 %sectionColor%, % currentDictionary.SortByText
; Determine which option to pre-select
sortOption := 1 ; Default (ModifiedAsc)
if (injectSortMethod = "ModifiedDesc")
  sortOption := 2
else if (injectSortMethod = "PacksAsc")
  sortOption := 3
else if (injectSortMethod = "PacksDesc")
  sortOption := 4
Gui, Add, DropDownList, vSortByDropdown gSortByDropdownHandler choose%sortOption% x350 y298 w130 Background2A2A2A cWhite, Oldest First|Newest First|Fewest Packs First|Most Packs First

; ========== Card Detection Section ==========
sectionColor := "cFF4500" ; Orange Red
Gui, Add, GroupBox, x255 y330 w240 h260 %sectionColor%, Card Detection ; Orange Red
Gui, Add, Checkbox, % (FullArtCheck ? "Checked" : "") " vFullArtCheck x270 y365 " . sectionColor, % currentDictionary.Txt_FullArtCheck
Gui, Add, Checkbox, % (TrainerCheck ? "Checked" : "") " vTrainerCheck x270 y385 " . sectionColor, % currentDictionary.Txt_TrainerCheck
Gui, Add, Checkbox, % (RainbowCheck ? "Checked" : "") " vRainbowCheck x270 y405 " . sectionColor, % currentDictionary.Txt_RainbowCheck
Gui, Add, Checkbox, % (PseudoGodPack ? "Checked" : "") " vPseudoGodPack x270 y425 " . sectionColor, % currentDictionary.Txt_PseudoGodPack

Gui, Add, Checkbox, % (CheckShinyPackOnly ? "Checked" : "") " vCheckShinyPackOnly x270 y445 " . sectionColor, % currentDictionary.Txt_CheckShinyPackOnly
Gui, Add, Checkbox, % (InvalidCheck ? "Checked" : "") " vInvalidCheck x270 y465 " . sectionColor, % currentDictionary.Txt_InvalidCheck

Gui, Add, Text, x270 y495 w210 h2 +0x10 ; Creates a horizontal line
Gui, Add, Checkbox, % (CrownCheck ? "Checked" : "") " vCrownCheck x270 y505 " . sectionColor, % currentDictionary.Txt_CrownCheck
Gui, Add, Checkbox, % (ShinyCheck ? "Checked" : "") " vShinyCheck x270 y525 " . sectionColor, % currentDictionary.Txt_ShinyCheck
Gui, Add, Checkbox, % (ImmersiveCheck ? "Checked" : "") " vImmersiveCheck x270 y545 " . sectionColor, % currentDictionary.Txt_ImmersiveCheck

; ========== Column 3 ==========
; ==============================
; ========== Pack Selection Section ==========
sectionColor := "cFFD700" ; Gold
Gui, Add, GroupBox, x505 y0 w240 h590 %sectionColor%, Pack Selection

Gui, Add, Checkbox, % (HoOh ? "Checked" : "") " vHoOh x530 y25 " . sectionColor, % currentDictionary.Txt_HoOh 
Gui, Add, Checkbox, % (Lugia ? "Checked" : "") " vLugia x530 y50 " . sectionColor, % currentDictionary.Txt_Lugia
Gui, Add, Checkbox, % (Eevee ? "Checked" : "") " vEevee x530 y75 " . sectionColor, % currentDictionary.Txt_Eevee
Gui, Add, Checkbox, % (Buzzwole ? "Checked" : "") " vBuzzwole x530 y100 " . sectionColor, % currentDictionary.Txt_Buzzwole
Gui, Add, Checkbox, % (Shining ? "Checked" : "") " vShining x530 y125 " . sectionColor, % currentDictionary.Txt_Shining
Gui, Add, Checkbox, % (Arceus ? "Checked" : "") " vArceus x530 y150 " . sectionColor, % currentDictionary.Txt_Arceus
Gui, Add, Checkbox, % (Palkia ? "Checked" : "") " vPalkia x530 y175 " . sectionColor, % currentDictionary.Txt_Palkia
Gui, Add, Checkbox, % (Dialga ? "Checked" : "") " vDialga x530 y200 " . sectionColor, % currentDictionary.Txt_Dialga
Gui, Add, Checkbox, % (Solgaleo ? "Checked" : "") " vSolgaleo x530 y225 " . sectionColor, % currentDictionary.Txt_Solgaleo
Gui, Add, Checkbox, % (Lunala ? "Checked" : "") " vLunala x530 y250 " . sectionColor, % currentDictionary.Txt_Lunala
Gui, Add, Checkbox, % (Pikachu ? "Checked" : "") " vPikachu x530 y275 " . sectionColor, % currentDictionary.Txt_Pikachu
Gui, Add, Checkbox, % (Charizard ? "Checked" : "") " vCharizard x530 y300 " . sectionColor, % currentDictionary.Txt_Charizard
Gui, Add, Checkbox, % (Mewtwo ? "Checked" : "") " vMewtwo x530 y325 " . sectionColor, % currentDictionary.Txt_Mewtwo
Gui, Add, Checkbox, % (Mew ? "Checked" : "") " vMew x530 y350 " . sectionColor, % currentDictionary.Txt_Mew

; ========== Column 4 ==========
; ==============================
; S4T Settings Section
sectionColor := "cFF4500"
Gui, Add, GroupBox, x755 y0 w240 h400 %sectionColor%, S4T Selection
Gui, Add, Checkbox, % (s4tEnabled ? "Checked" : "") " vs4tEnabled gs4tSettings x775 y25 cWhite", % currentDictionary.Txt_s4tEnabled
if(s4tEnabled) {
  Gui, Add, Checkbox, % (s4tSilent ? "Checked" : "") " vs4tSilent x775 y45 " . sectionColor, % currentDictionary.Txt_s4tSilent
  Gui, Add, Checkbox, % (s4t3Dmnd ? "Checked" : "") " vs4t3Dmnd x775 y65 " . sectionColor, 3 ◆◆◆
  Gui, Add, Checkbox, % (s4t4Dmnd ? "Checked" : "") " vs4t4Dmnd x775 y85 " . sectionColor, 4 ◆◆◆◆
  Gui, Add, Checkbox, % (s4t1Star ? "Checked" : "") " vs4t1Star x775 y105 " . sectionColor, 1 ★
  Gui, Add, Text, x775 y130 w210 h2 vs4tLine_1 +0x10 ; Creates a horizontal line
  Gui, Add, Checkbox, % (s4tWP ? "Checked" : "") " vs4tWP gs4tWPSettings x775 y145 cWhite", % currentDictionary.Txt_s4tWP
  Gui, Add, Text, % "x775 y170 vTxt_s4tWPMinCards " . sectionColor . (s4tWP ? "" : " Hidden"), % currentDictionary.Txt_s4tWPMinCards
  Gui, Add, Edit, % "cFDFDFD w50 x870 y170 h20 vs4tWPMinCards -E0x200 Background2A2A2A Center cWhite gs4tWPMinCardsCheck" . (s4tWP ? "" : " Hidden"), %s4tWPMinCards%
  Gui, Add, Text, x775 y205 w210 h2 vs4tLine_2 +0x10 ; Creates a horizontal line
  Gui, Add, Text, x775 y230 vS4TDiscordSettingsSubHeading %sectionColor%, % currentDictionary.S4TDiscordSettingsSubHeading
  if(StrLen(s4tDiscordUserId) < 3)
    s4tDiscordUserId := ""
  if(StrLen(s4tDiscordWebhookURL) < 3)
    s4tDiscordWebhookURL := ""
  Gui, Add, Text, x775 y255 vTxt_s4tDiscordUserId %sectionColor%, Discord ID:
  Gui, Add, Edit, vs4tDiscordUserId w210 x775 y280 h20 -E0x200 Background2A2A2A cWhite, %s4tDiscordUserId%
  Gui, Add, Text, x775 y305 vTxt_s4tDiscordWebhookURL %sectionColor%, Webhook URL:
  Gui, Add, Edit, vs4tDiscordWebhookURL w210 x775 y330 h20 -E0x200 Background2A2A2A cWhite, %s4tDiscordWebhookURL%
  Gui, Add, Checkbox, % (s4tSendAccountXml ? "Checked" : "") " vs4tSendAccountXml x775 y355 " . sectionColor, % currentDictionary.Txt_s4tSendAccountXml
} else {
  Gui, Add, Checkbox, % (s4tSilent ? "Checked" : "") " vs4tSilent x775 y45 Hidden " . sectionColor, % currentDictionary.Txt_s4tSilent
  Gui, Add, Checkbox, % (s4t3Dmnd ? "Checked" : "") " vs4t3Dmnd x775 y65 Hidden " . sectionColor, 3 ◆◆◆
  Gui, Add, Checkbox, % (s4t4Dmnd ? "Checked" : "") " vs4t4Dmnd x775 y85 Hidden " . sectionColor, 4 ◆◆◆◆
  Gui, Add, Checkbox, % (s4t1Star ? "Checked" : "") " vs4t1Star x775 y105 Hidden " . sectionColor, 1 ★
  Gui, Add, Text, Hidden x775 y130 w210 h2 vs4tLine_1 +0x10 ; Creates a horizontal line
  Gui, Add, Checkbox, % (s4tWP ? "Checked" : "") " vs4tWP gs4tWPSettings x775 y145 cWhite Hidden", % currentDictionary.Txt_s4tWP
  Gui, Add, Text, x775 y170 vTxt_s4tWPMinCards Hidden %sectionColor%, % currentDictionary.Txt_s4tWPMinCards
  Gui, Add, Edit, cFDFDFD w50 x870 y170 h20 vs4tWPMinCards -E0x200 Background2A2A2A Center cWhite Hidden, %s4tWPMinCards%
  Gui, Add, Text, Hidden x775 y205 w210 h2 vs4tLine_2 +0x10 ; Creates a horizontal line
  Gui, Add, Text, x775 y230 vS4TDiscordSettingsSubHeading Hidden %sectionColor%, % currentDictionary.S4TDiscordSettingsSubHeading
  if(StrLen(s4tDiscordUserId) < 3)
    s4tDiscordUserId := ""
  if(StrLen(s4tDiscordWebhookURL) < 3)
    s4tDiscordWebhookURL := ""
  Gui, Add, Text, Hidden x775 y255 vTxt_s4tDiscordUserId %sectionColor%, Discord ID:
  Gui, Add, Edit, vs4tDiscordUserId w210 x775 y280 h20 -E0x200 Background2A2A2A cWhite Hidden, %s4tDiscordUserId%
  Gui, Add, Text, Hidden x775 y305 vTxt_s4tDiscordWebhookURL %sectionColor%, Webhook URL:
  Gui, Add, Edit, vs4tDiscordWebhookURL w210 x775 y330 h20 -E0x200 Background2A2A2A cWhite Hidden, %s4tDiscordWebhookURL%
  Gui, Add, Checkbox, % (s4tSendAccountXml ? "Checked" : "") " vs4tSendAccountXml x775 y355 Hidden " . sectionColor, % currentDictionary.Txt_s4tSendAccountXml
}

; ========== Column 5 ==========
; ==============================
; ========== Discord Settings Section ==========
sectionColor := "cFF69B4" ; Hot pink
Gui, Add, GroupBox, x1005 y0 w240 h130 %sectionColor%, Discord Settings
if(StrLen(discordUserID) < 3)
  discordUserID =
if(StrLen(discordWebhookURL) < 3)
  discordWebhookURL =
Gui, Add, Text, x1020 y20 %sectionColor%, Discord ID:
Gui, Add, Edit, vdiscordUserId w210 x1020 y40 h20 -E0x200 Background2A2A2A cWhite, %discordUserId%
Gui, Add, Text, x1020 y60 %sectionColor%, Webhook URL:
Gui, Add, Edit, vdiscordWebhookURL w210 x1020 y80 h20 -E0x200 Background2A2A2A cWhite, %discordWebhookURL%
Gui, Add, Checkbox, % (sendAccountXml ? "Checked" : "") " vsendAccountXml x1020 y105 " . sectionColor, Send Account XML

; ========== Heartbeat Settings Section ==========
sectionColor := "c00FFFF" ; Cyan
Gui, Add, GroupBox, x1005 y130 w240 h160 %sectionColor%, Heartbeat Settings
Gui, Add, Checkbox, % (heartBeat ? "Checked" : "") " vheartBeat x1020 y155 gdiscordSettings " . sectionColor, % currentDictionary.Txt_heartBeat

if(StrLen(heartBeatName) < 3)
  heartBeatName =
if(StrLen(heartBeatWebhookURL) < 3)
  heartBeatWebhookURL =

if (heartBeat) {
  Gui, Add, Text, vhbName x1020 y175 %sectionColor%, % currentDictionary.hbName
  Gui, Add, Edit, vheartBeatName w210 x1020 y195 h20 -E0x200 Background2A2A2A cWhite, %heartBeatName%
  Gui, Add, Text, vhbURL x1020 y215 %sectionColor%, Webhook URL:
  Gui, Add, Edit, vheartBeatWebhookURL w210 x1020 y235 h20 -E0x200 Background2A2A2A cWhite, %heartBeatWebhookURL%
  Gui, Add, Text, vhbDelay x1020 y260 %sectionColor%, % currentDictionary.hbDelay
  Gui, Add, Edit, vheartBeatDelay w50 x1160 y260 h20 -E0x200 Background2A2A2A cWhite Center, %heartBeatDelay%
} else {
  Gui, Add, Text, vhbName x1020 y175 Hidden %sectionColor%, % currentDictionary.hbName
  Gui, Add, Edit, vheartBeatName w210 x1020 y195 h20 Hidden -E0x200 Background2A2A2A cWhite, %heartBeatName%
  Gui, Add, Text, vhbURL x1020 y215 Hidden %sectionColor%, Webhook URL:
  Gui, Add, Edit, vheartBeatWebhookURL w210 x1020 y235 h20 Hidden -E0x200 Background2A2A2A cWhite, %heartBeatWebhookURL%
  Gui, Add, Text, vhbDelay x1020 y260 Hidden %sectionColor%, % currentDictionary.hbDelay
  Gui, Add, Edit, vheartBeatDelay w50 x1160 y260 h20 Hidden -E0x200 Background2A2A2A cWhite Center, %heartBeatDelay%
}

; ========== Action Buttons ==========
Gui, Add, Button, gSave x1005 y310 w240 h90, Save Settings
; ========== Download Settings Section (Bottom right) ==========
sectionColor := "cWhite"
Gui, Add, GroupBox, x755 y405 w490 h185 %sectionColor%, Download Settings ;

if(StrLen(mainIdsURL) < 3)
  mainIdsURL =
if(StrLen(vipIdsURL) < 3)
  vipIdsURL =

Gui, Add, Text, x770 y425 %sectionColor%, ids.txt API:
Gui, Add, Edit, vmainIdsURL w460 x770 y445 h20 -E0x200 Background2A2A2A cWhite, %mainIdsURL%
Gui, Add, Text, x770 y465 %sectionColor%, vip_ids.txt (GP Test Mode) API:
Gui, Add, Edit, vvipIdsURL w460 x770 y485 h20 -E0x200 Background2A2A2A cWhite, %vipIdsURL%
Gui, Add, Checkbox, % (showcaseEnabled ? "Checked" : "") " vshowcaseEnabled x770 y510 " . sectionColor, % currentDictionary.Txt_showcaseEnabled

Gui, Show, w%GUI_WIDTH% h%GUI_HEIGHT%, Classic Mode
Return

mainSettings:
  Gui, Submit, NoHide
  
  if (runMain) {
    GuiControl, Show, Mains
  }
  else {
    GuiControl, Hide, Mains
  }
return

autoUseGPTestSettings:
  Gui, Submit, NoHide
  
  if (autoUseGPTest) {
    GuiControl, Show, TestTime
  }
  else {
    GuiControl, Hide, TestTime
  }
return

; NEW: Handle drop-down changes for sort method
SortByDropdownHandler:
  Gui, Submit, NoHide
  GuiControlGet, selectedOption,, SortByDropdown
  
  ; Update injectSortMethod based on selected option
  if (selectedOption = "Oldest First")
    injectSortMethod := "ModifiedAsc"
  else if (selectedOption = "Newest First")
    injectSortMethod := "ModifiedDesc"
  else if (selectedOption = "Fewest Packs First")
    injectSortMethod := "PacksAsc"
  else if (selectedOption = "Most Packs First")
    injectSortMethod := "PacksDesc"
  
  ; Save the updated setting
  IniWrite, %injectSortMethod%, Settings.ini, UserSettings, injectSortMethod

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
  }
  else {
    GuiControl, Hide, heartBeatName
    GuiControl, Hide, heartBeatWebhookURL
    GuiControl, Hide, heartBeatDelay
    GuiControl, Hide, hbName
    GuiControl, Hide, hbURL
    GuiControl, Hide, hbDelay
  }
return

deleteSettings:
  Gui, Submit, NoHide
  if (deleteMethod = "Create Bots (13P)") {
    GuiControl, Hide, FriendID
    GuiControl, Hide, spendHourGlass
    GuiControl, Hide, packMethod
    GuiControl, Hide, openExtraPack
    GuiControl, Show, nukeAccount
  } else if (deleteMethod = "Inject Wonderpick 39P+") {
    GuiControl, Show, FriendID
    GuiControl, Show, spendHourGlass
    GuiControl, Show, packMethod
    GuiControl, Show, openExtraPack
    GuiControl, Hide, nukeAccount
    nukeAccount := false
  } else {
    GuiControl, Show, FriendID
    GuiControl, Show, spendHourGlass
    GuiControl, Hide, packMethod
    GuiControl, Hide, openExtraPack
    GuiControl, Hide, nukeAccount
    nukeAccount := false
  }
return

openExtraPackSettings:
  Gui, Submit, NoHide
  if (openExtraPack) {
    GuiControl,, spendHourGlass, 0
  }
Return

spendHourGlassSettings:
  Gui, Submit, NoHide
  if (SpendHourGlass) {
    GuiControl,, openExtraPack, 0
  }
Return

s4tSettings:
  Gui, Submit, NoHide
  if(s4tEnabled) {
    GuiControl, Show, s4tSilent
    GuiControl, Show, s4t3Dmnd
    GuiControl, Show, s4t4Dmnd
    GuiControl, Show, s4t1Star
    GuiControl, Show, s4tLine_1
    GuiControl, Show, s4tWP
    if (s4tWP) {
      GuiControl, Show, Txt_s4tWPMinCards
      GuiControl, Show, s4tWPMinCards
    }
    GuiControl, Show, s4tLine_2
    GuiControl, Show, S4TDiscordSettingsSubHeading
    GuiControl, Show, Txt_s4tDiscordUserId
    GuiControl, Show, s4tDiscordUserId
    GuiControl, Show, Txt_s4tDiscordWebhookURL
    GuiControl, Show, s4tDiscordWebhookURL
    GuiControl, Show, s4tSendAccountXml
  } else {
    GuiControl, Hide, s4tSilent
    GuiControl, Hide, s4t3Dmnd
    GuiControl, Hide, s4t4Dmnd
    GuiControl, Hide, s4t1Star
    GuiControl, Hide, s4tLine_1
    GuiControl, Hide, s4tWP
    GuiControl, Hide, Txt_s4tWPMinCards
    GuiControl, Hide, s4tWPMinCards
    GuiControl, Hide, s4tLine_2
    GuiControl, Hide, S4TDiscordSettingsSubHeading
    GuiControl, Hide, Txt_s4tDiscordUserId
    GuiControl, Hide, s4tDiscordUserId
    GuiControl, Hide, Txt_s4tDiscordWebhookURL
    GuiControl, Hide, s4tDiscordWebhookURL
    GuiControl, Hide, s4tSendAccountXml
  }
return

s4tWPSettings:
  Gui, Submit, NoHide
  if (s4tWP) {
    GuiControl, Show, Txt_s4tWPMinCards
    GuiControl, Show, s4tWPMinCards
  } else {
    GuiControl, Hide, Txt_s4tWPMinCards
    GuiControl, Hide, s4tWPMinCards
  }
return

s4tWPMinCardsCheck:
    Gui, Submit, NoHide
    GuiControlGet, s4tWPMinCards
    if (s4tWPMinCards < 1)
        s4tWPMinCards := 1
    if (s4tWPMinCards > 2)
        s4tWPMinCards := 2
    GuiControl,, s4tWPMinCards, %s4tWPMinCards%
return

defaultLangSetting:
  global scaleParam
  GuiControlGet, defaultLanguage,, defaultLanguage
  if (defaultLanguage = "Scale125")
    scaleParam := 277
  else if (defaultLanguage = "Scale100")
    scaleParam := 287
return

Save:
  Gui, Submit
  SaveAllSettings()
  Gui, Destroy
  FileAppend,, %saveSignalFile%
  Run, %A_ScriptDir%\..\..\PTCGPB.ahk
ExitApp
Return

GuiClose:
    ; Save all settings before exiting
    SaveAllSettings()
    
    ; Kill all related scripts
    KillAllScripts()
    FileAppend,, %saveSignalFile%
    Run, %A_ScriptDir%\..\..\PTCGPB.ahk
ExitApp
Return

; Add this function to kill all related scripts
KillAllScripts() {
    ; Kill Monitor.ahk if running
    Process, Exist, Monitor.ahk
    if (ErrorLevel) {
        Process, Close, %ErrorLevel%
    }
    
    ; Kill all instance scripts
    Loop, 50 { ; Assuming you won't have more than 50 instances
        scriptName := A_Index . ".ahk"
        Process, Exist, %scriptName%
        if (ErrorLevel) {
            Process, Close, %ErrorLevel%
        }
        
        ; Also check for Main scripts
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
    
    ; Close any status GUIs that might be open
    Gui, PackStatusGUI:Destroy
}