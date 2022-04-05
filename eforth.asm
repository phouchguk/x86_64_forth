	BITS 64

	%define CELLL 8
	%define COMPO 040h
	%define BASEE 10

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

	section .data

	_UZERO	dq 0		; start of variable area
	_SPP	dq 0		; bottom of the data stack
	_RPP	dq 0		; bottom of the return stack
	_BASE	dq BASEE	; radix base for numeric i/o
	_TMP	dq 0		; temporary storage
	_IN	dq 0		; current character pointer to input string
	_SPAN	dq 0		; character count received by EXPECT
	_NTIB	dq 0		; end of input string
	_TIBB	dq 0		; beginning of input string
	_EVAL	dq 0		; execution vector for EVAL
	_HLD	dq 0		; next character in numeric output string
	_CNTXT	dq 0		; name field of the last word in the dictionary
	_CP	dq 0		; top of the dictionary
	_LASTN	dq 0		; initial CONTEXT
	ULAST	dq 0		; end of variable area
	_TIB	times 20 dq 0	; terminal input buffer
	_CPP	times 4096 dq 0	; user dictionary

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
	;; Branch to an inline address.
	$CODE COMPO+6,'branch',BRAN
BRAN1:	mov rsi, [rsi]		; IP=[IP]. Do the branching.


	;; donxt ( -- )
	;; Run time code for the single index loop.
	$CODE COMPO+5,'donxt',DONXT
	sub qword [rbp], 1	; decrement loop index on the return stack
	jc NEXT1		; decrement below 0?
	mov rsi, [rsi]		; no, continue loop. IP=[IP]
	$NEXT
NEXT1:	add rbp, CELLL		; pop loop index
	add rsi, CELLL		; exit loop, increment IP to next token
	$NEXT


	;; ! ( w a -- )
	;; Pop the data stack to the memory.
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
	;; Discard top stack item.
	$CODE 4,'DROP',DROP
	pop rax			; pop it
	$NEXT


	;; DUP ( w -- w w )
	;; Duplicate the top stack item.
	$CODE 3,'DUP',DUPP
	pop rax			; pop w
	push rax		; push w twice
	push rax
	$NEXT


	;; SWAP ( w1 w2 -- w2 w1 )
	;; Exchange top two stack items.
	$CODE 4,'SWAP',SWAP
	pop rbx			; pop w2
	pop rax			; pop w1
	push rbx		; push w2
	push rax		; push w1
	$NEXT


	;; OVER ( w1 w2 -- w1 w2 w1 )
	;; Copy second stack item to the top.
	$CODE 4,'OVER',OVER
	mov rax, [rsp + CELLL]	; get w1
	push rax		; push w1
	$NEXT


	;; 0< ( n -- t )
	;; Return true if n is negative.
	$CODE 2,'0<',ZLESS
	pop rax			; pop n
	cdq			; sign extend RAX to RDX
	push rdx		; push sign as flag
	$NEXT


	;; AND ( w w -- w )
	;; Bitwise AND.
	$CODE 3,'AND',ANDD
	pop rax
	pop rbx
	and rax, rbx		; and
	push rax
	$NEXT


	;; OR ( w w -- w )
	;; Bitwise inclusive OR.
	$CODE 2,'OR',ORR
	pop rax
	pop rbx
	or rax, rbx		; or
	push rax
	$NEXT


	;; XOR ( w w -- w )
	;; Bitwise exclusive OR.
	$CODE 3,'XOR',XORR
	pop rax
	pop rbx
	xor rax, rbx		; xor
	push rax
	$NEXT


	;; UM+ ( w w -- w cy )
	;; Add two numbers, return the sum and the carry flag.
	$CODE 3,'UM+',UPLUS
	xor rcx, rcx		; RCX=0 initial carry flag
	pop rbx
	pop rax
	add rax, rbx		; add
	rcl rcx, 1		; get carry
	push rax		; push sum
	push rcx		; push carry
	$NEXT


	;; Chapter 7 - Common Forth words

	;; System variables

	;; sp0 ( -- a )
	;; Pointer to bottom of the data stack.
	$CODE 3,'sp0',SZERO
	lea rax, [_SPP]		; bottom of data stack
	push rax		; push
	$NEXT


	;; rp0 ( -- a )
	;; Pointer to bottom of the return stack.
	$CODE 3,'rp0',RZERO
	lea rax, [_RPP]		; bottom of return stack
	push rax		; push
	$NEXT


	;; base ( -- a )
	;; Storage of the radix base for numeric i/o.
	$CODE 4,'base',BASE
	lea rax, [_BASE]	; Radix for number conversion
	push rax
	$NEXT


	;; tmp ( -- a )
	;; Temporary storage location used in PARSE and FIND.
	$CODE COMPO+3,'tmp',TEMP
	lea rax, [_TMP]		; Temporary storage
	push rax
	$NEXT


	;; span ( -- a )
	;; Hold character count received by EXPECT.
	$CODE 4,'span',SPAN
	lea rax, [_SPAN]	; Character count received
	push rax
	$NEXT


	;; in ( -- a )
	;; Character pointer while parsing input stream.
	$CODE 3,'>in',INN
	lea rax, [_IN]		; Parser pointer
	push rax
	$NEXT


	;; #tib ( -- a )
	;; Hold the current count for the terminal input buffer.
	$CODE 4,'#tib',NTIB
	lea rax, [_NTIB]	; Pointer to end of input buffer
	push rax
	$NEXT


	;; hld ( -- a )
	;; Pointer to numeric output string under construction.
	$CODE 3,'hld',HLD
	lea rax, [_HLD]		; Pointer to output number string
	push rax
	$NEXT


	;; eval ( -- a )
	;; Hold $INTERPRET or $COMPILE
	$CODE 4,'eval',TEVAL
	lea rax, [_EVAL]	; Execution vector for text interpreter
	push rax
	$NEXT


	;; context ( -- a )
	;; Pointer to last name in dictionary
	$CODE 7,'context',CNTXT
	lea rax, [_CNTXT]	; Pointer to last name
	push rax
	$NEXT

	;; cp ( -- a )
	;; Pointer to the top of the code dictionary.
	$CODE 2,'cp',CP
	lea rax, [_CP]		; Pointer to top of dictionary
	push rax
	$NEXT

	;; last ( -- a )
	;; Pointer to the last name in the dictionary.
	$CODE 4,'last',LAST
	lea rax, [_LASTN]	; Initial value for CONTEXT
	push rax
	$NEXT


	;; More stack words

	;; ?DUP ( w -- w w|0 )
	;; Dup tos if it is not zero.
	$CODE 4,'?DUP',QDUP
	pop rax
	or rax, rax 		; test tos
	jz QDUP1
	push rax
QDUP1:	push rax		; push twice
	$NEXT


	;; ROT ( w1 w2 w3 -- w2 w3 w1 )
	;; Rotate third item to top.
	$CODE 3,'ROT',ROT
	pop rax			; pop all 3 items
	pop rbx
	pop rcx
	push rbx		; push them in the desired order
	push rax
	push rcx
	$NEXT


	;; 2DROP ( w w -- )
	;; Discard top 2 items on the stack.
	$CODE 5,'2DROP',DDROP
	pop rax
	pop rax
	$NEXT


	;; 2DUP ( w1 w2 -- w1 w2 w1 w2 )
	;; Duplicate top two items.
	$CODE 4,'2DUP',DDUP
	pop rax			; pop w2
	pop rbx			; pop w1
	push rbx		; push w1
	push rax		; push w2
	push rbx		; push w1
	push rax		; push w2
	$NEXT


	;; More arithmetic words

	;; + ( w w -- sum )
	;; Add top two items.
	$CODE 1,'+',PLUS
	pop rax
	pop rbx
	add rax, rbx		; add
	push rax
	$NEXT

	;; D+ ( d d -- d )
	;; Double integer addition.
	$CODE 2,'D+',DPLUS
	pop rax
	pop rdx
	pop rbx
	pop rcx
	add rdx, rcx		; add lower half
	adc rax, rbx		; add upper half with carry
	push rdx		; push lower sum
	push rax		; push upper sum
	$NEXT


	;; NOT ( w -- w )
	;; One's compliment of tos.
	$CODE 3,'NOT',INVER
	pop rax
	not rax			; invert all bits
	push rax
	$NEXT


	;; NEGATE ( n -- -n )
	;; Two's compliment of tos.
	$CODE 6,'NEGATE',NEGAT
	pop rax
	neg rax			; negate
	push rax
	$NEXT


	;; DNEGATE ( d -- -d )
	;; Two's compliment of top double integer.
	$CODE 7,'DNEGATE',DNEGA
	pop rax			; dh
	pop rdx			; dl
	neg rax			; negate dh
	neg rdx			; negate dl
	sbb rax, 0		; Carry into dh
	push rdx
	push rax
	$NEXT


	;; - ( n1 n2 -- n1-n2 )
	;; Subtraction.
	$CODE 1,'-',SUBBB
	pop rbx
	pop rax
	sub rax, rbx		; sub
	push rax
	$NEXT


	;; ABS ( n -- n )
	;; Return the absolute value of n.
	$CODE 3,'ABS',ABSS
	pop rax
	or rax, rax
	jge ABS1
	neg rax
ABS1:	push rax
	$NEXT


	;; TEST COLON CALLS ( -- )
	;; Test colon calls.
	$COLON 7,'TESTABC',TESTABC
	dq DOLIT,100,DOLIT,197,SUBBB,ABSS,DOLIT,98,DOLIT,97,DOLIT,10,UPLUS,DROP,OVER,QDUP,ZLESS,DROP,EMIT,EMIT,EMIT,EMIT,EXITT


	;; TEST ( -- )
	;; My test code.
	$COLON 4,'TEST',TEST
	dq TESTABC,DOLIT,10,DOLIT,mem,CSTOR,DOLIT,mem,CAT,EMIT,BYE,EXITT

_start:
	mov rax, rsp
	mov [_SPP], rax
	mov rbp, rs_top-CELLL
	mov [_RPP], rbp
	mov qword [_TIBB], _TIB
	mov qword [_CP], _CPP
	mov qword [_CNTXT], _LINK
	mov qword [_LASTN], _LINK

	cld
	mov rax, TEST
	jmp [rax]		; jump to the address in rax i.e. docol?

	section .bss
inchr:	resb 1
return_stack: resq 128
rs_top:
mem:	resb 4098
