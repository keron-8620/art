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

# mds部署用户名称
mds_user=mdsuser

# mds主备仲裁服务器的IP地址
mds_dep_Lip=""
mds_dep_Fip=""
mds_dep_Aip=""

# mds目录名称
mds_dep_name=""

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
# Name: _fixleaderstart
# Desc: clear txlog, cp follow tx to leader, start mds, load mds
# Args:
##############################################################
_fixleaderstart()
{
	# 如果主机故障，再次执行一次停止MDS,并清除TXLOG数据
	echo "停止主机mds,并清除TXLOG数据"
	echo "执行指令1：ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip \"cd host_01/${mds_dep_name}/bin;./mds stop -F;rm -rf ../txlog/TXLOG_*\""
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin;./mds stop -F;rm -rf ../txlog/TXLOG_*"

	# 拷贝备机上面的行情日志到主机
	echo "执行指令2：ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip \"cd host_02/${mds_dep_name}/data;scp -r * ${mds_user}@${mds_dep_Lip}:/home/${mds_user}/host_01/${mds_dep_name}/data/.\""
	#ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/txlog;scp -r TXLOG_* ${mds_user}@${mds_dep_Lip}:/home/${mds_user}/host_01/${mds_dep_name}/txlog/."
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/data;scp -r * ${mds_user}@${mds_dep_Lip}:/home/${mds_user}/host_01/${mds_dep_name}/data/."

	# 启动MDS
	echo "执行指令3：ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip \"cd host_01/${mds_dep_name}/bin;./mds start\""
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin;./mds start"

	echo "重启命令执行完成，请及时去MON检查mds的状态"
}

##############################################################
# Name: _fixfollowstart
# Desc: clear txlog, cp leader tx to follow, start mds, load mds
# Args:
##############################################################
_fixfollowstart()
{
	# 如果备机故障，再次执行一次停止MDS,并清除TXLOG数据
	echo "停止主机mds,并清除TXLOG数据"
	echo "执行指令1：ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip \"cd host_02/${mds_dep_name}/bin;./mds stop -F;rm -rf ../txlog/TXLOG_*\""
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/bin;./mds stop -F;rm -rf ../txlog/TXLOG_*"

	# 拷贝备机上面的行情日志到备机
	echo "执行指令2：ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip \"cd host_01/${mds_dep_name}/data;scp -r * ${mds_user}@${mds_dep_Fip}:/home/${mds_user}/host_02/${mds_dep_name}/data/.\""
	#ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/txlog;scp -r TXLOG_* ${mds_user}@${mds_dep_Fip}:/home/${mds_user}/host_02/${mds_dep_name}/txlog/."
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/data;scp -r * ${mds_user}@${mds_dep_Fip}:/home/${mds_user}/host_02/${mds_dep_name}/data/."

	# 启动MDS
	echo "执行指令3：ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip \"cd host_02/${mds_dep_name}/bin;./mds start\""
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/bin;./mds start"

	echo "重启命令执行完成，请及时去MON检查mds的状态"
}

##############################################################
# Name: _fixarbiterstart
# Desc: start mds, load mds
# Args:
##############################################################
_fixarbiterstart()
{
	# 如果备机故障，再次执行一次停止MDS,并清除TXLOG数据
	echo "停止主机mds,并清除TXLOG数据"
	echo "执行指令1：sh -t -t -p $sh_port $mds_user@$mds_dep_Aip \"cd host_03/${mds_dep_name}/bin;./mds stop -F\""
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03/${mds_dep_name}/bin;./mds stop -F"

	# 启动MDS
	echo "执行指令2：ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip \"cd host_03/${mds_dep_name}/bin;./mds start\""
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03/${mds_dep_name}/bin;./mds start"

	echo "重启命令执行完成，请及时去MON检查mds的状态"
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
	echo "您好，准备开始执行重启行情主机(master)脚本，请耐心等待！"
	_fixleaderstart
	;;
	follow|f)
	echo "您好，准备开始执行重启行情备机(follow)脚本，请耐心等待！"
	_fixfollowstart
	;;
	arbiter|a)
	echo "您好，准备开始执行重启行情仲裁机(arbiter)脚本，请耐心等待！"
	_fixarbiterstart
	;;
	h|-h|--h|help|-help|--help)
	helpdesc
	;;
	*)
	echo ""
	echo " 非有效指令，请重新执行命令，可以输入./mds_fixed_start.sh -h 查看帮助！"
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
	echo "        ./mds_fixed_start.sh master"
	echo "等同于：./mds_fixed_start.sh m"
	echo ""
}

_set
_isexecute $@
