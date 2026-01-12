import express, { Request, Response, NextFunction } from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import bodyParser from 'body-parser';
import agentRoutes from './src/routes/agent.routes';
import analyticsRoutes from './src/routes/analytics.routes';
import clientRoutes from './src/routes/clients.routes';
import appointmentRoutes from './src/routes/appointment';
import policyRoutes from './src/routes/policy.routes';
import reminderRoutes from './src/routes/reminder.routes';
import notesRoutes from './src/routes/notes.routes';
import utilityRoutes from './src/routes/utility.routes';
import searchRoutes from './src/routes/search.routes';
import autocompleteRoutes from './src/routes/autocomplete.routes';
import prospectRoutes from './src/routes/prospect.routes';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

const corsOptions = {
  origin: [
    'https://aminius-app.netlify.app',
    'http://localhost:3000'
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

app.use(cors(corsOptions));
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// API routes
app.use('/api', agentRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/policies', policyRoutes);
app.use('/api/reminders', reminderRoutes);
app.use('/api/notes', notesRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/utility', utilityRoutes);
app.use('/api/autocomplete', autocompleteRoutes);
app.use('/api', prospectRoutes);

// Root route
app.get('/', (_req: Request, res: Response) => {
  res.send('🚀 Welcome to Aminius API!');
});

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ message: 'Route not found' });
});

// Error handling middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Server error:', err);
  res.status(500).json({
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'production' ? undefined : err.message
  });
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});