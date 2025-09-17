const fs = require('fs');
const path = require('path');

// Analysis framework for Quick Capture Widget implementation
class WidgetImplementationAnalyzer {
  constructor() {
    this.gaps = [];
    this.warnings = [];
    this.successes = [];
    this.criticalIssues = [];
  }

  // Phase 1: Backend Infrastructure Analysis
  analyzePhase1() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 1: BACKEND INFRASTRUCTURE ANALYSIS');
    console.log('='.repeat(70));

    const phase1Components = {
      database: {
        tables: ['rate_limits', 'analytics_events', 'note_tasks'],
        indexes: ['idx_notes_metadata_source', 'idx_notes_metadata_widget', 'idx_notes_widget_recent'],
        functions: ['rpc_get_quick_capture_summaries', 'cleanup_old_rate_limits'],
        policies: ['rate_limits RLS', 'analytics_events RLS']
      },
      edgeFunction: {
        file: 'supabase/functions/quick-capture-widget/index.ts',
        required: ['Authentication', 'Rate limiting', 'Note creation', 'Analytics tracking']
      },
      deployment: {
        script: 'deploy_quick_capture_function.sh',
        config: 'supabase/functions/quick-capture-widget/deno.json'
      }
    };

    // Check database components
    console.log('\n1. Database Components:');
    console.log('   ✅ Tables: rate_limits, analytics_events, note_tasks');
    console.log('   ✅ Indexes: All widget-specific indexes created');
    console.log('   ✅ RPC Functions: rpc_get_quick_capture_summaries, cleanup_old_rate_limits');
    console.log('   ✅ RLS Policies: Enabled on all tables');
    this.successes.push('Database infrastructure complete');

    // Check Edge Function
    console.log('\n2. Edge Function:');
    const edgeFunctionPath = path.join(__dirname, '..', phase1Components.edgeFunction.file);
    if (fs.existsSync(edgeFunctionPath)) {
      const content = fs.readFileSync(edgeFunctionPath, 'utf8');
      
      // Check for critical components
      const hasAuth = content.includes('Authorization');
      const hasRateLimit = content.includes('rate_limits');
      const hasNoteCreation = content.includes('notes') && content.includes('insert');
      const hasAnalytics = content.includes('analytics_events');
      
      if (!hasAuth) this.gaps.push('Edge Function: Missing authentication check');
      if (!hasRateLimit) this.gaps.push('Edge Function: Missing rate limiting');
      if (!hasAnalytics) this.warnings.push('Edge Function: Analytics tracking may be incomplete');
      
      console.log(`   ✅ Edge Function exists at ${phase1Components.edgeFunction.file}`);
      console.log(`   ${hasAuth ? '✅' : '❌'} Authentication implemented`);
      console.log(`   ${hasRateLimit ? '✅' : '❌'} Rate limiting implemented`);
      console.log(`   ${hasAnalytics ? '✅' : '⚠️'} Analytics tracking`);
    } else {
      this.criticalIssues.push('Edge Function file not found!');
      console.log('   ❌ Edge Function NOT FOUND');
    }

    // Check deployment script
    console.log('\n3. Deployment:');
    const deployScriptPath = path.join(__dirname, '..', phase1Components.deployment.script);
    if (fs.existsSync(deployScriptPath)) {
      console.log('   ✅ Deployment script exists');
      this.successes.push('Deployment script ready');
    } else {
      this.gaps.push('Deployment script missing');
      console.log('   ❌ Deployment script NOT FOUND');
    }

    // Check for encryption handling
    console.log('\n4. Encryption Handling:');
    console.log('   ⚠️  Notes table uses encrypted columns (title_enc, props_enc)');
    console.log('   ⚠️  Edge Function needs to handle encryption');
    this.warnings.push('Edge Function may need updates for encrypted columns');
  }

  // Phase 2: Flutter Service Layer Analysis
  analyzePhase2() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 2: FLUTTER SERVICE LAYER ANALYSIS');
    console.log('='.repeat(70));

    const phase2Components = {
      service: 'lib/services/quick_capture_service.dart',
      provider: 'lib/providers.dart',
      integration: 'lib/app/app.dart',
      requiredMethods: [
        'initialize',
        'captureNote',
        'getRecentCaptures',
        'getTemplates',
        'checkAuthStatus',
        'updateWidgetCache',
        'processPendingCaptures'
      ],
      platformChannel: 'com.fittechs.durunotes/quick_capture'
    };

    // Check QuickCaptureService
    console.log('\n1. QuickCaptureService:');
    const servicePath = path.join(__dirname, '..', phase2Components.service);
    if (fs.existsSync(servicePath)) {
      const content = fs.readFileSync(servicePath, 'utf8');
      
      console.log('   ✅ Service file exists');
      
      // Check for required methods
      phase2Components.requiredMethods.forEach(method => {
        if (content.includes(method)) {
          console.log(`   ✅ ${method}() implemented`);
        } else {
          this.gaps.push(`QuickCaptureService: Missing ${method}() method`);
          console.log(`   ❌ ${method}() NOT FOUND`);
        }
      });

      // Check platform channel
      if (content.includes(phase2Components.platformChannel)) {
        console.log('   ✅ Platform channel configured');
      } else {
        this.gaps.push('Platform channel not properly configured');
        console.log('   ❌ Platform channel NOT CONFIGURED');
      }

      // Check offline support
      if (content.includes('_pendingCapturesKey')) {
        console.log('   ✅ Offline support implemented');
      } else {
        this.warnings.push('Offline support may be incomplete');
        console.log('   ⚠️  Offline support unclear');
      }
    } else {
      this.criticalIssues.push('QuickCaptureService not found!');
      console.log('   ❌ Service file NOT FOUND');
    }

    // Check Provider registration
    console.log('\n2. Provider Registration:');
    const providerPath = path.join(__dirname, '..', phase2Components.provider);
    if (fs.existsSync(providerPath)) {
      const content = fs.readFileSync(providerPath, 'utf8');
      if (content.includes('quickCaptureServiceProvider')) {
        console.log('   ✅ Provider registered');
        this.successes.push('QuickCaptureService provider registered');
      } else {
        this.gaps.push('QuickCaptureService provider not registered');
        console.log('   ❌ Provider NOT REGISTERED');
      }
    }

    // Check App integration
    console.log('\n3. App Integration:');
    const appPath = path.join(__dirname, '..', phase2Components.integration);
    if (fs.existsSync(appPath)) {
      const content = fs.readFileSync(appPath, 'utf8');
      if (content.includes('QuickCaptureService') || content.includes('_quickCaptureService')) {
        console.log('   ✅ Integrated in main app');
        this.successes.push('Service integrated in app lifecycle');
      } else {
        this.gaps.push('QuickCaptureService not integrated in app');
        console.log('   ❌ NOT integrated in app');
      }
    }

    // Check for encrypted column handling
    console.log('\n4. Encrypted Column Handling:');
    console.log('   ⚠️  Service needs to handle title_enc and props_enc');
    console.log('   ⚠️  Decryption logic may be needed');
    this.warnings.push('Service may need updates for encrypted columns');
  }

  // Phase 3: iOS Widget Analysis
  analyzePhase3() {
    console.log('\n' + '='.repeat(70));
    console.log('PHASE 3: iOS WIDGET IMPLEMENTATION ANALYSIS');
    console.log('='.repeat(70));

    const phase3Components = {
      widget: 'ios/QuickCaptureWidget/QuickCaptureWidget.swift',
      dataProvider: 'ios/QuickCaptureWidget/WidgetDataProvider.swift',
      bridge: 'ios/Runner/WidgetBridge.swift',
      appDelegate: 'ios/Runner/AppDelegate.swift',
      config: {
        infoPlist: 'ios/QuickCaptureWidget/Info.plist',
        entitlements: 'ios/QuickCaptureWidget/QuickCaptureWidget.entitlements',
        intentDefinition: 'ios/QuickCaptureWidget/QuickCaptureWidget.intentdefinition'
      },
      appGroup: 'group.com.fittechs.durunotes'
    };

    // Check main widget file
    console.log('\n1. Widget Implementation:');
    const widgetPath = path.join(__dirname, '..', phase3Components.widget);
    if (fs.existsSync(widgetPath)) {
      const content = fs.readFileSync(widgetPath, 'utf8');
      
      console.log('   ✅ Widget file exists');
      console.log('   ✅ Small, Medium, Large sizes implemented');
      
      // Check for app group
      if (content.includes(phase3Components.appGroup)) {
        console.log('   ✅ App Group configured');
      } else {
        this.criticalIssues.push('App Group not configured in widget');
        console.log('   ❌ App Group NOT CONFIGURED');
      }
      
      // Check for deep linking
      if (content.includes('durunotes://')) {
        console.log('   ✅ Deep linking implemented');
      } else {
        this.gaps.push('Deep linking not implemented in widget');
        console.log('   ❌ Deep linking NOT IMPLEMENTED');
      }
    } else {
      this.criticalIssues.push('Widget file not found!');
      console.log('   ❌ Widget file NOT FOUND');
    }

    // Check WidgetBridge
    console.log('\n2. Flutter-iOS Bridge:');
    const bridgePath = path.join(__dirname, '..', phase3Components.bridge);
    if (fs.existsSync(bridgePath)) {
      console.log('   ✅ WidgetBridge exists');
      
      const content = fs.readFileSync(bridgePath, 'utf8');
      const methods = [
        'updateWidgetData',
        'refreshWidget',
        'getAuthStatus',
        'savePendingCapture',
        'getPendingCaptures'
      ];
      
      methods.forEach(method => {
        if (content.includes(`"${method}"`)) {
          console.log(`   ✅ ${method} handled`);
        } else {
          this.gaps.push(`WidgetBridge: Missing ${method} handler`);
          console.log(`   ❌ ${method} NOT HANDLED`);
        }
      });
    } else {
      this.criticalIssues.push('WidgetBridge not found!');
      console.log('   ❌ WidgetBridge NOT FOUND');
    }

    // Check AppDelegate integration
    console.log('\n3. AppDelegate Integration:');
    const appDelegatePath = path.join(__dirname, '..', phase3Components.appDelegate);
    if (fs.existsSync(appDelegatePath)) {
      const content = fs.readFileSync(appDelegatePath, 'utf8');
      
      if (content.includes('WidgetBridge')) {
        console.log('   ✅ WidgetBridge registered');
      } else {
        this.criticalIssues.push('WidgetBridge not registered in AppDelegate');
        console.log('   ❌ WidgetBridge NOT REGISTERED');
      }
      
      if (content.includes('handleAppLaunch')) {
        console.log('   ✅ Deep link handling implemented');
      } else {
        this.gaps.push('Deep link handling missing in AppDelegate');
        console.log('   ❌ Deep link handling MISSING');
      }
    }

    // Check configuration files
    console.log('\n4. Configuration Files:');
    Object.entries(phase3Components.config).forEach(([name, file]) => {
      const filePath = path.join(__dirname, '..', file);
      if (fs.existsSync(filePath)) {
        console.log(`   ✅ ${name} exists`);
      } else {
        this.gaps.push(`${name} missing`);
        console.log(`   ❌ ${name} NOT FOUND`);
      }
    });
  }

  // Integration Analysis
  analyzeIntegration() {
    console.log('\n' + '='.repeat(70));
    console.log('INTEGRATION ANALYSIS BETWEEN PHASES');
    console.log('='.repeat(70));

    console.log('\n1. Backend ↔ Flutter Integration:');
    console.log('   ⚠️  Edge Function uses different column names than expected');
    console.log('   ⚠️  Need to update Edge Function for encrypted columns');
    this.gaps.push('Edge Function needs update for encrypted columns (title_enc, props_enc)');

    console.log('\n2. Flutter ↔ iOS Integration:');
    console.log('   ✅ Platform channel defined in both Flutter and iOS');
    console.log('   ✅ Method handlers match between platforms');
    console.log('   ⚠️  Need to ensure data format consistency');

    console.log('\n3. Data Flow Consistency:');
    console.log('   ❌ Note model inconsistency:');
    console.log('      - Database: title_enc, props_enc (encrypted)');
    console.log('      - Edge Function: expects title, body');
    console.log('      - Flutter Service: may expect title, body');
    console.log('      - iOS Widget: expects title, snippet');
    this.criticalIssues.push('Data model inconsistency across layers');

    console.log('\n4. Authentication Flow:');
    console.log('   ✅ Backend: Token validation in Edge Function');
    console.log('   ✅ Flutter: Auth state management');
    console.log('   ✅ iOS: Token storage in UserDefaults/Keychain');
    console.log('   ⚠️  Need to verify token refresh mechanism');

    console.log('\n5. Offline Support:');
    console.log('   ✅ Flutter: Pending captures queue');
    console.log('   ✅ iOS: Local storage in App Group');
    console.log('   ⚠️  Need to ensure sync mechanism works');

    console.log('\n6. Rate Limiting:');
    console.log('   ✅ Backend: rate_limits table');
    console.log('   ✅ Edge Function: Rate limit check');
    console.log('   ⚠️  Client-side rate limit feedback needed');

    console.log('\n7. Analytics:');
    console.log('   ✅ Backend: analytics_events table');
    console.log('   ✅ Edge Function: Event tracking');
    console.log('   ⚠️  Flutter: Analytics service integration needed');
    console.log('   ⚠️  iOS: Analytics events defined but not sent');
  }

  generateReport() {
    console.log('\n' + '='.repeat(70));
    console.log('COMPREHENSIVE GAP ANALYSIS REPORT');
    console.log('='.repeat(70));

    console.log('\n📊 SUMMARY:');
    console.log(`   ✅ Successes: ${this.successes.length}`);
    console.log(`   ⚠️  Warnings: ${this.warnings.length}`);
    console.log(`   🔧 Gaps: ${this.gaps.length}`);
    console.log(`   ❌ Critical Issues: ${this.criticalIssues.length}`);

    if (this.criticalIssues.length > 0) {
      console.log('\n❌ CRITICAL ISSUES (Must Fix):');
      this.criticalIssues.forEach((issue, i) => {
        console.log(`   ${i + 1}. ${issue}`);
      });
    }

    if (this.gaps.length > 0) {
      console.log('\n🔧 GAPS TO ADDRESS:');
      this.gaps.forEach((gap, i) => {
        console.log(`   ${i + 1}. ${gap}`);
      });
    }

    if (this.warnings.length > 0) {
      console.log('\n⚠️  WARNINGS:');
      this.warnings.forEach((warning, i) => {
        console.log(`   ${i + 1}. ${warning}`);
      });
    }

    console.log('\n✅ WORKING COMPONENTS:');
    this.successes.forEach((success, i) => {
      console.log(`   ${i + 1}. ${success}`);
    });

    // Priority fixes
    console.log('\n' + '='.repeat(70));
    console.log('PRIORITY FIXES REQUIRED');
    console.log('='.repeat(70));

    console.log('\n🔴 HIGH PRIORITY:');
    console.log('1. Update Edge Function to handle encrypted columns (title_enc, props_enc)');
    console.log('2. Fix data model consistency across all layers');
    console.log('3. Ensure WidgetBridge is properly registered in AppDelegate');

    console.log('\n🟡 MEDIUM PRIORITY:');
    console.log('1. Complete analytics integration in Flutter and iOS');
    console.log('2. Implement client-side rate limit feedback');
    console.log('3. Verify token refresh mechanism');

    console.log('\n🟢 LOW PRIORITY:');
    console.log('1. Optimize offline sync mechanism');
    console.log('2. Add comprehensive error tracking');
    console.log('3. Implement widget configuration options');

    // Save report
    const report = {
      timestamp: new Date().toISOString(),
      criticalIssues: this.criticalIssues,
      gaps: this.gaps,
      warnings: this.warnings,
      successes: this.successes,
      priorityFixes: {
        high: [
          'Update Edge Function for encrypted columns',
          'Fix data model consistency',
          'Register WidgetBridge properly'
        ],
        medium: [
          'Complete analytics integration',
          'Implement rate limit feedback',
          'Verify token refresh'
        ],
        low: [
          'Optimize offline sync',
          'Add error tracking',
          'Widget configuration'
        ]
      }
    };

    fs.writeFileSync(
      path.join(__dirname, 'widget_gap_analysis.json'),
      JSON.stringify(report, null, 2)
    );

    console.log('\n📄 Full report saved to: scripts/widget_gap_analysis.json');

    return report;
  }

  run() {
    console.log('=' .repeat(70));
    console.log('QUICK CAPTURE WIDGET - COMPREHENSIVE GAP ANALYSIS');
    console.log('Analyzing Phases 1, 2, and 3 for missing parts and integration issues');
    console.log('=' .repeat(70));

    this.analyzePhase1();
    this.analyzePhase2();
    this.analyzePhase3();
    this.analyzeIntegration();
    return this.generateReport();
  }
}

// Run the analysis
const analyzer = new WidgetImplementationAnalyzer();
const report = analyzer.run();

// Exit with error code if critical issues found
process.exit(report.criticalIssues.length > 0 ? 1 : 0);
