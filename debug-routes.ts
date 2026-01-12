// debug-routes.ts - Run this to find the problematic route
// Place this in your root directory and run: npx ts-node debug-routes.ts

import express from 'express';

// Import each router one by one to isolate the problem
async function testRouters() {
  const results: any = {};
  
  const routers = [
    { name: 'agentRoutes', path: './src/routes/agent.routes' },
    { name: 'analyticsRoutes', path: './src/routes/analytics.routes' },
    { name: 'appointmentRoutes', path: './src/routes/appointment' },
    { name: 'clientRoutes', path: './src/routes/clients.routes' },
    { name: 'policyRoutes', path: './src/routes/policy.routes' },
    { name: 'reminderRoutes', path: './src/routes/reminder.routes' },
    { name: 'notesRoutes', path: './src/routes/notes.routes' },
    { name: 'searchRoutes', path: './src/routes/search.routes' },
    { name: 'utilityRoutes', path: './src/routes/utility.routes' },
    { name: 'autocompleteRoutes', path: './src/routes/autocomplete.routes' },
    { name: 'prospectRoutes', path: './src/routes/prospect.routes' },
  ];

  for (const routerInfo of routers) {
    const app = express();
    try {
      console.log(`\n🔍 Testing ${routerInfo.name}...`);
      const router = (await import(routerInfo.path)).default;
      
      // Try to mount the router - this is where the error occurs
      app.use('/test', router);
      
      console.log(`✅ ${routerInfo.name} - OK`);
      results[routerInfo.name] = 'OK';
    } catch (error: any) {
      console.error(`❌ ${routerInfo.name} - FAILED`);
      console.error(`   Error: ${error.message}`);
      results[routerInfo.name] = 'FAILED';
      
      // Stop at first failure to make it easier to identify
      console.log('\n🎯 FOUND THE PROBLEM!');
      console.log(`The issue is in: ${routerInfo.name}`);
      console.log(`File: ${routerInfo.path}`);
      break;
    }
  }

  console.log('\n📊 Results:');
  console.log(results);
}

testRouters().catch(console.error);