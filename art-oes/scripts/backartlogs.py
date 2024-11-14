#!/usr/bin/python3
# -*-coding: utf-8-*-
import os
import time
import subprocess


today = time.strftime('%Y%m%d')
workpath = os.path.abspath('.')
srcpath = os.path.join(workpath, 'logs')
destpath = os.path.join(workpath, 'backlogs')
backartlogname = '%s.tar.gz' % today
destfile = os.path.join(destpath, backartlogname)


def main():
    subprocess.run('tar -zcf %s %s' % (destfile, srcpath), shell=True)


if __name__ == '__main__':
    main()
