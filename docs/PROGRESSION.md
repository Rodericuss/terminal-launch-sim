# Progressão computacional retrofuturista

**Estado:** proposta de design para implementação. O protótipo atual ainda não salva progresso nem aplica esta árvore. O universo usa a linguagem visual e as ideias precursoras dos anos 1990, mas acelera deliberadamente a evolução do poder computacional. A linha do tempo é fictícia.

## Ciclo de jogo

1. Planejar uma missão com os instrumentos disponíveis e registrar uma previsão.
2. Operar a missão, coletando telemetria e eventos com incerteza explícita.
3. Comparar previsão e observação no relatório. Dados válidos e objetivos cumpridos geram **pontos de pesquisa**; repetir comandos sem novos dados não gera pontos.
4. Investir pontos, capacidade elétrica e manutenção em uma tecnologia. O desbloqueio fica no perfil da campanha e abre instrumentos ou análises para as missões seguintes.
5. Reexecutar cenários com a mesma semente e modelo para comparar o efeito da tecnologia sobre a informação disponível, sem mudar as leis do cenário.

O custo e a produção de pontos ainda precisam de balanceamento. A progressão não depende de esperar tempo real nem de compras externas. Modo prática permite experimentar equipamentos sem alterar o perfil; modo avaliação usa o perfil salvo.

## Árvore proposta

| Etapa | Referência conceitual | Equipamento fictício | Efeito no jogo | Custo e limite |
| --- | --- | --- | --- | --- |
| 0. Sala de máquinas | terminais, calculadoras e sistemas especialistas | console central | leituras básicas, previsão manual e relatórios simples | poucos canais e atraso alto |
| 1. Estações de análise | processamento digital de sinais e estações de trabalho | bancada de filtragem | faixa de incerteza menor após calibração; histórico de séries temporais | consome energia e exige amostras de calibração |
| 2. Rede de sensores | telemetria distribuída e dispositivos conectados | malha de nós | mais pontos de observação e detecção de divergência entre sensores | canais podem falhar; dados conflitantes exigem revisão |
| 3. Apoio à decisão | sistemas especialistas e aprendizado estatístico | laboratório de hipóteses | compara múltiplas previsões e destaca anomalias com taxa de erro visível | exige dados rotulados e validação; não emite comandos sozinho |
| 4. Supercomputação | computação paralela e simulação numérica | conjunto de computadores | executa conjuntos de simulações e apresenta intervalo de resultados | alto custo de energia, manutenção e tempo de cálculo |

As etapas representam **capacidades de jogo**, não uma cronologia técnica literal. Nomes comerciais, números de desempenho e datas históricas não são necessários para a ficção.

## Efeito nas campanhas

- **Espacial:** filtragem torna a altitude observada mais confiável; a rede compara sensores; o laboratório e o conjunto de computadores permitem comparar trajetórias previstas com telemetria e explorar incertezas. Empuxo, massa, gravidade e arrasto seguem o modelo científico versionado da missão.
- **Central fictícia:** a rede revela mais contatos e atrasos de comunicação; apoio à decisão ordena hipóteses e mostra confiança; supercomputação compara cenários de alocação de equipes. Prazos, trabalho exigido e resultado seguem as regras versionadas do cenário.

Cada melhoria precisa aparecer no catálogo de modelos com versão, entradas, unidade, hipótese, custo e teste de referência. Replay registra perfil tecnológico e versão da árvore no início da partida. Uma alteração de tecnologia durante uma missão só ocorre se a regra do cenário permitir e fica registrada como comando. Relatórios mostram quais decisões vieram do jogador e quais análises foram oferecidas pelo sistema.

## Primeiro incremento implementável

Criar um perfil persistente com pontos de pesquisa e etapa desbloqueada. Após uma missão concluída, conceder pontos uma única vez pelo `run_id`, usando critérios verificáveis no relatório. Implementar primeiro a **bancada de filtragem**: um comando de calibração usa amostras e reduz a faixa de incerteza da altitude observada na missão espacial; na central, reduz a incerteza do prazo estimado. A leitura verdadeira e a regra de vitória ficam iguais. Testar antes/depois com a mesma semente e replay do perfil.
