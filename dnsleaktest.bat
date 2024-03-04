@echo off

rem Any questions: tutumbul@gmail.com
rem https://bash.ws/dnsleak

for /f "delims=" %%a in (' powershell -command "& { (Invoke-WebRequest 'https://bash.ws/id').Content }"') do set "leak_id=%%a"

rem echo %leak_id%

for /L %%g IN (1,1,10) do ping %%g.%leak_id%.bash.ws > nul

powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://bash.ws/dnsleak/test/%leak_id%?txt', '%leak_id%.txt') }"

echo Your IP:
for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
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

for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
    if "%%5" == "dns" (
        set /a servers=servers+1
    )
)

if "%servers%" == "0" (
    echo No DNS servers found
) else (
    echo You use %servers% DNS servers:
    for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
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
for /f "tokens=1,2,3,4,5 delims=|" %%1 in (%leak_id%.txt) do (
    if "%%5" == "conclusion" (
        if [%%1] neq [] (
            echo %%1
        ) 
    )
)

del /q %leak_id%.txt