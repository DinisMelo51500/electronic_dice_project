.equ    STACK_SIZE, 64
.equ    nCs_ExT1, 0xff40 
.equ    DICE_SIDES_MASK, 0x0c
.equ    INPORT_ADDRESS, 0xFF80
.equ    OUTPORT_ADDRESS, 0xFFC0
.equ	RAND_MAX_L, 0xFFFF		; Corresponde ao maior valor inteiro
.equ	RAND_MAX_H, 0xFFFF		; sem sinal codificavel com 32 bits

.text
b		program
b       isr

program:        
	ldr	sp, stack_top_addr
	b	main
    b   .  

    stack_top_addr:
	    .word	stack_top


    main: 		;permite interrupeçoes e ativa o FED
        push lr
        mov r0, #0x78
        mov r1, #0x01
        bl  srand 
        mrs r0, cpsr 
        mov r1, #(1 << 4)           
        orr r0, r0, r1
        msr cpsr, r0
        mov r1, #nCs_ExT1 & 0xFF
    	movt r1, #(nCs_ExT1 >> 8) & 0xFF
        strb r1, [r1,#0]
    loop:
        bl      roll_reader       ; aguarda mudança no switch
    	bl      display_7seg_animation
    	bl      obtain_result
    	bl      final_result
		mov 	r0, #100
    	bl      sleep             ; 10s
    	b       loop



isr:
    push r0
    push r1
    push r2

    mov  r1, #nCs_ExT1 & 0xFF
    movt r1, #(nCs_ExT1 >> 8) & 0xFF
    strb r1, [r1, #0]
    ldr r0, sum_addr
    ldrb r2, [r0]
    add r2, r2, #1
    strb r2, [r0]

    pop r2
    pop r1
    pop r0
    movs pc, lr


sleep:
        ldr r1, sum_addr
        ldrb r2, [r1,#0]
    sleep_loop:
        ldrb r3, [r1, #0]
        sub r3, r3, r2
        cmp r3 , r0
        blo sleep_loop
        mov pc, lr 


display_7seg_animation:       ; r4 = 9, r5 = i, r3 = display_7seg_codes
    push lr
    push r4
    push r5
    mov r4, #9
    mov r5, #1      ; i = 1
for:
   cmp r5, r4       
   bhs for_end      ; if i > 8 for_end
   ldr  r3, display_7seg_codes_addr
   ldrb r0, [r3,r5]

   bl outport_write
   mov r0, #10  ; 1s
   bl sleep      

   add r5, r5, #1   ; i++
   b for   
for_end:
    pop r4
    pop r5
    pop lr
    mov pc, lr


final_result:
        push    lr

        ldr     r3, display_7seg_codes_addr
        ldrb    r3,   [r3,r0]
        mov     r0, r3

        bl      outport_write

        pop     lr
        mov     pc ,lr

display_7seg_codes_addr:
	.word display_7seg_codes

sum_addr:
     .word sum


umull32:			;(umull, rand e srand do stor)
        ; Prologo
        push	r8
        push	r7
        push	r6
        push	r5
        push	r4

        ; Iniciar p fazendo a extensao de sinal aos 16 MSb
        asr	r4, r3, #15
        mov	r5, r4
        ; Inicia p_1
        mov	r6, #0
        ; Implementacao do ciclo for
        mov	r7, #0	; Inicia i
    umull32_loop:
        mov	r8, #32	; Avaliar o limite maximo de i
        cmp	r7, r8
        bhs	umull32_ret
        ; Implementacao do if
        mov	r8, #1
        and	r8, r2, r8
        bzc	umull32_else
        mov	r8, #1
        cmp	r6, r8
        bne	umull32_loop_end
        add	r4, r4, r0	; Atualizar o valor de p
        adc	r5, r5, r1
        b	umull32_loop_end
    umull32_else:
        ; Implementacao otimizada do else
        mov	r8, #0
        cmp	r6, r8
        bne	umull32_loop_end
        sub	r4, r4, r0	; Atualizar o valor de p
        sbc	r5, r5, r1
    umull32_loop_end:
        mov	r8, #1	; Definir o novo valor de p_1
        and	r6, r2, r8
        asr	r5, r5, #1
        rrx	r4, r4
        rrx	r3, r3
        rrx	r2, r2
        add	r7, r7, #1	; Incrementar i
        b	umull32_loop

    umull32_ret:
        ; Epilogo
        mov	r0, r2	; Preparar o valor a devolver
        mov	r1, r3

        pop	r4
        pop	r5
        pop	r6
        pop	r7
        pop	r8
        mov	pc, lr

srand:
        ldr	r2, seed_addr_srand
        str	r0, [r2, #0]
        str	r1, [r2, #2]
        mov	pc, lr

seed_addr_srand:
        .word	seed

rand:
        ; Prologo
        push	lr
        ; Obter o valor atual de seed
        ldr	r2, seed_addr_rand
        ldr	r0, [r2, #0]
        ldr	r1, [r2, #2]
        ; Calcular a multiplicacao a 32 bits
        mov	r2, #( 0x43FD >> 0 ) & 0xFF	; Carregar o valor 214013
        movt	r2, #( 0x43FD >> 8 ) & 0xFF
        mov	r3, #( 0x0003 >> 0 ) & 0xFF
        movt	r3, #( 0x0003 >> 8 ) & 0xFF
        bl	umull32
        ; Calcular a adicao a 32 bits
        mov	r2, #( 0x9EC3 >> 0 ) & 0xFF	; Carregar o valor 2531011
        movt	r2, #( 0x9EC3 >> 8 ) & 0xFF
        mov	r3, #( 0x0026 >> 0 ) & 0xFF
        movt	r3, #( 0x0026 >> 8 ) & 0xFF
        add	r0, r0, r2
        adc	r1, r1, r3

        ; Nao e necessario implementar a divisao modulo, pois a operacao realizada
        ; com valores de 32 bits nunca ultrapassa o valor RAND_MAX (0xFFFFFFFF).
        ; No entanto, a operacao % RAND_MAX deve devolver 0 quando o novo valor de
        ; seed e exatamente igual a RAND_MAX. Assim, e suficiente verificar este
        ; caso e forcar seed a zero.
        mov	r2, #( RAND_MAX_L >> 0 ) & 0xFF
        movt	r2, #( RAND_MAX_L >> 8 ) & 0xFF
        cmp r0, r2
        bne rand_save_seed
        mov	r3, #( RAND_MAX_H >> 0 ) & 0xFF
        movt	r3, #( RAND_MAX_H >> 8 ) & 0xFF
        cmp r1, r3
        bne rand_save_seed
        mov r0, #0  	; Atribuir a seed o valor 0
        mov r1, #0

    rand_save_seed:
        ; Atualizar o valor de seed
        ldr	r2, seed_addr_rand
        str	r0, [r2, #0]
        str	r1, [r2, #2]
        ; Epilogo
        mov	r0, r1	; Preparar o valor a devolver (16 MSb do valor)
        pop	pc

seed_addr_rand:
        .word	seed
; Rotina:    rand
; Descricao: Implementa um gerador congruencial linear (LCG) para gerar numeros
;            pseudo-aleatorios entre zero e RAND_MAX.
;            Interface exemplo: uint16_t rand( void );
; Entradas:  -
; Saidas:    R0 - O valor pseudo-aleatorio gerado
; Efeitos:   Altera o valor da variavel global seed
;            R0 - guarda valores temporariamente
;            R1 - guarda valores temporariamente
;            R2 - guarda valores temporariamente
;            R3 - guarda valores temporariamente


    


obtain_result:
        push lr
        push r7

        bl  dice_sides
        mov r7, r0
        bl  rand
        mov r1, r7
        bl division
        add r0, r0, #1

        pop r7
        pop lr
        mov pc, lr


dice_sides:
    push lr
    bl inport_read          ;valor da entrada em r0
    mov r2, #DICE_SIDES_MASK  
	and r0,r0, r2 
	lsr r0,r0,#2                ;   shift right 2 bits de (DICE_SIDES_MASK && inport_value)
	ldr r1, dice_sides_comb_addr
	ldrb r0,[r1,r0]
    pop lr
    mov pc, lr

dice_sides_comb_addr:
	.word dice_sides_comb


roll_reader:
        push lr
        push r4
        push r5


    up_wait:
        bl inport_read
        mov r5, #1
        and r4, r0, r5
        mov r5, #0       
        cmp r4, r5
        beq up_wait; deteta a mudança do sw

    down_wait:
        bl inport_read
        mov r5, #1
        and r4, r0, r5
        cmp r4, r5
        beq down_wait; deteta a mudança do sw
        mov r0, #1

        pop r5
        pop r4
        pop lr
        mov pc, lr

division: 			; (no site fornecido pelo stor)
        push lr
        push r4
        push r3

        mov	r3, #0		; rest = 0;
        mov	r4, #0		; quocient = 0;
        mov	r2, #16		; uint16_t i = 16;
    
	div_while:			; uint16 dividend_msb = dividend >> 15;
        lsl	r0, r0, #1	; dividend <<= 1;
        adc	r3, r3, r3	; rest <<= 1; rest += dividend_bit;
        lsl	r4, r4, #1	; quotient <<= 1;
        cmp	r3, r1		; if (rest >= divisor) {
        blo	div_if_end
        sub	r3, r3, r1	; rest -= divisor;
        add	r4, r4, #1	; quotient += 1;
    
	div_if_end:
        sub	r2, r2, #1	; } while (--i > 0);
        bne	div_while
        mov	r0, r3		; return rest;

        pop r3
        pop	r4
        pop lr
        mov	pc, lr

inport_read:
	mov	r1, #INPORT_ADDRESS & 0xFF
	movt	r1, #(INPORT_ADDRESS >> 8) & 0xFF
	ldrb	r0, [r1, #0]
	mov	pc, lr

outport_write:
	mov	r1, #OUTPORT_ADDRESS & 0xFF
	movt	r1, #(OUTPORT_ADDRESS >> 8) & 0xFF
	strb	r0, [r1, #0]
	mov	pc, lr

.data

seed:
	.word 1 
	.word 0

dice_sides_comb:
    .byte 0x04, 0x06, 0x08, 0x0C

display_7seg_codes:
    .byte 0, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0 ;0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0

sum:   
    .byte 0 

	.stack
    .space  STACK_SIZE
stack_top:

