# CLAUDE.md

Convenções e regras do projeto **desktop**. Leitura obrigatória antes de qualquer alteração.

## Papel

Scripts que sobem apps e containers de desenvolvimento na máquina local. Não é aplicação — cada
script é autônomo, no padrão `docker pull` → `docker rm -f` → `docker run`.

| Script | Sobe | Versão fixada |
|---|---|---|
| `elasticsearch.sh` | Elasticsearch | `elastic/elasticsearch:9.1.3` |
| `kibana.sh` | Kibana | `elastic/kibana:9.1.3` |
| `mariadb.sh` | MariaDB | `mariadb` (sem tag) |
| `mysql_old.sh` | MySQL legado | — |
| `hyperf.sh` | Hyperf | `hyperf/hyperf:8.3-alpine-v3.22-swoole` |
| `php.sh`, `composer.sh` | PHP e Composer | — |
| `nodejs.sh`, `python.sh` | Node e Python | — |
| `alpine.sh`, `debian.sh` | Bases | — |

## Skills do agente — `.claude/skills/`

| Skill | Papel | Prioridade |
|---|---|---|
| `deploy/` | Workflow git. A raiz tem o symlink `.git.sh` | Alta |
| `define/` | Separação entre `README.md` (público) e `CLAUDE.md` (agente) | Alta |
| `devops-docker/` | Imagem, container, volume e restart — o padrão comum aos 12 scripts | Máxima |
| `index-elasticsearch/` | `elasticsearch.sh` e `kibana.sh` fixam a 9.1.3 | Alta |
| `db-mariadb/` | `mariadb.sh` — e a skill cobre as divergências frente ao MySQL | Alta |
| `db-mysql/` | `mysql_old.sh` | Média |
| `php-hyperf/` | `hyperf.sh` sobe `hyperf/hyperf:8.3-alpine-v3.22-swoole` (Swoole) | Alta |
| `php-backend/` | `php.sh` e `composer.sh` | Média |
| `python-backend/` | `python.sh` | Média |

⚠️ **`mariadb.sh` puxa `mariadb` sem tag.** `devops-docker` e `db-mariadb` tratam disso: imagem
sem versão fixada troca de major sem aviso. Os scripts do Elastic já fixam `9.1.3` — este não.

**Fora:** o kit de front, design, web, teste, lint e qualidade. Não há código de aplicação aqui,
só shell. `devops-kubernetes` e `cloud-aws` também não: é máquina local com Docker avulso.

## Git

```bash
bash .git.sh "mensagem de commit em português"
```
