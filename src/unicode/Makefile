CC = gcc
CFLAGS = -W -Wall -Wuninitialized -O2

all: encode

encode: encode.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f encode
