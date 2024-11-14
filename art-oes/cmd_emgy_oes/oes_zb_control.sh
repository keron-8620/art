#!/usr/bin/env bash

basepath=$(cd `dirname $0`; pwd)

cd $basepath/..

args_str=$@

python3.8 scripts/control_disaster_recovery.py $args_str
