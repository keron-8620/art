#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
import os
import optparse
from multiprocessing import Process, Manager
import sys
import time
from constants import CONF, DEPLOY_PATH
import subprocess


def run_command(command):
    response_dict = dict()
    try:
        result = subprocess.run(command, timeout=300, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    except Exception as e:
        response_dict['status'] = -1
        response_dict['response'] = e
    else:
        response_dict['status'] = result.returncode
        response_dict['response'] = result.stdout.decode('utf-8') + '\n'
        response_dict['response'] += result.stderr.decode('utf-8') + '\n'
    finally:
        return response_dict


def check_md5_sum(check_type, md5_check_queue, md5_check_list, src_path, dest_path):
    if check_type == 'sse' or check_type == 'sse_etf':
        command = "ssh -p " + str(CONF['ssh_port']) + " " + CONF['sse_user'] + "@" + CONF['sse_host'] + " 'md5sum %s'"
    elif check_type == 'szse' or check_type == 'szse_etf':
        command = "ssh -p " + str(CONF['ssh_port']) + " " + CONF['szse_user'] + "@" + CONF['szse_host'] + " 'md5sum %s'"
    elif check_type == 'counter':
        command = "ssh -p " + str(CONF['other_places_art_port']) + " " + CONF['other_places_art_user'] + "@" + CONF['other_places_art_host'] + " 'md5sum %s'"
    else:
        raise KeyError('no such check_type: {}'.format(check_type))
    os.chdir(src_path)
    max_number = md5_check_queue.qsize()
    log_name = 'md5_check_info_{}.log'.format(time.strftime('%Y%m%d'))
    with open(os.path.join(DEPLOY_PATH, 'logs', log_name), 'a') as f:
        while True:
            try:
                filename = md5_check_queue.get(timeout=0.5)
                local_md5_dict = run_command('md5sum {}'.format(filename))
                if local_md5_dict['status'] != 0:
                    md5_check_list.append(local_md5_dict)
                    continue
                local_md5 = local_md5_dict['response'].split()[0]
                filepath = os.path.join(dest_path, filename)
                ssh_command = command % filepath
                response_dict = run_command(ssh_command)
                if response_dict['status'] != 0:
                    md5_check_list.append(response_dict)
                    continue
                remote_md5 = response_dict['response'].split()[0]
                f.write('%s filename: %s, local_md5: %s, remote_md5: %s\n' %
                        (time.strftime('%H:%M:%S'), filename, local_md5, remote_md5))
                if local_md5 != remote_md5:
                    md5_check_list.append(filename)
            except Exception as e:
                print(e.__str__())
                break


def main():
    parser = optparse.OptionParser()
    parser.add_option(
        "-t",
        "--check_type",
        default='sse',
        type="string",
    )
    parser.add_option(
        "-s",
        "--src_path",
        default='.',
        type="string",
    )
    parser.add_option(
        "-d",
        "--dest_path",
        type="string",
    )
    (options, _) = parser.parse_args()
    check_type = options.check_type.strip()
    src_path = options.src_path.strip()
    dest_path = options.dest_path.strip()
    if check_type in CONF['skip_md5_check']:
        sys.exit(0)
    start_time = time.time()
    md5_check_manager = Manager()
    md5_check_queue = md5_check_manager.Queue()
    md5_check_list = md5_check_manager.list()
    file_list = os.listdir(src_path)
    for filename in file_list:
        md5_check_queue.put(filename)
    jobs = [Process(target=check_md5_sum, args=(check_type, md5_check_queue, md5_check_list, src_path, dest_path))
            for _ in range(10)]
    for j in jobs:
        j.daemon = True
        j.start()
    for j in jobs:
        j.join()
    end_time = time.time()
    use_time = end_time - start_time
    if len(md5_check_list) == 0:
        print('check success, use time %s' % use_time)
    else:
        raise FileExistsError('check error, use time %s, error files in %s' % (use_time, md5_check_list))


if __name__ == '__main__':
    main()

