# @File  : dd.py
# @Author: jianxinhou
# @Date  : 2019/7/26
# @Desc  : 一段简易的将二进制程序写入软盘镜像文件的程序
import sys

#被写入的二进制文件
binary_file_path = sys.argv[1]
#目标软盘文件
target_floppy_file_path = sys.argv[2]
#读取二进制文件
with open(binary_file_path,'rb') as fobj:
    binary_file_content = fobj.read()
    binary_file_size = len(binary_file_content)

#读取软盘原内容
with open(target_floppy_file_path,'rb') as fobj:
    floppy_file_content = fobj.read()
    floppy_file_content = bytearray(floppy_file_content)
    floppy_file_size = len(floppy_file_content)

#向软盘第一个扇区写入这一二进制文件
with open(target_floppy_file_path,'wb') as fobj:
    floppy_file_content[:len(binary_file_content)] = binary_file_content[:]
    fobj.write(floppy_file_content)
    
print("软盘大小为{}字节，写入的二进制文件带下为{}字节".format(binary_file_size, floppy_file_size))
