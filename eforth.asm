	BITS 64

	%define CELLL 8

	%assign _LINK 0

	%macro $CODE 3
	dq _LINK
	%define _LINK $
	db %1, %2
	align CELLL, db 0
%3:
	dq %3_CODE
%3_CODE:
	%endmacro

	%macro $COLON 3
	dq _LINK
	%define _LINK $
	db %1, %2
	align CELLL, db 0
%3:	dq DOLST
	%endmacro

	%macro $NEXT 0
	lodsq
	jmp [rax]
	%endmacro

	section .text
	global _start

DOLST:
	xchg rbp, rsp
	push rsi
	xchg rbp, rsp
	add rax, CELLL
	mov rsi, rax
	lodsq
	jmp [rax]

DOVAR:
	add rax, CELLL
	push rax
	$NEXT

DOCON:
	add rax, CELLL
	push rax
	$NEXT

	$CODE 4,'EXIT',EXITT
	xchg rbp, rsp
	pop rsi
	xchg rbp, rsp
	$NEXT

	$CODE 3,'BYE',BYE
	mov rax, 60		; nr
	mov rdi,  0		; exit code
	syscall

	$CODE 4,'?KEY',QKEY
	mov r10, rsi		; preserve rsi

	mov rax, 0 		; nr
	mov rdi, 1		; fd
	mov rsi, inchr		; addr
	mov rdx, 1              ; len
	syscall

	mov rsi, r10		; restore rsi

	mov al, [qword inchr]
	push rax		; the character

	mov rax, -1
	push rax		; true

	$NEXT

	$CODE 3,'KEY',KEY
	mov r10, rsi		; preserve rsi
	mov rax, 0 		; nr
	mov rdi, 1		; fd
	mov rsi, inchr		; addr
	mov rdx, 1              ; len
	syscall

	mov rsi, r10		; restore rsi

	mov al, [qword inchr]
	push rax		; the character

	$NEXT

	$CODE 4,'EMIT',EMIT
	pop rax
	mov [inchr], al

	mov r10, rsi		; preserve rsi

	mov rax, 1 		; nr
	mov rdi, 1		; fd
	mov rsi, inchr		; addr
	mov rdx, 1              ; len
	syscall

	mov rsi, r10		; restore rsi

	$NEXT

	$COLON 4,'TEST',TEST
	dq KEY,EMIT,BYE,EXITT

_start:
	mov rax, rsp
	mov [_SPP], rax
	mov rbp, rs_top-CELLL
	mov [_RPP], rbp
	cld
	mov rax, TEST
	jmp [rax]		; jump to the address in rax i.e. docol?

	section .bss
_SPP:	resq 1
_RPP:	resq 1
inchr:	resb 1
return_stack: resq 1024
rs_top:
