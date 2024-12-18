#!/usr/bin/env bash

# 获取当前时间-MMDD
nowdate=$(date +%m%d)

# 获取当前时间-YYYYMMDD
nowdate_full=$(date +%Y%m%d)
nowdate_full_hms=$(date +%Y%m%d%H%M%S)
current_day=$(date +%d)
current_month=$(date +%m)
if (( 10#$current_month <= 9 )); then
    current_month_code=$current_month
else
    case $current_month in
        10) current_month_code="a" ;;
        11) current_month_code="b" ;;
        12) current_month_code="c" ;;
    esac
fi
# 获取当前时间的小时和分钟
current_hour=$(date +"%H")
current_minute=$(date +"%M")

# 设置上午9点的时间参数
target_hour=9
target_minute=0

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
	broker=$(grep broker automatic.yml | awk -F'[: ]+' 'NR==1{ print $2 }' | awk -F'[# ]+' 'NR==1{ print $1 }')
	#taget: dev
	taget=$(awk -F'[: ]+' '/taget/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')
	#ansible_ssh_user: oesuser
	oes_user=$(awk -F'[: ]+' '/ssh_user/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')

	# 获取主机的序号标识 master_host: "01"
	master_host_seq=$(awk -F'[: "]+' '/master_host/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取备机的序号标识 follow_host: "02"
	follow_host_seq=$(awk -F'[: "]+' '/follow_host/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')
	# 获取仲裁机的序号标识 arbiter_host: "03"
	arbiter_host_seq=$(awk -F'[: "]+' '/arbiter_host/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')

	# 主备仲裁服务器的IP地址
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

	system=$(awk -F'[: ]+' '/system/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')
	version=$(awk -F'[: ]+' '/version/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')
	counter=$(grep counter automatic.yml | awk -F '[: ]+' 'NR==1{ print $2 }' | awk -F'[# ]+' 'NR==1{ print $1 }')

	oes_dep_name=$(awk -F'[: "]+' '/oes_pkg_name/{ print $2 }' automatic.yml | awk -F'[# ]+' 'NR==1{ print $1 }')
	if [ ! ${oes_dep_name} ]; then
		oes_dep_name=$(echo ${system}-${version}-${counter})
	fi

	oes_backup_name=$(echo ${system}-${version})
}

##############################################################
# Name: _update_files
# Desc: 更新上场文件
# Args:
##############################################################
_update_files() {
    ssh -t -t -p "$sh_port" "$oes_user@$oes_dep_Lip" bash  > /dev/null 2>&1 << EOF
        current_month_code="$current_month_code"
        current_day="$current_day"
        nowdate="$nowdate"
        nowdate_full="$nowdate_full"

        cd host_01/${oes_dep_name}/data/exchange
        for file in *; do
            if [[ "\$file" =~ ^cpxx0201[0-9]{4}\.txt$ || "\$file" =~ ^cpxx0202[0-9]{4}\.txt$ ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{4}\\.txt$/\$nowdate.txt/")
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ^dbp[0-9]{4}\.txt$ ]]; then
                new_file="dbp\$nowdate.txt"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ^gzlx\\.[0-9a-c][0-9]{2}$ ]]; then
                new_file="gzlx.\$current_month_code\$current_day"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done

        cd ../broker
        for file in *; do
            if [[ "\$file" =~ (TRANSFER|XCOUNTER)\.([0-9]{8})\.(OK) ]]; then
                new_file="\${BASH_REMATCH[1]}.\${nowdate_full}.\${BASH_REMATCH[3]}"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{4}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{4}/\$nowdate/")
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done

        cd ../flags
        for file in *; do
            if [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done
	exit
EOF
        echo "###主机文件名修改完成###"
        echo ""

    ssh -t -t -p "$sh_port" "$oes_user@$oes_dep_Fip" bash >/dev/null 2>&1 << EOF
	current_month_code="$current_month_code"
        current_day="$current_day"
        nowdate="$nowdate"
        nowdate_full="$nowdate_full"

        cd host_02/${oes_dep_name}/data/exchange
        for file in *; do
            if [[ "\$file" =~ ^cpxx0201[0-9]{4}\.txt$ || "\$file" =~ ^cpxx0202[0-9]{4}\.txt$ ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{4}\\.txt$/\$nowdate.txt/")
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ^dbp[0-9]{4}\.txt$ ]]; then
                new_file="dbp\$nowdate.txt"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ^gzlx\\.[0-9a-c][0-9]{2}$ ]]; then
                new_file="gzlx.\$current_month_code\$current_day"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done

        cd ../broker
        for file in *; do
            if [[ "\$file" =~ (TRANSFER|XCOUNTER)\.([0-9]{8})\.(OK) ]]; then
                new_file="\${BASH_REMATCH[1]}.\${nowdate_full}.\${BASH_REMATCH[3]}"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{4}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{4}/\$nowdate/")
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done

        cd ../flags
        for file in *; do
            if [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done
	exit
EOF
        echo "###备机文件名修改完成###"
        echo ""

    ssh -t -t -p "$sh_port" "$oes_user@$oes_dep_Aip" bash >/dev/null 2>&1 << EOF
	current_month_code="$current_month_code"
        current_day="$current_day"
        nowdate="$nowdate"
        nowdate_full="$nowdate_full"

        cd host_03/${oes_dep_name}/data/exchange
        for file in *; do
            if [[ "\$file" =~ ^cpxx0201[0-9]{4}\.txt$ || "\$file" =~ ^cpxx0202[0-9]{4}\.txt$ ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{4}\\.txt$/\$nowdate.txt/")
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ^dbp[0-9]{4}\.txt$ ]]; then
                new_file="dbp\$nowdate.txt"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ^gzlx\\.[0-9a-c][0-9]{2}$ ]]; then
                new_file="gzlx.\$current_month_code\$current_day"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done

        cd ../broker
        for file in *; do
            if [[ "\$file" =~ (TRANSFER|XCOUNTER)\.([0-9]{8})\.(OK) ]]; then
                new_file="\${BASH_REMATCH[1]}.\${nowdate_full}.\${BASH_REMATCH[3]}"
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{4}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{4}/\$nowdate/")
                mv "\$file" "\$new_file"
            elif [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done

        cd ../flags
        for file in *; do
            if [[ "\$file" =~ ([0-9]{8}) ]]; then
                new_file=\$(echo "\$file" | sed -E "s/[0-9]{8}/\$nowdate_full/")
                mv "\$file" "\$new_file"
            fi
        done
	exit
EOF

        echo "###仲裁机文件名修改完成###"
        echo ""
}

##############################################################
# Name: _restart
# Desc: start oes, load oes
# Args:
##############################################################
_restart()
{
	#停止OES
	echo "###主备仲裁模式停止oes###"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes stop -F"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes stop -F"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes stop -F"

	#启动OES
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes start"
	sleep 60
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes start"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes start"
	
	sleep 5
	#修改reset状态&#修改Ezoes数据库检查状态&两地资金划拨状态  
        ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes taskstatus -k reset -S 5;./oes ts -k EZOES_OIW_CHECK -S 5;./oes ts  -k CASH_ALLOT -S 5 -m '人工执行'"
        ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes taskstatus -k reset -S 5;./oes ts -k EZOES_OIW_CHECK -S 5;./oes ts  -k CASH_ALLOT -S 5 -m '人工执行'"
        ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/bin;./oes taskstatus -k reset -S 5;./oes ts -k EZOES_OIW_CHECK -S 5;./oes ts  -k CASH_ALLOT -S 5 -m '人工执行'"	

	sleep 30
	#开工
if [ "$current_hour" -lt "$target_hour" ] || (["$current_hour" -eq "$target_hour" ] && [ "$current_minute" -lt "$target_minute" ]); then
  		echo "当前时间在上午9点之前,不执行open"
else
 		 echo "当前时间在上午9点之后,执行open"
		ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/bin;./oes open"
		ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/bin;./oes open"
fi
	echo "重启启动命令执行完成，请及时去MON检查oes的状态"
}


_set
_update_files
_restart
