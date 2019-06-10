#!/bin/bash
##############################################################################
# Example command to build the android target.
##############################################################################
#
# This script shows how one can build a Caffe2 binary for the Android platform
# using android-cmake. A few notes:
#
# (1) This build also does a host build for protobuf. You will need autoconf
#     to carry out this. If autoconf is not possible, you will need to provide
#     a pre-built protoc binary that is the same version as the protobuf
#     version under third_party.
#     If you are building on Mac, you might need to install autotool and
#     libtool. The easiest way is via homebrew:
#         brew install automake
#         brew install libtool
# (2) You will need to have android ndk installed. The current script assumes
#     that you set ANDROID_NDK to the location of ndk.
# (3) The toolchain and the build target platform can be specified with the
#     cmake arguments below. For more details, check out android-cmake's doc.

set -e

CAFFE2_ROOT="$( cd "$(dirname "$0")"/.. ; pwd -P)"

echo "Bash: $(/bin/bash --version | head -1)"
echo "Caffe2 path: $CAFFE2_ROOT"

# Now, actually build the Android target.
BUILD_ROOT=${BUILD_ROOT:-"$CAFFE2_ROOT/build_ve"}
mkdir -p $BUILD_ROOT
cd $BUILD_ROOT

CMAKE_ARGS=()

# If Ninja is installed, prefer it to Make
if [ -x "$(command -v ninja)" ]; then
  CMAKE_ARGS+=("-GNinja")
fi

# # Use locally built protoc because we'll build libprotobuf for the
# # target architecture and need an exact version match.
if [ -z "$Protobuf_INSTALL_DIR" ]; then
  echo "You must set the environment variable Protobuf_INSTALL_DIR to something containing bin/protoc"
  exit 1
else
  CMAKE_ARGS+=("-DProtobuf_INSTALL_DIR=$Protobuf_INSTALL_DIR")
fi

# Snappy installation
if [ -z "$SNAPPY_ROOT_DIR" -o -z "$LEVELDB_ROOT" ]; then
  echo "Building without LevelDB - SNAPPY_ROOT_DIR or LEVELDB_ROOT not defined"
else
  CMAKE_ARGS+=("-DSNAPPY_ROOT_DIR=$SNAPPY_ROOT_DIR")
fi

# Need a cmake toolchain file configured for VE
CMAKE_ARGS+=("-DCMAKE_TOOLCHAIN_FILE=$CAFFE2_ROOT/cmake/Modules/ve.cmake")

# Don't build artifacts we don't need
CMAKE_ARGS+=("-DBUILD_BINARY=ON")
CMAKE_ARGS+=("-DBUILD_CUSTOM_PROTOBUF=OFF")
CMAKE_ARGS+=("-DBUILD_PYTHON=OFF")
CMAKE_ARGS+=("-DBUILD_BINARY=OFF")
CMAKE_ARGS+=("-DBUILD_DOCS=OFF")
CMAKE_ARGS+=("-DBUILD_SHARED_LIBS=ON")
CMAKE_ARGS+=("-DBUILD_TEST=OFF")
# Disable unused dependencies
CMAKE_ARGS+=("-DUSE_CUDA=OFF")
CMAKE_ARGS+=("-DUSE_NCCL=OFF")
CMAKE_ARGS+=("-DUSE_GFLAGS=OFF")
CMAKE_ARGS+=("-DUSE_OPENCV=OFF")
CMAKE_ARGS+=("-DUSE_LMDB=OFF")
if [ -z "$SNAPPY_ROOT_DIR" -o -z "$LEVELDB_ROOT" ]; then
  CMAKE_ARGS+=("-DUSE_LEVELDB=OFF")
else
  CMAKE_ARGS+=("-DUSE_LEVELDB=ON")
fi
CMAKE_ARGS+=("-DUSE_MPI=OFF")
CMAKE_ARGS+=("-DUSE_METAL=OFF")
CMAKE_ARGS+=("-DUSE_NUMA=OFF")
CMAKE_ARGS+=("-DUSE_GLOG=OFF")
CMAKE_ARGS+=("-DUSE_NNPACK=OFF")
CMAKE_ARGS+=("-DUSE_QNNPACK=OFF")
CMAKE_ARGS+=("-DBUILD_PYTHON=OFF")
CMAKE_ARGS+=("-DUSE_GLOO=OFF")
# CMAKE_ARGS+=("-DUSE_OPENMP=OFF")

CMAKE_ARGS+=("-DCMAKE_VERBOSE_MAKEFILE=1")

# pthreads
CMAKE_ARGS+=("-DCMAKE_THREAD_LIBS_INIT=-lpthread")
CMAKE_ARGS+=("-DCMAKE_HAVE_THREADS_LIBRARY=1")
CMAKE_ARGS+=("-DCMAKE_USE_PTHREADS_INIT=1")

# clang
if [ -z "$CC" -o -z "$CXX" ]; then
  echo "CC and CXX must be set to your C and C++ compilers, preferably clang"
  exit 1
else
  CMAKE_ARGS+=("-DCMAKE_C_COMPILER=$CC")
  CMAKE_ARGS+=("-DCMAKE_CXX_COMPILER=$CXX")
fi

# Python
CMAKE_ARGS+=("-DPYTHON_EXECUTABLE=python")

# Use-specified CMake arguments go last to allow overridding defaults
CMAKE_ARGS+=($@)

# cmake --trace-expand "$CAFFE2_ROOT" \
# cmake "$CAFFE2_ROOT" \
cmake --trace-expand \
    -DCMAKE_INSTALL_PREFIX=../install \
    -DCMAKE_BUILD_TYPE=Debug \
    "${CMAKE_ARGS[@]}" \
    "$CAFFE2_ROOT"

# Cross-platform parallel build
if [ -z "$MAX_JOBS" ]; then
  MAX_JOBS=$(nproc)
fi
# cmake --build . -- "-j${MAX_JOBS}"
cmake --build .
