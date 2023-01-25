#!/bin/sh
# ----
# File:        common/network.sh
# Description: Auxiliary functions for network management on hosts (MacOS X)
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_NETWORK_SH="1"

# ---------
# Variables
# ---------

export LINUX_HOST_IP="172.17.0.1"
export MACOS_HOST_IP="10.20.22.1"

# ---------
# Functions
# ---------

# Configure ip alias for MAC
config_ip_alias_macosx() {
  os="$(uname)"
  if [ "$os" = "Darwin" ]; then
    script="/usr/local/bin/loopback-alias"
    plist="/Library/LaunchDaemons/org.loopback.alias.plist"
    if [ ! -x "$script" ]; then
      sudo sh -c "cat > $script" <<EOF
#!/bin/sh
sudo ifconfig lo0 alias $MACOS_HOST_IP up
EOF
      sudo chmod +x "$script"
      sh "$script"
    fi
    if [ ! -f "$plist" ]; then
      sudo sh -c "cat > $plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>org.loopbak.alias</string>
  <key>RunAtLoad</key>
  <true/>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/loopback-alias</string>
  </array>
</dict>
</plist>
EOF
    fi
  fi
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
