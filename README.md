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

## Purpose
is to develop grub2 shell script, which will not need to be modified each time any changes made in the boot configuration, instead, it must create the boot menu "on-the-fly" according to the boot device content.

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
Caused by the grub2 shell limitations. Only dirctories named as natural numbers, defined in the NATURALS string in grub.cfg.template, will be visible for the executable. But as usual, limitation can turn to advantage, if You need to hide any subtree without deleting it, You can simply rename the subtree root node.

## TCE directories
Highest BOOT_ROOT subdir names are expected to be the major TinyCore version numbers and produce corresponding "tce=.../tceX" or "tce=.../tceX-64" bootcode, where X is highest subdir name. Respectively, "tce=.../tceX" for "rootfs.gz" accessible and "tce=.../tceX-64 for "rootfs64.gz" accessible.

## Boot entries
Depending on accessibility of core files and CPU bitness up to two entries can be created for each terminal node - see

        function create_entries
        
in the source code.

Boot entry name consists of the prefix and whole path steps, spaced with '-' symbols. Prefixes are:

- "Core" - for {vmlinuz; rootfs.gz; modules.gz}  
- "Core64" - for {vmlinuz64; rootfs.gz; modules64.gz}
- "Corepure64" - for {vmlinuz64; rootfs64.gz; modules64.gz}
  
### Example 1

Node /11/1/3/9 is terminal. Content of /bootcodes is 'BOOTCODES="quiet" '. /11/1 contains vmlinuz, vmlinuz64, modules.gz and modules64.gz. /11/1/3 contains rootfs.gz. Content of /11/1/3/9/bootcodes is 'BOOTCODES="base" '

Then for 32-bit CPU will be created entry, named "Core-11-1-3-9" loading /11/1/vmlinuz as kernel, /11/1/3/rootfs.gz + /11/1/modules.gz as initrd and passing "tce=UUID=${TCE_UUID}/tce11 quiet base" as the bootcodes.

For 64-bit CPU will be created entry, named "Core64-11-1-3-9" loading /11/1/vmlinuz64 as kernel, /11/1/3/rootfs.gz + /11/1/modules64.gz as initrd and passing "tce=UUID=${TCE_UUID}/tce11 quiet base" as the bootcodes.

In case will be present /11/1/3/9/title with 'TITLE="base" ' definition, for 32-bit and 64-bit CPUs entry names becomes
"Core-11-1-3-base" and "Core64-11-1-3-base" correspondingly.

### Example 2
Let's imagine, that You've packed custom /11/1/3/8/rootfs.gz  and placed it in the directory along with the /11/1/3/8/title containing 'TITLE="myrootfs" ' and /11/1/3/8/bootcodes, containing 'BOOTCODES="noswap" '. Then along with the entry, described in the Example 1 new entry will be created:
- 32-bit "Core-11-1-3-myrootfs", applying /11/1/vmlinuz as kernel, /11/1/3/8/rootfs.gz + /11/1/modules.gz as initrd and
"tce=UUID=.../tce11 quiet noswap" as the bootcodes, or
- 64-bit "Core64-11-1-3-myrootfs", applying /11/1/vmlinuz64 as kernel, /11/1/3/8/rootfs.gz + /11/1/modules64.gz as initrd and
"tce=UUID=.../tce11 quiet noswap" as the bootcodes.

Pay attention, that /11/1/3/8/rootfs.gz replaced /11/1/3/rootfs.gz from the previous example.

## grub4tc.sh
Shell script making BIOS/UEFI bootable removable device. Try

    ./grub4tc.sh --help
    
for usage and short description.
