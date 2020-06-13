# grub.cfg-forTinyCoreLinux
grub2 shell script, building TCL boot menu according to the boot directory structure and content
## Reasons
[TinyCore Linux](http://tinycorelinux.net) architecture allows versatile possibilities of building the Linux distribution for Your particular needs, assembled of the:
1. [core files](http://tinycorelinux.net/11.x/x86/release/distribution_files/) - kernel (vmlinuz) and initrd (rootfs.gz + modules.gz)

fine tuned with the

2. [bootcodes](http://tinycorelinux.net/faq.html#bootcodes) (supplied to the kernel by the boot manager during boot)

and extended to reach requested functionality with the appropriate subset of

3. [extensions](http://tinycorelinux.net/11.x/x86/tcz/)

Performing this task by the boot manager (grub2 in our case) can be considered as walking through the branches of some directory tree from the root to one of the terminal nodes, gathering the members of the resulting set along the path. Additional level under root must be added for different TinyCore versions coexisting inside the same boot partition.

## Subject
the subject is the "grub.cfg" file obtained as

        cat grub.cfg.def grub.cfg.template > grub.cfg
        
and supplied to the grub2 boot manager, installed following guidelines described by Juanito in the [BIOS/UEFI dual boot usb stick HowTo](http://forum.tinycorelinux.net/index.php/topic,19364.0.html).

Here "grub.cfg.def" contains definitions of the BOOT and TCE drives UUID's, boot directory name (if alternate to /) and initial bootcode "waitusb" string for slow usb devices (can be ommitted for hard drive installations). BOOT_ROOT may be changed in the case BOOT and TCE contained in the same partition.

And "grub.cfg.template" is executable code, performing directory tree walking around, gathering information and creating boot entries.

## Component parts of the BOOT directory tree
1. Core files - vmlinuz, vmlinuz64, rootfs.gz, rootfs64.gz, modules.gz, modules64.gz

2. Bootcodes - files named "bootcodes", containing the

        BOOTCODES="<some bootcode>"
        
directives.

3. Directory name aliases: files named "title", containing the

        TITLE="<aternative_dir_title>"

directives for more descriptive boot entry naming.

## Features
Files of different types are gathered along the path in the different manner. Core files are replacing ones found earlier, bootcodes are accumulated.

## Limitations
Caused by the grub2 shell limitations. Only dirctories named as natural numbers, defined in the NATURALS string in grub.cfg.template, will be visible for the executable. But as usual, limitation can turn to advantage, if You need to hide any subtree without deleting it, You can simply rename the subtree top.

## Proposed BOOT tree layout and content

