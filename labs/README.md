# Golden Path - Creating and deleting Flux config for an application

VPN is needed to follow the Golden Path tutorials.
[Golden Path tutorial - Java](https://backstage.platform.hmcts.net/catalog/default/component/golden-path-java)
[Golden Path tutorial - Node.js](https://backstage.sandbox.platform.hmcts.net/docs/default/component/golden-path-nodejs)

Clone this repository and create a local git branch before continuing e.g. `git checkout -b labs-yourGitHubUsername`

## Creating the flux config for your lab application

Inside the labs directory, run the [`labs/create-lab-flux-config.sh`](create-lab-flux-config.sh) script to create the flux config needed for your lab application. Use the component name you used when creating your app with backstage, which should be your GitHub username and specify the type of application you are deploying.

<details open>
<summary>Command to create the flux configuration for a Java app</summary>

```shell
./create-lab-flux-config.sh yourGitHubUsername java
```

</details>

<details open>
<summary>Command to create the flux configuration for a Node.js app</summary>

```shell
./create-lab-flux-config.sh yourGitHubUsername-nodejs nodejs
```

</details>

The above script will do the following:

- Create the directory that the new config will be created in `apps/labs/labs-'yourGitHubUsername'`
- Create the ImagePolicy and ImageRepository config
- Create the HelmRelease resource to deploy your app
- Add the image-policy and image-repo file references to the labs automation kustomization file so flux can automate image updates
- Add a reference to the HelmRelease file the sbox kustomization cluster so the resources are

Once the script has been executed, you will need to create a new branch, add and commit the new config and then push the changes to GitHub.

- Switch to a new branch by using `git switch -c labs-yourGitHubUsername`
- Run `git status` to check which files have been create and modified.
- Use `git add .` from the root of the repo to stage the changes for commit
- Run `git diff --staged` to view the changes made to the existing kustomization files. You should see references to the newly created files for your lab app.
- When you're happy with the changes made, commit and push them and create a PR.

More information on flux v2, its components and custom resources can be found on [flux docs site](https://fluxcd.io/docs/concepts/).

## Azure Container Registry

There are two container registries where your application image may end up:
- **hmctspublic** where majority of images are uploaded
- **hmctssandbox** where sandbox application images should be uploaded

The reason for this is that there will most likely be two separate Jenkins pipelines for your application once you create your repo (e.g. NodeJS) defined in two separate Jenkins instances both of which scan for new repos:

- [PTL Jenkins](https://build.hmcts.net/) ([defined under ptl-intsvc](https://github.com/hmcts/cnp-flux-config/blob/master/apps/jenkins/jenkins/ptl-intsvc/jenkins.yaml))
- [Sandbox Jenkins](https://sandbox-build.hmcts.net/) ([defined under sbox-intsvc](https://github.com/hmcts/cnp-flux-config/blob/master/apps/jenkins/jenkins/sbox-intsvc/jenkins.yaml))


The lab script mentioned above will generate configuration with the ACR set to **hmctssandbox** - this is where Flux will look for your image.

If your build is executed by the PTL Jenkins then this may cause issues because pipelines in this Jenkins will upload images into the **hmctspublic** ACR (you can see this if you open the respective ACR in Azure portal and search for your image).

Once you merge your Flux config and notice that you container is in error state with status **"ImageError"** or **"ImagePullBackOff"** then most likely your image is missing from the **hmctssandbox** ACR. 

You can check the status of your containers by running:

  `kubectl get pods -n labs`

Or to get more detailed information:

  `kuberctl describe pod labs-<github-username-nodejs-nodejs-abc-xyz>`

To avoid this issue, ensure that the registry defined in your application charts matches where your image will actually be uploaded. For the purpose of the Golden Path tutorial just ensure that the pipeline within Sandbox Jenkins has passed on your master branch and that your image has been uploaded to the sandbox ACR. 

You may also end up with images in both registries if both pipelines have run, e.g. as a result of a trigger on merge to master.

## Deleting the flux config for your lab application

Once you're finished with your lab app you can clean up the flux configuration by running the [`clean-up-lab-flux-config.sh`](./create-lab-flux-config.sh) script.

Inside the labs directory run the clean up script to remove the flux config you created earlier.

```shell
./clean-up-lab-flux-config.sh yourGitHubUsername-nodejs
```

```shell
./clean-up-lab-flux-config.sh yourGitHubUsername-java
```

Once the script has successfully finished, you will need to check and then commit the changes and push to GitHub and create a PR.
