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

;-------------------------------------------------------------------------------
; AddFriends - Add friends from friend code list
;-------------------------------------------------------------------------------
AddFriends(renew := false, getFC := false) {
    global botConfig, session, interceptProc

    ; Only allow AddFriends in Inject Wonderpick 96P+ mode
    if (botConfig.get("deleteMethod") != "Inject Wonderpick 96P+")
        return false

    if (botConfig.get("groupRerollEnabled") || botConfig.get("useSoloIdsFile")) {
        session.set("friendIDs", ReadFile("ids"))

        if(!HasVal(session.get("friendIDs"), botConfig.get("FriendID")) && botConfig.get("FriendID") != "")
            session.get("friendIDs").Push(botConfig.get("FriendID"))
    } else {
        session.set("friendIDs", false)
    }
	if(!getFC && !session.get("friendIDs") && botConfig.get("FriendID") = "")
		return false

    session.set("friended", true)

    session.set("failSafe", A_TickCount)
    failSafeTime := 0
    Loop {
        adbClick_wbb(143, 518)
        if(FindOrLoseImage("Common_ActivatedSocialInMainMenu", 0, failSafeTime)) {
            break
        }
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
        CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
    }
    
    GoToFriendsList(true)

    if(getFC) {
        Delay(3)
        adbClick_wbb(210, 342)
        Delay(3)
        session.set("friendCode", Clipboard)
        return session.get("friendCode")
    }
    else {
        IniWrite, 1, % session.get("scriptIniFile"), UserSettings, DeadCheck
    }

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

    GoToFriendsList()
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
        GoToFriendsList(true)
        FindImageAndClick("Friend_SearchFriendWindowCancelButtonCorner", 75, 440)
        FindImageAndClick("Friend_FriendIDInputReady", 138, 265)
    }
    else if(prevAction = "CLEARALL"){
        GoToFriendsList()
        FindImageAndClick("Friend_FriendRequestsSubMenu", 167, 467, , 10)
    }
    else if(prevAction = "REMOVE"){
        GoToFriendsList()
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
        LogToFile("Processing showcase ID: " . showcaseID, "ShowcaseLog.txt")
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

GoToFriendsList(isKeepSearch := false) {
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
            ; For Tutorial Window
            adbClick_wbb(170, 438)
        }
        Delay(0.25)
        failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
        CreateStatusMessage("Goto friends screen`n(" . failSafeTime . "/45 seconds)")
    }
}

;-------------------------------------------------------------------------------
; getFriendCode - Get friend code from current account
;-------------------------------------------------------------------------------
getFriendCode() {
    global session

    CreateStatusMessage("Getting friend code...",,,, false)
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
    session.set("friendCode", AddFriends(false, true))

    return session.get("friendCode")
}