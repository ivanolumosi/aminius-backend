import { Request, Response } from "express";
import { ProspectService } from "../services/prospect.service";

const prospectService = new ProspectService();

export const addProspect = async (req: Request, res: Response) => {
  try {
    const {
      AgentId,
      FirstName,
      Surname,
      LastName,
      PhoneNumber,
      Email,
      Notes
    } = req.body;

    // Basic validation
    if (!AgentId || !FirstName) {
      return res.status(400).json({ 
        Success: false,
        Message: "Agent ID and First Name are required" 
      });
    }

    const result = await prospectService.addProspect({
      AgentId,
      FirstName,
      Surname,
      LastName,
      PhoneNumber,
      Email,
      Notes
    });

    if (result.Success) {
      res.status(201).json(result);
    } else {
      res.status(400).json(result);
    }
    
  } catch (err: any) {
    console.error("Error adding prospect:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to add prospect"
    });
  }
};

export const addProspectPolicy = async (req: Request, res: Response) => {
  try {
    const {
      ProspectId,
      CompanyName,
      PolicyNumber,
      PolicyType,
      ExpiryDate,
      Notes
    } = req.body;

    // Basic validation
    if (!ProspectId || !CompanyName) {
      return res.status(400).json({ 
        Success: false,
        Message: "Prospect ID and Company Name are required" 
      });
    }

    const result = await prospectService.addProspectPolicy({
      ProspectId,
      CompanyName,
      PolicyNumber,
      PolicyType,
      ExpiryDate: ExpiryDate ? new Date(ExpiryDate) : undefined,
      Notes
    });

    if (result.Success) {
      res.status(201).json(result);
    } else {
      res.status(400).json(result);
    }
    
  } catch (err: any) {
    console.error("Error adding prospect policy:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to add prospect policy"
    });
  }
};

export const updateProspect = async (req: Request, res: Response) => {
  try {
    const { prospectId } = req.params;
    const {
      FirstName,
      Surname,
      LastName,
      PhoneNumber,
      Email,
      Notes
    } = req.body;

    // Basic validation
    if (!FirstName) {
      return res.status(400).json({ 
        Success: false,
        Message: "First Name is required" 
      });
    }

    const result = await prospectService.updateProspect({
      ProspectId: prospectId,
      FirstName,
      Surname,
      LastName,
      PhoneNumber,
      Email,
      Notes
    });

    res.json(result);
    
  } catch (err: any) {
    console.error("Error updating prospect:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to update prospect"
    });
  }
};

export const deleteProspect = async (req: Request, res: Response) => {
  try {
    const { prospectId } = req.params;
    const result = await prospectService.deleteProspect(prospectId);
    res.json(result);
  } catch (err: any) {
    console.error("Error deleting prospect:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to delete prospect"
    });
  }
};

export const convertProspectToClient = async (req: Request, res: Response) => {
  try {
    const { prospectId } = req.params;
    const { Address, NationalId, DateOfBirth } = req.body;

    const result = await prospectService.convertProspectToClient({
      ProspectId: prospectId,
      Address,
      NationalId,
      DateOfBirth: DateOfBirth ? new Date(DateOfBirth) : undefined
    });

    if (result.Success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
    
  } catch (err: any) {
    console.error("Error converting prospect to client:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to convert prospect to client"
    });
  }
};

export const getProspectStatistics = async (req: Request, res: Response) => {
  try {
    const { agentId } = req.params;
    const statistics = await prospectService.getProspectStatistics(agentId);
    res.json(statistics);
  } catch (err: any) {
    console.error("Error getting prospect statistics:", err);
    res.status(500).json({ 
      error: "Failed to get prospect statistics",
      Message: err.message || "Failed to retrieve prospect statistics"
    });
  }
};

export const getExpiringProspectPolicies = async (req: Request, res: Response) => {
  try {
    const { agentId } = req.params;
    const { daysAhead } = req.query;
    
    const days = daysAhead ? parseInt(daysAhead as string) : 30;
    const policies = await prospectService.getExpiringProspectPolicies(agentId, days);
    res.json(policies);
  } catch (err: any) {
    console.error("Error getting expiring prospect policies:", err);
    res.status(500).json({ 
      error: "Failed to get expiring policies",
      Message: err.message || "Failed to retrieve expiring prospect policies"
    });
  }
};

export const autoCreateProspectReminders = async (req: Request, res: Response) => {
  try {
    const { agentId } = req.params;
    const result = await prospectService.autoCreateProspectReminders(agentId);
    res.json(result);
  } catch (err: any) {
    console.error("Error auto-creating prospect reminders:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to create prospect reminders",
      RemindersCreated: 0
    });
  }
};

export const getAgentProspects = async (req: Request, res: Response) => {
  try {
    const { agentId } = req.params;
    const prospects = await prospectService.getAgentProspects(agentId);
    res.json(prospects);
  } catch (err: any) {
    console.error("Error getting agent prospects:", err);
    res.status(500).json({ 
      error: "Failed to get prospects",
      Message: err.message || "Failed to retrieve prospects"
    });
  }
};

export const getProspectPolicies = async (req: Request, res: Response) => {
  try {
    const { prospectId } = req.params;
    const policies = await prospectService.getProspectPolicies(prospectId);
    res.json(policies);
  } catch (err: any) {
    console.error("Error getting prospect policies:", err);
    res.status(500).json({ 
      error: "Failed to get prospect policies",
      Message: err.message || "Failed to retrieve prospect policies"
    });
  }
};