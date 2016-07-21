bin_PROGRAMS = spi-dump

spi_dump_SOURCES = \
	transfer.vala \
	spi-dump.vala
spi_dump_VALAFLAGS = $(spi_dump_U_VALAFLAGS)
spi_dump_CFLAGS = $(spi_dump_U_CFLAGS)
spi_dump_LDADD = \
	-lm \
	$(spi_dump_U_LIBS)

CLEANFILES = \
	$(spi_dump_SOURCES:%.vala=%.c) \
	*.stamp \
	*.stamp-t

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)
