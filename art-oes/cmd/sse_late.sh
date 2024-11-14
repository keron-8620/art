#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

export ANSIBLE_SSH_CONTROL_PATH_DIR=~/.ansible/sse_gateway

action="sse_late_collector"

TEMP=`getopt -o thd:c -a -l status,help,date:,cmd_oes,skip_etf -n "test.sh" -- "$@"`
# 判定 getopt 的执行时候有错，错误信息输出到 STDERR
# 选项后接一个冒号表示其后为其参数值，选项后接两个冒号表示其后可以有也可以没有选项值，选项后没有冒号表示其后不是其参数值
if [ $? != 0 ]
then
	echo "Terminating....." >&2
	exit 1
fi

eval set -- "$TEMP"
runargs=${TEMP%--}

while true
do
    case "$1" in
        -t | --status)
            /usr/local/bin/python3 scripts/art_modules/status.py -a $action
            shift
            break
            ;;

        -h | --help)
            /usr/local/bin/python3 scripts/art_modules/help.py -a $action
            shift
            break
            ;;
        -d | --date)
            date="$2"
            /usr/local/bin/python3 scripts/action.py -a $action -d $date
            exit $?
            shift
            break
            ;;
        -c | --cmd_oes)
            /usr/local/bin/python3 scripts/action.py -a $action -c
            exit $?
            shift
            break
            ;;
        --skip_etf)
            /usr/local/bin/python3 scripts/action.py -a $action --skip_etf
            exit $?
            shift
            break
            ;;
        --)
            /usr/local/bin/python3 scripts/action.py -a $action
            exit $?
            shift
            break
            ;;
        *)
            cmd="/usr/local/bin/python3 scripts/action.py -a $action $runargs"
            python3 scripts/run_command.py $cmd
            exit $?
            shift
            break
            ;;

    esac
done
