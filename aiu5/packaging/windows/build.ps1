# Exports Godot and assembles the model plus physical camera runtime into an Inno installer.
param([Parameter(Mandatory=$true)][string]$Godot,[Parameter(Mandatory=$true)][string]$ISCC)
$ErrorActionPreference='Stop'
$taskProject=(Resolve-Path "$PSScriptRoot\..\..").Path
$taskOutput=Join-Path $taskProject 'exports\windows'
$taskModel=Join-Path $taskProject 'models\gifts18-prototype-v1.pt'
if ((Get-FileHash -LiteralPath $taskModel).Hash -ne '5A7BB20F5BF0D86CA32BCF82447012FE088CDCB3791EF275D2F4FBC2353A6A8B') { throw 'Unexpected model hash' }
foreach ($taskRequired in @('python.exe','pythonw.exe','python312.dll','python312._pth','site-packages\torch\__init__.py','site-packages\cv2\__init__.py','site-packages\ultralytics\__init__.py','msvcp140.dll','vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath "$taskProject\runtime\$taskRequired")) { throw "Missing camera runtime: $taskRequired" }
}
New-Item -ItemType Directory -Force -Path $taskOutput | Out-Null
& $Godot --headless --path $taskProject --export-release 'Windows Desktop' "$taskOutput\AIU5.exe"
if ($LASTEXITCODE -ne 0) { throw 'Godot export failed' }
foreach ($taskFolder in @('models','runtime','services\gift_camera')) {
    $taskSidecarTarget=[IO.Path]::GetFullPath("$taskOutput\$taskFolder")
    if (-not $taskSidecarTarget.StartsWith($taskOutput+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Sidecar target escaped export folder' }
    New-Item -ItemType Directory -Force -Path $taskSidecarTarget | Out-Null
    & robocopy "$taskProject\$taskFolder" $taskSidecarTarget /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) { throw "Sidecar copy failed: $taskFolder" }
}
Copy-Item -LiteralPath "$taskProject\assets\branding\game-icon.ico" -Destination $taskOutput
Copy-Item -LiteralPath "$taskProject\THIRD_PARTY_NOTICES.md","$PSScriptRoot\README.md" -Destination $taskOutput
& $ISCC "/DPackageDir=$taskOutput" "/DOutputDir=$taskProject\exports" "$PSScriptRoot\installer.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
Get-FileHash -LiteralPath "$taskProject\exports\AIU5-Setup-0.7.3-win64.exe"
