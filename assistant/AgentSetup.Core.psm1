Set-StrictMode -Version 2
$script:AssistantRoot = $PSScriptRoot
. (Join-Path $PSScriptRoot 'AgentSetup.Localization.ps1')
. (Join-Path $PSScriptRoot 'AgentSetup.Clients.ps1')
. (Join-Path $PSScriptRoot 'AgentSetup.SharingLocal.ps1')
$script:ManagedFiles = @('profile.json', 'key.dpapi', 'codex/config.toml', 'codex/models.json', 'claude/settings.json', 'opencode/opencode.json', 'aider/config.yml')

function Get-AssistantCatalog {
    Get-Content -LiteralPath (Join-Path $script:AssistantRoot 'catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AssistantDataRoot {
    param([string]$DataRoot)
    if (-not $DataRoot) { $DataRoot = Join-Path $env:LOCALAPPDATA 'AgentSetupAssistant' }
    if (-not [IO.Path]::IsPathRooted($DataRoot)) { throw (Get-AssistantText '数据目录必须是绝对路径。') }
    [IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
}

function Assert-AssistantId {
    param([string]$Id)
    if ($Id -cnotmatch '^[a-z0-9][a-z0-9-]{0,47}$') { throw (Get-AssistantText '方案名称只能包含小写字母、数字和短横线，最长 48 位。') }
    if ($Id -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])$') { throw (Get-AssistantText '方案名称是 Windows 保留名称。') }
}

function Get-AssistantProfilePath {
    param([string]$Id, [string]$DataRoot)
    Assert-AssistantId $Id
    Join-Path (Join-Path (Get-AssistantDataRoot $DataRoot) 'profiles') $Id
}

function Write-AssistantText {
    param([string]$Path, [string]$Text)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $taskTemp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($taskTemp, $Text, [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($taskTemp, $Path, [System.Management.Automation.Language.NullString]::Value) }
    else { [IO.File]::Move($taskTemp, $Path) }
}

function ConvertTo-AssistantTomlString {
    param([string]$Value)
    '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t') + '"'
}

function New-AssistantPlan {
    [CmdletBinding()]
    param([string]$Id, [string]$ClientId, [string]$ProviderId, [string]$Model,
        [string]$BaseUrl, [string]$DataRoot, [string]$ModelCatalogPath, [switch]$MetadataOnly)
    Assert-AssistantId $Id
    $taskCatalog = Get-AssistantCatalog
    $taskClient = @($taskCatalog.clients | Where-Object id -eq $ClientId)
    $taskProvider = @($taskCatalog.providers | Where-Object id -eq $ProviderId)
    if ($taskClient.Count -ne 1 -or $taskProvider.Count -ne 1) { throw (Get-AssistantText '未知客户端或服务商。') }
    $taskClient = $taskClient[0]; $taskProvider = $taskProvider[0]
    $taskRoute = $taskProvider.routes.PSObject.Properties[$taskClient.protocol]
    if (-not $taskRoute) { throw (Get-AssistantText '该客户端与服务商协议不兼容。') }
    if (-not $BaseUrl) { $BaseUrl = $taskRoute.Value }
    $taskUri = $null
    $taskLocal = $ProviderId -in @('ollama','lmstudio')
    if (-not [uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$taskUri) -or
        $taskUri.Scheme -notin @('http','https') -or $taskUri.UserInfo -or $taskUri.Query -or $taskUri.Fragment) {
        throw (Get-AssistantText '接口地址必须是 HTTPS，且不能包含账户、查询参数或片段。') }
    if ($taskLocal) {
        $taskAddress = $null
        $taskLoopback = $taskUri.Host -in @('localhost','127.0.0.1')
        if ([Net.IPAddress]::TryParse($taskUri.DnsSafeHost,[ref]$taskAddress) -and $taskAddress.Equals([Net.IPAddress]::IPv6Loopback)) { $taskLoopback = $true }
        if (-not $taskLoopback) { throw (Get-AssistantText '本地服务地址只允许 localhost、127.0.0.1 或 ::1。') }
    } elseif ($taskUri.Scheme -ne 'https') { throw (Get-AssistantText '接口地址必须是 HTTPS，且不能包含账户、查询参数或片段。') }
    $BaseUrl = $taskUri.AbsoluteUri.TrimEnd('/')
    if (-not $taskLocal -and -not $ProviderId.StartsWith('custom-') -and $BaseUrl -ne $taskRoute.Value.TrimEnd('/')) {
        throw (Get-AssistantText '官方服务商使用固定地址；自建网关请选自定义服务商。')
    }
    if ([string]::IsNullOrWhiteSpace($Model) -or $Model -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._:/@+\[\]-]{0,199}$') {
        throw (Get-AssistantText '请填写有效的模型 ID，不能包含空格或控制字符。')
    }
    if ($ProviderId -eq 'deepseek' -and $Model -notin $taskProvider.models) { throw (Get-AssistantText '请选择当前支持的 DeepSeek 模型。') }
    $taskRoot = Get-AssistantDataRoot $DataRoot
    $taskProfilePath = Get-AssistantProfilePath $Id $taskRoot
    if ($MetadataOnly) {
        return [pscustomobject]@{ Id=$Id; ClientId=$ClientId; ProviderId=$ProviderId; Model=$Model; BaseUrl=$BaseUrl; Protocol=$taskClient.protocol }
    }
    if (Test-Path -LiteralPath (Join-Path $taskProfilePath 'profile.json')) {
        $taskExisting = Get-Content -LiteralPath (Join-Path $taskProfilePath 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($taskExisting.ClientId -ne $ClientId) { throw (Get-AssistantText '同名方案不能更换客户端，请使用新的方案名称。') }
    }
    $taskFiles = [ordered]@{}
    $taskCatalogRaw = $null
    if ($ClientId -eq 'codex-desktop') {
        if ($ProviderId -eq 'deepseek') { $ModelCatalogPath = Join-Path $script:AssistantRoot 'assets/deepseek-models.json' }
        if ($ModelCatalogPath) {
            $taskCatalogRaw = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ModelCatalogPath).Path)
            $taskParsedCatalog = $taskCatalogRaw | ConvertFrom-Json
            if ($Model -notin @($taskParsedCatalog.models | ForEach-Object slug)) { throw (Get-AssistantText '模型目录中没有所选模型的 slug。') }
            $taskFiles['codex/models.json'] = $taskCatalogRaw
        } elseif ($ProviderId -eq 'custom-responses') { throw (Get-AssistantText '自定义 Codex 模型需要选择配套的 Codex models.json 文件。') }
        $taskLines = @(('model = ' + (ConvertTo-AssistantTomlString $Model)),
            'model_provider = "assistant-provider"', 'preferred_auth_method = "apikey"', 'forced_login_method = "api"',
            'web_search = "disabled"')
        if ($taskCatalogRaw) { $taskLines += 'model_catalog_json = ' + (ConvertTo-AssistantTomlString (Join-Path $taskProfilePath 'codex/models.json')) }
        if ($ProviderId -eq 'deepseek') { $taskLines += 'model_reasoning_effort = "high"' }
        $taskLines += @('', '[model_providers.assistant-provider]', ('name = ' + (ConvertTo-AssistantTomlString $taskProvider.name)),
            ('base_url = ' + (ConvertTo-AssistantTomlString $BaseUrl)), 'wire_api = "responses"',
            'env_key = "AGENT_ASSISTANT_API_KEY"', '', '[windows]', 'sandbox = "unelevated"')
        if ($ProviderId -eq 'deepseek') { $taskLines += @('', '[desktop]', 'enabled-reasoning-efforts = ["low", "medium", "high", "xhigh", "ultra", "max"]') }
        $taskFiles['codex/config.toml'] = ($taskLines -join "`r`n") + "`r`n"
    } elseif ($ClientId -eq 'claude-code') {
        $taskFiles['claude/settings.json'] = (@{ model = $Model } | ConvertTo-Json)
    } elseif ($ClientId -eq 'opencode') {
        $taskModels = @{}; $taskModels[$Model] = @{ name = $Model }
        $taskFiles['opencode/opencode.json'] = (@{
            '$schema' = 'https://opencode.ai/config.json'
            model = 'assistant/' + $Model; enabled_providers = @('assistant'); permission = 'ask'
            provider = @{ assistant = @{ npm = '@ai-sdk/openai-compatible'; name = $taskProvider.name
                options = @{ baseURL = $BaseUrl; apiKey = '{env:AGENT_ASSISTANT_API_KEY}' }; models = $taskModels } }
        } | ConvertTo-Json -Depth 12)
    } elseif ($ClientId -eq 'aider') {
        # JSON is a YAML subset. The key is supplied only through the child environment.
        $taskFiles['aider/config.yml'] = (@{ model = 'openai/' + $Model; 'openai-api-base' = $BaseUrl
            'input-history-file' = Join-Path $taskProfilePath 'aider/input.history'
            'chat-history-file' = Join-Path $taskProfilePath 'aider/chat.history.md'
        } | ConvertTo-Json)
    } else { throw (Get-AssistantText '未知客户端。') }
    [pscustomobject]@{ Id = $Id; ClientId = $ClientId; ProviderId = $ProviderId; Model = $Model; BaseUrl = $BaseUrl
        Protocol = $taskClient.protocol; DataRoot = $taskRoot; ProfilePath = $taskProfilePath; Files = $taskFiles }
}

function Backup-AssistantProfile {
    param([string]$Id, [string]$DataRoot)
    $taskRoot = Get-AssistantDataRoot $DataRoot
    $taskProfilePath = Get-AssistantProfilePath $Id $taskRoot
    if (-not (Test-Path -LiteralPath (Join-Path $taskProfilePath 'profile.json'))) { throw (Get-AssistantText '方案不存在。') }
    $taskBackupId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $taskDestination = Join-Path (Join-Path (Join-Path $taskRoot 'backups') $Id) $taskBackupId
    New-Item -ItemType Directory -Path $taskDestination -Force | Out-Null
    $taskHashes = [ordered]@{}
    foreach ($taskRelative in $script:ManagedFiles) {
        $taskPath = Join-Path $taskProfilePath $taskRelative
        if (Test-Path -LiteralPath $taskPath -PathType Leaf) {
            $taskTarget = Join-Path $taskDestination $taskRelative
            New-Item -ItemType Directory -Path (Split-Path -Parent $taskTarget) -Force | Out-Null
            Copy-Item -LiteralPath $taskPath -Destination $taskTarget
            $taskHashes[$taskRelative] = (Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash
        }
    }
    Write-AssistantText (Join-Path $taskDestination 'backup.json') (@{ Id = $Id; Files = $taskHashes; CreatedUtc = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json -Depth 8)
    $taskBackupId
}

function Get-AssistantBackups {
    param([string]$Id, [string]$DataRoot)
    Assert-AssistantId $Id
    $taskParent = Join-Path (Join-Path (Get-AssistantDataRoot $DataRoot) 'backups') $Id
    if (Test-Path -LiteralPath $taskParent) {
        Get-ChildItem -LiteralPath $taskParent -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'backup.json') } | Sort-Object Name -Descending | Select-Object -ExpandProperty Name
    }
}

function Restore-AssistantProfile {
    param([string]$Id, [string]$BackupId, [string]$DataRoot, [switch]$SkipSafetyBackup)
    Assert-AssistantId $Id
    if ($BackupId -notmatch '^\d{8}T\d{9}-[a-f0-9]{8}$') { throw (Get-AssistantText '无效的备份标识。') }
    $taskRoot = Get-AssistantDataRoot $DataRoot
    $taskSource = Join-Path (Join-Path (Join-Path $taskRoot 'backups') $Id) $BackupId
    $taskMeta = Get-Content -LiteralPath (Join-Path $taskSource 'backup.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($taskMeta.Id -ne $Id) { throw (Get-AssistantText '备份与方案不匹配。') }
    foreach ($taskProperty in $taskMeta.Files.PSObject.Properties) {
        if ($taskProperty.Name -notin $script:ManagedFiles) { throw (Get-AssistantText '备份包含不支持的文件。') }
        if ((Get-FileHash -LiteralPath (Join-Path $taskSource $taskProperty.Name) -Algorithm SHA256).Hash -ne $taskProperty.Value) { throw (Get-AssistantText '备份校验失败，未恢复。') }
    }
    if (-not $taskMeta.Files.PSObject.Properties['profile.json']) { throw (Get-AssistantText '备份缺少必要文件。') }
    $taskSaved = Get-Content -LiteralPath (Join-Path $taskSource 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $null = New-AssistantPlan -Id $taskSaved.Id -ClientId $taskSaved.ClientId -ProviderId $taskSaved.ProviderId -Model $taskSaved.Model -BaseUrl $taskSaved.BaseUrl -DataRoot $taskRoot -MetadataOnly
    if ($taskSaved.Id -cne $Id -or ($taskSaved.ProviderId -notin @('ollama','lmstudio') -and -not $taskMeta.Files.PSObject.Properties['key.dpapi'])) { throw (Get-AssistantText '备份缺少必要文件。') }
    if (-not $SkipSafetyBackup) { $null = Backup-AssistantProfile $Id $taskRoot }
    $taskTarget = Get-AssistantProfilePath $Id $taskRoot
    foreach ($taskRelative in $script:ManagedFiles) {
        $taskPath = Join-Path $taskTarget $taskRelative
        if ($taskMeta.Files.PSObject.Properties[$taskRelative]) {
            Write-AssistantText $taskPath ([IO.File]::ReadAllText((Join-Path $taskSource $taskRelative)))
        } elseif (Test-Path -LiteralPath $taskPath -PathType Leaf) { Remove-Item -LiteralPath $taskPath -Force }
    }
}

function Save-AssistantProfile {
    param($Plan, [Security.SecureString]$ApiKey)
    $taskLocal = $Plan.ProviderId -in @('ollama','lmstudio')
    $null = New-AssistantPlan -Id $Plan.Id -ClientId $Plan.ClientId -ProviderId $Plan.ProviderId -Model $Plan.Model -BaseUrl $Plan.BaseUrl -DataRoot $Plan.DataRoot -MetadataOnly
    if ((-not $ApiKey -or $ApiKey.Length -eq 0) -and -not $taskLocal) { throw (Get-AssistantText '请输入 API Key。') }
    # Revalidate the plan before any write, including plans supplied by command-line callers.
    Assert-AssistantId $Plan.Id
    $taskExpected = Get-AssistantProfilePath $Plan.Id $Plan.DataRoot
    if ($taskExpected -ne $Plan.ProfilePath) { throw (Get-AssistantText '方案路径不匹配。') }
    foreach ($taskRelative in $Plan.Files.Keys) { if ($taskRelative -notin $script:ManagedFiles) { throw (Get-AssistantText '不支持的配置目标。') } }
    if (-not $Plan.Files.Count) { throw (Get-AssistantText '不支持的配置目标。') }
    $taskCiphertext = if ($ApiKey -and $ApiKey.Length) { ConvertFrom-SecureString $ApiKey } else { $null }
    $taskExisting = Test-Path -LiteralPath (Join-Path $Plan.ProfilePath 'profile.json')
    $taskBackup = $null
    if ($taskExisting) { $taskBackup = Backup-AssistantProfile $Plan.Id $Plan.DataRoot }
    try {
        foreach ($taskRelative in $Plan.Files.Keys) { Write-AssistantText (Join-Path $Plan.ProfilePath $taskRelative) $Plan.Files[$taskRelative] }
        $taskKeyPath = Join-Path $Plan.ProfilePath 'key.dpapi'
        if ($taskCiphertext) { Write-AssistantText $taskKeyPath $taskCiphertext }
        elseif (Test-Path -LiteralPath $taskKeyPath) { Remove-Item -LiteralPath $taskKeyPath -Force }
        $taskMetadata = [ordered]@{ Id = $Plan.Id; ClientId = $Plan.ClientId; ProviderId = $Plan.ProviderId
            Model = $Plan.Model; BaseUrl = $Plan.BaseUrl; Protocol = $Plan.Protocol; Version = 1
            UpdatedUtc = (Get-Date).ToUniversalTime().ToString('o') }
        Write-AssistantText (Join-Path $Plan.ProfilePath 'profile.json') ($taskMetadata | ConvertTo-Json)
    } catch {
        if ($taskBackup) { Restore-AssistantProfile $Plan.Id $taskBackup $Plan.DataRoot -SkipSafetyBackup }
        else {
            foreach ($taskRelative in $script:ManagedFiles) {
                $taskFailedPath = Join-Path $Plan.ProfilePath $taskRelative
                if (Test-Path -LiteralPath $taskFailedPath -PathType Leaf) { Remove-Item -LiteralPath $taskFailedPath -Force }
            }
        }
        throw
    }
    [pscustomobject]@{ Id = $Plan.Id; ProfilePath = $Plan.ProfilePath; BackupId = $taskBackup }
}

function Get-AssistantProfiles {
    param([string]$DataRoot)
    $taskParent = Join-Path (Get-AssistantDataRoot $DataRoot) 'profiles'
    if (Test-Path -LiteralPath $taskParent) {
        foreach ($taskDirectory in Get-ChildItem -LiteralPath $taskParent -Directory) {
            $taskPath = Join-Path $taskDirectory.FullName 'profile.json'
            if (Test-Path -LiteralPath $taskPath) { Get-Content -LiteralPath $taskPath -Raw -Encoding UTF8 | ConvertFrom-Json }
        }
    }
}

function Get-AssistantProfile {
    param([string]$Id, [string]$DataRoot)
    $taskPath = Get-AssistantProfilePath $Id $DataRoot
    $taskProfile = Get-Content -LiteralPath (Join-Path $taskPath 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($taskProfile.Id -cne $Id) { throw (Get-AssistantText '方案文件与目录标识不一致。') }
    $taskPlanArguments = @{ Id = $Id; ClientId = $taskProfile.ClientId; ProviderId = $taskProfile.ProviderId
        Model = $taskProfile.Model; BaseUrl = $taskProfile.BaseUrl; DataRoot = $DataRoot }
    if ($taskProfile.ProviderId -eq 'custom-responses') { $taskPlanArguments.ModelCatalogPath = Join-Path $taskPath 'codex/models.json' }
    $taskPlan = New-AssistantPlan @taskPlanArguments
    if ($taskProfile.Protocol -ne $taskPlan.Protocol) { throw (Get-AssistantText '方案协议与客户端不匹配。') }
    $taskProfile
}

function Get-AssistantSecret {
    param([string]$Id, [string]$DataRoot)
    $taskPath = Join-Path (Get-AssistantProfilePath $Id $DataRoot) 'key.dpapi'
    if (-not (Test-Path -LiteralPath $taskPath) -and (Get-AssistantProfile $Id $DataRoot).ProviderId -in @('ollama','lmstudio')) { return $null }
    ConvertTo-SecureString ([IO.File]::ReadAllText($taskPath))
}

function Find-AssistantClaude {
    foreach ($taskCandidate in @((Join-Path $env:USERPROFILE '.local/bin/claude.exe'), (Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Links/claude.exe'))) {
        if (Test-Path -LiteralPath $taskCandidate -PathType Leaf) { return $taskCandidate }
    }
    $taskCommand = Get-Command 'claude.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($taskCommand) { return $taskCommand.Source }
}

function Get-AssistantInstallStatus {
    param([string]$ClientId, [string]$DataRoot)
    if ($ClientId -eq 'codex-desktop') {
        $taskPackage = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue
        [pscustomobject]@{ Installed = [bool]$taskPackage; Description = if ($taskPackage) { [string]$taskPackage.Version } else { (Get-AssistantText '未安装') } }
    } elseif ($ClientId -eq 'claude-code') {
        $taskPath = Find-AssistantClaude
        [pscustomobject]@{ Installed = [bool]$taskPath; Description = if ($taskPath) { $taskPath } else { (Get-AssistantText '未安装') } }
    } elseif ($ClientId -eq 'opencode') {
        $taskPath = Find-AssistantTool -Name opencode.exe -PackagePrefix SST.opencode
        [pscustomobject]@{ Installed = [bool]$taskPath; Description = if ($taskPath) { $taskPath } else { (Get-AssistantText '未安装') } }
    } elseif ($ClientId -eq 'aider') {
        $taskPath = Get-AssistantManagedAider $DataRoot
        $taskInstalled = Test-AssistantManagedAider $DataRoot
        [pscustomobject]@{ Installed = $taskInstalled; Description = if ($taskInstalled) { $taskPath } else { (Get-AssistantText '未安装') } }
    } else { throw (Get-AssistantText '未知客户端。') }
}

function Install-AssistantClient {
    param([string]$ClientId, [string]$DataRoot)
    $taskStatus = Get-AssistantInstallStatus $ClientId $DataRoot
    if ($taskStatus.Installed) { return $taskStatus }
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw (Get-AssistantText '第一版安装功能只支持 Windows x64。') }
    if ($ClientId -eq 'opencode') {
        Invoke-AssistantWinget SST.opencode
    } elseif ($ClientId -eq 'aider') {
        Install-AssistantAider $DataRoot
    } elseif ($ClientId -eq 'claude-code') {
        $taskWinget = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
        if (-not $taskWinget) { throw (Get-AssistantText '请先从 Microsoft Store 安装或更新“应用安装程序”，以提供 winget。') }
        & $taskWinget.Source install --id Anthropic.ClaudeCode --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw (Get-AssistantText 'Claude Code 安装失败，请查看安装器输出。') }
    } elseif ($ClientId -eq 'codex-desktop') {
        $taskCache = Join-Path (Get-AssistantDataRoot $DataRoot) 'downloads'
        New-Item -ItemType Directory -Path $taskCache -Force | Out-Null
        $taskBundled = Join-Path $script:AssistantRoot 'assets/Codex-x64.msix'
        if (Test-Path -LiteralPath $taskBundled) { $taskMsix = $taskBundled }
        else {
            $taskMsix = Join-Path $taskCache 'Codex-x64.msix'
            $taskPartial = Join-Path $taskCache 'Codex.download.msix'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri 'https://persistent.oaistatic.com/codex-app-prod/ChatGPT-x64.msix' -OutFile $taskPartial -UseBasicParsing -TimeoutSec 900
            if ((Get-AuthenticodeSignature -LiteralPath $taskPartial).Status -ne 'Valid') { throw (Get-AssistantText '下载的 OpenAI 安装包签名无效。') }
            Move-Item -LiteralPath $taskPartial -Destination $taskMsix -Force
        }
        if ((Get-AuthenticodeSignature -LiteralPath $taskMsix).Status -ne 'Valid') { throw (Get-AssistantText 'OpenAI 安装包签名无效。') }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $taskZip = [IO.Compression.ZipFile]::OpenRead($taskMsix)
        try {
            $taskReader = [IO.StreamReader]::new($taskZip.GetEntry('AppxManifest.xml').Open())
            try { [xml]$taskManifest = $taskReader.ReadToEnd() } finally { $taskReader.Dispose() }
            if ($taskManifest.Package.Identity.Name -ne 'OpenAI.Codex' -or
                $taskManifest.Package.Identity.Publisher -ne 'CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B' -or
                $taskManifest.Package.Identity.ProcessorArchitecture -ne 'x64') { throw (Get-AssistantText '安装包身份不匹配。') }
        } finally { $taskZip.Dispose() }
        Add-AppxPackage -Path $taskMsix
    } else { throw (Get-AssistantText '未知客户端。') }
    $taskStatus = Get-AssistantInstallStatus $ClientId $DataRoot
    if (-not $taskStatus.Installed) { throw (Get-AssistantText '安装器结束，但尚未检测到客户端。重新打开助手后再检测。') }
    $taskStatus
}

function Get-AssistantLaunchEnvironment {
    param($Profile, [string]$ProfilePath, [string]$Key)
    $taskEnvironment = @{}
    # Remove conflicting inherited routing settings in the child process only.
    foreach ($taskName in @('OPENAI_API_KEY', 'OPENAI_BASE_URL', 'OPENAI_API_BASE', 'OPENAI_API_TYPE', 'OPENAI_API_VERSION', 'OPENAI_ORGANIZATION', 'CODEX_API_KEY', 'CODEX_ACCESS_TOKEN',
        'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'ANTHROPIC_MODEL',
        'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
        'CLAUDE_CODE_SUBAGENT_MODEL', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY',
        'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_EFFORT_LEVEL', 'CLAUDE_CODE_AUTO_COMPACT_WINDOW', 'AGENT_ASSISTANT_API_KEY')) { $taskEnvironment[$taskName] = $null }
    foreach ($taskName in [Environment]::GetEnvironmentVariables().Keys) {
        if ($taskName -like 'AIDER_*' -or $taskName -like 'OPENCODE_*') { $taskEnvironment[$taskName] = $null }
    }
    if ($Profile.ClientId -eq 'codex-desktop') {
        $taskEnvironment['CODEX_HOME'] = Join-Path $ProfilePath 'codex'
        $taskEnvironment['AGENT_ASSISTANT_API_KEY'] = $Key
    } elseif ($Profile.ClientId -eq 'claude-code') {
        $taskEnvironment['CLAUDE_CONFIG_DIR'] = Join-Path $ProfilePath 'claude'
        $taskEnvironment['ANTHROPIC_BASE_URL'] = $Profile.BaseUrl
        if ($Profile.ProviderId -eq 'anthropic') { $taskEnvironment['ANTHROPIC_API_KEY'] = $Key }
        else { $taskEnvironment['ANTHROPIC_AUTH_TOKEN'] = $Key }
        $taskEnvironment['ANTHROPIC_MODEL'] = $Profile.Model
        $taskEnvironment['ANTHROPIC_DEFAULT_OPUS_MODEL'] = $Profile.Model
        $taskEnvironment['ANTHROPIC_DEFAULT_SONNET_MODEL'] = $Profile.Model
        $taskEnvironment['ANTHROPIC_DEFAULT_HAIKU_MODEL'] = $Profile.Model
        $taskEnvironment['CLAUDE_CODE_SUBAGENT_MODEL'] = $Profile.Model
    } elseif ($Profile.ClientId -eq 'opencode') {
        $taskEnvironment['AGENT_ASSISTANT_API_KEY'] = $Key
        $taskEnvironment['OPENCODE_CONFIG'] = Join-Path $ProfilePath 'opencode/opencode.json'
        $taskEnvironment['OPENCODE_CONFIG_DIR'] = Join-Path $ProfilePath 'opencode/config'
        $taskEnvironment['XDG_CONFIG_HOME'] = Join-Path $ProfilePath 'opencode/xdg/config'
        $taskEnvironment['XDG_DATA_HOME'] = Join-Path $ProfilePath 'opencode/xdg/data'
        $taskEnvironment['XDG_STATE_HOME'] = Join-Path $ProfilePath 'opencode/xdg/state'
        $taskEnvironment['XDG_CACHE_HOME'] = Join-Path $ProfilePath 'opencode/xdg/cache'
        # Inline runtime settings override conflicting project routing without a plaintext key.
        $taskEnvironment['OPENCODE_CONFIG_CONTENT'] = [IO.File]::ReadAllText($taskEnvironment['OPENCODE_CONFIG'])
    } elseif ($Profile.ClientId -eq 'aider') {
        $taskEnvironment['OPENAI_API_KEY'] = $Key
        $taskEnvironment['AIDER_OPENAI_API_KEY'] = $Key
        $taskEnvironment['OPENAI_API_BASE'] = $Profile.BaseUrl
        $taskEnvironment['PYTHON_DOTENV_DISABLED'] = '1'
    } else { throw (Get-AssistantText '未知客户端。') }
    $taskEnvironment
}

function Start-AssistantProfile {
    param([string]$Id, [string]$DataRoot, [string]$WorkingDirectory)
    $taskProfile = Get-AssistantProfile $Id $DataRoot
    $taskProfilePath = Get-AssistantProfilePath $Id $DataRoot
    if (-not $WorkingDirectory) { $WorkingDirectory = $env:USERPROFILE }
    $WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
    if ($taskProfile.ClientId -eq 'codex-desktop') {
        $taskRunning = @(Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue)
        if ($taskRunning.Count) { throw (Get-AssistantText '请先完全退出已运行的 ChatGPT / Codex（含托盘），再从助手启动方案，避免沿用旧进程的配置。') }
        $taskPackage = Get-AppxPackage -Name 'OpenAI.Codex'
        if (-not $taskPackage) { throw (Get-AssistantText '请先安装 Codex 桌面版。') }
        $taskExecutable = Join-Path $taskPackage.InstallLocation 'app/ChatGPT.exe'
    } elseif ($taskProfile.ClientId -eq 'claude-code') {
        $taskExecutable = Find-AssistantClaude
        if (-not $taskExecutable) { throw (Get-AssistantText '请先安装 Claude Code。') }
    } else {
        $taskStatus = Get-AssistantInstallStatus $taskProfile.ClientId $DataRoot
        if (-not $taskStatus.Installed) { throw (Get-AssistantText '请先检测并安装所选客户端。') }
        $taskExecutable = $taskStatus.Description
    }
    $taskSecret = Get-AssistantSecret $Id $DataRoot
    $taskPointer = [IntPtr]::Zero
    try {
        $taskKey = 'local-no-key'
        if ($taskSecret) {
            $taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret)
            $taskKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer)
        }
        $taskEnvironment = Get-AssistantLaunchEnvironment $taskProfile $taskProfilePath $taskKey
        $taskArguments = @(Get-AssistantTerminalArguments $taskProfile $taskProfilePath)
        $taskStartInfo = New-AssistantProcessInfo -Executable $taskExecutable -Arguments $taskArguments -WorkingDirectory $WorkingDirectory -Environment $taskEnvironment
        $taskProcess = [Diagnostics.Process]::Start($taskStartInfo)
        foreach ($taskName in $taskEnvironment.Keys) { $taskStartInfo.EnvironmentVariables.Remove($taskName) }
        if ($taskProfile.ClientId -ne 'codex-desktop') {
            try {
                $taskProcess.WaitForExit()
                if ($taskProcess.ExitCode -ne 0) { throw (Get-AssistantText '客户端异常退出，请查看启动窗口输出。') }
            } finally { $taskProcess.Dispose() }
        }
    } finally {
        if ($taskPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer) }
        if ($taskSecret) { $taskSecret.Dispose() }; $taskKey = $null; $taskEnvironment = $null
    }
}

function Test-AssistantConnection {
    [CmdletBinding()]
    param([string]$Id, [string]$DataRoot)
    $taskProfile = Get-AssistantProfile $Id $DataRoot
    # Revalidate destination before decrypting or sending a credential.
    $null = New-AssistantPlan -Id $Id -ClientId $taskProfile.ClientId -ProviderId $taskProfile.ProviderId -Model $taskProfile.Model -BaseUrl $taskProfile.BaseUrl -DataRoot $DataRoot -ModelCatalogPath $(if ($taskProfile.ProviderId -eq 'custom-responses') { Join-Path (Get-AssistantProfilePath $Id $DataRoot) 'codex/models.json' })
    $taskSecret = Get-AssistantSecret $Id $DataRoot
    $taskPointer = [IntPtr]::Zero
    try {
        $taskKey = $null
        if ($taskSecret) {
            $taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret)
            $taskKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer)
        }
        $taskHeaders = @{}
        if ($taskProfile.Protocol -eq 'responses') {
            $taskUrl = $taskProfile.BaseUrl.TrimEnd('/') + '/responses'
            if ($taskKey) { $taskHeaders['Authorization'] = 'Bearer ' + $taskKey }
            $taskBody = @{ model = $taskProfile.Model; input = 'Reply with OK.'; max_output_tokens = 512; stream = $false }
        } elseif ($taskProfile.Protocol -eq 'chat') {
            $taskUrl = $taskProfile.BaseUrl.TrimEnd('/') + '/chat/completions'
            if ($taskKey) { $taskHeaders['Authorization'] = 'Bearer ' + $taskKey }
            $taskBody = @{ model = $taskProfile.Model; messages = @(@{ role = 'user'; content = 'Reply with OK.' }); max_tokens = 512; stream = $false }
            if ($taskProfile.ProviderId -eq 'openai') {
                $taskBody.Remove('max_tokens'); $taskBody['max_completion_tokens'] = 512
            }
        } else {
            $taskBase = $taskProfile.BaseUrl.TrimEnd('/')
            $taskUrl = $taskBase + $(if ($taskBase -match '/v1$') { '/messages' } else { '/v1/messages' })
            if ($taskProfile.ProviderId -eq 'anthropic') { $taskHeaders['x-api-key'] = $taskKey }
            else { $taskHeaders['Authorization'] = 'Bearer ' + $taskKey }
            $taskHeaders['anthropic-version'] = '2023-06-01'
            $taskBody = @{ model = $taskProfile.Model; messages = @(@{ role = 'user'; content = 'Reply with OK.' }); max_tokens = 512 }
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try {
            # Refuse redirects so credentials cannot be forwarded to another endpoint.
            $taskResponse = Invoke-RestMethod -Uri $taskUrl -Method Post -Headers $taskHeaders -Body ($taskBody | ConvertTo-Json -Depth 8) -ContentType 'application/json; charset=utf-8' -TimeoutSec 45 -MaximumRedirection 0
        } catch {
            $taskCode = (Get-AssistantText '网络错误')
            if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) {
                if ($_.Exception.Response.PSObject.Properties['StatusCode']) { $taskCode = 'HTTP ' + [int]$_.Exception.Response.StatusCode }
            }
            # Do not echo untrusted response bodies, request headers, or exception text.
            throw ((Get-AssistantText '接口检查失败：') + $taskCode + (Get-AssistantText '。请检查 Key、模型、余额、接口地址和网络。'))
        }
        if ($taskProfile.Protocol -eq 'responses') {
            if (-not $taskResponse.PSObject.Properties['object'] -or $taskResponse.object -ne 'response' -or
                -not $taskResponse.PSObject.Properties['status'] -or $taskResponse.status -ne 'completed' -or
                -not $taskResponse.PSObject.Properties['output'] -or @($taskResponse.output).Count -eq 0) {
                throw (Get-AssistantText '接口返回不完整或格式不符；尚未通过基础对话检查。')
            }
        } elseif ($taskProfile.Protocol -eq 'chat') {
            if (-not $taskResponse.PSObject.Properties['choices'] -or @($taskResponse.choices).Count -eq 0 -or
                -not $taskResponse.choices[0] -or -not $taskResponse.choices[0].PSObject.Properties['message'] -or
                -not $taskResponse.choices[0].message -or -not $taskResponse.choices[0].message.PSObject.Properties['content'] -or
                [string]::IsNullOrWhiteSpace([string]$taskResponse.choices[0].message.content) -or
                -not $taskResponse.choices[0].PSObject.Properties['finish_reason'] -or $taskResponse.choices[0].finish_reason -ne 'stop') {
                throw (Get-AssistantText 'Chat Completions 响应不完整或格式不符。')
            }
        } elseif (-not $taskResponse.PSObject.Properties['type'] -or $taskResponse.type -ne 'message' -or
            -not $taskResponse.PSObject.Properties['content'] -or @($taskResponse.content).Count -eq 0) { throw (Get-AssistantText 'Messages 响应格式不符。') }
        (Get-AssistantText '基础对话检查通过。工具调用、流式输出和多轮对话仍需在客户端中验证。')
    } finally {
        if ($taskPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer) }
        if ($taskSecret) { $taskSecret.Dispose() }; $taskKey = $null; $taskHeaders = $null
    }
}

Export-ModuleMember -Function Get-AssistantText,Get-AssistantLanguage,Set-AssistantLanguage,Save-AssistantLanguagePreference,Get-AssistantCatalog,Get-AssistantDataRoot,New-AssistantPlan,Save-AssistantProfile,Get-AssistantProfiles,Get-AssistantProfile,Get-AssistantProfilePath,Backup-AssistantProfile,Get-AssistantBackups,Restore-AssistantProfile,Get-AssistantInstallStatus,Install-AssistantClient,Start-AssistantProfile,Test-AssistantConnection,Export-AssistantProfile,Read-AssistantSharedProfile,Get-AssistantLocalModels
