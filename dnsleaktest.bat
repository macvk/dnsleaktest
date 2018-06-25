@echo off

for /F "tokens=*" %%g IN ('powershell -command "& { Get-Random -Minimum 1000000 -Maximum 9999999 }"') do (set /a leak_id=%%g)

rem echo %leak_id%

for /L %%g IN (1,1,10) do ping %%g.%leak_id%.bash.ws > nul

powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://bash.ws/dnsleak/test/%leak_id%?txt', '%leak_id%.txt') }"

echo Detected DNS servers:
for /f "tokens=1,2,3 delims=|" %%1 in (%leak_id%.txt) do echo %%1 (%%3)

del /q %leak_id%.txt