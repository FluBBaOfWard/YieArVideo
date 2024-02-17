;@
;@  YieArVideo.s
;@  Konami YieAr Video Chip emulator for GBA/NDS.
;@
;@  Created by Fredrik Ahlström on 2009-03-23.
;@  Copyright © 2009-2024 Fredrik Ahlström. All rights reserved.
;@

#if !__ASSEMBLER__
	#error This header file is only for use in assembly files!
#endif

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (224)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

	.equ SPRSRCTILECOUNTBITS,	9
	.equ SPRDSTTILECOUNTBITS,	8
	.equ SPRGROUPTILECOUNTBITS,	0
	.equ SPRBLOCKCOUNT,			(1<<(SPRSRCTILECOUNTBITS - SPRGROUPTILECOUNTBITS))
	.equ SPRTILESIZEBITS,		5

	koptr		.req r12
						;@ YieArVideo.s
	.struct 0
scanline:		.long 0			;@ These 3 must be first in state.
nextLineChange:	.long 0
lineState:		.long 0

periodicIrqFunc:.long 0			;@
frameIrqFunc:	.long 0

yieArState:						;@
yieArRegs:						;@
irqControl:		.byte 0			;@
sprMemReload:	.byte 0
yaPadding:		.space 2

sprMemAlloc:	.long 0

spriteRomBase:	.long 0

gfxRAM:			.long 0
sprBlockLUT:	.long 0

yieArSize:

;@----------------------------------------------------------------------------

