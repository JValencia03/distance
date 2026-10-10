// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Distance';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get homeTitle => '¿Qué quieres hacer?';

  @override
  String get homeSubtitle =>
      'Elige una actividad y encuentra planes cerca de ti.';

  @override
  String get chooseZone => 'Elige tu zona';

  @override
  String get zonePickerTitle => '¿Dónde quieres buscar planes?';

  @override
  String get allPlans => 'Todos los planes';

  @override
  String get filterAll => 'Todas';

  @override
  String get createPlan => 'Crear plan';

  @override
  String get planCreated => 'Plan creado';

  @override
  String noPlansTitle(String zone) {
    return 'No hay planes cerca de $zone';
  }

  @override
  String noActivityPlansTitle(String activity, String zone) {
    return 'No hay planes de $activity cerca de $zone';
  }

  @override
  String get noPlansMessage => 'Crea uno y deja que otras personas se unan.';

  @override
  String get errorTitle => 'Algo salió mal';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando…';

  @override
  String get errorConnection => 'No se pudo conectar con el servidor.';

  @override
  String get errorTimeout => 'El servidor tardó demasiado en responder.';

  @override
  String get errorUnexpectedResponse => 'Respuesta inesperada del servidor.';

  @override
  String get planScreenTitle => 'Plan';

  @override
  String get detailActivity => 'Actividad';

  @override
  String get detailWhen => 'Cuándo';

  @override
  String get detailMeetingPoint => 'Punto de encuentro';

  @override
  String get detailParticipants => 'Participantes';

  @override
  String get join => 'Unirme';

  @override
  String get joinZoneTitle => '¿Desde qué zona te unes?';

  @override
  String get joinZoneNotice =>
      'Otras personas verán esta zona en el mapa del plan. Es aproximada: nunca compartimos tu ubicación exacta.';

  @override
  String joinFromZone(String zone) {
    return 'Unirme desde $zone';
  }

  @override
  String get joinSuccess => '¡Listo! Ya participas en este plan.';

  @override
  String get noticeJoined => 'Ya participas en este plan';

  @override
  String get noticeFull => 'No quedan plazas disponibles';

  @override
  String get noticeCancelled => 'Este plan fue cancelado';

  @override
  String get noticeEnded => 'Este plan ya terminó';

  @override
  String get chipAvailable => 'Disponible';

  @override
  String get chipJoined => 'Participas';

  @override
  String get chipFull => 'Completo';

  @override
  String get chipCancelled => 'Cancelado';

  @override
  String get chipOngoing => 'En curso';

  @override
  String get chipEnded => 'Terminó';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String participants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participantes',
      one: '1 participante',
    );
    return '$_temp0';
  }

  @override
  String participantsWithLimit(int count, int max) {
    return '$count/$max participantes';
  }

  @override
  String get distanceSameZone => 'En tu zona';

  @override
  String distanceAway(String km) {
    return 'A $km km';
  }

  @override
  String get fieldActivity => 'Actividad';

  @override
  String get fieldTitle => 'Título';

  @override
  String get fieldTitleHint => 'Ej.: Leer en silencio en un café';

  @override
  String get fieldDescription => 'Descripción (opcional)';

  @override
  String get fieldZone => 'Zona';

  @override
  String get fieldPlace => 'Lugar de encuentro';

  @override
  String get fieldPlaceHint => 'Ej.: Café de la esquina, entrada principal';

  @override
  String get fieldDate => 'Fecha';

  @override
  String get fieldTime => 'Hora';

  @override
  String get fieldDuration => 'Duración';

  @override
  String get fieldCreatorZone => 'Tu zona';

  @override
  String get fieldCreatorZoneHelper =>
      'Otras personas verán esta zona en el mapa del plan.';

  @override
  String get fieldLimit => 'Límite de participantes (opcional)';

  @override
  String get fieldLimitHelper => 'Incluyéndote. Déjalo vacío para no limitar.';

  @override
  String get publishPlan => 'Publicar plan';

  @override
  String get errorChooseActivity => 'Elige una actividad.';

  @override
  String get errorTitleRequired => 'El título es obligatorio.';

  @override
  String get errorChooseZone => 'Elige una zona.';

  @override
  String get errorPlaceRequired => 'El lugar de encuentro es obligatorio.';

  @override
  String errorLimitRange(int min, int max) {
    return 'Escribe un número entre $min y $max.';
  }

  @override
  String get errorStartsAtRequired => 'Elige la fecha y la hora.';

  @override
  String get errorStartsAtPast => 'La fecha y hora deben ser futuras.';

  @override
  String get settingsCharacter => 'Tu personaje';

  @override
  String get settingsCharacterSubtitle => 'Cómo te ven los demás en el mapa';

  @override
  String get avatarTitle => 'Tu personaje';

  @override
  String get avatarSubtitle => 'Así te verán los demás en el mapa de planes.';

  @override
  String get avatarDefaultHint =>
      'Este es tu personaje por defecto. Personalízalo a tu gusto.';

  @override
  String get avatarSkin => 'Aspecto';

  @override
  String get avatarBodyColor => 'Color';

  @override
  String get avatarSkinTone => 'Tono de piel';

  @override
  String get avatarAccessory => 'Accesorio';

  @override
  String get avatarSave => 'Guardar personaje';

  @override
  String get avatarSaved => 'Personaje guardado';

  @override
  String get preview3dUnavailable =>
      'La vista 3D no está disponible en este dispositivo.';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorMint => 'Menta';

  @override
  String get colorLavender => 'Lavanda';

  @override
  String get colorSky => 'Cielo';

  @override
  String get colorSunflower => 'Girasol';

  @override
  String get colorPeach => 'Durazno';

  @override
  String get colorForest => 'Bosque';

  @override
  String get colorCharcoal => 'Carbón';

  @override
  String skinToneName(int number) {
    return 'Tono $number';
  }

  @override
  String get openMap => 'Ver mapa';

  @override
  String get mapTitle => 'Mapa de planes';

  @override
  String get mapHint => 'Arrastra para moverte · pellizca para acercar o girar';

  @override
  String get mapEmptyTitle => 'Todavía no hay planes en el mapa';

  @override
  String get mapEmptyMessage =>
      'Cuando alguien cree o se una a un plan, aparecerá aquí.';

  @override
  String get mapLegendOngoing => 'En curso';

  @override
  String get mapLegendUpcoming => 'Próximos';

  @override
  String get mapYou => 'Tú';

  @override
  String get mapNow => 'Ahora';

  @override
  String mapZonePlans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planes',
      one: '1 plan',
    );
    return '$_temp0';
  }

  @override
  String mapZoneLabel(String zone, String plans, String people) {
    return '$zone: $plans, $people';
  }

  @override
  String mapPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String mapFromZones(String zones) {
    return 'Desde $zones';
  }

  @override
  String get mapOpenPlan => 'Ver plan';

  @override
  String get mapEditCharacter => 'Editar personaje';

  @override
  String mapGroupLabel(
    String activity,
    String title,
    String people,
    String zone,
  ) {
    return '$activity: $title, $people en $zone';
  }
}
