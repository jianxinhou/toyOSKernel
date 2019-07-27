
%include    "pm.inc"
;org 07c00h
org 0100h
;跳转到程序可执行代码起始处
    jmp LABEL_BEGIN

[SECTION .gdt]
;GDT部分
;                                       段基址          段界限               属性
LABEL_GDT:          Descriptor          0,              0,                  0               ;空描述符
LABEL_DESC_CODE32:  Descriptor          0,              SegCode32Len - 1,   DA_C + DA_32    ;非一致代码段
LABEL_DESC_VIDEO:   Descriptor    0B8000h,              0ffffh,             DA_DRW          ;显存段

GdtLen  equ $   -   LABEL_GDT   ;GDT长度
GdtPtr  dw  GdtLen  -   1       ;GDT界限
        dd  0                   ;GDT基地址

;GDT选择子，负责选择相应的GDT
SelectorCode32      equ LABEL_DESC_CODE32   -   LABEL_GDT
SelectorVideo       equ LABEL_DESC_VIDEO    -   LABEL_GDT

[SECTION .s16]
;16位代码段
[BITS   16]
LABEL_BEGIN:
    ;对寄存器进行初始化
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    ;初始化32位代码段（LABEL_SEG_CODE32）描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [GdtPtr + 2], eax

    lgdt    [GdtPtr]

    cli

    in  al, 92h
    or  al, 00000010b
    out 92h, al

    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    jmp dword SelectorCode32:0

[SECTION .s32]
[BITS   32]

LABEL_SEG_CODE32:
    mov ax, SelectorVideo
    mov gs, ax

    mov edi, (80 * 11 + 79) * 2
    mov ah, 0Ch
    mov al, 'P'
    mov [gs:edi], ax

    jmp $

SegCode32Len	equ	$ - LABEL_SEG_CODE32