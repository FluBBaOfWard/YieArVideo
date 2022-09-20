// Konami YieAr Video Chip emulation

#ifdef __arm__

#ifdef GBA
#include "../Shared/gba_asm.h"
#elif NDS
#include "../Shared/nds_asm.h"
#endif
#include "../Shared/EmuSettings.h"
#include "YieArVideo.i"

	.global yieArInit
	.global yieArReset
	.global yiearSaveState
	.global yiearLoadState
	.global yiearGetStateSize
	.global convertTilesYieAr
	.global doScanline
	.global convertTileMapYieAr
	.global convertSpritesYieAr
	.global yieArRam_R
	.global yieArRam_W
	.global yieAr_W


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
yieArInit:		;@ Only need to be called once
;@----------------------------------------------------------------------------
	mov r1,#0xffffff00			;@ Build chr decode tbl
	ldr r2,=CHR_DECODE			;@ 0x400
ppi:
	ands r0,r1,#0x01
	movne r0,#0x10000000
	tst r1,#0x02
	orrne r0,r0,#0x01000000
	tst r1,#0x04
	orrne r0,r0,#0x00100000
	tst r1,#0x08
	orrne r0,r0,#0x00010000
	tst r1,#0x10
	orrne r0,r0,#0x00001000
	tst r1,#0x20
	orrne r0,r0,#0x00000100
	tst r1,#0x40
	orrne r0,r0,#0x00000010
	tst r1,#0x80
	orrne r0,r0,#0x00000001
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi

	bx lr
;@----------------------------------------------------------------------------
yieArReset:		;@ r0=NMI(periodicIrqFunc), r1=IRQ(frameIrqFunc), r2=ram
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r2,lr}

	mov r0,koptr
	ldr r1,=yieArSize/4
	bl memclr_					;@ Clear VDP state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia koptr,{r0-r2}			;@ Reset scanline, nextChange & lineState

//	mov r0,#-1
	strb r0,[koptr,#sprMemReload]
	mov r0,#1<<(SPRDSTTILECOUNTBITS-SPRGROUPTILECOUNTBITS)
	str r0,[koptr,#sprMemAlloc]

	ldmfd sp!,{r0-r2,lr}

	cmp r0,#0
	adreq r0,dummyIrqFunc
	cmp r1,#0
	adreq r1,dummyIrqFunc
	str r0,[koptr,#periodicIrqFunc]
	str r1,[koptr,#frameIrqFunc]

	str r2,[koptr,#gfxRAM]
	add r2,r2,#0x1000
	str r2,[koptr,#sprBlockLUT]

dummyIrqFunc:
	bx lr

;@----------------------------------------------------------------------------
yiearSaveState:				;@ In r0=destination, r1=koptr. Out r0=state size.
	.type   yiearSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r4,r0					;@ Store destination
	mov r5,r1					;@ Store koptr (r1)

	ldr r1,[r5,#gfxRAM]
	mov r2,#0x1000
	bl memcpy

	add r0,r4,#0x1000
	add r1,r5,#yieArRegs
	mov r2,#4
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x1004
	bx lr
;@----------------------------------------------------------------------------
yiearLoadState:				;@ In r0=koptr, r1=source. Out r0=state size.
	.type   yiearLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0					;@ Store koptr (r0)
	mov r4,r1					;@ Store source

	ldr r0,[r5,#gfxRAM]
	mov r2,#0x1000
	bl memcpy

	add r0,r5,#yieArRegs
	add r1,r4,#0x1000
	mov r2,#4
	bl memcpy

	mov koptr,r5				;@ Restore koptr (r12)
	bl endFrame

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
yiearGetStateSize:		;@ Out r0=state size.
	.type   yiearGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x1004
	bx lr

;@----------------------------------------------------------------------------
convertTilesYieAr:			;@ r0 = destination, r1 = source.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r8}
	mov r3,r1					;@ r3 = bitplane 0 & 1
	add r4,r3,#0x2000			;@ r4 = bitplane 2 & 3
	ldr r2,=CHR_DECODE
	mov r5,#0x1000
bgChr1:
	ldrb r6,[r3,#8]				;@ Read 1st & 2nd plane, right half.
	ldrb r8,[r3],#1				;@ Read 1st & 2nd plane, left half.
	ldrb r7,[r4,#8]				;@ Read 3rd & 4th plane, right half.
	ldrb r1,[r4],#1				;@ Read 3rd & 4th plane, left half.
	ldr r8,[r2,r8,lsl#2]
	ldr r1,[r2,r1,lsl#2]
	orr r8,r1,r8,lsl#2
	ldr r6,[r2,r6,lsl#2]
	ldr r7,[r2,r7,lsl#2]
	orr r6,r7,r6,lsl#2

	orr r8,r8,r8,lsr#15
	orr r6,r6,r6,lsr#15
	mov r8,r8,lsl#16
	mov r6,r6,lsl#16
	orr r8,r6,r8,lsr#16

	str r8,[r0],#4

	sub r5,r5,#1
	tst r5,#0x07
	addeq r3,r3,#0x08
	addeq r4,r4,#0x08
	cmp r5,#0x00
	bne bgChr1

	ldmfd sp!,{r4-r8}
	bx lr

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .ewram,"ax"
	.align 2
#endif
;@----------------------------------------------------------------------------
convertTileMapYieAr:		;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r6,lr}

	ldr r4,[koptr,#gfxRAM]
	add r4,r4,#0x800
	ldr r5,=0x7FE
	mov r6,#2					;@ Increase read
	mov r3,#0					;@ No tile flip
	ldrb r1,[koptr,#irqControl]
	tst r1,#0x01				;@ Screen flip bit
	addne r4,r4,r5				;@ End of tilemap
	movne r6,#-2				;@ Decrease read
	ldrne r3,=0xC0000000		;@ Tile flip

	bl bgrMapRender
	ldmfd sp!,{r3-r6,pc}

;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
	ldrb r0,[koptr,#irqControl]
	ands r0,r0,#2				;@ IRQ enabled? Every frame.
	ldrne pc,[koptr,#frameIrqFunc]
	bx lr
;@----------------------------------------------------------------------------
clearFrameIRQ:
;@----------------------------------------------------------------------------
	mov r0,#0
	ldr pc,[koptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
frameEndHook:
;@----------------------------------------------------------------------------
	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia koptr,{r0-r2}			;@ Reset scanline, nextChange & lineState

	mov r0,#0					;@ Must return 0 to end frame.
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------
//	mov r0,#0
//	str r0,[koptr,#scanline]	;@ Reset scanline count
//	strb r0,lineState			;@ Reset line state
	bx lr
;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame			;@ ZeroLine
	.long 239, endFrame			;@ Last visible scanline
	.long 240, checkFrameIRQ	;@ frameIRQ
	.long 248, clearFrameIRQ	;@ frameIRQ off
	.long 264, frameEndHook		;@ totalScanlines
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2
;@----------------------------------------------------------------------------
executeScanline:
;@----------------------------------------------------------------------------
	ldr r2,[koptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib koptr,{r1,r2}			;@ Write nextLineChange & lineState
	stmfd sp!,{lr}
	mov lr,pc
	bx r0
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
doScanline:
;@----------------------------------------------------------------------------
	ldmia koptr,{r1,r2}			;@ Read scanLine & nextLineChange
	cmp r1,r2
	bpl executeScanline
	add r1,r1,#1
	str r1,[koptr,#scanline]
;@----------------------------------------------------------------------------
checkScanlineIRQ:
;@----------------------------------------------------------------------------
	ands r0,r1,#0x1f			;@ NMI every 32th scanline
	bxne lr

	stmfd sp!,{lr}
	ldrb r0,[koptr,#irqControl]
	ands r0,r0,#4				;@ NMI enabled? 8 times a frame?
	movne lr,pc
	ldrne pc,[koptr,#periodicIrqFunc]

	mov r0,#1
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
yieArRam_R:					;@ Ram read (0x5000-0x5FFF)
;@----------------------------------------------------------------------------
	bic r1,r1,#0xFF000
	ldr r2,[koptr,#gfxRAM]
	ldrb r0,[r2,r1]
	bx lr

;@----------------------------------------------------------------------------
yieArRam_W:					;@ Ram write (0x5000-0x5FFF)
;@----------------------------------------------------------------------------
	bic r1,r1,#0xFF000
	ldr r2,[koptr,#gfxRAM]
	strb r0,[r2,r1]
	bx lr

;@----------------------------------------------------------------------------
yieAr_W:					;@ I/O write (0x4000)
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA breakpoint
	stmfd sp!,{r4,lr}
	ldrb r1,[koptr,#irqControl]	;@ bit 0=flip, 1=periodIRQ, 2=frameIRQ, 3=coin A, 4=coin B
	strb r0,[koptr,#irqControl]
	mov r4,r0
	bic r1,r0,r1
	movs r1,r1,lsl#28
	ldr r1,=coinCounter0
	ldrmi r0,[r1]
	addmi r0,r0,#1
	strmi r0,[r1]
	addcs r1,r1,#4
	ldrcs r0,[r1]
	addcs r0,r0,#1
	strcs r0,[r1]

	ands r0,r4,#2
	moveq lr,pc
	ldreq pc,[koptr,#periodicIrqFunc]
	ands r0,r4,#4
	moveq lr,pc
	ldreq pc,[koptr,#frameIrqFunc]
	ldmfd sp!,{r4,lr}

	bx lr

;@----------------------------------------------------------------------------
bgrMapRender:
;@----------------------------------------------------------------------------

bgTrLoop1:
	ldrh r1,[r4],r6				;@ Read from YieAr Tilemap RAM,  ttttttttxy-t----
	eor r1,r3,r1,ror#8
	bic r1,r1,#0x2F000000
	orr r1,r1,r1,lsr#20
	ands r2,r1,0xC0000000
	teqne r2,#0xC0000000
	eorne r1,r1,#0x0C00			;@ YX flip

	strh r1,[r0],#2				;@ Write to GBA/NDS Tilemap RAM
	tst r0,r5
	bne bgTrLoop1

	bx lr
;@----------------------------------------------------------------------------
reloadSprites:
;@----------------------------------------------------------------------------
	mov r0,#1<<(SPRDSTTILECOUNTBITS-SPRGROUPTILECOUNTBITS)
	str r0,[koptr,#sprMemAlloc]
	mov r1,#0x40000000				;@ r1=value
	strb r1,[koptr,#sprMemReload]	;@ Clear spr mem reload.
	mov r0,r9						;@ r0=destination
	mov r2,#SPRBLOCKCOUNT			;@ 512 tile entries
	b memset_						;@ Prepare lut
;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x800		;@ 0x800=AGB OBJ priority 2
;@----------------------------------------------------------------------------
convertSpritesYieAr:		;@ in r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination

	ldr r9,[koptr,#sprBlockLUT]
	ldrb r0,[koptr,#sprMemReload]
	cmp r0,#0
	blne reloadSprites

	ldr r10,[koptr,#gfxRAM]

	ldr r7,=gScaling
	ldrb r7,[r7]
	cmp r7,#UNSCALED			;@ Do autoscroll
	ldreq r7,=0x01000000		;@ No scaling
//	ldrne r7,=0x00DB6DB6		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
//	ldrne r7,=0x00B6DB6D		;@ 160/224, 5/7, scaling. 0xA0000000/0xE0 = 0x00B6DB6D.
	ldrne r7,=(SCREEN_HEIGHT<<19)/(GAME_HEIGHT>>5)		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
	ldreq r6,=yStart			;@ First scanline?
	ldrbeq r6,[r6]
	movne r6,#0

	mov r5,#0x50000000			;@ 16x16 size + X-flip
	orrne r5,r5,#0x0100			;@ Scaling

	ldrb r1,[koptr,#irqControl]
	tst r1,#0x01				;@ Screen flip bit
	orrne r5,#0x20000000		;@ Y-flip
	rsbne r7,r7,#0
	rsbeq r6,r6,#GAME_HEIGHT
	add r6,r6,#0x8

	mov r8,#24					;@ Number of sprites
//	add r10,r10,r8,lsl#1		;@ Begin with the last sprite
dm5:
	add r2,r10,#0x400
	ldrh r4,[r10],#2			;@ YieAr OBJ0, r4=Attrib,Ypos.
	sub r0,r6,r4,lsr#8			;@ Mask Y
	cmp r0,#GAME_HEIGHT
	beq dm10					;@ Skip if sprite Y=0xF8, 0xF7?
	subpl r0,r0,#0x100			;@ Make ypos > 0xF8 negative.

	ldrh r1,[r2]				;@ YieAr OBJ1, r1=Tile,Xpos.
	sub r2,r1,#(GAME_WIDTH-SCREEN_WIDTH)/2
	and r2,r2,#0xFF

	mul r0,r7,r0				;@ Y = scaled Y
	sub r0,r0,#0x08000000
	eor r0,r5,r0,lsr#24			;@ Size + scaling
	orr r0,r0,r2,lsl#16

	orr r4,r1,r4,lsl#16

	and r1,r4,#0x00C00000		;@ X/Yflip
	eor r0,r0,r1,lsl#6
	str r0,[r11],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	mov r1,r4,lsl#15
	mov r1,r1,lsr#23
	ldr r0,[r9,r1,lsl#2]		;@ Look up pattern conversion
	movs r0,r0,lsl#2
	blcs VRAM_spr_16			;@ Jump to spr copy, takes tile# in r1, gives new tile# in r0
ret01:
	orr r0,r0,#PRIORITY			;@ Priority
	strh r0,[r11],#4			;@ Store OBJ Atr 2. Pattern, prio & palette.
dm9:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
dm10:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	b dm9

;@----------------------------------------------------------------------------
spriteCacheFull:
	strb r2,[koptr,#sprMemReload]
	ldmfd sp!,{r4-r11,pc}
;@----------------------------------------------------------------------------
VRAM_spr_16:			;@ Takes tilenumber in r1, returns new tilenumber in r0
;@----------------------------------------------------------------------------
	ldr r2,[koptr,#sprMemAlloc]
	subs r2,r2,#1
	bmi spriteCacheFull
	str r2,[koptr,#sprMemAlloc]

	str r2,[r9,r1,lsl#2]
	mov r0,r2,lsl#2

;@----------------------------------------------------------------------------
do16:
	stmfd sp!,{r0-r6,lr}
	ldr r6,=CHR_DECODE
	ldr r3,[koptr,#spriteRomBase]	;@ r3 = bitplane 0 & 1
	ldr r5,=SPRITE_GFX			;@ r6=SPR tileset
	add r5,r5,r0,lsl#5			;@
	add r3,r3,r1,lsl#6			;@ id x 64
	add r4,r3,#0x8000			;@ r4 = bitplane 2 & 3

spr1:
	ldrb r0,[r3,#8]				;@ Read 1st & 2nd plane, right half.
	ldrb r1,[r4,#8]				;@ Read 3rd & 4th plane, right half.
	ldr r0,[r6,r0,lsl#2]
	ldr r1,[r6,r1,lsl#2]
	orr r2,r1,r0,lsl#2

	ldrb r0,[r3],#1				;@ Read 1st & 2nd plane, left half.
	ldrb r1,[r4],#1				;@ Read 3rd & 4th plane, left half.
	ldr r0,[r6,r0,lsl#2]
	ldr r1,[r6,r1,lsl#2]
	orr r0,r1,r0,lsl#2

	orr r0,r0,r0,lsr#15
	orr r2,r2,r2,lsr#15
	mov r0,r0,lsl#16
	mov r2,r2,lsl#16
	orr r0,r2,r0,lsr#16
	str r0,[r5],#4

	tst r5,#0x1C
	bne spr1
	addeq r3,r3,#0x08
	addeq r4,r4,#0x08
	tst r5,#0x60				;@ Allways 1 16x16 tiles
	bne spr1

	ldmfd sp!,{r0-r6,pc}
;@----------------------------------------------------------------------------

	.section .ewram,"ax"
	.align 2
;@----------------------------------------------------------------------------
CHR_DECODE:
	.space 0x400

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
