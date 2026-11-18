# cnp-flux-config
Flux v2 config for CFT AKS clusters

## Repo Structure

Please see [Repo setup](docs/repo-setup.md) for details on how this repo is organized and meant to work.

## Adding an app to flux

- All App deployments are managed through `HelmRelease` manifests.
- Any new/existing application that is getting added to an environment for the first time should use [Flux v2](docs/app-deployment-v2.md).

## Sandbox Jenkins Java mitigation

For CVE-2026-114938, the [sandbox Jenkins overlay](apps/jenkins/jenkins/sbox-intsvc/jenkins.yaml)
sets `JDK_JAVA_OPTIONS=-XX:-UseBASE64Intrinsics` for the controller, Java build
processes and Kubernetes agent containers. The [VM agent overlay](apps/jenkins/jenkins/sbox-intsvc/jenkins-azure-vm-agent.yaml)
sets the same flag in agent `jvmOptions`. Existing Java options are preserved;
production and shared defaults are unchanged.

After an approved rollout, confirm the controller has restarted and drain/recreate
existing agents so their JVMs pick up the mitigation. Check
`jcmd <pid> VM.flags -all` for `UseBASE64Intrinsics = false` on the controller
and each agent type, and run a representative sandbox build checking the same flag
in its build JVMs. Pipeline-defined containers or environment overrides need
separate verification; Jenkins environment variables do not automatically enter
nested Docker containers. `JDK_JAVA_OPTIONS` requires Java 9 or later, so verify
any older build toolchains before rollout.

This is a temporary mitigation, not a JDK patch. Remove the flag from all the
above locations only after patched JDK images are deployed and verified.

## Encrypting Secrets With Sops

Secrets can be stored in this repository but they must be encrypted using the SOPS tool.

[Click here for info on how to setup SOPS](docs/secrets-sops-encryption.md).

## Preventing commit of secrets

To prevent unencrypted secrets being committed to this repository, a pre-commit hook has been provided via `.pre-commit-config.yaml`

To install it, run `brew install pre-commit` and then `pre-commit install` on macOS or Linux (with homebrew).

On the first commit after installing, `pyyaml` will be downloaded and installed to parse the yaml files in the repo.

This will take a bit longer than normal to install but future commits should take place at the normal speed.

This hook will also run as a github action to ensure bypass has not occurred.

The action can be found at [sops-secrets](.github/workflows/sops-secrets.yml)

### SOPs

Sops fails linting by default as we require 2 spaces while it uses 4 spaces.
You can use `yq` to fix this:

```
yq eval -I 2 --inplace apps/mi/mi-adf-shir/sbox/mi-adf-auth-values.enc.yaml
```

upstream issue: https://github.com/mozilla/sops/issues/900

## Rebooting nodes with kured

[Documentation](docs/reboot-node-using-kured.md)

## Upgrading flux v2

Update `flux` cli in your local and run 
 ```bash
flux install --export > apps/flux-system/base/gotk-components.yaml
flux install --export --components source-controller,kustomize-controller,helm-controller,notification-controller,image-reflector-controller,image-automation-controller > apps/flux-system/ptl-intsvc/base/gotk-components.yaml 
```

As Flux in PTL makes use of optional GOTK image automation components, we generate a second `gotk-components.yaml` file just for PTL. Information about Flux GOTK components can be found [here](https://fluxcd.io/flux/components/). 

Both files are maintained by Renovate after generation.
 