param([string]$AiConfig)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
Push-Location $NextStepRoot
try {
    if (!$AiConfig) {
        $defaultConfig = Join-Path $NextStepRoot 'config\firebase.local.json'
        if (Test-Path -LiteralPath $defaultConfig) { $AiConfig = $defaultConfig }
    }
    $flutterArguments = @('build', 'apk', '--debug', '-t', 'lib/main.dart')
    if ($AiConfig) {
        $resolvedConfig = (Resolve-Path -LiteralPath $AiConfig).Path
        $flutterArguments += "--dart-define-from-file=$resolvedConfig"
    }
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'Android debug build failed.' }
    $metadata = Get-Content build/app/outputs/apk/debug/output-metadata.json -Raw | ConvertFrom-Json
    if ($metadata.applicationId -ne 'dev.tyago.nextstep') { throw 'Unexpected APK package.' }
    New-Item -ItemType Directory -Path dist -Force | Out-Null
    Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-debug.apk -Destination dist/NextStep-debug.apk -Force
    $apkHash = (Get-FileHash -LiteralPath dist/NextStep-debug.apk -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath dist/NextStep-debug.apk.sha256 -Value "$apkHash  NextStep-debug.apk" -Encoding ascii
    Write-Output 'Normal APK preserved at dist/NextStep-debug.apk.'
    if (!$AiConfig) { Write-Output 'Firebase is not configured. Manual planning works; live AI generation remains unavailable.' }
} finally {
    Pop-Location
}
