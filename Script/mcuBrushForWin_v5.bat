@echo off
chcp 65001

@REM 判断adb是否连接成功
for /f "tokens=2 skip=1" %%i in ('adb devices') do (
    goto brush
)

color 4
echo "[FATAL]请重新反面插入Typec"
goto end

:brush
setlocal enabledelayedexpansion
set scriptFileName=%~nx0
set versionFile=.gitversion
set md5File=.md5version
set appFile=mcu/C385_App.s19
set mcuFile=%~dp0%appFile%
set mergeFile=.mergeVersion
set checkFile=file2check
set mcuScript=.readmcu.sh

@REM 切换为root用户
call:switchRoot

@REM 记录刷写时间、主机名和IP,显示版本信息
call:recordBrushInfo

@REM 开始mcu刷写
call:mcuBrush

:end
pause
exit


@REM #############################以下是函数定义#################################
@REM /**
@REM  * @description: 如果不是root模式,切换为root模式,如果是,则跳过
@REM  */
:switchRoot
echo "[INFO]自动切换为root模式"
for /f "tokens=*" %%i in ('adb push %scriptFileName% /home/root') do (
    set allRes=%%i
    for /f %%j in ('echo !allRes! ^| find "remote Permission denied"') do (
        adb usb 8155@zongmutech
        timeout /T 3 /NOBREAK
    )
)
goto:eof

@REM /**
@REM  * @description: 推送ota文件开始mcu刷写
@REM  * @return：如果ota文件不存在则报错
@REM  */
:mcuBrush
if exist "%mcuFile%" (
    echo "[INFO]开始mcu软件刷写"
    adb push %mcuFile% /data
    adb shell "mount -o rw,remount /"
    adb shell "cd /zros/bin && chmod a+x ota_test"
    for /f %%i in ('adb shell "cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test active_check 2>&1 | sed -n 's/.*is\( [0-9]\).*/\1/p'"') do (
        set firstBeforePart=%%i
    )

    adb shell "cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test integration_test_with_mcu"

    call:judgeDeviceExist firstCheck
) else (
    color 4
    echo "[FATAL]%appFile% 文件不存在"
    goto end
)
goto:eof

@REM /**
@REM  * @description: 第一次刷写检查,并在最后进行诊断,如果诊断失败,则重新执行当前函数
@REM  */
:firstCheck
for /f %%i in ('adb shell "cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test active_check 2>&1 | sed -n 's/.*is\( [0-9]\).*/\1/p'"') do (
    set firstAfterPart=%%i
)

@REM 执行双检测机制,如果第一次查询分区没变,则进行第二次查询
if !firstBeforePart! equ !firstAfterPart! (
    for /f %%i in ('adb shell "sleep 3 && cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test active_check 2>&1 | sed -n 's/.*is\( [0-9]\).*/\1/p'"') do (
        set firstRetryPart=%%i
    )
) else (
    set firstRetryPart=!firstAfterPart!
)

adb shell "sleep 3 && cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test integration_test_with_mcu"

@REM 添加设备诊断
call:deviceDiagnose firstCheck

call:judgeDeviceExist secondCheck
goto:eof

@REM /**
@REM  * @description: 第二次刷写检查,并在最后进行诊断,如果诊断失败,则重新执行当前函数
@REM  */
:secondCheck
for /f %%i in ('adb shell "cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test active_check 2>&1 | sed -n 's/.*is\( [0-9]\).*/\1/p'"') do (
    set secondAfterPart=%%i
)

@REM 执行双检测机制,如果第一次查询分区没变,则进行第二次查询
if !firstRetryPart! equ !secondAfterPart! (
    for /f %%i in ('adb shell "sleep 3 && cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test active_check 2>&1 | sed -n 's/.*is\( [0-9]\).*/\1/p'"') do (
        set secondRetryPart=%%i
    )
) else (
    set secondRetryPart=!secondAfterPart!
)
adb shell "if [ -e /home/root/%scriptFileName% ];then rm /home/root/%scriptFileName%;fi"
call:deviceDiagnose secondCheck

call:getBrushResult
goto:eof

@REM /**
@REM  * @description: 获取mcu刷写结果
@REM  */
:getBrushResult
echo "第1次刷写之前分区为:!firstBeforePart!"
echo "第1次刷写之后分区为:!firstRetryPart!"
if !firstBeforePart! equ !firstRetryPart! (
    echo "####第一次刷写失败####"
    echo "                      "
) else (
    echo "####第一次刷写成功####"
    echo "                      "
)

echo "第2次刷写之前分区为:!firstRetryPart!"
echo "第2次刷写之后分区为:!secondRetryPart!"
if !firstRetryPart! equ !secondRetryPart! (
    echo "####第二次刷写失败####"
) else (
    echo "####第二次刷写成功####"
)
goto:end
goto:eof

@REM /**
@REM  * @description: 设备诊断,以防运行过程中设备挂掉,重新运行当前函数
@REM  */
:deviceDiagnose
for /f "skip=1" %%i in ('adb devices ^| find "device"') do (
    goto:eof
)
echo "[ERROR]第二次刷写过程中设备挂掉,需重新上下电挂载设备"
call:judgeDeviceExist %1
goto:eof

@REM /**
@REM  * @description: 判断设备是否存在,如果不存在,每间隔3S循环搜索一次
@REM  */
:judgeDeviceExist
timeout /T 3 /NOBREAK
for /f "skip=1" %%i in ('adb devices ^| find "device"') do (
    echo "[INFO]第一次检测到设备,准备进行第二次检测: %%i"
    timeout /T 3 /NOBREAK
    for /f "skip=1" %%i in ('adb devices ^| find "device"') do (
        echo "[INFO]第二次检测到设备,切换root模式: %%i"
        call:switchRoot
        if "%1" == "firstCheck" (
            call:firstCheck
        ) else (
            call:secondCheck
        )
    )
    echo "[WARNING]第一次误检测,正在搜索设备,请稍等~~"
    call:judgeDeviceExist %1
)
echo "[INFO]正在搜索设备,请稍等"
call:judgeDeviceExist %1
goto:eof

@REM /**
@REM  * @description: 记录刷写时间IP和地址
@REM  */
:recordBrushInfo
for /f %%a in ('WMIC OS GET LocalDateTime ^| FIND "."') do (
    set DTS=%%a
)
set DateTime=%DTS:~0,14%

set counter=0
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| find "IPv4"') do (
    set /a counter+=1

    if !counter! equ 1 (
        set ipAddress=%%i
    )
)

for /f %%a in ('hostname') do (
    set hostName=%%a
)

@REM 获取git安装路径
for /f %%a in ('where git') do (
    set gitPath=%%a
)

if defined gitPath (
    set gitRootPath=%gitPath:~0,-12%
    echo !gitRootPath!

    if exist ".git" (
        @REM 获取mcu版本
        set counter=0
        for /f "tokens=1 delims=-" %%a in ('git log -n 10 ^| find /I "mcu"') do (
            set /a counter+=1

            if !counter! equ 1 (
                echo "当前mcu版本为:%%a"
                set mcuVersion=%%a
            )
        )

        for /f %%a in ('git rev-parse --short HEAD') do (
            set commitId=%%a
        )

        @REM 获取mcuMd5映射表
        echo "get git info"
        !gitRootPath!\git-cmd.exe --command=usr/bin/bash.exe -l -i -c "git log --pretty=oneline -40 | grep mcu" >%versionFile%
        for /f %%a in (%versionFile%) do (
            git show %%a:%appFile% >%checkFile%
            certutil -hashfile %checkFile% MD5 | find /v ":" >>%md5File%
        )
        adb push %versionFile% /home/root/
        adb push %md5File% /home/root/
        del %checkFile%
        del %md5File%
        del %versionFile%

        @REM 自动生成.readmcu.sh
        adb shell "echo -e \"#!/bin/sh\n\" >/home/root/%mcuScript%"
        adb shell "echo md5Local=\$\(md5sum /data/C385_App.s19 \| awk \'\{print \$1\}\'\) >>/home/root/%mcuScript%"
        adb shell "echo -e \"while read line\ndo\" >>/home/root/%mcuScript%"
        adb shell "echo -e \"\t\"md5Server=\$\(echo \$line \| awk \'\{print \$3\}\'\) >>/home/root/%mcuScript%"
        adb shell "echo -e \"\t\"if [ \$md5Server == \$md5Local ]\;then >>/home/root/%mcuScript%"
        adb shell "echo -e \"\t\t\"echo \$line \| awk \'\{print \$2\}\' >>/home/root/%mcuScript%"
        adb shell "echo -e \"\t\"fi >>/home/root/%mcuScript%"
        adb shell "echo    done\<%mergeFile% >>/home/root/%mcuScript%"
        adb shell "cd /home/root && if [ -e %mcuScript% ];then chmod a+x %mcuScript%;fi"
        adb shell "paste -d \" \" %versionFile% %md5File% >%mergeFile%"
        adb shell "if [ -e %versionFile% ];then rm %versionFile%;fi"
        adb shell "if [ -e %md5File% ];then rm %md5File%;fi"
    ) else (
        set mcuVersion="null"
        set commitId="null"
    )
)

adb shell "echo %DateTime% %hostName% %ipAddress% %mcuVersion% %commitId% >>/home/root/.mcu_history"
goto:eof