@echo off
title Verificador de Seriais - Antes/Depois
setlocal enabledelayedexpansion

:: Verifica se está a correr como Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requer privilégios de Administrador.
    echo A reiniciar com elevação...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo   VERIFICADOR DE SERIAIS - ANTES E DEPOIS DA LIMPEZA
echo ============================================================
echo.

:: Função para obter os valores via PowerShell e guardar em variáveis
:obter_valores
set "MAC="
set "VSN="
set "BIOS="
set "UUID="
set "BASEBOARD="
set "MACHINEGUID="

:: MachineGuid
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction SilentlyContinue).MachineGuid" 2^>nul') do set "MACHINEGUID=%%i"

:: MAC Address atual (primeiro adaptador físico com IP)
for /f "delims=" %%i in ('powershell -NoProfile -Command "$a = Get-NetAdapter -Physical -ErrorAction SilentlyContinue ^| Where-Object { $_.Status -eq 'Up' } ^| Select-Object -First 1; if (-not $a) { $a = Get-NetAdapter -Physical -ErrorAction SilentlyContinue ^| Select-Object -First 1 }; if ($a) { $a.MacAddress } else { 'N/A' }" 2^>nul') do set "MAC=%%i"

:: Volume Serial Number do C: (via boot sector, ou usar vol)
for /f "delims=" %%i in ('powershell -NoProfile -Command "$s=New-Object System.IO.FileStream('\\.\C:',[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read,512); try{$b=New-Object byte[]512;[void]$s.Read($b,0,512);$o=-1;$oem=[System.Text.Encoding]::ASCII.GetString($b,3,8);if($oem -like 'NTFS*'){$o=0x48}elseif([System.Text.Encoding]::ASCII.GetString($b,82,8) -like 'FAT32*'){$o=0x43}elseif([System.Text.Encoding]::ASCII.GetString($b,54,8) -match 'FAT'){$o=0x27};if($o -ge 0){'{0:X2}{1:X2}{2:X2}{3:X2}' -f $b[$o],$b[$o+1],$b[$o+2],$b[$o+3]}else{'N/A'}}finally{$s.Close()}" 2^>nul') do set "VSN=%%i"

:: BIOS Serial
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber" 2^>nul') do set "BIOS=%%i"

:: System UUID
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID" 2^>nul') do set "UUID=%%i"

:: Baseboard Serial
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-WmiObject Win32_BaseBoard -ErrorAction SilentlyContinue).SerialNumber" 2^>nul') do set "BASEBOARD=%%i"

goto :eof

:: --------------------- ANTES ---------------------
echo [ANTES DA LIMPEZA]
echo -------------------
call :obter_valores
echo MachineGuid:   %MACHINEGUID%
echo MAC Address:   %MAC%
echo VSN (C:):      %VSN%
echo BIOS Serial:   %BIOS%
echo System UUID:   %UUID%
echo Baseboard Ser: %BASEBOARD%
echo.
echo ============================================================
echo.

:: Guarda os valores ANTES para comparação
set "antes_MACHINEGUID=%MACHINEGUID%"
set "antes_MAC=%MAC%"
set "antes_VSN=%VSN%"
set "antes_BIOS=%BIOS%"
set "antes_UUID=%UUID%"
set "antes_BASEBOARD=%BASEBOARD%"

:: Pergunta se já correu o programa
:pergunta
set /p "continuar=Já correu a limpeza no app? (S/N): "
if /i "%continuar%"=="S" goto pos
if /i "%continuar%"=="N" (
    echo.
    echo Execute o programa "Clean" agora.
    echo Depois volte aqui e prima qualquer tecla para verificar os NOVOS valores.
    pause >nul
    goto pos
)
echo Resposta inválida. Digite S ou N.
goto pergunta

:pos
echo.
echo [DEPOIS DA LIMPEZA]
echo -------------------
call :obter_valores
echo MachineGuid:   %MACHINEGUID%
echo MAC Address:   %MAC%
echo VSN (C:):      %VSN%
echo BIOS Serial:   %BIOS%
echo System UUID:   %UUID%
echo Baseboard Ser: %BASEBOARD%
echo.
echo ============================================================
echo.

:: Comparação
echo [COMPARAÇÃO]
echo ------------
set "changed=0"
if not "!antes_MACHINEGUID!"=="%MACHINEGUID%" ( echo MachineGuid   -> ALTERADO & set "changed=1" ) else ( echo MachineGuid   -> IGUAL )
if not "!antes_MAC!"=="%MAC%" ( echo MAC Address   -> ALTERADO & set "changed=1" ) else ( echo MAC Address   -> IGUAL )
if not "!antes_VSN!"=="%VSN%" ( echo VSN (C:)      -> ALTERADO & set "changed=1" ) else ( echo VSN (C:)      -> IGUAL )
if not "!antes_BIOS!"=="%BIOS%" ( echo BIOS Serial   -> ALTERADO & set "changed=1" ) else ( echo BIOS Serial   -> IGUAL )
if not "!antes_UUID!"=="%UUID%" ( echo System UUID   -> ALTERADO & set "changed=1" ) else ( echo System UUID   -> IGUAL )
if not "!antes_BASEBOARD!"=="%BASEBOARD%" ( echo Baseboard Ser  -> ALTERADO & set "changed=1" ) else ( echo Baseboard Ser  -> IGUAL )

echo.
if %changed%==1 (
    echo [OK] Pelo menos um valor foi alterado.
) else (
    echo [ATENCAO] Nenhum valor foi alterado. Verifique se o programa foi executado corretamente.
)
echo.
echo ============================================================
pause
exit /b