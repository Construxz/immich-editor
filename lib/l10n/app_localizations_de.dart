// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get languageSystem => 'Sprache des Geräts';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get save => 'Speichern';

  @override
  String get settings => 'Einstellungen';

  @override
  String get anyway => 'Trotzdem';

  @override
  String get original => 'Original';

  @override
  String get useMobileDataTitle => 'Mobile Daten verwenden?';

  @override
  String get stepRendering => 'Wird gerendert …';

  @override
  String get stepUploading => 'Wird hochgeladen …';

  @override
  String get stepChecking => 'Wird geprüft …';

  @override
  String get stepStacking => 'Wird gestapelt …';

  @override
  String get photoGoneFromDevice => 'Foto nicht mehr auf dem Gerät';

  @override
  String get toolBrightness => 'Helligkeit';

  @override
  String get toolContrast => 'Kontrast';

  @override
  String get toolWhitePoint => 'Weißpunkt';

  @override
  String get toolHighlights => 'Spitzlichter';

  @override
  String get toolShadows => 'Schatten';

  @override
  String get toolBlackPoint => 'Schwarzpunkt';

  @override
  String get toolSaturation => 'Sättigung';

  @override
  String get toolWarmth => 'Wärme';

  @override
  String get toolTint => 'Färbung';

  @override
  String get toolBlueTones => 'Blautöne';

  @override
  String get toolVignette => 'Vignette';

  @override
  String get toolSharpness => 'Schärfe';

  @override
  String get editorDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get editorDiscard => 'Verwerfen';

  @override
  String get editorLoadingOriginal => 'Original wird geladen …';

  @override
  String get editorUndo => 'Rückgängig';

  @override
  String get editorRedo => 'Wiederholen';

  @override
  String get editorHdrOn => 'HDR an';

  @override
  String get editorHdrOff => 'HDR aus';

  @override
  String get editorMore => 'Mehr';

  @override
  String get editorResetAll => 'Alles zurücksetzen';

  @override
  String get editorBackToSaved => 'Zur gespeicherten Bearbeitung';

  @override
  String get editorAspectRatio => 'Seitenverhältnis';

  @override
  String get editorRatioFree => 'Frei';

  @override
  String get editorRatioSquare => 'Quadrat';

  @override
  String get editorFlip => 'Spiegeln';

  @override
  String get editorRotate => 'Drehen';

  @override
  String get editorTabPresets => 'Presets';

  @override
  String get editorTabCrop => 'Zuschneiden';

  @override
  String get editorTabAdjust => 'Anpassen';

  @override
  String get presetSaveTitle => 'Als Preset sichern';

  @override
  String get presetName => 'Name';

  @override
  String get presetSave => 'Sichern';

  @override
  String presetDeleteTitle(String name) {
    return 'Preset „$name\" löschen?';
  }

  @override
  String get presetDelete => 'Löschen';

  @override
  String get saveReplaceCopy => 'Kopie ersetzen';

  @override
  String get saveReplaceCopyHint =>
      'Die bisherige Bearbeitung geht in den Papierkorb';

  @override
  String get saveAsAnotherCopy => 'Als weitere Kopie speichern';

  @override
  String get saveAsAnotherCopyHint => 'Beide Bearbeitungen liegen im Stapel';

  @override
  String get saveMobileDataBody =>
      'Zum Speichern muss das Original geladen oder die Kopie hochgeladen werden — laut Einstellung nur im WLAN.';

  @override
  String get saveDoneChecked => 'Gespeichert und geprüft';

  @override
  String get saveDoneOnDevice =>
      'Auf dem Gerät gespeichert — gestapelt wird nach dem Backup';

  @override
  String saveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String saveCopyMismatch(String id) {
    return 'Kopie auf dem Server weicht ab ($id)';
  }

  @override
  String get saveOpenInImmichTitle => 'Bearbeitung in Immich öffnen?';

  @override
  String saveOpenInImmichBody(String folder, String album) {
    return 'Der Ordner „$folder\" wird nicht in Immich gesichert. Die Bearbeitung archiviert hochladen — nicht in der Zeitleiste —, ins Album „$album\" legen und in der Immich-App öffnen? Dort kannst du sie in ein anderes Album legen.';
  }

  @override
  String get saveDeviceOnly => 'Nur auf dem Gerät';

  @override
  String get saveOpenInImmich => 'In Immich öffnen';

  @override
  String saveArchived(String album) {
    return 'Archiviert in Immich, Album „$album\"';
  }

  @override
  String saveArchivedNoApp(String album) {
    return 'Archiviert in Immich, Album „$album\" — die Immich-App fehlt';
  }

  @override
  String get galleryNoPresets =>
      'Noch keine Presets — im Editor unter „Presets\" sichern';

  @override
  String galleryApplyPresetTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preset auf $count Fotos anwenden',
      one: 'Preset auf 1 Foto anwenden',
    );
    return '$_temp0';
  }

  @override
  String get galleryMobileDataOriginals =>
      'Die Originale der Online-Fotos werden geladen — laut Einstellung nur im WLAN.';

  @override
  String galleryApplyingPreset(String name) {
    return '„$name\" wird angewendet';
  }

  @override
  String galleryProgress(int done, int total) {
    return '$done von $total Fotos';
  }

  @override
  String galleryCopiesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kopien gespeichert',
      one: '1 Kopie gespeichert',
    );
    return '$_temp0';
  }

  @override
  String galleryCopiesSavedFailed(int count, int failed, String error) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kopien',
      one: '1 Kopie',
    );
    return '$_temp0 gespeichert, $failed fehlgeschlagen: $error';
  }

  @override
  String get galleryTabDevice => 'Gerät';

  @override
  String get galleryTabLibrary => 'Bibliothek';

  @override
  String get galleryTabPhotos => 'Fotos';

  @override
  String get galleryEndSelection => 'Auswahl beenden';

  @override
  String gallerySelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String get galleryApplyPreset => 'Preset anwenden';

  @override
  String get galleryNoPhotos => 'Noch keine Fotos.';

  @override
  String get galleryNoDevicePermission =>
      'Die App darf die Fotos auf dem Gerät nicht sehen.';

  @override
  String get galleryNoDevicePhotos => 'Keine Fotos auf dem Gerät.';

  @override
  String get galleryNoServerPhotos => 'Noch keine Fotos auf dem Server.';

  @override
  String get galleryRetry => 'Nochmal';

  @override
  String get libraryOnDevice => 'Auf diesem Gerät';

  @override
  String libraryNotInImmich(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos · nicht in Immich',
      one: '1 Foto · nicht in Immich',
    );
    return '$_temp0';
  }

  @override
  String libraryBackedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos · gesichert',
      one: '1 Foto · gesichert',
    );
    return '$_temp0';
  }

  @override
  String libraryPartlyBackedUp(int count, int backedUp) {
    return '$count Fotos · $backedUp gesichert';
  }

  @override
  String get tilePhoto => 'Foto';

  @override
  String tilePhotoStack(int count) {
    return 'Foto, Stapel mit $count';
  }

  @override
  String get tileDeviceOnly => 'nur auf dem Gerät';

  @override
  String get tileServerOnly => 'nur auf dem Server';

  @override
  String get tileBackedUp => 'gesichert';

  @override
  String viewerKeepTitle(String name) {
    return '$name behalten?';
  }

  @override
  String viewerKeepText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die anderen $count Fotos des Stapels gehen in Immichs Papierkorb — dort lassen sie sich wiederherstellen.',
      one: 'Das andere Foto des Stapels geht in Immichs Papierkorb — dort lässt es sich wiederherstellen.',
    );
    return '$_temp0';
  }

  @override
  String get viewerDeleteRest => 'Rest löschen';

  @override
  String get viewerInfo => 'Infos';

  @override
  String get viewerEdit => 'Bearbeiten';

  @override
  String get viewerStack => 'Stapel';

  @override
  String get viewerSetPrimary => 'Als Hauptfoto festlegen';

  @override
  String get viewerKeepThis => 'Dieses Foto behalten, den Rest löschen';

  @override
  String get serverTimeout =>
      'Der Server antwortet nicht (Zeitüberschreitung).';

  @override
  String serverUnreachable(String message) {
    return 'Server nicht erreichbar: $message';
  }

  @override
  String serverConnectionLost(String message) {
    return 'Verbindung abgebrochen: $message';
  }

  @override
  String get serverSessionExpired =>
      'Anmeldung abgelaufen — bitte neu anmelden.';

  @override
  String get checksumsTitle => 'Bildabgleich';

  @override
  String get checksumsExplanation =>
      'Die App rechnet einmal für jedes Foto auf diesem Gerät eine Prüfsumme. Daran erkennt sie, welche Fotos schon in Immich liegen — das zeigen die Wolken in der Zeitleiste.\n\nDas passiert nur beim ersten Mal, danach nur für neue Fotos. Hochgeladen wird dabei nichts; an den Server gehen nur die Prüfsummen.';

  @override
  String get checksumsInBackground => 'Im Hintergrund';

  @override
  String checksumsProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString von $totalString Fotos';
  }

  @override
  String checksumsProgressRemaining(int done, int total, String duration) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString von $totalString Fotos · fertig in etwa $duration';
  }

  @override
  String get checksumsOneMinute => 'einer Minute';

  @override
  String checksumsMinutes(int minutes) {
    return '$minutes Minuten';
  }

  @override
  String checksumsHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get accountTooltip => 'Konto und Einstellungen';

  @override
  String get accountStorageTitle => 'Speicherplatz auf dem Server';

  @override
  String accountStorageUsed(String used, String total) {
    return '$used von $total belegt';
  }

  @override
  String get accountAppVersion => 'App-Version';

  @override
  String get accountServerVersion => 'Server-Version';

  @override
  String get accountServerAddress => 'Server-Adresse';

  @override
  String get accountLogout => 'Abmelden';

  @override
  String get accountLogoutQuestion => 'Wirklich abmelden?';

  @override
  String get accountLogoutConfirm => 'Ja';

  @override
  String get accountLicenses => 'Lizenzen';

  @override
  String settingsPendingEdits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bearbeitungen warten auf das Backup',
      one: '1 Bearbeitung wartet auf das Backup',
      zero: 'Nichts wartet auf das Backup',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguageText => 'Deutsch, Englisch oder wie das Gerät';

  @override
  String get settingsViewTitle => 'Ansicht';

  @override
  String get settingsViewText => 'Eine Zeitleiste über Gerät und Server';

  @override
  String get settingsEditTitle => 'Bearbeiten';

  @override
  String get settingsEditText => 'HDR in Vorschau und Kopie';

  @override
  String get settingsSaveTitle => 'Speichern';

  @override
  String get settingsSaveText => 'Wohin Bearbeitungen von Online-Fotos gehen';

  @override
  String get settingsNetworkTitle => 'Netzwerk';

  @override
  String get settingsNetworkText => 'Mobile Daten für Originale und Uploads';

  @override
  String get settingsStackingTitle => 'Stapeln';

  @override
  String get settingsStackingText => 'Bearbeitungen, die auf das Backup warten';

  @override
  String get settingsTogetherTitle => 'Gerät und Server zusammen';

  @override
  String get settingsTogetherText =>
      'Eine Zeitleiste wie in der Immich-App; die Wolke unten rechts zeigt, ob ein Foto nur auf dem Gerät, nur auf dem Server oder auf beiden liegt. Aus: zwei Reiter „Gerät\" und „Immich\".';

  @override
  String get settingsHdrText =>
      'Ultra-HDR-Fotos in HDR zeigen und als Ultra HDR speichern';

  @override
  String get settingsOnlineTitle => 'Online-Fotos übers Gerät sichern';

  @override
  String get settingsOnlineText =>
      'Die Kopie eines Fotos, das nur auf dem Server liegt, kommt ins Kamera-Album; die Immich-App sichert sie, danach verlässt sie das Gerät. Aus: direkt auf den Server.';

  @override
  String get settingsMobileDataTitle => 'Mobile Daten';

  @override
  String get settingsMobileDataText =>
      'Originale laden und Kopien hochladen auch ohne WLAN. Aus: nur nach Rückfrage.';

  @override
  String settingsStackingExplanation(String email) {
    return 'Auf dem Gerät gespeicherte Kopien stapelt die App, sobald die Immich-App Original und Kopie gesichert hat — dafür muss sie mit $email angemeldet sein.';
  }

  @override
  String get settingsStackNow => 'Jetzt stapeln';

  @override
  String loginUntestedVersion(int version) {
    return 'Immich $version.x ist nicht geprüft — die App kann sich unerwartet verhalten.';
  }

  @override
  String loginFailed(String error) {
    return 'Anmeldung fehlgeschlagen: $error';
  }

  @override
  String get loginEmail => 'E-Mail';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginButton => 'Anmelden';

  @override
  String get settingsFoldersTitle => 'Geräteordner';

  @override
  String get settingsFoldersText =>
      'Was unter „Fotos“ erscheint, was die Bibliothek ausblendet';

  @override
  String get foldersInPhotos => 'Unter „Fotos“ zeigen';

  @override
  String get foldersInPhotosHint =>
      'Unter „Fotos“ stehen alle Fotos auf dem Server und vom Gerät nur diese Ordner — wie bei Google Fotos die Kamera.';

  @override
  String get foldersHidden => 'In der Bibliothek ausblenden';

  @override
  String get foldersHiddenHint =>
      'Diese Ordner erscheinen nicht unter „Bibliothek“.';

  @override
  String get settingsOpenWithTitle => 'Bearbeitungen öffnen mit';

  @override
  String get settingsOpenWithAsk => 'Android fragen';

  @override
  String get settingsOpenWithText =>
      'Für Fotos aus Ordnern, die Immich nicht sichert. „Android fragen“ bietet „Nur diesmal“ und „Immer“ an; eine App hier gilt auch, wenn in Android „Immer“ gewählt ist.';

  @override
  String settingsPendingWhere(String folder) {
    return 'Kopie in $folder — noch nicht in Immich';
  }

  @override
  String get settingsPendingNotFound =>
      'Kopie auf dem Gerät noch nicht gefunden';

  @override
  String get settingsPendingUnknown => 'Bearbeitung';

  @override
  String get settingsPendingDiscard => 'Nicht mehr warten — die Kopie bleibt';

  @override
  String get settingsHdrButtonTitle => 'HDR-Knopf anzeigen';

  @override
  String get settingsHdrButtonText =>
      'In Galerie, Betrachter und Editor; er schaltet HDR überall. Aus: nur hier.';
}
