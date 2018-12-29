### Configure

Here are the project settings used in commands below, exported as variables so you can better understand them:

```shell
export PROJECT_ID=alanblount-sandbox
export GCP_CLUSTER=hpgcpcluster
export GCP_CLUSTER_NODE_COUNT=2
export GCP_CLUSTER_ZONE=us-central1-a
export REPO_NAME=house_party
export ERLANG_COOKIE=DCRVBIZHIPUTSECRETETHINGSHEREJWHNZXYVSFPG  # don't store this in code for real world usage!
```

The steps we need to complete are:

1. Build a Docker Image on GCP for the App
1. Setup a Kubernetes Cluster
1. Setup Kubernetes Secrets & Volume
1. Setup Kubernetes Roles / Access
1. Configure Kubernetes to Run the App as a Deployment

Once we have done all of that, we can use the HTTP API we created to start a Scenario and report on it.

### Build Docker Image

```shell
$ gcloud builds submit --tag=gcr.io/${PROJECT_ID}/${REPO_NAME}:v1
```

### Setup Kubernetes Cluster

```shell
$ gcloud container clusters create ${GCP_CLUSTER} --num-nodes=${GCP_CLUSTER_NODE_COUNT} --zone=${GCP_CLUSTER_ZONE}
```

### Setup Kubernetes Secret & Volume

```shell
$ kubectl create secret generic app-config --from-literal=erlang-cookie=${ERLANG_COOKIE}
$ kubectl create configmap vm-config --from-file=vm.args
```

You should see basic success feedback like:

> secret "app-config" created
> configmap "vm-config" created

### Setup Kubernetes Access

Grant yourself rights to grant to the service account
[documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control)

```shell
$ kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole cluster-admin --user $(gcloud config get-value account)
$ kubectl create -f kube-gcp-roles.yml
```

You should see basic success feedback like:

> clusterrolebinding.rbac.authorization.k8s.io "cluster-admin-binding" created
> role.rbac.authorization.k8s.io "ex_libcluster" created
> rolebinding.rbac.authorization.k8s.io "give-default-sa-libcluster" created

In this case, we create a Role with the metadata of `ex_libcluster` with basic access to endpoints.

Then we bind that Role to the `ServiceAccount`.

### Build & Run Kubernetes Deployment

This will tell Kubernetes to run the HouseParty application in pods, on the cluster.

```shell
$ kubectl create -f kube-gcp-build-deployment.yml
```

> Tip: if you mess up, delete the deployment with
> `kubectl delete -f kube-gcp-build-deployment.yml
> then edit the .yml file and create again

You can see the status of pods, and full details for pods with these commands:

```shell
$ kubectl get pods
$ kubectl describe $(kubectl get pods -o name | head -n 1)
# kubectl describe pod "${GCP_CLUSTER}-<id>" (first get the ID of the pod you want)
```

You can get the logs from running containers with these commands:

```shell
$ kubectl logs $(kubectl get pods -o name | head -n 1)
# kubectl logs "${GCP_CLUSTER}-<id>" (first get the ID of the pod you want)
```

> Tip: you can get the logs for all pods with `kubectl get pods -o name | xargs -I {} kubectl logs {}`

You want to see logs something like this:

```
19:43:47.657 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:init] started
19:43:47.659 [info]  HTTP interface starting with port 30080
19:43:47.710 [warn]  [libcluster:hpgcpcluster] unable to connect to :"housepartyapp@10.36.0.15"
19:43:47.712 [warn]  [libcluster:hpgcpcluster] unable to connect to :"housepartyapp@10.36.0.16"
19:43:51.731 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:ensure_swarm_started_on_remote_node] nodeup housepartyapp@10.36.0.16
19:43:51.746 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:ensure_swarm_started_on_remote_node] nodeup housepartyapp@10.36.0.15
19:43:52.658 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:cluster_wait] joining cluster..
19:43:52.659 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:cluster_wait] found connected nodes: [:"housepartyapp@10.36.0.15", :"housepartyapp@10.36.0.16"]
19:43:52.659 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:cluster_wait] selected sync node: housepartyapp@10.36.0.15
19:43:56.671 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:syncing] syncing to housepartyapp@10.36.0.15 based on node precedence
19:43:56.671 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:awaiting_sync_ack] received sync acknowledgement from housepartyapp@10.36.0.15, syncing with remote registry
19:43:56.671 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:awaiting_sync_ack] local synchronization with housepartyapp@10.36.0.15 complete!
19:43:56.671 [info]  [swarm on housepartyapp@10.36.1.14] [tracker:resolve_pending_sync_requests] pending sync requests cleared
```

* HTTP interface was started from `application.ex`, configured with port `30080`
* `libcluster` handles node **discovery** via the Kubernetes API.
* `libcluster` handles node **connection** with normal Erlang `:net_kernel.connect_node`.
* `swarm` then takes over and syncs accross nodes in the cluster

This looks really good, I think we are ready to go.

### Build a LoadBalancer to expose the Deployment via HTTP

We have a very simple HTTP API to play with this application.  We need a LoadBalancer to expose our app via HTTP.

```shell
$ kubectl create -f kube-gcp-build-load-balancer.yml
```

This process takes a few minutes.  You can check status and eventually get the `EXTERNAL-IP` address with this command:

```shell
$ kubectl get service
```

For easy future use, you can create a variable to store the LoadBalancer IP address:

```shell
$ export LBIP=35.222.222.222
$ curl "http://${LBIP}/hello"
```

----

### Delete Kubernetes Cluster

When you're done testing, you should delete the Deployment and the LoadBalancer

Doing this is important to ensure you are not charged.

```shell
$ gcloud clusters delete ${GCP_CLUSTER} --zone=us-central1-a
$ kubectl create -f kube-gcp-build-load-balancer.yml
$ gcloud compute forwarding-rules list
$ gcloud compute forwarding-rules delete <id>
```
