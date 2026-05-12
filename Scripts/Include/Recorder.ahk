; ===== RECORDER GLOBALS =====
rec_Active        := false
rec_Actions       := []
rec_DownX         := 0
rec_DownY         := 0
rec_DownTime      := 0
rec_LastTime      := 0
rec_TrackX        := 0
rec_TrackY        := 0
rec_ReviewDone    := false
rec_ReviewComment  := ""
rec_BuildScript    := ""
RecComment         := ""
rec_SuspendCapture := false
rec_LastScreenGrab := ""
rec_ScreenshotChoice := ""
rec_IsScreenshotAction := false
rec_ReviewBack    := false
rec_ReviewAbort   := false
rec_GrabDone      := false
rec_ReviewIndex   := 0
rec_JumpToOutput  := false
rec_ReturnToReview := false
rec_OutputDone    := false

RecPreview          := ""
RecTitle            := ""
RecInfo             := ""
RecNeedle           := ""
RecChoiceWait       := 0
RecChoiceWaitGone   := 0
RecChoiceFC         := 0
RecCommentLbl       := ""
RecBack             := ""
RecNext             := ""

; ===== FUNCTIONS =====
RecordingCapture() {
    global session

    fileDir := A_ScriptDir . "\..\Screenshots\Rec"
    if !FileExist(fileDir)
        FileCreateDir, %fileDir%
    filePath := fileDir . "\" . A_TickCount . "_rec.png"
    LogToFile("[Capture] Generated filePath=" filePath, "recorder.txt")
    pBitmap := from_window(getMuMuHwnd(session.get("winTitle")))
    saveResult := Gdip_SaveBitmapToFile(pBitmap, filePath)
    fileExists := FileExist(filePath) ? "YES" : "NO"
    LogToFile("[Capture] SaveResult=" saveResult " FileExists=" fileExists " path=" filePath, "recorder.txt")
    Gdip_DisposeImage(pBitmap)
    return filePath
}

ReviewRecording() {
    global rec_Actions, rec_ReviewDone, rec_ReviewBack, rec_ReviewAbort, rec_ReviewComment, rec_BuildScript, rec_ScreenshotChoice, rec_IsScreenshotAction
    global RecPreview, RecTitle, RecInfo, RecNeedle, RecChoiceWait, RecChoiceWaitGone, RecChoiceFC, RecCommentLbl, RecComment, RecBack, RecNext
    global rec_GrabDone, rec_ReviewIndex, rec_JumpToOutput, rec_ReturnToReview, rec_OutputDone, rec_ReviewHwnd
    actionCount := rec_Actions.Length()
    LogToFile("[ReviewRecording] Called with actionCount=" actionCount, "recorder.txt")
    loop %actionCount% {
        a := rec_Actions[A_Index]
        LogToFile("[ReviewRecording] Action[" A_Index "] type=" a.type " screenshot=" a.screenshot " x1=" a.x1 " y1=" a.y1, "recorder.txt")
    }
    if (actionCount = 0) {
        MsgBox, No actions recorded.
        return
    }
    rec_ReviewAbort    := false
    rec_ReturnToReview := false

    Gui, RecReview:New, +LastFound -DPIScale
    WinGet, rec_ReviewHwnd, ID
    Gui, RecReview:Add, Picture, x10  y10  w277 h489 vRecPreview,
    Gui, RecReview:Add, Text,    x300 y10  w280 vRecTitle,
    Gui, RecReview:Add, Text,    x300 y30  w280 vRecInfo,
    Gui, RecReview:Add, Picture, x300 y55  w280 h150 vRecNeedle,
    Gui, RecReview:Add, CheckBox, x300 y215 vRecChoiceWait,     Wait
    Gui, RecReview:Add, CheckBox, x300 y240 vRecChoiceWaitGone, Wait Gone
    Gui, RecReview:Add, CheckBox, x300 y265 vRecChoiceFC,       FindAndClick
    Gui, RecReview:Add, Text,    x300 y295 w280 vRecCommentLbl, Comment:
    Gui, RecReview:Add, Edit,    x300 y315 w280 h80 vRecComment,
    Gui, RecReview:Add, Button,  x300 y405 w65 h25 vRecBack gRecReviewBack, Back
    Gui, RecReview:Add, Button,  x370 y405 w65 h25 vRecNext gRecReviewNext, Next
    Gui, RecReview:Add, Button,  x440 y405 w65 h25 gRecReviewDone, Done
    Gui, RecReview:Add, Button,  x300 y435 w135 h25 gRecGrabScreenshot, Screen Grab

    i := 1
    loop {
        actionCount := rec_Actions.Length()
        while (i <= actionCount) {
            Gui, RecReview:Default      ; restore default GUI after ShowRecordingScript may have changed it
            rec_ReviewIndex := i
            action  := rec_Actions[i]
            isFirst := (i = 1)
            isLast  := (i = actionCount)

            rec_IsScreenshotAction := (action.type = "screenshot")

            LogToFile("[Review] Processing action i=" i " type=" action.type " screenshot=" action.screenshot " x1=" action.x1 " y1=" action.y1 " x2=" action.x2 " y2=" action.y2, "recorder.txt")
            annotPath := AnnotateScreenshot(action.screenshot, action)
            LogToFile("[Review] AnnotateScreenshot returned annotPath=" annotPath " for action i=" i, "recorder.txt")
            GuiControl,, RecPreview, % annotPath
            GuiControl,, RecTitle,   % "Action " i " of " actionCount ": " action.type

            if (action.type = "screenshot") {
                GuiControl,, RecInfo,   % action.fileName
                GuiControl,, RecNeedle, % action.needlePath
                GuiControl, Show, RecNeedle
                GuiControl, Show, RecChoiceWait
                GuiControl, Show, RecChoiceWaitGone
                GuiControl, Show, RecChoiceFC
                GuiControl, Show, RecCommentLbl

                GuiControl,, RecChoiceWait,     % (InStr(action.choice, "|wait|") || action.choice = "") ? 1 : 0
                GuiControl,, RecChoiceWaitGone, % InStr(action.choice, "|waitgone|") ? 1 : 0
                GuiControl,, RecChoiceFC,       % InStr(action.choice, "|findandclick|") ? 1 : 0
            } else {
                if (action.type = "click")
                    actionText := "adbClick(" action.x1 ", " action.y1 ")"
                else {
                    static convX := 540/277, convY := 960/489, offset := -44
                    x1 := Round(action.x1 * convX)
                    y1 := Round((action.y1 + offset) * convY)
                    x2 := Round(action.x2 * convX)
                    y2 := Round((action.y2 + offset) * convY)
                    actionText := "adbSwipe(""" x1 " " y1 " " x2 " " y2 " " action.duration """)"
                }
                action.code := actionText
                GuiControl,, RecInfo, % actionText
                GuiControl, Hide, RecNeedle
                GuiControl, Hide, RecChoiceWait
                GuiControl, Hide, RecChoiceWaitGone
                GuiControl, Hide, RecChoiceFC
                GuiControl, Show, RecCommentLbl
            }
            GuiControl,, RecComment, % action.comment

            if (isFirst)
                GuiControl, Hide, RecBack
            else
                GuiControl, Show, RecBack
            if (isLast)
                GuiControl, Hide, RecNext
            else
                GuiControl, Show, RecNext

            Gui, RecReview:Show, w590 h520, % "Recording Review - Action " i
            WinActivate, ahk_id %rec_ReviewHwnd%
            Sleep, 50                    ; pump message queue so buffered clicks from previous action fire now
            rec_ReviewDone   := false   ; reset AFTER drain — queue is empty, spin loop starts clean
            rec_ReviewBack   := false
            rec_JumpToOutput := false
            LogToFile("[Review] Showing action " i " / " actionCount " type=" action.type " rec_ReviewDone=" rec_ReviewDone " rec_ReviewBack=" rec_ReviewBack " rec_JumpToOutput=" rec_JumpToOutput, "recorder.txt")

            spinCount := 0
            while (!rec_ReviewDone) {
                spinCount++
                if (Mod(spinCount, 50) = 0) {
                    WinGetActiveTitle, dbgActiveWin
                    dbgExists := WinExist("ahk_id " rec_ReviewHwnd) ? "yes" : "no"
                    LogToFile("[Review] Spinning i=" i " count=" spinCount " done=" rec_ReviewDone " activeWin=" dbgActiveWin " hwndExists=" dbgExists, "recorder.txt")
                }
                if (rec_GrabDone) {
                    rec_GrabDone := false
                    actionCount  := rec_Actions.Length()
                    isLast       := (i = actionCount)
                    GuiControl,, RecTitle, % "Action " i " of " actionCount ": " action.type
                    if (isLast)
                        GuiControl, Hide, RecNext
                    else
                        GuiControl, Show, RecNext
                }
                Delay(1)
            }
            LogToFile("[Review] Loop exited action " i " rec_ReviewDone=" rec_ReviewDone " rec_ReviewBack=" rec_ReviewBack " rec_JumpToOutput=" rec_JumpToOutput " rec_ReviewAbort=" rec_ReviewAbort, "recorder.txt")

            if (rec_ReviewAbort)
                break

            action.comment := rec_ReviewComment
            if (action.type = "screenshot") {
                action.choice := rec_ScreenshotChoice
                code := ""
                if (InStr(action.choice, "|wait|"))
                    code .= "FindOrLoseImage(" action.x1 ", " action.y1 ", " action.x2 ", " action.y2 ", , """ action.fileName """, 0, failSafeTime)`n"
                if (InStr(action.choice, "|waitgone|"))
                    code .= "FindOrLoseImage(" action.x1 ", " action.y1 ", " action.x2 ", " action.y2 ", , """ action.fileName """, 1, failSafeTime)`n"
                if (InStr(action.choice, "|findandclick|"))
                    code .= "FindImageAndClick(" action.x1 ", " action.y1 ", " action.x2 ", " action.y2 ", , """ action.fileName """, " action.x3 ", " action.y3 ", sleepTime)`n"
                action.code := RTrim(code, "`n")
            }

            if (rec_JumpToOutput)
                break

            i := rec_ReviewBack ? (i > 1 ? i - 1 : 1) : i + 1
        }

        if (rec_ReviewAbort)
            break

        Gui, RecReview:Hide
        rec_BuildScript := BuildRecordingScript(rec_Actions)
        ShowRecordingScript(rec_BuildScript)

        if (!rec_ReturnToReview)
            break

        rec_ReturnToReview := false
        i := rec_ReviewIndex
        Gui, RecReview:Show, w590 h520, % "Recording Review - Action " i
        WinActivate, ahk_id %rec_ReviewHwnd%
    }
    Gui, RecReview:Destroy
}

AnnotateScreenshot(srcPath, action) {
    static annotCache := {}
    static cacheId    := 0
    LogToFile("[Annotate] Called srcPath=" srcPath " action.type=" action.type " action.x1=" action.x1 " action.y1=" action.y1, "recorder.txt")
    if (!srcPath || !FileExist(srcPath)) {
        LogToFile("[Annotate] SKIP - srcPath empty or file missing: " srcPath, "recorder.txt")
        return srcPath
    }
    if (annotCache.HasKey(srcPath)) {
        LogToFile("[Annotate] CACHE HIT srcPath=" srcPath " returning=" annotCache[srcPath], "recorder.txt")
        return annotCache[srcPath]
    }
    LogToFile("[Annotate] CACHE MISS - generating annotation for srcPath=" srcPath, "recorder.txt")
    pOrig := Gdip_CreateBitmapFromFile(srcPath)
    if (!pOrig)
        return srcPath
    bw := Gdip_GetImageWidth(pOrig)
    bh := Gdip_GetImageHeight(pOrig)
    pAnnotated := Gdip_CreateBitmap(bw, bh)
    pG := Gdip_GraphicsFromImage(pAnnotated)
    Gdip_DrawImage(pG, pOrig, 0, 0, bw, bh)
    Gdip_DisposeImage(pOrig)

    penColor := 0xFFFF4400
    penW     := 3
    pPen     := Gdip_CreatePen(penColor, penW)

    if (action.type = "click" || action.type = "hold") {
        bx := Round(action.x1)
        by := Round(action.y1)
        r  := 15
        if (action.type = "hold") {
            pFill := Gdip_BrushCreateSolid(0x66FF4400)
            Gdip_FillEllipse(pG, pFill, bx - r, by - r, r*2, r*2)
            Gdip_DeleteBrush(pFill)
        }
        Gdip_DrawEllipse(pG, pPen, bx - r, by - r, r*2, r*2)
    } else if (action.type = "swipe") {
        bx1 := Round(action.x1)
        by1 := Round(action.y1)
        bx2 := Round(action.x2)
        by2 := Round(action.y2)
        Gdip_DrawLine(pG, pPen, bx1, by1, bx2, by2)
        dx  := bx2 - bx1
        dy  := by2 - by1
        len := Sqrt(dx*dx + dy*dy)
        if (len > 0) {
            nx    := dx / len
            ny    := dy / len
            aLen  := 18
            aW    := 8
            baseX := Round(bx2 - nx*aLen)
            baseY := Round(by2 - ny*aLen)
            p1x   := Round(baseX - ny*aW)
            p1y   := Round(baseY + nx*aW)
            p2x   := Round(baseX + ny*aW)
            p2y   := Round(baseY - nx*aW)
            pts   := bx2 "," by2 "|" p1x "," p1y "|" p2x "," p2y
            pFill := Gdip_BrushCreateSolid(penColor)
            Gdip_FillPolygon(pG, pFill, pts)
            Gdip_DeleteBrush(pFill)
        }
    } else if (action.type = "screenshot") {
        rx := Round(action.x1 * bw / 275)
        ry := Round(action.y1 * bh / 534)
        rw := Round((action.x2 - action.x1) * bw / 275)
        rh := Round((action.y2 - action.y1) * bh / 534)
        Gdip_DrawRectangle(pG, pPen, rx, ry, rw, rh)
    }

    Gdip_DeletePen(pPen)
    Gdip_DeleteGraphics(pG)
    cacheId++
    tempPath := A_Temp . "\PTCGPB_annot_" . cacheId . ".png"
    Gdip_SaveBitmapToFile(pAnnotated, tempPath)
    Gdip_DisposeImage(pAnnotated)
    annotCache[srcPath] := tempPath
    LogToFile("[Annotate] Stored cache srcPath=" srcPath " -> tempPath=" tempPath " cacheId=" cacheId, "recorder.txt")
    return tempPath
}

BuildRecordingScript(actions) {
    script := ""
    actionCount := actions.Length()
    loop %actionCount% {
        action := actions[A_Index]
        if (A_Index > 1) {
            delay := (action.delay > 0) ? action.delay : 3
            script .= "Delay(" delay ")`n"
            script .= "`n"
        }
        if (action.comment != "")
            script .= "; " . action.comment . "`n"
        script .= action.code . "`n"
    }

    delay := (action.delay > 0) ? action.delay : 3
    script .= "Delay(" . delay . ")`n"
    script .= "`n"

    return script
}

ShowRecordingScript(script) {
    global rec_OutputDone
    rec_OutputDone := false
    Gui, RecOutput:New, +LastFound -DPIScale
    Gui, RecOutput:Add, Edit, x10 y10 w580 h360 ReadOnly HScroll VScroll, %script%
    Gui, RecOutput:Add, Button, x10 y380 w120 h25 gRecOutputCopy, Copy to Clipboard
    Gui, RecOutput:Add, Button, x140 y380 w120 h25 gRecOutputSave, Save As...
    Gui, RecOutput:Add, Button, x270 y380 w120 h25 gRecOutputBack, Back to Review
    Gui, RecOutput:Show, w600 h420, Recording Output
    while (!rec_OutputDone) {
        Delay(1)
    }
}


RecGoTo() {
    global session
    global rec_Active, rec_Actions, rec_LastTime, rec_ReviewBack, rec_IsScreenshotAction, rec_ReviewComment, RecComment
    global RecChoiceWait, RecChoiceWaitGone, RecChoiceFC, rec_ScreenshotChoice, rec_ReviewDone
    global rec_SuspendCapture, rec_LastScreenGrab, rec_ReviewIndex, rec_GrabDone, rec_ReviewAbort, rec_BuildScript, rec_JumpToOutput
    global rec_ReturnToReview, rec_OutputDone, rec_ReviewHwnd

StartStopRecording:
    guiSuffix := session.get("winTitle")
    if (!rec_Active) {
        rec_Active      := true
        rec_Actions     := []
        rec_LastTime    := A_TickCount
        GuiControl, DevMode%guiSuffix%:, Start Recording, Stop Recording
        CreateStatusMessage("Recording: Start")
    } else {
        rec_Active := false
        GuiControl, DevMode%guiSuffix%:, Stop Recording, Start Recording
        CreateStatusMessage("Recording: Done")
        ReviewRecording()
    }
return

RecReviewBack:
    LogToFile("[Label] RecReviewBack fired rec_ReviewDone=" rec_ReviewDone, "recorder.txt")
    rec_ReviewBack := true
    Gui, RecReview:Submit, NoHide
    rec_ReviewComment := RecComment

    choices := ""
    if (RecChoiceWait = 1) {
        choices .= "|wait|"
    }
    if (RecChoiceWaitGone = 1) {
        choices .= "|waitgone|"
    }
    if (RecChoiceFC = 1) {
        choices .= "|findandclick|"
    }
    rec_ScreenshotChoice := choices

    rec_ReviewDone := true
    LogToFile("[Label] RecReviewBack done rec_ReviewDone=" rec_ReviewDone " rec_ReviewBack=" rec_ReviewBack " comment=" rec_ReviewComment, "recorder.txt")
return

RecReviewNext:
    LogToFile("[Label] RecReviewNext fired rec_ReviewDone=" rec_ReviewDone, "recorder.txt")
    rec_ReviewBack := false
    Gui, RecReview:Submit, NoHide
    rec_ReviewComment := RecComment

    choices := ""
    if (RecChoiceWait = 1) {
        choices .= "|wait|"
    }
    if (RecChoiceWaitGone = 1) {
        choices .= "|waitgone|"
    }
    if (RecChoiceFC = 1) {
        choices .= "|findandclick|"
    }
    rec_ScreenshotChoice := choices

    rec_ReviewDone := true
    LogToFile("[Label] RecReviewNext done rec_ReviewDone=" rec_ReviewDone " rec_ReviewBack=" rec_ReviewBack " comment=" rec_ReviewComment, "recorder.txt")
return


RecGrabScreenshot:
    rec_SuspendCapture := true
    rec_LastScreenGrab := ""
    Screenshot_dev("Dev", "", rec_Actions[rec_ReviewIndex].screenshot)
    rec_SuspendCapture := false
    if (rec_LastScreenGrab != "") {
        rec_Actions.InsertAt(rec_ReviewIndex + 1, {type: "screenshot"
            , fileName:   rec_LastScreenGrab.fileName
            , needlePath: rec_LastScreenGrab.needlePath
            , screenshot: rec_LastScreenGrab.screenshot
            , x1: rec_LastScreenGrab.x1, y1: rec_LastScreenGrab.y1
            , x2: rec_LastScreenGrab.x2, y2: rec_LastScreenGrab.y2
            , x3: rec_LastScreenGrab.x3, y3: rec_LastScreenGrab.y3
            , delay: 3, comment: "", code: "", choice: ""})
        rec_GrabDone := true
    }
return

RecReviewGuiClose:
    LogToFile("[Label] RecReviewGuiClose fired rec_ReviewDone=" rec_ReviewDone " rec_ReviewAbort=" rec_ReviewAbort, "recorder.txt")
    if (!rec_ReviewDone) {
        rec_ReviewAbort := true
        rec_ReviewDone  := true
    }
    LogToFile("[Label] RecReviewGuiClose done rec_ReviewDone=" rec_ReviewDone " rec_ReviewAbort=" rec_ReviewAbort, "recorder.txt")
    Gui, RecReview:Destroy
return

RecOutputCopy:
    Clipboard := rec_BuildScript
    ToolTip, Copied to clipboard!
    Delay(1)
    ToolTip
return

RecOutputSave:
    FileSelectFile, savePath, S16,, Save Recording Script, AHK Script (*.ahk)
    if (savePath != "") {
        FileDelete, %savePath%
        FileAppend, %rec_BuildScript%, %savePath%
    }
return

RecReviewDone:
    LogToFile("[Label] RecReviewDone fired rec_ReviewDone=" rec_ReviewDone, "recorder.txt")
    Gui, RecReview:Submit, NoHide
    rec_ReviewComment := RecComment

    if (RecChoiceWait = 1) {
        choices .= "|wait|"
    }
    if (RecChoiceWaitGone = 1) {
        choices .= "|waitgone|"
    }
    if (RecChoiceFC = 1) {
        choices .= "|findandclick|"
    }
    rec_ScreenshotChoice := choices

    rec_JumpToOutput := true
    rec_ReviewDone   := true
    LogToFile("[Label] RecReviewDone done rec_ReviewDone=" rec_ReviewDone " rec_JumpToOutput=" rec_JumpToOutput, "recorder.txt")
return

RecOutputBack:
    rec_ReturnToReview := true
    rec_OutputDone     := true
    Gui, RecOutput:Destroy
return

RecOutputGuiClose:
RecOutputEscape:
    rec_OutputDone := true
    Gui, RecOutput:Destroy
return
}