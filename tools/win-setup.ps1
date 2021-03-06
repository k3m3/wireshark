#
# win-setup - Prepare a Windows development environment for building Wireshark.
#
# Copyright 2015 Gerald Combs <gerald@wireshark.org>
#
# Wireshark - Network traffic analyzer
# By Gerald Combs <gerald@wireshark.org>
# Copyright 1998 Gerald Combs
#
# SPDX-License-Identifier: GPL-2.0-or-later

#requires -version 2

# Makefile.nmake + win-setup.sh does:
# - verify_tools: Checks required executables. CMake does this.
# - clean_setup: Removes current and past lib dirs.
# - process_libs: calls libverify or download for each lib.

# To do:
# - Make this the source of truth. Keep the list of libs here.
# - Download everything unconditionally, at least initially.

# Bugs:
# - Unzipping from the shell seems to be slower than Cygwin's unzip or 7zip.

<#
.SYNOPSIS
Prepare a Windows development environment for building Wireshark.

.DESCRIPTION
This script downloads and extracts third-party libraries required to compile
Wireshark.

.PARAMETER Destination
Specifies the destination directory for the text files. The path must
contain the pattern "wireshark-*-libs".

.PARAMETER Platform
Target platform. One of "win64" or "win32".

.PARAMETER VSVersion
Visual Studio version. Must be the numeric version (e.g. "12", "11"),
not the year.

.PARAMETER Force
Download each library even if exists on the local system.

.INPUTS
-Destination Destination directory.
-Platform Target platform.
-VSVersion Visual Studio version.
-Force Force fresh downloads.

.OUTPUTS
A set of libraries required to compile Wireshark on Windows, along with
their compressed archives.
A date stamp (current-tag.txt)

.EXAMPLE
C:\PS> .\tools\win-setup.ps1 -Destination C:\wireshark-master-64-libs -Platform win64
#>

Param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateScript({$_ -like "*\wireshark-*-libs"})]
    [String]
    $Destination,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidateSet("win32", "win64")]
    [String]
    $Platform,

    [Parameter(Mandatory=$false, Position=2)]
    [ValidateSet("14", "12", "11", "10")]
    [String]
    $VSVersion,

    [Parameter(Mandatory=$false)]
    [Switch]
    $Force
)

# Variables

# We create and delete files and directories. Bail out at the first sign of
# trouble instead of trying to catch exceptions everywhere.
$ErrorActionPreference = "Stop"

$Win64CurrentTag = "2018-04-20"
$Win32CurrentTag = "2018-04-20"

# Archive file / subdir.
$Win64Archives = @{
    "AirPcap_Devpack_4_1_0_1622.zip" = "AirPcap_Devpack_4_1_0_1622";
    "bcg729-1.0.4-win64ws.zip" = "";
    "c-ares-1.14.0-win64ws.zip" = "";
    "gnutls-3.4.11-1.35-win64ws.zip" = "";
    "glib2-2.52.2-1.31-win64ws.zip" = "";
    "json-glib-1.0.2-4.31-win64ws.zip" = "";
    "kfw-3-2-2-x64-ws.zip" = "";
    "libgcrypt-1.7.6-win64ws.zip" = "";
    "libsmi-svn-40773-win64ws.zip" = "";
    "libssh-0.7.3-1-win64ws.zip" = "";
    "libxml2-2.9.4-win64ws.zip" = "";
    "lua-5.2.4_Win64_dllw4_lib.zip" = "lua5.2.4";
    "lz4-1.7.5-win64ws.zip" = "";
    "MaxMindDB-1.3.2-win64ws.zip" = "";
    "nghttp2-1.14.0-1-win64ws.zip" = "";
    "sbc-1.3-1-win64ws.zip" = "";
    "snappy-1.1.3-1-win64ws.zip" = "";
    "spandsp-0.0.6-1-win64ws.zip" = "";
    "WinSparkle-0.5.6.zip" = "";
    "WpdPack_4_1_2.zip" = "";
    "zlib-1.2.11-ws.zip" = "";
}

$Win32Archives = @{
    "AirPcap_Devpack_4_1_0_1622.zip" = "AirPcap_Devpack_4_1_0_1622";
    "bcg729-1.0.4-win32ws.zip" = "";
    "c-ares-1.14.0-win32ws.zip" = "";
    "gnutls-3.4.11-1.36-win32ws.zip" = "";
    "glib2-2.52.2-1.34-win32ws.zip" = "";
    "json-glib-1.0.2-4.37-win32ws.zip" = "";
    "kfw-3-2-2-i386-ws-vc6.zip" = "";
    "libgcrypt-1.7.6-win32ws.zip" = "";
    "libsmi-svn-40773-win32ws.zip" = "";
    "libssh-0.7.3-1-win32ws.zip" = "";
    "libxml2-2.9.4-win32ws.zip" = "";
    "lua-5.2.4_Win32_dllw4_lib.zip" = "lua5.2.4";
    "lz4-1.7.5-win32ws.zip" = "";
    "MaxMindDB-1.3.2-win32ws.zip" = "";
    "nghttp2-1.14.0-1-win32ws.zip" = "";
    "sbc-1.3-1-win32ws.zip" = "";
    "snappy-1.1.3-1-win32ws.zip" = "";
    "spandsp-0.0.6-1-win32ws.zip" = "";
    "WinSparkle-0.5.6.zip" = "";
    "WpdPack_4_1_2.zip" = "";
    "zlib-1.2.11-ws.zip" = "";
}

# Plain file downloads

$Win32Files = @(
    "WinPcap_4_1_3.exe";
    "USBPcapSetup-1.2.0.3.exe";
)

$Win64Files = @(
    "WinPcap_4_1_3.exe";
    "USBPcapSetup-1.2.0.3.exe";
)

$Archives = $Win64Archives;
$Files = $Win64Files;
$CurrentTag = $Win64CurrentTag;

if ($Platform -eq "win32") {
    $Archives = $Win32Archives;
    $Files = $Win32Files;
    $CurrentTag = $Win32CurrentTag;
}

$CleanupItems = @(
    "bcg729-1.0.4-win??ws"
    "c-ares-1.9.1-1-win??ws"
    "c-ares-1.1*-win??ws"
    "gnutls-3.1.22-*-win??ws"
    "gnutls-3.2.15-*-win??ws"
    "gnutls-3.4.11-*-win??ws"
    "glib2-2.*-win??ws"
    "gtk2"
    "gtk3"
    "json-glib-1.0.2-*-win??ws"
    "kfw-3-2-2-final"
    "kfw-3-2-2-i386-ws-vc6"
    "kfw-3-2-2-x64-ws"
    "libgcrypt-1.7.6-win??ws"
    "libsmi-0.4.8"
    "libsmi-svn-40773-win??ws"
    "libssh-0.7.?-win??ws"
    "libxml2-*-win??ws"
    "lua5.1.4"
    "lua5.2.?"
    "lz4-*-win??ws"
    "MaxMindDB-1.3.2-win??ws"
    "nghttp2-*-win??ws"
    "portaudio_v19"
    "portaudio_v19_2"
    "sbc-1.3-win??ws"
    "snappy-1.1.3-win??ws"
    "spandsp-0.0.6-win??ws"
    "upx301w"
    "upx303w"
    "user-guide"
    "zlib-1.2.5"
    "zlib-1.2.8"
    "zlib-1.2.*-ws"
    "AirPcap_Devpack_4_1_0_1622"
    "GeoIP-1.*-win??ws"
    "WinSparkle-0.3-44-g2c8d9d3-win??ws"
    "WinSparkle-0.5.?"
    "WpdPack"
    "current-tag.txt"
)

[Uri] $DownloadPrefix = "https://anonsvn.wireshark.org/wireshark-$($Platform)-libs/tags/$($CurrentTag)/packages"
$Global:SevenZip = "7-zip-not-found"

# Functions

function DownloadFile($fileName, [Uri] $fileUrl = $null) {
    if ([string]::IsNullOrEmpty($fileUrl)) {
        $fileUrl = "$DownloadPrefix/$fileName"
    }
    $destinationFile = "$fileName"
    if ((Test-Path $destinationFile -PathType 'Leaf') -and -not ($Force)) {
        Write-Output "$destinationFile already there; not retrieving."
        return
    }

    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

    Write-Output "Downloading $fileUrl into $Destination"
    $webClient = New-Object System.Net.WebClient
    $webClient.proxy = $proxy
    $webClient.DownloadFile($fileUrl, "$Destination\$destinationFile")
}

# Find 7-Zip, downloading it if necessary.
# If we ever add NuGet support we might be able to use
# https://github.com/thoemmi/7Zip4Powershell
function Bootstrap7Zip() {
    $searchExes = @("7z.exe", "7za.exe")
    $binDir = "$Destination\bin"

    # First, check $env:Path.
    foreach ($exe in $searchExes) {
        if (Get-Command $exe -ErrorAction SilentlyContinue)  {
            $Global:SevenZip = "$exe"
            Write-Output "Found 7-zip on the path"
            return
        }
    }

    # Next, look in a few likely places.
    $searchDirs = @(
        "${env:ProgramFiles}\7-Zip"
        "${env:ProgramFiles(x86)}\7-Zip"
        "${env:ProgramW6432}\7-Zip"
        "${env:ChocolateyInstall}\bin"
        "${env:ChocolateyInstall}\tools"
        "$binDir"
    )

    foreach ($dir in $searchDirs) {
        if ($dir -ne $null -and (Test-Path $dir -PathType 'Container')) {
            foreach ($exe in $searchExes) {
                if (Test-Path "$dir\$exe" -PathType 'Leaf') {
                    $Global:SevenZip = "$dir\$exe"
                    Write-Output "Found 7-zip at $dir\$exe"
                    return
                }
            }
        }
    }

    # Finally, download a copy from anonsvn.
    if ( -not (Test-Path $binDir -PathType 'Container') ) {
        New-Item -ItemType 'Container' "$binDir" > $null
    }

    Write-Output "Unable to find 7-zip, retrieving from anonsvn into $binDir\7za.exe"
    [Uri] $bbUrl = "https://anonsvn.wireshark.org/wireshark-win32-libs/trunk/bin/7za.exe"
    DownloadFile "bin\7za.exe" "$bbUrl"

    $Global:SevenZip = "$binDir\7za.exe"
}

function DownloadArchive($fileName, $subDir) {
    DownloadFile $fileName
    # $shell = New-Object -com shell.application
    $archiveFile = "$Destination\$fileName"
    $archiveDir = "$Destination\$subDir"
    if ($subDir -and -not (Test-Path $archiveDir -PathType 'Container')) {
        New-Item -ItemType Directory -Path $archiveDir > $null
    }
    $activity = "Extracting into $($archiveDir)"
    Write-Progress -Activity "$activity" -Status "Running 7z x $archiveFile ..."
    & "$SevenZip" x "-o$archiveDir" -y "$archiveFile" 2>&1 |
        Set-Variable -Name SevenZOut
    $bbStatus = $LASTEXITCODE
    Write-Progress -Activity "$activity" -Status "Done" -Completed
    if ($bbStatus -gt 0) {
        Write-Output $SevenZOut
        exit 1
    }
}

# On with the show

# Make sure $Destination exists and do our work there.
if ( -not (Test-Path $Destination -PathType 'Container') ) {
    New-Item -ItemType 'Container' "$Destination" > $null
}

# CMake's file TO_NATIVE_PATH passive-aggressively omits the drive letter.
Set-Location "$Destination"
$Destination = $(Get-Item -Path ".\")
Write-Output "Working in $Destination"

# Check our last known state
$destinationTag = "INVALID"
$tagFile = "current_tag.txt"
if ((Test-Path $tagFile -PathType 'Leaf') -and -not ($Force)) {
    $destinationTag = Get-Content $tagFile
}

if ($destinationTag -ne $CurrentTag) {
    Write-Output "Tag $CurrentTag not found. Refreshing."
    Bootstrap7Zip
    $activity = "Removing directories"
    foreach ($oldItem in $CleanupItems) {
        if (Test-Path $oldItem) {
            Write-Progress -Activity "$activity" -Status "Removing $oldItem"
            Remove-Item -force -recurse $oldItem
        }
    }
    Write-Progress -Activity "$activity" -Status "Done" -Completed
} else {
    Write-Output "Tag $CurrentTag found. Skipping."
    exit 0
}

# Download files
foreach ($item in $Files) {
    DownloadFile $item
}

# Download and extract archives
foreach ($item in $Archives.GetEnumerator() | Sort-Object -property key) {
    DownloadArchive $item.Name $item.Value
}

# Save our last known state
Set-Content -Path $tagFile -Value "$CurrentTag"
