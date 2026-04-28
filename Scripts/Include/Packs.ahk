class PackCoordinate {
    __New(packName, seriesType, expansionXPos, expansionYPos, dragType) {
        this.packName := packName
        this.seriesType := seriesType
        this.expansionXPos := expansionXPos
        this.expansionYPos := expansionYPos
        this.dragType := dragType
    }

    getPackName(){
        return this.packName
    }

    getXPos(){
        return this.expansionXPos
    }

    getYPos(){
        return this.expansionYPos
    }

    getDragType(){
        return this.dragType
    }

    moveSeriesScreen(){
        if(this.seriesType = "B"){
            FindImageAndClick("Pack_ActivatedBSeriesTab", 63, 464, , 250)
        }
        Delay(1)
    }

    expansionScreenDrag(){
        if(this.dragType = 0)
            return
        
        loopCnt := 1
        X := 266
        Y1 := 430
        Y2 := 50

        if(this.dragType = 1)
            loopCnt := 7
        else if(this.dragType = 2)
            loopCnt := 1
        else if(this.dragType = 3)
            loopCnt := 2

        Loop, %loopCnt% {
            adbSwipe(X . " " . Y1 . " " . X . " " . Y2 . " " . 250)
            Sleep, 300
        }
        Delay(2)
    }

    additionalAction(){
        if(this.packName = "Lunala"){
            session.set("failSafe", A_TickCount)
            failSafeTime := 0
            Loop{
                Delay(1)
                if(FindOrLoseImage("Pack_PackPointButton", 0, failSafeTime)){
                    break
                }
                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            }
            session.set("failSafe", A_TickCount)
            failSafeTime := 0
            Loop{
                adbClick_wbb(210, 320)
                Delay(1)
                if(FindOrLoseImage("Pack_PackImageBlankAreaForLunala", 0, failSafeTime)){
                    break
                }
                failSafeTime := (A_TickCount - session.get("failSafe")) // 1000
            }
        }
    }
}

generatePackCoordinates(){
    global session

    session.set("packCoordinates", {})

    ; Crinity modify - Separate X coordinates by expansion type and improve accessibility
    mapExpansionType2PosX := {"Col-First-Left":53, "Col-First-Right":94, "Col-Second-Left":181, "Col-Second-Right":222}
    mapExpansionType3PosX := {"Col-First-Left":33, "Col-First-Middle":74, "Col-First-Right":116, "Col-Second-Left":162, "Col-Second-Middle":202, "Col-Second-Right":244}
    expansionType1PosX := {"Col-First":75, "Col-Second":203}
    mapExpansionCoordinates := {"3Pack":mapExpansionType3PosX, "2Pack":mapExpansionType2PosX, "1Pack":expansionType1PosX}

    ; {"PackID":splitData[1], "Series":splitData[2], "NumOfPackInSet":splitData[3], "PositionInExtension":splitData[4], "YPosInExtension":splitData[5], "DragType":splitData[6]}
    for key, obj in session.get("pokemonPackObj") {
        coordObj := new PackCoordinate(obj["PackID"], obj["Series"], mapExpansionCoordinates[obj["NumOfPackInSet"] . "Pack"][obj["PositionInExtension"]], obj["YPosInExtension"], obj["DragType"])
        session.get("packCoordinates")[obj["PackID"]] := coordObj
    }
}