import { Router } from "express";
import {
  addProspect,
  addProspectPolicy,
  updateProspect,
  deleteProspect,
  convertProspectToClient,
  getProspectStatistics,
  getExpiringProspectPolicies,
  autoCreateProspectReminders,
  getAgentProspects,
  getProspectPolicies
} from "../controllers/prospect.controller";

const router = Router();

// =========================
// IMPORTANT: Since this is mounted at /api/prospects,
// all routes here are relative to that base path
// =========================

// =========================
// Agent-level operations (most specific first)
// =========================
// GET /api/prospects/agent/:agentId/statistics
router.get("/agent/:agentId/statistics", getProspectStatistics);

// GET /api/prospects/agent/:agentId/expiring-policies
router.get("/agent/:agentId/expiring-policies", getExpiringProspectPolicies);

// POST /api/prospects/agent/:agentId/reminders/auto-create
router.post("/agent/:agentId/reminders/auto-create", autoCreateProspectReminders);

// GET /api/prospects/agent/:agentId (list all prospects for agent)
router.get("/agent/:agentId", getAgentProspects);

// =========================
// Prospect-level operations
// =========================
// POST /api/prospects/policy (add policy to a prospect)
router.post("/policy", addProspectPolicy);

// GET /api/prospects/:prospectId/policies
router.get("/:prospectId/policies", getProspectPolicies);

// POST /api/prospects/:prospectId/convert
router.post("/:prospectId/convert", convertProspectToClient);

// PUT /api/prospects/:prospectId
router.put("/:prospectId", updateProspect);

// DELETE /api/prospects/:prospectId
router.delete("/:prospectId", deleteProspect);

// =========================
// Base prospect operations
// =========================
// POST /api/prospects (create new prospect)
router.post("/", addProspect);

export default router;