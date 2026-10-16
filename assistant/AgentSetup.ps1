[CmdletBinding()]
param(
    [ValidateSet('UI','List','Install','Test','Launch','Backup','Restore')][string]$Action = 'UI',
    [string]$ProfileId, [string]$DataRoot, [string]$BackupId, [string]$WorkingDirectory,
    [ValidateSet('','zh-CN','en-US')][string]$Language, [string]$ResultPath, [switch]$SmokeTest, [string]$PreviewPath, [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$taskBundleRoot = Split-Path -Parent $PSScriptRoot
$taskManifestPath = Join-Path $taskBundleRoot 'bundle-manifest.json'
if (Test-Path -LiteralPath $taskManifestPath) {
    $taskManifest = Get-Content -LiteralPath $taskManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $taskAllowed = @('Agent-Assistant.cmd','assistant/AgentSetup.ps1','assistant/AgentSetup.Core.psm1',
        'assistant/AgentSetup.UI.ps1','assistant/catalog.json','assistant/README.txt','assistant/assets/deepseek-models.json',
        'assistant/AgentSetup.Localization.ps1','assistant/locales/zh-CN.json','assistant/locales/en-US.json','assistant/README.en.txt','assistant/AgentSetup.Clients.ps1','assistant/AgentSetup.SharingLocal.ps1',
        'assistant/assets/Codex-x64.msix','assistant/assets/Codex-License.xml')
    if (@($taskManifest.Files | Select-Object -ExpandProperty Name -Unique).Count -ne $taskManifest.Files.Count) { throw '安装包校验清单有重复项。 / Duplicate bundle manifest entries.' }
    foreach ($taskRequired in $taskAllowed[0..12]) {
        if ($taskRequired -notin $taskManifest.Files.Name) { throw ('安装包校验清单缺少： / Missing bundle manifest entry: ' + $taskRequired) }
    }
    foreach ($taskEntry in $taskManifest.Files) {
        if ($taskEntry.Name -notin $taskAllowed) { throw '安装包校验清单有不支持的路径。 / Unsupported bundle manifest path.' }
        if ((Get-FileHash -LiteralPath (Join-Path $taskBundleRoot $taskEntry.Name) -Algorithm SHA256).Hash -ne $taskEntry.Sha256) {
            throw ('安装包文件校验失败： / Bundle verification failed: ' + $taskEntry.Name + '。请重新解压。 / . Extract the ZIP again.')
        }
    }
}
if ($VerifyOnly) {
    if (-not (Test-Path -LiteralPath $taskManifestPath)) { throw '仅校验模式需要已打包的文件校验清单。 / VerifyOnly requires a packaged bundle manifest.' }
    Write-Output 'Assistant bundle verification passed. No user state was changed.'
    return
}
Import-Module (Join-Path $PSScriptRoot 'AgentSetup.Core.psm1') -Force
if (-not $DataRoot) { $DataRoot = Get-AssistantDataRoot }
Set-AssistantLanguage -Language $Language -DataRoot $DataRoot
if ($Action -ne 'UI') {
    $taskExit = 0
    try {
        switch ($Action) {
            'List' { Get-AssistantProfiles $DataRoot | Select-Object Id,ClientId,ProviderId,Model; return }
            'Install' {
                $taskProfile = Get-AssistantProfile $ProfileId $DataRoot
                $taskStatus = Install-AssistantClient $taskProfile.ClientId $DataRoot
                $taskMessage = (Get-AssistantText '客户端已安装：') + $taskStatus.Description
            }
            'Test' { $taskMessage = Test-AssistantConnection $ProfileId $DataRoot }
            'Launch' { Start-AssistantProfile $ProfileId $DataRoot $WorkingDirectory; $taskMessage = (Get-AssistantText '客户端启动流程已结束。') }
            'Backup' { $taskMessage = (Get-AssistantText '已创建备份：') + (Backup-AssistantProfile $ProfileId $DataRoot) }
            'Restore' { Restore-AssistantProfile $ProfileId $BackupId $DataRoot; $taskMessage = (Get-AssistantText '方案已恢复。') }
        }
        $taskResult = @{ Success = $true; Message = [string]$taskMessage }
    } catch {
        $taskResult = @{ Success = $false; Message = $_.Exception.Message }
        $taskExit = 1
    }
    if ($ResultPath) {
        $taskResultText = $taskResult | ConvertTo-Json
        [IO.File]::WriteAllText($ResultPath, $taskResultText, [Text.UTF8Encoding]::new($false))
    } else { Write-Host $taskResult.Message }
    if ($Action -eq 'Launch' -and $taskExit -ne 0) { $null = Read-Host (Get-AssistantText '按 Enter 关闭') }
    exit $taskExit
}
. (Join-Path $PSScriptRoot 'AgentSetup.UI.ps1')
Show-AssistantWindow -DataRoot $DataRoot -SmokeTest:$SmokeTest -PreviewPath $PreviewPath
