// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageDescription =>
      'Elige el idioma para la experiencia del personal.';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortuguese => 'Portugués (Brasil)';

  @override
  String get languageSaved => 'Idioma actualizado.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonArchive => 'Archivar';

  @override
  String get commonUnarchive => 'Desarchivar';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonErrorTitle => 'Error';

  @override
  String get commonEmail => 'Correo electrónico';

  @override
  String get commonPassword => 'Contraseña';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRole => 'Rol';

  @override
  String get commonName => 'Nombre';

  @override
  String get commonBackToSignIn => 'Volver a iniciar sesión';

  @override
  String get commonGoToSignIn => 'Ir a iniciar sesión';

  @override
  String get commonOpenHands => 'Abrir Hands';

  @override
  String get commonNotSpecified => 'No especificado';

  @override
  String get commonContinueIn => 'Continuar en';

  @override
  String get commonWebApp => 'Aplicación web';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginIntroTitle => 'Operaciones, sin el caos.';

  @override
  String get loginIntroBody =>
      'Inicia sesión para gestionar turnos, tareas, documentos y la ejecución del equipo desde un solo lugar.';

  @override
  String get loginFeatureLiveTaskTracking => 'Seguimiento de tareas en vivo';

  @override
  String get loginFeatureSharedTeamWorkflows => 'Flujos de trabajo compartidos';

  @override
  String get loginFeatureOperationalVisibility => 'Visibilidad operativa';

  @override
  String get loginWelcomeBack => 'Bienvenido de nuevo';

  @override
  String get loginWelcomeBackBody =>
      'Usa tu correo y contraseña para continuar.';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginEmailHint => 'tu@restaurante.com';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginPasswordHint => 'Ingresa tu contraseña';

  @override
  String get loginHidePassword => 'Ocultar contraseña';

  @override
  String get loginShowPassword => 'Mostrar contraseña';

  @override
  String get loginSignIn => 'Iniciar sesión';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginNeedAccessTitle => '¿Necesitas acceso?';

  @override
  String get loginNeedAccessBody =>
      'Si necesitas acceso a una organización existente, pídele a tu gerente que te envíe una invitación.';

  @override
  String get loginNeedAccountTitle => '¿Necesitas una cuenta?';

  @override
  String get loginNeedAccountBody =>
      'Crea una organización de prueba o acepta una invitación de tu gerente.';

  @override
  String get loginSignUp => 'Registrarte';

  @override
  String loginVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get loginEnterEmail => 'Por favor ingresa tu correo electrónico';

  @override
  String get loginEnterValidEmail =>
      'Por favor ingresa un correo electrónico válido';

  @override
  String get loginEnterPassword => 'Por favor ingresa tu contraseña';

  @override
  String get loginProfileNotFound =>
      'No se encontró el perfil del usuario. Comunícate con soporte.';

  @override
  String get loginResetPasswordTitle => 'Restablecer contraseña';

  @override
  String get loginResetPasswordSubtitle =>
      'Ingresa el correo asociado a tu cuenta de Hands y te enviaremos un enlace seguro para restablecerla.';

  @override
  String get loginResetPasswordBody =>
      'Enviaremos el correo de restablecimiento de inmediato.';

  @override
  String get loginResetEmailAddressLabel => 'Correo electrónico';

  @override
  String get loginResetEmailHint => 'Correo electrónico';

  @override
  String get loginResetSendButton => 'Enviar enlace';

  @override
  String loginResetEmailSent(String email) {
    return 'Se envió un correo de restablecimiento a $email';
  }

  @override
  String get loginEnterEmailAddress =>
      'Por favor ingresa tu correo electrónico.';

  @override
  String get loginEnterValidEmailAddress =>
      'Por favor ingresa un correo electrónico válido.';

  @override
  String get loginResetFailed =>
      'No se pudo enviar el correo de restablecimiento.';

  @override
  String get loginNoAccountFound =>
      'No se encontró una cuenta con este correo electrónico.';

  @override
  String get loginTooManyRequests =>
      'Demasiadas solicitudes. Inténtalo más tarde.';

  @override
  String get welcomeInviteUnavailable => 'Invitación no disponible';

  @override
  String welcomeToOrganization(String organizationName) {
    return '¡Bienvenido a $organizationName!';
  }

  @override
  String welcomeInviteBody(String organizationName) {
    return 'Has sido invitado a unirte a $organizationName. Completa la configuración de tu cuenta para comenzar.';
  }

  @override
  String get welcomeAccountDetails => 'Detalles de la cuenta';

  @override
  String get welcomeCompleteSetupTitle =>
      'Completa la configuración de tu cuenta';

  @override
  String get welcomeCompleteSetupBody =>
      'Crea una contraseña para terminar de configurar tu cuenta. El acceso y el rol de tu organización se aplicarán automáticamente desde esta invitación.';

  @override
  String get welcomeNewPasswordLabel => 'Nueva contraseña';

  @override
  String get welcomeNewPasswordHint => 'Crea una nueva contraseña';

  @override
  String get welcomeConfirmPasswordLabel => 'Confirmar nueva contraseña';

  @override
  String get welcomeConfirmPasswordHint => 'Confirma tu nueva contraseña';

  @override
  String get welcomeEnterNewPassword =>
      'Por favor ingresa una nueva contraseña';

  @override
  String get welcomePasswordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get welcomeConfirmNewPassword =>
      'Por favor confirma tu nueva contraseña';

  @override
  String get welcomePasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get welcomeCompleteSetupButton => 'Completar configuración';

  @override
  String get welcomeAccountSetupCompleteTitle =>
      'Configuración de cuenta completa';

  @override
  String get welcomeAccountReady => 'Tu cuenta está lista para usarse.';

  @override
  String get welcomeOpenOnWeb =>
      'Puedes abrir Hands en la web ahora mismo. La descarga de la app móvil es opcional.';

  @override
  String get welcomeDownloadOnThe => 'Descargar en';

  @override
  String get welcomeAppStore => 'App Store';

  @override
  String get welcomeUseSameCredentials =>
      'Usa el mismo correo y contraseña que acabas de crear en cualquier lugar donde inicies sesión.';

  @override
  String get welcomeInviteAccepted =>
      'Esta invitación ya fue aceptada. Inicia sesión con tu cuenta para continuar.';

  @override
  String get welcomeInviteExpired =>
      'Este enlace de invitación venció. Pídele a tu administrador que te envíe una nueva invitación.';

  @override
  String get welcomeInviteRevoked =>
      'Esta invitación fue revocada por tu administrador. Pídele una nueva si todavía necesitas acceso.';

  @override
  String get welcomeInviteInvalid =>
      'Este enlace de invitación no es válido o ya no está disponible.';

  @override
  String get welcomeRoleGeneralUser => 'Usuario general';

  @override
  String get welcomeRoleManager => 'Gerente';

  @override
  String get welcomeRoleAdmin => 'Administrador';

  @override
  String get welcomeRoleUser => 'Usuario';

  @override
  String welcomeFailedSetup(String error) {
    return 'No se pudo completar la cuenta: $error';
  }

  @override
  String get welcomeInviteUsed =>
      'Esta invitación ya fue usada. Inicia sesión con tu cuenta.';

  @override
  String get welcomeInviteExistingAccount =>
      'Ya existe una cuenta para este correo electrónico. Inicia sesión o pídele a tu administrador una nueva invitación si esperabas una cuenta nueva.';

  @override
  String get welcomeInviteExpiredError =>
      'Esta invitación venció. Pídele a tu administrador que envíe una nueva.';

  @override
  String get welcomeInviteRevokedError =>
      'Esta invitación fue revocada. Pídele a tu administrador una nueva invitación.';

  @override
  String get welcomeInviteMissingEmail =>
      'La invitación no tiene una dirección de correo electrónico.';

  @override
  String get notificationsInbox => 'Bandeja';

  @override
  String get notificationsUnread => 'No leídos';

  @override
  String get notificationsRead => 'Leídos';

  @override
  String get notificationsArchived => 'Archivados';

  @override
  String get notificationsHeaderSubtitle =>
      'Actualizaciones sin leer, elementos leídos y mensajes archivados.';

  @override
  String get notificationsDeleteTitle => 'Eliminar mensaje';

  @override
  String get notificationsDeleteBody =>
      '¿Seguro que quieres eliminar este mensaje de forma permanente? Esta acción no se puede deshacer.';

  @override
  String get notificationsDeleteSuccess => 'Mensaje eliminado correctamente';

  @override
  String notificationsDeleteFailed(String error) {
    return 'No se pudo eliminar el mensaje: $error';
  }

  @override
  String notificationsNoMessagesIn(String filter) {
    return 'No hay mensajes en $filter';
  }

  @override
  String get notificationsNewMessage => 'Nuevo mensaje';

  @override
  String get notificationsNoContent => 'Sin contenido';

  @override
  String get notificationsLoadMore => 'Cargar más';

  @override
  String notificationsYesterdayAt(String time) {
    return 'Ayer $time';
  }

  @override
  String get contactUsTitle => 'Contáctanos';

  @override
  String get contactUsSuccess =>
      '¡Solicitud enviada con éxito! Te responderemos dentro de 24 horas.';

  @override
  String get contactUsFailed => 'No se pudo enviar la solicitud';

  @override
  String get contactUsNetworkError => 'Error de red. Inténtalo de nuevo.';

  @override
  String get contactUsOverviewTitle => 'Soporte, sin tantas idas y vueltas.';

  @override
  String get contactUsOverviewBody =>
      'Envía una solicitud clara y nuestro equipo responderá con la ayuda correcta para configuración, facturación, errores o preguntas sobre flujos de trabajo.';

  @override
  String get contactUsTechnicalIssues => 'Problemas técnicos';

  @override
  String get contactUsBillingQuestions => 'Preguntas de facturación';

  @override
  String get contactUsTeamSetupHelp => 'Ayuda con el equipo';

  @override
  String get contactUsWhatToExpect => 'Qué esperar';

  @override
  String get contactUsTypicalResponse => 'Respuesta típica';

  @override
  String get contactUsTypicalResponseValue => 'Dentro de 24 horas';

  @override
  String get contactUsBestFor => 'Ideal para';

  @override
  String get contactUsBestForValue =>
      'Ayuda del producto, facturación y configuración';

  @override
  String get contactUsHelpfulDetails => 'Detalles útiles';

  @override
  String get contactUsHelpfulDetailsValue => 'Ubicación, rol y lo que ocurrió';

  @override
  String get contactUsSupportContext => 'Contexto de soporte';

  @override
  String get contactUsSupportContextBody =>
      'Incluiremos automáticamente el contexto actual de ayuda y ubicación.';

  @override
  String get bottomNavTodayTasks => 'Tareas de hoy';

  @override
  String get bottomNavDashboard => 'Panel';

  @override
  String get bottomNavSetup => 'Configuración';

  @override
  String get bottomNavDocumentCenter => 'Centro de documentos';

  @override
  String get messagesTitle => 'Comunicaciones';

  @override
  String get messagesHeaderSubtitle =>
      'La bandeja mantiene a todos al día. Los comunicados envían novedades. Las audiencias organizan quién las recibe.';

  @override
  String get messagesInboxTab => 'Bandeja';

  @override
  String get messagesBroadcastsTab => 'Comunicados';

  @override
  String get messagesAudiencesTab => 'Audiencias';

  @override
  String get messagesBroadcastsTitle => 'Comunicados';

  @override
  String get messagesBroadcastsBody =>
      'Envía una actualización clara a todos, a una ubicación o a una audiencia personalizada.';

  @override
  String get messagesBroadcastsHelp =>
      'Usa comunicados para anuncios claros para todo el equipo o para ubicaciones específicas que deban quedar visibles en la bandeja.';

  @override
  String get messagesNewBroadcast => 'Nuevo comunicado';

  @override
  String get messagesBroadcastsUnavailable => 'Comunicados no disponibles';

  @override
  String get messagesOrgContextMissing =>
      'No pudimos determinar el contexto de tu organización.';

  @override
  String get messagesNoBroadcasts => 'Todavía no hay comunicados';

  @override
  String get messagesNoBroadcastsBody =>
      'Tus actualizaciones enviadas aparecerán aquí cuando publiques un comunicado al equipo.';

  @override
  String get messagesSending => 'Enviando...';

  @override
  String get messagesEveryone => 'Todos';

  @override
  String get messagesCustomAudience => 'Audiencia personalizada';

  @override
  String get messagesLocation => 'Ubicación';

  @override
  String get messagesUntitledBroadcast => 'Comunicado sin título';

  @override
  String get messagesAudiencesTitle => 'Audiencias';

  @override
  String get messagesAudiencesBody =>
      'Crea listas reutilizables para que el equipo correcto reciba la actualización correcta cada vez.';

  @override
  String get messagesAudiencesHelp =>
      'Las audiencias son grupos reutilizables de destinatarios que te ayudan a enviar el comunicado correcto al equipo correcto.';

  @override
  String get broadcastSheetTitle => 'Nuevo comunicado';

  @override
  String get broadcastSheetSubtitle =>
      'Envía una actualización clara a todos, a una ubicación o a una audiencia guardada.';

  @override
  String get broadcastSendButton => 'Enviar comunicado';

  @override
  String get broadcastInfoTip =>
      'Los comunicados aparecen en la bandeja del equipo y también pueden enviar una notificación push.';

  @override
  String get broadcastAudienceSectionTitle => 'Audiencia';

  @override
  String get broadcastRecipientEveryone => 'Todos';

  @override
  String get broadcastRecipientSavedAudience => 'Audiencia guardada';

  @override
  String get broadcastRecipientLocation => 'Ubicación específica';

  @override
  String get broadcastSendToLabel => 'Enviar a';

  @override
  String get broadcastChooseAudience => 'Elige una audiencia';

  @override
  String get broadcastSelectAudience => 'Selecciona una audiencia';

  @override
  String get broadcastSelectLocation => 'Selecciona una ubicación';

  @override
  String get broadcastMessageSectionTitle => 'Mensaje';

  @override
  String get broadcastHeadlineLabel => 'Titular';

  @override
  String get broadcastEnterHeadline => 'Ingresa un titular';

  @override
  String get broadcastMessageLabel => 'Mensaje';

  @override
  String get broadcastMessageHint =>
      '¿Qué debe saber el equipo en este momento?';

  @override
  String get broadcastEnterMessage => 'Ingresa un mensaje';

  @override
  String get broadcastDismiss => 'Descartar';

  @override
  String broadcastAutoTitleAudience(String name) {
    return 'Actualización para $name';
  }

  @override
  String get broadcastAutoTitleAudienceFallback => 'Actualización de audiencia';

  @override
  String broadcastAutoTitleLocation(String name) {
    return 'Actualización para $name';
  }

  @override
  String get broadcastAutoTitleLocationFallback => 'Actualización de ubicación';

  @override
  String get broadcastAutoTitleTeam => 'Actualización del equipo';

  @override
  String get audienceSheetSubtitle =>
      'Crea listas reutilizables de audiencia para que los gerentes puedan dirigirse al equipo correcto rápidamente.';

  @override
  String get audienceSavedTitle => 'Audiencias guardadas';

  @override
  String get audienceNewTitle => 'Nueva audiencia';

  @override
  String get audienceNameLabel => 'Nombre de la audiencia';

  @override
  String get audienceSearchMembers => 'Buscar miembros del equipo';

  @override
  String get audienceTeamMembers => 'Miembros del equipo';

  @override
  String get audienceMembersTitle => 'Miembros de la audiencia';

  @override
  String get audienceCreateButton => 'Crear audiencia';

  @override
  String get audienceEditTitle => 'Editar audiencia';

  @override
  String get audienceDeleteTitle => 'Eliminar audiencia';

  @override
  String get audienceEnterNameAndMember =>
      'Ingresa un nombre de audiencia y selecciona al menos un miembro del equipo.';

  @override
  String get audienceCreatedSuccess => '¡Audiencia creada correctamente!';

  @override
  String get audienceUpdatedSuccess => 'Audiencia actualizada correctamente!';

  @override
  String get audienceDeletedSuccess => 'Audiencia eliminada correctamente!';

  @override
  String audienceDeleteBody(String groupName) {
    return '¿Seguro que quieres eliminar la audiencia \"$groupName\"? Esta acción no se puede deshacer.';
  }

  @override
  String get messagesManageAudiences => 'Administrar audiencias';

  @override
  String get messagesAudiencesUnavailable => 'Audiencias no disponibles';

  @override
  String get messagesNoAudiences => 'Todavía no hay audiencias personalizadas';

  @override
  String get messagesNoAudiencesBody =>
      'Empieza con audiencias personalizadas para equipos como Bar, Cocina o el equipo de fin de semana.';

  @override
  String get messagesCustomAudiencesMetric => 'Audiencias personalizadas';

  @override
  String get messagesLinkedMembersMetric => 'Miembros vinculados';

  @override
  String get messagesUnnamedAudience => 'Audiencia sin nombre';

  @override
  String messagesMemberCount(int count) {
    return '$count miembros';
  }

  @override
  String get threadTitle => 'Conversación';

  @override
  String get threadNoMessages => 'Todavía no hay mensajes';

  @override
  String get threadMessageHint => 'Mensaje';

  @override
  String get threadDeleteTitle => 'Eliminar mensaje';

  @override
  String get threadDeleteBody =>
      '¿Seguro que quieres eliminar este mensaje? Esta acción no se puede deshacer.';

  @override
  String get threadDeleteSuccess => 'Mensaje eliminado correctamente';

  @override
  String threadDeleteFailed(String error) {
    return 'No se pudo eliminar el mensaje: $error';
  }

  @override
  String get commonOpen => 'Abrir';

  @override
  String get commonReplay => 'Repetir';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpSubtitle =>
      'Encuentra la forma más rápida de completar tu trabajo, configurar operaciones o resolver un problema.';

  @override
  String get helpSearchHint =>
      'Busca ayuda, configuración o solución de problemas';

  @override
  String get helpSearchResultsTitle => 'Resultados de búsqueda';

  @override
  String get helpNoSearchResults =>
      'Todavía no hay temas de ayuda que coincidan con esa búsqueda.';

  @override
  String helpTopicsFoundForRole(int count, String role) {
    return '$count temas encontrados para $role';
  }

  @override
  String get helpStartHereTitle => 'Empieza aquí';

  @override
  String get helpOpenHelp => 'Abrir ayuda';

  @override
  String get helpOpenWalkthrough => 'Abrir recorrido';

  @override
  String get helpStartHereSectionSubtitle =>
      'Comienza con la ruta más corta para tu rol.';

  @override
  String get helpNewHereTitle => 'Soy nuevo aquí';

  @override
  String get helpNewHereBody =>
      'Recibe el recorrido guiado según tu rol sin tener que leer primero todas las guías.';

  @override
  String get helpOpenStartHere => 'Abrir Empieza aquí';

  @override
  String get helpBrowseByRoleTitle => 'Explorar por rol';

  @override
  String get helpBrowseByRoleBody => 'Ve solo los temas de tu trabajo.';

  @override
  String get helpFixProblemTitle => 'Resolver un problema';

  @override
  String get helpFixProblemBody => 'Ve directo a la solución de problemas.';

  @override
  String get helpBrowseByRoleSectionSubtitle =>
      'Cambia de perspectiva sin cambiar de cuenta.';

  @override
  String get helpReplayGuidedTourTitle => 'Repetir recorrido guiado';

  @override
  String get helpReplayGuidedTourSubtitle =>
      'Vuelve al recorrido dentro de la app para tu rol actual cuando necesites un repaso.';

  @override
  String get helpWhatsNewTitle => 'Qué hay de nuevo';

  @override
  String get helpWhatsNewSubtitle =>
      'Vuelve a abrir el resumen de la última actualización importante y entra de nuevo al recorrido guiado.';

  @override
  String get helpMajorUpdateAvailable => 'Actualización importante disponible';

  @override
  String get helpLatestMajorRelease => 'Última versión importante';

  @override
  String get helpOpenLatestReleaseUpdateBody =>
      'Abre el resumen más reciente y las instrucciones de actualización para tu rol.';

  @override
  String get helpOpenLatestReleaseTourBody =>
      'Abre el resumen más reciente y vuelve a iniciar el recorrido guiado para tu rol.';

  @override
  String get helpPopularTasksTitle => 'Tareas populares';

  @override
  String helpPopularTasksSubtitle(String role) {
    return 'Las guías más útiles para $role en este momento.';
  }

  @override
  String helpRoleBannerTitle(String role) {
    return 'Ayuda para $role';
  }

  @override
  String get helpStillStuckTitle => '¿Todavía atascado?';

  @override
  String get helpStillStuckBody =>
      'Abre primero la solución de problemas o contacta a soporte con el problema que estás viendo ahora mismo.';

  @override
  String get helpContactSupport => 'Contactar soporte';

  @override
  String get settingsPageTitle => 'Configuración';

  @override
  String get settingsHeroTitle =>
      'Configuración de cuenta y espacio de trabajo';

  @override
  String get settingsHeroHelp =>
      'Usa Configuración para detalles de cuenta, preferencias y soporte sin perder el foco en la operación.';

  @override
  String get settingsHeroAdminBody =>
      'Administra tu perfil, detalles del negocio, facturación y preferencias operativas desde un solo lugar.';

  @override
  String get settingsHeroStaffBody =>
      'Administra tu perfil, contraseña y preferencias de notificación desde un solo lugar.';

  @override
  String get settingsPreferencesTitle => 'Preferencias';

  @override
  String get settingsPreferencesSaved => '¡Preferencias guardadas con éxito!';

  @override
  String settingsPreferencesSaveFailed(String error) {
    return 'No se pudieron guardar las preferencias: $error';
  }

  @override
  String get settingsProfileTitle => 'Perfil';

  @override
  String get settingsProfileSubtitle =>
      'Los datos de tu cuenta y tu correo de acceso.';

  @override
  String get settingsBusinessTitle => 'Negocio';

  @override
  String get settingsBusinessSubtitle =>
      'Detalles centrales de la organización que se muestran en toda la app.';

  @override
  String get settingsLocationsTitle => 'Ubicaciones';

  @override
  String get settingsLocationsSubtitle =>
      'Administra dónde trabaja tu equipo y dónde se ejecutan los turnos.';

  @override
  String get settingsLocationsBody =>
      'Agrega, revisa o ajusta las ubicaciones vinculadas a tu organización.';

  @override
  String get settingsLocationSupportEmail =>
      'Envíanos un correo a support@planwithhands.com';

  @override
  String get settingsGuidedToursTitle => 'Recorridos guiados';

  @override
  String get settingsGuidedToursSubtitle =>
      'Repite el recorrido dentro de la app para tu rol actual cuando necesites un repaso.';

  @override
  String settingsReplayTour(String role) {
    return 'Repetir recorrido de $role';
  }

  @override
  String get settingsWhatsNew => 'Qué hay de nuevo';

  @override
  String get settingsSecurityTitle => 'Seguridad';

  @override
  String get settingsSecuritySubtitle =>
      'Restablecimiento de contraseña y controles de acceso relacionados con la sesión.';

  @override
  String get settingsResetPassword => 'Restablecer contraseña';

  @override
  String get settingsSignedInAs => 'Sesión iniciada como';

  @override
  String get settingsOrganization => 'Organización';

  @override
  String get settingsSessionTimeout => 'Tiempo de espera de la sesión';

  @override
  String get settingsSessionTimeoutSubtitle =>
      'Cierra la sesión automáticamente después de un período de inactividad';

  @override
  String get settingsSessionTimeoutDone => 'Listo';

  @override
  String get settingsSessionTimeout2Hours => '2 horas';

  @override
  String get settingsSessionTimeout2HoursBody =>
      'Alta seguridad: cierre automático después de 2 horas';

  @override
  String get settingsSessionTimeout4Hours => '4 horas';

  @override
  String get settingsSessionTimeout4HoursBody =>
      'Seguridad equilibrada: cierre automático después de 4 horas';

  @override
  String get settingsSessionTimeout8Hours => '8 horas';

  @override
  String get settingsSessionTimeout8HoursBody =>
      'Recomendado: ideal para turnos de trabajo';

  @override
  String get settingsSessionTimeout24Hours => '24 horas';

  @override
  String get settingsSessionTimeout24HoursBody =>
      'Acceso extendido: cierre automático después de 1 día';

  @override
  String get settingsResetEmailInvalid =>
      'Ingresa una dirección de correo válida';

  @override
  String settingsResetEmailSentVerified(String email) {
    return 'Se envió el restablecimiento a tu correo verificado $email. Verifica tu nuevo correo para usarlo al iniciar sesión.';
  }

  @override
  String settingsResetEmailSent(String email) {
    return 'Se envió el correo de restablecimiento a $email';
  }

  @override
  String get settingsResetEmailFailed =>
      'No se pudo enviar el correo de restablecimiento';

  @override
  String get settingsResetEmailUserNotFound =>
      'No se encontró una cuenta con esta dirección de correo';

  @override
  String get settingsResetEmailTooManyRequests =>
      'Demasiadas solicitudes. Inténtalo de nuevo más tarde';

  @override
  String get settingsSummaryPeriodTitle => 'Selecciona el período del resumen';

  @override
  String get settingsSummaryPeriodCalendar => 'Día calendario';

  @override
  String get settingsSummaryPeriodCalendarBody =>
      'Solo las tareas de hoy (de 6 a. m. a 6 a. m.)';

  @override
  String get settingsSummaryPeriodBusiness => 'Día operativo';

  @override
  String get settingsSummaryPeriodBusinessBody =>
      'Incluye las tareas de cierre de anoche';

  @override
  String get settingsDailySummaryHourTitle =>
      'Selecciona la hora del resumen diario';

  @override
  String get settingsDailySummaryFixedMinutes =>
      'Los minutos están fijos en :00';

  @override
  String get settingsOrganizationDailySummaryUpdated =>
      '¡La configuración del resumen diario de la organización se actualizó!';

  @override
  String settingsOrganizationDailySummaryFailed(String error) {
    return 'No se pudo guardar la configuración de la organización: $error';
  }

  @override
  String get settingsDailySummaryEmailTitle => 'Correo de resumen diario';

  @override
  String get settingsDailySummaryEmailSubtitle =>
      'Recibe resúmenes diarios de finalización de tareas';

  @override
  String get settingsDailySummaryTimeTitle => 'Hora del resumen diario';

  @override
  String get settingsDailySummaryTimeSubtitle =>
      'Cuándo recibir tu resumen diario';

  @override
  String get settingsDailySummaryRateLimitTitle => 'Límite de cambios';

  @override
  String get settingsDailySummaryChangeBlocked =>
      'No se puede cambiar el resumen diario en este momento.';

  @override
  String get settingsDailySummaryConfirmTitle => 'Confirmar cambio de hora';

  @override
  String get settingsDailySummaryTimePassedTitle => 'La hora ya pasó';

  @override
  String get settingsDailySummaryProceedQuestion =>
      '¿Quieres continuar con el cambio de hora?';

  @override
  String get settingsDailySummarySendNowTitle => '¿Enviar ahora?';

  @override
  String get settingsDailySummarySendNowBody =>
      '¿Quieres enviar el resumen de hoy ahora mismo en lugar de esperar hasta mañana?';

  @override
  String get settingsDailySummarySendNowLater => 'No, esperar';

  @override
  String get settingsDailySummarySendNowAction => 'Sí, enviar ahora';

  @override
  String get settingsDailySummaryResultSuccess => 'Éxito';

  @override
  String get settingsDailySummaryResultError => 'Error';

  @override
  String get settingsSummaryPeriodLabel => 'Período del resumen';

  @override
  String get settingsSummaryPeriodLabelSubtitle =>
      'Elige si el resumen incluye tareas nocturnas';

  @override
  String get settingsDashboardMetricsTitle => 'Métricas del panel';

  @override
  String get settingsDashboardMetricsSubtitle =>
      'Recalcula las métricas del panel desde hoy';

  @override
  String get settingsRefresh => 'Actualizar';

  @override
  String get settingsLoadingSubscriptionData =>
      'Cargando datos de suscripción...';

  @override
  String get settingsLoadingSubscriptionDetails =>
      'Cargando detalles de la suscripción...';

  @override
  String get settingsTrialEndingSoon => 'La prueba termina pronto';

  @override
  String settingsFreeTrialDays(int days) {
    return 'Prueba gratuita de $days días';
  }

  @override
  String settingsTrialContinueUntil(String date) {
    return 'Tu prueba continuará hasta $date, pero no se te cobrará.';
  }

  @override
  String settingsTrialChargeOn(String date, int days) {
    return 'Estás en una prueba gratuita de $days días. Tu primer cobro será el $date a menos que canceles.';
  }

  @override
  String get settingsCancelSubscription => 'Cancelar suscripción';

  @override
  String get settingsManageBilling => 'Administrar facturación';

  @override
  String get settingsBillingPortal => 'Portal de facturación';

  @override
  String settingsBillingPortalFailed(String error) {
    return 'No se pudo abrir el portal de facturación: $error';
  }

  @override
  String get settingsTrialAndBilling => 'Prueba y facturación';

  @override
  String get settingsSubscriptionManagement => 'Administración de suscripción';

  @override
  String get settingsPlannedLocations => 'Ubicaciones planificadas:';

  @override
  String get settingsSubscribedLocations => 'Ubicaciones suscritas:';

  @override
  String get settingsLocationsInUse => 'Ubicaciones en uso:';

  @override
  String get settingsMonthlyCost => 'Costo mensual:';

  @override
  String get settingsStatus => 'Estado:';

  @override
  String get settingsSubscriptionOverUsage =>
      'Estás usando más ubicaciones de las que permite tu suscripción. Actualiza para evitar interrupciones en el servicio.';

  @override
  String get settingsAddBilling => 'Agregar facturación';

  @override
  String get settingsManageSubscription => 'Administrar suscripción';

  @override
  String get settingsBillingWebOnly =>
      'Para administrar tu suscripción, visita https://planwithhands.com y haz clic en \"Login\" arriba a la derecha. Las suscripciones deben administrarse desde el portal web.';

  @override
  String get settingsBillingPortalWebOnly =>
      'Para administrar la facturación, abre esta página en Safari o Chrome y visita el portal de facturación. Las suscripciones deben administrarse desde el portal web.';

  @override
  String get settingsTalkToSales => 'Hablar con ventas';

  @override
  String get settingsNoOrganizationFound =>
      'No se encontró ninguna organización. Comunícate con soporte.';

  @override
  String get settingsOrganizationInformation =>
      'Información de la organización';

  @override
  String get settingsOrganizationLabel => 'Organización:';

  @override
  String get settingsBusinessTypeLabel => 'Tipo de negocio:';

  @override
  String get settingsNotSet => 'Sin configurar';

  @override
  String get settingsActiveLocations => 'Ubicaciones activas:';

  @override
  String get settingsNeedHelp => '¿Necesitas ayuda?';

  @override
  String get settingsSupportContactBody =>
      'Para administración de suscripciones, preguntas de facturación o soporte técnico, contáctanos:';

  @override
  String get settingsSupportEmailPrompt =>
      'Envíanos un correo a support@planwithhands.com';

  @override
  String get settingsContactSalesBody =>
      'Para 5 o más ubicaciones, contacta a nuestro equipo de ventas para un plan personalizado.';

  @override
  String get settingsSubscriptionUpgraded => '¡Suscripción mejorada!';

  @override
  String get settingsSubscriptionUpdated => '¡Suscripción actualizada!';

  @override
  String settingsSubscriptionUpdateFailed(String error) {
    return 'No se pudo actualizar: $error';
  }

  @override
  String get settingsSubscriptionChangeIncrease => 'aumentar';

  @override
  String get settingsSubscriptionChangeDecrease => 'reducir';

  @override
  String get settingsUpgradeSubscription => 'Mejorar suscripción';

  @override
  String get settingsDowngradeSubscription => 'Reducir suscripción';

  @override
  String settingsSubscriptionAboutToChange(String change) {
    return 'Estás a punto de $change tu suscripción de ubicaciones:';
  }

  @override
  String get settingsFrom => 'De:';

  @override
  String get settingsTo => 'A:';

  @override
  String settingsLocationsCount(int count) {
    return '$count ubicaciones';
  }

  @override
  String get settingsMonthlyChange => 'Cambio mensual:';

  @override
  String get settingsPerMonth => '/mes';

  @override
  String get settingsBillingEffectiveNextCycle =>
      'El nuevo importe de facturación entrará en vigor en tu próximo ciclo de facturación.';

  @override
  String get settingsCurrent => 'Actual:';

  @override
  String get settingsInUse => 'En uso:';

  @override
  String settingsCannotReduceBelow(int currentUsage) {
    return 'No se puede reducir por debajo de $currentUsage (uso actual). Elimina ubicaciones primero.';
  }

  @override
  String get settingsNoChanges => 'Sin cambios';

  @override
  String get settingsUpgrade => 'Mejorar';

  @override
  String get settingsDowngrade => 'Reducir';

  @override
  String get settingsStatusActive => 'ACTIVA';

  @override
  String get settingsStatusTrial => 'PRUEBA';

  @override
  String get settingsStatusPastDue => 'VENCIDA';

  @override
  String get settingsStatusCanceled => 'CANCELADA';

  @override
  String get settingsStatusUnpaid => 'IMPAGA';

  @override
  String get settingsStatusPending => 'PENDIENTE';

  @override
  String get settingsAccountTitle => 'Cuenta';

  @override
  String get settingsAccountSubtitle =>
      'Cierre de sesión del dispositivo y acciones irreversibles de la cuenta.';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsSignOutSubtitle =>
      'Esto cierra tu sesión en este dispositivo y te devuelve a la pantalla de inicio de sesión.';

  @override
  String get settingsSigningOut => 'Cerrando sesión...';

  @override
  String settingsSignOutFailed(String error) {
    return 'No se pudo cerrar sesión: $error';
  }

  @override
  String get settingsDeleteAccount => 'Eliminar cuenta';

  @override
  String get settingsDeleteAccountWarningTitle => '¿Eliminar cuenta?';

  @override
  String get settingsDeleteAccountWarningBody =>
      'Esto eliminará permanentemente tu cuenta y todos los datos personales asociados. Esta acción NO se puede deshacer.';

  @override
  String get settingsDeleteAccountReinviteBody =>
      'Si continúas y luego quieres volver a usar Hands, necesitarás recibir una NUEVA INVITACIÓN de tu administrador para registrarte de nuevo.';

  @override
  String get settingsDeleteAccountContinueQuestion =>
      '¿Todavía quieres continuar?';

  @override
  String get settingsDeleteAccountConfirmAction => 'Sí, eliminar';

  @override
  String get settingsDeleteAccountBody =>
      'Esto eliminará permanentemente tu cuenta y todos tus datos. Esta acción no se puede deshacer.';

  @override
  String get settingsDeleteAccountPasswordPrompt =>
      'Ingresa tu contraseña para confirmar:';

  @override
  String get settingsDeleteAccountPasswordHint => 'Contraseña';

  @override
  String get settingsDeletingAccount => 'Eliminando cuenta...';

  @override
  String get settingsDeleteAccountSuccess => 'Cuenta eliminada con éxito';

  @override
  String get settingsDeleteAccountFailed => 'No se pudo eliminar la cuenta';

  @override
  String get settingsDeleteAccountWrongPassword =>
      'Contraseña incorrecta. Inténtalo de nuevo.';

  @override
  String get settingsDeleteAccountRelogin =>
      'Cierra sesión y vuelve a iniciar sesión, luego inténtalo de nuevo.';

  @override
  String get settingsDeleteAccountTooManyRequests =>
      'Demasiados intentos fallidos. Inténtalo de nuevo más tarde.';

  @override
  String get settingsAddLocation => 'Agregar ubicación';

  @override
  String get settingsEdit => 'Editar';

  @override
  String get settingsFirstName => 'Nombre';

  @override
  String get settingsLastName => 'Apellido';

  @override
  String get settingsEditProfileTitle => 'Editar perfil';

  @override
  String get settingsEditProfileSubtitle =>
      'Actualiza tu nombre y tu correo de inicio de sesión.';

  @override
  String get settingsSaveChanges => 'Guardar cambios';

  @override
  String get settingsProfileSignInRequired =>
      'Inicia sesión para editar tu perfil';

  @override
  String get settingsProfileSavedVerifyEmail =>
      'Perfil guardado. Verifica el nuevo correo.';

  @override
  String get settingsProfileUpdatedSuccess => '¡Perfil actualizado con éxito!';

  @override
  String get settingsProfileUpdateFailed => 'No se pudo actualizar el perfil';

  @override
  String get settingsProfileErrorReloginToChangeEmail =>
      'Cierra y vuelve a iniciar sesión para cambiar el correo';

  @override
  String get settingsProfileErrorEmailInUse => 'El correo ya está en uso';

  @override
  String get settingsProfileErrorInvalidEmail =>
      'Dirección de correo no válida';

  @override
  String get settingsFieldEnterFirstName => 'Ingresa el nombre';

  @override
  String get settingsFieldEnterLastName => 'Ingresa el apellido';

  @override
  String get settingsInvalidEmail => 'Correo no válido';

  @override
  String get settingsBusinessName => 'Nombre del negocio';

  @override
  String get settingsBusinessType => 'Tipo de negocio';

  @override
  String get commonRequired => 'Obligatorio';

  @override
  String get commonHide => 'Ocultar';

  @override
  String helpSupportRequest(String role) {
    return 'Solicitud de soporte de $role';
  }

  @override
  String helpRolePageTitle(String role) {
    return 'Ayuda de $role';
  }

  @override
  String get helpTroubleshootingTitle => 'Solución de problemas';

  @override
  String get helpTroubleshootingSubtitle =>
      'Resuelve bloqueos rápido comenzando por el síntoma que estás viendo ahora mismo.';

  @override
  String get helpTroubleshootingSearchHint =>
      'Busca un problema como turno faltante o ubicación incorrecta';

  @override
  String get helpTroubleshootingIntroTitle =>
      'La solución de problemas funciona mejor cuando comienzas con el síntoma exacto.';

  @override
  String get helpTroubleshootingIntroBody =>
      'Primero revisa la ubicación activa, el rol actual y el contexto de la pantalla. Muchos problemas en realidad son de alcance o configuración.';

  @override
  String get helpTroubleshootingCommonProblems => 'Problemas comunes';

  @override
  String get helpTroubleshootingResults => 'Resultados';

  @override
  String get helpTroubleshootingNoResults =>
      'Ninguna guía de solución de problemas coincide con esa búsqueda. Prueba con un síntoma más simple o contacta a soporte.';

  @override
  String get helpNeedMoreHelpTitle => '¿Necesitas más ayuda?';

  @override
  String get helpNeedMoreHelpBody =>
      'Envía a soporte el problema exacto, la ubicación y la pantalla en la que estabas. Incluiremos el contexto de solución de problemas automáticamente.';

  @override
  String get helpTopicScreenLabel => 'Tema de ayuda';

  @override
  String get helpTopicMissingSubtitle => 'No se pudo encontrar ese tema.';

  @override
  String get helpTopicMissingBody =>
      'La guía que intentaste abrir ya no existe o todavía no se ha agregado.';

  @override
  String get helpReturnToHelp => 'Volver a Ayuda';

  @override
  String helpMinutes(int count) {
    return '$count min';
  }

  @override
  String get helpWhyThisMatters => 'Por qué importa';

  @override
  String get helpDoThisNow => 'Haz esto ahora';

  @override
  String get helpWhatGoodLooksLike => 'Cómo se ve bien hecho';

  @override
  String get helpCommonMistakes => 'Errores comunes';

  @override
  String helpMoreRoleHelp(String role) {
    return 'Más ayuda para $role';
  }

  @override
  String get helpRelatedHelp => 'Ayuda relacionada';

  @override
  String get helpStartHerePageSubtitle =>
      'Un recorrido rápido por lo esencial para tu rol, para que puedas usar la app sin adivinar.';

  @override
  String get helpFollowTheseSteps => 'Sigue estos pasos';

  @override
  String get helpKeepGoing => 'Sigue adelante';

  @override
  String get helpRoleStaff => 'Personal';

  @override
  String get helpRoleManager => 'Gerente';

  @override
  String get helpRoleAdmin => 'Administrador';

  @override
  String get helpRoleStaffShortDescription =>
      'Trabajo diario, turnos, tareas y pendientes';

  @override
  String get helpRoleManagerShortDescription =>
      'Supervisión diaria, seguimiento y comunicados';

  @override
  String get helpRoleAdminShortDescription =>
      'Configuración, flujos de trabajo, acceso del equipo y operaciones';

  @override
  String get helpCategoryDailyWork => 'Trabajo diario';

  @override
  String get helpCategoryDailyWorkDescription =>
      'Completa tu turno y termina las tareas de forma ordenada.';

  @override
  String get helpCategoryOversight => 'Supervisión diaria';

  @override
  String get helpCategoryOversightDescription =>
      'Comprende el servicio en vivo y responde rápido a los riesgos.';

  @override
  String get helpCategorySetup => 'Configuración operativa';

  @override
  String get helpCategorySetupDescription =>
      'Configura el negocio en el orden correcto.';

  @override
  String get helpCategoryCommunications => 'Comunicaciones';

  @override
  String get helpCategoryCommunicationsDescription =>
      'Mantén al equipo alineado con bandeja, comunicados y audiencias.';

  @override
  String get helpCategoryDocuments => 'Documentos y formación';

  @override
  String get helpCategoryDocumentsDescription =>
      'Usa el Centro de documentos para formación, SOP y referencias.';

  @override
  String get helpCategoryAccount => 'Cuenta y acceso';

  @override
  String get helpCategoryAccountDescription =>
      'Administra inicio de sesión, ubicaciones, accesos y lo básico del perfil.';

  @override
  String get helpCategorySharedMode => 'Modo compartido';

  @override
  String get helpCategorySharedModeDescription =>
      'Usa dispositivos compartidos de forma segura sin perder el control.';

  @override
  String get helpCategoryTroubleshooting => 'Solución de problemas';

  @override
  String get helpCategoryTroubleshootingDescription =>
      'Resuelve bloqueos rápido cuando faltan trabajo, acceso o mensajes.';

  @override
  String get helpCategoryOperationsControl => 'Control operativo';

  @override
  String get helpCategoryOperationsControlDescription =>
      'Gestiona las operaciones del día a día y mantén la configuración saludable con el tiempo.';

  @override
  String contactUsPrefillSubjectTopic(String topic) {
    return 'Ayuda con $topic';
  }

  @override
  String contactUsPrefillSubjectIssue(String issue) {
    return 'Ayuda con $issue';
  }

  @override
  String contactUsPrefillSubjectScreen(String screen) {
    return 'Ayuda en $screen';
  }

  @override
  String get contactUsPrefillSubjectDefault => 'Solicitud de soporte';

  @override
  String get contactUsPrefillPrompt =>
      'Describe qué pasó, qué esperabas y cualquier error que hayas visto.';

  @override
  String get contactUsPrefillContextTitle => 'Contexto';

  @override
  String contactUsPrefillRole(String role) {
    return 'Rol: $role';
  }

  @override
  String contactUsPrefillHelpTopic(String topic) {
    return 'Tema de ayuda: $topic';
  }

  @override
  String contactUsPrefillScreen(String screen) {
    return 'Pantalla: $screen';
  }

  @override
  String contactUsPrefillLocation(String location) {
    return 'Ubicación: $location';
  }

  @override
  String contactUsPrefillIssue(String issue) {
    return 'Problema: $issue';
  }

  @override
  String contactUsPrefillRoute(String route) {
    return 'Ruta: $route';
  }

  @override
  String get contactUsSendRequestTitle => 'Enviar una solicitud';

  @override
  String get contactUsSendRequestBody =>
      'Hazla breve y específica para que podamos ayudarte más rápido.';

  @override
  String get contactUsAutoContextBody =>
      'Esta solicitud ya incluye tu tema de ayuda, la pantalla actual y la ubicación activa para que soporte pueda responder más rápido.';

  @override
  String get contactUsSubjectLabel => 'Asunto';

  @override
  String get contactUsSubjectHint => '¿Con qué necesitas ayuda?';

  @override
  String get contactUsMessageLabel => 'Mensaje';

  @override
  String get contactUsMessageHint =>
      'Describe el problema, lo que esperabas y lo que ocurrió.';

  @override
  String get contactUsEmailRequired => 'El correo electrónico es obligatorio';

  @override
  String get contactUsValidEmailRequired =>
      'Ingresa un correo electrónico válido';

  @override
  String get contactUsSubjectRequired => 'El asunto es obligatorio';

  @override
  String get contactUsSubjectMinLength =>
      'El asunto debe tener al menos 5 caracteres';

  @override
  String get contactUsMessageRequired => 'El mensaje es obligatorio';

  @override
  String get contactUsMessageMinLength =>
      'El mensaje debe tener al menos 10 caracteres';

  @override
  String get contactUsSendRequestButton => 'Enviar solicitud';

  @override
  String get contactUsUrgentIssueNote =>
      'Para problemas urgentes, incluye la ubicación, el turno afectado y cualquier mensaje de error que hayas visto.';

  @override
  String get documentsTitle => 'Centro de documentos';

  @override
  String get documentsNoOrganization =>
      'No se encontró ninguna organización. Ponte en contacto con soporte.';

  @override
  String get documentsUploaded => 'Documento cargado';

  @override
  String get documentsUpdated => 'Documento actualizado';

  @override
  String get documentsDeleteTitle => 'Eliminar documento';

  @override
  String get documentsDeleteBody =>
      '¿Seguro que quieres eliminar este documento? Esta acción no se puede deshacer.';

  @override
  String get documentsDeletedSuccess => 'Documento eliminado correctamente';

  @override
  String documentsDeleteError(String error) {
    return 'Error al eliminar el documento: $error';
  }

  @override
  String get documentsAdminSubtitle =>
      'Organiza SOP, guías de formación y archivos de referencia para cada ubicación.';

  @override
  String get documentsStaffSubtitle =>
      'Encuentra las guías, políticas y materiales de referencia que necesitas para este turno.';

  @override
  String get documentsHelpSubtitle =>
      'Usa el Centro de documentos para SOP, formación y archivos de referencia que apoyen el trabajo sin saturar los flujos de tareas.';

  @override
  String get documentsUpload => 'Cargar';

  @override
  String get documentsSearchHint =>
      'Busca por título, categoría o nombre del archivo';

  @override
  String get documentsCurrentScope => 'Alcance actual';

  @override
  String get documentsAllLocations => 'Todas las ubicaciones';

  @override
  String documentsLocationsCount(int count) {
    return '$count ubicaciones';
  }

  @override
  String documentsErrorLoading(String error) {
    return 'Error al cargar los documentos: $error';
  }

  @override
  String get documentsVisibleFiles => 'Archivos visibles';

  @override
  String get documentsCategories => 'Categorías';

  @override
  String get documentsScope => 'Alcance';

  @override
  String get documentsScopeAll => 'Todo';

  @override
  String get documentsScopeLocal => 'Local';

  @override
  String get documentsBuildLibraryTitle => 'Crea tu biblioteca de documentos';

  @override
  String get documentsNoDocumentsTitle =>
      'Todavía no hay documentos disponibles';

  @override
  String get documentsBuildLibraryBody =>
      'Carga SOP, políticas de seguridad, guías de equipos y archivos de formación para que tu equipo tenga una sola fuente clara de información.';

  @override
  String get documentsNoDocumentsBody =>
      'Tu gerente o administrador cargará aquí las guías de formación, SOP y documentos de referencia.';

  @override
  String get documentsUploadFirst => 'Cargar primer documento';

  @override
  String documentsNoMatches(String query) {
    return 'Ningún archivo coincide con \"$query\" en el alcance actual.';
  }

  @override
  String get documentsNoLocationDocs =>
      'Todavía no hay documentos disponibles en esta ubicación.';

  @override
  String documentsNoCategoryDocs(String category) {
    return 'No se encontraron documentos en $category.';
  }

  @override
  String get documentsNothingToShow => 'Nada para mostrar';

  @override
  String get documentsUntitled => 'Sin título';

  @override
  String get documentsTypeVideo => 'Video';

  @override
  String get documentsTypeImage => 'Imagen';

  @override
  String get documentsTypeDoc => 'Doc';

  @override
  String get documentsGlobal => 'Global';

  @override
  String get documentsLocation => 'Ubicación';

  @override
  String get documentsEditTooltip => 'Editar';

  @override
  String get documentsDeleteTooltip => 'Eliminar';

  @override
  String documentsAddedDate(String date) {
    return 'Agregado $date';
  }

  @override
  String get documentsOpenError =>
      'No se pudo abrir el documento. Revisa tu conexión a internet.';

  @override
  String documentsOpenErrorDetailed(String error) {
    return 'Error al abrir el documento: $error';
  }

  @override
  String get documentsCategoryAll => 'Todo';

  @override
  String get documentsCategorySafetyProcedures => 'Procedimientos de seguridad';

  @override
  String get documentsCategoryCleaningProtocols => 'Protocolos de limpieza';

  @override
  String get documentsCategoryTrainingMaterials => 'Materiales de formación';

  @override
  String get documentsCategoryOperatingProcedures =>
      'Procedimientos operativos';

  @override
  String get documentsCategoryEmergencyProcedures =>
      'Procedimientos de emergencia';

  @override
  String get documentsCategoryEquipmentManuals => 'Manuales de equipos';

  @override
  String get documentsCategoryPolicyDocuments => 'Documentos de políticas';

  @override
  String get documentsCategoryOther => 'Otro';

  @override
  String get documentsViewerOpenExternalTooltip => 'Abrir en app externa';

  @override
  String get documentsViewerDownloadTooltip => 'Descargar';

  @override
  String get documentsViewerLoading => 'Cargando documento...';

  @override
  String get documentsViewerErrorTitle => 'Error al cargar el documento';

  @override
  String get documentsViewerInvalidUrl => 'URL de documento no válida.';

  @override
  String get documentsViewerDownloadFailed =>
      'No se pudo descargar el documento.';

  @override
  String get documentsViewerTestBrowser => 'Probar URL en el navegador';

  @override
  String get documentsViewerRetry => 'Reintentar';

  @override
  String get documentsViewerNoPath => 'No hay una ruta de documento disponible';

  @override
  String get documentsViewerTrainingDocument => 'Documento de formación';

  @override
  String get documentsViewerNativeBody =>
      'Este documento se abrirá en el visor nativo de tu dispositivo para una mejor experiencia.';

  @override
  String get documentsViewerOpenDocument => 'Abrir documento';

  @override
  String get documentsViewerNativeHelp =>
      'Los documentos se abren en el visor integrado de tu dispositivo para un rendimiento y funciones óptimos.';

  @override
  String get documentsViewerPdfTitle => 'Documento PDF';

  @override
  String get documentsViewerOfficeTitle => 'Documento de Office';

  @override
  String get documentsViewerWebBody =>
      'Haz clic abajo para ver o descargar este documento';

  @override
  String get documentsViewerViewDocument => 'Ver documento';

  @override
  String get documentsViewerCopyLink => 'Copiar enlace';

  @override
  String get documentsViewerTechnicalInfo => 'Información técnica';

  @override
  String get documentsViewerDocumentUrl => 'URL del documento:';

  @override
  String get documentsViewerNewTabNote =>
      'Nota: Los documentos se abren en una pestaña nueva debido a las políticas de seguridad del navegador.';

  @override
  String get documentsViewerImageFailed => 'No se pudo cargar la imagen';

  @override
  String get documentsViewerPreviewUnavailable => 'Vista previa no disponible';

  @override
  String get documentsViewerUnsupportedPreview =>
      'Este tipo de archivo no es compatible con la vista previa';

  @override
  String get documentsViewerOpenExternal => 'Abrir en app externa';

  @override
  String get documentsViewerUrlCopied => 'URL copiada al portapapeles';

  @override
  String get documentsViewerCopyFailed => 'No se pudo copiar la URL';

  @override
  String get documentsViewerVideoFailed => 'No se pudo cargar el video';

  @override
  String get documentsViewerLoadingVideo => 'Cargando video...';

  @override
  String get documentsUploadSheetTitle => 'Documento';

  @override
  String get documentsUploadSheetLoadingSubtitle =>
      'Cargando el contexto de la organización...';

  @override
  String get documentsUploadSheetMissingOrgSubtitle =>
      'No pudimos determinar tu organización.';

  @override
  String get documentsUploadTitle => 'Cargar documento';

  @override
  String get documentsEditTitle => 'Editar documento';

  @override
  String get documentsUploadSubtitle =>
      'Agrega SOP, políticas, guías y archivos de formación para el equipo.';

  @override
  String get documentsUpdateButton => 'Actualizar documento';

  @override
  String get documentsInfoTip =>
      'Carga PDF, archivos DOCX, imágenes o videos de hasta 20 MB y colócalos en la categoría correcta.';

  @override
  String get documentsDetails => 'Detalles';

  @override
  String get documentsDocumentTitleLabel => 'Título del documento';

  @override
  String get documentsDocumentTitleHint =>
      'Ingresa un título claro y descriptivo';

  @override
  String get documentsDocumentTitleRequired =>
      'Ingresa un título para el documento';

  @override
  String get documentsCategoryLabel => 'Categoría';

  @override
  String get documentsCategoryRequired => 'Selecciona una categoría';

  @override
  String get documentsReplaceFileOptional => 'Reemplazar archivo (opcional)';

  @override
  String get documentsSelectFile => 'Seleccionar archivo';

  @override
  String get documentsUnknownFile => 'Archivo desconocido';

  @override
  String get documentsChangeFile => 'Cambiar archivo';

  @override
  String get documentsTapToSelect => 'Toca para seleccionar un archivo';

  @override
  String get documentsSupportedFileTypes => 'PDF, DOCX, imágenes o video';

  @override
  String documentsPickFileError(String error) {
    return 'Error al seleccionar el archivo: $error';
  }

  @override
  String get documentsFillRequiredFields =>
      'Completa todos los campos obligatorios';

  @override
  String get documentsSelectFileRequired => 'Selecciona un archivo';

  @override
  String get documentsMissingOrgId =>
      'Falta el ID de la organización. No se puede cargar el documento.';

  @override
  String get documentsUserNotAuthenticated =>
      'Usuario no autenticado. Vuelve a iniciar sesión.';

  @override
  String get documentsFileDataUnavailable =>
      'Los datos del archivo no están disponibles. Vuelve a seleccionar el archivo.';

  @override
  String get documentsUpdatedSuccess => '¡Documento actualizado correctamente!';

  @override
  String get documentsUploadedSuccess => '¡Documento cargado correctamente!';

  @override
  String get documentsUploadFailedPrefix => 'Error al cargar: ';

  @override
  String get documentsUploadFailedMissingData =>
      'Faltan datos obligatorios. Intenta seleccionar el archivo nuevamente.';

  @override
  String get documentsUploadFailedPermission =>
      'Permiso denegado. Revisa los permisos de tu cuenta.';

  @override
  String get documentsUploadFailedStorage =>
      'Error de almacenamiento. Revisa tu conexión a internet.';

  @override
  String get documentsDismissTip => 'Cerrar';

  @override
  String get scheduleEditorTitle => 'Editor de horarios';

  @override
  String get scheduleMyTitle => 'Mi horario';

  @override
  String get scheduleOrganizationNotFound => 'Organización no encontrada';

  @override
  String get scheduleOrganizationLocationMissing =>
      'Falta la organización o la ubicación.';

  @override
  String get scheduleLocationLabel => 'Ubicación';

  @override
  String get schedulePickDateRange => 'Elige un rango de fechas';

  @override
  String get scheduleSelectDateRange => 'Seleccionar rango de fechas';

  @override
  String get scheduleNext7Days => 'Próximos 7 días';

  @override
  String scheduleDaysWindow(int start, int end) {
    return 'Días $start-$end';
  }

  @override
  String get scheduleSelectLocationAndDateRange =>
      'Selecciona una ubicación y un rango de fechas para ver el horario';

  @override
  String get schedulePublishSchedule => 'Publicar horario';

  @override
  String get scheduleCreateTemplateFirst =>
      'Primero crea una plantilla de turno desde el panel de administración';

  @override
  String get schedulePublishAllSuccess =>
      '¡Todos los horarios se publicaron correctamente!';

  @override
  String schedulePublishError(String error) {
    return 'Error al publicar los horarios: $error';
  }

  @override
  String scheduleDayPublished(String date) {
    return '¡Horario de $date publicado!';
  }

  @override
  String scheduleDayPublishError(String error) {
    return 'Error al publicar el horario: $error';
  }

  @override
  String get scheduleNoPublishedShifts => 'No hay turnos publicados.';

  @override
  String scheduleAssignedCount(int count) {
    return 'Asignados: $count';
  }

  @override
  String scheduleUsersLabel(String users) {
    return 'Usuarios: $users';
  }

  @override
  String get scheduleAssignedStatus => 'Asignado';

  @override
  String get scheduleShiftsHeader => 'Turnos';

  @override
  String get scheduleAssignedCell => 'asignados';

  @override
  String scheduleShiftTemplatesError(String error) {
    return 'Error al cargar los turnos: $error';
  }

  @override
  String get scheduleNoShiftTemplates =>
      'No se encontraron plantillas de turnos para esta ubicación.\nPrimero crea plantillas de turnos desde el panel de administración.';

  @override
  String get scheduleUnnamedShift => 'Turno sin nombre';

  @override
  String scheduleMessageTitle(String start, String end) {
    return 'Tu horario $start a $end';
  }

  @override
  String scheduleMessageLine(
    String date,
    String shiftName,
    String startTime,
    String endTime,
  ) {
    return '$date: $shiftName ($startTime - $endTime)';
  }

  @override
  String get dashboardSwitch => 'Cambiar';

  @override
  String dashboardLocationsCount(int count) {
    return '$count ubicaciones';
  }

  @override
  String get dashboardNoActiveShift => 'Sin turno activo';

  @override
  String get dashboardNothingAssignedTitle =>
      'No hay nada asignado ahora mismo';

  @override
  String dashboardNothingAssignedBody(String locationName) {
    return 'Estás configurado para trabajar en $locationName. Toma un turno disponible cuando estés listo.';
  }

  @override
  String get dashboardSeeAvailableShifts => 'Ver turnos disponibles';

  @override
  String get dashboardNoVisibleShiftTitle =>
      'No hay un turno visible en este momento';

  @override
  String get dashboardNoVisibleShiftBody =>
      'Tus turnos asignados pueden haber terminado, o tu próximo turno aún no está disponible para comenzar.';

  @override
  String get dashboardMomentumBody =>
      'Mantén el ritmo cuando el trabajo asignado de hoy esté en buen estado.';

  @override
  String get dashboardLoadingTasks => 'Cargando las tareas de hoy...';

  @override
  String get dashboardNoTasksForShift =>
      'Todavía no hay tareas disponibles para este turno.';

  @override
  String get dashboardEverythingCompleteShift =>
      'Todo para este turno está completo.';

  @override
  String dashboardTasksLeftShort(int count) {
    return '$count pendientes';
  }

  @override
  String dashboardBlockedShort(int count) {
    return '$count bloqueadas';
  }

  @override
  String dashboardNeedPhotosShort(int count) {
    return '$count necesitan fotos';
  }

  @override
  String get dashboardProgress => 'Progreso';

  @override
  String get dashboardWaitingForTasks => 'Esperando tareas';

  @override
  String dashboardCompletedOfTotal(int completed, int total) {
    return '$completed de $total hechas';
  }

  @override
  String get dashboardRemaining => 'Pendientes';

  @override
  String get dashboardTasksLeftInShift => 'Tareas pendientes en este turno';

  @override
  String get dashboardAttention => 'Atención';

  @override
  String get dashboardPhotos => 'Fotos';

  @override
  String get dashboardBlockedOrFlagged => 'Bloqueadas o marcadas';

  @override
  String get dashboardNeedPhotoProof => 'Necesitan prueba fotográfica';

  @override
  String get dashboardReviewTodaysWork => 'Revisar el trabajo de hoy';

  @override
  String get dashboardContinueWorking => 'Seguir trabajando';

  @override
  String get dashboardViewFullShift => 'Ver turno completo';

  @override
  String get dashboardNextUp => 'Siguiente';

  @override
  String get dashboardNoRemainingTasks =>
      'No quedan tareas en este turno ahora mismo.';

  @override
  String get dashboardFastestPath =>
      'La ruta más rápida para terminar este turno.';

  @override
  String get dashboardNextUpHelpSubtitle =>
      'Siguiente muestra la ruta más rápida a través de las tareas sin terminar de tu turno actual.';

  @override
  String dashboardQueuedCount(int count) {
    return '$count en cola';
  }

  @override
  String get dashboardNoTasksAvailableYet =>
      'Todavía no hay tareas disponibles';

  @override
  String get dashboardCaughtUp => 'Estás al día en este turno';

  @override
  String get dashboardCheckChecklistSetup =>
      'Si esto parece incorrecto, pídele a tu gerente que revise la configuración de la lista de este turno.';

  @override
  String get dashboardReviewCompletedOrPickShift =>
      'Usa la sección de abajo para revisar el trabajo completado o tomar otro turno.';

  @override
  String get dashboardCurrentShift => 'Turno actual';

  @override
  String get dashboardLeaveShift => 'Salir del turno';

  @override
  String dashboardPendingTasksRemaining(int count) {
    return '$count pendientes';
  }

  @override
  String dashboardListsCount(int count) {
    return '$count listas';
  }

  @override
  String get dashboardNoTasksAvailableForShift =>
      'No hay tareas disponibles para este turno';

  @override
  String get dashboardAskManagerVerifyChecklist =>
      'Si esto parece incorrecto, pídele a tu gerente que verifique la configuración de la lista de hoy.';

  @override
  String get dashboardChecklistFallback => 'Lista';

  @override
  String get dashboardChecklistTasksLoading =>
      'Las tareas se están cargando para esta lista';

  @override
  String dashboardChecklistCompletedOfTotal(int completed, int total) {
    return '$completed de $total tareas completas';
  }

  @override
  String dashboardNeedPhotoChip(int count) {
    return '$count necesitan foto';
  }

  @override
  String get dashboardEverythingHereComplete => 'Todo aquí está completo';

  @override
  String get dashboardCompletedBelow =>
      'El trabajo completado está abajo para una revisión rápida.';

  @override
  String dashboardHideCompleted(int count) {
    return 'Ocultar completadas ($count)';
  }

  @override
  String dashboardShowCompleted(int count) {
    return 'Mostrar completadas ($count)';
  }

  @override
  String dashboardNeedsAttention(String reason) {
    return 'Necesita atención: $reason';
  }

  @override
  String get dashboardPhotoRequiredBeforeSignoff =>
      'Se requiere foto antes de finalizar';

  @override
  String get dashboardReadyToComplete => 'Listo para completar';

  @override
  String get dashboardMustBeLoggedIn =>
      'Debes iniciar sesión para completar tareas';

  @override
  String get dashboardPhotoRequiredTitle => 'Se requiere foto';

  @override
  String get dashboardPhotoRequiredBody =>
      'Esta tarea requiere una foto. Agrega una foto ahora, completa sin foto o cancela.';

  @override
  String get dashboardCompleteWithoutPhoto => 'Completar sin foto';

  @override
  String get dashboardAddPhoto => 'Agregar foto';

  @override
  String get dashboardAddNoteRequiredTitle => 'Agregar nota (obligatoria)';

  @override
  String get dashboardAddNoteRequiredBody =>
      'Agrega una nota breve explicando por qué no se añadió una foto.';

  @override
  String get dashboardEnterNote => 'Ingresa una nota...';

  @override
  String get dashboardSave => 'Guardar';

  @override
  String get dashboardTaskCompleted => '¡Tarea completada!';

  @override
  String get dashboardTaskUnchecked => 'Tarea desmarcada';

  @override
  String get dashboardTaskUpdateError =>
      'Error al actualizar la tarea. Inténtalo de nuevo.';

  @override
  String get dashboardCompleted => 'Completada';

  @override
  String dashboardCompletedBy(String name) {
    return 'Completada por $name';
  }

  @override
  String get dashboardPhotoAdded => 'Foto agregada';

  @override
  String get dashboardPhotoRequiredChip => 'Foto obligatoria';

  @override
  String get dashboardNoteAdded => 'Nota agregada';

  @override
  String get dashboardBlocked => 'Bloqueada';

  @override
  String get dashboardPhotoMenu => 'Foto';

  @override
  String get dashboardNotesMenu => 'Notas';

  @override
  String get dashboardCannotComplete => 'No se puede completar';

  @override
  String get dashboardMarkIncomplete => 'Marcar incompleta';

  @override
  String get dashboardComplete => 'Completar';

  @override
  String get dashboardViewPhoto => 'Ver foto';

  @override
  String get dashboardUpdateIssue => 'Actualizar problema';

  @override
  String get dashboardCantDo => 'No puedo';

  @override
  String get dashboardEditNote => 'Editar nota';

  @override
  String get dashboardAddNote => 'Agregar nota';

  @override
  String get dashboardSwitchLocationTitle => 'Cambiar ubicación';

  @override
  String get dashboardSwitchLocationBody =>
      'Elige dónde quieres ver y completar el trabajo.';

  @override
  String get dashboardUnnamedLocation => 'Ubicación sin nombre';

  @override
  String get dashboardCurrentlySelectedLocation => 'Seleccionada actualmente';

  @override
  String get dashboardSwitchLocationError =>
      'No se pudieron cambiar las ubicaciones. Inténtalo de nuevo.';

  @override
  String get dashboardMissedTaskNotCompletedYesterday => 'No se completó ayer';

  @override
  String get dashboardNoteChip => 'Nota';

  @override
  String get dashboardReasonChip => 'Motivo';

  @override
  String get dashboardClearNotes => 'Borrar notas';

  @override
  String get dashboardClearReason => 'Borrar motivo';

  @override
  String dashboardAlreadySignedUpForShift(String shiftName) {
    return 'Ya estás apuntado a $shiftName.';
  }

  @override
  String dashboardJoinedShift(String shiftName) {
    return '¡Te uniste correctamente a $shiftName!';
  }

  @override
  String get dashboardJoinShiftError =>
      'Error al unirte al turno. Inténtalo de nuevo.';

  @override
  String get dashboardMustBeLoggedInToLeaveShift =>
      'Debes iniciar sesión para salir de los turnos';

  @override
  String get dashboardLeaveVolunteerShiftTitle => 'Salir del turno voluntario';

  @override
  String dashboardLeaveVolunteerShiftBody(String shiftName) {
    return '¿Seguro que quieres salir del turno voluntario \"$shiftName\"? Esto te quitará de futuras asignaciones para este turno.';
  }

  @override
  String get dashboardLeaveShiftConfirm => 'Salir del turno';

  @override
  String get dashboardLeftVolunteerShift =>
      '¡Saliste correctamente del turno voluntario!';

  @override
  String get dashboardLeaveShiftError =>
      'Error al salir del turno. Inténtalo de nuevo.';

  @override
  String get dashboardAvailableShiftsTitle => 'Turnos disponibles';

  @override
  String dashboardAvailableShiftsSubtitle(String locationName) {
    return 'Selecciona un turno para comenzar a trabajar en $locationName';
  }

  @override
  String get dashboardAvailableShiftsLoadError => 'Error al cargar los turnos';

  @override
  String get dashboardNoAvailableShiftsTitle => 'No hay turnos disponibles';

  @override
  String get dashboardNoAvailableShiftsBody =>
      'No hay turnos disponibles para que te unas hoy.';

  @override
  String get dashboardNoAvailableShiftsTiming =>
      'Los turnos estarán disponibles para seleccionar 30 minutos antes de su hora de inicio.';

  @override
  String get dashboardJoin => 'Unirse';

  @override
  String get dashboardTaskNotesTitle => 'Notas de la tarea';

  @override
  String dashboardTaskLabel(String taskName) {
    return 'Tarea: $taskName';
  }

  @override
  String get dashboardUnknownTask => 'Tarea desconocida';

  @override
  String get dashboardTaskNotesPrompt =>
      'Agrega notas o comentarios sobre esta tarea:';

  @override
  String get dashboardNotesSaved => '¡Notas guardadas correctamente!';

  @override
  String dashboardNotesSaveError(String error) {
    return 'Error al guardar las notas: $error';
  }

  @override
  String get dashboardNotesCleared => 'Notas borradas';

  @override
  String dashboardNotesClearError(String error) {
    return 'No se pudieron borrar las notas: $error';
  }

  @override
  String get dashboardSaveNotes => 'Guardar notas';

  @override
  String get dashboardEnterNotesHint => 'Escribe tus notas aquí...';

  @override
  String get dashboardSavingNotes => 'Guardando notas...';

  @override
  String get dashboardPhotoViewerResetZoom => 'Restablecer zoom';

  @override
  String get dashboardPhotoViewerLoadingImage => 'Cargando imagen...';

  @override
  String get dashboardPhotoViewerLoadError => 'No se pudo cargar la imagen';

  @override
  String get dashboardPhotoViewerGestureHint =>
      'Pellizca para acercar • Arrastra para mover • Toca restablecer para ajustar';

  @override
  String get dashboardReasonEquipmentUnavailable => 'Equipo no disponible';

  @override
  String get dashboardReasonSuppliesMissing => 'Faltan suministros';

  @override
  String get dashboardReasonNotEnoughTime => 'No hubo tiempo suficiente';

  @override
  String get dashboardReasonSafetyConcern => 'Problema de seguridad';

  @override
  String get dashboardReasonWaitingApproval => 'Esperando aprobación';

  @override
  String get dashboardReasonAreaBlocked => 'Área bloqueada o inaccesible';

  @override
  String get dashboardReasonTechnicalIssue => 'Problema técnico';

  @override
  String get dashboardReasonStaffShortage => 'Falta de personal';

  @override
  String get dashboardReasonEmergencyPriority =>
      'Tarea prioritaria por emergencia';

  @override
  String get dashboardReasonWeatherConditions => 'Condiciones climáticas';

  @override
  String get dashboardReasonOther => 'Otro (especifica abajo)';

  @override
  String get dashboardReasonSpecifyText =>
      'Especifica un motivo en el campo de texto';

  @override
  String get dashboardReasonSelectOrEnter => 'Selecciona o escribe un motivo';

  @override
  String get dashboardReasonSaved => '¡Motivo guardado correctamente!';

  @override
  String dashboardReasonSaveError(String error) {
    return 'Error al guardar el motivo: $error';
  }

  @override
  String get dashboardTaskNotCompletedTitle => 'Tarea no completada';

  @override
  String get dashboardSaveReason => 'Guardar motivo';

  @override
  String get dashboardTaskNotCompletedPrompt =>
      '¿Por qué no se completó esta tarea?';

  @override
  String get dashboardEnterReasonHint => 'Especifica el motivo...';

  @override
  String get dashboardSavingReason => 'Guardando motivo...';

  @override
  String get dashboardLoadingCarryover => 'Cargando pendientes acumuladas...';

  @override
  String get dashboardCurrentLocationLabel => 'Ubicación actual';

  @override
  String get dashboardWorkingLocationLabel => 'Ubicación de trabajo';

  @override
  String get dashboardLocationHelpTitle => 'Ayuda sobre ubicaciones';

  @override
  String get dashboardLocationHelpSubtitle =>
      'La ubicación activa controla qué turnos, tareas y documentos ves en esta página.';

  @override
  String get dashboardSharedModeTitle => 'Modo compartido';

  @override
  String get dashboardSharedModeLocked =>
      'Bloqueado: selecciona tu nombre para continuar';

  @override
  String dashboardSharedModeActive(String userName) {
    return 'Activo: $userName';
  }

  @override
  String get dashboardCarryoverClearTitle => 'No hay pendientes acumuladas';

  @override
  String get dashboardCarryoverClearBody => 'No hubo tareas omitidas ayer.';

  @override
  String get dashboardCarryoverTitle => 'Pendientes acumuladas de ayer';

  @override
  String get dashboardCarryoverHelpTitle => 'Pendientes acumuladas de ayer';

  @override
  String get dashboardCarryoverHelpSubtitle =>
      'Las pendientes acumuladas mantienen visible el trabajo sin terminar para que pueda completarse o bloquearse con contexto en vez de desaparecer.';

  @override
  String dashboardTasksCompletedCount(int completed, int total) {
    return '$completed de $total tareas completadas';
  }

  @override
  String dashboardShiftTaskSummary(int shiftCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      shiftCount,
      locale: localeName,
      other: 'turnos',
      one: 'turno',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: 'tareas',
      one: 'tarea',
    );
    return '$shiftCount $_temp0 • $taskCount $_temp1';
  }

  @override
  String get dashboardUnknownShift => 'Turno desconocido';

  @override
  String get dashboardShiftTimingScheduled => 'Programado';

  @override
  String get dashboardShiftTimingCheckDetails =>
      'Revisa los detalles del horario';

  @override
  String get dashboardShiftTimingStartsSoon => 'Comienza pronto';

  @override
  String get dashboardShiftTimingAvailableNow => 'Disponible ahora';

  @override
  String dashboardShiftTimingAvailableInMinutes(int minutes) {
    return 'Disponible en $minutes min';
  }

  @override
  String get dashboardShiftTimingInProgress => 'En curso';

  @override
  String dashboardShiftTimingHoursLeft(int hours) {
    return 'Quedan $hours h';
  }

  @override
  String dashboardShiftTimingMinutesLeft(int minutes) {
    return 'Quedan $minutes min';
  }

  @override
  String get dashboardShiftTimingGracePeriod => 'Período de gracia';

  @override
  String get dashboardShiftTimingJustEnded => 'El turno acaba de terminar';

  @override
  String dashboardShiftTimingEndedMinutesAgo(int minutes) {
    return 'Terminó hace $minutes min';
  }

  @override
  String get dashboardShiftTimingCheckCurrentWork => 'Revisa el trabajo actual';

  @override
  String get dashboardTourLocationTitle => 'Empieza con la ubicación activa';

  @override
  String get dashboardTourLocationDescription =>
      'Las tareas, los turnos, las pendientes acumuladas, los avisos y los documentos siguen la ubicación seleccionada. Cámbiala aquí antes de empezar a trabajar.';

  @override
  String get dashboardTourShiftLiveTitle =>
      'Primero revisa el resumen de tu turno';

  @override
  String get dashboardTourShiftIdleTitle =>
      'Aquí aparece el estado de tu turno';

  @override
  String get dashboardTourShiftLiveDescription =>
      'La tarjeta principal del turno te muestra en qué turno estás, cuánto trabajo queda y si algo está bloqueado o esperando evidencia.';

  @override
  String get dashboardTourShiftIdleDescription =>
      'Si todavía no tienes un turno activo, esta área te indica si debes esperar, tomar otro turno o pedirle a tu gerente que revise la configuración.';

  @override
  String get dashboardTourNextUpTitle =>
      'Usa Siguiente como tu cola principal de trabajo';

  @override
  String get dashboardTourNextUpDescription =>
      'Siguiente muestra la ruta más rápida por el trabajo pendiente para que no tengas que revisar manualmente cada lista.';

  @override
  String get dashboardTourTodaysWorkTitle =>
      'Revisa las listas completas en Trabajo de hoy';

  @override
  String get dashboardTourTodaysWorkDescription =>
      'Usa esta sección cuando necesites la vista completa de la lista de tu turno, las tareas completadas o más contexto que la cola principal.';

  @override
  String get commonAdd => 'Agregar';

  @override
  String get managerDashboardActiveShifts => 'Turnos activos';

  @override
  String get managerDashboardActiveShiftLiveNowOne => '1 turno activo ahora';

  @override
  String managerDashboardActiveShiftLiveNowOther(int count) {
    return '$count turnos activos ahora';
  }

  @override
  String get managerDashboardAtRisk => 'En riesgo';

  @override
  String get managerDashboardNoShiftsSlipping => 'No hay turnos desviándose';

  @override
  String get managerDashboardNeedInterventionNow =>
      'Necesita intervención ahora';

  @override
  String get managerDashboardOpenTasks => 'Tareas abiertas';

  @override
  String get managerDashboardNoTrackedTasksYet =>
      'Aún no hay tareas rastreadas';

  @override
  String managerDashboardCompletedTracked(int completed, int total) {
    return '$completed/$total completadas';
  }

  @override
  String get managerDashboardCarryover => 'Pendientes acumuladas';

  @override
  String get managerDashboardYesterdayFinishedCleanly =>
      'Ayer terminó sin pendientes';

  @override
  String managerDashboardShiftsAffected(int count) {
    return '$count turnos afectados';
  }

  @override
  String get managerDashboardTourSummaryTitle =>
      'Empieza por la tarjeta de resumen';

  @override
  String get managerDashboardTourSummaryDescription =>
      'Esta tarjeta superior te muestra si el servicio va bien, cuántos turnos están en riesgo y qué necesita tu atención ahora mismo.';

  @override
  String get managerDashboardTourIssuesTitle =>
      'Usa En riesgo hoy como tu cola de acción';

  @override
  String get managerDashboardTourIssuesDescription =>
      'Abre primero estos problemas cuando algo se retrasa. Te ayudan a priorizar trabajo pendiente, riesgos en vivo y el siguiente seguimiento.';

  @override
  String get managerDashboardTourReadinessTitle =>
      'Estado del turno muestra el tablero en vivo';

  @override
  String get managerDashboardTourReadinessDescription =>
      'Usa esta sección para revisar trabajo abierto, progreso del turno y qué ejecuciones van bien o se están quedando atrás.';

  @override
  String get managerDashboardCurrentLocation => 'Ubicación actual';

  @override
  String get managerDashboardLoading => 'Cargando panel';

  @override
  String managerDashboardIssuesNeedAttention(int count) {
    return '$count problemas necesitan atención';
  }

  @override
  String get managerDashboardTodayOnTrack => 'Hoy va por buen camino';

  @override
  String managerDashboardLoadingSummary(String locationName) {
    return 'Cargando los turnos de hoy, el trabajo pendiente y las señales de problemas recurrentes para $locationName.';
  }

  @override
  String get managerDashboardThisLocation => 'esta ubicación';

  @override
  String managerDashboardIssuesSummary(int riskCount, int openTaskCount) {
    return '$riskCount turnos están actualmente en riesgo y $openTaskCount tareas abiertas aún necesitan atención del gerente.';
  }

  @override
  String get managerDashboardNoLiveShiftsSummary =>
      'Ningún turno en vivo está desviado en este momento. Usa el panel de abajo para revisar el estado y los problemas recurrentes.';

  @override
  String get managerDashboardRefreshNow => 'Actualizar ahora';

  @override
  String get managerDashboardReviewIssues => 'Revisar problemas';

  @override
  String get managerDashboardViewShiftReadiness => 'Ver estado del turno';

  @override
  String get managerDashboardHistoryReports => 'Historial e informes';

  @override
  String get managerDashboardTodayAtRisk => 'En riesgo hoy';

  @override
  String get managerDashboardTodayAtRiskSubtitle =>
      'Cola de acción compacta para lo que necesita atención primero.';

  @override
  String get managerDashboardShiftReadiness => 'Estado del turno';

  @override
  String get managerDashboardShiftReadinessSubtitle =>
      'Tablero en vivo de progreso, trabajo abierto y salud del turno.';

  @override
  String get managerDashboardNoScheduledShiftsYet =>
      'Aún no hay turnos programados';

  @override
  String get managerDashboardNoScheduledShiftsBody =>
      'Crea y ejecuta turnos para ver aquí el estado.';

  @override
  String get managerDashboardRecurringIssues => 'Problemas recurrentes';

  @override
  String get managerDashboardRecurringIssuesSubtitle =>
      'Donde los fallos y ejecuciones débiles siguen apareciendo.';

  @override
  String get managerDashboardRecurringFailures => 'Fallos recurrentes';

  @override
  String get managerDashboardRecurringFailuresSubtitle =>
      'Clasificados por tasa de fallos en los últimos 30 días.';

  @override
  String get managerDashboardNoRecurringFailuresYet =>
      'Aún no hay fallos recurrentes.';

  @override
  String get managerDashboardAtRiskShifts => 'Turnos en riesgo';

  @override
  String get managerDashboardAtRiskShiftsSubtitle =>
      'Turnos con las tendencias de finalización más débiles en los últimos 30 días.';

  @override
  String get managerDashboardNoAtRiskShifts =>
      'No se encontraron turnos en riesgo.';

  @override
  String get managerDashboardAllMissedTasksYesterday =>
      'Todas las tareas omitidas ayer';

  @override
  String get managerDashboardUnknownTask => 'Tarea desconocida';

  @override
  String get managerDashboardUnknownShift => 'Turno desconocido';

  @override
  String get managerDashboardDoneToday => 'Hecho hoy';

  @override
  String get adminSetupTourWelcomeTitle => 'Te mostramos lo nuevo';

  @override
  String get adminSetupTourWelcomeDescription =>
      'La configuración se actualizó para que ubicaciones, equipo, turnos y plantillas de listas sean más fáciles de administrar. Este recorrido rápido te mostrará el flujo actualizado antes de empezar a editar.';

  @override
  String get adminSetupTourLocationTitle =>
      'Mantén la configuración enfocada en una ubicación';

  @override
  String get adminSetupTourLocationDescription =>
      'Cambia aquí cuando quieras concentrarte en un restaurante. Los turnos, el acceso del equipo y las plantillas de listas son más fáciles de administrar cuando reduces el alcance a una ubicación.';

  @override
  String get adminSetupTourAreasTitle =>
      'Muévete por la configuración por áreas';

  @override
  String get adminSetupTourAreasDescription =>
      'Usa estas áreas rápidas de configuración para saltar entre Ubicaciones, Equipo, Turnos y Biblioteca de listas sin perder tu lugar.';

  @override
  String get adminSetupTourPanelTitle => 'Trabaja en una sola área a la vez';

  @override
  String get adminSetupTourPanelDescription =>
      'El panel principal de abajo es donde agregas, editas y revisas el área de configuración actual. Mantén sincronizadas la ubicación seleccionada y el área de configuración mientras configuras la operación.';

  @override
  String get adminSetupActiveLocation => 'Ubicación activa';

  @override
  String get adminSetupSelectLocation => 'Seleccionar ubicación';

  @override
  String get adminSetupAreas => 'Áreas de configuración';

  @override
  String get adminViewLocations => 'Ubicaciones';

  @override
  String get adminViewTeam => 'Equipo';

  @override
  String get adminViewShifts => 'Turnos';

  @override
  String get adminViewChecklistLibrary => 'Biblioteca de listas';

  @override
  String get adminViewEyebrowPlaces => 'Lugares';

  @override
  String get adminViewEyebrowPeople => 'Personas';

  @override
  String get adminViewEyebrowOperations => 'Operaciones';

  @override
  String get adminViewEyebrowChecklistTemplates => 'Plantillas de listas';

  @override
  String get adminViewLocationsSubtitle =>
      'Administra los lugares desde donde opera tu equipo y mantén la configuración anclada a ubicaciones reales.';

  @override
  String get adminViewTeamSubtitle =>
      'Invita al personal, asigna accesos y mantén cada rol alineado con las ubicaciones correctas.';

  @override
  String get adminViewShiftsSubtitle =>
      'Define cuándo sucede el trabajo y adjunta el flujo correcto a cada turno.';

  @override
  String get adminViewChecklistLibrarySubtitle =>
      'Mantén plantillas reutilizables para apertura, cierre, preparación y rutinas repetibles.';

  @override
  String get adminSetupHeroTitle => 'Configuración operativa';

  @override
  String get adminSetupAllLocations => 'Todas las ubicaciones';

  @override
  String get adminWorkflowNoneAttached => 'Aún no hay un flujo adjunto';

  @override
  String get adminWorkflowOneAttached => '1 flujo adjunto';

  @override
  String adminWorkflowManyAttached(int count) {
    return '$count flujos adjuntos';
  }

  @override
  String adminWorkflowTitle(String name) {
    return 'Flujo de $name';
  }

  @override
  String get adminNoOrganizationDataAvailable =>
      'No hay datos de la organización disponibles';

  @override
  String adminErrorLoadingUsers(String error) {
    return 'Error al cargar usuarios: $error';
  }

  @override
  String adminErrorLoadingLocations(String error) {
    return 'Error al cargar ubicaciones: $error';
  }

  @override
  String get adminNoTeamMembersFound => 'No se encontraron miembros del equipo';

  @override
  String get adminInviteTeamToGetStarted => 'Invita a tu equipo para comenzar';

  @override
  String get adminUnnamedUser => 'Usuario sin nombre';

  @override
  String get adminDeleteUserTitle => 'Eliminar usuario';

  @override
  String get adminDeleteUserBody =>
      '¿Seguro que quieres eliminar este usuario? Esta acción no se puede deshacer.';

  @override
  String get adminNoLocationsFound => 'No se encontraron ubicaciones';

  @override
  String get adminAddLocationToGetStarted =>
      'Agrega una ubicación para comenzar';

  @override
  String get adminNoShiftsForSelectedLocation =>
      'No se encontraron turnos para la ubicación seleccionada';

  @override
  String get adminNoShiftsFound => 'No se encontraron turnos';

  @override
  String get adminCreateShiftsAttachWorkflows =>
      'Crea turnos y luego adjunta los flujos de trabajo';

  @override
  String get webAdminWorkflowLabel => 'Flujo';

  @override
  String get webAdminWorkflowCreated => 'Flujo creado correctamente';

  @override
  String get webAdminScheduleDaily => 'Diario';

  @override
  String get webAdminDayMon => 'Lun';

  @override
  String get webAdminDayTue => 'Mar';

  @override
  String get webAdminDayWed => 'Mié';

  @override
  String get webAdminDayThu => 'Jue';

  @override
  String get webAdminDayFri => 'Vie';

  @override
  String get webAdminDaySat => 'Sáb';

  @override
  String get webAdminDaySun => 'Dom';

  @override
  String get webAdminSidebarSubtitle =>
      'Configura lugares, personas, turnos y flujos reutilizables.';

  @override
  String get webAdminSetupWorkspace => 'Espacio de configuración';

  @override
  String get webAdminScope => 'Alcance';

  @override
  String get webAdminAllActive => 'Todos los activos';

  @override
  String webAdminSearchHint(String name) {
    return 'Buscar $name...';
  }

  @override
  String webAdminAddItem(String name) {
    return 'Agregar $name';
  }

  @override
  String get webAdminSectionEyebrowShifts => 'Configuración operativa';

  @override
  String get webAdminSectionEyebrowChecklists => 'Plantillas de listas';

  @override
  String get webAdminSectionEyebrowUsers => 'Personas y acceso';

  @override
  String get webAdminSectionEyebrowLocations => 'Huella operativa';

  @override
  String get webAdminSectionTitleShifts =>
      'Construye turnos alrededor de flujos reales de servicio';

  @override
  String get webAdminSectionTitleChecklists =>
      'Mantén una biblioteca limpia de flujos';

  @override
  String get webAdminSectionTitleUsers =>
      'Administra tu equipo con menos fricción';

  @override
  String get webAdminSectionTitleLocations =>
      'Mantén cada ubicación lista para operar';

  @override
  String get webAdminSectionSubtitleShifts =>
      'Define cuándo ocurre el trabajo, a quién pertenece y qué plantilla de flujo se ejecuta en ese turno.';

  @override
  String get webAdminSectionSubtitleChecklists =>
      'Crea plantillas reutilizables para apertura, cierre, preparación y procedimientos recurrentes en toda tu operación.';

  @override
  String get webAdminSectionSubtitleUsers =>
      'Invita a gerentes y personal, asigna sus ubicaciones y mantén el acceso alineado con la forma en que opera el negocio.';

  @override
  String get webAdminSectionSubtitleLocations =>
      'Configura los lugares desde donde opera tu equipo y úsalos para organizar turnos, personal y cobertura de flujos.';

  @override
  String get webAdminSectionTableSubtitleShifts =>
      'Configuración centrada en turnos con visibilidad directa del flujo.';

  @override
  String get webAdminSectionTableSubtitleChecklists =>
      'Las plantillas siguen siendo reutilizables aquí y se adjuntan desde los turnos.';

  @override
  String get webAdminSectionTableSubtitleUsers =>
      'Personas, roles, estado de invitación y cobertura por ubicación.';

  @override
  String get webAdminSectionTableSubtitleLocations =>
      'Tus lugares activos, direcciones y huella operativa.';

  @override
  String get webAdminTabShift => 'turno';

  @override
  String get webAdminTabTemplate => 'plantilla';

  @override
  String get webAdminTabTeamMember => 'miembro del equipo';

  @override
  String get webAdminTabLocation => 'ubicación';

  @override
  String get webAdminEmptyTitleShifts => 'Aún no hay turnos creados';

  @override
  String get webAdminEmptyDescriptionShifts =>
      'Crea tu primer turno para definir cuándo ocurre el trabajo, quién lo realiza y qué flujo debe ejecutarse. Los turnos son el lugar principal para configurar la operación.';

  @override
  String get webAdminEmptyActionShifts => 'Crear el primer turno';

  @override
  String get webAdminEmptySupportLabelShifts => 'Siguiente paso';

  @override
  String get webAdminEmptySupportValueShifts => 'Adjuntar flujo';

  @override
  String get webAdminEmptySecondaryLabelShifts => 'Recomendado';

  @override
  String get webAdminEmptySecondaryValueShifts => 'Empieza con apertura';

  @override
  String get webAdminEmptyTitleChecklists => 'Aún no hay plantillas de listas';

  @override
  String get webAdminEmptyDescriptionChecklists =>
      'Crea plantillas reutilizables para apertura, cierre, preparación y otro trabajo repetible. La mayoría de los propietarios las adjuntarán desde la pantalla de turnos.';

  @override
  String get webAdminEmptyActionChecklists => 'Crear la primera plantilla';

  @override
  String get webAdminEmptySupportLabelChecklists => 'Mejor uso';

  @override
  String get webAdminEmptySupportValueChecklists => 'Flujos reutilizables';

  @override
  String get webAdminEmptySecondaryLabelChecklists => 'Lo más común';

  @override
  String get webAdminEmptySecondaryValueChecklists => 'Apertura + cierre';

  @override
  String get webAdminEmptyTitleUsers => 'Aún no hay miembros del equipo';

  @override
  String get webAdminEmptyDescriptionUsers =>
      'Invita a miembros del equipo a unirse a tu organización. Puedes asignar distintos roles y controlar a qué ubicaciones pueden acceder.';

  @override
  String get webAdminEmptyActionUsers => 'Agregar el primer miembro';

  @override
  String get webAdminEmptySupportLabelUsers => 'Más útil';

  @override
  String get webAdminEmptySupportValueUsers => 'Invita primero a gerentes';

  @override
  String get webAdminEmptySecondaryLabelUsers => 'Estado';

  @override
  String get webAdminEmptySecondaryValueUsers => 'Sigue las invitaciones aquí';

  @override
  String get webAdminEmptyTitleLocations => 'Aún no hay ubicaciones agregadas';

  @override
  String get webAdminEmptyDescriptionLocations =>
      'Configura las ubicaciones de tu negocio para organizar turnos, asignar personal y seguir la operación. Cada ubicación puede tener sus propios turnos, listas y miembros del equipo.';

  @override
  String get webAdminEmptyActionLocations => 'Agregar la primera ubicación';

  @override
  String get webAdminEmptySupportLabelLocations => 'Base';

  @override
  String get webAdminEmptySupportValueLocations =>
      'Construye la configuración alrededor de los lugares';

  @override
  String get webAdminEmptySecondaryLabelLocations => 'Después de esto';

  @override
  String get webAdminEmptySecondaryValueLocations => 'Crear turnos';

  @override
  String get webAdminEmptyFooter =>
      'Mantén la configuración simple: crea la ubicación, agrega tu equipo y luego construye turnos con flujos adjuntos.';

  @override
  String get webAdminColumnShiftName => 'Nombre del turno';

  @override
  String get webAdminColumnTime => 'Hora';

  @override
  String get webAdminColumnSchedule => 'Horario';

  @override
  String get webAdminColumnStatus => 'Estado';

  @override
  String get webAdminColumnActions => 'Acciones';

  @override
  String get webAdminColumnTemplateName => 'Nombre de la plantilla';

  @override
  String get webAdminColumnDescription => 'Descripción';

  @override
  String get webAdminColumnTasks => 'Tareas';

  @override
  String get webAdminColumnUsedInShifts => 'Usado en turnos';

  @override
  String get webAdminColumnLocationName => 'Nombre de la ubicación';

  @override
  String get webAdminColumnAddress => 'Dirección';

  @override
  String get webAdminStatusActive => 'Activo';

  @override
  String get webAdminStatusInactive => 'Inactivo';

  @override
  String get webAdminStatusArchived => 'Archivado';

  @override
  String get webAdminActionEdit => 'Editar';

  @override
  String get webAdminActionDuplicate => 'Duplicar';

  @override
  String get webAdminActionArchive => 'Archivar';

  @override
  String get webAdminActionRestore => 'Restaurar';

  @override
  String get webAdminActionCreateWorkflow => 'Crear flujo';

  @override
  String get webAdminActionEditWorkflow => 'Editar flujo';

  @override
  String get webAdminActionDeactivate => 'Desactivar';

  @override
  String get webAdminActionActivate => 'Activar';

  @override
  String get webAdminActionDeleteUser => 'Eliminar usuario';

  @override
  String get webAdminNoDescription => 'Sin descripción';

  @override
  String webAdminTaskCount(int count) {
    return '$count tareas';
  }

  @override
  String get webAdminDeleteShiftTitle => '¿Eliminar turno?';

  @override
  String webAdminDeleteShiftBody(String name) {
    return '¿Seguro que quieres eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get webAdminShiftUpdated => 'Turno actualizado correctamente';

  @override
  String webAdminShiftUpdateFailed(String error) {
    return 'No se pudo actualizar el turno: $error';
  }

  @override
  String get webAdminChecklistUpdateFailed =>
      'No se pudo actualizar la plantilla';

  @override
  String get webAdminDeleteTemplateTitle => '¿Eliminar plantilla?';

  @override
  String webAdminDeleteTemplateBody(String name) {
    return '¿Seguro que quieres eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get webAdminTemplateDeleted => 'Plantilla eliminada correctamente';

  @override
  String webAdminTemplateDeleteFailed(String error) {
    return 'No se pudo eliminar la plantilla: $error';
  }

  @override
  String webAdminCopyName(String name) {
    return '$name (Copia)';
  }

  @override
  String get webAdminLocationDuplicated => 'Ubicación duplicada correctamente';

  @override
  String get webAdminDuplicateFailed => 'No se pudo duplicar el elemento';

  @override
  String get webAdminShiftCreated => 'Turno creado correctamente';

  @override
  String get webAdminShiftSaved => 'Turno actualizado correctamente';

  @override
  String get webAdminShiftEditorOpenFailed =>
      'No se pudo abrir el editor de turnos';

  @override
  String get webAdminShiftDuplicated => 'Turno duplicado correctamente';

  @override
  String webAdminShiftDuplicateFailed(String error) {
    return 'No se pudo duplicar el turno: $error';
  }

  @override
  String get webAdminShiftArchived => 'Turno archivado correctamente';

  @override
  String get webAdminShiftRestored => 'Turno restaurado correctamente';

  @override
  String get webAdminTemplateCreated => 'Plantilla creada correctamente';

  @override
  String get webAdminTemplateSaved => 'Plantilla actualizada correctamente';

  @override
  String webAdminTemplateSaveFailed(String error) {
    return 'No se pudo guardar la plantilla: $error';
  }

  @override
  String get webAdminTemplateEditorOpenFailed =>
      'No se pudo abrir el editor de plantillas';

  @override
  String get webAdminTemplateDuplicated => 'Plantilla duplicada correctamente';

  @override
  String webAdminTemplateDuplicateFailed(String error) {
    return 'No se pudo duplicar la plantilla: $error';
  }

  @override
  String get webAdminTemplateArchived => 'Plantilla archivada correctamente';

  @override
  String get webAdminTemplateRestored => 'Plantilla restaurada correctamente';

  @override
  String get webAdminUserDeactivated => 'Usuario desactivado correctamente';

  @override
  String get webAdminUserActivated => 'Usuario activado correctamente';

  @override
  String webAdminUserUpdateFailed(String error) {
    return 'No se pudo actualizar el usuario: $error';
  }

  @override
  String get webAdminLocationCreated => 'Ubicación creada correctamente';

  @override
  String get webAdminLocationSaved => 'Ubicación actualizada correctamente';

  @override
  String webAdminLocationUpdateFailed(String error) {
    return 'No se pudo actualizar la ubicación: $error';
  }

  @override
  String get webAdminLocationArchived => 'Ubicación archivada correctamente';

  @override
  String get webAdminLocationRestored => 'Ubicación restaurada correctamente';

  @override
  String get webAdminDeleteLocationTitle => '¿Eliminar ubicación?';

  @override
  String webAdminDeleteLocationBody(String name) {
    return '¿Seguro que quieres eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get webAdminLocationDeleted => 'Ubicación eliminada correctamente';

  @override
  String webAdminLocationDeleteFailed(String error) {
    return 'No se pudo eliminar la ubicación: $error';
  }

  @override
  String get webAdminDeleteUserTitle => '¿Eliminar usuario?';

  @override
  String webAdminDeleteUserBody(String name) {
    return '¿Seguro que quieres eliminar a \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get webAdminUserDeleted => 'Usuario eliminado correctamente';

  @override
  String webAdminUserDeleteFailed(String error) {
    return 'No se pudo eliminar el usuario: $error';
  }

  @override
  String webAdminWorkflowSuggestion(String name) {
    return 'flujo de $name';
  }

  @override
  String webAdminStreamError(String error) {
    return 'Error: $error';
  }

  @override
  String get webAdminUnnamedShift => 'Turno sin nombre';

  @override
  String get webAdminUnnamedTemplate => 'Plantilla sin nombre';

  @override
  String get webAdminUnnamedLocation => 'Ubicación sin nombre';

  @override
  String get webAdminUnknownUser => 'Usuario desconocido';

  @override
  String get webAdminNoEmail => 'Sin correo electrónico';

  @override
  String get webAdminNoAddress => 'Sin dirección';

  @override
  String guidedTourStepCounter(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get guidedTourSkip => 'Omitir';

  @override
  String get guidedTourLearnMore => 'Más información';

  @override
  String get guidedTourBack => 'Atrás';

  @override
  String get guidedTourNext => 'Siguiente';

  @override
  String get guidedTourDone => 'Listo';

  @override
  String get guidedTourLanguageFeatureTitle => 'Nuevo: soporte de idioma';

  @override
  String get guidedTourLanguageFeatureBody =>
      'Ahora puedes cambiar entre inglés, español y portugués en cualquier momento desde Idioma en Configuración.';

  @override
  String get releaseDialogUpdateTitle =>
      'Hay una actualización importante disponible';

  @override
  String get releaseDialogUpdateSubtitle =>
      'Actualiza o recarga para ver la experiencia más reciente, las opciones de idioma y el recorrido guiado.';

  @override
  String get releaseDialogWhatsNewSubtitle =>
      'Hay una experiencia renovada disponible, con actualizaciones del recorrido guiado y soporte de idioma.';

  @override
  String get releaseDialogNotNow => 'Ahora no';

  @override
  String get releaseDialogTakeGuidedTour => 'Iniciar recorrido guiado';

  @override
  String get releaseDialogRefreshNow => 'Recargar ahora';

  @override
  String get releaseDialogUpdateNow => 'Actualizar ahora';

  @override
  String get releaseDialogOkay => 'Entendido';

  @override
  String get releaseDialogMajorReleaseBadge => 'Versión importante';

  @override
  String get releaseDialogNewExperienceBadge => 'Nueva experiencia';

  @override
  String get releaseDialogWhatChanged => 'Qué cambió';

  @override
  String get releaseDialogLanguageFeatureTitle => 'Nuevo: soporte de idioma';

  @override
  String get releaseDialogLanguageFeatureBody =>
      'Ahora tienes inglés, español y portugués disponibles desde Idioma en Configuración.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get notificationsViewAction => 'View';

  @override
  String get quickPdfViewerDocumentTitle => 'Document';

  @override
  String get quickPdfViewerTrainingDocumentTitle => 'Training Document';

  @override
  String get quickPdfViewerDescription =>
      'This document will open in your device\'s native viewer for the best experience.';

  @override
  String get quickPdfViewerOpenDocument => 'Open Document';

  @override
  String get quickPdfViewerCopyLink => 'Copy Link';

  @override
  String get quickPdfViewerShare => 'Share';

  @override
  String get quickPdfViewerHelpBody =>
      'Documents open in your device\'s built-in viewer for optimal performance and feature support.';

  @override
  String get quickPdfViewerOpenFailed =>
      'Could not open document. Please check your internet connection.';

  @override
  String quickPdfViewerOpenError(String error) {
    return 'Error opening document: $error';
  }

  @override
  String get quickPdfViewerCopied => 'Document link copied to clipboard';

  @override
  String get quickPdfViewerShareFailed => 'Could not share document';

  @override
  String get notificationSettingsTitle => 'Configuración de notificaciones';

  @override
  String get notificationSettingsTestTooltip => 'Test Notifications';

  @override
  String get notificationPermissionTitle => 'Stay Updated with Hands';

  @override
  String get notificationPermissionBody =>
      'Get notified about schedule changes, shift reminders, and important announcements from your team.';

  @override
  String get notificationSettingsQuickActions => 'Quick Actions';

  @override
  String get notificationSettingsSubscribeTopics => 'Subscribe to Topics';

  @override
  String get notificationSettingsSystemSettings => 'System Settings';

  @override
  String get notificationSettingsTestTitle => 'Notification Setup Test';

  @override
  String notificationSettingsPermission(String value) {
    return 'Permission: $value';
  }

  @override
  String notificationSettingsToken(String value) {
    return 'Token: $value';
  }

  @override
  String notificationSettingsStatus(String value) {
    return 'Status: $value';
  }

  @override
  String get notificationSettingsNone => 'None';

  @override
  String get notificationSettingsReady => '✅ Ready';

  @override
  String get notificationSettingsNotReady => '❌ Not Ready';

  @override
  String get notificationOnboardingStayConnected => 'Mantente al tanto';

  @override
  String get notificationOnboardingBody =>
      'Get notified about:\n• Schedule updates\n• Shift reminders\n• Important announcements';

  @override
  String get notificationOnboardingEnableTitle => 'Activar notificaciones';

  @override
  String get notificationOnboardingEnableBody =>
      'We\'ll only send notifications that are relevant to your work schedule and important updates.';

  @override
  String get notificationOnboardingSkip => 'Skip for now';

  @override
  String get checklistSheetInfoLabel => 'Info';

  @override
  String get checklistSheetNewChecklist => 'New checklist';

  @override
  String get checklistSheetEditChecklist => 'Edit checklist';

  @override
  String get checklistSheetSaveChecklist => 'Save checklist';

  @override
  String get checklistSheetStepBasics => 'Basics';

  @override
  String get checklistSheetStepTasks => 'Tasks';

  @override
  String get checklistSheetStepAdvanced => 'Advanced';

  @override
  String get checklistSheetNameRequired => 'Checklist name is required.';

  @override
  String get checklistSheetAddOneTask => 'Please add at least one task.';

  @override
  String get checklistSheetAllTasksNamed => 'All tasks must have names.';

  @override
  String get checklistSheetInfoTipBasics =>
      'Name this workflow template and add a short description.';

  @override
  String get checklistSheetBasicsIntro =>
      'Enter the basic information for this template:';

  @override
  String get checklistSheetTemplateName => 'Template name *';

  @override
  String get checklistSheetTemplateNameHint =>
      'e.g., Opening Bar, Kitchen Close';

  @override
  String get checklistSheetDescriptionOptional => 'Description (optional)';

  @override
  String get checklistSheetDescriptionHint =>
      'Brief description of this checklist';

  @override
  String get checklistSheetNoShiftsAttach =>
      'No shifts are available to attach right now.';

  @override
  String get checklistSheetNoShiftsFound =>
      'No shifts found for this location. Please create shifts first.';

  @override
  String get checklistSheetShiftTip =>
      'Select shifts where this checklist appears. You can leave this empty now and attach it later from the Shifts screen.';

  @override
  String get checklistSheetSelectShifts =>
      'Select which shifts should use this checklist:';

  @override
  String get checklistSheetTasksTip =>
      'Tap the camera to require a photo. If a photo is not uploaded by staff, admins are notified.';

  @override
  String get checklistSheetTasksIntro =>
      'Add tasks to your checklist. Drag to reorder:';

  @override
  String get checklistSheetNoTasks =>
      'No tasks added yet. Tap \"Add Task\" to get started.';

  @override
  String get checklistSheetAddTask => 'Add Task';

  @override
  String get checklistSheetAdvancedTip =>
      'Advanced settings are optional. Use them if you want to limit who can see this checklist or attach it to one or more shifts now.';

  @override
  String get checklistSheetVisibilityByJobType => 'Visibility by job type';

  @override
  String get checklistSheetAssignToShifts => 'Assign to shifts';

  @override
  String get checklistSheetSpanishTranslations => 'Spanish translations';

  @override
  String get checklistSheetPortugueseTranslations => 'Portuguese translations';

  @override
  String get checklistSheetSpanishTip =>
      'Optional: add Spanish versions of this template and its task names. English stays as the fallback when a Spanish field is left blank.';

  @override
  String get checklistSheetTemplateNameSpanish => 'Template name (Spanish)';

  @override
  String get checklistSheetTemplateNameSpanishHint => 'e.g., Apertura del bar';

  @override
  String get checklistSheetDescriptionSpanish => 'Description (Spanish)';

  @override
  String get checklistSheetDescriptionSpanishHint =>
      'Brief description in Spanish';

  @override
  String get checklistSheetAddTasksForSpanish =>
      'Add tasks first to include Spanish task labels.';

  @override
  String get checklistSheetSpanishTaskLabels => 'Spanish task labels';

  @override
  String checklistSheetTaskSpanish(int index) {
    return 'Task $index (Spanish)';
  }

  @override
  String get checklistSheetSpanishTaskLabelHint => 'Spanish task label';

  @override
  String checklistSheetSpanishFor(String name) {
    return 'Spanish for: $name';
  }

  @override
  String get checklistSheetPortugueseTip =>
      'Optional: add Portuguese versions of this template and its task names. English stays as the fallback when a Portuguese field is left blank.';

  @override
  String get checklistSheetTemplateNamePortuguese =>
      'Template name (Portuguese)';

  @override
  String get checklistSheetTemplateNamePortugueseHint =>
      'e.g., Abertura do bar';

  @override
  String get checklistSheetDescriptionPortuguese => 'Description (Portuguese)';

  @override
  String get checklistSheetDescriptionPortugueseHint =>
      'Brief description in Portuguese';

  @override
  String get checklistSheetAddTasksForPortuguese =>
      'Add tasks first to include Portuguese task labels.';

  @override
  String get checklistSheetPortugueseTaskLabels => 'Portuguese task labels';

  @override
  String checklistSheetTaskPortuguese(int index) {
    return 'Task $index (Portuguese)';
  }

  @override
  String get checklistSheetPortugueseTaskLabelHint => 'Portuguese task label';

  @override
  String checklistSheetPortugueseFor(String name) {
    return 'Portuguese for: $name';
  }

  @override
  String checklistSheetTask(int index) {
    return 'Task $index';
  }

  @override
  String get checklistSheetTaskHint => 'Enter task description';

  @override
  String get checklistSheetDeleteTask => 'Delete task';

  @override
  String get checklistSheetPhotoRequired => 'Photo required';

  @override
  String get checklistSheetNoPhotoRequired => 'No photo required';

  @override
  String get checklistSheetTaskName => 'Task name';

  @override
  String get checklistSheetPhoto => 'Photo';

  @override
  String checklistSheetLoadShiftsError(String error) {
    return 'Error loading shifts: $error';
  }

  @override
  String get checklistSheetJobTypesTip =>
      'Job types control who will see this checklist. Leave this empty to make it visible to everyone on the shift.';

  @override
  String get checklistSheetJobTypesIntro =>
      'Optionally restrict this checklist to people with these job types. Leave empty to make it visible to all.';

  @override
  String get checklistSheetManage => 'Manage';

  @override
  String get checklistSheetNoJobTypes =>
      'No job types found yet. Use Manage to create your first one.';

  @override
  String get checklistSheetAddJobType => 'Add job type';

  @override
  String get checklistSheetAddJobTypeHint => 'e.g., Dishwasher';

  @override
  String get checklistSheetAdd => 'Add';

  @override
  String checklistSheetSaveFailed(String error) {
    return 'Failed to save checklist: $error';
  }

  @override
  String shiftSheetLoadDataError(String error) {
    return 'Error loading data: $error';
  }

  @override
  String get shiftSheetSavedSuccess => 'Shift schedule updated successfully';

  @override
  String shiftSheetSaveError(String error) {
    return 'Error saving schedule: $error';
  }

  @override
  String get shiftSheetAddRequiredRole => 'Add Required Role';

  @override
  String get shiftSheetAlreadyAdded => 'Already added';

  @override
  String shiftSheetAssignedCount(int assigned, int required) {
    return '$assigned of $required assigned';
  }

  @override
  String get shiftSheetRequiredRoles => 'Required Roles';

  @override
  String get shiftSheetAddRole => 'Add Role';

  @override
  String get shiftSheetNoRolesAssigned =>
      'No roles assigned to this shift. Tap \"Add Role\" to add required positions.';

  @override
  String get shiftSheetAssignedUsers => 'Assigned Users';

  @override
  String get shiftSheetNoUsersAssigned => 'No users assigned yet.';

  @override
  String get shiftSheetAvailableUsers => 'Available Users (Matching Roles)';

  @override
  String get shiftSheetOtherUsers => 'Other Users (No Matching Role)';

  @override
  String shiftSheetLoadUsersError(String error) {
    return 'Error loading users: $error';
  }

  @override
  String get shiftSheetNoOtherUsers => 'No other users available';

  @override
  String get shiftSheetSaveSchedule => 'Save Schedule';

  @override
  String get shiftSheetUnknownRole => 'Unknown Role';

  @override
  String shiftSheetRequiredCount(int count) {
    return 'Required: $count';
  }

  @override
  String get shiftSheetDecreaseCount => 'Decrease count';

  @override
  String get shiftSheetIncreaseCount => 'Increase count';

  @override
  String get shiftSheetRemoveRole => 'Remove role';

  @override
  String get shiftSheetUnknownUserInitial => 'U';

  @override
  String shiftSheetCheckAssignmentsError(String error) {
    return 'Error checking assignments: $error';
  }

  @override
  String get shiftSheetAlreadyAssignedAnotherShift =>
      'Already assigned to another shift this day';

  @override
  String get notificationTopicsTitle => 'Tipos de notificación';

  @override
  String get notificationTopicsIntro =>
      'Elige qué actualizaciones quieres seguir:';

  @override
  String get notificationTopicsScheduleUpdates =>
      'Las actualizaciones de horario te avisan cuando cambian tus turnos.';

  @override
  String get notificationTopicsShiftReminders =>
      'Los recordatorios de turno te preparan antes de que comience tu trabajo asignado.';

  @override
  String get notificationTopicsGeneralAnnouncements =>
      'Los anuncios generales comparten novedades más amplias del equipo y del negocio.';

  @override
  String get notificationTopicsGotIt => 'Entendido';

  @override
  String get notificationTypesLearnMore =>
      'Más información sobre los tipos de notificación';

  @override
  String get notificationTypesTitle => 'Tipos de notificaciones';

  @override
  String get notificationPushTitle => 'Notificaciones push';

  @override
  String get notificationPushEnabled =>
      'Las notificaciones push están activadas en este dispositivo.';

  @override
  String get notificationPushTapToEnable =>
      'Pulsa activar para recibir alertas en este dispositivo.';

  @override
  String get notificationEnable => 'Activar';

  @override
  String get notificationTypeScheduleUpdates => 'Actualizaciones de horario';

  @override
  String get notificationTypeScheduleUpdatesBody =>
      'Recibe avisos cuando tus turnos se agreguen, cambien o eliminen.';

  @override
  String get notificationTypeShiftReminders => 'Recordatorios de turno';

  @override
  String get notificationTypeShiftRemindersBody =>
      'Recibe recordatorios antes de que empiecen tus próximos turnos.';

  @override
  String get notificationTypeGeneralAnnouncements => 'Anuncios generales';

  @override
  String get notificationTypeGeneralAnnouncementsBody =>
      'Mantente al tanto de las novedades del equipo y los avisos importantes.';

  @override
  String get notificationTypeEmail => 'Notificaciones por correo';

  @override
  String get notificationTypeEmailBody =>
      'Recibe también por correo las actualizaciones más importantes.';

  @override
  String get notificationDebugInfo => 'Información de depuración';

  @override
  String get notificationFcmToken => 'Token de FCM';

  @override
  String get notificationNoToken => 'Todavía no hay token disponible';

  @override
  String get notificationTokenCopied => 'Token copiado';

  @override
  String get pushPermissionExplanationBody =>
      'Activa las notificaciones para recibir recordatorios de turnos, cambios de horario y actualizaciones importantes del equipo al instante.';

  @override
  String get pushPermissionNotNow => 'Ahora no';

  @override
  String get pushPermissionEnabledSuccess =>
      'Las notificaciones están activadas.';

  @override
  String get pushPermissionError =>
      'No pudimos activar las notificaciones. Inténtalo de nuevo.';

  @override
  String get pushPermissionDisabledTitle =>
      'Las notificaciones están desactivadas';

  @override
  String get pushPermissionDisabledBody =>
      'Puedes seguir usando la app, pero podrías perder recordatorios y avisos urgentes hasta volver a activar las notificaciones en la configuración del dispositivo.';

  @override
  String get pushPermissionMaybeLater => 'Tal vez después';

  @override
  String get pushPermissionOpenSettings => 'Abrir configuración';

  @override
  String get pushPermissionShortBody =>
      'Recibe recordatorios de turnos, cambios de horario y novedades del equipo en este dispositivo.';

  @override
  String get pushPermissionSettings => 'Configuración';

  @override
  String get pushPermissionRequestError =>
      'No pudimos solicitar el permiso de notificaciones. Inténtalo de nuevo.';

  @override
  String get availabilitySavedSuccess =>
      'Disponibilidad guardada correctamente.';

  @override
  String availabilitySaveError(String error) {
    return 'Error al guardar la disponibilidad: $error';
  }

  @override
  String get availabilityTitle => 'Disponibilidad';

  @override
  String get availabilityShiftAvailability => 'Disponibilidad por turnos';

  @override
  String get availabilityShiftAvailabilityBody =>
      'Define en qué bloques de turno sueles poder trabajar cada día.';

  @override
  String get availabilityEarliestStartTimes => 'Hora más temprana para empezar';

  @override
  String get availabilityEarliestStartBody =>
      'Define la hora más temprana en la que normalmente puedes empezar cada día de la semana.';

  @override
  String get availabilityDefaultTime => '9:00';

  @override
  String get availabilityNotificationPreferences =>
      'Preferencias de notificación';

  @override
  String get availabilityScheduleUpdatesBody =>
      'Mantente al día cuando cambie tu horario publicado.';

  @override
  String get availabilityShiftRemindersBody =>
      'Recibe recordatorios antes de que empiecen tus turnos.';

  @override
  String get availabilityEmailNotificationsBody =>
      'Recibe también por correo las actualizaciones más importantes.';

  @override
  String get availabilityPushNotificationsBody =>
      'Permite que este dispositivo reciba alertas instantáneas.';

  @override
  String get availabilitySavePreferences => 'Guardar preferencias';

  @override
  String get weekdayMonday => 'Lunes';

  @override
  String get weekdayTuesday => 'Martes';

  @override
  String get weekdayWednesday => 'Miércoles';

  @override
  String get weekdayThursday => 'Jueves';

  @override
  String get weekdayFriday => 'Viernes';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get shiftLabelMorning => 'Mañana';

  @override
  String get shiftLabelAfternoon => 'Tarde';

  @override
  String get shiftLabelEvening => 'Noche';

  @override
  String get shiftLabelNight => 'Madrugada';

  @override
  String get upgradeLocationsTitle => 'Agregar ubicaciones';

  @override
  String get upgradeLocationsQuantity =>
      '¿Cuántas ubicaciones quieres agregar?';

  @override
  String upgradeLocationsSummary(int count, String price) {
    return 'Agregar $count ubicación(es) por $price al mes.';
  }

  @override
  String upgradeLocationsFailed(String error) {
    return 'No se pudieron actualizar las ubicaciones: $error';
  }

  @override
  String get upgradeLocationsAction => 'Actualizar y pagar';
}
