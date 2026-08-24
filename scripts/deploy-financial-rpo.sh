#!/usr/bin/env bash
# deploy-financial-rpo.sh — Deploy financial-rpo (Next.js + Supabase) to Conway Sandbox
# Usage: ./deploy-financial-rpo.sh [sandbox-name] [memory-mb] [vcpu] [disk-gb]

set -euo pipefail

SANDBOX_NAME="${1:-financial-rpo-store}"
MEMORY_MB="${2:-2048}"
VCPU="${3:-2}"
DISK_GB="${4:-20}"

AUTOMATON_DIR="${HOME}/.automaton"
CONFIG_FILE="${AUTOMATON_DIR}/automaton.json"
HEARTBEAT_FILE="${AUTOMATON_DIR}/heartbeat.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; }

# Check dependencies
check_deps() {
    log "Checking dependencies..."
    command -v node >/dev/null || { error "node not found"; exit 1; }
    command -v npm >/dev/null || { error "npm not found"; exit 1; }
    command -v jq >/dev/null || { error "jq not found (install: apt-get install jq)"; exit 1; }

    # Check automaton config exists
    [[ -f "$CONFIG_FILE" ]] || { error "Automaton not configured. Run 'automaton --run' first."; exit 1; }
    success "Dependencies OK"
}

# Get API key and URL from config
get_conway_config() {
    CONWAY_API_URL=$(jq -r '.conwayApiUrl // "https://api.conway.tech"' "$CONFIG_FILE")
    CONWAY_API_KEY=$(jq -r '.conwayApiKey // empty' "$CONFIG_FILE")
    [[ -n "$CONWAY_API_KEY" ]] || { error "No Conway API key in config. Run 'automaton --provision'"; exit 1; }
    log "Conway API: $CONWAY_API_URL"
}

# Create sandbox via Conway API
create_sandbox() {
    log "Creating sandbox: $SANDBOX_NAME (${VCPU}vCPU, ${MEMORY_MB}MB, ${DISK_GB}GB)"

    RESPONSE=$(curl -s -X POST "${CONWAY_API_URL}/v1/sandboxes" \
        -H "Authorization: Bearer ${CONWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${SANDBOX_NAME}\",
            \"vcpu\": ${VCPU},
            \"memory_mb\": ${MEMORY_MB},
            \"disk_gb\": ${DISK_GB}
        }")

    SANDBOX_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
    [[ -n "$SANDBOX_ID" && "$SANDBOX_ID" != "null" ]] || {
        error "Failed to create sandbox: $RESPONSE"
        exit 1
    }
    success "Sandbox created: $SANDBOX_ID"
}

# Wait for sandbox to be running
wait_for_sandbox() {
    log "Waiting for sandbox to be ready..."
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        STATUS=$(curl -s -H "Authorization: Bearer ${CONWAY_API_KEY}" \
            "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}" | jq -r '.status // empty')
        if [[ "$STATUS" == "running" ]]; then
            success "Sandbox is running"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done
    error "Sandbox did not become ready in time"
    exit 1
}

# Deploy financial-rpo to sandbox
deploy_app() {
    log "Deploying financial-rpo to sandbox..."

    # Create deploy script to run inside sandbox
    cat > /tmp/deploy-rpo.sh << 'DEPLOY_EOF'
#!/usr/bin/env bash
set -euo pipefail

cd /root

# Install dependencies
log "Installing system dependencies..."
apt-get update -qq && apt-get install -y -qq git nodejs npm curl

# Clone financial-rpo
log "Cloning financial-rpo..."
git clone https://github.com/amos-fernandes/financial-rpo.git
cd financial-rpo

# Install npm dependencies
log "Installing npm dependencies..."
npm ci --prefer-offline --no-audit 2>&1 | tail -20

# Build Next.js app
log "Building Next.js application..."
npm run build 2>&1 | tail -30

# Create production start script
cat > /root/start-rpo.sh << 'START_EOF'
#!/usr/bin/env bash
cd /root/financial-rpo
# Load env vars
if [[ -f .env.production ]]; then
    export $(grep -v '^#' .env.production | xargs)
fi
# Start Next.js in production mode on port 3000
exec npm start
START_EOF
chmod +x /root/start-rpo.sh

# Create systemd service for auto-restart
cat > /etc/systemd/system/financial-rpo.service << 'SERVICE_EOF'
[Unit]
Description=Financial RPO Next.js App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/financial-rpo
ExecStart=/root/start-rpo.sh
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable financial-rpo
systemctl start financial-rpo

log "Deployment complete. Service started."
DEPLOY_EOF
    chmod +x /tmp/deploy-rpo.sh

    # Copy and execute deploy script in sandbox
    log "Uploading deploy script..."
    curl -s -X POST "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}/files" \
        -H "Authorization: Bearer ${CONWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"path\": \"/root/deploy-rpo.sh\", \"content\": \"$(base64 -w0 /tmp/deploy-rpo.sh)\"}" >/dev/null

    log "Executing deployment (this takes 3-5 minutes)..."
    EXEC_RESPONSE=$(curl -s -X POST "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}/exec" \
        -H "Authorization: Bearer ${CONWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"command": "bash /root/deploy-rpo.sh", "timeout": 600000}')

    echo "$EXEC_RESPONSE" | jq -r '.stdout // .error // .'
    EXIT_CODE=$(echo "$EXEC_RESPONSE" | jq -r '.exitCode // 1')
    [[ "$EXIT_CODE" == "0" ]] || { error "Deployment failed"; exit 1; }
    success "Application deployed and service started"
}

# Expose port 3000
expose_port() {
    log "Exposing port 3000..."
    EXPOSE_RESPONSE=$(curl -s -X POST "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}/ports" \
        -H "Authorization: Bearer ${CONWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"port": 3000, "protocol": "http"}')

    PUBLIC_URL=$(echo "$EXPOSE_RESPONSE" | jq -r '.url // empty')
    [[ -n "$PUBLIC_URL" && "$PUBLIC_URL" != "null" ]] || {
        warn "Port exposure response: $EXPOSE_RESPONSE"
        # Try to get existing ports
        PORTS=$(curl -s -H "Authorization: Bearer ${CONWAY_API_KEY}" \
            "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}/ports" | jq -r '.[] | select(.port==3000) | .url')
        PUBLIC_URL="$PORTS"
    }
    [[ -n "$PUBLIC_URL" ]] && success "App accessible at: $PUBLIC_URL" || warn "Could not get public URL"
}

# Configure environment variables in sandbox
configure_env() {
    log "Configuring environment variables..."
    cat > /tmp/setup-env.sh << 'ENV_EOF'
#!/usr/bin/env bash
cd /root/financial-rpo

cat > .env.production << 'ENVEOF'
# Supabase (configure these!)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# WhatsApp (configure!)
NEXT_PUBLIC_WHATSAPP_NUMBER=5562900000000

# AgentIA / OpenAI (optional - for AI post generation)
OPENAI_API_KEY=your-openai-key

# Production
NODE_ENV=production
PORT=3000
ENVEOF

echo "Created .env.production template. EDIT IT with real credentials!"
ENV_EOF
    chmod +x /tmp/setup-env.sh

    curl -s -X POST "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}/files" \
        -H "Authorization: Bearer ${CONWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"path\": \"/root/setup-env.sh\", \"content\": \"$(base64 -w0 /tmp/setup-env.sh)\"}" >/dev/null

    curl -s -X POST "${CONWAY_API_URL}/v1/sandboxes/${SANDBOX_ID}/exec" \
        -H "Authorization: Bearer ${CONWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"command": "bash /root/setup-env.sh", "timeout": 30000}' >/dev/null

    warn "IMPORTANT: Edit /root/financial-rpo/.env.production in sandbox with real credentials!"
    warn "Then: systemctl restart financial-rpo"
}

# Save sandbox info to automaton state
save_sandbox_info() {
    log "Saving sandbox info to automaton database..."

    # This would be called from within automaton via the Conway client
    # For standalone script, we just output the info
    cat << INFOEOF

=== DEPLOYMENT SUMMARY ===
Sandbox ID: $SANDBOX_ID
Sandbox Name: $SANDBOX_NAME
Public URL: ${PUBLIC_URL:-"Check Conway dashboard"}
SSH: Use Conway dashboard for shell access

NEXT STEPS:
1. Access sandbox shell via Conway dashboard
2. Edit /root/financial-rpo/.env.production with real credentials:
   - Supabase URL + Anon Key
   - WhatsApp number
   - OpenAI API Key (for AgentIA)
3. Run: systemctl restart financial-rpo
4. Test: curl $PUBLIC_URL

MONETIZATION INTEGRATION:
- PIX webhook: $PUBLIC_URL/api/webhook/pix
- AgentIA dashboard: $PUBLIC_URL/dashboard
- E-book store: $PUBLIC_URL/

AUTOMATON INTEGRATION:
- Use 'spawn_child' with this sandbox for strategy-specific stores
- Use 'send_message' to notify automaton of new sales
- Revenue (PIX) → bridge to USDC → topup_credits → more compute
INFOEOF
}

# Main
main() {
    log "Starting financial-rpo deployment to Conway Cloud"
    check_deps
    get_conway_config
    create_sandbox
    wait_for_sandbox
    deploy_app
    expose_port
    configure_env
    save_sandbox_info
    success "Deployment complete!"
}

main "$@"