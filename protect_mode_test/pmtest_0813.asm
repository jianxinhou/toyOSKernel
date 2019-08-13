%include    "pm.inc"
;org 07c00h
org 0100h   ;设置为在FreeDos中运行的方式
;跳转到程序可执行代码起始处
    jmp LABEL_BEGIN

[SECTION .gdt]
;GDT部分
;                                           段基址          段界限               属性
LABEL_GDT:              Descriptor          0,              0,                  0                           ;空描述符
LABEL_DESC_NORMAL:      Descriptor          0,              0ffffh,             DA_DRW                      ;Normal描述符（用于从保护模式跳转至实模式时设置段寄存器）
LABEL_DESC_CODE32:      Descriptor          0,              SegCode32Len - 1,   DA_C + DA_32                ;32位代码段
LABEL_DESC_CODE16:      Descriptor          0,              0ffffh,             DA_C                        ;16位代码段
LABEL_DESC_CODE_DEST:   Descriptor          0,              SegCodeDestLen - 1, DA_C + DA_32                ;非一致代码段， 32
LABEL_DESC_CODE_RING3:  Descriptor          0,              SegCodeRing3Len- 1, DA_C + DA_32 + DA_DPL3      ;RING3代码段
LABEL_DESC_TSS:         Descriptor          0,              TSSLen  -   1,      DA_386TSS                   ;TSS段
LABEL_DESC_DATA:        Descriptor          0,              DataLen - 1,        DA_DRW                      ;Data段
LABEL_DESC_STACK:       Descriptor          0,              TopOfStack,         DA_DRWA + DA_32             ;全局堆栈段
LABEL_DESC_STACK3:      Descriptor          0,              TopOfStack3,        DA_DRWA + DA_32 + DA_DPL3   ;ring3堆栈段
LABEL_DESC_TEST:        Descriptor          0500000h,       0ffffh,             DA_DRW                      ;测试代码段
LABEL_DESC_VIDEO:       Descriptor          0B8000h,        0ffffh,             DA_DRW + DA_DPL3            ;显存段
LABEL_DESC_LDT:         Descriptor          0,              LdtLen - 1,         DA_LDT                      ;LDT段

LABEL_CALL_GATE_TEST:   Gate                SelectorCodeDest,           0,         0,      DA_386CGate + DA_DPL3    ;调用门

GdtLen  equ $   -   LABEL_GDT   ;GDT长度
;GdtPtr将会被加载进GDTR
GdtPtr  dw  GdtLen  -   1       ;GDT界限
        dd  0                   ;GDT基地址

;GDT Selector，负责为对应的段寄存器选择相应的GDT
SelectorNormal          equ LABEL_DESC_NORMAL       -   LABEL_GDT               ;Normal段对应的Selector
SelectorCode32          equ LABEL_DESC_CODE32       -   LABEL_GDT               ;32位代码段对应的Selector 
SelectorCode16          equ LABEL_DESC_CODE16       -   LABEL_GDT               ;16位代码段对应的Selector
SelectorCodeDest        equ LABEL_DESC_CODE_DEST    -   LABEL_GDT               ;DEST段对应的Selector
SelectorCodeRing3       equ LABEL_DESC_CODE_RING3   -   LABEL_GDT   +   SA_RPL3 ;ring3代码段对应的Selector
SelectorTss             equ LABEL_DESC_TSS          -   LABEL_GDT               ;TSS对应的Selector
SelectorData            equ LABEL_DESC_DATA         -   LABEL_GDT               ;Data段对应的Selector
SelectorStack           equ LABEL_DESC_STACK        -   LABEL_GDT               ;Stack段对应的Selector
SelectorStack3          equ LABEL_DESC_STACK3       -   LABEL_GDT   +   SA_RPL3 ;Stack3段对应的Selector
SelectorTest            equ LABEL_DESC_TEST         -   LABEL_GDT               ;Test段对应的Selector
SelectorVideo           equ LABEL_DESC_VIDEO        -   LABEL_GDT               ;video段对应的Selector   
SelectorLDT             equ LABEL_DESC_LDT          -   LABEL_GDT               ;LDT段对应的Selector

SelectorCallGateTest    equ LABEL_CALL_GATE_TEST    -   LABEL_GDT   +   SA_RPL3 ;调用门对应的Selector

[SECTION .data]
;数据段
ALIGN   32
[BITS   32]
LABEL_DATA:
SPValueInRealMode       dw      0
PMMessage               db      "In Protect Mode now. :p", 0    ;进入保护模式后显示这一信息
OffsetPMMessage         equ     PMMessage - $$
StrTest                 db      "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0 ;TestWrite将向Test段写入的数据
OffsetStrTest           equ     StrTest - $$
DataLen                 equ     $ - LABEL_DATA                  ;段长

[SECTION .tss]
ALIGN 32
[BITS 32]
LABEL_TSS:
    dd  0                       ;back
    dd  TopOfStack              ;ring0 对应的堆栈段
    dd  SelectorStack
    dd  0                       ;ring1 对应的堆栈段
    dd  0                       
    dd  0                       ;ring2 对应的堆栈段
    dd  0   
    dd  0                       ;cr3
    dd  0                       ;eip
    dd  0                       ;eflags
    dd  0                       ;eax
    dd  0                       ;ecx
    dd  0                       ;edx
    dd  0                       ;ebx
    dd  0                       ;esp
    dd  0                       ;ebp
    dd  0                       ;esi
    dd  0                       ;edi
    dd  0                       ;es
    dd  0                       ;cs
    dd  0                       ;ss
    dd  0                       ;ds
    dd  0                       ;fs
    dd  0                       ;gs
    dd  0                       ;LDT
    dw  0                       ;调试陷阱标志
    dw  $ - LABEL_TSS + 2       ;I/O位图基址
    db  0FFh                    ;I/O位图结束标志
TSSLen  equ     $   -   LABEL_TSS
    


[SECTION .globalstack]
;全局堆栈段
ALIGN   32
[BITS   32]
LABEL_STACK:
    times   512     db  0                   ;共512字节
TopOfStack  equ     $ - LABEL_STACK - 1     ;栈顶=511 

[SECTION .stack3]
;ring3堆栈段
ALIGN 32
[BITS 32]
LABEL_STACK3:
    times   512     db  0
TopOfStack3 equ     $ - LABEL_STACK3 - 1

[SECTION .s16]
;实模式下的16位代码段
[BITS   16]
;程序可执行代码起始处
LABEL_BEGIN:
    ;初始化段寄存器和堆栈寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    ;将LABEL_GO_BACK_TO_REAL处改为jmp 实模式下的cs:LABLE_REAL_ENTRY
    mov [LABEL_GO_BACK_TO_REAL + 3], ax
    ;保存当前栈顶地址
    mov [SPValueInRealMode], sp

    ;设置32位代码段的段基址
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

    ;设置保护模式下16位代码段的段基址
    mov ax, cs
    movzx   eax, ax
    shl eax, 4
    add eax, LABEL_SEG_CODE16
    mov word [LABEL_DESC_CODE16 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16 + 4], al
    mov byte [LABEL_DESC_CODE16 + 7], ah

    ;设置Dest段段基址
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE_DEST    
    mov word [LABEL_DESC_CODE_DEST + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE_DEST + 4], al
    mov byte [LABEL_DESC_CODE_DEST + 7], ah

    ;设置ring3代码段段基址
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE_RING3   
    mov word [LABEL_DESC_CODE_RING3 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE_RING3 + 4], al
    mov byte [LABEL_DESC_CODE_RING3 + 7], ah

    ;设置TSS段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_TSS
    mov word [LABEL_DESC_TSS + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_TSS + 4], al
    mov byte [LABEL_DESC_TSS + 7], ah

    ;设置数据段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
    mov word [LABEL_DESC_DATA + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA + 4], al
    mov byte [LABEL_DESC_DATA + 7], ah

    ;设置堆栈段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_STACK
    mov word [LABEL_DESC_STACK + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK + 4], al
    mov byte [LABEL_DESC_STACK + 7], ah

    ;设置ring3 堆栈段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_STACK3
    mov word [LABEL_DESC_STACK3], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK3], al
    mov byte [LABEL_DESC_STACK3], ah

    ;设置LDT段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax,LABEL_LDT
    mov word [LABEL_DESC_LDT + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_LDT + 4], al
    mov byte [LABEL_DESC_LDT + 7], ah

    ;设置LDT中CODEA段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_CODE_A
    mov word [LABEL_LDT_DESC_CODEA + 2], ax
    shr eax, 16
    mov byte [LABEL_LDT_DESC_CODEA + 4], al
    mov byte [LABEL_LDT_DESC_CODEA + 7], ah

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

LABLE_REAL_ENTRY:
    ;从保护模式返回实模式时跳转到此处
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

    ;恢复栈顶地址
    mov sp, [SPValueInRealMode]
    
    ;关闭A20地址线
    in al, 92h
    and al, 11111101b
    out 92h, al

    ;开中断
    sti

    ;退出程序
    mov ax, 4c00h
    int 21h

[SECTION .s32]
;32位代码段
[BITS   32]
;32位代码段入口
LABEL_SEG_CODE32:
    ;使用ds来选择Data段
    mov ax, SelectorData
    mov ds, ax
    ;使用es来选择Test段
    mov ax, SelectorTest
    mov es, ax
    ;使用gs来选择显存段
    mov ax, SelectorVideo
    mov gs, ax

    ;使用ss选择全局堆栈段
    mov ax, SelectorStack
    mov ss, ax
    mov esp, TopOfStack
    
    ;显示字符串
    ;设置颜色
    mov ah,0Ch
    ;使两个寄存器归零
    xor esi, esi    
    xor edi, edi
    ;将字符串地址放入esi
    mov esi, OffsetPMMessage
    ;将显存目标地址放入edi
    mov edi, (80 * 10 + 0) * 2
    ;将方向标志位清，即向地址增加方向读取
    cld 
.1:
    lodsb               ;从esi指向的地址中读取一个字节并放入al中，同时esi += 1
    test al, al         ;判断读取的字节是否为字符串最后的'\0'，是则ZF=0
    jz  .2              ;如果ZF=0，则读取结束，转至.2处执行，否则继续这一过程
    mov [gs:edi], ax    ;将字符写入显存
    add edi, 2          ;使edi指向下一个显存地址
    jmp .1
.2:
    call DispReturn     
    
    call TestRead       
    call TestWrite
    call TestRead

    call DispReturn   

    ;加载TSS
    mov ax, SelectorTss
    ltr ax

    ;由低特权级向高特权级跳转
    push SelectorStack3
    push TopOfStack3
    push SelectorCodeRing3
    push 0
    retf
    ;使用调用门
    call SelectorCallGateTest:0


;===================================================================================
;函数名     ：  TestRead
;功能       ：  读取目标内存
;
;-----------------------------------------------------------------------------------
TestRead:
    xor esi, esi    ;初始化esi寄存器
    mov ecx, 8      ;循环8次,在这一函数中表示读取8个字节
.loop:
    mov al, [es:esi];\  读取es:esi处的数据并显示其值
    call DispAL     ;/
    inc esi         ;增加esi，使其指向下一个被读取的元素
    loop .loop      ;循环执行这一过程，直至ecx = 0
    call DispReturn
    ret
;===================================================================================


;===================================================================================
;函数名     ：  TestWrite
;功能       ：  向内存地址为5M的空间写入StrTest中的数据
;
;-----------------------------------------------------------------------------------
TestWrite:
    push esi
    push edi
    xor esi, esi    ;\  初始化esi，edi
    xor edi, edi    ;/  
    mov esi, OffsetStrTest  ;使esi指向StrTest
    cld             ;将方向标志位设置为0，即向地址增加方向读取
.1:
    lodsb           ;读取数据到al
    test al, al     ;判断是否读至字符串末尾
    jz .2           ;如果读至末尾，则此函数结束
    mov [es:edi], al;将字符串数据写入内存地址5M处
    inc edi         ;edi = edi + 1
    jmp .1          ;继续向目标地址写入字符串
.2:
    pop edi
    pop esi
    ret
;===================================================================================


;===================================================================================
;函数名     ：  DispAL
;功能       ：  将寄存器AL中的整数以16进制显示在显示器指定位置上，如'2b '
;参数       ：  
;       al  ：   数据        
;      edi  ：   目标显存偏移地址
;
;-----------------------------------------------------------------------------------
DispAL:
    push ecx    ;保存ecx的值
    push edx    ;保存edx的值

    mov ah,0Ch  ;字符颜色，黑底红字
    mov dl, al  ;备份数据到dl中
    shr al, 4   ;取高4位数据
    mov ecx, 2  ;高4位和低4位，共循环两次
.begin:
    and al, 01111b  ;清除其他位的数据，方便显示低4位
    cmp al, 9   ;比较9和al中的数
    ja  .1      ;无符号跳转，大于则跳转至.1处执行

    add al,'0'  ;计算数据的ascii值
    jmp .2       
.1:
    sub al, 0Ah ;计算数据ascii值
    add al, 'A'
.2:
    mov [gs:edi], ax ;输出数据至显存
    add edi, 2   ;使edi指向下一个数据显示的位置

    mov al, dl  ;恢复al，为显示低4位做准备
    loop .begin
    add edi, 2  ;在数据末尾加个空格

    pop edx     ;恢复edx
    pop ecx     ;回复ecx
    ret
;DispAL结束
;===================================================================================

;===================================================================================
;函数名     ：  DispReturn
;功能       ：  显示一个回车
;参数       ：         
;      edi  ：   当前输出的显存偏移地址
;
;-----------------------------------------------------------------------------------
DispReturn:
    push eax
    push ebx
    mov eax, edi;eax：被除数
    mov bl, 160 ;bl ：除数
    div bl      ;除完后得出edi指向屏幕第几行，al为商，ah为余数
    and eax, 0FFh   ;只保留商，即edi当前位于屏幕的行数
    inc eax     ;   \
    mov bl, 160 ;   |-  计算目标地址
    mul bl      ;   /
    mov edi, eax;将目标地址放入edi中
    pop ebx
    pop eax

    ret
;DispReturn结束
;===================================================================================
SegCode32Len	equ	$ - LABEL_SEG_CODE32

[SECTION .sdest]
[BITS 32]
LABEL_SEG_CODE_DEST:
    ; jmp $
    mov ax, SelectorVideo
    mov gs, ax

    mov edi, (80 * 14 + 0) * 2
    mov ah, 0Ch
    mov al, 'C'
    mov [gs:edi], ax

    ;跟GDTR不同，LDTR加载的似乎不是类似上面GdtPtr的数据结构，而是相应的Selector
    mov ax, SelectorLDT
    lldt ax

    ;跳转至LDT的CodeA段
    jmp SelectorLDTCodeA:0
    ; retf
SegCodeDestLen  equ $ - LABEL_SEG_CODE_DEST

[SECTION .ring3]
ALIGN 32
[BITS 32]
LABEL_SEG_CODE_RING3:
    mov ax, SelectorVideo
    mov gs, ax

    mov edi, (80 * 13 + 0) * 2
    mov ah, 0Ch
    mov al, '3'
    mov [gs:edi], ax

    call SelectorCallGateTest:0
    jmp $
SegCodeRing3Len equ $ - LABEL_SEG_CODE_RING3

[SECTION .s16code]
;保护模式下的16位代码段
ALIGN   32
[BITS   16]
LABEL_SEG_CODE16:
    ;初始化段描述符告诉缓冲寄存器
    mov ax, SelectorNormal  
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ;关闭保护模式
    mov eax, cr0
    and al, 11111110b
    mov cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp 0:LABLE_REAL_ENTRY
Code16Len   equ $ - LABEL_SEG_CODE16

[SECTION .ldt]
;LDT部分
ALIGN 32
LABEL_LDT:
;LDT描述符                                  段基址          段界限               属性
LABEL_LDT_DESC_CODEA:   Descriptor          0,              CodeALen - 1,       DA_C + DA_32               ;CodeA段
 
LdtLen  equ $   -   LABEL_LDT   ;LDT长度

SelectorLDTCodeA    equ LABEL_LDT_DESC_CODEA-   LABEL_LDT + SA_TIL   ;CodeA段对应的LDT Selector，SA_TIL将T1位置置1，表示LDT选择子   

[SECTION .ldt_codea]
;CodeA段（LDT，32位代码段）
ALIGN 32
[BITS 32]
LABEL_CODE_A:
    ;使用gs来选择显存段
    mov ax, SelectorVideo   
    mov gs, ax

    ;在第14行开头增加红底黑字的'L'
    mov edi, (80 * 16 + 0) * 2
    mov ah, 0Ch
    mov al, 'L'
    mov [gs:edi], ax

    ;跳转至保护模式下的16位代码段
    jmp SelectorCode16:0
CodeALen    equ $ - LABEL_CODE_A

