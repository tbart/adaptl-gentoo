# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
#
#TODO:
# Getting /var/tmp/portage/x11-libs/wxGTK-3.2.8.1-r2/work/wxWidgets-3.2.8.1/src/common/sizer.cpp(2299): assert "CheckSizerFlags(!((flags) & (wxALIGN_RIGHT | wxALIGN_CENTRE_HORIZONTAL | wxALIGN_BOTTOM | wxALIGN_CENTRE_VERTICAL)))" failed in DoInsert(): wxALIGN_RIGHT | wxALIGN_CENTRE_HORIZONTAL | wxALIGN_BOTTOM | wxALIGN_CENTRE_VERTICAL will be ignored in this sizer: wxEXPAND overrides alignment flags in box sizers
# at first start
# it seems (as per https://docs.wxwidgets.org/stable/classwx_hyperlink_ctrl.html) that https://github.com/bambulab/BambuStudio/blob/5346d734170855602e1edce2c080fd8f60c59e2c/src/slic3r/GUI/Widgets/SideTools.cpp#L337 assigns a style that is not valid (wxST_ELLIPSIZE_END)

EAPI=8

WX_GTK_VER="3.2-gtk3"
CMAKE_BUILD_TYPE="Release"

inherit git-r3 wxwidgets cmake desktop xdg

DESCRIPTION="G-code generator for 3D printers (Bambu, Prusa, Voron, VzBot, RatRig, Creality, etc.)"
HOMEPAGE="https://www.orcaslicer.com/"
EGIT_REPO_URI="https://github.com/SoftFever/OrcaSlicer.git"
SRC_URI="https://github.com/SoftFever/OrcaSlicer.git"

# Long story short, It's APGL-3, with code forked from other AGPL-3 slicers.
# It includes some code for a "pressure advance calibration pattern test" which is GPL-3
LICENSE="AGPL-3 GPL-3"
SLOT="0"
KEYWORDS="~amd64" # WIP
# The (heavy!) webview and html features of wxGTK could probably made conditional with an IUSE as well, but UI degradation is untested

IUSE="test"

DEPEND="
	net-misc/curl[ssl]
	sys-apps/dbus
	gui-libs/eglexternalplatform
	sys-apps/file
	sys-devel/gettext
	media-libs/glew
	media-libs/glfw
	gui-libs/gtk
	dev-libs/libmspack
	app-crypt/libsecret
	dev-libs/libspnav
	dev-build/libtool
	virtual/libudev
	media-libs/glu
	net-libs/webkit-gtk
	dev-libs/boost
	media-gfx/openvdb[utils,blosc]
	dev-libs/imath
	dev-libs/libnoise
	media-libs/qhull[static-libs]
	x11-libs/wxGTK:${WX_GTK_VER}[webkit,curl,gstreamer,keyring]
	dev-cpp/gstreamermm
	media-libs/gstreamer
	media-libs/opencv
	sci-mathematics/cgal:=
	sci-libs/opencascade
	dev-libs/cereal
	sci-libs/nlopt
	net-misc/wget
	sys-apps/texinfo
	dev-libs/cereal
	dev-libs/openssl
	sys-devel/m4
	media-libs/draco
	dev-libs/dbus-c++
	dev-libs/dbus-glib
"
RDEPEND="
	${DEPEND}
"
BDEPEND="
	virtual/pkgconfig
	dev-build/ninja
	sys-apps/ripgrep
"
S="${WORKDIR}/orcaslicer-${PV}"

# TODO: improve and document these changes. maybe convert it all to patches?
# We are linking here against a newer boost and CGAL than this version of slic3r is supposed to take, cause these are the only vers availible in gentoo.
# slic3r_fixes.patch is mostly from https://github.com/supermerill/SuperSlicer/pull/4635/commits/c9ba132c329a80b8f7116e86576dd8e6c669a08a
# I forget where the cmake modules are from, but they are edited from stuff I found on the web. IDK if its linking right with system libs.
src_prepare() {
	eapply "${FILESDIR}/slic3r_fixes_dev.patch"
	eapply "${FILESDIR}/TCPConsole.patch"
	cp "${FILESDIR}/BoostProcessCompat.hpp" "${S}/src/libslic3r/BoostProcessCompat.hpp" || die

	pushd "${S}/deps_src/libigl/igl/copyleft/cgal" || die
		rg -l "AABB_traits\.h" | while read file; do sed -i 's/AABB_traits\.h/AABB_traits_3\.h/g' $file ; done || die
		rg -l "AABB_triangle_primitive\.h" | while read file; do sed -i 's/AABB_triangle_primitive\.h/AABB_triangle_primitive_3\.h/g' $file ; done || die
		rg -l "CGAL::AABB_traits" | while read file; do sed -i 's/CGAL::AABB_traits/CGAL::AABB_traits_3/g' $file ; done || die
		rg -l "CGAL::AABB_triangle_primitive" | while read file; do sed -i 's/CGAL::AABB_triangle_primitive/CGAL::AABB_triangle_primitive_3/g' $file ; done || die
	popd
	pushd "${S}/src/libslic3r/" || die
		rg -l "CGAL::AABB_traits" | while read file; do sed -i 's/CGAL::AABB_traits/CGAL::AABB_traits_3/g' $file ; done || die
	popd
	pushd "${S}/src/slic3r/" || die
		rg -l "directory_iterator" | while read file; do sed -i 's/operations.hpp/directory.hpp/g' $file ; done || die
	popd

	# boost 1.90.0 does not explicit "system" module anymore
	eapply "${FILESDIR}/boost-system.patch"
	# distros have long used imath's "half" instead of ilmbase's "half"
	eapply "${FILESDIR}/openvdb-imath-half.patch"
	# boost 1.90.0 has new timer functions
	eapply "${FILESDIR}/bonjour-asio-timer-fix.patch"
	# boost 1.90.0 needs explicit -lboost_process
	eapply "${FILESDIR}/boost-process-linking.patch"

	cmake_src_prepare
}

src_configure() {
	setup-wxwidgets
	filter-lto
	local mycmakeargs=(
		-DSLIC3R_ASAN=OFF
		-DSLIC3R_BUILD_SANDBOXES=OFF
		-DSLIC3R_BUILD_TESTS=$(usex test)
		-DSLIC3R_DESKTOP_INTEGRATION=ON
		-DSLIC3R_FHS=ON
		-DSLIC3R_GTK=3
		-DSLIC3R_GUI=ON
		-DSLIC3R_MSVC_COMPILE_PARALLEL=ON
		-DSLIC3R_MSVC_PDB=ON
		-DSLIC3R_PCH=OFF
		-DSLIC3R_PROFILE=OFF
		-DSLIC3R_STATIC=OFF
		-DSLIC3R_WX_STABLE=OFF

		-DBBL_RELEASE_TO_PUBLIC=OFF
		-DBBL_INTERNAL_TESTING=OFF
		
		-DwxWidgets_CONFIG_EXECUTABLE="/usr/bin/wx-config"

		-DwxWidgets_USE_UNICODE=ON
		-DwxWidgets_USE_STATIC=OFF
		
		-DORCA_TOOLS=1
#		-DUSE_BLOSC=TRUE # Default; openvdb has blosc as default USE, so use it
		
		-DCMAKE_POLICY_VERSION_MINIMUM=3.0
		-DCMAKE_BUILD_TYPE="Release"
#		-DBoost_NO_BOOST_CMAKE=ON # breaks CGAL
		
		-Wno-dev
		-Wdeprecated-declarations
		
		-DCMAKE_CXX_FLAGS="-DwxDEBUG_LEVEL=0 -DNDEBUG ${CMAKE_CXX_FLAGS}"
	)

	# wxMediaCtrl lives in a separate wx library; wx-config exposes it via "media"
	append-libs $(wx-config --libs media)

	cmake_src_configure
}

src_install() {
	cmake_src_install
	#default
	rm "${D}/usr/LICENSE.txt" || die
	rm -r "${D}/usr/include" || die
	rm -r "${D}/usr/lib" || die
	# install bundled Clipper2 shared library
	insinto /usr/lib64/orcaslicer
	doins "${BUILD_DIR}/deps_src/clipper2/libClipper2.so.*" /usr/lib64/
	dosym libClipper2.so.1.5.2 /usr/lib64/libClipper2.so.1
}
