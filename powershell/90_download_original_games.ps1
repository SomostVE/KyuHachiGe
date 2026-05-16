# 90_download_original_games.ps1
# KyuHachiGe original games downloader
# Internal game version ZIPs such as FD/HD/CD remain zipped.

$ErrorActionPreference = "Stop"

try {
    chcp 65001 > $null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Net.ServicePointManager]::SecurityProtocol = 3072
} catch {}

function Show-Banner {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  ____   ____        ___   ___" -ForegroundColor Cyan
    Write-Host " |  _ \ / ___|      / _ \ ( _ )" -ForegroundColor Cyan
    Write-Host " | |_) | |   _____ | (_) |/ _ \" -ForegroundColor Cyan
    Write-Host " |  __/| |__|_____  \__, | (_) |" -ForegroundColor Cyan
    Write-Host " |_|    \____|       /_/  \___/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                    KyuHachiGe" -ForegroundColor Yellow
    Write-Host "      NEC PC-98 ENGLISH GAME LIBRARY BUILDER" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-KyuHachiGePaths {
    $currentScriptDir = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($currentScriptDir)) {
        $currentScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $leaf = Split-Path -Leaf $currentScriptDir

    if ($leaf -ieq "powershell") {
        $scriptDir = Split-Path -Parent $currentScriptDir
    } else {
        $scriptDir = $currentScriptDir
    }

    $root = (Resolve-Path (Join-Path $scriptDir "..")).Path

    return [pscustomobject]@{
        PowerShell = $currentScriptDir
        Script = $scriptDir
        Root = $root
        Emulator = Join-Path $root "emulator"
        Frontend = Join-Path $root "frontend"
        PC98 = Join-Path $root "PC98"
        PC98Patched = Join-Path $root "PC98 Patched"
    }
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK]      $Message" -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN]    $Message" -ForegroundColor Yellow
}

function Write-Missing {
    param([string]$Message)
    Write-Host "[MISSING] $Message" -ForegroundColor Red
}

function Write-InfoLine {
    param([string]$Message)
    Write-Host "[INFO]    $Message" -ForegroundColor Cyan
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        [System.IO.Directory]::CreateDirectory($Path) | Out-Null
    }
}

function Sanitize-Name {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "Unknown"
    }

    $Name = [System.Net.WebUtility]::HtmlDecode($Name)
    $Name = $Name.Replace("[", "(")
    $Name = $Name.Replace("]", ")")

    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $Name = $Name.Replace([string]$char, "_")
    }

    $Name = $Name -replace "\s+", " "
    $Name = $Name.Trim().Trim(".")

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "Unknown"
    }

    if ($Name.Length -gt 180) {
        $ext = [System.IO.Path]::GetExtension($Name)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)

        if ($base.Length -gt 160) {
            $base = $base.Substring(0, 160).Trim().Trim(".")
        }

        $Name = "$base$ext"
    }

    return $Name
}

function ConvertTo-ArchiveUrlPath {
    param([string]$Path)

    return (($Path -split "/") | ForEach-Object {
        [Uri]::EscapeDataString($_)
    }) -join "/"
}

function Get-ErrorText {
    param($ErrorRecord)

    $message = $ErrorRecord.Exception.Message

    try {
        if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) {
            $statusCode = [int]$ErrorRecord.Exception.Response.StatusCode
            $statusText = $ErrorRecord.Exception.Response.StatusDescription
            return "HTTP $statusCode $statusText - $message"
        }
    } catch {}

    return $message
}

function Invoke-JsonRequest {
    param([string]$Uri)

    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0 Safari/537.36"
        "Accept" = "application/json,text/plain,*/*"
    }

    return Invoke-RestMethod -Uri $Uri -Headers $headers -TimeoutSec 90 -ErrorAction Stop
}

function Download-FileSafe {
    param(
        [string]$Uri,
        [string]$OutFile
    )

    Ensure-Directory (Split-Path -Parent $OutFile)

    $partial = "$OutFile.part"

    if (Test-Path -LiteralPath $partial -PathType Leaf) {
        Remove-Item -LiteralPath $partial -Force
    }

    $params = @{
        Uri = $Uri
        OutFile = $partial
        Headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0 Safari/537.36"
            "Accept" = "*/*"
        }
        TimeoutSec = 1800
        ErrorAction = "Stop"
    }

    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $params.UseBasicParsing = $true
    }

    Invoke-WebRequest @params

    if (Test-Path -LiteralPath $OutFile -PathType Leaf) {
        Remove-Item -LiteralPath $OutFile -Force
    }

    Move-Item -LiteralPath $partial -Destination $OutFile -Force
}

function Read-YesNo {
    param([string]$Question)

    while ($true) {
        $answer = Read-Host "$Question [y/n]"
        $answer = $answer.Trim().ToLowerInvariant()

        if ($answer -in @("y", "yes")) {
            return $true
        }

        if ($answer -in @("n", "no")) {
            return $false
        }

        Write-WarnLine "Please answer y or n."
    }
}

$OriginalArchiveIdentifier = "NeoKobe-NecPc-98012017-11-17"
$OriginalMetadataUrl = "https://archive.org/metadata/$OriginalArchiveIdentifier"
$OriginalDetailsUrl = "https://archive.org/details/$OriginalArchiveIdentifier"

function Get-ArchiveDownloadUrl {
    param(
        [string]$Identifier,
        [string]$ArchivePath
    )

    return "https://archive.org/download/$Identifier/$(ConvertTo-ArchiveUrlPath $ArchivePath)"
}

function Test-IsWhateverArchive {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    $n = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $n = [System.Net.WebUtility]::HtmlDecode($n)
    $n = $n.ToLowerInvariant()

    return (
        $n -match '(^|[\s\-_\.])(bios|bio)([\s\-_\.]|$)' -or
        $n -match '(^|[\s\-_\.])(os|dos|ms-dos|system|systems)([\s\-_\.]|$)' -or
        $n -match '(^|[\s\-_\.])(utility|utilities|tool|tools|driver|drivers)([\s\-_\.]|$)' -or
        $n -match '(^|[\s\-_\.])(ea)([\s\-_\.]|$)' -or
        $n -match 'electronic[\s\-_\.]*arts' -or
        $n -match 'microsoft'
    )
}

function Test-IsWantedOriginalStudioZip {
    param($FileObject)

    if ($null -eq $FileObject) {
        return $false
    }

    $archivePath = [string]$FileObject.name

    if ([string]::IsNullOrWhiteSpace($archivePath)) {
        return $false
    }

    $normalized = $archivePath.Replace("\", "/")
    $lower = $normalized.ToLowerInvariant()

    $format = ""

    try {
        $format = ([string]$FileObject.format).ToLowerInvariant()
    } catch {}

    $isZip = $lower.EndsWith(".zip") -or ($format -eq "zip")

    if (-not $isZip) {
        return $false
    }

    # The original collection uses top-level ZIPs as studio/archive containers.
    # Sub-paths are ignored here to avoid treating internal files as studio archives.
    if ($normalized.Contains("/")) {
        return $false
    }

    return $true
}

function Get-OriginalStudioZipList {
    $metadata = Invoke-JsonRequest $OriginalMetadataUrl

    return @($metadata.files |
        Where-Object { Test-IsWantedOriginalStudioZip $_ } |
        Sort-Object name)
}

function Get-LocalStudioZipName {
    param([string]$ArchivePath)

    $leaf = [System.IO.Path]::GetFileName($ArchivePath)
    $safeLeaf = Sanitize-Name $leaf

    if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($safeLeaf))) {
        $safeLeaf = "$safeLeaf.zip"
    }

    return $safeLeaf
}

function Get-UniqueDestination {
    param(
        [string]$Path,
        [bool]$IsDirectory
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Path
    }

    $parent = Split-Path -Parent $Path

    if ($IsDirectory) {
        $name = Split-Path -Leaf $Path
        $ext = ""
    } else {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $ext = [System.IO.Path]::GetExtension($Path)
    }

    $i = 2

    while ($true) {
        $candidate = Join-Path $parent "$name ($i)$ext"

        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }

        $i++
    }
}

function Test-IsSpecialFolderName {
    param([string]$Name)

    $n = $Name.ToLowerInvariant()
    return ($n -match '^(bios|system|systems|os|dos|utility|utilities|tools?|drivers?|manuals?|materials?|extras?|docs?|documentation|whatever)$')
}

function Test-IsGameVersionZipName {
    param([string]$Name)

    $n = $Name.ToLowerInvariant()
    return (
        $n -match '\[(hd|fd|cd|hdd|hdi|fdd)\]' -or
        $n -match '\((hd|fd|cd|hdd|hdi|fdd)\)' -or
        $n -match '\b(hd|fd|cd|hdd|hdi|fdd)\b'
    )
}

function Test-FolderLooksLikeGameFolder {
    param([string]$FolderPath)

    $versionZip = Get-ChildItem -LiteralPath $FolderPath -File -Filter "*.zip" -ErrorAction SilentlyContinue |
        Where-Object { Test-IsGameVersionZipName $_.Name } |
        Select-Object -First 1

    if ($versionZip) {
        return $true
    }

    $anyImage = Get-ChildItem -LiteralPath $FolderPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @(".hdi", ".hdd", ".nhd", ".fdi", ".d88", ".hdm", ".xdf", ".nfd", ".fdd", ".iso", ".cue", ".ccd") } |
        Select-Object -First 1

    return ($null -ne $anyImage)
}

function Fix-DuplicatedNestedFolder {
    param([string]$FolderPath)

    $folderName = Split-Path -Leaf $FolderPath
    $inner = Join-Path $FolderPath $folderName

    if (-not (Test-Path -LiteralPath $inner -PathType Container)) {
        return
    }

    $outside = @(Get-ChildItem -LiteralPath $FolderPath -Force | Where-Object { $_.FullName -ne $inner })

    if ($outside.Count -gt 0) {
        return
    }

    Get-ChildItem -LiteralPath $inner -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $FolderPath
    }

    Remove-Item -LiteralPath $inner -Force
}

function Expose-GameFoldersFromStudioFolder {
    param(
        [string]$StudioFolder,
        [string]$Pc98Root
    )

    if (-not (Test-Path -LiteralPath $StudioFolder -PathType Container)) {
        return 0
    }

    Fix-DuplicatedNestedFolder -FolderPath $StudioFolder

    $moved = 0

    $topIsGame = Test-FolderLooksLikeGameFolder $StudioFolder

    if ($topIsGame) {
        return 0
    }

    $children = Get-ChildItem -LiteralPath $StudioFolder -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsSpecialFolderName $_.Name) -and
            (Test-FolderLooksLikeGameFolder $_.FullName)
        }

    foreach ($child in $children) {
        $dest = Join-Path $Pc98Root $child.Name
        $dest = Get-UniqueDestination -Path $dest -IsDirectory $true

        Move-Item -LiteralPath $child.FullName -Destination $dest
        $moved++
    }

    $remaining = @(Get-ChildItem -LiteralPath $StudioFolder -Force -ErrorAction SilentlyContinue)

    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $StudioFolder -Force
    }

    return $moved
}

Show-Banner

$paths = Get-KyuHachiGePaths

Write-WarnLine "This option downloads the original/raw PC-98 collection."
Write-WarnLine "It is large (80 GB)."
Write-Host ""
Write-InfoLine "Source:"
Write-Host "          $OriginalDetailsUrl"
Write-InfoLine "Output:"
Write-Host "          $($paths.PC98)"
Write-Host ""

$confirm = Read-YesNo "Continue with original games download?"

if (-not $confirm) {
    Write-WarnLine "Canceled."
    exit 0
}

Ensure-Directory $paths.PC98

try {
    $studioZips = Get-OriginalStudioZipList
} catch {
    Write-Missing "Could not read Archive.org metadata: $(Get-ErrorText $_)"
    exit 1
}

if ($studioZips.Count -eq 0) {
    Write-WarnLine "No studio ZIP file found."
    exit 0
}

Write-Ok "Studio ZIP files selected: $($studioZips.Count)"
Write-Host ""

$index = 0
$downloaded = 0
$skipped = 0
$extracted = 0
$movedGames = 0
$whateverKept = 0
$failed = 0

Add-Type -AssemblyName System.IO.Compression.FileSystem

foreach ($file in $studioZips) {
    $index++

    $archivePath = [string]$file.name
    $remoteLeaf = [System.IO.Path]::GetFileName($archivePath)
    $safeLeaf = Get-LocalStudioZipName $archivePath
    $studioName = [System.IO.Path]::GetFileNameWithoutExtension($safeLeaf)
    $downloadUrl = Get-ArchiveDownloadUrl -Identifier $OriginalArchiveIdentifier -ArchivePath $archivePath

    Write-InfoLine "[$index/$($studioZips.Count)] $remoteLeaf"

    if (Test-IsWhateverArchive $remoteLeaf) {
        $whateverRoot = Join-Path $paths.PC98 "whatever"
        Ensure-Directory $whateverRoot

        $whateverZip = Join-Path $whateverRoot $safeLeaf

        try {
            if (Test-Path -LiteralPath $whateverZip -PathType Leaf) {
                Write-WarnLine "Already present in whatever, skipped: $safeLeaf"
                $skipped++
                continue
            }

            Download-FileSafe -Uri $downloadUrl -OutFile $whateverZip
            $downloaded++
            $whateverKept++
            Write-Ok "Downloaded to whatever without extraction: $safeLeaf"
            continue
        } catch {
            $failed++
            Write-Missing "Failed: $(Get-ErrorText $_)"
            continue
        }
    }

    $localZip = Join-Path $paths.PC98 $safeLeaf
    $studioFolder = Join-Path $paths.PC98 $studioName

    try {
        if (Test-Path -LiteralPath $studioFolder -PathType Container) {
            Write-WarnLine "Studio folder already exists, skipped: $studioName"
            $skipped++
            continue
        }

        Download-FileSafe -Uri $downloadUrl -OutFile $localZip
        $downloaded++
        Write-Ok "Downloaded: $safeLeaf"

        Ensure-Directory $studioFolder
        [System.IO.Compression.ZipFile]::ExtractToDirectory($localZip, $studioFolder)
        $extracted++
        Write-Ok "Extracted: $studioName"

        Remove-Item -LiteralPath $localZip -Force
        Write-Ok "Deleted archive ZIP after successful extraction."

        $moved = Expose-GameFoldersFromStudioFolder -StudioFolder $studioFolder -Pc98Root $paths.PC98
        $movedGames += $moved

        if ($moved -gt 0) {
            Write-Ok "Moved game folders to PC98 root: $moved"
        }
    } catch {
        $failed++
        Write-Missing "Failed: $(Get-ErrorText $_)"
        Write-WarnLine "If a ZIP remains, it was kept because the process failed."
    }
}

Write-Host ""
Write-Ok "Original games download completed."
Write-Host "Downloaded:              $downloaded"
Write-Host "Skipped:                 $skipped"
Write-Host "Extracted studios:       $extracted"
Write-Host "Moved games:             $movedGames"
Write-Host "Kept in whatever as ZIP: $whateverKept"
Write-Host "Failed:                  $failed"

Write-Host "Moved games:       $movedGames"
Write-Host "Failed:            $failed"
