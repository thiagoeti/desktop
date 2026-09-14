---
name: devops-docker
description: Containerização com Docker — Dockerfile, multi-stage e otimização de imagem, Docker Compose, volumes/redes, segurança (non-root/secrets/scan) e produção (healthcheck/limites/logging). Use ao escrever/otimizar Dockerfiles, montar ambientes com Compose ou preparar imagens para deploy. Não cobre orquestração em vários nós (devops-kubernetes), provisionamento da infraestrutura (devops-terraform) nem deploy em VPS (cd-webhook).
version: 2.4.0
license: Unlicense
tags:
  - docker
  - containers
  - devops
  - docker-compose
  - dockerfile
---

# Docker — Containerização

Empacote app + dependências numa imagem portátil: pequena, segura, reproduzível.

> **Não cobre:** rodar em cluster — Deployment, probe, Service → `devops-kubernetes` · build e push no pipeline → `ci-github` · servir e fazer proxy → `devops-nginx` · postura de nuvem e IAM → `sec-cloud-security` · o que passar como ARG e o que passar em runtime → `ts-env`
> Aqui: **a imagem e o contêiner**.

---

## Contexto e Objetivo

- **Imagem** = template imutável; **container** = instância efêmera e isolada.
- **Ganha:** paridade dev/prod; base de CI/CD e da orquestração.
- Uma imagem boa é **pequena** (multi-stage + base enxuta), **segura** (non-root, sem secret embutido, escaneada) e **cacheável** (deps antes do código).

**Casos de uso:** containerizar apps · ambiente local multi-serviço · otimizar imagem/build · preparar deploy em registry/orquestrador

---

## Fluxo Cognitivo (Workflow)

1. **Dockerfile** — base fixada, ordem de instruções para cache, multi-stage.
2. **Otimize** — `.dockerignore`, layers, base enxuta/distroless, só deps de produção.
3. **Componha** — vários serviços com Compose (rede, volumes, healthcheck + `depends_on: condition`).
4. **Dados/rede** — volume nomeado para persistência; rede isolando o privado.
5. **Segurança** — non-root, capabilities mínimas, secrets em runtime, scan no CI.
6. **Produção** — healthcheck, limites de CPU/memória, logging com rotação, graceful shutdown.
7. **Publique** — tag imutável (versão/SHA) no registry; deploy referencia essa tag.

---

## Regras Estritas de Execução

- **Nunca `latest` em produção:** fixe a versão da base (ex.: `node:22.3-alpine`) — builds reproduzíveis.
- **Nunca rode como root:** crie e use `USER` não-privilegiado; nunca embuta secrets no Dockerfile/imagem (use secrets/env em runtime).
- **Sempre `.dockerignore`:** exclua `node_modules`, `.git`, `.env`, artefatos — contexto menor, build mais rápido, sem vazar segredos.
- **Multi-stage por padrão:** separe build (toolchain) do runtime (imagem final enxuta, só o necessário).
- **Container é efêmero:** nada de estado dentro dele — dados em **volume**; logs para stdout/stderr.
- **Forma exec** em CMD/ENTRYPOINT (JSON array) — sinais (SIGTERM) chegam ao processo.
- **Publique só as portas necessárias**; banco nunca exposto ao host/mundo.

---

## Exemplos Práticos (Few-Shot)

### "containeriza essa API Node.js"

**Erro típico** — `FROM node:latest` (tag móvel, build não reprodutível), `COPY . .` sem `.dockerignore` (leva `node_modules`/`.env` do host junto), `npm install` sem lockfile, roda como root, sem healthcheck.

**Ação:** Dockerfile multi-stage (deps → build → runtime alpine), `USER node`, `.dockerignore`, `HEALTHCHECK` (§1, §2).

### "sobe a API com Postgres em Compose"

**Erro típico** — `depends_on: [db]` só espera o **container** subir, não o Postgres aceitar conexão; sem volume nomeado, os dados somem a cada `docker compose down`.

**Ação:** `healthcheck` no `db` + `depends_on: condition: service_healthy` + volume nomeado (§3) — sem isso a API tenta conectar antes do banco estar pronto.

### "por que essa imagem ficou com 1.2GB?"

**Erro típico** — `FROM node:20` completo (toolchain inteiro na imagem final) e `COPY . .` antes do `npm install` invalida o cache a cada mudança de código.

**Ação:** multi-stage descartando o toolchain, base alpine/distroless, `COPY package.json` antes do código para aproveitar cache de layer (§1, §2).

---

## Referência Técnica

### 1. Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# --- stage 1: dependências ---
FROM node:22.3-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci                                   # instala com lockfile (reprodutível)

# --- stage 2: build ---
FROM node:22.3-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build                            # gera /app/dist

# --- stage 3: runtime (enxuto) ---
FROM node:22.3-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
USER node                                    # não-root
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/index.js"]
```

```txt
FROM base (fixe a versão; AS <nome>) · WORKDIR (cria e entra) · COPY (prefira a ADD)
RUN executa no BUILD e vira layer (junte com && ) · ENV variáveis · EXPOSE só DOCUMENTA a porta
USER usuário de execução (não-root) · HEALTHCHECK saúde · ENTRYPOINT binário fixo · CMD args default

ENTRYPOINT ["node"] CMD ["dist/index.js"] → `node dist/index.js`; `docker run img app.js` troca só o CMD.
Prefira a forma EXEC (JSON array): a forma shell cria um shell que atrapalha o SIGTERM.
```

**Ordem = cache (crucial):** cada instrução é uma layer; o Docker reusa o cache até a primeira que mudou. Copie o que muda **menos** antes do que muda **mais**.

```dockerfile
COPY package.json package-lock.json ./   # muda raramente
RUN npm ci                                # cacheado enquanto o lockfile não mudar
COPY . .                                  # código muda sempre (invalida daqui p/ frente)
```

**Base:** `node:22-alpine` pequena (musl libc), bom default — cuidado com libs nativas (glibc) · `node:22-slim` Debian enxuta, compatível com glibc · `gcr.io/distroless/...` só runtime, sem shell/gerenciador (mínima superfície) · `scratch` vazia, para binários estáticos (Go/Rust).

```dockerfile
# BuildKit (builder padrão): cache mounts e secrets de build
RUN --mount=type=cache,target=/root/.npm npm ci     # cache entre builds, fora da imagem
RUN --mount=type=secret,id=npmtoken npm ci          # secret só no build, sem virar layer
```

### 2. Otimização de imagem

Imagem grande = deploy lento, mais custo de registry e **maior superfície de ataque**.

```dockerfile
FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app ./cmd/server

FROM gcr.io/distroless/static-debian12      # imagem final mínima (sem shell, sem libs extras)
COPY --from=build /app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**`.dockerignore` (sempre):** `.git` · `node_modules` · `dist` · `*.log` · `.env` · `.env.*` · `Dockerfile` · `docker-compose*.yml` · `coverage` · `**/__pycache__`. Sem ele, `COPY . .` manda `node_modules`/`.git`/`.env` → build lento e risco de vazar segredo.

**Limpeza na MESMA layer** (limpar depois NÃO reduz tamanho): `RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*`.

**Só o necessário no runtime:** deps de produção (`npm ci --omit=dev` / `pip --no-cache-dir`) · sem compiladores, headers ou ferramentas de teste · remova caches do gerenciador de pacotes.

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t user/app:1.0 --push .   # multi-arch
docker images                 # tamanho
docker history myapp:latest   # tamanho por layer (caça gordura); ferramenta externa: dive
```

### 3. Docker Compose

Use **Compose v2** (`docker compose`, com espaço); o campo `version:` é obsoleto.

```yaml
# compose.yaml
services:
  api:
    build:
      context: .
      target: runtime           # estágio do multi-stage
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgres://app:${DB_PASSWORD}@db:5432/app   # 'db' = nome do serviço (DNS interno)
    depends_on:
      db:
        condition: service_healthy     # espera o healthcheck do db, não só "subiu"
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data       # volume nomeado → persiste
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  db-data:
# uma rede default é criada automaticamente; serviços se acham pelo NOME
```

- `service` = um container (ou réplicas) por `build`/`image` · **DNS interno**: comunicação pelo NOME do serviço, nunca por IP.
- `depends_on` = ordem de start; com `condition: service_healthy` espera o healthcheck · `restart`: `no | always | unless-stopped | on-failure`.
- `volumes`: nomeados (persistência) ou bind (`./host:/container` — dev) · `env_file` carrega um `.env` (não comite segredos; versione `.env.example`).
- **Overrides:** `compose.yaml` + `compose.override.yaml` (automático, para dev) · `docker compose -f compose.yaml -f compose.prod.yaml up` (explícito, produção) · `profiles: ["dev"]` sobe só com `--profile dev`.

```yaml
# segredos como arquivo (melhor que env)
services:
  api:
    secrets: [db_password]
secrets:
  db_password:
    file: ./secrets/db_password.txt   # montado em /run/secrets/db_password

# compose.override.yaml — dev com hot reload
services:
  api:
    build: { target: build }
    command: npm run dev
    volumes:
      - ./src:/app/src           # bind mount → reflete mudanças locais
```

**Boas práticas:** healthcheck + `depends_on: condition` (evita "db ainda não aceita conexão") · volume nomeado para dados, bind mount só em dev · restart policy e limites (`deploy.resources`/`mem_limit`) · um compose base + overrides por ambiente. **Nunca** segredo hardcoded nem dependência de IP.

### 4. Volumes e redes

**Volume nomeado** gerenciado pelo Docker, portátil e performático → produção/persistência · **bind mount** mapeia diretório do HOST (`./src:/app/src`) → dev, cuidado com permissões/UID · **tmpfs** em memória, nunca em disco → dados sensíveis/temporários.

```bash
docker volume create dbdata && docker run -v dbdata:/var/lib/postgresql/data postgres:16
docker run -v "$(pwd)":/app node:22-alpine   # bind mount (dev)   |  -v dbdata:/data:ro (read-only)
docker volume ls | inspect dbdata | rm dbdata (apaga dados) | prune

docker run --rm -v dbdata:/data -v "$(pwd)":/backup alpine \
  tar czf /backup/dbdata.tar.gz -C /data .        # backup de volume
```

**Redes** (mesma rede = se enxergam pelo NOME): `bridge` (default) rede isolada na máquina, o caso comum · `host` compartilha a pilha do host, sem isolamento (Linux) · `none` sem rede · `overlay` multi-host (Swarm/orquestração).

**Portas:** `EXPOSE` apenas DOCUMENTA; `-p host:container` (run) / `ports:` (compose) é que PUBLICA no host. Comunicação interna usa a porta do container direto — publique só o que o mundo precisa acessar.

```bash
docker network create app-net
docker run -d --name db --network app-net postgres:16 && docker run -d --name api --network app-net myapp
# dentro de 'api': postgres://db:5432 (resolve pelo nome 'db')
```

```yaml
# isolamento: db privado
services:
  api:   { networks: [frontend, backend] }
  db:    { networks: [backend] }           # não exposto ao frontend
  proxy: { networks: [frontend], ports: ["80:80"] }
networks:
  frontend:
  backend:
```

### 5. Segurança

Container não é fronteira de segurança forte por si só: reduza superfície e privilégio.

```dockerfile
# imagens oficiais costumam ter usuário pronto (ex.: 'node')
USER node
# ou crie:
RUN addgroup -S app && adduser -S app -G app
USER app
```

```yaml
services:
  api:
    user: "1000:1000"
    read_only: true                 # filesystem read-only (escreva só em volumes/tmpfs)
    cap_drop: ["ALL"]               # remove todas as capabilities Linux
    security_opt: ["no-new-privileges:true"]
    tmpfs: ["/tmp"]
```

**Secrets — nunca na imagem** (`docker history` revela tudo): ❌ `ENV API_KEY=...` no Dockerfile, ❌ `COPY .env` para dentro da imagem · ✅ runtime (env do orquestrador, Docker/Compose secrets em `/run/secrets`) · ✅ build via BuildKit `RUN --mount=type=secret,id=...` (não vira layer) · ✅ produção com cofre externo (Vault/cloud secrets manager).

**Imagem mínima e atualizada:** base enxuta (alpine/distroless) = menos pacotes = menos CVEs · fixe versões e atualize regularmente · use imagens oficiais/confiáveis.

```bash
docker scout cves myapp:latest        # Docker Scout
trivy image myapp:latest              # Trivy (popular em CI)
grype myapp:latest                    # Grype
```

Integre o scan no pipeline (`ci-github`): falhe o build em CVE crítico/fixável; escaneie também as dependências da app (`npm audit`/`pip-audit`).

**Supply chain:** pin de versões + lockfiles · assinatura/atestação (cosign / SLSA provenance) · SBOM (`docker buildx --sbom` / syft) · pull só de registries confiáveis.

**Runtime hardening:** non-root + no-new-privileges + `cap_drop ALL` (adicione só o necessário) · `read_only` + tmpfs · limites de recurso · **não monte `docker.sock`** sem necessidade (= root no host) · rede isolada, portas mínimas.

### 6. Produção

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
```

`start-period` dá carência enquanto a app sobe; `/health` deve checar dependências críticas mas ser barato. Em k8s vira liveness/readiness probe.

```bash
docker run --memory=512m --cpus=1.5 myapp
```

```yaml
services:
  api:
    deploy:
      resources:
        limits:   { cpus: "1.5", memory: 512M }
        reservations: { memory: 256M }
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }
```

Sem limites, um container consome toda a CPU/memória e derruba os vizinhos. Apps com runtime gerenciado devem respeitar o limite (`--max-old-space-size` no Node; a JVM lê cgroups).

**Logging:** stdout/stderr (nunca arquivo dentro do container) · JSON estruturado (Loki/ELK/cloud) · driver com rotação, senão o disco enche.

```js
process.on("SIGTERM", () => server.close(() => process.exit(0)));  // graceful shutdown
```

**Sinais:** Docker envia SIGTERM e, após o grace period, SIGKILL — pare de aceitar requisições, finalize as em curso, feche conexões. Use forma EXEC (sem shell intermediário); se o processo não lida com zumbis/sinais como PID 1, use `--init` (tini) ou `ENTRYPOINT ["dumb-init", ...]`.

**Restart policy:** `no | on-failure[:max] | always | unless-stopped`. Sem orquestrador, use `unless-stopped`/`on-failure`; com k8s, o orquestrador gerencia.

```bash
docker login
docker tag myapp:latest registry.example.com/team/myapp:1.4.2
docker push registry.example.com/team/myapp:1.4.2
```

Tag **imutável** (versão ou git SHA) permite deploy reproduzível e rollback; deploy de `latest` impede saber o que roda. Registries: Docker Hub, GHCR, ECR, GCR/Artifact Registry, Harbor. Build/push no CI (`ci-github`); orquestração em Kubernetes/ECS/Nomad/Swarm com rolling/blue-green/canary; proxy/TLS na frente (`devops-nginx` ou ingress).

### 7. Comandos e debugging

```bash
# imagens
docker build -t myapp:1.0 .              # build (BuildKit por padrão)
docker build --target build -t x .       # build até um estágio (multi-stage)
docker images | docker history myapp:1.0 | docker tag | docker pull/push | docker rmi

# containers
docker run -d -p 3000:3000 --name api myapp:1.0   # detached + porta + nome
docker run -it --rm myapp:1.0 sh                   # interativo, remove ao sair; --env-file .env
docker ps [-a] | stop/start/restart api | rm [-f] api | exec -it api sh | cp api:/app/log.txt .

# logs e inspeção
docker logs -f --tail 100 api | inspect api (config/rede/mounts/env) | stats | top api | events | port api
docker inspect -f '{{.State.Health.Status}}' api      # status do healthcheck

# limpeza (docker system df mostra o uso)
docker container prune | image prune [-a] | volume prune (apaga dados!) | builder prune | system prune -a

# compose
docker compose up -d --build | logs -f <svc> | exec <svc> sh | ps | down [-v]
```

**Diagnóstico rápido:** container sai imediatamente → `docker logs`; processo principal terminou? CMD correto? forma shell mascarando erro/sinal · "connection refused" entre containers → mesma rede? usa o NOME do serviço? (`localhost` dentro do container = o próprio container) · porta inacessível do host → publicou com `-p`/`ports:`? a app escuta em `0.0.0.0` e não `127.0.0.1`? · mudança no código não aparece → rebuild (cache) ou bind mount em dev, `--build` no compose · imagem gigante/build lento → falta `.dockerignore`, sem multi-stage, layers mal ordenadas · permissão negada em bind mount → UID do container vs dono dos arquivos no host.

---

## Checklist

- [ ] Multi-stage: build separado do runtime; base fixada e enxuta (alpine/slim/distroless), nunca `latest`
- [ ] Deps instaladas antes do código (cache de layers); limpeza na mesma layer do install
- [ ] `USER` não-root; `HEALTHCHECK` definido; CMD/ENTRYPOINT na forma exec
- [ ] BuildKit para cache mounts e secrets de build (sem secret em layer)
- [ ] `.dockerignore` cobrindo deps/artefatos/segredos; só deps de produção
- [ ] Tamanho verificado (history/dive); multi-arch se necessário
- [ ] Compose v2 (sem `version:`); comunicação por nome do serviço
- [ ] healthcheck + `depends_on: condition: service_healthy`
- [ ] Volume nomeado p/ persistência (com backup); bind mount só em dev
- [ ] Variáveis via `.env`/`secrets:`; nenhum segredo hardcoded ou na imagem
- [ ] Redes isolando o privado; publica só as portas necessárias (banco não exposto)
- [ ] Não-root + no-new-privileges; `cap_drop ALL`; `read_only`+tmpfs onde der
- [ ] Base mínima e atualizada; scan de imagem e deps no CI (falha em CVE crítico)
- [ ] `docker.sock` não exposto sem necessidade; supply chain (pin/lockfile/SBOM/assinatura)
- [ ] Limites de CPU/memória; runtime respeita o limite
- [ ] Logs em stdout/stderr, estruturados, com rotação
- [ ] Graceful shutdown (SIGTERM tratado; init para PID 1 se preciso); restart policy adequada
- [ ] Tag imutável (versão/SHA) no registry; nunca deploy de `latest`

---

## Externas

- Docs Docker: Dockerfile reference · Compose · Build/BuildKit · "Docker best practices"
- Skills: `devops-kubernetes` · `ci-github` · `devops-nginx` · `sec-cloud-security` · `sec-owasp-top10`
