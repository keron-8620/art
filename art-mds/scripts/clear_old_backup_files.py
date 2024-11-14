import os
import optparse
import time
import shutil


def main():
    parser = optparse.OptionParser()
    parser.add_option(
        "-p",
        "--path",
        type="string",
    )
    parser.add_option(
        "-k",
        "--key_word",
        default='txlog',
        type="string",
    )
    parser.add_option(
        "-d",
        "--clear_data",
        type="string",
    )
    (options, _) = parser.parse_args()
    path = options.path.strip()
    key_word = options.key_word.strip()
    clear_data = options.clear_data.strip()
    today = int(time.strftime('%Y%m%d', time.localtime()))
    for log_data in os.listdir(path):
        if today - int(log_data) > int(clear_data):
            log_dir = os.path.join(path, log_data)
            for filename in os.listdir(log_dir):
                if key_word.lower() in filename.lower():
                    filepath = os.path.join(log_dir, filename)
                    if os.path.isfile(filepath):
                        os.remove(filepath)
                    elif os.path.isdir(filepath):
                        shutil.rmtree(filepath)


if __name__ == '__main__':
    main()

