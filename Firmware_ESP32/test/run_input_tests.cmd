@call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
@if errorlevel 1 exit /b 1
@pushd "%~dp0.."
@if not exist .pio mkdir .pio
@cl /nologo /EHsc /Fo.pio\input_latch_test.obj /Fe.pio\input_latch_test.exe test\input_latch_test.cpp
@if errorlevel 1 goto failed
@.pio\input_latch_test.exe
@if errorlevel 1 goto failed
@powershell -NoProfile -ExecutionPolicy Bypass -File test\extract_navigation.ps1
@if errorlevel 1 goto failed
@cl /nologo /EHsc /Fo.pio\navigation_test.obj /Fe.pio\navigation_test.exe test\navigation_test.cpp
@if errorlevel 1 goto failed
@.pio\navigation_test.exe
@if errorlevel 1 goto failed
@popd
@exit /b 0
:failed
@popd
@exit /b 1
