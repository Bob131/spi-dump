check_PROGRAMS = mock-arduino

tty.vala:
	$(AM_V_GEN) ln -s $(top_srcdir)/src/tty.vala tty.vala

mock_arduino_SOURCES = \
	tty.vala \
	mock-arduino.vala
mock_arduino_VALAFLAGS = \
	--enable-experimental \
	$(spi_dump_U_VALAFLAGS)
mock_arduino_CFLAGS = $(spi_dump_U_CFLAGS)
mock_arduino_LDADD = $(spi_dump_U_LIBS)

CLEANFILES = \
	tty.vala \
	tty.c \
	mock-arduino.c \
	*.stamp \
	*.stamp-t

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)
