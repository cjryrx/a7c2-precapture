
.syntax unified
.thumb
.cpu cortex-a9
.text
.macro ADDR reg, value
 movw \reg, #:lower16:\value
 movt \reg, #:upper16:\value
.endm
.global cp_fastoff
.type cp_fastoff,%function
.thumb_func
cp_fastoff:
 /* Only the fixed-version external dispatcher may use this acknowledgement.
    The embedded 4063 origin and all other origins tail-call the old guard. */
 ADDR r12,0x0035d07d
 cmp lr,r12
 bne old_shooting
 ldrb r1,[r0]
 cmp r1,#5
 bne old_shooting
 ldrh r1,[r0,#2]
 movw r2,#0x4173
 cmp r1,r2
 bne old_shooting
 ldr r1,[r0,#8]
 cmp r1,#0
 bne old_shooting
 ADDR r1,0x01b86000
 ldr r2,[r1]
 ADDR r3,0x43504231
 cmp r2,r3
 bne old_shooting
 ldr r2,[r1,#4]
 cmp r2,#1
 bne old_shooting
 ldr r2,[r1,#8]
 cmp r2,#0
 bne old_shooting
 ldr r2,[r1,#0x30]
 cmp r2,#0
 bne old_shooting
 dmb ish
 ADDR r1,0x01a533a4
 ldrb r2,[r1,#0xf0]
 tst r2,#0x10
 bne old_shooting
 ldrb r2,[r1,#0xf1]
 tst r2,#1
 bne old_shooting
 ADDR r1,0x01a45c70
 ldr r2,[r1,#0x1c]
 cmp r2,#0
 bne old_shooting
 ldr r2,[r1,#0x0c]
 cmp r2,#0
 bne old_shooting
 ldr r2,[r1,#0x3c]
 cmp r2,#0
 bne old_shooting
 ADDR r1,0x01b86fe0
 ldr r2,[r1,#4]
 cmp r2,#0
 bne old_shooting
 /* Global CAPCON root 01A52B38 +108 is the same owner used by native leaf. */
 ADDR r1,0x01a52c40
 ldrb r2,[r1,#0x2d]
 cmp r2,#0
 bne old_shooting
 /* No gate/controller/active setting is written. This only acknowledges an
    already disabled gate; it is not an ordinary-capture completion barrier. */
 push {r4,lr}
 movw r1,#0xf000
 ADDR r12,0x00c2f5a5
 blx r12
 movs r0,#1
 pop {r4,pc}
old_shooting:
 ADDR r12,0x00c2f4e3
 bx r12
.size cp_fastoff,.-cp_fastoff
