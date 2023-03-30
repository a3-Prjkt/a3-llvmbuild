#!/usr/bin/env bash


# Install or Update Dependencies. Added no installs recommends to eliminate not necessary things
sudo apt update && sudo apt upgrade -y
sudo apt install --no-install-recommends -y \
        bc \
        bison \
        ca-certificates \
        ccache \
        clang \
        cmake \
        curl \
        file \
        flex \
        gcc \
        g++ \
        git \
        libelf-dev \
        libssl-dev \
        lld \
        make \
        ninja-build \
        python3 \
        texinfo \
        xz-utils \
        zlib1g-dev \
        patchelf

pushd ~ || exit
wget https://github.com/Kitware/CMake/releases/download/v3.26.2/cmake-3.26.2-linux-x86_64.sh
sudo sh cmake-3.26.2-linux-x86_64.sh --prefix=/usr/local --exclude-subdir
rm -rf cmake-3.26.2-linux-x86_64.sh
popd || exit

set -eo pipefail

# Variable(s)
NAME="Æ3"

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Build LLVM
msg "Building LLVM for $NAME..."
./build-llvm.py \
	--vendor-string "$NAME" \
        --defines LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 \
        --ref release/16.x \
	--projects "clang;lld;compiler-rt;polly" \
	--targets AArch64 ARM X86 \
        --pgo "kernel-defconfig" \
        --install-folder $PWD/install 2>&1 | tee build.log

# Build binutils
msg "Building binutils for $NAME..."
./build-binutils.py --targets aarch64 arm x86_64

# Remove unused products
msg "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$ORIGIN/../lib" "$bin"
done
