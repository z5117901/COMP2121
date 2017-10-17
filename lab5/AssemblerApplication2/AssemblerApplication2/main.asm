; Part C: Motor Control
; Create a feedback system to control motor speed.
; Connect motor to OC3B. Connect optointerrupt as in Part A.
; PB1: reduce target speed by 20 rps.
; PB0: increase target speed by 20 rps.
; Minimum speed is 0 rps, maximum speed is 400 rps.
; LCD should display target speed in rps on the first line
; and measured speed on the second.
; Voltage supplied to the motor should be adjusted

.include "m2560def.inc"
.equ RPS_UPDATE = 10 	; increase/decrease rps by this value

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
.def rpsL = r17
.def rpsH = r18
.def step = r19
.def temp1 = r22
.def temp2 = r23
.def temp3 = r24
.def address = r25

.dseg
.org 0x200
	targetrps: .byte 2

	isPrinted: .byte 1
	digit5: .byte 1
	digit4: .byte 1
	digit3: .byte 1
	digit2: .byte 1
	digit: .byte 1

	SecondCounter: .byte 2
	TempCounter: .byte 2

	button_flag: .byte 1

.cseg
; Vector Table
.org 0x0000
	jmp RESET
	jmp RIGHT_BUTTON				; IRQ0 Handler PB0 RDX4
	jmp LEFT_BUTTON					; IRQ1 Handler PB1 RDX3
	jmp HOLES 						; IRQ2 Handler
	jmp DEFAULT 					; IRQ3 Handler
	jmp DEFAULT 					; IRQ4 Handler
	jmp DEFAULT 					; IRQ5 Handler
	jmp DEFAULT 					; IRQ6 Handler
	jmp DEFAULT 					; IRQ7 Hacndler
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
	jmp BUTTON_CLR 			; Timer/Counter1 Overflow
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
	jmp DEFAULT 			; Timer/Counter3 Overflow
.org 0x0072
DEFAULT:
	reti							; used for interrupts that are not handled

RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser temp1	; set PORTC (LEDs) to output
	out DDRC, temp1

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

	; button stuff
	clr temp1
	sts button_flag, temp1
	lds temp1, EICRA
	ori temp1, (2 << ISC00)		; set INT0 to trigger on falling edges
	ori temp1, (2 << ISC10) 		; set INT1 to trigger on falling edges
	sts EICRA, temp1

	in temp1, EIMSK
	ori temp1, (1 << INT0) 		; enable INT0
	ori temp1, (1 << INT1) 		; enable INT1
	out EIMSK, temp1

	; button flag timer settings
	clr temp1 							; normal mode
	sts TCCR1A, temp1
	ldi temp1, (1 << CS12)	; set prescaler to 256
	sts TCCR1B, temp1

	; init lcd
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
	clr rpsL
	clr rpsH

	clr temp1
	sts TempCounter, temp1 			; initialise temporary counter to 0
	sts TempCounter + 1, temp1
	sts SecondCounter, temp1 		; initialise second counter to 0
	sts SecondCounter + 1, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1 			; set prescaler to 8 = 278 microseconds
	ldi temp1, 1 << TOIE0 		; enable timer
	sts TIMSK0, temp1

	; Output things
	;ldi temp1, 0b00011000 		; set PE4 (OC3B) and PE5 (OC3A) to output
	ser temp1
	out DDRE, temp1

	ldi temp1, 0 					; connected to PE4 (externally labelled PE2)
	sts OCR3AH, temp1
	ldi temp1, 0
	sts OCR3AL, temp1
	ldi temp1, 50
	sts targetrps, temp1
	clr temp1
	sts targetrps + 1, temp1

	ldi temp1, (1 << CS30) 		; set the Timer3 to Phase Correct PWM mode. 
	sts TCCR3B, temp1
	ldi temp1, (1 << WGM31)|(1<< WGM30)|(1<<COM3B1)|(1<<COM3A1)
	sts TCCR3A, temp1

	sei

halt:
	jmp halt

RIGHT_BUTTON:
	push temp1
	push temp2

	; debounce
	lds temp1, button_flag
	cpi temp1, 1
	breq RIGHT_BUTTON_EPILOGUE

	; ensure targetrps < 400
	lds temp1, targetrps
	cpi temp1, low(400)
	lds temp1, targetrps + 1
	ldi temp2, high(400)
	cpc temp1, temp2
	brsh RIGHT_BUTTON_max

	; + 20 rps
	lds temp1, targetrps
	ldi temp2, 5
	add temp1, temp2
	sts targetrps, temp1
	lds temp1, targetrps + 1
	ldi temp2, 0
	adc temp1, temp2
	sts targetrps + 1, temp1
	jmp RIGHT_BUTTON_Flag

	RIGHT_BUTTON_max:
	ldi temp1, low(400)
	sts targetrps, temp1
	ldi temp1, high(400)
	sts targetrps + 1, temp1

	RIGHT_BUTTON_Flag:
	ldi temp1, 1
	sts button_flag, temp1
	ldi temp1, 1 << TOIE1 		; enable timer
	sts TIMSK1, temp1

	RIGHT_BUTTON_EPILOGUE:
	pop temp2
	pop temp1
	reti

LEFT_BUTTON:
	push temp1

	; debounce
	lds temp1, button_flag
	cpi temp1, 1
	breq LEFT_BUTTON_EPILOGUE

	; ensure targetrps > 0
	lds temp1, targetrps
	cpi temp1, 0
	lds temp1, targetrps + 1
	ldi temp2, 0
	cpc temp1, temp2
	breq LEFT_BUTTON_Flag

	; - 20 targetrps
	lds temp1, targetrps
	subi temp1, 5
	sts targetrps, temp1
	lds temp1, targetrps + 1
	sbci temp1, 0
	sts targetrps + 1, temp1

	LEFT_BUTTON_Flag:
	ldi temp1, 1
	sts button_flag, temp1
	ldi temp1, 1 << TOIE1 		; enable timer
	sts TIMSK1, temp1

	LEFT_BUTTON_EPILOGUE:
	pop temp1
	reti

BUTTON_CLR:
	push temp1

	sei
	rcall sleep_1ms
	cli

	clr temp1 					; set button flag to 0
	sts button_flag, temp1
	ldi temp1, 0 << TOIE1 		; disable timer
	sts TIMSK1, temp1

	pop temp1
	reti

HOLES:
	push temp1

	ldi temp1, 1
	add rpsL, temp1
	ldi temp1, 0
	adc rpsH, temp1
	
	HOLES_EPILOGUE:
	pop temp1
	reti

Timer0OVF:						; interrupt subroutine to Timer0
	in temp1, SREG
	push temp1 					; save conflict registers
	push temp2
	push r25
	push r24

	lds r24, TempCounter 		; load value of temporary counter
	lds r25, TempCounter + 1
	adiw r25:r24, 1 			; increase temporary counter by 1

	cpi r24, low(3906)			; here use 7812 = 10^6/128 for 1 second
	ldi temp1, high(3906) 		; use 3906 for 0.5 seconds
	cpc r25, temp1
	breq pc+2 					; if they're not equal, jump to notSecond
    rjmp notSecond
    
	; here we know 0.5 seconds has passed: DO THINGS
	ldi address, LCD_HOME_LINE
	asr rpsH 				; need to multiply rps by 2 to give revolutions per SECOND
	ror rpsL 				; need to divide by 4 to account for 4 holes
	do_lcd_command LCD_DISP_CLR
	rcall write16

	push rpsL
	push rpsH
	lds rpsH, OCR3AH
	lds rpsL, OCR3AL
	ldi address, 136
	rcall write16
	pop rpsH
	pop rpsL
	
	lds temp1, targetrps
	lds temp2, targetrps + 1
	sub rpsL, temp1
	sbc rpsH, temp2 			; rps - targetrps
	in temp1, SREG
	push temp1
	
	ldi address, 176 			; write the difference to LCD
	rcall write16
	ldi step, RPS_UPDATE
	cpi rpsL, 10
	ldi temp3, 10
	cpc rpsH, temp3
	ldi temp3, RPS_UPDATE
	add step, temp3
	
	pop temp1
	out SREG, temp1
	breq Timer0OVF_DispTarget ; if rps == targetrps go to timer0OVF_DispTarget
	brsh Timer0OVF_Dec 			; if rps >= targetrps, go to decrease
	
	; else we know rps < targetrps so increase OCR3B by RPS_UPDATE
	ldi temp1, 0b00101000
	out PORTC, temp1

	lds temp1, OCR3AL
	lds temp2, OCR3AH
	add temp1, step
	clr temp3
	adc temp2, temp3
	sts OCR3AH, temp2
	sts OCR3AL, temp1
	jmp timer0OVF_DispTarget

	Timer0OVF_Dec: ; if rps > targetrps decrease OCR3B by RPS_UPDATE
	ldi temp1, 0b11111111
	out PORTC, temp1

	lds temp1, OCR3AL
	sub temp1, step
	lds temp2, OCR3AH
	sbci temp2, 0
	sts OCR3AH, temp2
	sts OCR3AL, temp1
	
	Timer0OVF_DispTarget:
	lds rpsL, targetrps
	lds rpsH, targetrps + 1
	ldi address, LCD_SEC_LINE
	rcall write16
	clr rpsL
	clr rpsH

	; timer stuff
	clr temp1
	sts TempCounter, temp1		; reset temporary counter
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
		pop temp2
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

; Writes 16-bit number in rpsH:rpsL to the LCD in decimal
write16:
	push rpsH
	push rpsL
	push temp1

	clr temp1
	sts isPrinted, temp1 							; 0 if not printed, 1 if printed
	sts digit5, temp1
	sts digit4, temp1
	sts digit3, temp1
	sts digit2, temp1
	sts digit, temp1

	write10000s:
		mov temp1, rpsL
		cpi temp1, low(10000) 						; check that rpsH:rpsL > 10000
		ldi temp1, high(10000)
		cpc rpsH, temp1
		brlo write1000s
	
		loop10000s:
			mov temp1, rpsL
			cpi temp1, low(10000) 					; if < 10000, display ten thousands digit
			ldi temp1, high(10000)
			cpc rpsH, temp1
			brlo display10000s

			mov temp1, rpsL						; decrement parameter by 10000
			subi temp1, low(10000)
			mov rpsL, temp1
			mov temp1, rpsH
			sbci temp1, high(10000)
			mov rpsH, temp1
		   
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
		mov temp1, rpsL
		cpi temp1, low(1000) 						; check that rpsH:rpsL > 1000
		ldi temp1, high(1000)
		cpc rpsH, temp1
		brlo space1000s
	
		loop1000s:
			mov temp1, rpsL
			cpi temp1, low(1000) 					; if < 1000, display thousands digit
			ldi temp1, high(1000)
			cpc rpsH, temp1
			brlo display1000s

			mov temp1, rpsL					; decrement parameter by 1000
			subi temp1, low(1000)
			mov rpsL, temp1
			mov temp1, rpsH
			sbci temp1, high(1000)
			mov rpsH, temp1
		   
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
		mov temp1, rpsL
		cpi temp1, low(100) 						; check that rpsH:rpsL > 100
		ldi temp1, high(100)
		cpc rpsH, temp1
		brlo space100s

		loop100s:
			mov temp1, rpsL
			cpi temp1, low(100) 					; if < 100, display hundreds digit
			ldi temp1, high(100)
			cpc rpsH, temp1
			brlo display100s

			mov temp1, rpsL						; decrement parameter by 100
			subi temp1, low(100)
			mov rpsL, temp1
			mov temp1, rpsH
			sbci temp1, high(100)
			mov rpsH, temp1
		   
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
		mov temp1, rpsL
		cpi temp1, 10 								; check that rpsH:rpsL >= 10
		brlo space10s

		loop10s:
			mov temp1, rpsL
			cpi temp1, 10 							; if < 10, display tens digit
			brlo display10s

			mov temp1, rpsL						; decrement parameter by 10
			subi temp1, low(10)
			mov rpsL, temp1
			mov temp1, rpsH
			sbci temp1, high(10)
			mov rpsH, temp1

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
		mov temp1, rpsL
		subi temp1, -'0' 							; convert to ASCII
		do_lcd_command_reg address
		inc address	
		do_lcd_data_reg temp1

	write16Epilogue:
	pop temp1
	pop rpsL
	pop rpsH
	ret
