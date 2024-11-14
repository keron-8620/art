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
mds_user="mdsuser"

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
	# 获取主机的id 192.168.10.120 swf-mds-hlzq-dev-01
	if [ $(echo ${master_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		mds_dep_Lip=${master_host_seq}
	else
		mds_dep_Lip=$(grep swf-mds-${broker}-${taget}-${master_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	if [ $(echo ${follow_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		mds_dep_Fip=${follow_host_seq}
	else
		mds_dep_Fip=$(grep swf-mds-${broker}-${taget}-${follow_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
	if [ $(echo ${arbiter_host_seq} | awk -F"." '{print NF-1}') -eq 3 ]; then
		mds_dep_Aip=${arbiter_host_seq}
	else
		mds_dep_Aip=$(grep swf-mds-${broker}-${taget}-${arbiter_host_seq} /etc/hosts | awk -F '[ "]+' '{print $1}')
	fi
    
        # 获取mon主机用户和IP地址
        mon_user=$(grep mon_user automatic.yml|awk -F' ' '{print $2}')
        mon_dep_ip=$(grep mon_host automatic.yml|awk -F' ' '{print $2}')

        # 获得art版本信息
        art_system=$(cd $(dirname "$PWD")|xargs python3 art.py -v|grep art |grep -v config|awk -F' ' '{print $2}')
        #art-mds备份目录名
        art_backup_name=$(echo 'art-mds'-${art_system})

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

_isexecute()
{
        echo "备份art-mds主机"
        tar -zcvf automatic.yml-bak-${nowdate_full}.tar.gz automatic.yml cmd cmd_emgy_mds inventory plugins scripts swf_playbooks README.txt art.py
        tar -zcvf files/bin.conf-bak-${nowdate_full}.tar.gz files/bin files/config
        
        echo "备份mds主机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01; tar -zcvf mds-${version}-bak-${nowdate_full}.tar.gz ${mds_dep_name}/bin ${mds_dep_name}/conf ${mds_dep_name}/data ${mds_dep_name}/logs ${mds_dep_name}/sample ${mds_dep_name}/sbin"

        echo "备份mds备机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02; tar -zcvf mds-${version}-bak-${nowdate_full}.tar.gz ${mds_dep_name}/bin ${mds_dep_name}/conf ${mds_dep_name}/data ${mds_dep_name}/logs ${mds_dep_name}/sample ${mds_dep_name}/sbin"

        echo "备份mds仲裁机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03; tar -zcvf mds-${version}-bak-${nowdate_full}.tar.gz ${mds_dep_name}/bin ${mds_dep_name}/conf ${mds_dep_name}/data ${mds_dep_name}/logs ${mds_dep_name}/sample ${mds_dep_name}/sbin"
}
_set
_isexecute







