/**
 * Circuit Breaker Pattern Implementation
 * Prevents cascading failures by monitoring and breaking failed operations
 */

export interface CircuitBreakerConfig {
  failureThreshold: number;    // Number of failures before opening circuit
  recoveryTimeout: number;     // Time to wait before attempting recovery (ms)
  monitoringPeriod: number;    // Time window for failure counting (ms)
  successThreshold?: number;   // Successful calls needed to close circuit (default: 1)
}

export enum CircuitState {
  CLOSED = "closed",     // Normal operation
  OPEN = "open",         // Circuit is open, failing fast
  HALF_OPEN = "half_open" // Testing if service has recovered
}

export interface CircuitBreakerState {
  state: CircuitState;
  failureCount: number;
  successCount: number;
  lastFailureTime: number;
  lastSuccessTime: number;
  nextAttemptTime: number;
}

export class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failureCount: number = 0;
  private successCount: number = 0;
  private lastFailureTime: number = 0;
  private lastSuccessTime: number = 0;
  private nextAttemptTime: number = 0;
  private failureWindow: number[] = [];

  constructor(private config: CircuitBreakerConfig) {
    this.config.successThreshold = config.successThreshold || 1;
  }

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.shouldReject()) {
      throw new Error("Circuit breaker is OPEN - failing fast");
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private shouldReject(): boolean {
    const now = Date.now();

    switch (this.state) {
      case CircuitState.CLOSED:
        return false;

      case CircuitState.OPEN:
        if (now >= this.nextAttemptTime) {
          this.state = CircuitState.HALF_OPEN;
          this.successCount = 0;
          return false;
        }
        return true;

      case CircuitState.HALF_OPEN:
        return false;
    }
  }

  private onSuccess(): void {
    this.lastSuccessTime = Date.now();
    this.cleanupOldFailures();

    switch (this.state) {
      case CircuitState.CLOSED:
        this.resetFailureCount();
        break;

      case CircuitState.HALF_OPEN:
        this.successCount++;
        if (this.successCount >= this.config.successThreshold!) {
          this.state = CircuitState.CLOSED;
          this.resetFailureCount();
        }
        break;
    }
  }

  private onFailure(): void {
    const now = Date.now();
    this.lastFailureTime = now;
    this.failureWindow.push(now);
    this.cleanupOldFailures();

    switch (this.state) {
      case CircuitState.CLOSED:
        if (this.failureWindow.length >= this.config.failureThreshold) {
          this.openCircuit();
        }
        break;

      case CircuitState.HALF_OPEN:
        this.openCircuit();
        break;
    }
  }

  private openCircuit(): void {
    this.state = CircuitState.OPEN;
    this.nextAttemptTime = Date.now() + this.config.recoveryTimeout;
  }

  private resetFailureCount(): void {
    this.failureCount = 0;
    this.failureWindow = [];
  }

  private cleanupOldFailures(): void {
    const cutoff = Date.now() - this.config.monitoringPeriod;
    this.failureWindow = this.failureWindow.filter(time => time > cutoff);
  }

  getState(): CircuitBreakerState {
    return {
      state: this.state,
      failureCount: this.failureWindow.length,
      successCount: this.successCount,
      lastFailureTime: this.lastFailureTime,
      lastSuccessTime: this.lastSuccessTime,
      nextAttemptTime: this.nextAttemptTime,
    };
  }

  reset(): void {
    this.state = CircuitState.CLOSED;
    this.resetFailureCount();
    this.successCount = 0;
    this.lastFailureTime = 0;
    this.lastSuccessTime = 0;
    this.nextAttemptTime = 0;
  }

  // Manual controls for testing/emergency situations
  forceOpen(): void {
    this.state = CircuitState.OPEN;
    this.nextAttemptTime = Date.now() + this.config.recoveryTimeout;
  }

  forceClose(): void {
    this.state = CircuitState.CLOSED;
    this.resetFailureCount();
    this.successCount = 0;
  }

  forceClosed(): void {
    this.forceClose();
  }
}