.include "nios_macros.s"
.include "address_map.s"

/* global variables */
.extern EIGHT_SEC
.extern GREEN_LED_PATTERN
.extern DISPLAY_BUFFER
.extern SHIFT_DIRECTION

/********************************************************************************
 * RESET SECTION
 * Note: "ax" is REQUIRED to designate the section as allocatable and executable.
 * Also, the Debug Client automatically places the ".reset" section at the reset
 * location specified in the CPU settings in SOPC Builder.
*/
	.section .reset, "ax"
	movia	r2, _start
	jmp 	r2									# branch to start function 

/********************************************************************************
 * EXCEPTIONS SECTION
 * Note: "ax" is REQUIRED to designate the section as allocatable and executable.
 * Also, the Debug Client automatically places the ".exceptions" section at the
 * exception location specified in the CPU settings in SOPC Builder.
*/
	.section .exceptions, "ax"
	.global EXCEPTION_HANDLER
EXCEPTION_HANDLER:
	subi		sp, sp, 36					# make room on the stack 
   stw		et,  0(sp)

	rdctl		et, ctl4
	beq		et, r0, SKIP_EA_DEC		# Interrupt is not external 

   subi		ea, ea, 4					# Must decrement ea by one instruction  
												#  for external interupts, so that the 
												#  interrupted instruction will be run 
SKIP_EA_DEC:
   stw		ea, 4(sp)					# Save all used registers on the Stack  
   stw		ra, 8(sp)					# needed if call inst is used 
   stw		fp, 12(sp)
   stw		r2, 16(sp)
   stw		r3, 20(sp)
   stw		r4, 24(sp)
   stw		r21, 28(sp)
   stw		r22, 32(sp)
	addi		fp,  sp, 36
	
	rdctl		et, ctl4
	bne		et, r0, CHECK_LEVEL_0	# Interrupt is an external interrupt    

NOT_EI:										# Interrupt must a unimplemented or     
	br		END_ISR							#   TRAP instruction. This code does    
												#   not handle those cases.             
CHECK_LEVEL_0:
	/* Interval timer is interrupt level 0 */
	andi		r22, et, 1
	beq		r22, r0, CHECK_LEVEL_1
	
	/* increment the delay counter used for changing the displayed message */
	movia		r22, EIGHT_SEC
	ldw		r21, 0(r22)
	addi		r21, r21, 1
	stw		r21, 0(r22)

	movia		r22, GREEN_LED_PATTERN 		# pass parameters into ISR 
	ldw		r3, 0(r22)						
	movia		r4, DISPLAY_BUFFER
	movia		r22, SHIFT_DIRECTION
	ldw		r2, 0(r22)
	
	call		INTERVAL_TIMER_ISR			
	movia		r22, GREEN_LED_PATTERN 		# store the returned values 
	stw		r3, 0(r22)
	movia		r22, SHIFT_DIRECTION
	stw		r2, 0(r22)
	br			END_ISR

CHECK_LEVEL_1:
	/* Pushbutton is interrupt level 1 */
	andi		r22, et, 0b10
	beq		r22, r0, CHECK_LEVEL_2

	call		PUSHBUTTON_ISR				
	br			END_ISR

CHECK_LEVEL_2:
	br			CHECK_LEVEL_12					# placeholder

CHECK_LEVEL_12:
	/* Expansion JP2 is interrupt level 12 */
	andi		r22, et, 0b1000000000000
	beq		r22, zero, END_ISR				
	/* this is a placeholder, so just clear the interrupt */
	movia		r22, JP2_EXPANSION_BASE 		
	stwio		zero, 12(r22)

END_ISR:
   ldw		et, 0(sp)				# Restore all used register to previous 
   ldw		ea, 4(sp)				#   values.                             
   ldw		ra, 8(sp)				# needed if call inst is used 
   ldw		fp, 12(sp)
   ldw		r2, 16(sp)
   ldw		r3, 20(sp)
   ldw		r4, 24(sp)
   ldw		r21, 28(sp)
   ldw		r22, 32(sp)
   addi		sp, sp, 36

	eret
	
