;===============================================================================
; FriendManager.ahk - Friend Management Functions
;===============================================================================
; This file contains functions for managing in-game friends.
; These functions handle:
;   - Adding friends by friend code
;   - Removing all friends
;   - Getting friend code from account
;   - Showcase likes
;   - Trade tutorial handling
;   - Friend input field management
;
; Dependencies: ADB.ahk, Utils.ahk (for ReadFile), image recognition
; Used by: Main bot loop for friend management and trading setup
;===============================================================================

; Windows clipboard is global, lock only around clear/click/read (per attempt, ~0.5s).
AccountFriendInfo_AcquireClipboardLock(timeoutMs := 800) {
    lockName := "Global\PTCGPB_FriendCodeClipboard"
    hMutex := DllCall("CreateMutex", "Ptr", 0, "Int", false, "Str", lockName, "Ptr")
    if (!hMutex)
        return 0

    waitResult := DllCall("WaitForSingleObject", "Ptr", hMutex, "UInt", timeoutMs, "UInt")
    if (waitResult != 0 && waitResult != 0x80) {
        DllCall("CloseHandle", "Ptr", hMutex)
        return 0
    }
    return hMutex
}

AccountFriendInfo_ReleaseClipboardLock(hMutex) {
    if (!hMutex)
        return
    DllCall("ReleaseMutex", "Ptr", hMutex)
    DllCall("CloseHandle", "Ptr", hMutex)
}

TryDismissSocialFirstTutorial(failSafeTime := 0) {
    if (failSafeTime < 5 || Mod(failSafeTime, 2) != 0)
        return false

    adbClick_wbb(145, 451)
    Delay(0.2)
    adbClick_wbb(167, 447)
    Delay(0.2)
    adbClick_wbb(38, 460)
    Delay(0.2)
    adbClick_wbb(155, 425)
    Delay(0.2)
    return true
}

TryHandleTradeTutorial(failSafeTime := 0) {
    if (failSafeTime < 6 || Mod(failSafeTime, 2) != 0)
        return false

    if (FindOrLoseImage("Friend_AddButtonInFriendList", 0, , , true))
        return false

    adbClick_wbb(167, 447)
    Delay(0.3)
    adbClick_wbb(38, 460)
    Delay(1)
    adbClick_wbb(38, 460)
    Delay(0.3)

    return true
}

;-------------------------------------------------------------------------------
; AddFriends - Add friends from friend code list
;-------------------------------------------------------------------------------
AddFriends(renew := false, getFC := false) {
    global botConfig, session, interceptProc

    ; Friend adding is Inject Wonderpick-only; own friend-code lookup is allowed wherever the caller explicitly asks for it.
    if (!getFC && botConfig.get("deleteMethod") != "Inject Wonderpick 96P+")
        return false

    if (!getFC && (botConfig.get("groupRerollEnabled") || botConfig.get("useSoloIdsFile"))) {
        friendIDs := ReadFile("ids")
        if (!friendIDs)
            friendIDs := []
        session.set("friendIDs", friendIDs)

        if(!HasVal(session.get("friendIDs"), botConfig.get("FriendID")) && botConfig.get("FriendID") != "")
            session.get("friendIDs").Push(botConfig.get("FriendID"))
    } else if (!getFC) {
        session.set("friendIDs", false)
    }
    friendIDsAvailable := IsObject(session.get("friendIDs")) && session.get("friendIDs").MaxIndex()
    if(!getFC && !friendIDsAvailable && botConfig.get("FriendID") = "")
        return false

    if (!getFC)
        session.set("friended", true)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(143, 518)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime)) {
            break
        }
        else if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
            Delay(1)
        }
        else if(TryHandleTradeTutorial(failSafeTime))
            continue
        else if(TryDismissSocialFirstTutorial(failSafeTime))
            continue
        else if(!renew && !getFC) {
            Delay(3)
            clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, , 80)
            if(clickButton) {
                StringSplit, pos, clickButton, `,  ; Split at ", "
                adbClick_wbb(pos1, pos2)
            }
        }
        else if(FindOrLoseImage("Create_TutorialUseResourceForOpenPack", 0)) {
            Delay(3)
            adbClick_wbb(146, 441) ; 146 440
            Delay(3)
            adbClick_wbb(146, 441)
            Delay(3)
            adbClick_wbb(146, 441)
            Delay(3)

            FindImageAndClick("Create_TutorialPremiumPass", 168, 438, , 500, 5) ;stop at hourglasses tutorial 2
            Delay(1)

            adbClick_wbb(203, 436) ; 203 436
        }
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        if (getFC)
            CreateStatusMessage("Retrieving account info`nOpening Social (" . failSafeTime . "/90 seconds)")
        else
            CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
    }

    GoToFriendsList(true, false)

    if(getFC)
        return AccountFriendInfo_CopyFriendCodeFromCurrentScreen()

    EnsureAccountFriendInfo("Inject Wonderpick 96P+", true)
    IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck

    ; start adding friends
    if(!session.get("friendIDs")){
        session.set("friendIDs", [])
        session.get("friendIDs").Push(botConfig.get("FriendID"))  ; Use an array to hold the single friend ID
    }
    FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 75, 440)
    FindImageAndClick("Friend_FriendIDInputReady", 138, 265)

    ;randomize friend id list to not back up mains if running in groups since they'll be sent in a random order.
    n := session.get("friendIDs").MaxIndex()
    Loop % n
    {
        i := n - A_Index + 1
        Random, j, 1, %i%
        ; Force string assignment with quotes
        temp := session.get("friendIDs")[i] . ""  ; Concatenation ensures string type
        session.get("friendIDs")[i] := session.get("friendIDs")[j] . ""
        session.get("friendIDs")[j] := temp . ""
    }
    friendIDIdx := 1
    while(friendIDIdx <= session.get("friendIDs").maxIndex()){
        value := session.get("friendIDs")[friendIDIdx]

        if (StrLen(value) != 16) {
            ; Wrong id value
            friendIDIdx += 1
            continue
        }
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        Loop {
            isContinue := false
            isSendReqeest := false
            Delay(1)
            adbInput(value)
            Delay(1)
            adbClick_wbb(187, 365)
            Delay(1)
            if(FindOrLoseImage("Friend_RequestButtonInSearchResult", 0, failSafeTime, 80)) {
                adbClick_wbb(243, 258)
                Delay(1)

                waitSendResult := A_TickCount
                interceptProc := true
                Loop{
                    if(!isSendReqeest && FindOrLoseImage("Friend_RequestButtonInSearchResult", 0, failSafeTime) && (A_TickCount - waitSendResult) > 1000){
                        adbClick_wbb(243, 258)
                        isSendReqeest := true
                    }
                    Delay(0.25)
                    if(FindOrLoseImage("Friend_WithdrawButton", 0, failSafeTime))
                        break
                    else if(FindOrLoseImage("Friend_AcceptedButtonInSearchResult", 0, failSafeTime))
                        break
                    else if(interceptErrorCheck("ADD")){
                        isContinue := true
                        break
                    }
                    else if(FindOrLoseImage("Friend_CannotFriendRequest", 0, failSafeTime))
                        break
                    if ((A_TickCount - waitSendResult) > 10000)
                        break
                }
                interceptProc := false
                break
            }
            else if(FindOrLoseImage("Friend_WithdrawButton", 0, failSafeTime))
                break
            else if(FindOrLoseImage("Friend_AcceptedButtonInSearchResult", 0, failSafeTime)) {
                if(renew){
                    FindImageAndClick("Friend_RemoveConfirmButtonInSearchResult", 193, 258)
                    FindImageAndClick("Friend_RequestButtonInSearchResult", 200, 372)
                    Delay(1) ; otherwise it will sometimes click before UI finishes loading
                    adbClick_wbb(243, 258)
                    ; adbClick_wbb(243, 258)
                    ; adbClick_wbb(243, 258)
                }
                break
            }
            else
                adbInputEvent("59 122 67")

            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Processing add friends for `n(" . failSafeTime . "/45 seconds)")
        }

        if(isContinue)
            continue

        if(friendIDIdx != session.get("friendIDs").maxIndex()) {
            FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 143, 518, , 1000)
            FindImageAndClick("Friend_FriendIDInputReady", 138, 265, , 1000)
            EraseInput(friendIDIdx, n)
        }
        friendIDIdx += 1
    }

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop, {
        adbClick_wbb(143, 518)
        Delay(3)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime))
            break
        else if(FindOrLoseImage("Friend_SearchFriendWindowCancelButtonCorner", 0, failSafeTime))
            adbClick_wbb(80, 365)
    }

    ; ratelimit, only use this route when number of added ids is 6-10, 16-20, etc
    if (Mod(n - 1, 10) >= 5) {
        FindImageAndClick("Menu_InventoryIconInMenu", 240, 494)
        FindImageAndClick("Menu_MiscMenuLeftTop", 105, 435, , 750)
        DelayH(600)

        clickX := 137
        clickY := 430
        if(FindOrLoseImage("Menu_GoToTitleButton_Down", 0, , 60))
            clickY := 470

        FindImageAndClick("Create_DownloadAlertWindow", clickX, clickY)

        Loop, {
            adbClick_wbb(197, 365)
            Delay(1)
            if(FindOrLoseImage("Create_DownloadAlertWindow", 1))
                break
        }
        session.set("isReloadAfterAddFriends", true)
    }
    else {
        Loop {
            if(FindOrLoseImage("Friend_BottomDarkHomeIcon", 0))
                break
            else{
                adbClick_wbb(40, 516)
                Delay(0.1)
                adbClick_wbb(175, 445)
                DelayH(500)
            }
        }
        ;FindImageAndClick("Friend_BottomDarkHomeIcon", 40, 516, , 500)

        Loop % botConfig.get("waitTime") {
            CreateStatusMessage("Waiting for friends to accept request`n(" . A_Index . "/" . botConfig.get("waitTime") . " seconds)")
            sleep, 1000
        }
    }
    return n ;return added friends so we can dynamically update the .txt in the middle of a run without leaving friends at the end
}

;-------------------------------------------------------------------------------
; RemoveFriends - Remove all friends from account
;-------------------------------------------------------------------------------
RemoveFriends() {
    global botConfig, session, interceptProc, DeadCheck

    ; Only allow RemoveFriends in Inject Wonderpick 96P+ mode
    if (botConfig.get("deleteMethod") != "Inject Wonderpick 96P+" && !botConfig.get("useSoloIdsFile")) {
        session.set("friended", false)
        return false
    }

    session.set("friendIDs", ReadFile("ids"))

    if(!session.get("friendIDs") && botConfig.get("FriendID") = "") {
        session.set("friended", false)
        return false
    }

    session.set("packsInPool", 0) ; if friends are removed, clear the pool

    CreateStatusMessage("Starting friend removal process...",,,, false)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(143, 518)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime))
            break
        else if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
            Delay(1)
        }
        else if(TryHandleTradeTutorial(failSafeTime))
            continue
        else if(TryDismissSocialFirstTutorial(failSafeTime))
            continue
        else if(FindOrLoseImage("Create_TutorialUseResourceForOpenPack", 0)) {
            Delay(3)
            adbClick_wbb(146, 441) ; 146 440
            Delay(3)
            adbClick_wbb(146, 441)
            Delay(3)
            adbClick_wbb(146, 441)
            Delay(3)

            FindImageAndClick("Create_TutorialPremiumPass", 168, 438, , 500, 5) ;stop at hourglasses tutorial 2
            Delay(1)

            adbClick_wbb(203, 436) ; 203 436
        } else if(!renew && !getFC && DeadCheck = 1) {
            clickButton := FindOrLoseImage("Common_ColorChangeButton", 0, , 80)
            if(clickButton) {
                StringSplit, pos, clickButton, `,  ; Split at ", "
                adbClick_wbb(pos1, pos2)
            }
        }
        Sleep, 500
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
    }

    GoToFriendsList(false, false)
    Delay(2)
    FindImageAndClick("Friend_FriendRequestsSubMenu", 167, 467, , 10)
    Delay(2)
    adbClick(167, 472) ; extra click since failing to get into requests sometimes
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    interceptProc := true
    Loop{
        if (FindOrLoseImage("Friend_ActivatedClearAllButton", 0, failSafeTime))
            break
        adbClick(205, 510)
        Delay(1)
        if (FindOrLoseImage("Friend_RemoveConfirmButtonInFriendDetails", 0, failSafeTime))
            adbClick(210, 372)

        Delay(1)

        isErrorOccurred := interceptErrorCheck("CLEARALL")
        if(isErrorOccurred)
            continue

        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for clearAll`n(" . failSafeTime . "/45 seconds)")
    }
    interceptProc := false
    FindImageAndClick("Friend_FriendListSubmenu", 22, 464, , 10)
    friendsProcessed := 0
    finished := false
    accepted := false
    Loop {
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        accepted := false
        Loop {
            adbClick(58, 190)
            Delay(1)
            if(FindOrLoseImage("Friend_AcceptedButtonInFriendDetails", 0, failSafeTime)){
                accepted := true
                break
            }
            else if(FindOrLoseImage("Friend_FriendListSubmenu", 0, failSafeTime, 10)) {
                if(FindOrLoseImage("Friend_FriendListEmpty", 0, failSafeTime, 10)) {
                    finished := true
                    break
                }
            }
            else if(FindOrLoseImage("Friend_ReqeustButtonInFriendDetails", 0, failSafeTime))
                break
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for Accepted2`n(" . failSafeTime . "/45 seconds)")
        }
        if(finished)
            break
        if(accepted){
            accepted := false

            FindImageAndClick("Friend_RemoveConfirmButtonInFriendDetails", 145, 407)

            interceptProc := true
            isContinue := false
            Loop, {
                adbClick(200, 372)
                Delay(0.5)
                if(FindOrLoseImage("Friend_ReqeustButtonInFriendDetails", 0))
                    break
                else if(interceptErrorCheck("REMOVE")){
                    isContinue := true
                    break
                }
            }
            interceptProc := false
            if(isContinue)
                continue
        }
        session.set("failSafe", A_TickCount)
        failSafeTime := 0
        ; Either find "Add" (expected), or if we accidentally went back too many pages to "Social", go back into friends.
        Loop {
            adbClick(143, 507)
            Sleep, 750
            if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime)) {
                Sleep, 1000
                adbClick(38, 460)
                Sleep, 2000
                break
            }
            else if(FindOrLoseImage("Friend_AddButtonInFriendList", 0, failSafeTime))
                break
        }
        friendsProcessed++
    }

    ; Exit friend removal process
    CreateStatusMessage("Friend removal completed. Processed " . friendsProcessed . " friends. Returning to main...",,,, false)
    IniWrite, 0, % session.get("scriptIniFile"), UserSettings, DeadCheck
    session.set("friended", false)
    CreateStatusMessage("Friends removed successfully!",,,, false)

    if(session.get("stopToggle")) {
        CreateStatusMessage("Stopping...",,,, false)
        ExitApp
    }
}

interceptErrorCheck(actionType){
    global interceptProc

    Delay(1)
    isErrorOccured := FindOrLoseImage("Common_Error", 0)
    if(isErrorOccured){
        adbClick_wbb(137, 380)
        CreateStatusMessage("An error occurred while processing friends. Restarting.`n(" . failSafeTime . "/45 seconds)")
        Delay(1)
        interceptProc := false
        ReEnterSocial(actionType)
    }

    return isErrorOccured
}

ReEnterSocial(prevAction){
    global interceptProc
    reEnterStart := A_TickCount
    Loop {
        adbClick_wbb(143, 518)
        reEnterElapsed := (A_TickCount - reEnterStart) // 1000
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, reEnterElapsed)) {
            break
        }
        else if(FindOrLoseImage("Common_PopupXButtonInMain", 0, , , true)){
            adbClick_wbb(137, 480)
        }
        Delay(0.25)
    }

    if(prevAction = "ADD"){
        GoToFriendsList(true, true)
        FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 75, 440)
        FindImageAndClick("Friend_FriendIDInputReady", 138, 265)
    }
    else if(prevAction = "CLEARALL"){
        GoToFriendsList(false, true)
        FindImageAndClick("Friend_FriendRequestsSubMenu", 167, 467, , 10)
    }
    else if(prevAction = "REMOVE"){
        GoToFriendsList(false, true)
    }
}
;-------------------------------------------------------------------------------
; showcaseLikes
;-------------------------------------------------------------------------------
showcaseLikes() {
    global session

    FindImageAndClick("Friend_CommunityShowcaseMain", 152, 335, , 200)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0

    ; Read the entire file to avoid concurrent access issues
    FileRead, content, %A_ScriptDir%\..\showcase_ids.txt
    ; Remove BOM if present
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    ; Split into lines
    showcaseIDs := StrSplit(content, "`n", "`r")
    ; Trim and filter non-empty
    filteredIDs := []
    for index, line in showcaseIDs {
        trimmed := Trim(line)
        if (trimmed != "")
            filteredIDs.Push(trimmed)
    }

    Loop % filteredIDs.Length()
    {
        showcaseID := filteredIDs[A_Index]
        ; Log for debugging
        LogInfo("Processing showcase ID: " . showcaseID, "ShowcaseLog.txt")
        Delay(2)
        ;TradeTutorialForShowcase()
        ;Delay(2)
        FindImageAndClick("Friend_FriendIDSearchWindow", 224, 467, , 200)
        Delay(2)
        FindImageAndClick("Friend_ShowcaseIDInputFormBlank", 143, 268, , 200)
        Delay(2)
        adbInput(showcaseID)					; Pasting ID
        Delay(2)
        adbClick(200, 364)						; Pressing OK
        Delay(1)
        FindImageAndClick("Friend_CompleteClickShowcaseLike", 160, 195, , 200)
        Delay(4)
        FindImageAndClick("Friend_CommunityShowcaseMain", 138, 500, , 200)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Waiting for Showcase Likes for `n(" . failSafeTime . "/90 seconds)")
    }
}

;-------------------------------------------------------------------------------
; EraseInput - Clear friend code input field
;-------------------------------------------------------------------------------
EraseInput(num := 0, total := 0) {
    global session

    if(num)
        CreateStatusMessage("Removing friend ID " . num . "/" . total,,,, false)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0

    Loop {
        FindImageAndClick("Friend_FriendIDInputReady", 138, 265)
        adbInputEvent("59 122 67") ; Press Shift + Home + Backspace
        if(FindOrLoseImage("Friend_InputFormBlank", 0, failSafeTime))
            break
    }
}

GoToFriendsList(isKeepSearch := false, skipTutorialProc := false) {
    global session

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    mainLoopBreak := false
    Loop {
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime, , true)) {
            ; If main screen(social): Click friends button
            adbClick_wbb(38, 460)
        }
        else if(FindOrLoseImage("Friend_AddButtonInFriendList", 0, failSafeTime, , true)) {
            ; If friends list screen: Click Search button
            adbClick_wbb(240, 120)
            Delay(1)
        }
        else if(FindOrLoseImage("Friend_SearchFriendButton", 0, failSafeTime, , true)) {
            if(!isKeepSearch){
                Loop {
                    if(FindOrLoseImage("Friend_SearchFriendButton", 0, failSafeTime, , true)) {
                        adbInputEvent("111") ;send ESC
                    }
                    else if(FindOrLoseImage("Friend_AddButtonInFriendList", 0, failSafeTime, , true)) {
                        mainLoopBreak := true
                        break
                    }
                    Delay(2)
                }
            }
            else
                break

            if(mainLoopBreak)
                break
        }
        else{
            if(!skipTutorialProc) {
                if(TryHandleTradeTutorial(failSafeTime))
                continue
                else if(!TryDismissSocialFirstTutorial(failSafeTime))
                adbClick_wbb(155, 425)
            }
        }
        Delay(0.25)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Goto friends screen`n(" . failSafeTime . "/45 seconds)")
    }
}

;-------------------------------------------------------------------------------
; getFriendCode - Get friend code from current account
;-------------------------------------------------------------------------------
getFriendCode(alreadyAtHome := false) {
    global session

    CreateStatusMessage("Getting friend code...",,,, false)
    if (!alreadyAtHome) {
        Sleep, 2000
        FindImageAndClick("Pack_SkipButtonAfterOpenPack", 146, 494) ;click on next until skip button appears
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
            } else if(FindOrLoseImage("Friend_BottomDarkHomeIcon", 0, failSafeTime)) {
                break
            } else {
                adbclick_wbb(146, 494)
            }
            failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            CreateStatusMessage("Waiting for Home`n(" . failSafeTime . "/45 seconds)")
            if(failSafeTime > 45)
                restartGameInstance("Stuck at Home")
        }
    }
    session.set("friendCode", AddFriends(false, true))

    return session.get("friendCode")
}

AccountFriendInfo_CopyFriendCodeFromCurrentScreen() {
    global session

    CreateStatusMessage("Retrieving account info`nCopying Friend Code...",,,, false)
    Delay(3)

    friendCode := ""
    copyStartX := 214
    copyY := 202
    copyStepX := 2
    maxCopyAttempts := 10

    ; Try the copy button area from left to right until clipboard yields a valid code.
    Loop, %maxCopyAttempts% {
        CreateStatusMessage("Retrieving account info`nCopying Friend Code (" . A_Index . "/" . maxCopyAttempts . ")")
        clickX := copyStartX + ((A_Index - 1) * copyStepX)

        hLock := AccountFriendInfo_AcquireClipboardLock(800)
        if (!hLock) {
            Sleep, 40
            continue
        }

        Clipboard := ""
        adbClick_wbb(clickX, copyY)
        ClipWait, 0.5
        copiedValue := RegExReplace(Clipboard, "\D", "")
        Clipboard := ""
        AccountFriendInfo_ReleaseClipboardLock(hLock)

        if (RegExMatch(copiedValue, "^\d{16}$")) {
            friendCode := copiedValue
            break
        }
        Sleep, 120
    }
    Delay(1)

    session.set("friendCode", friendCode)
    if (friendCode != "")
        CreateStatusMessage("Retrieving account info`nFriend Code copied",,,, false)
    return session.get("friendCode")
}

;-------------------------------------------------------------------------------
; EnsureAccountFriendInfo - Persist own account name + friend code once per account
;-------------------------------------------------------------------------------
EnsureAccountFriendInfo(methodType := "", alreadyOnFriendSearch := false, force := false) {
    global botConfig, session, DeadCheck

    if (!force && !botConfig.get("saveAccountFriendInfo"))
        return false
    if (DeadCheck = 1)
        return false
    if (methodType = "")
        methodType := botConfig.get("deleteMethod")
    if (methodType = "Create Bots (13P)" && !force)
        return false
    if (!force && (!session.get("injectMethod") || !session.get("loadedAccount")))
        return false

    accountFileName := session.get("accountFileName")
    if (accountFileName = "")
        return false

    deviceAccount := AccountFriendInfo_GetDeviceAccount()
    if (deviceAccount = "")
        return false

    if (session.get("accountFriendInfoChecked") = deviceAccount)
        return false
    session.set("accountFriendInfoChecked", deviceAccount)

    CreateStatusMessage("Retrieving account info`nChecking saved metadata...",,,, false)

    accountSourcePath := session.get("loadedAccount")
    if (accountSourcePath = "" && methodType = "Create Bots (13P)")
        accountSourcePath := A_ScriptDir . "\..\Accounts\Saved\" . session.get("scriptName") . "\" . accountFileName

    accountMeta := AccountMetadata_Get(session.get("scriptName"), accountFileName, accountSourcePath)
    existingName := Trim(accountMeta["accountName"])
    existingFriendCode := RegExReplace(accountMeta["friendCode"], "\D", "")
    if (existingName != "" && existingName != "Unknown" && RegExMatch(existingFriendCode, "^\d{16}$")) {
        session.set("accountName", existingName)
        session.set("friendCode", existingFriendCode)
        return true
    }

    CreateStatusMessage("Retrieving account info`nMissing name or Friend Code",,,, false)

    if (alreadyOnFriendSearch)
        friendCode := AccountFriendInfo_CopyFriendCodeFromCurrentScreen()
    else {
        CreateStatusMessage("Retrieving account info`nGoing to Friends profile...",,,, false)
        friendCode := AddFriends(false, true)
    }

    cleanFriendCode := RegExReplace(friendCode, "\D", "")
    if (!RegExMatch(cleanFriendCode, "^\d{16}$"))
        cleanFriendCode := existingFriendCode

    accountName := AccountFriendInfo_ReadNameFromFriendProfile()
    if (accountName = "" || accountName = "Unknown")
        accountName := existingName

    if (!alreadyOnFriendSearch && methodType != "Create Bots (13P)")
        AccountFriendInfo_ReturnToMain()

    if ((accountName = "" || accountName = "Unknown") && !RegExMatch(cleanFriendCode, "^\d{16}$")) {
        LogWarn("Could not retrieve account friend info for " . accountFileName)
        return false
    }

    accountMeta["deviceAccount"] := deviceAccount
    if (accountName != "" && accountName != "Unknown")
        accountMeta["accountName"] := accountName
    if (RegExMatch(cleanFriendCode, "^\d{16}$"))
        accountMeta["friendCode"] := cleanFriendCode

    CreateStatusMessage("Retrieving account info`nSaving to account JSON...",,,, false)
    saved := AccountMetadata_SaveAccount(session.get("scriptName"), accountFileName, accountMeta)
    if (saved) {
        session.set("accountName", accountMeta["accountName"])
        session.set("friendCode", accountMeta["friendCode"])
        CreateStatusMessage("Retrieving account info`nSaved name and Friend Code",,,, false)
        LogInfo("Saved account friend info for " . accountFileName)
    } else {
        CreateStatusMessage("Retrieving account info`nSave failed",,,, false)
        LogWarn("Failed to save account friend info for " . accountFileName)
    }
    return saved
}

AccountFriendInfo_GetDeviceAccount() {
    global session

    deviceAccount := session.get("deviceAccount")
    if (deviceAccount != "")
        return deviceAccount

    deviceAccount := GetDeviceAccountFromXML()

    if (deviceAccount != "")
        session.set("deviceAccount", deviceAccount)
    return deviceAccount
}

AccountFriendInfo_ReadNameFromFriendProfile(statusPrefix := "Retrieving account info", initialSleepMs := 5000) {
    global session

    CreateStatusMessage(statusPrefix . "`nReading account name...",,,, false)
    if (initialSleepMs > 0)
        Sleep, %initialSleepMs%

    tempDir := A_ScriptDir . "\..\Screenshots\temp"
    if !FileExist(tempDir)
        FileCreateDir, %tempDir%

    usernameScreenshotFile := tempDir . "\" . session.get("scriptName") . "_Username.png"
    CreateStatusMessage(statusPrefix . "`nTaking name screenshot...",,,, false)
    adbTakeScreenshot(usernameScreenshotFile)
    Sleep, 100

    username := ""
    try {
        if (IsFunc("ocr")) {
            CreateStatusMessage(statusPrefix . "`nRunning OCR on name...",,,, false)
            playerName := ""
            allowedUsernameChars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-+_"
            usernamePattern := "[\w-_]+"

            if (RefinedOCRText(usernameScreenshotFile, 145, 235, 250, 35, allowedUsernameChars, usernamePattern, playerName))
                username := playerName
        }
    } catch e {
        LogWarn("Failed to OCR account name: " . e.message, "OCR.txt")
    }

    if (FileExist(usernameScreenshotFile))
        FileDelete, %usernameScreenshotFile%

    return Trim(username)
}

AccountFriendInfo_ReturnToMain() {
    global session

    CreateStatusMessage("Retrieving account info`nReturning Home...",,,, false)
    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop, {
        adbClick_wbb(143, 518)
        Delay(3)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime))
            break
        else if(FindOrLoseImage("Friend_SearchFriendWindowCancelButtonCorner", 0, failSafeTime))
            adbClick_wbb(80, 365)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Retrieving account info`nReturning to Social (" . failSafeTime . "/45 seconds)")
    }

    Loop {
        if(FindOrLoseImage("Friend_BottomDarkHomeIcon", 0))
            break
        else {
            CreateStatusMessage("Retrieving account info`nOpening Home from Social...",,,, false)
            adbClick_wbb(40, 516)
            Delay(0.1)
            adbClick_wbb(175, 445)
            DelayH(500)
        }
    }
    session.set("accountFriendInfoReturnedHome", true)
}
