# 90_download_original_games.ps1
# KyuHachiGe original games downloader
# Internal game version ZIPs such as FD/HD/CD remain zipped.
#
# Current logic:
# - 1 external ZIP = 1 studio/archive group.
# - Normal studio ZIPs are extracted into PC98\StudioName.
# - The studio folder is kept. Games are NOT moved out of the studio folder.
# - Example: PC98\Alice Soft\GameName\GameName [HD].zip
# - The outer studio ZIP is deleted after successful extraction.
# - BIOS / OS / Utilities / EA / Electronic Arts / Microsoft archives are kept as ZIP files in PC98\whatever.
# - The script checks Archive.org ZIP entries against the local PC98 folder and skips what already exists.

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

function Get-RemoteSize {
    param($FileObject)

    $remoteSize = 0

    try {
        [void][Int64]::TryParse([string]$FileObject.size, [ref]$remoteSize)
    } catch {}

    return $remoteSize
}

function Test-FileSizeMatches {
    param(
        [string]$Path,
        [Int64]$RemoteSize
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    if ($RemoteSize -le 0) {
        return $true
    }

    return ((Get-Item -LiteralPath $Path).Length -eq $RemoteSize)
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

function Get-StudioFolderName {
    param([string]$SafeLeaf)

    return [System.IO.Path]::GetFileNameWithoutExtension($SafeLeaf)
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
    Write-Ok "Fixed duplicated nested folder: $folderName\$folderName"
}

function Get-ArchiveStatus {
    param(
        $Paths,
        $FileObject
    )

    $archivePath = [string]$FileObject.name
    $remoteLeaf = [System.IO.Path]::GetFileName($archivePath)
    $safeLeaf = Get-LocalStudioZipName $archivePath
    $studioName = Get-StudioFolderName $safeLeaf
    $downloadUrl = Get-ArchiveDownloadUrl -Identifier $OriginalArchiveIdentifier -ArchivePath $archivePath
    $remoteSize = Get-RemoteSize $FileObject
    $isWhatever = Test-IsWhateverArchive $remoteLeaf

    if ($isWhatever) {
        $whateverRoot = Join-Path $Paths.PC98 "whatever"
        $whateverZip = Join-Path $whateverRoot $safeLeaf
        $whateverPart = "$whateverZip.part"

        if (Test-FileSizeMatches -Path $whateverZip -RemoteSize $remoteSize) {
            $status = "Complete"
        } elseif (Test-Path -LiteralPath $whateverZip -PathType Leaf) {
            $status = "IncompleteZip"
        } elseif (Test-Path -LiteralPath $whateverPart -PathType Leaf) {
            $status = "PartialDownload"
        } else {
            $status = "Missing"
        }

        return [pscustomobject]@{
            ArchivePath = $archivePath
            RemoteLeaf = $remoteLeaf
            SafeLeaf = $safeLeaf
            StudioName = $studioName
            DownloadUrl = $downloadUrl
            RemoteSize = $remoteSize
            IsWhatever = $true
            LocalZip = $whateverZip
            StudioFolder = ""
            Status = $status
        }
    }

    $localZip = Join-Path $Paths.PC98 $safeLeaf
    $localPart = "$localZip.part"
    $studioFolder = Join-Path $Paths.PC98 $studioName

    if (Test-Path -LiteralPath $studioFolder -PathType Container) {
        $status = "Complete"
    } elseif (Test-FileSizeMatches -Path $localZip -RemoteSize $remoteSize) {
        $status = "ZipReadyToExtract"
    } elseif (Test-Path -LiteralPath $localZip -PathType Leaf) {
        $status = "IncompleteZip"
    } elseif (Test-Path -LiteralPath $localPart -PathType Leaf) {
        $status = "PartialDownload"
    } else {
        $status = "Missing"
    }

    return [pscustomobject]@{
        ArchivePath = $archivePath
        RemoteLeaf = $remoteLeaf
        SafeLeaf = $safeLeaf
        StudioName = $studioName
        DownloadUrl = $downloadUrl
        RemoteSize = $remoteSize
        IsWhatever = $false
        LocalZip = $localZip
        StudioFolder = $studioFolder
        Status = $status
    }
}

function Process-Archive {
    param(
        $Paths,
        $Item
    )

    if ($Item.IsWhatever) {
        $whateverRoot = Join-Path $Paths.PC98 "whatever"
        Ensure-Directory $whateverRoot

        if ($Item.Status -eq "Complete") {
            Write-WarnLine "Already present in whatever, skipped: $($Item.SafeLeaf)"
            return [pscustomobject]@{ Downloaded = 0; Extracted = 0; Fixed = 0; WhateverKept = 0; Skipped = 1 }
        }

        if (Test-Path -LiteralPath "$($Item.LocalZip).part" -PathType Leaf) {
            Remove-Item -LiteralPath "$($Item.LocalZip).part" -Force
        }

        if ($Item.Status -eq "IncompleteZip" -and (Test-Path -LiteralPath $Item.LocalZip -PathType Leaf)) {
            Remove-Item -LiteralPath $Item.LocalZip -Force
        }

        Download-FileSafe -Uri $Item.DownloadUrl -OutFile $Item.LocalZip
        Write-Ok "Downloaded to whatever without extraction: $($Item.SafeLeaf)"

        return [pscustomobject]@{ Downloaded = 1; Extracted = 0; Fixed = 0; WhateverKept = 1; Skipped = 0 }
    }

    if ($Item.Status -eq "Complete") {
        Write-WarnLine "Studio folder already exists, skipped: $($Item.StudioName)"
        return [pscustomobject]@{ Downloaded = 0; Extracted = 0; Fixed = 0; WhateverKept = 0; Skipped = 1 }
    }

    if ($Item.Status -eq "PartialDownload") {
        Remove-Item -LiteralPath "$($Item.LocalZip).part" -Force
    }

    if ($Item.Status -eq "IncompleteZip" -and (Test-Path -LiteralPath $Item.LocalZip -PathType Leaf)) {
        Remove-Item -LiteralPath $Item.LocalZip -Force
    }

    $downloaded = 0

    if ($Item.Status -ne "ZipReadyToExtract") {
        Download-FileSafe -Uri $Item.DownloadUrl -OutFile $Item.LocalZip
        $downloaded = 1
        Write-Ok "Downloaded: $($Item.SafeLeaf)"
    } else {
        Write-Ok "Using already downloaded ZIP: $($Item.SafeLeaf)"
    }

    if (Test-Path -LiteralPath $Item.StudioFolder -PathType Container) {
        Remove-Item -LiteralPath $Item.StudioFolder -Recurse -Force
    }

    Ensure-Directory $Item.StudioFolder

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Item.LocalZip, $Item.StudioFolder)
    } catch {
        if (Test-Path -LiteralPath $Item.StudioFolder -PathType Container) {
            Remove-Item -LiteralPath $Item.StudioFolder -Recurse -Force
        }

        throw
    }

    Write-Ok "Extracted studio folder: $($Item.StudioName)"

    Remove-Item -LiteralPath $Item.LocalZip -Force
    Write-Ok "Deleted archive ZIP after successful extraction."

    $beforeFix = (Get-ChildItem -LiteralPath $Item.StudioFolder -Force -ErrorAction SilentlyContinue | Measure-Object).Count
    Fix-DuplicatedNestedFolder -FolderPath $Item.StudioFolder
    $afterFix = (Get-ChildItem -LiteralPath $Item.StudioFolder -Force -ErrorAction SilentlyContinue | Measure-Object).Count

    $fixed = 0
    if ($beforeFix -ne $afterFix) {
        $fixed = 1
    }

    return [pscustomobject]@{ Downloaded = $downloaded; Extracted = 1; Fixed = $fixed; WhateverKept = 0; Skipped = 0 }
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

$items = New-Object System.Collections.Generic.List[object]

foreach ($file in $studioZips) {
    $items.Add((Get-ArchiveStatus -Paths $paths -FileObject $file)) | Out-Null
}

$completeItems = @($items | Where-Object { $_.Status -eq "Complete" })
$toProcess = @($items | Where-Object { $_.Status -ne "Complete" })
$missingItems = @($items | Where-Object { $_.Status -eq "Missing" })
$readyItems = @($items | Where-Object { $_.Status -eq "ZipReadyToExtract" })
$partialItems = @($items | Where-Object { $_.Status -eq "PartialDownload" -or $_.Status -eq "IncompleteZip" })

Write-Host "Status summary" -ForegroundColor Cyan
Write-Host "--------------" -ForegroundColor Cyan
Write-Host "Remote ZIP files:            $($items.Count)"
Write-Host "Already complete:            $($completeItems.Count)"
Write-Host "Missing:                     $($missingItems.Count)"
Write-Host "Downloaded ZIPs to extract:  $($readyItems.Count)"
Write-Host "Partial/incomplete ZIPs:     $($partialItems.Count)"
Write-Host "Items to process:            $($toProcess.Count)"
Write-Host ""

if ($toProcess.Count -eq 0) {
    Write-Ok "Original/raw PC-98 library appears complete."
    exit 0
}

$resume = Read-YesNo "Resume/download missing original games now?"

if (-not $resume) {
    Write-WarnLine "Canceled."
    exit 0
}

Write-Host ""

$index = 0
$downloaded = 0
$skipped = 0
$extracted = 0
$fixedFolders = 0
$whateverKept = 0
$failed = 0

Add-Type -AssemblyName System.IO.Compression.FileSystem

foreach ($item in $toProcess) {
    $index++

    Write-InfoLine "[$index/$($toProcess.Count)] $($item.RemoteLeaf)"

    try {
        $result = Process-Archive -Paths $paths -Item $item

        $downloaded += $result.Downloaded
        $skipped += $result.Skipped
        $extracted += $result.Extracted
        $fixedFolders += $result.Fixed
        $whateverKept += $result.WhateverKept
    } catch {
        $failed++
        Write-Missing "Failed: $(Get-ErrorText $_)"
        Write-WarnLine "If a ZIP remains, it was kept because the process failed."
    }
}

Write-Host ""
Write-Ok "Original games download/resume completed."
Write-Host "Downloaded:              $downloaded"
Write-Host "Skipped:                 $skipped"
Write-Host "Extracted studios:       $extracted"
Write-Host "Fixed nested folders:    $fixedFolders"
Write-Host "Kept in whatever as ZIP: $whateverKept"
Write-Host "Failed:                  $failed"
