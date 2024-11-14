import optparse
import os
import sys
import time
import paramiko

from constants import DEPLOY_PATH, CONF


class SSHClient:
    def __init__(self, host, port, user, password=None):
        self.ssh_client = paramiko.SSHClient()
        self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        if password is None:
            password = os.path.join(os.path.expanduser('~'), '.ssh', 'is_rsa')
        if os.path.isfile(password):
            self.ssh_client.connect(hostname=host, port=port, username=user,
                                    pkey=paramiko.RSAKey.from_private_key_file(password))
        else:
            self.ssh_client.connect(hostname=host, port=port, username=user, password=password)

    def close(self):
        self.ssh_client.close()

    def exec_command(self, command):
        response_dict = {'status': 'running', 'message': ''}
        try:
            stdin, stdout, stderr = self.ssh_client.exec_command(command, timeout=300)
        except Exception as e:
            response_dict['status'] = 'critical'
            response_dict['message'] = str(e)
        else:
            response_dict['message'] = stdout.read().decode('utf-8') + stderr.read().decode('utf-8')
            channel = stdout.channel
            if channel.recv_exit_status() != 0:
                response_dict['status'] = 'error'
            else:
                response_dict['status'] = 'success'
        return response_dict

    def exec_none_command(self, command):
        transport = self.ssh_client.get_transport()
        channel = transport.open_session()
        channel.exec_command(command)


class DisasterRecovery:
    def __init__(self, systemid):
        self.systemid = self.check_config(systemid)
        self.slave_info, self.slave_client = self.get_slave_info()
        self.zb_info = self.get_zb_info()

    @staticmethod
    def check_config(systemid):
        if CONF.get('is_enable_{}_zb'.format(systemid), '') != 'yes':
            print('配置文件automatic.yml中is_enable_{}_zb设置为未启动，请检查'.format(systemid))
            sys.exit(1)
        return systemid

    def get_slave_info(self):
        if self.systemid == 'mon':
            server_info = {
                'ssh_host': CONF['mon_host'],
                'ssh_port': CONF['ssh_port'],
                'ssh_user': CONF['mon_user'],
                'ssh_path': CONF.get('mon_deploy_path', '/home/monuser/mon')
            }
        else:
            server_info = {
                'ssh_host': CONF['follow_host'],
                'ssh_port': CONF['ssh_port'],
                'ssh_user': CONF['ssh_user'],
                'ssh_path': '/home' + '/' + CONF['ssh_user'] + '/' + 'host_02' + '/' +
                            CONF['{}_pkg_name'.format(self.systemid)]
            }
        try:
            ssh_client = SSHClient(server_info['ssh_host'], server_info['ssh_port'], server_info['ssh_user'])
        except Exception as e:
            print(e)
            print('ssh连接失败, {}'.format(server_info))
            sys.exit(5)
        return server_info, ssh_client

    def get_zb_info(self):
        return {
            'ssh_host': CONF.get('{}_zb_host'.format(self.systemid)),
            'ssh_port': CONF.get('{}_zb_port'.format(self.systemid)),
            'ssh_user': CONF.get('{}_zb_user'.format(self.systemid)),
            'ssh_path': CONF.get('{}_zb_path'.format(self.systemid))
        }

    def start(self):
        command = "cd %s && nohup python3.8 art/watch.py -i %s -s %s -p %s -u %s -d %s >/dev/null 2>&1 &" % (
            self.slave_info['ssh_path'], self.systemid, self.zb_info['ssh_host'], self.zb_info['ssh_port'],
            self.zb_info['ssh_user'], self.zb_info['ssh_path']
        )
        print(command)
        self.slave_client.exec_none_command(command)
        if self.check_watch_ps():
            return 'success'
        else:
            return 'error'

    def check_watch_ps(self):
        command = "ps aux | grep watch | grep -v grep | awk '{print $2}'"
        result = self.slave_client.exec_command(command)
        if result['message']:
            return result['message'].split()
        else:
            return []

    def stop(self):
        for pid in self.check_watch_ps():
            self.slave_client.exec_none_command('kill -9 {}'.format(pid))
        if self.check_watch_ps():
            return 'error'
        else:
            return 'success'

    def clear_flags(self, action):
        flag_filter = '{}_watch_{}'.format(self.systemid, action)
        flags_dir = os.path.join(DEPLOY_PATH, 'flag')
        os.chdir(flags_dir)
        for flag in os.listdir(flags_dir):
            if flag_filter in flag:
                os.remove(flag)

    def create_flag(self, action, status):
        flag_name = '{}_watch_{}_{}.{}'.format(self.systemid, action, time.strftime('%Y%m%d', time.localtime()), status)
        flag_path = os.path.join(DEPLOY_PATH, 'flag', flag_name)
        with open(flag_path, 'w', encoding='utf-8') as file_obj:
            file_obj.write(time.strftime('%H%M%S'))

    def run(self, action):
        self.clear_flags(action)
        handler = getattr(self, action)
        task_status = handler()
        self.create_flag(action, task_status)


def main():
    parser = optparse.OptionParser()
    parser.add_option(
        "-t",
        "--action_type",
        type="string",
        help="请输入操作类型(start, stop): "
    )
    parser.add_option(
        "-i",
        "--systemid",
        type="string",
        help="请输入操作对象(mon, oes): "
    )
    (options, _) = parser.parse_args()
    action_type = options.action_type.strip()
    systemid = options.systemid.strip()
    zb = DisasterRecovery(systemid)
    zb.run(action_type)


if __name__ == '__main__':
    main()
