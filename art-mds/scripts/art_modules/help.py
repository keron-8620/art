

import yaml
import os

from optparse import OptionParser


curr_path = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(curr_path, 'data/art_info.yml')) as f:
    art_info = yaml.load(f)

HelpInfo = art_info.get('help_info')
VersionInfo = art_info.get('version_info')


def display_explanation():
    print('Explanation: ')
    for key, info in HelpInfo.items():
        print(' {:30} {}'.format(info.get('cmd').strip(), info.get('description').strip()))
    print()


def display_params(help_info):
    params_list = help_info.get('params')

    print('Options: ')
    for params in params_list:
        print('  ' + params)
    print()


def display_help(action=None):
    if action:
        help_info = HelpInfo.get(action, None)
        title = '{:14}    {}'.format(help_info.get('cmd'), help_info.get('description'))
        print(title)
        display_params(help_info)
    else:
        full_version = VersionInfo.get('name') + ' ' + VersionInfo.get('version')
        print(full_version + '\n')
        display_params(HelpInfo.get('art'))
        display_explanation()

# if __name__ == "__main__":
#     usage = 'usage: %prog [options] arg1 '
#     parser = OptionParser(usage=usage, version='%prog 0.15.7')
#     parser.add_option(
#         "-a",
#         "--action",
#         # dest='action',
#         type='string',
#         default='',
#         metavar="operation_action",
#         help="待执行的命令(例:start; stop; backup)")
#     (options, _) = parser.parse_args()
#     action = options.action.strip()
#     print(action)
#     if action:
#         display_action_help(action)
#     else:
#         display()
