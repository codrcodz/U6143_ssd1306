# Fedora IOT `U6143_ssd1306` Display Setup

## Usage

This README will help you run the Uctronics display script on
[Fedora IOT](https://fedoraproject.org/iot/) on the
[Raspberry Pi 4](https://docs.fedoraproject.org/en-US/quick-docs/raspberry-pi/)
connected to your Uctronics Raspberry Pi cluster rack.
The handbook that came with the rack should have directed you to this repository.

## Pre-requisites

This guide assumes that you have already:

- Installed the hat on-top of the RPi
- Connected the hat to the display on one of the rack's RPi trays
- Provided the RPi with power (via either PoE or DC adapter)
- Installed Fedora IOT onto a SD card
- Attached the RPi to the network via ethernet, (**not WiFi**)
- Placed the SD card with Fedora IOT on it, into the SD card slot on the RPi
- Successfully gained access to the RPi via SSH
- Expanded the partition of `/dev/mmcblk0p3` to 100% of free space, using `parted`
- Remounted `/sysroot` as read-write to expand the filesystem, (if required)
- Extended the filesystem of `/sysroot` to use the expanded partition, using `resize2fs`

Note: instructions for expanding the partion and filesystem are located in the Tutorial Install, if required.

## Easy Button Install

This install method is automatic, but does not explain what it is doing or why.
See the "Tutorial Install" if you want a more interactive user experience.

If you have not done so already, ensure the pre-requisites above are met.

Since `git` is not installed on fresh Fedora IOT images,
you will need download the install script manually.
Find the "raw" webpage containing the script here:

```bash
# On your local machine
firefox https://raw.githubusercontent.com/codrcodz/U6143_ssd1306/master/fedora-iot/install.sh
# Ctrl+A and Ctrl+C to copy the contents of the webpage

# On the SSH session to the RPi
cd /root/ && vi install.sh
# Shift+I to enter Insert Mode
# Shift+Ctrl+V to paste the webpage contents you previously copied
# Esc to return to Normal Mode
# :wq to write and quit the text editor
```

You do not need any other files, the script will `git clone` them for you.

Copy the contents from the browser and paste them into a file on the RPi,
then make it executable and run it as the `root` user:

```bash
# Run as root user
cd /root/ && chmod +x install.sh && ./install.sh
```

### Troubleshooting

If you have not yet expanded the /sysroot partition and filesystem,
see the relevant sections from the Tutorial Install.
The script will fail if there is insufficient space for package installs.

A reboot is performed at the end of the script to enable I2C at next boot;
otherwise, the RPi device cannot communicate with the display,
even with the I2C drivers/tools installed by the script.

## Tutorial Install

This install method is more manual and strives to explain
to the user what is going on and why they are running the commands
they are running as they do it.

### Enable I2C

```bash
echo dtparam=i2c_arm=on >> /boot/efi/config.txt
```

### Check Disk Space

Before installing build dependencies, ensure your root file system is expanded.
Doing an `rpm-ostree` install,
creates A/B boot images and requires a lot of extra space.

Some Fedora IOT install methods will expand the rootfs for you, others will not.

```bash
df -h /sysroot  # If space is low, expand the partition, otherwise: skip this section
parted   # This will drop you into the parted client shell
(parted) p   # This will print the current partitions
(parted) resizepart 3   # The rootfs is on partition 3 on Fedora IOT
Warning: Partition /dev/mmcblk0p3 is being used. Are you sure you want to continue?
Yes/No? Yes 
End?  [4295MB]? 100%   # This assigns all remaining free space to /sysroot
(parted) p   # Partition 3 should be significantly larger now
(parted) quit
```

After resizing the partition, you need to do the filesystem, but it is likely read-only.

```bash
mount -o remount,rw /sysroot
resize2fs /dev/mmcblk0p3
df -h /sysroot   # /sysroot should have a lot more free space now
rpm-ostree upgrade   # Upgrade the OS before installing anything new
systemctl reboot   # With immutable OSes like this, upgrades/installs require reboots
```

### Install Dependencies

To install the display script on Fedora IOT,
you'll first need its build and runtime dependencies.

```bash
rpm-ostree install gcc make git i2c-tools
systemctl reboot
```

### Download Library

```bash
cd /root/ && \
git clone https://github.com/UCTRONICS/U6143_ssd1306.git
```

### Compile the source code

Before compiling, all references to "eth0" or "ETH0" need to be replaced
with references to "end0" or "END0" since this is how Fedora IOT names the
wired ethernet port on Raspberry Pi.

Note: if the pi is connected via WiFi,
these instructions might still work, but are untested.
They may have to be adjusted to swap the Wifi interface's name.

```bash
cd U6143_ssd1306/C/;
find ./ -type f -name "*\.[ohc]" -exec sed -i 's/eth0/end0/g' '{}' \;
find ./ -type f -name "*\.[ohc]" -exec sed -i 's/ETH0/END0/g' '{}' \;
make clean;   # Just in case you are running this a second time
make;
```

### Test Run

```bash
cd U6143_ssd1306/C/;
./display
# Kill the process with `Ctrl+C` once you are done previewing the display
```

### Start on Boot

```bash
cp /root/U6143_ssd1306/C/display /usr/local/bin/adafruit-display
cp /root/U6143_ssd1306/C/adafruit-display.service /etc/systemd/system/
systemctl daemon-reload
systemctl start adafruit-display.service
systemctl enable adafruit-display.service
systemctl reboot   # This is just to test that it starts on boot
```
