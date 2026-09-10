// Supabase Edge Function: Process Expired Account Deletions
// To be called daily by a free cron service (e.g., cron-job.org)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify the request is authorized (optional: add a secret key check)
    const authHeader = req.headers.get('Authorization')
    const cronSecret = Deno.env.get('CRON_SECRET')
    
    // Optional: Secure the endpoint with a secret
    if (cronSecret) {
      const providedSecret = req.headers.get('X-Cron-Secret')
      if (providedSecret !== cronSecret) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          { 
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Create Supabase client with service role key (bypasses RLS)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Call the database function to process expired deletions
    const { data, error } = await supabase.rpc('process_expired_deletion_requests')

    if (error) {
      console.error('Error processing deletions:', error)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: error.message 
        }),
        { 
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('Successfully processed deletions:', data)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Deletion processing completed',
        result: data
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: err.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
