import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @anyway.
  ///
  /// In en, this message translates to:
  /// **'Anyway'**
  String get anyway;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @useMobileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Use mobile data?'**
  String get useMobileDataTitle;

  /// No description provided for @stepRendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering …'**
  String get stepRendering;

  /// No description provided for @stepUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading …'**
  String get stepUploading;

  /// No description provided for @stepChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking …'**
  String get stepChecking;

  /// No description provided for @stepStacking.
  ///
  /// In en, this message translates to:
  /// **'Stacking …'**
  String get stepStacking;

  /// No description provided for @photoGoneFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Photo is no longer on the device'**
  String get photoGoneFromDevice;

  /// No description provided for @toolBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get toolBrightness;

  /// No description provided for @toolContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get toolContrast;

  /// No description provided for @toolWhitePoint.
  ///
  /// In en, this message translates to:
  /// **'White point'**
  String get toolWhitePoint;

  /// No description provided for @toolHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get toolHighlights;

  /// No description provided for @toolShadows.
  ///
  /// In en, this message translates to:
  /// **'Shadows'**
  String get toolShadows;

  /// No description provided for @toolBlackPoint.
  ///
  /// In en, this message translates to:
  /// **'Black point'**
  String get toolBlackPoint;

  /// No description provided for @toolSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get toolSaturation;

  /// No description provided for @toolWarmth.
  ///
  /// In en, this message translates to:
  /// **'Warmth'**
  String get toolWarmth;

  /// No description provided for @toolTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get toolTint;

  /// No description provided for @toolBlueTones.
  ///
  /// In en, this message translates to:
  /// **'Blue tone'**
  String get toolBlueTones;

  /// No description provided for @toolVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get toolVignette;

  /// No description provided for @toolSharpness.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get toolSharpness;

  /// No description provided for @editorDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get editorDiscardTitle;

  /// No description provided for @editorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get editorDiscard;

  /// No description provided for @editorLoadingOriginal.
  ///
  /// In en, this message translates to:
  /// **'Loading original …'**
  String get editorLoadingOriginal;

  /// No description provided for @editorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get editorUndo;

  /// No description provided for @editorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get editorRedo;

  /// No description provided for @editorHdrOn.
  ///
  /// In en, this message translates to:
  /// **'HDR on'**
  String get editorHdrOn;

  /// No description provided for @editorHdrOff.
  ///
  /// In en, this message translates to:
  /// **'HDR off'**
  String get editorHdrOff;

  /// No description provided for @editorMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get editorMore;

  /// No description provided for @editorResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get editorResetAll;

  /// No description provided for @editorBackToSaved.
  ///
  /// In en, this message translates to:
  /// **'Back to saved edit'**
  String get editorBackToSaved;

  /// No description provided for @editorAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get editorAspectRatio;

  /// No description provided for @editorRatioFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get editorRatioFree;

  /// No description provided for @editorRatioSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get editorRatioSquare;

  /// No description provided for @editorFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get editorFlip;

  /// No description provided for @editorRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get editorRotate;

  /// No description provided for @editorTabPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get editorTabPresets;

  /// No description provided for @editorTabCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get editorTabCrop;

  /// No description provided for @editorTabAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get editorTabAdjust;

  /// No description provided for @editorTabFilter.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get editorTabFilter;

  /// No description provided for @filterNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get filterNone;

  /// No description provided for @filterVivid.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get filterVivid;

  /// No description provided for @filterWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get filterWarm;

  /// No description provided for @filterCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get filterCool;

  /// No description provided for @filterFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get filterFilm;

  /// No description provided for @filterFade.
  ///
  /// In en, this message translates to:
  /// **'Faded'**
  String get filterFade;

  /// No description provided for @filterBw.
  ///
  /// In en, this message translates to:
  /// **'Black & white'**
  String get filterBw;

  /// No description provided for @filterNoir.
  ///
  /// In en, this message translates to:
  /// **'Noir'**
  String get filterNoir;

  /// No description provided for @filterSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get filterSepia;

  /// No description provided for @presetSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get presetSaveTitle;

  /// No description provided for @presetName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get presetName;

  /// No description provided for @presetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get presetSave;

  /// No description provided for @presetDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete preset “{name}”?'**
  String presetDeleteTitle(String name);

  /// No description provided for @presetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get presetDelete;

  /// No description provided for @saveReplaceCopy.
  ///
  /// In en, this message translates to:
  /// **'Replace copy'**
  String get saveReplaceCopy;

  /// No description provided for @saveReplaceCopyHint.
  ///
  /// In en, this message translates to:
  /// **'The previous edit moves to the trash'**
  String get saveReplaceCopyHint;

  /// No description provided for @saveAsAnotherCopy.
  ///
  /// In en, this message translates to:
  /// **'Save as another copy'**
  String get saveAsAnotherCopy;

  /// No description provided for @saveAsAnotherCopyHint.
  ///
  /// In en, this message translates to:
  /// **'Both edits stay in the stack'**
  String get saveAsAnotherCopyHint;

  /// No description provided for @saveMobileDataBody.
  ///
  /// In en, this message translates to:
  /// **'Saving needs to download the original or upload the copy — which your settings allow only on Wi-Fi.'**
  String get saveMobileDataBody;

  /// No description provided for @saveDoneChecked.
  ///
  /// In en, this message translates to:
  /// **'Saved and verified'**
  String get saveDoneChecked;

  /// No description provided for @saveDoneOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on the device — stacked after the backup'**
  String get saveDoneOnDevice;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @saveCopyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Copy on the server differs ({id})'**
  String saveCopyMismatch(String id);

  /// No description provided for @saveOpenInImmichTitle.
  ///
  /// In en, this message translates to:
  /// **'Open edit in Immich?'**
  String get saveOpenInImmichTitle;

  /// No description provided for @saveOpenInImmichBody.
  ///
  /// In en, this message translates to:
  /// **'The folder “{folder}” is not backed up to Immich. Upload the edit archived — not in the timeline —, add it to the album “{album}” and open it in the Immich app? There you can move it to another album.'**
  String saveOpenInImmichBody(String folder, String album);

  /// No description provided for @saveDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Device only'**
  String get saveDeviceOnly;

  /// No description provided for @saveOpenInImmich.
  ///
  /// In en, this message translates to:
  /// **'Open in Immich'**
  String get saveOpenInImmich;

  /// No description provided for @saveArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived in Immich, album “{album}”'**
  String saveArchived(String album);

  /// No description provided for @saveArchivedNoApp.
  ///
  /// In en, this message translates to:
  /// **'Archived in Immich, album “{album}” — the Immich app is missing'**
  String saveArchivedNoApp(String album);

  /// No description provided for @galleryNoPresets.
  ///
  /// In en, this message translates to:
  /// **'No presets yet — save one in the editor under \"Presets\"'**
  String get galleryNoPresets;

  /// No description provided for @galleryApplyPresetTo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Apply preset to 1 photo} other{Apply preset to {count} photos}}'**
  String galleryApplyPresetTo(int count);

  /// No description provided for @galleryMobileDataOriginals.
  ///
  /// In en, this message translates to:
  /// **'The originals of the online photos will be downloaded — your settings allow that only on Wi-Fi.'**
  String get galleryMobileDataOriginals;

  /// No description provided for @galleryApplyingPreset.
  ///
  /// In en, this message translates to:
  /// **'Applying \"{name}\"'**
  String galleryApplyingPreset(String name);

  /// No description provided for @galleryProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} photos'**
  String galleryProgress(int done, int total);

  /// No description provided for @galleryCopiesSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 copy saved} other{{count} copies saved}}'**
  String galleryCopiesSaved(int count);

  /// No description provided for @galleryCopiesSavedFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 copy} other{{count} copies}} saved, {failed} failed: {error}'**
  String galleryCopiesSavedFailed(int count, int failed, String error);

  /// No description provided for @galleryTabDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get galleryTabDevice;

  /// No description provided for @galleryTabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get galleryTabLibrary;

  /// No description provided for @galleryTabPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get galleryTabPhotos;

  /// No description provided for @galleryEndSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get galleryEndSelection;

  /// No description provided for @gallerySelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String gallerySelected(int count);

  /// No description provided for @galleryApplyPreset.
  ///
  /// In en, this message translates to:
  /// **'Apply preset'**
  String get galleryApplyPreset;

  /// No description provided for @galleryNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get galleryNoPhotos;

  /// No description provided for @galleryNoDevicePermission.
  ///
  /// In en, this message translates to:
  /// **'The app is not allowed to see the photos on this device.'**
  String get galleryNoDevicePermission;

  /// No description provided for @galleryNoDevicePhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos on this device.'**
  String get galleryNoDevicePhotos;

  /// No description provided for @galleryNoServerPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos on the server yet.'**
  String get galleryNoServerPhotos;

  /// No description provided for @galleryRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get galleryRetry;

  /// No description provided for @libraryOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get libraryOnDevice;

  /// No description provided for @libraryNotInImmich.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo · not in Immich} other{{count} photos · not in Immich}}'**
  String libraryNotInImmich(int count);

  /// No description provided for @libraryBackedUp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo · backed up} other{{count} photos · backed up}}'**
  String libraryBackedUp(int count);

  /// No description provided for @libraryPartlyBackedUp.
  ///
  /// In en, this message translates to:
  /// **'{count} photos · {backedUp} backed up'**
  String libraryPartlyBackedUp(int count, int backedUp);

  /// No description provided for @tilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get tilePhoto;

  /// No description provided for @tilePhotoStack.
  ///
  /// In en, this message translates to:
  /// **'Photo, stack of {count}'**
  String tilePhotoStack(int count);

  /// No description provided for @tileDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'only on this device'**
  String get tileDeviceOnly;

  /// No description provided for @tileServerOnly.
  ///
  /// In en, this message translates to:
  /// **'only on the server'**
  String get tileServerOnly;

  /// No description provided for @tileBackedUp.
  ///
  /// In en, this message translates to:
  /// **'backed up'**
  String get tileBackedUp;

  /// No description provided for @viewerKeepTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep {name}?'**
  String viewerKeepTitle(String name);

  /// No description provided for @viewerKeepText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The other photo of the stack goes to the Immich trash — you can restore it there.} other{The other {count} photos of the stack go to the Immich trash — you can restore them there.}}'**
  String viewerKeepText(int count);

  /// No description provided for @viewerDeleteRest.
  ///
  /// In en, this message translates to:
  /// **'Delete the rest'**
  String get viewerDeleteRest;

  /// No description provided for @viewerInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get viewerInfo;

  /// No description provided for @viewerUltraHdr.
  ///
  /// In en, this message translates to:
  /// **'Ultra HDR'**
  String get viewerUltraHdr;

  /// No description provided for @viewerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get viewerEdit;

  /// No description provided for @viewerStack.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get viewerStack;

  /// No description provided for @viewerSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as primary photo'**
  String get viewerSetPrimary;

  /// No description provided for @viewerKeepThis.
  ///
  /// In en, this message translates to:
  /// **'Keep this photo, delete the rest'**
  String get viewerKeepThis;

  /// No description provided for @serverTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server is not responding (timeout).'**
  String get serverTimeout;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable: {message}'**
  String serverUnreachable(String message);

  /// No description provided for @serverConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost: {message}'**
  String serverConnectionLost(String message);

  /// No description provided for @serverSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired — please log in again.'**
  String get serverSessionExpired;

  /// No description provided for @checksumsTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo matching'**
  String get checksumsTitle;

  /// No description provided for @checksumsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Once, the app computes a checksum for every photo on this device. That is how it knows which photos are already in Immich — shown by the clouds in the timeline.\n\nThis happens only the first time, afterwards only for new photos. Nothing is uploaded; only the checksums go to the server.'**
  String get checksumsExplanation;

  /// No description provided for @checksumsInBackground.
  ///
  /// In en, this message translates to:
  /// **'Run in background'**
  String get checksumsInBackground;

  /// No description provided for @checksumsProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} photos'**
  String checksumsProgress(int done, int total);

  /// No description provided for @checksumsProgressRemaining.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} photos · done in about {duration}'**
  String checksumsProgressRemaining(int done, int total, String duration);

  /// No description provided for @checksumsOneMinute.
  ///
  /// In en, this message translates to:
  /// **'a minute'**
  String get checksumsOneMinute;

  /// No description provided for @checksumsMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String checksumsMinutes(int minutes);

  /// No description provided for @checksumsHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String checksumsHoursMinutes(int hours, int minutes);

  /// No description provided for @accountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Account and settings'**
  String get accountTooltip;

  /// No description provided for @accountStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Server storage'**
  String get accountStorageTitle;

  /// No description provided for @accountStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String accountStorageUsed(String used, String total);

  /// No description provided for @accountAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get accountAppVersion;

  /// No description provided for @accountServerVersion.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get accountServerVersion;

  /// No description provided for @accountServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get accountServerAddress;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogout;

  /// No description provided for @accountLogoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get accountLogoutQuestion;

  /// No description provided for @accountLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get accountLogoutConfirm;

  /// No description provided for @accountLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get accountLicenses;

  /// No description provided for @settingsPendingEdits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing is waiting for the backup} =1{1 edit is waiting for the backup} other{{count} edits are waiting for the backup}}'**
  String settingsPendingEdits(int count);

  /// No description provided for @settingsLanguageText.
  ///
  /// In en, this message translates to:
  /// **'German, English or like the device'**
  String get settingsLanguageText;

  /// No description provided for @settingsViewTitle.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get settingsViewTitle;

  /// No description provided for @settingsViewText.
  ///
  /// In en, this message translates to:
  /// **'One timeline across device and server'**
  String get settingsViewText;

  /// No description provided for @settingsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get settingsEditTitle;

  /// No description provided for @settingsEditText.
  ///
  /// In en, this message translates to:
  /// **'HDR in preview and copy'**
  String get settingsEditText;

  /// No description provided for @settingsSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get settingsSaveTitle;

  /// No description provided for @settingsSaveText.
  ///
  /// In en, this message translates to:
  /// **'Where edits of online photos go'**
  String get settingsSaveText;

  /// No description provided for @settingsNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Networking'**
  String get settingsNetworkTitle;

  /// No description provided for @settingsNetworkText.
  ///
  /// In en, this message translates to:
  /// **'Mobile data for originals and uploads'**
  String get settingsNetworkText;

  /// No description provided for @settingsStackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stacking'**
  String get settingsStackingTitle;

  /// No description provided for @settingsStackingText.
  ///
  /// In en, this message translates to:
  /// **'Edits waiting for the backup'**
  String get settingsStackingText;

  /// No description provided for @settingsTogetherTitle.
  ///
  /// In en, this message translates to:
  /// **'Device and server together'**
  String get settingsTogetherTitle;

  /// No description provided for @settingsTogetherText.
  ///
  /// In en, this message translates to:
  /// **'One timeline like in the Immich app; the cloud at the bottom right shows whether a photo is only on the device, only on the server or on both. Off: two tabs, “Device” and “Immich”.'**
  String get settingsTogetherText;

  /// No description provided for @settingsHdrText.
  ///
  /// In en, this message translates to:
  /// **'Show Ultra HDR photos in HDR and save as Ultra HDR'**
  String get settingsHdrText;

  /// No description provided for @settingsOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up online photos via the device'**
  String get settingsOnlineTitle;

  /// No description provided for @settingsOnlineText.
  ///
  /// In en, this message translates to:
  /// **'The copy of a photo that is only on the server goes into the camera album; the Immich app backs it up, then it leaves the device. Off: straight to the server.'**
  String get settingsOnlineText;

  /// No description provided for @settingsMobileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile data'**
  String get settingsMobileDataTitle;

  /// No description provided for @settingsMobileDataText.
  ///
  /// In en, this message translates to:
  /// **'Download originals and upload copies without Wi-Fi too. Off: only after asking.'**
  String get settingsMobileDataText;

  /// No description provided for @settingsStackingExplanation.
  ///
  /// In en, this message translates to:
  /// **'The app stacks copies saved on the device as soon as the Immich app has backed up the original and the copy — for that, it has to be logged in as {email}.'**
  String settingsStackingExplanation(String email);

  /// No description provided for @settingsStackNow.
  ///
  /// In en, this message translates to:
  /// **'Stack now'**
  String get settingsStackNow;

  /// No description provided for @loginUntestedVersion.
  ///
  /// In en, this message translates to:
  /// **'Immich {version}.x is not tested — the app may behave unexpectedly.'**
  String loginUntestedVersion(int version);

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @settingsFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Device folders'**
  String get settingsFoldersTitle;

  /// No description provided for @settingsFoldersText.
  ///
  /// In en, this message translates to:
  /// **'What shows under “Photos”, what the library hides'**
  String get settingsFoldersText;

  /// No description provided for @foldersInPhotos.
  ///
  /// In en, this message translates to:
  /// **'Show under “Photos”'**
  String get foldersInPhotos;

  /// No description provided for @foldersInPhotosHint.
  ///
  /// In en, this message translates to:
  /// **'“Photos” shows everything on the server and, from the device, only these folders — like the camera in Google Photos.'**
  String get foldersInPhotosHint;

  /// No description provided for @settingsOpenWithTitle.
  ///
  /// In en, this message translates to:
  /// **'Open edits with'**
  String get settingsOpenWithTitle;

  /// No description provided for @settingsOpenWithAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask Android'**
  String get settingsOpenWithAsk;

  /// No description provided for @settingsOpenWithText.
  ///
  /// In en, this message translates to:
  /// **'For photos from folders Immich doesn’t back up. “Ask Android” offers “Just once” and “Always”; an app chosen here wins even over “Always” in Android.'**
  String get settingsOpenWithText;

  /// No description provided for @settingsPendingWhere.
  ///
  /// In en, this message translates to:
  /// **'Copy in {folder} — not in Immich yet'**
  String settingsPendingWhere(String folder);

  /// No description provided for @settingsPendingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Copy not found on the device yet'**
  String get settingsPendingNotFound;

  /// No description provided for @settingsPendingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get settingsPendingUnknown;

  /// No description provided for @settingsPendingDiscard.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting — the copy stays'**
  String get settingsPendingDiscard;

  /// No description provided for @settingsHdrButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Show HDR button'**
  String get settingsHdrButtonTitle;

  /// No description provided for @settingsHdrButtonText.
  ///
  /// In en, this message translates to:
  /// **'In gallery, viewer and editor; it switches HDR everywhere. Off: only here.'**
  String get settingsHdrButtonText;

  /// No description provided for @foldersLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get foldersLibrary;

  /// No description provided for @foldersLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Pinned folders first, then your order, then the rest. The eye hides a folder; drag the handle to move it.'**
  String get foldersLibraryHint;

  /// No description provided for @foldersRestNewest.
  ///
  /// In en, this message translates to:
  /// **'Rest: newest first'**
  String get foldersRestNewest;

  /// No description provided for @foldersRestName.
  ///
  /// In en, this message translates to:
  /// **'Rest: A–Z'**
  String get foldersRestName;

  /// No description provided for @foldersShow.
  ///
  /// In en, this message translates to:
  /// **'Show in library'**
  String get foldersShow;

  /// No description provided for @foldersHide.
  ///
  /// In en, this message translates to:
  /// **'Hide in library'**
  String get foldersHide;

  /// No description provided for @foldersPin.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get foldersPin;

  /// No description provided for @foldersUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get foldersUnpin;

  /// No description provided for @foldersMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get foldersMove;

  /// No description provided for @foldersByFolder.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersByFolder;

  /// No description provided for @foldersByApp.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get foldersByApp;

  /// No description provided for @foldersOtherApps.
  ///
  /// In en, this message translates to:
  /// **'Other and unknown'**
  String get foldersOtherApps;

  /// No description provided for @foldersAppCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 folder} other{{count} folders}}{hidden, plural, =0{} other{ · {hidden} hidden}}'**
  String foldersAppCount(int count, int hidden);
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
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
