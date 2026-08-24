#!/bin/sh
# Docker entrypoint for automaton - ensures HOME is set correctly

# Ensure HOME is set for the automaton user
export HOME=${HOME:-/home/automaton}

# Debug: print environment
echo "=== Automaton Entrypoint ==="
echo "USER: $(whoami)"
echo "UID: $(id -u)"
echo "HOME: $HOME"
echo "PWD: $PWD"

# Ensure .automaton directory exists and is writable
mkdir -p "$HOME/.automaton"
chmod 700 "$HOME/.automaton" 2>/dev/null || true

# CRITICAL: Create symlink as root using su-exec or similar
# Since we're running as automaton user, we need to create the symlink differently
# The symlink /root/.automaton -> /home/automaton/.automaton should be created by root
# But we're running as automaton user. Let's check if it exists and create if needed.
if [ ! -L /root/.automaton ]; then
    echo "Creating symlink /root/.automaton -> $HOME/.automaton"
    # Try to create as current user (might fail if /root not writable)
    ln -sf "$HOME/.automaton" /root/.automaton 2>/dev/null || {
        echo "Could not create symlink as automaton user, trying alternative..."
        # Create directory structure that satisfies both paths
        mkdir -p /root/.automaton
        # Copy files if needed
        cp -r "$HOME/.automaton"/* /root/.automaton/ 2>/dev/null || true
    }
fi

# Verify
if [ -L /root/.automaton ]; then
    echo "Symlink /root/.automaton -> $(readlink /root/.automaton) exists"
elif [ -d /root/.automaton ]; then
    echo "Directory /root/.automaton exists (fallback)"
else
    echo "WARNING: /root/.automaton not accessible!"
fi

# Debug: print environment
echo "=== Automaton Entrypoint ==="
echo "USER: $(whoami)"
echo "UID: $(id -u)"
echo "HOME: $HOME"
echo "PWD: $PWD"

# Ensure .automaton directory exists and is writable
mkdir -p "$HOME/.automaton"
chmod 700 "$HOME/.automaton" 2>/dev/null || true

# Debug: show what Node.js will see
echo "=== Node.js environment preview ==="
node -e "console.log('NODE HOME:', process.env.HOME); console.log('NODE UID:', process.getuid())"

# Execute the main command
exec "$@"