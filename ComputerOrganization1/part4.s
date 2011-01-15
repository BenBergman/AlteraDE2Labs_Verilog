.include "nios_macros.s"

.text
.equ TEST_NUM, 0x00abcdef /* The number to be tested */

.global _start
_start:

  movia   r7, TEST_NUM /* Initialize r7 with the number to be tested */
  mov     r4, r7 /* Copy the number to r4 */

  call _consecutive_ones

  mov     r16, r18 /* Copy the number to r4 */

  mov     r4, r7 /* Copy the number to r4 */
  xori    r4, r4, 0xffff
  xorhi   r4, r4, 0xffff

  call _consecutive_ones

  mov     r17, r18 /* Copy the number to r4 */

END:
  br      END /* Wait here once the program has completed */





_consecutive_ones:
  
STRING_COUNTER:
  mov     r2, r0 /* Initialize the counter to zero */

STRING_COUNTER_LOOP: /* Loop until the number has no more ones */
  beq     r4, r0, END_STRING_COUNTER

  srli    r5, r4, 1 /* Calculate the number for ones by shifting the */
  and     r4, r4, r5 /* number by 1 and anding the result with itself. */
  addi    r2, r2, 1 /* Increment the counter. */
  br      STRING_COUNTER_LOOP

END_STRING_COUNTER:
  mov     r18, r2 /* Store the result into r16 */
  ret
.end

