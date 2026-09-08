// Middleware to ensure CORS headers for all API routes
export const onRequest: PagesFunction = async (context) => {
  const response = await context.next();
  
  // Add CORS headers
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
  
  return response;
};
