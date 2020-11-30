# usage: chmod +x build.sh
#        ./build.sh [lab_number]

labname="lab$1"
filename="$PWD/$labname/$labname"

nasm -g -f elf -l "$filename.lst" "$filename.asm"
ld -m elf_i386 -o "$filename" "$filename.o"
