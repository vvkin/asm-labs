section .data
		prompt  db 'Select one of the following:', 10
		lenPrompt equ $ - prompt
		option1 db '1 - find sum of elements in array', 10
		len1 equ $ - option1
		option2 db '2 - find maximal element in array', 10
		len2 equ $ - option2
		option3 db '3 - sort array', 10
		len3 equ $ - option3
		option4 db '4 - find element in matrix', 10
		len4 equ $ - option4
		choiceMsg db 'Type your choice:', 32, 10
		lenChoice equ $ - choiceMsg
		sizeMsg db 'Type array size (less than 100):', 32, 10
		lenSize equ $ - sizeMsg
		errorMsg db 'Sorry, but something went wrong', 10
		lenError equ $ - errorMsg
		arr times 100 dw 0

section .text

global _start

;--- entry point
_start:
		call _print_intro

;--- end program execution
_exit:
		mov ebx, 0
		mov eax, 1
		int 80h

;--- print error message and jmp to _start
_error:
		mov ecx, errorMsg
		mov edx, lenError
		call _sys_write
		jmp _start
		
;--- atoi(const char* str) -> int (ax)
;--- ax - output
;--- bl - current char
;--- dl - sign
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
		jmp _error                  ; jump to _error block

.done:
		cmp dl, 0                   ; check for sign
		je .exit
		neg ax
		jo .error 

.exit:
		leave
		ret

;--- _sys_write
;--- call _sys_write
;--- ecx - msg to write, edx - msg len
_sys_write:
		mov ebx, 1
		mov eax, 4
		int 80h
		ret

;--- print messages to stdin
_print_intro:
		mov ecx, prompt
		mov edx, lenPrompt
		call _sys_write

		mov ecx, option1
		mov edx, len1
		call _sys_write

		mov ecx, option2
		mov edx, len2
		call _sys_write

		mov ecx, option3
		mov edx, len3
		call _sys_write

		mov ecx, option4
		mov edx, len4
		call _sys_write

		mov ecx, choiceMsg
		mov edx, lenChoice
		call _sys_write

		ret

;--- read_array(int)
;--- read array with given size
;--- stack - arr size, edi - pointer to read
_read_array:
		mov eax, [ebp-8]            ; array size
		enter 0, 0
		leave
		ret

