#include <p16F84a.inc>
LIST   P=PIC16F84A
__CONFIG _CP_OFF & _WDT_ON & _XT_OSC

;------------�������� �����/������-------------------
; PORTA		EQU     05h	;KEY and TERMOMETERS, bits:
T0			EQU		0h	;������ ������ �����������
T1			EQU		1h	;������ ������ �����������
						;2h..4h - ������
; PORTB		EQU     06h	; LCD port, bits:
BF			EQU		7h	;"������". 7h-4h - ���� ������
E			EQU		3h	;����� ������.������
RW			EQU		2h	;1-������/0-��������
RS			EQU		1h	;1-������/0-����������
V			EQU		0h  ;����� ���������� ��������

;-------------������ ���--------------------------------
		CBLOCK  0CH
COUNT		;������� ����� �/� ����������
COUNT1		;������� �/� ��������
COUNT2		;������� �/� ��������
COUNT3		;�������1 ��� ����������� �������� ������� ������
COUNT4		;�������2 ��� ����������� �������� ������� ������
W_STOCK		;������� ���������� �/� ��������� ���� ������ � ������� ������.
T_STOCK		;������� ���������� �/� ������� � �����������
RW_STOCK	;������� ���������� �/� ���������� ���
HEX			;���������� HEX ������� ����� ������ � DEC
DEC_H		;������� ����������� �� HEX
DEC_L		;������� ����������� �� HEX
T_OUT		;����������a OUT HEX
T_AIR		;����������a AIR HEX
T_SET		;����������a SET HEX
COUNT_750	;������� ��� ������� ��������� 750��
COUNT_750_M	;������� ��� ������� ��������� 750�� �������
KEY_ST		;������� ������,
OUT_ST		;������� ������� � ����������
		endc

;----- KEY_ST bits -----------------------------------
M			EQU		7h	;������� ������� ����� ������
D			EQU		6h	;������� ������ DOUN
U			EQU		5h	;������� ������ UP

; ----- OUT_ST bits ----------------------------------
VL			EQU		7h	;1-������ ������/0-������
MOD			EQU		0h	;�����:1-�������� �����������/0-����� ���������

;--------���������-------------------
#DEFINE		T_MAX	.40	;40'C ������� ������� ������������ �����������
#DEFINE		T_MIN	.10	;10'C ������ ������� ������������ �����������

;----------������ ������������ ����---------------------
        ORG     0
BEGIN:					;----������������� ������-------
		MOVLW	.1
		MOVWF	COUNT_750 	;������� �������� ��� ��������� �����������
		MOVWF	COUNT_750_M	;������� �������� ��� ��������� ����������� �������
		CLRF	KEY_ST		;������ �� ������
		CALL	INIT_A		;������������� ����� �-�� ����
		CALL	INIT_B		;������������� ����� �-�� �����
		CALL	INIT_LCD	;������������� ��� 16�2, 4-bit
		CALL	HEADER_LCD	;����� �� ��� ������ ������������ �����
		call	T_SET_RD_EEPROM;������ T_SET �� EEPROM
		call	T_SET_ON_LCD;o��������� T_SET
		call	OUT_ST_RD_EEPROM;������ OUT_ST
		btfss	OUT_ST,MOD	;���� � ������� ��� ����������� � ���� ����-���� ����
		call	SYSTEM_SLEEP
HANG:					;----������ ��������� ����-------
		CALL	TERMOMETR	;��������� ����������
		CALL	KEYS		;����� ����������
		CALL	VALVE		;������ ���������� � ���������� ��������
		CLRWDT
		GOTO	HANG

;--------------������������� ����� A-------------------------------
INIT_A
; ��������!! ����� �������� ������������� ���������!!
		BCF     STATUS,RP0    ;����� ����� 0
        CLRF    PORTA        ;�������� ������� DATAPORT
    	MOVLW   b'11111'  	 ;���p����� B'11111' � p�����p W
        BSF     STATUS,RP0    ;����� ����� 1
        MOVWF   TRISA        ;-�����
		BCF     STATUS,RP0    ;����� ����� 0
		RETURN	
;--------------������������� ����� � -----------------------------
INIT_B
		BCF     STATUS,RP0	;����� ����� 0
      	MOVLW	b'00000001'	;������� ������� ����� �, ��
		ANDWF	PORTB,1		;������ ���������� �������� �� �������
    	MOVLW   b'00000000'   ;���p����� B'00000000' � p�����p W
        BSF     STATUS,RP0    ;����� ����� 1
        MOVWF   TRISB        ;��� ������� ���������� ��� ������ 
		BCF     STATUS,RP0    ;����� ����� 0
		RETURN
;--------------������������� LCD-----------------------------------
INIT_LCD			;������������� LCD
		MOVLW	.100
 		CALL	DELAY_mS ;���� ������ ���

		MOVLW	b'00110000'		;Function set(Interface is 8-bit long)
		MOVWF	PORTB
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E	
		MOVLW	.5
 		CALL	DELAY_mS ;����

		MOVLW	b'00110000'		;Function set(Interface is 8-bit long)
		MOVWF	PORTB
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E	
		MOVLW	.100
 		CALL	DELAY_mS ;����

		MOVLW	b'00110000'		;Function set(Interface is 8-bit long)
		MOVWF	PORTB
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E	
		CALL	BUSY_LCD	;���� ����������

		MOVLW	b'00100000'		;������������� 4-������ �����
		MOVWF	PORTB
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E	
		CALL	BUSY_LCD	;���� ����������
		MOVLW 	b'00101000'	; ���.4-��� ������ � 2 ����� 5�8
		CALL	WRT_LCD_INSTR
		MOVLW 	b'00001100' ;�������� ������� � ������ �� ����������
		CALL	WRT_LCD_INSTR
		MOVLW 	b'00000001' ;�������� �������
		CALL	WRT_LCD_INSTR
		MOVLW 	b'00000110' ; ����� �����.��������� ������,
		CALL	WRT_LCD_INSTR
		RETURN
;--------HEADER_LCD-----------------------------
HEADER_LCD
		MOVLW 	b'00000001' ;�������� �������
		CALL	WRT_LCD_INSTR
		MOVLW 	81h			;������ � 2���. 1-� ������
		CALL WRT_LCD_INSTR
		MOVLW 	0x4F 		;"O"
		CALL WRT_LCD_DATA
		MOVLW 	0x55 		;"U"
		CALL WRT_LCD_DATA
		MOVLW 	0x54 		;"T"
		CALL WRT_LCD_DATA
		MOVLW 	87h			;������ � 8���. 1-� ������
		CALL WRT_LCD_INSTR
		MOVLW 	0x41 		;"A"
		CALL WRT_LCD_DATA
		MOVLW 	0x49 		;"I"
		CALL WRT_LCD_DATA
		MOVLW 	0x52 		;"R"
		CALL WRT_LCD_DATA
		MOVLW 	8Ch			;������ � 13���. 1-� ������
		CALL WRT_LCD_INSTR
		MOVLW 	0x53 		;"S"
		CALL WRT_LCD_DATA
		MOVLW 	0x45 		;"E"
		CALL WRT_LCD_DATA
		MOVLW 	0x54 		;"T"
		CALL WRT_LCD_DATA
		return
;--------����� �������� �����������----------------------
TERMOMETR
		DECFSZ	COUNT_750	
		GOTO	TERM_END
		DECFSZ	COUNT_750_M
		GOTO	TERM_END		;--���� ����� ��������� �� ������ - ���������� ��� �/�

TERM_READ:;--------����� ������ �����������--------------
		CALL	T0_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T0_WRITE
		MOVLW	0xBE		;Read scrachpad comand
		CALL	T0_WRITE	;
		CALL	T0_READ		;� W ��������� �����������
		MOVWF	T_AIR

		CALL	T1_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T1_WRITE
		MOVLW	0xBE		;Read scrachpad comand
		CALL	T1_WRITE
		CALL	T1_READ		;� W ��������� �����������
		MOVWF	T_OUT		

		CALL	T_ON_LCD	;���������� ���������

		;---------����� ��������� �����������-----------
		CALL	T0_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T0_WRITE
		MOVLW	0x44		;Start convertion comand
		CALL	T0_WRITE	;����� �� ����� ��� ����� 10 ��� ������ ���������� �������.���������� 750 ��
        BSF		PORTA,T0	;���������� 1 � �������� �/� ��� ������ �0
        BSF     STATUS,RP0	;����� ����� 1
		BCF		TRISA,T0	;����������� ����� �0 �� �����
		BCF     STATUS,RP0	;������� ��������� ����� 0

		CALL	T1_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T1_WRITE
		MOVLW	0x44		;Start convertion comand
		CALL	T1_WRITE	;����� �� ����� ��� ����� 10 ��� ������ ���������� �������.���������� 750 ��
        BSF		PORTA,T1	;���������� 1 � �������� �/� ��� ������ �1
        BSF     STATUS,RP0	;����� ����� 1
		BCF		TRISA,T1	;����������� ����� �1 �� �����
		BCF     STATUS,RP0	;������� ��������� ����� 0
		
		MOVLW	.74		;������ ������� ��������
		MOVWF	COUNT_750_M
TERM_END:
		RETURN

;--------����� ����������-----------------------------------
KEYS
		CLRF	KEY_ST		;�������� ������� ������
		CLRF	COUNT3		;������� �������� �������� �������
		CLRF	COUNT4

		BTFSS	PORTA, 3h 	;������ ���� � ���������� �����
		BSF	    KEY_ST, D
		BTFSS	PORTA, 2h 
		BSF	    KEY_ST, U
		INCF	KEY_ST,1	;���� �� ������ �� ���� �������-����� �/�
		DECFSZ	KEY_ST,1
		GOTO	DRIGLING
		GOTO	KEY_M1
DRIGLING:
		MOVLW	.20
		CALL 	DELAY_mS	;���� 20mS
		BTFSC	PORTA, 3h 	;�������� ������ �����(�������)
		BCF	    KEY_ST, D
		BTFSC	PORTA, 2h 
		BCF	    KEY_ST, U
EXIT3:
		DECFSZ	COUNT3		;������ ��� ����� ������ ������
		GOTO	KEY_M2
		DECFSZ	COUNT4
		GOTO	KEY_M2
		CLRF	KEY_ST		;���� ������ ������ ������ 760��
		BSF	    KEY_ST,M	
		
KEY_M2:
		CLRWDT
		MOVF	PORTA,0	;���� ����� �������� ��� �������
		ANDLW	b'11100'	;����� �� �������
		SUBLW	b'11101'
		MOVWF	W_STOCK
		DECFSZ	W_STOCK,1
		GOTO	EXIT3
		call	T_SET_RECALC	;������������ T_SET �������� ��������
		call	T_SET_ON_LCD	;���������� ��������� T_SET

		;����������� ��������� �������
		BTFSS	KEY_ST,M
		GOTO	KEY_M1		;���� �� ���� ������� ������� ������
		CALL	SYSTEM_SLEEP	;���� ����� ������ ����� �������
		CLRF	KEY_ST		;�������� ������� ������
KEY_M1:		
		RETURN

;------------- T_SET_recalculation -----------
T_SET_RECALC
		;����������� ��������� ������� �����������
		BTFSC	KEY_ST, U	;���� ���� ������ �������-��������� T_SET
		INCF	T_SET,1
		BTFSC	KEY_ST, D
		DECF	T_SET,1
        ;��������� ���������� ��������� ��������
		MOVF	T_SET,0		;If T_SET>max then T_SET-1
		SUBLW	T_MAX		;������� ��������� ������� �����������
		MOVWF	W_STOCK
		BTFSC	W_STOCK,7h
		DECF	T_SET,1		;���� ����������, ���������� �������

		MOVF	T_SET,0		;If T_SET<min then T_SET+1
		SUBLW	T_MIN		;������ ��������� ������� �����������
		MOVWF	W_STOCK
		DECF	W_STOCK,1
		BTFSS	W_STOCK,7h
		INCF	T_SET,1		;���� ����������, ���������� �������

		call	T_SET_WR_EEPROM
		return

;---------- ����� T_SET �� LCD ----------------
T_SET_ON_LCD
;����� ������������� �����������
		MOVLW 	0xCB		;������ � 12���. 2-� ������
		CALL WRT_LCD_INSTR
		MOVLW	0x20		;������
		BTFSC	T_SET, 7h 	;���� �� ���=1 - ������ ���.
		MOVLW	0x2D		;������� "-"
		CALL WRT_LCD_DATA	;������� ������ ��� "-"
		MOVF	T_SET,0		;����������� � ����������� ����
		CALL	HEX_DEC
		MOVF	DEC_H,0
		ADDLW	0x30		;���������� �����
		CALL WRT_LCD_DATA
		MOVF	DEC_L,0
		ADDLW	0x30		;���������� �����
		CALL WRT_LCD_DATA
		MOVLW 	0xDF 		;������ �������
		CALL WRT_LCD_DATA
		MOVLW 	0x43 		;"C"
		CALL WRT_LCD_DATA
		return

;------------ ����� ���������� ���������� �� LC-----------------
T_ON_LCD	
;����� ������� �����������
		MOVLW 	0xC0		;������ � 1���. 2-� ������
		CALL WRT_LCD_INSTR
		MOVLW	0x20		;������ 
		BTFSC	T_OUT, 7h 	;���� �� ���=1 - ������ ���.
		MOVLW	0x2D		;������� "-"
		CALL WRT_LCD_DATA	;������� ������ ��� "-"
		MOVF	T_OUT,0		;����������� � ����������� ����
		CALL	HEX_DEC	
		MOVF	DEC_H,0		;�������
		ADDLW	0x30		;���������� �����
		CALL WRT_LCD_DATA
		MOVF	DEC_L,0		;�������
		ADDLW	0x30		;���������� �����
		CALL WRT_LCD_DATA
		MOVLW 	0xDF 		;������ �������
		CALL WRT_LCD_DATA
		MOVLW 	0x43 		;"C"
		CALL WRT_LCD_DATA
;����� ����������� ������
		MOVLW 	0xC6		;������ � 7���. 2-� ������
		CALL WRT_LCD_INSTR
		MOVLW	0x20		;������
		BTFSC	T_AIR, 7h 	;���� �� ���=1 - ������ ���.
		MOVLW	0x2D		;������� "-"
		CALL WRT_LCD_DATA	;������� ������ ��� "-"
		MOVF	T_AIR,0		;����������� � ����������� ����
		CALL	HEX_DEC
		MOVF	DEC_H,0
		ADDLW	0x30		;���������� �����
		CALL WRT_LCD_DATA
		MOVF	DEC_L,0
		ADDLW	0x30		;���������� �����
		CALL WRT_LCD_DATA
		MOVLW 	0xDF 		;������ �������
		CALL WRT_LCD_DATA
		MOVLW 	0x43 		;"C"
		CALL WRT_LCD_DATA
		RETURN

;------����� ����������� �������-----------
SYSTEM_SLEEP
		BCF		OUT_ST,VL	;��������� ������(������)
		BCF		PORTB,V		;��������� ������(����)	
		BCF		OUT_ST, MOD	;����� - heat system off
		call	OUT_ST_WR_EEPROM;����� � EEPROM ��������� �������
;Heat System
;   Off
		MOVLW 	b'00000001' ;�������� �������
		CALL	WRT_LCD_INSTR
		MOVLW 	82h			;������ � 3���. 1-� ������
		CALL WRT_LCD_INSTR
		MOVLW 	0x48 		;"H"
		CALL WRT_LCD_DATA
		MOVLW 	0x65 		;"e"
		CALL WRT_LCD_DATA
		MOVLW 	0x61 		;"a"
		CALL WRT_LCD_DATA
		MOVLW 	0x74 		;"t"
		CALL WRT_LCD_DATA
		MOVLW 	88h			;������ � 9���. 1-� ������
		CALL WRT_LCD_INSTR
		MOVLW 	0x53 		;"S"
		CALL WRT_LCD_DATA
		MOVLW 	0x79 		;"y"
		CALL WRT_LCD_DATA
		MOVLW 	0x73 		;"s"
		CALL WRT_LCD_DATA
		MOVLW 	0x74 		;"t"
		CALL WRT_LCD_DATA
		MOVLW 	0x65 		;"e"
		CALL WRT_LCD_DATA
		MOVLW 	0x6D 		;"m"
		CALL WRT_LCD_DATA
		MOVLW 	0xC6		;������ � 7���. 2-� ������
		CALL WRT_LCD_INSTR
		MOVLW 	0x4F 		;"O"
		CALL WRT_LCD_DATA
		MOVLW 	0x66 		;"f"
		CALL WRT_LCD_DATA
		MOVLW 	0x66 		;"f"
		CALL WRT_LCD_DATA
SLEEP_MORE:
		CLRWDT
		CLRF	KEY_ST		;�������� ������� ������
		BTFSS	PORTA, 3h 	;������ ���� � ���������� �����
		BSF	    KEY_ST, D
		BTFSS	PORTA, 2h 
		BSF	    KEY_ST, U

		INCF	KEY_ST,1	;���� �� ������ �� ���� �������-
		DECFSZ	KEY_ST,1
		GOTO	SLEEP_DRIGLING
		GOTO	SLEEP_MORE
SLEEP_DRIGLING:
		MOVLW	.20
		CALL 	DELAY_mS	;���� 20mS
		BTFSC	PORTA, 3h 	;�������� ������ �����(�������)
		BCF	    KEY_ST, D
		BTFSC	PORTA, 2h 
		BCF	    KEY_ST, U

		INCF	KEY_ST,1	;���� �� ������ �� ���� �������-
		DECFSZ	KEY_ST,1
		GOTO	WAKE_UP
		GOTO	SLEEP_MORE
WAKE_UP:
		CLRWDT			
		MOVF	PORTA,0	;����� ��������� ����� �������� �������
		ANDLW	b'11100'	;����� �� �������
		SUBLW	b'11101'
		MOVWF	W_STOCK
		DECFSZ	W_STOCK,1
		GOTO	WAKE_UP
; wake up processes
		BSF		OUT_ST, MOD		;����� - �������� �����������
		call	OUT_ST_WR_EEPROM;����� � EEPROM ��������� �������
		call	HEADER_LCD		;����� ������ ���. ���
		call	T_SET_ON_LCD	;����� T_SET
		RETURN

;------������ ���������� � ���������� ��������-------------
VALVE
		MOVF	T_SET,0		;������� ������� ���� � W
		SUBWF	T_AIR,0		;F-W  ->  W
		MOVWF	W_STOCK	
		INCF	W_STOCK,1	;
		DECFSZ	W_STOCK,1	; ��������� ������� T_SET=T_AIR
		GOTO	CHANGE_V
		GOTO	VL_RETURN	;����������� ==,������ �� ������
CHANGE_V:
		BTFSC	W_STOCK,7	;���� � ����� ���� 1 -��� ����� �����
		GOTO	HEATING
		BCF		OUT_ST,VL	;��������� ������(������)
		BCF		PORTB,V		;��������� ������(����)		
		GOTO	VL_RETURN
HEATING:
		BSF		OUT_ST,VL	;�������� ������(������)
		BSF		PORTB,V		;�������� ������(����)		
VL_RETURN:
		RETURN

;--------------������ � LCD �������-------------------------
WRT_LCD_INSTR				;� W - ���������� ��� ���
		MOVWF	RW_STOCK	;���������� �� ������������ � RW_STOCK
		ANDLW	b'11110000' ;�������� ������� �������� ����������
		BTFSC	OUT_ST,VL	;���� ������ �.�.�������
		ADDLW	1			;��������� ��� ������ ����������
		MOVWF	PORTB		;������ � ���� �
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E		;����� ������� �������� ���������
		SWAPF   RW_STOCK,1 	;������ ������� �����-����� ���������
		MOVF	RW_STOCK,0	;������� ����������� ���������� � �����������
		ANDLW	b'11110000' ;�������� �������(���������� �������) ��������
		BTFSC	OUT_ST,VL	;���� ������ �.�.�������
		ADDLW	1			;��������� ��� ������ ����������	
		MOVWF	PORTB		;������ � ���� �
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E		;����� ������� �������� ���������
		CALL	BUSY_LCD	;���� ���������� ���
		RETURN

;--------------������ � LCD ������-------------------------
WRT_LCD_DATA				;� W - ������ ��� ���
		MOVWF	RW_STOCK	;������ �� ������������ � RW_STOCK
		ANDLW	b'11110000' ;�������� ������� �������� 
		BTFSC	OUT_ST,VL	;���� ������ �.�.�������
		ADDLW	1			;��������� ��� ������ ����������	
		MOVWF	PORTB		;������ � ���� �
		BSF		PORTB,RS    ;��������� ����������� ������ "������ ������" 
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E		;����� ������� �������� ���������
		SWAPF   RW_STOCK,1 	;������ ������� �����-����� ���������
		MOVF	RW_STOCK,0	;������� ����������� ���������� � �����������
		ANDLW	b'11110000' ;�������� �������(���������� �������) ��������
		BTFSC	OUT_ST,VL	;���� ������ �.�.�������
		ADDLW	1			;��������� ��� ������ ����������	
		MOVWF	PORTB		;������ � ���� �
		BSF		PORTB,RS    ;��������� ����������� ������ "������ ������" 
		BSF		PORTB,E		;����� ������
		BCF		PORTB,E		;����� ������� �������� ���������
		CALL	BUSY_LCD	;���� ���������� ���
		RETURN

;-------------�������� ���������� LCD----------------------
BUSY_LCD
		MOVLW	.2
 		CALL	DELAY_mS
		RETURN

;--------�������������� HEX to DEC ---------------
HEX_DEC	;����� ������������� ����������� � �������������
		MOVWF	HEX ;"-" ������� ����������� ��� ������������
		BTFSS	HEX, 7h ;���� ��� ����=0 - ���� �����
		GOTO	DECIMALING
		XORLW	0xFF	;���������� ������ �� ����������� ��������
		ADDLW	1
		MOVWF	HEX
DECIMALING:
		MOVLW	.10
		CLRF	DEC_H
		CLRF	DEC_L
SUB_10:
		SUBWF	HEX,1
		INCF	DEC_H,1	
		BTFSS	HEX, 7h 
		GOTO 	SUB_10
		ADDWF	HEX,0
		DECF	DEC_H,1
		MOVWF	DEC_L
		RETURN

;--------��������� �������������� ����������-----------------------------------
T0_HIZ	;-------------��������� ������ 1-�� ������� � ��������� �������� ��������� 
        BSF     STATUS,RP0	;����� ����� 1
        BSF     TRISA,T0	;��������� ������ ��� ���� (������� ��������)
		BCF     STATUS,RP0	;����� ����� 0
		RETURN	
T1_HIZ	;-------------��������� ������ 2-�� ������� � ��������� �������� ��������� 
        BSF     STATUS,RP0	;����� ����� 1
        BSF     TRISA,T1	;��������� ������ ��� ���� (������� ��������)
		BCF     STATUS,RP0	;����� ����� 0
		RETURN	
T0_LO	;-------------��������� ������ 1-�� ������� � 0
		BCF		PORTA,T0	;���������� 0 
		BSF     STATUS,RP0	;����� ����� 1
        BCF     TRISA,T0	;��������� ������ ��� �����
		BCF     STATUS,RP0	;����� ����� 0
		RETURN
T1_LO	;-------------��������� ������ 2-�� ������� � 0
		BCF		PORTA,T1	;���������� 0 
		BSF     STATUS,RP0	;����� ����� 1
        BCF     TRISA,T1	;��������� ������ ��� �����
		BCF     STATUS,RP0	;����� ����� 0
		RETURN
T0_RESET
		CALL 	T0_HIZ		; --> 1
		CALL 	T0_LO		; --> 0
		MOVLW	.50
		CALL	DELAY_x10mkS		
		CALL 	T0_HIZ		; --> 1
		MOVLW	.50
		CALL	DELAY_x10mkS		
		RETURN
T1_RESET
		CALL 	T1_HIZ		; --> 1
		CALL 	T1_LO		; --> 0
		MOVLW	.50
		CALL	DELAY_x10mkS		
		CALL 	T1_HIZ		; --> 1
		MOVLW	.50
		CALL	DELAY_x10mkS		
		RETURN
T0_WRITE	;---------����� ������� �� ������. ������ 1----
		MOVWF	T_STOCK	;������������ ����
		MOVLW	.8
		MOVWF	COUNT		;������� �����
T0_WLOOP:
		CALL	T0_LO		; --> 0
		RRF		T_STOCK,1	;�������� ����� Carry Flag
		BSF		STATUS,RP0	;����� ����� 1
		BTFSC	STATUS,C	;��������� Carry Flag
		BSF		TRISA,T0	;HIZ ���� 1
		BCF     STATUS,RP0	;����� ����� 0
		MOVLW	.6
		CALL	DELAY_x10mkS;�������� 64 ���
		CALL	T0_HIZ		; --> 1
		DECFSZ	COUNT,1
		GOTO	T0_WLOOP
		RETURN	
T1_WRITE	;---------����� ������� �� ������. ������ 2----
		MOVWF	T_STOCK	;������������ ����
		MOVLW	.8
		MOVWF	COUNT		;������� �����
T1_WLOOP:
		CALL	T1_LO		; --> 0
		RRF		T_STOCK,1	;�������� ����� Carry Flag
		BSF		STATUS,RP0	;����� ����� 1
		BTFSC	STATUS,C	;��������� Carry Flag
		BSF		TRISA,T1	;HIZ ���� 1
		BCF     STATUS,RP0	;����� ����� 0
		MOVLW	.6
		CALL	DELAY_x10mkS;�������� 64 ���
		CALL	T1_HIZ		; --> 1
		DECFSZ	COUNT,1
		GOTO	T1_WLOOP
		RETURN	
	
T0_READ		;--------������ 1-�� ���� ������ ------
		MOVLW	.9		;������ ����� �� 1 ������, �.�. � 0 ���� - ������� �������� �����������, �� ��� ���������
		MOVWF	COUNT		;������� �����
T0_RLOOP:
		CALL	T0_LO		; --> 0
		CALL	T0_HIZ		; --> 1
		NOP					
		NOP
		MOVF	PORTA,0		;������ ���
		ANDLW	b'00000001'	;�����
		ADDLW	.255		;���� ������ 1 ����� ������������
		RRF		T_STOCK,1	;��������� ���� ������������ � ����������
		MOVLW	.5
		CALL	DELAY_x10mkS;�������� 54 ���	
		DECFSZ	COUNT,1
		GOTO	T0_RLOOP
		MOVF	T_STOCK,0	
		RETURN

T1_READ		;--------������ 2-�� ���� ������ ------
		MOVLW	.9		;������ ����� �� 1 ������, �.�. � 0 ���� - ������� �������� �����������, �� ��� ���������
		MOVWF	COUNT		;������� �����
T1_RLOOP:
		CALL	T1_LO		; --> 0
		CALL	T1_HIZ		; --> 1
		NOP					
		NOP
		MOVF	PORTA,0		;������ ���
		ANDLW	b'00000010'	;�����
		ADDLW	.255		;���� ������ 1 ����� ������������
		RRF		T_STOCK,1	;��������� ���� ������������ � ����������
		MOVLW	.5
		CALL	DELAY_x10mkS;�������� 54 ���	
		DECFSZ	COUNT,1
		GOTO	T1_RLOOP
		MOVF	T_STOCK,0	
		RETURN

;--------T_SET_store in EEPROM_write--------------
T_SET_WR_EEPROM
		BCF		STATUS, RP0 ; Bank 0
		MOVFW	T_SET	;WE WILL WRITE SET TEMPR TO EEPROM
		MOVWF	EEDATA	;WRITING DATA W-->EEDATA REG
		MOVLW	0x00
		MOVWF	EEADR	; WRITE Address 
		call	EEPROM_WR_SEQ; write T_SET in 0x01 EEPROM
		return

;------- ����������� ��������� ������� -----------
OUT_ST_WR_EEPROM
		BCF		STATUS, RP0 ; Bank 0
		MOVFW	OUT_ST	;WE WILL WRITE OUT_ST TO EEPROM
		MOVWF	EEDATA	;WRITING DATA W-->EEDATA REG
		MOVLW	0x01
		MOVWF	EEADR	; WRITE Address 
		call	EEPROM_WR_SEQ; write T_SET in 0x01 EEPROM
		return

;--------- EEPROM_write standard sequence ---------
EEPROM_WR_SEQ
		BSF		STATUS, RP0 ; Bank 1
		BCF		INTCON, GIE ; Disable INTs.
		BSF		EECON1, WREN ; Enable Write
		MOVLW	55h ;
		MOVWF	EECON2 ; Write 55h
		MOVLW	0xAA ;
		MOVWF	EECON2 ; Write AAh
		BSF		EECON1,WR ; Set WR bit
		; begin write
		BSF		INTCON, GIE ; Enable INTs.
		movlw	.15		
		call	DELAY_mS	;wait till write process finish
		BCF		STATUS, RP0 ; Bank 0
		return

;--------T_SET read from EEPROM--------------
T_SET_RD_EEPROM
		BCF		STATUS, RP0 ; Bank 0
		MOVLW	0x00		;Address to read
		MOVWF	EEADR		; Address to read
		BSF		STATUS, RP0	; Bank 1
		BSF		EECON1, RD	; EE Read
		BCF		STATUS, RP0	; Bank 0
		MOVF	EEDATA, 0	; W = EEDATA
		BCF		STATUS, RP0 ; Bank 0
		MOVWF	T_SET		; save in T_SET
		RETURN

;--------OUT_ST read from EEPROM--------------
OUT_ST_RD_EEPROM
		BCF		STATUS, RP0 ; Bank 0
		MOVLW	0x01		;Address to read
		MOVWF	EEADR		; Address to read
		BSF		STATUS, RP0	; Bank 1
		BSF		EECON1, RD	; EE Read
		BCF		STATUS, RP0	; Bank 0
		MOVF	EEDATA, 0	; W = EEDATA
		BCF		STATUS, RP0 ; Bank 0
		MOVWF	OUT_ST		; save in OUT_ST
		RETURN

;--------�������� 1...255 ��----------------------------------------------------
DELAY_mS ;� W ��������� ����� �������� � ��
        MOVWF 	COUNT1
		NOP
		NOP
OUTTER:
		MOVLW   .111      ; �������� 1 ��
        MOVWF   COUNT2
INNER:
        NOP ; �������� 1 ��
        NOP
        NOP
        NOP
        NOP
        NOP
        DECFSZ  COUNT2, F
        GOTO 	INNER
        DECFSZ  COUNT1, F
        GOTO 	OUTTER
		CLRWDT
        RETURN
;--------�������� 14...2554 ���-------------------------------
DELAY_x10mkS:   ;�������� ������������ ��� W*10+4 ��� (14mkS- 2554mkS)
        MOVWF 	COUNT1
DELAY_10USEC_1:
      	NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        DECFSZ 	COUNT1, F
        GOTO 	DELAY_10USEC_1
		CLRWDT
        RETURN
;---------------------------------------------------------------
		END
