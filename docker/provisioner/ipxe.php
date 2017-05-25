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
isset ${menu-default} || set menu-default rancher

###################### MAIN MENU ####################################

:start
menu iPXE boot menu for COACH
item --gap -- ------------------------- Operating systems ------------------------------
item 
item --key b rancher	RancherOS
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

:rancher
dhcp
set base-url http://<?=gethostname()?>/boot/rancher
kernel ${base-url}/vmlinuz printk.devkmsg=on rancher.debug=true rancher.state.dev=LABEL=RANCHER_STATE rancher.state.wait console=tty0 rancher.state.mdadm_scan console=ttyS1,115200n8 rancher.autologin=ttyS1 rancher.network.interfaces.eth*.dhcp=true rancher.cloud_init.datasources=${base-url}/cloud-init
initrd ${base-url}/initrd
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
