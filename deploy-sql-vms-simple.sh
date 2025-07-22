#!/bin/bash
# filepath: deploy-sql-vms-simple.sh
set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Script version
SCRIPT_VERSION="1.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to check command result
check_result() {
    if [ $? -eq 0 ]; then
        print_message $GREEN "✓ $1 completed successfully"
    else
        print_message $RED "✗ $1 failed"
        exit 1
    fi
}

# Function to validate password complexity
validate_password() {
    local password=$1
    if [[ ${#password} -lt 12 ]] || \
       [[ ! "$password" =~ [A-Z] ]] || \
       [[ ! "$password" =~ [a-z] ]] || \
       [[ ! "$password" =~ [0-9] ]] || \
       [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        print_message $RED "Generated password doesn't meet SQL Server complexity requirements"
        exit 1
    fi
}

# Function to wait for VM to be ready
wait_for_vm() {
    local vm_name=$1
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if az vm show -g $RESOURCE_GROUP -n $vm_name --query provisioningState -o tsv 2>/dev/null | grep -q "Succeeded"; then
            return 0
        fi
        print_message $YELLOW "Waiting for $vm_name to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    return 1
}

# Generate unique names based on timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)
UNIQUE_ID=$(date +%s | tail -c 6)

# Configuration variables
RESOURCE_GROUP="sql-ha-rg-${TIMESTAMP}"
LOCATION="centralus"
VNET_NAME="sql-vnet"
SUBNET_NAME="sql-subnet"
NSG_NAME="sql-nsg"

# Key Vault names must be 3-24 characters, alphanumeric and hyphens only
KEY_VAULT_NAME="sqlkv-${UNIQUE_ID}"
if [ ${#KEY_VAULT_NAME} -gt 24 ]; then
    KEY_VAULT_NAME="${KEY_VAULT_NAME:0:24}"
fi

# VM Configuration
VM_NAME_1="sqlvm1"
VM_NAME_2="sqlvm2"
VM_SIZE="Standard_D2s_v3"
SQL_IMAGE="MicrosoftSQLServer:sql2019-ws2019:sqldev:latest"

# Load Balancer Configuration
LB_NAME="sql-lb"
LB_FRONTEND_NAME="sql-frontend"
LB_BACKEND_NAME="sql-backend"
LB_PROBE_NAME="sql-probe"
LB_RULE_NAME="sql-rule"
LISTENER_IP="10.0.1.100"
PROBE_PORT="59999"

# Admin credentials (will be stored in Key Vault)
ADMIN_USERNAME="sqladmin"
ADMIN_PASSWORD="SqlP@ss${UNIQUE_ID}!"

# Validate password complexity
validate_password "$ADMIN_PASSWORD"

# Validate listener IP is in subnet range
if [[ ! "$LISTENER_IP" =~ ^10\.0\.1\.[0-9]{1,3}$ ]]; then
    print_message $RED "Listener IP $LISTENER_IP is not in subnet range 10.0.1.0/24"
    exit 1
fi

print_message $GREEN "=== Azure SQL Server VM Deployment Script v$SCRIPT_VERSION ==="
print_message $YELLOW "Resource Group: $RESOURCE_GROUP"
print_message $YELLOW "Key Vault: $KEY_VAULT_NAME"
print_message $YELLOW "Timestamp: $TIMESTAMP"

# Cleanup function for failed deployments
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_message $RED "\nDeployment failed with exit code: $exit_code"
        print_message $YELLOW "To clean up resources, run:"
        print_message $NC "az group delete --name $RESOURCE_GROUP --yes --no-wait"
    fi
}
trap cleanup_on_error EXIT

# Function to create Key Vault and store credentials
create_key_vault() {
    print_message $YELLOW "\nCreating Azure Key Vault for secure credential storage..."

    # Create Key Vault
    az keyvault create \
        --name $KEY_VAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --enable-rbac-authorization false \
        --output none
    check_result "Key Vault creation"

    # Store admin credentials
    print_message $YELLOW "Storing credentials in Key Vault..."
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "sql-admin-username" \
        --value "$ADMIN_USERNAME" \
        --output none
    check_result "Username storage"

    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "sql-admin-password" \
        --value "$ADMIN_PASSWORD" \
        --output none
    check_result "Password storage"

    print_message $GREEN "Credentials securely stored in Key Vault: $KEY_VAULT_NAME"
}

# Function to create load balancer for AG listener
create_load_balancer() {
    print_message $YELLOW "\nCreating load balancer for AG listener..."

    # Create load balancer
    az network lb create \
        --resource-group $RESOURCE_GROUP \
        --name $LB_NAME \
        --sku Standard \
        --private-ip-address $LISTENER_IP \
        --subnet $SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --backend-pool-name $LB_BACKEND_NAME \
        --frontend-ip-name $LB_FRONTEND_NAME \
        --output none
    check_result "Load balancer creation"

    # Create health probe
    az network lb probe create \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $LB_PROBE_NAME \
        --protocol tcp \
        --port $PROBE_PORT \
        --interval 5 \
        --threshold 2 \
        --output none
    check_result "Health probe creation"

    # Create load balancing rule
    az network lb rule create \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $LB_RULE_NAME \
        --protocol tcp \
        --frontend-port 1433 \
        --backend-port 1433 \
        --frontend-ip-name $LB_FRONTEND_NAME \
        --backend-pool-name $LB_BACKEND_NAME \
        --probe-name $LB_PROBE_NAME \
        --disable-outbound-snat true \
        --idle-timeout 4 \
        --enable-floating-ip true \
        --output none
    check_result "Load balancing rule creation"

    print_message $GREEN "Load balancer configured with listener IP: $LISTENER_IP"
}

# Main deployment function
deploy_infrastructure() {
    # Create Resource Group
    print_message $YELLOW "\nCreating resource group..."
    az group create --name $RESOURCE_GROUP --location $LOCATION --output none
    check_result "Resource group creation"

    # Create Key Vault
    create_key_vault

    # Create Virtual Network
    print_message $YELLOW "\nCreating virtual network..."
    az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name $VNET_NAME \
        --address-prefixes 10.0.0.0/16 \
        --subnet-name $SUBNET_NAME \
        --subnet-prefixes 10.0.1.0/24 \
        --output none
    check_result "Virtual network creation"

    # Create Network Security Group
    print_message $YELLOW "\nCreating network security group..."
    az network nsg create \
        --resource-group $RESOURCE_GROUP \
        --name $NSG_NAME \
        --output none
    check_result "NSG creation"

    # Add NSG Rules
    print_message $YELLOW "\nAdding security rules..."

    # Get current public IP for RDP access
    MY_PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "0.0.0.0")
    if [ "$MY_PUBLIC_IP" == "0.0.0.0" ]; then
        print_message $YELLOW "Could not determine public IP. RDP rule will allow access from any IP."
        MY_PUBLIC_IP="*"
    fi

    # RDP Access (restricted to deployment machine)
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowRDP \
        --priority 100 \
        --destination-port-ranges 3389 \
        --source-address-prefixes "${MY_PUBLIC_IP}" \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --description "Allow RDP from deployment machine" \
        --output none
    check_result "RDP rule creation"

    # Internal subnet communication
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowInternalSubnet \
        --priority 105 \
        --source-address-prefixes 10.0.1.0/24 \
        --destination-address-prefixes 10.0.1.0/24 \
        --destination-port-ranges "*" \
        --access Allow \
        --protocol "*" \
        --direction Inbound \
        --description "Allow all internal subnet communication" \
        --output none
    check_result "Internal subnet rule creation"

    # SQL Server
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowSQL \
        --priority 110 \
        --destination-port-ranges 1433 \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --output none
    check_result "SQL rule creation"

    # AG Endpoint
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowAGEndpoint \
        --priority 120 \
        --destination-port-ranges 5022 \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --output none
    check_result "AG endpoint rule creation"

    # Health Probe Port
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowProbePort \
        --priority 130 \
        --destination-port-ranges $PROBE_PORT \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --description "Allow health probe port for load balancer" \
        --output none
    check_result "Health probe rule creation"

    # Create Availability Set
    print_message $YELLOW "\nCreating availability set..."
    az vm availability-set create \
        --resource-group $RESOURCE_GROUP \
        --name sql-avset \
        --platform-fault-domain-count 2 \
        --platform-update-domain-count 2 \
        --output none
    check_result "Availability set creation"

    # Create Load Balancer
    create_load_balancer

    # Create SQL VMs
    for i in 1 2; do
        local vm_name="VM_NAME_$i"
        vm_name=${!vm_name}

        print_message $YELLOW "\nCreating SQL VM $i: $vm_name (this may take 5-10 minutes)..."

        # Create NIC with load balancer backend pool
        local nic_name="${vm_name}-nic"
        az network nic create \
            --resource-group $RESOURCE_GROUP \
            --name $nic_name \
            --vnet-name $VNET_NAME \
            --subnet $SUBNET_NAME \
            --network-security-group $NSG_NAME \
            --lb-name $LB_NAME \
            --lb-address-pools $LB_BACKEND_NAME \
            --output none
        check_result "NIC creation for $vm_name"

        # Create VM with proper data disk configuration
        az vm create \
            --resource-group $RESOURCE_GROUP \
            --name $vm_name \
            --availability-set sql-avset \
            --nics $nic_name \
            --image "$SQL_IMAGE" \
            --size $VM_SIZE \
            --admin-username $ADMIN_USERNAME \
            --admin-password "$ADMIN_PASSWORD" \
            --storage-sku Premium_LRS \
            --os-disk-name "${vm_name}-osdisk" \
            --data-disk-sizes-gb 128 256 \
            --public-ip-address "" \
            --output none
        check_result "VM $i creation"

        # Wait for VM to be ready
        wait_for_vm $vm_name
        check_result "VM $i readiness check"

        # Enable system-assigned managed identity
        az vm identity assign \
            --resource-group $RESOURCE_GROUP \
            --name $vm_name \
            --output none
        check_result "Managed identity assignment for $vm_name"
    done

    # Grant VMs access to Key Vault
    print_message $YELLOW "\nGranting VMs access to Key Vault..."
    for i in 1 2; do
        local vm_name="VM_NAME_$i"
        vm_name=${!vm_name}

        local vm_identity=$(az vm show \
            --resource-group $RESOURCE_GROUP \
            --name $vm_name \
            --query identity.principalId -o tsv)

        az keyvault set-policy \
            --name $KEY_VAULT_NAME \
            --object-id $vm_identity \
            --secret-permissions get list \
            --output none
        check_result "Key Vault access for $vm_name"
    done

    # Register VMs with SQL VM provider
    print_message $YELLOW "\nRegistering VMs with SQL VM provider..."
    for i in 1 2; do
        local vm_name="VM_NAME_$i"
        vm_name=${!vm_name}

        az sql vm create \
            --name $vm_name \
            --resource-group $RESOURCE_GROUP \
            --sql-mgmt-type Full \
            --license-type PAYG \
            --sql-workload-type OLTP \
            --output none
        check_result "SQL VM registration for $vm_name"
    done

    # Get VM information
    VM1_PRIVATE_IP=$(az vm show -g $RESOURCE_GROUP -n $VM_NAME_1 --query privateIps -d --out tsv)
    VM2_PRIVATE_IP=$(az vm show -g $RESOURCE_GROUP -n $VM_NAME_2 --query privateIps -d --out tsv)

    # Create temporary public IPs for initial RDP access
    print_message $YELLOW "\nCreating temporary public IPs for RDP access..."
    for i in 1 2; do
        local vm_name="VM_NAME_$i"
        vm_name=${!vm_name}

        az network public-ip create \
            --resource-group $RESOURCE_GROUP \
            --name "${vm_name}-pip" \
            --sku Standard \
            --allocation-method Static \
            --output none

        # Get NIC name
        local nic_name="${vm_name}-nic"

        # Associate public IP with NIC
        az network nic ip-config update \
            --resource-group $RESOURCE_GROUP \
            --nic-name $nic_name \
            --name ipconfig1 \
            --public-ip-address "${vm_name}-pip" \
            --output none
        check_result "Public IP assignment for $vm_name"
    done

    # Get public IPs
    VM1_PUBLIC_IP=$(az network public-ip show -g $RESOURCE_GROUP -n "${VM_NAME_1}-pip" --query ipAddress -o tsv)
    VM2_PUBLIC_IP=$(az network public-ip show -g $RESOURCE_GROUP -n "${VM_NAME_2}-pip" --query ipAddress -o tsv)

    # Save deployment information
    save_deployment_info
}

# Function to save deployment information
save_deployment_info() {
    local deployment_file="deployment-info-${TIMESTAMP}.txt"

    cat > "$deployment_file" <<EOF
Azure SQL Server VM Deployment Information
==========================================
Deployment Date: $(date)
Deployment ID: $TIMESTAMP
Script Version: $SCRIPT_VERSION

Resource Group: $RESOURCE_GROUP
Location: $LOCATION
Key Vault: $KEY_VAULT_NAME

Network Configuration:
- VNet: $VNET_NAME (10.0.0.0/16)
- Subnet: $SUBNET_NAME (10.0.1.0/24)
- NSG: $NSG_NAME

Load Balancer Configuration:
- Load Balancer: $LB_NAME
- Frontend IP (Listener): $LISTENER_IP
- Backend Pool: $LB_BACKEND_NAME
- Health Probe Port: $PROBE_PORT

SQL Server VMs:
- VM1: $VM_NAME_1
  - Private IP: $VM1_PRIVATE_IP
  - Public IP: $VM1_PUBLIC_IP (temporary - remove after configuration)

- VM2: $VM_NAME_2
  - Private IP: $VM2_PRIVATE_IP
  - Public IP: $VM2_PUBLIC_IP (temporary - remove after configuration)

To retrieve credentials from Key Vault:
- Username: az keyvault secret show --vault-name $KEY_VAULT_NAME --name sql-admin-username --query value -o tsv
- Password: az keyvault secret show --vault-name $KEY_VAULT_NAME --name sql-admin-password --query value -o tsv

Quick access commands:
- RDP to VM1: mstsc /v:$VM1_PUBLIC_IP
- RDP to VM2: mstsc /v:$VM2_PUBLIC_IP

To remove public IPs after configuration:
az network nic ip-config update -g $RESOURCE_GROUP --nic-name ${VM_NAME_1}-nic -n ipconfig1 --remove publicIpAddress
az network nic ip-config update -g $RESOURCE_GROUP --nic-name ${VM_NAME_2}-nic -n ipconfig1 --remove publicIpAddress
az network public-ip delete -g $RESOURCE_GROUP -n ${VM_NAME_1}-pip --yes
az network public-ip delete -g $RESOURCE_GROUP -n ${VM_NAME_2}-pip --yes

To delete all resources:
az group delete --name $RESOURCE_GROUP --yes
EOF

    print_message $GREEN "\nDeployment information saved to: $deployment_file"
}

# Function to print post-deployment steps
print_post_deployment_steps() {
    print_message $BLUE "\n================================================================================"
    print_message $BLUE "                    POST-DEPLOYMENT CONFIGURATION STEPS"
    print_message $BLUE "================================================================================"

    print_message $YELLOW "\n1. RETRIEVE CREDENTIALS:"
    print_message $NC "   Username: az keyvault secret show --vault-name $KEY_VAULT_NAME --name sql-admin-username --query value -o tsv"
    print_message $NC "   Password: az keyvault secret show --vault-name $KEY_VAULT_NAME --name sql-admin-password --query value -o tsv"

    print_message $YELLOW "\n2. CONNECT TO VMs:"
    print_message $NC "   VM1: mstsc /v:$VM1_PUBLIC_IP"
    print_message $NC "   VM2: mstsc /v:$VM2_PUBLIC_IP"

    print_message $YELLOW "\n3. CONFIGURE PROBE PORT (Inside both VMs):"
    print_message $NC "   # PowerShell command to configure probe port response"
    print_message $NC "   netsh advfirewall firewall add rule name=\"SQL Probe Port\" dir=in action=allow protocol=TCP localport=$PROBE_PORT"

    print_message $YELLOW "\n4. CONFIGURE WINDOWS FAILOVER CLUSTER (inside the VMs):"
    print_message $NC "   - Install the Failover Clustering feature on both VMs."
    print_message $NC "   - Create the Windows Failover Cluster (no shared storage)."
    print_message $NC "   - Tune Azure-specific heartbeat/timeout parameters for the cluster."

    print_message $YELLOW "\n5. CONFIGURE SQL SERVER ALWAYS ON (inside the VMs):"
    print_message $NC "   - Enable the Always On feature on each SQL Server instance."
    print_message $NC "   - Restart the SQL Server service after enabling Always On."
    print_message $NC "   - Create the HADR/mirroring endpoints on each replica."
    print_message $NC "   - Create the Availability Group on the primary replica and join the secondary."

    print_message $YELLOW "\n6. CONFIGURE THE AVAILABILITY GROUP LISTENER:"
    print_message $NC "   - Create the AG Listener using the Load Balancer’s private IP."
    print_message $NC "   - Set the required cluster IP resource parameters (address, probe port, subnet mask, etc.)."

    print_message $YELLOW "\n7. CONFIGURE FIREWALL RULES (Inside VMs):"
    print_message $NC "   Windows Firewall exceptions for:"
    print_message $NC "   - SQL Server (1433)"
    print_message $NC "   - AG Endpoint (5022)"
    print_message $NC "   - Cluster communication (135, 445, 3343)"
    print_message $NC "   - Health probe port ($PROBE_PORT)"

    print_message $YELLOW "\n8. SECURITY - REMOVE PUBLIC IPs:"
    print_message $NC "   After configuration is complete, remove public IPs for security:"
    print_message $NC "   az network public-ip delete -g $RESOURCE_GROUP -n ${VM_NAME_1}-pip --yes"
    print_message $NC "   az network public-ip delete -g $RESOURCE_GROUP -n ${VM_NAME_2}-pip --yes"

    print_message $BLUE "\n================================================================================"
    print_message $GREEN "DEPLOYMENT COMPLETE!"
    print_message $NC "Resource Group: $RESOURCE_GROUP"
    print_message $NC "Load Balancer IP (Listener): $LISTENER_IP"
    print_message $NC "Deployment Info: deployment-info-${TIMESTAMP}.txt"
    print_message $NC "Microsoft Docs: https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/"
    print_message $BLUE "================================================================================"
}

# Main execution
main() {
    START_TIME=$(date +%s)

    # Check Azure CLI login
    print_message $YELLOW "Checking Azure CLI authentication..."
    if ! az account show &>/dev/null; then
        print_message $RED "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi

    # Validate Azure CLI version
    print_message $YELLOW "Checking Azure CLI version..."
    MIN_AZ_VERSION="2.40.0"
    CURRENT_AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "0.0.0")
    if ! printf '%s\n' "$MIN_AZ_VERSION" "$CURRENT_AZ_VERSION" | sort -V | head -n1 | grep -q "$MIN_AZ_VERSION"; then
        print_message $YELLOW "Warning: Azure CLI version $MIN_AZ_VERSION or higher recommended. Current: $CURRENT_AZ_VERSION"
    fi

    # Check if required providers are registered
    print_message $YELLOW "Checking Azure resource providers..."
    for provider in Microsoft.Compute Microsoft.Network Microsoft.KeyVault Microsoft.SqlVirtualMachine; do
        state=$(az provider show --namespace $provider --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")
        if [ "$state" != "Registered" ]; then
            print_message $YELLOW "Registering provider $provider..."
            az provider register --namespace $provider
        fi
    done

    # Deploy infrastructure
    deploy_infrastructure

    # Calculate elapsed time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))

    print_message $GREEN "\n=== Infrastructure Deployment Complete ==="
    print_message $GREEN "Total deployment time: ${MINUTES}m ${SECONDS}s"

    # Print post-deployment steps
    print_post_deployment_steps
}

# Run main function
main
