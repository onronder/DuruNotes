// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get notesListTitle => 'My Notes';

  @override
  String get createNewNote => 'Create New Note';

  @override
  String get searchNotes => 'Search Notes';

  @override
  String get noNotesYet => 'No notes yet';

  @override
  String get tapToCreateFirstNote => 'Tap + to create your first note';

  @override
  String get createFirstNote => 'Create First Note';

  @override
  String get importNotes => 'Import Notes';

  @override
  String get exportNotes => 'Export Notes';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get signOut => 'Sign Out';

  @override
  String get logout => 'Sign Out';

  @override
  String get import => 'Import';

  @override
  String get export => 'Export';

  @override
  String get importNotesTitle => 'Import Notes';

  @override
  String get exportNotesTitle => 'Export Notes';

  @override
  String get chooseWhatToImport => 'Choose what to import:';

  @override
  String get exportYourNotes => 'Export your notes to various formats:';

  @override
  String availableNotes(int count) {
    return 'Available notes: $count';
  }

  @override
  String get markdownFiles => 'Markdown Files';

  @override
  String get evernoteExport => 'Evernote Export';

  @override
  String get obsidianVault => 'Obsidian Vault';

  @override
  String get importSingleMdFiles => 'Import single .md or .markdown files';

  @override
  String get importEnexFiles => 'Import .enex files from Evernote';

  @override
  String get importObsidianVaultFolder => 'Import entire Obsidian vault folder';

  @override
  String get selectImportType => 'Select Import Type';

  @override
  String get markdown => 'Markdown';

  @override
  String get pdf => 'PDF';

  @override
  String get html => 'HTML';

  @override
  String get exportAsMdFiles => 'Export as .md files with full formatting';

  @override
  String get exportAsPdfDocs => 'Export as PDF documents for sharing';

  @override
  String get exportAsWebPages => 'Export as web pages with styling';

  @override
  String get selectExportFormat => 'Select Export Format';

  @override
  String get chooseFormat => 'Choose Format';

  @override
  String get exportAllNotes => 'Export All Notes';

  @override
  String get exportRecentNotes => 'Export Recent Notes';

  @override
  String get exportLatest10 => 'Export Latest 10';

  @override
  String exportAllNotesDesc(int count) {
    return 'Export all $count notes';
  }

  @override
  String get exportRecentNotesDesc => 'Export notes from the last 30 days';

  @override
  String get exportLatest10Desc => 'Export the 10 most recent notes';

  @override
  String get importingNotes => 'Importing Notes';

  @override
  String exportingToFormat(String format) {
    return 'Exporting to $format';
  }

  @override
  String get initializingImport => 'Initializing import...';

  @override
  String get initializingExport => 'Initializing export...';

  @override
  String currentFile(String filename) {
    return 'File: $filename';
  }

  @override
  String progressCount(int current, int total) {
    return 'Progress: $current/$total';
  }

  @override
  String noteProgress(int current, int total) {
    return 'Note: $current/$total';
  }

  @override
  String currentNote(String title) {
    return 'Current: $title';
  }

  @override
  String get overallProgress => 'Overall Progress:';

  @override
  String estimatedTimeRemaining(String time) {
    return 'Estimated time remaining: $time';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get importComplete => 'Import Complete';

  @override
  String get exportComplete => 'Export Complete';

  @override
  String successfullyImported(int count) {
    return '✅ Successfully imported: $count notes';
  }

  @override
  String successfullyExported(int count) {
    return '✅ Successfully exported: $count notes';
  }

  @override
  String errorsEncountered(int count) {
    return '⚠️ Errors encountered: $count';
  }

  @override
  String importTook(int seconds) {
    return '⏱️ Import took: $seconds seconds';
  }

  @override
  String exportTook(int seconds) {
    return '⏱️ Export took: $seconds seconds';
  }

  @override
  String totalSize(String size) {
    return '📁 Total size: $size';
  }

  @override
  String get errorDetails => 'Error details:';

  @override
  String get filesSavedToDownloads => 'Files saved to Downloads folder';

  @override
  String get failedExports => 'Failed exports:';

  @override
  String get shareFiles => 'Share Files';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get close => 'Close';

  @override
  String get importError => 'Import Error';

  @override
  String get exportError => 'Export Error';

  @override
  String get noNotesToExport => 'No notes to export';

  @override
  String get failedToSelectMarkdownFiles => 'Failed to select Markdown files';

  @override
  String get failedToSelectEvernoteFile => 'Failed to select Evernote file';

  @override
  String get failedToSelectObsidianVault => 'Failed to select Obsidian vault';

  @override
  String get importFailed => 'Import failed';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get obsidianImportFailed => 'Obsidian import failed';

  @override
  String get noFilesAvailableToShare => 'No files available to share';

  @override
  String get failedToShareExportedFile => 'Failed to share exported file';

  @override
  String get errorSharingFiles => 'Error sharing files';

  @override
  String get couldNotOpenExportsFolder => 'Could not open exports folder';

  @override
  String get pdfExportMayFailInSimulator =>
      'PDF export may fail in simulator due to network restrictions. Try:';

  @override
  String get testOnPhysicalDevice => '• Test on a physical device';

  @override
  String get checkInternetConnection => '• Check your internet connection';

  @override
  String get tryExportingAsMarkdown => '• Try exporting as Markdown instead';

  @override
  String get networkRelatedIssueDetected =>
      'Network-related issue detected. Try:';

  @override
  String get tryAgainInFewMoments => '• Try again in a few moments';

  @override
  String get useDifferentExportFormat => '• Use a different export format';

  @override
  String get tryMarkdown => 'Try Markdown';

  @override
  String get editNote => 'Edit Note';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get untitled => 'Untitled';

  @override
  String get noContent => 'No content';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count minutes ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String areYouSureDeleteNote(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get errorDeletingNote => 'Error deleting note';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get loading => 'Loading…';

  @override
  String get retry => 'Retry';

  @override
  String get errorLoadingNotes => 'Error loading notes';

  @override
  String get searchFeatureTemporarilyDisabled =>
      'Search feature temporarily disabled';

  @override
  String get exportFunctionalityComingSoon =>
      'Export functionality coming soon';

  @override
  String get settingsScreenComingSoon => 'Settings screen coming soon';

  @override
  String get areYouSureSignOut => 'Are you sure you want to sign out?';

  @override
  String get productionGradeImportSystemReady =>
      'Production-grade import system ready!';

  @override
  String get supportedFormats => 'Supported formats:';

  @override
  String get singleMarkdownFiles => '• Single Markdown files (.md, .markdown)';

  @override
  String get evernoteFiles => '• Evernote export files (.enex)';

  @override
  String get obsidianVaultFolders => '• Obsidian vault folders';

  @override
  String get importFeatures => 'Features:';

  @override
  String get securityValidation => '• Security validation';

  @override
  String get progressTracking => '• Progress tracking';

  @override
  String get errorRecovery => '• Error recovery';

  @override
  String get contentSanitization => '• Content sanitization';

  @override
  String get featuresSecurityValidation =>
      'Features: Security validation, progress tracking, error recovery';

  @override
  String get exportAsMarkdownFiles => '• Export as Markdown files';

  @override
  String get exportAsPdfDocuments => '• Export as PDF documents';

  @override
  String get exportAsHtmlFiles => '• Export as HTML files';

  @override
  String get featuresRichFormatting =>
      'Features: Rich formatting, metadata, attachments';

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String get checkDownloadsFolderForFiles =>
      'Check your Downloads folder for exported files';

  @override
  String get filesSavedInAppDocuments =>
      'Files are saved in app Documents folder. Use \"Share Files\" to access them.';

  @override
  String statusPhase(String phase) {
    return 'Status: $phase';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get sync => 'Sync';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get security => 'Security & Privacy';

  @override
  String get importExport => 'Import & Export';

  @override
  String get helpAbout => 'Help & About';

  @override
  String get signedInAs => 'Signed in as';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get manageAccount => 'Manage Account';

  @override
  String get syncMode => 'Sync Mode';

  @override
  String get automaticSync => 'Automatic';

  @override
  String get manualSync => 'Manual';

  @override
  String get automaticSyncDesc => 'Sync changes automatically';

  @override
  String get manualSyncDesc => 'Sync only when requested';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Syncing...';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get systemTheme => 'System Default';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Türkçe';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get openSystemSettings => 'Open System Settings';

  @override
  String get notificationPermissions => 'Notification Permissions';

  @override
  String get endToEndEncryption => 'End-to-End Encryption';

  @override
  String get encryptionEnabled =>
      'Your notes are encrypted with industry-standard encryption';

  @override
  String get analyticsOptIn => 'Usage Analytics';

  @override
  String get analyticsDesc =>
      'Help improve the app by sharing anonymous usage data';

  @override
  String get biometricLock => 'Biometric Lock';

  @override
  String get biometricDesc =>
      'Require biometric authentication to open the app';

  @override
  String get biometricNotAvailable => 'Biometric authentication not available';

  @override
  String get version => 'Version';

  @override
  String get buildNumber => 'Build Number';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get rateApp => 'Rate App';

  @override
  String get userGuide => 'User Guide';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get documentation => 'Documentation';

  @override
  String get aboutApp => 'About App';

  @override
  String get sharedNote => 'Shared Note';

  @override
  String get sharedText => 'Shared Text';

  @override
  String get sharedImage => 'Shared Image';

  @override
  String get sharedLink => 'Shared Link';

  @override
  String get sharedFile => 'Shared File';

  @override
  String sharedFrom(String source, String date) {
    return 'Shared from $source on $date';
  }

  @override
  String get sharedImageCouldNotBeProcessed =>
      'Shared image could not be processed.';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get continueAction => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Finish';

  @override
  String get selectFiles => 'Select Files';

  @override
  String get selectingFiles => 'Selecting files';

  @override
  String get scanningDirectory => 'Scanning directory';

  @override
  String get readingFile => 'Reading file';

  @override
  String get parsingContent => 'Parsing content';

  @override
  String get convertingToBlocks => 'Converting to blocks';

  @override
  String get processingFiles => 'Processing files';

  @override
  String get savingNotes => 'Saving notes';

  @override
  String get completed => 'Completed';

  @override
  String get preparing => 'Preparing';

  @override
  String get rendering => 'Rendering';

  @override
  String get finalizing => 'Finalizing';
}
