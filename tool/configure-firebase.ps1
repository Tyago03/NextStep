param([Parameter(Mandatory = $true)][string]$GoogleServicesJson)
$ErrorActionPreference = 'Stop'
$nextStepProjectRoot = Split-Path $PSScriptRoot -Parent
$settings = Get-Content -LiteralPath $GoogleServicesJson -Raw | ConvertFrom-Json
$clients = @($settings.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq 'dev.tyago.nextstep'
})
if ($clients.Count -ne 1) {
    throw 'Select google-services.json for the Android app dev.tyago.nextstep.'
}
$client = $clients[0]
$configuration = [ordered]@{
    NEXTSTEP_FIREBASE_API_KEY = $client.api_key[0].current_key
    NEXTSTEP_FIREBASE_APP_ID = $client.client_info.mobilesdk_app_id
    NEXTSTEP_FIREBASE_SENDER_ID = [string]$settings.project_info.project_number
    NEXTSTEP_FIREBASE_PROJECT_ID = $settings.project_info.project_id
}
foreach ($value in $configuration.Values) {
    if ([string]::IsNullOrWhiteSpace($value)) { throw 'Incomplete Firebase Android configuration.' }
}
$outputPath = Join-Path $nextStepProjectRoot 'config\firebase.local.json'
if (Test-Path -LiteralPath $outputPath) {
    throw 'Local configuration already exists. Review it before replacing it.'
}
$configuration | ConvertTo-Json | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output 'Created config/firebase.local.json. No remote settings were changed.'
Write-Output 'Enable Firebase AI Logic (Gemini Developer API) on the Spark plan and register the App Check debug token before live testing.'
