	BITS 64

	%define CELLL 8
	%define COMPO 040h

	%assign _LINK 0

	%macro $CODE 3
	dq _LINK
	%define _LINK $
	db %1, %2
%3:
	dq %3_CODE
%3_CODE:
	%endmacro

	%macro $COLON 3
	dq _LINK
	%define _LINK $
	db %1, %2
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


	;; EXIT ( -- )
	;; Terminate a colon definition.
	$CODE 4,'EXIT',EXITT
	xchg rbp, rsp
	pop rsi
	xchg rbp, rsp
	$NEXT


	;; BYE ( -- )
	;; Exit eForth.
	$CODE 3,'BYE',BYE
	mov rax, 60		; nr
	mov rdi,  0		; exit code
	syscall


	;; ?KEY ( -- c T | F )
	;; Return input character and true, or a false and no input.
	$CODE 4,'?KEY',QKEY
	mov r10, rsi		; preserve rsi

	mov rax, 0 		; nr
	mov rdi, 1		; fd
	mov rsi, inchr		; addr
	mov rdx, 1              ; len
	syscall

	mov rsi, r10		; restore rsi

	mov al, [inchr]
	push rax		; the character

	mov rax, -1
	push rax		; true

	$NEXT


	;; KEY ( -- c )
	;; Wait for and return an input character.
	$CODE 3,'KEY',KEY
	mov r10, rsi		; preserve rsi
	mov rax, 0 		; nr
	mov rdi, 1		; fd
	mov rsi, inchr		; addr
	mov rdx, 1              ; len
	syscall

	mov rsi, r10		; restore rsi

	mov al, [inchr]
	push rax		; the character

	$NEXT


	;; EMIT ( c -- )
	;; Send character c to the output device.
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


	;; EXECUTE ( cfa -- )
	;; Execute the word at code field address.
	$CODE 7,'EXECUTE',EXECUTE
	pop rax
	jmp [rax]


	;; dolit ( -- w )
	;; Push an inline literal.
	$CODE COMPO+5,'dolit',DOLIT
	lodsq
	push rax
	$NEXT


	;; ?branch ( f -- )
	;; Branch if flag is zero.
	$CODE COMPO+7,'?branch',QBRAN
	pop rax			; pop flag
	or rax, rax		; flag=0?
	jz BRAN1		; yes, do branch
	add rsi, CELLL		; point IP to next token
	$NEXT


	;; branch ( -- )
	;; Branch to an inline address
	$CODE COMPO+6,'branch',BRAN
BRAN1:	mov rsi, [rsi]		; IP=[IP]. Do the branching.


	;; donxt ( -- )
	;; Run time code for the single index loop
	$CODE COMPO+5,'donxt',DONXT
	sub qword [rbp], 1	; decrement loop index on the return stack
	jc NEXT1		; decrement below 0?
	mov rsi, [rsi]		; no, continue loop. IP=[IP]
	$NEXT
NEXT1:	add rbp, CELLL		; pop loop index
	add rsi, CELLL		; exit loop, increment IP to next token
	$NEXT


	;; ! ( w a -- )
	;; Pop the data stack to the memory
	$CODE 1,'!',STORE
	pop rbx
	pop qword [rbx]
	$NEXT


	;; @ ( a -- w )
	;; Push memory location to the data stack.
	$CODE 1,'@',ATT
	pop rbx
	push qword [rbx]
	$NEXT


	;; C! ( c b -- )
	;; Pop the data to byte memory.
	$CODE 2,'C!',CSTOR
	pop rbx			; pop address b
	pop rax			; pop byte c
	mov [rbx], al		; store c in b
	$NEXT


	;; C@ ( b -- c )
	;; Push byte memory location to the data stack.
	$CODE 2,'C@',CAT
	pop rbx			; pop address b
	xor rax, rax		; clear rax to receive one byte
	mov al, [ebx]		; get one byte c at b
	push rax		; push c
	$NEXT


	;; rp@ ( -- a )
	;; Push the current RP on the data stack.
	$CODE 3,'rp@',RPAT
	push rbp		; push RP on stacl
	$NEXT


	;; rp! ( a -- )
	;; Set the return stack pointer.
	$CODE COMPO+3,'rp!',RPSTO
	pop rbp			; pop a and store it in RP
	$NEXT


	;; R> ( -- w )
	;; Pop the return stack to the data stack.
	$CODE 2,'R>',RFROM
	push qword [rbp]	; push top of return stack on data stack
	add rbp, CELLL		; adjust RP
	$NEXT


	;; R@ ( -- w )
	;; Copy top of return stack to the data stack.
	$CODE 2,'R@',RAT
	push qword [rbp]	; push top of return stack on data stack
	$NEXT			; leave RP alone


	;; >R ( w -- )
	;; Push the data stack to the return stack.
	$CODE COMPO+2,'>R',TOR
	sub rbp, CELLL 		; adjust RP
	pop qword [rbp]		; pop w and store it on return stack
	$NEXT


	;; sp@ ( -- a )
	;; Push the current data stack pointer.
	$CODE 3,'sp@',SPAT
	mov rax, rsp		; Get data stack pointer rsp
	push rax		; Push it
	$NEXT


	;; sp! ( a -- )
	;; Set the data stack pointer.
	$CODE 3,'sp!',SPSTO
	pop rax			; Pop a
	mov rsp, rax		; Store it in rsp
	$NEXT


	;; DROP ( w -- )
	;; Discard top stack item
	$CODE 4,'DROP',DROP
	pop rax			; pop it
	$NEXT


	;; DUP ( w -- w w )
	;; Duplicate the top stack item
	$CODE 3,'DUP',DUPP
	pop rax			; pop w
	push rax		; push w twice
	push rax
	$NEXT


	;; SWAP ( w1 w2 -- w2 w1 )
	;; Exchange top two stack items.
	$CODE 4,'SWAP',SWAP
	pop rbx
	pop rax
	push rbx
	push rax
	$NEXT


	;; OVER ( w1 w2 -- w1 w2 w1 )
	;; Copy second stack item to the top.
	$CODE 4,'OVER',OVER
	mov rax, [rsp + CELLL]	; get w1
	push rax		; push w1
	$NEXT



	;; TEST COLON CALLS ( -- )
	;; Test colon calls.
	;; c b a b -> b a b c
	$COLON 7,'TESTABC',TESTABC
	dq DOLIT,99,DOLIT,98,DOLIT,97,OVER,EMIT,EMIT,EMIT,EMIT,EXITT


	;; TEST ( -- )
	;; My test code.
	$COLON 4,'TEST',TEST
	dq TESTABC,DOLIT,10,DOLIT,mem,CSTOR,DOLIT,mem,CAT,EMIT,BYE,EXITT

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
mem:	resb 4098
