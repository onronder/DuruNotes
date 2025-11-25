// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get notesListTitle => 'Meine Notizen';

  @override
  String get createNewNote => 'Neue Notiz erstellen';

  @override
  String get searchNotes => 'Notizen durchsuchen';

  @override
  String get noNotesYet => 'Noch keine Notizen';

  @override
  String get tapToCreateFirstNote =>
      'Tippe auf +, um deine erste Notiz zu erstellen';

  @override
  String get createFirstNote => 'Erstelle deine erste Notiz';

  @override
  String get importNotes => 'Notizen importieren';

  @override
  String get exportNotes => 'Notizen exportieren';

  @override
  String get settings => 'Einstellungen';

  @override
  String get help => 'Hilfe';

  @override
  String get signOut => 'Abmelden';

  @override
  String get logout => 'Abmelden';

  @override
  String get import => 'Importieren';

  @override
  String get export => 'Exportieren';

  @override
  String get importNotesTitle => 'Notizen importieren';

  @override
  String get exportNotesTitle => 'Notizen exportieren';

  @override
  String get chooseWhatToImport => 'Wähle aus, was importiert werden soll';

  @override
  String get exportYourNotes => 'Exportiere deine Notizen';

  @override
  String availableNotes(int count) {
    return 'Verfügbare Notizen';
  }

  @override
  String get markdownFiles => 'Markdown-Dateien';

  @override
  String get evernoteExport => 'Evernote-Export';

  @override
  String get obsidianVault => 'Obsidian-Vault';

  @override
  String get importSingleMdFiles => 'Einzelne Markdown-Dateien importieren';

  @override
  String get importEnexFiles => 'ENEX-Dateien importieren';

  @override
  String get importObsidianVaultFolder => 'Obsidian-Vault-Ordner importieren';

  @override
  String get selectImportType => 'Importtyp auswählen';

  @override
  String get markdown => 'Markdown';

  @override
  String get pdf => 'PDF';

  @override
  String get html => 'HTML';

  @override
  String get exportAsMdFiles => 'Als Markdown-Dateien exportieren';

  @override
  String get exportAsPdfDocs => 'Als PDF-Dokumente exportieren';

  @override
  String get exportAsWebPages => 'Als Webseiten exportieren';

  @override
  String get selectExportFormat => 'Exportformat auswählen';

  @override
  String get chooseFormat => 'Format auswählen';

  @override
  String get exportAllNotes => 'Alle Notizen exportieren';

  @override
  String get exportRecentNotes => 'Neueste Notizen exportieren';

  @override
  String get exportLatest10 => 'Die letzten 10 Notizen exportieren';

  @override
  String exportAllNotesDesc(int count) {
    return 'Alle Notizen deines Kontos exportieren';
  }

  @override
  String get exportRecentNotesDesc =>
      'Zuletzt erstellte und aktualisierte Notizen exportieren';

  @override
  String get exportLatest10Desc =>
      'Schnell nur die letzten 10 Notizen exportieren';

  @override
  String get importingNotes => 'Notizen werden importiert';

  @override
  String exportingToFormat(String format) {
    return 'Notizen werden exportiert';
  }

  @override
  String get initializingImport => 'Import wird initialisiert';

  @override
  String get initializingExport => 'Export wird initialisiert';

  @override
  String currentFile(String filename) {
    return 'Aktuelle Datei';
  }

  @override
  String progressCount(int current, int total) {
    return 'Fortschritt';
  }

  @override
  String noteProgress(int current, int total) {
    return 'Notizfortschritt';
  }

  @override
  String currentNote(String title) {
    return 'Aktuelle Notiz';
  }

  @override
  String get overallProgress => 'Gesamtfortschritt';

  @override
  String estimatedTimeRemaining(String time) {
    return 'Geschätzte verbleibende Zeit';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get importComplete => 'Import abgeschlossen';

  @override
  String get exportComplete => 'Export abgeschlossen';

  @override
  String successfullyImported(int count) {
    return 'Erfolgreich importiert';
  }

  @override
  String successfullyExported(int count) {
    return 'Erfolgreich exportiert';
  }

  @override
  String errorsEncountered(int count) {
    return 'Fehler sind aufgetreten';
  }

  @override
  String importTook(int seconds) {
    return 'Dauer des Imports';
  }

  @override
  String exportTook(int seconds) {
    return 'Dauer des Exports';
  }

  @override
  String totalSize(String size) {
    return 'Gesamtgröße';
  }

  @override
  String get errorDetails => 'Fehlerdetails';

  @override
  String get filesSavedToDownloads =>
      'Dateien wurden im Downloads-Ordner gespeichert';

  @override
  String get failedExports => 'Fehlgeschlagene Exporte';

  @override
  String get shareFiles => 'Dateien teilen';

  @override
  String get openFolder => 'Ordner öffnen';

  @override
  String get close => 'Schließen';

  @override
  String get importError => 'Importfehler';

  @override
  String get exportError => 'Exportfehler';

  @override
  String get noNotesToExport => 'Keine Notizen zum Exportieren vorhanden';

  @override
  String get failedToSelectMarkdownFiles =>
      'Markdown-Dateien konnten nicht ausgewählt werden';

  @override
  String get failedToSelectEvernoteFile =>
      'Evernote-Datei konnte nicht ausgewählt werden';

  @override
  String get failedToSelectObsidianVault =>
      'Obsidian-Vault konnte nicht ausgewählt werden';

  @override
  String get importFailed => 'Import fehlgeschlagen';

  @override
  String get exportFailed => 'Export fehlgeschlagen';

  @override
  String get obsidianImportFailed => 'Import aus Obsidian fehlgeschlagen';

  @override
  String get noFilesAvailableToShare => 'Keine Dateien zum Teilen verfügbar';

  @override
  String get failedToShareExportedFile =>
      'Exportierte Datei konnte nicht geteilt werden';

  @override
  String get errorSharingFiles => 'Fehler beim Teilen der Dateien';

  @override
  String get couldNotOpenExportsFolder =>
      'Exportordner konnte nicht geöffnet werden';

  @override
  String get pdfExportMayFailInSimulator =>
      'PDF-Export kann im Simulator fehlschlagen';

  @override
  String get testOnPhysicalDevice => 'Teste auf einem physischen Gerät';

  @override
  String get checkInternetConnection => 'Überprüfe deine Internetverbindung';

  @override
  String get tryExportingAsMarkdown => 'Versuche als Markdown zu exportieren';

  @override
  String get networkRelatedIssueDetected =>
      'Ein netzwerkbezogenes Problem wurde erkannt';

  @override
  String get tryAgainInFewMoments =>
      'Versuche es in ein paar Augenblicken erneut';

  @override
  String get useDifferentExportFormat => 'Verwende ein anderes Exportformat';

  @override
  String get tryMarkdown => 'Versuche das Markdown-Format';

  @override
  String get editNote => 'Notiz bearbeiten';

  @override
  String get deleteNote => 'Notiz löschen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get untitled => 'Ohne Titel';

  @override
  String get noContent => 'Kein Inhalt';

  @override
  String get justNow => 'Gerade eben';

  @override
  String minutesAgo(int count) {
    return 'vor einigen Minuten';
  }

  @override
  String hoursAgo(int count) {
    return 'vor einigen Stunden';
  }

  @override
  String daysAgo(int count) {
    return 'vor einigen Tagen';
  }

  @override
  String areYouSureDeleteNote(String title) {
    return 'Möchtest du diese Notiz wirklich löschen?';
  }

  @override
  String get noteDeleted => 'Notiz gelöscht';

  @override
  String get errorDeletingNote =>
      'Beim Löschen der Notiz ist ein Fehler aufgetreten';

  @override
  String get welcomeBack => 'Willkommen zurück';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get loading => 'Wird geladen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get errorLoadingNotes =>
      'Beim Laden der Notizen ist ein Fehler aufgetreten';

  @override
  String get searchFeatureTemporarilyDisabled =>
      'Die Suchfunktion ist vorübergehend deaktiviert';

  @override
  String get exportFunctionalityComingSoon =>
      'Die Exportfunktion ist bald verfügbar';

  @override
  String get settingsScreenComingSoon =>
      'Der Einstellungsbildschirm ist bald verfügbar';

  @override
  String get areYouSureSignOut => 'Möchtest du dich wirklich abmelden?';

  @override
  String get productionGradeImportSystemReady =>
      'Importsystem in Produktionsqualität ist bereit';

  @override
  String get supportedFormats => 'Unterstützte Formate';

  @override
  String get singleMarkdownFiles => 'Einzelne Markdown-Dateien';

  @override
  String get evernoteFiles => 'Evernote-Dateien';

  @override
  String get obsidianVaultFolders => 'Obsidian-Vault-Ordner';

  @override
  String get importFeatures => 'Importfunktionen';

  @override
  String get securityValidation => 'Sicherheitsüberprüfung';

  @override
  String get progressTracking => 'Fortschrittsverfolgung';

  @override
  String get errorRecovery => 'Fehlerbehebung';

  @override
  String get genericErrorTitle => 'Etwas ist schiefgelaufen';

  @override
  String get genericErrorMessage =>
      'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';

  @override
  String get reportError => 'Fehler melden';

  @override
  String get errorReportSent =>
      'Fehlerbericht gesendet. Vielen Dank für dein Feedback!';

  @override
  String get contentSanitization => 'Inhaltsbereinigung';

  @override
  String get featuresSecurityValidation =>
      'Sicherheitsüberprüfung und Inhaltsbereinigung';

  @override
  String get exportAsMarkdownFiles => 'Als Markdown-Dateien exportieren';

  @override
  String get exportAsPdfDocuments => 'Als PDF-Dokumente exportieren';

  @override
  String get exportAsHtmlFiles => 'Als HTML-Dateien exportieren';

  @override
  String get featuresRichFormatting =>
      'Reiche Formatierung und sicherer Export';

  @override
  String get exportCancelled => 'Export abgebrochen';

  @override
  String get checkDownloadsFolderForFiles =>
      'Prüfe den Downloads-Ordner auf Dateien';

  @override
  String get filesSavedInAppDocuments =>
      'Dateien wurden im Dokumentenordner der App gespeichert';

  @override
  String statusPhase(String phase) {
    return 'Phasenstatus';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get account => 'Konto';

  @override
  String get sync => 'Synchronisierung';

  @override
  String get appearance => 'Darstellung';

  @override
  String get language => 'Sprache';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get security => 'Sicherheit';

  @override
  String get importExport => 'Import/Export';

  @override
  String get helpAbout => 'Hilfe und Info';

  @override
  String get signedInAs => 'Angemeldet als';

  @override
  String get signOutConfirm => 'Möchtest du dich wirklich abmelden?';

  @override
  String get manageAccount => 'Konto verwalten';

  @override
  String get syncMode => 'Synchronisierungsmodus';

  @override
  String get automaticSync => 'Automatische Synchronisierung';

  @override
  String get manualSync => 'Manuelle Synchronisierung';

  @override
  String get automaticSyncDesc =>
      'Änderungen automatisch im Hintergrund synchronisieren';

  @override
  String get manualSyncDesc => 'Nur bei Bedarf synchronisieren';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Synchronisieren';

  @override
  String get syncComplete => 'Synchronisierung abgeschlossen';

  @override
  String get syncFailed => 'Synchronisierung fehlgeschlagen';

  @override
  String get theme => 'Design';

  @override
  String get lightTheme => 'Helles Design';

  @override
  String get darkTheme => 'Dunkles Design';

  @override
  String get systemTheme => 'Systemdesign';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Türkçe';

  @override
  String get enableNotifications => 'Benachrichtigungen aktivieren';

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
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

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
  String get folders => 'Ordner';

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
  String get folderName => 'Ordnername';

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
  String get moveToFolder => 'In Ordner verschieben';

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
  String get save => 'Speichern';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

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
  String get completed => 'Abgeschlossen';

  @override
  String get preparing => 'Preparing';

  @override
  String get rendering => 'Rendering';

  @override
  String get finalizing => 'Finalizing';

  @override
  String get attachments => 'Anhänge';

  @override
  String get dateModified => 'Änderungsdatum';

  @override
  String get highPriority => 'Hohe Priorität';

  @override
  String get lowPriority => 'Niedrige Priorität';

  @override
  String get mediumPriority => 'Mittlere Priorität';

  @override
  String get noTitle => 'No Title';

  @override
  String get overdue => 'Überfällig';

  @override
  String get pinnedNotes => 'Angeheftete Notizen';

  @override
  String get pinNote => 'Notiz anheften';

  @override
  String get tags => 'Tags';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get unpinNote => 'Notiz lösen';

  @override
  String get templatePickerTitle => 'Vorlage auswählen';

  @override
  String get templatePickerSubtitle =>
      'Mit einer Vorlage oder einer leeren Notiz beginnen';

  @override
  String get blankNoteOption => 'Leere Notiz';

  @override
  String get blankNoteDescription => 'Mit einer leeren Notiz beginnen';

  @override
  String get noTemplatesTitle => 'Noch keine Vorlagen';

  @override
  String get noTemplatesDescription =>
      'Erstelle deine erste Vorlage, um häufige Strukturen wiederzuverwenden';

  @override
  String get templatesSection => 'VORLAGEN';

  @override
  String get saveAsTemplate => 'Als Vorlage speichern';

  @override
  String get fromTemplate => 'Aus Vorlage';

  @override
  String templateSaved(String title) {
    return 'Vorlage gespeichert: $title';
  }

  @override
  String get failedToSaveTemplate => 'Vorlage konnte nicht gespeichert werden';

  @override
  String get cannotSaveEmptyTemplate =>
      'Eine leere Notiz kann nicht als Vorlage gespeichert werden';

  @override
  String get editTemplate => 'Vorlage bearbeiten';

  @override
  String get deleteTemplate => 'Vorlage löschen';

  @override
  String get confirmDeleteTemplate => 'Diese Vorlage löschen?';

  @override
  String get confirmDeleteTemplateMessage =>
      'Diese Vorlage wird dauerhaft gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden.';

  @override
  String get templateDeleted => 'Vorlage gelöscht';

  @override
  String get editingTemplate => 'Vorlage wird bearbeitet';

  @override
  String get templateOptions => 'Vorlagenoptionen';

  @override
  String get defaultTemplate => 'Standard';

  @override
  String get customTemplate => 'Benutzerdefiniert';

  @override
  String get useTemplate => 'Vorlage verwenden';

  @override
  String get manageTemplates => 'Vorlagen verwalten';

  @override
  String get notifEmailReceivedTitle => '📧 Neue E-Mail in deinem Posteingang';

  @override
  String notifEmailReceivedBody(String sender, String subject) {
    return 'Absender $sender: $subject\\n\\nDie E-Mail ist bereit, in eine Notiz umgewandelt zu werden.';
  }

  @override
  String get notifWebClipSavedTitle => '✂️ Inhalt erfolgreich gespeichert';

  @override
  String notifWebClipSavedBody(String preview) {
    return '$preview\\n\\nIn deinem Posteingang gespeichert und bereit zur Verwendung.';
  }

  @override
  String get notifTaskReminderTitle => '⏰ Aufgaben-Erinnerung';

  @override
  String notifTaskReminderBody(String taskTitle) {
    return '$taskTitle\\n\\nJetzt erledigen!';
  }

  @override
  String get notifTaskAssignedTitle => '📋 Neue Aufgabe mit Erinnerung';

  @override
  String notifTaskAssignedBody(String taskTitle, String dueDate) {
    return '$taskTitle\\nDatum: $dueDate\\n\\nDie Erinnerung wurde eingerichtet und wird dich benachrichtigen.';
  }
}
