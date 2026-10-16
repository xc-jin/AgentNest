$ErrorActionPreference = 'Stop'
try {
    $taskInstalled = Get-AppxPackage -Name 'OpenAI.Codex'
    if (-not $taskInstalled) { throw 'Codex is not installed for this Windows account. Run Setup-Codex-DeepSeek.cmd first.' }
    $taskManifest = Get-AppxPackageManifest -Package $taskInstalled.PackageFullName
    $taskApplication = @($taskManifest.Package.Applications.Application | Where-Object { $_.Executable -match '(?i)(^|[/\\])ChatGPT\.exe$' })
    if ($taskApplication.Count -ne 1) { throw 'Could not determine the registered ChatGPT application identity.' }
    $taskAppId = $taskInstalled.PackageFamilyName + '!' + $taskApplication[0].Id
    Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList ('shell:AppsFolder\' + $taskAppId)
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
