---
name: php-hyperf
description: APIs PHP de alta performance com Hyperf (coroutines sobre Swoole/Swow) — DI/AOP, rotas/controllers por anotação, corrotinas e pools de conexão, model/ORM, middleware e testes. Use ao criar API async/microsserviço PHP, WebSocket, ou precisar de PHP persistente de alta performance. Não cobre PHP puro (php-backend), Laravel (php-laravel) nem desenho de recurso REST (api-rest).
version: 3.2.0
license: Unlicense
tags:
  - hyperf
  - php
  - swoole
  - coroutines
  - async
---

# Hyperf (PHP Async / Coroutines)

Framework PHP de alta performance: servidor **persistente** (Swoole/Swow) com **corrotinas**, DI e AOP.

> **Não cobre:** tipos, PSR, Composer e estrutura de PHP moderno → `php-backend` · app tradicional em FPM, com Eloquent e Blade → `php-laravel` · desenho do contrato → `api-rest` · SQL → `db-*` · resiliência entre serviços → `arch-microservices`
> Aqui: **PHP assíncrono** — corrotina, pool de conexão, e o que muda quando o processo é longo.

---

## Contexto e Objetivo

- App fica **em memória** (long-running) — sem bootstrap por request.
- Corrotinas dão I/O não-bloqueante; pools de conexão são reutilizados.
- Preço: disciplina com estado global e uso exclusivo de I/O coroutine-aware.

**Casos de uso:** API async de alta performance · microsserviços (RPC/gRPC) · WebSocket · workers event-driven · processamento concorrente

---

## Fluxo Cognitivo (Workflow)

1. **Mentalidade long-running** — o processo persiste entre requests; cuidado com estado global/singletons (memory leak, vazamento entre requests).
2. **Corrotinas para I/O** — DB/HTTP/Redis async automaticamente; nunca chame função bloqueante.
3. **DI + anotações** — injete dependências; rotas/middleware/validação por `#[Attributes]`.
4. **Pools de conexão** — DB/Redis via pool, reutilizados entre corrotinas.
5. **AOP** para cross-cutting (cache, log, transação) com aspects.
6. **Middleware PSR-15 + exception handler central** — validação, auth, 422/5xx consistentes.
7. **Teste com co-phpunit** e valide com o Checklist final.

---

## Regras Estritas de Execução

- **Processo persistente**: NÃO guarde estado de request em propriedade de singleton/static — vaza entre requests (use `Hyperf\Context\Context`).
- **Nunca bloqueie a corrotina** — só funções coroutine-aware (DB/Redis/HTTP do Hyperf, `Coroutine::sleep`; não `sleep()`/curl bloqueante/`PDO` puro fora do pool).
- **DI por construtor / `#[Inject]`**; rotas e middleware por anotação.
- **Pools de conexão** para DB/Redis (não abra conexão por request).
- **Valide input**; queries via model/builder parametrizado (anti-SQLi).
- **`declare(strict_types=1)`** e PHP moderno (ver `php-backend`).
- CPU pesado fora do worker de request (task worker/processo separado).
- NUNCA execute ações destrutivas sem confirmação explícita do usuário humano.

---

## Exemplos Práticos (Few-Shot)

### "cria o controller de usuários"

**Erro típico** — instanciar a dependência na mão dentro do método: `new UserService(new UserRepository())`, sem container, sem troca possível em teste.

**Ação:** injeção por construtor com `#[Controller]`/`#[GetMapping]` (§2, §4) — o Hyperf resolve via container; nunca `new` dentro do handler.

### "busca o usuário e os pedidos dele numa rota só"

**Erro típico** — duas chamadas sequenciais que esperam uma a outra terminar, latências somadas.

**Ação:** `Hyperf\\Coroutine\\parallel` (§3) — corrotinas rodam concorrentemente enquanto uma espera I/O. Mas cuidado com o que bloqueia: `sleep`, `curl_exec` e `file_get_contents` puros travam o worker inteiro, não só a corrotina (§3).

### "guardei o usuário autenticado numa propriedade `static`, funciona?"

**Ação:** não, e é um bug sutil — o processo Hyperf é long-running e concorrente (diferente de PHP-FPM), então `static` vaza entre requests de usuários diferentes. Use `Context::set`/`Context::get` (§1): estado isolado por corrotina/request.

---

## Referência Técnica

### 1. Setup e arquitetura (long-running)

Requisitos: PHP 8.1+ com extensão **Swoole** (ou Swow) + Composer.

```bash
composer create-project hyperf/hyperf-skeleton app
cd app && php bin/hyperf.php start      # sobe o servidor (fica em memória)
```

```txt
PHP-FPM (Laravel/WordPress): request → carrega tudo → executa → MORRE → recarrega
  Estado não persiste; bloquear é "ok" (cada request é isolada).
Hyperf (Swoole): servidor sobe UMA vez; cada request é uma CORROTINA
  Estado em memória PERSISTE → cuidado com singletons/static.
  Bloquear a corrotina trava outras → só I/O coroutine-aware.
```

Config via `config()`/`env()` no boot — não dependa de estado mutável global.

| Aspecto | Hyperf |
|---|---|
| Bootstrap | único no `start` (container, config, pools) |
| Request | corrotina dentro de um worker; várias concorrem |
| Dev/Prod | hot reload via watcher em dev; restart de workers no deploy |
| Servidores | HTTP, WebSocket, gRPC, TCP no mesmo processo (config `server`) |
| Estrutura | `app/{Controller,Service,Model,Middleware,Aspect,Exception/Handler,Process}`, `config/autoload/*`, `bin/hyperf.php` |

**Quando usar:** ✅ alta concorrência/throughput, microsserviços, WebSocket, RPC, long-running · ❌ site/CRUD simples → Laravel (FPM) é mais simples.

### 2. Rotas e controllers

```php
use Hyperf\HttpServer\Annotation\{Controller, GetMapping, PostMapping, PatchMapping, DeleteMapping, Middleware};
use Hyperf\HttpServer\Contract\{RequestInterface, ResponseInterface};

#[Controller(prefix: '/v1/orders')]
final class OrderController {
    public function __construct(private readonly OrderService $service) {}

    #[GetMapping('')]
    public function index(): array { return $this->service->list(); }

    #[Middleware(AuthMiddleware::class)]
    #[GetMapping('/{id}')]
    public function show(string $id): array { return $this->service->byId($id)->toArray(); }

    #[PostMapping('')]
    public function store(RequestInterface $request, ResponseInterface $response) {
        $order = $this->service->create($request->all());
        return $response->json(['data' => $order])->withStatus(201);
    }
}

// Request/Response: $request->input('email') · ->all() · ->route('id') · ->header('Authorization')
//                   $response->json($data)->withStatus(201)
// Alternativa em config/routes.php:
Router::addGroup('/v1', fn () => Router::post('/orders', [OrderController::class, 'store']));
```

Request/Response são **proxies coroutine-safe** (resolvem o request da corrotina atual) — injete via DI, nunca use `$_GET`/`$_POST`. Middleware por anotação ou global em `config/autoload/middlewares.php`. Controller fino: valida/orquestra; regra no **Service**; envelope `data` e status corretos (201/204/404), ver `api-rest`.

### 3. Corrotinas

Cada request roda numa corrotina; I/O coroutine-aware **cede** enquanto espera → outra corrotina roda. **Bloquear** uma corrotina trava **todas** do worker.

```php
// ❌ bloqueiam o worker inteiro
sleep(1);                        // use Coroutine::sleep(1)
curl_exec($ch);                  // use o HTTP client do Hyperf (Guzzle + handler coroutine)
$pdo->query(...);                // use o DB do Hyperf (pool/coroutine)
file_get_contents('http://...'); // I/O de rede bloqueante

// ✅ coroutine-aware
use Hyperf\Coroutine\Coroutine;
Coroutine::sleep(1);
$client->get('https://api...');         // Guzzle coroutine
Db::select('SELECT ...', [$id]);        // DB do Hyperf (pool)

use function Hyperf\Coroutine\{go, parallel, wait};
go(fn () => doSomething());                  // fire-and-forget
[$a, $b] = parallel([fn () => $api->getUser($id), fn () => $api->getOrders($id)]);
```

| Ferramenta | Uso |
|---|---|
| `parallel([...])` | agregar I/O independente e coletar resultados |
| `Channel` | produtor/consumidor: `$ch->push()` / `$ch->pop()` (cede até ter valor) |
| `Concurrent(10)` | limitar corrotinas simultâneas (`$c->create(fn () => ...)`) — evita esgotar pool |
| `Context` | estado por corrotina/request (`Context::set/get`) |

CPU pesado também "bloqueia" → task worker/processo separado. Cuidado com libs de terceiros bloqueantes.

### 4. DI e AOP

```php
final class OrderService {                                     // construtor (preferido)
    public function __construct(private readonly OrderRepository $repo) {}
}
final class OrderController { #[Inject] private OrderService $service; }   // por propriedade

// config/autoload/dependencies.php
return [
    OrderRepository::class => DbOrderRepository::class,   // interface → implementação
    Redis::class           => RedisFactory::class,        // factory p/ construção complexa
];
```

Singletons por padrão — persistem entre requests, **nunca** guarde estado de request neles.

```php
#[Aspect]
final class LogAspect extends AbstractAspect {
    public array $classes = [OrderService::class . '::create'];   // alvo ($classes/$annotations)
    public function process(ProceedingJoinPoint $point) {
        $start = microtime(true);
        $result = $point->process();              // executa o método original
        logger()->info('create', ['ms' => (microtime(true) - $start) * 1000]);
        return $result;
    }
}

#[Listener]                                        // eventos desacoplam efeitos colaterais
final class OrderPaidListener implements ListenerInterface {
    public function listen(): array { return [OrderPaid::class]; }
    public function process(object $event): void { /* ... */ }
}
```

Anotações prontas (via AOP): `#[Cacheable(prefix: 'user', ttl: 60)]` · `#[Transactional]` · `#[RateLimit(create: 10, capacity: 10)]`.

### 5. Banco de dados

**Pool** é essencial: com muitas corrotinas, conexão por request esgota o banco. Dimensione em `config/autoload/databases.php`.

```php
use Hyperf\DbConnection\Db;
use Hyperf\Database\Model\Model;

$users = Db::select('SELECT * FROM users WHERE active = ?', [true]);   // parametrizado
$user  = Db::table('users')->where('id', $id)->first();
Db::table('users')->insert(['id' => $id, 'email' => $email]);

final class User extends Model {
    protected ?string $table = 'users';
    protected array $fillable = ['email', 'name'];
    protected array $casts = ['active' => 'boolean', 'created_at' => 'datetime'];
    public function orders() { return $this->hasMany(Order::class); }
}

User::query()->find($id);
User::create(['email' => $email, 'name' => $name]);   // respeita $fillable
Order::query()->with('customer', 'items')->get();     // eager loading (anti N+1)

Db::transaction(function () { Order::create([...]); OrderItem::query()->insert($items); });
```

```bash
php bin/hyperf.php gen:migration create_users_table && php bin/hyperf.php migrate
```

API similar ao Eloquent (relacionamentos, scopes, casts); ou `#[Transactional]` no método. Redis: `$container->get(Redis::class)` — também via pool, coroutine-aware. Saída via DTO/array, não model cru com campos sensíveis. Modelagem/SQL: `db-*`.

### 6. Middleware, validação e erros

```php
final class AuthMiddleware implements MiddlewareInterface {     // PSR-15
    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface {
        $token = $request->getHeaderLine('Authorization');
        if (! $this->valid($token)) return (new Response())->withStatus(401)->withBody(...);  // encerra
        return $handler->handle($request);   // passa adiante
    }
}
```

Use para auth, CORS, rate limit, trace id, logging. Ordem definida no config.

```php
$validator = $this->validationFactory->make($request->all(), [
    'email' => 'required|email',
    'age'   => 'required|integer|min:18',
]);
if ($validator->fails()) { throw new ValidationException($validator); }   // vira 422
$data = $validator->validated();

// config/autoload/exceptions.php registra handlers (em cadeia)
final class AppExceptionHandler extends ExceptionHandler {
    public function handle(Throwable $e, ResponseInterface $response): ResponseInterface {
        $this->stopPropagation();
        $status = $e instanceof AppException ? $e->status : 500;
        if ($status >= 500) logger()->error($e->getMessage(), ['exception' => $e]);
        return $response->withStatus($status)
            ->withHeader('Content-Type', 'application/problem+json')
            ->withBody(new SwooleStream(json_encode([
                'title' => $status >= 500 ? 'Erro interno' : $e->getMessage(), 'status' => $status,
            ])));
    }
    public function isValid(Throwable $e): bool { return true; }
}
```

Validação: `hyperf/validation` (estilo Laravel) ou `FormRequest` com `rules()`/`authorize()` — nunca use `$request->all()` cru. Mapeie exceções de domínio → status; **não vaze stack** ao cliente (logue com trace id). Formato Problem Details — ver `api-rest`. Rate limit via `#[RateLimit]` (AOP) ou middleware.

### 7. Testes

```bash
composer test    # co-phpunit --prepend test/bootstrap.php (roda em contexto de corrotina)
```

`co-phpunit` é necessário para DB/Redis coroutine-aware funcionarem no teste.
```php
final class OrderServiceTest extends TestCase {
    public function test_byId_lanca_not_found(): void {
        $repo = Mockery::mock(OrderRepository::class);
        $repo->shouldReceive('findById')->andReturn(null);
        $service = new OrderService($repo);          // DI torna o mock trivial
        $this->expectException(NotFoundException::class);
        $service->byId('x');
    }
    protected function tearDown(): void { Mockery::close(); }
}

// HTTP (testing helper/trait do Hyperf)
$response = $this->get('/v1/health');
$this->assertSame(200, $response->getStatusCode());
$response = $this->post('/v1/users', ['email' => 'x']);   // body inválido
$this->assertSame(422, $response->getStatusCode());
```

Banco de teste (ou SQLite) com migrations; transação + rollback por teste. Mocke I/O externo (HTTP/relógio); banco real só em integração. Cubra status, validação (422), autorização (401/403), erros e regra de negócio. Atenção a vazamento de estado entre testes (Context, singletons).

**Ferramentas:** Swoole/Swow · composer · `hyperf/*` components · co-phpunit · PHPStan · php-cs-fixer (CI)

---

## Checklist

- [ ] Swoole/Swow instalado; `declare(strict_types=1)`; escolha justificada vs Laravel/FPM
- [ ] Sem estado de request em singleton/static → `Context`
- [ ] Nenhuma chamada bloqueante (sem `sleep()`/curl/PDO puro); só clientes do Hyperf
- [ ] `parallel`/Channel para concorrência; `Concurrent` para limitar; CPU pesado fora do worker
- [ ] DI por construtor/`#[Inject]`; interfaces bindadas em `dependencies.php`; sem `new` manual
- [ ] AOP/anotações (`#[Cacheable]`/`#[Transactional]`) para cross-cutting; eventos/listeners
- [ ] Rotas/middleware por anotação com prefixo de versão; controllers finos; Request/Response injetados
- [ ] Pool dimensionado; queries parametrizadas; `$fillable`; sem N+1 (`with()`); paginação; transações
- [ ] Migrations versionadas; saída sem campos sensíveis (DTO/array, não model cru)
- [ ] Input validado; 422 consistente; exception handler central sem stack ao cliente
- [ ] Auth/middleware; 401 vs 403; anti-IDOR; rate limit; segredos em env; trace id nos logs
- [ ] co-phpunit: unit com mocks + HTTP (status/validação/auth); banco de teste isolado
- [ ] PHPStan + cs-fixer no CI; testes determinísticos

---

## Externas

- [Hyperf Docs](https://hyperf.wiki/) · [Swoole](https://www.swoole.com/)
- Skills: `php-backend` · `api-rest` · `db-*` · `php-laravel`
