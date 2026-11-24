/* Independent CAP800 variant. Requested window remains in context; effective <=800ms. */
/* OFFLINE, NOT_READY prototype. No device use; context.ready defaults to 0.
 * Header reads assume the same complete fixed16/12byte AP packets as native handlers.
 * This prototype does not claim to validate arbitrary truncated transport buffers.
 */
.syntax unified
.thumb
.cpu cortex-a9
.text
.macro ADDR reg, value
 movw \reg, #:lower16:\value
 movt \reg, #:upper16:\value
.endm
.macro CALL value
 ADDR r12,\value
 blx r12
.endm
.equ CTX,0x01b86000
.equ MAGIC,0x43504231
.equ TAG,0x50434252
.equ WAKE,0x57414b45
.equ G,0x01a533a4
.equ CTRL,0x01a45c70
.equ ROUTE,0x00bec02b
.equ SEND,0x008daa15
.equ ENQUEUE,0x004b5fe5
.equ IDLE,0x00b22031
.equ DONE,0x00b22cff
/* Layout: magic0,ready4,pending8,generationC,seq10,route14,pid18,
 * stagedTrigger1C,stagedMs20,targetEnabled24,targetTrigger28,targetMs2C,
 * activeEnabled30,activeTrigger34,activeMs38,error3C.
 * pending:0 idle,1 queued,2 applied,3 stopping/deferred; context defaults disabled.
 * wake marker event+16 means a posted wake must never reserve another ring slot.
 */
.global cp_setting
.type cp_setting,%function
.thumb_func
cp_setting:
 /* PID4063 embedded call: preserve original no-op semantics, no transport prefix. */
 ADDR r12,0x008da94b
 cmp lr,r12
 bne 1f
 movs r0,#1
 bx lr
1:
 push {r4,lr}
 ADDR r4,CTX
 ldr r1,[r4,#8]
 cbnz r1,setting_bad
 ldrb r1,[r0]
 cmp r1,#5
 bne setting_bad
 ldrh r1,[r0,#2]
 movw r2,#0x4172
 cmp r1,r2
 bne setting_bad
 ldr r1,[r0,#8]
 cmp r1,#1
 blo setting_bad
 cmp r1,#3
 bhi setting_bad
 movs r2,#4
 lsls r2,r2,r1
 cmp r1,#1
 it eq
 moveq r2,#0x40
 ldr r3,[r0,#12]
 cmp r3,#5
 blo setting_bad
 movw r1,#1000
 cmp r3,r1
 bhi setting_bad
 str r2,[r4,#0x1c]
 str r3,[r4,#0x20]
 movs r0,#0
 str r0,[r4,#0x3c]
 b setting_end
setting_bad:
 movs r0,#1
 str r0,[r4,#0x3c]
setting_end:
 movs r0,#1
 pop {r4,pc}
.size cp_setting,.-cp_setting

.global cp_shooting
.type cp_shooting,%function
.thumb_func
cp_shooting:
 /* PID4063 embedded call: preserve original no-op semantics, no transport prefix. */
 ADDR r12,0x008da957
 cmp lr,r12
 bne 1f
 movs r0,#1
 bx lr
1:
 push {r4-r8,lr}
 sub sp,#32
 mov r4,r0
 ADDR r5,CTX
 ldrb r1,[r4]
 cmp r1,#5
 bne shooting_reject
 ldrh r1,[r4,#2]
 movw r2,#0x4173
 cmp r1,r2
 bne shooting_reject
 ldr r6,[r4,#8]
 cmp r6,#1
 bhi shooting_reject
 ldr r1,[r5,#4]
 cmp r1,#1
 bne shooting_reject
 ldr r1,[r5,#8]
 cbnz r1,shooting_reject
 mov r0,r4
 CALL ROUTE
 str r0,[r5,#0x14]
 ldr r0,[r4,#4]
 str r0,[r5,#0x10]
 ldrh r0,[r4,#2]
 str r0,[r5,#0x18]
 str r6,[r5,#0x24]
 ldrd r0,r1,[r5,#0x1c]
 strd r0,r1,[r5,#0x28]
 ldr r0,[r5,#0xc]
 adds r0,#1
 it eq
 moveq r0,#1
 str r0,[r5,#0xc]
 movs r1,#0
 str r1,[sp]
 movw r2,#0x8206
 str r2,[sp,#4]
 ldr r2,[r5,#0x10]
 str r2,[sp,#8]
 ADDR r2,TAG
 str r2,[sp,#12]
 str r0,[sp,#16]
 str r1,[sp,#20]
 str r1,[sp,#24]
 str r1,[sp,#28]
 movs r1,#1
 dmb ish
 str r1,[r5,#8]
 mov r0,r5
 ADDR r1,0x900302d9
 mov r2,sp
 movs r3,#32
 CALL ENQUEUE
 cbz r0,shooting_end
 movs r0,#0
 str r0,[r5,#8]
shooting_reject:
 mov r0,r4
 movw r1,#0xf001
 bl reply_request
shooting_end:
 movs r0,#1
 add sp,#32
 pop {r4-r8,pc}
.size cp_shooting,.-cp_shooting

/* reply_request(r0=request,r1=status). Packet byte1 is explicitly initialized. */
.type reply_request,%function
.thumb_func
reply_request:
 push {r4-r6,lr}
 sub sp,#16
 mov r4,r0
 mov r5,r1
 CALL ROUTE
 mov r2,r0
 movs r0,#1
 str r0,[sp]
 ldrh r0,[r4,#2]
 strh r0,[sp,#2]
 ldr r0,[r4,#4]
 str r0,[sp,#4]
 str r5,[sp,#8]
 mov r0,sp
 movs r1,#12
 CALL SEND
 add sp,#16
 pop {r4-r6,pc}

/* reply_context(r0=status), clear pending before send. */
.type reply_context,%function
.thumb_func
reply_context:
 push {r4,lr}
 sub sp,#16
 ADDR r4,CTX
 str r0,[sp,#8]
 movs r0,#1
 str r0,[sp]
 ldr r0,[r4,#0x18]
 strh r0,[sp,#2]
 ldr r0,[r4,#0x10]
 str r0,[sp,#4]
 ldr r2,[r4,#0x14]
 movs r0,#0
 str r0,[r4,#8]
 dmb ish
 mov r0,sp
 movs r1,#12
 CALL SEND
 add sp,#16
 pop {r4,pc}

/* match event r4 with current transaction. Returns boolean in r0;
 * preserves r4-r11. Requires caller to check exact pending phase.
 */
.type event_matches,%function
.thumb_func
event_matches:
 ADDR r0,CTX
 ldr r1,[r4,#4]
 ldr r2,[r0,#0x10]
 cmp r1,r2
 bne match_no
 ldr r1,[r4,#8]
 ADDR r2,TAG
 cmp r1,r2
 bne match_no
 ldr r1,[r4,#12]
 ldr r2,[r0,#12]
 cmp r1,r2
 ite eq
 moveq r0,#1
 movne r0,#0
 bx lr
match_no:
 movs r0,#0
 bx lr

/* Replaces original MOVW/MOVT r6,G at3AD1D0; continuation original3AD1D8. */
.global cp_event_entry
.type cp_event_entry,%function
.thumb_func
cp_event_entry:
 push {r0-r3,r12,lr}
 ldr r0,[r4,#8]
 ADDR r1,TAG
 cmp r0,r1
 bne entry_original
 ADDR r0,CTX
 ldr r1,[r0,#8]
 cmp r1,#1
 beq entry_check_tag
 cmp r1,#3
 bne entry_deferred_exit
entry_check_tag:
 bl event_matches
 cmp r0,#0
 beq entry_deferred_exit
 /* Two-stage prototype: defer busy transactions; preserve type gate until idle. */
 ldr r0,[r5,#12]
 CALL IDLE
 cbnz r0,entry_busy
 ADDR r0,CTRL
 ldr r1,[r0,#28]
 cbnz r1,entry_busy
 ldr r1,[r0,#12]
 cbnz r1,entry_busy
 ldrb r1,[r0,#60]
 cbnz r1,entry_busy
 ADDR r0,CTX
 ldr r1,[r0,#0x24]
 ldr r2,[r0,#0x28]
 ldr r3,[r0,#0x2c]
 str r1,[r0,#0x30]
 str r2,[r0,#0x34]
 str r3,[r0,#0x38]
 orrs r2,r1
 ADDR r3,G
 strb r2,[r3,#0xf1]
 ldrb r2,[r3,#0xf0]
 bic r2,r2,#0x10
 orr r2,r2,r1,lsl #4
 strb r2,[r3,#0xf0]
 movs r1,#2
 dmb ish
 str r1,[r0,#8]
entry_original:
 pop {r0-r3,r12,lr}
 ADDR r6,G
 b.w original_entry_resume
entry_busy:
 ADDR r0,CTX
 ldr r1,[r0,#8]
 cmp r1,#3
 bne entry_reserve
 ldr r1,[r4,#16]
 ADDR r2,WAKE
 cmp r1,r2
 beq entry_deferred_exit
entry_reserve:
 /* Native ring owns a28B copy. Reserve retry before modifying current gates. */
 ldr r0,[r5,#4]
 mov r1,r4
 CALL 0x00b1feaf
 cmp r0,#0
 bne entry_not_ready
 ADDR r0,CTX
 ldr r1,[r0,#8]
 cmp r1,#1
 bne entry_deferred_exit
 movs r1,#3
 str r1,[r0,#8]
 /* Preserve current trigger/window/type gate until terminal-frame idle. */
 ADDR r0,G
 ldrb r1,[r0,#0xf1]
 bic r1,r1,#1
 strb r1,[r0,#0xf1]
 b entry_original
entry_deferred_exit:
 pop {r0-r3,r12,lr}
 b.w original_event_exit
entry_not_ready:
 ADDR r0,CTX
 ldr r1,[r0,#8]
 cmp r1,#3
 ite eq
 moveq r1,#3
 movne r1,#2
 str r1,[r0,#0x3c]
 cmp r1,#3
 bne entry_error_reply
 movs r1,#0
 str r1,[r0,#0x30]
entry_error_reply:
 movw r0,#0xf001
 bl reply_context
 pop {r0-r3,r12,lr}
 b.w original_event_exit
.size cp_event_entry,.-cp_event_entry

.global cp_event_done
.type cp_event_done,%function
.thumb_func
cp_event_done:
 push {r4-r6,lr}
 CALL DONE
 mov r6,r0
 ADDR r0,CTX
 ldr r1,[r0,#8]
 cmp r1,#2
 bne done_return
 bl event_matches
 cbz r0,done_return
 movw r0,#0xf000
 bl reply_context
done_return:
 mov r0,r6
 pop {r4-r6,pc}
.size cp_event_done,.-cp_event_done

/* Replace first4B atA09D32. Existing nonidle diagnostic remains intact.
 * activeMs units are a proposed contract requiring separate time-unit proof.
 */
.global cp_time_config
.type cp_time_config,%function
.thumb_func
cp_time_config:
 ldr r1,[r0,#28]
 cbnz r1,time_nonidle
 ADDR r1,CTX
 ldr r2,[r1,#4]
 cmp r2,#1
 bne time_original
 ldr r2,[r1,#0x38]
 /* Explicit first controlled experiment cap. Keep activeMs as requested. */
 movw r1,#800
 cmp r2,r1
 it hi
 movhi r2,r1
 movs r1,#0
 str r1,[r0,#20]
 str r2,[r0,#24]
 bx lr
time_original:
 b.w original_time_idle
time_nonidle:
 b.w original_time_nonidle
.size cp_time_config,.-cp_time_config


/* Vtable+1C normally consumes8206 when predicate says busy.
 * Only our exact transaction is routed back through normal CAPCON dispatcher.
 */
.global cp_busy_reject
.type cp_busy_reject,%function
.thumb_func
cp_busy_reject:
 push {r4-r6,lr}
 mov r4,r1
 mov r5,r0
 ldr r0,[r4]
 movw r1,#0x8206
 cmp r0,r1
 bne reject_original
 ldr r0,[r4,#8]
 ADDR r1,TAG
 cmp r0,r1
 bne reject_original
 ADDR r0,CTX
 ldr r1,[r0,#8]
 cmp r1,#1
 beq reject_check_tag
 cmp r1,#3
 bne reject_stale
reject_check_tag:
 bl event_matches
 cbz r0,reject_stale
 mov r0,r5
 mov r1,r4
 CALL 0x004b4cf1
 pop {r4-r6,pc}
reject_stale:
 pop {r4-r6,pc}
reject_original:
 mov r0,r5
 mov r1,r4
 pop {r4-r6,lr}
 b.w original_busy_reject
.size cp_busy_reject,.-cp_busy_reject


/* Tail-hook372140 after state transition; drain first, then post one owned wake.
 * Does not modify G or the controller. Duplicate own tags are swallowed.
 */
.global cp_worker_done
.type cp_worker_done,%function
.thumb_func
cp_worker_done:
 push {r4-r6,lr}
 sub sp,#32
 mov r4,r0
 CALL 0x00b11efd
 mov r6,r0
worker_post:
 ADDR r5,CTX
 ldr r0,[r5,#8]
 cmp r0,#3
 bne worker_return
 ldr r0,[r4,#28]
 cmp r0,#0
 bne worker_return
 ldr r0,[r4,#12]
 cmp r0,#0
 bne worker_return
 ADDR r0,CTRL
 ldrb r0,[r0,#60]
 cmp r0,#0
 bne worker_return
 movs r0,#0
 str r0,[sp]
 ADDR r1,WAKE
 str r1,[sp,#20]
 str r0,[sp,#24]
 str r0,[sp,#28]
 movw r1,#0x8206
 str r1,[sp,#4]
 ldr r1,[r5,#0x10]
 str r1,[sp,#8]
 ADDR r1,TAG
 str r1,[sp,#12]
 ldr r1,[r5,#12]
 str r1,[sp,#16]
 /* Snapshot generation+sequence. Recheck before posting; stale snapshots drop. */
 ldr r2,[r5,#8]
 cmp r2,#3
 bne worker_return
 ldr r2,[r5,#12]
 cmp r1,r2
 bne worker_return
 ldr r1,[sp,#8]
 ldr r2,[r5,#0x10]
 cmp r1,r2
 bne worker_return
 ADDR r1,0x900302d9
 mov r2,sp
 movs r3,#32
 CALL ENQUEUE
 cmp r0,#0
 beq worker_return
 movs r0,#4
 str r0,[r5,#0x3c]
worker_return:
 mov r0,r6
 add sp,#32
 pop {r4-r6,pc}
.size cp_worker_done,.-cp_worker_done


/* Preserve native non-D stop release while pending3, without enabling starts. */
.global cp_stop_f1
.type cp_stop_f1,%function
.thumb_func
cp_stop_f1:
 push {r1-r3,lr}
 ldrb r0,[r0,#0xf1]
 cmp r6,#0
 bne stop_read_return
 ADDR r1,CTX
 ldr r1,[r1,#8]
 cmp r1,#3
 bne stop_read_return
 orr r0,r0,#1
stop_read_return:
 pop {r1-r3,pc}
.size cp_stop_f1,.-cp_stop_f1

/* Callback36D014 keeps exact native A09C44 result; post after clear if idle. */
.global cp_release_clear
.type cp_release_clear,%function
.thumb_func
cp_release_clear:
 push {r4-r6,lr}
 sub sp,#32
 CALL 0x00b11c45
 mov r6,r0
 ADDR r4,CTRL
 b worker_post
.size cp_release_clear,.-cp_release_clear


/* First-frame worker tail: each new state0 epoch sees current active time.
 * No cross-thread controller write and no additional config queue transaction.
 */
.global cp_frame_epoch
.type cp_frame_epoch,%function
.thumb_func
cp_frame_epoch:
 push {r0,r1,r4,lr}
 ldr r2,[r0,#28]
 cmp r2,#0
 bne frame_epoch_ready
 CALL 0x00b11d33
frame_epoch_ready:
 pop {r0,r1,r4,lr}
 b.w original_frame_dispatch
.size cp_frame_epoch,.-cp_frame_epoch
