lib_LTLIBRARIES = libspi-dump-plugin.la

BUILT_SOURCES = \
	libspi-dump-plugin.h \
	libspi-dump-plugin.vapi

libspi_dump_plugin_la_SOURCES = libspi-dump-plugin.vala

libspi_dump_plugin_la_VALAFLAGS = \
	--library libspi-dump-plugin \
	-H libspi-dump-plugin.h \
	--vapi libspi-dump-plugin.vapi \
	$(AM_VALAFLAGS) \
	$(glib_U_VALAFLAGS)

libspi_dump_plugin_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(glib_U_CFLAGS)

libspi_dump_plugin_la_LIBADD = $(glib_U_LIBS)

-include $(top_srcdir)/git.mk
