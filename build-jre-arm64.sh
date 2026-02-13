#!/bin/bash
set -euo pipefail

# usage:
#
#   ./build-jre-arm64.sh
#
# which produces e.g.
#
#   SemeruJREarm64Linux_25.0.1/SemeruJREarm64Linux_25.0.1.tar.gz.sha256
#   SemeruJREarm64Linux_25.0.1/SemeruJREarm64Linux_25.0.1.tar.gz
#
# where 'SemeruJREarm64Linux_25.0.1.tar.gz' contains
#
#   * sysroot -- an input JDK and supporting native aarch64 libraries
#   * package.manifest -- some JSON
#   * README.md -- placeholder
#
# Assumptions: the host is native ARM64 and already has the necessary
# libraries (libc, zlib, libstdc++) installed.
#
# precise behaviour can be altered by defining alternative
# values for the following variables in the calling environment:

# these influence the Exact JDK that is downloaded
VERSION="${VERSION-25.0.1}"
PACKAGE_BASENAME="${PACKAGE_BASENAME-SemeruJREarm64Linux}"
JRE_DIR="${JRE_DIR-jdk-25.0.1+8-jre}"
JRE_URL="${JRE_URL-https://github.com/ibmruntimes/semeru25-binaries/releases/download/jdk-25.0.1%2B8_openj9-0.56.0/ibm-semeru-open-jre_aarch64_linux_25.0.1_8_openj9-0.56.0.tar.gz}" 

# this alters where to find native libraries on the host
LIBROOT=${LIBROOT-/usr/lib64}

# these set the output path
PKG_NAME=${PACKAGE_BASENAME}_${VERSION}
WORKDIR="${WORKDIR-$PWD/$PKG_NAME}"

##############################################################################

die() {
    echo "$@" >&2
    exit 1
}

command -v wget >/dev/null || die "please install the wget tool and try again"

# fedora aarch64 path: /usr/lib64
if [ ! -f "$LIBROOT/libc.so.6" ]; then
    # debian aarch64 path: /lib/aarch64-linux-gnu
    LIBROOT=/lib/aarch64-linux-gnu
    if [ ! -f "$LIBROOT/libc.so.6" ]; then
        die "can't figure out where aarch64 libraries are installed"
    fi
fi

SYSROOT="$WORKDIR/sysroot"

# Install Semeru JRE in sysroot
mkdir -p "$SYSROOT/lib" "$SYSROOT/lib64" "$SYSROOT/usr/lib/aarch64-linux-gnu" "$SYSROOT/$JRE_DIR"
wget -cO "$WORKDIR/jre.tar.gz" "${JRE_URL}"
tar -xzf "$WORKDIR/jre.tar.gz" --strip-components=1 -C "$SYSROOT/$JRE_DIR"

# Populate Linux ARM64 sysroot
cp /lib/ld-linux-aarch64.so.1 "$SYSROOT/lib/"
cp /lib/ld-linux-aarch64.so.1 "$SYSROOT/lib64/"
cd "$LIBROOT"
cp libc.so.6 \
    libm.so.6 \
    libpthread.so.0 \
    libdl.so.2 \
    librt.so.1 \
    libgcc_s.so.1 \
    libstdc++.so.6 \
    libz.so.1 \
    "$SYSROOT/usr/lib/aarch64-linux-gnu/"

# package.manifest (JSON)
cat > "$WORKDIR/package.manifest" <<EOF
{
 "Program": "/${JRE_DIR}/bin/java",
 "Args": ["java"],
 "Env": {
   "JAVA_HOME": "/${JRE_DIR}"
 },
 "Version": "${VERSION}"
}
EOF

# Create README
echo "Semeru JRE ${VERSION} aarch64 Linux package for Nanos VM" > "$WORKDIR/README.md"

# Create tarball
OUT="$WORKDIR/$PKG_NAME.tar.gz"
cd "$WORKDIR"
tar czf "$OUT" sysroot package.manifest README.md
sha256sum "$OUT" | tee "$OUT.sha256"
