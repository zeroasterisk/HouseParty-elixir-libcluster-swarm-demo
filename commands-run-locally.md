### Get Started

Here are the commands you need to get the project started

```shell
# download repo
mix clone <repo> house_party

# get basic package dependencies
mix deps.get

# initialize default release config files (not part of the repo)
mix release.init
```

You shouldn't need to change any of the settings or edit the code.

### Build & Run a Docker Image Locally

Build and a Docker image locally.

Then run it with a few parameters.


```shell
# build docker image
docker build --no-cache -t house_party .

# start docker container (expose 8080 to host)
docker run -it -p 8080:8080 -e PORT:8080 house_party
```
We are running this container without Kubernetes, so some errors will be logged:

> 19:02:51.956 [error] [libcluster:hpgcpcluster] request to kubernetes failed!: {:failed_connect, [{:to_address, {'kubernetes.default.svc.cluster.local', 443}}, {:inet, [:inet], :nxdomain}]}

We can verify the functionality is available via the HTTP API:

```shell
# verify working from container
curl 'http://localhost:8080/hello'

world%


$ curl 'http://localhost:8080/scenario/slow'
self: :"house_party@127.0.0.1"
nodes: []

%{avg_fullness: 0.0, avg_wanderlust_completion: 0.0, people_waiting_to_enter_party: 30, total_people: 30, total_rooms: 5}


$ curl 'http://localhost:8080/stats/tldr'
self: :"house_party@127.0.0.1"
nodes: []

%{avg_fullness: 100.0, avg_wanderlust_completion: 52.4, people_in_rooms: 25, people_waiting_to_enter_party: 5, total_people: 30, total_rooms: 5}
```

### Stop Locally running Docker Container

```shell
# kill the most recently started docker container
docker kill $(docker ps -lq)
```
