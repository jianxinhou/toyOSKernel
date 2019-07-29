
%include    "pm.inc"
org 07c00h
;org 0100h
;跳转到程序可执行代码起始处
    jmp LABEL_BEGIN

[SECTION .gdt]
;GDT部分
;                                       段基址          段界限               属性
LABEL_GDT:          Descriptor          0,              0,                  0               ;空描述符
LABEL_DESC_CODE32:  Descriptor          0,              SegCode32Len - 1,   DA_C + DA_32    ;32位代码段
LABEL_DESC_VIDEO:   Descriptor    0B8000h,              0ffffh,             DA_DRW          ;显存段

GdtLen  equ $   -   LABEL_GDT   ;GDT长度
GdtPtr  dw  GdtLen  -   1       ;GDT界限
        dd  0                   ;GDT基地址

;GDT选择子，负责选择相应的GDT
SelectorCode32      equ LABEL_DESC_CODE32   -   LABEL_GDT   ;32位代码段对应的选择子 
SelectorVideo       equ LABEL_DESC_VIDEO    -   LABEL_GDT   ;video段对应的选择子   

[SECTION .s16]
;16位代码段
[BITS   16]
;程序可执行代码起始处
LABEL_BEGIN:
    ;初始化段寄存器和堆栈寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    ;初始化32位代码段（LABEL_SEG_CODE32）描述符
    ;取出当前段基址
    xor eax, eax
    mov ax, cs
    shl eax, 4
    ;计算32位代码段基址
    add eax, LABEL_SEG_CODE32
    ;将计算得到的段基址别赋值给LABEL_SEG_CODE32对应Descriptor中段基址的相应字节
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ;为加载GDT寄存器做准备
    ;取出当前数据段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    ;计算GDT的起始地址
    add eax, LABEL_GDT
    ;将这一地址赋值给GdtPtr的后4字节
    mov dword [GdtPtr + 2], eax

    ;将GdtPtr加载至GDT寄存器
    lgdt    [GdtPtr]

    ;关中断
    cli

    ;打开A20地址线
    in  al, 92h
    or  al, 00000010b
    out 92h, al

    ;将cr0寄存器中第0位置1，即保护模式的开关
    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    ;跳转至32位代码段，正式进入保护模式
    jmp SelectorCode32:dword 0  ;此句被编译为32位代码。不加dword的话，则会被编译为16位代码，即若“：”后大于0xffff，高位部分会被截断

[SECTION .s32]
;32位代码段
[BITS   32]
;32位代码段入口
LABEL_SEG_CODE32:
    ;将gx设置位video selector
    mov ax, SelectorVideo
    mov gs, ax

    ;将'P'字显示在屏幕右侧
    mov edi, (80 * 11 + 79) * 2 ;第11行，79列
    mov ah, 0Ch                 ;颜色
    mov al, 'P'                 ;'P'字母
    mov [gs:edi], ax            ;将'P'移至显存处

    ;保持程序运行
    jmp $               

SegCode32Len	equ	$ - LABEL_SEG_CODE32