// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get notesListTitle => 'Notlarım';

  @override
  String get createNewNote => 'Yeni Not Oluştur';

  @override
  String get searchNotes => 'Notlarda Ara';

  @override
  String get noNotesYet => 'Henüz not yok';

  @override
  String get tapToCreateFirstNote => 'Tap + to create your first note';

  @override
  String get createFirstNote => 'Create First Note';

  @override
  String get importNotes => 'Notları İçe Aktar';

  @override
  String get exportNotes => 'Notları Dışa Aktar';

  @override
  String get settings => 'Ayarlar';

  @override
  String get help => 'Yardım';

  @override
  String get signOut => 'Çıkış Yap';

  @override
  String get logout => 'Sign Out';

  @override
  String get import => 'İçe Aktar';

  @override
  String get export => 'Dışa Aktar';

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
  String get cancel => 'İptal';

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
  String get deleteNote => 'Notu Sil';

  @override
  String get delete => 'Sil';

  @override
  String get edit => 'Düzenle';

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
  String get noteDeleted => 'Not silindi';

  @override
  String get errorDeletingNote => 'Error deleting note';

  @override
  String get welcomeBack => 'Tekrar Hoş Geldiniz';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get loading => 'Yükleniyor';

  @override
  String get retry => 'Tekrar Dene';

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
  String get genericErrorTitle => 'Bir şeyler ters gitti';

  @override
  String get genericErrorMessage =>
      'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  String get reportError => 'Hata bildir';

  @override
  String get errorReportSent =>
      'Hata raporu gönderildi. Geri bildiriminiz için teşekkürler!';

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
  String get language => 'Dil';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get security => 'Güvenlik';

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
  String get syncing => 'Senkronize ediliyor';

  @override
  String get syncComplete => 'Senkronizasyon tamamlandı';

  @override
  String get syncFailed => 'Senkronizasyon başarısız';

  @override
  String get theme => 'Tema';

  @override
  String get lightTheme => 'Açık Tema';

  @override
  String get darkTheme => 'Koyu Tema';

  @override
  String get systemTheme => 'Sistem Teması';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Türkçe';

  @override
  String get enableNotifications => 'Bildirimleri Etkinleştir';

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
  String get version => 'Sürüm';

  @override
  String get buildNumber => 'Build Number';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get termsOfService => 'Kullanım Koşulları';

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
  String get folders => 'Klasörler';

  @override
  String get folderPickerTitle => 'Choose Folder';

  @override
  String get folderPickerSubtitle => 'Organize your note';

  @override
  String get createNewFolder => 'Create New Folder';

  @override
  String get createNewFolderSubtitle => 'Add a new folder for organization';

  @override
  String get newFolder => 'New Folder';

  @override
  String get folderName => 'Klasör Adı';

  @override
  String get folderNameHint => 'e.g., Work, Personal, Ideas';

  @override
  String get folderNameRequired => 'Folder name is required';

  @override
  String get folderNameEmpty => 'Folder name cannot be empty';

  @override
  String get folderNameDuplicate => 'A folder with this name already exists';

  @override
  String get folderColor => 'Color';

  @override
  String get folderIcon => 'Icon';

  @override
  String get parentFolder => 'Parent Folder';

  @override
  String get rootFolder => 'Root (No Parent)';

  @override
  String get rootLevel => 'Root Level';

  @override
  String get description => 'Description';

  @override
  String get optional => 'Optional';

  @override
  String get folderDescriptionHint =>
      'Brief description of this folder\'s purpose';

  @override
  String get selectParentFolder => 'Select Parent Folder';

  @override
  String get unfiledNotes => 'Unfiled Notes';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: 'No notes',
    );
    return '$_temp0';
  }

  @override
  String get searchFolders => 'Search folders...';

  @override
  String get showSearch => 'Show search';

  @override
  String get hideSearch => 'Hide search';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noFoldersFound => 'No folders found';

  @override
  String noFoldersFoundSubtitle(String query) {
    return 'No folders match \'$query\'';
  }

  @override
  String get loadFoldersError => 'Failed to load folders';

  @override
  String get create => 'Create';

  @override
  String get loadError => 'Load error';

  @override
  String get folderManagement => 'Folder Management';

  @override
  String get editFolder => 'Edit Folder';

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String get moveFolder => 'Move Folder';

  @override
  String get folderProperties => 'Folder Properties';

  @override
  String get confirmDeleteFolder => 'Delete this folder?';

  @override
  String get confirmDeleteFolderMessage =>
      'This will move all notes and subfolders to the parent level.';

  @override
  String get confirmDeleteFolderAction => 'Delete Folder';

  @override
  String get addToFolder => 'Add to Folder';

  @override
  String get removeFromFolder => 'Remove from Folder';

  @override
  String get moveToFolder => 'Klasöre Taşı';

  @override
  String get folderEmpty => 'This folder is empty';

  @override
  String get folderEmptySubtitle => 'Add notes to get started';

  @override
  String get allFolders => 'All Folders';

  @override
  String get rename => 'Rename';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get move => 'Move';

  @override
  String get folderRenamed => 'Folder renamed successfully';

  @override
  String get folderMoved => 'Folder moved successfully';

  @override
  String get folderDeleted => 'Folder deleted';

  @override
  String get folderDeletedNotesMovedToInbox =>
      'Folder deleted, notes moved to Inbox';

  @override
  String folderCreated(String name) {
    return 'Folder \"$name\" created';
  }

  @override
  String deleteFolderConfirmation(String name) {
    return 'Delete folder \"$name\"? All notes will be moved to Inbox.';
  }

  @override
  String get folderDeleteDescription => 'Notes will be moved to Inbox';

  @override
  String get errorRenamingFolder => 'Failed to rename folder';

  @override
  String get errorMovingFolder => 'Failed to move folder';

  @override
  String get errorDeletingFolder => 'Failed to delete folder';

  @override
  String get errorCreatingFolder => 'Failed to create folder';

  @override
  String get errorLoadingFolders => 'Failed to load folders';

  @override
  String get cannotMoveToDescendant =>
      'Cannot move folder to its own descendant';

  @override
  String get selectFolder => 'Select Folder';

  @override
  String get unfiled => 'Unfiled';

  @override
  String get createYourFirstFolder => 'Create your first folder';

  @override
  String get expandAll => 'Expand All';

  @override
  String get collapseAll => 'Collapse All';

  @override
  String get save => 'Kaydet';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

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
  String get completed => 'Tamamlandı';

  @override
  String get preparing => 'Preparing';

  @override
  String get rendering => 'Rendering';

  @override
  String get finalizing => 'Finalizing';

  @override
  String get attachments => 'Ekler';

  @override
  String get dateModified => 'Değiştirilme Tarihi';

  @override
  String get highPriority => 'Yüksek Öncelik';

  @override
  String get lowPriority => 'Düşük Öncelik';

  @override
  String get mediumPriority => 'Orta Öncelik';

  @override
  String get noTitle => 'No Title';

  @override
  String get overdue => 'Gecikmiş';

  @override
  String get pinnedNotes => 'Sabitlenmiş Notlar';

  @override
  String get pinNote => 'Notu Sabitle';

  @override
  String get tags => 'Etiketler';

  @override
  String get today => 'Bugün';

  @override
  String get tomorrow => 'Yarın';

  @override
  String get unpinNote => 'Sabitlemeyi Kaldır';

  @override
  String get templatePickerTitle => 'Şablon Seçin';

  @override
  String get templatePickerSubtitle => 'Şablonla veya boş notla başlayın';

  @override
  String get blankNoteOption => 'Boş Not';

  @override
  String get blankNoteDescription => 'Boş bir notla başla';

  @override
  String get noTemplatesTitle => 'Henüz Şablon Yok';

  @override
  String get noTemplatesDescription =>
      'Sık kullandığınız yapıları tekrar kullanmak için ilk şablonunuzu oluşturun';

  @override
  String get templatesSection => 'ŞABLONLAR';

  @override
  String get saveAsTemplate => 'Şablon Olarak Kaydet';

  @override
  String get fromTemplate => 'Şablondan';

  @override
  String templateSaved(String title) {
    return 'Şablon kaydedildi: $title';
  }

  @override
  String get failedToSaveTemplate => 'Şablon kaydedilemedi';

  @override
  String get cannotSaveEmptyTemplate => 'Boş not şablon olarak kaydedilemez';

  @override
  String get editTemplate => 'Şablonu Düzenle';

  @override
  String get deleteTemplate => 'Şablonu Sil';

  @override
  String get confirmDeleteTemplate => 'Bu şablon silinsin mi?';

  @override
  String get confirmDeleteTemplateMessage =>
      'Bu şablon kalıcı olarak silinecek. Bu işlem geri alınamaz.';

  @override
  String get templateDeleted => 'Şablon silindi';

  @override
  String get editingTemplate => 'Şablon Düzenleniyor';

  @override
  String get templateOptions => 'Şablon Seçenekleri';

  @override
  String get defaultTemplate => 'Varsayılan';

  @override
  String get customTemplate => 'Özel';

  @override
  String get useTemplate => 'Şablonu Kullan';

  @override
  String get manageTemplates => 'Şablonları Yönet';

  @override
  String get notifEmailReceivedTitle => '📧 Gelen Kutunuzda Yeni E-posta';

  @override
  String notifEmailReceivedBody(String sender, String subject) {
    return 'Gönderen $sender: $subject\\n\\nE-posta notu dönüştürmeye hazır.';
  }

  @override
  String get notifWebClipSavedTitle => '✂️ İçerik Başarıyla Kaydedildi';

  @override
  String notifWebClipSavedBody(String preview) {
    return '$preview\\n\\nGelen kutunuza kaydedildi ve kullanıma hazır.';
  }

  @override
  String get notifTaskReminderTitle => '⏰ Görev Hatırlatıcısı';

  @override
  String notifTaskReminderBody(String taskTitle) {
    return '$taskTitle\\n\\nŞimdi yapılmalı!';
  }

  @override
  String get notifTaskAssignedTitle => '📋 Hatırlatıcılı Yeni Görev';

  @override
  String notifTaskAssignedBody(String taskTitle, String dueDate) {
    return '$taskTitle\\nTarih: $dueDate\\n\\nHatırlatıcı ayarlandı ve sizi bilgilendirecek.';
  }
}
