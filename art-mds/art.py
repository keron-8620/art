#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
import sys
sys.path.append("scripts")

import argparse
import art_modules
import constants as C


def cmd_parse():
    parser = argparse.ArgumentParser()

    parser.add_argument("-v", "--version", action="store_true", help="版本信息")

    parser.add_argument("-t", "--status", action="store_true", help="状态信息")

    # parser.add_argument("cmd", type=str, choices=["mon", "csdc", "xcounter", "sse", "szse"])

    return parser.parse_args()


def main():
    args = cmd_parse()
    version, status = args.version, args.status

    if version:
        art_modules.print_version()
    elif status:
        art_modules.print_status(C.SYSTEM)


if __name__ == '__main__':
    main()
