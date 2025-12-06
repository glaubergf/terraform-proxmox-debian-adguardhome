#!/usr/bin/env bash
set -e

echo "[+] Desabilitando systemd-resolved..."

systemctl stop systemd-resolved || true
systemctl disable systemd-resolved || true
systemctl mask systemd-resolved || true

rm -f /etc/resolv.conf

cat <<EOF >/etc/resolv.conf
# Servidor que hospeda o AdGuard Home NÃO pode usar ele mesmo como DNS.
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Proteger resolv.conf contra sobrescrita
chattr +i /etc/resolv.conf

echo "[+] resolv.conf configurado corretamente."
