#!/usr/bin/env bash

# 获取当前时间-MMDD
nowdate=$(date +%m%d)

# 获取当前时间-YYYYMMDD
nowdate_full=$(date +%Y%m%d)

# 获取脚本当前路径
basepath=$(cd `dirname $0`/..; pwd)
# 设置日志路径
logpath="${basepath}/logs"

# ftp端口
sh_port=22

# oes部署用户名称
oes_user=oesuser

# oes主备仲裁服务器的IP地址
oes_dep_Lip=""
oes_dep_Fip=""
oes_dep_Aip=""

# oes目录名称
oes_dep_name=""
# oes备份目录名称
oes_backup_name=""

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
# Name: _resetAll
# Desc: reset data
# Args:
##############################################################
_resetAll()
{
	#重置系统
	echo "开始reset"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes reset -Y -F"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes reset -Y -F"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes reset -Y -F"

	echo "reset命令执行完成，请及时去MON检查oes的状态"
}

##############################################################
# Name: _resetLeader
# Desc: reset leader data
# Args:
##############################################################
_resetLeader()
{
	#重置主机系统
	echo "开始reset"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes reset -Y -F"

	echo "reset命令执行完成，请及时去MON检查oes主机的状态"
}

##############################################################
# Name: _resetFollow
# Desc: reset follow data
# Args:
##############################################################
_resetFollow()
{
	#重置备机系统
	echo "开始reset"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes reset -Y -F"

	echo "reset命令执行完成，请及时去MON检查oes主机的状态"
}

##############################################################
# Name: _resetArbiter
# Desc: reset arbiter data
# Args:
##############################################################
_resetArbiter()
{
	#重置仲裁机系统
	echo "开始reset"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes reset -Y -F"

	echo "reset命令执行完成，请及时去MON检查oes主机的状态"
}

##############################################################
# Name: _isexecute
# Desc: 执行哪个方法
# Args:
##############################################################
_isexecute()
{
	if [ -z "$1" ];then
		echo "您好，准备开始执行重置系统命令，请耐心等待！"
		_resetAll
		return;
	fi

	case "$1" in
	master|m)
	echo "您好，准备开始执行重置主机系统命令，请耐心等待！"
	_resetLeader
	;;
	follow|f)
	echo "您好，准备开始执行重置备机系统命令，请耐心等待！"
	_resetFollow
	;;
	arbiter|a)
	echo "您好，准备开始执行重置仲裁机系统命令，请耐心等待！"
	_resetArbiter
	;;
	h|-h|--h|help|-help|--help)
	helpdesc
	;;
	*)
	echo ""
	echo " 非有效指令，请重新执行命令，可以输入./oes_reset.sh -h 查看帮助！"
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
	echo "Usage: reset command [options] [args]"
	echo ""
	echo "Commands are:"
	echo "    参数1：重置指定机器，取值：空：重置所有机器;master/m:重置主机; follow/f:重置备机; arbiter/a:重置仲裁机;"
	echo "=============================================================================="
	echo ""
	echo "执行命令例如："
	echo "        ./oes_reset.sh master"
	echo "等同于：./oes_reset.sh m"
	echo ""
}

_set
_isexecute $@






