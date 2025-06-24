import time
import os
import argparse
import subprocess

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


def exec_rsync(ssh_host, ssh_port, ssh_user, src_dir, dest_dir):
    command = "rsync -e 'ssh -p %s' -apz --delete %s/ %s@%s:%s/%s/" % (
        ssh_port, src_dir, ssh_user, ssh_host, dest_dir, os.path.basename(src_dir)
    )
    print(command)
    try:
        subprocess.run(command, shell=True)
    except Exception as e:
        print(e)


class FileEventHandler(FileSystemEventHandler):
    def __init__(self, ssh_host, ssh_port, ssh_user, src_dirs, ssh_path):
        self.ssh_host = ssh_host
        self.ssh_port = ssh_port
        self.ssh_user = ssh_user
        self.ssh_path = ssh_path
        self.src_dirs = src_dirs
        FileSystemEventHandler.__init__(self)

    def on_any_event(self, event):
        for src_dir in self.src_dirs:
            exec_rsync(self.ssh_host, self.ssh_port, self.ssh_user, src_dir, self.ssh_path)


class WatchSystemPath:
    local_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

    def mon(self):
        return [os.path.join(self.local_path, 'database')]

    def oes(self):
        data_dir = os.path.join(self.local_path, 'data')
        txlog_dir = os.path.join(self.local_path, 'txlog')
        return [data_dir, txlog_dir]

    def mds(self):
        data_dir = os.path.join(self.local_path, 'data')
        # txlog_dir = os.path.join(self.local_path, 'txlog')
        return [data_dir]

    def get_watch_dirs(self, systemid):
        handler = getattr(self, systemid)
        return handler()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--systemid",
        help="请输入系统类别(oes, mds, mon)"
    )
    parser.add_argument(
        "-s",
        "--ssh_host",
        help="请输入同步机器的ip"
    )
    parser.add_argument(
        "-p",
        "--ssh_port",
        default=22,
        help="请输入同步机器的端口, 默认为22端口"
    )
    parser.add_argument(
        "-u",
        "--ssh_user",
        help="请输入远程连接用户名"
    )
    parser.add_argument(
        "-d",
        "--ssh_dest_path",
        help="请输入远程同步的基础路径"
    )
    options = parser.parse_args()
    systemid = options.systemid.strip()
    ssh_host = options.ssh_host.strip()
    ssh_port = options.ssh_port
    ssh_user = options.ssh_user.strip()
    ssh_path = options.ssh_dest_path.strip()
    watch_path = WatchSystemPath()
    src_dirs = watch_path.get_watch_dirs(systemid)
    observer = Observer()
    for src_dir in src_dirs:
        exec_rsync(ssh_host, ssh_port, ssh_user, src_dir, ssh_path)
        event_handler = FileEventHandler(ssh_host, ssh_port, ssh_user, src_dirs, ssh_path)
        observer.schedule(event_handler, path=src_dir, recursive=True)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    main()
