#include <p16F84a.inc>
LIST   P=PIC16F84A
__CONFIG _CP_OFF & _WDT_OFF & _XT_OSC

;------------Регистры ввода/вывода-------------------
; PORTA		EQU     05h	;KEY and TERMOMETERS, bits:
T0			EQU		0h	;первый датчик температуры
T1			EQU		1h	;второй датчик температуры
						;2h..4h - кнопки
; PORTB		EQU     06h	; LCD port, bits:
BF			EQU		7h	;"занято". 7h-4h - шина данных
E			EQU		3h	;Старт чтения.записи
RW			EQU		2h	;1-читать/0-записать
RS			EQU		1h	;1-данные/0-инструкции
V			EQU		0h  ;выход управления клапаном

;-------------ячейки ОЗУ--------------------------------
		CBLOCK  0CH
COUNT		;счетчик битов в/в термометра
COUNT1		;счетчик п/п задержки
COUNT2		;счетчик п/п задержки
COUNT3		;счетчик1 для определения длинного нажания кнопки
COUNT4		;счетчик2 для определения длинного нажания кнопки
W_STOCK		;рабочая переменная п/п обработки сост клавиш и анализа темпер.
T_STOCK		;рабочая переменная п/п общения с термометром
RW_STOCK	;рабочая переменная п/п управления ЖКИ
HEX			;переменная HEX которая потом пересч в DEC
DEC_H		;десятки пересчитано из HEX
DEC_L		;единицы пересчитано из HEX
T_OUT		;температурa OUT HEX
T_AIR		;температурa AIR HEX
T_SET		;температурa SET HEX
COUNT_750	;счетчик для времени конверсии 750мс
COUNT_750_M	;счетчик для времени конверсии 750мс внешний
KEY_ST		;Статусы кнопок,
OUT_ST		;Статусы клапана и управления
		endc

;----- KEY_ST bits -----------------------------------
M			EQU		7h	;длинное нажатие любой кнопки
D			EQU		6h	;нажатие кнопки DOUN
U			EQU		5h	;нажатие кнопки UP

; ----- OUT_ST bits ----------------------------------
VL			EQU		7h	;1-клапан открыт/0-закрыт
MOD			EQU		0h	;режим:1-контроль температуры/0-печка выключена

;--------Константы-------------------
#DEFINE		T_MAX	.40	;40'C верхняя граница предустаноки температуры
#DEFINE		T_MIN	.10	;10'C нижняя граница предустаноки температуры

;----------начало исполняемого кода---------------------
        ORG     0
BEGIN:					;----Инициализации всякие-------
		MOVLW	.1
		MOVWF	COUNT_750 	;счетчик задержки для конверсии температуры
		MOVWF	COUNT_750_M	;счетчик задержки для конверсии температуры внешний
		CLRF	KEY_ST		;ничего не нажато
		CALL	INIT_A		;инициализация порта А-на ввод
		CALL	INIT_B		;инициализация порта В-на вывод
		CALL	INIT_LCD	;инициализация ЖКИ 16х2, 4-bit
		CALL	HEADER_LCD	;вывод на ЖКИ первой неизменяемой сроки
		call	T_SET_RD_EEPROM;читаем T_SET из EEPROM
		call	T_SET_ON_LCD;oтображаем T_SET
		call	OUT_ST_RD_EEPROM;читаем OUT_ST
		bcf		OUT_ST,VL
		btfss	OUT_ST,MOD	;усли в прошлый раз выключились в слип моде-идем туда
		call	SYSTEM_SLEEP
HANG:					;----Начало основного тела-------
		CALL	TERMOMETR	;измерение температур
		CALL	KEYS		;опрос клавиатуры
		CALL	VALVE		;анализ температур и управление клапаном
		CLRWDT
		GOTO	HANG

;--------------Инициализация порта A-------------------------------
INIT_A
; внимание!! нужно включить подтягивающие резисторы!!
		BCF     STATUS,RP0    ;Выбор банка 0
        CLRF    PORTA        ;Очистить регистр DATAPORT
    	MOVLW   b'11111'  	 ;Загpузить B'11111' в pегистp W
        BSF     STATUS,RP0    ;Выбор банка 1
        MOVWF   TRISA        ;-входы
		BCF     STATUS,RP0    ;Выбор банка 0
		RETURN	
;--------------Инициализация порта В -----------------------------
INIT_B
		BCF     STATUS,RP0	;Выбор банка 0
;      	MOVLW	b'00000001'	;Очищаем регистр порта В, но
;		ANDWF	PORTB,1		;сигнал управления клапаном не трогаем
		clrf	PORTB		;Очищаем регистр порта В
	   	MOVLW   b'00000000'   ;Загpузить B'00000000' в pегистp W
        BSF     STATUS,RP0    ;Выбор банка 1
        MOVWF   TRISB        ;Все разряды установить как выходы 
		BCF     STATUS,RP0    ;Выбор банка 0
		RETURN
;--------------ИНИЦИАЛИЗАЦИЯ LCD-----------------------------------
INIT_LCD			;Инициализация LCD
		MOVLW	.100
 		CALL	DELAY_mS ;Ждем старта ЖКИ

		MOVLW	b'00110000'		;Function set(Interface is 8-bit long)
		MOVWF	PORTB
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E	
		MOVLW	.5
 		CALL	DELAY_mS ;Ждем

		MOVLW	b'00110000'		;Function set(Interface is 8-bit long)
		MOVWF	PORTB
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E	
		MOVLW	.100
 		CALL	DELAY_mS ;Ждем

		MOVLW	b'00110000'		;Function set(Interface is 8-bit long)
		MOVWF	PORTB
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E	
		CALL	BUSY_LCD	;Ждем готовности

		MOVLW	b'00100000'		;устанавливаем 4-битный режим
		MOVWF	PORTB
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E	
		CALL	BUSY_LCD	;Ждем готовности
		MOVLW 	b'00101000'	; уст.4-бит работу и 2 линии 5х8
		CALL	WRT_LCD_INSTR
		MOVLW 	b'00001100' ;включаем дисплей и курсор не показывать
		CALL	WRT_LCD_INSTR
		MOVLW 	b'00000001' ;Очистить дисплей
		CALL	WRT_LCD_INSTR
		MOVLW 	b'00000110' ; Режим ввода.Инкремент адреса,
		CALL	WRT_LCD_INSTR
		RETURN
;--------HEADER_LCD-----------------------------
HEADER_LCD

;' Вне  Поток  Уст'
		MOVLW 	b'00000001' ;Очистить дисплей
		CALL	WRT_LCD_INSTR
		MOVLW 	81h			;курсор в 2поз. 1-й строки
		CALL WRT_LCD_INSTR
		MOVLW 	0x42 		;"В"
		CALL WRT_LCD_DATA
		MOVLW 	0xBD 		;"н"
		CALL WRT_LCD_DATA
		MOVLW 	0x65 		;"е"
		CALL WRT_LCD_DATA
		MOVLW 	86h			;курсор в 7поз. 1-й строки
		CALL WRT_LCD_INSTR
		MOVLW 	0xA8 		;"П"
		CALL WRT_LCD_DATA
		MOVLW 	0x6F 		;"o"
		CALL WRT_LCD_DATA
		MOVLW 	0xBF 		;"т"
		CALL WRT_LCD_DATA
		MOVLW 	0x6F 		;"o"
		CALL WRT_LCD_DATA
		MOVLW 	0xBA 		;"k"
		CALL WRT_LCD_DATA

		MOVLW 	8Dh			;курсор в 14поз. 1-й строки
		CALL WRT_LCD_INSTR
		MOVLW 	0xA9 		;"У"
		CALL WRT_LCD_DATA
		MOVLW 	0x63 		;"с"
		CALL WRT_LCD_DATA
		MOVLW 	0xBF 		;"т"
		CALL WRT_LCD_DATA

		return
;--------Опрос датчиков температуры----------------------
TERMOMETR
		DECFSZ	COUNT_750	
		GOTO	TERM_END
		DECFSZ	COUNT_750_M
		GOTO	TERM_END		;--если время конверсии не прошло - пропускаем всю п/п

TERM_READ:;--------Старт чтения температуры--------------
		CALL	T0_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T0_WRITE
		MOVLW	0xBE		;Read scrachpad comand
		CALL	T0_WRITE	;
		CALL	T0_READ		;в W находится температура
		MOVWF	T_AIR
		CALL	T1_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T1_WRITE
		MOVLW	0xBE		;Read scrachpad comand
		CALL	T1_WRITE
		CALL	T1_READ		;в W находится температура
		MOVWF	T_OUT		
		CALL	T_ON_LCD	;Отображаем изменения
		;---------Старт конверсии температуры-----------
		CALL	T0_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T0_WRITE
		MOVLW	0x44		;Start convertion comand
		CALL	T0_WRITE	;нужно не позже чем через 10 мкс подать паразитное питание.удерживать 750 мс
        BSF		PORTA,T0	;установить 1 в регистре в/в для вывода Т0
        BSF     STATUS,RP0	;Выбор банка 1
		BCF		TRISA,T0	;переключить вывод Т0 на вывод
		BCF     STATUS,RP0	;вернуть адресацию банка 0

		CALL	T1_RESET	;Reset
		MOVLW	0xCC		;skip ROM comand
		CALL	T1_WRITE
		MOVLW	0x44		;Start convertion comand
		CALL	T1_WRITE	;нужно не позже чем через 10 мкс подать паразитное питание.удерживать 750 мс
        BSF		PORTA,T1	;установить 1 в регистре в/в для вывода Т1
        BSF     STATUS,RP0	;Выбор банка 1
		BCF		TRISA,T1	;переключить вывод Т1 на вывод
		BCF     STATUS,RP0	;вернуть адресацию банка 0
		
		MOVLW	.74		;Начало отсчета задержки
		MOVWF	COUNT_750_M
TERM_END:
		RETURN

;--------Опрос клавиатуры-----------------------------------
KEYS
		CLRF	KEY_ST		;обнуляем статусы клавиш
		CLRF	COUNT3		;онуляем счетчики длинного нажатия
		CLRF	COUNT4

		BTFSS	PORTA, 3h 	;читаем порт и выставляем флаги
		BSF	    KEY_ST, D
		BTFSS	PORTA, 2h 
		BSF	    KEY_ST, U
		INCF	KEY_ST,1	;если не нажата ни одна клавиша-конец п/п
		DECFSZ	KEY_ST,1
		GOTO	DRIGLING
		GOTO	KEY_M1
DRIGLING:
		MOVLW	.20
		CALL 	DELAY_mS	;ждем 20mS
		BTFSC	PORTA, 3h 	;обнуляем ложные флаги(дребезг)
		BCF	    KEY_ST, D
		BTFSC	PORTA, 2h 
		BCF	    KEY_ST, U
EXIT3:
		DECFSZ	COUNT3		;считае как долго держат кнопку
		GOTO	KEY_M2
		DECFSZ	COUNT4
		GOTO	KEY_M2
		CLRF	KEY_ST		;если кнопка нажата дольше 760мс
		BSF	    KEY_ST,M	
		
KEY_M2:
		CLRWDT
		MOVF	PORTA,0	;ждем когда отпустят все клавиши
		ANDLW	b'11100'	;маска на клавиши
		SUBLW	b'11101'
		MOVWF	W_STOCK
		DECFSZ	W_STOCK,1
		GOTO	EXIT3
		call	T_SET_RECALC	;персчитываем T_SET согласно нажатому
		call	T_SET_ON_LCD	;Отображаем изменения T_SET

		;анализируем изменение режимов
		BTFSS	KEY_ST,M
		GOTO	KEY_M1		;если не было долгого нажатия уходим
		CALL	SYSTEM_SLEEP	;если долго нажата любая клавиша
		CLRF	KEY_ST		;обнуляем статусы клавиш
KEY_M1:		
		RETURN

;------------- T_SET_recalculation -----------
T_SET_RECALC
		;анализируем изменение опорной температуры
		BTFSC	KEY_ST, U	;если была нажата клавиша-изменяяем T_SET
		INCF	T_SET,1
		BTFSC	KEY_ST, D
		DECF	T_SET,1
        ;проверяем достижение граничных значений
		MOVF	T_SET,0		;If T_SET>max then T_SET-1
		SUBLW	T_MAX		;верхнее граничное опорной температуры
		MOVWF	W_STOCK
		BTFSC	W_STOCK,7h
		DECF	T_SET,1		;если перевалили, возвращаем границу

		MOVF	T_SET,0		;If T_SET<min then T_SET+1
		SUBLW	T_MIN		;нижнее граничное опорной температуры
		MOVWF	W_STOCK
		DECF	W_STOCK,1
		BTFSS	W_STOCK,7h
		INCF	T_SET,1		;если перевалили, возвращаем границу

		call	T_SET_WR_EEPROM
		return

;---------- вывод T_SET на LCD ----------------
T_SET_ON_LCD
;вывод установленной температуры
		MOVLW 	0xCC		;курсор в 13поз. 2-й строки
		CALL WRT_LCD_INSTR
		MOVLW	0x20		;пробел
		BTFSC	T_SET, 7h 	;если ст раз=1 - темпер отр.
		MOVLW	0x2D		;выведем "-"
		CALL WRT_LCD_DATA	;выводим пробел или "-"
		MOVF	T_SET,0		;преобразуем к десятичному виду
		CALL	HEX_DEC
		MOVF	DEC_H,0
		ADDLW	0x30		;координаты цифры
		CALL WRT_LCD_DATA
		MOVF	DEC_L,0
		ADDLW	0x30		;координаты цифры
		CALL WRT_LCD_DATA
		MOVLW 	0xDF 		;значек градуса
		CALL WRT_LCD_DATA
;		MOVLW 	0x63 		;"c"
;		CALL WRT_LCD_DATA
		return

;------------ вывод измеренных температур на LC-----------------
T_ON_LCD	
;вывод внешней температуры
		MOVLW 	0xC0		;курсор в 1поз. 2-й строки
		CALL WRT_LCD_INSTR
		MOVLW	0x20		;пробел 
		BTFSC	T_OUT, 7h 	;если ст раз=1 - темпер отр.
		MOVLW	0x2D		;выведем "-"
		CALL WRT_LCD_DATA	;выводим пробел или "-"
		MOVF	T_OUT,0		;преобразуем к десятичному виду
		CALL	HEX_DEC	
		MOVF	DEC_H,0		;десятки
		ADDLW	0x30		;координаты цифры
		CALL WRT_LCD_DATA
		MOVF	DEC_L,0		;единицы
		ADDLW	0x30		;координаты цифры
		CALL WRT_LCD_DATA
		MOVLW 	0xDF 		;значек градуса
		CALL WRT_LCD_DATA
		MOVLW 	0x63 		;"c"
		CALL WRT_LCD_DATA
;вывод температуры обдува
		MOVLW 	0xC6		;курсор в 7поз. 2-й строки
		CALL WRT_LCD_INSTR
		MOVLW	0x20		;пробел
		BTFSC	T_AIR, 7h 	;если ст раз=1 - темпер отр.
		MOVLW	0x2D		;выведем "-"
		CALL WRT_LCD_DATA	;выводим пробел или "-"
		MOVF	T_AIR,0		;преобразуем к десятичному виду
		CALL	HEX_DEC
		MOVF	DEC_H,0
		ADDLW	0x30		;координаты цифры
		CALL WRT_LCD_DATA
		MOVF	DEC_L,0
		ADDLW	0x30		;координаты цифры
		CALL WRT_LCD_DATA
		MOVLW 	0xDF 		;значек градуса
		CALL WRT_LCD_DATA
		MOVLW 	0x63 		;"c"
		CALL WRT_LCD_DATA
		RETURN

;------Режим выключенной системы-----------
SYSTEM_SLEEP
		BCF		OUT_ST,VL	;отключаем клапан(статус)
		BCF		PORTB,V		;отключаем клапан(порт)	
		BCF		OUT_ST, MOD	;режим - heat system off
		call	OUT_ST_WR_EEPROM;запис в EEPROM состояние системы

;   Отопитель   ' 
;    Выключен   '

		MOVLW 	b'00000001' ;Очистить дисплей
		CALL	WRT_LCD_INSTR
		MOVLW 	83h			;курсор в 4поз. 1-й строки
		CALL WRT_LCD_INSTR
		MOVLW 	0x4F 		;"O"
		CALL WRT_LCD_DATA
		MOVLW 	0xBF 		;"т"
		CALL WRT_LCD_DATA
		MOVLW 	0x6F 		;"o"
		CALL WRT_LCD_DATA
		MOVLW 	0xBE 		;"п"
		CALL WRT_LCD_DATA
		MOVLW 	0xB8 		;"и"
		CALL WRT_LCD_DATA
		MOVLW 	0xBF 		;"т"
		CALL WRT_LCD_DATA
		MOVLW 	0x65 		;"е"
		CALL WRT_LCD_DATA
		MOVLW 	0xBB 		;"л"
		CALL WRT_LCD_DATA
		MOVLW 	0xC4 		;"ь"
		CALL WRT_LCD_DATA

		MOVLW 	0xC5		;курсор в 6поз. 2-й строки
		CALL WRT_LCD_INSTR
		MOVLW 	0x42 		;"В"
		CALL WRT_LCD_DATA
		MOVLW 	0xC3 		;"ы"
		CALL WRT_LCD_DATA
		MOVLW 	0xBA 		;"к"
		CALL WRT_LCD_DATA
		MOVLW 	0xBB 		;"л"
		CALL WRT_LCD_DATA
		MOVLW 	0xC6 		;"ю"
		CALL WRT_LCD_DATA
		MOVLW 	0xC0 		;"ч"
		CALL WRT_LCD_DATA
		MOVLW 	0x65 		;"е"
		CALL WRT_LCD_DATA
		MOVLW 	0xBD 		;"н"
		CALL WRT_LCD_DATA

SLEEP_MORE:
		CLRWDT
		CLRF	KEY_ST		;обнуляем статусы клавиш
		BTFSS	PORTA, 3h 	;читаем порт и выставляем флаги
		BSF	    KEY_ST, D
		BTFSS	PORTA, 2h 
		BSF	    KEY_ST, U

		INCF	KEY_ST,1	;если не нажата ни одна клавиша-
		DECFSZ	KEY_ST,1
		GOTO	SLEEP_DRIGLING
		GOTO	SLEEP_MORE
SLEEP_DRIGLING:
		MOVLW	.20
		CALL 	DELAY_mS	;ждем 20mS
		BTFSC	PORTA, 3h 	;обнуляем ложные флаги(дребезг)
		BCF	    KEY_ST, D
		BTFSC	PORTA, 2h 
		BCF	    KEY_ST, U

		INCF	KEY_ST,1	;если не нажата ни одна клавиша-
		DECFSZ	KEY_ST,1
		GOTO	WAKE_UP
		GOTO	SLEEP_MORE
WAKE_UP:
		CLRWDT			
		MOVF	PORTA,0	;нужно подождать когда отпустят клавишу
		ANDLW	b'11100'	;маска на клавиши
		SUBLW	b'11101'
		MOVWF	W_STOCK
		DECFSZ	W_STOCK,1
		GOTO	WAKE_UP
; wake up processes
		BSF		OUT_ST, MOD		;режим - контроль температуры
		call	OUT_ST_WR_EEPROM;запис в EEPROM состояние системы
		call	HEADER_LCD		;отобр первой стр. ЖКИ
		call	T_SET_ON_LCD	;отобр T_SET
		RETURN

;------Анализ температур и управление клапаном-------------
VALVE
		MOVF	T_SET,0		;достаем опорную темп в W
		SUBWF	T_AIR,0		;F-W  ->  W
		MOVWF	W_STOCK	
		INCF	W_STOCK,1	;
		DECFSZ	W_STOCK,1	; проверяем условие T_SET=T_AIR
		GOTO	CHANGE_V
		GOTO	VL_RETURN	;температуры ==,ничего не меняем
CHANGE_V:
		BTFSC	W_STOCK,7	;если в старш бите 1 -все число отриц
		GOTO	HEATING
		BCF		OUT_ST,VL	;отключаем клапан(статус)
		BCF		PORTB,V		;отключаем клапан(порт)		
		GOTO	VL_RETURN
HEATING:
		BSF		OUT_ST,VL	;включаем клапан(статус)
		BSF		PORTB,V		;включаем клапан(порт)		
VL_RETURN:
		RETURN

;--------------Запись в LCD команды-------------------------
WRT_LCD_INSTR				;в W - инструкция для ЖКИ
		MOVWF	RW_STOCK	;инструкцию из аккумулятора в RW_STOCK
		ANDLW	b'11110000' ;выделяем СТАРШИЙ ПОЛУБАЙТ инструкции
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1			;добавляем его сигнал управления
		MOVWF	PORTB		;кидаем в порт В
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E		;конец отсылки старшего полубайта
		SWAPF   RW_STOCK,1 	;меняем местами старш-младш полубайты
		MOVF	RW_STOCK,0	;достаем развернутую инструкцию в аккумулятор
		ANDLW	b'11110000' ;выделяем СТАРШИЙ(изначально МЛАДШИЙ) ПОЛУБАЙТ
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1			;добавляем его сигнал управления	
		MOVWF	PORTB		;кидаем в порт В
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E		;конец отсылки младшего полубайта
		CALL	BUSY_LCD	;ждем готовность ЖКИ
		RETURN

;--------------Запись в LCD данных-------------------------
WRT_LCD_DATA				;в W - данные для ЖКИ
		MOVWF	RW_STOCK	;данные из аккумулятора в RW_STOCK
		ANDLW	b'11110000' ;выделяем СТАРШИЙ ПОЛУБАЙТ 
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1			;добавляем его сигнал управления	
		MOVWF	PORTB		;кидаем в порт В
		BSF		PORTB,RS    ;добавляем управляющий сигнал "запись данных" 
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E		;конец отсылки старшего полубайта
		SWAPF   RW_STOCK,1 	;меняем местами старш-младш полубайты
		MOVF	RW_STOCK,0	;достаем развернутую инструкцию в аккумулятор
		ANDLW	b'11110000' ;выделяем СТАРШИЙ(изначально МЛАДШИЙ) ПОЛУБАЙТ
		BTFSC	OUT_ST,VL	;если клапан д.б.включен
		ADDLW	1			;добавляем его сигнал управления	
		MOVWF	PORTB		;кидаем в порт В
		BSF		PORTB,RS    ;добавляем управляющий сигнал "запись данных" 
		BSF		PORTB,E		;старт записи
		BCF		PORTB,E		;конец отсылки младшего полубайта
		CALL	BUSY_LCD	;ждем готовность ЖКИ
		RETURN

;-------------Ожидание готовности LCD----------------------
BUSY_LCD
		MOVLW	.2
 		CALL	DELAY_mS
		RETURN

;--------преобразование HEX to DEC ---------------
HEX_DEC	;также отрицательное преобразует в положительное
		MOVWF	HEX ;"-" следует отслеживать вне подпрограммы
		BTFSS	HEX, 7h ;если стр разр=0 - темп полож
		GOTO	DECIMALING
		XORLW	0xFF	;извлечение модуля из негативного значения
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
		BCF		PORTA,T0	;Записываем 0 
		BSF     STATUS,RP0	;Выбор банка 1
        BCF     TRISA,T0	;установка вывода как выход
		BCF     STATUS,RP0	;Выбор банка 0
		RETURN
T1_LO	;-------------Установка вывода 2-го датчика в 0
		BCF		PORTA,T1	;Записываем 0 
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
		RRF		T_STOCK,1	;задвигаем флар переполнения в переменную
		MOVLW	.5
		CALL	DELAY_x10mkS;задержка 54 мкс	
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

;------- Запоминание состояния системы -----------
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
