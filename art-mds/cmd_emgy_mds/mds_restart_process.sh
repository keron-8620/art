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
# mds备份目录名称
mds_backup_name=""

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

	# 获取主机的序号标识 master_host: "01"
	master_host_seq=$(awk -F'[: "]+' '/master_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取备机的序号标识 follow_host: "02"
	follow_host_seq=$(awk -F'[: "]+' '/follow_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取仲裁机的序号标识 arbiter_host: "03"
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

	# 获得系统信息 system: mds
	system=$(awk -F'[: ]+' '/system/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获得版本信息 version: xxx
	version=$(awk -F'[: ]+' '/version/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	# 柜台信息
	counter=$(grep counter automatic.yml |awk -F '[: ]+' 'NR==1{print $2}'| awk -F'[# ]+' 'NR==1{ print $1 }')

	# 兼容0.15.8的art版本
	mds_dep_name=$(awk -F'[: "]+' '/mds_pkg_name/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
	if [ ! ${mds_dep_name} ]; then
		mds_dep_name=$(echo ${system}-${version}-${counter})
	fi

	mds_backup_name=$(echo ${system}-${version})
}

_RestartusAll()
{
	#重启主备仲裁的进程
	echo "开始Restatus"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin;./$i sp -F;kill -9 `ps -ef|grep mdsuser|grep -wE "./${1}|${1}"|awk '{print $2}'`;./${1} sp -F;./${1} st"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/bin;./$i sp -F;kill -9 `ps -ef|grep mdsuser|grep -wE "./${1}|${1}"|awk '{print $2}'`;./${1} sp -F;./${1} st"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03/${mds_dep_name}/bin;./$i sp -F;kill -9 `ps -ef|grep mdsuser|grep -wE "./${1}|${1}"|awk '{print $2}'`;./${1} sp -F;./${1} st"

	echo "主备仲裁Restatus命令执行完成"
}


_RestartLeader()
{
	#重启主机的进程
	echo "开始Restatus"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin;./$i sp -F;kill -9 `ps -ef|grep mdsuser|grep -wE "./${1}|${1}"|awk '{print $2}'`;./${1} sp -F;./${1} st"

	echo "主机Restatus命令执行完成"
}


_RestartFollow()
{
	#重启备机的进程
	echo "开始Restatus"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/bin;./$i sp -F;kill -9 `ps -ef|grep mdsuser|grep -wE "./${1}|${1}"|awk '{print $2}'`;./${1} sp -F;./${1} st"

	echo "备机Restatus命令执行完成"
}


_RestartArbiter()
{
	#重启仲裁的进程
	echo "开始Restatus"
	ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03/${mds_dep_name}/bin;./$i sp -F;kill -9 `ps -ef|grep mdsuser|grep -wE "./${1}|${1}"|awk '{print $2}'`;./${1} sp -F;./${1} st"

	echo "仲裁Restatus命令执行完成"
}




#指定的进程
array=(querier processor publisher)
#输入的进程名
i=$#
array1="${@: 2:$i}"

_help()
{
echo "  可以重启单个进程 或多个进程
        重启主机: sh mds_restart_process.sh m querier processor publisher
        --------------------------------------------------------------
        重启备机: sh mds_restart_process.sh f querier processor publisher
        --------------------------------------------------------------
        集群重启: sh mds_restart_process.sh all querier processor publisher
        -------------------------------------------------------------
        例如sh mds_restart_process.sh m querier processor publisher"

}


_set
if [[ $1 == m ]];then
	for i in ${array1[*]}
	do
		[[ ${array[@]/${i}/} != ${array[@]} ]] && _RestartLeader $i || echo "未有$i 参数，不执行"
	done

elif [[ $1 == f ]];then
	for i in ${array1[*]}
	do
		[[ ${array[@]/${i}/} != ${array[@]} ]] && _RestartFollow $i || echo "未有$i 参数，不执行"
	done
	
elif [[ $1 == a ]];then
	for i in ${array1[*]}
	do
		[[ ${array[@]/${i}/} != ${array[@]} ]] && _RestartArbiter $i || echo "未有$i 参数，不执行"
	done
	
elif [[ $1 == all ]];then
	for i in ${array1[*]}
	do
		[[ ${array[@]/${i}/} != ${array[@]} ]] && _RestartusAll $i || echo "未有$i 参数，不执行"
	done
	
elif [[ $1 == help ]];then
		_help
else
_help
fi	









