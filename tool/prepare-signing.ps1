$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$nextStepSigningDirectory = Join-Path $NextStepTools 'signing'
$nextStepKeyStore = Join-Path $nextStepSigningDirectory 'nextstep-release.jks'
$nextStepKeyProperties = Join-Path $NextStepRoot 'android\key.properties'
if ((Test-Path -LiteralPath $nextStepKeyStore) -or (Test-Path -LiteralPath $nextStepKeyProperties)) {
    if ((Test-Path -LiteralPath $nextStepKeyStore) -and (Test-Path -LiteralPath $nextStepKeyProperties)) {
        Write-Output 'Existing NextStep signing files preserved. Build verifies the resulting APK.'
        return
    }
    throw 'Incomplete existing signing setup. Restore the matching files; this script never replaces an existing key.'
}
New-Item -ItemType Directory -Path $nextStepSigningDirectory -Force | Out-Null
$passwordBytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($passwordBytes)
$env:NEXTSTEP_SIGNING_PASSWORD = [Convert]::ToBase64String($passwordBytes)
try {
    & (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -genkeypair -keystore $nextStepKeyStore -storetype JKS -keyalg RSA -keysize 3072 -validity 10000 -alias nextstep -dname 'CN=NextStep, OU=Mobile, O=NextStep, C=BR' -storepass:env NEXTSTEP_SIGNING_PASSWORD -keypass:env NEXTSTEP_SIGNING_PASSWORD -noprompt
    if ($LASTEXITCODE -ne 0) { throw 'NextStep signing key generation failed.' }
    $properties = @(
        'storeFile=' + $nextStepKeyStore.Replace('\', '/')
        'storePassword=' + $env:NEXTSTEP_SIGNING_PASSWORD
        'keyAlias=nextstep'
        'keyPassword=' + $env:NEXTSTEP_SIGNING_PASSWORD
    )
    Set-Content -LiteralPath $nextStepKeyProperties -Value $properties -Encoding ascii
    Write-Output 'Created a dedicated local NextStep release key and ignored android/key.properties.'
    Write-Output 'Keep both files private and back them up together before distributing updates.'
} finally {
    Remove-Item Env:NEXTSTEP_SIGNING_PASSWORD -ErrorAction SilentlyContinue
    [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
}
