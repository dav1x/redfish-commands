# redfish-commands
Useful Redfish Commands

This is a container image with some embedded curl commands for redfish ISOs for supermicro and ZT systems.

Usage:

```
$ podman run quay.io/dphillip/boot-redfish-iso -r 192.168.x.y -u Administrator -p password -i http://192.168.x.y/zt-worker2.iso
```

For example:

```
ISO_URL=$(oc get infraenvs.agent-install.openshift.io -n smc-sno1 -o jsonpath='{.items[].status.isoDownloadURL}')

$ podman run --net=host quay.io/dphillip/boot-redfish-iso:latest -r bmc_ip -u bmc_user -p bmc_password -i ${ISO_URL)
```
