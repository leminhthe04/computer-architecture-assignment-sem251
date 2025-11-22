# params:
# 	flag: 0: read, 1: write
# return: 
#	$v0: file discriptor
.macro open_file(%file_name, %flag)
	li $v0, 13
	la $a0, %file_name
	li $a1, %flag
    li $a2, 0           # mode is ignored
	syscall
.end_macro

.macro write_file_float(%outfile_descriptor_reg, %float_address)
	li $v0, 15	
	move $a0, %outfile_descriptor_reg
	la $a1, %float_address
	li $a2, 4
	syscall
.end_macro


# params:
# 	buf: buffer containing bytes to be read
# 	num_bytes: numbers of bytes to read
# return: 
#	$v0: file discriptor
.macro read_file_bytes(%infile_descriptor_reg, %buf, %num_bytes)
	li $v0, 14
    move $a0, %infile_descriptor_reg
    la $a1, %buf
    li $a2, %num_bytes
    syscall
.end_macro

.macro close_file(%file_descriptor_reg)
	li $v0, 16
	move $a0, %file_descriptor_reg
	syscall
.end_macro


.macro write_float_from_int_reg(%int_reg)
	li $v0, 2
	mtc1 %int_reg, $f12
	syscall
.end_macro


.macro write_string(%str_label)
	li $v0, 4
	la $a0, %str_label
	syscall
.end_macro


.macro swap_nums(%a, %b)
	addi $sp, $sp, -4
	sw $t0, 0($sp)

	move $t0, %a
	move %a, %b
	move %b, $t0

	lw $t0, 0($sp)
	addi $sp, $sp, 4
.end_macro


.macro exit
	li $v0, 10
	syscall
.end_macro
