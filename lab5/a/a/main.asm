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

.macro



.include "m2560def.inc"

.cseg
.org 0x0000		; Reset vector is 0x0000
jmp RESET		; jump to start of reset handler
.org INT0addr	; this is the address of int0 defined by the include
jmp IRQ0		; jumps to start of handler for irq0
.org INT2addr   ; defined address
reti			; return to break point where int1 occured	

RESET: 
ldi temp, high(RAMEND)	; initialization of SP
out SPH, temp
ldi temp, low(RAMEND)
out SPL, temp

rjmp main

;;Interupt1 stuff

jmp INT2 ;;IRQ2 handgler

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

