[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = Join-Path $taskRoot ('lab/evidence/assistant-packages-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskExpectedBase = @('Agent-Assistant.cmd','assistant/AgentSetup.ps1','assistant/AgentSetup.Core.psm1',
    'assistant/AgentSetup.UI.ps1','assistant/catalog.json','assistant/README.txt','assistant/assets/deepseek-models.json','assistant/AgentSetup.Localization.ps1','assistant/locales/zh-CN.json','assistant/locales/en-US.json','assistant/README.en.txt','assistant/AgentSetup.Clients.ps1','assistant/AgentSetup.SharingLocal.ps1')
foreach ($taskFlavor in @('online','with-Codex')) {
    $taskPackage = Join-Path $taskRoot ('dist/Agent-Setup-Assistant-0.4.0-Windows-x64-' + $taskFlavor + '.zip')
    $taskExpected = @($taskExpectedBase)
    if ($taskFlavor -eq 'with-Codex') { $taskExpected += @('assistant/assets/Codex-x64.msix','assistant/assets/Codex-License.xml') }
    $taskArchive = [IO.Compression.ZipFile]::OpenRead($taskPackage)
    try {
        $taskPrefix = 'Agent-Setup-Assistant/'
        $taskNames = @($taskArchive.Entries | ForEach-Object FullName)
        $taskExpectedNames = @($taskExpected + 'bundle-manifest.json' | ForEach-Object { $taskPrefix + $_ })
        if (@(Compare-Object $taskExpectedNames $taskNames).Count -or $taskNames.Count -ne $taskExpectedNames.Count) { throw ('Unexpected archive contents: ' + $taskFlavor) }
        $taskReader = [IO.StreamReader]::new($taskArchive.GetEntry($taskPrefix + 'bundle-manifest.json').Open())
        try { $taskManifest = $taskReader.ReadToEnd() | ConvertFrom-Json } finally { $taskReader.Dispose() }
        foreach ($taskFile in $taskManifest.Files) {
            $taskEntry = $taskArchive.GetEntry($taskPrefix + $taskFile.Name)
            $taskStream = $taskEntry.Open(); $taskSha = [Security.Cryptography.SHA256]::Create()
            try { $taskHash = [BitConverter]::ToString($taskSha.ComputeHash($taskStream)).Replace('-','') }
            finally { $taskStream.Dispose(); $taskSha.Dispose() }
            if ($taskHash -ne $taskFile.Sha256 -or $taskEntry.Length -ne $taskFile.Size) { throw ('ZIP checksum failed: ' + $taskFile.Name) }
        }
        $taskExternalHash = (Get-Content -LiteralPath ($taskPackage + '.sha256') -Raw).Split(' ')[0]
        if ((Get-FileHash -LiteralPath $taskPackage -Algorithm SHA256).Hash -ne $taskExternalHash) { throw 'External ZIP SHA256 mismatch.' }
        $taskExtract = Join-Path $taskOutput $taskFlavor
        foreach ($taskEntry in $taskArchive.Entries) {
            $taskRelative = $taskEntry.FullName.Substring($taskPrefix.Length)
            $taskTarget = Join-Path $taskExtract $taskRelative
            New-Item -ItemType Directory -Path (Split-Path -Parent $taskTarget) -Force | Out-Null
            if ($taskEntry.Name -eq 'Codex-x64.msix') {
                # Entry hash already checked; avoid a redundant 945 MB disk copy for entry-point verification.
                New-Item -ItemType HardLink -Path $taskTarget -Target (Join-Path $taskRoot 'lab/payload/Codex-x64.msix') | Out-Null
            } else { [IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry,$taskTarget) }
        }
    } finally { $taskArchive.Dispose() }
    $taskPs = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    & $taskPs -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $taskExtract 'assistant/AgentSetup.ps1') -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw ('Release entry verification failed: ' + $taskFlavor) }
    if ($taskFlavor -eq 'online') {
        foreach ($taskLanguage in @('zh-CN','en-US')) {
            & $taskPs -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $taskExtract 'assistant/AgentSetup.ps1') -Language $taskLanguage -SmokeTest -DataRoot (Join-Path $taskOutput 'ui-data')
            if ($LASTEXITCODE -ne 0) { throw ('Release GUI smoke test failed: ' + $taskLanguage) }
        }
        $taskReadme = Join-Path $taskExtract 'assistant/README.txt'
        [IO.File]::AppendAllText($taskReadme,'tamper-test')
        $taskPreviousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $taskOutputText = @(& $taskPs -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $taskExtract 'assistant/AgentSetup.ps1') -VerifyOnly 2>&1)
        } finally { $ErrorActionPreference = $taskPreviousPreference }
        if ($LASTEXITCODE -eq 0) { throw 'Modified archive file was not rejected.' }
        Write-Output 'PASS: Modified release files are rejected before importing the engine.'
    }
    Write-Output ('PASS: ' + $taskFlavor + ' ZIP allowlist, all file hashes, ZIP SHA256, and extracted entry point')
}
Write-Output ('Package verification evidence: ' + $taskOutput)
