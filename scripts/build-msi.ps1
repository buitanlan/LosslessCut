#Requires -Version 7.0
param(
    [Parameter(Mandatory = $true)]
    [string] $ArchivePath,

    [Parameter(Mandatory = $true)]
    [string] $Version,

    [string] $OutputDir = 'dist',

    [string] $WixVersion = $env:WIX_VERSION
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $WixVersion) { $WixVersion = '7.0.0' }

function Resolve-SevenZip {
    $candidates = @(
        (Get-Command 7z -ErrorAction SilentlyContinue)?.Source
        (Get-Command 7za -ErrorAction SilentlyContinue)?.Source
        'C:\Program Files\7-Zip\7z.exe'
        'C:\Program Files (x86)\7-Zip\7z.exe'
        (Join-Path $env:LOCALAPPDATA 'LostlessCut\tools\7zip\x64\7za.exe')
        (Join-Path $env:LOCALAPPDATA 'LostlessCut\tools\7zip\7za.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates) {
        return $candidates[0]
    }

    Write-Host '7-Zip not found; downloading portable 7-Zip Extra...'
    $portableDir = Join-Path $env:LOCALAPPDATA 'LostlessCut\tools\7zip'
    New-Item -ItemType Directory -Path $portableDir -Force | Out-Null

    $bootstrapExe = Join-Path $env:TEMP '7zr.exe'
    if (-not (Test-Path $bootstrapExe)) {
        Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile $bootstrapExe -UseBasicParsing
    }

    $extraPath = Join-Path $env:TEMP '7z-extra.7z'
    if (-not (Test-Path $extraPath)) {
        Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7z2601-extra.7z' -OutFile $extraPath -UseBasicParsing
    }

    & $bootstrapExe x $extraPath "-o$portableDir" -y | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to extract portable 7-Zip from https://www.7-zip.org/download.html'
    }

    foreach ($path in @(
            (Join-Path $portableDir 'x64\7za.exe')
            (Join-Path $portableDir '7za.exe')
        )) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw 'Portable 7-Zip was extracted but 7za.exe could not be located'
}

if (-not (Test-Path $ArchivePath)) {
    throw "Archive not found: $ArchivePath"
}

$sevenZip = Resolve-SevenZip
Write-Host "Using 7-Zip: $sevenZip"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$extractRoot = Join-Path $env:TEMP "losslesscut-extract-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

try {
    Write-Host "Extracting $ArchivePath..."
    & $sevenZip x $ArchivePath "-o$extractRoot" -y | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed with exit code $LASTEXITCODE"
    }

    $exe = Get-ChildItem -Path $extractRoot -Filter 'LosslessCut.exe' -Recurse -File |
        Select-Object -First 1
    if (-not $exe) {
        throw "LosslessCut.exe not found inside extracted archive"
    }

    $appDir = $exe.Directory.FullName
    Write-Host "Application directory: $appDir"

    $msiVersionParts = $Version.Split('.')
    while ($msiVersionParts.Count -lt 4) {
        $msiVersionParts += '0'
    }
    $msiVersion = ($msiVersionParts[0..3] -join '.')

    Write-Host "Installing WiX $WixVersion..."
    dotnet tool install --global wix --version $WixVersion 2>$null
    if ($LASTEXITCODE -ne 0) {
        dotnet tool update --global wix --version $WixVersion
    }

    $dotnetTools = Join-Path $env:USERPROFILE '.dotnet\tools'
    $env:PATH = "$dotnetTools;$env:PATH"

    Write-Host "Building MSI (version $msiVersion)..."
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $msiPath = Join-Path (Resolve-Path $OutputDir) "LosslessCut-$Version-win-x64.msi"
    $productWxs = Join-Path $repoRoot 'installer\Product.wxs'

    $wixArgs = @(
        'build', $productWxs
        '-bindpath', "AppDir=$appDir"
        '-d', "Version=$msiVersion"
        '-arch', 'x64'
        '-o', $msiPath
    )
    if ($WixVersion -match '^7\.') {
        # WiX 7+ requires OSMF EULA acceptance in CI: https://docs.firegiant.com/wix/osmf/
        $wixArgs += @('-acceptEula', 'wix7')
    }

    & wix @wixArgs

    if ($LASTEXITCODE -ne 0) {
        throw "WiX build failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path $msiPath)) {
        throw "MSI was not created: $msiPath"
    }

    $sizeMb = [math]::Round((Get-Item $msiPath).Length / 1MB, 2)
    Write-Host "Created $msiPath ($sizeMb MB)"
}
finally {
    if (Test-Path $extractRoot) {
        Remove-Item -Path $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
