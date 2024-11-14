#!/usr/bin/env bash
#Date:2021-11-24
#Author:dounpe
#Mail:dpliu@quant360.com

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
    
        # 获取mon主机用户和IP地址
        mon_user=$(grep mon_user automatic.yml|awk -F' ' '{print $2}')
        mon_dep_ip=$(grep mon_host automatic.yml|awk -F' ' '{print $2}')

        # 获得art版本信息
        art_system=$(cd $(dirname "$PWD")|xargs python3 art.py -v|grep art |grep -v config|awk -F' ' '{print $2}')
        #art-oes备份目录名
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
    echo "回滚art-mds主机"
	tar -zxvf automatic.yml-bak-${nowdate_full}.tar.gz 
	tar -zxvf files/bin.conf-bak-${nowdate_full}.tar.gz  
        echo "回滚mds主机"
		ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin; cd ../..; tar -zxvf mds-${version}-bak-${nowdate_full}.tar.gz"

        echo "回滚mds备机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/bin; cd ../..; tar -zxvf mds-${version}-bak-${nowdate_full}.tar.gz"

        echo "回滚mds仲裁机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03/${mds_dep_name}/bin; cd ../..; tar -zxvf mds-${version}-bak-${nowdate_full}.tar.gz"
}
_set
case "$1" in
        -d | --date)
            date="$2"			
		 echo "回滚automatic.yml"
		 at_file=$(ls ../ | grep automatic.yml-bak-${date}.tar.gz)
		 if [ ! -n "$at_file" ] ; then
		    echo "Internal error! 未检测到对应日期备份automatic.yml文件，请检查备份日期是否正确"
		    break
      else
         cd ..;tar -zxvf automatic.yml-bak-${date}.tar.gz
          _set
	read -p $name"请输入回滚版本:" version
	while [ true ]
	do
      while [ ! -n "$version" ]
      do
      read -p $name"请输入回滚版本: 例:0.17.4.2" version
      echo "回滚版本为" $version
      done 
	  files=$(ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin; cd ../..; ls |grep mds-${version}-bak-${date}.tar.gz")
          echo $files
          echo "-------------------------------------"
	  if [ ! -n "$files" ]; then
              echo "Internal error!,未检测到对应版本的备份文件请检查备份日期或者版本信息"
              break	
      else
	       echo $files
        echo "回滚art-mds主机"
        tar -zxvf automatic.yml-bak-${date}.tar.gz
        tar -zxvf files/bin.conf-bak-${date}.tar.gz
        echo "回滚mds主机"
                ssh -t -t -p $sh_port $mds_user@$mds_dep_Lip "cd host_01/${mds_dep_name}/bin; cd ../..; tar -zxvf mds-${version}-bak-${date}.tar.gz"

        echo "回滚mds备机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Fip "cd host_02/${mds_dep_name}/bin; cd ../..; tar -zxvf mds-${version}-bak-${date}.tar.gz"

        echo "回滚mds仲裁机"
        ssh -t -t -p $sh_port $mds_user@$mds_dep_Aip "cd host_03/${mds_dep_name}/bin; cd ../..; tar -zxvf mds-${version}-bak-${date}.tar.gz"
            break
   	fi    
    done
	fi
      shift
      break ;;

        -r)
            _isexecute
            shift
            break
            ;;
        *)
            echo "Internal error! 请输入正确参数 -d 20211020（指定回滚备份日期）,-r (回滚当日备份)"
            exit 1
            ;;

    esac


