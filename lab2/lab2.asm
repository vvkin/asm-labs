global _start                           ; start point for linker

section .bss
		buffer resb 7     

section .text
_start:
		mov ecx, 7

_clear_buffer:
		mov byte [buffer+ecx], 0    ; fill with \0
		loop _clear_buffer

		mov ebx, 2                  ; stdin
		mov eax, 3                  ; sys_read
		mov edx, 7                  ; maximal length of input
		mov ecx, buffer             ; place str to input variable
		int 80h                     ; call kernel
		
		push buffer 
		call _atoi                  ; result in ax
		add esp, 4

		sub ax, 88                  ; operation (var. 10)
		jo _start                   ; met overflow

		push ax
		call _print_num
		add esp, 2

_exit:	
		mov ebx, 0
		mov eax, 1
		int 80h
	  	
;----atoi(const char* str) -> int (ax)
;---- ax - output
;---- bl - current char
;---- dl - sign
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
		jl .error
		cmp bl, 57                  ;  greater than '9'
		jg .error

.valid_digit:
		sub bl, 48                  ; get digit
		imul ax, word 10
		jo .error
		add ax, bx
		jo .error
		jmp .new_iteration

.check_sign:
		cmp ecx, [ebp+8]            ; check is it first char
		jne .error 
		mov dl, 1

.new_iteration:
		inc ecx
		jmp .loop

.error:
		leave
		add esp, 8
		jmp _start                  ; prompt for a new number

.done:
		cmp dl, 0                   ; check for sign
		je .exit
		neg ax
		jo .error 

.exit:
		leave
		ret

;-- print_num(int) -> void
;-- print 16bit integer to stdin
_print_num:
		enter 0, 0
		cmp word [ebp+8], 0         ; check sign 
		jge .init
		
		push ecx                    ; save ecx
		mov byte [buffer], 45
		mov ebx, 1
		mov eax, 4
		mov ecx, buffer             ; print '-' to stdout
		mov edx, 1 
		int 80h
		pop ecx

		neg word [ebp+8]            ; make input positive

.init:
		mov ax, [ebp+8]
		mov bx, 10
		
.loop:
		xor dx, dx
		div bx
		add dl, 48 ; '0'
		push dx
		test ax, ax
		jnz .loop
		mov edi, ecx                ; result will be in ecx 

.stack:
		pop ax	
		stosb                        
		cmp esp, ebp                ; check stack is empty
		jne .stack

.print:
		mov ebx, 1
		mov eax, 4
		mov edx, edi                ; result length
		int 80h
		leave
		ret

