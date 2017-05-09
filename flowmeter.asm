;   Flowmeter - fuel consumption meter device
;   Copyright (C) 2017  Alexandr Gorodinski

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 3 of the License, or
;   (at your option) any later version.

;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.

;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software Foundation,
;   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA


.include "8535def.inc"
.include "LCD4_macro.inc"
.list

.def ansl = R0	;regs to get answer from math routines
.def ansh = R1

.def temp = R18  ;temp low
.def temp2 = R19 ;temp high
.def bc = R20
.def op2 = R21	;reg for pass second operand to math routines

.def tens = R22 ;	;use that in bin to ascii conversion
.def hundreds = R23 ;
.def k1 = R24
.def k10 = R25

.equ kdel = 3906 ;we get 1 int per second with that value
;.equ kdel = 300 ; uncomment to run faster for virtual debug

.dseg

.org 0x60

;naming of vars is simple: "what" and "for what" we count

;vars for litre per hour calc:
timeflow: .byte 1		;measuring time for l/h flow calc
flowtime: .byte 1		;measuring flow for l/h clac

;vars for kilometer per hour calc:
timespeed: .byte 1		;measuring time for km/h speed calc
pathspeed: .byte 1		;measuring path for km/h speed calc

;vars for litre per kilometer calc:
pathflowh: .byte 1		;measuring path l/km calc, high
pathflowl: .byte 1		;and low
flowpath: .byte 1		;measuring flow for l/km calc

;output var for l/h
litrehour: .byte 1

;output var for km/h
kmh: .byte 1

;output var for l/km
lkm: .byte 1

;vars for storing taximeter state

;cyclic counters for small value
taxkml:	.byte	1
taxkmh:	.byte	1
taxmin:	.byte	1
taxfuelpulsel:	.byte	1
taxfuelpulseh:	.byte	1

;path
taxpathl: .byte 1	;high and low bytes of path
taxpathh: .byte 1

;time
taxtimel: .byte 1
taxtimeh: .byte 1	;high and low bytes of time

;fuel
taxlitre: .byte 1

;cost
taxcosttimeh: .byte 1	;kopeiki for time high
taxcosttimel: .byte 1	;and low
taxcostpathh: .byte 1	;kopeiki for path high
taxcostpathl: .byte 1	;and low

;menu position(screen number)
screennumber:	.byte 1
	
.cseg
.org 0


start:	rjmp init		;0 reset
		rjmp 	pathint	;1			int0 - pulses form gearbox
		rjmp	flowint	;2			int1 - pulses from flow meter
		reti			;3
		reti			;4
		reti			;5
		rjmp tim1compa	;6			timer1
		reti			;7
		reti			;8
		reti			;9
		reti			;10
		reti			;11
		reti			;12
		reti			;13
		reti			;14
		reti			;15
		reti			;16
		reti			;17


init:	ldi temp, low(RAMEND)		;stack init
		out SPL, temp
		ldi temp, high(RAMEND)
		out SPH, temp


		ldi temp, 0					;port D on input
		out DDRD, temp
		

		ldi temp, 0xFF				
;		out PORTC, temp
;		out DDRC, temp
		out PORTD, temp				;some resistor

		ldi temp, 0xC0				;enables both ext interrupts
		out GIMSK, temp				;C0 is 11000000
									;and no more bits in that reg

		ldi temp, 0x0F				;configure edges of ext interrupts
		out MCUCR, temp				;00001111 is 0F - rising edges of both
		
		ldi temp, 0x00				;ensure that everything disconnected
		out TCCR1A, temp			;from pins(as in default conf)
		ldi temp, 0x0D
;		ldi temp, 0x09 ;lets run faster for virt debugger
		out TCCR1B, temp
		ldi temp, high(kdel)
		out OCR1AH, temp
		ldi temp, low(kdel)
		out OCR1AL, temp

		ldi temp, 0b00010000
		out TIMSK, temp
		

		ldi temp, 0x80
		out ACSR, temp

		ldi temp, 0x00			;init everything with zeroes
		sts timeflow, temp
		sts flowtime, temp

		sts timespeed, temp
		sts pathspeed, temp

		sts pathflowh, temp
		sts pathflowl, temp
		sts flowpath, temp


		sts litrehour, temp
		sts kmh, temp
		sts lkm, temp

		sts	taxkml, temp
		sts	taxkmh, temp
		sts	taxmin, temp
		sts	taxfuelpulsel, temp
		sts	taxfuelpulseh, temp

		sts taxpathl, temp
		sts taxpathh, temp

		sts taxtimel, temp
		sts taxtimeh, temp

		sts taxlitre, temp

		sts taxcosttimeh, temp
		sts taxcosttimel, temp
		sts taxcostpathh, temp
		sts taxcostpathl, temp

		sts screennumber, temp

INIT_LCD

;			WR_DATA 0x5F  ;draw a snail _@/"
;			WR_DATA 0x40
;			WR_DATA 0x2F
;			WR_DATA 0x22


main:	sei			;int enable

endless: rjmp endless


flowint:	push temp
			in temp, SREG
			push temp

			lds temp, flowtime	;load increase and store flow for TIME
			inc temp
			sts flowtime, temp	;reset occurs by timeflow counter
								;when it reaches the treshold


			lds temp, flowpath	;load increase and store flow for PATH
			inc temp
			sts flowpath, temp

counttaxpulse:
			lds ZH, taxfuelpulseh		;count fuelpulses
			lds ZL,	taxfuelpulsel
			adiw ZL, 0x01
			sts taxfuelpulsel, ZL
			sts taxfuelpulseh, ZH

			rjmp exf


exf:		pop temp
			out SREG,temp
			pop temp
			reti

pathint:	push temp
			in temp, SREG
			push temp

			lds temp, pathspeed	;load increase and store path for speed
			inc temp
			sts pathspeed, temp	;calc km/h and reset occurs 
								;by timespeed counter
								;when it reaches the treshold
			

			lds ZH, pathflowh	;load two bytes of path for flow calc
			lds ZL, pathflowl
			adiw ZL, 0x01		;add 1 to register pair
			ldi	temp2, 0x01		;load high(d500)
			cpi ZL, 0xF4			;if pathflow greater than dist(d500)
			cpc ZH, temp2
			breq resetpathflow  ;branch to reset, calc and display
retpf:		sts pathflowl, ZL
			sts pathflowh, ZH
			
;			rjmp exp  дурак!

counttaxkm:
			lds ZH, taxkmh		;count kilometre
			lds ZL,	taxkml
			adiw ZL, 0x01
			ldi temp2, 0x03
			cpi ZL, 0xE8			;reset on d1000
			cpc ZH, temp2
			breq counttaxpath
retctp:		sts taxkml, ZL
			sts taxkmh, ZH

			rjmp exp

counttaxpath:
			lds ZH, taxpathh	;add every one km to taxpath
			lds ZL, taxpathl
			adiw ZL, 0x01
			sts taxpathl, ZL
			sts taxpathh, ZH
			ldi ZL, 0x00
			ldi ZH, 0x00
			rjmp retctp


resetpathflow:
			lds temp, flowpath	;calculate lkm and also
			ldi op2, 0xEB		;reset corresponding pathflow(l/h)
			rcall mul8x8
			sts lkm, ansh
			ldi temp, 0x00
			ldi ZL, 0x00
			ldi ZH, 0x00
			sts flowpath, temp
			rjmp retpf

			
exp:		pop temp
			out SREG,temp
			pop temp
			reti
			

tim1compa:	push temp		;saving regs to stack
			in temp, SREG
			push temp

;chkbtn:		;check buttons
;			
			sbis PIND, 5	;if button 4 pressed
			rjmp menuinc	;jump to menu pager

exmi:		sbis PIND, 4	;if button 5 pressed
			rjmp resettax	;jump to taximeter reset

exrt:		lds temp, taxmin	;count seconds to get minute
			inc temp
			cpi temp, 0x3B		;d60
			brsh counttaxtime
retctt:		sts	taxmin, temp
			rjmp inctf

counttaxtime:
			lds ZH, taxtimeh	;add every one minute to taxtime
			lds ZL, taxtimel
			adiw ZL, 0x01
			sts taxtimel, ZL
			sts taxtimeh, ZH
			ldi temp, 0x00
			rjmp retctt

inctf:		lds temp, timeflow	;read flow timer value from RAM
			inc temp			;increasing it
			cpi temp, 0x1E		;if timeflow greater than max
			brsh resettimeflow  ;branch to reset
rettf:		sts timeflow, temp	;storing it

			lds temp, timespeed	;the same for speed timer
			inc temp
			cpi temp, 0x0A
			brsh resettimespeed
retts:		sts timespeed, temp

			rjmp ext1

resettimeflow:
			lds temp, flowtime
			ldi op2, 0x8D
			rcall mul8x8
			sts litrehour, ansh
			ldi temp, 0x00
			sts flowtime, temp	;reseting another couner
			rjmp rettf			;timeflow itself resets by rettf


resettimespeed:
			lds temp, pathspeed
			ldi op2, 0x5c		;load 92 for speed calc
			rcall mul8x8
			sts kmh, ansh
			ldi temp, 0x00
			sts pathspeed, temp	;the same as for reset tf
			rjmp retts

menuinc:
			ldi r17,(1<<LCD_CLR)
			rcall cmd_wr
			lds temp, screennumber	;get screen number from ram
			inc temp				;increase it
			cpi temp, 0x03			;check for cycle to initial screen
			brsh resetmenu			;jump to reset
			sts	screennumber, temp
			rjmp exmi				;or just return back

resetmenu:	ldi temp, 0x00
			sts screennumber, temp
			rjmp exmi

resettax:	ldi temp, 0x00
			sts taxpathl, temp
			sts taxpathh, temp

			sts taxtimel, temp
			sts taxtimeh, temp

			sts taxcosttimeh, temp
			sts taxcosttimel, temp
			sts taxcostpathh, temp
			sts taxcostpathl, temp

			sts	taxfuelpulsel, temp
			sts	taxfuelpulseh, temp

			sts taxlitre, temp

			rjmp exrt

ext1:		rcall drawall
			pop temp
			out SREG,temp
			pop temp
			reti

drawall:
			lds temp, screennumber
			cpi temp, 0x00
			breq draw0
			cpi temp, 0x01
			breq draw1
			cpi temp, 0x02
			breq draw2
			
			rjmp drawex

draw2:		lds temp, taxfuelpulsel
			lds temp2, taxfuelpulseh
			rcall longb2a
			ldi		r17,(1<<LCD_DDRAM)|(0x00)
			rcall cmd_wr
			mov r17, k10
			rcall data_wr
			mov r17, k1
			rcall data_wr
			mov r17, hundreds
			rcall data_wr
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr


			rjmp drawex

draw1:		lds temp, taxpathl
			lds temp2, taxpathh
			rcall longb2a
			ldi		r17,(1<<LCD_DDRAM)|(0x00)
			rcall cmd_wr
			mov r17, k10
			rcall data_wr
			mov r17, k1
			rcall data_wr
			mov r17, hundreds
			rcall data_wr
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr

			lds temp, taxtimel
			lds temp2, taxtimeh
			rcall longb2a
			ldi		r17,(1<<LCD_DDRAM)|(0x40)
			rcall cmd_wr
			mov r17, k10
			rcall data_wr
			mov r17, k1
			rcall data_wr
			mov r17, hundreds
			rcall data_wr
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr


			rjmp drawex

draw0:		lds temp, timespeed
			rcall b2a
			ldi		r17,(1<<LCD_DDRAM)|(0x00)	;set to zero position on disp
			rcall cmd_wr					;call pocedure for that
			mov r17, hundreds				;value to register
			rcall data_wr					;cal procedure for display it
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr

			lds temp, timeflow
			rcall b2a
			ldi		r17,(1<<LCD_DDRAM)|(0x05)	;set to zero position on disp
			rcall cmd_wr					;call pocedure for that
			mov r17, hundreds				;value to register
			rcall data_wr					;cal procedure for display it
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr

			lds temp, pathflowl
			lds temp2, pathflowh
			rcall longb2a
			ldi		r17,(1<<LCD_DDRAM)|(0x0A)
			rcall cmd_wr
			mov r17, k10
			rcall data_wr
			mov r17, k1
			rcall data_wr
			mov r17, hundreds
			rcall data_wr
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr

			lds temp, kmh
			rcall b2a
			ldi		r17,(1<<LCD_DDRAM)|(0x40)	;set to zero position on disp
			rcall cmd_wr					;call pocedure for that
			mov r17, hundreds				;value to register
			rcall data_wr					;cal procedure for display it
			mov r17, tens
			rcall data_wr
			mov r17, temp
			rcall data_wr

			lds temp, litrehour
			rcall b2a
			ldi		r17,(1<<LCD_DDRAM)|(0x45)	;set to zero position on disp
			rcall cmd_wr					;call pocedure for that
			mov r17, hundreds				;value to register
			rcall data_wr					;cal procedure for display it
			mov r17, tens
			rcall data_wr
			ldi r17, 0x2E
			rcall data_wr
			mov r17, temp
			rcall data_wr

			lds temp, lkm
			rcall b2a
			ldi		r17,(1<<LCD_DDRAM)|(0x4A)	;set to zero position on disp
			rcall cmd_wr					;call pocedure for that
			mov r17, hundreds				;value to register
			rcall data_wr					;cal procedure for display it
			mov r17, tens
			rcall data_wr
			ldi r17, 0x2E
			rcall data_wr
			mov r17, temp
			rcall data_wr
			
drawex:			ret


b2a:	ldi hundreds, $2F		;Init ASCII conversion ('0'-1)
		loop100:  inc hundreds	;+1 hundred
		subi temp, $64
		brcc loop100 ;if temp >=100 subtract again
		subi temp, $9C  ;subtract -100 (add 100)

		ldi tens, $2F			;Init ASCII conversion ('0'-1)
		loop10:  inc tens		;+1 ten
		sbci temp, $0A
		brcc loop10 ;if temp >=100 subtract again
		subi temp, $F6  ;subtract -100 (add 100)


		subi temp, $D0	;ones stays here

		ret

longb2a:		ldi k10, 0x2F
longloop10k:	inc k10
			subi temp, 0x10
			sbci temp2, 0x27
			brcc longloop10k
			subi temp, 0xF0
			sbci temp2, 0xD8

			ldi k1, 0x2F
longloop1k:		inc k1
			subi temp, 0xE8
			sbci temp2, 0x03
			brcc longloop1k
			subi temp, 0x18
			sbci temp2, 0xFC

			ldi hundreds, 0x2F
longloop100:	inc hundreds
			subi temp, 0x64
			sbci temp2, 0x00
			brcc longloop100
			subi temp, 0x9C
			sbci temp2, 0xFF

			ldi tens, 0x2F
longloop10:		inc tens
			subi temp, 0x0A
			brcc longloop10
			subi temp, 0xF6
		
			subi temp, 0xD0

			ret

mul8x8:
			ldi bc,8
			clr ansh
			mov ansl, op2
			lsr ansl
mulloop:	brcc mulskip
			add ansh, temp
mulskip:	ror ansh
			ror ansl
			dec bc
			brne mulloop
			
			ret



.include "LCD4.asm"
