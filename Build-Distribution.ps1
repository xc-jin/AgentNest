[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
$taskSource = Join-Path $taskRoot 'distribution'
$taskPayload = Join-Path $taskRoot 'lab\payload'
$taskOutput = Join-Path $taskRoot 'dist'
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskZipPath = Join-Path $taskOutput 'Codex-DeepSeek-Windows-x64.zip'
if (Test-Path -LiteralPath $taskZipPath) { throw 'The output ZIP already exists. Move it aside before building another version.' }
$taskFiles = [ordered]@{}
foreach ($taskName in @('Setup-Codex-DeepSeek.cmd', 'Setup-Codex-DeepSeek.ps1', 'Install-Codex.ps1', 'Start-Codex.cmd', 'Start-Codex.ps1', 'README.txt')) {
    $taskFiles[$taskName] = Join-Path $taskSource $taskName
}
foreach ($taskName in @('Codex-x64.msix', 'Codex-License.xml', 'Configure-DeepSeek.official.ps1')) {
    $taskFiles[$taskName] = Join-Path $taskPayload $taskName
}
$taskEntries = @($taskFiles.GetEnumerator() | ForEach-Object {
    [ordered]@{ Name = $_.Key; Size = (Get-Item -LiteralPath $_.Value).Length; Sha256 = (Get-FileHash -LiteralPath $_.Value -Algorithm SHA256).Hash }
})
if (($taskEntries | Where-Object Name -eq 'Codex-x64.msix').Sha256 -ne '230573079DC6EC7060C76778D470C029BE90DDDCC1EFCB79427A3620864C816E') {
    throw 'The installation package differs from the verified lab version.'
}
if ((Get-AuthenticodeSignature -LiteralPath $taskFiles['Codex-x64.msix']).Status -ne 'Valid') { throw 'Invalid OpenAI package signature.' }
$taskManifest = [ordered]@{
    BundleVersion = '1.0.0'
    CodexVersion = '26.1007.9446.0'
    Architecture = 'x64'
    CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    Files = $taskEntries
}
$taskManifestDirectory = Join-Path $taskOutput 'package-metadata'
New-Item -ItemType Directory -Path $taskManifestDirectory -Force | Out-Null
$taskManifestPath = Join-Path $taskManifestDirectory 'bundle-manifest.json'
[IO.File]::WriteAllText($taskManifestPath, ($taskManifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
$taskFiles['bundle-manifest.json'] = $taskManifestPath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZipStream = [IO.File]::Open($taskZipPath, [IO.FileMode]::CreateNew)
try {
    $taskArchive = [IO.Compression.ZipArchive]::new($taskZipStream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($taskFile in $taskFiles.GetEnumerator()) {
            $taskCompression = if ($taskFile.Key -eq 'Codex-x64.msix') { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskArchive, $taskFile.Value, ('Codex-DeepSeek/' + $taskFile.Key), $taskCompression) | Out-Null
        }
    } finally { $taskArchive.Dispose() }
} finally { $taskZipStream.Dispose() }
$taskZipHash = (Get-FileHash -LiteralPath $taskZipPath -Algorithm SHA256).Hash
[IO.File]::WriteAllText(($taskZipPath + '.sha256'), ($taskZipHash + '  ' + [IO.Path]::GetFileName($taskZipPath) + "`r`n"), [Text.Encoding]::ASCII)
Write-Output ('Created: ' + $taskZipPath)
Write-Output ('Bytes: ' + (Get-Item -LiteralPath $taskZipPath).Length)
Write-Output ('SHA256: ' + $taskZipHash)
