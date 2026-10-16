[CmdletBinding()]
param([switch]$IncludeCodexInstaller)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$taskOutput = Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskSuffix = if ($IncludeCodexInstaller) { 'with-Codex' } else { 'online' }
$taskZipPath = Join-Path $taskOutput ('Agent-Setup-Assistant-0.4.0-Windows-x64-' + $taskSuffix + '.zip')
if (Test-Path -LiteralPath $taskZipPath) { throw '目标 ZIP 已存在，请移走旧版本再构建。' }
$taskFiles = [ordered]@{}
$taskFiles['Agent-Assistant.cmd'] = Join-Path $PSScriptRoot 'Agent-Assistant.cmd'
foreach ($taskRelative in @('AgentSetup.ps1','AgentSetup.Core.psm1','AgentSetup.UI.ps1','catalog.json','README.txt','assets/deepseek-models.json','AgentSetup.Localization.ps1','locales/zh-CN.json','locales/en-US.json','README.en.txt','AgentSetup.Clients.ps1','AgentSetup.SharingLocal.ps1')) {
    $taskFiles['assistant/' + $taskRelative] = Join-Path (Join-Path $PSScriptRoot 'assistant') $taskRelative
}
if ($IncludeCodexInstaller) {
    $taskMsix = Join-Path $PSScriptRoot 'lab/payload/Codex-x64.msix'
    if ((Get-FileHash -LiteralPath $taskMsix -Algorithm SHA256).Hash -ne '230573079DC6EC7060C76778D470C029BE90DDDCC1EFCB79427A3620864C816E' -or
        (Get-AuthenticodeSignature -LiteralPath $taskMsix).Status -ne 'Valid') { throw 'Codex 离线安装文件校验失败。' }
    $taskFiles['assistant/assets/Codex-x64.msix'] = $taskMsix
    $taskFiles['assistant/assets/Codex-License.xml'] = Join-Path $PSScriptRoot 'lab/payload/Codex-License.xml'
}
$taskManifest = [ordered]@{ Version = '0.4.0'; Flavor = $taskSuffix; Files = @($taskFiles.GetEnumerator() | ForEach-Object {
    [ordered]@{ Name = $_.Key; Size = (Get-Item -LiteralPath $_.Value).Length; Sha256 = (Get-FileHash -LiteralPath $_.Value -Algorithm SHA256).Hash }
}) }
$taskArchive = [IO.Compression.ZipFile]::Open($taskZipPath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($taskFile in $taskFiles.GetEnumerator()) {
        $taskCompression = if ($taskFile.Key.EndsWith('.msix')) { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskArchive,$taskFile.Value,('Agent-Setup-Assistant/' + $taskFile.Key),$taskCompression) | Out-Null
    }
    $taskManifestEntry = $taskArchive.CreateEntry('Agent-Setup-Assistant/bundle-manifest.json')
    $taskWriter = [IO.StreamWriter]::new($taskManifestEntry.Open(),[Text.UTF8Encoding]::new($false))
    try { $taskWriter.Write(($taskManifest | ConvertTo-Json -Depth 8)) } finally { $taskWriter.Dispose() }
} finally { $taskArchive.Dispose() }
$taskSha = (Get-FileHash -LiteralPath $taskZipPath -Algorithm SHA256).Hash
[IO.File]::WriteAllText(($taskZipPath + '.sha256'), ($taskSha + '  ' + [IO.Path]::GetFileName($taskZipPath) + "`r`n"),[Text.Encoding]::ASCII)
Write-Output ('Created: ' + $taskZipPath)
Write-Output ('Bytes: ' + (Get-Item -LiteralPath $taskZipPath).Length)
