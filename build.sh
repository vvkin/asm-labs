# usage: chmod +x build.sh
#        ./build.sh [lab_number]

labname="lab$1"
dir_name="$PWD/$labname"

nasm -g -f elf -l "$dir_name/$labname.lst" "$dir_name/$labname.asm"
ld -m elf_i386 -o "$dir_name/$labname" "$dir_name/$labname.o"
