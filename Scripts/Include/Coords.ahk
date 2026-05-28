class Coordinate{
    startX := 0
    startY := 0
    endX := 0
    endY := 0
    isValid := false

    __New(startX, startY, endX, endY)
    {
        this.startX := startX
        this.startY := startY
        this.endX := endX
        this.endY := endY

        if RegExMatch(this.startX, "^\d+$") && RegExMatch(this.startY, "^\d+$") && RegExMatch(this.endX, "^\d+$") && RegExMatch(this.endY, "^\d+$") {
            this.isValid := true
        }
    }
}

class Needle{
    needleName := ""
    imageName := ""
    coords := ""
    coords100 := ""
    scale125Coords := ""

    __New(needleName, imageName, coords)
    {
        this.needleName := needleName
        this.imageName := imageName
        this.coords := coords
        this.coords100 := coords
    }
}

class NeedlesDict{
    needles := {}

    Add(needleObj)
    {
        this.needles[needleObj.needleName] := needleObj
    }

    Get(needleName){
        needleObj := this.needles[needleName]

        if (GetConfiguredDisplayScale() = 125 && needleObj.scale125Coords)
            needleObj.coords := needleObj.scale125Coords
        else
            needleObj.coords := needleObj.coords100

        return needleObj
    }

    SetScale125(needleName, coords){
        if (!this.needles.HasKey(needleName))
            return

        this.needles[needleName].scale125Coords := coords
    }
}

global needlesDict := new NeedlesDict()

;==============================================================================================================================

; Friend - Main
needlesDict.Add(new Needle("Friend_AddButtonInFriendList", "Add", new Coordinate(235, 104, 253, 124)))
needlesDict.Add(new Needle("Friend_FriendListSubmenu", "Friends", new Coordinate(84, 457, 100, 469)))
needlesDict.Add(new Needle("Friend_FriendRequestsSubMenu", "requests", new Coordinate(97, 447, 104, 471)))
needlesDict.Add(new Needle("Friend_BottomDarkHomeIcon", "Home", new Coordinate(28, 504, 42, 518)))
needlesDict.Add(new Needle("Friend_SocialHubFriendButton", "Friend2", new Coordinate(20, 440, 70, 500)))
needlesDict.Add(new Needle("Friend_ActivatedClearAllButton", "clearAll", new Coordinate(191, 493, 200, 509)))
needlesDict.Add(new Needle("Friend_FriendListEmpty", "empty", new Coordinate(42, 163, 66, 185)))
needlesDict.Add(new Needle("99ko", "99ko", new Coordinate(63, 106, 102, 120)))
needlesDict.Add(new Needle("99en", "99en", new Coordinate(63, 106, 102, 120)))
needlesDict.Add(new Needle("Friend_HamburgerMenuButtonInIntro", "MainHamburgerMenuButton", new Coordinate(241, 68, 258, 84)))

; Friend - Search
needlesDict.Add(new Needle("Friend_SearchFriendButton", "FriendSearchButton", new Coordinate(20, 435, 35, 450)))
needlesDict.Add(new Needle("Friend_SearchFriendWindowCancelButtonCorner", "CloseAlertWindow", new Coordinate(6, 375, 41, 400)))
needlesDict.Add(new Needle("Friend_FriendIDInputReady", "OK2", new Coordinate(0, 466, 35, 500)))
needlesDict.Add(new Needle("Friend_InputFormBlank", "Erase", new Coordinate(15, 495, 68, 515)))
needlesDict.Add(new Needle("Friend_RequestButtonInSearchResult", "Send", new Coordinate(170, 252, 184, 258)))
needlesDict.Add(new Needle("Friend_WithdrawButton", "Withdraw", new Coordinate(169, 247, 249, 253)))
needlesDict.Add(new Needle("Friend_AcceptedButtonInSearchResult", "Accepted", new Coordinate(171, 253, 183, 257)))
needlesDict.Add(new Needle("Friend_RemoveConfirmButtonInSearchResult", "Remove",new Coordinate(143, 357, 152, 374)))
needlesDict.Add(new Needle("Friend_CannotFriendRequest", "CannotFriendRequest", new Coordinate(14, 295, 39, 311)))

; Friend - Details
needlesDict.Add(new Needle("Friend_RemoveConfirmButtonInFriendDetails", "Remove", new Coordinate(143, 357, 152, 374)))
needlesDict.Add(new Needle("Friend_AcceptedButtonInFriendDetails", "Accepted2", new Coordinate(87, 396, 99, 407)))
needlesDict.Add(new Needle("Friend_ReqeustButtonInFriendDetails", "Send2", new Coordinate(80, 395, 94, 409)))

; Friend - Showcase
needlesDict.Add(new Needle("Friend_FriendIDSearchWindow", "FriendIDSearch", new Coordinate(215, 247, 240, 272)))
needlesDict.Add(new Needle("Friend_ShowcaseIDInputFormBlank", "ShowcaseInput", new Coordinate(150, 490, 218, 514)))
needlesDict.Add(new Needle("Friend_CompleteClickShowcaseLike", "ShowcaseLiked", new Coordinate(98, 182, 125, 209)))
needlesDict.Add(new Needle("Friend_CommunityShowcaseMain", "CommunityShowcase", new Coordinate(174, 459, 189, 474)))

; Friend - Approve
needlesDict.Add(new Needle("Friend_AcceptButtonInApproveSubmenu", "Pending", new Coordinate(230, 198, 245, 208)))
needlesDict.Add(new Needle("Friend_DenyButtonInApproveSubmenu", "DeleteFriend", new Coordinate(196, 196, 210, 209)))
needlesDict.Add(new Needle("Friend_RequestAlreadyClosedInApproveSubmenu", "RequestAlreadyClosed", new Coordinate(3, 330, 70, 345)))
needlesDict.Add(new Needle("Friend_DisabledDenyAllRequestButtonInApproveSubmenu", "Accept", new Coordinate(190, 495, 202, 507)))
needlesDict.Add(new Needle("Friend_BlankFriendSlotAreaInApproveSubmenu", "Approve", new Coordinate(177, 450, 190, 468)))
needlesDict.Add(new Needle("FriendLimit", "FriendLimit", new Coordinate(221, 267, 228, 272)))

;==============================================================================================================================

; Wonderpick
needlesDict.Add(new Needle("WonderPick_NoEnergy", "noWPenergy", new Coordinate(82, 422, 93, 434)))
needlesDict.Add(new Needle("WonderPick_WonderPickButtonInHome", "WonderPick", new Coordinate(244, 79, 259, 92)))
needlesDict.Add(new Needle("WonderPick_EnergyStatusAfterSelect", "WonderPickRaminItems", new Coordinate(22, 439, 38, 474)))
needlesDict.Add(new Needle("WonderPick_SelectCards", "Card", new Coordinate(166, 331, 194, 359)))

;==============================================================================================================================

; Shinedust
needlesDict.Add(new Needle("Shinedust_CopySupportIDButtonInSettings", "inHamburgerMenu", new Coordinate(252, 73, 263, 87)))
needlesDict.Add(new Needle("Shinedust_ShinedustInInventorys", "shinedustItems", new Coordinate(26, 183, 43, 199)))
needlesDict.Add(new Needle("Shinedust_CloseButtonInDetailWindow", "wrongItem", new Coordinate(133, 364, 148, 380)))

;==============================================================================================================================

; Receive Gift
needlesDict.Add(new Needle("Gift_ClaimAllButton", "ClaimAll", new Coordinate(170, 434, 216, 447)))
needlesDict.Add(new Needle("Gift_ReceivedWindowRightBorder", "GiftReceiveWindowBorder", new Coordinate(260, 200, 265, 205)))

;==============================================================================================================================

; Common
needlesDict.Add(new Needle("Common_ActivatedSocialInMainMenu", "Social", new Coordinate(128, 509, 141, 520)))
needlesDict.Add(new Needle("Common_CloseAlertWindowInMain", "CloseAlertWindow", new Coordinate(5, 375, 40, 400)))
needlesDict.Add(new Needle("Common_ActivatedHomeInMainMenu", "FogHomeIcon", new Coordinate(24, 499, 44, 522)))
needlesDict.Add(new Needle("Common_PopupXButtonInMain", "Privacy", new Coordinate(130, 473, 145, 488)))
needlesDict.Add(new Needle("Common_ShopButtonInMain", "Shop", new Coordinate(190, 390, 215, 404)))
needlesDict.Add(new Needle("Common_ColorChangeButton", "Button", new Coordinate(95, 350, 195, 530)))
needlesDict.Add(new Needle("Common_LevelUpBackground", "LevelUp", new Coordinate(100, 86, 167, 116)))
needlesDict.Add(new Needle("Common_UnknownButton2", "Button2", new Coordinate(95, 350, 195, 530)))
needlesDict.Add(new Needle("StartupErrorX", "StartupErrorX", new Coordinate(124, 423, 155, 455))) ; ------------------------------ Finding
needlesDict.Add(new Needle("Common_AlertForAppCrachDuringOpenPack", "closeduringpack", new Coordinate(241, 372, 269, 402)))

; Common - Error
needlesDict.Add(new Needle("Common_Error", "Error", new Coordinate(12, 160, 52, 180)))
needlesDict.Add(new Needle("Common_Error_Cache", "Error_Cache", new Coordinate(30, 320, 60, 395)))
needlesDict.Add(new Needle("Common_Error_NoResponse", "NoResponse", new Coordinate(38, 281, 57, 308)))
needlesDict.Add(new Needle("Common_Error_NoResponseDark", "NoResponseDark", new Coordinate(38, 281, 57, 308)))
needlesDict.Add(new Needle("Common_Error_NoBackground_1Button", "Error_NBOneButton", new Coordinate(70, 350, 80, 370)))
needlesDict.Add(new Needle("Common_Error_3ButtonError_Nodata", "Error_3Button", new Coordinate(35, 330, 50, 440)))

; Common - Menu for Speed Mod
needlesDict.Add(new Needle("Common_SpeedModMenuButton", "speedmodMenu", new Coordinate(22, 240, 29, 245)))
needlesDict.Add(new Needle("Common_SpeedMod1x", "One", new Coordinate(18, 159, 23, 166)))
needlesDict.Add(new Needle("Common_SpeedMod2x", "Two", new Coordinate(102, 159, 107, 164)))
needlesDict.Add(new Needle("Common_SpeedMod3x", "Three", new Coordinate(183, 157, 191, 167)))

;==============================================================================================================================

; Profile(for OCR - FindPackStat)
needlesDict.Add(new Needle("Profile_UserNameArrowInSettingMenu", "UserProfile", new Coordinate(239, 124, 248, 138)))
needlesDict.Add(new Needle("Profile_EditNameButtonIcon", "Profile", new Coordinate(209, 272, 225, 287)))
needlesDict.Add(new Needle("Profile_TrophyStandIconInProfile", "trophy", new Coordinate(13, 420, 40, 500)))
needlesDict.Add(new Needle("Profile_ShinedustIconInTrophyDetails", "trophyPage", new Coordinate(122, 370, 161, 385)))

;==============================================================================================================================

; Menu(Working...)
needlesDict.Add(new Needle("Menu_InventoryIconInMenu", "Settings", new Coordinate(97, 265, 115, 282)))
needlesDict.Add(new Needle("Menu_AgreementIconInIntroMenu", "Menu", new Coordinate(29, 132, 43, 139)))
needlesDict.Add(new Needle("Menu_SettingButtonInMenu", "Account", new Coordinate(25, 140, 45, 153)))
needlesDict.Add(new Needle("Menu_RemoveAccountNintendoButtonInMenu", "Account2", new Coordinate(61, 439, 95, 448)))
needlesDict.Add(new Needle("Menu_DeleteConfimButtonStep1", "DeleteAll", new Coordinate(160, 350, 191, 353)))
needlesDict.Add(new Needle("Menu_GoToTitleButton_Up", "GoToTitle", new Coordinate(30, 425, 40, 435)))
needlesDict.Add(new Needle("Menu_GoToTitleButton_Down", "GoToTitle", new Coordinate(30, 466, 40, 476)))
needlesDict.Add(new Needle("Menu_MiscMenuLeftTop", "InSubMenu", new Coordinate(0, 70, 30, 90)))

;==============================================================================================================================

; Pack
needlesDict.Add(new Needle("Pack_PackPointButton", "Points", new Coordinate(238, 406, 247, 416)))
needlesDict.Add(new Needle("Pack_ScrollInSelectExpansion", "SelectExpansion", new Coordinate(119, 138, 157, 146)))
needlesDict.Add(new Needle("Pack_ActivatedBSeriesTab", "ExpansionSeries", new Coordinate(96, 447, 112, 467)))
needlesDict.Add(new Needle("Pack_SkipButtonAfterOpenPack", "Skip", new Coordinate(245, 495, 256, 507)))
needlesDict.Add(new Needle("Pack_ResultAfterOpenPack", "Opening", new Coordinate(175, 96, 267, 115)))
needlesDict.Add(new Needle("Pack_ReadyForOpenPack", "Pack", new Coordinate(198, 271, 202, 282)))
needlesDict.Add(new Needle("Pack_NextButtonAfterOpenPack", "Next", new Coordinate(131, 74, 140, 84)))
needlesDict.Add(new Needle("Next2", "Next2", new Coordinate(131, 74, 140, 84)))  ; ------------------------------ Finding
needlesDict.Add(new Needle("Pack_BackButtonInSelectPackScreen", "ConfirmPack", new Coordinate(127, 462, 137, 475)))
needlesDict.Add(new Needle("Pack_AnimationToReadyOpenPack", "Skip2", new Coordinate(235, 492, 250, 510)))
needlesDict.Add(new Needle("Pack_NotEnoughItemsForOpenPack", "notenoughitems", new Coordinate(92, 294, 115, 312)))
needlesDict.Add(new Needle("Pack_PokeGoldImageAfterOpenPackClick", "PokeGoldPack", new Coordinate(75, 448, 83, 456)))
needlesDict.Add(new Needle("Pack_HourglassImageAfterOpenPackClick", "HourglassPack", new Coordinate(70, 446, 83, 465)))
needlesDict.Add(new Needle("Pack_HourglassAndPokeGoldImageAfterOpenPackClick", "HourGlassAndPokeGoldPack", new Coordinate(49, 444, 65, 469)))
needlesDict.Add(new Needle("Pack_PackImageBlankAreaForLunala", "PackNotExistInSelectPackScreen", new Coordinate(205, 320, 220, 335)))
needlesDict.Add(new Needle("Pack_GetItemDialogAfterOpenPack", "GetItemDialogAfterOpenPackLeftSide", new Coordinate(0, 335, 20, 350)))

;==============================================================================================================================

; Missions
needlesDict.Add(new Needle("Mission_PremiumLockImage", "PremiumLock", new Coordinate(250, 452, 258, 459)))
needlesDict.Add(new Needle("Mission_FirstWonderpickMissionIconInDetails", "FirstMission", new Coordinate(130, 188, 145, 206)))
needlesDict.Add(new Needle("Mission_ActivatedBeginnerMissionTabButton", "Missions", new Coordinate(15, 451, 18, 468)))
needlesDict.Add(new Needle("Mission_ThemeCollectionButtonIcon", "Mission_dino1", new Coordinate(180, 493, 190, 503)))
needlesDict.Add(new Needle("Mission_MissionIconTopAreaInDetails", "Mission_dino2", new Coordinate(130, 160, 150, 180)))
needlesDict.Add(new Needle("Mission_GoToDexButtonIcon", "DexMissions", new Coordinate(18, 210, 30, 222)))
needlesDict.Add(new Needle("Mission_DailyMissionImage", "DailyMissions", new Coordinate(204, 190, 223, 197)))
needlesDict.Add(new Needle("Mission_CompleteGotAllClaims", "GotAllMissions", new Coordinate(257, 417, 271, 428)))
needlesDict.Add(new Needle("MissionDeck", "MissionDeck", new Coordinate(158, 104, 170, 117)))

;==============================================================================================================================

; Create account
needlesDict.Add(new Needle("Create_CountryComboBoxButton", "Country", new Coordinate(107, 392, 119, 400)))
needlesDict.Add(new Needle("Create_SelectedMonth", "Month", new Coordinate(158, 390, 172, 394)))
needlesDict.Add(new Needle("Create_SelectedYear", "Year", new Coordinate(39, 390, 55, 391)))
needlesDict.Add(new Needle("Create_BirthConfirmCancelButton", "Birth", new Coordinate(118, 348, 136, 383)))
needlesDict.Add(new Needle("Create_TosOpenButton", "TosScreen", new Coordinate(226, 281, 239, 309)))
needlesDict.Add(new Needle("Create_TosCloseButton", "Tos", new Coordinate(130, 473, 145, 488)))
needlesDict.Add(new Needle("Create_BeginNewAccountButton", "Save", new Coordinate(36, 332, 41, 353)))
needlesDict.Add(new Needle("Create_NintendoLink", "Link", new Coordinate(65, 340, 91, 347)))
needlesDict.Add(new Needle("Create_DownloadAlertWindow", "Confirm", new Coordinate(118, 347, 135, 384)))
needlesDict.Add(new Needle("Create_DownloadComplete", "Complete", new Coordinate(215, 369, 233, 397)))
needlesDict.Add(new Needle("Create_CinematicBackground", "Cinematic", new Coordinate(0, 40, 7, 47)))
needlesDict.Add(new Needle("Create_WelcomePopup", "Welcome", new Coordinate(72, 234, 125, 239)))
needlesDict.Add(new Needle("Create_NameInputIcon", "Name", new Coordinate(190, 241, 209, 257)))
needlesDict.Add(new Needle("Create_DeactivatedOKButton", "OK", new Coordinate(0, 455, 30, 500)))
needlesDict.Add(new Needle("Create_PackReturnButtonIcon", "Return", new Coordinate(127, 501, 147, 509)))
needlesDict.Add(new Needle("Create_SwipeForRegisterDexIcon", "Swipe", new Coordinate(45, 100, 55, 107)))
needlesDict.Add(new Needle("Create_ConfirmRegisteredCard", "SwipeUp", new Coordinate(126, 69, 146, 89)))
needlesDict.Add(new Needle("Create_MustClickMissionBackground", "Gray", new Coordinate(56, 374, 86, 382)))
needlesDict.Add(new Needle("Create_TutorialDexMission", "Pokeball", new Coordinate(122, 97, 146, 128)))
needlesDict.Add(new Needle("Create_TutorialDexMissionComplete", "Register", new Coordinate(124, 167, 151, 201)))
needlesDict.Add(new Needle("Create_ConfirmDexMissionComplete", "Mission", new Coordinate(117, 260, 151, 284)))
needlesDict.Add(new Needle("Create_TutorialPackOpenNotifyIcon", "Notifications", new Coordinate(187, 162, 210, 181)))
needlesDict.Add(new Needle("Create_UnlockedWonerPickIconInLevelUp", "Wonder", new Coordinate(55, 278, 71, 296)))
needlesDict.Add(new Needle("Create_CardImageInTutorialWPFirstScreen", "Wonder2", new Coordinate(75, 151, 83, 162)))
needlesDict.Add(new Needle("Create_WPItemBottomBorder", "Wonder3", new Coordinate(120, 428, 156, 434)))
needlesDict.Add(new Needle("Create_SelectedWPItem", "Wonder4", new Coordinate(166, 295, 179, 309)))
needlesDict.Add(new Needle("Create_TutorialUseResourceForOpenPack", "Hourglass", new Coordinate(188, 200, 225, 270)))
needlesDict.Add(new Needle("Create_TutorialPremiumPass", "Hourglass1", new Coordinate(99, 181, 139, 215)))
needlesDict.Add(new Needle("Create_InfoIconInStandByOpenPack", "Hourglass2", new Coordinate(240, 197, 262, 218)))
needlesDict.Add(new Needle("Create_TitleBottomBorderInWPSelectCard", "Pick", new Coordinate(65, 128, 198, 133)))
needlesDict.Add(new Needle("Create_SoloBattleMissionIconInDetail", "1solobattlemission", new Coordinate(108, 135, 177, 163)))
needlesDict.Add(new Needle("Create_FullFreepackInMainCenter", "Main", new Coordinate(123, 314, 135, 323)))

;==============================================================================================================================

; GP Test
needlesDict.Add(new Needle("GPTest_FriendedInSearcResult", "Accepted", new Coordinate(171, 253, 183, 257)))
needlesDict.Add(new Needle("GPTest_NotFavouriteInDetails", "FavouriteN", new Coordinate(245, 68, 260, 84)))
needlesDict.Add(new Needle("GPTest_FavouritedInDetails", "FavouriteY", new Coordinate(244, 68, 262, 83)))
needlesDict.Add(new Needle("GPTest_AccountNotFound", "GPTest_NotFound", new Coordinate(211, 320, 245, 344)))
needlesDict.Add(new Needle("GPTest_ReqeustCancelButtonInSearchResult", "PendingFriendRequest", new Coordinate(188, 238, 221, 269)))
needlesDict.Add(new Needle("GPTest_FriendRequestButtonInUserDetails", "FavouriteFriend2", new Coordinate(84, 392, 98, 405)))

; Do not use
;needlesDict.Add(new Needle("CountrySelect", )
;needlesDict.Add(new Needle("CountrySelect2", )

; Unknown
;Proceed

;==============================================================================================================================
; Scale 125 coordinate overrides from the last Scale 125 release (v9.5.9).
; Default coordinates above remain the Scale 100 profile.

needlesDict.SetScale125("Create_SoloBattleMissionIconInDetail", new Coordinate(108, 180, 177, 208))
needlesDict.SetScale125("Friend_DisabledDenyAllRequestButtonInApproveSubmenu", new Coordinate(186, 496, 206, 518))
needlesDict.SetScale125("Menu_SettingButtonInMenu", new Coordinate(24, 158, 57, 189))
needlesDict.SetScale125("Menu_RemoveAccountNintendoButtonInMenu", new Coordinate(56, 435, 108, 460))
needlesDict.SetScale125("Friend_AddButtonInFriendList", new Coordinate(226, 100, 270, 135))
needlesDict.SetScale125("Friend_SearchFriendButton", new Coordinate(10, 433, 45, 460))
needlesDict.SetScale125("Friend_SearchFriendWindowCancelButtonCorner", new Coordinate(0, 375, 70, 430))
needlesDict.SetScale125("Friend_BlankFriendSlotAreaInApproveSubmenu", new Coordinate(170, 450, 195, 480))
needlesDict.SetScale125("Create_BirthConfirmCancelButton", new Coordinate(116, 352, 138, 389))
needlesDict.SetScale125("Common_UnknownButton2", new Coordinate(75, 340, 195, 530))
needlesDict.SetScale125("Common_ColorChangeButton", new Coordinate(100, 367, 190, 480))
needlesDict.SetScale125("WonderPick_SelectCards", new Coordinate(160, 330, 200, 370))
needlesDict.SetScale125("Create_CinematicBackground", new Coordinate(0, 46, 20, 70))
needlesDict.SetScale125("Common_AlertForAppCrachDuringOpenPack", new Coordinate(241, 377, 269, 407))
needlesDict.SetScale125("Create_DownloadComplete", new Coordinate(215, 371, 264, 418))
needlesDict.SetScale125("Create_DownloadAlertWindow", new Coordinate(110, 350, 150, 404))
needlesDict.SetScale125("Pack_BackButtonInSelectPackScreen", new Coordinate(121, 465, 140, 485))
needlesDict.SetScale125("Create_CountryComboBoxButton", new Coordinate(105, 396, 121, 406))
needlesDict.SetScale125("Mission_DailyMissionImage", new Coordinate(204, 195, 223, 202))
needlesDict.SetScale125("Mission_GoToDexButtonIcon", new Coordinate(18, 215, 30, 227))
needlesDict.SetScale125("MissionDeck", new Coordinate(150, 96, 180, 130))
needlesDict.SetScale125("GPTest_FriendRequestButtonInUserDetails", new Coordinate(84, 397, 98, 410))
needlesDict.SetScale125("GPTest_NotFavouriteInDetails", new Coordinate(245, 73, 260, 89))
needlesDict.SetScale125("GPTest_FavouritedInDetails", new Coordinate(244, 73, 262, 88))
needlesDict.SetScale125("Mission_FirstWonderpickMissionIconInDetails", new Coordinate(120, 185, 150, 215))
needlesDict.SetScale125("Mission_CompleteGotAllClaims", new Coordinate(244, 406, 273, 449))
needlesDict.SetScale125("Create_MustClickMissionBackground", new Coordinate(46, 368, 103, 411))
needlesDict.SetScale125("Friend_BottomDarkHomeIcon", new Coordinate(20, 500, 55, 530))
needlesDict.SetScale125("Create_TutorialUseResourceForOpenPack", new Coordinate(178, 193, 251, 282))
needlesDict.SetScale125("Create_TutorialPremiumPass", new Coordinate(98, 184, 151, 224))
needlesDict.SetScale125("Create_InfoIconInStandByOpenPack", new Coordinate(236, 198, 266, 226))
needlesDict.SetScale125("Pack_HourglassImageAfterOpenPackClick", new Coordinate(60, 440, 90, 480))
needlesDict.SetScale125("Create_NintendoLink", new Coordinate(51, 335, 107, 359))
needlesDict.SetScale125("Create_FullFreepackInMainCenter", new Coordinate(120, 316, 143, 335))
needlesDict.SetScale125("Menu_AgreementIconInIntroMenu", new Coordinate(20, 120, 50, 150))
needlesDict.SetScale125("Create_ConfirmDexMissionComplete", new Coordinate(115, 255, 176, 308))
needlesDict.SetScale125("Mission_ThemeCollectionButtonIcon", new Coordinate(180, 498, 190, 508))
needlesDict.SetScale125("Mission_MissionIconTopAreaInDetails", new Coordinate(136, 158, 156, 190))
needlesDict.SetScale125("Mission_ActivatedBeginnerMissionTabButton", new Coordinate(15, 456, 18, 473))
needlesDict.SetScale125("Create_SelectedMonth", new Coordinate(100, 386, 138, 416))
needlesDict.SetScale125("Create_NameInputIcon", new Coordinate(190, 241, 225, 270))
needlesDict.SetScale125("Pack_NextButtonAfterOpenPack", new Coordinate(120, 70, 150, 100))
needlesDict.SetScale125("Next2", new Coordinate(120, 70, 150, 100))
needlesDict.SetScale125("Pack_NotEnoughItemsForOpenPack", new Coordinate(92, 299, 115, 317))
needlesDict.SetScale125("Create_TutorialPackOpenNotifyIcon", new Coordinate(170, 160, 220, 200))
needlesDict.SetScale125("WonderPick_NoEnergy", new Coordinate(37, 424, 57, 446))
needlesDict.SetScale125("WonderPick_EnergyStatusAfterSelect", new Coordinate(20, 440, 45, 485))
needlesDict.SetScale125("Create_DeactivatedOKButton", new Coordinate(0, 476, 40, 502))
needlesDict.SetScale125("Friend_FriendIDInputReady", new Coordinate(0, 475, 25, 495))
needlesDict.SetScale125("Common_SpeedMod1x", new Coordinate(20, 170, 24, 174))
needlesDict.SetScale125("Pack_ResultAfterOpenPack", new Coordinate(170, 98, 270, 125))
needlesDict.SetScale125("Pack_ReadyForOpenPack", new Coordinate(198, 273, 207, 287))
needlesDict.SetScale125("Friend_AcceptButtonInApproveSubmenu", new Coordinate(225, 195, 250, 215))
needlesDict.SetScale125("FriendLimit", new Coordinate(215, 260, 235, 280))
needlesDict.SetScale125("GPTest_ReqeustCancelButtonInSearchResult", new Coordinate(188, 243, 221, 274))
needlesDict.SetScale125("Create_TitleBottomBorderInWPSelectCard", new Coordinate(60, 130, 202, 142))
needlesDict.SetScale125("Pack_PackPointButton", new Coordinate(233, 400, 264, 428))
needlesDict.SetScale125("Create_TutorialDexMission", new Coordinate(115, 97, 174, 150))
needlesDict.SetScale125("Pack_PokeGoldImageAfterOpenPackClick", new Coordinate(60, 440, 90, 480))
needlesDict.SetScale125("Common_PopupXButtonInMain", new Coordinate(129, 477, 156, 494))
needlesDict.SetScale125("Profile_EditNameButtonIcon", new Coordinate(203, 272, 237, 300))
needlesDict.SetScale125("Create_TutorialDexMissionComplete", new Coordinate(124, 168, 162, 207))
needlesDict.SetScale125("Friend_RemoveConfirmButtonInFriendDetails", new Coordinate(135, 355, 160, 385))
needlesDict.SetScale125("Friend_RemoveConfirmButtonInSearchResult", new Coordinate(135, 355, 160, 385))
needlesDict.SetScale125("Create_PackReturnButtonIcon", new Coordinate(121, 490, 161, 520))
needlesDict.SetScale125("Create_BeginNewAccountButton", new Coordinate(30, 336, 53, 370))
needlesDict.SetScale125("Pack_ScrollInSelectExpansion", new Coordinate(115, 140, 160, 155))
needlesDict.SetScale125("Friend_RequestButtonInSearchResult", new Coordinate(165, 245, 190, 270))
needlesDict.SetScale125("Friend_ReqeustButtonInFriendDetails", new Coordinate(70, 395, 100, 420))
needlesDict.SetScale125("Menu_InventoryIconInMenu", new Coordinate(90, 260, 126, 290))
; Group reroll rate-limit recovery opens the menu and returns to title.
; Keep managed needle names shared; legacy Scale125 images are only used by
; ResolveNeedlePath() for documented pixel-sensitive fallback exceptions.
needlesDict.SetScale125("Menu_GoToTitleButton_Up", new Coordinate(20, 418, 55, 447))
needlesDict.SetScale125("Menu_GoToTitleButton_Down", new Coordinate(20, 458, 60, 488))
needlesDict.SetScale125("Menu_MiscMenuLeftTop", new Coordinate(0, 65, 45, 105))
needlesDict.SetScale125("Common_ShopButtonInMain", new Coordinate(191, 393, 211, 411))
needlesDict.SetScale125("Common_CloseAlertWindowInMain", new Coordinate(0, 350, 70, 430))
needlesDict.SetScale125("Common_ActivatedHomeInMainMenu", new Coordinate(20, 490, 60, 530))
needlesDict.SetScale125("Pack_ActivatedBSeriesTab", new Coordinate(15, 450, 130, 482))
needlesDict.SetScale125("Pack_SkipButtonAfterOpenPack", new Coordinate(233, 486, 272, 519))
needlesDict.SetScale125("Pack_AnimationToReadyOpenPack", new Coordinate(233, 486, 272, 519))
needlesDict.SetScale125("Common_ActivatedSocialInMainMenu", new Coordinate(120, 500, 155, 530))
needlesDict.SetScale125("Common_SpeedModMenuButton", new Coordinate(158, 252, 177, 259))
needlesDict.SetScale125("Create_SwipeForRegisterDexIcon", new Coordinate(34, 99, 74, 131))
needlesDict.SetScale125("Create_ConfirmRegisteredCard", new Coordinate(133, 72, 141, 78))
needlesDict.SetScale125("Common_SpeedMod3x", new Coordinate(187, 168, 191, 174))
needlesDict.SetScale125("Create_TosCloseButton", new Coordinate(129, 477, 156, 494))
needlesDict.SetScale125("Create_TosOpenButton", new Coordinate(210, 285, 250, 315))
needlesDict.SetScale125("Common_SpeedMod2x", new Coordinate(102, 170, 107, 174))
needlesDict.SetScale125("Create_WelcomePopup", new Coordinate(110, 230, 182, 257))
needlesDict.SetScale125("Create_UnlockedWonerPickIconInLevelUp", new Coordinate(53, 281, 86, 310))
needlesDict.SetScale125("Create_CardImageInTutorialWPFirstScreen", new Coordinate(75, 156, 83, 167))
needlesDict.SetScale125("Create_WPItemBottomBorder", new Coordinate(114, 430, 155, 441))
needlesDict.SetScale125("Create_SelectedWPItem", new Coordinate(155, 281, 192, 315))
needlesDict.SetScale125("WonderPick_WonderPickButtonInHome", new Coordinate(240, 80, 265, 100))
needlesDict.SetScale125("Create_SelectedYear", new Coordinate(148, 384, 256, 419))

; Additional Scale 125 overrides audited from v9.5.9 raw image-search calls.
needlesDict.SetScale125("Friend_FriendListSubmenu", new Coordinate(84, 463, 100, 475))
needlesDict.SetScale125("Friend_FriendRequestsSubMenu", new Coordinate(97, 452, 104, 476))
needlesDict.SetScale125("Friend_SocialHubFriendButton", new Coordinate(20, 450, 70, 500))
needlesDict.SetScale125("Friend_ActivatedClearAllButton", new Coordinate(191, 498, 207, 514))
needlesDict.SetScale125("Friend_FriendListEmpty", new Coordinate(42, 163, 66, 185))
needlesDict.SetScale125("Friend_InputFormBlank", new Coordinate(15, 500, 68, 520))
needlesDict.SetScale125("Friend_WithdrawButton", new Coordinate(165, 240, 255, 270))
needlesDict.SetScale125("Friend_AcceptedButtonInSearchResult", new Coordinate(165, 250, 190, 275))
needlesDict.SetScale125("Friend_AcceptedButtonInFriendDetails", new Coordinate(87, 401, 99, 412))
needlesDict.SetScale125("Friend_DenyButtonInApproveSubmenu", new Coordinate(196, 196, 210, 209))
needlesDict.SetScale125("Friend_FriendIDSearchWindow", new Coordinate(215, 252, 240, 277))
needlesDict.SetScale125("Friend_ShowcaseIDInputFormBlank", new Coordinate(157, 498, 225, 522))
needlesDict.SetScale125("Friend_CompleteClickShowcaseLike", new Coordinate(98, 187, 125, 214))
needlesDict.SetScale125("Friend_CommunityShowcaseMain", new Coordinate(174, 464, 189, 479))
needlesDict.SetScale125("Common_Error", new Coordinate(100, 180, 170, 230))
needlesDict.SetScale125("Common_LevelUpBackground", new Coordinate(100, 86, 167, 116))
needlesDict.SetScale125("StartupErrorX", new Coordinate(124, 423, 155, 455))
needlesDict.SetScale125("Profile_UserNameArrowInSettingMenu", new Coordinate(230, 120, 260, 150))
needlesDict.SetScale125("Profile_ShinedustIconInTrophyDetails", new Coordinate(122, 375, 161, 390))
needlesDict.SetScale125("Shinedust_CopySupportIDButtonInSettings", new Coordinate(252, 78, 263, 92))
needlesDict.SetScale125("Shinedust_ShinedustInInventorys", new Coordinate(26, 188, 43, 204))
needlesDict.SetScale125("Shinedust_CloseButtonInDetailWindow", new Coordinate(133, 369, 148, 385))
needlesDict.SetScale125("Menu_DeleteConfimButtonStep1", new Coordinate(200, 340, 250, 530))
needlesDict.SetScale125("Pack_HourglassAndPokeGoldImageAfterOpenPackClick", new Coordinate(49, 449, 70, 474))
needlesDict.SetScale125("Pack_PackImageBlankAreaForLunala", new Coordinate(58, 303, 74, 319))
needlesDict.SetScale125("Mission_PremiumLockImage", new Coordinate(225, 444, 272, 470))
needlesDict.SetScale125("GPTest_FriendedInSearcResult", new Coordinate(165, 250, 190, 275))
needlesDict.SetScale125("GPTest_AccountNotFound", new Coordinate(211, 320, 245, 344))

; Scale 125 audit remains for these needles because v9.5.9 has no direct
; equivalent, or the current image name did not exist in the old asset set:
; 99ko, 99en, Common_Error_Cache, Common_Error_NoResponse,
; Common_Error_NoResponseDark, Common_Error_NoBackground_1Button,
; Common_Error_3ButtonError_Nodata, Friend_CannotFriendRequest,
; Friend_HamburgerMenuButtonInIntro, Friend_RequestAlreadyClosedInApproveSubmenu,
; Gift_ClaimAllButton, Gift_ReceivedWindowRightBorder,
; Pack_GetItemDialogAfterOpenPack,
; Profile_TrophyStandIconInProfile, CountrySelect, CountrySelect2.
