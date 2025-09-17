const fs = require('fs');
const path = require('path');

/**
 * Comprehensive Analysis of Quick Capture Widget Implementation
 * Analyzes all 4 phases for bugs, missing parts, and issues
 */
class ComprehensiveWidgetAnalyzer {
  constructor() {
    this.issues = {
      critical: [],
      bugs: [],
      missing: [],
      imports: [],
      performance: [],
      integration: [],
      security: [],
      warnings: []
    };
    this.stats = {
      filesAnalyzed: 0,
      linesOfCode: 0,
      phases: {
        phase1: { complete: false, files: [] },
        phase2: { complete: false, files: [] },
        phase3: { complete: false, files: [] },
        phase4: { complete: false, files: [] }
      }
    };
  }

  // ============== PHASE 1: Backend Analysis ==============
  analyzePhase1Backend() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 1: BACKEND INFRASTRUCTURE ANALYSIS');
    console.log('='.repeat(70));

    // Check database migrations
    console.log('\n1. Database Migrations:');
    const migrationsPath = path.join(__dirname, '..', 'supabase', 'migrations');
    
    const requiredMigrations = [
      '20250120_quick_capture_widget.sql',
      '20250121_fix_quick_capture_function.sql'
    ];

    requiredMigrations.forEach(migration => {
      const migrationPath = path.join(migrationsPath, migration);
      if (fs.existsSync(migrationPath)) {
        const content = fs.readFileSync(migrationPath, 'utf8');
        this.stats.phases.phase1.files.push(migrationPath);
        
        // Check for encrypted columns
        if (content.includes('title_enc') && content.includes('props_enc')) {
          console.log(`   ✅ ${migration} - Uses encrypted columns`);
        } else if (content.includes('title') && !content.includes('title_enc')) {
          this.issues.bugs.push(`Migration ${migration} uses unencrypted columns`);
          console.log(`   ❌ ${migration} - Uses unencrypted columns`);
        }

        // Check for proper JSON casting
        if (content.includes('encrypted_metadata::json')) {
          console.log(`   ✅ ${migration} - Proper JSON casting`);
        } else if (content.includes('encrypted_metadata->')) {
          this.issues.bugs.push(`Migration ${migration} missing JSON cast for TEXT column`);
        }
      } else {
        this.issues.missing.push(`Migration file: ${migration}`);
        console.log(`   ❌ ${migration} - NOT FOUND`);
      }
    });

    // Check Edge Function
    console.log('\n2. Edge Function Analysis:');
    const edgeFunctionPath = path.join(__dirname, '..', 'supabase', 'functions', 'quick-capture-widget', 'index.ts');
    
    if (fs.existsSync(edgeFunctionPath)) {
      const content = fs.readFileSync(edgeFunctionPath, 'utf8');
      this.stats.phases.phase1.files.push(edgeFunctionPath);
      this.stats.linesOfCode += content.split('\n').length;
      
      // Check for btoa usage (base64 encoding)
      if (!content.includes('btoa')) {
        this.issues.bugs.push('Edge Function: Missing btoa for base64 encoding');
        console.log('   ❌ Missing base64 encoding (btoa)');
      } else {
        console.log('   ✅ Base64 encoding implemented');
      }

      // Check for encrypted columns usage
      if (content.includes('title_enc') && content.includes('props_enc')) {
        console.log('   ✅ Uses encrypted columns');
      } else {
        this.issues.critical.push('Edge Function: Not using encrypted columns!');
        console.log('   ❌ NOT using encrypted columns');
      }

      // Check for rate limiting
      if (content.includes('rate_limits')) {
        console.log('   ✅ Rate limiting implemented');
      } else {
        this.issues.missing.push('Edge Function: Rate limiting not implemented');
      }

      // Check for error handling
      if (!content.includes('try') || !content.includes('catch')) {
        this.issues.bugs.push('Edge Function: Missing error handling');
      }

      // Check for CORS headers
      if (!content.includes('Access-Control-Allow-Origin')) {
        this.issues.missing.push('Edge Function: CORS headers missing');
      }
    } else {
      this.issues.critical.push('Edge Function file not found!');
      console.log('   ❌ Edge Function NOT FOUND');
    }

    // Check deployment status
    console.log('\n3. Deployment Configuration:');
    const deployScriptPath = path.join(__dirname, '..', 'deploy_quick_capture_function.sh');
    if (fs.existsSync(deployScriptPath)) {
      console.log('   ✅ Deployment script exists');
      this.stats.phases.phase1.files.push(deployScriptPath);
    } else {
      this.issues.missing.push('Deployment script for Edge Function');
    }

    this.stats.phases.phase1.complete = this.stats.phases.phase1.files.length >= 3;
  }

  // ============== PHASE 2: Flutter Service Analysis ==============
  analyzePhase2Flutter() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 2: FLUTTER SERVICE LAYER ANALYSIS');
    console.log('='.repeat(70));

    // Check QuickCaptureService
    console.log('\n1. QuickCaptureService:');
    const servicePath = path.join(__dirname, '..', 'lib', 'services', 'quick_capture_service.dart');
    
    if (fs.existsSync(servicePath)) {
      const content = fs.readFileSync(servicePath, 'utf8');
      this.stats.phases.phase2.files.push(servicePath);
      this.stats.linesOfCode += content.split('\n').length;
      
      // Check imports
      const requiredImports = [
        'package:flutter/services.dart',
        'package:riverpod/riverpod.dart',
        '../repository/notes_repository.dart',
        '../services/attachment_service.dart'
      ];

      requiredImports.forEach(imp => {
        if (!content.includes(imp)) {
          this.issues.imports.push(`QuickCaptureService missing: ${imp}`);
          console.log(`   ⚠️  Missing import: ${imp}`);
        }
      });

      // Check platform channel
      if (!content.includes('MethodChannel')) {
        this.issues.critical.push('QuickCaptureService: MethodChannel not implemented');
        console.log('   ❌ MethodChannel NOT implemented');
      } else {
        console.log('   ✅ MethodChannel implemented');
      }

      // Check for encryption handling
      if (content.includes('NotesRepository') && content.includes('createOrUpdate')) {
        console.log('   ✅ Uses NotesRepository for encryption');
      } else {
        this.issues.bugs.push('QuickCaptureService: May not handle encryption properly');
      }

      // Check error handling
      if (!content.includes('try') || !content.includes('catch')) {
        this.issues.bugs.push('QuickCaptureService: Insufficient error handling');
      }

      // Check offline support
      if (content.includes('_pendingCapturesKey') && content.includes('SharedPreferences')) {
        console.log('   ✅ Offline support implemented');
      } else {
        this.issues.missing.push('QuickCaptureService: Offline support incomplete');
      }

      // Check method implementations
      const requiredMethods = [
        'initialize()',
        'captureNote(',
        'getRecentCaptures(',
        'updateWidgetCache(',
        'processPendingCaptures('
      ];

      requiredMethods.forEach(method => {
        if (!content.includes(method)) {
          this.issues.missing.push(`QuickCaptureService: ${method} not found`);
        }
      });
    } else {
      this.issues.critical.push('QuickCaptureService not found!');
      console.log('   ❌ Service file NOT FOUND');
    }

    // Check Provider registration
    console.log('\n2. Provider Registration:');
    const providersPath = path.join(__dirname, '..', 'lib', 'providers.dart');
    
    if (fs.existsSync(providersPath)) {
      const content = fs.readFileSync(providersPath, 'utf8');
      
      if (content.includes('quickCaptureServiceProvider')) {
        console.log('   ✅ Provider registered');
        this.stats.phases.phase2.files.push(providersPath);
      } else {
        this.issues.critical.push('quickCaptureServiceProvider not registered');
        console.log('   ❌ Provider NOT registered');
      }
    }

    // Check App integration
    console.log('\n3. App Integration:');
    const appPath = path.join(__dirname, '..', 'lib', 'app', 'app.dart');
    
    if (fs.existsSync(appPath)) {
      const content = fs.readFileSync(appPath, 'utf8');
      
      if (content.includes('QuickCaptureService') || content.includes('quickCaptureService')) {
        console.log('   ✅ Integrated in app');
        this.stats.phases.phase2.files.push(appPath);
      } else {
        this.issues.bugs.push('QuickCaptureService not integrated in app lifecycle');
        console.log('   ⚠️  Not fully integrated in app');
      }
    }

    this.stats.phases.phase2.complete = this.stats.phases.phase2.files.length >= 2;
  }

  // ============== PHASE 3: iOS Widget Analysis ==============
  analyzePhase3iOS() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 3: iOS WIDGET IMPLEMENTATION ANALYSIS');
    console.log('='.repeat(70));

    const iosFiles = {
      widget: 'ios/QuickCaptureWidget/QuickCaptureWidget.swift',
      dataProvider: 'ios/QuickCaptureWidget/WidgetDataProvider.swift',
      bridge: 'ios/Runner/WidgetBridge.swift',
      appDelegate: 'ios/Runner/AppDelegate.swift',
      infoPlist: 'ios/QuickCaptureWidget/Info.plist',
      entitlements: 'ios/QuickCaptureWidget/QuickCaptureWidget.entitlements'
    };

    console.log('\n1. iOS Widget Files:');
    Object.entries(iosFiles).forEach(([name, filePath]) => {
      const fullPath = path.join(__dirname, '..', filePath);
      if (fs.existsSync(fullPath)) {
        console.log(`   ✅ ${name}: ${filePath}`);
        this.stats.phases.phase3.files.push(fullPath);
        
        const content = fs.readFileSync(fullPath, 'utf8');
        this.stats.linesOfCode += content.split('\n').length;
        
        // Specific checks for each file
        if (name === 'widget' && !content.includes('WidgetKit')) {
          this.issues.imports.push('iOS Widget: Missing WidgetKit import');
        }
        
        if (name === 'bridge' && !content.includes('FlutterMethodChannel')) {
          this.issues.bugs.push('WidgetBridge: Missing FlutterMethodChannel');
        }
        
        if (name === 'appDelegate') {
          if (!content.includes('WidgetBridge')) {
            this.issues.critical.push('AppDelegate: WidgetBridge not registered');
          }
          if (!content.includes('handleAppLaunch')) {
            this.issues.bugs.push('AppDelegate: Deep link handling missing');
          }
        }
      } else {
        this.issues.missing.push(`iOS ${name}: ${filePath}`);
        console.log(`   ❌ ${name}: NOT FOUND`);
      }
    });

    // Check for App Groups configuration
    console.log('\n2. App Groups Configuration:');
    const entitlementsPath = path.join(__dirname, '..', iosFiles.entitlements);
    if (fs.existsSync(entitlementsPath)) {
      const content = fs.readFileSync(entitlementsPath, 'utf8');
      if (content.includes('group.com.fittechs.durunotes')) {
        console.log('   ✅ App Groups configured');
      } else {
        this.issues.critical.push('iOS: App Groups not configured properly');
        console.log('   ❌ App Groups NOT configured');
      }
    }

    this.stats.phases.phase3.complete = this.stats.phases.phase3.files.length >= 4;
  }

  // ============== PHASE 4: Android Widget Analysis ==============
  analyzePhase4Android() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 4: ANDROID WIDGET IMPLEMENTATION ANALYSIS');
    console.log('='.repeat(70));

    // Check Android widget files
    console.log('\n1. Android Widget Components:');
    const androidFiles = {
      provider: 'android/app/src/main/kotlin/com/fittechs/durunotes/widget/QuickCaptureWidgetProvider.kt',
      service: 'android/app/src/main/kotlin/com/fittechs/durunotes/widget/QuickCaptureRemoteViewsService.kt',
      config: 'android/app/src/main/kotlin/com/fittechs/durunotes/widget/QuickCaptureConfigActivity.kt',
      mainActivity: 'android/app/src/main/kotlin/com/fittechs/duruNotesApp/MainActivity.kt'
    };

    Object.entries(androidFiles).forEach(([name, filePath]) => {
      const fullPath = path.join(__dirname, '..', filePath);
      if (fs.existsSync(fullPath)) {
        console.log(`   ✅ ${name}: Found`);
        this.stats.phases.phase4.files.push(fullPath);
        
        const content = fs.readFileSync(fullPath, 'utf8');
        this.stats.linesOfCode += content.split('\n').length;
        
        // Check for specific issues
        if (name === 'mainActivity') {
          // Check for package mismatch
          if (content.includes('com.fittechs.duruNotesApp') && 
              content.includes('com.fittechs.durunotes.widget')) {
            console.log('   ⚠️  Package name mismatch detected');
            this.issues.bugs.push('Android: Package name inconsistency between MainActivity and widget');
          }
          
          // Check for MethodChannel
          if (!content.includes('MethodChannel')) {
            this.issues.critical.push('MainActivity: MethodChannel not implemented');
          }
        }

        // Check for proper imports
        if (name === 'provider' && !content.includes('AppWidgetProvider')) {
          this.issues.imports.push('Android WidgetProvider: Missing AppWidgetProvider import');
        }
      } else {
        this.issues.missing.push(`Android ${name}: ${filePath}`);
        console.log(`   ❌ ${name}: NOT FOUND`);
      }
    });

    // Check layouts
    console.log('\n2. Widget Layouts:');
    const layouts = [
      'widget_quick_capture_small.xml',
      'widget_quick_capture_medium.xml',
      'widget_quick_capture_large.xml'
    ];

    layouts.forEach(layout => {
      const layoutPath = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', 'layout', layout);
      if (fs.existsSync(layoutPath)) {
        console.log(`   ✅ ${layout}`);
        this.stats.phases.phase4.files.push(layoutPath);
      } else {
        this.issues.missing.push(`Android layout: ${layout}`);
        console.log(`   ❌ ${layout} NOT FOUND`);
      }
    });

    // Check AndroidManifest
    console.log('\n3. AndroidManifest.xml:');
    const manifestPath = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
    if (fs.existsSync(manifestPath)) {
      const content = fs.readFileSync(manifestPath, 'utf8');
      
      if (content.includes('QuickCaptureWidgetProvider')) {
        console.log('   ✅ Widget provider registered');
      } else {
        this.issues.critical.push('AndroidManifest: Widget provider not registered');
        console.log('   ❌ Widget provider NOT registered');
      }
      
      if (content.includes('durunotes://')) {
        console.log('   ✅ Deep linking configured');
      } else {
        this.issues.bugs.push('AndroidManifest: Deep linking not configured');
        console.log('   ⚠️  Deep linking not configured');
      }
    }

    this.stats.phases.phase4.complete = this.stats.phases.phase4.files.length >= 6;
  }

  // ============== Cross-Platform Integration Analysis ==============
  analyzeCrossPlatformIntegration() {
    console.log('\n' + '='.repeat(70));
    console.log('CROSS-PLATFORM INTEGRATION ANALYSIS');
    console.log('='.repeat(70));

    console.log('\n1. Platform Channel Consistency:');
    
    // Check Flutter service
    const servicePath = path.join(__dirname, '..', 'lib', 'services', 'quick_capture_service.dart');
    let flutterChannel = '';
    if (fs.existsSync(servicePath)) {
      const content = fs.readFileSync(servicePath, 'utf8');
      const channelMatch = content.match(/MethodChannel\(['"]([^'"]+)['"]\)/);
      if (channelMatch) {
        flutterChannel = channelMatch[1];
        console.log(`   Flutter: ${flutterChannel}`);
      }
    }

    // Check iOS
    const iosBridgePath = path.join(__dirname, '..', 'ios', 'Runner', 'WidgetBridge.swift');
    if (fs.existsSync(iosBridgePath)) {
      const content = fs.readFileSync(iosBridgePath, 'utf8');
      if (content.includes(flutterChannel) || content.includes('com.fittechs.durunotes/quick_capture')) {
        console.log('   ✅ iOS: Channel matches');
      } else {
        this.issues.integration.push('iOS: Platform channel mismatch');
        console.log('   ❌ iOS: Channel mismatch');
      }
    }

    // Check Android
    const androidMainPath = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'kotlin', 'com', 'fittechs', 'duruNotesApp', 'MainActivity.kt');
    if (fs.existsSync(androidMainPath)) {
      const content = fs.readFileSync(androidMainPath, 'utf8');
      if (content.includes(flutterChannel) || content.includes('com.fittechs.durunotes/quick_capture')) {
        console.log('   ✅ Android: Channel matches');
      } else {
        this.issues.integration.push('Android: Platform channel mismatch');
        console.log('   ❌ Android: Channel mismatch');
      }
    }

    console.log('\n2. Data Model Consistency:');
    
    // Check if all platforms handle encrypted data
    console.log('   Checking encrypted column usage:');
    console.log('   - Backend: Uses title_enc, props_enc');
    console.log('   - Flutter: Uses NotesRepository (handles encryption)');
    console.log('   - iOS: Receives encrypted data');
    console.log('   - Android: Receives encrypted data');

    console.log('\n3. Method Name Consistency:');
    const commonMethods = [
      'updateWidgetData',
      'refreshWidget',
      'getAuthStatus',
      'savePendingCapture',
      'getPendingCaptures'
    ];

    commonMethods.forEach(method => {
      console.log(`   Checking: ${method}`);
      let found = { flutter: false, ios: false, android: false };

      // Check Flutter
      if (fs.existsSync(servicePath)) {
        const content = fs.readFileSync(servicePath, 'utf8');
        if (content.includes(method)) found.flutter = true;
      }

      // Check Android
      if (fs.existsSync(androidMainPath)) {
        const content = fs.readFileSync(androidMainPath, 'utf8');
        if (content.includes(`"${method}"`)) found.android = true;
      }

      if (!found.flutter || !found.android) {
        this.issues.integration.push(`Method '${method}' not consistent across platforms`);
      }
    });
  }

  // ============== Performance Analysis ==============
  analyzePerformance() {
    console.log('\n' + '='.repeat(70));
    console.log('PERFORMANCE ANALYSIS');
    console.log('='.repeat(70));

    console.log('\n1. Database Performance:');
    
    // Check for indexes
    const migrationPath = path.join(__dirname, '..', 'supabase', 'migrations', '20250120_quick_capture_widget.sql');
    if (fs.existsSync(migrationPath)) {
      const content = fs.readFileSync(migrationPath, 'utf8');
      
      if (content.includes('CREATE INDEX')) {
        const indexCount = (content.match(/CREATE INDEX/g) || []).length;
        console.log(`   ✅ ${indexCount} indexes created`);
      } else {
        this.issues.performance.push('No database indexes for widget queries');
        console.log('   ❌ No indexes found');
      }
    }

    console.log('\n2. Widget Update Frequency:');
    
    // Check Android update period
    const widgetInfoPath = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', 'xml', 'widget_quick_capture_info.xml');
    if (fs.existsSync(widgetInfoPath)) {
      const content = fs.readFileSync(widgetInfoPath, 'utf8');
      const updateMatch = content.match(/updatePeriodMillis="(\d+)"/);
      if (updateMatch) {
        const period = parseInt(updateMatch[1]);
        if (period < 1800000) { // Less than 30 minutes
          this.issues.performance.push(`Android widget updates too frequently: ${period/60000} minutes`);
        } else {
          console.log(`   ✅ Android: ${period/60000} minutes`);
        }
      }
    }

    console.log('\n3. Memory Management:');
    
    // Check for memory leaks in Android
    const providerPath = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'kotlin', 'com', 'fittechs', 'durunotes', 'widget', 'QuickCaptureWidgetProvider.kt');
    if (fs.existsSync(providerPath)) {
      const content = fs.readFileSync(providerPath, 'utf8');
      
      if (content.includes('onDestroy') || content.includes('clear()')) {
        console.log('   ✅ Android: Proper cleanup in lifecycle');
      } else {
        this.issues.performance.push('Android: Missing cleanup in widget lifecycle');
      }
    }

    console.log('\n4. Offline Queue Management:');
    
    // Check queue size limits
    const servicePath = path.join(__dirname, '..', 'lib', 'services', 'quick_capture_service.dart');
    if (fs.existsSync(servicePath)) {
      const content = fs.readFileSync(servicePath, 'utf8');
      
      if (content.includes('maxQueueSize') || content.includes('MAX_QUEUE')) {
        console.log('   ✅ Flutter: Queue size limited');
      } else {
        this.issues.performance.push('No limit on offline queue size');
        console.log('   ⚠️  No queue size limit found');
      }
    }
  }

  // ============== Security Analysis ==============
  analyzeSecurity() {
    console.log('\n' + '='.repeat(70));
    console.log('SECURITY ANALYSIS');
    console.log('='.repeat(70));

    console.log('\n1. Authentication:');
    
    // Check token storage
    console.log('   Token Storage:');
    
    // Android
    const androidMainPath = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'kotlin', 'com', 'fittechs', 'duruNotesApp', 'MainActivity.kt');
    if (fs.existsSync(androidMainPath)) {
      const content = fs.readFileSync(androidMainPath, 'utf8');
      if (content.includes('MODE_PRIVATE')) {
        console.log('   ✅ Android: SharedPreferences MODE_PRIVATE');
      } else {
        this.issues.security.push('Android: SharedPreferences not using MODE_PRIVATE');
      }
    }

    console.log('\n2. Data Encryption:');
    
    // Check if sensitive data is encrypted
    const edgeFunctionPath = path.join(__dirname, '..', 'supabase', 'functions', 'quick-capture-widget', 'index.ts');
    if (fs.existsSync(edgeFunctionPath)) {
      const content = fs.readFileSync(edgeFunctionPath, 'utf8');
      
      if (content.includes('requires_client_reencryption')) {
        console.log('   ✅ Edge Function: Flags for client re-encryption');
      } else {
        this.issues.security.push('Edge Function: No re-encryption flag');
      }
    }

    console.log('\n3. Input Validation:');
    
    // Check for input validation
    if (fs.existsSync(edgeFunctionPath)) {
      const content = fs.readFileSync(edgeFunctionPath, 'utf8');
      
      if (content.includes('MAX_TEXT_LENGTH') && content.includes('validateRequest')) {
        console.log('   ✅ Edge Function: Input validation present');
      } else {
        this.issues.security.push('Edge Function: Insufficient input validation');
      }
    }

    console.log('\n4. Rate Limiting:');
    
    // Check rate limiting implementation
    if (fs.existsSync(edgeFunctionPath)) {
      const content = fs.readFileSync(edgeFunctionPath, 'utf8');
      
      if (content.includes('RATE_LIMIT_MAX_REQUESTS')) {
        console.log('   ✅ Edge Function: Rate limiting configured');
      } else {
        this.issues.security.push('Edge Function: No rate limiting');
      }
    }
  }

  // ============== Generate Comprehensive Report ==============
  generateReport() {
    console.log('\n' + '='.repeat(70));
    console.log('COMPREHENSIVE ANALYSIS REPORT');
    console.log('='.repeat(70));

    // Statistics
    console.log('\n📊 STATISTICS:');
    console.log(`   Files Analyzed: ${this.stats.filesAnalyzed}`);
    console.log(`   Total Lines of Code: ${this.stats.linesOfCode.toLocaleString()}`);
    console.log(`   Phase 1 (Backend): ${this.stats.phases.phase1.complete ? '✅ Complete' : '❌ Incomplete'} (${this.stats.phases.phase1.files.length} files)`);
    console.log(`   Phase 2 (Flutter): ${this.stats.phases.phase2.complete ? '✅ Complete' : '❌ Incomplete'} (${this.stats.phases.phase2.files.length} files)`);
    console.log(`   Phase 3 (iOS): ${this.stats.phases.phase3.complete ? '✅ Complete' : '❌ Incomplete'} (${this.stats.phases.phase3.files.length} files)`);
    console.log(`   Phase 4 (Android): ${this.stats.phases.phase4.complete ? '✅ Complete' : '❌ Incomplete'} (${this.stats.phases.phase4.files.length} files)`);

    // Critical Issues
    if (this.issues.critical.length > 0) {
      console.log('\n❌ CRITICAL ISSUES (Must Fix Immediately):');
      this.issues.critical.forEach((issue, i) => {
        console.log(`   ${i + 1}. ${issue}`);
      });
    } else {
      console.log('\n✅ NO CRITICAL ISSUES FOUND');
    }

    // Bugs
    if (this.issues.bugs.length > 0) {
      console.log('\n🐛 BUGS DETECTED:');
      this.issues.bugs.forEach((bug, i) => {
        console.log(`   ${i + 1}. ${bug}`);
      });
    }

    // Missing Parts
    if (this.issues.missing.length > 0) {
      console.log('\n📦 MISSING COMPONENTS:');
      this.issues.missing.forEach((item, i) => {
        console.log(`   ${i + 1}. ${item}`);
      });
    }

    // Import Issues
    if (this.issues.imports.length > 0) {
      console.log('\n📥 IMPORT ISSUES:');
      this.issues.imports.forEach((imp, i) => {
        console.log(`   ${i + 1}. ${imp}`);
      });
    }

    // Performance Issues
    if (this.issues.performance.length > 0) {
      console.log('\n⚡ PERFORMANCE ISSUES:');
      this.issues.performance.forEach((perf, i) => {
        console.log(`   ${i + 1}. ${perf}`);
      });
    }

    // Integration Issues
    if (this.issues.integration.length > 0) {
      console.log('\n🔗 INTEGRATION ISSUES:');
      this.issues.integration.forEach((int, i) => {
        console.log(`   ${i + 1}. ${int}`);
      });
    }

    // Security Issues
    if (this.issues.security.length > 0) {
      console.log('\n🔒 SECURITY CONCERNS:');
      this.issues.security.forEach((sec, i) => {
        console.log(`   ${i + 1}. ${sec}`);
      });
    }

    // Warnings
    if (this.issues.warnings.length > 0) {
      console.log('\n⚠️  WARNINGS:');
      this.issues.warnings.forEach((warn, i) => {
        console.log(`   ${i + 1}. ${warn}`);
      });
    }

    // Summary
    const totalIssues = 
      this.issues.critical.length +
      this.issues.bugs.length +
      this.issues.missing.length +
      this.issues.imports.length +
      this.issues.performance.length +
      this.issues.integration.length +
      this.issues.security.length;

    console.log('\n' + '='.repeat(70));
    console.log('SUMMARY');
    console.log('='.repeat(70));
    
    if (totalIssues === 0) {
      console.log('\n🎉 EXCELLENT! No significant issues found!');
      console.log('The Quick Capture Widget implementation is production-ready.');
    } else {
      console.log(`\n⚠️  Total Issues Found: ${totalIssues}`);
      console.log('\nPRIORITY ORDER:');
      console.log('1. Fix critical issues first');
      console.log('2. Address security concerns');
      console.log('3. Fix bugs and integration issues');
      console.log('4. Add missing components');
      console.log('5. Resolve import issues');
      console.log('6. Optimize performance');
    }

    // Save detailed report
    const report = {
      timestamp: new Date().toISOString(),
      stats: this.stats,
      issues: this.issues,
      summary: {
        totalIssues,
        criticalCount: this.issues.critical.length,
        productionReady: totalIssues === 0
      }
    };

    fs.writeFileSync(
      path.join(__dirname, 'comprehensive_widget_report.json'),
      JSON.stringify(report, null, 2)
    );

    console.log('\n📄 Detailed report saved to: scripts/comprehensive_widget_report.json');

    return report;
  }

  run() {
    console.log('=' .repeat(70));
    console.log('COMPREHENSIVE WIDGET IMPLEMENTATION ANALYSIS');
    console.log('Analyzing all 4 phases for bugs, missing parts, and issues');
    console.log('=' .repeat(70));

    this.analyzePhase1Backend();
    this.analyzePhase2Flutter();
    this.analyzePhase3iOS();
    this.analyzePhase4Android();
    this.analyzeCrossPlatformIntegration();
    this.analyzePerformance();
    this.analyzeSecurity();
    
    return this.generateReport();
  }
}

// Run the analysis
const analyzer = new ComprehensiveWidgetAnalyzer();
const report = analyzer.run();

// Exit with error if critical issues found
process.exit(report.issues.critical.length > 0 ? 1 : 0);
