import optparse
import os.path

from constants import CONF
from control_disaster_recovery import SSHClient
from watch import WatchSystemPath


def get_local_info(systemid):
    if systemid == 'mon':
        server_info = {
            'ssh_host': CONF['mon_host'],
            'ssh_port': CONF['ssh_port'],
            'ssh_user': CONF['mon_user'],
            'ssh_path': CONF.get('mon_deploy_path', '/home/monuser/mon')
        }
    else:
        server_info = {
            'ssh_host': CONF['master_host'],
            'ssh_port': CONF['ssh_port'],
            'ssh_user': CONF['ssh_user'],
            'ssh_path': '/home' + '/' + CONF['ssh_user'] + '/' + 'host_01' + '/' +
                        CONF['{}_pkg_name'.format(systemid)]
        }
    return server_info


def get_zb_info(systemid):
    return {
        'ssh_host': CONF.get('{}_zb_host'.format(systemid)),
        'ssh_port': CONF.get('{}_zb_port'.format(systemid)),
        'ssh_user': CONF.get('{}_zb_user'.format(systemid)),
        'ssh_path': CONF.get('{}_zb_path'.format(systemid))
    }


def main():
    parser = optparse.OptionParser()
    parser.add_option(
        "-i",
        "--systemid",
        type="string",
        help="请输入操作对象(mon, mds): "
    )
    (options, _) = parser.parse_args()
    systemid = options.systemid.strip()
    zb_info = get_zb_info(systemid)
    system_info = get_local_info(systemid)
    watch_system_path = WatchSystemPath()
    for src_dir in watch_system_path.get_watch_dirs(systemid):
        src_name = os.path.basename(src_dir)
        command = "rsync -e 'ssh -p %s' -apz %s/%s/ %s@%s:%s/%s/" % (
            zb_info['ssh_port'], system_info['ssh_path'], src_name, zb_info['ssh_user'], zb_info['ssh_host'],
            zb_info['ssh_path'], src_name
        )
        print(command)
        zb_info = get_zb_info(systemid)
        ssh_client = SSHClient(system_info['ssh_host'], system_info['ssh_port'], system_info['ssh_user'])
        result = ssh_client.exec_command(command)
        print(result)


if __name__ == '__main__':
    main()
