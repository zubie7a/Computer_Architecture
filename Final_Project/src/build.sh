nasm -f elf -l mir.lst mir.asm
g++ -c includes.cpp
g++ -g -o mir mir.o includes.o `pkg-config --cflags --libs opencv`
rm mir.lst mir.o includes.o
