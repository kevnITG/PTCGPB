; Improved status display function
DisplayPackStatus(Message, X := 0, Y := 625) {
   global SelectedMonitorIndex
   static GuiName := "ScreenPackStatus"
   
   ; Fixed light theme colors
   bgColor := "F0F5F9" ; Light background
   textColor := "2E3440" ; Dark text for contrast
   
   MaxRetries := 10
   RetryCount := 0
   
   try {
      ; Get monitor origin from index
      SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
      SysGet, Monitor, Monitor, %SelectedMonitorIndex%
      X := MonitorLeft + X
      
      ;Adjust Y position to be just above buttons
      Y := MonitorTop + 503 ; This is approximately where the buttons start - 30 (status height)
      
      ; Check if GUI already exists
      Gui %GuiName%:+LastFoundExist
      if (PackGuiBuild) {
         GuiControl, %GuiName%:, PackStatus, %Message%
      }
      else {
         PackGuiBuild := 1
         ; Create a new GUI with light theme styling
         OwnerWND := WinExist(1)
         Gui, %GuiName%:Destroy
         if(!OwnerWND)
            Gui, %GuiName%:New, +ToolWindow -Caption +LastFound -DPIScale +AlwaysOnTop
         else
            Gui, %GuiName%:New, +Owner%OwnerWND% +ToolWindow -Caption +LastFound -DPIScale
         Gui, %GuiName%:Color, %bgColor% ; Light background
         Gui, %GuiName%:Margin, 2, 2
         Gui, %GuiName%:Font, s8 c%textColor% ; Dark text
         Gui, %GuiName%:Add, Text, vPackStatus c%textColor%, %Message%
         ; Show the GUI without activating it
         Gui, %GuiName%:Show, NoActivate x%X% y%Y%, %GuiName%
      }
   } catch e {
      ; Silent error handling
   }
}

;OPTIMIZATIONS START
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
DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution) ;setting the Windows Timer Resolution to 0.5ms, THIS IS A GLOBAL CHANGE
;OPTIMIZATIONS END
;YOUR SCRIPT GOES HERE
DllCall("Sleep","UInt",1) ;I just slept exactly 1ms!
DllCall("ntdll\ZwDelayExecution","Int",0,"Int64*",-5000) ;you can use this to sleep in increments of 0.5ms if you need even more granularity

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

;OnError("ErrorHandler") ; Add this line here

githubUser := "kevnITG"
   ,repoName := "PTCGPB"
   ,localVersion := "v6.4.22"
   ,scriptFolder := A_ScriptDir
   ,zipPath := A_Temp . "\update.zip"
   ,extractPath := A_Temp . "\update"
   ,intro := "Wisdom of Sea and Sky"

if not A_IsAdmin
{
   ; Relaunch script with admin rights
   Run *RunAs "%A_ScriptFullPath%"
   ExitApp
}

; ========== Load Settings ==========
settingsLoaded := LoadSettingsFromIni()
if (!settingsLoaded) {
   CreateDefaultSettingsFile()
   LoadSettingsFromIni()
}
; ========== language Selection ==========
if (!IsLanguageSet) {
   ; Build language select
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
   ; Define Language Dictionary
   global LicenseDictionary, ProxyDictionary, currentDictionary, SetUpDictionary, HelpDictionary
   LicenseDictionary := CreateLicenseNoteLanguage(defaultBotLanguage)
      ,ProxyDictionary := CreateProxyLanguage(defaultBotLanguage)
      ,currentDictionary := CreateGUITextByLanguage(defaultBotLanguage, localVersion)
      ,SetUpDictionary := CreateSetUpByLanguage(defaultBotLanguage)
      ,HelpDictionary := CreateHelpByLanguage(defaultBotLanguage)
   
   ; ========== License/Proxy Notice ==========
   RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
   ; Check for debugMode and display license notification if not in debug mode
   global saveSignalFile := A_ScriptDir "\Scripts\Include\save.signal"
   if (!debugMode && !shownLicense && !FileExist(saveSignalFile)) {
      MsgBox, 64, % LicenseDictionary.Title, % LicenseDictionary.Content
      shownLicense := 1
      if (proxyEnabled)
         MsgBox, 64,, % ProxyDictionary.Notice
   }
   
   ; ========== Handle save.signal ==========
   if FileExist(saveSignalFile) {
      KillADBProcesses()
      FileDelete, %saveSignalFile%
   } else {
      KillADBProcesses()
      CheckForUpdate()
   }
   
   ; ========== Backup JSON Files ==========
   scriptName := StrReplace(A_ScriptName, ".ahk")
   winTitle := scriptName
   showStatus := true
   
   ; Backup total.json
   totalFile := A_ScriptDir . "\json\total.json"
   backupFile := A_ScriptDir . "\json\total-backup.json"
   if FileExist(totalFile) {
      FileCopy, %totalFile%, %backupFile%, 1
      if (ErrorLevel)
         MsgBox, 0x40000,, Failed to create %backupFile%. Ensure permissions and paths are correct.
      FileDelete, %totalFile%
   }
   
   ; Backup Packs.json
   packsFile := A_ScriptDir . "\json\Packs.json"
   backupFile := A_ScriptDir . "\json\Packs-backup.json"
   if FileExist(packsFile) {
      FileCopy, %packsFile%, %backupFile%, 1
      if (ErrorLevel)
         MsgBox, 0x40000,, Failed to create %backupFile%. Ensure permissions and paths are correct.
   }
   InitializeJsonFile() ; Create or open the JSON file
   ; ========== GUI Setup ==========
   global MainGuiName
   global checkedPath, uncheckedPath
   checkedPath := A_ScriptDir . "\GUI\Gui_checked.png"
   uncheckedPath := A_ScriptDir . "\GUI\Gui_unchecked.png"
   Gui,+HWNDSGUI
   if (CurrentTheme = "Dark") {
      Gui, Color, e9f1f7, 7C8590
   } else {
      Gui, Color, e9f1f7, FFD1CD
   }
   Loop, 8 {
      Gui, Add, Picture, % "x" (A_Index-1)*360 " y0 w360 h640 BackgroundTrans", %BackgroundImage%
      Gui, Add, Picture, % "x" (A_Index-1)*360 + 20 " y90 w320 h480 BackgroundTrans", %PageImage%
   }
   OD_Colors.SetItemHeight("s10", currentfont)
   ; ========== Page 1 ==========
   xPos := 45
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_reroll
   SetNormalFont()
   ;; FriendID Section
   Gui, Add, Text, x%xPos% y150 vFriendIDLabel backgroundtrans, % currentDictionary.FriendIDLabel
   if(FriendID = "ERROR" || FriendID = "") {
      Gui, Add, Edit, % "vFriendID w270 x" . xPos . " y175 h20 -E0x200 Center backgroundtrans" . (CurrentTheme = "Dark"? " cFDFDFD ": " cBC0000"),
   } else {
      Gui, Add, Edit, % "vFriendID w270 x" . xPos . " y175 h20 -E0x200 Center backgroundtrans" . (CurrentTheme = "Dark"? " cFDFDFD ": " cBC0000"), %FriendID%
   }
   
   Gui, Add, Text, x%xPos% y200 w275 h1 +0x10 ; Creates a horizontal line
   
   ;; Instance Settings Section
   Gui, Add, Text, x%xPos% y205 backgroundtrans vTxt_Instances, % currentDictionary.Txt_Instances
   Gui, Add, Edit, % "vInstances w40 x" . xPos+185 . " y205 h20 -E0x200 Center backgroundtrans" . (CurrentTheme = "Dark"? " cFDFDFD ": " cBC0000"), %Instances%
   
   Gui, Add, Text, x%xPos% y230 backgroundtrans vTxt_InstanceStartDelay, % currentDictionary.Txt_InstanceStartDelay
   Gui, Add, Edit, % "vinstanceStartDelay w40 x" . xPos+185 . " y230 h20 -E0x200 Center backgroundtrans" . (CurrentTheme = "Dark"? " cFDFDFD ": " cBC0000"), %instanceStartDelay%
   
   Gui, Add, Text, x%xPos% y255 backgroundtrans vTxt_Columns, % currentDictionary.Txt_Columns
   Gui, Add, Edit, % "vColumns w40 x" . xPos+185 . " y255 h20 -E0x200 Center backgroundtrans" . (CurrentTheme = "Dark"? " cFDFDFD ": " cBC0000"), %Columns%
   global Txt_runMain
   CheckOptions := Object()
      ,CheckOptions["x"] := xPos,CheckOptions["y"] := 282,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "runMain"
      ,CheckOptions["gName"] := "runMainSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := runMain
      ,CheckOptions["vTextName"] := "Txt_runMain"
      ,CheckOptions["text"] := currentDictionary.Txt_runMain
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 280
   AddCheckBox(CheckOptions)
   Gui, Add, Edit, % "vMains w40 x" . xPos+185 . " y280 h20 -E0x200 Center backgroundtrans" . (runMain ? "" : " Hidden") . (CurrentTheme = "Dark"? " cFDFDFD ": " cBC0000"), %Mains%
   global Txt_autoUseGPTest
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 306,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "autoUseGPTest"
      ,CheckOptions["gName"] := "autoUseGPTestSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := autoUseGPTest
      ,CheckOptions["vTextName"] := "Txt_autoUseGPTest"
      ,CheckOptions["text"] := currentDictionary.Txt_autoUseGPTest
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 305
   AddCheckBox(CheckOptions)
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vTestTime w40 x" . xPos+185 . " y305 h20 -E0x200 Center backgroundtrans" . (autoUseGPTest ? "" : " Hidden"), %TestTime%
   Gui, Add, Text, x%xPos% y330 backgroundtrans vTxt_AccountName, % currentDictionary.Txt_AccountName
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vAccountName w85 x" . xPos+185 . " y330 h20 -E0x200 Center backgroundtrans", %AccountName%
   
   Gui, Add, Text, x%xPos% y355 w275 h1 +0x10 ; Creates a horizontal line
   
   ;; Time Settings Section
   Gui, Add, Text, x%xPos% y360 backgroundtrans vTxt_Delay, % currentDictionary.Txt_Delay
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vDelay w40 x" . xPos+185 . " y360 h20 -E0x200 Center backgroundtrans", %Delay%
   Gui, Add, Text, x%xPos% y385 backgroundtrans vTxt_WaitTime, % currentDictionary.Txt_WaitTime
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vwaitTime w40 x" . xPos+185 . " y385 h20 -E0x200 Center backgroundtrans", %waitTime%
   
   Gui, Add, Text, x%xPos% y410 backgroundtrans vTxt_SwipeSpeed, % currentDictionary.Txt_SwipeSpeed
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vswipeSpeed w40 x" . xPos+185 . " y410 h20 -E0x200 Center backgroundtrans", %swipeSpeed%
   global Txt_slowMotion
   CheckOptions := {}
   CheckOptions["x"] := xPos ,CheckOptions["y"] := 436,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "slowMotion"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := slowMotion
      ,CheckOptions["vTextName"] := "Txt_slowMotion"
      ,CheckOptions["text"] := currentDictionary.Txt_slowMotion
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 435
   AddCheckBox(CheckOptions)
   
   ; ========== Page 2 ==========
   xPos := 405
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_system
   ;; System Settings Section
   SetNormalFont()
   SysGet, MonitorCount, MonitorCount
   MonitorOptions := ""
   Loop, %MonitorCount% {
      SysGet, MonitorName, MonitorName, %A_Index%
      SysGet, Monitor, Monitor, %A_Index%
      MonitorOptions .= (A_Index > 1 ? "|" : "") "" A_Index ": (" MonitorRight - MonitorLeft "x" MonitorBottom - MonitorTop ")"
   }
   SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
   Gui, Add, Text, x%xPos% y150 backgroundtrans vTxt_Monitor, % currentDictionary.Txt_Monitor
   Gui, Add, DropDownList, % "x" . xPos+145 . " y146 w140 vSelectedMonitorIndex hwndMoitor +0x0210 Choose" . SelectedMonitorIndex . " -E0x200 Center BackgroundTrans", %MonitorOptions%
   Gui, Add, Text, x%xPos% y200 backgroundtrans vTxt_Scale, % currentDictionary.Txt_Scale
   if (defaultLanguage = "Scale125") {
      defaultLang := 1
      scaleParam := 277
   } else if (defaultLanguage = "Scale100") {
      defaultLang := 2
      scaleParam := 287
   }
   
   Gui, Add, DropDownList, % "x" . xPos+145 . " y197 w80 vdefaultLanguage hwndScale gdefaultLangSetting +0x0210 choose" . defaultLang . " -E0x200 Center backgroundtrans", Scale125
   Gui, Add, Text, x%xPos% y225 backgroundtrans vTxt_RowGap, % currentDictionary.Txt_RowGap
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vRowGap w80 x" . xPos+145 . " y223 h20 -E0x200 Center backgroundtrans", %RowGap%
   Gui, Add, Text, x%xPos% y175 backgroundtrans vTxt_FolderPath, % currentDictionary.Txt_FolderPath
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vfolderPath w140 x" . xPos+145 . " y173 h20 -E0x200 Center backgroundtrans", %folderPath%
   Gui, Add, Text, x%xPos% y250 backgroundtrans vTxt_OcrLanguage, % currentDictionary.Txt_OcrLanguage
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
   
   Gui, Add, DropDownList, % "x" . xPos+145 . " y247 w80 vocrLanguage hwndOCR +0x0210 choose" . defaultOcrLang . " -E0x200 Center backgroundtrans", %ocrLanguageList%
   
   Gui, Add, Text, x%xPos% y275 backgroundtrans vTxt_ClientLanguage, % currentDictionary.Txt_ClientLanguage
   
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
   Gui, Add, DropDownList, % "x" . xPos+145 . " y273 w80 vclientLanguage hwndClient +0x0210 choose" . defaultClientLang . " -E0x200 Center backgroundtrans", %clientLanguageList%
   
   Gui, Add, Text, x%xPos% y300 backgroundtrans vTxt_InstanceLaunchDelay, % currentDictionary.Txt_InstanceLaunchDelay
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vinstanceLaunchDelay w80 x" . xPos+145 . " y300 h20 -E0x200 Center backgroundtrans", %instanceLaunchDelay%
   global Txt_autoLaunchMonitor
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 326,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "autoLaunchMonitor"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := autoLaunchMonitor
      ,CheckOptions["vTextName"] := "Txt_autoLaunchMonitor"
      ,CheckOptions["text"] := currentDictionary.Txt_autoLaunchMonitor
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 325
   AddCheckBox(CheckOptions)
   Gui, Add, Text, x%xPos% y350 w275 h1 +0x10 ; Creates a horizontal line
   SetSectionFont()
   Gui, Add, Text, x%xPos% y355 backgroundtrans vExtraSettingsHeading, % currentDictionary.ExtraSettingsHeading
   SetNormalFont()
   ; ========= Extra Settings Section =========
   global Txt_applyRoleFilters, Txt_debugMode, Txt_useTesseract, Txt_statusMessage
   ; First add Role-Based Filters
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 381,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "applyRoleFilters"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := applyRoleFilters
      ,CheckOptions["vTextName"] := "Txt_applyRoleFilters"
      ,CheckOptions["text"] := currentDictionary.Txt_applyRoleFilters
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 380
   AddCheckBox(CheckOptions)
   
   ; Then add Debug Mode
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 406,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "debugMode"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := debugMode
      ,CheckOptions["vTextName"] := "Txt_debugMode"
      ,CheckOptions["text"] := currentDictionary.Txt_debugMode
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 405
   AddCheckBox(CheckOptions)
   
   ; Then add the Use Tesseract checkbox
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 431,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "useTesseract"
      ,CheckOptions["gName"] := "useTesseractSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := useTesseract
      ,CheckOptions["vTextName"] := "Txt_useTesseract"
      ,CheckOptions["text"] := currentDictionary.Txt_tesseractOption
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 430
   AddCheckBox(CheckOptions)
   
   ; Then add status messages
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 456,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "statusMessage"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := statusMessage
      ,CheckOptions["vTextName"] := "Txt_statusMessage"
      ,CheckOptions["text"] := currentDictionary.Txt_statusMessage
      ,CheckOptions["textX"] := xPos+35,CheckOptions["textY"] := 455
   AddCheckBox(CheckOptions)
   
   ; Keep Tesseract Path at the end
   Gui, Add, Text, % "x" . xPos . " y480 backgroundtrans vTxt_TesseractPath" . (useTesseract ? "" : " Hidden"), % currentDictionary.Txt_TesseractPath
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vtesseractPath w280 x" . xPos . " y505 h20 -E0x200 backgroundtrans" . (useTesseract ? "" : " Hidden"), %tesseractPath%
   
   ; ========== Page 3 ==========
   ; ========== Delete Method ==========
   xPos := 765
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_pack
   ; Create Sort By label and dropdown
   SetNormalFont()
   Gui, Add, Text, % "x" . xPos . " y150 backgroundtrans vTxt_DeleteMethod", % currentDictionary.Txt_DeleteMethod
   defaultDelete := 1 ; Default to first option (13 Pack)
   if (deleteMethod = "13 Pack")
      defaultDelete := 1
   else if (deleteMethod = "Inject")
      defaultDelete := 2
   else if (deleteMethod = "Inject Missions")
      defaultDelete := 3
   else if (deleteMethod = "Inject for Reroll")
      defaultDelete := 4
   Gui, Add, DropDownList, % "x" . xPos+65 . " y148 w120 vdeleteMethod gdeleteSettings hwndMethod +0x0210 choose" . defaultDelete . " -E0x200 backgroundtrans", 13 Pack|Inject|Inject Missions|Inject for Reroll
   ; Apply the correct selection
   GuiControl, Choose, deleteMethod, %defaultDelete%
   global Txt_packMethod, Txt_nukeAccount, Txt_spendHourGlass, Txt_openExtraPack
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 182,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "packMethod"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := deleteMethodEnabled
      ,CheckOptions["vTextName"] := "Txt_packMethod"
      ,CheckOptions["text"] := currentDictionary.Txt_packMethod
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 181
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos+155,CheckOptions["y"] := 182,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "nukeAccount"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := nukeAccount
      ,CheckOptions["vTextName"] := "Txt_nukeAccount"
      ,CheckOptions["text"] := currentDictionary.Txt_nukeAccount
      ,CheckOptions["textX"] := xPos+190
      ,CheckOptions["textY"] := 181
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 212,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "spendHourGlass"
      ,CheckOptions["gName"] := "spendHourGlassSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := spendHourGlass
      ,CheckOptions["vTextName"] := "Txt_spendHourGlass"
      ,CheckOptions["text"] := currentDictionary.Txt_spendHourGlass
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 211
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos+155,CheckOptions["y"] := 212,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "openExtraPack"
      ,CheckOptions["gName"] := "openExtraPackSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := openExtraPack
      ,CheckOptions["vTextName"] := "Txt_openExtraPack"
      ,CheckOptions["text"] := currentDictionary.Txt_openExtraPack
      ,CheckOptions["textX"] := xPos+190
      ,CheckOptions["textY"] := 211
   AddCheckBox(CheckOptions)
   
   ; Determine which option to pre-select
   sortOption := 1 ; Default (ModifiedAsc)
   if (injectSortMethod = "ModifiedDesc")
      sortOption := 2
   else if (injectSortMethod = "PacksAsc")
      sortOption := 3
   else if (injectSortMethod = "PacksDesc")
      sortOption := 4
   
   Gui, Add, Text, x%xPos% y242 vSortByText BackgroundTrans, % currentDictionary.SortByText
   Gui, Add, DropDownList, % "x" . xPos+110 . " y240 w120 vSortByDropdown gSortByDropdownHandler hwndSortby +0x0210 Choose" . sortOption . " BackgroundTrans", Oldest First|Newest First|Fewest Packs First|Most Packs First
   if (deleteMethod != "Inject for Reroll") {
      GuiControl, Hide, packMethod
      GuiControl, Hide, Txt_packMethod
      GuiControl, Hide, openExtraPack
      GuiControl, Hide, Txt_openExtraPack
   }
   
   if (deleteMethod != "13 Pack") {
      GuiControl, Hide, nukeAccount
      GuiControl, Hide, Txt_nukeAccount
   } else {
      GuiControl, Hide, spendHourGlass
      GuiControl, Hide, Txt_spendHourGlass
      GuiControl, Hide, SortByText
      GuiControl, Hide, SortByDropdown
   }
   
   ; Add divider for God Pack Settings section
   Gui, Add, Text, x%xPos% y271 w275 h1 +0x10 BackgroundTrans ; Creates a horizontal line
   ; === Card Detection Subsection ===
   SetNormalFont()
   global Txt_FullArtCheck, Txt_TrainerCheck, Txt_RainbowCheck, Txt_PseudoGodPack, Txt_CheckShinyPackOnly,
   global Txt_CrownCheck, Txt_ShinyCheck, Txt_ImmersiveCheck, Txt_invalidCheck,
   ; 2-Column Layout for Card Detection Subsection
   CheckOptions := {}
   CheckOptions["x"] :=xPos,CheckOptions["y"] := 281,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "FullArtCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := FullArtCheck
      ,CheckOptions["vTextName"] := "Txt_FullArtCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_FullArtCheck
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 280
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 306,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "TrainerCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := TrainerCheck
      ,CheckOptions["vTextName"] := "Txt_TrainerCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_TrainerCheck
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 305
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 331,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "RainbowCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := RainbowCheck
      ,CheckOptions["vTextName"] := "Txt_RainbowCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_RainbowCheck
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 330
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 356,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "PseudoGodPack"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := PseudoGodPack
      ,CheckOptions["vTextName"] := "Txt_PseudoGodPack"
      ,CheckOptions["text"] := currentDictionary.Txt_PseudoGodPack
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 355
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 381,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "CheckShinyPackOnly"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := CheckShinyPackOnly
      ,CheckOptions["vTextName"] := "Txt_CheckShinyPackOnly"
      ,CheckOptions["text"] := currentDictionary.Txt_CheckShinyPackOnly
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 380
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos+155,CheckOptions["y"] := 281,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "CrownCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := CrownCheck
      ,CheckOptions["vTextName"] := "Txt_CrownCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_CrownCheck
      ,CheckOptions["textX"] := xPos+190
      ,CheckOptions["textY"] := 280
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos+155,CheckOptions["y"] := 306,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "ShinyCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := ShinyCheck
      ,CheckOptions["vTextName"] := "Txt_ShinyCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_ShinyCheck
      ,CheckOptions["textX"] := xPos+190
      ,CheckOptions["textY"] := 305
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos+155,CheckOptions["y"] := 331,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "ImmersiveCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := ImmersiveCheck
      ,CheckOptions["vTextName"] := "Txt_ImmersiveCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_ImmersiveCheck
      ,CheckOptions["textX"] := xPos+190
      ,CheckOptions["textY"] := 330
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 406,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "InvalidCheck"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := InvalidCheck
      ,CheckOptions["vTextName"] := "Txt_InvalidCheck"
      ,CheckOptions["text"] := currentDictionary.Txt_InvalidCheck
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 405
   AddCheckBox(CheckOptions)
   ; ========== Page 4 ==========
; ========== Pack Selection ==========
xPos := 1125
SetHeaderFont()
Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_pack
global Txt_HoOh, Txt_Lugia, Txt_Eevee,Txt_Buzzwole, Txt_Solgaleo, Txt_Lunala, Txt_Shining, Txt_Arceus, Txt_Palkia, Txt_Dialga
global Txt_Mewtwo, Txt_Charizard, Txt_Pikachu, Txt_Mew
SetNormalFont()

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 151,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "HoOh"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := HoOh
   ,CheckOptions["vTextName"] := "Txt_HoOh"
   ,CheckOptions["text"] := currentDictionary.Txt_HoOh
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 150
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 151,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Lugia"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Lugia
   ,CheckOptions["vTextName"] := "Txt_Lugia"
   ,CheckOptions["text"] := currentDictionary.Txt_Lugia
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 150
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 176,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Eevee"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Eevee
   ,CheckOptions["vTextName"] := "Txt_Eevee"
   ,CheckOptions["text"] := currentDictionary.Txt_Eevee
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 175
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 176,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Buzzwole"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Buzzwole
   ,CheckOptions["vTextName"] := "Txt_Buzzwole"
   ,CheckOptions["text"] := currentDictionary.Txt_Buzzwole
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 175
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 201,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Solgaleo"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Solgaleo
   ,CheckOptions["vTextName"] := "Txt_Solgaleo"
   ,CheckOptions["text"] := currentDictionary.Txt_Solgaleo
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 200
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 201,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Lunala"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Lunala
   ,CheckOptions["vTextName"] := "Txt_Lunala"
   ,CheckOptions["text"] := currentDictionary.Txt_Lunala
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 200
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 226,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Shining"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Shining
   ,CheckOptions["vTextName"] := "Txt_Shining"
   ,CheckOptions["text"] := currentDictionary.Txt_Shining
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 225
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 226,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Arceus"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Arceus
   ,CheckOptions["vTextName"] := "Txt_Arceus"
   ,CheckOptions["text"] := currentDictionary.Txt_Arceus
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 225
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 251,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Palkia"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Palkia
   ,CheckOptions["vTextName"] := "Txt_Palkia"
   ,CheckOptions["text"] := currentDictionary.Txt_Palkia
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 250
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 251,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Dialga"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Dialga
   ,CheckOptions["vTextName"] := "Txt_Dialga"
   ,CheckOptions["text"] := currentDictionary.Txt_Dialga
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 250
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 276,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Pikachu"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Pikachu
   ,CheckOptions["vTextName"] := "Txt_Pikachu"
   ,CheckOptions["text"] := currentDictionary.Txt_Pikachu
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 275
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 276,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Charizard"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Charizard
   ,CheckOptions["vTextName"] := "Txt_Charizard"
   ,CheckOptions["text"] := currentDictionary.Txt_Charizard
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 275
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos,CheckOptions["y"] := 301,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Mewtwo"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Mewtwo
   ,CheckOptions["vTextName"] := "Txt_Mewtwo"
   ,CheckOptions["text"] := currentDictionary.Txt_Mewtwo
   ,CheckOptions["textX"] := xPos+35
   ,CheckOptions["textY"] := 300
AddCheckBox(CheckOptions)

CheckOptions := {}
CheckOptions["x"] := xPos+155,CheckOptions["y"] := 301,CheckOptions["w"] := 28,CheckOptions["h"] := 13
   ,CheckOptions["vName"] := "Mew"
   ,CheckOptions["gName"] := ""
   ,CheckOptions["checkedImagePath"] := checkedPath
   ,CheckOptions["uncheckedImagePath"] := uncheckedPath
   ,CheckOptions["isChecked"] := Mew
   ,CheckOptions["vTextName"] := "Txt_Mew"
   ,CheckOptions["text"] := currentDictionary.Txt_Mew
   ,CheckOptions["textX"] := xPos+190
   ,CheckOptions["textY"] := 300
AddCheckBox(CheckOptions)

   ; ========== Page 5 ==========
   ; ========== Min Stars ==========
   xPos := 1485
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_pack
   SetNormalFont()
   Gui, Add, Text, x%xPos% y150 backgroundtrans vTxt_MinStars, % currentDictionary.Txt_MinStars
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vminStars w40 x" . xPos+120 . " y149 h20 -E0x200 Center backgroundtrans", %minStars%
   
   Gui, Add, Text, x%xPos% y175 backgroundtrans vTxt_ShinyMinStars, % currentDictionary.Txt_ShinyMinStars
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vminStarsShiny w40 x" . xPos+120 . " y174 h20 -E0x200 Center backgroundtrans", %minStarsShiny%
   global Txt_minStarsEnabled
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 200, CheckOptions["w"] := 28, CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "minStarsEnabled"
      ,CheckOptions["gName"] := "minStarsEnabledSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath, CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := minStarsEnabled
      ,CheckOptions["vTextName"] := "Txt_minStarsEnabled"
      ,CheckOptions["text"] := currentDictionary.Txt_minStarsEnabled
      ,CheckOptions["textX"] := xPos+35, CheckOptions["textY"] := 199
   AddCheckBox(CheckOptions)
   Gui, Add, Text, % "x" . xPos . " y225 vTxt_minStarsA4HoOh BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_HoOh
   defaultStars := MinStarCheck("minStarsA4HoOh")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y225 w40 vminStarsA4HoOh hwndMinA4HoOh +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5
   
   Gui, Add, Text, % "x" . xPos+155 . " y225 vTxt_minStarsA4Lugia BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Lugia
   defaultStars := MinStarCheck("minStarsA4Lugia")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y225 w40 vminStarsA4Lugia hwndMinA4Lugia +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos . " y250 vTxt_minStarsA3b BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Eevee
   defaultStars := MinStarCheck("minStarsA3b")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y250 w40 vminStarsA3b hwndMinA3b +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos+155 . " y250 vTxt_minStarsA3a BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Buzzwole
   defaultStars := MinStarCheck("minStarsA3a")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y250 w40 vminStarsA3a hwndMinA3a +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos . " y275 vTxt_minStarsA3Solgaleo BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Solgaleo
   defaultStars := MinStarCheck("minStarsA3Solgaleo")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y275 w40 vminStarsA3Solgaleo hwndMinA3S +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos+155 . " y275 vTxt_minStarsA3Lunala BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Lunala
   defaultStars := MinStarCheck("minStarsA3Lunala")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y275 w40 vminStarsA3Lunala hwndMinA3L +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos . " y300 vTxt_minStarsA2b BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Shining
   defaultStars := MinStarCheck("minStarsA2b")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y300 w40 vminStarsA2b hwndMinA2b +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos+155 . " y300 vTxt_minStarsA2a BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Arceus
   defaultStars := MinStarCheck("minStarsA2a")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y300 w40 vminStarsA2a hwndMinA2a +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos . " y325 vTxt_minStarsA2Dialga BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Dialga
   defaultStars := MinStarCheck("minStarsA2Dialga")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y325 w40 vminStarsA2Dialga hwndMinA2D +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos+155 . " y325 vTxt_minStarsA2Palkia BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Palkia
   defaultStars := MinStarCheck("minStarsA2Palkia")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y325 w40 vminStarsA2Palkia hwndMinA2P +0x0210 choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos . " y350 vTxt_minStarsA1Mewtwo BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Mewtwo
   defaultStars := MinStarCheck("minStarsA1Mewtwo")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y350 w40 vminStarsA1Mewtwo +0x0210 hwndMinA1MT choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos+155 . " y350 vTxt_minStarsA1Charizard BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Charizard
   defaultStars := MinStarCheck("minStarsA1Charizard")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y350 w40 vminStarsA1Charizard +0x0210 hwndMinA1C choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos . " y375 vTxt_minStarsA1Pikachu BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Pikachu
   defaultStars := MinStarCheck("minStarsA1Pikachu")
   Gui, Add, DropDownList, % "x" . xPos+90 . " y375 w40 vminStarsA1Pikachu +0x0210 hwndMinA1P choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5

   Gui, Add, Text, % "x" . xPos+155 . " y375 vTxt_minStarsA1a BackgroundTrans" . (minStarsEnabled ? "" : " Hidden"), % currentDictionary.Txt_Mew
   defaultStars := MinStarCheck("minStarsA1a")
   Gui, Add, DropDownList, % "x" . xPos+245 . " y375 w40 vminStarsA1a +0x0210 hwndMinA1M choose" . defaultStars . " -E0x200 Center backgroundtrans" . (minStarsEnabled ? "" : " Hidden"), 0|1|2|3|4|5 

   ; ========== Page 6 ==========
   ;; Save For Trade Section
   xPos := 1845
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_save
   SetNormalFont()
   global Txt_s4tEnabled, Txt_s4tSilent, Txt_s4t3Dmnd, Txt_s4t4Dmnd, Txt_s4t1Star, s4tGholdengoArrow
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 151,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4tEnabled"
      ,CheckOptions["gName"] := "s4tSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4tEnabled
      ,CheckOptions["vTextName"] := "Txt_s4tEnabled"
      ,CheckOptions["text"] := currentDictionary.Txt_s4tEnabled
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 150
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 181,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4tSilent"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4tSilent
      ,CheckOptions["vTextName"] := "Txt_s4tSilent"
      ,CheckOptions["text"] := currentDictionary.Txt_s4tSilent
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 180
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 206,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4t3Dmnd"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4t3Dmnd
      ,CheckOptions["vTextName"] := "Txt_s4t3Dmnd"
      ,CheckOptions["text"] := "3 ◆◆◆"
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 205
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 231,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4t4Dmnd"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4t4Dmnd
      ,CheckOptions["vTextName"] := "Txt_s4t4Dmnd"
      ,CheckOptions["text"] := "4 ◆◆◆◆"
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 230
   AddCheckBox(CheckOptions)
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 256,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4t1Star"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4t1Star
      ,CheckOptions["vTextName"] := "Txt_s4t1Star"
      ,CheckOptions["text"] := "1 ★"
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 255
   AddCheckBox(CheckOptions)
   
   Gui, Add, Text, % "x" . xPos . " y280 w275 h1 vS4T_Divider1 +0x10 BackgroundTrans" . (!s4tEnabled ? " Hidden" : "") ; Creates a horizontal line
   
   CheckOptions := {}
   CheckOptions["x"] := xPos+140,CheckOptions["y"] := 181,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4tGholdengo"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4tGholdengo
      ,CheckOptions["vTextName"] := "s4tGholdengoArrow"
      ,CheckOptions["text"] := "➤"
      ,CheckOptions["textX"] := xPos+175
      ,CheckOptions["textY"] := 180
      if (!s4tEnabled || !Shining)
         CheckOptions["extraOptions"] := " Hidden"
      AddCheckBox(CheckOptions)
      Gui, Add, Picture, % (!s4tEnabled ? "Hidden " : "") . "vs4tGholdengoEmblem w25 h25 x" . xPos+195 . " y175 backgroundtrans", % A_ScriptDir . "\GUI\Images\GholdengoEmblem.png"
 
   global Txt_s4tWP
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 286,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4tWP"
      ,CheckOptions["gName"] := "s4tWPSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4tWP
      ,CheckOptions["vTextName"] := "Txt_s4tWP"
      ,CheckOptions["text"] := currentDictionary.Txt_s4tWP
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 285
   AddCheckBox(CheckOptions)
   
   Gui, Add, Text, % "vs4tWPMinCardsLabel x" . xPos . " y310 BackgroundTrans" . (!s4tEnabled || !s4tWP ? " Hidden " : ""), % currentDictionary.Txt_s4tWPMinCards
   Gui, Add, DropDownList, % "vs4tWPMinCards x" . xPos+120 . " y307 w40 hwnds4tMin +0x0210 choose" . (s4tWPMinCards=2?2:1) . " -E0x200 Center backgroundtrans" . (!s4tEnabled || !s4tWP ? " Hidden" : ""), 1|2
   
   Gui, Add, Text, % "x" . xPos . " y335 w275 h1 vS4T_Divider2 +0x10 BackgroundTrans" . (!s4tEnabled ? " Hidden" : "") ; Creates a horizontal line
   ; === S4T Discord Settings (now part of Save For Trade) ===
   SetSectionFont()
   Gui, Add, Text, % "x" . xPos . " y340 backgroundtrans vS4TDiscordSettingsSubHeading" . (!s4tEnabled? " Hidden" : ""), % currentDictionary.S4TDiscordSettingsSubHeading
   
   SetNormalFont()
   if(StrLen(s4tDiscordUserId) < 3)
      s4tDiscordUserId =
   if(StrLen(s4tDiscordWebhookURL) < 3)
      s4tDiscordWebhookURL =
   
   Gui, Add, Text, % "x" . xPos . " y365 backgroundtrans vTxt_S4T_DiscordID" . (!s4tEnabled ? " Hidden" : ""), Discord ID:
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vs4tDiscordUserId w220 x" . xPos . " y390 h20 -E0x200 Center backgroundtrans" . (!s4tEnabled ? " Hidden" : ""), %s4tDiscordUserId%
   Gui, Add, Text, % "x" . xPos . " y415 backgroundtrans vTxt_S4T_DiscordWebhook" . (!s4tEnabled ? " Hidden" : ""), Webhook URL:
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vs4tDiscordWebhookURL w220 x" . xPos . " y440 h20 -E0x200 Center backgroundtrans" . (!s4tEnabled ? " Hidden" : ""), %s4tDiscordWebhookURL%
   global Txt_s4tSendAccountXml
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 466,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "s4tSendAccountXml"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := s4tSendAccountXml
      ,CheckOptions["vTextName"] := "Txt_s4tSendAccountXml"
      ,CheckOptions["text"] := currentDictionary.Txt_s4tSendAccountXml
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 465
   AddCheckBox(CheckOptions)

   if (s4tEnabled) {
   ShowControls(s4tMainControls)
   ; Gholdengo show/hide
      if (Shining) {
         ShowControls("s4tGholdengo,s4tGholdengoEmblem,s4tGholdengoArrow")
      } else {
         HideControls("s4tGholdengo,s4tGholdengoEmblem,s4tGholdengoArrow")
      }
   ; s4tWP show/hide
      if (s4tWP) {
         ShowControls("s4tWPMinCardsLabel,s4tWPMinCards")
      } else {
         HideControls("s4tWPMinCardsLabel,s4tWPMinCards")
      }
   }
   
   if (!s4tEnabled) {
      GuiControl, Hide, s4tSilent
      GuiControl, Hide, Txt_s4tSilent
      GuiControl, Hide, s4t3Dmnd
      GuiControl, Hide, Txt_s4t3Dmnd
      GuiControl, Hide, s4t4Dmnd
      GuiControl, Hide, Txt_s4t4Dmnd
      GuiControl, Hide, s4t1Star
      GuiControl, Hide, Txt_s4t1Star
      GuiControl, Hide, s4tGholdengo
      GuiControl, Hide, s4tGholdengoArrow
      GuiControl, Hide, s4tWP
      GuiControl, Hide, Txt_s4tWP
      GuiControl, Hide, s4tSendAccountXml
      GuiControl, Hide, Txt_s4tSendAccountXml
   }
   ; ========== Page 7 ==========
   xPos := 2205
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, Discord && HeartBeat Settings
   ;; Discord Settings Section
   ; Add main heading for Discord Settings section
   SetSectionFont()
   Gui, Add, Text, x%xPos% y150 backgroundtrans vDiscordSettingsHeading, % currentDictionary.DiscordSettingsHeading
   
   SetNormalFont()
   if(StrLen(discordUserID) < 3)
      discordUserID := ""
   if(StrLen(discordWebhookURL) < 3)
      discordWebhookURL := ""
   
   Gui, Add, Text, x%xPos% y175 backgroundtrans vTxt_DiscordID, Discord ID:
   if(discordUserId = "" || discordUserId = "ERROR")
      Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vdiscordUserId w270 x" . xPos . " y200 h20 -E0x200 Center backgroundtrans",
   else
      Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vdiscordUserId w270 x" . xPos . " y200 h20 -E0x200 Center backgroundtrans", %discordUserId%
   
   Gui, Add, Text, x%xPos% y225 backgroundtrans vTxt_DiscordWebhook, Webhook URL:
   if(discordWebhookURL = "" || discordWebhookURL = "ERROR")
      Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vdiscordWebhookURL w270 x" . xPos . " y250 h20 -E0x200 Center backgroundtrans",
   else
      Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vdiscordWebhookURL w270 x" . xPos . " y250 h20 -E0x200 Center backgroundtrans", %discordWebhookURL%
   global Txt_sendAccountXml
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 276,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "sendAccountXml"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := sendAccountXml
      ,CheckOptions["vTextName"] := "Txt_sendAccountXml"
      ,CheckOptions["text"] := currentDictionary.Txt_sendAccountXml
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 275
   AddCheckBox(CheckOptions)
   
   ; Add divider after heading
   Gui, Add, Text, x%xPos% y300 w275 h1 vDiscordSettingsDivider +0x10 BackgroundTrans ; Creates a horizontal line
   ; === Heartbeat Settings (now part of Discord) ===
   SetSectionFont()
   Gui, Add, Text, x%xPos% y305 backgroundtrans vHeartbeatSettingsSubHeading, % currentDictionary.HeartbeatSettingsSubHeading
   
   SetNormalFont()
   global Txt_heartBeat
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 331,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "heartBeat"
      ,CheckOptions["gName"] := "discordSettings"
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := heartBeat
      ,CheckOptions["vTextName"] := "Txt_heartBeat"
      ,CheckOptions["text"] := currentDictionary.Txt_heartBeat
      ,CheckOptions["textX"] := xPos+35
      ,CheckOptions["textY"] := 330
   AddCheckBox(CheckOptions)
   
   if(StrLen(heartBeatName) < 3)
      heartBeatName := ""
   if(StrLen(heartBeatWebhookURL) < 3)
      heartBeatWebhookURL := ""
   
   Gui, Add, Text, % "vhbName x" . xPos . " y355 backgroundtrans" . (heartBeat?"":" Hidden"), % currentDictionary.hbName
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vheartBeatName w270 x" . xPos . " y380 h20 -E0x200 Center backgroundtrans" . (heartBeat?"":" Hidden"), %heartBeatName%
   Gui, Add, Text, % "vhbURL x" . xPos . " y405 backgroundtrans" . (heartBeat?"":" Hidden"), Webhook URL:
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vheartBeatWebhookURL w270 x" . xPos . " y430 h20 -E0x200 Center backgroundtrans" . (heartBeat?"":" Hidden"), %heartBeatWebhookURL%
   Gui, Add, Text, % "vhbDelay x" . xPos . " y455 backgroundtrans" . (heartBeat?"":" Hidden"), % currentDictionary.hbDelay
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vheartBeatDelay w40 x" . xPos+175 . " y454 h20 -E0x200 Center backgroundtrans" . (heartBeat?"":" Hidden"), %heartBeatDelay%
   ; =========== Page 8 ===========
   xPos := 2565
   SetHeaderFont()
   Gui, Add, Text, x%xPos% y110 backgroundtrans, % currentDictionary.btn_download
   ;; Download Settings Section
   SetNormalFont()
   if(StrLen(mainIdsURL) < 3)
      mainIdsURL := ""
   if(StrLen(vipIdsURL) < 3)
      vipIdsURL := ""
   
   Gui, Add, Text, x%xPos% y150 backgroundtrans vTxt_MainIdsURL, ids.txt API:
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vmainIdsURL w270 x" . xPos . " y175 h20 -E0x200 Center backgroundtrans", %mainIdsURL%
   
   Gui, Add, Text, x%xPos% y200 backgroundtrans vTxt_VipIdsURL, vip_ids.txt API:
   Gui, Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "vvipIdsURL w270 x" . xPos . " y225 h20 -E0x200 Center backgroundtrans", %vipIdsURL%
   
   ; Add Showcase options to Download Settings Section
   global Txt_showcaseEnabled
   CheckOptions := {}
   CheckOptions["x"] := xPos,CheckOptions["y"] := 251,CheckOptions["w"] := 28,CheckOptions["h"] := 13
      ,CheckOptions["vName"] := "showcaseEnabled"
      ,CheckOptions["gName"] := ""
      ,CheckOptions["checkedImagePath"] := checkedPath
      ,CheckOptions["uncheckedImagePath"] := uncheckedPath
      ,CheckOptions["isChecked"] := showcaseEnabled
      ,CheckOptions["vTextName"] := "Txt_showcaseEnabled"
      ,CheckOptions["text"] := currentDictionary.Txt_showcaseEnabled
      ,CheckOptions["textX"] := xPos + 35
      ,CheckOptions["textY"] := 250
   AddCheckBox(CheckOptions)
   Gui, Add, Button, x0 y0 w10 h10 vDummyFocusButton Hidden, Dummy
   GuiControl, Focus, DummyFocusButton
   
   SG:= New ScrollGUI(SGUI, 450, 800, "-DPIScale", 1, 1)
   SG.Show("Arturo's PTCGP BOT","ycenter xcenter")
   if (CurrentTheme = "Dark") {
      OD_Colors.Attach(Moitor,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(Scale,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(OCR,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(Client,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA4HoOh,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA4Lugia,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA3b,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA3a,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA3S,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA3L,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA2b,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA2a,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA2D,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA2P,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA1MT,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA1C,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA1P,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(MinA1M,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(Method,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(Sortby,{T: 0XFDFDFD, B: 0X7C8590})
      OD_Colors.Attach(s4tMin,{T: 0XFDFDFD, B: 0X7C8590})
   } else {
      OD_Colors.Attach(Moitor,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(Scale,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(OCR,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(Client,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA4HoOh,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA4Lugia,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA3b,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA3a,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA3S,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA3L,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA2b,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA2a,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA2D,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA2P,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA1MT,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA1C,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA1P,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(MinA1M,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(Method,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(Sortby,{T: 0XBC0000, B: 0XFFD1CD})
      OD_Colors.Attach(s4tMin,{T: 0XBC0000, B: 0XFFD1CD})
   }
   
   WinGet, mainHwnd, ID, Arturo's PTCGP BOT
   WinGetPos, mainX, mainY, mainW, mainH, ahk_id %mainHwnd%
   ;; ========== Menu ==========
   global menuW := 260
   global menuH := 683
   global menuExpanded
   if (!menuExpanded) {
      menuX := mainX + mainW - menuW - 35
      menuExpanded := False
   } else {
      menuX := mainX + mainW - 5
      menuExpanded := True
   }
   menuY := mainY
   xPos := 18
   Gui, Menu:New
   ;Gui, Menu:+Owner%MainGuiName%
   Gui, Menu:-Caption
   Gui, Menu:+HWNDmenuHwnd
   Gui, Menu:Add, Picture, x0 y0 w%menuW% h%menuH%, %MenuBackground%
   Gui, Menu:Add, Picture, x18 y12 w200 h60 BackgroundTrans, %titleImage%
   if (menuExpanded)
      menuPic := MenuClose
   else
      menuPic := MenuOpen
   Gui, Menu:Add, Picture, x240 y310 w20 h80 vMenuSwitch gMenuSwitchHandler BackgroundTrans, %menuPic%
   SetMenuBtnFont()
   Gui, Menu:Add, Text, x32 y23 BackgroundTrans, % currentDictionary.title_main . "`n" . localVersion . " " . intro
   global Btn_ToolTip, Txt_Btn_ToolTip
   global Btn_Mumu, Btn_Arrange, Btn_BalanceXMLs, Btn_Update, Btn_Join, Btn_Coffee, Btn_Start, Btn_XMLSortTool, Btn_XMLDuplicateTool
   global Txt_Btn_Mumu, Txt_Btn_Arrange, Txt_Btn_BalanceXMLs, Txt_Btn_Update, Txt_Btn_Join, Txt_Btn_Coffee, Txt_Btn_Start, Txt_XMLSortTool, Txt_XMLDuplicateTool
   PageBtnShift(defaultBotLanguage)
   ButtonOptions := Object()
   if (CurrentTheme = "Dark") {
      Gui, Menu:Font, s12 cBC1111, %currentfont%
   } else {
      Gui, Menu:Font, s12 c007700, %currentfont%
   }
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 94
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 44
      ,ButtonOptions["vName"] := "Btn_ToolTip"
      ,ButtonOptions["gName"] := "OpenToolTip"
      ,ButtonOptions["text"] := currentDictionary.btn_ToolTip
      ,ButtonOptions["imagePath"] := ToolTipImage
      ,ButtonOptions["vTextName"] := "Txt_Btn_ToolTip"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (106 + ys)
   AddBtn(ButtonOptions)
   SetMenuBtnFont()
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 157
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_Mumu"
      ,ButtonOptions["gName"] := "LaunchAllMumu"
      ,ButtonOptions["text"] := currentDictionary.btn_mumu
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_Btn_Mumu"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (167 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 211
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_Arrange"
      ,ButtonOptions["gName"] := "ArrangeWindows"
      ,ButtonOptions["text"] := currentDictionary.btn_arrange
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_Btn_Arrange"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (221 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 268
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_BalanceXMLs"
      ,ButtonOptions["gName"] := "BalanceXMLs"
      ,ButtonOptions["text"] := currentDictionary.btn_balance
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_Btn_BalanceXMLs"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (278 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 324
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_Update"
      ,ButtonOptions["gName"] := "CheckForUpdates"
      ,ButtonOptions["text"] := currentDictionary.btn_update
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_Btn_Update"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (334 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 379
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_Join"
      ,ButtonOptions["gName"] := "OpenDiscord"
      ,ButtonOptions["text"] := currentDictionary.btn_join
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_Btn_Join"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (389 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 436
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_Coffee"
      ,ButtonOptions["gName"] := "OpenLink"
      ,ButtonOptions["text"] := currentDictionary.btn_coffee
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_Btn_Coffee"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (446 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 491
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 44 
      ,ButtonOptions["vName"] := "Btn_Start"
      ,ButtonOptions["gName"] := "StartBot"
      ,ButtonOptions["text"] := currentDictionary.btn_start
      ,ButtonOptions["imagePath"] := ToolTipImage
      ,ButtonOptions["vTextName"] := "Txt_Btn_Start"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (506 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 546
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_XMLSortTool"
      ,ButtonOptions["gName"] := "RunXMLSortTool"
      ,ButtonOptions["text"] := "XML Sort Tool"
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_XMLSortTool"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (556 + ys)
   AddBtn(ButtonOptions)
   ButtonOptions["type"] := "Picture"
      ,ButtonOptions["x"] := xPos
      ,ButtonOptions["y"] := 601
      ,ButtonOptions["w"] := 200
      ,ButtonOptions["h"] := 36
      ,ButtonOptions["vName"] := "Btn_XMLDuplicateTool"
      ,ButtonOptions["gName"] := "RunXMLDuplicateTool"
      ,ButtonOptions["text"] := "XML Duplicate Tool"
      ,ButtonOptions["imagePath"] := btn_mainPage
      ,ButtonOptions["vTextName"] := "Txt_XMLDuplicateTool"
      ,ButtonOptions["textX"] := xPos
      ,ButtonOptions["textY"] := (611 + ys)
   AddBtn(ButtonOptions)
   setMenuNormalFont()
   Gui, Menu:Add, Text, x8 y660 w220 Center BackgroundTrans, ● CC BY-NC 4.0 international license
   Gui, Menu:Show, w%menuW% h%menuH% x%menuX% y%menuY% NoActivate
   WinSet, AlwaysOnTop, On, ahk_id %mainHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %mainHwnd%
   ;; ========== Top Bar GUI ==========
   global topBarW := 340
   global topBarH := 440
   Gui, TopBar:New
   Gui, TopBar:+Owner%MainGuiName%
   Gui, TopBar:-Caption
   Gui, TopBar:+HWNDtopBarHwnd
   if (CurrentTheme = "Dark") {
      Gui, Color, e9f1f7, 7C8590
   } else {
      Gui, Color, e9f1f7, FFD1CD
   }
   Gui, TopBar:Add, Picture, x0 y0 w%topBarW% h%topBarH% vTopBarBackground, %TopBarSmall%
   SetTopBarNormalFont()
   global Btn_ToolTip, Btn_reload, BackgroundToggle, ThemeToggle, Btn_ClassicMode
   global Txt_Btn_reload, Txt_Btn_ClassicMode
   global CallOthers := 0
   SetTopBarBtnFont()
   TopBarBtnOptions := Object()
   ; first row
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35
      ,TopBarBtnOptions["y"] := 10
      ,TopBarBtnOptions["w"] := 121
      ,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_reload"
      ,TopBarBtnOptions["gName"] := "SaveReload"
      ,TopBarBtnOptions["imagePath"] := btn_mainPage
      ,TopBarBtnOptions["text"] := currentDictionary.btn_reload
      ,TopBarBtnOptions["vTextName"] := "Txt_Btn_reload"
      ,TopBarBtnOptions["textX"] := 35
      ,TopBarBtnOptions["textY"] := 12
   AddBtnforTop(TopBarBtnOptions)
   ; Clean up the options object for the next button
   TopBarBtnOptions := {}
   TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 185
      ,TopBarBtnOptions["y"] := 10
      ,TopBarBtnOptions["w"] := 121
      ,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_ClassicMode"
      ,TopBarBtnOptions["gName"] := "OpenClassicMode"
      ,TopBarBtnOptions["text"] := "Classic Mode"
      ,TopBarBtnOptions["imagePath"] := btn_mainPage
      ,TopBarBtnOptions["vTextName"] := "Txt_Btn_ClassicMode"
      ,TopBarBtnOptions["textX"] := 185
      ,TopBarBtnOptions["textY"] := 12
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, TopBar:Add, Text, x35 y60 BackgroundTrans, % currentDictionary.btn_Language . " :"
   BotLanguagelist := "English|中文|日本語|Deutsch"
   defaultChooseLang := 1
   if (BotLanguage != "") {
      Loop, Parse, BotLanguagelist, |
         if (A_LoopField = BotLanguage) {
            defaultChooseLang := A_Index
            break
         }
   }
   Gui, TopBar:Add, DropDownList, x150 y58 w80 vTopBotLanguage gLanguageControl hwndBotLan +0x0210 Choose%defaultChooseLang% BackgroundTrans Center, English|中文|日本語|Deutsch
   global Btn_Font, Btn_FontColor, Btn_BackgroundToggle, Btn_PageToggle, Btn_MenuToggle, Btn_Theme, SaveTopBar
   global Txt_Btn_Font, Txt_Btn_FontColor, Txt_Btn_BackgroundToggle, Txt_Btn_PageToggle, Txt_Btn_MenuToggle, Txt_Btn_Theme, Txt_saveTopBar
   SetTopBarBtnFont()
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35 ,TopBarBtnOptions["y"] := 95 ,TopBarBtnOptions["w"] := 100,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_Font" ,TopBarBtnOptions["gName"] := "ChooseFont"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_topbar2.png" : A_ScriptDir . "\GUI\Images\panel_topbar1.png")
      ,TopBarBtnOptions["text"] := "Choose Font" ,TopBarBtnOptions["vTextName"] := "Txt_Btn_Font"
      ,TopBarBtnOptions["textX"] := 35 ,TopBarBtnOptions["textY"] := 97
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, TopBar:Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "x150 y97 w147 h20 vcurrentfont -E0x200 Center backgroundtrans", %currentfont%
   
   Gui, TopBar:Add, Text, X35 y130 BackgroundTrans, Set Font Color << current：
   Gui, TopBar:Add, Text, X238 y130 BackgroundTrans, >>
   SetTopBarBtnFont()
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35 ,TopBarBtnOptions["y"] := 155 ,TopBarBtnOptions["w"] := 100,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_FontColor" ,TopBarBtnOptions["gName"] := "ChooseFontColor"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_topbar2.png" : A_ScriptDir . "\GUI\Images\panel_topbar1.png")
      ,TopBarBtnOptions["text"] := "Choose Color" ,TopBarBtnOptions["vTextName"] := "Txt_Btn_FontColor"
      ,TopBarBtnOptions["textX"] := 35 ,TopBarBtnOptions["textY"] := 157
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, TopBar:Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "x150 y157 w147 h20 vFontColor BackgroundTrans -E0x200 Center backgroundtrans", %FontColor%
   
   Gui, TopBar:Add, Text, x35 y190 BackgroundTrans, Choose Background Image（9：16）：
   SetTopBarBtnFont()
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35 ,TopBarBtnOptions["y"] := 215 ,TopBarBtnOptions["w"] := 60,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_BackgroundToggle" ,TopBarBtnOptions["gName"] := "ChooseBackground"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_small2.png" : A_ScriptDir . "\GUI\Images\panel_small1.png")
      ,TopBarBtnOptions["text"] := "Search" ,TopBarBtnOptions["vTextName"] := "Txt_Btn_BackgroundToggle"
      ,TopBarBtnOptions["textX"] := 35 ,TopBarBtnOptions["textY"] := 217
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, TopBar:Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "x100 y217 w200 h20 vBackgroundImage -E0x200 Center backgroundtrans", %BackgroundImage%
   
   Gui, TopBar:Add, Text, x35 y250 BackgroundTrans, Choose Page Image（8：11）：
   SetTopBarBtnFont()
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35 ,TopBarBtnOptions["y"] := 275 ,TopBarBtnOptions["w"] := 60,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_PageToggle" ,TopBarBtnOptions["gName"] := "ChoosePage"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_small2.png" : A_ScriptDir . "\GUI\Images\panel_small1.png")
      ,TopBarBtnOptions["text"] := "Search" ,TopBarBtnOptions["vTextName"] := "Txt_Btn_PageToggle"
      ,TopBarBtnOptions["textX"] := 35 ,TopBarBtnOptions["textY"] := 277
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, TopBar:Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "x100 y277 w200 h20 vPageImage -E0x200 Center backgroundtrans", %PageImage%
   
   Gui, TopBar:Add, Text, x35 y310 BackgroundTrans, Choose Menu Image（2：5）：
   SetTopBarBtnFont()
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35 ,TopBarBtnOptions["y"] := 335 ,TopBarBtnOptions["w"] := 60,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_MenuToggle" ,TopBarBtnOptions["gName"] := "ChooseMenu"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_small2.png" : A_ScriptDir . "\GUI\Images\panel_small1.png")
      ,TopBarBtnOptions["text"] := "Search" ,TopBarBtnOptions["vTextName"] := "Txt_Btn_MenuToggle"
      ,TopBarBtnOptions["textX"] := 35 ,TopBarBtnOptions["textY"] := 337
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, TopBar:Add, Edit, % (CurrentTheme = "Dark"? "cFDFDFD ": "cBC0000 ") . "x100 y337 w200 h20 vMenuBackground -E0x200 Center backgroundtrans", %MenuBackground%
   SetTopBarBtnFont()
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 35 ,TopBarBtnOptions["y"] := 370 ,TopBarBtnOptions["w"] := 100,TopBarBtnOptions["h"] := 25
      ,TopBarBtnOptions["vName"] := "Btn_Theme" ,TopBarBtnOptions["gName"] := "ToggleTheme"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_topbar2.png" : A_ScriptDir . "\GUI\Images\panel_topbar1.png")
      ,TopBarBtnOptions["text"] := "Toggle Theme" ,TopBarBtnOptions["vTextName"] := "Txt_Btn_Theme"
      ,TopBarBtnOptions["textX"] := 35 ,TopBarBtnOptions["textY"] := 372
   AddBtnforTop(TopBarBtnOptions)
   TopBarBtnOptions := {}
      ,TopBarBtnOptions["type"] := "Picture"
      ,TopBarBtnOptions["x"] := 140 ,TopBarBtnOptions["y"] := 400 ,TopBarBtnOptions["w"] := 60,TopBarBtnOptions["h"] := 28
      ,TopBarBtnOptions["vName"] := "saveTopBar" ,TopBarBtnOptions["gName"] := "SaveTopBarSettings"
      ,TopBarBtnOptions["imagePath"] := (CurrentTheme = "Dark" ? A_ScriptDir . "\GUI\Images\panel_small2.png" : A_ScriptDir . "\GUI\Images\panel_small1.png")
      ,TopBarBtnOptions["text"] := "Save" ,TopBarBtnOptions["vTextName"] := "Txt_saveTopBar"
      ,TopBarBtnOptions["textX"] := 138,TopBarBtnOptions["textY"] := 402
   AddBtnforTop(TopBarBtnOptions)
   SetTopBarNormalFont()
   Gui, Font, norm
   SetTopBarNormalFont()
   Gui, TopBar:Show, % "x" . mainX+15 . " y" . mainY+32 . " w" . topBarW . " h36 NoActivate"
   if (CurrentTheme = "Dark") {
      OD_Colors.Attach(BotLan,{T: 0XFDFDFD, B: 0X7C8590})
   } else {
      OD_Colors.Attach(BotLan,{T: 0XFF5555, B: 0XFFD1CD})
   }
   ; ColorBlock
   Gui, TopBarColor:New
   Gui, TopBarColor:+Owner%MainGuiName%
   Gui, TopBarColor:-Caption -Border
   Gui, TopBarColor:+HWNDtopBarColorHwnd
   Gui, TopBarColor:Color, 0xeeeeee
   Gui, TopBarColor:Add, Edit, x0 y0 w15 h15 vColorBlock Hidden, % " "
   Gui, TopBarColor:Show, % "x" . mainX+274 . " y" . mainY+195 . " w0 h0 NoActivate"
   WinSet, TransColor, 0xeeeeee
   ; TopBarSwitch
   Gui, TopBarSwitch:New
   Gui, TopBarSwitch:+Owner%MainGuiName%
   Gui, TopBarSwitch:-Caption -Border
   Gui, TopBarSwitch:+HWNDtopBarSwitchHwnd
   Gui, TopBarSwitch:Color, 0xeeeeee
   Gui, TopBarSwitch:Add, Picture, x0 y0 w%topBarW% h20 vSwitchPic gTopBarSwitchHandler BackgroundTrans, %TopBarOpen%
   Gui, TopBarSwitch:Show, % "x" . mainX+15 . " y" . mainY+77 . " w" . topBarW . " h20 NoActivate"
   Gui, TopBarSwitch:+LastFound
   WinSet, TransColor, 0xeeeeee
   ApplyInputStyle()
   WinSet, Redraw,, A
   OnMessage(0x0003, "OnGuiMove") ; WM_MOVE
   OnMessage(0x0006, "OnMainGuiActivate")
Return

;;========== Class_ScrollGUI ==========
; ======================================================================================================================
; Namepace:       ScrollGUI
; Function:       Creates a scrollable GUI as a parent for GUI windows.
; Tested with:    AHK 1.1.20.03 (1.1.20+ required)
; Tested on:      Win 8.1 (x64)
; License:        The Unlicense -> http://unlicense.org
; Change log:
;                 1.0.00.00/2015-02-06/just me        -  initial release on ahkscript.org
;                 1.0.01.00/2015-02-08/just me        -  bug fixes
;                 1.1.00.00/2015-02-13/just me        -  bug fixes, mouse wheel handling, AutoSize method
;                 1.2.00.00/2015-03-12/just me        -  mouse wheel handling, resizing, OnMessage, bug fixes
; ======================================================================================================================
Class ScrollGUI {
   Static Instances := []
   ; ===================================================================================================================
   ; __New          Creates a scrollable parent window (ScrollGUI) for the passed GUI.
   ; Parameters:
   ;    HGUI        -  HWND of the GUI child window.
   ;    Width       -  Width of the client area of the ScrollGUI.
   ;                   Pass 0 to set the client area to the width of the child GUI.
   ;    Height      -  Height of the client area of the ScrollGUI.
   ;                   Pass 0 to set the client area to the height of the child GUI.
   ;    ----------- Optional:
   ;    GuiOptions  -  GUI options to be used when creating the ScrollGUI (e.g. +LabelMyLabel).
   ;                   Default: empty (no options)
   ;    ScrollBars  -  Scroll bars to register:
   ;                   1 : horizontal
   ;                   2 : vertical
   ;                   3 : both
   ;                   Default: 3
   ;    Wheel       -  Register WM_MOUSEWHEEL / WM_MOUSEHWHEEL messages:
   ;                   1 : register WM_MOUSEHWHEEL for horizontal scrolling (reqires Win Vista+)
   ;                   2 : register WM_MOUSEWHEEL for vertical scrolling
   ;                   3 : register both
   ;                   4 : register WM_MOUSEWHEEL for vertical and Shift+WM_MOUSEWHEEL for horizontal scrolling
   ;                   Default: 0
   ; Return values:
   ;    On failure:    False
   ; Remarks:
   ;    The dimensions of the child GUI are determined internally according to the visible children.
   ;    The maximum width and height of the parent GUI will be restricted to the dimensions of the child GUI.
   ;    If you register mouse wheel messages, the messages will be passed to the focused control, unless the mouse
   ;    is hovering on one of the ScrollGUI's scroll bars. If the control doesn't process the message, it will be
   ;    returned back to the ScrollGUI.
   ;    Common controls seem to ignore wheel messages whenever the CTRL is down. So you can use this modifier to
   ;    scroll the ScrollGUI even if a scrollable control has the focus.
   ; ===================================================================================================================
   __New(HGUI, Width, Height, GuiOptions := "", ScrollBars := 3, Wheel := 0) {
      Static WS_HSCROLL := "0x100000", WS_VSCROLL := "0x200000"
      Static FN_SCROLL := ObjBindMethod(ScrollGui, "On_WM_Scroll")
      Static FN_SIZE := ObjBindMethod(ScrollGui, "On_WM_Size")
      Static FN_WHEEL := ObjBindMethod(ScrollGUI, "On_WM_Wheel")
      ScrollBars &= 3
      Wheel &= 7
      If ((ScrollBars <> 1) && (ScrollBars <> 2) && (ScrollBars <> 3))
         || ((Wheel <> 0) && (Wheel <> 1) && (Wheel <> 2) && (Wheel <> 3) && (Wheel <> 4))
         Return False
      If !DllCall("User32.dll\IsWindow", "Ptr", HGUI, "UInt")
         Return False
      VarSetCapacity(RC, 16, 0)
      ; Child GUI
      If !This.AutoSize(HGUI, GuiW, GuiH)
         Return False
      Gui, %HGUI%:-Caption -Resize
      Gui, %HGUI%:Show, w%GuiW% h%GuiH% Hide
      MaxH := GuiW
      MaxV := GuiH
      LineH := 450
      LineV := Ceil(MaxV / 20)
      ; ScrollGUI
      If (Width = 0) || (Width > MaxH)
         Width := MaxH
      If (Height = 0) || (Height > MaxV)
         Height := MaxV
      Styles := (ScrollBars & 1 ? " +" . WS_HSCROLL : "") . (ScrollBars & 2 ? " +" . WS_VSCROLL : "")
      Gui, New, %GuiOptions% %Styles% +hwndHWND
      Gui, %HWND%:Show, w%Width% h%Height% Hide
      Gui, %HWND%:+MaxSize%MaxH%x%MaxV%
      PageH := Width + 1
      PageV := Height + 1
      ; Instance variables
      This.HWND := HWND + 0
      This.HGUI := HGUI
      This.Width := Width
      This.Height := Height
      This.UseShift := False
      If (ScrollBars & 1) {
         This.SetScrollInfo(0, {Max: MaxH, Page: PageH, Pos: 0}) ; SB_HORZ = 0
         OnMessage(0x0114, FN_SCROLL) ; WM_HSCROLL = 0x0114
         If (Wheel & 1)
            OnMessage(0x020E, FN_WHEEL) ; WM_MOUSEHWHEEL = 0x020E
         Else If (Wheel & 4) {
            OnMessage(0x020A, FN_WHEEL) ; WM_MOUSEWHEEL = 0x020A
            This.UseShift := True
         }
         This.MaxH := MaxH
         This.LineH := LineH
         This.PageH := PageH
         This.PosH := 0
         This.ScrollH := True
         If (Wheel & 5)
            This.WheelH := True
      }
      If (ScrollBars & 2) {
         This.SetScrollInfo(1, {Max: MaxV, Page: PageV, Pos: 0}) ; SB_VERT = 1
         OnMessage(0x0115, FN_SCROLL) ; WM_VSCROLL = 0x0115
         If (Wheel & 6)
            OnMessage(0x020A, FN_WHEEL) ; WM_MOUSEWHEEL = 0x020A
         This.MaxV := MaxV
         This.LineV := LineV
         This.PageV := PageV
         This.PosV := 0
         This.ScrollV := True
         If (Wheel & 6)
            This.WheelV := True
      }
      ; Set the position of the child GUI
      Gui, %HGUI%:+Parent%HWND%
      Gui, %HGUI%:Show, x0 y0
      ; Adjust the scroll bars
      This.Instances[This.HWND] := &This
      This.Size()
      OnMessage(0x0005, FN_SIZE) ; WM_SIZE = 0x0005
   }
   ; ===================================================================================================================
   ; __Delete       Destroy the GUIs, if they still exist.
   ; ===================================================================================================================
   __Delete() {
      This.Destroy()
   }
   ; ===================================================================================================================
   ; Show           Shows the ScrollGUI.
   ; Parameters:
   ;    Title       -  Title of the ScrollGUI window
   ;    ShowOptions -  Gui, Show command options, width or height options are ignored
   ; Return values:
   ;    On success: True
   ;    On failure: False
   ; ===================================================================================================================
   Show(Title := "", ShowOptions := "") {
      ShowOptions := RegExReplace(ShowOptions, "i)\+?AutoSize")
      W := This.Width
      H := This.Height
      Gui, % This.HWND . ":Show",NA %ShowOptions% w%W% h%H%, %Title%
      if (Title == "Arturo's PTCGP BOT")
         MainGuiName := % This.HGUI
      Return True
   }
   hide(Title := "") {
      Gui, % This.HWND . ":Hide"
      Return True
   }
   ; ===================================================================================================================
   ; Destroy        Destroys the ScrollGUI and the associated child GUI.
   ; Parameters:
   ;    None.
   ; Return values:
   ;    On success: True
   ;    On failure: False
   ; Remarks:
   ;    Use this method instead of 'Gui, Destroy' to remove the ScrollGUI from the 'Instances' object.
   ; ===================================================================================================================
   Destroy() {
      If This.Instances.HasKey(This.HWND) {
         Gui, % This.HWND . ":Destroy"
         This.Instances.Remove(This.HWND, "")
         Return True
      }
   }
   ; ===================================================================================================================
   ; AdjustToChild  Adjust the scroll bars to the new child dimensions.
   ; Parameters:
   ;    None
   ; Return values:
   ;    On success: True
   ;    On failure: False
   ; Remarks:
   ;    Call this method whenever the visible area of the child GUI has to be changed, e.g. after adding, hiding,
   ;    unhiding, resizing, or repositioning controls.
   ;    The dimensions of the child GUI are determined internally according to the visible children.
   ; ===================================================================================================================
   AdjustToChild() {
      VarSetCapacity(RC, 16, 0)
      DllCall("User32.dll\GetWindowRect", "Ptr", This.HGUI, "Ptr", &RC)
      PrevW := NumGet(RC, 8, "Int") - NumGet(RC, 0, "Int")
      PrevH := Numget(RC, 12, "Int") - NumGet(RC, 4, "Int")
      DllCall("User32.dll\ScreenToClient", "Ptr", This.HWND, "Ptr", &RC)
      XC := XN := NumGet(RC, 0, "Int")
      YC := YN := NumGet(RC, 4, "Int")
      If !This.AutoSize(This.HGUI, GuiW, GuiH)
         Return False
      Gui, % This.HGUI . ":Show", x%XC% y%YC% w%GuiW% h%GuiH%
      MaxH := GuiW
      MaxV := GuiH
      Gui, % This.HWND . ":+MaxSize" . MaxH . "x" . MaxV
      If (GuiW < This.Width) || (GuiH < This.Height) {
         Gui, % This.HWND . ":Show", w%GuiW% h%GuiH%
         This.Width := GuiW
         This.SetPage(1, MaxH + 1)
         This.Height := GuiH
         This.SetPage(2, MaxV + 1)
      }
      LineH := Ceil(MaxH / 20)
      LineV := Ceil(MaxV / 20)
      If This.ScrollH {
         This.SetMax(1, MaxH)
         This.LineH := LineH
         If (XC + MaxH) < This.Width {
            XN += This.Width - (XC + MaxH)
            If (XN > 0)
               XN := 0
            This.SetScrollInfo(0, {Pos: XN * -1})
            This.GetScrollInfo(0, SI)
            This.PosH := NumGet(SI, 20, "Int")
         }
      }
      If This.ScrollV {
         This.SetMax(2, MaxV)
         This.LineV := LineV
         If (YC + MaxV) < This.Height {
            YN += This.Height - (YC + MaxV)
            If (YN > 0)
               YN := 0
            This.SetScrollInfo(1, {Pos: YN * -1})
            This.GetScrollInfo(1, SI)
            This.PosV := NumGet(SI, 20, "Int")
         }
      }
      If (XC <> XN) || (YC <> YN)
         DllCall("User32.dll\ScrollWindow", "Ptr", This.HWND, "Int", XN - XC, "Int", YN - YC, "Ptr", 0, "Ptr", 0)
      Return True
   }
   ; ===================================================================================================================
   ; SetMax         Sets the width or height of the scrolling area.
   ; Parameters:
   ;    SB          -  Scroll bar to set the value for:
   ;                   1 = horizontal
   ;                   2 = vertical
   ;    Max         -  Width respectively height of the scrolling area in pixels
   ; Return values:
   ;    On success: True
   ;    On failure: False
   ; ===================================================================================================================
   SetMax(SB, Max) {
      ; SB_HORZ = 0, SB_VERT = 1
      SB--
      If (SB <> 0) && (SB <> 1)
         Return False
      If (SB = 0)
         This.MaxH := Max
      Else
         This.MaxV := Max
      Return This.SetScrollInfo(SB, {Max: Max})
   }
   ; ===================================================================================================================
   ; SetLine        Sets the number of pixels to scroll by line.
   ; Parameters:
   ;    SB          -  Scroll bar to set the value for:
   ;                   1 = horizontal
   ;                   2 = vertical
   ;    Line        -  Number of pixels.
   ; Return values:
   ;    On success: True
   ;    On failure: False
   ; ===================================================================================================================
   SetLine(SB, Line) {
      ; SB_HORZ = 0, SB_VERT = 1
      SB--
      If (SB <> 0) && (SB <> 1)
         Return False
      If (SB = 0)
         This.LineH := Line
      Else
         This.LineV := Line
      Return True
   }
   ; ===================================================================================================================
   ; SetPage        Sets the number of pixels to scroll by page.
   ; Parameters:
   ;    SB          -  Scroll bar to set the value for:
   ;                   1 = horizontal
   ;                   2 = vertical
   ;    Page        -  Number of pixels.
   ; Return values:
   ;    On success: True
   ;    On failure: False
   ; Remarks:
   ;    If the ScrollGUI is resizable, the page size will be recalculated automatically while resizing.
   ; ===================================================================================================================
   SetPage(SB, Page) {
      ; SB_HORZ = 0, SB_VERT = 1
      SB--
      If (SB <> 0) && (SB <> 1)
         Return False
      If (SB = 0)
         This.PageH := Page
      Else
         This.PageV := Page
      Return This.SetScrollInfo(SB, {Page: Page})
   }
   ; ===================================================================================================================
   ; Methods for internal or system use!!!
   ; ===================================================================================================================
   AutoSize(HGUI, ByRef Width, ByRef Height) {
      DHW := A_DetectHiddenWindows
      DetectHiddenWindows, On
      VarSetCapacity(RECT, 16, 0)
      Width := Height := 0
      HWND := HGUI
      CMD := 5 ; GW_CHILD
      L := T := R := B := LH := TH := ""
      While (HWND := DllCall("GetWindow", "Ptr", HWND, "UInt", CMD, "UPtr")) && (CMD := 2) {
         WinGetPos, X, Y, W, H, ahk_id %HWND%
         W += X, H += Y
         WinGet, Styles, Style, ahk_id %HWND%
         If (Styles & 0x10000000) { ; WS_VISIBLE
            If (L = "") || (X < L)
               L := X
            If (T = "") || (Y < T)
               T := Y
            If (R = "") || (W > R)
               R := W
            If (B = "") || (H > B)
               B := H
         }
         Else {
            If (LH = "") || (X < LH)
               LH := X
            If (TH = "") || (Y < TH)
               TH := Y
         }
      }
      DetectHiddenWindows, %DHW%
      If (LH <> "") {
         VarSetCapacity(POINT, 8, 0)
         NumPut(LH, POINT, 0, "Int")
         DllCall("ScreenToClient", "Ptr", HGUI, "Ptr", &POINT)
         LH := NumGet(POINT, 0, "Int")
      }
      If (TH <> "") {
         VarSetCapacity(POINT, 8, 0)
         NumPut(TH, POINT, 4, "Int")
         DllCall("ScreenToClient", "Ptr", HGUI, "Ptr", &POINT)
         TH := NumGet(POINT, 4, "Int")
      }
      NumPut(L, RECT, 0, "Int"), NumPut(T, RECT, 4, "Int")
      NumPut(R, RECT, 8, "Int"), NumPut(B, RECT, 12, "Int")
      DllCall("MapWindowPoints", "Ptr", 0, "Ptr", HGUI, "Ptr", &RECT, "UInt", 2)
      Width := NumGet(RECT, 8, "Int") + (LH <> "" ? LH : NumGet(RECT, 0, "Int"))
      Height := NumGet(RECT, 12, "Int") + (TH <> "" ? TH : NumGet(RECT, 4, "Int"))
      Return True
   }
   ; ===================================================================================================================
   GetScrollInfo(SB, ByRef SI) {
      VarSetCapacity(SI, 28, 0) ; SCROLLINFO
      NumPut(28, SI, 0, "UInt")
      NumPut(0x17, SI, 4, "UInt") ; SIF_ALL = 0x17
      Return DllCall("User32.dll\GetScrollInfo", "Ptr", This.HWND, "Int", SB, "Ptr", &SI, "UInt")
   }
   ; ===================================================================================================================
   SetScrollInfo(SB, Values) {
      Static SIF := {Max: 0x01, Page: 0x02, Pos: 0x04}
      Static Off := {Max: 12, Page: 16, Pos: 20}
      Mask := 0
      VarSetCapacity(SI, 28, 0) ; SCROLLINFO
      NumPut(28, SI, 0, "UInt")
      For Key, Value In Values {
         If SIF.HasKey(Key) {
            Mask |= SIF[Key]
            NumPut(Value, SI, Off[Key], "UInt")
         }
      }
      If (Mask) {
         NumPut(Mask | 0x08, SI, 4, "UInt") ; SIF_DISABLENOSCROLL = 0x08
         Return DllCall("User32.dll\SetScrollInfo", "Ptr", This.HWND, "Int", SB, "Ptr", &SI, "UInt", 1, "UInt")
      }
      Return False
   }
   ; ===================================================================================================================
   On_WM_Scroll(WP, LP, Msg, HWND) {
      ; WM_HSCROLL = 0x0114, WM_VSCROLL = 0x0115
      If (Instance := Object(This.Instances[HWND]))
         If ((Msg = 0x0114) && Instance.ScrollH)
            || ((Msg = 0x0115) && Instance.ScrollV)
            Return Instance.Scroll(WP, LP, Msg, HWND)
   }
   ; ==================================================================================================================
   SnapToPage(SB := 1) {
      ;ToolTip, InSnap, 50, 20
      pos := (SB=1) ? This.PosH : This.PosV
      page := (SB=1) ? This.Width : This.Height
      target := Round(pos / page) * page
      This.SetScrollInfo(SB-1, {Pos: target})
      This.GetScrollInfo(SB-1, SI)
      if (SB=1)
         This.PosH := NumGet(SI, 20, "Int")
      else
         This.PosV := NumGet(SI, 20, "Int")
      ; refresh immediately
      DllCall("User32.dll\ScrollWindow", "Ptr", This.HWND, "Int", (SB=1) ? pos-target : 0, "Int", (SB=2) ? pos-target : 0, "Ptr", 0, "Ptr", 0)
   }
   ; ===================================================================================================================
   Scroll(WP, LP, Msg, HWND) {
      
      ; WM_HSCROLL = 0x0114, WM_VSCROLL = 0x0115
      Static SB_LINEMINUS := 0, SB_LINEPLUS := 1, SB_PAGEMINUS := 2, SB_PAGEPLUS := 3, SB_THUMBTRACK := 5
      If (LP <> 0)
         Return
      SB := (Msg = 0x0114 ? 0 : 1) ; SB_HORZ : SB_VERT
      SC := WP & 0xFFFF
      if (SC = 8) {
         ;ToolTip, SC = %SC%, 50, 50
         This.SnapToPage(1)
      }
      SD := (Msg = 0x0114 ? This.LineH : This.LineV)
      SI := 0
      If !This.GetScrollInfo(SB, SI)
         Return
      PA := PN := NumGet(SI, 20, "Int")
      PN := (SC = 0) ? PA - SD ; SB_LINEMINUS
         : (SC = 1) ? PA + SD ; SB_LINEPLUS
         : (SC = 2) ? PA - NumGet(SI, 16, "UInt") ; SB_PAGEMINUS
         : (SC = 3) ? PA + NumGet(SI, 16, "UInt") ; SB_PAGEPLUS
         : (SC = 5) ? NumGet(SI, 24, "Int") ; SB_THUMBTRACK
         : PA
      If (PA = PN)
         Return 0
      This.SetScrollInfo(SB, {Pos: PN})
      This.GetScrollInfo(SB, SI)
      PN := NumGet(SI, 20, "Int")
      If (SB = 0)
         This.PosH := PN
      Else
         This.PosV := PN
      If (PA <> PN) {
         HS := (Msg = 0x0114) ? PA - PN : 0
         VS := (Msg = 0x0115) ? PA - PN : 0
         DllCall("User32.dll\ScrollWindow", "Ptr", This.HWND, "Int", HS, "Int", VS, "Ptr", 0, "Ptr", 0)
      }
      Return 0
   }
   ; ===================================================================================================================
   On_WM_Size(WP, LP, Msg, HWND) {
      If ((WP = 0) || (WP = 2)) && (Instance := Object(This.Instances[HWND]))
         Return Instance.Size(LP & 0xFFFF, (LP >> 16) & 0xFFFF)
   }
   ; ===================================================================================================================
   Size(Width := 0, Height := 0) {
      If (Width = 0) || (Height = 0) {
         VarSetCapacity(RC, 16, 0)
         DllCall("User32.dll\GetClientRect", "Ptr", This.HWND, "Ptr", &RC)
         Width := NumGet(RC, 8, "Int")
         Height := Numget(RC, 12, "Int")
      }
      SH := SV := 0
      If This.ScrollH {
         If (Width <> This.Width) {
            This.SetScrollInfo(0, {Page: Width + 1})
            This.Width := Width
            This.GetScrollInfo(0, SI)
            PosH := NumGet(SI, 20, "Int")
            SH := This.PosH - PosH
            This.PosH := PosH
         }
      }
      If This.ScrollV {
         If (Height <> This.Height) {
            This.SetScrollInfo(1, {Page: Height + 1})
            This.Height := Height
            This.GetScrollInfo(1, SI)
            PosV := NumGet(SI, 20, "Int")
            SV := This.PosV - PosV
            This.PosV := PosV
         }
      }
      If (SH) || (SV)
         DllCall("User32.dll\ScrollWindow", "Ptr", This.HWND, "Int", SH, "Int", SV, "Ptr", 0, "Ptr", 0)
      Return 0
   }
   ; ===================================================================================================================
   On_WM_Wheel(WP, LP, Msg, HWND) {
      ; MK_SHIFT = 0x0004, WM_MOUSEWHEEL = 0x020A, WM_MOUSEHWHEEL = 0x020E, WM_NCHITTEST = 0x0084
      HACT := WinActive("A") + 0
      If (HACT <> HWND) && (Instance := Object(This.Instances[HACT])) {
         SendMessage, 0x0084, 0, % (LP & 0xFFFFFFFF), , ahk_id %HACT%
         OnBar := ErrorLevel
         If (OnBar = 6) && Instance.WheelH ; HTHSCROLL = 6
            Return Instance.Wheel(WP, LP, 0x020E, HACT)
         If (OnBar = 7) && Instance.WheelV ; HTVSCROLL = 7
            Return Instance.Wheel(WP, LP, 0x020A, HACT)
      }
      If (Instance := Object(This.Instances[HWND])) {
         If ((Msg = 0x020E) && Instance.WheelH)
            || ((Msg = 0x020A) && (Instance.WheelV || (Instance.WheelH && Instance.UseShift && (WP & 0x0004))))
            Return Instance.Wheel(WP, LP, Msg, HWND)
      }
   }
   ; ===================================================================================================================
   Wheel(WP, LP, Msg, HWND) {
      ; MK_SHIFT = 0x0004, WM_MOUSEWHEEL = 0x020A, WM_MOUSEHWHEEL = 0x020E, WM_HSCROLL = 0x0114, WM_VSCROLL = 0x0115
      ; SB_LINEMINUS = 0, SB_LINEPLUS = 1
      If (Msg = 0x020A) && This.UseShift && (WP & 0x0004)
         Msg := 0x020E
      Msg := (Msg = 0x020A ? 0x0115 : 0x0114)
      SB := ((WP >> 16) > 0x7FFF) || (WP < 0) ? 1 : 0
      Return This.Scroll(SB, 0, Msg, HWND)
   }
}

UpdateTopBarSwitchPos(barX, barBottomY) {
   global topBarW
   Gui, TopBarSwitch:Show, % "x" . barX . " y" . barBottomY . " w" . topBarW . " NoActivate"
}

OnGuiMove(wParam, lParam, msg, hwnd) {
   global mainHwnd, menuHwnd, menuW, menuH, menuExpanded
   global topBarW, topBarH, topBarExpanded, topBarHwnd, topBarSwitchHwnd
   if (hwnd != mainHwnd)
      return
   WinGetPos, mainX, mainY, mainW, mainH, ahk_id %mainHwnd%
   
   ; Menu position
   if (menuExpanded)
      menuX := mainX + mainW - 5
   else
      menuX := mainX + mainW - menuW - 35
   menuY := mainY
   Gui, Menu:Show, x%menuX% y%menuY% NoActivate
   
   ; TopBar position
   TopBarX := mainX + 15
      ,TopBarY := mainY + 32
   Gui, TopBar:Show, % "x" . TopBarX . " y" . TopBarY . " NoActivate"
   
   ; TopColor position
   TopColorX := mainX + 274
      ,TopColorY := mainY + 195
   Gui, TopBarColor:Show, % "x" . TopColorX . " y" . TopColorY . " NoActivate"
   
   ; TopBarSwitch position
   TopBarSwitchX := TopBarX
   if (!topBarExpanded) {
      TopBarSwitchY := TopBarY + 45
   } else {
      TopBarSwitchY := TopBarY + topBarH + 107
   }
   Gui, TopBarSwitch:Show, % "x" . TopBarSwitchX . " y" . TopBarSwitchY . " NoActivate"
}

OnMainGuiActivate(wParam, lParam, msg, hwnd) {
   global mainHwnd, menuHwnd, topBarHwnd, topBarSwitchHwnd, topBarColorHwnd, CallOthers
   if (!CallOthers)
   {
      WinSet, AlwaysOnTop, On, ahk_id %menuHwnd%
      WinSet, AlwaysOnTop, On, ahk_id %mainHwnd%
      WinSet, AlwaysOnTop, On, ahk_id %topBarHwnd%
      WinSet, AlwaysOnTop, On, ahk_id %topBarSwitchHwnd%
      WinSet, AlwaysOnTop, On, ahk_id %topBarColorHwnd%
   }
}

GuiRemoveAlwaysOnTop() {
   WinSet, AlwaysOnTop, Off, ahk_id %menuHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %mainHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %topBarHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %topBarSwitchHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %topBarColorHwnd%
}

; Function to load settings from INI file
LoadSettingsFromIni() {
   global
   ; Check if Settings.ini exists
   if (FileExist("Settings.ini")) {
      IniRead, IsLanguageSet, Settings.ini, UserSettings, IsLanguageSet, 1
      IniRead, defaultBotLanguage, Settings.ini, UserSettings, defaultBotLanguage, 1
      IniRead, BotLanguage, Settings.ini, UserSettings, BotLanguage, English
      
      IniRead, shownLicense, Settings.ini, UserSettings, shownLicense, 0
      ; Read basic settings with default values if they don't exist in the file
      IniRead, currentfont, Settings.ini, UserSettings, currentfont, segoe UI
      defaultBg := A_ScriptDir . "\\GUI\\Images\background2.png"
      defaultPage := A_ScriptDir . "\\GUI\\Images\Page2.png"
      defaultMenu := A_ScriptDir . "\GUI\Images\Menu2.png"
      defaultBtn := A_ScriptDir . "\GUI\Images\panel2.png"
      defaultTitle := A_ScriptDir . "\GUI\Images\title2.png"
      defaultTopBarBig := A_ScriptDir . "\GUI\Images\TopBarBig2.png"
      defaultTopBarSmall := A_ScriptDir . "\GUI\Images\TopBarSmall2.png"
      defaultTopBarOpen := A_ScriptDir . "\GUI\Images\TopBarOpen2.png"
      defaultTopBarClose := A_ScriptDir . "\GUI\Images\TopBarClose2.png"
      defaultMenuOpen := A_ScriptDir . "\GUI\Images\MenuOpen2.png"
      defaultMenuClose := A_ScriptDir . "\GUI\Images\MenuClose2.png"
      defaultToolTip := A_ScriptDir . "\GUI\Images\ToolTip2.png"
      IniRead, BackgroundImage, Settings.ini, UserSettings, BackgroundImage, %defaultBg%
      IniRead, PageImage, Settings.ini, UserSettings, PageImage, %defaultPage%
      IniRead, MenuBackground, Settings.ini, UserSettings, MenuBackground, %defaultMenu%
      IniRead, FontColor, Settings.ini, UserSettings, FontColor, FDFDFD
      IniRead, CurrentTheme, Settings.ini, UserSettings, CurrentTheme, Dark
      IniRead, btn_mainPage, Settings.ini, UserSettings, btn_mainPage, %defaultBtn%
      IniRead, btn_fontColor, Settings.ini, UserSettings, btn_fontColor, FDFDFD
      IniRead, titleImage, Settings.ini, UserSettings, titleImage, %defaultTitle%
      IniRead, TopBarBig, Settings.ini, UserSettings, TopBarBig, %defaultTopBarBig%
      IniRead, TopBarSmall, Settings.ini, UserSettings, TopBarSmall, %defaultTopBarSmall%
      IniRead, TopBarOpen, Settings.ini, UserSettings, TopBarOpen, %defaultTopBarOpen%
      IniRead, TopBarClose, Settings.ini, UserSettings, TopBarClose, %defaultTopBarClose%
      IniRead, MenuOpen, Settings.ini, UserSettings, MenuOpen, %defaultMenuOpen%
      IniRead, MenuClose, Settings.ini, UserSettings, MenuClose, %defaultMenuClose%
      IniRead, ToolTipImage, Settings.ini, UserSettings, ToolTipImage, %defaultToolTip%
      ;friend id
      IniRead, FriendID, Settings.ini, UserSettings, FriendID, ""
      ;instance settings
      IniRead, Instances, Settings.ini, UserSettings, Instances, 1
      IniRead, instanceStartDelay, Settings.ini, UserSettings, instanceStartDelay, 5
      IniRead, Columns, Settings.ini, UserSettings, Columns, 5
      IniRead, runMain, Settings.ini, UserSettings, runMain, 1
      IniRead, Mains, Settings.ini, UserSettings, Mains, 1
      IniRead, AccountName, Settings.ini, UserSettings, AccountName, ""
      IniRead, autoLaunchMonitor, Settings.ini, UserSettings, autoLaunchMonitor, 1
      IniRead, autoUseGPTest, Settings.ini, UserSettings, autoUseGPTest, 0
      IniRead, TestTime, Settings.ini, UserSettings, TestTime, 3600
      ;Time settings
      IniRead, Delay, Settings.ini, UserSettings, Delay, 250
      IniRead, waitTime, Settings.ini, UserSettings, waitTime, 1
      IniRead, swipeSpeed, Settings.ini, UserSettings, swipeSpeed, 250
      IniRead, slowMotion, Settings.ini, UserSettings, slowMotion, 0
      
      ;system settings
      IniRead, SelectedMonitorIndex, Settings.ini, UserSettings, SelectedMonitorIndex, 1
      IniRead, defaultLanguage, Settings.ini, UserSettings, defaultLanguage, Scale125
      IniRead, rowGap, Settings.ini, UserSettings, rowGap, 75
      IniRead, folderPath, Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
      IniRead, ocrLanguage, Settings.ini, UserSettings, ocrLanguage, en
      IniRead, clientLanguage, Settings.ini, UserSettings, clientLanguage, en
      IniRead, instanceLaunchDelay, Settings.ini, UserSettings, instanceLaunchDelay, 5
      
      ; Extra Settings
      IniRead, tesseractPath, Settings.ini, UserSettings, tesseractPath, C:\Program Files\Tesseract-OCR\tesseract.exe
      IniRead, applyRoleFilters, Settings.ini, UserSettings, applyRoleFilters, 0
      IniRead, debugMode, Settings.ini, UserSettings, debugMode, 0
      IniRead, tesseractOption, Settings.ini, UserSettings, tesseractOption, 0
      IniRead, statusMessage, Settings.ini, UserSettings, statusMessage, 1
      
      ;pack settings
      IniRead, minStars, Settings.ini, UserSettings, minStars, 0
      IniRead, minStarsShiny, Settings.ini, UserSettings, minStarsShiny, 0
      IniRead, minStarsEnabled, Settings.ini, UserSettings, minStarsEnabled, 0
      IniRead, deleteMethod, Settings.ini, UserSettings, deleteMethod, 13 Pack
      IniRead, packMethod, Settings.ini, UserSettings, packMethod, 0
      IniRead, nukeAccount, Settings.ini, UserSettings, nukeAccount, 0
      IniRead, spendHourGlass, Settings.ini, UserSettings, spendHourGlass, 0
      IniRead, openExtraPack, Settings.ini, UserSettings, openExtraPack, 0
      IniRead, injectSortMethod, Settings.ini, UserSettings, injectSortMethod, ModifiedAsc
      IniRead, godPack, Settings.ini, UserSettings, godPack, Continue
      
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
      IniRead, HoOh, Settings.ini, UserSettings, HoOh, 1
      IniRead, Lugia, Settings.ini, UserSettings, Lugia, 1
      
      IniRead, CheckShinyPackOnly, Settings.ini, UserSettings, CheckShinyPackOnly, 0
      IniRead, TrainerCheck, Settings.ini, UserSettings, TrainerCheck, 0
      IniRead, FullArtCheck, Settings.ini, UserSettings, FullArtCheck, 0
      IniRead, RainbowCheck, Settings.ini, UserSettings, RainbowCheck, 0
      IniRead, ShinyCheck, Settings.ini, UserSettings, ShinyCheck, 0
      IniRead, CrownCheck, Settings.ini, UserSettings, CrownCheck, 0
      IniRead, ImmersiveCheck, Settings.ini, UserSettings, ImmersiveCheck, 0
      IniRead, InvalidCheck, Settings.ini, UserSettings, InvalidCheck, 0
      IniRead, PseudoGodPack, Settings.ini, UserSettings, PseudoGodPack, 0
      
      ; Read S4T settings
      IniRead, s4tEnabled, Settings.ini, UserSettings, s4tEnabled, 0
      IniRead, s4tSilent, Settings.ini, UserSettings, s4tSilent, 1
      IniRead, s4t3Dmnd, Settings.ini, UserSettings, s4t3Dmnd, 0
      IniRead, s4t4Dmnd, Settings.ini, UserSettings, s4t4Dmnd, 0
      IniRead, s4t1Star, Settings.ini, UserSettings, s4t1Star, 0
      IniRead, s4tGholdengo, Settings.ini, UserSettings, s4tGholdengo, 0
      IniRead, s4tWP, Settings.ini, UserSettings, s4tWP, 0
      IniRead, s4tWPMinCards, Settings.ini, UserSettings, s4tWPMinCards, 1
      IniRead, s4tDiscordWebhookURL, Settings.ini, UserSettings, s4tDiscordWebhookURL, ""
      IniRead, s4tDiscordUserId, Settings.ini, UserSettings, s4tDiscordUserId, ""
      IniRead, s4tSendAccountXml, Settings.ini, UserSettings, s4tSendAccountXml, 0
      
      ;discord settings
      IniRead, DiscordWebhookURL, Settings.ini, UserSettings, DiscordWebhookURL, ""
      IniRead, DiscordUserId, Settings.ini, UserSettings, DiscordUserId, ""
      IniRead, heartBeat, Settings.ini, UserSettings, heartBeat, 0
      IniRead, heartBeatWebhookURL, Settings.ini, UserSettings, heartBeatWebhookURL, ""
      IniRead, heartBeatName, Settings.ini, UserSettings, heartBeatName, ""
      IniRead, heartBeatDelay, Settings.ini, UserSettings, heartBeatDelay, 30
      IniRead, sendAccountXml, Settings.ini, UserSettings, sendAccountXml, 0
      
      ;download settings
      IniRead, mainIdsURL, Settings.ini, UserSettings, mainIdsURL, ""
      IniRead, vipIdsURL, Settings.ini, UserSettings, vipIdsURL, ""
      IniRead, showcaseEnabled, Settings.ini, UserSettings, showcaseEnabled, 0
      IniRead, showcaseLikes, Settings.ini, UserSettings, showcaseLikes, 5
      
      ; Advanced settings
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
      
      IniRead, waitForEligibleAccounts, Settings.ini, UserSettings, waitForEligibleAccounts, 1
      IniRead, maxWaitHours, Settings.ini, UserSettings, maxWaitHours, 24
      /*
      IniRead, isDarkTheme, Settings.ini, UserSettings, isDarkTheme, 1
      IniRead, useBackgroundImage, Settings.ini, UserSettings, useBackgroundImage, 1
      */
      IniRead, menuExpanded, Settings.ini, UserSettings, menuExpanded, True
      
      ; Validate numeric values
      if (!IsNumeric(Instances))
         Instances := 1
      if (!IsNumeric(Columns) || Columns < 1)
         Columns := 5
      if (!IsNumeric(waitTime))
         waitTime := 1
      if (!IsNumeric(Delay) || Delay < 10)
         Delay := 250
      if (s4tWPMinCards < 1 || s4tWPMinCards > 2)
         s4tWPMinCards := 1
         
      ; Return success
      return true
   } else {
      ; Settings file doesn't exist, will use defaults
      return false
   }
}

; Function to create the default settings file if it doesn't exist
CreateDefaultSettingsFile() {
   if (!FileExist("Settings.ini")) {
      defaultBg := A_ScriptDir . "\\GUI\\Images\background2.png"
      defaultPage := A_ScriptDir . "\\GUI\\Images\Page2.png"
      defaultMenu := A_ScriptDir . "\GUI\Images\Menu2.png"
      defaultBtn := A_ScriptDir . "\GUI\Images\panel2.png"
      defaultTitle := A_ScriptDir . "\GUI\Images\title2.png"
      defaultTopBarBig := A_ScriptDir . "\GUI\Images\TopBarBig2.png"
      defaultTopBarSmall := A_ScriptDir . "\GUI\Images\TopBarSmall2.png"
      defaultTopBarOpen := A_ScriptDir . "\GUI\Images\TopBarOpen2.png"
      defaultTopBarClose := A_ScriptDir . "\GUI\Images\TopBarClose2.png"
      defaultMenuOpen := A_ScriptDir . "\GUI\Images\MenuOpen2.png"
      defaultMenuClose := A_ScriptDir . "\GUI\Images\MenuClose2.png"
      defaultToolTip := A_ScriptDir . "\GUI\Images\ToolTip2.png"
      iniContent := "[UserSettings]`n"
      iniContent .= "IsLanguageSet=0`n"
      iniContent .= "defaultBotLanguage=1`n"
      iniContent .= "BotLanguage=English`n"
      iniContent .= "shownLicense=0`n"
      iniContent .= "currentfont=Segoe UI`n"
      iniContent .= "BackgroundImage=" defaultBg "`n"
      iniContent .= "PageImage=" defaultPage "`n"
      iniContent .= "MenuBackground=" defaultMenu "`n"
      iniContent .= "FontColor=FDFDFD`n"
      iniContent .= "CurrentTheme=Dark`n"
      iniContent .= "btn_mainPage=" defaultBtn "`n"
      iniContent .= "btn_fontColor=FDFDFD`n"
      iniContent .= "titleImage=" defaultTitle "`n"
      iniContent .= "TopBarBig=" defaultTopBarBig "`n"
      iniContent .= "TopBarSmall=" defaultTopBarSmall "`n"
      iniContent .= "TopBarOpen=" defaultTopBarOpen "`n"
      iniContent .= "TopBarClose=" defaultTopBarClose "`n"
      iniContent .= "MenuOpen=" defaultMenuOpen "`n"
      iniContent .= "MenuClose=" defaultMenuClose "`n"
      iniContent .= "ToolTipImage=" defaultToolTip "`n"
      iniContent .= "FriendID=`n"
      iniContent .= "AccountName=`n"
      iniContent .= "waitTime=1`n"
      iniContent .= "Delay=250`n"
      iniContent .= "folderPath=C:\Program Files\Netease`n"
      iniContent .= "Columns=5`n"
      iniContent .= "godPack=Continue`n"
      iniContent .= "Instances=1`n"
      iniContent .= "instanceStartDelay=5`n"
      iniContent .= "defaultLanguage=Scale125`n"
      iniContent .= "SelectedMonitorIndex=1`n"
      iniContent .= "swipeSpeed=250`n"
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
      iniContent .= "isDarkTheme=1`n"
      iniContent .= "useBackgroundImage=1`n"
      iniContent .= "rowGap=75`n"
      iniContent .= "variablePackCount=15`n"
      iniContent .= "claimSpecialMissions=0`n"
      iniContent .= "spendHourGlass=0`n"
      iniContent .= "injectSortMethod=ModifiedAsc`n"
      iniContent .= "waitForEligibleAccounts=1`n"
      iniContent .= "maxWaitHours=24`n"
      iniContent .= "menuExpanded=True`n"
      
      FileAppend, %iniContent%, Settings.ini, UTF-16
      return true
   }
   return false
}

SaveAllSettings() {
   global IsLanguageSet, defaultBotLanguage, BotLanguage, currentfont, BackgroundImage, PageImage, MenuBackground, FontColor
   global CurrentTheme, btn_mainPage, btn_fontColor, titleImage, ToolTipImage
   global TopBarBig, TopBarSmall, TopBarOpen, TopBarClose, MenuOpen, MenuClose
   global shownLicense
   global FriendID, AccountName, waitTime, Delay, folderPath, discordWebhookURL, discordUserId, Columns, godPack
   global Instances, instanceStartDelay, defaultLanguage, SelectedMonitorIndex, swipeSpeed, deleteMethod
   global runMain, Mains, heartBeat, heartBeatWebhookURL, heartBeatName, nukeAccount, packMethod
   global autoLaunchMonitor, autoUseGPTest, TestTime
   global CheckShinyPackOnly, TrainerCheck, FullArtCheck, RainbowCheck, ShinyCheck, CrownCheck
   global InvalidCheck, ImmersiveCheck, PseudoGodPack, minStars, Palkia, Dialga, Arceus, Shining
   global Mew, Pikachu, Charizard, Mewtwo, Solgaleo, Lunala, Buzzwole, Eevee, HoOh, Lugia, slowMotion, ocrLanguage, clientLanguage
   global CurrentVisibleSection, heartBeatDelay, sendAccountXml, showcaseEnabled, isDarkTheme
   global useBackgroundImage, tesseractPath, applyRoleFilters, debugMode, tesseractOption, statusMessage
   global s4tEnabled, s4tSilent, s4t3Dmnd, s4t4Dmnd, s4t1Star, s4tGholdengo, s4tWP, s4tWPMinCards
   global s4tDiscordUserId, s4tDiscordWebhookURL, s4tSendAccountXml, minStarsShiny, instanceLaunchDelay, mainIdsURL, vipIdsURL
   global spendHourGlass, openExtraPack, injectSortMethod, rowGap, SortByDropdown
   global waitForEligibleAccounts, maxWaitHours, skipMissionsInjectMissions
   global minStarsEnabled, minStarsA1Mewtwo, minStarsA1Charizard, minStarsA1Pikachu, minStarsA1a
   global minStarsA2Dialga, minStarsA2Palkia, minStarsA2a, minStarsA2b
   global minStarsA3Solgaleo, minStarsA3Lunala, minStarsA3a, minStarsA3b
   global menuExpanded
   
   iniContent := "[UserSettings]`n"
   iniContent .= "isLanguageSet=" IsLanguageSet "`n"
   iniContent .= "defaultBotLanguage=" defaultBotLanguage "`n"
   iniContent .= "BotLanguage=" BotLanguage "`n"
   iniContent .= "shownLicense=" shownLicense "`n"
   iniContent .= "CurrentTheme=" CurrentTheme "`n"
   iniContent .= "btn_mainPage=" btn_mainPage "`n"
   iniContent .= "btn_fontColor=" btn_fontColor "`n"
   iniContent .= "titleImage=" titleImage "`n"
   iniContent .= "TopBarBig=" TopBarBig "`n"
   iniContent .= "TopBarSmall=" TopBarSmall "`n"
   iniContent .= "TopBarOpen=" TopBarOpen "`n"
   iniContent .= "TopBarClose=" TopBarClose "`n"
   iniContent .= "MenuOpen=" MenuOpen "`n"
   iniContent .= "MenuClose=" MenuClose "`n"
   iniContent .= "ToolTipImage=" ToolTipImage "`n"
   ;CheckBox
   iniContent .= "runMain=" runMain "`n"
   iniContent .= "autoUseGPTest=" autoUseGPTest "`n"
   iniContent .= "slowMotion=" slowMotion "`n"
   iniContent .= "autoLaunchMonitor=" autoLaunchMonitor "`n"
   iniContent .= "applyRoleFilters=" applyRoleFilters "`n"
   iniContent .= "debugMode=" debugMode "`n"
   iniContent .= "tesseractOption=" tesseractOption "`n"
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
   iniContent .= "s4tWP=" s4tWP "`n"
   iniContent .= "s4tSendAccountXml=" s4tSendAccountXml "`n"
   iniContent .= "sendAccountXml=" sendAccountXml "`n"
   iniContent .= "heartBeat=" heartBeat "`n"
   
   iniContent .= "menuExpanded=" menuExpanded "`n"
   
   Gui, % MainGuiName . ":Submit", NoHide
   if (deleteMethod = "" || deleteMethod = "ERROR") {
      deleteMethod := "13 Pack"
   }
   validMethods := "13 Pack|Inject|Inject Missions|Inject for Reroll"
   if (!InStr(validMethods, deleteMethod)) {
      deleteMethod := "13 Pack"
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
   if (deleteMethod = "Inject for Reroll" || deleteMethod = "13 Pack") {
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
   iniContent_Second .= "s4tWPMinCards=" s4tWPMinCards "`n"
   iniContent_Second .= "s4tDiscordUserId=" s4tDiscordUserId "`n"
   iniContent_Second .= "s4tDiscordWebhookURL=" s4tDiscordWebhookURL "`n"
   iniContent_Second .= "minStarsShiny=" minStarsShiny "`n"
   iniContent_Second .= "tesseractPath=" tesseractPath "`n"
   
   Gui, TopBar:Submit, NoHide
   iniContent_third := "currentfont=" currentfont "`n"
   iniContent_third .= "BackgroundImage=" BackgroundImage "`n"
   iniContent_third .= "PageImage=" PageImage "`n"
   iniContent_third .= "MenuBackground=" MenuBackground "`n"
   iniContent_third .= "FontColor=" FontColor "`n"
   ;iniContent .= "isDarkTheme=" isDarkTheme "`n"
   ;iniContent .= "useBackgroundImage=" useBackgroundImage "`n"
   iniFull := iniContent . iniContent_Second . iniContent_third
   FileDelete, Settings.ini
   FileAppend, %iniFull%, Settings.ini, UTF-16
   
   if (debugMode) {
      FileAppend, % A_Now . " - Settings saved. DeleteMethod: " . deleteMethod . "`n", %A_ScriptDir%\debug_settings.log
   }
}

IsNumeric(var) {
   if var is number
      return true
   return false
}

SetNormalFont() {
   global currentfont, FontColor
   Gui, Font, norm s9 c%FontColor%, %currentfont%
}

SetMenuBtnFont() {
   global currentfont, btn_fontColor
   Gui, Font, norm s10 c%btn_fontColor%, %currentfont%
}

SetTopBarBtnFont() {
   global currentfont, btn_fontColor
   Gui, Font, norm s9 c%btn_fontColor%, %currentfont%
}

SetHeaderFont() {
   global currentfont, FontColor
   Gui, Font, norm s11 c%FontColor%, %currentfont%
}

SetSectionFont() {
   global currentfont, FontColor
   Gui, Font, norm s10 c%FontColor%, %currentfont%
}

setMenuNormalFont() {
   global currentfont
   Gui, Menu:Font, norm s8 c%btn_fontColor%, %currentfont%
}

SetTopBarSmallBtnFont() { ;For toolbar e.g. background,theme
   global currentfont
   Gui, TopBar:Font, norm s9 c000000, %currentfont%
}

setTopBarNormalFont() {
   global currentfont
   Gui, TopBar:Font, norm s9 c000000, %currentfont%
}

ApplyInputStyle() {
   global FontColor
   Gui, TopBarColor:Color,, %FontColor%
   GuiControl, TopBarColor:MoveDraw, ColorBlock
   GuiControl, TopBarColor:, ColorBlock, % " "
}

AddCheckBox(options) {
   ; options: {x, y, w, h, vName, gName, checkedImagePath, uncheckedImagePath, isChecked, vTextName, text, textX, textY}
   imagePath := options.isChecked ? options.checkedImagePath : options.uncheckedImagePath
   gName := (options.gName = "" ? "CheckBoxToggle" : options.gName)
   
   Gui, Add, Picture
      , % "x" . options.x . " y" . options.y . " w" . options.w . " h" . options.h . " v" . options.vName
      . " g" . gName
      . " BackgroundTrans"
      , %imagePath%
   
   if (options.HasKey("vTextName") && options.HasKey("textX") && options.HasKey("textY")) {
      Gui, Add, Text, % "x" . options.textX . " y" . options.textY . " v" . options.vTextName . " BackgroundTrans", % options.text
   }
}

AddBtn(options) {
   type := options.type ? Trim(options.type) : "Button"
   GuiOptions := ""
   if (options.HasKey("x"))
      GuiOptions .= "x" . options.x . " "
   if (options.HasKey("y"))
      GuiOptions .= "y" . options.y . " "
   if (options.HasKey("w"))
      GuiOptions .= "w" . options.w . " "
   if (options.HasKey("h"))
      GuiOptions .= "h" . options.h . " "
   if (options.HasKey("vName"))
      GuiOptions .= "v" . options.vName . " "
   if (options.HasKey("gName") && options.gName != "")
      GuiOptions .= "g" . options.gName . " "
   GuiOptions .= "BackgroundTrans"
   Gui, Menu:Add, %type%, %GuiOptions%, % options.imagePath
   
   if (options.HasKey("vTextName") && options.HasKey("text")) {
      TextOptions := ""
      if (options.HasKey("textX"))
         TextOptions .= "x" . options.textX . " "
      if (options.HasKey("textY"))
         TextOptions .= "y" . options.textY . " "
      if (options.HasKey("w"))
         TextOptions .= "w" . options.w . " "
      if (options.HasKey("h"))
         TextOptions .= "h" . options.h . " "
      TextOptions .= "v" . options.vTextName . " BackgroundTrans Center"
      Gui, Menu:Add, Text, %TextOptions%, % options.text
   }
}

AddBtnforTop(options) {
   type := options.type ? Trim(options.type) : "Button"
   GuiOptions := ""
   if (options.HasKey("x"))
      GuiOptions .= "x" . options.x . " "
   if (options.HasKey("y"))
      GuiOptions .= "y" . options.y . " "
   if (options.HasKey("w"))
      GuiOptions .= "w" . options.w . " "
   if (options.HasKey("h"))
      GuiOptions .= "h" . options.h . " "
   if (options.HasKey("vName"))
      GuiOptions .= "v" . options.vName . " "
   if (options.HasKey("gName") && options.gName != "")
      GuiOptions .= "g" . options.gName . " "
   GuiOptions .= "BackgroundTrans"
   Gui, TopBar:Add, %type%, %GuiOptions%, % options.imagePath
   
   if (options.HasKey("vTextName") && options.HasKey("text")) {
      TextOptions := ""
      if (options.HasKey("textX"))
         TextOptions .= "x" . options.textX . " "
      if (options.HasKey("textY"))
         TextOptions .= "y" . options.textY . " "
      if (options.HasKey("w"))
         TextOptions .= "w" . options.w . " "
      if (options.HasKey("h"))
         TextOptions .= "h" . options.h . " "
      TextOptions .= "v" . options.vTextName . " BackgroundTrans Center"
      Gui, TopBar:Add, Text, %TextOptions%, % options.text
   }
}

ShowControls(controlList) {
   Loop, Parse, controlList, `,
   {
      if (A_LoopField)
         GuiControl, Show, %A_LoopField%
   }
}

; Function to hide multiple controls at once
HideControls(controlList) {
   Loop, Parse, controlList, `,
   {
      if (A_LoopField)
         GuiControl, Hide, %A_LoopField%
   }
}

MinStarCheck(vName) {
   value := %vName%
   if (value = "" || value = 0)
      return 1
   if (value >= 1 && value <= 5)
      return value + 1
   return 0
}

ExpandTopBar() {
   global
   ; get current x, y
   GuiControlGet, reloadPos, TopBar:Pos, Btn_reload
   GuiControlGet, classicPos, TopBar:Pos, Btn_ClassicMode
   GuiControlGet, TxtReloadPos, TopBar:Pos, Txt_Btn_reload
   GuiControlGet, TxtClassicPos, TopBar:Pos, Txt_Btn_ClassicMode
   
   GuiControl, TopBar:Move, Btn_reload, % "y" . (reloadPosY + 15)
   GuiControl, TopBar:Move, Btn_ClassicMode, % "y" . (classicPosY + 15)
   
   GuiControl, TopBar:Move, Txt_Btn_reload, % "y" . (TxtreloadPosY + 15)
   GuiControl, TopBar:Move, Txt_Btn_ClassicMode, % "y" . (TxtclassicPosY + 15)
}

CloseTopBar() {
   global
   GuiControlGet, reloadPos, TopBar:Pos, Btn_reload
   GuiControlGet, classicPos, TopBar:Pos, Btn_ClassicMode
   GuiControlGet, TxtReloadPos, TopBar:Pos, Txt_Btn_reload
   GuiControlGet, TxtClassicPos, TopBar:Pos, Txt_Btn_ClassicMode
   
   GuiControl, TopBar:Move, Btn_reload, % "y" . (reloadPosY - 15)
   GuiControl, TopBar:Move, Btn_ClassicMode, % "y" . (classicPosY - 15)
   
   GuiControl, TopBar:Move, Txt_Btn_reload, % "y" . (TxtReloadPosY - 15)
   GuiControl, TopBar:Move, Txt_Btn_ClassicMode, % "y" . (TxtclassicPosY - 15)
}

MenuSwitchHandler:
   WinSet, AlwaysOnTop, On, ahk_id %menuHwnd%
   WinSet, AlwaysOnTop, On, ahk_id %mainHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %menuHwnd%
   WinSet, AlwaysOnTop, Off, ahk_id %mainHwnd%
   global menuExpanded, mainHwnd, menuW, menuH
   WinGetPos, mainX, mainY, mainW, mainH, ahk_id %mainHwnd%
   steps := 20
   stepSize := Ceil(menuW / steps) + 5
   if (!menuExpanded) {
      ; open
      Loop, %steps%
      {
         menuX := mainX + mainW - menuW + (A_Index * stepSize)
         if (menuX > mainX + mainW - 5)
            menuX := mainX + mainW - 5
         Gui, Menu:Show, % "x" . menuX . " y" . mainY . " NoActivate"
         
         Sleep, 15
      }
      GuiControl, Menu:, MenuSwitch, %MenuClose%
      menuExpanded := true
   } else {
      ; close
      Loop, %steps%
      {
         menuX := mainX + mainW - (A_Index * stepSize)
         if (menuX < mainX + mainW - menuW - 35)
            menuX := mainX + mainW - menuW - 35
         Gui, Menu:Show, % "x" . menuX . " y" . mainY . " NoActivate"
         
         Sleep, 15
      }
      GuiControl, Menu:, MenuSwitch, %MenuOpen%
      menuExpanded := false
   }
return

TopBarSwitchHandler:
   global topBarExpanded, topBarW, topBarH, topBarHwnd
   steps := 15
   minH := 36
   maxH := 440
   additionalCount := 15
   WinGetPos, barX, barY, , , ahk_id %topBarHwnd%
   if (!topBarExpanded) {
      ; open
      ExpandTopBar()
      GuiControl, TopBar:, TopBarBackground, %TopBarBig%
      Loop, %steps%
      {
         curH := minH + Ceil((maxH - minH) * (A_Index / steps))
         if (curH > maxH)
            curH := maxH
         Gui, TopBar:Show, % "x" . barX . " y" . barY . " w" . topBarW . " h" . curH . " NoActivate"
         additionalCount := additionalCount + 6
         UpdateTopBarSwitchPos(barX, barY + curH + additionalCount)
         Sleep, 15
      }
      GuiControl, TopBarColor:Show, ColorBlock
      GuiControl, TopBarSwitch:, SwitchPic, %TopBarClose%
      UpdateTopBarSwitchPos(barX, barY + maxH + 107)
      Gui, TopBarColor:Show, w15 h15 NoActivate
      topBarExpanded := true
   } else {
      Gui, TopBarColor:Show, w0 h0 NoActivate
      ; close
      additionalCount := 107
      CloseTopBar()
      GuiControl, TopBar:, TopBarBackground, %TopBarSmall%
      Loop, %steps%
      {
         curH := maxH - Ceil((maxH - minH) * (A_Index / steps))
         if(curH < minH)
            curH := minH
         Gui, TopBar:Show, % "x" . barX . " y" . barY . " w" . topBarW . " h" . curH . " NoActivate"
         additionalCount := additionalCount - 7
         UpdateTopBarSwitchPos(barX, barY + curH + additionalCount)
         Sleep, 15
      }
      GuiControl, TopBarColor:Hide, ColorBlock
      GuiControl, TopBarSwitch:, SwitchPic, %TopBarOpen%
      UpdateTopBarSwitchPos(barX, barY + minH + 9)
      topBarExpanded := false
   }
return

CheckBoxToggle:
   varName := A_GuiControl
   newValue := !%varName%
   %varName% := newValue
   GuiControl,, %varName%, % newValue ? checkedPath : uncheckedPath
return

runMainSettings:
   runMain := !runMain
   if (runMain) {
      GuiControl,, runMain, %checkedPath%
   } else {
      GuiControl,, runMain, %uncheckedPath%
   }
   
   if (runMain) {
      GuiControl, Show, Mains
   } else {
      GuiControl, Hide, Mains
   }
return

autoUseGPTestSettings:
   autoUseGPTest := !autoUseGPTest
   if (autoUseGPTest) {
      GuiControl,, autoUseGPTest, %checkedPath%
   } else {
      GuiControl,, autoUseGPTest, %uncheckedPath%
   }
   
   if (autoUseGPTest) {
      GuiControl, Show, TestTime
   } else {
      GuiControl, Hide, TestTime
   }
return

defaultLangSetting:
   global scaleParam
   if (defaultLanguage = "Scale125") {
      scaleParam := 277
      MsgBox, 0x40000,, Scale set to 125`% with scaleParam = %scaleParam%
   } else if (defaultLanguage = "Scale100") {
      scaleParam := 287
      MsgBox, 0x40000,, Scale set to 100`% with scaleParam = %scaleParam%
   }
return

useTesseractSettings:
   tesseractOption := !tesseractOption
   if (tesseractOption) {
      GuiControl,, tesseractOption, %checkedPath%
   } else {
      GuiControl,, tesseractOption, %uncheckedPath%
   }
   
   if (tesseractOption) {
      GuiControl, Show, Txt_TesseractPath
      GuiControl, Show, tesseractPath
   } else {
      GuiControl, Hide, Txt_TesseractPath
      GuiControl, Hide, tesseractPath
   }
return

minStarsEnabledSettings:
   minStarsEnabled := !minStarsEnabled
   controlsList := "Txt_minStarsA3b,minStarsA3b,Txt_minStarsA3a,minStarsA3a,"
   controlsList .= "Txt_minStarsA3Solgaleo,minStarsA3Solgaleo,Txt_minStarsA3Lunala,minStarsA3Lunala,"
   controlsList .= "Txt_minStarsA2b,minStarsA2b,Txt_minStarsA2a,minStarsA2a,"
   controlsList .= "Txt_minStarsA2Palkia,minStarsA2Palkia,Txt_minStarsA2Dialga,minStarsA2Dialga,"
   controlsList .= "Txt_minStarsA1Pikachu,minStarsA1Pikachu,Txt_minStarsA1Mewtwo,minStarsA1Mewtwo,"
   controlsList .= "Txt_minStarsA1Charizard,minStarsA1Charizard,Txt_minStarsA1a,minStarsA1a"
   if (minStarsEnabled) {
      GuiControl,, minStarsEnabled, %checkedPath%
      ShowControls(controlsList)
   } else {
      GuiControl,, minStarsEnabled, %uncheckedPath%
      HideControls(controlsList)
   }
return

deleteSettings:
   global scaleParam, defaultLanguage
   
   currentScaleParam := scaleParam
   GuiControlGet, currentMethod,, deleteMethod
   deleteMethod := currentMethod
   ShowCheck(name, checked := "") {
      if (checked != "")
         GuiControl,, %name%, % checked ? checkedPath : uncheckedPath
      GuiControl, Show, %name%
      GuiControl, Show, Txt_%name%
   }
   HideCheck(name) {
      GuiControl, Hide, %name%
      GuiControl, Hide, Txt_%name%
   }
   
   extraControls := ["openExtraPack", "packMethod"]
   sortControls := ["SortByText", "SortByDropdown"]
   
   if InStr(currentMethod, "Inject") {
      HideCheck("nukeAccount")
      nukeAccount := 0
      ShowCheck("spendHourGlass", spendHourGlass)
      for _, ctrl in sortControls
         GuiControl, Show, %ctrl%
      if (currentMethod = "Inject for Reroll") {
         for _, ctrl in extraControls
            ShowCheck(ctrl, %ctrl%)
      } else {
         for _, ctrl in extraControls {
            HideCheck(ctrl)
            %ctrl% := 0
         }
      }
   } else {
      ShowCheck("nukeAccount", nukeAccount)
      HideCheck("spendHourGlass")
      for _, ctrl in extraControls {
         HideCheck(ctrl)
         %ctrl% := 0
      }
      for _, ctrl in sortControls
         GuiControl, Hide, %ctrl%
   }
   
   if (defaultLanguage = "Scale125")
      scaleParam := 277
   else if (defaultLanguage = "Scale100")
      scaleParam := 287
   
   if (debugMode && scaleParam != currentScaleParam)
      MsgBox, 0x40000,, Scale parameter updated: %scaleParam% (Was: %currentScaleParam%)
return

spendHourGlassSettings:
   spendHourGlass := !spendHourGlass
   if (spendHourGlass) {
      GuiControl,, spendHourGlass, %checkedPath%
      openExtraPack := 0
      GuiControl,, openExtraPack, %uncheckedPath%
   } else {
      GuiControl,, spendHourGlass, %uncheckedPath%
   }
return

openExtraPackSettings:
   openExtraPack := !openExtraPack
   if (openExtraPack) {
      GuiControl,, openExtraPack, %checkedPath%
      spendHourGlass := 0
      GuiControl,, spendHourGlass, %uncheckedPath%
   } else {
      GuiControl,, openExtraPack, %uncheckedPath%
   }
return

SortByDropdownHandler:
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
return

s4tSettings:
   global s4tMainControls := "s4tSilent,s4t3Dmnd,s4t4Dmnd,s4t1Star,S4T_Divider1,s4tWP,S4T_Divider2,"
   s4tMainControls .= "Txt_s4tSilent,Txt_s4t3Dmnd,Txt_s4t4Dmnd,Txt_s4t1Star,Txt_s4tWP,"
   s4tMainControls .= "Txt_s4tSendAccountXml,S4TDiscordSettingsSubHeading,Txt_S4T_DiscordID,s4tDiscordUserId,"
   s4tMainControls .= "Txt_S4T_DiscordWebhook,s4tDiscordWebhookURL,s4tSendAccountXml,SaveForTradeDivider_1,SaveForTradeDivider_2"
   global s4tAllControls := s4tMainControls . ",s4tGholdengo,s4tGholdengoEmblem,s4tGholdengoArrow,s4tWPMinCardsLabel,s4tWPMinCards"
   ; Function to show multiple controls at once
   s4tEnabled := !s4tEnabled
   GuiControl,, s4tEnabled, % s4tEnabled ? checkedPath : uncheckedPath
   
   if (s4tEnabled) {
      ShowControls(s4tMainControls)
      ; Gholdengo show/hide
      if (Shining) {
         ShowControls("s4tGholdengo,s4tGholdengoEmblem,s4tGholdengoArrow")
      } else {
         HideControls("s4tGholdengo,s4tGholdengoEmblem,s4tGholdengoArrow")
      }
      ; s4tWP show/hide
      if (s4tWP) {
         ShowControls("s4tWPMinCardsLabel,s4tWPMinCards")
      } else {
         HideControls("s4tWPMinCardsLabel,s4tWPMinCards")
      }
   } else {
      HideControls(s4tAllControls)
   }
return

s4tWPSettings:
   s4tWP := !s4tWP
   GuiControl,, s4tWP, % s4tWP ? checkedPath : uncheckedPath
   
   if (s4tWP) {
      GuiControl, Show, s4tWPMinCardsLabel
      GuiControl, Show, s4tWPMinCards
   } else {
      GuiControl, Hide, s4tWPMinCardsLabel
      GuiControl, Hide, s4tWPMinCards
   }
return

discordSettings:
   global heartbeatControls := "heartBeatName,heartBeatWebhookURL,heartBeatDelay,hbName,hbURL,hbDelay"
   heartBeat := !heartBeat
   GuiControl,, heartBeat, % heartBeat ? checkedPath : uncheckedPath
   if (heartBeat)
      ShowControls(heartbeatControls)
   else
      HideControls(heartbeatControls)
return

ArrangeWindows:
   SaveAllSettings()
   LoadSettingsFromIni()
   ; Re-validate scaleParam based on current language
   if (defaultLanguage = "Scale125") {
      scaleParam := 277
   } else if (defaultLanguage = "Scale100") {
      scaleParam := 287
   }
   
   windowsPositioned := 0
   
   if (runMain && Mains > 0) {
      Loop %Mains% {
         mainInstanceName := "Main" . (A_Index > 1 ? A_Index : "")
         ; Use exact matching for Main windows
         SetTitleMatchMode, 3 ; Exact match
         if (WinExist(mainInstanceName)) {
            WinActivate, %mainInstanceName%
            WinGetPos, curX, curY, curW, curH, %mainInstanceName%
            
            ; Calculate position
            SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
            SysGet, Monitor, Monitor, %SelectedMonitorIndex%
            
            instanceIndex := A_Index
            rowHeight := 533
            currentRow := Floor((instanceIndex - 1) / Columns)
            y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
            x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
            
            ; Move window
            WinMove, %mainInstanceName%,, %x%, %y%, %scaleParam%, 537
            WinSet, Redraw, , %mainInstanceName%
            
            windowsPositioned++
            sleep, 100
         }
      }
   }
   
   if (Instances > 0) {
      Loop %Instances% {
         ; Use exact window title matching with SetTitleMatchMode
         SetTitleMatchMode, 3 ; Exact match
         windowTitle := A_Index
         
         if (WinExist(windowTitle)) {
            WinActivate, %windowTitle%
            WinGetPos, curX, curY, curW, curH, %windowTitle%
            
            ; Calculate position
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
            
            ; Move window
            WinMove, %windowTitle%,, %x%, %y%, %scaleParam%, 537
            WinSet, Redraw, , %windowTitle%
            
            windowsPositioned++
            sleep, 100
         }
      }
   }
   
   if (debugMode && windowsPositioned == 0) {
      MsgBox, 0x40000,, No windows found to arrange
   } else {
      MsgBox, 0x40000,, Arranged %windowsPositioned% windows
   }
   
   ; Save settings after arranging windows
   SaveAllSettings()
return

LaunchAllMumu:
   SaveAllSettings()
   LoadSettingsFromIni()
   
   ; Save settings before launching
   SaveAllSettings()
   
   if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
      MsgBox, 0x40000,, ERROR: bot folder path is too long or contains blank spaces. Move it to a shorter path without spaces, such as C:\PTCGPB
      return
   }
   
   launchAllFile := A_ScriptDir . "\Scripts\Include\LaunchAllMumu.ahk"
   if(FileExist(launchAllFile)) {
      Run, %launchAllFile%
   }
return

OpenClassicMode:
   SaveAllSettings()
   Run, %A_ScriptDir%\Scripts\Include\ClassicMode.ahk
ExitApp
return

; ToolTip
OpenToolTip:
   ;WinMinimize, ahk_id %mainHwnd%
   Run, https://mixman208.github.io/PTCGPB/
return

; Handle the link click
OpenLink:
   ;WinMinimize, ahk_id %mainHwnd%
   Run, https://buymeacoffee.com/aarturoo
return

OpenDiscord:
   ;WinMinimize, ahk_id %mainHwnd%
   Run, https://discord.gg/C9Nyf7P4sT
return

RunXMLSortTool:
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   WinMinimize, ahk_id %menuHwnd%
   Tool := A_ScriptDir . "\Accounts\xmlCounter.ahk"
   RunWait, %Tool%
   WinRestore, ahk_id %menuHwnd%
   WinActivate, ahk_id %menuHwnd%
   CallOthers := 0
Return

RunXMLDuplicateTool:
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   WinMinimize, ahk_id %menuHwnd%
   Tool := A_ScriptDir . "\Accounts\xml_duplicate_finder.ahk"
   RunWait, %Tool%
   WinRestore, ahk_id %menuHwnd%
   WinActivate, ahk_id %menuHwnd%
   CallOthers := 0
Return

; IMPROVED: Ensure settings are saved completely before reload
SaveReload:
   ; Save all settings using our comprehensive function
   SaveAllSettings()
   ; Reload the script
   Reload
return

LanguageControl:
   GuiControlGet, curLang,, TopBotLanguage
   BotLanguage := curLang
   langMap := { "English": 1, "中文": 2, "日本語": 3, "Deutsch": 4 }
   defaultBotLanguage := langMap.HasKey(BotLanguage) ? langMap[BotLanguage] : 1
   GuiControl, TopBar:Show, saveTopBar
Return

ChooseFont:
   global selectedFont
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   selectedFont := ""
   ShowFontListGui("selectedFont")
   if (selectedFont = "")
      selectedFont := "Segoe UI"
   GuiControl,TopBar:, currentfont, %selectedFont%
   GuiControl, TopBar:Show, saveTopBar
   WinSet, AlwaysOnTop, On, ahk_id %topBarColorHwnd%
   CallOthers := 0
return

FontListOK:
   global FontChoice
   Gui, FontList:Submit
   selectedFont := FontChoice
   Gui, FontList:Destroy
return

ChooseBackground:
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   FileSelectFile, selectedFile, 3, , Please select a background image, Image Files (*.jpg; *.png)
   if (selectedFile != "") {
      BackgroundImage := selectedFile
      GuiControl, TopBar:, BackgroundImage, %BackgroundImage%
   }
   GuiControl, TopBar:Show, saveTopBar
   WinSet, AlwaysOnTop, On, ahk_id %topBarColorHwnd%
   CallOthers := 0
return

ChoosePage:
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   FileSelectFile, selectedFile, 3, , Please select a Page image, Image Files (*.jpg; *.png)
   if (selectedFile != "") {
      PageImage := selectedFile
      GuiControl, TopBar:, PageImage, %PageImage%
   }
   GuiControl, TopBar:Show, saveTopBar
   WinSet, AlwaysOnTop, On, ahk_id %topBarColorHwnd%
   CallOthers := 0
return

ChooseMenu:
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   FileSelectFile, selectedFile, 3, , Please select a Menu image, Image Files (*.jpg; *.png)
   if (selectedFile != "") {
      MenuBackground := selectedFile
      GuiControl, TopBar:, MenuBackground, %MenuBackground%
   }
   GuiControl, TopBar:Show, saveTopBar
   WinSet, AlwaysOnTop, On, ahk_id %topBarColorHwnd%
   CallOthers := 0
return

ChooseFontColor:
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   result := ChooseColors("", FontColor)
   temp := FontColor
      ,FontColor := result.1
   if (FontColor = "") {
      FontColor := temp
   }
   GuiControl, TopBar:, FontColor, %FontColor%
   ApplyInputStyle()
   GuiControl, TopBar:Show, saveTopBar
   WinSet, AlwaysOnTop, On, ahk_id %topBarColorHwnd%
   CallOthers := 0
return

ToggleTheme:
   Front := A_ScriptDir . "\GUI\Images\"
      ,CurrentTheme := (CurrentTheme = "Dark"? "Light": "Dark")
      ,btn_mainPage := Front . (CurrentTheme = "Dark"? "panel2.png": "panel1.png")
      ,ToolTipImage := Front . (CurrentTheme = "Dark"? "ToolTip2.png": "ToolTip1.png")
      ,btn_fontColor := CurrentTheme = "Dark"? "FDFDFD": "CC0000"
      ,titleImage := Front . (CurrentTheme = "Dark"? "Title2.png": "Title1.png")
      ,TopBarBig := Front . (CurrentTheme = "Dark"? "TopBarBig2.png": "TopBarBig1.png")
      ,TopBarSmall := Front . (CurrentTheme = "Dark"? "TopBarSmall2.png": "TopBarSmall1.png")
      ,TopBarOpen := Front . (CurrentTheme = "Dark"? "TopBarOpen2.png": "TopBarOpen1.png")
      ,TopBarClose := Front . (CurrentTheme = "Dark"? "TopBarClose2.png": "TopBarClose1.png")
      ,MenuOpen := Front . (CurrentTheme = "Dark" ? "MenuOpen2.png":"MenuOpen1.png")
      ,MenuClose := Front . (CurrentTheme = "Dark" ? "MenuClose2.png":"MenuClose1.png")
      ,PageImage := Front . (CurrentTheme = "Dark"? "Page2.png": "Page1.png")
      ,BackgroundImage := Front . (CurrentTheme = "Dark"? "Background2.png": "Background1.png")
      ,MenuBackground := Front . (CurrentTheme = "Dark"? "Menu2.png": "Menu1.png")
      ,FontColor := CurrentTheme = "Dark"? "FDFDFD": "000000"
   GuiControl, TopBar:, MenuBackground, %MenuBackground%
   GuiControl, TopBar:, BackgroundImage, %BackgroundImage%
   GuiControl, TopBar:, PageImage, %PageImage%
   GuiControl, TopBar:, FontColor, %FontColor%
   SaveAllSettings()
   Reload
Return

SaveTopBarSettings:
   SaveAllSettings()
   Reload
Return

BalanceXMLs:
   if(Instances>0) {
      ; Save all settings first to ensure Instances is up to date
      SaveAllSettings()
      LoadSettingsFromIni()
      ;todo better status message location or method
      GuiControlGet, ButtonPos, Pos, BalanceXMLs
      XTooltipPos = % ButtonPosX + 10
      YTooltipPos = % ButtonPosY + 140
      
      ;check folders
      saveDir := A_ScriptDir "\Accounts\Saved\"
      if !FileExist(saveDir) ; Check if the directory exists
         FileCreateDir, %saveDir% ; Create the directory if it doesn't exist
      
      tmpDir := A_ScriptDir "\Accounts\Saved\tmp"
      if !FileExist(tmpDir) ; Check if the directory exists
         FileCreateDir, %tmpDir% ; Create the directory if it doesn't exist
      
      ;lags gui for some reason
      Tooltip, Moving Files and Folders to tmp, XTooltipPos, YTooltipPos
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
      ; create instance dirs
      Loop , %Instances%
      {
         instanceDir := saveDir . "\" . A_Index
         if !FileExist(instanceDir) ; Check if the directory exists
            FileCreateDir, %instanceDir% ; Create the directory if it doesn't exist
         listfile := instanceDir . "\list.txt"
         if FileExist(listfile)
            FileDelete, %listfile% ; delete list if it exists
      }
      
      ToolTip, Checking for Duplicate names, XTooltipPos, YTooltipPos
      fileList := ""
      seenFiles := {}
      Loop, Files, %tmpDir%\*.xml, R
      {
         fileName := A_LoopFileName
         fileTime := A_LoopFileTimeModified
         ; TODO can also sort by name (num packs), or time created
         fileTime := A_LoopFileTimeCreated
         filePath := A_LoopFileFullPath
         
         if seenFiles.HasKey(fileName)
         {
            ; Compare the timestamps to determine which file is older
            prevTime := seenFiles[fileName].Time
            prevPath := seenFiles[fileName].Path
            
            if (fileTime > prevTime)
            {
               ; Current file is newer, delete the previous one
               FileDelete, %prevPath%
               seenFiles[fileName] := {Time: fileTime, Path: filePath}
            }
            else
            {
               ; Current file is older, delete it
               FileDelete, %filePath%
            }
            continue
         }
         
         ; Store the file info
         seenFiles[fileName] := {Time: fileTime, Path: filePath}
         fileList .= fileTime "`t" filePath "`n"
      }
      
      ToolTip, Sorting by modified date, XTooltipPos, YTooltipPos
      Sort, fileList, R
      
      ToolTip, Distributing XMLs between folders...please wait, XTooltipPos, YTooltipPos
      instance := 1
      Loop, Parse, fileList, `n
      {
         if (A_LoopField = "")
            continue
         
         ; Split each line into timestamp and file path (split by tab)
         StringSplit, parts, A_LoopField, %A_Tab%
         tmpFile := parts2 ; Get the file path from the second part
         toDir := saveDir . "\" . instance
         
         ; Move the file
         FileMove, %tmpFile%, %toDir%, 1
         
         instance++
         if (instance > Instances)
            instance := 1
      }
      
      ;count number of xmls with date modified time over 24 hours in instance 1
      instanceOneDir := saveDir . "1"
      counter := 0
      counter2 := 0
      Loop, Files, %instanceOneDir%\*.xml
      {
         fileModifiedTimeDiff := A_Now
         FileGetTime, fileModifiedTime, %A_LoopFileFullPath%, M
         EnvSub, fileModifiedTimeDiff, %fileModifiedTime%, Hours
         if (fileModifiedTimeDiff >= 24) ; 24 hours
            counter++
      }
      
      Tooltip ;clear tooltip
      MsgBox, 0x40000,XML Balance,Done balancing XMLs between %Instances% instances`n%counter% XMLs past 24 hours per instance
   }
return

CheckForUpdates:
   CheckForUpdate()
return

; Function to reset all account lists (automatically called on startup)
ResetAccountLists() {
   ; Check if ResetLists.ahk exists before trying to run it
   resetListsPath := A_ScriptDir . "\Scripts\Include\ResetLists.ahk"
   
   if (FileExist(resetListsPath)) {
      ; Run the ResetLists.ahk script without waiting
      Run, %resetListsPath%,, Hide UseErrorLevel
      
      ; Very short delay to ensure process starts
      Sleep, 50
      
      ; Log that we've delegated to the script
      LogToFile("Account lists reset via ResetLists.ahk. New lists will be generated on next injection.")
      
      ; Create a status message
      CreateStatusMessage("Account lists reset. New lists will use current method settings.",,,, false)
   } else {
      ; Log error if file doesn't exist
      LogToFile("ERROR: ResetLists.ahk not found at: " . resetListsPath)
      
      if (debugMode) {
         MsgBox, 0x40000, Reset list issue, ResetLists.ahk not found at:`n%resetListsPath%
      }
   }
}

StartBot:
   global PackGuiBuild := 0
   SaveAllSettings()
   LoadSettingsFromIni()
   CallOthers := 1
   GuiRemoveAlwaysOnTop()
   WinMinimize, ahk_id %menuHwnd%
   ; Quick path validation (no file I/O)
   if(StrLen(A_ScriptDir) > 200 || InStr(A_ScriptDir, " ")) {
      MsgBox, 0x40000,, % SetUpDictionary.Error_BotPathTooLong
      return
   }
   
   ; Build confirmation message with current GUI values
   confirmMsg := SetUpDictionary.Confirm_SelectedMethod . deleteMethod . "`n"
   
   confirmMsg .= "`n" . SetUpDictionary.Confirm_SelectedPacks . "`n"
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
   
   confirmMsg .= "`n" . SetUpDictionary.Confirm_AdditionalSettings
   additionalSettingsFound := false
   
   if (packMethod) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_1PackMethod
      additionalSettingsFound := true
   }
   if (nukeAccount && !InStr(deleteMethod, "Inject")) {
      confirmMsg .= "`n•" . SetUpDictionary.Confirm_MenuDelete
      additionalSettingsFound := true
   }
   if (spendHourGlass) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SpendHourGlass
      additionalSettingsFound := true
   }
   if (openExtraPack) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_OpenExtraPack
      additionalSettingsFound := true
   }
   if (claimSpecialMissions && InStr(deleteMethod, "Inject")) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_ClaimMissions
      additionalSettingsFound := true
   }
   if (InStr(deleteMethod, "Inject")) {
      ;GuiControlGet, selectedSortOption,, SortByDropdown
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SortBy . " " . SortByDropdown
      additionalSettingsFound := true
   }
   if (!additionalSettingsFound)
      confirmMsg .= "`n" . SetUpDictionary.Confirm_None
   
   confirmMsg .= "`n`n" . SetUpDictionary.Confirm_CardDetection
   cardDetectionFound := false
   
   if (FullArtCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SingleFullArt
      cardDetectionFound := true
   }
   if (TrainerCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SingleTrainer
      cardDetectionFound := true
   }
   if (RainbowCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SingleRainbow
      cardDetectionFound := true
   }
   if (PseudoGodPack) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_Double2Star
      cardDetectionFound := true
   }
   if (CrownCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SaveCrowns
      cardDetectionFound := true
   }
   if (ShinyCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SaveShiny
      cardDetectionFound := true
   }
   if (ImmersiveCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_SaveImmersives
      cardDetectionFound := true
   }
   if (CheckShinyPackOnly) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_OnlyShinyPacks
      cardDetectionFound := true
   }
   if (InvalidCheck) {
      confirmMsg .= "`n" . SetUpDictionary.Confirm_IgnoreInvalid
      cardDetectionFound := true
   }
   
   if (!cardDetectionFound)
      confirmMsg .= "`n" . SetUpDictionary.Confirm_None
   
   confirmMsg .= "`n`n" . SetUpDictionary.Confirm_SaveForTrade
   
   if (!s4tEnabled) {
      confirmMsg .= ": " . SetUpDictionary.Confirm_Disabled
   } else {
      confirmMsg .= ": " . SetUpDictionary.Confirm_Enabled . "`n"
      confirmMsg .= "• " . SetUpDictionary.Confirm_SilentPings . ": " . (s4tSilent ? SetUpDictionary.Confirm_Enabled : SetUpDictionary.Confirm_Disabled) . "`n"
      
      ; Add enabled filters
      if (s4t3Dmnd)
         confirmMsg .= "• 3 ◆◆◆`n"
      if (s4t4Dmnd)
         confirmMsg .= "• 4 ◆◆◆◆`n"
      if (s4t1Star)
         confirmMsg .= "• 1 ★`n"
      if (s4tGholdengo && Shining)
         confirmMsg .= "• " . SetUpDictionary.Confirm_Gholdengo . "`n"
      
      ; Add Wonder Pick status
      if (s4tWP)
         confirmMsg .= "• " . SetUpDictionary.Confirm_WonderPick . ": " . s4tWPMinCards . " " . SetUpDictionary.Confirm_MinCards . "`n"
      else
         confirmMsg .= "• " . SetUpDictionary.Confirm_WonderPick . ": " . SetUpDictionary.Confirm_Disabled . "`n"
   }
   
   if (sendAccountXml || s4tEnabled && s4tSendAccountXml) {
      confirmMsg .= "`n`n" . SetUpDictionary.Confirm_XMLWarning . "`n"
   }
   
   confirmMsg .= "`n`n" . SetUpDictionary.Confirm_StartBot
   
   ; === SHOW CONFIRMATION DIALOG IMMEDIATELY ===
   MsgBox, 4, Confirm Bot Settings, %confirmMsg%
   IfMsgBox, No
   {
      WinRestore, ahk_id %menuHwnd%
      WinActivate, ahk_id %menuHwnd%
      CallOthers := 0
      return ; Return to GUI for user to modify settings
   }
   
   ResetAccountLists()
   
   /*
   ; Update dropdown settings if needed
   if (InStr(deleteMethod, "Inject")) {
      ;MsgBox, SortByDropDown := %SortByDropdown%
      if (SortByDropdown = "Oldest First")
         injectSortMethod := "ModifiedAsc"
      else if (SortByDropdown = "Newest First")
         injectSortMethod := "ModifiedDesc"
      else if (SortByDropdown = "Fewest Packs First")
         injectSortMethod := "PacksAsc"
      else if (SortByDropdown = "Most Packs First")
         injectSortMethod := "PacksDesc"
   }
   */
   
   ; Re-validate scaleParam based on current language
   if (defaultLanguage = "Scale125") {
      scaleParam := 277
   } else if (defaultLanguage = "Scale100") {
      scaleParam := 287
   }
   
   ; Handle deprecated FriendID field
   if (inStr(FriendID, "http")) {
      MsgBox,To provide a URL for friend IDs, please use the ids.txt API field and leave the Friend ID field empty.
      
      if (mainIdsURL = "") {
         IniWrite, "", Settings.ini, UserSettings, FriendID
         IniWrite, %FriendID%, Settings.ini, UserSettings, mainIdsURL
      }
      
      Reload
   }
   
   ; Download a new Main ID file prior to running the rest of the below
   if (mainIdsURL != "") {
      DownloadFile(mainIdsURL, "ids.txt")
   }
   
   ; Check for showcase_ids.txt if enabled
   if (showcaseEnabled) {
      if (!FileExist("showcase_ids.txt")) {
         MsgBox, 48, Showcase Warning, Showcase is enabled but showcase_ids.txt does not exist.`nPlease create this file in the same directory as the script.
      }
   }
   
   ; Create the second page dynamically based on the number of instances
   SG.Destroy()
   Gui, Destroy ; Close the first page
   
   ; Run main before instances to account for instance start delay
   if (runMain) {
      Loop, %Mains%
      {
         if (A_Index != 1) {
            SourceFile := "Scripts\Main.ahk" ; Path to the source .ahk file
            TargetFolder := "Scripts\" ; Path to the target folder
            TargetFile := TargetFolder . "Main" . A_Index . ".ahk" ; Generate target file path
            FileDelete, %TargetFile%
            FileCopy, %SourceFile%, %TargetFile%, 1 ; Copy source file to target
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
   
   ; Loop to process each instance
   Loop, %Instances%
   {
      if (A_Index != 1) {
         SourceFile := "Scripts\1.ahk" ; Path to the source .ahk file
         TargetFolder := "Scripts\" ; Path to the target folder
         TargetFile := TargetFolder . A_Index . ".ahk" ; Generate target file path
         if(Instances > 1) {
            FileDelete, %TargetFile%
            FileCopy, %SourceFile%, %TargetFile%, 1 ; Copy source file to target
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
      
      ; Clear out the last run time so that our monitor script doesn't try to kill and refresh this instance right away
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
   
   ; Update ScaleParam for use in displaying the status
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
   
   ; === MAIN HEARTBEAT LOOP ===
   Loop {
      Sleep, 30000
      ;ToolTip, Enter Loop, 100, 800
      ; Check if Main toggled GP Test Mode and send notification if needed
      IniRead, mainTestMode, HeartBeat.ini, TestMode, Main, -1
      if (mainTestMode != -1) {
         ; Main has toggled test mode, get status and send notification
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
         
         ; Create status message with all regular heartbeat info
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
         
         ; Add special note about Main's test mode status
         if (mainTestMode == "1")
            discMessage .= "\n\nMain entered GP Test Mode ✕"
         else
            discMessage .= "\n\nMain exited GP Test Mode ✓"
         
         ; Send the message
         LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)
         
         ; Clear the flag
         IniDelete, HeartBeat.ini, TestMode, Main
      }
      
      ; Every 5 minutes, pull down the main ID list and showcase list
      if(Mod(A_Index, 10) = 0) {
         if(mainIdsURL != "") {
            DownloadFile(mainIdsURL, "ids.txt")
         } else {
            if(FileExist("ids.txt"))
               FileDelete, ids.txt
         }
      }
      
      ; Sum all variable values and write to total.json
      total := SumVariablesInJsonFile()
      totalSeconds := Round((A_TickCount - rerollTime) / 1000) ; Total time in seconds
      mminutes := Floor(totalSeconds / 60)
      
      packStatus := "Time: " . mminutes . "m Packs: " . total
      packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"
      ; Display pack status at the bottom of the first reroll instance
      DisplayPackStatus(packStatus, ((runMain ? Mains * scaleParam : 0) + 5), 625)
      
      ; FIXED HEARTBEAT CODE
      if(heartBeat) {
         ; Each loop iteration is 30 seconds (0.5 minutes)
         ; So for X minutes, we need X * 2 iterations
         heartbeatIterations := heartBeatDelay * 2
         
         ; Send heartbeat at start (A_Index = 1) or every heartbeatDelay minutes
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
            
            ; Optional debug log
            if (debugMode) {
               FileAppend, % A_Now . " - Heartbeat sent at iteration " . A_Index . "`n", %A_ScriptDir%\heartbeat_log.txt
            }
         }
      }
   }

Return

GuiClose:
   ; Save all settings before exiting
   SaveAllSettings()
   
   ; Kill all related scripts
   KillAllScripts()

ExitApp
return

; New hotkey for sending "All Offline" status message
~+F7::
   SendAllInstancesOfflineStatus()
ExitApp
return

; Function to send a Discord message with all instances marked as offline
SendAllInstancesOfflineStatus() {
   global heartBeatName, heartBeatWebhookURL, localVersion, githubUser, Instances, runMain, Mains
   global typeMsg, selectMsg, rerollTime, scaleParam
   
   ; Display visual feedback that the hotkey was triggered
   DisplayPackStatus("Shift+F7 pressed - Sending offline heartbeat to Discord...", ((runMain ? Mains * scaleParam : 0) + 5), 625)
   
   ; Create message showing all instances as offline
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
   
   ; Create status message with heartbeat info
   discMessage := heartBeatName ? "\n" . heartBeatName : ""
   discMessage .= "\nOnline: none"
   discMessage .= "\nOffline: " . offlineInstances
   
   ; Add pack statistics
   total := SumVariablesInJsonFile()
   totalSeconds := Round((A_TickCount - rerollTime) / 1000)
   mminutes := Floor(totalSeconds / 60)
   packStatus := "Time: " . mminutes . "m | Packs: " . total
   packStatus .= " | Avg: " . Round(total / mminutes, 2) . " packs/min"
   
   discMessage .= "\n" . packStatus . "\nVersion: " . RegExReplace(githubUser, "-.*$") . "-" . localVersion
   discMessage .= typeMsg
   discMessage .= selectMsg
   discMessage .= "\n\n All instances marked as OFFLINE"
   
   ; Send the message
   LogToDiscord(discMessage,, false,,, heartBeatWebhookURL)
   
   ; Display confirmation in the status bar
   DisplayPackStatus("Discord notification sent: All instances marked as OFFLINE", ((runMain ? Mains * scaleParam : 0) + 5), 625)
}

; Global variable to track the current JSON file
global jsonFileName := ""

; Function to create or select the JSON file
InitializeJsonFile() {
   global jsonFileName
   fileName := A_ScriptDir . "\json\Packs.json"
   
   ; Add this line to create the directory if it doesn't exist
   FileCreateDir, %A_ScriptDir%\json
   
   if FileExist(fileName)
      FileDelete, %fileName%
   if !FileExist(fileName) {
      ; Create a new file with an empty JSON array
      FileAppend, [], %fileName% ; Write an empty JSON array
      jsonFileName := fileName
      return
   }
}

; Function to append a time and variable pair to the JSON file
AppendToJsonFile(variableValue) {
   global jsonFileName
   if (jsonFileName = "") {
      MsgBox, 0x40000, JSON, JSON file not initialized. Call InitializeJsonFile() first.
      return
   }
   
   ; Read the current content of the JSON file
   FileRead, jsonContent, %jsonFileName%
   if (jsonContent = "") {
      jsonContent := "[]"
   }
   
   ; Parse and modify the JSON content
   jsonContent := SubStr(jsonContent, 1, StrLen(jsonContent) - 1) ; Remove trailing bracket
   if (jsonContent != "[")
      jsonContent .= ","
   jsonContent .= "{""time"": """ A_Now """, ""variable"": " variableValue "}]"
   
   ; Write the updated JSON back to the file
   FileDelete, %jsonFileName%
   FileAppend, %jsonContent%, %jsonFileName%
}

; Function to sum all variable values in the JSON file
SumVariablesInJsonFile() {
   global jsonFileName
   if (jsonFileName = "") {
      return 0 ; Return 0 instead of nothing if jsonFileName is empty
   }
   ; Read the file content
   FileRead, jsonContent, %jsonFileName%
   if (jsonContent = "") {
      return 0
   }
   
   ; Parse the JSON and calculate the sum
   sum := 0
   ; Clean and parse JSON content
   jsonContent := StrReplace(jsonContent, "[", "") ; Remove starting bracket
   jsonContent := StrReplace(jsonContent, "]", "") ; Remove ending bracket
   Loop, Parse, jsonContent, {, }
   {
      ; Match each variable value
      if (RegExMatch(A_LoopField, """variable"":\s*(-?\d+)", match)) {
         sum += match1
      }
   }
   
   ; Write the total sum to a file called "total.json"
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
      MsgBox, 0x40000, Check for Update, currentDictionary.fail_fetch
      return
   }
   latestReleaseBody := FixFormat(ExtractJSONValue(response, "body"))
   latestVersion := ExtractJSONValue(response, "tag_name")
   zipDownloadURL := ExtractJSONValue(response, "zipball_url")
   Clipboard := latestReleaseBody
   if (zipDownloadURL = "" || !InStr(zipDownloadURL, "http"))
   {
      MsgBox, 0x40000, Check for Update, % currentDictionary.fail_url
      return
   }
   
   if (latestVersion = "")
   {
      MsgBox, 0x40000, Check for Update, % currentDictionary.fail_version
      return
   }
   
   if (VersionCompare(latestVersion, localVersion) > 0)
   {
      ; Get release notes from the JSON (ensure this is populated earlier in the script)
      releaseNotes := latestReleaseBody ; Assuming `latestReleaseBody` contains the release notes
      
      ; Show a message box asking if the user wants to download
      updateAvailable := currentDictionary.update_title
      latestDownloaad := currentDictionary.confirm_dl
      MsgBox, 262148, %updateAvailable% %latestVersion%, %releaseNotes%`n`nDo you want to download the latest version?
      
      ; If the user clicks Yes (return value 6)
      IfMsgBox, Yes
      {
         MsgBox, 262208, Downloading..., % currentDictionary.downloading
         
         ; Proceed with downloading the update
         URLDownloadToFile, %zipDownloadURL%, %zipPath%
         if ErrorLevel
         {
            MsgBox, 0x40000, Check for Update, % currentDictionary.dl_failed
            return
         }
         else {
            MsgBox, 0x40000, Check for Update, % currentDictionary.dl_complete
            
            ; Create a temporary folder for extraction
            tempExtractPath := A_Temp "\PTCGPB_Temp"
            FileCreateDir, %tempExtractPath%
            
            ; Extract the ZIP file into the temporary folder
            RunWait, powershell -Command "Expand-Archive -Path '%zipPath%' -DestinationPath '%tempExtractPath%' -Force",, Hide
            
            ; Check if extraction was successful
            if !FileExist(tempExtractPath)
            {
               MsgBox, 0x40000, Check for Update, % currentDictionary.extract_failed
               return
            }
            
            ; Get the first subfolder in the extracted folder
            Loop, Files, %tempExtractPath%\*, D
            {
               extractedFolder := A_LoopFileFullPath
               break
            }
            
            ; Check if a subfolder was found and move its contents recursively to the script folder
            if (extractedFolder)
            {
               MoveFilesRecursively(extractedFolder, scriptFolder)
               
               ; Clean up the temporary extraction folder
               FileRemoveDir, %tempExtractPath%, 1
               MsgBox, 0x40000, Check for Update, % currentDictionary.installed
               Reload
            }
            else
            {
               MsgBox, 0x40000, Check for Update, % currentDictionary.missing_files
               return
            }
         }
      }
      else
      {
         MsgBox, 0x40000, Check for Update, % currentDictionary.cancel
         return
      }
   }
   else
   {
      ;MsgBox, 0x40000, Check for Update, % currentDictionary.up_to_date
   }
}

MoveFilesRecursively(srcFolder, destFolder) {
   ; Loop through all files and subfolders in the source folder
   Loop, Files, % srcFolder . "\*", R
   {
      ; Get the relative path of the file/folder from the srcFolder
      relativePath := SubStr(A_LoopFileFullPath, StrLen(srcFolder) + 2)
      
      ; Create the corresponding destination path
      destPath := destFolder . "\" . relativePath
      
      ; If it's a directory, create it in the destination folder
      if (A_LoopIsDir)
      {
         ; Ensure the directory exists, if not, create it
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
         ; If it's a file, move it to the destination folder
         ; Ensure the directory exists before moving the file
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

; Function to extract value from JSON
ExtractJSONValue(json, key1, key2:="", ext:="") {
   value := ""
   json := StrReplace(json, """", "")
   lines := StrSplit(json, ",")
   
   Loop, % lines.MaxIndex()
   {
      if InStr(lines[A_Index], key1 ":") {
         ; Take everything after the first colon as the value
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
   ; Replace carriage return and newline with an actual line break
   text := StrReplace(text, "\r\n", "`n") ; Replace \r\n with actual newlines
   text := StrReplace(text, "\n", "`n") ; Replace \n with newlines
   
   ; Remove unnecessary backslashes before other characters like "player" and "None"
   text := StrReplace(text, "\player", "player") ; Example: removing backslashes around words
   text := StrReplace(text, "\None", "None") ; Remove backslash around "None"
   text := StrReplace(text, "\Welcome", "Welcome") ; Removing \ before "Welcome"
   
   ; Escape commas by replacing them with %2C (URL encoding)
   text := StrReplace(text, ",", "")
   
   return text
}

VersionCompare(v1, v2) {
   ; Remove non-numeric characters (like 'alpha', 'beta')
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
   
   ; If versions are numerically equal, check if one is an alpha version
   isV1Alpha := InStr(v1, "alpha") || InStr(v1, "beta")
   isV2Alpha := InStr(v2, "alpha") || InStr(v2, "beta")
   
   if (isV1Alpha && !isV2Alpha)
      return -1 ; Non-alpha version is newer
   if (!isV1Alpha && isV2Alpha)
      return 1 ; Alpha version is older
   
   return 0 ; Versions are equal
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
      cleanVal := RegExReplace(val, "[^a-zA-Z0-9]") ; Remove non-alphanumeric characters
      if (cleanVal != "")
         values.Push(cleanVal)
   }
   
   return values.MaxIndex() ? values : false
}

ErrorHandler(exception) {
   ; Display the error message
   errorMessage := "Error in PTCGPB.ahk`n`n"
      . "Message: " exception.Message "`n"
      . "What: " exception.What "`n"
      . "Line: " exception.Line "`n`n"
      . "Click OK to close all related scripts and exit."
   
   MsgBox, 262160, PTCGPB Error, %errorMessage%
   
   ; Kill all related scripts
   KillAllScripts()
   
   ; Exit this script
   ExitApp, 1
   return true ; Indicate that the error was handled
}

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
