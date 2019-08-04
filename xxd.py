# @File         : xxd.py
# @Author       : jianxinhou
# @Date         : 2019/8/3
# @Desc         : 简易二进制查看器
# @How to use   : ./xxd.py [每行的字节数] [起始位置（16进制）] [查看字节数] [目标文件]
import sys
import string
# 每行显示的字节数
bytes_per_line = int(sys.argv[1])
# 起始位置
start_address = int(sys.argv[2],16)
# 查看字节数
bytes_number = int(sys.argv[3])
# 目标文件
target_file = sys.argv[4]

with open(target_file, 'rb') as fobj:
    # 将文件指针移动到start_address处
    fobj.seek(start_address, 0)
    # 起始位置
    begin = start_address
    # 终止位置
    end = start_address + bytes_number
    # 这个变量的存在纯粹为了好看，统一左边那列数字的位数
    digits_num = len(hex(end)) - 2
    if digits_num < 8:
        digits_num = 8
    # 一行一行输出数据
    last_data_bytes = bytearray(16)
    num = 0
    for i in range(begin, end, bytes_per_line):
        data_bytes = bytes(fobj.read(bytes_per_line))
        if data_bytes == last_data_bytes:
            if num == 0:
                print('*')
            num += 1
        else:
            #这一变量存在的意义和digits_num一样
            print_addr_str = '{:0>'+str(digits_num)+'x}'
            #输出每行的起始地址
            print(print_addr_str.format(i),end = ': ')
            for data in data_bytes:
                print('{:0>2X}'.format(data), end = ' ')
            print(' ',end = ' ')
            for data in data_bytes:
                if chr(data) in string.printable[:-5]:
                    print(chr(data), end = '')
                else:
                    print('.',end='')
            print()
            last_data_bytes = data_bytes
            num = 0
            

        


