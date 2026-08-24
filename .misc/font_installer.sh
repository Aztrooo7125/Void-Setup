#!/bin/sh

# -----------------------------------------------------------------------------
# Void Linux Font Setup
# -----------------------------------------------------------------------------
# Installs:
#   - Noto / CJK / Emoji
#   - DejaVu / Liberation / Cantarell
#   - Font Awesome / Nerd Font Symbols
#   - Adobe Source fonts
#   - JetBrains Mono Nerd Font
#   - Microsoft Core Fonts
#   - Carlito / Caladea
#   - Inter
#
# Safe to run repeatedly.
# -----------------------------------------------------------------------------

set -u

FONT_DIR="$HOME/.local/share/fonts"

# Temporary working directory
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# 0. Basic checks
# -----------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

mkdir -p "$FONT_DIR" \
    "$FONT_DIR/JetBrainsMono" \
    "$FONT_DIR/NerdSymbols" \
    "$FONT_DIR/Adobe" \
    "$FONT_DIR/MSCoreFonts" \
    "$FONT_DIR/MetricCompatible" \
    "$FONT_DIR/Inter"

# -----------------------------------------------------------------------------
# 1. Update system
# -----------------------------------------------------------------------------

echo
echo "==> Updating Void Linux package database..."
$SUDO xbps-install -S

echo
echo "==> Updating installed packages..."
$SUDO xbps-install -yu

# -----------------------------------------------------------------------------
# 2. Install official Void font packages
# -----------------------------------------------------------------------------

PACKAGES="
noto-fonts-ttf
noto-fonts-ttf-extra
noto-fonts-cjk
noto-fonts-emoji
dejavu-fonts-ttf
liberation-fonts-ttf
font-awesome
nerd-fonts-symbols-ttf
cantarell-fonts
cabextract
curl
unzip
"

echo
echo "==> Checking required Void packages..."

MISSING_PACKAGES=""

for pkg in $PACKAGES; do
    if xbps-query -p pkgver "$pkg" >/dev/null 2>&1; then
        printf '    ✓ %-30s installed\n' "$pkg"
    else
        printf '    + %-30s missing\n' "$pkg"
        MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
    fi
done

if [ -n "$MISSING_PACKAGES" ]; then
    echo
    echo "==> Installing missing packages..."
    # shellcheck disable=SC2086
    $SUDO xbps-install -y $MISSING_PACKAGES
else
    echo
    echo "==> All required Void packages are already installed."
fi

# -----------------------------------------------------------------------------
# 3. Download helper
# -----------------------------------------------------------------------------

download() {
    url="$1"
    output="$2"

    echo "    -> $url"

    if curl \
        --fail \
        --location \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --show-error \
        --silent \
        -o "$output" \
        "$url"
    then
        return 0
    fi

    echo "    !! Download failed: $url" >&2
    rm -f "$output"
    return 1
}

# -----------------------------------------------------------------------------
# 4. Extract font files from ZIP regardless of directory structure
# -----------------------------------------------------------------------------

extract_fonts_from_zip() {
    archive="$1"
    destination="$2"

    workdir="$TMP_DIR/extract_$(basename "$archive" .zip)"
    mkdir -p "$workdir"

    echo "    -> Extracting archive..."

    if ! unzip -q "$archive" -d "$workdir"; then
        echo "    !! Failed to extract: $archive" >&2
        rm -rf "$workdir"
        return 1
    fi

    found=0

    # Find every TTF/OTF anywhere inside the extracted archive.
    find "$workdir" -type f \
        \( -iname '*.ttf' -o -iname '*.otf' \) \
        -print |
    while IFS= read -r font; do
        found=1

        filename="$(basename "$font")"

        if cp -f "$font" "$destination/$filename"; then
            printf '       ✓ %s\n' "$filename"
        else
            echo "       !! Failed to copy $filename" >&2
        fi
    done

    rm -rf "$workdir"

    # Check destination rather than relying on the subshell's "found".
    if find "$destination" -maxdepth 1 -type f \
        \( -iname '*.ttf' -o -iname '*.otf' \) |
        grep -q .
    then
        return 0
    fi

    echo "    !! No TTF/OTF fonts found in archive." >&2
    return 1
}

# -----------------------------------------------------------------------------
# 5. Adobe Source Fonts
# -----------------------------------------------------------------------------

echo
echo "==> Installing Adobe Source fonts..."

install_adobe_font() {
    name="$1"
    url="$2"

    archive="$TMP_DIR/${name}.zip"

    echo
    echo "    [$name]"

    if ! download "$url" "$archive"; then
        echo "    !! Skipping $name"
        return 0
    fi

    if ! extract_fonts_from_zip "$archive" "$FONT_DIR/Adobe"; then
        echo "    !! Failed to install $name"
        return 0
    fi

    echo "    ✓ $name installed"
}

install_adobe_font \
    "SourceCodePro" \
    "https://github.com/adobe-fonts/source-code-pro/archive/refs/heads/release.zip"

install_adobe_font \
    "SourceSans" \
    "https://github.com/adobe-fonts/source-sans/archive/refs/heads/release.zip"

install_adobe_font \
    "SourceSerif" \
    "https://github.com/adobe-fonts/source-serif/archive/refs/heads/release.zip"

# -----------------------------------------------------------------------------
# 6. JetBrains Mono Nerd Font
# -----------------------------------------------------------------------------

echo
echo "==> Installing JetBrains Mono Nerd Font..."

JBM_ARCHIVE="$TMP_DIR/JetBrainsMono.zip"

if download \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
    "$JBM_ARCHIVE"
then
    extract_fonts_from_zip \
        "$JBM_ARCHIVE" \
        "$FONT_DIR/JetBrainsMono"
fi

# -----------------------------------------------------------------------------
# 7. Nerd Font Symbols Only
# -----------------------------------------------------------------------------

echo
echo "==> Installing Nerd Font Symbols..."

SYMBOLS_ARCHIVE="$TMP_DIR/NerdFontsSymbolsOnly.zip"

if download \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" \
    "$SYMBOLS_ARCHIVE"
then
    extract_fonts_from_zip \
        "$SYMBOLS_ARCHIVE" \
        "$FONT_DIR/NerdSymbols"
fi

# -----------------------------------------------------------------------------
# 8. Microsoft Core Fonts
# -----------------------------------------------------------------------------

echo
echo "==> Installing Microsoft Core Fonts..."

CORE_BASE="https://downloads.sourceforge.net/project/corefonts/the%20fonts/final"

CORE_FONTS="
andale32
arial32
arialb32
comic32
courie32
georgi32
impact32
times32
trebuc32
verdan32
webdin32
"

for font in $CORE_FONTS; do
    archive="$TMP_DIR/${font}.exe"

    printf '    %-12s ' "$font"

    if download \
        "$CORE_BASE/${font}.exe" \
        "$archive"
    then
        if cabextract \
            -q \
            -L \
            -d "$FONT_DIR/MSCoreFonts" \
            "$archive"
        then
            echo "✓"
        else
            echo "!! extraction failed"
        fi
    else
        echo "!! download failed"
    fi

    rm -f "$archive"
done

# -----------------------------------------------------------------------------
# 9. Carlito
# -----------------------------------------------------------------------------

echo
echo "==> Installing Carlito (Calibri-compatible)..."

CARLITO_BASE="https://raw.githubusercontent.com/google/fonts/main/ofl/carlito"

for font in \
    Carlito-Regular \
    Carlito-Bold \
    Carlito-Italic \
    Carlito-BoldItalic
do
    output="$FONT_DIR/MetricCompatible/${font}.ttf"

    if [ -f "$output" ]; then
        printf '    ✓ %s already exists\n' "$font"
        continue
    fi

    if download \
        "$CARLITO_BASE/${font}.ttf" \
        "$output"
    then
        echo "    ✓ $font"
    fi
done

# -----------------------------------------------------------------------------
# 10. Caladea
# -----------------------------------------------------------------------------

echo
echo "==> Installing Caladea (Cambria-compatible)..."

CALADEA_BASE="https://raw.githubusercontent.com/google/fonts/main/ofl/caladea"

for font in \
    Caladea-Regular \
    Caladea-Bold
do
    output="$FONT_DIR/MetricCompatible/${font}.ttf"

    if [ -f "$output" ]; then
        printf '    ✓ %s already exists\n' "$font"
        continue
    fi

    if download \
        "$CALADEA_BASE/${font}.ttf" \
        "$output"
    then
        echo "    ✓ $font"
    fi
done

# -----------------------------------------------------------------------------
# 11. Inter
# -----------------------------------------------------------------------------

echo
echo "==> Installing Inter..."

INTER_ARCHIVE="$TMP_DIR/Inter.zip"

if download \
    "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip" \
    "$INTER_ARCHIVE"
then
    extract_fonts_from_zip \
        "$INTER_ARCHIVE" \
        "$FONT_DIR/Inter"
fi

# -----------------------------------------------------------------------------
# 12. Rebuild font cache
# -----------------------------------------------------------------------------

echo
echo "==> Rebuilding font cache..."

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$FONT_DIR"
else
    echo "    !! fc-cache not found."
fi

# -----------------------------------------------------------------------------
# 13. Verify installation
# -----------------------------------------------------------------------------

echo
echo "==> Font installation summary"

font_count=$(
    find "$FONT_DIR" -type f \
        \( -iname '*.ttf' -o -iname '*.otf' \) |
    wc -l
)

echo "    Font files installed: $font_count"
echo "    Font directory:       $FONT_DIR"

echo
echo "==> Font families detected:"
fc-list : family 2>/dev/null |
    cut -d: -f1 |
    sort -u |
    grep -E \
        'Noto|DejaVu|Liberation|Cantarell|Font Awesome|JetBrains|Source|Carlito|Caladea|Inter' |
    head -80

echo
echo "==> Font setup complete."
