.include "nios_macros.s"
.include "address_map.s"

/*****************************************************************************
 * Pushbutton - Interrupt Service Routine                                
 *   Divide or multiply DE2 delay by 2
 *                                                                          
 * r10 - Pushbutton
******************************************************************************/
	.global PUSHBUTTON_ISR
PUSHBUTTON_ISR:
	subi		sp, sp, 24		# reserve space on the stack 
   stw		ra, 0(sp)
   stw		fp, 4(sp)
   stw		r10, 8(sp)
   stw		r11, 12(sp)
   stw		r12, 16(sp)
   stw		r13, 20(sp)
	addi		fp, sp, 24


	/* get the current timer counter value in case we need to change it */

	/* stop interval timer */
	movia		r10, INTERVAL_TIMER_BASE
	movi		r12, 0b01000		# STOP = 1, START = 0, CONT = 0, ITO = 0 
	sthio		r12, 4(r10)

	/* read the 32-bit counter start value from the 16-bit timer registers */
	ldhio		r12, 0xC(r10)		# high half word of counter start 
	andi		r12, r12, 0xFFFF
	slli		r12, r12, 16
	ldhio		r13, 8(r10)			# low half word of counter start 
	andi		r13, r13, 0xFFFF
	or			r12, r13, r12

	movia		r10, PUSHBUTTON_BASE
	ldwio		r11, 0xC(r10)		# Check edge capture register to see 
										#  which KEY was pressed 
	stwio		r0,  0xC(r10)		# Clear the interrupt                   

CHECK_KEY1:
	andi		r13, r11, 0b0010	# check KEY1 
	beq		r13, zero, CHECK_KEY2

	/* double the timer frequency */
	srli		r12, r12, 1			# halves the timer period 
	movia		r10, 0x2FAF0
	bge		r12, r10, CHECK_KEY2
	mov		r12, r10				# avoid too small a timer period 

CHECK_KEY2:
	andi		r13, r11, 0b0100	# check KEY2 
	beq		r13, zero, CHECK_KEY3

	/* half the timer period */
	slli		r12, r12, 1			# doubles the timer period 
	ori		r12, r12, 1

CHECK_KEY3:
	andi		r13, r11, 0b1000		# check KEY3 

END_PUSHBUTTON_ISR:
	/* store the new counter values */
	movia		r10, INTERVAL_TIMER_BASE
	sthio		r12, 8(r10)			# store the adjusted low half word of counter start 
	srli		r12, r12, 16
	sthio		r12, 0xC(r10)		# high half word of counter start 

	/* restart interval timer, unless KEY3 was pressed */
	bne		r13, zero, DONT_START
	movi		r12, 0b0111			# STOP = 0, START = 1, CONT = 1, ITO = 1 
	sthio		r12, 4(r10)

DONT_START:
   ldw		ra,  0(sp)			# Restore all used register to previous 
   ldw		fp,  4(sp)
   ldw		r10, 8(sp)
   ldw		r11, 12(sp)
   ldw		r12, 16(sp)
   ldw		r13, 20(sp)
   addi		sp,  sp, 24

	ret

	.end
	
