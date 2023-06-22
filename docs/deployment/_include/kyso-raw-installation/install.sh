#!/bin/bash

KITT_HOME=../../../..
echo "Using kitt home $KITT_HOME"

echo "Connecting to registry.kyso.io"
docker login registry.kyso.io

echo ""
echo ""
echo "Installing MongoDB"
echo "Creating namespace"
kubectl create namespace mongodb-prod

echo "Creating pvc"
kubectl apply -f ./mongodb/pvc.yaml

echo "Installing helm chart"
helm upgrade --install -n mongodb-prod -f ./mongodb/values.yaml kyso-mongodb bitnami/mongodb --version=12.1.31

echo ""
echo ""
echo "Installing mongo-gui"
echo "Creating namespace"
kubectl create namespace mongo-gui-prod

echo "Installing helm chart"
helm upgrade --install -n mongo-gui-prod -f ./mongo-gui/values.yaml mongo-gui $KITT_HOME/lib/kitt/charts/mongo-gui


echo ""
echo ""
echo "Installing nats"
echo "Creating namespace"
kubectl create namespace nats-prod

echo "Creating pvc"
kubectl apply -f ./nats/pvc.yaml

echo "Installing helm chart"
helm upgrade --install -n nats-prod -f ./nats/values.yaml kyso-nats nats/nats --version=0.17.0



echo ""
echo ""
echo "Installing elasticsearch"
echo "Creating namespace"
kubectl create namespace elasticsearch-prod

echo "Creating pvc"
kubectl apply -f ./elasticsearch/pvc.yaml

echo "Installing helm chart"
helm upgrade --install -n elasticsearch-prod -f ./nats/values.yaml kyso-elasticsearch elastic/elasticsearch --version=7.17.3




echo ""
echo ""
echo "Installing kyso-api"
echo "Creating namespace"
kubectl create namespace kyso-api-prod

echo "Creating svc mapping"
kubectl apply -f ./kyso-api/svc_map.yaml

echo "Install helm chart"
helm upgrade --install -n kyso-api-prod -f ./kyso-api/values.yaml kyso-api $KITT_HOME/lib/kitt/charts/kyso-api





echo ""
echo ""
echo "Installing kyso-front"
echo "Creating namespace"
kubectl create namespace kyso-front-prod

echo "Creating svc mapping"
kubectl apply -f ./kyso-front/svc_map.yaml

echo "Install helm chart"
helm upgrade --install -n kyso-front-prod -f ./kyso-front/values.yaml kyso-front $KITT_HOME/lib/kitt/charts/kyso-front





echo ""
echo ""
echo "Installing kyso-scs"
echo "Creating namespace"
kubectl create namespace kyso-scs-prod

echo "Creating pvc"
kubectl apply -f ./kyso-scs/pvc.yaml

echo "Creating configmap"
kubectl apply -f ./kyso-scs/configmap.yaml

echo "Creating svc mapping"
kubectl apply -f ./kyso-scs/svc_map.yaml

echo "Install helm chart"
helm upgrade --install -n kyso-scs-prod -f ./kyso-scs/values.yaml kyso-scs $KITT_HOME/lib/kitt/charts/kyso-scs



echo ""
echo ""
echo "Installing ingress"
echo "Creating namespace"
kubectl create namespace ingress

echo "Creating TLS secrets based on certificates folder"
kubectl create secret tls ingress-cert --namespace ingress --cert ./certificates/lo.kyso.io.crt --key ./certificates/lo.kyso.io.key

echo "Install helm chart"
helm upgrade --install -n ingress -f ./ingress/values.yaml ingress bitnami/nginx-ingress-controller --version=9.3.22




echo ""
echo ""
echo "Installing onlyoffice"
echo "Creating namespace"
kubectl create namespace onlyoffice-ds-prod

echo "Creating svc mapping"
kubectl apply -f ./onlyoffice-ds/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n onlyoffice-ds-prod -f ./onlyoffice-ds/values.yaml onlyoffice-ds $KITT_HOME/lib/kitt/charts/onlyoffice-ds



echo ""
echo ""
echo "Installing imagebox"
echo "Creating namespace"
kubectl create namespace imagebox-prod

echo "Creating svc mapping"
kubectl apply -f ./imagebox/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n imagebox-prod -f ./imagebox/values.yaml imagebox $KITT_HOME/lib/kitt/charts/imagebox




echo ""
echo ""
echo "Installing notification-consumer"
echo "Creating namespace"
kubectl create namespace notification-consumer-prod

echo "Creating svc mapping"
kubectl apply -f ./notification-consumer/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n notification-consumer-prod -f ./notification-consumer/values.yaml notification-consumer $KITT_HOME/lib/kitt/charts/notification-consumer



echo ""
echo ""
echo "Installing activity-feed-consumer"
echo "Creating namespace"
kubectl create namespace activity-feed-consumer-prod

echo "Creating svc mapping"
kubectl apply -f ./activity-feed-consumer/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n activity-feed-consumer-prod -f ./activity-feed-consumer/values.yaml activity-feed-consumer $KITT_HOME/lib/kitt/charts/activity-feed-consumer





echo ""
echo ""
echo "Installing analytics-consumer"
echo "Creating namespace"
kubectl create namespace analytics-consumer-prod

echo "Creating svc mapping"
kubectl apply -f ./analytics-consumer/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n analytics-consumer-prod -f ./analytics-consumer/values.yaml analytics-consumer $KITT_HOME/lib/kitt/charts/analytics-consumer



echo ""
echo ""
echo "Installing file-metadata-postprocess-consumer"
echo "Creating namespace"
kubectl create namespace file-metadata-postprocess-consumer-prod

echo "Creating svc mapping"
kubectl apply -f ./file-metadata-postprocess-consumer/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n file-metadata-postprocess-consumer-prod -f ./file-metadata-postprocess-consumer/values.yaml file-metadata-postprocess-consumer $KITT_HOME/lib/kitt/charts/file-metadata-postprocess-consumer






echo ""
echo ""
echo "Installing slack-notifications-consumer"
echo "Creating namespace"
kubectl create namespace slack-notifications-consumer-prod

echo "Creating svc mapping"
kubectl apply -f ./slack-notifications-consumer/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n slack-notifications-consumer-prod -f ./slack-notifications-consumer/values.yaml slack-notifications-consumer $KITT_HOME/lib/kitt/charts/slack-notifications-consumer




echo ""
echo ""
echo "Installing teams-notification-consumer"
echo "Creating namespace"
kubectl create namespace teams-notification-consumer-prod

echo "Creating svc mapping"
kubectl apply -f ./teams-notification-consumer/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n teams-notification-consumer-prod -f ./teams-notification-consumer/values.yaml teams-notification-consumer



echo ""
echo ""
echo "Installing kyso-nbdime"
echo "Creating namespace"
kubectl create namespace kyso-nbdime-prod

echo "Installing helm chart"
helm upgrade --install -n kyso-nbdime-prod -f ./kyso-nbdime/values.yaml kyso-nbdime $KITT_HOME/lib/kitt/charts/kyso-nbdime




echo ""
echo ""
echo "Installing jupyter-diff"
echo "Creating namespace"
kubectl create namespace jupyter-diff-prod

echo "Creating svc mapping"
kubectl apply -f ./jupyter-diff/svc_map.yaml

echo "Installing helm chart"
helm upgrade --install -n jupyter-diff-prod -f ./jupyter-diff/values.yaml jupyter-diff $KITT_HOME/lib/kitt/charts/jupyter-diff



echo "Installation finished successfully"

echo ""
echo ""
echo "To get kyso-scs credentials run the following command (requires jq)"
echo "kubectl get secret -n kyso-scs-prod kyso-scs-myssh-secret -o json | jq -r '.data.\"user_pass.txt\"' | base64 -d"

echo ""
echo ""
echo "Please, update the following properties at KysoSettings (you can do it at https://lo.kyso.io/mongo-gui)"
echo ""
echo "BASE_URL=https://lo.kyso.io"
echo "FRONTEND_URL=https://lo.kyso.io"
echo "SFTP_HOST=kyso-scs.kyso-scs-prod.svc.cluster.local"
echo "SFTP_PASSWORD=<set autogenerated password for user scs shown above>"
echo "SFTP_PUBLIC_PASSWORD=<set autogenerated password for user pub shown above>"
echo "ELASTICSEARCH_URL=http://elasticsearch-master.elasticsearch-prod.svc.cluster.local:9200"
echo "KYSO_INDEXER_API_BASE_URL=http://kyso-scs.kyso-scs-prod.svc.cluster.local:8080"
echo "KYSO_NATS_URL=nats://kyso-nats.nats-prod.svc.cluster.local:4222"
echo "KYSO_WEBHOOK_URL=http://kyso-scs.kyso-scs-prod.svc.cluster.local:9000"
echo "KYSO_NBDIME_URL=http://kyso-nbdime.kyso-nbdime-prod.svc.cluster.local:3005"

echo ""
echo "In order to receive notifications, please set the following variables at KysoSettings"
echo "MAIL_TRANSPORT=smtps://user:password@mail_server"

