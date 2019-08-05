#!/usr/bin/env python3
# @File         : xxd.py
# @Author       : jianxinhou
# @Date         : 2019/8/3
# @Desc         : 简易二进制查看器
# @How to use   : ./xxd.py [每行的字节数] [目标文件被查看的起始地址（16进制）] [被查看字节数] [目标文件]

import sys
import string

# 整理参数
# 每行显示的字节数
byte_number_per_line = int(sys.argv[1])
# 目标文件被查看的起始地址（16进制）
start_address = int(sys.argv[2],16)
# 被查看字节数
select_byte_number = int(sys.argv[3])
# 目标文件
target_file = sys.argv[4]
# 字节数为byte_number_per_line的行数
line_number = select_byte_number // byte_number_per_line
# 最后一行的字节数
last_line_byte_number = select_byte_number % byte_number_per_line
# 最后一行会被拿出来单独处理，因此要计算最后一行的字节数
if last_line_byte_number == 0:
    line_number -= byte_number_per_line
    last_line_byte_number = byte_number_per_line

# 函数功能为输出一行数据
# 规定output_byte_number应该小于byte_number_per_line
def print_line(data_bytes: '待输出数据', 
             line_address: '当前行在文件中的首地址',
     byte_number_per_line: '规定每行显示的字节数', 
      output_byte_number: '实际每行显示的字节数', 
               digits_num: '地址列的数字位数', ):
    # 这一变量存在的意义也是为了好看
    print_addr_str = '{:0>'+str(digits_num)+'x}'
    # 在行左侧输出每行的起始地址
    print(print_addr_str.format(line_address),end = ': ')
    # 在行中间输出二进制数据
    for data in data_bytes:
        print('{:0>2X}'.format(data), end = ' ')
    if output_byte_number < byte_number_per_line:
        print('   '*(byte_number_per_line - output_byte_number), end = '')
    print(' ',end = ' ')
    # 在行右侧输出二进制数据对应的字符
    for data in data_bytes:
        if chr(data) in string.printable[:-5]:
            print(chr(data), end = '')
        else:
            print('.',end='')
    print()

# 这一行是为了省略显示数据为0的行
zeros_bytes = bytearray(byte_number_per_line)
# 打开文件进行操作
with open(target_file, 'rb') as fobj:
    # 将文件指针移动到start_address处
    fobj.seek(start_address, 0)
    # 这一变量的存在纯粹为了好看，统一左边地址列的位数
    digits_num = len(hex(start_address + select_byte_number)) - 2
    if digits_num < 8:
        digits_num = 8
    # 用于显示数据为0的行
    is_first_zeros_line = False
    # 按行读取
    for i in range(0, line_number):
        # 在文件中读取数据
        data_bytes = bytes(fobj.read(byte_number_per_line))
        # 判断当前行是否为0
        if data_bytes == zeros_bytes:
            # 对数据为0的行进行省略
            if is_first_zeros_line == False:
                is_first_zeros_line = True
                print_line(data_bytes = data_bytes,
                        line_address = start_address + byte_number_per_line * i,
                        byte_number_per_line = byte_number_per_line,
                        output_byte_number = byte_number_per_line,
                        digits_num = digits_num)
                print('*')
        else:
            # 输出第i行数据
            print_line(data_bytes = data_bytes,
                line_address = start_address + byte_number_per_line * i,
                byte_number_per_line = byte_number_per_line,
                output_byte_number = byte_number_per_line,
                digits_num = digits_num)        
            is_first_zeros_line = False   
    # 读取最后一行数据
    data_bytes = bytes(fobj.read(last_line_byte_number))  
    # 输出最后一行数据 
    print_line(data_bytes = data_bytes,
    line_address = start_address + byte_number_per_line * line_number ,
    byte_number_per_line = byte_number_per_line,
    output_byte_number=last_line_byte_number,
    digits_num=digits_num)  

        


