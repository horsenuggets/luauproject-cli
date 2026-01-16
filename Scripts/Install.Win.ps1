$PROGRAM_NAME = "luauproject"
$REPOSITORY = "horsenuggets/luauproject-cli"

$originalPath = Get-Location

Set-Location "$env:temp"

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
        throw "Failed to fetch release info: $_"
    }
}

try {
    if ($env:GITHUB_PAT) {
        Write-Host "NOTE: Using provided GITHUB_PAT for authentication"
    }

    # Determine architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) {
        if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
            "aarch64"
        } else {
            "x86_64"
        }
    } else {
        Write-Error "32-bit systems are not supported"
        exit 1
    }

    # Determine version to download
    $version = $args[0]
    if ($version) {
        Write-Host "`n[1 / 3] Looking for $PROGRAM_NAME release with tag '$version'"
        $apiUrl = "https://api.github.com/repos/$REPOSITORY/releases/tags/$version"
    } else {
        Write-Host "`n[1 / 3] Looking for latest $PROGRAM_NAME release"
        $apiUrl = "https://api.github.com/repos/$REPOSITORY/releases/latest"
    }

    $releaseInfo = Get-ReleaseInfo -ApiUrl $apiUrl

    # Find the download URL for our platform
    $binaryName = "$PROGRAM_NAME-windows-$arch.exe"
    $asset = $releaseInfo.assets | Where-Object { $_.name -eq $binaryName } | Select-Object -First 1

    if (-not $asset) {
        throw "Could not find binary '$binaryName' in the release"
    }

    $downloadUrl = $asset.browser_download_url
    Write-Host "[2 / 3] Downloading '$binaryName'"

    # Download the binary
    $tempFile = "$PROGRAM_NAME.exe"
    try {
        Invoke-WebRequest $downloadUrl -OutFile $tempFile -ErrorAction Stop
    }
    catch {
        throw "Failed to download from $downloadUrl`: $_"
    }

    if (-not (Test-Path $tempFile)) {
        throw "Download failed - file not found"
    }

    # Run self-install
    try {
        Write-Host "[3 / 3] Running $PROGRAM_NAME installation`n"
        Start-Process -FilePath ".\$tempFile" -ArgumentList "install" -Wait -NoNewWindow
    }
    catch {
        throw "Failed to run install: $_"
    }

    # Cleanup
    try {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Cleanup failed: $_"
    }
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}
finally {
    Set-Location -Path $originalPath
}
