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
		sizeMsg db 'Enter array size (less than 100): ', 0
		lenSize equ $ - sizeMsg
		errorMsg db 'Sorry, but something went wrong', 10
		lenError equ $ - errorMsg
		rulesMsg db 'Element must be an integer in range [-32768, 32767]!', 10
		lenRules equ $ - rulesMsg
		elementMsg db 'Enter element '
		lenElement equ $ - elementMsg
		colonws    db ': '
		lenColonws equ $ - colonws

section .bss
		arr     resw 100            ; buffer for one dimensional array
		buffer  resb 7
		err     resb 1              ; global variable to handle errors

section .text

global _start

;--- entry point
_start:
		call _print_intro
		;call _handle_choice
		push arr                    ; pointer to array
		call _make_array
		add esp, 8

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
		mov byte [err], 1           ; an error occured
		jmp .exit                   ; jump to _error block

.done:
		cmp dl, 0                   ; check for sign
		je .exit
		neg ax
		jo .error 

.exit:
		leave
		ret

_sys_write:
		mov ebx, 1
		mov eax, 4
		int 80h
		ret

_sys_read:
		mov ebx, 2
		mov eax, 3
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

; --- print number to stdin
; --- input: stack top
_print_num:	
		enter 0, 0

		cmp word [ebp+8], 0         ; check sign 
		jge .init
  
		mov byte [edi], '-'
		add edi, 1
		neg word [ebp+8]            ; make input positive

.init:
		mov ax, [ebp+8]
		mov bx, 10

.loop:
		xor dx, dx
		div bx
		add dl, 48                  ; '0'
		push dx
		test ax, ax
		jnz .loop
		mov edi, buffer             ; pointer to write

.stack:
		pop ax
		stosb                        
		cmp esp, ebp                ; check stack is empty
		jne .stack

.print:
		mov ecx, buffer
    mov edx, edi
    sub edx, buffer
    call _sys_write
    leave
		ret

;--- read number from stdin, convert
;--- it to int16 and put to ax
_get_element:
		mov ecx, buffer
		mov edx, 7
		call _sys_read              ; input in buffer
    
		push buffer                 ; push str to convert
		mov  byte [err], 0          ; nullify error variable
		call _atoi
		add esp, 4

		cmp byte [err], 1
		jne .exit

		mov ecx, rulesMsg
		mov edx, lenRules
		call _sys_write
		jmp _get_element

.exit:
		ret

;--- read array size and
;--- array elements from stdin
;--- stack: pointer to read array
_make_array:
		mov ecx, sizeMsg
		mov edx, lenSize
		call _sys_write

.read_size:
		mov ecx, buffer
		mov edx, 4                  ; no more than 4 symbols (with \n)
		call _sys_read

		mov byte [err], 0
		push buffer
		call _atoi
		add esp, 4

		cmp byte [err], 1
		je .read_size               ; an erorr occured

		cmp ax, 100
		jg .read_size               ; size < 100
		cmp ax, 1                
		jl .read_size               ; size > 0

.init:
		enter 0, 0
		mov ebx, [ebp+8]            ; pointer to array
		mov ecx, eax                ; array size
		xor eax, eax                ; element number counter

.loop:
		push ecx                    ; save registers 
		push ebx
		push eax
		
		mov ecx, elementMsg         ; prompt for number
		mov edx, lenElement
		call _sys_write
		call _print_num             ; now top of stack = eax
		
		mov ecx, colonws
		mov edx, lenColonws
		call _sys_write
		
		call _get_element           ; eax = elemen
		
		pop eax
		pop ebx                     
		pop ecx

		mov [ebx], eax
		add ebx, 4
		inc eax
		loop .loop

.exit:
		leave
		ret

