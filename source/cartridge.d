import std.stdio;
import std.file;

struct Cartridge{
  void loadcart(){
    auto cart = File("roms/zelda.nes", "r");
    // auto buf = cart.rawRead(new ubyte[]);
    // writeln(buf);
  }

}
