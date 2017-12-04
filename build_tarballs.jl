using BinaryBuilder

sources = [
    "https://github.com/xianyi/OpenBLAS/archive/v0.2.20.tar.gz" =>
    "5ef38b15d9c652985774869efd548b8e3e972e1e99475c673b25537ed7bcf394",
]

script = raw"""
# We always want threading
flags="USE_THREAD=1 GEMM_MULTITHREADING_THRESHOLD=50 NO_AFFINITY=1"

# We are cross-compiling
flags="${flags} CROSS=1 HOSTCC=$CC_FOR_BUILD PREFIX=/ CROSS_SUFFIX=${target}-"

# We need to use our basic objconv, not a prefixed one:
flags="${flags} OBJCONV=objconv"

if [[ ${target} == *64-*-* ]]; then
    # If we're building for a 64-bit platform, engage ILP64
    flags="${flags} INTERFACE64=1 SYMBOLSUFFIX=64_ LIBPREFIX=libopenblas64_"
fi

# Set BINARY=32 on i686 platforms and armv7l
if [[ ${target} == i686* ]] || [[ ${target} == arm-* ]]; then
    flags="${flags} BINARY=32"
fi

# Set BINARY=64 on x86_64 platforms
if [[ ${target} == x86_64-* ]]; then
    flags="${flags} BINARY=64"
fi

# Use 16 threads unless we're on an i686 arch:
if [[ ${target} == i686* ]]; then
    flags="${flags} NUM_THREADS=8"
else
    flags="${flags} NUM_THREADS=16"
fi

# On i686 and x86_64 architectures, engage DYNAMIC_ARCH
if [[ ${target} == i686* ]] || [[ ${target} == x86_64* ]]; then
    flags="${flags} DYNAMIC_ARCH=1"
# Otherwise, engage a specific target
elif [[ ${target} == aarch64-* ]]; then
    flags="${flags} TARGET=ARMV8"
elif [[ ${target} == arm-* ]]; then
    flags="${flags} TARGET=ARMV7"
elif [[ ${target} == powerpc64le-* ]]; then
    flags="${flags} TARGET=POWER8"
fi

# Enter the fun zone
cd ${WORKSPACE}/srcdir/OpenBLAS-0.2.20/

# Build the library
make ${flags} -j${nproc}

# Install the library
make ${flags} install
"""


# Be quiet unless we've passed `--verbose`
verbose = "--verbose" in ARGS
ARGS = filter!(x -> x != "--verbose", ARGS)

# Choose which platforms to build for; if we've got an argument use that one,
# otherwise default to just building all of them!
build_platforms = supported_platforms()
if length(ARGS) > 0
    build_platforms = platform_key.(split(ARGS[1], ","))
end
info("Building for $(join(triplet.(build_platforms), ", "))")

products = prefix -> [
    LibraryProduct(prefix, ["libopenblasp-r0", "libopenblas64_p-r0"])
]

autobuild(pwd(), "OpenBLASBuilder", build_platforms, sources, script, products; verbose=verbose)
