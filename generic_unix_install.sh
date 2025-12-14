#!/bin/bash
if command -v doas >> /dev/null; then
  root=doas
else 
  root=sudo
fi

# Ensure cargo is installed before trying to proceed
if ! command -v cargo > /dev/null 2>&1; then
    echo "cargo command is not installed. Cannot proceed. Please ensure cargo is installed and on the PATH"
    exit 1
fi

cargo build --release

BLISP_VERSION="v0.0.5"
BLISP_TEMP_DIR=$(mktemp -d)
trap "rm -rf $BLISP_TEMP_DIR" EXIT

if [ "$(uname)" == "Darwin" ]; then
  # macOS - universal binary supports both Intel and Apple Silicon
  echo "Downloading blisp ${BLISP_VERSION} for macOS..."
  curl -L "https://github.com/pine64/blisp/releases/download/${BLISP_VERSION}/blisp-apple-universal.zip" -o "${BLISP_TEMP_DIR}/blisp.zip"
  unzip -o "${BLISP_TEMP_DIR}/blisp.zip" -d "${BLISP_TEMP_DIR}"
  chmod +x "${BLISP_TEMP_DIR}/blisp"
  $root cp "${BLISP_TEMP_DIR}/blisp" /usr/local/bin/blisp
  $root chmod +x /usr/local/bin/blisp
  $root cp ./target/release/pineflash /usr/local/bin/
elif [ "$(uname)" == "Linux" ]; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)
      BLISP_ARCH="x86_64"
      ;;
    aarch64)
      BLISP_ARCH="aarch64"
      ;;
    armv7l)
      BLISP_ARCH="armv7"
      ;;
    riscv64)
      BLISP_ARCH="riscv64"
      ;;
    *)
      echo "No prebuilt blisp binary for architecture: $ARCH"
      echo "Building from source..."
      BLISP_ARCH=""
      ;;
  esac

  if [ -n "$BLISP_ARCH" ]; then
    echo "Downloading blisp ${BLISP_VERSION} for Linux ${BLISP_ARCH}..."
    curl -L "https://github.com/pine64/blisp/releases/download/${BLISP_VERSION}/blisp-linux-${BLISP_ARCH}.zip" -o "${BLISP_TEMP_DIR}/blisp.zip"
    unzip -o "${BLISP_TEMP_DIR}/blisp.zip" -d "${BLISP_TEMP_DIR}"
    $root cp "${BLISP_TEMP_DIR}/blisp" /usr/local/bin/blisp
    $root chmod +x /usr/local/bin/blisp
  else
    # Build from source for unsupported architectures
    echo "Building blisp ${BLISP_VERSION} from source..."
    BLISP_BUILD_DIR="${BLISP_TEMP_DIR}/blisp-src"
    git clone --recursive "https://github.com/pine64/blisp.git" "${BLISP_BUILD_DIR}"
    cd "${BLISP_BUILD_DIR}"
    git checkout "${BLISP_VERSION}"
    git submodule update --init --recursive
    mkdir -p build && cd build
    cmake -DBLISP_BUILD_CLI=ON ..
    cmake --build .
    $root cp ./tools/blisp/blisp /usr/local/bin/blisp
    $root chmod +x /usr/local/bin/blisp
    cd "${OLDPWD}"
  fi

  $root cp ./assets/Pineflash.desktop /usr/share/applications/Pineflash.desktop
  $root cp ./assets/pine64logo.png /usr/share/pixmaps/pine64logo.png
  $root cp ./target/release/pineflash /usr/bin/pineflash
else
  echo "Unsupported operating system: $(uname)"
  exit 1
fi
