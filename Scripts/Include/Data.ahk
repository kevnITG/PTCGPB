global dictionaryData := {}

parsePackData(){
    global session

    mainScreenPackList := {}
    pokemonPackObj := {}
    
    packDataPath := getScriptBaseFolder() . "\Data\packdata.dat"
    FileRead, packRawData, %packDataPath%
    if (ErrorLevel)
        return

    lastPackID := ""
    Loop, Parse, packRawData, `n, `r
    {
        line := Trim(A_LoopField)

        if (line = "")
            continue

        if (SubStr(line, 1, 1) = "#")
            continue

        if (InStr(line, "---END---") = 1)
            break

        if (InStr(line, "Home:") = 1) {
            homeValue := Trim(SubStr(line, 6))
            Loop, Parse, homeValue, `, 
            {
                item := Trim(A_LoopField)
                
                if (item = "")
                    continue
                
                splitData := StrSplit(item, "|")
                
                key := Trim(splitData[1])
                value := Trim(splitData[2])
                
                if (key != "")
                    mainScreenPackList[key] := value
            }

            continue
        }

        if (InStr(line, "Pack:") = 1) {
            ; Mewtwo|A|3|Col-First-Left|405|1
            packValue := Trim(SubStr(line, 6))
            splitData := StrSplit(packValue, "|")

            pokemonPackObj[splitData[1]] := {"PackID":splitData[1], "Series":splitData[2], "NumOfPackInSet":splitData[3], "PositionInExtension":splitData[4], "YPosInExtension":splitData[5], "DragType":splitData[6]}
            lastPackID := splitData[1]
            continue
        }
    }

    session.set("pokemonPackObj", pokemonPackObj)
    session.set("mainScreenPackList", mainScreenPackList)

    return lastPackID
}

parseDictionaryData(langCode){
    global dictionaryData
    
    dictionaryData[langCode] := {}
    dictFileName := "dictionary_" . langCode . ".dat"
    dictionaryDataPath := getScriptBaseFolder() . "\Data\" . dictFileName

    if !FileExist(dictionaryDataPath)
        return

    FileRead, rawData, %dictionaryDataPath%

    lastKey := ""

    Loop, Parse, rawData, `n, `r
    {
        line := Trim(A_LoopField)
        
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
            
        colonPos := InStr(line, ":")
        
        if (colonPos > 0) {
            key := Trim(SubStr(line, 1, colonPos - 1))
            val := Trim(SubStr(line, colonPos + 1))
            
            dictionaryData[langCode][key] := val
            lastKey := key
        } 
        else {
            if (lastKey != "")
                dictionaryData[langCode][lastKey] .= " " . line
        }
    }
}