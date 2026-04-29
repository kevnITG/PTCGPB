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

    __New(needleName, imageName, coords)
    {
        this.needleName := needleName
        this.imageName := imageName
        this.coords := coords
    }
}

class NeedlesDict{
    needles := {}

    Add(needleObj)
    {
        this.needles[needleObj.needleName] := needleObj
    }

    Get(needleName){
        return this.needles[needleName]
    }
}

global needlesDict := new NeedlesDict()

;==============================================================================================================================

; Friend - Main
needlesDict.Add(new Needle("Friend_AddButtonInFriendList", "Add", new Coordinate(235, 104, 253, 124)))
needlesDict.Add(new Needle("Friend_FriendListSubmenu", "Friends", new Coordinate(84, 457, 100, 469)))
needlesDict.Add(new Needle("Friend_FriendRequestsSubMenu", "requests", new Coordinate(97, 447, 104, 471)))
needlesDict.Add(new Needle("Friend_BottomDarkHomeIcon", "Home", new Coordinate(28, 504, 42, 518)))
needlesDict.Add(new Needle("Friend_ActivatedClearAllButton", "clearAll", new Coordinate(191, 493, 200, 509)))
needlesDict.Add(new Needle("Friend_FriendListEmpty", "empty", new Coordinate(42, 163, 66, 185)))
needlesDict.Add(new Needle("99ko", "99ko", new Coordinate(63, 106, 102, 120)))
needlesDict.Add(new Needle("99en", "99en", new Coordinate(63, 106, 102, 120)))
needlesDict.Add(new Needle("Friend_HamburgerMenuButtonInIntro", "MainHamburgerMenuButton", new Coordinate(241, 68, 258, 84)))

; Friend - Search
needlesDict.Add(new Needle("Friend_SearchFriendButton", "FriendSearchButton", new Coordinate(20, 435, 35, 450)))
needlesDict.Add(new Needle("Friend_SearchFriendWindowCancelButtonCorner", "CloseAlertWindow", new Coordinate(6, 375, 41, 400)))
needlesDict.Add(new Needle("Friend_FriendIDInputReady", "OK2", new Coordinate(0, 476, 25, 496)))
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
needlesDict.Add(new Needle("Create_DeactivatedOKButton", "OK", new Coordinate(0, 473, 19, 484)))
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