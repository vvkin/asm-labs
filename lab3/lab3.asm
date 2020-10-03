global _start

section .data
		msg db 'Enter x:', 10
		len equ $ - msg

section .bss
		buffer resb 128             ; buffer to read inpuy
		dummy  resb 1               ; buffer to read garbage from stdin

section .text
_start:
		mov ebx, 1                  ; stdout
		mov eax, 4                  ; sys_write
		mov edx, len
		mov ecx, msg
		int 80h                     ; call kernel

_clear_buffer:
		mov ecx, 128                ; buffer length
.loop:
		mov byte [buffer+ecx], 0    ; fill with \0
		loop .loop

_read_input:
		mov ebx, 2                  ; stdin
		mov eax, 3
		mov edx, 128                ; input length
		mov ecx, buffer

_flush_stdin:
		mov eax, 3                  ; sys_read
		int 80h
		cmp byte [ecx+eax-1], 10    ; \n
		je _main
		mov edx, 1
		mov ecx, dummy              ; read garbage from stdin
	  jmp _flush_stdin

_main:
		jmp _start

_exit:
		mov ebx, 0
		mov eax, 1                  ; sys_exit
		int 80h

_atof:
		enter 0, 0

.done:

.exit:
		leave
		ret
