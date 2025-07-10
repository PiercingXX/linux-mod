#!/bin/bash

# https://github.com/Piercingxx

username=$(id -u -n 1000)

# Check if Script is Run as Root
if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user to run this script, please run sudo su then try again" 2>&1
  exit 1
fi

# Checks for active network connection
if [[ -n "$(command -v nmcli)" && "$(nmcli -t -f STATE g)" != connected ]]; then
    awk '{print}' <<< "Network connectivity is required to continue."
    exit
fi

dnf update && upgrade -y
wait

sudo dnf config-manager \
    addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo

sudo dnf install --allowerasing kernel-surface iptsd libwacom-surface -y

sudo dnf install surface-secureboot -y

sudo systemctl enable --now linux-surface-default-watchdog.path

sudo linux-surface-default-watchdog.py

