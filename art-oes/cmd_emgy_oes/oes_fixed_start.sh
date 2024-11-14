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
# Name: _fixleaderstart
# Desc: clear txlog, cp follow tx to leader, start oes, load oes
# Args:
##############################################################
_fixleaderstart()
{
	# 如果主机故障，再次执行一次停止OES,并清除TXLOG数据
	echo "停止主机oes,并清除TXLOG数据"
	echo "执行指令1：ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip \"cd host_01/${oes_dep_name}/bin;./oes stop -F;cd ..;mkdir -p ../backup/${oes_backup_name}/${nowdate_full};tar -zcvf ../backup/${oes_backup_name}/${nowdate_full}/txlog-${nowdate_full_hms}.tar.gz txlog;rm -rf ./txlog/TXLOG_*\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes stop -F;cd ..;mkdir -p ../backup/${oes_backup_name}/${nowdate_full};tar -zcvf ../backup/${oes_backup_name}/${nowdate_full}/txlog-${nowdate_full_hms}.tar.gz txlog;rm -rf ./txlog/TXLOG_*"

	# 拷贝备机上面的交易日志到主机
	echo "执行指令2：ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip \"cd host_02/${oes_dep_name}/txlog;scp -r TXLOG_* ${oes_user}@${oes_dep_Lip}:/home/${oes_user}/host_01/${oes_dep_name}/txlog/.\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/txlog;scp -r TXLOG_* ${oes_user}@${oes_dep_Lip}:/home/${oes_user}/host_01/${oes_dep_name}/txlog/."
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/data;scp -r * ${oes_user}@${oes_dep_Lip}:/home/${oes_user}/host_01/${oes_dep_name}/data/."

	# 启动OES
	echo "执行指令3：ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip \"cd host_01/${oes_dep_name}/bin;./oes start\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes start;sleep 60;./oes open"

	echo "重启命令执行完成，请及时去MON检查oes的状态"
}

##############################################################
# Name: _fixfollowstart
# Desc: clear txlog, cp leader tx to follow, start oes, load oes
# Args:
##############################################################
_fixfollowstart()
{
	# 如果备机故障，再次执行一次停止OES,并清除TXLOG数据
	echo "停止主机oes,并清除TXLOG数据"
	echo "执行指令1：ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip \"cd host_02/${oes_dep_name}/bin;./oes stop -F;cd ..;mkdir -p ../backup/${oes_backup_name}/${nowdate_full};tar -zcvf ../backup/${oes_backup_name}/${nowdate_full}/txlog-${nowdate_full_hms}.tar.gz txlog;rm -rf ./txlog/TXLOG_*\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes stop -F;cd ..;mkdir -p ../backup/${oes_backup_name}/${nowdate_full};tar -zcvf ../backup/${oes_backup_name}/${nowdate_full}/txlog-${nowdate_full_hms}.tar.gz txlog;rm -rf ./txlog/TXLOG_*"

	# 拷贝备机上面的交易日志到备机
	echo "执行指令2：ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip \"cd host_01/${oes_dep_name}/txlog;scp -r TXLOG_* ${oes_user}@${oes_dep_Fip}:/home/${oes_user}/host_02/${oes_dep_name}/txlog/.\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/txlog;scp -r TXLOG_* ${oes_user}@${oes_dep_Fip}:/home/${oes_user}/host_02/${oes_dep_name}/txlog/."
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/data;scp -r * ${oes_user}@${oes_dep_Fip}:/home/${oes_user}/host_02/${oes_dep_name}/data/."

	# 启动OES
	echo "执行指令3：ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip \"cd host_02/${oes_dep_name}/bin;./oes start\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes start;sleep 60;./oes open"

	echo "重启命令执行完成，请及时去MON检查oes的状态"
}

##############################################################
# Name: _fixarbiterstart
# Desc: start oes, load oes
# Args:
##############################################################
_fixarbiterstart()
{
	# 如果备机故障，再次执行一次停止OES,并清除TXLOG数据
	echo "停止主机oes,并清除TXLOG数据"
	echo "执行指令1：sh -t -t -p $sh_port $oes_user@$oes_dep_Aip \"cd host_03/${oes_dep_name}/bin;./oes stop -F\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes stop -F"

	# 启动OES
	echo "执行指令2：ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip \"cd host_03/${oes_dep_name}/bin;./oes start\""
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes start"

	echo "重启命令执行完成，请及时去MON检查oes的状态"
}

##############################################################
# Name: _isexecute
# Desc: 执行哪个方法
# Args:
##############################################################
_isexecute()
{
	case "$1" in
	master|m)
	echo "您好，准备开始执行重启交易主机(master)脚本，请耐心等待！"
	_fixleaderstart
	;;
	follow|f)
	echo "您好，准备开始执行重启交易备机(follow)脚本，请耐心等待！"
	_fixfollowstart
	;;
	arbiter|a)
	echo "您好，准备开始执行重启交易仲裁机(arbiter)脚本，请耐心等待！"
	_fixarbiterstart
	;;
	h|-h|--h|help|-help|--help)
	helpdesc
	;;
	*)
	echo ""
	echo " 非有效指令，请重新执行命令，可以输入./oes_fixed_start.sh -h 查看帮助！"
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
	echo "    参数1：重启指定机器，取值：master/m:重启主机; follow/f:重启备机; arbiter/a:重启仲裁机;"
	echo "=============================================================================="
	echo ""
	echo "执行命令例如："
	echo "        ./oes_fixed_start.sh master"
	echo "等同于：./oes_fixed_start.sh m"
	echo ""
}

_set
_isexecute $@







