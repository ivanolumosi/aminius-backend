// db.ts
import { Pool, PoolClient } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// const dbConfig = {
//     user: process.env.DB_USER as string,
//     password: process.env.DB_PASSWORD as string,
//     host: process.env.DB_SERVER as string,
//     database: process.env.DB_DATABASE as string,
//     port: 5432,
//     max: 10, 
//         min: 0,  
//     idleTimeoutMillis: 30000,
//     ssl: {
//         require: true,
//         rejectUnauthorized: false
//     }
// };

const dbConfig = {
    connectionString: process.env.DATABASE_URL as string,
    ssl: {
        require: true,
        rejectUnauthorized: false
    }
};

let pool: Pool | null = null;

export async function getDbPool(): Promise<Pool> {
    try {
        if (!pool) {
            pool = new Pool(dbConfig);
            
            // Test the connection
            const client = await pool.connect();
            console.log('✅ Database connected successfully');
            client.release();
        }
        return pool;
    } catch (error) {
        console.error('❌ Database connection failed:', error);
        throw error;
    }
}

export const poolPromise = getDbPool();

// Helper function for queries (optional but useful)
export async function query(text: string, params?: any[]): Promise<any> {
    const pool = await getDbPool();
    const result = await pool.query(text, params);
    return result;
}

export default {
    Pool,
    query
};