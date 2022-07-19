#!/usr/bin/env bash

if [[ $1 = "--clean" ]]; then
rm -rf llvm-project \
       install \
       build
fi

# Install or Update Dependencies. Added no installs recommends to eliminate not necessary things
sudo apt update && sudo apt upgrade -y
sudo apt install --no-install-recommends -y \
        bc \
        bison \
        ca-certificates \
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
	--clang-vendor "$NAME" \
        --branch release/14.x \
	--projects "clang;lld;polly" \
	--targets "ARM;AArch64" \
	--incremental 2>&1 | tee build.log 

# Build binutils
msg "Building binutils for $NAME..."
./build-binutils.py --targets arm aarch64

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
