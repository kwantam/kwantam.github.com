% Cross Bootstrapping Rust
% Riad Wahby (kwantam)
% 2014 June 23

I have a Nexus7 with a linux chroot environment that I use as a really
compact laptop. Recently I wanted to play with Rust on the go, but
unfortunately there are neither [nightlies](http://www.rust-lang.org/install.html)
nor a stage0 bootstrap available. So we have to do this ourselves.

If you're just looking for a relatively recent `rustc` for
`arm-unknown-linux-gnueabihf` (e.g., Debian armhf) and don't want to go
through all this yourself, you can just download a binary tarball (most recent listed first):

- [rust_arm-unknown-linux-gnueabihf_dist_20140630.tbz2](files/rust_arm-unknown-linux-gnueabihf_dist_20140630.tbz2)
- [rust_arm-unknown-linux-gnueabihf_dist_20140623.tbz2](files/rust_arm-unknown-linux-gnueabihf_dist_20140623.tbz2)

## Problems to be solved ##

In an ideal world, the Rust build system (RBS) would be able to cross-bootstrap,
but at least for now, this is a bit broken:

1. When Rust is configured with `--host` and `--target` set to `arm-unknown-linux-gnueabihf`,
   it incorrectly passes the `--build=arm-unknown-linux-gnueabihf` switch
   to the LLVM configure script.

2. Even if the RBS had passed the correct switches to LLVM (`--host` and
   `--target`, but not `--build`), the build system relies upon the 
   `llvm-config` binary to provide information about the LLVM build, and
   the location the RBS uses for the binary will have been built for the
   cross architecture rather than the build architecture.

3. It's not possible to supply the RBS with different `--llvm-root`
   switches for multiple architectures.

4. By default, architectures that aren't passed in the `--host` switch
   end up without the necessary Make targets to build `librustllvm` and
   `librustc`.

5. When RBS generates `llvmdeps.rs`, it produces a restrictive `#[cfg]`
   directive that keeps the cross librustc from being linked to the LLVM
   libraries.

## Plan of action ##

Here's the plan:

1. Build LLVM out of tree for both the build architecture (I am using
   `x86_64-unknown-linux-gnu`) and the cross architecture
   (`arm-unknown-linux-gnueabihf`).

2. Tweak the RBS slightly to use our LLVM builds.

3. Modify the RBS a little more to build working versions of all crates
   for all targets rather than just for the host system.

4. Build the host binaries and host and cross libraries.

5. Build the cross binaries.

## First steps ##

First, to make sure we are on the same page, we will do a clean Rust clone:

    mkdir -p $HOME/toolchains/src
    cd $HOME/toolchains/src
    git clone https://github.com/mozilla/rust.git
    cd rust
    git submodule update --init

Also, you will need a working gcc (4.7 or later; LLVM requires C++11
support) cross toolchain for your cross architecture, including g++ and
libstdc++. Debian-ish users looking to build for ARM should be able to
get this from [emdebian.org](http://emdebian.org), or you can 
[build your own](http://emdebian.org/tools/crossdev.html). Of course,
you will need all of the standard Rust prerequisites as well: python
(2.6 or 2.7), perl, make 3.81 or later, and curl.

## Configuring Rust ##

    cd $HOME/toolchains/src/rust
    mkdir build
    cd build
    mkdir -p $HOME/toolchains/var/lib
    mkdir $HOME/toolchains/etc
    $PWD/../configure --prefix=$HOME/toolchains                       \
        --host=x86_64-unknown-linux-gnu --disable-llvm-assertions     \
        --target=x86_64-unknown-linux-gnu,arm-unknown-linux-gnueabihf \
        --localstatedir=$HOME/toolchains/var/lib                      \
        --sysconfdir=$HOME/toolchains/etc
    cd x86_64-unknown-linux-gnu
    find . -type d -exec mkdir -p ../arm-unknown-linux-gnueabihf/\{\} \;

(Of course, feel free to modify `--prefix`, `--localstatedir`, and
`--sysconfdir` as appropriate for your system.)

The last command makes sure that we have prepared the same directory
structure under the cross directory as under the build directory. (I
think we only really need `llvm/`, `rt/`, and `rustllvm/`, though.)

## Building cross LLVM ##

librustc needs to be linked against LLVM. In a cross build, these
libraries have to be for the cross architecture (in our case,
`arm-unknown-linux-gnueabihf`). We will also need LLVM for the build
architecture. Because of problem #1, we will do this manually.

    cd $HOME/toolchains/src/rust/build/x86_64-unknown-linux-gnu/llvm
    $HOME/toolchains/src/rust/src/llvm/configure --enable-target=x86,x86_64,arm,mips  \
        --enable-optimized --disable-assertions --disable-docs --enable-bindings=none \
        --disable-terminfo --disable-zlib --disable-libffi                            \
        --with-python=/usr/bin/python2.7
    make -j$(nproc)
    # (...this will take a while...)
    cd $HOME/toolchains/src/rust/build/arm-unknown-linux-gnueabihf/llvm
    $HOME/toolchains/src/rust/src/llvm/configure --enable-target=x86,x86_64,arm,mips  \
        --enable-optimized --disable-assertions --disable-docs --enable-bindings=none \
        --disable-terminfo --disable-zlib --disable-libffi                            \
        --with-python=/usr/bin/python2.7 --build=x86_64-unknown-linux-gnu             \
        --host=arm-unknown-linux-gnueabihf --target=arm-unknown-linux-gnueabihf
    make -j$(nproc)
    # (...again, a bit of a wait...)

(I use `-j$(nproc)` above to parallelize the build as much as possible,
but if your machine has limited RAM this might cause issues; feel free
to just `make` instead.)

### Enable `llvm-config` for the cross LLVM build ###

Recall problem #2, above: Rust will try to execute `llvm-config`
for each architecture, but in the cross LLVM the binary is built for
the cross architecture rather than ours. Fortunately, LLVM also builds a
version of the binary that runs locally, so we just have to put it in
the right place:

    cd $HOME/toolchains/src/rust/build/arm-unknown-linux-gnueabihf/llvm/Release/bin
    mv llvm-config llvm-config-arm
    ln -s ../../BuildTools/Release/bin/llvm-config .
    # (Now test to be sure this works.)
    ./llvm-config --cxxflags
    # (You should see some CXX flags printed out here!)

### Making RBS use our LLVM builds ###

Ideally, we'd be able to tell the Rust build system that we've done LLVM
building ourselves and that's that, and when compiling for a single
architecture that's possible, but sadly there is no way to tell it to
use one LLVM for x86 and another for ARM (problem #3); that's why we
didn't use the `--llvm-root` switch to the Rust configure script.
Instead, we'll manually tweak the configuration and hack the
LLVM-related makefile slightly.

First, we add a couple definitions to `config.mk` telling RBS where to
look for LLVM for each architecture:

    cd $HOME/toolchains/src/rust/build/
    chmod 0644 config.mk
    grep 'CFG_LLVM_[BI]' config.mk |                                          \
        sed 's/x86_64\(.\)unknown.linux.gnu/arm\1unknown\1linux\1gnueabihf/g' \
        >> config.mk

We also want to be sure that Rust doesn't clean or rebuild these for us
under any circumstances:

    cd $HOME/toolchains/src/rust
    sed -i.bak 's/\([\t]*\)\(.*\$(MAKE).*\)/\1#\2/' mk/llvm.mk

## Building a working librustc for the cross architecture ##

Finally, we have to modify the Rust build system so that it has the
necessary targets to build all crates for the cross architecture,
(problem #4). To do this, we modify another few Makefiles:

    cd $HOME/toolchains/src/rust
    sed -i.bak                                                                         \
        's/^CRATES := .*/TARGET_CRATES += $(HOST_CRATES)\nCRATES := $(TARGET_CRATES)/' \
        mk/crates.mk
    sed -i.bak                                                                                        \
        's/\(.*call DEF_LLVM_VARS.*\)/\1\n$(eval $(call DEF_LLVM_VARS,arm-unknown-linux-gnueabihf))/' \
        mk/main.mk
    sed -i.bak 's/foreach host,$(CFG_HOST)/foreach host,$(CFG_TARGET)/' mk/rustllvm.mk

One last thing: before librustc is built, library dependencies are
generated using `src/etc/mklldeps.py`, but the `#[cfg]` directive it
generates is too restrictive for our purposes (problem #5). As a result,
librustc for the cross architecture will not be linked to the LLVM libs.

In this example, our targets are similar enough that llvm-config returns
the same set of library dependencies for both. Depending on your host
and cross architectures, this might not be the case. Since we are an
easy case, we can make one quick change to `mklldeps.py` that enables
correct linking:

    cd $HOME/toolchains/src/rust
    sed -i.bak 's/.*target_arch = .*//' src/etc/mklldeps.py

If you want to verify that this is sufficient for your case, you
can compare the output from the respective `llvm-config`
executables like so:

    cd $HOME/toolchains/src/rust/build
    arm-unknown-linux-gnueabihf/llvm/Release/bin/llvm-config --libs \
        | tr '-' '\n' | sort > arm
    x86_64-unknown-linux-gnu/llvm/Release/bin/llvm-config --libs \
        | tr '-' '\n' | sort > x86
    diff arm x86

Also note that the cross `llvm-config` binary nevertheless reports `x86_64-unknown-linux-gnu`
when invoked with the `--host-target` switch, so if you need to roll
your own modification to `mklldeps.py`, keep this in mind.

## Build it, part 1 ##

We're finally ready to build!

    cd $HOME/toolchains/src/rust/build
    make -j4

(Again, note that I'm using `-j4` here; on a machine with less than 8Gb
of RAM, you probably don't want to do this because you risk heavy
swapping and/or OOM kills---rustc takes a lot of memory!)

## Build it, part 2 ##

One last thing: we have to actually produce the `rustc` and `rustdoc`
binaries for our cross architecture

    cd $HOME/toolchains/src/rust/build
    LD_LIBRARY_PATH=$PWD/x86_64-unknown-linux-gnu/stage2/lib/rustlib/arm-unknown-linux-gnueabihf/lib:$LD_LIBRARY_PATH \
        ./x86_64-unknown-linux-gnu/stage2/bin/rustc --cfg stage2 -O --cfg rtopt                                       \
        -C linker=arm-linux-gnueabihf-g++ -C ar=arm-linux-gnueabihf-ar -C target-feature=+v6,+vfp2                    \
        --cfg debug -C prefer-dynamic --target=arm-unknown-linux-gnueabihf                                            \
        -o x86_64-unknown-linux-gnu/stage2/lib/rustlib/arm-unknown-linux-gnueabihf/bin/rustc --cfg rustc              \
        $PWD/../src/driver/driver.rs
    LD_LIBRARY_PATH=$PWD/x86_64-unknown-linux-gnu/stage2/lib/rustlib/arm-unknown-linux-gnueabihf/lib:$LD_LIBRARY_PATH \
        ./x86_64-unknown-linux-gnu/stage2/bin/rustc --cfg stage2 -O --cfg rtopt                                       \
        -C linker=arm-linux-gnueabihf-g++ -C ar=arm-linux-gnueabihf-ar -C target-feature=+v6,+vfp2                    \
        --cfg debug -C prefer-dynamic --target=arm-unknown-linux-gnueabihf                                            \
        -o x86_64-unknown-linux-gnu/stage2/lib/rustlib/arm-unknown-linux-gnueabihf/bin/rustdoc --cfg rustdoc          \
        $PWD/../src/driver/driver.rs

We've now bootstrapped a rust compiler for the cross architecture. Let's tar it up:

    cd $HOME/toolchains/src/rust/build/
    mkdir -p cross-dist/lib/rustlib/arm-unknown-linux-gnueabihf
    cd cross-dist
    cp -R ../x86_64-unknown-linux-gnu/stage2/lib/rustlib/arm-unknown-linux-gnueabihf/* \
        lib/rustlib/arm-unknown-linux-gnueabihf
    mv lib/rustlib/arm-unknown-linux-gnueabihf/bin .
    cd lib
    for i in rustlib/arm-unknown-linux-gnueabihf/lib/*.so; do ln -s $i .; done
    cd ../
    tar cjf ../rust_arm-unknown-linux-gnueabihf_dist.tbz2 .

Hooray!
