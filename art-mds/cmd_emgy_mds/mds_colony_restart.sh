#!/usr/bin/env bash
#获取当前时间-YYYYMMDD
nowdate=$(date +%Y%m%d)
# 获取脚本当前路径
basepath=$(cd `dirname $0`/..; pwd)

##########success标志文件列表
mon_success_flag="mon_collector_$nowdate.success"
sse_success_flag="sse_collector_$nowdate.success"
szse_success_flag="szse_collector_$nowdate.success"


#########执行任务
cd $basepath/flag;
#mon的success标志文件未生成
while [ ! -f $mon_success_flag ];do
	echo "mon成功标志文件未生成，重新执行mon.sh、sse.sh和szse.sh"
	sleep 5
	echo "sh mon.sh;sh sse.sh;sh szse.sh"
	cd $basepath/cmd/;sh mon.sh;sh sse.sh;sh szse.sh
done
#已经生成mon的success标志文件
if [ -f $mon_success_flag ]&&[ ! -f $sse_success_flag ];then
	while [ ! -f $sse_success_flag ];do
		echo "mon成功,上海产品文件拉取失败，执行sse.sh"
		sleep 5
		echo "sh sse.sh"
		cd $basepath/cmd/;sh sse.sh
		done
elif [ -f $mon_success_flag ]&&[ ! -f $szse_success_flag ];then
	while [ ! -f $szse_success_flag ];do
	echo "mon成功，深圳产品文件拉取失败，执行szse.sh"
	sleep 5
	echo "sh szse.sh"
	cd $basepath/cmd/;sh szse.sh
	done
fi
#所有success标志文件都生成
while [ -f $mon_success_flag ]&&[ -f $sse_success_flag ]&&[ -f $szse_success_flag ];do
	echo "所有标志文件都已经生成，开始重启mds集群服务器"
	sleep 5
	    echo "sh mds_cleartx_start.sh;sh mds_set_status.sh w reset 5"
        cd $basepath/cmd_emgy_mds;sh mds_cleartx_start.sh;sh mds_set_status.sh w reset 5
done
