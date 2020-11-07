global _start

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

section .text
_start:
		call _print_intro

_exit:
		mov ebx, 0
		mov eax, 1
		int 80h

_sys_write:
    mov ebx, 1
		mov eax, 4
		int 80h
		ret

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
		
		ret

