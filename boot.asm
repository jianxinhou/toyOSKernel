
;%define	_BOOT_DEBUG_	; 做 Boot Sector 时一定将此行注释掉!将此行打开后可用 nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试

%ifdef	_BOOT_DEBUG_
	org  0100h			; 调试状态, 做成 .COM 文件, 可调试
%else
	org  07c00h			; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif

;================================================================================================
%ifdef	_BOOT_DEBUG_
BaseOfStack		equ	0100h	; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
BaseOfStack		equ	07c00h	; 堆栈基地址(栈底, 从这个位置向低地址生长)
%endif

BaseOfLoader		equ	09000h	; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0100h	; LOADER.BIN 被加载到的位置 ---- 偏移地址
;================================================================================================

        jmp short LABEL_START   ;跳转至可执行代码处
        nop

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
BaseOfStack           equ       07c00h
DATA:
LoaderNotFound         db        "loader not found"

LABEL_START:
        mov ax, cs
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, BaseOfStack

        ;软驱复位
        xor ah, ah
        mov dl, byte [BS_DrvNum]
        int 13h

        ;计算根目录起始地址，保存在 SectorNoOfRootDirectory 中
        mov ax, word [BPB_FATSz16]
        test ah, ah
        jz .GoOnCalcSectorNo     ;如果BPB_FATSz16大于255，则终止程序
        jmp $
.GoOnCalcSectorNo:        
        mov dl, byte [BPB_NumFATs]
        mul dl
        add ax, word [BPB_RsvdSecCnt]
        mov word [SectorNoOfRootDirectory], ax

        ;计算根目录所占扇区数
        mov ax, [BPB_RootEntCnt]
        mov dx, 32
        mul dx
        mov cx, [BPB_BytesPerSec]
        div cx
        test dx, dx
        jz .GoOnSectorNum
        inc ax
.GoOnSectorNum:
        mov [RootDirSize], ax
        mov [wRootDirSizeForLoop], ax

        ;读取并寻找loader
LABEL_FIND_LOADER:
        test cx, cx
        jz LABEL_LOADER_NOT_FOUND
        loop LABEL_FIND_LOADER
LABEL_LOADER_NOT_FOUND:

        


;============================================================================
;变量
RootDirSize             dw      0               ; 根目录占用扇区数    
SectorNoOfRootDirectory dw      0               ; 根目录的起始扇区
wRootDirSizeForLoop	dw	0	        ; Root Directory 占用的扇区数，
						; 在循环中会递减至零.
wSectorNo		dw	0		; 要读取的扇区号
bOdd			db	0		; 奇数还是偶数

;字符串
LoaderFileName		db	"LOADER  BIN", 0 ; LOADER.BIN 之文件名
; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	9
BootMessage:		db	"Booting  " ; 9字节, 不够则用空格补齐. 序号 0
Message1		db	"Ready.   " ; 9字节, 不够则用空格补齐. 序号 1
Message2		db	"No Loader" ; 9字节, 不够则用空格补齐. 序号 2
;============================================================================

;===================================================================================
;函数名     ：  DispStr
;功能       ：  显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
;                                        ，也代表输出到屏幕的行号
;-----------------------------------------------------------------------------------
DispStr:
;-----------------------------------------------------------------------------------
        mov ax, ds              ;\
        mov es, ax              ;|
        mov ax, MessageLength   ;| es:bp--串地址
        mul dh                  ;|
        add ax, BootMessage     ;|
        mov bp, ax              ;/
        mov cx, MessageLength   ;串长度
        mov ax, 01301h          ;10h号中断的参数
        mov bx, 0007h           ;第00页（bh = 00）,黑底白字（bl = 07h）
        mov dl, 0               ;列号，第00列（dl = 00），第dh行
        int 10h
        
        ret
;===================================================================================

;===================================================================================
;函数名     ：  ReadSector
;功能       ：  读取软盘扇区到目标地址处
;参数       ：  
;       ax  ：  目标扇区号
;       cl  ：  读取扇区数
;    es:bx  ：  目标缓冲区
;-----------------------------------------------------------------------------------
ReadSector:
;-----------------------------------------------------------------------------------
;保存需要用到的寄存器的值
        push cx
        push dx
        push bp
;-----------------------------------------------------------------------------------
;开辟出一块内存区域，保存读取扇区数
        mov bp, sp
        sub sp, 2
        mov byte [bp - 2], cl
;-----------------------------------------------------------------------------------
;计算起始扇区号，柱面号，磁头号
;起始扇区号 = 目标扇区号 mod 每磁道扇区数
;磁道号 = (目标扇区号 / 每磁道扇区数) >> 1
;磁头号 = (目标扇区号 / 每磁道扇区数) and 0x1
        mov dl, [BPB_SecPerTrk] ;dl保存每磁道扇区数
        div dl                  ;做除法后al保存商，ah保存起始扇区号        
;-----------------------------------------------------------------------------------
;将起始扇区号移至cl
        inc ah                  ;起始扇区号从1开始，而非从0开始
        mov cl, ah              ;起始扇区号      
;-----------------------------------------------------------------------------------  
;计算磁头号
        mov dh, al
        and dh, 0x1             ;磁头号
;----------------------------------------------------------------------------------- 
;计算磁道号        
        mov ch, al
        shr ch, 1               ;磁道号
;----------------------------------------------------------------------------------- 
        mov dl, [BS_DrvNum]     ;驱动器号
;----------------------------------------------------------------------------------- 
;读取软盘
.GoOnReading:
        mov al, byte [bp - 2]   ;读取扇区号
        mov ah, 02h             ;标志读取扇区
        int 13h
        jc .GoOnReading         ;读取失败时CF会置1，因此要循环读取
;-----------------------------------------------------------------------------------
;恢复保存的寄存器        
        add esp, 2
        pop bp
        pop dx
        pop cx

        ret
;===================================================================================


times   510 - ($ - $$)            db      0
DW      0xaa55


        
        
