global _start

%define BUFF_SIZE 256

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

;--- _pow10
;--- calc 10^st0 and put in st0
%macro pow10 0
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
    fstp st1                    ; st0=10^n
%endmacro

%macro itoa 1
		xor ecx, ecx
		mov bx, %1
		cmp bx, 0         ; check sign 
		jge %%init
  
		mov byte [edi], '-'
		inc edi
		inc cx
		neg bx            ; make input positive

%%init:
		mov ax, bx
		mov bx, 10

%%loop:
		inc ecx
		xor dx, dx
		div bx
		add dl, 48                  ; '0'
		push dx
		test ax, ax
		jnz %%loop

%%stack:
		pop ax
		stosb
		loop %%stack

%endmacro

%macro print_edi 0
		mov ebx, 1
		mov eax, 4
		mov ecx, buffer
		mov edx, edi
		sub edx, buffer
		int 80h
%endmacro


section .bss
    buffer resb BUFF_SIZE       ; buffer to read input

section .text
_start:
    finit                       ; initialize fstack

		print_str 'Enter x: ', 0x0

    mov ebx, 2
    mov eax, 3
    mov edx, BUFF_SIZE
    mov ecx, buffer
    int 80h                     ; buffer=input

    push buffer
    call _atof                  ; st0=real x
    add esp, 4

    call _calc                  ; st0=f(x)
    
		print_str 'The value of the f(x): ', 0x0

    mov edi, buffer             ; put buffer to write
    call _printf                ; print st0
    
_exit:
    mov ebx, 0
    mov eax, 1                  ; sys_exit
    int 80h

_error:
    print_str 'Sorry, but something went wrong', 0xA, 0x0
		jmp _exit

;--- atof(const char*) -> float
;--- convert string to float
;--- output: st0
_atof:
    %define DIGIT byte [ebp-1]
    %define SIGN  byte [ebp-2]
    %define TEN   word [ebp-4] 
    %define I_BUFFER dword [ebp-8]

    enter 8, 0

    fldz                        ; push 0 to st0
    xor eax, eax                ; number of digits after dot
    xor ebx, ebx        
    xor edx, edx                 
    mov ecx, [ebp+8]            ; pointer to first char in input
  
    mov TEN, 10
    mov SIGN, 0

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
    cmp bl, 57                  ; greater than '9'
    jg .error

.valid_digit:
    add eax, edx                ; ++number of digits after dot
    sub bl, 48                  ; get digit
    fimul TEN
    mov DIGIT, bl
    fiadd word DIGIT
    jmp .new_iteration

.dot:                           
    test edx, edx               ; check is it second dot
    jnz .error
    mov edx, 1                  ; first dot occured
    jmp .new_iteration

.check_sign:
    cmp ecx, [ebp+8]            ; check is it first char
    jne .error 
    mov SIGN, 1

.new_iteration:
    inc ecx
    jmp .loop

.error:
    leave
    add esp, 8
    jmp _error                  ; print error message and exit 

.done:
    cmp SIGN, 0                 ; check for sign
    je .divide
    fchs                        ; negate st0

.divide:
    mov I_BUFFER, eax
		fild I_BUFFER
    pow10                       ; st0=10^eax, st1=fvar*st0
    fdivp

.exit:
    leave
    ret

;--- _calc
;--- calculate func value (x = st0)
_calc:
    %define I_BUFFER word [ebp-2]

    enter 2, 0

    mov I_BUFFER, 1
    fild I_BUFFER
    fcomip st1
    jae .2                      ; 1 >= x

    mov I_BUFFER, 20
    fild I_BUFFER
    fcomip st1
    jb .3                       ; 20 < x

.1: ; 54+x^2/(1+x)              1 < x <= 20
    fld st0                     ; st0 = st1 = x
    fmul st0                    ; st0=x^2
    fld1                        ; st0=1, st1=x^2, st2=x
    faddp st2                   ; st0=1+x
    fdivrp                      ; st0=x^2/(1+x)
    mov I_BUFFER, 54            
    fiadd I_BUFFER              ; st0=54 + x^2/(1+x)
    leave
    ret

.2: ; 75 * x^2 - 17 * x         x <= 1
    fld st0                     ; st0=st1=x
    fmul st0                    ; st0=x^2
    mov I_BUFFER, 75
    fimul I_BUFFER              ; st0=75*x^2
    mov I_BUFFER, 17
    fxch st1                    ; st0=x, st1=75*x^2
    fimul I_BUFFER              ; st1=17*x
    fsub                        ; st0=st1-st0
    leave
    ret                         ; done

.3: ; 85 * x / (1 + x)          x > 20
    fld st0                     ; st0 = st1 = x
    mov I_BUFFER, 85         
    fimul I_BUFFER              ; st0 = 85x
    fld1                        ; st0=1, st1=85x, st2=x
    faddp st2                   ; st0=85x, st1=1+x
    fdivrp                      ; st0=st0/st1
    leave
    ret 

;--- _normalize
;--- normalize value in st0
;--- return: st1=significant, st0=exp
_normalize:
    %define SIGN   word  [ebp-2]
    %define OLD_CW word  [ebp-4]
    %define NEW_CW word  [ebp-6]
    %define F_EXP  qword [ebp-14]

    enter 14, 0
    
    fild SIGN
    fcomip st1                  ; compare with zero
    je .exit

    ; fexp = floor(log_10(fvar))
    fld st0
    fabs                        ; log doesn't support neg. values
    fxch st1
    fdiv st0, st1
    fistp SIGN

    fld st0
    fldlg2                      ; st0 = log_10(2)
    fxch st1                    ; st2=fvar, st1=log_10(2), st0=fvar
    fyl2x                       ; st0 = log_10(2) * log_2(fvar)
    fstcw OLD_CW                ; save previous rounding mode
    mov ax, OLD_CW
    or ah, 00000100b            ; rounding mode=3, toward zero
    mov NEW_CW, ax              ; new rounding mode
    fldcw NEW_CW                ; change rounding mode
    frndint                     ; truncate log_10(input)
    fldcw OLD_CW                ; restore rounding mode
    fst F_EXP                   ; store fexp value, st0=fexp, st1=fvar

    ; fsig = fvar / 10^(fexp)
    pow10                 ; st0=10^fexp, st1=fvar
    fdivp                       ; st0=fvar/10^fexp
    
    cmp SIGN, 1
    je .exit
    fchs

.exit:
    fld F_EXP                   ; st0=fexp, st1=significant
    leave
    ret                         ; return:  st1=fsig, st2=fexp

;--- _dtoa(double) -> const char*
;--- input: fstack (st0), edi - pointer to write
;--- convert double to ASCII
_dtoa:
    %define CONTROL_WORD word [ebp-2]
    %define TEN          word [ebp-4]
    %define TEMP         word [ebp-6]
    
    enter 6, 0

    fstcw CONTROL_WORD
    mov ax, CONTROL_WORD
    or ah, 00001100b            ; set RC=11: truncating rounding mode
    mov TEMP, ax
    fldcw TEMP                  ; load new rounding mode

    ; separate integer and fractional part & convert integer part into ASCII
    fst
    frndint                     ; st0 to integer
    fsub st1, st0               ; integral part in st0, fractional part in st1
    call _fpu2bcd2dec
    fabs                        ; make fractional positive (not guaranteed by fsub)

    mov byte [edi], '.'         ; decimal point
    add edi, 1
    mov ecx, 18                 ; less than 18 digits after the dot

    ; push 10 to st1
    mov TEN, 10
    fild TEN
    fxch

; isolate digits of fractional part and store ASCII
.get_fractional:
    fmul st0, st1               ; multiply by 10 (shift one decimal digit into integer part)
    fist word TEMP              ; store digit
    fisub word TEMP             ; clear integer part
    mov al, byte TEMP           ; load digit
    or al, 0x30                 ; convert digit to ASCII, decimal 48
    mov byte [edi], al          ; append it to string
    add edi, 1                  ; increment pointer to string
    fxam                        ; st0 == 0.0?
    fstsw ax                    ; put status word to ax
    sahf                        ; place ax to registers
    
    jz .exit                    ; no: once more
    loop .get_fractional

.exit:
    mov byte [edi], 0           ; null-termination for ASCIIZ

    ; clean up FPU
    ffree st0                   ; empty st0
    ffree st1                   ; empty st1
    fldcw CONTROL_WORD          ; restore old rounding mode

    leave
    ret                         ; return: edi points to the null-termination of the string

_fpu2bcd2dec:                   ; args: st0: FPU-register to convert, edi: target string
    enter 10, 0                 ; 10 bytes for local variable
    fbstp [ebp-10]               

    mov ecx, 10                 ; loop counter
    lea esi, [ebp-1]            ; bcd + 9 (last byte)
    xor bl, bl                  ; checker for leading zeros

    ; handle sign
    btr word [ebp-2], 15        ; move sign bit into carry flag and nullify it
    jnc .L1                     ; negative?
    mov byte [edi], '-'         ; yes: store a minus character
    add edi, 1

.L1:
    mov al, byte [esi]
    mov ah, al
    shr ah, 4                   ; isolate left nibble
    or bl, ah                   ; check for leading zero
    jz .1
    or ah, 30h                  ; convert digit to ASCII
    mov [edi], ah
    add edi, 1
    
.1:
    and al, 0Fh                 ; isolate right nibble, decimal 15
    or bl, al                   ; check for leading zero
    jz .2
    or al, 30h                  ; convert digit to ASCII, decimal 48
    mov [edi], al
    add edi, 1
    
.2:
    sub esi, 1
    loop .L1

    test bl, bl                 ; bl remains 0 if all digits were 0
    jnz .R1                     ; skip next line if integral part > 0
    mov byte [edi], '0'         ; zero if there are no digits before dot
    add edi, 1

.R1:
    mov byte [edi], 0           ; null-termination for ASCIIZ
    leave
    ret                         ; return: edi points to the null-termination of the string

;--- printf(double) -> void
;--- print st0 to stdin
_printf:
    %define I_BUFFER word  [ebp-2]
    %define F_BUFFER qword [ebp-10]

    enter 10, 0

    fst F_BUFFER
    call _normalize             ; st1=significant, st0=fexp
   
    fistp I_BUFFER
    cmp I_BUFFER, 18
    jg .exp_form
    cmp I_BUFFER, -18
    jl .exp_form

.common_form:
    ffree st0
    fld F_BUFFER
    call _dtoa
		print_edi
    
		print_str 0xA, 0x0          ; \n
    leave 
    ret

.exp_form:
    call _dtoa
		mov byte [edi], 'e'
		inc edi
		print_edi

    mov edi, buffer              ; pointer to string
    mov bx, I_BUFFER
		itoa bx                      ; print exp
		print_edi
		print_str 0xA, 0x0           ; \n

    leave
    ret

