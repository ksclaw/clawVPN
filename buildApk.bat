@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo =======================================================
echo         ClawVPN Android 自动打包脚本 (Meta Debug)
echo =======================================================

:: 0. 提示用户输入自定义的 Config URL
set "configUrl="
set /p configUrl=请输入您的后端中控 Config URL (按回车直接使用默认值 https://vungles.com/api/test/): 

if "!configUrl!"=="" (
    echo [Info] 未输入，将使用默认配置服务器。
) else (
    echo [Info] 准备将 Config URL 替换为: !configUrl!
    set "API_CLIENT_FILE=Android-kotlin-Code\design\src\main\java\com\github\kr328\clash\design\network\ApiClient.kt"
    
    :: 使用 PowerShell 正则替换 ConfigURL，确保多次运行依然有效
    powershell -Command "$file='!API_CLIENT_FILE!'; $url='!configUrl!'; $q=[char]34; (Get-Content $file -Encoding UTF8) -replace ('private const val ConfigURL = '+$q+'.*?'+$q), ('private const val ConfigURL = '+$q+$url+$q) | Set-Content $file -Encoding UTF8"
    
    if !errorlevel! neq 0 (
        echo [Error] 替换 Config URL 失败，请检查文件是否存在或权限问题！
        pause
        exit /b 1
    )
    echo [Info] URL 替换成功！
)

:: 1. 配置 JDK 18
echo [Info] 配置 Java 环境...
set "JAVA_HOME=D:\jdk-18.0.2.1"
set "PATH=%JAVA_HOME%\bin;%PATH%"
java -version
if %errorlevel% neq 0 (
    echo [Error] JDK 配置失败，请检查 D:\jdk-18.0.2.1 是否存在！
    pause
    exit /b 1
)

:: 2. 检查 Go 环境
echo [Info] 检查 Go 环境并配置国内镜像...
set "GOPROXY=https://goproxy.cn,direct"
go version
if %errorlevel% neq 0 (
    echo [Error] Go 未安装或未添加到环境变量中！
    pause
    exit /b 1
)

:: 3. 准备隔离的 Android SDK 环境
set "ANDROID_SDK_DIR=%~dp0.android_sdk"
set "ANDROID_HOME=%ANDROID_SDK_DIR%"
set "CMDLINE_TOOLS_BIN=%ANDROID_SDK_DIR%\cmdline-tools\latest\bin"

if not exist "%CMDLINE_TOOLS_BIN%\sdkmanager.bat" (
    echo [Info] 首次运行：正在下载 Android Command Line Tools...
    mkdir "%ANDROID_SDK_DIR%" 2>nul
    curl -# -o "%ANDROID_SDK_DIR%\cmdline-tools.zip" https://dl.google.com/android/repository/commandlinetools-win-11479570_latest.zip
    
    if not exist "%ANDROID_SDK_DIR%\cmdline-tools.zip" (
        echo [Error] 下载命令行工具失败！
        pause
        exit /b 1
    )

    echo [Info] 正在解压...
    powershell -Command "Expand-Archive -Path '%ANDROID_SDK_DIR%\cmdline-tools.zip' -DestinationPath '%ANDROID_SDK_DIR%\cmdline-tools_temp' -Force"
    
    mkdir "%ANDROID_SDK_DIR%\cmdline-tools\latest" 2>nul
    xcopy /E /I /Y "%ANDROID_SDK_DIR%\cmdline-tools_temp\cmdline-tools\*" "%ANDROID_SDK_DIR%\cmdline-tools\latest\" >nul
    
    rmdir /S /Q "%ANDROID_SDK_DIR%\cmdline-tools_temp"
    del "%ANDROID_SDK_DIR%\cmdline-tools.zip"
)

:: 4. 自动同意许可并安装必需的组件
echo [Info] 自动同意 Android SDK 许可协议...
echo y | call "%CMDLINE_TOOLS_BIN%\sdkmanager.bat" --licenses >nul 2>&1

echo [Info] 检查并安装所需的 SDK/NDK/CMake 组件 (这可能需要几分钟)...
call "%CMDLINE_TOOLS_BIN%\sdkmanager.bat" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;27.0.12077973" "cmake;3.22.1"

:: 5. 执行 Gradle 打包
echo [Info] 开始编译 APK (Meta 架构)...
cd Android-kotlin-Code
call gradlew.bat :app:assembleMetaDebug

if %errorlevel% neq 0 (
    echo.
    echo [Error] 编译失败！请检查上方报错信息。
    pause
    exit /b %errorlevel%
)

:: 6. 将 APK 复制到项目根目录
echo [Info] 编译成功，正在提取 APK...
cd ..
copy /Y /B "Android-kotlin-Code\app\build\outputs\apk\meta\debug\*universal*.apk" "clawVPN_MetaDebug_Universal.apk"

echo.
echo =======================================================
echo [Success] 打包完成！APK 已保存在项目根目录下: clawVPN_MetaDebug_Universal.apk
echo =======================================================
pause
