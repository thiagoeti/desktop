---
name: python-backend
description: Backend Python moderno — ambiente/deps (uv), type hints + mypy/pyright, estrutura em camadas, async (asyncio), validação (Pydantic v2), acesso a dados (SQLAlchemy) e testes (pytest). Use ao estruturar serviço Python, configurar pyproject/uv, tipar código, validar dados ou aplicar padrões backend. Não cobre FastAPI (python-fastapi), parsing de HTML (scraping-beautifulsoup) nem desenho de recurso REST (api-rest).
version: 3.2.0
license: Unlicense
tags:
  - python
  - backend
  - asyncio
  - pydantic
  - pytest
---

# Backend com Python (moderno)

Código tipado e validado, estrutura clara, async quando há I/O, testes com pytest. Python 3.12+.

> **Não cobre:** rota, injeção de dependência e OpenAPI do framework → `python-fastapi` · SQL, índice e tuning → `db-*` · desenho do contrato → `api-rest` · camadas formais → `arch-clean`, `arch-hexagonal` · parsing de HTML → `scraping-beautifulsoup`
> Aqui: **a base do serviço** — ambiente, tipos, camadas, async, dados, teste.

---

## Contexto e Objetivo

- Ambiente reprodutível (uv + lockfile) e toolchain única no `pyproject.toml`.
- Tipos checados estaticamente + dados validados em runtime nas bordas.
- I/O assíncrono onde faz sentido; camadas separadas e testáveis.

**Casos de uso:** iniciar/estruturar serviço · gerenciar deps (uv/pyproject) · tipar e validar · async I/O · acesso a dados (SQLAlchemy) · pytest

---

## Fluxo Cognitivo (Workflow)

1. **Ambiente reprodutível** — `uv` + `pyproject.toml`; venv isolado; lockfile.
2. **Type hints + checador** — anote tipos; rode `mypy`/`pyright` (estático, não é runtime).
3. **Valide dados** — Pydantic v2 nas bordas (input externo) e configs.
4. **Camadas** — rota/handler → service (regra) → repositório (dados).
5. **Async só para I/O** — `async/await` com libs async; não bloqueie o event loop.
6. **Dados com SQLAlchemy 2.0** — sessão por request, repositório isolado, Alembic versionado.
7. **Teste com pytest** (unit + integração) e valide com o Checklist final.

---

## Regras Estritas de Execução

- **Ambiente isolado e reprodutível** — `uv`/venv + lockfile; nunca instale global no projeto.
- **Type hints em código novo**; rode `mypy --strict` ou `pyright` no CI.
- **Valide input externo com Pydantic** — type hint não valida em runtime.
- **async só com I/O e libs async**; nunca chame função bloqueante (CPU/IO sync) no event loop — use `asyncio.to_thread`/executor.
- **Camadas**: regra de negócio fora do handler; dependa de abstrações onde a troca importa.
- **PEP 8 / ruff**; nomes claros; funções pequenas.
- **Segredos em env/secret manager** (validados via Settings); sem segredo no código.
- NUNCA execute ações destrutivas sem confirmação explícita do usuário humano.

---

## Exemplos Práticos (Few-Shot)

### "adiciona validação nesse endpoint"

**Erro típico** — type hint tratado como validação:

```python
def handler(payload: dict) -> User:
    email: str = payload["email"]      # 1. hint não confere nada em runtime
    age = int(payload.get("age", 0))   # 2. KeyError/ValueError sem contexto de campo
    return user_service.create(email, age)
```

**Ação:** modelo Pydantic na borda com `model_validate` (§5). Por padrão o v2 **coage** (`"123"` → `int`) — se o dado vem de fonte não confiável e a coerção mascara erro, use `strict=True`. Valide **uma vez**, na borda: revalidar a cada camada só custa CPU e mascara de onde veio o dado ruim.

### "por que o serviço async está lento se tudo é `await`?"

**Erro típico** — `await` dentro de loop e lib síncrona no meio do caminho:

```python
async def fetch_all(ids: list[str]) -> list[User]:
    users = [await repo.find_by_id(i) for i in ids]  # 1. serial: latências somadas
    perfil = requests.get(url).json()                # 2. lib sync trava TODAS as corrotinas
    return users
```

**Ação:** `asyncio.gather`/`TaskGroup` + lib async (httpx/asyncpg), §4. Duas pegadinhas que a correção óbvia esquece: `gather` sem limite dispara milhares de conexões (use `Semaphore`), e sem `asyncio.timeout` uma chamada pendurada segura o TaskGroup inteiro. Se a latência não mudou nada, procure `await` esquecido — a corrotina nunca roda e só aparece um warning "never awaited".

### "devolve o usuário do banco na resposta"

**Erro típico** — retornar o modelo ORM cru direto do repositório.

**Ação:** schema Pydantic de saída na borda; o modelo ORM não sai da camada de dados (§6, §3). Além de vazar colunas sensíveis, serializar o modelo fora da sessão dispara lazy-load: em async isso quebra ou vira N+1 — por isso `expire_on_commit=False` e `selectinload` em relações que a resposta usa.

### "sobe esse projeto Python aqui pra rodar"

**Ação:** `uv sync` a partir do `uv.lock` commitado, nunca `pip install` no ambiente global (§1). No CI use `uv sync --frozen`: ele **falha** se o lock estiver desatualizado em relação ao `pyproject.toml` — é exatamente o que se quer lá, e o que não se quer localmente (onde `uv add` atualiza o lock).

### "escreve testes pro UserService"

**Ação:** fake ou `AsyncMock` do repositório, nunca o DB real no unit (§7). `Mock` comum em método async devolve uma corrotina que ninguém aguarda e o teste passa por engano — use `AsyncMock` + `assert_awaited_once_with`. E confira `asyncio_mode = "auto"` (ou `@pytest.mark.asyncio`): sem isso o pytest coleta o teste async e não executa o corpo.

---

## Referência Técnica

### 1. Stack e setup (uv, pyproject, ruff)

**Stack:** ambiente/deps **uv** + `pyproject.toml` + `uv.lock` (alternativas: Poetry, PDM, pip+venv — o essencial é venv isolado + lockfile) · lint/format **ruff** (substitui flake8+black+isort) · tipos `mypy --strict` ou `pyright` · validação Pydantic v2 (+ pydantic-settings) · ORM SQLAlchemy 2.0 async + Alembic · testes pytest (+ pytest-asyncio, httpx).

```bash
uv init meu-servico                 # cria pyproject.toml + estrutura
uv add fastapi "sqlalchemy[asyncio]" pydantic-settings
uv add --dev pytest pytest-asyncio ruff mypy httpx
uv run python -m app                # roda no venv do projeto (sem ativar)
uv sync                             # instala exatamente do uv.lock; uv python pin 3.12
uv run ruff check --fix . && uv run ruff format .
```

```toml
[project]
name = "meu-servico"
requires-python = ">=3.12"
dependencies = ["fastapi", "pydantic-settings", "sqlalchemy[asyncio]"]
[dependency-groups]
dev = ["pytest", "pytest-asyncio", "ruff", "mypy", "httpx"]
[tool.ruff]
line-length = 100
[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "ASYNC"]   # erros, flake8, isort, pyupgrade, bugbear, async
[tool.mypy]
strict = true
python_version = "3.12"
[tool.pytest.ini_options]
asyncio_mode = "auto"        # pytest-asyncio trata test async automaticamente
testpaths = ["tests"]
```

**CI mínimo:** `uv sync --frozen` (falha se o lock estiver desatualizado) → `ruff check .` → `mypy src` → `pytest`. Layout `src/` evita imports acidentais do cwd.

### 2. Type hints e checagem estática

Hints **não** são validados em runtime (para isso, Pydantic). Use sintaxe moderna: `list`/`dict`/`tuple` direto (não `List`/`Dict`), `X | None` (não `Optional[X]`).

```python
from typing import Final, Literal, TypedDict, NewType, TypeVar, Generic, Protocol

def total(itens: list[dict[str, float]]) -> float: ...   # anote assinaturas e fronteiras
users: dict[str, User] = {}
Status = Literal["pending", "paid", "cancelled"]   # estados como union de strings
MAX: Final = 100
UserId = NewType("UserId", str)                    # id distinto de str comum
class UserDict(TypedDict): id: str; email: str      # dict com forma conhecida

T = TypeVar("T")
class Repository(Generic[T]):                       # 3.12+: class Repository[T]:
    async def find_by_id(self, id: str) -> T | None: ...

class SupportsSave(Protocol):                       # duck typing estrutural (sem herança)
    def save(self) -> None: ...
@dataclass(frozen=True, slots=True)                 # estruturas internas simples
class Point: x: float; y: float
```

**Narrowing:** `isinstance`, `is None`, `assert` e `TypeGuard` estreitam tipos (dentro de `if isinstance(x, int):` o mypy trata `x` como `int`). `Any` desliga a checagem — prefira `object`/Protocol/generics; se usar `# type: ignore`, comente o porquê. Rode **strict** no CI (`uv run mypy src`); pyright é a alternativa (Pylance no VS Code). Pydantic quando precisa de validação de dado externo.

### 3. Estrutura em camadas e DI

```txt
Router/Handler  → borda (HTTP): valida input, formata resposta
Service         → regra de negócio (orquestra, decide)
Repository      → acesso a dados (ORM/queries)   ·   Domain/Models → entidades e tipos

src/app/ ├── main.py · config.py (Settings) ├── shared/ (erros, utils, tipos)
         └── modules/users/{router,service,repository,schemas,models}.py   + tests/
```

```python
class UserRepository(Protocol):                     # abstração onde a troca importa
    async def find_by_id(self, id: str) -> User | None: ...
    async def save(self, user: User) -> User: ...

class UserService:
    def __init__(self, repo: UserRepository) -> None: self._repo = repo   # DI (ou Depends)

service = UserService(SqlAlchemyUserRepository(session))   # composição
```

- Organize por **feature**, não por tipo técnico (`controllers/`, `services/` globais); regra de negócio não mora no handler nem no repositório.
- Imports unidirecionais: router → service → repository; o domínio não importa framework/ORM. Schemas (entrada/saída) na borda; nunca exponha o modelo ORM cru na resposta.
- SRP: um motivo para mudar por módulo; funções pequenas, nomes claros (PEP 8). Padrões formais (Clean, Hexagonal, DDD): ver `arch-*`.

### 4. Async (asyncio)

```txt
I/O-bound (rede, DB, APIs, fila)  → async (alta concorrência com pouco custo)
CPU-bound (cálculo pesado)        → thread/processo (ProcessPool), não async puro
Código simples sync               → não force async sem necessidade
```

```python
import asyncio

async def fetch(url: str) -> str:
    async with httpx.AsyncClient() as client: return (await client.get(url)).text

users = await asyncio.gather(*(repo.find_by_id(i) for i in ids))   # paralelo
results = await asyncio.gather(*tasks, return_exceptions=True)     # erro individual

async with asyncio.TaskGroup() as tg:      # 3.11+: cancela irmãos se um falha (recomendado)
    t1 = tg.create_task(fetch(a)); t2 = tg.create_task(fetch(b))
async with asyncio.timeout(5):             # 3.11+: sempre limite I/O de rede
    await operacao_lenta()

sem = asyncio.Semaphore(20)                # limitar concorrência (não dispare 10k tasks)
async def limited(i):
    async with sem: return await fetch(i)
queue: asyncio.Queue[str] = asyncio.Queue()   # produtor/consumidor

# ❌ bloqueia o loop: requests.get(url) (lib sync) · heavy_cpu(data) (CPU)
data = await client.get(url)                       # ✅ lib async (httpx)
result = await asyncio.to_thread(heavy_cpu, data)  # ✅ thread para CPU/sync
```

Uma chamada síncrona lenta trava **todas** as corrotinas. Use libs async (httpx, asyncpg, SQLAlchemy async, aioredis); `to_thread` para bloqueio pontual, ProcessPool para CPU pesada. Trate `asyncio.CancelledError` (não engula). **Armadilhas:** sync bloqueante no loop (causa nº 1 de "async lento") · `await` esquecido (corrotina nunca executa; warning "never awaited") · `gather` sem limite · async onde sync bastava.

### 5. Validação com Pydantic v2

```python
from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator, ValidationError
class CreateUser(BaseModel):
    email: EmailStr
    age: int = Field(ge=18, le=120)
    name: str = Field(min_length=1, max_length=100)
    tags: list[str] = []

user = CreateUser.model_validate(payload)   # lança ValidationError se inválido
data = user.model_dump()                     # → dict ; model_dump_json() → str JSON
# except ValidationError as e: e.errors() → lista (loc, msg, type) p/ mapear na resposta da API
class SignUp(BaseModel):
    password: str = Field(min_length=8)
    confirm: str

    @field_validator("password")            # valida um campo
    @classmethod
    def strong(cls, v: str) -> str:
        if not any(c.isdigit() for c in v): raise ValueError("precisa de número")
        return v

    @model_validator(mode="after")          # valida o modelo inteiro (cruza campos)
    def match(self) -> "SignUp":
        if self.password != self.confirm: raise ValueError("senhas não conferem")
        return self

from pydantic_settings import BaseSettings, SettingsConfigDict
class Settings(BaseSettings):
    database_url: str
    jwt_secret: str = Field(min_length=32)
    debug: bool = False
    model_config = SettingsConfigDict(env_file=".env")
settings = Settings()   # lê env no boot; erro claro se faltar/inválido (fail fast)
```

**Migração v1 → v2:** `.dict()`→`.model_dump()` · `.json()`→`.model_dump_json()` · `.parse_obj()`→`.model_validate()` · `@validator`→`@field_validator` · `class Config`→`model_config = {...}`

- Pydantic **converte** quando seguro (`"123"` → `int`); use `strict=True` para não coagir. Tipos ricos: `EmailStr`, `HttpUrl`, `UUID4`, `datetime`, `Decimal`, `SecretStr` (não vaza em repr/log); `Annotated[int, Field(gt=0)]` reutiliza constraints.
- **Onde validar:** entrada HTTP/fila/webhook e resposta de terceiros → modelo Pydantic · configuração/env → `BaseSettings` no boot · interior já validado → não revalide a cada camada. No FastAPI a validação é automática (request → modelo) e gera 422; ver `python-fastapi`.

### 6. Acesso a dados (SQLAlchemy 2.0 + Alembic)

```python
from sqlalchemy import select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
class Base(DeclarativeBase): ...
class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(primary_key=True)        # Mapped[...] dá tipagem real
    email: Mapped[str] = mapped_column(unique=True, index=True)
    orders: Mapped[list["Order"]] = relationship(back_populates="user")
engine = create_async_engine(settings.database_url, pool_size=10, pool_pre_ping=True)
Session = async_sessionmaker(engine, expire_on_commit=False)   # driver async: postgresql+asyncpg://

async def get_session():                                       # dependência: sessão por request
    async with Session() as session: yield session
async with Session() as s:
    user = await s.get(User, user_id)                        # por PK
    user = (await s.scalars(select(User).where(User.email == email))).first()   # estilo 2.0
    s.add(User(id=..., email=...)); await s.commit()
class SqlAlchemyUserRepository:                              # esconde o ORM atrás de um Protocol
    def __init__(self, session: AsyncSession) -> None: self._s = session
    async def find_by_id(self, id: str) -> User | None: return await self._s.get(User, id)
    async def save(self, user: User) -> User:
        self._s.add(user); await self._s.commit(); return user
# uv run alembic init migrations
# uv run alembic revision --autogenerate -m "create users"  → revise: autogenerate não é perfeito
# uv run alembic upgrade head                               → migrações versionadas no repo
```

- **Sessão por request** (no FastAPI via `Depends`), nunca compartilhada; **pool** dimensionado com `pool_pre_ping=True` (serverless: pooler externo).
- **Evite N+1** (`selectinload`/`joinedload`); transações explícitas em operações multi-passo; **nunca** interpole input em SQL cru (parâmetros/expressões, anti-SQLi). Resposta via schema Pydantic, não o modelo ORM cru (não vaze colunas sensíveis).
- **Alternativas:** SQLModel (SQLAlchemy + Pydantic, bom com FastAPI) · asyncpg direto (sem ORM) · Tortoise ORM.

### 7. Testes (pytest)

```python
import pytest
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
def test_lanca_em_idade_invalida():
    with pytest.raises(ValueError, match="idade"): CreateUser(email="a@b.com", age=10)

@pytest.fixture                      # fixtures injetadas por nome; conftest.py compartilha
def user_service():                  # escopo: function (padrão), module, session
    return UserService(FakeUserRepository())

@pytest.mark.asyncio                 # ou asyncio_mode="auto" no config
async def test_by_id(user_service): assert (await user_service.by_id("1")).email

def test_service_chama_repo():
    repo = AsyncMock(); repo.find_by_id.return_value = User(id="1", email="a@b.com")
    UserService(repo)
    repo.find_by_id.assert_awaited_once_with("1")

@pytest.mark.parametrize("entrada,esperado", [(2, 4), (3, 9), (4, 16)])
def test_quadrado(entrada, esperado): assert quadrado(entrada) == esperado
async def test_post_users():         # integração HTTP (FastAPI)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        assert (await ac.post("/users", json={"email": "x"})).status_code == 422
```

- Mocke **dependências externas** (rede, DB, relógio), não a lógica: `unittest.mock` (`Mock`/`AsyncMock`/`patch`) ou `pytest-mock` (`mocker`); HTTP externo com **respx** (httpx).
- Banco: unit com fake/mock do repositório; integração com DB efêmero (**testcontainers** ou Postgres de teste) + transação/rollback entre testes. AAA (Arrange/Act/Assert); um comportamento por teste; nomes descritivos; determinístico (controle tempo/rede/ordem); caminhos críticos cobertos (não 100% por vaidade). CI: `uv run pytest` + mypy + ruff.

---

## Checklist

- [ ] uv/venv com lockfile commitado; `requires-python` definido; layout `src/`; deps de dev separadas
- [ ] ruff (lint + format); mypy --strict ou pyright; `uv sync --frozen` + ruff + mypy + pytest no CI
- [ ] Assinaturas anotadas; sintaxe moderna (`list[...]`, `X | None`); `Literal`/`TypedDict`/Protocol onde cabe; sem `Any`/`type: ignore` solto
- [ ] Input externo validado com Pydantic v2 (não só type hint); API v2 (`model_validate`/`model_dump`)
- [ ] Settings via `BaseSettings` (fail fast); `SecretStr` em segredos; `ValidationError` mapeado para a API
- [ ] Camadas (router/service/repo) por feature; regra fora do handler; imports unidirecionais
- [ ] DI por construtor/`Depends`; Protocol onde a troca importa; schemas nas bordas (ORM não vaza)
- [ ] async só para I/O com libs async; nada bloqueante no loop (`to_thread`/ProcessPool); timeouts; `gather`/`TaskGroup` com concorrência limitada; sem `await` esquecido
- [ ] SQLAlchemy 2.0 (`Mapped`/`select`) com driver async; sessão por request; pool dimensionado; repositório isolado (Protocol)
- [ ] Migrações Alembic versionadas e revisadas; sem N+1; transações; queries parametrizadas
- [ ] pytest (unit + integração); externos mockados; DB efêmero; caminhos críticos; determinístico
- [ ] Segredos em env; logs estruturados sem dados sensíveis

---

## Externas

- [Python Docs](https://docs.python.org/3/) · [uv](https://docs.astral.sh/uv/) · [ruff](https://docs.astral.sh/ruff/) · [Pydantic](https://docs.pydantic.dev/)
- Skills: `python-fastapi` · `db-*` · `api-rest` · `arch-*`
