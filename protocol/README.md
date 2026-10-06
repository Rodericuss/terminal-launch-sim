# Protocolo local v1

O cliente inicia o processo em `engine/` após `mix deps.get && mix compile --quiet`:

```sh
mix run --no-compile -e 'Engine.Protocol.main(System.argv())' --
```

Uma mensagem JSON por linha em stdin e stdout. Diagnósticos vão para stderr. Mensagens acima de 65.536 bytes são rejeitadas. A leitura atual usa `IO.gets/2`, que aloca a linha completa antes de verificar o limite; um transporte com leitura limitada ainda é necessário antes de aceitar clientes não confiáveis. O processo mantém partidas em memória enquanto estiver aberto; partidas não são retomadas após reinício. O perfil de pesquisa persiste em JSON local (`XDG_DATA_HOME` ou `~/.local/share/terminal-launch-sim/profile.json`); `TLS_PROFILE_PATH` permite isolá-lo. Alterações do perfil são salvas antes da resposta de confirmação.

## Envelope

Pedido:

```json
{"protocol_version":1,"request_id":"req-1","run_id":null,"seq":0,"type":"run.create","payload":{"mode":"space","seed":42}}
```

Resposta:

```json
{"protocol_version":1,"request_id":"req-1","run_id":"run-1","seq":0,"type":"response","payload":{"ok":true,"data":{"snapshot":{"run_id":"run-1","seq":0,"observation":{"mode":"space","model_version":"0.3.0","tech_level":0,"time_s":0,"status":"active","phase":"ready","altitude_m":0,"velocity_m_s":0,"fuel_kg":100.0,"peak_altitude_m":0,"altitude_uncertainty_m":5,"target_altitude_m":2000.0,"check_complete":false},"events":[]}}}}
```

Erro:

```json
{"protocol_version":1,"request_id":"req-2","run_id":"run-1","seq":0,"type":"response","payload":{"ok":false,"error":{"code":"check_required","message":"Command rejected: check_required"}}}
```

`request_id` não vazio e com até 128 bytes. A repetição de um `request_id` no mesmo processo devolve a resposta original sem repetir seus efeitos. `seq` é o número de ticks completos da partida. Um `run.command` deve enviar o `seq` mais recente; se estiver desatualizado, recebe `sequence_mismatch` e pode chamar `run.snapshot`. Erros não alteram a partida. Todas as respostas incluem os seis campos do envelope.

## Operações disponíveis

| Tipo | Payload | Dados da resposta |
| --- | --- | --- |
| `catalog.list` | `{}` | `model_version`, `modes` com comandos |
| `run.create` | `{"mode":"space"|"central","seed":42}` | `snapshot` inicial |
| `run.command` | `{"command":"check"}` | `snapshot` após o comando |
| `run.snapshot` | `{}` | `snapshot` atual, com `events:[]` |
| `calculator.evaluate` | `{"model":"average_speed","inputs":{"distance_m":100,"time_s":20}}` | `result` com valor, unidade, versão e explicação |
| `tech.status` | `{}` | `profile` com pontos, nível e próximo desbloqueio |
| `tech.unlock` | `{"id":"filter"}` ou `{"id":"network"}` | `profile` atualizado ou erro por pontos/pré-requisito |

Comandos espaciais: `check`, `launch`, `abort`, `wait`, `wait N` (1 a 500). Comandos da central: `assign orion`, `assign vega`, `recall orion`, `recall vega`, `wait`, `wait N`. `wait N` executa até N passos de um segundo e para quando a partida termina.

Calculadora: `average_speed` usa `distance_m` e `time_s`; `work_eta` usa `remaining_work` e `teams`.

O snapshot contém apenas `Engine.observe/1`, sem semente, estado aleatório ou valores verdadeiros internos. `events` contém os eventos produzidos por aquele comando. `run.create` e `run.snapshot` devolvem `events:[]`.

Ao fechar uma missão, `run.command` devolve `research_points_earned` (0, 1 ou 2). O mesmo par modo/semente pontua uma única vez no perfil. A bancada de filtragem custa dois pontos e afeta somente partidas criadas após `tech.unlock`: altitude espacial ±3 m em vez de ±5 m e prazo estimado da central com jitter zero em vez de ±1 s. A rede de sensores custa três pontos após a bancada: adiciona dois canais de altitude e alerta de divergência no voo; na central, alerta uma vez por contato aberto ao se aproximar do prazo. IA e supercomputação ainda não estão implementadas.
