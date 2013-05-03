% BeagleBoard Black Notes, Part 1
% Riad Wahby
% 2013 May 2

Having just picked up a couple BeagleBoard Blacks (BeagleBoards Black?)
(just BBK from now on), I immediately set about getting a running Debian
installation. Turns out, it is pretty easy.

Hardware
--

The BBK is a rather capable little beastie. <a href="http://beagleboard.org/Products/BeagleBone%20Black">BeagleBoard.org has the details</a>. Suffice it to say, you get a lot for your money.

While the procedure below should not require one, you might want to spring for a <a href="http://circuitco.com/support/index.php?title=BeagleBone_Black_Accessories#Serial_Debug_Cables">serial debug cable</a> so you can have eyes on the device during the boot process. I have a nice one from <a href="https://specialcomp.com/beaglebone/#20411">Special Computing</a> that uses the same USB Mini-B cable and is 3.3/5V selectable. Alternatively, the <a href="http://www.adafruit.com/products/954">Adafruit USB to TTL serial cable</a> is really nice because of the pinout flexibility.

You can power the device exclusively from USB, but it's handier if you've got an <a href="http://circuitco.com/support/index.php?title=BeagleBone_Black_Accessories#5VDC_Power_Supplies">external supply</a> so that you can pull the USB connectors on the fly without losing power.

I managed to pick up this <a href="http://www.frys.com/product/7593456">16 GB Samsung UHS-1 card</a> from Fry's for $11. Of course, you're free to substitute as you prefer, but given how cheap they are, I would recommend at least an 8 GB card.

You will probably also want a way to communicate with the microSD card. I have a built-in SD reader, so I just picked up a cheap microSD adapter (sadly, the Samsung cards come without); you could also pick up a cheap USB microSD reader. In any case, you will need a way to write the initial image to the microSD card.

Initial Debian image
--

The <a href="http://elinux.org/BeagleBoardDebian">eLinux.org BeagleBoard Debian entry</a> has a week-old (as of this writing) Debian Wheezy testing image ready to be installed on your SD card. (I have <a href="files/debian-wheezy-console-armhf-2013-04-26.tar.xz">a local mirror</a> available as well, checksum 8a1c4ff53f3b2a42419ee1c7c1f47e40.)

From an appropriate directory,
    
    wget http://github.jfet.org/files/debian-wheezy-console-armhf-2013-04-26.tar.xz
    tar xJvf debian-wheezy-console-armhf-2013-04-26.tar.xz
    cd debian-wheezy-console-armhf-2013-04-26
    sudo ./setup_sdcard.sh --mmc /dev/mmcblk0_CHECK_THIS_PATH --uboot bone_dtb --rootfs ext4 --swap_file 2048

Note the final command: you'll need to update the `--mmc` argument with the correct device for your system, and you should probably check that the swapfile isn't too big for your microSD card.

First boot
--

Insert the microSD card, connect your serial console cable (if applicable), plug in Ethernet, and off you go. If you control the DHCP server, you should be able to figure out what IP was assigned to the device; otherwise, you'll have to guess or use the debug console to figure it out. I'll assume you can get there somehow; now you can login via ssh with something like

    ssh root@10.0.0.1

(hint: the default password is `root`.) We have a few goals. First, let's make sure we're up-to-date:

    apt-get update
    apt-get dist-upgrade

(You will immediately notice that this process is not altogether fast.) When you do this, you will probably get an error when debian goes to run `update-initramfs`. No problem: 

    update-initramfs -c -k $(uname -r)
    cd /boot
    cp uboot/initrd.img initrd.img.old
    cp initrd.img-$(uname -r) uboot/initrd.img

USB Gadgets
--

By default, the image we're using doesn't enable USB gadgets at boot. With the following changes, the device will install all the gadgets, including

* USB ethernet with static IP address
* USB serial (`cdc_acm` driver), enabling serial console
* USB storage exporting the internal 2 GB memory

First, we will configure the USB ethernet device. Open `/etc/network/interfaces` in your favorite text editor, and add the following:

    auto usb0
    iface usb0 inet static
        address 172.17.0.1
        netmask 255.255.0.0

This will configure the USB virtual ethernet adapter with the static address 172.17.0.1 at boot.

Next, let's get the settings in place for the serial console. First up, we'll add the following to `/etc/inittab`

    T1:23:respawn:/sbin/getty -L ttyGS0 115200 linux

This tells `init` to start a serial login on `ttyGS0` in runlevels 2 and 3, and always respawn it. To enable root logins on this console, you will need to add `ttyGS0` to `/etc/securetty`, again using your favorite text editor.

Finally, we will configure the system to install the `g_multi` module at startup and export the internal 2 GB memory. Add the following to `/etc/modules`:

    g_multi file=/dev/mmcblk1p2

If you have completed all of the above, you can test it before rebooting with

    modprobe g_multi file=/dev/mmcblk1p2
    telinit q
    ifup usb0

Now, connect your computer to the onboard USB mini-B port. After things settle down, in the *host computer* dmesg output you should see something like:

    usb 1-3: new high-speed USB device number 21 using ehci_hcd
    usb 1-3: New USB device found, idVendor=1d6b, idProduct=0104
    usb 1-3: New USB device strings: Mfr=2, Product=3, SerialNumber=0
    usb 1-3: Product: Multifunction Composite Gadget
    usb 1-3: Manufacturer: Linux 3.8.8-bone14 with musb-hdrc
    rndis_host 1-3:1.0: usb0: register 'rndis_host' at usb-0000:00:1a.7-3, RNDIS device, 66:9b:cd:ab:b6:5d
    cdc_acm 1-3:1.2: This device cannot do calls on its own. It is not a modem.
    cdc_acm 1-3:1.2: ttyACM0: USB ACM device
    scsi9 : usb-storage 1-3:1.4
    scsi 9:0:0:0: Direct-Access     Linux    File-CD Gadget   0308 PQ: 0 ANSI: 2
    sd 9:0:0:0: Attached scsi generic sg2 type 0
    3598560 512-byte logical blocks: (1.84 GB/1.71 GiB)
    Write Protect is off
    Mode Sense: 0f 00 00 00
    Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
      sdb: unknown partition table
    Attached SCSI disk
    usb0: no IPv6 routers present

Now, on the host machine, you should be able to:

    mount /dev/sdb /mnt/ext
    ls /mnt/ext

and

    ifconfig usb0 172.17.0.2 netmask 255.255.0.0
    ssh root@172.17.0.1

and

    screen /dev/ttyACM0 115200

If all of this works, go ahead and reboot your device and double check that everything comes up as expected. Oh yeah, you might want to edit `/etc/hostname` first.

Other software
--

This is a list of some other stuff I've installed. Compiling the Gambit scheme with the `--enable-single-host` and `--enable-gcc-opts` switches takes a *seriously* long time, but the result is a compiler that generates substantially faster executables. It's probably worth it. Might not hurt to give `CFLAGS="-mfloat-abi=hard"` to the `configure` script, either.

* gcc
* make
* strace
* latrace
* libreadline6-dev
* <a href="http://gambitscheme.org/">gambit scheme</a>
* <a href="http://github.com/kwantam/lviv/">lviv</a>
* octave

