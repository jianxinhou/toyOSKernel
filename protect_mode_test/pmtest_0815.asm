%include    "pm.inc"
org 0100h   ; 设置为在FreeDos中运行的方式

; 跳转到程序可执行代码起始处
jmp LABEL_BEGIN

; 常量
PageDirBase0        equ         200000h     ; 页目录起始地址，  2M
PageTblBase0        equ         201000h     ; 页表开始地址，    2M+4K
PageDirBase1		equ	        220000h	    ; 页目录开始地址:	2M + 64K
PageTblBase1		equ	        221000h	    ; 页表开始地址:		2M + 64K + 4K

LinearAddrDemo      equ         00401000h   ; 在使用页表的实验中有用到
ProcFoo             equ         00401000h   ; Foo函数将移动至此处
ProcBar             equ         00501000h   ; Bar函数将移动至此处
ProcPagingDemo      equ         00301000h   ; PagingDemoProc函数将移动至此处

; GDT
[SECTION .gdt]                                      段基址          段界限               属性
LABEL_GDT:          Descriptor          0,              0,                  0                           ; 空描述符
LABEL_DESC_NORMAL:  Descriptor          0,              0ffffh,             DA_DRW                      ; Normal描述符（用于从保护模式跳转至实模式时设置段寄存器）
LABEL_DESC_CODE32:  Descriptor          0,              SegCode32Len - 1,   DA_CR | DA_32               ; 32位代码段
LABEL_DESC_CODE16:  Descriptor          0,              0ffffh,             DA_C                        ; 16位代码段
LABEL_DESC_DATA:    Descriptor          0,              DataLen - 1,        DA_DRW                      ; Data
LABEL_DESC_STACK:   Descriptor          0,              TopOfStack,         DA_DRWA + DA_32             ; Stack
LABEL_DESC_VIDEO:   Descriptor          0B8000h,        0ffffh,             DA_DRW                      ; 显存段
LABEL_DESC_FLAT_C:  Descriptor          0,              0fffffh,            DA_CR | DA_32 | DA_LIMIT_4K ; 可执行FLAT段，0~4G   
LABEL_DESC_FLAT_RW: Descriptor          0,              0fffffh,            DA_DRW | DA_LIMIT_4K        ; 可读写FLAT段，0~4G
; LABEL_DESC_PAGE_DIR:Descriptor          PageDirBase,    4095,               DA_DRW          ; 页目录段
; LABEL_DESC_PAGE_TBL:Descriptor          PageTblBase,    4096 * 8 - 1,       DA_DRW          ; 页表段
GdtLen  equ $   -   LABEL_GDT   ; GDT长度

; GdtPtr将会被加载进GDTR
GdtPtr  dw  GdtLen  -   1       ; GDT界限
        dd  0                   ; GDT基地址

; GDT Selector，负责为对应的段寄存器选择相应的GDT
SelectorNormal      equ LABEL_DESC_NORMAL   -   LABEL_GDT   ; Normal段对应的Selector
SelectorCode32      equ LABEL_DESC_CODE32   -   LABEL_GDT   ; 32位代码段对应的Selector 
SelectorCode16      equ LABEL_DESC_CODE16   -   LABEL_GDT   ; 16位代码段对应的Selector
SelectorData        equ LABEL_DESC_DATA     -   LABEL_GDT   ; Data段对应的Selector
SelectorStack       equ LABEL_DESC_STACK    -   LABEL_GDT   ; Stack段对应的Selector
SelectorVideo       equ LABEL_DESC_VIDEO    -   LABEL_GDT   ; video段对应的Selector   
SelectorFlatC       equ LABEL_DESC_FLAT_C   -   LABEL_GDT   ; 可执行FLAT段对应的Selector
SelectorFlatRW      equ LABEL_DESC_FLAT_RW  -   LABEL_GDT   ; 可读写FLAT段对应的Selector    
; SelectorPageDir     equ LABEL_DESC_PAGE_DIR -   LABEL_GDT  ; Page Directory段对应的Selector
; SelectorPageTbl     equ LABEL_DESC_PAGE_TBL -   LABEL_GDT  ; Page Tables段对应的Selector

; 程序用到的数据，数据段描述符指向这儿
[SECTION .data]
ALIGN   32
[BITS   32]
LABEL_DATA:
; 实模式下使用这些符号
; 字符串
_szPMMessage:			db	"In Protect Mode now. :p", 0Ah, 0Ah, 0	                    ; 进入保护模式后显示此字符串
_szMemChkTitle:			db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0	; 内存信息表头
_szRAMSize			    db	"RAM size:", 0                                              ; 内存大小提示信息
_szReturn			    db	0Ah, 0                                                      ; 换行字符
; 变量
_wSPValueInRealMode		dw	0                                                           ; 保存实模式下的sp
_dwMCRNumber:			dd	0	                                                        ; Memory Check Result
_dwDispPos:			    dd	(80 * 6 + 0) * 2	                                        ; 保存当前显示位置，屏幕第 6 行, 第 0 列。
_dwMemSize:			    dd	0                                                           ; Memory Size
_ARDStruct:			                                                                    ; Address Range Descriptor Structure
	_dwBaseAddrLow:		dd	0
	_dwBaseAddrHigh:	dd	0
	_dwLengthLow:		dd	0
	_dwLengthHigh:		dd	0
	_dwType:		    dd	0
_PageTableNumber:		dd	0                                                           ; 保存页表数
_MemChkBuf:	times	256	db	0                                                           ; 临时保存内存信息
; 保护模式下使用这些符号
szPMMessage		equ	_szPMMessage	- $$
szMemChkTitle	equ	_szMemChkTitle	- $$
szRAMSize		equ	_szRAMSize	- $$
szReturn		equ	_szReturn	- $$
dwDispPos		equ	_dwDispPos	- $$
dwMemSize		equ	_dwMemSize	- $$
dwMCRNumber		equ	_dwMCRNumber	- $$
ARDStruct		equ	_ARDStruct	- $$
	dwBaseAddrLow	equ	_dwBaseAddrLow	- $$
	dwBaseAddrHigh	equ	_dwBaseAddrHigh	- $$
	dwLengthLow	equ	_dwLengthLow	- $$
	dwLengthHigh	equ	_dwLengthHigh	- $$
	dwType		equ	_dwType		- $$
PageTableNumber		equ	_PageTableNumber- $$
MemChkBuf		equ	_MemChkBuf	- $$
DataLen			equ	$ - LABEL_DATA

; 全局堆栈段，堆栈段描述符指向这
[SECTION .globalstack]
ALIGN   32
[BITS   32]
LABEL_STACK:
    times   512     db  0                   ;共512字节
TopOfStack  equ     $ - LABEL_STACK - 1     ;栈顶=511 

; 实模式下的16位代码段
[SECTION .s16]
[BITS   16]
; 程序可执行代码起始处
LABEL_BEGIN:
    ; 初始化段寄存器和堆栈寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    ; 将LABEL_GO_BACK_TO_REAL处改为jmp 实模式下的cs:LABLE_REAL_ENTRY
    mov [LABEL_GO_BACK_TO_REAL + 3], ax
    ; 保存当前栈顶地址
    mov [_wSPValueInRealMode], sp

    ; 读取内存信息
    mov ebx, 0                              ; 初始化ebx
    mov di, _MemChkBuf                      ; 将存储内存信息的内存地址保存到di中

.loop:
    ; 为int 15h做准备
    mov eax, 0E820h                         ; eax保存0E820h表示获取内存信息
    mov ecx, 20                             ; 填充字节数
    mov edx, 0534D4150h                     ; 'SMAP'
    int 15h                                 ; 0x15号中断，一次中断获取一段内存信息，获取最后一段内存信息后，ebx会为0，且CF没进位
    jc LABEL_MEM_CHK_FAIL                   ; 如果CF=0表示内存信息读取错误
    add di, 20                              ; 下一段内存信息保存的内存地址
    inc dword [_dwMCRNumber]                ; 表示又多获取了一段内存信息
    cmp ebx, 0                              ; 判断内存信息是否读取完成
    jne .loop                               ; 未完成则继续读取
    jmp LABEL_MEM_CHK_OK                    ; 读取完成则程序继续

LABEL_MEM_CHK_FAIL:
    mov dword [_dwMCRNumber], 0             ; 将读取内存信息段数置0

LABEL_MEM_CHK_OK:
    ; 设置32位代码段的段基址
    ; 取出当前段基址
    xor eax, eax
    mov ax, cs
    shl eax, 4
    ; 计算32位代码段基址
    add eax, LABEL_SEG_CODE32
    ; 将计算得到的段基址别赋值给LABEL_SEG_CODE32对应Descriptor中段基址的相应字节
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ; 设置保护模式下16位代码段的段基址
    mov ax, cs
    movzx eax, ax
    shl eax, 4
    add eax, LABEL_SEG_CODE16
    mov word [LABEL_DESC_CODE16 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16 + 4], al
    mov byte [LABEL_DESC_CODE16 + 7], ah

    ; 设置数据段段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
    mov word [LABEL_DESC_DATA + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA + 4], al
    mov byte [LABEL_DESC_DATA + 7], ah

    ; 设置堆栈段段基址
    xor eax, eax
    mov ax, dx
    shl eax, 4
    add eax, LABEL_STACK
    mov word [LABEL_DESC_STACK + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK + 4], al
    mov byte [LABEL_DESC_STACK + 7], ah

    ; 为加载GDT寄存器做准备
    ; 取出当前数据段基址
    xor eax, eax
    mov ax, ds
    shl eax, 4
    ; 计算GDT的起始地址
    add eax, LABEL_GDT
    ; 将这一地址赋值给GdtPtr的后4字节
    mov dword [GdtPtr + 2], eax

    ; 将GdtPtr加载至GDT寄存器
    lgdt    [GdtPtr]

    ; 关中断
    cli

    ; 打开A20地址线
    in  al, 92h
    or  al, 00000010b
    out 92h, al

    ; 将cr0寄存器中第0位置1，即保护模式的开关
    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    ; 跳转至32位代码段，正式进入保护模式
    jmp SelectorCode32:dword 0  ; 此句被编译为32位代码。不加dword的话，则会被编译为16位代码，即若“：”后大于0xffff，高位部分会被截断

LABLE_REAL_ENTRY:
    ; 从保护模式返回实模式时跳转到此处
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; 恢复栈顶地址
    mov sp, [_wSPValueInRealMode]
    
    ; 关闭A20地址线
    in al, 92h
    and al, 11111101b
    out 92h, al

    ; 开中断
    sti

    ; 退出程序
    mov ax, 4c00h
    int 21h

[SECTION .s32]
; 32位代码段
[BITS   32]
; 32位代码段入口
LABEL_SEG_CODE32:
    ; 使用ds来选择Data段
    mov ax, SelectorData
    mov ds, ax
    mov ax, SelectorData
    mov es, ax

    ; 使用gs来选择显存段
    mov ax, SelectorVideo
    mov gs, ax

    ; 使用ss选择全局堆栈段
    mov ax, SelectorStack
    mov ss, ax
    mov esp, TopOfStack
    
    ; 显示字符串
    push szPMMessage
    call DispStr
    add esp, 4

    ; 显示内存信息title
    push szMemChkTitle
    call DispStr
    add esp, 4
    
    ; 显示内存信息
    call DispMemSize

    ; 演示改变页目录的效果
    call PagingDemo		

    jmp SelectorCode16:0


;===================================================================================
; 函数名     ：  SetupPaging
; 功能       ：  版本一，启动分页机制，按顺序连续映射0~4G内存，寻址使用PageDir和PageTbl段
;-----------------------------------------------------------------------------------
; SetupPaging:
;     ; 用es选择页目录段
;     mov ax, SelectorPageDir   
;     mov es, ax
;
;     ; 初始化页目录表
;     mov ecx, 1024
;     xor edi, edi
;     xor eax, eax
;     mov eax, PageTblBase | PG_P | PG_USU | PG_RWW
; .1:
;     stosd
;     add eax, 4096
;     loop .1
; 
;     ; 初始化页表
;     mov ax, SelectorPageTbl
;     mov es, ax
;     mov ecx, 1024 * 1024
;     xor edi, edi
;     xor eax, eax
;     mov eax, PG_P | PG_USU | PG_RWW

; .2:
;     stosd
;     add eax, 4096
;     loop .2
; 
;     ; 加载页目录表
;     mov eax, PageDirBase
;     mov cr3, eax
;      
;     ; 启动分页机制
;     mov eax, cr0
;     or eax, 80000000h
;     mov cr0, eax
;     jmp short .3

; .3:
    
;     ret
; SetupPaging结束
;===================================================================================

;===================================================================================
; 函数名     ：  SetupPaging
; 功能       ：  版本二，启动分页机制，根据机器实际内存计算页表数，
;               按顺序连续映射内存，使用栈保存页目录数，寻址使用PageDir和PageTbl段
;-----------------------------------------------------------------------------------
; 为开启分页功能做一些准备
; SetupPaging:
;     xor edx, edx                ; 归零edx
;     mov eax, [dwMemSize]        ; [dwMemSize]保存了内存大小
;     mov ebx, 400000h            ; 一个页目录项可以表示4M内存：4K * 1K个页表项
;     div ebx                     ; 计算有多少页目录项
;     mov ecx, eax                ; eax为商，保存需要多少页目录项
;     test edx, edx               ; 判断余数是否为0，即判断是否需要多一个页目录项表示
;     jz .no_remainder            
;     inc ecx                     ; 页目录项数增加1
; .no_remainder:
;     push ecx
;     mov ax, SelectorPageDir     ; 将页目录项基址放入es
;     mov es, ax
;     xor edi, edi                ; 归零edi
;     xor eax, eax                ; 归零eax
;     mov eax, PageTblBase | PG_P | PG_USU |PG_RWW    ; 初始化第一个页目录项
; .1:                             
;     stosd
;     add eax, 4096
;     loop .1                     ; 共初始化ecx个页目录项

;     mov ax, SelectorPageTbl     ; 将页表基址放入es
;     mov es, ax
;     pop eax                     ; eax <-- 页目录项数
;     mov ebx, 1024
;     mul ebx                     ; edx:eax = eax * ebx = 页表数，且edx必为0
;     mov ecx, eax                ; ecx保存页表数 
;     xor edi, edi                ; 归零edi
;     xor eax, eax                ; 归零eax
;     mov eax, PG_P | PG_USU | PG_RWW ; 初始化第一个页表项
; .2:
;     stosd                       
;     add eax, 4096
;     loop .2                     ; 共初始化ecx个页表项    
; 
;     ; 加载页目录表
;     mov eax, PageDirBase        ; 将页目录基址放入eax
;     mov cr3, eax                 
; 
;     ; 启动分页机制
;     mov eax, cr0
;     or eax, 80000000h
;     mov cr0, eax
;     jmp short .3
; .3:
;     nop
;     ret
; SetupPaging结束
;===================================================================================

;===================================================================================
; 函数名     ：  SetupPaging
; 功能       ：  版本三，启动分页机制，根据机器实际内存计算页目录数
;               按顺序连续映射内存，使用对应内存保存页目录数，寻址使用Flat段
;-----------------------------------------------------------------------------------
; 为开启分页功能做一些准备
SetupPaging:
    xor edx, edx                ; 归零edx
    mov eax, [dwMemSize]        ; [dwMemSize]保存了内存大小
    mov ebx, 400000h            ; 一个页目录项可以表示4M内存：4K * 1K个页表项
    div ebx                     ; 计算有多少页目录项
    mov ecx, eax                ; eax为商，保存需要多少页目录项
    test edx, edx               ; 判断余数是否为0，即判断是否需要多一个页目录项表示
    jz .no_remainder            
    inc ecx                     ; 页目录数增加1
.no_remainder:
    mov [PageTableNumber], ecx  ; 保存页目录数
    mov ax, SelectorFlatRW      ; 选择Flat段
    mov es, ax
    mov edi, PageDirBase0       ; 保存0号页表的页目录地址
    xor eax, eax                ; 归零eax
    mov eax, PageTblBase0 | PG_P | PG_USU | PG_RWW  ; 初始化第一个页目录项
.1:                             
    stosd
    add eax, 4096
    loop .1                     ; 共初始化ecx个页目录项

    mov eax, [PageTableNumber]  ; 页目录数
    mov ebx, 1024
    mul ebx                     ; edx:eax = eax * ebx = 页表数，且edx必为0
    mov ecx, eax                ; ecx保存页表数 
    mov edi, PageTblBase0       ; 保存0号页表的页表地址
    xor eax, eax                ; 归零eax
    mov eax, PG_P | PG_USU | PG_RWW ; 初始化第一个页表项
.2:
    stosd                       
    add eax, 4096
    loop .2                     ; 共初始化ecx个页表项    

    ; 加载页目录表
    mov eax, PageDirBase0       ; 将页目录基址放入eax
    mov cr3, eax

    ; 启动分页机制                
    mov eax, cr0
    or eax, 80000000h
    mov cr0, eax
    jmp short .3
.3:
    nop
    ret
; SetupPaging结束
;===================================================================================


;===================================================================================
; 函数名     ：  PagingDemo
; 功能       ：  功能集成函数
;
;-----------------------------------------------------------------------------------
PagingDemo:
    ; 用es选择Flat段
    mov ax, cs
    mov ds, ax
    mov ax, SelectorFlatRW
    mov es, ax

    ; 将Foo函数拷贝至00401000h处
    push LenFoo
    push OffsetFoo
    push ProcFoo
    call MemCpy
    add esp, 12

    ; 将Bar函数拷贝至00401000h处
    push LenBar
    push OffsetBar
    push ProcBar
    call MemCpy
    add esp, 12

    ; 将PagingDemoProc函数拷贝至00301000h处
    push LenPagingDemoAll
    push OffsetPagingDemoProc
    push ProcPagingDemo
    call MemCpy
    add esp, 12

    ; 使用es和ds选择数据段
    mov ax, SelectorData
    mov ds, ax
    mov es, ax

    ; 初始化0号页表
    call SetupPaging
    ; 切换页表前调用00301000h处的函数，应该显示Foo
    call SelectorFlatC:ProcPagingDemo
    ; 此函数意义在函数相应位置有解释
    call PSwitch
    ; 切换页表后调用00301000h处的函数，应该显示Bar
    call SelectorFlatC:ProcPagingDemo

    ret
; PagingDemo结束
;===================================================================================

;===================================================================================
; 函数名     ：  PSwitch
; 功能       ：  书中版本
;               初始化1号页表，并将00401000h对应的页表项地址改成00501000h，并切换至1号页表
;-----------------------------------------------------------------------------------
; PSwitch:
;     mov ax, SelectorFlatRW      ; 用es选择Flat段
;     mov es, ax
;     ; 初始化1号页表
;     mov edi, PageDirBase1       ; 取1号页表页目录的地址
;     xor eax, eax                ; 归零eax
;     mov eax, PageTblBase1 | PG_P | PG_USU | PG_RWW  ; 初始化第一个页目录项
;     mov ecx, [PageTableNumber]  ; 将页目录项数放入ecx
; .1:
;     stosd
;     add eax, 4096
;     loop .1                     

;     mov eax, [PageTableNumber]  
;     mov ebx, 1024
;     mul ebx
;     mov ecx, eax
;     mov edi, PageTblBase1
;     xor eax, eax
;     mov eax, PG_P | PG_USU | PG_RWW ; 初始化第一个页表项
; .2:
;     stosd
;     add eax, 4096
;     loop .2

;     ; 计算0401000这一地址对应哪个页表项
;     mov eax, LinearAddrDemo     ;  
;     shr eax, 22                 ; 计算此地址对应页目录项第一个页表的首地址偏移
;     mov ebx, 4096               ; Offset = (0x401000 >> 22) * 0x1000
;     mul ebx                     ; 
;     mov ecx, eax                ; 暂存Offset 
;     mov eax, LinearAddrDemo     ; 计算此地址对应页目录对应的页表项偏移地址
;     shr eax, 12                 ; 
;     and eax, 03FFh              ; InnerPageTblOffset = [(0x401000 >> 12) and 0x3FF] * 4
;     mov ebx, 4                  ; 
;     mul ebx                     ; 
;     add eax, ecx                ; 目标页表项偏移地址 = Offset + InnerPageTblOffset
;     add eax, PageTblBase1       ; 目标页表项地址 = 1号页表基址 + 目标页表项偏移地址
;     mov dword [es:eax], ProcBar | PG_P | PG_USU | PG_RWW    ; 修改页表项

;     mov eax, PageDirBase1       ; 加载页目录表
;     mov cr3, eax
;     jmp short .3

; .3:
;     nop
;     ret
;===================================================================================

;===================================================================================
; 函数名     ：  PSwitch
; 功能       ：  我做试验的版本 
;               不生成1号页表，直接更新0号页表，并将00401000h对应的页表项地址改成00501000h
;-----------------------------------------------------------------------------------
PSwitch:
    ; 同上面版本一样更新对应页表项
    mov ax, SelectorFlatRW
    mov es, ax

    mov eax, LinearAddrDemo
    shr eax, 22
    mov ebx, 4096
    mul ebx
    mov ecx, eax
    mov eax, LinearAddrDemo
    shr eax, 12
    and eax, 03FFh
    mov ebx, 4
    mul ebx
    add eax, ecx
    add eax, PageTblBase0
    mov dword [es:eax], ProcBar | PG_P | PG_USU | PG_RWW

    ; 这个页目录地址一定要重新添加至CR3，否则会导致寻址失败
    ; 说明页表会被移至寄存器中
    mov eax, PageDirBase0
    mov cr3, eax
    jmp short .3

.3:
    nop
    ret
;===================================================================================

;===================================================================================
; 函数名     ：  PagingDemoProc
; 功能       ：  调用0x401000处的程序
;-----------------------------------------------------------------------------------
PagingDemoProc:
OffsetPagingDemoProc    equ $ - $$
    mov eax, LinearAddrDemo
    call eax
    retf
LenPagingDemoAll        equ $ - PagingDemoProc
;===================================================================================

;===================================================================================
; 函数名     ：  foo
; 功能       ：  在第17行开头处输出红色Foo
;-----------------------------------------------------------------------------------
foo:
OffsetFoo               equ $ - $$
    mov ah, 0Ch
    mov al, 'F'
    mov [gs:((80 * 17 + 0) * 2)], ax
    mov al, 'o'
    mov [gs:((80 * 17 + 1) * 2)], ax
    mov [gs:((80 * 17 + 2) * 2)], ax
    ret
LenFoo                  equ $ - foo
;===================================================================================

;===================================================================================
; 函数名     ：  bar
; 功能       ：  在第18行开头处输出红色bar
;-----------------------------------------------------------------------------------
bar:
OffsetBar               equ $ - $$
    mov ah, 0Ch
    mov al, 'B'
    mov [gs:((80 * 18 + 0) * 2)], ax
    mov al, 'a'
    mov [gs:((80 * 18 + 1) * 2)], ax
    mov al, 'r'
    mov [gs:((80 * 18 + 2) * 2)], ax
    ret
LenBar                  equ $ - bar
;===================================================================================

;===================================================================================
; 函数名     ：  DispMemSize
; 功能       ：  显示内存信息
;
;-----------------------------------------------------------------------------------
DispMemSize:
;-----------------------------------------------------------------------------------
; 保存寄存器的值
    push esi
    push edi
    push ecx
;-----------------------------------------------------------------------------------
; 下面用C语言解释这段代码
    mov esi, MemChkBuf              ; 将保存内存信息的内存首地址放入esi 
    mov ecx, [dwMCRNumber]          ; for (int i = 0 ; i < [dwMCRNumber] ; i++){
.loop:
    mov edx, 5                      ;   for (int j = 0 ; j < 5 ; j++){
    mov edi, ARDStruct              ;       
.1:
    push dword [esi]                ;       55
    call DispInt                    ;       DispInt(MemChkBuf[j * 4]);
    pop eax                         ; 
    stosd                           ;       ARDStruct[j * 4] = MemChkBuf[j * 4];
    add esi, 4                      ;   
    dec edx                         ;                     
    cmp edx, 0                      ;
    jnz .1                          ;   }
    call DispReturn                 ;   printf("\n");
    cmp dword [dwType], 1           ;   if ([dwType] == AddressRangeMemory){
    jne .2                          ;           
    mov eax, [dwBaseAddrLow]        ;
    add eax, [dwLengthLow]          ;       
    cmp eax, [dwMemSize]            ;       if(BaseAddrLow + LengthLow > [dwMemSize])
    jb .2                           ;
    mov [dwMemSize], eax            ;           [dwMemSize] = BaseAddrLow + LengthLow
.2:                                 ;   }
    loop .loop                      ; }
    call DispReturn                 ; printf("\n")
    push szRAMSize                  ;
    call DispStr                    ; DispStr(szRAMSize)

    add esp, 4                      ;
    
    push dword [dwMemSize]          ;
    call DispInt                    ; DispInt(dwMemSize)
    add esp, 4                      ;
;-----------------------------------------------------------------------------------
; 恢复寄存器的值
    pop ecx
    pop edi
    pop esi
    ret
;===================================================================================

%include	"lib.inc"	; 库函数

SegCode32Len	equ	$ - LABEL_SEG_CODE32

[SECTION .s16code]
; 保护模式下的16位代码段
ALIGN   32
[BITS   16]
LABEL_SEG_CODE16:
    ; 初始化段描述符告诉缓冲寄存器
    mov ax, SelectorNormal  
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; 关闭保护模式
    mov eax, cr0
    and	eax, 7FFFFFFEh		; PE=0, PG=0
    mov cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp 0:LABLE_REAL_ENTRY
Code16Len   equ $ - LABEL_SEG_CODE16