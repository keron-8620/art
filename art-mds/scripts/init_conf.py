#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
import yaml
import os
import shutil
from publicdeco import checkuser
from constants import CONF, DEPLOY_PATH

system = CONF.get('system', '')
broker = CONF.get('broker', '')
taget = CONF.get('taget', '')
version = CONF.get('version', '')
set_num = CONF.get('set_num', '')
var_file_path = os.path.join(DEPLOY_PATH, "inventory", "swf_{}".format(system))

need_dir = [
    os.path.join(DEPLOY_PATH, "logs"),
    os.path.join(DEPLOY_PATH, "flag"),
    os.path.join(var_file_path, "group_vars"),
    os.path.join(var_file_path, "host_vars"),
]


def create_local_dir():
    for item in need_dir:
        if os.path.exists(item):
            shutil.rmtree(item)
        os.makedirs(item)


def create_hosts_var_files():
    host_pwd_dir_names = {
        "master": "host_01",
        "follow": "host_02",
        "arbiter": "host_03"
    }

    ssh_port = CONF['ssh_port']
    ssh_user = CONF["ssh_user"]

    file_path = os.path.join(var_file_path, "host_vars")
    h_list = list()
    for host in ['master', 'follow', 'arbiter']:
        if not CONF["{}_enable".format(host)]:
            continue
        info = dict(
            host=host,
            ssh_user=ssh_user,
            host_ip=CONF.get("{}_host".format(host), "xxx"),
            ssh_port=ssh_port
        )
        h_list.append(info)

    for info in h_list:
        # fname = "swf-{}-{}-{}-{}.yml".format(system, broker, taget, info['host_num'])
        fname = "{}_host.yml".format(info['host'])
        filename = os.path.join(file_path, fname)
        data = dict()
        with open(filename, 'w') as f:
            # if info['host'] == 'master':
            #     data['spec_config_file_dir'] = '01'
            #     data['slave_path_%suser_home' % system] = "/home/{{ ansible_ssh_user }}/host_01"
            # elif info['host'] == 'follow':
            #     data['spec_config_file_dir'] = '02'
            #     data['slave_path_%suser_home' % system] = "/home/{{ ansible_ssh_user }}/host_02"
            # elif info['host'] == 'arbiter':
            #     data['spec_config_file_dir'] = '03'
            #     data['slave_path_%suser_home' % system] = "/home/{{ ansible_ssh_user }}/host_03"
            data['ansible_ssh_user'] = str(info['ssh_user'])
            data['ansible_ssh_host'] = str(info['host_ip'])
            data['ansible_ssh_port'] = ssh_port
            data['spec_config_file_dir'] = host_pwd_dir_names.get(info['host'])
            data['slave_path_user_home'] = "/home/{{ ansible_ssh_user }}/%s" % host_pwd_dir_names.get(info['host'])
            yaml.dump(data, f, default_flow_style=False)

    if system == "oes":
        remote_hosts = ["mon", "csdc", "sse", "szse", "counter"]
    elif system == "mds":
        remote_hosts = ["mon", "sse", "szse"]
    else:
        remote_hosts = []

    for host in remote_hosts:
        host_file_name = os.path.join(file_path, "{}_host.yml".format(host))
        with open(host_file_name, 'w') as f:
            host_data = dict()
            host_data["ansible_ssh_user"] = "{{ %s_user }}" % host
            host_data["ansible_ssh_host"] = "{{ %s_host }}" % host
            host_data["ansible_ssh_port"] = ssh_port
            yaml.dump(host_data, f, default_flow_style=False)


def create_win_remote_var_file():
    if not CONF.get("run_in_win"):
        return

    file_path = os.path.join(var_file_path, "host_vars")
    win_host = CONF.get("win_host")
    win_info = dict(
        ansible_user=CONF['win_user'],
        ansible_password=CONF['win_pass'],
        ansible_port=CONF['win_port'],
        ansible_connection="winrm",
        ansible_winrm_server_cert_validation="ignore"
    )
    win_info_file = os.path.join(file_path, f"{win_host}.yml")
    with open(win_info_file, "w") as f:
        yaml.dump(win_info, f, default_flow_style=False)


def create_control_host_file():
    filename = "{}_hosts_{}".format(broker, taget)
    file_path = os.path.join(var_file_path, filename)
    prefix = "swf-{}-{}-{}-".format(system, broker, taget, )

    with open(file_path, "w") as f:
        master = 'master_host'
        follow = "follow_host"
        arbiter = 'arbiter_host'
        _str = ""
        if CONF['master_enable']:
            _str += master + '\n'
        if CONF['follow_enable']:
            _str += follow + '\n'
        if CONF['arbiter_enable']:
            _str += arbiter + "\n"
        f.write(_str)


def write_zb_server():
    if CONF['is_enable_mds_zb'] == 'yes':
        mds_zb_info = {
            'ansible_ssh_host': CONF['mds_zb_host'],
            'ansible_ssh_port': CONF['mds_zb_port'],
            'ansible_ssh_user': CONF['mds_zb_user'],
            'zb_deploy_path': CONF['mds_zb_path'],
        }
        with open(os.path.join(var_file_path, 'zb_mds.yml'), 'w', encoding='utf-8') as mds_file:
            yaml.dump(mds_zb_info, mds_file, default_flow_style=False, encoding='utf-8', allow_unicode=True)
    if CONF['is_enable_mon_zb'] == 'yes':
        mon_zb_info = {
            'ansible_ssh_host': CONF['mon_zb_host'],
            'ansible_ssh_port': CONF['mon_zb_port'],
            'ansible_ssh_user': CONF['mon_zb_user'],
            'zb_deploy_path': CONF['mon_zb_path'],
        }
        with open(os.path.join(var_file_path, 'zb_mon.yml'), 'w', encoding='utf-8') as mon_file:
            yaml.dump(mon_zb_info, mon_file, default_flow_style=False, encoding='utf-8', allow_unicode=True)


@checkuser
def main():
    create_local_dir()
    create_hosts_var_files()
    create_win_remote_var_file()
    create_control_host_file()
    write_zb_server()


if __name__ == '__main__':
    main()
