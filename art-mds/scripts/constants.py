import os
import yaml

DEPLOY_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

CONF_FILENAME = "automatic.yml"

def GetYamlConf(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            config_dict = yaml.load(f.read())
    except:
        with open(path, 'r', encoding='utf-8') as f:
            config_dict = yaml.load(f.read(), Loader=yaml.Loader)
    return config_dict

CONF = GetYamlConf(os.path.join(DEPLOY_PATH, CONF_FILENAME))

SYSTEM = CONF['system']

# 文件锁相关配置
LOCK_FILE_PATH = "/tmp"
LOCK_TIMEOUT = 2

