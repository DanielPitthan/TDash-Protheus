# 06 — Mapa das regras de negócio e pontos de customização

Este documento responde a uma pergunta só: **"o cliente quer que o número X seja calculado de outro jeito. Onde
eu mexo, como, e o que mais muda junto?"**

Para cada módulo, a tabela traz:

- **Regra:** o que o indicador considera hoje.
- **Onde:** fonte e método (ou função) em que a regra está escrita.
- **Como mudar:** o tipo de alteração mais comum.
- **Afeta também:** outros indicadores que usam o mesmo trecho. Mudar um trecho compartilhado muda todos eles.

O porquê de cada regra (a decisão tomada com o cliente) está em
[`10-catalogo-de-indicadores.md`](10-catalogo-de-indicadores.md). O passo a passo de cada tipo de
alteração está na [05 — Customização](05-customizacao.md).

## Como ler e mudar uma regra com segurança

1. **Ache o trecho** na tabela do módulo. Abra o fonte no TDS-VSCode (CP1252).
2. **Veja quem mais usa o trecho.** Métodos que terminam em `From`, `Where` ou `Join` montam o `FROM`/`WHERE`
   de vários indicadores. Na dúvida, procure o nome do método no fonte.
3. **Decida entre mudar e criar.** Se a regra nova vale para todos os indicadores que usam o trecho, mude o trecho.
   Se vale só para um, crie um método novo e troque a chamada só nesse indicador.
4. **Mantenha os binds.** Cada `?` do SQL recebe um `set...` na mesma ordem do texto. Acrescentou um `?` no meio?
   Ajuste a posição dos binds seguintes (veja os métodos `bind...` do repositório).
5. **Valor que muda por cliente** vira parâmetro `MV_TD...` com padrão no código ([05, receita 6](05-customizacao.md#6-criar-um-parâmetro-do-protheus-mv_td)).
6. **Teste:** compile o módulo, rode o smoke test com `-Module` e compare com o relatório padrão do Protheus.
7. **Registre:** atualize o [catálogo de indicadores](10-catalogo-de-indicadores.md) e o [histórico](08-historico.md).

Regras que não acessam o banco (conversões, faixas, totalizações) ficam em `User Function`s de fontes de regra
(`tdash.<mód>.<regra>.tlpp`) e têm teste PROBAT. Ao mudar uma delas, mude também o teste.

---

## Financeiro — `FIN`

Fontes: `src/fin/tdash.fin.api.tlpp`, `tdash.fin.repository.tlpp`, `tdash.fin.party.api.tlpp`,
`tdash.fin.party.repository.tlpp`, `tdash.fin.party.rules.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| Títulos que não são dívida ficam fora: abatimentos (`MVABATIM`), provisórios (`MVPROVIS`), adiantamentos (`MVRECANT`/`MVPAGANT`) e créditos (`MV_CRNEG`/`MV_CPNEG`) | `TDashFinRepository:excludedTypes` | Para excluir outro tipo, acrescente ao array (ou crie um `MV_TD...` lido aqui). Os tipos entram por `setIn`, nunca concatenados | Todos os saldos de títulos: painel do Financeiro **e** posição do cliente/fornecedor |
| Saldo mínimo de 0,01 (resíduo de centavos não conta) | `titleBalance`, `aging`, `topParties`, `overdueTitles`, `TDashFinPartyRepository:titleFrom` | Troque `>= 0.01` em todos os métodos juntos, para os números baterem entre si | Todos os saldos |
| Vencido = `VENCREA` antes de hoje | `titleBalance` (escopo `overdue`), `aging`, `overdueTitles` | Para usar o vencimento original, troque `VENCREA` por `VENCTO` em todos os métodos | Cartões, aging, lista de vencidos, posição |
| "A vencer" e inadimplência em 30 dias | Constantes `DEFAULT_DUE_DAYS` e `DEFAULT_LATE_DAYS` em `tdash.fin.api.tlpp` | Mude a constante, ou troque por um `MV_TD...` lido na API | Cartões "em 30 dias", inadimplência, maiores pagamentos |
| Faixas de atraso 30/60/90/180 | `u_agingBuckets` e `u_agingBucket` (`tdash.fin.party.rules.tlpp`) e o define `AGING_LIMITS` em `tdash.fin.repository.tlpp` | Mude os limites **e os rótulos** nos dois lugares. O app pinta as faixas pela posição (5 cores) | Aging do painel e da posição |
| Saldo bancário: contas do fluxo de caixa (`A6_FLUXCAI <> 'N'`), moeda 1, não bloqueadas | `TDashFinRepository:bankBalances` | Para incluir outra moeda, é preciso converter (`xMoeda`). Não basta tirar o filtro | Cartão, saldo por conta, ponto de partida do fluxo projetado |
| Caixa realizado com os filtros do FINR620 | `cashWhere` e `motivesWithoutBank` | Siga o FINR620 do ambiente. Cada filtro está comentado no catálogo | Entradas e saídas, caixa por conta, **recebido/pago da posição** |
| Prazo médio (PMR/PMP) ponderado pelo valor | `averageTerm` | Para média simples, troque a soma ponderada por `AVG` | Cartões de prazo médio |
| Posição: em aberto/vencido dos títulos; histórico do cadastro (`A1_*`/`A2_*`) | `TDashFinPartyRepository:balance` e `stores` | Para calcular o histórico dos títulos em vez do cadastro, crie consultas novas na SE1/SE2 | Tela de posição |
| Posição: limite de crédito e `MV_CREDCLI` ("C" = limite da 1ª loja contra todas as lojas) | `TDashFinParty:kpiValue`, `static creditScope`, `u_consolidateStores` | Para descontar pedidos em carteira do disponível, some `A1_SALPEDL` (ou a carteira da SC6) em `kpiValue` | Cartão "Crédito disponível" |
| Posição: recebido/pago = movimento bancário do código, estorno (`ES`) abate | `TDashFinPartyRepository:settled` | Para contar também baixas sem banco (compensação, `BA`), não use `cashWhere`: crie um `WHERE` próprio | Cartão e gráfico da posição |
| Posição: junção das lojas (maior, mais antigo, soma, média ponderada) | `u_consolidateStores` | Mude a função e o teste `test_tdash_fin_party` | Histórico "Todas as lojas" |

## Faturamento — `FAT`

Fontes: `src/fat/tdash.fat.api.tlpp`, `tdash.fat.repository.tlpp`, `tdash.fat.result.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| Faturamento = notas normais (`D2_TIPO = 'N'`) com TES que gera duplicata (`F4_DUPLIC = 'S'`), pela emissão | `TDashFatRepository:salesFrom` | Para incluir complemento de preço: `D2_TIPO IN ('N','C')`. Para contar TES sem duplicata (bonificação), tire o filtro do `F4` ou troque por outro campo da TES | Faturamento, ticket médio, nº de notas, série e **todos** os rankings |
| Devoluções = notas de entrada tipo `D`, valor bruto | `returns` e `returnsByDay` | Para valor líquido, troque o campo somado | Cartão de devoluções, faturamento líquido, série |
| Meta de vendas (SCT) | `target` | Para outra granularidade de meta (vendedor, região), filtre a SCT pelo campo correspondente | Atingimento da meta |
| Carteira = itens não eliminados por resíduo (`C6_BLQ <> 'R'`), com saldo (`C6_QTDVEN - C6_QTDEMP - C6_QTDENT > 0`) | `backlogWhere` | Para considerar só pedidos liberados, junte a SC9 ou filtre o status do pedido | Cartão e lista da carteira |
| Resultado: venda = `D2_TOTAL` das vendas (mesma base do faturamento) − `D1_TOTAL` das devoluções; custo = `D2_CUSTO1` − `D1_CUSTO`; lucro bruto = venda − custo | `TDashFatRepository:resultRows` e `tdash.fat.u_resultSum` | Para usar o valor bruto (com IPI e ST), troque `D2_TOTAL`/`D1_TOTAL` na consulta | Cartões, gráfico e lista da aba Resultado |
| Resultado: impostos = ICMS (`VALICM`) + IPI + ICMS-ST (`ICMSRET`) + ISS + PIS (`VALIMP6`) e COFINS (`VALIMP5`), ou CBS e IBS no lugar de PIS/COFINS com `taxRegime=reform`; retenções (`VALPIS`, `VALCOF`, `VALCSL`, `VALIRRF`) não entram; lucro líquido = bruto − impostos | `tdash.fat.u_resultSum` | Para tirar um imposto do total, mude a soma de `taxes` e o teste `test_tdash_fat_result` | Lucro líquido, impostos, gráfico |
| CBS e IBS = soma de `F2D_VALOR` (não da CJ3, que repete linhas) ligada ao item por `D2_IDTRIB`/`D1_IDTRIB`; o tributo é reconhecido pelo `F2B_TRIB` da regra (`F2D_IDCAD = F2B_ID`): começa com `CBS` (CBSFED) ou `IBS` (IBSEST, IBSMUN) | `TDashFatRepository:reformTaxes` | Se o cliente usar outro código de tributo na regra, ajuste os `LIKE` | Impostos por tipo e o total no regime da reforma |
| Custo incompleto: mês com mais de 2% da venda sem custo (`D2_CUSTO1` zerado) recebe aviso. TES que não movimenta estoque (`F4_ESTOQUE = 'N'`: energia, serviço, sucata) não conta como sem custo, mas continua na venda e no lucro | `UNCOSTED_LIMIT` em `tdash.fat.result.tlpp` | Mude o percentual no `#define` | Avisos do gráfico do Resultado |
| Rankings por cliente, produto, vendedor e UF | `revenueBy` | Para uma quebra nova (ex.: por grupo de produto), acrescente um caso em `revenueBy` e um `dimension` | Barras da aba Rankings |

## Compras — `COM`

Fontes: `src/com/tdash.com.api.tlpp`, `tdash.com.repository.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| Compra = notas normais (`D1_TIPO = 'N'`) com TES que gera duplicata, pela digitação (`D1_DTDIGIT`) | `TDashComRepository:purchasesFrom` | Para usar a emissão, troque `D1_DTDIGIT` por `D1_EMISSAO` | Volume comprado, série, maiores fornecedores, evolução de preço |
| Pedido em aberto = saldo (`C7_QUANT > C7_QUJE`), sem resíduo e não encerrado | `ordersWhere` | Para ignorar pedidos de um tipo, acrescente o filtro aqui | Em aberto, atrasados, aguardando aprovação e as listas |
| Valor do pedido em reais = preço × `C7_TXMOEDA` quando `C7_MOEDA > 1` e a taxa está preenchida (pedido em moeda estrangeira); sem taxa, fica na moeda do pedido | `TDashComRepository:brlFactor` e `tdash.com.u_brlFactor` (mesma regra, testada) | Para outra fonte de cotação (ex.: SM2 pela data), troque o fator nos dois | Em aberto, atrasados, aguardando aprovação e as listas |
| Atrasado = `C7_DATPRF` antes de hoje; aguardando aprovação = `C7_CONAPRO = 'B'` | `ordersWhere` (escopos `late` e `approval`) | Para tolerância de N dias, troque a data do bind por `Date() - N` | Cartões e listas |
| Acompanhamento: o pedido de uma solicitação é o item de SC7 com `C7_NUMSC`, `C7_ITEMSC` e `C7_PRODUTO` iguais aos do item de SC1 (na filial de cada tabela); a nota é a SD1 normal (`D1_TIPO = 'N'`) com `D1_PEDIDO`, `D1_ITEMPC`, `D1_COD`, fornecedor e loja do item de pedido | `TDashComRepository:traceRows` | Para ligar por `C1_PEDIDO`/`C1_ITEMPED` em vez de `C7_NUMSC`, troque o `LEFT JOIN` da SC7 | Cartões, série e lista do Acompanhamento |
| Acompanhamento: quantidade pedida = soma de `C7_QUANT`; entregue = soma de `C7_QUJE` (unidade do pedido); valor solicitado = quantidade solicitada x preço médio do pedido, pois `C1_VUNIT` vem zerado; pedido pode passar de 100% da solicitação | `tdash.com.u_traceItems` | Para outra valorização do solicitado (ex.: último preço de compra), troque o cálculo de `requestedValue` | Cartões, série e lista do Acompanhamento |
| Solicitação pendente | `requestsWhere` | Ajuste os campos de status da SC1 | Cartão de solicitações |
| Prazos médios (SC → PC e PC → entrega), ponderados pela quantidade | `leadTimeRequest`, `leadTimeDelivery`, `averageDays` | A diferença de datas é feita em AdvPL com `tdash.core.u_daysBetween`. Nunca use data menos data | Cartões de prazo |

## Estoque e Custos — `EST`

Fontes: `src/est/tdash.est.api.tlpp`, `tdash.est.repository.tlpp`, `tdash.est.abc.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| Valor em estoque (`B2_VATU1`) por armazém, tipo ou grupo | `TDashEstRepository` (métodos de valor) | Para tirar um armazém (ex.: terceiros), acrescente o filtro e passe o código por bind ou parâmetro | Cartão, quebras, curva ABC, giro e cobertura |
| Saídas que movimentam estoque (`F4_ESTOQUE = 'S'`, `D2_TIPO = 'N'`) | `outputsFrom` | Para incluir requisições internas (SD3), crie outra consulta e some | CMV, giro, cobertura |
| Abaixo do ponto de pedido (`B1_EMIN`) | `belowReorderFrom` | Para usar o estoque disponível (`B2_QATU - B2_RESERVA`), troque o campo somado | Cartão e lista de reposição |
| Sem movimento há `MV_TDSEMMV` dias (padrão 180) | `idleFrom` e `paramDays` | Crie o parâmetro no SX6 para mudar o padrão | Cartão e lista |
| Lotes a vencer em `MV_TDVALID` dias (padrão 30) | `lotsFrom` e `paramDays` | Crie o parâmetro no SX6 | Cartão e lista de validade |
| Giro e cobertura (fórmulas) | `TDashEstApi:kpiValue` | Mude a fórmula aqui; o valor precisa continuar na unidade do catálogo | Cartões |
| Curva ABC 80/15/5% | `u_abcClassify` (`tdash.est.abc.tlpp`) | Mude os limites e o teste `test_tdash_est_abc` | Barras da curva ABC |

## Produção — `PCP`

Fontes: `src/pcp/tdash.pcp.api.tlpp`, `tdash.pcp.repository.tlpp`, `tdash.pcp.time.tlpp`, `tdash.pcp.material.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| Só OPs firmes (`C2_TPOP = 'F'`) | `openOrders`, `closedOrders`, `planTotals`, `lateFrom`, `closedJoin`, `closedOrderMaterials` | Para incluir as previstas, tire o filtro em **todos** esses métodos | Cartões de OP, lista de atrasadas, balanço de matéria-prima |
| Produção = SD3 com `D3_CF` iniciando com `PR`, sem estorno | `productionWhere` | Mantenha o mesmo filtro em `closedOrderMaterials` (produzido da OP) | Produção por dia, perdas apontadas, produtos mais produzidos |
| Perda apontada = `D3_PERDA` | `productionTotals`, `productionByDay` | Para usar a SH6 (`H6_QTDPERD`), crie consulta nova | Cartão e gráfico de perdas |
| Tempo da SH6: hora normal ou centesimal por `H6_TIPOTEM` (1 normal, 2 centesimal); sem ele, `MV_TPHR` (padrão "C") | `u_timeToHours`, `u_isCentesimal` (`tdash.pcp.time.tlpp`); leitura em `timeEntries` | Se o ambiente grava errado o `H6_TIPOTEM`, force o formato em `timeEntries`. Mude o teste `test_tdash_pcp_time` | Horas apontadas, horas por recurso, produção por hora |
| Hora improdutiva = `H6_TIPO = 'I'`; o resto é produtiva | `TDashPcpRepository:timeEntries` | Para separar por motivo (`H6_MOTIVO`), acrescente o campo no `GROUP BY` e crie uma quebra | Série de horas, produção por hora |
| Horas pela data do apontamento (`H6_DTAPONT`) | `timeEntries` | Para usar a data inicial do apontamento, troque por `H6_DATAINI` | Todas as horas |
| Produção por hora = `H6_QTDPROD` ÷ horas produtivas, por recurso, sem total geral | `static productivityRows` (`tdash.pcp.api.tlpp`) | Para um total geral, só faz sentido com produtos da mesma unidade. Filtre por unidade antes de somar | Ranking "Produção por hora" |
| Balanço de matéria-prima: só OPs **encerradas no período** (`C2_DATRF`) | `closedJoin` e a primeira consulta de `closedOrderMaterials` | Para olhar OPs abertas também, crie outra consulta; a "sobra" delas ainda não voltou ao estoque | Cartões, perda por produto e lista da aba Matéria-prima |
| Empenhado = Σ `D4_QTDEORI` | `closedOrderMaterials` (consulta "Empenhado") | Para usar o empenho atual em vez do original, troque por `D4_QUANT` + consumido | Empenhado e devolvido |
| Consumido = requisições (`RE*`) − devoluções (`DE*`) com `D3_OP`, sem estorno | `closedOrderMaterials` (consulta "Consumido") | Para excluir um tipo de requisição (ex.: `RE4`), acrescente `AND D3.D3_CF NOT IN (...)` | Consumido, perda, devolvido |
| Mão de obra fora (`B1_TIPO <> 'MO'`) | `closedOrderMaterials` (consultas de empenho e consumo) | Para considerar só matéria-prima, troque por `B1_TIPO = 'MP'` (ou uma lista em `MV_TD...` por `setIn`) **nas duas** consultas | Todo o balanço |
| Componente com unidade diferente da do produto (`B1_UM <> C2_UM`) fica fora e é avisado | `closedOrderMaterials` (`CASE WHEN B1.B1_UM = C2.C2_UM`) e `materialWarnings` na API | Para converter pela 2ª unidade (`B1_CONV`), troque o `CASE` por uma expressão de conversão e teste com uma OP real | Todo o balanço e os avisos |
| OP sem empenho nem consumo comparável fica fora | `u_materialCounts` (`tdash.pcp.material.tlpp`) | Mude a função e o teste `test_tdash_pcp_material` | Totais, ranking e lista |
| Perda de material = consumido − produzido; devolvido = empenhado − consumido; perda % sobre o consumido | `u_materialTotals`, `u_lossRate` | Para perda % sobre o empenhado, mude `u_lossRate` e o título do catálogo | Cartões e lista |
| Ligação OP × SD3/SD4 por `C2_NUM + C2_ITEM + C2_SEQUEN + C2_ITEMGRD` | `closedJoin` (usa `MatiConcat()`) | Não troque `MatiConcat()` por `+` ou `||` fixo: o operador muda com o banco | Balanço de matéria-prima |

## Livros Fiscais — `FIS`

Fontes: `src/fis/tdash.fis.api.tlpp`, `tdash.fis.repository.tlpp`, `tdash.fis.ledger.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| Débito = saídas (CFOP 5, 6, 7); crédito = entradas (1, 2, 3); sem canceladas | `TDashFisRepository:taxSql` | Para tirar um CFOP, acrescente `NOT IN` com bind | Saldos de ICMS, IPI, PIS/COFINS e as séries |
| ISS (notas de serviço) | `iss` | Ajuste o campo de tipo de nota/serviço do livro | Cartão de ISS |
| ICMS ST e DIFAL | `sumField` | Troque o campo somado se o cliente usa outro | Cartões |
| Centralização: campos de débito e crédito de cada tributo | `TDashFisRepository:ledgerMonths` | Mude o `CASE` do tributo (ex.: outro campo de DIFAL) | Tabela, cartões e série da visão geral |
| PIS/COFINS: crédito só com CST 50 a 66 | `ledgerMonths` (consulta da SFT) | Mude a faixa de CST | Centralização |
| ISS retido = `D1_VALISS` das notas com `FT_RECISS = '1'` | `ledgerMonths` (consulta da SD1) | Para usar o contas a pagar, troque por `E2_ISS` | Centralização |
| CBS e IBS fora do total | `u_ledgerTaxes` (3º elemento `.F.`) em `tdash.fis.ledger.tlpp` | Mude para `.T.` quando CBS/IBS passarem a ser recolhidos | Total, cartões e série |
| Carga tributária | `u_taxBurden` | Mude a soma ou a base e o teste `test_tdash_fis_ledger` | Cartão da visão geral |
| Canceladas pela data de cancelamento, uma por nota | `cancelledFrom` | Para contar pela emissão, troque `F3_DTCANC` | Cartão e lista |

## Contabilidade — `CTB`

Fontes: `src/ctb/tdash.ctb.api.tlpp`, `tdash.ctb.repository.tlpp`, `tdash.ctb.rollup.tlpp`, `tdash.ctb.months.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| DRE e Balanço seguem a **visão gerencial** escolhida no app (CVE/CTS) | `TDashCtbRepository:views`, `viewExists`, `balanceRows` | A estrutura das linhas é configurada no Protheus, não no código. Para mudar a DRE, ajuste a visão | Demonstrações |
| Período em meses inteiros (saldos mensais da CQ0/CQ2 no último dia do mês) | `u_monthPeriod` (`tdash.ctb.months.tlpp`) | Não use dias soltos: os saldos são mensais | DRE, Balanço e comparação |
| CQ0 sem centro de custo; CQ2 quando a linha tem faixa de centro de custo; DRE sem apuração (`LP` S e Z) | `balanceRows`, `accountBalances` | Para considerar o lançamento de apuração, tire o filtro de `LP` | DRE |
| Sinal pela natureza da linha | `statementValues` | Mude se a visão do cliente usa outra convenção de sinal | Valores exibidos |
| Totalização (subtotais; natureza oposta subtrai) | `u_rollup` (`tdash.ctb.rollup.tlpp`) | Mude a função e o teste `test_tdash_ctb_rollup` | Subtotais e total |
| Sem visão escolhida ou visão desconhecida: `422` | `TDashCtbApi:configError` | Mantenha o `422`: é ele que faz o app pedir a configuração | Tela da Contabilidade |

## Recursos Humanos — `GPE`

Fontes: `src/gpe/tdash.gpe.api.tlpp`, `tdash.gpe.repository.tlpp`, `tdash.gpe.rules.tlpp`.

| Regra | Onde | Como mudar | Afeta também |
|---|---|---|---|
| **LGPD:** grupos com menos de `MV_TDMINGR` pessoas (padrão 5) vão para "Outros"; cartões de grupo pequeno saem com `hidden` | `u_lgpdGroups`, `minGroup` | Não reduza o mínimo sem aval do jurídico/DPO do cliente | Todo o RH |
| Ativo = admitido até a data, sem demissão até a data, categoria fora de `MV_TDCATEX` (padrão `A,P`) | `activeWhere`, `bindActive` | Crie `MV_TDCATEX` no SX6 para mudar as categorias | Quadro, turnover, absenteísmo, perfil |
| Admissões e desligamentos sem transferência (RAIS 30 e 31) | `movementFrom` | Acrescente códigos à lista de exclusão | Movimentação e turnover |
| Ausências que contam: `RCM_TIPOAF` 1 e 2 | `absences` | Mude a lista de tipos | Absenteísmo e afastamentos |
| Dias de ausência no período (dias corridos) | `u_absenceDays` | Para dias úteis, a função precisa do calendário; mude também o teste | Absenteísmo |
| Folha = proventos da SRD de meses fechados, sem os roteiros de `MV_TDROTEX` (padrão `ADI,131,AUT`) | `payrollFrom`, `u_payrollMonths`, `lastClosedMonth` | Crie `MV_TDROTEX` no SX6 para mudar os roteiros | Folha, folha por centro de custo, horas extras |
| Horas extras = verbas escolhidas no app; horas só de `RD_TIPO1 = 'H'` | `overtimeFrom`, `overtime` | As verbas são do usuário (Configurações). Sem elas, `422` | Cartões de horas extras |
| Faixas de idade e tempo de casa | `u_ageBand`, `u_tenureBand` | Mude as faixas e os testes | Perfil do quadro |
| Turnover e absenteísmo (fórmulas) | `turnover`, `absenteeism` em `tdash.gpe.api.tlpp` | Mude a fórmula; mantenha `PCT` de 0 a 100 | Cartões |

---

## Parâmetros que mudam regras sem mexer no código

| Parâmetro | Padrão | Onde é lido | Efeito |
|---|---|---|---|
| `MV_TDSEMMV` | 180 | Estoque | Dias sem movimento |
| `MV_TDVALID` | 30 | Estoque | Janela de lotes a vencer |
| `MV_TDMINGR` | 5 | RH | Tamanho mínimo de grupo (LGPD) |
| `MV_TDCATEX` | `A,P` | RH | Categorias fora do quadro |
| `MV_TDROTEX` | `ADI,131,AUT` | RH | Roteiros fora da folha |
| `MV_TPHR` (padrão do Protheus) | `C` | Produção | Formato do tempo da SH6 quando o apontamento não tem `H6_TIPOTEM` |
| `MV_CREDCLI` (padrão do Protheus) | `L` | Financeiro (posição) | Limite de crédito por loja (`L`) ou por cliente (`C`) |
| Variáveis do Financeiro (`MVABATIM`, `MVPROVIS`, `MVRECANT`, `MVPAGANT`, `MV_CRNEG`, `MV_CPNEG`) | do ambiente | Financeiro | Tipos de título que não são dívida |

Escolhas feitas pelo usuário no app (por servidor e empresa): visão gerencial da DRE e do Balanço, verbas de hora
extra e indicadores fixados no Início.
