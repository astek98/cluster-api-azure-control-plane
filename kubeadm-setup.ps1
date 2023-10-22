az account set --subscription ea23f33b-f226-4c3f-9c14-aabb8b63b8c8
az group create -l eastus -n k0s-rgp-001
$grp_name="k0smotron-rgp"
az group create -l eastus -n $grp_name

az vm create `
--count 4 --name knode- `
--size Standard_B2s `
--resource-group  $grp_name `
--image Ubuntu2204 `
--admin-username azureuser --admin-password Geico@12345! `
--os-disk-delete-option Delete `
--nic-delete-option Delete `
--% --public-ip-address ""


az vm boot-diagnostics enable --ids $(az vm list -g $grp_name --query "[].id" -o tsv)
az vm auto-shutdown --ids $(az vm list -g $grp_name --query "[].id" -o tsv) --time 2300


az vm start --ids $(az vm list -g $grp_name --query "[].id" -o tsv)

az vm stop --ids $(az vm list -g $grp_name --query "[].id" -o tsv)

az vm delete --ids $(az vm list -g $grp_name --query "[].id" -o tsv) --no-wait --yes

az vm show -g $grp_name -n vm-node-0 -d -u

az vm open-port --resource-group $grp_name --name kmono --port 3389