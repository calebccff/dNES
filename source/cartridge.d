import std.stdio;
import std.file;

import utils;
import Memory;

struct Cartridge{
  FileType type;
  ubyte[] prg;
  ubyte[] chr;

  void loadcart(Memory ram){
    auto file = File("roms/nestest.nes", "r");
    auto header = file.rawRead(new ubyte[0x10]);
    bool iNESFormat=false;
    if (header[0]=='N' && header[1]=='E' && header[2]=='S' && header[3]==0x1A) { //"NES<EOF>"
      iNESFormat=true;
      type = iNES;
    }

    if (iNESFormat==true && (header[7]&0x0C)==0x08) { //Checks that bit 3 is set on the 7th byte
      type = NES20;
    }

    ubyte[] trainer;
    const bool hasTrainer = (header[6]&F6_TRAINER_P)==1;
    if(hasTrainer) {
      trainer = file.rawRead(new ubyte[0x200]);
    }

    ushort PRG = header[4];
    ubyte  PRG_MSB = header[9]&F9_PRG_ROM<<8;
    ushort CHR = header[5];
    ubyte  CHR_MSB = header[9]&F9_CHR_ROM<<4;

    
    if(PRG_MSB == 0x0f)
    {
      //Exponent math
      writeln("STUB: Skipping PRG-ROM size calculation");
    } else
    {
      PRG += PRG_MSB; //Add MS 4 bits
    }
    if(CHR_MSB == 0x0f) // Repeat for Character ROM
    {
      //Exponent math
      writeln("STUB: Skipping CHR-ROM size calculation");
    } else
    {
      CHR += CHR_MSB; //Add MS 4 bits
    }
    writeln(header);
    writeln(trainer);
    write("PRG-ROM Bank count: ");
    writeln(PRG);
    write("CHR-ROM Bank count: ");
    writeln(CHR);

    /+ No offset as file pointer is always at last byte of previous read? +/
    //uint offset = hasTrainer?0x200:0;
    prg = file.rawRead(new ubyte[PRG*PRG_BANK_SIZE]);
    chr = file.rawRead(new ubyte[CHR*CHR_BANK_SIZE]);
    for(int i = 0; i < prg.length; i++){
      ram[0x8000+i] = prg[i];
    }
    for(int i = 0; i < prg.length; i++){
      ram[0x8000+i] = prg[i];
    }
  }

}