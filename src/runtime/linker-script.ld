ENTRY(_start)
SECTIONS
{
    . = 0x08048000;
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    . = 0x09000000;
    .lisp_rom : { *(.lisp_rom) }
    .bss : { *(.bss) }
}
