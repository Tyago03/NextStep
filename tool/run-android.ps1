param([string]$Device = 'emulator-5554', [string]$AiConfig)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
Push-Location $NextStepRoot
try {
    if (!(Test-Path -LiteralPath (Join-Path $NextStepTools 'flutter\bin\flutter.bat'))) {
        throw 'Flutter SDK missing. Follow README setup instructions first.'
    }
    if ($Device -eq 'emulator-5554') {
        $connected = & adb devices
        if (!($connected -match '^emulator-5554\s+device')) {
            Start-Process -FilePath (Join-Path $env:ANDROID_HOME 'emulator\emulator.exe') -ArgumentList '-avd','NextStep_API36','-port','5554','-no-snapshot','-no-audio','-gpu','software' -WindowStyle Hidden
        }
        $deadline = (Get-Date).AddMinutes(3)
        do {
            Start-Sleep -Seconds 2
            $booted = & adb -s $Device shell getprop sys.boot_completed 2>$null
        } until ($booted -match '1' -or (Get-Date) -gt $deadline)
        if ($booted -notmatch '1') { throw 'Emulator did not boot within 3 minutes. Run flutter doctor -v.' }
    }
    if (!$AiConfig) {
        $defaultConfig = Join-Path $NextStepRoot 'config\firebase.local.json'
        if (Test-Path -LiteralPath $defaultConfig) { $AiConfig = $defaultConfig }
    }
    $flutterArguments = @('run', '-d', $Device)
    if ($AiConfig) {
        $resolvedConfig = (Resolve-Path -LiteralPath $AiConfig).Path
        $flutterArguments += "--dart-define-from-file=$resolvedConfig"
    }
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'flutter run failed' }
} finally {
    Pop-Location
}
