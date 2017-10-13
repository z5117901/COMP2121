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


; Replace with your application code
start:
    inc r16
    rjmp start


