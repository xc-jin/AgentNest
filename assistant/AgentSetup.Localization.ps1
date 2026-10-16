$script:AssistantLanguage = 'en-US'
$script:AssistantTranslations = @{}
foreach ($taskLocale in @('zh-CN','en-US')) {
    $script:AssistantTranslations[$taskLocale] = Get-Content -LiteralPath (Join-Path $PSScriptRoot ('locales/' + $taskLocale + '.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AssistantLanguage { $script:AssistantLanguage }

function Set-AssistantLanguage {
    param([ValidateSet('','zh-CN','en-US')][string]$Language, [string]$DataRoot)
    if (-not $Language -and $DataRoot) {
        $taskPreferences = Join-Path (Get-AssistantDataRoot $DataRoot) 'preferences.json'
        if (Test-Path -LiteralPath $taskPreferences -PathType Leaf) {
            try {
                $taskPreference = Get-Content -LiteralPath $taskPreferences -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($taskPreference.PSObject.Properties['Language'] -and $taskPreference.Language -in @('zh-CN','en-US')) { $Language = $taskPreference.Language }
            } catch { # Invalid preferences fall back to English.
            }
        }
    }
    if (-not $Language) { $Language = 'en-US' }
    $script:AssistantLanguage = $Language
}

function Save-AssistantLanguagePreference {
    param([ValidateSet('zh-CN','en-US')][string]$Language, [string]$DataRoot)
    $taskPreferencePath = Join-Path (Get-AssistantDataRoot $DataRoot) 'preferences.json'
    $taskPreferences = [pscustomobject]@{}
    if (Test-Path -LiteralPath $taskPreferencePath -PathType Leaf) {
        try {
            $taskParsed = Get-Content -LiteralPath $taskPreferencePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($taskParsed -is [pscustomobject]) { $taskPreferences = $taskParsed }
        } catch { }
    }
    $taskPreferences | Add-Member -NotePropertyName Language -NotePropertyValue $Language -Force
    Write-AssistantText $taskPreferencePath ($taskPreferences | ConvertTo-Json -Depth 8)
}

function Get-AssistantText {
    param([Parameter(Mandatory=$true)][string]$Text)
    $taskTranslation = $script:AssistantTranslations[$script:AssistantLanguage].PSObject.Properties[$Text]
    if (-not $taskTranslation) { throw ('Missing translation: ' + $Text) }
    [string]$taskTranslation.Value
}
