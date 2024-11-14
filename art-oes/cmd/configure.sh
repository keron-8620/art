#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

TEMP=`getopt -o th -a -l help,status:: -n "test.sh" -- "$@"`
# 判定 getopt 的执行时候有错，错误信息输出到 STDERR
if [ $? != 0 ]
then
	echo "Terminating....." >&2
	exit 1
fi

eval set -- "$TEMP"

while true
do
    case "$1" in
        -h | --help)
            /usr/local/bin/python3 scripts/help.py -aconfigure
            shift
            break
            ;;

		--)
		    /usr/local/bin/python3 scripts/init_conf.py
			shift
			break
			;;
		*)
			echo "Internal error!"
			exit 1
            ;;

    esac
done




