import time
import requests

from optparse import OptionParser
from constants import CONF

SET_NUM = CONF['monlog_set_num']
URL = CONF['monlog_url']
RETRY = CONF['monlog_retry']
SERVER_NUM = CONF['monlog_server_num']
PLATFORM = CONF['monlog_platform']
MODULE = CONF['monlog_module']


def _send_log(log_level, log_content):
    retry_time = RETRY
    while retry_time > 0:
        header = {
            'Content-Type': 'application/json'
        }
        data = {
            'clusterNo': '%02d' % int(SET_NUM),
            'serverNo': SERVER_NUM,
            'platform': PLATFORM,
            'module': MODULE,
            'timestamp': int(round(time.time() * 1000)),
            'level': log_level,
            'content': log_content
        }
        try:

            res = requests.post(url=URL, json=data, headers=header, timeout=5)
            print(res.text)
            break

        except Exception as e:
            # logger.error("MonRsp[{}]".format(e))
            print(e)
            retry_time = retry_time - 1
            time.sleep(0.001)


def error(log_content):
    _send_log("ERROR", log_content)


def bzerr(log_content):
    _send_log("BZERR", log_content)


def bzinf(log_content):
    _send_log("BZINF", log_content)


def bzwarn(log_content):
    _send_log("BZWRN", log_content)


if __name__ == '__main__':
    # error("hello, world !!!")
    usage = 'usage: %prog [options] arg1 arg2 arg3 '
    parser = OptionParser(usage=usage, version='%prog 0.16')

    parser.add_option("-l", "--level", type='string', default='error',
                      metavar='level',
                      help="日志等级")
    parser.add_option("-c", "--con", type='string',
                      metavar='con',
                      help="日志内容")

    (options, _) = parser.parse_args()

    level = options.level.strip()
    con = options.con.strip()

    if level == "error":
        error(con)
    elif level == "bzinf":
        bzinf(con)
    elif level == "bzwarn":
        bzwarn(con)
    elif level == "bzerr":
        bzerr(con)
    else:
        raise Exception("invalid params")
