#!/bin/bash

SECONDS=0 # Keeping track of the time taken to deploy the solution
# Checking the presence of required arguments
if [ -z "$1" ]; then
    echo "Error: Please specify the openrc, tag, and ssh_key"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: Please specify the openrc, tag, and ssh_key"
    exit 1
fi

if [ -z "$3" ]; then
    echo "Error: Please specify the openrc, tag, and ssh_key"
    exit 1
fi

openrc_sr=${1}     # openrc access file
tag_sr=${2}        # tag for identification of items
ssh_key_path=${3}  # the ssh_key
no_of_servers=$(grep -E '[0-9]' servers.conf) # number of nodes from servers.conf

# Sourcing the given openrc file
echo "${cd_time} Begining the deployment of $tag_sr using ${openrc_sr} for credentials."
source ${openrc_sr}

# Defining variables
natverk_namn="${2}_network"
sr_subnet="${2}_subnet"
sr_keypair="${2}_key"
sr_router="${2}_router"
sr_security_group="${2}_security_group"
sr_haproxy_server="${2}_proxy"
sr_bastion_server="${2}_bastion"
sr_server="${2}_server"
sshconfig="config"
knownhosts="known_hosts"
hostsfile="hosts"
nodes_yaml="nodes.yaml"

# Verify the existence of the keypair
echo "$(date) Checking for the presence of keypair: ${sr_keypair}."

# Fetch the list of existing keypairs
available_keypairs=$(openstack keypair list -f value --column Name)

# Check if the keypair exists
if [[ "$available_keypairs" =~ (^|[[:space:]])"${sr_keypair}"($|[[:space:]]) ]]; then
    echo "$(date) Keypair ${sr_keypair} already exists."
else
    echo "$(date) Keypair ${sr_keypair} not found in this OpenStack project."
    echo "$(date) Creating keypair ${sr_keypair} with the public key from ${ssh_key_path}."
    created_keypair=$(openstack keypair create --public-key "${ssh_key_path}" "${sr_keypair}")
fi

# Retrieve the list of current networks with the specified tag
existing_networks=$(openstack network list --tag "${tag_sr}" --column Name -f value)

# Check if the desired network exists in the list
if [[ $(echo "${existing_networks}" | grep -x "${natverk_namn}") ]]; then
    echo "$(date) ${natverk_namn} already exists"
else
    echo "$(date) ${natverk_namn} not found in the current OpenStack project, creating it."
    created_network=$(openstack network create --tag "${tag_sr}" "${natverk_namn}" -f json)
    echo "$(date) ${natverk_namn} has been created."
fi


# Retrieve the list of current subnets with the specified tag
subnet_list=$(openstack subnet list --tag "${tag_sr}" --column Name -f value)

# Check if the desired subnet exists in the list
if [[ "${subnet_list}" == *"${sr_subnet}"* ]]; then
    echo "$(date) ${sr_subnet} already exists"
else
    echo "$(date) Did not find ${sr_subnet} in this OpenStack project, adding it."

    # Create the new subnet
    created_subnet=$(openstack subnet create \
        --subnet-range 10.10.0.0/27 \
        --allocation-pool start=10.10.0.10,end=10.10.0.30 \
        --tag "${tag_sr}" \
        --network "${natverk_namn}" \
        "${sr_subnet}" -f json)

    echo "$(date) Added ${sr_subnet}."
fi

# Fetch the list of current routers with the specified tag
routers_list=$(openstack router list --tag "${tag_sr}" --column Name -f value)

# Check if the router exists in the fetched list
if [[ "$(echo "${routers_list}" | grep -Fx "${sr_router}")" ]]; then
    echo "$(date) ${sr_router} already exists"
else
    echo "$(date) Did not find ${sr_router} in this OpenStack project, adding it."
    
    # Create a new router with the specified tag and name
    created_router=$(openstack router create --tag "${tag_sr}" "${sr_router}")
    echo "$(date) Added ${sr_router}."
    
    echo "$(date) Configuring the router."
    
    # Add a subnet to the new router
    openstack router add subnet "${sr_router}" "${sr_subnet}"
    
    # Set the external gateway for the new router
    openstack router set --external-gateway ext-net "${sr_router}"
    
    echo "$(date) Done."
fi


# Define a function to add security group rules
add_security_group_rules() {
    echo "$(date) Adding security group rules."
    created_security_group=$(openstack security group create --tag "${tag_sr}" "${sr_security_group}" -f json)                       
    for port in 22:tcp 5000:tcp 6000:udp 161:udp 80:icmp; do
        IFS=":" read -r port_number protocol <<< "$port"
     
      port=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port "$port_number" --protocol "$protocol" --ingress ${sr_security_group})
    done
    echo "$(date) Done."
}

# Fetch current security groups based on tag
current_sg=$(openstack security group list --tag "$tag_sr" -f value)

# Check if the specified security group exists
if ! echo "$current_sg" | grep -q "$sr_security_group"; then
    #echo "Test"
    add_security_group_rules 
                             
else
    echo "$(date) $sr_security_group already exists"
fi


# Remove old configuration files if they exist
for file in "$sshconfig" "$knownhosts" "$hostsfile" "$nodes_yaml"; do
    if [[ -f "$file" ]]; then
        rm "$file"
    fi
done
