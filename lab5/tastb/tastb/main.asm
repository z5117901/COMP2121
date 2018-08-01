;
; B.asm
;
; Created: 11/10/2017 1:42:15 PM
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
.set LCD_HOME_LINE = 0b00000001

.macro do_lcd_command
	ldi r21, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro funky_do_lcd_command
	mov r21, @0
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
.def numberL = r24
.def numberH = r25
.def resultL = r20
.def resultH = r21
.def lcddisplayaddress = r22
.def tempS = r23
.def flag = r18

/////////////////////////////////////////////////


.dseg
	secondCounter : .byte 2
	tempCounter: .byte 2

	TenThousand: .byte 1
	Thousand: .byte 1
	Hundred: .byte 1
	Ten: .byte 1
	One: .byte 1

	MotorSpeed: .byte 1

	
.cseg	;;; Got this table from lecture slides


; Vector Table
.cseg
.org 0x0
	jmp RESET
.org INT0addr ; INT0addr is the address of EXT_INT0
	jmp EXT_INT0
.org INT1addr ; INT1addr is the address of EXT_INT1
	jmp EXT_INT1
.org INT2addr
	jmp INTERRUPT2
.org OVF0addr
	jmp Timer0OVF
/*
.org 0x0000
	jmp RESET
	jmp EXT_INT0					; IRQ0 Handler
	jmp EXT_INT1					; IRQ1 Handler
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
*/
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
	out DDRC, temp
	clr temp
	out PORTF, temp
	out PORTA, temp
		out PORTC, temp


	//Sets port D int2 to an input
	clr temp
	out DDRD, temp
	out PORTD, temp

	//sets BUTTONS I THINK
	ldi temp, (2 << ISC10) | ( 2 << ISC00 ) | (2<<ISC20)
	sts EICRA, temp
	in temp, EIMSK
	ori temp, (1<<INT1) | (1<<INT0) | (1<<INT2)
	out EIMSK, temp
	clr temp
	clr flag
	
	//THIS allows int2 to trigger falling edges which occurs when a 
	//hole occurs in the motor wheel. Seen this in example code
	//still to learn what isc20 &  eimsk are.
	//External Interrupt Control Register A
	
			
	
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

	ldi temp, LCD_HOME_LINE				; initialise variables
	mov lcddisplayaddress, temp
	
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
	push temp
	ldi temp, 0b00001000
	sts DDRL, temp ; set PL3 (OC5A) as output.
	ldi temp, 0xFF ; this value and the operation mode determine the PWM duty cycle
	sts OCR5AL, temp

	sts MotorSpeed, temp // stores the motor speed in memory

	clr temp
	sts OCR5AH, temp
	ldi temp, (1 << CS50) ; CS50=1: no prescaling
	sts TCCR5B, temp
	ldi temp, (1<< WGM50)|(1<<COM5A1)
	; WGM50=1: phase correct PWM, 8 bits
	; COM5A1=1: make OC5A override the normal port functionality of the I/O pin PL3
	sts TCCR5A, temp
	pop temp
	sei		//setting interupt flag

//just waiting for interupts now
loop:	
	jmp loop

;;Interupt stuff
//increases count of how many holes seen
//counts seeing 4 holes as one revolution

EXT_INT0:
	;debounce
	cpi flag, 1 ;skips delay if flag is set
	brne br0
	rcall sleep_100ms
	clr flag
	br0:
	ldi flag, 1 ;sets flag

	;prologue
	push temp
	in temp, SREG
	push temp

	ser temp
	out PORTC, temp
	;body
	lds temp, MotorSpeed
	cpi temp, 0xFF
	breq end0
	cpi temp, 0x9F 

	;epilogue
	end0:
	pop temp
	out SREG, temp
	pop temp

	reti

EXT_INT1:
	;debounce
	/*
	cpi flag, 1 ;skips delay if flag is set
	brne br1
	rcall sleep_100ms
	clr flag
	br1:
	ldi flag, 1 ;sets flag
	*/
	;prologue
	push temp
	in temp, SREG
	push temp

	ser temp
	out PORTC, temp
	/*
	;body
	lds temp, MotorSpeed
	cpi temp, 0xFF
	breq end1
	cpi temp, 0x9F

	;epilogue
	end1:
	*/
	pop temp
	out SREG, temp
	pop temp
	
	//rcall sleep_25ms
	reti


INTERRUPT2:
	;prolouge
	push temp
	push tempS
	;main
	ldi temp, 4
	inc fourCounter
	cp fourCounter, temp
	brne NOTFOUR
	adiw numberH:numberL, 1
	clr fourCounter
	NOTFOUR:
	pop tempS
	pop temp
	reti


//INTERRUPT SUBROUTINE FOR TIMER0, not external, for how many
//interup2s, for each second to get rpms
Timer0OVF:
	//prologue: saving conflicting registers and teh status regiser
	in temp, SREG 
	push temp
	push tempS
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
	
	pop r24
	pop r25
	ldi r23, 10
	mul numberL, r23
	mov resultL, r0
	mov resultH, r1
	mul numberH, r23
	add resultH, r0
	mov numberL, resultL
	mov numberH, resultH
	clr resultL
	clr resultH
	
	
	rcall write_number
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
		pop r24
		pop r25
	epi:
		
		pop tempS
		pop temp
		out SREG, temp
		reti






//LCD COMMANDS
lcd_command:
	out PORTF, r21
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
	out PORTF, r22
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
	push r21
	clr r21
	out DDRF, r21
	out PORTF, r21
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
        nop
	in r21, PINF
	lcd_clr LCD_E
	sbrc r21, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r21
	out DDRF, r21
	pop r21
	ret

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


write_number:
	push numberL
	push numberH
	push temp
	push tempS


	ldi lcddisplayaddress, 0b10000000 
	clr temp
	sts TenThousand, temp
	sts Thousand, temp
	sts Hundred, temp
	sts Ten, temp
	sts One, temp

	writeTenThousand:
		cpi numberL, low(10000)
		ldi tempS, high(10000)
		cpc numberH, tempS
		brlo displayTenThousand

		loopTenThousand:
			cpi numberL, low(10000)			;Compares the number to 10000
			ldi tempS, high(10000)
			cpc numberH, tempS			;if it is less than 10000 branch to the 1000s 
			brlo displayTenThousand

			subi numberL, low(10000)			;Minus 10000 from the number
			sbci numberH, high(10000)

			lds temp, TenThousand				;increase the number in the 10000s column
			inc temp
			sts TenThousand, temp

			jmp loopTenThousand					;Repeat until less than 10000, where you have the value of the 10000s column

		displayTenThousand:
			lds temp, TenThousand
			subi temp, -'0'
			funky_do_lcd_command lcddisplayaddress
			inc lcddisplayaddress
			do_lcd_data temp

	writeThousand:
		cpi numberL, low(1000)
		ldi tempS, high(1000)
		cpc numberH, tempS
		brlo displayThousand

		loopThousand:
			cpi numberL, low(1000)			;Compares the number to 1000
			ldi tempS, high(1000)
			cpc numberH, tempS			;if it is less than 1000 branch to the 100s 
			brlo displayThousand

			subi numberL, low(1000)			;Minus 1000 from the number
			sbci numberH, high(1000)

			lds temp, Thousand				;increase the number in the 1000s column
			inc temp
			sts Thousand, temp

			jmp loopThousand					;Repeat until less than 1000, where you have the value of the 1000s column

		displayThousand:
			lds temp, Thousand
			subi temp, -'0'
			funky_do_lcd_command lcddisplayaddress 
			inc lcddisplayaddress
			do_lcd_data temp

	writeHundreds:
		cpi numberL, low(100)
		ldi tempS, high(100)
		cpc numberH, tempS
		brlo displayHundred

		loopHundred:
			cpi numberL, low(100)			;Compares the number to 100
			ldi tempS, high(100)
			cpc numberH, tempS			;if it is less than 100 branch to the 10s 
			brlo displayHundred

			subi numberL, low(100)			;Minus 100 from the number
			sbci numberH, high(100)

			lds temp, Hundred				;increase the number in the 100s column
			inc temp
			sts Hundred, temp

			jmp loopHundred					;Repeat until less than 100, where you have the value of the 100s column

		displayHundred:
			lds temp, Hundred
			subi temp, -'0'
			funky_do_lcd_command lcddisplayaddress 
			inc lcddisplayaddress
			do_lcd_data temp

	writeTens:
		cpi numberL, low(10)
		ldi tempS, high(10)
		cpc numberH, tempS
		brlo displayTen

		loopTen:
			cpi numberL, low(10)			;Compares the number to 10
			ldi tempS, high(10)
			cpc numberH, tempS			;if it is less than 10 branch to the 10s 
			brlo displayTen

			subi numberL, low(10)			;Minus 10 from the number
			sbci numberH, high(10)

			lds temp, Ten				;increase the number in the 10s column
			inc temp
			sts Ten, temp

			jmp loopTen				;Repeat until less than 10, where you have the value of the 10s column

		displayTen:
			lds temp, Ten
			subi temp, -'0'
			funky_do_lcd_command lcddisplayaddress 
			inc lcddisplayaddress
			do_lcd_data temp

	writeOnes:										; write remaining digit to LCD
		mov temp, numberL
		subi temp, -'0' 							; convert to ASCII
		funky_do_lcd_command lcddisplayaddress
		inc lcddisplayaddress
		do_lcd_data temp

	pop tempS
	pop temp
	pop numberH
	pop numberL

	ret



