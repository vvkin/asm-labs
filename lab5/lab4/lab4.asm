global _start

%define UPPER_BOUND 256
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
		mov ebx, 1
   	mov eax, 4
   	int 80h

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
		jl %%error
		cmp bl, 57                  ;  greater than '9'
		jg %%error

%%valid_digit:
		sub bl, 48                  ; get digit
		imul eax, dword 10
		jo %%error
		add eax, ebx
		jo %%error
		jmp %%next_iteration

%%check_sign:
		cmp ecx, ebp               ; check is it first char
		jne %%error 
		mov dl, 1

%%next_iteration:
		inc ecx
		jmp %%loop

%%error:
		mov byte [err], 1
		jmp %%exit

%%done:
		cmp dl, 0                   ; check for sign
		je %%exit
		neg eax
		jo %%error 

%%exit:
%endmacro

%macro find_sum 0
		mov byte [err], 0             ; nullify error
		xor eax, eax
		xor esi, esi
		mov ecx, [arrSize]

%%loop:
		add eax, [arr+esi*4]
		jo %%overflow                  ; check for overflow
		inc esi
		loop %%loop
		jmp %%end

%%overflow:
		print_str 0xA, 'An overflow error occured!', 0xA, 0x0
		mov byte [err], 1             ; an error occured

%%end:
%endmacro

%macro print_array 0
		print_str '[ ', 0x0

		mov ecx, [arrSize]
		xor esi, esi

%%loop:
		push ecx                   ; save ecx
		print_num dword [arr+esi*4]
		
		print_str 0x20             ; print whitespace
		pop ecx                    ; restore ecx

		inc esi
		loop %%loop

%%exit:
		print_str ']', 0xA, 0x0
%endmacro

%macro find_max 0
		mov eax, [arr]
		mov ecx, [arrSize]
		xor esi, esi

%%loop:
		mov edx, [arr+esi*4]
		cmp edx, eax
		jle %%next
		mov eax, edx

%%next:
		inc esi
		loop %%loop
%endmacro

%macro sort_array 0
		cmp dword [arrSize], 1      ; check for 1 element
		jle %%exit

		mov ecx, [arrSize]          ; initialize outer loop
		dec ecx

%%outer:
		mov edx, ecx                ; initialize inner loop
		xor esi, esi

%%inner:
		mov eax, [arr+esi*4]
		cmp eax, [arr+esi*4+4]      ; arr[j] > arr[j+1]
		jl %%no_swap
		xchg eax, [arr+esi*4+4]     ; swap
		mov [arr+esi*4], eax

%%no_swap:
		inc esi
		dec edx
		jnz %%inner

		loop %%outer                 ; while (--ecx)

%%exit:
%endmacro

%macro clear_buffer 0
		mov ecx, BIT32_LEN

%%loop:
		mov byte [buffer+ecx], 0
		loop %%loop

%endmacro

section .bss
		arr     resd UPPER_BOUND    ; buffer for one dimensional array
		arrSize resd 1              ; size of one dimensional array
		
		matrix  resd UPPER_BOUND * UPPER_BOUND
		rowSize resd 1
		colSize resd 1
		toFind  resd 1

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
		call _read_32bit
		cmp byte [err], 1
		je .error
		
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

.matrix:
		call _make_matrix
		call _find_in_matrix
		jmp _exit

.sort:
		print_str 'Sorted array:', 0xA, 0x0
		sort_array
		print_array
		jmp _exit

.sum:
		print_str 'Sum of elements of array: ', 0x0
		find_sum
		
		cmp byte [err], 1           ; check for error
		jne .print_eax              ; all is OK
		jmp _exit                   ; overflow occured

.max:
		print_str 'Maximal element of array: ', 0x0
		find_max

.print_eax:
		print_num eax
		print_str 0xA
		jmp _exit
		
.error:
		print_str 'Invalid option! Try again: ', 0x0 
		jmp _handle_input

;--- end program execution
_exit:
		mov ebx, 0
		mov eax, 1
		int 80h

_read_32bit:
		mov byte [err], 0           ; nullify error
		clear_buffer
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
		mov  byte [err], 0          ; nullify error variable
		atoi buffer                 

.exit:
		ret

;--- just read from stdin to eax number from [1, UPPER_BOUND]
_read_size:
		call _read_32bit
		
		cmp byte [err], 1       ; not a number
		je .error
		cmp eax, UPPER_BOUND
		jg .error               ; size <= UPPER_BOUND
		cmp eax, 1                
		jl .error               ; size > 0
		ret

.error:
		print_str 'Try again:', 0x20, 0x0
		jmp _read_size

; create array from stdin input
_make_array:
		print_str 'Enter array size (integer from [1, 256]): ', 0x0
		call _read_size             ; eax = array size

.init:
		mov [arrSize], eax
		print_str 'Please, fill array with 32bit signed integers: ', 0xA, 0x0
		
		mov ecx, [arrSize]          ; initialize counter
		xor esi, esi

.fill:
		push ecx                    ; save registers
		push esi

		print_str 'array['
		print_num esi               ; print idx (esi)
		print_str '] = '
		
		call _read_32bit            ; eax = number
		pop esi                     ; restore esi

		cmp byte [err], 1           ; check for error
		je .error
		pop ecx

		mov [arr+esi*4], eax        ; arr[i] = number
		inc esi
		
		dec ecx
		jnz .fill         

.exit:
		ret

.error:
		print_str 'An error occured. Try again!', 0xA, 0x0
		pop ecx
		jmp .fill

; create matrix from stdin input
_make_matrix:

.read_sizes:
		print_str 'Enter number of rows (integer from [1, 256]): ', 0x0
		call _read_size
		mov [rowSize], eax

		print_str 'Enter number of columns (integer from [1, 256]): ', 0x0
		call _read_size
		mov [colSize], eax

.init:
		xor ebx, ebx                ; i

.outer:
		xor esi, esi                ; j

.inner:
		push esi
		push ebx

		print_str 'matrix[', 0x0
		print_num [esp]             ; ebx
		print_str '][', 0x0 
		
		print_num [esp+4]           ; esi 
		print_str '] = '            ; matrix[i][j] = 
				
		call _read_32bit            ; eax = int(input)
		cmp byte [err], 1           ; check for error
		je .error

		pop ebx
		pop esi

		mov edx, [rowSize]
		imul edx, ebx
		add edx, esi
		mov [matrix+edx*4], eax     ; matrix[i][j] = num

		inc esi
		cmp esi, [colSize]
		jl .inner
		
		inc ebx
		cmp ebx, [rowSize]
		jl .outer

.exit:
		ret

.error:
		print_str 'An error occured. Try again!', 0xA, 0x0
		pop ebx
		pop esi
		jmp .inner


_find_in_matrix:
.read_number:
		print_str 'Type number to find (32bit signed integer): ', 0x0
		call _read_32bit            ; eax = int(input)
		cmp byte [err], 1
		je .read_number
		mov [toFind], eax             ; save to local variable

.init:
		print_str 'Suitable indices:', 0xA, 0x0
		xor ebx, ebx

.outer:
		xor esi, esi

.inner:
		mov eax, [rowSize]
		imul ebx
		add eax, esi

		mov eax, [matrix+eax*4]
		cmp eax, [toFind]
		je .print

.next:
		inc esi
		cmp esi, [colSize]
		jl .inner

		inc ebx
		cmp ebx, [rowSize]
		jl .outer

.exit:
		ret

.print:
		push esi
		push ebx

		print_num [esp]             ; ebx
		print_str 0x20
		
		print_num [esp+4]           ; esi     
		print_str 0xA

		pop ebx
		pop esi

		jmp .next

