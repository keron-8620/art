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
# Name: _cancelreporter
# Desc: cancel receiver reporter onload restart
# Args:
##############################################################
_cancelreporter()
{
        #检查onload进程是否开启
        if ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip grep -q "^#reporter.startupExe" "host_01/${oes_dep_name}/conf/system.conf"; then
                echo "" 
	        echo "reporter进程onload功能已经是关闭状态，不需要重启服务，请检查配置。"
		echo ""
        else
        #关闭onload进程
                ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "sed -i '/^reporter.startupExe/,+2 s/^/#/' 'host_01/${oes_dep_name}/conf/system.conf'"
		echo ""
                echo "已关闭reporter的onload功能，即将进行重启操作。"
		echo ""
        sleep 5
                ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./reporter sp -F;./reporter st"
    	        echo ""
                echo "reporter进程重启完成，请检查！"
		echo ""

        fi

}


##############################################################
# Name: _cancelreceiver
# Desc: cancel receiver onload restart
# Args:
##############################################################
_cancelreceiver()
{
        #检查onload进程是否开启
        if ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip grep -q "^#receiver.startupExe" "host_01/${oes_dep_name}/conf/system.conf"; then
                echo ""
		echo "receiver进程onload功能已经是关闭状态，不需要重启服务，请检查配置。"
		echo ""
        else
        #关闭onload进程
                ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "sed -i '/^receiver.startupExe/,+2 s/^/#/' 'host_01/${oes_dep_name}/conf/system.conf'"
                echo ""
		echo "已关闭receiver的onload功能，即将进行重启操作。"
		echo ""
        sleep 5
                ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./receiver sp -F;./receiver st"
                echo ""
		echo "receiver进程重启完成，请检查！"
		echo ""
                                
        fi

}


##############################################################
# Name: _cancelall
# Desc: cancel receiver reporter onload restart
# Args:
##############################################################
_cancelall()
{
	#检查onload进程是否开启
	if ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip grep -q "^#receiver.startupExe" "host_01/${oes_dep_name}/conf/system.conf" &&
   		ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip grep -q "^#reporter.startupExe" "host_01/${oes_dep_name}/conf/system.conf"; then
    		echo ""
		echo "receiver和reporter进程onload功能已经是关闭状态，不需要重启服务，请检查配置。"
		echo ""
	else
	#关闭onload进程
    		ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "sed -i '/^receiver.startupExe/,+2 s/^/#/' 'host_01/${oes_dep_name}/conf/system.conf'"
    		ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "sed -i '/^reporter.startupExe/,+2 s/^/#/' 'host_01/${oes_dep_name}/conf/system.conf'"
		echo ""
		echo "已关闭receiver和reporter的onload功能，即将进行重启操作。"
		echo ""
	sleep 5
		ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./receiver sp -F;./receiver st"
		ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./reporter sp -F;./reporter st"
		echo ""
		echo "receiver和reporter进程重启完成，请检查！"
		echo ""
				
	fi

}

##############################################################
# Name: _isexecute
# Desc: 执行哪个方法
# Args:
##############################################################
_isexecute()
{
        case "$1" in
        receiver)
        _cancelreceiver
        ;;
        reporter)
        _cancelreporter
        ;;
	all)
	_cancelall
	;;
        h|-h|--h|help|-help|--help)
        helpdesc
        ;;
        *)
        echo ""
        echo " 非有效指令，请重新执行命令，可以输入./cancel_onload_restart.sh -h 查看帮助！"
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
        echo "Usage: restart command [options] [args]"
        echo ""
        echo "Commands are:"
        echo "    参数说明:"
	echo "    receiver:关闭receiver子进程onload功能并重启;"
        echo "    reporter:关闭reporter子进程onload功能并重启;"
        echo "         all:关闭receiver和reporter子进程onload功能并重启;"
        echo "=============================================================================="
        echo ""
        echo "执行命令参考："
        echo "        ./cancel_onload_restart.sh receiver"
        echo "        ./cancel_onload_restart.sh reporter"
        echo "        ./cancel_onload_restart.sh all"
        echo ""
}

_set
_isexecute $@






