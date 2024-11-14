#!/usr/bin/env bash

# 获取当前时间-MMDD
nowdate=$(date +%m%d)

# 获取当前时间-YYYYMMDD
nowdate_full=$(date +%Y%m%d)
nowdate_full_hms=$(date +%Y%m%d%H%M%S)

# 获取脚本当前路径
basepath=$(cd `dirname $0`/..; pwd)
# 设置日志路径
logpath="${basepath}/logs"

# ftp端口
sh_port=22

# mds部署用户名称
mds_user="mdsuser"

# mds主备仲裁服务器的IP地址
mds_dep_Lip=""
mds_dep_Fip=""
mds_dep_Aip=""

# mds目录名称
mds_dep_name=""

# 删除日期
delete_time=""

##############################################################
# Name: set
# Desc: set param
# Args: 
##############################################################
_set()
{
	if [ -e ${logpath} ]; then
		echo ${logpath} existing >> ${logpath}/urgent.log
	else
		echo mkdir -p ${logpath}
		mkdir -p ${logpath}
	fi
	# 切换上一级目录
	cd $basepath
	# 获取配置相关参数
	#broker: hlzq
	broker=$(grep broker automatic.yml| awk -F'[: ]+' 'NR==1{ print $2 }'| awk -F'[# ]+' 'NR==1{ print $1 }')
	#taget: dev
	taget=$(awk -F'[: ]+' '/taget/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	#ansible_ssh_user: mdsuser
	mds_user=$(awk -F'[: ]+' '/ssh_user/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 获取主机的序号标识 master_host: "03"
	master_host_seq=$(awk -F'[: "]+' '/master_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取备机的序号标识 follow_host: "02"
	follow_host_seq=$(awk -F'[: "]+' '/follow_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取仲裁机的序号标识 arbiter_host: "01"
	arbiter_host_seq=$(awk -F'[: "]+' '/arbiter_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 主备仲裁服务器的IP地址
	# 获取主机的id 192.168.10.120 swf-oes-hlzq-dev-01
	if [ $(echo ${master_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		mds_dep_Lip=${master_host_seq}
	else
		mds_dep_Lip=$(grep swf-oes-${broker}-${taget}-${master_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	if [ $(echo ${follow_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		mds_dep_Fip=${follow_host_seq}
	else
		mds_dep_Fip=$(grep swf-oes-${broker}-${taget}-${follow_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	if [ $(echo ${arbiter_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		mds_dep_Aip=${arbiter_host_seq}
	else
		mds_dep_Aip=$(grep swf-oes-${broker}-${taget}-${arbiter_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi

	# 获得系统信息 system: mds
	system=$(awk -F'[: ]+' '/system/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获得版本信息 version: xxx
	version=$(awk -F'[: ]+' '/version/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 兼容0.15.8的art版本
	mds_dep_name=$(awk -F'[: "]+' '/mds_pkg_name/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	if [ ! ${mds_dep_name} ]; then
		mds_dep_name=$(echo ${system}-${version})
	fi
}

##############################################################
# Name: _delete_tx_5days
# Desc: delete mds_txlog
# Args:
##############################################################
_delete_tx_5days()
{
	# 删除mds主机5天之前的txlog日志
	echo "删除mds主机5天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "find /home/mdsuser/host_01/backup/ -type f -ctime +5 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds备机5天之前的txlog日志
	echo "删除mds备机5天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "find /home/mdsuser/host_02/backup/ -type f -ctime +5 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds仲裁机5天之前的txlog日志
	echo "删除mds仲裁机5天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "find /home/mdsuser/host_03/backup/ -type f -ctime +5 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"
	
	# 删除art主机5天之前的日志
	echo "删除art主机5天之前的日志"
	find $logpath -type f -ctime +5 -iname '*.log' -exec rm -rf {} \;	

	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_10days
# Desc: delete mds_txlog
# Args:
##############################################################
_delete_tx_10days()
{
	# 删除mds主机10天之前的txlog日志
	echo "删除mds主机10天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "find /home/mdsuser/host_01/backup/ -type f -ctime +10 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds备机10天之前的txlog日志
	echo "删除mds备机10天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "find /home/mdsuser/host_02/backup/ -type f -ctime +10 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds仲裁机10天之前的txlog日志
	echo "删除mds仲裁机10天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "find /home/mdsuser/host_03/backup/ -type f -ctime +10 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"
	
	# 删除art主机10天之前的日志
	echo "删除art主机10天之前的日志"
	find $logpath -type f -ctime +10 -iname '*.log' -exec rm -rf {} \;

	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_15days
# Desc: delete mds_txlog
# Args:
##############################################################
_delete_tx_15days()
{
	# 删除mds主机15天之前的txlog日志
	echo "删除mds主机15天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "find /home/mdsuser/host_01/backup/ -type f -ctime +15 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds备机15天之前的txlog日志
	echo "删除mds备机15天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "find /home/mdsuser/host_02/backup/ -type f -ctime +15 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds仲裁机15天之前的txlog日志
	echo "删除mds仲裁机15天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "find /home/mdsuser/host_03/backup/ -type f -ctime +15 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"
	
	# 删除art主机15天之前的日志
	echo "删除art主机15天之前的日志"
	find $logpath -type f -ctime +15 -iname '*.log' -exec rm -rf {} \;

	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_20days
# Desc: delete mds_txlog
# Args:
##############################################################
_delete_tx_20days()
{
	# 删除mds主机20天之前的txlog日志
	echo "删除mds主机20天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "find /home/mdsuser/host_01/backup/ -type f -ctime +20 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds备机20天之前的txlog日志
	echo "删除mds备机20天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "find /home/mdsuser/host_02/backup/ -type f -ctime +20 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds仲裁机20天之前的txlog日志
	echo "删除mds仲裁机20天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "find /home/mdsuser/host_03/backup/ -type f -ctime +20 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"
	
	# 删除art主机20天之前的日志
	echo "删除art主机20天之前的日志"
	find $logpath -type f -ctime +20 -iname '*.log' -exec rm -rf {} \;

	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_25days
# Desc: delete mds_txlog
# Args:
##############################################################
_delete_tx_25days()
{
	# 删除mds主机25天之前的txlog日志
	echo "删除mds主机25天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "find /home/mdsuser/host_01/backup/ -type f -ctime +25 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds备机25天之前的txlog日志
	echo "删除mds备机25天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "find /home/mdsuser/host_02/backup/ -type f -ctime +25 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds仲裁机25天之前的txlog日志
	echo "删除mds仲裁机25天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "find /home/mdsuser/host_03/backup/ -type f -ctime +25 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"
	
	# 删除art主机25天之前的日志
	echo "删除art主机25天之前的日志"
	find $logpath -type f -ctime +25 -iname '*.log' -exec rm -rf {} \;

	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_30days
# Desc: delete mds_txlog
# Args:
##############################################################
_delete_tx_30days()
{
	# 删除mds主机30天之前的txlog日志
	echo "删除mds主机30天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "find /home/mdsuser/host_01/backup/ -type f -ctime +30 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds备机30天之前的txlog日志
	echo "删除mds备机30天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "find /home/mdsuser/host_02/backup/ -type f -ctime +30 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除mds仲裁机机30天之前的txlog日志
	echo "删除mds仲裁机机30天之前的txlog日志"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "find /home/mdsuser/host_03/backup/ -type f -ctime +30 -iname 'txlog*.tar.gz' -exec rm -rf {} \;"
	
	# 删除art主机30天之前的日志
	echo "删除art主机30天之前的日志"
	find $logpath -type f -ctime +30 -iname '*.log' -exec rm -rf {} \;

	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _isexecute
# Desc: 执行哪个方法
# Args:
##############################################################
_isexecute()
{
	case "$1" in
	5)
	echo "您好，准备删除mds集群5天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除art主机5天之前的log日志，请耐心等待！"
	_delete_tx_5days
	;;
	10)
	echo "您好，准备删除mds集群10天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除art主机10天之前的log日志，请耐心等待！"
	_delete_tx_10days
	;;
	15)
	echo "您好，准备删除mds集群15天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除art主机15天之前的log日志，请耐心等待！"
	_delete_tx_15days
	;;
	20)
	echo "您好，准备删除mds集群20天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除art主机20天之前的log日志，请耐心等待！"
	_delete_tx_20days
	;;
	25)
	echo "您好，准备删除mds集群25天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除art主机25天之前的log日志，请耐心等待！"
	_delete_tx_25days
	;;
	30)
	echo "您好，准备删除mds集群30天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除art主机30天之前的log日志，请耐心等待！"
	_delete_tx_30days
	;;
	h|-h|--h|help|-help|--help)
	helpdesc
	;;
	*)
	echo ""
	echo " 非有效指令，请重新执行命令，可以输入./mds_deletetx_.sh -h 查看帮助！"
	echo ""
	exit;;
	esac
}

##############################################################
# Name: help desc
# Desc: help desc
# Args:
##############################################################
helpdesc()
{
	echo "Usage: delete txlog command [options] [args]"
	echo ""
	echo "Commands are:"
	echo "    参数1：指定删除日期长度，取值：5:删除mds、art集群5天前txlog日志; 10:删除mds、art集群10天前txlog日志; 15:删除mds、art集群15天前txlog日志; 20:删除mds、art集群20天前txlog日志; 25:删除mds、art集群25天前txlog日志; 30:删除mds、art集群30天前txlog日志;"
	echo "=============================================================================="
	echo ""
	echo "执行命令例如："
	echo "        ./mds_deletetx_.sh 10"
	echo ""
}

_set
_isexecute $@






