/**
 * Error Handling Module
 * Provides consistent error responses and status codes
 */

export class ApiError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code?: string,
    public details?: any
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export class ValidationError extends ApiError {
  constructor(message: string, details?: any) {
    super(message, 400, 'VALIDATION_ERROR', details);
  }
}

export class AuthenticationError extends ApiError {
  constructor(message: string = 'Authentication required') {
    super(message, 401, 'AUTHENTICATION_ERROR');
  }
}

export class AuthorizationError extends ApiError {
  constructor(message: string = 'Insufficient permissions') {
    super(message, 403, 'AUTHORIZATION_ERROR');
  }
}

export class NotFoundError extends ApiError {
  constructor(resource: string) {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

export class RateLimitError extends ApiError {
  constructor(retryAfter?: number) {
    super('Rate limit exceeded', 429, 'RATE_LIMIT_EXCEEDED', { retry_after: retryAfter });
  }
}

export class ServerError extends ApiError {
  constructor(message: string = 'Internal server error', details?: any) {
    super(message, 500, 'SERVER_ERROR', details);
  }
}

export class ServiceUnavailableError extends ApiError {
  constructor(message: string = 'Service temporarily unavailable') {
    super(message, 503, 'SERVICE_UNAVAILABLE');
  }
}

/**
 * Create error response with CORS headers
 */
export function errorResponse(
  error: Error | ApiError,
  corsHeaders: Record<string, string> = {}
): Response {
  if (error instanceof ApiError) {
    const body = {
      error: {
        message: error.message,
        code: error.code,
        ...(error.details && { details: error.details }),
      },
    };
    
    const headers = {
      ...corsHeaders,
      "Content-Type": "application/json",
    };
    
    // Add retry-after header for rate limit errors
    if (error instanceof RateLimitError && error.details?.retry_after) {
      headers["Retry-After"] = String(error.details.retry_after);
    }
    
    return new Response(JSON.stringify(body), {
      status: error.statusCode,
      headers,
    });
  }
  
  // Generic error handling
  const body = {
    error: {
      message: "An unexpected error occurred",
      code: "INTERNAL_ERROR",
    },
  };
  
  return new Response(JSON.stringify(body), {
    status: 500,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

/**
 * Wrap async handler with error handling
 */
export function withErrorHandling(
  handler: (req: Request) => Promise<Response>,
  corsHeaders: Record<string, string> = {}
) {
  return async (req: Request): Promise<Response> => {
    try {
      return await handler(req);
    } catch (error) {
      return errorResponse(error as Error, corsHeaders);
    }
  };
}
