kind delete cluster --name k8ssandra-0 && kind create cluster --config build/kind-config.yaml --name k8ssandra-0 && \
make cert-manager &&
# kustomize build test/kuttl/test-servicemonitors/config/prometheus | kubectl apply --server-side --force-conflicts -f - && \
# until kubectl get crd prometheuses.monitoring.coreos.com; do sleep 5; done && \
# kustomize build test/kuttl/test-servicemonitors/config/prometheus | kubectl apply --server-side --force-conflicts -f - && \
make docker-build && make single-prepare &&
kustomize build config/deployments/control-plane | kubectl apply --server-side --force-conflicts -f - && \
# helm install -n pulsar --create-namespace -f build/dev-values.yaml pulsar datastax-pulsar/pulsar && \
kubectl apply --server-side --force-conflicts  -f build/k8ssandra-cluster.yaml
# kubectl apply -f build/testutils-deployment.yaml
# Run me in the testutils container and look for a success message!
#/opt/bin/pulsar-cdc-testutil --cass-contact-points test-dc1-all-pods-service.k8ssandra-operator.svc.cluster.local:9042 --pulsar-url pulsar://pulsar-proxy.pulsar.svc.cluster.local:6650 --pulsar-admin-url http://pulsar-proxy.pulsar.svc.cluster.local:8080 --pulsar-cass-contact-point test-dc1-all-pods-service.k8ssandra-operator.svc.cluster.local