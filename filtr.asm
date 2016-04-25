### ADRIAN HAWRYLAK 3I1
### ARKO projekt duzy MIPS
### filtr gorno/dolno przepustowy
######################################




.data
ask_input_msg:			.asciiz	"Input file name:\n"
header: 			.space   54 	
input_file:			.space	128 	
ask_output_msg:			.asciiz	"Output file name:\n"
filter_prompt:			.asciiz "\nChoose filter:\n1. lowpass\n2. highpass\n3. edge detection\n"
input_err:			.asciiz "\nInput image not found! Restarting...\n\n"
bmp_format_err:			.asciiz	"\nInput image not 24b bitmap! Restarting...\n\n"
not_bmp_err: 			.asciiz "\nInput file is not a bitmap! Restarting...\n\n"
output_err: 			.asciiz "\nOutput file error! Restarting...\n"
output_file: 			.space  128	
lowpass:			.byte   1,2,1,2,4,2,1,2,1
highpass:			.byte 	-1,-1,-1,-1,38,-1,-1,-1,-1
buffer:				.space	1



#	$s0 - the file descriptor
#	$s1 - the size of the data section 
#   	$s2 - the pixel array of the bmp image

.text
main:
	
	#print ask_input_msg string
	li		$v0, 4			# syscall 4, print string
	la		$a0, ask_input_msg	# load ask_input_msg string
	syscall
	
	#read filename
	li		$v0, 8			# syscall 8, read string
	la		$a0, input_file		# store string in input_file
	li		$a1, 128		
	syscall
	
	#print ask_output_string
	li		$v0, 4			# syscall 4, print string
	la		$a0, ask_output_msg	# load ask_input_msg string
	syscall
	
	#read output name
	li 		$v0, 8			# syscall 8, read string
	la 		$a0, output_file	# store string in output_file
	li 		$a1, 128		
	syscall
	
	# remove trailing newline
	li 		$t0, '\n'		
	li 		$t1, 128		# length of the output_file
	li 		$t2, 0			
	
outputRemoveNewLine:
	beqz		$t1, newLineLoopInit			# if end of string, jump to remove newline from input string
	subu		$t1, $t1, 1				# decrement the index
	lb		$t2, output_file($t1)			# load the character at current index position
	bne		$t2, $t0, outputRemoveNewLine		# if current character != '\n', jump to loop beginning
	li		$t0, 0			
	sb		$t0, output_file($t1) 
	
newLineLoopInit:
	li		$t0, '\n'	
	li		$t1, 128	# length of the input_file
	li		$t2, 0		
	
newLineLoop:
	beqz	$t1, newLineLoopEnd	# if end of string, jump to loop end
	subu	$t1, $t1, 1			# decrement the index
	lb		$t2, input_file($t1)	# load the character at current index position
	bne		$t2, $t0, newLineLoop	# if current character != '\n', jump to loop beginning
	li		$t0, 0			# else store null character
	sb		$t0, input_file($t1) # and overwrite newline character with null
	
newLineLoopEnd:
	
	#open input file
	li		$v0, 13		# syscall 13, open file
	la		$a0, input_file	# load filename address
	li 		$a1, 0		# read flag
	li		$a2, 0		# mode 0
	syscall
	bltz		$v0, inputFileErrorHandler	#if $v0=-1, there was a descriptor error; go to handler. 
	move		$s0, $v0	# save file descriptor
	
	#read header
	li		$v0, 14		# syscall 14, read from file
	move		$a0, $s0	# load file descriptor
	la		$a1, header	# load address to store data
	li		$a2, 54		# read 54 bytes
	syscall
	

	
	#save the width
	lw 		$s7, header+18
	mul		$s7, $s7, 3
	
	#save height
	lw		$s4, header+22
	
	lw		$s1, header+34	# store the size of the data section of the image
	
	#read image data into array
	li		$v0, 9		# syscall 9, allocate heap memory
	move		$a0, $s1	# load size of data section
	syscall
	move		$s2, $v0	# store the base address of the array in $s2
	
	li		$v0, 14		# syscall 14, read from file
	move		$a0, $s0	# load file descriptor
	move		$a1, $s2	# load base address of array
	move		$a2, $s1	# load size of data section
	syscall
	
	#close file
	move		$a0, $s0		# move the file descriptor into argument register
	li		$v0, 16			# syscall 16, close file
	syscall
	la 		$s3, buffer  #load the address of the buffer into $s3


  	#print filter type string
	li		$v0, 4	# syscall 4, print string
	la		$a0, filter_prompt	# load filter selection string
	syscall
	
        #read filter type
	li		$v0, 5	# syscall 5, read integer 
	syscall

	beq $v0, 1, load_lowpass
	beq $v0, 2, load_highpass


	# load selected convolution kernel
load_lowpass:
	la 		$t9, lowpass
	j 		init_loop
	
load_highpass:
	la		$t9, highpass
	j		init_loop



#############################################################################
# $s1 - size of data section
# $s2 - start of pixel array
# $s3 - buffer address
# $s7 - width
# $s4 - height
# $t0 - loop counter (to 3* overall number of pixels)
# $t1 - current pixel address

init_loop:
	move		 $t0,$zero
	move		 $t1,$s2
	

loop:
	# $t9 - convolution kernel, $t8 - current kernel wage
	# $t7 - sum of all wages, $t6 - wage*old_value
	# $s7 - width in bytes, $t5 - pixel R/G/B address, $t4 - old color value
	# $t2 - new value
	
	
	move 		$t7, $zero
	
	# lower left
	lb 		$t8, 0($t9)
	sub		$t5, $t1, $s7	# calculate wanted value address 
	addi		$t5, $t5, -3
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	
	# lower center
	lb 		$t8, 1($t9)
	sub 		$t5, $t1, $s7	# calculate wanted value address 
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# lower right
	lb 		$t8, 2($t9)
	sub 		$t5, $t1, $s7	# calculate wanted value address 
	addi 		$t5, $t5, 3
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# middle left
	lb 		$t8, 3($t9)		# calculate wanted value address 
	addi 		$t5, $t1, -3
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# center
	lb 		$t8, 4($t9)
	lb 		$t4, ($t1)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# middle right
	lb 		$t8, 5($t9)		# calculate wanted value address 
	addi 		$t5, $t1, 3
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# upper left
	lb 		$t8, 6($t9)
	add 		$t5, $t1, $s7	# calculate wanted value address 
	addi 		$t5, $t5, -3
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# upper center
	lb 		$t8, 7($t9)
	add 		$t5, $t1, $s7	# calculate wanted value address 
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	
	# upper right
	lb 		$t8, 8($t9)
	add 		$t5, $t1, $s7	# calculate wanted value address 
	addi 		$t5, $t5, 3
	lb 		$t4, ($t5)
	jal		shift
	mul 		$t6, $t8, $t4
	add 		$t7, $t7, $t6
	j		loop_continue

shift:
	sll 		$t4, $t4, 24
	srl		$t4, $t4, 24
	jr		$ra

			
loop_continue:			
	# divide sum of all wages 
	div 		$t2, $t7, 16
	
	
	# normalization
	bge		$t2, -128, continue1
	li 		$t2, -128
continue1:
	ble 		$t2, 128, continue2
	li 		$t2, 128
continue2:

	
	#store in output file
	sb 		$t2,($s3)
	addi 		$s3,$s3,1
	addi 		$t1,$t1,1
	addi 		$t0,$t0,1
	
	blt 		$t0,$s1, loop
	
	li 		$v0, 1
	move 		$a0,$t2
	syscall
	
	j write_file
	
	
write_file:
	
	#open output file
	li		$v0, 13
	la		$a0, output_file
	li		$a1, 1		#1 to write
	li		$a2, 0
	syscall
	move		$t1, $v0	#output file descriptor in $t1
	
	#confirm that file exists 
	bltz		$t1, outputFileErrorHandler

	li		$v0, 15		#prep $v0 for write syscall
	move 		$a0, $t1
	la		$a1, header
	addi    	$a2, $zero,54
	syscall
	
	#write to output file
	li		$v0, 15		
	move 		$a0, $t1
	la		$a1, buffer
	move  		$a2, $s1
	syscall
	
	#close file
	move		$a0, $t1
	li		$v0, 16
	syscall

leave:
	li 		$v0, 10
	syscall
	
	
inputFileErrorHandler:
	#print file input error message
	li		$v0, 4			# syscall 4, print string
	la		$a0, input_err		# print the message
	syscall
	j		main
	
improperFormatHandler:
	#print file input error message
	li		$v0, 4			# syscall 4, print string
	la		$a0, bmp_format_err	# print the message
	syscall
	j		main
	
inputNotBMPHandler:
	#print file input error message
	li		$v0, 4			# syscall 4, print string
	la		$a0, not_bmp_err	# print the message
	syscall
	j		main
	
outputFileErrorHandler:
	#print file output error message
	li		$v0, 4			# syscall 4, print string
	la		$a0, output_err	# print the message
	syscall
	j		main
