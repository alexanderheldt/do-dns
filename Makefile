include .env

build:
	docker build -f Dockerfile -t do-dns .

# RUNNING
up:
	docker run -d \
		--env DO_TOKEN=${DO_TOKEN} \
		--env DO_DOMAIN=${DO_DOMAIN} \
		--env DO_SUBDOMAINS=${DO_SUBDOMAINS} \
		--restart=always \
		--name do-dns \
		do-dns

down:
	docker stop do-dns
	docker rm do-dns
