import std.conv;
import std.stdio;
import std.datetime.stopwatch;
import core.thread;

import memory;

class Mos6502{

  Memory* ram;

  ubyte    a = 0; //Accumulator
  ubyte    x = 0; //Index X
  ubyte    y = 0; //Index Y

  ubyte    s = 0xFF; //Stack pointer, counts down
  ushort  pc = 0; //Program counter

  // ubyte    c = 0; //Carry
  // ubyte    z = 0; //Zero flag
  // ubyte    i = 0; //Interrupt disable
  // ubyte    d = 0; //Decimal mode, always 0 for nes
  // ubyte    b = 0; //Break flag, unused
  // ubyte    v = 0; //Overflow, when result out of signed byte range
  // ubyte    n = 0; //Negative flag, for two's complement

  ubyte    p = 0; //Status flags
  /*
  7  bit  0
  ---- ----
  NVss DIZC
  |||| ||||
  |||| |||+- Carry
  |||| ||+-- Zero
  |||| |+--- Interrupt Disable
  |||| +---- Decimal
  ||++------ No CPU effect, see: the B flag
  |+-------- Overflow
  +--------- Negative
  */

  //Flag bits, or with flag to set
  enum FLAGS {
    NEGATIVE  = 0x80,
    OVERFLOW  = 0x40,
    CONSTANT  = 0x20, //b flag, set when hardware reset occurs
    BREAK     = 0x10,
    DECIMAL   = 0x08, //Decimal mode, unused on NES
    INTERRUPT = 0x04,
    ZERO      = 0x02,
    CARRY     = 0x01
  }

  //Methods to control status flags
  void SET_NEGATIVE (ubyte x) {if(x){p |= FLAGS.NEGATIVE ;} else {p &= ~FLAGS.NEGATIVE ;}}
  void SET_OVERFLOW (ubyte x) {if(x){p |= FLAGS.OVERFLOW ;} else {p &= ~FLAGS.OVERFLOW ;}}
  void SET_CONSTANT (ubyte x) {if(x){p |= FLAGS.CONSTANT ;} else {p &= ~FLAGS.CONSTANT ;}}
  void SET_BREAK    (ubyte x) {if(x){p |= FLAGS.BREAK    ;} else {p &= ~FLAGS.BREAK    ;}}
  void SET_DECIMAL  (ubyte x) {if(x){p |= FLAGS.DECIMAL  ;} else {p &= ~FLAGS.DECIMAL  ;}}
  void SET_INTERRUPT(ubyte x) {if(x){p |= FLAGS.INTERRUPT;} else {p &= ~FLAGS.INTERRUPT;}}
  void SET_ZERO     (ubyte x) {if(x){p |= FLAGS.ZERO     ;} else {p &= ~FLAGS.ZERO     ;}}
  void SET_CARRY    (ubyte x) {if(x){p |= FLAGS.CARRY    ;} else {p &= ~FLAGS.CARRY    ;}}

  bool IF_NEGATIVE () {if(p&FLAGS.NEGATIVE ){return true;} else {return false;}}
  bool IF_OVERFLOW () {if(p&FLAGS.OVERFLOW ){return true;} else {return false;}}
  bool IF_CONSTANT () {if(p&FLAGS.CONSTANT ){return true;} else {return false;}}
  bool IF_BREAK    () {if(p&FLAGS.BREAK    ){return true;} else {return false;}}
  bool IF_DECIMAL  () {if(p&FLAGS.DECIMAL  ){return true;} else {return false;}}
  bool IF_INTERRUPT() {if(p&FLAGS.INTERRUPT){return true;} else {return false;}}
  bool IF_ZERO     () {if(p&FLAGS.ZERO     ){return true;} else {return false;}}
  bool IF_CARRY    () {if(p&FLAGS.CARRY    ){return true;} else {return false;}}


  //Counters and such
  ushort cycles = 0; //For counting instruction cycles
  bool illegalOpcode = false; //Set when illegal opcode called
  StopWatch sw;
  const double clockTime = 0.055865921; //hnsecs

  //Reset vectors
  static const ushort nmiVectorL = 0xFFFA;
  static const ushort nmiVectorH = 0xFFFB;
  static const ushort rstVectorL = 0xFFFC;
  static const ushort rstVectorH = 0xFFFD;
  static const ushort irqVectorL = 0xFFFE;
  static const ushort irqVectorH = 0xFFFF;

  struct Instr{
    string name; //For dev friendliness

    ushort delegate()         mode; //Addressing mode, sets up registers and offsets
    void delegate(ushort src) exec; //The instruction to execute

    ubyte len; //Number of bytes
    ubyte cycles; //Execute cycles


  }

  Instr[256] instrSet;

  /*
  Adressing modes:
  d,x   - Zero page indexed, used to address the first 0xFF bytes of ram
  d,y   - See above
  a,x   - Absolute indexed - 16 bit address is used (x is low byte)
  a,y   - Same as above, y is low byte
        - Indirect - Only supported by jump, allows 16 bit value to index memory
          to read 16 bit address of real jump target
  (d,x) - Indexed indirect - When instruction includes zero page address
          read address and add X register to get least significant byte of target
  (d),y - Indirect indexed - common. Instruction contains zero page location of
          least significant byte, Y register added to generate target.
  */

  this(Memory* ram){ //Constructor, initialises address table
    this.ram = ram;
    Instr instr;
    //Fill instruction set with illegals, so unimplemented instructions don't cause a crash
    instr = Instr("Illegal", &addr_imp, &op_illegal);
    for(int i = 0; i < instrSet.length; i++){
      instrSet[i] = instr;
    }
    //Setup opcodes
    instr = Instr("ADC imm", &addr_imm, &op_adc, 2, 2);
    instrSet[0x69] = instr;
    instr = Instr("ADC zer", &addr_zer, &op_adc, 2, 3);
    instrSet[0x65] = instr;
    instr = Instr("ADC zex", &addr_zex, &op_adc, 2, 4);
    instrSet[0x75] = instr;
    instr = Instr("ADC abs", &addr_abs, &op_adc, 3, 4);
    instrSet[0x6D] = instr;
    instr = Instr("ADC abx", &addr_abx, &op_adc, 3, 4);
    instrSet[0x7D] = instr;
    instr = Instr("ADC aby", &addr_aby, &op_adc, 3, 4);
    instrSet[0x79] = instr;
    instr = Instr("ADC inx", &addr_inx, &op_adc, 2, 6);
    instrSet[0x61] = instr;
    instr = Instr("ADC iny", &addr_iny, &op_adc, 2, 5);
    instrSet[0x71] = instr;

    instr = Instr("AND imm", &addr_imm, &op_and, 2, 2);
    instrSet[0x29] = instr;
    instr = Instr("AND zer", &addr_zer, &op_and, 2, 3);
    instrSet[0x25] = instr;
    instr = Instr("AND zex", &addr_zex, &op_and, 2, 4);
    instrSet[0x35] = instr;
    instr = Instr("AND abs", &addr_abs, &op_and, 3, 4);
    instrSet[0x2D] = instr;
    instr = Instr("AND abx", &addr_abx, &op_and, 3, 4);
    instrSet[0x3D] = instr;
    instr = Instr("AND aby", &addr_aby, &op_and, 3, 4);
    instrSet[0x39] = instr;
    instr = Instr("AND inx", &addr_inx, &op_and, 2, 6);
    instrSet[0x21] = instr;
    instr = Instr("AND iny", &addr_iny, &op_and, 2, 5);
    instrSet[0x31] = instr;

    instr = Instr("ASL acc", &addr_acc, &op_asl_acc, 1, 2); //Must use different function for accumulator
    instrSet[0x0A] = instr;
    instr = Instr("ASL zer", &addr_zer, &op_asl, 2, 5);
    instrSet[0x06] = instr;
    instr = Instr("ASL zex", &addr_zex, &op_asl, 2, 6);
    instrSet[0x16] = instr;
    instr = Instr("ASL abs", &addr_abs, &op_asl, 3, 6);
    instrSet[0x0E] = instr;
    instr = Instr("ASL abx", &addr_abx, &op_asl, 3, 7);
    instrSet[0x1E] = instr;

    instr = Instr("BCC rel", &addr_rel, &op_bcc, 2, 2);
    instrSet[0x90] = instr;

    instr = Instr("BCS rel", &addr_rel, &op_bcs, 2, 2);
    instrSet[0xB0] = instr;

    instr = Instr("BEQ rel", &addr_rel, &op_beq, 2, 2);
    instrSet[0xF0] = instr;

    instr = Instr("BIT zer", &addr_zer, &op_bit, 2, 3);
    instrSet[0x24] = instr;
    instr = Instr("BIT abs", &addr_abs, &op_bit, 3, 4);
    instrSet[0x2C] = instr;

    instr = Instr("BMI rel", &addr_rel, &op_bmi, 2, 2);
    instrSet[0x30] = instr;

    instr = Instr("BNE rel", &addr_rel, &op_bne, 2, 2);
    instrSet[0xD0] = instr;

    instr = Instr("BPL rel", &addr_rel, &op_bpl, 2, 2);
    instrSet[0x10] = instr;

    instr = Instr("BRK imp", &addr_imp, &op_brk, 1, 7);
    instrSet[0x00] = instr;

    instr = Instr("BVC rel", &addr_rel, &op_bvc, 2, 2);
    instrSet[0x50] = instr;

    instr = Instr("BVS rel", &addr_rel, &op_bvs, 2, 2);
    instrSet[0x70] = instr;

    instr = Instr("CLC imp", &addr_imp, &op_clc, 1, 2);
    instrSet[0x18] = instr;

    instr = Instr("CLD imp", &addr_imp, &op_cld, 1, 2);
    instrSet[0xD8] = instr;

    instr = Instr("CLI imp", &addr_imp, &op_cli, 1, 2);
    instrSet[0x58] = instr;

    instr = Instr("CLV imp", &addr_imp, &op_clv, 1, 2);
    instrSet[0xB8] = instr;

    instr = Instr("CMP imm", &addr_imm, &op_cmp, 2, 2);
    instrSet[0xC9] = instr;
    instr = Instr("CMP zer", &addr_zer, &op_cmp, 2, 3);
    instrSet[0xC5] = instr;
    instr = Instr("CMP zex", &addr_zex, &op_cmp, 2, 4);
    instrSet[0xD5] = instr;
    instr = Instr("CMP abs", &addr_abs, &op_cmp, 3, 4);
    instrSet[0xCD] = instr;
    instr = Instr("CMP abx", &addr_abx, &op_cmp, 3, 4);
    instrSet[0xDD] = instr;
    instr = Instr("CMP aby", &addr_aby, &op_cmp, 3, 4);
    instrSet[0xD9] = instr;
    instr = Instr("CMP inx", &addr_inx, &op_cmp, 2, 6);
    instrSet[0xC1] = instr;
    instr = Instr("CMP iny", &addr_iny, &op_cmp, 2, 5);
    instrSet[0xD1] = instr;

    instr = Instr("CPX imm", &addr_imm, &op_cpx, 2, 2);
    instrSet[0xE0] = instr;
    instr = Instr("CPX zer", &addr_zer, &op_cpx, 2, 3);
    instrSet[0xE4] = instr;
    instr = Instr("CPX abs", &addr_abs, &op_cpx, 3, 4);
    instrSet[0xEC] = instr;

    instr = Instr("CPY imm", &addr_imm, &op_cpy, 2, 2);
    instrSet[0xC0] = instr;
    instr = Instr("CPY zer", &addr_zer, &op_cpy, 2, 3);
    instrSet[0xC4] = instr;
    instr = Instr("CPY abs", &addr_abs, &op_cpy, 3, 4);
    instrSet[0xCC] = instr;

    instr = Instr("DEC zer", &addr_zer, &op_dec, 2, 5);
    instrSet[0xC6] = instr;
    instr = Instr("DEC zex", &addr_zex, &op_dec, 2, 6);
    instrSet[0xD6] = instr;
    instr = Instr("DEC abs", &addr_abs, &op_dec, 3, 6);
    instrSet[0xCE] = instr;
    instr = Instr("DEC abx", &addr_abx, &op_dec, 3, 7);
    instrSet[0xDE] = instr;

    instr = Instr("DEX imp", &addr_imp, &op_dex, 1, 2);
    instrSet[0xCA] = instr;

    instr = Instr("DEY imp", &addr_imp, &op_dey, 1, 2);
    instrSet[0x88] = instr;

    instr = Instr("EOR imm", &addr_imm, &op_eor, 2, 2);
    instrSet[0x49] = instr;
    instr = Instr("EOR zer", &addr_zer, &op_eor, 2, 3);
    instrSet[0x45] = instr;
    instr = Instr("EOR zex", &addr_zex, &op_eor, 2, 4);
    instrSet[0x55] = instr;
    instr = Instr("EOR abs", &addr_abs, &op_eor, 3, 4);
    instrSet[0x4D] = instr;
    instr = Instr("EOR abx", &addr_abx, &op_eor, 3, 4);
    instrSet[0x5D] = instr;
    instr = Instr("EOR aby", &addr_aby, &op_eor, 3, 4);
    instrSet[0x59] = instr;
    instr = Instr("EOR inx", &addr_inx, &op_eor, 2, 6);
    instrSet[0x41] = instr;
    instr = Instr("EOR iny", &addr_iny, &op_eor, 2, 5);
    instrSet[0x51] = instr;

    instr = Instr("INC zer", &addr_zer, &op_inc, 2, 5);
    instrSet[0xE6] = instr;
    instr = Instr("INC zex", &addr_zex, &op_inc, 2, 6);
    instrSet[0xF6] = instr;
    instr = Instr("INC abs", &addr_abs, &op_inc, 3, 6);
    instrSet[0xEE] = instr;
    instr = Instr("INC abx", &addr_abx, &op_inc, 3, 7);
    instrSet[0xFE] = instr;

    instr = Instr("INX imp", &addr_imp, &op_inx, 1, 2);
    instrSet[0xE8] = instr;

    instr = Instr("INY imp", &addr_imp, &op_iny, 1, 2);
    instrSet[0xC8] = instr;

    instr = Instr("JMP abs", &addr_abs, &op_jmp, 3, 3);
    instrSet[0x4C] = instr;
    instr = Instr("JMP abi", &addr_abi, &op_jmp, 3, 5);
    instrSet[0x6C] = instr;

    instr = Instr("JSR abs", &addr_abs, &op_jsr, 3, 6);
    instrSet[0x20] = instr;

    instr = Instr("LDA imm", &addr_imm, &op_lda, 2, 2);
    instrSet[0xA9] = instr;
    instr = Instr("LDA zer", &addr_zer, &op_lda, 2, 3);
    instrSet[0xA5] = instr;
    instr = Instr("LDA zex", &addr_zex, &op_lda, 2, 4);
    instrSet[0xB5] = instr;
    instr = Instr("LDA abs", &addr_abs, &op_lda, 3, 4);
    instrSet[0xAD] = instr;
    instr = Instr("LDA abx", &addr_abx, &op_lda, 3, 4);
    instrSet[0xBD] = instr;
    instr = Instr("LDA aby", &addr_aby, &op_lda, 3, 4);
    instrSet[0xB9] = instr;
    instr = Instr("LDA inx", &addr_inx, &op_lda, 2, 6);
    instrSet[0xA1] = instr;
    instr = Instr("LDA iny", &addr_iny, &op_lda, 2, 5);
    instrSet[0xB1] = instr;

    instr = Instr("LDX imm", &addr_imm, &op_ldx, 2, 2);
    instrSet[0xA2] = instr;
    instr = Instr("LDX zer", &addr_zer, &op_ldx, 2, 3);
    instrSet[0xA6] = instr;
    instr = Instr("LDX zey", &addr_zey, &op_ldx, 2, 4);
    instrSet[0xB6] = instr;
    instr = Instr("LDX abs", &addr_abs, &op_ldx, 3, 4);
    instrSet[0xAE] = instr;
    instr = Instr("LDX aby", &addr_aby, &op_ldx, 3, 4);
    instrSet[0xBE] = instr;

    instr = Instr("LDY imm", &addr_imm, &op_ldy, 2, 2);
    instrSet[0xA0] = instr;
    instr = Instr("LDY zer", &addr_zer, &op_ldy, 2, 3);
    instrSet[0xA4] = instr;
    instr = Instr("LDY zex", &addr_zex, &op_ldy, 2, 4);
    instrSet[0xB4] = instr;
    instr = Instr("LDY abs", &addr_abs, &op_ldy, 3, 4);
    instrSet[0xAC] = instr;
    instr = Instr("LDY abx", &addr_abx, &op_ldy, 3, 4);
    instrSet[0xBC] = instr;

    instr = Instr("LSR acc", &addr_acc, &op_lsr_acc, 1, 2);
    instrSet[0x4A] = instr;
    instr = Instr("LSR zer", &addr_zer, &op_lsr, 2, 5);
    instrSet[0x46] = instr;
    instr = Instr("LSR zex", &addr_zex, &op_lsr, 2, 6);
    instrSet[0x56] = instr;
    instr = Instr("LSR abs", &addr_abs, &op_lsr, 3, 6);
    instrSet[0x4E] = instr;
    instr = Instr("LSR abx", &addr_abx, &op_lsr, 3, 7);
    instrSet[0x5E] = instr;

    instr = Instr("NOP imp", &addr_imp, &op_nop, 1, 2);
    instrSet[0xEA] = instr;

    instr = Instr("ORA imm", &addr_imm, &op_ora, 2, 2);
    instrSet[0x09] = instr;
    instr = Instr("ORA zer", &addr_zer, &op_ora, 2, 3);
    instrSet[0x05] = instr;
    instr = Instr("ORA zex", &addr_zex, &op_ora, 2, 4);
    instrSet[0x15] = instr;
    instr = Instr("ORA abs", &addr_abs, &op_ora, 3, 4);
    instrSet[0x0D] = instr;
    instr = Instr("ORA abx", &addr_abx, &op_ora, 3, 4);
    instrSet[0x1D] = instr;
    instr = Instr("ORA aby", &addr_aby, &op_ora, 3, 4);
    instrSet[0x19] = instr;
    instr = Instr("ORA inx", &addr_inx, &op_ora, 2, 6);
    instrSet[0x01] = instr;
    instr = Instr("ORA iny", &addr_iny, &op_ora, 2, 5);
    instrSet[0x11] = instr;

    instr = Instr("PHA imp", &addr_imp, &op_pha, 1, 3);
    instrSet[0x48] = instr;

    instr = Instr("PHP imp", &addr_imp, &op_php, 1, 3);
    instrSet[0x08] = instr;

    instr = Instr("PLA imp", &addr_imp, &op_pla, 1, 4);
    instrSet[0x68] = instr;

    instr = Instr("PLP imp", &addr_imp, &op_plp, 1, 4);
    instrSet[0x28] = instr;

    instr = Instr("ROL acc", &addr_acc, &op_rol_acc, 1, 2);
    instrSet[0x2A] = instr;
    instr = Instr("ROL zer", &addr_zer, &op_rol, 2, 5);
    instrSet[0x26] = instr;
    instr = Instr("ROL zex", &addr_zex, &op_rol, 2, 6);
    instrSet[0x36] = instr;
    instr = Instr("ROL abs", &addr_abs, &op_rol, 3, 6);
    instrSet[0x2E] = instr;
    instr = Instr("ROL abx", &addr_abx, &op_rol, 3, 7);
    instrSet[0x3E] = instr;

    instr = Instr("ROR acc", &addr_acc, &op_ror_acc, 1, 2);
    instrSet[0x6A] = instr;
    instr = Instr("ROR zer", &addr_zer, &op_ror, 2, 5);
    instrSet[0x66] = instr;
    instr = Instr("ROR zex", &addr_zex, &op_ror, 2, 6);
    instrSet[0x76] = instr;
    instr = Instr("ROR abs", &addr_abs, &op_ror, 3, 6);
    instrSet[0x6E] = instr;
    instr = Instr("ROR abx", &addr_abx, &op_ror, 3, 7);
    instrSet[0x7E] = instr;

    instr = Instr("RTI imp", &addr_imp, &op_rti, 1, 6);
    instrSet[0x40] = instr;

    instr = Instr("RTS imp", &addr_imp, &op_rts, 1, 6);
    instrSet[0x60] = instr;

    instr = Instr("SBC imm", &addr_imm, &op_sbc, 2, 2);
    instrSet[0xE9] = instr;
    instr = Instr("SBC zer", &addr_zer, &op_sbc, 2, 3);
    instrSet[0xE5] = instr;
    instr = Instr("SBC zex", &addr_zex, &op_sbc, 2, 4);
    instrSet[0xF5] = instr;
    instr = Instr("SBC abs", &addr_abs, &op_sbc, 3, 4);
    instrSet[0xED] = instr;
    instr = Instr("SBC abx", &addr_abx, &op_sbc, 3, 4);
    instrSet[0xFD] = instr;
    instr = Instr("SBC aby", &addr_aby, &op_sbc, 3, 4);
    instrSet[0xF9] = instr;
    instr = Instr("SBC inx", &addr_inx, &op_sbc, 2, 6);
    instrSet[0xE1] = instr;
    instr = Instr("SBC iny", &addr_iny, &op_sbc, 2, 5);
    instrSet[0xF1] = instr;

    instr = Instr("SEC imp", &addr_imp, &op_sec, 1, 2);
    instrSet[0x38] = instr;

    instr = Instr("SED imp", &addr_imp, &op_sed, 1, 2);
    instrSet[0xF8] = instr;

    instr = Instr("SEI imp", &addr_imp, &op_sei, 1, 2);
    instrSet[0x78] = instr;

    instr = Instr("STA zer", &addr_zer, &op_sta, 2, 3);
    instrSet[0x85] = instr;
    instr = Instr("STA zex", &addr_zex, &op_sta, 2, 4);
    instrSet[0x95] = instr;
    instr = Instr("STA abs", &addr_abs, &op_sta, 3, 4);
    instrSet[0x8D] = instr;
    instr = Instr("STA abx", &addr_abx, &op_sta, 3, 5);
    instrSet[0x9D] = instr;
    instr = Instr("STA aby", &addr_aby, &op_sta, 3, 5);
    instrSet[0x99] = instr;
    instr = Instr("STA inx", &addr_inx, &op_sta, 2, 6);
    instrSet[0x81] = instr;
    instr = Instr("STA iny", &addr_iny, &op_sta, 2, 6);
    instrSet[0x91] = instr;

    instr = Instr("STX zer", &addr_zer, &op_stx, 2, 3);
    instrSet[0x86] = instr;
    instr = Instr("STX zey", &addr_zey, &op_stx, 2, 4);
    instrSet[0x96] = instr;
    instr = Instr("STX abs", &addr_abs, &op_stx, 3, 4);
    instrSet[0x8E] = instr;

    instr = Instr("STY zer", &addr_zer, &op_sty, 2, 3);
    instrSet[0x84] = instr;
    instr = Instr("STY zex", &addr_zex, &op_sty, 2, 4);
    instrSet[0x94] = instr;
    instr = Instr("STY abs", &addr_abs, &op_sty, 3, 4);
    instrSet[0x8C] = instr;

    instr = Instr("TAX imp", &addr_imp, &op_tax, 1, 2);
    instrSet[0xAA] = instr;

    instr = Instr("TAY imp", &addr_imp, &op_tay, 1, 2);
    instrSet[0xA8] = instr;

    instr = Instr("TSX imp", &addr_imp, &op_tsx, 1, 2);
    instrSet[0xBA] = instr;

    instr = Instr("TXA imp", &addr_imp, &op_txa, 1, 2);
    instrSet[0x8A] = instr;

    instr = Instr("TXS imp", &addr_imp, &op_txs, 1, 2);
    instrSet[0x9A] = instr;

    instr = Instr("TYA imp", &addr_imp, &op_tya, 1, 2);
    instrSet[0x98] = instr;
  }

  void tick(){ //Runs one CPU tick (1 instruction)
    sw.reset();
    sw.start();
    ubyte opcode;
    Instr instr;

    instr = instrSet[ram.read(pc++)];
    //writeln(instr.name);

    ushort src = instr.mode(); //Set addressing mode
    //writeln(src);
    instr.exec(src); //Execute instruction

    //Sleep to keep cycle accurate
    auto time = sw.peek();
    //Thread.sleep(dur!("hnsecs")(1)); //Sleep to make cycles accurate + time taken for instructions to run
  }

  //Addressing modes - All return short
  ushort addr_acc(){ //Operate on accumulator
    return 0; //No addressing needed when using Acc
  }

  ushort addr_imm(){ //Immediate addressing
    return pc++;
  }

  ushort addr_abs(){ //Absolute addressing, for acessing RAM outside of zero page
    ushort addrL;
    ushort addrH;
    ushort addr;

    addrL = ram.read(pc++);
    addrH = ram.read(pc++);

    addr = to!ushort(addrL + (addrH << 8)); //Create a short with the full 16 bit address

    return addr;
  }

  ushort addr_zer(){ //Access zero page
    return ram.read(pc++);
  }

  ushort addr_imp(){ //For instructions that don't access RAM, only 1 byte long
    return 0;
  }

  ushort addr_rel(){ //Used for jumps accessing memory relative to current location
    ushort offset;
    short addr;

    offset = to!ushort(ram.read(pc++));
    if(offset &= 0x80) offset |= 0xFF00; //Something to do with signing the number? not sure
    addr = to!short(pc + offset); //Casts to signed short

    return addr;
  }
  /*
  ONLY used by JuMP.
  Takes the given address and uses it to point to the low part of a 16 bit memory address
  High part is the next memory address
  Two bytes are added and then execution jumps to that 16 bit address
  */
  ushort addr_abi(){ //Absolute indirect addressing, don't think NES uses this as only 2k RAM
    ushort addrL; //Address of READ address
    ushort addrH;
    ushort jtL; //Jump target
    ushort jtH;
    ushort abs;
    ushort addr;

    addrL = ram.read(pc++);
    addrH = ram.read(pc++);

    abs = to!ushort(addrL + (addrH << 8)); //Same as (addrH << 8) | addrL ???

    jtL = ram.read(abs);
    jtH = ram.read((abs & 0xFF00) + ((abs + 1) & 0x00FF)); //Add 1 to get the next address. Is this the same as 'abs+1'?

    addr = to!ushort(jtL + (jtH << 8)); //Apparently equivalent to 'jtH*0x100'

    return addr;
  }

  ushort addr_zex(){ //Zero page + x (% to keep within zero page)
    ushort addr;

    addr = (ram.read(pc++) + x) % 256;

    return addr;
  }

  ushort addr_zey(){ //Zero page + y (% to keep within zero page)
    ushort addr;

    addr = (ram.read(pc++) + y) % 256;

    return addr;
  }

  ushort addr_abx(){ //Absolute, offset by x
    ushort addrL;
    ushort addrH;
    ushort addr;

    addrL = ram.read(pc++);
    addrH = ram.read(pc++);

    addr = to!ushort((addrH << 8) + addrL + x); //No bounds checking?

    return addr;
  }

  ushort addr_aby(){ //Absolute, offset by y
    ushort addrL;
    ushort addrH;
    ushort addr;

    addrL = ram.read(pc++);
    addrH = ram.read(pc++);

    addr = to!ushort((addrH << 8) + addrL + y); //No bounds checking?

    return addr;
  }

  ushort addr_inx(){ //Indrect indexed - Where address is stored in zero page
    ushort addrL;
    ushort addrH;
    ushort addr;

    addrL = (ram.read(pc++) + x) % 256; //Constrained to zero page
    addrH = (addrL + 1) % 256; //Next byte

    addr = ram.read(to!ushort(addrL)) + ram.read(to!ushort(addrH << 8)) + x;
    return addr;
  }

  ushort addr_iny(){ //Indrect indexed - Where address is stored in zero page
    ushort addrL;
    ushort addrH;
    ushort addr;

    addrL = (ram.read(pc++) + x) % 256; //Constrained to zero page
    addrH = (addrL + 1) % 256; //Next byte

    addr = ram.read(to!ushort(addrL)) + ram.read(to!ushort(addrH << 8)) + y;
    return addr;
  }

  //*******************
  //*Control functions*
  //*******************
  void reset(){
    a = 0x00;
    x = 0x00;
    y = 0x00;

    pc = (ram.read(rstVectorH) << 8) + ram.read(rstVectorL);
    s = 0xFD;

    SET_CONSTANT(1);

    cycles = 6; //Reset takes 6 cycles?
    ram.reset();
  }

  void stackPush(ubyte val){
    ram.write(to!ubyte(0x100 + s), val);
    if(s == 0x00) s = 0xFF;
    else s--;
  }

  ubyte stackPop(){
    if(s == 0xFF) s = 0x00;
    else s++;
    return ram.read(0x100 + s); //Read top of stack
  }

  void irq(){
    if(!(p & FLAGS.INTERRUPT)){ //If interrupt flag not set (Are we allows to interrupt the system?)
      SET_BREAK(0);
      stackPush(cast(ubyte)(pc >> 8) & 0xFF); //Push high byte of PC
      stackPush(cast(ubyte)pc & 0xFF); //Push low byte of PC, make sure only low byte is set
      stackPush(p); //Push status flags
      SET_INTERRUPT(1); //Set interrupt flag
      pc = (ram.read(irqVectorH) << 8) + ram.read(irqVectorL); //Jump to reset position
    }
  }

  void nmi(){
    SET_BREAK(0);
    stackPush(cast(ubyte)(pc >> 8) & 0xFF); //Push high byte of PC
    stackPush(cast(ubyte)pc & 0xFF); //Push low byte of PC, make sure only low byte is set
    stackPush(p); //Push status flags
    SET_INTERRUPT(1); //Set interrupt flag
    pc = (ram.read(nmiVectorH) << 8) + ram.read(nmiVectorL); //Jump to reset position
  }

  //*********
  //*Opcodes*
  //*********
  void op_illegal(ushort src){
    illegalOpcode = true; //Program tried to execute illegal opcode
  }

  void op_adc(ushort src){ //Add with carry
    ubyte m = ram.read(src);
    uint sum = a + m + (IF_CARRY() ? 1 : 0); //Carry flag is last bit
    SET_ZERO(!(sum & 0xFF));
    SET_NEGATIVE(sum & 0x80);
    SET_OVERFLOW(!((a ^ m) & 0x80) && ((a ^ sum) & 0x80));
    SET_CARRY(sum > 0xFF);
    a = to!ubyte(sum & 0xFF);
  }

  void op_and(ushort src){ //Bitwise AND
    ubyte m = ram.read(src);
    ubyte res = m & a; //AND with accumulator
    a = res;

    SET_NEGATIVE(res & 0x80); //Sets negative flag if bit 7 is set
    SET_ZERO(!res); //set zero flag if result is 0
  }

  void op_asl(ushort src){
    ubyte m = ram.read(src);
    SET_CARRY(m & 0x80); //If bit 7 is set then will need to carry

    m <<= 1; //Left shift by 1
    m &= 0xFF; //Does nothing?

    SET_NEGATIVE(m & 0x80); //If bit 7 set thenset negative flag
    SET_ZERO(!m);
  }

  void op_asl_acc(ushort src){ //Left shit accumulator
    ubyte m = a;
    SET_CARRY(m & 0x80); //If bit 7 is set then will need to carry

    m <<= 1; //Left shift by 1
    m &= 0xFF; //Does nothing?

    SET_NEGATIVE(m & 0x80); //If bit 7 set thenset negative flag
    SET_ZERO(!m);
  }

  void op_bcc(ushort src){ //Branch if carry clear
    if(!(p&FLAGS.CARRY)){ //Check if carry not set
      pc = src;
    }
  }

  void op_bcs(ushort src){ //Branch if carry set
    if(IF_CARRY()){
      pc = src;
    }
  }

  void op_beq(ushort src){ //Branch if equal (zero flag set)
    if(IF_ZERO()){
      pc = src;
    }
  }

  void op_bit(ushort src){ //Bit test - confusing
    ubyte m = ram.read(src);
    ubyte res = to!ubyte(m&a);

    SET_NEGATIVE(res & 0x80);
    SET_OVERFLOW(m & 0x80);
    SET_NEGATIVE(m & 0x40);
    SET_ZERO(!res);
  }

  void op_bmi(ushort src){ //Branch if minus - if negative
    if(IF_NEGATIVE()){
      pc = src;
    }
  }

  void op_bne(ushort src){
    if(!IF_ZERO()){
      pc = src;
    }
  }
  void op_bpl(ushort src){ //Branch if positive
    if(!IF_NEGATIVE()){ //If not negative, positive
      pc = src;
    }
  }
  void op_brk(ushort src){ //force interrupt
    pc++;
    stackPush((pc >> 8) & 0xFF);
    stackPush(pc & 0xFF);
    stackPush(p | FLAGS.BREAK); //Set break flag and push FLAGS
    SET_INTERRUPT(1);
    pc = (ram.read(irqVectorH) << 8) + ram.read(irqVectorL);
  }
  void op_bvc(ushort src){ //Branch if overflow clear
    if(!IF_OVERFLOW()){
      pc = src;
    }
  }
  void op_bvs(ushort src){ //Branch if overflow set
    if(IF_OVERFLOW()){
      pc = src;
    }
  }
  void op_clc(ushort src){ //Clear carry
    SET_CARRY(0);
  }
  void op_cld(ushort src){ //Clear decimal
    SET_DECIMAL(0);
  }
  void op_cli(ushort src){ //Clear interrupt
    SET_INTERRUPT(0);
  }
  void op_clv(ushort src){ //Clear overflow
    SET_OVERFLOW(0);
  }
  void op_cmp(ushort src){ //Compare acc to memory
    ushort v = to!ushort(a - ram.read(src));
    SET_CARRY(v < 0x100); //?
    SET_NEGATIVE(v & 0x80);
    SET_ZERO(!(v & 0xFF)); //Only want to check first byte
  }
  void op_cpx(ushort src){ //Compare x to memory
    ushort v = to!ushort(x - ram.read(src));
    SET_CARRY(v < 0x100); //?
    SET_NEGATIVE(v & 0x80);
    SET_ZERO(!(v & 0xFF)); //Only want to check first byte
  }
  void op_cpy(ushort src){ //Compare y to memory
    ushort v = to!ushort(y - ram.read(src));
    SET_CARRY(v < 0x100); //?
    SET_NEGATIVE(v & 0x80);
    SET_ZERO(!(v & 0xFF)); //Only want to check first byte
  }
  void op_dec(ushort src){ //Decrement memory
    ubyte m = ram.read(src);
    m = to!ubyte((m-1)%256);

    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    ram.write(src, m);
  }
  void op_dex(ushort src){ //Decrement x
    ubyte m = x;
    m = to!ubyte((m-1)%256);

    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    x = m;
  }
  void op_dey(ushort src){ //Decrement y
    ubyte m = y;
    m = to!ubyte((m-1)%256);

    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    y = m;
  }
  void op_eor(ushort src){ //XOR
    ubyte m = ram.read(src);
    m = a ^ m; //XOR with acc
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = m;
  }
  void op_inc(ushort src){ //Increment memory
    ubyte m = ram.read(src);
    m = to!ubyte((m+1)%256);

    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    ram.write(src, m);
  }
  void op_inx(ushort src){ //Increment x
    ubyte m = x;
    m = to!ubyte((m-1)%256);

    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    x = m;
  }
  void op_iny(ushort src){ //Increment y
    ubyte m = y;
    m = to!ubyte((m-1)%256);

    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    y = m;
  }
  void op_jmp(ushort src){ //Jump!
    pc = src;
  }
  void op_jsr(ushort src){ //Jump to subroutine, stores current PC so you can jump back
    pc--;
    stackPush((pc >> 8) & 0xFF);
    stackPush(pc & 0xFF);
    pc = src;
  }
  void op_lda(ushort src){ //Load RAM into acc
    ubyte m = ram.read(src);
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = m;
  }
  void op_ldx(ushort src){ //Load RAM into x
    ubyte m = ram.read(src);
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    x = m;
  }
  void op_ldy(ushort src){ //Load RAM into y
    ubyte m = ram.read(src);
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    y = m;
  }
  void op_lsr(ushort src){ //Logical shift right
    ubyte m = ram.read(src);
    SET_CARRY(m & 0x01);
    m >>= 1;
    SET_NEGATIVE(0);
    SET_ZERO(!m);
    ram.write(src, m);
  }
  void op_lsr_acc(ushort src){ //Logical shift acc right
    ubyte m = a;
    SET_CARRY(m & 0x01);
    m >>= 1;
    SET_NEGATIVE(0);
    SET_ZERO(!m);
    a = m;
  }
  void op_nop(ushort src){ //No op
    return;
  }
  void op_ora(ushort src){ //Logical inclusive OR
    ubyte m = ram.read(src);
    m = a | m;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = m;
  }
  void op_pha(ushort src){ //Push accumulator
    stackPush(a);
  }
  void op_php(ushort src){ //Push processor status
    stackPush(p | FLAGS.BREAK);
  }
  void op_pla(ushort src){ //Pull acc
    a = stackPop();
    SET_NEGATIVE(a & 0x80);
    SET_ZERO(!a);
  }
  void op_plp(ushort src){ //Pull status
    p = stackPop();
    SET_CONSTANT(1);
  }
  void op_rol(ushort src){ //Rotate left (similar to shift)
    ushort m = ram.read(src);
    m <<= 1;
    if(IF_CARRY()){
      m |= 0x01;
    }
    SET_CARRY(m > 0xFF);
    m &= 0xFF;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    ram.write(src, to!ubyte(m));
  }
  void op_rol_acc(ushort src){ //Rotate left acc (similar to shift)
    ushort m = a;
    m <<= 1;
    if(IF_CARRY()){
      m |= 0x01;
    }
    SET_CARRY(m > 0xFF);
    m &= 0xFF;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = to!ubyte(m);
  }
  void op_ror(ushort src){ //Rotate right
    ushort m = ram.read(src);
    if(IF_CARRY()){
      m |= 0x100;
    }
    SET_CARRY(m & 0x01);
    m >>= 1;
    m &= 0xFF;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    ram.write(src, to!ubyte(m));
  }
  void op_ror_acc(ushort src){ //Rotate right
    ushort m = a;
    if(IF_CARRY()){
      m |= 0x100;
    }
    SET_CARRY(m & 0x01);
    m >>= 1;
    m &= 0xFF;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = to!ubyte(m);
  }
  void op_rti(ushort src){ //Return from interrupt
    ubyte pcL;
    ubyte pcH;

    p = stackPop();

    pcL = stackPop();
    pcH = stackPop();

    pc = (pcH << 8) | pcL;
  }
  void op_rts(ushort src){ //Return from subroutine
    ubyte pcL;
    ubyte pcH;

    pcL = stackPop();
    pcH = stackPop();

    pc = to!ushort(((pcH << 8) | pcL) + 1);
  }
  void op_sbc(ushort src){ //Subtract with carry
    ubyte m = ram.read(src);
    ushort v = to!ushort(a - m - (IF_CARRY() ? 0 : 1));

    SET_NEGATIVE(v & 0x80);
    SET_ZERO(!(v & 0xFF));
    SET_OVERFLOW(((a ^ v) & 0x80) && ((a ^ m) & 0x80));

    //Never in decimal mode
    SET_CARRY(v < 0x100);
    a = to!ubyte((v & 0xFF));
  }
  void op_sec(ushort src){ //Set carry bit
    SET_CARRY(1);
  }
  void op_sed(ushort src){ //Set decimal mode
    return; //Not used on NES
  }
  void op_sei(ushort src){ //Set interrupt bit
    SET_INTERRUPT(1);
  }
  void op_sta(ushort src){ //Store acc
    ram.write(src, a);
  }
  void op_stx(ushort src){ //Store x
    ram.write(src, x);
  }
  void op_sty(ushort src){ //Store y
    ram.write(src, y);
  }
  void op_tax(ushort src){ //Transfer acc to x
    ubyte m = a;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    x = m;
  }
  void op_tay(ushort src){ //Transfer acc to y
    ubyte m = a;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    y = m;
  }
  void op_tsx(ushort src){ //Transfer stack pointer to x
    ubyte m = s;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    x = m;
  }
  void op_txa(ushort src){ //Transfer x to acc
    ubyte m = x;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = m;
  }
  void op_txs(ushort src){ //Transfer x to stack pointer
    s = x;
  }
  void op_tya(ushort src){ //Transfer y to acc
    ubyte m = y;
    SET_NEGATIVE(m & 0x80);
    SET_ZERO(!m);
    a = m;
  }
}
