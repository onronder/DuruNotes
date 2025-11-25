// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get notesListTitle => 'Mis notas';

  @override
  String get createNewNote => 'Crear nota nueva';

  @override
  String get searchNotes => 'Buscar en notas';

  @override
  String get noNotesYet => 'Todavía no hay notas';

  @override
  String get tapToCreateFirstNote => 'Toca + para crear tu primera nota';

  @override
  String get createFirstNote => 'Crea tu primera nota';

  @override
  String get importNotes => 'Importar notas';

  @override
  String get exportNotes => 'Exportar notas';

  @override
  String get settings => 'Ajustes';

  @override
  String get help => 'Ayuda';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get import => 'Importar';

  @override
  String get export => 'Exportar';

  @override
  String get importNotesTitle => 'Importar notas';

  @override
  String get exportNotesTitle => 'Exportar notas';

  @override
  String get chooseWhatToImport => 'Elige qué quieres importar';

  @override
  String get exportYourNotes => 'Exporta tus notas';

  @override
  String availableNotes(int count) {
    return 'Notas disponibles';
  }

  @override
  String get markdownFiles => 'Archivos Markdown';

  @override
  String get evernoteExport => 'Exportación de Evernote';

  @override
  String get obsidianVault => 'Vault de Obsidian';

  @override
  String get importSingleMdFiles => 'Importar archivos Markdown individuales';

  @override
  String get importEnexFiles => 'Importar archivos ENEX';

  @override
  String get importObsidianVaultFolder =>
      'Importar carpeta de vault de Obsidian';

  @override
  String get selectImportType => 'Selecciona el tipo de importación';

  @override
  String get markdown => 'Markdown';

  @override
  String get pdf => 'PDF';

  @override
  String get html => 'HTML';

  @override
  String get exportAsMdFiles => 'Exportar como archivos Markdown';

  @override
  String get exportAsPdfDocs => 'Exportar como documentos PDF';

  @override
  String get exportAsWebPages => 'Exportar como páginas web';

  @override
  String get selectExportFormat => 'Selecciona el formato de exportación';

  @override
  String get chooseFormat => 'Elige un formato';

  @override
  String get exportAllNotes => 'Exportar todas las notas';

  @override
  String get exportRecentNotes => 'Exportar notas recientes';

  @override
  String get exportLatest10 => 'Exportar las últimas 10 notas';

  @override
  String exportAllNotesDesc(int count) {
    return 'Exporta todas las notas de tu cuenta';
  }

  @override
  String get exportRecentNotesDesc =>
      'Exporta las notas creadas y actualizadas recientemente';

  @override
  String get exportLatest10Desc =>
      'Exporta rápidamente solo las últimas 10 notas';

  @override
  String get importingNotes => 'Importando notas';

  @override
  String exportingToFormat(String format) {
    return 'Exportando notas';
  }

  @override
  String get initializingImport => 'Iniciando importación';

  @override
  String get initializingExport => 'Iniciando exportación';

  @override
  String currentFile(String filename) {
    return 'Archivo actual';
  }

  @override
  String progressCount(int current, int total) {
    return 'Progreso';
  }

  @override
  String noteProgress(int current, int total) {
    return 'Progreso de las notas';
  }

  @override
  String currentNote(String title) {
    return 'Nota actual';
  }

  @override
  String get overallProgress => 'Progreso general';

  @override
  String estimatedTimeRemaining(String time) {
    return 'Tiempo restante estimado';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get importComplete => 'Importación completada';

  @override
  String get exportComplete => 'Exportación completada';

  @override
  String successfullyImported(int count) {
    return 'Importado correctamente';
  }

  @override
  String successfullyExported(int count) {
    return 'Exportado correctamente';
  }

  @override
  String errorsEncountered(int count) {
    return 'Se encontraron errores';
  }

  @override
  String importTook(int seconds) {
    return 'Duración de la importación';
  }

  @override
  String exportTook(int seconds) {
    return 'Duración de la exportación';
  }

  @override
  String totalSize(String size) {
    return 'Tamaño total';
  }

  @override
  String get errorDetails => 'Detalles del error';

  @override
  String get filesSavedToDownloads =>
      'Los archivos se han guardado en la carpeta Descargas';

  @override
  String get failedExports => 'Exportaciones fallidas';

  @override
  String get shareFiles => 'Compartir archivos';

  @override
  String get openFolder => 'Abrir carpeta';

  @override
  String get close => 'Cerrar';

  @override
  String get importError => 'Error de importación';

  @override
  String get exportError => 'Error de exportación';

  @override
  String get noNotesToExport => 'No hay notas para exportar';

  @override
  String get failedToSelectMarkdownFiles =>
      'No se pudieron seleccionar los archivos Markdown';

  @override
  String get failedToSelectEvernoteFile =>
      'No se pudo seleccionar el archivo de Evernote';

  @override
  String get failedToSelectObsidianVault =>
      'No se pudo seleccionar el vault de Obsidian';

  @override
  String get importFailed => 'La importación ha fallado';

  @override
  String get exportFailed => 'La exportación ha fallado';

  @override
  String get obsidianImportFailed => 'La importación desde Obsidian ha fallado';

  @override
  String get noFilesAvailableToShare =>
      'No hay archivos disponibles para compartir';

  @override
  String get failedToShareExportedFile =>
      'No se pudo compartir el archivo exportado';

  @override
  String get errorSharingFiles => 'Error al compartir los archivos';

  @override
  String get couldNotOpenExportsFolder =>
      'No se pudo abrir la carpeta de exportaciones';

  @override
  String get pdfExportMayFailInSimulator =>
      'La exportación a PDF puede fallar en el simulador';

  @override
  String get testOnPhysicalDevice => 'Prueba en un dispositivo físico';

  @override
  String get checkInternetConnection => 'Comprueba tu conexión a Internet';

  @override
  String get tryExportingAsMarkdown => 'Prueba a exportar como Markdown';

  @override
  String get networkRelatedIssueDetected =>
      'Se detectó un problema relacionado con la red';

  @override
  String get tryAgainInFewMoments => 'Inténtalo de nuevo en unos momentos';

  @override
  String get useDifferentExportFormat =>
      'Usa un formato de exportación diferente';

  @override
  String get tryMarkdown => 'Prueba el formato Markdown';

  @override
  String get editNote => 'Editar nota';

  @override
  String get deleteNote => 'Eliminar nota';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get untitled => 'Sin título';

  @override
  String get noContent => 'Sin contenido';

  @override
  String get justNow => 'Justo ahora';

  @override
  String minutesAgo(int count) {
    return 'hace unos minutos';
  }

  @override
  String hoursAgo(int count) {
    return 'hace unas horas';
  }

  @override
  String daysAgo(int count) {
    return 'hace unos días';
  }

  @override
  String areYouSureDeleteNote(String title) {
    return '¿Seguro que quieres eliminar esta nota?';
  }

  @override
  String get noteDeleted => 'Nota eliminada';

  @override
  String get errorDeletingNote => 'Se produjo un error al eliminar la nota';

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get online => 'En línea';

  @override
  String get offline => 'Sin conexión';

  @override
  String get loading => 'Cargando';

  @override
  String get retry => 'Reintentar';

  @override
  String get errorLoadingNotes => 'Se produjo un error al cargar las notas';

  @override
  String get searchFeatureTemporarilyDisabled =>
      'La función de búsqueda está desactivada temporalmente';

  @override
  String get exportFunctionalityComingSoon =>
      'La función de exportación estará disponible pronto';

  @override
  String get settingsScreenComingSoon =>
      'La pantalla de ajustes estará disponible pronto';

  @override
  String get areYouSureSignOut => '¿Seguro que quieres cerrar sesión?';

  @override
  String get productionGradeImportSystemReady =>
      'El sistema de importación de nivel de producción está listo';

  @override
  String get supportedFormats => 'Formatos admitidos';

  @override
  String get singleMarkdownFiles => 'Archivos Markdown individuales';

  @override
  String get evernoteFiles => 'Archivos de Evernote';

  @override
  String get obsidianVaultFolders => 'Carpetas de vault de Obsidian';

  @override
  String get importFeatures => 'Funciones de importación';

  @override
  String get securityValidation => 'Validación de seguridad';

  @override
  String get progressTracking => 'Seguimiento del progreso';

  @override
  String get errorRecovery => 'Recuperación de errores';

  @override
  String get genericErrorTitle => 'Algo salió mal';

  @override
  String get genericErrorMessage =>
      'Se produjo un error inesperado. Inténtalo de nuevo.';

  @override
  String get reportError => 'Informar de un error';

  @override
  String get errorReportSent =>
      'Informe de error enviado. ¡Gracias por tus comentarios!';

  @override
  String get contentSanitization => 'Limpieza de contenido';

  @override
  String get featuresSecurityValidation =>
      'Validación de seguridad y limpieza de contenido';

  @override
  String get exportAsMarkdownFiles => 'Exportar como archivos Markdown';

  @override
  String get exportAsPdfDocuments => 'Exportar como documentos PDF';

  @override
  String get exportAsHtmlFiles => 'Exportar como archivos HTML';

  @override
  String get featuresRichFormatting =>
      'Formato enriquecido y exportación segura';

  @override
  String get exportCancelled => 'Exportación cancelada';

  @override
  String get checkDownloadsFolderForFiles =>
      'Revisa la carpeta Descargas para ver los archivos';

  @override
  String get filesSavedInAppDocuments =>
      'Los archivos se han guardado en la carpeta de documentos de la aplicación';

  @override
  String statusPhase(String phase) {
    return 'Estado de la fase';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get account => 'Cuenta';

  @override
  String get sync => 'Sincronización';

  @override
  String get appearance => 'Apariencia';

  @override
  String get language => 'Idioma';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get security => 'Seguridad';

  @override
  String get importExport => 'Importar/Exportar';

  @override
  String get helpAbout => 'Ayuda y acerca de';

  @override
  String get signedInAs => 'Sesión iniciada como';

  @override
  String get signOutConfirm => '¿Seguro que quieres cerrar sesión?';

  @override
  String get manageAccount => 'Gestionar cuenta';

  @override
  String get syncMode => 'Modo de sincronización';

  @override
  String get automaticSync => 'Sincronización automática';

  @override
  String get manualSync => 'Sincronización manual';

  @override
  String get automaticSyncDesc =>
      'Sincroniza los cambios automáticamente en segundo plano';

  @override
  String get manualSyncDesc =>
      'Sincroniza los datos solo cuando tú lo solicites';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get syncing => 'Sincronizando';

  @override
  String get syncComplete => 'Sincronización completada';

  @override
  String get syncFailed => 'Error de sincronización';

  @override
  String get theme => 'Tema';

  @override
  String get lightTheme => 'Tema claro';

  @override
  String get darkTheme => 'Tema oscuro';

  @override
  String get systemTheme => 'Tema del sistema';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get english => 'Inglés';

  @override
  String get turkish => 'Turco';

  @override
  String get enableNotifications => 'Activar notificaciones';

  @override
  String get openSystemSettings => 'Abrir configuración del sistema';

  @override
  String get notificationPermissions => 'Permisos de notificación';

  @override
  String get endToEndEncryption => 'Cifrado de extremo a extremo';

  @override
  String get encryptionEnabled => 'Cifrado activado';

  @override
  String get analyticsOptIn => 'Participar en analíticas';

  @override
  String get analyticsDesc =>
      'Comparte datos de uso anónimos para ayudar a mejorar la aplicación';

  @override
  String get biometricLock => 'Bloqueo biométrico';

  @override
  String get biometricDesc =>
      'Usa huella dactilar o reconocimiento facial para acceder a las notas';

  @override
  String get biometricNotAvailable =>
      'La autenticación biométrica no está disponible en este dispositivo';

  @override
  String get version => 'Versión';

  @override
  String get buildNumber => 'Número de compilación';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get contactSupport => 'Contactar con soporte';

  @override
  String get rateApp => 'Valorar la aplicación';

  @override
  String get userGuide => 'Guía de usuario';

  @override
  String get helpAndSupport => 'Ayuda y soporte';

  @override
  String get documentation => 'Documentación';

  @override
  String get aboutApp => 'Acerca de la aplicación';

  @override
  String get sharedNote => 'Nota compartida';

  @override
  String get sharedText => 'Texto compartido';

  @override
  String get sharedImage => 'Imagen compartida';

  @override
  String get sharedLink => 'Enlace compartido';

  @override
  String get sharedFile => 'Archivo compartido';

  @override
  String sharedFrom(String source, String date) {
    return 'Compartido desde';
  }

  @override
  String get sharedImageCouldNotBeProcessed =>
      'No se pudo procesar la imagen compartida';

  @override
  String get folders => 'Carpetas';

  @override
  String get folderPickerTitle => 'Selecciona una carpeta';

  @override
  String get folderPickerSubtitle => 'Elige una carpeta para mover la nota';

  @override
  String get createNewFolder => 'Crear nueva carpeta';

  @override
  String get createNewFolderSubtitle =>
      'Añade una carpeta nueva para organizar tus notas';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get folderName => 'Nombre de la carpeta';

  @override
  String get folderNameHint => 'Nombre de la carpeta';

  @override
  String get folderNameRequired => 'El nombre de la carpeta es obligatorio';

  @override
  String get folderNameEmpty => 'El nombre de la carpeta no puede estar vacío';

  @override
  String get folderNameDuplicate => 'Ya existe una carpeta con ese nombre';

  @override
  String get folderColor => 'Color de la carpeta';

  @override
  String get folderIcon => 'Icono de la carpeta';

  @override
  String get parentFolder => 'Carpeta padre';

  @override
  String get rootFolder => 'Carpeta raíz';

  @override
  String get rootLevel => 'Nivel raíz';

  @override
  String get description => 'Descripción';

  @override
  String get optional => 'Opcional';

  @override
  String get folderDescriptionHint => 'Descripción opcional para la carpeta';

  @override
  String get selectParentFolder => 'Selecciona la carpeta padre';

  @override
  String get unfiledNotes => 'Notas sin carpeta';

  @override
  String noteCount(int count) {
    return 'Número de notas';
  }

  @override
  String get searchFolders => 'Buscar en carpetas';

  @override
  String get showSearch => 'Mostrar búsqueda';

  @override
  String get hideSearch => 'Ocultar búsqueda';

  @override
  String get clearSearch => 'Limpiar búsqueda';

  @override
  String get noFoldersFound => 'No se encontraron carpetas';

  @override
  String noFoldersFoundSubtitle(String query) {
    return 'Prueba cambiando el filtro o crea una nueva carpeta';
  }

  @override
  String get loadFoldersError => 'Se produjo un error al cargar las carpetas';

  @override
  String get create => 'Crear';

  @override
  String get loadError => 'Error de carga';

  @override
  String get folderManagement => 'Gestión de carpetas';

  @override
  String get editFolder => 'Editar carpeta';

  @override
  String get deleteFolder => 'Eliminar carpeta';

  @override
  String get moveFolder => 'Mover carpeta';

  @override
  String get folderProperties => 'Propiedades de la carpeta';

  @override
  String get confirmDeleteFolder => 'Confirmar eliminación de carpeta';

  @override
  String get confirmDeleteFolderMessage =>
      'Esta carpeta y su contenido se eliminarán de forma permanente. ¿Quieres continuar?';

  @override
  String get confirmDeleteFolderAction => 'Eliminar carpeta';

  @override
  String get addToFolder => 'Añadir a carpeta';

  @override
  String get removeFromFolder => 'Quitar de la carpeta';

  @override
  String get moveToFolder => 'Mover a carpeta';

  @override
  String get folderEmpty => 'La carpeta está vacía';

  @override
  String get folderEmptySubtitle =>
      'Usa el icono + para añadir notas aquí o mueve notas a esta carpeta';

  @override
  String get allFolders => 'Todas las carpetas';

  @override
  String get rename => 'Renombrar';

  @override
  String get renameFolder => 'Renombrar carpeta';

  @override
  String get move => 'Mover';

  @override
  String get folderRenamed => 'Carpeta renombrada';

  @override
  String get folderMoved => 'Carpeta movida';

  @override
  String get folderDeleted => 'Carpeta eliminada';

  @override
  String get folderDeletedNotesMovedToInbox =>
      'La carpeta se ha eliminado y sus notas se han movido a la bandeja de entrada';

  @override
  String folderCreated(String name) {
    return 'Carpeta creada';
  }

  @override
  String deleteFolderConfirmation(String name) {
    return '¿Seguro que quieres eliminar esta carpeta?';
  }

  @override
  String get folderDeleteDescription =>
      'La carpeta se eliminará. Tus notas no se perderán y se moverán a la bandeja de entrada.';

  @override
  String get errorRenamingFolder =>
      'Se produjo un error al renombrar la carpeta';

  @override
  String get errorMovingFolder => 'Se produjo un error al mover la carpeta';

  @override
  String get errorDeletingFolder =>
      'Se produjo un error al eliminar la carpeta';

  @override
  String get errorCreatingFolder => 'Se produjo un error al crear la carpeta';

  @override
  String get errorLoadingFolders =>
      'Se produjo un error al cargar las carpetas';

  @override
  String get cannotMoveToDescendant =>
      'No puedes mover una carpeta a una de sus subcarpetas';

  @override
  String get selectFolder => 'Selecciona una carpeta';

  @override
  String get unfiled => 'Sin carpeta';

  @override
  String get createYourFirstFolder => 'Crea tu primera carpeta';

  @override
  String get expandAll => 'Expandir todo';

  @override
  String get collapseAll => 'Contraer todo';

  @override
  String get save => 'Guardar';

  @override
  String get done => 'Listo';

  @override
  String get ok => 'Aceptar';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get continueAction => 'Continuar';

  @override
  String get back => 'Atrás';

  @override
  String get next => 'Siguiente';

  @override
  String get finish => 'Finalizar';

  @override
  String get selectFiles => 'Seleccionar archivos';

  @override
  String get selectingFiles => 'Seleccionando archivos';

  @override
  String get scanningDirectory => 'Escaneando carpeta';

  @override
  String get readingFile => 'Leyendo archivo';

  @override
  String get parsingContent => 'Analizando contenido';

  @override
  String get convertingToBlocks => 'Convirtiendo a bloques';

  @override
  String get processingFiles => 'Procesando archivos';

  @override
  String get savingNotes => 'Guardando notas';

  @override
  String get completed => 'Completado';

  @override
  String get preparing => 'Preparando';

  @override
  String get rendering => 'Renderizando';

  @override
  String get finalizing => 'Finalizando';

  @override
  String get attachments => 'Adjuntos';

  @override
  String get dateModified => 'Fecha de modificación';

  @override
  String get highPriority => 'Alta prioridad';

  @override
  String get lowPriority => 'Baja prioridad';

  @override
  String get mediumPriority => 'Prioridad media';

  @override
  String get noTitle => 'Sin título';

  @override
  String get overdue => 'Atrasado';

  @override
  String get pinnedNotes => 'Notas fijadas';

  @override
  String get pinNote => 'Fijar nota';

  @override
  String get tags => 'Etiquetas';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get unpinNote => 'Desfijar nota';

  @override
  String get templatePickerTitle => 'Elige una plantilla';

  @override
  String get templatePickerSubtitle =>
      'Empieza con una plantilla o una nota en blanco';

  @override
  String get blankNoteOption => 'Nota en blanco';

  @override
  String get blankNoteDescription => 'Empieza con una nota vacía';

  @override
  String get noTemplatesTitle => 'Aún no hay plantillas';

  @override
  String get noTemplatesDescription =>
      'Crea tu primera plantilla para reutilizar estructuras frecuentes';

  @override
  String get templatesSection => 'PLANTILLAS';

  @override
  String get saveAsTemplate => 'Guardar como plantilla';

  @override
  String get fromTemplate => 'Desde plantilla';

  @override
  String templateSaved(String title) {
    return 'Plantilla guardada: $title';
  }

  @override
  String get failedToSaveTemplate => 'No se pudo guardar la plantilla';

  @override
  String get cannotSaveEmptyTemplate =>
      'No se puede guardar una nota vacía como plantilla';

  @override
  String get editTemplate => 'Editar plantilla';

  @override
  String get deleteTemplate => 'Eliminar plantilla';

  @override
  String get confirmDeleteTemplate => '¿Eliminar esta plantilla?';

  @override
  String get confirmDeleteTemplateMessage =>
      'Esta plantilla se eliminará de forma permanente. Esta acción no se puede deshacer.';

  @override
  String get templateDeleted => 'Plantilla eliminada';

  @override
  String get editingTemplate => 'Editando plantilla';

  @override
  String get templateOptions => 'Opciones de plantilla';

  @override
  String get defaultTemplate => 'Predeterminada';

  @override
  String get customTemplate => 'Personalizada';

  @override
  String get useTemplate => 'Usar plantilla';

  @override
  String get manageTemplates => 'Gestionar plantillas';

  @override
  String get notifEmailReceivedTitle =>
      '📧 Nuevo correo en tu bandeja de entrada';

  @override
  String notifEmailReceivedBody(String sender, String subject) {
    return 'Remitente $sender: $subject\\n\\nEl correo está listo para convertirse en nota.';
  }

  @override
  String get notifWebClipSavedTitle => '✂️ Contenido guardado correctamente';

  @override
  String notifWebClipSavedBody(String preview) {
    return '$preview\\n\\nSe ha guardado en tu bandeja de entrada y está listo para usarse.';
  }

  @override
  String get notifTaskReminderTitle => '⏰ Recordatorio de tarea';

  @override
  String notifTaskReminderBody(String taskTitle) {
    return '$taskTitle\\n\\n¡Debe hacerse ahora!';
  }

  @override
  String get notifTaskAssignedTitle => '📋 Nueva tarea con recordatorio';

  @override
  String notifTaskAssignedBody(String taskTitle, String dueDate) {
    return '$taskTitle\\nFecha: $dueDate\\n\\nEl recordatorio está configurado y te avisará.';
  }
}
