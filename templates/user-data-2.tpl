#cloud-config
hostname: __VM_NAME__
fqdn: __VM_NAME__.local

ssh_pwauth: true
disable_root: false

users:
  - name: __VM_USER__
    # hashed_passwd: '__VM_HASHED_PASS__'
    # lock_passwd: false
    # sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - __SSH_KEY__

write_files:
  - path: /etc/apk/repositories
    content: |
      https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
      https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
    append: true
  - path: /etc/network/interfaces
    owner: root:root
    permissions: '0644'
    content: |
      auto eth0
      iface eth0 inet static
        address __IP_NUM__
        gateway __IP_GW__
        dns-nameservers 8.8.8.8 1.1.1.1

package_upgrade: true
package_update: true
packages:
  - vim
  - curl
  - net-tools
  - openssh
  - lsblk
  - cloud-init
  - sudo

runcmd:
  - rc-update add cloud-init-local boot
  - rc-update add cloud-init default
  - rc-update add cloud-config default
  - rc-update add cloud-final default
  - rc-service sshd start
  - rc-update add sshd
  - rc-service sshd start
  - echo "AllowUsers __VM_USER__" >> /etc/ssh/sshd_config
  - sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  - echo "__VM_USER__ ALL=(ALL) ALL" > /etc/sudoers.d/__VM_USER__ && chmod 0440 /etc/sudoers.d/__VM_USER__
  - echo '__VM_USER__:__VM_HASHED_PASS__' | chpasswd
  - rc-service sshd restart
  - rc-service networking restart