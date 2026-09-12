---
name: define
description: >
  Analisa, corrige e configura a separação entre os arquivos raiz README.md (público) e CLAUDE.md (sdd agent) de um projeto. Gatilhos: "define o projeto", "analisa o README", "atualiza o CLAUDE.md", "configura os arquivos do projeto", "o README está certo?", "o CLAUDE.md está completo?", ou qualquer pedido para revisar, criar ou ajustar README.md/CLAUDE.md.
allowed-tools: Read Edit Write Glob Bash
license: Unlicense
metadata:
  author: thiagoeti
  version: "1.0.0"
---

# Define

Regra de separação entre os dois arquivos raiz de qualquer projeto.

---

## README.md — Arquivo público

**Audiência:** Qualquer pessoa que acesse o repositório (usuários, colaboradores e público em geral).

**Deve conter:**
- O que é o projeto (descrição objetiva).
- Como instalar e usar (instruções focadas no usuário final).
- Estrutura de arquivos **visível ao usuário** (apenas pastas e arquivos públicos).
- Diretrizes de como contribuir (se aplicável).
- Licença de uso.

**Nunca deve conter:**
- Detalhes de arquitetura ou desenvolvimento.
- Referências ao diretório `.claude` ou a qualquer Documentação de Design de Software (SDD).
- Scripts e ferramentas de workflow interno (ex.: `git.sh`).
- Backlog, histórico de tarefas ou decisões internas de desenvolvimento.

---

## CLAUDE.md — Arquivo para agentes de IA / SDD

**Audiência:** Claude Code, Codex e outros agentes de IA que trabalham no projeto.

**Deve conter:**
- Todas informações de desenvolvimento do projeto.
- Estrutura completa SDD `.claude/`
- Todos arquivos de especificação do projeto dentro de `.specs/`

**Nunca deve conter:**
- Instruções de uso voltadas ao usuário final
- Descrições de produto ou qualquer coisa voltada ao usuário final

**Formatação Exigida:**

As tabelas têm o objetivo de fornecer um guia claro e rápido para orientar as ações do agente. Elas devem ser apresentadas na seguinte ordem de importância:

1. **Tabela de Especificações (`.specs/`)**: Listar todos os arquivos de especificação acompanhados de um breve resumo, ordenados por relevância.
2. **Tabela de Arquivos Internos (`.claude/`)**: Listar todos os arquivos de configuração do agente com uma breve descrição, ordenados por prioridade.

**Execução:**

1. Sem `CLAUDE.md` na raiz: rode `/init` para gerar a base. Com `CLAUDE.md`: pule (o `/init` sobrescreve).
2. Aplique as regras acima sobre o resultado.

---

## Regra resumida

| Pergunta | README.md | CLAUDE.md |
|----------|-----------|-----------|
| "Como um usuário externo usa isso?" | ✅ | ❌ |
| "Como instalar/rodar o projeto?" | ✅ | ❌ |
| "Qual é a licença?" | ✅ | ❌ |
| "Como um dev/agente trabalha nisso?" | ❌ | ✅ |
| "Qual a arquitetura e as decisões de design?" | ❌ | ✅ |
| "Onde ficam as specs (`.specs/`)?" | ❌ | ✅ |
| "Quais skills internas o agente tem?" | ❌ | ✅ |
| "Qual é o workflow de deploy?" | ❌ | ✅ |
