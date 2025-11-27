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
    global FriendID, friendIds, waitTime, friendCode, scriptName, friended, packsThisRun
    global scaleParam

    friendIDs := ReadFile("ids")
    friended := true
	if(!getFC && !friendIDs && friendID = "")
		return false

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick_wbb(143, 518)
        if(FindOrLoseImage(120, 500, 155, 530, , "Social", 0, failSafeTime)) {
            break
        }
        else if(!renew && !getFC) {
            Delay(3)
            clickButton := FindOrLoseImage(75, 360, 195, 410, 75, "Button", 0)
            if(clickButton) {
                StringSplit, pos, clickButton, `,  ; Split at ", "
                if (scaleParam = 287) {
                    pos2 += 5
                }
                adbClick_wbb(pos1, pos2)
            }
        }
        else if(FindOrLoseImage(175, 165, 255, 235, , "Hourglass3", 0)) {
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
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
    }
    IniRead, showcaseNumber, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseLikes
    IniRead, showcaseEnabled, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseEnabled
    if (showcaseNumber > 0 && showcaseEnabled = 1 && packsThisRun = 0) {
        showcaseNumber -= 1
        IniWrite, %showcaseNumber%, %A_ScriptDir%\..\Settings.ini, UserSettings, showcaseLikes
        showcaseLikes()
        FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518, 500)
    }

    FindImageAndClick(226, 100, 270, 135, , "Add", 38, 460, 500)
    FindImageAndClick(205, 430, 255, 475, , "Search", 240, 120, 1500)
    if(getFC) {
        Delay(3)
        adbClick_wbb(210, 342)
        Delay(3)
        friendCode := Clipboard
        return friendCode
    }
    else {
        IniWrite, 1, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
    }

    ; start adding friends
    if(!friendIDs)
        friendIDs := [friendID]  ; Use an array to hold the single friend ID
    FindImageAndClick(0, 475, 25, 495, , "OK2", 138, 454)

    ;randomize friend id list to not back up mains if running in groups since they'll be sent in a random order.
    n := friendIDs.MaxIndex()
    Loop % n
    {
        i := n - A_Index + 1
        Random, j, 1, %i%
        ; Force string assignment with quotes
        temp := friendIDs[i] . ""  ; Concatenation ensures string type
        friendIDs[i] := friendIDs[j] . ""
        friendIDs[j] := temp . ""
    }
    for index, value in friendIDs {
        if (StrLen(value) != 16) {
            ; Wrong id value
            continue
        }
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            adbInput(value)
            Delay(1)
            if(FindOrLoseImage(205, 430, 255, 475, , "Search2", 0, failSafeTime)) {
                break
            }
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for AddFriends3`n(" . failSafeTime . "/45 seconds)")
        }
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            adbClick_wbb(232, 453)
            if(FindOrLoseImage(165, 250, 190, 275, , "Send", 0, failSafeTime)) {
                Delay(1) ; otherwise it will sometimes click before UI finishes loading
                adbClick_wbb(243, 258)
                ; adbClick_wbb(243, 258)
                ; adbClick_wbb(243, 258)
                break
            }
            else if(FindOrLoseImage(165, 240, 255, 270, , "Withdraw", 0, failSafeTime)) {
                break
            }
            else if(FindOrLoseImage(165, 250, 190, 275, , "Accepted", 0, failSafeTime)) {
                if(renew){
                    FindImageAndClick(135, 355, 160, 385, , "Remove", 193, 258)
                    FindImageAndClick(165, 250, 190, 275, , "Send", 200, 372)
                    Delay(1) ; otherwise it will sometimes click before UI finishes loading
                    adbClick_wbb(243, 258)
                    ; adbClick_wbb(243, 258)
                    ; adbClick_wbb(243, 258)
                }
                break
            }
            Delay(1)
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for AddFriends4`n(" . failSafeTime . "/45 seconds)")
        }
        if(index != friendIDs.maxIndex()) {
            FindImageAndClick(205, 430, 255, 475, , "Search2", 143, 518)
            EraseInput(index, n)
        }
    }

    FindImageAndClick(120, 500, 155, 530, , "Social", 143, 518, 500)

    FindImageAndClick(20, 500, 55, 530, , "Home", 40, 516, 500)

    Loop %waitTime% {
        CreateStatusMessage("Waiting for friends to accept request`n(" . A_Index . "/" . waitTime . " seconds)")
        sleep, 1000
    }
    return n ;return added friends so we can dynamically update the .txt in the middle of a run without leaving friends at the end
}

;-------------------------------------------------------------------------------
; RemoveFriends - Remove all friends from account
;-------------------------------------------------------------------------------
RemoveFriends() {
    global friendIDs, friended, friendID, packsInPool, scriptName, stopToggle, scaleParam
	friendIDs := ReadFile("ids")

    if(!friendIDs && friendID = "") {
        friended := false
        return false
    }

    packsInPool := 0 ; if friends are removed, clear the pool

    CreateStatusMessage("Starting friend removal process...",,,, false)

    failSafe := A_TickCount
    failSafeTime := 0
    Loop {
        adbClick_wbb(143, 518)
        if(FindOrLoseImage(120, 500, 155, 530, , "Social", 0, failSafeTime))
            break
        else if(FindOrLoseImage(175, 165, 255, 235, , "Hourglass3", 0)) {
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
        } else if(!renew && !getFC && DeadCheck = 1) {
            clickButton := FindOrLoseImage(75, 340, 195, 530, 80, "Button", 0)
            if(clickButton) {
                StringSplit, pos, clickButton, `,  ; Split at ", "
                if (scaleParam = 287) {
                    pos2 += 5
                }
                adbClick_wbb(pos1, pos2)
                }
            }
        Sleep, 500
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Social`n(" . failSafeTime . "/90 seconds)")
    }

    FindImageAndClick(226, 100, 270, 135, , "Add", 38, 460)
    Delay(2)
    FindImageAndClick(97, 452, 104, 476, 10, "requests", 167, 472)
    Delay(2)
    adbClick(167, 472) ; extra click since failing to get into requests sometimes
    failSafe := A_TickCount
    failSafeTime := 0
    Loop{
        if (FindOrLoseImage(191, 498, 207, 514, , "clearAll", 0, failSafeTime))
            break
        adbClick(205, 510)
        Delay(1)
        if (FindOrLoseImage(135, 355, 160, 385, , "Remove", 0, failSafeTime))
            adbClick(210, 372)
        Delay(1)
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for clearAll`n(" . failSafeTime . "/45 seconds)")
    }
    FindImageAndClick(84, 463, 100, 475, 10, "Friends", 22, 464)
    friendsProcessed := 0
    finished := false
    accepted := false
    Loop {
        failSafe := A_TickCount
        failSafeTime := 0
        Loop {
            adbClick(58, 190)
            Delay(1)
            if(FindOrLoseImage(87, 401, 99, 412, , "Accepted2", 0, failSafeTime)){
                accepted := true
                break
            }
            else if(FindOrLoseImage(84, 463, 100, 475, 10, "Friends", 0, failSafeTime)) {
                if(FindOrLoseImage(42, 163, 66, 185, 10, "empty", 0, failSafeTime)) {
                    finished := true
                    break
                }
            }
            else if(FindOrLoseImage(70, 395, 100, 420, , "Send2", 0, failSafeTime))
                break
            failSafeTime := (A_TickCount - failSafe) // 1000
            CreateStatusMessage("Waiting for Accepted2`n(" . failSafeTime . "/45 seconds)")
        }
        if(finished)
            break
        if(accepted){
            accepted := false
            FindImageAndClick(135, 355, 160, 385, , "Remove", 145, 407)
            FindImageAndClick(70, 395, 100, 420, , "Send2", 200, 372)
        }
        failSafe := A_TickCount
        failSafeTime := 0
        ; Either find "Add" (expected), or if we accidentally went back too many pages to "Social", go back into friends.
        Loop {
            adbClick(143, 507)
            Sleep, 750
            if(FindOrLoseImage(120, 500, 155, 530, , "Social", 0, failSafeTime)) {
                Sleep, 1000
                adbClick(38, 460)
                Sleep, 2000
                break
            }
            else if(FindOrLoseImage(226, 100, 270, 135, , "Add", 0, failSafeTime))
                break
        }
        friendsProcessed++
    }

    ; Exit friend removal process
    CreateStatusMessage("Friend removal completed. Processed " . friendsProcessed . " friends. Returning to main...",,,, false)
	IniWrite, 0, %A_ScriptDir%\%scriptName%.ini, UserSettings, DeadCheck
    friended := false
    CreateStatusMessage("Friends removed successfully!",,,, false)

    if(stopToggle) {
        CreateStatusMessage("Stopping...",,,, false)
        ExitApp
    }
}

;-------------------------------------------------------------------------------
; showcaseLikes - Like community showcases from ID list
;-------------------------------------------------------------------------------
showcaseLikes() {
	; Liking showcase script
    FindImageAndClick(174, 464, 189, 479, , "CommunityShowcase", 152, 335, 200)
	Loop, Read, %A_ScriptDir%\..\showcase_ids.txt
		{
			showcaseID := Trim(A_LoopReadLine)
            Delay(2)
			FindImageAndClick(215, 252, 240, 277, , "FriendIDSearch", 224, 472, 200)
            Delay(2)
			FindImageAndClick(157, 498, 225, 522, , "ShowcaseInput", 143, 273, 200)
			Delay(3)
			adbInput(showcaseID)					; Pasting ID
			Delay(1)
			adbClick(212, 384)						; Pressing OK
			FindImageAndClick(98, 187, 125, 214, ,"ShowcaseLiked", 175, 200, 200)
            Delay(2)
			FindImageAndClick(174, 464, 189, 479, , "CommunityShowcase", 140, 495, 200)
		}
}

;-------------------------------------------------------------------------------
; EraseInput - Clear friend code input field
;-------------------------------------------------------------------------------
EraseInput(num := 0, total := 0) {
    global Delay

    if(num)
        CreateStatusMessage("Removing friend ID " . num . "/" . total,,,, false)

    failSafe := A_TickCount
    failSafeTime := 0

    Loop {
        FindImageAndClick(0, 475, 25, 495, , "OK2", 138, 454)
        adbInputEvent("59 122 67") ; Press Shift + Home + Backspace
        if(FindOrLoseImage(15, 500, 68, 520, , "Erase", 0, failSafeTime))
            break
    }
}

;-------------------------------------------------------------------------------
; TradeTutorial - Handle trade tutorial popup
;-------------------------------------------------------------------------------
TradeTutorial() {
    if(FindOrLoseImage(100, 120, 175, 145, , "Trade", 0)) {
        Loop{
            adbClick_wbb(167, 447)
            Delay(1)
            adbClick_wbb(38, 460)
            Delay(3) ; Add more delay to check for the load & Add2 or Add to appear.
            if(FindOrLoseImage(15, 455, 40, 475, ,"Add2", 0))
                break
            if(FindOrLoseImage(226, 100, 270, 135, ,"Add", 0))
                break
            adbClick_wbb(38, 460)
            Delay(1)
        }

        FindImageAndClick(226, 100, 270, 135, , "Add", 38, 460, 500,,2)
    }
    Delay(1)
}

;-------------------------------------------------------------------------------
; getFriendCode - Get friend code from current account
;-------------------------------------------------------------------------------
getFriendCode() {
    global friendCode
    CreateStatusMessage("Getting friend code...",,,, false)
    Sleep, 2000
    FindImageAndClick(233, 486, 272, 519, , "Skip", 146, 494) ;click on next until skip button appears
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
        } else if(FindOrLoseImage(20, 500, 55, 530, , "Home", 0, failSafeTime)) {
            break
        } else {
            adbclick_wbb(146, 494)
        }
        failSafeTime := (A_TickCount - failSafe) // 1000
        CreateStatusMessage("Waiting for Home`n(" . failSafeTime . "/45 seconds)")
        if(failSafeTime > 45)
            restartGameInstance("Stuck at Home")
    }
    friendCode := AddFriends(false, true)

    return friendCode
}
