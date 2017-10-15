;
; a.asm
;
;Detecting Motor Speed

; Created: 11/10/2017 1:41:50 PM
; Author : ottof
;

;;Need to get external interupt INT2, for reading how often theres a hole
;;Need a timer interrupt to display speed on the LCD every 100ms
;;Need to set how to output to LCD

.include "m2560def.inc"

;Contsants for delay
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
/////////////////////////////////////////////////

;; LCD STUFF
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro do_lcd_command
	ldi r21, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	mov r22, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro
/////////////////////////////////////////////////

;Basic register naming
.def temp = r16
.def fourCounter = r17
.def numberL = r18
.def numberH = r19
.def resultL  = r20
.def resultH = r21

/////////////////////////////////////////////////


.dseg
	rps: .byte 2
	secondCounter : .byte 2
	tempCounter: .byte 2


	
.cseg	;;; Got this table from lecture slides
; Vector Table
.org 0x0000
	jmp RESET
	jmp DEFAULT						; IRQ0 Handler
	jmp DEFAULT						; IRQ1 Handler
	jmp INTERRUPT2 					; IRQ2 Handler
	jmp DEFAULT 					; IRQ3 Handler
	jmp DEFAULT 					; IRQ4 Handler
	jmp DEFAULT 					; IRQ5 Handler
	jmp DEFAULT 					; IRQ6 Handler
	jmp DEFAULT 					; IRQ7 Handler
	jmp DEFAULT 					; Pin Change Interrupt Request 0
	jmp DEFAULT 					; Pin Change Interrupt Request 1
	jmp DEFAULT 					; Pin Change Interrupt Request 2
	jmp DEFAULT 					; Watchdog Time-out Interrupt
	jmp DEFAULT 					; Timer/Counter2 Compare Match A
	jmp DEFAULT 					; Timer/Counter2 Compare Match B
	jmp DEFAULT 					; Timer/Counter2 Overflow
	jmp DEFAULT 					; Timer/Counter1 Capture Event
	jmp DEFAULT 					; Timer/Counter1 Compare Match A
	jmp DEFAULT 					; Timer/Counter1 Compare Match B
	jmp DEFAULT 					; Timer/Counter1 Compare Match C
	jmp DEFAULT 					; Timer/Counter1 Overflow
	jmp DEFAULT 					; Timer/Counter0 Compare Match A
	jmp DEFAULT 					; Timer/Counter0 Compare Match B
	jmp Timer0OVF 					; Timer/Counter0 Overflow
	jmp DEFAULT 					; SPI Serial Transfer Complete
	jmp DEFAULT 					; USART0, Rx Complete
	jmp DEFAULT 					; USART0 Data register Empty
	jmp DEFAULT 					; USART0, Tx Complete
	jmp DEFAULT 					; Analog Comparator
	jmp DEFAULT 					; ADC Conversion Complete
	jmp DEFAULT 					; EEPROM Ready
	jmp DEFAULT 					; Timer/Counter3 Capture Event
	jmp DEFAULT 					; Timer/Counter3 Compare Match A
	jmp DEFAULT 					; Timer/Counter3 Compare Match B
	jmp DEFAULT 					; Timer/Counter3 Compare Match C
	jmp DEFAULT 					; Timer/Counter3 Overflow
.org 0x0072
DEFAULT:
	reti							; used for interrupts that are not handled

RESET: 
	//Stack initialization
	ldi temp, high(RAMEND)	
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp

	//Setting outputs
	ser temp
	out DDRF, temp;out
	out DDRA, temp;out
	clr temp
	out PORTF, temp
	out PORTA, temp

	//Sets port D int2 to an input
	clr temp
	out DDRD, r16 
	
	//THIS allows int2 to trigger falling edges which occurs when a 
	//hole occurs in the motor wheel. Seen this in example code
	//still to learn what isc20 &  eimsk are.
	//External Interrupt Control Register A
	ldi temp, (2 <<ISC20)		
	sts EICRA, temp
	ldi temp, (1 << INT2)
	out EIMSK, temp			

	// LCD Commands
	do_lcd_command 0b00111000 ; 2x5x7; 0b001 DL N F x x;function set
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift;entry mode
	do_lcd_command 0b00001110 ; display on,Cursor off, no blink
	do_lcd_command 0b00011000
	
	//temp counter stuff to keep timer counts
	//16bit counter
	clr temp	; in this temp is 0, this initalizes counts to 0
	sts tempCounter, temp
	sts tempCounter + 1, temp
	//Setting speed/amount of counts for the timer
	//interupt occurs when overflow happens
	ldi temp, 0b00000010	//sets prescalar to 8
	out TCCR0B, temp	
	ldi temp, 1 << TOIE0
	sts TIMSK0, temp
	
	clr fourCounter
	//
	sei		//setting interupt flag

//just waiting for interupts now
loop:	
	jmp loop

;;Interupt stuff
//increases count of how many holes seen
//counts seeing 4 holes as one revolution
INTERRUPT2:
	;prolouge
	push temp
	;main
	ldi temp, 4
	inc fourCounter
	cp fourCounter, temp
	brne NOTFOUR
	adiw numberHigh:numberLow ,1
	clr fourCounter
	NOTFOUR:
	pop temp
	reti


//INTERRUPT SUBROUTINE FOR TIMER0, not external, for how many
//interup2s, for each second to get rpms
Timer0OVF:
	//prologue: saving conflicting registers and teh status regiser
	in temp, SREG 
	push temp
	push r25
	push r24
	;;body
	lds r24, tempCounter	//getting value of temp coints
	lds r25, tempCounter + 1
	adiw r25:r24, 1			//increasing temp counter by 1

	cpi r24, low(781)		//this is due to 7812 = 10000000/128, so 1 second 
	ldi temp, high(781)		// use 781 for 0.1 seconds
	cpc r25, temp
	brne NOTYET
	// 0.1 seconds past so now to count speed and average it

	//multiplies by 10, dont need to worry about carry
	//as rpms wont be high enough
	ldi r23, 10
	mul numberL, r23
	mov resultL, r0
	mov resultH, r1
	mul numberH, r23
	add resultH, r0

	//print "speed = numberH&L" to lcd


	
	//now clear the revolution counter
	clr numberL
	clr numberH

	//clear the timecounter
	clr temp
	sts tempCounter, temp
	sts tempCounter + 1, temp

	rjmp epi

	NOTYET:
		sts tempCounter, r24
		sts tempCounter + 1, r25
	
	epi:
		pop r24
		pop r25
		pop temp
		out SREG, temp
		reti


//Delay functions taken from previous lab
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

sleep_25ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret

sleep_100ms:
	rcall sleep_25ms
	rcall sleep_25ms
	rcall sleep_25ms
	rcall sleep_25ms
	ret