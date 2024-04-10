//
//  YieArVideo.h
//  Konami Yie Ar Video Chip emulator for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2009-08-25.
//  Copyright © 2009-2024 Fredrik Ahlström. All rights reserved.
//

#ifndef YIEARVIDEO_HEADER
#define YIEARVIDEO_HEADER

/** Game screen width in pixels */
#define GAME_WIDTH  (256)
/** Game screen height in pixels */
#define GAME_HEIGHT (224)
/** Total horizontal pixel count */
#define H_PIXEL_COUNT (384)

typedef struct {
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

	void *periodicIrqFunc;
	void *frameIrqFunc;

	u8 irqControl;
	u8 sprMemReload;
	u8 koPadding1[2];

	u32 sprMemAlloc;

	u32 *spriteRomBase;

	u8 *gfxRAM;
	u32 *sprBlockLUT;
} YieArVideo;

/**
 * Initializes the tile decoder.
 * @param  *chrDecode: Pointer to a 0x400 large byte buffer.
 */
void yiearInit(u8 *chrDecode);

void yiearReset(void *periodicIrqFunc(), void *frameIrqFunc(), u8 *ram);

/**
 * Saves the state of the YieArVideo chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The YieArVideo chip to save.
 * @return The size of the state.
 */
int yiearSaveState(void *destination, const YieArVideo *chip);

/**
 * Loads the state of the YieArVideo chip from the source.
 * @param  *chip: The YieArVideo chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int yiearLoadState(YieArVideo *chip, const void *source);

/**
 * Gets the state size of a YieArVideo chip.
 * @return The size of the state.
 */
int yiearGetStateSize(void);

void yiearConvertTileMap(void *destination, const void *source, int length);
void yiearConvertSprites(void *destination);
void yiearDoScanline(void);

#endif // YIEARVIDEO_HEADER
