#SingleInstance, force
#NoEnv
SetBatchLines, -1
SetWorkingDir %A_ScriptDir%

cockpitScript := A_ScriptDir . "\..\Scripts\Include\Cockpit\Cockpit.ahk"
if (!FileExist(cockpitScript)) {
    MsgBox, 16, Injection Queue, Could not find `%Scripts\Include\Cockpit\Cockpit.ahk`.
    ExitApp
}

cmd := """" . A_AhkPath . """ """ . cockpitScript . """ --injection-queue"
Run, %cmd%
ExitApp
