version: 1
config:
  - type: physical
    name: eth0
    subnets:
      - type: static
        address: __IP_NUM__
        gateway: __IP_GW__
        dns_nameservers:
          - 8.8.8.8
          - 1.1.1.1