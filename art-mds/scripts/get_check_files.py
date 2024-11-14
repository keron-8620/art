import yaml
import os
import constants as  C
import shutil
from art_modules.parse import parse_csv
from enum import Enum
from art_modules.trading_day_calc import is_trd_date, get_trd_date, get_curr_date

ETF_HEADER = ["etf_id", "security_id", "market", "tradable"]

SPEC_ETF = yaml.load(open(os.path.join(C.DEPLOY_PATH, "scripts", "data", "EtfTradeSpecial.yml")))

curr_date = get_curr_date()
src = os.path.join(C.DEPLOY_PATH, "files", "mon", 'EtfTradeList.csv')
dst = os.path.join(C.DEPLOY_PATH, "scripts", "etf_files", f"EtfTradeList{curr_date}.csv")
mon_success_flag = os.path.join(C.DEPLOY_PATH, "flag", f"mon_collector_{curr_date}.success")
tmp_path = os.path.join(C.DEPLOY_PATH, ".tmp")
tmp_sse_etf = os.path.join(tmp_path, f"sse_etf.yml")
tmp_szse_etf = os.path.join(tmp_path, f"szse_etf.yml")


class Market(Enum):
    sh_mkt = 1
    sz_mkt = 2


def get_etc_check_files(path: str):
    lines = parse_csv(path, headers=ETF_HEADER)
    spec_files = SPEC_ETF
    sh_files = []
    sz_files = []

    for line in lines:
        if int(line.market) == Market.sh_mkt.value:
            if line.security_id in spec_files:
                print(spec_files[line.security_id])
                sh_files.append(spec_files[line.security_id])
            sh_files.append(
                f"({line.security_id}{{{{ curr_date[4:] }}}}.(?i)ETF|{line.security_id}{{{{ curr_date[4:] }}}}2.(?i)ETF)")
        elif int(line.market) == Market.sz_mkt.value:
            # pcf_159942_20180201.xml
            sz_files.append(f"pcf_{line.security_id}_{{{{ curr_date }}}}.xml")
    # print(sh_files)
    return sh_files, sz_files


def backup_eft_list():
    if os.path.exists(src):
        shutil.copy2(src, dst)
        return True
    else:
        return False


def is_mon_ok():
    print(mon_success_flag)
    return os.path.exists(mon_success_flag)


def handler_var_files():
    flag, msg = True, ""
    if not is_mon_ok():
        flag, msg = False, "mon_is_not_success"
    if not backup_eft_list():
        flag, msg = False, "files_mon_EtfTradeList_not_exist"
    return flag, msg


def create_sse_var_file():
    flag, msg = handler_var_files()
    if flag:
        automatic_etf_files = C.CONF["sse_etf_check_files"] or []
        try:
            mon_etf_files, _ = get_etc_check_files(dst)
            all_etf_files = list(set(mon_etf_files + automatic_etf_files))
        except Exception as e:
            print(e)
            print("EtfTradeSpecial.yml 解析失败，放弃增加该 Etf检查列表 文件")
            all_etf_files = automatic_etf_files
    else:
        all_etf_files = [msg]
    yaml.dump({
        "etf_check_files": all_etf_files
    }, open(tmp_sse_etf, "w"))


def create_szse_var_file():
    flag, msg = handler_var_files()
    if flag:
        automatic_etf_files = C.CONF["szse_etf_check_files"] or []
        try:
            _, mon_etf_files = get_etc_check_files(dst)
            all_etf_files = list(set(mon_etf_files + automatic_etf_files))
        except Exception as e:
            print(e)
            print("EtfTradeSpecial.yml 解析失败，放弃增加该 Etf检查列表 文件")
            all_etf_files = automatic_etf_files
    else:
        all_etf_files = [msg]
    yaml.dump({
        "etf_check_files": all_etf_files
    }, open(tmp_szse_etf, "w"))
