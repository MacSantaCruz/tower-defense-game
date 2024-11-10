@echo off
echo Creating game package...

:: Clean up any existing packages
del /q client\game.love 2>nul
del /q client\game.zip 2>nul
del /q client\love-win32.zip 2>nul
rmdir /s /q temp 2>nul
rmdir /s /q dist 2>nul

:: Set your game directory - adjust if needed
set GAME_DIR=client

:: Create .love file
cd %GAME_DIR%
echo Creating .love file...

:: Create a staging directory for the game files
mkdir staging

:: Copy ALL .lua files from root directory
echo Copying main game files...
copy *.lua staging\

:: Copy directories
echo Copying directories...
xcopy /E /I /Y "maps" "staging\maps\"
xcopy /E /I /Y "images" "staging\images\"
xcopy /E /I /Y "enemies" "staging\enemies\"
xcopy /E /I /Y "towers" "staging\towers\"
xcopy /E /I /Y "sti" "staging\sti\"

:: Show what we're packaging
echo Files being packaged:
dir /s /b staging

:: Create the .love file
cd staging
powershell -command "Compress-Archive -Force -Path * -DestinationPath ..\game.zip"
cd ..
ren game.zip game.love

:: Clean up staging directory
rmdir /s /q staging

cd ..

:: Create temp directory for LÖVE files
mkdir temp
cd temp

:: Download LÖVE
echo Downloading LÖVE...
curl -L -o love.zip "https://github.com/love2d/love/releases/download/11.4/love-11.4-win32.zip"

:: Extract using PowerShell
echo Extracting LÖVE...
powershell -command "Expand-Archive -Force love.zip ."

:: Copy required files
echo Copying LÖVE files...
copy "love-11.4-win32\love.exe" .
copy "love-11.4-win32\*.dll" .

cd ..

:: Create the executable
echo Creating executable...
copy /b "temp\love.exe"+"client\game.love" "YourGame.exe"

:: Create distribution directory
echo Creating distribution...
mkdir dist
move YourGame.exe dist\
copy "temp\*.dll" dist\

:: Clean up
echo Cleaning up...
rmdir /s /q temp

:: Verify the package contents
echo Verifying .love contents:
powershell -command "Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip = [System.IO.Compression.ZipFile]::OpenRead('client\game.love'); $zip.Entries.FullName; $zip.Dispose()"

:: Check file sizes
for %%I in (client\game.love) do echo game.love size: %%~zI bytes
for %%I in (dist\YourGame.exe) do echo YourGame.exe size: %%~zI bytes

echo Package created in dist directory!
pause