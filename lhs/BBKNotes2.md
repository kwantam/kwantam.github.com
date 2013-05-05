% BeagleBone Black Notes, Part 2
% Riad Wahby
% 2013 May 4

Continuing from our <a href="BBKNotes1.html">previous session</a>, it's time to continue hacking.

USB network bridge
--

A quick couple scripts so we can bridge network through the USB interface.

On the host machine, we create `/usr/local/src/usbnet_gate` like so:

    #!/bin/bash
    
    case "$1" in
    
    up)
        ifconfig usb0 172.17.0.254 netmask 255.255.0.0
        iptables -F
        iptables -t nat -F
        iptables -t mangle -F
        iptables -X
        iptables -t nat -X
        iptables -t mangle -X
    
        iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
        iptables -A FORWARD -i usb0 -j ACCEPT
    
        echo 1 > /proc/sys/net/ipv4/ip_forward
    
        if ( ifconfig wlan0 | grep -q DOWN ); then
            echo "Don't forget to put up the wlan0 interface!"
        fi
        ;;
    
    down)
        iptables -F
        iptables -t nat -F
        iptables -t mangle -F
        
        iptables -X
        iptables -t nat -X
        iptables -t mangle -X
        ifconfig eth0 down
        ;;
    
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
    
    esac
    
    exit 0

On the target board, `/usr/local/src/usbnet_route` looks like this:

    #!/bin/bash
    
    case "$1" in
    
    up)
    
        # fix routing table
        for i in $(route -n | grep UG | sed 's/  */,/g'); do
            $(echo $i | awk -F , '{print("route del -net",$1,"netmask",$3,"gw",$2);}');
        done
    
        route add default gw 172.17.0.254
        ;;
    
    down)
    
        # fix routing table
        for i in $(route -n | grep UG | sed 's/  */,/g'); do
            $(echo $i | awk -F , '{print("route del -net",$1,"netmask",$3,"gw",$2);}');
        done
        ;;
    
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
    
    esac
    
    exit 0
    
If you don't regularly connect an ethernet cable to your BBK at boot, you could run this script automatically by adding

    post-up /usr/local/src/usbnet_route up

in the `usb0` stanza in `/etc/network/interfaces`. Otherwise, just go in via serial or SSH and enable it.

PRU access under Wheezy
--

One of the coolest features of the AM335x SOC on the BBK is the pair of Programmable Realtime Units (PRUs), 200 MHz RISC cores that run independently of the ARM core and with access to GPIO, peripherals, private memory, and system memory. These are *really* cool for making high-speed hardware interfaces or communications busses.

More background info on the PRUs is available from

* <a href="http://elinux.org/ECE497_BeagleBone_PRU">ECE497 BeagleBone PRU</a> at elinux.org
* <a href="http://blog.boxysean.com/2012/08/12/first-steps-with-the-beaglebone-pru/">First Steps with the BeagleBone PRU</a> courtesy of boxysean
* <a href="https://github.com/beagleboard/am335x_pru_package">`am335x_pru_package`</a> from the BeagleBoard.org team
* <a href="https://github.com/boxysean/am335x_pru_package">boxysean's fork of `am335x_pru_package`</a>

The first goal is to get the latter package working with the Debian Wheezy image we installed last time. Grabbing the `am335x_pru_package`, we follow the build process that boxysean describes (see the "First Steps" link above). If you grab boxysean's fork of the package you get a couple LED blinking tests as well.

Sadly, it doesn't work right out of the box: once we're ready to run the test code, it turns out that the uio\_pruss module shipped with our image apparently doesn't work right.

    INFO: Starting PRU_memAccessPRUDataRam example.
    prussdrv_open open failed

A little `strace`ing reveals the problem:

    open("/dev/uio0", O_RDWR|O_SYNC)        = -1 ENODEV (No such device)
    open("/sys/class/uio/uio0/maps/map0/addr", O_RDONLY) = -1 ENOENT (No such file or directory)

Apparently something about the uio implementation is broken. Let's see if we can't figure out what.

My first inclination is to investigate how it works with the default &#8491;ngstrom image (aren't you glad we kept our install on a microSD card? I am!).

Updating the eMMC from Debian (but not really)
--

First things first: you should be sure your &#8491;ngstrom image is up-to-date.

After looking into it, it turns out that my board already has the <a href="https://s3.amazonaws.com/angstrom/demo/beaglebone/Angstrom-Cloud9-IDE-GNOME-eglibc-ipk-v2012.12-beaglebone-2013.04.13.img.xz">latest image</a>. However, before figuring this out, I set about coming up with a way to update the onboard &#8491;ngstrom image directly from our Debian install. I've recorded it here for posterity.

1. On the *target board*, download the latest image:

        cd /usr/local/src
        wget https://s3.amazonaws.com/angstrom/demo/beaglebone/Angstrom-Cloud9-IDE-GNOME-eglibc-ipk-v2012.12-beaglebone-2013.04.13.img.xz

    Note: if `wget` complains about certificates, it's probably because the date on your machine isn't set. `ntpdate -s time.mit.edu` will fix you right up.

2. Decompress it:

        xz -d Angstrom-Cloud9-IDE-GNOME-eglibc-ipk-v2012.12-beaglebone-2013.04.13.img.xz

3. Now we have an .img file that's actually a disk with a partition table and two partitions. Using `fdisk` we can see that the two partitions start at offsets 63 and 144585, both expressed in units of 512 bytes. With this information, we can mount the partitions like so (note the offset we provide is 144585\*512):

        mkdir -p /mnt/Afiles
        mount -o loop,offset=74027520 BBB-eMMC-flasher-2013.04.13-DDR3-400MHz.img /mnt/Afiles

4. In `/mnt/Afiles/build` we find the actual scripts that are used to flash the drive. Simply running `emmc.sh` should perform the update. Since I haven't actually done this, your mileage may vary.

Getting the PRUSS working
--

I booted the &#8491;ngstrom system expecting things to work, but no love here. `modprobe uio_pruss` still resulted in an empty `/sys/class/uio` directory!

A little more research turned up this thread, <a href="https://groups.google.com/forum/?fromgroups=#!topic/beagleboard/gqCjxh4uZi0">How to reliably activate PRUSS on beaglebone?</a> (from today!). Apparently there are some troubles with PRUSS under 3.8 kernels; until they're fixed, we can use Jacek Radzikowski's magical hack. Create `/usr/local/src/pruss_magic_jr`, like so:

    #!/bin/bash
    
    progress_and_delay () {
        echo -n "."
        sleep 1
    }
    
    SLOTS=/sys/devices/bone_capemgr.*/slots
    
    echo -n "Installing uio_pruss module ."
    
    /sbin/modprobe uio_pruss
    progress_and_delay
    
    rmmod uio_pruss
    progress_and_delay
    
    echo cape-bone-nixie > $SLOTS
    progress_and_delay
    
    /sbin/modprobe uio_pruss
    progress_and_delay
    
    echo cape-bone-nixie > $SLOTS
    progress_and_delay
    
    rmmod uio_pruss
    progress_and_delay
    
    /sbin/modprobe uio_pruss
    progress_and_delay
    
    ( [ -L /sys/class/uio/uio0 ] || [ -d /sys/class/uio/uio0 ] ) && echo ' Success!' && exit 0
    
    # shouldn't get here if things worked
    echo 'Failed.'
    exit 1;

After executing this, the PRUs work!

    [root@charm]# ls /sys/class/uio/uio0/
    total 0
    drwxr-xr-x  4 root root    0 Jan  1 00:09 .
    drwxr-xr-x 10 root root    0 Jan  1 00:09 ..
    -r--r--r--  1 root root 4096 Jan  1 00:22 dev
    lrwxrwxrwx  1 root root    0 Jan  1 00:22 device -> ../../../4a300000.pruss
    -r--r--r--  1 root root 4096 Jan  1 00:22 event
    drwxr-xr-x  4 root root    0 Jan  1 00:22 maps
    -r--r--r--  1 root root 4096 Jan  1 00:22 name
    drwxr-xr-x  2 root root    0 Jan  1 00:22 power
    lrwxrwxrwx  1 root root    0 Jan  1 00:09 subsystem -> ../../../../../class/uio
    -rw-r--r--  1 root root 4096 Jan  1 00:09 uevent
    -r--r--r--  1 root root 4096 Jan  1 00:22 version
    [root@charm]# ./PRU_PRUtoPRU_Interrupt 
    
    INFO: Starting PRU_PRUtoPRU_Interrupt example.
    AM33XX
    AM33XX
            INFO: Initializing example.
            INFO: Executing example on PRU0.
    File ./PRU_PRU0toPRU1_Interrupt.bin open passed
                    INFO: Executing example on PRU1.
    File ./PRU_PRU1toPRU0_Interrupt.bin open passed
            INFO: Waiting for HALT command.
            INFO: PRU0 completed transfer.
                    INFO: Waiting for HALT command.
                    INFO: PRU1 completed transfer.
    Example executed succesfully.

Well, that's all the time I've got today. My goal in the near term is to use the PRUSS to do high-speed data capture and waveform generation. After that, I hope to wrap the whole thing in a nice web interface so that we can use the board as a pattern generator / logic capture card via a web browser.

Stay tuned!

