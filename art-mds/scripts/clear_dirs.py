# -*- coding: utf-8 -*-
import os
import sys
import time


def main():
    path = sys.argv[1]
    if os.path.isdir(path):
        for root, dirs, files in os.walk(path):
            for name in files:
                if name != 'ansible-backup-{}.log'.format(time.strftime('%Y%m%d')):
                    os.remove(os.path.join(root, name))
        return
    if os.path.isfile(path):
        os.remove(path)
        return


if __name__ == '__main__':
    main()
