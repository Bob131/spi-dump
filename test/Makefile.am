check_PROGRAMS = mock-arduino

BUILT_SOURCES = tty.vala

tty.vala:
	$(AM_V_GEN) $(LN_S) $(top_srcdir)/src/tty.vala tty.vala

mock_arduino_SOURCES = \
	tty.vala \
	mock-arduino.vala

mock_arduino_VALAFLAGS = \
	--enable-experimental \
	$(spi_dump_U_VALAFLAGS)

mock_arduino_CFLAGS = $(spi_dump_U_CFLAGS)

mock_arduino_LDADD = $(spi_dump_U_LIBS)

-include $(top_srcdir)/git.mk
