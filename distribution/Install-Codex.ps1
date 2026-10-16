[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskLogDirectory = Join-Path $env:LOCALAPPDATA 'CodexDeepSeekSetup'
New-Item -ItemType Directory -Path $taskLogDirectory -Force | Out-Null
Start-Transcript -Path (Join-Path $taskLogDirectory 'codex-install.log') -Append | Out-Null
try {
    $taskPackagePath = Join-Path $PSScriptRoot 'Codex-x64.msix'
    if ((Get-AuthenticodeSignature -LiteralPath $taskPackagePath).Status -ne 'Valid') { throw 'Invalid OpenAI package signature.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $taskArchive = [IO.Compression.ZipFile]::OpenRead($taskPackagePath)
    try {
        $taskEntry = $taskArchive.GetEntry('AppxManifest.xml')
        if (-not $taskEntry) { throw 'The installation package has no AppxManifest.xml.' }
        $taskReader = [IO.StreamReader]::new($taskEntry.Open())
        try { [xml]$taskPackageManifest = $taskReader.ReadToEnd() } finally { $taskReader.Dispose() }
        $taskIdentity = $taskPackageManifest.Package.Identity
        if ($taskIdentity.Name -ne 'OpenAI.Codex' -or $taskIdentity.ProcessorArchitecture -ne 'x64' -or
            $taskIdentity.Publisher -ne 'CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B') {
            throw 'The package is not the expected OpenAI.Codex x64 package.'
        }
    } finally { $taskArchive.Dispose() }

    $taskInstalled = Get-AppxPackage -Name 'OpenAI.Codex'
    if (-not $taskInstalled -or [version]$taskInstalled.Version -lt [version]$taskIdentity.Version) {
        Add-AppxPackage -Path $taskPackagePath
        $taskInstalled = Get-AppxPackage -Name 'OpenAI.Codex'
    }
    if (-not $taskInstalled) { throw 'Codex is not registered for the current Windows account.' }

    $taskConfigDirectory = if ($env:CODEX_HOME) { [IO.Path]::GetFullPath($env:CODEX_HOME) } else { Join-Path $env:USERPROFILE '.codex' }
    New-Item -ItemType Directory -Path $taskConfigDirectory -Force | Out-Null
    $taskConfigPath = Join-Path $taskConfigDirectory 'config.toml'
    if (-not (Test-Path -LiteralPath $taskConfigPath)) {
        [IO.File]::WriteAllText($taskConfigPath, "[windows]`r`nsandbox = `"unelevated`"`r`n", [Text.UTF8Encoding]::new($false))
    }

    # Launch the registered app instead of depending on Start-menu indexing or an install path.
    $taskRegisteredManifest = Get-AppxPackageManifest -Package $taskInstalled.PackageFullName
    $taskApplication = @($taskRegisteredManifest.Package.Applications.Application | Where-Object { $_.Executable -match '(?i)(^|[/\\])ChatGPT\.exe$' })
    if ($taskApplication.Count -ne 1) { throw 'The registered app launch identity could not be determined.' }
    $taskAppId = $taskInstalled.PackageFamilyName + '!' + $taskApplication[0].Id
    try {
        $taskDesktop = [Environment]::GetFolderPath('DesktopDirectory')
        if (-not $taskDesktop) { throw 'The Windows Desktop folder is unavailable.' }
        $taskShell = New-Object -ComObject WScript.Shell
        $taskShortcut = $taskShell.CreateShortcut((Join-Path $taskDesktop 'ChatGPT (Codex).lnk'))
        $taskShortcut.TargetPath = Join-Path $env:SystemRoot 'explorer.exe'
        $taskShortcut.Arguments = 'shell:AppsFolder\' + $taskAppId
        $taskShortcut.Description = 'Open ChatGPT (Codex) for the current Windows account'
        $taskShortcut.Save()
        Write-Host 'Desktop shortcut created: ChatGPT (Codex)'
    } catch {
        Write-Warning ('Could not create a desktop shortcut. Use Start-Codex.cmd. ' + $_.Exception.Message)
    }
    [ordered]@{
        Package = $taskInstalled.PackageFullName
        ApplicationId = $taskAppId
        Config = $taskConfigPath
        CompletedUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskLogDirectory 'installed.json') -Encoding UTF8
    Write-Host ('Installed package: ' + $taskInstalled.PackageFullName)
} finally {
    Stop-Transcript | Out-Null
}
