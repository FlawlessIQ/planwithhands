import 'package:flutter/material.dart';
import 'package:hands_app/features/help/models/help_topic.dart';

class HelpTopics {
  static final List<HelpTopic> all = [
    const HelpTopic(
      id: 'staff-first-shift',
      title: 'Get through your first shift',
      summary: 'Understand the flow from assigned shift to completed work.',
      whyItMatters:
          'Staff success depends on knowing where work appears, what to do next, and how to flag issues without stopping service.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.play_circle_outline_rounded,
      estimatedMinutes: 2,
      steps: [
        'Open Today’s Tasks and confirm the current location at the top of the screen.',
        'Check your shift hero to see whether you are in progress, starting soon, or finishing carryover.',
        'Use Next Up first. It shows the fastest path through your remaining work.',
        'Open Today’s Work if you need to see the full checklist for your shift.',
        'If a task needs a photo or note, use the inline actions instead of skipping it.',
      ],
      goodOutcome: [
        'You can see your shift clearly and know where to start.',
        'Next Up shrinks as you complete work.',
        'You finish tasks without hunting through completed items.',
      ],
      commonMistakes: [
        'Jumping into completed checklist sections instead of using Next Up.',
        'Ignoring carryover tasks when your manager expects them to be closed out.',
      ],
      localizedTitles: {
        'es': 'Completa tu primer turno',
        'pt': 'Conclua seu primeiro turno',
      },
      localizedSummaries: {
        'es':
            'Entiende el flujo desde un turno asignado hasta el trabajo completado.',
        'pt':
            'Entenda o fluxo desde um turno atribuido ate o trabalho concluido.',
      },
      localizedWhyItMatters: {
        'es':
            'El éxito del personal depende de saber dónde aparece el trabajo, qué hacer después y cómo marcar problemas sin frenar el servicio.',
        'pt':
            'O sucesso da equipe depende de saber onde o trabalho aparece, o que fazer em seguida e como sinalizar problemas sem atrapalhar o servico.',
      },
      localizedSteps: {
        'es': [
          'Abre Tareas de hoy y confirma la ubicación actual en la parte superior de la pantalla.',
          'Revisa la tarjeta principal de tu turno para ver si está en progreso, por comenzar o cerrando arrastres.',
          'Empieza por Siguiente. Muestra la ruta más rápida por el trabajo restante.',
          'Abre Trabajo de hoy si necesitas ver la lista completa del turno.',
          'Si una tarea necesita foto o nota, usa las acciones en línea en lugar de saltarla.',
        ],
        'pt': [
          'Abra Tarefas de hoje e confirme o local atual no topo da tela.',
          'Verifique o card principal do seu turno para ver se ele esta em andamento, vai comecar em breve ou esta fechando pendencias.',
          'Use Proximo item primeiro. Ele mostra o caminho mais rapido pelo trabalho restante.',
          'Abra Trabalho de hoje se precisar ver o checklist completo do seu turno.',
          'Se uma tarefa precisar de foto ou observacao, use as acoes na propria linha em vez de pular.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'Puedes ver tu turno con claridad y sabes por dónde empezar.',
          'Siguiente se reduce a medida que completas trabajo.',
          'Terminas tareas sin buscar entre elementos ya completados.',
        ],
        'pt': [
          'Voce consegue ver seu turno com clareza e sabe por onde comecar.',
          'Proximo item diminui conforme voce conclui o trabalho.',
          'Voce termina tarefas sem procurar em itens ja concluidos.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Entrar en secciones ya completadas en vez de usar Siguiente.',
          'Ignorar tareas arrastradas cuando tu gerente espera que las cierres.',
        ],
        'pt': [
          'Entrar em secoes ja concluidas em vez de usar Proximo item.',
          'Ignorar tarefas pendentes quando seu gerente espera que voce as feche.',
        ],
      },
      localizedKeywords: {
        'es': ['primer turno', 'inicio turno', 'tareas de hoy', 'siguiente'],
        'pt': [
          'primeiro turno',
          'inicio do turno',
          'tarefas de hoje',
          'proximo item',
        ],
      },
      keywords: ['first shift', 'start shift', 'today tasks', 'next up'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'staff-next-up',
      title: 'Use Next Up',
      summary:
          'Finish the next important task without scanning the full shift.',
      whyItMatters:
          'Next Up is the fastest and lowest-friction way to move through work on a busy floor.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.arrow_circle_right_outlined,
      estimatedMinutes: 1,
      steps: [
        'Open Today’s Tasks and look at the Next Up section under your shift summary.',
        'Start with the first incomplete task shown there.',
        'Use Complete, Photo, Add Note, or Can’t Do directly from the row.',
        'Return to Next Up after each action so the page can surface the next item automatically.',
      ],
      goodOutcome: [
        'You always know what to do next.',
        'You avoid wasting time scrolling through every checklist.',
      ],
      commonMistakes: [
        'Treating Next Up like a summary instead of the main execution flow.',
      ],
      localizedTitles: {'es': 'Usa Siguiente', 'pt': 'Use Proximo item'},
      localizedSummaries: {
        'es':
            'Completa la siguiente tarea importante sin revisar todo el turno.',
        'pt':
            'Conclua a proxima tarefa importante sem revisar o turno inteiro.',
      },
      localizedWhyItMatters: {
        'es':
            'Siguiente es la forma más rápida y con menos fricción de avanzar en el trabajo durante un turno ocupado.',
        'pt':
            'Proximo item e a forma mais rapida e com menos atrito de avancar no trabalho durante um turno corrido.',
      },
      localizedSteps: {
        'es': [
          'Abre Tareas de hoy y mira la sección Siguiente debajo del resumen de tu turno.',
          'Empieza con la primera tarea incompleta que aparece allí.',
          'Usa Completar, Foto, Agregar nota o No puedo directamente desde la fila.',
          'Vuelve a Siguiente después de cada acción para que la página muestre automáticamente el siguiente elemento.',
        ],
        'pt': [
          'Abra Tarefas de hoje e veja a secao Proximo item abaixo do resumo do seu turno.',
          'Comece pela primeira tarefa incompleta mostrada ali.',
          'Use Concluir, Foto, Adicionar observacao ou Nao consigo diretamente na linha.',
          'Volte para Proximo item depois de cada acao para que a pagina mostre automaticamente o proximo item.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'Siempre sabes qué hacer después.',
          'Evitas perder tiempo desplazándote por cada checklist.',
        ],
        'pt': [
          'Voce sempre sabe o que fazer em seguida.',
          'Evita perder tempo rolando por cada checklist.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Tratar Siguiente como un resumen en vez del flujo principal de ejecución.',
        ],
        'pt': [
          'Tratar Proximo item como um resumo em vez do fluxo principal de execucao.',
        ],
      },
      localizedKeywords: {
        'es': ['siguiente', 'siguiente tarea', 'qué sigue', 'lista de tareas'],
        'pt': [
          'proximo item',
          'proxima tarefa',
          'o que vem agora',
          'lista de tarefas',
        ],
      },
      keywords: ['next up', 'next task', 'what next', 'tasks list'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'staff-complete-task',
      title: 'Complete a task cleanly',
      summary:
          'Use the task row actions to finish work and keep the checklist accurate.',
      whyItMatters:
          'Clean task completion keeps shift progress reliable for both staff and managers.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.task_alt_rounded,
      estimatedMinutes: 1,
      steps: [
        'Open the task from Next Up or Today’s Work.',
        'Tap Complete if the task is done and no extra proof is needed.',
        'If the task requires supporting detail, add a note or photo before you finish it.',
        'Check that the task moves into completed status and the checklist progress updates.',
      ],
      goodOutcome: [
        'The task moves out of the active list.',
        'Checklist and shift progress increase immediately.',
      ],
      commonMistakes: [
        'Leaving required notes or photos until later and forgetting them.',
      ],
      localizedTitles: {
        'es': 'Completa una tarea correctamente',
        'pt': 'Conclua uma tarefa corretamente',
      },
      localizedSummaries: {
        'es':
            'Usa las acciones de la fila de tarea para terminar el trabajo y mantener el checklist preciso.',
        'pt':
            'Use as acoes da linha da tarefa para concluir o trabalho e manter o checklist correto.',
      },
      localizedWhyItMatters: {
        'es':
            'Completar tareas correctamente mantiene confiable el progreso del turno para el personal y los gerentes.',
        'pt':
            'Concluir tarefas corretamente mantem o progresso do turno confiavel para a equipe e os gerentes.',
      },
      localizedSteps: {
        'es': [
          'Abre la tarea desde Siguiente o Trabajo de hoy.',
          'Toca Completar si la tarea está hecha y no necesita evidencia adicional.',
          'Si la tarea requiere más detalle, agrega una nota o foto antes de terminarla.',
          'Confirma que la tarea pase a completada y que el progreso del checklist se actualice.',
        ],
        'pt': [
          'Abra a tarefa em Proximo item ou Trabalho de hoje.',
          'Toque em Concluir se a tarefa estiver pronta e nao precisar de prova extra.',
          'Se a tarefa precisar de mais detalhe, adicione uma observacao ou foto antes de concluir.',
          'Confirme que a tarefa foi marcada como concluida e que o progresso do checklist foi atualizado.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'La tarea sale de la lista activa.',
          'El progreso del checklist y del turno aumenta de inmediato.',
        ],
        'pt': [
          'A tarefa sai da lista ativa.',
          'O progresso do checklist e do turno aumenta imediatamente.',
        ],
      },
      localizedCommonMistakes: {
        'es': ['Dejar notas o fotos obligatorias para después y olvidarlas.'],
        'pt': [
          'Deixar observacoes ou fotos obrigatorias para depois e esquecer.',
        ],
      },
      localizedKeywords: {
        'es': ['completar tarea', 'terminar tarea', 'progreso checklist'],
        'pt': ['concluir tarefa', 'terminar tarefa', 'progresso do checklist'],
      },
      keywords: ['complete task', 'finish task', 'checklist progress'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
    ),
    const HelpTopic(
      id: 'staff-photo-required',
      title: 'Handle a photo-required task',
      summary: 'Attach proof when the task needs a visual record.',
      whyItMatters:
          'Photo-required tasks exist so managers can trust that high-importance work actually happened.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.photo_camera_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open the task row and use the Photo action.',
        'Take a clear, well-lit photo that shows the completed result.',
        'Review the upload and confirm the task is now ready to complete.',
        'Finish the task once the photo is attached successfully.',
      ],
      goodOutcome: [
        'Managers can review proof later without following up.',
        'The task stays compliant with the checklist rules.',
      ],
      commonMistakes: [
        'Uploading an unclear photo that does not show the completed result.',
        'Trying to complete the task before the upload finishes.',
      ],
      localizedTitles: {
        'es': 'Gestiona una tarea con foto obligatoria',
        'pt': 'Gerencie uma tarefa com foto obrigatoria',
      },
      localizedSummaries: {
        'es': 'Adjunta evidencia cuando la tarea necesita un registro visual.',
        'pt':
            'Anexe comprovacao quando a tarefa precisar de um registro visual.',
      },
      localizedWhyItMatters: {
        'es':
            'Las tareas con foto obligatoria existen para que los gerentes puedan confiar en que el trabajo importante realmente se hizo.',
        'pt':
            'Tarefas com foto obrigatoria existem para que os gerentes possam confiar que o trabalho importante realmente foi feito.',
      },
      localizedSteps: {
        'es': [
          'Abre la fila de la tarea y usa la acción Foto.',
          'Toma una foto clara y bien iluminada que muestre el resultado terminado.',
          'Revisa la carga y confirma que la tarea ya está lista para completarse.',
          'Termina la tarea cuando la foto esté adjunta correctamente.',
        ],
        'pt': [
          'Abra a linha da tarefa e use a acao Foto.',
          'Tire uma foto clara e bem iluminada que mostre o resultado concluido.',
          'Revise o envio e confirme que a tarefa esta pronta para ser concluida.',
          'Conclua a tarefa quando a foto estiver anexada com sucesso.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'Los gerentes pueden revisar la evidencia después sin hacer seguimiento.',
          'La tarea sigue cumpliendo con las reglas del checklist.',
        ],
        'pt': [
          'Os gerentes podem revisar a comprovacao depois sem precisar cobrar voce.',
          'A tarefa continua em conformidade com as regras do checklist.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Subir una foto poco clara que no muestre el resultado terminado.',
          'Intentar completar la tarea antes de que termine la carga.',
        ],
        'pt': [
          'Enviar uma foto pouco clara que nao mostre o resultado concluido.',
          'Tentar concluir a tarefa antes de o envio terminar.',
        ],
      },
      localizedKeywords: {
        'es': ['foto', 'camara', 'foto obligatoria', 'subir imagen'],
        'pt': ['foto', 'camera', 'foto obrigatoria', 'enviar imagem'],
      },
      keywords: ['photo', 'camera', 'required photo', 'upload image'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
    ),
    const HelpTopic(
      id: 'staff-blocked-task',
      title: 'Mark Can’t Do or blocked work',
      summary:
          'Use the blocked flow when work cannot be completed safely or correctly.',
      whyItMatters:
          'Blocked tasks help managers understand what stopped the work instead of leaving silent misses behind.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.report_problem_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open the task row and choose Can’t Do or Update Issue.',
        'Select the closest reason and add a clear note.',
        'Save the issue so the task appears as blocked instead of incomplete without context.',
        'Move on to the next task unless your manager asks for follow-up.',
      ],
      goodOutcome: [
        'The task remains visible with context for managers.',
        'Blocked work does not look like staff simply ignored it.',
      ],
      commonMistakes: [
        'Leaving the issue without a note when more context is needed.',
      ],
      localizedTitles: {
        'es': 'Marca trabajo bloqueado o No puedo',
        'pt': 'Marque trabalho bloqueado ou Nao consigo',
      },
      localizedSummaries: {
        'es':
            'Usa el flujo de bloqueo cuando el trabajo no puede completarse de forma segura o correcta.',
        'pt':
            'Use o fluxo de bloqueio quando o trabalho nao puder ser concluido com seguranca ou corretamente.',
      },
      localizedWhyItMatters: {
        'es':
            'Las tareas bloqueadas ayudan a los gerentes a entender qué impidió el trabajo en lugar de dejar omisiones silenciosas.',
        'pt':
            'Tarefas bloqueadas ajudam os gerentes a entender o que impediu o trabalho em vez de deixar falhas silenciosas.',
      },
      localizedSteps: {
        'es': [
          'Abre la fila de la tarea y elige No puedo o Actualizar problema.',
          'Selecciona el motivo más cercano y agrega una nota clara.',
          'Guarda el problema para que la tarea aparezca como bloqueada y no como incompleta sin contexto.',
          'Pasa a la siguiente tarea a menos que tu gerente pida seguimiento.',
        ],
        'pt': [
          'Abra a linha da tarefa e escolha Nao consigo ou Atualizar problema.',
          'Selecione o motivo mais proximo e adicione uma observacao clara.',
          'Salve o problema para que a tarefa apareca como bloqueada, e nao como incompleta sem contexto.',
          'Passe para a proxima tarefa, a menos que seu gerente peca acompanhamento.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'La tarea sigue visible con contexto para los gerentes.',
          'El trabajo bloqueado no parece que el personal simplemente lo ignoró.',
        ],
        'pt': [
          'A tarefa continua visivel com contexto para os gerentes.',
          'O trabalho bloqueado nao parece que a equipe simplesmente ignorou.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Dejar el problema sin una nota cuando hace falta más contexto.',
        ],
        'pt': [
          'Deixar o problema sem observacao quando e necessario mais contexto.',
        ],
      },
      localizedKeywords: {
        'es': ['bloqueado', 'no puedo', 'problema', 'faltan insumos'],
        'pt': ['bloqueado', 'nao consigo', 'problema', 'faltam suprimentos'],
      },
      keywords: ['blocked', 'cant do', 'can’t do', 'issue', 'missing supplies'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
    ),
    const HelpTopic(
      id: 'staff-carryover',
      title: 'Finish carryover from yesterday',
      summary:
          'Work through unfinished items from the prior day without losing focus on today’s shift.',
      whyItMatters:
          'Carryover makes missed work visible so it can be cleaned up instead of disappearing between shifts.',
      roles: [HelpRole.staff, HelpRole.manager],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.history_toggle_off_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open the Carryover from Yesterday section.',
        'Expand the affected shift and review the incomplete tasks.',
        'Complete the missed work if it is still valid, or mark the issue with context.',
        'Make sure the carryover count shrinks as you work through it.',
      ],
      goodOutcome: [
        'Carryover tasks no longer stay hidden across days.',
        'Managers can see exactly what was cleaned up or blocked.',
      ],
      commonMistakes: [
        'Ignoring carryover because it is visually separate from today’s shift.',
      ],
      localizedTitles: {
        'es': 'Termina los arrastres de ayer',
        'pt': 'Conclua as pendencias de ontem',
      },
      localizedSummaries: {
        'es':
            'Resuelve los elementos pendientes del día anterior sin perder el enfoque en el turno de hoy.',
        'pt':
            'Resolva os itens pendentes do dia anterior sem perder o foco no turno de hoje.',
      },
      localizedWhyItMatters: {
        'es':
            'Los arrastres hacen visible el trabajo perdido para que pueda limpiarse en vez de desaparecer entre turnos.',
        'pt':
            'As pendencias tornam o trabalho perdido visivel para que ele seja resolvido em vez de desaparecer entre turnos.',
      },
      localizedSteps: {
        'es': [
          'Abre la sección Arrastres de ayer.',
          'Expande el turno afectado y revisa las tareas incompletas.',
          'Completa el trabajo pendiente si sigue siendo válido o marca el problema con contexto.',
          'Confirma que el conteo de arrastres baja mientras avanzas.',
        ],
        'pt': [
          'Abra a secao Pendencias de ontem.',
          'Expanda o turno afetado e revise as tarefas incompletas.',
          'Conclua o trabalho pendente se ele ainda for valido ou marque o problema com contexto.',
          'Confirme que a contagem de pendencias diminui enquanto voce avanca.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'Las tareas arrastradas dejan de quedar ocultas entre días.',
          'Los gerentes pueden ver exactamente qué se resolvió o quedó bloqueado.',
        ],
        'pt': [
          'As tarefas pendentes deixam de ficar escondidas entre os dias.',
          'Os gerentes conseguem ver exatamente o que foi resolvido ou ficou bloqueado.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Ignorar los arrastres porque están visualmente separados del turno de hoy.',
        ],
        'pt': [
          'Ignorar as pendencias porque elas estao visualmente separadas do turno de hoje.',
        ],
      },
      localizedKeywords: {
        'es': ['arrastres', 'ayer', 'tareas perdidas', 'trabajo pendiente'],
        'pt': ['pendencias', 'ontem', 'tarefas perdidas', 'trabalho pendente'],
      },
      keywords: ['carryover', 'yesterday', 'missed tasks', 'unfinished work'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'staff-pick-up-shift',
      title: 'Pick up another shift',
      summary: 'Join an available shift when your role and location allow it.',
      whyItMatters:
          'Shift pickup helps the team stay flexible without losing checklist ownership and visibility.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.dailyWork,
      icon: Icons.add_task_outlined,
      estimatedMinutes: 1,
      steps: [
        'Open Today’s Tasks and choose Pick Up Another Shift.',
        'Review the available shifts for the current location.',
        'Join the shift that matches your role and time window.',
        'Confirm that the new shift appears in your work list.',
      ],
      goodOutcome: ['The additional shift appears clearly in Today’s Work.'],
      commonMistakes: [
        'Trying to pick up a shift while the wrong location is selected.',
      ],
      localizedTitles: {'es': 'Toma otro turno', 'pt': 'Assuma outro turno'},
      localizedSummaries: {
        'es':
            'Únete a un turno disponible cuando tu rol y ubicación lo permitan.',
        'pt':
            'Entre em um turno disponivel quando sua funcao e seu local permitirem.',
      },
      localizedWhyItMatters: {
        'es':
            'Tomar turnos ayuda al equipo a mantenerse flexible sin perder propiedad ni visibilidad del checklist.',
        'pt':
            'Assumir turnos ajuda a equipe a se manter flexivel sem perder a responsabilidade nem a visibilidade do checklist.',
      },
      localizedSteps: {
        'es': [
          'Abre Tareas de hoy y elige Tomar otro turno.',
          'Revisa los turnos disponibles para la ubicación actual.',
          'Únete al turno que coincida con tu rol y tu franja horaria.',
          'Confirma que el nuevo turno aparezca en tu lista de trabajo.',
        ],
        'pt': [
          'Abra Tarefas de hoje e escolha Assumir outro turno.',
          'Revise os turnos disponiveis para o local atual.',
          'Entre no turno que combine com sua funcao e sua faixa de horario.',
          'Confirme que o novo turno aparece na sua lista de trabalho.',
        ],
      },
      localizedGoodOutcome: {
        'es': ['El turno adicional aparece con claridad en Trabajo de hoy.'],
        'pt': ['O turno adicional aparece com clareza em Trabalho de hoje.'],
      },
      localizedCommonMistakes: {
        'es': [
          'Intentar tomar un turno mientras está seleccionada la ubicación incorrecta.',
        ],
        'pt': [
          'Tentar assumir um turno enquanto o local incorreto ainda esta selecionado.',
        ],
      },
      localizedKeywords: {
        'es': ['tomar turno', 'unirse turno', 'turnos disponibles'],
        'pt': ['assumir turno', 'entrar no turno', 'turnos disponiveis'],
      },
      keywords: ['pick up shift', 'join shift', 'available shifts'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
    ),
    const HelpTopic(
      id: 'staff-switch-location',
      title: 'Switch location',
      summary: 'Focus the app on the location you are working in right now.',
      whyItMatters:
          'Tasks, shifts, broadcasts, and documents can all depend on the active location.',
      roles: [HelpRole.staff, HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.account,
      icon: Icons.location_on_outlined,
      estimatedMinutes: 1,
      steps: [
        'Tap the current location chip or location card near the top of the screen.',
        'Choose the site you want to work in.',
        'Wait for the page to refresh before checking shifts, tasks, or messages.',
        'If the location is missing, ask an admin to assign it to your account.',
      ],
      goodOutcome: [
        'All location-specific content updates to the selected site.',
      ],
      commonMistakes: [
        'Looking for shifts or checklists while still scoped to the wrong location.',
      ],
      localizedTitles: {'es': 'Cambiar ubicación', 'pt': 'Trocar local'},
      localizedSummaries: {
        'es': 'Enfoca la app en la ubicación en la que estás trabajando ahora.',
        'pt':
            'Mantenha o app focado no local em que voce esta trabalhando agora.',
      },
      localizedWhyItMatters: {
        'es':
            'Las tareas, los turnos, los avisos y los documentos pueden depender de la ubicación activa.',
        'pt':
            'Tarefas, turnos, avisos e documentos podem depender do local ativo.',
      },
      localizedSteps: {
        'es': [
          'Toca el chip de ubicación actual o la tarjeta de ubicación cerca de la parte superior de la pantalla.',
          'Elige el sitio en el que quieres trabajar.',
          'Espera a que la página se actualice antes de revisar turnos, tareas o mensajes.',
          'Si falta la ubicación, pide a un admin que la asigne a tu cuenta.',
        ],
        'pt': [
          'Toque no chip do local atual ou no card do local perto da parte superior da tela.',
          'Escolha o local em que voce quer trabalhar.',
          'Espere a pagina atualizar antes de verificar turnos, tarefas ou mensagens.',
          'Se o local estiver faltando, peca a um admin para atribui-lo a sua conta.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'Todo el contenido específico de la ubicación se actualiza al sitio seleccionado.',
        ],
        'pt': [
          'Todo o conteudo especifico do local e atualizado para o local selecionado.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Buscar turnos o checklists mientras sigues dentro de la ubicación incorrecta.',
        ],
        'pt': [
          'Procurar turnos ou checklists enquanto o app ainda esta no local errado.',
        ],
      },
      localizedKeywords: {
        'es': ['cambiar ubicación', 'ubicación actual', 'filtro ubicación'],
        'pt': ['trocar local', 'local atual', 'filtro de local'],
      },
      keywords: ['switch location', 'current location', 'location filter'],
    ),
    const HelpTopic(
      id: 'user-settings',
      title: 'Use Settings',
      summary:
          'Manage your account details, preferences, and support options without drifting out of the main workflow.',
      whyItMatters:
          'Settings should help users adjust access, profile, and billing details quickly without turning into a second setup flow.',
      roles: [HelpRole.staff, HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.account,
      icon: Icons.settings_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open Settings when you need to update profile details, password, preferences, or support information.',
        'Use the section cards instead of scrolling randomly through the whole page.',
        'If you are an admin, handle business profile and billing changes, then return to Setup when you are done.',
        'Use Contact support from Settings when the issue is account-specific or you need subscription help.',
      ],
      goodOutcome: [
        'Account details stay current without interrupting daily operations.',
        'Admins can handle subscription or business changes without losing setup focus.',
      ],
      commonMistakes: [
        'Treating Settings like the place to manage day-to-day operations instead of locations, shifts, and workflows.',
      ],
      keywords: ['settings', 'account', 'billing', 'preferences', 'profile'],
      primaryCtaLabel: 'Open Settings',
      primaryCtaRoute: HelpDestinations.settings,
    ),
    const HelpTopic(
      id: 'staff-inbox',
      title: 'Use Inbox',
      summary:
          'Read updates from managers and keep important team messages from getting lost.',
      whyItMatters:
          'Inbox is where announcements, broadcasts, and operational updates stay visible even if push notifications are missed.',
      roles: [HelpRole.staff, HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.communications,
      icon: Icons.inbox_outlined,
      estimatedMinutes: 1,
      steps: [
        'Open Inbox from the menu or communications entry point.',
        'Start with unread items, then review anything that needs action.',
        'Open the message to read the full detail and context.',
        'Archive it once it no longer needs attention.',
      ],
      goodOutcome: [
        'You stay aligned with broadcasts even when you were away from the device.',
      ],
      commonMistakes: [
        'Treating push notifications as the full message instead of opening Inbox.',
      ],
      localizedTitles: {
        'es': 'Usa la bandeja de entrada',
        'pt': 'Use a Caixa de entrada',
      },
      localizedSummaries: {
        'es':
            'Lee las actualizaciones de los gerentes y evita que se pierdan los mensajes importantes del equipo.',
        'pt':
            'Leia as atualizacoes dos gerentes e evite que mensagens importantes da equipe se percam.',
      },
      localizedWhyItMatters: {
        'es':
            'La bandeja de entrada es donde los anuncios, avisos y actualizaciones operativas siguen visibles aunque se pierda una notificación push.',
        'pt':
            'A Caixa de entrada e onde anuncios, avisos e atualizacoes operacionais continuam visiveis mesmo se uma notificacao push for perdida.',
      },
      localizedSteps: {
        'es': [
          'Abre la bandeja de entrada desde el menú o el acceso de comunicaciones.',
          'Empieza por los elementos no leídos y luego revisa lo que necesite acción.',
          'Abre el mensaje para leer el detalle completo y el contexto.',
          'Archívalo cuando ya no requiera atención.',
        ],
        'pt': [
          'Abra a Caixa de entrada pelo menu ou pela entrada de comunicacoes.',
          'Comece pelos itens nao lidos e depois revise o que precisar de acao.',
          'Abra a mensagem para ler todos os detalhes e o contexto.',
          'Arquive quando ela nao precisar mais de atencao.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'Sigues alineado con los avisos incluso si no estabas usando el dispositivo.',
        ],
        'pt': [
          'Voce continua alinhado com os avisos mesmo se nao estava usando o dispositivo.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Tomar las notificaciones push como el mensaje completo en vez de abrir la bandeja.',
        ],
        'pt': [
          'Tratar a notificacao push como a mensagem completa em vez de abrir a Caixa de entrada.',
        ],
      },
      localizedKeywords: {
        'es': ['bandeja', 'mensajes', 'avisos', 'notificaciones'],
        'pt': ['caixa de entrada', 'mensagens', 'avisos', 'notificacoes'],
      },
      keywords: ['inbox', 'messages', 'broadcasts', 'notifications'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir bandeja de entrada',
        'pt': 'Abrir Caixa de entrada',
      },
      primaryCtaLabel: 'Open Inbox',
      primaryCtaRoute: HelpDestinations.inbox,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'staff-document-center',
      title: 'Use Document Center',
      summary:
          'Open SOPs, guides, and training material without leaving the app.',
      whyItMatters:
          'Document Center is the reference layer for work that does not belong inside a task checklist.',
      roles: [HelpRole.staff, HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.documents,
      icon: Icons.menu_book_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open Document Center from the bottom navigation.',
        'Use search, category filters, or location filters to narrow the list.',
        'Open the document to read or review it in the viewer.',
        'Return to your task flow once you have the information you need.',
      ],
      goodOutcome: [
        'Staff can find operational references without asking a manager every time.',
      ],
      commonMistakes: [
        'Using documents for work that should really be in a checklist workflow.',
      ],
      localizedTitles: {
        'es': 'Usa el centro de documentos',
        'pt': 'Use o Centro de documentos',
      },
      localizedSummaries: {
        'es':
            'Abre SOPs, guías y material de capacitación sin salir de la app.',
        'pt': 'Abra SOPs, guias e material de treinamento sem sair do app.',
      },
      localizedWhyItMatters: {
        'es':
            'El centro de documentos es la capa de referencia para el trabajo que no debe vivir dentro de un checklist.',
        'pt':
            'O Centro de documentos e a camada de referencia para o trabalho que nao deve ficar dentro de um checklist.',
      },
      localizedSteps: {
        'es': [
          'Abre el centro de documentos desde la navegación inferior.',
          'Usa la búsqueda, los filtros por categoría o los filtros de ubicación para reducir la lista.',
          'Abre el documento para leerlo o revisarlo en el visor.',
          'Vuelve a tu flujo de tareas cuando ya tengas la información que necesitas.',
        ],
        'pt': [
          'Abra o Centro de documentos pela navegacao inferior.',
          'Use busca, filtros de categoria ou filtros de local para reduzir a lista.',
          'Abra o documento para ler ou revisar no visualizador.',
          'Volte ao seu fluxo de tarefas quando tiver a informacao de que precisa.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'El personal puede encontrar referencias operativas sin pedir ayuda a un gerente cada vez.',
        ],
        'pt': [
          'A equipe pode encontrar referencias operacionais sem precisar pedir ajuda a um gerente toda vez.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Usar documentos para trabajo que realmente debería estar en un flujo de checklist.',
        ],
        'pt': [
          'Usar documentos para trabalho que na verdade deveria estar em um fluxo de checklist.',
        ],
      },
      localizedKeywords: {
        'es': ['centro de documentos', 'capacitacion', 'sop', 'documentos'],
        'pt': ['centro de documentos', 'treinamento', 'sop', 'documentos'],
      },
      keywords: ['document center', 'training', 'sop', 'documents'],
      localizedPrimaryCtaLabels: {
        'es': 'Abrir centro de documentos',
        'pt': 'Abrir Centro de documentos',
      },
      primaryCtaLabel: 'Open Document Center',
      primaryCtaRoute: HelpDestinations.documents,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'staff-shared-mode',
      title: 'Use shared mode on a team device',
      summary:
          'Keep shared iPads and service devices safe while still making them easy to use.',
      whyItMatters:
          'Shared mode lets multiple people use one device without exposing the wrong settings or account controls.',
      roles: [HelpRole.staff, HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.sharedMode,
      icon: Icons.devices_outlined,
      estimatedMinutes: 2,
      steps: [
        'Use the shared device normally for daily work.',
        'If the lock overlay appears, ask a manager or admin for the PIN.',
        'Do not sign out or change settings unless you are responsible for the device.',
        'Use the shared mode exit flow only when a manager authorizes it.',
      ],
      goodOutcome: [
        'The device stays focused on work instead of account management.',
      ],
      commonMistakes: [
        'Trying to bypass the shared mode lock instead of asking for the owner PIN.',
      ],
      localizedTitles: {
        'es': 'Usa el modo compartido en un dispositivo del equipo',
        'pt': 'Use o modo compartilhado em um dispositivo da equipe',
      },
      localizedSummaries: {
        'es':
            'Mantén seguros los iPads y dispositivos compartidos sin dejar de hacerlos fáciles de usar.',
        'pt':
            'Mantenha iPads e dispositivos compartilhados seguros sem deixar de torna-los faceis de usar.',
      },
      localizedWhyItMatters: {
        'es':
            'El modo compartido permite que varias personas usen un dispositivo sin exponer configuraciones o controles de cuenta incorrectos.',
        'pt':
            'O modo compartilhado permite que varias pessoas usem um dispositivo sem expor configuracoes ou controles de conta errados.',
      },
      localizedSteps: {
        'es': [
          'Usa el dispositivo compartido normalmente para el trabajo diario.',
          'Si aparece la capa de bloqueo, pide el PIN a un gerente o admin.',
          'No cierres sesión ni cambies ajustes a menos que seas responsable del dispositivo.',
          'Usa el flujo para salir del modo compartido solo cuando un gerente lo autorice.',
        ],
        'pt': [
          'Use o dispositivo compartilhado normalmente para o trabalho diario.',
          'Se a camada de bloqueio aparecer, peca o PIN a um gerente ou admin.',
          'Nao saia da conta nem altere configuracoes, a menos que voce seja responsavel pelo dispositivo.',
          'Use o fluxo de saida do modo compartilhado somente quando um gerente autorizar.',
        ],
      },
      localizedGoodOutcome: {
        'es': [
          'El dispositivo se mantiene enfocado en el trabajo y no en la gestión de cuentas.',
        ],
        'pt': [
          'O dispositivo continua focado no trabalho e nao no gerenciamento da conta.',
        ],
      },
      localizedCommonMistakes: {
        'es': [
          'Intentar saltarte el bloqueo del modo compartido en vez de pedir el PIN del responsable.',
        ],
        'pt': [
          'Tentar contornar o bloqueio do modo compartilhado em vez de pedir o PIN do responsavel.',
        ],
      },
      localizedKeywords: {
        'es': ['modo compartido', 'dispositivo compartido', 'pin', 'bloqueo'],
        'pt': [
          'modo compartilhado',
          'dispositivo compartilhado',
          'pin',
          'bloqueio',
        ],
      },
      keywords: ['shared mode', 'shared device', 'pin', 'lock'],
    ),
    const HelpTopic(
      id: 'staff-trouble-missing-shift',
      title: 'I can’t see my shift',
      summary:
          'Fix the most common reasons a shift does not appear on the staff dashboard.',
      whyItMatters:
          'Missing shifts stop staff from reaching the work they are supposed to complete.',
      roles: [HelpRole.staff],
      category: HelpTopicCategory.troubleshooting,
      icon: Icons.search_off_outlined,
      estimatedMinutes: 2,
      steps: [
        'Confirm you are on the correct location first.',
        'Check whether the shift is scheduled for the current time or day.',
        'Make sure you were invited or assigned correctly for that location.',
        'If the problem continues, contact a manager or admin with the location and shift name.',
      ],
      goodOutcome: [
        'You can quickly confirm whether the issue is location, access, or scheduling.',
      ],
      commonMistakes: [
        'Reporting a missing shift before switching to the correct location.',
      ],
      localizedTitles: {'pt': 'Nao consigo ver meu turno'},
      localizedSummaries: {
        'pt':
            'Corrija os motivos mais comuns pelos quais um turno nao aparece no painel da equipe.',
      },
      localizedWhyItMatters: {
        'pt':
            'Turnos ausentes impedem que a equipe chegue ao trabalho que deveria concluir.',
      },
      localizedSteps: {
        'pt': [
          'Confirme primeiro que voce esta no local correto.',
          'Verifique se o turno esta agendado para o horario ou dia atual.',
          'Certifique-se de que voce foi convidado ou atribuido corretamente para esse local.',
          'Se o problema continuar, fale com um gerente ou admin informando o local e o nome do turno.',
        ],
      },
      localizedGoodOutcome: {
        'pt': [
          'Voce consegue confirmar rapidamente se o problema e de local, acesso ou agendamento.',
        ],
      },
      localizedCommonMistakes: {
        'pt': [
          'Relatar um turno ausente antes de trocar para o local correto.',
        ],
      },
      localizedKeywords: {
        'pt': ['turno ausente', 'sem turno', 'nao vejo turno', 'nao aparece'],
      },
      keywords: ['missing shift', 'no shift', 'can’t see shift', 'not showing'],
      localizedPrimaryCtaLabels: {'pt': 'Falar com o suporte'},
      primaryCtaLabel: 'Contact support',
      primaryCtaRoute: HelpDestinations.contactSupport,
      isTroubleshooting: true,
    ),
    const HelpTopic(
      id: 'staff-trouble-missing-tasks',
      title: 'My tasks are missing',
      summary:
          'Use a quick checklist when a shift is visible but no tasks appear.',
      whyItMatters:
          'Task visibility depends on shift setup, location scope, and the workflow the admin attached.',
      roles: [HelpRole.staff, HelpRole.manager],
      category: HelpTopicCategory.troubleshooting,
      icon: Icons.playlist_remove_outlined,
      estimatedMinutes: 2,
      steps: [
        'Confirm you are inside the correct shift.',
        'Refresh the page after switching locations or re-entering the dashboard.',
        'Check whether the shift shows “No tasks are available for this shift yet.”',
        'If it still looks wrong, ask a manager or admin whether a workflow is attached to that shift.',
      ],
      goodOutcome: [
        'You can quickly tell whether the issue is data setup or just the wrong screen context.',
      ],
      commonMistakes: [
        'Assuming the app is broken when the shift was never configured with a workflow.',
      ],
      localizedTitles: {'pt': 'Minhas tarefas nao aparecem'},
      localizedSummaries: {
        'pt':
            'Use um checklist rapido quando um turno esta visivel, mas nenhuma tarefa aparece.',
      },
      localizedWhyItMatters: {
        'pt':
            'A visibilidade das tarefas depende da configuracao do turno, do escopo do local e do fluxo que o admin anexou.',
      },
      localizedSteps: {
        'pt': [
          'Confirme que voce esta dentro do turno correto.',
          'Atualize a pagina depois de trocar de local ou entrar novamente no painel.',
          'Verifique se o turno mostra “No tasks are available for this shift yet.”',
          'Se ainda parecer errado, pergunte a um gerente ou admin se existe um fluxo anexado a esse turno.',
        ],
      },
      localizedGoodOutcome: {
        'pt': [
          'Voce consegue perceber rapidamente se o problema e de configuracao dos dados ou apenas de contexto na tela errada.',
        ],
      },
      localizedCommonMistakes: {
        'pt': [
          'Assumir que o app esta quebrado quando o turno nunca foi configurado com um fluxo.',
        ],
      },
      localizedKeywords: {
        'pt': ['tarefas ausentes', 'checklist vazio', 'sem tarefas', 'fluxo'],
      },
      keywords: ['missing tasks', 'empty checklist', 'no tasks', 'workflow'],
      localizedPrimaryCtaLabels: {'pt': 'Falar com o suporte'},
      primaryCtaLabel: 'Contact support',
      primaryCtaRoute: HelpDestinations.contactSupport,
      isTroubleshooting: true,
    ),
    const HelpTopic(
      id: 'manager-dashboard',
      title: 'Read the manager dashboard',
      summary:
          'Use the dashboard as an operational command center, not a generic report page.',
      whyItMatters:
          'Managers need to know what needs attention right now, not browse every shift manually.',
      roles: [HelpRole.manager],
      category: HelpTopicCategory.oversight,
      icon: Icons.space_dashboard_outlined,
      estimatedMinutes: 2,
      steps: [
        'Start with Today at Risk to see what needs attention first.',
        'Use Shift Readiness to compare live shifts and upcoming runs.',
        'Review Recurring Issues to find patterns that keep repeating over time.',
        'Open History & Reports only when you need deeper review or follow-up.',
      ],
      goodOutcome: [
        'You can identify what needs intervention in under a minute.',
      ],
      commonMistakes: [
        'Jumping straight into historical reports before reviewing live risk.',
      ],
      keywords: ['manager dashboard', 'today at risk', 'shift readiness'],
      primaryCtaLabel: 'Open Dashboard',
      primaryCtaRoute: HelpDestinations.managerDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'manager-at-risk',
      title: 'Understand Today at Risk',
      summary:
          'Use the action queue to prioritize unfinished, blocked, or slipping work.',
      whyItMatters:
          'Today at Risk is the fastest view of what could compromise service or completion today.',
      roles: [HelpRole.manager],
      category: HelpTopicCategory.oversight,
      icon: Icons.warning_amber_rounded,
      estimatedMinutes: 2,
      steps: [
        'Open the first issue with the highest urgency.',
        'Use the issue title and supporting line to see what is slipping.',
        'Open the affected shift and review blocked or open tasks.',
        'Follow up with staff or finish the work yourself if needed.',
      ],
      goodOutcome: ['The issue queue shrinks as you resolve or delegate work.'],
      commonMistakes: [
        'Treating carryover and at-risk issues as purely informational.',
      ],
      keywords: ['today at risk', 'at risk', 'manager issues'],
      primaryCtaLabel: 'Open Dashboard',
      primaryCtaRoute: HelpDestinations.managerDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'manager-shift-readiness',
      title: 'Use Shift Readiness',
      summary:
          'Compare active and upcoming shifts without drilling into each one.',
      whyItMatters:
          'Shift Readiness helps you spot low progress, blocked work, and no-activity shifts before service slips.',
      roles: [HelpRole.manager],
      category: HelpTopicCategory.oversight,
      icon: Icons.view_list_outlined,
      estimatedMinutes: 2,
      steps: [
        'Review each shift row for status, progress, and flagged work.',
        'Open the shifts with the highest number of open or blocked tasks first.',
        'Use the readiness view to check whether an upcoming shift is prepared to start.',
      ],
      goodOutcome: [
        'You can compare shifts quickly without reading every checklist.',
      ],
      commonMistakes: [
        'Focusing only on completed percentages without checking blocked tasks.',
      ],
      keywords: ['shift readiness', 'progress', 'manager shifts'],
      primaryCtaLabel: 'Open Dashboard',
      primaryCtaRoute: HelpDestinations.managerDashboard,
    ),
    const HelpTopic(
      id: 'manager-recurring-issues',
      title: 'Review recurring issues',
      summary:
          'Use repeat misses and weak shifts to find systemic problems, not just today’s noise.',
      whyItMatters:
          'Recurring Issues help managers coach better, fix broken workflows, and catch repeat misses early.',
      roles: [HelpRole.manager],
      category: HelpTopicCategory.oversight,
      icon: Icons.bar_chart_rounded,
      estimatedMinutes: 3,
      steps: [
        'Review Recurring Failures first to see the repeat misses with the highest impact.',
        'Use At-Risk Shifts to see which runs keep underperforming over time.',
        'Follow up by adjusting training, workflow design, or team assignment.',
      ],
      goodOutcome: ['You stop solving the same issue every day in isolation.'],
      commonMistakes: [
        'Treating recurring issues as historical noise instead of coaching input.',
      ],
      keywords: ['recurring issues', 'repeat misses', 'history'],
      primaryCtaLabel: 'Open Dashboard',
      primaryCtaRoute: HelpDestinations.managerDashboard,
    ),
    const HelpTopic(
      id: 'manager-broadcast',
      title: 'Send a broadcast',
      summary:
          'Use Broadcasts when the team needs a clear update across one or more audiences.',
      whyItMatters:
          'Broadcasts keep teams aligned without relying on ad hoc texts or missing staff on shift change.',
      roles: [HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.communications,
      icon: Icons.campaign_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open Broadcasts from the communications area.',
        'Choose the audience carefully before writing the message.',
        'Use a clear title and one concise instruction or update.',
        'Send the broadcast and confirm it lands in Inbox.',
      ],
      goodOutcome: ['The right group receives the message in one place.'],
      commonMistakes: [
        'Sending broad updates to everyone when only one location or shift needs it.',
      ],
      keywords: ['broadcast', 'send message', 'notification', 'inbox'],
      primaryCtaLabel: 'Open Inbox',
      primaryCtaRoute: HelpDestinations.inbox,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'manager-audiences',
      title: 'Use audiences',
      summary:
          'Organize who receives broadcasts without rebuilding recipient lists every time.',
      whyItMatters:
          'Audiences reduce mistakes and help managers message the right location, role, or team quickly.',
      roles: [HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.communications,
      icon: Icons.groups_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open Audiences from communications.',
        'Use system audiences for simple targets like all staff or managers.',
        'Use custom audiences for repeat groups that need the same updates often.',
        'Review the audience before sending a broadcast.',
      ],
      goodOutcome: ['Broadcast composition is faster and more accurate.'],
      commonMistakes: [
        'Treating audiences like chat groups instead of reusable recipient targets.',
      ],
      keywords: ['audiences', 'groups', 'message group', 'recipients'],
      primaryCtaLabel: 'Open Inbox',
      primaryCtaRoute: HelpDestinations.inbox,
    ),
    const HelpTopic(
      id: 'manager-history-reports',
      title: 'Use History & Reports',
      summary:
          'Go deeper when you need filtering, review, or follow-up beyond the live dashboard.',
      whyItMatters:
          'History & Reports are best for analysis after you understand what is happening right now.',
      roles: [HelpRole.manager],
      category: HelpTopicCategory.operationsControl,
      icon: Icons.analytics_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open History & Reports from the manager dashboard.',
        'Filter by shift, time range, or status depending on what you need to review.',
        'Use it to investigate patterns, compliance, and follow-up questions.',
      ],
      goodOutcome: [
        'You can answer specific questions without cluttering the live dashboard.',
      ],
      commonMistakes: [
        'Using history first when a live dashboard issue still needs action.',
      ],
      keywords: ['history', 'reports', 'filters', 'task history'],
      primaryCtaLabel: 'Open Dashboard',
      primaryCtaRoute: HelpDestinations.managerDashboard,
    ),
    const HelpTopic(
      id: 'manager-trouble-wrong-location',
      title: 'The dashboard is showing the wrong location',
      summary:
          'Reset the dashboard scope when you are looking at the wrong site.',
      whyItMatters:
          'Managers can make the wrong decision quickly if the page is scoped to another location.',
      roles: [HelpRole.manager, HelpRole.admin],
      category: HelpTopicCategory.troubleshooting,
      icon: Icons.place_outlined,
      estimatedMinutes: 1,
      steps: [
        'Use the location scope control at the top of the page.',
        'Switch to the correct location and let the dashboard refresh.',
        'If the site is missing, confirm that your account is assigned to it.',
      ],
      goodOutcome: [
        'The manager dashboard reflects the correct location before you act.',
      ],
      commonMistakes: [
        'Reviewing metrics before confirming the active location.',
      ],
      keywords: ['wrong location', 'manager location', 'scope'],
      primaryCtaLabel: 'Contact support',
      primaryCtaRoute: HelpDestinations.contactSupport,
      isTroubleshooting: true,
    ),
    const HelpTopic(
      id: 'admin-first-location',
      title: 'Add your first location',
      summary:
          'Start setup with the physical place where work will actually happen.',
      whyItMatters:
          'Locations define the scope for team access, shifts, workflows, documents, and dashboards.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.setup,
      icon: Icons.storefront_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open Setup and start in Locations.',
        'Add the site details and confirm it appears in the location list.',
        'Switch the active location to the one you want to configure next.',
      ],
      goodOutcome: ['The rest of setup now has a real location to attach to.'],
      commonMistakes: [
        'Building shifts or workflows before choosing which location they belong to.',
      ],
      keywords: ['first location', 'add location', 'setup location'],
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'admin-invite-team',
      title: 'Invite your team',
      summary:
          'Bring staff into the right locations with the right role before service begins.',
      whyItMatters:
          'Invites and location assignments determine whether people can even see the correct work.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.setup,
      icon: Icons.person_add_alt_1_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open Team from Setup.',
        'Create a new invite, choose role, and assign the correct locations.',
        'Send the invite and track it from the team/invites list.',
      ],
      goodOutcome: [
        'Staff land in the correct organization and role from the start.',
      ],
      commonMistakes: [
        'Assigning the wrong location and assuming the user will still find the right shift.',
      ],
      keywords: ['invite staff', 'team', 'role', 'location access'],
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'admin-create-shift',
      title: 'Create a shift',
      summary:
          'Define when work happens and who it belongs to before attaching the workflow.',
      whyItMatters:
          'Shifts are the operational frame that staff and managers work inside every day.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.setup,
      icon: Icons.schedule_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open Shifts from Setup.',
        'Create the shift with the right name, time window, and schedule.',
        'Assign the correct location and working roles.',
        'Save it before attaching a workflow template.',
      ],
      goodOutcome: [
        'The shift is ready to receive a workflow and appear in the dashboards.',
      ],
      commonMistakes: [
        'Creating workflows in the library without attaching them to a real shift.',
      ],
      keywords: ['create shift', 'setup shift', 'schedule'],
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'admin-attach-workflow',
      title: 'Attach a workflow to a shift',
      summary:
          'Link the reusable checklist template to the shift where it actually runs.',
      whyItMatters:
          'Staff do not see tasks until the shift has a workflow attached and generated correctly.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.setup,
      icon: Icons.link_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open the shift you want to configure.',
        'Create a workflow from the shift or attach an existing one from Checklist Library.',
        'Save the shift and confirm the workflow is visible on the shift row.',
      ],
      goodOutcome: ['Today’s work can be generated correctly for that shift.'],
      commonMistakes: [
        'Editing a checklist without checking whether it is actually attached to the intended shift.',
      ],
      keywords: ['attach workflow', 'checklist library', 'shift workflow'],
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'admin-checklist-library',
      title: 'Use Checklist Library',
      summary:
          'Manage reusable workflow templates without making setup feel like raw checklist CRUD.',
      whyItMatters:
          'Checklist Library is where reusable templates live, but it is not the place most admins should start.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.setup,
      icon: Icons.library_books_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open Checklist Library from Setup.',
        'Create or edit a reusable workflow template.',
        'Return to Shifts when you want to attach that template to live operations.',
      ],
      goodOutcome: [
        'Reusable workflows stay organized without replacing shift-based setup.',
      ],
      commonMistakes: [
        'Treating Checklist Library as the main setup path instead of a supporting template area.',
      ],
      keywords: ['checklist library', 'workflow template', 'template'],
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
    ),
    const HelpTopic(
      id: 'admin-multi-location',
      title: 'Manage multiple locations',
      summary:
          'Use the location switcher to keep setup focused and avoid editing the wrong site.',
      whyItMatters:
          'Multi-location orgs get noisy fast when shifts, users, and workflows are not scoped properly.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.operationsControl,
      icon: Icons.location_city_outlined,
      estimatedMinutes: 2,
      steps: [
        'Use the active location card or scope control in Setup.',
        'Switch to the location you want to edit before touching shifts, team, or Checklist Library.',
        'Use Locations itself for global site management, then return to scoped setup.',
      ],
      goodOutcome: ['Setup lists stay focused and easier to manage.'],
      commonMistakes: [
        'Editing a checklist or shift while the wrong location is active.',
      ],
      keywords: [
        'multi location',
        'all locations',
        'scope',
        'location switcher',
      ],
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'admin-document-center',
      title: 'Set up Document Center',
      summary:
          'Use Document Center for SOPs, references, and training that should not live inside task workflows.',
      whyItMatters:
          'Documents support the operation, but they should not be the primary way routine work gets executed.',
      roles: [HelpRole.admin, HelpRole.manager],
      category: HelpTopicCategory.documents,
      icon: Icons.folder_open_outlined,
      estimatedMinutes: 3,
      steps: [
        'Open Document Center.',
        'Upload SOPs, training guides, and references with clear titles and categories.',
        'Use search and filters to keep the repository easy to browse.',
      ],
      goodOutcome: [
        'The team can find reference material quickly without cluttering checklists.',
      ],
      commonMistakes: [
        'Uploading docs for repeat work that should really be a workflow task.',
      ],
      keywords: ['documents', 'sops', 'training', 'repository'],
      primaryCtaLabel: 'Open Document Center',
      primaryCtaRoute: HelpDestinations.documents,
    ),
    const HelpTopic(
      id: 'admin-settings-billing',
      title: 'Use settings and billing',
      summary:
          'Manage the business account, profile, and subscription without leaving setup unfinished.',
      whyItMatters:
          'Account and billing settings matter, but they are secondary to getting locations, team, and shifts ready first.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.account,
      icon: Icons.settings_outlined,
      estimatedMinutes: 2,
      steps: [
        'Open Settings for account, business profile, or billing needs.',
        'Use billing only when plan limits or subscription changes require it.',
        'Return to Setup once the account-level change is complete.',
      ],
      goodOutcome: [
        'Business settings stay accurate without distracting from operational setup.',
      ],
      commonMistakes: [
        'Jumping into billing before completing the core operational setup.',
      ],
      keywords: ['settings', 'billing', 'subscription', 'account'],
      primaryCtaLabel: 'Open Settings',
      primaryCtaRoute: HelpDestinations.settings,
    ),
    const HelpTopic(
      id: 'admin-trouble-invite',
      title: 'An invite is not working',
      summary:
          'Use the new invite-first model to diagnose whether the issue is the link, status, or account state.',
      whyItMatters:
          'Invite problems block activation and can leave users unable to reach the right role or location.',
      roles: [HelpRole.admin],
      category: HelpTopicCategory.troubleshooting,
      icon: Icons.mail_lock_outlined,
      estimatedMinutes: 3,
      steps: [
        'Check the invite status in Team or pending invites first.',
        'Resend or revoke the invite if the status is stale.',
        'Make sure the user is using the invite flow instead of generic signup.',
        'If the user already has the wrong account state, contact support with the email and org details.',
      ],
      goodOutcome: [
        'You can tell whether the issue is invite lifecycle, wrong flow, or account mismatch.',
      ],
      commonMistakes: [
        'Telling users to create a new account outside the invite flow.',
      ],
      keywords: [
        'invite',
        'invite not working',
        'pending invite',
        'accept invite',
      ],
      primaryCtaLabel: 'Contact support',
      primaryCtaRoute: HelpDestinations.contactSupport,
      isTroubleshooting: true,
    ),
    const HelpTopic(
      id: 'admin-trouble-workflow',
      title: 'A shift workflow is not showing up for staff',
      summary:
          'Check the setup chain from location to shift to workflow before assuming the staff app is wrong.',
      whyItMatters:
          'Most missing task issues trace back to setup scope or workflow attachment, not random UI failure.',
      roles: [HelpRole.admin, HelpRole.manager],
      category: HelpTopicCategory.troubleshooting,
      icon: Icons.rule_folder_outlined,
      estimatedMinutes: 3,
      steps: [
        'Confirm the correct location is active in Setup.',
        'Open the shift and verify that a workflow is attached.',
        'Check whether the workflow belongs to the intended location and shift.',
        'If you edited the workflow on web, confirm the change reseeded today’s work correctly.',
      ],
      goodOutcome: [
        'You can isolate whether the problem is shift setup, checklist attachment, or stale daily generation.',
      ],
      commonMistakes: [
        'Editing a template and assuming staff will instantly see it without checking the shift attachment.',
      ],
      keywords: [
        'workflow missing',
        'checklist not showing',
        'staff tasks missing',
      ],
      primaryCtaLabel: 'Contact support',
      primaryCtaRoute: HelpDestinations.contactSupport,
      isTroubleshooting: true,
    ),
  ];

  static final Map<HelpRole, HelpStartGuide> startGuides = {
    HelpRole.staff: const HelpStartGuide(
      role: HelpRole.staff,
      title: 'Get through your first shift',
      subtitle:
          'Learn the exact flow for finding work, completing tasks, and handling issues without slowing service down.',
      primaryCtaLabel: 'Open Today’s Tasks',
      primaryCtaRoute: HelpDestinations.userDashboard,
      localizedTitles: {
        'es': 'Completa tu primer turno',
        'pt': 'Conclua seu primeiro turno',
      },
      localizedSubtitles: {
        'es':
            'Aprende el flujo exacto para encontrar trabajo, completar tareas y manejar problemas sin frenar el servicio.',
        'pt':
            'Aprenda o fluxo exato para encontrar trabalho, concluir tarefas e lidar com problemas sem desacelerar o servico.',
      },
      localizedPrimaryCtaLabels: {
        'es': 'Abrir tareas de hoy',
        'pt': 'Abrir tarefas de hoje',
      },
      steps: [
        HelpStartStep(
          title: 'Confirm your location',
          description:
              'Make sure the app is focused on the site you are working in.',
          topicId: 'staff-switch-location',
          localizedTitles: {
            'es': 'Confirma tu ubicación',
            'pt': 'Confirme seu local',
          },
          localizedDescriptions: {
            'es':
                'Asegúrate de que la app esté enfocada en el sitio donde estás trabajando.',
            'pt':
                'Confirme que o app esta focado no local onde voce esta trabalhando.',
          },
        ),
        HelpStartStep(
          title: 'Open your assigned shift',
          description:
              'Start from your current shift hero instead of hunting through every list.',
          topicId: 'staff-first-shift',
          localizedTitles: {
            'es': 'Abre tu turno asignado',
            'pt': 'Abra seu turno atribuido',
          },
          localizedDescriptions: {
            'es':
                'Empieza desde la tarjeta principal de tu turno actual en vez de buscar en cada lista.',
            'pt':
                'Comece pelo card principal do seu turno atual em vez de procurar em cada lista.',
          },
        ),
        HelpStartStep(
          title: 'Use Next Up first',
          description:
              'Let the app show the fastest path through the remaining work.',
          topicId: 'staff-next-up',
          localizedTitles: {
            'es': 'Usa Siguiente primero',
            'pt': 'Use Proximo item primeiro',
          },
          localizedDescriptions: {
            'es':
                'Deja que la app muestre la ruta más rápida a través del trabajo restante.',
            'pt':
                'Deixe que o app mostre o caminho mais rapido pelo trabalho restante.',
          },
        ),
        HelpStartStep(
          title: 'Handle proof and issues properly',
          description:
              'Use photo, note, and Can’t Do actions inline when work needs more context.',
          topicId: 'staff-photo-required',
          localizedTitles: {
            'es': 'Gestiona bien la evidencia y los problemas',
            'pt': 'Gerencie bem as provas e os problemas',
          },
          localizedDescriptions: {
            'es':
                'Usa las acciones de foto, nota y No puedo cuando el trabajo necesite más contexto.',
            'pt':
                'Use as acoes de foto, observacao e Nao consigo quando o trabalho precisar de mais contexto.',
          },
        ),
        HelpStartStep(
          title: 'Check messages and references',
          description:
              'Use Inbox for updates and Document Center for SOPs when needed.',
          topicId: 'staff-inbox',
          localizedTitles: {
            'es': 'Revisa mensajes y referencias',
            'pt': 'Verifique mensagens e referencias',
          },
          localizedDescriptions: {
            'es':
                'Usa la bandeja de entrada para actualizaciones y el centro de documentos para SOPs cuando haga falta.',
            'pt':
                'Use a Caixa de entrada para atualizacoes e o Centro de documentos para SOPs quando necessario.',
          },
        ),
      ],
    ),
    HelpRole.manager: const HelpStartGuide(
      role: HelpRole.manager,
      title: 'Run service with confidence',
      subtitle:
          'Learn how to read the new manager dashboard, act on risks, and communicate with the team clearly.',
      primaryCtaLabel: 'Open Dashboard',
      primaryCtaRoute: HelpDestinations.managerDashboard,
      steps: [
        HelpStartStep(
          title: 'Start with Today at Risk',
          description: 'Review the issues that need attention now.',
          topicId: 'manager-at-risk',
        ),
        HelpStartStep(
          title: 'Use Shift Readiness',
          description: 'Compare active and upcoming shifts quickly.',
          topicId: 'manager-shift-readiness',
        ),
        HelpStartStep(
          title: 'Watch recurring issues',
          description: 'Use repeat misses to identify systemic problems.',
          topicId: 'manager-recurring-issues',
        ),
        HelpStartStep(
          title: 'Send broadcasts clearly',
          description:
              'Use communications for clean team updates instead of ad hoc text chains.',
          topicId: 'manager-broadcast',
        ),
        HelpStartStep(
          title: 'Keep the right location in focus',
          description:
              'Always confirm location scope before acting on metrics.',
          topicId: 'manager-trouble-wrong-location',
        ),
      ],
    ),
    HelpRole.admin: const HelpStartGuide(
      role: HelpRole.admin,
      title: 'Set up your operation the right way',
      subtitle:
          'Start with the real-world setup order so locations, team, shifts, and workflows line up cleanly.',
      primaryCtaLabel: 'Open Setup',
      primaryCtaRoute: HelpDestinations.adminDashboard,
      localizedTitles: {
        'es': 'Configura tu operación de la manera correcta',
        'pt': 'Configure sua operação da maneira certa',
      },
      localizedSubtitles: {
        'es':
            'Comienza con el orden real de configuración para que ubicaciones, equipo, turnos y flujos queden alineados.',
        'pt':
            'Comece pela ordem real de configuração para que locais, equipe, turnos e fluxos fiquem alinhados.',
      },
      localizedPrimaryCtaLabels: {
        'es': 'Abrir configuración',
        'pt': 'Abrir configuração',
      },
      steps: [
        HelpStartStep(
          title: 'Add your first location',
          description: 'Start with the real place where work happens.',
          topicId: 'admin-first-location',
          localizedTitles: {
            'es': 'Agrega tu primera ubicación',
            'pt': 'Adicione seu primeiro local',
          },
          localizedDescriptions: {
            'es': 'Empieza con el lugar real donde ocurre el trabajo.',
            'pt': 'Comece pelo local real onde o trabalho acontece.',
          },
        ),
        HelpStartStep(
          title: 'Invite the team',
          description:
              'Bring users in with the correct role and location access.',
          topicId: 'admin-invite-team',
          localizedTitles: {'es': 'Invita al equipo', 'pt': 'Convide a equipe'},
          localizedDescriptions: {
            'es':
                'Incorpora a los usuarios con el rol correcto y acceso a la ubicación adecuada.',
            'pt':
                'Traga os usuários com a função certa e o acesso correto ao local.',
          },
        ),
        HelpStartStep(
          title: 'Create shifts',
          description:
              'Define when the work happens before building workflows around it.',
          topicId: 'admin-create-shift',
          localizedTitles: {'es': 'Crea turnos', 'pt': 'Crie turnos'},
          localizedDescriptions: {
            'es':
                'Define cuándo ocurre el trabajo antes de construir flujos alrededor de ello.',
            'pt':
                'Defina quando o trabalho acontece antes de criar fluxos em torno dele.',
          },
        ),
        HelpStartStep(
          title: 'Attach workflows',
          description:
              'Connect reusable templates to the shifts where they actually run.',
          topicId: 'admin-attach-workflow',
          localizedTitles: {
            'es': 'Adjunta flujos de trabajo',
            'pt': 'Anexe fluxos de trabalho',
          },
          localizedDescriptions: {
            'es':
                'Conecta plantillas reutilizables a los turnos donde realmente se ejecutan.',
            'pt':
                'Conecte modelos reutilizáveis aos turnos em que eles realmente são executados.',
          },
        ),
        HelpStartStep(
          title: 'Use Checklist Library as support',
          description:
              'Treat templates as reusable assets, not the main setup path.',
          topicId: 'admin-checklist-library',
          localizedTitles: {
            'es': 'Usa la biblioteca de checklists como apoyo',
            'pt': 'Use a biblioteca de checklists como apoio',
          },
          localizedDescriptions: {
            'es':
                'Trata las plantillas como recursos reutilizables, no como la ruta principal de configuración.',
            'pt':
                'Trate os modelos como recursos reutilizáveis, não como o caminho principal de configuração.',
          },
        ),
      ],
    ),
  };

  static HelpTopic? byId(String id) {
    for (final topic in all) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  static HelpStartGuide guideForRole(HelpRole role) => startGuides[role]!;

  static List<HelpTopic> forRole(HelpRole role) =>
      all.where((topic) => topic.roles.contains(role)).toList();

  static List<HelpTopic> featuredForRole(HelpRole role) =>
      forRole(
        role,
      ).where((topic) => topic.isFeatured && !topic.isTroubleshooting).toList();

  static List<HelpTopic> troubleshootingForRole(HelpRole role) =>
      forRole(role).where((topic) => topic.isTroubleshooting).toList();

  static List<HelpTopic> byCategoryForRole(
    HelpRole role,
    HelpTopicCategory category,
  ) {
    return forRole(role)
        .where(
          (topic) =>
              topic.category == category &&
              (category == HelpTopicCategory.troubleshooting ||
                  !topic.isTroubleshooting),
        )
        .toList();
  }

  static List<HelpTopic> search(
    String query, {
    HelpRole? role,
    bool troubleshootingOnly = false,
    String localeCode = 'en',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      final source = role == null ? all : forRole(role);
      return troubleshootingOnly
          ? source.where((topic) => topic.isTroubleshooting).toList()
          : source.where((topic) => !topic.isTroubleshooting).toList();
    }

    final source = role == null ? all : forRole(role);
    final filtered =
        source.where((topic) {
          if (troubleshootingOnly && !topic.isTroubleshooting) return false;
          if (!troubleshootingOnly && topic.isTroubleshooting) return false;

          final haystack =
              topic.searchTermsForLocale(localeCode).join(' ').toLowerCase();
          return haystack.contains(normalizedQuery);
        }).toList();

    filtered.sort((a, b) {
      final aTitle = a.titleForLocale(localeCode);
      final bTitle = b.titleForLocale(localeCode);
      final aStarts = aTitle.toLowerCase().startsWith(normalizedQuery);
      final bStarts = bTitle.toLowerCase().startsWith(normalizedQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return aTitle.compareTo(bTitle);
    });

    return filtered;
  }

  static List<HelpTopicCategory> categoriesForRole(HelpRole role) {
    switch (role) {
      case HelpRole.staff:
        return const [
          HelpTopicCategory.dailyWork,
          HelpTopicCategory.communications,
          HelpTopicCategory.documents,
          HelpTopicCategory.sharedMode,
          HelpTopicCategory.account,
          HelpTopicCategory.troubleshooting,
        ];
      case HelpRole.manager:
        return const [
          HelpTopicCategory.oversight,
          HelpTopicCategory.communications,
          HelpTopicCategory.documents,
          HelpTopicCategory.account,
          HelpTopicCategory.troubleshooting,
        ];
      case HelpRole.admin:
        return const [
          HelpTopicCategory.setup,
          HelpTopicCategory.operationsControl,
          HelpTopicCategory.communications,
          HelpTopicCategory.documents,
          HelpTopicCategory.account,
          HelpTopicCategory.troubleshooting,
        ];
    }
  }

  static List<HelpTopic> relatedTopics(HelpTopic topic) {
    return forRole(topic.roles.first)
        .where(
          (candidate) =>
              candidate.id != topic.id &&
              candidate.category == topic.category &&
              candidate.isTroubleshooting == topic.isTroubleshooting,
        )
        .take(3)
        .toList();
  }
}
