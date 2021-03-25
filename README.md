# PIC16F84-climate-control
Termostate system based of Microchip controller PIC16F84

Feb22, 2008.

Car heating system controller. It uses electromagnetic valve in cooling liquid circulation system to control vehicle interior heater temperature. It shows 3 temperatures: Outside temperature, desired inside temperature and temperature of incoming air flow. Managed by 2 buttons: increment and decrement desired temperature for 1 degree. It uses internal EEPROM for store system status in case of power off.

Hardware:
- PIC 16F84A - microcontroller
- DS18S20 - temperature censors, 2pcs
- BC1602E - LCD 2x16
- 4 MHz quarz 

Software:
- Clima-Rus.HEX - compiled soft with russian interface.
- main-Eng.asm - Assembler source code with EN interface
- main-Rus.asm - Assembler source code with RU interface + fixed bug of valve clicing at the start
- P16F84A.INC  - standard header-file for Microchip microcontroller

One of source file + header file shoul be assembled during compilation.
