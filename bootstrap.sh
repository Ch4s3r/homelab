curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode=644 --cluster-cidr=10.42.0.0/16,2001:cafe:42::/56 --service-cidr=10.43.0.0/16,2001:cafe:43::/112 --default-local-storage-path /mnt/data
kubectl config view --raw
pbpaste | tee ~/.kube/macmini
set -x KUBECONFIG ~/.kube/macmini

k3d cluster create -i latest
kubectl annotate storageclass local-path defaultVolumeType=local
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

velero install \
        --use-node-agent \
        --default-volumes-to-fs-backup \
        --provider aws \
        --plugins velero/velero-plugin-for-aws \
        --bucket velero \
        --secret-file ./credentials-velero \
        --use-volume-snapshots=false \
        --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://192.168.178.11:9000
k apply -f https://raw.githubusercontent.com/vmware-tanzu/velero/main/examples/nginx-app/with-pv.yaml
k apply -f pod-with-pvc.yaml

k apply -f immich-pvc.yaml
helm install --namespace immich immich immich/immich -f immich-values.yaml
