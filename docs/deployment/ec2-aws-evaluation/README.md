# Table of contents

1. [Overview](#overview)
2. [EC2 instance creation instructions](#ec2-instance-creation-instructions)
3. [Installation of required tools](#installation-of-required-tools)
4. [K3D installation](#k3d-installation)
5. [Kyso installation](#kyso-installation)
5. [Appendix 1. DNS configuration](#appendix-1-dns-configuration)
# Overview

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


# Installation of required tools

See [Installation of required tools](../src/required-tools.md)

# K3D installation

1. Sudo as root

```shell
sudo su .
```

2. Configure the K3D cluster running the following command

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
Cluster DNS Domain [lo.kyso.io]: <PUT_HERE_THE_DOMAIN_YOU_WILL_USE>
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

> ⚠️ **EXTREMELY IMPORTANT:** Ensure that you put the **LoadBalancer Host IP** property to **0.0.0.0**

3. Install k3d cluster

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

4. Check that everything is working running:

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

5. Configure the **ingress** running the following command

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

6. Copy the certificates from your domain (in this example fjbarrena.kyso.io) to `/root/kitt-data/certificates`

> ⚠️ **EXTREMELY IMPORTANT:** Ensure that the name of the certs follows this convention *domain.crt* and *domain.key*. If your domain is whatever.example.com, then your files would be **whatever.example.com.crt** and **whatever.example.com.key**

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

7. Install the ingress

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

8. Check that the ingress is listening correctly running the following command

```shell
ss -tnlp                   
```

And look for the following lines

```shell
State     Recv-Q    Send-Q       Local Address:Port        Peer Address:Port    Process                  
                            
LISTEN    0    4096     0.0.0.0:443       0.0.0.0:*
LISTEN    0    4096     0.0.0.0:80        0.0.0.0:*
```

> ⚠️ Make sure it's listening to **0.0.0.0** and not to **127.0.0.1**

# Kyso installation

See [Kyso installation](../src/kyso.md)

# Appendix 1. DNS Configuration

Remember to add an entry to your DNS with the public IP

![DNS entry](./images/7.png)