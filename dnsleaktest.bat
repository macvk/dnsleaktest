@echo off

rem Any questions: tutumbul@gmail.com
rem https://bash.ws/dnsleak

set "result_file=%TEMP%\dnsleaktest-%RANDOM%-%RANDOM%.txt"

powershell -NoProfile -Command "& { $ProgressPreference = 'SilentlyContinue'; $ErrorActionPreference = 'Stop'; $leakId = (Invoke-WebRequest -UseBasicParsing 'https://bash.ws/id').Content.Trim(); $tasks = 1..30 | ForEach-Object { [System.Net.Dns]::GetHostAddressesAsync(('{0}.{1}.bash.ws' -f $_,$leakId)) }; try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$tasks,2500) } catch {}; Invoke-WebRequest -UseBasicParsing ('https://bash.ws/dnsleak/test/{0}?txt' -f $leakId) -OutFile '%result_file%' }"

if errorlevel 1 (
    echo DNS leak test failed.
    exit /b 1
)

echo Your IP:
for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "ip" (
        if [%%1] neq [] (
            if [%%3] neq [] (
                if [%%4] neq [] (
                    echo %%1 [%%3, %%4]
                ) else (
                    echo %%1 [%%3]
                )
            ) else (
                echo %%1
            )
        ) 
    )
)

set /a servers=0

for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "dns" (
        set /a servers=servers+1
    )
)

if "%servers%" == "0" (
    echo No DNS servers found
) else (
    echo You use %servers% DNS servers:
    for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
        if "%%5" == "dns" (
            if [%%1] neq [] (
                if [%%3] neq [] (
                    if [%%4] neq [] (
                        echo %%1 [%%3, %%4]
                    ) else (
                        echo %%1 [%%3]
                    )
                ) else (
                    echo %%1
                )
            ) 
        )
    )
)

echo Conclusion:
for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "conclusion" (
        if [%%1] neq [] (
            echo %%1
        ) 
    )
)

del /q "%result_file%"
