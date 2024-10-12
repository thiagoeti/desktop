# Desktop

Containers for development desktop.

![Image](_img/post.jpg)

## Alpine

```console
# pull
docker pull "alpine"

# drop
docker rm -f "alpine"

# run
docker run --name "alpine" \
	-v "/data":"/data" \
	-w "/data" \
	-it "alpine":"latest" "/bin/sh"
```

## Debian

```console
# pull
docker pull "debian"

# drop
docker rm -f "debian"

# run
docker run --name "debian" \
	-v "/data":"/data" \
	-w "/data" \
	-it "debian":"latest" "/bin/bash"
```

## PHP

```console
# pull
docker pull "php"

# drop
docker rm -f "php"

# run
docker run --name "php" \
	-v "/data":"/data" \
	-w "/data" \
	-it "php":"latest" "/bin/bash"
```

## NodeJS

```console
# pull
docker pull "node"

# drop
docker rm -f "node"

# run
docker run --name "node" \
	-v "/data":"/data" \
	-w "/data" \
	-it "node":"latest" "/bin/bash"
```

## Python

```console
# pull
docker pull "python:3.9.20-alpine"

# drop
docker rm -f "python"

# run
docker run --name "python" \
	-v "/data":"/data" \
	-w "/data" \
	-it "python":"latest" "/bin/bash"
```
