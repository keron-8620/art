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

# 交易日期YYYYMMDD
tradedate_full=""
# 交易日期MMDD
tradedate=""
# 交易日期MDD,用于修改国债日期文件
tradedate_md=""

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
}

##############################################################
# Name: _gentestdata
# Desc: generate test data
# Args:
##############################################################
_gentestdata()
{
	#手工生成周末测试数据
	#1、准备数据，sh命令到主机上面执行相关命令
	#   查找最新的oes的备份的data数据
	#   解压data数据，修改产品数据交易日期，根据需要改成当前日期
	#   根据data数据格式，查找最新的oes的备份的broker数据
	#   解压broker数据，修改交易日，改成当前日期，并复制到data的broker目录下面
	#2、复制数据，制造的data数据
	#   拷贝到oes的生产运行目录上面(/home/oesuser/host_01/oes-0.15.9-release)
	#   从oes主机拷贝数据回art到临时目录下面，并删除oes里面的刚才解压处理的临时数据
	#   从art主机将oes的data数据分发到oes备机器和oes仲裁机上面
	#   删除art主机上面的临时data数据
	#3、修正数据，如果data里面的数据，有部分可以获取，则执行如下命令
	#   获取并分发MON数据：mon.sh YYYYMMDD,同时修正TradingDate.txt里面的交易日期
	#   获取并分发主柜数据：counter_fetch.sh YYYYMMDD、counter_distribute.sh YYYYMMDD
	#   获取并分发上海产品文件数据：sse.sh YYYYMMDD
	#   获取并分发深圳产品文件数据：szse.sh YYYYMMDD
	#   获取并分发中登文件数据：csdc.sh YYYYMMDD
	#4、制造ok文件，执行cmd_emgency_oes里面的oes_okflag.sh脚本

	tradedate_full=$1
	tradedate=$(echo $tradedate_full | cut -c 5-8)

	#国债利息的文件名称后缀获取方法
	tradedate_month=$(echo $tradedate_full | cut -c 5-6)
	tradedate_md=$(echo $tradedate_full | cut -c 7-8)
	tradedate_month_num=`expr ${tradedate_month} + 0`

	if [ $tradedate_month_num -eq 10 ] ; then
		tradedate_month="a"
	elif [ $tradedate_month_num -eq 11 ] ; then
		tradedate_month="b"
	elif [ $tradedate_month_num -eq 12 ] ; then
		tradedate_month="c"
	else
		tradedate_month="$tradedate_month_num"
	fi

	tradedate_md=${tradedate_month}${tradedate_md}
	# 获得测试数据备份文件名称
	testdata=$(ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "find /home/oesuser/host_01/backup/ -name data-*.tar.gz -type f -print | sort -b -k1 -r | awk 'NR==1{print}';" |sed 's/\r//' )
	testbroker=`echo $testdata |sed  's/data/broker/g'`;
	oldmd=`echo $testdata |awk -F'/' '{print $NF}' | cut -c 10-13`;
	oldymd=`echo $testdata |awk -F'/' '{print $NF}' | cut -c 6-13`;

	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/backup;tar -zxvf ${testdata};tar -zxvf ${testbroker};cp -rf broker data/.;rm -rf broker;cd data;rename ${oldmd} ${tradedate} broker/*;rename ${oldymd} ${tradedate_full} flags/*;rename ${oldmd}.txt ${tradedate}.txt exchange/*;rename ${oldymd}.xml ${tradedate_full}.xml exchange/*;cd exchange;rename gzlx.* gzlx.${tradedate_md} *;cd ..;rename ${oldmd}.ETF ${tradedate}.ETF exchange/sse_etf/*;rename ${oldymd}.xml ${tradedate_full}.xml exchange/szse_etf/*;sed -i -e \"s|EffectiveDate.*|EffectiveDate = $nowdate_full|\" TradingDate.txt;sed -i -e \"s|TradingDate.*|TradingDate = $tradedate_full|\" TradingDate.txt;cd ..;tar -zcvf testdata_${tradedate_full}.tar.gz data;cp -rf data ../../host_01/${oes_dep_name}/.;rm -rf data;"
	echo "主机数据生成脚本已经执行完毕，请检查！"

	echo "开始分发数据到备机和仲裁机"
	cd $basepath/files
	scp ${oes_user}@${oes_dep_Lip}:/home/${oes_user}/host_01/backup/testdata_${tradedate_full}.tar.gz .
	tar -zxvf testdata_${tradedate_full}.tar.gz
	scp -r data ${oes_user}@${oes_dep_Fip}:/home/${oes_user}/host_02/${oes_dep_name}/.
	scp -r data ${oes_user}@${oes_dep_Aip}:/home/${oes_user}/host_03/${oes_dep_name}/.
	rm -rf testdata_${tradedate_full}.tar.gz
	rm -rf data

	echo "开始执行补充脚本，如果有当前产品文件、主柜数据可以获取，都可以拉取！"
	cd $basepath/cmd
	sh mon.sh ${tradedate_full}
	sh counter_fetch.sh ${tradedate_full}
	sh counter_distribute.sh ${tradedate_full}
	sh sse.sh ${tradedate_full}
	sh szse.sh ${tradedate_full}
	sh csdc.sh ${tradedate_full}

	echo "执行art脚本拷贝后，TradingDate.txt里面的日期重新处理!"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Lip "cd host_01/${oes_dep_name}/data;sed -i -e \"s|EffectiveDate.*|EffectiveDate = $nowdate_full|\" TradingDate.txt;sed -i -e \"s|TradingDate.*|TradingDate = $tradedate_full|\" TradingDate.txt;"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Fip "cd host_02/${oes_dep_name}/data;sed -i -e \"s|EffectiveDate.*|EffectiveDate = $nowdate_full|\" TradingDate.txt;sed -i -e \"s|TradingDate.*|TradingDate = $tradedate_full|\" TradingDate.txt;"
	ssh -t -t -p $sh_port $oes_user@$oes_dep_Aip "cd host_03/${oes_dep_name}/data;sed -i -e \"s|EffectiveDate.*|EffectiveDate = $nowdate_full|\" TradingDate.txt;sed -i -e \"s|TradingDate.*|TradingDate = $tradedate_full|\" TradingDate.txt;"

	echo "生成OK文件"
	cd $basepath/cmd_emgy_oes
	sh oes_okflag.sh ${tradedate_full}

	echo "上场数据制造完毕，请检查"
}

##############################################################
# Name: _isexecute
# Desc: 执行哪个方法
# Args:
##############################################################
_isexecute()
{
	case "$1" in
	h|-h|--h|help|-help|--help)
	helpdesc
	;;
	*)
	if [ -z "$1" ];then
		echo "您好，准备开始执行生成测试数据命令，请耐心等待！"
		_gentestdata ${nowdate_full}
		return;
	else
		date -d "$1" "+%Y%m%d"|grep -q "$1" 2>/dev/null
		if [ $? = 0 ]; then
			echo "您好，准备开始执行生成测试数据命令，请耐心等待！"
			formatdate=$(date -d "$1" "+%Y%m%d")
			_gentestdata $formatdate
			return;
		else
			echo ""
			echo " 非有效指令，请重新执行命令，可以输入./oes_testdata_make.sh -h 查看帮助！"
			echo ""
		fi 
	fi
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
	echo "Usage: testdata_make command [options] [args]"
	echo ""
	echo "Commands are:"
	echo "    参数1：指定交易日,可以为空，如果不填参数默认使用当前日期作为交易日;"
	echo "=============================================================================="
	echo ""
	echo "执行命令例如："
	echo "        ./oes_testdata_make.sh 20191111"
	echo ""
}

_set
_isexecute $@





