# Creating Flux config for your Golden Path Java app

## Creating the flux config for your Java lab application 

Inside the labs/java directory run the create-lab-flux-config.sh script to create the flux config needed for your Java lab application.

```shell
cd labs/java/
./create-lab-flux-config.sh 
```

The above script will do the following:
- The directory your app's config will live in `apps/labs/labs-yourGitHubUsername'`
- Create the imagePolicy and imageRepository config
- Create the HelmRelease resource to deploy your app 
- Add the image-policy and image-repo file references to the labs automation kustomization file so flux can automate image updates
- Add a reference to the HelmRelease file the sbox kustomization cluster so the resources are 

More information on flux v2, its components and custom resources can be found on [flux docs site](https://fluxcd.io/docs/concepts/).

## Deleting the flux config for your Java lab application

Once you're finished with your lab app you can clean up the flux configuration but running the `clean-up-lab-flux-config.sh` script. 

Inside the labs/java directory run the clean up script to remove the flux config you created earlier.

```shell
cd labs/java/
./clean-up-lab-flux-config.sh 
```