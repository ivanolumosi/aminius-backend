import { Router } from "express";
import {
  upsertAgentProfile,
  getAgentProfile,
  updateAgentSettings,
  authenticateAgent,
  loginAgent,
  registerAgent,
  changeAgentPassword,
  requestPasswordReset,
  resetAgentPassword,
  sendTemporaryPassword,
  getInsuranceCompanies,
  getPolicyTypes,
  getNavbarBadgeCounts
} from "../controllers/agent.controller";

const router = Router();

// =========================
// Data Lookups (no params)
// =========================
router.get("/insurance-companies", getInsuranceCompanies);
router.get("/policy-types", getPolicyTypes);

// =========================
// Authentication (specific routes BEFORE parameterized routes)
// =========================
router.post("/agent/authenticate", authenticateAgent);
router.post("/agent/login", loginAgent);

// =========================
// Registration (specific route)
// =========================
router.post("/agent/register", registerAgent);

// =========================
// Password Management (specific routes BEFORE parameterized routes)
// =========================
router.post("/agent/password-reset/request", requestPasswordReset);
router.post("/agent/password-reset/temporary", sendTemporaryPassword);

// =========================
// Agent Profile (basic CRUD)
// =========================
router.post("/agent", upsertAgentProfile);
router.get("/agent/:agentId", getAgentProfile);

// =========================
// Settings (parameterized route)
// =========================
router.put("/agent/:agentId/settings", updateAgentSettings);

// =========================
// Password Management (parameterized routes)
// =========================
router.post("/agent/:agentId/change-password", changeAgentPassword);
router.post("/agent/:agentId/password-reset", resetAgentPassword);

// =========================
// Navbar Badge Counts (parameterized route)
// =========================
router.get("/agent/:agentId/navbar-counts", getNavbarBadgeCounts);

export default router;