        LIST
; P16F84A.INC  Standard Header File, Version 2.00    Microchip Technology, Inc.
        NOLIST

; This header file defines configurations, registers, and other useful bits of
; information for the PIC16F84 microcontroller.  These names are taken to match 
; the data sheets as closely as possible.  

; Note that the processor must be selected before this file is 
; included.  The processor may be selected the following ways:

;       1. Command line switch:
;               C:\ MPASM MYFILE.ASM /PIC16F84A
;       2. LIST directive in the source file
;               LIST   P=PIC16F84A
;       3. Processor Type entry in the MPASM full-screen interface

;==========================================================================
;
;       Revision History
;
;==========================================================================

;Rev:   Date:    Reason:

;1.00   2/15/99 Initial Release

;==========================================================================
;
;       Verify Processor
;
;==========================================================================

        IFNDEF __16F84A
           MESSG "Processor-header file mismatch.  Verify selected processor."
        ENDIF

;==========================================================================
;
;       Register Definitions
;
;==========================================================================

W                            EQU     H'0000'
F                            EQU     H'0001'

;----- Register Files------------------------------------------------------
; �������� ���p�������� p�����p��. Bank 0
INDF                         EQU     H'0000'
TMR0                         EQU     H'0001'
PCL                          EQU     H'0002'
STATUS                       EQU     H'0003'
FSR                          EQU     H'0004';��������� ��������� ���������
PORTA                        EQU     H'0005'
PORTB                        EQU     H'0006'
EEDATA                       EQU     H'0008';������ EEPROM
EEADR                        EQU     H'0009';�����  EEPROM. 3Fh max
PCLATH                       EQU     H'000A'
INTCON                       EQU     H'000B'
; �������� ���p�������� p�����p��. Bank 1
OPTION_REG                   EQU     H'0081'
TRISA                        EQU     H'0085';���������� ������ �
TRISB                        EQU     H'0086';���������� ������ �
EECON1                       EQU     H'0088';���������� R/W EEPROM
EECON2                       EQU     H'0089';������ �� ���� ������

;----- STATUS Bits --------------------------------------------------------

IRP                          EQU     H'0007'; not in use
RP1                          EQU     H'0006'; not in use
RP0                          EQU     H'0005';����� �������� ������(Bank): 0(0-7F), 1(80-FF)
NOT_TO                       EQU     H'0004';������������ WDT ���������� ��� � 0
NOT_PD                       EQU     H'0003';0 �� ������� SLEEP, 1-��� ��� � CLRWDT
Z                            EQU     H'0002';�������� ����������
DC                           EQU     H'0001';���������� �������
C                            EQU     H'0000';�������

;----- INTCON Bits --------------------------------------------------------

GIE                          EQU     H'0007';7-������(1)/����(0) ���� ������;
EEIE                         EQU     H'0006';6-������(1)/����(0) ������ �� ������������ �������
T0IE                         EQU     H'0005';5-������(1)/����(0) ������ �� TMRO
INTE                         EQU     H'0004';4-������(1)/����(0) ������ �������� INT
RBIE                         EQU     H'0003';3-������(1)/����(0) ������ ��� ��������� �� �� RB7...RB4
T0IF                         EQU     H'0002';2-���� ���������� TMRO. ����(1)/���(0)
INTF                         EQU     H'0001';1-���� ���������� INT. ����(1)/���(0)
RBIF                         EQU     H'0000';0-���� ���������� �� RB7...RB4. ����(1)/���(0)

;----- OPTION_REG Bits ----------------------------------------------------

NOT_RBPU                     EQU     H'0007';7-�����(0)/����(1) �������� ����� �
INTEDG                       EQU     H'0006';6-INT �� ������(0)/�����(1),
T0CS                         EQU     H'0005';5-TMRO �� �����(0)/����(1),
T0SE                         EQU     H'0004';4-TMR �� ������(0)/�����(1), 
PSA                          EQU     H'0003';3- �������� � TMR0(0)/WDT(1),
PS2                          EQU     H'0002';��� ��������
PS1                          EQU     H'0001';��� ��������
PS0                          EQU     H'0000';��� ��������

;----- EECON1 Bits --------------------------------------------------------

EEIF                         EQU     H'0004';4-������ ���������(1)/�����������(0)
WRERR                        EQU     H'0003';3-������ ���� �������� �� ����������(1)/������ ���������(0)
WREN                         EQU     H'0002';2-��������� ������(1)/���������(0)
WR                           EQU     H'0001';1-������ ������ (1)/�������. �����.�� ������.
RD                           EQU     H'0000';0-������ ������ (1)/�������. �����.�� ������.

;==========================================================================
;
;       RAM Definition
;
;==========================================================================

        __MAXRAM H'CF'
        __BADRAM H'07', H'50'-H'7F', H'87'

;==========================================================================
;
;       Configuration Bits
;
;==========================================================================

_CP_ON                       EQU     H'000F'
_CP_OFF                      EQU     H'3FFF'
_PWRTE_ON                    EQU     H'3FF7'
_PWRTE_OFF                   EQU     H'3FFF'
_WDT_ON                      EQU     H'3FFF'
_WDT_OFF                     EQU     H'3FFB'
_LP_OSC                      EQU     H'3FFC'
_XT_OSC                      EQU     H'3FFD'
_HS_OSC                      EQU     H'3FFE'
_RC_OSC                      EQU     H'3FFF'

        LIST
