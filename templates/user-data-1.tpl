#cloud-config
hostname: __VM_NAME__
fqdn: __VM_NAME__.local

ssh_pwauth: true
disable_root: false

users:
  - name: __VM_USER__
    hashed_passwd: '__VM_HASHED_PASS__'
    shell: /bin/bash
    lock_passwd: false
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - __SSH_KEY__

package_upgrade: true
package_update: true
packages:
  - vim
  - net-tools
  - curl

runcmd:
  - echo "AllowUsers __VM_USER__" >> /etc/ssh/sshd_config
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  - sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
  - systemctl restart sshd