#!/bin/bash
BMC_ADDRESS=$1
USERNAME_PASSWORD=$2
ISO="$3"

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{"ResetType": "ForceOff"}' -X POST https://$BMC_ADDRESS/redfish/v1/Systems/Self/Actions/ComputerSystem.Reset

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{}' -X POST https://$BMC_ADDRESS/redfish/v1/Managers/Self/VirtualMedia/1/Actions/VirtualMedia.EjectMedia 

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d  "{"\"Image\"": "\"${ISO}\""}" -X POST https://$BMC_ADDRESS/redfish/v1/Managers/Self/VirtualMedia/1/Actions/VirtualMedia.InsertMedia 

curl --globoff  -L -w "%{http_code} %{url_effective}\\n"  -ku ${USERNAME_PASSWORD}  -H "Content-Type: application/json" -H "Accept: application/json" -d '{"Boot":{ "BootSourceOverrideEnabled": "Once", "BootSourceOverrideTarget": "Cd", "BootSourceOverrideMode": "UEFI"}}' -X PATCH https://$BMC_ADDRESS/redfish/v1/Systems/Self


curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{"ResetType": "ForceOn"}' -X POST https://$BMC_ADDRESS/redfish/v1/Systems/Self/Actions/ComputerSystem.Reset

