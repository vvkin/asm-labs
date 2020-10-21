global _start

%define BUFSIZE 256

section .data
		msgX db 'Enter x:', 10
		lenX equ $ - msgX
		msgY db 'Enter y:', 10
		lenY equ $ - msgY

		ten dw 10

section .bss
		buffer  resb BUFSIZE        ; buffer to read inpuy
		fbuffer resq 1              ; buffer to store double values
		ibuffer resd 1              ; buffer to store dword
		dummy   resb 1              ; buffer to read garbage from stdin
		valueX  resq 1              ; variable to handle x (float)
		valueY  resq 1              ; variable to handle y (float)
		digit   resb 1 

section .text
_start:
    mov ebx, 1
		mov eax, 4
		mov edx, lenX
		mov ecx, msgX
		int 80h

		call read_to                ; read x
		push buffer
		call atof
		fstp qword [valueX]

		mov ebx, 1
		mov eax, 4
		mov edx, lenY
		mov ecx, msgY
		int 80h

		call read_to                ; read y
		push buffer
		call atof
		fstp qword [valueY]
		
_exit:
		mov ebx, 0
		mov eax, 1                  ; sys_exit
		int 80h

;--- read input from stdin to buffer 
read_to:
		enter 0, 0
    mov ecx, BUFSIZE     

.clear_buffer:
    mov byte [buffer+ecx], 0    ; fill with \0
    loop .clear_buffer

.read:
    mov ebx, 2
		mov edx, BUFSIZE
		mov ecx, buffer

.flush_stdin:
    mov eax, 3                  ; sys_read
    int 80h                     ; call kernel
    cmp byte [ecx+eax-1], 10    ; compare last char in stdin with \n
    je .exit
    mov edx, 1
    mov ecx, dummy
    loop .flush_stdin

.exit:
    leave
		ret

;--- atof(const char*) -> float
;--- convert string to float
;--- eax - number of digits after dot
;--- dl - sign
;--- input: stack
;--- output: fstack(st0)
atof:
    enter 0, 0
		finit                       ; fstack to default
		fldz                        ; push 0 to st0
		xor eax, eax                ; number of digits after dot
		xor ebx, ebx        
		xor edx, edx                ; sign
		mov ecx, [ebp+8]            ; pointer to first char in input
		
.loop:
		mov bl, byte [ecx]          ; current char
		cmp bl, 0                   ; \0 
		je .done
		cmp bl, 10                  ; \n
		je .done
		
    cmp bl, 46                  ; check for dot
		je .dot
		cmp bl, 45                  ; check for minus
		je .check_sign
		cmp bl, 48                  ; less than '0'
		jl .error
		cmp bl, 57                  ;  greater than '9'
		jg .error

.valid_digit:
    inc eax                     ; ++number of digits after (before) dot
		sub bl, 48                  ; get digit
		fimul word [ten]
		mov [digit], bl
		fiadd word [digit]
		jmp .new_iteration

.dot:                           ; if dot then nullify counter
   xor eax, eax
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
		je .divide
	  fchs                        ; negate st0

.divide:
		fstp qword [fbuffer]
		mov [ibuffer], eax
		fild dword [ibuffer]        ; exponent
		fild word  [ten]            ; 10
		fyl2x                       ; st0 = pow * log_2(10)
		fld1                        ; push 1
		fld st1
		fprem
		f2xm1
		faddp
		fscale
		fstp st1                    ; pop st1
		fld qword [fbuffer]
		fdivrp

.exit:
		leave
		ret	
