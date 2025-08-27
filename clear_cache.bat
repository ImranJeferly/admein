@echo off
echo Clearing Flutter Windows App Cache...

REM Clear Flutter build cache
echo Clearing Flutter build cache...
flutter clean

REM Clear local app data directories
echo Clearing app data directories...
if exist "%LOCALAPPDATA%\admain" rmdir /s /q "%LOCALAPPDATA%\admain"
if exist "%APPDATA%\admain" rmdir /s /q "%APPDATA%\admain"

REM Clear any Flutter/Dart cache related to this app
if exist "%LOCALAPPDATA%\Pub" echo Found Pub cache at %LOCALAPPDATA%\Pub
if exist "%APPDATA%\Pub" echo Found Pub cache at %APPDATA%\Pub

REM Clear any SQLite databases in common locations
for /d %%d in ("%LOCALAPPDATA%\*flutter*") do (
    if exist "%%d\admain.db" (
        echo Found database: %%d\admain.db
        del "%%d\admain.db"
    )
)

REM Clear SharedPreferences (typically in Registry or files)
echo Note: SharedPreferences on Windows are usually stored in Registry
echo You may need to manually clear Registry entries under HKEY_CURRENT_USER\Software\Flutter if needed

REM Get dependencies again
echo Getting Flutter dependencies...
flutter pub get

echo Cache clearing complete!
echo Run "flutter run -d windows" to start fresh
pause