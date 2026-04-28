#SingleInstance on
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetBatchLines, -1
SetTitleMatchMode, 3
CoordMode, Pixel, Screen
#NoEnv

#Include %A_ScriptDir%\Include\
#Include Config.ahk
#Include Session.ahk
#Include Data.ahk
#Include ExtraConfig.ahk
#Include Utils.ahk
#Include Logging.ahk
#Include ADB.ahk
#Include Gdip_All.ahk
#Include Gdip_Imagesearch.ahk
#Include OCR.ahk
#Include Gdip_Extra.ahk
#Include Database.ahk
#Include CardDetection.ahk
#Include AccountManager.ahk
#Include FriendManager.ahk
;#Include %A_ScriptDir%\Include\Recorder.ahk
#Include Packs.ahk
#Include Error.ahk
#Include Coords.ahk
#Include RarityBorder.ahk
#Include SpecialEvent.ahk
#Include Crinity_UnofficialPatch.ahk

pToken := Gdip_Startup()

; Allocate and hide the console window to reduce flashing
DllCall("AllocConsole")
WinHide % "ahk_id " DllCall("GetConsoleWindow", "ptr")

; Register OnExit handler to clean up ADB shell properly when script exits
; DISABLED - was causing Reload delays due to blocking ADB shell communication
; OnExit("CleanupOnExit")

; Register message handler to receive "stop after run" signal from instance 1
; WM_USER (0x400) + 0x100 = custom message for stop after run
OnMessage(0x500, "OnStopAfterRunMessage")
OnMessage(0x007E, "OnMonitorWake")
OnExit("CleanupBeforeExit")

global session := new Session()
global botConfig := new BotConfig()
botConfig.loadSettingsToConfig("ALL")

parsePackData()
pokemonList := getKeyList(session.get("pokemonPackObj"))
generatePackCoordinates()

parseDictionaryData("en")
parseDictionaryData("de")
parseDictionaryData("jp")
parseDictionaryData("cn")

session.set("s4tPendingTradeables", [])
session.set("deviceAccountXmlMap", {})
session.set("scriptName", StrReplace(A_ScriptName, ".ahk"))
session.set("winTitle", StrReplace(A_ScriptName, ".ahk"))
session.set("scriptIniFile", A_ScriptDir . "\" . session.get("scriptName") . ".ini")
session.set("stopToggle", false)
session.set("friended", false)
session.set("injectMethod", false)
session.set("dateChange", false)
session.set("foundGP", false)
session.set("isReloadAfterAddFriends", false)
session.set("avgtotalSeconds", false)
session.set("hhours", 0)
session.set("mminutes", 0)
session.set("sseconds", 0)
session.set("aminutes", 0)
session.set("aseconds", 0)
session.set("packsInPool", 0)
session.set("packsThisRun", 0)
session.set("cantOpenMorePacks", 0)
session.set("isSkipSelectExpansion", 0)

session.set("specialEventList", {})

session.set("rerolls_local", 0)
session.set("rerollStartTime_local", A_TickCount)

session.set("maxAccountPackNum", 9999)
session.set("missionDoneList", {"beginnerMissionsDone": 0, "soloBattleMissionDone": 0, "intermediateMissionsDone": 0, "specialMissionsDone": 0, "resetSpecialMissionsDone": 0, "accountHasPackInTesting": 0, "receivedGiftDone": 0})
activatedPackList := []
For idx, value in botConfig.packSettings {
    if(value == 1){
        activatedPackList.Push(idx)
    }
}
session.set("packList", activatedPackList)

session.set("dbg_bbox", 0)
session.set("dbg_bboxNpause", 0)

session.set("failSafe", A_TickCount) ; Initialize failSafe timer at script startup

; Survives SafeReload/Reload so "stop at end of run" still applies after restartGameInstance (e.g. failsafe + DeadCheck unfriend path)
IniRead, stopAfterRunPending, % session.get("scriptIniFile"), UserSettings, stopAfterRunPending, 0
if (stopAfterRunPending = 1) {
    session.set("stopToggle", true)
    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, stopAfterRunPending
}

originalDeleteMethod := botConfig.get("deleteMethod")
if (MigrateDeleteMethod(originalDeleteMethod) != originalDeleteMethod) {
    validMethods := "Create Bots (13P)|Inject 13P+|Inject Wonderpick 96P+"
    if (!InStr(validMethods, originalDeleteMethod)) {
        botConfig.set("deleteMethod", "Create Bots (13P)", "General")
        botConfig.saveConfigToSettings("General")
    }
}

session.set("packMethod", botConfig.get("packMethod"))
if(botConfig.get("deleteMethod") != "Inject Wonderpick 96P+")
    session.set("packMethod", 0)

IniRead, DeadCheck, % session.get("scriptIniFile"), UserSettings, DeadCheck, 0
IniRead, rerollsValue, % session.get("scriptIniFile"), Metrics, rerolls, 0
IniRead, rerollStartTimeValue, % session.get("scriptIniFile"), Metrics, rerollStartTime, -1

if(rerollStartTimeValue = -1)
    rerollStartTimeValue := A_TickCount

session.set("changeDate", getChangeDateTime()) ; get server reset time
session.set("rerolls", rerollsValue)
session.set("rerollStartTime", rerollStartTimeValue)
(botConfig.get("s4tEnabled")) ? session.set("maxAccountPackNum", 9999)

if(botConfig.get("heartBeat"))
    IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, % "Instance" . session.get("scriptName")

SetTimer, RefreshAccountLists, 3600000  ; Refresh Account list every hour

DirectlyPositionWindow()
Sleep, 500

setADBBaseInfo()
ConnectAdb()

Sleep, 500
CreateStatusMessage("Disabling background services...")
DisableBackgroundServices()

resetWindows()
MaxRetries := 10
RetryCount := 0
Loop {
    try {
        WinGetPos, x, y, Width, Height, % "ahk_id " . getMuMuHwnd(session.get("winTitle"))
        sleep, 1000
        OwnerWND := getMuMuHwnd(session.get("winTitle"))
        x4 := x + 4
        y4 := y + 529
        buttonWidth := 50

        Gui, New, +Owner%OwnerWND% -AlwaysOnTop +ToolWindow -Caption +LastFound -DPIScale
        Gui, Default
        Gui, Margin, 4, 4  ; Set margin for the GUI
        Gui, Font, s5 cGray Norm Bold, Segoe UI  ; Normal font for input labels
        Gui, Add, Button, % "x" . (buttonWidth * 0) . " y0 w" . buttonWidth . " h25 gReloadScript", Reload  (Shift+F5)
        Gui, Add, Button, % "x" . (buttonWidth * 1) . " y0 w" . buttonWidth . " h25 gPauseScript", Pause (Shift+F6)
        Gui, Add, Button, % "x" . (buttonWidth * 2) . " y0 w" . buttonWidth . " h25 gResumeScript", Resume (Shift+F6)
        Gui, Add, Button, % "x" . (buttonWidth * 3) . " y0 w" . buttonWidth . " h25 gStopScript", Stop (Shift+F7)
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

session.set("setSpeed", 3) ;always 1x/3x

if(InStr(botConfig.get("deleteMethod"), "Inject"))
    session.set("injectMethod", true)

initializeAdbShell()

if(session.get("injectMethod"))
    createAccountList(session.get("scriptName"))

SetTimer, LiveMetricsTimer, 5000

if(session.get("injectMethod") && DeadCheck != 1) {
    session.set("loadedAccount", loadAccount())
} else if(session.get("injectMethod") && DeadCheck = 1) {
    ; DeadCheck = 1: Start the Pokemon app for the stuck account (don't inject new account)
    startPTCGPApp()
}

clearMissionCache()

if(isSevtFileExist())
    loadAllSevtFiles()

if(!session.get("injectMethod") || (!session.get("loadedAccount") && DeadCheck != 1))
    restartGameInstance("Initializing bot...", false)

; Define default swipe params.
adbSwipeX1 := Round(35 / 283 * 540)
adbSwipeX2 := Round(273 / 283 * 540)
adbSwipeY := Round((327 - 40) / 488 * 960)
global adbSwipeParams := adbSwipeX1 . " " . adbSwipeY . " " . adbSwipeX2 . " " . adbSwipeY . " " . botConfig.get("swipeSpeed")

if(DeadCheck = 1 && botConfig.get("deleteMethod") != "Create Bots (13P)") {
    CreateStatusMessage("Account is stuck! Restarting and unfriending...")
    session.set("friended", true)
    CreateStatusMessage("Stuck account still has friends. Unfriending accounts...")
    FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
    if(session.get("setSpeed") = 3)
        FindImageAndClick("Common_SpeedMod3x", 187, 172)
    else
        FindImageAndClick("Common_SpeedMod2x", 106, 173) 
    adbClick_wbb(51, 297)
    Delay(1)
    startPreProcess(botConfig.get("deleteMethod"))
    RemoveFriends()
    if(session.get("injectMethod") && session.get("loadedAccount") && !session.get("keepAccount")) {
        MarkAccountAsUsed()
        session.set("loadedAccount", false)
    }
    DeadCheck := 0
    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    createAccountList(session.get("scriptName"))
    CleanupBeforeExit()
    SafeReload()
} else if(DeadCheck = 1 && botConfig.get("deleteMethod") = "Create Bots (13P)") {
    CreateStatusMessage("New account creation is stuck! Deleting account...")
    Delay(5)
    menuDeleteStart()
    CleanupBeforeExit()
    SafeReload()
} else {
    ; in injection mode, we dont need to reload

    Loop {
        clearMissionCache()
        session.set("isReloadAfterAddFriends", false)
        Randmax := session.get("packList").Length()
        Random, rand, 1, Randmax
        session.set("openPack", session.get("packList")[rand])
        session.set("friended", false)
        IniWrite, 1, %A_ScriptDir%\..\HeartBeat.ini, HeartBeat, % "Instance" . session.get("scriptName")

        session.set("changeDate", getChangeDateTime()) ; get server reset time

        if (session.get("avgtotalSeconds") > 0 ) {
            StartTime := session.get("changeDate")
            StartTime += -(1.5*session.get("avgtotalSeconds")), Seconds
            EndTime := session.get("changeDate")
            EndTime += (0.5*session.get("avgtotalSeconds")), Seconds
        } else {
            StartTime := session.get("changeDate")
            StartTime += -5, minutes
            EndTime := session.get("changeDate")
            EndTime += 2, minutes
        }

        if(botConfig.get("deleteMethod") = "Create Bots (13P)"){
            StartTime := session.get("changeDate")
            StartTime += -900, Seconds
            EndTime := session.get("changeDate")
            EndTime += 120, Seconds
        }

        StartCurrentTimeDiff := A_Now
        EnvSub, StartCurrentTimeDiff, %StartTime%, Seconds
        EndCurrentTimeDiff := A_Now
        EnvSub, EndCurrentTimeDiff, %EndTime%, Seconds

        session.set("dateChange", false)

        while (StartCurrentTimeDiff > 0 && EndCurrentTimeDiff < 0) {
            FormatTime, formattedEndTime, %EndTime%, HH:mm:ss
            CreateStatusMessage("Waiting for daily server reset until " . formattedEndTime ,,,, false)
            session.set("dateChange", true)
            Sleep, 5000

            StartCurrentTimeDiff := A_Now
            EnvSub, StartCurrentTimeDiff, %StartTime%, Seconds
            EndCurrentTimeDiff := A_Now
            EnvSub, EndCurrentTimeDiff, %EndTime%, Seconds
        }

        session.set("VRAMUsage", GetVRAMByScriptName(session.get("scriptName")))
        if(session.get("VRAMUsage").Usage > 1){
            LogToFile("[" . A_ScriptName . "] GPU usage exceeds the threshold and restarts. VRAM Usage(" . session.get("VRAMUsage").Mode . "): " . session.get("VRAMUsage").Usage . " GB", "Restart.txt")
            CreateStatusMessage("Restarting Instance...",,,, false)
            restartInstance()
            DirectlyPositionWindow()
            CreateStatusMessage("Restart complete!",,,, false)
            LogToFile("[" . A_ScriptName . "] Restart complete!", "Restart.txt")
            session.set("loadedAccount", false)
        }

        if(session.get("dateChange"))
            botConfig.set("showcaseLikes", 5, "Extra")

        ; Only refresh account lists if we're not in injection mode or if no account is loaded
        ; This prevents constant list regeneration during injection
        if(session.get("injectMethod") && !session.get("loadedAccount")) {
            createAccountList(session.get("scriptName"))
        }

        ; For injection methods, load account only if we don't already have one
        if(session.get("injectMethod")) {
            ; Only load account if we don't already have one loaded
            if(!session.get("loadedAccount")) {
                session.set("loadedAccount", loadAccount())
            }

            ; If no account could be loaded for injection methods, handle appropriately
            if(!session.get("loadedAccount")) {
                ; Check user setting for what to do when no eligible accounts
                if(botConfig.get("waitForEligibleAccounts") = 1) {
                    ; Wait for eligible accounts to become available
                    ; Simple approach - just show wait message and sleep
                    CreateStatusMessage("No eligible accounts available for " . botConfig.get("deleteMethod") . ". Waiting 1 minute before checking again...", "", 0, 0, false)
                    LogToFile("No eligible accounts available for " . botConfig.get("deleteMethod") . ". Waiting 1 minute...")

                    ; Check stopToggle immediately, then wait 1 minute before checking again
                    if (session.get("stopToggle"))
                        CleanupBeforeExit()
                        ExitApp
                    Sleep, 60000  ; 1 minute
                    continue  ; Go back to start of loop to check again
                } else {
                    CleanupBeforeExit()
                    ExitApp
                }
            }

            ; If we reach here, we have a valid loaded account for injection
            LogToFile("Successfully loaded account for injection: " . session.get("accountFileName"))
        }

        ; Download friend IDs for injection methods when group reroll is enabled
        if(session.get("injectMethod")) {
            if(botConfig.get("groupRerollEnabled")) {
                mainIdsURL := botConfig.get("mainIdsURL")
                if(mainIdsURL) {
                    DownloadFile(mainIdsURL, "ids.txt")
                }
            }
        }

        
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        if(session.get("setSpeed") = 3)
            FindImageAndClick("Common_SpeedMod3x", 187, 172)
        else
            FindImageAndClick("Common_SpeedMod2x", 106, 173) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)

        session.set("packsInPool", 0)
        session.set("packsThisRun", 0)
        session.set("cantOpenMorePacks", 0)
        session.set("keepAccount", false)

        ; BallCity 2025.02.21 - Track monitor
        now := A_NowUTC
        IniWrite, %now%, % session.get("scriptIniFile"), Metrics, LastStartTimeUTC
        EnvSub, now, 1970, seconds
        IniWrite, %now%, % session.get("scriptIniFile"), Metrics, LastStartEpoch

        startPreProcess(botConfig.get("deleteMethod"))

        if(!session.get("injectMethod") || !session.get("loadedAccount")) {
            DoTutorial()
            session.set("accountOpenPacks", 0) ;tutorial packs don't count
        }

        if(botConfig.get("deleteMethod") = "Create Bots (13P)"){
            GoToMain()
            wonderPicked := DoWonderPick()
        }

        session.set("friendsAdded", AddFriends())

        if(botConfig.get("deleteMethod") = "Inject Wonderpick 96P+"){
            if(!session.get("isReloadAfterAddFriends"))
                GoToMain()
            else{
                clickX := getPackCoordXInHome()
                FindImageAndClick("Pack_PackPointButton", clickX, 203)
            }

        }
        
        SelectPack("First")
        if(session.get("cantOpenMorePacks"))
            Goto, MidOfRun

        PackOpening()
        if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
            Goto, MidOfRun

        ; Pack method handling
        if(session.get("packMethod")) {
            session.set("friendsAdded", AddFriends(true))
            GoToMain()
            SelectPack()
            if(session.get("cantOpenMorePacks"))
                Goto, MidOfRun
        }

        PackOpening()
        if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
            Goto, MidOfRun

        ; Hourglass opening for non-injection methods ONLY
        if(!session.get("injectMethod"))
            HourglassOpening() ;deletemethod check in here at the start

        ; Wonder pick additional handling - only for non-injection methods
        if(wonderPicked && !session.get("injectMethod")) {
            if(session.get("packMethod")) {
                session.set("friendsAdded", AddFriends(true))
                SelectPack("HGPack")
                PackOpening()
            } else {
                HourglassOpening(true)
            }

            if(session.get("packMethod")) {
                session.set("friendsAdded", AddFriends(true))
                SelectPack("HGPack")
                PackOpening()
            }
            else {
                HourglassOpening(true)
            }
        }

        ; Daily Mission 4hg collection and/or extra 3rd pack opening
        if((botConfig.get("deleteMethod") = "Inject Wonderpick 96P+" || botConfig.get("deleteMethod") = "Inject 13P+") && (botConfig.get("claimDailyMission") || botConfig.get("openExtraPack"))) {

            ; If only claiming daily missions (no extra pack)
            if(botConfig.get("claimDailyMission") && !botConfig.get("openExtraPack")) {
                GoToMain()
                GetAllRewards(false, true)
            }
            ; If only opening extra pack (no daily mission claim)
            else if(!botConfig.get("claimDailyMission") && botConfig.get("openExtraPack")) {
                ; Remove & add friends between 2nd free pack & HG pack if 1-pack method is enabled
                if(session.get("packMethod")) {
                    session.set("friendsAdded", AddFriends(true))
                    SelectPack("HGPack")
                }
                if(!session.get("cantOpenMorePacks")) {
                    HourglassOpening(true)
                }
            }
            ; If both settings are enabled (original functionality)
            else if(botConfig.get("claimDailyMission") && botConfig.get("openExtraPack")) {
                ; Remove & add friends between 2nd free pack & HG pack if 1-pack method is enabled
                if(session.get("packMethod")) {
                    session.set("friendsAdded", AddFriends(true))
                }

                GoToMain()
                GetAllRewards(false, true)
                GoToMain()
                SelectPack("HGPack")
                if(!session.get("cantOpenMorePacks")) {
                    PackOpening()
                }
            }
        }

        MidOfRun:

        if(botConfig.get("deleteMethod") = "Inject 13P+" || botConfig.get("deleteMethod") = "Inject Missions" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum"))
            Goto, EndOfRun

        if (checkShouldDoMissions()) {
            GoToMain()
            HomeAndMission()
            if(session.get("missionDoneList")["beginnerMissionsDone"])
                Goto, EndOfRun

            SelectPack("HGPack")
            if(session.get("cantOpenMorePacks"))
                Goto, EndOfRun

            PackOpening() ;6
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            HourglassOpening(true) ;7
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            GoToMain()
            HomeAndMission()
            if(session.get("missionDoneList")["beginnerMissionsDone"])
                Goto, EndOfRun

            SelectPack("HGPack")
            if(session.get("cantOpenMorePacks"))
                Goto, EndOfRun
            PackOpening() ;8
            if(cantOpesession.get("cantOpenMorePacks")nMorePacks || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            HourglassOpening(true) ;9
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            GoToMain()
            HomeAndMission()
            if(session.get("missionDoneList")["beginnerMissionsDone"])
                Goto, EndOfRun

            SelectPack("HGPack")
            if(session.get("cantOpenMorePacks"))
                Goto, EndOfRun
            PackOpening() ;10
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            HourglassOpening(true) ;11
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            ; Extended mission handling for Inject Missions
            if(session.get("injectMethod") && session.get("loadedAccount") && botConfig.get("deleteMethod") = "Inject Missions") {
                GoToMain()
                HomeAndMission()
                if(session.get("missionDoneList")["beginnerMissionsDone"])
                    Goto, EndOfRun

                SelectPack("HGPack")
                if(session.get("cantOpenMorePacks"))
                    Goto, EndOfRun
                PackOpening() ;12
                if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                    Goto, EndOfRun

                HourglassOpening(true) ;13
                if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                    Goto, EndOfRun
            }

            GoToMain()
            HomeAndMission(1)
            SelectPack("HGPack")
            if(session.get("cantOpenMorePacks"))
                Goto, EndOfRun
            PackOpening() ;12
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            GoToMain()
            HomeAndMission(1)
            SelectPack("HGPack")
            if(session.get("cantOpenMorePacks"))
                Goto, EndOfRun
            PackOpening() ;13
            if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
                Goto, EndOfRun

            session.get("missionDoneList")["beginnerMissionsDone"] := 1
            if(session.get("injectMethod") && session.get("loadedAccount"))
                setMetaData()
        }

        EndOfRun:

        if(!session.get("missionDoneList")["receivedGiftDone"] && botConfig.get("receiveGift") && session.get("injectMethod")) {
            GoToMain()
            ReceiveGift()

            session.get("missionDoneList")["receivedGiftDone"] := 0
            
            if (session.get("injectMethod") && session.get("loadedAccount"))
                setMetaData()
        }

        if(botConfig.get("ocrShinedust") && session.get("injectMethod") && session.get("loadedAccount") && botConfig.get("s4tEnabled")) {
            GoToMain()
            CountShinedust()
        }

        if(botConfig.get("wonderpickForEventMissions")) {
            GoToMain()
            FindImageAndClick("WonderPick_WonderPickButtonInHome", 59, 429) ;click until in wonderpick Screen
            DoWonderPickOnly()
        }

        ; Special missions
        if (botConfig.get("claimSpecialMissions") = 1 && (botConfig.get("deleteMethod") = "Inject 13P+" || botConfig.get("deleteMethod") = "Inject Wonderpick 96P+")) {
            syncSpecialEvents()

            ; removed check for !specialMissionsDone := 1 so that users don't need to constantly reset claim status on accounts.
            GoToMain()
            ;HomeAndMission(1)
            GetEventRewards(true) ; collects all the Special mission hourglass
            session.get("missionDoneList")["specialMissionsDone"] := 1
            session.set("cantOpenMorePacks", 0)
            if (session.get("injectMethod") && session.get("loadedAccount"))
                setMetaData()
        }

        ; Hourglass spending
        if (botConfig.get("spendHourGlass") = 1 && !(botConfig.get("deleteMethod") = "Inject 13P+" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum"))) {
            SpendAllHourglass()
        }

        ; Friend removal for Inject Wonderpick 96P+
        if (session.get("injectMethod") && session.get("friended") && !session.get("keepAccount")) {
            RemoveFriends()
        }
        
        ; Showcase likes
        if (botConfig.get("showcaseLikes") > 0 && botConfig.get("showcaseEnabled") = 1) {
            showcaseNumber := botConfig.get("showcaseLikes") - 1
            botConfig.set("showcaseLikes", showcaseNumber, "Extra")

            FindImageAndClick("Common_ActivatedSocialInMainMenu", 143, 518, , 500)
            showcaseLikes()
        }

        if (session.get("friended")) {
            CreateStatusMessage("Unfriending...",,,, false)
            RemoveFriends()
        }

        ; BallCity 2025.02.21 - Track monitor
        now := A_NowUTC
        IniWrite, %now%, % session.get("scriptIniFile"), Metrics, LastEndTimeUTC
        EnvSub, now, 1970, seconds
        IniWrite, %now%, % session.get("scriptIniFile"), Metrics, LastEndEpoch

        session.set("rerolls", session.get("rerolls") + 1)
        session.set("rerolls_local", session.get("rerolls_local") + 1)
        IniWrite, % session.get("rerolls"), % session.get("scriptIniFile"), Metrics, rerolls

        totalSeconds := Round((A_TickCount - session.get("rerollStartTime")) / 1000) ; Total time in seconds
        totalSeconds_local := Round((A_TickCount - session.get("rerollStartTime_local")) / 1000) ; Total time in seconds
        session.set("avgtotalSeconds", Round(totalSeconds_local / session.get("rerolls_local"))) ; Total time in seconds
        session.set("aminutes", Floor(session.get("avgtotalSeconds") / 60)) ; Average minutes
+       session.set("aseconds", Mod(session.get("avgtotalSeconds"), 60)) ; Average remaining seconds
        updateTotalTime()

        session.set("VRAMUsage", GetVRAMByScriptName(session.get("scriptName")))

        ; Add total time, Logging.ahk #31: guiheight := 30
        
        ; Display the times
        CreateStatusMessage(generateStatusText(), "AvgRuns", 0, 605, false, true)

        ; Log to file
        LogToFile("Packs: " . session.get("packsThisRun") . " | Total time: " . mminutes . "m " . sseconds . "s | Avg: " . aminutes . "m " . aseconds . "s | Runs: " . rerolls)

        SendMetadataToPTCGPB(session.get("packsThisRun"))

        ; Check for 40 first to quit
        if (botConfig.get("deleteMethod") = "Inject 13P+" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")) {
            if (session.get("injectMethod") && session.get("loadedAccount")) {
                if (!session.get("keepAccount")) {
                    MarkAccountAsUsed()
                }
                session.set("loadedAccount", false)
                continue
            }
        }

        if (session.get("injectMethod") && session.get("loadedAccount")) {
            ; For injection methods, mark the account as used
            if (!session.get("keepAccount")) {
                MarkAccountAsUsed()  ; Remove account from queue
                if(botConfig.get("verboseLogging"))
                    LogToFile("Marked injected account as used: " . session.get("accountFileName"))
            } else {
                if(botConfig.get("verboseLogging"))
                    LogToFile("Keeping injected account: " . session.get("accountFileName"))
            }

            ; Reset loadedAccount so it will be loaded fresh next iteration
            session.set("loadedAccount", false)
        } else if (!session.get("injectMethod")) {
            if ((!session.get("injectMethod") || !session.get("loadedAccount"))) {
                ; Save account for Create Bots
                ; At end of Create Bots run - check if we already have XML from tradeables
                deviceAccount := GetDeviceAccountFromXML()

                if (session.get("deviceAccountXmlMap").HasKey(deviceAccount) && FileExist(session.get("deviceAccountXmlMap")[deviceAccount])) {
                    ; We already have an XML from tradeable finds - update and rename it
                    existingXmlPath := session.get("deviceAccountXmlMap")[deviceAccount]

                    ; Update XML with final account state
                    UpdateSavedXml(existingXmlPath)

                    ; Build new filename with final pack count and metadata
                    metadata := ""
                    if(session.get("missionDoneList")["beginnerMissionsDone"])
                        metadata .= "B"
                    if(session.get("missionDoneList")["soloBattleMissionDone"])
                        metadata .= "S"
                    if(session.get("missionDoneList")["intermediateMissionsDone"])
                        metadata .= "I"
                    if(session.get("missionDoneList")["specialMissionsDone"])
                        metadata .= "X"
                    if(session.get("missionDoneList")["accountHasPackInTesting"])
                        metadata .= "T"

                    ; Extract timestamp from existing filename
                    SplitPath, existingXmlPath, oldFileName, saveDir
                    RegExMatch(oldFileName, "i)_(\d{14})_", match)
                    timestamp := match1

                    ; Create new filename: 13P_[original_timestamp]_1(B).xml
                    newFileName := session.get("accountOpenPacks") . "P_" . timestamp . "_" . session.get("winTitle") . "(" . metadata . ").xml"
                    newXmlPath := saveDir . "\" . newFileName

                    ; Rename the file
                    FileMove, %existingXmlPath%, %newXmlPath%, 1

                    ; Update mapping and accountFileName
                    session.get("deviceAccountXmlMap")[deviceAccount] := newXmlPath
                    session.set("accountFileName", newFileName)

                } else {
                    ; No tradeable XML exists - create new one normally
                    savedXmlPath := ""
                    saveAccount("All", savedXmlPath)

                    if (savedXmlPath) {
                        SplitPath, savedXmlPath, xmlFileName
                        session.set("accountFileName", xmlFileName)
                    }
                }

                ; if Create Bots + FoundTradeable, log to database and push discord webhook message(s)
                if (!session.get("loadDir") && session.get("s4tPendingTradeables").Length() > 0) {
                    ProcessPendingTradeables()
                }

                session.get("missionDoneList")["beginnerMissionsDone"] := 0
                session.get("missionDoneList")["soloBattleMissionDone"] := 0
                session.get("missionDoneList")["intermediateMissionsDone"] := 0
                session.get("missionDoneList")["specialMissionsDone"] := 0
                session.get("missionDoneList")["accountHasPackInTesting"] := 0

                restartGameInstance("New Run", false)
            } else {
                if (session.get("stopToggle")) {
                    CreateStatusMessage("Stopping...",,,, false)
                    CleanupBeforeExit()
                    ExitApp
                }
                restartGameInstance("New Run", false)
            }
        }
    }
}

return

HomeAndMission(homeonly := 0, completeSecondMisson=false) {
    global session

    Sleep, 250
    Leveled := 0
    Loop {
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            FindImageAndClick("Mission_ThemeCollectionButtonIcon", 261, 478, , 1000, 1)
            Delay(1)

            if(FindOrLoseImage("Mission_ThemeCollectionButtonIcon", 0, failSafeTime)){
                break
            }
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        }
        if(!homeonly){
            FindImageAndClick("Mission_ThemeCollectionButtonIcon", 261, 478, , 1000)

            wonderpicked := 0
            session.set("failSafe", A_TickCount)
            failSafeTime := 0
            Loop {
                Delay(1)

                Loop {
                    if (completeSecondMisson){
                        adbClick_wbb(150, 390)
                    }
                    else {
                        adbClick_wbb(150, 286)
                    }
                    Delay(1)

                    if(FindOrLoseImage("Mission_ThemeCollectionButtonIcon", 1, , 10)){
                        break
                    }
                }

                if(FindOrLoseImage("Mission_MissionIconTopAreaInDetails", 0, failSafeTime))
                    break

                if(FindOrLoseImage("Create_SoloBattleMissionIconInDetail", 0, failSafeTime)) {
                    session.get("missionDoneList")["beginnerMissionsDone"] := 1
                    
                    if(session.get("injectMethod") && session.get("loadedAccount"))
                        setMetaData()
                    return
                }

                if (FindOrLoseImage("Mission_FirstWonderpickMissionIconInDetails", 0, failSafeTime)){
                    adbClick_wbb(141, 396) ; click try it and go to wonderpick page
                    DoWonderPickOnly()
                    wonderpicked := 1
                    break
                }

                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            }
            if(!wonderpicked)
                break
        } else
            break
    }

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        Delay(1)

        adbClick_wbb(139, 424) ;clicks complete mission
        Delay(1)
        clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, failSafeTime, 80)
        if(clickButton) {
            adbClick_wbb(110, 435)
            Delay(1)
        }
        else if(FindOrLoseImage("Common_ShopButtonInMain", 1, failSafeTime)) {
            GoToMain()
            break
        }
        else
            break
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("In failsafe for WonderPick. " . failSafeTime "/45 seconds")
    }
    return Leveled
}

FindOrLoseImage(needleName := "DEFAULT", EL := 1, safeTime := 0, searchVariation := 20, notShowFinding := 0) {
    global botConfig, session, needlesDict
    static lastStatusTime := 0

    needleObj := needlesDict.Get(needleName)
    imageName := needleObj.imageName

    if(botConfig.get("slowMotion")) {
        if(imageName = "speedmodMenu" || imageName = "One" || imageName = "Two" || imageName = "Three")
            return true
    }
    imagePath := A_ScriptDir . "\Needles\"
    confirmed := false

    if(A_TickCount - lastStatusTime > 500 and !notShowFinding) {
        lastStatusTime := A_TickCount
        CreateStatusMessage("Finding " . imageName . "...")
    }

    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    Path = %imagePath%%imageName%.png
    pNeedle := GetNeedle(Path)

    X1 := needleObj.coords.startX
    Y1 := needleObj.coords.startY
    X2 := needleObj.coords.endX
    Y2 := needleObj.coords.endY

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

    if (imageName = "CommunityShowcase" || imageName = "Search" || imageName = "inHamburgerMenu" || imageName = "Trade") {
        Path = %imagePath%Tutorial.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 111, 115, 167, 121, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(145, 451)
        }
    }

    ; Handle 7/2025 trade news update popup, remove later patch
    if(imageName = "Points" || imageName = "Missions" || imageName = "WonderPick" || imageName = "Home" || imageName = "Country" || imageName = "Account2" || imageName = "Account" || imageName = "ClaimAll" || imageName = "inHamburgerMenu" || imageName = "Trade") {
        Path = %imagePath%Update.png
        pNeedle := GetNeedle(Path)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 15, 180, 53, 228, searchVariation)
        if (vRet = 1) {
            adbClick_wbb(137, 485)
            Gdip_DisposeImage(pBitmap)
            return confirmed
        }
    }

    stateResult := isTerminatePTCGPAppByADBShell()
    if(stateResult){
        restartGameInstance("Stuck at " . imageName . "... (found App3.png)")
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
    /*
    if(imageName = "CommunityShowcase") {
        TradeTutorialForShowcase()
    }
    */

    ErrorCheckInScreen(pBitmap)

    if(imageName = "Social" || imageName = "Country" || imageName = "Account2" || imageName = "Account" || imageName = "Points") { ;only look for deleted account on start up.
        Path = %imagePath%NoSave.png ; look for No Save Data error message > if loaded account > delete xml > reload
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 331, 50, 449, searchVariation)
        if (vRet = 1) {
            adbWriteRaw("rm -rf /data/data/jp.pokemon.pokemontcgp/cache/*") ; clear cache
            waitadb()
            CreateStatusMessage("Loaded deleted account. Deleting XML...",,,, false)
            if(session.get("loadedAccount")) {
                FileDelete, % session.get("loadedAccount")
                IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
            }
            LogToFile("Restarted game. Reason: No save data found")
            CleanupBeforeExit()
            SafeReload()
        }
    }

    ;country for new accounts, social for inject with friend id, points for inject without friend id
    if(imageName = "Country" || imageName = "Social" || imageName = "Points")
        FSTime := 90
    else if(imageName = "Missions" || imageName = "DailyMissions" || imageName = "DexMissions")
        FSTime := 60
    else
        FSTime := 45
    if (safeTime >= FSTime) {
        if(session.get("injectMethod") && session.get("loadedAccount") && session.get("friended")) {
            IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck
        }
        restartGameInstance("Stuck at " . imageName . "...")
        session.set("failSafe", A_TickCount)
    }
    Gdip_DisposeImage(pBitmap)
    return confirmed
}

FindImageAndClick(needleName := "DEFAULT", clickx := 0, clicky := 0, searchVariation := 20, sleepTime := "", skip := false, safeTime := 0) {
    global botConfig, session, needlesDict

    needleObj := needlesDict.Get(needleName)
    imageName := needleObj.imageName

    if(botConfig.get("slowMotion")) {
        if(imageName = "speedmodMenu" || imageName = "One" || imageName = "Two" || imageName = "Three")
            return true
    }
    if (sleepTime = "") {
        sleepTime := botConfig.get("Delay")
    }
    imagePath := A_ScriptDir . "\Needles\"
    click := false
    if(clickx > 0 and clicky > 0)
        click := true
    x := 0
    y := 0
    session.set("StartSkipTime", A_TickCount)

    confirmed := false

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

        pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
        Path = %imagePath%%imageName%.png
        pNeedle := GetNeedle(Path)
        ; ImageSearch within the region
        X1 := needleObj.coords.startX
        Y1 := needleObj.coords.startY
        X2 := needleObj.coords.endX
        Y2 := needleObj.coords.endY
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, X1, Y1, X2, Y2, searchVariation)
        if (!confirmed && vRet = 1) {
            confirmed := vPosXY
        } else {
            ElapsedTime := (A_TickCount - session.get("StartSkipTime")) // 1000
            if(imageName = "Country")
                FSTime := 90
            else if(imageName = "Missions" || imageName = "DailyMissions" || imageName = "DexMissions")
                FSTime := 60
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
                CreateStatusMessage("Instance " . session.get("scriptName") . " has been stuck for 90s. Killing it...")
                if(session.get("injectMethod") && session.get("loadedAccount") && session.get("friended")) {
                    IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck
                }
                restartGameInstance("Stuck at " . imageName . "...") ; change to reset the instance and delete data then reload script
            }
        }

        ErrorCheckInScreen(pBitmap)
        
        if (imageName = "CommunityShowcase" || imageName = "Add" || imageName = "Search") {
            Path = %imagePath%Tutorial.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 111, 115, 167, 121, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(145, 451)
            }
        }

        ; Search for 7/2025 trade news update popup; can be removed later patch
        if(imageName = "Points" || imageName = "Missions" || imageName = "WonderPick" || imageName = "Home" || imageName = "Country" || imageName = "Account2" || imageName = "Account" || imageName = "ClaimAll" || imageName = "inHamburgerMenu" || imageName = "Trade") {
            Path = %imagePath%Update.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 20, 191, 36, 211, searchVariation)
            if (vRet = 1) {
                adbClick_wbb(137, 485)
                Gdip_DisposeImage(pBitmap)
                continue
            }
        }

        stateResult := isTerminatePTCGPAppByADBShell()
        if(stateResult){
            restartGameInstance("Stuck at " . imageName . "... (found App3.png)")
        }

        if(imageName = "Social" || imageName = "Country" || imageName = "Account2" || imageName = "Account") { ;only look for deleted account on start up.
            Path = %imagePath%NoSave.png ; look for No Save Data error message > if loaded account > delete xml > reload
            pNeedle := GetNeedle(Path)
            ; ImageSearch within the region
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 30, 331, 50, 449, searchVariation)
            if (vRet = 1) {
                adbWriteRaw("rm -rf /data/data/jp.pokemon.pokemontcgp/cache/*") ; clear cache
                waitadb()
                CreateStatusMessage("Loaded deleted account. Deleting XML...",,,, false)
                if(session.get("loadedAccount")) {
                    FileDelete, % session.get("loadedAccount")
                    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
                }
                LogToFile("Restarted game. Reason: No save data found")
                CleanupBeforeExit()
                SafeReload()
            }
        }

        if(imageName = "Skip2" || imageName = "Pack" || imageName = "Hourglass2") {
            Path = %imagePath%notenoughitems.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 92, 299, 115, 317, 0)
            if(vRet = 1) {
                session.set("cantOpenMorePacks", 1)
                return 0
            }
        }

        if(imageName = "Mission_dino2") {
            Path = %imagePath%1solobattlemission.png
            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, 108, 180, 177, 208, 0)
            if(vRet = 1) {
                session.get("missionDoneList")["beginnerMissionsDone"] := 1
                if(session.get("injectMethod") && session.get("loadedAccount"))
                    setMetaData()
                return
            }
        }

        Gdip_DisposeImage(pBitmap)
        /*
        if(imageName = "CommunityShowcase") {
            TradeTutorialForShowcase()
        }
        */
        
        if(skip) {
            ElapsedTime := (A_TickCount - session.get("StartSkipTime")) // 1000
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

resetWindows() {
    DirectlyPositionWindow()

    return true
}

DirectlyPositionWindow() {
    global botConfig

    scaleParam := 283
    rowGap := botConfig.get("rowGap")

    ; Get monitor information
    SelectedMonitorIndex := RegExReplace(botConfig.get("SelectedMonitorIndex"), ":.*$")
    SysGet, Monitor, Monitor, %SelectedMonitorIndex%

    ; Calculate position based on instance number
    Title := session.get("winTitle")

    if (botConfig.get("runMain")) {
        instanceIndex := (botConfig.get("Mains") - 1) + Title + 1
    } else {
        instanceIndex := Title
    }

    titleHeight := 40

    borderWidth := 4 - 1
    rowHeight := titleHeight + 492
    currentRow := Floor((instanceIndex - 1) / botConfig.get("Columns"))

    y := MonitorTop + (currentRow * rowHeight) + (currentRow * rowGap)
    x := MonitorLeft + (Mod((instanceIndex - 1), botConfig.get("Columns")) * (scaleParam - borderWidth * 2))

    WinSet, Style, -0xC00000, % "ahk_id " . getMuMuHwnd(session.get("winTitle"))
    WinMove, % "ahk_id " . getMuMuHwnd(session.get("winTitle")), , %x%, %y%, %scaleParam%, %rowHeight%
    WinSet, Style, +0xC00000, % "ahk_id " . getMuMuHwnd(session.get("winTitle"))
    WinSet, Redraw, , % "ahk_id " . getMuMuHwnd(session.get("winTitle"))

    FixInstanceScreen(session.get("winTitle"))

    CreateStatusMessage("Positioned window at x:" . x . " y:" . y,,,, false)

    return true
}

PersistStopAfterRunIfNeeded() {
    global session
    if (session.get("stopToggle"))
        IniWrite, 1, % session.get("scriptIniFile"), UserSettings, stopAfterRunPending
}

restartGameInstance(reason, RL := true) {
    global botConfig, session, DeadCheck
    isStuck := InStr(reason, "Stuck")

    if (Debug)
        CreateStatusMessage("Restarting game reason:`n" . reason)
    else if (isStuck)
        CreateStatusMessage("Stuck! Restarting MuMu...",,,, false)
    else
        CreateStatusMessage("Restarting game...",,,, false)

    ; Log to instance-specific log file
    if (isStuck) {
        logStr := "STUCK DETECTED - Reason: " . reason . " | injectMethod: " . (session.get("injectMethod") ? "true" : "false") . " | "
        logStr .= "loadedAccount: " . (session.get("loadedAccount") ? "true" : "false") . " | "
        logStr .= "accountFileName: " . session.get("accountFileName")
        LogToFile(logStr)
        SaveStuckScreenshot(reason)
    }

    if (RL = "GodPack") {
        LogToFile("Restarted game. Reason: " reason)
        IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
        if (!botConfig.get("groupRerollEnabled"))
            AppendFriendCodeToManualVipIds(session.get("friendCode"))
        SendMetadataToPTCGPB(session.get("packsThisRun"))

        PersistStopAfterRunIfNeeded()
        CleanupBeforeExit()
        Reload
    } else if (isStuck) {
        if(!checkInstance(session.get("scriptName"))){
            LogToFile(" Found " . session.get("scriptName") . " instance down! start Instance")
            launchInstance(session.get("scriptName"))
        }

        ; Only restart MuMu when stuck - this is the nuclear option
        clearMissionCache()

        ; Kill the entire MuMu instance
        CreateStatusMessage("Restarting Pocket App...",,,, false)
        LogToFile("Restarting Pocket App " . session.get("scriptName") . " due to: " . reason)
        ;restartInstance()
        closePTCGPApp()
        Sleep, 100
        startPTCGPApp()
        SendMetadataToPTCGPB(session.get("packsThisRun"))
        LogToFile("Restarted MuMu instance. Reason: " reason)

        PersistStopAfterRunIfNeeded()
        CleanupBeforeExit()
        SafeReload()
    } else {
        ; Non-stuck restart: just restart the Pokemon app, not the whole MuMu instance
        closePTCGPApp()
        Sleep, 100

        clearMissionCache()
        if (!RL && DeadCheck = 0) {
            adbWriteRaw("rm -f /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml") ; delete account data
        }
        Sleep, 100
        startPTCGPApp()

        if (RL) {
            LogToFile("Restarted game. Reason: " reason)

            PersistStopAfterRunIfNeeded()
            CleanupBeforeExit()
            SafeReload()
        }

        if (session.get("stopToggle")) {
            CreateStatusMessage("Stopping...",,,, false)
            CleanupBeforeExit()
            ExitApp
        }
    }
}

SaveStuckScreenshot(reason) {
    global session

    fileDir := A_ScriptDir . "\..\Screenshots\Stuck"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%

    safeReason := RegExReplace(reason, "[\\/:*?""<>|]", "_")
    safeReason := RegExReplace(safeReason, "\s+", "_")
    safeReason := SubStr(safeReason, 1, 80)
    filePath := fileDir . "\" . A_Now . "_inst" . session.get("scriptName") . "_" . safeReason . ".png"

    hWnd := getMuMuHwnd(session.get("winTitle"))
    if (!hWnd)
        return

    pBitmap := from_window(hWnd)
    if (pBitmap) {
        Gdip_SaveBitmapToFile(pBitmap, filePath)
        Gdip_DisposeImage(pBitmap)
        LogToFile("Saved stuck screenshot: " . filePath)
    }
}

menuDelete() {
    global botConfig, session

    Delay(1)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop
    {
        Delay(2)
        adbClick_wbb(245, 518)
        if(FindImageAndClick("Menu_InventoryIconInMenu", , , , , 1, failSafeTime)) ;wait for settings menu
            break
        Delay(2)
        adbClick_wbb(50, 100)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Settings`n(" . failSafeTime . " seconds)")
    }
    Delay(1)
    FindImageAndClick("Menu_SettingButtonInMenu", 140, 440, , 2000) ;wait for other menu
    Delay(1)
    FindImageAndClick("Menu_RemoveAccountNintendoButtonInMenu", 79, 256, , 1000) ;wait for account menu
    Delay(1)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            clickButton := FindOrLoseImage("Common_UnknownButton2", 0, failSafeTime, 40)
            if(!clickButton) {
                ; fix https://discord.com/channels/1330305075393986703/1354775917288882267/1355090394307887135
                clickImage := FindOrLoseImage("Menu_DeleteConfimButtonStep1", 0, failSafeTime, 60)
                if(clickImage) {
                    StringSplit, pos, clickImage, `,  ; Split at ", "
                    adbClick_wbb(pos1, pos2)
                }
                else {
                    adbClick_wbb(198, 480)
                    Delay(2)
                    adbClick_wbb(230, 506)
                }
                Delay(1)
                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
                CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
            }
            else {
                break
            }
            Delay(1)
        }
        StringSplit, pos, clickButton, `,  ; Split at ", "
        adbClick_wbb(pos1, pos2)
        break
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
    }

    Sleep, 2500
}

menuDeleteStart() {
    global botConfig, session

    if(session.get("keepAccount")) {
        return session.get("keepAccount")
    }
    if(session.get("friended")) {
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        if(session.get("setSpeed") = 3)
            FindImageAndClick("Common_SpeedMod3x", 187, 172)
        else
            FindImageAndClick("Common_SpeedMod2x", 106, 173) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        if(!session.get("friended"))
            break
        adbClick_wbb(255, 83)
        if(FindOrLoseImage("Create_CountryComboBoxButton", 0, failSafeTime)) { ;if at country continue
            break
        }
        else if(FindOrLoseImage("Menu_AgreementIconInIntroMenu", 0, failSafeTime)) { ; if the clicks in the top right open up the game settings menu then continue to delete account
            Delay(1)
            FindImageAndClick("Menu_RemoveAccountNintendoButtonInMenu", 79, 256, , 1000) ;wait for account menu
            Delay(1)
            session.set("failSafe", A_TickCount)
            failSafeTime := 0
            Loop {
                clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, failSafeTime, 80)
                if(!clickButton) {
                    clickImage := FindOrLoseImage("Menu_DeleteConfimButtonStep1", 0, failSafeTime, 60)
                    if(clickImage) {
                        StringSplit, pos, clickImage, `,  ; Split at ", "
                        adbClick_wbb(pos1, pos2)
                    }
                    else {
                        adbClick_wbb(230, 506)
                    }
                    Delay(1)
                    failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
                    CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
                }
                else {
                    break
                }
                Delay(1)
            }
            StringSplit, pos, clickButton, `,  ; Split at ", "
            adbClick_wbb(pos1, pos2)
            break
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting to click delete`n(" . failSafeTime . "/45 seconds)")
        }
        CreateStatusMessage("Looking for Country/Menu")
        Delay(1)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Country/Menu`n(" . failSafeTime . "/45 seconds)")
    }
    if(session.get("loadedAccount")) {
        ;    FileDelete, % session.get("loadedAccount")
    }
}

CheckPack() {
    global botConfig, session

    currentPackIs6Card := false ; reset before each pack check
    currentPackIs6Card := false ; reset before each pack check

    ; Update pack count.
    session.set("accountOpenPacks", session.get("accountOpenPacks")+1)
    if (session.get("injectMethod") && session.get("loadedAccount"))
        UpdateAccount()

    session.set("packsInPool", session.get("packsInPool") + 1)
    session.set("packsThisRun", session.get("packsThisRun") + 1)

    ; NEW: Disable card detection for Create Bots and Inject 13P+
    ; Only run detection for Inject Wonderpick 96P+
    skipCardDetection := (botConfig.get("deleteMethod") = "Create Bots (13P)" || botConfig.get("deleteMethod") = "Inject 13P+")

    ; If not doing card detection and no friends and s4t disabled, just return early
    if(skipCardDetection && !session.get("friendIDs") && botConfig.get("FriendID") = "" && !botConfig.get("s4tEnabled"))
        return false

    currentPackIs4Card := DetectFourCardPack()
    if (!currentPackIs4Card) {
        currentPackIs6Card := DetectSixCardPack()
    }

    ; Determine total cards in pack for 4-diamond s4t calculations
    totalCardsInPack := currentPackIs6Card ? 6 : (currentPackIs4Card ? 4 : 5)

    ; Wait for cards to render before checking.
    Loop {
        if (CheckCardLoading(totalCardsInPack) = 0)
            break
        Delay(1)
    }
    Delay(1)

    currentPackInfo := AnalysisBorder(totalCardsInPack)
    session.set("currentPackInfo", currentPackInfo)

    ; NEW: Check for s4t tradeable cards FIRST (before invalid/godpack checks)
    ; This allows s4t to work even on "invalid" packs with crowns/immersives/etc
    if (botConfig.get("s4tEnabled")) {
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
        if (botConfig.get("s4t3Dmnd")) {
            found3Dmnd := currentPackInfo["TypeCount"]["3diamond"]
        }
        if (botConfig.get("s4t1Star")) {
            found1Star := currentPackInfo["TypeCount"]["1star"]
        }
        if (botConfig.get("s4t4Dmnd")) {
            ; Detecting a 4-diamond EX card by subtracting other types
            found4Dmnd := totalCardsInPack - currentPackInfo["TypeCount"]["normal"]
            if (found4Dmnd > 0) {
                if (botConfig.get("s4t3Dmnd"))
                    found4Dmnd -= found3Dmnd
                else
                    found4Dmnd -= currentPackInfo["TypeCount"]["3diamond"]
            }
            if (found4Dmnd > 0) {
                if (botConfig.get("s4t1Star"))
                    found4Dmnd -= found1Star
                else
                    found4Dmnd -= currentPackInfo["TypeCount"]["1star"]
            }
            if (found4Dmnd > 0) {
                found4Dmnd -= currentPackInfo["TypeCount"]["trainer"]
                found4Dmnd -= currentPackInfo["TypeCount"]["rainbow"]
                found4Dmnd -= currentPackInfo["TypeCount"]["fullart"]
                found4Dmnd -= currentPackInfo["TypeCount"]["immersive"]
                found4Dmnd -= currentPackInfo["TypeCount"]["crown"]
                found4Dmnd -= currentPackInfo["TypeCount"]["ShinyEx"]
                found4Dmnd -= currentPackInfo["TypeCount"]["shiny1star"]
            }
        }
        if (botConfig.get("s4tGholdengo") && session.get("openPack") = "Shining") {
            foundGimmighoul := FindCard("gimmighoul")
        }

        ; NEW: Only check if the specific card type is enabled
        if (botConfig.get("s4tCrown")) {
            foundCrown := currentPackInfo["TypeCount"]["crown"]
        }
        if (botConfig.get("s4tImmersive")) {
            foundImmersive := currentPackInfo["TypeCount"]["immersive"]
        }
        if (botConfig.get("s4tShiny2Star")) {
            foundShiny2Star := currentPackInfo["TypeCount"]["ShinyEx"]
        }
        if (botConfig.get("s4tShiny1Star")) {
            foundShiny1Star := currentPackInfo["TypeCount"]["shiny1star"]
        }
        if (botConfig.get("s4tTrainer")) {
            foundTrainer := currentPackInfo["TypeCount"]["trainer"]
        }
        if (botConfig.get("s4tRainbow")) {
            foundRainbow := currentPackInfo["TypeCount"]["rainbow"]
        }
        if (botConfig.get("s4tFullArt")) {
            foundFullArt := currentPackInfo["TypeCount"]["fullart"]
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
    foundShiny := currentPackInfo["TypeCount"]["ShinyEx"] + currentPackInfo["TypeCount"]["shiny1star"]
    foundCrown := currentPackInfo["TypeCount"]["crown"]
    foundImmersive := currentPackInfo["TypeCount"]["immersive"]
    foundInvalid := foundShiny + foundCrown + foundImmersive

    if (foundInvalid) {
        ; Pack is invalid...
        foundInvalidGP := FindGodPack(true) ; GP is never ignored

        if (foundInvalidGP){
            restartGameInstance("Invalid God Pack Found.", "GodPack")
        }
        if (!foundInvalidGP && !botConfig.get("InvalidCheck")) {
            ; If not a GP and not "ignore invalid packs", check what cards the current pack contains which make it invalid
            if (botConfig.get("ShinyCheck") && foundShiny && !foundLabel)
                foundLabel := "Shiny"
            if (botConfig.get("ImmersiveCheck") && foundImmersive && !foundLabel)
                foundLabel := "Immersive"
            if (botConfig.get("CrownCheck") && foundCrown && !foundLabel)
                foundLabel := "Crown"

            ; Report invalid cards found.
            if (foundLabel) {
                FoundStars(foundLabel)
                restartGameInstance(foundLabel . " found. Continuing...", "GodPack")
            }
        }

        IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
        return
    }

    ; Check for god pack. if found we know its not invalid
    session.set("foundGP", FindGodPack())

    if (session.get("foundGP")) {
        if (session.get("loadedAccount")) {
            session.get("missionDoneList")["accountHasPackInTesting"] := 1  ; T flag ONLY for godpacks
            setMetaData()
            IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
        }

        restartGameInstance("God Pack found. Continuing...", "GodPack")
        return
    }

    ; Check for 2-star cards (for Inject Wonderpick 96P+ only)
    foundTrainer := false
    foundRainbow := false
    foundFullArt := false
    2starCount := false

    if (botConfig.get("PseudoGodPack") && !foundLabel) {
        foundTrainer := currentPackInfo["TypeCount"]["trainer"]
        foundRainbow := currentPackInfo["TypeCount"]["rainbow"]
        foundFullArt := currentPackInfo["TypeCount"]["fullart"]
        2starCount := foundTrainer + foundRainbow + foundFullArt
        if (2starCount > 1)
            foundLabel := "Double two star"
    }
    if (botConfig.get("TrainerCheck") && !foundLabel) {
        if(!botConfig.get("PseudoGodPack"))
            foundTrainer := currentPackInfo["TypeCount"]["trainer"]
        if (foundTrainer)
            foundLabel := "Trainer"
    }
    if (botConfig.get("RainbowCheck") && !foundLabel) {
        if(!botConfig.get("PseudoGodPack"))
            foundRainbow := currentPackInfo["TypeCount"]["rainbow"]
        if (foundRainbow)
            foundLabel := "Rainbow"
    }
    if (botConfig.get("FullArtCheck") && !foundLabel) {
        if(!botConfig.get("PseudoGodPack"))
            foundFullArt := currentPackInfo["TypeCount"]["fullart"]
        if (foundFullArt)
            foundLabel := "Full Art"
    }

    if (foundLabel) {
        if (session.get("loadedAccount")) {
            ; NEW: Do NOT add T flag for single 2-star cards
            ; Only godpacks get the T flag now
            IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
        }

        FoundStars(foundLabel)
        restartGameInstance(foundLabel . " found. Continuing...", "GodPack")
    }
}

ControlClick(X, Y) {
    global session
    ControlClick, x%X% y%Y%, % session.get("winTitle")
}

Screenshot_dev(fileType := "Dev", subDir := "", srcPath := "") {
    global session, rec_Active
    SetWorkingDir %A_ScriptDir%  ; Ensures the working directory is the script's directory

    ; Define folder and file paths
    fileDir := A_ScriptDir "\..\Screenshots\grab"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%
    if (subDir) {
        fileDir .= "\" . subDir
    }
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%

    ; File path for saving the screenshot locally
    fileName := A_Now . "_" . session.get("scriptName") . "_" . fileType . ".png"
    filePath := fileDir "\" . fileName

    if (srcPath != "" && FileExist(srcPath))
        pBitmapW := Gdip_CreateBitmapFromFile(srcPath)
    else
        pBitmapW := from_window(getMuMuHwnd(session.get("winTitle")))
    Gdip_SaveBitmapToFile(pBitmapW, filePath)

    sleep 100

    try {
        OwnerWND := WinExist(session.get("winTitle"))
        buttonWidth := 40

        guiSuffix := session.get("winTitle")
        Gui, DevMode_ss%guiSuffix%:New, +LastFound -DPIScale
        Gui, DevMode_ss%guiSuffix%:Add, Picture, x0 y0 w275 h534, %filePath%
        Gui, DevMode_ss%guiSuffix%:Show, w275 h534, % "Screensho" session.get("winTitle")

        sleep 100
        msgbox click on top-left corner and bottom-right corners

        yBias := 40

        KeyWait, LButton, D
        MouseGetPos , X1, Y1, OutputVarWin, OutputVarControl
        KeyWait, LButton, U
        Y1 -= 31
        Y1Image := Y1

        ; Return in case of user close the screen
        if !WinExist("Screensho " session.get("scriptName"))
            return

        KeyWait, LButton, D
        MouseGetPos , X2, Y2, OutputVarWin, OutputVarControl
        KeyWait, LButton, U
        Y2 -= 31
        Y2Image := Y2

        W:=X2-X1
        H:=Y2-Y1

        pBitmap := Gdip_CloneBitmapArea(pBitmapW, X1, Y1Image, W, H)

        InputBox, fileName, ,"Enter the name of the needle to save"

        if (fileName = "") {
            return ""
        }

        fullScreenPath := filePath
        fileDir := A_ScriptDir . "\Needles"
        filePath := fileDir "\" . fileName . ".png"
        Gdip_SaveBitmapToFile(pBitmap, filePath)

        msgbox click on coordinate for adbClick

        KeyWait, LButton, D
        MouseGetPos , X3, Y3, OutputVarWin, OutputVarControl
        KeyWait, LButton, U
        Y3 -= 31 + yBias

        global rec_LastScreenGrab
        rec_LastScreenGrab := {fileName: fileName, needlePath: filePath
            , screenshot: fullScreenPath
            , x1: X1, y1: Y1, x2: X2, y2: Y2, x3: X3, y3: Y3}

        ; Convert window coordinates to device/OCR coordinates
        ; Device resolution: 540x960, Window resolution: 277x489, Y offset: 44
        OCR_X1 := Round(X1 * 540 / 283)
        OCR_Y1 := Round((Y1 - 44) * 960 / 488)
        OCR_W := Round(W * 540 / 283)
        OCR_H := Round(H * 960 / 488)
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
    fileName := A_Now . "_" . session.get("scriptName") . "_" . fileType . "_" . session.get("packsInPool") . "_packs.png"
    if (filename = "PACKSTATS")
        fileName := "packstats_temp.png"
    filePath := fileDir "\" . fileName

    yBias := 40
    pBitmapW := from_window(getMuMuHwnd(session.get("winTitle")))
    pBitmap := Gdip_CloneBitmapArea(pBitmapW, 18, 170, 240, 227)

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
    session.set("StartSkipTime", A_TickCount) ;reset stuck timers
    session.set("failSafe", A_TickCount)
    Pause, Off
return

; Stop Script
StopScript:
    ToggleStop()
return

DevMode:
    ToggleDevMode()
return

ReloadScript:
    CleanupBeforeExit()
    SafeReload()
return

TestScript:
    ToggleTestScript()
return

; ToggleStop - For GUI button clicks (stops only THIS instance)
ToggleStop() {
    static ui_RememberStopPreferenceSingle
    global botConfig, session, dictionaryData

    ; Check if user has a saved preference for single instance stop
    settingsPath := A_ScriptDir . "\..\Settings.ini"
    IniRead, savedStopPreferenceSingle, %settingsPath%, UserSettings, stopPreferenceSingle, none

    if (savedStopPreferenceSingle != "none" && savedStopPreferenceSingle != "ERROR" && savedStopPreferenceSingle != "") {
        ; Execute the saved preference directly without showing popup
        if (savedStopPreferenceSingle = "immediate") {
            CleanupBeforeExit()
            ExitApp
        } else if (savedStopPreferenceSingle = "wait_end") {
            session.set("stopToggle", true)
            CreateStatusMessage("Stopping script at the end of the run...",,,, false)
        }
        return
    }

    ; Get localized strings
    title := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_confirm_title"]
    btnImmediate := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_immediately"]
    btnWaitEnd := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_wait_end"]
    chkRemember := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_remember_preference"]

    ; Create confirmation GUI with checkbox
    Gui, StopConfirm:New, +AlwaysOnTop +Owner
    Gui, StopConfirm:Add, Text, x20 y15 w260 Center, % title
    Gui, StopConfirm:Add, Button, x20 y45 w130 h30 gStopImmediatelySingle, % btnImmediate
    Gui, StopConfirm:Add, Button, x160 y45 w130 h30 gStopWaitEndSingle, % btnWaitEnd
    Gui, StopConfirm:Add, Checkbox, x20 y85 w260 vui_RememberStopPreferenceSingle, % chkRemember
    Gui, StopConfirm:Show, w310 h115, % title
    return
}

; ToggleStopAll - For Shift+F7 hotkey (stops ALL instances, only called from instance 1)
ToggleStopAll() {
    static ui_RememberStopPreference
    global botConfig, session, dictionaryData

    ; Check if user has a saved preference
    settingsPath := A_ScriptDir . "\..\Settings.ini"
    IniRead, savedStopPreference, %settingsPath%, UserSettings, stopPreference, none

    if (savedStopPreference != "none" && savedStopPreference != "ERROR" && savedStopPreference != "") {
        ; Execute the saved preference directly without showing popup
        if (savedStopPreference = "immediate") {
            StopAllInstances()
        } else if (savedStopPreference = "wait_end") {
            SignalStopAfterRun()
            session.set("stopToggle", true)
            CreateStatusMessage("Stopping script at the end of the run...",,,, false)
        } else if (savedStopPreference = "kill_mumu") {
            Loop, % botConfig.get("Instances") {
                killInstance(A_Index)
                Sleep, 500
            }
            Sleep, 1000
            StopAllInstances()
        }
        return
    }

    ; Get localized strings
    title := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_confirm_title"]
    btnImmediate := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_immediately"]
    btnWaitEnd := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_wait_end"]
    btnKillMumu := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_kill_mumu"]
    chkRemember := dictionaryData[botConfig.get("defaultBotLanguage")]["stop_remember_preference"]

    ; Create confirmation GUI with checkbox
    Gui, StopConfirmAll:New, +AlwaysOnTop +Owner
    Gui, StopConfirmAll:Add, Text, x20 y15 w400 Center, % title
    Gui, StopConfirmAll:Add, Button, x20 y45 w130 h30 gStopImmediatelyAll, % btnImmediate
    Gui, StopConfirmAll:Add, Button, x160 y45 w130 h30 gStopWaitEndAll, % btnWaitEnd
    Gui, StopConfirmAll:Add, Button, x300 y45 w130 h30 gStopAndKillMuMuAll, % btnKillMumu
    Gui, StopConfirmAll:Add, Checkbox, x20 y85 w400 vui_RememberStopPreference, % chkRemember
    Gui, StopConfirmAll:Show, w450 h115, % title
    return
}

; === Single instance stop handlers (GUI button) ===
StopImmediatelySingle:
    Gui, StopConfirm:Submit, NoHide
    GuiControlGet, RememberStopPreferenceSingle, , ui_RememberStopPreferenceSingle
    if (RememberStopPreferenceSingle) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, immediate, %settingsPath%, UserSettings, stopPreferenceSingle
    }
    Gui, StopConfirm:Destroy
    CleanupBeforeExit()
    ExitApp
return

StopWaitEndSingle:
    Gui, StopConfirm:Submit, NoHide
    GuiControlGet, RememberStopPreferenceSingle, , ui_RememberStopPreferenceSingle
    if (RememberStopPreferenceSingle) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, wait_end, %settingsPath%, UserSettings, stopPreferenceSingle
    }
    Gui, StopConfirm:Destroy
    session.set("stopToggle", true)
    CreateStatusMessage("Stopping script at the end of the run...",,,, false)
return

StopConfirmGuiClose:
StopConfirmGuiEscape:
    Gui, StopConfirm:Destroy
return

; === All instances stop handlers (Shift+F7 from instance 1) ===
StopImmediatelyAll:
    GuiControlGet, RememberStopPreference, , ui_RememberStopPreference
    Gui, StopConfirmAll:Submit, NoHide
    if (RememberStopPreference) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, immediate, %settingsPath%, UserSettings, stopPreference
    }
    Gui, StopConfirmAll:Destroy
    StopAllInstances()
return

StopWaitEndAll:
    GuiControlGet, RememberStopPreference, , ui_RememberStopPreference
    Gui, StopConfirmAll:Submit, NoHide
    if (RememberStopPreference) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, wait_end, %settingsPath%, UserSettings, stopPreference
    }
    Gui, StopConfirmAll:Destroy
    ; Signal all other instances to stop after their current run
    SignalStopAfterRun()
    session.set("stopToggle", true)
    CreateStatusMessage("Stopping script at the end of the run...",,,, false)
return

StopAndKillMuMuAll:
    GuiControlGet, RememberStopPreference, , ui_RememberStopPreference
    Gui, StopConfirmAll:Submit, NoHide
    if (RememberStopPreference) {
        settingsPath := A_ScriptDir . "\..\Settings.ini"
        IniWrite, kill_mumu, %settingsPath%, UserSettings, stopPreference
    }
    Gui, StopConfirmAll:Destroy
    ; Kill ALL MuMu instances before calling StopAllInstances (which does ExitApp)
    Loop, % botConfig.get("Instances") {
        killInstance(A_Index)
        Sleep, 500
    }
    Sleep, 1000
    StopAllInstances()
return

StopConfirmAllGuiClose:
StopConfirmAllGuiEscape:
    Gui, StopConfirmAll:Destroy
return

; Kill all script instances immediately
StopAllInstances() {
    global botConfig

    DetectHiddenWindows, On
    SetTitleMatchMode, 2  ; Match if title CONTAINS the string (needed for full paths)

    ; Close Main.ahk first
    WinClose, Main.ahk ahk_class AutoHotkey

    ; Close all numbered instances (2 through Instances, skip 1 which is us)
    Loop, % botConfig.get("Instances") {
        if (A_Index != 1) {
            WinClose, % A_Index ".ahk ahk_class AutoHotkey"
        }
    }

    ; Finally exit this instance
    CleanupBeforeExit()
    ExitApp
}

OnMonitorWake(wParam, lParam, msg, hwnd) {
    global session

    DelayH(3000)
    FixInstanceScreen(session.get("scriptName"))
}

; Message handler for "stop after run" signal from instance 1
OnStopAfterRunMessage(wParam, lParam, msg, hwnd) {
    global session
    session.set("stopToggle", true)
    CreateStatusMessage("Stopping script at the end of the run...",,,, false)
    return 0
}

; Send "stop after run" message to all other script instances
SignalStopAfterRun() {
    global botConfig

    DetectHiddenWindows, On
    SetTitleMatchMode, 2

    ; Send message to all numbered instances (2 through Instances)
    Loop, % botConfig.get("Instances") {
        if (A_Index != 1) {
            ; Find the window for this instance
            WinGet, targetHwnd, ID, % A_Index ".ahk ahk_class AutoHotkey"
            if (targetHwnd) {
                ; Send custom message (0x500) to signal "stop after run"
                PostMessage, 0x500, 0, 0,, ahk_id %targetHwnd%
            }
        }
    }
}

ToggleTestScript() {
    global session

    if(!session.get("GPTest")) {
        CreateStatusMessage("In GP Test Mode",,,, false)
        session.set("GPTest", true)
    }
    else {
        CreateStatusMessage("Exiting GP Test Mode",,,, false)
        session.set("GPTest", false)
    }
}

; ===== TIMER FUNCTIONS =====
RefreshAccountLists:
    createAccountList(session.get("scriptName"))
Return

CleanupUsedAccountsTimer:
    CleanupUsedAccounts()
Return

LiveMetricsTimer:
    updateTotalTime()
    session.set("VRAMUsage", GetVRAMByScriptName(session.get("scriptName")))
    CreateStatusMessage(generateStatusText(), "AvgRuns", 0, 605, false, true)
Return

; ===== HOTKEYS =====
~+F5::
    CleanupBeforeExit()
    SafeReload()
return
~+F6::Pause
~+F7::
    ; Only instance 1 handles Shift+F7 - shows popup and controls all instances
    ; Other instances do nothing here; they receive commands via PostMessage from instance 1
    if (session.get("scriptName") = "1") {
        ToggleStopAll()
    }
return
~+F8::ToggleDevMode()
;~F9::restartGameInstance("F9")

; ===== RECORDER HOTKEY =====
; Fires on every left-click; no-op unless recording is active.
/*
~+LButton::
    if (!rec_Active) {
        return
    }
    if (rec_SuspendCapture) {
        return
    }
    MouseGetPos, rec_DownX, rec_DownY, clickedHwnd
    if (clickedHwnd != WinExist(session.get("winTitle"))) {
        return
    }
    CoordMode, Mouse, Screen
    MouseGetPos, rec_DownX, rec_DownY
    CoordMode, Mouse, Relative

    rec_DownTime := A_TickCount
    KeyWait, LButton

    CoordMode, Mouse, Screen
    MouseGetPos, upX, upY
    CoordMode, Mouse, Relative
    held := A_TickCount - rec_DownTime

    ; Compute window-relative coords first, then use them for distance
    WinGetPos, wx, wy, ww, wh, % session.get("winTitle")
    devX1 := rec_DownX - wx
    devY1 := rec_DownY - wy
    devX2 := upX - wx
    devY2 := upY - wy

    ; Ignore clicks that started outside the emulator window
    if (devX1 < 0 || devY1 < 0 || devX1 > ww || devY1 > wh) {
        return
    }

    dist := Sqrt((devX2 - devX1) ** 2 + (devY2 - devY1) ** 2)

    if (dist > 20)
        type := "swipe"
    else if (held >= 500)
        type := "hold"
    else
        type := "click"

    ssPath := RecordingCapture()
    rawDelay := A_TickCount - rec_LastTime - held
    delay := (rawDelay > 0) ? rawDelay // Delay : 0
    rec_LastTime := A_TickCount
    actionIdx := rec_Actions.Length() + 1
    LogToFile("[Hook] Pushing action idx=" actionIdx " type=" type " x1=" devX1 " y1=" devY1 " x2=" devX2 " y2=" devY2 " ssPath=" ssPath, "recorder.txt")
    rec_Actions.Push({type: type, x1: devX1, y1: devY1, x2: devX2, y2: devY2
        , duration: held, delay: delay, screenshot: ssPath, comment: "", code: ""})
    LogToFile("[Hook] rec_Actions.Length()=" rec_Actions.Length() " last.screenshot=" rec_Actions[rec_Actions.Length()].screenshot, "recorder.txt")
    CreateStatusMessage("Recording: Capture`n" type " (" devX1 "," devY1 ")-(" devX2 "," devY2 ") dist=" dist)
return
*/
ToggleDevMode() {
    global session

    try {
        OwnerWND := getMuMuHwnd(session.get("winTitle"))
        if (!OwnerWND) {
            CreateStatusMessage("Failed to create button GUI. Emulator window not found.",,,, false)
            return
        }

        WinGetPos, x, y, Width, Height, ahk_id %OwnerWND%
        x4 := x + 5
        y4 := y + 44
        buttonWidth := 40

        guiSuffix := session.get("winTitle")
        Gui, DevMode%guiID%:Destroy
        Gui, DevMode%guiID%:New, +Owner%OwnerWND% +LastFound
        Gui, DevMode%guiID%:Font, s5 cGray Norm Bold, Segoe UI  ; Normal font for input labels
        Gui, DevMode%guiID%:Add, Button, % "x" . (buttonWidth * 0) . " y0 w" . buttonWidth . " h25 gbboxScript", bound box

        Gui, DevMode%guiID%:Add, Button, % "x" . (buttonWidth * 1) . " y0 w" . buttonWidth . " h25 gbboxNpauseScript", bbox pause

        Gui, DevMode%guiID%:Add, Button, % "x" . (buttonWidth * 2) . " y0 w" . buttonWidth . " h25 gscreenshotscript", screen grab
        ;Gui, DevMode%guiID%:Add, Button, % "x" . (buttonWidth * 3) . " y0 w" . buttonWidth . " h25 gStartStopRecording", Start Recording

        Gui, DevMode%guiID%:Add, Button, % "x" . (buttonWidth * 0) . " y" . (25 + 5) " w" . buttonWidth . " h25 gLogout", Logout

        Gui, DevMode%guiID%:Show, x%x4% y%y4% w250 h100, % "Dev Mode" session.get("winTitle")

    }
    catch e {
        CreateStatusMessage("Failed to create button GUI. " . e.Message,,,, false)
    }
}

screenshotscript:
    if (rec_Active) {
        rawDelay := A_TickCount - rec_LastTime
        delay := (rawDelay > 0) ? rawDelay // botConfig.get("Delay") : 0
        rec_SuspendCapture := true
        CreateStatusMessage("Recording: Capture`nYou could deside what to do with it later.")
        rec_LastScreenGrab := ""
        Screenshot_dev()
        rec_SuspendCapture := false
        if (rec_LastScreenGrab != "") {
            rec_Actions.Push({type: "screenshot"
                , fileName:       rec_LastScreenGrab.fileName
                , needlePath:     rec_LastScreenGrab.needlePath
                , screenshot:     rec_LastScreenGrab.screenshot
                , x1: rec_LastScreenGrab.x1, y1: rec_LastScreenGrab.y1
                , x2: rec_LastScreenGrab.x2, y2: rec_LastScreenGrab.y2
                , x3: rec_LastScreenGrab.x3, y3: rec_LastScreenGrab.y3
                , delay: delay, screenshot: rec_LastScreenGrab.needlePath
                , comment: "", code: "", choice: ""})
            rec_LastTime := A_TickCount
            CreateStatusMessage("Recording: Image captured")
        } else {
            CreateStatusMessage("")
        }
    } else {
        Screenshot_dev()
    }
return

Logout:
     closePTCGPApp()
     adbWriteRaw("rm /data/data/jp.pokemon.pokemontcgp/shared_prefs/deviceAccount:.xml")
     startPTCGPApp()
return

bboxScript:
    ToggleBBox()
return

ToggleBBox() {
    session.set("dbg_bbox", !session.get("dbg_bbox"))
}

bboxNpauseScript:
    TogglebboxNpause()
return

TogglebboxNpause() {
    session.set("dbg_bboxNpause", !session.get("dbg_bboxNpause"))
}

bboxDraw(X1, Y1, X2, Y2, color) {
    global session

    WinGetPos, xwin, ywin, Width, Height, % "ahk_id " . getMuMuHwnd(session.get("winTitle"))
    BoxWidth := X2-X1
    BoxHeight := Y2-Y1
    ; Create a GUI
    guiSuffix := session.get("winTitle")
    Gui, BoundingBox%guiSuffix%:+AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, BoundingBox%guiSuffix%:Color, 123456
    Gui, BoundingBox%guiSuffix%:+LastFound  ; Make the GUI window the last found window for use by the line below. (straght from documentation)
    WinSet, TransColor, 123456 ; Makes that specific color transparent in the gui

    ; Create the borders and show
    Gui, BoundingBox%guiSuffix%:Add, Progress, x0 y0 w%BoxWidth% h2 %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x0 y0 w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%BoxWidth% y0 w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x0 y%BoxHeight% w%BoxWidth% h2 %color%

    xshow := X1+xwin
    yshow := Y1+ywin
    Gui, BoundingBox%guiSuffix%:Show, x%xshow% y%yshow% NoActivate
    Sleep, 100

}

bboxDraw2(X1, Y1, X2, Y2, color) {
    global session

    WinGetPos, xwin, ywin, Width, Height, % session.get("winTitle")
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
    guiSuffix := session.get("winTitle")
    Gui, BoundingBox%guiSuffix%:+AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, BoundingBox%guiSuffix%:Color, 123456
    Gui, BoundingBox%guiSuffix%:+LastFound  ; Make the GUI window the last found window for use by the line below. (straght from documentation)
    WinSet, TransColor, 123456 ; Makes that specific color transparent in the gui

    ; Create the borders and show
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xm1% y%Ym1% w%BoxWidth% h2 %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xm1% y%Ym1% w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xh1% y%Ym1% w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xm1% y%Yh1% w%BoxWidth% h2 %color%

    ; Create the borders and show
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xm2% y%Ym2% w%BoxWidth% h2 %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xm2% y%Ym2% w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xh2% y%Ym2% w2 h%BoxHeight% %color%
    Gui, BoundingBox%guiSuffix%:Add, Progress, x%Xm2% y%Yh2% w%BoxWidth% h2 %color%

    xshow := xwin
    yshow := ywin
    Gui, BoundingBox%guiSuffix%:Show, x%xshow% y%yshow% NoActivate
    Sleep, 100

}

adbSwipe_wbb(params) {
    global session
    
    if(session.get("dbg_bbox"))
        bboxAndPause_swipe(params, session.get("dbg_bboxNpause"))
    adbSwipe(params)
}

bboxAndPause_swipe(params, doPause := False) {
    global session

    guiSuffix := session.get("winTitle")
    paramsplit := StrSplit(params , " ")
    X1:=round(paramsplit[1] / 535 * 283)
    Y1:=round((paramsplit[2] / 960 * 488) + 40)
    X2:=round(paramsplit[3] / 535 * 283)
    Y2:=round((paramsplit[4] / 960 * 488) + 40)
    speed:=paramsplit[5]
    CreateStatusMessage("Swiping (" . X1 . "," . Y1 . ") to (" . X2 . "," . Y2 . ") speed " . speed,,,, false)

    color := "BackgroundYellow"

    ;bboxDraw2(X1, Y1, X2, Y2, color)

    bboxDraw(X1-5, Y1-5, X1+5, Y1+5, color)
    if (doPause) {
        Pause
    }
    Gui, BoundingBox%guiSuffix%:Destroy

    bboxDraw(X2-5, Y2-5, X2+5, Y2+5, color)
    if (doPause) {
        Pause
    }
    Gui, BoundingBox%guiSuffix%:Destroy
}

adbClick_wbb(X,Y)  {
    global session

    if(session.get("dbg_bbox"))
        bboxAndPause_click(X, Y, session.get("dbg_bboxNpause"))
    adbClick(X,Y)
}

bboxAndPause_click(X, Y, doPause := False) {
    global session
    
    guiSuffix := session.get("winTitle")
    CreateStatusMessage("Clicking X " . X . " Y " . Y,,,, false)

    color := "BackgroundBlue"

    bboxDraw(X-5, Y-5, X+5, Y+5, color)

    if (doPause) {
        Pause
    }

    if GetKeyState("F4", "P") {
        Pause
    }
    Gui, BoundingBox%guiSuffix%:Destroy
}

bboxAndPause_immage(X1, Y1, X2, Y2, pNeedleObj, vret := False, doPause := False) {
    global session
    
    guiSuffix := session.get("winTitle")
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
    Gui, BoundingBox%guiSuffix%:Destroy
}

Gdip_ImageSearch_wbb(pBitmapHaystack,pNeedle,ByRef OutputList=""
    ,OuterX1=0,OuterY1=0,OuterX2=0,OuterY2=0,Variation=0,Trans=""
    ,SearchDirection=1,Instances=1,LineDelim="`n",CoordDelim=",") {
    global session

    vret := Gdip_ImageSearch(pBitmapHaystack,pNeedle.needle,OutputList,OuterX1,OuterY1,OuterX2,OuterY2,Variation,Trans,SearchDirection,Instances,LineDelim,CoordDelim)
    if(session.get("dbg_bbox"))
        bboxAndPause_immage(OuterX1, OuterY1, OuterX2, OuterY2, pNeedle, vret, session.get("dbg_bboxNpause"))
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
}

DoTutorial() {
    global botConfig, session

    FindImageAndClick("Create_CountryComboBoxButton", 143, 370) ;select month and year and click

    Delay(3)
    adbClick_wbb(80, 400)
    Delay(3)
    adbClick_wbb(80, 375)
    Delay(3)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0

    Loop {
        Delay(3)
        if(FindImageAndClick("Create_SelectedYear", , , , , 1, failSafeTime))
            break
        Delay(3)
        adbClick_wbb(142, 159)
        Delay(3)
        adbClick_wbb(80, 400)
        Delay(3)
        adbClick_wbb(80, 375)
        Delay(3)
        adbClick_wbb(82, 422)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Year`n(" . failSafeTime . "/45 seconds)")
    } ;select month and year and click

    adbClick_wbb(200, 400)
    Delay(3)
    adbClick_wbb(200, 375)
    Delay(3)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop { ;select month and year and click
        Delay(3)
        if(FindImageAndClick("Create_SelectedMonth", , , , , 1, failSafeTime))
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
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Month`n(" . failSafeTime . "/45 seconds)")
    } ;select month and year and click

    Delay(3)
    FindImageAndClick("Create_BirthConfirmCancelButton", 140, 474, , 1000)

    ;wait date confirmation screen while clicking ok

    FindImageAndClick("Create_TosOpenButton", 203, 371, , 1000) ;wait to be at the tos screen while confirming birth

    FindImageAndClick("Create_TosCloseButton", 139, 299, , 1000) ;wait for tos while clicking it

    FindImageAndClick("Create_TosOpenButton", 142, 486, , 1000) ;wait to be at the tos screen and click x

    FindImageAndClick("Common_PopupXButtonInMain", 142, 339, , 1000) ;wait to be at the tos screen

    FindImageAndClick("Create_TosOpenButton", 142, 486, , 1000) ;wait to be at the tos screen, click X

    Delay(3)
    adbClick_wbb(261, 374)

    Delay(3)
    adbClick_wbb(261, 406)

    Delay(3)
    adbClick_wbb(145, 484)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        if(FindImageAndClick("Create_BeginNewAccountButton", 145, 484, , , 2, failSafeTime)) ;wait to be at create save data screen while clicking
            break
        Delay(1)
        adbClick_wbb(261, 406)
        if(FindImageAndClick("Create_BeginNewAccountButton", 145, 484, , , 2, failSafeTime)) ;wait to be at create save data screen while clicking
            break
        Delay(1)
        adbClick_wbb(261, 374)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Save`n(" . failSafeTime . "/45 seconds)")
    }

    Delay(1)

    adbClick_wbb(143, 348)

    Delay(1)

    FindImageAndClick("Create_NintendoLink") ;wait for link account screen%
    Delay(1)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        if(FindOrLoseImage("Create_NintendoLink", 0, failSafeTime)){
            adbClick_wbb(140, 460)
            Loop {
                Delay(1)
                if(FindOrLoseImage("Create_NintendoLink", 1, failSafeTime)){
                    adbClick_wbb(140, 380) ; click ok on the interrupted while opening pack prompt
                    break
                }
                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            }
        } else if(FindOrLoseImage("Create_DownloadAlertWindow", 0, failSafeTime)){
            adbClick_wbb(203, 364)
        } else if(FindOrLoseImage("Create_DownloadComplete", 0, failSafeTime)){
            adbClick_wbb(140, 370)
        } else if(FindOrLoseImage("Create_CinematicBackground", 0, failSafeTime)){
            break
        }
        Delay(1)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
    }

    if(session.get("setSpeed") = 3){
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod1x", 21, 172)
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }

    FindImageAndClick("Create_WelcomePopup", 253, 506, , 110) ;click through cutscene until welcome page

    if(session.get("setSpeed") = 3){
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod3x", 187, 172)
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    FindImageAndClick("Create_NameInputIcon", 189, 438) ;wait for name input screen
    FindImageAndClick("Create_DeactivatedOKButton", 139, 257) ;wait for name input screen

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        if (botConfig.get("AccountName") != "ERROR" && botConfig.get("AccountName") != "") {
            Random, randomNum, 1, 500 ; Generate random number from 1 to 500
            username := botConfig.get("AccountName") . "-" . randomNum
            username := SubStr(username, 1, 14)  ; max character limit
            if(botConfig.get("verboseLogging"))
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
            if(botConfig.get("verboseLogging"))
                LogToFile("Using random username: " . username)
        }

        adbInput(username)
        Delay(1)
        if(FindImageAndClick("Create_PackReturnButtonIcon", 185, 372, , , 10))
            break
        adbClick_wbb(90, 370)
        Delay(1)
        adbClick_wbb(139, 254) ; 139 254 194 372
        Delay(1)
        adbClick_wbb(139, 254)
        Delay(1)
        EraseInput() ; incase the random pokemon is not accepted
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("In failsafe for Trace. " . failSafeTime . "/45 seconds")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at name")
    }

    Delay(1)

    adbClick_wbb(140, 424)

    FindImageAndClick("Pack_ReadyForOpenPack", 140, 424) ;wait for pack to be ready  to trace
    if(session.get("setSpeed") > 1) {
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod1x", 21, 172) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if(FindOrLoseImage("Pack_ReadyForOpenPack", 1, failSafeTime)){
            if(session.get("setSpeed") > 1) {
                if(session.get("setSpeed") = 3) {
                    FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000)
                    FindImageAndClick("Common_SpeedMod3x", 187, 172) ; click 3x
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
    }

    FindImageAndClick("Create_SwipeForRegisterDexIcon", 140, 375) ;click through cards until needing to swipe up
    if(session.get("setSpeed") > 1) {
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod1x", 21, 172)
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbSwipe_wbb("266 770 266 355 60")
        Sleep, 100
        if(FindOrLoseImage("Create_ConfirmRegisteredCard", 0, failSafeTime)){
            if(session.get("setSpeed") > 1) {
                FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
                if(session.get("setSpeed") = 3)
                    FindImageAndClick("Common_SpeedMod3x", 187, 172)
                else
                    FindImageAndClick("Common_SpeedMod2x", 106, 173) 
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for swipe up for " . failSafeTime . "/45 seconds")
        Delay(1)
    }

    Delay(1)
    adbClick_wbb(204, 371)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(137, 365)
        Delay(1)
        adbClick_wbb(137, 480)
        Delay(1)
        if(FindOrLoseImage("Create_MustClickMissionBackground", 0, failSafeTime)){
            break
        } else if(FindOrLoseImage("Create_DownloadAlertWindow", 0, failSafeTime)){
            adbClick_wbb(203, 364)
        }
    }

    Delay(1)
    adbClick_wbb(247, 472)

    FindImageAndClick("Create_TutorialDexMission", 247, 472, , 5000) ; click through missions until missions is open

    Delay(1)
    adbClick_wbb(141, 294)
    Delay(1)
    adbClick_wbb(141, 294)
    Delay(1)
    FindImageAndClick("Create_TutorialDexMissionComplete", 141, 294, , 1000) ; wait for register screen
    Delay(6)
    adbClick_wbb(140, 500)

    FindImageAndClick("Create_ConfirmDexMissionComplete") ; wait for mission complete screen

    FindImageAndClick("Create_MustClickMissionBackground", 143, 360) ;wait for for missions to be clickable

    FindImageAndClick("Create_TutorialPackOpenNotifyIcon", 145, 194) ;click on packs. stop at booster pack tutorial

    Delay(3)
    adbClick_wbb(142, 436)
    Delay(3)
    adbClick_wbb(142, 436)
    Delay(3)
    adbClick_wbb(142, 436)
    Delay(3)
    adbClick_wbb(142, 436)

    FindImageAndClick("Pack_ReadyForOpenPack", 239, 497) ;wait for pack to be ready  to Trace
    if(session.get("setSpeed") > 1) {
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod1x", 21, 172) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if(FindOrLoseImage("Pack_ReadyForOpenPack", 1, failSafeTime)){
            if(session.get("setSpeed") > 1) {
                if(session.get("setSpeed") = 3) {
                    FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000)
                    FindImageAndClick("Common_SpeedMod3x", 187, 172)
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
    }

    FindImageAndClick("Pack_ResultAfterOpenPack", 252, 505, 5, 50) ;skip through cards until results opening screen

    FindImageAndClick("Pack_SkipButtonAfterOpenPack", 146, 496) ;click on next until skip button appears

    FindImageAndClick("Pack_NextButtonAfterOpenPack", 239, 497, , , 2)

    FindImageAndClick("Create_UnlockedWonerPickIconInLevelUp", 146, 494) ;click on next until skip button appearsstop at hourglasses tutorial

    Delay(3)

    adbClick_wbb(140, 358)

    FindImageAndClick("Common_ShopButtonInMain", 146, 444) ;click until at main menu

    ; New needle & search region 11.1.2025 kevinnnn
    FindImageAndClick("Create_CardImageInTutorialWPFirstScreen", 79, 411)

    FindImageAndClick("Create_WPItemBottomBorder", 190, 437) ; click through tutorial

    Delay(2)

    FindImageAndClick("Create_SelectedWPItem", 202, 347, , 500) ; confirm wonder pick selection

    Delay(2)

    adbClick_wbb(208, 461)

    if(session.get("setSpeed") = 3) ;time the animation
        Sleep, 1500
    else
        Sleep, 2500

    FindImageAndClick("Create_TitleBottomBorderInWPSelectCard", 208, 461, 10, 350) ;stop at pick a card

    Delay(1)

    adbClick_wbb(187, 345)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        if(session.get("setSpeed") = 3)
            continueTime := 1
        else
            continueTime := 3

        if(FindOrLoseImage("Pack_SkipButtonAfterOpenPack", 0, failSafeTime)) {
            adbClick_wbb(239, 497)
        } else if(FindOrLoseImage("Create_WelcomePopup", 0, failSafeTime)) { ;click through to end of tut screen
            break
        } else if(FindOrLoseImage("Pack_NextButtonAfterOpenPack", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage("Next2", 0, failSafeTime)) {
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
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for End`n(" . failSafeTime . "/45 seconds)")
    }

    FindImageAndClick("Create_FullFreepackInMainCenter", 192, 449) ;click until at main menu

    return true
}

SelectPack(HG := false) {
    global session

    ; define constants
    mapPackX := {"Left":60, "Middle":140, "Right":215}
    mainScreenPackCoords := {"MegaBlaziken":mapPackX["Left"], "Parade":mapPackX["Middle"], "CrimsonBlaze":mapPackX["Right"]}

    HomeScreenAllPackY := 203
    PackScreenAllPackY := 320

    packx := getPackCoordXInHome()
    packy := HomeScreenAllPackY
    
    if(HG = "First" && session.get("injectMethod") && session.get("loadedAccount") ){
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            adbClick_wbb(packx, HomeScreenAllPackY)
            Delay(1)
            if(FindOrLoseImage("Pack_PackPointButton", 0, failSafeTime)) {
                break
            }
            else if(!renew && !getFC) {
                if(FindOrLoseImage("Common_AlertForAppCrachDuringOpenPack", 0)) {
                    adbClick_wbb(139, 371)
                }
            }
            else if(FindOrLoseImage("Create_TutorialUseResourceForOpenPack", 0)) {
                ;TODO hourglass tutorial still broken after injection
                Delay(3)
                adbClick_wbb(146, 441)
                Delay(3)
                adbClick_wbb(146, 441)
                Delay(3)
                adbClick_wbb(146, 441)
                Delay(3)

                FindImageAndClick("Create_TutorialPremiumPass", 168, 438, , 500, 5) ;stop at hourglasses tutorial 2
                Delay(1)

                adbClick_wbb(203, 436)
                FindImageAndClick("Create_InfoIconInStandByOpenPack", 180, 436, , 500) ;stop at hourglasses tutorial 2 180 to 203?
            }

            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for Points`n(" . failSafeTime . "/90 seconds)")
        }
    }
    
    FindImageAndClick("Pack_PackPointButton", packx, packy, , 1000)
    
    if(!session.get("isSkipSelectExpansion")) {
        FindImageAndClick("Pack_ScrollInSelectExpansion", 248, 459, , 300)

        ; packs that can be opened after clicking A series
        session.get("packCoordinates")[session.get("openPack")].moveSeriesScreen()
        session.get("packCoordinates")[session.get("openPack")].expansionScreenDrag()

        packx := session.get("packCoordinates")[session.get("openPack")].getXPos()
        packy := session.get("packCoordinates")[session.get("openPack")].getYPos()

        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop{
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Move pack:" . session.get("openPack") . "`n(" . failSafeTime . "/90 seconds)")

            adbClick_wbb(packx, packy)
            Delay(2)
            if(FindOrLoseImage("Pack_ScrollInSelectExpansion", 1, , , 1)) {
                break
            }
        }
        Delay(2)
        session.get("packCoordinates")[session.get("openPack")].additionalAction()
    }

    if(HG = "First" && session.get("injectMethod") && session.get("loadedAccount") && !session.get("accountHasPackInfo")) {
        FindPackStats()
    }

    if(HG = "Tutorial") {
        FindImageAndClick("Create_InfoIconInStandByOpenPack", 180, 436, , 500) ;stop at hourglasses tutorial 2 180 to 203?
    }
    else if(HG = "HGPack") {
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop{
            if (FindOrLoseImage("Pack_PackPointButton", 1)) {
                break
            }
            Delay(1)
            adbClick_wbb(140, 260)  ; Upper pack click
            Delay(1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        }
        Delay(1)

        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage("Pack_HourglassImageAfterOpenPackClick", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage("Pack_HourglassAndPokeGoldImageAfterOpenPackClick", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage("Pack_PokeGoldImageAfterOpenPackClick", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage("Pack_NotEnoughItemsForOpenPack", 0)) {
                session.set("cantOpenMorePacks", 1)
            }
            if(session.get("cantOpenMorePacks"))
                return
            adbClick_wbb(161, 423)
            Delay(1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for HourglassPack3`n(" . failSafeTime . "/45 seconds)")
        }
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage("Pack_HourglassImageAfterOpenPackClick", 1, failSafeTime)) {
                break
            }
            adbClick_wbb(205, 458)
            Delay(1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for HourglassPack4`n(" . failSafeTime . "/45 seconds)")
        }
    } else { 
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop{
            if (FindOrLoseImage("Pack_PackPointButton", 1)) {
                break
            }
            Delay(1)
            adbClick_wbb(140, 260)  ; Upper pack click
            Delay(1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        }
        Delay(1)

        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        failsafeClickExecuted := false  ; Flag to track if failsafe click has been executed
        Loop {
            adbClick_wbb(151, 420)  ; open button
            if(FindOrLoseImage("Pack_AnimationToReadyOpenPack", 0, failSafeTime)) {
                break
            } else if(FindOrLoseImage("Pack_NotEnoughItemsForOpenPack", 0)) {
                session.set("cantOpenMorePacks", 1)
            } else if(FindOrLoseImage("Pack_HourglassImageAfterOpenPackClick", 0, 1) || FindOrLoseImage("Pack_HourglassAndPokeGoldImageAfterOpenPackClick", 0, 1)) {
                adbClick_wbb(205, 458)  ; Handle unexpected HG pack confirmation
            } else if(FindOrLoseImage("Common_AlertForAppCrachDuringOpenPack", 0)) {
                ; Handle restart caused due to network error
                adbClick_wbb(139, 371)
                if (session.get("injectMethod") && session.get("loadedAccount") && session.get("friended")) {
                    IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck
                }
                LogToFile("[" . A_ScriptName . "] Stuck #1 in SelectPack.", "Restart.txt")
                restartGameInstance("Stuck at pack opening")
                return
            } else {
                adbClick_wbb(200, 451)  ; Additional fallback click
            }

            if(session.get("cantOpenMorePacks"))
                return

            Delay(0.1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for Skip2`n(" . failSafeTime . "/45 seconds)")
        }
    }
}

PackOpening() {
    global session

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(146, 434)
        Delay(0.2)
        adbClick_wbb(170, 455)
        if(FindOrLoseImage("Pack_ReadyForOpenPack", 0, failSafeTime)) {
            break ;wait for pack to be ready to Trace and click skip
        } else if(FindOrLoseImage("Pack_NotEnoughItemsForOpenPack", 0)) {
            session.set("cantOpenMorePacks", 1)
        } else if(FindOrLoseImage("Pack_HourglassImageAfterOpenPackClick", 0, 1) || FindOrLoseImage("Pack_HourglassAndPokeGoldImageAfterOpenPackClick", 0, 1)) {
            adbClick_wbb(205, 453) ; handle unexpected no packs available
        } else if(FindOrLoseImage("Pack_GetItemDialogAfterOpenPack", 0)){
            adbInputEvent("111")
            Delay(2)
        } else {
            adbClick_wbb(239, 492)
        }

        ; Execute failsafe click only once after 10 seconds to try to select Floating Pack
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        if (failSafeTime >= 10 && !failsafeClickExecuted) {
            if (FindOrLoseImage("Pack_PackPointButton", 0)) {
                CreateStatusMessage("Trying to click floating pack...")
                Sleep, 3000
                adbClick_wbb(151, 245) ; if pack is floating/glitched
                failsafeClickExecuted := true
            }
        }

        if(session.get("cantOpenMorePacks"))
            return

        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45){
            RemoveFriends()
            if(session.get("injectMethod") && session.get("loadedAccount") && session.get("friended")) {
                IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck
            }
            restartGameInstance("Stuck at Pack")
        }
    }

    if(session.get("setSpeed") > 1) {
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod1x", 21, 172) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if (FindOrLoseImage("Pack_ReadyForOpenPack", 1, failSafeTime)){
            if(session.get("setSpeed") > 1) {
                if(session.get("setSpeed") = 3) {
                    FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000)
                    FindImageAndClick("Common_SpeedMod3x", 187, 172)
                }
            }
            adbClick_wbb(51, 292)
            break
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Trace`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
    }

    FindImageAndClick("Pack_ResultAfterOpenPack", 252, 505, 5, 100) ;skip through cards until results opening screen

    CheckPack()

    if(!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum"))
        return

    ;FindImageAndClick("Pack_SkipButtonAfterOpenPack", 146, 494) ;click on next until skip button appears

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        Delay(1)
        if(FindOrLoseImage("Pack_SkipButtonAfterOpenPack", 0, failSafeTime)) {
            adbClick_wbb(247, 500)
        } else if(FindOrLoseImage("Pack_NextButtonAfterOpenPack", 0, failSafeTime)) {
            adbClick_wbb(146, 489) ;146, 494
        } else if(FindOrLoseImage("Next2", 0, failSafeTime)) {
            adbClick_wbb(146, 489) ;146, 494
        } else if(FindOrLoseImage("Pack_BackButtonInSelectPackScreen", 0, failSafeTime)) {
            break
        } else if(FindOrLoseImage("Create_TutorialUseResourceForOpenPack", 0, failSafeTime)) {
            break
        } else {
            adbClick_wbb(146, 489) ;146, 494
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Home`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at Home")
    }
}

HourglassOpening(HG := false, NEIRestart := true) {
    global botConfig, session

    if(!HG) {
        Delay(3)
        adbClick_wbb(146, 441) ; 146 440
        Delay(3)
        adbClick_wbb(146, 441)
        Delay(3)
        adbClick_wbb(146, 441)
        Delay(3)

        FindImageAndClick("Create_TutorialPremiumPass", 168, 430, , 650, 5) ;stop at hourglasses tutorial 2
        Delay(1)

        adbClick_wbb(203, 436) ; 203 436

        if(session.get("packMethod")) {
            AddFriends(true)
            SelectPack("Tutorial")
        }
        else {
            FindImageAndClick("Create_InfoIconInStandByOpenPack", 180, 436, , 500) ;stop at hourglasses tutorial 2 180 to 203?

            if(session.get("cantOpenMorePacks"))
                return
        }
    }
    if(!session.get("packMethod")) {
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage("Pack_HourglassImageAfterOpenPackClick", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage("Pack_HourglassAndPokeGoldImageAfterOpenPackClick", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage("Pack_PokeGoldImageAfterOpenPackClick", 0, failSafeTime)) {
                break
            }else if(FindOrLoseImage("Pack_NotEnoughItemsForOpenPack", 0)) {
                session.set("cantOpenMorePacks", 1)
            }
            if(session.get("cantOpenMorePacks"))
                return

            ; Execute failsafe click only once after 10 seconds to try to click floating pack
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            if (failSafeTime >= 10 && !failsafeClickExecuted) {
                if (FindOrLoseImage("Pack_PackPointButton", 0)) {
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
            adbClick_wbb(146, 434)
            Delay(1)
            CreateStatusMessage("Waiting for HourglassPack`n(" . failSafeTime . "/45 seconds)")
        }
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            if(FindOrLoseImage("Pack_HourglassImageAfterOpenPackClick", 1, failSafeTime)) {
                break
            }
            adbClick_wbb(205, 458)
            Delay(1)
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for HourglassPack2`n(" . failSafeTime . "/45 seconds)")
        }
    }
    Loop {
        adbClick_wbb(146, 434)
        Delay(1)
        adbClick_wbb(170, 455)
        if(FindOrLoseImage("Pack_ReadyForOpenPack", 0, failSafeTime))
            break ;wait for pack to be ready to Trace and click skip
        else
            adbClick_wbb(239, 497)

        if(session.get("cantOpenMorePacks"))
            return

        if(FindOrLoseImage("Common_ShopButtonInMain", 0, failSafeTime)){
            SelectPack("HGPack")
        }

        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Pack`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45) {
            if(session.get("injectMethod") && session.get("loadedAccount") && session.get("friended")) {
                IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck
            }
            restartGameInstance("Stuck at Pack")
        }
    }

    if(session.get("setSpeed") > 1) {
        FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000) 
        FindImageAndClick("Common_SpeedMod1x", 21, 172) 
        Delay(1)
        adbClick_wbb(51, 297)
        Delay(1)
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbSwipe_wbb(adbSwipeParams)
        Sleep, 100
        if (FindOrLoseImage("Pack_ReadyForOpenPack", 1, failSafeTime)){
            if(session.get("setSpeed") > 1) {
                if(session.get("setSpeed") = 3) {
                    FindImageAndClick("Common_SpeedModMenuButton", 18, 109, , 2000)
                    FindImageAndClick("Common_SpeedMod3x", 187, 172)
                }
            }
            adbClick_wbb(51, 297)
            break
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Trace`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
    }

    FindImageAndClick("Pack_ResultAfterOpenPack", 252, 505, 5, 100) ;skip through cards until results opening screen

    CheckPack()

    if(!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum"))
        return

    ;FindImageAndClick("Pack_SkipButtonAfterOpenPack", 146, 494) ;click on next until skip button appears

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        Delay(1)
        if(FindOrLoseImage("Pack_SkipButtonAfterOpenPack", 0, failSafeTime)) {
            adbClick_wbb(239, 497)
        } else if(FindOrLoseImage("Pack_NextButtonAfterOpenPack", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage("Next2", 0, failSafeTime)) {
            adbClick_wbb(146, 494) ;146, 494
        } else if(FindOrLoseImage("Pack_BackButtonInSelectPackScreen", 0, failSafeTime)) {
            break
        } else {
            adbClick_wbb(146, 494) ;146, 494
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for ConfirmPack`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at ConfirmPack")
    }
}

DoWonderPickOnly() {
    global session

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(80, 390) ; first wonderpick slot
        adbClick_wbb(80, 460) ; backup, second wonderpick slot
        if(FindOrLoseImage("WonderPick_NoEnergy", 0, failSafeTime)) {
            Sleep, 2000
            CreateStatusMessage("No WonderPick Energy left!",,,, false)
            Sleep, 2000
            adbClick_wbb(137, 505)
            Sleep, 2000
            adbClick_wbb(35, 515)
            Sleep, 4000
            return
        }
        if(FindOrLoseImage("WonderPick_WonderPickButtonInHome", 1, failSafeTime)) {
            if(FindOrLoseImage("WonderPick_EnergyStatusAfterSelect", 0, failSafeTime)){
                adbClick_wbb(198, 456)
                Delay(3)
            }
            if(FindOrLoseImage("WonderPick_SelectCards", 0, failSafeTime))
                break
        }
        Delay(1)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for WonderPick`n(" . failSafeTime . "/45 seconds)")
    }
    Sleep, 300
    if(botConfig.get("slowMotion"))
        Sleep, 3000
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(183, 350) ; click card
        if(FindOrLoseImage("WonderPick_SelectCards", 1, failSafeTime)) {
            break
        }
        Delay(1)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Card`n(" . failSafeTime . "/45 seconds)")
    }
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    ;TODO thanks and wonder pick 5 times for missions
    Loop {
        adbClick_wbb(146, 494)
        Delay(1)
        if(FindOrLoseImage("Pack_SkipButtonAfterOpenPack", 0, failSafeTime) || FindOrLoseImage("WonderPick_WonderPickButtonInHome", 0, failSafeTime))
            break
        if(FindOrLoseImage("WonderPick_SelectCards", 0, failSafeTime)) {
            adbClick_wbb(183, 350) ; click card
        }
        Delay(1)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Shop`n(" . failSafeTime . "/45 seconds)")
    }

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        Delay(1)
        if(FindOrLoseImage("Common_ShopButtonInMain", 0, failSafeTime))
            break
        else if(FindOrLoseImage("Pack_SkipButtonAfterOpenPack", 0, failSafeTime))
            adbClick_wbb(239, 497)
        else if(FindOrLoseImage("WonderPick_SelectCards", 0, failSafeTime)) {
            adbClick_wbb(183, 350) ; click card
        }
        else if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
            Delay(1)
        }
        else
            adbInputEvent("111") ;send ESC
        Delay(4)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Shop`n(" . failSafeTime . "/45 seconds)")
    }
}

DoWonderPick() {
    global session

    FindImageAndClick("Common_ShopButtonInMain", 40, 515) ;click until at main menu

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        if(FindOrLoseImage("WonderPick_WonderPickButtonInHome", 0, failSafeTime))
            break
        else if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
        }
        else
            adbClick_wbb(59, 429)
        Delay(1)
    }

    DoWonderPickOnly()

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick(261, 478)
        Sleep, 1000
        if FindOrLoseImage("Mission_ActivatedBeginnerMissionTabButton", 0, failSafeTime)
            break
        else if FindOrLoseImage("Mission_GoToDexButtonIcon", 0, failSafeTime)
            break
        else if FindOrLoseImage("Mission_DailyMissionImage", 0, failSafeTime)
            break
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
    }

    ;FindImageAndClick("WPMission", 150, 286, , 1000)
    FindImageAndClick("Mission_FirstWonderpickMissionIconInDetails", 150, 286, , 1000)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        Delay(1)
        adbClick_wbb(139, 424)
        Delay(1)
        clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, failSafeTime, 80)
        if(clickButton) {
            adbClick_wbb(110, 369)
        }
        else if(FindOrLoseImage("Common_ShopButtonInMain", 1, failSafeTime)){
            GoToMain()
            break
        }
        else if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
            Delay(1)
        }
        else
            break
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for WonderPick`n(" . failSafeTime . "/45 seconds)")
    }
    return true
}

SpendAllHourglass() {
    global botConfig, session

    ; GoToMain()
    ; GetAllRewards(false, true)
    GoToMain()

    SelectPack("HGPack")
    if(session.get("cantOpenMorePacks"))
        return

    PackOpening()
    if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
        return

    ; Keep opening packs until we can't anymore
    while (!session.get("cantOpenMorePacks") && (session.get("friendIDs") || botConfig.get("FriendID") != "" || session.get("accountOpenPacks") < session.get("maxAccountPackNum"))) {
        if(session.get("packMethod")) {
            session.set("friendsAdded", AddFriends(true))  ; true parameter removes and re-adds friends
            SelectPack("HGPack")
            if(session.get("cantOpenMorePacks"))
                break
            PackOpening()  ; Use PackOpening since we just selected the pack
        } else {
            HourglassOpening(true)
        }

        if(session.get("cantOpenMorePacks") || (!session.get("friendIDs") && botConfig.get("FriendID") = "" && session.get("accountOpenPacks") >= session.get("maxAccountPackNum")))
            break
    }
}

; For Special Missions 2025
GetEventRewards(frommain := true){
    global session

    isAllEventExpired := true
    missionDirection := "Forward"

    for specialEventName, specialEventObj in session.get("specialEventList") {
        if(!specialEventObj.isExpiredSpecialEvent()){
            isAllEventExpired := false
            break
        }
    }

    if(isAllEventExpired){
        GoToMain()
        return
    }

    if (frommain){
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            adbClick(261, 478)
            Sleep, 1000
            if FindOrLoseImage("Mission_ActivatedBeginnerMissionTabButton", 0, failSafeTime)
                break
            if FindOrLoseImage("Mission_GoToDexButtonIcon", 0, failSafeTime)
                break
            if FindOrLoseImage("Mission_DailyMissionImage", 0, failSafeTime)
                break
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            if (FindOrLoseImage("MissionDeck", 0, failSafeTime)) {
                HandleMissionDeckFailsafe()
                return
            }
            CreateStatusMessage("Moving to Missions...(" . failSafeTime . "/60 seconds)")
        }
    }
    Delay(4)

    isForceMoveToEnd := true
    eventSuccessCount := 0
    eventResult := initEventResult()

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop{
        if (isAllEventGotReward(eventResult))
            break

        if(missionDirection = "Forward"){
            ; Move to Premium
            adbClick_wbb(235, 460)
            Delay(0.1)
            adbClick_wbb(175, 445)
        }
        else if(missionDirection = "Backward"){
            adbClick_wbb(6, 465)
        }
        Delay(1)

        if (isForceMoveToEnd){
            if(FindOrLoseImage("Mission_PremiumLockImage", 0, failSafeTime) || FindOrLoseImage("Mission_ActivatedBeginnerMissionTabButton", 0, failSafeTime)){
                missionDirection := "Backward"
                isForceMoveToEnd := false
                adbClick_wbb(115, 463)
                Delay(1)
            }
        }

        if (!isForceMoveToEnd){
            Delay(6)
            if(FindOrLoseImage("Mission_DailyMissionImage", 0, failSafeTime)){
                missionDirection := "Forward"
                isForceMoveToEnd := true
                continue
            }

            foundEvent := false
            for specialEventName, specialEventObj in session.get("specialEventList") {
                if(specialEventObj.isExpiredSpecialEvent()){
                    eventResult[specialEventName] := true
                    continue
                }

                redBoxCoords := specialEventObj.redBoxCoords
                blueBoxCoords := specialEventObj.redBoxCoords
                
                if (specialEventObj.isExistNeedleInScreen(session.get("winTitle")) = 2){
                    Loop{
                        adbClick_wbb(175, 422)
                        Delay(1)
                        adbClick_wbb(138, 451)
                        Delay(1)

                        if (FindOrLoseImage("Mission_CompleteGotAllClaims", 0, failSafeTime, , true)) {
                            eventResult[specialEventName] := true
                            session.set("failSafe", A_TickCount)
                            foundEvent := true
                            break
                        }
                        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
                        CreateStatusMessage("Get reward event: " . specialEventName . "`n(" . failSafeTime . "/45 seconds)")
                    }
                    Delay(2)
                }

                if(foundEvent)
                    break

                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            }
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Move to premium and Find event`n(" . failSafeTime . "/45 seconds)")
    }
}

GetAllRewards(tomain := true, dailies := false) {
    global session

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick(261, 478)
        Delay(1)
        if FindOrLoseImage("Mission_ActivatedBeginnerMissionTabButton", 0, failSafeTime)
            break
        else if (FindOrLoseImage("Mission_GoToDexButtonIcon", 0, failSafeTime)) {
            Delay(2)
            adbClick(42, 465) ; move to DailyMissions page
            Delay(2)
            break
        }
        else if FindOrLoseImage("Mission_DailyMissionImage", 0, failSafeTime)
            break
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
    }

    Delay(4)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    GotRewards := true
    if(dailies) {
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            adbClick(165, 465)
            Sleep, 500
            if FindOrLoseImage("Mission_DailyMissionImage", 0, failSafeTime)
                break
            else if (FindOrLoseImage("Mission_GoToDexButtonIcon", 0, failSafeTime)) {
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

        if(FindOrLoseImage("Mission_CompleteGotAllClaims", 0, 0)) {
            break
        }
        else if (failSafeTime > 20) {
            GotRewards := false
            break
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
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

GoToMain() {
    global session

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop, {
        if(FindOrLoseImage("Common_CloseAlertWindowInMain", 0, failSafeTime, , true) && FindOrLoseImage("Common_ActivatedHomeInMainMenu", 0, failSafeTime, , true)){
            Loop, {
                adbInputEvent("111") ;send ESC
                Delay(3)

                if(FindOrLoseImage("Common_ShopButtonInMain", 0, failSafeTime))
                    break
            }
            break
        }
        else{
            adbInputEvent("111") ;send ESC
        }

        if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
            Delay(1)
        }

        DelayH(600)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Moving to Main`n(" . failSafeTime . "/45 seconds)")
    }
}

CleanupBeforeExit(){
    allSpecialEventDispose()
    GetGPUMemoryByPDH(-1, true)
}

^e::
    pToken := Gdip_Startup()
    Screenshot_dev()
return
