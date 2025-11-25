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
  String get tapToCreateFirstNote =>
      'İlk notunuzu oluşturmak için + simgesine dokunun';

  @override
  String get createFirstNote => 'İlk notunuzu oluşturun';

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
  String get logout => 'Oturumu Kapat';

  @override
  String get import => 'İçe Aktar';

  @override
  String get export => 'Dışa Aktar';

  @override
  String get importNotesTitle => 'Notları İçe Aktar';

  @override
  String get exportNotesTitle => 'Notları Dışa Aktar';

  @override
  String get chooseWhatToImport => 'Ne içe aktarılacağını seçin';

  @override
  String get exportYourNotes => 'Notlarınızı dışa aktarın';

  @override
  String availableNotes(int count) {
    return 'Kullanılabilir notlar';
  }

  @override
  String get markdownFiles => 'Markdown dosyaları';

  @override
  String get evernoteExport => 'Evernote dışa aktarma';

  @override
  String get obsidianVault => 'Obsidian kasası';

  @override
  String get importSingleMdFiles => 'Tek tek Markdown dosyalarını içe aktar';

  @override
  String get importEnexFiles => 'ENEX dosyalarını içe aktar';

  @override
  String get importObsidianVaultFolder => 'Obsidian kasa klasörünü içe aktar';

  @override
  String get selectImportType => 'İçe aktarma türünü seçin';

  @override
  String get markdown => 'Markdown';

  @override
  String get pdf => 'PDF';

  @override
  String get html => 'HTML';

  @override
  String get exportAsMdFiles => 'Markdown dosyaları olarak dışa aktar';

  @override
  String get exportAsPdfDocs => 'PDF belgeleri olarak dışa aktar';

  @override
  String get exportAsWebPages => 'Web sayfaları olarak dışa aktar';

  @override
  String get selectExportFormat => 'Dışa aktarma formatını seçin';

  @override
  String get chooseFormat => 'Format seçin';

  @override
  String get exportAllNotes => 'Tüm notları dışa aktar';

  @override
  String get exportRecentNotes => 'Son notları dışa aktar';

  @override
  String get exportLatest10 => 'Son 10 notu dışa aktar';

  @override
  String exportAllNotesDesc(int count) {
    return 'Hesabınızdaki tüm notları dışa aktarın';
  }

  @override
  String get exportRecentNotesDesc =>
      'Son oluşturulan ve güncellenen notları dışa aktarın';

  @override
  String get exportLatest10Desc => 'Yalnızca son 10 notu hızlıca dışa aktarın';

  @override
  String get importingNotes => 'Notlar içe aktarılıyor';

  @override
  String exportingToFormat(String format) {
    return 'Notlar dışa aktarılıyor';
  }

  @override
  String get initializingImport => 'İçe aktarma başlatılıyor';

  @override
  String get initializingExport => 'Dışa aktarma başlatılıyor';

  @override
  String currentFile(String filename) {
    return 'Geçerli dosya';
  }

  @override
  String progressCount(int current, int total) {
    return 'İlerleme sayacı';
  }

  @override
  String noteProgress(int current, int total) {
    return 'Not ilerlemesi';
  }

  @override
  String currentNote(String title) {
    return 'Geçerli not';
  }

  @override
  String get overallProgress => 'Genel ilerleme';

  @override
  String estimatedTimeRemaining(String time) {
    return 'Tahmini kalan süre';
  }

  @override
  String get cancel => 'İptal';

  @override
  String get importComplete => 'İçe aktarma tamamlandı';

  @override
  String get exportComplete => 'Dışa aktarma tamamlandı';

  @override
  String successfullyImported(int count) {
    return 'Başarıyla içe aktarıldı';
  }

  @override
  String successfullyExported(int count) {
    return 'Başarıyla dışa aktarıldı';
  }

  @override
  String errorsEncountered(int count) {
    return 'Hatalar ile karşılaşıldı';
  }

  @override
  String importTook(int seconds) {
    return 'İçe aktarma süresi';
  }

  @override
  String exportTook(int seconds) {
    return 'Dışa aktarma süresi';
  }

  @override
  String totalSize(String size) {
    return 'Toplam boyut';
  }

  @override
  String get errorDetails => 'Hata ayrıntıları';

  @override
  String get filesSavedToDownloads =>
      'Dosyalar İndirilenler klasörüne kaydedildi';

  @override
  String get failedExports => 'Başarısız dışa aktarmalar';

  @override
  String get shareFiles => 'Dosyaları paylaş';

  @override
  String get openFolder => 'Klasörü aç';

  @override
  String get close => 'Kapat';

  @override
  String get importError => 'İçe aktarma hatası';

  @override
  String get exportError => 'Dışa aktarma hatası';

  @override
  String get noNotesToExport => 'Dışa aktarılacak not yok';

  @override
  String get failedToSelectMarkdownFiles => 'Markdown dosyaları seçilemedi';

  @override
  String get failedToSelectEvernoteFile => 'Evernote dosyası seçilemedi';

  @override
  String get failedToSelectObsidianVault => 'Obsidian kasası seçilemedi';

  @override
  String get importFailed => 'İçe aktarma başarısız';

  @override
  String get exportFailed => 'Dışa aktarma başarısız';

  @override
  String get obsidianImportFailed => 'Obsidian içe aktarma başarısız oldu';

  @override
  String get noFilesAvailableToShare => 'Paylaşılabilir dosya bulunamadı';

  @override
  String get failedToShareExportedFile => 'Dışa aktarılan dosya paylaşılamadı';

  @override
  String get errorSharingFiles => 'Dosyalar paylaşılırken hata oluştu';

  @override
  String get couldNotOpenExportsFolder => 'Dışa aktarma klasörü açılamadı';

  @override
  String get pdfExportMayFailInSimulator =>
      'PDF dışa aktarma, simülatörde başarısız olabilir';

  @override
  String get testOnPhysicalDevice => 'Lütfen gerçek bir cihazda test edin';

  @override
  String get checkInternetConnection =>
      'Lütfen internet bağlantınızı kontrol edin';

  @override
  String get tryExportingAsMarkdown => 'Markdown olarak dışa aktarmayı deneyin';

  @override
  String get networkRelatedIssueDetected =>
      'Ağ ile ilgili bir sorun tespit edildi';

  @override
  String get tryAgainInFewMoments => 'Biraz sonra tekrar deneyin';

  @override
  String get useDifferentExportFormat =>
      'Farklı bir dışa aktarma formatı kullanın';

  @override
  String get tryMarkdown => 'Markdown formatını deneyin';

  @override
  String get editNote => 'Notu düzenle';

  @override
  String get deleteNote => 'Notu Sil';

  @override
  String get delete => 'Sil';

  @override
  String get edit => 'Düzenle';

  @override
  String get untitled => 'Başlıksız';

  @override
  String get noContent => 'İçerik yok';

  @override
  String get justNow => 'Az önce';

  @override
  String minutesAgo(int count) {
    return 'dakika önce';
  }

  @override
  String hoursAgo(int count) {
    return 'saat önce';
  }

  @override
  String daysAgo(int count) {
    return 'gün önce';
  }

  @override
  String areYouSureDeleteNote(String title) {
    return 'Bu notu silmek istediğinizden emin misiniz?';
  }

  @override
  String get noteDeleted => 'Not silindi';

  @override
  String get errorDeletingNote => 'Not silinirken bir hata oluştu';

  @override
  String get welcomeBack => 'Tekrar Hoş Geldiniz';

  @override
  String get online => 'Çevrimiçi';

  @override
  String get offline => 'Çevrimdışı';

  @override
  String get loading => 'Yükleniyor';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get errorLoadingNotes => 'Notlar yüklenirken hata oluştu';

  @override
  String get searchFeatureTemporarilyDisabled =>
      'Arama özelliği geçici olarak devre dışı';

  @override
  String get exportFunctionalityComingSoon =>
      'Dışa aktarma işlevi yakında geliyor';

  @override
  String get settingsScreenComingSoon => 'Ayarlar ekranı yakında geliyor';

  @override
  String get areYouSureSignOut => 'Çıkış yapmak istediğinizden emin misiniz?';

  @override
  String get productionGradeImportSystemReady =>
      'Üretim seviyesinde içe aktarma sistemi hazır';

  @override
  String get supportedFormats => 'Desteklenen formatlar';

  @override
  String get singleMarkdownFiles => 'Tekli Markdown dosyaları';

  @override
  String get evernoteFiles => 'Evernote dosyaları';

  @override
  String get obsidianVaultFolders => 'Obsidian kasa klasörleri';

  @override
  String get importFeatures => 'İçe aktarma özellikleri';

  @override
  String get securityValidation => 'Güvenlik doğrulaması';

  @override
  String get progressTracking => 'İlerleme takibi';

  @override
  String get errorRecovery => 'Hata kurtarma';

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
  String get contentSanitization => 'İçerik temizleme';

  @override
  String get featuresSecurityValidation =>
      'Güvenlik doğrulaması ve içerik temizleme';

  @override
  String get exportAsMarkdownFiles => 'Markdown dosyaları olarak dışa aktar';

  @override
  String get exportAsPdfDocuments => 'PDF belgeleri olarak dışa aktar';

  @override
  String get exportAsHtmlFiles => 'HTML dosyaları olarak dışa aktar';

  @override
  String get featuresRichFormatting =>
      'Zengin biçimlendirme ve güvenli dışa aktarma';

  @override
  String get exportCancelled => 'Dışa aktarma iptal edildi';

  @override
  String get checkDownloadsFolderForFiles =>
      'Dosyalar için İndirilenler klasörünü kontrol edin';

  @override
  String get filesSavedInAppDocuments =>
      'Dosyalar uygulamanın belgeler klasörüne kaydedildi';

  @override
  String statusPhase(String phase) {
    return 'Aşama durumu';
  }

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get account => 'Hesap';

  @override
  String get sync => 'Senkronizasyon';

  @override
  String get appearance => 'Görünüm';

  @override
  String get language => 'Dil';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get security => 'Güvenlik';

  @override
  String get importExport => 'İçe/Dışa Aktarma';

  @override
  String get helpAbout => 'Yardım ve Hakkında';

  @override
  String get signedInAs => 'Giriş yapılan hesap';

  @override
  String get signOutConfirm => 'Çıkış yapmak istediğinizden emin misiniz?';

  @override
  String get manageAccount => 'Hesabı yönet';

  @override
  String get syncMode => 'Senkronizasyon modu';

  @override
  String get automaticSync => 'Otomatik senkronizasyon';

  @override
  String get manualSync => 'Manuel senkronizasyon';

  @override
  String get automaticSyncDesc =>
      'Değişiklikleri arka planda otomatik olarak senkronize et';

  @override
  String get manualSyncDesc =>
      'Verileri yalnızca siz istediğinizde senkronize edin';

  @override
  String get syncNow => 'Şimdi senkronize et';

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
  String get accentColor => 'Vurgu rengi';

  @override
  String get selectLanguage => 'Dil seçin';

  @override
  String get english => 'İngilizce';

  @override
  String get turkish => 'Türkçe';

  @override
  String get enableNotifications => 'Bildirimleri Etkinleştir';

  @override
  String get openSystemSettings => 'Sistem ayarlarını aç';

  @override
  String get notificationPermissions => 'Bildirim izinleri';

  @override
  String get endToEndEncryption => 'Uçtan uca şifreleme';

  @override
  String get encryptionEnabled => 'Şifreleme etkin';

  @override
  String get analyticsOptIn => 'Analitiklere katıl';

  @override
  String get analyticsDesc =>
      'Uygulamanın iyileştirilmesine yardımcı olmak için anonim kullanım verilerini paylaşın';

  @override
  String get biometricLock => 'Biyometrik kilit';

  @override
  String get biometricDesc =>
      'Notlara erişmek için parmak izi veya yüz tanımayı kullanın';

  @override
  String get biometricNotAvailable =>
      'Bu cihazda biyometrik kimlik doğrulama kullanılamıyor';

  @override
  String get version => 'Sürüm';

  @override
  String get buildNumber => 'Derleme numarası';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get termsOfService => 'Kullanım Koşulları';

  @override
  String get contactSupport => 'Destek ile iletişime geç';

  @override
  String get rateApp => 'Uygulamayı değerlendir';

  @override
  String get userGuide => 'Kullanım kılavuzu';

  @override
  String get helpAndSupport => 'Yardım ve destek';

  @override
  String get documentation => 'Dokümantasyon';

  @override
  String get aboutApp => 'Uygulama hakkında';

  @override
  String get sharedNote => 'Paylaşılan not';

  @override
  String get sharedText => 'Paylaşılan metin';

  @override
  String get sharedImage => 'Paylaşılan görsel';

  @override
  String get sharedLink => 'Paylaşılan bağlantı';

  @override
  String get sharedFile => 'Paylaşılan dosya';

  @override
  String sharedFrom(String source, String date) {
    return 'Paylaşıldığı yer';
  }

  @override
  String get sharedImageCouldNotBeProcessed => 'Paylaşılan görsel işlenemedi';

  @override
  String get folders => 'Klasörler';

  @override
  String get folderPickerTitle => 'Klasör seçin';

  @override
  String get folderPickerSubtitle => 'Notu taşımak için bir klasör seçin';

  @override
  String get createNewFolder => 'Yeni klasör oluştur';

  @override
  String get createNewFolderSubtitle =>
      'Notlarınızı düzenlemek için yeni bir klasör ekleyin';

  @override
  String get newFolder => 'Yeni klasör';

  @override
  String get folderName => 'Klasör Adı';

  @override
  String get folderNameHint => 'Klasör adı';

  @override
  String get folderNameRequired => 'Klasör adı gerekli';

  @override
  String get folderNameEmpty => 'Klasör adı boş olamaz';

  @override
  String get folderNameDuplicate => 'Bu adda bir klasör zaten var';

  @override
  String get folderColor => 'Klasör rengi';

  @override
  String get folderIcon => 'Klasör simgesi';

  @override
  String get parentFolder => 'Ana klasör';

  @override
  String get rootFolder => 'Kök klasör';

  @override
  String get rootLevel => 'Kök seviye';

  @override
  String get description => 'Açıklama';

  @override
  String get optional => 'İsteğe bağlı';

  @override
  String get folderDescriptionHint => 'Klasör için isteğe bağlı açıklama';

  @override
  String get selectParentFolder => 'Ana klasörü seçin';

  @override
  String get unfiledNotes => 'Klasörsüz notlar';

  @override
  String noteCount(int count) {
    return 'Not sayısı';
  }

  @override
  String get searchFolders => 'Klasörlerde ara';

  @override
  String get showSearch => 'Aramayı göster';

  @override
  String get hideSearch => 'Aramayı gizle';

  @override
  String get clearSearch => 'Aramayı temizle';

  @override
  String get noFoldersFound => 'Klasör bulunamadı';

  @override
  String noFoldersFoundSubtitle(String query) {
    return 'Filtreyi değiştirerek veya yeni bir klasör oluşturarak tekrar deneyin';
  }

  @override
  String get loadFoldersError => 'Klasörler yüklenirken hata oluştu';

  @override
  String get create => 'Oluştur';

  @override
  String get loadError => 'Yükleme hatası';

  @override
  String get folderManagement => 'Klasör yönetimi';

  @override
  String get editFolder => 'Klasörü düzenle';

  @override
  String get deleteFolder => 'Klasörü sil';

  @override
  String get moveFolder => 'Klasörü taşı';

  @override
  String get folderProperties => 'Klasör özellikleri';

  @override
  String get confirmDeleteFolder => 'Klasörü silmeyi onayla';

  @override
  String get confirmDeleteFolderMessage =>
      'Bu klasör ve içeriği kalıcı olarak silinecek. Devam etmek istiyor musunuz?';

  @override
  String get confirmDeleteFolderAction => 'Klasörü sil';

  @override
  String get addToFolder => 'Klasöre ekle';

  @override
  String get removeFromFolder => 'Klasörden kaldır';

  @override
  String get moveToFolder => 'Klasöre Taşı';

  @override
  String get folderEmpty => 'Klasör boş';

  @override
  String get folderEmptySubtitle =>
      'Buraya not eklemek için + simgesini kullanın veya notları buraya taşıyın';

  @override
  String get allFolders => 'Tüm klasörler';

  @override
  String get rename => 'Yeniden adlandır';

  @override
  String get renameFolder => 'Klasörü yeniden adlandır';

  @override
  String get move => 'Taşı';

  @override
  String get folderRenamed => 'Klasör yeniden adlandırıldı';

  @override
  String get folderMoved => 'Klasör taşındı';

  @override
  String get folderDeleted => 'Klasör silindi';

  @override
  String get folderDeletedNotesMovedToInbox =>
      'Klasör silindi, içindeki notlar gelen kutusuna taşındı';

  @override
  String folderCreated(String name) {
    return 'Klasör oluşturuldu';
  }

  @override
  String deleteFolderConfirmation(String name) {
    return 'Bu klasörü silmek istediğinizden emin misiniz?';
  }

  @override
  String get folderDeleteDescription =>
      'Klasör silinecek. Notlarınız kaybolmayacak ve gelen kutusuna taşınacak.';

  @override
  String get errorRenamingFolder =>
      'Klasör yeniden adlandırılırken hata oluştu';

  @override
  String get errorMovingFolder => 'Klasör taşınırken hata oluştu';

  @override
  String get errorDeletingFolder => 'Klasör silinirken hata oluştu';

  @override
  String get errorCreatingFolder => 'Klasör oluşturulurken hata oluştu';

  @override
  String get errorLoadingFolders => 'Klasörler yüklenirken hata oluştu';

  @override
  String get cannotMoveToDescendant =>
      'Bir klasörü kendi alt klasörüne taşıyamazsınız';

  @override
  String get selectFolder => 'Klasör seçin';

  @override
  String get unfiled => 'Klasörsüz';

  @override
  String get createYourFirstFolder => 'İlk klasörünüzü oluşturun';

  @override
  String get expandAll => 'Tümünü genişlet';

  @override
  String get collapseAll => 'Tümünü daralt';

  @override
  String get save => 'Kaydet';

  @override
  String get done => 'Bitti';

  @override
  String get ok => 'Tamam';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get continueAction => 'Devam et';

  @override
  String get back => 'Geri';

  @override
  String get next => 'İleri';

  @override
  String get finish => 'Bitir';

  @override
  String get selectFiles => 'Dosyaları seç';

  @override
  String get selectingFiles => 'Dosyalar seçiliyor';

  @override
  String get scanningDirectory => 'Klasör taranıyor';

  @override
  String get readingFile => 'Dosya okunuyor';

  @override
  String get parsingContent => 'İçerik ayrıştırılıyor';

  @override
  String get convertingToBlocks => 'Bloklara dönüştürülüyor';

  @override
  String get processingFiles => 'Dosyalar işleniyor';

  @override
  String get savingNotes => 'Notlar kaydediliyor';

  @override
  String get completed => 'Tamamlandı';

  @override
  String get preparing => 'Hazırlanıyor';

  @override
  String get rendering => 'Oluşturuluyor';

  @override
  String get finalizing => 'Sonlandırılıyor';

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
  String get noTitle => 'Başlık yok';

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
