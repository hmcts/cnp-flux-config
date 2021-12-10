# Golden Path Java - Creating and deleting Flux config
[Golden Path tutorial](https://backstage.platform.hmcts.net/catalog/default/component/golden-path-java) - VPN needed.

## Creating the flux config for your Java lab application 

Inside the labs/java directory run the [`create-lab-flux-config.sh`](./create-lab-flux-config.sh) script to create the flux config needed for your Java lab application. Use the component name you used when creating your app with backstage, which should be your GitHub username.

```shell
./create-lab-flux-config.sh yourGitHubUsername
```

The above script will do the following:
- Create the directory that the new config will be created in `apps/labs/labs-'yourGitHubUsername'`
- Create the imagePolicy and imageRepository config
- Create the HelmRelease resource to deploy your app 
- Add the image-policy and image-repo file references to the labs automation kustomization file so flux can automate image updates
- Add a reference to the HelmRelease file the sbox kustomization cluster so the resources are 

Once the script has been exectued, you will need to add and commit the new config and push it to GitHub. 
- Run `git status` to check which files have been create and modified.
- Use `git add` to stage the newly created files for commit
- Run `git diff` to view the changes made to the existing kustomization files. You should see references to the newly created files for your lab app.
- Once you're happy with the changes made, commit and push them and create a PR.

More information on flux v2, its components and custom resources can be found on [flux docs site](https://fluxcd.io/docs/concepts/).

## Deleting the flux config for your Java lab application

Once you're finished with your lab app you can clean up the flux configuration but running the [`clean-up-lab-flux-config.sh`](./create-lab-flux-config.sh) script. 

Inside the labs/java directory run the clean up script to remove the flux config you created earlier.

```shell
./clean-up-lab-flux-config.sh yourGitHubUsername
```

Once the script has been run, you will need to check and then commit the changes and push to GitHub and create a PR. 
