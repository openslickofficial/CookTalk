/**
 * Cloudflare Pages Function - LiveKit Token Generator (Mobile-Compatible)
 * 
 * This edge function generates JWT tokens for LiveKit rooms.
 * Supports both GET (query params) and POST (JSON body) for compatibility.
 * 
 * Endpoint: https://your-app.pages.dev/api/token
 * 
 * GET: /api/token?room=X&name=Y
 * POST: /api/token with body { "room_name": "X", "participant_name": "Y" }
 * 
 * Response: { "token": "string", "url": "wss://..." }
 */

import { sign } from 'jsonwebtoken';

interface Env {
  LIVEKIT_API_KEY: string;
  LIVEKIT_API_SECRET: string;
  LIVEKIT_URL?: string;
}

export const onRequest: PagesFunction<Env> = async (context) => {
  const { request, env } = context;
  
  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      },
    });
  }

  try {
    let roomName: string;
    let participantName: string;

    // Support both GET and POST
    if (request.method === 'GET') {
      const url = new URL(request.url);
      roomName = url.searchParams.get('room') || '';
      participantName = url.searchParams.get('name') || '';
    } else if (request.method === 'POST') {
      const body = await request.json() as { room_name?: string; participant_name?: string };
      roomName = body.room_name || '';
      participantName = body.participant_name || '';
    } else {
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

    // Validate required fields
    if (!roomName || !participantName) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields',
          required: request.method === 'GET' 
            ? 'Query params: room and name' 
            : 'JSON body: room_name and participant_name',
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
          room: roomName,
        },
        name: participantName,
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

    // Get LiveKit URL from environment or use default
    const livekitUrl = env.LIVEKIT_URL || 'wss://cooltalk-9ik3u4wt.livekit.cloud';

    // Return token and URL (mobile-compatible format)
    return new Response(
      JSON.stringify({ 
        token,
        url: livekitUrl,
        expires_in: 3600,
        room: roomName,
        participant: participantName,
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
    
    // Check if it's a JSON parse error (only for POST)
    if (error instanceof SyntaxError && request.method === 'POST') {
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
