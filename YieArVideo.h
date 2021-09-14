// Konami Yie Ar Video Chip emulation

#ifndef YIEARVIDEO_HEADER
#define YIEARVIDEO_HEADER

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (224)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

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

void yieArReset(void *periodicIrqFunc(), void *frameIrqFunc(), u8 *ram);

/**
 * Saves the state of the YieArVideo chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The YieArVideo chip to save.
 * @return The size of the state.
 */
int yiearSaveState(void *destination, YieArVideo *chip);

/**
 * Loads the state of the YieArVideo chip from the source.
 * @param  *chip: The YieArVideo chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int yiearLoadState(const void *source, const YieArVideo *chip);

/**
 * Gets the state size of a YieArVideo chip.
 * @return The size of the state.
 */
int yiearGetStateSize(void);

void convertTileMapYieAr(void *destination, const void *source, int length);
void convertSpritesYieAr(void *destination);
void doScanline(void);

#endif // YIEARVIDEO_HEADER
