base_sources = $(top_srcdir)/src/libplugin/libspi-dump-plugin.vapi
base_valaflags = $(AM_VALAFLAGS) $(glib_U_VALAFLAGS) $(peas_U_VALAFLAGS)
base_cflags = -I$(top_srcdir)/src/libplugin $(AM_CFLAGS) $(glib_U_CFLAGS) $(peas_U_CFLAGS)
base_libs = $(top_srcdir)/src/libplugin/libspi-dump-plugin.la $(glib_U_LIBS) $(peas_U_LIBS)
base_ldflags = -module -avoid-version -no-undefined

plugin_LTLIBRARIES = arduino/libarduino.la

arduino_libarduino_la_SOURCES = \
	arduino/arduino.vala \
	$(base_sources)

arduino_libarduino_la_VALAFLAGS = \
	--pkg posix \
	$(base_valaflags)

arduino_libarduino_la_CFLAGS = $(base_cflags)

arduino_libarduino_la_LIBADD = $(base_libs)

arduino_libarduino_la_LDFLAGS = $(base_ldflags)

-include $(top_srcdir)/git.mk
