# TDash — Catálogo de indicadores (v1)

Todos os campos citados foram conferidos no dicionário local (`docs/dicionarios/SX3010.sdb`) em
2026-10-20. Os 299 existem e são reais (não virtuais). `CTS_IDENTI` é virtual e não deve ser usado em SQL.

## Convenções

- **Tipo**: `kpi` = cartão (valor + comparativo), `series` = série temporal, `breakdown` = composição
  ou ranking, `list` = drill-down paginado.
- **TTL**: `op` = 5 min (operacional), `tat` = 30 min (tático), `est` = 12 h (estratégico).
- **Sentido**: `+` = subir é bom, `-` = subir é ruim, `=` = neutro. Define a cor da variação no app.
- Toda consulta filtra `D_E_L_E_T_ = ' '` e `<TAB>_FILIAL = xFilial('<TAB>')` da filial do `tenantid`.
  Com `branches=` consolidado, a filial vira `IN (...)`, só com filiais que o usuário pode acessar.
- Período: `dateFrom`/`dateTo` (`AAAAMMDD`). `compare=prev` = período anterior de mesma duração;
  `compare=yoy` = mesmo período do ano anterior.
- Valores monetários na moeda 1. Datas de corte = data do servidor (`Date()`).
- Parâmetros que variam por cliente (verbas, visões gerenciais) são informados pelo usuário no app. Ver o fim deste documento.

---

## Financeiro — `FIN`

Tabelas: SE1, SE2, SE5, SE8, SA6, SA1, SA2.

Títulos que não são dívida real ficam fora dos saldos: abatimentos (`MVABATIM`), provisórios
(`MVPROVIS`, ex.: PR), adiantamentos (`MVRECANT` / `MVPAGANT`, ex.: RA e PA) e créditos negativos
(`MV_CRNEG` / `MV_CPNEG`, ex.: NCC e NDF). Os tipos vêm das variáveis do Financeiro do ambiente; sem
elas, a API usa os padrões do framework (`AB-|FB-|FC-|FU-`, `PR`, `RA`/`PA`, `NCC`/`NDF`).

Saldo em aberto considera só `SALDO >= 0,01` (resíduos de centavos ficam fora). Vencido, aging, maiores
devedores e listas exigem vencimento real preenchido (`VENCREA <> ' '`).

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `fin.bank_balance` | kpi + breakdown por banco | Último `E8_SALATUA` de cada conta (maior `E8_DTSALAT` ≤ data), só contas não bloqueadas (`A6_BLOCKED <> '1'`), que participam do fluxo de caixa (`A6_FLUXCAI <> 'N'`) e em moeda 1 (`A6_MOEDA <= 1`). Composição: contas com saldo ≠ 0, as 10 maiores e o resto em "Outras contas" | E8_BANCO, E8_AGENCIA, E8_CONTA, E8_DTSALAT, E8_SALATUA, A6_NOME, A6_NREDUZ, A6_BLOCKED, A6_FLUXCAI, A6_MOEDA | op | + |
| `fin.receivable_open` | kpi | Σ `E1_SALDO` com `E1_SALDO > 0` | E1_SALDO, E1_TIPO | op | = |
| `fin.receivable_overdue` | kpi | Igual ao anterior, com `E1_VENCREA < hoje` | E1_VENCREA | op | - |
| `fin.receivable_due` | kpi | Igual, com `E1_VENCREA` entre hoje e hoje+N (padrão 30) | E1_VENCREA | op | = |
| `fin.payable_open` | kpi | Σ `E2_SALDO` com `E2_SALDO > 0` | E2_SALDO, E2_TIPO | op | = |
| `fin.payable_overdue` | kpi | `E2_VENCREA < hoje` | E2_VENCREA | op | - |
| `fin.payable_due` | kpi | `E2_VENCREA` entre hoje e hoje+N | E2_VENCREA | op | = |
| `fin.aging_receivable` | breakdown | Faixas de atraso 0-30 / 31-60 / 61-90 / 91-180 / >180 sobre `E1_VENCREA` | E1_VENCREA, E1_SALDO | tat | - |
| `fin.aging_payable` | breakdown | Mesmas faixas sobre `E2_VENCREA` | E2_VENCREA, E2_SALDO | tat | - |
| `fin.cashflow_projection` | series | Por dia/semana: Σ `E1_SALDO` (entrada) e Σ `E2_SALDO` (saída) por vencimento futuro + saldo acumulado a partir de `fin.bank_balance` | E1_VENCREA, E2_VENCREA | tat | + |
| `fin.default_rate` | kpi | Σ saldo vencido há mais de N dias (padrão `MV_TDINADD` = 30) ÷ Σ saldo em aberto | E1_VENCREA, E1_SALDO | tat | - |
| `fin.dso` (PMR) | kpi | Média ponderada (`E1_BAIXA − E1_EMISSAO`) × `E1_VALOR` dos títulos baixados no período | E1_EMISSAO, E1_BAIXA, E1_VALOR | est | - |
| `fin.dpo` (PMP) | kpi | Mesma fórmula em SE2 | E2_EMISSAO, E2_BAIXA, E2_VALOR | est | + |
| `fin.cash_realized` | series | Σ `E5_VALOR` por `E5_DTDISPO`, entradas (`E5_RECPAG = 'R'`) e saídas (`'P'`), com os mesmos filtros do relatório padrão de movimentação bancária FINR620 (ver abaixo) | E5_DTDISPO, E5_DATA, E5_VENCTO, E5_VALOR, E5_RECPAG, E5_SITUACA, E5_TIPODOC, E5_MOEDA, E5_NUMCHEQ, E5_DOCUMEN, E5_NUMERO, E5_ORIGEM, E5_MOTBX, E5_BANCO | tat | + |
| `fin.cash_by_bank` | breakdown | Mesmo filtro de `fin.cash_realized`, entradas e saídas por banco/agência/conta | E5_BANCO, E5_AGENCIA, E5_CONTA, A6_NOME | tat | = |
| `fin.top_debtors` | breakdown | Top N clientes por saldo vencido | E1_CLIENTE, E1_LOJA, A1_NOME, E1_SALDO | tat | - |
| `fin.top_creditors` | breakdown | Top N fornecedores por saldo a pagar nos próximos 30 dias | E2_FORNECE, E2_LOJA, A2_NOME, E2_SALDO | tat | = |
| `fin.overdue_receivables` | list | Títulos vencidos, ordenados por atraso | E1_PREFIXO, E1_NUM, E1_PARCELA, E1_TIPO, E1_NOMCLI, E1_VENCREA, E1_SALDO | op | — |
| `fin.overdue_payables` | list | Idem a pagar | E2_PREFIXO, E2_NUM, E2_PARCELA, E2_TIPO, E2_NOMFOR, E2_VENCREA, E2_SALDO | op | — |

Abas no app: **Receber | Pagar | Caixa**.

### Regra do caixa realizado (igual ao FINR620)

Conferida no fonte do FINR620 (`docs/knowledge_base/codigo_advpl/f/finr620-a0e6c2.md`, linhas
604–616 e 797–892). Um movimento do SE5 entra no caixa realizado quando:

1. `E5_BANCO <> ' '` (tem banco).
2. `E5_SITUACA <> 'C'` (não cancelado).
3. `E5_DTDISPO` dentro do período (data de disponibilidade, não a data da baixa).
4. `E5_VENCTO <= E5_DATA` ou `E5_ORIGEM = 'FINA087A'` (não é movimento pré-datado).
5. `E5_TIPODOC NOT IN ('DC','JR','MT','BA','CM','D2','J2','M2','C2','V2','CX','CP','TL')`. São
   desconto, juros, multa, baixa, correção e as variações. Esses valores já estão dentro do movimento
   principal.
6. `E5_NUMCHEQ` não começa com `*` (cheque cancelado).
7. `E5_MOEDA` em `C1..C5` ou `CH` só conta se tiver `E5_NUMCHEQ` (exceto transferências `TR`/`TE`).
8. Transferência (`E5_TIPODOC` `TR`/`TE`) sem número de título só conta se `E5_MOEDA` for `R$`, `DO`,
   `TB`, `TC` ou `CH`. Também não conta se `E5_NUMCHEQ` ou `E5_DOCUMEN` começar com `*`.
9. `E5_TIPODOC = 'SG'` só conta se `E5_MOEDA = 'R$'`.
10. Se `E5_MOTBX` estiver preenchido, o motivo de baixa precisa movimentar banco (`MovBcoBx`). A API
    monta, no início da requisição, a lista de motivos que **não** movimentam banco (`ReadMotBx()` +
    `MovBcoBx()`) e passa essa lista como `NOT IN` com bind.

As regras 1 a 6 e 9 ficam no `WHERE`. As regras 7, 8 e 10 também vão para o SQL, como `CASE` ou
`NOT IN`, para a soma ser feita no banco. Não fica nada para filtrar linha a linha no AppServer.
Valor na moeda 1 (`E5_VALOR`). Ficam fora da v1: a conversão de moeda (`xMoeda`) e a regra de cheque
em banco "caixa loja" (`IsCaixaLoja`), que dependem de configuração do SIGALOJA.

### Posição do cliente e do fornecedor (como FINC010 e FINC030)

Pedido do usuário em 2026-10-22. Regras confirmadas no mesmo dia:

- **Lojas:** sem `store`, junta todas as lojas do código; o app mostra "Todas as lojas" e deixa abrir os detalhes e a
  posição de cada loja.
- **Em aberto, vencido e a vencer:** calculados dos títulos (SE1/SE2), sempre atualizados, com as mesmas exclusões de
  tipo dos indicadores do Financeiro. O **histórico** (maior compra, maior saldo, primeira e última compra, número de
  compras, maior atraso e média de atraso) vem dos campos que o Protheus mantém no cadastro (`A1_*`, `A2_*`).
- **Limite de crédito** (só clientes, `A1_LC`): com `MV_CREDCLI = "C"` (crédito por cliente) vale o limite da primeira
  loja contra o saldo de todas as lojas; senão, o limite da loja escolhida (ou a soma das lojas). **Crédito disponível**
  = limite − saldo em aberto dos títulos (não desconta pedidos em carteira).
- **Recebido ou pago no período:** movimento bancário do cliente ou fornecedor (`E5_CLIFOR`/`E5_LOJA`) com os mesmos
  filtros do caixa realizado (FINR620). Do cliente entram os recebimentos (`E5_RECPAG = 'R'`); do fornecedor, os
  pagamentos (`'P'`). Estornos (`E5_TIPODOC = 'ES'`) abatem.

Parâmetros: `type=customer|supplier`, `code=<A1_COD ou A2_COD>` e `store=<loja>` (opcional). A busca usa
`list/fin.party_search?type=...&search=<3 a 40 caracteres>` e procura no nome, nome fantasia, código e CNPJ/CPF
(até 20 códigos, todas as lojas juntas).

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `fin.party_search` | list | Clientes ou fornecedores pelo texto, um por código, em ordem de nome | A1/A2_COD, NOME, NREDUZ, CGC, MUN, EST | tat | = |
| `fin.party_open` | kpi | Σ saldo dos títulos em aberto do código (e loja) | E1/E2_SALDO, TIPO, CLIENTE/FORNECE, LOJA | op | = |
| `fin.party_overdue` | kpi | Saldo com `VENCREA` antes de hoje | E1/E2_VENCREA | op | - |
| `fin.party_not_due` | kpi | Em aberto − vencido | — | op | = |
| `fin.party_credit_limit` | kpi | Limite de crédito (regra acima). Só clientes | A1_LC, MV_CREDCLI | tat | = |
| `fin.party_credit_available` | kpi | Limite − em aberto. Só clientes | A1_LC, E1_SALDO | op | + |
| `fin.party_settled` | kpi + series | Recebido (cliente) ou pago (fornecedor) no período; série `settled` (aceita comparação) | E5_CLIFOR, E5_LOJA, E5_RECPAG, E5_TIPODOC, E5_VALOR, E5_DTDISPO | tat | = |
| `fin.party_aging` | breakdown | Saldo vencido nas faixas do aging | E1/E2_VENCREA, SALDO | op | - |
| `fin.party_titles` | list | Títulos em aberto, do vencimento mais antigo para o mais novo (loja, emissão, vencimento, valor, saldo, atraso) | E1/E2_PREFIXO, NUM, PARCELA, TIPO, LOJA, EMISSAO, VENCREA, VALOR, SALDO | op | = |
| `fin.party_stores` | list | Cadastro e histórico de cada loja; com mais de uma loja, a linha "Todas as lojas" vem primeiro | A1/A2_MCOMPRA, MSALDO, PRICOM, ULTCOM, NROCOM, MATR; A1_LC, A1_VENCLC, A1_METR, A1_NROPAG | tat | = |

Na junção das lojas: maior compra, maior saldo, última compra e maior atraso pegam o maior valor; primeira compra, a
mais antiga; compras e pagamentos somam; a média de atraso é ponderada pelo número de pagamentos (`A1_NROPAG`).

Abertura no app: botões **Posição de um cliente** (aba Receber) e **Posição de um fornecedor** (aba Pagar), ou um
toque nas barras de maiores devedores e maiores pagamentos.

---

## Compras — `COM`

Tabelas: SC1, SC7, SD1, SF1, SF4, SA2, SB1. Implementado na Onda 3 (`TDashComApi` / `TDashComRepository`).

Compras = notas de entrada normais (`D1_TIPO = 'N'`) com TES que gera duplicata (`F4_DUPLIC = 'S'`), pelo
valor das mercadorias (`D1_TOTAL`). Pedido em aberto = saldo `C7_QUANT − C7_QUJE` > 0, sem resíduo eliminado
(`C7_RESIDUO <> 'S'`) e não encerrado (`C7_ENCER <> 'E'`).

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `com.purchases` | kpi + series | Σ `D1_TOTAL` por `D1_DTDIGIT` (aceita comparação) | D1_TOTAL, D1_TIPO, D1_TES, D1_DTDIGIT, F4_DUPLIC | tat | = |
| `com.po_open` | kpi + list | Σ (`C7_QUANT − C7_QUJE`) × `C7_PRECO` × fator de moeda dos pedidos em aberto. Fator de moeda = `C7_TXMOEDA` quando `C7_MOEDA > 1` e a taxa está preenchida; senão 1 (corrigido em 25/10/2026: pedido em dólar entrava sem converter) | C7_QUANT, C7_QUJE, C7_PRECO, C7_MOEDA, C7_TXMOEDA, C7_RESIDUO, C7_ENCER | op | = |
| `com.po_late` | kpi + list | Igual, com `C7_DATPRF` preenchida e anterior a hoje | C7_DATPRF | op | - |
| `com.po_awaiting_approval` | kpi + list | Igual, com `C7_CONAPRO = 'B'` (bloqueado aguardando aprovação) | C7_CONAPRO | op | - |
| `com.pr_pending` | kpi + list | Quantidade de itens de solicitação com saldo (`C1_QUANT > C1_QUJE`), sem resíduo (`C1_RESIDUO <> 'S'`) e sem pedido (`C1_PEDIDO = ' '`) | C1_QUANT, C1_QUJE, C1_RESIDUO, C1_PEDIDO, C1_EMISSAO, C1_SOLICIT | op | - |
| `com.trace_requested` | kpi | Σ quantidade solicitada (`C1_QUANT`) × preço médio do pedido, dos itens de solicitação emitidos no período (`C1_EMISSAO`, sem resíduo eliminado) que já viraram pedido. A solicitação não tem preço (`C1_VUNIT` zerado na base do cliente), por isso vale o preço do pedido. Aceita comparação | C1_QUANT, C1_EMISSAO, C1_RESIDUO, C7_NUMSC, C7_ITEMSC, C7_PRODUTO, C7_QUANT, C7_PRECO | tat | = |
| `com.trace_ordered` | kpi | Σ `C7_QUANT` × `C7_PRECO` × fator de moeda dos itens de pedido ligados a essas solicitações | C7_QUANT, C7_PRECO, C7_MOEDA, C7_TXMOEDA | tat | = |
| `com.trace_delivered` | kpi | Σ `D1_TOTAL` das notas de entrada normais (`D1_TIPO = 'N'`) ligadas a esses itens de pedido (`D1_PEDIDO`, `D1_ITEMPC`, `D1_COD`, `D1_FORNECE`, `D1_LOJA`) | D1_TOTAL, D1_TIPO, D1_PEDIDO, D1_ITEMPC, D1_COD, D1_FORNECE, D1_LOJA | tat | = |
| `com.trace_unordered` | kpi | Quantidade de itens dessas solicitações sem nenhum item de pedido | C7_NUMSC, C7_ITEMSC | tat | - |
| `com.trace` | series | Os três valores acima por mês de emissão da solicitação | | tat | = |
| `com.trace_items` | list | Por item de solicitação: quantidade solicitada, pedida (`C7_QUANT`) e entregue (`C7_QUJE`), % que virou pedido e % entregue do pedido; "N pedidos" quando o item se divide | C1_*, C7_QUANT, C7_QUJE | tat | = |
| `com.lead_time_request` | kpi | Média de dias `C7_EMISSAO − C1_EMISSAO` dos pedidos emitidos no período e originados de solicitação (`C7_NUMSC`/`C7_ITEMSC`) | C1_EMISSAO, C7_EMISSAO, C7_NUMSC, C7_ITEMSC | est | - |
| `com.lead_time_delivery` | kpi | Média de dias `D1_DTDIGIT − C7_EMISSAO` das notas do período amarradas a pedido (`D1_PEDIDO`/`D1_ITEMPC`) | D1_PEDIDO, D1_ITEMPC, D1_DTDIGIT, C7_EMISSAO | est | - |
| `com.top_suppliers` | breakdown | Valor comprado por fornecedor, top N + "Outros fornecedores" | D1_FORNECE, D1_LOJA, A2_NOME, D1_TOTAL | tat | = |
| `com.price_evolution` | series | Preço médio mensal (Σ `D1_TOTAL` ÷ Σ `D1_QUANT`) dos 5 produtos de maior valor comprado no período; uma série por produto | D1_COD, D1_QUANT, D1_TOTAL, B1_DESC | est | - |

Abas no app: **Compras | Pedidos | Solicitações**.

---

## Faturamento — `FAT`

Tabelas: SF2, SD2, SF4, SC6, SA1, SA3, SB1, SCT, SD1 (devoluções). Implementado na Onda 3
(`TDashFatApi` / `TDashFatRepository`).

Faturamento = itens de saída normais (`D2_TIPO = 'N'`) com TES que gera duplicata (`F4_DUPLIC = 'S'`), pelo
valor bruto (`D2_VALBRUT`). Devoluções = notas de entrada tipo D pelo valor bruto
(`D1_TOTAL + D1_VALIPI + D1_ICMSRET`), para comparar na mesma base.

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `fat.revenue` | kpi + series | Σ `D2_VALBRUT` por `D2_EMISSAO`; a série traz também as devoluções (aceita comparação) | D2_VALBRUT, D2_TIPO, D2_TES, D2_EMISSAO, F4_DUPLIC | op | + |
| `fat.revenue_net` | kpi | `fat.revenue` − `fat.returns` | — | tat | + |
| `fat.invoice_count` | kpi | Quantidade de pares distintos `D2_DOC` + `D2_SERIE` | D2_DOC, D2_SERIE | op | + |
| `fat.avg_ticket` | kpi | `fat.revenue` ÷ `fat.invoice_count` | — | tat | + |
| `fat.returns` | kpi | Σ (`D1_TOTAL + D1_VALIPI + D1_ICMSRET`) de `D1_TIPO = 'D'` por `D1_DTDIGIT` | D1_TIPO, D1_TOTAL, D1_VALIPI, D1_ICMSRET, D1_DTDIGIT | tat | - |
| `fat.target_attainment` | kpi | Faturamento ÷ meta (Σ `CT_VALOR` com `CT_DATA` no período) × 100; sem meta, o título avisa "sem meta no período" | CT_DATA, CT_VALOR | tat | + |
| `fat.backlog` | kpi + list | Carteira: Σ (`C6_QTDVEN − C6_QTDEMP − C6_QTDENT`) × `C6_PRCVEN` dos itens em aberto (regra abaixo); lista pela data de entrega | C6_QTDVEN, C6_QTDENT, C6_QTDEMP, C6_PRCVEN, C6_BLQ, C6_ENTREG, C6_CLI, C6_LOJA | op | + |
| `fat.top_customers` | breakdown | Faturamento por cliente, top N + "Outros" | D2_CLIENTE, D2_LOJA, A1_NOME | tat | = |
| `fat.top_products` | breakdown | Faturamento por produto, top N + "Outros" | D2_COD, B1_DESC | tat | = |
| `fat.by_seller` | breakdown | Faturamento por `F2_VEND1` (vendedor 1 da nota) | F2_VEND1, A3_NOME | tat | = |
| `fat.by_state` | breakdown | Faturamento por UF (`F2_EST`) | F2_EST | est | = |
| `fat.gross_profit` | kpi | Lucro bruto: (Σ `D2_TOTAL` − Σ `D1_TOTAL` das devoluções) − (Σ `D2_CUSTO1` − Σ `D1_CUSTO`). Vendas com a mesma base do faturamento, por `D2_EMISSAO`; devoluções tipo D por `D1_DTDIGIT` (aceita comparação) | D2_TOTAL, D2_CUSTO1, D1_TOTAL, D1_CUSTO | tat | + |
| `fat.taxes` | kpi | Impostos das vendas menos os das devoluções: ICMS + IPI + ICMS-ST + ISS + PIS e COFINS (`VALIMP6`, `VALIMP5`); com `taxRegime=reform`, CBS e IBS no lugar de PIS e COFINS (em 2026 eles são compensados no PIS/COFINS, por isso só um par entra). Retenções não entram | D2/D1_VALICM, VALIPI, ICMSRET, VALISS, VALIMP5, VALIMP6, F2D_VALOR, F2B_TRIB | tat | - |
| `fat.net_profit` | kpi | `fat.gross_profit` − `fat.taxes` | — | tat | + |
| `fat.result` | series | Os três acima por mês (séries `gross`, `net`, `taxes`); aviso nos meses com mais de 2% da venda sem custo (`D2_CUSTO1` zerado em TES que movimenta estoque; TES com `F4_ESTOQUE = 'N'` fica fora do aviso, mas dentro da venda e do lucro) | — | tat | = |
| `fat.taxes_by_type` | breakdown | Cada imposto do período (ICMS, IPI, ICMS-ST, ISS, PIS, COFINS, CBS, IBS); o par fora do total vem marcado "(fora do total)". CBS e IBS: Σ `F2D_VALOR` ligada por `D2_IDTRIB`/`D1_IDTRIB`, tributo pelo `F2B_TRIB` (CBS…, IBS…) | F2D_IDREL, F2D_IDCAD, F2D_VALOR, F2D_DTEXCL, F2B_ID, F2B_TRIB | tat | = |

**Regra de carteira (confirmada em 2026-10-20):** um item de pedido está encerrado, e fica fora da
carteira, quando acontece qualquer um destes casos:
- `C6_BLQ = 'R'` (resíduo eliminado);
- `C6_QTDENT >= C6_QTDVEN` (faturado igual ou maior que o vendido);
- `C6_QTDVEN − C6_QTDEMP − C6_QTDENT = 0` (sem saldo).

Abas no app: **Vendas | Carteira | Rankings**.

---

## Produção — `PCP`

Tabelas: SC2, SD3, SD4, SH6, SH1, SB1.

Fonte principal (confirmada): **SD3**. A SH6 é usada para as horas apontadas e a produtividade por recurso,
quando houver apontamento nela. A SD4 (empenhos) entra no balanço de matéria-prima.

Tempo da SH6 (`H6_TEMPO`, texto "HH:MM"): `H6_TIPOTEM = 1` é hora normal (minutos) e `2` é centesimal
(centésimos de hora, "01:50" = 1,5 h), o mesmo critério do padrão do PCP; sem o campo vale o `MV_TPHR`
(padrão "C"). Antes de 2026-10-22 a API lia sempre minutos.

OP **firme** é `C2_TPOP = 'F'`. Só as firmes entram nos indicadores de OP; as previstas ficam de fora
(decisão de 2026-10-21).

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `pcp.po_open` | kpi | OPs firmes sem data de encerramento real (`C2_DATRF = ' '`). Posição de hoje | C2_TPOP, C2_DATRF | op | = |
| `pcp.po_late` | kpi + list | OPs firmes abertas com `C2_DATPRF < hoje`. Posição de hoje. A lista vai da entrega mais antiga para a mais recente (OP, produto, entrega prevista, planejada e produzida) | C2_NUM, C2_ITEM, C2_SEQUEN, C2_PRODUTO, C2_QUANT, C2_QUJE, C2_DATPRF, B1_DESC | op | - |
| `pcp.po_closed` | kpi | OPs firmes com `C2_DATRF` no período (aceita comparação) | C2_TPOP, C2_DATRF | tat | + |
| `pcp.plan_attainment` | kpi (gauge) | Σ `C2_QUJE` ÷ Σ `C2_QUANT` das OPs firmes com entrega (`C2_DATPRF`) no período. Sem OPs no período o título avisa e o percentual fica zerado (aceita comparação) | C2_TPOP, C2_QUANT, C2_QUJE, C2_DATPRF | tat | + |
| `pcp.production_daily` | series | Σ `D3_QUANT` de apontamentos de produção (`D3_CF` iniciando com `PR`), não estornados (`D3_ESTORNO <> 'S'`). Série `production`, unidade QTY | D3_CF, D3_QUANT, D3_EMISSAO, D3_ESTORNO | op | + |
| `pcp.losses` | kpi + series | Σ `D3_PERDA` ÷ (Σ `D3_QUANT` + Σ `D3_PERDA`) dos apontamentos de produção da SD3 (mesmo filtro de `pcp.production_daily`). A série `losses` traz o percentual de cada dia, semana ou mês (aceita comparação) | D3_PERDA, D3_QUANT, D3_CF, D3_ESTORNO, D3_EMISSAO | tat | - |
| `pcp.hours_by_resource` | breakdown | Σ `H6_TEMPO` (convertido em horas, normal ou centesimal) por recurso, produtivas e improdutivas, unidade HOURS. **Opcional:** vem vazio se não houver apontamento na SH6. A fonte principal da produção é a SD3 | H6_RECURSO, H1_DESCRI, H6_TEMPO, H6_TIPOTEM, H6_DTAPONT | est | = |
| `pcp.hours` | kpi + series | Σ horas apontadas na SH6 pela data do apontamento (`H6_DTAPONT`). A série traz `productive` (`H6_TIPO` diferente de "I") e `unproductive` (`H6_TIPO = 'I'`); o cartão soma as duas (aceita comparação) | H6_TEMPO, H6_TIPOTEM, H6_TIPO, H6_DTAPONT | tat | = |
| `pcp.productivity` | breakdown | Σ `H6_QTDPROD` ÷ horas produtivas de cada recurso, unidade PER_HOUR. Sem total geral nem "Outros": somar taxas de produtos diferentes não tem sentido. Recurso sem hora produtiva fica fora | H6_RECURSO, H6_QTDPROD, H6_TEMPO, H6_TIPO | tat | + |
| `pcp.top_products` | breakdown | Top N produtos produzidos (Σ `D3_QUANT` dos apontamentos de produção), unidade QTY | D3_COD, B1_DESC, D3_QUANT | tat | = |

### Balanço de matéria-prima (OPs encerradas)

Pergunta do usuário (2026-10-22): do que foi produzido, quanto de matéria-prima foi absorvido, quanto foi perda e
quanto do empenho voltou ao estoque. Exemplo: produz 10 t, consome 11 t e tinha empenhado 12 t: perda de 1 t e
1 t devolvida.

- **OPs:** só as firmes **encerradas no período** (`C2_DATRF`), porque só nelas a sobra do empenho já voltou ao
  estoque. Os valores são de toda a vida da OP.
- **Produzido:** Σ `D3_QUANT` dos apontamentos de produção da OP (`D3_CF` iniciando com `PR`, sem estorno).
- **Empenhado:** Σ `D4_QTDEORI` dos componentes da OP (SD4).
- **Consumido:** Σ requisições (`D3_CF` iniciando com `RE`) − Σ devoluções (`DE`) com `D3_OP` da OP, sem estorno.
- **Perda de material** = consumido − produzido; em % do consumido. É diferente de `pcp.losses` (`D3_PERDA`,
  perda apontada na produção).
- **Devolvido ao estoque (não absorvido)** = empenhado − consumido.
- **Fora da conta:** mão de obra (`B1_TIPO = 'MO'`) e componentes com unidade (`B1_UM`) diferente da do produto
  (`C2_UM`), avisados na resposta. OP sem empenho nem consumo comparável também fica fora e é avisada.
- A OP é ligada à SD3/SD4 pela chave `C2_NUM + C2_ITEM + C2_SEQUEN + C2_ITEMGRD` (operador de concatenação do
  banco por `MatiConcat()`).

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `pcp.material_reserved` | kpi | Empenhado das OPs encerradas (aceita comparação) | D4_OP, D4_COD, D4_QTDEORI, B1_UM, B1_TIPO, C2_UM | tat | = |
| `pcp.material_consumed` | kpi | Consumido (requisições − devoluções) | D3_OP, D3_CF, D3_QUANT, D3_ESTORNO | tat | = |
| `pcp.material_produced` | kpi | Produzido nas OPs encerradas | D3_OP, D3_CF, D3_QUANT | tat | + |
| `pcp.material_loss` | kpi | Consumido − produzido, unidade QTY | — | tat | - |
| `pcp.material_loss_rate` | kpi | Perda ÷ consumido × 100 | — | tat | - |
| `pcp.material_returned` | kpi | Empenhado − consumido | — | tat | = |
| `pcp.material_loss_by_product` | breakdown | Perda de material por produto, top N + "Outros", com `warnings` sobre o que ficou fora | C2_PRODUTO, B1_DESC | tat | - |
| `pcp.material_orders` | list | Uma linha por OP encerrada no período, da maior perda para a menor: empenhado, consumido, produzido, perda, perda %, devolvido. Usa `dateFrom`/`dateTo` | — | tat | = |

O rascunho tinha também `pcp.late_orders` (lista). Ele repetia `pcp.po_late` e foi removido: a lista das
OPs atrasadas é a de `pcp.po_late` (decisão de 2026-10-21).

Abas no app: **Visão geral | OPs | Apontamentos | Matéria-prima**.

---

## Estoque e Custos — `EST`

Tabelas: SB1, SB2, SB8, SB9, SBM, SD2, SD3, SF4.

Valor e quantidade em estoque somam **todos os armazéns** do SB2, sem filtro (decisão de 2026-10-21).
Produtos bloqueados (`B1_MSBLQL = '1'`) entram no valor e na curva ABC, mas ficam fora da lista de
reposição. Com exceção do CMV, os indicadores desta seção são posição de hoje ou usam janelas fixas e
não dependem do período do cabeçalho.

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `est.stock_value` | kpi + breakdown | Σ `B2_VATU1`. A composição aceita `dimension=local` (armazém, padrão), `type` (`B1_TIPO`) ou `group` (`B1_GRUPO`/`BM_DESC`); top N e o resto em "Outros" | B2_VATU1, B2_LOCAL, B1_TIPO, B1_GRUPO, BM_DESC | tat | = |
| `est.below_reorder` | kpi + list | Produtos com Σ `B2_QATU` (todos os armazéns) < `B1_EMIN` (`B1_EMIN > 0`, produto não bloqueado). Ponto de pedido sempre do SB1 (o cliente não usa SBZ). O cartão conta produtos; a lista vai da maior falta para a menor | B1_EMIN, B1_MSBLQL, B2_QATU | op | - |
| `est.coverage_days` | kpi | Σ `B2_QATU` ÷ consumo médio diário dos últimos 90 dias. Consumo = vendas `D2_QUANT` (`D2_TIPO = 'N'`, TES com `F4_ESTOQUE = 'S'`) + requisições SD3 (`D3_CF` iniciando com `RE`, não estornadas). As quantidades de todos os produtos são somadas, sem converter unidades. Sem consumo, o título avisa | B2_QATU, D2_QUANT, D3_QUANT, D3_CF, D3_ESTORNO, F4_ESTOQUE | est | = |
| `est.turnover` | kpi | CMV dos últimos 12 meses ÷ estoque médio, que é a média, entre as datas de fechamento do SB9 nos últimos 12 meses, da soma de `B9_VINI1`. Unidade TIMES (vezes). Sem fechamento no SB9 o índice fica zerado e o título avisa | D2_CUSTO1, B9_DATA, B9_VINI1 | est | + |
| `est.no_movement` | kpi + list | Itens (produto x armazém) com `B2_QATU > 0` e `B2_DMOV` anterior a hoje menos N dias (`MV_TDSEMMV`, padrão 180); data em branco conta como sem movimentação. O cartão conta itens; a lista vai do maior valor parado para o menor | B2_DMOV, B2_QATU, B2_VATU1 | est | - |
| `est.abc_curve` | breakdown | Classes A/B/C pelo valor em estoque de cada produto (soma dos armazéns), por participação acumulada: abaixo de 80% é A, abaixo de 95% é B, o resto é C (o maior produto é sempre A). Traz a quantidade de produtos e o valor de cada classe. Valores zerados ou negativos ficam de fora | B2_VATU1, B2_COD | est | = |
| `est.lots_expiring` | kpi + list | Lotes com `B8_SALDO > 0` e validade preenchida até hoje mais N dias (`MV_TDVALID`, padrão 30), incluindo os já vencidos. O cartão conta lotes; a lista vai da validade mais antiga para a mais recente | B8_PRODUTO, B8_LOCAL, B8_LOTECTL, B8_SALDO, B8_DTVALID | op | - |
| `est.cogs` | kpi + series | CMV: Σ `D2_CUSTO1` das saídas de venda (`D2_TIPO = 'N'`) com TES que movimenta estoque (`F4_ESTOQUE = 'S'`) no período (aceita comparação) | D2_CUSTO1, D2_TIPO, F4_ESTOQUE, D2_EMISSAO | tat | = |
| `est.avg_cost_evolution` | series | Custo médio por fechamento (`B9_VINI1 ÷ B9_QINI`) dos 5 itens de maior valor em estoque hoje. Série mensal, uma por produto | B9_DATA, B9_QINI, B9_VINI1, B2_VATU1 | est | - |

Abas no app: **Valor | Reposição | Validade**.

---

## Recursos Humanos — `GPE`

Tabelas: SRA, SR8, RCM, SRD, SRV, CTT, SRJ. Implementado na Onda 6 (`TDashGpeApi` / `TDashGpeRepository`), desenhado
sobre o diagnóstico da base do cliente (`tools/diagnostico-rh.sql`, 2026-10-21).

**LGPD:** a API devolve apenas números agrupados. Não existe lista de pessoas.

- Grupos (centro de custo, função, faixa, tipo de ausência) com menos de `MV_TDMINGR` pessoas (padrão 5) entram em
  "Outros". Se "Outros" ficar com menos pessoas que isso, o menor grupo restante entra nele. Se o total tiver menos,
  a quebra vem vazia, com um aviso em `warnings` (`u_lgpdGroups`).
- Folha e horas extras de menos de `MV_TDMINGR` pessoas não saem: o cartão vem com `hidden: true` e o app mostra "—".
  O absenteísmo também, quando o quadro tem menos pessoas que o mínimo.

**Quem conta:**

- **Quadro** = admitidos até a data e sem demissão até ela (`RA_DEMISSA` vazio ou posterior). As categorias de
  `MV_TDCATEX` (padrão `A,P`: autônomo e pró-labore) ficam fora do quadro, das admissões, dos desligamentos e das
  ausências.
- Desligamento por **transferência** entre filiais (`RA_RESCRAI` 30 e 31) não conta.
- **Ausência** = tipos da RCM com `RCM_TIPOAF` 1 (afastamento) ou 2 (outras ausências). Férias (4, controle de dias de
  direito) e registros informativos (3) ficam de fora.
- **Folha** = proventos (`RV_TIPOCOD = '1'`) da SRD, que só tem meses fechados. Os roteiros de `MV_TDROTEX` (padrão
  `ADI,131,AUT`) ficam de fora: adiantamento e 1ª parcela do 13º, que são descontados depois, e autônomos.

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `gpe.headcount` | kpi + breakdown | Quadro na data final do período. Quebra `dimension=cc` (centro de custo, padrão) ou `role` (função), top N e o restante em "Outros" | RA_ADMISSA, RA_DEMISSA, RA_CATFUNC, RA_CC, RA_CODFUNC, CTT_DESC01, RJ_DESC | est | = |
| `gpe.hires` | kpi | Admissões (`RA_ADMISSA`) no período | RA_ADMISSA | est | = |
| `gpe.terminations` | kpi | Desligamentos (`RA_DEMISSA`) no período, sem transferências | RA_DEMISSA, RA_RESCRAI | est | - |
| `gpe.turnover` | kpi | ((admissões + desligamentos) ÷ 2) ÷ quadro médio × 100. Quadro médio = média entre a véspera do início e o fim do período | — | est | - |
| `gpe.movements` | series | Admissões (`hires`) e desligamentos (`terminations`) por dia, semana ou mês | RA_ADMISSA, RA_DEMISSA | est | = |
| `gpe.absenteeism` | kpi + breakdown | Dias de ausência no período (interseção de `R8_DATAINI` a `R8_DATAFIM`; fim vazio = ainda ausente) ÷ (quadro médio × dias do período) × 100, em dias corridos. Quebra: dias por tipo (`RCM_DESCRI`), unidade DAYS | R8_MAT, R8_TIPOAFA, R8_DATAINI, R8_DATAFIM, RCM_TIPOAF, RCM_DESCRI | est | - |
| `gpe.payroll` | kpi + series | Σ `RD_VALOR` dos proventos nas competências (`RD_DATARQ`) do período, até a última fechada. Sem competência fechada no período, usa a última fechada e o título diz qual ("Folha de pagamento (set/2026)"). Série mensal `payroll`; meses de menos de `MV_TDMINGR` pessoas ficam fora | RD_DATARQ, RD_PD, RD_VALOR, RD_ROTEIR, RD_MAT, RV_TIPOCOD | est | = |
| `gpe.payroll_by_cc` | breakdown | Folha por centro de custo do lançamento (`RD_CC`), nas mesmas competências; a resposta traz os meses usados em `dateFrom`/`dateTo` | RD_CC, CTT_DESC01 | est | = |
| `gpe.overtime` | kpi + series | Σ `RD_VALOR` das verbas de hora extra escolhidas no app (`overtimeCodes`), nas mesmas competências. Sem verbas, 422 | RD_PD, RD_VALOR | est | - |
| `gpe.overtime_hours` | kpi | Σ `RD_HORAS` das mesmas verbas, só dos lançamentos em horas (`RD_TIPO1 = 'H'`) | RD_HORAS, RD_TIPO1 | est | - |
| `gpe.demographics` | breakdown | Ativos por `dimension=age` (até 24, 25–34, 35–44, 45–54, 55 ou mais), `tenure` (menos de 1 ano, 1–2, 3–5, 6–10, mais de 10) ou `sex` | RA_NASC, RA_ADMISSA, RA_SEXO | est | = |
| `gpe.payroll_codes` | list (apoio) | Verbas de provento da filial, para escolher as de hora extra. Não traz dado de pessoa | RV_COD, RV_DESC, RV_TIPOCOD | est | — |

O rascunho tinha `gpe.hires` e `gpe.terminations` também como série. As duas viraram uma série só,
`gpe.movements`, para o gráfico de admissões e desligamentos (decisão de 2026-10-21).

Abas no app: **Quadro | Folha | Afastamentos**.

---|---|---|---|---|---|
| `gpe.headcount` | kpi + breakdown | Funcionários admitidos até a data e não demitidos (`RA_DEMISSA` vazio ou posterior), por centro de custo e função | RA_ADMISSA, RA_DEMISSA, RA_SITFOLH, RA_CC, RA_CODFUNC, RA_CATFUNC, CTT_DESC01, RJ_DESC | est | = |
| `gpe.hires` | kpi + series | Admissões no período | RA_ADMISSA | est | = |
| `gpe.terminations` | kpi + series | Desligamentos no período | RA_DEMISSA | est | - |
| `gpe.turnover` | kpi | ((admissões + desligamentos) ÷ 2) ÷ headcount médio | — | est | - |
| `gpe.absenteeism` | kpi + breakdown | Dias de afastamento no período (interseção `R8_DATAINI`..`R8_DATAFIM`) ÷ (headcount × dias úteis), por tipo `R8_TIPOAFA` | R8_DATAINI, R8_DATAFIM, R8_TIPOAFA, R8_DURACAO | est | - |
| `gpe.payroll` | kpi + series | Σ `RD_VALOR` de verbas de provento (`RV_TIPOCOD = '1'`) por competência (`RD_DATARQ`) | RD_DATARQ, RD_PD, RD_VALOR, RV_TIPOCOD | est | = |
| `gpe.payroll_by_cc` | breakdown | Folha por centro de custo | RD_CC, CTT_DESC01 | est | = |
| `gpe.overtime` | kpi + series | Σ `RD_HORAS` e `RD_VALOR` das verbas de hora extra **informadas pelo usuário no app** (parâmetro `overtimeCodes`). Sem verbas configuradas, a API devolve 422 e o app mostra "Configure as verbas de hora extra" | RD_PD, RD_HORAS, RD_VALOR | est | - |
| `gpe.demographics` | breakdown | Faixa etária (`RA_NASC`), tempo de casa (`RA_ADMISSA`) e sexo (`RA_SEXO`) | RA_NASC, RA_ADMISSA, RA_SEXO | est | = |
| `gpe.payroll_codes` | list (apoio) | Verbas cadastradas, para o usuário escolher no app. Não traz dado de pessoa | RV_COD, RV_DESC, RV_TIPOCOD | est | — |

Abas no app: **Quadro | Folha | Afastamentos**.

---

## Contabilidade — `CTB`

Tabelas: CVE (cabeçalho da Visão Gerencial), CTS (linhas), CQ0 (saldo por conta, por mês) e CQ2 (saldo por conta e
centro de custo, por mês).

A Contabilidade sai em etapas: **1) demonstrações (DRE e Balanço) e apoio**, já feita; **2) indicadores** (margens,
liquidez, receita x despesa), depois que você validar os números da etapa 1; **3) lançamentos** (adiada, ver abaixo).

As demonstrações usam a **Visão Gerencial** do cliente. Quem escolhe a visão da DRE e a do Balanço é o usuário, em
Configurações > Parâmetros dos indicadores (por servidor e empresa). O app manda o código no parâmetro `view`; a API
valida o formato e se a visão existe na CVE da filial. Sem visão, ou com visão desconhecida, a resposta é 422
(`TDASH-422-CONFIG`) e o app mostra "Configure a visão gerencial".

**Como o valor de cada linha é calculado**

- A visão existe **por filial** (CVE/CTS seguem o compartilhamento do dicionário). Uma linha é um `CTS_CONTAG`; ela pode
  ter várias linhas de faixa na CTS, e os saldos das faixas se somam.
- **Linha analítica** (`CTS_CLASSE = '2'`): soma dos saldos das contas da faixa `CTS_CT1INI` a `CTS_CT1FIM`. Sem faixa
  de centro de custo, o saldo vem da **CQ0**; com faixa de centro de custo (`CTS_CTTINI/FIM`), vem da **CQ2**, só dos
  centros dentro da faixa. Moeda `01`, saldo real (tipo `1`). A natureza (`CTS_NORMAL`) define o sinal: `1` devedora é
  débito − crédito; `2` credora é crédito − débito.
- **Linha sintética** (`CTS_CLASSE = '1'`, identificador `3` subtotal ou `4` total geral): soma das linhas filhas
  (`CTS_CTASUP`). A filha de mesma natureza soma; a de natureza oposta subtrai. É assim que a DRE sai: receita bruta
  (credora) − deduções (devedora) = receita líquida; − custos = resultado bruto; e assim até o resultado líquido.
- **DRE**: movimento do período, sem os lançamentos de apuração (`CQ0_LP` / `CQ2_LP` iguais a `S` ou `Z`).
  **Balanço**: saldo acumulado até a data final, com todos os sinalizadores (a CQ0 guarda o movimento de cada mês).
- **Meses inteiros**: a CQ0 e a CQ2 são mensais e gravam o movimento com a data do **último dia do mês**. O período
  vai do primeiro dia do mês inicial ao último dia do mês final (outubro até o dia 21 = outubro inteiro, com o que já
  foi lançado). A comparação também é em meses: `prev` = a mesma quantidade de meses imediatamente anterior; `yoy` =
  os mesmos meses do ano anterior. A resposta traz os meses usados (`dateFrom`, `dateTo`, `compareFrom`, `compareTo`,
  em AAAA-MM-DD) e o app mostra "outubro/2026" na legenda.
- Linhas com faixa de **item contábil ou classe de valor** ainda não são calculadas; a API avisa em `warnings`.
- Só aparecem para escolha as visões que têm linhas analíticas com faixa de conta (no cliente: 003, 005 e 100; as de
  fluxo de caixa e L210 não são calculáveis por saldo).

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `ctb.views` | list (apoio) | Visões gerenciais da filial com linhas analíticas por faixa de conta | CVE_CODIGO, CVE_DESCRI, CTS_CLASSE, CTS_CT1INI | est | — |
| `ctb.view_lines` | list (apoio) | Linhas de uma visão (`view=`), na ordem da visão, uma por `CTS_CONTAG` | CTS_ORDEM, CTS_CONTAG, CTS_DESCCG, CTS_CLASSE, CTS_IDENT, CTS_CTASUP | est | — |
| `ctb.income_statement` | breakdown | DRE: todas as linhas da visão (`view=`) com valor, nível, tipo (`detail`, `subtotal`, `total`) e, com comparação, o valor anterior | CTS_*, CQ0_*, CQ2_* | est | = |
| `ctb.balance_sheet` | breakdown | Balanço: idem, saldo acumulado até a data final | CTS_*, CQ0_*, CQ2_* | est | = |
| `ctb.revenue_expense` | series | **Etapa 2.** Receita e despesa por mês, linhas escolhidas pelo usuário | | est | + |
| `ctb.margins` | kpi | **Etapa 2.** Margem bruta, operacional e líquida, linhas escolhidas pelo usuário | | est | + |
| `ctb.liquidity` | kpi | **Etapa 2.** Liquidez corrente e seca, endividamento, linhas escolhidas pelo usuário | | est | + |
| `ctb.entries` | list | **Adiada.** Lançamentos do período (CT2): a tabela é grande e a paginação atual (por salto de registros) não serve | CT2_* | est | — |

Abas no app: **DRE | Balanço**, cada uma em **Resumo** (subtotais e total) ou **Detalhado** (com as linhas de detalhe;
as zeradas no período somem).

**Estado da validação.** O motor foi desenhado sobre os dados do cliente (diagnóstico de 2026-10-21: visões 003 e 100,
sem fórmulas, só centro de custo nas faixas, saldos reais). Os números ainda precisam ser conferidos com o relatório
padrão de visão gerencial do Protheus (ver `status/tdash-onda5.md`).

---

## Livros Fiscais — `FIS`

Tabelas: SF3 (livro por nota), SFT (livro por item); na centralização também SD1 (ISS retido), F2D e F2B (CBS e IBS).

Notas canceladas (`F3_DTCANC` / `FT_DTCANC` preenchido) ficam fora de todos os totais, menos `fis.cancelled`.
Entradas: CFOP iniciando com 1, 2 ou 3. Saídas: CFOP iniciando com 5, 6 ou 7. O período é a data de
entrada/saída do livro (`F3_ENTRADA`, `FT_ENTRADA`). Linhas com CFOP em branco não entram em débito nem em crédito.

| id | Tipo | Cálculo | Campos | TTL | Sentido |
|---|---|---|---|---|---|
| `fis.icms_balance` | kpi + series | Saldo = débito (Σ `F3_VALICM` das saídas) − crédito (das entradas), sem as notas de serviço (`F3_TIPO <> 'S'`). A série mensal traz `debit` e `credit` (aceita comparação) | F3_ENTRADA, F3_CFO, F3_VALICM, F3_TIPO, F3_DTCANC | est | = |
| `fis.ipi_balance` | kpi + series | Mesmo cálculo com `F3_VALIPI` | F3_VALIPI | est | = |
| `fis.pis_cofins` | kpi + series | Saldo = débito − crédito de PIS **mais** COFINS, pela SFT: `FT_TIPOMOV = 'S'` é débito e `'E'` é crédito | FT_ENTRADA, FT_TIPOMOV, FT_VALPIS, FT_VALCOF, FT_DTCANC | est | = |
| `fis.iss` | kpi | Σ `F3_VALICM` das notas de serviço (`F3_TIPO = 'S'`), entradas e saídas | F3_TIPO, F3_VALICM | est | = |
| `fis.icms_st` | kpi | Σ `F3_ICMSRET` (ICMS ST), sem serviços, entradas e saídas | F3_ICMSRET | est | = |
| `fis.difal` | kpi | Σ `F3_DIFAL`, sem serviços, entradas e saídas | F3_DIFAL | est | = |
| `fis.by_cfop` | breakdown | Valor contábil (`F3_VALCONT`) por CFOP, top N e o resto em "Outros". O rótulo traz o sentido: "Saída 5.102", "Entrada 1.102" | F3_CFO, F3_VALCONT | est | = |
| `fis.by_state` | breakdown | Valor contábil das saídas por UF (`F3_ESTADO`) | F3_ESTADO, F3_VALCONT | est | = |
| `fis.cancelled` | kpi + list | Notas canceladas, pela **data de cancelamento** (`F3_DTCANC`) no período. Conta notas (documento + série + cliente/fornecedor + loja), não linhas do livro. A lista vai da mais recente para a mais antiga | F3_NFISCAL, F3_SERIE, F3_CLIEFOR, F3_LOJA, F3_DTCANC, F3_VALCONT | est | - |

O rascunho tinha `fis.st_difal` com dois valores (ICMS ST e DIFAL). Foi dividido em `fis.icms_st` e `fis.difal`,
dois cartões, porque são duas medidas diferentes (decisão de 2026-10-21).

### Visão geral e centralização de débitos e créditos (Onda F1, 2026-10-27)

Uma linha de centralização por mês junta todos os tributos da filial (`tdash.fis.u_ledger*`). Débito e crédito:

| Tributo | Débito | Crédito | Fonte |
|---|---|---|---|
| ICMS | `F3_VALICM` das saídas | `F3_VALICM` das entradas | SF3 sem serviço (`F3_TIPO <> 'S'`) |
| ICMS-ST | `F3_ICMSRET` das saídas | `F3_ICMSRET` das entradas | SF3 sem serviço |
| DIFAL e FCP | `F3_DIFAL + F3_VFCPDIF` das saídas **mais** `F3_ICMSCOM` das entradas (a empresa paga o complementar) | — | SF3 sem serviço |
| IPI | `F3_VALIPI` das saídas | `F3_VALIPI` das entradas | SF3 sem serviço |
| PIS / COFINS | `FT_VALPIS` / `FT_VALCOF` das saídas | o mesmo das entradas com `FT_CSTPIS` / `FT_CSTCOF` entre 50 e 66 | SFT |
| ISS próprio | `F3_VALICM` das notas de serviço de saída | — | SF3 (`F3_TIPO = 'S'`) |
| ISS retido | `D1_VALISS` das notas de entrada que têm `FT_RECISS = '1'` no livro | — | SD1 + SFT |
| CBS / IBS | F2D das saídas (SD2, por `D2_EMISSAO`) | F2D das entradas (SD1, por `D1_DTDIGIT`) | F2D + F2B (`F2B_TRIB` CBS% / IBS%) |

- Saldo = débito − crédito; positivo "A recolher", negativo "Credor". Visão gerencial: não usa o saldo credor do
  mês anterior nem os ajustes da apuração (CDH).
- **CBS e IBS ficam fora do total** ("(fora do total)"): em 2026 são compensados no PIS e na COFINS.
- O ISS retido vem do item da nota (`D1_VALISS`) porque o livro grava o ISS retido zerado (diagnóstico de
  2026-10-27). O contas a pagar (`E2_ISS`) dá um valor menor no mesmo período; a escolha pelo `D1_VALISS` foi
  aprovada e pode ser revista.

| id | Tipo | Cálculo | TTL | Sentido |
|---|---|---|---|---|
| `fis.ledger` | list | Centralização. `scope=branch` (padrão): um tributo por linha com débito, crédito, saldo e situação, e a linha `total` (sem CBS e IBS). `scope=all`: saldo de cada tributo por filial liberada ao usuário (`FWLoadSM0` com `SM0_USEROK`, mesma empresa do app), coluna `b_<filial>`, e a soma. Uma página só | tat | = |
| `fis.ledger_debit` / `fis.ledger_credit` / `fis.ledger_balance` | kpi | Débitos, créditos e saldo da centralização, sem CBS e IBS | tat | = |
| `fis.tax_burden` | kpi | Carga tributária: (ICMS + IPI + PIS + COFINS + ISS próprio) das saídas ÷ `F3_VALCONT` das saídas × 100 | tat | ↓ |
| `fis.ledger_trend` | series | Débitos e créditos da centralização por mês (séries `debit` e `credit`) | tat | = |
| `fis.top_parties` | breakdown | Clientes e fornecedores pela soma de `FT_VALICM + FT_VALIPI + FT_VALPIS + FT_VALCOF + FT_ICMSRET` (o `FT_VALICM` das notas de serviço é o ISS). Saída é cliente e entrada é fornecedor; `FT_TIPO` D ou B inverte. Nome do cadastro (SA1/SA2) só nas N primeiras linhas | tat | = |
| `fis.top_ncm` | breakdown | NCM (`FT_POSIPI`) das saídas pela mesma soma; rótulo "3207.40.10", vazio ou zerado é "Sem NCM" | tat | = |
| `fis.by_state_in` | breakdown | Valor contábil das entradas por UF (o par de `fis.by_state`) | est | = |

Abas no app: **Visão geral | Centralização | Apuração | CFOP | Canceladas**. A visão geral tem o mapa do Brasil em
blocos (`UfMap`) com `fis.by_state` ou `fis.by_state_in`.

---

## Parâmetros TDash (lidos com `SuperGetMV`, todos com padrão no código)

| Parâmetro | Padrão | Uso |
|---|---|---|
| `MV_TDINADD` | 30 | Dias de atraso para contar como inadimplência |
| `MV_TDDIASV` | 30 | Janela "a vencer" (dias) |
| `MV_TDTOPN` | 10 | Tamanho padrão dos rankings |
| `MV_TDSEMMV` | 180 | Dias sem movimento (estoque) |
| `MV_TDVALID` | 30 | Janela de lotes a vencer (dias) |
| `MV_TDMINGR` | 5 | Tamanho mínimo de grupo no RH (LGPD) |
| `MV_TDCATEX` | `A,P` | Categorias (`RA_CATFUNC`) fora do quadro do RH: autônomo e pró-labore |
| `MV_TDROTEX` | `ADI,131,AUT` | Roteiros (`RD_ROTEIR`) fora da folha: adiantamento, 1ª parcela do 13º e autônomos |

Os parâmetros só precisam ser criados no SX6 se o cliente quiser mudar o padrão. A criação vai
documentada no [`README.md`](../README.md).

## Parâmetros informados pelo usuário no app

Mudam muito de um cliente para outro, por isso ficam no app (seção "Parâmetros dos indicadores" em
Configurações) e não no SX6. São salvos por **servidor + empresa** e enviados em cada requisição.

| Parâmetro do app | Enviado como | Validação na API | Usado em |
|---|---|---|---|
| Verbas de hora extra | `overtimeCodes=101,102,105` | Até 30 códigos, cada um com 3 caracteres (`RV_COD`); todos precisam existir na SRV da filial | `gpe.overtime`, `gpe.overtime_hours` |
| Visão da DRE | `view=001` | 3 caracteres (`CTS_CODPLA`); precisa existir na CTS | `ctb.income_statement`, `ctb.margins`, `ctb.revenue_expense` |
| Visão do Balanço | `view=002` | Idem | `ctb.balance_sheet`, `ctb.liquidity` |
| Linhas da DRE | `lines=netRevenue:<linha>,grossProfit:<linha>,operatingProfit:<linha>,netProfit:<linha>,revenue:<linha>,expense:<linha>` | Papéis fixos (lista acima); linha com até 20 caracteres (`CTS_CONTAG`) existente na visão | `ctb.margins`, `ctb.revenue_expense` |
| Linhas do Balanço | `lines=currentAssets:<linha>,inventories:<linha>,currentLiabilities:<linha>,nonCurrentLiabilities:<linha>,totalAssets:<linha>` | Idem | `ctb.liquidity` |

Os valores sempre entram na consulta por bind. Nunca são concatenados no SQL.

## Decisões de regra de negócio (2026-10-20)

| # | Assunto | Decisão |
|---|---|---|
| 1 | `fat.backlog` | Regra de encerramento confirmada |
| 2 | `fin.cash_realized` | Mesmos filtros do relatório padrão FINR620 (seção Financeiro) |
| 3 | Produção | SD3 é a fonte principal (inclusive perdas via `D3_PERDA`). SH6 é opcional |
| 4 | Ponto de pedido | Sem SBZ. Usa `B1_EMIN` |
| 5 | Verbas de hora extra | O usuário informa no app |
| 6 | Visões gerenciais e linhas | O usuário informa no app, escolhendo em listas vindas da API |
| 7 | `fin.bank_balance` | Confirmado pelo Financeiro em 2026-10-21: só contas do fluxo de caixa (`A6_FLUXCAI <> 'N'`) em moeda 1 |
| 8 | Estoque: armazéns | Todos os armazéns do SB2, sem filtro |
| 9 | Estoque: produtos bloqueados | Entram no valor e na curva ABC; saem da lista "abaixo do ponto de pedido" |
| 10 | Produção: OP aberta | Só OPs firmes (`C2_TPOP = 'F'`); as previstas ficam de fora |
| 11 | Produção: `pcp.late_orders` | Removido; a lista das OPs atrasadas é a de `pcp.po_late` |
| 12 | Giro de estoque sem fechamento no SB9 | Índice zerado e título "Giro de estoque (sem fechamento no período)" |
| 13 | Fiscal: `fis.st_difal` | Dividido em `fis.icms_st` e `fis.difal` (dois cartões) |
| 14 | Fiscal: ISS, ICMS ST e DIFAL | Seguem o catálogo ao pé da letra: somam entradas e saídas, sem separar por CFOP. **A conferir com o Fiscal** |
| 15 | Fiscal: notas canceladas | Contadas pela data de cancelamento (`F3_DTCANC`), uma por nota |
| 16 | Contabilidade: cálculo das linhas | Analítica = saldo da faixa de contas (CQ0, ou CQ2 com faixa de centro de custo), pela natureza; sintética = soma das filhas, subtraindo as de natureza oposta |
| 17 | Contabilidade: apuração | A DRE ignora os lançamentos de apuração (`LP` = S e Z); o Balanço acumula todos |
| 18 | Contabilidade: indicadores (margens, liquidez, receita x despesa) | Etapa 2, depois de validadas as demonstrações |
| 19 | Contabilidade: `ctb.entries` | Adiada: CT2 é grande e a paginação por salto de registros não serve |
| 20 | Contabilidade: visões oferecidas | Só as que têm linhas analíticas por faixa de conta |
| 21 | Contabilidade: período | Meses inteiros (os saldos são mensais, gravados no último dia do mês); comparação em meses |
| 22 | RH: quadro | Sem autônomos e pró-labore (`MV_TDCATEX`); transferência entre filiais não é desligamento |
| 23 | RH: absenteísmo | Ausências de tipo 1 (afastamento) e 2 (outras), sem férias e informativos; dias corridos nos dois lados da conta (o rascunho falava em dias úteis) |
| 24 | RH: folha | Só meses fechados (SRD), confirmado pelo usuário em 2026-10-21; sem adiantamento, 1ª parcela do 13º e autônomos (`MV_TDROTEX`) |
| 25 | RH: período sem folha fechada | Usa a última competência fechada e diz qual no título do cartão |
| 26 | RH: LGPD | Grupos com menos de `MV_TDMINGR` pessoas em "Outros", que nunca fica abaixo do mínimo; folha de grupo pequeno não sai (`hidden`) |
| 27 | RH: séries de admissões e desligamentos | Uma série só, `gpe.movements` |
| 28 | Produção: horas da SH6 | Hora normal ou centesimal por `H6_TIPOTEM` (sem ele, `MV_TPHR`), como o padrão do PCP |
| 29 | Produção: balanço de matéria-prima | Só OPs encerradas no período; sem mão de obra; componentes em unidade diferente da do produto ficam fora e são avisados; perda de material e perda apontada aparecem separadas (confirmado pelo usuário em 2026-10-22) |

Não há pendências de regra de negócio abertas.
