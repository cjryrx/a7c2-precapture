.syntax unified
.thumb
.cpu cortex-a9
.text
.global precache_exposure_filter
.type precache_exposure_filter,%function
.thumb_func
precache_exposure_filter:
 ldr r1,[r0,#0x20]
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
 movs r0,#0
 bx lr
original:
 push {r4,r5,r6,r7,lr}
 add r7,sp,#0xc
 b.w original_resume
.size precache_exposure_filter,.-precache_exposure_filter
