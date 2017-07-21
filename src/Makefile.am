SUBDIRS = libplugin plugins

bin_PROGRAMS = spi-dump

spi_dump_SOURCES = \
	libplugin/libspi-dump-plugin.vapi \
	progressbar/progressbar.c \
	progressbar/progressbar.vapi \
	plugin-engine.vala \
	transfer.vala \
	spi-dump.vala

spi_dump_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(glib_U_VALAFLAGS) \
	$(peas_U_VALAFLAGS) \
	$(spi_dump_U_VALAFLAGS)

spi_dump_CFLAGS = \
	-Ilibplugin \
	-DPLUGINDIR=\"$(plugindir)\" \
	$(AM_CFLAGS) \
	$(glib_U_CFLAGS) \
	$(peas_U_CFLAGS) \
	$(spi_dump_U_CFLAGS)

spi_dump_LDADD = \
	-lm \
	libplugin/libspi-dump-plugin.la \
	$(glib_U_LIBS) \
	$(peas_U_LIBS) \
	$(spi_dump_U_LIBS)

-include $(top_srcdir)/git.mk
