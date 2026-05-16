# 00_check_environment.ps1
# KyuHachiGe environment checker

$ErrorActionPreference = "Stop"

try {
    chcp 65001 > $null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
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


Show-Banner

$paths = Get-KyuHachiGePaths

Write-InfoLine "Detected root:"
Write-Host "          $($paths.Root)"
Write-Host ""

Write-Host "Required base folders" -ForegroundColor Cyan
Write-Host "---------------------" -ForegroundColor Cyan

Ensure-Directory $paths.Emulator
Write-Ok $paths.Emulator

Ensure-Directory $paths.Frontend
Write-Ok $paths.Frontend

Ensure-Directory $paths.PowerShell
Write-Ok $paths.PowerShell

Write-Host ""
Write-Host "Optional libraries" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan

if (Test-Path -LiteralPath $paths.PC98 -PathType Container) {
    Write-Ok "Original library folder exists: $($paths.PC98)"
} else {
    Write-InfoLine "Original library folder not present. It is created only by [O] Download original games."
}

if (Test-Path -LiteralPath $paths.PC98Patched -PathType Container) {
    Write-Ok "Patched library folder exists: $($paths.PC98Patched)"
} else {
    Write-InfoLine "Patched library folder not present. It is created by [2] Download patched library."
}

Write-Host ""
Write-Host "PowerShell scripts" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan

$requiredPs = @(
    "00_check_environment.ps1",
    "01_download_patched_library.ps1",
    "02_check_patched_games_update.ps1",
    "90_download_original_games.ps1"
)

foreach ($file in $requiredPs) {
    $path = Join-Path $paths.PowerShell $file

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Write-Ok $file
    } else {
        Write-Missing $file
    }
}

Write-Host ""
Write-Host "Optional frontend/emulation" -ForegroundColor Cyan
Write-Host "---------------------------" -ForegroundColor Cyan

$retroArchCandidates = @(
    (Join-Path $paths.Emulator "RetroArch-Win64\retroarch.exe"),
    (Join-Path $paths.Emulator "RetroArch\retroarch.exe"),
    (Join-Path $paths.Emulator "retroarch.exe")
)

$retro = $retroArchCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

if ($retro) {
    Write-Ok "RetroArch detected: $retro"
} else {
    Write-WarnLine "RetroArch not detected. Use menu option [5] to open the official download page."
}

$coreCandidates = @(
    (Join-Path $paths.Emulator "RetroArch-Win64\cores\np2kai_libretro.dll"),
    (Join-Path $paths.Emulator "RetroArch\cores\np2kai_libretro.dll"),
    (Join-Path $paths.Emulator "cores\np2kai_libretro.dll")
)

$core = $coreCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

if ($core) {
    Write-Ok "Neko Project II Kai core detected: $core"
} else {
    Write-WarnLine "np2kai_libretro.dll not detected. Install the NEC PC-98 core in RetroArch."
}

Write-Host ""
Write-Ok "Environment check completed."
