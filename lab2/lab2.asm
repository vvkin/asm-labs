global _start         ; start point for linker

section .data
		maxLen equ 6      ; negative 16bit number (6 char's)

section .bss
		sign resb		1		  ; sign of got number (1 bit)
		number resw	1	    ; input str after atoi (16 bit)
		input  resb 6     ; input str (6 bit)
		strLen resb 1     ; input length

section .text
_start:
		; get str from stdin
		mov ebx, 2				; stdin
		mov eax, 3				; sys_read
		mov edx, maxLen   ; maximal length of input
		mov ecx, input    ; place str to input variable
		int 80h           ; call kernel

_str_len:
		xor eax, eax        ; result
		mov ecx, input      ; put pointer to ecx

_str_len_loop:
		cmp [ecx], byte 0       ; check for \0
		je _str_len_end
		cmp [ecx], byte 10      ; check for \n
		je _str_len_end
		
		cmp byte [ecx], 45      ; it's minus
		je _str_len_valid 

		cmp byte [ecx], 48      ; less than ord('0')
		jl _str_len_error
		cmp byte [ecx], 57      ; bigger than ord('9')
		jg _str_len_error 

_str_len_valid:
		inc eax
		add ecx, 1
		jmp _str_len_loop

_str_len_error:
		mov eax, -1

_str_len_end:
		mov [strLen], eax  ; save len to variable

_validate_input:
		cmp [strLen], byte -1         ; got non numeric string
		je _start

_exit:
		mov ebx, 1
		mov eax, 4
		mov edx, strLen
		mov ecx, input
		int 80h

		mov ebx, 0
	  mov eax, 1				; sys_exit
	  int 80h

