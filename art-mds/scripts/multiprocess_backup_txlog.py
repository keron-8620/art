import os
import tarfile
import time
from multiprocessing import Process, Queue, current_process
import optparse
from datetime import datetime


def _process_archive(queue, backup_path, is_enable_taskset=False, cpu_id=None):
    if is_enable_taskset:
        process_id = current_process().pid
        command = "taskset -cp %s %s" % (cpu_id, process_id)
        os.system(command)
    while True:
        try:
            filepath = queue.get(block=True, timeout=0.1)
        except Exception:
            break
        tar_name = os.path.basename(filepath)
        tar_file = os.path.join(backup_path, '{}-{}'.format(tar_name, time.strftime('%Y%m%d-%H%M.tar.gz')))
        with tarfile.open(tar_file, 'w:gz') as tar_file:
            tar_file.add(filepath, arcname=tar_name)
            time.sleep(0.1)


def multiprocess_archive(src_path, backup_path, cpu_args=''):
    file_queue = Queue()
    process_list = []
    for filename in os.listdir(src_path):
        file_path = os.path.join(src_path, filename)
        if os.path.isfile(file_path):
            file_queue.put(file_path)
    if cpu_args:
        cpu_list = cpu_args.split()
        is_enable_taskset = True
    else:
        cpu_list = range(10)
        is_enable_taskset = False
    for cpu_id in cpu_list:
        p = Process(target=_process_archive, args=(file_queue, backup_path, is_enable_taskset, cpu_id))
        p.daemon = True
        p.start()
        time.sleep(0.1)
        process_list.append(p)
    for p in process_list:
        p.join()


def main():
    print(datetime.now())
    parser = optparse.OptionParser()
    parser.add_option(
        "-s",
        "--src_path",
        type="string",
    )
    parser.add_option(
        "-b",
        "--backup_path",
        type="string",
    )
    parser.add_option(
        "-m",
        "--master",
        default="",
        type="str",
    )
    parser.add_option(
        "-f",
        "--follow",
        default="",
        type="str",
    )
    parser.add_option(
        "-a",
        "--arbiter",
        default="",
        type="str",
    )
    (options, _) = parser.parse_args()
    src_path = options.src_path.strip()
    backup_path = options.backup_path.strip()
    filepath = os.path.abspath(os.path.dirname(__file__))
    if 'host_01' in filepath:
        cpu_args = options.master.strip()
    elif 'host_02' in filepath:
        cpu_args = options.follow.strip()
    elif 'host_03' in filepath:
        cpu_args = options.arbiter.strip()
    else:
        cpu_args = ''
    multiprocess_archive(src_path, backup_path, cpu_args)
    print(datetime.now())


if __name__ == '__main__':
    main()
