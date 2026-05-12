class BotConfig {
    settingsFile := getScriptBaseFolder() . "\Settings.ini"
    botConfigs := {}
    packList := []

    mainConfigUIMap := {"ui_FriendID": "FriendID"
        , "ui_Instances": "Instances"
        , "ui_Columns": "Columns"
        , "ui_instanceStartDelay": "instanceStartDelay"
        , "ui_runMain": "runMain"
        , "ui_Mains": "Mains"
        , "ui_deleteMethod": "deleteMethod"
        , "ui_packMethod": "packMethod"
        , "ui_openExtraPack": "openExtraPack"
        , "ui_spendHourGlass": "spendHourGlass"
        , "ui_AccountName": "AccountName"
        , "ui_Delay": "Delay"
        , "ui_swipeSpeed": "swipeSpeed"
        , "ui_waitTime": "waitTime"
        , "ui_heartBeat": "heartBeat"
        , "ui_heartBeatName": "heartBeatName"
        , "ui_heartBeatWebhookURL": "heartBeatWebhookURL"
        , "ui_heartBeatDelay": "heartBeatDelay"
        , "ui_heartBeatOwnerWebHookURL": "heartBeatOwnerWebHookURL"}

    defaultValueMap := {"BotLanguage":"English"
        , "IsLanguageSet":0
        , "shownLicense":0
        , "defaultBotLanguage":1
        , "deleteMethod":"Create Bots (13P)"
        , "Instances": 1
        , "Columns": 5
        , "instanceStartDelay": 10
        , "runMain": 0
        , "Mains": 0
        , "openExtraPack": 0
        , "spendHourGlass": 0
        , "injectSortMethod": "PacksDesc"
        , "Delay": 250
        , "swipeSpeed": 250
        , "waitTime": 5
        , "heartBeat": 0
        , "heartBeatDelay": 30
        , "groupRerollEnabled": 0
        , "autoUseGPTest": 0
        , "hasUnopenedPack": 0
        , "applyRoleFilters": 0
        , "TestTime": 3600
        , "gpTestWaitTime": 150
        , "showcaseEnabled": 0
        , "slowMotion": 0
        , "claimSpecialMissions": 0
        , "SelectedMonitorIndex": 1
        , "instanceLaunchDelay": 5
        , "folderPath": "C:\Program Files\Netease"
        , "RowGap": 105
        , "debugMode": 0
        , "stopPreference": ""
        , "stopPreferenceSingle": ""
        , "stopPreferenceMain": ""
        , "s4tKeepSyntheticScreenshots": 0
        , "ocrLanguage": "en"
        , "waitAfterBulkLaunch": 40000}

    generalSettings := {}
    packSettings := {}
    wonderpickSettings := {}
    groupRerollSettings := {}
    saveForTradeSettings := {}
    toolsAndSystemSettings := {}
    extraSettings := {}
    legacySettings := {}

    __New(){
        this.botConfigs["General"] := this.generalSettings
        this.botConfigs["Pack"] := this.packSettings
        this.botConfigs["Wonderpick"] := this.wonderpickSettings
        this.botConfigs["GroupReroll"] := this.groupRerollSettings
        this.botConfigs["SaveForTrade"] := this.saveForTradeSettings
        this.botConfigs["ToolsAndSystem"] := this.toolsAndSystemSettings
        this.botConfigs["Extra"] := this.extraSettings

        this.botConfigs["UserSettings"] := this.legacySettings
        this.initDefaultSettings()
    }

    initDefaultSettings(){
        For settingID, settingValue in this.defaultValueMap {
            this.set(settingID, settingValue)
        }
    }

    get(configItemName){
        value := ""
        For idx, configObj in this.botConfigs {
            if(idx = "UserSettings")
                continue

            if(configObj.HasKey(configItemName))
                value := configObj[configItemName]
        }

        if(value = "" && this.legacySettings.HasKey(configItemName))
            value := this.legacySettings[configItemName]

        if(value = "" && this.defaultValueMap.HasKey(configItemName)){
            value := this.defaultValueMap[configItemName]
            this.set(configItemName, value)
        }

        return Trim(value)
    }

    set(configItemName, configValue, sectionName := "UserSettings"){
        configValue := Trim(configValue)
        if(sectionName != "UserSettings"){
            this.botConfigs[sectionName][configItemName] := configValue
            return
        }

        if(sectionName = "UserSettings"){
            isFound := false
            For idx, configObj in this.botConfigs {
                if(idx = "UserSettings")
                    continue

                if(this.botConfigs[idx].HasKey(configItemName)){
                    this.botConfigs[idx][configItemName] := configValue
                    isFound := true
                    break
                }
            }

            if(!isFound)
                this.botConfigs["UserSettings"][configItemName] := configValue
        }
    }

    loadSettingsToConfig(configType := "ALL"){
        if(configType = "ALL"){
            For idx, configObj in this.botConfigs {
                this.loadIniSectionFromSettingsFile(idx)
            }
        }
        else{
            this.loadIniSectionFromSettingsFile(configType)
        }

        ; for Legacy
        this.loadIniSectionFromSettingsFile("UserSettings")
    }

    saveConfigToSettings(configType := "ALL"){
        if(configType = "ALL"){
            FileDelete, % this.settingsFile

            For configKey, configValue in this.botConfigs["UserSettings"].Clone() {
                For sectionName, configObj in this.botConfigs {
                    if(sectionName = "UserSettings")
                        continue

                    if(this.botConfigs[sectionName].HasKey(configKey)){
                        this.botConfigs["UserSettings"].Delete(configKey)
                        break
                    }
                }
            }

            For idx, configObj in this.botConfigs {
                this.writeConfigFile(idx)
            }

            return
        }
        else
            this.writeConfigFile(configType)
    }

    writeConfigFile(sectionName := "UserSettings"){
        writeCount := 0
        settingsFile := this.settingsFile
        For idx, value in this.botConfigs[sectionName] {
            IniWrite, %value%, %settingsFile%, %sectionName%, %idx%
            writeCount += 1
        }
        if(writeCount > 0)
            FileAppend, `n, %settingsFile%
    }

    loadIniSectionFromSettingsFile(sectionName){
        settingsFile := this.settingsFile
        IniRead, rawData, %settingsFile%, %sectionName%

        if (rawData = "ERROR" || rawData = "") {
            return
        }

        Loop, Parse, rawData, `n, `r
        {
            if (A_LoopField = "")
                continue

            equalPos := InStr(A_LoopField, "=")

            if (equalPos > 0) {
                key := SubStr(A_LoopField, 1, equalPos - 1)
                val := SubStr(A_LoopField, equalPos + 1)

                this.botConfigs[sectionName][key] := val
            }
        }
    }
}
