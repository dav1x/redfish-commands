#!/bin/bash
BMC_ADDRESS=$1
USERNAME_PASSWORD=$2

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{"ResetType": "ForceOff"}' -X POST https://$BMC_ADDRESS/redfish/v1/Systems/1/Actions/ComputerSystem.Reset
