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
@REM 设置释放出去的四个文件 soc zros和集成软件 qnx zros和集成软件
set socZrosFile=zrosC385.tar.gz
set socZrosFilePath=%~dp0%socZrosFile%
set socIntegratedFile=8155Integrate.tar.gz
set socFilePath=%~dp0%socIntegratedFile%
set qnxZrosFile=releaseqnx2.1.2.tar.gz
set qnxZrosFilePath=%~dp0%qnxZrosFile%
set qnxIntegratedFile=821Integrate.tar.gz
set qnxFilePath=%~dp0%qnxIntegratedFile%

@REM 集成软件各自包含的两个文件 
set executeFile=ApaIntegrate.tar.gz
set softwareFile=ca_adas.tar.gz

@REM 自动生成的脚本名
set scriptFileName=%~nx0
set memoryFile=all-cpu-mem.sh
set memoryScript=%~dp0\GIF\extraScript\%memoryFile%
set cleanLogScript=cleanLog.sh
set envScriptName=env.sh
set scpScriptName=qnxBrush.sh
set integratedRepName=ApaIntegrate
set /a MByte=1024*1024
set speed=3

@REM 切换为root用户
call:switchRoot

@REM 判断空间使用率是否超过90%
call:judgeDiskSpace

@REM 判断SOC和QNX ZROS文件包和集成文件包是否存在
call:judgeFileExist %socZrosFilePath% %socZrosFile%
call:judgeFileExist %socFilePath% %socIntegratedFile%
call:judgeFileExist %qnxZrosFilePath% %qnxZrosFile%
call:judgeFileExist %qnxFilePath% %qnxIntegratedFile%

@REM 获取SOC和QNX ZROS文件包和集成文件包大小
for /f %%a in ('dir /b %socZrosFilePath%') do (
    set /a socZrosSize = %%~za
)

for /f %%a in ('dir /b %qnxZrosFilePath%') do (
    set /a qnxZrosSize = %%~za
)

for /f %%a in ('dir /b %socFilePath%') do (
    set /a socIntegratedSize = %%~za
)

for /f %%a in ('dir /b %qnxFilePath%') do (
    set /a qnxIntegratedSize = %%~za
)

@REM 获取本地和域控SOC、QNX的ZROS文件和集成文件MD5校验码
call:getLocalMd5num %socZrosFile% localSocZrosMd5num
call:getBoardMd5num %socZrosFile% boardSocZrosMd5num
call:getLocalMd5num %qnxZrosFile% localQnxZrosMd5num
call:getBoardMd5num %qnxZrosFile% boardQnxZrosMd5num
call:getLocalMd5num %socIntegratedFile% localSocItgMd5num
call:getBoardMd5num %socIntegratedFile% boardSocItgMd5num
call:getLocalMd5num %qnxIntegratedFile% localQnxItgMd5num
call:getBoardMd5num %qnxIntegratedFile% boardQnxItgMd5num

@REM 获取需要推送文件总大小
set /a allSize=18000000
if not %localSocZrosMd5num% == %boardSocZrosMd5num% (
    set /a allSize = !socZrosSize!
)

if not %localQnxZrosMd5num% == %boardQnxZrosMd5num% (
    set /a allSize = !allSize! + !qnxZrosSize!
)

if not %localSocItgMd5num% == %boardSocItgMd5num% (
    set /a allSize = !allSize! + !socIntegratedSize!
)

if not %localQnxItgMd5num% == %boardQnxItgMd5num% (
    set /a allSize = !allSize! + !qnxIntegratedSize!
)

call:calculateTime

call:filePush %localSocZrosMd5num% %boardSocZrosMd5num% %socZrosFilePath%
call:filePush %localQnxZrosMd5num% %boardQnxZrosMd5num% %qnxZrosFilePath%
call:filePush %localSocItgMd5num% %boardSocItgMd5num% %socFilePath%
call:filePush %localQnxItgMd5num% %boardQnxItgMd5num% %qnxFilePath%
adb shell "sync"

@REM 环境部署,备份标定文件和解压软件包
call:envDeploy

:soc
@REM 自动生成脚本,配置开机自启动和网段
call:generateScript
@REM 记录刷写时间、主机名和IP,显示版本信息
call:recordBrushInfo

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
adb shell "if [ -e /home/root/%scriptFileName% ];then rm /home/root/%scriptFileName%;fi"
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
        if "%1" == "installEnv" (
            call:installEnv
        )
    )
    echo "[WARNING]第一次误检测,正在搜索设备,请稍等~~"
    call:judgeDeviceExist %1
)
echo "[INFO]正在搜索设备,请稍等"
call:judgeDeviceExist %1
goto:eof

@REM /**
@REM  * @description: 判断磁盘空间大小
@REM  * @return：如果空间占用超过90%则报错
@REM  */
:judgeDiskSpace
echo "[INFO]判断磁盘使用空间大小是否超过百分之九十"
adb shell "res=`df -h | sed -n '/data$/p' | awk '{if($5 >90) print $5}' | wc -l` && echo $res >/home/root/temp.txt"
for /f %%i in ('adb shell cat /home/root/temp.txt') do (
    set res=%%i
)
adb shell "rm /home/root/temp.txt"
if %res% equ 1 (
    color 4
    echo "[FATAL]磁盘使用超过百分之九十,剩余磁盘空间不足,请删除不需要的文件"
    goto end
)
goto:eof

@REM /**
@REM  * @description: 判断文件是否存在
@REM  */
:judgeFileExist
if not exist %1 (
    echo "[FATAL]%2 文件不存在"
    color 4
    goto end
)
goto:eof

@REM /**
@REM  * @description: 获取本地文件md5
@REM  * @return：本地文件md5值
@REM  */
:getLocalMd5num
for /f %%i in ('certutil -hashfile %1 MD5 ^| find /v ":"') do (
    echo "[INFO]获取本地%1文件md5"
    set md5Num=%%i
    set "%~2=!md5Num!"
    echo "[INFO]本地%1文件md5: "!md5Num!
)
goto:eof

@REM /**
@REM  * @description: 获取域控文件md5
@REM  * @return：域控文件md5值
@REM  */
:getBoardMd5num
for /f %%i in ('adb shell md5sum /data/zros/%1') do (
    echo "[INFO]获取域控%1文件md5"
    set md5Num=%%i
    set "%~2=!md5Num!"
    echo "[INFO]域控%1文件md5: "!md5Num!
)
goto:eof

@REM /**
@REM  * @description: 根据文件大小,计算时间
@REM  */
:calculateTime
set /a timeGap = !allSize! / %MByte% / %speed%
set /a itgMin = !timeGap! / 60 + 1
set /a itgSec = !timeGap! %% 60
echo "[INFO]开始集成软件刷写,预计!itgMin!分!itgSec!秒"
goto:eof

@REM /**
@REM  * @description: 推送文件到域控
@REM  * @param: 本地文件md5 域控文件md5 文件名
@REM  */
:filePush
if not %1 == %2 (
    adb push %3 /data/zros/
)
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
adb shell "echo %DateTime% %hostName% %ipAddress% >>/home/root/.itg_history"
echo "[INFO]集成软件刷写完成,当前SOC版本为:"
adb shell "cd /zros/ca_adas && ./run.sh --version"
echo "[INFO]当前GHDMapResimSDK库大小为:"
adb shell "cd /data/zros/%integratedRepName% && if [ -e GHDMapResimSDK ];then du -sh GHDMapResimSDK;fi"
echo "[INFO]请进入8155(adb shell)执行脚本刷写qnx: ./%scpScriptName%"
goto:eof

@REM /**
@REM  * @description: 重置环境：1.备份纵目标定文件 2.删除旧的环境
@REM  */
:resetEnv
echo "[INFO]重置环境,同步并自动重启SOC"
adb shell "mount -o rw,remount /"
adb shell "mount -o rw,remount /persist"
adb shell "cd /data/zros && if [ -e data/ca_c385/calib ];then mv data/ca_c385/calib ./;fi"
adb shell "if [ -e /data/zros/cache ];then rm -r /data/zros/cache;fi"
adb shell "if [ -e /persist/res/backup/ca_c385/calib ];then rm -r /persist/res/backup/ca_c385/calib;fi"

adb shell "if [ -e /zros ];then cd /zros && rm -r *;fi"
adb shell "cd /data/zros && if [ -e data ];then rm -r data;fi"
adb shell "if [ -e /data/zros/ca_adas ];then rm -rf /data/zros/ca_adas;fi"
adb shell "killall capilot"
adb shell "sync && reboot"
goto:eof

@REM /**
@REM  * @description: 安装环境
@REM  */
:installEnv
adb shell "mount -o rw,remount /"
adb shell "cd /data/zros && if [ -d zros_8155 ];then touch zros_8155;else mkdir zros_8155;fi"
adb shell "cd /data/zros && tar -zxvf %socZrosFile% -C ./zros_8155"
echo "[INFO]正在部署zros环境,请稍等"
adb shell "cd /data/zros && if [ -e zros_8155/bin ];then mv zros_8155/bin /zros;fi"
adb shell "cd /data/zros && if [ -e zros_8155/lib ];then mv zros_8155/lib /zros;fi"
adb shell "cd /data/zros && if [ -e zros_8155/res ];then mv zros_8155/res /zros;fi"
adb shell "cd /data/zros && if [ -e zros_8155/data ];then mv zros_8155/data ./;fi"
adb shell "cd /data/zros && if [ -e data/ca_c385/calib ];then rm -r data/ca_c385/calib;fi"
adb shell "cd /data/zros && if [ -e calib ];then mv calib data/ca_c385/;fi"
adb shell "cd /data/zros && tar -zxvf %socIntegratedFile% -C ./"
adb shell "cd /data/zros && if [ -e %integratedRepName% ];then touch %integratedRepName%;else tar -zxvf 8155Integrate/%executeFile% -C ./;fi"
adb shell "cd /data/zros/8155Integrate && tar -zxvf %softwareFile% -C /zros"
adb shell "cd /zros/ca_adas && if [ -e run.sh ];then chmod a+x run.sh;fi"
adb shell "cd /zros/ca_adas && if [ -e map_convert.sh ];then chmod a+x map_convert.sh;fi"
adb shell "cd /zros/ca_adas && if [ -e hdm/capilot_map_gd_c385ev ];then chmod a+x hdm/capilot_map_gd_c385ev;fi"
adb shell "cd /data/zros && if [ -d zros ];then touch zros;else mkdir zros;fi"
adb shell "cp /data/zros/%qnxZrosFile% /data/zros/zros"
adb shell "cp /data/zros/%qnxIntegratedFile% /data/zros/zros"
adb shell "sync"
goto:soc
goto:eof

@REM /**
@REM  * @description: 环境部署:1. 重置环境 2.安装环境
@REM  */
:envDeploy
call:resetEnv

call:judgeDeviceExist installEnv
goto:eof

@REM /**
@REM  * @description: 自动生成脚本,配置开机自启动
@REM  */
:generateScript
if exist %memoryScript% (
    adb push %memoryScript% /home/root
    adb shell "cd /home/root && chmod a+x %memoryFile%"
)

@REM 生成当空间占用大于80%删除log的脚本
adb shell "echo -e \"#!/bin/sh\n\" >/home/root/%cleanLogScript%"
adb shell "echo res=\$\(df -h \| sed -n \'/data$/p\' \| awk \'\{print \$5\}\' \| awk -F\'%%\' \'\{print \$1\}\'\) >>/home/root/%cleanLogScript%"
adb shell "echo if [ \$res -ge 80 ]\;then >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\"for logPath in \$\(find /data -name \'ehpv3log\'\)\"\n\tdo\" >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\"if [ -e \$logPath ]\;then >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\t\"rm -r \$logPath >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\tfi\n\tdone\n\n\" >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\"res=\$\(df -h \| sed -n \'/data$/p\' \| awk \'\{print \$5\}\' \| awk -F\'%%\' \'\{print \$1\}\'\) >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\"if [ \$res -ge 80 ]\;then >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\"for path in \$\(find /data -name \'run.sh\'\)\"\n\t\tdo\" >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\t\"dirPath=\$\(dirname \$path\) >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\t\"if [ -e \$dirPath/log ]\;then >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\t\t\"rm -r \$dirPath/log >>/home/root/%cleanLogScript%"
adb shell "echo -e \"\t\t\tfi\n\t\tdone\n\tfi\nfi\" >>/home/root/%cleanLogScript%"
adb shell "cd /home/root && if [ -e %cleanLogScript% ];then chmod a+x %cleanLogScript%;fi"

@REM 生成821的环境配置脚本
adb shell "echo -e \"#!/bin/sh\n\" >/home/root/%scpScriptName%"
adb shell "echo scp -r /data/zros/zros root@192.168.1.202:/data >>/home/root/%scpScriptName%"
adb shell "echo ssh root@192.168.1.202 '\""cd /data/zros && /proc/boot/chmod a+x %envScriptName% && ./%envScriptName%\""' >>/home/root/%scpScriptName%"
adb shell "echo reboot >>/home/root/%scpScriptName%"
adb shell "chmod a+x /home/root/%scpScriptName%"

adb shell "echo -e \"#!/bin/sh\n\" >/data/zros/zros/%envScriptName%"
adb shell "echo export ZROS_CONSOLE_LOG_LEVEL=1 >>/data/zros/zros/%envScriptName%"
adb shell "echo export LD_LIBRARY_PATH=/zros/lib:/ti_fs/lib:/ti_fs/usr/lib:/proc/boot:'\$'LD_LIBRARY_PATH >>/data/zros/zros/%envScriptName%"
adb shell "echo -e \"\n\" >>/data/zros/zros/%envScriptName%"
adb shell "echo qnxIntegratedFile='\""%qnxIntegratedFile%\""' >>/data/zros/zros/%envScriptName%"
adb shell "echo qnxZrosFile='\""%qnxZrosFile%\""' >>/data/zros/zros/%envScriptName%"
adb shell "echo /proc/boot/mount -u /zros >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /zros \&\& /proc/boot/rm -r \* >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros \&\& 'if [ -d zros_821 ];then /proc/boot/touch zros_821;else /ti_fs/bin/mkdir zros_821;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo /ti_fs/bin/tar -zxvf /data/zros/\$qnxZrosFile -C /data/zros/zros_821 >>/data/zros/zros/%envScriptName%"
adb shell "echo /proc/boot/mount -u /ti_fs >>/data/zros/zros/%envScriptName%"
adb shell "echo /ti_fs/bin/echo Enploy qnx zros environment,Please wait a moment >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/bin ];then /proc/boot/mv zros_821/bin /zros;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/data ];then /proc/boot/mv zros_821/data /zros;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/res ];then /proc/boot/mv zros_821/res /zros;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/lib ];then /proc/boot/mv zros_821/lib /zros;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo /ti_fs/bin/tar -zxvf /data/zros/\$qnxIntegratedFile -C /data/zros >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros \&\& 'if [ -e %executeFile% ];then /proc/boot/touch %executeFile%;else /ti_fs/bin/tar -zxvf /data/zros/821Integrate/%executeFile% -C /data/zros;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo /ti_fs/bin/tar -zxvf /data/zros/821Integrate/%softwareFile% -C /zros >>/data/zros/zros/%envScriptName%"
adb shell "echo /proc/boot/chmod a+x /zros/ca_adas/run.sh >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /data/zros/ApaIntegrate \&\& 'if [ -e nocheck.txt ];then /proc/boot/rm -r nocheck.txt;fi' >>/data/zros/zros/%envScriptName%"
adb shell "echo cd /ti_fs/scripts \&\& /proc/boot/sed -i \'/run.sh/d\' user.sh >>/data/zros/zros/%envScriptName%"
adb shell "echo /ti_fs/bin/sync >>/data/zros/zros/%envScriptName%"
adb shell "echo /proc/boot/echo '\""Qnx Software Brush Success, Auto Reboot SOC and QNX\""' >>/data/zros/zros/%envScriptName%"
adb shell "echo /proc/boot/shutdown \> /dev/null 2\>\&1 >>/data/zros/zros/%envScriptName%"

@REM 配置开机自启动
adb shell "cd /usr/bin && cat zros.sh | grep %cleanLogScript% >/dev/null || sed -i '/%integratedRepName%\b/icd /home/root\n./%cleanLogScript%' zros.sh"
adb shell "cd /usr/bin && cat zros.sh | grep %cleanLogScript% >/dev/null || sed -i '/^date\b/icd /home/root\n./%cleanLogScript%' zros.sh"
adb shell "cd /usr/bin && cat zros.sh | grep run.sh >/dev/null && sed -i '/run.sh/d' zros.sh"
adb shell "sed -i 's#<path>.*#<path>/zros/ca_adas</path>#g' /zros/res/changan_apa_node/config.xml"

@REM 配置172.16.1.8网段
adb shell "cd /usr/bin && cat vlan.sh | grep -w 'eth0 1' >/dev/null || sed -i '/eth0 2\b/ivconfig add eth0 1' vlan.sh"
adb shell "cd /usr/bin && cat vlan.sh | grep -w 'eth0.1 172.16.1.8' >/dev/null || sed -i '/eth0.2 172.16.2.8/iifconfig eth0.1 172.16.1.8 netmask 255.255.255.0 up' vlan.sh"
adb shell "cd /usr/bin && cat vlan.sh | grep -w 'add 172.16.1.8' >/dev/null || sed -i '/add 172.16.2.8/iip route add 172.16.1.8  dev eth0.1 proto kernel' vlan.sh"

@REM 配置快捷方式
adb shell "echo alias ll=\'ls -al\' >/home/root/.profile"
adb shell "echo alias gw=\'cd /data/zros/%integratedRepName%\' >>/home/root/.profile"
adb shell "echo alias rv=\'cd /zros/bin \&\& export ZROS_CONSOLE_LOG_LEVEL=1 \&\& ./read_version\' >>/home/root/.profile"
adb shell "echo alias ck=\'cd /zros/bin \&\& export ZROS_CONSOLE_LOG_LEVEL=1 \&\& ./ota_test active_check\' >>/home/root/.profile"
adb shell "echo alias up=\'cd /zros/bin \&\& export ZROS_CONSOLE_LOG_LEVEL=1 \&\& ./ota_test integration_test_with_mcu\' >>/home/root/.profile"
adb shell "echo alias mt=\'mount -o rw,remount /\' >>/home/root/.profile"
adb shell "echo alias ft=\'resize \&\& top -b -d 1 -n 1 \| grep ca_apa \| grep -v ca_apa_agent\' >>/home/root/.profile"
adb shell "echo alias fv=\'mt \&\& vi /usr/bin/zros.sh\' >>/home/root/.profile"
adb shell "echo alias fr=\'cd /zros/ca_adas \&\& ./run.sh --version\' >>/home/root/.profile"
adb shell "echo alias ma=\'mt \&\& sed -ri '\""s/(.*<enable>)([0-1])(.*)/\10\3/\""' /zros/res/product_config/launcher/launcher_changan.xml\' >>/home/root/.profile"
adb shell "echo alias au=\'mt \&\& sed -ri '\""s/(.*<enable>)([0-1])(.*)/\11\3/\""' /zros/res/product_config/launcher/launcher_changan.xml\' >>/home/root/.profile"
adb shell "echo alias eq=\'ssh root@192.168.1.202\' >>/home/root/.profile"
adb shell "echo alias mcu=\'cd /home/root \&\& ./.readmcu.sh\' >>/home/root/.profile"
adb shell "echo alias qb=\'cd /home/root \&\& ./%scpScriptName%\' >>/home/root/.profile"
goto:eof