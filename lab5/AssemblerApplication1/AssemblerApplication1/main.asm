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

;Constants for delay
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
/////////////////////////////////////////////////

;LCD Constants
.set lcddisplayaddress=0b10000000

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
.def temp1 = r19
.def numberLow = r17
.def numberHigh = r18
.def 
/////////////////////////////////////////////////


.dseg
	rps: .byte 2
	secondCounter : .byte 2
	tempCounter: .byte 2

	TenThousand: .byte 1
	Thousand: .byte 1
	Hundred: .byte 1
	Ten: .byte 1
	One: .byte 1


	
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
	jmp UPDATE_LCD 					; Timer/Counter1 Compare Match A
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
	clr temp	; in this temp is 0, this initalizes counts to 0
	sts tempCounter, temp
	sts tempCounter + 1, temp
	sts secondCounter, temp
	sts secondCounter + 1, temp
	//Setting speed/amount of counts for the timer
	ldi temp, 0b00000010
	out TCCR0B, temp
	ldi temp, 1 << TOIE0
	sts TIMSK0, temp
	

	//
	sei		//setting interupt flag
	rjmp main

end:
	jmp end

main:

;;Interupt1 stuff
INTERRUPT2:
	;prologue
	push temp
	;body
	ldi temp, 1
	add numberLow ,temp
	ldi temp, 0
	adc numberHigh, temp
	;epilogue
	pop temp
	reti

//Updates lcd, shud be called every 100ms
UPDATE_LCD:
	;prologue
	push temp
	;body
	//////////////////////
	//////////////////////
	//////////////////////
	//////////////////////
	////////CAMERON///////
	//////////////////////
	//////////////////////
	//////////////////////
	//////////////////////

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
	cpc r25,temp1
	// 0.1 seconds past so now to count speed and average it
	


	; LCD Commands
lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
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
	push numberLow
	push numberHigh
	push temp1

	clr temp1
	sts TenThousand, temp1
	sts Thousand, temp1
	sts Hundred, temp1
	sts Ten, temp1
	sts One, temp1

	writeTenThousand:
		cpi numberLow, low(10000)
		cpc numberHigh, high(10000)
		brlo writeThousand

		loopTenThousand:
			cpi numberLow, low(10000)			;Compares the number to 10000
			cpc numberHigh, high(10000)			;if it is less than 10000 branch to the 1000s 
			brlo displayTenThousand

			subi numberLow, low(10000)			;Minus 10000 from the number
			sbic numberHigh, high(10000)

			lds temp1, TenThousand				;increase the number in the 10000s column
			inc temp1
			sts TenThousand, temp1

			jmp loopTenThousand					;Repeat until less than 10000, where you have the value of the 10000s column

		displayTenThousand:
			lds temp1, TenThousand
			subi temp1, -'0'
			do_lcd_command lcddisplayaddress
			inc lcddisplayaddress
			do_lcd_data temp1

	writeThousand:
		cpi numberLow, low(1000)
		cpc numberHigh, high(1000)
		brlo writeHundreds

		loopThousand:
			cpi numberLow, low(1000)			;Compares the number to 1000
			cpc numberHigh, high(1000)			;if it is less than 1000 branch to the 100s 
			brlo displayThousand

			subi numberLow, low(1000)			;Minus 1000 from the number
			sbic numberHigh, high(1000)

			lds temp1, Thousand				;increase the number in the 1000s column
			inc temp1
			sts Thousand, temp1

			jmp loopThousand					;Repeat until less than 1000, where you have the value of the 1000s column

		displayThousand:
			lds temp1, Thousand
			subi temp1, -'0'
			do_lcd_command lcddisplayaddress 
			inc lcddisplayaddress
			do_lcd_data temp1

	writeHundreds:
		cpi numberLow, low(100)
		cpc numberHigh, high(100)
		brlo writeTens

		loopHundred:
			cpi numberLow, low(100)			;Compares the number to 100
			cpc numberHigh, high(100)			;if it is less than 100 branch to the 10s 
			brlo displayHundred

			subi numberLow, low(100)			;Minus 100 from the number
			sbic numberHigh, high(100)

			lds temp1, Hundred				;increase the number in the 100s column
			inc temp1
			sts Hundred, temp1

			jmp loopHundred					;Repeat until less than 100, where you have the value of the 100s column

		displayHundred:
			lds temp1, Hundred
			subi temp1, -'0'
			do_lcd_command lcddisplayaddress 
			inc lcddisplayaddress
			do_lcd_data temp1

	writeTens:
		cpi numberLow, low(10)
		cpc numberHigh, high(10)
		brlo writeOnes

		loopTen:
			cpi numberLow, low(10)			;Compares the number to 10
			cpc numberHigh, high(10)			;if it is less than 10 branch to the 10s 
			brlo displayTen

			subi numberLow, low(10)			;Minus 10 from the number
			sbic numberHigh, high(10)

			lds temp1, Ten				;increase the number in the 10s column
			inc temp1
			sts Ten, temp1

			jmp loopTen				;Repeat until less than 10, where you have the value of the 10s column

		displayTen:
			lds temp1, Ten
			subi temp1, -'0'
			do_lcd_command lcddisplayaddress 
			inc lcddisplayaddress
			do_lcd_data temp1

	writeOnes:										; write remaining digit to LCD
		mov temp1, numberLow
		subi temp1, -'0' 							; convert to ASCII
		do_lcd_command lcddisplayaddress
		inc lcddisplayaddress
		do_lcd_data temp1

	pop temp1
	pop numberHigh
	pop numberLow

	ret