.syntax unified
.thumb
.cpu cortex-a9
.text
.global cp_capture_done_token
.type cp_capture_done_token,%function
.thumb_func
cp_capture_done_token:
 /* Preserve native early VDF finish; defer only capture completion to stage6.
  * Only the reviewed continuous capture route is changed. */
 ldr r1,[r0,#0x20]
 cmp r1,#6
 beq late_check
 cmp r1,#4
 bne original
 ldr r1,[r0]
 movw r2,#0x66e8
 ldr r2,[r1,r2]
 cmp r2,#2
 bne original
 ldr r2,[r1,#0x210]
 cmp r2,#1
 bne original
 ldr r2,[r1,#0xbb4]
 cmp r2,#0
 bne original
 ldrb r2,[r1,#0x9ed]
 cmp r2,#0
 bne original
 movw r2,#0x5c10
 ldr r2,[r1,r2]
 cmp r2,#0
 bne original
 movw r2,#0x6078
 ldr r2,[r1,r2]
 cmp r2,#1
 bne original
 movw r2,#0x617c
 ldr r2,[r1,r2]
 tst r2,#0xbf
 bne original
 movw r2,#0x3417
 movt r2,#0x1a5
 ldrb r2,[r2]
 tst r2,#1
 bne original
 movw r2,#0xab08
 movt r2,#0x1a3
 ldr r2,[r2]
 subs r2,#3
 cmp r2,#1
 bhi original
 push {r4-r6,lr}
 mov r4,r0
 ldr r5,[r4]
 bl device_state_getter
 ldr r1,[r0]
 ldr r1,[r1,#0x1c]
 blx r1
 /* Publish only after this actual early VDF call. */
 mov r0,r4
 bl token_slot
 cmp r0,#0
 beq early_return
 mov r6,r0
 mov r4,r5
 ldr r5,[r5,#0x208]
 dmb ish
early_publish:
 ldrexd r0,r1,[r6]
 orrs r2,r0,r1
 beq early_store
 cmp r0,r4
 bne early_conflict
 cmp r1,r5
 bne early_conflict
 /* Already this frame; never overwrite a different owner's marker. */
 clrex
 b early_return
early_store:
 strexd r2,r4,r5,[r6]
 cmp r2,#0
 bne early_publish
 dmb ish
 b early_return
early_conflict:
 clrex
early_return:
 movs r0,#0
 pop {r4-r6,pc}
late_check:
 push {r4-r8,lr}
 mov r4,r0
 ldr r5,[r4]
 ldr r6,[r5,#0x208]
 bl token_slot
 cmp r0,#0
 beq late_original
 mov r7,r0
 dmb ish
late_claim:
 ldrexd r0,r1,[r7]
 cmp r0,r5
 bne late_mismatch
 cmp r1,r6
 bne late_mismatch
 movs r2,#0
 movs r3,#0
 strexd r8,r2,r3,[r7]
 cmp r8,#0
 bne late_claim
 dmb ish
 mov r0,r4
 pop {r4-r8,lr}
 /* Same frame already finished VDF early. Retain exact native job packing. */
 push {r4,r6,r7,lr}
 add r7,sp,#8
 sub sp,#0x18
 mov r4,r0
 b.w original_capture_job_resume
late_mismatch:
 clrex
late_original:
 mov r0,r4
 pop {r4-r8,lr}
 b original
original:
 push {r4,r6,r7,lr}
 add r7,sp,#8
 b.w original_capture_done_resume
.size cp_capture_done_token,.-cp_capture_done_token

/* r0=handle -> r0=owned slot or0. Native pool has exactly500 handles. */
.type token_slot,%function
.thumb_func
token_slot:
 movw r1,#0x1f4c
 movt r1,#0x1a3
 subs r0,r0,r1
 movw r1,#0x848c
 cmp r0,r1
 bhi token_invalid
 /* Exact bounded division by68 via inverse17 after /4; remainder checked. */
 lsrs r2,r0,#2
 movw r1,#0xf0f1
 movt r1,#0xf0f0
 mul r2,r2,r1
 movw r1,#500
 cmp r2,r1
 bhs token_invalid
 movs r1,#68
 mls r3,r2,r1,r0
 cmp r3,#0
 bne token_invalid
 movw r0,#0x9040
 movt r0,#0x120
 add r0,r0,r2,lsl #3
 bx lr
token_invalid:
 movs r0,#0
 bx lr
.size token_slot,.-token_slot

/* A0189C: native mutex36 is still held after pool removal. Clear on allocation. */
.global cp_pool_allocate_clear
.type cp_pool_allocate_clear,%function
.thumb_func
cp_pool_allocate_clear:
 push {r0-r3,r12,lr}
 movw r1,#0x1f40
 movt r1,#0x1a3
 cmp r6,r1
 bne allocation_original
 mov r0,r5
 bl token_slot
 cmp r0,#0
 beq allocation_original
 mov r12,r0
 movs r2,#0
 movs r3,#0
 dmb ish
allocation_clear:
 ldrexd r0,r1,[r12]
 strexd lr,r2,r3,[r12]
 cmp lr,#0
 bne allocation_clear
 dmb ish
allocation_original:
 pop {r0-r3,r12,lr}
 movw r12,#0x267c
 movt r12,#0x5f
 blx r12
 b.w original_allocate_resume
.size cp_pool_allocate_clear,.-cp_pool_allocate_clear
