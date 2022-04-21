	section .text

	global _start

add:
	xchg rbp, rsp		; make data stack the stack

	pop rbx
	pop rax
	add rax, rbx

	mov [msg+12], al

	xchg rbp, rsp		; make return stack the stack
	ret

hello:
	mov rax, 1 		; nr
	mov rdi, 1		; fd
	mov rsi, msg		; addr
	mov rdx, 14             ; len
	syscall

	ret

_start:
	mov rbp, rs_top-8

	push 40
	push 2

	xchg rbp, rsp		; make return stack the stack
	call add
	xchg rbp, rsp		; make data stack the stack

	call hello

	mov rax, 60
	mov rdi, 0
	syscall

	section .data

	msg db "Hello, World!",10

	section .bss

rs:	resq 128
rs_top:

mem:	resq 1024
