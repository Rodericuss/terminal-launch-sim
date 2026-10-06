# Progressão computacional retrofuturista

**Estado:** dois desbloqueios jogáveis; IA e supercomputação em planejamento. O protótipo salva pontos, filtragem e rede de sensores em um perfil JSON local. O universo usa a linguagem visual e as ideias precursoras dos anos 1990, mas acelera deliberadamente a evolução do poder computacional. A linha do tempo é fictícia.

## Ciclo de jogo

1. Planejar uma missão com os instrumentos disponíveis e registrar uma previsão.
2. Operar a missão, coletando telemetria e eventos com incerteza explícita.
3. Comparar previsão e observação no relatório. Dados válidos e objetivos cumpridos geram **pontos de pesquisa**; repetir comandos sem novos dados não gera pontos.
4. Investir pontos, capacidade elétrica e manutenção em uma tecnologia. O desbloqueio fica no perfil da campanha e abre instrumentos ou análises para as missões seguintes.
5. Reexecutar cenários com a mesma semente e modelo para comparar o efeito da tecnologia sobre a informação disponível, sem mudar as leis do cenário.

Nesta versão, uma missão concluída com sucesso concede dois pontos; uma conclusão parcial concede um. A mesma combinação de modo e semente só pontua uma vez, mesmo depois de reiniciar o cliente. A bancada custa dois pontos; a rede exige a bancada e custa mais três. Ambas só afetam missões criadas depois da compra. Os custos e a produção de pontos ainda precisam de balanceamento. A progressão não depende de esperar tempo real nem de compras externas. Modo prática e modo avaliação ainda não foram implementados.

## Árvore proposta

| Etapa | Referência conceitual | Equipamento fictício | Efeito no jogo | Custo e limite |
| --- | --- | --- | --- | --- |
| 0. Sala de máquinas | terminais, calculadoras e sistemas especialistas | console central | leituras básicas, previsão manual e relatórios simples | poucos canais e atraso alto |
| 1. Estações de análise | processamento digital de sinais e estações de trabalho | bancada de filtragem | faixa de incerteza menor após calibração; histórico de séries temporais | consome energia e exige amostras de calibração |
| 2. Rede de sensores | telemetria distribuída e dispositivos conectados | malha de nós | dois canais de altitude e alerta de divergência; aviso de prazo na central | custa 3 pontos; falha de canal ainda não simulada |
| 3. Apoio à decisão | sistemas especialistas e aprendizado estatístico | laboratório de hipóteses | compara múltiplas previsões e destaca anomalias com taxa de erro visível | exige dados rotulados e validação; não emite comandos sozinho |
| 4. Supercomputação | computação paralela e simulação numérica | conjunto de computadores | executa conjuntos de simulações e apresenta intervalo de resultados | alto custo de energia, manutenção e tempo de cálculo |

As etapas representam **capacidades de jogo**, não uma cronologia técnica literal. Nomes comerciais, números de desempenho e datas históricas não são necessários para a ficção.

## Efeito nas campanhas

- **Espacial:** filtragem torna a altitude observada mais confiável; a rede compara sensores; o laboratório e o conjunto de computadores permitem comparar trajetórias previstas com telemetria e explorar incertezas. Empuxo, massa, gravidade e arrasto seguem o modelo científico versionado da missão.
- **Central fictícia:** a rede avisa quando cada contato aberto chega a cinco segundos do prazo; apoio à decisão ordenará hipóteses e mostrará confiança; supercomputação comparará cenários de alocação de equipes. Prazos, trabalho exigido e resultado seguem as regras versionadas do cenário.

Cada melhoria precisa aparecer no catálogo de modelos com versão, entradas, unidade, hipótese, custo e teste de referência. Replay registra perfil tecnológico e versão da árvore no início da partida. Uma alteração de tecnologia durante uma missão só ocorre se a regra do cenário permitir e fica registrada como comando. Relatórios mostram quais decisões vieram do jogador e quais análises foram oferecidas pelo sistema.

## Incrementos implementados

O perfil persistente registra pontos, nível desbloqueado, próximo ID de partida e combinações de modo/semente já recompensadas. O protocolo concede pontos ao fechar uma missão e recusa recompensa duplicada. `tech.status` mostra o perfil; `tech.unlock` compra a **bancada de filtragem**. Ela reduz o erro de altitude de ±5 m para ±3 m no modo espacial e elimina o jitter de ±1 s na estimativa de prazo da central. A leitura verdadeira e a regra de vitória ficam iguais. Os testes comparam a mesma semente antes e depois da melhoria.

A rede de sensores adiciona duas leituras de altitude e uma estimativa combinada no modo espacial; divergências de pelo menos 4 m geram aviso, limitado a um por 10 s simulados. Na central, cada contato aberto gera um aviso ao chegar a cinco segundos do prazo. Os alertas ajudam o jogador a reagir, mas não mudam a trajetória, o prazo ou a regra de vitória. O perfil usa JSON atômico em `~/.local/share/terminal-launch-sim/profile.json` (ou `XDG_DATA_HOME`/`TLS_PROFILE_PATH`) enquanto o projeto ainda não tem a persistência SQLite especificada para V1. Partidas não são retomadas após reinício. Apoio à decisão e supercomputação continuam metas sem efeito jogável.
