# Portable prerequisites only. Android license acceptance is a separate step.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$toolsPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '.nextstep-tools'
$downloads = Join-Path $toolsPath 'downloads'
New-Item -ItemType Directory -Path $downloads -Force | Out-Null
function Download-Checked($url, $destination, $expected) {
    if (!(Test-Path -LiteralPath $destination)) {
        Invoke-WebRequest -Uri $url -OutFile $destination -TimeoutSec 600
    }
    $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw "Checksum mismatch: $destination" }
    Write-Output "SHA256 verified: $(Split-Path $destination -Leaf)"
}
$jdkUrl = 'https://aka.ms/download-jdk/microsoft-jdk-21.0.13.1-windows-x64.zip'
$jdkHash = (Invoke-RestMethod -Uri ($jdkUrl + '.sha256sum.txt') -TimeoutSec 60).Trim().Split(' ')[0]
$jdkZip = Join-Path $downloads 'microsoft-jdk-21.zip'
Download-Checked $jdkUrl $jdkZip $jdkHash
if (!(Test-Path -LiteralPath (Join-Path $toolsPath 'jdk'))) {
    Expand-Archive -LiteralPath $jdkZip -DestinationPath (Join-Path $toolsPath 'jdk')
}
$androidZip = Join-Path $downloads 'android-commandline-tools.zip'
Download-Checked 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' $androidZip '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
$sdk = Join-Path $toolsPath 'android-sdk'
$latest = Join-Path $sdk 'cmdline-tools\latest'
if (!(Test-Path -LiteralPath $latest)) {
    $extract = Join-Path $toolsPath 'android-extract'
    Expand-Archive -LiteralPath $androidZip -DestinationPath $extract -Force
    New-Item -ItemType Directory -Path (Split-Path $latest -Parent) -Force | Out-Null
    $source = (Resolve-Path -LiteralPath (Join-Path $extract 'cmdline-tools')).Path
    $target = [IO.Path]::GetFullPath($latest)
    if (!$source.StartsWith($toolsPath + '\') -or !$target.StartsWith($toolsPath + '\')) { throw 'Unexpected SDK path' }
    Move-Item -LiteralPath $source -Destination $target
}
. (Join-Path $PSScriptRoot 'env.ps1')
& java -version
& (Join-Path $latest 'bin\sdkmanager.bat') --version
if ($LASTEXITCODE -ne 0) { throw 'sdkmanager failed' }
