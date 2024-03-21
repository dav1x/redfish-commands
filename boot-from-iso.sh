#!/usr/bin/env bash
set -eoE pipefail

usage()         {
        echo "${@}"
        echo "Usage: $0 -r bmc-address -u user -p password -i http://iso-url" 1>&2;
        exit 1;
}

if [[ $# -lt 4 ]]; then
	echo $#
        usage "Insufficient number of parameters"
fi

while getopts r:u:p:i: option; do
        case "${option}" in
                r)
                        HOST=${OPTARG};;
                u)
                        USER=${OPTARG};;
                p)
                        PASSWORD=${OPTARG};;
                i)
                        ISO_URL=${OPTARG}
                        [[ $ISO_URL =~ http://.* ]] || usage "Iso should be with http prefix"
                        ;;
                *)
                        usage;;
        esac
done
shift $((OPTIND-1))


echo HOST = $HOST
echo USER = $USER
echo PASSWORD = $PASSWORD
echo ISO_URL = $ISO_URL


if ! curl --output /dev/null --silent --head --fail "$ISO_URL"; then
          usage "******* ISO does not exist in the provided url: $ISO_URL"
fi



if curl -f -s -o /dev/null -w "%{http_code}" -ku "${USER}:${PASSWORD}" https://${HOST}/redfish/v1/Systems/Self;then

	echo ztBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"
        ./ztBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"

fi

if curl -f -s -o /dev/null -w "%{http_code}" -ku "${USER}:${PASSWORD}" https://${HOST}/redfish/v1/Systems/1;then

	echo smcBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"
	./smcBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"

fi
