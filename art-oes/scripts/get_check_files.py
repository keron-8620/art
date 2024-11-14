import traceback

import yaml
import os
import constants as C
from art_modules.parse import parse_csv
from enum import Enum
from art_modules.trading_day_calc import get_curr_date

ETF_HEADER = ["etf_id", "security_id", "market", "tradable"]
SPEC_ETF = yaml.load(open(os.path.join(C.DEPLOY_PATH, "scripts", "data", "EtfTradeSpecial.yml")))

curr_date = get_curr_date()
mon_etf_path = os.path.join(C.DEPLOY_PATH, "files", "mon", "EtfTradeList.csv")
counter_etf_path = os.path.join(C.DEPLOY_PATH, "files", "counter", "data", "broker", f"EtfTradeList{str(curr_date)[4:]}.csv")
mon_success_flag = os.path.join(C.DEPLOY_PATH, "flag", f"mon_collector_{curr_date}.success")
tmp_path = os.path.join(C.DEPLOY_PATH, ".tmp")
tmp_sse_etf = os.path.join(tmp_path, f"sse_etf.yml")
tmp_szse_etf = os.path.join(tmp_path, f"szse_etf.yml")

curr_path = os.path.abspath(os.path.dirname(__file__))
deploy_path = os.path.abspath(os.path.join(curr_path, ".."))
conf_filename = "automatic.yml"
automatic_is_option = C.CONF["is_option"]


class Market(Enum):
    sh_mkt = 1
    sz_mkt = 2


def get_etc_check_files(path: str):
    sh_files = []
    sz_files = []
    try:
        assert os.path.isfile(path), f"文件不存在: {path}"
        lines = parse_csv(path, headers=ETF_HEADER)
        for line in lines:
            if str(line.tradable) == str(0):
                continue
            if int(line.market) == Market.sh_mkt.value:
                sh_files.append(
                    f"({line.security_id}{{{{ curr_date[4:] }}}}.(?i)ETF|{line.security_id}{{{{ curr_date[4:] }}}}2.(?i)ETF|ssepcf_{line.security_id}_{{{{ curr_date }}}}.xml)"
                )
            elif int(line.market) == Market.sz_mkt.value:
                # pcf_159942_20180201.xml
                sz_files.append(f"pcf_{line.security_id}_{{{{ curr_date }}}}.xml")
    except Exception:
        print(traceback.format_exc())
        sh_files.append("no_such_etf_file")
        sz_files.append("no_such_etf_file")
    return sh_files, sz_files


def handler_var_files():
    if not C.CONF['sse_etf_check_mon_files'] and not os.path.exists(mon_etf_path):
        return False, "mon_is_not_success"
    if not C.CONF['sse_etf_check_counter_files'] and not os.path.exists(counter_etf_path):
        return False, "counter_is_not_success"
    return True, ""


def create_sse_var_file():
    sse_etf_check_mon_files = C.CONF["sse_etf_check_mon_files"]
    sse_etf_check_counter_files = C.CONF["sse_etf_check_counter_files"]
    all_etf_files = C.CONF["sse_etf_check_files"] or []
    if sse_etf_check_mon_files:
        mon_etf_files, _ = get_etc_check_files(mon_etf_path)
        all_etf_files += mon_etf_files
    if sse_etf_check_counter_files:
        counter_etf_files, _ = get_etc_check_files(counter_etf_path)
        all_etf_files += counter_etf_files
    yaml.dump({"etf_check_files": list(set(all_etf_files))}, open(tmp_sse_etf, "w"))


def create_szse_var_file():
    all_etf_files = C.CONF["szse_etf_check_files"] or []
    szse_etf_check_mon_files = C.CONF["szse_etf_check_mon_files"]
    szse_etf_check_counter_files = C.CONF["sse_etf_check_counter_files"]
    if szse_etf_check_mon_files:
        _, mon_etf_files = get_etc_check_files(mon_etf_path)
        all_etf_files += mon_etf_files
    if szse_etf_check_counter_files:
        _, counter_etf_files = get_etc_check_files(counter_etf_path)
        all_etf_files += counter_etf_files
    yaml.dump({"etf_check_files": list(set(all_etf_files))}, open(tmp_szse_etf, "w"))

