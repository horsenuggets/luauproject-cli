$PROGRAM_NAME = "luauproject"
$REPOSITORY = "horsenuggets/luauproject-cli"
$INSTALL_DIR = "$env:USERPROFILE\.luauproject-cli"
$BIN_DIR = "$INSTALL_DIR\bin"
$VERSIONS_DIR = "$INSTALL_DIR\versions"
$CURRENT_FILE = "$INSTALL_DIR\current"

Function Get-ReleaseInfo {
    param (
        [string]$ApiUrl
    )

    $headers = @{
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if ($env:GITHUB_PAT) {
        $headers['Authorization'] = "token $env:GITHUB_PAT"
    }

    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -ErrorAction Stop
        return $response
    }
    catch {
        throw "Failed to fetch release info. $_"
    }
}

Function Get-WindowsUserPath {
    try {
        $path = [Environment]::GetEnvironmentVariable("Path", "User")
        return $path
    }
    catch {
        return $null
    }
}

Function Add-ToPath {
    param (
        [string]$Directory
    )

    $currentPath = Get-WindowsUserPath
    if ($currentPath -and $currentPath.ToLower().Contains($Directory.ToLower())) {
        Write-Host "PATH already configured."
        return $false
    }

    $newPath = if ($currentPath) { "$currentPath;$Directory" } else { $Directory }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $Directory to user PATH."
    return $true
}

try {
    if ($env:GITHUB_PAT) {
        Write-Host "Using the provided GITHUB_PAT for authentication."
    }

    # Determine architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) {
        if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
            "aarch64"
        } else {
            "x86_64"
        }
    } else {
        Write-Error "32-bit systems are not supported."
        exit 1
    }

    # Determine version to download
    $version = $args[0]
    if ($version) {
        Write-Host "`n[1 / 6] Looking for $PROGRAM_NAME release with tag `"$version`"."
        $apiUrl = "https://api.github.com/repos/$REPOSITORY/releases/tags/$version"
    } else {
        Write-Host "`n[1 / 6] Looking for the latest $PROGRAM_NAME release."
        $apiUrl = "https://api.github.com/repos/$REPOSITORY/releases/latest"
    }

    $releaseInfo = Get-ReleaseInfo -ApiUrl $apiUrl
    $releaseVersion = $releaseInfo.tag_name
    Write-Host "Found version $releaseVersion."

    # Find the download URLs
    $cliBinaryName = "$PROGRAM_NAME-windows-$arch.exe"
    $launcherBinaryName = "$PROGRAM_NAME-launcher-windows-$arch.exe"

    $cliAsset = $releaseInfo.assets | Where-Object { $_.name -eq $cliBinaryName } | Select-Object -First 1
    $launcherAsset = $releaseInfo.assets | Where-Object { $_.name -eq $launcherBinaryName } | Select-Object -First 1

    if (-not $cliAsset) {
        throw "Could not find the CLI binary `"$cliBinaryName`" in the release."
    }

    if (-not $launcherAsset) {
        throw "Could not find the launcher binary `"$launcherBinaryName`" in the release."
    }

    $cliDownloadUrl = $cliAsset.browser_download_url
    $launcherDownloadUrl = $launcherAsset.browser_download_url

    # Create installation directories
    Write-Host "[2 / 6] Creating installation directories."
    New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $VERSIONS_DIR | Out-Null

    # Download the CLI binary
    Write-Host "[3 / 6] Downloading CLI `"$cliBinaryName`"."
    $cliDest = "$VERSIONS_DIR\$PROGRAM_NAME-$releaseVersion.exe"
    try {
        Invoke-WebRequest $cliDownloadUrl -OutFile $cliDest -ErrorAction Stop
    }
    catch {
        throw "Failed to download CLI from $cliDownloadUrl. $_"
    }

    if (-not (Test-Path $cliDest)) {
        throw "Failed to download the CLI binary."
    }

    # Download the launcher binary
    Write-Host "[4 / 6] Downloading launcher `"$launcherBinaryName`"."
    $launcherDest = "$BIN_DIR\$PROGRAM_NAME.exe"
    try {
        Invoke-WebRequest $launcherDownloadUrl -OutFile $launcherDest -ErrorAction Stop
    }
    catch {
        throw "Failed to download launcher from $launcherDownloadUrl. $_"
    }

    if (-not (Test-Path $launcherDest)) {
        throw "Failed to download the launcher binary."
    }

    # Set the current version
    Write-Host "[5 / 6] Setting current version."
    Set-Content -Path $CURRENT_FILE -Value $releaseVersion -NoNewline

    # Configure PATH
    Write-Host "[6 / 6] Configuring PATH."
    $pathChanged = Add-ToPath -Directory $BIN_DIR

    # Print success message
    Write-Host "`nInstallation complete!"
    Write-Host ""
    Write-Host "Installed version $releaseVersion."
    Write-Host "Launcher at $launcherDest."
    Write-Host "CLI at $cliDest."

    if ($pathChanged) {
        Write-Host ""
        Write-Host "Restart your terminal to use luauproject."
    }
}
catch {
    Write-Error "Installation failed. $_"
    exit 1
}
