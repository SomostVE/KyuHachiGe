# 01_download_patched_library.ps1
# KyuHachiGe patched library downloader
# Downloads ready-to-use patched game ZIPs into PC98 Patched.
# No extraction is performed because Playnite can scan ZIP files directly.

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


function Write-Ok { param([string]$Message) Write-Host "[OK]      $Message" -ForegroundColor Green }
function Write-WarnLine { param([string]$Message) Write-Host "[WARN]    $Message" -ForegroundColor Yellow }
function Write-Missing { param([string]$Message) Write-Host "[MISSING] $Message" -ForegroundColor Red }
function Write-InfoLine { param([string]$Message) Write-Host "[INFO]    $Message" -ForegroundColor Cyan }

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


$PatchedArchiveIdentifier = "nec-pc-9801-translations"
$PatchedMetadataUrl = "https://archive.org/metadata/$PatchedArchiveIdentifier"
$PatchedDownloadBase = "https://archive.org/download/$PatchedArchiveIdentifier"
$PatchedDetailsUrl = "https://archive.org/details/$PatchedArchiveIdentifier"

function Test-IsWantedPatchedZip {
    param([string]$ArchivePath)

    if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
        return $false
    }

    $normalized = $ArchivePath.Replace("\", "/")
    $lower = $normalized.ToLowerInvariant()

    if (-not $lower.EndsWith(".zip")) {
        return $false
    }

    if ($lower.StartsWith("hacks/")) {
        return $false
    }

    if ($lower.StartsWith("incomplete/")) {
        return $false
    }

    return $true
}

function Get-PatchedZipList {
    $metadata = Invoke-JsonRequest $PatchedMetadataUrl

    return @($metadata.files |
        Where-Object { Test-IsWantedPatchedZip ([string]$_.name) } |
        Sort-Object name)
}

function Get-RemoteSize {
    param($FileObject)

    $remoteSize = 0
    try {
        [void][Int64]::TryParse([string]$FileObject.size, [ref]$remoteSize)
    } catch {}

    return $remoteSize
}

function Get-LocalPatchedZipPath {
    param(
        $Paths,
        [string]$ArchivePath
    )

    $leaf = [System.IO.Path]::GetFileName($ArchivePath)
    $safeLeaf = Sanitize-Name $leaf
    return Join-Path $Paths.PC98Patched $safeLeaf
}

function Get-ArchiveDownloadUrl {
    param(
        [string]$Identifier,
        [string]$ArchivePath
    )

    return "https://archive.org/download/$Identifier/$(ConvertTo-ArchiveUrlPath $ArchivePath)"
}


Show-Banner

$paths = Get-KyuHachiGePaths

Ensure-Directory $paths.PC98Patched

Write-InfoLine "Source:"
Write-Host "          $PatchedDetailsUrl"
Write-InfoLine "Output:"
Write-Host "          $($paths.PC98Patched)"
Write-Host ""

$confirm = Read-YesNo "Download patched library ZIPs now?"

if (-not $confirm) {
    Write-WarnLine "Canceled."
    exit 0
}

try {
    $zipFiles = Get-PatchedZipList
} catch {
    Write-Missing "Could not read Archive.org metadata: $(Get-ErrorText $_)"
    exit 1
}

if ($zipFiles.Count -eq 0) {
    Write-WarnLine "No patched ZIP file found."
    exit 0
}

Write-Ok "Patched ZIP files selected: $($zipFiles.Count)"
Write-Host ""

$index = 0
$downloaded = 0
$skipped = 0
$replaced = 0
$failed = 0

foreach ($file in $zipFiles) {
    $index++

    $archivePath = [string]$file.name
    $remoteLeaf = [System.IO.Path]::GetFileName($archivePath)
    $localZip = Get-LocalPatchedZipPath -Paths $paths -ArchivePath $archivePath
    $downloadUrl = Get-ArchiveDownloadUrl -Identifier $PatchedArchiveIdentifier -ArchivePath $archivePath
    $remoteSize = Get-RemoteSize $file

    Write-InfoLine "[$index/$($zipFiles.Count)] $remoteLeaf"

    try {
        if (Test-Path -LiteralPath $localZip -PathType Leaf) {
            $localSize = (Get-Item -LiteralPath $localZip).Length

            if ($remoteSize -gt 0 -and $localSize -ne $remoteSize) {
                Write-WarnLine "Size mismatch. Replacing local ZIP."
                Download-FileSafe -Uri $downloadUrl -OutFile $localZip
                $replaced++
                Write-Ok "Replaced: $localZip"
            } else {
                Write-WarnLine "Already present, skipped."
                $skipped++
            }
        } else {
            Download-FileSafe -Uri $downloadUrl -OutFile $localZip
            $downloaded++
            Write-Ok "Downloaded: $localZip"
        }
    } catch {
        $failed++
        Write-Missing "Failed: $(Get-ErrorText $_)"
    }
}

Write-Host ""
Write-Ok "Patched library download completed."
Write-Host "Downloaded: $downloaded"
Write-Host "Replaced:   $replaced"
Write-Host "Skipped:    $skipped"
Write-Host "Failed:     $failed"
