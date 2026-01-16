#Include %A_ScriptDir%\Include\Logging.ahk
#Include %A_ScriptDir%\Include\ADB.ahk
#Include %A_ScriptDir%\Include\Gdip_All.ahk
#Include %A_ScriptDir%\Include\Gdip_Imagesearch.ahk

; BallCity - 2025.20.25 - Add OCR library for Username if Inject is on
#Include *i %A_ScriptDir%\Include\OCR.ahk
#Include *i %A_ScriptDir%\Include\Gdip_Extra.ahk

; Refactored includes - organized by functionality
#Include %A_ScriptDir%\Include\Utils.ahk
#Include %A_ScriptDir%\Include\Database.ahk
#Include %A_ScriptDir%\Include\CardDetection.ahk
#Include %A_ScriptDir%\Include\WonderPickManager.ahk
#Include %A_ScriptDir%\Include\AccountManager.ahk
#Include %A_ScriptDir%\Include\FriendManager.ahk

#SingleInstance on
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetBatchLines, -1
SetTitleMatchMode, 3
CoordMode, Pixel, Screen
#NoEnv

; Allocate and hide the console window to reduce flashing
DllCall("AllocConsole")
WinHide % "ahk_id " DllCall("GetConsoleWindow", "ptr")

global winTitle, changeDate, failSafe, openPack, Delay, failSafeTime, StartSkipTime, Columns, failSafe, scriptName, GPTest, StatusText, defaultLanguage, setSpeed, jsonFileName, pauseToggle, SelectedMonitorIndex, swipeSpeed, godPack, scaleParam, deleteMethod, packs, FriendID, friendIDs, Instances, username, friendCode, stopToggle, friended, runMain, Mains, showStatus, injectMethod, packMethod, loadDir, loadedAccount, nukeAccount, CheckShinyPackOnly, TrainerCheck, FullArtCheck, RainbowCheck, ShinyCheck, dateChange, foundGP, friendsAdded, PseudoGodPack, packArray, CrownCheck, ImmersiveCheck, InvalidCheck, slowMotion, screenShot, accountFile, invalid, starCount, keepAccount
global Mewtwo, Charizard, Pikachu, Mew, Dialga, Palkia, Arceus, Shining, Solgaleo, Lunala, Buzzwole, Eevee, HoOh, Lugia, Springs, Deluxe, MegaGyarados, MegaBlaziken, MegaAltaria, CrimsonBlaze
global shinyPacks, minStars, minStarsShiny, minStarsA1Mewtwo, minStarsA1Charizard, minStarsA1Pikachu, minStarsA1a, minStarsA2Dialga, minStarsA2Palkia, minStarsA2a, minStarsA2b, minStarsA3Solgaleo, minStarsA3Lunala, minStarsA3a, minStarsA4HoOh, minStarsA4Lugia, minStarsA4Springs, minStarsA4Deluxe, minStarsCrimsonBlaze, minStarsMegaGyarados, minStarsMegaBlaziken, minStarsMegaAltaria
global DeadCheck
global s4tEnabled, s4tSilent, s4t3Dmnd, s4t4Dmnd, s4t1Star, s4tGholdengo, s4tWP, s4tWPMinCards, s4tDiscordWebhookURL, s4tDiscordUserId, s4tSendAccountXml
global s4tTrainer, s4tRainbow, s4tFullArt, s4tCrown, s4tImmersive, s4tShiny1Star, s4tShiny2Star
global claimDailyMission, wonderpickForEventMissions
global checkWPthanks, wpThanksSavedUsername, wpThanksSavedFriendCode, isCurrentlyDoingWPCheck := false
global s4tPendingTradeables := []
global deviceAccountXmlMap := {} ; prevents Create Bots + s4t making duplicate .xmls within a single run
global ocrShinedust
global titleHeight, MuMuv5

global currentPackInfo := {"isVerified": false, "CardSlot": [], "TypeCount": {}}
global cardBorderList := ["normal", "3diamond", "1star", "trainer", "rainbow", "fullart", "immersive", "crown", "gimmighoul", "ShinyEx", "shiny1star"]

global avgtotalSeconds
global verboseLogging
global showcaseEnabled
global currentPackIs6Card := false
global currentPackIs4Card := false
global injectSortMethod := "ModifiedAsc"  ; Default sort method (oldest accounts first)
global injectMinPacks := 0       ; Minimum pack count for injection (0 = no minimum)
global injectMaxPacks := 39      ; Maximum pack count for injection (default for regular Inject 13P+)

global waitForEligibleAccounts := 1  ; Enable/disable waiting (1 = wait, 0 = stop script)
global maxWaitHours := 24             ; Maximum hours to wait before giving up (0 = wait forever)

avgtotalSeconds := 0

global accountOpenPacks, accountFileName, accountFileNameOrig, accountFileNameTmp, accountHasPackInfo, ocrSuccess, packsInPool, packsThisRun, aminutes, aseconds, rerolls, rerollStartTime, maxAccountPackNum, cantOpenMorePacks, rerolls_local, rerollStartTime_local

cantOpenMorePacks := 0
maxAccountPackNum := 9999
aminutes := 0
aseconds := 0

global beginnerMissionsDone, soloBattleMissionDone, intermediateMissionsDone, specialMissionsDone, resetSpecialMissionsDone, accountHasPackInTesting, currentLoadedAccountIndex

beginnerMissionsDone := 0
soloBattleMissionDone := 0
intermediateMissionsDone := 0
specialMissionsDone := 0
resetSpecialMissionsDone := 0
accountHasPackInTesting := 0

global dbg_bbox, dbg_bboxNpause, dbg_bbox_click

dbg_bbox :=0
dbg_bboxNpause :=0
dbg_bbox_click :=0

scriptName := StrReplace(A_ScriptName, ".ahk")
winTitle := scriptName
foundGP := false
injectMethod := false
pauseToggle := false
showStatus := true
friended := false
dateChange := false
jsonFileName := A_ScriptDir . "\..\json\Packs.json"
IniRead, FriendID, %A_ScriptDir%\..\Settings.ini, UserSettings, FriendID
IniRead, waitTime, %A_ScriptDir%\..\Settings.ini, UserSettings, waitTime, 5
IniRead, Delay, %A_ScriptDir%\..\Settings.ini, UserSettings, Delay, 250
IniRead, folderPath, %A_ScriptDir%\..\Settings.ini, UserSettings, folderPath, C:\Program Files\Netease
MuMuv5 := isMuMuv5()
IniRead, Columns, %A_ScriptDir%\..\Settings.ini, UserSettings, Columns, 5
IniRead, godPack, %A_ScriptDir%\..\Settings.ini, UserSettings, godPack, Continue
IniRead, Instances, %A_ScriptDir%\..\Settings.ini, UserSettings, Instances, 1
IniRead, defaultLanguage, %A_ScriptDir%\..\Settings.ini, UserSettings, defaultLanguage, Scale125
IniRead, rowGap, %A_ScriptDir%\..\Settings.ini, UserSettings, rowGap, 100
IniRead, SelectedMonitorIndex, %A_ScriptDir%\..\Settings.ini, UserSettings, SelectedMonitorIndex, 1
IniRead, swipeSpeed, %A_ScriptDir%\..\Settings.ini, UserSettings, swipeSpeed, 300
IniRead, deleteMethod, %A_ScriptDir%\..\Settings.ini, UserSettings, deleteMethod, Create Bots (13P)

; support to convert old settings.ini deleteMethods to new nomenclature
originalDeleteMethod := deleteMethod
deleteMethod := MigrateDeleteMethod(deleteMethod)
if (deleteMethod != originalDeleteMethod) {
    IniWrite, %deleteMethod%, %A_ScriptDir%\..\Settings.ini, UserSettings, deleteMethod
    validMethods := "Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+"
    if (!InStr(validMethods, deleteMethod)) {
        deleteMethod := "Create Bots (13P)"
        IniWrite, %deleteMethod%, %A_ScriptDir%\..\Settings.ini, UserSettings, deleteMethod
    }
}
; Write deleteMethod to instance-specific ini for Monitor.ahk to read
IniWrite, %deleteMethod%, %A_ScriptDir%\%scriptName%.ini, UserSettings, deleteMethod

IniRead, runMain, %A_ScriptDir%\..\Settings.ini, UserSettings, runMain, 1
IniRead, Mains, %A_ScriptDir%\..\Settings.ini, UserSettings, Mains, 1
IniRead, AccountName, %A_ScriptDir%\..\Settings.ini, UserSettings, AccountName, ""
IniRead, nukeAccount, %A_ScriptDir%\..\Settings.ini, UserSettings, nukeAccount, 0
IniRead, packMethod, %A_ScriptDir%\..\Settings.ini, UserSettings, packMethod, 0
IniRead, CheckShinyPackOnly, %A_ScriptDir%\..\Settings.ini, UserSettings, CheckShinyPackOnly, 0
IniRead, TrainerCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, TrainerCheck, 0
IniRead, FullArtCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, FullArtCheck, 0
IniRead, RainbowCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, RainbowCheck, 0
IniRead, ShinyCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, ShinyCheck, 0
IniRead, CrownCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, CrownCheck, 0
IniRead, ImmersiveCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, ImmersiveCheck, 0
IniRead, InvalidCheck, %A_ScriptDir%\..\Settings.ini, UserSettings, InvalidCheck, 0
IniRead, PseudoGodPack, %A_ScriptDir%\..\Settings.ini, UserSettings, PseudoGodPack, 0
IniRead, minStars, %A_ScriptDir%\..\Settings.ini, UserSettings, minStars, 0
IniRead, minStarsShiny, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsShiny, 0

IniRead, CrimsonBlaze, %A_ScriptDir%\..\Settings.ini, UserSettings, CrimsonBlaze, 1
IniRead, MegaGyarados, %A_ScriptDir%\..\Settings.ini, UserSettings, MegaGyarados, 0
IniRead, MegaBlaziken, %A_ScriptDir%\..\Settings.ini, UserSettings, MegaBlaziken, 0
IniRead, MegaAltaria, %A_ScriptDir%\..\Settings.ini, UserSettings, MegaAltaria, 0
IniRead, Deluxe, %A_ScriptDir%\..\Settings.ini, UserSettings, Deluxe, 0
IniRead, Springs, %A_ScriptDir%\..\Settings.ini, UserSettings, Springs, 0
IniRead, HoOh, %A_ScriptDir%\..\Settings.ini, UserSettings, HoOh, 0
IniRead, Lugia, %A_ScriptDir%\..\Settings.ini, UserSettings, Lugia, 0
IniRead, Eevee, %A_ScriptDir%\..\Settings.ini, UserSettings, Eevee, 0
IniRead, Buzzwole, %A_ScriptDir%\..\Settings.ini, UserSettings, Buzzwole, 0
IniRead, Solgaleo, %A_ScriptDir%\..\Settings.ini, UserSettings, Solgaleo, 0
IniRead, Lunala, %A_ScriptDir%\..\Settings.ini, UserSettings, Lunala, 0
IniRead, Shining, %A_ScriptDir%\..\Settings.ini, UserSettings, Shining, 0
IniRead, Arceus, %A_ScriptDir%\..\Settings.ini, UserSettings, Arceus, 0
IniRead, Dialga, %A_ScriptDir%\..\Settings.ini, UserSettings, Dialga, 0
IniRead, Palkia, %A_ScriptDir%\..\Settings.ini, UserSettings, Palkia, 0
IniRead, Mewtwo, %A_ScriptDir%\..\Settings.ini, UserSettings, Mewtwo, 0
IniRead, Charizard, %A_ScriptDir%\..\Settings.ini, UserSettings, Charizard, 0
IniRead, Pikachu, %A_ScriptDir%\..\Settings.ini, UserSettings, Pikachu, 0
IniRead, Mew, %A_ScriptDir%\..\Settings.ini, UserSettings, Mew, 0

IniRead, minStarsA1Mewtwo, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA1Mewtwo, 0
IniRead, minStarsA1Charizard, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA1Charizard, 0
IniRead, minStarsA1Pikachu, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA1Pikachu, 0
IniRead, minStarsA1a, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA1a, 0
IniRead, minStarsA2Dialga, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA2Dialga, 0
IniRead, minStarsA2Palkia, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA2Palkia, 0
IniRead, minStarsA2a, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA2a, 0
IniRead, minStarsA2b, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA2b, 0
IniRead, minStarsA3Solgaleo, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA3Solgaleo, 0
IniRead, minStarsA3Lunala, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA3Lunala, 0
IniRead, minStarsA3a, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA3a, 0
IniRead, minStarsA3b, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA3b, 0
IniRead, minStarsA4HoOh, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA4HoOh, 0
IniRead, minStarsA4Lugia, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA4Lugia, 0
IniRead, minStarsA4Springs, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA4Springs, 0
IniRead, minStarsA4Deluxe, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsA4Deluxe, 0
IniRead, minStarsCrimsonBlaze, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsCrimsonBlaze, 0
IniRead, minStarsMegaGyarados, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsMegaGyarados, 0
IniRead, minStarsMegaBlaziken, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsMegaBlaziken, 0
IniRead, minStarsMegaAltaria, %A_ScriptDir%\..\Settings.ini, UserSettings, minStarsMegaAltaria, 0

IniRead, slowMotion, %A_ScriptDir%\..\Settings.ini, UserSettings, slowMotion, 0
IniRead, DeadCheck, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck, 0
IniRead, ocrLanguage, %A_ScriptDir%\..\Settings.ini, UserSettings, ocrLanguage, en
IniRead, injectSortMethod, %A_ScriptDir%\..\Settings.ini, UserSettings, injectSortMethod, ModifiedAsc
IniRead, waitForEligibleAccounts, %A_ScriptDir%\..\Settings.ini, UserSettings, waitForEligibleAccounts, 1
IniRead, maxWaitHours, %A_ScriptDir%\..\Settings.ini, UserSettings, maxWaitHours, 24
IniRead, skipMissionsInjectMissions, %A_ScriptDir%\..\Settings.ini, UserSettings, skipMissionsInjectMissions, 0
IniRead, claimSpecialMissions, %A_ScriptDir%\..\Settings.ini, UserSettings, claimSpecialMissions, 0
IniRead, spendHourGlass, %A_ScriptDir%\..\Settings.ini, UserSettings, spendHourGlass, 1
IniRead, openExtraPack, %A_ScriptDir%\..\Settings.ini, UserSettings, openExtraPack, 0
IniRead, verboseLogging, %A_ScriptDir%\..\Settings.ini, UserSettings, debugMode, 0
IniRead, claimDailyMission, %A_ScriptDir%\..\Settings.ini, UserSettings, claimDailyMission, 0
IniRead, wonderpickForEventMissions, %A_ScriptDir%\..\Settings.ini, UserSettings, wonderpickForEventMissions, 0
IniRead, checkWPthanks, %A_ScriptDir%\..\Settings.ini, UserSettings, checkWPthanks, 0
wpThanksSavedUsername := ""
wpThanksSavedFriendCode := ""

IniRead, s4tEnabled, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tEnabled, 0
IniRead, s4tSilent, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tSilent, 1
IniRead, s4t3Dmnd, %A_ScriptDir%\..\Settings.ini, UserSettings, s4t3Dmnd, 0
IniRead, s4t4Dmnd, %A_ScriptDir%\..\Settings.ini, UserSettings, s4t4Dmnd, 0
IniRead, s4t1Star, %A_ScriptDir%\..\Settings.ini, UserSettings, s4t1Star, 0
IniRead, s4tGholdengo, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tGholdengo, 0
IniRead, s4tTrainer, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tTrainer, 0
IniRead, s4tRainbow, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tRainbow, 0
IniRead, s4tFullArt, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tFullArt, 0
IniRead, s4tCrown, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tCrown, 0
IniRead, s4tImmersive, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tImmersive, 0
IniRead, s4tShiny1Star, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tShiny1Star, 0
IniRead, s4tShiny2Star, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tShiny2Star, 0
IniRead, s4tWP, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tWP, 0
IniRead, s4tWPMinCards, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tWPMinCards, 1
IniRead, s4tDiscordWebhookURL, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tDiscordWebhookURL
IniRead, s4tDiscordUserId, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tDiscordUserId
IniRead, s4tSendAccountXml, %A_ScriptDir%\..\Settings.ini, UserSettings, s4tSendAccountXml, 1
IniRead, ocrShinedust, %A_ScriptDir%\..\Settings.ini, UserSettings, ocrShinedust, 0

IniRead, rerolls, %A_ScriptDir%\%scriptName%.ini, Metrics, rerolls, 0
IniRead, rerollStartTime, %A_ScriptDir%\%scriptName%.ini, Metrics, rerollStartTime, A_TickCount
;rerollstartTime := A_TickCount

; Initialize no limit to max account pack number if running save for trade
if(s4tEnabled){
    maxAccountPackNum := 9999
}

pokemonList := ["Mewtwo", "Charizard", "Pikachu", "Mew", "Dialga", "Palkia", "Arceus", "Shining", "Solgaleo", "Lunala", "Buzzwole", "Eevee", "HoOh", "Lugia", "Springs", "Deluxe", "MegaGyarados", "MegaBlaziken", "MegaAltaria", "CrimsonBlaze"]
shinyPacks := {"Shining": 1, "Solgaleo": 1, "Lunala": 1, "Buzzwole": 1, "Eevee": 1, "HoOh": 1, "Lugia": 1, "Springs": 1, "Deluxe": 1, "MegaGyarados": 1, "MegaBlaziken": 1, "MegaAltaria": 1, "CrimsonBlaze": 1}

packArray := []  ; Initialize an empty array

Loop, % pokemonList.MaxIndex()  ; Loop through the array
{
    pokemon := pokemonList[A_Index]  ; Get the variable name as a string
    if (%pokemon%)  ; Dereference the variable using %pokemon%
        packArray.push(pokemon)  ; Add the name to packArray
}

changeDate := getChangeDateTime() ; get server reset time

if(heartBeat)
    IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, Instance%scriptName%

SetTimer, RefreshAccountLists, 3600000  ; Refresh Account list every hour

; Set default rowGap if not defined
if (!rowGap)
    rowGap := 100

Sleep, % scriptName * 1000

; Validate scaleParam early
if (InStr(defaultLanguage, "100")) {
    scaleParam := 287
} else {
    if (MuMuv5) {
        scaleParam := 283
    } else {
        scaleParam := 277
    }
}
DirectlyPositionWindow()
Sleep, 1000

ConnectAdb(folderPath)

Sleep, 2000
CreateStatusMessage("Disabling background services...")
DisableBackgroundServices()
Sleep, 5000

resetWindows()
MaxRetries := 10
RetryCount := 0
Loop {
    try {
        WinGetPos, x, y, Width, Height, %winTitle%
        sleep, 2000
        ;Winset, Alwaysontop, On, %winTitle%
        OwnerWND := WinExist(winTitle)
        x4 := x + 5
        y4 := y +535
        buttonWidth := 50
        if (scaleParam = 287)
            buttonWidth := buttonWidth + 5

        Gui, New, +Owner%OwnerWND% -AlwaysOnTop +ToolWindow -Caption +LastFound -DPIScale
        Gui, Default
        Gui, Margin, 4, 4  ; Set margin for the GUI
        Gui, Font, s5 cGray Norm Bold, Segoe UI  ; Normal font for input labels
        Gui, Add, Button, % "x" . (buttonWidth * 0) . " y0 w" . buttonWidth . " h25 gReloadScript", Reload  (Shift+F5)
        Gui, Add, Button, % "x" . (buttonWidth * 1) . " y0 w" . buttonWidth . " h25 gPauseScript", Pause (Shift+F6)
        Gui, Add, Button, % "x" . (buttonWidth * 2) . " y0 w" . buttonWidth . " h25 gResumeScript", Resume (Shift+F6)
        Gui, Add, Button, % "x" . (buttonWidth * 3) . " y0 w" . buttonWidth . " h25 gStopScript", Stop (Shift+F7)
        ;if(winTitle=1)
        Gui, Add, Button, % "x" . (buttonWidth * 4) . " y0 w" . buttonWidth . " h25 gDevMode", Dev Mode (Shift+F8)
        DllCall("SetWindowPos", "Ptr", WinExist(), "Ptr", 1  ; HWND_BOTTOM
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)  ; SWP_NOSIZE, SWP_NOMOVE, SWP_NOACTIVATE
        Gui, Show, NoActivate x%x4% y%y4%  w275 h30
        break
    }
    catch {
        RetryCount++
        if (RetryCount >= MaxRetries) {
            CreateStatusMessage("Failed to create button GUI.",,,, false)
            break
        }
        Sleep, 1000
    }
    Delay(1)
    CreateStatusMessage("Trying to create button GUI...")
}

if (!godPack)
    godPack = 1
else if (godPack = "Close")
    godPack = 1
else if (godPack = "Pause")
    godPack = 2
if (godPack = "Continue")
    godPack = 3

if (!setSpeed)
    setSpeed = 1
if (setSpeed = "2x")
    setSpeed := 1
else if (setSpeed = "1x/2x")
    setSpeed := 2
else if (setSpeed = "1x/3x")
    setSpeed := 3

setSpeed := 3 ;always 1x/3x

if(InStr(deleteMethod, "Inject"))
    injectMethod := true

initializeAdbShell()

createAccountList(scriptName)

rerolls_local := 0
rerollStartTime_local := A_TickCount

if(injectMethod && DeadCheck != 1) {
    loadedAccount := loadAccount()
    nukeAccount := false
}

clearMissionCache()

if(!injectMethod || !loadedAccount)
    restartGameInstance("Initializing bot...", false)

pToken := Gdip_Startup()
packsInPool := 0
packsThisRun := 0

; Define default swipe params.
adbSwipeX1 := Round(35 / 277 * 535)
adbSwipeX2 := Round(267 / 277 * 535)
adbSwipeY := Round((327 - 44) / 489 * 960)
global adbSwipeParams := adbSwipeX1 . " " . adbSwipeY . " " . adbSwipeX2 . " " . adbSwipeY . " " . swipeSpeed

if(DeadCheck = 1 && deleteMethod != "Create Bots (13P)") {
    CreateStatusMessage("Account is stuck! Restarting and unfriending...")
    friended := true
    CreateStatusMessage("Stuck account still has friends. Unfriending accounts...")
    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
    if(setSpeed = 3)
        FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
    else
        FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
    adbClick_wbb(51, 297)
    Delay(1)
    RemoveFriends()
    if(injectMethod && loadedAccount && !keepAccount) {
        MarkAccountAsUsed()
        loadedAccount := false
    }
    DeadCheck := 0
    IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
    createAccountList(scriptName)
    Reload
} else if(DeadCheck = 1 && deleteMethod = "Create Bots (13P)") {
    CreateStatusMessage("New account creation is stuck! Deleting account...")
    Delay(5)
    menuDeleteStart()
    Reload
} else {
    ; in injection mode, we dont need to reload

    Loop {
        clearMissionCache()
        Randmax := packArray.Length()
        Random, rand, 1, Randmax
        openPack := packArray[rand]
        friended := false
        IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, Instance%scriptName%

        changeDate := getChangeDateTime() ; get server reset time

        if (avgtotalSeconds > 0 ) {
            StartTime := changeDate
            StartTime += -(1.0*avgtotalSeconds), Seconds
            EndTime := changeDate
            EndTime += (0.3*avgtotalSeconds), Seconds
        } else {
            StartTime := changeDate
            StartTime += -5, minutes
            EndTime := changeDate
            EndTime += 2, minutes
        }

        StartCurrentTimeDiff := A_Now
        EnvSub, StartCurrentTimeDiff, %StartTime%, Seconds
        EndCurrentTimeDiff := A_Now
        EnvSub, EndCurrentTimeDiff, %EndTime%, Seconds

        dateChange := false

        while (StartCurrentTimeDiff > 0 && EndCurrentTimeDiff < 0) {
            FormatTime, formattedEndTime, %EndTime%, HH:mm:ss
            CreateStatusMessage("Waiting for daily server reset until " . formattedEndTime ,,,, false)
            dateChange := true
            Sleep, 5000

            StartCurrentTimeDiff := A_Now
            EnvSub, StartCurrentTimeDiff, %StartTime%, Seconds
            EndCurrentTimeDiff := A_Now
            EnvSub, EndCurrentTimeDiff, %EndTime%, Seconds
        }

        if(dateChange)
            IniWrite, 5, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseLikes

        ; Only refresh account lists if we're not in injection mode or if no account is loaded
        ; This prevents constant list regeneration during injection
        if(injectMethod && !loadedAccount) {
            createAccountList(scriptName)
        }

        ; For injection methods, load account only if we don't already have one
        if(injectMethod) {
            nukeAccount := false

            ; Only load account if we don't already have one loaded
            if(!loadedAccount) {
                loadedAccount := loadAccount()
            }

            ; If no account could be loaded for injection methods, handle appropriately
            if(!loadedAccount) {
                ; Check user setting for what to do when no eligible accounts
                IniRead, waitForEligibleAccounts, %A_ScriptDir%\..\Settings.ini, UserSettings, waitForEligibleAccounts, 1
                IniRead, maxWaitHours, %A_ScriptDir%\..\Settings.ini, UserSettings, maxWaitHours, 24

                if(waitForEligibleAccounts = 1) {
                    ; Wait for eligible accounts to become available
                    ; Simple approach - just show wait message and sleep
                    CreateStatusMessage("No eligible accounts available for " . deleteMethod . ". Waiting 5 minutes before checking again...", "", 0, 0, false)
                    LogToFile("No eligible accounts available for " . deleteMethod . ". Waiting 5 minutes...")

                    ; Wait 5 minutes before checking again
                    Sleep, 300000  ; 5 minutes
                    continue  ; Go back to start of loop to check again
                } else {
                    ExitApp
                }
            }

            ; If we reach here, we have a valid loaded account for injection
            LogToFile("Successfully loaded account for injection: " . accountFileName)
        }

        ; Check if the account loaded is to check for wonderpick thanks (godpack testing)
        if(injectMethod && loadedAccount) {
            if(CheckWonderPickThanks()) {
                ; WP thanks check was performed, mark account as used and continue to next iteration
                MarkAccountAsUsed()
                loadedAccount := false
                continue  ; Skip to next iteration of main loop
            }
        }

        ; Download friend IDs for injection methods when group reroll is enabled
        if(injectMethod) {
            IniRead, groupRerollEnabled, %A_ScriptDir%\..\Settings.ini, UserSettings, groupRerollEnabled, 1
            if(groupRerollEnabled) {
                IniRead, mainIdsURL, %A_ScriptDir%\..\Settings.ini, UserSettings, mainIdsURL
                if(mainIdsURL) {
                    DownloadFile(mainIdsURL, "ids.txt")
                }
            }
        }

        Sleep, 4000 ; avoiding spam clicks at startup
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        if(setSpeed = 3)
            FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
        else
            FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)

        cantOpenMorePacks := 0
        packsInPool := 0
        packsThisRun := 0
        keepAccount := false

        ; BallCity 2025.02.21 - Track monitor
        now := A_NowUTC
        IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastStartTimeUTC
        EnvSub, now, 1970, seconds
        IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastStartEpoch

        if(!injectMethod || !loadedAccount) {
            DoTutorial()
            accountOpenPacks := 0 ;tutorial packs don't count
        }

        if(deleteMethod = "5 Pack" || deleteMethod = "5 Pack (Fast)" || deleteMethod = "Create Bots (13P)")
            wonderPicked := DoWonderPick()

        friendsAdded := AddFriends()

        SelectPack("First")
        if(cantOpenMorePacks)
            Goto, MidOfRun

        PackOpening()
        if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
            Goto, MidOfRun

        ; Pack method handling
        if(packMethod) {
            friendsAdded := AddFriends(true)
            SelectPack()
            if(cantOpenMorePacks)
                Goto, MidOfRun
        }

        PackOpening()
        if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
            Goto, MidOfRun

        ; Hourglass opening for non-injection methods ONLY
        if(!injectMethod)
            HourglassOpening() ;deletemethod check in here at the start

        ; Wonder pick additional handling - only for non-injection methods
        if(wonderPicked && !injectMethod) {
            if(deleteMethod = "5 Pack" || packMethod) {
                friendsAdded := AddFriends(true)
                SelectPack("HGPack")
                PackOpening()
            } else {
                HourglassOpening(true)
            }

            if(packMethod) {
                friendsAdded := AddFriends(true)
                SelectPack("HGPack")
                PackOpening()
            }
            else {
                HourglassOpening(true)
            }
        }

        ; Daily Mission 4hg collection and/or extra 3rd pack opening
        if((deleteMethod = "Inject Wonderpick 96P+" || deleteMethod = "Inject 13P+") && (claimDailyMission || openExtraPack)) {

            ; If only claiming daily missions (no extra pack)
            if(claimDailyMission && !openExtraPack) {
                GoToMain()
                GetAllRewards(false, true)
            }
            ; If only opening extra pack (no daily mission claim)
            else if(!claimDailyMission && openExtraPack) {
                ; Remove & add friends between 2nd free pack & HG pack if 1-pack method is enabled
                if(packMethod) {
                    friendsAdded := AddFriends(true)
                    SelectPack("HGPack")
                }
                if(!cantOpenMorePacks) {
                    HourglassOpening(true)
                }
            }
            ; If both settings are enabled (original functionality)
            else if(claimDailyMission && openExtraPack) {
                ; Remove & add friends between 2nd free pack & HG pack if 1-pack method is enabled
                if(packMethod) {
                    friendsAdded := AddFriends(true)
                }

                GoToMain()
                GetAllRewards(false, true)
                GoToMain()
                SelectPack("HGPack")
                if(!cantOpenMorePacks) {
                    PackOpening()
                }
            }
        }

        MidOfRun:

        if(deleteMethod = "Inject 13P+" || deleteMethod = "Inject Missions" && accountOpenPacks >= maxAccountPackNum)
            Goto, EndOfRun

        if (checkShouldDoMissions()) {

            HomeAndMission()
            if(beginnerMissionsDone)
                Goto, EndOfRun

            SelectPack("HGPack")
            if(cantOpenMorePacks)
                Goto, EndOfRun

            PackOpening() ;6
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            HourglassOpening(true) ;7
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            HomeAndMission()
            if(beginnerMissionsDone)
                Goto, EndOfRun

            SelectPack("HGPack")
            if(cantOpenMorePacks)
                Goto, EndOfRun
            PackOpening() ;8
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            HourglassOpening(true) ;9
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            HomeAndMission()
            if(beginnerMissionsDone)
                Goto, EndOfRun

            SelectPack("HGPack")
            if(cantOpenMorePacks)
                Goto, EndOfRun
            PackOpening() ;10
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            HourglassOpening(true) ;11
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            ; Extended mission handling for Inject Missions
            if(injectMethod && loadedAccount && deleteMethod = "Inject Missions") {
                HomeAndMission()
                if(beginnerMissionsDone)
                    Goto, EndOfRun

                SelectPack("HGPack")
                if(cantOpenMorePacks)
                    Goto, EndOfRun
                PackOpening() ;12
                if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                    Goto, EndOfRun

                HourglassOpening(true) ;13
                if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                    Goto, EndOfRun
            }

            HomeAndMission(1)
            SelectPack("HGPack")
            if(cantOpenMorePacks)
                Goto, EndOfRun
            PackOpening() ;12
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            HomeAndMission(1)
            SelectPack("HGPack")
            if(cantOpenMorePacks)
                Goto, EndOfRun
            PackOpening() ;13
            if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
                Goto, EndOfRun

            beginnerMissionsDone := 1
            if(injectMethod && loadedAccount)
                setMetaData()
        }

        EndOfRun:

        if(ocrShinedust && injectMethod && loadedAccount && s4tEnabled) {
            GoToMain()
            ; FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518, 500)
            CountShinedust()
        }

        if(wonderpickForEventMissions) {
            GoToMain()
            FindImageAndClick(240, 80, 265, 100, , "WonderPick", 59, 429) ;click until in wonderpick Screen
            DoWonderPickOnly()
        }

        ; Special missions
        IniRead, claimSpecialMissions, %A_ScriptDir%\..\Settings.ini, UserSettings, claimSpecialMissions, 0
        if (claimSpecialMissions = 1 && (deleteMethod = "Inject 13P+" || deleteMethod = "Inject Wonderpick 96P+")) {
            ; removed check for !specialMissionsDone := 1 so that users don't need to constantly reset claim status on accounts.
            GoToMain()
            HomeAndMission(1)
            GetEventRewards(true) ; collects all the Special mission hourglass
            specialMissionsDone := 1
            cantOpenMorePacks := 0
            if (injectMethod && loadedAccount)
                setMetaData()
        }

        ; Hourglass spending
        IniRead, spendHourGlass, %A_ScriptDir%\..\Settings.ini, UserSettings, spendHourGlass, 0
        if (spendHourGlass = 1 && !(deleteMethod = "Inject 13P+" && accountOpenPacks >= maxAccountPackNum || deleteMethod = "Inject Missions" && accountOpenPacks >= maxAccountPackNum)) {
            SpendAllHourglass()
        }

        ; Friend removal for Inject Wonderpick 96P+
        if (injectMethod && friended && !keepAccount) {
            RemoveFriends()
        }
        
        ; Showcase likes
        IniRead, showcaseNumber, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseLikes
        IniRead, showcaseEnabled, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseEnabled
        if (showcaseNumber > 0 && showcaseEnabled = 1) {
            showcaseNumber -= 1
            IniWrite, %showcaseNumber%, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseLikes
            FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518, 500)
            showcaseLikes()
            ; FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518, 500)
        }

        ; BallCity 2025.02.21 - Track monitor
        now := A_NowUTC
        IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastEndTimeUTC
        EnvSub, now, 1970, seconds
        IniWrite, %now%, %A_ScriptDir%\%scriptName%.ini, Metrics, LastEndEpoch

        rerolls++
        rerolls_local++
        IniWrite, %rerolls%, %A_ScriptDir%\%scriptName%.ini, Metrics, rerolls

        totalSeconds := Round((A_TickCount - rerollStartTime) / 1000) ; Total time in seconds
        totalSeconds_local := Round((A_TickCount - rerollStartTime_local) / 1000) ; Total time in seconds
        avgtotalSeconds := Round(totalSeconds_local / rerolls_local) ; Total time in seconds
        aminutes := Floor(avgtotalSeconds / 60) ; Average minutes
        aseconds := Mod(avgtotalSeconds, 60) ; Average remaining seconds
        mminutes := Floor(totalSeconds / 60) ; Total minutes
        sseconds := Mod(totalSeconds, 60) ; Total remaining seconds

        ; Display the times
        CreateStatusMessage("Avg: " . aminutes . "m " . aseconds . "s | Runs: " . rerolls . " | Account Packs " . accountOpenPacks, "AvgRuns", 0, 605, false, true)

        ; Log to file
        LogToFile("Packs: " . packsThisRun . " | Total time: " . mminutes . "m " . sseconds . "s | Avg: " . aminutes . "m " . aseconds . "s | Runs: " . rerolls)

        if (nukeAccount && !keepAccount && !injectMethod) {
            CreateStatusMessage("Deleting account...",,,, false)
            menuDelete()
        } else if (friended) {
            CreateStatusMessage("Unfriending...",,,, false)
            RemoveFriends()
        }

        AppendToJsonFile(packsThisRun)

        ; Check for 40 first to quit
        if (deleteMethod = "Inject 13P+" && accountOpenPacks >= maxAccountPackNum) {
            if (injectMethod && loadedAccount) {
                if (!keepAccount) {
                    MarkAccountAsUsed()
                }
                loadedAccount := false
                continue
            }
        }

        if (injectMethod && loadedAccount) {
            ; For injection methods, mark the account as used
            if (!keepAccount) {
                MarkAccountAsUsed()  ; Remove account from queue
                if(verboseLogging)
                    LogToFile("Marked injected account as used: " . accountFileName)
            } else {
                if(verboseLogging)
                    LogToFile("Keeping injected account: " . accountFileName)
            }

            ; Reset loadedAccount so it will be loaded fresh next iteration
            loadedAccount := false

        } else if (!injectMethod) {
            if ((!injectMethod || !loadedAccount) && (!nukeAccount || keepAccount)) {
                ; Save account for Create Bots
                ; At end of Create Bots run - check if we already have XML from tradeables
                deviceAccount := GetDeviceAccountFromXML()

                if (deviceAccountXmlMap.HasKey(deviceAccount) && FileExist(deviceAccountXmlMap[deviceAccount])) {
                    ; We already have an XML from tradeable finds - update and rename it
                    existingXmlPath := deviceAccountXmlMap[deviceAccount]

                    ; Update XML with final account state
                    UpdateSavedXml(existingXmlPath)

                    ; Build new filename with final pack count and metadata
                    metadata := ""
                    if(beginnerMissionsDone)
                        metadata .= "B"
                    if(soloBattleMissionDone)
                        metadata .= "S"
                    if(intermediateMissionsDone)
                        metadata .= "I"
                    if(specialMissionsDone)
                        metadata .= "X"
                    if(accountHasPackInTesting)
                        metadata .= "T"

                    ; Extract timestamp from existing filename
                    SplitPath, existingXmlPath, oldFileName, saveDir
                    RegExMatch(oldFileName, "i)_(\d{14})_", match)
                    timestamp := match1

                    ; Create new filename: 13P_[original_timestamp]_1(B).xml
                    newFileName := accountOpenPacks . "P_" . timestamp . "_" . winTitle . "(" . metadata . ").xml"
                    newXmlPath := saveDir . "\" . newFileName

                    ; Rename the file
                    FileMove, %existingXmlPath%, %newXmlPath%, 1

                    ; Update mapping and accountFileName
                    deviceAccountXmlMap[deviceAccount] := newXmlPath
                    accountFileName := newFileName

                } else {
                    ; No tradeable XML exists - create new one normally
                    savedXmlPath := ""
                    saveAccount("All", savedXmlPath)

                    if (savedXmlPath) {
                        SplitPath, savedXmlPath, xmlFileName
                        accountFileName := xmlFileName
                    }
                }

                ; if Create Bots + FoundTradeable, log to database and push discord webhook message(s)
                if (!loadDir && s4tPendingTradeables.Length() > 0) {
                    ProcessPendingTradeables()
                }

                beginnerMissionsDone := 0
                soloBattleMissionDone := 0
                intermediateMissionsDone := 0
                specialMissionsDone := 0
                accountHasPackInTesting := 0

                restartGameInstance("New Run", false)
            } else {
                if (stopToggle) {
                    CreateStatusMessage("Stopping...",,,, false)
                    ExitApp
                }
                restartGameInstance("New Run", false)
            }
        }
    }
}

return

HomeAndMission(homeonly := 0, completeSecondMisson=false) {
    Sleep, 250
    Leveled := 0
    Loop {
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            if(!Leveled)
                Leveled := LevelUp()
            else
                LevelUp()
            FindImageAndClick(191, 393, 211, 411, , "Shop", 138, 488, 500, 1)
            if(FindImageAndClick(120, 188, 140, 208, , "Album", 79, 86 , 500, 1)){
                FindImageAndClick(191, 393, 211, 411, , "Shop", 142, 488, 500)
                break
            }
            failSafeTime := (A_TickCount - failSafe) // 1000
        }
        if(!homeonly){
            FindImageAndClick(191, 393, 211, 411, , "Shop", 142, 488, 500)
            FindImageAndClick(180, 498, 190, 508, , "Mission_dino1", 261, 478, 1000)

            wonderpicked := 0
            failSafe := A_TickCount
            failSafeTime := 0
            Loop {
                Delay(1)
                ; ADD LEVEL UP CHECK HERE
                LevelUp()

                if (completeSecondMisson){
                    adbClick_wbb(150, 390)
                }
                else {
                    adbClick_wbb(150, 286)
                }
                Delay(1)

                if(FindOrLoseImage(136, 158, 156, 190, , "Mission_dino2", 0, failSafeTime))
                    break

                if(FindOrLoseImage(108, 180, 177, 208, , "1solobattlemission", 0, failSafeTime)) {
                    beginnerMissionsDone := 1
                    if(injectMethod && loadedAccount)
                        setMetaData()
                    return
                }

                if (FindOrLoseImage(150, 159, 176, 206, , "missionwonder", 0, failSafeTime)){
                    adbClick_wbb(141, 396) ; click try it and go to wonderpick page
                    DoWonderPickOnly()
                    wonderpicked := 1
                    break
                }

                failSafeTime := (A_TickCount - failSafe) // 1000
            }
            if(!wonderpicked)
                break
        } else
            break
    }

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        Delay(1)
        ; ADD LEVEL UP CHECK HERE TOO
        LevelUp()

        adbClick_wbb(139, 424) ;clicks complete mission
        Delay(1)
        clickButton := FindOrLoseImage(145, 447, 258, 480, 80, "Button", 0, failSafeTime)
        if(clickButton) {
            adbClick_wbb(110, 369)
        }
        else if(FindOrLoseImage(191, 393, 211, 411, , "Shop", 1, failSafeTime)) {
            adbInputEvent("111") ;send ESC
            sleep, 1500
        }
        else
            break
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("In failsafe for WonderPick. " . failSafeTime "/45 seconds")
    }
    return Leveled
}

clearMissionCache() {
    adbWriteRaw("rm /data/data/jp.pokemon.pokemontcgp/files/UserPreferences/v1/MissionUserPrefs")
    waitadb()
    Sleep, 500
    ;TODO delete all user preferences?
}

/*
ChooseTag() {
	FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518, 500)
	failSafe := A_TickCount
	failSafeTime := 0
	Loop {
		FindImageAndClick(20, 500, 55, 530, , "Home", 40, 516, 500, 2)
		LevelUp()
		if(FindImageAndClick(203, 272, 237, 300, , "Profile", 143, 95, 500, 2, failSafeTime))
			break
		failSafeTime := (A_TickCount - failSafe) // 1000
		CreateStatusMessage("In failsafe for Profile. " . failSafeTime "/45 seconds")
	}
	FindImageAndClick(205, 310, 220, 319, , "ChosenTag", 143, 306, 1000)
	FindImageAndClick(53, 218, 63, 228, , "Badge", 143, 466, 500)
	FindImageAndClick(203, 272, 237, 300, , "Profile", 61, 112, 500)
	if(FindOrLoseImage(145, 140, 157, 155, , "Eevee", 1)) {
		FindImageAndClick(163, 200, 173, 207, , "ChooseEevee", 147, 207, 1000)
		FindImageAndClick(53, 218, 63, 228, , "Badge", 143, 466, 500)
	}
}
*/

FindOrLoseImage(X1, Y1, X2, Y2, searchVariation := "", imageName := "DEFAULT", EL := 1, safeTime := 0) {
    global winTitle, failSafe
    static lastStatusTime := 0

    if(slowMotion) {
        if(imageName = "speedmodMenu" || imageName = "One" || imageName = "Two" || imageName = "Three" || imageName = "speedmodMenu2" || imageName = "One2" || imageName = "Two2" || imageName = "Three2")
            return true
    }
    if(searchVariation = "")
        searchVariation := 20
    imagePath := A_ScriptDir . "\" . defaultLanguage . "\"
    confirmed := false

    if(A_TickCount - lastStatusTime > 500) {
        lastStatusTime := A_TickCount
        CreateStatusMessage("Finding " . imageName . "...")
    }

    pBitmap := from_window(WinExist(winTitle))
    Path = %imagePath%%imageName%.png
    pNeedle := GetNeedle(Path)

    ; 100% scale changes
    if (scaleParam = 287) {
        Y1 -= 8 ; offset, should be 44-36 i think?
        Y2 -= 8
        if (Y1 < 0) {
            Y1 := 0
        }
        if (imageName = "Bulba") { ; too much to the left? idk how that happens
            X1 := 200
            Y1 := 220
            X2 := 230
            Y2 := 260
        } else if (imageName = "Erika") { ; 100% fix for Erika avatar
            X1 := 149
            Y1 := 153
            X2 := 159
            Y2 := 162
        } else if (imageName = "DeleteAll") { ; 100% for Deleteall offset
            X1 := 200
            Y1 := 340
            X2 := 265
            Y2 := 530
        }
    }

    ; ImageSearch within the region
    vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, X1, Y1, X2, Y2, searchVariation)
    if(EL = 0)
        GDEL := 1
    else
        GDEL := 0
    if (!confirmed && vRet = GDEL && GDEL = 1) {
        confirmed := vPosXY
    } else if(!confirmed && vRet = GDEL && GDEL = 0) {
        confirmed := true
    }

    if (imageName = "Social" || imageName = "CommunityShowcase" || imageName = "Add" || imageName = "Search" || imageName = "inHamburgerMenu" || imageName = "Trade") {
        Path = %imagePath%Tutorial.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 111, 115, 167, 121, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(145, 451)
        }
    }

        ; Search for new privacy and TOS clearing popup; can be removed later patch
    if (imageName = "Points" || imageName = "Social" || imageName = "Country") {
        Path = %imagePath%newPrivacyTOSpopup.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 221, 394, 236, 407, searchVariation)
        if (vRet = 1) {
            CreateStatusMessage("Accepting Privacy and TOS popup.",,,, false)
            Sleep, 3000
            adbClick_wbb(142, 372)
            adbClick_wbb(142, 372)
            Sleep, 2000
            adbClick_wbb(140, 336) ; Privacy Notice
            adbClick_wbb(140, 336) ; Privacy Notice
            Sleep, 2000
            adbClick_wbb(138, 487) ; Close Privacy Notice
            adbClick_wbb(138, 487) ; Close Privacy Notice
            Sleep, 1000
            adbClick_wbb(47, 371) ; Agree to Privacy Notice
            Sleep, 200
            adbClick_wbb(143, 488) ; OK
            Sleep, 500
            adbClick_wbb(141, 371) ; OK
            adbClick_wbb(141, 371) ; OK
            Sleep, 2000
            adbClick_wbb(140, 336) ; Terms of Use
            adbClick_wbb(140, 336) ; Terms of Use
            Sleep, 2000
            adbClick_wbb(138, 487) ; Close Terms of Use
            adbClick_wbb(138, 487) ; Close Terms of Use
            Sleep, 1000
            adbClick_wbb(47, 371) ; Agree to Privacy Notice
            Sleep, 200
            adbClick_wbb(143, 488) ; OK
            Sleep, 500
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

    }

    ; Handle 7/2025 trade news update popup, remove later patch
    if(imageName = "Points" || imageName = "Social" || imageName = "Shop" || imageName = "Missions" || imageName = "WonderPick" || imageName = "Home" || imageName = "Country" || imageName = "Account2" || imageName = "Account" || imageName = "ClaimAll" || imageName = "inHamburgerMenu" || imageName = "Trade") {
        Path = %imagePath%Privacy.png ; this is just the "X" button on several pop-up menus
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 130, 477, 148, 494, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(137, 485)
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

        ; display boards
        Path = %imagePath%FeatureUnlocked1.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 125, 208, 155, 228, searchVariation)
        if (vRet = 1) {
            adbInputEvent("111") ; ESC
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

        ; Trades unlocked
        Path = %imagePath%FeatureUnlocked1.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 125, 203, 155, 217, searchVariation)
        if (vRet = 1) {
            adbInputEvent("111") ; ESC
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

        ; trying to check for other feature unlocks
        Path = %imagePath%FeatureUnlocked1.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 125, 190, 155, 238, searchVariation)
        if (vRet = 1) {
            adbInputEvent("111") ; ESC
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

        ; Try to handle "Share" feature
        Path = %imagePath%Share.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 61, 273, 74, 286, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(141, 369)
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

        ; another option to look for "share" 'x' button, different position per language? unclear.
        Path = %imagePath%Privacy.png ; this is just the "X" button on several pop-up menus
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 130, 359, 148, 379, searchVariation)
        if (vRet = 1) {
            adbInputEvent("111") ; ESC
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }

        Path = %imagePath%Update.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 15, 180, 53, 228, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(137, 485)
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }
    }

    Path = %imagePath%Error.png ; Search for communication error
    pNeedle := GetNeedle(Path)
    vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 120, 187, 155, 210, searchVariation)
    if (vRet = 1) {
        CreateStatusMessage("Error message in " . scriptName . ". Clicking retry...",,,, false)
        Sleep, 3000
        Gdip_DisposeImage(pBitmap)
        pBitmap := from_window(WinExist(winTitle))

        Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir . "\debug_startup_error.png")

        Path = %imagePath%StartupErrorX.png
        CreateStatusMessage("Searching for: " . Path,,,, false)

        if (FileExist(Path)) {
            CreateStatusMessage("File exists, searching...",,,, false)
        } else {
            CreateStatusMessage("FILE NOT FOUND: " . Path,,,, false)
        }

        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 124, 423, 155, 455, searchVariation)
        CreateStatusMessage("Search result: " . vRet . " at coords: " . vPosXY,,,, false)

        if (vRet != 1) {
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 50, 350, 250, 500, 80)
            CreateStatusMessage("Wide search result: " . vRet . " at coords: " . vPosXY,,,, false)
        }

        if (vRet = 1) {
            CreateStatusMessage("Start-up error; initiating slow reload...",,,, false)
            Sleep, 2000
            adbClick_wbb(19,125) ; platin, must remove speedmod for reload app
            Sleep, 500
            adbClick_wbb(26, 180) ; 1x
            Sleep, 2000
            adbClick_wbb(139, 440) ; click "X"
            Sleep, 10000
            Reload
        } else {
            ; assume it's communication error instead; click the "Retry" blue button
            adbClick_wbb(82, 389)
            Delay(5)
            adbClick_wbb(139, 386)
        }
        Sleep, 5000 ; longer sleep time to allow reloading, previously 1000ms
    }

    Path = %imagePath%App.png
    pNeedle := GetNeedle(Path)
    ; ImageSearch within the region
    vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 225, 300, 242, 314, searchVariation)
    if (vRet = 1) {
        restartGameInstance("Stuck at " . imageName . "...")
    }

    if(imageName = "Missions") { ; may input extra ESC and stuck at exit game
        Path = %imagePath%Delete2.png
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 118, 353, 135, 390, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(74, 353)
            Delay(1)
        }
    }

    if(imageName = "Social" || imageName = "Shop" || imageName = "Home" || imageName = "Add" || imageName = "Add2" || imageName = "requests") {
        TradeTutorial()
    }
    if(imageName = "CommunityShowcase") {
        TradeTutorialForShowcase()
    }
    Path = %imagePath%NoResponse.png
    pNeedle := GetNeedle(Path)
    ; ImageSearch within the region
    vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 38, 281, 57, 308, searchVariation)
    if (vRet = 1) {
        CreateStatusMessage("No response in " . scriptName . ". Clicking retry...",,,, false)
        adbClick_wbb(46, 299)
        Sleep, 1000
    }
    Path = %imagePath%NoResponseDark.png
    pNeedle := GetNeedle(Path)
    ; ImageSearch within the region
    vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 38, 281, 57, 308, searchVariation)
    if (vRet = 1) {
        CreateStatusMessage("No response in " . scriptName . ". Clicking retry...",,,, false)
        adbClick_wbb(46, 299)
        Sleep, 1000
    }
    if(imageName = "Social" || imageName = "Country" || imageName = "Account2" || imageName = "Account" || imageName = "Points") { ;only look for deleted account on start up.
        Path = %imagePath%NoSave.png ; look for No Save Data error message > if loaded account > delete xml > reload
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 331, 50, 449, searchVariation)
        if (scaleParam = 287) {
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 325, 55, 445, searchVariation)
        }
        if (vRet = 1) {
            adbWriteRaw("rm -rf /data/data/jp.pokemon.pokemontcgp/cache/*") ; clear cache
            waitadb()
            CreateStatusMessage("Loaded deleted account. Deleting XML...",,,, false)
            if(loadedAccount) {
                FileDelete, %loadedAccount%
                IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
            }
            LogToFile("Restarted game for instance " . scriptName . ". Reason: No save data found", "Restart.txt")
            Reload
        }
    }
    if(imageName = "Points" || imageName = "Home") { ;look for level up ok "button"
        LevelUp()
    }

    ;country for new accounts, social for inject with friend id, points for inject without friend id
    if(imageName = "Country" || imageName = "Social" || imageName = "Points")
        FSTime := 90
    else
        FSTime := 45
    if (safeTime >= FSTime) {
        if(injectMethod && loadedAccount && friended) {
            IniWrite, 1, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
        }
        restartGameInstance("Stuck at " . imageName . "...")
        failSafe := A_TickCount
    }
    Gdip_DisposeImage(pBitmap)
    return confirmed
}

FindImageAndClick(X1, Y1, X2, Y2, searchVariation := "", imageName := "DEFAULT", clickx := 0, clicky := 0, sleepTime := "", skip := false, safeTime := 0) {
    global winTitle, failSafe, confirmed, slowMotion

    if(slowMotion) {
        if(imageName = "speedmodMenu" || imageName = "One" || imageName = "Two" || imageName = "Three" || imageName = "speedmodMenu2" || imageName = "One2" || imageName = "Two2" || imageName = "Three2")
            return true
    }
    if(searchVariation = "")
        searchVariation := 20
    if (sleepTime = "") {
        global Delay
        sleepTime := Delay
    }
    imagePath := A_ScriptDir . "\" defaultLanguage "\"
    click := false
    if(clickx > 0 and clicky > 0)
        click := true
    x := 0
    y := 0
    StartSkipTime := A_TickCount

    confirmed := false

    ; 100% scale changes
    if (scaleParam = 287) {
        Y1 -= 8 ; offset, should be 44-36 i think?
        Y2 -= 8
        if (Y1 < 0) {
            Y1 := 0
        }

        clicky += 2 ; clicky offset
        if (imageName = "speedmodMenu") { ; can't do text so purple box
            X1 := 141
            Y1 := 189
            X2 := 208
            Y2 := 224
        } else if (imageName = "Opening") { ; Opening click (to skip cards) can't click on the immersive skip with 239, 497
            X1 := 10
            Y1 := 80
            X2 := 50
            Y2 := 115
            clickx := 250
            clicky := 505
        } else if (imageName = "SelectExpansion") { ; SelectExpansion
            X1 := 120
            Y1 := 135
            X2 := 161
            Y2 := 145
        } else if (imageName = "CountrySelect2") { ; SelectExpansion
            X1 := 120
            Y1 := 130
            X2 := 174
            Y2 := 155
        } else if (imageName = "Profile") { ; ChangeTag GP found
            X1 := 213
            Y1 := 273
            X2 := 226
            Y2 := 286
        } else if (imageName = "ChosenTag") { ; ChangeTag GP found
            X1 := 218
            Y1 := 307
            X2 := 231
            Y2 := 312
        } else if (imageName = "Badge") { ; ChangeTag GP found
            X1 := 48
            Y1 := 204
            X2 := 72
            Y2 := 230
        } else if (imageName = "ChooseErika") { ; ChangeTag GP found
            X1 := 150
            Y1 := 286
            X2 := 155
            Y2 := 291
        } else if (imageName = "ChooseEevee") { ; Change Eevee Avatar
            X1 := 157
            Y1 := 195
            X2 := 162
            Y2 := 200
            clickx := 147
            clicky := 207
        }
    }

    if(click) {
        adbClick_wbb(clickx, clicky)
        clickTime := A_TickCount
    }
    CreateStatusMessage("Finding and clicking " . imageName . "...")

    messageTime := 0
    firstTime := true
    Loop { ; Main loop
        Sleep, 100
        if(click) {
            ElapsedClickTime := A_TickCount - clickTime
            if(ElapsedClickTime > sleepTime) {
                adbClick_wbb(clickx, clicky)
                clickTime := A_TickCount
            }
        }

        if (confirmed) {
            continue
        }

        pBitmap := from_window(WinExist(winTitle))
        Path = %imagePath%%imageName%.png
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, X1, Y1, X2, Y2, searchVariation)
        if (!confirmed && vRet = 1) {
            confirmed := vPosXY
        } else {
            ElapsedTime := (A_TickCount - StartSkipTime) // 1000
            if(imageName = "Country")
                FSTime := 90
            else if(imageName = "Proceed") ; Decrease time for Marowak
                FSTime := 8
            else
                FSTime := 45
            if(!skip) {
                if(ElapsedTime - messageTime > 0.5 || firstTime) {
                    CreateStatusMessage("Looking for " . imageName . " for " . ElapsedTime . "/" . FSTime . " seconds")
                    messageTime := ElapsedTime
                    firstTime := false
                }
            }
            if (ElapsedTime >= FSTime || safeTime >= FSTime) {
                CreateStatusMessage("Instance " . scriptName . " has been stuck for 90s. Killing it...")
                if(injectMethod && loadedAccount && friended) {
                    IniWrite, 1, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
                }
                restartGameInstance("Stuck at " . imageName . "...") ; change to reset the instance and delete data then reload script
            }
        }

        Path = %imagePath%Error.png ; Search for communication error
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 120, 187, 155, 210, searchVariation)
        if (vRet = 1) {
            CreateStatusMessage("Error message in " . scriptName . ". Clicking retry...",,,, false)
            Sleep, 3000
            Gdip_DisposeImage(pBitmap)
            pBitmap := from_window(WinExist(winTitle))

            Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir . "\debug_startup_error.png")

            Path = %imagePath%StartupErrorX.png
            CreateStatusMessage("Searching for: " . Path,,,, false)

            if (FileExist(Path)) {
                CreateStatusMessage("File exists, searching...",,,, false)
            } else {
                CreateStatusMessage("FILE NOT FOUND: " . Path,,,, false)
            }

            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 124, 423, 155, 455, searchVariation)
            CreateStatusMessage("Search result: " . vRet . " at coords: " . vPosXY,,,, false)

            if (vRet != 1) {
                vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 50, 350, 250, 500, 80)
                CreateStatusMessage("Wide search result: " . vRet . " at coords: " . vPosXY,,,, false)
            }

            if (vRet = 1) {
                CreateStatusMessage("Start-up error; initiating slow reload...",,,, false)
                Sleep, 2000
                adbClick_wbb(19,125) ; platin, must remove speedmod for reload app
                Sleep, 500
                adbClick_wbb(26, 180) ; 1x
                Sleep, 2000
                adbClick_wbb(139, 440) ; click the "X" button
                Sleep, 10000
                Reload ; reload the script to reset the instance
            } else {
                ; assume it's communication error instead; click the "Retry" blue button
                adbClick_wbb(82, 389)
                Delay(5)
                adbClick_wbb(139, 386)
            }
            Sleep, 5000 ; longer sleep time to allow reloading, previously 1000ms
        }

        if (imageName = "Social" || imageName = "CommunityShowcase" || imageName = "Add" || imageName = "Search") {
            Path = %imagePath%Tutorial.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 111, 115, 167, 121, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(145, 451)
            }
        }

        ; Search for new privacy and TOS clearing popup; can be removed later patch
        if (imageName = "Points" || imageName = "Social" || imageName = "Country") {
            Path = %imagePath%newPrivacyTOSpopup.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 221, 394, 236, 407, searchVariation)
            if (vRet = 1) {
                CreateStatusMessage("Accepting Privacy and TOS popup.",,,, false)
                Sleep, 1000
                adbClick_wbb(142, 372)
                adbClick_wbb(142, 372)
                Sleep, 2000
                adbClick_wbb(140, 336) ; Privacy Notice
                adbClick_wbb(140, 336) ; Privacy Notice
                Sleep, 2000
                adbClick_wbb(138, 487) ; Close Privacy Notice
                adbClick_wbb(138, 487) ; Close Privacy Notice
                Sleep, 1000
                adbClick_wbb(47, 371) ; Agree to Privacy Notice
                Sleep, 200
                adbClick_wbb(143, 488) ; OK
                Sleep, 500
                adbClick_wbb(141, 371) ; OK
                adbClick_wbb(141, 371) ; OK
                Sleep, 1500
                adbClick_wbb(140, 336) ; Terms of Use
                adbClick_wbb(140, 336) ; Terms of Use
                Sleep, 2000
                adbClick_wbb(138, 487) ; Close Terms of Use
                adbClick_wbb(138, 487) ; Close Terms of Use
                Sleep, 1000
                adbClick_wbb(47, 371) ; Agree to Privacy Notice
                Sleep, 200
                adbClick_wbb(143, 488) ; OK
                Sleep, 500
                Gdip_DisposeImage(pBitmap)
                return confirmed
            }

        }

        ; Search for 7/2025 trade news update popup; can be removed later patch
        if(imageName = "Points" || imageName = "Social" || imageName = "Shop" || imageName = "Missions" || imageName = "WonderPick" || imageName = "Home" || imageName = "Country" || imageName = "Account2" || imageName = "Account" || imageName = "ClaimAll" || imageName = "inHamburgerMenu" || imageName = "Trade") {
            Path = %imagePath%Privacy.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 130, 477, 148, 494, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(137, 485)
                Gdip_DisposeImage(pBitmap)
                continue
            }

            ; display boards
            Path = %imagePath%FeatureUnlocked1.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 125, 208, 155, 228, searchVariation)
            if (vRet = 1) {
                adbInputEvent("111") ; ESC
                Gdip_DisposeImage(pBitmap)
                return confirmed
            }

            ; trying to check for other feature unlocks
            Path = %imagePath%FeatureUnlocked1.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 125, 150, 155, 240, searchVariation)
            if (vRet = 1) {
                adbInputEvent("111") ; ESC
                Gdip_DisposeImage(pBitmap)
                return confirmed
            }

            ; Try to handle "Share" feature
            Path = %imagePath%Share.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 61, 273, 74, 286, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(141, 369)
                Gdip_DisposeImage(pBitmap)
                return confirmed
            }

            Path = %imagePath%Update.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 20, 191, 36, 211, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(137, 485)
                Gdip_DisposeImage(pBitmap)
                continue
            }
        }

        Path = %imagePath%App.png
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 225, 300, 242, 314, searchVariation)
        if (vRet = 1) {
            restartGameInstance("Stuck at " . imageName . "...")
        }

        if(imageName = "Social" || imageName = "Country" || imageName = "Account2" || imageName = "Account") { ;only look for deleted account on start up.
            Path = %imagePath%NoSave.png ; look for No Save Data error message > if loaded account > delete xml > reload
            pNeedle := GetNeedle(Path)
            ; ImageSearch within the region
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 331, 50, 449, searchVariation)
            if (scaleParam = 287) {
                vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 325, 55, 445, searchVariation)
            }
            if (vRet = 1) {
                adbWriteRaw("rm -rf /data/data/jp.pokemon.pokemontcgp/cache/*") ; clear cache
                waitadb()
                CreateStatusMessage("Loaded deleted account. Deleting XML...",,,, false)
                if(loadedAccount) {
                    FileDelete, %loadedAccount%
                    IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
                }
                LogToFile("Restarted game for instance " . scriptName . ". Reason: No save data found", "Restart.txt")
                Reload
            }
        }

        if(imageName = "Missions") { ; may input extra ESC and stuck at exit game
            Path = %imagePath%Delete2.png
            pNeedle := GetNeedle(Path)
            ; ImageSearch within the region
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 118, 353, 135, 390, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(74, 353)
                Delay(1)
            }
        }
        if(imageName = "Skip2" || imageName = "Pack" || imageName = "Hourglass2") {
            Path = %imagePath%notenoughitems.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 92, 299, 115, 317, 0)
            if(vRet = 1) {
                cantOpenMorePacks := 1
                return 0
                ;restartGameInstance("Not Enough Items")
            }
        }

        if(imageName = "Mission_dino2") {
            Path = %imagePath%1solobattlemission.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 108, 180, 177, 208, 0)
            if(vRet = 1) {
                beginnerMissionsDone := 1
                if(injectMethod && loadedAccount)
                    setMetaData()
                return
                ;restartGameInstance("beginner missions done except solo battle")
            }
        }

        if(imageName = "WonderPick") {
            Path = %imagePath%Update.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 15, 187, 62, 209, searchVariation)
            if (vRet = 1) {
                CreateStatusMessage("Update popup found! Clicking to dismiss...")
                adbClick_wbb(137, 485)
                Sleep, 1000
            }
        }

        Gdip_DisposeImage(pBitmap)
        if(imageName = "Points" || imageName = "Home") { ;look for level up ok "button"
            LevelUp()
        }
        if(imageName = "Social" || imageName = "Shop" || imageName = "Home" || imageName = "Add" || imageName = "Add2" || imageName = "requests" || imageName = "insideTrade" || imageName = "Trade") {
            TradeTutorial()
        }
        if(imageName = "CommunityShowcase") {
            TradeTutorialForShowcase()
        }
        if(skip) {
            ElapsedTime := (A_TickCount - StartSkipTime) // 1000
            if(ElapsedTime - messageTime > 0.5 || firstTime) {
                CreateStatusMessage("Looking for " . imageName . "`nSkipping in " . (skip - ElapsedTime) . " seconds...")
                messageTime := ElapsedTime
                firstTime := false
            }
            if (ElapsedTime >= skip) {
                confirmed := false
                ElapsedTime := ElapsedTime/2
                break
            }
        }
        if (confirmed) {
            break
        }
    }
    Gdip_DisposeImage(pBitmap)
    return confirmed
}

LevelUp() {
    Leveled := FindOrLoseImage(100, 86, 167, 116, , "LevelUp", 0)
    if(Leveled) {
        clickButton := FindOrLoseImage(75, 340, 195, 530, 80, "Button", 0, failSafeTime)
        StringSplit, pos, clickButton, `,  ; Split at ", "
        if (scaleParam = 287) {
            pos2 += 5
        }
        adbClick_wbb(pos1, pos2)
    }
    Delay(1)
}

resetWindows() {
    global Columns, winTitle, SelectedMonitorIndex, scaleParam, defaultLanguage, rowGap

    ; Simply call our direct positioning function
    DirectlyPositionWindow()

    return true
}

DirectlyPositionWindow() {
    global Columns, runMain, Mains, scaleParam, winTitle, SelectedMonitorIndex, rowGap, titleHeight

    ; Make sure rowGap is defined
    if (!rowGap)
        rowGap := 100

    ; Get monitor information
    SelectedMonitorIndex := RegExReplace(SelectedMonitorIndex, ":.*$")
    SysGet, Monitor, Monitor, %SelectedMonitorIndex%

    ; Calculate position based on instance number
    Title := winTitle

    if (runMain) {
        instanceIndex := (Mains - 1) + Title + 1
    } else {
        instanceIndex := Title
    }

    if (MuMuv5) {
        titleHeight := 50
    } else {
        titleHeight := 45
    }

    borderWidth := 4 - 1
    rowHeight := titleHeight + 489 + 4
    currentRow := Floor((instanceIndex - 1) / Columns)

    y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
    ;x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
    if (MuMuv5) {
        x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * (scaleParam - borderWidth * 2)) - borderWidth
    } else {
        x := MonitorLeft + (Mod((instanceIndex - 1), Columns) * scaleParam)
    }

    WinSet, Style, -0xC00000, %Title%
    WinMove, %Title%, , %x%, %y%, %scaleParam%, %rowHeight%
    WinSet, Style, +0xC00000, %Title%
    WinSet, Redraw, , %Title%

    CreateStatusMessage("Positioned window at x:" . x . " y:" . y,,,, false)

    return true
}

restartGameInstance(reason, RL := true) {
    global friended, scriptName, packsThisRun, injectMethod, loadedAccount, DeadCheck, starCount, packsInPool, openPack, invalid, accountFile, username, stopToggle, accountFileName
    global isCurrentlyDoingWPCheck

    ; Check if we're currently doing a WP thanks check (use the proper flag)
    if (isCurrentlyDoingWPCheck) {
        CreateStatusMessage("WP Thanks check encountered issue: " . reason . ". Removing W flag and continuing...",,,, false)
        LogToFile("WP Thanks check encountered issue (" . reason . ") for account: " . accountFileName . ". Removing W flag.")

        ; Remove W flag and send warning
        RemoveWFlagFromAccount()
        SendWPStuckWarning(reason)

        ; Clear the flag since we're exiting the WP check
        isCurrentlyDoingWPCheck := false

        ; Don't deadcheck (which would remove friends of potential godpacks) - just mark account as used and continue
        if (injectMethod && loadedAccount) {
            MarkAccountAsUsed()
            loadedAccount := false
        }

        ; Restart without deadcheck
        waitadb()
        adbWriteRaw("am force-stop jp.pokemon.pokemontcgp")
        waitadb()
        Sleep, 2000
        clearMissionCache()
        adbWriteRaw("am start -W -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity -f 0x10018000")
        waitadb()
        Sleep, 5000

        return  ; Exit early to continue with next account
    }

    ; Original restartGameInstance logic for non-WP checks
    if (Debug)
        CreateStatusMessage("Restarting game reason:`n" . reason)
    else if (InStr(reason, "Stuck"))
        CreateStatusMessage("Stuck! Restarting game...",,,, false)
    else
        CreateStatusMessage("Restarting game...",,,, false)

    if (RL = "GodPack") {
        LogToFile("Restarted game for instance " . scriptName . ". Reason: " reason, "Restart.txt")
        IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
        AppendToJsonFile(packsThisRun)

        if (stopToggle) {
            CreateStatusMessage("Stopping...",,,, false)
            ExitApp
        }

        Reload
    } else {
        waitadb()
        adbWriteRaw("am force-stop jp.pokemon.pokemontcgp")
        waitadb()
        Sleep, 2000
        clearMissionCache()
        if (!RL && DeadCheck = 0) {
            adbWriteRaw("rm /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") ; delete account data
        }
        waitadb()
        Sleep, 500
        adbWriteRaw("am start -W -n jp.pokemon.pokemontcgp/com.unity3d.player.UnityPlayerActivity -f 0x10018000")
        waitadb()
        Sleep, 5000

        if (RL) {
            AppendToJsonFile(packsThisRun)
            if(!injectMethod) {
                if (menuDeleteStart()) {
                    IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
                    logMessage := "\n" . username . "\n[" . (starCount ? starCount : "0") . "/5][" . (packsInPool ? packsInPool : 0) . "P][" . openPack . "] " . (invalid ? invalid . " God Pack" : "Some sort of pack") . " found in instance: " . scriptName . "\nFile name: " . accountFile . "\nGot stuck doing something. Check Log_" . scriptName . ".txt."
                    LogToFile(Trim(StrReplace(logMessage, "\n", " ")))
                }
            }
            LogToFile("Restarted game for instance " . scriptName . ". Reason: " reason, "Restart.txt")

            if (stopToggle) {
                CreateStatusMessage("Stopping...",,,, false)
                ExitApp
            }

            Reload
        }

        if (stopToggle) {
            CreateStatusMessage("Stopping...",,,, false)
            ExitApp
        }
    }
}

menuDelete() {
    sleep, %Delay%
    failSafe := A_TickCount
    failSafeTime := 0
    Loop
    {
        sleep, %Delay%
        sleep, %Delay%
        adbClick_wbb(245, 518)
        if(FindImageAndClick(90, 260, 126, 290, , "Settings", , , , 1, failSafeTime)) ;wait for settings menu
            break
        sleep, %Delay%
        sleep, %Delay%
        adbClick_wbb(50, 100)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Settings`n(" . failSafeTime . " seconds)")
    }
    Sleep,%Delay%
    FindImageAndClick(24, 158, 57, 189, , "Account", 140, 440, 2000) ;wait for other menu
    Sleep,%Delay%
    FindImageAndClick(56, 435, 108, 460, , "Account2", 79, 256, 1000) ;wait for account menu
    Sleep,%Delay%

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            clickButton := FindOrLoseImage(75, 340, 195, 530, 40, "Button2", 0, failSafeTime)
            if(!clickButton) {
                ; fix https://discord.com/channels/1330305075393986703/1354775917288882267/1355090394307887135
                clickImage := FindOrLoseImage(200, 340, 250, 530, 60, "DeleteAll", 0, failSafeTime)
                if(clickImage) {
                    StringSplit, pos, clickImage, `,  ; Split at ", "
                    if (scaleParam = 287) {
                        pos2 += 5
                    }
                    adbClick_wbb(pos1, pos2)
                }
                else {
                    adbClick_wbb(230, 506)
                }
                Delay(1)
                failSafeTime := (A_TickCount - failSafe) // 1000
                CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
            }
            else {
                break
            }
            Sleep,%Delay%
        }
        StringSplit, pos, clickButton, `,  ; Split at ", "
        if (scaleParam = 287) {
            pos2 += 5
        }
        adbClick_wbb(pos1, pos2)
        break
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
    }

    Sleep, 2500
}

menuDeleteStart() {
    global friended
    if(keepAccount) {
        return keepAccount
    }
    if(friended) {
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        if(setSpeed = 3)
            FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
        else
            FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        if(!friended)
            break
        adbClick_wbb(255, 83)
        if(FindOrLoseImage(105, 396, 121, 406, , "Country", 0, failSafeTime)) { ;if at country continue
            break
        }
        else if(FindOrLoseImage(20, 120, 50, 150, , "Menu", 0, failSafeTime)) { ; if the clicks in the top right open up the game settings menu then continue to delete account
            Sleep,%Delay%
            FindImageAndClick(56, 435, 108, 460, , "Account2", 79, 256, 1000) ;wait for account menu
            Sleep,%Delay%
            failSafe := A_TickCount
            failSafeTime := 0
            Loop {
                clickButton := FindOrLoseImage(75, 340, 195, 530, 80, "Button", 0, failSafeTime)
                if(!clickButton) {
                    clickImage := FindOrLoseImage(200, 340, 250, 530, 60, "DeleteAll", 0, failSafeTime)
                    if(clickImage) {
                        StringSplit, pos, clickImage, `,  ; Split at ", "
                        if (scaleParam = 287) {
                            pos2 += 5
                        }
                        adbClick_wbb(pos1, pos2)
                    }
                    else {
                        adbClick_wbb(230, 506)
                    }
                    Delay(1)
                    failSafeTime := (A_TickCount - failSafe) // 1000
                    CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
                }
                else {
                    break
                }
                Sleep,%Delay%
            }
            StringSplit, pos, clickButton, `,  ; Split at ", "
            if (scaleParam = 287) {
                pos2 += 5
            }
            adbClick_wbb(pos1, pos2)
            break
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
        }
        CreateStatusMessage("Looking for Country/Menu")
        Delay(1)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Country/Menu`n(" . failSafeTime . "/45 seconds)")
    }
    if(loadedAccount) {
        ;    FileDelete, %loadedAccount%
    }
}

CheckPack() {
    global currentShinyExPackPos, currentPackInfo
    
    currentShinyExPackPos := []
    currentPackInfo := {"isVerified": false, "CardSlot": [], "TypeCount": {}}
    currentPackIs6Card := false ; reset before each pack check

    ; Update pack count.
    accountOpenPacks += 1
    if (injectMethod && loadedAccount)
        UpdateAccount()

    packsInPool += 1
    packsThisRun += 1

    ; NEW: Disable card detection for Create Bots and Inject 13P+
    ; Only run detection for Inject Wonderpick 96P+
    skipCardDetection := (deleteMethod = "Create Bots (13P)" || deleteMethod = "Inject 13P+")

    ; If not doing card detection and no friends and s4t disabled, just return early
    if(skipCardDetection && !friendIDs && friendID = "" && !s4tEnabled)
        return false

    currentPackIs4Card := DetectFourCardPack()
    if (!currentPackIs4Card) {
        currentPackIs6Card := DetectSixCardPack()
    }

    ; Wait for cards to render before checking.
    Loop {
        if (CheckCardLoading() = 0)
            break
        Delay(1)
    }

    ; Determine total cards in pack for 4-diamond s4t calculations
    totalCardsInPack := currentPackIs6Card ? 6 : (currentPackIs4Card ? 4 : 5)

    ; NEW: Check for s4t tradeable cards FIRST (before invalid/godpack checks)
    ; This allows s4t to work even on "invalid" packs with crowns/immersives/etc
    if (s4tEnabled) {
        found3Dmnd := 0
        found4Dmnd := 0
        found1Star := 0
        foundGimmighoul := 0
        foundCrown := 0
        foundImmersive := 0
        foundShiny1Star := 0
        foundShiny2Star := 0
        foundTrainer := 0
        foundRainbow := 0
        foundFullArt := 0

        ; Check all border types for s4t (only if enabled)
        if (s4t3Dmnd) {
            found3Dmnd := FindBorders("3diamond")
        }
        if (s4t1Star) {
            found1Star := FindBorders("1star")
        }
        if (s4t4Dmnd) {
            ; Detecting a 4-diamond EX card by subtracting other types
            found4Dmnd := totalCardsInPack - FindBorders("normal")
            if (found4Dmnd > 0) {
                if (s4t3Dmnd)
                    found4Dmnd -= found3Dmnd
                else
                    found4Dmnd -= FindBorders("3diamond")
            }
            if (found4Dmnd > 0) {
                if (s4t1Star)
                    found4Dmnd -= found1Star
                else
                    found4Dmnd -= FindBorders("1star")
            }
            if (found4Dmnd > 0) {
                found4Dmnd -= FindBorders("trainer")
                found4Dmnd -= FindBorders("rainbow")
                found4Dmnd -= FindBorders("fullart")
            }
        }
        if (s4tGholdengo && openPack = "Shining") {
            foundGimmighoul := FindCard("gimmighoul")
        }

        ; NEW: Only check if the specific card type is enabled
        if (s4tCrown) {
            foundCrown := FindBorders("crown")
        }
        if (s4tImmersive) {
            foundImmersive := FindBorders("immersive")
        }
        if (s4tShiny1Star) {
            foundShiny1Star := FindBorders("shiny1star")
        }
        if (s4tShiny2Star) {
            foundShiny2Star := FindBorders("shiny2star")
        }
        if (s4tTrainer) {
            foundTrainer := FindBorders("trainer")
        }
        if (s4tRainbow) {
            foundRainbow := FindBorders("rainbow")
        }
        if (s4tFullArt) {
            foundFullArt := FindBorders("fullart")
        }

        foundTradeable := found3Dmnd + found4Dmnd + found1Star + foundGimmighoul + foundCrown + foundImmersive + foundShiny1Star + foundShiny2Star + foundTrainer + foundRainbow + foundFullArt

        if (foundTradeable > 0) {
            FoundTradeable(found3Dmnd, found4Dmnd, found1Star, foundGimmighoul, foundCrown, foundImmersive, foundShiny1Star, foundShiny2Star, foundTrainer, foundRainbow, foundFullArt)
            ; Continue with the rest of the run in s4t mode; don't return early.
        }
    }

    ; Skip rest of card detection if this is Create Bots or Inject 13P+
    if (skipCardDetection) {
        return false
    }

    foundLabel := false

    ; Check if the current pack is valid (for Inject Wonderpick 96P+ only now)
    foundShiny := FindBorders("shiny2star") + FindBorders("shiny1star")
    foundCrown := FindBorders("crown")
    foundImmersive := FindBorders("immersive")
    foundInvalid := foundShiny + foundCrown + foundImmersive

    if (foundInvalid) {
        ; Pack is invalid...
        foundInvalidGP := FindGodPack(true) ; GP is never ignored

        if (foundInvalidGP){
            restartGameInstance("Invalid God Pack Found.", "GodPack")
        }
        if (!foundInvalidGP && !InvalidCheck) {
            ; If not a GP and not "ignore invalid packs", check what cards the current pack contains which make it invalid
            if (ShinyCheck && foundShiny && !foundLabel)
                foundLabel := "Shiny"
            if (ImmersiveCheck && foundImmersive && !foundLabel)
                foundLabel := "Immersive"
            if (CrownCheck && foundCrown && !foundLabel)
                foundLabel := "Crown"

            ; Report invalid cards found.
            if (foundLabel) {
                FoundStars(foundLabel)
                restartGameInstance(foundLabel . " found. Continuing...", "GodPack")
            }
        }

        IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
        return
    }

    ; Check for god pack. if found we know its not invalid
    foundGP := FindGodPack()

    if (foundGP) {
        if (loadedAccount) {
            accountHasPackInTesting := 1  ; T flag ONLY for godpacks
            setMetaData()
            IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
        }

        restartGameInstance("God Pack found. Continuing...", "GodPack")
        return
    }

    ; Check for 2-star cards (for Inject Wonderpick 96P+ only)
    if (!CheckShinyPackOnly || shinyPacks.HasKey(openPack)) {
        foundTrainer := false
        foundRainbow := false
        foundFullArt := false
        2starCount := false

        if (PseudoGodPack && !foundLabel) {
            foundTrainer := FindBorders("trainer")
            foundRainbow := FindBorders("rainbow")
            foundFullArt := FindBorders("fullart")
            2starCount := foundTrainer + foundRainbow + foundFullArt
            if (2starCount > 1)
                foundLabel := "Double two star"
        }
        if (TrainerCheck && !foundLabel) {
            if(!PseudoGodPack)
                foundTrainer := FindBorders("trainer")
            if (foundTrainer)
                foundLabel := "Trainer"
        }
        if (RainbowCheck && !foundLabel) {
            if(!PseudoGodPack)
                foundRainbow := FindBorders("rainbow")
            if (foundRainbow)
                foundLabel := "Rainbow"
        }
        if (FullArtCheck && !foundLabel) {
            if(!PseudoGodPack)
                foundFullArt := FindBorders("fullart")
            if (foundFullArt)
                foundLabel := "Full Art"
        }

        if (foundLabel) {
            if (loadedAccount) {
                ; NEW: Do NOT add T flag for single 2-star cards
                ; Only godpacks get the T flag now
                IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
            }

            FoundStars(foundLabel)
            restartGameInstance(foundLabel . " found. Continuing...", "GodPack")
        }
    }
}

; NEW function to mark account as successfully used and remove from queue

/* ;Deprecated, use T flag instead
accountFoundGP() {
	saveDir := A_ScriptDir "\..\Accounts\Saved\" . winTitle
	accountFile := saveDir . "\" . accountFileName

	FileGetTime, accountFileTime, %accountFile%, M
	accountFileTime += 5, days

	FileSetTime, accountFileTime, %accountFile%
}
*/

; MODIFIED TrackUsedAccount function with better timestamp tracking

; NEW function to clean up stale used accounts

ControlClick(X, Y) {
    global winTitle
    ControlClick, x%X% y%Y%, %winTitle%
}

Screenshot_dev(fileType := "Dev",subDir := "") {
    global adbShell, adbPath, packs, winTitle
    SetWorkingDir %A_ScriptDir%  ; Ensures the working directory is the script's directory

    ; Define folder and file paths
    fileDir := A_ScriptDir "\..\Screenshots"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%
    if (subDir) {
        fileDir .= "\" . subDir
    }
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%

    ; File path for saving the screenshot locally
    fileName := A_Now . "_" . winTitle . "_" . fileType . ".png"
    filePath := fileDir "\" . fileName

    pBitmapW := from_window(WinExist(winTitle))
    Gdip_SaveBitmapToFile(pBitmapW, filePath)

    sleep 100

    try {
        OwnerWND := WinExist(winTitle)
        buttonWidth := 40

        Gui, DevMode_ss%winTitle%:New, +LastFound -DPIScale
        Gui, DevMode_ss%winTitle%:Add, Picture, x0 y0 w275 h534, %filePath%
        Gui, DevMode_ss%winTitle%:Show, w275 h534, Screensho %winTitle%

        sleep 100
        msgbox click on top-left corner and bottom-right corners

        KeyWait, LButton, D
        MouseGetPos , X1, Y1, OutputVarWin, OutputVarControl
        KeyWait, LButton, U
        Y1 -= 31
        ;MsgBox, The cursor is at X%X1% Y%Y1%.

        KeyWait, LButton, D
        MouseGetPos , X2, Y2, OutputVarWin, OutputVarControl
        KeyWait, LButton, U
        Y2 -= 31
        ;MsgBox, The cursor is at X%X2% Y%Y2%.

        W:=X2-X1
        H:=Y2-Y1

        pBitmap := Gdip_CloneBitmapArea(pBitmapW, X1, Y1, W, H)

        InputBox, fileName, ,"Enter the name of the needle to save"

        fileDir := A_ScriptDir . "\Scale125"
        filePath := fileDir "\" . fileName . ".png"
        Gdip_SaveBitmapToFile(pBitmap, filePath)

        msgbox click on coordinate for adbClick

        KeyWait, LButton, D
        MouseGetPos , X3, Y3, OutputVarWin, OutputVarControl
        KeyWait, LButton, U
        Y3 -= 31

        ; Convert window coordinates to device/OCR coordinates
        ; Device resolution: 540x960, Window resolution: 277x489, Y offset: 44
        OCR_X1 := Round(X1 * 540 / 277)
        OCR_Y1 := Round((Y1 - 44) * 960 / 489)
        OCR_W := Round(W * 540 / 277)
        OCR_H := Round(H * 960 / 489)
        OCR_X2 := OCR_X1 + OCR_W
        OCR_Y2 := OCR_Y1 + OCR_H

        ; Calculate center point of the box
        OCR_X3 := Round(OCR_X1 + OCR_W / 2)
        OCR_Y3 := Round(OCR_Y1 + OCR_H / 2)

        MsgBox,
        (LTrim
            ctrl+C to copy:
            FindOrLoseImage(%X1%, %Y1%, %X2%, %Y2%, , "%fileName%", 0, failSafeTime)
            FindImageAndClick(%X1%, %Y1%, %X2%, %Y2%, , "%fileName%", %X3%, %Y3%, sleepTime)
            adbClick_wbb(%X3%, %Y3%)
            OCR coordinates: %OCR_X3%, %OCR_Y3%, %OCR_W%, %OCR_H%
        )
    }
    catch {
        msgbox Failed to create screenshot GUI
    }
    return filePath
}

Screenshot(fileType := "Valid", subDir := "", ByRef fileName := "") {
    global adbShell, adbPath, packs
    SetWorkingDir %A_ScriptDir%  ; Ensures the working directory is the script's directory

    ; Define folder and file paths
    fileDir := A_ScriptDir "\..\Screenshots"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%
    if (subDir) {
        fileDir .= "\" . subDir
        if !FileExist(fileDir)
            FileCreateDir, %fileDir%
    }
    if (filename = "PACKSTATS") {
        fileDir .= "\temp"
        if !FileExist(fileDir)
            FileCreateDir, %fileDir%
    }

    ; File path for saving the screenshot locally
    fileName := A_Now . "_" . winTitle . "_" . fileType . "_" . packsInPool . "_packs.png"
    if (filename = "PACKSTATS")
        fileName := "packstats_temp.png"
    filePath := fileDir "\" . fileName

    global titleHeight
    yBias := titleHeight - 45
    pBitmapW := from_window(WinExist(winTitle))
    pBitmap := Gdip_CloneBitmapArea(pBitmapW, 18, 175+yBias, 240, 227)

    ;scale 100%
    if (scaleParam = 287) {
        pBitmap := Gdip_CloneBitmapArea(pBitmapW, 17, 168, 245, 230)
    }
    Gdip_DisposeImage(pBitmapW)
    Gdip_SaveBitmapToFile(pBitmap, filePath)

    ; Don't dispose pBitmap if it's a PACKSTATS screenshot
    if (filename != "PACKSTATS") {
        Gdip_DisposeImage(pBitmap)
        return filePath
    }

    ; For PACKSTATS, return both values and delete temp file after OCR is done
    return {filepath: filePath, bitmap: pBitmap, deleteAfterUse: true}
}

; Pause Script
PauseScript:
    CreateStatusMessage("Pausing...",,,, false)
    Pause, On
return

; Resume Script
ResumeScript:
    CreateStatusMessage("Resuming...",,,, false)
    StartSkipTime := A_TickCount ;reset stuck timers
    failSafe := A_TickCount
    Pause, Off
return

; Stop Script
StopScript:
    ToggleStop()
return

DevMode:
    ToggleDevMode()
return

ShowStatusMessages:
    ToggleStatusMessages()
return

ReloadScript:
    Reload
return

TestScript:
    ToggleTestScript()
return

ToggleStop() {
    global stopToggle, friended
    stopToggle := true
    if (!friended)
        ExitApp
    else
        CreateStatusMessage("Stopping script at the end of the run...",,,, false)
}

ToggleTestScript() {
    global GPTest
    if(!GPTest) {
        CreateStatusMessage("In GP Test Mode",,,, false)
        GPTest := true
    }
    else {
        CreateStatusMessage("Exiting GP Test Mode",,,, false)
        ;Winset, Alwaysontop, On, %winTitle%
        GPTest := false
    }
}

; Function to append a time and variable pair to the JSON file

from_window(ByRef image) {
    ; Thanks tic - https://www.autohotkey.com/boards/viewtopic.php?t=6517

    ; Get the handle to the window.
    image := (hwnd := WinExist(image)) ? hwnd : image

    ; Restore the window if minimized! Must be visible for capture.
    if DllCall("IsIconic", "ptr", image)
        DllCall("ShowWindow", "ptr", image, "int", 4)

    ; Get the width and height of the client window.
    VarSetCapacity(Rect, 16) ; sizeof(RECT) = 16
    DllCall("GetClientRect", "ptr", image, "ptr", &Rect)
        , width  := NumGet(Rect, 8, "int")
        , height := NumGet(Rect, 12, "int")

    ; struct BITMAPINFOHEADER - https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
    hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    VarSetCapacity(bi, 40, 0)                ; sizeof(bi) = 40
        , NumPut(       40, bi,  0,   "uint") ; Size
        , NumPut(    width, bi,  4,   "uint") ; Width
        , NumPut(  -height, bi,  8,    "int") ; Height - Negative so (0, 0) is top-left.
        , NumPut(        1, bi, 12, "ushort") ; Planes
        , NumPut(       32, bi, 14, "ushort") ; BitCount / BitsPerPixel
        , NumPut(        0, bi, 16,   "uint") ; Compression = BI_RGB
        , NumPut(        3, bi, 20,   "uint") ; Quality setting (3 = low quality, no anti-aliasing)
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", &bi, "uint", 0, "ptr*", pBits:=0, "ptr", 0, "uint", 0, "ptr")
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

    ; Print the window onto the hBitmap using an undocumented flag. https://stackoverflow.com/a/40042587
    DllCall("PrintWindow", "ptr", image, "ptr", hdc, "uint", 0x3) ; PW_CLIENTONLY | PW_RENDERFULLCONTENT
    ; Additional info on how this is implemented: https://www.reddit.com/r/windows/comments/8ffr56/altprintscreen/

    ; Convert the hBitmap to a Bitmap using a built in function as there is no transparency.
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", pBitmap:=0)

    ; Cleanup the hBitmap and device contexts.
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC",     "ptr", hdc)

    return pBitmap
}

; ===== TIMER FUNCTIONS =====
RefreshAccountLists:
    createAccountList(scriptName)
Return

CleanupUsedAccountsTimer:
    CleanupUsedAccounts()
Return

; ===== HOTKEYS =====
~+F5::Reload
~+F6::Pause
~+F7::ToggleStop()
~+F8::ToggleDevMode()
;~+F8::ToggleStatusMessages()
;~F9::restartGameInstance("F9")

ToggleDevMode() {

    try {
        OwnerWND := WinExist(winTitle)
        x4 := x + 5
        y4 := y + 44
        buttonWidth := 40

        Gui, DevMode%winTitle%:New, +LastFound
        Gui, DevMode%winTitle%:Font, s5 cGray Norm Bold, Segoe UI  ; Normal font for input labels
        Gui, DevMode%winTitle%:Add, Button, % "x" . (buttonWidth * 0) . " y0 w" . buttonWidth . " h25 gbboxScript", bound box

        Gui, DevMode%winTitle%:Add, Button, % "x" . (buttonWidth * 1) . " y0 w" . buttonWidth . " h25 gbboxNpauseScript", bbox pause

        Gui, DevMode%winTitle%:Add, Button, % "x" . (buttonWidth * 2) . " y0 w" . buttonWidth . " h25 gscreenshotscript", screen grab

        Gui, DevMode%winTitle%:Show, w250 h100, Dev Mode %winTitle%

    }
    catch {
        CreateStatusMessage("Failed to create button GUI.",,,, false)
    }
}

screenshotscript:
    Screenshot_dev()
return

bboxScript:
    ToggleBBox()
return

ToggleBBox() {
    dbg_bbox := !dbg_bbox
}

bboxNpauseScript:
    TogglebboxNpause()
return

TogglebboxNpause() {
    dbg_bboxNpause := !dbg_bboxNpause
}

dbg_bbox :=0
dbg_bboxNpause :=0
dbg_bbox_click :=0

ToggleStatusMessages() {
    if(showStatus) {
        showStatus := False
    }
    else
        showStatus := True
}

bboxDraw(X1, Y1, X2, Y2, color) {
    WinGetPos, xwin, ywin, Width, Height, %winTitle%
    BoxWidth := X2-X1
    BoxHeight := Y2-Y1
    ; Create a GUI
    Gui, BoundingBox%winTitle%:+AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, BoundingBox%winTitle%:Color, 123456
    Gui, BoundingBox%winTitle%:+LastFound  ; Make the GUI window the last found window for use by the line below. (straght from documentation)
    WinSet, TransColor, 123456 ; Makes that specific color transparent in the gui

    ; Create the borders and show
    Gui, BoundingBox%winTitle%:Add, Progress, x0 y0 w%BoxWidth% h2 %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x0 y0 w2 h%BoxHeight% %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%BoxWidth% y0 w2 h%BoxHeight% %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x0 y%BoxHeight% w%BoxWidth% h2 %color%

    xshow := X1+xwin
    yshow := Y1+ywin
    Gui, BoundingBox%winTitle%:Show, x%xshow% y%yshow% NoActivate
    Sleep, 100

}

bboxDraw2(X1, Y1, X2, Y2, color) {
    WinGetPos, xwin, ywin, Width, Height, %winTitle%
    BoxWidth := 10
    BoxHeight := 10
    Xm1:=X1-(BoxWidth/2)
    Xm2:=X2-(BoxWidth/2)
    Ym1:=Y1-(BoxWidth/2)
    Ym2:=Y2-(BoxWidth/2)
    Xh1:=Xm1+BoxWidth
    Xh2:=Xm2+BoxWidth
    Yh1:=Ym1+BoxHeight
    Yh2:=Ym2+BoxHeight

    ; Create a GUI
    Gui, BoundingBox%winTitle%:+AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, BoundingBox%winTitle%:Color, 123456
    Gui, BoundingBox%winTitle%:+LastFound  ; Make the GUI window the last found window for use by the line below. (straght from documentation)
    WinSet, TransColor, 123456 ; Makes that specific color transparent in the gui

    ; Create the borders and show
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xm1% y%Ym1% w%BoxWidth% h2 %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xm1% y%Ym1% w2 h%BoxHeight% %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xh1% y%Ym1% w2 h%BoxHeight% %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xm1% y%Yh1% w%BoxWidth% h2 %color%

    ; Create the borders and show
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xm2% y%Ym2% w%BoxWidth% h2 %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xm2% y%Ym2% w2 h%BoxHeight% %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xh2% y%Ym2% w2 h%BoxHeight% %color%
    Gui, BoundingBox%winTitle%:Add, Progress, x%Xm2% y%Yh2% w%BoxWidth% h2 %color%

    xshow := xwin
    yshow := ywin
    Gui, BoundingBox%winTitle%:Show, x%xshow% y%yshow% NoActivate
    Sleep, 100

}

adbSwipe_wbb(params) {
    if(dbg_bbox)
        bboxAndPause_swipe(params, dbg_bboxNpause)
    adbSwipe(params)
}

bboxAndPause_swipe(params, doPause := False) {
    paramsplit := StrSplit(params , " ")
    X1:=round(paramsplit[1] / 535 * 277)
    Y1:=round((paramsplit[2] / 960 * 489) + 44)
    X2:=round(paramsplit[3] / 535 * 277)
    Y2:=round((paramsplit[4] / 960 * 489) + 44)
    speed:=paramsplit[5]
    CreateStatusMessage("Swiping (" . X1 . "," . Y1 . ") to (" . X2 . "," . Y2 . ") speed " . speed,,,, false)

    color := "BackgroundYellow"

    ;bboxDraw2(X1, Y1, X2, Y2, color)

    bboxDraw(X1-5, Y1-5, X1+5, Y1+5, color)
    if (doPause) {
        Pause
    }
    Gui, BoundingBox%winTitle%:Destroy

    bboxDraw(X2-5, Y2-5, X2+5, Y2+5, color)
    if (doPause) {
        Pause
    }
    Gui, BoundingBox%winTitle%:Destroy
}

adbClick_wbb(X,Y)  {
    if(dbg_bbox)
        bboxAndPause_click(X, Y, dbg_bboxNpause)
    adbClick(X,Y)
}

bboxAndPause_click(X, Y, doPause := False) {
    CreateStatusMessage("Clicking X " . X . " Y " . Y,,,, false)

    color := "BackgroundBlue"

    bboxDraw(X-5, Y-5, X+5, Y+5, color)

    if (doPause) {
        Pause
    }

    if GetKeyState("F4", "P") {
        Pause
    }
    Gui, BoundingBox%winTitle%:Destroy
}

bboxAndPause_immage(X1, Y1, X2, Y2, pNeedleObj, vret := False, doPause := False) {
    CreateStatusMessage("Searching " . pNeedleObj.Name . " returns " . vret,,,, false)

    if(vret>0) {
        color := "BackgroundGreen"
    } else {
        color := "BackgroundRed"
    }

    bboxDraw(X1, Y1, X2, Y2, color)

    if (doPause && vret) {
        Pause
    }

    if GetKeyState("F4", "P") {
        Pause
    }
    Gui, BoundingBox%winTitle%:Destroy
}

Gdip_ImageSearch_wbb(pBitmapHaystack,pNeedle,ByRef OutputList=""
    ,OuterX1=0,OuterY1=0,OuterX2=0,OuterY2=0,Variation=0,Trans=""
    ,SearchDirection=1,Instances=1,LineDelim="`n",CoordDelim=",") {
    global titleHeight
    yBias := titleHeight - 45
    vret := Gdip_ImageSearch(pBitmapHaystack,pNeedle.needle,OutputList,OuterX1,OuterY1+yBias,OuterX2,OuterY2+yBias,Variation,Trans,SearchDirection,Instances,LineDelim,CoordDelim)
    if(dbg_bbox)
        bboxAndPause_immage(OuterX1, OuterY1+yBias, OuterX2, OuterY2+yBias, pNeedle, vret, dbg_bboxNpause)
    return vret
}

GetNeedle(Path) {
    static NeedleBitmaps := Object()

    if (NeedleBitmaps.HasKey(Path)) {
        return NeedleBitmaps[Path]
    } else {
        pNeedle := Gdip_CreateBitmapFromFile(Path)
        needleObj := Object()
        needleObj.Path := Path
        pathsplit := StrSplit(Path , "\")
        needleObj.Name := pathsplit[pathsplit.MaxIndex()]
        needleObj.needle := pNeedle
        NeedleBitmaps[Path] := needleObj
        return needleObj
    }

    if (NeedleBitmaps.HasKey(Path)) {
        return NeedleBitmaps[Path]
    } else {
        pNeedle := Gdip_CreateBitmapFromFile(Path)
        NeedleBitmaps[Path] := pNeedle
        return pNeedle
    }
}

DoTutorial() {
    FindImageAndClick(105, 396, 121, 406, , "Country", 143, 370) ;select month and year and click

    Delay(3)
    adbClick_wbb(80, 400)
    Delay(3)
    adbClick_wbb(80, 375)
    Delay(3)
    failSafe := A_TickCount
    failSafeTime := 0

    Loop {
        Delay(3)
        if(FindImageAndClick(100, 386, 138, 416, , "Month", , , , 1, failSafeTime))
            break
        Delay(3)
        adbClick_wbb(142, 159)
        Delay(3)
        adbClick_wbb(80, 400)
        Delay(3)
        adbClick_wbb(80, 375)
        Delay(3)
        adbClick_wbb(82, 422)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Month`n(" . failSafeTime . "/45 seconds)")
    } ;select month and year and click

    adbClick_wbb(200, 400)
    Delay(3)
    adbClick_wbb(200, 375)
    Delay(3)
    failSafe := A_TickCount
    failSafeTime := 0
    Loop { ;select month and year and click
        Delay(3)
        if(FindImageAndClick(148, 384, 256, 419, , "Year", , , , 1, failSafeTime))
            break
        Delay(3)
        adbClick_wbb(142, 159)
        Delay(3)
        adbClick_wbb(142, 159)
        Delay(3)
        adbClick_wbb(200, 400)
        Delay(3)
        adbClick_wbb(200, 375)
        Delay(3)
        adbClick_wbb(142, 159)
        Delay(3)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Year`n(" . failSafeTime . "/45 seconds)")
    } ;select month and year and click

    Delay(3)
    if(FindOrLoseImage(93, 471, 122, 485, , "CountrySelect", 0)) {
        FindImageAndClick(110, 134, 164, 160, , "CountrySelect2", 141, 237, 500)
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            countryOK := FindOrLoseImage(93, 450, 122, 470, , "CountrySelect", 0, failSafeTime)
            birthFound := FindOrLoseImage(116, 352, 138, 389, , "Birth", 0, failSafeTime)
            if(countryOK)
                adbClick_wbb(124, 250)
            else if(!birthFound)
                adbClick_wbb(140, 474)
            else if(birthFound)
                break
            Delay(3)
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for country select for " . failSafeTime . "/45 seconds")
        }
    } else {
        FindImageAndClick(116, 352, 138, 389, , "Birth", 140, 474, 1000)
    }

    ;wait date confirmation screen while clicking ok

    FindImageAndClick(210, 285, 250, 315, , "TosScreen", 203, 371, 1000) ;wait to be at the tos screen while confirming birth

    FindImageAndClick(129, 477, 156, 494, , "Tos", 139, 299, 1000) ;wait for tos while clicking it

    FindImageAndClick(210, 285, 250, 315, , "TosScreen", 142, 486, 1000) ;wait to be at the tos screen and click x

    FindImageAndClick(129, 477, 156, 494, , "Privacy", 142, 339, 1000) ;wait to be at the tos screen

    FindImageAndClick(210, 285, 250, 315, , "TosScreen", 142, 486, 1000) ;wait to be at the tos screen, click X

    Delay(3)
    adbClick_wbb(261, 374)

    Delay(3)
    adbClick_wbb(261, 406)

    Delay(3)
    adbClick_wbb(145, 484)

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        if(FindImageAndClick(30, 336, 53, 370, , "Save", 145, 484, , 2, failSafeTime)) ;wait to be at create save data screen while clicking
            break
        Delay(1)
        adbClick_wbb(261, 406)
        if(FindImageAndClick(30, 336, 53, 370, , "Save", 145, 484, , 2, failSafeTime)) ;wait to be at create save data screen while clicking
            break
        Delay(1)
        adbClick_wbb(261, 374)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Save`n(" . failSafeTime . "/45 seconds)")
    }

    Delay(1)

    adbClick_wbb(143, 348)

    Delay(1)

    FindImageAndClick(51, 335, 107, 359, , "Link") ;wait for link account screen%
    Delay(1)
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        if(FindOrLoseImage(51, 335, 107, 359, , "Link", 0, failSafeTime)){
            adbClick_wbb(140, 460)
            Loop {
                Delay(1)
                if(FindOrLoseImage(51, 335, 107, 359, , "Link", 1, failSafeTime)){
                    adbClick_wbb(140, 380) ; click ok on the interrupted while opening pack prompt
                    break
                }
                failSafeTime := (A_TickCount - failSafe) // 1000
            }
        } else if(FindOrLoseImage(110, 350, 150, 404, , "Confirm", 0, failSafeTime)){
            adbClick_wbb(203, 364)
        } else if(FindOrLoseImage(215, 371, 264, 418, , "Complete", 0, failSafeTime)){
            adbClick_wbb(140, 370)
        } else if(FindOrLoseImage(0, 46, 20, 70, , "Cinematic", 0, failSafeTime)){
            break
        }
        Delay(1)
        failSafeTime := (A_TickCount - failSafe) // 1000
    }

    if(setSpeed = 3){
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(18, 177, 23, 181, , "One2", 26, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }

    FindImageAndClick(110, 230, 182, 257, , "Welcome", 253, 506, 110) ;click through cutscene until welcome page

    if(setSpeed = 3){
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    FindImageAndClick(190, 241, 225, 270, , "Name", 189, 438) ;wait for name input screen
    /* ; Picks Erika at creation - disabled
    Delay(1)
    if(FindOrLoseImage(147, 160, 157, 169, , "Erika", 1)) {
        adbClick_wbb(143, 207)
        Delay(1)
        adbClick_wbb(143, 207)
        FindImageAndClick(165, 294, 173, 301, , "ChooseErika", 143, 306)
        FindImageAndClick(190, 241, 225, 270, , "Name", 143, 462) ;wait for name input screen
    }
    */
    FindImageAndClick(0, 476, 40, 502, , "OK", 139, 257) ;wait for name input screen

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        ; Check for AccountName in Settings.ini
        IniRead, accountNameValue, %A_ScriptDir%\..\Settings.ini, UserSettings, AccountName, ERROR

        ; Use AccountName if it exists and isn't empty
        if (accountNameValue != "ERROR" && accountNameValue != "") {
            Random, randomNum, 1, 500 ; Generate random number from 1 to 500
            username := accountNameValue . "-" . randomNum
            username := SubStr(username, 1, 14)  ; max character limit
            if(verboseLogging)
                LogToFile("Using AccountName: " . username)
        } else {
            fileName := A_ScriptDir . "\..\usernames.txt"
            if(FileExist(fileName))
                name := ReadFile("usernames")
            else
                name := ReadFile("usernames_default")

            Random, randomIndex, 1, name.MaxIndex()
            username := name[randomIndex]
            username := SubStr(username, 1, 14)  ; max character limit
            if(verboseLogging)
                LogToFile("Using random username: " . username)
        }

        adbInput(username)
        Delay(1)
        if(FindImageAndClick(121, 490, 161, 520, , "Return", 185, 372, , 10))
            break
        adbClick_wbb(90, 370)
        Delay(1)
        adbClick_wbb(139, 254) ; 139 254 194 372
        Delay(1)
        adbClick_wbb(139, 254)
        Delay(1)
        EraseInput() ; incase the random pokemon is not accepted
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("In failsafe for Trace. " . failSafeTime . "/45 seconds")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at name")
    }

    Delay(1)

    adbClick_wbb(140, 424)

    FindImageAndClick(225, 273, 235, 290, , "Pack", 140, 424) ;wait for pack to be ready  to trace
    if(setSpeed > 1) {
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(18, 177, 23, 181, , "One2", 26, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if(FindOrLoseImage(225, 273, 235, 290, , "Pack", 1, failSafeTime)){
            if(setSpeed > 1) {
                if(setSpeed = 3) {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) ; click 3x
                } else {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) ; click 2x
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
    }

    FindImageAndClick(34, 99, 74, 131, , "Swipe", 140, 375) ;click through cards until needing to swipe up
    if(setSpeed > 1) {
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(18, 177, 23, 181, , "One2", 26, 180) 
        Delay(1)
    }
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbSwipe_wbb("266 770 266 355 60")
        Sleep, 100
        if(FindOrLoseImage(120, 70, 150, 95, , "SwipeUp", 0, failSafeTime)){
            if(setSpeed > 1) {
                if(setSpeed = 3)
                    FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
                else
                    FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for swipe up for " . failSafeTime . "/45 seconds")
        Delay(1)
    }

    Delay(1)
    if(setSpeed > 2) {
        FindImageAndClick(136, 420, 151, 436, , "Move", 134, 375, 500) ; click through until move
        FindImageAndClick(50, 394, 86, 412, , "Proceed", 141, 483, 750) ;wait for menu to proceed then click ok. increased delay in between clicks to fix freezing on 3x speed
    } else {
        FindImageAndClick(136, 420, 151, 436, , "Move", 134, 375) ; click through until move
        FindImageAndClick(50, 394, 86, 412, , "Proceed", 141, 483) ;wait for menu to proceed then click ok
    }

    Delay(1)
    adbClick_wbb(204, 371)

    FindImageAndClick(46, 368, 103, 411, , "Gray") ;wait for for missions to be clickable

    Delay(1)
    adbClick_wbb(247, 472)

    FindImageAndClick(115, 97, 174, 150, , "Pokeball", 247, 472, 5000) ; click through missions until missions is open

    Delay(1)
    adbClick_wbb(141, 294)
    Delay(1)
    adbClick_wbb(141, 294)
    Delay(1)
    FindImageAndClick(124, 168, 162, 207, , "Register", 141, 294, 1000) ; wait for register screen
    Delay(6)
    adbClick_wbb(140, 500)

    FindImageAndClick(115, 255, 176, 308, , "Mission") ; wait for mission complete screen

    FindImageAndClick(46, 368, 103, 411, , "Gray", 143, 360) ;wait for for missions to be clickable

    FindImageAndClick(170, 160, 220, 200, , "Notifications", 145, 194) ;click on packs. stop at booster pack tutorial

    Delay(3)
    adbClick_wbb(142, 436)
    Delay(3)
    adbClick_wbb(142, 436)
    Delay(3)
    adbClick_wbb(142, 436)
    Delay(3)
    adbClick_wbb(142, 436)

    FindImageAndClick(225, 273, 235, 290, , "Pack", 239, 497) ;wait for pack to be ready  to Trace
    if(setSpeed > 1) {
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(18, 177, 23, 181, , "One2", 26, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if(FindOrLoseImage(225, 273, 235, 290, , "Pack", 1, failSafeTime)){
            if(setSpeed > 1) {
                if(setSpeed = 3) {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
                } else {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
    }

    FindImageAndClick(170, 98, 270, 125, 5, "Opening", 239, 497, 50) ;skip through cards until results opening screen

    FindImageAndClick(233, 486, 272, 519, , "Skip", 146, 496) ;click on next until skip button appears

    FindImageAndClick(120, 70, 150, 100, , "Next", 239, 497, , 2)

    FindImageAndClick(53, 281, 86, 310, , "Wonder", 146, 494) ;click on next until skip button appearsstop at hourglasses tutorial

    Delay(3)

    adbClick_wbb(140, 358)

    FindImageAndClick(191, 393, 211, 411, , "Shop", 146, 444) ;click until at main menu

    ; New needle & search region 11.1.2025 kevinnnn
    FindImageAndClick(75, 156, 83, 167, , "Wonder2", 79, 411)

    FindImageAndClick(114, 430, 155, 441, , "Wonder3", 190, 437) ; click through tutorial

    Delay(2)

    FindImageAndClick(155, 281, 192, 315, , "Wonder4", 202, 347, 500) ; confirm wonder pick selection

    Delay(2)

    adbClick_wbb(208, 461)

    if(setSpeed = 3) ;time the animation
        Sleep, 1500
    else
        Sleep, 2500

    FindImageAndClick(60, 130, 202, 142, 10, "Pick", 208, 461, 350) ;stop at pick a card

    Delay(1)

    adbClick_wbb(187, 345)

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        if(setSpeed = 3)
            continueTime := 1
        else
            continueTime := 3

        if(FindOrLoseImage(233, 486, 272, 519, , "Skip", 0, failSafeTime)) {
            adbClick_wbb(239, 497)
        } else if(FindOrLoseImage(110, 230, 182, 257, , "Welcome", 0, failSafeTime)) { ;click through to end of tut screen
            break
        } else if(FindOrLoseImage(120, 70, 150, 100, , "Next", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage(120, 70, 150, 100, , "Next2", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else {
            adbClick_wbb(187, 345)
            Delay(1)
            adbClick_wbb(143, 492)
            Delay(1)
            adbClick_wbb(143, 492)
            Delay(1)
        }
        Delay(1)

        ; adbClick_wbb(66, 446)
        ; Delay(1)
        ; adbClick_wbb(66, 446)
        ; Delay(1)
        ; adbClick_wbb(66, 446)
        ; Delay(1)
        ; adbClick_wbb(187, 345)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for End`n(" . failSafeTime . "/45 seconds)")
    }

    FindImageAndClick(120, 316, 143, 335, , "Main", 192, 449) ;click until at main menu

    return true
}

SelectPack(HG := false) {
    global openPack, packArray

    ; define constants
    MiddlePackX := 140
    RightPackX := 215
    LeftPackX := 50 ;60
    HomeScreenAllPackY := 203

    PackScreenAllPackY := 320

    SelectExpansionFirstRowY := 300
    SelectExpansionSecondRowY := 432

    SelectExpansionRightColumnMiddleX := 203
    SelectExpansionLeftColumnMiddleX := 73
    3PackExpansionLeft := -40
    3PackExpansionRight := 40
    2PackExpansionLeft := -20
    2PackExpansionRight := 15 ; avoiding clicking UI elements behind

    inselectexpansionscreen := 0

    packy := HomeScreenAllPackY
    if (openPack == "Deluxe") {
        packx := LeftPackX
    } else if (openPack == "MegaBlaziken") {
        packx := RightPackX
    } else { ; do not set this to a specific if openPack == "something" as all packs need to reference MiddlePackX as pack position.
        packx := MiddlePackX
    }

    if(openPack == "CrimsonBlaze" || openPack == "MegaBlaziken" || openPack == "Deluxe") {
        PackIsInHomeScreen := 1
    } else {
        PackIsInHomeScreen := 0
    }

    if(openPack == "CrimsonBlaze") {
        PackIsLatest := 1
    } else {
        PackIsLatest := 0
    }

    if (openPack == "CrimsonBlaze" || openPack == "MegaGyarados" || openPack == "MegaBlaziken" || openPack == "MegaAltaria") {
        packInTopRowsOfSelectExpansion := 1
    } else {
        packInTopRowsOfSelectExpansion := 0
    }

    if(HG = "First" && injectMethod && loadedAccount ){
        ; when First and injection, if there are free packs, we don't land/start in home screen,
        ; and we have also to search for closed during pack, hourglass, etc.

        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            adbClick_wbb(packx, HomeScreenAllPackY) ; click until points appear (if free packs, will land in pack scree, if no free packs, this will select the middle pack and go to same screen as if there were free packs)
            Delay(1)
            if(FindOrLoseImage(233, 400, 264, 428, , "Points", 0, failSafeTime)) {
                break
            }
            else if(!renew && !getFC) {
                if(FindOrLoseImage(241, 377, 269, 407, , "closeduringpack", 0)) {
                    adbClick_wbb(139, 371)
                }
            }
            else if(FindOrLoseImage(175, 165, 255, 235, , "Hourglass3", 0)) {
                ;TODO hourglass tutorial still broken after injection
                Delay(3)
                adbClick_wbb(146, 441)
                Delay(3)
                adbClick_wbb(146, 441)
                Delay(3)
                adbClick_wbb(146, 441)
                Delay(3)

                FindImageAndClick(98, 184, 151, 224, , "Hourglass1", 168, 438, 500, 5) ;stop at hourglasses tutorial 2
                Delay(1)

                adbClick_wbb(203, 436)
                FindImageAndClick(236, 198, 266, 226, , "Hourglass2", 180, 436, 500) ;stop at hourglasses tutorial 2 180 to 203?
            }

            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for Points`n(" . failSafeTime . "/90 seconds)")
        }

        if(!friendIDs && friendID = "") {
            ; if we don't need to add any friends we can select directly the latest packs, or go directly to select other booster screen,

            if(PackIsLatest) {   ; if selected pack is the latest pack select directly from the pack select screen
                packy := PackScreenAllPackY ; Y coordinate is lower when in pack select screen then in home screen

                if(packx != MiddlePackX) { ; if it is already the middle Pack, no need to click again
                    Delay(5)
                    adbClick_wbb(packx, packy)
                    Delay(5)
                }
            } else {
                FindImageAndClick(115, 140, 160, 155, , "SelectExpansion", 248, 459, 1000) ; if selected pack is not the latest pack click directly select other boosters

                if(PackIsInHomeScreen) {
                    ; the only one that is not handled below because should show in home page
                    inselectexpansionscreen := 1
                }
            }
        }
    } else {
        ; if not first or not injected, or friends were added, always start from home page
        FindImageAndClick(233, 400, 264, 428, , "Points", packx, packy, 1000)  ; open selected pack from home page
    }

    ; if not the ones showing in home screen, click select other booster packs
    if (!PackIsInHomeScreen && !inselectexpansionscreen) {
        FindImageAndClick(115, 140, 160, 155, , "SelectExpansion", 248, 459, 1000)
        inselectexpansionscreen := 1
    }

    if(inselectexpansionscreen) {
        ; packs that can be opened after clicking A series
        if (openPack = "Springs" || openPack == "Deluxe" || openPack = "HoOh" || openPack = "Lugia" || openPack = "Eevee") {
            Delay(4)

            if (openPack == "Springs") {
                packx := SelectExpansionRightColumnMiddleX
                packy := 298
            } else if (openPack == "Deluxe") {
                packx := SelectExpansionLeftColumnMiddleX
                packy := 298
            } else if (openPack == "HoOh") {
                packx := SelectExpansionLeftColumnMiddleX + 2PackExpansionLeft
                packy := 434
            } else if (openPack == "Lugia") {
                packx := SelectExpansionLeftColumnMiddleX + 2PackExpansionRight
                packy := 434
            } else if (openPack == "Eevee") {
                packx := SelectExpansionRightColumnMiddleX
                packy := 434
            }
        }

        ; packs that can be opened after swiping once
        if (openPack = "Buzzwole" || openPack = "Solgaleo" || openPack = "Lunala") {
            Delay(3)

            X := 266
            Y1 := 430
            Y2 := 50

            Loop, 1 {
                adbSwipe(X . " " . Y1 . " " . X . " " . Y2 . " " . swipeSpeed)
                Sleep, 600 ;
            }

            if (openPack = "Buzzwole") {
                packx := SelectExpansionLeftColumnMiddleX
                packy := 444
            } else if (openPack = "Solgaleo") {
                packx := SelectExpansionRightColumnMiddleX
                packy := 444
            } else if (openPack = "Lunala") {
                packx := SelectExpansionRightColumnMiddleX
                packy := 444
            }
        }

        ; packs that can be opened after fully swiping down
        if (openPack = "Dialga" || openPack = "Palkia" || openPack = "Mew" || openPack = "Charizard" || openPack = "Mewtwo" || openPack = "Pikachu" || openPack = "Shining" || openPack = "Arceus") {
            Delay(3)
            
            X := 266
            Y1 := 430
            Y2 := 50

            Loop, 8 {
                adbSwipe(X . " " . Y1 . " " . X . " " . Y2 . " " . swipeSpeed)
                Sleep, 100 ;
            }

            if (openPack = "Shining") {
                packx := SelectExpansionLeftColumnMiddleX
                packy := 114
            } else if (openPack = "Arceus") {
                packx := SelectExpansionRightColumnMiddleX
                packy := 114
            } else if (openPack = "Dialga") {
                packx := SelectExpansionLeftColumnMiddleX + 2PackExpansionLeft
                packy := 209
            } else if (openPack = "Palkia") {
                packx := 80
                packy := 209 ; custom height and X to avoid clicking pack accidentally on next screen
            } else if (openPack = "Mew") {
                packx := SelectExpansionRightColumnMiddleX
                packy := 238
            } else if (openPack = "Charizard") {
                packx := SelectExpansionLeftColumnMiddleX + 3PackExpansionLeft
                packy := 420 ; packy must be low enough to not accidentally click the pack
                ; wheel rotation on the next screen while waiting for 'points'
            } else if (openPack = "Mewtwo") {
                packx := SelectExpansionLeftColumnMiddleX
                packy := 420 ; changed from 394 to avoid charizard pack per Crinity
            } else if (openPack = "Pikachu") {
                packx := SelectExpansionLeftColumnMiddleX + 3PackExpansionRight
                packy := 420
            }
        }

        if (openPack == "CrimsonBlaze" || openPack == "MegaGyarados" || openPack == "MegaBlaziken" || openPack == "MegaAltaria") { ; No swipe, inital screen
            Delay(4)
            adbClick(52, 455) ; click B series. need more robust system later
            Delay(4)
            if (openPack == "CrimsonBlaze") {
                packy := SelectExpansionFirstRowY
                packx := SelectExpansionLeftColumnMiddleX
            } else if (openPack == "MegaGyarados") {
                packy := SelectExpansionFirstRowY
                packx := SelectExpansionRightColumnMiddleX + 3PackExpansionLeft
                ; packx := 18 ; custom location to avoid accidentally rotating through pack wheel on following screen
            } else if (openPack == "MegaBlaziken") {
                packy := SelectExpansionFirstRowY
                packx := SelectExpansionRightColumnMiddleX
            } else if (openPack == "MegaAltaria") {
                packy := SelectExpansionFirstRowY
                packx := SelectExpansionRightColumnMiddleX + 3PackExpansionRight
                packx := 258 ; custom locations to avoid accidentally rotating through pack wheel on following screen
                packy := 309 ; custom locations to avoid accidentally rotating through pack wheel on following screen
            }
        }

        FindImageAndClick(233, 400, 264, 428, , "Points", packx, packy)

        if(openPack = "Lunala") {
            ; Crinity created this method to click on some other pack in the same expansion
            ; and make sure we're clicked over to the correct pack within the set.
            failSafe := A_TickCount
            failSafeTime := 0
            Loop{
                Delay(1)
                if(FindOrLoseImage(233, 400, 264, 428, , "Points", 0, failSafeTime)) {
                    break
                }
                failSafeTime := (A_TickCount - failsafe) // 1000
            }
            failSafe := A_TickCount
            failSafeTime := 0
            Loop{
                adbClick_wbb(210, 320)
                Delay(1)
                if(FindOrLoseImage(58, 303, 74, 319, , "PackIsMissing", 1, failSafeTime)){
                    ; if white square DOES NOT appear here, then break.
                    break
                }
                failSafeTime := (A_TickCount - failsafe) // 1000
            }
        }

    }

    if(HG = "First" && injectMethod && loadedAccount && !accountHasPackInfo) {
        FindPackStats()
    }

    if(HG = "Tutorial") {
        FindImageAndClick(236, 198, 266, 226, , "Hourglass2", 180, 436, 500) ;stop at hourglasses tutorial 2 180 to 203?
    }
    else if(HG = "HGPack") {
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            ; Execute failsafe click only once after 10 seconds to try to click floating glitched pack
            failSafeTime := (A_TickCount - failSafe) // 1000
            if (failSafeTime >= 10 && !failsafeClickExecuted) {
                if (FindorLoseImage(233, 400, 264, 428, , "Points", 0)) {
                    CreateStatusMessage("Trying to click floating pack...")
                    Sleep, 3000
                    adbClick_wbb(151, 250) ; if pack is floating/glitched
                    failsafeClickExecuted := true
                }
            }
            if(FindOrLoseImage(60, 440, 90, 480, , "HourglassPack", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage(49, 449, 70, 474, , "HourGlassAndPokeGoldPack", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage(60, 440, 90, 480, , "PokeGoldPack", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage(92, 299, 115, 317, , "notenoughitems", 0)) {
                cantOpenMorePacks := 1
            }
            if(cantOpenMorePacks)
                return
            adbClick_wbb(161, 423)
            Delay(1)
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for HourglassPack3`n(" . failSafeTime . "/45 seconds)")
        }
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage(60, 440, 90, 480, , "HourglassPack", 1, failSafeTime)) {
                break
            }
            adbClick_wbb(205, 458)
            Delay(1)
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for HourglassPack4`n(" . failSafeTime . "/45 seconds)")

            ; Execute failsafe click only once after 10 seconds to try to click floating glitched pack
            if (failSafeTime >= 10 && !failsafeClickExecuted) {
                if (FindorLoseImage(233, 400, 264, 428, , "Points", 0)) {
                    CreateStatusMessage("Trying to click floating pack...")
                    Sleep, 3000
                    adbClick_wbb(151, 250) ; if pack is floating/glitched
                    failsafeClickExecuted := true
                }
            }
        }
    } else {
        failSafe := A_TickCount
        failSafeTime := 0
        failsafeClickExecuted := false  ; Flag to track if failsafe click has been executed
        Loop {
            adbClick_wbb(151, 420)  ; open button

            if(FindOrLoseImage(233, 486, 272, 519, , "Skip2", 0, failSafeTime)) {
                break
            } else if(FindOrLoseImage(92, 299, 115, 317, , "notenoughitems", 0)) {
                cantOpenMorePacks := 1
            } else if(FindOrLoseImage(60, 440, 90, 480, , "HourglassPack", 0, 1) || FindOrLoseImage(49, 449, 70, 474, , "HourGlassAndPokeGoldPack", 0, 1)) {
                adbClick_wbb(205, 458)  ; Handle unexpected HG pack confirmation
            } else if(FindOrLoseImage(241, 377, 269, 407, , "closeduringpack", 0)) {
                ; Handle restart caused due to network error
                adbClick_wbb(139, 371)
                if (injectMethod && loadedAccount && friended) {
                    IniWrite, 1, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
                }
                restartGameInstance("Stuck at pack opening")
                return
            } else {
                adbClick_wbb(200, 451)  ; Additional fallback click
                Delay(1)

                ; Execute failsafe click only once after 10 seconds
                failSafeTime := (A_TickCount - failSafe) // 1000
                if (failSafeTime >= 10 && !failsafeClickExecuted) {
                    if (FindorLoseImage(233, 400, 264, 428, , "Points", 0)) {
                        CreateStatusMessage("Trying to click floating pack...")
                        Sleep, 3000
                        adbClick_wbb(151, 250) ; if pack is floating/glitched
                        failsafeClickExecuted := true
                    }
                }
            }

            if(cantOpenMorePacks)
                return

            Delay(1)
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for Skip2`n(" . failSafeTime . "/45 seconds)")
        }
    }
}

PackOpening() {
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick_wbb(146, 439)
        Delay(1)
        if(FindOrLoseImage(225, 273, 235, 290, , "Pack", 0, failSafeTime)) {
            break ;wait for pack to be ready to Trace and click skip
        } else if(FindOrLoseImage(92, 299, 115, 317, , "notenoughitems", 0)) {
            cantOpenMorePacks := 1
        } else if(FindOrLoseImage(60, 440, 90, 480, , "HourglassPack", 0, 1) || FindOrLoseImage(49, 449, 70, 474, , "HourGlassAndPokeGoldPack", 0, 1)) {
            adbClick_wbb(205, 458) ; handle unexpected no packs available
        } else {
            adbClick_wbb(239, 497)
        }

        ; Execute failsafe click only once after 10 seconds to try to select Floating Pack
        failSafeTime := (A_TickCount - failSafe) // 1000
        if (failSafeTime >= 10 && !failsafeClickExecuted) {
            if (FindorLoseImage(233, 400, 264, 428, , "Points", 0)) {
                CreateStatusMessage("Trying to click floating pack...")
                Sleep, 3000
                adbClick_wbb(151, 250) ; if pack is floating/glitched
                failsafeClickExecuted := true
            }
        }

        if(cantOpenMorePacks)
            return

        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45){
            RemoveFriends()
            IniWrite, 1, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
            restartGameInstance("Stuck at Pack")
        }
    }

    if(setSpeed > 1) {
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(18, 177, 23, 181, , "One2", 26, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if (FindOrLoseImage(225, 273, 235, 290, , "Pack", 1, failSafeTime)){
            if(setSpeed > 1) {
                if(setSpeed = 3) {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
                } else {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Trace`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
    }

    FindImageAndClick(170, 98, 270, 125, 5, "Opening", 239, 497, 100) ;skip through cards until results opening screen
    Delay(4) ; trying to avoid loading icons 2025.12.23 kevinnnn
    CheckPack()

    if(!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum)
        return

    ;FindImageAndClick(233, 486, 272, 519, , "Skip", 146, 494) ;click on next until skip button appears

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        Delay(1)
        if(FindOrLoseImage(233, 486, 272, 519, , "Skip", 0, failSafeTime)) {
            adbClick_wbb(239, 497)
        } else if(FindOrLoseImage(120, 70, 150, 100, , "Next", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage(120, 70, 150, 100, , "Next2", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage(121, 465, 140, 485, , "ConfirmPack", 0, failSafeTime)) {
            break
        } else if(FindOrLoseImage(178, 193, 251, 282, , "Hourglass", 0, failSafeTime)) {
            break
        } else {
            adbClick_wbb(146, 494) ;146, 494
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Home`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at Home")
    }
}

HourglassOpening(HG := false, NEIRestart := true) {
    if(!HG) {
        Delay(3)
        adbClick_wbb(146, 441) ; 146 440
        Delay(3)
        adbClick_wbb(146, 441)
        Delay(3)
        adbClick_wbb(146, 441)
        Delay(3)

        FindImageAndClick(98, 184, 151, 224, , "Hourglass1", 168, 438, 500, 5) ;stop at hourglasses tutorial 2
        Delay(1)

        adbClick_wbb(203, 436) ; 203 436

        if(packMethod) {
            AddFriends(true)
            SelectPack("Tutorial")
        }
        else {
            FindImageAndClick(236, 198, 266, 226, , "Hourglass2", 180, 436, 500) ;stop at hourglasses tutorial 2 180 to 203?

            if(cantOpenMorePacks)
                return
        }
    }
    if(!packMethod) {
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage(60, 440, 90, 480, , "HourglassPack", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage(40, 440, 70, 474, , "HourGlassAndPokeGoldPack", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage(60, 440, 90, 480, , "PokeGoldPack", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage(92, 299, 115, 317, , "notenoughitems", 0)) {
                cantOpenMorePacks := 1
            }
            if(cantOpenMorePacks)
                return

            ; Execute failsafe click only once after 10 seconds to try to click floating pack
            failSafeTime := (A_TickCount - failSafe) // 1000
            if (failSafeTime >= 10 && !failsafeClickExecuted) {
                if (FindorLoseImage(233, 400, 264, 428, , "Points", 0)) {
                    CreateStatusMessage("Trying to click floating pack...")
                    Sleep, 3000
                    adbClick_wbb(151, 250) ; if pack is floating/glitched
                    failsafeClickExecuted := true
                }
            }

            if(failSafeTime >= 45) {
                restartGameInstance("Stuck waiting for HourglassPack")
                return
            }
            adbClick_wbb(146, 439)
            Delay(1)
            CreateStatusMessage("Waiting for HourglassPack`n(" . failSafeTime . "/45 seconds)")
        }
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage(60, 440, 90, 480, , "HourglassPack", 1, failSafeTime)) {
                break
            }
            adbClick_wbb(205, 458)
            Delay(1)
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for HourglassPack2`n(" . failSafeTime . "/45 seconds)")
        }
    }
    Loop {
        adbClick_wbb(146, 439)
        Delay(1)
        if(FindOrLoseImage(225, 273, 235, 290, , "Pack", 0, failSafeTime))
            break ;wait for pack to be ready to Trace and click skip
        else
            adbClick_wbb(239, 497)

        if(cantOpenMorePacks)
            return

        if(FindOrLoseImage(191, 393, 211, 411, , "Shop", 0, failSafeTime)){
            SelectPack("HGPack")
        }

        clickButton := FindOrLoseImage(145, 440, 258, 480, 80, "Button", 0, failSafeTime)
        if(clickButton) {
            StringSplit, pos, clickButton, `,  ; Split at ", "
            if (scaleParam = 287) {
                pos2 += 5
            }
            adbClick_wbb(pos1, pos2)
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45) {
            if(injectMethod && loadedAccount && friended) {
                IniWrite, 1, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
            }
            restartGameInstance("Stuck at Pack")
        }
    }

    if(setSpeed > 1) {
        FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000) 
        FindImageAndClick(18, 177, 23, 181, , "One2", 26, 180) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if (FindOrLoseImage(225, 273, 235, 290, , "Pack", 1, failSafeTime)){
            if(setSpeed > 1) {
                if(setSpeed = 3) {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(185, 177, 189, 182, , "Three2", 187, 180) 
                } else {
                    FindImageAndClick(158, 252, 177, 259, , "speedmodMenu2", 18, 109, 2000)
                    FindImageAndClick(103, 177, 106, 181, , "Two2", 107, 180) 
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Trace`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
    }

    FindImageAndClick(170, 98, 270, 125, 5, "Opening", 239, 497, 50) ;skip through cards until results opening screen

    CheckPack()

    if(!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum)
        return

    ;FindImageAndClick(233, 486, 272, 519, , "Skip", 146, 494) ;click on next until skip button appears

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        Delay(1)
        if(FindOrLoseImage(233, 486, 272, 519, , "Skip", 0, failSafeTime)) {
            adbClick_wbb(239, 497)
        } else if(FindOrLoseImage(120, 70, 150, 100, , "Next", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage(120, 70, 150, 100, , "Next2", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage(121, 465, 140, 485, , "ConfirmPack", 0, failSafeTime)) {
            break
        } else {
            adbClick_wbb(146, 494) ;146, 494
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for ConfirmPack`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at ConfirmPack")
    }
}

DoWonderPickOnly() {

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick_wbb(80, 390) ; first wonderpick slot
        adbClick_wbb(80, 460) ; backup, second wonderpick slot
        if(FindOrLoseImage(37, 424, 57, 446, , "noWPenergy", 0, failSafeTime)) {
            Sleep, 2000
            CreateStatusMessage("No WonderPick Energy left!",,,, false)
            Sleep, 2000
            adbClick_wbb(137, 505)
            Sleep, 2000
            adbClick_wbb(35, 515)
            Sleep, 4000
            return
        }
        if(FindOrLoseImage(240, 80, 265, 100, , "WonderPick", 1, failSafeTime)) {
            clickButton := FindOrLoseImage(100, 367, 190, 480, 100, "Button", 0, failSafeTime)
            if(clickButton) {
                StringSplit, pos, clickButton, `,  ; Split at ", "
                ; Adjust pos2 if scaleParam is 287 for 100%
                if (scaleParam = 287) {
                    pos2 += 5
                }
                adbClick_wbb(pos1, pos2)
                Delay(3)
            }
            if(FindOrLoseImage(160, 330, 200, 370, , "Card", 0, failSafeTime))
                break
        }
        Delay(1)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for WonderPick`n(" . failSafeTime . "/45 seconds)")
    }
    Sleep, 300
    if(slowMotion)
        Sleep, 3000
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick_wbb(183, 350) ; click card
        if(FindOrLoseImage(160, 330, 200, 370, , "Card", 1, failSafeTime)) {
            break
        }
        Delay(1)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Card`n(" . failSafeTime . "/45 seconds)")
    }
    failSafe := A_TickCount
    failSafeTime := 0
    ;TODO thanks and wonder pick 5 times for missions
    Loop {
        adbClick_wbb(146, 494)
        Delay(1)
        if(FindOrLoseImage(233, 486, 272, 519, , "Skip", 0, failSafeTime) || FindOrLoseImage(240, 80, 265, 100, , "WonderPick", 0, failSafeTime))
            break
        if(FindOrLoseImage(160, 330, 200, 370, , "Card", 0, failSafeTime)) {
            adbClick_wbb(183, 350) ; click card
        }
        Delay(1)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Shop`n(" . failSafeTime . "/45 seconds)")
    }

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        Delay(1)
        if(FindOrLoseImage(191, 393, 211, 411, , "Shop", 0, failSafeTime))
            break
        else if(FindOrLoseImage(233, 486, 272, 519, , "Skip", 0, failSafeTime))
            adbClick_wbb(239, 497)
        else if(FindOrLoseImage(160, 330, 200, 370, , "Card", 0, failSafeTime)) {
            adbClick_wbb(183, 350) ; click card
        }
        else
            adbInputEvent("111") ;send ESC
        Delay(4)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Shop`n(" . failSafeTime . "/45 seconds)")
    }
}

DoWonderPick() {
    FindImageAndClick(191, 393, 211, 411, , "Shop", 40, 515) ;click until at main menu
    FindImageAndClick(240, 80, 265, 100, , "WonderPick", 59, 429) ;click until in wonderpick Screen

    DoWonderPickOnly()

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick(261, 478)
        Sleep, 1000
        if FindOrLoseImage(15, 456, 18, 473, , "Missions", 0, failSafeTime)
            break
        else if FindOrLoseImage(18, 215, 30, 227, , "DexMissions", 0, failSafeTime)
            break
        else if FindOrLoseImage(204, 195, 223, 202, , "DailyMissions", 0, failSafeTime)
            break
        failSafeTime := (A_TickCount - failSafe) // 1000
    }

    ;FindImageAndClick(130, 170, 170, 205, , "WPMission", 150, 286, 1000)
    FindImageAndClick(120, 185, 150, 215, , "FirstMission", 150, 286, 1000)
    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        Delay(1)
        adbClick_wbb(139, 424)
        Delay(1)
        clickButton := FindOrLoseImage(145, 447, 258, 480, 80, "Button", 0, failSafeTime)
        if(clickButton) {
            adbClick_wbb(110, 369)
        }
        else if(FindOrLoseImage(191, 393, 211, 411, , "Shop", 1, failSafeTime))
            ;adbInputEvent("111") ;send ESC
            adbClick_wbb(139, 492)
        else
            break
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for WonderPick`n(" . failSafeTime . "/45 seconds)")
    }
    return true
}

SpendAllHourglass() {
    ; GoToMain()
    ; GetAllRewards(false, true)
    GoToMain()

    SelectPack("HGPack")
    if(cantOpenMorePacks)
        return

    PackOpening()
    if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
        return

    ; Keep opening packs until we can't anymore
    while (!cantOpenMorePacks && (friendIDs || friendID != "" || accountOpenPacks < maxAccountPackNum)) {
        if(packMethod) {
            ; For packMethod=true: remove/re-add friends between each pack
            friendsAdded := AddFriends(true)  ; true parameter removes and re-adds friends
            SelectPack("HGPack")
            if(cantOpenMorePacks)
                break
            PackOpening()  ; Use PackOpening since we just selected the pack
        } else {
            ; For packMethod=false: direct hourglass opening
            HourglassOpening(true)
        }

        if(cantOpenMorePacks || (!friendIDs && friendID = "" && accountOpenPacks >= maxAccountPackNum))
            break
    }
}

; For Special Missions 2025
GetEventRewards(frommain := true){
    swipeSpeed := 300
    adbSwipeX3 := Round(211 / 277 * 535)
    adbSwipeX4 := Round(11 / 277 * 535)
    adbSwipeY2 := Round((453 - 44) / 489 * 960)
    adbSwipeParams2 := adbSwipeX3 . " " . adbSwipeY2 . " " . adbSwipeX4 . " " . adbSwipeY2 . " " . swipeSpeed
    if (frommain){
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            adbClick(261, 478)
            Sleep, 1000
            if FindOrLoseImage(15, 456, 18, 473, , "Missions", 0, failSafeTime)
                break
            if FindOrLoseImage(18, 215, 30, 227, , "DexMissions", 0, failSafeTime)
                break
            if FindOrLoseImage(204, 195, 223, 202, , "DailyMissions", 0, failSafeTime)
                break
            failSafeTime := (A_TickCount - failSafe) // 1000
            if (FindOrLoseImage(158, 104, 170, 117, , "MissionDeck", 0, failSafeTime)) {
                HandleMissionDeckFailsafe()
                return
            }
        }
    }
    Delay(4)

    LevelUp()

    failSafe := A_TickCount
    failSafeTime := 0
    Loop{
        adbSwipe(adbSwipeParams2)
        Sleep, 200
        if (FindOrLoseImage(225, 444, 272, 470, , "Premium", 0, failSafeTime)){
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for PremiumMissions`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
        if (FindOrLoseImage(158, 104, 170, 117, , "MissionDeck", 0, failSafeTime)) {
            HandleMissionDeckFailsafe()
            return
        }
    }

    adbClick(139,465) ;Important - clicks the center-most mission first.
    Delay(2)

    ;====== Generic mission clicks, if only 1 mission is going on ======
    ; pick ONE of these click locations based upon which events are currently going on.
    ; adbClick_wbb(120, 465) ; used to click the middle mission button
    ; adbClick_wbb(25, 465) ;used to click the left-most mission button

    ;====== Special Event CLaim ======
    failSafe := A_TickCount
    failSafeTime := 0
    Loop{
        ;if (FindOrLoseImage(199, 203, 212, 211, , "MissionWater", 0, failSafeTime)){
        ;    break
        ;}
        if (FindOrLoseImage(199, 203, 212, 211, , "MissionOliveGreen", 0, failSafeTime)){
            break
        }
        adbClick_wbb(6, 465) ; used to scroll to other missions further left.
        Delay(4)
        if (failSafeTime > 10){
            adbInput("111")
            Sleep, 1000
            return
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        if (FindOrLoseImage(158, 104, 170, 117, , "MissionDeck", 0, failSafeTime)) {
            HandleMissionDeckFailsafe()
            return
        }
    }

    ; ====== Collect all rewards ======
    failSafe := A_TickCount
    failSafeTime := 0
    Loop{
        adbClick_wbb(172, 427) ;clicks complete all and ok
        Sleep, 1500
        adbClick_wbb(139, 464) ;when too many rewards, ok button goes lower
        Sleep, 1500
        if FindOrLoseImage(244, 406, 273, 449, , "GotAllMissions", 0, 0) {
            break
        }
        if (FindOrLoseImage(243, 202, 256, 212, , "bonusWeek", 0, failSafeTime)){
            break
        }
        if (failSafeTime > 10){
            adbInput("111")
            Sleep, 1000
            return
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        if (FindOrLoseImage(158, 104, 170, 117, , "MissionDeck", 0, failSafeTime)) {
            HandleMissionDeckFailsafe()
            return
        }
    }
    */

    GoToMain()
}

GetAllRewards(tomain := true, dailies := false) {

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick(261, 478)
        Sleep, 1000
        if FindOrLoseImage(15, 456, 18, 473, , "Missions", 0, failSafeTime)
            break
        else if (FindOrLoseImage(18, 215, 30, 227, , "DexMissions", 0, failSafeTime)) {
            Sleep, 500
            adbClick(42, 465) ; move to DailyMissions page
            Sleep, 500
            break
        }
        else if FindOrLoseImage(204, 195, 223, 202, , "DailyMissions", 0, failSafeTime)
            break
        failSafeTime := (A_TickCount - failSafe) // 1000
    }

    Delay(4)
    failSafe := A_TickCount
    failSafeTime := 0
    GotRewards := true
    if(dailies) {
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            adbClick(165, 465)
            Sleep, 500
            if FindOrLoseImage(204, 195, 223, 202, , "DailyMissions", 0, failSafeTime)
                break
            else if (FindOrLoseImage(18, 215, 30, 227, , "DexMissions", 0, failSafeTime)) {
                Sleep, 500
                adbClick(42, 465) ; move to DailyMissions page
                Sleep, 500
                break
            }
            else if (failSafeTime > 10) {
                ; if DailyMissions doesn't show up, like if an account has already completed Dailies
                ; and we are on the wrong tab like 'Deck' missions in the center tab instead.
                GoToMain()
                GotRewards := false
                return
            }
        }

    }
    Loop {
        Delay(2)
        adbClick(174, 427)
        adbClick(174, 427) ; changed 2px right & added 2nd click
        Delay(1) ; new Delay

        if(FindOrLoseImage(244, 406, 273, 449, , "GotAllMissions", 0, 0)) {
            break
        }
        else if (failSafeTime > 20) {
            GotRewards := false
            break
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
    }
    if (tomain) {
        GoToMain()
    }
}

; Failsafe if Missions page lands on 'Deck' mission tutorial.
HandleMissionDeckFailsafe() {
    Sleep, 500
    adbInput("111") ; ESC
    Sleep, 500
    adbInput("111") ; ESC
    Sleep, 500
    adbInput("111") ; ESC
    Sleep, 500
    adbInput("111") ; ESC
    Sleep, 500
    adbClick(146,438)
    Sleep, 1500
    adbInput("111") ; ESC to home screen
    Sleep, 1000
    return true
}

GoToMain(fromSocial := false) {
    failSafe := A_TickCount
    failSafeTime := 0
    if(!fromSocial) {
        Delay(2)
        Loop {
            Delay(6) ;increase this delay if you see "close app" on home page
            if(FindOrLoseImage(191, 393, 211, 411, , "Shop", 0, failSafeTime)) {
                break
            }
            else
                adbInputEvent("111") ;send ESC
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for Shop`n(" . failSafeTime . "/45 seconds)")
        }
    }
    else {
        FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518)
        FindImageAndClick(191, 393, 211, 411, , "Shop", 20, 515, 500) ;click until at main menu
    }
}

;levelUp()
;FindOrLoseImage(118, 167, 167, 203, , "unlocked", 0, failSafeTime)
;FindImageAndClick(118, 167, 167, 203, , "unlocked", 144, 396, sleepTime)
;adbClick_wbb(144, 396)

;FindOrLoseImage(53, 280, 81, 306, , "unlockdisplayboard", 0, failSafeTime)
;FindImageAndClick(53, 280, 81, 306, , "unlockdisplayboard", 137, 362, sleepTime)
;adbClick_wbb(137, 362)
^e::
    pToken := Gdip_Startup()
    Screenshot_dev()
return

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Find Card Count and OCR Helper Functions
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Attempts to extract and validate text from a specified region of a screenshot using OCR.

; Crops an image, scales it up, converts it to grayscale, and enhances contrast to improve OCR accuracy.

; Extracts text from a bitmap using OCR. Converts the bitmap to a format usable by Windows OCR, performs OCR, and optionally removes characters not in the allowed character list.

; Escapes special characters in a string for use in a regular expression.
; ========================================
; DATABASE FUNCTIONS
; ========================================

; =====================

