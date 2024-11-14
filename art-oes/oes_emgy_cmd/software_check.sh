#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

export ANSIBLE_SSH_CONTROL_PATH_DIR=~/.ansile/test

/usr/local/bin/python3 scripts/action.py -asoftware_check



