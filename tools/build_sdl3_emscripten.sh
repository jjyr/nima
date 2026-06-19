#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDL_SRC="${SDL3_SRC:-$ROOT_DIR/build/sdl3-source}"
BUILD_DIR="${SDL3_EMSCRIPTEN_BUILD_DIR:-$ROOT_DIR/build/sdl3-emscripten}"
PREFIX="${SDL3_EMSCRIPTEN_PREFIX:-$ROOT_DIR/build/sdl3-emscripten-prefix}"
EM_CONFIG="${EM_CONFIG:-$ROOT_DIR/build/emscripten/.emscripten}"
EM_CACHE="${EM_CACHE:-$ROOT_DIR/build/emscripten/cache-nothreads}"
SDL_REPO="${SDL3_REPO:-https://github.com/libsdl-org/SDL.git}"
SDL_REF="${SDL3_REF:-main}"

for path in \
  /opt/homebrew/opt/python@3.14/bin \
  /usr/local/opt/python@3.14/bin \
  /opt/homebrew/opt/binaryen/bin \
  /usr/local/opt/binaryen/bin \
  /opt/homebrew/opt/lld/bin \
  /usr/local/opt/lld/bin \
  /opt/homebrew/bin \
  /usr/local/bin; do
  if [ -d "$path" ]; then
    export PATH="$path:$PATH"
  fi
done

export EM_CONFIG
export EM_CACHE
mkdir -p "$EM_CACHE"

find_tool_dir() {
  local tool="$1"
  shift
  local path
  for path in "$@"; do
    if [ -x "$path/$tool" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

prepare_llvm_root() {
  if [ -n "${EM_LLVM_ROOT:-}" ] && [ -x "$EM_LLVM_ROOT/wasm-ld" ]; then
    return 0
  fi

  local llvm_dir=""
  llvm_dir="$(find_tool_dir clang \
    /opt/homebrew/opt/llvm/bin \
    /usr/local/opt/llvm/bin \
    /opt/homebrew/bin \
    /usr/local/bin || true)"

  local lld_dir=""
  lld_dir="$(find_tool_dir wasm-ld \
    /opt/homebrew/opt/lld/bin \
    /usr/local/opt/lld/bin \
    /opt/homebrew/bin \
    /usr/local/bin || true)"

  if [ -z "$llvm_dir" ]; then
    return 0
  fi

  if [ -x "$llvm_dir/wasm-ld" ] || [ -z "$lld_dir" ]; then
    export EM_LLVM_ROOT="$llvm_dir"
    return 0
  fi

  local shim="$ROOT_DIR/build/emscripten/llvm-root"
  mkdir -p "$shim"
  local tool
  for tool in "$llvm_dir"/* "$lld_dir"/*; do
    if [ -f "$tool" ] || [ -L "$tool" ]; then
      ln -sf "$tool" "$shim/$(basename "$tool")"
    fi
  done
  export EM_LLVM_ROOT="$shim"
}

prepare_llvm_root

for path in /opt/homebrew/opt/binaryen /usr/local/opt/binaryen; do
  if [ -d "$path" ]; then
    export EM_BINARYEN_ROOT="$path"
    break
  fi
done

if ! command -v emcmake >/dev/null 2>&1; then
  echo "Required command not found: emcmake" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "Required command not found: cmake" >&2
  exit 1
fi

if [ ! -f "$EM_CONFIG" ]; then
  mkdir -p "$(dirname "$EM_CONFIG")"
  emcc --generate-config
fi

if [ ! -d "$SDL_SRC/.git" ]; then
  mkdir -p "$(dirname "$SDL_SRC")"
  git clone --depth 1 --branch "$SDL_REF" "$SDL_REPO" "$SDL_SRC"
fi

emcmake cmake -S "$SDL_SRC" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_MAKE_PROGRAM=/usr/bin/make \
  -DSDL_SHARED=OFF \
  -DSDL_STATIC=ON \
  -DSDL_TEST_LIBRARY=OFF \
  -DSDL_TESTS=OFF

cmake --build "$BUILD_DIR" --target install --config Release

cat <<EOF
SDL3 Emscripten build complete.

Use:
  export SDL3_EMSCRIPTEN_PREFIX="$PREFIX"
  NIMA_EXAMPLE=breakout nimble webExample
EOF
