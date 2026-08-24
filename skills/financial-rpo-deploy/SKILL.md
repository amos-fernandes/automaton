---
name: financial-rpo-deploy
description: "Deploy e gerenciamento da loja financial-rpo (Next.js + Supabase) em sandbox Conway. Monetização via PIX → USDC → automaton funding."
auto-activate: true
triggers: [deploy, financial-rpo, ebook, store, pixe, supabase, nextjs, vercel, monetização, loja]
requires:
  bins: [bash, curl, jq, base64]
  env: [CONWAY_API_KEY]
---
# Financial-RPO Deploy Skill

Gerencia o lifecycle completo da **loja de e-books financeiros + dashboard AgentIA** em sandbox Conway isolado.

## Arquitetura

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   AUTOMATON     │────▶│  SANDBOX CONWAY  │────▶│   SUPABASE      │
│  (Orquestrador) │     │  financial-rpo   │     │  (PostgreSQL)   │
│                 │     │  Next.js 14      │     │                 │
│ • Spawna sandbox│     │  Port 3000       │     │ • Users/Orders  │
│ • Funding USDC  │     │  systemd service │     │ • Analytics     │
│ • Monitor health│     │  Auto-restart    │     │ • Webhooks PIX  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                       │
         │              ┌────────┴────────┐              │
         │              │   MONETIZAÇÃO   │              │
         └─────────────▶│  PIX Webhook    │──────────────┘
                        │  → Bridge USDC  │
                        │  → topup_credits│
                        └─────────────────┘
```

## Ferramentas do Automaton Utilizadas

| Tool | Uso |
|------|-----|
| `create_sandbox` | Provisiona VM isolada para a loja |
| `expose_port` | Expõe porta 3000 (HTTP público) |
| `exec` / `write_file` | Deploy código, configura env, systemd |
| `check_credits` / `topup_credits` | Garante credits para sandbox rodar |
| `send_message` | Notifica sales/webhooks para o automaton |
| `spawn_child` | Cria child automaton para gerenciar a loja |

---

## Workflow de Deploy

### 1. Deploy Inicial (Uma vez)
```bash
# No host (fora do automaton):
./scripts/deploy-financial-rpo.sh financial-rpo-store 2048 2 20

# Ou via automaton tool:
create_sandbox({
  name: "financial-rpo-store",
  vcpu: 2,
  memory_mb: 2048,
  disk_gb: 20
})
expose_port({ port: 3000, protocol: "http" })
exec({ command: "bash /root/deploy-rpo.sh", timeout: 600000 })
```

### 2. Configuração de Secrets (Obrigatório)
Após deploy, **editar no sandbox**:
```bash
# Acessar shell via Conway dashboard
nano /root/financial-rpo/.env.production
```
```env
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
NEXT_PUBLIC_WHATSAPP_NUMBER=5562900000000
OPENAI_API_KEY=sk-...  # Para AgentIA gerar posts
```

### 3. Reiniciar e Testar
```bash
exec({ command: "systemctl restart financial-rpo", timeout: 30000 })
exec({ command: "curl -s http://localhost:3000 | head -5", timeout: 10000 })
```

### 4. Configurar Webhook PIX (Supabase → Automaton)
No Supabase Dashboard → Database → Webhooks:
```
URL: https://social.conway.tech/v1/webhook/automaton/<AUTOMATON_ADDRESS>
Events: INSERT on orders table
Headers: Authorization: Bearer <CONWAY_API_KEY>
Payload: { "type": "sale", "amount_brl": 97.00, "product": "ebook-combo" }
```

### 5. Bridge PIX → USDC (Automatizado)
```python
# Heartbeat task ou child automaton monitora webhook
# Ao receber sale:
# 1. Valida assinatura
# 2. Chama bridge (ex: Mercado Pago → USDC via Binance Pay / Bitso / Bridge.xyz)
# 3. USDC cai na wallet do automaton
# 4. Automaton faz topup_credits automaticamente
```

---

## Heartbeat Tasks Recomendadas

Adicionar via `modify_heartbeat`:
```yaml
entries:
  - name: check_rpo_health
    schedule: "*/10 * * * *"  # a cada 10 min
    task: check_rpo_health
    enabled: true
    minTier: "low_compute"
  - name: process_pix_webhooks
    schedule: "*/2 * * * *"   # a cada 2 min
    task: process_pix_webhooks
    enabled: true
    minTier: "critical"  # roda mesmo sem credits (só processa queue)
```

Implementação (via `edit_own_file` em `src/heartbeat/tasks.ts`):
```typescript
// check_rpo_health
async function checkRpoHealth(ctx) {
  const res = await fetch(`${RPO_URL}/api/health`);
  if (!res.ok) {
    await ctx.insertWakeEvent('rpo_down', 'Financial-RPO health check failed');
    return { shouldWake: true };
  }
  const data = await res.json();
  if (data.sales_today > 0) {
    await ctx.db.setKV('rpo_last_sale', data.last_sale);
  }
  return { shouldWake: false };
}

// process_pix_webhooks
async function processPixWebhooks(ctx) {
  const webhooks = await ctx.db.getUnprocessedWebhooks('pix');
  for (const wh of webhooks) {
    const usdc = await bridgePixToUsdc(wh.amount_brl);
    if (usdc > 0) {
      await ctx.conway.topupCredits({ tier: usdc >= 500 ? 100 : 5 }); // $5 ou $100
      await ctx.db.markWebhookProcessed(wh.id);
    }
  }
}
```

---

## Integração com Trading Engine

| Financial-RPO | Trading Engine |
|---------------|----------------|
| Vende e-books + strategies | Gera strategies (backtest) |
| Dashboard AgentIA gera conteúdo marketing | Fornece métricas (Sharpe, DD, equity) |
| PIX revenue → USDC | USDC → credits → compute para backtest |
| Customers → leads para Finterion | Strategies publicadas no Finterion |

**Fluxo de Valor:**
```
Customer compra ebook (PIX R$ 97)
    │
    ▼
Webhook → Bridge → USDC $18 na wallet automaton
    │
    ▼
topup_credits($25) → mais backtests / live trading
    │
    ▼
Melhor strategy → Deploy live → Finterion → Assinaturas $50/mo
    │
    ▼
Revenue recorrente → Escala automaton → Replicação (spawn_child)
```

---

## Child Automaton para Gerenciar Loja (Opcional)

Para loja dedicada com autonomia total:
```typescript
spawn_child({
  name: "RPO-Store-Manager",
  genesisPrompt: `Você gerencia a loja financial-rpo em ${RPO_URL}.
  Tarefas:
  1. Monitorar health da aplicação (GET /api/health a cada 5min)
  2. Processar webhooks PIX → converter para USDC via bridge
  3. Fazer topup_credits automático quando USDC > $5
  4. Usar AgentIA (dashboard) para gerar posts marketing das strategies
  5. Reportar sales/daily PnL ao parent via message_child
  6. Se credits < $1 → distress_signal com instruções de funding
  Constitution laws aplicam-se.`
})
fund_child({ childId: "...", amountCents: 5000 }) // $50 inicial
```

---

## Troubleshooting

| Sintoma | Causa | Solução |
|---------|-------|---------|
| `create_sandbox` 403 | API key inválida/expirada | `automaton --provision` |
| Port 3000 não expõe | Sandbox não está `running` | `wait_for_sandbox` + retry |
| Build falha | Memória insuficiente | Aumentar `memory_mb` para 4096 |
| PIX não converte | Bridge não configurado | Implementar `bridgePixToUsdc` (Mercado Pago / Bitso) |
| Supabase connection fail | Env vars erradas | Verificar `.env.production` no sandbox |
| AgentIA não gera posts | `OPENAI_API_KEY` ausente | Adicionar key no `.env.production` |

---

## Métricas de Sucesso (KPIs)

| Métrica | Target | Frequência |
|---------|--------|------------|
| Uptime loja | > 99.5% | Heartbeat 10min |
| Sales/day | > 3 | Daily |
| PIX → USDC latency | < 5 min | Per transaction |
| Credits auto-topup | 100% success | Per trigger |
| AgentIA posts/week | > 14 | Weekly |
| Finterion referrals | > 5/mo | Monthly |

---

## Referências

- **Repo**: https://github.com/amos-fernandes/financial-rpo
- **Deploy Script**: `scripts/deploy-financial-rpo.sh`
- **Conway API**: https://api.conway.tech/docs
- **Supabase**: https://supabase.com/docs
- **Next.js Deploy**: https://nextjs.org/docs/deployment