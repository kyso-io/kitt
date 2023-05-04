# Kyso installation

1. Login into **registry.kyso.io** with the provided credentials, running the following command

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

# Annex 1. Helm files

Source of truth available [here](../../../lib/kitt/tmpl/apps/)

Values are replaced using kitt for comfort, but they can be replaced manually if desired