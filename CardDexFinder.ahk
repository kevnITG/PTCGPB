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

version = kevinnnn's Dex Scanner
#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

OnError("ErrorHandler")

githubUser := "kevnITG"
   ,repoName := "PTCGPB"
   ,localVersion := "v1.0"
   ,scriptFolder := A_ScriptDir
   ,zipPath := A_Temp . "\update.zip"
   ,extractPath := A_Temp . "\update"
   ,intro := "Mega Rising"

global GUI_WIDTH := 790
global GUI_HEIGHT := 320
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
      ; CheckForUpdate()
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
   Gui, Add, GroupBox, x5 y0 w240 h130 %sectionColor%, % currentDictionary.InstanceSettings
   Gui, Add, Text, x20 y25 %sectionColor%, % currentDictionary.Txt_Instances
   Gui, Add, Edit, vInstances w50 x125 y25 h20 -E0x200 Background2A2A2A cWhite Center, %Instances%
   Gui, Add, Text, x20 y50 %sectionColor%, % currentDictionary.Txt_Columns
   Gui, Add, Edit, vColumns w50 x125 y50 h20 -E0x200 Background2A2A2A cWhite Center, %Columns%
      Gui, Font, s8 cWhite, Segoe UI
   Gui, Add, Button, x185 y50 w50 h20 gArrangeWindows BackgroundTrans, % currentDictionary.btn_arrange
      Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, Text, x20 y75 %sectionColor%, % currentDictionary.Txt_InstanceStartDelay
   Gui, Add, Edit, vinstanceStartDelay w50 x125 y75 h20 -E0x200 Background2A2A2A cWhite Center, %instanceStartDelay%

   Gui, Add, Checkbox, % (runMain ? "Checked" : "") " vrunMain gmainSettings x20 y100 " . sectionColor, % currentDictionary.Txt_runMain
   Gui, Add, Edit, % "vMains w50 x125 y100 h20 -E0x200 Background2A2A2A " . sectionColor . " Center" . (runMain ? "" : " Hidden"), %Mains%

   sectionColor := "c39FF14"
   Gui, Add, GroupBox, x5 y135 w240 h80 %sectionColor%, % currentDictionary.BotSettings

   if (deleteMethod = "Create Bots (13P)")
   defaultDelete := 2
   else if (deleteMethod = "Inject 13P+")
   defaultDelete := 2
   else if (deleteMethod = "Inject Wonderpick 96P+")
   defaultDelete := 2
   ; Gui, Add, DropDownList, vdeleteMethod gdeleteSettings choose%defaultDelete% x20 y160 w200 Background2A2A2A cWhite, Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+

   Gui, Add, Text, x20 y160 %sectionColor% vSortByText, % currentDictionary.SortByText
   sortOption := 1
   if (injectSortMethod = "ModifiedDesc")
   sortOption := 2
   else if (injectSortMethod = "PacksAsc")
   sortOption := 3
   else if (injectSortMethod = "PacksDesc")
   sortOption := 4
   Gui, Add, DropDownList, vSortByDropdown gSortByDropdownHandler choose%sortOption% x20 y180 w130 Background2A2A2A cWhite, Oldest First|Newest First|Fewest Packs First|Most Packs First

   Gui, Add, Text, x20 y190 %sectionColor% vAccountNameText, % currentDictionary.Txt_AccountName
   Gui, Add, Edit, vAccountName w90 x130 y190 h20 -E0x200 Background2A2A2A cWhite Center, %AccountName%

   if (deleteMethod = "Create Bots (13P)") {
      GuiControl, Hide, SortByText
      GuiControl, Hide, SortByDropdown
   } else {
      GuiControl, Hide, AccountNameText
      GuiControl, Hide, AccountName
   }

   sectionColor := "cFFD700"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x255 y0 w180 h170 %sectionColor%, Card Selection

   ; Add checkboxes directly in the main UI (no popup)
   yPos := 25
   Gui, Add, Checkbox, % (CardSelect_ProfessorOak ? "Checked" : "") " vCardSelect_ProfessorOak x265 y" . yPos . " cWhite", Professor Oak
   yPos += 20
   Gui, Add, Checkbox, % (CardSelect_Lisia ? "Checked" : "") " disabled vCardSelect_Lisia x265 y" . yPos . " cWhite", "L̶i̶s̶i̶a̶ (disabled)"
   yPos += 20
      GuiControl, Disable, CardSelect_Lisia
   Gui, Add, Checkbox, % (CardSelect_Lusamine ? "Checked" : "") " disabled vCardSelect_Lusamine x265 y" . yPos . " cWhite", "L̶u̶s̶a̶m̶i̶n̶e̶ (disabled)"
   yPos += 20
      GuiControl, Disable, CardSelect_Lusamine

   sectionColor := "c4169E1"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x255 y175 w180 h35 %sectionColor%, Trade Tools
   
   Gui, Font, s6 cWhite, Segoe UI
   Gui, Add, Button, x275 y193 w140 h15 gOpenTradesDashboard BackgroundTrans, Open Trades Dashboard

   Gui, Font, s10 cWhite, Segoe UI
   sectionColor := "c9370DB"
   Gui, Add, GroupBox, x20 y215 w180 h100 %sectionColor%, % currentDictionary.TimeSettings
   Gui, Add, Text, x35 y240 %sectionColor%, % currentDictionary.Txt_Delay
   Gui, Add, Edit, vDelay w30 x155 y240 h20 -E0x200 Background2A2A2A cWhite Center, %Delay%
   Gui, Add, Text, x35 y265 %sectionColor%, % currentDictionary.Txt_SwipeSpeed
   Gui, Add, Edit, vswipeSpeed w30 x155 y265 h20 -E0x200 Background2A2A2A cWhite Center, %swipeSpeed%
   Gui, Add, Text, x35 y290 %sectionColor%, % currentDictionary.Txt_WaitTime
   Gui, Add, Edit, vwaitTime w30 x155 y290 h20 -E0x200 Background2A2A2A cWhite Center, %waitTime%

   sectionColor := "c00FFFF"
   Gui, Font, s10 cWhite, Segoe UI
   Gui, Add, GroupBox, x445 y0 w156 h180 %sectionColor%, % currentDictionary.HeartbeatSettingsSubHeading
   Gui, Add, Checkbox, % (heartBeat ? "Checked" : "") " vheartBeat x455 y25 gdiscordSettings " . sectionColor, % currentDictionary.Txt_heartBeat

   if(StrLen(heartBeatName) < 3)
   heartBeatName =
   if(StrLen(heartBeatWebhookURL) < 3)
   heartBeatWebhookURL =

   if (heartBeat) {
   Gui, Add, Text, vhbName x455 y45 %sectionColor%, % currentDictionary.hbName
   Gui, Add, Edit, vheartBeatName w136 x455 y65 h20 -E0x200 Background2A2A2A cWhite, %heartBeatName%
   Gui, Add, Text, vhbURL x455 y85 %sectionColor%, Webhook URL:
   Gui, Add, Edit, vheartBeatWebhookURL w136 x455 y105 h20 -E0x200 Background2A2A2A cWhite, %heartBeatWebhookURL%
   Gui, Add, Text, vhbDelay x455 y130 %sectionColor%, % currentDictionary.hbDelay
   Gui, Add, Edit, vheartBeatDelay w50 x455 y150 h20 -E0x200 Background2A2A2A cWhite Center, %heartBeatDelay%
   } else {
   Gui, Add, Text, vhbName x455 y45 Hidden %sectionColor%, % currentDictionary.hbName
   Gui, Add, Edit, vheartBeatName w136 x455 y65 h20 Hidden -E0x200 Background2A2A2A cWhite, %heartBeatName%
   Gui, Add, Text, vhbURL x455 y85 Hidden %sectionColor%, Webhook URL:
   Gui, Add, Edit, vheartBeatWebhookURL w136 x455 y105 h20 Hidden -E0x200 Background2A2A2A cWhite, %heartBeatWebhookURL%
   Gui, Add, Text, vhbDelay x455 y130 Hidden %sectionColor%, % currentDictionary.hbDelay
   Gui, Add, Edit, vheartBeatDelay w50 x455 y150 h20 Hidden -E0x200 Background2A2A2A cWhite Center, %heartBeatDelay%
   }

   Gui, Font, s10 cWhite
   Gui, Add, Picture, gOpenDiscord x455 y190 w36 h36, %A_ScriptDir%\GUI\Images\discord-icon.png
   Gui, Add, Picture, gOpenToolTip x505 y190 w36 h36, %A_ScriptDir%\GUI\Images\help-icon.png
   Gui, Add, Picture, gShowToolsAndSystemSettings x555 y192 w32 h32, %A_ScriptDir%\GUI\Images\tools-icon.png

   sectionColor := "cWhite"
   Gui, Add, GroupBox, x611 y0 w175 h260 %sectionColor%

   Gui, Font, s12 cWhite Bold
   Gui, Add, Text, x621 y20 w155 h50 Left BackgroundTrans cWhite, % "Dex Scanner"
   Gui, Font, s10 cWhite Bold
   Gui, Add, Text, x621 y20 w155 h50 Left BackgroundTrans cWhite, % "`nkevinnnn v1.0.0beta"

   Gui, Add, Picture, gBuyMeCoffee x625 y65, %A_ScriptDir%\GUI\Images\support_me_on_kofi.png

   Gui, Font, s10 cWhite Bold
   Gui, Add, Button, x621 y105 w155 h25 gBalanceXMLs BackgroundTrans, % currentDictionary.btn_balance
   Gui, Add, Button, x621 y140 w155 h40 gLaunchAllMumu BackgroundTrans, % currentDictionary.btn_mumu
   Gui, Add, Button, gSave x621 y190 w155 h40, Start Bot

   Gui, Font, s7 cGray
   Gui, Add, Text, x620 y240 w165 Center BackgroundTrans, CC BY-NC 4.0 international license

   Gui, Show, w%GUI_WIDTH% h%GUI_HEIGHT%, kevinnnn's Dex Scanner

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
    GuiControl, Hide, SortByText
    GuiControl, Hide, SortByDropdown
    GuiControl, Show, AccountNameText
    GuiControl, Show, AccountName
    GuiControl, Hide, WaitTime
  } else if (deleteMethod = "Inject Wonderpick 96P+") {
    GuiControl, Show, SortByText
    GuiControl, Show, SortByDropdown
    GuiControl, Hide, AccountNameText
    GuiControl, Hide, AccountName
    GuiControl, Show, WaitTime
  } else if (deleteMethod = "Inject 13P+") {
    GuiControl, Show, SortByText
    GuiControl, Show, SortByDropdown
    GuiControl, Hide, AccountNameText
    GuiControl, Hide, AccountName
    GuiControl, Hide, WaitTime
  }
return

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
    
    Gui, ToolsAndSystemSelect:Add, Checkbox, % (slowMotion ? "Checked" : "") " vslowMotion_Popup x" . col1X . " y" . yPos . " cWhite", No Speedmod Menu Clicks
    yPos += 35
    
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
    
    slowMotion := slowMotion_Popup
    
    SelectedMonitorIndex := SelectedMonitorIndex_Popup
    defaultLanguage := defaultLanguage_Popup
    RowGap := RowGap_Popup
    folderPath := folderPath_Popup
    ocrLanguage := ocrLanguage_Popup
    clientLanguage := clientLanguage_Popup
    instanceLaunchDelay := instanceLaunchDelay_Popup
    autoLaunchMonitor := autoLaunchMonitor_Popup
    
    Gui, ToolsAndSystemSelect:Destroy
    
    Gui, 1:Default
    
    GuiControl,, slowMotion, %slowMotion%
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

OpenTradesDashboard:
    Run, https://ptcgp-trades-dashboard.netlify.app/
return

OpenDiscord:
    Run, https://discord.gg/UQXrQbEG4r
return

OpenToolTip:
    Run, %A_ScriptDir%\GUI\Help.html
return

BuyMeCoffee:
    Run, https://ko-fi.com/arturosbot
return

ArrangeWindows:
    Run, %A_ScriptDir%\Scripts\Include\WindowArranger.ahk
return

BalanceXMLs:
    Run, %A_ScriptDir%\Scripts\Include\DistributeXMLs.ahk
return

LaunchAllMumu:
    Run, %A_ScriptDir%\Scripts\Include\LaunchMumuVMs.ahk
return

RunXMLSortTool:
    Run, %A_ScriptDir%\Scripts\Include\XMLSortTool.ahk
return

RunXMLDuplicateTool:
    Run, %A_ScriptDir%\Scripts\Include\XMLDuplicateTool.ahk
return

GuiClose:
GuiEscape:
   ExitApp
Return

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
  if (slowMotion)
    additionalSettings .= "• No Speedmod Menu Clicks`n"
  
  if (additionalSettings != "") {
    confirmMsg .= "`n" . SetUpDictionary.Confirm_AdditionalSettings . "`n" . additionalSettings
  }
  
  cardSelections := ""
  if (CardSelect_ProfessorOak)
     cardSelections .= "• Professor Oak`n"
  if (CardSelect_Lisia)
     cardSelections .= "• Lisia`n"
  if (CardSelect_Lusamine)
     cardSelections .= "• Lusamine`n"
     
  if (cardSelections != "") {
    confirmMsg .= "`nCard Selections:`n" . cardSelections
  }
  
  MsgBox, 1, % SetUpDictionary.ConfirmStart, %confirmMsg%
  
  IfMsgBox OK
  {
    StartBot()
    Gui, Destroy
  }
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
      IniRead, slowMotion, Settings.ini, UserSettings, slowMotion, 1
      
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
      nukeAccount := 0
      IniRead, spendHourGlass, Settings.ini, UserSettings, spendHourGlass, 0
      IniRead, openExtraPack, Settings.ini, UserSettings, openExtraPack, 0
      IniRead, injectSortMethod, Settings.ini, UserSettings, injectSortMethod, PacksDesc
      IniRead, godPack, Settings.ini, UserSettings, godPack, Continue
      IniRead, claimSpecialMissions, Settings.ini, UserSettings, claimSpecialMissions, 0
      IniRead, claimDailyMission, Settings.ini, UserSettings, claimDailyMission, 0
      IniRead, wonderpickForEventMissions, Settings.ini, UserSettings, wonderpickForEventMissions, 0
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
        s4tSilent := 0
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

      ; Load Card Selection settings
      IniRead, CardSelect_ProfessorOak, Settings.ini, UserSettings, CardSelect_ProfessorOak, 0
      IniRead, CardSelect_Lisia, Settings.ini, UserSettings, CardSelect_Lisia, 0
      IniRead, CardSelect_Lusamine, Settings.ini, UserSettings, CardSelect_Lusamine, 0

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
      iniContent .= "CardSelect_ProfessorOak=0`n"
      iniContent .= "CardSelect_Lisia=0`n"
      iniContent .= "CardSelect_Lusamine=0`n"
      
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
   global menuExpanded
   global claimSpecialMissions, claimDailyMission, wonderpickForEventMissions
   global checkWPthanks
   global CardSelect_ProfessorOak, CardSelect_Lisia, CardSelect_Lusamine

   if (deleteMethod != "Inject Wonderpick 96P+") {
       packMethod := false
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
   iniContent .= "minStars=" minStars "`n"
   iniContent .= "minStarsShiny=" minStarsShiny "`n"
   iniContent .= "FriendID=" FriendID "`n"
   iniContent .= "AccountName=" AccountName "`n"
   iniContent .= "waitTime=" waitTime "`n"
   iniContent .= "Delay=" Delay "`n"
   iniContent .= "folderPath=" folderPath "`n"
   iniContent .= "DiscordWebhookURL=" discordWebhookURL "`n"
   iniContent .= "DiscordUserId=" discordUserId "`n"
   iniContent .= "Columns=" Columns "`n"
   iniContent .= "godPack=" godPack "`n"
   iniContent .= "Instances=" Instances "`n"
   iniContent .= "instanceStartDelay=" instanceStartDelay "`n"
   iniContent .= "defaultLanguage=" defaultLanguage "`n"
   iniContent .= "SelectedMonitorIndex=" SelectedMonitorIndex "`n"
   iniContent .= "swipeSpeed=" swipeSpeed "`n"
   iniContent .= "Mains=" Mains "`n"
   iniContent .= "heartBeat=" heartBeat "`n"
   iniContent .= "heartBeatWebhookURL=" heartBeatWebhookURL "`n"
   iniContent .= "heartBeatName=" heartBeatName "`n"
   iniContent .= "heartBeatDelay=" heartBeatDelay "`n"
   iniContent .= "sendAccountXml=" sendAccountXml "`n"
   iniContent .= "rowGap=" rowGap "`n"
   iniContent .= "mainIdsURL=" mainIdsURL "`n"
   iniContent .= "vipIdsURL=" vipIdsURL "`n"
   iniContent .= "showcaseEnabled=" showcaseEnabled "`n"
   iniContent .= "ocrLanguage=" ocrLanguage "`n"
   iniContent .= "clientLanguage=" clientLanguage "`n"
   iniContent .= "instanceLaunchDelay=" instanceLaunchDelay "`n"
   iniContent .= "s4tEnabled=" s4tEnabled "`n"
   iniContent .= "s4tSilent=" s4tSilent "`n"
   iniContent .= "s4t3Dmnd=" s4t3Dmnd "`n"
   iniContent .= "s4t4Dmnd=" s4t4Dmnd "`n"
   iniContent .= "s4t1Star=" s4t1Star "`n"
   iniContent .= "s4tGholdengo=" s4tGholdengo "`n"
   iniContent .= "s4tWP=" s4tWP "`n"
   iniContent .= "s4tTrainer=" s4tTrainer "`n"
   iniContent .= "s4tRainbow=" s4tRainbow "`n"
   iniContent .= "s4tFullArt=" s4tFullArt "`n"
   iniContent .= "s4tCrown=" s4tCrown "`n"
   iniContent .= "s4tImmersive=" s4tImmersive "`n"
   iniContent .= "s4tShiny1Star=" s4tShiny1Star "`n"
   iniContent .= "s4tShiny2Star=" s4tShiny2Star "`n"
   iniContent .= "s4tWPMinCards=" s4tWPMinCards "`n"
   iniContent .= "s4tDiscordUserId=" s4tDiscordUserId "`n"
   iniContent .= "s4tDiscordWebhookURL=" s4tDiscordWebhookURL "`n"
   iniContent .= "s4tSendAccountXml=" s4tSendAccountXml "`n"
   iniContent .= "ocrShinedust=" ocrShinedust "`n"
   iniContent .= "deleteMethod=" deleteMethod "`n"
   iniContent .= "injectSortMethod=" injectSortMethod "`n"
   iniContent .= "tesseractPath=" tesseractPath "`n"
   iniContent .= "waitForEligibleAccounts=" waitForEligibleAccounts "`n"
   iniContent .= "maxWaitHours=" maxWaitHours "`n"
   iniContent .= "menuExpanded=" menuExpanded "`n"
   iniContent .= "groupRerollEnabled=" groupRerollEnabled "`n"
   iniContent .= "claimSpecialMissions=" claimSpecialMissions "`n"
   iniContent .= "claimDailyMission=" claimDailyMission "`n"
   iniContent .= "wonderpickForEventMissions=" wonderpickForEventMissions "`n"
   iniContent .= "checkWPthanks=" checkWPthanks "`n"
   iniContent .= "CardSelect_ProfessorOak=" CardSelect_ProfessorOak "`n"
   iniContent .= "CardSelect_Lisia=" CardSelect_Lisia "`n"
   iniContent .= "CardSelect_Lusamine=" CardSelect_Lusamine "`n"
   
   FileDelete, Settings.ini
   FileAppend, %iniContent%, Settings.ini, UTF-16
   
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
