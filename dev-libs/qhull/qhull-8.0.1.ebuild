# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Qhull is a general dimension convex hull program that reads a set of points from stdin, and outputs the smallest convex set that contains the points to stdout."
HOMEPAGE="http://www.qhull.org/"
SRC_URI="
	https://github.com/qhull/qhull/archive/v${PV}.zip
"

LICENSE="LGPL2.1"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""
DEPEND=""
RDEPEND="
	${DEPEND}
"
BDEPEND="
	virtual/pkgconfig
"
src_install(){
	cmake_src_install
	rm -r "${D}/usr/share/doc/qhull/" || die
	rm "${D}/usr/lib/libqhull_p.so.8.0.1" "${D}/usr/lib/libqhull.so.8.0.1" "${D}/usr/lib/libqhull_r.so.8.0.1" || die
}
