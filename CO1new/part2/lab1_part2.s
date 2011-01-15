/* Program that finds the largest number in a list of integers	    */

.equ LIST, 0x500		  /* Starting address of the list		    */

.global _start
_start:
	movia	r4, LIST	  /* r4 points to the start of the list	    */
	ldw	r5, 4(r4)	  /* r5 is a counter, initialize it with n    */
	addi	r6, r4, 8	  /* r6 points to the first number		    */
 	ldw	r7, (r6)	  /* r7 holds the largest number found so far */
		
LOOP:
	subi	r5, r5, 1	  /* Decrement the counter 			    */
	beq	r5, r0, DONE  /* Finished if r5 is equal to 0		    */
	addi	r6, r6, 4	  /* Increment the list pointer		    */
	ldw	r8, (r6)	  /* Get the next number			    */
	bge	r7, r8, LOOP  /* Check if larger number found		    */
	add	r7, r8, r0	  /* Update the largest number found	    */
	br	LOOP
DONE:
	stw	r7, (r4)	  /* Store the largest number into RESULT	    */

STOP:	
	br	STOP		  /* Remain here if done			    */

.org	0x500
RESULT:
.skip	4			  /* Space for the largest number found	    */
N:
.word 7			  /* Number of entries in the list		    */
NUMBERS:
.word	4, 5, 3, 6, 1, 8, 2	/* Numbers in the list */

.end
