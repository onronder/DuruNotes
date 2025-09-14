/**
 * Structured Logger Module
 * Provides consistent logging across all Edge Functions
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogContext {
  event: string;
  status?: string;
  [key: string]: any;
}

export class Logger {
  private readonly service: string;
  private readonly region: string;
  private readonly projectRef: string;

  constructor(service: string) {
    this.service = service;
    this.region = Deno.env.get("DENO_REGION") || "unknown";
    this.projectRef = Deno.env.get("SUPABASE_PROJECT_REF") || "unknown";
  }

  private formatLog(level: LogLevel, context: LogContext): string {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      service: this.service,
      edge_region: this.region,
      project_ref: this.projectRef,
      ...context,
    };
    return JSON.stringify(logEntry);
  }

  debug(event: string, data: Record<string, any> = {}): void {
    if (Deno.env.get("LOG_LEVEL") === "debug") {
      console.log(this.formatLog('debug', { event, ...data }));
    }
  }

  info(event: string, data: Record<string, any> = {}): void {
    console.log(this.formatLog('info', { event, status: 'success', ...data }));
  }

  warn(event: string, data: Record<string, any> = {}): void {
    console.warn(this.formatLog('warn', { event, status: 'warning', ...data }));
  }

  error(event: string, error: Error | string, data: Record<string, any> = {}): void {
    const errorData = error instanceof Error 
      ? { error_message: error.message, error_stack: error.stack }
      : { error_message: String(error) };
    
    console.error(this.formatLog('error', { 
      event, 
      status: 'error',
      ...errorData,
      ...data 
    }));
  }

  // Log performance metrics
  perf(event: string, startTime: number, data: Record<string, any> = {}): void {
    const duration_ms = Date.now() - startTime;
    this.info(event, { duration_ms, ...data });
  }
}
