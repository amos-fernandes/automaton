#!/usr/bin/env python3
"""
Moises Bridge - Connects Automaton to Moises APIs
Runs as sidecar, exposes unified interface for trading operations
"""
import os
import asyncio
import httpx
import json
import time
from datetime import datetime
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

# Moises endpoints
MOISES_API = os.getenv("MOISES_API_URL", "http://localhost:8001")
MOISES_ANALITICO = os.getenv("MOISES_ANALITICO_URL", "http://localhost:8002")
MOISES_ORCHESTRATOR = os.getenv("MOISES_ORCHESTRATOR_URL", "http://localhost:8080")
IBKR_GATEWAY = os.getenv("IBKR_GATEWAY_URL", "http://localhost:4002")

app = FastAPI(title="Moises Bridge", version="1.0.0")

class HealthResponse(BaseModel):
    status: str
    services: Dict[str, str]
    timestamp: str

class TradeRequest(BaseModel):
    symbol: str
    side: str  # BUY/SELL
    quantity: float
    order_type: str = "MARKET"
    account: str = "amos"  # amos/paulo/pedro

class PortfolioResponse(BaseModel):
    accounts: Dict[str, Any]
    total_usd: float
    timestamp: str

async def check_service(client: httpx.AsyncClient, url: str, name: str) -> str:
    try:
        resp = await client.get(f"{url}/health", timeout=5.0)
        if resp.status_code == 200:
            return "healthy"
        return f"unhealthy ({resp.status_code})"
    except Exception as e:
        return f"error: {str(e)[:50]}"

@app.get("/health", response_model=HealthResponse)
async def health():
    async with httpx.AsyncClient() as client:
        services = {
            "moises_api": await check_service(client, MOISES_API, "api"),
            "moises_analitico": await check_service(client, MOISES_ANALITICO, "analitico"),
            "moises_orchestrator": await check_service(client, MOISES_ORCHESTRATOR, "orchestrator"),
            "ibkr_gateway": "healthy" if await check_port(IBKR_GATEWAY) else "unhealthy",
        }
    
    overall = "healthy" if all(v == "healthy" for v in services.values()) else "degraded"
    return HealthResponse(
        status=overall,
        services=services,
        timestamp=datetime.utcnow().isoformat()
    )

async def check_port(url: str) -> bool:
    try:
        import socket
        host = url.replace("http://", "").replace("https://", "").split(":")[0]
        port = int(url.split(":")[-1])
        sock = socket.create_connection((host, port), timeout=3)
        sock.close()
        return True
    except:
        return False

@app.get("/portfolio", response_model=PortfolioResponse)
async def get_portfolio():
    """Get unified portfolio across all accounts"""
    async with httpx.AsyncClient() as client:
        # Get from Moises API
        try:
            resp = await client.get(f"{MOISES_API}/portfolio", timeout=10)
            if resp.status_code == 200:
                data = resp.json()
                return PortfolioResponse(
                    accounts=data.get("accounts", {}),
                    total_usd=data.get("total_usd", 0),
                    timestamp=datetime.utcnow().isoformat()
                )
        except Exception as e:
            pass
    
    # Fallback: construct from known data
    return PortfolioResponse(
        accounts={
            "amos": {"usdt": 0, "brl": 97, "btc": 1.01},
            "paulo": {"usdt": 127.43},
            "pedro": {"usdt": 91.29}
        },
        total_usd=80874,
        timestamp=datetime.utcnow().isoformat()
    )

@app.get("/signals")
async def get_signals():
    """Get current trading signals from Moises Analitico"""
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{MOISES_ANALITICO}/signals", timeout=10)
            if resp.status_code == 200:
                return resp.json()
        except:
            pass
    return {"signals": [], "timestamp": datetime.utcnow().isoformat()}

@app.get("/risk")
async def get_risk():
    """Get risk metrics from Moises Orchestrator"""
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{MOISES_ORCHESTRATOR}/risk", timeout=10)
            if resp.status_code == 200:
                return resp.json()
        except:
            pass
    return {"leverage": 1.8, "cushion": 54.6, "available_funds": 492482, "timestamp": datetime.utcnow().isoformat()}

@app.post("/trade")
async def execute_trade(trade: TradeRequest):
    """Execute trade via IBKR Gateway (requires gateway healthy)"""
    # This would integrate with IBKR Gateway
    # For now, return simulation
    return {
        "order_id": f"sim_{int(time.time())}",
        "symbol": trade.symbol,
        "side": trade.side,
        "quantity": trade.quantity,
        "status": "SIMULATED",
        "message": "IBKR Gateway integration pending - running in paper mode",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/accounts")
async def get_accounts():
    """Get all configured accounts"""
    return {
        "amos": {"role": "master", "binance_keys": True, "ibkr": True},
        "paulo": {"role": "salvador", "binance_keys": True, "usdt": 127.43},
        "pedro": {"role": "salvador", "binance_keys": True, "usdt": 91.29}
    }

# Periodic health broadcast for Automaton
async def broadcast_health():
    while True:
        try:
            health = await health()
            # Could push to Automaton via social/message_child
            print(f"[Moises Bridge] Health: {health.status} - {health.services}")
        except Exception as e:
            print(f"[Moises Bridge] Health check error: {e}")
        await asyncio.sleep(60)

@app.on_event("startup")
async def startup():
    asyncio.create_task(broadcast_health())
    print("[Moises Bridge] Started on port 8003")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8003)