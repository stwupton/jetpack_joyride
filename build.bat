@REM Build 
odin build                                          ^
    ./src                                           ^
    -debug                                          ^
    -out:./build/jetpack-joyride.exe                ^
    -collection:jetpack_joyride=src/jetpack_joyride ^
    -collection:common=src/common

@REM Copy Assets
xcopy assets build\assets /s /y /d

@REM Copy libraries
xcopy SDL2.dll build\SDL2.dll /y /d