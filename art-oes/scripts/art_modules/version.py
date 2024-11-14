#!/usr/local/bin/python3
# -*- coding: utf-8 -*-

import yaml
import os

curr_path = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(curr_path, '../data/art_info.yml')) as f:
    art_info = yaml.load(f)

VersionInfo = art_info.get('version_info')

space = '  '


def print_title():
    name = VersionInfo.get('name', '')
    version = VersionInfo.get('version', '')
    title = name + " " + version
    print(title)


def print_update_time():
    key = 'update time'
    value = VersionInfo.get('update_time', '')
    update_time = space + key + ' = ' + value
    print(update_time)


def print_config_file():
    key = 'art config file'
    value = './' + VersionInfo.get('config_file', '')
    config_file = space + key + " = " + value
    print(config_file)


def print_ansible_config_file():
    key = 'ansible config file'
    value = './' + VersionInfo.get('ansible_config_file', '')
    config_file = space + key + " = " + value
    print(config_file)


def print_rely_on_python3():
    key = 'rely on python3'
    value = VersionInfo.get('rely_on_python3', '')
    rely_on_python3 = space + key + ' = ' + value
    print(rely_on_python3)


def print_rely_on_ansible():
    key = 'rely on ansible'
    value = VersionInfo.get('rely_on_ansible', '')
    rely_on_ansible = space + key + " = " + value
    print(rely_on_ansible)



