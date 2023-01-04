ENTRY(_start)

SECTIONS {
  . = 0x7c00;
  .text : {
    *(.text)
    *(.rodata .rodata.*)
  }
  /DISCARD/ : {
    *(.*)
  }
}
