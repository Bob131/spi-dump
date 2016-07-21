#!/bin/sh

set -e

_openbsd_acenv_set() {
    [ -z ${AUTOCONF_VERSION:-} ] || return 0
    export AUTOCONF_VERSION
    AUTOCONF_VERSION="$( ls -1 /usr/local/bin/autoreconf-* | sort | tail -n 1 )"
    AUTOCONF_VERSION="${AUTOCONF_VERSION##*-}"
}

_openbsd_amenv_set() {
    [ -z ${AUTOMAKE_VERSION:-} ] || return 0
    export AUTOMAKE_VERSION
    AUTOMAKE_VERSION="$( ls -1 /usr/local/bin/automake-* | sort | tail -n 1 )"
    AUTOMAKE_VERSION="${AUTOMAKE_VERSION##*-}"
}

_openbsd_env_set() {
    [ `uname` = OpenBSD ] || return 0
    _openbsd_acenv_set
    _openbsd_amenv_set
}

_openbsd_env_set

set -e

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

aclocal -I m4 --install
autoreconf --force --install

if [ -z "$NOCONFIGURE" ]; then
    "$srcdir"/configure ${1+"$@"}
fi

