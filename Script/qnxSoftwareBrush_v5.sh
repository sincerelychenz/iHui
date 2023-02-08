#!/bin/bash

# 释放出去的四个文件 soc zros和集成软件 qnx zros和集成软件
socZrosFile=zrosC385.tar.gz
socIntegratedFile=8155Integrate.tar.gz
qnxZrosFile=releaseqnx2.1.2.tar.gz
qnxIntegratedFile=821Integrate.tar.gz

# 集成软件各自包含的两个文件 
executeFile=ApaIntegrate.tar.gz
softwareFile=ca_adas.tar.gz

# 自动生成的脚本名
cleanLogScriptName=cleanLog.sh
envScriptName=env.sh
scpScriptName=qnxBrush.sh
integratedRepName=ApaIntegrate
allSize=16
speed=3.2


#############################以下是函数定义#################################
###
 # @description: 获取文件的大小和md5sum
 # @return: 本地文件md5值 域控文件md5值 文件大小
###
function getFileInfo()
{
    if [ -e $1 ];then
        localMd5num=`md5sum $1| awk '{print $1}'`
        adb shell "touch /data/zros/$1"
        boardMd5num=`adb shell md5sum /data/zros/$1 | awk '{print $1}'`
        fileSize=`du -shm $1 | awk -F" " '{print $1}'`
    else
        exit
    fi

    echo $localMd5num
    echo $boardMd5num
    echo $fileSize
}

###
 # @description: 判断文件是否存在
###
function judgeFileExist()
{
    if [ -z $2 ];then
        echo -e "\e[1;31m本地$1文件不存在\e[0m"
        exit
    fi

    echo -e "\e[1;33m本地$1文件md5: $2\e[0m"
    echo -e "\e[1;33m域控$1文件md5: $3\e[0m"
}

###
 # @description: 根据文件大小计算集成时间
###
function calculateTime()
{
    timeGap=`echo $1 / $speed | bc`
    itgMin=$[$timeGap / 60 + 1]
    itgSec=$[$timeGap % 60]
    echo -e "\e[1;32m开始集成软件刷写,预计$itgMin分$itgSec秒\e[0m"
}

###
 # @description: 推送文件到域控
 # @param: 本地文件md5 域控文件md5 文件名
###
function filePush()
{
    if [ $1 != $2 ];then
        adb push $3 /data/zros/
    fi
}

###
 # @description: 重置环境：1.备份纵目标定文件 2.删除旧的环境
###
function resetEnv()
{
    echo -e "\e[1;32m重置环境,同步并自动重启SOC\e[0m"
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
}

###
 # @description: 安装环境
###
function installEnv()
{
    adb shell "mount -o rw,remount /"
    adb shell "cd /data/zros && if [ -d zros_8155 ];then touch zros_8155;else mkdir zros_8155;fi"
    adb shell "cd /data/zros && tar -zxvf $socZrosFile -C ./zros_8155"
    echo -e "\e[1;32m正在部署zros环境,请稍等\e[0m"
    adb shell "cd /data/zros && if [ -e zros_8155/bin ];then mv zros_8155/bin /zros;fi"
    adb shell "cd /data/zros && if [ -e zros_8155/lib ];then mv zros_8155/lib /zros;fi"
    adb shell "cd /data/zros && if [ -e zros_8155/res ];then mv zros_8155/res /zros;fi"
    adb shell "cd /data/zros && if [ -e zros_8155/data ];then mv zros_8155/data ./;fi"
    adb shell "cd /data/zros && if [ -e data/ca_c385/calib ];then rm -r data/ca_c385/calib;fi"
    adb shell "cd /data/zros && if [ -e calib ];then mv calib data/ca_c385/;fi"
    adb shell "cd /data/zros && tar -zxvf $socIntegratedFile -C ./"
    socPath=${socIntegratedFile%%.*}
    adb shell "cd /data/zros && if [ -e $integratedRepName ];then touch $integratedRepName;else tar -zxvf $socPath/$executeFile -C ./;fi"
    adb shell "cd /data/zros/$socPath && tar -zxvf $softwareFile -C /zros"
    adb shell "cd /zros/ca_adas && if [ -e run.sh ];then chmod a+x run.sh;fi"
    adb shell "cd /zros/ca_adas && if [ -e map_convert.sh ];then chmod a+x map_convert.sh;fi"
    adb shell "cd /zros/ca_adas && if [ -e hdm/capilot_map_gd_c385ev ];then chmod a+x hdm/capilot_map_gd_c385ev;fi"
    adb shell "cd /data/zros && if [ -d zros ];then touch zros;else mkdir zros;fi"
    adb shell "cp /data/zros/$qnxZrosFile /data/zros/zros"
    adb shell "cp /data/zros/$qnxIntegratedFile /data/zros/zros"
    adb shell "sync"
}

###
 # @description: 环境部署,备份标定文件和解压软件包
###
function envDeploy()
{
    resetEnv

    judgeDeviceExist installEnv
}

###
 # @description: 自动生成脚本,配置开机自启动和网段
###
function generateScript()
{
    # 生成空间空间占用大于80%删除log的脚本
    adb shell "echo -e \"#!/bin/sh\n\" >/home/root/$cleanLogScriptName"
    adb shell "echo res=\$\(df -h \| sed -n \'/data$/p\' \| awk \'\{print '\$5'\}\' \| awk -F\'%\' \'\{print '\$1'\}\'\) >>/home/root/$cleanLogScriptName"
    adb shell "echo if [ '\$res' -ge 80 ]\;then >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\"for logPath in \$\(find /data -name \'ehpv3log\'\)\"\n\tdo\" >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\"if [ -e '\$logPath' ]\;then >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\t\"rm -r '\$logPath' >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\tfi\n\tdone\n\n\" >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\"res=\$\(df -h \| sed -n \'/data$/p\' \| awk \'\{print '\$5'\}\' \| awk -F\'%\' \'\{print '\$1'\}\'\) >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\"if [ '\$res' -ge 80 ]\;then >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\"for path in \$\(find /data -name \'run.sh\'\)\"\n\t\tdo\" >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\t\"dirPath=\$\(dirname '\$path'\) >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\t\"if [ -e '\$dirPath'/log ]\;then >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\t\t\"rm -r '\$dirPath'/log >>/home/root/$cleanLogScriptName"
    adb shell "echo -e \"\t\t\tfi\n\t\tdone\n\tfi\nfi\" >>/home/root/$cleanLogScriptName"
    adb shell "cd /home/root && if [ -e $cleanLogScriptName ];then chmod a+x $cleanLogScriptName;fi"

    # 生成821的环境配置脚本
    adb shell "echo -e \"#!/bin/sh\n\" >/home/root/$scpScriptName"
    adb shell "echo scp -r /data/zros/zros root@192.168.1.202:/data >>/home/root/$scpScriptName"
    adb shell "echo ssh root@192.168.1.202 '\""cd /data/zros \&\& /proc/boot/chmod a+x $envScriptName \&\& ./$envScriptName\""' >>/home/root/$scpScriptName"
    adb shell "echo reboot >>/home/root/$scpScriptName"
    adb shell "chmod a+x /home/root/$scpScriptName"

    adb shell "echo -e \"#!/bin/sh\n\" >/data/zros/zros/$envScriptName"
    adb shell "echo export ZROS_CONSOLE_LOG_LEVEL=1 >>/data/zros/zros/$envScriptName"
    adb shell "echo export LD_LIBRARY_PATH=/zros/lib:/ti_fs/lib:/ti_fs/usr/lib:/proc/boot:'\$'LD_LIBRARY_PATH >>/data/zros/zros/$envScriptName"
    adb shell "echo -e \"\n\" >>/data/zros/zros/$envScriptName"
    adb shell "echo qnxIntegratedFile='\""$qnxIntegratedFile\""' >>/data/zros/zros/$envScriptName"
    adb shell "echo qnxZrosFile='\""$qnxZrosFile\""' >>/data/zros/zros/$envScriptName"
    adb shell "echo /proc/boot/mount -u /zros >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /zros \&\& /proc/boot/rm -r \* >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros \&\& 'if [ -d zros_821 ];then /proc/boot/touch zros_821;else /ti_fs/bin/mkdir zros_821;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo /ti_fs/bin/tar -zxvf /data/zros/'\$'qnxZrosFile -C /data/zros/zros_821 >>/data/zros/zros/$envScriptName"
    adb shell "echo /proc/boot/mount -u /ti_fs >>/data/zros/zros/$envScriptName"
    adb shell "echo /ti_fs/bin/echo Enploy qnx zros environment,Please wait a moment >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/bin ];then /proc/boot/mv zros_821/bin /zros;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/data ];then /proc/boot/mv zros_821/data /zros;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/res ];then /proc/boot/mv zros_821/res /zros;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros \&\& 'if [ -e zros_821/lib ];then /proc/boot/mv zros_821/lib /zros;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo /ti_fs/bin/tar -zxvf /data/zros/'\$'qnxIntegratedFile -C /data/zros >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros \&\& 'if [ -e $executeFile ];then /proc/boot/touch $executeFile;else /ti_fs/bin/tar -zxvf /data/zros/821Integrate/$executeFile -C /data/zros;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo /ti_fs/bin/tar -zxvf /data/zros/821Integrate/$softwareFile -C /zros >>/data/zros/zros/$envScriptName"
    adb shell "echo /proc/boot/chmod a+x /zros/ca_adas/run.sh >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /data/zros/ApaIntegrate \&\& 'if [ -e nocheck.txt ];then /proc/boot/rm -r nocheck.txt;fi' >>/data/zros/zros/$envScriptName"
    adb shell "echo cd /ti_fs/scripts \&\& /proc/boot/sed -i \'/run.sh/d\' user.sh >>/data/zros/zros/$envScriptName"
    adb shell "echo /ti_fs/bin/sync >>/data/zros/zros/$envScriptName"
    adb shell "echo /proc/boot/echo '\""Qnx Software Brush Success, Auto Reboot SOC and QNX\""' >>/data/zros/zros/$envScriptName"
    adb shell "echo /proc/boot/shutdown \> /dev/null 2\>\&1 >>/data/zros/zros/$envScriptName"

    # 配置开机自启动
    adb shell "cd /usr/bin && cat zros.sh | grep $cleanLogScriptName >/dev/null || sed -i '/$integratedRepName\b/icd /home/root\n./$cleanLogScriptName' zros.sh"
    adb shell "cd /usr/bin && cat zros.sh | grep $cleanLogScriptName >/dev/null || sed -i '/^date\b/icd /home/root\n./$cleanLogScriptName' zros.sh"
    # adb shell "cd /usr/bin && cat zros.sh | grep run.sh >/dev/null || sed -i '/^date\b/icd /data/zros/$integratedRepName\n./run.sh' zros.sh"
    adb shell "cd /usr/bin && cat zros.sh | grep run.sh >/dev/null && sed -i '/run.sh/d' zros.sh"
    adb shell "sed -i 's#<path>.*#<path>/zros/ca_adas</path>#g' /zros/res/changan_apa_node/config.xml"

    # 配置172.16.1.8网段
    adb shell "cd /usr/bin && cat vlan.sh | grep -w 'eth0 1' >/dev/null || sed -i '/eth0 2\b/ivconfig add eth0 1' vlan.sh"
    adb shell "cd /usr/bin && cat vlan.sh | grep -w 'eth0.1 172.16.1.8' >/dev/null || sed -i '/eth0.2 172.16.2.8/iifconfig eth0.1 172.16.1.8 netmask 255.255.255.0 up' vlan.sh"
    adb shell "cd /usr/bin && cat vlan.sh | grep -w 'add 172.16.1.8' >/dev/null || sed -i '/add 172.16.2.8/iip route add 172.16.1.8  dev eth0.1 proto kernel' vlan.sh"

    # 配置快捷方式
    adb shell "echo alias ll=\'ls -al\' >/home/root/.profile"
    adb shell "echo alias gw=\'cd /data/zros/$integratedRepName\' >>/home/root/.profile"
    adb shell "echo alias rv=\'cd /zros/bin \&\& export ZROS_CONSOLE_LOG_LEVEL=1 \&\& ./read_version\' >>/home/root/.profile"
    adb shell "echo alias ck=\'cd /zros/bin \&\& export ZROS_CONSOLE_LOG_LEVEL=1 \&\& ./ota_test active_check\' >>/home/root/.profile"
    adb shell "echo alias up=\'cd /zros/bin \&\& export ZROS_CONSOLE_LOG_LEVEL=1 \&\& ./ota_test integration_test_with_mcu\' >>/home/root/.profile"
    adb shell "echo alias mt=\'mount -o rw,remount /\' >>/home/root/.profile"
    adb shell "echo alias ft=\'resize \&\& top -b -d 1 -n 1 \| grep ca_apa \| grep -v ca_apa_agent\' >>/home/root/.profile"
    adb shell "echo alias fv=\'mt \&\& vi /usr/bin/zros.sh\' >>/home/root/.profile"
    adb shell "echo alias fr=\'cd /zros/ca_adas \&\& ./run.sh --version\' >>/home/root/.profile"
    adb shell "echo alias ma=\'mt \&\& sed -ri '\""s/\(.*\<enable\>\)\([0-1]\)\(.*\)/\\10\\3/\""' /zros/res/product_config/launcher/launcher_changan.xml\' >>/home/root/.profile"
    adb shell "echo alias au=\'mt \&\& sed -ri '\""s/\(.*\<enable\>\)\([0-1]\)\(.*\)/\\11\\3/\""' /zros/res/product_config/launcher/launcher_changan.xml\' >>/home/root/.profile"
    adb shell "echo alias eq=\'ssh root@192.168.1.202\' >>/home/root/.profile"
    adb shell "echo alias qb=\'cd /home/root \&\& ./$scpScriptName\' >>/home/root/.profile"
}

###
 # @description: 记录刷写时间,主机名和IP,显示版本信息
###
function recordBrushInfo()
{
    DateTime=`date "+%Y%m%d%H%M%S"`
    ipAddress=`ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | head -n 1`
    if [ $? -ne 0 ];then
        ipAddress=null
    fi
    adb shell "echo $DateTime $USER $ipAddress >>/home/root/.itg_history"
    echo -e "\e[1;33mSOC集成软件刷写完成,当前SOC版本为:\e[0m"
    adb shell "cd /zros/ca_adas && ./run.sh --version"
    echo -e "\e[1;33m当前GHDMapResimSDK库大小为:\e[0m"
    adb shell "cd /data/zros/$integratedRepName && if [ -e GHDMapResimSDK ];then du -sh GHDMapResimSDK;fi"
    echo -e "\e[1;32m请进入8155(adb shell)执行脚本刷写qnx: ./$scpScriptName\e[0m"
}

###
 # @description: 判断设备是否存在,如果不存在,每间隔3S循环搜索一次
###
function judgeDeviceExist()
{
    sleep 3
    res=`adb devices | grep -w device | awk '{print $1}'`
    if [[ -z $res ]];then
        echo -e "\e[1;32m正在搜索设备,请稍等\e[0m"
        judgeDeviceExist $1
    else
        echo -e "\e[1;32m第一次检测到设备,准备进行第二次检测: $res\e[0m"
        sleep 3
        res=`adb devices | grep -w device | awk '{print $1}'`
        if [[ -z $res ]];then
            echo -e "\e[1;33m第一次误检测,正在搜索设备,请稍等~~\e[0m"
            judgeDeviceExist $1
        else
            echo -e "\e[1;32m第二次检测到设备,切换root模式: $res\e[0m"
            switchRoot
            if [ "$1" == "installEnv" ];then
                installEnv
            else
                echo -e "\e[1;31m参数错误\e[0m"
            fi
        fi
    fi
}

###
 # @description: 如果不是root模式，切换为root模式
###
function switchRoot()
{
    echo -e "\e[1;32m自动切换为root模式\e[0m"
    timeout 3s adb shell "ls >/dev/null"

    if [ $? -eq 124 ];then
        adb usb 8155@zongmutech
        sleep 3
    fi
}

#############################main entrance#################################
res=`adb devices | grep -w device`
if [[ -z $res ]];then
    echo -e "\e[1;31m请反面插入Typec\e[0m"
    exit
else
    switchRoot

    adb shell "df -h | sed -n '/data$/p' >/home/root/temp.txt"
    ret=`adb shell cat /home/root/temp.txt | awk '{print $5}' | awk -F"%" '{print $1}'`
    adb shell "rm /home/root/temp.txt"
    if [[ $ret -gt 90 ]];then
        echo -e "\e[1;31m剩余磁盘空间不足,请删除不需要的文件\e[0m"
        exit
    else
        echo -e "\e[1;32m获取文件md5校验码,请稍等\e[0m"
        localSocItgMd5num=`echo $(getFileInfo $socIntegratedFile) | awk '{print $1}'`
        boardSocItgMd5num=`echo $(getFileInfo $socIntegratedFile) | awk '{print $2}'`
        socIntegratedSize=`echo $(getFileInfo $socIntegratedFile) | awk '{print $3}'`
        judgeFileExist $socIntegratedFile $localSocItgMd5num $boardSocItgMd5num

        localQnxItgMd5num=`echo $(getFileInfo $qnxIntegratedFile) | awk '{print $1}'`
        boardQnxItgMd5num=`echo $(getFileInfo $qnxIntegratedFile) | awk '{print $2}'`
        qnxIntegratedSize=`echo $(getFileInfo $qnxIntegratedFile) | awk '{print $3}'`
        judgeFileExist $qnxIntegratedFile $localQnxItgMd5num $boardQnxItgMd5num

        localSocZrosMd5num=`echo $(getFileInfo $socZrosFile) | awk '{print $1}'`
        boardSocZrosMd5num=`echo $(getFileInfo $socZrosFile) | awk '{print $2}'`
        socZrosSize=`echo $(getFileInfo $socZrosFile) | awk '{print $3}'`
        judgeFileExist $socZrosFile $localSocZrosMd5num $boardSocZrosMd5num

        localQnxZrosMd5num=`echo $(getFileInfo $qnxZrosFile) | awk '{print $1}'`
        boardQnxZrosMd5num=`echo $(getFileInfo $qnxZrosFile) | awk '{print $2}'`
        qnxZrosSize=`echo $(getFileInfo $qnxZrosFile) | awk '{print $3}'`
        judgeFileExist $qnxZrosFile $localQnxZrosMd5num $boardQnxZrosMd5num

        if [ $localSocZrosMd5num != $boardSocZrosMd5num ];then
            allSize=$[$allSize + $socZrosSize]
        fi

        if [ $localQnxZrosMd5num != $boardQnxZrosMd5num ];then
            allSize=$[$allSize + $qnxZrosSize]
        fi

        if [ $localSocItgMd5num != $boardSocItgMd5num ];then
            allSize=$[$allSize + $socIntegratedSize]
        fi

        if [ $localQnxItgMd5num != $boardQnxItgMd5num ];then
            allSize=$[$allSize + $qnxIntegratedSize]
        fi

        calculateTime $allSize

        filePush $localSocZrosMd5num $boardSocZrosMd5num $socZrosFile
        filePush $localQnxZrosMd5num $boardQnxZrosMd5num $qnxZrosFile
        filePush $localSocItgMd5num $boardSocItgMd5num $socIntegratedFile
        filePush $localQnxItgMd5num $boardQnxItgMd5num $qnxIntegratedFile
        adb shell "sync"

        # 环境部署,备份标定文件和解压软件包
        envDeploy
        # 自动生成脚本,配置开机自启动和网段
        generateScript
        # 记录刷写时间,主机名和IP,显示版本信息
        recordBrushInfo
    fi
fi
