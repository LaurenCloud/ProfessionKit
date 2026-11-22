<#
.SYNOPSIS
Validate or install ProfessionKit with a timestamped backup and hash verification.
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
$sourceDirectory = Join-Path $projectDirectory 'ProfessionKit'
$reportPath = Join-Path $projectDirectory 'artifacts\integration-report.json'
if (-not $Install) {
    Write-Output 'ProfessionKit installer'
    Write-Output 'Usage: .\scripts\deploy.ps1 -Install [-GameDirectory <WoW _forever_ directory>]'
    Write-Output 'Run scripts\validate.py --run first. Installation backs up the addon and verifies every file.'
    Write-Output 'For the one-time upgrade from ProfessionPro or Professionator, exit WoW first. The installer copies settings and archives the previous addon folders. Later updates support /reload.'
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
$gameRoot = (Resolve-Path -LiteralPath $GameDirectory).Path
$addonDirectory = Join-Path $gameRoot 'Interface\AddOns'
if (-not (Test-Path -LiteralPath $addonDirectory)) { throw "Missing AddOns directory: $addonDirectory" }
$destinationDirectory = Join-Path $addonDirectory 'ProfessionKit'
$alreadyInstalled = Test-Path -LiteralPath $destinationDirectory
$previousAddonNames = @('ProfessionPro', 'Professionator')
$previousAddons = foreach ($name in $previousAddonNames) {
    $path = Join-Path $addonDirectory $name
    if (Test-Path -LiteralPath $path) {
        $addon = Get-Item -LiteralPath $path
        if (-not $addon.PSIsContainer -or $addon.LinkType -or $addon.FullName -ne $path) { throw "Unexpected previous addon path: $path" }
        $addon
    }
}
$settingsCopies = @()
$accountDirectory = Join-Path $gameRoot 'WTF\Account'
if (Test-Path -LiteralPath $accountDirectory) {
    foreach ($account in Get-ChildItem -LiteralPath $accountDirectory -Directory) {
        $settings = Join-Path $account.FullName 'SavedVariables'
        $current = Join-Path $settings 'ProfessionKit.lua'
        if (Test-Path -LiteralPath $current) { continue }
        foreach ($name in $previousAddonNames) {
            $previous = Join-Path $settings "$name.lua"
            if (Test-Path -LiteralPath $previous -PathType Leaf) {
                $settingsCopies += [pscustomobject]@{ Previous = $previous; Current = $current; Variable = "${name}DB" }
                break
            }
        }
    }
}
if ($previousAddons -or $settingsCopies.Count) {
    $gameProcesses = Get-Process -Name Wow,WowClassic,WowClassicT -ErrorAction SilentlyContinue | Where-Object { -not $_.Path -or (Split-Path -Parent $_.Path) -eq $gameRoot }
    if ($gameProcesses) { throw 'Exit WoW Forever normally before migrating to ProfessionKit, then run this command again.' }
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'
$backupDirectory = Join-Path $projectDirectory "backups\$timestamp"
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
# Preserve every byte of the saved data except the first (top-level) variable name.
$byteEncoding = [Text.Encoding]::GetEncoding(28591)
foreach ($copy in $settingsCopies) {
    $databaseHeader = [regex]('\A((?:\xEF\xBB\xBF)?\s*)' + [regex]::Escape($copy.Variable) + '(?=\s*=)')
    $contents = $byteEncoding.GetString([IO.File]::ReadAllBytes($copy.Previous))
    if (-not $databaseHeader.IsMatch($contents)) { throw "Unexpected SavedVariables format in $($copy.Previous). Original retained." }
    $migrated = $databaseHeader.Replace($contents, '${1}ProfessionKitDB', 1)
    $temporaryPath = "$($copy.Current).$timestamp.tmp"
    try {
        [IO.File]::WriteAllBytes($temporaryPath, $byteEncoding.GetBytes($migrated))
        [IO.File]::Move($temporaryPath, $copy.Current)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath }
    }
}
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
foreach ($oldAddon in $previousAddons) {
    $archivePath = [IO.Path]::GetFullPath((Join-Path $backupDirectory $oldAddon.Name))
    if ($oldAddon.FullName -ne (Join-Path $addonDirectory $oldAddon.Name) -or $oldAddon.LinkType -or
        (Split-Path -Parent $archivePath) -ne (Resolve-Path -LiteralPath $backupDirectory).Path -or (Test-Path -LiteralPath $archivePath)) {
        throw 'Unexpected path for archiving the old addon.'
    }
    Move-Item -LiteralPath $oldAddon.FullName -Destination $archivePath
    Write-Output "Archived the previous $($oldAddon.Name) addon at $archivePath"
}
$manifest = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('o')
    Destination = $destinationDirectory
    Backup = $backupDirectory
    WorkflowChecks = $report.checks.Count
    MigratedSettingsFiles = $settingsCopies.Count
    GameRunning = [bool](Get-Process -Name Wow -ErrorAction SilentlyContinue)
    Files = $records
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $projectDirectory 'artifacts\installed.json') -Encoding utf8
Write-Output "Installed and hash-verified $($records.Count) files in $destinationDirectory"
if ($alreadyInstalled) {
    Write-Output 'Type /reload in WoW to load the updated ProfessionKit files.'
} else {
    Write-Output 'Restart WoW when convenient, then open a profession or click the ProfessionKit minimap icon.'
}
