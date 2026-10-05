# Simulador de Central de Lançamentos — especificação v0.1

**Estado:** proposta de produto e arquitetura, para revisão antes da implementação.
**Data:** 2026-10-05.
**Nome de trabalho:** Terminal Launch Sim. O nome comercial ainda não foi definido.

## 1. Visão

Jogo educacional de simulação operado por uma interface de terminal. O jogador assume o posto de operador ou comandante de uma central fictícia, estuda os instrumentos, usa uma calculadora integrada, emite comandos, compara previsões com telemetria e responde a imprevistos. A experiência deve transmitir trabalho técnico e tensão operacional sem depender de gráficos 3D.

Há **dois modos obrigatórios na versão 1**:

1. **Programa espacial:** missões de pesquisa e exploração com foguetes, da preparação à análise do voo.
2. **Central militar fictícia:** exercícios de comando com múltiplos eventos simultâneos, contatos e alertas, em cenários inventados. As decisões do jogador e os cálculos do modelo afetam a resolução da missão.

Os dois modos compartilham relógio, eventos, unidades, calculadora, telemetria, persistência e replay. Têm regras de missão e apresentação próprias. A modalidade militar representa equipamentos e operações fictícios; a especificação não depende de parâmetros de armamentos reais.

**V1 pronta** significa os dois modos jogáveis de ponta a ponta, com cálculos efetivos, missões completas, tutoriais, salvamento, replay, validação do modelo e interface utilizável. Um protótipo com apenas o modo espacial não é V1.

## 2. Princípios de jogo

- **Instrumentos, não botões mágicos:** comandos revelam ou alteram um estado mensurável; alertas têm causa e efeito.
- **Matemática útil:** o jogador pode estimar um resultado, conferir unidades, usar a calculadora e depois comparar previsão e observação. Números exibidos precisam participar da simulação.
- **Conhecimento gradual:** o tutorial ensina fundamentos; missões posteriores exigem combinar conceitos.
- **Tensão legível:** condições mudam e há prazos, mas o jogador consegue consultar histórico, pausar onde o cenário permitir e entender por que falhou.
- **Reprodução:** mesma versão do modelo, cenário, semente aleatória e sequência de comandos produzem o mesmo resultado.
- **Sem falsa precisão:** cada grandeza declara unidade, origem, hipótese e limitações do modelo. A fidelidade é documentada por subsistema, não prometida como “realismo total”.

## 3. Experiência e estética

Referência visual principal: **computadores e centros de comando da Guerra Fria**. Influência secundária: interfaces de terminal vistas em *Matrix*. O período histórico não precisa ser reconstituído literalmente; cenário, equipamentos e nomenclatura do jogo são ficcionais. Evitar a aparência de interface moderna com um filtro verde por cima.

Layout inicial em terminal largo:

```text
┌────────────────── VISÃO DA MISSÃO / ASCII ──────────────────────┐
│ Mapa, silhueta, trajetória esquemática ou painel de instrumentos │
├──────── TELEMETRIA ────────┬────────── ALERTAS / LOG ──────────┤
│ Leituras com unidades      │ Eventos em ordem temporal         │
├────────────────────────────┴───────────────────────────────────┤
│ > COMANDO / CALCULADORA / AJUDA                                  │
└─────────────────────────────────────────────────────────────────┘
```

O painel visual ocupa aproximadamente a metade superior; o console fica embaixo. A proporção é adaptável à largura e altura do terminal. Na largura pequena, alternar abas em vez de comprimir dados. Suportar navegação por teclado, alto contraste, paletas âmbar, fósforo verde e monocromática, redução de animações e texto sem cor. ASCII e caracteres de desenho podem representar veículos, instalações, mapas esquemáticos e alertas. Gráficos de séries temporais devem usar widgets do terminal, com dados textuais acessíveis.

O Ratatui oferece `Canvas`, `Chart`, `Gauge`, `Table` e outros widgets, além de exemplos de aplicações completas. Isso viabiliza a exploração visual em terminal sem motor 3D. O protótipo visual deve comparar três opções com os mesmos dados: painel técnico, cena ASCII e composição híbrida. A escolha final depende de legibilidade e jogabilidade, não só de aparência.

## 4. Escopo funcional da V1

### 4.1 Núcleo de simulação e matemática

- Estado imutável avançado por função determinística `step(state, commands, dt) -> {state, events}`; relógio simulado e passo fixo. Interpolar apenas a apresentação.
- Catálogo versionado de grandezas, unidades, limites e hipóteses. Conversão e validação de unidades antes dos cálculos.
- Modelo espacial educacional com movimento, forças, massa variável, atmosfera simplificada, condições ambientais, fases do voo, sensores com incerteza e eventos de falha. A lista final de equações, domínios válidos e tolerâncias entra em um documento separado de modelo científico antes de programar cada subsistema.
- Modelo da central fictícia com múltiplos contatos, estados de sensores, latências, recursos, janelas de decisão e resolução de eventos. Os cálculos de tempo, capacidade, probabilidade e incerteza devem ser explícitos e auditáveis dentro do universo do jogo.
- Semente de aleatoriedade gravada na partida. Erros de sensor e falhas são derivados da semente, não de chamadas aleatórias ocultas.
- Calculadora integrada com operações gerais, conversão de unidades, planilha simples de hipóteses e modelos de previsão ligados aos conteúdos ensinados. Mostrar entradas, resultado, unidade, explicação e versão do modelo.
- Separar **valor verdadeiro de simulação**, **valor observado pelo jogador** e **previsão calculada pelo jogador**. A diferença entre eles sustenta investigação e aprendizado.
- Velocidade da simulação: pausa, normal e aceleração quando a missão permitir; comandos são aplicados em um instante definido do relógio simulado.

### 4.2 Modo espacial

No mínimo uma campanha curta com preparação, missão executável e relatório pós missão; vários cenários progressivos devem cobrir planejamento, checagem, lançamento, acompanhamento, falhas e análise. O sucesso depende dos parâmetros escolhidos, das condições reveladas pelos instrumentos e das ações durante a missão. Incluir pelo menos uma missão de foguete de pesquisa e uma missão espacial mais avançada, com a fidelidade de cada uma descrita no catálogo de modelos.

### 4.3 Modo central militar fictícia

No mínimo uma campanha curta com treinamento, exercício com múltiplos eventos simultâneos e relatório pós missão. O jogador observa um quadro operacional esquemático, consulta dados e aloca atenção e recursos sob restrições de tempo. O modo deve exigir cálculos do sistema e do jogador, exibir incerteza e permitir explicar cada resultado no replay. Cenários e equipamentos são fictícios. O conteúdo de jogo privilegia leitura de instrumentos, coordenação, comunicação e decisão.

### 4.4 Conteúdo e progressão

Tutoriais interativos por conceito, glossário, ajuda contextual, objetivos claros, avaliação pós missão e histórico de decisões. Cada missão tem critérios de sucesso, falha e conclusão parcial. Dificuldade altera assistência e visibilidade, sem trocar silenciosamente as leis do modelo. Incluir modo de prática com pausa livre e modo de avaliação com regras específicas.

## 5. Arquitetura recomendada

```text
┌──────────────────────── Rust + Ratatui ────────────────────────┐
│ Entrada, layout, ASCII, gráficos, áudio opcional, acessibilidade │
└─────────────────────── protocolo local ────────────────────────┘
┌──────────────────────── Elixir / OTP ───────────────────────────┐
│ Adaptador do protocolo → sessão → motor puro → eventos          │
│                         ↘ persistência / catálogo / calculadora │
└───────────────────────────────┬─────────────────────────────────┘
                            SQLite
```

**Elixir** é a linguagem principal das regras, estado de sessão, orquestração e persistência. **Rust/Ratatui** é o cliente TUI. O motor de passo deve ser código funcional puro, sem acesso a banco, relógio do sistema ou terminal; isso permite testes, replay e futura otimização pontual em Rust se medições comprovarem necessidade. Não criar um processo OTP por projétil, contato ou leitura: a concorrência representa sessões e trabalhos independentes; a ordem dos objetos dentro de uma simulação é determinística.

Uma `MissionSession` supervisionada mantém o estado ativo de cada partida. `DynamicSupervisor` inicia sessões; `Registry` encontra sessões por ID. O processo recebe comandos serializados, valida versão/estado, executa o passo, publica eventos para o cliente e solicita persistência. Falha de cliente não deve destruir a partida salva. O fluxo de eventos usa as caixas de mensagens do BEAM; limites de fila e sinais de sobrecarga devem impedir acumulação ilimitada. Leituras de telemetria podem ser agregadas para apresentação, enquanto comandos e eventos relevantes são preservados.

**Alternativa considerada:** jogo inteiro em Rust reduziria a ponte entre linguagens e possivelmente facilitaria a distribuição. Preferimos Elixir porque o usuário quer explorar OTP e porque estado de missões, eventos e recuperação se encaixam bem no BEAM. Caso o núcleo numérico medido se torne gargalo, otimizar somente esse núcleo ou movê-lo para Rust preserva o restante da arquitetura.

## 6. Comunicação entre TUI e motor

V1 local, sem conta ou servidor remoto. O cliente Rust inicia o executável Elixir como processo filho e conversa por **mensagens JSON delimitadas por linha** em `stdin/stdout`, com logs técnicos em `stderr`. Versão de protocolo, `request_id`, `run_id`, número sequencial, tipo e payload em cada mensagem. Nenhum texto de depuração pode entrar no canal JSON. Tamanho máximo, validação de esquema, timeout, reconexão/reinício e tratamento de erro são requisitos de implementação. Um socket local pode substituir o transporte sem mudar o contrato se a execução como processo filho se mostrar insuficiente.

Operações de comando, não CRUD genérico:

| Operação | Finalidade |
| --- | --- |
| `catalog.list` / `catalog.get` | Consultar modos, cenários, lições e definições de modelo. |
| `run.create` / `run.load` / `run.list` | Criar, retomar e listar partidas. |
| `run.command` | Enviar comando do jogador com `request_id` idempotente. |
| `run.pause` / `run.resume` / `run.speed` | Controlar relógio conforme regras da missão. |
| `run.snapshot` | Obter estado observável completo após entrada ou recuperação. |
| `calculator.evaluate` | Avaliar expressão ou modelo educacional com entradas e unidades. |
| `run.save` / `run.report` / `run.replay` | Persistir, analisar e reproduzir missão. |
| `settings.get` / `settings.update` | Paleta, acessibilidade, som e controles. |

Eventos enviados pelo motor: `run.started`, `state.changed`, `telemetry.updated`, `alert.raised`, `command.accepted`, `command.rejected`, `run.finished`, `save.completed` e `engine.error`. Enviar `snapshot` inicial e depois deltas com sequência; se houver lacuna, o cliente pede novo `snapshot`. Comandos alteradores recebem confirmação ou erro explícito. Definir um esquema versionado em `protocol/` e testes de contrato nas duas linguagens.

## 7. Persistência relacional

**SQLite + Ecto** para um jogo local e um jogador. Banco em diretório de dados do usuário, migrações versionadas, backup antes de migração incompatível e exportação de partidas. O estado em execução fica na memória; não gravar todo frame. Persistir comandos e eventos importantes, mais snapshots periódicos e ao salvar/encerrar. Uma transação associa evento, sequência e snapshot quando necessário.

| Tabela | Campos principais | Relação |
| --- | --- | --- |
| `scenario_packs` | id, slug, version, title, license, checksum | Agrupa conteúdo. |
| `scenarios` | id, pack_id, mode, model_version, seed_policy, config_json, goals_json | Pertence a pack. |
| `lessons` | id, scenario_id, order, content_ref, objectives_json | Tutorial e currículo. |
| `model_definitions` | id, version, kind, assumptions_json, units_json, source_refs_json, checksum | Modelo auditável. |
| `runs` | id, scenario_id, model_version, seed, status, sim_time, started_at, finished_at, result_json | Partida. |
| `run_commands` | id, run_id, seq, request_id, sim_time, command_type, args_json, outcome_json | Entrada reproduzível; `request_id` único por partida. |
| `run_events` | id, run_id, seq, sim_time, event_type, payload_json | Histórico relevante. |
| `run_snapshots` | id, run_id, seq, sim_time, schema_version, state_blob, checksum | Recuperação e replay rápido. |
| `player_notes` | id, run_id, sim_time, body | Anotações do jogador. |
| `settings` | key, value_json | Configurações locais. |

Índices: `(run_id, seq)` em comandos/eventos/snapshots, `scenarios(mode)`, `runs(status, started_at)`. Usar chaves estrangeiras e política explícita de exclusão. `config_json` e `payload_json` guardam conteúdo versionado; campos consultados frequentemente são colunas. Definições de cenário e conteúdo autoral ficam também em arquivos de texto versionados no repositório; o banco instalado é uma projeção para execução.

## 8. Documentação e futura busca vetorial/IA

**Fonte de verdade:** Markdown/JSON versionados para regras, modelos, unidades, missões, tutoriais, glossário, decisões de arquitetura, formato do protocolo, testes de referência e notas de versão. Cada página deve ter ID estável, título, tipo, modo, versão do modelo, idioma, referências, data de revisão e vínculo com o conteúdo executável. Todo número de uma explicação técnica deve apontar para hipótese/modelo e teste de referência. Documentar também limites conhecidos e mudanças de modelo entre versões.

**V1:** busca textual local no conteúdo, sem exigir IA nem um segundo banco. **Preparação para IA futura:** pipeline que fragmenta documentos por seção sem cortar fórmulas/tabelas, mantém `document_id`, `section_id`, hash do texto, versão, idioma, fontes, licença e vínculos com cenário/modelo. Uma tabela `knowledge_documents` registra metadados; `knowledge_chunks` registra texto e posição. Embeddings são índices derivados e reconstruíveis, nunca substitutos do documento. Uma futura `knowledge_embeddings` liga chunk, modelo de embedding, dimensão, versão e hash do texto. Reindexar quando documento ou modelo mudar; resultados de IA devem citar seção e versão. Não indexar segredos, saves pessoais ou dados de jogador por padrão.

Se a busca semântica virar requisito medido, avaliar **sqlite-vec** no mesmo SQLite para instalação local; o projeto ainda se declara pré-1.0, então encapsular a busca atrás de uma interface e testar migração/reindexação. Um banco vetorial separado só faz sentido se escala, colaboração ou implantação remota o exigirem. Nenhum recurso de IA é requisito para considerar a V1 pronta.

## 9. Mensageria e filas

- **Tempo real do jogo:** mensagens OTP e caixa de entrada da sessão. Processar comandos de uma partida em ordem; eventos de apresentação podem ser coalescidos. Não usar fila externa no caminho crítico do relógio, pois reentrega e atraso poderiam quebrar a ordem determinística.
- **Trabalhos duráveis fora do relógio:** exportação de replay, geração de relatórios extensos, importação de conteúdo e futura indexação vetorial podem ir para Oban com SQLite (`Oban.Engines.Lite`) quando existirem. Para a V1, a necessidade concreta é persistência confiável de saves e relatórios; se os trabalhos forem curtos e síncronos, não instalar Oban até haver carga real.
- **Critério para adicionar fila:** trabalho precisa sobreviver a reinício, ter retentativa/idempotência e não pode bloquear a sessão. Medir latência e volume antes. Kafka/RabbitMQ não têm papel no jogo local de um jogador.

## 10. Etapas até a V1

Cada etapa termina com código, documentação e demonstração verificável. Protótipos intermediários não recebem o rótulo de V1.

1. **Contrato de produto:** detalhar campanha e missão final de cada modo, público, controles, ritmo, dificuldade, lista de comandos, histórias do jogador e critérios de aceitação. Fechar os limites de fidelidade de cada modelo.
2. **Catálogo científico e de regras:** registrar grandezas, unidades, entradas, saídas, hipóteses, domínios válidos, fontes e tolerâncias; produzir exemplos calculados independentemente para testes. Definir os cálculos do modo espacial e os cálculos de estado/decisão do modo militar fictício.
3. **Motor determinístico:** implementar estado, passo fixo, relógio, semente, eventos, comandos, calculadora e testes de reprodução; rodar ambos os modos sem TUI.
4. **Persistência e protocolo:** migrações, criação/retomada de partidas, eventos, snapshots, replay, mensagens JSON e testes de contrato Rust/Elixir.
5. **TUI jogável:** entrada de comandos, ajuda, visualização ASCII, telemetria, alertas, calculadora, paletas e acessibilidade; testar tamanhos de terminal e recuperação de falha.
6. **Campanha espacial completa:** conteúdo, progressão, falhas, tutoriais, relatórios e validação do modelo.
7. **Campanha militar fictícia completa:** múltiplos eventos, decisões, progressão, tutoriais, relatórios e validação das regras.
8. **Acabamento:** balanceamento, revisão de linguagem, testes de sessão longa e carga, perfil de CPU/memória, distribuição local, migração/backup e documentação do jogador.
9. **Gate de V1:** executar a matriz da seção 11 em instalação limpa; corrigir falhas antes de declarar pronta.

## 11. Critérios de pronto verificáveis

- Pelo menos uma campanha completa em **cada modo**, com início, progressão, conclusão e relatório; tutoriais suficientes para jogar sem documentação externa.
- Calculadora e modelos versionados presentes nos dois modos; entradas, unidades, hipóteses e saídas consultáveis no jogo. Cálculos mudam decisões e resultados.
- Testes de referência independentes cobrem casos típicos, limites e entradas inválidas; tolerâncias definidas por grandeza. Nenhuma grandeza exibida sem unidade ou indicação de que é estimativa.
- Replay reproduz resultado, sequência de eventos e leituras observáveis com mesma semente/modelo; saves retomam sem perda de comandos confirmados.
- Interface opera inteiramente por teclado, suporta tela pequena, paleta sem cor e leitura textual dos gráficos; não depende de 3D.
- Dois cenários com eventos simultâneos mantêm responsividade; limites de CPU, memória e latência serão fixados após um benchmark de referência no hardware alvo, antes do gate final.
- Teste de instalação limpa, atualização de banco, backup/restauração e falha/reinício do processo de interface concluídos.
- Documentação de regras, modelos, conteúdo, protocolo, dados, build e distribuição acompanha a versão lançada.

## 12. Decisões abertas para revisão

1. Nome final, idioma inicial e plataformas alvo (Linux apenas ou também macOS/Windows).
2. Perspectiva do jogador em cada campanha: operador único ou equipe representada pelo sistema.
3. Lista exata de missões, grandezas e tolerâncias científicas por modelo. Esta é a principal definição pendente antes de estimar esforço.
4. Ritmo: tempo real com pausa, turnos, ou mistura; regras de pausa por campanha.
5. Estilo visual final após protótipo comparativo ASCII/painel/híbrido.
6. Som e efeitos de terminal: desejados, opcionais e desativáveis.

## 13. Referências técnicas iniciais

- [Elixir: GenServer](https://elixir.hexdocs.pm/genservers.html) e [DynamicSupervisor](https://elixir.hexdocs.pm/dynamic-supervisor.html).
- [Ratatui: widgets](https://ratatui.rs/concepts/widgets/), [Canvas](https://ratatui.rs/examples/widgets/canvas/) e [exemplos completos](https://ratatui.rs/examples/apps/).
- [Ecto SQLite3](https://ecto-sqlite3.hexdocs.pm/).
- [Oban com SQLite](https://oban.hexdocs.pm/installation.html), se trabalhos duráveis justificarem a dependência.
- [sqlite-vec](https://github.com/asg017/sqlite-vec), opção futura de busca vetorial local.
- [NASA: Guide to Rockets](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/guide-to-rockets/), ponto de partida para currículo e validação do modo espacial.
