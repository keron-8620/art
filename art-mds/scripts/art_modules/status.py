#!/usr/local/bin/python3
# -*- coding: utf-8 -*-

import subprocess
import os
import time
import json
# from optparse import OptionParser
from art_modules import trading_day_calc

curr_path = os.path.abspath(os.path.dirname(__file__))
status_path = os.path.join(curr_path, 'status')

CronJobInfo = {
    'stop': 'oes_stop',
    'stop_no_register': 'oes_stop',
    'backup': 'oes_backup',
    'nakedstart': 'oes_nakedstart',
    'nakedstart_no_register': 'oes_nakedstart',
    'datacheck': 'oes_datacheck',
    'open': 'oes_open',
    'close': 'oes_close',
    'load': 'oes_load_data',
    'reset': "oes_reset",
    'shutoff': "oes_shutoff",
    'mon_collector': 'mon_collector',
    'csdc_collector': 'csdc_collector',
    'sse_collector': 'sse_collector',
    'szse_collector': 'szse_collector',
    'write_back_main': 'oes_write_back',
    'counter_fetch': 'counter_fetch',
    'counter_distribute': 'counter_distribute'

}

StatusInfo = {
    ".success": "成功::分发成功，已经初始化",
    ".failed": "失败::请人工干预，手动重试",
    ".retry": "待重试::正在等待重新运行",
    ".running": "运行中::请稍等，重新查看",
    ".timeout": "超时::请人工干预，手动获取",
    ".error": "错误::任务执行异常",
}

QueueInfo = {
    'mon_collector': 0,
    'csdc_collector': 1,
    'counter_fetch': 2,
    'counter_distribute': 3,
    'sse_collector': 4,
    'szse_collector': 5,
    'oes_datacheck': 6,
    'oes_backup': 7,
    'oes_write_back': 8,
    'calendar_collector': 9,
    'mds_backup': 13,
}


class CronRead(object):
    """获取crontab中内容"""

    def __init__(self):
        self.cmd = "crontab -l"
        self.line_list = self.get()

    def excute_cmd(self):
        return subprocess.run(
            self.cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)

    def readline(self):
        return self.line_list.pop(0) if self.line_list else None

    def get(self):
        con = self.excute_cmd().stdout.decode()
        return con.split('\n')


class TimeStatus(object):
    """提供时间接口"""

    def __init__(self):
        self._curr_date = trading_day_calc.get_curr_date()
        self._pre_date, _, self._next_date = trading_day_calc.get_trd_date(self._curr_date)

    @property
    def curr_date(self):
        return self._curr_date

    @property
    def pre_date(self):
        return self._pre_date

    @property
    def next_date(self):
        return self._next_date


class CronStatus(object):
    """获取定时任务状态， 并提供定时任务状态获取接口"""

    def __init__(self, system, time_status):
        self._cron = CronRead()
        self._time_status = time_status
        self.end = False
        self._status_dict = {}
        self._system = system

    def __getitem__(self, key):
        pass

    def items(self):
        for key, val in self.status_dict.items():
            yield key, val

    @property
    def status_dict(self):
        if not self._status_dict:
            self._status_dict = self.get_status()
        return self._status_dict

    @property
    def flag_path(self):
        return os.path.join(curr_path, "../../flag")

    def get_head(self, line):
        content = line.lstrip("#Ansible:")
        cont_list = content.strip().split(' ')
        en_name, system_version = cont_list[0].split('--')
        system = system_version.split("-")[0]

        return system, en_name, cont_list[2]

    def get_body(self, line, info):
        content = line.strip()
        content_list = content.split(' ')
        info['cron_M'] = content_list[0]
        info['cron_H'] = content_list[1]
        info['cron_d'] = content_list[2]
        info['cron_m'] = content_list[3]

    @staticmethod
    def is_ansible_cron(line):
        return line.startswith("#Ansible:")

    def set_status_remark(self, info):
        cron_eng_name = info['english_name']
        file_list = os.listdir(self.flag_path)

        for key, value in StatusInfo.items():
            if cron_eng_name + '_' + str(self._time_status.curr_date) + key in file_list:
                info['status'], info['remark'] = value.split('::')
                return
        else:
            info['status'] = '未运行'
            info['remark'] = ''

    def set_status_time(self, info):
        info['cron_time'] = self.get_crontime_of(info)

    def get_cron_info(self):
        info = dict()
        system = None
        for i in range(2):
            line = self._cron.readline()
            if line is None:
                self.end = True
                break
            if i == 0:
                if not self.is_ansible_cron(line):
                    return None
                system, en_name, ch_name = self.get_head(line)
                if system == self._system:
                    info['english_name'], info['chinese_name'], info['system'] = en_name, ch_name, system
            elif i == 1:
                if system == self._system:
                    self.get_body(line, info)
        return info

    def get_status(self):
        cron_info = dict()
        while True:
            info = self.get_cron_info()
            if info is None:
                continue
            if self.end is True:
                break
            if info:
                self.set_status_remark(info)
                self.set_status_time(info)
                cron_info[info['english_name']] = info
        return cron_info

    def get_crontime_of(self, info):
        if info:
            return f"{info['cron_m']:>2}月{info['cron_d']:>2}日 {info['cron_H']}:{info['cron_M']}"
        else:
            return f'xx月xx日 xx:xx'


class Display:
    """显示类， 提供显示功能， 定义显示格式"""

    def __init__(self, system):
        self._num = 100

        self.time_status = TimeStatus()
        self._status = CronStatus(system, self.time_status)
        self.head = '{0:{1}^47}'.format('自动化运行工具（art）状态', chr(12288))

    @staticmethod
    def to_localtime(timestamp):
        if not timestamp:
            return ''
        time_array = time.localtime(timestamp)
        format_time = time.strftime('%m月%d日 %H:%M', time_array)
        return format_time

    def sorted_cron(self):
        cron_list = list()
        for key, info in self._status.items():
            if not isinstance(info, dict):
                continue
            cron_list.append((key, info))
        return sorted(cron_list, key=lambda x: QueueInfo[x[0]])

    def display_head(self):
        print(self.head)
        print('')

    def display_cron_head(self):
        print('=' * self._num)
        title = [
            '序号', '中文介绍', '任务名称', '定时任务执行时间', '任务状态', '备注'
        ]
        str_title = '| {0:<2}| {1:{6}^8}| {2:{6}<12}|{3:{6}<8}| {4:{6}<4}| {5:{6}^10}|'.format(
            title[0], title[1], title[2], title[3], title[4], title[5], chr(12288))
        print(str_title)
        print('-' * self._num)

    def display_cron_info(self, key, info):
        # print(info['excu_time'])
        str_content = '| {0:^4}| {1:{6}<8}| {2:<24}|{3:{6}<13}| {4:{6}^4}| {5:{6}<10}|'.format(
            int(QueueInfo[key]) + 1, info.get('chinese_name', ''), key,
            info.get('cron_time', ''), info.get('status', ''),
            info.get('remark', ''), chr(12288))
        print(str_content)

    def display_cron_status(self):
        self.display_cron_head()
        cron_info = self.sorted_cron()
        for key, info in cron_info:
            self.display_cron_info(key, info)
        print('')

    def display(self):
        self.display_head()
        # self.display_time_status()
        self.display_cron_status()
