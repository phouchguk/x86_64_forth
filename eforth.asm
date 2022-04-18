	BITS 64

	%define VER 5
	%define EXT 2

	%define CELLL 8
	%define COMPO 040h
	%define IMEDD 080h
	%define MASKK 0ff1fh
	%define BASEE 16
	%define LF 10
	%define BKSPP 8
	%define _LINK 0

	%macro $CODE 3
	dq _LINK
%3_NAME:
	%define _LINK %3_NAME
	db %1, %2
%3:
	dq %3_CODE
%3_CODE:
	%endmacro

	%macro $COLON 3
	dq _LINK
%3_NAME:
	%xdefine _LINK %3_NAME
	db %1, %2
%3:
	dq DOLST
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


	;; SYS1 ( code nr -- n )
	;; One arg syscall.
	$CODE 4,'SYS1',SYS1
	pop rax
	pop rdi
	syscall
	push rax
	$NEXT


	;; SYS4 ( len addr fd nr -- n )
	$CODE 4,'SYS4',SYS4
 	mov r10, rsi		; preserve rsi

	pop rax
	pop rdi
	pop rsi
	pop rdx
	syscall
	push rax

	mov rsi, r10		; restore rsi
	$NEXT


	;; BYE ( -- )
	;; Exit eForth.
	$COLON 3,'BYE',BYE
	dq DOLIT,0		; exit code
	dq DOLIT,60		; sycall nr i.e. EXIT
	dq SYS1


	;; ?KEY ( -- c T | F )
	;; Return input character and true, or a false and no input.
	$CODE 4,'?KEY',QKEY
	xor rax, rax		; setup for false flag
	push rax
	$NEXT


	;; KEY ( -- c )
	;; Wait for and return an input character.
	$CODE 3,'KEY',KEY
	xor rax, rax		; reset [inchr], rax=0, nr for kernel
	mov [inchr], al

	mov r10, rsi		; preserve rsi
	xor rdi, rdi		; rdi=0, fd=stdin
	mov rsi, inchr		; addr
	mov rdx, 1              ; len
	syscall

	mov rsi, r10		; restore rsi

	mov al, [inchr]		; will be zero if nothing was written because we reset it
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
	$CODE 7,'EXECUTE',EXECU
	pop rax
	jmp [rax]
	;; no $NEXT because jumping


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
	jz short BRAN1		; yes, do branch
	add rsi, CELLL		; point IP to next token
	$NEXT


	;; branch ( -- )
	;; Branch to an inline address.
	$CODE COMPO+6,'branch',BRAN
BRAN1:	mov rsi, [rsi]		; IP=[IP]. Do the branching.
	$NEXT


	;; donxt ( -- )
	;; Run time code for the single index loop.
	$CODE COMPO+5,'donxt',DONXT
	sub qword [rbp], 1	; decrement loop index on the return stack
	jc short NEXT1		; decrement below 0?
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
	cqo			; sign extend RAX to RDX
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
	jz short QDUP1
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
	jge short ABS1
	neg rax
ABS1:	push rax
	$NEXT


	;; More comparison words

	;; = ( w w -- t )
	;; Return true if top two are equal.
	$CODE 1,'=',EQUAL
	xor rax, rax		; init a false flag
	pop rdx
	pop rbx
	xor rdx, rbx		; compare
	jnz short EQU1
	dec rax			; change false flag to true flag
EQU1:	push rax
	$NEXT


	;; U< ( u u -- t )
	;; Unsigned compare of top two items.
	$CODE 2,'U<',ULESS
	pop rbx
	pop rax
	sub rax, rbx		; compare
	sbb rax, rax		; use carry to generate true or false flag
	push rax
	$NEXT


	;; < ( n1 n2 -- t )
	;; Signed compare of top two items.
	$CODE 1,'<',LESS
	xor rax, rax		; init false flag
	pop rbx
	pop rcx
	sub rcx, rbx		; compare
	jge short LESS1
	dec rax			; make true flag
LESS1:	push rax
	$NEXT


	;; MAX ( n n -- n )
	;; Return the greater of top two stack items.
	$CODE 3,'MAX',MAX
	pop rbx
	pop rax
	cmp rax, rbx		; compare
	jge short MAX1		; select larger
	xchg rax, rbx
MAX1:	push rax
	$NEXT


	;; MIN ( n n -- n )
	;; Return the smaller of top two stack items.
	$CODE 3,'MIN',MIN
	pop rbx
	pop rax
	cmp rax, rbx		; compare
	jge short MIN1		; select smaller
	xchg rax, rbx
MIN1:	push rbx
	$NEXT


	;; WITHIN (u ul uh -- t )
	;; Return true if u is within range of ul and uh.
	$COLON 6,'WITHIN',WITHI
	dq OVER,SUBBB,TOR	; range between ul and uh
	dq SUBBB,RFROM,ULESS	; range between ul and uh
	dq EXITT


	;; Multiply and divide

	;; UM/MOD ( udl udh un -- ur uq )
	;; Unsigned divide of a double by a single. Return mod and quotient.
	$CODE 6,'UM/MOD',UMMOD
	pop rbx			; un
	pop rdx			; udh
	pop rax			; udl
	or rbx, rbx		; if un=0
	jnz short UMM1
UMM:	mov rax, -1		; return two -1's
	push rax
	push rax
	$NEXT
UMM1:	div rbx			; else unsigned divide
	push rdx		; remainder
	push rax		; quotient
	$NEXT


	;; M/MOD ( d n -- r q )
	;; Signed floored divide of double by single. Return mod and quotient.
	$CODE 5,'M/MOD',MSMOD
	pop rbx			; n
	pop rdx			; dh
	pop rax			; dl
	or rbx, rbx		; if n=0
	jz short UMM
MSM1:	div rbx			; signed divide
	push rdx		; remainder
	push rax		; quotient
	$NEXT


	;; /MOD ( n1 n2 -- r q )
	;; Signed divide. Return mod and quotient.
	$COLON 4,'/MOD',SLMOD
	dq OVER,ZLESS,SWAP	; sign extend n1
	dq MSMOD		; floored divide
	dq EXITT

	;; MOD ( n n -- r )
	;; Signed divide. Return mod only.
	$COLON 3,'MOD',MODD
	dq SLMOD,DROP		; divide and discard remainder
	dq EXITT

	;; / ( n n -- q )
	;; Signed divide. Return quotient only.
	$COLON 1,'/',SLASH
	dq SLMOD,SWAP,DROP	; divide and discard quotient
	dq EXITT


	;; UM* ( u u -- ud )
	;; Unsigned multiply. Return double product.
	$CODE 3,'UM*',UMSTA
	pop rax
	pop rbx
	mul rbx			; unsigned multiply
	push rax
	push rdx
	$NEXT


	;; M* ( n n -- d )
	;; Signed multiply. Return double product.
	$CODE 2,'M*',MSTAR
	pop rbx
	pop rax
	imul rbx		; signed multiply
	push rax
	push rdx
	$NEXT


	;; * ( n n -- n )
	;; Signed multiply. Return single product.
	$CODE 1,'*',STAR
	pop rax
	pop rbx
	imul rbx		; signed multiply
	push rax
	$NEXT


	;; Scaling

	;; */MOD ( n1 n2 n3 -- r q )
	;; Multiply n1 and n2. then divide by n3. Return mod and quotient.
	$COLON 5,'*/MOD',SSMOD
	dq TOR,MSTAR		; n1*n2
	dq RFROM,MSMOD		; (n1*n2)/n3 with remainder
	dq EXITT


	;; */ ( n1 n2 n3 -- q )
	;; Multiply n1 by n2, then divide by n3. Return quotient only.
	$COLON 2,'*/',STASL
	dq SSMOD,SWAP		; (n1*n2)/n3
	dq DROP			; discard remainder
	dq EXITT

	;; Memory alignment words

	;; 8+ ( a -- a+8 )
	;; Add cell size in bytes to address.
	$CODE 2,'8+',CELLP
	pop rax
	add rax, CELLL		; plus 8
	push rax
	$NEXT


	;; 8- ( a -- a-8 )
	;; Subtract cell size in bytes from address.
	$CODE 2,'8-',CELLM
	pop rax
	sub rax, CELLL		; minus 8
	push rax
	$NEXT


	;; 8* ( n -- n*8 )
	;; Multiply tos by cell size in bytes.
	$CODE 2,'8*',CELLS
	pop rax
	shl rax, 3		; shift left 3 bits
	push rax
	$NEXT


	;; 1+ ( a -- a+1 )
	;; Add one to address.
	$CODE 2,'1+',ONEP
	pop rax
	add rax, 1		; increment
	push rax
	$NEXT


	;; 1- ( a -- a-1 )
	;; Subtract one from address.
	$CODE 2,'1-',ONEM
	pop rax
	sub rax, 1
	push rax
	$NEXT


	;; 2+ ( a -- a+2 )
	;; Add two to address.
	$CODE 2,'2+',TWOP
	pop rax
	add rax, 2		; increment
	push rax
	$NEXT


	;; 2- ( a -- a-2 )
	;; Subtract two from address.
	$CODE 2,'2-',TWOM
	pop rax
	sub rax, 2
	push rax
	$NEXT


	;; Special characters

	;; BL ( -- 32 )
	;; Return 32, the blank character.
	$COLON 2,'BL',BLANK
	dq DOLIT,' '		; blank
	dq EXITT


	;; >CHAR ( c -- c )
	;; Filter non-printing characters.
	$COLON 5,'>CHAR',TCHAR
	dq DOLIT,07FH,ANDD,DUPP		; mask msb
	dq DOLIT,127,BLANK,WITHI	; check for printable
	dq QBRAN,TCHA1
	dq DROP,DOLIT,'_'		; replace non-printable
TCHA1:
	dq EXITT


	;; Managing data stack

	;; depth ( -- n )
	;; Return the depth of the data stack.
	$COLON 5,'depth',DEPTH
	dq SPAT,DOLIT,_SPP,ATT	; top and bottom of data stack
	dq SWAP,SUBBB
	dq DOLIT,CELLL,SLASH	; divide by 8
	dq EXITT


	;; PICK ( .. +n -- .. w )
	;; Copy the nth stack item to tos.
	$COLON 4,'PICK',PICK
	dq ONEP,CELLS		; 0 based
	dq SPAT,PLUS,ATT,EXITT	; reach into the data stack


	;; Memory access

	;; +! ( n a -- )
	;; Add n to the contents at address a.
	$CODE 2,'+!',PSTOR
	pop rbx			; a
	pop rax			; n
	add [rbx], rax		; and n to [a]
	$NEXT


	;; 2! ( d a -- )
	;; Store the double integer to address a.
	$CODE 2,'2!',DSTOR
	pop rbx
	pop qword [rbx]		; dl
	pop qword [rbx+CELLL]	; dh
	$NEXT


	;; 2@ ( a -- d )
	;; Fetch double integer from address a.
	$CODE 2,'2@',DAT
	pop rbx
	push qword [rbx+CELLL]	; dh
	push qword [rbx]	; dl
	$NEXT


	;; HERE ( -- a )
	;; Return the top of the code dictionary
	$COLON 4,'HERE',HERE
	dq CP,ATT,EXITT		; [cp]


	;; PAD ( -- a )
	;; Return the address of the text buffer above the code dictionary.
	$COLON 3,'PAD',PAD
	dq HERE,DOLIT,80	; [cp+80]
	dq PLUS,EXITT


	;; TIB ( -- a )
	;; Return the address of the terminal input buffer.
	$COLON 3,'TIB',TIB
	dq DOLIT,_TIB,EXITT


	;; @EXECUTE ( a -- )
	;; Execute vector store in address a.
	$COLON 8,'@EXECUTE',ATEXE
	dq ATT,QDUP		; address or zero?
	dq QBRAN,EXE1
	dq EXECU		; execute if non-zero
EXE1:	dq EXITT		; do nothing if zero


	;; Array and string words

	;; COUNT ( b -- b+1 c )
	;; Return count byte of a string and add one to the byte address.
	$CODE 5,'COUNT',COUNT
	pop rbx			; get b
	xor rax, rax		; clear rax to receive one byte
	mov al, [rbx]		; get c
	inc rbx			; increment b
	push rbx		; push b+1
	push rax		; push c
	$NEXT


	;; CMOVE ( b1 b2 u -- )
	;; Copy u bytes from b1 to b2
	$CODE 5,'CMOVE',CMOVEE
	mov rbx, rsi		; save IP
	pop rcx			; get count
	pop rdi
	pop rsi
	rep movsb		; repeat move bytes
	mov rsi, rbx		; restore IP
	$NEXT


	;; FILL ( b u c -- )
	;; Fill u bytes of character c to area beginning at b.
	$CODE 4,'FILL',FILL
	pop rax			; get byte pattern c
	pop rcx			; get count u
	pop rdi			; get address b
	rep stosb		; repeat store bytes
	$NEXT


	;; ERASE ( b u -- )
	;; Erase u bytes beginning at b.
	$COLON 5,'ERASE',ERASE
	dq DOLIT,0,FILL		; just fill with zero
	dq EXITT


	;; PACK$ ( b u a -- a )
	;; Build a counted string at a from string with u characters at b.
	$COLON 5,'PACK$',PACKS
	dq DUPP,TOR		; save count
	dq DDUP,CSTOR,ONEP	; store count
	dq SWAP,CMOVEE,RFROM	; move string
	dq EXITT


	;; Chapter 8 - Text Interpreter

	;; digit ( u -- c )
	;; Convert digit to a character.
	$COLON 5,'digit',DIGIT
	dq DOLIT,9,OVER,LESS	; if u>9
	dq DOLIT,7,ANDD,PLUS	; add 7 for a hex number
	dq DOLIT,'0',PLUS	; convert to ASCII
	dq EXITT


	;; extract ( n base -- n c )
	;; Extract the least significant digit from n.
	$COLON 7,'extract',EXTRC
	dq DOLIT,0,SWAP,UMMOD	; extract least significant digit
	dq SWAP,DIGIT		; convert to ascii digit
	dq EXITT


	;; Number formatting

	;; <# ( -- )
	;; Initiate the numeric output process.
	$COLON 2,'<#',BDIGS	; BeginDIGitString
	dq PAD,HLD,STORE	; point HLD to PAD to accept numeric digits
	dq EXITT


	;; HOLD ( c -- )
	;; Insert a character into the numeric output string.
	$COLON 4,'HOLD',HOLD
	dq HLD,ATT,ONEM		; decrement HLD
	dq DUPP,HLD,STORE	; digits are stored in reverse order
	dq CSTOR		; store digit c
	dq EXITT


	;; # ( u -- u )
	;; Extract one digit from u and append the digit to the output string.
	$COLON 1,'#',DIG
	dq BASE,ATT,EXTRC	; extract least significant digit
	dq HOLD			; append it to numeric output string
	dq EXITT


	;; #S ( u -- 0 )
	;; Convert u until all digits are added to the output string.
	$COLON 2,'#S',DIGS
DIGS1:	dq DIG,DUPP		; append one digit
	dq QBRAN,DIGS2		; if u is not 0
	dq BRAN,DIGS1		; repeat until u is reduced to 0
DIGS2:	dq EXITT


	;; SIGN ( n -- )
	;; Add a minus sign to the numeric output string.
	$COLON 4,'SIGN',SIGN
	dq ZLESS		; if n<0
	dq QBRAN,SIGN1
	dq DOLIT,'-',HOLD	; append minus sign
SIGN1:	dq EXITT


	;; #> ( w -- b u )
	;; Prepare the output string to be TYPEed.
	$COLON 2,'#>',EDIGS
	dq DROP,HLD,ATT		; replace w with HLD
	dq PAD,OVER,SUBBB	; return length of string
	dq EXITT


	;; Number output

	;; str ( w -- b u )
	;; Convert a signed integer to a numeric string.
	$COLON 3,'str',STRR
	dq DUPP,TOR,ABSS	; save w for SIGN, and change w to absolute
	dq BDIGS,DIGS,RFROM	; extract all digits of absolute value
	dq SIGN,EDIGS		; append sign and return buffer and length
	dq EXITT


	;; .R ( w +n -- )
	;; Display an integer in a field of n columns, right justified.
	$COLON 2,'.R',DOTR
	dq TOR,STRR,RFROM	; save column width +n and convert w
	dq OVER,SUBBB,SPACS	; display spaces for right justification
	dq TYPES		; display number string
	dq EXITT


	;; U.R ( w +n -- )
	;; Display an unsigned integer in n column, right justified.
	$COLON 3,'U.R',UDOTR
	dq TOR,BDIGS,DIGS,EDIGS		; convert unsigned integer w
	dq RFROM,OVER,SUBBB,SPACS 	; add spaces for right justification
	dq TYPES			; display string number
	dq EXITT


	;; U. ( u -- )
	;; Display an unsigned integer in free format.
	$COLON 2,'U.',UDOT
	dq BDIGS,DIGS,EDIGS	; convert unsigned integer w
	dq SPACE,TYPES		; add space and display number string
	dq EXITT


	;; . ( w -- )
	;; Display an integer in free format, followed by a space.
	$COLON 1,'.',DOT
	dq BASE,ATT,DOLIT,10,XORR	; decimal?
	dq QBRAN,DOT1
	dq UDOT,EXITT		; No, display unsigned number
DOT1:	dq STRR,SPACE,TYPES	; Yes, display signed number
	dq EXITT


	;; ? ( a -- )
	;; Display the contents in a memory cell.
	$COLON 1,'?',QUEST
	dq ATT,DOT
	dq EXITT


	;; HEX ( -- )
	;; Use radix 16 as base for numeric conversions.
	$COLON 3,'HEX',HEX
	dq DOLIT,16,BASE,STORE
	dq EXITT


	;; DECIMAL ( -- )
	;; Use radix 10 as base for numeric conversions.
	$COLON 7,'DECIMAL',DECIMAL
	dq DOLIT,10,BASE,STORE
	dq EXITT


	;; Numeric input

	;; digit? ( c base -- u t )
	;; Convert a character to its numeric value. A flag indicates success.
	$COLON 6,'digit?',DIGTQ
	dq TOR,DOLIT,'0',SUBBB	; save radix, convert ASCII to digit
	dq DOLIT,9,OVER,LESS	; is digit greater than 9?
	dq QBRAN,DGTQ1
	dq DOLIT,7,SUBBB	; Yes, convert hex to decimal digit
	dq DUPP,DOLIT,10,LESS,ORR	; if digit<10, change it to -1
DGTQ1:	dq DUPP,RFROM,ULESS	 	; if digit>=base, return a false flag
	dq EXITT


	;; number? ( a -- n T | a F )
	;; Convert a number string to integer. Push a flag on tos.
	$COLON 7,'number?',NUMBQ
	dq BASE,ATT,TOR		; save the current radix in BASE
	dq DOLIT,0,OVER,COUNT	; a 0 a+1 n --, get length of the string
	dq OVER,CAT		; get first digit
	dq DOLIT,'$',EQUAL	; is it a '$' for hexadecimal base?
	dq QBRAN,NUMQ1
	dq HEX,SWAP,ONEP	; Yes, use hexadecimal base and adjust string
	dq SWAP,ONEM		; a 0 a+2 n-1 --
NUMQ1:	dq OVER,CAT		; get next digit
	dq DOLIT,'-',EQUAL,TOR	; is it a '-' sign? Save flag.
	dq SWAP,RAT,SUBBB,SWAP	; a 0 b' n' --, adjust address b
	dq RAT,PLUS,QDUP	; a 0 b" n" n" --, add just count n"
	dq QBRAN,NUMQ6
	dq ONEM,TOR		; valid count, convert string
NUMQ2:	dq DUPP,TOR,CAT		; save address b and get next digit
	dq BASE,ATT,DIGTQ	; convert it according to current radix
	dq QBRAN,NUMQ4		; if it is a valid digit
	dq SWAP,BASE,ATT,STAR	; mutiply it by radix
	dq PLUS,RFROM,ONEP	; add to sum. increment address b.
	dq DONXT,NUMQ2		; loop back to convert next digit
	dq RAT,SWAP,DROP	; completely convert the string. get sign.
	dq QBRAN,NUMQ3
	dq NEGAT		; negate the sum if flag is true
NUMQ3:	dq SWAP			; sum a --
	dq BRAN,NUMQ5
NUMQ4:	dq RFROM,RFROM,DDROP	; if a non-digit was encountered
	dq DDROP,DOLIT,0	; a 0 --, conversion failed
NUMQ5:	dq DUPP			; sum a a -- if success, else a 0 0
NUMQ6:	dq RFROM,DDROP		; discard garbage
	dq RFROM,BASE,STORE	; restore BASE
	dq EXITT


	;; Derived I/O words

	;; nuf? ( -- t )
	;; Return false if no input, else pause and if CR return true.
	$COLON 4,'nuf?',NUFQ
	dq QKEY,DUPP		; got a key?
	dq QBRAN,NUFQ1		; No, return a false flag
	dq DDROP,KEY		; Yes. Get key.
	dq DOLIT,LF,EQUAL	; Is it a CR? Return a flag.
NUFQ1:	dq EXITT


	;; SPACE ( -- )
	;; Send the blank character to the output device.
	$COLON 5,'SPACE',SPACE
	dq BLANK,EMIT		; send space
	dq EXITT


	;; SPACES ( +n -- )
	;; Send n spaces to the output device.
	$COLON 6,'SPACES',SPACS
	dq DOLIT,0,MAX,TOR	; avoid negative numbers
	dq BRAN,CHAR2
CHAR1:	dq SPACE		; send one space
CHAR2:	dq DONXT,CHAR1		; loop back
	dq EXITT


	;; TYPE ( b u -- )
	;; Output u characters from b.
	$COLON 4,'TYPE',TYPES
	dq TOR
	dq BRAN,TYPE2		; skip one loop
TYPE1:	dq DUPP,CAT,TCHAR,EMIT	; emit only printable characters
	dq ONEP			; b+1
TYPE2:	dq DONXT,TYPE1
	dq DROP			; discard b
	dq EXITT


	;; CR ( -- )
	;; Output a carriage return and a line feed.
	$COLON 2,'CR',CR
	dq DOLIT,LF,EMIT	; LF
	dq EXITT


	;; String literal words

	;; do$ ( -- a )
	;; Return the address of a compiled string.
	$COLON COMPO+3,'do$',DOSTR
	dq RFROM		; 1st return address must be saved
	dq RAT,RFROM		; 2ns return address points to counted string a
	dq COUNT,PLUS		; address of next token after string literal
	dq TOR,SWAP		; replace 2nd return address
	dq TOR			; restore saved 1st return address
	dq EXITT


	;; $"| ( -- a )
	;; Runtime routine compiled by $". Return address of compiled string.
	$COLON COMPO+3,'$"|',STRQP
	dq DOSTR		; force a call to do$
	dq EXITT


	;; ."| ( -- )
	;; Runtime routine of .". Output a compiled string.
	$COLON COMPO+3,'."|',DOTQP ;"
	dq DOSTR,COUNT,TYPES	; display following string
	dq EXITT


	;; Parsing

	;; (parse) ( b u c -- b u delta ; <string )
	;; Scan string delimited by c. Return found string and its offset.
	$COLON 7,'(parse)',PARS
	dq TEMP,STORE,OVER	; b u b --, save c
	dq TOR,DUPP		; b u u --, save b test u
	dq QBRAN,PARS8		; if u=0, exit
	dq ONEM,TEMP,ATT	; u not 0, c=blank?
	dq BLANK,EQUAL
	dq QBRAN,PARS3		; u not blank, go forward
	dq TOR			; loop u times to skip blanks
PARS1:	dq BLANK,OVER,CAT	; skip leading blanks
	dq SUBBB,ZLESS,INVER
	dq QBRAN,PARS2		; found non-blank character, go parsing
	dq ONEP
	dq DONXT,PARS1		; b+1 --, end of loop
	dq RFROM,DROP		; string is blank exit
	dq DOLIT,0,DUPP,EXITT	; b 0 0 --
PARS2:	dq RFROM		; found non-blank character, parse
PARS3:	dq OVER,SWAP		; b b u --, start parsing non-space characters
	dq TOR			; loop u times to parse a string
PARS4:	dq TEMP,ATT,OVER
	dq CAT,SUBBB		; scan for delimiter
	dq TEMP,ATT,BLANK,EQUAL
	dq QBRAN,PARS5		; c is not blank
	dq ZLESS
PARS5:	dq QBRAN,PARS6		; c is blank, exit this loop
	dq ONEP			; b+1 --
	dq DONXT,PARS4		; loop back to test next character
	dq DUPP,TOR		; save a copy of b at the end of the loop
	dq BRAN,PARS7		; found a valid string
PARS6:	dq RFROM,DROP,DUPP	; discard loop count
	dq ONEP,TOR		; save a copy of b+1
PARS7:	dq OVER,SUBBB		; length of the parsed string
	dq RFROM,RFROM,SUBBB	; and its offset in the buffer
	dq EXITT		; b u 0 --
PARS8:	dq OVER,RFROM,SUBBB	; b u delta --
	dq EXITT


	;; PARSE ( c -- b u ; <string> )
	;; Scan input stream and return counted string delimited by c.
	$COLON 5,'parse',PARSE
	dq TOR,TIB,INN,ATT,PLUS		; current input buffer pointer to start parsing
	dq NTIB,ATT,INN,ATT,SUBBB	; length of remaining string in TIB
	dq RFROM,PARS			; parse desired string
	dq INN,PSTOR			; move pointer to end of string
	dq EXITT


	;; Parsing Words

	;; .( ( -- )
	;; Output following string up to next ).
	$COLON IMEDD+2,'.(',DOTPTR
	dq DOLIT,')',PARSE,TYPES	; parse till ) and display parsed string
	dq EXITT


	;; ( ( -- )
	;; Ignore following string up to next ). A comment.
	$COLON IMEDD+1,'(',PAREN
	dq DOLIT,')',PARSE,DDROP   ; parse til ) and discard parsed string
	dq EXITT


	;; \ ( -- )
	;; Ignore following text till the end of the line.
	$COLON IMEDD+1,'\',BKSLA
	dq NTIB,ATT,INN,STORE	; make >IN equal to #TIB and terminate parsing
	dq EXITT


	;; WORD ( c -- a ; <string> )
	;; Parse a word from input stream and copy it to code dictionary.
	$COLON 4,'WORD',WORDD
	dq PARSE		; parse till c
	dq HERE,CELLP
	dq PACKS		; pack parsed string to HERE buffer
	dq EXITT


	;; token ( -- a ; <string> )
	;; Parse a word from input stream and copy it to name dictionary.
	$COLON 5,'token',TOKEN
	dq BLANK,WORDD		; parse next string delimited by spaces
	dq EXITT		; pack parsed string to HERE buffer


	;; Dictionary Search

	;; name> ( nfa -- cfa )
	;; Return a code address given a name address.
	$COLON 5,'name>',NAMET
	dq COUNT,DOLIT,31,ANDD	; mask lexicon byte to get length
	dq PLUS			; skip over name field
	dq EXITT


	;; same? ( a1 a2 u -- a1 a2 f \ -0+ )
	;; Compare u-2 bytes in two strings. Return 0 if identical.
	$COLON 5,'same?',SAMEQ
	dq ONEM,TOR		; compare n-1 bytes
	dq BRAN,SAME2		; skip the first round
SAME1:	dq OVER,RAT,PLUS,CAT	; get source byte
	dq OVER,RAT,PLUS,CAT	; get target byte
	dq SUBBB,QDUP		; compare
	dq QBRAN,SAME2		; same?
	dq RFROM,DROP,EXITT	; not same, f<>0
SAME2:	dq DONXT,SAME1		; same, loop for next byte
	dq DOLIT,0		; same, f=0
	dq EXITT


	;; find ( a va -- cfa nfa | a F )
	;; Search a dictionary for a string. Return cfa and nfa if succeeded.
	$COLON 4,'find',FIND
	dq SWAP,DUPP,CAT		; va a count --
	dq TEMP,STORE		       	; count saved in tmp
	dq DUPP,ATT,TOR
	dq TWOP,SWAP			; a+2 va --, first 4 bytes saved on RS
FIND1:	dq ATT,DUPP		        ; a+2 nfa nfa --, end of dictionary?
	dq QBRAN,FIND6		      	; end, return a 0
	dq DUPP,TWOP,SWAP	       	; a+2 nfa+2 nfa --
	dq ATT,RAT,XORR
	dq DOLIT,MASKK,ANDD		; a+2 nfa+2 f --, compare first 2 bytes
	dq QBRAN,FIND2		  	; 2 bytes same, do SAME?
	dq DOLIT,-1		    	; a+2 nfa+2 -1 --, not same, repeat
	dq BRAN,FIND3
FIND2:	dq TEMP,ATT,SAMEQ		; a+2 nfa+2 f --, compare rest of name
FIND3:	dq QBRAN,FIND5		  	; a+2 nfa+2 --
	dq CELLM,TWOM		  	; a+2 lfa --, not this name
	dq BRAN,FIND1		  	; go to next name
FIND5:	dq RFROM,DROP,SWAP,DROP	  	; nfa+2 --
	dq TWOM			  	; nfa --
	dq DUPP,NAMET,SWAP,EXITT  	; cfa nfa --, find name
FIND6:	dq RFROM,DROP			; a+2 0 --, end of dictionary
	dq SWAP,TWOM,SWAP		; a 0 --, return with 0 flag
	dq EXITT


	;; name? ( a -- cfa nfa | a F )
	;; Search dictionary for a string.
	$COLON 5,'name?',NAMEQ
	dq CNTXT,FIND			; initial nfa is in CONTEXT
	dq EXITT


	;; Text input

	;; ^h ( bot eot cur -- bot eot cur )
	;; Backup the cursor by one character.
	$COLON 2,'^h',BKSP
	dq TOR,OVER,RFROM		; bot eot bot cur --
	dq SWAP,OVER,XORR		; bot=cur?
	dq QBRAN,BACK1
	dq DOLIT,BKSPP,EMIT		; backspace
	dq ONEM,BLANK,EMIT		; send blank
	dq DOLIT,BKSPP,EMIT		; backspace again
BACK1:  dq EXITT			; bot=cur, do not backspace


	;; tap ( bot eot cur c -- bot eot cur )
	;; Accept and echo the key stroke and bump the cursor
	$COLON 3,'tap',TAP
	;dq DUPP,EMIT			; duplicate the character and emit it
	dq OVER,CSTOR,ONEP		; store c at cur and increment cur
	dq EXITT


	;; ktap ( bot eot cur c -- bot eot cur )
	;; Process a key stroke, CR or backspace.
	$COLON 4,'ktap',KTAP
	dq DUPP,DOLIT,LF,XORR		; is key a return?
	dq QBRAN,KTAP2
	dq DUPP,DOLIT,BKSPP,XORR	; is key a backspace?
	dq QBRAN,KTAP1
	dq DOLIT,0,XORR		; is key 0
	dq QBRAN,KTAP0
	dq BLANK,TAP,EXITT		; none of above, replace by space
KTAP0:	dq CR,BYE			; quit
KTAP1:	dq BKSP,EXITT			; process backspace
KTAP2: 	dq DROP,SWAP,DROP,DUPP		; process carriage return
	dq EXITT


	;; accept ( b u1 -- b u2 )
	;; Accept characters to input buffer. Return with actual count.
	;; TODO: Should filter chars not WITHI BLANK and 127. Replace with spaces.
	$COLON 6,'accept',ACCEP
	dq OVER,PLUS,OVER		; b b+u1 b --
ACCP1:	dq DDUP,XORR			; b+u1 = current pointer?
	dq QBRAN,ACCP4			; Yes, exit
	dq KEY,DUPP			; No, get next character
	dq BLANK,DOLIT,127,WITHI	; a valid character
	dq QBRAN,ACCP2
	dq TAP				; Yes, accept it to input buffer
	dq BRAN,ACCP3
ACCP2:	dq KTAP				; No, process control character
ACCP3:	dq BRAN,ACCP1			; loop for next character
ACCP4:	dq DROP,OVER,SUBBB		; done, return actual string length
	dq EXITT


	;; query ( -- )
	;; Accept input stream to terminal input buffer.
	$COLON 5,'query',QUERY
	dq TIB,DOLIT,80,ACCEP	; accept up to 80 characters to TIB
	dq NTIB,STORE,DROP	; store actual string length in #TIB
	dq DOLIT,0,INN,STORE	; init >IN
	dq EXITT


	;; ABORT ( -- )
	;; Reset data stack and jump to QUIT.
	$COLON 5,'ABORT',ABORT
	dq PRESE,DOTS,QUIT	; dump stack as well


	;; abort"| ( f -- )
	;; Runtime routine of ABORT". Abort with an error message.
	$COLON COMPO+7,'abort"|',ABORQ ;"
	dq QBRAN,ABOR2	      	      ; test flag
	dq DOSTR		      ; get string address
ABOR1:	dq SPACE,COUNT,TYPES	      ; display error string
	dq DOLIT,'?',EMIT,CR,ABORT    ; go passed error string
ABOR2:	dq DOSTR,DROP		      ; drop error string
	dq EXITT


	;; ?stack ( -- )
	;; Abort if the data stack underflows.
	$COLON 6,'?stack',QSTAC
	dq DEPTH,ZLESS		; check only for underflow
	dq ABORQ		; abort if true
	db 11,' underflow '
	dq EXITT


	;; Text interpreter loop

	;; $INTERPRET ( a -- )
	;; Interpret a word. If failed, try to convert it to an integer.
	$COLON 10,'$interpret',INTER
	dq NAMEQ,QDUP		; word defined
	dq QBRAN,INTE1		; No. Go convert to number.
	dq ATT,DOLIT,COMPO,ANDD	; test compile-only lexicon bit
	dq ABORQ		; if it is compile-only abort
	db 13,' compile only'
	dq EXECU,EXITT		; otherwise, execute defined word
INTE1:	dq NUMBQ		; convert to a number
	dq QBRAN,ABOR1		; not a number, abort
	dq EXITT


	;; [ ( -- )
	;; Start the text interpreter.
	$COLON IMEDD+1,'[',LBRAC
	dq DOLIT,INTER		; get the address of $interpret
	dq TEVAL,STORE		; store it in 'EVAL
	dq EXITT


	;; .ok ( -- )
	;; Display the data stack only while interpreting.
	$COLON 3,'.ok',DOTOK
	dq CR,DOLIT,INTER	; 'EVAL contains $interpret?
	dq TEVAL,ATT,EQUAL
	dq QBRAN,DOTO1		; no, exit
	dq DOTS			; yes, dump stack
DOTO1:	dq EXITT


	;; eval ( -- )
	;; Interpret the input stream.
	$COLON 4,'eval',EVAL
EVAL1:	dq TOKEN,DUPP,CAT	; input stream empty?
	dq QBRAN,EVAL2		; yes, exit
	dq TEVAL,ATEXE,QSTAC	; no, evaluate input, check stack
	dq BRAN,EVAL1		; loop back for the next word
EVAL2	dq DROP,DOTOK		; done, display prompt
	dq EXITT


	;; preset ( -- )
	;; Reset data stack pointer.
	$COLON 6,'preset',PRESE
	dq DOLIT,_SPP,ATT,SPSTO	; init data stack pointer
	dq EXITT


	;; quit ( -- )
	;; Reset return stack pointer and start text interpreter.
	$COLON 4,'quit',QUIT
	dq DOLIT,_RPP,ATT,RPSTO	; init return stack pointer
QUIT1:	dq LBRAC		; start interpretation
QUIT2:	dq QUERY		; get input
	dq EVAL			; process input
	dq BRAN,QUIT2		; continue till error


	;; Chapter 9 - Colon compiler

	;; ' ( -- cfa )
	;; Search dictionary for the next word in input stream.
	$COLON 1,"'",TICK
	dq TOKEN,NAMEQ		; word defined?
	dq QBRAN,ABOR1
	dq EXITT		; yes, push code field address


	;; ALLOT ( n -- )
	;; Allocate n bytes to the code dictionary.
	$COLON 5,'ALLOT',ALLOT
	dq CP,PSTOR		; adjust the dictionary pointer
	dq EXITT


	;; , ( w -- )
	;; Compile an integer to the code dictionary.
	$COLON 1,',',COMMA
	dq HERE,DUPP,CELLP,CP,STORE	; advance CP
	dq STORE			; compile w to dictionary
	dq EXITT


	;; compile ( -- )
	;; Compile the next address in colon list to code dictionary.
	$COLON COMPO+7,'compile',COMPI
	dq RFROM,DUPP,ATT,COMMA		; compile address
	dq CELLP,TOR			; adjust return address
	dq EXITT


	;; [compile] (-- ; <string> )
	;; Compile the next immediate word into code dictionary.
	$COLON IMEDD+9,'[compile]',BCOMP
	dq TICK,COMMA			; search next word and compile its cfa
	dq EXITT


	;; literal ( w -- )
	;; Compile tos to dictionary as an integer literal.
	$COLON IMEDD+7,'literal',LITER
	dq COMPI,DOLIT,COMMA		; compile DOLIT and w as an integer literal
	dq EXITT			; this is an integer literal in a colon word


	;; $," ( -- )
	;; Compile a literal string up to next ".
	$COLON 3,'$,"',STRCQ
	dq DOLIT,'"',PARSE,HERE		; compile string to code dictionary
	dq PACKS,COUNT,PLUS		; calculate aligned end of string
	dq CP,STORE			; adjust the code pointer
	dq EXITT


	;; Control structures

	;; FOR ( -- a )
	;; Start a FOR-NEXT loop structure in a colon definition.
	$COLON IMEDD+3,'FOR',FORR
	dq COMPI,TOR			; compile >R to start a FOR-NEXT loop
	dq HERE				; leave address a of next token
	dq EXITT


	;; NEXT ( a -- )
	;; Terminate a FOR-NEXT loop structure.
	$COLON IMEDD+4,'NEXT',NEXT
	dq COMPI,DONXT,COMMA		; compile DONXT address with address a
	dq EXITT


	;; BEGIN ( -- a )
	;; Start an infinite or indefinite loop structure.
	$COLON IMEDD+5,'BEGIN',BEGIN
	dq HERE				; leave address a of next token
	dq EXITT


	;; UNTIL ( a -- )
	;; Terminate a BEGIN-UNTIL indefinite loop structure.
	$COLON IMEDD+5,'UNTIL',UNTIL
	dq COMPI,QBRAN,COMMA		; compile ?branch address literal with address a
	dq EXITT


	;; AGAIN ( a -- )
	;; Terminate a BEGIN-AGAIN infinite loop structure.
	$COLON IMEDD+5,'AGAIN',AGAIN
	dq COMPI,BRAN,COMMA		; compile branch address literal with address a
	dq EXITT


	;; IF ( -- A )
	;; Begin a conditional branch structure.
	$COLON IMEDD+2,'IF',IFF
	dq COMPI,QBRAN,HERE		; compile ?branch address literal, leave address a
	dq DOLIT,0,COMMA		; init address field to 0
	dq EXITT


	;; ahead ( -- A )
	;; Compile a forward branch instruction.
	$COLON IMEDD+5,'ahead',AHEAD
	dq COMPI,BRAN,HERE		; compile branch address literal, leave address A
	dq DOLIT,0,COMMA		; init address field to 0
	dq EXITT


	;; REPEAT ( A a -- )
	;; Terminate a BEGIN-WHILE-REPEAT indefinite loop.
	$COLON IMEDD+6,'REPEAT',REPEA
	dq AGAIN,HERE,SWAP,STORE	; compile branch address literal with address a
	dq EXITT			; resolve address at A with current token address


	;; THEN ( A -- )
	;; Terminate a conditional branch structure.
	$COLON IMEDD+4,'THEN',THENN
	dq HERE,SWAP,STORE		; resolve address at A with current address
	dq EXITT


	;; AFT ( a -- a A )
	;; Jump to THEN in a FOR-AFT-THEN-NEXT loop the first time through.
	$COLON IMEDD+3,'AFT',AFT
	dq DROP,AHEAD			; compile a branch address literal and leave A
	dq BEGIN,SWAP			; replace a with address of current token
	dq EXITT


	;; ELSE ( A -- A )
	;; Start the false clause in an IF-ELSE-THEN structure.
	$COLON IMEDD+4,'ELSE',ELSEE
	dq AHEAD,SWAP			; compile branch address literal. resolve address at a
	dq THENN			; with current token address. replace A by literal address.
	dq EXITT


	;; WHILE ( a -- A a )
	;; Conditional branch out of a BEGIN-WHILE-REPEAT loop.
	$COLON IMEDD+5,'WHILE',WHILEE
	dq IFF,SWAP
	dq EXITT			; compile branch address literal. Leave literal address A.


	;; String literals

	;; ABORT" ( -- ; <string> )
	;; Conditional abort with an error message.
	$COLON IMEDD+6,'ABORT"',ABRTQ
	dq COMPI,ABORQ,STRCQ		; compile abort"| string literal with following string
	dq EXITT


	;; $" ( -- ; <string> )
	;; Compile an inline string literal.
	$COLON IMEDD+2,'$"',STRQ
	dq COMPI,STRQP,STRCQ		; compile $"| string literal with following string
	dq EXITT


	;; ." ( -- ; <string> )
	;; Compile an inline string literal to be typed out at runtime.
	$COLON IMEDD+2,'."',DOTQ
	dq COMPI,DOTQP,STRCQ		; compile ." string literal with following string
	dq EXITT


	;; Colon word compiler

	;; ?unique ( a -- a )
	;; Display a warning if the word already exists.
	$COLON 7,'?unique',UNIQU
	dq DUPP,NAMEQ			; word defined?
	dq QBRAN,UNIQ1
	dq DOTQP			; redefinitions are ok
	db 7,' reDef '			; but the user should be warned
	dq OVER,COUNT,TYPES		; just in case it is not intended
UNIQ1:	dq DROP
	dq EXITT


	;; $,n ( nfa -- )
	;; Build a new dictionary name using the string at nfa.
	$COLON 3,'$,n',SNAME
	dq DUPP,CAT			; null input?
	dq QBRAN,PNAM1
	dq UNIQU			; redefinition?
	dq DUPP,COUNT,PLUS		; skip over name field
	dq CP,STORE			; CP points to code field now
	dq DUPP,LAST,STORE		; save nfa for dictionary link
	dq CELLM			; link address
	dq CNTXT,ATT,SWAP
	dq STORE,EXITT			; fill link field with CONTEXT
PNAM1:	dq STRQP			; warning message
	db 5,' name'			; null input
	dq BRAN,ABOR1


	;; $compile ( a -- )
	;; Compile next word to code dictionary as a token or literal.
	$COLON 8,'$compile',SCOMP
	dq NAMEQ,QDUP			; word defined
	dq QBRAN,SCOM2
	dq ATT,DOLIT,IMEDD,ANDD		; immediate?
	dq QBRAN,SCOM1
	dq EXECU,EXITT			; it's immediate, execute
SCOM1:	dq COMMA,EXITT			; it's not immediate, compile
SCOM2:  dq NUMBQ			; try to convert to a number
	dq QBRAN,ABOR1
	dq LITER			; compile number as integer literal
	dq EXITT


	;; overt ( -- )
	;; Link a new word into the current dictionary.
	$COLON 5,'overt',OVERT
	dq LAST,ATT
	dq CNTXT,STORE			; initialise CONTEXT from LAST
	dq EXITT


	;; ; ( -- )
	;; Terminate a colon definition.
	$COLON IMEDD+COMPO+1,';',SEMIS
	dq COMPI,EXITT			; compile EXIT
	dq LBRAC,OVERT			; return to interpret mode
	dq EXITT


	;; ] ( -- )
	;; Start compiling the words in the input stream.
	$COLON 1,']',RBRAC
	dq DOLIT,SCOMP	       	     	; change 'EVAL to $compile
	dq TEVAL,STORE			; switch to compile mode
	dq EXITT


	;; : ( -- ; <string> )
	;; Start a new colon definition using next word as its name.
	$COLON 1,':',COLON
	dq TOKEN,SNAME			; get next string and build new name field
	dq DOLIT,DOLST,COMMA		; compile DOLST into code field
	dq RBRAC			; switch to compile mode
	dq EXITT


	;; IMMEDIATE ( -- )
	;; Make the last compiled word an immediate word.
	$COLON 9,'IMMEDIATE',IMMED
	dq DOLIT,IMEDD			; immediate bit
	dq LAST,ATT,CAT,ORR		; add it to lexicon byte in the last name field
	dq LAST,ATT,CSTOR		; store back to lexicon byte
	dq EXITT


	; Defining words

	;; CREATE ( -- ; <string> )
	;; Compile a new array entry without allocating code space.
	$COLON 6,'CREATE',CREAT
	dq TOKEN,SNAME,OVERT		; build new link and name fields
	dq DOLIT,DOVAR,COMMA		; compile DOVAR into code field
	dq EXITT


	;; CONSTANT ( n -- ; <string> )
	;; Compile a new constant.
	$COLON 8,'CONSTANT',CONST
	dq TOKEN,SNAME,OVERT		; build new link and name fields
	dq DOLIT,DOCON,COMMA		; compile DOCON into code field
	dq COMMA			; compile n into parameter field
	dq EXITT


	;; VARIABLE ( -- ; <string> )
	;; Compile a new variable initialised to 0.
	$COLON 8,'VARIABLE',VARIA
	dq CREAT,DOLIT,0,COMMA		; compile link, name and DOVAR field
	dq EXITT


	;; Chapter 10 - Utilities

	;; Memory dump

	;; DUMP ( a -- )
	;; Dump 128 bytes from a, in a formatted manner.
	$COLON 4,'DUMP',DUMP
	dq DOLIT,7			; set line count to 7 for 8 lines
	dq TOR				; start count down loop
DUMP1:	dq CR,DUPP,DOLIT,8,UDOTR	; display address
	dq SPACE,DOLIT,15		; add a space
	dq TOR
DUMP2:	dq COUNT,DOLIT,3,UDOTR		; display 16 bytes of data
	dq DONXT,DUMP2
	dq SPACE,DUPP			; add space
	dq DOLIT,16,SUBBB		; back up 16 bytes
	dq DOLIT,16,TYPES		; display 16 bytes of text
	dq DONXT,DUMP1			; loop till done
	dq DROP
	dq EXITT


	;; Stack dump

	;; .S ( ... -- ... )
	;; Display the contents of the data stack.
	$COLON 2,'.S',DOTS
	dq TOR,TOR,TOR			; save 3 items on stack
	dq DUPP,DOT,RFROM		; dump 4th item
	dq DUPP,DOT,RFROM		; dump 3rd item
	dq DUPP,DOT,RFROM		; dump 2nd item
	dq DUPP,DOT			; dump 1st item
	dq DOTQP
	db 3,' > '			; display separator
	dq EXITT


	;; Dictionary dump

	;; >name ( cfa -- nfa | F )
	;; Convert code address to a name address.
	$COLON 5,'>name',TNAME
	dq CNTXT			; dictionary link
TNAM2:	dq ATT,DUPP			; last word in dictionary?
	dq QBRAN,TNAM4			; yes, reach end of dictionary
	dq DDUP,NAMET,XORR		; no, compare name
	dq QBRAN,TNAM3			; word not found
	dq CELLM			; continue with next word
	dq BRAN,TNAM2
TNAM3:	dq SWAP,DROP,EXITT		; found word, return nfa
TNAM4:	dq DDROP,DOLIT,0		; end of dictionary, return false flag
	dq EXITT


	;; .id ( nfa -- )
	;; Display the name at name field address.
	$COLON 3,'.id',DOTID
	dq QDUP				; if 0, no name
	dq QBRAN,DOTI1
	dq COUNT,DOLIT,01FH,ANDD	; mask lexicon bits
	dq TYPES,EXITT			; display name string
DOTI1:	dq DOTQP			; no name
	db 9,' {noName}'
	dq EXITT


	;; WORDS ( -- )
	;; Display the names in the context dictionary.
	$COLON 5,'WORDS',WORDS
	dq CR,CNTXT			; start at CONTEXT
WORS1:	dq ATT,QDUP			; end of dictionary?
	dq QBRAN,WORS2			; yes, exit
	dq DUPP,SPACE,DOTID		; display a name
	dq CELLM,NUFQ			; user control
	dq QBRAN,WORS1			; repeat next word
	dq DROP				; stop by user
WORS2:	dq EXITT


	;; SEE ( -- ; <string> )
	;; A simple decompiler. Updated for byte machines.
	$COLON 3,'SEE',SEE
	dq TICK				; starting address
	dq CR,CELLP
SEE1:	dq ONEP,DUPP,ATT,DUPP		; does it contain zero?
	dq QBRAN,SEE2
	dq TNAME			; is it a name?
SEE2:	dq QDUP				; name address or zero
	dq QBRAN,SEE3
	dq SPACE,DOTID			; display name
	dq ONEP,TWOP			; next token
	dq BRAN,SEE4
SEE3:	dq DUPP,CAT,UDOT		; display number
SEE4:	dq NUFQ				; user control
	dq QBRAN,SEE1			; decompile next token
	dq DROP
	dq EXITT


	;; cold ( -- )
	;; The high-level cold-start sequence.
	$COLON 4,'cold',COLD
COLD1:	dq HEX,CR,DOTQP			; set base
	db 13,'86eForth v'		; sign-on message
	db VER+'0','.',EXT+'0'		; version and extension
	dq CR,OVERT			; init data stack
	dq ABORT			; start interpretation


_start:
	xor rax, rax
	push rax
	push rax
	push rax
	push rax
	mov rax, rsp
	mov [_SPP], rax
	mov rbp, rs_top-CELLL
	mov [_RPP], rbp
	mov qword [_TIBB], _TIB
	mov qword [_CP], _CPP
	mov qword [_CNTXT], _LINK
	mov qword [_LASTN], _LINK

	cld
	mov rax, COLD
	jmp [rax]		; jump to the address in rax i.e. docol?

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
	_TIB	times 80 db 0	; terminal input buffer
	_CPP	times 4096 dq 0	; user dictionary

	section .bss
inchr:	resb 1
return_stack: resq 128
rs_top:
