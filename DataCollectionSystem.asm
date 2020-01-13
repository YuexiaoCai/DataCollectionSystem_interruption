CRLF MACRO 
MOV DL, 0DH
MOV AH, 02H
INT 21H ;宏定义了回车,但不定义换行符
ENDM

Y0 EQU 0E000H;片选0809
Y1 EQU 0E020H;片选8255
Y2 EQU 0E040H;片选0832
;Y3 EQU 0E060H片选8254
Y7 EQU 0E0E0H;片选8259
ADC0 EQU Y0;0809的INO端口地址
ADC1 EQU Y0+01H*4;0809的IN1端口地址
PA55 EQU Y1+00H*4;8255的A端口地址
PB55 EQU Y1+01H*4;8255的B端口地址
PC55 EQU Y1+02H*4;8255的C端口地址
PCTL EQU Y1+03H*4;8255的控制寄存器地址
DAC EQU Y2;0832的OUT端口地址
;TIMER0 EQU Y3+00H*4;8254计数器0的端口地址
;TIMER1 EQU Y3+01H*4;8254计数器1的端口地址
;TIMER2 EQU Y3+02H*4;8254计数器2的端口地址
;TCTL EQU Y3+03H*4;8254控制寄存器的端口地址
INTR_IVADD EQU 0038H ;INTR2对应的中断矢量地址
INTR_OCW1 EQU 021H ;INTR对应PC机内部8259的OCW1地址
INTR_OCW2 EQU 020H ;INTR对应PC机内部8259的OCW2地址
INTR_IM EQU 0FBH ;INTR对应的中断屏蔽字 
MY8259_ICW1 EQU Y7+00H ;实验系统中8259的ICW1端口地址
MY8259_ICW2 EQU Y7+04H ;实验系统中8259的ICW2端口地址
MY8259_ICW3 EQU Y7+04H ;实验系统中8259的ICW3端口地址
MY8259_ICW4 EQU Y7+04H ;实验系统中8259的ICW4端口地址
MY8259_OCW1 EQU Y7+04H ;实验系统中8259的OCW1端口地址
MY8259_OCW2 EQU Y7+00H ;实验系统中8259的OCW2端口地址
MY8259_OCW3 EQU Y7+00H ;实验系统中8259的OCW3端口地址


STACK1  SEGMENT STACK
DW      256     DUP(?)
STACK1  ENDS

DATA    SEGMENT
MES0    DB      'Copyright © 1998 - 2020 CaiYuexiao. All Rights Reserved. ',0DH,0AH,'$'
MES1    DB      'The HEX value of IN1 is:$'
DCTBL   DB      3Fh,06h,5Bh,4Fh,66h,6Dh,7Dh,07h,7Fh,6Fh ;数码管的段码表
        DB      77h,7Ch,39h,5Eh,79h,71h,00H
FLAG    DB      ?
VOICE	DB	00H;控制蜂鸣器变量的初始值
CS_BAK  DW      ?;保存 INTR 原中断处理程序入口段地址的变量
IP_BAK  DW      ?;保存 INTR 原中断处理程序入口偏移地址的变量
IM_BAK  DB      ?;保存 INTR 原中断屏蔽字的变量
GW      DB      ?;个位
SF      DB      ?;十分位
BF      DB      ?;百分位
IN0     DB      ?;0809通道IN0传入后的暂存变量
IN1     DB      ?;0809通道IN1传入后的暂存变量
TWO     DB      2
DATA    ENDS

CODE    SEGMENT
ASSUME  CS:CODE,DS:DATA,SS:STACK1
START:  MOV     AX,DATA
        MOV     DS,AX
        MOV     DX,OFFSET MES0
        MOV     AH,9
        INT     21H

        CLI;初始化8259，禁止中断发生
        MOV     AX, 0000H 
        MOV     ES, AX ;替换 INTR 的中断矢量
        MOV     DI, INTR_IVADD ;保存 INTR 原中断处理程序入口偏移地址 
        MOV     AX, ES:[DI]
        MOV     IP_BAK,AX
        MOV     AX, OFFSET MYISR ;设置当前中断处理程序入口偏移地址
        MOV     ES:[DI],AX 
        ADD     DI, 2
        MOV     AX, ES:[DI] ;保存 INTR 原中断处理程序入口段地址
        MOV     CS_BAK,AX
        MOV     AX, SEG MYISR ;设置当前中断处理程序入口段地址
        MOV     ES:[DI],AX 
        MOV     DX,INTR_OCW1 ;设置中断屏蔽寄存器，打开 INTR 的屏蔽位
        IN      AL, DX ;保存 INTR 原中断屏蔽字
        MOV     IM_BAK,AL 
        AND     AL, INTR_IM ;允许 PC 机内部8259的 IR2 中断
        OUT     DX,AL
        MOV     DX, MY8259_ICW1 ;初始化实验系统中8259的 ICW1
        MOV     AL, 13H ;边沿触发、单片 8259、需要 ICW4
        OUT     DX,AL
        MOV     DX, MY8259_ICW2
        MOV     AL, 08H ;初始化实验系统中8259的 ICW2
        OUT     DX,AL
        MOV     DX, MY8259_ICW4 ;初始化实验系统中8259的 ICW4
        MOV     AL, 01H ;非自动结束 EOI
        OUT     DX,AL
        MOV     DX, MY8259_OCW3 ;向8259的 OCW3 发送读取 IRR 命令
        MOV     AL, 0AH
        OUT     DX,AL 
        MOV     DX, MY8259_OCW1 ;初始化实验系统中8259的 OCW1
        MOV     AL, 0FCH ;打开 IR0 和 IR1 的屏蔽位
        OUT     DX,AL

        ;MOV     DX,TCTL;初始化8254
        ;MOV     AL,16H;8254计数器0方式3读低8位二进制数
        ;OUT     DX,AL;输出控制字
        ;MOV     DX,TIMER0;找到TIMER0地址
        ;MOV     AL,14H;0809工作频率在10KHz-1280KHz之间，当选择18.432MHz的时钟源时，传入数值大约在18.432-1843.2之间即可
        ;OUT     DX,AL;输出初值

        MOV     AL,80H;初始化8255，A口输出，B口输出，C口输出，方式0
        MOV     DX,PCTL;写入控制字
        OUT     DX,AL;输出控制字
        STI;初始化结束，允许中断

        
MAIN:   ;启动0809的IN0
        MOV     DX,ADC0 
        OUT     DX,AL
        CALL    DELAY
        ;设置标志寄存器
        MOV     AX,0FFH
        MOV     FLAG,AL
        ;LED排灯模块
        CALL    LEDDIS
        ;量纲转换
        CALL    CHANGE
        ;显示提示信息
        LEA     DX,MES1
        MOV     AH,9
        INT     21H
        ;读入0809的IN1数据
        MOV     DX,ADC1
        IN      AL,DX
        ;输出16进制线性转换后数值
        CALL    DISP1
        MOV     DL,0FFH
        ;等待控制台输入
        MOV     AH,6
        INT     21H
        JZ      MAIN
QUIT:   CLI
        MOV     AX, 0000H ;恢复 INTR 原中断矢量
        MOV     ES, AX
        MOV     DI, INTR_IVADD ;恢复 INTR 原中断处理程序入口偏移地址
        MOV     AX, IP_BAK
        MOV     ES:[DI],AX
        ADD     DI, 2
        MOV     AX, CS_BAK ;恢复 INTR 原中断处理程序入口段地址
        MOV     ES:[DI],AX
        MOV     DX,INTR_OCW1
        MOV     AL, IM_BAK ;恢复 INTR 原中断屏蔽寄存器的屏蔽字
        OUT     DX,AL 
        STI
EXIT:   MOV     AX, 4C00H ;返回到 DOS
        INT     21H        

;转换后数值控制台回显主模块
DISP1   PROC    
        PUSH    AX
        MOV     BL,AL
        AND     AL,0F0H
        MOV     CL,4
        ROR     AL,CL
        CALL    CRT
        MOV     AL,BL
        AND     AL,0FH
        CALL    CRT
        CRLF
        POP     AX
        RET
DISP1   ENDP

;控制台显示
CRT    PROC
        ADD     AL, 30H 
        CMP     AL, 39H
        JBE     D0
        ADD     AL, 7 ;在屏幕上显示一位16进制字符
D0:     MOV     DL, AL 
        MOV     AH, 2
        INT     21H
        RET
CRT ENDP

;量纲转换模块
CHANGE PROC
        ;存个位的相对数值(加30H后为实际字符)
        MOV     AL,IN0
        XOR     AH,AH
        MOV     DL,51
        MOV     DH,10
        DIV     DL
        MOV     GW,AL
        MOV     AL,AH
        XOR     AH,AH
	;存十分位的相对数值(加30H后为实际字符)
        MUL     DH
        DIV     DL
        MOV     SF,AL
        MOV     AL,AH
        XOR     AH,AH
        MUL     DH
        DIV     DL
        CMP     AH,25
        JB      TAG
        ADD     AL,1
TAG:    ;存百分位的相对数值(加30H后为实际字符)
        MOV     BF,AL
        CALL    DISP0
        RET
CHANGE  ENDP

;数码管显示驱动模块
DISP0   PROC
        ;个位段码与位码
        MOV     AL,GW
        XOR     AH,AH
        MOV     SI,AX  
        LEA     BX,DCTBL;取段码表地址
        MOV     AL,[BX+SI];根据该数值在段码表中的对应位置，获取个位段码
        ADD     AL,80H;个位固定显示小数点
        MOV     DX,PB55
        OUT     DX,AL;输出段码
        MOV     DX,PA55
        MOV     AL,01H;选择左边第一位显示个位
        NOT	AL;位码取反
        OUT     DX,AL;输出位码
        CALL    DELAY
        ;十分位段码与位码
        MOV     AL,SF
        MOV     SI,AX
        MOV     AL,[BX+SI];根据该数值在段码表中的对应位置，获取十分位段码
        MOV     DX,PB55
        OUT     DX,AL;输出段码
        MOV     DX,PA55
        MOV     AL,02H;选择左边第二位显示个位
        NOT	AL;位码取反
        OUT     DX,AL;输出位码
        CALL    DELAY
        ;百分位段码与位码
        MOV     AL,BF
        MOV     SI,AX
        MOV     AL,[BX+SI];根据该数值在段码表中的对应位置，获取百分位段码
        MOV     DX,PB55
        OUT     DX,AL;输出段码
        MOV     DX,PA55
        MOV     AL,04H;选择左边第三位显示个位
        NOT	AL;位码取反
        OUT     DX,AL;输出位码
        CALL    DELAY  
        RET
DISP0   ENDP

;中断服务程序
MYISR   PROC    NEAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CLI;关中断,防止在执行中断服务子程序时，二次进入中断服务子程序
        CMP     FLAG,0FFH;判断标志位
        JZ      FLAG0
FLAG1:  ;当FLAG=0FFH时，读IN1值并保存
        MOV     DX,ADC1
        IN      AL,DX
        MOV     IN1,AL
        JMP     OVER
FLAG0:  ;当FLAG!=0FFH时，按要求变换IN0值并送0832输出，启动IN1
        MOV     DX,ADC0
        IN      AL,DX
        MOV     IN0,AL;将数据放入变量IN0中，方便量纲转换模块直接使用
        ;线性变换y=2.5-0.5x
        MOV     AH,0
        DIV     TWO
        NEG     AL
        MOV     BL,01111111B
        ADD     AL,BL
        ;变换后的数字量送0832
        MOV     DX,DAC
        OUT     DX,AL
        CALL    DELAY
        ;启动0809 IN1
        MOV     DX,ADC1
        OUT     DX,AL
        CALL    DELAY
        ;标志位清零
        MOV     AL,0
        MOV     FLAG,AL
OVER:   ;中断结束
        MOV     DX,INTR_OCW2
        MOV     AL, 20H 
        OUT     DX,AL ; 向 PC 机内部8259发送中断结束命令
        MOV     AL, 20H 
        OUT     20H, AL
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        STI;退出中断前开中断，以便下次中断进入
        IRET
MYISR ENDP

;延迟程序
DELAY   PROC    NEAR
        PUSH    CX
        MOV     CX,0FFFFH
        LOOP    $
        POP     CX
        RET
DELAY   ENDP

;LED排灯根据电压大小逐个亮起
LEDDIS  PROC    NEAR
PUSH    AX
        MOV     DX,PC55
        MOV     AL,0;让所有LED灯默认熄灭，以实现电压减小时灯灭
        OUT     DX,AL
       	MOV     BL, GW;获取个位的相对大小
       	ADD     BL, 30H;加30H后为字符'0'-'5'
       	CMP     BL,'0'
       	JA      LED1
       	JMP     DES;电压在0-0.99V之间，不点亮LED
LED1:  	;电压在1-1.99V之间，点亮PC1对应的LED
        MOV     DX,PCTL
	MOV     AL,00000011B;通过8255控制寄存器，对C口输出PC1进行置位
	OUT     DX,AL
	CMP     BL,'1'
       	JA      LED2
	JMP     DES
LED2:  	;电压在2-2.99V之间，点亮PC2对应的LED
        MOV     DX,PCTL
	MOV     AL,00000101B
	OUT     DX,AL
        CALL    ALERT;当电压为2-2.99V之间时蜂鸣器最低频率报警
	CMP     BL,'2'
       	JA      LED3
	JMP	DES
LED3:	;电压在3-3.99V之间，点亮PC3对应的LED
        MOV     DX,PCTL
	MOV     AL,00000111B
	OUT     DX,AL
        CALL    ALERT;当电压为3-3.99V之间时蜂鸣器最次低频率报警
        CALL    DELAY
        CALL    ALERT
	CMP     BL,'3'
       	JA      LED4
	JMP	DES
LED4: 	;电压在4-4.99V之间，点亮PC4对应的LED
        MOV     DX,PCTL
	MOV     AL,00001001B
	OUT     DX,AL
        CALL    ALERT;当电压为4-4.99V之间时蜂鸣器次高频率报警
        CALL    DELAY
        CALL    ALERT
        CALL    DELAY
        CALL    ALERT
	CMP     BL, '4'
       	JA	LED5
	JMP	DES
LED5: 	;电压5V，点亮PC5对应的LED
        MOV     DX,PCTL
	MOV     AL,00001011B
	OUT     DX,AL
        CALL    ALERT;当电压为5V时蜂鸣器最高频率报警
        CALL    DELAY
        CALL    ALERT
        CALL    DELAY
        CALL    ALERT
        CALL    DELAY
        CALL    ALERT
DES:    POP     AX
        RET
LEDDIS  ENDP

;蜂鸣器报警模块
ALERT	PROC	NEAR
	PUSH    AX
        ;对VOICE的值进行不断反转变换，从而形成方波
	CMP     VOICE,00H
        JE	VCLOW
        CMP	VOICE,0FFH
        JE	VCHIGH
VCLOW:	;当PC输出0时，下一个时刻更改为1
        MOV	VOICE,0FFH
	MOV     DX,PCTL
	MOV     AL,00000001B
	OUT     DX,AL
	JMP	BC		
VCHIGH:	;当PC输出1时，下一个时刻更改为0
        MOV	VOICE,00H
	MOV     DX,PCTL
	MOV     AL,00000000B	
	OUT     DX,AL	
BC:	POP     AX
	RET
ALERT	ENDP		

CODE    ENDS
END     START
