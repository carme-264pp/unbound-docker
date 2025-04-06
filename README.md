# unbound-docker

## setup
1. Build docker image

```shell
docker compose build
```

2. Fetch DNS root hints

```shell
 curl -o conf/root.hints https://www.internic.net/domain/named.root
```
