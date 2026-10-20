# Compiles the phone-only Camera2/ONNX library from public sources and a supplied model.
param([Parameter(Mandatory=$true)][string]$JavaHome,[Parameter(Mandatory=$true)][string]$AndroidSdk,[Parameter(Mandatory=$true)][string]$Model,[string]$OnnxRuntimeAar)
$ErrorActionPreference='Stop'
$taskProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$taskPlugins=Join-Path $taskProject 'android\plugins'
$taskBuild=Join-Path $taskProject ('.runtime\android-native\'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $taskPlugins,"$taskBuild\classes" | Out-Null
if(-not $OnnxRuntimeAar){
    $OnnxRuntimeAar=Join-Path $taskBuild 'onnxruntime-android-1.23.2.aar'
    Invoke-WebRequest -Uri 'https://repo.maven.apache.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.23.2/onnxruntime-android-1.23.2.aar' -OutFile $OnnxRuntimeAar
}
if((Get-FileHash -LiteralPath $OnnxRuntimeAar -Algorithm SHA256).Hash -ne '82048D1F462218ADAE4BA76477089AB0BA76093D84F733540066DB1A8BA6B827'){throw 'ONNX Runtime Android checksum mismatch'}
function Read-ClassesJar([string]$Archive,[string]$Output){
    $taskZip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try{
        $taskStream=$taskZip.GetEntry('classes.jar').Open()
        try{$taskTarget=[IO.File]::Create($Output);try{$taskStream.CopyTo($taskTarget)}finally{$taskTarget.Dispose()}}finally{$taskStream.Dispose()}
    }finally{$taskZip.Dispose()}
}
Read-ClassesJar (Join-Path $taskProject 'android\build\libs\release\godot-lib.template_release.aar') "$taskBuild\godot.jar"
Read-ClassesJar $OnnxRuntimeAar "$taskBuild\onnx.jar"
$taskClasspath="$AndroidSdk\platforms\android-36\android.jar;$taskBuild\godot.jar;$taskBuild\onnx.jar"
& "$JavaHome\bin\javac.exe" -encoding UTF-8 -source 17 -target 17 -cp $taskClasspath -d "$taskBuild\classes" "$PSScriptRoot\native\com\aiu5\mobile\AiuGiftCamera.java" "$PSScriptRoot\native\com\aiu5\mobile\GiftDetector.java"
if($LASTEXITCODE -ne 0){throw 'Camera2 bridge Java compilation failed'}
& "$JavaHome\bin\jar.exe" --create --file "$taskBuild\classes.jar" -C "$taskBuild\classes" .
if($LASTEXITCODE -ne 0){throw 'Camera library class archive failed'}
$taskAar=Join-Path $taskPlugins 'aiu-camera.aar'
if(Test-Path -LiteralPath $taskAar){Remove-Item -LiteralPath $taskAar}
$taskZip=[IO.Compression.ZipFile]::Open($taskAar,[IO.Compression.ZipArchiveMode]::Create)
try{
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskZip,"$taskBuild\classes.jar",'classes.jar') | Out-Null
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskZip,"$PSScriptRoot\native\AndroidManifest.xml",'AndroidManifest.xml') | Out-Null
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskZip,(Resolve-Path -LiteralPath $Model).Path,'assets/aiu_gifts18.onnx') | Out-Null
    $taskZip.CreateEntry('R.txt') | Out-Null
}finally{$taskZip.Dispose()}
Copy-Item -LiteralPath $OnnxRuntimeAar -Destination (Join-Path $taskPlugins 'onnxruntime-android-1.23.2.aar') -Force
'Android native camera library built.'
