from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
import uuid

from app.db import get_db
from app.models.eval import Rubric, Worldlet, EvalRun, EvalAttestation
from app.services.eval_runner import run_eval, issue_attestation

router = APIRouter(prefix="/v1/eval", tags=["eval"])


class RubricCreate(BaseModel):
    name: str
    capability_class: str
    version: str = "1.0.0"
    dimensions: list[dict] = []
    hard_gates: list[str] = []
    visibility: str = "public"


class WorldletCreate(BaseModel):
    name: str
    capability_class: str
    visibility: str = "public"
    initial_state: dict = {}
    observations: list[dict] = []
    expected_behavior: dict = {}
    graders: list[str] = []


class EvalRunCreate(BaseModel):
    target_type: str
    target_id: str
    rubric_id: str
    dataset_refs: list[str] = []


@router.post("/rubrics")
async def create_rubric(data: RubricCreate, db: AsyncSession = Depends(get_db)):
    rubric = Rubric(
        id=f"rubric_{uuid.uuid4().hex[:12]}",
        name=data.name,
        capability_class=data.capability_class,
        version=data.version,
        dimensions=data.dimensions,
        hard_gates=data.hard_gates,
        visibility=data.visibility,
    )
    db.add(rubric)
    await db.commit()
    return {"id": rubric.id, "name": rubric.name}


@router.get("/rubrics")
async def list_rubrics(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Rubric))
    return [{"id": r.id, "name": r.name, "capability_class": r.capability_class} for r in result.scalars().all()]


@router.get("/rubrics/{rubric_id}")
async def get_rubric(rubric_id: str, db: AsyncSession = Depends(get_db)):
    rubric = await db.get(Rubric, rubric_id)
    if not rubric:
        raise HTTPException(status_code=404, detail="Rubric not found")
    return rubric


@router.post("/worldlets")
async def create_worldlet(data: WorldletCreate, db: AsyncSession = Depends(get_db)):
    worldlet = Worldlet(
        id=f"worldlet_{uuid.uuid4().hex[:12]}",
        name=data.name,
        capability_class=data.capability_class,
        visibility=data.visibility,
        initial_state=data.initial_state,
        observations=data.observations,
        expected_behavior=data.expected_behavior,
        graders=data.graders,
    )
    db.add(worldlet)
    await db.commit()
    return {"id": worldlet.id, "name": worldlet.name}


@router.get("/worldlets")
async def list_worldlets(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Worldlet))
    worldlets = result.scalars().all()
    # Hide private holdout content
    items = []
    for w in worldlets:
        item = {"id": w.id, "name": w.name, "capability_class": w.capability_class, "visibility": w.visibility}
        if w.visibility != "private_holdout":
            item["initial_state"] = w.initial_state
            item["observations"] = w.observations
            item["expected_behavior"] = w.expected_behavior
        else:
            item["initial_state"] = "[HIDDEN]"
            item["observations"] = "[HIDDEN]"
            item["expected_behavior"] = "[HIDDEN]"
        items.append(item)
    return items


@router.get("/worldlets/{worldlet_id}")
async def get_worldlet(worldlet_id: str, db: AsyncSession = Depends(get_db)):
    worldlet = await db.get(Worldlet, worldlet_id)
    if not worldlet:
        raise HTTPException(status_code=404, detail="Worldlet not found")
    if worldlet.visibility == "private_holdout":
        return {
            "id": worldlet.id,
            "name": worldlet.name,
            "visibility": "private_holdout",
            "detail": "Content hidden - private holdout",
        }
    return worldlet


@router.post("/runs")
async def create_eval_run(data: EvalRunCreate, db: AsyncSession = Depends(get_db)):
    eval_run = await run_eval(db, data.target_type, data.target_id, data.rubric_id, data.dataset_refs)
    return {"id": eval_run.id, "status": eval_run.status, "score_vector": eval_run.score_vector}


@router.get("/runs")
async def list_eval_runs(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(EvalRun))
    return [{"id": r.id, "target_id": r.target_id, "status": r.status} for r in result.scalars().all()]


@router.get("/runs/{run_id}")
async def get_eval_run(run_id: str, db: AsyncSession = Depends(get_db)):
    run = await db.get(EvalRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="Eval run not found")
    return run


@router.post("/runs/{run_id}/issue-attestation")
async def issue_attestation_endpoint(run_id: str, db: AsyncSession = Depends(get_db)):
    attestation = await issue_attestation(db, run_id)
    if not attestation:
        raise HTTPException(status_code=400, detail="Cannot issue attestation - eval not passed or hard gate failed")
    return {"id": attestation.id, "target_id": attestation.target_id}


@router.get("/attestations")
async def list_attestations(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(EvalAttestation))
    return [{"id": a.id, "target_id": a.target_id, "canary_status": a.canary_status} for a in result.scalars().all()]


@router.get("/attestations/{attestation_id}")
async def get_attestation(attestation_id: str, db: AsyncSession = Depends(get_db)):
    att = await db.get(EvalAttestation, attestation_id)
    if not att:
        raise HTTPException(status_code=404, detail="Attestation not found")
    return att
