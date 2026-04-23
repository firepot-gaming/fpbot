# PRD — fpbot: Wiki Search Bot

## Status
`draft` | v0.1 | 2026-04-23

## Problema
Colaboradores da Firepot têm dificuldade em encontrar informações na wiki. Perguntas simples ("Como tiro férias?", "Qual o processo de reembolso?") acabam indo para o Slack e consumindo tempo de quem sabe a resposta.

## Solução
Bot no Slack que:
1. Recebe uma pergunta via menção (`@fpbot como faço para tirar férias?`)
2. Busca nas páginas da wiki sincronizadas no Supabase
3. Passa o contexto relevante para Claude
4. Responde na thread com a resposta em linguagem natural + link para a página original

## Escopo (v1)

### Inclui
- Menção direta ao bot (`@fpbot <pergunta>`)
- Busca full-text nas páginas da wiki (PostgreSQL FTS)
- Resposta gerada por Claude com citação da fonte
- Sincronização manual da wiki via script (`sync_wiki.py`)
- Comando `/fpbot-sync` no Slack para forçar sync (admin only)

### Não inclui (v1)
- Agente de revisão de conteúdo (v2)
- Sync automático por webhook
- Embeddings vetoriais (pgvector) — começa com FTS, migra se precisar
- Histórico de conversa multi-turno
- Feedback de utilidade (👍/👎)

## Fluxo de uso

```
Usuário no Slack:
  @fpbot como faço para tirar férias?

fpbot (na thread):
  Segundo a página "Política de Férias" na wiki:

  Os colaboradores CLT têm direito a 30 dias de férias após 12 meses de trabalho.
  Para solicitar, acesse o sistema de RH em até 30 dias antes da data desejada...

  📄 Fonte: https://wiki.firepot.com.br/rh/politica-ferias
```

## Arquitetura técnica

### Stack
- **Bot**: Python 3.11 + Slack Bolt (Socket Mode)
- **LLM**: Claude claude-sonnet-4-6 via Anthropic SDK
- **DB**: Supabase PostgreSQL com busca FTS (`tsvector`)
- **Wiki source**: WikiJS GraphQL API

### Schema Supabase

```sql
-- Tabela principal de páginas da wiki
create table wiki_pages (
  id          text primary key,          -- WikiJS page ID
  path        text not null,             -- ex: /rh/politica-ferias
  title       text not null,
  content     text not null,             -- Markdown da página
  updated_at  timestamptz not null,      -- última atualização no WikiJS
  synced_at   timestamptz default now(), -- última sync no Supabase
  search_vec  tsvector                   -- gerado automaticamente via trigger
);

-- Índice FTS
create index wiki_pages_search_idx on wiki_pages using gin(search_vec);
```

### Prompt do sistema (Claude)
```
Você é o fpbot, assistente interno da Firepot.
Responda a pergunta do colaborador com base EXCLUSIVAMENTE no conteúdo da wiki fornecido.
Se a informação não estiver no conteúdo, diga claramente que não encontrou na wiki.
Seja direto e objetivo. Máximo 300 palavras.
Sempre termine com: "📄 Fonte: <url da página>"
```

## Critérios de aceitação

- [ ] Bot responde a menções em canais onde está presente
- [ ] Resposta aparece na thread da mensagem original
- [ ] Fonte linkada é válida e leva à página correta
- [ ] Se wiki não tiver resposta, bot informa claramente
- [ ] Sync importa todas as páginas publicadas do WikiJS
- [ ] Sync é idempotente (re-rodar não duplica dados)
- [ ] Variáveis de ambiente documentadas em `.env.example`

## Dependências externas
- Slack workspace com permissão para instalar apps
- WikiJS com API token de leitura
- Projeto Supabase com extensão `vector` habilitada
- Anthropic API key

## Riscos
| Risco | Probabilidade | Mitigação |
|-------|--------------|-----------|
| Wiki com conteúdo desatualizado | Alta | Agente de revisão (v2) |
| Resposta do Claude inventar informação | Média | Prompt com instrução de só usar contexto fornecido |
| Timeout Slack (3s) | Baixa | Resposta assíncrona via `say()` após ACK imediato |
| Rate limit WikiJS API | Baixa | Sync incremental por `updated_at` |
