@echo off
setlocal

cd /d "%~dp0"
set "PORT=8081"
set "URL=http://localhost:%PORT%/Accounts/Cards/card_database.html"
set "ROOT=%~dp0..\.."

start "" "%URL%"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0start_card_dashboard_server.ps1','-Port','%PORT%','-Root','%ROOT%') -WorkingDirectory '%ROOT%' -WindowStyle Hidden"
