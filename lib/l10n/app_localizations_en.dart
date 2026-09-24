// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageTitle => 'Language';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get settings => 'Settings';

  @override
  String get anyway => 'Anyway';

  @override
  String get original => 'Original';

  @override
  String get useMobileDataTitle => 'Use mobile data?';

  @override
  String get stepRendering => 'Rendering …';

  @override
  String get stepUploading => 'Uploading …';

  @override
  String get stepChecking => 'Checking …';

  @override
  String get stepStacking => 'Stacking …';

  @override
  String get photoGoneFromDevice => 'Photo is no longer on the device';

  @override
  String get toolBrightness => 'Brightness';

  @override
  String get toolContrast => 'Contrast';

  @override
  String get toolWhitePoint => 'White point';

  @override
  String get toolHighlights => 'Highlights';

  @override
  String get toolShadows => 'Shadows';

  @override
  String get toolBlackPoint => 'Black point';

  @override
  String get toolSaturation => 'Saturation';

  @override
  String get toolWarmth => 'Warmth';

  @override
  String get toolTint => 'Tint';

  @override
  String get toolBlueTones => 'Blue tone';

  @override
  String get toolVignette => 'Vignette';

  @override
  String get toolSharpness => 'Sharpen';

  @override
  String get editorDiscardTitle => 'Discard changes?';

  @override
  String get editorDiscard => 'Discard';

  @override
  String get editorLoadingOriginal => 'Loading original …';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorRedo => 'Redo';

  @override
  String get editorHdrOn => 'HDR on';

  @override
  String get editorHdrOff => 'HDR off';

  @override
  String get editorMore => 'More';

  @override
  String get editorResetAll => 'Reset all';

  @override
  String get editorBackToSaved => 'Back to saved edit';

  @override
  String get editorAspectRatio => 'Aspect ratio';

  @override
  String get editorRatioFree => 'Free';

  @override
  String get editorRatioSquare => 'Square';

  @override
  String get editorFlip => 'Flip';

  @override
  String get editorRotate => 'Rotate';

  @override
  String get editorTabPresets => 'Presets';

  @override
  String get editorTabCrop => 'Crop';

  @override
  String get editorTabAdjust => 'Adjust';

  @override
  String get editorDone => 'Done';

  @override
  String get editorReset => 'Reset';

  @override
  String get editorTabFilter => 'Filters';

  @override
  String get filterNone => 'None';

  @override
  String get filterVivid => 'Vivid';

  @override
  String get filterWarm => 'Warm';

  @override
  String get filterCool => 'Cool';

  @override
  String get filterFilm => 'Film';

  @override
  String get filterFade => 'Faded';

  @override
  String get filterBw => 'Black & white';

  @override
  String get filterNoir => 'Noir';

  @override
  String get filterSepia => 'Sepia';

  @override
  String get presetSaveTitle => 'Save as preset';

  @override
  String get presetName => 'Name';

  @override
  String get presetSave => 'Save';

  @override
  String get presetOptimize => 'Enhance';

  @override
  String get presetOptimizeNothing => 'The photo is already balanced.';

  @override
  String presetDeleteTitle(String name) {
    return 'Delete preset “$name”?';
  }

  @override
  String get presetDelete => 'Delete';

  @override
  String get saveReplaceCopy => 'Replace copy';

  @override
  String get saveReplaceCopyHint => 'The previous edit moves to the trash';

  @override
  String get saveAsAnotherCopy => 'Save as another copy';

  @override
  String get saveAsAnotherCopyHint => 'Both edits stay in the stack';

  @override
  String get saveMobileDataBody =>
      'Saving needs to download the original or upload the copy — which your settings allow only on Wi-Fi.';

  @override
  String get saveDoneChecked => 'Saved and verified';

  @override
  String get saveDoneOnDevice =>
      'Saved on the device — stacked after the backup';

  @override
  String saveFailed(String error) {
    return 'Saving failed: $error';
  }

  @override
  String saveCopyMismatch(String id) {
    return 'Copy on the server differs ($id)';
  }

  @override
  String get saveOpenInImmichTitle => 'Open edit in Immich?';

  @override
  String saveOpenInImmichBody(String folder, String album) {
    return 'The folder “$folder” is not backed up to Immich. Upload the edit archived — not in the timeline —, add it to the album “$album” and open it in the Immich app? There you can move it to another album.';
  }

  @override
  String get saveDeviceOnly => 'Device only';

  @override
  String get saveOpenInImmich => 'Open in Immich';

  @override
  String saveArchived(String album) {
    return 'Archived in Immich, album “$album”';
  }

  @override
  String saveArchivedNoApp(String album) {
    return 'Archived in Immich, album “$album” — the Immich app is missing';
  }

  @override
  String galleryApplyPresetTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apply preset to $count photos',
      one: 'Apply preset to 1 photo',
    );
    return '$_temp0';
  }

  @override
  String get galleryMobileDataOriginals =>
      'The originals of the online photos will be downloaded — your settings allow that only on Wi-Fi.';

  @override
  String galleryApplyingPreset(String name) {
    return 'Applying \"$name\"';
  }

  @override
  String galleryProgress(int done, int total) {
    return '$done of $total photos';
  }

  @override
  String galleryCopiesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies saved',
      one: '1 copy saved',
    );
    return '$_temp0';
  }

  @override
  String galleryCopiesSavedFailed(int count, int failed, String error) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: '1 copy',
    );
    return '$_temp0 saved, $failed failed: $error';
  }

  @override
  String get galleryTabDevice => 'Device';

  @override
  String get galleryTabLibrary => 'Library';

  @override
  String get galleryTabPhotos => 'Photos';

  @override
  String get galleryEndSelection => 'Clear selection';

  @override
  String gallerySelected(int count) {
    return '$count selected';
  }

  @override
  String get galleryApplyPreset => 'Apply preset';

  @override
  String get galleryOptimizeEach => 'Computed for each photo';

  @override
  String get galleryNoPhotos => 'No photos yet.';

  @override
  String get galleryNoDevicePermission =>
      'The app is not allowed to see the photos on this device.';

  @override
  String get galleryNoDevicePhotos => 'No photos on this device.';

  @override
  String get galleryNoServerPhotos => 'No photos on the server yet.';

  @override
  String get galleryRetry => 'Try again';

  @override
  String get libraryOnDevice => 'On this device';

  @override
  String libraryNotInImmich(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos · not in Immich',
      one: '1 photo · not in Immich',
    );
    return '$_temp0';
  }

  @override
  String libraryBackedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos · backed up',
      one: '1 photo · backed up',
    );
    return '$_temp0';
  }

  @override
  String libraryPartlyBackedUp(int count, int backedUp) {
    return '$count photos · $backedUp backed up';
  }

  @override
  String get tilePhoto => 'Photo';

  @override
  String tilePhotoStack(int count) {
    return 'Photo, stack of $count';
  }

  @override
  String get tileDeviceOnly => 'only on this device';

  @override
  String get tileServerOnly => 'only on the server';

  @override
  String get tileBackedUp => 'backed up';

  @override
  String viewerKeepTitle(String name) {
    return 'Keep $name?';
  }

  @override
  String viewerKeepText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The other $count photos of the stack go to the Immich trash — you can restore them there.',
      one: 'The other photo of the stack goes to the Immich trash — you can restore it there.',
    );
    return '$_temp0';
  }

  @override
  String get viewerDeleteRest => 'Delete the rest';

  @override
  String get viewerInfo => 'Info';

  @override
  String get viewerUltraHdr => 'Ultra HDR';

  @override
  String get viewerEdit => 'Edit';

  @override
  String get viewerStack => 'Stack';

  @override
  String get viewerSetPrimary => 'Set as primary photo';

  @override
  String get viewerKeepThis => 'Keep this photo, delete the rest';

  @override
  String get serverTimeout => 'The server is not responding (timeout).';

  @override
  String serverUnreachable(String message) {
    return 'Server unreachable: $message';
  }

  @override
  String serverConnectionLost(String message) {
    return 'Connection lost: $message';
  }

  @override
  String get serverSessionExpired => 'Session expired — please log in again.';

  @override
  String get checksumsTitle => 'Photo matching';

  @override
  String get checksumsExplanation =>
      'Once, the app computes a checksum for every photo on this device. That is how it knows which photos are already in Immich — shown by the clouds in the timeline.\n\nThis happens only the first time, afterwards only for new photos. Nothing is uploaded; only the checksums go to the server.';

  @override
  String get checksumsInBackground => 'Run in background';

  @override
  String checksumsProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString photos';
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

    return '$doneString of $totalString photos · done in about $duration';
  }

  @override
  String get checksumsOneMinute => 'a minute';

  @override
  String checksumsMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String checksumsHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get accountTooltip => 'Account and settings';

  @override
  String get accountStorageTitle => 'Server storage';

  @override
  String accountStorageUsed(String used, String total) {
    return '$used of $total used';
  }

  @override
  String get accountAppVersion => 'App version';

  @override
  String get accountServerVersion => 'Server version';

  @override
  String get accountServerAddress => 'Server address';

  @override
  String get accountLogout => 'Log out';

  @override
  String get accountLogoutQuestion => 'Are you sure you want to log out?';

  @override
  String get accountLogoutConfirm => 'Yes';

  @override
  String get accountLicenses => 'Licenses';

  @override
  String settingsPendingEdits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count edits are waiting for the backup',
      one: '1 edit is waiting for the backup',
      zero: 'Nothing is waiting for the backup',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguageText => 'German, English or like the device';

  @override
  String get settingsViewTitle => 'View';

  @override
  String get settingsViewText => 'One timeline across device and server';

  @override
  String get settingsEditTitle => 'Editing';

  @override
  String get settingsEditText => 'HDR in preview and copy';

  @override
  String get settingsSaveTitle => 'Saving';

  @override
  String get settingsSaveText => 'Where edits of online photos go';

  @override
  String get settingsNetworkTitle => 'Networking';

  @override
  String get settingsNetworkText => 'Mobile data for originals and uploads';

  @override
  String get settingsStackingTitle => 'Stacking';

  @override
  String get settingsStackingText => 'Edits waiting for the backup';

  @override
  String get settingsTogetherTitle => 'Device and server together';

  @override
  String get settingsTogetherText =>
      'One timeline like in the Immich app; the cloud at the bottom right shows whether a photo is only on the device, only on the server or on both. Off: two tabs, “Device” and “Immich”.';

  @override
  String get settingsHdrText =>
      'Show Ultra HDR photos in HDR and save as Ultra HDR';

  @override
  String get settingsOnlineTitle => 'Back up online photos via the device';

  @override
  String get settingsOnlineText =>
      'The copy of a photo that is only on the server goes into the camera album; the Immich app backs it up, then it leaves the device. Off: straight to the server.';

  @override
  String get settingsMobileDataTitle => 'Mobile data';

  @override
  String get settingsMobileDataText =>
      'Download originals and upload copies without Wi-Fi too. Off: only after asking.';

  @override
  String settingsStackingExplanation(String email) {
    return 'The app stacks copies saved on the device as soon as the Immich app has backed up the original and the copy — for that, it has to be logged in as $email.';
  }

  @override
  String get settingsStackNow => 'Stack now';

  @override
  String loginUntestedVersion(int version) {
    return 'Immich $version.x is not tested — the app may behave unexpectedly.';
  }

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Log in';

  @override
  String get settingsFoldersTitle => 'Device folders';

  @override
  String get settingsFoldersText =>
      'What shows under “Photos”, what the library hides';

  @override
  String get foldersInPhotos => 'Show under “Photos”';

  @override
  String get foldersInPhotosHint =>
      '“Photos” shows everything on the server and, from the device, only these folders — like the camera in Google Photos.';

  @override
  String get settingsOpenWithTitle => 'Open edits with';

  @override
  String get settingsOpenWithAsk => 'Ask Android';

  @override
  String get settingsOpenWithText =>
      'For photos from folders Immich doesn’t back up. “Ask Android” offers “Just once” and “Always”; an app chosen here wins even over “Always” in Android.';

  @override
  String settingsPendingWhere(String folder) {
    return 'Copy in $folder — not in Immich yet';
  }

  @override
  String get settingsPendingNotFound => 'Copy not found on the device yet';

  @override
  String get settingsPendingUnknown => 'Edit';

  @override
  String get settingsPendingDiscard => 'Stop waiting — the copy stays';

  @override
  String get settingsHdrButtonTitle => 'Show HDR button';

  @override
  String get settingsHdrButtonText =>
      'In gallery, viewer and editor; it switches HDR everywhere. Off: only here.';

  @override
  String get foldersLibrary => 'Library';

  @override
  String get foldersLibraryHint =>
      'Pinned folders first, then your order, then the rest. The eye hides a folder; drag the handle to move it.';

  @override
  String get foldersRestNewest => 'Rest: newest first';

  @override
  String get foldersRestName => 'Rest: A–Z';

  @override
  String get foldersShow => 'Show in library';

  @override
  String get foldersHide => 'Hide in library';

  @override
  String get foldersPin => 'Pin to top';

  @override
  String get foldersUnpin => 'Unpin';

  @override
  String get foldersMove => 'Move';

  @override
  String get foldersByFolder => 'Folders';

  @override
  String get foldersByApp => 'Apps';

  @override
  String get foldersOtherApps => 'Other and unknown';

  @override
  String foldersAppCount(int count, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '1 folder',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: ' · $hidden hidden',
      zero: '',
    );
    return '$_temp0$_temp1';
  }
}
