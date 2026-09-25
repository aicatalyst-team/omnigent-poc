# Omnigent on OpenShift with OpenShell POC

[Omnigent](https://omnigent.ai/) is a meta-harness for AI agents.

In this POC we are running it on Open Shift using OpenShell for sandboxing the agents.

The demo folder contains the demo material.

Demo link (to be added here).

## Dockerfile

This is a custom UBI10 based image with a custom policy to allow access to a local Lite Maas instance.

A custom Opencode configuration allows connection to this LiteMaaS.

API tokens are expected to be passed in through environment variables as secrets.

Please deploy on OpenShift with the accompanying Kustomize at the `scShiftShell` branch of the `https://github.com/aicatalyst-team/omnigent` fork:

[https://github.com/aicatalyst-team/omnigent/tree/scShiftShell](https://github.com/aicatalyst-team/omnigent/tree/scShiftShell)
