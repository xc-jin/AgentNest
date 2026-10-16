[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZipPath = Join-Path $PSScriptRoot 'dist\Codex-DeepSeek-Windows-x64.zip'
$taskVerifyDirectory = Join-Path $PSScriptRoot ('lab\evidence\distribution-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskVerifyDirectory -Force | Out-Null
$taskExpectedNames = @('Setup-Codex-DeepSeek.cmd', 'Setup-Codex-DeepSeek.ps1', 'Install-Codex.ps1',
    'Start-Codex.cmd', 'Start-Codex.ps1', 'README.txt', 'Codex-x64.msix', 'Codex-License.xml',
    'Configure-DeepSeek.official.ps1', 'bundle-manifest.json')
$taskArchive = [IO.Compression.ZipFile]::OpenRead($taskZipPath)
try {
    $taskNames = @($taskArchive.Entries | ForEach-Object { $_.FullName })
    if ($taskNames.Count -ne $taskExpectedNames.Count -or
        @(Compare-Object ($taskExpectedNames | ForEach-Object { 'Codex-DeepSeek/' + $_ }) $taskNames).Count) {
        throw 'Unexpected ZIP contents.'
    }
    $taskReader = [IO.StreamReader]::new($taskArchive.GetEntry('Codex-DeepSeek/bundle-manifest.json').Open())
    try { $taskManifest = $taskReader.ReadToEnd() | ConvertFrom-Json } finally { $taskReader.Dispose() }
    if ($taskManifest.Files.Count -ne 9) { throw 'The bundle manifest must describe all nine payload files.' }
    foreach ($taskFile in $taskManifest.Files) {
        $taskEntry = $taskArchive.GetEntry('Codex-DeepSeek/' + $taskFile.Name)
        if (-not $taskEntry -or $taskEntry.Length -ne $taskFile.Size) { throw ('Incorrect ZIP entry: ' + $taskFile.Name) }
        $taskStream = $taskEntry.Open()
        $taskSha = [Security.Cryptography.SHA256]::Create()
        try {
            $taskHash = [BitConverter]::ToString($taskSha.ComputeHash($taskStream)).Replace('-', '')
            if ($taskHash -ne $taskFile.Sha256) { throw ('ZIP checksum mismatch: ' + $taskFile.Name) }
        } finally { $taskStream.Dispose(); $taskSha.Dispose() }
        Write-Output ('ZIP checksum OK: ' + $taskFile.Name)
    }
    # Extract only small files; the already verified MSIX is linked on the same volume.
    foreach ($taskEntry in $taskArchive.Entries) {
        if ($taskEntry.Name -ne 'Codex-x64.msix') {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry, (Join-Path $taskVerifyDirectory $taskEntry.Name))
        }
    }
    New-Item -ItemType HardLink -Path (Join-Path $taskVerifyDirectory 'Codex-x64.msix') -Target (Join-Path $PSScriptRoot 'lab\payload\Codex-x64.msix') | Out-Null
    $taskPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $taskPs -NoProfile -ExecutionPolicy Bypass -File (Join-Path $taskVerifyDirectory 'Setup-Codex-DeepSeek.ps1') -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw 'Valid bundle verification failed.' }
    $taskReadmePath = Join-Path $taskVerifyDirectory 'README.txt'
    [IO.File]::AppendAllText($taskReadmePath, 'tamper check')
    $taskTamperOutput = @(& $taskPs -NoProfile -ExecutionPolicy Bypass -File (Join-Path $taskVerifyDirectory 'Setup-Codex-DeepSeek.ps1') -VerifyOnly)
    if ($LASTEXITCODE -ne 1 -or ($taskTamperOutput -join ' ') -notmatch 'File checksum mismatch: README.txt') {
        throw 'Tamper detection did not stop setup.'
    }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($taskArchive.GetEntry('Codex-DeepSeek/README.txt'), $taskReadmePath, $true)
    Write-Output 'Tamper detection OK: modified README rejected before installation.'
    Write-Output 'ZIP contains only the 10 approved distribution files.'
    Write-Output 'No installation, API request, or user configuration change was performed.'
} finally { $taskArchive.Dispose() }
