;
; lab04.asm
;
; Created: 2017/9/27 9:28:02



.include "m2560def.inc"


.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.def temp=r16
.def minutes=r19
.def s=r18 ;seconds
.def ts=r17 ;10's seconds
.equ onemin=0b111100
;macros
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	mov r20, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro



.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro



.macro clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp
	st Y+,temp
	st Y,temp
.endmacro

.dseg
.org 0x200
SecondCounter: .byte 2 
TempCounter: .byte 2

.cseg
.org 0x0000
	jmp RESET
	;jmp DEFAULT;NO HANDLING FOR IRQ0
	;jmp DEFAULT;NO ...			IRQ1   CAN I IGNORE???
.org OVF0addr
	jmp Timer0OVF

;DEFAULT: reti

RESET: 

	ldi temp, high(RAMEND)
	out SPH,temp
	ldi temp, low(RAMEND)
	out SPL,temp
	clr minutes
	clr s
	clr ts
	ser temp
	out DDRF, temp;out
	out DDRA, temp;out
	clr temp
	out PORTF, temp
	out PORTA, temp

	do_lcd_command 0b00111000 ; 2x5x7; 0b001 DL N F x x;function set
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift;entry mode
	do_lcd_command 0b00001100 ; display on,Cursor off, no blink


	rjmp main


;;;;;time 
Timer0OVF:
	push temp
	in temp,SREG
	push temp
	push YH
	push YL
	push r25
	push r24

	lds r24,TempCounter
	lds r25,TempCounter+1
	adiw r25:r24,1

	cpi r24,low(7812)
	ldi temp,high(7812)
	cpc r25,temp
	brne NotSecond
	
	inc s
	cpi s,10;10
	breq tsinc
	bac:
	cpi ts,6;6
	breq minu	
	back:
	ldi r23,48
	
	do_lcd_command 0b00000010

	add minutes,r23
	do_lcd_data minutes

	ldi r20,':'
	rcall lcd_data
	rcall lcd_wait

	add ts,r23
	do_lcd_data ts
	add s,r23
	do_lcd_data s


	sub minutes,r23
	sub ts,r23
	sub s,r23


	clear TempCounter
	rjmp EndIf
tsinc:
	clr s;
	inc ts;
	rjmp bac
minu:
	clr ts
	clr s
	inc minutes     ;1
	clr temp
	rjmp back

NotSecond:
	sts TempCounter,r24
	sts TempCounter+1,r25
	rjmp EndIf

	
EndIf:
	pop r24
	pop r25
	pop YL;
	pop YH
	pop temp
	out SREG,temp
	pop temp
	reti

main:

	clear TempCounter
	;clear SecondCounter
	ldi temp,0
	out TCCR0A,temp
	ldi temp,0b00000010
	out TCCR0B,temp
	ldi temp, 1<<TOIE0
	sts TIMSK0,temp
	sei

loop:rjmp loop



;;;;lcdddddd
lcd_command:
	out PORTF, r16
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTF, r20
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
        nop
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4;;;;;i dont understand
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
