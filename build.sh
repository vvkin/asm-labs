# usage: chmod +x build.sh
#        ./build.sh [dir_name]

dir_name="$PWD/$1"

nasm -g -f elf "$dir_name/$1.asm"
ld -m elf_i386 -o "$dir_name/$1" "$dir_name/$1.o"
