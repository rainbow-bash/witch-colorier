#!/usr/bin/env bash
set -eu

# OUT_DIR is for everything except the exe. The exe needs to stay in root
# folder so it sees the assets folder, without having to copy it.
OUT_DIR=build/hot_reload

mkdir -p $OUT_DIR

# root is a special command of the odin compiler that tells you where the Odin
# compiler is located.
ROOT=$(odin root)

# Figure out which DLL extension to use based on platform. Also copy the Linux
# so libs.
case $(uname) in
"Darwin")
    DLL_EXT=".dylib"
    EXTRA_LINKER_FLAGS="-Wl,-rpath $ROOT/vendor/raylib/macos"
    ;;
*)
    DLL_EXT=".so"
    EXTRA_LINKER_FLAGS="'-Wl,-rpath=\$ORIGIN/linux'"

    # Copy the linux libraries into the project automatically.
    if [ ! -d "$OUT_DIR/linux" ]; then
        mkdir -p $OUT_DIR/linux
        cp -r $ROOT/vendor/raylib/linux/libraylib*.so* $OUT_DIR/linux
    fi
    ;;
esac

# Build the game. Note that the game goes into $OUT_DIR while the exe stays in
# the root folder.
odin build source -extra-linker-flags:"$EXTRA_LINKER_FLAGS" -define:RAYLIB_SHARED=true -build-mode:dll -out:$OUT_DIR/compiled_game_tmp$DLL_EXT -strict-style -vet -debug -error-pos-style:unix
