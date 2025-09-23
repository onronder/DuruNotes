/**
 * Metrics Collection System
 * Provides counters, gauges, histograms for observability
 */

export interface MetricSnapshot {
  name: string;
  type: 'counter' | 'gauge' | 'histogram';
  value: number;
  timestamp: number;
  labels?: Record<string, string>;
}

export interface HistogramBucket {
  le: number;    // Less than or equal to
  count: number;
}

export interface HistogramMetric {
  buckets: HistogramBucket[];
  sum: number;
  count: number;
}

export class MetricsCollector {
  private counters = new Map<string, number>();
  private gauges = new Map<string, number>();
  private histograms = new Map<string, HistogramMetric>();
  private readonly defaultBuckets = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10];

  constructor(private readonly prefix: string = '') {}

  /**
   * Increment a counter metric
   */
  incrementCounter(name: string, value: number = 1, labels?: Record<string, string>): void {
    const metricName = this.getMetricName(name, labels);
    const current = this.counters.get(metricName) || 0;
    this.counters.set(metricName, current + value);
  }

  /**
   * Set a gauge metric value
   */
  recordGauge(name: string, value: number, labels?: Record<string, string>): void {
    const metricName = this.getMetricName(name, labels);
    this.gauges.set(metricName, value);
  }

  /**
   * Record a histogram observation (typically for latency/duration)
   */
  recordLatency(name: string, value: number, labels?: Record<string, string>): void {
    this.recordHistogram(name, value, labels);
  }

  /**
   * Record a histogram observation
   */
  recordHistogram(name: string, value: number, labels?: Record<string, string>): void {
    const metricName = this.getMetricName(name, labels);
    let histogram = this.histograms.get(metricName);

    if (!histogram) {
      histogram = {
        buckets: this.defaultBuckets.map(le => ({ le, count: 0 })),
        sum: 0,
        count: 0,
      };
      this.histograms.set(metricName, histogram);
    }

    // Update histogram
    histogram.sum += value;
    histogram.count += 1;

    // Update buckets
    for (const bucket of histogram.buckets) {
      if (value <= bucket.le) {
        bucket.count += 1;
      }
    }
  }

  /**
   * Time a function execution and record the duration
   */
  async time<T>(name: string, fn: () => Promise<T>, labels?: Record<string, string>): Promise<T> {
    const start = Date.now();
    try {
      const result = await fn();
      this.recordLatency(name, Date.now() - start, labels);
      return result;
    } catch (error) {
      this.recordLatency(name, Date.now() - start, { ...labels, status: 'error' });
      throw error;
    }
  }

  /**
   * Get all metrics as snapshot
   */
  getSnapshot(): Record<string, any> {
    const snapshot: Record<string, any> = {
      timestamp: Date.now(),
      counters: Object.fromEntries(this.counters),
      gauges: Object.fromEntries(this.gauges),
      histograms: {},
    };

    // Convert histograms to a more readable format
    for (const [name, histogram] of this.histograms) {
      snapshot.histograms[name] = {
        count: histogram.count,
        sum: histogram.sum,
        avg: histogram.count > 0 ? histogram.sum / histogram.count : 0,
        buckets: histogram.buckets.reduce((acc, bucket) => {
          acc[`le_${bucket.le}`] = bucket.count;
          return acc;
        }, {} as Record<string, number>),
      };
    }

    return snapshot;
  }

  /**
   * Get Prometheus-formatted metrics
   */
  getPrometheusMetrics(): string {
    const lines: string[] = [];
    const timestamp = Date.now();

    // Counters
    for (const [name, value] of this.counters) {
      lines.push(`# TYPE ${name} counter`);
      lines.push(`${name} ${value} ${timestamp}`);
    }

    // Gauges
    for (const [name, value] of this.gauges) {
      lines.push(`# TYPE ${name} gauge`);
      lines.push(`${name} ${value} ${timestamp}`);
    }

    // Histograms
    for (const [name, histogram] of this.histograms) {
      lines.push(`# TYPE ${name} histogram`);

      // Buckets
      for (const bucket of histogram.buckets) {
        lines.push(`${name}_bucket{le="${bucket.le}"} ${bucket.count} ${timestamp}`);
      }

      // +Inf bucket
      lines.push(`${name}_bucket{le="+Inf"} ${histogram.count} ${timestamp}`);

      // Sum and count
      lines.push(`${name}_sum ${histogram.sum} ${timestamp}`);
      lines.push(`${name}_count ${histogram.count} ${timestamp}`);
    }

    return lines.join('\n');
  }

  /**
   * Clear all metrics (useful for testing)
   */
  clear(): void {
    this.counters.clear();
    this.gauges.clear();
    this.histograms.clear();
  }

  /**
   * Get counter value
   */
  getCounter(name: string, labels?: Record<string, string>): number {
    const metricName = this.getMetricName(name, labels);
    return this.counters.get(metricName) || 0;
  }

  /**
   * Get gauge value
   */
  getGauge(name: string, labels?: Record<string, string>): number {
    const metricName = this.getMetricName(name, labels);
    return this.gauges.get(metricName) || 0;
  }

  /**
   * Get histogram statistics
   */
  getHistogram(name: string, labels?: Record<string, string>): HistogramMetric | undefined {
    const metricName = this.getMetricName(name, labels);
    return this.histograms.get(metricName);
  }

  /**
   * Calculate histogram percentiles
   */
  getHistogramPercentile(name: string, percentile: number, labels?: Record<string, string>): number {
    const histogram = this.getHistogram(name, labels);
    if (!histogram || histogram.count === 0) {
      return 0;
    }

    const targetCount = histogram.count * (percentile / 100);
    let cumulativeCount = 0;

    for (const bucket of histogram.buckets) {
      cumulativeCount += bucket.count;
      if (cumulativeCount >= targetCount) {
        return bucket.le;
      }
    }

    return histogram.buckets[histogram.buckets.length - 1].le;
  }

  /**
   * Create metric name with prefix and labels
   */
  private getMetricName(name: string, labels?: Record<string, string>): string {
    let metricName = this.prefix ? `${this.prefix}_${name}` : name;

    if (labels && Object.keys(labels).length > 0) {
      const labelString = Object.entries(labels)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, value]) => `${key}="${value}"`)
        .join(',');
      metricName += `{${labelString}}`;
    }

    return metricName;
  }
}

/**
 * Global metrics instance for easy access
 */
export const globalMetrics = new MetricsCollector('edge_function');

/**
 * Utility function to create labeled metrics
 */
export function createLabeledMetrics(labels: Record<string, string>) {
  return {
    incrementCounter: (name: string, value: number = 1) =>
      globalMetrics.incrementCounter(name, value, labels),
    recordGauge: (name: string, value: number) =>
      globalMetrics.recordGauge(name, value, labels),
    recordLatency: (name: string, value: number) =>
      globalMetrics.recordLatency(name, value, labels),
    time: <T>(name: string, fn: () => Promise<T>) =>
      globalMetrics.time(name, fn, labels),
  };
}