import std.stdio;
import std.conv;
import core.thread;

import cpu;
import memory;
import cartridge;

Mos6502 proc;
Memory ram;
Cartridge cart;

void main(){
  cart.loadcart();
  //this is main, it does things
  proc = new Mos6502(&ram);

  fib();
  ushort val = 0;
  for(;;){

    proc.tick();
    ushort r = to!ushort(to!ushort(ram.read(0xF4)) + to!ushort(ram.read(0xF5) << 8));
    if(r != val && r > val){
      writeln(to!string(r));
      val = r;
    }

    Thread.sleep(dur!("hnsecs")(10));
  }
}

void write(ubyte i){
  ram.writeNext(i);
}

void fib(){
  write(0xA9); //LDA
  write(0x01);
  write(0x85); //STA
  write(0xF0);

  write(0x85); //STA
  write(0xF2);

  //Loop
  write(0x18); //CLC
  write(0xA5); //LDA
  write(0xF0);
  write(0x65); //ADC
  write(0xF2);
  write(0x85); //STA
  write(0xF4);

  write(0xA5); //LDA
  write(0xF1);
  write(0x65); //ADC
  write(0xF3);
  write(0x85); //STA
  write(0xF5);

  write(0xA5); //LDA
  write(0xF4);
  write(0x85); //STA
  write(0xF0);
  write(0xA5); //LDA
  write(0xF5);
  write(0x85); //STA
  write(0xF1);

  //Manual repeat
  write(0x18); //CLC
  write(0xA5); //LDA
  write(0xF0);
  write(0x65); //ADC
  write(0xF2);
  write(0x85); //STA
  write(0xF4);

  write(0xA5); //LDA
  write(0xF1);
  write(0x65); //ADC
  write(0xF3);
  write(0x85); //STA
  write(0xF5);

  write(0xA5); //LDA
  write(0xF4);
  write(0x85); //STA
  write(0xF2);
  write(0xA5); //LDA
  write(0xF5);
  write(0x85); //STA
  write(0xF3);

  write(0x4C); //JMP
  write(0x06); //16 bit address
  write(0x00);
}
