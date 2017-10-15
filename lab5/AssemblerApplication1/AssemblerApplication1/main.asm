; Part A: Speed Measurement
; Connect motor MOT to potentiometer POT to control motor's speed.
; Connect optointerrupter's emitter OpE to +5V pin.
; Connect output (OpO) to INT2 (TDX2).
; Write a program to calculate the speed of the motor's rotation in
; revolutions per second and display it on the LCD.
; Update the display at least every 500ms.

.include "m2560def.inc"

; Delay Constants
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4 				; 4 cycles per iteration - setup/call-return overhead

; LCD Instructions
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.set LCD_DISP_ON = 0b00001110
.set LCD_DISP_OFF = 0b00001000
.set LCD_DISP_CLR = 0b00000001

.set LCD_FUNC_SET = 0b00111000 						; 2 lines, 5 by 7 characters
.set LCD_ENTR_SET = 0b00000110 						; increment, no display shift

.set LCD_HOME_LINE = 0b10000000 					; goes to 1st line (address 0)
.set LCD_SEC_LINE = 0b10101000 						; goes to 2nd line (address 40)

; LCD Macros
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_command_reg
	mov r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_reg
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

; General
.def param = r16
.def numberL = r17
.def numberH = r18
.def temp1 = r22
.def temp2 = r23
.def address = r24

.dseg
	rps: .byte 2

	isPrinted: .byte 1
	digit5: .byte 1
	digit4: .byte 1
	digit3: .byte 1
	digit2: .byte 1
	digit: .byte 1

	SecondCounter: .byte 2
	TempCounter: .byte 2

.cseg
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
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16 										; set PORTF and PORTA to output (LCD)
	out DDRF, r16
	out DDRA, r16
	clr r16											; clear PORTF and PORTA registers
	out PORTF, r16
	out PORTA, r16

	clr r16
	out DDRD, r16 									; set PORTD (INT2/TDX2) to input

	ldi temp1, (2 << ISC20) 						; set INT2 to trigger on falling edges
	sts EICRA, temp1
	ldi temp1, (1 << INT2) 							; enable INT2
	out EIMSK, temp1

	do_lcd_command LCD_FUNC_SET 					; initialise LCD
	rcall sleep_5ms
	do_lcd_command LCD_FUNC_SET
	rcall sleep_1ms
	do_lcd_command LCD_FUNC_SET
	do_lcd_command LCD_FUNC_SET
	do_lcd_command LCD_DISP_OFF
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_ENTR_SET
	do_lcd_command LCD_DISP_ON

	ldi temp1, LCD_HOME_LINE						; initialise variables
	mov address, temp1
	clr numberL
	clr numberH

	/* Target Timer Count = (Input Frequency / Prescale) / Target Frequency - 1
						; = (16 000 000 / 1024) / 1 - 1 = 15625
	ldi temp1, (1 << WGM12) 						; set 16-bit Timer1 to CTC mode
	ori temp1, (1 << CS12)|(1 << CS10) 				; set prescaler to 1024
	sts TCCR1B, temp1
	ldi temp1, low(15625) 							; set compare match value in OCR1A
	sts OCR1AL, temp1
	ldi temp1, high(15625)
	sts OCR1AH, temp1
	ldi temp1, 1 << OCIE1A 							; enable Timer1 Compare Match Interrupt A
	sts TIMSK1, temp1 */

	clr temp1
	sts TempCounter, temp1 			; initialise temporary counter to 0
	sts TempCounter + 1, temp1
	sts SecondCounter, temp1 		; initialise second counter to 0
	sts SecondCounter + 1, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1 			; set prescaler to 8 = 278 microseconds
	ldi temp1, 1 << TOIE0 		; enable timer
	sts TIMSK0, temp1

	sei

halt:
	jmp halt

INTERRUPT2:
	push temp1

	ldi temp1, 1
	add numberL, temp1
	ldi temp1, 0
	adc numberH, temp1
	
	INTERRUPT2_EPILOGUE:
	pop temp1
	reti

UPDATE_LCD:
	push temp1

	ldi address, LCD_HOME_LINE
	rcall write16

	clr numberL
	clr numberH

	UPDATE_LCD_EPILOGUE:
	pop temp1
	reti

Timer0OVF:						; interrupt subroutine to Timer0
	in temp1, SREG
	push temp1 					; save conflict registers
	push r25
	push r24

	lds r24, TempCounter 		; load value of temporary counter
	lds r25, TempCounter + 1
	adiw r25:r24, 1 			; increase temporary counter by 1

	cpi r24, low(3906)			; here use 7812 = 10^6/128 for 1 second
	ldi temp1, high(3906) 		; use 3906 for 0.5 seconds
	cpc r25, temp1
	brne notSecond 				; if they're not equal, jump to notSecond
	
	; here we know 0.5 seconds has passed: DO THINGS
	ldi address, LCD_HOME_LINE
	asr numberH 				; need to multiply number by 2 to give revolutions per SECOND
	ror numberL 				; need to divide by 4 to account for 4 holes
	do_lcd_command LCD_DISP_CLR
	rcall write16
	clr numberL
	clr numberH

	clr temp1
	sts TempCounter, temp1				; reset temporary counter
	sts TempCounter + 1, temp1
	lds r24, SecondCounter 		; load second counter and increase since 1 second has expired
	lds r25, SecondCounter + 1
	adiw r25:r24, 1 			; increase second counter by 1

	sts SecondCounter, r24
	sts SecondCounter + 1, r25
	rjmp epilogue

	notSecond:
		sts TempCounter, r24		; store new value of temporary counter
		sts TempCounter + 1, r25

	epilogue:
		pop r24
		pop r25
		pop temp1
		out SREG, temp1
		reti 						; return from interrupt

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

; Delay commands
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

sleep_20ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret

; Writes 16-bit number in numberH:numberL to the LCD in decimal
write16:
	push numberH
	push numberL
	push temp1

	clr temp1
	sts isPrinted, temp1 							; 0 if not printed, 1 if printed
	sts digit5, temp1
	sts digit4, temp1
	sts digit3, temp1
	sts digit2, temp1
	sts digit, temp1

	write10000s:
		mov temp1, numberL
		cpi temp1, low(10000) 						; check that numberH:numberL > 10000
		ldi temp1, high(10000)
		cpc numberH, temp1
		brlo write1000s
	
		loop10000s:
			mov temp1, numberL
			cpi temp1, low(10000) 					; if < 10000, display ten thousands digit
			ldi temp1, high(10000)
			cpc numberH, temp1
			brlo display10000s

			mov temp1, numberL						; decrement parameter by 10000
			subi temp1, low(10000)
			mov numberL, temp1
			mov temp1, numberH
			sbci temp1, high(10000)
			mov numberH, temp1
		   
			lds temp1, digit5 						; increment ten thousands digit counter
			inc temp1
			sts digit5, temp1
		   
			jmp loop10000s
	   
		display10000s:
			lds temp1, digit5 						; only print if ten thousands digit counter > 0
			cpi temp1, 0
			breq write1000s

			lds temp1, isPrinted 					; set isPrinted to 1
			ldi temp1, 1
			sts isPrinted, temp1

			lds temp1, digit5 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1

	write1000s:
		mov temp1, numberL
		cpi temp1, low(1000) 						; check that numberH:numberL > 1000
		ldi temp1, high(1000)
		cpc numberH, temp1
		brlo space1000s
	
		loop1000s:
			mov temp1, numberL
			cpi temp1, low(1000) 					; if < 1000, display thousands digit
			ldi temp1, high(1000)
			cpc numberH, temp1
			brlo display1000s

			mov temp1, numberL					; decrement parameter by 1000
			subi temp1, low(1000)
			mov numberL, temp1
			mov temp1, numberH
			sbci temp1, high(1000)
			mov numberH, temp1
		   
			lds temp1, digit4 						; increment thousands digit counter
			inc temp1
			sts digit4, temp1
		   
			jmp loop1000s
	   
		display1000s:
			lds temp1, digit4 						; print if thousands digit counter > 0
			cpi temp1, 0
			breq write100s

			lds temp1, isPrinted 					; set isPrinted to 1
			ldi temp1, 1
			sts isPrinted, temp1

			lds temp1, digit4 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1

			jmp write100s

		space1000s:
			lds temp1, isPrinted
			cpi temp1, 0
			breq write100s
			do_lcd_command_reg address
			inc address
			do_lcd_data '0'

	write100s:
		mov temp1, numberL
		cpi temp1, low(100) 						; check that numberH:numberL > 100
		ldi temp1, high(100)
		cpc numberH, temp1
		brlo space100s

		loop100s:
			mov temp1, numberL
			cpi temp1, low(100) 					; if < 100, display hundreds digit
			ldi temp1, high(100)
			cpc numberH, temp1
			brlo display100s

			mov temp1, numberL						; decrement parameter by 100
			subi temp1, low(100)
			mov numberL, temp1
			mov temp1, numberH
			sbci temp1, high(100)
			mov numberH, temp1
		   
			lds temp1, digit3 						; increment hundreds digit counter
			inc temp1
			sts digit3, temp1

			jmp loop100s
	   
		display100s:
			lds temp1, digit3 						; only print if hundreds digit counter > 0
			cpi temp1, 0
			breq write10s

			lds temp1, isPrinted 					; set isPrinted to 1
			ldi temp1, 1
			sts isPrinted, temp1

			lds temp1, digit3 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1

			jmp write10s
		
		space100s:
			lds temp1, isPrinted
			cpi temp1, 0
			breq write10s
			do_lcd_command_reg address
			inc address
			do_lcd_data '0'

	write10s:
		mov temp1, numberL
		cpi temp1, 10 								; check that numberH:numberL >= 10
		brlo space10s

		loop10s:
			mov temp1, numberL
			cpi temp1, 10 							; if < 10, display tens digit
			brlo display10s

			mov temp1, numberL						; decrement parameter by 10
			subi temp1, low(10)
			mov numberL, temp1
			mov temp1, numberH
			sbci temp1, high(10)
			mov numberH, temp1

			lds temp1, digit2 						; increment tens digit counter
			inc temp1
			sts digit2, temp1
		   
			jmp loop10s
	   
		display10s:
			lds temp1, digit2 						; only print if tens digit counter > 0
			cpi temp1, 0
			breq write1s

			lds temp1, digit2 						; convert to ASCII
			subi temp1, -'0'
			do_lcd_command_reg address
			inc address
			do_lcd_data_reg temp1
			jmp write1s

		space10s:
			lds temp1, isPrinted
			cpi temp1, 0
			breq write1s
			do_lcd_command_reg address
			inc address
			do_lcd_data '0'

	write1s:										; write remaining digit to LCD
		mov temp1, numberL
		subi temp1, -'0' 							; convert to ASCII
		do_lcd_command_reg address
		inc address	
		do_lcd_data_reg temp1

	write16Epilogue:
	pop temp1
	pop numberL
	pop numberH
	ret