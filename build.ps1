[CmdletBinding()]
param(
    [string]$PythonExe = "python",
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail($Message) {
    Write-Error $Message
    exit 1
}

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Required command not found: $Name"
    }
}

function Resolve-Iscc {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }

    $cmd = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    Fail "ISCC.exe not found. Install Inno Setup 6 or add ISCC.exe to PATH."
}

function Invoke-Step([string]$Label, [scriptblock]$Action) {
    Write-Host "==> $Label"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Fail "$Label failed with exit code $LASTEXITCODE"
    }
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $RepoRoot

try {
    Require-Command $PythonExe
    $IsccExe = Resolve-Iscc

    $VenvDir = Join-Path $RepoRoot ".venv"
    $BuildDir = Join-Path $RepoRoot "build"
    $DistDir = Join-Path $RepoRoot "dist"
    $OutputDir = Join-Path $RepoRoot "output"
    $SpecFile = Join-Path $RepoRoot "gerber2font.spec"
    $InstallerFile = Join-Path $RepoRoot "installer.iss"
    $RequirementsFile = Join-Path $RepoRoot "requirements.txt"
    $IconFile = Join-Path $RepoRoot "app.ico"

    if (-not (Test-Path $RequirementsFile)) { Fail "Missing requirements.txt" }
    if (-not (Test-Path $SpecFile)) { Fail "Missing gerber2font.spec" }
    if (-not (Test-Path $InstallerFile)) { Fail "Missing installer.iss" }
    if (-not (Test-Path (Join-Path $RepoRoot "gerber2font.py"))) { Fail "Missing gerber2font.py" }
    if (-not (Test-Path (Join-Path $RepoRoot "README.md"))) { Fail "Missing README.md" }
    if (-not (Test-Path (Join-Path $RepoRoot "LICENSE"))) { Fail "Missing LICENSE" }

    Write-Host "Cleaning previous build artifacts..."
    Remove-Item $VenvDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $DistDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $OutputDir -Recurse -Force -ErrorAction SilentlyContinue

    Invoke-Step "Create virtual environment" {
        & $PythonExe -m venv $VenvDir
    }

    $VenvPython = Join-Path $VenvDir "Scripts\python.exe"
    if (-not (Test-Path $VenvPython)) {
        Fail "Virtual environment Python not found at $VenvPython"
    }

    Invoke-Step "Upgrade pip" {
        & $VenvPython -m pip install --upgrade pip
    }

    Invoke-Step "Install dependencies" {
        & $VenvPython -m pip install -r $RequirementsFile pyinstaller
    }

    Invoke-Step "Build one-file executable with PyInstaller" {
        & $VenvPython -m PyInstaller --clean --noconfirm $SpecFile
    }

    $BuiltExe = Join-Path $DistDir "gerber2font.exe"
    if (-not (Test-Path $BuiltExe)) {
        Fail "PyInstaller output not found: $BuiltExe"
    }

    $InnoArgs = @(
        "/DSourceDir=$RepoRoot",
        "/DDistDir=$DistDir",
        "/DOutputDir=$OutputDir",
        "/DAppVersion=$Version"
    )

    if (Test-Path $IconFile) {
        $InnoArgs += "/DIconFile=$IconFile"
    }

    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    Invoke-Step "Compile Inno Setup installer" {
        & $IsccExe @InnoArgs $InstallerFile
    }

    $InstallerPath = Join-Path $OutputDir "gerber2font-setup-$Version-win-x64.exe"
    if (-not (Test-Path $InstallerPath)) {
        $found = Get-ChildItem -Path $OutputDir -Filter "*.exe" | Select-Object -ExpandProperty FullName
        if (-not $found) {
            Fail "Installer was not produced."
        }
        Write-Host "Installer created:"
        $found | ForEach-Object { Write-Host "  $_" }
    }
    else {
        Write-Host "Installer created: $InstallerPath"
    }
}
finally {
    Pop-Location
}
