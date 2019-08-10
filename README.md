# toy OS Kernel (developing)

>  一个用于学习的玩具级操作系统内核，正在开发中

在我大二的时候，认为实现一个操作系统内核是很酷的事情，但是由于自己的懈怠，这一项目在完成到一半的时候被无限期的搁置了。每当回想起这件事还是觉得有些遗憾，如今我已经毕业，想要重新完成这一项目，希望这次不会再半途而废。 :p

| name   | contribution | email                |
| ------ | ------------ | -------------------- |
| rupert | 作者         | jxrupert@outlook.com |

## 参考资料

- 《Orange's 一个操作系统的实现》 于渊
- 《汇编语言(第3版) 》 王爽

## 开发环境

- Windows 10 / Windows Subsystem for Linux
- VS Code
- Bochs 2.6.9
- GCC，GNU Make，NASM
- UltraISO 试用版

## 开发进度与问题记录

#### 2019-8-08

实现了`boot.asm`，并添加了详细注释，在实现过程中遇到了一些问题，问题描述和解决方案如下：

- 程序中的一些宏定义我本来不想写死，而是想定义成内存变量，在程序动态计算，但是实现后发现这样会导致引导扇区大于512B，无奈只能像书中一样写死

- `boot.asm`第`181`行必须空一行，否则nasm编译后总是将`182`行的压栈语句忽略，不知道为什么，我真是无奈

- 不理解`boot.asm`中的`384`行到`391`行，原因是对`FAT`项的表示产生了一些误解

  **前提**：

  三个字节包含两个`FAT`项，每个`FAT`项占`12`位；

  两个字节包含一个完整`FAT`项的值，偶数项取前两个字节，奇数项取后两个字节

  **问题描述**：

  我一开始认为FAT项应该这么看：

  | LOW   | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    | HIGH |
  | ----- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
  | BYTE1 | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    |      |
  | BYTE2 | 8    | 9    | A    | B    | 0    | 1    | 2    | 3    |      |
  | BYTE3 | 4    | 5    | 6    | 7    | 8    | 9    | A    | B    |      |

  FATEntry1（偶）: byte1[0到7] 和 byte2[0到3]

  FATEntry2（奇）: byte2[4到7] 和 byte3[0到7]

  这样表示数据确实没有错，但是计算机中右移是将数据从高位移至低位，这样看容易让自己误解右移的方向是由低位到高位，因此我当时认为应该是偶数FAT项右移4位，奇数FAT项保留低12位

  **解决方案**

  后来发现，这样看FAT项，更符合计算机存储数据的方式

  | HIGH  | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | LOW  |
  | ----- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
  | BYTE1 | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    |      |
  | BYTE2 | 3    | 2    | 1    | 0    | B    | A    | 9    | 8    |      |
  | BYTE3 | B    | A    | 9    | 8    | 7    | 6    | 5    | 4    |      |

  FATEntry1（偶）: byte1[0到7] 和 byte2[0到3]

  FATEntry2（奇）: byte2[4到7] 和 byte3[0到7]

  根据小端法：

  偶数FAT项需要读取前两个字节并取后12位

  奇数FAT项读取后两个字节并右移四位

第四章结束，下一次继续回到前面复习第三章。（继续枯燥:p）

#### 2019-8-05

由于第三章是学习性质的章节，对我来说太枯燥了。因此我决定先暂停第三章的学习，开始第四章，为我的内核做一些真正的工作。书中第四章实现了一个启动扇区，目的是将`Loader.bin`从文件系统为`FAT12`的软盘中读至内存，并跳转至`Loader.bin`

- 学习了`FAT12`文件系统
- 独立实现了`ReadSector`函数，此函数的功能为读取软盘扇区到目标地址处，详见`boot.asm`
  - 软盘存储数据按照如下顺序：0号盘面的0号磁道，1号盘面的0号磁道，0号盘面的1号磁道...，以此类推
- 实现了`DispStr`函数，此函数能够在显示器上输出一些信息，见`boot.asm`
- 完成了一部分`boot.asm`

#### 2019-8-03

- 理解了代码`chapter3/c/pmtest3.asm`，此代码在`protect_mode_test/pmtest_0730.asm`的基础上引入了`LDT`，我照着书实现了一遍，并添加了相应的注释，详见`protect_mode_test/pmtest_0802.asm`（保护模式的学习什么时候能结束啊！！！！！）

- 用`Python`实现了一个第四章中的简易的二进制查看器`xxd.py`，用法如下：

  ```shell
  # ./xxd.py [每行的字节数] [目标文件被查看的起始地址（16进制）] [被查看字节数] [目标文件]
  ./xxd.py 16 0x2600 512 x.img #每行字节数为16，目标文件被查看的起始地址为0x2600，被查看的字节数为512，目标文件为x.img
  ```

  功能非常简单，大部分的时间用在调输出格式上了 :p

#### 2019-8-01

- 再次复习了一些汇编语言知识
- 理解了代码`chapter3/b/pmtest2.asm`，此代码从实模式跳至保护模式，向内存地址为`5M`的内存空间处写入了一些数据，又从保护模式跳回了实模式，我照着书实现了一遍，并根据自己的理解为代码添加了注释，详见`protect_mode_test/pmtest_0730.asm`
  - 为啥从保护模式跳至实模式要将所有段寄存器赋值为`SelectorNormal`，答案见：[关于从保护模式切换到实模式的相关说明](http://blog.chinaunix.net/uid-22683402-id-1771401.html)
- `tips`：针对在`FreeDos`系统下运行我们编写的程序时，无法使用`bochsdbg`对程序进行调试问题的解决办法
  - 在我们想设置断点的地方加上`jmp $`
  - 进入`FreeDos`，运行程序，此时程序进入无限循环
  - 在运行`Bochs`的命令行中按`Ctrl + C`，暂停程序运行
  - 在运行`Bochs`的命令行中键入`set $eip=addr`，`addr`为当前`eip`中的内容+2
  - 即可对程序进行单步调试

#### 2019-7-29

- 复习了一些汇编语言知识
- 理解了代码`chapter3/a/pmtest1.asm`，此代码实现了从实模式跳转至保护模式，并结合自己的理解给`protect_mode_test/pmtest_0727.asm`添加了注释
- 理解了保护模式下的寻址方式

#### 2019-7-27

- 继续搭建`Windows`下的开发环境
  - 安装`Windows Subsystem for Linux`
    - 步骤
      - 在`Windows 10`设置中开启开发人员模式
      - 在`Windows`应用商店中搜索`Linux`，选乌班图下载
      - 在`cmd`中运行`bash`
    - 更换阿里云软件源：[Ubuntu18.04下更改apt源为阿里云源](https://blog.csdn.net/zhangjiahao14/article/details/80554616)
    - 安装`build-essential`软件包和`NASM`
  - 书中需要使用`freedos`运行二进制程序，可在`WSL`下无法挂载软盘，只能在`Windows`中使用软碟通打开软盘，`bximage`生成的软盘镜像软碟通又无法读取，只能把程序放在`freedos.img`中，明天再看看有没有更好的解决方法
- 尝试理解保护模式和书中所附代码`chapter3/a/pmtest1.asm`，同时照着书实现了一遍（我写的`dd.py`还挺好用:p），见`protect_mode_test/pmtest_0727.asm`，这里发现自己以前学过的汇编语言忘得七七八八了。实模式下的寻址，堆栈是如何压栈和出栈的，显存的地址，这些东西几乎都忘了，后面可能要再看看

#### 2019-7-26

- 开始《Orange's 一个操作系统的实现》

- 搭建了部分`Windows`下的开发环境

  - 安装`Bochs 2.6.9`
    - 调试模式和`Linux`版本的`Bochs`有一些区别，`Windows`下调试模式是一个独立的程序`bochsdbg.exe`
    - 调试模式的命令：[bochs2.6.9 配置文件详解.和相关调试到虚拟机运行](https://blog.csdn.net/chprain/article/details/79328673)
  - 将`Bochs`的安装目录添加进了环境变量`Path`中，以便直接使用

- 用`Python`实现了一个简易的引导扇区写入工具`dd.py`，用法如下：

  ```shell
  # ./dd.py [被写入文件] [目标镜像文件]
  ./dd.py boot.bin a.img # boot.bin为引导扇区内容，a.img为软盘镜像
  ```

- 实现了第一章中的引导扇区

  - 这里遇到了大端法小端法问题，`boot_0726.asm`中定义了最后两个字节的内容为`0xaa55`，编译出的`boot_0726.bin`大小为`512`字节，其中第`511`字节的内容为`0x55`，第`512`字节的内容为`0xaa`，而我使用的是`Intel CPU`，因此`Intel CPU`的数据存储方式为小端法 (这一认知似乎对我完成后面的工作并没有什么卵用 :p)