from art_modules.status import Display
from art_modules.version import *


def print_status(system):

    display = Display(system)
    display.display()


def print_version():
    print_title()
    print_update_time()
    print_config_file()
    print_ansible_config_file()
    print_rely_on_python3()
    print_rely_on_ansible()


