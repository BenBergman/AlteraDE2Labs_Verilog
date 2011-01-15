/* Program that finds the largest number in a list of integers	    */

.equ LIST, 0x500		  /* Starting address of the list		    */
.equ ASCII1, 0x32
.equ ASCII2, 0x34
.equ ASCII3, 0x36
.equ ASCII4, 0x38
.equ ASCII5, 0x31
.equ ASCII6, 0x33
.equ ASCII7, 0x35
.equ ASCII8, 0x37

.equ BCD_MASK, 0x0F

.equ BCD_PACKED, 0x1000

.global _start
_start:
  
  movia r4, ASCII8
  andi r4, r4, BCD_MASK

  slli r4, r4, 4  

  movia r5, ASCII7
  andi r5, r5, BCD_MASK
  or r4, r4, r5

  slli r4, r4, 4

  movia r5, ASCII6
  andi r5, r5, BCD_MASK
  or r4, r4, r5

  slli r4, r4, 4  

  movia r5, ASCII5
  andi r5, r5, BCD_MASK
  or r4, r4, r5

  slli r4, r4, 4  

  movia r5, ASCII4
  andi r5, r5, BCD_MASK
  or r4, r4, r5

  slli r4, r4, 4  

  movia r5, ASCII3
  andi r5, r5, BCD_MASK
  or r4, r4, r5

  slli r4, r4, 4  

  movia r5, ASCII2
  andi r5, r5, BCD_MASK
  or r4, r4, r5

  slli r4, r4, 4  

  movia r5, ASCII1
  andi r5, r5, BCD_MASK
  or r4, r4, r5
  


  movia r5, BCD_PACKED
  stw r4, 0(r5)



STOP:	
	br	STOP		  /* Remain here if done			    */

.org	0x500

.end

