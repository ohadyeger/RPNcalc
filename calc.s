section .rodata
        one: db "1", 0
        zero: db "0", 0
        wrong_y_value: db "wrong Y value",10,0
        debug_push_msg: db "pushed to stack (decimal): %u",10,0
        stack_overflow_msg: db "Error: Operand Stack Overflow",10,0
        insufficient_resources_msg: db "Error: Insufficient Number of Arguments on Stack",10,0
        leading_zero_hex_format: db "0%X", 0
        hex_format: db "%X", 0
        newline: dd "",10,0
        calc_prompt: db "calc: ",0
        dash_d: db "-d",0
        debug_read: db "read from user : %s",10,0
        main_print_format: db "%X",10,0
       

section .data
        stackSize: dd 0
        debug: db 0
        count: dd 0
        MAX_SIZE: dd 82
        my_flag: dd 0

section .bss			; we define (global) uninitialized variables in .bss section
	input: resb 82		; enough to store input of size 80
        stack: resb 20   ; 5 pointers

section .text
        align 16
        
        global main 
        extern printf
        extern fprintf 
        extern fflush
        extern malloc 
        extern free 
        extern fgets
        extern stdin
        extern stderr

%macro INC_COUNT 0 
		inc DWORD [count]
%endmacro

%macro ERR_PRINT 2 
		push %2
                push %1
                push dword[stderr]
                call fprintf
                add esp, 12
%endmacro

main:
        push    ebp
        mov     ebp, esp

        push    DWORD [ebp+12]
        push    DWORD [ebp+8]
        call    set_debug
        add     esp, 8

        ;while_loop
        movzx   eax, BYTE [debug]
        movsx   eax, al
        sub     esp, 8
        push    eax
        push    input
        call    while_loop
        add     esp, 16

        ;free_stack
        call    free_stack
        
        mov   eax, DWORD [count]
        push    eax
        push    main_print_format
        call    printf
        add     esp, 8
        leave
        ret

while_loop:
        push    ebp
        mov     ebp, esp
        sub     esp, 8
        jmp     .check_quit
.prompt_msg:
        call    prompt
        sub     esp, 8
        push    DWORD [MAX_SIZE]
        push    DWORD [ebp+8]
        call    get_input
        add     esp, 16
        call    flush
        sub     esp, 8
        push    DWORD [ebp+8]
        push    DWORD [ebp+12]
        call    if_debug
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp+8]
        call    execute
        add     esp, 16
.check_quit:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, 'q'
        jne     .prompt_msg
        leave
        ret

if_debug:
        push    ebp
        mov     ebp, esp
        sub     esp, 8
        cmp     DWORD [ebp+8], 0
        je      .return

        ERR_PRINT debug_read, input
        
.return:
        leave
        ret


set_debug:
        push    ebp
        mov     ebp, esp
        mov     eax, DWORD [ebp+8]
        cmp     eax, 1
        jbe      .return
        mov     eax, DWORD [ebp+12]
        add     eax, 4
        mov     esi, DWORD [eax]
        push    2
        push    dash_d
        push    esi
        call    strncmp
        add     esp, 12
        cmp     eax, 0
        jne     .return
        mov     byte [debug], 1
.return:
        mov esp, ebp	
	pop ebp
        ret

prompt:
        push    ebp
        mov     ebp, esp
        push    calc_prompt
        call    printf
        add     esp, 4
        leave
        ret

flush:
        push    ebp
        mov     ebp, esp
        sub     esp, 8
        mov     eax, DWORD [stdin]
        sub     esp, 12
        push    eax
        call    fflush
        add     esp, 16
        leave
        ret

get_input:
        push    ebp
        mov     ebp, esp
        mov     eax, DWORD [stdin]
        push    eax
        push    DWORD [MAX_SIZE]
        push    DWORD [ebp+8]
        call    fgets
        add     esp, 12
        leave
        ret

free_stack:
        push    ebp
        mov     ebp, esp
        jmp     .while_not_empty
.pop_free:
        call    pop
        push    eax
        call    free_Number
        add     esp, 4
.while_not_empty:
        call    isEmpty
        cmp     eax, 0
        je      .pop_free
        leave
        ret

trim_next:
        push    ebp
        mov     ebp, esp
        mov     eax, DWORD [ebp+8]
        mov     eax, DWORD [eax+4]
        push    eax
        call    trim
        add     esp, 4
        mov     edx, eax
        mov     eax, DWORD [ebp+8]
        mov     DWORD [eax+4], edx
        leave
        ret

; stack operations: //----------------------------------->
isEmpty:
        push ebp
	mov ebp, esp
        mov esi, DWORD[stackSize]
        cmp esi, 0
        jle .return_true
        mov eax, 0
        jmp .return
.return_true:
        mov eax, 1
.return:
        mov esp, ebp	
	pop ebp
	ret

isFull:
        push ebp
	mov ebp, esp
        mov esi, DWORD[stackSize]
        cmp esi, 5
        jge .return_true
        mov eax, 0
        jmp .return
.return_true:
        mov eax, 1
.return:
        mov esp, ebp	
	pop ebp
	ret


push:
        push    ebp
        mov     ebp, esp
        sub     esp, 8
        movzx   eax, byte [debug]
        cmp     eax, 0
        je      .no_debug
        sub     esp, 12
        push    DWORD [ebp+8]
        call    convert_to_decimal
        
        ERR_PRINT debug_push_msg, eax

.no_debug:
        call    isFull
        cmp     eax, 0
        je      .stack_not_full
        sub     esp, 12
        push    stack_overflow_msg
        call    printf
        add     esp, 16

        push    DWORD [ebp+8]
        call    free_Number
        add     esp, 4

        jmp     .return
.stack_not_full:
        mov     eax, DWORD [ebp+8]
        cmp     eax, 0
        je      .next  
        push    eax  
        call    trim_next

        mov     DWORD [ebp+8], eax

        add esp, 4
.next:               
        mov     eax, stack
        mov     esi, DWORD [stackSize]
        shl     esi, 2
        add     eax, esi ;eax <- stack+4*stackSize
        inc     DWORD [stackSize]
        mov     edx, DWORD [ebp+8]
        mov     DWORD [eax], edx
.return:
        leave
        ret

pop:
        push    ebp
        mov     ebp, esp
        sub     esp, 24
        call    isEmpty
        cmp     eax, 0
        je      .not_empty
        sub     esp, 12
        push    insufficient_resources_msg
        call    printf
        add     esp, 16
        mov     eax, 0
        jmp     .return
.not_empty:
        mov     eax, DWORD [stackSize]
        dec     eax
        mov     DWORD [stackSize], eax
        mov     eax, DWORD [stackSize]
        shl     eax, 2
        add     eax, stack ;eax<-stack+4*stackSize
        mov     esi, DWORD [eax]
        mov     DWORD [eax], 0
        mov     eax, esi
.return:
        leave
        ret
; stack operations - END: //----------------------------------->
; print: //----------------------------------->
print:
        push    ebp
        mov     ebp, esp
        push    DWORD [ebp+8]
        call    print_Recursive
        add     esp, 4
        push    newline
        call    printf
        add     esp, 4
        leave
        ret

print_Recursive:
        push    ebx
        sub     esp, 8
        mov     ebx, DWORD [esp+16]
        mov     eax, DWORD [ebx+4]
        cmp     eax, 0
        je      .print_last
        cmp     BYTE [ebx], 15
        ja      .recursive_call
        sub     esp, 12
        push    eax
        call    print_Recursive
        add     esp, 8
        movzx   eax, BYTE [ebx]
        push    eax
        push    leading_zero_hex_format
        call    printf
        add     esp, 16
.return:
        add     esp, 8
        pop     ebx
        ret
.print_last:
        sub     esp, 8
        movzx   eax, BYTE [ebx]
        push    eax
        push    hex_format
        call    printf
        add     esp, 16
        jmp     .return
.recursive_call:
        sub     esp, 12
        push    eax
        call    print_Recursive
        add     esp, 8
        movzx   eax, BYTE [ebx]
        push    eax
        push    hex_format
        call    printf
        add     esp, 16
        jmp     .return
; print - END: //----------------------------------->
; utilities: //----------------------------------->
trim:
        push    ebp
        mov     ebp, esp
        sub     esp, 24
        mov     eax, DWORD [ebp+8]
        mov     DWORD [ebp-12], eax
        cmp     DWORD [ebp-12], 0
        jne     .not_null
        mov     eax, 0
        jmp     .return
.not_null:
        mov     eax, DWORD [ebp+8]
        mov     eax, DWORD [eax+4]
        sub     esp, 12
        push    eax
        call    trim
        add     esp, 16
        mov     edx, eax
        mov     eax, DWORD [ebp-12]
        mov     DWORD [eax+4], edx
        mov     eax, DWORD [ebp-12]
        mov     eax, DWORD [eax+4]
        test    eax, eax
        jne     .return_ans
        mov     eax, DWORD [ebp-12]
        movzx   eax, BYTE [eax]
        test    al, al
        jne     .return_ans
        sub     esp, 12
        push    DWORD [ebp-12]
        call    free_Number
        add     esp, 16
        mov     eax, 0
        jmp     .return
.return_ans:
        mov     eax, DWORD [ebp-12]
.return:
        leave
        ret


strncmp:
        push    ebx
        sub     esp, 8
        mov     edx, DWORD [esp+16]
        mov     eax, DWORD [esp+24]
        cmp     eax, 0
        je      .return
        movzx   ecx, BYTE [edx] ;mov zero extend
        cmp     cl, 0
        je      .not_equal
        mov     ebx, DWORD [esp+20]
        cmp     cl, BYTE [ebx]
        je      .call_recursively
.not_equal:
        movzx   eax, BYTE [edx]
        mov     ecx, DWORD [esp+20]
        movzx   edx, BYTE [ecx]
        sub     eax, edx
.return:
        add     esp, 8
        pop     ebx
        ret
.call_recursively:
        sub     esp, 4
        sub     eax, 1
        push    eax
        mov     eax, DWORD [esp+28]
        add     eax, 1
        push    eax
        add     edx, 1
        push    edx
        call    strncmp
        add     esp, 16
        jmp     .return

my_strlen:
	push ebp
	mov ebp, esp	
	pushad			

	sub esp, 16
	mov DWORD [ebp-4], 0
	jmp .next
.inc_n:
	add DWORD [ebp-4], 1
.next:
	mov edx, DWORD [ebp-4]
	mov eax, DWORD [ebp+8]
	add eax, edx
	movzx eax, BYTE [eax]
	cmp al, 0
	je .return
	mov edx, DWORD [ebp-4]
	mov eax, DWORD [ebp+8]
	add eax, edx
	movzx eax, BYTE [eax]
	cmp al, 10
	jne .inc_n
.return:
	add esp, 16
	
	mov eax, DWORD [ebp-4]		 
        popad
	mov esp, ebp	
	pop ebp
	ret

divide:
	push esi
	push ebx
	sub esp, 16
	mov esi, DWORD  [esp+28]
	push 8
	call malloc
	mov ebx, eax
	add esp, 16
	cmp esi, 0
	jne .if_not_null
	mov BYTE  [eax], 0
	mov BYTE  [eax+1], 0
	mov DWORD  [eax+4], 0
.return:
	mov eax, ebx
	add esp, 4
	pop ebx
	pop esi
	ret
.if_not_null:
	sub esp, 12
	push DWORD  [esi+4]
	call divide
	mov DWORD  [ebx+4], eax
	movzx eax, BYTE  [eax+1]
	sal eax, 8
	movzx edx, BYTE  [esi]
	add eax, edx
	mov edx, eax
	shr edx, 1
	mov BYTE  [ebx], dl
	and eax, 1
	mov BYTE  [ebx+1], al
	add esp, 16
	jmp .return



; utilities - END: //----------------------------------->
; free functions -------------------->
free_Number:
        push ebx
        sub esp, 8
        mov eax, DWORD [esp+16]
        cmp  eax, 0
        jne .func_body
.return:
        add esp, 8
        pop ebx
        ret
.func_body:
        mov ebx, DWORD [eax+4]
        sub esp, 12
        push eax
        call free
        mov DWORD [esp], ebx
        call free_Number
        add esp, 16
        jmp .return

free_Diver:
        push ebx
        sub esp, 8
        mov eax, DWORD [esp+16]
        cmp  eax, 0
        jne .func_body
.return:
        add esp, 8
        pop ebx
        ret
.func_body:
        mov ebx, DWORD [eax+4]
        sub esp, 12
        push eax
        call free
        mov DWORD [esp], ebx
        call free_Diver
        add esp, 16
        jmp .return
  
; free functions - END -------------------->
;Main functions! --------------------->
plus:
        sub esp, 16
        push 0
        push DWORD [esp+28]
        push DWORD [esp+28]
        call pluss
        add esp, 28
        ret

hexstr_to_num_len:
        push ebp
        mov ebp, esp
        push ebx
        sub esp, 20
        mov eax, DWORD [ebp+12]
        lea edx, [eax-1]
        mov eax, DWORD [ebp+8]
        add eax, edx
        mov DWORD [ebp-12], eax
        cmp DWORD [ebp+12], 0
        jg .malloc
        mov eax, 0
        jmp .return
.malloc:
        sub esp, 12
        push 8
        call malloc
        add esp, 16
        mov DWORD [ebp-16], eax
        cmp DWORD [ebp+12], 1
        jne .fill_node
        mov eax, DWORD [ebp-12]
        movzx eax, BYTE [eax]
        movsx eax, al
        sub esp, 12
        push eax
        call hex_digit_to_num
        add esp, 16
        mov edx, eax
        mov eax, DWORD [ebp-16]
        mov BYTE [eax], dl
        mov eax, DWORD [ebp-16]
        mov DWORD [eax+4], 0
        mov eax, DWORD [ebp-16]
        jmp .return
.fill_node:
        mov eax, DWORD [ebp-12]
        movzx eax, BYTE [eax]
        movsx eax, al
        sub esp, 12
        push eax
        call hex_digit_to_num
        add esp, 16
        mov ebx, eax
        mov eax, DWORD [ebp-12]
        sub eax, 1
        movzx eax, BYTE [eax]
        movsx eax, al
        sub esp, 12
        push eax
        call hex_digit_to_num
        add esp, 16
        sal eax, 4
        lea edx, [ebx+eax]
        mov eax, DWORD [ebp-16]
        mov BYTE [eax], dl
        mov eax, DWORD [ebp+12]
        sub eax, 2
        sub esp, 8
        push eax
        push DWORD [ebp+8]
        call hexstr_to_num_len
        add esp, 16
        mov edx, eax
        mov eax, DWORD [ebp-16]
        mov DWORD [eax+4], edx
        mov eax, DWORD [ebp-16]
.return:
        mov ebx, DWORD [ebp-4]
        leave
        ret

shr:
        push    edi
        push    esi
        push    ebx
        sub     esp, 12
        push    DWORD [esp+32]
        call    convert_to_decimal
        mov     DWORD[my_flag], eax
        mov     ebx, eax
        add     esp, 4

        push    DWORD [esp+28]
        call    deepCopy
        mov     esi, eax
        add     esp, 16
        cmp     DWORD[my_flag], 0
        je      .return_x
        cmp     ebx, 0
        je      .reset_edi
.while:
        sub     esp, 12
        push    esi
        call    shr_single
        mov     edi, eax
        mov     DWORD [esp], esi
        call    free_Number
        mov     esi, edi
        add     esp, 16
        sub     ebx, 1
        jne     .while
.return:
        mov     eax, edi
        pop     ebx
        pop     esi
        pop     edi
        ret
.reset_edi:
        mov     edi, 0
        jmp     .return
.return_x:
        mov     edi, esi
        jmp     .return
        

num_bits:
        push ebp
        push edi
        push esi
        push ebx
        sub esp, 40
        mov edi, DWORD [esp+60]
        push one
        call hexstr_to_num
        mov ebp, eax
        mov DWORD [esp], zero
        call hexstr_to_num
        mov esi, eax
        add esp, 16
        cmp  edi, 0
        jne .while_data_test
.free_one:
        sub esp, 12
        push ebp
        call free_Number
        mov eax, esi
        add esp, 44
        pop ebx
        pop esi
        pop edi
        pop ebp
        ret
.divide_by2_and_loop:
        mov eax, ebx
        shr al, 1
        mov ebx, eax
        cmp  al, 0
        je .while_ptr_test
.while_body:
        test bl, 1
        je .divide_by2_and_loop
        sub esp, 8
        push ebp
        push esi
        call plus
        mov DWORD [esp+28], eax
        mov DWORD [esp], esi
        call free_Number
        add esp, 16
        mov esi, DWORD [esp+12]
        jmp .divide_by2_and_loop
.while_ptr_test:
        mov edi, DWORD [edi+4]
        cmp  edi, 0
        je .free_one
.while_data_test:
        movzx ebx, BYTE [edi]
        cmp  bl, 0
        jne .while_body
        jmp .while_ptr_test

duplicate:
        push ebp
        mov ebp, esp
        sub esp, 24
        call pop
        mov DWORD [ebp-12], eax
        cmp DWORD [ebp-12], 0
        je .return
        sub esp, 12
        push DWORD [ebp-12]
        call deepCopy
        add esp, 16
        mov DWORD [ebp-16], eax
        sub esp, 12
        push DWORD [ebp-12]
        call push
        add esp, 16
        sub esp, 12
        push DWORD [ebp-16]
        call push
        add esp, 16
.return:
        leave
        ret

shl:
        push    ebp
        mov     ebp, esp
        sub     esp, 24
        sub     esp, 12
        push    DWORD [ebp+12]
        call    convert_to_decimal
        add     esp, 16
        mov     DWORD [ebp-12], eax
        sub     esp, 12
        push    DWORD [ebp+8]
        call    deepCopy
        add     esp, 16
        mov     DWORD [ebp-16], eax
        mov     DWORD [ebp-20], eax
        jmp     .while_test
.while_body:
        sub     esp, 8
        push    0
        push    DWORD [ebp-20]
        call    shl_single
        add     esp, 16
        mov     DWORD [ebp-16], eax
        sub     esp, 12
        push    DWORD [ebp-20]
        call    free_Number
        add     esp, 16
        mov     eax, DWORD [ebp-16]
        mov     DWORD [ebp-20], eax
        sub     DWORD [ebp-12], 1
.while_test:
        cmp     DWORD [ebp-12], 0
        jne     .while_body
        mov     eax, DWORD [ebp-16]
        leave
        ret
;Main functions! - END --------------------->
bigger_than_200:
        push    ebp
        mov     ebp, esp
        mov     eax, DWORD [ebp+8]
        mov     eax, DWORD [eax+4]
        cmp     eax, 0
        jne     .return_false
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     eax, 200
        ja     .return_false
.return_true:
        mov     eax, 1
        jmp     .return
.return_false:
        mov     eax, 0
.return:
        pop     ebp
        ret
; execute main function: ----------------------------------->

execute:
        push    ebp
        mov     ebp, esp

        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, 'q'
        je      .return

        sub     esp, 24
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, 'p'
        jne     .if_d
        INC_COUNT
        call    pop
        mov     DWORD [ebp-12], eax
        cmp     DWORD [ebp-12], 0
        je      .return
        mov     eax, DWORD [ebp-12]
        mov     eax, DWORD [eax+4]
        ; sub     esp, 12
        ; push    eax
        ; call    trim
        ; add     esp, 16
        mov     edx, eax
        mov     eax, DWORD [ebp-12]
        mov     DWORD [eax+4], edx
        sub     esp, 12
        push    DWORD [ebp-12]
        call    print
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    free_Number
        add     esp, 16
        jmp     .return
.if_d:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, 'd'
        jne     .if_n
        INC_COUNT
        call    duplicate
        jmp     .return
.if_n:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, 'n'
        jne     .if_v
        INC_COUNT
        call    pop
        mov     DWORD [ebp-12], eax
        cmp     DWORD [ebp-12], 0
        je      .return
        sub     esp, 12
        push    DWORD [ebp-12]
        call    num_bits
        add     esp, 16
        sub     esp, 12
        push    eax
        call    push
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    free_Number
        add     esp, 16
        jmp     .return
.if_v:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, 'v'
        jne     .if_shl
        INC_COUNT
        call    pop
        mov     DWORD [ebp-12], eax
        cmp     DWORD [ebp-12], 0
        je      .return
        call    pop
        mov     DWORD [ebp-16], eax
        cmp     DWORD [ebp-16], 0
        jne     .shiftR
        sub     esp, 12
        push    DWORD [ebp-12]
        call    push
        add     esp, 16
        jmp     .return
.shiftR:
        sub     esp, 12
        push    DWORD [ebp-16]
        call    bigger_than_200
        add     esp, 16
        cmp     eax, 0
        jne      .shiftR_end
        sub     esp, 12
        push    wrong_y_value
        call    printf
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-16]
        call    push
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    push
        add     esp, 16
        jmp     .return
.shiftR_end:
        sub     esp, 8
        push    DWORD [ebp-16]
        push    DWORD [ebp-12]
        call    shr
        add     esp, 16
        sub     esp, 12
        push    eax
        call    push
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    free_Number
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-16]
        call    free_Number
        add     esp, 16
        jmp     .return
.if_shl:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, '^'
        jne     .if_plus
        INC_COUNT
        call    pop
        mov     DWORD [ebp-12], eax
        cmp     DWORD [ebp-12], 0
        je      .return
        call    pop
        mov     DWORD [ebp-16], eax
        cmp     DWORD [ebp-16], 0
        jne     .shiftL
        sub     esp, 12
        push    DWORD [ebp-12]
        call    push
        add     esp, 16
        jmp     .return
.shiftL:
        sub     esp, 12
        push    DWORD [ebp-16]
        call    bigger_than_200
        add     esp, 16
        cmp     eax, 0
        jne     .shiftL_end
        sub     esp, 12
        push    wrong_y_value
        call    printf
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-16]
        call    push
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    push
        add     esp, 16
        jmp     .return
.shiftL_end:
        sub     esp, 8
        push    DWORD [ebp-16]
        push    DWORD [ebp-12]
        call    shl
        add     esp, 16
        sub     esp, 12
        push    eax
        call    push
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    free_Number
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-16]
        call    free_Number
        add     esp, 16
        jmp     .return
.if_plus:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        cmp     al, '+'
        jne     .push_new_number
        INC_COUNT
        call    pop
        mov     DWORD [ebp-12], eax
        cmp     DWORD [ebp-12], 0
        je      .return
        call    pop
        mov     DWORD [ebp-16], eax
        cmp     DWORD [ebp-16], 0
        jne     .plus_end
        sub     esp, 12
        push    DWORD [ebp-12]
        call    push
        add     esp, 16
        jmp     .return
.plus_end:
        sub     esp, 8
        push    DWORD [ebp-16]
        push    DWORD [ebp-12]
        call    plus
        add     esp, 16
        sub     esp, 12
        push    eax
        call    push
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-12]
        call    free_Number
        add     esp, 16
        sub     esp, 12
        push    DWORD [ebp-16]
        call    free_Number
        add     esp, 16
        jmp     .return
.push_new_number:
        push    DWORD [ebp+8]
        call    hexstr_to_num
        add     esp, 4
        push    eax
        call    push
        add     esp, 4
.return:
        mov     eax, 0
        leave
        ret
; execute main function - END ----------------------------------->
; main function helpers ----------------------------------->
shl_single:
        push    ebp
        mov     ebp, esp
        sub     esp, 40
        mov     eax, DWORD [ebp+12]
        mov     BYTE [ebp-28], al
        cmp     DWORD [ebp+8], 0
        jne     .calc_data_and_carry
        cmp     BYTE [ebp-28], 0
        jne     .last_iteration
        add     esp, 40
        mov     eax, 0
        jmp     .return
.last_iteration:
        push    8
        call    malloc
        add     esp, 4
        mov     DWORD [ebp-20], eax
        mov     eax, DWORD [ebp-20]
        movzx   edx, BYTE [ebp-28]
        mov     BYTE [eax], dl
        mov     eax, DWORD [ebp-20]
        mov     DWORD [eax+4], 0
        mov     eax, DWORD [ebp-20]
        jmp     .return
.calc_data_and_carry:
        mov     eax, DWORD [ebp+8]
        movzx   eax, BYTE [eax]
        movzx   eax, al
        lea     edx, [eax+eax]
        movzx   eax, BYTE [ebp-28]
        add     eax, edx
        mov     DWORD [ebp-12], eax
        mov     BYTE [ebp-13], 0
        cmp     DWORD [ebp-12], 255
        jbe     .create_new_node
        mov     BYTE [ebp-13], 1
        sub     DWORD [ebp-12], 256
.create_new_node:
        push    8
        call    malloc
        add     esp, 4
        mov     DWORD [ebp-20], eax
        mov     eax, DWORD [ebp-12]
        mov     edx, eax
        mov     eax, DWORD [ebp-20]
        mov     BYTE [eax], dl
        movzx   edx, BYTE [ebp-13]
        mov     eax, DWORD [ebp+8]
        mov     eax, DWORD [eax+4]
        push    edx
        push    eax
        call    shl_single
        add     esp, 8
        mov     edx, eax
        mov     eax, DWORD [ebp-20]
        mov     DWORD [eax+4], edx
        mov     eax, DWORD [ebp-20]
.return:
        leave
        ret

pluss:
	push ebp
	push edi
	push esi
	push ebx
	sub esp, 28
	mov esi, DWORD [esp+48]
	mov edi, DWORD [esp+52]
	mov ebx, DWORD [esp+56]
	cmp esi, 0
	sete dl
	cmp edi, 0
	sete al	;set if equal
	and edx, eax
	mov BYTE [esp+14], dl
	cmp bl, 0
	jne .if_null
	cmp dl, 0
	jne .is_equal
.if_null:
	mov BYTE [esp+13], 0
	cmp esi, 0
	je .next
	movzx eax, BYTE [esi]
	mov BYTE [esp+13], al
.next:
	cmp edi, 0
	je .malloc
	movzx eax, BYTE [edi]
	mov BYTE [esp+15], al
	sub esp, 12
	push 8
	call malloc
	mov ebp, eax
	movzx eax, BYTE [esp+29]
	movzx edx, BYTE [esp+31]
	add eax, edx
	movzx ebx, bl
	add eax, ebx
	mov ebx, eax
	add esp, 16
	cmp eax, 255
	ja .add_carry
	mov BYTE [ebp+0], al
	cmp esi, 0
	je .reset_eax
	mov eax, 0
.both_not_null:
	sub esp, 4
	movzx eax, al
	push eax
	push DWORD [edi+4]
	push DWORD [esi+4]
	call pluss
	mov DWORD [ebp+4], eax
	add esp, 16
	jmp .fix_stack
.malloc:
	sub esp, 12
	push 8
	call malloc
	mov ebp, eax
	movzx eax, BYTE [esp+29]
	movzx ebx, bl
	add ebx, eax
	add esp, 16
	mov eax, 0
	cmp ebx, 255
	jbe .both_null
.add_carry:
	sub ebx, 256
	mov eax, 1
.both_null:
	mov BYTE [ebp+0], bl
	cmp BYTE [esp+14], 0
	je .one_num_is_null
	mov DWORD [ebp+4], 0
.fix_stack:
	mov eax, ebp
	add esp, 28
	pop ebx
	pop esi
	pop edi
	pop ebp
	ret
.one_num_is_null:
	cmp esi, 0
	je .second_num_is_null
	cmp edi, 0
	jne .both_not_null
	sub esp, 4
	movzx eax, al
	push eax
	push edi
	push DWORD [esi+4]
	call pluss
	mov DWORD [ebp+4], eax
	add esp, 16
	jmp .fix_stack
.reset_eax:
	mov eax, 0
.second_num_is_null:
	sub esp, 4
	movzx eax, al
	push eax
	push DWORD [edi+4]
	push esi
	call pluss
	mov DWORD [ebp+4], eax
	add esp, 16
	jmp .fix_stack
.is_equal:
	mov ebp, 0
	jmp .fix_stack

deepCopy:
        push esi
        push ebx
        sub esp, 16
        mov esi, DWORD [esp+28]
        push 8
        call malloc
        mov ebx, eax
        movzx eax, BYTE [esi]
        mov BYTE [ebx], al
        mov eax, DWORD [esi+4]
        add esp, 16
        cmp  eax, 0
        jne .recursive_call
        mov DWORD [ebx+4], 0
        .return:
        mov eax, ebx
        add esp, 4
        pop ebx
        pop esi
        ret
        .recursive_call:
        sub esp, 12
        push eax
        call deepCopy
        mov DWORD [ebx+4], eax
        add esp, 16
        jmp .return

div_to_num:
        push ebp
        mov ebp, esp
        sub esp, 24
        mov eax, DWORD [ebp+8]
        mov eax, DWORD [eax+4]
        cmp  eax, 0
        jne .func_body
        mov eax, 0
        jmp .return
        .func_body:
        sub esp, 12
        push 8
        call malloc
        add esp, 16
        mov DWORD [ebp-12], eax
        mov eax, DWORD [ebp+8]
        movzx edx, BYTE [eax]
        mov eax, DWORD [ebp-12]
        mov BYTE [eax], dl
        mov eax, DWORD [ebp+8]
        mov eax, DWORD [eax+4]
        sub esp, 12
        push eax
        call div_to_num
        add esp, 16
        mov edx, eax
        mov eax, DWORD [ebp-12]
        mov DWORD [eax+4], edx
        mov eax, DWORD [ebp-12]
.return:
        leave
        ret

shr_single:
        push    esi
        push    ebx
        sub     esp, 16
        push    DWORD [esp+28]
        call    divide
        mov     ebx, eax
        mov     DWORD [esp], eax
        call    div_to_num
        mov     esi, eax
        mov     DWORD [esp], ebx
        call    free_Diver
        mov     eax, esi
        add     esp, 20
        pop     ebx
        pop     esi
        ret

convert_to_decimal:
        push ebp
        mov ebp, esp
        sub esp, 16
        mov DWORD [ebp-4], 0
        mov DWORD [ebp-8], 1
        jmp .while_test
.while_body:
        mov eax, DWORD [ebp+8]
        movzx eax, BYTE [eax]
        movzx eax, al
        imul eax, DWORD [ebp-8]
        add DWORD [ebp-4], eax
        sal DWORD [ebp-8], 8
        mov eax, DWORD [ebp+8]
        mov eax, DWORD [eax+4]
        mov DWORD [ebp+8], eax
.while_test:
        cmp DWORD [ebp+8], 0
        jne .while_body
        mov eax, DWORD [ebp-4]
        leave
        ret
  

hex_digit_to_num:
        push    ebp
        mov     ebp, esp
        sub     esp, 4
        mov     eax, DWORD [ebp+8]
        mov     BYTE [ebp-4], al
        cmp     BYTE [ebp-4], '9'
        jg      .letter
        cmp     BYTE [ebp-4], '0'
        jle     .letter
        movzx   eax, BYTE [ebp-4]
        sub     eax, '0'
        jmp     .return
.letter:
        cmp     BYTE [ebp-4], 70
        jg      .return_0
        cmp     BYTE [ebp-4], 64
        jle     .return_0
        movzx   eax, BYTE [ebp-4]
        sub     eax, 55
        jmp     .return
.return_0:
        mov     eax, 0
.return:
        leave
        ret

hexstr_to_num:
        push ebp
        mov ebp, esp
        sub esp, 24
        sub esp, 12
        push DWORD [ebp+8]
        call my_strlen
        add esp, 16
        mov DWORD [ebp-12], eax
        sub esp, 8
        push DWORD [ebp-12]
        push DWORD [ebp+8]
        call hexstr_to_num_len
        add esp, 16
        leave
        ret

; main function helpers - END ----------------------------------->