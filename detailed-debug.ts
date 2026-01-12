// detailed-debug.ts - Find the exact problematic route pattern
// Run: npx ts-node detailed-debug.ts

import express from 'express';

async function detailedTest() {
  console.log('🔍 Starting detailed route pattern analysis...\n');

  const app = express();
  const routers = [
    { name: 'agentRoutes', path: './src/routes/agent.routes', mount: '/api/agents' },
    { name: 'analyticsRoutes', path: './src/routes/analytics.routes', mount: '/api/analytics' },
    { name: 'appointmentRoutes', path: './src/routes/appointment', mount: '/api/appointments' },
    { name: 'clientRoutes', path: './src/routes/clients.routes', mount: '/api/clients' },
    { name: 'policyRoutes', path: './src/routes/policy.routes', mount: '/api/policies' },
    { name: 'reminderRoutes', path: './src/routes/reminder.routes', mount: '/api/reminders' },
    { name: 'notesRoutes', path: './src/routes/notes.routes', mount: '/api/notes' },
    { name: 'searchRoutes', path: './src/routes/search.routes', mount: '/api/search' },
    { name: 'utilityRoutes', path: './src/routes/utility.routes', mount: '/api/utility' },
    { name: 'autocompleteRoutes', path: './src/routes/autocomplete.routes', mount: '/api/autocomplete' },
    { name: 'prospectRoutes', path: './src/routes/prospect.routes', mount: '/api/prospects' },
  ];

  let successCount = 0;
  
  // Test mounting routers one by one, accumulating them
  for (let i = 0; i < routers.length; i++) {
    const testApp = express();
    
    try {
      console.log(`\n📦 Mounting routers 0 through ${i}...`);
      
      // Mount all routers up to index i
      for (let j = 0; j <= i; j++) {
        const routerInfo = routers[j];
        const router = (await import(routerInfo.path)).default;
        console.log(`  ✓ Mounting ${routerInfo.name} at ${routerInfo.mount}`);
        testApp.use(routerInfo.mount, router);
      }
      
      successCount = i + 1;
      console.log(`✅ Success with ${successCount} router(s) mounted`);
      
    } catch (error: any) {
      console.error(`\n❌ FAILURE when mounting router #${i}: ${routers[i].name}`);
      console.error(`   Mount path: ${routers[i].mount}`);
      console.error(`   Error: ${error.message}`);
      
      console.log(`\n🎯 THE PROBLEM:`);
      console.log(`   Router #${i} (${routers[i].name}) conflicts with previously mounted routers`);
      console.log(`\n   Successfully mounted routers (0-${i-1}):`);
      for (let k = 0; k < i; k++) {
        console.log(`   ${k}. ${routers[k].name} at ${routers[k].mount}`);
      }
      console.log(`\n   Failed to mount:`);
      console.log(`   ${i}. ${routers[i].name} at ${routers[i].mount} ⚠️`);
      
      // Now let's try to extract route patterns from the problematic router
      console.log(`\n🔬 Analyzing ${routers[i].name} route patterns...`);
      try {
        const router = (await import(routers[i].path)).default;
        const stack = (router as any).stack;
        
        if (stack && Array.isArray(stack)) {
          console.log(`\n   Routes defined in ${routers[i].name}:`);
          stack.forEach((layer: any, idx: number) => {
            if (layer.route) {
              const methods = Object.keys(layer.route.methods).join(', ').toUpperCase();
              const path = layer.route.path;
              console.log(`   ${idx + 1}. ${methods} ${routers[i].mount}${path}`);
              
              // Check for problematic patterns
              if (path.includes('//') || path.includes('/:/:') || path.match(/:\w*:/)) {
                console.log(`      ⚠️  SUSPICIOUS PATTERN DETECTED!`);
              }
            }
          });
        }
      } catch (e) {
        console.log('   Could not analyze route patterns');
      }
      
      break;
    }
  }

  if (successCount === routers.length) {
    console.log(`\n✅ All ${successCount} routers mounted successfully!`);
    console.log(`\nThe issue is likely in how they're mounted together in the actual server.ts`);
  }
}

detailedTest().catch(console.error);