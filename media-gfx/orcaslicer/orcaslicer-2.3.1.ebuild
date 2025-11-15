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

inherit cmake desktop wxwidgets xdg

DESCRIPTION="G-code generator for 3D printers (Bambu, Prusa, Voron, VzBot, RatRig, Creality, etc.)"
HOMEPAGE="https://www.orcaslicer.com/"
SRC_URI="
	https://github.com/SoftFever/OrcaSlicer/archive/refs/tags/v${PV}.tar.gz
"

# Long story short, It's APGL-3, with code forked from other AGPL-3 slicers.
# It includes some code for a "pressure advance calibration pattern test" which is GPL-3
LICENSE="AGPL-3 GPL-3"
SLOT="0"
KEYWORDS="~amd64" # WIP
# The (heavy!) webview and html features of wxGTK could probably made conditional with an IUSE as well, but UI degradation is untested
# TODO: The video conditional currently fails with
# In file included from /var/tmp/portage/media-gfx/orcaslicer-2.3.1/work/OrcaSlicer-2.3.1/src/slic3r/GUI/MonitorBasePanel.h:37,
#                 from /var/tmp/portage/media-gfx/orcaslicer-2.3.1/work/OrcaSlicer-2.3.1/src/slic3r/GUI/CameraPopup.hpp:4,
#                 from /var/tmp/portage/media-gfx/orcaslicer-2.3.1/work/OrcaSlicer-2.3.1/src/slic3r/GUI/DeviceManager.hpp:17,
#                 from /var/tmp/portage/media-gfx/orcaslicer-2.3.1/work/OrcaSlicer-2.3.1/src/slic3r/Config/../GUI/GUI_App.hpp:11,
#                 from /var/tmp/portage/media-gfx/orcaslicer-2.3.1/work/OrcaSlicer-2.3.1/src/slic3r/Config/Snapshot.cpp:24:
# /var/tmp/portage/media-gfx/orcaslicer-2.3.1/work/OrcaSlicer-2.3.1/src/slic3r/GUI/wxMediaCtrl2.h:59:1: error: expected class-name before '{' token

IUSE="video test"
DEPEND="
	net-misc/curl[ssl]
	sys-apps/dbus
	gui-libs/eglexternalplatform
	sys-apps/file
	sys-devel/gettext
	media-libs/glew
	media-libs/glfw
	media-libs/gstreamer
	gui-libs/gtk
	dev-libs/libmspack
	app-crypt/libsecret
	dev-libs/libspnav
	dev-build/libtool
	virtual/libudev
	media-libs/glu
	net-libs/webkit-gtk
	dev-libs/boost
	media-gfx/openvdb[utils]
	dev-libs/imath
	media-libs/opencv
	dev-libs/libnoise
	media-libs/qhull[static-libs]
	video? (
		x11-libs/wxGTK:${WX_GTK_VER}[webkit,curl,gstreamer]
	)
	!video? (
		x11-libs/wxGTK:${WX_GTK_VER}[webkit,curl]
	)
	sci-mathematics/cgal:=
	sci-libs/opencascade
	dev-libs/cereal
	sci-libs/nlopt
"
RDEPEND="
	${DEPEND}
"
BDEPEND="
	virtual/pkgconfig
	dev-build/ninja
	sys-apps/ripgrep
"
S="${WORKDIR}/OrcaSlicer-${PV}"


PATCHES=(
	# the cmake build unconditionally adds --toolkit to the wx-config call, which fails at least on some setups
	"${FILESDIR}/wxwidgets_no_multislot.patch"
	# slic3r_fixes.patch is mostly from https://github.com/supermerill/SuperSlicer/pull/4635/commits/c9ba132c329a80b8f7116e86576dd8e6c669a08a
	"${FILESDIR}/slic3r_fixes.patch"
)


# TODO: improve and document these changes. maybe convert it all to patches?
# We are linking here against a newer boost and CGAL than this version of slic3r is supposed to take, cause these are the only vers availible in gentoo.
# I forget where the cmake modules are from, but they are edited from stuff I found on the web. IDK if its linking right with system libs.
src_prepare() {
	# wxwidget's "media" property is in fact gstreamer support; if wxGTK is not compiled with it, the configure fails
	if ! use video; then
		PATCHES+=( "${FILESDIR}/orcaslicer-no-media.patch" )
	fi

	rm "${S}/cmake/modules/FindOpenVDB.cmake" "${S}/cmake/modules/OpenVDBUtils.cmake" || die
	cp "${FILESDIR}/FindOpenVDB.cmake" "${S}/cmake/modules/FindOpenVDB.cmake" || die
	cp "${FILESDIR}/OpenVDBUtils.cmake" "${S}/cmake/modules/OpenVDBUtils.cmake" || die
	cp "${FILESDIR}/FindBlosc.cmake" "${S}/cmake/modules/FindBlosc.cmake" || die
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

	cmake_src_prepare
}

src_configure() {
	setup-wxwidgets unicode
	local mycmakeargs=(
		-DOPENVDB_FIND_MODULE_PATH="/usr/$(get_libdir)/cmake/OpenVDB"

		-DSLIC3R_BUILD_TESTS=$(usex test)

		-DSLIC3R_GTK=3
		-DSLIC3R_STATIC=OFF
		-DSLIC3R_FHS=1
		-DSLIC3R_PCH=0
		
		-DBBL_RELEASE_TO_PUBLIC=1
		-DBBL_INTERNAL_TESTING=0
		
		-DwxWidgets_CONFIG_EXECUTABLE="/usr/bin/wx-config"

		-DwxWidgets_USE_UNICODE=ON
		-DwxWidgets_USE_STATIC=OFF

		-DORCA_TOOLS=ON
		-DUSE_BLOSC=TRUE

		-Wno-dev
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install
	rm "${D}/usr/LICENSE.txt" || die
	rm -r "${D}/usr/include" || die
	rm -r "${D}/usr/lib" || die
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
	if ! use video; then
		einfo "\nMissing gstreamer support in wxGTK and/or USE=\"-video\" in this package will most likely break printer camera features"
	fi
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
