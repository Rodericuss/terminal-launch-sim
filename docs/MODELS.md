# Modelos do protótipo 0.3.0

Estes valores são **hipóteses de jogo** e não representam um veículo, sistema militar ou ambiente operacional real. O modelo espacial serve para ensinar relação entre massa, força, arrasto e altitude. O modo central serve para ensinar alocação de recursos e prazos. Nenhum dos dois foi validado para uso fora do jogo.

## Voo vertical de pesquisa

O cenário começa em altitude zero, velocidade zero, massa seca de 80 kg e combustível de 100 kg. Após `check`, `launch` liga um motor de empuxo constante de 4.000 N e consumo de 2 kg/s. A cada segundo, a massa usada no cálculo é a massa no meio do passo. Gravidade constante: 9,81 m/s². Densidade do ar: `1,225 * exp(-altitude_m / 8.500)` kg/m³. Arrasto vertical: `0,5 * densidade * 0,12 * velocidade * abs(velocidade)` N. A velocidade usa Euler explícito; altitude usa a média entre as velocidades anterior e nova. O chão limita a altitude a zero.

O voo encerra ao voltar ao chão. Apogeu de pelo menos 2.000 m dá `success`; abaixo disso dá `partial`. `abort` dá `failed`. A leitura de altitude é arredondada a metros e recebe erro uniforme determinístico de até 5 m por passo, derivado da semente. Com a bancada de filtragem, o limite cai para 3 m usando a mesma amostra aleatória. Com a rede de sensores, dois canais com amostras distintas da sequência pseudoaleatória e erro de até 3 m são mostrados e a altitude observada usa a média arredondada dos canais. A divergência entre eles fica visível; quando chega a 4 m, um alerta é emitido, limitado a um por intervalo de 10 s simulados. A velocidade exibida é a velocidade verdadeira arredondada a m/s; este canal ainda não simula erro de sensor. O apogeu exibido é o máximo verdadeiro arredondado, uma informação de relatório, não leitura instantânea. O motor guarda valor verdadeiro separado da observação.

Domínio pretendido: voo vertical curto, altitude não negativa, passo fixo de 1 s. Não há orientação, vento, rotação, propagação de incerteza, variação de gravidade, fases de paraquedas ou precisão perto do instante exato de pouso. A integração e os parâmetros precisam de comparação independente antes de virar modelo de campanha.

## Central fictícia

Duas estações de comunicação fictícias entram ao mesmo tempo. Órion tem prazo de 12 s e exige 4 unidades de trabalho; Vega tem prazo de 18 s e exige 6. Há duas equipes. Cada equipe alocada entrega uma unidade de trabalho por segundo. Um contato resolve quando o trabalho acumulado atinge seu requisito; se não resolver até o prazo, fica `missed`. Equipes voltam ao conjunto disponível quando o contato fecha. A missão termina quando ambos fecham: `success` se ambos resolveram, `partial` caso contrário.

O prazo verdadeiro fica no estado do motor. O painel mostra `estimated_remaining_s`, calculado pelo prazo restante mais um atraso fictício de comunicação entre -1 s e +1 s, escolhido pela semente a cada passo. A incerteza de ±1 s pode afetar a decisão do jogador; o prazo real continua determinando o resultado. Com a bancada de filtragem, o jitter é zero e a estimativa de prazo fica exata neste modelo introdutório. Com a rede de sensores, cada contato aberto gera um aviso único ao chegar a cinco segundos ou menos do prazo verdadeiro. A previsão `work_eta` da calculadora usa `ceil(remaining_work / teams)` segundos. Os valores e nomes são inventados, sem equivalência com equipamento ou procedimento militar real.

## Reprodutibilidade e calculadora

`step(state, command, 1)` não lê relógio do sistema nem aleatoriedade global. O gerador LCG tem módulo 2³², multiplicador 1.664.525 e incremento 1.013.904.223. A semente faz parte do estado. O log guarda eventos com `time_s`; comandos ainda precisam ser persistidos separadamente na próxima etapa. `Engine.replay/3` executa uma lista de comandos a partir da mesma semente.

`average_speed` recebe distância em metros e tempo positivo em segundos e devolve m/s. `work_eta` recebe unidades inteiras de trabalho restantes e número positivo de equipes e devolve segundos inteiros. Ambas retornam explicação e versão do modelo. As funções recusam entradas fora do domínio, mas ainda não aceitam conversão automática de unidades.
