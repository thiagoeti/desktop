---
name: db-mariadb
description: MariaDB e onde ele diverge do MySQL — JSON como LONGTEXT, RETURNING, sequences, tabelas versionadas por sistema, engines próprias (Aria, MyRocks, ColumnStore), GTID e collation incompatíveis. Use ao escolher entre MariaDB e MySQL, migrar de um para o outro, depurar SQL que funciona num e falha no outro, configurar replicação, ou escolher engine de tabela. Não cobre MySQL puro (db-mysql), fundamentos e tuning de query (db-sql) nem migração sem downtime (db-migrations).
version: 1.3.0
license: Unlicense
tags:
  - mariadb
  - mysql
  - banco-de-dados
  - replicacao
  - engines
---

# db-mariadb

MariaDB é um fork do MySQL, não um clone. O que quebra não é a sintaxe comum — é **assumir que o que vale para MySQL vale aqui**.

> MySQL `db-mysql` · SQL e tuning de query `db-sql` · ORM em TS `db-drizzle` · Migração sem downtime `db-migrations`

**Não cobre:** modelagem e queries genéricas de SQL → `db-sql` · camada TypeScript → `db-drizzle` · migração sem downtime → `db-migrations`.

Divergências desta referência **verificadas por execução** contra `MariaDB 10.11.14` — ver as marcas ✓ na §2.

---

## Contexto e Objetivo

- Decidir entre MariaDB e MySQL com critério técnico, não por hábito.
- Escrever SQL que roda no banco que você tem, sabendo qual recurso é exclusivo de cada lado.
- Migrar entre os dois sem descobrir a incompatibilidade em produção.
- Escolher engine de tabela pelo padrão de acesso.

**Casos de uso:** escolher o banco · migrar MySQL ↔ MariaDB · depurar SQL que só falha num deles · configurar replicação · decidir a engine · resolver erro de autenticação na conexão · lidar com coluna JSON

---

## Fluxo Cognitivo (Workflow)

1. **Descubra o servidor real** (§1) — `SELECT VERSION()` diz qual fork e qual versão; nunca presuma.
2. **Confira a tabela de divergências** (§2) antes de usar recurso que você conhece do outro lado.
3. **Trate JSON com cuidado especial** (§3) — é o ponto onde os dois mais divergem.
4. **Escolha a engine pelo padrão de acesso** (§4).
5. **Se for migrar, siga a ordem de §5** — collation e autenticação quebram antes do dado.
6. **Replicação: escolha o modo de GTID conscientemente** (§6) — os dois esquemas não conversam.

---

## Regras Estritas de Execução

- **Nunca presuma o fork pelo nome do comando.** O cliente `mysql` costuma ser um link para o cliente MariaDB. `SELECT VERSION()` é a única fonte — a string traz `MariaDB` quando é MariaDB.
- **Nunca trate a coluna `JSON` do MariaDB como tipo binário.** No MariaDB, `JSON` é **alias de `LONGTEXT`** com uma checagem de validade; não há armazenamento binário nem indexação de caminho como no MySQL. Consulta que dependia de desempenho de JSON binário degrada silenciosamente na migração.
- **Nunca replique MariaDB → MySQL nem o contrário via GTID.** Os dois implementaram GTID de formas diferentes e incompatíveis. Replicação entre forks exige posição de binlog, e mesmo assim é frágil — trate como migração, não como topologia permanente.
- **Nunca copie collation do MySQL 8 para o MariaDB.** As collations `utf8mb4_0900_*` são do MySQL 8 e não existem no MariaDB; um dump com elas falha na restauração.
- **Nunca use `RETURNING`, `CREATE SEQUENCE` ou tabela versionada por sistema em código que também precisa rodar em MySQL** — são exclusivos do MariaDB e não têm equivalente sintático.
- **Sempre declare a engine explicitamente** em tabela que não é InnoDB. Depender do default torna o schema dependente da configuração do servidor.
- NUNCA execute ação destrutiva (`DROP`, `TRUNCATE`, alteração de engine em tabela grande) sem confirmação explícita do usuário humano.

---

## Exemplos Práticos (Few-Shot)

### "migrei do MySQL 8 pro MariaDB e o dump não restaura"

**Erro típico** — procurar o erro no dado. A falha quase sempre está no cabeçalho de cada `CREATE TABLE`: o `mysqldump` do MySQL 8 escreve `COLLATE=utf8mb4_0900_ai_ci`, que o MariaDB não conhece. O erro aponta a linha da tabela, não a causa.

**Ação:** normalize a collation **antes** de restaurar, não depois (§5). Depois confira se alguma coluna era `JSON` — no destino ela vira texto, e qualquer índice funcional sobre caminho do JSON precisa ser repensado (§3).

### "a aplicação conecta no MySQL e falha no MariaDB com erro de plugin de autenticação"

**Erro típico** — mexer na senha. O problema é o plugin: o MySQL 8 usa `caching_sha2_password` por padrão e o MariaDB não o implementa. Driver configurado para um não fala com o outro.

**Ação:** confira o plugin do usuário em `mysql.global_priv`/`mysql.user` e alinhe driver e servidor (§5). Trocar a senha sem trocar o plugin não resolve, e é o que faz o problema parecer intermitente.

---

## Referência Técnica

### 1. Identificar o servidor

```sql
SELECT VERSION();          -- string com "MariaDB" quando e MariaDB
SHOW VARIABLES LIKE 'version_comment';
SELECT @@version_comment;
```

O binário `mysql` na maioria das distribuições é um link para o cliente MariaDB — o nome do comando não diz nada sobre o servidor do outro lado da conexão.

### 2. Divergências que quebram código

| Recurso | MariaDB | MySQL |
|---|---|---|
| Tipo `JSON` ✓ | alias de `LONGTEXT` + checagem de validade | tipo binário próprio, com acesso por caminho |
| `RETURNING` em `INSERT`/`DELETE`/`REPLACE` ✓ | sim | não |
| `CREATE SEQUENCE` ✓ | sim | não (só `AUTO_INCREMENT`) |
| Tabela versionada por sistema (histórico temporal) ✓ | sim | não |
| `CHECK` constraint | aplicado | aplicado (MySQL 8+) |
| Coluna invisível | sim | sim (MySQL 8+) |
| CTE e window function | sim | sim (MySQL 8+) |
| Engine ColumnStore, Spider, Aria | sim | não |
| MyRocks | sim | não (existe fora do MySQL oficial) |
| Cache de query ✓ | mantido (a variável `query_cache_type` existe) | **removido** no MySQL 8 |
| Collation `utf8mb4_0900_*` ✓ | não existe | padrão no MySQL 8 |
| `caching_sha2_password` ✓ | não implementado | padrão no MySQL 8 |
| GTID | esquema próprio | esquema próprio — **incompatíveis entre si** |
| Pool de threads na edição comunitária | sim | só na edição Enterprise |
| Índice funcional `((LOWER(col)))` ✓ | **não existe** — erro de sintaxe | sim (MySQL 8.0.13+) |
| Variável de isolamento ✓ | `@@tx_isolation` | `@@transaction_isolation` — o nome do MariaDB foi removido |

Recurso exclusivo de um lado é dívida de portabilidade: use quando a decisão de banco estiver firmada, nunca em código que precise rodar nos dois.

**Como confirmar no servidor que você tem**, sem confiar em tabela nenhuma:

```sql
-- JSON e mesmo LONGTEXT aqui?
SELECT DATA_TYPE FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='sua_tabela' AND COLUMN_NAME='seu_json';
-- collation e plugin de auth do MySQL 8 existem?
SELECT COUNT(*) FROM information_schema.COLLATIONS WHERE COLLATION_NAME LIKE 'utf8mb4_0900%';
SELECT COUNT(*) FROM information_schema.PLUGINS WHERE PLUGIN_NAME='caching_sha2_password';
```

Medido em 10.11.14: `DATA_TYPE` volta `longtext` para coluna declarada `JSON`, e as duas contagens voltam **0**.

### 3. JSON — a divergência mais cara

No MariaDB, `JSON` não é um tipo de armazenamento: é `LONGTEXT` com validação. Consequências práticas:

| Consequência | O que fazer |
|---|---|
| Não há parsing pré-computado; cada acesso reprocessa o texto | não use JSON como caminho quente de leitura |
| Não dá para indexar caminho do JSON diretamente | extraia o campo para **coluna gerada** e indexe essa coluna |
| Comparação de igualdade compara **texto**, não estrutura | normalize antes de comparar, ou compare campo a campo |
| Tamanho conta como texto | atenção ao limite de linha e ao `max_allowed_packet` |

A saída padrão é a mesma dos dois lados: **campo que se consulta ou ordena vira coluna real** (gerada ou comum), e o JSON guarda só o que é acessório. Isso vale como boa prática no MySQL e como necessidade no MariaDB.

### 4. Engines

| Engine | Quando |
|---|---|
| **InnoDB** | padrão e resposta certa em quase todo caso — transação, FK, recuperação após queda |
| **Aria** | tabela temporária interna e carga só-leitura; sem transação |
| **MyRocks** ⚙️ | escrita muito pesada com pouca folga de disco (compressão alta, amplificação de escrita baixa) |
| **ColumnStore** ⚙️ | analítico sobre volume grande; não é para OLTP |
| **Spider** ⚙️ | sharding transparente; complexidade operacional alta, adote só com necessidade comprovada |
| **MEMORY** | cache volátil; perde tudo no restart |

⚙️ **Não vêm no build padrão.** São plugins empacotados à parte, e "MariaDB tem MyRocks" não significa que o **seu** MariaDB tem. Medido numa instalação 10.11.14 de distribuição: as engines disponíveis eram apenas `InnoDB` (default), `Aria`, `MyISAM` e `MEMORY` — as três marcadas não apareciam. Confira antes de desenhar em cima:

```sql
SELECT ENGINE, SUPPORT FROM information_schema.ENGINES ORDER BY ENGINE;
```

Descobrir isso na hora do deploy, com o schema já escrito, é caro; a consulta acima custa nada.

Declare sempre: `ENGINE=InnoDB` no `CREATE TABLE`. Tabela sem engine explícita herda o default do servidor, e o schema deixa de ser reprodutível.

### 5. Migrar entre os forks — ordem que evita retrabalho

1. **Levante os incompatíveis antes de exportar** — colunas `JSON`, uso de `RETURNING`, sequences, tabelas temporais, engines exclusivas.
2. **Normalize a collation no dump**, antes da restauração. É a falha mais comum e a mais fácil de evitar.
3. **Alinhe o plugin de autenticação** de cada usuário com o que o driver da aplicação suporta.
4. **Restaure em ambiente de teste e rode a suíte**, não só o restore — o restore passar não significa que a aplicação funciona.
5. **Compare contagem por tabela** entre origem e destino antes de apontar a aplicação.
6. **Meça as queries quentes nos dois** — plano de execução e otimizador divergem; query que era rápida pode não ser.

Sempre teste a restauração num ambiente descartável primeiro. Migração validada só no papel falha na janela de manutenção.

### 6. Replicação

- Dentro do mesmo fork, use GTID: recuperação e troca de master ficam muito mais simples.
- **Entre forks, GTID não serve** — os esquemas são incompatíveis. O caminho é posição de binlog, e ainda assim como operação de migração, com janela definida, não como topologia que se mantém.
- Réplica atrasada é ferramenta de recuperação contra erro humano: dá tempo de parar antes que um `DELETE` sem `WHERE` chegue lá.
- Monitore o atraso da réplica como métrica de primeira classe. Réplica que atrasa em silêncio é backup que não existe.

---

## Checklist

- [ ] Servidor identificado por `SELECT VERSION()`, não presumido
- [ ] Nenhum recurso exclusivo de um fork em código que precisa rodar nos dois
- [ ] Coluna `JSON` avaliada contra §3; campo consultado extraído para coluna indexável
- [ ] `ENGINE=` explícito em todo `CREATE TABLE`
- [ ] Collation normalizada antes de qualquer restauração cruzada
- [ ] Plugin de autenticação alinhado entre servidor e driver
- [ ] Replicação entre forks tratada como migração com janela, nunca como topologia
- [ ] Atraso de réplica monitorado
- [ ] Restauração testada em ambiente descartável antes da janela real
- [ ] Queries quentes medidas no banco de destino, não só no de origem

## Externas

- MariaDB Server Documentation — https://mariadb.com/kb/en/documentation/
- Incompatibilidades com MySQL — https://mariadb.com/kb/en/incompatibilities-and-feature-differences-between-mariadb-and-mysql/
- Skills relacionadas — `db-mysql` · `db-sql` · `db-drizzle` · `db-migrations`
