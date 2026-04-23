# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# fpbot

## Projeto
Slack bot interno da Firepot que responde perguntas dos colaboradores com base no conteúdo da wiki (WikiJS).
Usuário menciona @fpbot no Slack → busca no conteúdo da wiki → Claude monta resposta → bot responde na thread com a fonte.

Ver `docs/product/prd-wiki-bot.md` para o PRD completo.

## Tech Stack
- Backend: Python 3.11 + Slack Bolt (Socket Mode)
- Wiki source: WikiJS (GraphQL API)
- Database: Supabase (PostgreSQL + pgvector)
- LLM: Claude API (claude-sonnet-4-6) via anthropic SDK
- Package manager: pip + venv

## Arquitetura

### Fluxo principal
```
Slack @fpbot <pergunta>
    → src/bot/handlers.py       # recebe evento, faz ACK imediato
    → src/db/pages.py           # busca FTS no Supabase (RPC search_wiki_pages)
    → src/bot/responder.py      # monta contexto + chama Claude
    → resposta na thread com link para página da wiki
```

### Sync job (rodar periodicamente ou on-demand)
```
scripts/sync_wiki.py
    → src/wiki/client.py        # puxa páginas via GraphQL (lista + conteúdo individual)
    → src/wiki/sync.py          # upsert em batches de 100
    → src/db/pages.py           # on_conflict="id"
```

### Detalhes não-óbvios da implementação

**Timeout do Slack (3s):** `handlers.py` responde com ACK imediato ("🔍 Buscando na wiki...") e só depois faz a busca + Claude. Nunca mover a lógica pesada para antes do ACK.

**FTS em português:** O schema usa `to_tsvector('portuguese', ...)` e `websearch_to_tsquery('portuguese', ...)`. Queries em outros idiomas podem retornar menos resultados.

**Truncamento de conteúdo:** O schema SQL limita o conteúdo indexado a 3000 chars (`left(content, 3000)`). Páginas grandes da wiki são truncadas antes de chegar ao Claude.

**Clientes singleton:** `src/db/client.py` e o cliente Anthropic em `src/bot/responder.py` são lazy-initialized na primeira chamada — não instanciar fora das funções.

**`setup_db.py` não executa SQL:** Imprime as instruções na tela. O schema precisa ser colado manualmente no Supabase SQL Editor ou executado via `psql`.

## Comandos

```bash
# Dev
python -m src.bot.app                  # bot em Socket Mode
python scripts/sync_wiki.py            # sincroniza wiki → Supabase
python scripts/sync_wiki.py --dry-run  # lista páginas sem sincronizar
python scripts/setup_db.py             # imprime SQL para executar no Supabase

# Qualidade
ruff check src/                        # lint
black src/                             # format
pytest                                 # todos os testes
pytest tests/test_handlers.py -k test_clean_question_removes_mention  # teste único
```

### Slash commands
- `/implement <PRD>` → implementar feature a partir do PRD
- `/ralph <PRD>` → modo persistência
- `/debug <erro|arquivo>` → debugging sistemático
- `/refactor <arquivo|módulo>` → refatoração segura
- `/clean [arquivo|dir]` → remover slop
- `/debt [dir]` → scan de tech debt
- `/deploy` → checklist de deploy
- `/spec-review <path>` → auditoria (security + quality + performance)

## Convenções
- Style: black + ruff (linha máx 100)
- Tipos: type hints obrigatórios em funções públicas
- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`)
- Branches: `feature/`, `fix/`, `docs/`
- Env vars: sempre via `os.environ`, nunca hardcoded; toda var nova vai em `.env.example`

## Workflow
- Nunca commitar `.env` ou qualquer secret
- Toda mudança na integração WikiJS atualiza `docs/architecture/`
- Bug em produção → post-mortem em `docs/runbooks/post-mortems/`
- Novo env var → `.env.example` com comentário explicativo

## Variáveis de ambiente
```
SLACK_BOT_TOKEN         # xoxb-... (bot OAuth token)
SLACK_APP_TOKEN         # xapp-... (Socket Mode)
SLACK_SIGNING_SECRET    # webhook signing secret
ANTHROPIC_API_KEY       # Claude API
SUPABASE_URL            # https://xxx.supabase.co
SUPABASE_SERVICE_KEY    # service_role key (bypass RLS)
WIKIJS_URL              # https://wiki.suaempresa.com
WIKIJS_API_TOKEN        # token gerado no WikiJS admin → API Access
```

## Spec modules ativos
- [x] `security/` → validação de inputs, secrets
- [x] `observability/` → logging estruturado (structlog)
- [x] `api/` → WikiJS GraphQL client
- [x] `ai-ml/` → prompts, RAG, guardrails

## Gotchas
- WikiJS GraphQL: header `Authorization: Bearer <token>` obrigatório
- Slack Socket Mode: precisa de `SLACK_APP_TOKEN` (xapp-) além do bot token (xoxb-)
- Claude API: `max_tokens=600` hardcoded em `responder.py` — ajustar se respostas forem cortadas
- pgvector: extensão `vector` precisa estar habilitada no Supabase antes de rodar o schema
- Supabase `service_role` key tem bypass de RLS — nunca expor fora do backend
- Slack: bot precisa de escopos `app_mentions:read`, `chat:write`, `channels:history`
