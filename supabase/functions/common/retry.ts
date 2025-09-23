/**
 * Retry Policy Implementation
 * Provides configurable retry strategies with exponential backoff and jitter
 */

export interface RetryConfig {
  maxRetries: number;
  baseDelay: number;         // Initial delay in milliseconds
  maxDelay: number;          // Maximum delay in milliseconds
  backoffMultiplier: number; // Multiplier for exponential backoff
  jitter: boolean;           // Add randomness to delay
  retryableErrors?: (error: Error) => boolean; // Function to determine if error is retryable
}

export interface RetryResult<T> {
  success: boolean;
  result?: T;
  error?: Error;
  attempts: number;
  totalDelay: number;
}

export class RetryPolicy {
  constructor(private config: RetryConfig) {
    // Validate configuration
    if (config.maxRetries < 0) {
      throw new Error("maxRetries must be non-negative");
    }
    if (config.baseDelay <= 0) {
      throw new Error("baseDelay must be positive");
    }
    if (config.maxDelay < config.baseDelay) {
      throw new Error("maxDelay must be >= baseDelay");
    }
    if (config.backoffMultiplier <= 1) {
      throw new Error("backoffMultiplier must be > 1");
    }
  }

  /**
   * Execute operation with retry policy
   */
  async execute<T>(operation: () => Promise<T>): Promise<T> {
    let lastError: Error;
    let totalDelay = 0;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          const delay = this.calculateDelay(attempt - 1);
          totalDelay += delay;
          await this.sleep(delay);
        }

        const result = await operation();
        return result;
      } catch (error) {
        lastError = error as Error;

        // Check if error is retryable
        if (this.config.retryableErrors && !this.config.retryableErrors(lastError)) {
          throw lastError;
        }

        // If this was the last attempt, throw the error
        if (attempt === this.config.maxRetries) {
          throw lastError;
        }
      }
    }

    // This should never be reached, but TypeScript needs it
    throw lastError!;
  }

  /**
   * Execute operation and return detailed result
   */
  async executeWithResult<T>(operation: () => Promise<T>): Promise<RetryResult<T>> {
    let lastError: Error | undefined;
    let totalDelay = 0;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          const delay = this.calculateDelay(attempt - 1);
          totalDelay += delay;
          await this.sleep(delay);
        }

        const result = await operation();
        return {
          success: true,
          result,
          attempts: attempt + 1,
          totalDelay,
        };
      } catch (error) {
        lastError = error as Error;

        // Check if error is retryable
        if (this.config.retryableErrors && !this.config.retryableErrors(lastError)) {
          return {
            success: false,
            error: lastError,
            attempts: attempt + 1,
            totalDelay,
          };
        }

        // If this was the last attempt, return failure
        if (attempt === this.config.maxRetries) {
          return {
            success: false,
            error: lastError,
            attempts: attempt + 1,
            totalDelay,
          };
        }
      }
    }

    // This should never be reached
    return {
      success: false,
      error: lastError!,
      attempts: this.config.maxRetries + 1,
      totalDelay,
    };
  }

  /**
   * Calculate delay for given retry attempt
   */
  private calculateDelay(retryAttempt: number): number {
    // Exponential backoff: baseDelay * (backoffMultiplier ^ retryAttempt)
    let delay = this.config.baseDelay * Math.pow(this.config.backoffMultiplier, retryAttempt);

    // Cap at maxDelay
    delay = Math.min(delay, this.config.maxDelay);

    // Add jitter if enabled
    if (this.config.jitter) {
      // Add random jitter of ±25%
      const jitterRange = delay * 0.25;
      const jitter = (Math.random() - 0.5) * 2 * jitterRange;
      delay += jitter;
    }

    return Math.max(0, delay);
  }

  /**
   * Sleep for specified milliseconds
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Get configuration
   */
  getConfig(): RetryConfig {
    return { ...this.config };
  }
}

/**
 * Common retry policies for different scenarios
 */
export class RetryPolicies {
  /**
   * Fast retry for transient network issues
   */
  static fast(): RetryPolicy {
    return new RetryPolicy({
      maxRetries: 3,
      baseDelay: 100,
      maxDelay: 1000,
      backoffMultiplier: 2,
      jitter: true,
      retryableErrors: (error: Error) => {
        // Retry on network errors, timeouts, and 5xx status codes
        const message = error.message.toLowerCase();
        return message.includes('network') ||
               message.includes('timeout') ||
               message.includes('connection') ||
               message.includes('503') ||
               message.includes('502') ||
               message.includes('504');
      },
    });
  }

  /**
   * Standard retry for API calls
   */
  static standard(): RetryPolicy {
    return new RetryPolicy({
      maxRetries: 5,
      baseDelay: 1000,
      maxDelay: 30000,
      backoffMultiplier: 2,
      jitter: true,
      retryableErrors: (error: Error) => {
        const message = error.message.toLowerCase();
        return message.includes('network') ||
               message.includes('timeout') ||
               message.includes('connection') ||
               message.includes('503') ||
               message.includes('502') ||
               message.includes('504') ||
               message.includes('429'); // Rate limiting
      },
    });
  }

  /**
   * Aggressive retry for critical operations
   */
  static aggressive(): RetryPolicy {
    return new RetryPolicy({
      maxRetries: 10,
      baseDelay: 500,
      maxDelay: 60000,
      backoffMultiplier: 1.5,
      jitter: true,
      retryableErrors: (error: Error) => {
        const message = error.message.toLowerCase();
        // Retry almost everything except authentication and validation errors
        return !message.includes('401') &&
               !message.includes('403') &&
               !message.includes('400') &&
               !message.includes('invalid') &&
               !message.includes('unauthorized');
      },
    });
  }

  /**
   * Conservative retry for operations that should fail fast
   */
  static conservative(): RetryPolicy {
    return new RetryPolicy({
      maxRetries: 2,
      baseDelay: 2000,
      maxDelay: 10000,
      backoffMultiplier: 3,
      jitter: false,
      retryableErrors: (error: Error) => {
        const message = error.message.toLowerCase();
        // Only retry on clear network/server issues
        return message.includes('503') ||
               message.includes('502') ||
               message.includes('504') ||
               message.includes('connection reset');
      },
    });
  }

  /**
   * Custom retry policy for FCM operations
   */
  static fcm(): RetryPolicy {
    return new RetryPolicy({
      maxRetries: 3,
      baseDelay: 1000,
      maxDelay: 8000,
      backoffMultiplier: 2,
      jitter: true,
      retryableErrors: (error: Error) => {
        const message = error.message.toLowerCase();
        // Retry on server errors and rate limits, but not on auth or invalid token errors
        return message.includes('503') ||
               message.includes('502') ||
               message.includes('504') ||
               message.includes('500') ||
               message.includes('429') ||
               message.includes('network') ||
               message.includes('timeout');
      },
    });
  }
}

/**
 * Utility function for quick retries
 */
export async function withRetry<T>(
  operation: () => Promise<T>,
  policy: RetryPolicy = RetryPolicies.standard()
): Promise<T> {
  return await policy.execute(operation);
}

/**
 * Utility function for conditional retries
 */
export async function retryIf<T>(
  operation: () => Promise<T>,
  condition: (error: Error) => boolean,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  const policy = new RetryPolicy({
    maxRetries,
    baseDelay,
    maxDelay: baseDelay * 10,
    backoffMultiplier: 2,
    jitter: true,
    retryableErrors: condition,
  });

  return await policy.execute(operation);
}