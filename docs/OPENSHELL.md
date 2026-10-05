# Install openshell locally

## Installing on Kind

To install openshell locally on kind use:

```bash
kind create cluster

# Install Agent Sandbox
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox.yaml

kubectl create namespace openshell

helm upgrade openshell   oci://ghcr.io/nvidia/openshell/helm-chart --version 0.1.3-pre.3  --namespace openshell   --reuse-values   --set server.auth.allowUnauthenticatedUsers=true --set server.disableTls=true
```

> Note this uses 0.1.3-pre.3 as that's the latest stable release as of 5 Oct 2026.
> Update this when a newer version is available.
> Note Openshell 0.1.2 does not contain the fix for issue [#3994](https://github.com/NVIDIA/OpenShell/issues/3994).

## Installing Openshell on Openshift

To run properly Openshell requires a kernel >=5.19. RHCOS 9 on OpenShift cannot provide this as it is pinned to 5.14.

Enable Tech Preview on OpenShift 4.21 or 4.22 and use the MultiOS feature to switch nodes to RHCOS 10 to enable Kernel 6.12.

WARNING: This is not reversible. You will not be able to upgrade the cluster to minor versions, and all nodes on the cluster will have to be moved to RHCOS 10.

There are OpenShift specific instructions in the NVIDIA documentation at
[https://docs.nvidia.com/openshell/latest/kubernetes/openshift](https://docs.nvidia.com/openshell/latest/kubernetes/openshift).

## Adding Profiles and Providers

Then to add a profile from the [profiles](../profiles/) folder:

```bash
openshell profile lint -f profiles/openai.yaml

openshell profile import -f profiles/openai.yaml

openshell profile list
```

The to add a credential to the profile, set the credential as a local env var:

```bash
openshell provider create --name my-codex --type openai --credential OPENAI_API_KEY=$OPENAI_API_KEY

openshell provider list
```

> The providers can then be added to Omnigent's `server-config.yaml` so that they will be automatically attached to new sandboxes.
