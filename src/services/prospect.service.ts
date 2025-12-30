// services/prospect.service.ts
import { poolPromise } from '../../db';
import {
  Prospect,
  ProspectExternalPolicy,
  ProspectStatistics,
  ExpiringProspectPolicy,
  AddProspectRequest,
  AddProspectResponse,
  AddProspectPolicyRequest,
  AddProspectPolicyResponse,
  UpdateProspectRequest,
  ConvertProspectToClientRequest,
  ConvertProspectToClientResponse,
  AutoCreateRemindersResponse
} from '../interfaces/prospect';

export class ProspectService {
  /**
   * Add a new prospect
   */
  public async addProspect(prospectData: AddProspectRequest): Promise<AddProspectResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT sp_add_prospect(
          $1::UUID,
          $2::VARCHAR(50),
          $3::VARCHAR(50),
          $4::VARCHAR(50),
          $5::VARCHAR(20),
          $6::VARCHAR(100),
          $7::TEXT
        ) AS prospect_id
      `, [
        prospectData.AgentId,
        prospectData.FirstName,
        prospectData.Surname || null,
        prospectData.LastName || null,
        prospectData.PhoneNumber || null,
        prospectData.Email || null,
        prospectData.Notes || null
      ]);

      if (result.rows.length > 0 && result.rows[0].prospect_id) {
        return {
          Success: true,
          Message: 'Prospect added successfully',
          ProspectId: result.rows[0].prospect_id
        };
      } else {
        return {
          Success: false,
          Message: 'Failed to add prospect'
        };
      }
    } catch (error: any) {
      console.error('Error adding prospect:', error);
      return {
        Success: false,
        Message: `Failed to add prospect: ${error.message}`
      };
    }
  }

  /**
   * Add external policy to prospect
   */
  public async addProspectPolicy(policyData: AddProspectPolicyRequest): Promise<AddProspectPolicyResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT sp_add_prospect_policy(
          $1::UUID,
          $2::VARCHAR(100),
          $3::VARCHAR(100),
          $4::VARCHAR(100),
          $5::DATE,
          $6::TEXT
        ) AS ext_policy_id
      `, [
        policyData.ProspectId,
        policyData.CompanyName,
        policyData.PolicyNumber || null,
        policyData.PolicyType || null,
        policyData.ExpiryDate || null,
        policyData.Notes || null
      ]);

      if (result.rows.length > 0 && result.rows[0].ext_policy_id) {
        return {
          Success: true,
          Message: 'Prospect policy added successfully',
          ExtPolicyId: result.rows[0].ext_policy_id
        };
      } else {
        return {
          Success: false,
          Message: 'Failed to add prospect policy'
        };
      }
    } catch (error: any) {
      console.error('Error adding prospect policy:', error);
      return {
        Success: false,
        Message: `Failed to add prospect policy: ${error.message}`
      };
    }
  }

  /**
   * Update prospect information
   */
  public async updateProspect(prospectData: UpdateProspectRequest): Promise<{ Success: boolean; Message: string }> {
    try {
      const pool = await poolPromise;
      await pool.query(`
        SELECT sp_update_prospect(
          $1::UUID,
          $2::VARCHAR(50),
          $3::VARCHAR(50),
          $4::VARCHAR(50),
          $5::VARCHAR(20),
          $6::VARCHAR(100),
          $7::TEXT
        )
      `, [
        prospectData.ProspectId,
        prospectData.FirstName,
        prospectData.Surname || null,
        prospectData.LastName || null,
        prospectData.PhoneNumber || null,
        prospectData.Email || null,
        prospectData.Notes || null
      ]);

      return {
        Success: true,
        Message: 'Prospect updated successfully'
      };
    } catch (error: any) {
      console.error('Error updating prospect:', error);
      return {
        Success: false,
        Message: `Failed to update prospect: ${error.message}`
      };
    }
  }

  /**
   * Delete prospect
   */
  public async deleteProspect(prospectId: string): Promise<{ Success: boolean; Message: string }> {
    try {
      const pool = await poolPromise;
      await pool.query('SELECT sp_delete_prospect($1::UUID)', [prospectId]);

      return {
        Success: true,
        Message: 'Prospect deleted successfully'
      };
    } catch (error: any) {
      console.error('Error deleting prospect:', error);
      return {
        Success: false,
        Message: `Failed to delete prospect: ${error.message}`
      };
    }
  }

  /**
   * Convert prospect to client
   */
  public async convertProspectToClient(
    conversionData: ConvertProspectToClientRequest
  ): Promise<ConvertProspectToClientResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT sp_convert_prospect_to_client(
          $1::UUID,
          $2::VARCHAR,
          $3::VARCHAR,
          $4::DATE
        ) AS client_id
      `, [
        conversionData.ProspectId,
        conversionData.Address || 'To be provided',
        conversionData.NationalId || 'To be provided',
        conversionData.DateOfBirth || null
      ]);

      if (result.rows.length > 0 && result.rows[0].client_id) {
        return {
          Success: true,
          Message: 'Prospect converted to client successfully',
          ClientId: result.rows[0].client_id
        };
      } else {
        return {
          Success: false,
          Message: 'Failed to convert prospect to client'
        };
      }
    } catch (error: any) {
      console.error('Error converting prospect to client:', error);
      return {
        Success: false,
        Message: `Failed to convert prospect: ${error.message}`
      };
    }
  }

  /**
   * Get prospect statistics
   */
  public async getProspectStatistics(agentId: string): Promise<ProspectStatistics> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT * FROM sp_get_prospect_statistics($1::UUID)', [agentId]);

      if (result.rows.length > 0) {
        const row = result.rows[0];
        return {
          TotalProspects: row.total_prospects || 0,
          ProspectsWithPolicies: row.prospects_with_policies || 0,
          ExpiringIn7Days: row.expiring_in_7_days || 0,
          ExpiringIn30Days: row.expiring_in_30_days || 0,
          ExpiredPolicies: row.expired_policies || 0
        };
      }

      return {
        TotalProspects: 0,
        ProspectsWithPolicies: 0,
        ExpiringIn7Days: 0,
        ExpiringIn30Days: 0,
        ExpiredPolicies: 0
      };
    } catch (error: any) {
      console.error('Error getting prospect statistics:', error);
      return {
        TotalProspects: 0,
        ProspectsWithPolicies: 0,
        ExpiringIn7Days: 0,
        ExpiringIn30Days: 0,
        ExpiredPolicies: 0
      };
    }
  }

  /**
   * Get expiring prospect policies
   */
  public async getExpiringProspectPolicies(
    agentId: string, 
    daysAhead: number = 30
  ): Promise<ExpiringProspectPolicy[]> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT * FROM sp_get_expiring_prospect_policies($1::UUID, $2::INTEGER)
      `, [agentId, daysAhead]);

      return result.rows.map(row => ({
        ProspectId: row.prospect_id,
        FullName: row.full_name,
        PhoneNumber: row.phone_number,
        Email: row.email,
        PolicyType: row.policy_type,
        CompanyName: row.company_name,
        ExpiryDate: new Date(row.expiry_date),
        DaysUntilExpiry: row.days_until_expiry,
        Priority: row.priority as 'High' | 'Medium' | 'Low'
      }));
    } catch (error: any) {
      console.error('Error getting expiring prospect policies:', error);
      return [];
    }
  }

  /**
   * Auto-create reminders for expiring prospect policies
   */
  public async autoCreateProspectReminders(agentId: string): Promise<AutoCreateRemindersResponse> {
    try {
      const pool = await poolPromise;
      const result = await pool.query('SELECT sp_auto_create_prospect_reminders($1::UUID) AS reminder_count', [agentId]);

      const reminderCount = result.rows[0]?.reminder_count || 0;

      return {
        Success: true,
        Message: `Created ${reminderCount} reminder(s) for expiring prospect policies`,
        RemindersCreated: reminderCount
      };
    } catch (error: any) {
      console.error('Error auto-creating prospect reminders:', error);
      return {
        Success: false,
        Message: `Failed to create reminders: ${error.message}`,
        RemindersCreated: 0
      };
    }
  }

  /**
   * Get all prospects for an agent
   */
  public async getAgentProspects(agentId: string): Promise<Prospect[]> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT 
          prospect_id, agent_id, first_name, surname, last_name,
          phone_number, email, notes, created_date, modified_date, is_active
        FROM prospects 
        WHERE agent_id = $1::UUID AND is_active = TRUE
        ORDER BY created_date DESC
      `, [agentId]);

      return result.rows.map(row => ({
        ProspectId: row.prospect_id,
        AgentId: row.agent_id,
        FirstName: row.first_name,
        Surname: row.surname,
        LastName: row.last_name,
        PhoneNumber: row.phone_number,
        Email: row.email,
        Notes: row.notes,
        CreatedDate: new Date(row.created_date),
        ModifiedDate: new Date(row.modified_date),
        IsActive: row.is_active
      }));
    } catch (error: any) {
      console.error('Error getting agent prospects:', error);
      return [];
    }
  }

  /**
   * Get prospect external policies
   */
  public async getProspectPolicies(prospectId: string): Promise<ProspectExternalPolicy[]> {
    try {
      const pool = await poolPromise;
      const result = await pool.query(`
        SELECT 
          ext_policy_id, prospect_id, company_name, policy_number, policy_type,
          expiry_date, notes, created_date, modified_date, is_active
        FROM prospect_external_policies 
        WHERE prospect_id = $1::UUID AND is_active = TRUE
        ORDER BY expiry_date ASC
      `, [prospectId]);

      return result.rows.map(row => ({
        ExtPolicyId: row.ext_policy_id,
        ProspectId: row.prospect_id,
        CompanyName: row.company_name,
        PolicyNumber: row.policy_number,
        PolicyType: row.policy_type,
        ExpiryDate: row.expiry_date ? new Date(row.expiry_date) : undefined,
        Notes: row.notes,
        CreatedDate: new Date(row.created_date),
        ModifiedDate: new Date(row.modified_date),
        IsActive: row.is_active
      }));
    } catch (error: any) {
      console.error('Error getting prospect policies:', error);
      return [];
    }
  }
}