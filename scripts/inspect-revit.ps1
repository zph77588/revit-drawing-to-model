[CmdletBinding()]
param(
    [ValidateRange(2011,2099)][int]$Year,
    [string]$RevitDirectory
)
$ErrorActionPreference = 'Stop'
# Read-only discovery; never launch Revit or choose a fallback year silently.
$candidates = @()
if ($RevitDirectory) {
    if (-not (Test-Path -LiteralPath (Join-Path $RevitDirectory 'Revit.exe'))) {
        throw 'RevitDirectory must contain Revit.exe'
    }
    $candidates += $RevitDirectory
} else {
    foreach ($root in @('HKLM:\SOFTWARE\Autodesk\Revit', 'HKLM:\SOFTWARE\WOW6432Node\Autodesk\Revit')) {
        if (Test-Path -LiteralPath $root) {
            foreach ($key in (Get-ChildItem -LiteralPath $root)) {
                $info = Get-ItemProperty -LiteralPath $key.PSPath
                foreach ($field in @('InstallationLocation','InstallLocation')) {
                    if ($info.PSObject.Properties[$field] -and $info.$field) { $candidates += $info.$field }
                }
            }
        }
    }
    foreach ($base in @((Join-Path $env:ProgramFiles 'Autodesk'), 'D:\Program Files\Autodesk')) {
        if (Test-Path -LiteralPath $base) {
            $candidates += @(Get-ChildItem -LiteralPath $base -Directory -Filter 'Revit *' | Select-Object -ExpandProperty FullName)
        }
    }
}
$found = @(
    foreach ($dir in ($candidates | Select-Object -Unique)) {
        $exe = Join-Path $dir 'Revit.exe'
        if (-not (Test-Path -LiteralPath $exe)) { continue }
        $version = (Get-Item -LiteralPath $exe).VersionInfo
        $detectedYear = 2000 + $version.FileMajorPart
        if ($detectedYear -lt 2011 -or $detectedYear -gt 2099) { throw "Unrecognized Revit version: $($version.FileVersion)" }
        if ($Year -and $detectedYear -ne $Year) {
            if ($RevitDirectory) { throw "Requested Revit $Year but directory contains $detectedYear" }
            continue
        }
        $addinDir = Join-Path $env:APPDATA "Autodesk\Revit\Addins\$detectedYear"
        $contentRoot = Join-Path $env:ProgramData "Autodesk\RVT $detectedYear"
        [pscustomobject]@{
            Year = $detectedYear
            Directory = (Resolve-Path -LiteralPath $dir).Path
            ProductVersion = $version.FileVersion
            RevitAPI = Test-Path -LiteralPath (Join-Path $dir 'RevitAPI.dll')
            RevitAPIUI = Test-Path -LiteralPath (Join-Path $dir 'RevitAPIUI.dll')
            RuntimeGuidance = $(if ($detectedYear -ge 2025) { 'Modern .NET: verify target-year SDK/runtime requirements' } else { '.NET Framework: verify target-year framework requirements' })
            ContentCandidate = $contentRoot
            TemplatesExist = Test-Path -LiteralPath (Join-Path $contentRoot 'Templates')
            FamilyTemplatesExist = Test-Path -LiteralPath (Join-Path $contentRoot 'Family Templates')
            LibrariesExist = Test-Path -LiteralPath (Join-Path $contentRoot 'Libraries')
            AddinDirectory = $addinDir
            AddinFiles = @(if (Test-Path -LiteralPath $addinDir) {
                Get-ChildItem -LiteralPath $addinDir -Filter '*.addin' -File | Select-Object -ExpandProperty FullName
            })
        }
    }
)
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
[pscustomobject]@{
    RequestedYear = $(if ($Year) { $Year } else { $null })
    Status = $(if ($found.Count) { 'found' } else { 'not-found' })
    Installations = $found
    LegacyCompilerExists = Test-Path -LiteralPath $compiler
    DotnetCommand = $(if ($dotnet) { $dotnet.Source } else { $null })
    Note = 'Discovery only. SDK, plugin loading and model compatibility require separate checks. Use RevitDirectory for custom locations.'
    RunningRevit = @(Get-Process -Name Revit -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{ Id = $_.Id; WindowTitle = $_.MainWindowTitle }
    })
} | ConvertTo-Json -Depth 6