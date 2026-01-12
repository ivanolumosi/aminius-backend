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
// Agent Profile
// =========================
router.post("/agent", upsertAgentProfile);
router.get("/agent/:agentId", getAgentProfile);

// =========================
// Settings
// =========================
router.put("/agent/:agentId/settings", updateAgentSettings);

// =========================
// Authentication
// =========================
router.post("/agent/authenticate", authenticateAgent);
router.post("/agent/login", loginAgent);

// =========================
// Registration
// =========================
router.post("/agent/register", registerAgent);

// =========================
// Password Management
// =========================
router.post("/agent/:agentId/change-password", changeAgentPassword);
router.post("/agent/password-reset/request", requestPasswordReset);
router.post("/agent/:agentId/password-reset", resetAgentPassword);
router.post("/agent/password-reset/temporary", sendTemporaryPassword);

// =========================
// Data Lookups
// =========================
router.get("/insurance-companies", getInsuranceCompanies);
router.get("/policy-types", getPolicyTypes);

// =========================
// Navbar Badge Counts
// =========================
router.get("/agent/:agentId/navbar-counts", getNavbarBadgeCounts);

export default router;