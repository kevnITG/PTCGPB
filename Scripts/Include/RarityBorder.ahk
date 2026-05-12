global currentPackInfo := {"isVerified": false, "CardSlot": [], "TypeCount": {}}
global rarityCheckers := []

class RarityBorder {
    ; =========================================================
    ; [Static] 기존 영역 검색용 공통 좌표
    ; =========================================================
    static DefaultCommon := { 4: [ new Coordinate(96, 279, 116, 281), new Coordinate(181, 279, 201, 281), new Coordinate(96, 394, 116, 396), new Coordinate(181, 394, 201, 396) ]
        , 5: [ new Coordinate(56, 279, 76, 281), new Coordinate(139, 279, 159, 281), new Coordinate(222, 279, 242, 281), new Coordinate(96, 394, 116, 396), new Coordinate(181, 394, 201, 396) ]
        , 6: [ new Coordinate(56, 279, 76, 281), new Coordinate(139, 279, 159, 281), new Coordinate(222, 279, 242, 281), new Coordinate(56, 394, 76, 396), new Coordinate(139, 394, 159, 396), new Coordinate(222, 394, 242, 396) ] }

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
        this.CommonCoords := RarityBorder.DefaultCommon
        this.MaskAnchors := RarityBorder.DefaultMaskAnchors

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

    SetCustomCommon(coordsObj) {
        if (!coordsObj.HasKey(4) || !coordsObj.HasKey(5) || !coordsObj.HasKey(6)) {
            MsgBox, 16, Error, % this.RarityName " Register failed!"
            return
        }

        this.CommonCoords := coordsObj
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

    Search(pBitmap, cardCount, targetIndex) {
        if (this.SearchMode == "MASK") {
            anchor := this.MaskAnchors[cardCount][targetIndex]
            if (!anchor || anchor.x == "")
                return false
            return this.DoMaskSearch(pBitmap, anchor.x, anchor.y)
        }

        commonCoord := this.CommonCoords[cardCount][targetIndex]
        additionalGroups := this.AdditionalSets[cardCount]

        if (!commonCoord || commonCoord.startX == "")
            return false

        if (this.SearchMode == "COMMON_ONLY") {
            return this.DoSearch(pBitmap, commonCoord, this.BasePrefix)
        }

        else if (this.SearchMode == "ALL") {
            if !this.DoSearch(pBitmap, commonCoord, this.BasePrefix)
                return false

            for i, altSet in additionalGroups {
                altCoord := altSet.Coords[targetIndex]
                if !this.DoSearch(pBitmap, altCoord, altSet.Prefix)
                    return false
            }
            return true
        }

        else if (this.SearchMode == "ANY") {
            if this.DoSearch(pBitmap, commonCoord, this.BasePrefix)
                return true

            for i, altSet in additionalGroups {
                altCoord := altSet.Coords[targetIndex]
                if this.DoSearch(pBitmap, altCoord, altSet.Prefix)
                    return true
            }
            return false
        }
    }

    DoSearch(pBitmap, coord, targetPrefix) {
        if (!coord || coord.startX == "")
            return false

        imageIdx := 1

        Loop {
            vRet := false
            Path := A_ScriptDir . "\Needles\" . targetPrefix . imageIdx . ".png"
            if(!FileExist(Path))
                break

            pNeedle := GetNeedle(Path)
            vRet := Gdip_ImageSearch_wbb(pBitmap, pNeedle, vPosXY, coord.startX, coord.startY, coord.endX, coord.endY, 40)

            if(vRet = 1)
                return true
            else
                imageIdx += 1
        }

        return false
    }
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

; Rarity: "normal", "3diamond", "1star", "trainer", "rainbow", "fullart", "immersive", "crown", "gimmighoul", "ShinyEx", "shiny1star"
borderNormal := new RarityBorder("normal", "normal")
border3Diamond := new RarityBorder("3diamond", "3diamond")
border1Star := new RarityBorder("1star", "1star")
borderTrainer := new RarityBorder("trainer", "trainer")
borderRainbow := new RarityBorder("rainbow", "rainbow")
borderFullArt := new RarityBorder("fullart", "fullart", "MASK")
borderFullArt.LoadMaskReferences(A_ScriptDir . "\Mask")
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
