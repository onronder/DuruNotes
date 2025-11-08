# DevTools & Instruments Debugging Guide

## Current Situation
- App Process ID: 11690
- DevTools URL: http://127.0.0.1:9100?uri=http://127.0.0.1:53697/aWV8uGSLg68=/
- Instruments: Should be open now
- Symptom: setState() completes but widgets never rebuild

## Part 1: Flutter DevTools Investigation

### A. Check Performance Tab
1. Open DevTools (should be open in browser now)
2. Go to **Performance** tab
3. Look for:
   - **Frame rendering**: Are frames being rendered at all?
   - **UI thread**: Is it blocked/waiting?
   - **Raster thread**: Is it processing?
   - **Timeline events**: What's the last event recorded?

### B. Check Timeline
1. Click **Timeline** tab
2. Record for 5-10 seconds
3. Look for:
   - **Frame build events**: Are `build()` methods being called?
   - **Platform channel calls**: Any stuck platform calls?
   - **Microtasks**: Are they executing?
   - **Event loop**: Is it processing or frozen?

### C. Check Memory
1. Go to **Memory** tab
2. Take a snapshot
3. Check:
   - **Widget tree**: Can you see the current widget tree?
   - **Is BootstrapShell present?** (Should be if rebuild happened)
   - **Is _BootstrapLoadingApp present?** (Should NOT be if rebuild happened)

### D. Check Logging
1. Go to **Logging** tab
2. Look for:
   - Last log message (should be "Frame scheduled")
   - Any error messages after bootstrap
   - Platform channel errors
   - Native crashes

## Part 2: Instruments Profiling

### A. Setup Instruments
1. Instruments should be open now
2. Choose **Time Profiler** template
3. At the top, select target:
   - Device: iPhone 16 Pro Max (Simulator)
   - Process: com.fittechs.duruNotesApp (PID 11690)
4. Click **Record** (red button)
5. Let it run for 10-15 seconds
6. Click **Stop**

### B. Analyze Call Tree
After recording stops:

1. Click **Call Tree** at the bottom
2. Configure display options (top right):
   - ☑ Separate by Thread
   - ☑ Invert Call Tree
   - ☑ Hide System Libraries (uncheck this to see everything)

3. **Look for threads spending most time**:
   - Sort by "Weight" column (highest first)
   - Identify which thread is blocked

4. **Common blocking patterns to look for**:
   - `semaphore_wait` - Thread waiting on semaphore
   - `pthread_cond_wait` - Thread waiting on condition
   - `mach_msg_trap` - Thread blocked on mach message
   - `dispatch_semaphore_wait` - Waiting on GCD semaphore
   - `__psynch_cvwait` - pthread condition variable wait

### C. Check Main Thread
1. Find "Main Thread" or "com.apple.main-thread"
2. Expand the call stack
3. **Look for**:
   - Where is it spending time?
   - Is it stuck in a `wait` call?
   - Is it blocked on native code?
   - Last Flutter/Dart function called?

### D. Check Flutter Threads
Look for these specific threads:
- **1.ui** - Flutter UI thread (should be active)
- **1.raster** - Flutter raster thread
- **1.io** - Flutter IO thread
- **1.platform** - Platform thread

For each thread, check if it's:
- ✅ Running normally (< 50% time in wait)
- ⚠️ Mostly waiting (> 80% time in wait calls)
- ❌ Deadlocked (100% time in single wait call)

## Part 3: System Trace (Advanced)

If Time Profiler doesn't show the issue:

1. Close current trace
2. Create new trace with **System Trace** template
3. Record for 10 seconds
4. Look for:
   - **Thread states**: Which threads are runnable vs blocked
   - **System calls**: What system calls are being made
   - **Lock contention**: Are threads fighting for locks?

## Part 4: What To Look For

### Signs of Main Thread Block:
```
Main Thread:
├─ 100% mach_msg_trap
├─ __CFRunLoopServiceMachPort
└─ CFRunLoopRunSpecific
```
**Meaning**: Main thread stuck waiting for message (likely iOS level)

### Signs of Flutter UI Thread Block:
```
1.ui:
├─ 100% pthread_cond_wait
├─ std::__1::condition_variable::wait
└─ dart::Monitor::Wait
```
**Meaning**: Dart isolate waiting on condition variable

### Signs of Platform Channel Deadlock:
```
1.platform:
├─ dispatch_semaphore_wait
├─ Flutter::PlatformChannel::InvokeMethod
└─ [platform code]
```
**Meaning**: Flutter waiting for native platform response

### Signs of StoreKit/Adapty Block (Should be fixed):
```
Main Thread:
├─ SKPaymentQueue
├─ -[SKPaymentQueue transactions]
└─ -[Adapty getTransactions]
```
**Meaning**: StoreKit blocking (we deferred this)

## Part 5: Reporting Back

After investigation, please share:

### From DevTools:
1. Screenshot of Performance tab showing timeline
2. Last 20 lines from Logging tab
3. Widget tree snapshot (if available)
4. Any error messages

### From Instruments:
1. Screenshot of Call Tree showing top 10 functions by weight
2. Which thread is spending most time? (name + percentage)
3. Top function that thread is stuck in
4. Full call stack of the blocking function (expand and screenshot)

### Key Questions to Answer:
1. **Is the main thread blocked?** Yes/No + what it's waiting on
2. **Is Flutter UI thread (1.ui) blocked?** Yes/No + what it's waiting on
3. **Are frames being rendered at all?** Yes/No + frame rate if yes
4. **Any platform channel calls stuck?** Yes/No + which channel if yes
5. **Widget tree shows which widget?** _BootstrapLoadingApp or BootstrapShell?

## Quick Command Reference

### Get thread dump:
```bash
lldb -p 11690 -o "thread backtrace all" -o "quit"
```

### Check if app is responsive:
```bash
xcrun simctl io booted recordVideo --display=external /tmp/screen_test.mp4 &
sleep 5
kill %1
open /tmp/screen_test.mp4
```

### Get console logs:
```bash
xcrun simctl spawn booted log show --predicate 'process == "Runner"' --last 1m
```

## Expected Findings

Based on our analysis, you should find:
- **Main thread**: Likely blocked waiting on something
- **1.ui thread**: Possibly blocked after setState()
- **Widget tree**: Still shows _BootstrapLoadingApp (not BootstrapShell)
- **Last frame**: Rendered before bootstrap completed
- **Next frame**: Never scheduled/rendered despite scheduleFrame() call

The blocker is likely one of:
1. iOS App Group UserDefaults lock (ShareExtension)
2. StoreKit transaction lock (despite deferring Adapty)
3. Platform channel deadlock (some plugin)
4. Flutter engine deadlock (rare but possible)
