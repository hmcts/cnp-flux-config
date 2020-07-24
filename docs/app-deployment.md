# Application Configuration

The section covers how to configure a new application in this repository to deploy to various environments.
We use [kustomize](https://github.com/kubernetes-sigs/kustomize) for templating/patching manifests in this repo. 

Note: Some of these scripts need you to [install yq](https://mikefarah.gitbook.io/yq/)

## Namespace

All the applications owned by a team are deployed to a single namespace.
 
### Create a namespace manifest

1. Run [add-namespace.sh](/bin/add-namespace.sh) with your namespace( usually team name) and team build notices slack channel.
   ```bash
    ./bin/add-namespace.sh <your namespace> <team slack channel>
   ```
   
### Add kustomization to a environment

1. Run [add-namespace-to-env.sh](/bin/add-namespace-to-env.sh) with namespace and environment.
   ```bash
    ./bin/add-namespace-to-env.sh <your namespace> <environment>
   ```

## Application

All application deployments are managed with `HelmRelease`.

### Add an application manifest

1. Standard naming convention for your application (`<application-name>`) is `<product>-<component>`. 
2. Add a `HelmRelease` manifest in `/k8s/namespaces/<your-namespace>/<application-name>/<application-name>.yaml`. [See example](/k8s/namespaces/rpe/draft-store-service/draft-store-service.yaml)


### Add application to all environments

Below adds Application to all the environments you have [added your kustomization](#Add-kustomization-to-a-environment). 
If you want to add a new app only to a one environment, see [Add application to only one environment](#Add-application-to-only-one-environment)

1. Add `- <application-name>/<application-name>.yaml`  to `bases:` list in `/k8s/namespaces/<your-namespace>/kustomization.yaml`

### Add application to only one environment

1. Add `- <application-name>/<application-name>.yaml`  to `bases:` list in `/k8s/<env>/common-overlay/<your-namespace>/kustomization.yaml`
