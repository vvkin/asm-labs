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

%macro clear_buffer 0
		mov ecx, BIT32_LEN

%%loop:
		mov byte [buffer+ecx], 0
		loop %%loop

%endmacro

%macro atoi 1
		xor eax, eax
		xor ebx, ebx
		xor edx, edx
		mov ebp, %1                 ; save pointer to first char here
		mov ecx, %1                 ; pointer to first char in input
		
%%loop:
		mov bl, byte [ecx]          ; current char
		cmp bl, 0                   ; \0 
		je %%done
		cmp bl, 10                  ; \n
		je %%done

		cmp bl, 45                  ; check for minus
		je %%check_sign
		cmp bl, 48                  ; less than '0'
		jl %%not_a_number
		cmp bl, 57                  ;  greater than '9'
		jg %%not_a_number

%%valid_digit:
		sub bl, 48                  ; get digit
		imul eax, dword 10
		jo %%overflow
		add eax, ebx
		jo %%overflow
		jmp %%next_iteration

%%check_sign:
		cmp ecx, ebp               ; check is it first char
		jne %%not_a_number 
		mov dl, 1

%%next_iteration:
		inc ecx
		jmp %%loop

%%not_a_number:
		print_str 'Input is not a number!', 0xA, 0x0
		jmp _error

%%overflow:
		print_str 'Input number is too big!', 0xA, 0x0
		jmp _error

%%done:
		cmp dl, 0                   ; check for sign
		je %%exit
		neg eax
		jo %%overflow 

%%exit:
%endmacro

%macro print_num 1
		mov ebp, esp
		mov ebx, %1
		mov edi, buffer
		cmp ebx, 0         ; check sign 
		jge %%init
  
		mov byte [edi], '-'
		inc edi
		neg ebx            ; make input positive

%%init:
		mov eax, ebx
		mov ebx, 10

%%loop:
		xor edx, edx
		div ebx
		add dl, 48                  ; '0'
		push edx
		test eax, eax
		jnz %%loop

%%stack:
		pop eax
		stosb                        
		cmp esp, ebp                ; check stack is empty
		jne %%stack

%%print:
		mov ecx, buffer
		mov edx, edi
		sub edx, buffer
		sys_write

%endmacro

section .bss
		buffer resb BIT32_LEN 
		dummy  resb 1

section .text
_start:
		print_str 'Enter number (32bit signed integer): ', 0x0
		
_read_input:
		clear_buffer
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
		atoi buffer                 ; eax = number
		sub eax, 88                 ; operation (var. 11)
		jno _print                  ; met overflow
		print_str 'An overflow error occured!', 0xA, 0x0
		jmp _error

_print:
		push eax
		print_str 'Result: ', 0x0
		pop eax	
		print_num eax
		print_str 0xA, 0x0          ; \n

_exit:	
		mov ebx, 0
		mov eax, 1
		int 80h

_error:
		print_str 'Try again: ', 0x0
		jmp _read_input
	  	
