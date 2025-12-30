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
// Prospect Management
// =========================
router.post("/prospect", addProspect);
router.put("/prospect/:prospectId", updateProspect);
router.delete("/prospect/:prospectId", deleteProspect);
router.get("/agent/:agentId/prospects", getAgentProspects);

// =========================
// Prospect Policies
// =========================
router.post("/prospect/policy", addProspectPolicy);
router.get("/prospect/:prospectId/policies", getProspectPolicies);

// =========================
// Prospect Conversion
// =========================
router.post("/prospect/:prospectId/convert-to-client", convertProspectToClient);

// =========================
// Analytics & Statistics
// =========================
router.get("/agent/:agentId/prospect-statistics", getProspectStatistics);
router.get("/agent/:agentId/expiring-prospect-policies", getExpiringProspectPolicies);

// =========================
// Auto Reminders
// =========================
router.post("/agent/:agentId/prospect-reminders/auto-create", autoCreateProspectReminders);

export default router;