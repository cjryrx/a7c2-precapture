.syntax unified
.thumb
.cpu cortex-a9
.text
.equ STATE,0x01b86fe0
.global pair_mark
.type pair_mark,%function
.thumb_func
pair_mark:
 push {r0,r1,r2,r3,r4,r5,r6,lr}
 cmp r1,#13
 bhs mark_done
 movw r0,#0x33a4
 movt r0,#0x1a5
 ldrb r0,[r0,#0xf1]
 and r0,r0,#0x71
 cmp r0,#0x11
 bne mark_done
 movw r0,#0x6fe0
 movt r0,#0x1b8
 ldr r2,[r0]
 cmp r2,r4
 beq mark_owned
 ldr r2,[r0,#4]
 cmp r2,#0
 bne mark_done
 str r4,[r0]
mark_owned:
 movs r2,#1
 lsl r2,r2,r1
 ldr r3,[r0,#4]
 orrs r3,r2
 str r3,[r0,#4]
mark_done:
 pop {r0,r1,r2,r3,r4,r5,r6,lr}
 b.w native_emit
.size pair_mark,.-pair_mark
.global pair_stop_bypass
.type pair_stop_bypass,%function
.thumb_func
pair_stop_bypass:
 push {r0,r1,r2,r3,r4,r5,r6,lr}
 mov r4,r10
 b consume
.size pair_stop_bypass,.-pair_stop_bypass
.global pair_stop_normal
.type pair_stop_normal,%function
.thumb_func
pair_stop_normal:
 push {r0,r1,r2,r3,r4,r5,r6,lr}
 sub.w r4,r5,#0x278
consume:
 cmp r1,#13
 bhs consume_done
 movw r0,#0x6fe0
 movt r0,#0x1b8
 ldr r2,[r0]
 cmp r2,r4
 bne consume_done
 movs r2,#1
 lsl r2,r2,r1
 ldr r3,[r0,#4]
 bic r3,r3,r2
 str r3,[r0,#4]
consume_done:
 pop {r0,r1,r2,r3,r4,r5,r6,lr}
 b.w native_emit
.size pair_stop_normal,.-pair_stop_normal
.global pair_fallback
.type pair_fallback,%function
.thumb_func
pair_fallback:
 cmp r6,#0
 bne fallback_suppressed
 push {r0,r1,r2,r3,r12,lr}
 cmp r5,#13
 bhs fallback_original
 movw r0,#0x6fe0
 movt r0,#0x1b8
 ldr r1,[r0]
 cmp r1,r10
 bne fallback_original
 movs r1,#1
 lsl r1,r1,r5
 ldr r2,[r0,#4]
 tst r2,r1
 beq fallback_original
 ldr.w r0,[r10,#0x288]
 cmp r0,#0
 bne fallback_original
 add.w r0,r4,r5,lsl #4
 ldrb r0,[r0,#0x14]
 cmp r0,#0
 bne fallback_original
 pop {r0,r1,r2,r3,r12,lr}
 b.w native_bypass_stop
fallback_original:
 pop {r0,r1,r2,r3,r12,lr}
 b.w native_normal_stop
fallback_suppressed:
 mov.w r8,#0
 b.w native_stop_finish
.size pair_fallback,.-pair_fallback
