#!/bin/bash

# here is my script that I run to setup StatsPack "Train" release from RDO
# see: https://www.rdoproject.org/networking/neutron-with-existing-external-network/

set -xe
out_file=$HOME/answer_$(date '+%Y%m%d_%H%M%S').txt
#dr="--dry-run"
# NOTE: --all-in-one refuses --answer-file, however it generates one in /root on exit
#
# Replace enp0s8 with your physical NIC
# Replace stack-vg with your EMPTY volume group LVM
#
# Be sure that your /etc/sysconfig/network-scripts/ifcfg-NIC has assigned STATIC IP Address
# - it will be swapped by packstack with new bridge br-ex, therefore killing DHCP assigned address from NIC...
sudo packstack $dr \
  --allinone \
  --default-password=Secr3t321 \
  --cinder-volume-name=stack-vg --cinder-backend=lvm --cinder-volumes-create=n \
  --os-neutron-l2-agent=openvswitch --os-neutron-ml2-mechanism-drivers=openvswitch \
  --os-neutron-ml2-tenant-network-types=vxlan --os-neutron-ml2-type-drivers=vxlan,flat \
  --provision-demo=n --os-neutron-ovs-bridge-mappings=extnet:br-ex --os-neutron-ovs-bridge-interfaces=br-ex:enp0s8 \
  --os-swift-install=n --os-ceilometer-install=n --os-heat-install=y

