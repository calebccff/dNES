struct Memory{
  ubyte[0xFFFF] ram;
  /*RAM Layout:
    https://wiki.nesdev.com/w/index.php/CPU_memory_map
  */
  int count = 0;

  ubyte read(ushort a){
    return ram[a];
  }

  void write(ushort addr, ubyte b){
    if(addr <= 0x1fff) { // Hack for writes to mirrored addresses
      addr = addr%0x07FF;
    }
    void mirror(ushort start, ushort end, ushort mstart, ushort mend){
      if(addr < 0x800){
        for(ushort i = 0x800; i < 0x1FFF; i++){ //Mirror NES RAM
          ram[i] = ram[i-0x800];
        }
      }else if(addr <= 0x2007) { // Create mirrors of I/O RAM
        for(ushort i = 0x2008; i < 0x3fff; i+=0x08){ //Multiple mirrors
          ram[i] = ram[i-0x08];
        }
      }
    }

    ram[addr] = b;
    for(ushort i = 1; i < 4; i++){
      mirror(cast(ushort)0x00, cast(ushort)0x7FF, cast(ushort)(0x800*i), cast(ushort)(0x0FFF*i));
    }

  }

  void writeNext(ubyte b){ //For CPU testing ONLY
    ram[count++] = b;
  }

  void reset(){
    for(int i = 0; i < ram.length; i++){
      ram[i] = 0xFF;
    }
    count = 0;
  }
}
