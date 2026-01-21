#!/usr/bin/env bash
set -eoE pipefail

usage() {
    echo "${@}"
    echo "Usage: $0 -r bmc-address -u user -p password" 1>&2
    exit 1
}

# Parse command line arguments
if [[ $# -lt 6 ]]; then
    usage "Insufficient number of parameters"
fi

while getopts r:u:p: option; do
    case "${option}" in
        r)
            HOST=${OPTARG};;
        u)
            USER=${OPTARG};;
        p)
            PASSWORD=${OPTARG};;
        *)
            usage;;
    esac
done
shift $((OPTIND-1))

# Validate required parameters
if [[ -z "$HOST" ]] || [[ -z "$USER" ]] || [[ -z "$PASSWORD" ]]; then
    usage "Missing required parameters"
fi

USERNAME_PASSWORD="${USER}:${PASSWORD}"
BASE_URL="https://${HOST}"

echo "Querying Redfish endpoint: ${BASE_URL}" >&2
echo "" >&2

# Function to make a Redfish API call and extract JSON
query_redfish() {
    local url=$1
    local response=$(curl --globoff -L -s -k -u "${USERNAME_PASSWORD}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "${url}" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        return 1
    fi
    
    echo "$response"
}

# Function to extract value from JSON using grep/sed (simple approach)
extract_json_value() {
    local json=$1
    local key=$2
    echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"\([^"]*\)".*/\1/' | head -1
}

# Function to extract array member URIs from Members array
extract_members() {
    local json=$1
    # Try to extract from Members array structure: "Members": [{"@odata.id": "/redfish/v1/..."}]
    local member=$(echo "$json" | grep -o '"@odata\.id"[[:space:]]*:[[:space:]]*"/redfish/v1/[^"]*"' | sed 's/.*"\/redfish\/v1\([^"]*\)".*/\1/' | head -1)
    
    if [[ -n "$member" ]]; then
        echo "/redfish/v1${member}"
    else
        # Fallback: try to find any /redfish/v1/ path
        echo "$json" | grep -o '"/redfish/v1/[^"]*"' | sed 's/"//g' | head -1
    fi
}

# Query service root
echo "Discovering Redfish paths..." >&2
SERVICE_ROOT=$(query_redfish "${BASE_URL}/redfish/v1/")

if [[ -z "$SERVICE_ROOT" ]]; then
    echo "ERROR: Failed to connect to Redfish service root" >&2
    exit 1
fi

# Query Systems collection
SYSTEMS_URL="${BASE_URL}/redfish/v1/Systems"
SYSTEMS_JSON=$(query_redfish "${SYSTEMS_URL}")

if [[ -n "$SYSTEMS_JSON" ]]; then
    # Try to extract the first member
    SYSTEM_PATH=$(extract_members "$SYSTEMS_JSON")
    
    if [[ -n "$SYSTEM_PATH" ]]; then
        # Extract just the path part (remove base URL)
        SYSTEM_PATH=$(echo "$SYSTEM_PATH" | sed "s|${BASE_URL}||")
        echo "Systems Path: ${SYSTEM_PATH}"
    else
        # Fallback: try common paths
        for path in "/redfish/v1/Systems/Self" "/redfish/v1/Systems/1" "/redfish/v1/Systems/System.Embedded.1"; do
            if query_redfish "${BASE_URL}${path}" > /dev/null 2>&1; then
                echo "Systems Path: ${path}"
                SYSTEM_PATH="${path}"
                break
            fi
        done
    fi
else
    echo "WARNING: Could not query Systems collection" >&2
fi

# Query Managers collection
MANAGERS_URL="${BASE_URL}/redfish/v1/Managers"
MANAGERS_JSON=$(query_redfish "${MANAGERS_URL}")

if [[ -n "$MANAGERS_JSON" ]]; then
    # Try to extract the first member
    MANAGER_PATH=$(extract_members "$MANAGERS_JSON")
    
    if [[ -n "$MANAGER_PATH" ]]; then
        MANAGER_PATH=$(echo "$MANAGER_PATH" | sed "s|${BASE_URL}||")
        echo "Managers Path: ${MANAGER_PATH}"
        
        # Try to discover VirtualMedia
        VIRTUALMEDIA_URL="${BASE_URL}${MANAGER_PATH}/VirtualMedia"
        VIRTUALMEDIA_JSON=$(query_redfish "${VIRTUALMEDIA_URL}")
        
        if [[ -n "$VIRTUALMEDIA_JSON" ]]; then
            # Extract all VirtualMedia member paths
            VIRTUALMEDIA_PATHS=$(echo "$VIRTUALMEDIA_JSON" | grep -o '"@odata\.id"[[:space:]]*:[[:space:]]*"/redfish/v1/[^"]*"' | sed 's/.*"\/redfish\/v1\([^"]*\)".*/\1/' | sed 's|^|/redfish/v1|')
            
            if [[ -n "$VIRTUALMEDIA_PATHS" ]]; then
                while IFS= read -r path; do
                    [[ -n "$path" ]] && echo "VirtualMedia Path: ${path}"
                done <<< "$VIRTUALMEDIA_PATHS"
            fi
        fi
    else
        # Fallback: try common paths
        for path in "/redfish/v1/Managers/1" "/redfish/v1/Managers/Self" "/redfish/v1/Managers/iDRAC.Embedded.1"; do
            if query_redfish "${BASE_URL}${path}" > /dev/null 2>&1; then
                echo "Managers Path: ${path}"
                MANAGER_PATH="${path}"
                break
            fi
        done
    fi
else
    echo "WARNING: Could not query Managers collection" >&2
fi

# Output summary
echo ""
echo "Summary of discovered paths:"
if [[ -n "$SYSTEM_PATH" ]]; then
    echo "  Systems: ${SYSTEM_PATH}"
    echo "  Systems Reset Action: ${SYSTEM_PATH}/Actions/ComputerSystem.Reset"
    echo "  Systems Boot Config: ${SYSTEM_PATH}"
fi
if [[ -n "$MANAGER_PATH" ]]; then
    echo "  Managers: ${MANAGER_PATH}"
fi
if [[ -n "$VIRTUALMEDIA_PATHS" ]]; then
    while IFS= read -r path; do
        if [[ -n "$path" ]]; then
            echo "  VirtualMedia: ${path}"
            echo "    Insert: ${path}/Actions/VirtualMedia.InsertMedia"
            echo "    Eject: ${path}/Actions/VirtualMedia.EjectMedia"
        fi
    done <<< "$VIRTUALMEDIA_PATHS"
fi
