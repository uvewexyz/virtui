version: 2
ethernets:
  primary_nic:
    match:
      name: "e*"
    dhcp4: false
    addresses:
      - __IP_NUM__/24
    nameservers:
      addresses: [8.8.8.8, 1.1.1.1]
    routes:
      - to: default
        via: __IP_GW__