---
name: php-backend
description: Backend PHP 8.3+ moderno — Composer/PSR, tipos estritos, enums/readonly, estrutura em camadas, erros/exceptions, PDO (queries parametrizadas), validação e testes (PHPUnit/Pest). Use ao estruturar app PHP, configurar Composer/autoload, tipar código, acessar banco ou modernizar PHP legado. Não cobre Laravel (php-laravel), Hyperf e Swoole (php-hyperf) nem desenho de recurso REST (api-rest).
version: 3.2.0
license: Unlicense
tags:
  - php
  - backend
  - composer
  - pdo
  - psr
---

# Backend com PHP (moderno, 8.3+)

PHP tipado e seguro: `declare(strict_types=1)`, PSR + Composer, camadas e acesso a dados via PDO parametrizado.

> **Não cobre:** rota, Eloquent, fila e recursos do framework → `php-laravel` · corrotina e Swoole → `php-hyperf` · SQL e tuning → `db-*` · desenho do contrato → `api-rest` · camadas formais → `arch-clean`, `arch-hexagonal` · prática de código seguro → `sec-secure-coding`

---

## Contexto e Objetivo

- PHP moderno (8.3+): tipos estritos, enums, `readonly`, `match`, attributes.
- Autoload PSR-4 via Composer; camadas controller → service → repository.
- Acesso a dados seguro (PDO parametrizado), validação na borda e escape na saída.

**Casos de uso:** estruturar app · Composer/autoload · tipar e modernizar legado · acesso a dados (PDO) · validação · testes

---

## Fluxo Cognitivo (Workflow)

1. **Base moderna** — `declare(strict_types=1)`, PHP 8.3+, Composer com autoload PSR-4.
2. **Tipos em tudo** — parâmetros, retornos, propriedades; enums para estados; `readonly` para imutabilidade.
3. **Camadas** — controller → service (regra) → repository (PDO/ORM); front controller em `public/`.
4. **Segurança nos dados** — PDO **sempre** com prepared statements; valide input, escape a saída.
5. **Erros via exceptions** tipadas + handler global; não suprima com `@`.
6. **Qualidade** — PHPStan/Psalm em nível alto, PSR-12 e testes (PHPUnit/Pest) no CI.
7. Valide com o **Checklist** no fim deste arquivo.

---

## Regras Estritas de Execução

- **`declare(strict_types=1)`** no topo de todo arquivo PHP.
- **Tipos sempre** — params, retornos (`: void`/`: T`), propriedades tipadas; evite `mixed` sem necessidade.
- **PDO com prepared statements** — **nunca** interpole input em SQL (SQLi). `PDO::ERRMODE_EXCEPTION`.
- **Valide input** e **escape na saída** (`htmlspecialchars` em HTML) — ver `web-security`.
- **Exceptions** para erros; nunca `@` para suprimir; nunca exponha erro detalhado ao usuário em produção.
- **Composer + PSR-4**; sem `require` manual de arquivos de classe.
- **Senhas** com `password_hash` (bcrypt/argon2); segredos em env (não no código/repo).
- NUNCA execute ações destrutivas sem confirmação explícita do usuário humano.

---

## Exemplos Práticos (Few-Shot)

### "busca o usuário pelo id"

**Erro típico** — `$pdo->query("SELECT * FROM users WHERE id = {$id}")` interpolado é SQL injection.

**Ação:** `prepare` + `execute` com parâmetros nomeados, sempre (§4) — nunca concatene valor de usuário na query.

### "modela o status do pedido"

**Erro típico** — `string $status` mutável aceita `'paid'`, `'PAID'`, `'pago'` ou qualquer typo, e nada impede alterar o pedido depois de criado.

**Ação:** `enum` backed para o conjunto fechado de estados + `readonly` nas propriedades que não devem mudar após a construção (§2) — o typo vira erro de tipo, não bug em produção.

### "o service devolve `false` quando não acha o usuário"

**Erro típico** — `false`, `null` ou array vazio: cada chamador tem que adivinhar qual.

**Ação:** exception de domínio tipada (§5) — `$repo->findById($id) ?? throw new NotFoundException(...)`. O tipo de retorno vira `User` sem união com falha silenciosa.

---

## Referência Técnica

### 1. Composer, PSR e ferramentas

```jsonc
// composer.json
{
  "require": { "php": ">=8.3" },
  "require-dev": { "phpstan/phpstan": "^2", "pestphp/pest": "^3", "friendsofphp/php-cs-fixer": "^3" },
  "autoload": { "psr-4": { "App\\": "src/" } },
  "autoload-dev": { "psr-4": { "Tests\\": "tests/" } },
  "scripts": { "test": "pest", "analyse": "phpstan analyse src --level=max", "fix": "php-cs-fixer fix" }
}
```

```bash
composer install                          # instala do composer.lock (reprodutível) — commite o lock
composer require vlucas/phpdotenv
composer dump-autoload                    # regenera autoload
composer analyse                          # PHPStan level max (ou Psalm)
vendor/bin/php-cs-fixer fix               # PSR-12 (ou PHP_CodeSniffer: phpcs/phpcbf)
# CI: composer install --no-interaction --prefer-dist && composer analyse
#     && vendor/bin/php-cs-fixer fix --dry-run --diff && composer test
```

`App\Users\UserService` → `src/Users/UserService.php`. Sem `require`/`include` manual de classes.

**PSR essenciais:** PSR-4 autoload por namespace · PSR-12 estilo de código · PSR-3 logger · PSR-7 HTTP messages (Request/Response) · PSR-11 container de DI · PSR-15 middleware HTTP · PSR-18 HTTP client.

Programar contra interfaces PSR deixa o código interoperável entre libs/frameworks. PHP é dinâmico — PHPStan/Psalm pegam erros de tipo/null antes do runtime; mire o nível mais alto viável e suba gradualmente em legado.

```php
(Dotenv\Dotenv::createImmutable(__DIR__))->load();   // vlucas/phpdotenv
$db = $_ENV['DATABASE_URL'];      // valide presença; nunca commite .env (mantenha .env.example)
```

### 2. PHP moderno (8.3+)

```php
<?php
declare(strict_types=1);   // 1ª linha de TODO arquivo — sem coerção silenciosa ("5" → 5)

function soma(int $a, int $b): int { return $a + $b; }
class User { public int $age = 0; public ?string $name = null; }   // propriedades tipadas
final class Money {                                    // constructor promotion + readonly
    public function __construct(
        public readonly int $amountCents,
        public readonly string $currency = 'BRL',
    ) {}
}                                                      // 8.2+: `readonly class`
enum Role: string {
    case Admin = 'admin';
    case User = 'user';
    public function label(): string => match($this) {
        Role::Admin => 'Administrador',
        Role::User  => 'Usuário',
    };
}
$r = Role::from('admin');   // ::from / ::tryFrom (backed enums) · Role::cases()
$status = match($code) { 200, 201 => 'success', 404 => 'not found', default => 'error' };  // estrito (===)
$city = $user?->address?->city;        // nullsafe
$name = $input['name'] ?? 'anônimo';   // null coalescing · $config['x'] ??= 'default';
$fn = strlen(...);                                     // first-class callable
$users = array_map(User::fromArray(...), $rows);
criar(nome: 'Ana', ativo: true);                       // named arguments
#[Route('/users', methods: ['GET'])]                   // attributes nativos (framework/ORM/validação)
public function index(): Response { ... }
function find(int|string $id): User|null { ... }       // union types
function process(): never { throw new \RuntimeException(); }
```

```txt
Evite (legado):
❌ sem declare(strict_types=1)   ❌ variáveis globais / $GLOBALS   ❌ @ para suprimir erro
❌ mysql_*/mysqli concatenando SQL (use PDO prepared)   ❌ extract()/eval()
❌ require manual de classes (use autoload)   ❌ array associativo onde cabe enum/DTO/objeto
```

### 3. Estrutura do projeto

```txt
Controller → borda HTTP (lê request, valida, chama service, devolve response)
Service    → regra de negócio          Repository → acesso a dados (PDO/ORM)
Domain     → entidades, value objects, enums
projeto/
├── composer.json / composer.lock
├── src/                       # App\ (PSR-4, por feature)
│   ├── Users/{UserController,UserService,UserRepository,User}.php
│   └── Shared/{Exceptions,Http}/
├── public/index.php           # front controller — ÚNICO ponto exposto (webroot)
├── tests/                     # Tests\
└── .env / .env.example
```

```php
<?php                                    // public/index.php
declare(strict_types=1);
require __DIR__ . '/../vendor/autoload.php';
$container = require __DIR__ . '/../bootstrap/container.php';
$router = require __DIR__ . '/../bootstrap/routes.php';
$router->dispatch($_SERVER['REQUEST_METHOD'], $_SERVER['REQUEST_URI']);

// DI por construtor; monte no bootstrap (ou container PSR-11, ex.: PHP-DI)
final class UserController { public function __construct(private readonly UserService $service) {} }
$service = new UserService(new PdoUserRepository($pdo));

interface UserRepository {                 // dependa de INTERFACE onde a troca importa
    public function findById(string $id): ?User;
    public function save(User $user): void;
}
// config: fail fast no bootstrap; não leia $_ENV/getenv espalhado
$db = $_ENV['DATABASE_URL'] ?? throw new \RuntimeException('DATABASE_URL ausente');
```

**Sem framework full:** componentes PSR — PSR-7 (nyholm/psr7), PSR-15 (middlewares), router (FastRoute), container PSR-11 (PHP-DI). SRP por classe; imports unidirecionais (controller→service→repo); não exponha a linha do banco crua (use DTO). Padrões formais: `arch-*`.

### 4. Banco de dados (PDO)

```php
$pdo = new PDO(
    'mysql:host=localhost;dbname=app;charset=utf8mb4',      // ou pgsql:host=...
    $user, $pass,
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,        // erros viram exceptions
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,   // arrays associativos
        PDO::ATTR_EMULATE_PREPARES => false,                // prepares reais (mais seguro)
    ],
);
// ❌ SQL Injection: $pdo->query("SELECT * FROM users WHERE email = '{$email}'");
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = :email');    // nomeados
$stmt->execute(['email' => $email]);
$stmt = $pdo->prepare('INSERT INTO users (id, email) VALUES (?, ?)'); // posicionais
$stmt->execute([$id, $email]);
$user  = $stmt->fetch();               // uma linha       $users = $stmt->fetchAll();
$count = (int) $stmt->fetchColumn();   // escalar         $stmt->setFetchMode(PDO::FETCH_CLASS, User::class);

$pdo->beginTransaction();
try {
    $pdo->prepare('UPDATE accounts SET balance = balance - ? WHERE id = ?')->execute([100, $from]);
    $pdo->prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?')->execute([100, $to]);
    $pdo->commit();
} catch (\Throwable $e) { $pdo->rollBack(); throw $e; }

final class PdoUserRepository implements UserRepository {     // repositório isola o SQL
    public function __construct(private readonly PDO $pdo) {}
    public function findById(string $id): ?User {
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();
        return $row ? User::fromRow($row) : null;
    }
}
```

Identificadores (tabela/coluna) **não** podem ser parâmetros → valide contra **allowlist**. Conexão única reutilizada (não abra por query). Migrações versionadas (Doctrine Migrations/Phinx) — não altere schema na mão em prod. **Doctrine ORM** para domínios complexos; PDO direto para apps simples/performance.

### 5. Erros e logging

```php
abstract class AppException extends \RuntimeException {
    public function __construct(string $message, public readonly int $status = 500) { parent::__construct($message); }
}
final class NotFoundException extends AppException {
    public function __construct(string $msg) { parent::__construct($msg, 404); }
}
final class ValidationException extends AppException {
    public function __construct(string $msg, public readonly array $errors = []) { parent::__construct($msg, 422); }
}
public function byId(string $id): User {
    return $this->repo->findById($id) ?? throw new NotFoundException("User {$id}");
}
try { $user = $service->byId($id); }
catch (NotFoundException $e) { /* tratar especificamente */ }
catch (\Throwable $e) { $logger->error($e->getMessage(), ['exception' => $e]); throw $e; }  // não engula

set_exception_handler(function (\Throwable $e) use ($logger) {        // handler global
    $status = $e instanceof AppException ? $e->status : 500;
    $logger->error($e->getMessage(), ['exception' => $e]);
    http_response_code($status);
    header('Content-Type: application/problem+json');
    echo json_encode(['title' => $status >= 500 ? 'Erro interno' : $e->getMessage(), 'status' => $status]);
});
set_error_handler(fn (int $sev, string $msg, string $file, int $line)
    => throw new \ErrorException($msg, 0, $sev, $file, $line));       // erros viram exceptions

ini_set('display_errors', '0');   // produção: NUNCA exibir erro/trace ao usuário
error_reporting(E_ALL);           // logue tudo (PSR-3 / Monolog)
$logger->error('Falha ao cobrar', ['exception' => $e, 'order_id' => $id]);
```

Capture `\Throwable` só no nível mais alto. Nunca `catch` vazio nem `@`. `finally` libera recursos. Formato de erro no padrão da API (Problem Details — `api-rest`). Não logue senhas/tokens; inclua correlação (request id).

### 6. Validação e saída segura

```php
function validateUser(array $input): array {
    $errors = [];
    $email = filter_var($input['email'] ?? '', FILTER_VALIDATE_EMAIL);
    if ($email === false) $errors['email'] = 'E-mail inválido';
    $age = filter_var($input['age'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 18]]);
    if ($age === false) $errors['age'] = 'Idade deve ser >= 18';
    if ($errors) throw new ValidationException('Dados inválidos', $errors);   // agregue todos
    return ['email' => $email, 'age' => $age];
}
use Symfony\Component\Validator\Constraints as Assert;
final class CreateUserDto {
    public function __construct(
        #[Assert\Email] public readonly string $email,
        #[Assert\Range(min: 18)] public readonly int $age,
    ) {}
}
final class Email {                                   // Value Object: inválido nem existe
    public function __construct(public readonly string $value) {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) throw new \InvalidArgumentException('E-mail inválido');
    }
}
echo htmlspecialchars($comment, ENT_QUOTES | ENT_HTML5, 'UTF-8');   // HTML: SEMPRE escape
$href = htmlspecialchars($url, ENT_QUOTES);                          // atributo/URL
$json = json_encode($data, JSON_THROW_ON_ERROR);                     // <script> e APIs
```

Libs: **respect/validation** (fluente) · **symfony/validator** (constraints por atributo) · **webmozart/assert** (invariantes internas). Em templates (Twig/Blade) o auto-escape cuida — não desligue. Outras defesas: SQL parametrizado (§4) · CSRF em forms · upload (valide magic bytes/tamanho, renomeie, fora do webroot) · `password_hash($p, PASSWORD_ARGON2ID)` / `password_verify`.

### 7. Testes (PHPUnit / Pest)

```php
// Pest — sintaxe enxuta sobre o PHPUnit
it('lança NotFound quando usuário não existe', function () {
    $repo = Mockery::mock(UserRepository::class);
    $repo->shouldReceive('findById')->andReturn(null);
    (new UserService($repo))->byId('x');
})->throws(NotFoundException::class);
it('valida idade', fn (int $age, bool $ok) => expect(isAdult($age))->toBe($ok))
    ->with([[17, false], [18, true], [30, true]]);          // dataset

// PHPUnit clássico
final class UserServiceTest extends TestCase {
    public function test_lanca_not_found(): void {
        $repo = $this->createMock(UserRepository::class);
        $repo->method('findById')->willReturn(null);
        $this->expectException(NotFoundException::class);
        (new UserService($repo))->byId('x');
    }
}
```

```bash
composer test      # pest / phpunit
composer analyse   # phpstan
```

Mocks: `createMock`/`createStub` (PHPUnit) ou **Mockery** (`->shouldReceive(...)`); mocke **dependências externas** (repo, HTTP, relógio) via interface — DI por construtor facilita. DB: mock do repositório no unit; DB de teste (SQLite em memória/container) na integração, com migração e transação + rollback entre testes. HTTP: test client do framework, ou Request PSR-7 simulado no handler. AAA, um comportamento por teste, determinístico (controle tempo/rede/aleatório).

---

## Checklist

- [ ] `declare(strict_types=1)` em todo arquivo; PHP >= 8.3 no `require`
- [ ] Composer + autoload PSR-4; `composer.lock` commitado; PHPStan/Psalm nível alto + PSR-12 no CI
- [ ] Tipos em params/retornos/propriedades; sem `mixed` gratuito; `never`/union onde cabe
- [ ] Enums para estados; `readonly`/promotion em DTOs; `match` em vez de `switch`; nullsafe/`??`
- [ ] Sem padrões legados (`@`, globals, `extract`/`eval`, SQL concatenado, require manual)
- [ ] Camadas (controller/service/repo); regra no service; PSR-4 por feature; DI por construtor
- [ ] Front controller em `public/`, resto fora do webroot; interfaces onde a troca importa
- [ ] Config centralizada e validada (fail fast); `.env` não commitado + `.env.example`
- [ ] Exceptions tipadas (com status); handler global → Problem Details; sem `catch` vazio
- [ ] `display_errors=0` em prod; logger PSR-3 sem dados sensíveis
- [ ] PDO `ERRMODE_EXCEPTION` + `EMULATE_PREPARES=false`; prepared statements sempre
- [ ] Identificadores dinâmicos via allowlist; transações + rollback; migrações versionadas
- [ ] Input validado na borda (filter_var/lib/VO), erros agregados; saída escapada por contexto
- [ ] CSRF; upload seguro; senha com `password_hash` (argon2/bcrypt); segredos em env
- [ ] Saída via DTO (não linha crua); PHPUnit/Pest no CI com deps mockadas e DB de teste isolado

---

## Externas

- [PHP Docs](https://www.php.net/docs.php) · [PHP The Right Way](https://phptherightway.com/) · [PSR](https://www.php-fig.org/psr/) · [Composer](https://getcomposer.org/)
- Skills: `php-laravel` · `php-hyperf` · `db-*` · `api-rest` · `web-security` · `sec-secure-coding`
