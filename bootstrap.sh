sudo mkfs.btrfs -L data -d raid1 -m raid1 /dev/sda /dev/sdb
UUID=$(sudo blkid -s UUID -o value /dev/sda)
sudo mkdir -p /mnt/data
echo "UUID=$UUID /mnt/data btrfs defaults,noatime,compress=zstd:3,space_cache=v2,autodefrag,nofail 0 2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
sudo btrfs filesystem show /mnt/data
# sudo vim /etc/sysconfig/btrfsmaintenance # set the PATHs to auto
sudo systemctl enable --now btrfs-scrub.timer btrfs-balance.timer btrfs-trim.timer

# sudo dnf install hd-idle
# sudo systemctl enable --now hd-idle

sudo touch /mnt/data/systemd_check_file
sudo vim /etc/systemd/system/k3s.service
# [Unit]
# ConditionPathExists=/mnt/data/systemd_check_file
sudo systemctl daemon-reload

curl -sfL https://get.k3s.io | sh -s - --default-local-storage-path /mnt/data
pbpaste | tee ~/.kube/macmini
sudo cat /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=~/.kube/macmini

# k3d cluster create -i latest
kubectl annotate storageclass local-path defaultVolumeType=local
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

kubectl create namespace tailscale
kubectl create secret generic operator-oauth \
  --namespace tailscale \
  --from-literal=client_id="XXXX" \
  --from-literal=client_secret="tskey-client-XXXX"

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

argocd login localhost:8080

cloudflared tunnel delete mac-mini
cloudflared tunnel create mac-mini
kubectl create secret generic -n cloudflared tunnel-credentials --from-file=credentials.json=/Users/lampe/.cloudflared/a212fe06-f2bf-4430-9d56-5b3f275440fc.json
