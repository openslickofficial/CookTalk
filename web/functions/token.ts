/**
 * Cloudflare Pages Function - LiveKit Token Generator
 * 
 * This edge function generates JWT tokens for LiveKit rooms.
 * Zero cold start, deployed alongside the frontend.
 * 
 * Endpoint: https://your-app.pages.dev/token
 * Method: POST
 * Body: { "room_name": "string", "participant_name": "string" }
 * Response: { "token": "string" }
 */

import { sign } from 'jsonwebtoken';

interface Env {
  LIVEKIT_API_KEY: string;
  LIVEKIT_API_SECRET: string;
}

interface TokenRequest {
  room_name: string;
  participant_name: string;
}

export const onRequest: PagesFunction<Env> = async (context) => {
  const { request, env } = context;
  
  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      },
    });
  }

  // Only allow POST requests
  if (request.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }

  try {
    // Parse request body
    const body = await request.json() as TokenRequest;
    const { room_name, participant_name } = body;

    // Validate required fields
    if (!room_name || !participant_name) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields',
          required: ['room_name', 'participant_name'],
        }),
        { 
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    // Validate environment variables
    if (!env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET) {
      console.error('Missing LiveKit credentials in environment');
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { 
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    // Generate JWT token
    const now = Math.floor(Date.now() / 1000);
    const token = sign(
      {
        video: {
          roomJoin: true,
          room: room_name,
        },
        name: participant_name,
        iat: now,
        exp: now + 3600, // 1 hour expiration
        nbf: now - 10, // Valid from 10 seconds ago (clock skew tolerance)
      },
      env.LIVEKIT_API_SECRET,
      {
        header: {
          alg: 'HS256',
          typ: 'JWT',
          kid: env.LIVEKIT_API_KEY,
        },
      }
    );

    // Return token
    return new Response(
      JSON.stringify({ 
        token,
        expires_in: 3600,
        room_name,
        participant_name,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-store, no-cache, must-revalidate',
        },
      }
    );

  } catch (error) {
    console.error('Token generation error:', error);
    
    // Check if it's a JSON parse error
    if (error instanceof SyntaxError) {
      return new Response(
        JSON.stringify({ 
          error: 'Invalid JSON in request body',
        }),
        { 
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    // Generic error response
    return new Response(
      JSON.stringify({ 
        error: 'Token generation failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      { 
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
};
