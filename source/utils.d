enum FileType {
  iNES,
  NES20,
  INVALID,
}
alias iNES = FileType.iNES;
alias NES20 = FileType.NES20;
alias INVALID = FileType.INVALID;

// ROM Bank size
const uint PRG_BANK_SIZE   = 0x4000;
const uint CHR_BANK_SIZE   = 0x2000;

// Arbitrary bit masks
/+ Flag 6 +/
const ubyte F6_MIRROR_TYPE = 0b00000001;
const ubyte F6_BATTERY_P   = 0b00000010;
const ubyte F6_TRAINER_P   = 0b00000100;
const ubyte F6_FOURSCREEN  = 0b00001000;
const ubyte F6_MAPPER_NUM  = 0b11110000;

/+ Flag 9 +/
const ubyte F9_PRG_ROM     = 0b00001111;
const ubyte F9_CHR_ROM     = 0b11110000;
