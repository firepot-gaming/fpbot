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
- `/src/bot/` → Slack Bolt app (handlers, responder)
- `/src/wiki/` → WikiJS GraphQL client + sync job
- `/src/db/` → Supabase client, queries, schema SQL
- `/scripts/` → jobs de manutenção (sync, bootstrap DB)
- `/docs/` → PRDs, ADRs, specs, runbooks

### Fluxo principal
```
Slack @fpbot <pergunta>
    → src/bot/handlers.py       # recebe evento
    → src/db/search.py          # busca FTS no Supabase
    → src/bot/responder.py      # monta prompt + chama Claude
    → resposta na thread com link para página da wiki
```

### Sync job (rodar periodicamente ou on-demand)
```
scripts/sync_wiki.py
    → src/wiki/client.py        # puxa páginas via GraphQL
    → src/wiki/sync.py          # diff + upsert
    → src/db/pages.py           # salva no Supabase
```

## Convenções
- Style: black + ruff (linha máx 100)
- Tipos: type hints obrigatórios em funções públicas
- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`)
- Branches: `feature/`, `fix/`, `docs/`
- Env vars: sempre via `os.environ`, nunca hardcoded; toda var nova vai em `.env.example`

## Comandos
- `python -m src.bot.app` → bot em modo socket (dev)
- `python scripts/sync_wiki.py` → sincroniza wiki → Supabase
- `python scripts/sync_wiki.py --dry-run` → lista páginas sem sincronizar
- `python scripts/setup_db.py` → cria tabelas e extensão pgvector no Supabase
- `ruff check src/` → lint
- `black src/` → format
- `pytest` → testes

### Slash commands
- `/implement <PRD>` → implementar feature a partir do PRD
- `/ralph <PRD>` → modo persistência
- `/debug <erro|arquivo>` → debugging sistemático
- `/refactor <arquivo|módulo>` → refatoração segura
- `/clean [arquivo|dir]` → remover slop
- `/debt [dir]` → scan de tech debt
- `/deploy` → checklist de deploy
- `/spec-review <path>` → auditoria (security + quality + performance)

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
- Claude API: definir `max_tokens` explícito — respostas sem limite podem exceder timeout do Slack (3s)
- pgvector: extensão `vector` precisa estar habilitada no Supabase antes do `setup_db.py`
- Supabase `service_role` key tem bypass de RLS — nunca expor fora do backend
- Slack: bot precisa de escopos `app_mentions:read`, `chat:write`, `channels:history`
