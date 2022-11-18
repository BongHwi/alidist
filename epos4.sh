package: EPOS4
version: "%(tag_basename)s"
tag: "v4.0.0"
source: https://gitlab.cern.ch/blim/epos4.git
requires:
  - ROOT
  - fastjet
env:
  EPOVSN: "${EPOS_VERSION/./}"
  EPO: "${EPOS_ROOT}/epos/"
---
#!/bin/bash -ex

export EPOVSN=${PKGVERSION/./}

# The following two variables *must* have a trailing slash! EPOS installation
# will make a mess otherwise.
export EPO=$PWD/
export LIBDIR=$EPO/bin/

rsync -a --exclude='**/.git' ${SOURCEDIR}/ .
mkdir $LIBDIR

# Copied from the ROOT installation script (below)
case $ARCHITECTURE in
  osx*)
      export LDFLAGS="-Wl,-undefined dynamic_lookup -L${MPFR_ROOT}/lib -L${GMP_ROOT}/lib -L${CGAL_ROOT}/lib -L/usr/lib"
   ;;
  *)
      export LDFLAGS="-Wl,--no-as-needed -L${MPFR_ROOT}/lib -L${GMP_ROOT}/lib -L${CGAL_ROOT}/lib"
   ;;
esac

# We do not use global options for ROOT, otherwise the -g will
# kill compilation on < 8GB machines
unset CXXFLAGS
unset CFLAGS
unset LDFLAGS

SONAME=so
case $ARCHITECTURE in
  osx_arm64)
    ENABLE_COCOA=1
    DISABLE_MYSQL=1
    COMPILER_CC=clang
    COMPILER_CXX=clang++
    COMPILER_LD=clang
    CXXFLAGS="-mdynamic-no-pic" # This has to be set for preventing errors in osx_arm64.. but not working yet.
    SONAME=dylib
    [[ ! $GSL_ROOT ]] && GSL_ROOT=$(brew --prefix gsl)
    [[ ! $OPENSSL_ROOT ]] && SYS_OPENSSL_ROOT=$(brew --prefix openssl@1.1)
    [[ ! $LIBPNG_ROOT ]] && LIBPNG_ROOT=$(brew --prefix libpng)
  ;;
  osx*)
    ENABLE_COCOA=1
    DISABLE_MYSQL=1
    COMPILER_CC=clang
    COMPILER_CXX=clang++
    COMPILER_LD=clang
    SONAME=dylib
    [[ ! $GSL_ROOT ]] && GSL_ROOT=$(brew --prefix gsl)
    [[ ! $OPENSSL_ROOT ]] && SYS_OPENSSL_ROOT=$(brew --prefix openssl@1.1)
    [[ ! $LIBPNG_ROOT ]] && LIBPNG_ROOT=$(brew --prefix libpng)
  ;;
esac
# Copied from the ROOT installation script (above)

# "Install"
cmake -B$LIBDIR
make -C$LIBDIR ${JOBS+-j $JOBS} 
mkdir -p $INSTALLROOT
cp -rf $BUILDDIR/* $INSTALLROOT/

# Modulefile
# Setup based on the page: https://klaus.pages.in2p3.fr/epos4/code/install
MODULEDIR="$INSTALLROOT/etc/modulefiles"
MODULEFILE="$MODULEDIR/$PKGNAME"
mkdir -p "$MODULEDIR"
cat > "$MODULEFILE" <<EoF
#%Module1.0
proc ModulesHelp { } {
  global version
  puts stderr "ALICE Modulefile for $PKGNAME $PKGVERSION-@@PKGREVISION@$PKGHASH@@"
}
set version $PKGVERSION-@@PKGREVISION@$PKGHASH@@
module-whatis "ALICE Modulefile for $PKGNAME $PKGVERSION-@@PKGREVISION@$PKGHASH@@"
# Dependencies
module load BASE/1.0 ROOT/$ROOT_VERSION-$ROOT_REVISION fastjet/$FASTJET_VERSION-$FASTJET_REVISION
# Our environment
set EPOS4_ROOT \$::env(BASEDIR)/$PKGNAME/\$version
setenv EPOS4_ROOT \$EPOS4_ROOT
prepend-path PATH \$EPOS4_ROOT/bin
setenv EPOVSN ${EPOVSN}
setenv EPO $::env(EPOS4_ROOT)/
setenv LIBDIR ${EPO}bin
setenv OPT ./
setenv HTO ./
setenv CHK ./
setenv PATH ${PATH}:${EPO}/scripts
EoF
