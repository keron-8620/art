from collections import namedtuple


def parse_csv(path: str, headers: list) -> list:
    csv_list = []

    data_namedtuple = namedtuple("CsvLine", headers)
    with open(path) as f:
        for line in f:
            if line.startswith("#") or line.strip() == "":
                continue

            line_data = [i.strip() for i in line.split("|")]
            csv_list.append(data_namedtuple(**dict(zip(headers, line_data))))
        return csv_list
