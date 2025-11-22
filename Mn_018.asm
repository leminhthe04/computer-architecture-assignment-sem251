.data
	file_name:	.asciiz 	"FLOAT2.BIN"
	.align 2 # align to make address of buffer is divisible by 2^2=4
	buffer:		.space      8

	first_float_str:	.asciiz "First float: "
	second_float_str:	.asciiz "Sencond float: "	
	newl:				.asciiz "\n"
	sum_str:			.asciiz "Sum: "
	nan:				.word   0x7FC00000
    neg_inf:			.word   0xFF800000
	pos_inf:			.word   0x7F800000

.include "macros.asm"

.text
.globl main

main:
	
	# open file for reading
	open_file(file_name, 0) 
	move $s0, $v0 # save file descriptor 

	# read 8 bytes
	read_file_bytes($s0, buffer, 8) 

	# close file after reading
	close_file($s0)	

	# load 2 floats in buffer to integer regs
	la $t0, buffer 
	lw $s1, 0($t0)
	lw $s2, 4($t0)

	write_string(first_float_str)
	write_float_from_int_reg($s1)
	write_string(newl)
	write_string(second_float_str)
	write_float_from_int_reg($s2)
	write_string(newl)
	
	# move the floats to a1 and a2 registers as the arguments of sum function
	move $a1, $s1
	move $a2, $s2
	jal sum
	move $s3, $v0 # get the return value of sum function (stored in $v0) 

	write_string(sum_str)
	write_float_from_int_reg($s3)

	exit



# function to add two floats without using any float operators.
# params:
#	a1: 4 bytes of the first float stored in integer register
#   a2: 4 bytes of the second float stored in integer register
# return:
#   v0: 4 bytes result is the sum of the two floats stored in integer register 
sum:
	addi $sp, $sp, -40
	sw $a0, 0($sp)
	sw $v1, 4($sp)
	sw $t0, 8($sp)
	sw $ra, 12($sp)
	sw $t1, 16($sp)
	sw $t2, 20($sp)
	sw $t3, 24($sp)
	sw $t4, 28($sp)
	sw $t5, 32($sp)
	sw $t6, 36($sp)

	## split a float into 3 part: sign, exponent and mantissa ##

	# make the 1st float is the argument of `split` function 
	move $a0, $a1
	jal split
	# save return values
	move $t1, $v0
	move $t2, $v1
	move $t3, $t0
	
	# make the 1st float is the argument of `split` function
	move $a0, $a2
	jal split
	# save return values 
	move $t4, $v0
	move $t5, $v1
	move $t6, $t0

	addi $sp, $sp, -20
	sw $a1, 0($sp)
	sw $a2, 4($sp)
	sw $a3, 8($sp)
	sw $t8, 12($sp)
	sw $t9, 16($sp)

	
	## check INF, NaN ##

	# check if 1st float is +-INF or NaN
	move $a1, $t1
	move $a2, $t2
	move $a3, $t3
	jal check_inf_nan 
	move $t8, $v0 # save return value of `check_inf_nan`

	# check if 2nd float is +-INF or NaN
	move $a1, $t4
	move $a2, $t5
	move $a3, $t6
	jal check_inf_nan 
	move $t9, $v0

	# if any float is NaN, sum is NaN
	beq $t8, 2, sum_is_nan
	beq $t9, 2, sum_is_nan
	
	# check other special cases (+INF + +INF, +INF + -INF,...)
	beqz $t8, first_is_normal
	beq  $t8, -1, first_is_neg_inf
	j first_is_pos_inf


  first_is_normal:
	beq  $t9, -1, sum_is_neg_inf
	beq  $t9,  1, sum_is_pos_inf
	j sum_is_normal
  
  first_is_neg_inf:
	beq  $t9, -1, sum_is_neg_inf
	beq  $t9,  1, sum_is_nan
	j sum_is_neg_inf
  
  first_is_pos_inf:
	beq  $t9, -1, sum_is_nan
	beq  $t9,  1, sum_is_pos_inf
	j sum_is_pos_inf


  sum_is_normal:
	## check if two floats are oppsite ## 
	jal check_opposite

	# if return value of `check_opposite` equals 1, the two float
	# are opposite, sum of them equals 0
	beqz $v0, not_opposite 

	j sum_is_zero
	

  not_opposite:

	## 1. standardize exponent and mantissa of two floats ##

	# make arguments of `standardize` function
	move $a0, $t2
	move $a1, $t3
	
	move $a2, $t5
	move $a3, $t6

	jal standardize

	# re-assign values of exponent and mantissa after standardization 
	move $t2, $a0 # exp1
	move $t3, $a1 # mant1
	move $t5, $a2 # exp2
	move $t6, $a3 # mant2

	## 2. determine the sign of sum, add two mantissa parts and adjust exponet if needed ##

	# make arguments of `add_mantissas` function
	move $a0, $t1 # sign1
	move $a1, $t3 # man1
	move $a2, $t4 # sign2
	move $a3, $t6 # man2
	move $v0, $t2 # exp1 or exp2 (they are equal)

	jal add_mantissa_parts

	## 3. concatenate 3 parts to get the final sum ##

	# get return values of `add_mantissa_parts` and pass to `concatenate`
      # return regs of `add_mantissa_parts` and arguments regs of `concatenate` are same
	jal concatenate

	# $v0 is the return reg of both `concatenate` and this function 

	j exit_sum


  sum_is_nan:
	lw $v0, nan
	j exit_sum

  sum_is_neg_inf:
	lw $v0, neg_inf
	j exit_sum

  sum_is_pos_inf:
	lw $v0, pos_inf
	j exit_sum

  sum_is_zero:
	li $v0, 0


  exit_sum:
	lw $a1, 0($sp)
	lw $a2, 4($sp)
	lw $a3, 8($sp)
	lw $t8, 12($sp)
	lw $t9, 16($sp)
	addi $sp, $sp, 20
	

	lw $a0, 0($sp)
	lw $v1, 4($sp)
	lw $t0, 8($sp)
	lw $ra, 12($sp)
	lw $t1, 16($sp)
	lw $t2, 20($sp)
	lw $t3, 24($sp)
	lw $t4, 28($sp)
	lw $t5, 32($sp)
	lw $t6, 36($sp)
	addi $sp, $sp, 40
	
	jr $ra



# function to split 32 bits represent a float 
# into 3 parts: sign, exponent and mantisssa (fraction with adding hidden 1).
# params:
#	$a0: 32 bits represent a float
# return:
#   $v0, $v1, $t0: store sign, exponent and mantisssa of the float, respectively.
split:
	
	# get 1 sign bit (at 31st bit)
    srl $v0, $a0, 31

	# get 8 exponent bits (from 23rd to 30th bit)
	andi $v1, $a0, 0x7F800000
	srl  $v1, $v1, 23

	# get 23 fraction bits (from 0th to 22nd bit)
	# and add hidden 1 to get mantissa
	andi $t0, $a0, 0x007FFFFF
    ori  $t0, $t0, 0x00800000  # add hidden 1

	jr $ra



# function to check if a float is +-INF or NaN
# params:
#	$a1: sign part
#	$a2: exponent part
#	$a3: mantissa part
# return:
#	$v0: -1 if -INF, 1 if +INF, 2 if NaN, otherwise, 0. 
check_inf_nan:
	
	bne $a2, 255, normal_case
	
	bne $a3, 0x00800000, nan_case # fraction = 0 <=> mantissa = 0x00800000

	beqz $a1, pos_inf_case
	j neg_inf_case	

  normal_case:
	li $v0, 0
	j exit_check_inf_nan

  nan_case:
	li $v0, 2	
	j exit_check_inf_nan

  pos_inf_case:
	li $v0, 1
	j exit_check_inf_nan

  neg_inf_case:
	li $v0, -1

  exit_check_inf_nan:
    jr $ra


# function to check if two floats are opposite (e.g., 3.0 and -3.0).
# params:
#	$t1: sign part of 1st float
#	$t2: exponent part of 1st float
#	$t3: mantissa part of 1st float
#	$t4: sign part of 2nd float
#	$t5: exponent part of 2nd float
#	$t6: mantissa part of 2nd float
# return:
#   $v0: 1 if two floats are opposite, otherwise, 0.
check_opposite:
		
	# two floats are opposite iff:
      # the sign parts are opposite
      # the rest between them is the same
    beq $t1, $t4, false_case
  	

    # check the rest parts
	bne $t2, $t5, false_case
	bne $t3, $t6, false_case
	j true_case
	
  
  false_case:
	li $v0, 0
    j exit_check_opposite
	
  true_case:
    li $v0, 1
 

  exit_check_opposite:
	jr $ra



# function to standardize exponent annd mantissa of 2 floats
# params:
#	$a0: exponent part of 1st float
#	$a1: mantissa part of 1st float
#	$a2: exponent part of 2nd float
#	$a3: mantissa part of 2nd float
# return:
#	$a0: exponent part of 1st float after standardization
#	$a1: mantissa part of 1st float after standardization
#	$a2: exponent part of 2nd float after standardization
#	$a3: mantissa part of 2nd float after standardization
standardize:
	addi $sp, $sp, -8
	sw $t0, 0($sp)
	sw $t1, 4($sp)	

	beq $a0, $a2, exit_standardize # if exp1 == exp2, there is nothing to standardize
	
	slt $t0, $a0, $a2 # $t0 = exp1 < exp2 ? 1 : 0
	beqz $t0, align_mantissa

	# if exp1 < exp2, swap exponent and mantissa before standardize
	# use swap macro
	swap_nums($a0, $a2)
	swap_nums($a1, $a3)


	# as exp1 > exp2, execute shifting mant2 right so that exp1 = exp2 
  align_mantissa:
	sub  $t1, $a0, $a2 # get number of shifting bits = exp1 - exp2
	srlv $a3, $a3, $t1 # shift right
	move $a2, $a0      # now the two exponent parts are equal = exp1

 	beqz $t0, exit_standardize
	# if we'd swapped nums before, we need to swap two mantissa parts
	# back to get the correct order 
	swap_nums($a1, $a3)


  exit_standardize:
	lw $t0, 0($sp)
	lw $t1, 4($sp)	
	addi $sp, $sp, 8
	
	jr $ra


# function to add mantissa parts of two floats and determine the sign of result
# params:
#	a0: sign part of 1st float
#	a1: mantissa part of 1st float after standardization
#	a2: sign part of 2nd float
#	a3: mantissa part of 2nd float after standardization
#	v0: exponent part of two floats after standardization
# return:
#	a0: sign part of final sum result
#	a1: exponent part of final sum result
#	a2: mantissa part of final sum result
add_mantissa_parts:
	
	addi $sp, $sp, -16
	sw $t0, 0($sp)
	sw $t1, 4($sp)	
	sw $t4, 8($sp)
	sw $t2, 12($sp)

	bne $a0, $a2, diff_sign_case
	
	# if same sign part (sign1=sign2):
	  # the sign of the result to be $a0 or $a2, whatever.
      # the final mantissa result will be the addition between two mantissa parts
	
	move $t0, $a0 # save final sign part temporarily in $t0
 	add  $t1, $a1, $a3 # save final mantissa result temporarily in $t1
	j check_overflow


  diff_sign_case:
	# if difference sign part:
	  # determine the sign of the result to be the sign 
	  # corresponding to the float with the larger mantissa

	  # and the final mantissa result is the subtraction with 
      # larger mantissa is minuend and the other mantissa is subtrahend
	blt $a1, $a3, mant2_larger
	move $t0, $a0 # final sign is followed 1st float, save temporarily in $t0
	sub $t1, $a1, $a3 # final mantissa result = mant1 - mant2
	j check_overflow


  mant2_larger:
	move $t0, $a2 # final sign is followed 2nd float, save temporarily in $t0
	sub $t1, $a3, $a1 # final mantissa result = mant2 - mant1


  check_overflow:
	# check if the final mantissa result is overflow (24th bit = 1) because of the addition
	
	andi $t2, $t1, 0x01000000
	srl  $t2, $t2, 24 # get 24th bit
	beqz $t2, standardize_mant # 24th bit = 0 -> no overflow -> jump next checking

	# handle overflow:
	# 24th bit = 1, shift right 1 and increase exp by 1
	srl  $t1, $t1, 1
	addi $v0, $v0, 1
	j exit_add_mantissa_parts


  standardize_mant:
	# if no overflow, need to standardize mant part by 
    # shifting mant left and decrease exp util 23rd bit = 1 
    
	  # check if mant part = 0 (there are no 1 bits to shift left)
	beqz $t1, exit_add_mantissa_parts
	
  loop_standardize_mant:
	  # check 23rd bit
	andi $t2, $t1, 0x00800000
    bnez $t2, exit_add_mantissa_parts # if 23rd bit != 0 (= 1) -> ok -> exit loop
	# else, shift mant left and decrease exp by 1
    sll  $t1, $t1, 1
    subi $v0, $v0, 1
	j loop_standardize_mant


  exit_add_mantissa_parts:
	# assign values to return registers
	move $a0, $t0 # sign
	move $a1, $v0 # exp
	move $a2, $t1 # mant


	
	lw $t0, 0($sp)
	lw $t1, 4($sp)	
	lw $t4, 8($sp)
	lw $t2, 12($sp)
	addi $sp, $sp, 16

	jr $ra


# function to concatenate 3 parts of float into 32-bit and save in a integer reg
# params:
#	a0: sign part
#	a1: exponent part
#	a2: mantissa part
# return:
#	v0: 32-bit represents the float after concatenate
concatenate:

	addi $sp, $sp, -16
	sw $a0, 0($sp)
	sw $a1, 4($sp)	
	sw $a2, 8($sp)
	sw $t0, 12($sp)
	
	sll $a0, $a0, 31 # shift sign bit to 31st position
	sll $a1, $a1, 23 # shift 8 bits exponent 23 bits

	# set 23rd bit in mantissa = 0 to get fraction part
	li  $t0, 0x00800000
	nor $t0, $t0, $zero
	and $a2, $a2, $t0
	
	# or 3 regs to concatenate final result
	or  $v0, $a0, $a1
	or  $v0, $v0, $a2


	lw $a0, 0($sp)
	lw $a1, 4($sp)	
	lw $a2, 8($sp)
	lw $t0, 12($sp)
	addi $sp, $sp, 16

	jr $ra