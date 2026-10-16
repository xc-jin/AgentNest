[CmdletBinding()]
param([switch]$VerifyOnly)

$ErrorActionPreference = 'Stop'
try {
    if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'This bundle requires x64 Windows and 64-bit Windows PowerShell. Use the CMD entry point.'
    }
    if ([Environment]::OSVersion.Version.Build -lt 19041) {
        throw 'Windows build 19041 or newer is required.'
    }
    if ($env:CODEX_HOME -and -not [IO.Path]::IsPathRooted($env:CODEX_HOME)) {
        throw 'CODEX_HOME must be an absolute path. Check the existing override first.'
    }
    $taskConfigDirectory = if ($env:CODEX_HOME) { [IO.Path]::GetFullPath($env:CODEX_HOME) } else { Join-Path $env:USERPROFILE '.codex' }
    Write-Host '[1/3] Checking the local installation bundle...'
    $taskManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle-manifest.json') -Raw | ConvertFrom-Json
    foreach ($taskFile in $taskManifest.Files) {
        if ([IO.Path]::GetFileName($taskFile.Name) -ne $taskFile.Name) { throw 'Invalid file name in the bundle manifest.' }
        $taskPath = Join-Path $PSScriptRoot $taskFile.Name
        if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) { throw ('Missing file: ' + $taskFile.Name) }
        if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash -ne $taskFile.Sha256) {
            throw ('File checksum mismatch: ' + $taskFile.Name)
        }
    }
    $taskSignature = Get-AuthenticodeSignature -LiteralPath (Join-Path $PSScriptRoot 'Codex-x64.msix')
    if ($taskSignature.Status -ne 'Valid') { throw 'The OpenAI installation package signature is not valid.' }
    if ($VerifyOnly) {
        Write-Host 'Bundle verification passed. No installation or configuration was performed.' -ForegroundColor Green
        return
    }
    Write-Host ('Configuration directory: ' + $taskConfigDirectory)
    Write-Host 'Run using the Windows account that will use Codex. Close the app before continuing.'
    Write-Host '[2/3] Installing Codex for the current Windows user...'
    & (Join-Path $PSScriptRoot 'Install-Codex.ps1')

    Write-Host '[3/3] Configuring DeepSeek...'
    Write-Host 'The official configuration menu offers 1 = DeepSeek-Flash and 2 = DeepSeek-V4-Pro.'
    Write-Host 'Your key will be saved in your local config.toml. Existing configuration is backed up by the official script.'
    $taskSecureKey = Read-Host 'DeepSeek API key (hidden input)' -AsSecureString
    $taskKeyPointer = [IntPtr]::Zero
    $taskPreviousKey = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Process')
    try {
        $taskKeyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecureKey)
        $taskKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskKeyPointer).Trim()
        if ($taskKey -notmatch '^sk-[A-Za-z0-9_-]+$') { throw 'Invalid DeepSeek API key format.' }
        [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $taskKey, 'Process')
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Configure-DeepSeek.official.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'DeepSeek configuration did not complete. Read the message above.' }
    } finally {
        [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $taskPreviousKey, 'Process')
        $taskKey = $null
        $taskPreviousKey = $null
        if ($taskKeyPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskKeyPointer) }
        $taskSecureKey.Dispose()
    }
    $taskConfigPath = Join-Path $taskConfigDirectory 'config.toml'
    $taskConfigText = [IO.File]::ReadAllText($taskConfigPath)
    if ($taskConfigText -notmatch '(?m)^model_provider\s*=\s*"deepseek"' -or
        $taskConfigText -notmatch '(?m)^wire_api\s*=\s*"responses"') {
        throw 'DeepSeek is not selected in the resulting configuration. If you chose Restore, the previous configuration was restored.'
    }
    $taskConfigText = $null
    Write-Host ''
    Write-Host 'SETUP COMPLETED. Double-click Start-Codex.cmd to open ChatGPT (Codex).' -ForegroundColor Green
    Write-Host ('Configuration: ' + $taskConfigPath)
    Write-Host 'API connectivity has not been tested. Send a message in the app to verify it.'
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
