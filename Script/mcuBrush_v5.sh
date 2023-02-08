#!/bin/bash

appFile=mcu/C385_App.s19

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
            if [ "$1" == "firstCheck" ];then
                firstCheck
            elif [ "$1" == "secondCheck" ];then
                secondCheck
            else
                echo -e "\e[1;31m参数错误\e[0m"
            fi
        fi
    fi
}

###
 # @description: 如果不是root模式,切换为root模式,如果是,则跳过
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

###
 # @description: 获取当前分区
###
function readCurrentPart()
{
    curPart=`adb shell "cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test active_check 2>&1 | sed -n 's/.*is \([0-9]\).*/\1/p'"`
    echo $curPart
}

###
 # @description: 设备诊断,以防运行过程中设备挂掉,重新运行当前函数
###
function deviceDiagnose()
{
    res=`adb devices | grep -w device | awk '{print $1}'`
    if [[ -z $res ]];then
        echo -e "\e[1;31m第二次刷写过程中设备挂掉,需重新上下电挂载设备\e[0m"
        judgeDeviceExist $1
    fi
}

###
 # @description: 推送ota文件开始mcu刷写
 # @return: 如果ota文件不存在则报错
###
function mcuBrush()
{
    if [ -e ./$appFile ];then
        echo -e "\e[1;32m开始mcu软件刷写\e[0m"
        adb push ./$appFile /data
        adb shell "mount -o rw,remount /"
        adb shell "cd /zros/bin && chmod a+x ota_test"

        firstBeforePart=`readCurrentPart`

        adb shell "cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test integration_test_with_mcu"

        judgeDeviceExist firstCheck
    else
        echo -e "\e[1;31m$appFile 文件不存在\e[0m"
        exit
    fi
}

###
 # @description: 第一次刷写检查,并在最后进行诊断,如果诊断失败,则重新执行当前函数
###
function firstCheck()
{
    # 如果查询分区没变，则进行第二次查询
    firstAfterPart=`readCurrentPart`
    if [[ $firstBeforePart == $firstAfterPart ]];then
        firstRetryPart=`readCurrentPart`
    else
        firstRetryPart=$firstAfterPart
    fi

    adb shell "sleep 5 && cd /zros/bin && export ZROS_CONSOLE_LOG_LEVEL=1 && ./ota_test integration_test_with_mcu"

    # 添加设备诊断
    deviceDiagnose firstCheck

    judgeDeviceExist secondCheck
}

###
 # @description: 第二次刷写检查,并在最后进行诊断,如果诊断失败,则重新执行当前函数
###
function secondCheck()
{
    # 如果查询分区没变，则进行第二次查询
    secondAfterPart=`readCurrentPart`
    if [[ $firstRetryPart == $secondAfterPart ]];then
        secondRetryPart=`readCurrentPart`
    else
        secondRetryPart=$secondAfterPart
    fi

    # 添加设备诊断
    deviceDiagnose secondCheck

    getBrushResult
}

###
 # @description: 获取mcu刷写结果
###
function getBrushResult()
{
    echo -e "\e[1;33m第1次刷写之前分区为: $firstBeforePart\e[0m"
    echo -e "\e[1;33m第1次刷写之后分区为: $firstRetryPart\e[0m"
    if [[ $firstBeforePart == $firstRetryPart ]];then
        echo -e "\e[1;31m第一次刷写失败\e[0m"
    else
        echo -e "\e[1;32m第一次刷写成功\e[0m"
    fi

    echo -e "\e[1;33m第2次刷写之前分区为: $firstRetryPart\e[0m"
    echo -e "\e[1;33m第2次刷写之后分区为: $secondRetryPart\e[0m"
    if [[ $firstRetryPart == $secondRetryPart ]];then
        echo -e "\e[1;31m第二次刷写失败\e[0m"
    else
        echo -e "\e[1;32m第二次刷写成功\e[0m"
    fi
    exit
}

#############################main entrance#################################
res=`adb devices | grep -w device`
if [[ -z $res ]];then
    echo -e "\e[1;31m请反面插入Typec\e[0m"
    exit
else
    switchRoot

    mcuBrush
fi