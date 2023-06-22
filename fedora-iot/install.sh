#!/usr/bin/env bash

while read -r line; do
  if [[ "${line}" =~ [0-9]+ ]]; then
    percent_used="${BASH_REMATCH[0]}"
  fi
done < <(df --output=pcent /sysroot)

if [[ "${percent_used}" -gt "66" ]]; then
  echo -e "\n[FAIL] Disk usage is over 66%." 1>&2
  echo -e   "       Is the partition fully expanded?" 1>&2
  echo -e   "       Is the filesystem fully expanded?" 1>&2
  echo -e   "       Can you delete files to make space for an upgrade?" 1>&2
  exit 1
else
  echo -e "\n[INFO] Sufficient disk space exists in case service install is required."
fi

declare -A deps
deps[i2c-tools]="i2cdetect"
deps[gcc]="gcc"
deps[git]="git"
deps[make]="make"
declare -a required_pkgs

for pkg in "${!deps[@]}"; do
  which "${deps[$pkg]}" &>/dev/null || required_pkgs+=( "$pkg" )
done

if [[ "${#required_pkgs[@]}" != "0" ]]; then
  echo -e "\n[INFO] Attempting to live apply pkgs (${required_pkgs[*]})."
  rpm-ostree install -yA "${required_pkgs[@]}"
fi

for pkg in "${!deps[@]}"; do
  which "${deps[$pkg]}" &>/dev/null ||
    { echo -e "\n[FAIL] Either the live apply failed, or pkg ($pkg) is already staged." 1>&2;
      echo -e   "       If it is already staged, reboot and run script again." 1>&2;
      exit 1; }
done

while read -r line; do
  if [[ "${line}" =~ ^dtparam=i2c_arm=on ]]; then
    config_line_in_file="yes"
  fi
done < /boot/efi/config.txt

if [[ "${config_line_in_file}" != "yes" ]]; then
  echo -e "\n[INFO] Updating boot config to enable I2C; reboot required to take effect."
  echo -e   "       Once setting is applied, RPi should be able to communicate with display." 
  echo dtparam=i2c_arm=on >> /boot/efi/config.txt || exit 1
else
  echo -e "\n[INFO] I2C already enabled in RPi boot config file (/boot/efi/config.txt)."
  echo -e   "       Once setting is applied, RPi should be able to communicate with display." 
  echo -e   "       Note: Changes to file take effect at boot time; reboot may be required."
fi

if [[ "$(systemctl status adafruit-display.service &>/dev/null; echo "$?";)" == "4" ]]; then
  echo -e "\n[INFO] The adafruit-display service was not found; installing..."
  cd /root/ || exit 1
  git clone https://github.com/codrcodz/U6143_ssd1306.git;
  cd U6143_ssd1306/C/ || exit 1
  find ./ -type f -name "*\.[ohc]" -exec sed -i 's/eth0/end0/g' '{}' \;
  find ./ -type f -name "*\.[ohc]" -exec sed -i 's/ETH0/END0/g' '{}' \;
  make clean;
  make || exit 1
  cp -f /root/U6143_ssd1306/C/display /usr/local/bin/adafruit-display
  cp -f /root/U6143_ssd1306/fedora-iot/adafruit-display.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable adafruit-display.service || exit 1
  echo -e "\n[INFO] Upgrading device..."
  rpm-ostree upgrade
  echo -e "\n[INFO] Rebooting device; watch device display for IP and stats during reboot..."
  echo      "       If 0.0.0.0 is displayed instead of actual IP, source code changes required."
  systemctl reboot
else
  echo -e "\n[INFO] The adafruit-display service is already installed."
  echo -e   "       Check status with command: 'systemctl status adafruit-display.service'\n"
fi

