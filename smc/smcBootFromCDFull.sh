#!/bin/bash
BMC_ADDRESS=$1
USERNAME_PASSWORD=$2
ISO="$3"

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{"ResetType": "ForceOff"}' -X POST https://$BMC_ADDRESS/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# older SMC curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d "{}" -X POST https://$BMC_ADDRESS/redfish/v1/Managers/1/VirtualMedia/VirtualMedia2/Actions/VirtualMedia.EjectMedia
curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d "{}" -X POST https://$BMC_ADDRESS/curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d "{}" -X POST https://$BMC_ADDRESS/redfish/v1/Managers/1/VM1/CfgCD/Actions/IsoConfig.UnMount


# older SMC curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d "{"\"Image\"": "\"${ISO}\""}" -X POST https://$BMC_ADDRESS/redfish/v1/Managers/1/VirtualMedia/VirtualMedia2/Actions/VirtualMedia.InsertMedia

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d "{"\"Image\"": "\"${ISO}\""}" -X POST https://$BMC_ADDRESS//redfish/v1/Managers/1/VM1/CfgCD/Actions/IsoConfig.Mount

curl --globoff  -L -w "%{http_code} %{url_effective}\\n"  -ku ${USERNAME_PASSWORD}  -H "Content-Type: application/json" -H "Accept: application/json" -d '{"Boot":{ "BootSourceOverrideEnabled": "Once", "BootSourceOverrideTarget": "Cd", "BootSourceOverrideMode": "UEFI"}}' -X PATCH https://$BMC_ADDRESS/redfish/v1/Systems/1

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{"ResetType": "ForceOn"}' -X POST https://$BMC_ADDRESS/redfish/v1/Systems/1/Actions/ComputerSystem.Reset
