$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskModule = Import-Module (Join-Path $taskRoot 'assistant/AgentSetup.Core.psm1') -Force -PassThru
$taskTestRoot = Join-Path $taskRoot ('lab/evidence/assistant-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskTestRoot -Force | Out-Null
$script:taskPassed = 0
function Assert-Check([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw ('FAIL: ' + $Message) }
    $script:taskPassed++; Write-Output ('PASS: ' + $Message)
}
function Assert-Rejected([scriptblock]$Work,[string]$Message) {
    $taskRejected = $false
    try { & $Work | Out-Null } catch { $taskRejected = $true }
    Assert-Check $taskRejected $Message
}
foreach ($taskFile in @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'assistant') -File | Where-Object Extension -in '.ps1','.psm1') + @(Get-Item (Join-Path $taskRoot 'Build-Assistant.ps1'))) {
    $taskTokens = $null; $taskErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($taskFile.FullName,[ref]$taskTokens,[ref]$taskErrors) | Out-Null
    Assert-Check ($taskErrors.Count -eq 0) ('PowerShell parse: ' + $taskFile.Name)
}
$taskZh = Get-Content -LiteralPath (Join-Path $taskRoot 'assistant/locales/zh-CN.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$taskEn = Get-Content -LiteralPath (Join-Path $taskRoot 'assistant/locales/en-US.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Check (@(Compare-Object @($taskZh.PSObject.Properties.Name) @($taskEn.PSObject.Properties.Name)).Count -eq 0) 'Both language resources contain the same keys'
Assert-Check (@($taskEn.PSObject.Properties | Where-Object { [string]::IsNullOrWhiteSpace($_.Value) -or $_.Value -match '[一-龥]' }).Count -eq 0) 'English resource values are complete and contain no Chinese text'
$taskMissingKeys = @()
foreach ($taskSource in Get-ChildItem -LiteralPath (Join-Path $taskRoot 'assistant') -File | Where-Object Extension -in '.ps1','.psm1') {
    $taskTokens = $null; $taskErrors = $null
    $taskAst = [Management.Automation.Language.Parser]::ParseFile($taskSource.FullName,[ref]$taskTokens,[ref]$taskErrors)
    $taskCalls = $taskAst.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] -and $Node.GetCommandName() -in @('Get-AssistantText','Add-Label','Add-Button') }, $true)
    foreach ($taskCall in $taskCalls) {
        if ($taskCall.CommandElements.Count -gt 1 -and $taskCall.CommandElements[1] -is [Management.Automation.Language.StringConstantExpressionAst]) {
            $taskKey = $taskCall.CommandElements[1].Value
            if (-not $taskEn.PSObject.Properties[$taskKey]) { $taskMissingKeys += $taskKey }
        }
    }
}
Assert-Check ($taskMissingKeys.Count -eq 0) ('All static UI and message translation keys exist: ' + ($taskMissingKeys -join ', '))
Set-AssistantLanguage -Language en-US
Assert-Check ((Get-AssistantText '未安装') -ceq 'Not installed') 'English messages selected'
try { $null = Get-AssistantDataRoot 'relative'; throw 'Expected rejection' }
catch { Assert-Check ($_.Exception.Message -ceq 'The data directory must be an absolute path.') 'Core validation errors use English'
}
Set-AssistantLanguage -Language zh-CN
Assert-Check ((Get-AssistantText '未安装') -ceq '未安装') 'Chinese messages selected'
Assert-Rejected { Set-AssistantLanguage -Language fr-FR } 'Unsupported languages are rejected'
$taskPreferenceRoot = Join-Path $taskTestRoot 'preference-tests'
Save-AssistantLanguagePreference en-US $taskPreferenceRoot
Set-AssistantLanguage -Language zh-CN
Set-AssistantLanguage -DataRoot $taskPreferenceRoot
Assert-Check ((Get-AssistantLanguage) -eq 'en-US') 'Saved language is restored on the next initialization'
$taskPreferenceFile = Join-Path $taskPreferenceRoot 'preferences.json'
[IO.File]::WriteAllText($taskPreferenceFile,'{"Language":"en-US","OtherSetting":"preserve"}')
Save-AssistantLanguagePreference zh-CN $taskPreferenceRoot
$taskPreference = Get-Content -LiteralPath $taskPreferenceFile -Raw | ConvertFrom-Json
Assert-Check ($taskPreference.Language -eq 'zh-CN' -and $taskPreference.OtherSetting -eq 'preserve') 'Updating language preserves other preferences'
Set-AssistantLanguage -Language en-US -DataRoot $taskPreferenceRoot
Assert-Check ((Get-AssistantLanguage) -eq 'en-US' -and (Get-Content -LiteralPath $taskPreferenceFile -Raw | ConvertFrom-Json).Language -eq 'zh-CN') 'Explicit language overrides the preference for this run only'
foreach ($taskBadPreference in @('{broken-json','{"Language":"fr-FR"}','null','[]')) {
    [IO.File]::WriteAllText($taskPreferenceFile,$taskBadPreference)
    Set-AssistantLanguage -DataRoot $taskPreferenceRoot
    $taskCultureLanguage = if ([Globalization.CultureInfo]::CurrentUICulture.Name -like 'zh*') { 'zh-CN' } else { 'en-US' }
    Assert-Check ((Get-AssistantLanguage) -eq $taskCultureLanguage) ('Invalid preference falls back to Windows language: ' + $taskBadPreference)
}
Set-AssistantLanguage -Language zh-CN
$taskChinesePlan = New-AssistantPlan -Id locale-check -ClientId codex-desktop -ProviderId deepseek -Model deepseek-flash -DataRoot $taskTestRoot
Set-AssistantLanguage -Language en-US
$taskEnglishPlan = New-AssistantPlan -Id locale-check -ClientId codex-desktop -ProviderId deepseek -Model deepseek-flash -DataRoot $taskTestRoot
Assert-Check ($taskChinesePlan.Files['codex/config.toml'] -ceq $taskEnglishPlan.Files['codex/config.toml']) 'Language selection does not change generated client configuration'
$taskCatalog = Get-AssistantCatalog
Assert-Check ($taskCatalog.clients.Count -eq 4 -and $taskCatalog.providers.Count -eq 17) 'Four clients and seventeen provider / region / custom presets'
foreach ($taskClient in $taskCatalog.clients) {
    Assert-Check ([bool]$taskEn.PSObject.Properties[$taskClient.name]) ('Client display translation: ' + $taskClient.id)
    foreach ($taskProvider in $taskCatalog.providers) {
        $taskMatrixArgs = @{ Id = 'matrix'; ClientId = $taskClient.id; ProviderId = $taskProvider.id; Model = 'deepseek-flash'; DataRoot = $taskTestRoot }
        if ($taskProvider.id -like 'custom-*') { $taskMatrixArgs.BaseUrl = 'https://example.com/v1' }
        if ($taskProvider.id -eq 'custom-responses') { $taskMatrixArgs.ModelCatalogPath = Join-Path $taskRoot 'assistant/assets/deepseek-models.json' }
        if ($taskProvider.routes.PSObject.Properties[$taskClient.protocol]) {
            Assert-Check ((New-AssistantPlan @taskMatrixArgs).Protocol -eq $taskClient.protocol) ('Accept protocol combination: ' + $taskClient.id + '/' + $taskProvider.id)
        } else {
            Assert-Rejected { New-AssistantPlan @taskMatrixArgs } ('Reject protocol combination: ' + $taskClient.id + '/' + $taskProvider.id)
        }
    }
}
foreach ($taskProvider in $taskCatalog.providers) { Assert-Check ([bool]$taskEn.PSObject.Properties[$taskProvider.name]) ('Provider display translation: ' + $taskProvider.id) }
foreach ($taskCase in @(
    @('codex-desktop','deepseek'),@('codex-desktop','openai'),@('claude-code','deepseek'),@('claude-code','anthropic'),@('claude-code','custom-messages'))) {
    $taskArguments = @{ Id = 'test'; ClientId = $taskCase[0]; ProviderId = $taskCase[1]; Model = 'deepseek-flash'; DataRoot = $taskTestRoot }
    if ($taskCase[1] -eq 'custom-messages') { $taskArguments.BaseUrl = 'https://gateway.example.com/anthropic' }
    $taskPlan = New-AssistantPlan @taskArguments
    Assert-Check ($taskPlan.Files.Count -gt 0) ('Plan: ' + ($taskCase -join ' + '))
}
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $taskTestRoot 'profiles'))) 'Planning does not write files'
Assert-Rejected { New-AssistantPlan -Id test -ClientId codex-desktop -ProviderId anthropic -Model test -DataRoot $taskTestRoot } 'Reject Messages provider for Codex'
Assert-Rejected { New-AssistantPlan -Id test -ClientId claude-code -ProviderId openai -Model test -DataRoot $taskTestRoot } 'Reject Responses provider for Claude'
foreach ($taskInvalidId in @('../escape','CON','a/b','bad name','a";exit')) {
    Assert-Rejected { New-AssistantPlan -Id $taskInvalidId -ClientId codex-desktop -ProviderId deepseek -Model deepseek-flash -DataRoot $taskTestRoot } ('Reject invalid profile ID: ' + $taskInvalidId)
}
foreach ($taskInvalidUrl in @('http://example.com','https://user:secret@example.com','https://example.com?key=secret','https://example.com/#fragment')) {
    Assert-Rejected { New-AssistantPlan -Id test -ClientId claude-code -ProviderId custom-messages -Model test -BaseUrl $taskInvalidUrl -DataRoot $taskTestRoot } ('Reject unsafe endpoint: ' + $taskInvalidUrl)
}
Assert-Rejected { New-AssistantPlan -Id test -ClientId codex-desktop -ProviderId deepseek -Model deepseek-flash -BaseUrl 'https://other.example.com' -DataRoot $taskTestRoot } 'Official provider cannot silently change endpoint'
Assert-Rejected { New-AssistantPlan -Id test -ClientId codex-desktop -ProviderId custom-responses -Model custom-model -BaseUrl https://example.com/v1 -DataRoot $taskTestRoot } 'Custom Codex models require a catalog'
$taskCustomPlan = New-AssistantPlan -Id custom -ClientId codex-desktop -ProviderId custom-responses -Model deepseek-flash -BaseUrl https://example.com/v1 -DataRoot $taskTestRoot -ModelCatalogPath (Join-Path $taskRoot 'assistant/assets/deepseek-models.json')
Assert-Check ($taskCustomPlan.Files.Contains('codex/models.json')) 'Custom Codex catalog included'
$taskFakeKey = 'test-only-never-valid-api-key'
$taskSecure = ConvertTo-SecureString $taskFakeKey -AsPlainText -Force
try {
    $taskPlan1 = New-AssistantPlan -Id sample -ClientId codex-desktop -ProviderId deepseek -Model deepseek-flash -DataRoot $taskTestRoot
    $null = Save-AssistantProfile $taskPlan1 $taskSecure
    $taskConfig = [IO.File]::ReadAllText((Join-Path $taskPlan1.ProfilePath 'codex/config.toml'))
    Assert-Check ($taskConfig -match '(?m)^model = "deepseek-flash"\r?$' -and $taskConfig -match '(?m)^name = "DeepSeek"\r?$') 'TOML scalar settings occupy individual lines'
    Assert-Check ($taskConfig -notmatch [regex]::Escape($taskFakeKey) -and $taskConfig -match 'env_key = "AGENT_ASSISTANT_API_KEY"') 'No plaintext key in Codex config'
    $taskCipher = [IO.File]::ReadAllText((Join-Path $taskPlan1.ProfilePath 'key.dpapi'))
    Assert-Check ($taskCipher -notmatch [regex]::Escape($taskFakeKey)) 'Key is DPAPI encrypted'
    $taskRoundTrip = & $taskModule { param($Id,$Root) $taskSecret = Get-AssistantSecret $Id $Root; $taskPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret); try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPtr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPtr); $taskSecret.Dispose() } } sample $taskTestRoot
    Assert-Check ($taskRoundTrip -ceq $taskFakeKey) 'DPAPI decrypts for current Windows user'
    $taskProfile = Get-AssistantProfile sample $taskTestRoot
    $taskEnv = & $taskModule { param($Profile,$Path,$Key) Get-AssistantLaunchEnvironment $Profile $Path $Key } $taskProfile $taskPlan1.ProfilePath $taskFakeKey
    Assert-Check ($taskEnv.CODEX_HOME -eq (Join-Path $taskPlan1.ProfilePath 'codex') -and $taskEnv.AGENT_ASSISTANT_API_KEY -ceq $taskFakeKey) 'Codex launch uses dedicated home and credential environment'
    $taskSaved = Save-AssistantProfile (New-AssistantPlan -Id sample -ClientId codex-desktop -ProviderId deepseek -Model deepseek-v4-pro -DataRoot $taskTestRoot) $taskSecure
    Assert-Check ([bool]$taskSaved.BackupId) 'Update creates a backup'
    $taskSessionPath = Join-Path $taskPlan1.ProfilePath 'codex/session-test.txt'
    [IO.File]::WriteAllText($taskSessionPath,'keep-session')
    Restore-AssistantProfile sample $taskSaved.BackupId $taskTestRoot
    Assert-Check ((Get-AssistantProfile sample $taskTestRoot).Model -eq 'deepseek-flash') 'Restore returns original model'
    Assert-Check ([IO.File]::ReadAllText($taskSessionPath) -eq 'keep-session') 'Restore preserves session files'
    Assert-Check (@(Get-AssistantBackups sample $taskTestRoot).Count -eq 2) 'Restore creates a safety backup'
    $taskBackupConfig = Join-Path (Join-Path (Join-Path (Join-Path $taskTestRoot 'backups') 'sample') $taskSaved.BackupId) 'codex/config.toml'
    [IO.File]::AppendAllText($taskBackupConfig,'tampered')
    Assert-Rejected { Restore-AssistantProfile sample $taskSaved.BackupId $taskTestRoot } 'Reject tampered backup before restore'
    Assert-Rejected { Restore-AssistantProfile sample '../outside' $taskTestRoot } 'Reject backup path traversal'
    Assert-Rejected { New-AssistantPlan -Id sample -ClientId claude-code -ProviderId deepseek -Model deepseek-flash -DataRoot $taskTestRoot } 'Existing profile cannot switch client'
    $taskClaudePlan = New-AssistantPlan -Id claude-sample -ClientId claude-code -ProviderId deepseek -Model deepseek-flash -DataRoot $taskTestRoot
    $null = Save-AssistantProfile $taskClaudePlan $taskSecure
    $taskClaude = Get-AssistantProfile claude-sample $taskTestRoot
    $taskClaudeEnv = & $taskModule { param($Profile,$Path,$Key) Get-AssistantLaunchEnvironment $Profile $Path $Key } $taskClaude $taskClaudePlan.ProfilePath $taskFakeKey
    Assert-Check ($taskClaudeEnv.ANTHROPIC_AUTH_TOKEN -ceq $taskFakeKey -and $null -eq $taskClaudeEnv.ANTHROPIC_API_KEY -and $taskClaudeEnv.CLAUDE_CONFIG_DIR -eq (Join-Path $taskClaudePlan.ProfilePath 'claude')) 'Claude has isolated home and no conflicting Anthropic key'
    # Mock HTTP in module scope: no real network call or paid API is used.
    & $taskModule {
        $script:MockMode = 'success'
        function script:Invoke-RestMethod {
            param($Uri,$Method,$Headers,$Body,$ContentType,$TimeoutSec,$MaximumRedirection)
            $script:MockRequest = @{ Uri = $Uri; Body = ($Body | ConvertFrom-Json); Headers = $Headers; Redirects = $MaximumRedirection }
            if ($script:MockMode -eq 'error') { throw 'DO-NOT-LEAK-test-only-never-valid-api-key' }
            if ($script:MockMode -eq 'incomplete') { return [pscustomobject]@{ object = 'response'; status = 'incomplete'; output = @() } }
            if ($Uri -match '/chat/completions$') { return [pscustomobject]@{ choices = @([pscustomobject]@{ message = [pscustomobject]@{ content = 'OK' }; finish_reason = 'stop' }) } }
            if ($Uri -match '/messages$') { return [pscustomobject]@{ type = 'message'; content = @(@{ type = 'text'; text = 'OK' }) } }
            [pscustomobject]@{ object = 'response'; status = 'completed'; output = @(@{ type = 'message' }) }
        }
    }
    $taskResult = Test-AssistantConnection sample $taskTestRoot
    $taskRequest = & $taskModule { $script:MockRequest }
    Assert-Check ($taskRequest.Uri -eq 'https://api.deepseek.com/responses' -and $taskRequest.Redirects -eq 0 -and $taskRequest.Body.model -eq 'deepseek-flash') 'Responses probe builds correct request and refuses redirects'
    $null = Test-AssistantConnection claude-sample $taskTestRoot
    $taskRequest = & $taskModule { $script:MockRequest }
    Assert-Check ($taskRequest.Uri -eq 'https://api.deepseek.com/anthropic/v1/messages' -and $taskRequest.Headers.Authorization -eq ('Bearer ' + $taskFakeKey)) 'DeepSeek Messages request route and bearer authentication'
    foreach ($taskProviderCase in @(@('openai-probe','codex-desktop','openai','gpt-test'),@('anthropic-probe','claude-code','anthropic','claude-test'),@('custom-probe','claude-code','custom-messages','custom-model'))) {
        $taskPlanArguments = @{ Id = $taskProviderCase[0]; ClientId = $taskProviderCase[1]; ProviderId = $taskProviderCase[2]; Model = $taskProviderCase[3]; DataRoot = $taskTestRoot }
        if ($taskProviderCase[2] -eq 'custom-messages') { $taskPlanArguments.BaseUrl = 'https://gateway.example.com/v1' }
        $null = Save-AssistantProfile (New-AssistantPlan @taskPlanArguments) $taskSecure
        $null = Test-AssistantConnection $taskProviderCase[0] $taskTestRoot
        $taskRequest = & $taskModule { $script:MockRequest }
        switch ($taskProviderCase[2]) {
            'openai' { Assert-Check ($taskRequest.Uri -eq 'https://api.openai.com/v1/responses' -and $taskRequest.Headers.Authorization -eq ('Bearer ' + $taskFakeKey)) 'OpenAI Responses route and authentication' }
            'anthropic' { Assert-Check ($taskRequest.Uri -eq 'https://api.anthropic.com/v1/messages' -and $taskRequest.Headers['x-api-key'] -ceq $taskFakeKey -and -not $taskRequest.Headers.ContainsKey('Authorization')) 'Anthropic Messages x-api-key authentication' }
            'custom-messages' { Assert-Check ($taskRequest.Uri -eq 'https://gateway.example.com/v1/messages') 'Custom Messages base ending in v1 is not doubled' }
        }
    }
    foreach ($taskChatClient in @('opencode','aider')) {
        foreach ($taskProvider in @($taskCatalog.providers | Where-Object { $_.routes.PSObject.Properties['chat'] })) {
            $taskChatId = $taskChatClient + '-' + $taskProvider.id
            $taskPlanArgs = @{ Id = $taskChatId; ClientId = $taskChatClient; ProviderId = $taskProvider.id; Model = 'deepseek-flash'; DataRoot = $taskTestRoot }
            if ($taskProvider.id -eq 'custom-chat') { $taskPlanArgs.BaseUrl = 'https://gateway.example.com/v1' }
            $taskChatPlan = New-AssistantPlan @taskPlanArgs
            $null = Save-AssistantProfile $taskChatPlan $taskSecure
            $taskChatProfile = Get-AssistantProfile $taskChatId $taskTestRoot
            $null = Test-AssistantConnection $taskChatId $taskTestRoot
            $taskRequest = & $taskModule { $script:MockRequest }
            Assert-Check ($taskRequest.Uri -eq ($taskChatProfile.BaseUrl + '/chat/completions') -and $taskRequest.Body.model -eq 'deepseek-flash' -and $taskRequest.Redirects -eq 0 -and $taskRequest.Headers.Authorization -ceq ('Bearer ' + $taskFakeKey)) ('Chat probe routing and auth: ' + $taskChatId)
            if ($taskProvider.id -eq 'openai') { Assert-Check ($taskRequest.Body.max_completion_tokens -eq 512 -and -not $taskRequest.Body.PSObject.Properties['max_tokens']) 'OpenAI Chat uses max_completion_tokens' }
            $taskClientFile = if ($taskChatClient -eq 'opencode') { 'opencode/opencode.json' } else { 'aider/config.yml' }
            $taskClientText = [IO.File]::ReadAllText((Join-Path $taskChatPlan.ProfilePath $taskClientFile))
            Assert-Check ($taskClientText -notmatch [regex]::Escape($taskFakeKey)) ('No plaintext key in configuration: ' + $taskChatId)
            if ($taskProvider.id -eq 'gemini') {
                $taskLaunchEnv = & $taskModule { param($Profile,$Path,$Key) Get-AssistantLaunchEnvironment $Profile $Path $Key } $taskChatProfile $taskChatPlan.ProfilePath $taskFakeKey
                $taskLaunchArgs = @(& $taskModule { param($Profile,$Path) Get-AssistantTerminalArguments $Profile $Path } $taskChatProfile $taskChatPlan.ProfilePath)
                if ($taskChatClient -eq 'opencode') {
                    $taskClientConfig = $taskClientText | ConvertFrom-Json
                    Assert-Check ($taskClientConfig.model -eq 'assistant/deepseek-flash' -and $taskClientConfig.provider.assistant.options.apiKey -eq '{env:AGENT_ASSISTANT_API_KEY}' -and $taskClientConfig.provider.assistant.npm -eq '@ai-sdk/openai-compatible') 'OpenCode config uses Chat adapter and environment key reference'
                    Assert-Check ($taskLaunchEnv.AGENT_ASSISTANT_API_KEY -ceq $taskFakeKey -and $taskLaunchEnv.XDG_DATA_HOME.StartsWith($taskChatPlan.ProfilePath) -and $taskLaunchEnv.OPENCODE_CONFIG_CONTENT -ceq $taskClientText -and $taskLaunchArgs[1] -eq 'assistant/deepseek-flash') 'OpenCode has per-profile data, runtime routing and selected model'
                } else {
                    Assert-Check ($taskLaunchEnv.PYTHON_DOTENV_DISABLED -eq '1' -and $taskLaunchEnv.AIDER_OPENAI_API_KEY -ceq $taskFakeKey -and $taskLaunchEnv.OPENAI_API_BASE -ceq $taskChatProfile.BaseUrl) 'Aider disables dotenv rerouting and injects selected key and endpoint'
                    Assert-Check ($taskLaunchArgs -contains 'openai/deepseek-flash' -and $taskLaunchArgs -contains $taskChatProfile.BaseUrl -and $taskLaunchArgs -contains (Join-Path $taskChatPlan.ProfilePath 'aider/chat.history.md')) 'Aider pins endpoint and model in non-secret arguments and isolates history'
                }
                Assert-Check (($taskLaunchArgs -join ' ') -notmatch [regex]::Escape($taskFakeKey)) ('Key excluded from launch arguments: ' + $taskChatClient)
                $taskHistory = Join-Path $taskChatPlan.ProfilePath ($taskChatClient + '/session-evidence.txt')
                [IO.File]::WriteAllText($taskHistory,'preserve-client-session')
                $taskOldConfigHash = (Get-FileHash -LiteralPath (Join-Path $taskChatPlan.ProfilePath $taskClientFile)).Hash
                $null = Save-AssistantProfile $taskChatPlan $taskSecure
                $taskBackupName = @(Get-AssistantBackups $taskChatId $taskTestRoot)[0]
                Restore-AssistantProfile $taskChatId $taskBackupName $taskTestRoot
                Assert-Check ((Get-FileHash -LiteralPath (Join-Path $taskChatPlan.ProfilePath $taskClientFile)).Hash -eq $taskOldConfigHash -and [IO.File]::ReadAllText($taskHistory) -eq 'preserve-client-session') ('Backup and restore preserve managed config and sessions: ' + $taskChatClient)
            }
        }
    }
    foreach ($taskMessagesProvider in @('qwen-cn','qwen-intl','qwen-coding-cn','zhipu-coding')) {
        $taskMessagesId = 'claude-' + $taskMessagesProvider
        $null = Save-AssistantProfile (New-AssistantPlan -Id $taskMessagesId -ClientId claude-code -ProviderId $taskMessagesProvider -Model model-test -DataRoot $taskTestRoot) $taskSecure
        $null = Test-AssistantConnection $taskMessagesId $taskTestRoot
        $taskRequest = & $taskModule { $script:MockRequest }
        $taskExpectedBase = @($taskCatalog.providers | Where-Object id -eq $taskMessagesProvider)[0].routes.messages
        Assert-Check ($taskRequest.Uri -eq ($taskExpectedBase + '/v1/messages') -and $taskRequest.Headers.Authorization -ceq ('Bearer ' + $taskFakeKey)) ('Messages provider routing and auth: ' + $taskMessagesProvider)
    }
    & $taskModule { $script:MockMode = 'incomplete' }
    Assert-Rejected { Test-AssistantConnection sample $taskTestRoot } 'Incomplete response is not reported as success'
    Assert-Rejected { Test-AssistantConnection opencode-gemini $taskTestRoot } 'Incomplete Chat response is not reported as success'
    & $taskModule { $script:MockMode = 'error' }
    try { $null = Test-AssistantConnection sample $taskTestRoot; throw 'Expected rejection' }
    catch { Assert-Check ($_.Exception.Message -notmatch 'DO-NOT-LEAK|test-only-never-valid') 'HTTP errors do not leak response body or key' }
    try { $null = Test-AssistantConnection aider-gemini $taskTestRoot; throw 'Expected rejection' }
    catch { Assert-Check ($_.Exception.Message -notmatch 'DO-NOT-LEAK|test-only-never-valid') 'Chat errors do not leak response body or key' }
    & $taskModule {
        $script:OriginalWriter = (Get-Command Write-AssistantText).ScriptBlock
        $script:FailOnce = $true
        function script:Write-AssistantText {
            param($Path,$Text)
            if ($script:FailOnce -and $Path.EndsWith('key.dpapi')) { $script:FailOnce = $false; throw 'Simulated write failure' }
            & $script:OriginalWriter $Path $Text
        }
    }
    Assert-Rejected { Save-AssistantProfile (New-AssistantPlan -Id sample -ClientId codex-desktop -ProviderId deepseek -Model deepseek-v4-pro -DataRoot $taskTestRoot) $taskSecure } 'Write failure is reported'
    Assert-Check ((Get-AssistantProfile sample $taskTestRoot).Model -eq 'deepseek-flash') 'Failed update rolls back metadata and configuration'
    $taskFinalConfig = [IO.File]::ReadAllText((Join-Path $taskPlan1.ProfilePath 'codex/config.toml'))
    Assert-Check ($taskFinalConfig -match 'model = "deepseek-flash"') 'Failed update rollback restores TOML'
    # A local fixture verifies real Windows argument parsing and child environment handling.
    $taskFixtureExe = Join-Path $taskTestRoot 'launch-fixture.exe'
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Web.Script.Serialization;
public class AssistantLaunchFixture {
    public static void Main(string[] args) {
        var data = new Dictionary<string, object>();
        data["Args"] = args;
        foreach (var name in new [] {"OPENAI_API_KEY", "AIDER_OPENAI_API_KEY", "AGENT_ASSISTANT_API_KEY", "OPENAI_API_BASE", "PYTHON_DOTENV_DISABLED", "OPENCODE_CONFIG", "XDG_DATA_HOME"}) {
            data[name] = Environment.GetEnvironmentVariable(name);
        }
        File.WriteAllText(Environment.GetEnvironmentVariable("AGENT_SETUP_FIXTURE_RESULT"), new JavaScriptSerializer().Serialize(data));
    }
}
'@ -ReferencedAssemblies System.Web.Extensions -OutputAssembly $taskFixtureExe -OutputType ConsoleApplication
    $taskTrickyArgs = @('plain','C:\folder with spaces\','quoted"value','中文路径','amp&semi;$(literal)','')
    $taskFixtureResult = Join-Path $taskTestRoot 'argument-roundtrip.json'
    $taskFixtureInfo = & $taskModule { param($Exe,$Arguments,$Result) New-AssistantProcessInfo -Executable $Exe -Arguments $Arguments -Environment @{ AGENT_SETUP_FIXTURE_RESULT = $Result; OPENAI_API_KEY = $null; AIDER_OPENAI_API_KEY = $null; AGENT_ASSISTANT_API_KEY = $null } } $taskFixtureExe $taskTrickyArgs $taskFixtureResult
    $taskFixtureProcess = [Diagnostics.Process]::Start($taskFixtureInfo)
    try { $taskFixtureProcess.WaitForExit(); Assert-Check ($taskFixtureProcess.ExitCode -eq 0) 'Windows process fixture exits successfully' } finally { $taskFixtureProcess.Dispose() }
    $taskArgumentResult = Get-Content -LiteralPath $taskFixtureResult -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Check (($taskArgumentResult.Args | ConvertTo-Json -Compress) -ceq ($taskTrickyArgs | ConvertTo-Json -Compress)) 'Windows arguments round-trip spaces, quotes, trailing slash, Unicode, shell symbols and empty values'
    & $taskModule {
        param($Exe,$Result)
        $script:FixtureExe = $Exe; $script:FixtureResult = $Result
        $script:OriginalProcessBuilder = (Get-Command New-AssistantProcessInfo).ScriptBlock
        function script:New-AssistantProcessInfo {
            param($Executable,$Arguments,$WorkingDirectory,$Environment)
            $Environment['AGENT_SETUP_FIXTURE_RESULT'] = $script:FixtureResult
            & $script:OriginalProcessBuilder -Executable $Executable -Arguments $Arguments -WorkingDirectory $WorkingDirectory -Environment $Environment
        }
        function script:Get-AssistantInstallStatus { param($ClientId,$DataRoot) [pscustomobject]@{ Installed = $true; Description = $script:FixtureExe } }
    } $taskFixtureExe (Join-Path $taskTestRoot 'profile-launch.json')
    foreach ($taskLaunchClient in @('opencode','aider')) {
        Start-AssistantProfile ($taskLaunchClient + '-gemini') $taskTestRoot $taskTestRoot
        $taskChild = Get-Content -LiteralPath (Join-Path $taskTestRoot 'profile-launch.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $taskChildKey = if ($taskLaunchClient -eq 'aider') { $taskChild.OPENAI_API_KEY } else { $taskChild.AGENT_ASSISTANT_API_KEY }
        Assert-Check ($taskChildKey -ceq $taskFakeKey -and ($taskChild.Args -join ' ') -notmatch [regex]::Escape($taskFakeKey)) ('Launch adapter supplies key only through the child environment: ' + $taskLaunchClient)
        if ($taskLaunchClient -eq 'aider') { Assert-Check ($taskChild.PYTHON_DOTENV_DISABLED -eq '1' -and $taskChild.Args -contains 'https://generativelanguage.googleapis.com/v1beta/openai') 'Aider launch process receives dotenv opt-out and fixed endpoint' }
        else { Assert-Check ($taskChild.XDG_DATA_HOME.StartsWith($taskTestRoot) -and $taskChild.Args -contains 'assistant/deepseek-flash') 'OpenCode launch process receives isolated data home and selected model' }
    }
    # Installer calls are mocked; no package manager or client is actually run.
    & $taskModule {
        $script:InstallEvents = @(); $script:InstallChecks = 0
        $script:OriginalAiderInstaller = (Get-Command Install-AssistantAider).ScriptBlock
        function script:Get-AssistantInstallStatus { param($ClientId,$DataRoot) $script:InstallChecks++; [pscustomobject]@{ Installed = ($script:InstallChecks -gt 1); Description = 'mock-installed' } }
        function script:Invoke-AssistantWinget { param($PackageId) $script:InstallEvents += $PackageId }
        function script:Install-AssistantAider { param($DataRoot) $script:InstallEvents += 'aider-managed' }
    }
    Assert-Check ((Install-AssistantClient opencode $taskTestRoot).Installed) 'OpenCode installer confirms installation after package manager exits'
    Assert-Check ((& $taskModule { $script:InstallEvents }) -eq 'SST.opencode') 'OpenCode installer selects the verified winget package'
    & $taskModule { $script:InstallChecks = 0; $script:InstallEvents = @() }
    Assert-Check ((Install-AssistantClient aider $taskTestRoot).Installed) 'Aider installer confirms managed installation'
    Assert-Check ((& $taskModule { $script:InstallEvents }) -eq 'aider-managed') 'Aider installation uses the managed environment adapter'
    # Exercise the genuine Aider adapter with native process mocks.
    & $taskModule {
        $script:UvCalls = @()
        function script:Find-AssistantTool { param($Name,$PackagePrefix,$Candidates) 'mock-uv.exe' }
        function script:Invoke-AssistantNativeProcess { param($Executable,$Arguments,$Environment) $script:UvCalls += ,@($Arguments) }
        & $script:OriginalAiderInstaller (Join-Path (Split-Path -Parent $script:FixtureResult) 'aider-install-test')
    }
    $taskUvCalls = @(& $taskModule { $script:UvCalls })
    Assert-Check ($taskUvCalls.Count -eq 2 -and $taskUvCalls[0][0] -eq 'venv' -and $taskUvCalls[0] -contains '3.12' -and $taskUvCalls[1] -contains 'aider-chat' -and $taskUvCalls[1] -contains 'python-dotenv>=1.2.0') 'Aider installation creates Python 3.12 environment and requires dotenv opt-out support'
    $taskAiderStatusRoot = Join-Path $taskTestRoot 'aider-install-test'
    $taskAiderExe = Join-Path $taskAiderStatusRoot 'tools/aider/venv/Scripts/aider.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $taskAiderExe) -Force | Out-Null
    [IO.File]::WriteAllText($taskAiderExe,'fixture only; never execute')
    Assert-Check (& $taskModule { param($Root) Test-AssistantManagedAider $Root } $taskAiderStatusRoot) 'Managed Aider is recognized after a complete dependency install'
    [IO.File]::WriteAllText((Join-Path $taskAiderStatusRoot 'tools/aider/install.json'),'{}')
    Assert-Check (-not (& $taskModule { param($Root) Test-AssistantManagedAider $Root } $taskAiderStatusRoot)) 'Incomplete Aider installation cannot be mistaken for success'
    # Installation path is mocked before invoking the installer adapter.
    & $taskModule { function script:Get-AssistantInstallStatus { param($ClientId) [pscustomobject]@{ Installed = $true; Description = 'mock-installed' } } }
    Assert-Check ((Install-AssistantClient codex-desktop $taskTestRoot).Description -eq 'mock-installed') 'Already installed client skips all installer actions'
} finally { $taskSecure.Dispose(); Remove-Module $taskModule.Name -Force }

$taskPs = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
foreach ($taskLanguage in @('zh-CN','en-US')) {
    $taskPreview = Join-Path $taskTestRoot ('ui-preview-' + $taskLanguage + '.png')
    & $taskPs -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $taskRoot 'assistant/AgentSetup.ps1') -Language $taskLanguage -SmokeTest -DataRoot $taskTestRoot -PreviewPath $taskPreview
    Assert-Check ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $taskPreview)) ($taskLanguage + ' GUI builds, switches languages and preserves unsaved fields and IDs')
    $taskResultFile = Join-Path $taskTestRoot ('worker-result-' + $taskLanguage + '.json')
    & $taskPs -NoProfile -ExecutionPolicy Bypass -File (Join-Path $taskRoot 'assistant/AgentSetup.ps1') -Language $taskLanguage -Action Backup -ProfileId sample -DataRoot $taskTestRoot -ResultPath $taskResultFile
    $taskWorkerResult = Get-Content -LiteralPath $taskResultFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $taskExpectedPrefix = if ($taskLanguage -eq 'zh-CN') { '已创建备份：' } else { 'Backup created: ' }
    Assert-Check ($LASTEXITCODE -eq 0 -and $taskWorkerResult.Success -and $taskWorkerResult.Message.StartsWith($taskExpectedPrefix)) ($taskLanguage + ' background process reports in the requested language')
}
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $taskTestRoot 'preferences.json'))) 'UI smoke tests do not persist language preferences'
& $taskPs -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-SharingLocal.ps1')
Assert-Check ($LASTEXITCODE -eq 0) 'Sharing and local-model regression suite passes in Windows PowerShell 5.1'
Write-Output ('ALL PASSED: ' + $script:taskPassed)
Write-Output ('Evidence: ' + $taskTestRoot)
Write-Output 'Tests only wrote to the evidence directory. No actual installer, VM, client, or API was started.'
