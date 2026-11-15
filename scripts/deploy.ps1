<#
.SYNOPSIS
Validate or install Professionator with a timestamped backup and hash verification.
.EXAMPLE
.\scripts\deploy.ps1 -Install -GameDirectory 'C:\Program Files (x86)\World of Warcraft\_forever_'
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [string]$GameDirectory = 'C:\Program Files (x86)\World of Warcraft\_forever_'
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $projectDirectory 'Professionator'
$reportPath = Join-Path $projectDirectory 'artifacts\integration-report.json'
if (-not $Install) {
    Write-Output 'Professionator installer'
    Write-Output 'Usage: .\scripts\deploy.ps1 -Install [-GameDirectory <WoW _forever_ directory>]'
    Write-Output 'Run scripts\validate.py --run first. Installation backs up the addon and verifies every file.'
    Write-Output 'SavedVariables are never changed. A newly installed addon requires a game restart.'
    return
}
if (-not (Test-Path -LiteralPath $reportPath)) { throw 'Run scripts\validate.py --run before installing.' }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'The integration workflow did not pass.' }
foreach ($file in Get-ChildItem -LiteralPath $sourceDirectory -File) {
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $validatedHash = $report.sourceHashes.PSObject.Properties[$file.Name].Value
    if ($sourceHash -ne $validatedHash) { throw "Source changed after validation: $($file.Name). Run scripts\validate.py --run again." }
}
$addonDirectory = Join-Path (Resolve-Path -LiteralPath $GameDirectory).Path 'Interface\AddOns'
if (-not (Test-Path -LiteralPath $addonDirectory)) { throw "Missing AddOns directory: $addonDirectory" }
$destinationDirectory = Join-Path $addonDirectory 'Professionator'
$alreadyInstalled = Test-Path -LiteralPath $destinationDirectory
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDirectory = Join-Path $projectDirectory "backups\$timestamp"
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
if ($alreadyInstalled) {
    Copy-Item -LiteralPath $destinationDirectory -Destination $backupDirectory -Recurse
}
New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
$records = @()
foreach ($file in Get-ChildItem -LiteralPath $sourceDirectory -File) {
    $destination = Join-Path $destinationDirectory $file.Name
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $installedHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($sourceHash -ne $installedHash) { throw "Installed file differs: $destination" }
    $records += [pscustomobject]@{ File = $file.Name; SHA256 = $sourceHash }
}
$manifest = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('o')
    Destination = $destinationDirectory
    Backup = $backupDirectory
    WorkflowChecks = $report.checks.Count
    GameRunning = [bool](Get-Process -Name Wow -ErrorAction SilentlyContinue)
    Files = $records
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $projectDirectory 'artifacts\installed.json') -Encoding utf8
Write-Output "Installed and hash-verified $($records.Count) files in $destinationDirectory"
if ($alreadyInstalled) {
    Write-Output 'Type /reload in WoW to load the updated Professionator files.'
} else {
    Write-Output 'Restart WoW when convenient, then open a profession or click the Professionator minimap icon.'
}
