#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

export ANSIBLE_SSH_CONTROL_PATH_DIR=~/.ansible/nakedstart

action="nakedstart"

TEMP=`getopt -o thd: -a -l status,help,date: -n "test.sh" -- "$@"`
# 判定 getopt 的执行时候有错，错误信息输出到 STDERR
# 选项后接一个冒号表示其后为其参数值，选项后接两个冒号表示其后可以有也可以没有选项值，选项后没有冒号表示其后不是其参数值
if [ $? != 0 ]
then
	echo "Terminating....." >&2
	exit 1
fi

eval set -- "$TEMP"

while true
do
    case "$1" in
        -t | --status)
            /usr/local/bin/python3 scripts/status.py -a $action
            shift
            break
            ;;

        -h | --help)
            /usr/local/bin/python3 scripts/help.py -a $action
            shift
            break
            ;;
        -d | --date)
            date="$2"
            /usr/local/bin/python3 scripts/action.py -a $action -d $date
            shift
            break
            ;;

        --)
            /usr/local/bin/python3 scripts/action.py -a $action
            shift
            break
            ;;
        *)
            echo "Internal error!"
            exit 1
            ;;

    esac
done


