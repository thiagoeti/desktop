---
name: db-mysql
description: MySQL 8+ (InnoDB) — tipos e charset (utf8mb4), índices e clustered PK, EXPLAIN/otimização, transações e isolamento, JSON, replicação e backup. Use ao usar recurso específico do MySQL, modelar ou otimizar schema InnoDB, escolher índice, ler EXPLAIN, ou tunar consulta lenta. Não cobre SQL agnóstico de engine (db-sql), as divergências do fork MariaDB (db-mariadb) nem migração sem downtime (db-migrations).
version: 2.1.0
license: Unlicense
tags:
  - mysql
  - database
  - innodb
  - indexes
  - performance
---

# MySQL 8+ (InnoDB)

Clustered index, charset utf8mb4, otimização e os recursos específicos do MySQL — além do SQL padrão.

> **Não cobre:** modelagem, JOIN e SQL agnóstico → `db-sql` · o que muda no fork **MariaDB** → `db-mariadb` (vários comandos desta skill não existem lá) · expand-migrate-contract e locks de DDL → `db-migrations` · ORM e camada de acesso → `php-laravel`, `ts-backend` · relevância e analyzer → `index-elasticsearch` · SQLi como categoria → `web-security`
> Aqui: **InnoDB e os recursos próprios do MySQL**.

---

## Contexto e Objetivo

- Engine **InnoDB** (transacional, FK, row-level locking) e charset **utf8mb4**.
- Índices pensados a partir do **clustered index** (a PK); `EXPLAIN` para otimizar.
- JSON nativo, transações/isolamento e fundamentos de replicação/backup.

**Casos de uso:** modelar/otimizar schema InnoDB · escolher tipos/charset · índices · tunar query lenta · transações/isolamento · JSON · operação

---

## Fluxo Cognitivo (Workflow)

1. **InnoDB sempre** (transacional, FK, row-level locking); charset **utf8mb4**.
2. **PK pequena e crescente** — é o **clustered index**: a tabela é fisicamente ordenada por ela; secundários referenciam a PK.
3. **Índice o que filtra/junta/ordena**; cuidado com o tamanho do clustered (PK grande infla todos os secundários).
4. **EXPLAIN / EXPLAIN ANALYZE** para diagnosticar antes de mexer.
5. **Transações** curtas (InnoDB); default REPEATABLE READ, ciente dos gap locks.
6. **JSON** só para o que é realmente flexível; indexado por coluna gerada.
7. **Opere** — backup consistente com restore testado, réplicas com GTID, DDL online, menor privilégio.

---

## Regras Estritas de Execução

- **Engine InnoDB** (não MyISAM): transações, FK, crash-safe, row-level locks.
- **`utf8mb4`** (não `utf8`, que é incompleto/3-byte) + collation adequada (`utf8mb4_0900_ai_ci` ou `_bin`).
- **PK pequena, crescente e imutável** (clustered index) — evite UUID v4 aleatório como PK (fragmenta); use auto-increment ou UUID ordenável (v7/ULID) se precisar.
- **`DECIMAL` para dinheiro**; `DATETIME`/`TIMESTAMP` conscientes de timezone (guarde UTC).
- **Índice conforme filtro/JOIN/ORDER**; lembre que secundário inclui a PK.
- **Parametrize** (anti-SQLi); migrations versionadas; `EXPLAIN` antes de otimizar.
- **Transações curtas**, sem I/O externo (HTTP) entre `START` e `COMMIT`.
- NUNCA `UPDATE/DELETE` sem `WHERE` nem ação destrutiva sem confirmação.

---

## Exemplos Práticos (Few-Shot)

### "cria a tabela de pedidos"

**Erro típico** — `INT` sem `UNSIGNED` (estoura em 2.1bi), `FLOAT` para dinheiro (`19.99` vira `19.989999`), `VARCHAR` livre para status (aceita `'Paid'`, `'pago'`, typo), `ENGINE=MyISAM` (sem transação) e `utf8` (não guarda emoji).

**Ação:** `BIGINT UNSIGNED` + `DECIMAL(10,2)` + `ENUM` fechado + `InnoDB` + `utf8mb4` (§1) — cada escolha de tipo evita uma classe inteira de bug, não só estilo.

### "atualiza o estoque sem deixar dar corrida entre requests"

**Erro típico** — `SELECT` pra ler a quantidade, depois `UPDATE` calculado no app: entre os dois, outra request lê o mesmo valor e a escrita se perde.

**Ação:** `INSERT ... ON DUPLICATE KEY UPDATE qty = qty + VALUES(qty)` — operação atômica no servidor, sem janela de leitura intermediária.

### "a query tá lenta, adiciona índice em toda coluna do WHERE?"

**Ação:** meça antes com `EXPLAIN` (§3) — o plano diz qual índice falta e se um composto vale mais que três soltos. `type=ALL` numa tabela grande é o sinal de "falta índice"; adicionar índice sem olhar o plano é tiro no escuro.

---

## Referência Técnica

### 1. Engine, charset e tipos

**InnoDB** (padrão no MySQL 8): ACID, FK, row-level locking, crash recovery. **MyISAM** é legado (sem transação/FK, table-lock) — evite.

```sql
... ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

`utf8` ❌ é UTF-8 "fake" de 3 bytes (não armazena emoji). `utf8mb4` ✅ é o real de 4 bytes — sempre. Collations: `utf8mb4_0900_ai_ci` (case/acento-insensível, padrão 8), `utf8mb4_bin` (binária), `utf8mb4_0900_as_cs` (sensível). Defina charset no **banco, tabela e conexão**.

| Categoria | Tipos |
|---|---|
| Inteiros | `TINYINT` `SMALLINT` `INT` `BIGINT` (+ `UNSIGNED`); PK típica: `BIGINT UNSIGNED AUTO_INCREMENT` |
| Exatos | `DECIMAL(p,s)` para **dinheiro** — nunca `FLOAT`/`DOUBLE` (esses só para científico/aproximado) |
| Booleano | `BOOLEAN` = alias de `TINYINT(1)` |
| Texto | `VARCHAR(n)` (n em caracteres) · `TEXT`/`MEDIUMTEXT`/`LONGTEXT` (fora da linha) · `CHAR(n)` (raro) · `ENUM('a','b')` (conjunto fechado, compacto) |
| Data/hora | `DATETIME` (range amplo, **não** converte timezone) · `TIMESTAMP` (até 2038, converte p/ tz da sessão, auto-update) · `DATE` `TIME` `YEAR` |
| Semiestruturado | `JSON` nativo (ver 5) |

Padronize em **UTC**. `TIMESTAMP ... DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` para `updated_at`. VARCHAR grande demais ou muitos TEXT impactam buffer/temp tables. Use o menor tipo que comporta o dado; `NOT NULL`/`DEFAULT` onde couber. FK exige InnoDB e tipos compatíveis nas duas pontas. UUID como PK: evite v4 aleatório; se precisar, `BINARY(16)` e/ou UUID ordenável (v7/ULID).

### 2. Índices e clustered index

- A tabela é **fisicamente ordenada pela PK**; as linhas vivem nas folhas do índice da PK — lookup por PK é o mais rápido (sem indireção).
- **Índices secundários** guardam o valor da PK como ponteiro → a busca faz índice → PK → linha (a menos que seja covering).
- **Consequência:** PK grande infla **todos** os secundários. Mantenha-a pequena (BIGINT) e crescente — auto-increment dá inserts sequenciais; UUID v4 aleatório causa page splits.

```sql
CREATE INDEX idx_customer ON orders (customer_id);
CREATE INDEX idx_status_created ON orders (status, created_at);   -- composto (ordem importa)
CREATE INDEX idx_cover ON orders (customer_id, status, total);    -- covering: não vai à linha
CREATE INDEX idx_email_prefix ON users (email(20));               -- prefix index (textos longos)
CREATE INDEX idx_lower_email ON users ((LOWER(email)));           -- functional index (8.0.13+; NÃO existe no MariaDB)
CREATE FULLTEXT INDEX ft_body ON articles (title, body);
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('mysql index' IN NATURAL LANGUAGE MODE);
```

Composto: **igualdade antes de range**; serve para prefixos da esquerda. Prefix index economiza espaço mas não serve para ordenação completa nem unicidade plena. FULLTEXT do InnoDB cobre busca textual simples (relevância avançada → `index-elasticsearch`).

```sql
UNIQUE KEY uq_email (email)
CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
```

FK cria índice automaticamente no lado referenciador (InnoDB) — bom para JOIN.

```sql
EXPLAIN SELECT ... ;                       -- ver se usa índice
SHOW INDEX FROM orders;                    -- índices existentes
SELECT * FROM sys.schema_unused_indexes;   -- índices não usados (sys schema)
```

### 3. Performance e otimização

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 42 AND status = 'paid';
EXPLAIN ANALYZE SELECT ...;     -- MySQL 8: executa e mostra custo/tempo reais
EXPLAIN FORMAT=JSON SELECT ...; -- detalhes
```

Coluna **`type`**, do melhor ao pior: `system/const → ref/eq_ref → range → index → ALL` (full table scan ⚠️). `ALL` em tabela grande filtrada = falta índice. Veja também `key` (índice usado), `rows` (estimativa) e `Extra`.

| Sinal no EXPLAIN | Significa / ação |
|---|---|
| `Using filesort` | ordenação sem índice → crie índice que cubra o `ORDER BY` |
| `Using temporary` | tabela temporária (GROUP BY/DISTINCT pesado) → revise índice/query |
| `type=ALL` + muitas rows | falta índice no filtro |
| N+1 vindo da app | resolva com JOIN/eager loading |

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;        -- loga queries > 1s
SELECT * FROM sys.statements_with_full_table_scans LIMIT 20;
-- ou analise com pt-query-digest (Percona)
```

| Config (`my.cnf`) | Efeito |
|---|---|
| `innodb_buffer_pool_size` | **tuning nº 1** — ~50-75% da RAM (cache de dados/índices) |
| `innodb_log_file_size` | maior = melhor throughput de escrita (com cautela) |
| `innodb_flush_log_at_trx_commit` | `1` durável · `2` mais rápido, menos durável |
| `max_connections` | use pooler/limite; cada conexão custa memória |

**Padrões:** índices certos · colunas explícitas no SELECT · paginação **keyset** (`WHERE id > :last`) em vez de `LIMIT ... OFFSET` alto · evitar funções na coluna do WHERE (usar functional index) · batches/bulk `INSERT` em escritas grandes · cache de leitura quente (Redis) · `ANALYZE TABLE` quando o plano degrada.

### 4. Transações e concorrência

```sql
START TRANSACTION;
  UPDATE accounts SET balance = balance - 100 WHERE id = 1;
  UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;     -- ou ROLLBACK
```

`autocommit` é ON por padrão (cada statement é uma transação). Agrupe com `START TRANSACTION` ou `SET autocommit=0`.

| Nível | No InnoDB |
|---|---|
| READ UNCOMMITTED | dirty reads (evite) |
| READ COMMITTED | lê só commitado (comum em apps web de alta concorrência) |
| REPEATABLE READ | **default**; snapshot consistente; usa next-key locks |
| SERIALIZABLE | leituras viram locking reads |

```sql
SELECT @@transaction_isolation;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

InnoDB usa MVCC para leituras consistentes. No REPEATABLE READ, **next-key locks** (gap locks) previnem phantoms — mas podem causar mais bloqueios/deadlocks em ranges.

```sql
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;     -- lock exclusivo até o commit
SELECT * FROM jobs WHERE status='pending'
  ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED;       -- fila de jobs (MySQL 8)
SELECT ... FOR SHARE;                                -- lock compartilhado

-- concorrência otimista (baixa contenção, sem segurar lock):
UPDATE orders SET status='paid', version=version+1 WHERE id=:id AND version=:v;
-- 0 linhas afetadas = conflito → retry
```

**Deadlock:** InnoDB detecta e aborta uma transação (`ERROR 1213`). Mitigue acessando linhas/tabelas **na mesma ordem**, com transações curtas e índices adequados (locks por linha, não por range), **retry** no erro e idempotência. `SHOW ENGINE INNODB STATUS` mostra o último deadlock.

### 5. JSON

```sql
ALTER TABLE events ADD COLUMN payload JSON;

SELECT payload->>'$.user' AS user,              -- ->> retorna texto (unquoted)
       payload->'$.meta.id' AS id               -- ->  retorna JSON
FROM events
WHERE payload->>'$.status' = 'ok'
  AND JSON_CONTAINS(payload, '"web"', '$.sources');
```

`->` = `JSON_EXTRACT` (JSON) · `->>` extrai e remove aspas (texto) · `$.caminho` é a sintaxe de path. Consultas: `JSON_CONTAINS`, `JSON_OVERLAPS`, `JSON_TABLE`.

```sql
JSON_OBJECT('id', id, 'name', name)               -- construir
JSON_ARRAYAGG(name)                                -- agregar em array
JSON_SET / JSON_INSERT / JSON_REPLACE              -- atualizar campos
JSON_REMOVE(payload, '$.temp')                     -- remover
JSON_TABLE(payload, '$.items[*]' COLUMNS (...))    -- expandir array em linhas

UPDATE events SET payload = JSON_SET(payload, '$.flag', true) WHERE id = :id;
```

MySQL **não** indexa JSON diretamente — crie uma **coluna gerada** e indexe-a:

```sql
ALTER TABLE events
  ADD COLUMN status VARCHAR(20)
    GENERATED ALWAYS AS (payload->>'$.status') STORED,
  ADD INDEX idx_status (status);
-- agora isto usa o índice:
SELECT * FROM events WHERE status = 'ok';
```

`STORED` (ocupa espaço, indexável) ou `VIRTUAL` (calculado, indexável em InnoDB). Multi-valued index (8.0.17+) para arrays: `INDEX ((CAST(payload->'$.tags' AS UNSIGNED ARRAY)))`.
✅ atributos variáveis, metadados, config, payloads flexíveis. ❌ dados estruturados estáveis → colunas relacionais (tipos, índices, FK, integridade). Promova a coluna real os campos sempre filtrados.
O JSONB do Postgres tem indexação mais direta (GIN) e operadores mais ricos — se JSON é central ao projeto, considere `db-postgresql`.

### 6. Replicação, backup e operação

```bash
# lógico (SQL): portável/seletivo; lento para bases grandes
mysqldump --single-transaction --routines --triggers dbname > db.sql
mysqlpump ...                        # paralelo (mais rápido que mysqldump)
# físico: rápido para bases grandes — Percona XtraBackup (hot backup do InnoDB, sem travar)
xtrabackup --backup --target-dir=/bkp
```

`--single-transaction` (InnoDB) dá backup consistente **sem travar**. **Teste o restore** regularmente. PITR = backup + **binlogs**.

**Replicação** `Source → Replica(s)`: assíncrona (padrão, réplica pode ficar com lag) · semi-síncrona (source espera ≥1 réplica confirmar) · **GTID** para failover robusto (recomendado). Usos: réplicas read-only (escala leitura), DR, backup sem impacto no primário. `SHOW REPLICA STATUS\G` mostra `Seconds_Behind_Source` e erros — atenção ao read-after-write.

| Durabilidade | Valor |
|---|---|
| `innodb_flush_log_at_trx_commit` | `1` durável (padrão, cada commit no disco) · `2` mais rápido, perde ~1s em crash do SO |
| `sync_binlog` | `1` binlog durável (importante para replicação/PITR) |

**HA:** InnoDB Cluster (Group Replication + MySQL Router + Shell) com failover automático; gerenciados: RDS/Aurora, Cloud SQL, PlanetScale (Vitess para sharding).
**DDL online:** `ALTER TABLE` pode travar/reescrever a tabela — use `ALGORITHM=INPLACE, LOCK=NONE` quando suportado, ou **gh-ost** / **pt-online-schema-change** em tabelas grandes. Migrations versionadas (Flyway/Liquibase/ORM).
**Segurança:** usuários de menor privilégio (app não usa root), `GRANT` por banco/tabela, TLS, `bind-address` restrito, queries parametrizadas.
**Monitoramento:** Performance Schema / sys schema, slow query log; métricas de conexões, buffer pool hit ratio, lag de replicação, locks/deadlocks, QPS.

---

## Checklist

- [ ] `ENGINE=InnoDB`; `CHARSET=utf8mb4` + collation (banco/tabela/conexão)
- [ ] `DECIMAL` para dinheiro; datas em UTC; tipos dimensionados (`UNSIGNED`, menor tamanho)
- [ ] PK `BIGINT UNSIGNED AUTO_INCREMENT` (ou UUID binário/ordenável) — pequena e crescente
- [ ] `ENUM`/lookup para conjuntos fechados; constraints e FK definidas
- [ ] Índices em FK/filtro/ORDER; composto na ordem certa; covering onde compensa
- [ ] Prefix/functional/FULLTEXT index quando aplicável; índices não usados removidos
- [ ] `EXPLAIN`: `type` ref/range, sem `ALL` em tabela grande filtrada
- [ ] Sem `Using filesort`/`Using temporary` evitáveis; slow query log ativo (sys schema)
- [ ] `innodb_buffer_pool_size` adequado; pooler de conexões; estatísticas atualizadas
- [ ] Paginação keyset; SELECT enxuto; bulk em escrita
- [ ] Multi-passo em transação curta, com rollback em falha e sem I/O externo dentro
- [ ] Isolamento adequado (default REPEATABLE READ; avaliar READ COMMITTED)
- [ ] `FOR UPDATE`/otimista conforme contenção; `SKIP LOCKED` em filas
- [ ] Deadlocks: ordem consistente de acesso + retry idempotente
- [ ] JSON nativo indexado por coluna gerada; estruturado em colunas; campos quentes promovidos
- [ ] Backup consistente (`--single-transaction`/XtraBackup) + **restore testado**; binlog/PITR em prod
- [ ] Réplicas com GTID para leitura/DR, com lag monitorado
- [ ] DDL online (gh-ost/pt-osc) em tabelas grandes; migrations versionadas
- [ ] Usuários com menor privilégio; TLS; queries parametrizadas; monitoramento ativo

---

## Externas

- [MySQL 8 Docs](https://dev.mysql.com/doc/refman/8.0/en/)
- Ferramentas: `EXPLAIN` / `EXPLAIN ANALYZE` · slow query log / Performance Schema / sys schema · mysqldump / mysqlpump / Percona XtraBackup · MySQL Workbench / DBeaver · gh-ost / pt-online-schema-change
- Skills: `db-sql` · `db-postgresql` · `php-laravel` · `index-redis` · `index-elasticsearch` · `web-security`
