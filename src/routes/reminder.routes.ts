// =============================================
// FIXED REMINDER ROUTES - routes/reminder.routes.ts
// Resolved route conflicts causing path-to-regexp error
// =============================================

import { Router } from 'express';
import { RemindersController } from '../controllers/reminder.controller';

const router = Router();
const remindersController = new RemindersController();

// =============================================
// UTILITY ROUTES (Must come first)
// =============================================

// Validate phone number
// POST /api/reminders/validate-phone
router.post('/validate-phone', remindersController.validatePhoneNumber);

// =============================================
// AGENT-SPECIFIC ROUTES (Most specific patterns first)
// =============================================

// Statistics
router.get('/:agentId/statistics', remindersController.getReminderStatistics);

// Settings
router.get('/:agentId/settings', remindersController.getReminderSettings);
router.put('/:agentId/settings', remindersController.updateReminderSettings);

// Today's reminders
router.get('/:agentId/today', remindersController.getTodayReminders);

// Birthday reminders
router.get('/:agentId/birthdays', remindersController.getBirthdayReminders);

// Policy expiry reminders
router.get('/:agentId/policy-expiry', remindersController.getPolicyExpiryReminders);

// Reminders by type
router.get('/:agentId/type/:reminderType', remindersController.getRemindersByType);

// Reminders by status
router.get('/:agentId/status/:status', remindersController.getRemindersByStatus);

// =============================================
// REMINDER-SPECIFIC OPERATIONS (with both agentId and reminderId)
// =============================================

// Complete a reminder
router.post('/:agentId/:reminderId/complete', remindersController.completeReminder);

// Update a reminder
router.put('/:agentId/:reminderId', remindersController.updateReminder);

// Delete a reminder
router.delete('/:agentId/:reminderId', remindersController.deleteReminder);

// Get reminder by ID
router.get('/:agentId/:reminderId', remindersController.getReminderById);

// =============================================
// MAIN CRUD ROUTES (Must come after specific routes)
// =============================================

// Create a new reminder
router.post('/:agentId', remindersController.createReminder);

// Get all reminders with pagination and filters
router.get('/:agentId', remindersController.getAllReminders);

export default router;