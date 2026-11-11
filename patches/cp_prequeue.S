.syntax unified
.thumb
.cpu cortex-a9
.text
.global cp_prequeue_prepare, cp_prequeue_no_alias, cp_prequeue_finish
.macro check_type2 normal
 ldr r1,[r0]
 movw r2,#0x66e8
 ldr r1,[r1,r2]
 cmp r1,#2
 bne \normal
.endm
.type cp_prequeue_prepare,%function
.thumb_func
cp_prequeue_prepare:
 check_type2 1f
 push {r7,lr}
 ldr r0,[r0]
 bl native_prepare
 cmp r0,#1
 ite eq
 moveq r0,#0
 movne r0,#2
 pop {r7,pc}
1: b.w native_record_notify
.size cp_prequeue_prepare,.-cp_prequeue_prepare
.type cp_prequeue_no_alias,%function
.thumb_func
cp_prequeue_no_alias:
 check_type2 2f
 movs r0,#0
 bx lr
2: b.w native_lowres_alias
.size cp_prequeue_no_alias,.-cp_prequeue_no_alias
.type cp_prequeue_finish,%function
.thumb_func
cp_prequeue_finish:
 check_type2 3f
 b.w native_timeshift_queue
3: b.w native_record_class
.size cp_prequeue_finish,.-cp_prequeue_finish
