#include <p16F84a.inc>
LIST   P=PIC16F84A
__CONFIG _CP_OFF & _WDT_ON & _XT_OSC

;------------ I/O REGISTERS -------------------
; PORTA		EQU     05h	; KEY and TERMOMETERS, bits:
T0		EQU	0h	; - temperature sensor 1
T1		EQU	1h	; - temperature sensor 1
				; - 2h..4h - buttons
; PORTB		EQU     06h	; LCD port, bits:
BF		EQU	7h	; - "bussy". 7h-4h - data bus
E		EQU	3h	; - Read/Write start
RW		EQU	2h	; - 1-read/0-write
RS		EQU	1h	; - 1-data/0-instruction
V		EQU	0h	; - output signal for valve

;------------- MEMORY --------------------------------
		CBLOCK  0CH
COUNT		; termometer I/O bits counter
COUNT1		; delay routine counter
COUNT2		; delay routine counter
COUNT3		; counter 1 for detecting long button press
COUNT4		; counter 2 for detecting long button press
W_STOCK		; variable for key controller and temperature analyzer function
T_STOCK		; variable for temperature communication function
RW_STOCK	; variable for LCD controller
HEX		; HEX variable - will be converted to DEC
DEC_H		; tens digit of DEC, converted from HEX
DEC_L		; unit digit of DEC, converted from HEX
T_OUT		; OUT temperature in HEX
T_AIR		; AIR temperature in HEX
T_SET		; SET temperature in HEX
COUNT_750	; convertion time counter 750ms
COUNT_750_M	; outher convertion time counter 750ms
KEY_ST		; keys status
OUT_ST		; valve and control statuses
		endc

;----- KEY_ST bits -----------------------------------
M			EQU		7h	; any button long press flag
D			EQU		6h	; DOUN button pressed
U			EQU		5h	; UP button pressed

; ----- OUT_ST bits ----------------------------------
VL			EQU		7h	; 1-open valve/0-close valve
MOD			EQU		0h	; mode:1-check temperature/0-heater off

;-------- CONSTANTS -------------------
#DEFINE		T_MAX	.40	; 40'C is maximum adjustable temperature
#DEFINE		T_MIN	.10	; 10'C is minimum adjustable temperature

;---------- BEGINING OF EXECUTABLE CODE ---------------------
        ORG     0
BEGIN:					;---- INITIALISATIONS -------
		MOVLW	.1
		MOVWF	COUNT_750 	; convertion time counter 750ms
		MOVWF	COUNT_750_M	; outher convertion time counter 750ms
		CLRF	KEY_ST		; no button pressed
		CALL	INIT_A		; Port A for input
		CALL	INIT_B		; Port B for output
		CALL	INIT_LCD	; LCD 16х2, 4-bit
		CALL	HEADER_LCD	; Show greeting
		call	T_SET_RD_EEPROM	; read T_SET (desired temperature) from EEPROM
		call	T_SET_ON_LCD	; display T_SET
		call	OUT_ST_RD_EEPROM; read OUT_ST (valve and control statuses)
		btfss	OUT_ST,MOD	; if last time before swich off system was in sleep mode do sleed
		call	SYSTEM_SLEEP
HANG:					;---- MAIN CYCLE -------
		CALL	TERMOMETR	; measure temperatures
		CALL	KEYS		; scan keys
		CALL	VALVE		; manage valve depend of temperature and keys status
		CLRWDT
		GOTO	HANG

;-------------- Port A Initialisation -------------------------------
INIT_A
; attention!! pull-up resistors must be enabled!!
	BCF     STATUS,RP0	; set memory bank 0
        CLRF    PORTA		; clear DATAPORT register A
    	MOVLW   b'11111'  	; load B'11111' to register W
        BSF     STATUS,RP0      ; set memory bank 1
        MOVWF   TRISA           ; set as inputs
	BCF     STATUS,RP0      ; set memory bank 0
	RETURN	
;-------------- Port B Initialisation -----------------------------
INIT_B
	BCF     STATUS,RP0	; set memory bank 0
      	MOVLW	b'00000001'	; clear DATAPORT register B , but
	ANDWF	PORTB,1		; do not touch valve control bit
    	MOVLW   b'00000000'     ; load B'00000000' to register W
        BSF     STATUS,RP0      ; set memory bank 1
        MOVWF   TRISB           ; set as outputs
	BCF     STATUS,RP0      ; set memory bank 0
	RETURN
;-------------- LCD initialisation -----------------------------------
INIT_LCD
	MOVLW	.100
 	CALL	DELAY_mS ;Ждем старта ЖКИ

	MOVLW	b'00110000'	; Function set(Interface is 8-bit long)
	MOVWF	PORTB
	BSF	PORTB,E		; write start
	BCF	PORTB,E	
	MOVLW	.5
 	CALL	DELAY_mS 	; wait

	MOVLW	b'00110000'	; Function set(Interface is 8-bit long)
	MOVWF	PORTB
	BSF	PORTB,E		; write start
	BCF	PORTB,E	
	MOVLW	.100
 	CALL	DELAY_mS 	; wait

	MOVLW	b'00110000'	; Function set(Interface is 8-bit long)
	MOVWF	PORTB
	BSF	PORTB,E		; write start
	BCF	PORTB,E	
	CALL	BUSY_LCD	; wait for readiness

	MOVLW	b'00100000'	; set 4-bit mode
	MOVWF	PORTB
	BSF	PORTB,E		; write start
	BCF	PORTB,E	
	CALL	BUSY_LCD	; wait for readiness
	MOVLW 	b'00101000'	; set 4-bit mode and 2 lines 5х8
	CALL	WRT_LCD_INSTR
	MOVLW 	b'00001100' 	; swith on LCD, do not show cursor
	CALL	WRT_LCD_INSTR
	MOVLW 	b'00000001' 	; clear LCD
	CALL	WRT_LCD_INSTR
	MOVLW 	b'00000110' 	; input mode. address increment
	CALL	WRT_LCD_INSTR
	RETURN
;-------- HEADER_LCD -----------------------------
HEADER_LCD
	MOVLW 	b'00000001' 	; clear LCD
	CALL	WRT_LCD_INSTR
	MOVLW 	81h		; cursor to 2nd place in 1st string
	CALL 	WRT_LCD_INSTR
	MOVLW 	0x4F 		;"O"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x55 		;"U"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x54 		;"T"
	CALL 	WRT_LCD_DATA
	MOVLW 	87h		; cursor to 8 place in 1st string
	CALL 	WRT_LCD_INSTR
	MOVLW 	0x41 		;"A"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x49 		;"I"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x52 		;"R"
	CALL 	WRT_LCD_DATA
	MOVLW 	8Ch		; cursor to 13 place in 1st string
	CALL 	WRT_LCD_INSTR
	MOVLW 	0x53 		;"S"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x45 		;"E"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x54 		;"T"
	CALL 	WRT_LCD_DATA
	return
;-------- Scan temperature sensors ----------------------
TERMOMETR
	DECFSZ	COUNT_750	
	GOTO	TERM_END
	DECFSZ	COUNT_750_M
	GOTO	TERM_END	; if convertion time did not pass skipp whole routine

;-------- Read temperature --------------
TERM_READ:
	;-------- Read temperature sensors--------------
	CALL	T0_RESET	; Reset
	MOVLW	0xCC		; skip ROM comand
	CALL	T0_WRITE
	MOVLW	0xBE		; Read scrachpad comand
	CALL	T0_WRITE	;
	CALL	T0_READ		; now temperature 0 is in W
	MOVWF	T_AIR

	CALL	T1_RESET	; Reset
	MOVLW	0xCC		; skip ROM comand
	CALL	T1_WRITE
	MOVLW	0xBE		; Read scrachpad comand
	CALL	T1_WRITE
	CALL	T1_READ		; now temperature 1 is in W
	MOVWF	T_OUT		

	CALL	T_ON_LCD	; display temperatures

	;--------- temperature convertion -----------
	CALL	T0_RESET	; Reset
	MOVLW	0xCC		; skip ROM comand
	CALL	T0_WRITE
	MOVLW	0x44		; Start convertion comand
	CALL	T0_WRITE	; it is necessary to supply parasitic power no later than 10 µs. hold for 750 ms
        BSF	PORTA,T0	; set 1 in I/O register for T0 pin
        BSF     STATUS,RP0	; set memory bank 1
	BCF	TRISA,T0	; set pin T0 for output
	BCF     STATUS,RP0	; set memory bank 0

	CALL	T1_RESET	; Reset
	MOVLW	0xCC		; skip ROM comand
	CALL	T1_WRITE
	MOVLW	0x44		; Start convertion comand
	CALL	T1_WRITE	; it is necessary to supply parasitic power no later than 10 µs. hold for 750 ms
        BSF	PORTA,T1	; set 1 in I/O register for T1 pin
        BSF     STATUS,RP0	; set memory bank 1
	BCF	TRISA,T1	; set pin T1 for output
	BCF     STATUS,RP0	; set memory bank 0
		
	MOVLW	.74		; Begining of delay counter
	MOVWF	COUNT_750_M
TERM_END:
	RETURN

;-------- keys scan -----------------------------------
KEYS
	CLRF	KEY_ST		; clear keys statuses
	CLRF	COUNT3		; clear long press counters
	CLRF	COUNT4

	BTFSS	PORTA, 3h 	; read port, set up flags
	BSF	KEY_ST, D
	BTFSS	PORTA, 2h 
	BSF	KEY_ST, U
	INCF	KEY_ST,1	; if no keys pressed - return
	DECFSZ	KEY_ST,1
	GOTO	DRIGLING
	GOTO	KEY_M1
DRIGLING:
	MOVLW	.20
	CALL 	DELAY_mS	; wait 20mS
	BTFSC	PORTA, 3h 	; clear false flags caused by bounce noice of keys
	BCF	KEY_ST, D
	BTFSC	PORTA, 2h 
	BCF	KEY_ST, U
EXIT3:
	DECFSZ	COUNT3		; count how long key was pressed
	GOTO	KEY_M2
	DECFSZ	COUNT4
	GOTO	KEY_M2
	CLRF	KEY_ST		; if key pressed for more than 760ms
	BSF	KEY_ST,M	
		
KEY_M2:
	CLRWDT
	MOVF	PORTA,0		; wait all keys release
	ANDLW	b'11100'	; mask for keys
	SUBLW	b'11101'
	MOVWF	W_STOCK
	DECFSZ	W_STOCK,1
	GOTO	EXIT3
	call	T_SET_RECALC	; recalculate T_SET in accordance with pressed key
	call	T_SET_ON_LCD	; display Отображаем изменения T_SET

	;анализируем изменение режимов
	BTFSS	KEY_ST,M	; if no long press
	GOTO	KEY_M1		; return
	CALL	SYSTEM_SLEEP	; else launch sleep mode
	CLRF	KEY_ST		; reset keys statuses
KEY_M1:		
	RETURN

;------------- T_SET_recalculation -----------
T_SET_RECALC
	; manage desirable temperature
	BTFSC	KEY_ST, U	; change T_SET in case + or - key pressed
	INCF	T_SET,1
	BTFSC	KEY_ST, D
	DECF	T_SET,1
        ; check temperature limits
	MOVF	T_SET,0		; If T_SET>max then T_SET-1
	SUBLW	T_MAX		; high limin of temperature settings
	MOVWF	W_STOCK
	BTFSC	W_STOCK,7h
	DECF	T_SET,1		; if temperature seting too high returt maximum limit

	MOVF	T_SET,0		; If T_SET<min then T_SET+1
	SUBLW	T_MIN		; low limit temperature settings
	MOVWF	W_STOCK
	DECF	W_STOCK,1
	BTFSS	W_STOCK,7h
	INCF	T_SET,1		; if temperature seting too low returt minimum limit

	call	T_SET_WR_EEPROM ; save the settings
	return

;---------- show desirable temperature T_SET to LCD ----------------
T_SET_ON_LCD
	MOVLW 	0xCB		; cursor to 12 place in 2nd string
	CALL 	WRT_LCD_INSTR
	MOVLW	0x20		; " "
	BTFSC	T_SET, 7h 	; if subzerro temperature
	MOVLW	0x2D		; "-"
	CALL 	WRT_LCD_DATA	; show " " or "-"
	MOVF	T_SET,0		; convert to DEC
	CALL	HEX_DEC
	MOVF	DEC_H,0		; tens digit of DEC
	ADDLW	0x30		
	CALL 	WRT_LCD_DATA
	MOVF	DEC_L,0		; unit digit of DEC
	ADDLW	0x30		
	CALL 	WRT_LCD_DATA
	MOVLW 	0xDF 		; "°"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x43 		; "C"
	CALL 	WRT_LCD_DATA
	return

;------------ Show measured temperatures to LCD -----------------
T_ON_LCD	
	; outdoor temperature
	MOVLW 	0xC0		; cursor to 1 place in 2nd string
	CALL 	WRT_LCD_INSTR
	MOVLW	0x20		; " "
	BTFSC	T_OUT, 7h 	; if subzerro temperature
	MOVLW	0x2D		; "-"
	CALL 	WRT_LCD_DATA	; show " " or "-"
	MOVF	T_OUT,0		; convert to DEC
	CALL	HEX_DEC	
	MOVF	DEC_H,0		; tens digit of DEC
	ADDLW	0x30		
	CALL 	WRT_LCD_DATA
	MOVF	DEC_L,0		; units digit of DEC
	ADDLW	0x30		
	CALL 	WRT_LCD_DATA
	MOVLW 	0xDF 		; "°"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x43 		;"C"
	CALL 	WRT_LCD_DATA
	; heater air temperature
	MOVLW 	0xC6		; cursor to 7 place in 2nd string
	CALL 	WRT_LCD_INSTR
	MOVLW	0x20		; " "
	BTFSC	T_AIR, 7h 	; if subzerro temperature
	MOVLW	0x2D		; "-"
	CALL 	WRT_LCD_DATA	; show " " or "-"
	MOVF	T_AIR,0		; convert to DEC
	CALL	HEX_DEC
	MOVF	DEC_H,0		; tens digit of DEC
	ADDLW	0x30		
	CALL 	WRT_LCD_DATA
	MOVF	DEC_L,0		; units digit of DEC
	ADDLW	0x30		
	CALL 	WRT_LCD_DATA
	MOVLW 	0xDF 		; "°"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x43 		; "C"
	CALL 	WRT_LCD_DATA
	RETURN

;------ sleep mode -----------
SYSTEM_SLEEP
	BCF	OUT_ST,VL	; close valve (status) 
	BCF	PORTB,V		; close valve (port) 
	BCF	OUT_ST, MOD	; status heat system off
	call	OUT_ST_WR_EEPROM; save to EEPROM

	; show Heat System Off on LCD
	MOVLW 	b'00000001' 	; clear LCD
	CALL	WRT_LCD_INSTR
	MOVLW 	82h		; cursor to 3rd place in 1st string
	CALL 	WRT_LCD_INSTR
	MOVLW 	0x48 		;"H"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x65 		;"e"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x61 		;"a"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x74 		;"t"
	CALL 	WRT_LCD_DATA
	MOVLW 	88h		; cursor to 9 place in 1st string
	CALL 	WRT_LCD_INSTR
	MOVLW 	0x53 		;"S"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x79 		;"y"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x73 		;"s"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x74 		;"t"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x65 		;"e"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x6D 		;"m"
	CALL 	WRT_LCD_DATA
	MOVLW 	0xC6		; cursor to 7 place in 2nd string
	CALL 	WRT_LCD_INSTR
	MOVLW 	0x4F 		;"O"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x66 		;"f"
	CALL 	WRT_LCD_DATA
	MOVLW 	0x66 		;"f"
	CALL 	WRT_LCD_DATA
SLEEP_MORE:
	CLRWDT
	CLRF	KEY_ST		; clear keys status
	BTFSS	PORTA, 3h 	; pead port and set flags
	BSF	KEY_ST, D
	BTFSS	PORTA, 2h 
	BSF	KEY_ST, U

	INCF	KEY_ST,1	; if no keys pressed
	DECFSZ	KEY_ST,1
	GOTO	SLEEP_DRIGLING
	GOTO	SLEEP_MORE
SLEEP_DRIGLING:
	MOVLW	.20
	CALL 	DELAY_mS	; wait 20mS
	BTFSC	PORTA, 3h 	; clear false flags caused by bounce noice of keys
	BCF	KEY_ST, D
	BTFSC	PORTA, 2h 
	BCF	KEY_ST, U

	INCF	KEY_ST,1	; if no keys pressed
	DECFSZ	KEY_ST,1
	GOTO	WAKE_UP
	GOTO	SLEEP_MORE
WAKE_UP:
	CLRWDT			
	MOVF	PORTA,0		; wait till key will be released
	ANDLW	b'11100'	; mask for keys
	SUBLW	b'11101'
	MOVWF	W_STOCK
	DECFSZ	W_STOCK,1
	GOTO	WAKE_UP
; wake up processes
	BSF	OUT_ST, MOD		; temperature management mode
	call	OUT_ST_WR_EEPROM	; save system status to EPPROM
	call	HEADER_LCD		; show 1st string on LCD
	call	T_SET_ON_LCD		; show desired temperature
	RETURN

;------ Temperature comparation and valve management -------------
VALVE
		MOVF	T_SET,0		; get desired temperature from  W
		SUBWF	T_AIR,0		; F-W  ->  W
		MOVWF	W_STOCK	
		INCF	W_STOCK,1	;
		DECFSZ	W_STOCK,1	; check T_SET=T_AIR
		GOTO	CHANGE_V
		GOTO	VL_RETURN	; ==, no action needed
CHANGE_V:
		BTFSC	W_STOCK,7	; if oldest bit = 1 this is negative number
		GOTO	HEATING
		BCF	OUT_ST,VL	; close valve(status)
		BCF	PORTB,V		; close valve(port)	
		GOTO	VL_RETURN
HEATING:
		BSF	OUT_ST,VL	; open valve(status)
		BSF	PORTB,V		; open valve(port)	
VL_RETURN:
		RETURN

;--------------Запись в LCD команды-------------------------
WRT_LCD_INSTR				;в W - инструкция для ЖКИ
		MOVWF	RW_STOCK	;инструкцию из аккумулятора в RW_STOCK
		ANDLW	b'11110000' 	;выделяем СТАРШИЙ ПОЛУБАЙТ инструкции
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1		;добавляем его сигнал управления
		MOVWF	PORTB		;кидаем в порт В
		BSF	PORTB,E		;старт записи
		BCF	PORTB,E		;конец отсылки старшего полубайта
		SWAPF   RW_STOCK,1 	;меняем местами старш-младш полубайты
		MOVF	RW_STOCK,0	;достаем развернутую инструкцию в аккумулятор
		ANDLW	b'11110000' 	;выделяем СТАРШИЙ(изначально МЛАДШИЙ) ПОЛУБАЙТ
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1		;добавляем его сигнал управления	
		MOVWF	PORTB		;кидаем в порт В
		BSF	PORTB,E		;старт записи
		BCF	PORTB,E		;конец отсылки младшего полубайта
		CALL	BUSY_LCD	;ждем готовность ЖКИ
		RETURN

;--------------Запись в LCD данных-------------------------
WRT_LCD_DATA				;в W - данные для ЖКИ
		MOVWF	RW_STOCK	;данные из аккумулятора в RW_STOCK
		ANDLW	b'11110000' 	;выделяем СТАРШИЙ ПОЛУБАЙТ 
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1		;добавляем его сигнал управления	
		MOVWF	PORTB		;кидаем в порт В
		BSF	PORTB,RS    	;добавляем управляющий сигнал "запись данных" 
		BSF	PORTB,E		;старт записи
		BCF	PORTB,E		;конец отсылки старшего полубайта
		SWAPF   RW_STOCK,1 	;меняем местами старш-младш полубайты
		MOVF	RW_STOCK,0	;достаем развернутую инструкцию в аккумулятор
		ANDLW	b'11110000' 	;выделяем СТАРШИЙ(изначально МЛАДШИЙ) ПОЛУБАЙТ
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1		;добавляем его сигнал управления	
		MOVWF	PORTB		;кидаем в порт В
		BSF	PORTB,RS    	;добавляем управляющий сигнал "запись данных" 
		BSF	PORTB,E		;старт записи
		BCF	PORTB,E		;конец отсылки младшего полубайта
		CALL	BUSY_LCD	;ждем готовность ЖКИ
		RETURN

;-------------Ожидание готовности LCD----------------------
BUSY_LCD
		MOVLW	.2
 		CALL	DELAY_mS
		RETURN

;--------преобразование HEX to DEC ---------------
HEX_DEC	;также отрицательное преобразует в положительное
		MOVWF	HEX 		;"-" следует отслеживать вне подпрограммы
		BTFSS	HEX, 7h 	;если стр разр=0 - темп полож
		GOTO	DECIMALING
		XORLW	0xFF		;извлечение модуля из негативного значения
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

;--------Процедуры однопроводного интерфейса-----------------------------------
T0_HIZ	;-------------Установка вывода 1-го датчика в состояние высокого импеданса 
        BSF     STATUS,RP0	;Выбор банка 1
        BSF     TRISA,T0	;установка вывода как вход (высокий импеданс)
	BCF     STATUS,RP0	;Выбор банка 0
	RETURN	
T1_HIZ	;-------------Установка вывода 2-го датчика в состояние высокого импеданса 
        BSF     STATUS,RP0	;Выбор банка 1
        BSF     TRISA,T1	;установка вывода как вход (высокий импеданс)
	BCF     STATUS,RP0	;Выбор банка 0
	RETURN	
T0_LO	;-------------Установка вывода 1-го датчика в 0
	BCF	PORTA,T0	;Записываем 0 
	BSF     STATUS,RP0	;Выбор банка 1
        BCF     TRISA,T0	;установка вывода как выход
	BCF     STATUS,RP0	;Выбор банка 0
	RETURN
T1_LO	;-------------Установка вывода 2-го датчика в 0
	BCF	PORTA,T1	;Записываем 0 
	BSF     STATUS,RP0	;Выбор банка 1
        BCF     TRISA,T1	;установка вывода как выход
	BCF     STATUS,RP0	;Выбор банка 0
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
T0_WRITE	;---------Вывод команды на темпер. датчик 1----
		MOVWF	T_STOCK	;передаваемый байт
		MOVLW	.8
		MOVWF	COUNT		;счетчик битов
T0_WLOOP:
		CALL	T0_LO		; --> 0
		RRF		T_STOCK,1	;сдвигаем через Carry Flag
		BSF		STATUS,RP0	;Выбор банка 1
		BTFSC	STATUS,C	;проверяем Carry Flag
		BSF		TRISA,T0	;HIZ если 1
		BCF     STATUS,RP0	;Выбор банка 0
		MOVLW	.6
		CALL	DELAY_x10mkS;задержка 64 мкс
		CALL	T0_HIZ		; --> 1
		DECFSZ	COUNT,1
		GOTO	T0_WLOOP
		RETURN	
T1_WRITE	;---------Вывод команды на темпер. датчик 2----
		MOVWF	T_STOCK	;передаваемый байт
		MOVLW	.8
		MOVWF	COUNT		;счетчик битов
T1_WLOOP:
		CALL	T1_LO		; --> 0
		RRF		T_STOCK,1	;сдвигаем через Carry Flag
		BSF		STATUS,RP0	;Выбор банка 1
		BTFSC	STATUS,C	;проверяем Carry Flag
		BSF		TRISA,T1	;HIZ если 1
		BCF     STATUS,RP0	;Выбор банка 0
		MOVLW	.6
		CALL	DELAY_x10mkS;задержка 64 мкс
		CALL	T1_HIZ		; --> 1
		DECFSZ	COUNT,1
		GOTO	T1_WLOOP
		RETURN	
	
T0_READ		;--------Чтение 1-го датч темпер ------
		MOVLW	.9		;циклов будет на 1 больше, т.к. в 0 бите - дробное значение температуры, мы его пропустим
		MOVWF	COUNT		;счетчик битов
T0_RLOOP:
		CALL	T0_LO		; --> 0
		CALL	T0_HIZ		; --> 1
		NOP					
		NOP
		MOVF	PORTA,0		;читаем бит
		ANDLW	b'00000001'	;маска
		ADDLW	.255		;если прочли 1 будет переполнение
		RRF		T_STOCK,1	;задвигаем флар переполнения в переменную
		MOVLW	.5
		CALL	DELAY_x10mkS;задержка 54 мкс	
		DECFSZ	COUNT,1
		GOTO	T0_RLOOP
		MOVF	T_STOCK,0	
		RETURN

T1_READ		;--------Чтение 2-го датч темпер ------
		MOVLW	.9		;циклов будет на 1 больше, т.к. в 0 бите - дробное значение температуры, мы его пропустим
		MOVWF	COUNT		;счетчик битов
T1_RLOOP:
		CALL	T1_LO		; --> 0
		CALL	T1_HIZ		; --> 1
		NOP					
		NOP
		MOVF	PORTA,0		;читаем бит
		ANDLW	b'00000010'	;маска
		ADDLW	.255		;если прочли 1 будет переполнение
		RRF	T_STOCK,1	;задвигаем флар переполнения в переменную
		MOVLW	.5
		CALL	DELAY_x10mkS	;задержка 54 мкс	
		DECFSZ	COUNT,1
		GOTO	T1_RLOOP
		MOVF	T_STOCK,0	
		RETURN

;--------T_SET_store in EEPROM_write--------------
T_SET_WR_EEPROM
		BCF	STATUS, RP0 ; Bank 0
		MOVFW	T_SET		;WE WILL WRITE SET TEMPR TO EEPROM
		MOVWF	EEDATA		;WRITING DATA W-->EEDATA REG
		MOVLW	0x00
		MOVWF	EEADR		; WRITE Address 
		call	EEPROM_WR_SEQ	; write T_SET in 0x01 EEPROM
		return

;------- Запоминание состояния системы -----------
OUT_ST_WR_EEPROM
		BCF	STATUS, RP0 ; Bank 0
		MOVFW	OUT_ST		;WE WILL WRITE OUT_ST TO EEPROM
		MOVWF	EEDATA		;WRITING DATA W-->EEDATA REG
		MOVLW	0x01
		MOVWF	EEADR		; WRITE Address 
		call	EEPROM_WR_SEQ	; write T_SET in 0x01 EEPROM
		return

;--------- EEPROM_write standard sequence ---------
EEPROM_WR_SEQ
		BSF	STATUS, RP0 	; Bank 1
		BCF	INTCON, GIE 	; Disable INTs.
		BSF	EECON1, WREN 	; Enable Write
		MOVLW	55h
		MOVWF	EECON2 		; Write 55h
		MOVLW	0xAA
		MOVWF	EECON2 		; Write AAh
		BSF	EECON1,WR ; Set WR bit
		; begin write
		BSF	INTCON, GIE 	; Enable INTs.
		movlw	.15		
		call	DELAY_mS	;wait till write process finish
		BCF	STATUS, RP0 	; Bank 0
		return

;--------T_SET read from EEPROM--------------
T_SET_RD_EEPROM
		BCF	STATUS, RP0 	; Bank 0
		MOVLW	0x00		;Address to read
		MOVWF	EEADR		; Address to read
		BSF	STATUS, RP0	; Bank 1
		BSF	EECON1, RD	; EE Read
		BCF	STATUS, RP0	; Bank 0
		MOVF	EEDATA, 0	; W = EEDATA
		BCF	STATUS, RP0 	; Bank 0
		MOVWF	T_SET		; save in T_SET
		RETURN

;--------OUT_ST read from EEPROM--------------
OUT_ST_RD_EEPROM
		BCF	STATUS, RP0 	; Bank 0
		MOVLW	0x01		; Address to read
		MOVWF	EEADR		; Address to read
		BSF	STATUS, RP0	; Bank 1
		BSF	EECON1, RD	; EE Read
		BCF	STATUS, RP0	; Bank 0
		MOVF	EEDATA, 0	; W = EEDATA
		BCF	STATUS, RP0 	; Bank 0
		MOVWF	OUT_ST		; save in OUT_ST
		RETURN

;--------Задержка 1...255 мс----------------------------------------------------
DELAY_mS ;в W находится время задержки в мс
        MOVWF 	COUNT1
	NOP
	NOP
OUTTER:
	MOVLW   .111      ; Задержка 1 мс
        MOVWF   COUNT2
INNER:
        NOP ; Задержка 1 мс
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
;--------Задержка 14...2554 мкс-------------------------------
DELAY_x10mkS:   ;Задержка определяется как W*10+4 мкс (14mkS- 2554mkS)
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
