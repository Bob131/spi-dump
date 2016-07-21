build:
	valac \
	    --pkg gio-2.0 --pkg gio-unix-2.0 \
	    --pkg posix --pkg linux -X -lm \
	    --pkg zlib \
	    --enable-checking \
	    --enable-experimental --enable-experimental-non-null \
	    --fatal-warnings \
	    -o spi-transfer -X -g -X -w \
	    --save-temps \
	    transfer.vala app.vala
