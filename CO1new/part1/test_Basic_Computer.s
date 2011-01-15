.include "address_map.s"
.equ RIBBON_CABLE_INSTALLED, 0

/* This program exercises various features of the DE2 basic computer, as a test and
 * to provide and example. 
 *
 * It performs the following: 
 * 1. tests the SRAM repeatedly
 * 2. scrolls some text on the hex displays, which alternates between "dE2" and
 * "PASSEd" if there is no SRAM error detected, and "Error" if an error is detected 
 * 3. flashes the green LEDs. The speed of flasing and scrolling for 2. is controlled
 * by timer interrupts
 * 4. connects the SW switches to red LEDs
 * 5. handles pushbutton interrupts: pushing KEY1 speeds up the scrolling of text, 
 * pushing KEY2 slows it down, and pushing KEY3 stops the scrolling
 * 6. can test the JP1, JP2 expansion ports, if a ribbon cable is installed between them
 * 7. echos text received from the JTAG UART (such as text typed in the
 * terminal window of the Monitor Program) to the serial port UART, and vice versa
 */

	.text
	.global _start
_start:
	/* set up sp and fp */
	movia 	sp, 0x007FFFFC			# stack starts from largest memory address 
	mov 		fp, sp

	/* initialize 7-segment displays buffer (dE2 just before being visible on left side) */
	movia 	r16, DISPLAY_BUFFER
	movi		r17, 0xde2
	stw		r17, 0(r16)
	stw		zero, 4(r16)
	stw		zero, 8(r16)

	/* initialize green LED values */
	movia		r2, 0x55555555
	movia		r16, GREEN_LED_PATTERN
	stw		r2, 0(r16)

	/* initialize delay counter used to decide when to change displayed text */
	movia		r16, EIGHT_SEC
	stw		zero, 0(r16)

	/* initialize display toggle */
	movia		r16, DISPLAY_TOGGLE
	stw		zero, 0(r16)

	/* shift direction will be stored in SHIFT_DIRECTION, where 0 = left and 1 = right */
	movi		r2, 1
	movia		r16, SHIFT_DIRECTION
	stw		r2, 0(r16)

	/* start interval timer, enable its interrupts */
	movia		r16, INTERVAL_TIMER_BASE
	movi		r15, 0b0111		# START = 1, CONT = 1, ITO = 1 
	sthio		r15, 4(r16)

	/* enable pushbutton interrupts */
	movia		r16, PUSHBUTTON_BASE
	movi		r15, 0b01110		# set all 3 interrupt mask bits to 1 (bit 0 is Nios II Reset) 
	stwio		r15, 8(r16)

	/* enable processor interrupts */
	movi		r15, 0b011		# enable interrupts for timer and pushbuttons 
.if RIBBON_CABLE_INSTALLED
	ori		r15, r15, 0b1000000000000	# also enable interrupts for expansion port (JP2) 
.endif
	wrctl		ienable, r15
	movi		r15, 1
	wrctl		status, r15

	/* loop that tests the SRAM and keeps displays updated */
	movia		r15, 0x55555555
	movia		r17, SRAM_END
DO_DISPLAY:
	movia		r16, SRAM_BASE
	movia		r17, SRAM_END
MEM_LOOP:
	call 		UPDATE_HEX_DISPLAY
	call 		UPDATE_RED_LED			# read slider switches and show on red LEDs 
	call 		UPDATE_UARTS			# update both the JTAG and serial port UARTs 
	/* only test the Expansion ports if there is a 40-pin ribbon cable connected
		between them.
	*/
.if RIBBON_CABLE_INSTALLED
	call		TEST_EXPANSION_PORTS		# returns 0 if test fails
	beq		r2, zero, SHOW_ERROR 
.endif

	stw		r15, 0(r16)
	ldw		r14, 0(r16)
	bne		r14, r15, SHOW_ERROR
	addi		r16, r16, 4
	ble		r16, r17, MEM_LOOP
	
	xori		r15, r15, 0xFFFF
	xorhi		r15, r15, 0xFFFF

	/* change 7-segment displays buffer approx every 8 seconds */
	movia		r16, EIGHT_SEC
	ldw		r17, 0(r16)
	movi		r14, 80					#  80 timer interrupts ~= 10 sec 
	ble		r17, r14, DO_DISPLAY

	stw		zero, 0(r16)			# reset delay counter used to toggle displayed text 
	/* toggle display of dE2 and PASSEd */
	movia 	r16, DISPLAY_TOGGLE
	ldw		r17, 0(r16)
	beq		r17, zero, SHOW_PASSED

	stw		zero, 0(r16)			# toggle display setting 
	/* show dE2 */
	movia 	r16, DISPLAY_BUFFER
	movi		r17, 0xdE2
	stw		r17, 0(r16)
	stw		zero, 4(r16)
	stw		zero, 8(r16)
	br 		DO_DISPLAY
SHOW_PASSED:
	movi		r17, 1
	stw		r17, 0(r16)				# toggle display setting 
	movia 	r16, DISPLAY_BUFFER
	movia		r17, 0xbA55Ed			# Passed 
	stw		r17, 0(r16)
	stw		zero, 4(r16)
	stw		zero, 8(r16)
	br 		DO_DISPLAY

SHOW_ERROR:
	movia 	r16, DISPLAY_BUFFER
	movia		r17, 0xe7787			# Error 
	stw		r17, 0(r16)
	stw		zero, 4(r16)
	stw		zero, 8(r16)
DO_ERROR:
	call 		UPDATE_HEX_DISPLAY
	br			DO_ERROR

/********************************************************************************
 * Updates the value displayed on the hex display. The value is taken from the 
 * buffer.
 *
 */
	.global UPDATE_HEX_DISPLAy
UPDATE_HEX_DISPLAY:
	subi		sp, sp, 36		# reserve space on the stack 
	/* save registers */
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw 		r15, 8(sp)
	stw 		r16, 12(sp)
	stw 		r17, 16(sp)
	stw 		r18, 20(sp)
	stw 		r19, 24(sp)
	stw 		r20, 28(sp)
	stw 		r21, 32(sp)
	addi		fp, sp, 36

	/* load hex value to display */
	movia		r15, DISPLAY_BUFFER
	ldw		r16, 4(r15)		# value to display is in second full-word of buffer 

/* Loop to fill the two-word buffer that drives the parallel port on the DE2 basic
 * computer connected to the HEX7 to HEX0 displays. The loop produces for each 4-bit
 * character in r16 a corresponding 8-bit code for the segments of the displays
*/
	movia		r17, 7
	movia		r15, HEX3_HEX0	
	movia		r19, SEVEN_SEG_DECODE_TABLE
SEVEN_SEG_DECODER:
	mov		r18, r16
	andi		r18, r18, 0x000F
	add		r20, r19, r18						# index into decode table based on character 
	add		r21, zero, zero
	ldb		r21, 0(r20)							# r21 <- 7-seg character code 
	stb		r21, 0(r15)							# store 7-seg code into buffer 

	srli		r16, r16, 4
	addi		r15, r15, 1
	subi		r17, r17, 1
	bge		r17, zero, SEVEN_SEG_DECODER

	/* write parallel port buffer words */
	movia		r15, HEX3_HEX0
	ldw		r16, 0(r15)
	movia		r17, HEX3_HEX0_BASE
	stwio		r16, 0(r17)
	ldw		r16, 4(r15)
	movia		r17, HEX7_HEX4_BASE
	stwio		r16, 0(r17)

	/* restore registers */
	ldw		ra, 0(sp)
	ldw		fp, 4(sp)
	ldw 		r15, 8(sp)
	ldw 		r16, 12(sp)
	ldw 		r17, 16(sp)
	ldw 		r18, 20(sp)
	ldw 		r19, 24(sp)
	ldw 		r20, 28(sp)
	ldw 		r21, 32(sp)
	addi		sp, sp, 36		# release the reserved stack space 

	ret

/********************************************************************************
 * Updates the value displayed on the red LEDs. The value is taken from the 
 * slider switches.
 *
 */
	.global UPDATE_RED_LED
UPDATE_RED_LED:
	/* save registers */
	subi		sp, sp, 16		# reserve space on the stack 
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw 		r15, 8(sp)
	stw 		r16, 12(sp)
	addi		fp, sp, 16

	/* load slider switch value to display */
	movia		r15, SLIDER_SWITCH_BASE
	ldwio		r16, 0(r15)		

	/* write to red LEDs */
	movia		r15, RED_LED_BASE
	stwio		r16, 0(r15)

	/* restore registers */
	ldw		ra, 0(sp)
	ldw		fp, 4(sp)
	ldw		r15, 8(sp)
	ldw		r16, 12(sp)
	addi		sp, sp, 16

	ret

/********************************************************************************
 * Reads characters received from either JTAG or serial port UARTs, and echo
 * character to both ports.
 *
 */
	.global UPDATE_UARTS
UPDATE_UARTS:
	/* save registers */
	subi		sp, sp, 28		# reserve space on the stack 
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw 		r15, 8(sp)
	stw 		r16, 12(sp)
	stw 		r17, 16(sp)
	stw 		r18, 20(sp)
	stw 		r19, 24(sp)
	addi		fp, sp, 28

	movia	r15, JTAG_UART_BASE
	movia	r19, UART_BASE

GET_CHAR:
   ldwio   r17, 0(r15)				# Check if JTAG UART has new data and 
   andi    r18, r17, 0x8000		# read in the character          
   beq     r18, r0, GET_CHAR_UART		
   andi    r16, r17, 0x00ff

/* echo character */
PUT_CHAR:
   ldwio   r17, 4(r15)					# Check if JTAG UART is ready for data 
   andhi   r17, r17, 0xffff			# Check for write space 
   beq     r17, r0, PUT_CHAR_UART	
   stwio   r16, 0(r15)					# echo the character 

PUT_CHAR_UART:
   ldwio   r17, 4(r19)					# Check if UART is ready for data 
   andhi   r17, r17, 0xffff			# Check for write space 
   beq     r17, r0, GET_CHAR_UART	
   stwio   r16, 0(r19)					# echo the character 

GET_CHAR_UART:
   ldwio   r17, 0(r19)				# Check if UART has new data and 
   andhi   r18, r17, 0xFFFF		# read in the character          
   beq     r18, r0, NO_CHAR		
   andi    r16, r17, 0x00ff

/* echo character */
   ldwio   r17, 4(r19)					# Check if UART is ready for data 
   andhi   r17, r17, 0xffff			# Check for write space 
   beq     r17, r0, PUT_CHAR_JTAG	
   stwio   r16, 0(r19)					# echo the character 

PUT_CHAR_JTAG:
   ldwio   r17, 4(r15)					# Check if JTAG UART is ready for data 
   andhi   r17, r17, 0xffff			# Check for write space 
   beq     r17, r0, NO_CHAR	
   stwio   r16, 0(r15)					# echo the character 

NO_CHAR:
	/* restore registers */
	ldw		ra, 0(sp)
	ldw		fp, 4(sp)
	ldw		r15, 8(sp)
	ldw		r16, 12(sp)
	ldw		r17, 16(sp)
	ldw		r18, 20(sp)
	ldw		r19, 24(sp)
	addi		sp, sp, 28

	ret

/********************************************************************************
 * This code tests that the JP1 and JP2 expansion ports.  The code requires that
 * the two ports be connected in parallel, which would typically be done using 
 * a 40-pin ribbon cable.
 */
	.global TEST_EXPANSION_PORTS
TEST_EXPANSION_PORTS:
	/* save registers */
	subi		sp, sp, 24		# reserve space on the stack 
	stw		ra, 0(sp)
	stw		fp, 4(sp)
	stw 		r15, 8(sp)
	stw 		r16, 12(sp)
	stw 		r17, 16(sp)
	stw 		r18, 20(sp)
	addi		fp, sp, 24

	movia		r15, JP1_EXPANSION_BASE
	movia		r16, JP2_EXPANSION_BASE
	movia		r17, 0xFFFFFFFF				# set as outputs 
	stwio		r17, 4(r15)						# makes JP1 an output
	add		r17, zero, zero				# set as inputs 
	stwio		r17, 4(r16)						# makes JP2 an input
	movia		r17, 0x55555555				# test pattern for JP1 
	stwio		r17, 0(r15)
	add		zero, zero, zero				# cycle delay to allow registers to be clocked 
	ldwio		r18, 0(r16)
	bne		r17, r18, RET_ERROR
	movia		r17, 0xAAAAAAAA				# test pattern for JP1 
	stwio		r17, 0(r15)
	add		zero, zero, zero				# cycle delay to allow registers to be clocked 
	ldwio		r18, 0(r16)
	bne		r17, r18, RET_ERROR
	movia		r17, 0x01234567				# test pattern for JP1 
	stwio		r17, 0(r15)
	add		zero, zero, zero				# cycle delay to allow registers to be clocked 
	ldwio		r18, 0(r16)
	bne		r17, r18, RET_ERROR

	add		r17, zero, zero				# set as inputs 
	stwio		r17, 4(r15)						# makes JP1 an input
	movia		r17, 0xFFFFFFFF				# set as outputs 
	stwio		r17, 4(r16)						# makes JP2 an output
	movia		r17, 0x55555555				# test pattern for JP1 
	stwio		r17, 0(r16)
	add		zero, zero, zero				# cycle delay to allow registers to be clocked 
	ldwio		r18, 0(r15)
	bne		r17, r18, RET_ERROR
	movia		r17, 0xAAAAAAAA				# test pattern for JP1 
	stwio		r17, 0(r16)
	add		zero, zero, zero				# cycle delay to allow registers to be clocked 
	ldwio		r18, 0(r15)
	bne		r17, r18, RET_ERROR
	movia		r17, 0x01234567				# test pattern for JP1 
	stwio		r17, 0(r16)
	add		zero, zero, zero				# cycle delay to allow registers to be clocked 
	ldwio		r18, 0(r15)
	bne		r17, r18, RET_ERROR
	/* restore registers */
	movi		r2, 1								# success return code
	br			RETURN

RET_ERROR:
	movi		r2, 0								# error return code
RETURN:
	ldw		ra, 0(sp)
	ldw		fp, 4(sp)
	ldw		r15, 8(sp)
	ldw		r16, 12(sp)
	ldw		r17, 16(sp)
	ldw		r18, 20(sp)
	addi		sp, sp, 24

	ret

/********************************************************************************
 * DATA SECTION
 */

	.data

/* Buffer to hold values to display on the hex display.
 * The buffer contains 3 full-words: before, visible, after
 */
	.global DISPLAY_BUFFER
DISPLAY_BUFFER:
	.fill 3, 4, 0

	.global SHIFT_DIRECTION
SHIFT_DIRECTION:
	.word 0

/* SEVEN_SEGMENT_DECODE_TABLE give the on/off settings for all segments in 
 * a single 7-seg display in the DE2 basic computer, for the characters 
 * 'blank', 1, 2, 3, 4, S, 6, r, o, 9, A, P, C, d, E, F. These values obey 
 * the digit indexes on the DE2 board 7-seg displays, and the assignment of 
 * these signals to parallel port pins in the DE2 basic computer.
*/
SEVEN_SEG_DECODE_TABLE:
	.byte 0b00000000, 0b00000110, 0b01011011, 0b01001111 
	.byte 0b01100110, 0b01101101, 0b01111100, 0b01010000
	.byte 0b01011100, 0b01100111, 0b01110111, 0b01110011 
	.byte 0b00111001, 0b01011110, 0b01111001, 0b01110001
/* HEX3_HEX0 and HEX7_HEX4 are used to hold the on/off settings for all segments in 
 * the 8 digits of 7-seg *	displays in the DE2 basic computer. The first word is 
 * written to the parallel port that drives HEX3 to HEX0, and the second word is 
 * written to the parallel port that drives HEX7 to HEX4.
*/
HEX3_HEX0:
	.word 0
HEX7_HEX4:
	.word 0

	.global GREEN_LED_PATTERN
GREEN_LED_PATTERN:
	.word 0

	.global EIGHT_SEC
EIGHT_SEC:
	.word 0

DISPLAY_TOGGLE:
	.word 0

	.end
