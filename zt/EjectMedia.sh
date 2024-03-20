#!/bin/bash
BMC_ADDRESS=$1
USERNAME_PASSWORD=$2

curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku ${USERNAME_PASSWORD} -H "Content-Type: application/json" -H "Accept: application/json" -d '{}' -X POST https://$BMC_ADDRESS/redfish/v1/Managers/Self/VirtualMedia/1/Actions/VirtualMedia.EjectMedia 
