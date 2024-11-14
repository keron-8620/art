#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
import constants as C
import os

curr_path = os.path.abspath(os.path.dirname(__file__))
deploy_path = os.path.abspath(os.path.join(curr_path, '..'))
load_check_file = os.path.abspath(os.path.join(deploy_path, 'swf_playbooks', 'swf_oes', 'control', 'load', 'load_check.yml'))

line_num = 0
list_str = []
automatic_is_csdc_register = C.CONF["csdc_cron_register"]

if (automatic_is_csdc_register) == (False):
    with open(load_check_file) as f:
        j = 1
        for csdc_ok in f.readlines():
            if csdc_ok[10:23] == 'fetch_csdc_ok':
                line_num = j
                csdc_ok = "#"+csdc_ok
                list_str.append(csdc_ok)


            else:
                j = j+1
                list_str.append(csdc_ok)
    new_load_file = ''.join(list_str)

    with open(load_check_file, 'r+', encoding='utf-8') as f:
        f.write(new_load_file)

else:
    with open(load_check_file) as f:
        j = 1
        for csdc_ok in f.readlines():
            if csdc_ok[:28] == '#    - \"{{ fetch_csdc_ok }}\"':
                line_num = j
                csdc_ok = csdc_ok.replace('#', '')
                list_str.append(csdc_ok)

            else:
                j = j + 1
                list_str.append(csdc_ok)
    new_load_file = ''.join(list_str)

    with open(load_check_file, 'r+', encoding='utf-8') as f:
        f.write(new_load_file)