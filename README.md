# Omnigent on OpenShift with OpenShell POC

[Omnigent](https://omnigent.ai/) is a meta-harness for AI agents.

In this POC we are running it on OpenShift using OpenShell for sandboxing the agents.

The demo folder contains the demo material.

Video Demo [link](https://drive.google.com/file/d/1pBVeMpGJ6WSRzDa9hBwcAi3kjqnwZdWa/view?usp=drive_link).

## Dockerfile

This is a custom OpenShell compliant UBI10 based image with:

* Installation of:
  * Codex
  * ClaudeCode
  * Antigravity
  * OpenCode
  * GH command
* a custom OpenShell policy to allow access to these harnesses
* opencode configuration to a local Lite Maas instance (in [opencode.json](./images/opencode.json)) It's just an example, ignore it if you don't need it
* Includes python WebSocket package > v15

This is pushed to `quay.io/aicatalyst/omnigent-host-openshell`.

## Deployment

API tokens are expected to be passed in through OpenShell providers. See [OPENSHELL.md](docs/OPENSHELL.md).

Please deploy on OpenShift with the accompanying Kustomize at the `scShiftShell` branch of the `https://github.com/aicatalyst-team/omnigent` fork:

[https://github.com/aicatalyst-team/omnigent/tree/scShiftShell](https://github.com/aicatalyst-team/omnigent/tree/scShiftShell)

with `kubectl apply -k deploy/kubernetes/overlays/openshift-openshell/`.

The Kustomize deploys:

* `quay.io/aicatalyst/omnigent-host-openshell` (from above) as the sandbox container
  * referenced in `server-confg.yaml`
* `quay.io/aicatalyst/omnigent-server-openshell` (see below) as the omnigent runtime
  * referenced in `deployment.yaml`


### Server Configuration

Inside the Kustomization, the `server-config.yaml` controls how Sandboxes are created by Omnigent.

It sets:

* the sandbox provider: `openshell`
* Optionally a list of OpenShell (credential) `providers`
* Optionally a `node_selector`
* Optionally configuration of the runtime class (default `runc`)
* Optionally an OpenShell `workspace` to create sandboxes in
  * Note the OpenShell `providers` must be in the same `workspace`.
* The name of the `image` for new sandboxes: `quay.io/aicatalyst/omnigent-host-openshell:latest` in our case.

### Special build of Omnigent

The branch [scOpenshellProviders](https://github.com/aicatalyst-team/omnigent/tree/scOpenshellProviders) contains enhancements to Omnigent to allow it to configure new sandboxes with:

* node selector criteria
* runtime selection
* list of providers

This builds `quay.io/aicatalyst/omnigent-server-openshell` and is referenced by the Kustomize above.

> These will be pushed upstream as a PR when finished.
