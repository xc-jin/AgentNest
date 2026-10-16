function Export-AssistantProfile {
    [CmdletBinding()]
    param([string]$Id, [string]$Path, [string]$DataRoot, [switch]$Force)
    $taskProfile = Get-AssistantProfile $Id $DataRoot
    $taskDestination = [IO.Path]::GetFullPath($Path)
    $taskManaged = (Get-AssistantDataRoot $DataRoot).TrimEnd('\') + '\'
    if (-not $taskDestination.EndsWith('.agent-profile.json',[StringComparison]::OrdinalIgnoreCase) -or
        $taskDestination.StartsWith($taskManaged,[StringComparison]::OrdinalIgnoreCase)) { throw (Get-AssistantText '请选择数据目录以外的 .agent-profile.json 文件。') }
    # Explicit field allowlist: never serialize the full profile, generated config or key file.
    $taskShare = [ordered]@{ Format = 'agent-setup-profile'; Version = 1; Id = $taskProfile.Id
        ClientId = $taskProfile.ClientId; ProviderId = $taskProfile.ProviderId
        Model = $taskProfile.Model; BaseUrl = $taskProfile.BaseUrl }
    $taskText = $taskShare | ConvertTo-Json
    if ($Force -and (Test-Path -LiteralPath $taskDestination)) {
        # Overwrite only another recognized sharing file, never unrelated user files.
        $null = Read-AssistantSharedProfile -Path $taskDestination -DataRoot $DataRoot
        Write-AssistantText $taskDestination $taskText
    } else {
        $taskStream = [IO.File]::Open($taskDestination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $taskBytes = [Text.Encoding]::UTF8.GetBytes($taskText); $taskStream.Write($taskBytes,0,$taskBytes.Length) }
        finally { $taskStream.Dispose() }
    }
    $taskDestination
}

function Read-AssistantSharedProfile {
    [CmdletBinding()]
    param([string]$Path, [string]$DataRoot)
    if ((Get-Item -LiteralPath $Path).Length -gt 65536) { throw (Get-AssistantText '分享文件格式无效或包含不支持的字段。') }
    $taskShare = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path) | ConvertFrom-Json
    $taskFields = @('Format','Version','Id','ClientId','ProviderId','Model','BaseUrl')
    if ($taskShare -isnot [pscustomobject] -or @($taskShare.PSObject.Properties).Count -ne $taskFields.Count) { throw (Get-AssistantText '分享文件格式无效或包含不支持的字段。') }
    foreach ($taskName in $taskFields) {
        $taskProperty = $taskShare.PSObject.Properties[$taskName]
        if (-not $taskProperty -or ($taskName -ne 'Version' -and $taskProperty.Value -isnot [string])) { throw (Get-AssistantText '分享文件格式无效或包含不支持的字段。') }
    }
    if ($taskShare.Format -cne 'agent-setup-profile' -or $taskShare.Version -isnot [int] -or $taskShare.Version -ne 1) { throw (Get-AssistantText '分享文件格式无效或包含不支持的字段。') }
    New-AssistantPlan -Id $taskShare.Id -ClientId $taskShare.ClientId -ProviderId $taskShare.ProviderId -Model $taskShare.Model -BaseUrl $taskShare.BaseUrl -DataRoot $DataRoot -MetadataOnly
}

function Get-AssistantLocalModels {
    [CmdletBinding()]
    param([string]$ProviderId, [string]$BaseUrl, [Security.SecureString]$ApiKey)
    if ($ProviderId -notin @('ollama','lmstudio')) { throw (Get-AssistantText '请先选择 Ollama 或 LM Studio。') }
    $taskValidated = New-AssistantPlan -Id local-model-list -ClientId opencode -ProviderId $ProviderId -Model local-model -BaseUrl $BaseUrl -MetadataOnly
    $taskPointer = [IntPtr]::Zero
    $taskHeaders = @{}
    try {
        if ($ApiKey -and $ApiKey.Length) {
            $taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)
            $taskHeaders.Authorization = 'Bearer ' + [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer)
        }
        try { $taskResponse = Invoke-RestMethod -Uri ($taskValidated.BaseUrl + '/models') -Method Get -Headers $taskHeaders -TimeoutSec 5 -MaximumRedirection 0 }
        catch { throw (Get-AssistantText '无法读取本地模型。请启动本地服务，检查端口以及认证设置。') }
        if (-not $taskResponse -or -not $taskResponse.PSObject.Properties['data']) { throw (Get-AssistantText '本地模型列表格式无效。') }
        $taskModels = @($taskResponse.data | Select-Object -First 5000 | ForEach-Object {
            if ($_.PSObject.Properties['id'] -and $_.id -is [string] -and $_.id -match '^[a-zA-Z0-9][a-zA-Z0-9._:/@+\[\]-]{0,199}$') { $_.id }
        } | Sort-Object -Unique)
        if (-not $taskModels.Count) { throw (Get-AssistantText '未找到可用模型，请先在本地服务中下载或加载模型。') }
        $taskModels
    } finally {
        if ($taskPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer) }
        $taskHeaders.Clear()
    }
}
