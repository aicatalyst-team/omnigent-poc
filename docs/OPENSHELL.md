# Install openshell locally

## Installing OpenShell on Kind

To install openshell locally on kind use:

```bash
kind create cluster

# Install Agent Sandbox
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox.yaml

kubectl create namespace openshell

helm install openshell   oci://ghcr.io/nvidia/openshell/helm-chart --version 0.1.4  --namespace openshell   --values ./openshell-values.yaml --set server.drivers.kubernetes.allowDriverConfig=true --set server.auth.allowUnauthenticatedUsers=true --set server.disableTls=true
```

## Installing Openshell on Openshift

There are OpenShift specific instructions in the NVIDIA documentation at
[https://docs.nvidia.com/openshell/latest/kubernetes/openshift](https://docs.nvidia.com/openshell/latest/kubernetes/openshift).

## Running Openshell terminal

Port forward from the openshell Pod on port 8080 to your local machine.

Then set the Gateway with `openshell gateway` command.

## Adding Profiles and Providers

> The convenience script [load-openshell-profiles.sh](../scripts/load-openshell-profiles.sh) will create or update these `profiles` and `providers` depending on the environment variables you have set in your terminal.

Set the following Env Vars locally on your terminal:

* OPENAI_API_KEY
* GEMINI_API_KEY
* ANTHROPIC_API_KEY or CLAUDE_API_KEY
* LITEMAAS_API_KEY
* GITHUB_TOKEN or GH_TOKEN

> If there are any you don't have just leave it out

Then to add a profile from the [profiles](../profiles/) folder:

```bash
openshell profile lint -f profiles/openai.yaml --workspace omnigent

openshell profile import -f profiles/openai.yaml --workspace omnigent

openshell profile list --workspace omnigent
```

The to add a credential to the profile, set the credential as a local env var:

```bash
openshell provider create --name my-codex --type openai --credential OPENAI_API_KEY=$OPENAI_API_KEY --workspace omnigent

openshell provider list --workspace omnigent
```

> The providers can then be added to Omnigent's `server-config.yaml` so that they will be attached to new sandboxes.
