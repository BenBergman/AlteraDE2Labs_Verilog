.include "nios_macros.s"

.text
.equ TEST_NUM, 0x90abcdef /* The number to be tested */

.global _start
_start:

  movia   r7, TEST_NUM /* Initialize r7 with the number to be tested */
  mov     r4, r7 /* Copy the number to r4 */

STRING_COUNTER:
  mov     r2, r0 /* Initialize the counter to zero */

STRING_COUNTER_LOOP: /* Loop until the number has no more ones */
  beq     r4, r0, END_STRING_COUNTER

  srli    r5, r4, 1 /* Calculate the number for ones by shifting the */
  and     r4, r4, r5 /* number by 1 and anding the result with itself. */
  addi    r2, r2, 1 /* Increment the counter. */
  br      STRING_COUNTER_LOOP

END_STRING_COUNTER:
  mov     r16, r2 /* Store the result into r16 */

END:
  br      END /* Wait here once the program has completed */
.end

