# AMDRyzer Linux Makefile
# Compiles pure x86-64 assembly with NASM and links with GNU ld (no libc)

NASM ?= nasm
LD   ?= ld

SRC  = AMDRyzer.asm
OBJ  = AMDRyzer.o
BIN  = AMDRyzer

all: $(BIN)

$(OBJ): $(SRC)
	$(NASM) -f elf64 $(SRC) -o $(OBJ)

$(BIN): $(OBJ)
	$(LD) $(OBJ) -o $(BIN)

clean:
	rm -f $(OBJ) $(BIN) AMDRyzer_Tuning_Guide.txt

.PHONY: all clean
