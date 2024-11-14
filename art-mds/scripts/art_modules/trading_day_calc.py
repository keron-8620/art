#!/usr/local/bin/python3
# -*- coding: utf-8 -*-

import time
import os
from optparse import OptionParser
import yaml

_curr_dir = os.path.abspath(os.path.dirname(__file__))
toyear = time.strftime('%Y', time.localtime())

trd_list_path = os.path.abspath(os.path.join(_curr_dir, "../trd_date", f"TrdDateList.yml"))

with open(trd_list_path) as f:
    trd_date_info = yaml.load(f)


def next_trd_date(date, trdDateList, the_year):
    if not date:
        return '00000000'
    date = int(date)
    if date >= trdDateList[-1]:
        return trd_date_info.get('trd_date_%d_list' % (the_year + 1,))[0]
    if date in trdDateList:
        index = trdDateList.index(date)
        next_date = trdDateList[index + 1]
        return next_date
    else:
        if date + 1 in trdDateList:
            return date + 1
        return next_trd_date(date + 1, trdDateList, the_year)


def pre_trd_date(date, trdDateList, the_year):
    if not date:
        return '00000000'
    date = int(date)
    if date <= trdDateList[0]:
        return trd_date_info.get('trd_date_%d_list' % (the_year - 1,))[-1]
    if date in trdDateList:
        index = trdDateList.index(date)
        next_date = trdDateList[index - 1]
        return next_date
    else:
        if date - 1 in trdDateList:
            return date - 1
        return pre_trd_date(date - 1, trdDateList, the_year)


def get_curr_date():
    return int(time.strftime('%Y%m%d', time.localtime()))


def is_trd_date():
    trd_d = get_curr_date()
    year = str(trd_d)[:4]
    if int(trd_d) in trd_date_info.get('trd_date_%s_list' % year):
        return True
    else:
        return False


def get_trd_date(date):
    if date:
        curr_date = str(date)
    else:
        curr_date = str(get_curr_date())

    the_year = int(curr_date[:4])
    trd_date_list = trd_date_info.get('trd_date_%s_list' % the_year, '')

    next_date = str(next_trd_date(curr_date, trd_date_list, the_year))
    pre_date = str(pre_trd_date(curr_date, trd_date_list, the_year))

    return pre_date, curr_date, next_date


def main():
    usage = 'usage: %prog [options] arg1 arg2 arg3 '
    parser = OptionParser(usage=usage, version='%prog 0.15.5.2')

    parser.add_option("-d", "--date", action="store_true", default=False,
                      metavar="trd_date",
                      help="交易日期(e: 20171224)")
    parser.add_option("-p", "--pre", type='string', default='',
                      metavar='pre_trd_date',
                      help="上个交易日")
    parser.add_option("-n", "--next", type='string', default='',
                      metavar='next_trd_date',
                      help="下个交易日")

    (options, _) = parser.parse_args()
    date = options.date
    pre = options.pre.strip()
    next = options.next.strip()

    if date:
        print(get_curr_date())
    elif pre:
        the_year = int(pre[:4])
        trdDateList = trd_date_info.get('trd_date_%s_list' % the_year, '')
        print(pre_trd_date(pre, trdDateList, the_year))
    elif next:
        the_year = int(next[:4])
        trdDateList = trd_date_info.get('trd_date_%s_list' % the_year, '')
        print(next_trd_date(next, trdDateList, the_year))


if __name__ == '__main__':
    main()
