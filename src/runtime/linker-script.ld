ENTRY(_start)
SECTIONS
{
    . = 0x08048000;
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) *(.bdesc1) }
    .bss : { *(.bdesc2) *(.bss) }
    . = 0x09000000;
    .lisp_rom : { *(.lisp_rom) }
    . = 0x0A000000;
    .heap_area : { *(.heap_area) }
}
