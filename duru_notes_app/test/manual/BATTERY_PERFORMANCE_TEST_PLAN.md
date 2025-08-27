# Battery & Performance Test Plan
## 8-Hour Geofence and Reminder Monitoring

### Overview
This comprehensive test plan validates the battery efficiency and performance characteristics of the Duru Notes app, specifically focusing on geofencing and reminder services over an extended 8-hour monitoring period.

### Test Objectives
1. **Validate 3-Second Capture Principle** - Ensure all capture operations complete within 3 seconds
2. **Monitor Battery Consumption** - Track power usage of background services
3. **Assess Memory Stability** - Verify no memory leaks in long-running services
4. **Performance Consistency** - Confirm stable performance over extended periods
5. **Device Impact Analysis** - Measure overall system impact

---

## Pre-Test Setup

### Device Requirements
- **Minimum**: iOS 14+ or Android 8.0+ device
- **Recommended**: Device with 4GB+ RAM, recent chipset
- **Battery**: Fully charged (100%) at test start
- **Storage**: At least 2GB free space
- **Location**: GPS enabled, high accuracy mode

### Test Environment Setup
```bash
# Install test dependencies
flutter pub get
flutter pub add battery_plus device_info_plus

# Prepare performance monitoring
flutter test test/performance/performance_test.dart

# Verify app installation
flutter run --release
```

### Pre-Test Checklist
- [ ] Device fully charged (100%)
- [ ] All unnecessary apps closed
- [ ] Do Not Disturb mode enabled
- [ ] Screen brightness at 50%
- [ ] Wi-Fi connected, mobile data enabled
- [ ] Location services enabled
- [ ] Performance monitoring tools ready
- [ ] Test area with clear GPS signal
- [ ] Backup device for comparison testing

---

## Test Execution Plan

### Phase 1: Baseline Performance Testing (30 minutes)

#### 1.1 Initial Performance Validation
**Objective**: Verify 3-second capture principle compliance

**Steps**:
1. Launch Duru Notes app
2. Execute automated performance tests:
   ```bash
   flutter test test/performance/performance_test.dart
   ```
3. Record baseline metrics:
   - Voice recording times
   - OCR processing times
   - Share-sheet processing times
   - Memory usage
   - Battery level

**Success Criteria**:
- [ ] All voice operations complete < 3 seconds
- [ ] All OCR operations complete < 3 seconds  
- [ ] All share operations complete < 3 seconds
- [ ] Memory usage stable
- [ ] No performance alerts triggered

#### 1.2 Device Performance Profiling
**Steps**:
1. Open app settings → Performance Monitoring
2. Run device performance analysis:
   ```dart
   final deviceInfo = await PerformanceMonitor.instance.getDevicePerformanceInfo();
   final memoryUsage = await PerformanceMonitor.instance.getCurrentMemoryUsage();
   ```
3. Record device characteristics:
   - Platform and model
   - CPU cores and RAM
   - Performance class
   - Initial memory usage

### Phase 2: Geofencing Setup and Validation (1 hour)

#### 2.1 Geofence Configuration
**Objective**: Establish multiple geofences for comprehensive testing

**Test Geofences to Create**:
1. **Home Location** (50m radius)
2. **Work Location** (100m radius)  
3. **Coffee Shop** (30m radius)
4. **Gym** (75m radius)

**Steps**:
1. Create test note: "Geofence Test Note"
2. Add location reminder for each test location
3. Verify geofence setup in system:
   ```dart
   final reminders = await db.getLocationReminders();
   assert(reminders.length == 4);
   ```
4. Start battery monitoring:
   ```dart
   await BatteryMonitor.instance.startMonitoring(
     testSessionName: 'geofence_setup',
   );
   ```

**Validation**:
- [ ] All 4 geofences created successfully
- [ ] GPS permissions granted
- [ ] Background location access enabled
- [ ] Battery monitoring started
- [ ] No immediate performance degradation

#### 2.2 Initial Geofence Testing
**Steps**:
1. Walk to first test location (Home)
2. Wait for geofence trigger (should occur within 2 minutes)
3. Verify notification received
4. Check app logs for geofence events
5. Record battery impact

**Expected Results**:
- [ ] Geofence trigger detected
- [ ] Notification displayed correctly
- [ ] Battery drain < 2% during setup phase

### Phase 3: Extended Monitoring (8 hours)

#### 3.1 Real-World Usage Simulation
**Objective**: Monitor performance during typical daily usage

**Monitoring Schedule**:
```
Hour 1-2: Active usage simulation
Hour 3-4: Background monitoring  
Hour 5-6: Mixed usage patterns
Hour 7-8: Final stress testing
```

**Hourly Checkpoints**:
```bash
# Execute every hour
flutter test test/performance/checkpoint_test.dart --hour=X
```

**Activities per Hour**:
1. **Voice Recording Tests** (3 operations)
   - 30-second voice note
   - 60-second voice note  
   - 90-second voice note
2. **OCR Testing** (2 operations)
   - Photo of document
   - Screenshot text extraction
3. **Share-Sheet Testing** (2 operations)
   - Share text from browser
   - Share image from gallery
4. **Location Changes** (if possible)
   - Trigger 1-2 geofence events

#### 3.2 Automated Monitoring Data Collection

**Battery Monitoring Script**:
```dart
// Execute every 15 minutes
void collectMonitoringData() async {
  final batteryInfo = await BatteryMonitor.instance.getCurrentBatteryInfo();
  final memoryUsage = await PerformanceMonitor.instance.getCurrentMemoryUsage();
  final performanceMetrics = PerformanceMonitor.instance.getMetricsInRange(
    DateTime.now().subtract(Duration(minutes: 15)),
    DateTime.now(),
  );
  
  // Log data for analysis
  logger.info('Monitoring checkpoint', data: {
    'battery_level': batteryInfo.level,
    'battery_state': batteryInfo.state.toString(),
    'memory_usage_mb': memoryUsage.usedMemoryMB,
    'memory_percentage': memoryUsage.usagePercentage,
    'operations_count': performanceMetrics.length,
    'timestamp': DateTime.now().toIso8601String(),
  });
}
```

### Phase 4: Reminder Service Testing (Throughout 8 hours)

#### 4.1 Recurring Reminder Setup
**Test Reminders to Create**:
1. **Every 30 minutes**: "Hydration reminder"
2. **Every 2 hours**: "Posture check"
3. **Daily at specific times**: 
   - 9:00 AM: "Morning standup"
   - 1:00 PM: "Lunch break"
   - 5:00 PM: "End of workday"

#### 4.2 Snooze Function Testing
**Test Scenarios**:
1. Snooze reminder for 5 minutes (test 3 times)
2. Snooze reminder for 15 minutes (test 2 times)
3. Snooze reminder for 1 hour (test 1 time)
4. Test snooze limit enforcement (5 max snoozes)

**Validation Points**:
- [ ] Reminders trigger on schedule
- [ ] Snooze functionality works correctly
- [ ] Notifications are timely and accurate
- [ ] Battery impact is minimal

### Phase 5: Stress Testing (Final 2 hours)

#### 5.1 Concurrent Operations Stress Test
**Objective**: Test performance under load

**Test Scenario**:
```dart
void stressTest() async {
  // Launch multiple concurrent operations
  final futures = [
    voiceRecordingService.recordAndTranscribe(90), // 90 second recording
    ocrService.processLargeDocument('test_document.pdf'),
    shareService.processBulkSharedContent(testFiles),
    reminderService.processAllDueReminders(),
  ];
  
  final stopwatch = Stopwatch()..start();
  await Future.wait(futures);
  stopwatch.stop();
  
  assert(stopwatch.elapsed < Duration(seconds: 5)); // Allow extra time for stress test
}
```

#### 5.2 Memory Pressure Testing
**Steps**:
1. Create and process 50 large notes (1MB each)
2. Import 20 high-resolution images  
3. Generate 100 voice recordings (30 seconds each)
4. Process all content through OCR
5. Monitor memory usage throughout

**Success Criteria**:
- [ ] Memory usage remains stable
- [ ] No out-of-memory errors
- [ ] Garbage collection working effectively
- [ ] Performance degradation < 20%

---

## Data Collection and Monitoring

### Automated Data Collection

#### Battery Metrics
```dart
class BatteryTestMetrics {
  final DateTime timestamp;
  final int batteryLevel;
  final BatteryState batteryState;
  final double drainRatePerHour;
  final bool isInBatterySaveMode;
  
  // Collected every 5 minutes
}
```

#### Performance Metrics
```dart
class PerformanceTestMetrics {
  final DateTime timestamp;
  final Duration operationDuration;
  final String operationName;
  final double memoryUsageMB;
  final int cpuUsagePercent;
  final bool operationSuccessful;
  
  // Collected per operation
}
```

#### Geofencing Metrics
```dart
class GeofenceTestMetrics {
  final DateTime timestamp;
  final String geofenceId;
  final GeofenceEvent eventType; // enter/exit
  final Duration detectionLatency;
  final double accuracyMeters;
  final bool notificationDelivered;
  
  // Collected per geofence event
}
```

### Manual Observation Points

#### Battery Health Indicators
- [ ] **Battery temperature** (should remain normal)
- [ ] **Charging behavior** (normal charging speeds)
- [ ] **Battery save mode triggers** (only when expected)
- [ ] **Background app refresh** (functioning normally)

#### Performance Indicators  
- [ ] **App responsiveness** (no UI lag)
- [ ] **System responsiveness** (overall device performance)
- [ ] **Thermal throttling** (device temperature normal)
- [ ] **Memory warnings** (no system memory alerts)

#### Functionality Verification
- [ ] **Geofence accuracy** (triggers at correct locations)
- [ ] **Reminder timing** (accurate notification delivery)
- [ ] **Data synchronization** (cloud sync working)
- [ ] **App stability** (no crashes or freezes)

---

## Success Criteria and Benchmarks

### 3-Second Capture Principle
| Operation | Target | Acceptable | Unacceptable |
|-----------|--------|------------|--------------|
| Voice Recording Start | < 500ms | < 1s | > 1s |
| Voice Transcription | < 2.5s | < 3s | > 3s |
| Image OCR | < 2s | < 3s | > 3s |
| Document OCR | < 3s | < 3s | > 3s |
| Share Processing | < 1s | < 2s | > 3s |

### Battery Consumption Benchmarks
| Time Period | Target Drain | Acceptable | Concerning |
|-------------|--------------|------------|------------|
| 1 Hour | < 3% | < 5% | > 8% |
| 4 Hours | < 10% | < 15% | > 25% |
| 8 Hours | < 20% | < 30% | > 50% |

### Memory Usage Guidelines
| Metric | Target | Acceptable | Concerning |
|--------|--------|------------|------------|
| Base Memory | < 150MB | < 200MB | > 300MB |
| Peak Memory | < 300MB | < 400MB | > 600MB |
| Memory Growth | < 50MB/8h | < 100MB/8h | > 200MB/8h |

### Performance Consistency
| Metric | Target | Acceptable | Unacceptable |
|--------|--------|------------|--------------|
| Operation Time Variance | < 20% | < 30% | > 50% |
| Success Rate | > 99% | > 95% | < 90% |
| Error Rate | < 0.1% | < 1% | > 5% |

---

## Troubleshooting Guide

### High Battery Drain Issues
**Symptoms**: Battery drain > 8% per hour
**Debugging Steps**:
1. Check background app refresh settings
2. Verify location accuracy settings (use balanced, not high accuracy)
3. Monitor geofence frequency and radius settings
4. Check for infinite loops in reminder processing
5. Verify proper service disposal on app backgrounding

**Investigation Commands**:
```dart
// Check active geofences
final activeGeofences = await geofenceService.getActiveGeofences();

// Monitor reminder processing frequency  
final reminderStats = await reminderService.getProcessingStats();

// Check battery usage by component
final batteryReport = await BatteryMonitor.instance.generateUsageReport(
  DateTime.now().subtract(Duration(hours: 1)),
  DateTime.now(),
);
```

### Performance Degradation Issues
**Symptoms**: Operations taking > 3 seconds
**Debugging Steps**:
1. Check available memory
2. Verify network connectivity for cloud services
3. Monitor CPU usage during operations
4. Check for resource contention
5. Validate input data quality

**Investigation Commands**:
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

### Geofencing Issues
**Symptoms**: Missed geofence triggers or false positives
**Debugging Steps**:
1. Verify GPS signal strength
2. Check geofence radius settings (minimum 30m recommended)
3. Validate location permissions
4. Monitor geofence service initialization
5. Check for location service conflicts

**Investigation Commands**:
```dart
// Check location permissions
final hasPermissions = await geofenceService.hasLocationPermissions();

// Monitor geofence status
final geofenceStatus = await geofenceService.getGeofenceStatus();

// Check location accuracy
final currentLocation = await Geolocator.getCurrentPosition();
```

---

## Test Data Analysis

### Automated Report Generation
```dart
class TestReportGenerator {
  static Future<TestReport> generateReport(DateTime testStart, DateTime testEnd) async {
    final batteryReport = await BatteryMonitor.instance.generateUsageReport(testStart, testEnd);
    final performanceMetrics = PerformanceMonitor.instance.getMetricsInRange(testStart, testEnd);
    
    return TestReport(
      testDuration: testEnd.difference(testStart),
      batteryUsage: batteryReport,
      performanceMetrics: performanceMetrics,
      geofenceEvents: await getGeofenceEvents(testStart, testEnd),
      reminderEvents: await getReminderEvents(testStart, testEnd),
      successRate: calculateSuccessRate(performanceMetrics),
      recommendations: generateRecommendations(batteryReport, performanceMetrics),
    );
  }
}
```

### Key Performance Indicators (KPIs)

#### Battery Efficiency Score
```
Score = 100 - (actual_drain_percentage / target_drain_percentage) * 100
Target: Score > 85 (Excellent), > 70 (Good), > 50 (Acceptable)
```

#### Performance Consistency Score  
```
Score = (operations_under_3s / total_operations) * 100
Target: Score > 95 (Excellent), > 90 (Good), > 80 (Acceptable)
```

#### System Impact Score
```
Score = 100 - (memory_growth_percentage + cpu_impact_percentage) / 2
Target: Score > 90 (Low Impact), > 75 (Medium Impact), > 60 (Acceptable)
```

---

## Post-Test Analysis

### Report Generation
1. **Execute final report generation**:
   ```bash
   flutter test test/performance/generate_report.dart --test-session=8h_battery_test
   ```

2. **Compile test results**:
   - Battery consumption analysis
   - Performance metric summaries  
   - Geofencing accuracy report
   - Reminder timing analysis
   - Memory usage patterns

3. **Generate recommendations**:
   - Optimization opportunities
   - Configuration improvements
   - Code efficiency suggestions
   - User experience enhancements

### Success Validation Checklist
- [ ] All operations completed within 3-second threshold
- [ ] Battery consumption within acceptable limits (< 30% over 8 hours)
- [ ] Memory usage remained stable (< 100MB growth)
- [ ] Geofence triggers accurate and timely
- [ ] Reminder notifications delivered correctly
- [ ] No crashes or significant errors
- [ ] Overall device performance not impacted
- [ ] User experience remained smooth

### Failure Investigation
If any success criteria are not met:
1. **Analyze performance logs** for bottlenecks
2. **Review battery usage patterns** for inefficiencies  
3. **Check geofencing configuration** for accuracy issues
4. **Validate reminder timing** for scheduling problems
5. **Examine memory usage** for potential leaks
6. **Generate improvement recommendations**

---

## Test Report Template

```markdown
# 8-Hour Battery & Performance Test Report
## Duru Notes App - [Test Date]

### Executive Summary
- Test Duration: 8 hours, 15 minutes
- Battery Consumption: X% (Target: <30%)
- Performance Grade: [A/B/C/F]
- System Impact: [Low/Medium/High]

### Test Results
#### 3-Second Capture Principle
- Voice Operations: X/X passed (XX% success rate)
- OCR Operations: X/X passed (XX% success rate)  
- Share Operations: X/X passed (XX% success rate)

#### Battery Analysis
- Starting Level: 100%
- Ending Level: XX%
- Average Drain Rate: X.X% per hour
- Peak Drain Period: [Time] (X.X% per hour)

#### Performance Metrics
- Total Operations: XXX
- Average Response Time: XXXms
- Memory Usage: XX MB - XX MB (XX MB growth)
- Success Rate: XX.X%

#### Geofencing Performance
- Total Triggers: XX
- Accuracy: XX.X%
- Average Detection Time: XXXms
- False Positives: X

#### Reminder System
- Scheduled Reminders: XX
- Delivered on Time: XX (XX.X%)
- Snooze Operations: XX
- Processing Efficiency: XX.X%

### Recommendations
1. [Optimization recommendation 1]
2. [Configuration improvement 2]
3. [Performance enhancement 3]

### Conclusion
[Overall assessment and recommendations for production readiness]
```

This comprehensive test plan ensures thorough validation of the Duru Notes app's performance characteristics, particularly focusing on the 3-second capture principle and battery efficiency of background services. The systematic approach covers all critical aspects while providing clear success criteria and troubleshooting guidance.
