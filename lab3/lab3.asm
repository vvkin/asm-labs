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
    add esp, 4

    call _calc

    mov edi, buffer
    call _dtoa
		
    mov ebx, 1
    mov eax, 4
    mov ecx, buffer
    mov edx, edi
    sub edx, buffer
    int 80h

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
;--- output: st0
_pow10:
    ; x^y=2^(y * log_2(x))
    fldl2t                      ; st0 = log_2(10)
    fmul
    fld st0                     ; st1=st0
    frndint                     ; significant part st0
    fsub st1, st0               ; fractional part st1
    fxch st1                    ; swap st0, st1
    f2xm1                       ; 2 ^ st0 - 1
    fld1                        ; push 1            
    faddp                       ; st0 += st1 
    fscale                      ; st0 *= 2 ^ st1 
    fstp st1                    ; st0 = x^y
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
    fabs                         ; log doesn't support neg. values
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
    cmp byte [sign], 0
    je .exit
    fchs

.exit:
    fstp qword [fsig]
    ret

;--- _dtoa(double) -> const char*
;--- input: fstack (st0), edi - pointer to write
;--- convert double to ASCII
_dtoa:
%define CONTROL_WORD    word [ebp-2]
%define TEN             word [ebp-4]
%define TEMP            word [ebp-4]
    
    push ebp
    mov ebp, esp
    sub esp, 4 
		
    fstcw CONTROL_WORD
    mov ax, CONTROL_WORD
    or ah, 0b00001100           ; set RC=11: truncating rounding mode
    mov TEMP, ax
    fldcw TEMP                  ; load new rounding mode

    ; separate integer and fractional part & convert integer part into ASCII
    fst
    frndint                     ; st0 to integer
    fsub st1, st0               ; integral part in st0, fractional part in st1
    call fpu2bcd2dec
    fabs                        ; make fractional positive (not guaranteed by fsub)

    mov byte [edi], '.'         ; decimal point
    add edi, 1

    ; push 10 to st1	
    mov TEN, 10
    fild TEN
    fxch

; isolate digits of fractional part and store ASCII
.get_fractional:
    fmul st0, st1               ; Multiply by 10 (shift one decimal digit into integer part)
    fist word TEMP              ; Store digit
    fisub word TEMP             ; Clear integer part
    mov al, byte TEMP           ; Load digit
    or al, 0x30                 ; Convert digit to ASCII
    mov byte [edi], al          ; Append it to string
    add edi, 1                  ; Increment pointer to string
    fxam                        ; ST0 == 0.0?
    fstsw ax
    sahf
    jnz .get_fractional         ; No: once more
    mov byte [edi], 0           ; Null-termination for ASCIIZ

    ; clean up FPU
    ffree st0                   ; Empty ST(0)
    ffree st1                   ; Empty ST(1)
    fldcw CONTROL_WORD          ; Restore old rounding mode

    leave
    ret                             ; Return: EDI points to the null-termination of the string

fpu2bcd2dec:                    ; Args: ST(0): FPU-register to convert, EDI: target string
    push ebp
    mov ebp, esp
    sub esp, 10                 ; 10 bytes for local tbyte variable

    fbstp [ebp-10]

    mov ecx, 10                 ; Loop counter
    lea esi, [ebp - 1]          ; bcd + 9 (last byte)
    xor bl, bl                  ; Checker for leading zeros

    ; Handle sign
    btr word [ebp-2], 15        ; Move sign bit into carry flag and clear it
    jnc .L1                     ; Negative?
    mov byte [edi], '-'         ; Yes: store a minus character
    add edi, 1

.L1:
    mov al, byte [esi]
    mov ah, al
    shr ah, 4               ; Isolate left nibble
    or bl, ah               ; Check for leading zero
    jz .1
    or ah, 30h              ; Convert digit to ASCII
    mov [edi], ah
    add edi, 1
    
.1:
    and al, 0Fh             ; Isolate right nibble
    or bl, al               ; Check for leading zero
    jz .2
    or al, 30h              ; Convert digit to ASCII
    mov [edi], al
    add edi, 1
    
.2:
    sub esi, 1
    loop .L1

    test bl, bl                 ; BL remains 0 if all digits were 0
    jnz .R1                     ; Skip next line if integral part > 0
    mov byte [edi], '0'
    add edi, 1

.R1:
    mov byte [edi], 0           ; Null-termination for ASCIIZ
    leave
    ret                         ; Return: EDI points to the null-termination of the string
