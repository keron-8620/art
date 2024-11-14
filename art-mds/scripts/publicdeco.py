#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
import sys
import os
import re
from constants import CONF
from run_command import Run_Command


def checkuser(func):
    def wrapper(*args, **kwargs):
        job_run_user_dict = Run_Command('id {}'.format(CONF['job_run_user']))
        job_run_user_uid = re.search(r'id=(\d+)', job_run_user_dict['response'])
        if os.geteuid() != int(job_run_user_uid.group(1)):
            print('The current user is not %s, please switch' % CONF['job_run_user'])
            sys.exit(5)
        func(*args, **kwargs)
    return wrapper

