# Installation instructions

These instructions describe how to install Kyso for **evaluation purposes** in a EC2 instance at AWS

# EC2 instance creation instructions

1. Open and login into AWS console
2. Open EC2 Dashboard
3. Click on Launch instance button and select option "Launch instance"

![Launch instance](./images/1.png)

4. Write a **name** for the instance, i.e: kyso-pilot
5. Select **Debian** as OS

> Kyso can be installed in **any** operating system, but this instructions are based on Debian. Other OS based in Unix might have slightly different instructions (different package manager, etc.), but the step by step, and the tools, are exactly the same.

6. Choose the desired instance type. **t3.large is the recommended type for a pilot**
7. Click on **Create new key pair** and choose the following options (recommended, but other options are good as well)

![Create new key pair](./images/2.png)

> A .pem file will be downloaded in your local machine, save it in a secure place

8. Put the following rules at Network Settings 

![Network settings](./images/3.png)

9. Configure the storage to the desired size. **Recommended size for a pilot is 30GB GP3**.
10. Click on "Launch instance"
11. Create a new ElasticIP and associate it with the recently created instance
12. Click on the menu item **Instances** and select the recently created instance
11. Click on the "Connect" button. You will see the public IP of your machine. Save it for later.

> Click on the tab **SSH Client** to configure your local machine to access through SSH to the EC2 instance

![SSH Client](./images/5.png)

12. Check out that you are able to connect to the EC2 instance through SSH

![Connect to instance using shell](./images/6.png)


# Installation of required tools (docker, k3d, etc.)

1. Update apt registries running the following command

```shell
sudo apt update
```

2. Install **git**, **curl**, **uidmap**, **unzip** and **age** executing the following command

```shell
sudo apt install git curl unzip age uidmap --yes
```

3. Clone the **kitt** repository provided by Kyso. For example, if the provided repository is **https://gitlab.kyso.io/ext/CUSTOMER_REPOSITORY/kyso-installation**, then run:

```shell 
admin@ip-172-31-4-139:~$ git clone https://gitlab.kyso.io/ext/CUSTOMER_REPOSITORY/kyso-installation.git
Cloning into 'kitt'...
Username for 'https://gitlab.kyso.io': xxxx
Password for 'https://xxx@gitlab.kyso.io': xxxxx
remote: Enumerating objects: 3719, done.
remote: Counting objects: 100% (1003/1003), done.
remote: Compressing objects: 100% (278/278), done.
remote: Total 3719 (delta 769), reused 842 (delta 688), pack-reused 2716
Receiving objects: 100% (3719/3719), 1.45 MiB | 6.63 MiB/s, done.
Resolving deltas: 100% (2160/2160), done.

``` 
> Kyso will provide you the required credentials

4. Go into the cloned kitt folder and the bin directory

```shell
cd kitt/bin
```

5. Install all the required tools to install Kyso using the following kitt.sh command

```shell
./kitt.sh tools docker k3d kubectx kubectl helm jq krew kubelogin sops 
```
```log
docker could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
k3d could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
Preparing to install k3d into /usr/local/bin
kubectx could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
kubectl could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
helm could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
jq could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
krew could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
kubelogin could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
sops could not be found.
Install it in /usr/local/bin? (Yes/No) [Yes]: Yes
```
6. Sudo as root

```shell
sudo su .
```

7. Configure the K3D cluster running the following command

```shell
./kitt.sh clust config update
```

And selecting the following options

```shell
Cluster kind? (eks|ext|k3d) []: k3d

When reading values an empty string or spaces keep the default value.
To adjust the value to an empty string use a single - or edit the file.
-------------------------------------
Cluster kind? (eks|ext|k3d) [k3d]: 
Cluster Kubectl Context [default]: 
Cluster DNS Domain [lo.kyso.io]: <PUT_HERE_THE_DOMAIN_YOU_WILL_ _USE>
Keep cluster data in git (Yes/No) [Yes]: 
Force SSL redirect on ingress (Yes/No) [Yes]: 
Cluster Ingress Replicas [1]: 
Add pull secrets to namespaces (Yes/No) [No]: 
Use basic auth (Yes/No) [Yes]: 
Use SOPS (Yes/No) [Yes]: No
Number of servers (Master + Agent) [1]: 
Number of workers (Agents) [0]: 
K3s Image [docker.io/rancher/k3s:v1.25.7-k3s1]: 
API Host [127.0.0.1]: 
API Port [6443]: 
LoadBalancer Host IP [127.0.0.1]: 0.0.0.0
LoadBalancer HTTP Port [80]: 
LoadBalancer HTTPS Port [443]: 
Map Kyso development ports? (Yes/No) [No]: 
Use local storage? (Yes/No) [Yes]: 
Use local registry? (Yes/No) [No]: 
Use remote registry? (Yes/No) [Yes]: 
Use calico? (Yes/No) [Yes]: 
-------------------------------------
Configuration saved to '/home/admin/kitt-data/clusters/default/config'
-------------------------------------
Remote registry configuration not found, configuring it now!
Configuring remote registry
-------------------------------------
Registry NAME []: registry.kyso.io
Registry URL []: registry.kyso.io
Registry USER []: <PUT_HERE_CREDENTIALS_PROVIDED>
Registry PASS []: <PUT_HERE_CREDENTIALS_PROVIDED>
-------------------------------------
Configuration saved to '/home/admin/kitt-data/clusters/default/secrets/registry.sops.env'
-------------------------------------
``` 

> **EXTREMELY IMPORTANT:** Ensure that you put the **LoadBalancer Host IP** property to **0.0.0.0**

8. Install k3d cluster

```shell
./kitt.sh clust k3d install
```

You should see a log like this
```log
Creating K3D cluster
-------------------------------------
INFO[0000] Using config file /tmp/tmp.brihaIgBSN/k3d-config.yaml (k3d.io/v1alpha4#simple) 
INFO[0000] portmapping '127.0.0.1:80:80' targets the loadbalancer: defaulting to [servers:*:proxy agents:*:proxy] 
INFO[0000] portmapping '127.0.0.1:443:443' targets the loadbalancer: defaulting to [servers:*:proxy agents:*:proxy] 
INFO[0000] Prep: Network                                
INFO[0000] Created network 'k3d-default'                
INFO[0000] Created image volume k3d-default-images      
INFO[0000] Starting new tools node...                   
INFO[0001] Creating node 'k3d-default-server-0'         
INFO[0001] Pulling image 'ghcr.io/k3d-io/k3d-tools:5.4.9' 
INFO[0002] Pulling image 'docker.io/rancher/k3s:v1.25.7-k3s1' 
INFO[0002] Starting Node 'k3d-default-tools'            
INFO[0007] Creating LoadBalancer 'k3d-default-serverlb' 
INFO[0008] Pulling image 'ghcr.io/k3d-io/k3d-proxy:5.4.9' 
INFO[0011] Using the k3d-tools node to gather environment information 
INFO[0011] HostIP: using network gateway 172.18.0.1 address 
INFO[0011] Starting cluster 'default'                   
INFO[0011] Starting servers...                          
INFO[0012] Starting Node 'k3d-default-server-0'         
INFO[0017] All agents already running.                  
INFO[0017] Starting helpers...                          
INFO[0018] Starting Node 'k3d-default-serverlb'         
INFO[0025] Injecting records for hostAliases (incl. host.k3d.internal) and for 2 network members into CoreDNS configmap... 
INFO[0027] Cluster 'default' created successfully!      
INFO[0027] You can now use it like this:                
kubectl cluster-info
-------------------------------------
✔ Switched to context "k3d-default".
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
-------------------------------------
```

9. Check that everything is working running:

```shell
kubectl get pods -A
```
```logs
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
kube-system   calico-node-gf7gd                          1/1     Running   0          58m
kube-system   local-path-provisioner-79f67d76f8-gn6km    1/1     Running   0          58m
kube-system   coredns-597584b69b-kj26p                   1/1     Running   0          58m
kube-system   calico-kube-controllers-788b5f94dc-pxf4x   1/1     Running   0          58m
kube-system   metrics-server-5f9f776df5-bmkn9            1/1     Running   0          58m
```

10. Configure the **ingress** running the following command

```shell
./kitt.sh addons ingress env-update
```
And choosing the following options
```shell
Ingress Helm Chart Version [9.3.22]: 
Ingress Backend Image Registry [docker.io]: 
Ingress Backend Image Repository in Registry [bitnami/nginx]: 
Ingress Backend Image Tag [1.22.1-debian-11-r7]: 
Ingress Controller Image Registry [docker.io]: 
Ingress Controller Image Repository in Registry [bitnami/nginx-ingress-controller]: 
Ingress Controller Image Tag [1.5.1-debian-11-r5]: 
Add Ingress CoreDNS Custom Config (Yes/No) [No]: Yes
-------------------------------------
Save updated ingress env vars? (Yes/No) [Yes]: Yes
-------------------------------------
ingress configuration saved to '/root/kitt-data/clusters/default/envs/ingress/ingress.env'
-------------------------------------
```

11. Copy the certificates from your domain (in this example fjbarrena.kyso.io) to `/root/kitt-data/certificates`

> **EXTREMELY IMPORTANT:** Ensure that the name of the certs follows this convention *domain.crt* and *domain.key*. If your domain is whatever.example.com, then your files would be **whatever.example.com.crt** and **whatever.example.com.key**

> To copy the certs from your local machine to the EC2 instance you can run the following command

```shell
scp -i fjbarrena@kyso-pilot.pem fjbarrena.kyso.io.* admin@ec2-13-50-108-185.eu-north-1.compute.amazonaws.com:~/
```
```logs
fjbarrena.kyso.io.crt                           100% 5676    94.0KB/s   00:00    
fjbarrena.kyso.io.key                           100% 1704    29.6KB/s   00:00
```
And to copy to the desired folder

```shell
root@ip-172-31-4-139:/home/admin/kitt/bin# cp ../../fjbarrena.kyso.io.* /root/kitt-data/certificates/
```

12. Install the ingress

```shell 
./kitt.sh addons ingress install
``` 
You should see an output like the following
```logs
-------------------------------------
LoadBalancer info:
-------------------------------------
NAME                                               TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-ingress-controller                   LoadBalancer   10.43.139.205   172.18.0.2    80:32519/TCP,443:31084/TCP   21s
-------------------------------------
```

13. Check that the ingress is listening correctly running the following command

```shell
ss -tnlp                   
```

And look for the following lines

```shell
State     Recv-Q    Send-Q       Local Address:Port        Peer Address:Port    Process                  
                            
LISTEN    0    4096     0.0.0.0:443       0.0.0.0:*
LISTEN    0    4096     0.0.0.0:80        0.0.0.0:*
```

Make sure it's listening to **0.0.0.0** and not to **127.0.0.1**

# Kyso installation

1. Login into registry.kyso.io with the provided credentials, running the following command

```shell
docker login registry.kyso.io
```

2. Configure common properties for Kyso deployment running:

```shell
./kitt.sh apps common env-update
```
And set the following properties

```logs
-------------------------------------
Common Settings
-------------------------------------
Space separated list of ingress hostnames [fjbarrena.kyso.io]: 
imagePullPolicy ('Always'/'IfNotPresent') [Always]: 
Manage TLS certificates for the ingress definitions? (Yes/No) [No]: Yes
Port forward IP address [127.0.0.1]: 
-------------------------------------
common configuration saved to '/root/kitt-data/clusters/default/deployments/dev/envs/common.env'
-------------------------------------
```

3. Install **MongoDB**

```shell
./kitt.sh apps mongodb install
```

4. Install **NATS**

```shell
./kitt.sh apps nats install
```

5. Install **ElasticSearch**

```shell
./kitt.sh apps elasticsearch install
```

6. Install **Mongo GUI**

```shell
./kitt.sh apps mongo-gui install
```

7. **If provided**, execute the script `kyso-exports.sh`. This script will export all the environment variables needed for the next commands. To execute the script run the following command

```shell
source kyso-exports.sh
```

8. Install **kyso-api**

```shell
./kitt.sh apps kyso-api install
```
> If `kyso-exports.sh` was not provided, use the following command specifying the docker image

```shell
KYSO_API_IMAGE=registry.kyso.io/kyso-io/kyso-api/develop:latest ./kitt.sh apps kyso-api install
```

9. Install **kyso-scs**

```shell
./kitt.sh apps kyso-scs install
```
> If `kyso-exports.sh` was not provided, use the following command specifying the docker image

```shell
KYSO_SCS_INDEXER_IMAGE=registry.kyso.io/kyso-io/kyso-indexer/develop:latest ./kitt.sh apps kyso-scs install
```
10. Install **kyso-front**

```shell
./kitt.sh apps kyso-front install
```
> If `kyso-exports.sh` was not provided, use the following command specifying the docker image

```shell
KYSO_FRONT_IMAGE=registry.kyso.io/kyso-io/kyso-front/develop:latest ./kitt.sh apps kyso-front install
```
10. Install **consumers**

> If you are not going to use Microsoft Teams nor Slack integrations, you can skip their installation

> The consumers are not mandatory, but if not installed some features wouldn't be available

```shell
./kitt.sh apps activity-feed-consumer install
./kitt.sh apps notification-consumer install
./kitt.sh apps slack-notifications-consumer install
./kitt.sh apps teams-notification-consumer install
./kitt.sh apps file-metadata-postprocess-consumer install
./kitt.sh apps analytics-consumer install
```
> If `kyso-exports.sh` was not provided, use the following command specifying the docker image

```shell
ACTIVITY_FEED_CONSUMER_IMAGE=registry.kyso.io/kyso-io/consumers/activity-feed-consumer/develop:latest ./kitt.sh apps activity-feed-consumer install
NOTIFICATION_CONSUMER_IMAGE=registry.kyso.io/kyso-io/consumers/notification-consumer/develop:latest ./kitt.sh apps notification-consumer install
SLACK_NOTIFICATIONS_CONSUMER_IMAGE=registry.kyso.io/kyso-io/consumers/slack-notifications-consumer/develop:latest ./kitt.sh apps slack-notifications-consumer install
TEAMS_NOTIFICATION_CONSUMER_IMAGE=registry.kyso.io/kyso-io/consumers/teams-notification-consumer/develop:latest  ./kitt.sh apps teams-notification-consumer install
FILE_METADATA_POSTPROCESS_IMAGE=registry.kyso.io/kyso-io/consumers/file-metadata-postprocess/develop:latest ./kitt.sh apps file-metadata-postprocess-consumer install
ANALYTICS_CONSUMER_IMAGE=registry.kyso.io/kyso-io/consumers/analytics-consumer:latest ./kitt.sh apps analytics-consumer install
```

11. Finally, install OnlyOffice server

```shell
./kitt.sh apps onlyoffice-ds install
```

12. Check that all the kubernetes pods are running executing the following command:

```shell
kubectl get pods -A
```

13. Finally, open your browser and access to your domain, in this example https://fjbarrena.kyso.io

You should view something similar to this:

```shell
root@ip-172-31-4-139:/home/admin/kitt/bin# kubectl get pods -A
NAMESPACE                                NAME                                                              READY   STATUS    RESTARTS   AGE
mongodb-dev                              kyso-mongodb-0                                                    1/1     Running   0          163m
nats-dev                                 kyso-nats-box-9cd6697db-fvq8d                                     1/1     Running   0          162m
nats-dev                                 kyso-nats-0                                                       3/3     Running   0          162m
elasticsearch-dev                        elasticsearch-master-0                                            1/1     Running   0          161m
mongo-gui-dev                            mongo-gui-694754b6bc-2r2mn                                        1/1     Running   0          159m
kyso-api-dev                             kyso-api-55794c75fd-bv5p7                                         1/1     Running   0          157m
kyso-scs-dev                             kyso-scs-0                                                        4/4     Running   0          137m
activity-feed-consumer-dev               activity-feed-consumer-7dc76d5f54-fklmr                           1/1     Running   0          12m
notification-consumer-dev                notification-consumer-576f5c8747-f7zh6                            1/1     Running   0          11m
slack-notifications-consumer-dev         slack-notifications-consumer-7548f87fbc-fchhd                     1/1     Running   0          11m
teams-notification-consumer-dev          teams-notification-consumer-7fdcf75974-m9htk                      1/1     Running   0          11m
file-metadata-postprocess-consumer-dev   file-metadata-postprocess-consumer-6f997cc7c4-vrnsb               1/1     Running   0          10m
analytics-consumer-dev                   analytics-consumer-7d87645bd8-8flgb                               1/1     Running   0          9m8s
kyso-front-dev                           kyso-front-56554bccfd-j5phj                                       1/1     Running   0          5m52s

```

# Appendix 1. DNS Configuration

Remember to add an entry to your DNS with the public IP

![DNS entry](./images/7.png)