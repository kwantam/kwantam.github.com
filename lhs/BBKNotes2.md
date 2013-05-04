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

in the `usb0` stanza in `/etc/network/interfaces`. Otherwise, just go in via the serial port and enable it as necessary.

PRU access under Wheezy
--

One of the coolest features of the AM335x SOC on the BBK is the pair of Programmable Realtime Units (PRUs), 200 MHz RISC cores that run independently of the ARM core and with access to GPIO, peripherals, private memory, and system memory. These are *really* cool for making high-speed hardware interfaces or communications busses.

More background info on the PRUs is available from

* <a href="http://elinux.org/ECE497_BeagleBone_PRU">ECE497 BeagleBone PRU</a> at elinux.org
* <a href="http://blog.boxysean.com/2012/08/12/first-steps-with-the-beaglebone-pru/">First Steps with the BeagleBone PRU</a> courtesy of boxysean
* <a href="https://github.com/beagleboard/am335x_pru_package">`am335x_pru_package`</a> from the BeagleBoard.org team

The first goal is to get the latter package working with the Debian Wheezy image we installed last time. Sadly, it doesn't work right out of the box: following boxysean's steps above, we get to the point where we're ready to run the test code and find that the uio\_pruss module shipped with our image apparently doesn't work right.

    INFO: Starting PRU_memAccessPRUDataRam example.
    prussdrv_open open failed

A little `strace`ing reveals the problem:

    open("/dev/uio0", O_RDWR|O_SYNC)        = -1 ENODEV (No such device)
    open("/sys/class/uio/uio0/maps/map0/addr", O_RDONLY) = -1 ENOENT (No such file or directory)

Apparently something about the uio implementation is broken. Let's investigate how it works with the default Angstrom image (aren't you glad we kept our install on a microSD card? I am!).
