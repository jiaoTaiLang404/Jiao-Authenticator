#requires -Version 7.0
[CmdletBinding()]
param(
    [string] $OutputDirectory = (Join-Path $PSScriptRoot 'dist'),
    [string] $FlutterRoot,
    [string] $AndroidSdk,
    [string] $JavaHome,
    [string] $SigningConfig
)

$ErrorActionPreference = 'Stop'
$projectVersion = [regex]::Match(
    (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pubspec.yaml') -Raw),
    '(?m)^version:[ \t]*(\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\+\d+[ \t]*\r?$'
)
if (!$projectVersion.Success) { throw 'pubspec.yaml 需要 version: x.y.z+build 格式。' }

$buildArgs = @{}
foreach ($name in @('FlutterRoot', 'AndroidSdk', 'JavaHome', 'SigningConfig')) {
    if ($PSBoundParameters.ContainsKey($name)) { $buildArgs[$name] = $PSBoundParameters[$name] }
}
& (Join-Path $PSScriptRoot 'tool\dev.ps1') -Action Release @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$built = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
$directory = [IO.Path]::GetFullPath($OutputDirectory, $PSScriptRoot)
[IO.Directory]::CreateDirectory($directory) | Out-Null
$filename = "Jiao-Authenticator-v$($projectVersion.Groups[1].Value).apk"
$apk = Join-Path $directory $filename
$sha256 = (Get-FileHash -LiteralPath $built -Algorithm SHA256).Hash.ToLowerInvariant()
Copy-Item -LiteralPath $built -Destination $apk -Force
if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $sha256) { throw 'APK 复制校验失败。' }
"$sha256  $filename" | Set-Content -LiteralPath "$apk.sha256" -Encoding ascii
Write-Output "APK_READY=$apk"
Write-Output "APK_SHA256=$sha256"
