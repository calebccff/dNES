import std.stdio;
import std.conv;

import memory;

class nesPPU{
  //Registers

  /* PPUCTRL $2000
    Misc. control flags
  */
  struct Ctrl{
    ubyte nt     = 2;  // Nametable ($2000 / $2400 / $2800 / $2C00).
    ubyte incr   = 1;  // Address increment (1 / 32).
    ubyte sprTbl = 1;  // Sprite pattern table ($0000 / $1000).
    ubyte bgTbl  = 1;  // BG pattern table ($0000 / $1000).
    ubyte sprSz  = 1;  // Sprite size (8x8 / 8x16).
    ubyte slave  = 1;  // PPU master/slave.
    ubyte nmi    = 1;  // Enable NMI.
  }

  /* PPUMASK $2001
    Controls rendering of sprites and backgrounds
  */
  struct Mask{
    ubyte gray    = 1;  // Grayscale.
    ubyte bgLeft  = 1;  // Show background in leftmost 8 pixels.
    ubyte sprLeft = 1;  // Show sprite in leftmost 8 pixels.
    ubyte bg      = 1;  // Show background.
    ubyte spr     = 1;  // Show sprites.
    ubyte red     = 1;  // Intensify reds.
    ubyte green   = 1;  // Intensify greens.
    ubyte blue    = 1;  // Intensify blues.
  }

  /* PPUSTATUS $2002
    Reflects state of various internal functions
  */
  struct Status{
    ubyte bus    = 5;  // Not significant.
    ubyte sprOvf = 1;  // Sprite overflow.
    ubyte sprHit = 1;  // Sprite 0 Hit.
    ubyte vBlank = 1;  // In VBlank?
  }

  /* OAM Address $2003
    CPU writes address of desired OAM here, most games use OAMDMA
  */
  ubyte oamAddr;

  /* OAM DMA $4014
    Writing $XX will upload 256 bytes of data from CPU page $XX00-$XXFF to
    internal PPU OAM. Typically located in internal RAM but can also be cartridge
  */

  //Data
  struct Sprite{
    ubyte id;     // Index in OAM.
    ubyte x;      // X position.
    ubyte y;      // Y position.
    ubyte tile;   // Tile index.
    ubyte attr;   // Attributes.
    ubyte dataL;  // Tile data (low).
    ubyte dataH;  // Tile data (high).
  }

  uint[256 * 240] pixels;
}
