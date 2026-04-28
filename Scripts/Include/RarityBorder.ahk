global currentPackInfo := {"isVerified": false, "CardSlot": [], "TypeCount": {}}
global rarityCheckers := []

class RarityBorder {
    static DefaultCommon := { 4: [ new Coordinate(96, 279, 116, 281)
                                 , new Coordinate(181, 279, 201, 281)
                                 , new Coordinate(96, 394, 116, 396)
                                 , new Coordinate(181, 394, 201, 396) ]
                           , 5: [new Coordinate(56, 279, 76, 281)
                               , new Coordinate(139, 279, 159, 281)
                               , new Coordinate(222, 279, 242, 281)
                               , new Coordinate(96, 394, 116, 396)
                               , new Coordinate(181, 394, 201, 396) ] 
                           , 6: [new Coordinate(56, 279, 76, 281)
                               , new Coordinate(139, 279, 159, 281)
                               , new Coordinate(222, 279, 242, 281)
                               , new Coordinate(56, 394, 76, 396)
                               , new Coordinate(139, 394, 159, 396)
                               , new Coordinate(222, 394, 242, 396) ] }

    __New(name, basePrefix, searchMode := "COMMON_ONLY") {
        this.RarityName := name
        this.BasePrefix := basePrefix
        this.SearchMode := searchMode  ; "COMMON_ONLY", "ALL", "ANY" 중 하나를 저장
        
        this.AdditionalSets := { 4: [], 5: [], 6: [] }
        this.CommonCoords := RarityBorder.DefaultCommon
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

; Rarity: "normal", "3diamond", "1star", "trainer", "rainbow", "fullart", "immersive", "crown", "gimmighoul", "ShinyEx", "shiny1star"
borderNormal := new RarityBorder("normal", "normal")
border3Diamond := new RarityBorder("3diamond", "3diamond")
border1Star := new RarityBorder("1star", "1star")
borderTrainer := new RarityBorder("trainer", "trainer")
borderRainbow := new RarityBorder("rainbow", "rainbow")
borderFullArt := new RarityBorder("fullart", "fullart", "ANY")
borderImmersive := new RarityBorder("immersive", "immersive")
borderCrown := new RarityBorder("crown", "crown")
borderGimmighoul := new RarityBorder("gimmighoul", "gimmighoul")
borderShinyEx := new RarityBorder("ShinyEx", "shiny1star", "ALL")
borderShiny1Star := new RarityBorder("shiny1star", "shiny1star")

; Addtional coords
borderFullArt.AddAdditionalSet("fullart_ex1_", { 4: [ new Coordinate(57, 176, 59, 184)
                                                    , new Coordinate(142, 176, 144, 184)
                                                    , new Coordinate(57, 291, 59, 299)
                                                    , new Coordinate(57, 291, 59, 299) ]
                                               , 5: [ new Coordinate(17, 181, 19, 189)
                                                    , new Coordinate(99, 181, 101, 189)
                                                    , new Coordinate(182, 181, 184, 189)
                                                    , new Coordinate(57, 296, 59, 304)
                                                    , new Coordinate(142, 296, 144, 304) ] 
                                               , 6: [ new Coordinate(17, 181, 19, 189)
                                                    , new Coordinate(99, 181, 101, 189)
                                                    , new Coordinate(182, 181, 184, 189)
                                                    , new Coordinate(17, 296, 19, 304)
                                                    , new Coordinate(99, 296, 101, 304)
                                                    , new Coordinate(182, 296, 184, 304) ] })

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