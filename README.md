
```

export KUBECONFIG=$(pwd)/bin/k3s.yml

kubectl -n minio port-forward svc/minio 9000:9000


export AWS_ACCESS_KEY_ID=$(kubectl -n minio get secret minio -ojson | jq -r '.data.accesskey' | base64 -d) \
    && export AWS_SECRET_ACCESS_KEY=$(kubectl -n minio get secret minio -ojson | jq -r '.data.secretkey' | base64 -d) \
    && export AWS_S3_ENDPOINT=http://localhost:9000 \
    && export MINIO_ENDPOINT=localhost:9000 \
    && export MINIO_ACCESS_KEY=$(kubectl -n minio get secret minio -ojson | jq -r '.data.accesskey' | base64 -d) \
    && export MINIO_SECRET_KEY=$(kubectl -n minio get secret minio -ojson | jq -r '.data.secretkey' | base64 -d)

```bash

mc config host add testminio http://localhost:9000 $(kubectl -n minio get secret minio -ojson | jq -r '.data.accesskey' | base64 -d) $(kubectl -n minio get secret minio -ojson | jq -r '.data.secretkey' | base64 -d)