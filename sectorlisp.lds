ENTRY(_start)

SECTIONS {
  . = 0;
  .text : {
    *(.text)
    *(.rodata .rodata.*)
  }
  /DISCARD/ : {
    *(.*)
  }
}
