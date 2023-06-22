#!/bin/bash

echo "Uninstalling kyso"
kubectl delete namespace mongodb-prod
kubectl delete namespace mongo-gui-prod
kubectl delete namespace nats-prod
kubectl delete namespace elasticsearch-prod
kubectl delete namespace kyso-api-prod
kubectl delete namespace kyso-front-prod
kubectl delete namespace kyso-scs-prod
kubectl delete namespace imagebox-prod
kubectl delete namespace notification-consumer-prod
kubectl delete namespace activity-feed-consumer-prod
kubectl delete namespace analytics-consumer-prod
kubectl delete namespace file-metadata-postprocess-consumer-prod
kubectl delete namespace onlyoffice-ds-prod
kubectl delete namespace slack-notifications-consumer-prod
kubectl delete namespace teams-notification-consumer-prod
kubectl delete namespace kyso-nbdime-prod
kubectl delete namespace jupyter-diff-prod
kubectl delete namespace ingress
