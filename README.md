# LostlessCut

Automatically builds a Windows MSI installer when [mifi/lossless-cut](https://github.com/mifi/lossless-cut) publishes a new release.

## How it works

1. The [GitHub Actions workflow](.github/workflows/build-msi.yml) runs monthly (and on push to `main`/`master` or manual trigger).
2. It reads the **latest** upstream release from `mifi/lossless-cut`.
3. If this repository does not already have a GitHub release with the same tag (e.g. `v3.70.0`), it:
   - Downloads `LosslessCut-win-x64.7z` from that release
   - Extracts the portable app
   - Packages it into an MSI with [WiX Toolset 7](https://wixtoolset.org/)
   - Publishes a GitHub release with `LosslessCut-<version>-win-x64.msi`

Release notes link to the upstream release page (`releases/tag/<version>`), not the direct download URL.

## Manual run

In GitHub: **Actions → Build LosslessCut MSI → Run workflow**.

## Local build

```powershell
# Download the upstream 7z for the version you want, then:
./scripts/build-msi.ps1 -ArchivePath .\LosslessCut-win-x64.7z -Version 3.70.0
```

Requires [.NET SDK](https://dotnet.microsoft.com/download) and 7-Zip (included on GitHub-hosted Windows runners).

## Install

```powershell
msiexec /i LosslessCut-<version>-win-x64.msi
```

Or double-click the MSI from the [Releases](https://github.com/YOUR_USER/LostlessCut/releases) page.

## License

This repository only contains packaging automation. LosslessCut itself is licensed by its upstream authors. See [mifi/lossless-cut](https://github.com/mifi/lossless-cut).
