@echo off
title UBISAFE Launcher
color 0A
echo.
echo  ==========================================
echo   UBISAFE - Iniciando todos los servicios
echo  ==========================================
echo.

REM ---- 1. Firebase Emulators ----
echo [1/3] Abriendo Firebase Emulators...
start "Firebase Emulators" cmd /k "title Firebase Emulators && cd /d C:\Users\ultra\Documents\Ingenieria\Semestre_Actual\TSP\Codigo\UBISAFE && firebase emulators:start --project demo-ubisafe"

echo      Esperando 10 segundos para que levanten los emuladores...
timeout /t 10 /nobreak > nul

REM ---- 2. FastAPI Backend ----
echo [2/3] Abriendo FastAPI backend...
start "FastAPI Backend" cmd /k "title FastAPI Backend && cd /d C:\Users\ultra\Documents\Ingenieria\Semestre_Actual\TSP\Codigo\UBISAFE\ubisafe_api && call .venv\Scripts\activate && python -m uvicorn main:app --reload"

echo      Esperando 4 segundos...
timeout /t 4 /nobreak > nul

REM ---- 3. ADB Reverse (para dispositivo fisico) ----
echo [3/3] Configurando ADB reverse...
adb reverse tcp:9099 tcp:9099 2>nul || echo      (adb no encontrado o sin dispositivo conectado, continua de todas formas)
adb reverse tcp:8080 tcp:8080 2>nul
adb reverse tcp:9000 tcp:9000 2>nul
adb reverse tcp:8000 tcp:8000 2>nul

REM ---- 4. Flutter App ----
echo      Abriendo Flutter app...
start "Flutter App" cmd /k "title Flutter App && cd /d C:\Users\ultra\Documents\Ingenieria\Semestre_Actual\TSP\Codigo\UBISAFE\ubisafe_app && flutter run"

echo.
echo  ==========================================
echo   Todo listo! Se abrieron 3 ventanas:
echo     - Firebase Emulators  (UI: localhost:4000)
echo     - FastAPI Backend     (Docs: localhost:8000/docs)
echo     - Flutter App
echo  ==========================================
echo.
pause
