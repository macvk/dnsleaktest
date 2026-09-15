@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem DNS leak test client for bash.ws.
rem Project: https://github.com/macvk/dnsleaktest
rem SPDX-License-Identifier: MIT

set "program_name=%~nx0"
set "interface="
set "verbose="
set "log_file="
set "probes=30"
set "parallel=30"
set "short_output=0"
set "watch=0"
set "result_file=%TEMP%\dnsleaktest-%RANDOM%-%RANDOM%.txt"

:parse_arguments
if "%~1" == "" goto arguments_parsed

if /I "%~1" == "-i" goto read_interface
if /I "%~1" == "--interface" goto read_interface
if /I "%~1" == "-p" goto read_probes
if /I "%~1" == "--probes" goto read_probes
if /I "%~1" == "-j" goto read_parallel
if /I "%~1" == "--parallel" goto read_parallel
if /I "%~1" == "-s" goto enable_short
if /I "%~1" == "--short" goto enable_short
if /I "%~1" == "-w" goto read_watch
if /I "%~1" == "--watch" goto read_watch
if /I "%~1" == "-v" goto read_verbose
if /I "%~1" == "--verbose" goto read_verbose
if /I "%~1" == "--log-file" goto read_log_file
if /I "%~1" == "-h" goto show_help
if /I "%~1" == "--help" goto show_help

call :argument_error "Unknown option: %~1"
exit /b 2

:read_interface
if "%~2" == "" (
    call :argument_error "Option %~1 requires a source IP address."
    exit /b 2
)
set "interface=%~2"
shift
shift
goto parse_arguments

:read_probes
if "%~2" == "" (
    call :argument_error "Option %~1 requires a number."
    exit /b 2
)
set "probes=%~2"
shift
shift
goto parse_arguments

:enable_short
set "short_output=1"
shift
goto parse_arguments
    
:enable_short
set "short_output=1"
shift
goto parse_arguments

:read_watch
if "%~2" == "" (
    call :argument_error "Option %~1 requires a number of seconds."
    exit /b 2
)
set "watch=%~2"
set "short_output=1"
shift       
shift       
goto parse_arguments
    
:read_parallel
if "%~2" == "" (
    call :argument_error "Option %~1 requires a number."
    exit /b 2
)
set "parallel=%~2"
shift
shift
goto parse_arguments
            
:read_verbose
if "%~2" == "" (
    call :argument_error "Option %~1 requires info or trace."
    exit /b 2
)
set "verbose=%~2"
shift
shift
goto parse_arguments
    
:read_log_file
if "%~2" == "" (
    call :argument_error "Option --log-file requires a path."
    exit /b 2
)   
set "log_file=%~2"
shift
shift   
goto parse_arguments
    
:arguments_parsed
powershell -NoProfile -Command "if ($env:probes -notmatch '^[1-9][0-9]*$' -or [int]$env:probes -gt 100) { exit 1 }"

if errorlevel 1 (
    call :argument_error "Invalid probe count '%probes%'; expected an integer from 1 to 100."
    exit /b 2
)

if not "%watch%" == "0" (
    powershell -NoProfile -Command "if ($env:watch -notmatch '^[1-9][0-9]*$' -or [int]$env:watch -lt 10) { exit 1 }"
    
    if errorlevel 1 (
        call :argument_error "Invalid watch interval '%watch%'; expected at least 10 seconds."
        exit /b 2
    )
)

powershell -NoProfile -Command "if ($env:parallel -notmatch '^[1-9][0-9]*$' -or [int]$env:parallel -gt 100) { exit 1 }"

if errorlevel 1 (
    call :argument_error "Invalid parallel count '%parallel%'; expected an integer from 1 to 100."
    exit /b 2
)

if defined verbose (
    if /I not "%verbose%" == "info" (
        if /I not "%verbose%" == "trace" (
            call :argument_error "Invalid verbosity level '%verbose%'; expected info or trace."
            exit /b 2
        )
    )
)

if defined log_file (
    if not defined verbose set "verbose=info"
)

if defined verbose (
    if not defined log_file (
        if defined LOCALAPPDATA (
            set "log_file=%LOCALAPPDATA%\dnsleaktest\dnsleaktest.log"
        ) else (
            set "log_file=%USERPROFILE%\AppData\Local\dnsleaktest\dnsleaktest.log"
        )
    )

    for %%D in ("!log_file!\..") do set "log_dir=%%~fD"

    if not exist "!log_dir!" mkdir "!log_dir!" 2>nul

    if not exist "!log_dir!" (
        call :argument_error "Cannot create diagnostic log directory: !log_dir!"
        exit /b 2
    )

    type nul >> "!log_file!"

    if errorlevel 1 (
        call :argument_error "Cannot create diagnostic log: !log_file!"
        exit /b 2
    )

    if not "%DNSLEAK_WATCH_CHILD%" == "1" echo Diagnostic log: !log_file!
)

call :log_info "dnsleaktest started; OS=Windows; requested_interface=%interface%; probes=%probes%; parallel=%parallel%"

where curl.exe >nul 2>&1

if errorlevel 1 (
    call :fail "curl.exe is required."
    exit /b 1
)

call :log_info "Requesting test ID"

if /I "%verbose%" == "trace" (
    if defined interface (
        for /f "usebackq delims=" %%I in (`curl.exe --verbose --silent --show-error --fail --interface "%interface%" "https://bash.ws/id" 2^>^>"%log_file%"`) do set "leak_id=%%I"
    ) else (
        for /f "usebackq delims=" %%I in (`curl.exe --verbose --silent --show-error --fail "https://bash.ws/id" 2^>^>"%log_file%"`) do set "leak_id=%%I"
    )
) else (
    if defined interface (
        for /f "usebackq delims=" %%I in (`curl.exe --silent --show-error --fail --interface "%interface%" "https://bash.ws/id"`) do set "leak_id=%%I"
    ) else (
        for /f "usebackq delims=" %%I in (`curl.exe --silent --show-error --fail "https://bash.ws/id"`) do set "leak_id=%%I"
    )
)

if not defined leak_id (
    call :fail "Unable to obtain a test ID from bash.ws."
    exit /b 1
)

call :log_info "Test ID received; bytes available"

if defined interface (
    call :log_info "Starting %probes% DNS probes with source IP %interface%"

    powershell -NoProfile -Command "& { for ($start = 1; $start -le %probes%; $start += %parallel%) { $end = [Math]::Min($start + %parallel% - 1, %probes%); $procs = $start..$end | ForEach-Object { $hostName = ('{0}.%leak_id%.bash.ws' -f $_); Start-Process ping.exe -ArgumentList @('-n','1','-w','1000','-S','%interface%',$hostName) -WindowStyle Hidden -PassThru }; $procs | Wait-Process -Timeout 3 -ErrorAction SilentlyContinue; $procs | Where-Object { -not $_.HasExited } | Stop-Process -Force } }"
) else (
    call :log_info "Starting %probes% DNS probes with the default route"

    powershell -NoProfile -Command "& { for ($start = 1; $start -le %probes%; $start += %parallel%) { $end = [Math]::Min($start + %parallel% - 1, %probes%); $tasks = $start..$end | ForEach-Object { [System.Net.Dns]::GetHostAddressesAsync(('{0}.%leak_id%.bash.ws' -f $_)) }; try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$tasks,2500) } catch {} } }"
)

if errorlevel 1 (
    call :fail "DNS probes failed."
    exit /b 1
)

call :log_info "Requesting text results"

if /I "%verbose%" == "trace" (
    if defined interface (
        curl.exe --verbose --silent --show-error --fail --interface "%interface%" "https://bash.ws/dnsleak/test/%leak_id%?txt" --output "%result_file%" 2>>"%log_file%"
    ) else (
        curl.exe --verbose --silent --show-error --fail "https://bash.ws/dnsleak/test/%leak_id%?txt" --output "%result_file%" 2>>"%log_file%"
    )
) else (
    if defined interface (
        curl.exe --silent --show-error --fail --interface "%interface%" "https://bash.ws/dnsleak/test/%leak_id%?txt" --output "%result_file%"
    ) else (
        curl.exe --silent --show-error --fail "https://bash.ws/dnsleak/test/%leak_id%?txt" --output "%result_file%"
    )
)

if errorlevel 1 (
    call :fail "Unable to retrieve DNS leak test results."
    exit /b 1
)

if "%short_output%" == "1" goto short_result


echo Your IP:

for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "ip" (
        if not "%%1" == "" (
            call :print_address "%%1" "%%3" "%%4"
            call :log_info "public_ip=%%1; country=%%3; asn=%%4"
        )
    )
)

set /a servers=0

for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "dns" set /a servers+=1
)

if "!servers!" == "0" (
    echo No DNS servers found
) else (
    if "!servers!" == "1" (
        echo You use 1 DNS server:
    ) else (
        echo You use !servers! DNS servers:
    )

    for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
        if "%%5" == "dns" (
            if not "%%1" == "" (
                call :print_address "%%1" "%%3" "%%4"
                call :log_info "dns_server=%%1; country=%%3; asn=%%4"
            )
        )
    )
)

echo Conclusion:
set "conclusion="

for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "conclusion" (
        if not "%%1" == "" (
            set "conclusion=%%1"
            echo %%1
        )
    )
)

call :log_info "conclusion=!conclusion!"

echo(!conclusion! | findstr /I /C:"not leaking" /C:"no leak" >nul

if not errorlevel 1 (
    set "test_result=no_leak"
) else (
    echo(!conclusion! | findstr /I /C:"may be leaking" /C:"leak detected" >nul

    if not errorlevel 1 (
        set "test_result=leak_detected"
    ) else (
        set "test_result=unknown"
    )
)

call :log_info "result=!test_result!"
call :log_info "dnsleaktest finished; dns_servers=!servers!; exit=0"

del /q "%result_file%" >nul 2>&1
exit /b 0

:short_result
set /a servers=0
set "conclusion="

for /f "usebackq tokens=1,2,3,4,5 delims=|" %%1 in ("%result_file%") do (
    if "%%5" == "dns" set /a servers+=1
    if "%%5" == "conclusion" set "conclusion=%%1"
)

echo(!conclusion! | findstr /I /C:"not leaking" /C:"no leak" >nul

if not errorlevel 1 (
    set "test_result=no_leak"
) else (
    echo(!conclusion! | findstr /I /C:"may be leaking" /C:"leak detected" >nul
    if not errorlevel 1 (set "test_result=leak_detected") else (set "test_result=unknown")
)

echo %date%T%time% !test_result!
call :log_info "conclusion=!conclusion!"
call :log_info "result=!test_result!"
call :log_info "dnsleaktest finished; dns_servers=!servers!; exit=0"
del /q "%result_file%" >nul 2>&1

if "%watch%" == "0" exit /b 0

set "watch_args=-s -p %probes% -j %parallel%"

if defined interface set "watch_args=!watch_args! -i "!interface!""
if defined verbose set "watch_args=!watch_args! -v !verbose!"
if defined log_file set "watch_args=!watch_args! --log-file "!log_file!""

:watch_loop
timeout /t %watch% /nobreak >nul
set "DNSLEAK_WATCH_CHILD=1"
call "%~f0" !watch_args!
goto watch_loop

:print_address
if not "%~3" == "" (
    echo %~1 [%~2, %~3]
) else if not "%~2" == "" (
    echo %~1 [%~2]
) else (
    echo %~1
)
exit /b 0

:log_info
if not defined verbose exit /b 0
>>"!log_file!" echo %date%T%time% [INFO] %~1
exit /b 0

:argument_error
echo %~1 1>&2
echo Try '%program_name% --help' for more information. 1>&2
exit /b 0

:fail
echo %~1 1>&2
call :log_info "ERROR: %~1"
del /q "%result_file%" >nul 2>&1
exit /b 1

:show_help
echo Usage: %program_name% [OPTIONS]
echo.
echo Options:
echo   -i, --interface IP        Use a specific source IP address
echo   -p, --probes NUMBER      Number of DNS probes to send ^(default: 30^)
echo   -j, --parallel NUMBER    Maximum simultaneous probes ^(default: 30^)
echo   -s, --short              Print a one-line result
echo   -w, --watch SECONDS      Repeat in short mode ^(minimum: 10 seconds^)
echo   -v, --verbose LEVEL      Write diagnostics: info or trace
echo       --log-file FILE      Set the log path ^(implies --verbose info^)
echo   -h, --help               Show this help
exit /b 0
