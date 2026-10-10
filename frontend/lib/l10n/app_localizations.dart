import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Distance'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// No description provided for @homeTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres hacer?'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige una actividad y encuentra planes cerca de ti.'**
  String get homeSubtitle;

  /// No description provided for @chooseZone.
  ///
  /// In es, this message translates to:
  /// **'Elige tu zona'**
  String get chooseZone;

  /// No description provided for @zonePickerTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde quieres buscar planes?'**
  String get zonePickerTitle;

  /// No description provided for @allPlans.
  ///
  /// In es, this message translates to:
  /// **'Todos los planes'**
  String get allPlans;

  /// No description provided for @filterAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get filterAll;

  /// No description provided for @createPlan.
  ///
  /// In es, this message translates to:
  /// **'Crear plan'**
  String get createPlan;

  /// No description provided for @planCreated.
  ///
  /// In es, this message translates to:
  /// **'Plan creado'**
  String get planCreated;

  /// No description provided for @noPlansTitle.
  ///
  /// In es, this message translates to:
  /// **'No hay planes cerca de {zone}'**
  String noPlansTitle(String zone);

  /// activity is the lowercase activity name.
  ///
  /// In es, this message translates to:
  /// **'No hay planes de {activity} cerca de {zone}'**
  String noActivityPlansTitle(String activity, String zone);

  /// No description provided for @noPlansMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea uno y deja que otras personas se unan.'**
  String get noPlansMessage;

  /// No description provided for @errorTitle.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal'**
  String get errorTitle;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @errorConnection.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor.'**
  String get errorConnection;

  /// No description provided for @errorTimeout.
  ///
  /// In es, this message translates to:
  /// **'El servidor tardó demasiado en responder.'**
  String get errorTimeout;

  /// No description provided for @errorUnexpectedResponse.
  ///
  /// In es, this message translates to:
  /// **'Respuesta inesperada del servidor.'**
  String get errorUnexpectedResponse;

  /// No description provided for @planScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Plan'**
  String get planScreenTitle;

  /// No description provided for @detailActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get detailActivity;

  /// No description provided for @detailWhen.
  ///
  /// In es, this message translates to:
  /// **'Cuándo'**
  String get detailWhen;

  /// No description provided for @detailMeetingPoint.
  ///
  /// In es, this message translates to:
  /// **'Punto de encuentro'**
  String get detailMeetingPoint;

  /// No description provided for @detailParticipants.
  ///
  /// In es, this message translates to:
  /// **'Participantes'**
  String get detailParticipants;

  /// No description provided for @join.
  ///
  /// In es, this message translates to:
  /// **'Unirme'**
  String get join;

  /// No description provided for @joinZoneTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Desde qué zona te unes?'**
  String get joinZoneTitle;

  /// No description provided for @joinZoneNotice.
  ///
  /// In es, this message translates to:
  /// **'Otras personas verán esta zona en el mapa del plan. Es aproximada: nunca compartimos tu ubicación exacta.'**
  String get joinZoneNotice;

  /// No description provided for @joinFromZone.
  ///
  /// In es, this message translates to:
  /// **'Unirme desde {zone}'**
  String joinFromZone(String zone);

  /// No description provided for @joinSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Listo! Ya participas en este plan.'**
  String get joinSuccess;

  /// No description provided for @noticeJoined.
  ///
  /// In es, this message translates to:
  /// **'Ya participas en este plan'**
  String get noticeJoined;

  /// No description provided for @noticeFull.
  ///
  /// In es, this message translates to:
  /// **'No quedan plazas disponibles'**
  String get noticeFull;

  /// No description provided for @noticeCancelled.
  ///
  /// In es, this message translates to:
  /// **'Este plan fue cancelado'**
  String get noticeCancelled;

  /// No description provided for @noticeEnded.
  ///
  /// In es, this message translates to:
  /// **'Este plan ya terminó'**
  String get noticeEnded;

  /// No description provided for @chipAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get chipAvailable;

  /// No description provided for @chipJoined.
  ///
  /// In es, this message translates to:
  /// **'Participas'**
  String get chipJoined;

  /// No description provided for @chipFull.
  ///
  /// In es, this message translates to:
  /// **'Completo'**
  String get chipFull;

  /// No description provided for @chipCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get chipCancelled;

  /// No description provided for @chipOngoing.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get chipOngoing;

  /// No description provided for @chipEnded.
  ///
  /// In es, this message translates to:
  /// **'Terminó'**
  String get chipEnded;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In es, this message translates to:
  /// **'Mañana'**
  String get tomorrow;

  /// No description provided for @durationMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In es, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In es, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @participants.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 participante} other{{count} participantes}}'**
  String participants(int count);

  /// No description provided for @participantsWithLimit.
  ///
  /// In es, this message translates to:
  /// **'{count}/{max} participantes'**
  String participantsWithLimit(int count, int max);

  /// No description provided for @distanceSameZone.
  ///
  /// In es, this message translates to:
  /// **'En tu zona'**
  String get distanceSameZone;

  /// Non-breaking spaces keep the distance on one line.
  ///
  /// In es, this message translates to:
  /// **'A {km} km'**
  String distanceAway(String km);

  /// No description provided for @fieldActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get fieldActivity;

  /// No description provided for @fieldTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get fieldTitle;

  /// No description provided for @fieldTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Ej.: Leer en silencio en un café'**
  String get fieldTitleHint;

  /// No description provided for @fieldDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get fieldDescription;

  /// No description provided for @fieldZone.
  ///
  /// In es, this message translates to:
  /// **'Zona'**
  String get fieldZone;

  /// No description provided for @fieldPlace.
  ///
  /// In es, this message translates to:
  /// **'Lugar de encuentro'**
  String get fieldPlace;

  /// No description provided for @fieldPlaceHint.
  ///
  /// In es, this message translates to:
  /// **'Ej.: Café de la esquina, entrada principal'**
  String get fieldPlaceHint;

  /// No description provided for @fieldDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get fieldDate;

  /// No description provided for @fieldTime.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get fieldTime;

  /// No description provided for @fieldDuration.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get fieldDuration;

  /// No description provided for @fieldCreatorZone.
  ///
  /// In es, this message translates to:
  /// **'Tu zona'**
  String get fieldCreatorZone;

  /// No description provided for @fieldCreatorZoneHelper.
  ///
  /// In es, this message translates to:
  /// **'Otras personas verán esta zona en el mapa del plan.'**
  String get fieldCreatorZoneHelper;

  /// No description provided for @fieldLimit.
  ///
  /// In es, this message translates to:
  /// **'Límite de participantes (opcional)'**
  String get fieldLimit;

  /// No description provided for @fieldLimitHelper.
  ///
  /// In es, this message translates to:
  /// **'Incluyéndote. Déjalo vacío para no limitar.'**
  String get fieldLimitHelper;

  /// No description provided for @publishPlan.
  ///
  /// In es, this message translates to:
  /// **'Publicar plan'**
  String get publishPlan;

  /// No description provided for @errorChooseActivity.
  ///
  /// In es, this message translates to:
  /// **'Elige una actividad.'**
  String get errorChooseActivity;

  /// No description provided for @errorTitleRequired.
  ///
  /// In es, this message translates to:
  /// **'El título es obligatorio.'**
  String get errorTitleRequired;

  /// No description provided for @errorChooseZone.
  ///
  /// In es, this message translates to:
  /// **'Elige una zona.'**
  String get errorChooseZone;

  /// No description provided for @errorPlaceRequired.
  ///
  /// In es, this message translates to:
  /// **'El lugar de encuentro es obligatorio.'**
  String get errorPlaceRequired;

  /// No description provided for @errorLimitRange.
  ///
  /// In es, this message translates to:
  /// **'Escribe un número entre {min} y {max}.'**
  String errorLimitRange(int min, int max);

  /// No description provided for @errorStartsAtRequired.
  ///
  /// In es, this message translates to:
  /// **'Elige la fecha y la hora.'**
  String get errorStartsAtRequired;

  /// No description provided for @errorStartsAtPast.
  ///
  /// In es, this message translates to:
  /// **'La fecha y hora deben ser futuras.'**
  String get errorStartsAtPast;

  /// No description provided for @settingsCharacter.
  ///
  /// In es, this message translates to:
  /// **'Tu personaje'**
  String get settingsCharacter;

  /// No description provided for @settingsCharacterSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo te ven los demás en el mapa'**
  String get settingsCharacterSubtitle;

  /// No description provided for @avatarTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu personaje'**
  String get avatarTitle;

  /// No description provided for @avatarSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Así te verán los demás en el mapa de planes.'**
  String get avatarSubtitle;

  /// No description provided for @avatarDefaultHint.
  ///
  /// In es, this message translates to:
  /// **'Este es tu personaje por defecto. Personalízalo a tu gusto.'**
  String get avatarDefaultHint;

  /// No description provided for @avatarSkin.
  ///
  /// In es, this message translates to:
  /// **'Aspecto'**
  String get avatarSkin;

  /// No description provided for @avatarBodyColor.
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get avatarBodyColor;

  /// No description provided for @avatarSkinTone.
  ///
  /// In es, this message translates to:
  /// **'Tono de piel'**
  String get avatarSkinTone;

  /// No description provided for @avatarAccessory.
  ///
  /// In es, this message translates to:
  /// **'Accesorio'**
  String get avatarAccessory;

  /// No description provided for @avatarSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar personaje'**
  String get avatarSave;

  /// No description provided for @avatarSaved.
  ///
  /// In es, this message translates to:
  /// **'Personaje guardado'**
  String get avatarSaved;

  /// No description provided for @preview3dUnavailable.
  ///
  /// In es, this message translates to:
  /// **'La vista 3D no está disponible en este dispositivo.'**
  String get preview3dUnavailable;

  /// No description provided for @colorCoral.
  ///
  /// In es, this message translates to:
  /// **'Coral'**
  String get colorCoral;

  /// No description provided for @colorMint.
  ///
  /// In es, this message translates to:
  /// **'Menta'**
  String get colorMint;

  /// No description provided for @colorLavender.
  ///
  /// In es, this message translates to:
  /// **'Lavanda'**
  String get colorLavender;

  /// No description provided for @colorSky.
  ///
  /// In es, this message translates to:
  /// **'Cielo'**
  String get colorSky;

  /// No description provided for @colorSunflower.
  ///
  /// In es, this message translates to:
  /// **'Girasol'**
  String get colorSunflower;

  /// No description provided for @colorPeach.
  ///
  /// In es, this message translates to:
  /// **'Durazno'**
  String get colorPeach;

  /// No description provided for @colorForest.
  ///
  /// In es, this message translates to:
  /// **'Bosque'**
  String get colorForest;

  /// No description provided for @colorCharcoal.
  ///
  /// In es, this message translates to:
  /// **'Carbón'**
  String get colorCharcoal;

  /// No description provided for @skinToneName.
  ///
  /// In es, this message translates to:
  /// **'Tono {number}'**
  String skinToneName(int number);

  /// No description provided for @openMap.
  ///
  /// In es, this message translates to:
  /// **'Ver mapa'**
  String get openMap;

  /// No description provided for @mapTitle.
  ///
  /// In es, this message translates to:
  /// **'Mapa de planes'**
  String get mapTitle;

  /// No description provided for @mapHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra para moverte · pellizca para acercar o girar'**
  String get mapHint;

  /// No description provided for @mapEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay planes en el mapa'**
  String get mapEmptyTitle;

  /// No description provided for @mapEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Cuando alguien cree o se una a un plan, aparecerá aquí.'**
  String get mapEmptyMessage;

  /// No description provided for @mapLegendOngoing.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get mapLegendOngoing;

  /// No description provided for @mapLegendUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próximos'**
  String get mapLegendUpcoming;

  /// No description provided for @mapYou.
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get mapYou;

  /// No description provided for @mapNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get mapNow;

  /// No description provided for @mapPeople.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 persona} other{{count} personas}}'**
  String mapPeople(int count);

  /// zones is a comma-separated list of zone names.
  ///
  /// In es, this message translates to:
  /// **'Desde {zones}'**
  String mapFromZones(String zones);

  /// No description provided for @mapOpenPlan.
  ///
  /// In es, this message translates to:
  /// **'Ver plan'**
  String get mapOpenPlan;

  /// No description provided for @mapEditCharacter.
  ///
  /// In es, this message translates to:
  /// **'Editar personaje'**
  String get mapEditCharacter;

  /// Screen reader label of a group of avatars on the map.
  ///
  /// In es, this message translates to:
  /// **'{activity}: {title}, {people} en {zone}'**
  String mapGroupLabel(
    String activity,
    String title,
    String people,
    String zone,
  );
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
