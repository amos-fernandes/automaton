#!/usr/bin/env bash
# deploy-trading-stack.sh — Deploy completo: Trading Engine (IAF) + Financial-RPO + Automaton Integration
# Run from automaton directory: ./scripts/deploy-trading-stack.sh

set -euo pipefail

AUTOMATON_DIR="${HOME}/.automaton"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

main() {
    log "=== DEPLOY TRADING STACK ==="
    log "Root: $ROOT_DIR"

    # 1. Verify automaton is built
    log "Checking automaton build..."
    [[ -f "$ROOT_DIR/dist/index.js" ]] || { log "Building automaton..."; cd "$ROOT_DIR" && pnpm build; }
    success "Automaton built"

    # 2. Install skills
    log "Installing skills..."
    SKILLS_DIR="$AUTOMATON_DIR/skills"
    mkdir -p "$SKILLS_DIR"

    # trading-engine skill
    if [[ -d "$ROOT_DIR/skills/trading-engine" ]]; then
        cp -r "$ROOT_DIR/skills/trading-engine" "$SKILLS_DIR/"
        success "trading-engine skill installed"
    fi

    # financial-rpo-deploy skill
    if [[ -d "$ROOT_DIR/skills/financial-rpo-deploy" ]]; then
        cp -r "$ROOT_DIR/skills/financial-rpo-deploy" "$SKILLS_DIR/"
        success "financial-rpo-deploy skill installed"
    fi

    # 3. Verify investing-algorithm-framework MCP server
    log "Checking investing-algorithm-framework..."
    IAF_PATH="/home/amos/dev/investing-algorithm-framework"
    if [[ -d "$IAF_PATH" ]]; then
        cd "$IAF_PATH"
        if command -v poetry >/dev/null; then
            poetry install --quiet 2>/dev/null || true
            success "IAF ready (poetry)"
        elif command -v pip >/dev/null; then
            pip install -e . --quiet 2>/dev/null || true
            success "IAF ready (pip)"
        fi
        # Test MCP server
        timeout 10 python -m investing_algorithm_framework.cli.mcp_server -d examples/batch_one --help 2>&1 | head -5 || true
    else
        warn "IAF not found at $IAF_PATH — MCP server won't work"
    fi

    # 4. Create genesis prompt template for trading automaton
    log "Creating genesis prompt template..."
    cat > "$AUTOMATON_DIR/genesis-trading-template.json" << 'GENESIS_EOF'
{
  "name": "QuantFund-Alpha",
  "genesisPrompt": "Você é um gestor de fundo quantitativo autônomo (Quant Fund).\n\nMISSÃO: Descobrir, validar, deployar e monetizar strategies de trading algorítmico rentáveis.\n\nFERRAMENTAS DISPONÍVEIS:\n1. trading-engine (MCP server: investing-algorithm-framework)\n   - Backtest vetorial + event-driven multi-window\n   - 30+ métricas (Sharpe, Sortino, Calmar, Max DD, Consistency, Stability)\n   - Live trading via CCXT (Binance, Coinbase, Kraken, Bitvavo...)\n   - Deploy AWS Lambda / Azure Functions\n   - Marketplace Finterion para revenue recorrente\n\n2. financial-rpo (Next.js + Supabase em sandbox Conway)\n   - Loja de e-books financeiros + strategies\n   - Dashboard AgentIA para conteúdo marketing\n   - PIX webhook → Bridge USDC → Automaton funding\n\n3. Automaton nativo\n   - create_sandbox / spawn_child para isolamento por strategy\n   - Wallet USDC (Base) + Conway credits\n   - Constitution: Never Harm, Earn Existence, Never Deceive\n   - Self-modification, Replication, Social/ERC-8004\n\nWORKFLOW DIÁRIO:\n1. WAKE: list_strategies → rank_strategies(sharpe_ratio) → filter_strategies(Sharpe>1.5, DD<15%, WR>55%)\n2. ANALYZE: compare_strategies → get_full_analysis → correlation_matrix\n3. VALIDATE: get_return_scenarios → rolling_sharpe → symbol_breakdown\n4. DEPLOY: create_sandbox → fund_child → spawn_child com genesis da strategy\n5. MONETIZE: Publish no Finterion → Marketing via financial-rpo AgentIA\n6. REINVEST: PIX sales → USDC → topup_credits → mais compute / replicação\n\nRISK LIMITS (Constitution + Treasury):\n- Max allocation per strategy: 20% capital\n- Stop loss portfolio: 15% drawdown → pause all\n- Max concurrent live strategies: 3\n- Minimum reserve: $10 credits (treasuryPolicy.minimumReserveCents)\n- Max single transfer: $50 (treasuryPolicy.maxSingleTransferCents)\n\nREPORTING:\n- Daily PnL report ao creator via send_message\n- Weekly SOUL.md reflection com alignment check\n- Monthly strategy performance review (create_note no MCP)\n- Finterion subscriber metrics\n\nREPLICATION:\n- Strategy vencedora (Sharpe>1.5 live 30d) → spawn_child especializado\n- Child herda constitution, wallet próprio, funding parent→child\n- Lineage tracking via replication lineage\n\nNEVER:\n- Deploy sem backtest event-driven + 3+ windows\n- Exceder position sizing rules da strategy\n- Ocultar losses ou manipular métricas\n- Violar Constitution Law I (Never Harm)",
  "creatorMessage": "Genesis trading fund. Capital inicial: $500 USDC. Target: $5k/mo revenue em 90 dias. Boa sorte.",
  "creatorAddress": "0xYOUR_ADDRESS_HERE",
  "chainType": "evm"
}
GENESIS_EOF
    success "Genesis template created at ~/.automaton/genesis-trading-template.json"

    # 5. Create MCP server startup script
    log "Creating MCP server launcher..."
    cat > "$AUTOMATON_DIR/start-iaf-mcp.sh" << 'MCP_EOF'
#!/usr/bin/env bash
# Start investing-algorithm-framework MCP server for automaton
# Usage: ./start-iaf-mcp.sh [backtest_dir]

set -euo pipefail

IAF_DIR="/home/amos/dev/investing-algorithm-framework"
BACKTEST_DIR="${1:-$IAF_DIR/examples/batch_one}"

cd "$IAF_DIR"

# Activate poetry env if available
if [[ -f "poetry.lock" ]] && command -v poetry >/dev/null; then
    poetry run python3 -m investing_algorithm_framework.cli.mcp_server -d "$BACKTEST_DIR"
elif command -v python3 >/dev/null; then
    python3 -m investing_algorithm_framework.cli.mcp_server -d "$BACKTEST_DIR"
else
    python -m investing_algorithm_framework.cli.mcp_server -d "$BACKTEST_DIR"
fi
MCP_EOF
    chmod +x "$AUTOMATON_DIR/start-iaf-mcp.sh"
    success "MCP launcher created"

    # 6. Create financial-rpo deploy helper
    log "Creating financial-rpo deploy helper..."
    cat > "$AUTOMATON_DIR/deploy-rpo-helper.sh" << 'RPO_EOF'
#!/usr/bin/env bash
# Helper to deploy financial-rpo from within automaton context
# Usage: ./deploy-rpo-helper.sh [sandbox_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/deploy-financial-rpo.sh" "$@"
RPO_EOF
    chmod +x "$AUTOMATON_DIR/deploy-rpo-helper.sh"
    success "RPO deploy helper created"

    # 7. Summary
    cat << SUMMARY

=== TRADING STACK DEPLOY COMPLETE ===

SKILLS INSTALLED:
  ~/.automaton/skills/trading-engine/
  ~/.automaton/skills/financial-rpo-deploy/

MCP SERVER:
  Launch: ~/.automaton/start-iaf-mcp.sh [backtest_dir]
  Backtests: /home/amos/dev/investing-algorithm-framework/examples/batch_one

FINANCIAL-RPO DEPLOY:
  Script: ~/.automaton/deploy-rpo-helper.sh [name]
  Full: $ROOT_DIR/scripts/deploy-financial-rpo.sh

GENESIS TEMPLATE:
  ~/.automaton/genesis-trading-template.json
  Edit creatorAddress antes de usar!

NEXT STEPS:
1. Fund automaton wallet with USDC on Base
2. Run: automaton --run
3. In automaton: install_mcp_server({ name: "trading-engine", command: "~/.automaton/start-iaf-mcp.sh" })
4. Deploy financial-rpo: create_sandbox + expose_port + exec deploy script
5. Configure .env.production in sandbox with Supabase/WhatsApp/OpenAI keys
6. Set up PIX webhook → bridge → USDC → topup_credits loop

SUMMARY
}

main "$@"