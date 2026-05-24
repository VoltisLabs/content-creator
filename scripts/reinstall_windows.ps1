# Content Calendar — uninstall prior install, build installer, copy to Downloads, reinstall, launch.

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
  throw "pubspec.yaml not found under project root: $ProjectRoot"
}

$Flutter = $env:FLUTTER_EXE
if (-not $Flutter) {
  foreach ($c in @(
      "$env:USERPROFILE\flutter\bin\flutter.bat",
      'C:\src\flutter\bin\flutter.bat',
      'flutter'
    )) {
    if ($c -eq 'flutter' -or (Test-Path $c)) { $Flutter = $c; break }
  }
}

function Stop-AppProcesses {
  Get-Process -Name 'content_calendar' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Stopping $($_.Name) (PID $($_.Id))"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
  }
}

function Uninstall-InnoIfPresent {
  $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
  $candidates = @(
    "$env:ProgramFiles\Content Calendar\unins000.exe",
    "$env:ProgramFiles\Content Calendar\unins001.exe",
    "$pf86\Content Calendar\unins000.exe",
    "$env:LOCALAPPDATA\Programs\Content Calendar\unins000.exe"
  )
  foreach ($u in $candidates) {
    if (Test-Path $u) {
      Write-Host "Running uninstaller: $u"
      Start-Process -FilePath $u -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -ErrorAction SilentlyContinue
    }
  }
}

function Clear-DownloadsArtifacts {
  param([string]$Downloads)
  foreach ($name in @('ContentCalendarSetup.exe', 'ContentCalendarSetup-*.exe')) {
    Get-ChildItem -Path $Downloads -Filter $name -ErrorAction SilentlyContinue |
      ForEach-Object { Write-Host "Removing $($_.FullName)"; Remove-Item $_.FullName -Force }
  }
  $portable = Join-Path $Downloads 'ContentCalendar-Windows'
  if (Test-Path $portable) {
    Write-Host "Removing old portable bundle: $portable"
    Remove-Item $portable -Recurse -Force
  }
}

Stop-AppProcesses
Uninstall-InnoIfPresent
Start-Sleep -Seconds 1
Stop-AppProcesses

Push-Location $ProjectRoot
try {
  & $Flutter pub get
  & $Flutter pub run flutter_launcher_icons
  if ($LASTEXITCODE -ne 0) { throw 'flutter_launcher_icons failed' }
  $Dart = Join-Path (Split-Path $Flutter -Parent) 'dart.bat'
  & $Dart run tool/generate_windows_ico.dart
  if ($LASTEXITCODE -ne 0) { throw 'generate_windows_ico failed' }
  & $Flutter clean
  & $Flutter build windows --release
} finally {
  Pop-Location
}

$ReleaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$PortableExe = Join-Path $ReleaseDir 'content_calendar.exe'
if (-not (Test-Path $PortableExe)) { throw "Build output missing: $PortableExe" }

$Iss = Join-Path $ProjectRoot 'installer\ContentCalendarSetup.iss'
$Iscc = $null
$pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
foreach ($p in @(
    "$pf86\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )) {
  if (Test-Path $p) { $Iscc = $p; break }
}

$Downloads = Join-Path $env:USERPROFILE 'Downloads'
Clear-DownloadsArtifacts -Downloads $Downloads

$SetupExe = $null
if ($Iscc -and (Test-Path $Iss)) {
  Write-Host "Building installer with: $Iscc"
  & $Iscc $Iss
  $built = Join-Path $Downloads 'ContentCalendarSetup.exe'
  if (Test-Path $built) { $SetupExe = $built }
}

if ($SetupExe) {
  Write-Host "Installer ready: $SetupExe"
  Write-Host 'Running installer (silent)...'
  Start-Process -FilePath $SetupExe -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait
  $installed = "$env:LOCALAPPDATA\Programs\Content Calendar\content_calendar.exe"
  $installedPf = "$env:ProgramFiles\Content Calendar\content_calendar.exe"
  if (Test-Path $installedPf) {
    Write-Host "Launching: $installedPf"
    Start-Process -FilePath $installedPf
  } elseif (Test-Path $installed) {
    Write-Host "Launching: $installed"
    Start-Process -FilePath $installed
  } else {
    Write-Warning 'Installed exe not found — launching portable build.'
    Start-Process -FilePath $PortableExe
  }
} else {
  Write-Warning 'Inno Setup 6 (ISCC.exe) not found — copying full Windows Release bundle.'
  $portable = Join-Path $Downloads 'ContentCalendar-Windows'
  New-Item -ItemType Directory -Path $portable -Force | Out-Null
  Copy-Item -Path (Join-Path $ReleaseDir '*') -Destination $portable -Recurse -Force
  $launch = Join-Path $portable 'content_calendar.exe'
  Write-Host "Portable app folder: $portable"
  Write-Host "Launching: $launch"
  Start-Process -FilePath $launch
}

Write-Host "Opening Downloads folder..."
Start-Process explorer.exe $Downloads
Write-Host 'Done.'
