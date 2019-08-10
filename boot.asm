;===================================================================================
;  boot.asm：将loader.bin装入内存并执行
;===================================================================================
; 将此行打开后可用 nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试
; %define	_BOOT_DEBUG_            ; 做 Boot Sector 时一定将此行注释掉!

%ifdef	_BOOT_DEBUG_
	org  0100h	                ; 调试状态, 做成 .COM 文件, 可调试
%else
	org  07c00h	                ; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif

;===================================================================================
; 这些宏定义我本来不想写死，想定义成内存变量，并用程序进行计算
; 但是实现后发现这样会导致引导扇区大于512B，无奈只能像书中一样写死

StartSecNoOfRootDir     equ     19      ; 根目录的起始扇区
StartSecNoOfData        equ     33      ; 数据区的起始扇区号
RootDirSecNum           equ     14      ; 根目录占用的扇区数 
RootDirNumInOneSec      equ     16      ; 一个扇区能够容纳的根目录项数
SecNoOfFAT1             equ     1       ; FAT1的第一个扇区号
RootDirItemSize         equ     0020h   ; 根目录下文件目录项大小

;-----------------------------------------------------------------------------------
;一些必要的常量

%ifdef	_BOOT_DEBUG_
BaseOfStack		equ	0100h	; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
BaseOfStack		equ	07c00h	; 堆栈基地址(栈底, 从这个位置向低地址生长)
%endif
BaseOfLoader		equ	09000h  ; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0100h   ; LOADER.BIN 被加载到的位置 ---- 偏移地址

;===================================================================================
; 程序入口

        jmp short LABEL_START                           ; 跳转至可执行代码处
        nop

;-----------------------------------------------------------------------------------
; FAT12的头

        BS_OEMName              DB      'JanXnHou'      ; OEMString，8字节
        BPB_BytesPerSec         DW      512             ; 每扇区字节数
        BPB_SecPerClus          DB      1               ; 每簇扇区数
        BPB_RsvdSecCnt          DW      1               ; Boot记录占用多少个扇区
        BPB_NumFATs             DB      2               ; 共有多少个FAT表 =
        BPB_RootEntCnt          DW      224             ; 根目录文件数最大值
        BPB_TotSec16            DW      2880            ; 逻辑扇区总数
        BPB_Media               DB      0xF0            ; 媒体描述符
        BPB_FATSz16             DW      9               ; 每FAT扇区数  =
        BPB_SecPerTrk           DW      18              ; 每磁道扇区数
        BPB_NumHeads            DW      2               ; 磁头数（面数）
        BPB_HiddSec             DD      0               ; 隐藏扇区数
        BPB_TotSec32            DD      0               ; 没整明白
        BS_DrvNum               DB      0               ; 中断 13 的驱动器号
        BS_Reserved1            DB      0               ; 未使用
        BS_BootSig              DB      29h             ; 扩展引导标记
        BS_VolID                DD      0               ; 卷序列号
        BS_VolLab               DB      '   OS 27   '   ; 卷标，11字节
        BS_FileSysType          DB      'FAT12   '      ; 文件系统类型，8字节

;===================================================================================
; 可执行代码部分

;-----------------------------------------------------------------------------------
; 清屏，初始化寄存器，软驱和其他数据

LABEL_START:
        ; 初始化寄存器
        mov ax, cs
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, BaseOfStack
        
        ; 软驱复位
        xor ah, ah
        mov dl, byte [BS_DrvNum]
        int 13h

        ; 清屏
        mov ax, 0600h
        mov bx, 0700h
        mov cx, 0
        mov dx, 0184fh
        int 10h
        
        ; 显示启动提示信息
        mov dh, 0
        call DispStr
        
        ; 初始化第一个加载的扇区号
        mov word [wSecNo], StartSecNoOfRootDir

;-----------------------------------------------------------------------------------
; 遍历所有根目录扇区，将每个扇区加载进内存，寻找文件名为LOADER.BIN的条目
 
LABEL_SEARCH_IN_ROOT_DIR:
        ; 按顺序加载根目录扇区至内存
        cmp word [wRootDirSecNumForLoop], 0     ; 判断根目录扇区是否全部被读取
        jz LABEL_LOADER_NOT_FOUND               ; 全部被读取则说明软盘中没有LOADER.BIN
        dec word [wRootDirSecNumForLoop]        ; 控制迭代

        ; 读取1个根目录扇区
        mov ax, BaseOfLoader
        mov es, ax
        mov bx, OffsetOfLoader
        mov ax, word [wSecNo]
        mov cl, 1
        call ReadSector                         ; 将被读取的扇区加载至es:bx处
        inc word [wSecNo]                       ; 准备加载的下一个扇区号

        ; 遍历此扇区中所有的根目录条目，判断是否有LOADER.BIN
        mov si, LoaderFileName                  ; 指向目标文件名(LOADER.BIN)
        mov di, OffsetOfLoader                  ; 指向此扇区第一个文件条目
        cld
        xor dx, dx                              
        mov dx, RootDirNumInOneSec              ; dx控制此扇区中的文件条目是否都被访问，
                                                ; 每扇区（512B）可以容纳16个文件条目(32B)
LABEL_SEARCH_FOR_LOADERBIN:
        ; 按顺序判断文件名和目标文件名是否一致
        cmp dx, 0                               ; 判断此扇区文件条目是否都被访问
        jz LABEL_SEARCH_IN_ROOT_DIR             ; 若都被访问过，则加载下一个扇区
        dec dx                                  ; 控制迭代

        ; 判断条目文件名和目标文件名（LOADER.BIN）是否相同
        xor ecx, ecx
        mov cx, LoaderFileNameLength            
LABEL_CMP_FILENAME:
        ; 按顺序判断文件名字符是否与目标文件名一致
        cmp cx, 0                               ; 判断是否比对至文件名最后一个字符
        jz LABEL_LOADER_FOUND                   ; 是则表示找到目标文件
        dec cx                                  ; 控制迭代

        lodsb                                   ; 将条目中文件名字符按顺序加载进ax
        cmp al, byte [es:di]                    ; 判断此文件条目中文件名的单个字符与目标文件名是否享同
        jnz LABEL_NEXT_ROOT_DIR                 ; 不相同则证明此文件并非目标文件，因此继续比对下一个条目
        inc di                                  ; 使di指向下一个字符
        jmp LABEL_CMP_FILENAME                  ; 运行到这里表示当前字符与目标文件名相应字符相同，继续比对下一个字符

LABEL_NEXT_ROOT_DIR:
        and di, 0FFE0h                          ;\使di指向下一个条目文件名开头处 
        add di, RootDirItemSize                 ;/
        mov si, LoaderFileName                  ; 使si指向目标文件名开头处
        jmp LABEL_SEARCH_FOR_LOADERBIN
                 
LABEL_LOADER_NOT_FOUND:
        ; 未找到LOADER.BIN，则跳转至此处
        mov dh, 2
        call DispStr                            ; 显示未找到loader的信息
%ifdef	_BOOT_DEBUG_
	mov ax, 4c00h
        int 21h
%else
	jmp $                   
%endif

;-----------------------------------------------------------------------------------
; 当根目录中包含文件名为loader.bin的条目，则继续加载loader至内存

LABEL_LOADER_FOUND:
        ; 找到LOADER.BIN，跳转到此处 
        and di, 0FFE0h                          ; 计算文件条目起始地址
        add di, 1Ah                             ; 偏移0x1a处保存文件内容数据第一簇的对应FAT值
        mov cx, [es:di]                         
        push cx                                 ; 保存这一FAT值
        
        add cx, StartSecNoOfData                ;\计算文件内容第一簇的扇区号
        sub cx, 2                               ;/

        mov ax, BaseOfLoader                    ;\                   
        mov es, ax                              ;| es:bx指向loader所在内存区域
        mov bx, OffsetOfLoader                  ;/
        mov ax, cx                              

LABEL_GOON_LOADING_FILE:
        ; 挨个扇区读取文件内容
        push bx                                 ;\
                                                ;|这里必须空一行，否则nasm编译后总是少一条压栈语句，不知道为什么，我真是无奈
        push ax                                 ;|
        mov ah, 0Eh                             ;|
        mov al, '.'                             ;|显示Booting 后的'.'，每读一个扇区则显示一个'.'
        mov bl, 0Fh                             ;|
        int 10h                                 ;|
        pop ax                                  ;|
        pop bx                                  ;/

        mov cl, 1                               ; ReadSector的参数，表示读取多少个扇区
        call ReadSector                         ; 读取文件内容扇区
        pop ax                                  ; 取出保存的FAT值
        call GetFATEntry                        ; 根据当前簇的FAT值计算文件下一簇的FAT值
        cmp ax, 0FFFh                           ; 判断当前扇区是否为文件最后一个扇区
        jz LABEL_FILE_LOADED                    ; 是则准备跳转至Loader，否则继续
        push ax                                 ; 保存这一FAT值
        add ax, StartSecNoOfData                ;\计算文件下一簇的扇区号
        sub ax, 2                               ;/
        add bx, [BPB_BytesPerSec]               ; 计算文件内容下一簇装入的的地址
        jmp LABEL_GOON_LOADING_FILE

;-----------------------------------------------------------------------------------
; LOADER.BIN已经加载完毕，这部分代码将跳转至Loader

LABEL_FILE_LOADED:
        ; 显示提示信息，表示loader已加载完毕
        mov dh, 1
        call DispStr
;--------------------------------------------------
; 至此，启动扇区的工作全部完成，正式跳转至Loader  
        jmp BaseOfLoader:OffsetOfLoader                 
;--------------------------------------------------

;===================================================================================

;===================================================================================
; 这部分保存程序需要用到的变量，字符串
; 变量   
wSecNo		        dw	0		; 要读取的扇区号
wRootDirSecNumForLoop	dw	RootDirSecNum   ; Root Directory 占用的扇区数，
						; 在循环中会递减至零.
bOdd			db	0		; 奇数还是偶数

; 字符串
LoaderFileNameLength    equ     11 
LoaderFileName		db	"LOADER  BIN", 0; LOADER.BIN 之文件名

; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	9
BootMessage:		db	"Booting  "     ; 9字节, 不够则用空格补齐. 序号 0
Message1:		db	"Ready.   "     ; 9字节, 不够则用空格补齐. 序号 1
Message2:		db	"No Loader"     ; 9字节, 不够则用空格补齐. 序号 2

;===================================================================================

;===================================================================================
; 函数名     ：  DispStr
; 功能       ：  显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
;                                        ，也代表输出到屏幕的行号
;-----------------------------------------------------------------------------------
DispStr:
;-----------------------------------------------------------------------------------
        mov ax, MessageLength   ;\ 
        mul dh                  ;|
        add ax, BootMessage     ;|es:bp--串地址
        mov bp, ax              ;|
        mov ax, ds              ;|
        mov es, ax              ;/
        mov cx, MessageLength   ; 串长度
        mov ax, 01301h          ; 10h号中断的参数
        mov bx, 0007h           ; 第00页（bh = 00）,黑底白字（bl = 07h）
        mov dl, 0               ; 列号，第00列（dl = 00），第dh行
        int 10h
        
        ret
;===================================================================================

;===================================================================================
; 函数名     ：  ReadSector
; 功能       ：  读取软盘扇区到目标地址处
; 参数       ：  
;       ax  ：  目标扇区号
;       cl  ：  读取扇区数
;    es:bx  ：  目标缓冲区
;-----------------------------------------------------------------------------------
ReadSector:
;-----------------------------------------------------------------------------------
; 保存需要用到的寄存器的值
        push cx
        push dx
        push bp
;-----------------------------------------------------------------------------------
; 开辟出一块内存区域，保存读取扇区数
        mov bp, sp
        sub sp, 2
        mov byte [bp - 2], cl
;-----------------------------------------------------------------------------------
; 计算起始扇区号，柱面号，磁头号
; 起始扇区号 = 目标扇区号 mod 每磁道扇区数
; 磁道号 = (目标扇区号 / 每磁道扇区数) >> 1
; 磁头号 = (目标扇区号 / 每磁道扇区数) and 0x1
        mov dl, [BPB_SecPerTrk] ; dl保存每磁道扇区数
        div dl                  ; 做除法后al保存商，ah保存起始扇区号        
;-----------------------------------------------------------------------------------
; 将起始扇区号移至cl
        inc ah                  ; 起始扇区号从1开始，而非从0开始
        mov cl, ah              ; 起始扇区号      
;-----------------------------------------------------------------------------------  
; 计算磁头号
        mov dh, al
        and dh, 0x1             ; 磁头号
;----------------------------------------------------------------------------------- 
; 计算磁道号        
        mov ch, al
        shr ch, 1               ; 磁道号
;----------------------------------------------------------------------------------- 
        mov dl, [BS_DrvNum]     ; 驱动器号
;----------------------------------------------------------------------------------- 
; 读取软盘
.GoOnReading:
        mov al, byte [bp - 2]   ; 读取扇区号
        mov ah, 02h             ; 标志读取扇区
        int 13h
        jc .GoOnReading         ; 读取失败时CF会置1，因此要循环读取
;-----------------------------------------------------------------------------------
;恢复保存的寄存器        
        add esp, 2
        pop bp
        pop dx
        pop cx

        ret
;===================================================================================

;===================================================================================
; 函数名     ：  GetFATEntry
; 功能       ：  由数据区扇区号找到FAT项的值
; 参数       ：  
;       ax  ：  扇区号
; 返回值     ：
;       ax  :   FAT值
;-----------------------------------------------------------------------------------
GetFATEntry:
;-----------------------------------------------------------------------------------
;保存将要用到的寄存器
        push es
        push bx
        push ax

;-----------------------------------------------------------------------------------
;开辟一块区域用于保存FAT表，此区域起始地址为0x8900:0
        mov ax, BaseOfLoader    
        sub ax, 0100h
        mov es, ax
;-----------------------------------------------------------------------------------
;计算目标FAT值所处的FAT表偏移地址，ax * 3 / 2是因为3个字节保存2个FAT值
        pop ax
        mov byte [bOdd], 0
        mov bx, 3
        mul bx
        mov bx, 2
        div bx                  ; ax即为FAT表偏移地址
                                ; dx的奇偶表示FAT值在三个字节中的相对位置                  
;-----------------------------------------------------------------------------------
; 判断目标扇区号的奇偶，并做标记，保存于[bOdd]中
        cmp dx, 0
        jz LABEL_EVEN
        mov byte [bOdd], 1
LABEL_EVEN:
;-----------------------------------------------------------------------------------
; 计算FAT项所在的扇区号和在扇区内的偏移地址，并加载相应扇区至内存
        xor dx, dx
        mov bx, [BPB_BytesPerSec]
        div bx                  

        push dx                 ; dx保存FAT项在扇区内的偏移地址
        mov bx,0
        add ax, SecNoOfFAT1     ; ax保存FAT想所在扇区号
        mov cl, 2               ; 连续加载两个扇区，防止某个FAT项只有一半
        call ReadSector
;-----------------------------------------------------------------------------------
; 取出FAT项的值并根据扇区号的奇偶对其进行处理
; 两个字节包含一个完整FAT项的值，偶数项取前两个字节，奇数项取后两个字节
; 我一开始认为FAT项应该这么看：
;    Low  0  1  2  3  4  5  6  7  High
; byte1: [0][1][2][3][4][5][6][7]
; byte2: [8][9][a][b][0][1][2][3] 
; byte3: [4][5][6][7][8][9][a][b]
; FATEntry1（偶）: byte1[0到7] 和 byte2[0到3]
; FATEntry2（奇）: byte2[4到7] 和 byte3[0到7]
; 这样表示数据确实没有错，但是计算机中右移是将数据从高位移至低位，
; 这样看容易让自己误解右移的方向是由低位到高位
; 因此我当时认为应该是偶数FAT项右移4位，奇数FAT项保留低12位
; 后来发现，这样看FAT项，更符合计算机存储数据的方式
;   High  7  6  5  4  3  2  1  0  Low
; byte1: [7][6][5][4][3][2][1][0]
; byte2: [3][2][1][0][b][a][9][8] 
; byte3: [b][a][9][8][7][6][5][4]
; FATEntry1（偶）: byte1[0到7] 和 byte2[0到3]
; FATEntry2（奇）: byte2[4到7] 和 byte3[0到7]
; 根据小端法：
; 偶数FAT项需要读取前两个字节并取后12位
; 奇数FAT项读取后两个字节并右移四位
        pop dx
        add bx, dx
        mov ax, [es:bx]
        cmp byte [bOdd], 1      
        jnz LABEL_EVEN2
        shr ax, 4
LABEL_EVEN2:
        and ax, 0FFFh
LABEL_GET_FAT_ENTRY_OK:
        pop bx
        pop es

        ret
;===================================================================================

;===================================================================================
;补足不到512字节的部分
times   510 - ($ - $$)            db      0
DW      0xaa55
;===================================================================================

        
        
