global _start

%define BUFSIZE 256

section .data
		msgX db 'Enter x:', 10
		lenX equ $ - msgX

		ten  dw 10
		fsig dq 0.0                 ; handle significant
		fexp dq 0.0                 ; exponent

section .bss
		buffer  resb BUFSIZE        ; buffer to read inpuy
		fbuffer resq 1              ; buffer to store double values
		ibuffer resd 1              ; buffer to store dword
		sign    resb 1              ; number sign
		dummy   resb 1              ; buffer to read garbage from stdin
		valueX  resq 1              ; variable to handle x (float)
		valueY  resq 1              ; variable to handle y (float)
		digit   resb 1
		newcw   resw 1              ; control word
		oldcw   resw 1

section .text
_start:
    finit                       ; initialize fstack

		mov ebx, 1
		mov eax, 4
		mov edx, lenX
		mov ecx, msgX
		int 80h

		call _read_to	
		push buffer
		call _atof
		call _calc
	
_exit:
		mov ebx, 0
		mov eax, 1                  ; sys_exit
		int 80h

;--- read input from stdin to buffer 
_read_to:
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
		ret

;--- _pow10
;--- calculate 10 ^ n
;--- n - st0
;--- output - st0
_pow10:
   ; x^y=2^(y * log_2(x))
	 fldl2t                       ; st0 = log_2(10)
	 fmul
	 fld st0                      ; st1=st0
	 frndint                      ; significant part st0
	 fsub st1, st0                ; fractional part st1
	 fxch st1                     ; swap st0, st1
	 f2xm1                        ; 2 ^ st0 - 1
	 fld1                         ; push 1            
	 faddp                         ; st0 += st1 
	 fscale                       ; st0 *= 2 ^ st1 
	 fstp st1                     ; st0 = x^y
	 ret

;--- atof(const char*) -> float
;--- convert string to float
;--- output: st0
_atof:
		enter 0, 0
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
    add eax, edx                      ; ++number of digits after dot
		sub bl, 48                  ; get digit
		fimul word [ten]
		mov [digit], bl
		fiadd word [digit]
		jmp .new_iteration

.dot:                           ; if dot then nullify counter
   test edx, edx                  ; check is it second dot
	 jnz .error
	 mov edx, 1
	 jmp .new_iteration

.check_sign:
		cmp ecx, [ebp+8]            ; check is it first char
		jne .error 
		mov byte [sign], 1

.new_iteration:
		inc ecx
		jmp .loop

.error:
    leave
		add esp, 8
		jmp _start                  ; prompt for a new number

.done:
		cmp byte [sign], 0          ; check for sign
		je .divide
	  fchs                        ; negate st0

.divide:
    fstp qword [fbuffer]        ; save st0
		mov [ibuffer], eax
		fild dword [ibuffer]        ; push eax to fstack

		call _pow10                 ; st0 = 10 ^ eax
		fld qword [fbuffer]
		fdivrp

.exit:
		leave
		ret

;--- _calc
;--- calculate func value (x = st0)
_calc:
    mov word [ibuffer], 1
		fild word [ibuffer]
		fcomip st1
		jae .2                      ; 1 >= x

		mov word [ibuffer], 20
		fild word [ibuffer]
		fcomip st1
		jb .3                       ; 20 < x

.1: ; 54+x^2/(1+x)              1 < x <= 20
		fld st0                     ; st0 = st1 = x
		fmul st0                    ; st0=x^2
		mov word [ibuffer], 54
		fiadd word [ibuffer]        ; st0=54+x^2
    fld1                        ; st0=1, st1=54+x^2, st2=x
		faddp st2                   ; st0=1+x
		fdivrp                      ; done
		ret

.2: ; 75 * x^2 - 17 * x         x <= 1
    fld st0                     ; st0=st1=x
		fmul st0                    ; st0=x^2
		mov word [ibuffer], 75
		fimul word [ibuffer],       ; st0=75*x^2
    mov word [ibuffer], 17
		fxch st1                    ; st0=x, st1=75*x^2
		fimul word [ibuffer]        ; st1=17*x
		fsub                        ; st0=st1-st0
		ret                         ; done

.3: ; 85 * x / (1 + x)          x > 20
		fld st0                     ; st0 = st1 = x
		mov word [ibuffer], 85         
		fimul word [ibuffer]        ; st0 = 85x
		fld1                        ; st0=1, st1=85x, st2=x
		faddp st2                   ; st0=85x, st1=1+x
		fdivrp                      ; st0=st0/st1
		ret 

;--- _normalize
;--- normalize value in st0
;--- fvar - input
;--- fexp - exp
;--- fsig - signficant
_normalize:
		; fexp = floor(log_10(fvar))
	  fabs
		fld st0
		fldlg2                       ; st0 = log_10(2)
		fxch st1                     ; st2=fvar, st1=log_10(2), st0=fvar
		fyl2x                        ; st0 = log_10(2) * log_2(fvar)
		fstcw [oldcw]                ; save previous rounding mode
		mov dx, [oldcw]
		or  dx, 0x0c000              ; rounding mode = 3, toward zero
    mov [newcw], dx              ; new rounding mode
		fldcw [newcw]                ; change rounding mode
		frndint                      ; truncate log_10(input)
		fldcw [oldcw]                ; restore rounding mode
		fst qword [fexp]             ; store exp value
		
		; fsig = fvar / 10^(fexp)
		fxch st1                     ; st0=fvar, st1=fexp
		fstp qword [fbuffer]         ; fbuffer=fvar, st0=fexp
		call _pow10                  ; st0=10^fexp
		fld qword [fbuffer]          ; st0=fvar, st1=10^fexp
		fdivrp                       ; st0=fvar/10^fexp
		fstp qword [fsig]
		ret
