import std.stdio;
import std.conv;
import core.thread;

import cpu;

Mos6502 proc;

void main(){
  proc = new Mos6502();
  proc.ram.ram[0] = 0x29;
  proc.ram.ram[1] = 0b11110000;
  proc.a          = 0b10101111;
  for(;;){
    proc.tick();
    writeln(proc.a);
    break;//Thread.sleep(dur!("msecs")(10));
  }
}
