// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageDescription =>
      'Escolha o idioma da experiência da equipe.';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageSaved => 'Idioma atualizado.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonArchive => 'Arquivar';

  @override
  String get commonUnarchive => 'Desarquivar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Concluir';

  @override
  String get commonErrorTitle => 'Erro';

  @override
  String get commonEmail => 'E-mail';

  @override
  String get commonPassword => 'Senha';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonRole => 'Função';

  @override
  String get commonName => 'Nome';

  @override
  String get commonBackToSignIn => 'Voltar para entrar';

  @override
  String get commonGoToSignIn => 'Ir para entrar';

  @override
  String get commonOpenHands => 'Abrir Hands';

  @override
  String get commonNotSpecified => 'Não especificado';

  @override
  String get commonContinueIn => 'Continuar em';

  @override
  String get commonWebApp => 'aplicativo web';

  @override
  String get loginTitle => 'Entrar';

  @override
  String get loginIntroTitle => 'Operações, sem o caos.';

  @override
  String get loginIntroBody =>
      'Entre para gerenciar turnos, tarefas, documentos e a execução da equipe em um só lugar.';

  @override
  String get loginFeatureLiveTaskTracking =>
      'Acompanhamento de tarefas em tempo real';

  @override
  String get loginFeatureSharedTeamWorkflows =>
      'Fluxos de trabalho compartilhados da equipe';

  @override
  String get loginFeatureOperationalVisibility => 'Visibilidade operacional';

  @override
  String get loginWelcomeBack => 'Bem-vindo de volta';

  @override
  String get loginWelcomeBackBody => 'Use seu e-mail e senha para continuar.';

  @override
  String get loginEmailLabel => 'E-mail';

  @override
  String get loginEmailHint => 'Digite seu e-mail';

  @override
  String get loginPasswordLabel => 'Senha';

  @override
  String get loginPasswordHint => 'Digite sua senha';

  @override
  String get loginHidePassword => 'Ocultar senha';

  @override
  String get loginShowPassword => 'Mostrar senha';

  @override
  String get loginSignIn => 'Entrar';

  @override
  String get loginForgotPassword => 'Esqueceu a senha?';

  @override
  String get loginNeedAccessTitle => 'Precisa de acesso?';

  @override
  String get loginNeedAccessBody =>
      'Se você precisa acessar uma organização existente, peça ao seu gerente para enviar um convite.';

  @override
  String get loginNeedAccountTitle => 'Precisa de uma conta?';

  @override
  String get loginNeedAccountBody =>
      'Crie uma organização de teste ou aceite um convite do seu gerente.';

  @override
  String get loginSignUp => 'Criar conta';

  @override
  String loginVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get loginEnterEmail => 'Digite seu e-mail';

  @override
  String get loginEnterValidEmail => 'Digite um e-mail válido';

  @override
  String get loginEnterPassword => 'Digite sua senha';

  @override
  String get loginProfileNotFound =>
      'Perfil não encontrado. Fale com seu administrador.';

  @override
  String get loginResetPasswordTitle => 'Redefinir senha';

  @override
  String get loginResetPasswordSubtitle =>
      'Digite o e-mail vinculado à sua conta Hands e enviaremos um link seguro para redefinição.';

  @override
  String get loginResetPasswordBody =>
      'Enviaremos um e-mail de redefinição de senha imediatamente.';

  @override
  String get loginResetEmailAddressLabel => 'Endereço de e-mail';

  @override
  String get loginResetEmailHint => 'Digite o e-mail da sua conta';

  @override
  String get loginResetSendButton => 'Enviar link de redefinição';

  @override
  String loginResetEmailSent(String email) {
    return 'E-mail de redefinição enviado para $email';
  }

  @override
  String get loginEnterEmailAddress => 'Digite seu endereço de e-mail.';

  @override
  String get loginEnterValidEmailAddress =>
      'Digite um endereço de e-mail válido.';

  @override
  String get loginResetFailed =>
      'Não foi possível enviar o e-mail de redefinição.';

  @override
  String get loginNoAccountFound => 'Nenhuma conta encontrada com esse e-mail.';

  @override
  String get loginTooManyRequests =>
      'Muitas tentativas. Tente novamente mais tarde.';

  @override
  String get welcomeInviteUnavailable => 'Convite indisponível';

  @override
  String welcomeToOrganization(String organizationName) {
    return 'Bem-vindo à $organizationName!';
  }

  @override
  String welcomeInviteBody(String organizationName) {
    return 'Você foi convidado para entrar em $organizationName. Conclua a configuração da sua conta para começar.';
  }

  @override
  String get welcomeAccountDetails => 'Detalhes da conta';

  @override
  String get welcomeCompleteSetupTitle => 'Conclua a configuração da sua conta';

  @override
  String get welcomeCompleteSetupBody =>
      'Crie uma senha para finalizar a configuração da sua conta. Seu acesso à organização e sua função serão aplicados automaticamente a partir deste convite.';

  @override
  String get welcomeNewPasswordLabel => 'Nova senha';

  @override
  String get welcomeNewPasswordHint => 'Crie uma nova senha';

  @override
  String get welcomeConfirmPasswordLabel => 'Confirmar nova senha';

  @override
  String get welcomeConfirmPasswordHint => 'Confirme sua nova senha';

  @override
  String get welcomeEnterNewPassword => 'Digite uma nova senha';

  @override
  String get welcomePasswordMinLength =>
      'A senha deve ter pelo menos 6 caracteres';

  @override
  String get welcomeConfirmNewPassword => 'Confirme sua nova senha';

  @override
  String get welcomePasswordsDoNotMatch => 'As senhas não coincidem';

  @override
  String get welcomeCompleteSetupButton => 'Concluir configuração';

  @override
  String get welcomeAccountSetupCompleteTitle =>
      'Configuração da conta concluída';

  @override
  String get welcomeAccountReady => 'Sua conta está pronta para uso.';

  @override
  String get welcomeOpenOnWeb =>
      'Você já pode abrir o Hands na web. O download do app móvel é opcional.';

  @override
  String get welcomeDownloadOnThe => 'Baixar no';

  @override
  String get welcomeAppStore => 'App Store';

  @override
  String get welcomeUseSameCredentials =>
      'Use o mesmo e-mail e senha que você acabou de criar em qualquer lugar onde fizer login.';

  @override
  String get welcomeInviteAccepted =>
      'Este convite já foi aceito. Entre com sua conta para continuar.';

  @override
  String get welcomeInviteExpired =>
      'Este link de convite expirou. Peça ao seu administrador para enviar um novo convite.';

  @override
  String get welcomeInviteRevoked =>
      'Este convite foi revogado pelo seu administrador. Peça um novo convite se ainda precisar de acesso.';

  @override
  String get welcomeInviteInvalid =>
      'Este link de convite não é válido ou não está mais disponível.';

  @override
  String get welcomeRoleGeneralUser => 'Usuário geral';

  @override
  String get welcomeRoleManager => 'Gerente';

  @override
  String get welcomeRoleAdmin => 'Administrador';

  @override
  String get welcomeRoleUser => 'Usuário';

  @override
  String welcomeFailedSetup(String error) {
    return 'Não foi possível configurar a conta: $error';
  }

  @override
  String get welcomeInviteUsed =>
      'Este convite já foi usado. Entre com sua conta.';

  @override
  String get welcomeInviteExistingAccount =>
      'Já existe uma conta para este e-mail. Entre com ela ou fale com seu administrador se esperava um novo convite.';

  @override
  String get welcomeInviteExpiredError =>
      'Este convite expirou. Peça ao seu administrador para enviar outro.';

  @override
  String get welcomeInviteRevokedError =>
      'Este convite foi revogado. Peça um novo convite ao seu administrador.';

  @override
  String get welcomeInviteMissingEmail =>
      'O convite não possui um endereço de e-mail.';

  @override
  String get notificationsInbox => 'Caixa de entrada';

  @override
  String get notificationsUnread => 'Não lidas';

  @override
  String get notificationsRead => 'Lidas';

  @override
  String get notificationsArchived => 'Arquivadas';

  @override
  String get notificationsHeaderSubtitle =>
      'Atualizações não lidas, itens lidos e mensagens arquivadas.';

  @override
  String get notificationsDeleteTitle => 'Excluir mensagem';

  @override
  String get notificationsDeleteBody =>
      'Tem certeza de que deseja excluir esta mensagem permanentemente? Esta ação não pode ser desfeita.';

  @override
  String get notificationsDeleteSuccess => 'Mensagem excluída com sucesso';

  @override
  String notificationsDeleteFailed(String error) {
    return 'Não foi possível excluir a mensagem: $error';
  }

  @override
  String notificationsNoMessagesIn(String filter) {
    return 'Nenhuma mensagem em $filter';
  }

  @override
  String get notificationsNewMessage => 'Nova mensagem';

  @override
  String get notificationsNoContent => 'Sem conteúdo';

  @override
  String get notificationsLoadMore => 'Carregar mais';

  @override
  String notificationsYesterdayAt(String time) {
    return 'Ontem $time';
  }

  @override
  String get contactUsTitle => 'Fale conosco';

  @override
  String get contactUsSuccess =>
      'Solicitação de ajuda enviada com sucesso! Responderemos em até 24 horas.';

  @override
  String get contactUsFailed =>
      'Não foi possível enviar a solicitação de ajuda';

  @override
  String get contactUsNetworkError => 'Erro de rede. Tente novamente.';

  @override
  String get contactUsOverviewTitle => 'Suporte sem idas e vindas.';

  @override
  String get contactUsOverviewBody =>
      'Envie uma solicitação clara e nossa equipe responderá com a ajuda certa para configuração, cobrança, erros ou dúvidas de fluxo de trabalho.';

  @override
  String get contactUsTechnicalIssues => 'Problemas técnicos';

  @override
  String get contactUsBillingQuestions => 'Dúvidas sobre cobrança';

  @override
  String get contactUsTeamSetupHelp => 'Ajuda com configuração da equipe';

  @override
  String get contactUsWhatToExpect => 'O que esperar';

  @override
  String get contactUsTypicalResponse => 'Resposta típica';

  @override
  String get contactUsTypicalResponseValue => 'Em até 24 horas';

  @override
  String get contactUsBestFor => 'Ideal para';

  @override
  String get contactUsBestForValue =>
      'Ajuda com produto, cobrança e configuração';

  @override
  String get contactUsHelpfulDetails => 'Detalhes úteis';

  @override
  String get contactUsHelpfulDetailsValue => 'Local, função e o que aconteceu';

  @override
  String get contactUsSupportContext => 'Contexto de suporte';

  @override
  String get contactUsSupportContextBody =>
      'Incluiremos automaticamente o contexto atual de ajuda e localização.';

  @override
  String get bottomNavTodayTasks => 'Tarefas de hoje';

  @override
  String get bottomNavDashboard => 'Painel';

  @override
  String get bottomNavSetup => 'Configuração';

  @override
  String get bottomNavDocumentCenter => 'Central de documentos';

  @override
  String get messagesTitle => 'Comunicações';

  @override
  String get messagesHeaderSubtitle =>
      'A caixa de entrada mantém todos atualizados. Os comunicados enviam novas atualizações. Os públicos organizam quem as recebe.';

  @override
  String get messagesInboxTab => 'Caixa de entrada';

  @override
  String get messagesBroadcastsTab => 'Comunicados';

  @override
  String get messagesAudiencesTab => 'Públicos';

  @override
  String get messagesBroadcastsTitle => 'Comunicados';

  @override
  String get messagesBroadcastsBody =>
      'Envie uma atualização clara para todos, para um local ou para um público personalizado.';

  @override
  String get messagesBroadcastsHelp =>
      'Use comunicados para atualizações limpas para toda a equipe ou para um local específico, que devem permanecer visíveis na caixa de entrada.';

  @override
  String get messagesNewBroadcast => 'Novo comunicado';

  @override
  String get messagesBroadcastsUnavailable => 'Comunicados indisponíveis';

  @override
  String get messagesOrgContextMissing =>
      'Não foi possível determinar o contexto da sua organização.';

  @override
  String get messagesNoBroadcasts => 'Ainda não há comunicados';

  @override
  String get messagesNoBroadcastsBody =>
      'Suas atualizações enviadas aparecerão aqui quando você transmitir para a equipe.';

  @override
  String get messagesSending => 'Enviando...';

  @override
  String get messagesEveryone => 'Todos';

  @override
  String get messagesCustomAudience => 'Público personalizado';

  @override
  String get messagesLocation => 'Local';

  @override
  String get messagesUntitledBroadcast => 'Comunicado sem título';

  @override
  String get messagesAudiencesTitle => 'Públicos';

  @override
  String get messagesAudiencesBody =>
      'Crie listas reutilizáveis de público para que a equipe certa receba a atualização certa sempre.';

  @override
  String get messagesAudiencesHelp =>
      'Os públicos são grupos reutilizáveis de destinatários que ajudam você a enviar o comunicado certo para a equipe certa.';

  @override
  String get broadcastSheetTitle => 'Nova transmissão';

  @override
  String get broadcastSheetSubtitle =>
      'Envie uma atualização clara para todos, para um local ou para um público salvo.';

  @override
  String get broadcastSendButton => 'Enviar transmissão';

  @override
  String get broadcastInfoTip =>
      'As transmissões aparecem na caixa de entrada da equipe e também podem enviar uma notificação push.';

  @override
  String get broadcastAudienceSectionTitle => 'Público';

  @override
  String get broadcastRecipientEveryone => 'Todos';

  @override
  String get broadcastRecipientSavedAudience => 'Público salvo';

  @override
  String get broadcastRecipientLocation => 'Local específico';

  @override
  String get broadcastSendToLabel => 'Enviar para';

  @override
  String get broadcastChooseAudience => 'Escolha um público';

  @override
  String get broadcastSelectAudience => 'Selecione um público';

  @override
  String get broadcastSelectLocation => 'Selecione um local';

  @override
  String get broadcastMessageSectionTitle => 'Mensagem';

  @override
  String get broadcastHeadlineLabel => 'Título';

  @override
  String get broadcastEnterHeadline => 'Digite um título';

  @override
  String get broadcastMessageLabel => 'Mensagem';

  @override
  String get broadcastMessageHint => 'O que a equipe precisa saber agora?';

  @override
  String get broadcastEnterMessage => 'Digite uma mensagem';

  @override
  String get broadcastDismiss => 'Fechar';

  @override
  String broadcastAutoTitleAudience(String name) {
    return 'Atualização para $name';
  }

  @override
  String get broadcastAutoTitleAudienceFallback => 'Atualização do público';

  @override
  String broadcastAutoTitleLocation(String name) {
    return 'Atualização para $name';
  }

  @override
  String get broadcastAutoTitleLocationFallback => 'Atualização do local';

  @override
  String get broadcastAutoTitleTeam => 'Atualização da equipe';

  @override
  String get audienceSheetSubtitle =>
      'Crie listas de público reutilizáveis para que os gerentes possam alcançar a equipe certa rapidamente.';

  @override
  String get audienceSavedTitle => 'Públicos salvos';

  @override
  String get audienceNewTitle => 'Novo público';

  @override
  String get audienceNameLabel => 'Nome do público';

  @override
  String get audienceSearchMembers => 'Buscar membros da equipe';

  @override
  String get audienceTeamMembers => 'Membros da equipe';

  @override
  String get audienceMembersTitle => 'Membros do público';

  @override
  String get audienceCreateButton => 'Criar público';

  @override
  String get audienceEditTitle => 'Editar público';

  @override
  String get audienceDeleteTitle => 'Excluir público';

  @override
  String get audienceEnterNameAndMember =>
      'Digite um nome para o público e selecione pelo menos um membro da equipe.';

  @override
  String get audienceCreatedSuccess => 'Público criado com sucesso!';

  @override
  String get audienceUpdatedSuccess => 'Público atualizado com sucesso!';

  @override
  String get audienceDeletedSuccess => 'Público excluído com sucesso!';

  @override
  String audienceDeleteBody(String groupName) {
    return 'Tem certeza de que deseja excluir o público \"$groupName\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get messagesManageAudiences => 'Gerenciar públicos';

  @override
  String get messagesAudiencesUnavailable => 'Públicos indisponíveis';

  @override
  String get messagesNoAudiences => 'Ainda não há públicos personalizados';

  @override
  String get messagesNoAudiencesBody =>
      'Comece com públicos personalizados para equipes como Bar, Cozinha ou Turma do fim de semana.';

  @override
  String get messagesCustomAudiencesMetric => 'Públicos personalizados';

  @override
  String get messagesLinkedMembersMetric => 'Membros vinculados';

  @override
  String get messagesUnnamedAudience => 'Público sem nome';

  @override
  String messagesMemberCount(int count) {
    return '$count membros';
  }

  @override
  String get threadTitle => 'Conversa';

  @override
  String get threadNoMessages => 'Ainda não há mensagens';

  @override
  String get threadMessageHint => 'Mensagem';

  @override
  String get threadDeleteTitle => 'Excluir mensagem';

  @override
  String get threadDeleteBody =>
      'Tem certeza de que deseja excluir esta mensagem? Esta ação não pode ser desfeita.';

  @override
  String get threadDeleteSuccess => 'Mensagem excluída com sucesso';

  @override
  String threadDeleteFailed(String error) {
    return 'Falha ao excluir mensagem: $error';
  }

  @override
  String get commonOpen => 'Abrir';

  @override
  String get commonReplay => 'Repetir';

  @override
  String get helpTitle => 'Ajuda';

  @override
  String get helpSubtitle =>
      'Encontre a maneira mais rápida de concluir o trabalho, configurar operações ou resolver um problema.';

  @override
  String get helpSearchHint =>
      'Pesquise ajuda, configuração ou solução de problemas';

  @override
  String get helpSearchResultsTitle => 'Resultados da busca';

  @override
  String get helpNoSearchResults =>
      'Ainda não há tópicos de ajuda para essa busca.';

  @override
  String helpTopicsFoundForRole(int count, String role) {
    return '$count tópicos encontrados para $role';
  }

  @override
  String get helpStartHereTitle => 'Comece aqui';

  @override
  String get helpOpenHelp => 'Abrir ajuda';

  @override
  String get helpOpenWalkthrough => 'Abrir passo a passo';

  @override
  String get helpStartHereSectionSubtitle =>
      'Comece pelo caminho mais curto para a sua função.';

  @override
  String get helpNewHereTitle => 'Sou novo aqui';

  @override
  String get helpNewHereBody =>
      'Faça o passo a passo do app orientado por função sem precisar ler todos os guias primeiro.';

  @override
  String get helpOpenStartHere => 'Abrir Comece aqui';

  @override
  String get helpBrowseByRoleTitle => 'Explorar por função';

  @override
  String get helpBrowseByRoleBody => 'Veja apenas os tópicos da sua função.';

  @override
  String get helpFixProblemTitle => 'Resolver um problema';

  @override
  String get helpFixProblemBody => 'Vá direto para a solução de problemas.';

  @override
  String get helpBrowseByRoleSectionSubtitle =>
      'Mude de perspectiva sem trocar de conta.';

  @override
  String get helpReplayGuidedTourTitle => 'Repetir tour guiado';

  @override
  String get helpReplayGuidedTourSubtitle =>
      'Volte ao passo a passo dentro do app para sua função atual sempre que precisar relembrar.';

  @override
  String get helpWhatsNewTitle => 'Novidades';

  @override
  String get helpWhatsNewSubtitle =>
      'Reabra o resumo da atualização principal mais recente e inicie o tour guiado novamente.';

  @override
  String get helpMajorUpdateAvailable => 'Grande atualização disponível';

  @override
  String get helpLatestMajorRelease => 'Última grande versão';

  @override
  String get helpOpenLatestReleaseUpdateBody =>
      'Abra o resumo da versão mais recente e as instruções de atualização para sua função.';

  @override
  String get helpOpenLatestReleaseTourBody =>
      'Abra o resumo da versão mais recente e reinicie o tour guiado para sua função.';

  @override
  String get helpPopularTasksTitle => 'Tarefas populares';

  @override
  String helpPopularTasksSubtitle(String role) {
    return 'Os guias mais úteis para $role agora.';
  }

  @override
  String helpRoleBannerTitle(String role) {
    return 'Ajuda para $role';
  }

  @override
  String get helpStillStuckTitle => 'Ainda com dificuldades?';

  @override
  String get helpStillStuckBody =>
      'Abra a solução de problemas primeiro ou fale com o suporte sobre o problema que você está vendo agora.';

  @override
  String get helpContactSupport => 'Falar com o suporte';

  @override
  String get settingsPageTitle => 'Configurações';

  @override
  String get settingsHeroTitle =>
      'Configurações da conta e do espaço de trabalho';

  @override
  String get settingsHeroHelp =>
      'Use Configurações para detalhes da conta, preferências e suporte sem perder o foco na operação.';

  @override
  String get settingsHeroAdminBody =>
      'Gerencie seu perfil, os dados do negócio, a cobrança e as preferências operacionais em um só lugar.';

  @override
  String get settingsHeroStaffBody =>
      'Gerencie seu perfil, sua senha e suas preferências de notificação em um só lugar.';

  @override
  String get settingsPreferencesTitle => 'Preferências';

  @override
  String get settingsPreferencesSaved => 'Preferências salvas com sucesso!';

  @override
  String settingsPreferencesSaveFailed(String error) {
    return 'Não foi possível salvar as preferências: $error';
  }

  @override
  String get settingsProfileTitle => 'Perfil';

  @override
  String get settingsProfileSubtitle =>
      'Os dados da sua conta e seu e-mail de acesso.';

  @override
  String get settingsBusinessTitle => 'Negócio';

  @override
  String get settingsBusinessSubtitle =>
      'Detalhes principais da organização exibidos em todo o app.';

  @override
  String get settingsLocationsTitle => 'Locais';

  @override
  String get settingsLocationsSubtitle =>
      'Gerencie onde sua equipe trabalha e onde os turnos acontecem.';

  @override
  String get settingsLocationsBody =>
      'Adicione, revise ou ajuste os locais vinculados à sua organização.';

  @override
  String get settingsLocationSupportEmail =>
      'Envie um e-mail para support@planwithhands.com';

  @override
  String get settingsGuidedToursTitle => 'Tours guiados';

  @override
  String get settingsGuidedToursSubtitle =>
      'Repita o tour no app para sua função atual sempre que precisar relembrar.';

  @override
  String settingsReplayTour(String role) {
    return 'Repetir tour de $role';
  }

  @override
  String get settingsWhatsNew => 'Novidades';

  @override
  String get settingsSecurityTitle => 'Segurança';

  @override
  String get settingsSecuritySubtitle =>
      'Redefinição de senha e controles de acesso relacionados à sessão.';

  @override
  String get settingsResetPassword => 'Redefinir senha';

  @override
  String get settingsSignedInAs => 'Sessão iniciada como';

  @override
  String get settingsOrganization => 'Organização';

  @override
  String get settingsSessionTimeout => 'Tempo limite da sessão';

  @override
  String get settingsSessionTimeoutSubtitle =>
      'Encerre a sessão automaticamente após um período de inatividade';

  @override
  String get settingsSessionTimeoutDone => 'Concluir';

  @override
  String get settingsSessionTimeout2Hours => '2 horas';

  @override
  String get settingsSessionTimeout2HoursBody =>
      'Alta segurança: saída automática após 2 horas';

  @override
  String get settingsSessionTimeout4Hours => '4 horas';

  @override
  String get settingsSessionTimeout4HoursBody =>
      'Segurança equilibrada: saída automática após 4 horas';

  @override
  String get settingsSessionTimeout8Hours => '8 horas';

  @override
  String get settingsSessionTimeout8HoursBody =>
      'Recomendado: bom para turnos de trabalho';

  @override
  String get settingsSessionTimeout24Hours => '24 horas';

  @override
  String get settingsSessionTimeout24HoursBody =>
      'Acesso estendido: saída automática após 1 dia';

  @override
  String get settingsResetEmailInvalid => 'Digite um endereço de e-mail válido';

  @override
  String settingsResetEmailSentVerified(String email) {
    return 'A redefinição de senha foi enviada para o e-mail verificado $email. Verifique seu novo e-mail para usá-lo no login.';
  }

  @override
  String settingsResetEmailSent(String email) {
    return 'O e-mail de redefinição de senha foi enviado para $email';
  }

  @override
  String get settingsResetEmailFailed =>
      'Não foi possível enviar o e-mail de redefinição';

  @override
  String get settingsResetEmailUserNotFound =>
      'Nenhuma conta encontrada com este endereço de e-mail';

  @override
  String get settingsResetEmailTooManyRequests =>
      'Muitas solicitações. Tente novamente mais tarde';

  @override
  String get settingsSummaryPeriodTitle => 'Selecione o período do resumo';

  @override
  String get settingsSummaryPeriodCalendar => 'Dia do calendário';

  @override
  String get settingsSummaryPeriodCalendarBody =>
      'Somente as tarefas de hoje (das 6h às 6h)';

  @override
  String get settingsSummaryPeriodBusiness => 'Dia operacional';

  @override
  String get settingsSummaryPeriodBusinessBody =>
      'Inclui as tarefas de fechamento da noite passada';

  @override
  String get settingsDailySummaryHourTitle =>
      'Selecione a hora do resumo diário';

  @override
  String get settingsDailySummaryFixedMinutes =>
      'Os minutos ficam fixos em :00';

  @override
  String get settingsOrganizationDailySummaryUpdated =>
      'As configurações do resumo diário da organização foram atualizadas!';

  @override
  String settingsOrganizationDailySummaryFailed(String error) {
    return 'Não foi possível salvar as configurações da organização: $error';
  }

  @override
  String get settingsDailySummaryEmailTitle => 'E-mail de resumo diário';

  @override
  String get settingsDailySummaryEmailSubtitle =>
      'Receba resumos diários de conclusão de tarefas';

  @override
  String get settingsDailySummaryTimeTitle => 'Horário do resumo diário';

  @override
  String get settingsDailySummaryTimeSubtitle =>
      'Quando receber seu resumo diário';

  @override
  String get settingsDailySummaryRateLimitTitle => 'Limite de alterações';

  @override
  String get settingsDailySummaryChangeBlocked =>
      'Não é possível alterar o resumo diário agora.';

  @override
  String get settingsDailySummaryConfirmTitle => 'Confirmar mudança de horário';

  @override
  String get settingsDailySummaryTimePassedTitle => 'O horário já passou';

  @override
  String get settingsDailySummaryProceedQuestion =>
      'Deseja continuar com a mudança de horário?';

  @override
  String get settingsDailySummarySendNowTitle => 'Enviar agora?';

  @override
  String get settingsDailySummarySendNowBody =>
      'Deseja enviar o resumo de hoje imediatamente em vez de esperar até amanhã?';

  @override
  String get settingsDailySummarySendNowLater => 'Não, esperar';

  @override
  String get settingsDailySummarySendNowAction => 'Sim, enviar agora';

  @override
  String get settingsDailySummaryResultSuccess => 'Sucesso';

  @override
  String get settingsDailySummaryResultError => 'Erro';

  @override
  String get settingsSummaryPeriodLabel => 'Período do resumo';

  @override
  String get settingsSummaryPeriodLabelSubtitle =>
      'Escolha se o resumo inclui tarefas tarde da noite';

  @override
  String get settingsDashboardMetricsTitle => 'Métricas do painel';

  @override
  String get settingsDashboardMetricsSubtitle =>
      'Recalcule as métricas do painel a partir de hoje';

  @override
  String get settingsRefresh => 'Atualizar';

  @override
  String get settingsLoadingSubscriptionData =>
      'Carregando dados da assinatura...';

  @override
  String get settingsLoadingSubscriptionDetails =>
      'Carregando detalhes da assinatura...';

  @override
  String get settingsTrialEndingSoon => 'O teste termina em breve';

  @override
  String settingsFreeTrialDays(int days) {
    return 'Teste grátis de $days dias';
  }

  @override
  String settingsTrialContinueUntil(String date) {
    return 'Seu teste continuará até $date, mas você não será cobrado.';
  }

  @override
  String settingsTrialChargeOn(String date, int days) {
    return 'Você está em um teste grátis de $days dias. Sua primeira cobrança ocorrerá em $date, a menos que cancele.';
  }

  @override
  String get settingsCancelSubscription => 'Cancelar assinatura';

  @override
  String get settingsManageBilling => 'Gerenciar cobrança';

  @override
  String get settingsBillingPortal => 'Portal de cobrança';

  @override
  String settingsBillingPortalFailed(String error) {
    return 'Não foi possível abrir o portal de cobrança: $error';
  }

  @override
  String get settingsTrialAndBilling => 'Teste e cobrança';

  @override
  String get settingsSubscriptionManagement => 'Gerenciamento da assinatura';

  @override
  String get settingsPlannedLocations => 'Locais planejados:';

  @override
  String get settingsSubscribedLocations => 'Locais assinados:';

  @override
  String get settingsLocationsInUse => 'Locais em uso:';

  @override
  String get settingsMonthlyCost => 'Custo mensal:';

  @override
  String get settingsStatus => 'Status:';

  @override
  String get settingsSubscriptionOverUsage =>
      'Você está usando mais locais do que sua assinatura permite. Faça upgrade para evitar interrupções no serviço.';

  @override
  String get settingsAddBilling => 'Adicionar cobrança';

  @override
  String get settingsManageSubscription => 'Gerenciar assinatura';

  @override
  String get settingsBillingWebOnly =>
      'Para gerenciar sua assinatura, visite https://planwithhands.com e clique em \"Login\" no canto superior direito. As assinaturas precisam ser gerenciadas pelo portal web.';

  @override
  String get settingsBillingPortalWebOnly =>
      'Para gerenciar a cobrança, abra esta página no Safari ou Chrome e acesse o portal de cobrança. As assinaturas precisam ser gerenciadas pelo portal web.';

  @override
  String get settingsTalkToSales => 'Falar com vendas';

  @override
  String get settingsNoOrganizationFound =>
      'Nenhuma organização encontrada. Entre em contato com o suporte.';

  @override
  String get settingsOrganizationInformation => 'Informações da organização';

  @override
  String get settingsOrganizationLabel => 'Organização:';

  @override
  String get settingsBusinessTypeLabel => 'Tipo de negócio:';

  @override
  String get settingsNotSet => 'Não definido';

  @override
  String get settingsActiveLocations => 'Locais ativos:';

  @override
  String get settingsNeedHelp => 'Precisa de ajuda?';

  @override
  String get settingsSupportContactBody =>
      'Para gerenciamento de assinatura, dúvidas de cobrança ou suporte técnico, fale conosco:';

  @override
  String get settingsSupportEmailPrompt =>
      'Envie um e-mail para support@planwithhands.com';

  @override
  String get settingsContactSalesBody =>
      'Para 5 ou mais locais, fale com nossa equipe de vendas para um plano personalizado.';

  @override
  String get settingsSubscriptionUpgraded =>
      'Assinatura atualizada para um plano superior!';

  @override
  String get settingsSubscriptionUpdated => 'Assinatura atualizada!';

  @override
  String settingsSubscriptionUpdateFailed(String error) {
    return 'Não foi possível atualizar: $error';
  }

  @override
  String get settingsSubscriptionChangeIncrease => 'aumentar';

  @override
  String get settingsSubscriptionChangeDecrease => 'reduzir';

  @override
  String get settingsUpgradeSubscription => 'Fazer upgrade da assinatura';

  @override
  String get settingsDowngradeSubscription => 'Reduzir assinatura';

  @override
  String settingsSubscriptionAboutToChange(String change) {
    return 'Você está prestes a $change sua assinatura de locais:';
  }

  @override
  String get settingsFrom => 'De:';

  @override
  String get settingsTo => 'Para:';

  @override
  String settingsLocationsCount(int count) {
    return '$count locais';
  }

  @override
  String get settingsMonthlyChange => 'Mudança mensal:';

  @override
  String get settingsPerMonth => '/mês';

  @override
  String get settingsBillingEffectiveNextCycle =>
      'O novo valor de cobrança entra em vigor no próximo ciclo de faturamento.';

  @override
  String get settingsCurrent => 'Atual:';

  @override
  String get settingsInUse => 'Em uso:';

  @override
  String settingsCannotReduceBelow(int currentUsage) {
    return 'Não é possível reduzir abaixo de $currentUsage (uso atual). Exclua locais primeiro.';
  }

  @override
  String get settingsNoChanges => 'Sem alterações';

  @override
  String get settingsUpgrade => 'Fazer upgrade';

  @override
  String get settingsDowngrade => 'Reduzir';

  @override
  String get settingsStatusActive => 'ATIVA';

  @override
  String get settingsStatusTrial => 'TESTE';

  @override
  String get settingsStatusPastDue => 'ATRASADA';

  @override
  String get settingsStatusCanceled => 'CANCELADA';

  @override
  String get settingsStatusUnpaid => 'NÃO PAGA';

  @override
  String get settingsStatusPending => 'PENDENTE';

  @override
  String get settingsAccountTitle => 'Conta';

  @override
  String get settingsAccountSubtitle =>
      'Saída do dispositivo e ações irreversíveis da conta.';

  @override
  String get settingsSignOut => 'Sair';

  @override
  String get settingsSignOutSubtitle =>
      'Isso encerra sua sessão neste dispositivo e leva você de volta para a tela de login.';

  @override
  String get settingsSigningOut => 'Saindo...';

  @override
  String settingsSignOutFailed(String error) {
    return 'Não foi possível sair: $error';
  }

  @override
  String get settingsDeleteAccount => 'Excluir conta';

  @override
  String get settingsDeleteAccountWarningTitle => 'Excluir conta?';

  @override
  String get settingsDeleteAccountWarningBody =>
      'Isso excluirá permanentemente sua conta e todos os dados pessoais associados. Essa ação NÃO pode ser desfeita.';

  @override
  String get settingsDeleteAccountReinviteBody =>
      'Se você continuar e depois quiser usar o Hands novamente, precisará receber um NOVO CONVITE do seu administrador para se cadastrar de novo.';

  @override
  String get settingsDeleteAccountContinueQuestion =>
      'Você ainda quer continuar?';

  @override
  String get settingsDeleteAccountConfirmAction => 'Sim, excluir';

  @override
  String get settingsDeleteAccountBody =>
      'Isso excluirá permanentemente sua conta e todos os seus dados. Essa ação não pode ser desfeita.';

  @override
  String get settingsDeleteAccountPasswordPrompt =>
      'Digite sua senha para confirmar:';

  @override
  String get settingsDeleteAccountPasswordHint => 'Senha';

  @override
  String get settingsDeletingAccount => 'Excluindo conta...';

  @override
  String get settingsDeleteAccountSuccess => 'Conta excluída com sucesso';

  @override
  String get settingsDeleteAccountFailed => 'Não foi possível excluir a conta';

  @override
  String get settingsDeleteAccountWrongPassword =>
      'Senha incorreta. Tente novamente.';

  @override
  String get settingsDeleteAccountRelogin =>
      'Saia e entre novamente, depois tente de novo.';

  @override
  String get settingsDeleteAccountTooManyRequests =>
      'Muitas tentativas sem sucesso. Tente novamente mais tarde.';

  @override
  String get settingsAddLocation => 'Adicionar local';

  @override
  String get settingsEdit => 'Editar';

  @override
  String get settingsFirstName => 'Nome';

  @override
  String get settingsLastName => 'Sobrenome';

  @override
  String get settingsEditProfileTitle => 'Editar perfil';

  @override
  String get settingsEditProfileSubtitle =>
      'Atualize seu nome e o e-mail de acesso.';

  @override
  String get settingsSaveChanges => 'Salvar alterações';

  @override
  String get settingsProfileSignInRequired =>
      'Faça login para editar seu perfil';

  @override
  String get settingsProfileSavedVerifyEmail =>
      'Perfil salvo. Verifique o novo e-mail.';

  @override
  String get settingsProfileUpdatedSuccess => 'Perfil atualizado com sucesso!';

  @override
  String get settingsProfileUpdateFailed =>
      'Não foi possível atualizar o perfil';

  @override
  String get settingsProfileErrorReloginToChangeEmail =>
      'Saia e entre novamente para alterar o e-mail';

  @override
  String get settingsProfileErrorEmailInUse => 'E-mail já está em uso';

  @override
  String get settingsProfileErrorInvalidEmail => 'Endereço de e-mail inválido';

  @override
  String get settingsFieldEnterFirstName => 'Digite o nome';

  @override
  String get settingsFieldEnterLastName => 'Digite o sobrenome';

  @override
  String get settingsInvalidEmail => 'E-mail inválido';

  @override
  String get settingsBusinessName => 'Nome da empresa';

  @override
  String get settingsBusinessType => 'Tipo de empresa';

  @override
  String get commonRequired => 'Obrigatório';

  @override
  String get commonHide => 'Ocultar';

  @override
  String helpSupportRequest(String role) {
    return 'Solicitação de suporte de $role';
  }

  @override
  String helpRolePageTitle(String role) {
    return 'Ajuda de $role';
  }

  @override
  String get helpTroubleshootingTitle => 'Solução de problemas';

  @override
  String get helpTroubleshootingSubtitle =>
      'Resolva bloqueios rapidamente começando pelo sintoma que você está vendo agora.';

  @override
  String get helpTroubleshootingSearchHint =>
      'Pesquise um problema como turno ausente ou local errado';

  @override
  String get helpTroubleshootingIntroTitle =>
      'A solução de problemas funciona melhor quando você começa pelo sintoma exato.';

  @override
  String get helpTroubleshootingIntroBody =>
      'Verifique primeiro o local ativo, a função atual e o contexto da tela. Muitos problemas são, na verdade, de escopo ou configuração.';

  @override
  String get helpTroubleshootingCommonProblems => 'Problemas comuns';

  @override
  String get helpTroubleshootingResults => 'Resultados';

  @override
  String get helpTroubleshootingNoResults =>
      'Nenhum guia de solução de problemas correspondeu a essa busca. Tente um sintoma mais simples ou fale com o suporte.';

  @override
  String get helpNeedMoreHelpTitle => 'Precisa de mais ajuda?';

  @override
  String get helpNeedMoreHelpBody =>
      'Envie ao suporte o problema exato, o local e a tela em que você estava. Incluiremos o contexto da solução de problemas automaticamente.';

  @override
  String get helpTopicScreenLabel => 'Tópico de ajuda';

  @override
  String get helpTopicMissingSubtitle => 'Esse tópico não foi encontrado.';

  @override
  String get helpTopicMissingBody =>
      'O guia que você tentou abrir não existe mais ou ainda não foi adicionado.';

  @override
  String get helpReturnToHelp => 'Voltar para Ajuda';

  @override
  String helpMinutes(int count) {
    return '$count min';
  }

  @override
  String get helpWhyThisMatters => 'Por que isso importa';

  @override
  String get helpDoThisNow => 'Faça isso agora';

  @override
  String get helpWhatGoodLooksLike => 'Como fica quando está certo';

  @override
  String get helpCommonMistakes => 'Erros comuns';

  @override
  String helpMoreRoleHelp(String role) {
    return 'Mais ajuda para $role';
  }

  @override
  String get helpRelatedHelp => 'Ajuda relacionada';

  @override
  String get helpStartHerePageSubtitle =>
      'Um passo a passo rápido com o essencial da sua função para que você use o app sem adivinhação.';

  @override
  String get helpFollowTheseSteps => 'Siga estas etapas';

  @override
  String get helpKeepGoing => 'Continue';

  @override
  String get helpRoleStaff => 'Equipe';

  @override
  String get helpRoleManager => 'Gerente';

  @override
  String get helpRoleAdmin => 'Administrador';

  @override
  String get helpRoleStaffShortDescription =>
      'Trabalho diário, turnos, tarefas e pendências';

  @override
  String get helpRoleManagerShortDescription =>
      'Acompanhamento diário, retornos e comunicados';

  @override
  String get helpRoleAdminShortDescription =>
      'Configuração, fluxos, acesso da equipe e operações';

  @override
  String get helpCategoryDailyWork => 'Trabalho diário';

  @override
  String get helpCategoryDailyWorkDescription =>
      'Passe pelo seu turno e conclua as tarefas com clareza.';

  @override
  String get helpCategoryOversight => 'Acompanhamento diário';

  @override
  String get helpCategoryOversightDescription =>
      'Entenda o serviço em tempo real e responda rápido aos riscos.';

  @override
  String get helpCategorySetup => 'Configuração operacional';

  @override
  String get helpCategorySetupDescription =>
      'Configure o negócio na ordem certa.';

  @override
  String get helpCategoryCommunications => 'Comunicações';

  @override
  String get helpCategoryCommunicationsDescription =>
      'Mantenha a equipe alinhada com caixa de entrada, comunicados e públicos.';

  @override
  String get helpCategoryDocuments => 'Documentos e treinamento';

  @override
  String get helpCategoryDocumentsDescription =>
      'Use a Central de documentos para treinamentos, SOPs e materiais de referência.';

  @override
  String get helpCategoryAccount => 'Conta e acesso';

  @override
  String get helpCategoryAccountDescription =>
      'Gerencie login, locais, acesso e informações básicas do perfil.';

  @override
  String get helpCategorySharedMode => 'Modo compartilhado';

  @override
  String get helpCategorySharedModeDescription =>
      'Use dispositivos compartilhados com segurança sem perder o controle.';

  @override
  String get helpCategoryTroubleshooting => 'Solução de problemas';

  @override
  String get helpCategoryTroubleshootingDescription =>
      'Resolva bloqueios rapidamente quando faltarem trabalho, acesso ou mensagens.';

  @override
  String get helpCategoryOperationsControl => 'Controle operacional';

  @override
  String get helpCategoryOperationsControlDescription =>
      'Conduza as operações do dia a dia e mantenha a configuração saudável ao longo do tempo.';

  @override
  String contactUsPrefillSubjectTopic(String topic) {
    return 'Ajuda com $topic';
  }

  @override
  String contactUsPrefillSubjectIssue(String issue) {
    return 'Ajuda com $issue';
  }

  @override
  String contactUsPrefillSubjectScreen(String screen) {
    return 'Ajuda na tela $screen';
  }

  @override
  String get contactUsPrefillSubjectDefault => 'Solicitação de suporte';

  @override
  String get contactUsPrefillPrompt =>
      'Descreva o que aconteceu, o que você esperava e qualquer erro que viu.';

  @override
  String get contactUsPrefillContextTitle => 'Contexto';

  @override
  String contactUsPrefillRole(String role) {
    return 'Função: $role';
  }

  @override
  String contactUsPrefillHelpTopic(String topic) {
    return 'Tópico de ajuda: $topic';
  }

  @override
  String contactUsPrefillScreen(String screen) {
    return 'Tela: $screen';
  }

  @override
  String contactUsPrefillLocation(String location) {
    return 'Local: $location';
  }

  @override
  String contactUsPrefillIssue(String issue) {
    return 'Problema: $issue';
  }

  @override
  String contactUsPrefillRoute(String route) {
    return 'Rota: $route';
  }

  @override
  String get contactUsSendRequestTitle => 'Enviar uma solicitação';

  @override
  String get contactUsSendRequestBody =>
      'Seja breve e específico para que possamos ajudar mais rápido.';

  @override
  String get contactUsAutoContextBody =>
      'Esta solicitação já inclui seu tópico de ajuda, tela atual e local ativo para que o suporte responda mais rápido.';

  @override
  String get contactUsSubjectLabel => 'Assunto';

  @override
  String get contactUsSubjectHint => 'Com o que você precisa de ajuda?';

  @override
  String get contactUsMessageLabel => 'Mensagem';

  @override
  String get contactUsMessageHint =>
      'Descreva o problema, o que você esperava e o que aconteceu.';

  @override
  String get contactUsEmailRequired => 'E-mail é obrigatório';

  @override
  String get contactUsValidEmailRequired => 'Digite um e-mail válido';

  @override
  String get contactUsSubjectRequired => 'Assunto é obrigatório';

  @override
  String get contactUsSubjectMinLength =>
      'O assunto deve ter pelo menos 5 caracteres';

  @override
  String get contactUsMessageRequired => 'A mensagem é obrigatória';

  @override
  String get contactUsMessageMinLength =>
      'A mensagem deve ter pelo menos 10 caracteres';

  @override
  String get contactUsSendRequestButton => 'Enviar solicitação';

  @override
  String get contactUsUrgentIssueNote =>
      'Para problemas urgentes, inclua o local, o turno afetado e qualquer mensagem de erro que você viu.';

  @override
  String get documentsTitle => 'Central de documentos';

  @override
  String get documentsNoOrganization =>
      'Nenhuma organização encontrada. Entre em contato com o suporte.';

  @override
  String get documentsUploaded => 'Documento enviado';

  @override
  String get documentsUpdated => 'Documento atualizado';

  @override
  String get documentsDeleteTitle => 'Excluir documento';

  @override
  String get documentsDeleteBody =>
      'Tem certeza de que deseja excluir este documento? Esta ação não pode ser desfeita.';

  @override
  String get documentsDeletedSuccess => 'Documento excluído com sucesso';

  @override
  String documentsDeleteError(String error) {
    return 'Erro ao excluir documento: $error';
  }

  @override
  String get documentsAdminSubtitle =>
      'Organize SOPs, guias de treinamento e arquivos de referência para cada local.';

  @override
  String get documentsStaffSubtitle =>
      'Encontre os guias, políticas e materiais de referência de que você precisa para este turno.';

  @override
  String get documentsHelpSubtitle =>
      'Use a Central de documentos para SOPs, treinamento e arquivos de referência que apoiam o trabalho sem poluir os fluxos de tarefa.';

  @override
  String get documentsUpload => 'Enviar';

  @override
  String get documentsSearchHint =>
      'Pesquisar por título, categoria ou nome do arquivo';

  @override
  String get documentsCurrentScope => 'Escopo atual';

  @override
  String get documentsAllLocations => 'Todos os locais';

  @override
  String documentsLocationsCount(int count) {
    return '$count locais';
  }

  @override
  String documentsErrorLoading(String error) {
    return 'Erro ao carregar documentos: $error';
  }

  @override
  String get documentsVisibleFiles => 'Arquivos visíveis';

  @override
  String get documentsCategories => 'Categorias';

  @override
  String get documentsScope => 'Escopo';

  @override
  String get documentsScopeAll => 'Todos';

  @override
  String get documentsScopeLocal => 'Local';

  @override
  String get documentsBuildLibraryTitle => 'Monte sua biblioteca de documentos';

  @override
  String get documentsNoDocumentsTitle => 'Ainda não há documentos disponíveis';

  @override
  String get documentsBuildLibraryBody =>
      'Envie SOPs, políticas de segurança, guias de equipamentos e arquivos de treinamento para que sua equipe tenha uma única fonte confiável.';

  @override
  String get documentsNoDocumentsBody =>
      'Seu gerente ou administrador enviará guias de treinamento, SOPs e documentos de referência aqui.';

  @override
  String get documentsUploadFirst => 'Enviar primeiro documento';

  @override
  String documentsNoMatches(String query) {
    return 'Nenhum arquivo corresponde a \"$query\" no escopo atual.';
  }

  @override
  String get documentsNoLocationDocs =>
      'Nenhum documento disponível para este local.';

  @override
  String documentsNoCategoryDocs(String category) {
    return 'Nenhum documento nesta categoria ainda.';
  }

  @override
  String get documentsNothingToShow => 'Nada para mostrar';

  @override
  String get documentsUntitled => 'Sem título';

  @override
  String get documentsTypeVideo => 'Vídeo';

  @override
  String get documentsTypeImage => 'Imagem';

  @override
  String get documentsTypeDoc => 'Documento';

  @override
  String get documentsGlobal => 'Global';

  @override
  String get documentsLocation => 'Local';

  @override
  String get documentsEditTooltip => 'Editar documento';

  @override
  String get documentsDeleteTooltip => 'Excluir documento';

  @override
  String documentsAddedDate(String date) {
    return 'Adicionado em $date';
  }

  @override
  String get documentsOpenError => 'Não foi possível abrir o documento';

  @override
  String documentsOpenErrorDetailed(String error) {
    return 'Não foi possível abrir este documento: $error';
  }

  @override
  String get documentsCategoryAll => 'Todas';

  @override
  String get documentsCategorySafetyProcedures => 'Procedimentos de segurança';

  @override
  String get documentsCategoryCleaningProtocols => 'Protocolos de limpeza';

  @override
  String get documentsCategoryTrainingMaterials => 'Materiais de treinamento';

  @override
  String get documentsCategoryOperatingProcedures =>
      'Procedimentos operacionais';

  @override
  String get documentsCategoryEmergencyProcedures =>
      'Procedimentos de emergência';

  @override
  String get documentsCategoryEquipmentManuals => 'Manuais de equipamentos';

  @override
  String get documentsCategoryPolicyDocuments => 'Documentos de política';

  @override
  String get documentsCategoryOther => 'Outros';

  @override
  String get documentsViewerOpenExternalTooltip =>
      'Abrir no navegador ou aplicativo';

  @override
  String get documentsViewerDownloadTooltip => 'Baixar arquivo';

  @override
  String get documentsViewerLoading => 'Carregando documento...';

  @override
  String get documentsViewerErrorTitle =>
      'Não foi possível carregar a visualização';

  @override
  String get documentsViewerInvalidUrl => 'URL inválida do documento';

  @override
  String get documentsViewerDownloadFailed => 'Falha ao baixar o documento';

  @override
  String get documentsViewerTestBrowser => 'Testar no navegador';

  @override
  String get documentsViewerRetry => 'Tentar novamente';

  @override
  String get documentsViewerNoPath => 'Nenhum caminho de documento disponível';

  @override
  String get documentsViewerTrainingDocument => 'Documento de treinamento';

  @override
  String get documentsViewerNativeBody =>
      'Seu dispositivo abrirá o documento em um aplicativo compatível.';

  @override
  String get documentsViewerOpenDocument => 'Abrir documento';

  @override
  String get documentsViewerNativeHelp =>
      'Se nada acontecer, tente usar a opção de abrir externamente.';

  @override
  String get documentsViewerPdfTitle => 'Visualizador de PDF';

  @override
  String get documentsViewerOfficeTitle => 'Documento do Office';

  @override
  String get documentsViewerWebBody =>
      'Abra este documento na web para usar o visualizador mais completo.';

  @override
  String get documentsViewerViewDocument => 'Ver documento';

  @override
  String get documentsViewerCopyLink => 'Copiar link';

  @override
  String get documentsViewerTechnicalInfo => 'Informações técnicas';

  @override
  String get documentsViewerDocumentUrl => 'URL do documento';

  @override
  String get documentsViewerNewTabNote => 'Abrirá em uma nova aba';

  @override
  String get documentsViewerImageFailed => 'Não foi possível carregar a imagem';

  @override
  String get documentsViewerPreviewUnavailable => 'Visualização indisponível';

  @override
  String get documentsViewerUnsupportedPreview =>
      'Este tipo de arquivo não tem visualização incorporada aqui.';

  @override
  String get documentsViewerOpenExternal => 'Abrir externamente';

  @override
  String get documentsViewerUrlCopied => 'Link copiado';

  @override
  String get documentsViewerCopyFailed => 'Não foi possível copiar o link';

  @override
  String get documentsViewerVideoFailed => 'Não foi possível carregar o vídeo';

  @override
  String get documentsViewerLoadingVideo => 'Carregando vídeo...';

  @override
  String get documentsUploadSheetTitle => 'Documento';

  @override
  String get documentsUploadSheetLoadingSubtitle =>
      'Carregando o contexto da organização...';

  @override
  String get documentsUploadSheetMissingOrgSubtitle =>
      'Não foi possível determinar sua organização.';

  @override
  String get documentsUploadTitle => 'Enviar documento';

  @override
  String get documentsEditTitle => 'Editar documento';

  @override
  String get documentsUploadSubtitle =>
      'Adicione POPs, políticas, guias e arquivos de treinamento para a equipe.';

  @override
  String get documentsUpdateButton => 'Atualizar documento';

  @override
  String get documentsInfoTip =>
      'Envie PDFs, arquivos DOCX, imagens ou vídeos de até 20 MB e coloque-os na categoria correta.';

  @override
  String get documentsDetails => 'Detalhes';

  @override
  String get documentsDocumentTitleLabel => 'Título do documento';

  @override
  String get documentsDocumentTitleHint =>
      'Digite um título claro e descritivo';

  @override
  String get documentsDocumentTitleRequired =>
      'Digite um título para o documento';

  @override
  String get documentsCategoryLabel => 'Categoria';

  @override
  String get documentsCategoryRequired => 'Selecione uma categoria';

  @override
  String get documentsReplaceFileOptional => 'Substituir arquivo (opcional)';

  @override
  String get documentsSelectFile => 'Selecionar arquivo';

  @override
  String get documentsUnknownFile => 'Arquivo desconhecido';

  @override
  String get documentsChangeFile => 'Trocar arquivo';

  @override
  String get documentsTapToSelect => 'Toque para selecionar um arquivo';

  @override
  String get documentsSupportedFileTypes => 'PDF, DOCX, imagens ou vídeo';

  @override
  String documentsPickFileError(String error) {
    return 'Erro ao selecionar arquivo: $error';
  }

  @override
  String get documentsFillRequiredFields =>
      'Preencha todos os campos obrigatórios';

  @override
  String get documentsSelectFileRequired => 'Selecione um arquivo';

  @override
  String get documentsMissingOrgId =>
      'Falta o ID da organização. Não é possível enviar o documento.';

  @override
  String get documentsUserNotAuthenticated =>
      'Usuário não autenticado. Faça login novamente.';

  @override
  String get documentsFileDataUnavailable =>
      'Os dados do arquivo não estão disponíveis. Selecione o arquivo novamente.';

  @override
  String get documentsUpdatedSuccess => 'Documento atualizado com sucesso!';

  @override
  String get documentsUploadedSuccess => 'Documento enviado com sucesso!';

  @override
  String get documentsUploadFailedPrefix => 'Falha no envio: ';

  @override
  String get documentsUploadFailedMissingData =>
      'Faltam dados obrigatórios. Tente selecionar o arquivo novamente.';

  @override
  String get documentsUploadFailedPermission =>
      'Permissão negada. Verifique as permissões da sua conta.';

  @override
  String get documentsUploadFailedStorage =>
      'Erro de armazenamento. Verifique sua conexão com a internet.';

  @override
  String get documentsDismissTip => 'Fechar';

  @override
  String get scheduleEditorTitle => 'Editor de escala';

  @override
  String get scheduleMyTitle => 'Minha escala';

  @override
  String get scheduleOrganizationNotFound => 'Organização não encontrada';

  @override
  String get scheduleOrganizationLocationMissing =>
      'Organização ou local não definido.';

  @override
  String get scheduleLocationLabel => 'Local';

  @override
  String get schedulePickDateRange => 'Escolha um intervalo de datas';

  @override
  String get scheduleSelectDateRange => 'Selecionar intervalo de datas';

  @override
  String get scheduleNext7Days => 'Próximos 7 dias';

  @override
  String scheduleDaysWindow(int start, int end) {
    return 'Dias $start-$end';
  }

  @override
  String get scheduleSelectLocationAndDateRange =>
      'Selecione um local e um intervalo de datas para ver a escala';

  @override
  String get schedulePublishSchedule => 'Publicar escala';

  @override
  String get scheduleCreateTemplateFirst =>
      'Crie primeiro um modelo de turno no painel de administração';

  @override
  String get schedulePublishAllSuccess =>
      'Todas as escalas foram publicadas com sucesso!';

  @override
  String schedulePublishError(String error) {
    return 'Erro ao publicar escalas: $error';
  }

  @override
  String scheduleDayPublished(String date) {
    return 'Escala de $date publicada!';
  }

  @override
  String scheduleDayPublishError(String error) {
    return 'Erro ao publicar escala: $error';
  }

  @override
  String get scheduleNoPublishedShifts => 'Nenhum turno publicado.';

  @override
  String scheduleAssignedCount(int count) {
    return 'Atribuídos: $count';
  }

  @override
  String scheduleUsersLabel(String users) {
    return 'Usuários: $users';
  }

  @override
  String get scheduleAssignedStatus => 'Atribuído';

  @override
  String get scheduleShiftsHeader => 'Turnos';

  @override
  String get scheduleAssignedCell => 'atribuído';

  @override
  String scheduleShiftTemplatesError(String error) {
    return 'Erro ao carregar turnos: $error';
  }

  @override
  String get scheduleNoShiftTemplates =>
      'Nenhum modelo de turno encontrado para este local.\nCrie modelos de turno primeiro no Painel de Administração.';

  @override
  String get scheduleUnnamedShift => 'Turno sem nome';

  @override
  String scheduleMessageTitle(String start, String end) {
    return 'Sua escala de $start a $end';
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
  String get dashboardSwitch => 'Trocar';

  @override
  String dashboardLocationsCount(int count) {
    return '$count locais';
  }

  @override
  String get dashboardNoActiveShift => 'Nenhum turno ativo';

  @override
  String get dashboardNothingAssignedTitle => 'Nada está atribuído agora';

  @override
  String dashboardNothingAssignedBody(String locationName) {
    return 'Você está configurado para trabalhar em $locationName. Pegue um turno disponível quando estiver pronto.';
  }

  @override
  String get dashboardSeeAvailableShifts => 'Ver turnos disponíveis';

  @override
  String get dashboardNoVisibleShiftTitle => 'Nenhum turno visível agora';

  @override
  String get dashboardNoVisibleShiftBody =>
      'Seus turnos atribuídos podem ter terminado, ou seu próximo turno ainda não está disponível para começar.';

  @override
  String get dashboardMomentumBody =>
      'Mantenha o ritmo quando o trabalho atribuído de hoje estiver em boa forma.';

  @override
  String get dashboardLoadingTasks => 'Carregando tarefas de hoje...';

  @override
  String get dashboardNoTasksForShift =>
      'Ainda não há tarefas disponíveis para este turno.';

  @override
  String get dashboardEverythingCompleteShift =>
      'Tudo neste turno está concluído.';

  @override
  String dashboardTasksLeftShort(int count) {
    return '$count restantes';
  }

  @override
  String dashboardBlockedShort(int count) {
    return '$count bloqueadas';
  }

  @override
  String dashboardNeedPhotosShort(int count) {
    return '$count precisam de fotos';
  }

  @override
  String get dashboardProgress => 'Progresso';

  @override
  String get dashboardWaitingForTasks => 'Aguardando tarefas';

  @override
  String dashboardCompletedOfTotal(int completed, int total) {
    return '$completed de $total concluídas';
  }

  @override
  String get dashboardRemaining => 'Restantes';

  @override
  String get dashboardTasksLeftInShift => 'Tarefas restantes neste turno';

  @override
  String get dashboardAttention => 'Atenção';

  @override
  String get dashboardPhotos => 'Fotos';

  @override
  String get dashboardBlockedOrFlagged => 'Bloqueadas ou sinalizadas';

  @override
  String get dashboardNeedPhotoProof => 'Precisam de comprovação por foto';

  @override
  String get dashboardReviewTodaysWork => 'Revisar trabalho de hoje';

  @override
  String get dashboardContinueWorking => 'Continuar trabalhando';

  @override
  String get dashboardViewFullShift => 'Ver turno completo';

  @override
  String get dashboardNextUp => 'Próximas';

  @override
  String get dashboardNoRemainingTasks =>
      'Não há tarefas restantes neste turno agora.';

  @override
  String get dashboardFastestPath =>
      'O caminho mais rápido para concluir este turno.';

  @override
  String get dashboardNextUpHelpSubtitle =>
      'Próximas mostra o caminho mais rápido pelas tarefas inacabadas do seu turno atual.';

  @override
  String dashboardQueuedCount(int count) {
    return '$count na fila';
  }

  @override
  String get dashboardNoTasksAvailableYet => 'Ainda não há tarefas disponíveis';

  @override
  String get dashboardCaughtUp => 'Você está em dia com este turno';

  @override
  String get dashboardCheckChecklistSetup =>
      'Se isso parecer errado, peça ao seu gerente para verificar a configuração da checklist deste turno.';

  @override
  String get dashboardReviewCompletedOrPickShift =>
      'Use a seção abaixo para revisar o trabalho concluído ou pegar outro turno.';

  @override
  String get dashboardCurrentShift => 'Turno atual';

  @override
  String get dashboardLeaveShift => 'Sair do turno';

  @override
  String dashboardPendingTasksRemaining(int count) {
    return '$count restantes';
  }

  @override
  String dashboardListsCount(int count) {
    return '$count listas';
  }

  @override
  String get dashboardNoTasksAvailableForShift =>
      'Nenhuma tarefa disponível para este turno';

  @override
  String get dashboardAskManagerVerifyChecklist =>
      'Se isso parecer errado, peça ao seu gerente para verificar a configuração da checklist de hoje.';

  @override
  String get dashboardChecklistFallback => 'Checklist';

  @override
  String get dashboardChecklistTasksLoading =>
      'As tarefas estão carregando para esta checklist';

  @override
  String dashboardChecklistCompletedOfTotal(int completed, int total) {
    return '$completed de $total tarefas concluídas';
  }

  @override
  String dashboardNeedPhotoChip(int count) {
    return '$count precisam de foto';
  }

  @override
  String get dashboardEverythingHereComplete => 'Tudo aqui está concluído';

  @override
  String get dashboardCompletedBelow =>
      'O trabalho concluído fica abaixo para revisão rápida.';

  @override
  String dashboardHideCompleted(int count) {
    return 'Ocultar concluídas ($count)';
  }

  @override
  String dashboardShowCompleted(int count) {
    return 'Mostrar concluídas ($count)';
  }

  @override
  String dashboardNeedsAttention(String reason) {
    return 'Precisa de atenção: $reason';
  }

  @override
  String get dashboardPhotoRequiredBeforeSignoff =>
      'Foto obrigatória antes da confirmação';

  @override
  String get dashboardReadyToComplete => 'Pronta para concluir';

  @override
  String get dashboardMustBeLoggedIn =>
      'Você precisa estar conectado para concluir tarefas';

  @override
  String get dashboardPhotoRequiredTitle => 'Foto obrigatória';

  @override
  String get dashboardPhotoRequiredBody =>
      'Esta tarefa exige uma foto. Adicione uma foto agora, conclua sem foto ou cancele.';

  @override
  String get dashboardCompleteWithoutPhoto => 'Concluir sem foto';

  @override
  String get dashboardAddPhoto => 'Adicionar foto';

  @override
  String get dashboardAddNoteRequiredTitle => 'Adicionar nota (obrigatório)';

  @override
  String get dashboardAddNoteRequiredBody =>
      'Adicione uma nota breve explicando por que nenhuma foto foi adicionada.';

  @override
  String get dashboardEnterNote => 'Digite uma nota...';

  @override
  String get dashboardSave => 'Salvar';

  @override
  String get dashboardTaskCompleted => 'Tarefa concluída!';

  @override
  String get dashboardTaskUnchecked => 'Marcação da tarefa removida';

  @override
  String get dashboardTaskUpdateError =>
      'Erro ao atualizar a tarefa. Tente novamente.';

  @override
  String get dashboardCompleted => 'Concluída';

  @override
  String dashboardCompletedBy(String name) {
    return 'Concluída por $name';
  }

  @override
  String get dashboardPhotoAdded => 'Foto adicionada';

  @override
  String get dashboardPhotoRequiredChip => 'Foto obrigatória';

  @override
  String get dashboardNoteAdded => 'Nota adicionada';

  @override
  String get dashboardBlocked => 'Bloqueada';

  @override
  String get dashboardPhotoMenu => 'Foto';

  @override
  String get dashboardNotesMenu => 'Notas';

  @override
  String get dashboardCannotComplete => 'Não é possível concluir';

  @override
  String get dashboardMarkIncomplete => 'Marcar como incompleta';

  @override
  String get dashboardComplete => 'Concluir';

  @override
  String get dashboardViewPhoto => 'Ver foto';

  @override
  String get dashboardUpdateIssue => 'Atualizar problema';

  @override
  String get dashboardCantDo => 'Não consigo fazer';

  @override
  String get dashboardEditNote => 'Editar nota';

  @override
  String get dashboardAddNote => 'Adicionar nota';

  @override
  String get dashboardSwitchLocationTitle => 'Trocar local';

  @override
  String get dashboardSwitchLocationBody =>
      'Escolha onde você quer ver e concluir o trabalho.';

  @override
  String get dashboardUnnamedLocation => 'Local sem nome';

  @override
  String get dashboardCurrentlySelectedLocation => 'Selecionado no momento';

  @override
  String get dashboardSwitchLocationError =>
      'Não foi possível trocar de local. Tente novamente.';

  @override
  String get dashboardMissedTaskNotCompletedYesterday => 'Não concluída ontem';

  @override
  String get dashboardNoteChip => 'Nota';

  @override
  String get dashboardReasonChip => 'Motivo';

  @override
  String get dashboardClearNotes => 'Limpar notas';

  @override
  String get dashboardClearReason => 'Limpar motivo';

  @override
  String dashboardAlreadySignedUpForShift(String shiftName) {
    return 'Você já está inscrito no turno $shiftName.';
  }

  @override
  String dashboardJoinedShift(String shiftName) {
    return 'Você entrou no turno $shiftName com sucesso!';
  }

  @override
  String get dashboardJoinShiftError =>
      'Erro ao entrar no turno. Tente novamente.';

  @override
  String get dashboardMustBeLoggedInToLeaveShift =>
      'Você precisa estar conectado para sair dos turnos';

  @override
  String get dashboardLeaveVolunteerShiftTitle => 'Sair do turno voluntário';

  @override
  String dashboardLeaveVolunteerShiftBody(String shiftName) {
    return 'Tem certeza de que deseja sair do turno voluntário \"$shiftName\"? Isso removerá você das futuras atribuições deste turno.';
  }

  @override
  String get dashboardLeaveShiftConfirm => 'Sair do turno';

  @override
  String get dashboardLeftVolunteerShift =>
      'Você saiu do turno voluntário com sucesso!';

  @override
  String get dashboardLeaveShiftError =>
      'Erro ao sair do turno. Tente novamente.';

  @override
  String get dashboardAvailableShiftsTitle => 'Turnos disponíveis';

  @override
  String dashboardAvailableShiftsSubtitle(String locationName) {
    return 'Selecione um turno para começar a trabalhar em $locationName';
  }

  @override
  String get dashboardAvailableShiftsLoadError => 'Erro ao carregar turnos';

  @override
  String get dashboardNoAvailableShiftsTitle => 'Nenhum turno disponível';

  @override
  String get dashboardNoAvailableShiftsBody =>
      'Não há turnos disponíveis para você entrar hoje.';

  @override
  String get dashboardNoAvailableShiftsTiming =>
      'Os turnos ficarão disponíveis para seleção 30 minutos antes do horário de início.';

  @override
  String get dashboardJoin => 'Entrar';

  @override
  String get dashboardTaskNotesTitle => 'Notas da tarefa';

  @override
  String dashboardTaskLabel(String taskName) {
    return 'Tarefa: $taskName';
  }

  @override
  String get dashboardUnknownTask => 'Tarefa desconhecida';

  @override
  String get dashboardTaskNotesPrompt =>
      'Adicione notas ou comentários sobre esta tarefa:';

  @override
  String get dashboardNotesSaved => 'Notas salvas com sucesso!';

  @override
  String dashboardNotesSaveError(String error) {
    return 'Erro ao salvar notas: $error';
  }

  @override
  String get dashboardNotesCleared => 'Notas removidas';

  @override
  String dashboardNotesClearError(String error) {
    return 'Não foi possível limpar as notas: $error';
  }

  @override
  String get dashboardSaveNotes => 'Salvar notas';

  @override
  String get dashboardEnterNotesHint => 'Digite suas notas aqui...';

  @override
  String get dashboardSavingNotes => 'Salvando notas...';

  @override
  String get dashboardPhotoViewerResetZoom => 'Redefinir zoom';

  @override
  String get dashboardPhotoViewerLoadingImage => 'Carregando imagem...';

  @override
  String get dashboardPhotoViewerLoadError =>
      'Não foi possível carregar a imagem';

  @override
  String get dashboardPhotoViewerGestureHint =>
      'Use pinça para ampliar • Arraste para mover • Toque em redefinir para ajustar à tela';

  @override
  String get dashboardReasonEquipmentUnavailable => 'Equipamento indisponível';

  @override
  String get dashboardReasonSuppliesMissing => 'Faltam suprimentos';

  @override
  String get dashboardReasonNotEnoughTime => 'Tempo insuficiente';

  @override
  String get dashboardReasonSafetyConcern => 'Preocupação com segurança';

  @override
  String get dashboardReasonWaitingApproval => 'Aguardando aprovação';

  @override
  String get dashboardReasonAreaBlocked => 'Área bloqueada/inacessível';

  @override
  String get dashboardReasonTechnicalIssue => 'Problema técnico';

  @override
  String get dashboardReasonStaffShortage => 'Falta de pessoal';

  @override
  String get dashboardReasonEmergencyPriority =>
      'Tarefa prioritária de emergência';

  @override
  String get dashboardReasonWeatherConditions => 'Condições climáticas';

  @override
  String get dashboardReasonOther => 'Outro (especifique abaixo)';

  @override
  String get dashboardReasonSpecifyText =>
      'Especifique o motivo no campo de texto';

  @override
  String get dashboardReasonSelectOrEnter => 'Selecione ou digite um motivo';

  @override
  String get dashboardReasonSaved => 'Motivo salvo com sucesso!';

  @override
  String dashboardReasonSaveError(String error) {
    return 'Erro ao salvar o motivo: $error';
  }

  @override
  String get dashboardTaskNotCompletedTitle => 'Tarefa não concluída';

  @override
  String get dashboardSaveReason => 'Salvar motivo';

  @override
  String get dashboardTaskNotCompletedPrompt =>
      'Por que esta tarefa não foi concluída?';

  @override
  String get dashboardEnterReasonHint => 'Explique o motivo...';

  @override
  String get dashboardSavingReason => 'Salvando motivo...';

  @override
  String get dashboardLoadingCarryover => 'Carregando pendências acumuladas...';

  @override
  String get dashboardCurrentLocationLabel => 'Local atual';

  @override
  String get dashboardWorkingLocationLabel => 'Local de trabalho';

  @override
  String get dashboardLocationHelpTitle => 'Ajuda de local';

  @override
  String get dashboardLocationHelpSubtitle =>
      'O local ativo controla quais turnos, tarefas e documentos você vê nesta página.';

  @override
  String get dashboardSharedModeTitle => 'Modo compartilhado';

  @override
  String get dashboardSharedModeLocked =>
      'Bloqueado — selecione seu nome para continuar';

  @override
  String dashboardSharedModeActive(String userName) {
    return 'Ativo: $userName';
  }

  @override
  String get dashboardCarryoverClearTitle => 'Sem pendências acumuladas';

  @override
  String get dashboardCarryoverClearBody => 'Não houve tarefas perdidas ontem.';

  @override
  String get dashboardCarryoverTitle => 'Pendências de ontem';

  @override
  String get dashboardCarryoverHelpTitle => 'Pendências de ontem';

  @override
  String get dashboardCarryoverHelpSubtitle =>
      'As pendências mantêm o trabalho inacabado visível para que ele possa ser concluído ou bloqueado com contexto em vez de desaparecer.';

  @override
  String dashboardTasksCompletedCount(int completed, int total) {
    return '$completed de $total tarefas concluídas';
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
      other: 'tarefas',
      one: 'tarefa',
    );
    return '$shiftCount $_temp0 • $taskCount $_temp1';
  }

  @override
  String get dashboardUnknownShift => 'Turno desconhecido';

  @override
  String get dashboardShiftTimingScheduled => 'Programado';

  @override
  String get dashboardShiftTimingCheckDetails =>
      'Verifique os detalhes do horário';

  @override
  String get dashboardShiftTimingStartsSoon => 'Começa em breve';

  @override
  String get dashboardShiftTimingAvailableNow => 'Disponível agora';

  @override
  String dashboardShiftTimingAvailableInMinutes(int minutes) {
    return 'Disponível em $minutes min';
  }

  @override
  String get dashboardShiftTimingInProgress => 'Em andamento';

  @override
  String dashboardShiftTimingHoursLeft(int hours) {
    return 'Faltam $hours h';
  }

  @override
  String dashboardShiftTimingMinutesLeft(int minutes) {
    return 'Faltam $minutes min';
  }

  @override
  String get dashboardShiftTimingGracePeriod => 'Período de tolerância';

  @override
  String get dashboardShiftTimingJustEnded => 'O turno acabou de terminar';

  @override
  String dashboardShiftTimingEndedMinutesAgo(int minutes) {
    return 'Terminou há $minutes min';
  }

  @override
  String get dashboardShiftTimingCheckCurrentWork =>
      'Verifique o trabalho atual';

  @override
  String get dashboardTourLocationTitle => 'Comece pelo local ativo';

  @override
  String get dashboardTourLocationDescription =>
      'Tarefas, turnos, pendências, avisos e documentos acompanham o local selecionado. Troque aqui antes de começar a trabalhar.';

  @override
  String get dashboardTourShiftLiveTitle =>
      'Primeiro, confira o resumo do seu turno';

  @override
  String get dashboardTourShiftIdleTitle =>
      'É aqui que o status do seu turno aparece';

  @override
  String get dashboardTourShiftLiveDescription =>
      'O destaque do turno mostra em qual turno você está, quanto trabalho falta e se algo está bloqueado ou aguardando comprovação.';

  @override
  String get dashboardTourShiftIdleDescription =>
      'Se você ainda não tiver um turno ativo, esta área mostra se deve esperar, pegar outro turno ou pedir ao gerente para verificar a configuração.';

  @override
  String get dashboardTourNextUpTitle =>
      'Use Próximas como sua fila principal de trabalho';

  @override
  String get dashboardTourNextUpDescription =>
      'Próximas mostra o caminho mais rápido pelo trabalho pendente para que você não precise revisar cada checklist manualmente.';

  @override
  String get dashboardTourTodaysWorkTitle =>
      'Revise checklists completos em Trabalho de hoje';

  @override
  String get dashboardTourTodaysWorkDescription =>
      'Use esta seção quando precisar da visualização completa do checklist do seu turno, das tarefas concluídas ou de um contexto mais profundo além da fila principal.';

  @override
  String get commonAdd => 'Adicionar';

  @override
  String get managerDashboardActiveShifts => 'Turnos ativos';

  @override
  String get managerDashboardActiveShiftLiveNowOne => '1 turno ativo agora';

  @override
  String managerDashboardActiveShiftLiveNowOther(int count) {
    return '$count turnos ativos agora';
  }

  @override
  String get managerDashboardAtRisk => 'Em risco';

  @override
  String get managerDashboardNoShiftsSlipping =>
      'Nenhum turno saindo do controle';

  @override
  String get managerDashboardNeedInterventionNow =>
      'Precisa de intervenção agora';

  @override
  String get managerDashboardOpenTasks => 'Tarefas abertas';

  @override
  String get managerDashboardNoTrackedTasksYet =>
      'Ainda não há tarefas monitoradas';

  @override
  String managerDashboardCompletedTracked(int completed, int total) {
    return '$completed/$total concluídas';
  }

  @override
  String get managerDashboardCarryover => 'Pendências';

  @override
  String get managerDashboardYesterdayFinishedCleanly =>
      'Ontem terminou sem pendências';

  @override
  String managerDashboardShiftsAffected(int count) {
    return '$count turnos afetados';
  }

  @override
  String get managerDashboardTourSummaryTitle => 'Comece pelo cartão de resumo';

  @override
  String get managerDashboardTourSummaryDescription =>
      'Este cartão superior mostra se o serviço está no rumo certo, quantos turnos estão em risco e o que precisa da sua atenção agora.';

  @override
  String get managerDashboardTourIssuesTitle =>
      'Use Hoje em risco como sua fila de ação';

  @override
  String get managerDashboardTourIssuesDescription =>
      'Abra estes problemas primeiro quando algo sair do plano. Eles ajudam você a priorizar trabalho perdido, riscos ao vivo e o próximo acompanhamento.';

  @override
  String get managerDashboardTourReadinessTitle =>
      'Prontidão dos turnos mostra o painel ao vivo';

  @override
  String get managerDashboardTourReadinessDescription =>
      'Use esta seção para inspecionar trabalho aberto, progresso dos turnos e quais operações estão saudáveis ou ficando para trás.';

  @override
  String get managerDashboardCurrentLocation => 'Local atual';

  @override
  String get managerDashboardLoading => 'Carregando painel';

  @override
  String managerDashboardIssuesNeedAttention(int count) {
    return '$count problemas precisam de atenção';
  }

  @override
  String get managerDashboardTodayOnTrack => 'Hoje está no rumo certo';

  @override
  String managerDashboardLoadingSummary(String locationName) {
    return 'Carregando os turnos de hoje, o trabalho perdido e os sinais de problemas recorrentes para $locationName.';
  }

  @override
  String get managerDashboardThisLocation => 'este local';

  @override
  String managerDashboardIssuesSummary(int riskCount, int openTaskCount) {
    return '$riskCount turnos estão em risco neste momento e $openTaskCount tarefas abertas ainda precisam da atenção do gerente.';
  }

  @override
  String get managerDashboardNoLiveShiftsSummary =>
      'Nenhum turno ativo está fora do rumo neste momento. Use o painel abaixo para verificar prontidão e problemas recorrentes.';

  @override
  String get managerDashboardRefreshNow => 'Atualizar agora';

  @override
  String get managerDashboardReviewIssues => 'Revisar problemas';

  @override
  String get managerDashboardViewShiftReadiness => 'Ver prontidão dos turnos';

  @override
  String get managerDashboardHistoryReports => 'Histórico e relatórios';

  @override
  String get managerDashboardTodayAtRisk => 'Hoje em risco';

  @override
  String get managerDashboardTodayAtRiskSubtitle =>
      'Fila compacta de ação para o que precisa de atenção primeiro.';

  @override
  String get managerDashboardShiftReadiness => 'Prontidão dos turnos';

  @override
  String get managerDashboardShiftReadinessSubtitle =>
      'Painel ao vivo de progresso, trabalho aberto e saúde dos turnos.';

  @override
  String get managerDashboardNoScheduledShiftsYet =>
      'Ainda não há turnos programados';

  @override
  String get managerDashboardNoScheduledShiftsBody =>
      'Crie e execute turnos para ver a prontidão aqui.';

  @override
  String get managerDashboardRecurringIssues => 'Problemas recorrentes';

  @override
  String get managerDashboardRecurringIssuesSubtitle =>
      'Onde falhas e execuções fracas continuam aparecendo.';

  @override
  String get managerDashboardRecurringFailures => 'Falhas recorrentes';

  @override
  String get managerDashboardRecurringFailuresSubtitle =>
      'Classificadas pela taxa de falha nos últimos 30 dias.';

  @override
  String get managerDashboardNoRecurringFailuresYet =>
      'Ainda não há falhas recorrentes.';

  @override
  String get managerDashboardAtRiskShifts => 'Turnos em risco';

  @override
  String get managerDashboardAtRiskShiftsSubtitle =>
      'Turnos com as tendências de conclusão mais fracas nos últimos 30 dias.';

  @override
  String get managerDashboardNoAtRiskShifts =>
      'Nenhum turno em risco encontrado.';

  @override
  String get managerDashboardAllMissedTasksYesterday =>
      'Todas as tarefas perdidas de ontem';

  @override
  String get managerDashboardUnknownTask => 'Tarefa desconhecida';

  @override
  String get managerDashboardUnknownShift => 'Turno desconhecido';

  @override
  String get managerDashboardDoneToday => 'Concluídas hoje';

  @override
  String get adminSetupTourWelcomeTitle =>
      'Bem-vindo de volta — vamos mostrar o que mudou';

  @override
  String get adminSetupTourWelcomeDescription =>
      'A configuração foi atualizada para facilitar o gerenciamento de locais, equipe, turnos e modelos de checklist. Este tour rápido mostra o fluxo atualizado antes de você começar a editar.';

  @override
  String get adminSetupTourLocationTitle =>
      'Mantenha a configuração focada em um local';

  @override
  String get adminSetupTourLocationDescription =>
      'Mude aqui quando quiser focar em um restaurante. Turnos, acesso da equipe e modelos de checklist ficam mais fáceis de gerenciar quando você reduz o escopo para um único local.';

  @override
  String get adminSetupTourAreasTitle => 'Passe pela configuração por área';

  @override
  String get adminSetupTourAreasDescription =>
      'Use estas áreas rápidas de configuração para alternar entre Locais, Equipe, Turnos e Biblioteca de checklists sem perder o contexto.';

  @override
  String get adminSetupTourPanelTitle =>
      'Trabalhe em uma área de configuração por vez';

  @override
  String get adminSetupTourPanelDescription =>
      'O painel principal abaixo é onde você adiciona, edita e revisa a área de configuração atual. Mantenha o local selecionado e a área de configuração sincronizados enquanto organiza a operação.';

  @override
  String get adminSetupActiveLocation => 'Local ativo';

  @override
  String get adminSetupSelectLocation => 'Selecionar local';

  @override
  String get adminSetupAreas => 'Áreas de configuração';

  @override
  String get adminViewLocations => 'Locais';

  @override
  String get adminViewTeam => 'Equipe';

  @override
  String get adminViewShifts => 'Turnos';

  @override
  String get adminViewChecklistLibrary => 'Biblioteca de checklists';

  @override
  String get adminViewEyebrowPlaces => 'Locais';

  @override
  String get adminViewEyebrowPeople => 'Equipe';

  @override
  String get adminViewEyebrowOperations => 'Operações';

  @override
  String get adminViewEyebrowChecklistTemplates => 'Modelos de checklist';

  @override
  String get adminViewLocationsSubtitle =>
      'Gerencie os locais onde sua equipe opera e mantenha a configuração ancorada em locais reais.';

  @override
  String get adminViewTeamSubtitle =>
      'Convide funcionários, defina acessos e mantenha cada função alinhada aos locais certos.';

  @override
  String get adminViewShiftsSubtitle =>
      'Defina quando o trabalho acontece e vincule o fluxo certo a cada turno.';

  @override
  String get adminViewChecklistLibrarySubtitle =>
      'Mantenha modelos reutilizáveis de checklist para abertura, fechamento, preparo e rotinas recorrentes.';

  @override
  String get adminSetupHeroTitle => 'Configuração operacional';

  @override
  String get adminSetupAllLocations => 'Todos os locais';

  @override
  String get adminWorkflowNoneAttached => 'Nenhum fluxo vinculado ainda';

  @override
  String get adminWorkflowOneAttached => '1 fluxo vinculado';

  @override
  String adminWorkflowManyAttached(int count) {
    return '$count fluxos vinculados';
  }

  @override
  String adminWorkflowTitle(String name) {
    return 'Fluxo de $name';
  }

  @override
  String get adminNoOrganizationDataAvailable =>
      'Não há dados da organização disponíveis';

  @override
  String adminErrorLoadingUsers(String error) {
    return 'Erro ao carregar usuários: $error';
  }

  @override
  String adminErrorLoadingLocations(String error) {
    return 'Erro ao carregar locais: $error';
  }

  @override
  String get adminNoTeamMembersFound => 'Nenhum membro da equipe encontrado';

  @override
  String get adminInviteTeamToGetStarted => 'Convide sua equipe para começar';

  @override
  String get adminUnnamedUser => 'Usuário sem nome';

  @override
  String get adminDeleteUserTitle => 'Excluir usuário';

  @override
  String get adminDeleteUserBody =>
      'Tem certeza de que deseja excluir este usuário? Esta ação não pode ser desfeita.';

  @override
  String get adminNoLocationsFound => 'Nenhum local encontrado';

  @override
  String get adminAddLocationToGetStarted => 'Adicione um local para começar';

  @override
  String get adminNoShiftsForSelectedLocation =>
      'Nenhum turno encontrado para o local selecionado';

  @override
  String get adminNoShiftsFound => 'Nenhum turno encontrado';

  @override
  String get adminCreateShiftsAttachWorkflows =>
      'Crie turnos e depois vincule os fluxos de trabalho';

  @override
  String get webAdminWorkflowLabel => 'Fluxo';

  @override
  String get webAdminWorkflowCreated => 'Fluxo criado com sucesso';

  @override
  String get webAdminScheduleDaily => 'Diariamente';

  @override
  String get webAdminDayMon => 'Seg';

  @override
  String get webAdminDayTue => 'Ter';

  @override
  String get webAdminDayWed => 'Qua';

  @override
  String get webAdminDayThu => 'Qui';

  @override
  String get webAdminDayFri => 'Sex';

  @override
  String get webAdminDaySat => 'Sáb';

  @override
  String get webAdminDaySun => 'Dom';

  @override
  String get webAdminSidebarSubtitle =>
      'Configure locais, pessoas, turnos e fluxos reutilizáveis.';

  @override
  String get webAdminSetupWorkspace => 'Espaço de configuração';

  @override
  String get webAdminScope => 'Escopo';

  @override
  String get webAdminAllActive => 'Todos ativos';

  @override
  String webAdminSearchHint(String name) {
    return 'Buscar $name...';
  }

  @override
  String webAdminAddItem(String name) {
    return 'Adicionar $name';
  }

  @override
  String get webAdminSectionEyebrowShifts => 'Configuração operacional';

  @override
  String get webAdminSectionEyebrowChecklists => 'Modelos de checklist';

  @override
  String get webAdminSectionEyebrowUsers => 'Pessoas e acessos';

  @override
  String get webAdminSectionEyebrowLocations => 'Estrutura do negócio';

  @override
  String get webAdminSectionTitleShifts =>
      'Monte turnos em torno de fluxos reais de serviço';

  @override
  String get webAdminSectionTitleChecklists =>
      'Mantenha uma biblioteca de fluxos organizada';

  @override
  String get webAdminSectionTitleUsers =>
      'Gerencie sua equipe com menos atrito';

  @override
  String get webAdminSectionTitleLocations =>
      'Mantenha cada local pronto para operar';

  @override
  String get webAdminSectionSubtitleShifts =>
      'Defina quando o trabalho acontece, a quem ele pertence e qual modelo de fluxo roda durante aquele turno.';

  @override
  String get webAdminSectionSubtitleChecklists =>
      'Crie modelos reutilizáveis de checklist para abertura, fechamento, preparo e procedimentos recorrentes em toda a operação.';

  @override
  String get webAdminSectionSubtitleUsers =>
      'Convide gerentes e funcionários, atribua seus locais e mantenha o acesso alinhado com a forma como o negócio funciona.';

  @override
  String get webAdminSectionSubtitleLocations =>
      'Configure os locais onde sua equipe opera e use-os para organizar turnos, equipe e cobertura de fluxos.';

  @override
  String get webAdminSectionTableSubtitleShifts =>
      'Configuração centrada em turnos com visibilidade direta do fluxo.';

  @override
  String get webAdminSectionTableSubtitleChecklists =>
      'Os modelos de checklist permanecem reutilizáveis aqui e são vinculados pelos turnos.';

  @override
  String get webAdminSectionTableSubtitleUsers =>
      'Pessoas, funções, estado do convite e cobertura por local.';

  @override
  String get webAdminSectionTableSubtitleLocations =>
      'Seus locais ativos, endereços e cobertura operacional.';

  @override
  String get webAdminTabShift => 'Turno';

  @override
  String get webAdminTabTemplate => 'Modelo';

  @override
  String get webAdminTabTeamMember => 'Membro da equipe';

  @override
  String get webAdminTabLocation => 'Local';

  @override
  String get webAdminEmptyTitleShifts => 'Ainda não há turnos criados';

  @override
  String get webAdminEmptyDescriptionShifts =>
      'Crie seu primeiro turno para definir quando o trabalho acontece, quem o executa e qual fluxo deve rodar. Os turnos são o principal lugar para configurar a operação.';

  @override
  String get webAdminEmptyActionShifts => 'Criar seu primeiro turno';

  @override
  String get webAdminEmptySupportLabelShifts => 'Próximo passo';

  @override
  String get webAdminEmptySupportValueShifts => 'Vincular fluxo';

  @override
  String get webAdminEmptySecondaryLabelShifts => 'Recomendado';

  @override
  String get webAdminEmptySecondaryValueShifts => 'Comece pela abertura';

  @override
  String get webAdminEmptyTitleChecklists =>
      'Ainda não há modelos de checklist';

  @override
  String get webAdminEmptyDescriptionChecklists =>
      'Crie modelos reutilizáveis de checklist para abertura, fechamento, preparo e outros trabalhos repetíveis. A maioria dos proprietários os vinculará pela tela de Turnos.';

  @override
  String get webAdminEmptyActionChecklists => 'Criar seu primeiro modelo';

  @override
  String get webAdminEmptySupportLabelChecklists => 'Melhor uso';

  @override
  String get webAdminEmptySupportValueChecklists => 'Fluxos reutilizáveis';

  @override
  String get webAdminEmptySecondaryLabelChecklists => 'Mais comum';

  @override
  String get webAdminEmptySecondaryValueChecklists => 'Abertura + fechamento';

  @override
  String get webAdminEmptyTitleUsers => 'Ainda não há membros da equipe';

  @override
  String get webAdminEmptyDescriptionUsers =>
      'Convide membros da equipe para entrarem na sua organização. Você pode atribuir funções diferentes e controlar quais locais eles podem acessar.';

  @override
  String get webAdminEmptyActionUsers =>
      'Adicionar seu primeiro membro da equipe';

  @override
  String get webAdminEmptySupportLabelUsers => 'Mais útil';

  @override
  String get webAdminEmptySupportValueUsers => 'Convide gerentes primeiro';

  @override
  String get webAdminEmptySecondaryLabelUsers => 'Status';

  @override
  String get webAdminEmptySecondaryValueUsers => 'Acompanhe convites aqui';

  @override
  String get webAdminEmptyTitleLocations => 'Ainda não há locais adicionados';

  @override
  String get webAdminEmptyDescriptionLocations =>
      'Configure os locais do seu negócio para organizar turnos, atribuir funcionários e acompanhar operações. Cada local pode ter seus próprios turnos, checklists e membros da equipe.';

  @override
  String get webAdminEmptyActionLocations => 'Adicionar seu primeiro local';

  @override
  String get webAdminEmptySupportLabelLocations => 'Base';

  @override
  String get webAdminEmptySupportValueLocations =>
      'Monte a configuração em torno dos locais';

  @override
  String get webAdminEmptySecondaryLabelLocations => 'Depois disso';

  @override
  String get webAdminEmptySecondaryValueLocations => 'Crie turnos';

  @override
  String get webAdminEmptyFooter =>
      'Mantenha a configuração leve: crie o local, adicione sua equipe e depois monte os turnos com fluxos vinculados.';

  @override
  String get webAdminColumnShiftName => 'Nome do turno';

  @override
  String get webAdminColumnTime => 'Horário';

  @override
  String get webAdminColumnSchedule => 'Agenda';

  @override
  String get webAdminColumnStatus => 'Status';

  @override
  String get webAdminColumnActions => 'Ações';

  @override
  String get webAdminColumnTemplateName => 'Nome do modelo';

  @override
  String get webAdminColumnDescription => 'Descrição';

  @override
  String get webAdminColumnTasks => 'Tarefas';

  @override
  String get webAdminColumnUsedInShifts => 'Usado em turnos';

  @override
  String get webAdminColumnLocationName => 'Nome do local';

  @override
  String get webAdminColumnAddress => 'Endereço';

  @override
  String get webAdminStatusActive => 'Ativo';

  @override
  String get webAdminStatusInactive => 'Inativo';

  @override
  String get webAdminStatusArchived => 'Arquivado';

  @override
  String get webAdminActionEdit => 'Editar';

  @override
  String get webAdminActionDuplicate => 'Duplicar';

  @override
  String get webAdminActionArchive => 'Arquivar';

  @override
  String get webAdminActionRestore => 'Restaurar';

  @override
  String get webAdminActionCreateWorkflow => 'Criar fluxo';

  @override
  String get webAdminActionEditWorkflow => 'Editar fluxo';

  @override
  String get webAdminActionDeactivate => 'Desativar';

  @override
  String get webAdminActionActivate => 'Ativar';

  @override
  String get webAdminActionDeleteUser => 'Excluir usuário';

  @override
  String get webAdminNoDescription => 'Sem descrição';

  @override
  String webAdminTaskCount(int count) {
    return '$count tarefas';
  }

  @override
  String get webAdminDeleteShiftTitle => 'Excluir turno?';

  @override
  String webAdminDeleteShiftBody(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get webAdminShiftUpdated => 'Turno atualizado com sucesso';

  @override
  String webAdminShiftUpdateFailed(String error) {
    return 'Falha ao atualizar turno: $error';
  }

  @override
  String get webAdminChecklistUpdateFailed => 'Falha ao atualizar modelo';

  @override
  String get webAdminDeleteTemplateTitle => 'Excluir modelo?';

  @override
  String webAdminDeleteTemplateBody(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get webAdminTemplateDeleted => 'Modelo excluído com sucesso';

  @override
  String webAdminTemplateDeleteFailed(String error) {
    return 'Falha ao excluir modelo: $error';
  }

  @override
  String webAdminCopyName(String name) {
    return '$name (Cópia)';
  }

  @override
  String get webAdminLocationDuplicated => 'Local duplicado com sucesso';

  @override
  String get webAdminDuplicateFailed => 'Falha ao duplicar item';

  @override
  String get webAdminShiftCreated => 'Turno criado com sucesso';

  @override
  String get webAdminShiftSaved => 'Turno atualizado com sucesso';

  @override
  String get webAdminShiftEditorOpenFailed =>
      'Falha ao abrir o editor de turno';

  @override
  String get webAdminShiftDuplicated => 'Turno duplicado com sucesso';

  @override
  String webAdminShiftDuplicateFailed(String error) {
    return 'Falha ao duplicar turno: $error';
  }

  @override
  String get webAdminShiftArchived => 'Turno arquivado com sucesso';

  @override
  String get webAdminShiftRestored => 'Turno restaurado com sucesso';

  @override
  String get webAdminTemplateCreated => 'Modelo criado com sucesso';

  @override
  String get webAdminTemplateSaved => 'Modelo atualizado com sucesso';

  @override
  String webAdminTemplateSaveFailed(String error) {
    return 'Falha ao salvar modelo: $error';
  }

  @override
  String get webAdminTemplateEditorOpenFailed =>
      'Falha ao abrir o editor de modelo';

  @override
  String get webAdminTemplateDuplicated => 'Modelo duplicado com sucesso';

  @override
  String webAdminTemplateDuplicateFailed(String error) {
    return 'Falha ao duplicar modelo: $error';
  }

  @override
  String get webAdminTemplateArchived => 'Modelo arquivado com sucesso';

  @override
  String get webAdminTemplateRestored => 'Modelo restaurado com sucesso';

  @override
  String get webAdminUserDeactivated => 'Usuário desativado com sucesso';

  @override
  String get webAdminUserActivated => 'Usuário ativado com sucesso';

  @override
  String webAdminUserUpdateFailed(String error) {
    return 'Falha ao atualizar usuário: $error';
  }

  @override
  String get webAdminLocationCreated => 'Local criado com sucesso';

  @override
  String get webAdminLocationSaved => 'Local atualizado com sucesso';

  @override
  String webAdminLocationUpdateFailed(String error) {
    return 'Falha ao atualizar local: $error';
  }

  @override
  String get webAdminLocationArchived => 'Local arquivado com sucesso';

  @override
  String get webAdminLocationRestored => 'Local restaurado com sucesso';

  @override
  String get webAdminDeleteLocationTitle => 'Excluir local?';

  @override
  String webAdminDeleteLocationBody(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get webAdminLocationDeleted => 'Local excluído com sucesso';

  @override
  String webAdminLocationDeleteFailed(String error) {
    return 'Falha ao excluir local: $error';
  }

  @override
  String get webAdminDeleteUserTitle => 'Excluir usuário?';

  @override
  String webAdminDeleteUserBody(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get webAdminUserDeleted => 'Usuário excluído com sucesso';

  @override
  String webAdminUserDeleteFailed(String error) {
    return 'Falha ao excluir usuário: $error';
  }

  @override
  String webAdminWorkflowSuggestion(String name) {
    return 'fluxo de $name';
  }

  @override
  String webAdminStreamError(String error) {
    return 'Erro: $error';
  }

  @override
  String get webAdminUnnamedShift => 'Turno sem nome';

  @override
  String get webAdminUnnamedTemplate => 'Modelo sem nome';

  @override
  String get webAdminUnnamedLocation => 'Local sem nome';

  @override
  String get webAdminUnknownUser => 'Usuário desconhecido';

  @override
  String get webAdminNoEmail => 'Sem e-mail';

  @override
  String get webAdminNoAddress => 'Sem endereço';

  @override
  String guidedTourStepCounter(int current, int total) {
    return 'Etapa $current de $total';
  }

  @override
  String get guidedTourSkip => 'Pular';

  @override
  String get guidedTourLearnMore => 'Saiba mais';

  @override
  String get guidedTourBack => 'Voltar';

  @override
  String get guidedTourNext => 'Próximo';

  @override
  String get guidedTourDone => 'Concluir';

  @override
  String get guidedTourLanguageFeatureTitle => 'Novo: suporte de idioma';

  @override
  String get guidedTourLanguageFeatureBody =>
      'Agora você pode alternar entre inglês, espanhol e português a qualquer momento em Idioma nas Configurações.';

  @override
  String get releaseDialogUpdateTitle =>
      'Uma grande atualização está disponível';

  @override
  String get releaseDialogUpdateSubtitle =>
      'Atualize ou recarregue para ver a experiência mais recente, as opções de idioma e o tour guiado.';

  @override
  String get releaseDialogWhatsNewSubtitle =>
      'Uma experiência renovada está disponível, incluindo atualizações no tour guiado e suporte de idioma.';

  @override
  String get releaseDialogNotNow => 'Agora não';

  @override
  String get releaseDialogTakeGuidedTour => 'Fazer tour guiado';

  @override
  String get releaseDialogRefreshNow => 'Recarregar agora';

  @override
  String get releaseDialogUpdateNow => 'Atualizar agora';

  @override
  String get releaseDialogOkay => 'Entendi';

  @override
  String get releaseDialogMajorReleaseBadge => 'Grande lançamento';

  @override
  String get releaseDialogNewExperienceBadge => 'Nova experiência';

  @override
  String get releaseDialogWhatChanged => 'O que mudou';

  @override
  String get releaseDialogLanguageFeatureTitle => 'Novo: suporte de idioma';

  @override
  String get releaseDialogLanguageFeatureBody =>
      'Inglês, espanhol e português agora estão disponíveis em Idioma nas Configurações.';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get notificationsViewAction => 'Ver';

  @override
  String get quickPdfViewerDocumentTitle => 'Documento';

  @override
  String get quickPdfViewerTrainingDocumentTitle => 'Documento de treinamento';

  @override
  String get quickPdfViewerDescription =>
      'Este documento será aberto no visualizador nativo do seu dispositivo para a melhor experiência.';

  @override
  String get quickPdfViewerOpenDocument => 'Abrir documento';

  @override
  String get quickPdfViewerCopyLink => 'Copiar link';

  @override
  String get quickPdfViewerShare => 'Compartilhar';

  @override
  String get quickPdfViewerHelpBody =>
      'Os documentos são abertos no visualizador integrado do seu dispositivo para melhor desempenho e suporte de recursos.';

  @override
  String get quickPdfViewerOpenFailed =>
      'Não foi possível abrir o documento. Verifique sua conexão com a internet.';

  @override
  String quickPdfViewerOpenError(String error) {
    return 'Erro ao abrir o documento: $error';
  }

  @override
  String get quickPdfViewerCopied =>
      'Link do documento copiado para a área de transferência';

  @override
  String get quickPdfViewerShareFailed =>
      'Não foi possível compartilhar o documento';

  @override
  String get notificationSettingsTitle => 'Configurações de notificações';

  @override
  String get notificationSettingsTestTooltip => 'Testar notificações';

  @override
  String get notificationPermissionTitle => 'Fique por dentro com o Hands';

  @override
  String get notificationPermissionBody =>
      'Receba notificações sobre mudanças de escala, lembretes de turno e avisos importantes da sua equipe.';

  @override
  String get notificationSettingsQuickActions => 'Ações rápidas';

  @override
  String get notificationSettingsSubscribeTopics => 'Inscrever-se em tópicos';

  @override
  String get notificationSettingsSystemSettings => 'Configurações do sistema';

  @override
  String get notificationSettingsTestTitle =>
      'Teste de configuração de notificações';

  @override
  String notificationSettingsPermission(String value) {
    return 'Permissão: $value';
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
  String get notificationSettingsNone => 'Nenhum';

  @override
  String get notificationSettingsReady => '✅ Pronto';

  @override
  String get notificationSettingsNotReady => '❌ Não pronto';

  @override
  String get notificationOnboardingStayConnected => 'Mantenha-se conectado';

  @override
  String get notificationOnboardingBody =>
      'Receba notificações sobre:\n• Atualizações de escala\n• Lembretes de turno\n• Avisos importantes';

  @override
  String get notificationOnboardingEnableTitle => 'Ativar notificações';

  @override
  String get notificationOnboardingEnableBody =>
      'Só enviaremos notificações relevantes para sua escala de trabalho e atualizações importantes.';

  @override
  String get notificationOnboardingSkip => 'Pular por enquanto';

  @override
  String get checklistSheetInfoLabel => 'Informações';

  @override
  String get checklistSheetNewChecklist => 'Novo checklist';

  @override
  String get checklistSheetEditChecklist => 'Editar checklist';

  @override
  String get checklistSheetSaveChecklist => 'Salvar checklist';

  @override
  String get checklistSheetStepBasics => 'Básico';

  @override
  String get checklistSheetStepTasks => 'Tarefas';

  @override
  String get checklistSheetStepAdvanced => 'Avançado';

  @override
  String get checklistSheetNameRequired => 'O nome do checklist é obrigatório.';

  @override
  String get checklistSheetAddOneTask => 'Adicione pelo menos uma tarefa.';

  @override
  String get checklistSheetAllTasksNamed =>
      'Todas as tarefas precisam ter nome.';

  @override
  String get checklistSheetInfoTipBasics =>
      'Dê um nome a este modelo de fluxo de trabalho e adicione uma descrição curta.';

  @override
  String get checklistSheetBasicsIntro =>
      'Insira as informações básicas deste modelo:';

  @override
  String get checklistSheetTemplateName => 'Nome do modelo *';

  @override
  String get checklistSheetTemplateNameHint =>
      'ex.: Abertura do bar, Fechamento da cozinha';

  @override
  String get checklistSheetDescriptionOptional => 'Descrição (opcional)';

  @override
  String get checklistSheetDescriptionHint => 'Breve descrição deste checklist';

  @override
  String get checklistSheetNoShiftsAttach =>
      'Nenhum turno está disponível para vincular agora.';

  @override
  String get checklistSheetNoShiftsFound =>
      'Nenhum turno encontrado para este local. Crie os turnos primeiro.';

  @override
  String get checklistSheetShiftTip =>
      'Selecione em quais turnos este checklist aparece. Você pode deixar isso vazio agora e vinculá-lo depois na tela de Turnos.';

  @override
  String get checklistSheetSelectShifts =>
      'Selecione quais turnos devem usar este checklist:';

  @override
  String get checklistSheetTasksTip =>
      'Toque na câmera para exigir uma foto. Se a foto não for enviada pela equipe, os administradores serão avisados.';

  @override
  String get checklistSheetTasksIntro =>
      'Adicione tarefas ao seu checklist. Arraste para reordenar:';

  @override
  String get checklistSheetNoTasks =>
      'Nenhuma tarefa adicionada ainda. Toque em \"Adicionar tarefa\" para começar.';

  @override
  String get checklistSheetAddTask => 'Adicionar tarefa';

  @override
  String get checklistSheetAdvancedTip =>
      'As configurações avançadas são opcionais. Use-as se quiser limitar quem pode ver este checklist ou vinculá-lo agora a um ou mais turnos.';

  @override
  String get checklistSheetVisibilityByJobType =>
      'Visibilidade por tipo de cargo';

  @override
  String get checklistSheetAssignToShifts => 'Vincular a turnos';

  @override
  String get checklistSheetSpanishTranslations => 'Traduções em espanhol';

  @override
  String get checklistSheetPortugueseTranslations => 'Traduções em português';

  @override
  String get checklistSheetSpanishTip =>
      'Opcional: adicione versões em espanhol deste modelo e dos nomes das tarefas. O inglês continua como fallback quando um campo em espanhol fica vazio.';

  @override
  String get checklistSheetTemplateNameSpanish => 'Nome do modelo (espanhol)';

  @override
  String get checklistSheetTemplateNameSpanishHint => 'ex.: Apertura del bar';

  @override
  String get checklistSheetDescriptionSpanish => 'Descrição (espanhol)';

  @override
  String get checklistSheetDescriptionSpanishHint =>
      'Breve descrição em espanhol';

  @override
  String get checklistSheetAddTasksForSpanish =>
      'Adicione tarefas primeiro para incluir rótulos de tarefas em espanhol.';

  @override
  String get checklistSheetSpanishTaskLabels =>
      'Rótulos das tarefas em espanhol';

  @override
  String checklistSheetTaskSpanish(int index) {
    return 'Tarefa $index (espanhol)';
  }

  @override
  String get checklistSheetSpanishTaskLabelHint =>
      'Rótulo da tarefa em espanhol';

  @override
  String checklistSheetSpanishFor(String name) {
    return 'Espanhol para: $name';
  }

  @override
  String get checklistSheetPortugueseTip =>
      'Opcional: adicione versões em português deste modelo e dos nomes das tarefas. O inglês continua como fallback quando um campo em português fica vazio.';

  @override
  String get checklistSheetTemplateNamePortuguese =>
      'Nome do modelo (português)';

  @override
  String get checklistSheetTemplateNamePortugueseHint => 'ex.: Abertura do bar';

  @override
  String get checklistSheetDescriptionPortuguese => 'Descrição (português)';

  @override
  String get checklistSheetDescriptionPortugueseHint =>
      'Breve descrição em português';

  @override
  String get checklistSheetAddTasksForPortuguese =>
      'Adicione tarefas primeiro para incluir rótulos de tarefas em português.';

  @override
  String get checklistSheetPortugueseTaskLabels =>
      'Rótulos das tarefas em português';

  @override
  String checklistSheetTaskPortuguese(int index) {
    return 'Tarefa $index (português)';
  }

  @override
  String get checklistSheetPortugueseTaskLabelHint =>
      'Rótulo da tarefa em português';

  @override
  String checklistSheetPortugueseFor(String name) {
    return 'Português para: $name';
  }

  @override
  String checklistSheetTask(int index) {
    return 'Tarefa $index';
  }

  @override
  String get checklistSheetTaskHint => 'Digite a descrição da tarefa';

  @override
  String get checklistSheetDeleteTask => 'Excluir tarefa';

  @override
  String get checklistSheetPhotoRequired => 'Foto obrigatória';

  @override
  String get checklistSheetNoPhotoRequired => 'Sem foto obrigatória';

  @override
  String get checklistSheetTaskName => 'Nome da tarefa';

  @override
  String get checklistSheetPhoto => 'Foto';

  @override
  String checklistSheetLoadShiftsError(String error) {
    return 'Erro ao carregar turnos: $error';
  }

  @override
  String get checklistSheetJobTypesTip =>
      'Os tipos de cargo controlam quem verá este checklist. Deixe vazio para torná-lo visível para todos no turno.';

  @override
  String get checklistSheetJobTypesIntro =>
      'Opcionalmente, restrinja este checklist a pessoas com estes tipos de cargo. Deixe vazio para deixá-lo visível para todos.';

  @override
  String get checklistSheetManage => 'Gerenciar';

  @override
  String get checklistSheetNoJobTypes =>
      'Nenhum tipo de cargo encontrado ainda. Use Gerenciar para criar o primeiro.';

  @override
  String get checklistSheetAddJobType => 'Adicionar tipo de cargo';

  @override
  String get checklistSheetAddJobTypeHint => 'ex.: Lavador de louça';

  @override
  String get checklistSheetAdd => 'Adicionar';

  @override
  String checklistSheetSaveFailed(String error) {
    return 'Falha ao salvar checklist: $error';
  }

  @override
  String shiftSheetLoadDataError(String error) {
    return 'Erro ao carregar dados: $error';
  }

  @override
  String get shiftSheetSavedSuccess => 'Agenda do turno atualizada com sucesso';

  @override
  String shiftSheetSaveError(String error) {
    return 'Erro ao salvar agenda: $error';
  }

  @override
  String get shiftSheetAddRequiredRole => 'Adicionar função obrigatória';

  @override
  String get shiftSheetAlreadyAdded => 'Já adicionada';

  @override
  String shiftSheetAssignedCount(int assigned, int required) {
    return '$assigned de $required atribuídos';
  }

  @override
  String get shiftSheetRequiredRoles => 'Funções obrigatórias';

  @override
  String get shiftSheetAddRole => 'Adicionar função';

  @override
  String get shiftSheetNoRolesAssigned =>
      'Nenhuma função atribuída a este turno. Toque em \"Adicionar função\" para incluir as posições necessárias.';

  @override
  String get shiftSheetAssignedUsers => 'Usuários atribuídos';

  @override
  String get shiftSheetNoUsersAssigned => 'Nenhum usuário atribuído ainda.';

  @override
  String get shiftSheetAvailableUsers =>
      'Usuários disponíveis (funções compatíveis)';

  @override
  String get shiftSheetOtherUsers => 'Outros usuários (sem função compatível)';

  @override
  String shiftSheetLoadUsersError(String error) {
    return 'Erro ao carregar usuários: $error';
  }

  @override
  String get shiftSheetNoOtherUsers => 'Nenhum outro usuário disponível';

  @override
  String get shiftSheetSaveSchedule => 'Salvar agenda';

  @override
  String get shiftSheetUnknownRole => 'Função desconhecida';

  @override
  String shiftSheetRequiredCount(int count) {
    return 'Necessário: $count';
  }

  @override
  String get shiftSheetDecreaseCount => 'Diminuir quantidade';

  @override
  String get shiftSheetIncreaseCount => 'Aumentar quantidade';

  @override
  String get shiftSheetRemoveRole => 'Remover função';

  @override
  String get shiftSheetUnknownUserInitial => 'U';

  @override
  String shiftSheetCheckAssignmentsError(String error) {
    return 'Erro ao verificar atribuições: $error';
  }

  @override
  String get shiftSheetAlreadyAssignedAnotherShift =>
      'Já atribuído a outro turno neste dia';

  @override
  String get notificationTopicsTitle => 'Tipos de notificação';

  @override
  String get notificationTopicsIntro =>
      'Escolha quais atualizações você quer acompanhar:';

  @override
  String get notificationTopicsScheduleUpdates =>
      'Atualizações de agenda avisam quando seus turnos mudarem.';

  @override
  String get notificationTopicsShiftReminders =>
      'Lembretes de turno ajudam você a chegar preparado para o trabalho atribuído.';

  @override
  String get notificationTopicsGeneralAnnouncements =>
      'Avisos gerais compartilham atualizações mais amplas da equipe e da empresa.';

  @override
  String get notificationTopicsGotIt => 'Entendi';

  @override
  String get notificationTypesLearnMore =>
      'Saiba mais sobre os tipos de notificação';

  @override
  String get notificationTypesTitle => 'Tipos de notificações';

  @override
  String get notificationPushTitle => 'Notificações push';

  @override
  String get notificationPushEnabled =>
      'As notificações push estão ativadas neste dispositivo.';

  @override
  String get notificationPushTapToEnable =>
      'Toque em ativar para receber alertas neste dispositivo.';

  @override
  String get notificationEnable => 'Ativar';

  @override
  String get notificationTypeScheduleUpdates => 'Atualizações de agenda';

  @override
  String get notificationTypeScheduleUpdatesBody =>
      'Receba avisos quando seus turnos forem adicionados, removidos ou alterados.';

  @override
  String get notificationTypeShiftReminders => 'Lembretes de turno';

  @override
  String get notificationTypeShiftRemindersBody =>
      'Receba lembretes antes do início dos próximos turnos.';

  @override
  String get notificationTypeGeneralAnnouncements => 'Avisos gerais';

  @override
  String get notificationTypeGeneralAnnouncementsBody =>
      'Fique por dentro das novidades da equipe e dos avisos importantes.';

  @override
  String get notificationTypeEmail => 'Notificações por e-mail';

  @override
  String get notificationTypeEmailBody =>
      'Receba também por e-mail as atualizações mais importantes.';

  @override
  String get notificationDebugInfo => 'Informações de depuração';

  @override
  String get notificationFcmToken => 'Token FCM';

  @override
  String get notificationNoToken => 'Ainda não há token disponível';

  @override
  String get notificationTokenCopied => 'Token copiado';

  @override
  String get pushPermissionExplanationBody =>
      'Ative as notificações para receber lembretes de turno, mudanças na agenda e atualizações importantes da equipe imediatamente.';

  @override
  String get pushPermissionNotNow => 'Agora não';

  @override
  String get pushPermissionEnabledSuccess => 'As notificações foram ativadas.';

  @override
  String get pushPermissionError =>
      'Não foi possível ativar as notificações. Tente novamente.';

  @override
  String get pushPermissionDisabledTitle => 'As notificações estão desativadas';

  @override
  String get pushPermissionDisabledBody =>
      'Você ainda pode usar o app, mas pode perder lembretes e atualizações urgentes até reativar as notificações nas configurações do dispositivo.';

  @override
  String get pushPermissionMaybeLater => 'Talvez depois';

  @override
  String get pushPermissionOpenSettings => 'Abrir configurações';

  @override
  String get pushPermissionShortBody =>
      'Receba lembretes de turno, mudanças na agenda e atualizações da equipe neste dispositivo.';

  @override
  String get pushPermissionSettings => 'Configurações';

  @override
  String get pushPermissionRequestError =>
      'Não foi possível solicitar a permissão de notificações. Tente novamente.';

  @override
  String get availabilitySavedSuccess => 'Disponibilidade salva com sucesso.';

  @override
  String availabilitySaveError(String error) {
    return 'Erro ao salvar disponibilidade: $error';
  }

  @override
  String get availabilityTitle => 'Disponibilidade';

  @override
  String get availabilityShiftAvailability => 'Disponibilidade por turno';

  @override
  String get availabilityShiftAvailabilityBody =>
      'Defina em quais blocos de turno você geralmente pode trabalhar em cada dia.';

  @override
  String get availabilityEarliestStartTimes =>
      'Horários mais cedo para começar';

  @override
  String get availabilityEarliestStartBody =>
      'Defina o horário mais cedo em que você normalmente pode começar em cada dia da semana.';

  @override
  String get availabilityDefaultTime => '9:00';

  @override
  String get availabilityNotificationPreferences =>
      'Preferências de notificação';

  @override
  String get availabilityScheduleUpdatesBody =>
      'Mantenha-se informado quando sua agenda publicada mudar.';

  @override
  String get availabilityShiftRemindersBody =>
      'Receba lembretes antes do início dos seus turnos.';

  @override
  String get availabilityEmailNotificationsBody =>
      'Receba também as atualizações principais por e-mail.';

  @override
  String get availabilityPushNotificationsBody =>
      'Permita que este dispositivo receba alertas instantâneos.';

  @override
  String get availabilitySavePreferences => 'Salvar preferências';

  @override
  String get weekdayMonday => 'Segunda-feira';

  @override
  String get weekdayTuesday => 'Terça-feira';

  @override
  String get weekdayWednesday => 'Quarta-feira';

  @override
  String get weekdayThursday => 'Quinta-feira';

  @override
  String get weekdayFriday => 'Sexta-feira';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get shiftLabelMorning => 'Manhã';

  @override
  String get shiftLabelAfternoon => 'Tarde';

  @override
  String get shiftLabelEvening => 'Noite';

  @override
  String get shiftLabelNight => 'Madrugada';

  @override
  String get upgradeLocationsTitle => 'Adicionar locais';

  @override
  String get upgradeLocationsQuantity => 'Quantos locais você quer adicionar?';

  @override
  String upgradeLocationsSummary(int count, String price) {
    return 'Adicionar $count local(is) por $price por mês.';
  }

  @override
  String upgradeLocationsFailed(String error) {
    return 'Não foi possível atualizar os locais: $error';
  }

  @override
  String get upgradeLocationsAction => 'Atualizar e pagar';
}
