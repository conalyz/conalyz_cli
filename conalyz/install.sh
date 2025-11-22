#!/bin/bash

# Name of your binary
BINARY_NAME="conalyz"
SRC_DIR="$(pwd)/dist"
DEST_DIR="$HOME/bin"
SHELL_PROFILE=""

# Detect shell profile
if [ -n "$ZSH_VERSION" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
    # fallback if file doesn't exist
    [ ! -f "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.bashrc"
else
    SHELL_PROFILE="$HOME/.profile"
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy binary
cp "$SRC_DIR/$BINARY_NAME" "$DEST_DIR"
chmod +x "$DEST_DIR/$BINARY_NAME"
echo "✓ $BINARY_NAME copied to $DEST_DIR"

# Add DEST_DIR to PATH if not already
if ! echo "$PATH" | grep -q "$DEST_DIR"; then
    echo "export PATH=\"$DEST_DIR:\$PATH\"" >> "$SHELL_PROFILE"
    echo "✓ Added $DEST_DIR to PATH in $SHELL_PROFILE"
else
    echo "✓ $DEST_DIR is already in PATH"
fi

echo "Installation complete! Restart your terminal or run 'source $SHELL_PROFILE' to apply PATH changes."
