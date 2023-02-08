#! /bin/bash

tempFileName=temp.log
maxAndminFile=maxmin.log
mediumFile=medium.log
singleTopFile=singleTop.log
uselessDir=useless
arrCom=(ca_apa_adas_udp ca_apa_adrSyste ca_apa_adastm ca_apa_ApaDcs ca_apa_erc_com ca_apa_apa_fusi ca_apa_fusion_m ca_apa_stm_hmi ca_apa_ins_kalm ca_apa_kalman_f ca_apa_loc_publ ca_apa_localiza ca_apa_map_dyna ca_apa_map_data ca_apa_map_stat ca_apa_ApaPcs ca_apa_sab_c385 ca_apa_sab_soc2 ca_apa_semantic ca_apa_render ca_apa_monitor ca_ZmqProxy capilot visual_perception message_center free_space_detection DVR_cam_recoder fused_perception_node ca_apa_agent zros_ui landmark_node marker_park_slot_detector camera topic_sod2 object_sector_node uss_node_2 dr_loc_node location_service_node fusion_slot_target log_center landmark_loc_node data_trans fpse_node spsd_node lane_monitor cube_slam_loc_node ota_c385 object_detection_3channels ldw_node data_mask map_data_recorder)
arrCountVal=(minNiVal maxNiVal minIdleVal maxIdleVal)

localStartTime=`date +'%y-%m-%d %H:%M:%S'`

function Usage()
{
	echo -e "\e[1;31m$0 [-f 输入的文件名(必须为第一个参数)] [-c 生成的cpu文件名] [-m 生成的mem文件名]\e[0m"
	exit
}

###
 # @description: 创建多线程
###
function startMultyThread()
{
    fifoName="csvFifo"
    mkfifo $fifoName
    exec 9<>$fifoName
    rm -rf $fifoName

    for((i=1;i<=${#arrCom[@]};i++))
    do
        echo
    done >&9
}

function fileIsExist()
{
    if [ ! -e $inputFileName ];then
        echo -e "\e[1;31m输入的$inputFileName文件不存在\e[0m"
        exit
    fi
}

function filePreProcess()
{
    if [ ! -e $uselessDir ];then
        mkdir $uselessDir
    fi

    if [ -f $outFileName ];then
        sed -i '1,$d' $outFileName
    fi
}

###
 # @description: 重新生成每个top信息的数据:组件名 cpu mem
 # @return: singleTop.log
###
function genSingleTopRes()
{
    for beginNum in `sed -n -e '/PID USER/=' $inputFileName`
    do
        arrBegin[${#arrBegin[*]}]=$beginNum
    done

    for endNum in `sed -n -e '/top -/=' $inputFileName`
    do
        arrEnd[${#arrEnd[*]}]=$endNum
    done

    for i in $(seq 0 `expr ${#arrBegin[@]} - 1`)
    do
        if [ $i -lt $[${#arrBegin[@]}-1] ];then
            beginNum=${arrBegin[i]}
            endNum=${arrEnd[i+1]}
            sed -n "$beginNum,$endNum"p $inputFileName >$uselessDir/$singleTopFile
            for com in ${arrCom[@]}
            do
                read -u9
                {
                    cpuVal=`sed -n "/$com/p" $uselessDir/$singleTopFile | awk '{print $9 " " $10}'`
                    if [ -z "$cpuVal" ];then
                        echo $com " " " " >> $uselessDir/$tempFileName
                    else
                        echo $com $cpuVal >> $uselessDir/$tempFileName
                    fi
                    echo "" >&9
                } &
            done
            wait
        else
            beginNum=${arrBegin[i]}
            sed -n "$beginNum,$"p $inputFileName >$uselessDir/$singleTopFile
            for com in ${arrCom[@]}
            do
                read -u9
                {
                    cpuVal=`sed -n "/$com/p" $uselessDir/$singleTopFile | awk '{print $9 " " $10}'`
                    if [ -z "$cpuVal" ];then
                        echo $com " " " ">> $uselessDir/$tempFileName
                    else
                        echo $com $cpuVal >> $uselessDir/$tempFileName
                    fi
                    echo "" >&9
                } &
            done
            wait
        fi
    done
}

###
 # @description: 获取每个模式的值以及每个模式下的最大值最小值
 # @return: maxmin.log
###
function generateArr()
{
    # 生成switch to mode行数数组
    for modeNum in `sed -n -e '/switch to mode/=' $inputFileName`
    do
        arrSwitchModeNum[${#arrSwitchModeNum[@]}]=$modeNum
    done

    # 生成switch to mode模式数组
    for swithmode in `sed -n '/switch to mode/p' $inputFileName | awk -F":" '{print $2}' | awk -F"(" '{print $1}'`
    do
        arrSwitchMode[${#arrSwitchMode[@]}]=$swithmode
    done

    for i in $(seq 0 `expr ${#arrSwitchModeNum[@]} - 1`)
    do
        if [ $i -lt $[${#arrSwitchModeNum[@]}-1] ];then
            beginNum=${arrSwitchModeNum[i]}
            endNum=${arrSwitchModeNum[i+1]}
            sed -n "$beginNum,$endNum"p $inputFileName >$uselessDir/$mediumFile
            ni=`sed -n '/\bni\b/p' $uselessDir/$mediumFile | awk '{ print $6}'`
            minNiVal=`echo $ni | awk '{for(i=2;i<=NF;i++) {if($i>$(i-1)){$i=$(i-1)}} {print $NF}}'`
            maxNiVal=`echo $ni | awk '{for(i=2;i<=NF;i++) {if($i<$(i-1)){$i=$(i-1)}} {print $NF}}'`
            minNiArr[${#minNiArr[@]}]=$minNiVal
            maxNiArr[${#maxNiArr[@]}]=$maxNiVal
            idle=`sed -n '/\bni\b/p' $uselessDir/$mediumFile | awk '{ print $8}'`
            minIdleVal=`echo $idle| awk '{for(i=2;i<=NF;i++) {if($i>$(i-1)){$i=$(i-1)}} {print $NF}}'`
            maxIdleVal=`echo $idle | awk '{for(i=2;i<=NF;i++) {if($i<$(i-1)){$i=$(i-1)}} {print $NF}}'`
            minIdleArr[${#minIdleArr[@]}]=$minIdleVal
            maxIdleArr[${#maxIdleArr[@]}]=$maxIdleVal
            timeVal=`sed -n '/\btop -/p' $uselessDir/$mediumFile | awk '{ print $3}'`
            arrNi[${#arrNi[@]}]=$ni
            arrIdle[${#arrIdle[@]}]=$idle
            arrTime[${#arrTime[@]}]=$timeVal
            for com in ${arrCom[@]}
            do
                read -u9
                {
                    if [ $outFileName == "cpu.csv" ];then
                        cpumax=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{max=-1} {if($9+0>max+0) max=$9} END{print max}'`
                        cpumin=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{min=999} {if($9+0<min+0) min=$9} END{print min}'`
                        echo "$com $cpumin $cpumax" >>$uselessDir/$maxAndminFile
                    else
                        memmax=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{max=-1} {if($10+0>max+0) max=$10} END{print max}'`
                        memmin=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{min=999} {if($10+0<min+0) min=$10} END{print min}'`
                        echo "$com $memmin $memmax" >>$uselessDir/$maxAndminFile
                    fi
                    echo "" >&9
                } &
            done
            wait
        else
            beginNum=${arrSwitchModeNum[i]}
            sed -n "$beginNum,$"p $inputFileName >$uselessDir/$mediumFile
            ni=`sed -n '/\bni\b/p' $uselessDir/$mediumFile | awk '{ print $6}'`
            minNiVal=`echo $ni | awk '{for(i=2;i<=NF;i++) {if($i>$(i-1)){$i=$(i-1)}} {print $NF}}'`
            maxNiVal=`echo $ni | awk '{for(i=2;i<=NF;i++) {if($i<$(i-1)){$i=$(i-1)}} {print $NF}}'`
            minNiArr[${#minNiArr[@]}]=$minNiVal
            maxNiArr[${#maxNiArr[@]}]=$maxNiVal
            idle=`sed -n '/\bni\b/p' $uselessDir/$mediumFile | awk '{ print $8}'`
            minIdleVal=`echo $idle| awk '{for(i=2;i<=NF;i++) {if($i>$(i-1)){$i=$(i-1)}} {print $NF}}'`
            maxIdleVal=`echo $idle | awk '{for(i=2;i<=NF;i++) {if($i<$(i-1)){$i=$(i-1)}} {print $NF}}'`
            minIdleArr[${#minIdleArr[@]}]=$minIdleVal
            maxIdleArr[${#maxIdleArr[@]}]=$maxIdleVal
            timeVal=`sed -n "$beginNum,$"p $inputFileName | sed -n '/\btop -/p' | awk '{ print $3}'`
            arrNi[${#arrNi[@]}]=$ni
            arrIdle[${#arrIdle[@]}]=$idle
            arrTime[${#arrTime[@]}]=$timeVal
            for com in ${arrCom[@]}
            do
                read -u9
                {
                    if [ $outFileName == "cpu.csv" ];then
                        cpumax=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{max=-1} {if($9+0>max+0) max=$9} END{print max}'`
                        cpumin=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{min=999} {if($9+0<min+0) min=$9} END{print min}'`
                        echo "$com $cpumin $cpumax" >>$uselessDir/$maxAndminFile
                    else
                        memmax=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{max=-1} {if($10+0>max+0) max=$10} END{print max}'`
                        memmin=`sed -n "/$com/p" $uselessDir/$mediumFile | awk 'BEGIN{min=999} {if($10+0<min+0) min=$10} END{print min}'`
                        echo "$com $memmin $memmax" >>$uselessDir/$maxAndminFile
                    fi
                    echo "" >&9
                }
            done
            wait
        fi
    done

    for i in ${!arrNi[@]}
    do
        lenArr[${#lenArr[@]}]=`echo ${arrNi[$i]} | awk '{print NF}'`
    done
}

###
 # @description: 增加switch mode和ni的行信息到最后的csv文件
###
function appendSwitchmodeInfo()
{
    echo -n "time" >>$outFileName
    for i in ${!arrTime[@]}
    do
        for timeVal in ${arrTime[$i]}
        do
            echo -n " , "$timeVal >>$outFileName
        done 
    done
    echo >>$outFileName

    echo -n "mode" >>$outFileName
    for i in ${!arrNi[@]}
    do
        for niVal in ${arrNi[$i]}
        do
            echo -n " , "${arrSwitchMode[$i]} >>$outFileName
        done 
    done
    echo >>$outFileName

    echo -n "NI" >>$outFileName
    for i in ${!arrNi[@]}
    do
        for niVal in ${arrNi[$i]}
        do
            echo -n " , "$niVal >>$outFileName
        done 
    done
    echo >>$outFileName

    echo -n "Idle" >>$outFileName
    for i in ${!arrNi[@]}
    do
        for idleVal in ${arrIdle[$i]}
        do
            echo -n " , "$idleVal >>$outFileName
        done 
    done
    echo >>$outFileName

    for val in ${arrCountVal[@]}
    do
        echo -n "$val" >>$outFileName
        for i in ${!arrNi[@]}
        do
            for _ in ${arrNi[$i]}
            do
                case $val in
                "minNiVal")
                    echo -n " , "${minNiArr[$i]} >>$outFileName
                    ;;
                "maxNiVal")
                    echo -n " , "${maxNiArr[$i]} >>$outFileName
                    ;;
                "minIdleVal")
                    echo -n " , "${minIdleArr[$i]} >>$outFileName
                    ;;
                "maxIdleVal")
                    echo -n " , "${maxIdleArr[$i]} >>$outFileName
                    ;;
                esac
            done
        done
        echo >>$outFileName
    done
}

###
 # @description: csv前置处理
 # @return {*}
###
function csvPreProcess()
{
    fileIsExist

    filePreProcess

    genSingleTopRes

    generateArr

    appendSwitchmodeInfo
}

###
 # @description: 获得每个组件的最大值和最小值并保存为文件
 # @return: $com.app
###
function getMinAndMax()
{
    for com in ${arrCom[*]}
    do
        read -u9
        {
            if [ $1 == "cpu" ];then
                echo $com `sed -n "/$com/p" $uselessDir/$tempFileName | awk '{print ", "$2}'` >>$outFileName
            else
                echo $com `sed -n "/$com/p" $uselessDir/$tempFileName | awk '{print ", "$3}'` >>$outFileName
            fi

            echo -n $com"min" >>$uselessDir/$com.app
            i=0
            for j in `sed -n "/$com/p" $uselessDir/$maxAndminFile | awk '{print $2}'`
            do
                for _ in `seq ${lenArr[i]}`
                do
                    if [ `echo "$j < 999.0" | bc` -eq 0 ];then
                        echo -n " , " >>$uselessDir/$com.app
                    else
                        echo -n " , "$j >>$uselessDir/$com.app
                    fi
                done
                i=$[$i+1]
            done
            echo >>$uselessDir/$com.app

            k=0
            echo -n $com"max" >>$uselessDir/$com.app
            for j in `sed -n "/$com/p" $uselessDir/$maxAndminFile | awk '{print $3}'`
            do
                for _ in `seq ${lenArr[k]}`
                do
                    if [ `echo "$j > -1" | bc` -eq 0 ];then
                        echo -n " , " >>$uselessDir/$com.app
                    else
                        echo -n " , "$j >>$uselessDir/$com.app
                    fi
                done
                k=$[$k+1]
            done
            echo >>$uselessDir/$com.app
            echo "" >&9
        } &
    done
    wait
}

###
 # @description: 将获得的最大值最小值合入最后的csv文件
###
function appendMaxAndMin()
{
    for com in ${arrCom[*]}
    do
        sed -i "/\b$com\b/r $uselessDir/$com.app" $outFileName
    done

    filePostProcess
}

function filePostProcess()
{
    if [ -e $uselessDir ];then
        rm -r $uselessDir
    fi

    exec 9>&-
    exec 9<&-
}

function cpu2csv()
{
    csvPreProcess

    getMinAndMax cpu

    appendMaxAndMin
}

function mem2csv()
{
    csvPreProcess

    getMinAndMax mem

    appendMaxAndMin
}

###
 # @description: 计算运行时间
###
function calculateRunTime()
{
    localEndTime=`date +'%y-%m-%d %H:%M:%S'`
    localStartSeconds=`date -d "$localStartTime" +%s`
    localEndSeconds=`date -d "$localEndTime" +%s`
    runTime=$(($localEndSeconds - $localStartSeconds))

    rHour=$(($runTime / 3600))
    rMinute=$((($runTime % 3600) / 60))
    rSecond=$(($runTime % 60))
    echo -e "起始时间:\t$localStartTime"
    echo -e "结束时间:\t$localEndTime"
    echo -e "运行时间:\t"$rHour"时"$rMinute"分"$rSecond"秒"
}


####################################main entrance##################################
startMultyThread

while getopts 'c:m:f:' OPT
do
    case $OPT in
    f)
        inputFileName=$OPTARG
        ;;
    c)
        outFileName=$OPTARG
        cpu2csv
        ;;
    m)
        outFileName=$OPTARG
        mem2csv
        ;;
    *)
        Usage
        ;;
    esac
done

if [ $# -eq 0 ];then
	Usage
fi

calculateRunTime