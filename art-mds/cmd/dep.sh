#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

sh cmd/configure.sh

export ANSIBLE_SSH_CONTROL_PATH_DIR=~/.ansible/dep

/usr/local/bin/python3 scripts/action.py -adep
