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

# oes部署用户名称
oes_user="oesuser"

# oes主备仲裁服务器的IP地址
oes_dep_Lip=""
oes_dep_Fip=""
oes_dep_Aip=""

# oes目录名称
oes_dep_name=""
# oes备份目录名称
oes_backup_name=""

# mon主机ip地址
mon_dep_name=""
mon_ep_dir=""
mon_user=""
mon_dep_ip=""

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
	#ansible_ssh_user: oesuser
	oes_user=$(awk -F'[: ]+' '/ssh_user/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 获取主机的序号标识 master_host: "01"
	master_host_seq=$(awk -F'[: "]+' '/master_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取备机的序号标识 follow_host: "02"
	follow_host_seq=$(awk -F'[: "]+' '/follow_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取仲裁机的序号标识 arbiter_host: "03"
	arbiter_host_seq=$(awk -F'[: "]+' '/arbiter_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 主备仲裁服务器的IP地址
	# 获取主机的id 192.168.10.120 swf-oes-hlzq-dev-01
	if [ $(echo ${master_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		oes_dep_Lip=${master_host_seq}
	else
		oes_dep_Lip=$(grep swf-oes-${broker}-${taget}-${master_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	if [ $(echo ${follow_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		oes_dep_Fip=${follow_host_seq}
	else
		oes_dep_Fip=$(grep swf-oes-${broker}-${taget}-${follow_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	if [ $(echo ${arbiter_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		oes_dep_Aip=${arbiter_host_seq}
	else
		oes_dep_Aip=$(grep swf-oes-${broker}-${taget}-${arbiter_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	
	# 获取mon主机用户和IP地址
	mon_dep_name=$(grep mon_deploy_path automatic.yml | awk -F' ' '{print $2}')
        mon_ep_dir=$(grep gateway_path_root_mon automatic.yml | awk -F' ' '{print $2}'|sed 's/.......$//')
	mon_user=$(grep mon_user automatic.yml|awk -F' ' '{print $2}')
	mon_dep_ip=$(grep mon_host automatic.yml|awk -F' ' '{print $2}')
        
        # 获得art版本信息
	art_system=$(cd $(dirname "$PWD")|xargs python3 art.py -v|grep art |grep -v config|awk -F' ' '{print $2}')
	#art-oes备份目录名
	art_backup_name=$(echo 'art-oes'-${art_system})
	
        # 获得系统信息 system: oes
	system=$(awk -F'[: ]+' '/system/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获得版本信息 version: xxx
	version=$(awk -F'[: ]+' '/version/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 柜台信息
	counter=$(grep counter automatic.yml |awk -F '[: ]+' 'NR==1{print $2}'| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 兼容0.15.8的art版本
	oes_dep_name=$(awk -F'[: "]+' '/oes_pkg_name/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	if [ ! ${oes_dep_name} ]; then
		oes_dep_name=$(echo ${system}-${version}-${counter})
	fi
	oes_backup_name=$(echo ${system}-${version})
}

##############################################################
# Name: _delete_tx_5days
# Desc: delete oes_txlog
# Args:
##############################################################
_delete_tx_5days()
{
	# 删除oes主机5天之前的txlog日志
	echo "删除oes主机5天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -type f -ctime +5 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes备机5天之前的txlog日志
	echo "删除oes备机5天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "find /home/oesuser/host_02/backup/ -type f -ctime +5 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes仲裁机5天之前的txlog日志
	echo "删除oes仲裁机5天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "find /home/oesuser/host_03/backup/ -type f -ctime +5 -name 'txlog*.tar.gz' -exec rm -rf {} \;"
        
	# 删除mon主机5天之前的日志
	echo "删除mon主机5天之前的日志"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "find $mon_dep_name/log/ -type f -ctime +5 -name '*.log' -exec rm -rf {} \;"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; rm -rf nohup.out;"
	
	# 删除art主机5天之前的日志
	echo "删除art主机5天之前的日志"
	find $logpath -type f -ctime +5 -name '*.log' -exec rm -rf {} \;
	
	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_10days
# Desc: delete oes_txlog
# Args:
##############################################################
_delete_tx_10days()
{
	# 删除oes主机10天之前的txlog日志
	echo "删除oes主机10天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -type f -ctime +10 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes备机10天之前的txlog日志
	echo "删除oes备机10天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "find /home/oesuser/host_02/backup/ -type f -ctime +10 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes仲裁机10天之前的txlog日志
	echo "删除oes仲裁机10天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "find /home/oesuser/host_03/backup/ -type f -ctime +10 -name 'txlog*.tar.gz' -exec rm -rf {} \;"
        
	# 删除mon主机10天之前的日志
	echo "删除mon主机10天之前的日志"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "find $mon_dep_name/log/ -type f -ctime +10 -name '*.log' -exec rm -rf {} \;"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; rm -rf nohup.out;"
	
	# 删除art主机10天之前的日志
	echo "删除art主机10天之前的日志"
	find $logpath -type f -ctime +10 -name '*.log' -exec rm -rf {} \;	
	
	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_15days
# Desc: delete oes_txlog
# Args:
##############################################################
_delete_tx_15days()
{
	# 删除oes主机15天之前的txlog日志
	echo "删除oes主机15天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -type f -ctime +15 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes备机15天之前的txlog日志
	echo "删除oes备机15天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "find /home/oesuser/host_02/backup/ -type f -ctime +15 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes仲裁机15天之前的txlog日志
	echo "删除oes仲裁机15天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "find /home/oesuser/host_03/backup/ -type f -ctime +15 -name 'txlog*.tar.gz' -exec rm -rf {} \;"
        
	# 删除mon主机15天之前的日志
	echo "删除mon主机15天之前的日志"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "find $mon_dep_name/log/ -type f -ctime +15 -name '*.log' -exec rm -rf {} \;"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; rm -rf nohup.out;"
	
	# 删除art主机15天之前的日志
	echo "删除art主机15天之前的日志"
	find $logpath -type f -ctime +15 -name '*.log' -exec rm -rf {} \;
	
	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_20days
# Desc: delete oes_txlog
# Args:
##############################################################
_delete_tx_20days()
{
	# 删除oes主机20天之前的txlog日志
	echo "删除oes主机20天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -type f -ctime +20 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes备机20天之前的txlog日志
	echo "删除oes备机20天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "find /home/oesuser/host_02/backup/ -type f -ctime +20 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes仲裁机20天之前的txlog日志
	echo "删除oes仲裁机20天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "find /home/oesuser/host_03/backup/ -type f -ctime +20 -name 'txlog*.tar.gz' -exec rm -rf {} \;"
        
	# 删除mon主机20天之前的日志
	echo "删除mon主机20天之前的日志"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "find $mon_dep_name/log/ -type f -ctime +20 -name '*.log' -exec rm -rf {} \;"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; rm -rf nohup.out;"
	
	# 删除art主机20天之前的日志
	echo "删除art主机20天之前的日志"
	find $logpath -type f -ctime +20 -name '*.log' -exec rm -rf {} \;
	
	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_25days
# Desc: delete oes_txlog
# Args:
##############################################################
_delete_tx_25days()
{
	# 删除oes主机25天之前的txlog日志
	echo "删除oes主机25天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -type f -ctime +25 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes备机25天之前的txlog日志
	echo "删除oes备机25天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "find /home/oesuser/host_02/backup/ -type f -ctime +25 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes仲裁机25天之前的txlog日志
	echo "删除oes仲裁机25天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "find /home/oesuser/host_03/backup/ -type f -ctime +25 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

    # 删除mon主机25天之前的日志
	echo "删除mon主机25天之前的日志"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "find $mon_dep_name/log/ -type f -ctime +25 -name '*.log' -exec rm -rf {} \;"
    ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; rm -rf nohup.out;"
	
	# 删除art主机25天之前的日志
	echo "删除art主机25天之前的日志"
	find $logpath -type f -ctime +25 -name '*.log' -exec rm -rf {} \;
	
	echo "日志删除完毕，请及时去检查日志删除情况"
}

##############################################################
# Name: _delete_tx_30days
# Desc: delete oes_txlog
# Args:
##############################################################
_delete_tx_30days()
{
	# 删除oes主机30天之前的txlog日志
	echo "删除oes主机30天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -type f -ctime +30 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes备机30天之前的txlog日志
	echo "删除oes备机30天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "find /home/oesuser/host_02/backup/ -type f -ctime +30 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

	# 删除oes仲裁机机30天之前的txlog日志
	echo "删除oes仲裁机机30天之前的txlog日志"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "find /home/oesuser/host_03/backup/ -type f -ctime +30 -name 'txlog*.tar.gz' -exec rm -rf {} \;"

    # 删除mon主机30天之前的日志
	echo "删除mon主机30天之前的日志"
	ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "find $mon_dep_name/log/ -type f -ctime +30 -name '*.log' -exec rm -rf {} \;"
    ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; rm -rf nohup.out;"
	
	# 删除art主机30天之前的日志
	echo "删除art主机30天之前的日志"
	find $logpath -type f -ctime +30 -name '*.log' -exec rm -rf {} \;
	
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
	echo "您好，准备删除oes集群5天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除mon主机5天之前的log和nohup.out日志，请耐心等待！"
	echo "您好，准备删除art主机5天之前的log日志，请耐心等待！"
	_delete_tx_5days
	;;
	10)
	echo "您好，准备删除oes集群10天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除mon主机10天之前的log和nohup.out日志，请耐心等待！"
	echo "您好，准备删除art主机10天之前的log日志，请耐心等待！"
	_delete_tx_10days
	;;
	15)
	echo "您好，准备删除oes集群15天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除mon主机15天之前的log和nohup.out日志，请耐心等待！"
	echo "您好，准备删除art主机15天之前的log日志，请耐心等待！"
	_delete_tx_15days
	;;
	20)
	echo "您好，准备删除oes集群20天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除mon主机20天之前的log和nohup.out日志，请耐心等待！"
	echo "您好，准备删除art主机20天之前的log日志，请耐心等待！"
	_delete_tx_20days
	;;
	25)
	echo "您好，准备删除oes集群25天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除mon主机25天之前的log和nohup.out日志，请耐心等待！"
	echo "您好，准备删除art主机25天之前的log日志，请耐心等待！"
	_delete_tx_25days
	;;
	30)
	echo "您好，准备删除oes集群30天之前的txlog日志，请耐心等待！"
	echo "您好，准备删除mon主机30天之前的log和nohup.out日志，请耐心等待！"
	echo "您好，准备删除art主机30天之前的log日志，请耐心等待！"
	_delete_tx_30days
	;;
	h|-h|--h|help|-help|--help)
	helpdesc
	;;
	*)
	echo ""
	echo " 非有效指令，请重新执行命令，可以输入./oes_deletetx_.sh -h 查看帮助！"
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
	echo "Usage: fix start command [options] [args]"
	echo ""
	echo "Commands are:"
	echo "    参数1：指定删除日期长度，取值：5:删除oes、mon、art的5天前日志; 10:删除oes、mon、art的10天前日志; 15:删除oes、mon、art的15天前日志; 20:删除oes、mon、art的20天前日志; 25:删除oes、mon、art的25天前日志; 30:删除oes、mon、art的30天前日志;"
	echo "=============================================================================="
	echo ""
	echo "执行命令例如："
	echo "        ./oes_deletetx_.sh 10"
	echo ""
}

_set
_isexecute $@






