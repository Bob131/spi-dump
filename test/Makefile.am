check_PROGRAMS = mock-arduino

mock_arduino_SOURCES = \
	tty.vala \
	mock-arduino.vala

mock_arduino_VALAFLAGS = \
	--enable-experimental \
	$(AM_VALAFLAGS) \
	$(glib_U_VALAFLAGS) \
	$(spi_dump_U_VALAFLAGS)

mock_arduino_CFLAGS = \
	$(AM_CFLAGS) \
	$(glib_U_CFLAGS) \
	$(spi_dump_U_CFLAGS)

mock_arduino_LDADD = \
	$(glib_U_LIBS) \
	$(spi_dump_U_LIBS)

-include $(top_srcdir)/git.mk
