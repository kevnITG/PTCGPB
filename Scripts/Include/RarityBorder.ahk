global currentPackInfo := {"isVerified": false, "CardSlot": [], "TypeCount": {}}
global rarityCheckers := []

class RarityBorder {
    ; =========================================================
    ; [Static] 기존 영역 검색용 공통 좌표
    ; =========================================================
    static DefaultCommon := { 4: [ new Coordinate(96, 279, 116, 281), new Coordinate(181, 279, 201, 281), new Coordinate(96, 394, 116, 396), new Coordinate(181, 394, 201, 396) ]
                            , 5: [ new Coordinate(56, 279, 76, 281), new Coordinate(139, 279, 159, 281), new Coordinate(222, 279, 242, 281), new Coordinate(96, 394, 116, 396), new Coordinate(181, 394, 201, 396) ] 
                            , 6: [ new Coordinate(56, 279, 76, 281), new Coordinate(139, 279, 159, 281), new Coordinate(222, 279, 242, 281), new Coordinate(56, 394, 76, 396), new Coordinate(139, 394, 159, 396), new Coordinate(222, 394, 242, 396) ] }
    static DefaultCommon125 := { 4: [ new Coordinate(96, 284, 123, 286), new Coordinate(181, 284, 208, 286), new Coordinate(96, 399, 123, 401), new Coordinate(181, 399, 208, 401) ]
                               , 5: [ new Coordinate(56, 284, 83, 286), new Coordinate(139, 284, 166, 286), new Coordinate(222, 284, 249, 286), new Coordinate(96, 399, 123, 401), new Coordinate(181, 399, 208, 401) ]
                               , 6: [ new Coordinate(56, 284, 83, 286), new Coordinate(139, 284, 166, 286), new Coordinate(222, 284, 249, 286), new Coordinate(56, 399, 83, 401), new Coordinate(139, 399, 166, 401), new Coordinate(256, 386, 260, 402) ] }

    ; =========================================================
    ; [Static] MASK 모드용 단일 기준점(좌상단 x, y) 앵커 좌표
    ; =========================================================
    static DefaultMaskAnchors := { 4: [ {x: 57, y: 181}, {x: 142, y: 181}, {x: 57, y: 296}, {x: 142, y: 296} ]
                                 , 5: [ {x: 17, y: 176}, {x: 100, y: 176}, {x: 182, y: 176}, {x: 57, y: 291}, {x: 142, y: 291} ]
                                 , 6: [ {x: 17, y: 176}, {x: 100, y: 176}, {x: 182, y: 176}, {x: 17, y: 291}, {x: 100, y: 291}, {x: 182, y: 291} ] }

    __New(name, basePrefix, searchMode := "COMMON_ONLY") {
        this.RarityName := name
        this.BasePrefix := basePrefix
        this.SearchMode := searchMode
        
        this.AdditionalSets := { 4: [], 5: [], 6: [] }
        this.Scale125AdditionalSets := { 4: [], 5: [], 6: [] }
        this.CommonCoords := RarityBorder.DefaultCommon
        this.CommonCoords125 := RarityBorder.DefaultCommon125
        this.MaskAnchors := RarityBorder.DefaultMaskAnchors
        this.Scale125MaskAnchors := ""
        
        this.ValidPixelSets := []
    }

    LoadMaskReferences(maskFolder) {
        prefix := this.BasePrefix
        
        Loop, Files, %maskFolder%\Mask_%prefix%*.png, F
        {
            pMask := Gdip_CreateBitmapFromFile(A_LoopFileFullPath)
            if (!pMask)
                continue

            Sleep, 20
            
            imgW := Gdip_GetImageWidth(pMask)
            imgH := Gdip_GetImageHeight(pMask)
            
            pixels := []
            Loop, %imgH% {
                Y := A_Index - 1
                Loop, %imgW% {
                    X := A_Index - 1
                    RefColor := Gdip_GetPixel(pMask, X, Y)
                    
                    if (!this.IsMaskColor(RefColor)) {
                        pixels.Push({ "X": X, "Y": Y, "Color": RefColor })
                    }
                }
            }
            Gdip_DisposeImage(pMask)
            
            if (pixels.MaxIndex() > 0)
                this.ValidPixelSets.Push(pixels)
        }
    }

    SetMaskAnchors(anchorsObj) {
        if (!anchorsObj.HasKey(4) || !anchorsObj.HasKey(5) || !anchorsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " Mask Anchors Register failed!"
            return
        }
        this.MaskAnchors := anchorsObj
    }

    SetScale125MaskAnchors(anchorsObj) {
        if (!anchorsObj.HasKey(4) || !anchorsObj.HasKey(5) || !anchorsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " Scale 125 Mask Anchors Register failed!"
            return
        }
        this.Scale125MaskAnchors := anchorsObj
    }

    SetCustomCommon(coordsObj) {
        if (!coordsObj.HasKey(4) || !coordsObj.HasKey(5) || !coordsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " Register failed!"
            return
        }
        this.CommonCoords := coordsObj
    }

    SetScale125Common(coordsObj) {
        if (!coordsObj.HasKey(4) || !coordsObj.HasKey(5) || !coordsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " Scale 125 Register failed!"
            return
        }
        this.CommonCoords125 := coordsObj
    }

    AddAdditionalSet(setPrefix, coordsObj) {
        if (!coordsObj.HasKey(4) || !coordsObj.HasKey(5) || !coordsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " [" setPrefix "] register failed!"
            return
        }
        this.AdditionalSets[4].Push({ Prefix: setPrefix, Coords: coordsObj[4] })
        this.AdditionalSets[5].Push({ Prefix: setPrefix, Coords: coordsObj[5] })
        this.AdditionalSets[6].Push({ Prefix: setPrefix, Coords: coordsObj[6] })
    }

    AddScale125AdditionalSet(setPrefix, coordsObj) {
        if (!coordsObj.HasKey(4) || !coordsObj.HasKey(5) || !coordsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " Scale 125 [" setPrefix "] register failed!"
            return
        }
        this.Scale125AdditionalSets[4].Push({ Prefix: setPrefix, Coords: coordsObj[4] })
        this.Scale125AdditionalSets[5].Push({ Prefix: setPrefix, Coords: coordsObj[5] })
        this.Scale125AdditionalSets[6].Push({ Prefix: setPrefix, Coords: coordsObj[6] })
    }

    Search(pBitmap, cardCount, targetIndex) {
        isScale125 := (GetConfiguredDisplayScale() = 125)
        searchMode := this.SearchMode
        basePrefix := this.BasePrefix

        if (searchMode == "MASK") {
            maskAnchors := this.MaskAnchors
            if (isScale125 && this.Scale125MaskAnchors)
                maskAnchors := this.Scale125MaskAnchors

            anchor := maskAnchors[cardCount][targetIndex]
            return (anchor && anchor.x != "" && this.DoMaskSearch(pBitmap, anchor.x, anchor.y))
        }

        commonCoords := this.CommonCoords
        if (isScale125 && this.CommonCoords125)
            commonCoords := this.CommonCoords125
        commonCoord := commonCoords[cardCount][targetIndex]
        additionalGroups := this.AdditionalSets[cardCount]
        if (isScale125 && this.Scale125AdditionalSets[cardCount].MaxIndex())
            additionalGroups := this.Scale125AdditionalSets[cardCount]

        if (!commonCoord || commonCoord.startX == "")
            return false

        if (searchMode == "COMMON_ONLY") {
            return this.DoSearch(pBitmap, commonCoord, basePrefix, cardCount, targetIndex)
        }
        else if (searchMode == "ALL") {
            if !this.DoSearch(pBitmap, commonCoord, basePrefix, cardCount, targetIndex)
                return false
            
            for i, altSet in additionalGroups {
                altCoord := altSet.Coords[targetIndex]
                if !this.DoSearch(pBitmap, altCoord, altSet.Prefix, cardCount, targetIndex)
                    return false
            }
            return true
        }
        else if (searchMode == "ANY") {
            if this.DoSearch(pBitmap, commonCoord, basePrefix, cardCount, targetIndex)
                return true
            
            for i, altSet in additionalGroups {
                altCoord := altSet.Coords[targetIndex]
                if this.DoSearch(pBitmap, altCoord, altSet.Prefix, cardCount, targetIndex)
                    return true
            }
            return false
        }
    }

    DoSearch(pBitmap, coord, targetPrefix, cardCount := "", targetIndex := "") {
        if (!coord || coord.startX == "")
            return false

        return this.DoPrimarySearch(pBitmap, coord, targetPrefix, cardCount, targetIndex)
    }

    DoPrimarySearch(pBitmap, coord, targetPrefix, cardCount := "", targetIndex := "") {
        imageIdx := 1
        Loop {
            vRet := false
            Path := A_ScriptDir . "\Needles\" . targetPrefix . imageIdx . ".png"
            if(!FileExist(ResolveNeedlePath(Path)))
                break
            
            if (this.SearchNeedlePath(pBitmap, coord, Path, cardCount, targetIndex))
                return true
            else
                imageIdx += 1
        }
        return false
    }

    GetSearchVariation(cardCount := "", targetIndex := "") {
        isScale125 := (GetConfiguredDisplayScale() = 125)

        if (isScale125 && this.RarityName = "normal") {
            if (cardCount = 4)
                return 60

            if (cardCount = 6 && targetIndex >= 4)
                return 60

            return 40
        }

        if (this.RarityName = "normal")
            return 40

        if (cardCount = 6 && targetIndex >= 4)
            return 80

        return 60
    }

    SearchNeedlePath(pBitmap, coord, Path, cardCount := "", targetIndex := "") {
        if(!FileExist(ResolveNeedlePath(Path)))
            return false

        pNeedle := GetNeedle(Path)
        searchVariation := this.GetSearchVariation(cardCount, targetIndex)
        vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coord.startX, coord.startY, coord.endX, coord.endY, searchVariation)
        return (vRet = 1)
    }

    DoMaskSearch(pBitmap, cardX, cardY) {
        vRet := false
        Sleep, 20
        
        lImgW := Gdip_GetImageWidth(pBitmap)
        lImgH := Gdip_GetImageHeight(pBitmap)

        if (lImgW <= 100 && lImgH <= 150) {
            LockX := 0
            LockY := 0
        } else {
            LockX := cardX
            LockY := cardY
        }

        Gdip_LockBits(pBitmap, LockX, LockY, 76, 105, Stride, Scan0, BitmapData)

        for idx, pixelSet in this.ValidPixelSets {
            if (this.CheckSingleMask(Scan0, Stride, pixelSet)) {
                vRet := true
                break
            }
        }

    UnlockAndReturn:
        Gdip_UnlockBits(pBitmap, BitmapData)
        return vRet
    }

    CheckSingleMask(Scan0, Stride, pixelSet) {
        TargetConsecutive := 10
        Variation := 15
        CurrentConsecutive := 0

        for index, pixel in pixelSet {
            CurrentColor := NumGet(Scan0+0, (pixel.X*4) + (pixel.Y*Stride), "UInt")
            
            if (this.ColorMatch(CurrentColor, pixel.Color, Variation)) {
                CurrentConsecutive++
                if (CurrentConsecutive >= TargetConsecutive) {
                    return true
                }
            } else {
                CurrentConsecutive := 0
            }
        }
        return false
    }

    ColorMatch(c1, c2, var) {
        r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
        r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
        return (Abs(r1-r2) <= var && Abs(g1-g2) <= var && Abs(b1-b2) <= var)
    }

    IsMaskColor(c) {
        r := (c >> 16) & 0xFF
        g := (c >> 8) & 0xFF
        b := c & 0xFF
        return (r > 200 && g < 50 && b > 200)
    }
}

; Rarity: "normal", "3diamond", "1star", "trainer", "rainbow", "fullart", "immersive", "crown", "gimmighoul", "ShinyEx", "shiny1star"
borderNormal := new RarityBorder("normal", "normal")
border3Diamond := new RarityBorder("3diamond", "3diamond")
border1Star := new RarityBorder("1star", "1star")
borderTrainer := new RarityBorder("trainer", "trainer")
borderRainbow := new RarityBorder("rainbow", "rainbow")
borderFullArt := new RarityBorder("fullart", "fullart", "MASK")
borderFullArt.LoadMaskReferences(A_ScriptDir . "\Mask")
borderFullArt.SetScale125MaskAnchors({ 4: [ {x: 57, y: 186}, {x: 142, y: 186}, {x: 57, y: 301}, {x: 142, y: 301} ]
                                     , 5: [ {x: 17, y: 181}, {x: 100, y: 181}, {x: 182, y: 181}, {x: 57, y: 301}, {x: 142, y: 301} ]
                                     , 6: [ {x: 17, y: 181}, {x: 100, y: 181}, {x: 182, y: 181}, {x: 17, y: 301}, {x: 100, y: 301}, {x: 182, y: 301} ] })
borderImmersive := new RarityBorder("immersive", "immersive")
borderCrown := new RarityBorder("crown", "crown")
borderGimmighoul := new RarityBorder("gimmighoul", "gimmighoul")
borderShinyEx := new RarityBorder("ShinyEx", "shiny1star", "ALL")
borderShiny1Star := new RarityBorder("shiny1star", "shiny1star")

borderShinyEx.SetCustomCommon({ 4: [ new Coordinate(107, 176, 129, 178)
                                   , new Coordinate(192, 176, 214, 178)
                                   , new Coordinate(107, 291, 129, 293)
                                   , new Coordinate(192, 291, 214, 293) ]
                               , 5: [new Coordinate(67, 176, 89, 178)
                                   , new Coordinate(150, 176, 172, 178)
                                   , new Coordinate(233, 176, 255, 178)
                                   , new Coordinate(107, 291, 129, 293)
                                   , new Coordinate(192, 291, 214, 293) ] 
                               , 6: [new Coordinate(67, 176, 89, 178)
                                   , new Coordinate(150, 176, 172, 178)
                                   , new Coordinate(233, 176, 255, 178)
                                   , new Coordinate(67, 291, 89, 293)
                                   , new Coordinate(150, 291, 172, 293)
                                   , new Coordinate(233, 291, 255, 293) ] })
borderShinyEx.AddAdditionalSet("ShinyEx_ex_", { 4: [ new Coordinate(100, 272, 110, 274)
                                               , new Coordinate(185, 272, 195, 274)
                                               , new Coordinate(100, 387, 110, 389)
                                               , new Coordinate(185, 387, 195, 389) ]
                                          , 5: [ new Coordinate(60, 272, 70, 274)
                                               , new Coordinate(143, 272, 153, 274)
                                               , new Coordinate(225, 272, 235, 274)
                                               , new Coordinate(100, 387, 110, 389)
                                               , new Coordinate(185, 387, 195, 389) ] 
                                          , 6: [ new Coordinate(60, 272, 70, 274)
                                               , new Coordinate(143, 272, 153, 274)
                                               , new Coordinate(225, 272, 235, 274)
                                               , new Coordinate(60, 387, 70, 389)
                                               , new Coordinate(143, 387, 153, 389)
                                               , new Coordinate(225, 387, 235, 389) ] })

borderShinyEx.SetScale125Common({ 4: [ new Coordinate(90, 261, 93, 283)
                                     , new Coordinate(173, 261, 176, 283)
                                     , new Coordinate(130, 376, 133, 398)
                                     , new Coordinate(215, 376, 218, 398) ]
                                 , 5: [ new Coordinate(90, 261, 93, 283)
                                     , new Coordinate(173, 261, 176, 283)
                                     , new Coordinate(255, 261, 258, 283)
                                     , new Coordinate(130, 376, 133, 398)
                                     , new Coordinate(215, 376, 218, 398) ]
                                 , 6: [ new Coordinate(90, 261, 93, 283)
                                     , new Coordinate(173, 261, 176, 283)
                                     , new Coordinate(255, 261, 258, 283)
                                     , new Coordinate(90, 376, 93, 398)
                                     , new Coordinate(173, 376, 176, 398)
                                     , new Coordinate(254, 384, 258, 400) ] })
borderShinyEx.AddScale125AdditionalSet("ShinyEx_ex_", { 4: [ new Coordinate(110, 175, 140, 187)
                                                           , new Coordinate(192, 175, 223, 187)
                                                           , new Coordinate(110, 293, 140, 305)
                                                           , new Coordinate(192, 293, 223, 305) ]
                                                       , 5: [ new Coordinate(74, 175, 97, 187)
                                                           , new Coordinate(153, 175, 180, 187)
                                                           , new Coordinate(237, 175, 262, 187)
                                                           , new Coordinate(110, 293, 140, 305)
                                                           , new Coordinate(192, 293, 223, 305) ]
                                                       , 6: [ new Coordinate(74, 175, 97, 187)
                                                           , new Coordinate(153, 175, 180, 187)
                                                           , new Coordinate(237, 175, 262, 187)
                                                           , new Coordinate(74, 293, 97, 305)
                                                           , new Coordinate(153, 293, 180, 305)
                                                           , new Coordinate(253, 385, 259, 402) ] })

borderShiny1Star.SetScale125Common({ 4: [ new Coordinate(90, 261, 93, 283)
                                        , new Coordinate(173, 261, 176, 283)
                                        , new Coordinate(130, 376, 133, 398)
                                        , new Coordinate(215, 376, 218, 398) ]
                                    , 5: [ new Coordinate(90, 261, 93, 283)
                                        , new Coordinate(173, 261, 176, 283)
                                        , new Coordinate(255, 261, 258, 283)
                                        , new Coordinate(130, 376, 133, 398)
                                        , new Coordinate(215, 376, 218, 398) ]
                                    , 6: [ new Coordinate(90, 261, 93, 283)
                                        , new Coordinate(173, 261, 176, 283)
                                        , new Coordinate(255, 261, 258, 283)
                                        , new Coordinate(90, 376, 93, 398)
                                        , new Coordinate(173, 376, 176, 398)
                                        , new Coordinate(254, 384, 258, 400) ] })

rarityCheckers.Push(borderNormal)
rarityCheckers.Push(border3Diamond)
rarityCheckers.Push(border1Star)
rarityCheckers.Push(borderTrainer)
rarityCheckers.Push(borderRainbow)
rarityCheckers.Push(borderFullArt)
rarityCheckers.Push(borderImmersive)
rarityCheckers.Push(borderCrown)
rarityCheckers.Push(borderGimmighoul)
rarityCheckers.Push(borderShinyEx)
rarityCheckers.Push(borderShiny1Star)
