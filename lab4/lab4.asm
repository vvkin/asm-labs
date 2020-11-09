global _start

%define UPPER_BOUND 100
%define BIT32_LEN   13          ; len(-2**31) + 1

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
		choiceMsg db 'Type your choice: '
		lenChoice equ $ - choiceMsg
		sizeMsg db 'Enter array size (less than 100): ', 0
		lenSize equ $ - sizeMsg
		errorMsg db 'Sorry, but something went wrong', 10
		lenError equ $ - errorMsg
		rulesMsg db 'Only 32bit signed integers are allowed!', 10
		lenRules equ $ - rulesMsg
		elementMsg db 'array['
		lenElement equ $ - elementMsg
		braceEqual db '] = '
		lenBraceEqual equ $ - braceEqual
		sumResult db 'Sum of elements of array: '
		lenSum equ $ - sumResult
		maxResult db 'Maximal element of array: '
		lenMax equ $ - maxResult
		sortResult db 'Sorted array:', 10
		lenSort equ $ - sortResult

section .bss
		arr     resd UPPER_BOUND    ; buffer for one dimensional array
		arrSize resd 1              ; size of one dimensional array
		buffer  resb BIT32_LEN
		dummy   resb 1
		err     resb 1              ; global variable to handle errors

section .text
_start:

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

;--- read answer option from stdin
_handle_input:
		mov ecx, buffer
		mov edx, 2                  ; only digits and \n
		call _sys_read
		
		xor eax, eax
		mov al, byte [buffer]
		sub eax, 48                 ; extract digit

		cmp eax, 1
		jl .error
		cmp eax, 4
		jg .error
		cmp eax, 4
		je .matrix

.array:
		push eax                   ; save eax
		call _make_array
		pop eax                    ; restore eax
		
		cmp eax, 1
		je .sum
		cmp eax, 2
		je .max

		jmp _exit

.sum:
		mov ecx, sumResult
		mov edx, lenSum
		call _sys_write
		call _find_sum
		jmp .print_eax

.max:
		mov ecx, maxResult
		mov edx, lenMax
		call _sys_write
		call _find_max

.print_eax:
		push eax
		call _print_num
		add esp, 8
		
		mov byte [buffer], 10       ; \n
		mov ecx, buffer
		mov edx, 1
		call _sys_write
		jmp _exit
		
.matrix:
		jmp _exit
		
.error:
		call _print_intro
		call _handle_input

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

;--- atoi(const char* str) -> int32 (eax)
;--- eax - output
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
		imul eax, dword 10
		jo .error
		add eax, ebx
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
		neg eax
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
		
; --- print number to stdin
; --- input: stack top
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
		call _sys_write
		leave
		ret

;--- read number from stdin, convert
;--- it to int32 and put to ax
_get_element:
		push ecx                    ; save registers 
		push esi

.print:
		mov ecx, elementMsg         ; prompt for number
		mov edx, lenElement
		call _sys_write
		call _print_num             ; now top of stack = eax
		
		mov ecx, braceEqual
		mov edx, lenBraceEqual    
		call _sys_write             ; ] = 

		
		mov ecx, BIT32_LEN          ; buffer length
.clear_buffer:
		mov byte [buffer+ecx], 0    ; fill with \0
		loop .clear_buffer
	
.read:
		mov ebx, 2
		mov ecx, buffer             ; input in buffer
		mov edx, BIT32_LEN
		              
.flush_stdin:
		mov eax, 3                  ; sys_read
		int 80h                     ; call kernel
		cmp byte [ecx+eax-1], 10    ; compare last char in stdin with \n
		je .convert
		mov edx, 1
		mov ecx, dummy
		jmp .flush_stdin

.convert:
		push buffer                 ; push str to convert
		mov  byte [err], 0          ; nullify error variable
		call _atoi
		add esp, 4

		cmp byte [err], 1
		jne .exit

		mov ecx, rulesMsg
		mov edx, lenRules
		call _sys_write
		jmp .print

.exit:
		pop esi
		pop ecx
		ret

;--- just read from stdin to eax number from [1, UPPER_BOUND]
_read_size:
		mov ecx, buffer
		mov edx, 4                  ; no more than 4 symbols (with \n)
		call _sys_read

		mov byte [err], 0
		push buffer
		call _atoi
		add esp, 4

		cmp byte [err], 1
		je _read_size               ; an erorr occured

		cmp eax, UPPER_BOUND
		jg _read_size               ; size < 100
		cmp eax, 1                
		jl _read_size               ; size > 0
		ret
		
;--- read array size and
;--- array elements from stdin
_make_array:
		mov ecx, sizeMsg
		mov edx, lenSize
		call _sys_write
		call _read_size             ; eax = array size

.init:
		xor esi, esi                ; offset / 4
		mov ecx, eax                ; array size
		mov dword [arrSize], eax

.fill:
		call _get_element           ; eax = element
		mov [arr+esi*4], eax
		inc esi
		loop .fill         

.exit:
		ret

;--- place sum of array to eax
_find_sum:
		xor eax, eax
		xor esi, esi
		mov ecx, dword [arrSize]

.loop:
		add eax, [arr+esi*4]
		inc esi
		loop .loop
		ret

; place maximal element of array to eax
_find_max:
		mov eax, dword [arr]
		mov ecx, dword [arrSize]
		xor esi, esi

.loop:
		mov edx, [arr+esi*4]
		cmp edx, eax
		jle .next
		mov eax, edx

.next:
		inc esi
		loop .loop
		ret

; sort array (by reference)
;_sort_array:

		
;.outer:
;.inner:
		

