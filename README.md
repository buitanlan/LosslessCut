# LostlessCut

Automatically builds a Windows MSI installer when [mifi/lossless-cut](https://github.com/mifi/lossless-cut) publishes a new release.

## How it works

1. The [GitHub Actions workflow](.github/workflows/build-msi.yml) runs daily (and on manual trigger).
2. It reads the latest upstream release from `mifi/lossless-cut`.
3. If this repository does not already have a GitHub release with the same tag (e.g. `v3.69.0`), it:
   - Downloads `LosslessCut-win-x64.7z`
   - Extracts the portable app
   - Packages it into an MSI with [WiX Toolset 5](https://wixtoolset.org/)
   - Publishes a GitHub release with `LosslessCut-<version>-win-x64.msi`

## Manual run

In GitHub: **Actions → Build LosslessCut MSI → Run workflow**.

## Local build

```powershell
# Download upstream 7z, then:
./scripts/build-msi.ps1 -ArchivePath .\LosslessCut-win-x64.7z -Version 3.69.0
```

Requires [.NET SDK](https://dotnet.microsoft.com/download) and 7-Zip (included on GitHub-hosted Windows runners).

## Install

```powershell
msiexec /i LosslessCut-3.69.0-win-x64.msi
```

Or double-click the MSI from the [Releases](https://github.com/YOUR_USER/LostlessCut/releases) page.

## License

This repository only contains packaging automation. LosslessCut itself is licensed by its upstream authors. See [mifi/lossless-cut](https://github.com/mifi/lossless-cut).
