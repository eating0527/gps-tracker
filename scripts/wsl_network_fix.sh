#!/usr/bin/env bash
set -euo pipefail

# Apply WSL-specific network and sysctl tweaks to improve cloudflared reliability.
# - disable auto resolv.conf generation
# - set stable DNS (1.1.1.1, 8.8.8.8)
# - increase UDP buffer sizes used by QUIC

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "Not running under WSL; skipping WSL network tweaks."
  exit 0
fi

echo "Detected WSL. Applying DNS and sysctl tweaks (may require sudo)..."

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

echo "Writing /etc/wsl.conf to disable resolv.conf generation"
$SUDO tee /etc/wsl.conf > /dev/null <<'EOF'
[network]
generateResolvConf = false
EOF

echo "Setting resolv.conf → 1.1.1.1, 8.8.8.8"
$SUDO chattr -i /etc/resolv.conf 2>/dev/null || true
$SUDO rm -f /etc/resolv.conf 2>/dev/null || true
$SUDO tee /etc/resolv.conf > /dev/null <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
$SUDO chattr +i /etc/resolv.conf 2>/dev/null || true

echo "Tuning kernel UDP buffer sizes"
$SUDO sysctl -w net.core.rmem_max=4194304 2>/dev/null || true
$SUDO sysctl -w net.core.wmem_max=4194304 2>/dev/null || true
$SUDO sysctl -w net.core.rmem_default=262144 2>/dev/null || true
$SUDO sysctl -w net.core.wmem_default=262144 2>/dev/null || true

cat <<'EOF' | $SUDO tee /etc/sysctl.d/99-wsl-network.conf > /dev/null
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.core.rmem_default=262144
net.core.wmem_default=262144
EOF

echo "WSL network tweaks applied. Please run 'wsl --shutdown' from Windows and restart WSL for resolv.conf changes to take full effect."

exit 0
