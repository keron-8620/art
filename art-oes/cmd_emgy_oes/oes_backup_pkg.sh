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

_isexecute()
{
      echo "备份art-oes主机配置"
      tar -zcvf automatic.yml-bak-${nowdate_full}.tar.gz automatic.yml cmd cmd_emgy_oes inventory plugins scripts swf_playbooks README.txt art.py
      tar -zcvf automatic.yml-bak-${nowdate_full}.tar.gz automatic.yml cmd cmd_emgy_oes inventory plugins scripts swf_playbooks README.txt art.py
      tar -zcvf files/bin.conf-bak-${nowdate_full}.tar.gz files/bin files/config
     
      echo "备份mon主机配置"
      ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_dep_name; tar -zcvf mon-bak-${nowdate_full}.tar.gz database config"
      
      echo "备份mon导出目录"
      ssh -t -t -p $sh_port $mon_user@$mon_dep_ip "cd $mon_ep_dir; tar -zcvf mon-bak-${nowdate_full}.tar.gz oes mds"   
      
      echo "备份oes主机"
      ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01; tar -zcvf oes-${version}-bak-${nowdate_full}.tar.gz ${oes_dep_name}/bin ${oes_dep_name}/conf ${oes_dep_name}/data ${oes_dep_name}/logs ${oes_dep_name}/sample ${oes_dep_name}/sbin"

      echo "备份oes备机"
      ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02; tar -zcvf oes-${version}-bak-${nowdate_full}.tar.gz ${oes_dep_name}/bin ${oes_dep_name}/conf ${oes_dep_name}/data ${oes_dep_name}/logs ${oes_dep_name}/sample ${oes_dep_name}/sbin"

      echo "备份oes仲裁机"
      ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03; tar -zcvf oes-${version}-bak-${nowdate_full}.tar.gz ${oes_dep_name}/bin ${oes_dep_name}/conf ${oes_dep_name}/data ${oes_dep_name}/logs ${oes_dep_name}/sample ${oes_dep_name}/sbin"
}

_set
_isexecute
