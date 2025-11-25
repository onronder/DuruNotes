// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get notesListTitle => 'Mes notes';

  @override
  String get createNewNote => 'Créer une nouvelle note';

  @override
  String get searchNotes => 'Rechercher dans les notes';

  @override
  String get noNotesYet => 'Aucune note pour le moment';

  @override
  String get tapToCreateFirstNote => 'Touchez + pour créer votre première note';

  @override
  String get createFirstNote => 'Créez votre première note';

  @override
  String get importNotes => 'Importer des notes';

  @override
  String get exportNotes => 'Exporter les notes';

  @override
  String get settings => 'Paramètres';

  @override
  String get help => 'Aide';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get import => 'Importer';

  @override
  String get export => 'Exporter';

  @override
  String get importNotesTitle => 'Importer des notes';

  @override
  String get exportNotesTitle => 'Exporter des notes';

  @override
  String get chooseWhatToImport => 'Choisissez ce que vous voulez importer';

  @override
  String get exportYourNotes => 'Exportez vos notes';

  @override
  String availableNotes(int count) {
    return 'Notes disponibles';
  }

  @override
  String get markdownFiles => 'Fichiers Markdown';

  @override
  String get evernoteExport => 'Export Evernote';

  @override
  String get obsidianVault => 'Coffre Obsidian';

  @override
  String get importSingleMdFiles =>
      'Importer des fichiers Markdown individuels';

  @override
  String get importEnexFiles => 'Importer des fichiers ENEX';

  @override
  String get importObsidianVaultFolder =>
      'Importer un dossier de coffre Obsidian';

  @override
  String get selectImportType => 'Sélectionnez le type d’importation';

  @override
  String get markdown => 'Markdown';

  @override
  String get pdf => 'PDF';

  @override
  String get html => 'HTML';

  @override
  String get exportAsMdFiles => 'Exporter en fichiers Markdown';

  @override
  String get exportAsPdfDocs => 'Exporter en documents PDF';

  @override
  String get exportAsWebPages => 'Exporter en pages web';

  @override
  String get selectExportFormat => 'Sélectionnez le format d’exportation';

  @override
  String get chooseFormat => 'Choisissez un format';

  @override
  String get exportAllNotes => 'Exporter toutes les notes';

  @override
  String get exportRecentNotes => 'Exporter les notes récentes';

  @override
  String get exportLatest10 => 'Exporter les 10 dernières notes';

  @override
  String exportAllNotesDesc(int count) {
    return 'Exporter toutes les notes de votre compte';
  }

  @override
  String get exportRecentNotesDesc =>
      'Exporter les notes récemment créées ou modifiées';

  @override
  String get exportLatest10Desc =>
      'Exporter rapidement uniquement les 10 dernières notes';

  @override
  String get importingNotes => 'Importation des notes';

  @override
  String exportingToFormat(String format) {
    return 'Exportation des notes';
  }

  @override
  String get initializingImport => 'Initialisation de l’importation';

  @override
  String get initializingExport => 'Initialisation de l’exportation';

  @override
  String currentFile(String filename) {
    return 'Fichier actuel';
  }

  @override
  String progressCount(int current, int total) {
    return 'Progression';
  }

  @override
  String noteProgress(int current, int total) {
    return 'Progression des notes';
  }

  @override
  String currentNote(String title) {
    return 'Note actuelle';
  }

  @override
  String get overallProgress => 'Progression globale';

  @override
  String estimatedTimeRemaining(String time) {
    return 'Temps restant estimé';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get importComplete => 'Importation terminée';

  @override
  String get exportComplete => 'Exportation terminée';

  @override
  String successfullyImported(int count) {
    return 'Importé avec succès';
  }

  @override
  String successfullyExported(int count) {
    return 'Exporté avec succès';
  }

  @override
  String errorsEncountered(int count) {
    return 'Des erreurs se sont produites';
  }

  @override
  String importTook(int seconds) {
    return 'Durée de l’importation';
  }

  @override
  String exportTook(int seconds) {
    return 'Durée de l’exportation';
  }

  @override
  String totalSize(String size) {
    return 'Taille totale';
  }

  @override
  String get errorDetails => 'Détails de l’erreur';

  @override
  String get filesSavedToDownloads =>
      'Les fichiers ont été enregistrés dans le dossier Téléchargements';

  @override
  String get failedExports => 'Exportations échouées';

  @override
  String get shareFiles => 'Partager les fichiers';

  @override
  String get openFolder => 'Ouvrir le dossier';

  @override
  String get close => 'Fermer';

  @override
  String get importError => 'Erreur d’importation';

  @override
  String get exportError => 'Erreur d’exportation';

  @override
  String get noNotesToExport => 'Aucune note à exporter';

  @override
  String get failedToSelectMarkdownFiles =>
      'Impossible de sélectionner les fichiers Markdown';

  @override
  String get failedToSelectEvernoteFile =>
      'Impossible de sélectionner le fichier Evernote';

  @override
  String get failedToSelectObsidianVault =>
      'Impossible de sélectionner le coffre Obsidian';

  @override
  String get importFailed => 'L’importation a échoué';

  @override
  String get exportFailed => 'L’exportation a échoué';

  @override
  String get obsidianImportFailed => 'L’importation depuis Obsidian a échoué';

  @override
  String get noFilesAvailableToShare => 'Aucun fichier disponible à partager';

  @override
  String get failedToShareExportedFile =>
      'Impossible de partager le fichier exporté';

  @override
  String get errorSharingFiles => 'Erreur lors du partage des fichiers';

  @override
  String get couldNotOpenExportsFolder =>
      'Impossible d’ouvrir le dossier d’exportation';

  @override
  String get pdfExportMayFailInSimulator =>
      'L’exportation PDF peut échouer dans le simulateur';

  @override
  String get testOnPhysicalDevice => 'Testez sur un appareil physique';

  @override
  String get checkInternetConnection => 'Vérifiez votre connexion Internet';

  @override
  String get tryExportingAsMarkdown => 'Essayez d’exporter au format Markdown';

  @override
  String get networkRelatedIssueDetected => 'Un problème réseau a été détecté';

  @override
  String get tryAgainInFewMoments => 'Réessayez dans quelques instants';

  @override
  String get useDifferentExportFormat =>
      'Utilisez un autre format d’exportation';

  @override
  String get tryMarkdown => 'Essayez le format Markdown';

  @override
  String get editNote => 'Modifier la note';

  @override
  String get deleteNote => 'Supprimer la note';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get untitled => 'Sans titre';

  @override
  String get noContent => 'Aucun contenu';

  @override
  String get justNow => 'À l’instant';

  @override
  String minutesAgo(int count) {
    return 'il y a quelques minutes';
  }

  @override
  String hoursAgo(int count) {
    return 'il y a quelques heures';
  }

  @override
  String daysAgo(int count) {
    return 'il y a quelques jours';
  }

  @override
  String areYouSureDeleteNote(String title) {
    return 'Voulez-vous vraiment supprimer cette note ?';
  }

  @override
  String get noteDeleted => 'Note supprimée';

  @override
  String get errorDeletingNote =>
      'Une erreur s’est produite lors de la suppression de la note';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get online => 'En ligne';

  @override
  String get offline => 'Hors ligne';

  @override
  String get loading => 'Chargement';

  @override
  String get retry => 'Réessayer';

  @override
  String get errorLoadingNotes =>
      'Une erreur s’est produite lors du chargement des notes';

  @override
  String get searchFeatureTemporarilyDisabled =>
      'La recherche est temporairement désactivée';

  @override
  String get exportFunctionalityComingSoon =>
      'La fonction d’exportation arrive bientôt';

  @override
  String get settingsScreenComingSoon =>
      'L’écran des paramètres arrive bientôt';

  @override
  String get areYouSureSignOut => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get productionGradeImportSystemReady =>
      'Le système d’importation de niveau production est prêt';

  @override
  String get supportedFormats => 'Formats pris en charge';

  @override
  String get singleMarkdownFiles => 'Fichiers Markdown individuels';

  @override
  String get evernoteFiles => 'Fichiers Evernote';

  @override
  String get obsidianVaultFolders => 'Dossiers de coffre Obsidian';

  @override
  String get importFeatures => 'Fonctionnalités d’importation';

  @override
  String get securityValidation => 'Validation de la sécurité';

  @override
  String get progressTracking => 'Suivi de progression';

  @override
  String get errorRecovery => 'Récupération après erreur';

  @override
  String get genericErrorTitle => 'Un problème est survenu';

  @override
  String get genericErrorMessage =>
      'Une erreur inattendue s’est produite. Veuillez réessayer.';

  @override
  String get reportError => 'Signaler une erreur';

  @override
  String get errorReportSent =>
      'Rapport d’erreur envoyé. Merci pour votre retour !';

  @override
  String get contentSanitization => 'Nettoyage du contenu';

  @override
  String get featuresSecurityValidation =>
      'Validation de sécurité et nettoyage du contenu';

  @override
  String get exportAsMarkdownFiles => 'Exporter en fichiers Markdown';

  @override
  String get exportAsPdfDocuments => 'Exporter en documents PDF';

  @override
  String get exportAsHtmlFiles => 'Exporter en fichiers HTML';

  @override
  String get featuresRichFormatting =>
      'Mise en forme enrichie et exportation sécurisée';

  @override
  String get exportCancelled => 'Exportation annulée';

  @override
  String get checkDownloadsFolderForFiles =>
      'Vérifiez le dossier Téléchargements pour trouver les fichiers';

  @override
  String get filesSavedInAppDocuments =>
      'Les fichiers ont été enregistrés dans le dossier Documents de l’application';

  @override
  String statusPhase(String phase) {
    return 'Statut de l’étape';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get account => 'Compte';

  @override
  String get sync => 'Synchronisation';

  @override
  String get appearance => 'Apparence';

  @override
  String get language => 'Langue';

  @override
  String get notifications => 'Notifications';

  @override
  String get security => 'Sécurité';

  @override
  String get importExport => 'Importer/Exporter';

  @override
  String get helpAbout => 'Aide et à propos';

  @override
  String get signedInAs => 'Connecté en tant que';

  @override
  String get signOutConfirm => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get manageAccount => 'Gérer le compte';

  @override
  String get syncMode => 'Mode de synchronisation';

  @override
  String get automaticSync => 'Synchronisation automatique';

  @override
  String get manualSync => 'Synchronisation manuelle';

  @override
  String get automaticSyncDesc =>
      'Synchroniser automatiquement les modifications en arrière-plan';

  @override
  String get manualSyncDesc =>
      'Synchroniser les données uniquement lorsque vous le demandez';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncing => 'Synchronisation';

  @override
  String get syncComplete => 'Synchronisation terminée';

  @override
  String get syncFailed => 'Échec de la synchronisation';

  @override
  String get theme => 'Thème';

  @override
  String get lightTheme => 'Thème clair';

  @override
  String get darkTheme => 'Thème sombre';

  @override
  String get systemTheme => 'Thème du système';

  @override
  String get accentColor => 'Couleur d’accent';

  @override
  String get selectLanguage => 'Sélectionner une langue';

  @override
  String get english => 'Anglais';

  @override
  String get turkish => 'Turc';

  @override
  String get enableNotifications => 'Activer les notifications';

  @override
  String get openSystemSettings => 'Ouvrir les paramètres système';

  @override
  String get notificationPermissions => 'Autorisations de notification';

  @override
  String get endToEndEncryption => 'Chiffrement de bout en bout';

  @override
  String get encryptionEnabled => 'Chiffrement activé';

  @override
  String get analyticsOptIn => 'Participer aux statistiques';

  @override
  String get analyticsDesc =>
      'Partagez des données d’utilisation anonymes pour aider à améliorer l’application';

  @override
  String get biometricLock => 'Verrouillage biométrique';

  @override
  String get biometricDesc =>
      'Utilisez l’empreinte digitale ou la reconnaissance faciale pour accéder aux notes';

  @override
  String get biometricNotAvailable =>
      'L’authentification biométrique n’est pas disponible sur cet appareil';

  @override
  String get version => 'Version';

  @override
  String get buildNumber => 'Numéro de build';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d’utilisation';

  @override
  String get contactSupport => 'Contacter le support';

  @override
  String get rateApp => 'Noter l’application';

  @override
  String get userGuide => 'Guide d’utilisation';

  @override
  String get helpAndSupport => 'Aide et support';

  @override
  String get documentation => 'Documentation';

  @override
  String get aboutApp => 'À propos de l’application';

  @override
  String get sharedNote => 'Note partagée';

  @override
  String get sharedText => 'Texte partagé';

  @override
  String get sharedImage => 'Image partagée';

  @override
  String get sharedLink => 'Lien partagé';

  @override
  String get sharedFile => 'Fichier partagé';

  @override
  String sharedFrom(String source, String date) {
    return 'Partagé depuis';
  }

  @override
  String get sharedImageCouldNotBeProcessed =>
      'L’image partagée n’a pas pu être traitée';

  @override
  String get folders => 'Dossiers';

  @override
  String get folderPickerTitle => 'Choisissez un dossier';

  @override
  String get folderPickerSubtitle =>
      'Sélectionnez un dossier pour déplacer la note';

  @override
  String get createNewFolder => 'Créer un nouveau dossier';

  @override
  String get createNewFolderSubtitle =>
      'Ajoutez un nouveau dossier pour organiser vos notes';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get folderName => 'Nom du dossier';

  @override
  String get folderNameHint => 'Nom du dossier';

  @override
  String get folderNameRequired => 'Le nom du dossier est obligatoire';

  @override
  String get folderNameEmpty => 'Le nom du dossier ne peut pas être vide';

  @override
  String get folderNameDuplicate => 'Un dossier avec ce nom existe déjà';

  @override
  String get folderColor => 'Couleur du dossier';

  @override
  String get folderIcon => 'Icône du dossier';

  @override
  String get parentFolder => 'Dossier parent';

  @override
  String get rootFolder => 'Dossier racine';

  @override
  String get rootLevel => 'Niveau racine';

  @override
  String get description => 'Description';

  @override
  String get optional => 'Facultatif';

  @override
  String get folderDescriptionHint => 'Description facultative du dossier';

  @override
  String get selectParentFolder => 'Sélectionnez le dossier parent';

  @override
  String get unfiledNotes => 'Notes sans dossier';

  @override
  String noteCount(int count) {
    return 'Nombre de notes';
  }

  @override
  String get searchFolders => 'Rechercher dans les dossiers';

  @override
  String get showSearch => 'Afficher la recherche';

  @override
  String get hideSearch => 'Masquer la recherche';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get noFoldersFound => 'Aucun dossier trouvé';

  @override
  String noFoldersFoundSubtitle(String query) {
    return 'Essayez de modifier le filtre ou créez un nouveau dossier';
  }

  @override
  String get loadFoldersError => 'Erreur lors du chargement des dossiers';

  @override
  String get create => 'Créer';

  @override
  String get loadError => 'Erreur de chargement';

  @override
  String get folderManagement => 'Gestion des dossiers';

  @override
  String get editFolder => 'Modifier le dossier';

  @override
  String get deleteFolder => 'Supprimer le dossier';

  @override
  String get moveFolder => 'Déplacer le dossier';

  @override
  String get folderProperties => 'Propriétés du dossier';

  @override
  String get confirmDeleteFolder => 'Confirmer la suppression du dossier';

  @override
  String get confirmDeleteFolderMessage =>
      'Ce dossier et son contenu seront définitivement supprimés. Voulez-vous continuer ?';

  @override
  String get confirmDeleteFolderAction => 'Supprimer le dossier';

  @override
  String get addToFolder => 'Ajouter au dossier';

  @override
  String get removeFromFolder => 'Retirer du dossier';

  @override
  String get moveToFolder => 'Déplacer vers un dossier';

  @override
  String get folderEmpty => 'Le dossier est vide';

  @override
  String get folderEmptySubtitle =>
      'Utilisez l’icône + pour ajouter des notes ici ou déplacez des notes dans ce dossier';

  @override
  String get allFolders => 'Tous les dossiers';

  @override
  String get rename => 'Renommer';

  @override
  String get renameFolder => 'Renommer le dossier';

  @override
  String get move => 'Déplacer';

  @override
  String get folderRenamed => 'Dossier renommé';

  @override
  String get folderMoved => 'Dossier déplacé';

  @override
  String get folderDeleted => 'Dossier supprimé';

  @override
  String get folderDeletedNotesMovedToInbox =>
      'Le dossier a été supprimé et ses notes ont été déplacées dans la boîte de réception';

  @override
  String folderCreated(String name) {
    return 'Dossier créé';
  }

  @override
  String deleteFolderConfirmation(String name) {
    return 'Voulez-vous vraiment supprimer ce dossier ?';
  }

  @override
  String get folderDeleteDescription =>
      'Le dossier sera supprimé. Vos notes ne seront pas perdues et seront déplacées dans la boîte de réception.';

  @override
  String get errorRenamingFolder =>
      'Une erreur s’est produite lors du renommage du dossier';

  @override
  String get errorMovingFolder =>
      'Une erreur s’est produite lors du déplacement du dossier';

  @override
  String get errorDeletingFolder =>
      'Une erreur s’est produite lors de la suppression du dossier';

  @override
  String get errorCreatingFolder =>
      'Une erreur s’est produite lors de la création du dossier';

  @override
  String get errorLoadingFolders =>
      'Une erreur s’est produite lors du chargement des dossiers';

  @override
  String get cannotMoveToDescendant =>
      'Vous ne pouvez pas déplacer un dossier vers l’un de ses sous-dossiers';

  @override
  String get selectFolder => 'Sélectionnez un dossier';

  @override
  String get unfiled => 'Sans dossier';

  @override
  String get createYourFirstFolder => 'Créez votre premier dossier';

  @override
  String get expandAll => 'Tout développer';

  @override
  String get collapseAll => 'Tout réduire';

  @override
  String get save => 'Enregistrer';

  @override
  String get done => 'Terminé';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get continueAction => 'Continuer';

  @override
  String get back => 'Retour';

  @override
  String get next => 'Suivant';

  @override
  String get finish => 'Terminer';

  @override
  String get selectFiles => 'Sélectionner des fichiers';

  @override
  String get selectingFiles => 'Sélection des fichiers';

  @override
  String get scanningDirectory => 'Analyse du dossier';

  @override
  String get readingFile => 'Lecture du fichier';

  @override
  String get parsingContent => 'Analyse du contenu';

  @override
  String get convertingToBlocks => 'Conversion en blocs';

  @override
  String get processingFiles => 'Traitement des fichiers';

  @override
  String get savingNotes => 'Enregistrement des notes';

  @override
  String get completed => 'Terminé';

  @override
  String get preparing => 'Préparation';

  @override
  String get rendering => 'Rendu en cours';

  @override
  String get finalizing => 'Finalisation';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get dateModified => 'Date de modification';

  @override
  String get highPriority => 'Haute priorité';

  @override
  String get lowPriority => 'Faible priorité';

  @override
  String get mediumPriority => 'Priorité moyenne';

  @override
  String get noTitle => 'Sans titre';

  @override
  String get overdue => 'En retard';

  @override
  String get pinnedNotes => 'Notes épinglées';

  @override
  String get pinNote => 'Épingler la note';

  @override
  String get tags => 'Étiquettes';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get unpinNote => 'Désépingler la note';

  @override
  String get templatePickerTitle => 'Choisissez un modèle';

  @override
  String get templatePickerSubtitle =>
      'Commencez avec un modèle ou une note vierge';

  @override
  String get blankNoteOption => 'Note vierge';

  @override
  String get blankNoteDescription => 'Commencer avec une note vide';

  @override
  String get noTemplatesTitle => 'Aucun modèle pour le moment';

  @override
  String get noTemplatesDescription =>
      'Créez votre premier modèle pour réutiliser vos structures fréquentes';

  @override
  String get templatesSection => 'MODÈLES';

  @override
  String get saveAsTemplate => 'Enregistrer comme modèle';

  @override
  String get fromTemplate => 'Depuis un modèle';

  @override
  String templateSaved(String title) {
    return 'Modèle enregistré : $title';
  }

  @override
  String get failedToSaveTemplate => 'Impossible d’enregistrer le modèle';

  @override
  String get cannotSaveEmptyTemplate =>
      'Impossible d’enregistrer une note vide comme modèle';

  @override
  String get editTemplate => 'Modifier le modèle';

  @override
  String get deleteTemplate => 'Supprimer le modèle';

  @override
  String get confirmDeleteTemplate => 'Supprimer ce modèle ?';

  @override
  String get confirmDeleteTemplateMessage =>
      'Ce modèle sera définitivement supprimé. Cette action est irréversible.';

  @override
  String get templateDeleted => 'Modèle supprimé';

  @override
  String get editingTemplate => 'Modification du modèle';

  @override
  String get templateOptions => 'Options du modèle';

  @override
  String get defaultTemplate => 'Par défaut';

  @override
  String get customTemplate => 'Personnalisé';

  @override
  String get useTemplate => 'Utiliser le modèle';

  @override
  String get manageTemplates => 'Gérer les modèles';

  @override
  String get notifEmailReceivedTitle =>
      '📧 Nouveau message dans votre boîte de réception';

  @override
  String notifEmailReceivedBody(String sender, String subject) {
    return 'Expéditeur $sender : $subject\\n\\nL’e-mail est prêt à être converti en note.';
  }

  @override
  String get notifWebClipSavedTitle => '✂️ Contenu enregistré avec succès';

  @override
  String notifWebClipSavedBody(String preview) {
    return '$preview\\n\\nEnregistré dans votre boîte de réception et prêt à l’emploi.';
  }

  @override
  String get notifTaskReminderTitle => '⏰ Rappel de tâche';

  @override
  String notifTaskReminderBody(String taskTitle) {
    return '$taskTitle\\n\\nÀ faire maintenant !';
  }

  @override
  String get notifTaskAssignedTitle => '📋 Nouvelle tâche avec rappel';

  @override
  String notifTaskAssignedBody(String taskTitle, String dueDate) {
    return '$taskTitle\\nDate : $dueDate\\n\\nLe rappel est configuré et vous tiendra informé.';
  }
}
