# Automaton Trading Stack - Project Memory

**Last Updated:** 2026-08-23
**Session:** Integration of investing-algorithm-framework + financial-rpo + automaton

---

## 🎯 Objetivo Principal

Criar um **fundo quantitativo autônomo** (Automaton) que:
1. Descobre e valida strategies via `investing-algorithm-framework` (IAF)
2. Executa live trading via CCXT em sandboxes Conway
3. Monetiza dual: **Finterion** (strategies) + **financial-rpo** (e-books/PIX)
4. Se auto-financia: PIX → USDC → credits → compute → mais alpha
5. Se auto-replica: strategies vencedoras spawnam children autônomos

---

## 📦 Stack Integrado

### 1. Automaton Core (Conway Research)
- **Repo:** `/home/amos/dev/automaton`
- **Tipo:** TypeScript/Node.js, sovereign AI runtime
- **Key features:** Wallet USDC (Base), Conway credits, self-mod, replication, heartbeat, policy engine, 5-tier memory, SOUL.md, ERC-8004, social messaging
- **Build:** `pnpm build` ✅
- **Skills system:** Dynamic loading from `~/.automaton/skills/`

### 2. Investing Algorithm Framework (IAF)
- **Repo:** `/home/amos/dev/investing-algorithm-framework`
- **Tipo:** Python (poetry), production-ready quant framework
- **Key features:**
  - Vector + event-driven backtesting (Polars)
  - 30+ metrics (Sharpe, Sortino, Calmar, Max DD, Consistency, Stability)
  - Cross-sectional pipelines (factor ranking)
  - Live trading via CCXT (Binance, Coinbase, Kraken, Bitvavo...)
  - Deploy: AWS Lambda, Azure Functions, Docker
  - **MCP Server nativo** com 40+ tools (list_strategies, rank_strategies, compare_strategies, get_equity_curve, get_correlation_matrix, create_note, filter_strategies...)
  - Marketplace Finterion plugin
- **MCP Entry:** `python -m investing_algorithm_framework.cli.mcp_server -d <backtest_dir>`
- **Backtests:** `/home/amos/dev/investing-algorithm-framework/examples/batch_one`

### 3. Financial-RPO (Next.js + Supabase)
- **Repo:** `/home/amos/dev/financial-rpo`
- **Tipo:** Next.js 14, TypeScript, Tailwind, Supabase, Vercel
- **Key features:**
  - Loja e-books financeiros (3 planos, checkout WhatsApp + PIX)
  - Dashboard AgentIA: KPIs, fila posts, funil, gerador IA (4 templates), importador tweets, analytics
  - API routes: `/api/generate-post`, `/api/webhook/pix`
  - Deploy: Vercel ou sandbox Conway (systemd service)

---

## 🔧 Skills Criados

### `~/.automaton/skills/trading-engine/SKILL.md`
- Documentação completa de 45+ MCP tools do IAF
- Workflow: Descoberta → Seleção → Validação → Deploy Live → Monetização → Registro
- Integração com automaton tools (create_sandbox, spawn_child, fund_child, topup_credits, etc.)
- Genesis prompt template para child strategies
- Heartbeat tasks recomendadas
- KPIs de sucesso

### `~/.automaton/skills/financial-rpo-deploy/SKILL.md`
- Arquitetura: Automaton → Sandbox Conway → financial-rpo → Supabase
- Workflow deploy: create_sandbox → expose_port → exec deploy script
- Configuração secrets (.env.production)
- Webhook PIX → Bridge USDC → topup_credits loop
- Child automaton opcional para gerenciar loja
- Integração com trading-engine (marketing AgentIA ↔ métricas strategies)

---

## 📜 Scripts Criados

| Script | Localização | Função |
|--------|-------------|--------|
| `deploy-financial-rpo.sh` | `/home/amos/dev/automaton/scripts/` | Deploy standalone financial-rpo em sandbox Conway |
| `deploy-trading-stack.sh` | `/home/amos/dev/automaton/scripts/` | Instala skills, cria genesis template, launchers |
| `start-iaf-mcp.sh` | `~/.automaton/` | Launcher MCP server IAF (python3) |
| `deploy-rpo-helper.sh` | `~/.automaton/` | Helper deploy RPO via automaton context |

---

## 📋 Genesis Template (Quant Fund)

**Arquivo:** `~/.automaton/genesis-trading-template.json`

```json
{
  "name": "QuantFund-Alpha",
  "genesisPrompt": "Você é um gestor de fundo quantitativo autônomo...",
  "creatorMessage": "Genesis trading fund. Capital inicial: $500 USDC. Target: $5k/mo revenue em 90 dias.",
  "creatorAddress": "0xYOUR_ADDRESS_HERE",
  "chainType": "evm"
}
```

**Workflow diário definido:**
1. WAKE: list_strategies → rank_strategies(sharpe) → filter(Sharpe>1.5, DD<15%, WR>55%)
2. ANALYZE: compare_strategies → get_full_analysis → correlation_matrix
3. VALIDATE: return_scenarios → rolling_sharpe → symbol_breakdown
4. DEPLOY: create_sandbox → fund_child → spawn_child com genesis da strategy
5. MONETIZE: Publish Finterion → Marketing financial-rpo AgentIA
6. REINVEST: PIX sales → USDC → topup_credits → mais compute / replicação

**Risk Limits:** Max 20% per strategy, 15% portfolio DD stop, max 3 concurrent, $10 min reserve

---

## 🚀 Próximos Passos Imediatos

1. **Fundar wallet:** Enviar USDC na Base para endereço gerado no wizard
2. **Rodar automaton:** `automaton --run` (usa genesis template)
3. **Instalar MCP:** `install_mcp_server({ name: "trading-engine", command: "~/.automaton/start-iaf-mcp.sh" })`
4. **Deploy RPO:** create_sandbox + expose_port + exec deploy script
5. **Configurar secrets:** Supabase, WhatsApp, OpenAI no sandbox
6. **Webhook PIX:** Supabase → social.conway.tech → bridge → USDC → topup_credits

---

## 💰 Monetização Atual (Dual Track)

| Track | Fonte | Status | Próximo |
|-------|-------|--------|---------|
| **Quant Strategies** | Finterion subscriptions | IAF ready, precisa backtest + publish | Backtest batch_one → rank → publish |
| **E-books/Content** | financial-rpo PIX sales | Code ready, precisa deploy + Supabase | Deploy sandbox + configure webhook |
| **Freelance Dev** | Workana/Upwork/Toptal | **NOVA IDEIA** - analisar agency-agents repo | Análise abaixo |

---

## 🔍 Novas Oportunidades a Analisar

### 1. Freelance Platforms (Workana, Upwork, 99Freelas, Toptal)
- Automaton como "dev autônomo" que pega projetos, desenvolve, entrega, recebe
- Requer: browser automation, proposal writing, code generation, delivery, payment verification
- Repo sugerido: `https://github.com/verticalagent/agency-agents.git`

### 2. /dev/moises + VPS Production API
- Verificar se há infra local/remota disponível para compute barato
- Alternativa ao Conway Cloud para reduzir custos

### 3. Vertical Agency Agents Repo
- Analisar compatibilidade com automaton architecture
- Verificar se pode ser integrado como skill ou child automaton

---

## 📁 Estrutura de Arquivos Importantes

```
/home/amos/dev/automaton/
├── skills/
│   ├── trading-engine/SKILL.md          # IAF MCP integration
│   └── financial-rpo-deploy/SKILL.md    # RPO deploy + monetization
├── scripts/
│   ├── deploy-financial-rpo.sh          # Standalone deploy
│   └── deploy-trading-stack.sh          # Full stack setup
├── PROJECT_MEMORY.md                     # THIS FILE
└── genesis-trading-template.json         # Genesis prompt template

~/.automaton/
├── skills/trading-engine/                # Installed by deploy script
├── skills/financial-rpo-deploy/
├── start-iaf-mcp.sh                      # MCP launcher
├── deploy-rpo-helper.sh                  # Deploy helper
└── genesis-trading-template.json         # Template for wizard
```

---

## ⚠️ Riscos e Bloqueadores

| Risco | Mitigação |
|-------|-----------|
| Conway API rate limits / downtime | Local mode (sandboxId="") + Ollama local inference |
| USDC bridge PIX → USDC indisponível | Usar Bitso, Mercado Pago, Bridge.xyz, Binance Pay APIs |
| IAF MCP server instabilidade | Health check heartbeat, restart policy |
| Finterion approval delay | Parallel track: financial-rpo immediate revenue |
| Freelance platform ToS violation | Verificar ToS, usar API oficial se disponível, human-in-loop para compliance |

---

## 🔑 Variáveis de Ambiente Necessárias

```bash
# Automaton
CONWAY_API_URL=https://api.conway.tech
CONWAY_API_KEY=cnwy_k_...          # provisioned via SIWE
OLLAMA_BASE_URL=http://localhost:11434  # optional local inference

# IAF MCP
IAF_MCP_DIR=/home/amos/dev/investing-algorithm-framework/examples/batch_one

# Financial-RPO (no sandbox)
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
NEXT_PUBLIC_WHATSAPP_NUMBER=5562900000000
OPENAI_API_KEY=sk-...               # para AgentIA
```

---

## 📚 Referências Técnicas

- **Automaton Docs:** ARCHITECTURE.md, DOCUMENTATION.md, constitution.md
- **IAF Docs:** https://coding-kitties.github.io/investing-algorithm-framework/
- **IAF MCP:** https://coding-kitties.github.io/investing-algorithm-framework/Advanced%20Concepts/mcp-server
- **Finterion:** https://www.finterion.com/
- **Conway API:** https://api.conway.tech/docs
- **ERC-8004:** https://ethereum-magicians.org/t/erc-8004-autonomous-agent-identity/22268
- **x402 Protocol:** https://github.com/coinbase/x402