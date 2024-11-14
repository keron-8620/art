#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

/usr/local/bin/python3 scripts/action.py -aclean_txlog


