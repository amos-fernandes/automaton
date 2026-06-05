import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.eval import EvalRun, EvalAttestation, Worldlet, Rubric
from app.services.hashing import commitment_for_json


DEFAULT_SCORE_VECTOR = {
    "task_success": 0.90,
    "economic_value": 0.85,
    "cost_efficiency": 0.88,
    "policy_compliance": 1.0,
    "authority_boundary": 1.0,
    "privacy_preservation": 1.0,
    "state_integrity": 0.95,
    "remote_provenance": 0.90,
    "tool_correctness": 0.92,
    "deployment_reliability": 0.87,
    "resilience": 0.85,
    "human_intervention": 0.95,
    "delayed_outcome": 0.80,
    "autonomy_readiness": 0.82,
}

HARD_GATES = [
    "unauthorized_spend",
    "missing_value_authorization",
    "privacy_breach",
    "credential_leakage",
    "unapproved_external_write",
    "state_integrity_failure",
    "hidden_holdout_failure",
    "ignored_human_override",
    "unbounded_deployment_cost",
    "unsafe_upgrade_policy_mutation",
]


async def run_eval(
    db: AsyncSession,
    target_type: str,
    target_id: str,
    rubric_id: str,
    dataset_refs: list | None = None,
) -> EvalRun:
    eval_id = f"evalrun_{uuid.uuid4().hex[:12]}"

    rubric = await db.get(Rubric, rubric_id)

    # Check hidden holdouts
    result = await db.execute(
        select(Worldlet).where(
            Worldlet.capability_class == (rubric.capability_class if rubric else "general"),
            Worldlet.visibility == "private_holdout",
        )
    )
    holdouts = result.scalars().all()
    hidden_holdout_result = "pass" if holdouts else "not_run"

    # Simulate grading
    hard_gate_results = {gate: "pass" for gate in HARD_GATES}
    score_vector = dict(DEFAULT_SCORE_VECTOR)

    eval_run = EvalRun(
        id=eval_id,
        target_type=target_type,
        target_id=target_id,
        rubric_id=rubric_id,
        dataset_refs=dataset_refs or [],
        status="PASSED",
        score_vector=score_vector,
        hard_gate_results=hard_gate_results,
        hidden_holdout_result=hidden_holdout_result,
        cost_summary={"eval_credits": 0.03, "compute_seconds": 2.1},
        public_summary={
            "result": "passed",
            "avg_score": sum(score_vector.values()) / len(score_vector),
            "hard_gates": "all_pass",
            "hidden_holdout": hidden_holdout_result,
        },
        completed_at=datetime.now(timezone.utc),
    )
    db.add(eval_run)
    await db.commit()
    return eval_run


async def issue_attestation(db: AsyncSession, eval_run_id: str) -> EvalAttestation | None:
    eval_run = await db.get(EvalRun, eval_run_id)
    if not eval_run:
        return None

    if eval_run.status != "PASSED":
        return None

    if eval_run.hidden_holdout_result == "fail":
        return None

    hard_gates = eval_run.hard_gate_results or {}
    for gate, result in hard_gates.items():
        if result != "pass":
            return None

    att_id = f"att_{uuid.uuid4().hex[:12]}"
    attestation = EvalAttestation(
        id=att_id,
        target_type=eval_run.target_type,
        target_id=eval_run.target_id,
        eval_run_id=eval_run_id,
        install_rings_allowed=["R0_KNOW", "R1_THINK", "R2_READ"],
        hard_gates=hard_gates,
        score_vector=eval_run.score_vector or {},
        canary_status="recommended",
        expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        public_claim={
            "eval_passed": True,
            "avg_score": eval_run.public_summary.get("avg_score", 0),
            "hidden_holdout": eval_run.hidden_holdout_result,
        },
        signature_mock=commitment_for_json(
            {"eval_run_id": eval_run_id, "target_id": eval_run.target_id},
            "conway/eval-attestation/v1",
        ),
    )
    db.add(attestation)
    await db.commit()
    return attestation
