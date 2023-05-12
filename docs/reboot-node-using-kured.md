# Testing Kured

To do a manual test connect to a node using these [instructions](https://learn.microsoft.com/en-us/azure/aks/node-access) and create a file on the node itself.
```
sudo touch /var/run/reboot-required
```
Reboot will occur.

By default the kured daemon set checks the nodes if they need restarted once every hour.