;IMPORTANT NOTICE: 
;The labels on PORTL are reversed, i.e., PLi is actually PL7-i (i=0, 1, ¡­, 7).  

;Board settings: 
;Connect the four columns C0~C3 of the keypad to PL3~PL0 of PORTL and the four rows R0~R3 to PL7~PL4 of PORTL.
;Connect LED0~LED7 of LEDs to PC0~PC7 of PORTC.
    
; For I/O registers located in extended I/O map, "IN", "OUT", "SBIS", "SBIC", 
; "CBI", and "SBI" instructions must be replaced with instructions that allow access to 
; extended I/O. Typically "LDS" and "STS" combined with "SBRS", "SBRC", "SBR", and "CBR".

.include "m2560def.inc"
.def temp =r16
.def row =r17
.def col =r18
.def mask =r19
.def temp2 =r20
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F


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


.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro


.cseg
jmp RESET

.org 0x72
RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, PORTLDIR ; columns are outputs, rows are inputs
	STS DDRL, temp     ; cannot use out
	ser temp
	out DDRC, temp ; Make PORTC all outputs
	out PORTC, temp ; Turn on all the LEDs

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
	do_lcd_command 0b00001110 ; display on,Cursor off, no blink
	do_lcd_command 0b00011000



; main keeps scanning the keypad to find which key is pressed.
main:
ldi mask, INITCOLMASK ; initial column mask
clr col ; initial column

colloop:
STS PORTL, mask ; set column to mask value (sets column 0 off)
ldi temp, 0xFF ; implement a delay so the hardware can stabilize
delay:
dec temp
brne delay
LDS temp, PINL ; read PORTL. Cannot use in 
andi temp, ROWMASK ; read only the row bits
cpi temp, 0xF ; check if any rows are grounded
breq nextcol ; if not go to the next column
ldi mask, INITROWMASK ; initialise row check
clr row ; initial row

rowloop:      
mov temp2, temp
and temp2, mask ; check masked bit
brne skipconv ; if the result is non-zero, we need to look again
rcall convert ; if bit is clear, convert the bitcode
jmp main ; and start again

skipconv:
inc row ; else move to the next row
lsl mask ; shift the mask to the next bit
jmp rowloop    
      
nextcol:     
cpi col, 3 ; check if we^Òre on the last column
breq main ; if so, no buttons were pushed,
; so start again.

sec ; else shift the column mask:
; We must set the carry bit
rol mask ; and then rotate left by a bit, shifting the carry into bit zero. We need this to make sure all the rows have pull-up resistors
inc col ; increment column value
jmp colloop ; and check the next column convert function converts the row and column given to a binary number and also outputs the value to PORTC. 
; Inputs come from registers row and col and output is in temp.

convert:
cpi col, 3 ; if column is 3 we have a letter
breq letters

cpi row, 3 ; if row is 3 we have a symbol or 0
breq symbols

cpi row, 0
breq row1

cpi row, 1
breq row2

cpi row, 2
breq row3

row1:
ldi temp, '1'
add temp, col ; add the column address
jmp convert_end

row2:
ldi temp, '4'
add temp, col ; add the column address
jmp convert_end

row3:
ldi temp, '7'
add temp, col ; add the column address
jmp convert_end


; to get the offset from 1
 ; add 1. Value of switch is
; row*3 + col + 1.
jmp convert_end

letters:
ldi temp, 'A'
add temp, row ; increment from 0xA by the row value
jmp convert_end

symbols:
cpi col, 0 ; check if we have a star
breq star
cpi col, 1 ; or if we have zero
breq zero

ldi temp, '#' ; we'll output 0xF for hash
jmp convert_end

star:
ldi temp, '*' ; we'll output 0xE for star
jmp convert_end

zero:
ldi temp, '0' ; set to zero

convert_end:
mov r22, temp
rcall lcd_data
rcall lcd_wait
rcall sleep_25ms
rcall sleep_25ms
rcall sleep_25ms
rcall sleep_100ms
ret ; return to caller


;;;;lcdddddd
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


.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4;;;;;i dont understand

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
