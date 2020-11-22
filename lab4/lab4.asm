global _start

%define UPPER_BOUND 100
%define BIT32_LEN   13          ; len(-2**31) + 1

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
		print_str 'Choose one of the following:', 0xA, 0x0
		print_str '1 - find sum of elements of array', 0xA, 0x0
		print_str '2 - find maximal element in array', 0xA, 0x0
		print_str '3 - sort array', 0xA, 0x0
		print_str '4 - find element in matrix', 0xA, 0x0
		print_str 'Type your choice: ',  0x0

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
		cmp eax, 3
		je .sort

		jmp _print_intro

.sort:
		print_str 'Sorted array:', 0xA, 0x0
		call _sort_array
		call _print_array
		jmp _exit

.sum:
		print_str 'Sum of elements of array: ', 0x0
		call _find_sum
		jmp .print_eax

.max:
		print_str 'Maximal element of array: ', 0x0
		call _find_max

.print_eax:
		push eax
		call _print_num
		add esp, 8
		
		print_str 0xA
		jmp _exit
		
.matrix:
		jmp _exit
		
.error:
		jmp _print_intro

;--- end program execution
_exit:
		mov ebx, 0
		mov eax, 1
		int 80h

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
		print_str 'array[', 0x0
		call _print_num             ; now top of stack = eax
		print_str '] = ', 0x0

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

		print_str 'Only 32bit signed integers are allowed!', 0xA, 0x0
		jmp .print

.exit:
		pop esi
		pop ecx
		ret

;--- just read from stdin to eax number from [1, UPPER_BOUND]
_read_size:
.begin:
		mov ecx, buffer
		mov edx, 4                  ; no more than 4 symbols (with \n)
		call _sys_read

		mov byte [err], 0
		push buffer
		call _atoi
		add esp, 4

		cmp byte [err], 1
		je .error               ; an erorr occured
		cmp eax, UPPER_BOUND
		jg .error               ; size < 100
		cmp eax, 1                
		jl .error               ; size > 0
		ret

.error:
		print_str 'Try again: ',  0x0
		jmp .begin
		
;--- read array size and
;--- array elements from stdin
_make_array:
		print_str 'Enter array size (integer from [0, 1000]): ', 0x0
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
_sort_array:
		mov ecx, dword [arrSize]    ; initialize outer loop
		dec ecx

.outer:
		mov edx, ecx                ; initialize inner loop
		xor esi, esi

.inner:
		mov eax, [arr+esi*4]
		cmp eax, [arr+esi*4+4]      ; arr[j] > arr[j+1]
		jl .no_swap
		xchg eax, [arr+esi*4+4]     ; swap
		mov [arr+esi*4], eax

.no_swap:
		inc esi
		dec edx
		jnz .inner

		loop .outer                 ; while (--ecx)

.exit:
		ret

; print array to stdin
_print_array:
		xor esi, esi
		print_str '[ ', 0x0

.loop:
		push dword [arr+esi*4]	
		call _print_num
		add esp, 4
		print_str 0x20
		
		inc esi
		cmp esi, [arrSize]
		jl .loop

.exit:
		print_str ']', 0xA, 0x0
		ret
