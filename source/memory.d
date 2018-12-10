struct Memory{
  ubyte[0xFFFF] ram;

  ubyte read(ushort a){
    return ram[a];
  }

  void write(ushort addr, ubyte b){
    ram[addr] = b;
    if(addr < 0x800){
      for(ushort i = 0x800; i < 0x1FFF; i++){ //Mirror NES RAM
        ram[i] = ram[i-0x800];
      }
    }
  }
}
