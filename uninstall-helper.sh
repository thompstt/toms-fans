#!/bin/bash
# uninstall-helper.sh — Remove the privileged helper daemon.
# Usage: sudo ./uninstall-helper.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo:"
    echo "  sudo ./uninstall-helper.sh"
    exit 1
fi

echo "Stopping helper daemon..."
launchctl unload /Library/LaunchDaemons/com.tomsfans.helper.plist 2>/dev/null || true

echo "Removing files..."
rm -f /Library/PrivilegedHelperTools/com.tomsfans.helper
rm -f /Library/LaunchDaemons/com.tomsfans.helper.plist

echo "✅ Helper uninstalled."
