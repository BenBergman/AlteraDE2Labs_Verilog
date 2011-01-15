.include "nios_macros.s"

.text
.equ TEST_NUM, 0x00abcdef /* The number to be tested */

.global _start
_start:

  movia   r1, 0x10000
  ldbuio  r0, 0x1000(r1)

  stbio   r2, 0x1010(r1)

END:
  br      END /* Wait here once the program has completed */

.end


