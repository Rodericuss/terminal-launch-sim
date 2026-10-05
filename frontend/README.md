# Cliente de terminal

Interface Rust/Ratatui para os dois exercícios introdutórios do motor Elixir. Execute em um terminal com pelo menos 40 colunas e 12 linhas:

```sh
cd frontend
cargo run
```

É preciso ter Rust/Cargo, Elixir/Mix e acesso às dependências Hex na primeira execução. O cliente resolve `../engine` a partir de sua própria pasta, executa `mix deps.get` e `mix compile --quiet` antes de abrir a interface e então inicia o processo JSONL. Defina `TLS_ENGINE_DIR` para usar outro diretório do motor.

Na abertura, pressione `1` para o programa espacial ou `2` para a central fictícia. Digite comandos na linha inferior e pressione Enter. `F1` abre ajuda, `F2` troca entre âmbar, verde e sem cor, `Tab` ou `F3` alterna os painéis em terminais pequenos e `Ctrl+C` sai. A interface não usa animação. `Esc` limpa a entrada. Os comandos `space` e `central` iniciam novos exercícios.

Comandos do programa espacial: `check`, `launch`, `abort`, `wait N`. Comandos da central: `assign orion`, `assign vega`, `recall orion`, `recall vega`, `wait N`. `N` vai de 1 a 500. `snapshot` sincroniza os instrumentos. A calculadora usa `calc speed DISTÂNCIA_M TEMPO_S` ou `calc eta TRABALHO_RESTANTE EQUIPES`.

A TUI usa o contrato em [`../protocol/README.md`](../protocol/README.md). A simulação atual é um protótipo: não salva partidas, não inclui campanhas e não mantém estado ao fechar o cliente.
