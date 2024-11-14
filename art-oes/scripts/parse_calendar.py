import os

import yaml
from constants import DEPLOY_PATH


def parse_calendar():
    """
    导出交易日历
    """
    trd_csv_file_path = os.path.join(DEPLOY_PATH, 'files', 'mon', 'TradingCalendar.csv')
    if not os.path.isfile(trd_csv_file_path):
        raise Exception('no such file or directory: {}'.format(trd_csv_file_path))
    trd_info = {}
    with open(trd_csv_file_path, 'r', encoding='utf-8') as trd_csv:
        for line in trd_csv.readlines():
            if line.startswith("#") or not line.strip():
                continue
            year_month_dates = line.split('|')
            year_month, dates = year_month_dates[0].strip(), year_month_dates[1].rstrip('/n').strip().split(",")
            year = year_month[:4]
            year_key = 'trd_date_%s_list' % year
            if not trd_info.get(year_key, None):
                trd_info[year_key] = []
            for date in dates:
                date = date.zfill(2)
                a_trd_date = year_month + date
                trd_info[year_key].append(int(a_trd_date.strip()))
    TRD_DATE_PATH = os.path.join(DEPLOY_PATH, 'scripts', 'trd_date', 'TrdDateList.yml')
    with open(TRD_DATE_PATH, 'w') as yaml_f:
        yaml.dump(trd_info, yaml_f)


if __name__ == '__main__':
    parse_calendar()
