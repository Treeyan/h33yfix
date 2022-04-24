;
; 作者 : Treeyan  4/15/2022
; 编译环境 : NTDDK 2003
;
; 修复准系统 H33Y(UMA) / Intel HM55 不能安装 windows 8.1/10 的问题
;
; 注意, 
;   这台笔记本为神舟 A360-I3 D1， bios 为 205 版，8G 内存，H33Y 准系统，
; 无法保证在其他 H33Y 准系统上也能正确修正安装 Windows 10 的问题。需要自己动动手噢。
;      

.MODEL SMALL
.386P

BOOT SEGMENT USE16 AT 0 
BOOT ENDS

_TEXT SEGMENT USE16        
        
        ORG 7C00H - 200H        ; 7A00H

STACK_A:

        ;
        ; 设置堆栈
        ;
        xor  ax, ax
        mov  ss, ax
        mov  sp, OFFSET STACK_A

        push dx
        push ds
        push si
        push es
        push di
        push fs

        pushf        

        ;
        ; 复制到 7A00H
        ;
        cld
        mov  es, ax
        push cs
        call NEAR PTR FIX_ADR

FIX_ADR:

        pop  si
        pop  ds
        sub  si, OFFSET FIX_ADR - OFFSET STACK_A
        mov  di, OFFSET STACK_A
        mov  cx, 200H        
        rep  movsb

        ;
        ; 修正执行位置, cs = 0
        ;
        jmp  far ptr BOOT:[FIX_SEG]

FIX_SEG:

        ;
        ; 检查是不是 H33Y BIOS
        ;
        mov  ax, 0F000H
        mov  ds, ax
        mov  si, 0C3E2H
        cmp  DWORD PTR ds:[si], 'Y33H' ; 'H33Y'
        jne  ORG_LDR
        mov  si, 410H
        cmp  DWORD PTR ds:[si], ' DSR'  ;'RSD '
        jne  ORG_LDR

        cli
        lgdt FWORD PTR [GDT_SRU]

        ;
        ; A20 神马龟
        ;
        ;in   al, 92H
        ;or   al, 00000010B
        ;out  92H, al
        ;

        ;
        ; 进入保护模式，刷 fs 段寄存器高速缓存
        ;
        mov  eax, cr0
        or   al, 1
        mov  cr0, eax
        jmp  DWORD PTR cs:[PMD_ADR]     ; 指向 PMD_RUN
        
PMD_RUN:

        mov  bx, TBL_DATA - TBL_NULL
        mov  fs, bx

        and  al, NOT 1
        mov  cr0, eax
        jmp  FAR PTR BOOT:[FIX_ENT]

FIX_ENT:

        ;
        ; 退回实模式，检测是否为 DSDT 表位置
        ;
        sti
        mov  esi, 0BB451018H
        mov  eax, DWORD PTR fs:[esi]
        cmp  eax, 'TDSD'  ;'DSDT'
        jne  ORG_LDR

        ;
        ; 简单的修复 DSDT，仅仅为了兼容 windows 10/8.1, 其他版本 windows 不需要
        ;
        lea  edi, [esi+9]
        mov  BYTE PTR fs:[edi], 88H
        lea  edi, [esi+91E2H]
        mov  BYTE PTR fs:[edi], 1

ORG_LDR:

        ;
        ; 读写驱动器第二扇区，保存的 MBR
        ;
        mov  ax, 201H
        mov  bx, OFFSET BIO_SLR
        mov  cx, 2
        int  13H

        ;
        ; 复制分区表
        ;
        push es
        pop  ds
        mov  cx, 200H - 1B8H
        mov  si, PAT_TBL
        mov  di, PAT_MTB
        rep  movsb

        popf

        pop  fs
        pop  di 
        pop  es 
        pop  si 
        pop  ds 
        pop  dx

        ;
        ; 跳转硬盘本身的 MBR 执行
        ;
        jmp  FAR PTR BOOT:[BIO_SLR]
        jmp  $

        ;
        ; -----------------------------------------------------------------------------
        ;
        
PMD_ADR:
        dw   PMD_RUN
        dw   TBL_CODE - TBL_NULL        

        ORG STACK_A + 190H        
GDT_TBL:

    TBL_NULL: ; the  mandatory  null  descriptor
        dd 0   ; ’dd’ means  define  double  word (i.e. 4 bytes)
        dd 0

    TBL_CODE: ; the  code  segment  descriptor
        ; base=0x0, limit=0xfffff ,
        ; 1st  flags: (present )1 (privilege )00 (descriptor  type)1 -> 1001b
        ; type  flags: (code)1 (conforming )0 (readable )1 (accessed )0 -> 1010b
        ; 2nd  flags: (granularity )0 (16-bit  default )0 (64-bit  seg)0 (AVL)0 -> 0000b
        dw 0FFFFH     ; Limit (bits  0-15)
        dw 0         ; Base (bits  0-15)
        db 0         ; Base (bits  16 -23)
        db 10011010B ; 1st flags , type  flags
        db 00000000B ; 2nd flags , Limit (bits  16-19)
        db 0         ; Base (bits  24 -31)

    TBL_DATA: ;the  data  segment  descriptor
        ; Same as code  segment  except  for  the  type  flags:
        ; type  flags: (code)0 (expand  down)0 (writable )1 (accessed )0 -> 0010b
        dw 0FFFFH     ; Limit (bits  0-15)
        dw 0         ; Base (bits  0-15)
        db 0         ; Base (bits  16 -23)
        db 10010010B ; 1st flags , type  flags
        db 11001111B ; 2nd flags , Limit (bits  16-19)
        db 0         ; Base (bits  24 -31)    

TBL_END:        ; The  reason  for  putting a label  at the  end of the

GDT_SRU:        ; GDT structure
        dw OFFSET TBL_END - OFFSET GDT_TBL
        dd OFFSET GDT_TBL
SRU_END:

        ORG STACK_A + 1B8H
PAT_TBL:

        ORG 7C00H
BIO_SLR:
        
        ORG OFFSET BIO_SLR + 1B8H
PAT_MTB:

_TEXT ENDS

    END

