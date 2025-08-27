# Performance & Battery Testing Suite

This comprehensive testing suite validates the **3-second capture principle** and monitors battery consumption for the Duru Notes app, ensuring optimal performance and power efficiency.

## Overview

The testing suite consists of automated performance tests and manual battery monitoring tools designed to validate:

1. **3-Second Capture Principle** - All capture operations (voice, OCR, share-sheet) complete within 3 seconds
2. **Battery Efficiency** - Background services consume minimal power over extended periods
3. **Memory Stability** - No memory leaks in long-running operations
4. **Performance Consistency** - Stable performance over time

## Test Components

### 1. Automated Performance Tests

#### `performance_test.dart`
Comprehensive stress testing of core capture operations.

**Features:**
- Tests voice recording/transcription (10 iterations each)
- Tests OCR processing for images and documents (10 iterations each)
- Tests share-sheet processing for text, images, and files (10 iterations each)
- Validates 3-second compliance for all operations
- Includes concurrent operation testing
- Memory usage stability validation

**Usage:**
```bash
# Run full performance test suite
flutter test test/performance/performance_test.dart

# Run with verbose output
flutter test test/performance/performance_test.dart --verbose
```

**Success Criteria:**
- ✅ All operations complete within 3 seconds
- ✅ 95% success rate across all iterations
- ✅ Memory usage remains stable during repeated operations
- ✅ Concurrent operations maintain performance

### 2. Monitoring Infrastructure

#### `PerformanceMonitor` (`lib/core/performance/performance_monitor.dart`)
Real-time performance monitoring service.

**Capabilities:**
- Operation timing and profiling
- Memory usage tracking
- Device performance characteristics analysis
- Performance alerts and thresholds
- Comprehensive metrics collection

**Key Methods:**
```dart
// Start/stop operation timing
PerformanceMonitor.instance.startOperation('voice_recording');
PerformanceMonitor.instance.endOperation('voice_recording');

// Measure operation with automatic timing
await PerformanceMonitor.instance.measureOperation(
  'ocr_processing',
  () => ocrService.processImage(image),
);

// Get performance summaries
final summary = PerformanceMonitor.instance.getOperationSummary('voice_recording');
```

#### `BatteryMonitor` (`lib/core/performance/battery_monitor.dart`)
Comprehensive battery monitoring for extended testing.

**Features:**
- Real-time battery level tracking
- Power consumption estimation
- Battery drain rate calculation
- Background service impact monitoring
- Detailed battery usage reporting

**Usage:**
```dart
// Start monitoring session
await BatteryMonitor.instance.startMonitoring(
  testSessionName: '8h_geofence_test',
);

// Generate usage report
final report = BatteryMonitor.instance.generateUsageReport(startTime, endTime);

// Stop and get final report
final finalReport = await BatteryMonitor.instance.stopMonitoring();
```

### 3. Extended Testing Tools

#### `checkpoint_test.dart`
Hourly validation during extended testing sessions.

**Purpose:**
- Validates performance at regular intervals
- Monitors battery drain progression
- Ensures system health throughout test duration
- Generates intermediate reports

**Usage:**
```bash
# Run hourly checkpoints
flutter test test/performance/checkpoint_test.dart --hour=1
flutter test test/performance/checkpoint_test.dart --hour=2
# ... continue for each hour
```

#### `generate_report.dart`
Comprehensive test report generation and analysis.

**Features:**
- Detailed performance statistics
- Battery usage analysis
- Success rate calculations
- Performance recommendations
- Production readiness assessment

**Usage:**
```bash
# Generate final test report
flutter test test/performance/generate_report.dart --test-session=8h_battery_test
```

## Running the Complete Test Suite

### Quick Performance Validation (30 minutes)
```bash
# 1. Run automated performance tests
flutter test test/performance/performance_test.dart

# 2. Verify all operations meet 3-second threshold
# Expected: 100% compliance rate

# 3. Check memory stability
# Expected: <50MB memory growth during testing
```

### Extended Battery Testing (8 hours)
Follow the comprehensive manual test plan: [`BATTERY_PERFORMANCE_TEST_PLAN.md`](../manual/BATTERY_PERFORMANCE_TEST_PLAN.md)

**Key Steps:**
1. **Setup Phase** (30 min)
   - Device preparation
   - Baseline performance validation
   - Geofence configuration

2. **Extended Monitoring** (8 hours)
   - Real-world usage simulation
   - Hourly checkpoint validation
   - Continuous battery/performance monitoring

3. **Final Analysis**
   - Comprehensive report generation
   - Success criteria validation
   - Performance recommendations

## Performance Benchmarks

### 3-Second Capture Principle
| Operation | Target | Acceptable | Unacceptable |
|-----------|--------|------------|--------------|
| Voice Recording Start | < 500ms | < 1s | > 1s |
| Voice Transcription | < 2.5s | < 3s | > 3s |
| Image OCR | < 2s | < 3s | > 3s |
| Document OCR | < 3s | < 3s | > 3s |
| Share Processing | < 1s | < 2s | > 3s |

### Battery Consumption Targets
| Time Period | Target | Acceptable | Concerning |
|-------------|--------|------------|------------|
| 1 Hour | < 3% | < 5% | > 8% |
| 4 Hours | < 10% | < 15% | > 25% |
| 8 Hours | < 20% | < 30% | > 50% |

### Memory Usage Guidelines
| Metric | Target | Acceptable | Concerning |
|--------|--------|------------|------------|
| Base Memory | < 150MB | < 200MB | > 300MB |
| Peak Memory | < 300MB | < 400MB | > 600MB |
| Memory Growth | < 50MB/8h | < 100MB/8h | > 200MB/8h |

## Test Environment Setup

### Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  battery_plus: ^6.0.2
  device_info_plus: ^10.1.2

dev_dependencies:
  mockito: ^5.4.4
  image: ^4.1.7
```

### Device Requirements
- **Minimum**: iOS 14+ or Android 8.0+
- **Recommended**: 4GB+ RAM, recent chipset
- **Battery**: Fully charged for extended tests
- **Storage**: 2GB+ free space
- **Location**: GPS enabled for geofence testing

### Pre-Test Checklist
- [ ] Device fully charged (100%)
- [ ] Unnecessary apps closed
- [ ] Do Not Disturb enabled
- [ ] Screen brightness at 50%
- [ ] Location services enabled
- [ ] Test area with clear GPS signal

## Interpreting Test Results

### Performance Grades
- **A (90-100%)**: Excellent performance, production ready
- **B (80-89%)**: Good performance, minor optimizations recommended
- **C (70-79%)**: Acceptable performance, some improvements needed
- **D (60-69%)**: Needs improvement before production
- **F (<60%)**: Unacceptable performance, major optimization required

### Key Performance Indicators (KPIs)

#### Battery Efficiency Score
```
Score = 100 - (actual_drain_percentage / target_drain_percentage) * 100
```

#### Performance Consistency Score
```
Score = (operations_under_3s / total_operations) * 100
```

#### System Impact Score
```
Score = 100 - (memory_growth_percentage + cpu_impact_percentage) / 2
```

## Troubleshooting

### High Battery Drain
**Symptoms**: Battery drain > 8% per hour

**Investigation:**
```dart
// Check active geofences
final activeGeofences = await geofenceService.getActiveGeofences();

// Monitor reminder processing
final reminderStats = await reminderService.getProcessingStats();

// Analyze battery usage
final batteryReport = await BatteryMonitor.instance.generateUsageReport(
  DateTime.now().subtract(Duration(hours: 1)),
  DateTime.now(),
);
```

**Common Causes:**
- Geofence radius too small (< 30m)
- High accuracy location mode
- Infinite loops in reminder processing
- Improper service disposal

### Performance Degradation
**Symptoms**: Operations taking > 3 seconds

**Investigation:**
```dart
// Check system resources
final memoryUsage = await PerformanceMonitor.instance.getCurrentMemoryUsage();
final deviceInfo = await PerformanceMonitor.instance.getDevicePerformanceInfo();

// Analyze slow operations
final slowOperations = PerformanceMonitor.instance.getMetricsInRange(
  DateTime.now().subtract(Duration(hours: 1)),
  DateTime.now(),
).where((m) => m.duration > Duration(seconds: 3));
```

**Common Causes:**
- Insufficient memory
- Network connectivity issues
- Resource contention
- Poor input data quality

### Geofencing Issues
**Symptoms**: Missed triggers or false positives

**Investigation:**
```dart
// Check permissions
final hasPermissions = await geofenceService.hasLocationPermissions();

// Monitor geofence status
final geofenceStatus = await geofenceService.getGeofenceStatus();

// Check location accuracy
final currentLocation = await Geolocator.getCurrentPosition();
```

**Common Causes:**
- Insufficient GPS signal
- Location permissions not granted
- Geofence radius too small
- Service conflicts

## Continuous Integration

### Automated Testing
Add to CI/CD pipeline:
```yaml
# .github/workflows/performance.yml
- name: Run Performance Tests
  run: |
    flutter test test/performance/performance_test.dart
    
- name: Validate Performance Benchmarks
  run: |
    # Parse test output and validate benchmarks
    # Fail build if performance degrades
```

### Performance Regression Detection
```dart
// Compare against historical performance data
final currentPerformance = await runPerformanceTests();
final historicalData = await loadHistoricalPerformance();

if (currentPerformance.averageDuration > historicalData.averageDuration * 1.2) {
  throw Exception('Performance regression detected');
}
```

## Best Practices

### Test Design
- **Realistic Scenarios**: Test with real-world data sizes and network conditions
- **Edge Cases**: Include boundary conditions and error scenarios  
- **Consistency**: Run tests multiple times to ensure stable results
- **Documentation**: Record all test parameters and environmental factors

### Monitoring
- **Baseline Establishment**: Record baseline performance for comparison
- **Trend Analysis**: Monitor performance trends over time
- **Alert Thresholds**: Set appropriate alerts for performance degradation
- **Regular Validation**: Schedule periodic performance validation

### Optimization
- **Targeted Improvements**: Focus on operations that fail benchmarks most frequently
- **Incremental Changes**: Make small, measurable improvements
- **A/B Testing**: Validate optimizations with controlled comparisons
- **User Impact**: Consider real-world usage patterns in optimization decisions

## Report Outputs

### Automated Reports
Generated JSON reports include:
- Device characteristics
- Performance statistics (avg, min, max, percentiles)
- Success rates and compliance metrics
- Battery usage analysis
- Specific recommendations

### Manual Test Reports
Follow the template in [`BATTERY_PERFORMANCE_TEST_PLAN.md`](../manual/BATTERY_PERFORMANCE_TEST_PLAN.md) for:
- Executive summary
- Detailed test results
- Performance analysis
- Battery consumption assessment
- Production readiness evaluation

## Contributing

When adding new performance tests:

1. **Follow Naming Conventions**: Use descriptive test names
2. **Include Documentation**: Add clear comments and documentation
3. **Validate Benchmarks**: Ensure realistic performance targets
4. **Test Edge Cases**: Include error conditions and boundary tests
5. **Update Benchmarks**: Adjust targets based on new requirements

## Support

For questions about performance testing:
1. Review this documentation and test plan
2. Check existing test implementations for examples
3. Examine performance monitoring logs for debugging
4. Consult the troubleshooting guide for common issues

---

**🎯 Goal**: Ensure Duru Notes delivers consistent, fast, and battery-efficient performance that delights users while maintaining production reliability.
