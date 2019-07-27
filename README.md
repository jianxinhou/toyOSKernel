# toy OS Kernel (developing)

>  一个用于学习的玩具级操作系统内核，正在开发中

在我大二的时候，认为实现一个操作系统内核是很酷的事情，但是由于自己的懈怠，这一项目在完成到一半的时候被无限期的搁置了。每当回想起这件事还是觉得有些遗憾，如今我已经毕业，想要重新完成这一项目，希望自己这次不会再半途而废。 :p

| name   | contribution | email                |
| ------ | ------------ | -------------------- |
| rupert | 作者         | jxrupert@outlook.com |

## 参考资料

- 《Orange's 一个操作系统的实现》

## 开发环境

- Windows 10 / Windows Subsystem for Linux

- VS Code
- Bochs 2.6.9
- GCC，GNU Make，NASM

## 开发进度与问题记录

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
- 尝试理解保护模式和书中的**代码3.1**`pmtest.asm`，同时照着书敲了一遍（我写的`dd.py`还挺好用:p），这里发现自己以前学过的汇编语言忘得七七八八了。实模式下的寻址，堆栈是如何压栈和出栈的，显存的地址，这些东西几乎都忘了，后面可能要再看看

#### 2019-7-26

- 开始《Orange's 一个操作系统的实现》

- 搭建了部分`Windows`下的开发环境

  - 安装`Bochs 2.6.9`
    - 调试模式和`Linux`版本的`Bochs`有一些区别，`Windows`下调试模式是一个独立的程序`bochsdbg.exe`
    - 调试模式的命令：[bochs2.6.9 配置文件详解.和相关调试到虚拟机运行](https://blog.csdn.net/chprain/article/details/79328673)
  - 将``Bochs`的安装目录添加进了环境变量`Path`中，以便直接使用

- 用`Python`实现了一个简易的引导扇区写入工具`dd.py`，用法如下：

  ```shell
  #boot.bin为引导扇区内容，a.img为软盘镜像
  ./dd.py boot.bin a.img 
  ```

- 实现了第一章中的引导扇区

  - 这里遇到了大端法小端法问题，`boot.asm`中定义了最后两个字节的内容为`0xaa55`，编译出的`boot.bin`大小为`512`字节，其中第`511`字节的内容为`0x55`，第`512`字节的内容为`0xaa`，而我使用的是`Intel CPU`，因此`Intel CPU`的数据存储方式为小端法 (这一认知似乎对我完成后面的工作并没有什么卵用 :p)