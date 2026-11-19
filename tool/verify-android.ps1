param([string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
Push-Location $NextStepRoot
try {
    New-Item -ItemType Directory -Path local-validation -Force | Out-Null
    & flutter test integration_test/session_flow_test.dart -d $Device --no-uninstall --reporter expanded 2>&1 | Tee-Object -FilePath local-validation/android-flow.log
    if ($LASTEXITCODE -ne 0) { throw 'Android UI integration failed' }
    & flutter test integration_test/process_restart_test.dart -d $Device --no-uninstall --dart-define=NEXTSTEP_RESTART_PHASE=seed --reporter expanded 2>&1 | Tee-Object -FilePath local-validation/android-restart-seed.log
    if ($LASTEXITCODE -ne 0) { throw 'Restart seed failed' }
    $installedTestPackage = & adb -s $Device shell pm path dev.tyago.nextstep.integration
    if (!($installedTestPackage -match '^package:')) { throw 'Expected isolated test package is not installed' }
    & adb -s $Device shell am force-stop dev.tyago.nextstep.integration
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop the NextStep test process' }
    & flutter test integration_test/process_restart_test.dart -d $Device --no-uninstall --dart-define=NEXTSTEP_RESTART_PHASE=verify --reporter expanded 2>&1 | Tee-Object -FilePath local-validation/android-restart-verify.log
    if ($LASTEXITCODE -ne 0) { throw 'Restart verification failed' }
} finally {
    Pop-Location
}
