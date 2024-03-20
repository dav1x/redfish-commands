#!/usr/bin/env bash
set -eoE pipefail

usage()         {
        echo "${@}"
        echo "Usage: $0 -t hw-type -r bmc-address -u user -p password -i http://iso-url" 1>&2;
        exit 1;
}

if [[ $# -lt 5 ]]; then
	echo $#
        usage "Insufficient number of parameters"
fi

while getopts t:r:u:p:i: option; do
        case "${option}" in
                t)      
                        HW=${OPTARG};;
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


echo HW = $HW
echo HOST = $HOST
echo USER = $USER
echo PASSWORD = $PASSWORD
echo ISO_URL = $ISO_URL


if ! curl --output /dev/null --silent --head --fail "$ISO_URL"; then
          usage "******* ISO does not exist in the provided url: $ISO_URL"
fi

case "${HW}" in 
	"smc")
		echo smcBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"
		./smcBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"
		;;
	"zt")
		echo ztBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"
		./ztBootFromCDFull.sh $HOST $USER:$PASSWORD "$ISO_URL"
		;;
	*)
                usage;;
esac


