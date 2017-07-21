AC_INIT([spi-dump], [0.3])

AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([foreign subdir-objects])
AM_SILENT_RULES([yes])

AM_PROG_VALAC([0.28])
AM_PROG_CC_C_O

AC_PROG_LN_S

LT_INIT([disable-static])

AC_SUBST([plugindir], ["\$(libdir)/spi-dump/plugins"])

AC_SUBST([AM_CFLAGS], ["\
  -Wall -Wextra \
  -Wno-unused-function \
  -Wno-unused-parameter \
  -Wno-unused-variable -Wno-unused-but-set-variable \
  \$(NULL)"])

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40.0

PKG_CHECK_MODULES(glib_U, [
  glib-2.0 >= $GLIB_REQUIRED
  gobject-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED
  gio-unix-2.0 >= $GLIB_REQUIRED
])

PKG_CHECK_MODULES(peas_U, [libpeas-1.0])

PKG_CHECK_MODULES(spi_dump_U, [
  zlib
  ncurses
])

AC_SUBST([AM_VALAFLAGS], ["\
          --fatal-warnings \
          --enable-checking \
          --enable-experimental-non-null \
          \$(NULL)"])

AC_SUBST([glib_U_VALAFLAGS], ["\
          --pkg gio-2.0 \
          --pkg gio-unix-2.0 \
          --target-glib=$GLIB_REQUIRED \
          \$(NULL)"])

AC_SUBST([peas_U_VALAFLAGS], ["--pkg libpeas-1.0"])

AC_SUBST([spi_dump_U_VALAFLAGS], ["\
          --pkg posix \
          --pkg zlib \
          \$(NULL)"])

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
src/Makefile
src/libplugin/Makefile
src/plugins/Makefile
test/Makefile
])
AC_OUTPUT
