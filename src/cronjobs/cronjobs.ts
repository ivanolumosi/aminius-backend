// import cron from "node-cron";
// import emailService from "./../nodemailer/emailservice";  // your EmailService file
// import { getDbPool } from "../../db";

// // ========================
// // Utility Functions
// // ========================

// // Fetch all active agents
// async function getAllActiveAgents() {
//     const pool = await getDbPool();
//     const result = await pool.query(
//         `SELECT agentid, email, firstname, lastname FROM agent WHERE isactive = true`
//     );
//     return result.rows;
// }

// // Fetch today's appointments for an agent
// async function getTodayAppointments(agentId: string) {
//     const pool = await getDbPool();
//     const result = await pool.query(
//         'SELECT * FROM sp_GetTodayAppointments($1)',
//         [agentId]
//     );
    
//     return result.rows;
// }

// // Combine appointment date + time and convert to Nairobi time
// function formatAppointmentTime(appointmentDateStr: string, startTimeStr: string) {
//     if (!appointmentDateStr || !startTimeStr) return "Invalid Date";
    
//     const appointmentDate = new Date(appointmentDateStr);
//     const startTime = new Date(startTimeStr); // from DB, usually timestamp
    
//     // If the startTime is just time (without date), combine it with appointmentDate
//     const combined = new Date(
//         appointmentDate.getFullYear(),
//         appointmentDate.getMonth(),
//         appointmentDate.getDate(),
//         startTime.getHours(),
//         startTime.getMinutes(),
//         startTime.getSeconds()
//     );
    
//     return combined.toLocaleTimeString("en-KE", {
//         hour: "2-digit",
//         minute: "2-digit",
//         hour12: false,
//         timeZone: "Africa/Nairobi",
//     });
// }

// // Send email to a single agent with their appointments
// async function sendAgentAppointments(agent: any) {
//     const appointments = await getTodayAppointments(agent.agentid);
    
//     if (!appointments || appointments.length === 0) {
//         console.log(`📭 No appointments for ${agent.email} today.`);
//         return;
//     }
    
//     const appointmentList = appointments.map((a: any) => {
//         const clientName = a.clientname || a.client_name || "Unknown Client";
//         const appointmentTime = formatAppointmentTime(a.appointmentdate || a.appointment_date, a.starttime || a.start_time);
//         return `<li>${clientName} at ${appointmentTime}</li>`;
//     }).join("");
    
//     const htmlContent = `
//         <h3>Today's Appointments</h3>
//         <ul>${appointmentList}</ul>
//     `;
    
//     try {
//         await emailService.sendMail(
//             agent.email,
//             "Your Appointments for Today",
//             "Please see your appointments below.",
//             htmlContent
//         );
//         console.log(`✅ Appointment email sent to ${agent.email}`);
//     } catch (error) {
//         console.error(`❌ Failed to send email to ${agent.email}:`, error);
//     }
// }

// // ========================
// // Cron Jobs
// // ========================

// // 12:05 AM Nairobi time
// cron.schedule(
//     "5 0 * * *",
//     async () => {
//         console.log("⏰ Running 12:05 AM appointment email job...");
//         try {
//             const agents = await getAllActiveAgents();
//             for (const agent of agents) {
//                 await sendAgentAppointments(agent);
//             }
//         } catch (error) {
//             console.error("❌ Error in 12:05 AM cron job:", error);
//         }
//     },
//     { timezone: "Africa/Nairobi" }
// );

// // 8:00 AM Nairobi time
// cron.schedule(
//     "0 8 * * *",
//     async () => {
//         console.log("⏰ Running 8:00 AM appointment email job...");
//         try {
//             const agents = await getAllActiveAgents();
//             for (const agent of agents) {
//                 await sendAgentAppointments(agent);
//             }
//         } catch (error) {
//             console.error("❌ Error in 8:00 AM cron job:", error);
//         }
//     },
//     { timezone: "Africa/Nairobi" }
// );

// // ========================
// // Optional: Test Cron (every minute)
// // ========================
// // cron.schedule("* * * * *", async () => {
// //     console.log("🔔 Running test cron...");
// //     try {
// //         const agents = await getAllActiveAgents();
// //         for (const agent of agents) {
// //             await sendAgentAppointments(agent);
// //         }
// //     } catch (error) {
// //         console.error("❌ Error in test cron job:", error);
// //     }
// // });

// export { getAllActiveAgents, getTodayAppointments, sendAgentAppointments };