numargs     equ 3
sys_exit    equ 1
sys_read    equ 3
sys_write   equ 4
stdin       equ 0 
stdout      equ 1
stderr      equ 3	

extern      printf
extern      puts
extern      loadimg
extern      saveimg
extern      getdims
extern      getdats
extern      pixchange

SECTION .data
	testfmt:    db  "%s %s", 10, 0 
	infail:     db  "The input file route %s is invalid.", 10, 0  
	outfail1:   db  "The output file route %s is invalid.", 10, 0	
	outfail2:   db  "The output file route %s is protected, change permissions.", 10, 0
	argfail:    db  "The number of arguments is different to 2.", 10, 0
	c:          dd  0    ;column iterator
	r:          dd  0    ;row iterator
	k:          dd  0    ;channel iterator
	;declaring NASM variables

SECTION .bss
	arg1:		resd	1
	arg2:		resd	1
	numa:		resd	1
	dats:		resq	1
	cols:		resd	1
	colm:		resd	1
	rows:		resd	1
	pix1:		resd	1
	pix2:		resd	1
	;reserving memory space for variables that will be brought from C++	
	
SECTION	.text
global 	main

main:
	mov     ecx, [esp + 4] ;number of arguments 
	mov     [numa], ecx    ;store this value

	mov     edx, [esp + 8] ;pointer to start of argument array
	mov     eax, dword[edx + 4] ;store the first two arguments
	mov     [arg1], eax
	mov     eax, dword[edx + 8]
	mov     [arg2], eax
 	
	;push   dword[arg2]  ;test for printing the arguments
	;push   dword[arg1]  ;..to see if the program is reading them
	;push   testfmt
	;call   printf
	;push   dword[numa]  
	;all    print	   

	cmp     dword[numa], numargs ;compare the number of arguments
				     ;..received against the expected number
	jne     nicht ;its different
	je      jah   ;its the same

nicht:
	push    argfail ;failing message, number of arguments is greater
	call    printf  ;..than the two expectex arguments
	jmp     exit

jah:
	push    dword[arg1] ;puts into the stack the input route
	call    loadimg ;calls the external function that loads an image
			;.. and it returns a value depending on what happens
	cmp     eax,0   ;whatever that function returns is stored in eax
			;in this case we are checking if it returns 0 = failure
			;or if returns 1 = success at loading the image
	jne     success
	je      fail1   

fail1:
;fail1 is a failure for an invalid input route
	push    dword[arg1]
	push    infail
	call    printf
	jmp     exit

fail2:
;fail2 is a failure for an invalid output route
	push    dword[arg2]
	push    outfail1
	call    printf
	jmp     exit

fail3:
;fail3 is a failure for a protected output route
	push    dword[arg2]
	push    outfail2
	call    printf
	jmp     exit

success:
	call    getdims ;returns a pointer to an array with rows and cols values
	mov     ecx, [eax]
	mov     [cols], ecx
	mov     ecx, [eax + 4]
	mov     [rows], ecx
	
	mov     eax, [cols]
	mov     edx, 0	
	mov     ecx, 2
	div     ecx
	mov     [colm], eax ;half of the cols, because this is the horizontal
			;..iteration limit, all that is needed for the mirror effect

	mov     [dats], eax
	jmp     startloop

;the image data 'grid' (which is really an array) the program iterates with
;the following formula:
;col: number of given columns
;3: fixed number of jpg channels
;r: row iterator
;c: column iterator
;k: channel iterator

;r * col * 3   +   c * 3  + k ; origin pixel
;3 * ((r * col) + c) + k     ; factorized expression

;r * col * 3   +  (col - c) * 3  + k ; destination pixel
;3 * (col * (r + 1) - c) + k  ;factorized expression

; By chance after factorizing, the resulting expression has a nested chained form,
; ..which permits an easily solving of it with the concept of stack in ASM, doing 
; ..operations from the innermost to the outermost, without having to store inter-
; ..mediate values in other registries/variables.

;loop format:
;initialize iterator variable
;[label of loop start]
;	code of the loop control, check the iterator variable against a control variable (max)
;if the 'equal' condition is not fulfilled, jump back to the loop start/label

startloop:
;indentation just for aestethical value and understanding the nested loops
mov	[r], dword 0 ;row iterator
rowloop:		
	mov	[c], dword 0 ;column iterator
	columnloop:
		mov	[k], dword 0 ;channel iterator
		channelloop:
			;find the origin pixel
			mov      eax, [cols]			
			imul     dword[r]
			add      eax, [c]
			mov      ecx, 3
			imul     eax, ecx
			add      eax, [k]
			mov      [pix1], eax

			;find the destination pixel
			mov      eax, [r]
			add      eax, 1
			imul     dword[cols]
			sub      eax, [c]
			mov      ecx, 3
			imul     eax, ecx
			add      eax, [k]			
			mov      [pix2], eax
		
			push     dword[pix1]
			push     dword[pix2]
			call     pixchange ;swap both origin and destination

		;end channelloop, check the channel iterator
		mov     eax, [k]
		inc     eax ;increment
		mov     [k], eax 
		cmp     eax, 3   ;limit is 3
		jne     channeloop
	;end columnloop, check the column iterator
	mov     eax, [c]
	inc     eax ;increment
	mov     [c], eax
	cmp     eax, [colm] ;limit is half the column number
	jne     columnloop
;end rowloop, check the row iterator
mov     eax, [r]
inc     eax ;increment
mov     [r], eax
cmp     eax, [rows] ;limit is number of rows
jne     rowloop

save:
	push    dword[arg2]
	call    saveimg
	cmp     eax, 0
	je      fail2
	cmp     eax, 2
	je      fail3
	jne     exit

exit:
	mov     eax, sys_exit
	int     80H


