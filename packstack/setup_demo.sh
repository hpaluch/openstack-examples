#!/bin/bash

# This script attempts to automate demo setup steps from page:
#   https://www.rdoproject.org/networking/neutron-with-existing-external-network/
# just after sentence "Now, create the external network with Neutron."
#
# WARNING! I intentionally use unique (different) names from above guide
# to catch parameter name errors.
#
# Many things were ripped from this very good guide:
# https://web.archive.org/web/20190819054107if_/http://www.netlabsug.org:80/documentum/Openstack-Laboratory-Guide_v5.0.1-Pike-Release.pdf


# NOTE: This image must already exist
MY_IMAGE=cirros
# NOTE: Flavor must exist (it will not be created)
MY_FLAVOR=m1.tiny

MY_KEYPAIR=demo_kp
MY_KEYPAIR_FILE=~/${MY_KEYPAIR}.pem

MY_VOLUME=1GB-Vol
MY_VOLUME_SIZE_GB=1

MY_SECGROUP=demosg

# Public DNS server
MY_DNS=8.8.8.8

MY_SUBNET=demos
MY_SUBNET_CIDR=192.168.100.0/24
MY_NET=demon
MY_EXT_NET=external_network

MY_ROUTER=demor
MY_PROJECT=demop
MY_ROLE=member

MY_USER=demou
MY_PW=Secr3t321
MY_EMAIL=root@example.com

set -e

script_name=$(basename $0 | tr '.' '_')
sd=$HOME/.cache/$script_name
mkdir -p $sd

# https://www.rdoproject.org/networking/neutron-with-existing-external-network/
source ~/keystonerc_admin

# Create project $MY_PROJECT if not exist
sf=$sd/created-project-$MY_PROJECT
echo $sf
[ -f "$sf" ] || {
	openstack project show $MY_PROJECT || {
		openstack project create --enable $MY_PROJECT
	}
	touch $sf
}

# create user
sf=$sd/created-user-$MY_PROJECT-$MY_USER
echo $sf
[ -f "$sf" ] || {
	openstack user show $MY_USER || {
		set -x
		openstack user create --project $MY_PROJECT --password $MY_PW \
			 --email $MY_EMAIL --enable $MY_USER
		set +x
	}
	touch $sf
}

# undocumented - user must get assigned role(!)
sf=$sd/created-$MY_ROLE-$MY_PROJECT-$MY_USER
echo $sf
[ -f "$sf" ] || {
	openstack role assignment list -f value --user $MY_USER --project $MY_PROJECT --role $MY_ROLE | egrep '...' || {
		set -x
		openstack role add --project $MY_PROJECT --user $MY_USER  $MY_ROLE
		set +x
	}
	touch $sf
}

echo "Setting openstack credentials to tenanat=$MY_PROJECT user=$MY_USER"
export OS_USERNAME=$MY_USER
export OS_PROJECT_NAME=$MY_PROJECT
export OS_PASSWORD=$MY_PW
set | grep OS_


# create router to external network
sf=$sd/created-router-$MY_PROJECT-$MY_ROUTER
echo $sf
[ -f "$sf" ] || {
  	openstack router show $MY_ROUTER || {
		openstack router create $MY_ROUTER
	}
	touch $sf
}

# set external gateway
sf=$sd/created-router-gw-$MY_PROJECT-$MY_ROUTER
echo $sf
[ -f "$sf" ] || {
  	[ "$(openstack router show -f value -c external_gateway_info $MY_ROUTER)"  = "$MY_EXT_NET"  ] || {
		openstack router set --external-gateway $MY_EXT_NET  $MY_ROUTER
	}
	touch $sf
}

# create private network
sf=$sd/created-net-$MY_PROJECT-$MY_NET
echo $sf
[ -f "$sf" ] || {
  	openstack network show $MY_NET || {
		openstack network create $MY_NET
	}
	touch $sf
}

# create subnet in private network
sf=$sd/created-subnet-$MY_PROJECT-$MY_SUBNET
echo $sf
[ -f "$sf" ] || {
  	openstack subnet show $MY_SUBNET || {
		openstack subnet create --network $MY_NET  --subnet-range $MY_SUBNET_CIDR \
			--dns-nameserver $MY_DNS $MY_SUBNET
	}
	touch $sf
}

# assign subnet to router
sf=$sd/created-router-subnet-$MY_PROJECT-$MY_SUBNET-$MY_ROUTER
echo $sf
[ -f "$sf" ] || {
        # fixme - don't know how to detect that router has assigned this subnet
	openstack router add subnet $MY_ROUTER $MY_SUBNET
	touch $sf
}

# create security group
sf=$sd/created-sg-$MY_PROJECT-$MY_SECGROUP
echo $sf
[ -f "$sf" ] || {
	openstack security group show $MY_SECGROUP || {
		openstack security group create $MY_SECGROUP 
	}
	touch $sf
}

# Rules creation grabbed from:
# https://web.archive.org/web/20190819054107if_/http://www.netlabsug.org:80/documentum/Openstack-Laboratory-Guide_v5.0.1-Pike-Release.pdf

# create allow ICMP rule
sf=$sd/created-rule-$MY_PROJECT-$MY_SECGROUP-icmp
echo $sf
[ -f "$sf" ] || {
	# FIXME: Don't know how to easy detect specific rule...
	openstack security group rule create --ethertype IPv4 --proto icmp $MY_SECGROUP
	touch $sf
}
# create allow SSH rule
sf=$sd/created-rule-$MY_PROJECT-$MY_SECGROUP-ssh
echo $sf
[ -f "$sf" ] || {
	# FIXME: Don't know how to easy detect specific rule...
	openstack security group rule create --ethertype IPv4 --proto tcp --dst-port 22  $MY_SECGROUP
	touch $sf
}

# create volume
sf=$sd/created-volume-$MY_PROJECT-$MY_VOLUME
echo $sf
[ -f "$sf" ] || {
	openstack volume show $MY_VOLUME || {
		openstack volume create --size $MY_VOLUME_SIZE_GB  $MY_VOLUME
	}
	touch $sf
}

# create keypair if not exist
sf=$MY_KEYPAIR_FILE
echo "$sf"
[ -f "$sf" ] || {
	openstack keypair create --private-key ${MY_KEYPAIR_FILE}.tmp $MY_KEYPAIR
	file ${MY_KEYPAIR_FILE}.tmp | fgrep 'PEM RSA private key' || {
		echo "Generated private key file ${MY_KEYPAIR_FILE}.tmp has invalid data" >&2
		exit 1
	}
	mv ${MY_KEYPAIR_FILE}.tmp $MY_KEYPAIR_FILE
}

MY_NET_ID=$(openstack network show -f value -c id $MY_NET)
[ -n "$MY_NET_ID" ] || {
	echo "Error getting ID of network $MY_NET in project $MY_PROJECT" >&2
	exit 1
}
echo "Network '$MY_NET' has ID='$MY_NET_ID'"

#penstack server create --flavor m1.nano \
#--image cirros --nic net-id=$NIC --security-group default \
#--key-name mykey cirrOS-test
