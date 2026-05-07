# Under development!❗️

![Static Badge](https://img.shields.io/badge/virtui-self%20hosted-green?style=for-the-badge&logo=Linux&logoColor=Yellow&color=%23285A48)

# Descriptions and Supports
This script is used for creating a VM based on libvirtd. Your system will be checked for availability for running virtualization with the following prompts:
- Checking the compatibility system for serving virtualization
- Checking and installing the libvirtd dependency packages
- Checking the compatibility of your system with nested virtualization
- Make sure the 'workdir' directory is ready

After checking is finished, then you must fill out several questions below:
- Give a name for your VM
- How much memory
- Allocate several cores of CPU
- Select a base image and OS
- Create a primary disk for the VM
- Determine many peripheral disks for the VM 
- Select a virtual network
- Specify IPv4 for the VM
- Configure a user, password, and key to access your VM
- Validate if the VM is successfully created or not

**Attention please**, this script currently only supports running on the Ubuntu base system. Next to do:
- [x] Ubuntu 20 or later
- [ ] Debian
- [ ] Rhel
- [ ] CentOS
- [ ] Alpine

# Prerequisites
Don't worry if you are running this script. Your system will install the following dependency packages while running this script:
1. cpu-checker
2. ipcalc
3. whois
4. qemu-system
5. libvirt-daemon-system
6. virtinst
7. libosinfo-bin

# Tips and Tricks
1. If you want to running this script **rootless**. You must uncomment the `#unix_sock_group = "libvirt"` parameter in the `/etc/libvirt/libvirtd.conf` file
```bash
sed -i 's/^#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/g' /etc/libvirt/libvirtd.conf
```

2. Suppose you encounter a problem like this
<img height="300" alt="image" src="https://github.com/user-attachments/assets/973e1495-9d4c-4d6b-9cca-42551e43b7b1" />

The solutions is add the `uri_default = "qemu:///system"` parameter in the `.config/libvirt/libvirt.conf` file and allow all permissions to the `libvirt-sock` file. Here is the [reference](https://serverfault.com/questions/803283/how-do-i-list-virsh-networks-without-sudo#:~:text=17,to%20espicify%20%2D%2Dconnect)
```bash
cat << EOF > .config/libvirt/libvirt.conf
uri_default = "qemu:///system"
EOF
```
```bash
sudo chmod 777 /var/run/libvirt/libvirt-sock
```

3. Here is the example xml if you don't have a virtual network. You can customize as you wish. Click this [reference](https://libvirt.org/formatnetwork.html#example-configuration)
```bash
<network>
  <name>default</name>
  <bridge name='virbr0'/>
  <forward/>
  <ip address='192.168.1.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.1.2' end='192.168.1.254'/>
    </dhcp>
  </ip>
</network>
```

4. Allow all permissions and change owner the `workdir` and `images` directory to avoid script can't cloning base image. 
- The **reasons** is on bellow line in script
```bash
qemu-img create -q -b "${src_dir}/${src_img}" -f qcow2 -F qcow2 "${dst_path}" "${vm_disk1_size}"G
```

- This is way to allow all permissions to `workdir` and `images` directory
```bash
sudo chmod -R 777 /var/lib/libvirt/workdir/
```
```bash
sudo chmod -R 777 /var/lib/libvirt/images/
```

- This is way to change owner the `workdir` and `images` directory
```bash
sudo chown -R libvirt-qemu:kvm /var/lib/libvirt/workdir/
```
```bash
sudo chown -R libvirt-qemu:kvm /var/lib/libvirt/images/
```

5. Clone this repository
```bash
git clone https://github.com/uvewexyz/create-vm-automatically.git
```

6. Give the execute permissions to the `virtui.sh` script
```bash
cd ~/create-vm-automatically
```
```bash
chmod +x virtui.sh && ls -l virtui.sh
```

7. Before running the `virtui.sh` script. These are recommended OS image, if you want to install. Follow bellowing step by step:
- Move the current/working directory
```bash
cd /var/lib/libvirt/workdir/
```

- Installing `almalinux9` image
```bash
wget https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
```

- Installing `centos-stream9` image
```bash
wget https://cloud.centos.org/altarch/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
```

- Installing `alpine-virt-3.21` image
```bash
wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-virt-3.21.3-x86_64.iso
```
```bash
qemu-img convert -f raw -O qcow2 alpine-virt-3.21.3-x86_64.iso alpine-virt-3.21.3-x86_64.qcow2
```

- Installing `ubuntu22.04` image
```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

- Installing `ubuntu20.04` image
```bash
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

- Installing, extract, and convert extension to qcow2 the `openwrt` image
```bash
wget https://downloads.openwrt.org/releases/24.10.1/targets/x86/generic/openwrt-24.10.1-x86-generic-generic-ext4-combined.img.gz
```
```bash
gunzip openwrt-24.10.1-x86-generic-generic-ext4-combined.img.gz
```
```bash
qemu-img convert -f raw -O qcow2 openwrt-24.10.1-x86-generic-generic-ext4-combined.img openwrt-24.10.1-x86-generic-generic-ext4-combined.qcow2
```

8. Run the script bellow in this way
```bash
./virtui.sh
```

9. Easily to create or change user password, run the command in bellow
```bash
echo "user1:Str0ngPass!" | chpasswd
```

10. Demonstration

![virtui_demo](https://github.com/user-attachments/assets/148f69bb-7d1d-456a-8f17-6ff2af6332cc)
![virtui_demo_access](https://github.com/user-attachments/assets/6faa13dd-6126-4f9c-b5a4-cf7c8532d530)


# Legends Color information's
| Legend  |                 Colour               |
| :-----: |                :------:              |
| INFO    | $\textsf{\color{lightblue}Blue}$     |
| SUCCESS | $\textsf{\color{lightgreen}Green}$   |
| FAIL    | $\textsf{\color{red}Red}$            |
| TIPS    | $\textsf{\color{yellow}Yellow}$      |

# Reference
- https://linuxize.com/post/how-to-install-kvm-on-ubuntu-20-04
- https://www.freecodecamp.org/news/turn-ubuntu-2404-into-a-kvm-hypervisor
- https://serverfault.com/questions/803283/how-do-i-list-virsh-networks-without-sudo#:~:text=17,to%20espicify%20%2D%2Dconnect
- https://blog.wikichoon.com/2016/01/qemusystem-vs-qemusession.html?utm_source=chatgpt.com
- https://libvirt.org/drvqemu.html#driver-instances
- https://libvirt.org/formatnetwork.html#routed-network-config
- https://libvirt.org/formatnetwork.html#example-configuration
