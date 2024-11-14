#!/usr/bin/bash
#获取当前时间-YYYYMMDD
nowdate=$(date +%Y%m%d)
# 获取脚本当前路径
basepath=$(cd `dirname $0`/..; pwd)

##########success标志文件列表
counter_distribute_success_flag="counter_distribute_$nowdate.success"
mon_success_flag="mon_collector_$nowdate.success"
counter_fetch_success_flag="counter_fetch_$nowdate.success"
csdc_collector_success_flag="csdc_collector_$nowdate.success"
sse_success_flag="sse_collector_$nowdate.success"
fetch_OK_flag="fetch_$nowdate.ok"
szse_success_flag="szse_collector_$nowdate.success"
freezed_OK_flag="freezed_$nowdate.ok"

########################################执行任务####################################
cd $basepath/flag;
#mon的success标志文件未生成
while [ ! -f $mon_success_flag ];do
	echo "mon成功标志文件未生成，重新执行mon.sh、sse.sh和szse.sh"
	sleep 5
	echo "sh mon.sh;sh sse.sh;sh szse.sh"
	cd $basepath/cmd/;sh mon.sh;sh sse.sh;sh szse.sh
	if [ -f $basepath/flag/$mon_success_flag ];then
		break;
	fi
done
#柜台拉取冻结失败
while [ ! -f $fetch_OK_flag ] || [ ! -f $freezed_OK_flag ] || [ ! -f $counter_fetch_success_flag ];do
	echo "执行counter_fetch.sh,拉取并冻结柜台资金"
	sleep 5
	echo "sh counter_fetch.sh"
	cd $basepath/cmd/;sh counter_fetch.sh
	if [ -f $basepath/flag/$fetch_OK_flag && -f $basepath/flag/$freezed_OK_flag || -f $basepath/flag/$counter_fetch_success_flag ];then
		break;
	fi
done

#柜台分发失败
while [ ! -f $counter_distribute_success_flag ];do
	echo "执行counter_distribute.sh分发主柜文件"
	sleep 5
	echo "sh counter_distribute.sh"
	cd $basepath/cmd/;sh counter_distribute.sh
	if [ -f $basepath/flag/$counter_distribute_success_flag ];then
		break;
	fi
done
#中登权益文件失败
while [ ! -f $csdc_collector_success_flag ];do
	echo "执行csdc.sh拉取分发中登新股权益文件"
	sleep 5
	echo "sh csdc.sh"
	cd $basepath/cmd/;sh csdc.sh
		if [ -f $basepath/flag/$csdc_collector_success_flag ];then
			break;
		fi
done 
#已经生成mon的success标志文件
if [ -f $mon_success_flag ]&&[ ! -f $sse_success_flag ];then
	while [ ! -f $sse_success_flag ];do
		echo "mon成功,上海产品文件拉取失败，执行sse.sh"
		sleep 5
		echo "sh sse.sh"
		cd $basepath/cmd/;sh sse.sh
		if [ -f $basepath/flag/$sse_success_flag ];then
		break;
		fi
	done
elif [ -f $mon_success_flag ]&&[ ! -f $szse_success_flag ];then
	while [ ! -f $szse_success_flag ];do
		echo "mon成功，深圳产品文件拉取失败，执行szse.sh"
		sleep 5
		echo "sh szse.sh"
		cd $basepath/cmd/;sh szse.sh
		if [ -f $basepath/flag/$szse_success_flag ];then
			break;
		fi
	done
fi
#所有success标志文件都生成
while [ -f $counter_distribute_success_flag ]&& \
	[ -f $mon_success_flag ]&& \
	[ -f $counter_fetch_success_flag ]&& \
	[ -f $csdc_collector_success_flag ]&& \
	[ -f $sse_success_flag ]&& \
	[ -f $fetch_OK_flag ]&& \
	[ -f $szse_success_flag ]&& \
	[ -f $freezed_OK_flag ];do
	echo "所有标志文件都已经生成，开始重启交易服务器"
	sleep 5
		echo "sh oes_restart.sh nct;sh oes_set_status.sh w reset 5"
		cd $basepath/cmd_emgy_oes;sh oes_restart.sh nct;sh oes_set_status.sh w reset 5
done

