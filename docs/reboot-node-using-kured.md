# Testing Kured

To do a manual test connect to a node you want to restart within the cluster and create a file on the node itself.
```
sudo touch /var/run/reboot-required
```
Reboot will occur.

By default the kured daemon set checks the nodes if they need restarted once every hour.