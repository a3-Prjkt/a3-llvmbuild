#!/usr/bin/env bash

set -euo pipefail

# Variable(s)
NAME="Æ3-Clang"

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

# Set a directory
DIR="$(pwd ...)"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Build LLVM
msg "Building LLVM for $NAME..."
./build-llvm.py \
	--clang-vendor "$NAME" \
	--projects "clang;lld;polly" \
	--targets "ARM;AArch64" \
	--shallow-clone \
	--incremental \
	--build-type "Release" 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
	exit 1
}

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
	strip "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

echo "Finished Building $NAME"
echo "Clang Version: $clang_version"
echo "Binutils Version: $binutils_ver"
echo "LLVM Commit: $llvm_commit_url"

# Push to GitHub
# Update Git repository
#git config --global user.name "Panchajanya1999"
#git config --global user.email "panchajanya@azure-dev.live"
#git clone "https://Panchajanya1999:$GITHUB_TOKEN@github.com/Panchajanya1999/azure-clang.git" rel_repo
#pushd rel_repo || exit
#rm -fr ./*
#cp -r ../install/* .
#git checkout README.md # keep this as it's not part of the toolchain itself
#git add .
#git commit -asm "Update to $rel_date build

#LLVM commit: $llvm_commit_url
#Clang Version: $clang_version
#Binutils version: $binutils_ver
#Builder commit: https://github.com/Panchajanya1999/tc-build/commit/$builder_commit"
#git push -f
#popd || exit
#tg_post_msg "<b>Toolchain Compilation Finished and pushed</b>"
