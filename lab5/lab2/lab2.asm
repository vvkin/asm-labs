global _start                           ; start point for linker

%define BIT32_LEN 13            ; len(-2**31)

%macro print_str 1+            
		jmp %%output

%%string: db %1
%%output:
		mov ebx, 1
		mov eax, 4
		mov ecx, %%string
		mov edx, %%output-%%string
		int 80h

%endmacro

%macro sys_write 0
		mov ebx, 1
		mov eax, 4
		int 80h
%endmacro

section .bss
		buffer resb BIT32_LEN 
		dummy  resb 1

section .text
_start:
		print_str 'Enter number (32bit signed integer): ', 0x0

_clear_buffer:
		mov ecx, BIT32_LEN          ; buffer length
.loop:
		mov byte [buffer+ecx], 0    ; fill with \0
		loop .loop

_read_input:
		mov ebx, 2                  ; stdin
		mov edx, BIT32_LEN          ; maximal length of input
		mov ecx, buffer             ; place str to input variable

_flush_stdin:
		mov eax, 3                  ; sys_read
		int 80h                     ; call kernel
		cmp byte [ecx+eax-1], 10    ; compare last char in stdin with \n
		je _main
		mov edx, 1
		mov ecx, dummy
		jmp _flush_stdin
		
_main:
		push buffer 
		call _atoi                  ; result in eax
		add esp, 4
		
_operation:
		sub eax, 88                 ; operation (var. 11)
		jno _print                  ; met overflow
		print_str 'An overflow error occured!', 0xA, 0x0
		jmp _error

_print:
		push eax
		print_str 'Result: ', 0x0
		
		call _print_num
		add esp, 4

		print_str 0xA, 0x0          ; \n

_exit:	
		mov ebx, 0
		mov eax, 1
		int 80h

_error:
		print_str 'Try again: ', 0x0
		jmp _clear_buffer
	  	
_atoi:
		enter 0, 0
		xor eax, eax
		xor ebx, ebx
		xor edx, edx
		mov ecx, [ebp+8]            ; pointer to first char in input
		
.loop:
		mov bl, byte [ecx]          ; current char
		cmp bl, 0                   ; \0 
		je .done
		cmp bl, 10                  ; \n
		je .done

		cmp bl, 45                  ; check for minus
		je .check_sign
		cmp bl, 48                  ; less than '0'
		jl .not_a_number
		cmp bl, 57                  ;  greater than '9'
		jg .not_a_number

.valid_digit:
		sub bl, 48                  ; get digit
		imul eax, dword 10
		jo .overflow
		add eax, ebx
		jo .overflow
		jmp .new_iteration

.check_sign:
		cmp ecx, [ebp+8]            ; check is it first char
		jne .not_a_number 
		mov dl, 1

.new_iteration:
		inc ecx
		jmp .loop

.not_a_number:
		print_str 'Input is not a number!', 0xA, 0x0
		jmp _error

.overflow:
		print_str 'Input number is too big!', 0xA, 0x0
		jmp _error

.done:
		cmp dl, 0                   ; check for sign
		je .exit
		neg eax
		jo .overflow 

.exit:
		leave
		ret

; print value from TOS to stdin
_print_num:	
		enter 0, 0
		mov edi, buffer
		cmp dword [ebp+8], 0         ; check sign 
		jge .init
  
		mov byte [edi], '-'
		inc edi
		neg dword [ebp+8]            ; make input positive

.init:
		mov eax, [ebp+8]
		mov ebx, 10

.loop:
		xor edx, edx
		div ebx
		add dl, 48                  ; '0'
		push edx
		test eax, eax
		jnz .loop

.stack:
		pop eax
		stosb                        
		cmp esp, ebp                ; check stack is empty
		jne .stack

.print:
		mov ecx, buffer
		mov edx, edi
		sub edx, buffer
		sys_write

.exit: 
		leave
		ret

