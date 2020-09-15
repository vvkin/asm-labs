section .text
		global _start

_start: 
		; nullify al
		xor al, al
		
		; nullify array ([] to put 0 to current address)
		mov [dest], al
		mov [dest+1], al
		mov [dest+2], al
		mov [dest+3], al

		; OR : mov byte [dest+i], 0

		; readdressing
		mov al, [source]
		mov [dest+3], al
		mov al, [source+1]
		mov [dest+2], al
		mov al, [source+2]
		mov [dest+1], al
		mov al, [source+3]
		mov [dest], al

		; sys_exit
		mov eax, 1
		int 80h

section .data 
		source db 10, 20, 30, 40 
		dest times 4 db "?"
