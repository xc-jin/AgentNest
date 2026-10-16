$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskModule = Import-Module (Join-Path $taskRoot 'assistant/AgentSetup.Core.psm1') -Force -PassThru
Set-AssistantLanguage -Language en-US
$taskTestRoot = Join-Path $taskRoot ('lab/evidence/sharing-local-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskTestRoot -Force | Out-Null
$taskData = Join-Path $taskTestRoot 'data'
$script:Count = 0
function Check([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw ('FAIL: ' + $Message) }; $script:Count++; Write-Output ('PASS: ' + $Message)
}
function Reject([scriptblock]$Work,[string]$Message) {
    $taskRejected = $false
    try { & $Work | Out-Null } catch { $taskRejected = $true }; Check $taskRejected $Message
}
$taskKeyText = 'fake-secret-only-for-sharing-local-tests'
$taskKey = ConvertTo-SecureString $taskKeyText -AsPlainText -Force
try {
    $taskCloud = New-AssistantPlan -Id cloud -ClientId opencode -ProviderId deepseek -Model deepseek-flash -DataRoot $taskData
    Reject { Save-AssistantProfile $taskCloud } 'Cloud profiles still require a key'
    $null = Save-AssistantProfile $taskCloud $taskKey
    $taskSession = Join-Path $taskCloud.ProfilePath 'session-private.txt'
    [IO.File]::WriteAllText($taskSession,'private-chat-never-share')
    $taskBefore = (Get-FileHash -LiteralPath (Join-Path $taskCloud.ProfilePath 'key.dpapi')).Hash
    $taskSharePath = Join-Path $taskTestRoot 'cloud.agent-profile.json'
    $null = Export-AssistantProfile -Id cloud -DataRoot $taskData -Path $taskSharePath
    $taskRaw = [IO.File]::ReadAllText($taskSharePath)
    $taskParsed = $taskRaw | ConvertFrom-Json
    Check (@($taskParsed.PSObject.Properties).Count -eq 7) 'Share uses exactly seven explicitly allowed fields'
    Check ($taskRaw -notmatch [regex]::Escape($taskKeyText) -and $taskRaw -notmatch 'key.dpapi|private-chat|config.json|C:|dpapi') 'Share excludes plaintext and encrypted credentials, sessions, config and local paths'
    Check ((Get-FileHash -LiteralPath (Join-Path $taskCloud.ProfilePath 'key.dpapi')).Hash -eq $taskBefore) 'Export does not change the source key'
    $taskDraft = Read-AssistantSharedProfile $taskSharePath $taskData
    Check ($taskDraft.Id -eq 'cloud' -and $taskDraft.ClientId -eq 'opencode' -and $taskDraft.BaseUrl -eq $taskCloud.BaseUrl) 'Import validates and preserves routing fields'
    $taskOther = Join-Path $taskTestRoot 'recipient'
    $null = Read-AssistantSharedProfile $taskSharePath $taskOther
    Check (-not (Test-Path -LiteralPath $taskOther)) 'Import is a read-only draft operation, even on another machine data root'
    Reject { Export-AssistantProfile cloud $taskSharePath $taskData } 'Export cannot silently overwrite files'
    $null = Export-AssistantProfile cloud $taskSharePath $taskData -Force
    Check ((Read-AssistantSharedProfile $taskSharePath $taskData).Model -eq 'deepseek-flash') 'Confirmed export can replace a valid sharing file'
    Reject { Export-AssistantProfile cloud (Join-Path $taskCloud.ProfilePath 'bad.agent-profile.json') $taskData } 'Export cannot overwrite files within managed data'
    Reject { Export-AssistantProfile cloud (Join-Path $taskTestRoot 'key.dpapi') $taskData } 'Export enforces the sharing extension'
    $taskInvalid = Join-Path $taskTestRoot 'invalid.agent-profile.json'
    foreach ($taskBad in @(
        ($taskRaw.Replace('"Version":  1','"Version":  2').Replace('"Version": 1','"Version": 2')),
        ($taskRaw.Replace('"Id":  "cloud"','"Id":  "../escape"').Replace('"Id": "cloud"','"Id": "../escape"')),
        ($taskRaw.Replace('https://api.deepseek.com/v1','http://example.com/v1')),
        ($taskRaw.Replace('"ProviderId":  "deepseek"','"ProviderId":  "unknown"').Replace('"ProviderId": "deepseek"','"ProviderId": "unknown"')),
        ($taskRaw.TrimEnd().TrimEnd('}') + ',"ApiKey":"leak"}'),
        'null','[]','{"Format":"agent-setup-profile"}',('{"padding":"' + ('x' * 66000) + '"}')
    )) {
        Check ($taskBad -cne $taskRaw) 'Invalid sharing fixture changes the original payload'
        [IO.File]::WriteAllText($taskInvalid,$taskBad)
        Reject { Read-AssistantSharedProfile $taskInvalid $taskData } 'Invalid / oversized / extra-field sharing payload is rejected'
    }
    [IO.File]::WriteAllText($taskInvalid,'{"unrelated":"preserve"}')
    Reject { Export-AssistantProfile cloud $taskInvalid $taskData -Force } 'Export does not replace unrelated JSON files'
    Check ([IO.File]::ReadAllText($taskInvalid) -ceq '{"unrelated":"preserve"}') 'Rejected overwrite preserves existing file'
    $taskCustom = New-AssistantPlan -Id custom-codex -ClientId codex-desktop -ProviderId custom-responses -Model deepseek-flash -BaseUrl https://example.com/v1 -DataRoot $taskData -ModelCatalogPath (Join-Path $taskRoot 'assistant/assets/deepseek-models.json')
    $null = Save-AssistantProfile $taskCustom $taskKey
    $taskCustomShare = Join-Path $taskTestRoot 'custom.agent-profile.json'
    $null = Export-AssistantProfile custom-codex $taskCustomShare $taskData
    Check ((Read-AssistantSharedProfile $taskCustomShare $taskOther).ProviderId -eq 'custom-responses') 'Custom Codex sharing validates metadata without copying a catalog'
    foreach ($taskProvider in @('ollama','lmstudio')) {
        foreach ($taskClient in @('opencode','aider')) {
            $taskId = $taskClient + '-' + $taskProvider
            $taskPlan = New-AssistantPlan -Id $taskId -ClientId $taskClient -ProviderId $taskProvider -Model 'local-model:7b' -DataRoot $taskData
            $null = Save-AssistantProfile $taskPlan
            Check (-not (Test-Path -LiteralPath (Join-Path $taskPlan.ProfilePath 'key.dpapi'))) ($taskId + ' saves without a key file')
            Check ((Get-AssistantProfile $taskId $taskData).BaseUrl -like 'http://127.0.0.1:*') ($taskId + ' reloads as a valid local profile')
            $taskLocalShare = Join-Path $taskTestRoot ($taskId + '.agent-profile.json')
            $null = Export-AssistantProfile $taskId $taskLocalShare $taskData
            Check ((Read-AssistantSharedProfile $taskLocalShare $taskOther).Model -eq 'local-model:7b') ($taskId + ' shares without a key')
        }
    }
    foreach ($taskUrl in @('http://localhost:2345/v1','http://127.0.0.1:2345/v1','http://[::1]:2345/v1','https://localhost:2345/v1')) {
        Check ([bool](New-AssistantPlan -Id local -ClientId aider -ProviderId ollama -Model local -BaseUrl $taskUrl -DataRoot $taskData)) ('Allow local endpoint: ' + $taskUrl)
    }
    foreach ($taskUrl in @('http://192.168.1.1/v1','https://example.com/v1','http://localhost.evil/v1','http://user:key@localhost/v1','http://localhost/v1?key=secret','http://localhost/v1#token','file:///C:/key')) {
        Reject { New-AssistantPlan -Id local -ClientId aider -ProviderId lmstudio -Model local -BaseUrl $taskUrl -DataRoot $taskData } ('Reject non-local or unsafe local endpoint: ' + $taskUrl)
    }
    $taskPlan = New-AssistantPlan -Id opencode-ollama -ClientId opencode -ProviderId ollama -Model local-model:7b -DataRoot $taskData
    $taskNoKeyBackup = Backup-AssistantProfile opencode-ollama $taskData
    $null = Save-AssistantProfile $taskPlan $taskKey
    Check (Test-Path -LiteralPath (Join-Path $taskPlan.ProfilePath 'key.dpapi')) 'Authenticated local services store DPAPI tokens'
    $taskWithKeyBackup = Backup-AssistantProfile opencode-ollama $taskData
    $null = Save-AssistantProfile $taskPlan
    Check (-not (Test-Path -LiteralPath (Join-Path $taskPlan.ProfilePath 'key.dpapi'))) 'Saving local blank key removes previous authentication token'
    Restore-AssistantProfile opencode-ollama $taskWithKeyBackup $taskData
    Check (Test-Path -LiteralPath (Join-Path $taskPlan.ProfilePath 'key.dpapi')) 'Restore recovers authenticated local configuration'
    Restore-AssistantProfile opencode-ollama $taskNoKeyBackup $taskData
    Check (-not (Test-Path -LiteralPath (Join-Path $taskPlan.ProfilePath 'key.dpapi'))) 'Restore accepts unauthenticated local backups and removes obsolete tokens'
    $taskCloudBackup = Backup-AssistantProfile cloud $taskData
    $taskBackupRoot = Join-Path (Join-Path (Join-Path $taskData 'backups') 'cloud') $taskCloudBackup
    $taskManifestPath = Join-Path $taskBackupRoot 'backup.json'
    $taskManifest = Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
    $taskManifest.Files.PSObject.Properties.Remove('key.dpapi')
    [IO.File]::WriteAllText($taskManifestPath,($taskManifest | ConvertTo-Json -Depth 8))
    Reject { Restore-AssistantProfile cloud $taskCloudBackup $taskData } 'Cloud backups still require an encrypted key'
    & $taskModule {
        $script:SharingOriginalWriter = (Get-Item Function:Write-AssistantText).ScriptBlock
        $script:SharingFailOnce = $true
        function script:Write-AssistantText {
            param($Path,$Text)
            if ($script:SharingFailOnce -and $Path -like '*profiles*opencode-ollama*profile.json') { $script:SharingFailOnce=$false; throw 'simulated metadata write failure' }
            & $script:SharingOriginalWriter $Path $Text
        }
    }
    Reject { Save-AssistantProfile $taskPlan $taskKey } 'Failed change from keyless to authenticated local profile is reported'
    Check (-not (Test-Path -LiteralPath (Join-Path $taskPlan.ProfilePath 'key.dpapi')) -and (Get-AssistantProfile opencode-ollama $taskData).Model -eq 'local-model:7b') 'Failed local save rolls back metadata and removes the newly written token'
    & $taskModule { Set-Item Function:script:Write-AssistantText $script:SharingOriginalWriter }
    & $taskModule {
        $script:LocalResponse = [pscustomobject]@{ data = @([pscustomobject]@{id='local-b:7b'},[pscustomobject]@{id='local-a'},[pscustomobject]@{id='local-a'},[pscustomobject]@{id='../bad model'}) }
        function script:Invoke-RestMethod {
            param($Uri,$Method,$Headers,$Body,$ContentType,$TimeoutSec,$MaximumRedirection)
            $script:LocalCall = @{ Uri=$Uri; Method=$Method; Headers=$Headers.Clone(); Body=$Body; Timeout=$TimeoutSec; Redirects=$MaximumRedirection }
            if ($script:LocalResponse -eq 'throw') { throw 'untrusted body containing fake-secret-only-for-sharing-local-tests' }
            $script:LocalResponse
        }
    }
    $taskModels = @(Get-AssistantLocalModels -ProviderId ollama -BaseUrl http://127.0.0.1:11434/v1)
    $taskCall = & $taskModule { $script:LocalCall }
    Check (($taskModels -join ',') -ceq 'local-a,local-b:7b') 'Discovery filters malformed IDs and removes duplicates'
    Check ($taskCall.Method -eq 'Get' -and $taskCall.Uri -eq 'http://127.0.0.1:11434/v1/models' -and $taskCall.Headers.Count -eq 0 -and $taskCall.Timeout -eq 5 -and $taskCall.Redirects -eq 0) 'Discovery uses local /models, no authentication, bounded timeout and no redirects'
    $null = Get-AssistantLocalModels -ProviderId lmstudio -BaseUrl http://localhost:1234/v1 -ApiKey $taskKey
    $taskCall = & $taskModule { $script:LocalCall }
    Check ($taskCall.Headers.Authorization -ceq ('Bearer ' + $taskKeyText)) 'Discovery supports optional LM Studio authentication'
    Reject { Get-AssistantLocalModels -ProviderId deepseek -BaseUrl https://api.deepseek.com/v1 } 'Discovery never calls cloud providers'
    & $taskModule { $script:LocalResponse = 'throw' }
    try { $null = Get-AssistantLocalModels -ProviderId ollama; throw 'expected failure' }
    catch { Check ($_.Exception.Message -notmatch 'untrusted|fake-secret') 'Discovery redacts untrusted server errors and tokens' }
    & $taskModule { $script:LocalResponse = [pscustomobject]@{data=@()} }
    Reject { Get-AssistantLocalModels -ProviderId ollama } 'Discovery reports an empty local model list'
    & $taskModule { $script:LocalResponse = [pscustomobject]@{choices=@([pscustomobject]@{message=[pscustomobject]@{content='OK'};finish_reason='stop'})} }
    $null = Test-AssistantConnection opencode-ollama $taskData
    $taskCall = & $taskModule { $script:LocalCall }
    Check (-not $taskCall.Headers.ContainsKey('Authorization') -and $taskCall.Uri -eq 'http://127.0.0.1:11434/v1/chat/completions') 'Local connection checks omit Authorization without a key'
    $null = Save-AssistantProfile $taskPlan $taskKey
    $null = Test-AssistantConnection opencode-ollama $taskData
    $taskCall = & $taskModule { $script:LocalCall }
    Check ($taskCall.Headers.Authorization -ceq ('Bearer ' + $taskKeyText)) 'Local connection checks send the token only when configured'
    $null = Save-AssistantProfile $taskPlan
    $taskFixture = Join-Path $taskTestRoot 'local-client.exe'
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class LocalClientFixture {
    public static void Main(string[] args) {
        File.WriteAllText(Environment.GetEnvironmentVariable("ASSISTANT_LOCAL_FIXTURE"),
            Environment.GetEnvironmentVariable("AGENT_ASSISTANT_API_KEY") + "|" +
            Environment.GetEnvironmentVariable("OPENAI_API_KEY"));
    }
}
'@ -OutputAssembly $taskFixture -OutputType ConsoleApplication
    & $taskModule { param($Exe) $script:LocalExe=$Exe; function script:Get-AssistantInstallStatus { param($ClientId,$DataRoot) [pscustomobject]@{Installed=$true;Description=$script:LocalExe} } } $taskFixture
    $taskPreviousFixture = $env:ASSISTANT_LOCAL_FIXTURE
    try {
        foreach ($taskClient in @('opencode','aider')) {
            $env:ASSISTANT_LOCAL_FIXTURE = Join-Path $taskTestRoot ($taskClient + '-env.txt')
            Start-AssistantProfile ($taskClient + '-ollama') $taskData $taskTestRoot
            $taskEnv = [IO.File]::ReadAllText($env:ASSISTANT_LOCAL_FIXTURE)
            Check ($taskEnv -ceq $(if ($taskClient -eq 'opencode') { 'local-no-key|' } else { '|local-no-key' })) ($taskClient + ' launches keyless local profiles using a non-secret SDK placeholder')
        }
    } finally { $env:ASSISTANT_LOCAL_FIXTURE = $taskPreviousFixture }
} finally { $taskKey.Dispose(); Remove-Module $taskModule.Name -Force }
Write-Output ('ALL PASSED: ' + $script:Count)
Write-Output ('Evidence: ' + $taskTestRoot)
Write-Output 'Only isolated fixtures were used. No real server, client, installer, credential or VM was accessed.'
