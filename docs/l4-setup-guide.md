# Level 4 Setup Guide — Agent Teams

> **Requisitos:** Claude Code v2.1.79+ (março 2026) · Modelo Opus 4.6 · Plano Pro, Max, Team ou Enterprise · tmux recomendado

## O que é o Nível 4

O Nível 4 habilita agentes especializados operando como time coordenado. Um lead agent orquestra, teammates trabalham em paralelo com context windows independentes, cada um no seu Git worktree, com task list compartilhada e messaging peer-to-peer.

Os agentes em `.claude/agents/` (compliance-auditor, security-auditor, quality-guardian) deixam de ser sub-agents isolados e passam a operar como equipe coordenada com loop author-critic.

## Habilitando Agent Teams

Agent Teams é uma feature experimental (research preview) lançada com Opus 4.6 em 6 de fevereiro de 2026. Desabilitada por padrão.

### Opção 1: Via settings.json (recomendado, persiste no projeto)

Adicione ao `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Opção 2: Via variável de ambiente (por sessão)

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
claude
```

### Verificando a versão

```bash
claude --version
# Esperado: 2.1.79 ou superior
```

Se precisar atualizar:

```bash
npm update -g @anthropic-ai/claude-code
```

## Instalando tmux (recomendado)

tmux permite visualizar cada agente num painel separado. Sem tmux, Agent Teams funciona, mas a saída de todos os agentes aparece misturada numa thread só.

```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Verificar
tmux -V
```

## Como funciona na prática

### Estrutura de agentes do blueprint

```
.claude/agents/
├── compliance-auditor.md    ← Audita LGPD, regulações, ISOs
├── security-auditor.md      ← OWASP, controle de acesso, vulnerabilidades
└── quality-guardian.md      ← Cobertura de testes, code review, manutenibilidade
```

### Spawning um time

Com Agent Teams habilitado, você pode pedir ao Claude Code para montar um time:

```
Crie um agent team pra implementar o sistema de auth OAuth2.
Quero:
- 1 agente de backend implementando a lógica
- 1 agente de frontend pro fluxo de login
- 1 security-auditor revisando em paralelo
Usem o PRD em docs/product/feat-auth.md como spec.
```

O lead agent:
1. Decompõe o trabalho em tasks
2. Spawna teammates especializados
3. Cada teammate opera no seu worktree
4. Teammates se comunicam entre si (peer-to-peer, não só via lead)
5. Security auditor revisa o trabalho dos outros em tempo real

### Casos de uso recomendados

| Cenário | Por que Agent Teams | Por que NÃO Agent Teams |
|---------|--------------------|-----------------------|
| Feature com frontend + backend + testes | Parallelismo real, cada um no seu worktree | — |
| Debugging com múltiplas hipóteses | Agentes testam teorias em paralelo e debatem | — |
| Code review + security audit | Revisores especializados em paralelo | — |
| Tarefa sequencial simples | — | Overhead de coordenação não justifica |
| Edição no mesmo arquivo | — | Conflitos de merge, usar sessão única |

## Memória de longo prazo (L4)

Agent Teams se combina com o sistema de memória do blueprint:

```bash
# Indexar o projeto (docs/ + src/) na vector DB
pip install -r memory/requirements.txt
python memory/index.py

# Agente pode consultar memória semântica
python memory/query.py "como resolvemos rate limiting"

# Auto-index a cada commit (via post-commit hook)
# Já configurado em scripts/post-commit-index.sh
```

Com memória ativa, os agentes conseguem:
- Consultar ADRs e PRDs anteriores antes de tomar decisões
- Aprender com post-mortems de iterações passadas
- Manter contexto entre sessões diferentes

## Hooks para Agent Teams (L3+L4)

Os hooks do Nível 3 continuam operando com Agent Teams. Cada teammate respeita os mesmos gates:

```json
// .claude/hooks.json (já incluído no bootstrap L3+)
{
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": "scripts/lint-check.sh" }]
    },
    {
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "scripts/security-check.sh" }]
    }
  ],
  "TeammateIdle": [
    {
      "hooks": [{ "type": "command", "command": "echo 'Pick up the next unassigned task'" }]
    }
  ],
  "TaskCompleted": [
    {
      "hooks": [{ "type": "command", "command": "scripts/lint-check.sh" }]
    }
  ]
}
```

`TeammateIdle` e `TaskCompleted` são hooks específicos de Agent Teams:
- **TeammateIdle**: roda quando um teammate vai ficar ocioso. Exit code 2 manda feedback e mantém ele trabalhando.
- **TaskCompleted**: roda quando uma task é marcada como concluída. Exit code 2 impede a conclusão e manda feedback.

## Limitações conhecidas (março 2026)

- Sem resumo de sessão: se a sessão cair, o time não retoma do ponto onde parou
- Sem spawn aninhado: um teammate não pode spawnar outro teammate
- Consome significativamente mais tokens que sessão única
- Funciona melhor quando teammates operam de forma independente
- Para tarefas sequenciais ou edição no mesmo arquivo, sessão única ou sub-agents são mais eficientes

## Checklist de setup

- [ ] Claude Code v2.1.79+ instalado (`claude --version`)
- [ ] Opus 4.6 como modelo padrão
- [ ] `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` em settings.json ou env
- [ ] tmux instalado (recomendado)
- [ ] Agentes definidos em `.claude/agents/`
- [ ] Hooks de L3 configurados (lint, security)
- [ ] Memória indexada (`python memory/index.py`)
- [ ] Bootstrap rodado com `--level 4`

---

*Documentação atualizada em 24 de março de 2026. Claude Code v2.1.79, Opus 4.6.*
