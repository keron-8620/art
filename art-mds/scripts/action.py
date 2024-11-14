# -*- coding: utf-8 -*-
import subprocess
import sys
from optparse import OptionParser
from constants import *
from publicdeco import checkuser
from art_modules.trading_day_calc import is_trd_date, get_trd_date, get_curr_date
from get_check_files import create_sse_var_file, create_szse_var_file


curr_path = os.path.abspath(os.path.dirname(__file__))
pbk_info = GetYamlConf(os.path.join(curr_path, "data", "playbk_info.yml"))

flagInfos = {
    "success": ".success",
    "retry": ".retry",
    "timeout": ".timeout",
}

EXIT_CODE = {
    "success": 0,
    "retry": 1,
    "timeout": 2,
}


@checkuser
def run_main():
    # 解析命令行参数
    usage = 'usage: %prog [options] arg1 arg2 '
    parser = OptionParser(usage=usage, version='%prog 0.16.0.0.')

    parser.add_option(
        "-a",
        "--action",
        type='string',
        default='',
        metavar="operation_action",
        help="待执行的命令(例:dep; start; stop; backup)")

    parser.add_option(
        "-c",
        "--cmd_to_oes",
        action='store_true',
        default=False,
        metavar="cmd_to_oes",
        help="指定向oes发送命令设置状态")

    parser.add_option(
        "--skip_etf",
        action='store_true',
        default=False,
        metavar="skip_etf",
        help="跳过 etf检查，直接启动")

    (options, _) = parser.parse_args()

    swf_system_taget = CONF.get('taget')
    swf_system_broker = CONF.get('broker')
    swf_system_name = CONF.get('system')

    # mds 没有这些配置， 使用默认值 None
    is_option = CONF.get("is_option")
    run_in_win = CONF.get("run_in_win")
    is_scp_counter_fetch = CONF.get("is_scp_counter_fetch")

    swf_operation_action = options.action.strip()
    swf_cmd_to_oes = options.cmd_to_oes
    skip_etf = options.skip_etf

    allow_list = ["register", 'dep', 'install', 'software_check', 'ping', 'check_dir', 'calendar_converter', 'mon']

    if not is_trd_date() and CONF['trd_check'] and swf_operation_action not in allow_list:
        print(f"当前日期: {get_curr_date()} 不是交易日！！！如需强制执行， 请在配置文件中关闭交易日校验项trd_check")
        return 1

    # 必须指定参数
    # inventory_file = ' inventory/swf_' + swf_system_name + '/' + swf_system_broker + '_hosts_' + swf_system_taget
    inventory_file = f" inventory/swf_{swf_system_name}/{swf_system_broker}_hosts_{swf_system_taget}"

    playbook_info = pbk_info[f"{swf_system_name}_playbook_info"]

    if swf_operation_action == "counter_fetch":
        # 在windows 上运行 xcounter 脚本， 重新设置swf_operation_action 值
        if run_in_win:
            swf_operation_action = "win_counter_fetch"
        # 如果是期权， 判断 xcounter是否在特殊获取列表
        elif is_option and is_scp_counter_fetch:
            swf_operation_action = "opt_counter_fetch"

    if swf_system_name == "oes":
        if swf_operation_action == "sse_collector":
            create_sse_var_file()
        elif swf_operation_action == "szse_collector":
            create_szse_var_file()

    playbook_path = playbook_info.get(swf_operation_action)

    if playbook_path:
        playbooks_file = f" swf_playbooks/{playbook_path}"
    else:
        print(f"未知任务类型 {swf_operation_action}")
        return

    pre_trd_date, curr_date, next_trd_date = get_trd_date(get_curr_date())

    os.putenv('ANSIBLE_LOG_PATH', 'logs/ansible-{}-{}.log'.format(swf_operation_action, curr_date))

    cmd = '$(which ansible-playbook) -i ' + inventory_file + playbooks_file
    # # 可选参数指定
    if swf_operation_action in ['install', 'software_check']:
        cmd += " --ask-sudo-pass "

    if swf_system_name == "oes" and swf_operation_action in ["sse_collector", "szse_collector"]:
        cmd += f" -e '{{skip_etf: {skip_etf}}}'"
    cmd += " --extra-vars 'ansible_path_ansible_home={} ".format(DEPLOY_PATH)
    cmd += "pre_trd_date={} curr_date={} next_trd_date={} ".format(pre_trd_date, curr_date, next_trd_date)

    if swf_cmd_to_oes:
        cmd += "set_oes_status=True "
    cmd += "'"

    print(f"执行的命令为:  {cmd}")
    ret_code = subprocess.call(cmd, shell=True, cwd=os.getcwd())

    print(u'exec over: {}'.format(0 == ret_code and 'success' or 'failed'))

    if os.path.exists(os.path.join(DEPLOY_PATH, "flag", f"{swf_operation_action}_{curr_date}{flagInfos['success']}")):
        sys.exit(EXIT_CODE['success'])
    elif os.path.exists(os.path.join(DEPLOY_PATH, "flag", f"{swf_operation_action}_{curr_date}{flagInfos['retry']}")):
        sys.exit(EXIT_CODE['retry'])
    elif os.path.exists(os.path.join(DEPLOY_PATH, "flag", f"{swf_operation_action}_{curr_date}{flagInfos['timeout']}")):
        sys.exit(EXIT_CODE['timeout'])
    else:
        sys.exit(-1)


if __name__ == '__main__':
    # print(u'exec over: {}'.format(0 == run_main() and 'success' or 'failed'))
    run_main()
