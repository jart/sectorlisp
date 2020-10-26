ENTRY(_start)

SECTIONS {

  .text 0x7c00 - 0x600 : {
    *(.start)
    rodata = .;
    *(.rodata .rodata.*)
    . = 0x1fe;
    SHORT(0xaa55);
    *(.text .text.*)
    /*BYTE(0x90);*/
    _etext = .;
    . = ALIGN(512);
  }

  .bss : {
    bss = .;
    *(.bss .bss.*)
    *(COMMON)
  }

  /DISCARD/ : {
    *(.*)
  }
}

boot        = 0x7c00;
q.syntax    = 8192*2;
q.look      = 8192*2+256;
q.globals   = 8192*2+256+2;
q.index     = 8192*2+256+2+2;
q.token     = 8192*2+256+2+2+2;
q.str       = 8192*2+256+2+2+2+128;
v_sectors   = SIZEOF(.text) / 512;
