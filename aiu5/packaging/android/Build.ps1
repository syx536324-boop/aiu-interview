# Exports Android independently, verifies its signature, and guards the existing desktop binaries.
param([Parameter(Mandatory=$true)][string]$Godot,[Parameter(Mandatory=$true)][string]$JavaHome,[Parameter(Mandatory=$true)][string]$AndroidSdk,[Parameter(Mandatory=$true)][string]$KeyStore,[string]$KeyAlias='aiu5')
$ErrorActionPreference='Stop'
$taskProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$taskApk=Join-Path $taskProject 'exports\android\沙盘上的生活-0.10.8-android.3.apk'
if(-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD){throw 'Set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD locally before export'}
if(-not(Test-Path -LiteralPath $KeyStore)){throw 'Release signing key does not exist'}
$taskDesktop=@{}
foreach($taskFile in @('exports\windows\AIU5.exe','exports\windows\AIU5.pck','exports\AIU5-Setup-0.10.8-win64.exe')){
    $taskPath=Join-Path $taskProject $taskFile
    if(Test-Path -LiteralPath $taskPath){$taskDesktop[$taskFile]=(Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash}
}
$env:JAVA_HOME=$JavaHome;$env:ANDROID_HOME=$AndroidSdk;$env:ANDROID_SDK_ROOT=$AndroidSdk
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH=(Resolve-Path -LiteralPath $KeyStore).Path
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER=$KeyAlias
New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($taskApk)) | Out-Null
& $Godot --headless --path $taskProject --export-release 'Android' $taskApk
if($LASTEXITCODE -ne 0){throw 'Android export failed'}
& "$AndroidSdk\build-tools\36.1.0\apksigner.bat" verify --verbose --print-certs $taskApk
if($LASTEXITCODE -ne 0){throw 'APK signature verification failed'}
foreach($taskFile in $taskDesktop.Keys){
    if((Get-FileHash -LiteralPath (Join-Path $taskProject $taskFile) -Algorithm SHA256).Hash -ne $taskDesktop[$taskFile]){throw "Desktop artifact changed: $taskFile"}
}
Get-FileHash -LiteralPath $taskApk -Algorithm SHA256
