AC_INIT([spi-dump], [0.2])

AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([foreign subdir-objects])
AM_SILENT_RULES([yes])

AM_PROG_VALAC([0.28])
AM_PROG_CC_C_O

CFLAGS="$CFLAGS -w"
AC_PROG_LN_S


dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40.0

PKG_CHECK_MODULES(spi_dump_U, [
  glib-2.0 >= $GLIB_REQUIRED
  gobject-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED
  gio-unix-2.0 >= $GLIB_REQUIRED
  zlib
  ncurses
])

AC_SUBST([spi_dump_U_VALAFLAGS], ["--pkg gio-2.0 \
          --pkg gio-unix-2.0 \
          --pkg posix \
          --pkg zlib \
          --target-glib=$GLIB_REQUIRED \
          --fatal-warnings \
          --enable-checking \
          --enable-experimental-non-null"])

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
src/Makefile
test/Makefile
])
AC_OUTPUT
