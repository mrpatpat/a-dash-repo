@echo off
REM Generate appcast.xml from all studio versions
REM Scans studio/vX.X.X directories and creates complete appcast.xml

setlocal enabledelayedexpansion

cd /d "%~dp0.."

echo ========================================
echo Generating appcast.xml
echo ========================================
echo.

REM Check if studio directory exists
if not exist "studio" (
    echo ERROR: studio directory not found
    exit /b 1
)

REM Create temporary file for items
set TEMP_ITEMS=%TEMP%\appcast_items.xml
if exist "%TEMP_ITEMS%" del "%TEMP_ITEMS%"

REM Find all version directories and sort them in reverse order (newest first)
echo Scanning for studio versions...
set COUNT=0

REM Create temp file with all versions
set TEMP_VERSIONS=%TEMP%\versions.txt
if exist "%TEMP_VERSIONS%" del "%TEMP_VERSIONS%"

REM Collect all version directories
for /f "tokens=*" %%d in ('dir /b /ad studio 2^>nul') do (
    set DIRNAME=%%d
    REM Check if directory name starts with 'v'
    if "!DIRNAME:~0,1!"=="v" (
        set VERSION=!DIRNAME:~1!
        REM Check if installer exists
        if exist "studio\%%d\ADashStudio-!VERSION!-Setup.exe" (
            echo !VERSION!>> "%TEMP_VERSIONS%"
        )
    )
)

REM Check if any versions were found
if not exist "%TEMP_VERSIONS%" (
    echo ERROR: No studio versions found
    exit /b 1
)

REM Sort versions using PowerShell (newest first)
powershell -Command "(Get-Content '%TEMP_VERSIONS%') | Sort-Object {[version]$_} -Descending | Set-Content '%TEMP_VERSIONS%'"

REM Process each version in sorted order
for /f "tokens=*" %%v in (%TEMP_VERSIONS%) do (
    set VERSION=%%v
    set VERSION_DIR=studio\v!VERSION!

    echo Found version: !VERSION!

    REM Get file size
    for %%A in ("!VERSION_DIR!\ADashStudio-!VERSION!-Setup.exe") do set FILESIZE=%%~zA

    REM Get git commit date for this version directory (RFC 2822 format)
    for /f "tokens=*" %%i in ('git log -1 --format^=%%aD --diff-filter^=A -- "!VERSION_DIR!"') do set PUBDATE=%%i

    REM If git date not found (not committed yet), use current date
    if not defined PUBDATE (
        for /f "tokens=*" %%i in ('powershell -Command "Get-Date -Format 'ddd, dd MMM yyyy HH:mm:ss K'"') do set PUBDATE=%%i
    )

    REM Append item to temp file
    (
        echo     ^<item^>
        echo       ^<title^>Version !VERSION!^</title^>
        echo       ^<sparkle:version^>!VERSION!^</sparkle:version^>
        echo       ^<pubDate^>!PUBDATE!^</pubDate^>
        echo       ^<description^>^</description^>
        echo       ^<enclosure
        echo         url="https://raw.githubusercontent.com/mrpatpat/a-dash-repo/refs/heads/main/studio/v!VERSION!/ADashStudio-!VERSION!-Setup.exe"
        echo         sparkle:version="!VERSION!"
        echo         length="!FILESIZE!"
        echo         type="application/octet-stream" /^>
        echo     ^</item^>
        echo.
    ) >> "%TEMP_ITEMS%"

    set /a COUNT+=1
)

REM Clean up versions file
if exist "%TEMP_VERSIONS%" del "%TEMP_VERSIONS%"

if !COUNT! EQU 0 (
    echo ERROR: No studio versions found
    exit /b 1
)

echo.
echo Found !COUNT! version^(s^)
echo.

REM Generate complete appcast.xml
echo Generating appcast.xml...

(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"^>
echo   ^<channel^>
echo     ^<title^>A-Dash Studio Updates^</title^>
echo     ^<link^>https://github.com/mrpatpat/a-dash^</link^>
echo     ^<description^>Most recent updates to A-Dash Studio^</description^>
echo     ^<language^>en^</language^>
echo.
type "%TEMP_ITEMS%"
echo   ^</channel^>
echo ^</rss^>
) > studio\appcast.xml

REM Clean up
del "%TEMP_ITEMS%"

echo.
echo ========================================
echo appcast.xml generated successfully
echo ========================================
echo.
echo File: %CD%\studio\appcast.xml
echo Versions: !COUNT!
echo.

:end
