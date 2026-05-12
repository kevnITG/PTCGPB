#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

#Include %A_ScriptDir%\Config.ahk
#Include %A_ScriptDir%\Utils.ahk

global botConfig := new BotConfig()
botConfig.loadSettingsToConfig("ALL")

waitAfterBulkLaunch := botConfig.get("waitAfterBulkLaunch")
instanceLaunchDelay := botConfig.get("instanceLaunchDelay")
Instances := botConfig.get("Instances")
runMain := botConfig.get("runMain")
Mains := botConfig.get("Mains")
mumuFolder := getMuMuFolder()

; Loop through each instance, check if it's started, and start it if it's not
launched := 0

; Allows launching Main2, Main3, etc.
if(runMain && Mains > 0)
{
    Loop %Mains% {
        instanceNum := "Main" . (A_Index > 1 ? A_Index : "")
        pID := checkInstance(instanceNum)
        if not pID {
            launchInstance(instanceNum)

            sleepTime := instanceLaunchDelay * 1000
            Sleep, % sleepTime
            launched := launched + 1
        }
    }
}

Loop %Instances% {
    instanceNum := Format("{:u}", A_Index)
    pID := checkInstance(instanceNum)
    if not pID {
        launchInstance(instanceNum)

        sleepTime := instanceLaunchDelay * 1000
        Sleep, % sleepTime
        launched := launched + 1
    }
}

ExitApp
