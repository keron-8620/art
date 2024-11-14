#!/usr/bin/env bash

_curr_date=$(date +%Y%m%d)

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

export ANSIBLE_SSH_CONTROL_PATH_DIR=~/.ansile/test

/usr/local/bin/python3 scripts/action.py -aping



