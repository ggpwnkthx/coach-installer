<?php
$base_url=trim(shell_exec('hostname -f'));
?>
#!ipxe
# menu.ipxe by stefanl
# hints from:
# http://jpmens.net/2011/07/18/network-booting-machines-over-http/
# https://gist.github.com/2234639
# http://ipxe.org/cmd/menu

# menu [--name <name>] [--delete] [<title>]
# item [--menu <menu>] [--key <key>] [--default] [<label>|--gap [<text>]]
# choose [--menu <menu>] [--default <label>] [--timeout <timeout>] [--keep] <setting>

# Setup some basic convenience variables
set menu-timeout 5000

# Ensure we have menu-default set to something
isset ${menu-default} || set menu-default ubuntu

###################### MAIN MENU ####################################

:start
menu iPXE boot menu for COACH
item --gap -- ------------------------- Operating systems ------------------------------
item
item --key b ubuntu	Ubuntu 16.04
item
item --gap --           ------------------------- Advanced options -------------------------------
item --key c config     (c)onfigure settings
item --key s shell      Drop to iPXE (s)hell
item --key r reboot     (r)eboot computer
item
item --key x exit       E(x)it iPXE and continue BIOS boot
choose --timeout ${menu-timeout} --default ${menu-default} selected || goto cancel
set menu-timeout 0
goto ${selected}

:ubuntu
set base-url http://<?=$base_url;?>/boot/ubuntu
kernel ${base-url}/vmlinuz vga=775 ro root=filesystem.squashfs init_ip=ib0:dhcp  ds=nocloud-net
initrd ${base-url}/initrd
initrd ${base-url}/squashfs filesystem.squashfs
initrd http://<?=$base_url;?>/user-data/ /nocloud/user-data
initrd http://<?=$base_url;?>/meta-data /nocloud/meta-data

boot

:cancel
echo You cancelled the menu, dropping you to a shell

:shell
echo Type exit to get the back to the menu
shell
set menu-timeout 0
goto start

:failed
echo Booting failed, dropping to shell
goto shell

:reboot
reboot

:exit
exit

:config
config
goto start
