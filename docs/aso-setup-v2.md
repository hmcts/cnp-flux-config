
# ASO Configuration

We use [Azure Service Operator](https://azure.github.io/azure-service-operator/) to manage ephemeral infrastructure in environments like preview. The section covers how to configure ASO resources in this repository.

Note: You need to [install yq](https://mikefarah.gitbook.io/yq/) for these scripts

## Resource Group

- It is mandatory for ASO to have a resource group configured on the cluster.
- We will configure one resource group per namespace for all ASO resources needed in the team. 
- Add   `- ../../../azureserviceoperator-system/resources/resource-group.yaml` to `resources` in `apps/<namespace>/<environment>/base/kustomization.yaml`

## Blob Storage

- Please configure resource group as described in earlier section.
- Follow [chart-blobstorage](https://github.com/hmcts/chart-blobstorage) documentation for configuring queues and topics.

## Service Bus Namespace

- Please configure resource group as described in earlier section.
- One service Bus instance can be used per team in preview, while queues and topics are created dynamically using [chart-servicebus](https://github.com/hmcts/chart-servicebus)
- Add   `- ../../../azureserviceoperator-system/resources/servicebus-namespace.yaml` to `resources` in `apps/<namespace>/<environment>/base/kustomization.yaml`
- Create a patch `<namespace>-servicebus.yaml` in `apps/<namespace>/<environment>/aso` as below:

    ```yaml
    apiVersion: servicebus.azure.com/v1beta20210101preview
    kind: Namespace
    metadata:
      name: ${NAMESPACE}-servicebus-${ENVIRONMENT}
      namespace: ${NAMESPACE}
    spec:
      tags:
        app.kubernetes.io_name: <application tag value>
        application: <application tag value >
    ```
  You can get correct application tag value from [team config](https://github.com/hmcts/cnp-jenkins-config/blob/master/team-config.yml)
- ServiceBus namespace is setup as `Basic` tier by default. [If you want any features not in `Basic`](https://www.azure.cn/en-us/pricing/details/service-bus/) like Topics/ Sessions, you can override the tier in the patch file created above.
     ```yaml
    apiVersion: servicebus.azure.com/v1beta20210101preview
    kind: Namespace
    metadata:
      name: ${NAMESPACE}-servicebus-${ENVIRONMENT}
      namespace: ${NAMESPACE}
    spec:
      tags:
        app.kubernetes.io_name: <application tag value>
        application: <application tag value >
      sku:
        name: Standard
     ```
- Add the patch `- ../aso/bsp-servicebus.yaml` to `patchesStrategicMerge:` in `apps/<namespace>/<environment>/base/kustomization.yaml`
- Raise a PR with above steps and get it merged, you should see a new servicebus instance `bsp-sb-preview` in Azure portal.
- Once the service bus instance is created, run `./bin/v2/add-servicebus-secret.sh <namespace> <environment>` to create a sops secret.
- Once you merge above changes, you can refer to the servicebus secrets in your application helm charts as below:
  ```yaml
  java:
  secrets:
    SB_ACCESS_KEY:
      secretRef: <your namespace>-sb-preview
      key: primaryKey
    SB_CONNECTION_STRING:
      secretRef: <your namespace>-sb-preview
      key: connectionString
  ```
- Follow [chart-servicebus](https://github.com/hmcts/chart-servicebus) documentation for configuring queues and topics.
