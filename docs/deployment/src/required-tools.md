# Installation of required tools

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

> You can install these tools by your own following the official documentation of each tool if you prefer

```shell
./kitt.sh tools docker kubectx kubectl helm jq krew kubelogin sops terraform aws aws-iam-authenticator eksctl
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