#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$upstreamRepo = $env:UPSTREAM_REPO
if (-not $upstreamRepo) { $upstreamRepo = 'mifi/lossless-cut' }

$assetName = $env:ASSET_NAME
if (-not $assetName) { $assetName = 'LosslessCut-win-x64.7z' }

$headers = @{
    'User-Agent'           = 'LostlessCut-MSI-CI'
    'Accept'               = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

Write-Host "Fetching latest upstream release from $upstreamRepo..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$upstreamRepo/releases/latest" -Headers $headers

$tag = $release.tag_name
$version = $tag -replace '^v', ''
$releaseUrl = "https://github.com/$upstreamRepo/releases/tag/$tag"
$downloadUrl = "https://github.com/$upstreamRepo/releases/download/$tag/$assetName"

$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
if (-not $asset) {
    throw "Asset '$assetName' not found in upstream release $tag ($releaseUrl)"
}

Write-Host "Upstream release: $tag ($version)"
Write-Host "Release page: $releaseUrl"
Write-Host "Download URL: $downloadUrl"

$shouldBuild = $true
$reason = ''

if ($env:GITHUB_REPOSITORY) {
    $authHeaders = $headers.Clone()
    if ($env:GITHUB_TOKEN) {
        $authHeaders['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    $checkUrl = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/releases/tags/$tag"
    try {
        Invoke-RestMethod -Uri $checkUrl -Headers $authHeaders -ErrorAction Stop | Out-Null
        $shouldBuild = $false
        $reason = "Release $tag already exists in $env:GITHUB_REPOSITORY"
    }
    catch {
        $response = $_.Exception.Response
        if ($response -and [int]$response.StatusCode -eq 404) {
            $shouldBuild = $true
            $reason = "Release $tag not found; build required"
        }
        else {
            throw
        }
    }
}
else {
    $reason = 'Running outside GitHub Actions; build enabled'
}

if ($env:GITHUB_OUTPUT) {
    "tag=$tag" >> $env:GITHUB_OUTPUT
    "version=$version" >> $env:GITHUB_OUTPUT
    "download_url=$downloadUrl" >> $env:GITHUB_OUTPUT
    "release_url=$releaseUrl" >> $env:GITHUB_OUTPUT
    "should_build=$($shouldBuild.ToString().ToLower())" >> $env:GITHUB_OUTPUT
    "reason=$reason" >> $env:GITHUB_OUTPUT
}

Write-Host "should_build=$shouldBuild — $reason"
