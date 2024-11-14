#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
import os
import time
import re
import constants as C

file_lock_prefix = "art.lock"
file_lock_compile = re.compile(r"^art\.lock\.\d{10}")

now = lambda: int(time.time())


def get_filelock():
    file_list = os.listdir(C.LOCK_FILE_PATH)
    lock_file_list = [file for file in file_list if file_lock_compile.match(file)]
    if lock_file_list:
        return lock_file_list
    else:
        return list()


def is_filelock_timeout(file_lock):
    _time = int(re.search(r"\d{10}", file_lock).group())
    return now() - _time > C.LOCK_TIMEOUT


def wait_file_lock(lock):
    lock_path = os.path.join(C.LOCK_FILE_PATH, lock)
    while os.path.exists(lock_path):
        if is_filelock_timeout(lock):
            os.remove(lock_path)
        else:
            time.sleep(0.1)


def wait_all_file_lock(file_lock_list):
    # 如果文件锁存在， 判断是否超时，
    # 知道文件锁被删除
    for lock in file_lock_list:
        wait_file_lock(lock)


def create_filelock():
    filelock = f"{file_lock_prefix}.{now()}"
    filelock_path = os.path.join(C.LOCK_FILE_PATH, filelock)
    if os.path.exists(filelock_path):
        wait_file_lock(filelock)

    filelock = f"{file_lock_prefix}.{now()}"
    filelock_path = os.path.join(C.LOCK_FILE_PATH, filelock)
    file = open(filelock_path, "w")
    file.close()
    return filelock


def run():
    # 检查文件锁是否存在，
    #  存在多久
    #    合理 等待， 不合理， 删除
    # 创建
    #   失败， 继续等待 文件锁
    #   成功
    file_lock_list = get_filelock()
    wait_all_file_lock(file_lock_list)
    filelock_name = create_filelock()
    print(filelock_name)


if __name__ == "__main__":
    run()
