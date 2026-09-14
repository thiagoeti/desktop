---
name: index-elasticsearch
description: Elasticsearch — busca full-text e analytics distribuída. Use ao modelar mapeamentos, escrever Query DSL (match/term/bool), relevância (analyzers/scoring), agregações, indexação em massa, e operar índices (shards/réplicas/ILM). Inclui noções de busca vetorial (kNN). Não cobre banco vetorial dedicado (index-qdrant), pipeline de RAG (ts-rag, ai-rag) nem busca textual que ainda cabe no Postgres (db-postgresql).
version: 2.1.0
license: Unlicense
tags:
  - elasticsearch
  - search
  - full-text
  - analytics
  - aggregations
---

# Elasticsearch

Motor de busca e analytics distribuído (sobre Lucene): full-text com relevância, agregações e escala horizontal.

> **Não cobre:** coleção, payload e Query API de banco vetorial dedicado → `index-qdrant` · chunking, reranking e citação → `ts-rag`, `ai-rag` · escolher e gerar embedding → `ai-embeddings` · banco primário → `db-*` · trace e log estruturado da aplicação → `ts-otel`
> **Antes de adotar:** se a busca textual ainda cabe no `tsvector`/GIN do Postgres, ela cabe — veja `db-postgresql §6`. Elasticsearch é um cluster a mais para operar.
> Aqui: **mapping, Query DSL, relevância e agregação**.

---

## Contexto e Objetivo

Indexar e buscar dados com relevância e velocidade: definir mapeamentos/analyzers, escrever Query DSL, calcular relevância, agregar (facets/analytics) e operar índices em escala.

**Casos de uso:** busca full-text (e-commerce, docs) · autocomplete · facets/filtros · analytics/dashboards (Kibana) · logs (ELK) · busca semântica/vetorial

---

## Fluxo Cognitivo (Workflow)

1. **Defina o mapping** — tipos certos: `text` (analisado, busca) vs `keyword` (exato, agregação/sort).
2. **Escolha o analyzer** — idioma/normalização afetam o que casa (stemming, stopwords, lowercase, asciifolding).
3. **Query DSL adequada** — `match` (full-text, analisado) vs `term` (exato); componha com `bool`.
4. **Relevância** — entenda scoring (BM25); use `bool` (must/should/filter), boosting e `function_score`.
5. **Agregue** para facets/analytics (`size: 0`, campos `keyword`/numéricos).
6. **Indexe em massa** com `_bulk`; use alias + reindex para evoluir o mapping sem downtime.
7. **Opere** — shards/réplicas planejados, ILM para time-based, snapshots, auth/TLS.

---

## Regras Estritas de Execução

- **`text` vs `keyword`**: `text` é analisado (full-text, **não** agrega/ordena bem); `keyword` é exato (filtro/agregação/sort). Use `multi-field` (`field` + `field.keyword`) quando precisa dos dois.
- **`match` para texto, `term` para exato** — `term` em campo `text` raramente casa (o texto foi analisado).
- **`filter` (bool) para condições sem score** — é cacheável e mais rápido que `must` quando não precisa de relevância.
- **Indexação em massa via `_bulk`** — nunca um request por documento.
- **Elasticsearch não é fonte da verdade** — é um índice de busca; reindexável a partir do banco primário. Sincronize (não use como DB primário transacional).
- **Mapping explícito** em produção — não confie só no dynamic mapping (evita "mapping explosion" e tipos errados).
- **App sempre usa alias**, nunca o índice físico (permite reindex/troca de versão sem downtime).
- **`search_after` para deep paging** — não `from` alto (limite ~10k, caro).
- NUNCA delete índice/dados sem confirmação.

---

## Exemplos Práticos (Few-Shot)

### "cria o índice de produtos"

**Erro típico** — sem mapping explícito, dynamic mapping decide sozinho: `price` vira `float` (erro de arredondamento em dinheiro) e `tags` vira `text` analisado (`"promo-verão"` vira dois termos, o filtro exato erra).

**Ação:** mapping explícito (§1) — `keyword` para o que é filtro/agregação exato, `scaled_float` para dinheiro, multi-field (`text` + `.raw` keyword) quando precisa dos dois usos no mesmo campo.

### "busca produtos por nome, filtrando tag e preço"

**Erro típico** — filtro exato (`tags`, `price`) dentro de `must` via `match`: calcula score à toa para condição que não devia pontuar, e não aproveita cache.

**Ação:** `must` só para o que pontua relevância (busca textual); `filter` para condição exata — mais rápido e cacheável (§3).

### "mostra os contadores de produtos por tag"

**Erro típico** — `size: 10000` para trazer os documentos junto só para exibir contadores de faceta.

**Ação:** `size: 0` (§5) — a agregação roda sobre o resultado da query sem devolver documento nenhum.

---

## Referência Técnica

### 1. Conceitos e mapping

```txt
Index      ≈ "tabela" (coleção de documentos JSON)     Mapping  = schema do índice (tipos/analyzers)
Document   ≈ "linha" (JSON)                            Analyzer = pipeline de tokenização/normalização
Shard      = partição do índice (escala)               Réplica  = cópia (HA/leitura)
```

| Tipo | Uso |
|---|---|
| `text` | ANALISADO (tokeniza/lowercase/stemming) → full-text (`match`). ❌ sort/agregação |
| `keyword` | NÃO analisado, valor literal → `term`/agregação/sort/filtro |
| `long`/`integer`/`short`/`byte`, `float`/`double`/`scaled_float` | números; `scaled_float` para preço |
| `date` | com formato configurável |
| `boolean`, `ip`, `geo_point`, `geo_shape` | tipos especiais |
| `object` | JSON aninhado (achatado) |
| `nested` | array de objetos onde a relação entre campos importa (evita cruzar valores errados) |
| `dense_vector` | kNN/semântica · `completion` para autocomplete |

```json
"name": { "type": "text", "fields": { "raw": { "type": "keyword" } } }  // multi-field: busca E exato/agg
```

**Dynamic mapping:** em produção defina mapping explícito; `"dynamic": "strict"` rejeita campos não mapeados; `"runtime"` para campos calculados.

**Mapping é imutável em parte** — não dá para mudar o tipo de um campo existente → reindexar. Planeje; use alias para trocar de índice sem downtime.

### 2. Analyzers

Analyzer = **char filters → tokenizer → token filters**. Aplicado na indexação **e** na query.

```txt
standard   → padrão (tokeniza por palavra, lowercase)
keyword    → não quebra (1 token = string inteira)
language   → ex.: "portuguese" (stemming + stopwords do idioma)
custom     → tokenizer + filters (lowercase, asciifolding, synonym, ngram)
```

```json
PUT /articles
{ "settings": { "analysis": { "analyzer": {
    "pt": { "type": "standard" }   // ou custom com stemmer português + asciifolding
}}},
  "mappings": { "properties": {
    "title": { "type": "text", "analyzer": "portuguese" }
}}}

POST /articles/_analyze
{ "analyzer": "portuguese", "text": "Os ratos roeram a roupa" }
```

**asciifolding** (remove acentos) é quase obrigatório em pt-BR (buscar "cafe" e achar "café"). Teste com `_analyze` antes de indexar tudo.

### 3. Query DSL

```json
{ "match": { "name": "tênis de corrida" } }                                  // full-text, analisado
{ "match": { "name": { "query": "tenis corrida", "operator": "and" } } }     // todos os termos
{ "match_phrase": { "name": "tênis de corrida" } }                            // frase exata (ordem)
{ "multi_match": { "query": "corrida", "fields": ["name^2", "desc"] } }        // ^2 = boost
{ "term":  { "status": "active" } }        // exato, NÃO analisado — use em keyword!
{ "terms": { "tags": ["promo", "novo"] } }
{ "range": { "price": { "gte": 100, "lte": 500 } } }
{ "range": { "createdAt": { "gte": "now-7d/d" } } }
{ "match_all": {} }  { "exists": { "field": "email" } }
{ "prefix":   { "sku.keyword": "X1" } }    // começa com (custo)
{ "wildcard": { "sku.keyword": "X*1" } }   // evite curinga no início
{ "fuzzy": { "name": { "value": "tenos", "fuzziness": "AUTO" } } }             // tolera typo
```

**`bool` — o mais importante:**

```json
{ "query": { "bool": {
  "must":     [ { "match": { "name": "corrida" } } ],
  "should":   [ { "match": { "brand": "nike" } } ],
  "must_not": [ { "term": { "status": "discontinued" } } ],
  "filter":   [ { "term": { "inStock": true } },
                { "range": { "price": { "lte": 500 } } } ]
}}}
```

| Cláusula | Score? | Uso |
| --- | --- | --- |
| `must` | sim | precisa casar (relevância) |
| `should` | sim | opcional; aumenta score (boost) |
| `must_not` | não | exclui |
| `filter` | **não** | condição exata, **cacheável/rápida** |

**Paginação:** `{ "from": 20, "size": 10 }` (offset, limite ~10k e caro além) · `{ "size": 10, "search_after": [last_sort_value], "sort": [...] }` (deep paging, preferido) · `scroll` só para exportar tudo, não para UI.

### 4. Relevância e scoring

**BM25** (padrão): **TF** (mais ocorrências → mais relevante, com saturação) · **IDF** (termo raro vale mais) · **comprimento do campo** (termo em campo curto pesa mais). Você raramente ajusta a fórmula — controla pela **estrutura da query**.

```json
{ "bool": {
  "must":   [ { "match": { "title": { "query": "tênis", "boost": 3 } } } ],
  "should": [ { "match": { "description": "corrida" } },
              { "term":  { "brand": { "value": "nike", "boost": 2 } } } ],
  "filter": [ { "term": { "inStock": true } } ]                    // não afeta score
}}
```

```json
{ "multi_match": { "query": "tênis corrida",
  "fields": ["title^3", "brand^2", "description"],
  "type": "best_fields" }}   // best_fields | most_fields | cross_fields | phrase
```

`best_fields` (padrão) usa o melhor campo; `cross_fields` trata os campos como um só (nome+sobrenome).

```json
{ "function_score": {                       // sinais de negócio
  "query": { "match": { "title": "tênis" } },
  "functions": [
    { "field_value_factor": { "field": "popularity", "modifier": "log1p" } },
    { "gauss": { "createdAt": { "scale": "30d" } } }
  ],
  "boost_mode": "multiply"
}}
```

**Autocomplete:** `search_as_you_type` (campo dedicado, prefixo/infix) · `completion suggester` (mais rápido para sugestões) · `edge_ngram analyzer` (tokeniza prefixos).

**Vetorial/semântica (kNN):**

```json
"embedding": { "type": "dense_vector", "dims": 768, "index": true, "similarity": "cosine" }
```

`knn` busca por similaridade de embeddings; combine com BM25 (**hybrid search**).

**Avaliar:** `_explain` para entender o score de um doc; métricas precision@k, recall, NDCG; iterar boosts com dados reais.

### 5. Agregações

```json
GET /products/_search
{ "size": 0,                                    // só os números (mais rápido)
  "query": { "term": { "inStock": true } },     // aggs operam sobre o resultado da query
  "aggs": { "by_category": { "terms": { "field": "category" } } } }
```

| Bucket (agrupam) | Metric (calculam) |
|---|---|
| `terms` (top N valores — em `keyword`!) | `avg` / `max` / `min` / `sum` |
| `date_histogram` (`calendar_interval`/`fixed_interval`) | `cardinality` (distintos aproximados) |
| `range` (faixas de preço) | `stats` (min/max/avg/sum/count) |
| `filter` / `composite` (pagina buckets) | |

```json
"by_category": { "terms": { "field": "category" },
  "aggs": { "avg_price": { "avg": { "field": "price" } } } }   // aninhada: média por categoria

"over_time": { "date_histogram": { "field": "@timestamp", "fixed_interval": "1h" },
  "aggs": { "errors": { "filter": { "term": { "level": "error" } } } } }
```

**Facets (e-commerce):** a mesma request traz resultados + contagens por filtro; cada bucket vira um filtro clicável.

⚠️ `terms`/`sort` exigem campo **não analisado** (`keyword`) ou numérico. Agregar em `text` falha ou exige `fielddata` (caro — evite).

**Performance:** `size: 0`; limitar `size` de buckets; `composite` para paginar; `filter` na query reduz o conjunto antes de agregar.

### 6. Indexação, reindex e performance

```json
PUT /products/_doc/42          // id explícito (idempotente)
{ "name": "Tênis X100", "price": 499.9, "tags": ["corrida"] }
POST /products/_doc            // id automático
```

```txt
POST /_bulk
{ "index": { "_index": "products", "_id": "1" } }
{ "name": "A", "price": 10 }
{ "index": { "_index": "products", "_id": "2" } }
{ "name": "B", "price": 20 }
```

Centenas a milhares por request; clients oficiais têm helpers com chunking/retry.

```json
PUT /products/_settings
{ "index": { "refresh_interval": "30s" } }   // ou "-1" durante carga inicial pesada
```

Refresh default 1s (near-real-time); aumentar/desligar em carga massiva dá muito mais throughput — reative depois.

**Sincronizar do banco primário:** **dual write** (simples, risco de divergência) · **CDC** (Debezium/logs → ES, robusto) · **reindex periódico** (tolera atraso). Projete o índice como reconstruível.

```json
POST /_reindex
{ "source": { "index": "products_v1" }, "dest": { "index": "products_v2" } }

POST /_aliases                              // troca atômica de alias
{ "actions": [
  { "remove": { "index": "products_v1", "alias": "products" } },
  { "add":    { "index": "products_v2", "alias": "products" } }
]}
```

**Performance de busca:** mapping enxuto · `filter` cacheável · evite `wildcard`/`regexp` iniciando com curinga e `script` queries pesadas · `search_after` para deep paging · `"index": false` em campos que não busca · `_source` filtrado · force merge em índices read-only (logs antigos).

### 7. Cluster e operação

```json
PUT /products
{ "settings": { "number_of_shards": 1, "number_of_replicas": 1 } }
```

- `number_of_shards` é fixo na criação (mudar = reindexar); `number_of_replicas` é ajustável.
- **Sem oversharding**: mire shards de ~10–50GB; comece com poucos. Réplicas ≥ 1 em produção (0 só em dev/carga inicial).

```json
GET /_cluster/health   // green (ok) | yellow (réplicas não alocadas) | red (primário faltando — urgente)
GET /_cat/indices?v    GET /_cat/shards?v    GET /_nodes/stats
```

**ILM (dados time-based):** `Hot` (escrita/busca rápida, SSD) → `Warm` (só leitura) → `Cold` (raro, barato) → `Delete` (retenção 30/90d). Use **data streams** + ILM com rollover por tamanho/idade.

**Operação:** snapshots (`_snapshot`, repositório S3) com restore testado · heap da JVM ≤ ~50% da RAM (resto para page cache) · disco com folga (watermark bloqueia escrita) · auth (X-Pack/Security), TLS, RBAC, cluster não exposto à internet.

**Escala:** leitura → mais réplicas/nós · escrita/volume → mais primary shards planejados + nós, data streams para time-series · gerenciado: Elastic Cloud, OpenSearch (AWS).

**ES como índice, não DB primário:** não transacional, near-real-time (~1s de atraso), descartável/recriável.

---

## Checklist

- [ ] Mapping explícito em produção; `text` (busca) vs `keyword` (exato/agg/sort) + multi-field onde precisa
- [ ] Analyzer adequado (idioma + asciifolding em pt-BR); testado com `_analyze`
- [ ] `nested` para arrays de objetos; tipos numéricos/`date` corretos
- [ ] `match` (analisado) para texto; `term`/`terms` (exato) em `keyword`
- [ ] `bool` com `filter` para condições sem relevância (cacheável); `range`/`exists`/`fuzzy`/`multi_match` conforme caso
- [ ] `search_after` para deep paging (não `from` alto)
- [ ] Relevância por boost/fields/filter (não pela fórmula); `function_score` para sinais de negócio
- [ ] Autocomplete (completion/edge_ngram); kNN/hybrid para semântica; relevância avaliada com `_explain`/métricas
- [ ] Agregar em `keyword`/numérico; `size: 0` quando só quer aggs; bucket+metric aninhadas
- [ ] Facets (resultados + contagens) na mesma request; `composite`/limite de `size` para muitos buckets
- [ ] `_bulk` para volume (chunk/retry); `refresh_interval` ajustado em carga inicial
- [ ] ES sincronizado do banco (dual write/CDC/reindex) e reconstruível; alias usado pela app
- [ ] Shards planejados (sem oversharding); réplicas ≥ 1; cluster green
- [ ] ILM/data streams para time-based; snapshots + restore testado
- [ ] Heap ~50% RAM; disco com folga; auth/TLS/RBAC; cluster não exposto
- [ ] ES justificado vs FTS nativo do Postgres (casos menores → `db-postgresql`)

---

## Externas

- [Elasticsearch Guide](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html) · [Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html)
- Ferramentas: Kibana (Dev Tools/dashboards) · clients oficiais (JS/Python) · ELK/Elastic Stack (Logstash/Beats) · OpenSearch (fork)
- Skills: `db-postgresql` · `db-*` · `ai-embeddings` · `ai-rag`
