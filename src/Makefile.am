bin_PROGRAMS = spi-dump

spi_dump_SOURCES = \
	progressbar/progressbar.c \
	progressbar/progressbar.vapi \
	tty.vala \
	transfer.vala \
	spi-dump.vala
spi_dump_VALAFLAGS = $(spi_dump_U_VALAFLAGS)
spi_dump_CFLAGS = $(spi_dump_U_CFLAGS)
spi_dump_LDADD = \
	-lm \
	$(spi_dump_U_LIBS)

CLEANFILES = \
	tty.c \
	transfer.c \
	spi-dump.c \
	*.stamp \
	*.stamp-t

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)
