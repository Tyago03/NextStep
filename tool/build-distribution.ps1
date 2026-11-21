param([string]$AiConfig)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
if (!(Test-Path -LiteralPath (Join-Path $NextStepRoot 'android\key.properties'))) {
    throw 'Run tool/prepare-signing.ps1 first. Release builds never use the debug key.'
}
Push-Location $NextStepRoot
try {
    if (!$AiConfig) {
        $defaultConfig = Join-Path $NextStepRoot 'config\firebase.local.json'
        if (Test-Path -LiteralPath $defaultConfig) { $AiConfig = $defaultConfig }
    }
    $flutterArguments = @('build', 'apk', '--release', '-t', 'lib/main.dart')
    if ($AiConfig) { $flutterArguments += '--dart-define-from-file=' + (Resolve-Path -LiteralPath $AiConfig).Path }
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'Release compilation failed.' }
    $metadata = Get-Content build/app/outputs/apk/release/output-metadata.json -Raw | ConvertFrom-Json
    if ($metadata.applicationId -ne 'dev.tyago.nextstep') { throw 'Unexpected release package.' }
    $apk = Join-Path $NextStepRoot 'build\app\outputs\flutter-apk\app-release.apk'
    $signer = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\apksigner.bat'
    $signature = & $signer verify --verbose --print-certs $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    if ($signature -match 'CN=Android Debug') { throw 'Distribution APK unexpectedly uses a debug certificate.' }
    New-Item -ItemType Directory -Path dist -Force | Out-Null
    $version = $metadata.elements[0].versionName
    $destination = Join-Path $NextStepRoot "dist\NextStep-$version-release.apk"
    Copy-Item -LiteralPath $apk -Destination $destination -Force
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath "$destination.sha256" -Value "$hash  $(Split-Path $destination -Leaf)" -Encoding ascii
    $signature | Set-Content -LiteralPath "$destination.signature.txt" -Encoding utf8
    Get-Item -LiteralPath $destination | Select-Object FullName,Length
    Write-Output "SHA-256: $hash"
    Write-Output 'Signed release APK prepared locally; it has not been published.'
    if (!$AiConfig) { Write-Output 'Live AI remains unavailable; manual planning works offline.' }
} finally {
    Pop-Location
}
