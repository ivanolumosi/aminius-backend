import { Pool } from 'pg';
import { validate as uuidValidate } from 'uuid';

import { poolPromise } from '../../db';
import {
    Reminder,
    ReminderSettings,
    CreateReminderRequest,
    UpdateReminderRequest,
    ReminderFilters,
    PaginatedReminderResponse,
    BirthdayReminder,
    PolicyExpiryReminder,
    PhoneValidationResult
} from '../interfaces/reminders';

export interface ReminderStatistics {
    TotalActive: number;
    TotalCompleted: number;
    TodayReminders: number;
    UpcomingReminders: number;
    HighPriority: number;
    Overdue: number;
}

export class ReminderService {
    private isValidUUID(uuid: string): boolean {
        return uuidValidate(uuid);
    }

    /** Create a new reminder - FIXED to return complete reminder object */
    public async createReminder(agentId: string, reminderData: CreateReminderRequest): Promise<Reminder> {
        console.log('📝 Backend: Creating reminder with raw data:', reminderData);
        
        try {
            // Validate agentId
            if (!agentId || !this.isValidUUID(agentId)) {
                throw new Error('Valid Agent ID is required');
            }

            if (!this.isValidReminderType(reminderData.ReminderType)) {
                throw new Error(`Invalid reminder type: ${reminderData.ReminderType}`);
            }

            let validatedTime: string | null = null;
            
            if (reminderData.ReminderTime) {
                validatedTime = this.validateAndFormatPostgreSQLTime(reminderData.ReminderTime);
                console.log('📝 Backend: Time validated:', reminderData.ReminderTime, '->', validatedTime);
            }
            
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT sp_create_reminder(
                        $1::uuid, $2::uuid, $3::uuid, $4::varchar(50), $5::varchar(200),
                        $6::text, $7::date, $8::time, $9::varchar(150), $10::varchar(10),
                        $11::boolean, $12::boolean, $13::boolean, $14::varchar(20),
                        $15::text, $16::boolean, $17::text
                    ) as reminder_id
                `;
                
                const values = [
                    agentId,
                    reminderData.ClientId || null,
                    reminderData.AppointmentId || null,
                    reminderData.ReminderType,
                    reminderData.Title,
                    reminderData.Description || null,
                    reminderData.ReminderDate,
                    validatedTime,
                    reminderData.ClientName || null,
                    reminderData.Priority || 'Medium',
                    reminderData.EnableSMS || false,
                    reminderData.EnableWhatsApp || false,
                    reminderData.EnablePushNotification || true,
                    reminderData.AdvanceNotice || '1 day',
                    reminderData.CustomMessage || null,
                    reminderData.AutoSend || false,
                    reminderData.Notes || null
                ];

                console.log('📝 Backend: Executing query with validated time:', validatedTime);
                
                const result = await client.query(query, values);
                const reminderId = result.rows[0].reminder_id;
                
                console.log('✅ Backend: Reminder created with ID:', reminderId);
                
                // FIXED: Fetch and return the complete reminder object
                const createdReminder = await this.getReminderById(reminderId, agentId);
                if (!createdReminder) {
                    throw new Error('Failed to retrieve created reminder');
                }
                
                console.log('✅ Backend: Returning complete reminder object');
                return createdReminder;
                
            } finally {
                client.release();
            }
            
        } catch (error: unknown) {
            console.error('❌ Backend: Error creating reminder:', error);
            console.error('❌ Original reminder data:', reminderData);
            
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            throw new Error(`Failed to create reminder: ${errorMessage}`);
        }
    }

    /** Update a reminder - FIXED to return complete reminder object */
    public async updateReminder(reminderId: string, agentId: string, updateData: UpdateReminderRequest): Promise<Reminder> {
        // Validate inputs
        if (!reminderId || !this.isValidUUID(reminderId)) {
            throw new Error('Valid Reminder ID is required');
        }
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            let validatedTime: string | null = null;
            if (updateData.ReminderTime) {
                validatedTime = this.validateAndFormatPostgreSQLTime(updateData.ReminderTime);
            }
            
            const query = `
                SELECT sp_update_reminder(
                    $1::uuid, $2::uuid, $3::varchar(200), $4::text, $5::date,
                    $6::time, $7::varchar(10), $8::varchar(20), $9::boolean,
                    $10::boolean, $11::boolean, $12::varchar(20), $13::text,
                    $14::boolean, $15::text
                ) as rows_affected
            `;
            
            const values = [
                reminderId,
                agentId,
                updateData.Title || null,
                updateData.Description || null,
                updateData.ReminderDate || null,
                validatedTime,
                updateData.Priority || null,
                updateData.Status || null,
                updateData.EnableSMS || null,
                updateData.EnableWhatsApp || null,
                updateData.EnablePushNotification || null,
                updateData.AdvanceNotice || null,
                updateData.CustomMessage || null,
                updateData.AutoSend || null,
                updateData.Notes || null
            ];
            
            const result = await client.query(query, values);
            console.log('✅ Backend: Update affected rows:', result.rows[0].rows_affected);
            
            // FIXED: Fetch and return the complete updated reminder object
            const updatedReminder = await this.getReminderById(reminderId, agentId);
            if (!updatedReminder) {
                throw new Error('Failed to retrieve updated reminder');
            }
            
            return updatedReminder;
        } finally {
            client.release();
        }
    }

    /** Get all reminders with filters and pagination */
    public async getAllReminders(agentId: string, filters: ReminderFilters = {}): Promise<PaginatedReminderResponse> {
        // Validate agentId
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            console.log('🔍 ReminderService.getAllReminders - Starting...');
            console.log('🔍 AgentId:', agentId);
            console.log('🔍 Filters:', filters);

            // Determine which function to use based on filters
            const hasFilters = filters.ReminderType || 
                              filters.Status || 
                              filters.Priority || 
                              filters.ClientId;

            let query: string;
            let values: any[];

            if (hasFilters) {
                query = `
                    SELECT * FROM sp_get_all_reminders_with_filters(
                        $1::uuid, $2::varchar, $3::varchar, $4::varchar, 
                        $5::date, $6::date, $7::uuid, $8::integer, $9::integer
                    )
                `;
                
                values = [
                    agentId,
                    filters.ReminderType || null,
                    filters.Status || null,
                    filters.Priority || null,
                    filters.StartDate || null,
                    filters.EndDate || null,
                    filters.ClientId || null,
                    filters.PageNumber || 1,
                    filters.PageSize || 20
                ];
            } else {
                query = `
                    SELECT * FROM sp_get_all_reminders(
                        $1::uuid, $2::date, $3::date, $4::integer, $5::integer
                    )
                `;
                
                values = [
                    agentId,
                    filters.StartDate || null,
                    filters.EndDate || null,
                    filters.PageNumber || 1,
                    filters.PageSize || 20
                ];
            }

            console.log('🔍 Executing query:', query);
            console.log('🔍 Query values:', values);

            const result = await client.query(query, values);
            console.log('✅ Query executed successfully, rows:', result.rows.length);

            // Map database results to frontend-compatible format
            const reminders: Reminder[] = result.rows.map(row => this.mapDatabaseRowToReminder(row));
            const pageSize = filters.PageSize || 20;
            const currentPage = filters.PageNumber || 1;

            let totalRecords = 0;
            if (hasFilters && result.rows.length > 0) {
                totalRecords = parseInt(result.rows[0].total_records) || 0;
            } else if (!hasFilters) {
                // Simplified count query for non-filtered results
                const countQuery = `
                    SELECT COUNT(*) as total FROM reminders WHERE agent_id = $1
                `;
                const countResult = await client.query(countQuery, [agentId]);
                totalRecords = parseInt(countResult.rows[0]?.total) || 0;
            } else {
                totalRecords = reminders.length;
            }

            const response: PaginatedReminderResponse = {
                reminders,
                totalRecords,
                currentPage,
                totalPages: Math.ceil(totalRecords / pageSize),
                pageSize
            };

            console.log('✅ getAllReminders completed:', {
                totalReminders: reminders.length,
                totalRecords,
                currentPage,
                totalPages: response.totalPages
            });

            return response;

        } catch (error) {
            console.error('❌ ReminderService.getAllReminders - Error:', error);
            throw error;
        } finally {
            client.release();
        }
    }

    /** Get reminder by ID */
    public async getReminderById(reminderId: string, agentId: string): Promise<Reminder | null> {
        // Validate inputs
        if (!reminderId || !this.isValidUUID(reminderId)) {
            throw new Error('Valid Reminder ID is required');
        }
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            console.log('🔍 ReminderService.getReminderById - Starting...');
            console.log('🔍 ReminderId:', reminderId);
            console.log('🔍 AgentId:', agentId);

            const query = `
                SELECT * FROM sp_get_reminder_by_id($1::uuid, $2::uuid)
            `;
            
            const result = await client.query(query, [reminderId, agentId]);
            
            if (result.rows.length === 0) {
                console.log('ℹ️ No reminder found for ID:', reminderId);
                return null;
            }
            
            const reminder = this.mapDatabaseRowToReminder(result.rows[0]);
            console.log('✅ getReminderById completed:', reminder.Title);
            
            return reminder;

        } catch (error) {
            console.error('❌ ReminderService.getReminderById - Error:', error);
            throw error;
        } finally {
            client.release();
        }
    }

    /** Delete a reminder */
    public async deleteReminder(reminderId: string, agentId: string): Promise<{ RowsAffected: number }> {
        // Validate inputs
        if (!reminderId || !this.isValidUUID(reminderId)) {
            throw new Error('Valid Reminder ID is required');
        }
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT sp_delete_reminder($1::uuid, $2::uuid) as rows_affected
            `;
            
            const result = await client.query(query, [reminderId, agentId]);
            return { RowsAffected: result.rows[0].rows_affected };
        } finally {
            client.release();
        }
    }

    /** Complete a reminder */
    public async completeReminder(reminderId: string, agentId: string, notes?: string): Promise<{ RowsAffected: number }> {
        // Validate inputs
        if (!reminderId || !this.isValidUUID(reminderId)) {
            throw new Error('Valid Reminder ID is required');
        }
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT sp_complete_reminder($1::uuid, $2::uuid, $3::text) as rows_affected
            `;
            
            const result = await client.query(query, [reminderId, agentId, notes || null]);
            return { RowsAffected: result.rows[0].rows_affected };
        } finally {
            client.release();
        }
    }

    /** Get today's reminders */
    public async getTodayReminders(agentId: string): Promise<Reminder[]> {
        // Validate agentId
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            // Try the stored procedure first
            try {
                const query = `
                    SELECT * FROM sp_get_today_reminders_direct($1::uuid)
                `;
                
                const result = await client.query(query, [agentId]);
                return result.rows.map(row => this.mapDatabaseRowToReminder(row));
                
            } catch (spError) {
                console.warn('⚠️ Stored procedure failed, using fallback:', spError);
                
                // Fallback: Direct query for today's reminders
                const fallbackQuery = `
                    SELECT 
                        reminder_id,
                        client_id,
                        appointment_id,
                        agent_id,
                        reminder_type,
                        title,
                        description,
                        reminder_date,
                        reminder_time,
                        client_name,
                        priority,
                        status,
                        enable_sms,
                        enable_whatsapp,
                        enable_push_notification,
                        advance_notice,
                        custom_message,
                        auto_send,
                        notes,
                        created_date,
                        modified_date,
                        completed_date
                    FROM reminders 
                    WHERE agent_id = $1 
                    AND reminder_date = CURRENT_DATE
                    AND status = 'Active'
                    ORDER BY reminder_time ASC NULLS LAST, created_date ASC
                `;
                
                const fallbackResult = await client.query(fallbackQuery, [agentId]);
                return fallbackResult.rows.map(row => this.mapDatabaseRowToReminder(row));
            }
            
        } catch (error) {
            console.error('❌ Error in getTodayReminders:', error);
            throw error;
        } finally {
            client.release();
        }
    }

    /** Get reminder settings */
    public async getReminderSettings(agentId: string): Promise<ReminderSettings[]> {
        // Validate agentId
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT * FROM sp_get_reminder_settings($1::uuid)
            `;
            
            const result = await client.query(query, [agentId]);
            return result.rows.map(row => this.mapDatabaseRowToReminderSettings(row));
        } finally {
            client.release();
        }
    }

    /** Update reminder settings */
    public async updateReminderSettings(agentId: string, settings: ReminderSettings): Promise<void> {
        // Validate agentId
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT sp_update_reminder_settings(
                    $1::uuid, $2::varchar(50), $3::boolean, $4::integer, $5::time, $6::boolean
                )
            `;
            
            await client.query(query, [
                agentId, 
                settings.ReminderType, 
                settings.IsEnabled, 
                settings.DaysBefore, 
                settings.TimeOfDay, 
                settings.RepeatDaily
            ]);
        } finally {
            client.release();
        }
    }

    /** Get reminder statistics */
    public async getReminderStatistics(agentId: string): Promise<ReminderStatistics> {
        // Validate agentId
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        try {
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT * FROM sp_get_reminder_statistics($1::uuid)
                `;
                
                const result = await client.query(query, [agentId]);

                if (result.rows.length === 0) {
                    return {
                        TotalActive: 0,
                        TotalCompleted: 0,
                        TodayReminders: 0,
                        UpcomingReminders: 0,
                        HighPriority: 0,
                        Overdue: 0
                    };
                }

                const row = result.rows[0];
                return {
                    TotalActive: parseInt(row.total_active) || 0,
                    TotalCompleted: parseInt(row.total_completed) || 0,
                    TodayReminders: parseInt(row.today_reminders) || 0,
                    UpcomingReminders: parseInt(row.upcoming_reminders) || 0,
                    HighPriority: parseInt(row.high_priority) || 0,
                    Overdue: parseInt(row.overdue) || 0
                };
            } finally {
                client.release();
            }
        } catch (error: unknown) {
            console.error('Error fetching reminder statistics:', error);
            throw error;
        }
    }

    /** Get reminders filtered by ReminderType */
    async getRemindersByType(agentId: string, reminderType: string): Promise<Reminder[]> {
        // Validate inputs
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }
        if (!reminderType) {
            throw new Error('Reminder type is required');
        }

        // FIXED: Validate against expanded reminder types
        if (!this.isValidReminderType(reminderType)) {
            throw new Error(`Invalid reminder type: ${reminderType}`);
        }

        try {
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT * FROM sp_get_reminders_by_type($1::uuid, $2::varchar(50))
                `;
                
                const result = await client.query(query, [agentId, reminderType]);
                return result.rows.map(row => this.mapDatabaseRowToReminder(row));
            } finally {
                client.release();
            }
        } catch (error: unknown) {
            console.error('Error fetching reminders by type:', error);
            throw error;
        }
    }

    /** Get reminders filtered by Status */
    async getRemindersByStatus(agentId: string, status: string): Promise<Reminder[]> {
        // Validate inputs
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }
        if (!status) {
            throw new Error('Status is required');
        }

        try {
            const pool = await poolPromise as Pool;
            const client = await pool.connect();
            
            try {
                const query = `
                    SELECT * FROM sp_get_reminders_by_status($1::uuid, $2::varchar(20))
                `;
                
                const result = await client.query(query, [agentId, status]);
                return result.rows.map(row => this.mapDatabaseRowToReminder(row));
            } finally {
                client.release();
            }
        } catch (error: unknown) {
            console.error('Error fetching reminders by status:', error);
            throw error;
        }
    }

    /** Get birthday reminders */
    public async getBirthdayReminders(agentId: string): Promise<BirthdayReminder[]> {
        // Validate agentId
        if (!agentId || !this.isValidUUID(agentId)) {
            throw new Error('Valid Agent ID is required');
        }

        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT 
                    client_id,
                    first_name,
                    last_name,
                    phone,
                    email,
                    date_of_birth,
                    age
                FROM sp_get_today_birthday_reminders($1::uuid)
            `;
            
            const result = await client.query(query, [agentId]);
            return result.rows.map(row => ({
                ClientId: row.client_id,
                FirstName: row.first_name || '',
                Surname: row.last_name || '',
                LastName: row.last_name || '',
                PhoneNumber: row.phone || '',
                Email: row.email || '',
                DateOfBirth: this.formatDateToISOString(row.date_of_birth),
                Age: row.age || 0
            }));
        } catch (error) {
            console.error('Error fetching birthday reminders:', error);
            // Return empty array instead of throwing to prevent frontend crashes
            return [];
        } finally {
            client.release();
        }
    }

    /** Get policy expiry reminders */
    public async getPolicyExpiryReminders(agentId: string, daysAhead: number = 30): Promise<PolicyExpiryReminder[]> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT 
                    policy_id,
                    client_id,
                    policy_name,
                    policy_type,
                    company_name,
                    end_date,
                    first_name,
                    last_name,
                    phone,
                    email,
                    days_until_expiry
                FROM sp_get_policy_expiry_reminders($1::uuid, $2::integer)
            `;
            
            const result = await client.query(query, [agentId, daysAhead]);
            return result.rows.map(row => ({
                PolicyId: row.policy_id,
                ClientId: row.client_id,
                PolicyName: row.policy_name || '',
                PolicyType: row.policy_type || '',
                CompanyName: row.company_name || '',
                EndDate: this.formatDateToISOString(row.end_date),
                FirstName: row.first_name || '',
                Surname: row.last_name || '',
                PhoneNumber: row.phone || '',
                Email: row.email || '',
                DaysUntilExpiry: row.days_until_expiry || 0
            }));
        } catch (error) {
            console.error('Error fetching policy expiry reminders:', error);
            // Return empty array instead of throwing to prevent frontend crashes
            return [];
        } finally {
            client.release();
        }
    }

    /** Validate phone number */
    public async validatePhoneNumber(phoneNumber: string, countryCode: string = '+254'): Promise<PhoneValidationResult> {
        const pool = await poolPromise as Pool;
        const client = await pool.connect();
        
        try {
            const query = `
                SELECT * FROM sp_validate_phone_number($1::varchar(50), $2::varchar(5))
            `;
            
            const result = await client.query(query, [phoneNumber, countryCode]);
            const row = result.rows[0];
            
            return {
                IsValid: row.is_valid,
                FormattedNumber: row.formatted_number,
                ValidationMessage: row.validation_message
            };
        } finally {
            client.release();
        }
    }

    // ADDED: Helper method to validate reminder types
    private isValidReminderType(type: string): boolean {
        const validTypes = [
            'Call',
            'Visit', 
            'Policy Expiry',
            'Maturing Policy',
            'Birthday',
            'Holiday',
            'Custom',
            'Appointment'
        ];
        return validTypes.includes(type);
    }

    // PostgreSQL time validation method
    private validateAndFormatPostgreSQLTime(timeString: string | null | undefined): string | null {
        console.log('🕐 Backend: Validating PostgreSQL time:', timeString, typeof timeString);
        
        if (!timeString || timeString === 'null' || timeString === 'undefined') {
            console.log('🕐 Backend: No valid time provided, returning null');
            return null;
        }
        
        let cleanTime = timeString.toString().trim();
        console.log('🕐 Backend: Cleaned time:', cleanTime);
        
        try {
            // Format 1: Already HH:MM:SS
            if (/^\d{2}:\d{2}:\d{2}$/.test(cleanTime)) {
                const [h, m, s] = cleanTime.split(':').map(Number);
                if (h >= 0 && h <= 23 && m >= 0 && m <= 59 && s >= 0 && s <= 59) {
                    console.log('🕐 Backend: Valid HH:MM:SS format');
                    return cleanTime;
                }
                throw new Error('Invalid time ranges');
            }
            
            // Format 2: HH:MM
            if (/^\d{1,2}:\d{2}$/.test(cleanTime)) {
                const [h, m] = cleanTime.split(':').map(Number);
                if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
                    const formatted = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:00`;
                    console.log('🕐 Backend: Converted HH:MM to HH:MM:SS:', cleanTime, '->', formatted);
                    return formatted;
                }
                throw new Error('Invalid time ranges for HH:MM');
            }
            
            // Format 3: Try parsing as ISO datetime and extract time
            if (cleanTime.includes('T') || cleanTime.includes('-')) {
                const date = new Date(cleanTime);
                if (!isNaN(date.getTime())) {
                    const hours = date.getUTCHours().toString().padStart(2, '0');
                    const minutes = date.getUTCMinutes().toString().padStart(2, '0');
                    const seconds = date.getUTCSeconds().toString().padStart(2, '0');
                    const formatted = `${hours}:${minutes}:${seconds}`;
                    console.log('🕐 Backend: Extracted time from datetime:', cleanTime, '->', formatted);
                    return formatted;
                }
            }
            
            // Format 4: Try creating a date with the time
            const testDate = new Date(`1970-01-01T${cleanTime}`);
            if (!isNaN(testDate.getTime())) {
                const hours = testDate.getUTCHours().toString().padStart(2, '0');
                const minutes = testDate.getUTCMinutes().toString().padStart(2, '0');
                const seconds = testDate.getUTCSeconds().toString().padStart(2, '0');
                const formatted = `${hours}:${minutes}:${seconds}`;
                console.log('🕐 Backend: Parsed with date constructor:', cleanTime, '->', formatted);
                return formatted;
            }
            
            throw new Error(`Cannot parse time format: ${cleanTime}`);
            
        } catch (error: unknown) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown validation error';
            console.error('🕐 Backend: Time validation failed:', errorMessage);
            console.error('🕐 Backend: Original input was:', timeString);
            
            console.log('🕐 Backend: Returning null due to validation failure');
            return null;
        }
    }

    /** Map database row to Reminder object */
    private mapDatabaseRowToReminder(row: any): Reminder {
        return {
            ReminderId: row.reminder_id,
            ClientId: row.client_id,
            AppointmentId: row.appointment_id,
            AgentId: row.agent_id,
            ReminderType: row.reminder_type,
            Title: row.title,
            Description: row.description,
            ReminderDate: this.formatDateToISOString(row.reminder_date),
            ReminderTime: row.reminder_time,
            ClientName: row.client_name,
            Priority: row.priority,
            Status: row.status,
            EnableSMS: row.enable_sms,
            EnableWhatsApp: row.enable_whatsapp,
            EnablePushNotification: row.enable_push_notification,
            AdvanceNotice: row.advance_notice,
            CustomMessage: row.custom_message,
            AutoSend: row.auto_send,
            Notes: row.notes,
            CreatedDate: this.formatDateTimeToISOString(row.created_date),
            ModifiedDate: this.formatDateTimeToISOString(row.modified_date),
            CompletedDate: row.completed_date ? this.formatDateTimeToISOString(row.completed_date) : undefined,
            // Handle missing computed fields gracefully
            ClientPhone: row.client_phone || '',
            ClientEmail: row.client_email || '',
            FullClientName: row.full_client_name || row.client_name || ''
        };
    }

    /** Map database row to ReminderSettings object */
    private mapDatabaseRowToReminderSettings(row: any): ReminderSettings {
        return {
            ReminderSettingId: row.reminder_setting_id,
            AgentId: row.agent_id,
            ReminderType: row.reminder_type,
            IsEnabled: row.is_enabled,
            DaysBefore: row.days_before,
            TimeOfDay: row.time_of_day,
            RepeatDaily: row.repeat_daily,
            CreatedDate: this.formatDateTimeToISOString(row.created_date),
            ModifiedDate: this.formatDateTimeToISOString(row.modified_date)
        };
    }

    /** Format date to ISO string */
    private formatDateToISOString(date: any): string {
        if (!date) return '';
        
        if (typeof date === 'string') {
            if (date.includes('-')) {
                return date.split('T')[0];
            }
            return date;
        }
        
        if (date instanceof Date) {
            return date.toISOString().split('T')[0];
        }
        
        return String(date);
    }

    /** Format datetime to ISO string */
    private formatDateTimeToISOString(datetime: any): string {
        if (!datetime) return '';
        
        if (typeof datetime === 'string') {
            return datetime;
        }
        
        if (datetime instanceof Date) {
            return datetime.toISOString();
        }
        
        return String(datetime);
    }
}