# Install openshell locally on Kind

To install openshell locally on kind use:

```bash
kind create cluster

# Install Agent Sandbox
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox.yaml

kubectl create namespace openshell

helm upgrade openshell   oci://ghcr.io/nvidia/openshell/helm-chart   --namespace openshell   --reuse-values   --set server.auth.allowUnauthenticatedUsers=true --set server.disableTls=true
```

Then to use add a profile:

```bash
openshell profile lint -f git/aicatalyst-team/omnigent-poc/profiles/openai.yaml 

openshell profile import -f git/aicatalyst-team/omnigent-poc/profiles/openai.yaml 

openshell profile list
```
