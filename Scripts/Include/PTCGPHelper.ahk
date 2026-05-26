;===============================================================================
; PTCGPHelper.ahk - Android ptcgpb helper install/runtime utilities
;===============================================================================

EnsurePTCGPBHelperInstalled() {
    global session

    remotePath := "/data/ptcgp/ptcgpb"
    safeScriptName := RegExReplace(session.get("scriptName"), "[^A-Za-z0-9_.-]", "_")
    if (safeScriptName = "")
        safeScriptName := A_ScriptName
    remoteTmpPath := "/data/ptcgp/ptcgpb." . safeScriptName . ".tmp"
    sdcardTmpPath := "/sdcard/ptcgpb-helper." . safeScriptName . ".tmp"
    helperUrl := "https://leanny.github.io/ptcgpb-helper/ptcgpb-helper-android"
    localPath := A_Temp . "\ptcgpb-helper-android." . safeScriptName
    minHelperSize := 2500000

    adbWriteRaw("mkdir -p /data/ptcgp")
    remoteSize := Trim(StrReplace(adbWriteRaw("if [ -x " . remotePath . " ]; then wc -c < " . remotePath . "; else echo 0; fi", true), "`r"), "`n`t ")
    remoteSize := RegExReplace(remoteSize, "[^\d]")
    if (remoteSize >= minHelperSize) {
        LogTrace("ptcgpb helper already exists on device size=" . remoteSize, "ADB.txt")
        return true
    }
    if (remoteSize > 0) {
        LogWarn("Removing incomplete ptcgpb helper from device size=" . remoteSize)
        adbWriteRaw("rm -f " . remotePath)
    }

    LogInfo("ptcgpb helper missing on device; downloading on Windows host")
    if (!DownloadPTCGPBHelperToFile(helperUrl, localPath)) {
        LogWarn("Failed to download ptcgpb helper on Windows host")
        return false
    }

    FileGetSize, helperSize, %localPath%
    if (helperSize < minHelperSize) {
        LogWarn("Downloaded ptcgpb helper is unexpectedly small: " . helperSize . " bytes")
        return false
    }

    adbCommand := """" . session.get("adbPath") . """ -s 127.0.0.1:" . session.get("adbPort")
    LogTrace("Pushing ptcgpb helper to " . sdcardTmpPath, "ADB.txt")
    RunWait, % adbCommand . " push """ . localPath . """ " . sdcardTmpPath,, Hide
    if (ErrorLevel) {
        LogWarn("Failed to push ptcgpb helper to device. ErrorLevel=" . ErrorLevel)
        return false
    }

    adbWriteRaw("cp -f " . sdcardTmpPath . " " . remoteTmpPath . " && mv -f " . remoteTmpPath . " " . remotePath . " && chmod 777 " . remotePath . " && rm -f " . sdcardTmpPath)
    remoteSize := Trim(StrReplace(adbWriteRaw("if [ -x " . remotePath . " ]; then wc -c < " . remotePath . "; else echo 0; fi", true), "`r"), "`n`t ")
    remoteSize := RegExReplace(remoteSize, "[^\d]")
    if (remoteSize < minHelperSize) {
        LogWarn("ptcgpb helper install verification failed size=" . remoteSize)
        return false
    }

    LogInfo("ptcgpb helper installed via Windows download and adb push")
    return true
}

DownloadPTCGPBHelperToFile(url, localPath) {
    RegRead, proxyEnabled, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
    RegRead, proxyServer, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyServer

    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    if (proxyEnabled)
        whr.SetProxy(2, proxyServer)
    whr.SetTimeouts(10000, 10000, 30000, 120000)
    whr.Open("GET", url, false)
    whr.Send()

    if (whr.Status != 200) {
        LogWarn("ptcgpb helper host download returned HTTP status " . whr.Status)
        return false
    }

    if (FileExist(localPath))
        FileDelete, %localPath%

    stream := ComObjCreate("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.Write(whr.ResponseBody)
    stream.SaveToFile(localPath, 2)
    stream.Close()
    return FileExist(localPath)
}

RemoveOldFiles() {
    remotePath := "/data/ptcgp/ptcgpb"
    exists := Trim(StrReplace(adbWriteRaw("if [ -f " . remotePath . " ]; then echo 1; else echo 0; fi", true), "`r"), "`n`t ")
    if (exists != "1") {
        LogTrace("RemoveOldFiles skipped because ptcgpb helper does not exist", "ADB.txt")
        return
    }

    versionOutput := adbWriteRaw(remotePath . " --version", true)
    if (!RegExMatch(versionOutput, "(\d+)\.(\d+)\.(\d+)", versionMatch)) {
        LogWarn("RemoveOldFiles skipped because ptcgpb helper version could not be parsed: " . Trim(versionOutput), "ADB.txt")
        return
    }

    if (IsPtcgpbVersionLessThan(versionMatch1, versionMatch2, versionMatch3, 0, 9, 0)) {
        LogInfo("RemoveOldFiles deleting old ptcgpb helper version " . versionMatch1 . "." . versionMatch2 . "." . versionMatch3, "ADB.txt")
        adbWriteRaw("rm -f " . remotePath)
    } else {
        LogTrace("RemoveOldFiles kept ptcgpb helper version " . versionMatch1 . "." . versionMatch2 . "." . versionMatch3, "ADB.txt")
    }
}

IsPtcgpbVersionLessThan(major, minor, patch, minMajor, minMinor, minPatch) {
    major += 0
    minor += 0
    patch += 0

    if (major != minMajor)
        return major < minMajor
    if (minor != minMinor)
        return minor < minMinor
    return patch < minPatch
}

