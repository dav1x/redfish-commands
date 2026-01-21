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

query_redfish() {
    local url=$1
    local response
    response=$(curl --globoff -L -s -k -u "${USERNAME_PASSWORD}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "${url}" 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        return 1
    fi

    echo "$response"
}

extract_json_value() {
    local json=$1
    local key=$2
    echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"\([^"]*\)".*/\1/' | head -1
}

extract_child_odata_id() {
    local json=$1
    local key=$2
    echo "$json" \
        | tr '\n' ' ' \
        | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*{[^}]*\"@odata.id\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | sed 's/.*"@odata.id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
        | head -1
}

extract_member_paths() {
    local json=$1
    local members_block
    members_block=$(echo "$json" \
        | tr '\n' ' ' \
        | sed 's/.*"Members"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/')

    if [[ -n "$members_block" ]] && [[ "$members_block" != "$json" ]]; then
        echo "$members_block" \
            | grep -o '"@odata\.id"[[:space:]]*:[[:space:]]*"/redfish/v1/[^"]*"' \
            | sed 's/.*"\/redfish\/v1\([^"]*\)".*/\1/' \
            | sed 's|^|/redfish/v1|' \
            | sort -u
        return
    fi

    echo "$json" | grep -o '"@odata\.id"[[:space:]]*:[[:space:]]*"/redfish/v1/[^"]*"' \
        | sed 's/.*"\/redfish\/v1\([^"]*\)".*/\1/' \
        | sed 's|^|/redfish/v1|' \
        | sort -u
}

extract_mac_addresses() {
    local json=$1
    echo "$json" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | sort -u
}

print_macs_from_collection() {
    local collection_url=$1
    local collection_label=$2
    local found_any=0

    local collection_json
    collection_json=$(query_redfish "${BASE_URL}${collection_url}" || true)
    [[ -z "$collection_json" ]] && return 1

    local member_paths
    member_paths=$(extract_member_paths "$collection_json")
    [[ -z "$member_paths" ]] && return 1

    echo "${collection_label}:"
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local item_json
        item_json=$(query_redfish "${BASE_URL}${path}" || true)
        [[ -z "$item_json" ]] && continue

        local item_id item_name macs label
        item_id=$(extract_json_value "$item_json" "Id")
        item_name=$(extract_json_value "$item_json" "Name")
        macs=$(extract_mac_addresses "$item_json" | tr '\n' ' ')
        macs=$(echo "$macs" | sed 's/[[:space:]]*$//')

        if [[ -n "$macs" ]]; then
            found_any=1
            label="${item_name:-${item_id:-${path}}}"
            echo "  ${label}: ${macs}"
        fi
    done <<< "$member_paths"
    echo ""

    [[ "$found_any" -eq 1 ]]
}

echo "Querying Redfish endpoint: ${BASE_URL}" >&2
echo "" >&2

SYSTEM_PATH=""

SYSTEMS_JSON=$(query_redfish "${BASE_URL}/redfish/v1/Systems" || true)
if [[ -n "$SYSTEMS_JSON" ]]; then
    SYSTEM_PATH=$(extract_member_paths "$SYSTEMS_JSON" | head -1 || true)
fi

if [[ -z "$SYSTEM_PATH" ]]; then
    for path in "/redfish/v1/Systems/Self" "/redfish/v1/Systems/1" "/redfish/v1/Systems/System.Embedded.1"; do
        if query_redfish "${BASE_URL}${path}" > /dev/null 2>&1; then
            SYSTEM_PATH="${path}"
            break
        fi
    done
fi

if [[ -z "$SYSTEM_PATH" ]]; then
    echo "ERROR: Unable to discover Systems path" >&2
    exit 1
fi

echo "Using Systems path: ${SYSTEM_PATH}" >&2
echo "" >&2

found=0

if print_macs_from_collection "${SYSTEM_PATH}/EthernetInterfaces" "EthernetInterfaces"; then
    found=1
fi

if [[ "$found" -eq 0 ]]; then
    NETWORK_JSON=$(query_redfish "${BASE_URL}${SYSTEM_PATH}/NetworkInterfaces" || true)
    if [[ -n "$NETWORK_JSON" ]]; then
        NETWORK_PATHS=$(extract_member_paths "$NETWORK_JSON")
        if [[ -n "$NETWORK_PATHS" ]]; then
            echo "NetworkInterfaces:" 
            while IFS= read -r net_path; do
                [[ -z "$net_path" ]] && continue
                NET_JSON=$(query_redfish "${BASE_URL}${net_path}" || true)
                [[ -z "$NET_JSON" ]] && continue

                NET_ID=$(extract_json_value "$NET_JSON" "Id")
                NET_NAME=$(extract_json_value "$NET_JSON" "Name")
                NET_MACS=$(extract_mac_addresses "$NET_JSON" | tr '\n' ' ')
                NET_MACS=$(echo "$NET_MACS" | sed 's/[[:space:]]*$//')

                if [[ -n "$NET_MACS" ]]; then
                    found=1
                    label="${NET_NAME:-${NET_ID:-${net_path}}}"
                    echo "  ${label}: ${NET_MACS}"
                fi

                PORTS_URL=$(extract_child_odata_id "$NET_JSON" "NetworkPorts")
                if [[ -z "$PORTS_URL" ]]; then
                    PORTS_URL=$(extract_child_odata_id "$NET_JSON" "Ports")
                fi
                if [[ -n "$PORTS_URL" ]]; then
                    PORTS_JSON=$(query_redfish "${BASE_URL}${PORTS_URL}" || true)
                    PORT_PATHS=$(extract_member_paths "$PORTS_JSON" || true)
                    while IFS= read -r port_path; do
                        [[ -z "$port_path" ]] && continue
                        PORT_JSON=$(query_redfish "${BASE_URL}${port_path}" || true)
                        [[ -z "$PORT_JSON" ]] && continue
                        PORT_ID=$(extract_json_value "$PORT_JSON" "Id")
                        PORT_NAME=$(extract_json_value "$PORT_JSON" "Name")
                        PORT_MACS=$(extract_mac_addresses "$PORT_JSON" | tr '\n' ' ')
                        PORT_MACS=$(echo "$PORT_MACS" | sed 's/[[:space:]]*$//')

                        if [[ -n "$PORT_MACS" ]]; then
                            found=1
                            label="${PORT_NAME:-${PORT_ID:-${port_path}}}"
                            echo "  ${label}: ${PORT_MACS}"
                        fi
                    done <<< "$PORT_PATHS"
                fi
            done <<< "$NETWORK_PATHS"
            echo ""
        fi
    fi
fi

if [[ "$found" -eq 0 ]]; then
    CHASSIS_PATH=""
    CHASSIS_JSON=$(query_redfish "${BASE_URL}/redfish/v1/Chassis" || true)
    if [[ -n "$CHASSIS_JSON" ]]; then
        CHASSIS_PATH=$(extract_member_paths "$CHASSIS_JSON" | head -1 || true)
    fi

    if [[ -z "$CHASSIS_PATH" ]]; then
        for path in "/redfish/v1/Chassis/1" "/redfish/v1/Chassis/chassis" "/redfish/v1/Chassis/System.Embedded.1"; do
            if query_redfish "${BASE_URL}${path}" > /dev/null 2>&1; then
                CHASSIS_PATH="${path}"
                break
            fi
        done
    fi

    if [[ -n "$CHASSIS_PATH" ]]; then
        if print_macs_from_collection "${CHASSIS_PATH}/NetworkAdapters" "NetworkAdapters"; then
            found=1
        else
            ADAPTERS_JSON=$(query_redfish "${BASE_URL}${CHASSIS_PATH}/NetworkAdapters" || true)
            ADAPTER_PATHS=$(extract_member_paths "$ADAPTERS_JSON" || true)
            if [[ -n "$ADAPTER_PATHS" ]]; then
                echo "NetworkPorts:"
                while IFS= read -r adapter_path; do
                    [[ -z "$adapter_path" ]] && continue
                    ADAPTER_JSON=$(query_redfish "${BASE_URL}${adapter_path}" || true)
                    [[ -z "$ADAPTER_JSON" ]] && continue

                    PORTS_URL=$(extract_child_odata_id "$ADAPTER_JSON" "NetworkPorts")
                    if [[ -z "$PORTS_URL" ]]; then
                        PORTS_URL=$(extract_child_odata_id "$ADAPTER_JSON" "Ports")
                    fi
                    [[ -z "$PORTS_URL" ]] && continue
                    PORTS_JSON=$(query_redfish "${BASE_URL}${PORTS_URL}" || true)
                    PORT_PATHS=$(extract_member_paths "$PORTS_JSON" || true)
                    while IFS= read -r port_path; do
                        [[ -z "$port_path" ]] && continue
                        PORT_JSON=$(query_redfish "${BASE_URL}${port_path}" || true)
                        [[ -z "$PORT_JSON" ]] && continue
                        PORT_ID=$(extract_json_value "$PORT_JSON" "Id")
                        PORT_NAME=$(extract_json_value "$PORT_JSON" "Name")
                        PORT_MACS=$(extract_mac_addresses "$PORT_JSON" | tr '\n' ' ')
                        PORT_MACS=$(echo "$PORT_MACS" | sed 's/[[:space:]]*$//')

                        if [[ -n "$PORT_MACS" ]]; then
                            found=1
                            label="${PORT_NAME:-${PORT_ID:-${port_path}}}"
                            echo "  ${label}: ${PORT_MACS}"
                        fi
                    done <<< "$PORT_PATHS"
                done <<< "$ADAPTER_PATHS"
                echo ""
            fi
        fi
    fi
fi

if [[ "$found" -eq 0 ]]; then
    echo "No MAC addresses found via Redfish." >&2
    exit 1
fi
