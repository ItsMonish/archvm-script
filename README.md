# Arch Linux Install Script
Just a simple bash script to get a quick Arch linux guest system on a virtual machine such as VirtualBox or QEMU/LIBVIRT.
# Usage:
- To use the script, boot into the arch live iso media and check for internet connection and run the below snippet. Fill in a few prompts and the script gets the job done.
	```sh
	curl https://raw.githubusercontent.com/ItsMonish/archvm-script/refs/heads/master/install.sh -o install.sh && bash install.sh
	```
- To manually perform partitioning and mounting set the ```SKIP_PARTITION_AND_MOUNT``` variable in the environment to ```true``` . This will make the script skip it partitioning and mounting functions and install the base system directly to ```/mnt```.
-  **Tip**: SSH into the live media by opening the ssh server using ```systemctl enable sshd.service``` and connect from your host computer. It allows copy-pasting the above command and makes things easy. 
-  **Note**: This is for spinning up a quick VM instance of Arch linux guest. If you want to install Arch on your host machine, then read the [wiki](https://wiki.archlinux.org/) and spend some time tweaking and installing it.
