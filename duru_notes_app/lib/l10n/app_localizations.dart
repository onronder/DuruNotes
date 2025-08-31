import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @notesListTitle.
  ///
  /// In en, this message translates to:
  /// **'My Notes'**
  String get notesListTitle;

  /// No description provided for @createNewNote.
  ///
  /// In en, this message translates to:
  /// **'Create New Note'**
  String get createNewNote;

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search Notes'**
  String get searchNotes;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesYet;

  /// No description provided for @tapToCreateFirstNote.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first note'**
  String get tapToCreateFirstNote;

  /// No description provided for @createFirstNote.
  ///
  /// In en, this message translates to:
  /// **'Create First Note'**
  String get createFirstNote;

  /// No description provided for @importNotes.
  ///
  /// In en, this message translates to:
  /// **'Import Notes'**
  String get importNotes;

  /// No description provided for @exportNotes.
  ///
  /// In en, this message translates to:
  /// **'Export Notes'**
  String get exportNotes;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get logout;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @importNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Notes'**
  String get importNotesTitle;

  /// No description provided for @exportNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Notes'**
  String get exportNotesTitle;

  /// No description provided for @chooseWhatToImport.
  ///
  /// In en, this message translates to:
  /// **'Choose what to import:'**
  String get chooseWhatToImport;

  /// No description provided for @exportYourNotes.
  ///
  /// In en, this message translates to:
  /// **'Export your notes to various formats:'**
  String get exportYourNotes;

  /// No description provided for @availableNotes.
  ///
  /// In en, this message translates to:
  /// **'Available notes: {count}'**
  String availableNotes(int count);

  /// No description provided for @markdownFiles.
  ///
  /// In en, this message translates to:
  /// **'Markdown Files'**
  String get markdownFiles;

  /// No description provided for @evernoteExport.
  ///
  /// In en, this message translates to:
  /// **'Evernote Export'**
  String get evernoteExport;

  /// No description provided for @obsidianVault.
  ///
  /// In en, this message translates to:
  /// **'Obsidian Vault'**
  String get obsidianVault;

  /// No description provided for @importSingleMdFiles.
  ///
  /// In en, this message translates to:
  /// **'Import single .md or .markdown files'**
  String get importSingleMdFiles;

  /// No description provided for @importEnexFiles.
  ///
  /// In en, this message translates to:
  /// **'Import .enex files from Evernote'**
  String get importEnexFiles;

  /// No description provided for @importObsidianVaultFolder.
  ///
  /// In en, this message translates to:
  /// **'Import entire Obsidian vault folder'**
  String get importObsidianVaultFolder;

  /// No description provided for @selectImportType.
  ///
  /// In en, this message translates to:
  /// **'Select Import Type'**
  String get selectImportType;

  /// No description provided for @markdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get markdown;

  /// No description provided for @pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @html.
  ///
  /// In en, this message translates to:
  /// **'HTML'**
  String get html;

  /// No description provided for @exportAsMdFiles.
  ///
  /// In en, this message translates to:
  /// **'Export as .md files with full formatting'**
  String get exportAsMdFiles;

  /// No description provided for @exportAsPdfDocs.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF documents for sharing'**
  String get exportAsPdfDocs;

  /// No description provided for @exportAsWebPages.
  ///
  /// In en, this message translates to:
  /// **'Export as web pages with styling'**
  String get exportAsWebPages;

  /// No description provided for @selectExportFormat.
  ///
  /// In en, this message translates to:
  /// **'Select Export Format'**
  String get selectExportFormat;

  /// No description provided for @chooseFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose Format'**
  String get chooseFormat;

  /// No description provided for @exportAllNotes.
  ///
  /// In en, this message translates to:
  /// **'Export All Notes'**
  String get exportAllNotes;

  /// No description provided for @exportRecentNotes.
  ///
  /// In en, this message translates to:
  /// **'Export Recent Notes'**
  String get exportRecentNotes;

  /// No description provided for @exportLatest10.
  ///
  /// In en, this message translates to:
  /// **'Export Latest 10'**
  String get exportLatest10;

  /// No description provided for @exportAllNotesDesc.
  ///
  /// In en, this message translates to:
  /// **'Export all {count} notes'**
  String exportAllNotesDesc(int count);

  /// No description provided for @exportRecentNotesDesc.
  ///
  /// In en, this message translates to:
  /// **'Export notes from the last 30 days'**
  String get exportRecentNotesDesc;

  /// No description provided for @exportLatest10Desc.
  ///
  /// In en, this message translates to:
  /// **'Export the 10 most recent notes'**
  String get exportLatest10Desc;

  /// No description provided for @importingNotes.
  ///
  /// In en, this message translates to:
  /// **'Importing Notes'**
  String get importingNotes;

  /// No description provided for @exportingToFormat.
  ///
  /// In en, this message translates to:
  /// **'Exporting to {format}'**
  String exportingToFormat(String format);

  /// No description provided for @initializingImport.
  ///
  /// In en, this message translates to:
  /// **'Initializing import...'**
  String get initializingImport;

  /// No description provided for @initializingExport.
  ///
  /// In en, this message translates to:
  /// **'Initializing export...'**
  String get initializingExport;

  /// No description provided for @currentFile.
  ///
  /// In en, this message translates to:
  /// **'File: {filename}'**
  String currentFile(String filename);

  /// No description provided for @progressCount.
  ///
  /// In en, this message translates to:
  /// **'Progress: {current}/{total}'**
  String progressCount(int current, int total);

  /// No description provided for @noteProgress.
  ///
  /// In en, this message translates to:
  /// **'Note: {current}/{total}'**
  String noteProgress(int current, int total);

  /// No description provided for @currentNote.
  ///
  /// In en, this message translates to:
  /// **'Current: {title}'**
  String currentNote(String title);

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress:'**
  String get overallProgress;

  /// No description provided for @estimatedTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Estimated time remaining: {time}'**
  String estimatedTimeRemaining(String time);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Export Complete'**
  String get exportComplete;

  /// No description provided for @successfullyImported.
  ///
  /// In en, this message translates to:
  /// **'✅ Successfully imported: {count} notes'**
  String successfullyImported(int count);

  /// No description provided for @successfullyExported.
  ///
  /// In en, this message translates to:
  /// **'✅ Successfully exported: {count} notes'**
  String successfullyExported(int count);

  /// No description provided for @errorsEncountered.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Errors encountered: {count}'**
  String errorsEncountered(int count);

  /// No description provided for @importTook.
  ///
  /// In en, this message translates to:
  /// **'⏱️ Import took: {seconds} seconds'**
  String importTook(int seconds);

  /// No description provided for @exportTook.
  ///
  /// In en, this message translates to:
  /// **'⏱️ Export took: {seconds} seconds'**
  String exportTook(int seconds);

  /// No description provided for @totalSize.
  ///
  /// In en, this message translates to:
  /// **'📁 Total size: {size}'**
  String totalSize(String size);

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error details:'**
  String get errorDetails;

  /// No description provided for @filesSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Files saved to Downloads folder'**
  String get filesSavedToDownloads;

  /// No description provided for @failedExports.
  ///
  /// In en, this message translates to:
  /// **'Failed exports:'**
  String get failedExports;

  /// No description provided for @shareFiles.
  ///
  /// In en, this message translates to:
  /// **'Share Files'**
  String get shareFiles;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openFolder;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import Error'**
  String get importError;

  /// No description provided for @exportError.
  ///
  /// In en, this message translates to:
  /// **'Export Error'**
  String get exportError;

  /// No description provided for @noNotesToExport.
  ///
  /// In en, this message translates to:
  /// **'No notes to export'**
  String get noNotesToExport;

  /// No description provided for @failedToSelectMarkdownFiles.
  ///
  /// In en, this message translates to:
  /// **'Failed to select Markdown files'**
  String get failedToSelectMarkdownFiles;

  /// No description provided for @failedToSelectEvernoteFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to select Evernote file'**
  String get failedToSelectEvernoteFile;

  /// No description provided for @failedToSelectObsidianVault.
  ///
  /// In en, this message translates to:
  /// **'Failed to select Obsidian vault'**
  String get failedToSelectObsidianVault;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @obsidianImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Obsidian import failed'**
  String get obsidianImportFailed;

  /// No description provided for @noFilesAvailableToShare.
  ///
  /// In en, this message translates to:
  /// **'No files available to share'**
  String get noFilesAvailableToShare;

  /// No description provided for @failedToShareExportedFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to share exported file'**
  String get failedToShareExportedFile;

  /// No description provided for @errorSharingFiles.
  ///
  /// In en, this message translates to:
  /// **'Error sharing files'**
  String get errorSharingFiles;

  /// No description provided for @couldNotOpenExportsFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not open exports folder'**
  String get couldNotOpenExportsFolder;

  /// No description provided for @pdfExportMayFailInSimulator.
  ///
  /// In en, this message translates to:
  /// **'PDF export may fail in simulator due to network restrictions. Try:'**
  String get pdfExportMayFailInSimulator;

  /// No description provided for @testOnPhysicalDevice.
  ///
  /// In en, this message translates to:
  /// **'• Test on a physical device'**
  String get testOnPhysicalDevice;

  /// No description provided for @checkInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'• Check your internet connection'**
  String get checkInternetConnection;

  /// No description provided for @tryExportingAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'• Try exporting as Markdown instead'**
  String get tryExportingAsMarkdown;

  /// No description provided for @networkRelatedIssueDetected.
  ///
  /// In en, this message translates to:
  /// **'Network-related issue detected. Try:'**
  String get networkRelatedIssueDetected;

  /// No description provided for @tryAgainInFewMoments.
  ///
  /// In en, this message translates to:
  /// **'• Try again in a few moments'**
  String get tryAgainInFewMoments;

  /// No description provided for @useDifferentExportFormat.
  ///
  /// In en, this message translates to:
  /// **'• Use a different export format'**
  String get useDifferentExportFormat;

  /// No description provided for @tryMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Try Markdown'**
  String get tryMarkdown;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get editNote;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNote;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @noContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get noContent;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @areYouSureDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String areYouSureDeleteNote(String title);

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @errorDeletingNote.
  ///
  /// In en, this message translates to:
  /// **'Error deleting note'**
  String get errorDeletingNote;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorLoadingNotes.
  ///
  /// In en, this message translates to:
  /// **'Error loading notes'**
  String get errorLoadingNotes;

  /// No description provided for @searchFeatureTemporarilyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Search feature temporarily disabled'**
  String get searchFeatureTemporarilyDisabled;

  /// No description provided for @exportFunctionalityComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Export functionality coming soon'**
  String get exportFunctionalityComingSoon;

  /// No description provided for @settingsScreenComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Settings screen coming soon'**
  String get settingsScreenComingSoon;

  /// No description provided for @areYouSureSignOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get areYouSureSignOut;

  /// No description provided for @productionGradeImportSystemReady.
  ///
  /// In en, this message translates to:
  /// **'Production-grade import system ready!'**
  String get productionGradeImportSystemReady;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported formats:'**
  String get supportedFormats;

  /// No description provided for @singleMarkdownFiles.
  ///
  /// In en, this message translates to:
  /// **'• Single Markdown files (.md, .markdown)'**
  String get singleMarkdownFiles;

  /// No description provided for @evernoteFiles.
  ///
  /// In en, this message translates to:
  /// **'• Evernote export files (.enex)'**
  String get evernoteFiles;

  /// No description provided for @obsidianVaultFolders.
  ///
  /// In en, this message translates to:
  /// **'• Obsidian vault folders'**
  String get obsidianVaultFolders;

  /// No description provided for @importFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features:'**
  String get importFeatures;

  /// No description provided for @securityValidation.
  ///
  /// In en, this message translates to:
  /// **'• Security validation'**
  String get securityValidation;

  /// No description provided for @progressTracking.
  ///
  /// In en, this message translates to:
  /// **'• Progress tracking'**
  String get progressTracking;

  /// No description provided for @errorRecovery.
  ///
  /// In en, this message translates to:
  /// **'• Error recovery'**
  String get errorRecovery;

  /// No description provided for @contentSanitization.
  ///
  /// In en, this message translates to:
  /// **'• Content sanitization'**
  String get contentSanitization;

  /// No description provided for @featuresSecurityValidation.
  ///
  /// In en, this message translates to:
  /// **'Features: Security validation, progress tracking, error recovery'**
  String get featuresSecurityValidation;

  /// No description provided for @exportAsMarkdownFiles.
  ///
  /// In en, this message translates to:
  /// **'• Export as Markdown files'**
  String get exportAsMarkdownFiles;

  /// No description provided for @exportAsPdfDocuments.
  ///
  /// In en, this message translates to:
  /// **'• Export as PDF documents'**
  String get exportAsPdfDocuments;

  /// No description provided for @exportAsHtmlFiles.
  ///
  /// In en, this message translates to:
  /// **'• Export as HTML files'**
  String get exportAsHtmlFiles;

  /// No description provided for @featuresRichFormatting.
  ///
  /// In en, this message translates to:
  /// **'Features: Rich formatting, metadata, attachments'**
  String get featuresRichFormatting;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get exportCancelled;

  /// No description provided for @checkDownloadsFolderForFiles.
  ///
  /// In en, this message translates to:
  /// **'Check your Downloads folder for exported files'**
  String get checkDownloadsFolderForFiles;

  /// No description provided for @filesSavedInAppDocuments.
  ///
  /// In en, this message translates to:
  /// **'Files are saved in app Documents folder. Use \"Share Files\" to access them.'**
  String get filesSavedInAppDocuments;

  /// No description provided for @statusPhase.
  ///
  /// In en, this message translates to:
  /// **'Status: {phase}'**
  String statusPhase(String phase);

  /// No description provided for @userGuide.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get userGuide;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @documentation.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get documentation;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @sharedNote.
  ///
  /// In en, this message translates to:
  /// **'Shared Note'**
  String get sharedNote;

  /// No description provided for @sharedText.
  ///
  /// In en, this message translates to:
  /// **'Shared Text'**
  String get sharedText;

  /// No description provided for @sharedImage.
  ///
  /// In en, this message translates to:
  /// **'Shared Image'**
  String get sharedImage;

  /// No description provided for @sharedLink.
  ///
  /// In en, this message translates to:
  /// **'Shared Link'**
  String get sharedLink;

  /// No description provided for @sharedFile.
  ///
  /// In en, this message translates to:
  /// **'Shared File'**
  String get sharedFile;

  /// No description provided for @sharedFrom.
  ///
  /// In en, this message translates to:
  /// **'Shared from {source} on {date}'**
  String sharedFrom(String source, String date);

  /// No description provided for @sharedImageCouldNotBeProcessed.
  ///
  /// In en, this message translates to:
  /// **'Shared image could not be processed.'**
  String get sharedImageCouldNotBeProcessed;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFiles;

  /// No description provided for @selectingFiles.
  ///
  /// In en, this message translates to:
  /// **'Selecting files'**
  String get selectingFiles;

  /// No description provided for @scanningDirectory.
  ///
  /// In en, this message translates to:
  /// **'Scanning directory'**
  String get scanningDirectory;

  /// No description provided for @readingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading file'**
  String get readingFile;

  /// No description provided for @parsingContent.
  ///
  /// In en, this message translates to:
  /// **'Parsing content'**
  String get parsingContent;

  /// No description provided for @convertingToBlocks.
  ///
  /// In en, this message translates to:
  /// **'Converting to blocks'**
  String get convertingToBlocks;

  /// No description provided for @processingFiles.
  ///
  /// In en, this message translates to:
  /// **'Processing files'**
  String get processingFiles;

  /// No description provided for @savingNotes.
  ///
  /// In en, this message translates to:
  /// **'Saving notes'**
  String get savingNotes;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @rendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering'**
  String get rendering;

  /// No description provided for @finalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing'**
  String get finalizing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
