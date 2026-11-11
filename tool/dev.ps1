#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Doctor', 'Analyze', 'Test', 'Integration', 'Release')]
    [string] $Action = 'Test',
    [string] $FlutterRoot = (Join-Path $HOME 'Documents\Codex\toolchains\flutter'),
    [string] $AndroidSdk = (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
    [string] $JavaHome = 'C:\Program Files\Java\jdk-17',
    [string] $SigningConfig = (Join-Path $HOME 'Documents\Codex\toolchains\jiao-signing\signing.json'),
    [string] $Device = 'emulator-5570'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
if (!(Test-Path -LiteralPath $flutter)) { throw '请传入有效的 -FlutterRoot。' }
if (!(Test-Path -LiteralPath $AndroidSdk)) { throw '请传入有效的 -AndroidSdk。' }
if (!(Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) { throw '请传入 Java 17 的 -JavaHome。' }
$toolchains = Split-Path $FlutterRoot -Parent
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:PUB_CACHE = Join-Path $toolchains 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $toolchains 'gradle-cache'
$localMaven = Join-Path $toolchains 'jiao-maven-cache'
$mavenInit = Join-Path $env:GRADLE_USER_HOME 'init.d\jiao-maven-relay.init.gradle'
if (!$env:JIAO_MAVEN_RELAY_URL -and
    (Test-Path -LiteralPath $localMaven -PathType Container) -and
    (Test-Path -LiteralPath $mavenInit -PathType Leaf)) {
    $env:JIAO_MAVEN_RELAY_URL = ([uri]($localMaven.TrimEnd('\') + '\')).AbsoluteUri
}
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:PATH = "$(Join-Path $FlutterRoot 'bin');$(Join-Path $AndroidSdk 'platform-tools');$(Join-Path $JavaHome 'bin');$env:PATH"
Push-Location $root
try {
    switch ($Action) {
        'Doctor' { & $flutter doctor -v }
        'Analyze' { & $flutter analyze }
        'Test' { & $flutter test --coverage --reporter expanded }
        'Integration' {
            & $flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d $Device --no-dds
        }
        'Release' {
            $configPath = [IO.Path]::GetFullPath($SigningConfig)
            $rootPath = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
            if ($configPath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
                throw '签名配置应放在项目目录之外。'
            }
            if (!(Test-Path -LiteralPath $configPath)) { throw '请指定项目外的正式签名配置。' }
            $signing = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            if (!$signing.storeFile -or !$signing.storePassword -or !$signing.keyPassword -or
                !(Test-Path -LiteralPath $signing.storeFile)) { throw '签名配置不完整。' }
            $env:JIAO_STORE_FILE = $signing.storeFile
            $env:JIAO_STORE_PASSWORD = $signing.storePassword
            $env:JIAO_KEY_PASSWORD = $signing.keyPassword
            try {
                & $flutter build apk --release
                $buildExit = $LASTEXITCODE
            } finally {
                Remove-Item Env:JIAO_STORE_FILE, Env:JIAO_STORE_PASSWORD, Env:JIAO_KEY_PASSWORD -ErrorAction SilentlyContinue
                $signing = $null
            }
            if ($buildExit -ne 0) { exit $buildExit }
            $verifier = Join-Path $AndroidSdk 'build-tools\36.0.0\apksigner.bat'
            & $verifier verify --verbose (Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk')
        }
    }
    $result = $LASTEXITCODE
} finally { Pop-Location }
exit $result
