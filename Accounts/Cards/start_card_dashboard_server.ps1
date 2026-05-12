param(
    [int]$Port = 8081,
    [string]$Root = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    throw "Root path not found: $resolvedRoot"
}

$defaultDocument = "Accounts/Cards/card_database.html"
$shutdownAt = $null

$mimeMap = @{
    ".html" = "text/html; charset=utf-8"
    ".htm" = "text/html; charset=utf-8"
    ".css" = "text/css; charset=utf-8"
    ".js" = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".csv" = "text/csv; charset=utf-8"
    ".txt" = "text/plain; charset=utf-8"
    ".xml" = "application/xml; charset=utf-8"
    ".png" = "image/png"
    ".jpg" = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif" = "image/gif"
    ".webp" = "image/webp"
    ".svg" = "image/svg+xml"
    ".ico" = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2" = "font/woff2"
}

function Write-TextResponse {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [int]$StatusCode,
        [string]$Body,
        [string]$ContentType = "text/plain; charset=utf-8"
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.ContentType = $ContentType
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.OutputStream.Close()
}

function Write-JsonResponse {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [int]$StatusCode,
        $Payload,
        [int]$Depth = 6
    )
    $json = $Payload | ConvertTo-Json -Depth $Depth -Compress
    Write-TextResponse -Context $Context -StatusCode $StatusCode -Body $json -ContentType "application/json; charset=utf-8"
}

function Read-RequestBody {
    param([Parameter(Mandatory = $true)]$Context)
    $reader = New-Object System.IO.StreamReader($Context.Request.InputStream, $Context.Request.ContentEncoding)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Get-XmlDeviceAccount {
    param([Parameter(Mandatory = $true)][string]$XmlPath)

    if (-not (Test-Path -LiteralPath $XmlPath -PathType Leaf)) { return "" }
    try {
        $content = [System.IO.File]::ReadAllText($XmlPath)
    } catch {
        return ""
    }
    $match = [regex]::Match($content, '<string\s+name=["'']deviceAccount["'']>([^<]+)</string>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return "" }
    return $match.Groups[1].Value.Trim()
}

function Find-AccountXml {
    param(
        [Parameter(Mandatory = $true)][string]$Account,
        [string]$FileName
    )
    $savedRoot = Join-Path $resolvedRoot "Accounts\Saved"
    if (-not (Test-Path -LiteralPath $savedRoot -PathType Container)) { return $null }

    if (-not [string]::IsNullOrWhiteSpace($FileName)) {
        # Reject anything that looks like a path traversal attempt before any IO.
        if ($FileName -match "[\\/:*?""<>|]" -or $FileName -match "\.\.") { return $null }

        # Strip a trailing .xml so we can build wildcard patterns either way.
        $stem = $FileName
        if ($stem -match "\.xml$") { $stem = $stem.Substring(0, $stem.Length - 4) }
        if (-not [string]::IsNullOrWhiteSpace($stem)) {
            $exactName = "$stem.xml"
            $wildcardName = "*$stem*.xml"

            # Helper: prefer exact match, otherwise the most recently modified wildcard hit.
            $resolveIn = {
                param($root)
                if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $null }
                $exact = Get-ChildItem -LiteralPath $root -Recurse -Filter $exactName -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exact) { return $exact.FullName }
                $fuzzy = Get-ChildItem -LiteralPath $root -Recurse -Filter $wildcardName -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
                if ($fuzzy) { return $fuzzy.FullName }
                return $null
            }

            # Prefer the device-specific subfolder when the account looks like a folder name.
            if ($Account -match "^[A-Za-z0-9_-]{1,32}$") {
                $preferredDir = Join-Path $savedRoot $Account
                $hit = & $resolveIn $preferredDir
                if ($hit) { return $hit }
            }

            # Fallback: search the entire Saved tree by filename.
            $hit = & $resolveIn $savedRoot
            if ($hit) { return $hit }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Account)) { return $null }

    # Final fallback: inspect XML contents and match the embedded deviceAccount.
    $contentMatch = Get-ChildItem -LiteralPath $savedRoot -Recurse -Filter "*.xml" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Where-Object { (Get-XmlDeviceAccount -XmlPath $_.FullName) -eq $Account } |
        Select-Object -First 1
    if ($contentMatch) { return $contentMatch.FullName }

    return $null
}

function Update-InjectIni {
    param(
        [Parameter(Mandatory = $true)][string]$IniPath,
        [Parameter(Mandatory = $true)][hashtable]$UserSettings
    )
    # The .ahk reads via IniRead which expects UTF-16 LE BOM (current format).
    $existing = @()
    if (Test-Path -LiteralPath $IniPath -PathType Leaf) {
        $existing = [System.IO.File]::ReadAllLines($IniPath, [System.Text.Encoding]::Unicode)
    }

    $output = New-Object System.Collections.Generic.List[string]
    $currentSection = ""
    $remaining = @{}
    foreach ($k in $UserSettings.Keys) { $remaining[$k] = $true }
    $userSettingsSeen = $false

    foreach ($line in $existing) {
        if ($line -match '^\s*\[(.+)\]\s*$') {
            # Before leaving [UserSettings], flush any keys we did not encounter.
            if ($currentSection -eq "UserSettings") {
                foreach ($k in @($remaining.Keys)) {
                    if ($remaining[$k]) {
                        $output.Add("$k=$($UserSettings[$k])")
                        $remaining[$k] = $false
                    }
                }
            }
            $currentSection = $matches[1]
            if ($currentSection -eq "UserSettings") { $userSettingsSeen = $true }
            $output.Add($line)
            continue
        }

        if ($currentSection -eq "UserSettings" -and $line -match '^\s*([^=;\s][^=]*?)\s*=') {
            $key = $matches[1]
            if ($UserSettings.ContainsKey($key)) {
                $output.Add("$key=$($UserSettings[$key])")
                $remaining[$key] = $false
                continue
            }
        }

        $output.Add($line)
    }

    # Flush any keys still missing.
    if (-not $userSettingsSeen) {
        $output.Add("[UserSettings]")
    }
    foreach ($k in @($remaining.Keys)) {
        if ($remaining[$k]) {
            $output.Add("$k=$($UserSettings[$k])")
        }
    }

    # Preserve UTF-16 LE with BOM (matches what AHK IniRead expects on the existing file).
    $encoding = New-Object System.Text.UnicodeEncoding($false, $true)
    [System.IO.File]::WriteAllLines($IniPath, $output, $encoding)
}

function Resolve-AutoHotkeyExe {
    $candidates = @(
        "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe",
        "$env:ProgramFiles\AutoHotkey\v1.1\AutoHotkeyU64.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkeyU64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }
    }
    return $null
}

function Read-IniSection {
    param(
        [Parameter(Mandatory = $true)][string]$IniPath,
        [Parameter(Mandatory = $true)][string]$Section
    )
    $result = @{}
    if (-not (Test-Path -LiteralPath $IniPath -PathType Leaf)) { return $result }
    $lines = [System.IO.File]::ReadAllLines($IniPath, [System.Text.Encoding]::Unicode)
    $current = ""
    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.+)\]\s*$') { $current = $matches[1]; continue }
        if ($current -ne $Section) { continue }
        if ($line -match '^\s*([^=;\s][^=]*?)\s*=\s*(.*)\s*$') {
            $result[$matches[1]] = $matches[2]
        }
    }
    return $result
}

function Resolve-MumuFolder {
    param([Parameter(Mandatory = $true)][string]$BaseFolder)
    $candidates = @(
        "MuMuPlayerGlobal-12.0",
        "MuMu Player 12",
        "MuMuPlayer-12.0",
        "MuMuPlayer",
        "MuMuPlayer-12",
        "MuMuPlayer12"
    )
    foreach ($c in $candidates) {
        $p = Join-Path $BaseFolder $c
        if (Test-Path -LiteralPath $p -PathType Container) { return $p }
    }
    return $null
}

function Get-MumuInstances {
    param([Parameter(Mandatory = $true)][string]$BaseFolder)
    $instances = @()
    $mumuFolder = Resolve-MumuFolder -BaseFolder $BaseFolder
    if (-not $mumuFolder) { return $instances }
    $vmsRoot = Join-Path $mumuFolder "vms"
    if (-not (Test-Path -LiteralPath $vmsRoot -PathType Container)) { return $instances }
    $vmDirs = Get-ChildItem -LiteralPath $vmsRoot -Directory -ErrorAction SilentlyContinue
    foreach ($vm in $vmDirs) {
        $extra = Join-Path $vm.FullName "configs\extra_config.json"
        if (-not (Test-Path -LiteralPath $extra -PathType Leaf)) { continue }
        try {
            $content = [System.IO.File]::ReadAllText($extra)
            $m = [regex]::Match($content, '"playerName"\s*:\s*"([^"]*)"')
            if (-not $m.Success) { continue }
            $name = $m.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            # Also pull adb host port from vm_config.json (best-effort, optional metadata).
            $port = $null
            $vmCfg = Join-Path $vm.FullName "configs\vm_config.json"
            if (Test-Path -LiteralPath $vmCfg -PathType Leaf) {
                $vmContent = [System.IO.File]::ReadAllText($vmCfg)
                $pm = [regex]::Match($vmContent, '"host_port"\s*:\s*"(\d+)"')
                if ($pm.Success) { $port = [int]$pm.Groups[1].Value }
            }
            $instances += [pscustomobject]@{
                name = $name
                vm = $vm.Name
                adbPort = $port
            }
        } catch { continue }
    }
    return $instances
}

function Invoke-ListInstances {
    param([Parameter(Mandatory = $true)]$Context)
    $accountsDir = Join-Path $resolvedRoot "Accounts"
    $iniPath = Join-Path $accountsDir "InjectAccount.ini"
    $settings = Read-IniSection -IniPath $iniPath -Section "UserSettings"
    $folderPath = if ($settings.ContainsKey("folderPath") -and -not [string]::IsNullOrWhiteSpace($settings["folderPath"])) {
        $settings["folderPath"]
    } else {
        "C:\Program Files\Netease"
    }
    if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) {
        Write-JsonResponse -Context $Context -StatusCode 404 -Payload @{
            ok = $false
            error = "MuMu base folder not found: $folderPath. Update folderPath in Accounts\InjectAccount.ini."
        }
        return
    }
    $instances = Get-MumuInstances -BaseFolder $folderPath
    Write-JsonResponse -Context $Context -StatusCode 200 -Payload @{
        ok = $true
        folderPath = $folderPath
        defaultInstance = if ($settings.ContainsKey("winTitle")) { $settings["winTitle"] } else { "" }
        instances = $instances
    }
}

function Invoke-LaunchInstance {
    param([Parameter(Mandatory = $true)]$Context)

    $bodyText = Read-RequestBody -Context $Context
    if ([string]::IsNullOrWhiteSpace($bodyText)) {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Empty request body." }
        return
    }
    try { $payload = $bodyText | ConvertFrom-Json } catch {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Invalid JSON body." }
        return
    }

    $name = [string]$payload.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Missing 'name'." }
        return
    }
    if ($name -match '[\r\n=\[\]"]') {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Invalid characters in instance name." }
        return
    }

    $accountsDir = Join-Path $resolvedRoot "Accounts"
    $iniPath = Join-Path $accountsDir "InjectAccount.ini"
    $settings = Read-IniSection -IniPath $iniPath -Section "UserSettings"
    $folderPath = if ($settings.ContainsKey("folderPath") -and -not [string]::IsNullOrWhiteSpace($settings["folderPath"])) {
        $settings["folderPath"]
    } else {
        "C:\Program Files\Netease"
    }
    $mumuFolder = Resolve-MumuFolder -BaseFolder $folderPath
    if (-not $mumuFolder) {
        Write-JsonResponse -Context $Context -StatusCode 404 -Payload @{ ok = $false; error = "MuMu folder not found under $folderPath." }
        return
    }

    # Find vm folder whose extra_config.json playerName matches.
    $vmsRoot = Join-Path $mumuFolder "vms"
    $instanceNum = $null
    $vmFolderName = $null
    if (Test-Path -LiteralPath $vmsRoot -PathType Container) {
        foreach ($vm in Get-ChildItem -LiteralPath $vmsRoot -Directory -ErrorAction SilentlyContinue) {
            $extra = Join-Path $vm.FullName "configs\extra_config.json"
            if (-not (Test-Path -LiteralPath $extra -PathType Leaf)) { continue }
            try {
                $content = [System.IO.File]::ReadAllText($extra)
                $m = [regex]::Match($content, '"playerName"\s*:\s*"([^"]*)"')
                if ($m.Success -and $m.Groups[1].Value -eq $name) {
                    $vmFolderName = $vm.Name
                    $nm = [regex]::Match($vm.Name, '[^-]+$')
                    if ($nm.Success) { $instanceNum = $nm.Value }
                    break
                }
            } catch { continue }
        }
    }
    if (-not $instanceNum) {
        Write-JsonResponse -Context $Context -StatusCode 404 -Payload @{ ok = $false; error = "Could not resolve instance number for '$name'." }
        return
    }

    $mumuExe = Join-Path $mumuFolder "shell\MuMuPlayer.exe"
    if (-not (Test-Path -LiteralPath $mumuExe -PathType Leaf)) {
        $mumuExe = Join-Path $mumuFolder "nx_main\MuMuNxMain.exe"
    }
    if (-not (Test-Path -LiteralPath $mumuExe -PathType Leaf)) {
        Write-JsonResponse -Context $Context -StatusCode 404 -Payload @{ ok = $false; error = "MuMuPlayer.exe not found in $mumuFolder." }
        return
    }

    try {
        Start-Process -FilePath $mumuExe -ArgumentList @("-v", $instanceNum) -WorkingDirectory (Split-Path -Parent $mumuExe) | Out-Null
    } catch {
        Write-JsonResponse -Context $Context -StatusCode 500 -Payload @{ ok = $false; error = "Failed to launch: $($_.Exception.Message)" }
        return
    }

    Write-JsonResponse -Context $Context -StatusCode 200 -Payload @{
        ok = $true
        name = $name
        vm = $vmFolderName
        instance = $instanceNum
    }
}

function Invoke-InjectAccount {
    param([Parameter(Mandatory = $true)]$Context)

    $bodyText = Read-RequestBody -Context $Context
    if ([string]::IsNullOrWhiteSpace($bodyText)) {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Empty request body." }
        return
    }

    try { $payload = $bodyText | ConvertFrom-Json } catch {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Invalid JSON body." }
        return
    }

    $account = [string]$payload.account
    $fileName = [string]$payload.fileName
    $winTitle = [string]$payload.winTitle
    $sendFriendRequest = $false
    if ($null -ne $payload.sendFriendRequest) {
        try { $sendFriendRequest = [bool]$payload.sendFriendRequest } catch { $sendFriendRequest = $false }
    }
    if ([string]::IsNullOrWhiteSpace($account)) {
        Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "The 'account' field is required." }
        return
    }

    $xmlPath = Find-AccountXml -Account $account -FileName $fileName
    if (-not $xmlPath) {
        $searchHint = if ([string]::IsNullOrWhiteSpace($fileName)) {
            "deviceAccount '$account'"
        } else {
            "file '$fileName' or deviceAccount '$account'"
        }
        Write-JsonResponse -Context $Context -StatusCode 404 -Payload @{ ok = $false; error = "No XML matching $searchHint was found under Accounts\Saved." }
        return
    }

    $accountsDir = Join-Path $resolvedRoot "Accounts"
    $iniPath = Join-Path $accountsDir "InjectAccount.ini"
    $ahkPath = Join-Path $accountsDir "_InjectAccount.ahk"

    if (-not (Test-Path -LiteralPath $ahkPath -PathType Leaf)) {
        Write-JsonResponse -Context $Context -StatusCode 500 -Payload @{ ok = $false; error = "_InjectAccount.ahk not found." }
        return
    }

    # fileName must be without extension (the AHK script appends .xml at runtime).
    $fileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($xmlPath)

    $iniValues = @{
        fileName = $fileNameNoExt
        selectedFilePath = $xmlPath
        sendFriendRequestAfterInject = if ($sendFriendRequest) { 1 } else { 0 }
    }
    if (-not [string]::IsNullOrWhiteSpace($winTitle)) {
        # Reject anything weird so we don't write garbage that breaks the ini.
        if ($winTitle -match "[`r`n=\[\]]") {
            Write-JsonResponse -Context $Context -StatusCode 400 -Payload @{ ok = $false; error = "Invalid winTitle." }
            return
        }
        $iniValues["winTitle"] = $winTitle
    }

    try {
        Update-InjectIni -IniPath $iniPath -UserSettings $iniValues
    } catch {
        Write-JsonResponse -Context $Context -StatusCode 500 -Payload @{ ok = $false; error = "Failed to update InjectAccount.ini: $($_.Exception.Message)" }
        return
    }

    $headless = -not [string]::IsNullOrWhiteSpace($winTitle)
    $ahkExe = Resolve-AutoHotkeyExe
    try {
        $argList = @()
        if ($ahkExe) { $argList += "`"$ahkPath`"" }
        if ($headless) { $argList += "/headless" }
        if ($ahkExe) {
            Start-Process -FilePath $ahkExe -ArgumentList $argList -WorkingDirectory $accountsDir | Out-Null
        } elseif ($headless) {
            Start-Process -FilePath $ahkPath -ArgumentList @("/headless") -WorkingDirectory $accountsDir | Out-Null
        } else {
            Start-Process -FilePath $ahkPath -WorkingDirectory $accountsDir | Out-Null
        }
    } catch {
        Write-JsonResponse -Context $Context -StatusCode 500 -Payload @{ ok = $false; error = "Failed to launch AutoHotkey: $($_.Exception.Message)" }
        return
    }

    Write-JsonResponse -Context $Context -StatusCode 200 -Payload @{
        ok = $true
        file = $xmlPath
        fileName = $fileNameNoExt
        account = $account
        winTitle = $winTitle
        headless = $headless
        sendFriendRequest = $sendFriendRequest
        launcher = if ($ahkExe) { $ahkExe } else { "shell-association" }
    }
}

function Invoke-LoadAccountData {
    param([Parameter(Mandatory = $true)]$Context)

    $accountsDataDir = Join-Path $resolvedRoot "Accounts\Cards\accounts"
    if (-not (Test-Path -LiteralPath $accountsDataDir -PathType Container)) {
        Write-JsonResponse -Context $Context -StatusCode 404 -Payload @{
            ok = $false
            error = "Accounts folder not found: $accountsDataDir"
        }
        return
    }

    $documents = New-Object System.Collections.Generic.List[object]
    $skipped = New-Object System.Collections.Generic.List[object]

    Get-ChildItem -LiteralPath $accountsDataDir -Filter "*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object {
            $file = $_
            try {
                $text = [System.IO.File]::ReadAllText($file.FullName)
                $doc = $text | ConvertFrom-Json
                if ($null -eq $doc) {
                    throw "Empty JSON document."
                }

                $deviceAccount = [string]$doc.deviceAccount
                if ([string]::IsNullOrWhiteSpace($deviceAccount)) {
                    $deviceAccount = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    $doc | Add-Member -NotePropertyName deviceAccount -NotePropertyValue $deviceAccount -Force
                }

                if (-not $doc.PSObject.Properties["metadata"] -or $null -eq $doc.metadata) {
                    $doc | Add-Member -NotePropertyName metadata -NotePropertyValue ([pscustomobject]@{}) -Force
                }
                if (-not $doc.PSObject.Properties["pulls"] -or $null -eq $doc.pulls) {
                    $doc | Add-Member -NotePropertyName pulls -NotePropertyValue @() -Force
                }

                $doc | Add-Member -NotePropertyName sourceFileName -NotePropertyValue $file.Name -Force
                $documents.Add($doc)
            } catch {
                $skipped.Add([pscustomobject]@{
                    file = $file.Name
                    error = $_.Exception.Message
                })
            }
        }

    Write-JsonResponse -Context $Context -StatusCode 200 -Depth 12 -Payload @{
        ok = $true
        source = "Accounts/Cards/accounts"
        accountCount = $documents.Count
        skippedCount = $skipped.Count
        skipped = $skipped
        accounts = $documents
    }
}

function Is-LocalRequest {
    param([Parameter(Mandatory = $true)]$Context)
    $remoteAddress = $Context.Request.RemoteEndPoint.Address.ToString()
    return $remoteAddress -eq "127.0.0.1" -or $remoteAddress -eq "::1"
}

function Resolve-RequestedPath {
    param([Parameter(Mandatory = $true)][string]$RawUrl)

    $requestPath = [Uri]::UnescapeDataString(($RawUrl -split "\?", 2)[0])
    if ([string]::IsNullOrWhiteSpace($requestPath) -or $requestPath -eq "/") {
        $requestPath = "/$defaultDocument"
    }

    $relativePath = $requestPath.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))
    if (-not $candidate.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidate
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Serving $resolvedRoot at http://localhost:$Port"

try {
    $shouldStop = $false
    while (-not $shouldStop) {
        $iar = $listener.BeginGetContext($null, $null)
        while (-not $iar.AsyncWaitHandle.WaitOne(200)) {
            if ($shutdownAt -and (Get-Date) -ge $shutdownAt) {
                $shouldStop = $true
                break
            }
        }

        if ($shouldStop) {
            break
        }

        $context = $listener.EndGetContext($iar)
        $request = $context.Request

        if ($request.Url.AbsolutePath -eq "/__dashboard/ping" -and $request.HttpMethod -eq "GET") {
            if (-not (Is-LocalRequest -Context $context)) {
                Write-TextResponse -Context $context -StatusCode 403 -Body "Local requests only"
                continue
            }
            $shutdownAt = $null
            $context.Response.StatusCode = 204
            $context.Response.OutputStream.Close()
            continue
        }

        if ($request.Url.AbsolutePath -eq "/__dashboard/shutdown" -and $request.HttpMethod -eq "POST") {
            if (-not (Is-LocalRequest -Context $context)) {
                Write-TextResponse -Context $context -StatusCode 403 -Body "Local requests only"
                continue
            }
            $shutdownAt = (Get-Date).AddSeconds(3)
            Write-TextResponse -Context $context -StatusCode 202 -Body "shutdown scheduled"
            continue
        }

        if ($request.Url.AbsolutePath -eq "/__dashboard/inject" -and $request.HttpMethod -eq "POST") {
            if (-not (Is-LocalRequest -Context $context)) {
                Write-JsonResponse -Context $context -StatusCode 403 -Payload @{ ok = $false; error = "Local requests only" }
                continue
            }
            try {
                Invoke-InjectAccount -Context $context
            } catch {
                Write-JsonResponse -Context $context -StatusCode 500 -Payload @{ ok = $false; error = "Unexpected server error: $($_.Exception.Message)" }
            }
            continue
        }

        if ($request.Url.AbsolutePath -eq "/__dashboard/accounts-data" -and $request.HttpMethod -eq "GET") {
            if (-not (Is-LocalRequest -Context $context)) {
                Write-JsonResponse -Context $context -StatusCode 403 -Payload @{ ok = $false; error = "Local requests only" }
                continue
            }
            try {
                Invoke-LoadAccountData -Context $context
            } catch {
                Write-JsonResponse -Context $context -StatusCode 500 -Payload @{ ok = $false; error = "Unexpected server error: $($_.Exception.Message)" }
            }
            continue
        }

        if ($request.Url.AbsolutePath -eq "/__dashboard/instances" -and $request.HttpMethod -eq "GET") {
            if (-not (Is-LocalRequest -Context $context)) {
                Write-JsonResponse -Context $context -StatusCode 403 -Payload @{ ok = $false; error = "Local requests only" }
                continue
            }
            try {
                Invoke-ListInstances -Context $context
            } catch {
                Write-JsonResponse -Context $context -StatusCode 500 -Payload @{ ok = $false; error = "Unexpected server error: $($_.Exception.Message)" }
            }
            continue
        }

        if ($request.Url.AbsolutePath -eq "/__dashboard/launch-instance" -and $request.HttpMethod -eq "POST") {
            if (-not (Is-LocalRequest -Context $context)) {
                Write-JsonResponse -Context $context -StatusCode 403 -Payload @{ ok = $false; error = "Local requests only" }
                continue
            }
            try {
                Invoke-LaunchInstance -Context $context
            } catch {
                Write-JsonResponse -Context $context -StatusCode 500 -Payload @{ ok = $false; error = "Unexpected server error: $($_.Exception.Message)" }
            }
            continue
        }

        if ($request.HttpMethod -ne "GET") {
            Write-TextResponse -Context $context -StatusCode 405 -Body "Method not allowed"
            continue
        }

        $resolved = Resolve-RequestedPath -RawUrl $request.RawUrl
        if (-not $resolved -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            Write-TextResponse -Context $context -StatusCode 404 -Body "Not found"
            continue
        }

        try {
            $bytes = [System.IO.File]::ReadAllBytes($resolved)
            $extension = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
            $contentType = if ($mimeMap.ContainsKey($extension)) { $mimeMap[$extension] } else { "application/octet-stream" }

            $response = $context.Response
            $response.StatusCode = 200
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
        }
        catch {
            Write-TextResponse -Context $context -StatusCode 500 -Body "Server error"
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
