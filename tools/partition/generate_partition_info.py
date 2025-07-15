# -*- coding: utf-8 -*-
import sys
import xml.etree.ElementTree as ET

def parse_partition_info(xml_file):
    partition_info = []
    tree = ET.parse(xml_file)
    root = tree.getroot()

    for partition in root.find('physical_partition'):
        label = partition.get('label')
        size_kb = int(partition.get('size_in_kb'))
        size_hex = hex(size_kb * 1024)[2:]  # Convert size to hex and remove '0x' prefix
        partition_info.append('{} 0x{}'.format(label, size_hex))


    return ' '.join(partition_info)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python script_name.py xml_file")
        sys.exit(1)

    xml_file = sys.argv[1]
    output = parse_partition_info(xml_file)
    print(output)
