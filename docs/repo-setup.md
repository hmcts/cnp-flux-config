## Repo Setup

Below section covers how the repo is set up to handle multiple environments and teams with Flux V2.

### Key considerations

- Directory stucture is team/namespace focussed than cluster focussed so that moving teams config to different repos and managing permissions is easy.
- Every namespace is a directory in [apps/](../apps/)
- Image Automation is run only from CFTPTL cluster and related components/CRDs are installed/created only on CFTPTL.
- Every team/namespace has a separate Flux Kustomization so that one team won't break another team's config.
- Everything is Kustomized by default aligning with Flux V2.

### Kustomization Naming

- [flux-system Flux kustomization](../apps/flux-system/sbox/00/kustomize.yaml)- flux specific CRD, file named kustomize.yaml to avoid confusion with k8s kustomization.yaml files. It gives path and repo from which flux controller should apply from.
- [namespace flux kustomization](../apps/rpe/base/kustomize.yaml) - A Flux Kustomize file for specific namespace having the path flux should look at.
- [Cluster Overlay](../clusters/sbox/00/kustomization.yaml) - overlay of a cluster which normally patches on top of Env Base defined next.
- [Env Base](../clusters/sbox/base/kustomization.yaml) - A base kustomization for an environment which generally includes Flux Kustomizations for all namespaces in that cluster.
- [namespace base kustomization](../apps/rpe/base/kustomization.yaml) - A base kustomization including manifests that are common across all environments except special cases like preview.
- [namespace env overlay]((../apps/rpe/aat/base/kustomization.yaml)) - Overlay of a namespace base kustomization with env specific patches related to that namespace.
- [default namespace base](../apps/base/kustomization.yaml) - default manifests needed for all namespaces but templated which are set in [namespace Flux kustomization](../apps/rpe/base/kustomize.yaml)
- [namespace automation kustomization](../apps/rpe/automation) - includes all automation CRDs for a namespace

### Folder Structure


    ├── apps                                        # apps directory containing all namespaces and manifests
    │   │
    │   └──<base>
    │   │  └── kustomization.yaml                   # Default namespace base  kustomization that all teams extend
    │   │  └── kustomize.yaml                       # defaults applied to all base team kustomizations
    │   │  └── alert/provider.yaml                  # Default manifests for all namespaces to enable notifications
    │   │  └── ...
    │   │
    │   ├── <namespace>                             # One folder per namespace containing workloads.
    │   │   ├── automation
    │   │   │   └── kustomization.yaml              # Namespace specific automation kustomization referring to all image repos/policies.
    │   │   │
    │   │   ├── base
    │   │   │   └── kustomization.yaml              # namespace base kustomization that is applied to all clusters (except preview).
    │   │   │   └── kustomize.yaml                  # namespace flux kustomization containing the path flux should look at.
    │   │   │
    │   │   ├── <env>        
    │   │   │   └── base                          
    │   │   │       └── kustomization.yaml          # namespace env overlay containing patches for a specific environment.
    │   │   │       └── sealed-secrets              # Optional sealed secrets manifests.
    │   │   │   └── 00/01
    │   │   │       └── kustomization.yaml          # Optional cluster overlay containing patches for a specific environment.
    │   │   │
    │   │   ├── identity
    │   │   │   └── identity.yaml                   # Base identity file.
    │   │   │   └── <env>.yaml                      # Env specific patch for identity.
    │   │   │
    │   │   └── <application-name>                  # Folder per app containing manifests and patches for each application.
    │   │       └── <application-name>.yaml         # Helm Release for each application.
    │   │       └── <env>.yaml                      # Optional patch for each environment
    │   │       └── image-repo.yaml                 # ImageRepository CRD used for image automation 
    │   │       └── image-policy.yaml               # ImagePolicy CRD used for image automation
    │   │       └── <env>-image-policy.yaml         # Optional ImagePolicy for non-ptl environments.
    │   │
    │   └──<namespace2>
    │      └── ...
    │
    │
    └── clusters
        │
        ├── <environment>
        │   ├── 00/01
        │   │   └── kustomization.yaml                # Cluster Overlay with patches on env base.  
        │   │      
        │   ├── base
        │   │   └── kustomization.yaml                # Env Base which includes Flux Kustomizations for all namespaces in that cluster.
        │   │
        │   └── pub-cert.pem                          # pem file for sealed-secrets
        │     
        └──<environment2>
           └── ...

### How flux understands the config

- Flux installation from Cluster creation pipeline applies
    1. [Flux components](../apps/flux-system/base/gotk-components.yaml) - creates CRDs and installs core flux components
    2. [Flux git repo CRD](../apps/flux-system/base/flux-config-gitrepo.yaml) - source controller config to download/update flux repo periodically.
    3. [Git Credentials](../apps/flux-system/sbox/base/git-credentials.yaml) which source controller uses to authenticate to Github
    4. [All config in flux-system base](../apps/flux-system/base/kustomization.yaml) which includes `hmctspublic` HelmRepo CRD, `hmcts-charts` Github Repo CRDs.
    5. [Flux kustomization for flux-system namespace](../apps/flux-system/base/kustomize.yaml) which is patched to [env/cluster specific kustomize.yaml](../apps/flux-system/sbox/00/kustomize.yaml)
    
- Flux kustomization for flux-system namespace patched above [Env/Cluster specific kustomize.yaml](../apps/flux-system/sbox/00/kustomize.yaml) will point to the path at which flux should look at. (Example  `./clusters/sbox/00`)
- Kustomize controller installs everything included in [Cluster Overlay](../clusters/sbox/00/kustomization.yaml) which inherits [Env Base Kustomization](../clusters/sbox/base/kustomization.yaml)
- This will create Flux Kustomizations for all namespaces that are included in that cluster. It also sets the defaults for all these using [kustomize.yaml](../apps/base/kustomize.yaml)
- Kustomize controller processes each namespace separately at a regular interval based on the path defined in [namespace flux kustomization](../apps/rpe/base/kustomize.yaml). Example : `./apps/rpe/${ENVIRONMENT}/base` where relevant environment name is substituted from  [env/cluster specific kustomize.yaml](../apps/flux-system/sbox/00/kustomize.yaml) installed previously.
- Some teams can choose the path to be `./apps/<namespace>/${ENVIRONMENT}/${CLUSTER}` if they need config specific to each cluster (Example - Cron Job Schedule)
- Each team environment overlay can either override [namespace base kustomization](../apps/rpe/base/kustomization.yaml) (which is common across all environments) or have [raw manifests](../apps/rpe/sbox/base/kustomization.yaml) overriding the [default namespace base](../apps/base/kustomization.yaml)
- Managed Identities is defined in [idenity.yaml](../apps/rpe/identity/identity.yaml) patched in [namespace env overlay](../apps/rpe/aat/base/kustomization.yaml) from [identity dir](../apps/rpe/identity/aat.yaml)
- Each [Helm Release](../apps/rpe/draft-store-service/draft-store-service.yaml) is defined as a directory in [namespace dir](../apps/rpe/draft-store-service) along with [patches](../apps/rpe/draft-store-service/aat.yaml)
- Helm Release has a [image repository](../apps/rpe/draft-store-service/image-repo.yaml) and [image policy](../apps/rpe/draft-store-service/image-policy.yaml) defined which are used for image automation.
- Image repository and policy are patched with default [default repo](../apps/flux-system/automation/hmctspublic-image-repo.yaml) and [image policy](../apps/flux-system/automation/prod-image-policy.yaml).
- Every namespace has a [namespace automation kustomization](../apps/rpe/automation) which includes all image policies and repos from that namespace, please note these automation CRDs should not be added to other kustomizations.
- CFTPTL flux-system includes a [automation kustomization](../apps/flux-system/automation/kustomization.yaml) includes all namespace automation kustomizations. It's the only cluster where image automation CRDs and controllers are added to [flux-system kustomization](../apps/flux-system/ptl-intsvc/base/kustomization.yaml).
- Image automation controller automates a HelmRelease based on `image policy` in the comment defined next to `image`. [Example](../apps/rpe/draft-store-service/draft-store-service.yaml)

