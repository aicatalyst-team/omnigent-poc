# Omnigent on OpenShift with OpenShell POC

[Omnigent](https://omnigent.ai/) is a meta-harness for AI agents.

In this POC we are running it on OpenShift using OpenShell for sandboxing the agents.

The demo folder contains the demo material.

Demo [link](https://drive.google.com/file/d/1pBVeMpGJ6WSRzDa9hBwcAi3kjqnwZdWa/view?usp=drive_link).

## Dockerfile

This is a custom UBI10 based image with a custom policy to allow access to a local Lite Maas instance.

A custom Opencode configuration allows connection to this LiteMaaS.

API tokens are expected to be passed in through OpenShell providers [see](docs/OPENSHELL.md).

Please deploy on OpenShift with the accompanying Kustomize at the `scShiftShell` branch of the `https://github.com/aicatalyst-team/omnigent` fork:

[https://github.com/aicatalyst-team/omnigent/tree/scShiftShell](https://github.com/aicatalyst-team/omnigent/tree/scShiftShell)

## Special build of Omnigent

The branch [scOpenshellProviders](https://github.com/aicatalyst-team/omnigent/tree/scOpenshellProviders) contains enhancements to Omnigent to allow it to configure new sandboxes with:

* node selector criteria
* runtime selection
* list of providers

> These will be pushed upstream as a PR when finished.
