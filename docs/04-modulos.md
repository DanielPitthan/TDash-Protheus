# 04 — Módulos

Para cada módulo:

- fontes e catálogo, lidos dos fontes;
- o que cada tela do app chama;
- onde fica cada regra de negócio;
- os métodos da API e do repositório.

As fórmulas e as decisões com o cliente estão em
[`10-catalogo-de-indicadores.md`](10-catalogo-de-indicadores.md).

Validade: 5 min (`TTL_OP`), 30 min (`TTL_TAT`), 12 h (`TTL_EST`).


## Financeiro — `FIN`

- **Rotas:** `/tdash/v1/fin/...`, com `x-erp-module: FIN`.
- **Abas no app:** Receber · Pagar · Caixa.
- **Fontes:** `src/fin/tdash.fin.api.tlpp`, `src/fin/tdash.fin.repository.tlpp`; posição do cliente e do fornecedor em
  `src/fin/tdash.fin.party.api.tlpp`, `src/fin/tdash.fin.party.repository.tlpp` e `src/fin/tdash.fin.party.rules.tlpp`.

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `fin.bank_balance` | kpi, breakdown | Saldo bancário | `BRL` | `up_is_good` | 5 min |
| `fin.receivable_open` | kpi | A receber em aberto | `BRL` | `neutral` | 5 min |
| `fin.receivable_overdue` | kpi | A receber vencido | `BRL` | `down_is_good` | 5 min |
| `fin.receivable_due` | kpi | A receber em 30 dias | `BRL` | `neutral` | 5 min |
| `fin.payable_open` | kpi | A pagar em aberto | `BRL` | `neutral` | 5 min |
| `fin.payable_overdue` | kpi | A pagar vencido | `BRL` | `down_is_good` | 5 min |
| `fin.payable_due` | kpi | A pagar em 30 dias | `BRL` | `neutral` | 5 min |
| `fin.default_rate` | kpi | Inadimplência | `PCT` | `down_is_good` | 30 min |
| `fin.dso` | kpi | Prazo médio de recebimento | `DAYS` | `down_is_good` | 12 h |
| `fin.dpo` | kpi | Prazo médio de pagamento | `DAYS` | `up_is_good` | 12 h |
| `fin.cashflow_projection` | series | Fluxo de caixa projetado | `BRL` | `up_is_good` | 30 min |
| `fin.cash_realized` | series | Entradas e saídas realizadas | `BRL` | `up_is_good` | 30 min |
| `fin.aging_receivable` | breakdown | Vencidos a receber por atraso | `BRL` | `down_is_good` | 30 min |
| `fin.aging_payable` | breakdown | Vencidos a pagar por atraso | `BRL` | `down_is_good` | 30 min |
| `fin.top_debtors` | breakdown | Maiores devedores | `BRL` | `down_is_good` | 30 min |
| `fin.top_creditors` | breakdown | Maiores pagamentos em 30 dias | `BRL` | `neutral` | 30 min |
| `fin.cash_by_bank` | breakdown | Resultado do caixa por conta | `BRL` | `up_is_good` | 30 min |
| `fin.overdue_receivables` | list | Títulos a receber vencidos | `BRL` | `down_is_good` | 5 min |
| `fin.overdue_payables` | list | Títulos a pagar vencidos | `BRL` | `down_is_good` | 5 min |

**O que a tela chama**

- **Receber:**
  - `kpis`: `fin.receivable_open`, `fin.receivable_overdue`, `fin.receivable_due`, `fin.default_rate`, `fin.dso`;
  - `breakdown`: `fin.aging_receivable`, `fin.top_debtors` (top 5);
  - lista `fin.overdue_receivables`.
- **Pagar:** os mesmos, com `fin.payable_*`, `fin.dpo`, `fin.aging_payable`, `fin.top_creditors` e
  `fin.overdue_payables`.
- **Caixa:**
  - `kpis` e `breakdown` de `fin.bank_balance`;
  - série `fin.cashflow_projection`, sem datas: a API usa de hoje até hoje + 30 dias;
  - série `fin.cash_realized` no período, com a granularidade da escolha.

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| Tipos de título que não são dívida (abatimento, provisório, adiantamento, crédito) | `TDashFinRepository:excludedTypes`, que lê as variáveis do Financeiro por `publicList` |
| Saldo em aberto, vencido e a vencer | `TDashFinRepository:titleBalance` |
| Prazos de 30 dias ("a vencer" e inadimplência) | Constantes `DEFAULT_DUE_DAYS` e `DEFAULT_LATE_DAYS` em `tdash.fin.api.tlpp` |
| Faixas de atraso (5 faixas, sempre na mesma ordem) | `TDashFinRepository:aging` |
| Saldo bancário (contas do fluxo de caixa, moeda 1, não bloqueadas) | `TDashFinRepository:bankBalances` |
| Caixa realizado (mesmos filtros do FINR620) | `TDashFinRepository:cashWhere` e `motivesWithoutBank` |

### Métodos da API (`TDashFinApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/fin/catalog |
| `getKpis()` | GET /tdash/v1/fin/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy Saldos (a receber, a pagar, bancário) são posição de hoje e não têm comparação; prazos médios (PMR/PMP) usam o período e aceitam comparação |
| `getSeries()` | GET /tdash/v1/fin/series/:id?dateFrom&dateTo&grain=day\|week\|month fin.cashflow_projection: a receber, a pagar e saldo projetado (padrão: hoje até hoje + 30) |
| `getBreakdown()` | GET /tdash/v1/fin/breakdown/:id?top=10&dateFrom&dateTo Composição e rankings: saldo por conta, aging, maiores devedores/credores, caixa por conta |
| `getList()` | GET /tdash/v1/fin/list/:id?page=1&pageSize=20 Títulos vencidos a receber (fin.overdue_receivables) ou a pagar (fin.overdue_payables) |
| `kpiValue(cId as character, dFrom as date, dTo as date, dToday as date) as numeric` | Calcula o valor de um cartão |
| `static finCatalog() as array` | Catálogo do Financeiro: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashFinRepository`)

| Método | O que faz |
|---|---|
| `titleBalance(cSide as character, cScope as character, dToday as date, nDays as numeric) as numeric` | Soma de saldo de títulos em aberto |
| `aging(cSide as character, dToday as date) as array` | Saldo vencido por faixa de atraso (1-30, 31-60, 61-90, 91-180, acima de 180 dias) |
| `projection(cSide as character, dFrom as date, dTo as date) as array` | Saldo a vencer por data de vencimento real no intervalo |
| `averageTerm(cSide as character, dFrom as date, dTo as date) as numeric` | Prazo médio (PMR para receber, PMP para pagar) dos títulos baixados no período: média de (baixa - emissão) ponderada pelo valor do título |
| `topParties(cSide as character, dToday as date, nDays as numeric, nTop as numeric) as array` | Maiores clientes (saldo vencido) ou fornecedores (saldo a vencer em nDays dias) |
| `overdueTitles(cSide as character, dToday as date, nPage as numeric, nPageSize as numeric) as json` | Títulos vencidos, do mais atrasado para o mais recente, paginados |
| `bankBalances(dDate as date) as array` | Último saldo (SE8) de cada conta até a data |
| `cashMovements(dFrom as date, dTo as date) as array` | Movimento bancário realizado por dia de disponibilidade, com os filtros do relatório padrão FINR620 (ver cashWhere) |
| `cashByBank(dFrom as date, dTo as date) as array` | Entradas e saídas realizadas por banco/agência/conta (mesmos filtros de cashMovements) |
| `cashWhere() as character` | Filtros do movimento bancário iguais ao relatório padrão FINR620 (linhas 604-616 e 797-892): banco informado, não cancelado, data de disponibilidade no período, não pré-datado, sem documentos de juros/multa/desconto/baixa/correção, sem cheque cancelado e as regras de numerário/transferência/SG |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |
| `sideInfo(cSide as character) as json` | Tabela e campos de cada lado (receber/pagar) |
| `excludedTypes(cSide as character) as array` | Tipos de título que não são dívida real: abatimentos (MVABATIM), provisórios (MVPROVIS), adiantamentos (MVRECANT / MVPAGANT) e créditos (MV_CRNEG / MV_CPNEG) |
| `publicList(cName as character, cDefault as character) as array` | Lê uma variável pública do Financeiro (ex.: MVABATIM = "AB-\|FB-\|FC-") e separa os tipos |
| `motivesWithoutBank() as array` | Motivos de baixa que não movimentam banco (ReadMotBx + MovBcoBx), excluídos do caixa realizado como no FINR620 |
| `static bankName(cName as character, cShort as character) as character` | Nome do banco para exibição: A6_NOME; se vier vazio ou só pontuação, usa A6_NREDUZ |

`excludedTypes`, `motivesWithoutBank` e `cashWhere` são públicos porque a posição do cliente e do fornecedor usa as
mesmas regras.

### Posição do cliente e do fornecedor (`TDashFinParty`)

`TDashFinApi` repassa para `TDashFinParty` todo indicador `fin.party_*` das rotas `kpis`, `series/:id`,
`breakdown/:id` e `list/:id`. Parâmetros: `type=customer|supplier`, `code`, `store` (opcional; vazio junta as
lojas). A busca é `list/fin.party_search?type&search`. Regras: [`10-catalogo-de-indicadores.md`](10-catalogo-de-indicadores.md).

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `fin.party_search` | list | Buscar cliente ou fornecedor | `COUNT` | `neutral` | 30 min |
| `fin.party_open` | kpi | Em aberto | `BRL` | `neutral` | 5 min |
| `fin.party_overdue` | kpi | Vencido | `BRL` | `down_is_good` | 5 min |
| `fin.party_not_due` | kpi | A vencer | `BRL` | `neutral` | 5 min |
| `fin.party_credit_limit` | kpi | Limite de crédito | `BRL` | `neutral` | 30 min |
| `fin.party_credit_available` | kpi | Crédito disponível | `BRL` | `up_is_good` | 5 min |
| `fin.party_settled` | kpi, series | Recebido ou pago no período | `BRL` | `neutral` | 30 min |
| `fin.party_aging` | breakdown | Vencido por atraso | `BRL` | `down_is_good` | 5 min |
| `fin.party_titles` | list | Títulos em aberto | `BRL` | `neutral` | 5 min |
| `fin.party_stores` | list | Cadastro e histórico por loja | `BRL` | `neutral` | 30 min |

**O que a tela chama** (`/modules/fin/party/{customer|supplier}`)

- Sem código: `list/fin.party_search` com o texto digitado.
- Com código: `kpis` (`fin.party_open`, `fin.party_overdue`, `fin.party_not_due`, `fin.party_settled` e, para
  clientes, `fin.party_credit_limit` e `fin.party_credit_available`), `breakdown/fin.party_aging`,
  `series/fin.party_settled` e `list/fin.party_stores` (sem `store`, para ter todas as lojas). "Ver títulos em
  aberto" abre `list/fin.party_titles`.

| Regra | Onde |
|---|---|
| Código e loja da requisição (letras e números, tamanho do campo; 404 se não existir) | `TDashFinParty:readParty` e `tdash.fin.u_validPartyKey` |
| Títulos do código/loja, sem os tipos que não são dívida | `TDashFinPartyRepository:titleFrom` e `bindTitles` |
| Limite e crédito disponível (`MV_CREDCLI`) | `TDashFinParty:kpiValue` e `static creditScope` |
| Junção das lojas | `tdash.fin.u_consolidateStores` (`tdash.fin.party.rules.tlpp`) |
| Recebido/pago (filtros do FINR620, estornos abatem) | `TDashFinPartyRepository:settled` |

| Método | O que faz |
|---|---|
| `TDashFinParty:kpis(aIds, oRequest, oHelper)` | Cartões da posição |
| `TDashFinParty:series(cId, oRequest, oHelper)` | Série `settled` |
| `TDashFinParty:breakdown(cId, oRequest, oHelper)` | Aging do cliente ou fornecedor |
| `TDashFinParty:list(cId, oRequest, oHelper)` | Busca, títulos em aberto e cadastro por loja |
| `TDashFinPartyRepository:search(cType, cTerm, nMax)` | Busca por nome, nome fantasia, código ou CNPJ/CPF |
| `TDashFinPartyRepository:stores(cType, cCode)` | Cadastro e histórico de cada loja |
| `TDashFinPartyRepository:balance(cType, cScope, dToday, cCode, cStore)` | Saldo em aberto ou vencido |
| `TDashFinPartyRepository:aging(cType, dToday, cCode, cStore)` | Saldo vencido por faixa de atraso |
| `TDashFinPartyRepository:titles(cType, dToday, cCode, cStore, nPage, nPageSize)` | Títulos em aberto paginados |
| `TDashFinPartyRepository:settled(cType, dFrom, dTo, cCode, cStore)` | Recebido ou pago por dia |
| `u_agingBuckets()`, `u_agingBucket(nDays)` | Faixas de atraso |
| `u_validPartyKey(cValue, nSize)` | Confere código e loja vindos da requisição |
| `u_consolidateStores(aStores, cCreditMode)` | Junta as lojas numa posição só |
| `u_isPartyId(cId)`, `u_partyCatalog()` | Indicadores da posição e o catálogo deles |

## Faturamento — `FAT`

- **Rotas:** `/tdash/v1/fat/...`, com `x-erp-module: FAT`.
- **Abas no app:** Vendas · Resultado · Carteira · Rankings.
- **Fontes:** `src/fat/tdash.fat.api.tlpp`, `src/fat/tdash.fat.repository.tlpp`, `src/fat/tdash.fat.result.tlpp`
  (conta do resultado).

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `fat.revenue` | kpi, series | Faturamento bruto | `BRL` | `up_is_good` | 5 min |
| `fat.revenue_net` | kpi | Faturamento líquido | `BRL` | `up_is_good` | 30 min |
| `fat.invoice_count` | kpi | Notas fiscais emitidas | `COUNT` | `up_is_good` | 5 min |
| `fat.avg_ticket` | kpi | Ticket médio por nota | `BRL` | `up_is_good` | 30 min |
| `fat.returns` | kpi | Devoluções | `BRL` | `down_is_good` | 30 min |
| `fat.target_attainment` | kpi | Meta x realizado | `PCT` | `up_is_good` | 30 min |
| `fat.backlog` | kpi, list | Carteira de pedidos | `BRL` | `up_is_good` | 5 min |
| `fat.top_customers` | breakdown | Maiores clientes | `BRL` | `neutral` | 30 min |
| `fat.top_products` | breakdown | Produtos mais vendidos | `BRL` | `neutral` | 30 min |
| `fat.by_seller` | breakdown | Faturamento por vendedor | `BRL` | `neutral` | 30 min |
| `fat.by_state` | breakdown | Faturamento por UF | `BRL` | `neutral` | 12 h |
| `fat.gross_profit` | kpi | Lucro bruto | `BRL` | `up_is_good` | 30 min |
| `fat.net_profit` | kpi | Lucro líquido | `BRL` | `up_is_good` | 30 min |
| `fat.taxes` | kpi | Impostos sobre vendas | `BRL` | `down_is_good` | 30 min |
| `fat.result` | series | Lucro bruto, lucro líquido e impostos | `BRL` | `neutral` | 30 min |
| `fat.taxes_by_type` | breakdown | Impostos por tipo | `BRL` | `neutral` | 30 min |

`fat.net_profit`, `fat.taxes`, `fat.result` e `fat.taxes_by_type` aceitam `taxRegime=current|reform` (padrão
`current`): `current` soma PIS e COFINS no total de impostos; `reform` soma CBS e IBS no lugar deles. O valor vem do
ajuste "Usar CBS/IBS no lugar de PIS/COFINS" do app (não há parâmetro no Protheus).

**O que a tela chama**

- **Vendas:**
  - `kpis` com **`compare=yoy`**: `fat.revenue`, `fat.revenue_net`, `fat.returns`, `fat.invoice_count`,
    `fat.avg_ticket`, `fat.target_attainment`;
  - série `fat.revenue`, com as séries `revenue` e `returns`.
- **Resultado:** `kpis` de `fat.gross_profit`, `fat.net_profit` e `fat.taxes` (`compare=yoy`); série `fat.result`
  (últimos 12 meses, mensal, séries `gross`, `net` e `taxes`, com `warnings` nos meses de custo incompleto); `breakdown`
  de `fat.taxes_by_type`. Todas com `taxRegime`.
- **Carteira:** `kpis` de `fat.backlog` (`compare=none`) e lista `fat.backlog`.
- **Rankings:** `breakdown` de `fat.top_customers`, `fat.top_products`, `fat.by_seller` (top 10) e `fat.by_state`
  (top 27).

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| O que é faturamento (`D2_TIPO = 'N'`, TES que gera duplicata, pela emissão) | `TDashFatRepository:salesFrom` |
| Devoluções (notas de entrada tipo D, valor bruto) | `TDashFatRepository:returns` e `returnsByDay` |
| Meta de vendas (SCT) | `TDashFatRepository:target` |
| Carteira de pedidos (itens em aberto) | `TDashFatRepository:backlogWhere` |
| Quebras por cliente, produto, vendedor e UF | `TDashFatRepository:revenueBy` |
| Resultado: venda, custo, venda sem custo e impostos por dia (vendas e devoluções); CBS e IBS da F2D pela regra F2B | `TDashFatRepository:resultRows` e `reformTaxes` |
| Resultado: lucro bruto, impostos (PIS/COFINS ou CBS/IBS), lucro líquido, custo incompleto (> 2% sem custo, sem contar TES que não movimenta estoque) | `tdash.fat.u_resultSum`, `u_resultMonths`, `u_taxItems` (testadas) |

### Métodos da API (`TDashFatApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/fat/catalog |
| `getKpis()` | GET /tdash/v1/fat/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy Indicadores de período aceitam comparação; a carteira (fat.backlog) é posição de hoje |
| `getSeries()` | GET /tdash/v1/fat/series/fat.revenue?dateFrom&dateTo&grain=day\|week\|month Séries "revenue" (faturamento bruto) e "returns" (devoluções) no período |
| `getBreakdown()` | GET /tdash/v1/fat/breakdown/:id?top=10&dateFrom&dateTo Rankings de faturamento por cliente, produto, vendedor e UF |
| `getList()` | GET /tdash/v1/fat/list/fat.backlog?page=1&pageSize=20 Itens da carteira de pedidos, pela data de entrega |
| `kpiValue(cId as character, dFrom as date, dTo as date) as numeric` | Calcula o valor de um cartão |
| `resultRows(dFrom as date, dTo as date) as array` | Linhas do resultado do período, guardadas para os cartões da mesma requisição |
| `readRegime(oRequest as object, oHelper as object) as logical` | Lê `taxRegime` (current ou reform); responde 400 quando é inválido |
| `static fatCatalog() as array` | Catálogo do Faturamento: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashFatRepository`)

| Método | O que faz |
|---|---|
| `revenue(dFrom as date, dTo as date) as numeric` | Faturamento bruto do período |
| `invoiceCount(dFrom as date, dTo as date) as numeric` | Quantidade de notas fiscais (documento + série distintos) do período |
| `returns(dFrom as date, dTo as date) as numeric` | Devoluções de venda (notas de entrada tipo D) pelo valor bruto |
| `target(dFrom as date, dTo as date) as numeric` | Meta de vendas do período (SCT) |
| `revenueByDay(dFrom as date, dTo as date) as array` | Faturamento bruto por dia de emissão |
| `returnsByDay(dFrom as date, dTo as date) as array` | Devoluções por dia de digitação |
| `revenueBy(cDimension as character, dFrom as date, dTo as date, nTop as numeric) as array` | Faturamento bruto agrupado por cliente, produto, vendedor ou UF, do maior para o menor |
| `backlog() as numeric` | Carteira de pedidos: saldo (C6_QTDVEN - C6_QTDEMP - C6_QTDENT) x C6_PRCVEN dos itens em aberto (regra confirmada: encerrado quando C6_BLQ = 'R', faturado >= vendido ou saldo zero) |
| `backlogItems(nPage as numeric, nPageSize as numeric) as json` | Itens da carteira, pela data de entrega, paginados |
| `resultRows(dFrom as date, dTo as date) as array` | Resultado por dia: vendas (SD2) e devoluções (SD1) com venda, custo, venda sem custo e cada imposto |
| `reformTaxes(cTable as character) as character` | Subconsulta de CBS e IBS por item (F2D somada, tributo pelo `F2B_TRIB`) |
| `readResultRows(oQuery as object, cKind as character, aRows as array)` | Lê a consulta do resultado para as linhas |
| `salesFrom(cJoin as character) as character` | FROM/WHERE do faturamento, com um JOIN opcional de cadastro antes do SF4 |
| `bindSales(oQuery as object, dFrom as date, dTo as date)` | Binds de salesFrom sem JOIN de cadastro (posições 1 a 4) |
| `backlogWhere() as character` | WHERE da carteira em aberto |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |

## Compras — `COM`

- **Rotas:** `/tdash/v1/com/...`, com `x-erp-module: COM`.
- **Abas no app:** Compras · Pedidos · Solicitações · Acompanhamento.
- **Fontes:** `src/com/tdash.com.api.tlpp`, `src/com/tdash.com.repository.tlpp`, `src/com/tdash.com.rules.tlpp` (fator de moeda), `src/com/tdash.com.trace.tlpp` (acompanhamento).

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `com.purchases` | kpi, series | Valor comprado | `BRL` | `neutral` | 30 min |
| `com.po_open` | kpi, list | Pedidos de compra em aberto | `BRL` | `neutral` | 5 min |
| `com.po_late` | kpi, list | Pedidos com entrega atrasada | `BRL` | `down_is_good` | 5 min |
| `com.po_awaiting_approval` | kpi, list | Pedidos aguardando aprovação | `BRL` | `down_is_good` | 5 min |
| `com.pr_pending` | kpi, list | Itens de solicitação pendentes | `COUNT` | `down_is_good` | 5 min |
| `com.lead_time_request` | kpi | Prazo solicitação até pedido | `DAYS` | `down_is_good` | 12 h |
| `com.lead_time_delivery` | kpi | Prazo pedido até entrega | `DAYS` | `down_is_good` | 12 h |
| `com.top_suppliers` | breakdown | Maiores fornecedores | `BRL` | `neutral` | 30 min |
| `com.price_evolution` | series | Preço médio dos itens mais comprados | `BRL` | `down_is_good` | 12 h |
| `com.trace_requested` | kpi | Solicitado (a preço de pedido) | `BRL` | `neutral` | 30 min |
| `com.trace_ordered` | kpi | Virou pedido | `BRL` | `neutral` | 30 min |
| `com.trace_delivered` | kpi | Entregue (notas de entrada) | `BRL` | `neutral` | 30 min |
| `com.trace_unordered` | kpi | Itens de solicitação sem pedido | `COUNT` | `down_is_good` | 30 min |
| `com.trace` | series | Solicitado x pedido x entregue | `BRL` | `neutral` | 30 min |
| `com.trace_items` | list | Acompanhamento por item | `QTY` | `neutral` | 30 min |

**O que a tela chama**

- **Compras:**
  - `kpis` de `com.purchases`;
  - série `com.purchases` (série `purchases`);
  - `breakdown` de `com.top_suppliers`;
  - série `com.price_evolution` (últimos 6 meses, mensal, uma série por produto).
- **Pedidos:**
  - `kpis`: `com.po_open`, `com.po_late`, `com.po_awaiting_approval`, `com.lead_time_delivery`;
  - listas dos três primeiros.
- **Solicitações:** `kpis` de `com.pr_pending` e `com.lead_time_request`; lista `com.pr_pending`.
- **Acompanhamento:** `kpis` de `com.trace_requested`, `com.trace_ordered`, `com.trace_delivered` e `com.trace_unordered`
  (período = emissão da solicitação, aceitam comparação); série `com.trace` (últimos 6 meses, mensal, séries `requested`,
  `ordered`, `delivered`); lista `com.trace_items` (com `dateFrom` e `dateTo`).

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| O que é compra (`D1_TIPO = 'N'`, TES que gera duplicata, pela digitação) | `TDashComRepository:purchasesFrom` |
| Pedido em aberto, atrasado e aguardando aprovação | `TDashComRepository:ordersWhere` (escopos) |
| Solicitação pendente | `TDashComRepository:requestsWhere` |
| Prazos médios | `TDashComRepository:leadTimeRequest`, `leadTimeDelivery` e `averageDays` |
| Acompanhamento: ligações SC1 → SC7 → SD1, valores e percentuais | `TDashComRepository:traceRows` (consulta) e `tdash.com.u_traceItems` / `u_traceTotals` (regra, testada) |
| Valor do pedido em reais (moeda estrangeira) | `TDashComRepository:brlFactor` e `tdash.com.u_brlFactor` |

### Métodos da API (`TDashComApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/com/catalog |
| `getKpis()` | GET /tdash/v1/com/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy Valor comprado e prazos médios são de período e aceitam comparação; pedidos e solicitações em aberto são posição de hoje |
| `getSeries()` | GET /tdash/v1/com/series/:id?dateFrom&dateTo&grain=day\|week\|month com.purchases: valor comprado (série "purchases") |
| `getBreakdown()` | GET /tdash/v1/com/breakdown/com.top_suppliers?top=10&dateFrom&dateTo Maiores fornecedores pelo valor comprado no período |
| `getList()` | GET /tdash/v1/com/list/:id?page=1&pageSize=20 com.po_open, com.po_late, com.po_awaiting_approval: itens de pedidos em aberto |
| `kpiValue(cId as character, dFrom as date, dTo as date, dToday as date) as numeric` | Calcula o valor de um cartão |
| `static comCatalog() as array` | Catálogo de Compras: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashComRepository`)

| Método | O que faz |
|---|---|
| `purchases(dFrom as date, dTo as date) as numeric` | Valor comprado no período (D1_DTDIGIT) |
| `purchasesByDay(dFrom as date, dTo as date) as array` | Valor comprado por dia de digitação |
| `orders(cScope as character, dToday as date) as numeric` | Saldo em aberto dos pedidos de compra (quantidade pendente x preço) |
| `orderItems(cScope as character, dToday as date, nPage as numeric, nPageSize as numeric) as json` | Itens de pedidos de compra em aberto (mesmos escopos de orders), pela data de entrega |
| `pendingRequests() as numeric` | Quantidade de itens de solicitação de compra pendentes (sem pedido, sem resíduo eliminado) |
| `requestItems(nPage as numeric, nPageSize as numeric) as json` | Itens de solicitação de compra pendentes, da mais antiga para a mais recente |
| `leadTimeRequest(dFrom as date, dTo as date) as numeric` | Prazo médio (dias) entre a solicitação (C1_EMISSAO) e o pedido (C7_EMISSAO), para pedidos emitidos no período e originados de solicitação |
| `leadTimeDelivery(dFrom as date, dTo as date) as numeric` | Prazo médio (dias) entre o pedido (C7_EMISSAO) e a entrada da nota (D1_DTDIGIT), para notas digitadas no período e amarradas a pedido |
| `topSuppliers(dFrom as date, dTo as date) as array` | Valor comprado por fornecedor no período, do maior para o menor |
| `priceEvolution(dFrom as date, dTo as date, nTop as numeric) as array` | Preço médio ponderado (valor / quantidade) dos nTop produtos mais comprados no período, por dia de digitação |
| `purchasesFrom(cJoin as character) as character` | FROM/WHERE das compras, com um JOIN opcional de cadastro antes do SF4 |
| `ordersWhere(cScope as character) as character` | WHERE dos pedidos em aberto por escopo |
| `bindOrders(oQuery as object, nStart as numeric, cScope as character, dToday as date)` | Binds de ordersWhere a partir da posição nStart |
| `requestsWhere() as character` | WHERE das solicitações pendentes |
| `averageDays(cQry as character, aBinds as array) as numeric` | Média de dias (FIM - INICIO) ponderada pela quantidade de itens, de uma consulta agrupada com as colunas INICIO, FIM e QTD |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |

## Estoque e Custos — `EST`

- **Rotas:** `/tdash/v1/est/...`, com `x-erp-module: EST`.
- **Abas no app:** Valor · Reposição · Validade.
- **Fontes:** `src/est/tdash.est.api.tlpp`, `src/est/tdash.est.repository.tlpp`, `src/est/tdash.est.abc.tlpp`.

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `est.stock_value` | kpi, breakdown | Valor em estoque | `BRL` | `neutral` | 30 min |
| `est.below_reorder` | kpi, list | Produtos abaixo do ponto de pedido | `COUNT` | `down_is_good` | 5 min |
| `est.coverage_days` | kpi | Cobertura de estoque | `DAYS` | `neutral` | 12 h |
| `est.turnover` | kpi | Giro de estoque | `TIMES` | `up_is_good` | 12 h |
| `est.no_movement` | kpi, list | Itens sem movimento | `COUNT` | `down_is_good` | 12 h |
| `est.abc_curve` | breakdown | Curva ABC do estoque | `BRL` | `neutral` | 12 h |
| `est.lots_expiring` | kpi, list | Lotes vencidos ou a vencer | `COUNT` | `down_is_good` | 5 min |
| `est.cogs` | kpi, series | Custo da mercadoria vendida | `BRL` | `neutral` | 30 min |
| `est.avg_cost_evolution` | series | Custo médio dos itens de maior valor | `BRL` | `down_is_good` | 12 h |

**O que a tela chama**

- **Valor:**
  - `kpis`: `est.stock_value`, `est.cogs`, `est.turnover`;
  - `breakdown` de `est.stock_value` com `dimension=local|type|group`;
  - `breakdown` de `est.abc_curve` (3 itens, na ordem A, B, C);
  - séries `est.cogs` e `est.avg_cost_evolution` (6 meses, uma série por produto).
- **Reposição:** `kpis` de `est.below_reorder` e `est.coverage_days`; lista `est.below_reorder`.
- **Validade:** `kpis` de `est.lots_expiring` e `est.no_movement`; listas dos dois.

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| Saídas de venda que movimentam estoque (CMV e consumo) | `TDashEstRepository:outputsFrom` |
| Abaixo do ponto de pedido | `TDashEstRepository:belowReorderFrom` |
| Sem movimento (`MV_TDSEMMV`) | `TDashEstRepository:idleFrom` e `paramDays` na API |
| Lotes a vencer (`MV_TDVALID`) | `TDashEstRepository:lotsFrom` e `paramDays` na API |
| Cobertura e giro (fórmulas) | `TDashEstApi:kpiValue` |
| Curva ABC (80/15/5%) | `tdash.est.u_abcClassify` (`tdash.est.abc.tlpp`) |

### Métodos da API (`TDashEstApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/est/catalog |
| `getKpis()` | GET /tdash/v1/est/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy Só o CMV (est.cogs) é de período e aceita comparação; os demais são posição de hoje ou janelas fixas |
| `getSeries()` | GET /tdash/v1/est/series/:id?dateFrom&dateTo&grain=day\|week\|month est.cogs: série "cogs" (CMV) no período |
| `getBreakdown()` | GET /tdash/v1/est/breakdown/est.stock_value?dimension=local\|type\|group&top=10 GET /tdash/v1/est/breakdown/est.abc_curve Valor em estoque por armazém, tipo ou grupo; e curva ABC (A 80%, B 15%, C 5% do valor em estoque) |
| `getList()` | GET /tdash/v1/est/list/:id?page=1&pageSize=20 est.below_reorder, est.no_movement e est.lots_expiring |
| `kpiValue(cId as character, dFrom as date, dTo as date) as numeric` | Calcula o valor de um cartão |
| `static abcItems(aValues as array) as array` | Itens da curva ABC: classe, quantidade de produtos e valor em estoque de cada classe |
| `static paramDays(cParam as character, nDefault as numeric) as numeric` | Lê um parâmetro de dias (SX6) com padrão no código; fora de 1 a 3650 volta ao padrão |
| `static estCatalog() as array` | Catálogo de Estoque e Custos: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashEstRepository`)

| Método | O que faz |
|---|---|
| `stockValue() as numeric` | Valor total em estoque (B2_VATU1) de todos os armazéns |
| `stockQuantity() as numeric` | Quantidade total em estoque (B2_QATU) de todos os armazéns |
| `stockValueBy(cDimension as character) as array` | Valor em estoque agrupado por armazém, tipo ou grupo do produto, do maior para o menor |
| `stockByProduct() as array` | Valor em estoque de cada produto (soma dos armazéns), para a curva ABC |
| `belowReorder() as numeric` | Quantidade de produtos com saldo total (todos os armazéns) abaixo do ponto de pedido |
| `belowReorderItems(nPage as numeric, nPageSize as numeric) as json` | Produtos abaixo do ponto de pedido, da maior falta para a menor, paginados |
| `consumption(dFrom as date, dTo as date) as numeric` | Quantidade consumida no período: vendas que movimentam estoque (SD2) mais requisições (SD3, D3_CF = RE*) |
| `cogs(dFrom as date, dTo as date) as numeric` | Custo da mercadoria vendida (CMV) do período |
| `cogsByDay(dFrom as date, dTo as date) as array` | CMV por dia de emissão |
| `averageStock(dFrom as date, dTo as date) as numeric` | Estoque médio do período: média, entre as datas de fechamento do SB9, do valor inicial do mês (B9_VINI1) |
| `noMovement(dLimit as date) as numeric` | Quantidade de itens (produto x armazém) com saldo e sem movimentação desde a data limite |
| `noMovementItems(dLimit as date, nPage as numeric, nPageSize as numeric) as json` | Itens sem movimentação, do maior valor parado para o menor, paginados |
| `lotsExpiring(dLimit as date) as numeric` | Quantidade de lotes com saldo e validade até a data limite (inclui os já vencidos) |
| `lotsExpiringItems(dLimit as date, nPage as numeric, nPageSize as numeric) as json` | Lotes vencidos ou a vencer, pela validade, paginados |
| `avgCostEvolution(dFrom as date, dTo as date, nTop as numeric) as array` | Custo médio (B9_VINI1 / B9_QINI) por fechamento dos produtos de maior valor em estoque |
| `outputsFrom() as character` | FROM/WHERE das saídas de venda que movimentam estoque |
| `bindOutputs(oQuery as object, dFrom as date, dTo as date)` | Binds de outputsFrom (posições 1 a 4) |
| `belowReorderFrom() as character` | FROM/GROUP/HAVING dos produtos abaixo do ponto de pedido (saldo total dos armazéns) |
| `idleFrom() as character` | FROM/WHERE dos itens com saldo e sem movimentação |
| `lotsFrom() as character` | FROM/WHERE dos lotes com saldo e validade até a data limite |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |
| `pageResult(aItems as array, nTotal as numeric, nPage as numeric, nPageSize as numeric) as json` | Monta a resposta paginada { items, total, hasNext } |

### Regras puras (`tdash.est.abc.tlpp`)

| Função | O que faz |
|---|---|
| `u_abcClassify(aValues as array) as array` | Classifica valores de estoque em A, B e C pela participação acumulada (80% / 15% / 5%) |

## Produção — `PCP`

- **Rotas:** `/tdash/v1/pcp/...`, com `x-erp-module: PCP`.
- **Abas no app:** Visão geral · OPs · Apontamentos · Matéria-prima.
- **Fontes:** `src/pcp/tdash.pcp.api.tlpp`, `src/pcp/tdash.pcp.repository.tlpp`, `src/pcp/tdash.pcp.time.tlpp`,
  `src/pcp/tdash.pcp.material.tlpp`.

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `pcp.po_open` | kpi | OPs abertas | `COUNT` | `neutral` | 5 min |
| `pcp.po_late` | kpi, list | OPs atrasadas | `COUNT` | `down_is_good` | 5 min |
| `pcp.po_closed` | kpi | OPs encerradas | `COUNT` | `up_is_good` | 30 min |
| `pcp.plan_attainment` | kpi | Atingimento do plano | `PCT` | `up_is_good` | 30 min |
| `pcp.production_daily` | series | Produção | `QTY` | `up_is_good` | 5 min |
| `pcp.losses` | kpi, series | Perdas na produção | `PCT` | `down_is_good` | 30 min |
| `pcp.hours_by_resource` | breakdown | Horas por recurso | `HOURS` | `neutral` | 12 h |
| `pcp.hours` | kpi, series | Horas apontadas | `HOURS` | `neutral` | 30 min |
| `pcp.productivity` | breakdown | Produção por hora | `PER_HOUR` | `up_is_good` | 30 min |
| `pcp.top_products` | breakdown | Produtos mais produzidos | `QTY` | `neutral` | 30 min |
| `pcp.material_reserved` | kpi | Matéria-prima empenhada | `QTY` | `neutral` | 30 min |
| `pcp.material_consumed` | kpi | Matéria-prima consumida | `QTY` | `neutral` | 30 min |
| `pcp.material_produced` | kpi | Produzido nas OPs encerradas | `QTY` | `up_is_good` | 30 min |
| `pcp.material_loss` | kpi | Perda de material | `QTY` | `down_is_good` | 30 min |
| `pcp.material_loss_rate` | kpi | Perda de material (%) | `PCT` | `down_is_good` | 30 min |
| `pcp.material_returned` | kpi | Empenho devolvido ao estoque | `QTY` | `neutral` | 30 min |
| `pcp.material_loss_by_product` | breakdown | Perda de material por produto | `QTY` | `down_is_good` | 30 min |
| `pcp.material_orders` | list | Matéria-prima por OP | `QTY` | `neutral` | 30 min |

**O que a tela chama**

- **Visão geral:**
  - `kpis`: `pcp.plan_attainment`, `pcp.losses`, `pcp.po_open`, `pcp.po_late`;
  - séries `pcp.production_daily` (série `production`) e `pcp.losses` (série `losses`).
- **OPs:** `kpis` de `pcp.po_late`, `pcp.po_open`, `pcp.po_closed`; lista `pcp.po_late`.
- **Apontamentos:**
  - `kpis`: `pcp.hours`; série `pcp.hours` (séries `productive` e `unproductive`, barras empilhadas);
  - `breakdown` de `pcp.productivity` (PER_HOUR), `pcp.hours_by_resource` (HOURS) e `pcp.top_products` (QTY);
  - série `pcp.losses`.
- **Matéria-prima:** `kpis` de `pcp.material_reserved`, `pcp.material_consumed`, `pcp.material_produced`,
  `pcp.material_loss`, `pcp.material_loss_rate`, `pcp.material_returned` (as barras empenhado → consumido →
  produzido são montadas com esses cartões); `breakdown` de `pcp.material_loss_by_product` com `warnings`;
  lista `pcp.material_orders` com o período.

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| Só OPs firmes (`C2_TPOP = 'F'`) | `TDashPcpRepository:openOrders`, `closedOrders`, `planTotals` e `lateFrom` |
| Apontamentos de produção (`D3_CF` iniciando com `PR`, sem estorno) | `TDashPcpRepository:productionWhere` |
| Horas da SH6 ("HH:MM" em horas, normal ou centesimal) | `tdash.pcp.u_timeToHours` e `u_isCentesimal` (`tdash.pcp.time.tlpp`) |
| Hora produtiva × improdutiva (`H6_TIPO = 'I'`) | `TDashPcpRepository:timeEntries` |
| OPs do balanço (firmes, encerradas no período) e ligação SC2 × SD3/SD4 | `TDashPcpRepository:closedJoin` |
| Sem mão de obra; componente em outra unidade fica fora | `TDashPcpRepository:closedOrderMaterials` |
| Perda, devolvido e OPs fora da conta | `tdash.pcp.u_materialTotals` (`tdash.pcp.material.tlpp`) |

### Métodos da API (`TDashPcpApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/pcp/catalog |
| `getKpis()` | GET /tdash/v1/pcp/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy OPs encerradas, atingimento do plano e perdas aceitam comparação; OPs abertas e atrasadas são posição de hoje |
| `getSeries()` | GET /tdash/v1/pcp/series/:id?dateFrom&dateTo&grain=day\|week\|month pcp.production_daily: série "production" (quantidade produzida) |
| `getBreakdown()` | GET /tdash/v1/pcp/breakdown/:id?top=10&dateFrom&dateTo pcp.top_products: produtos mais produzidos |
| `getList()` | GET /tdash/v1/pcp/list/pcp.po_late?page=1&pageSize=20 OPs firmes abertas e atrasadas, da entrega mais antiga para a mais recente |
| `kpiValue(cId as character, dFrom as date, dTo as date) as numeric` | Calcula o valor de um cartão |
| `materials(dFrom as date, dTo as date) as array` | Balanço de matéria-prima das OPs encerradas, guardado para não repetir as consultas na mesma requisição |
| `static materialValue(cId as character, jTotals as json) as numeric` | Valor de um cartão de matéria-prima a partir dos totais |
| `static materialWarnings(jTotals as json) as array` | Avisos sobre o que ficou fora do balanço |
| `static lossByProduct(aOrders as array) as array` | Perda de material por produto |
| `static productivityRows(aEntries as array) as array` | Produção por hora produtiva de cada recurso |
| `static materialPage(aOrders as array, nPage as numeric, nPageSize as numeric) as json` | Página da lista de matéria-prima por OP |
| `static pcpCatalog() as array` | Catálogo da Produção: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashPcpRepository`)

| Método | O que faz |
|---|---|
| `openOrders() as numeric` | Quantidade de OPs firmes abertas |
| `lateOrders(dToday as date) as numeric` | Quantidade de OPs firmes abertas com entrega prevista anterior a hoje |
| `closedOrders(dFrom as date, dTo as date) as numeric` | Quantidade de OPs firmes encerradas no período (C2_DATRF) |
| `planTotals(dFrom as date, dTo as date) as array` | Quantidade planejada (C2_QUANT) e produzida (C2_QUJE) das OPs firmes com entrega prevista no período |
| `productionTotals(dFrom as date, dTo as date) as array` | Quantidade produzida (D3_QUANT) e perdida (D3_PERDA) nos apontamentos de produção do período |
| `productionByDay(dFrom as date, dTo as date) as array` | Produção e perda por dia de emissão |
| `topProducts(dFrom as date, dTo as date) as array` | Produtos mais produzidos no período, do maior para o menor |
| `hoursByResource(dFrom as date, dTo as date) as array` | Horas apontadas por recurso na SH6 no período (produtivas e improdutivas) |
| `timeEntries(dFrom as date, dTo as date) as array` | Apontamentos da SH6 somados por dia, recurso e tipo: { dia, recurso, rótulo, produtiva, horas, quantidade } |
| `closedOrderMaterials(dFrom as date, dTo as date) as array` | Produzido, empenhado e consumido de cada OP firme encerrada no período (json por OP) |
| `lateOrderItems(dToday as date, nPage as numeric, nPageSize as numeric) as json` | OPs firmes abertas e atrasadas, da entrega mais antiga para a mais recente, paginadas |
| `lateFrom() as character` | FROM/WHERE das OPs firmes abertas e atrasadas |
| `productionWhere() as character` | WHERE dos apontamentos de produção da SD3 (alias D3) |
| `bindProduction(oQuery as object, nFirst as numeric, dFrom as date, dTo as date)` | Binds de productionWhere a partir da posição indicada |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |
| `closedJoin(cOpField as character) as character` | JOIN com as OPs firmes encerradas no período pelo campo de OP (D3_OP, D4_OP) |
| `bindClosed(oQuery as object, dFrom as date, dTo as date)` | Binds de closedJoin (posições 1 a 3) |
| `mergeOrders(oQuery as object, aOrders as array, jIndex as json, cKey as character)` | Soma o resultado de uma consulta agrupada por OP no campo de cada OP |

### Regras puras (`tdash.pcp.time.tlpp` e `tdash.pcp.material.tlpp`)

| Função | O que faz |
|---|---|
| `u_timeToHours(cTime as character, lCentesimal as logical) as numeric` | Converte o tempo da SH6 (texto "HH:MM" ou "HHH:MM") em horas decimais, em minutos ou centésimos |
| `u_isCentesimal(nTimeType as numeric, cDefault as character) as logical` | `H6_TIPOTEM` 1 = normal, 2 = centesimal; sem ele vale o `MV_TPHR` |
| `u_materialTotals(aOrders as array) as json` | Soma produzido, empenhado e consumido das OPs e calcula perda e devolvido |
| `u_materialCounts(jOrder as json) as logical` | Diz se a OP entra no balanço (tem empenho ou consumo comparável) |
| `u_lossRate(nLoss as numeric, nConsumed as numeric) as numeric` | Perda em percentual do consumido |

## Livros Fiscais — `FIS`

- **Rotas:** `/tdash/v1/fis/...`, com `x-erp-module: FIS`.
- **Abas no app:** Visão geral · Centralização · Apuração · CFOP · Canceladas.
- **Fontes:** `src/fis/tdash.fis.api.tlpp`, `src/fis/tdash.fis.repository.tlpp`, `src/fis/tdash.fis.ledger.tlpp`
  (regras da centralização, testadas em `tests/fis/test_tdash_fis_ledger.tlpp`).

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `fis.icms_balance` | kpi, series | Saldo de ICMS (débito - crédito) | `BRL` | `neutral` | 12 h |
| `fis.ipi_balance` | kpi, series | Saldo de IPI (débito - crédito) | `BRL` | `neutral` | 12 h |
| `fis.pis_cofins` | kpi, series | Saldo de PIS e COFINS (débito - crédito) | `BRL` | `neutral` | 12 h |
| `fis.iss` | kpi | ISS das notas de serviço | `BRL` | `neutral` | 12 h |
| `fis.icms_st` | kpi | ICMS ST retido | `BRL` | `neutral` | 12 h |
| `fis.difal` | kpi | DIFAL | `BRL` | `neutral` | 12 h |
| `fis.by_cfop` | breakdown | Valor contábil por CFOP | `BRL` | `neutral` | 12 h |
| `fis.by_state` | breakdown | Saídas por UF | `BRL` | `neutral` | 12 h |
| `fis.cancelled` | kpi, list | Notas canceladas | `COUNT` | `down_is_good` | 12 h |
| `fis.tax_burden` | kpi | Carga tributária das saídas | `PCT` | `down_is_good` | 30 min |
| `fis.ledger_debit` | kpi | Débitos de tributos (sem CBS e IBS) | `BRL` | `neutral` | 30 min |
| `fis.ledger_credit` | kpi | Créditos de tributos (sem CBS e IBS) | `BRL` | `neutral` | 30 min |
| `fis.ledger_balance` | kpi | Saldo dos tributos (débito - crédito) | `BRL` | `neutral` | 30 min |
| `fis.ledger_trend` | series | Débitos x créditos de tributos | `BRL` | `neutral` | 30 min |
| `fis.ledger` | list | Centralização de débitos e créditos | `BRL` | `neutral` | 30 min |
| `fis.top_parties` | breakdown | Clientes e fornecedores por tributos | `BRL` | `neutral` | 30 min |
| `fis.top_ncm` | breakdown | NCM das saídas por tributos | `BRL` | `neutral` | 30 min |
| `fis.by_state_in` | breakdown | Entradas por UF | `BRL` | `neutral` | 12 h |

**O que a tela chama**

- **Visão geral:**
  - `kpis`: `fis.tax_burden`, `fis.ledger_balance`, `fis.ledger_debit`, `fis.ledger_credit`;
  - série `fis.ledger_trend`, 12 meses;
  - `breakdown` de `fis.by_state` ou `fis.by_state_in` (top 27, mapa), `fis.top_parties` e `fis.top_ncm` (top 10).
- **Centralização:** lista `fis.ledger` com `dateFrom`, `dateTo` e `scope=branch` ou `scope=all`.
- **Apuração:**
  - `kpis`: `fis.icms_balance`, `fis.ipi_balance`, `fis.pis_cofins`, `fis.iss`, `fis.icms_st`, `fis.difal`;
  - série mensal do imposto escolhido (`debit` e `credit`), 6 meses.
- **CFOP:** `breakdown` de `fis.by_cfop` (top 10) e `fis.by_state` (top 27).
- **Canceladas:** `kpis` de `fis.cancelled`; lista `fis.cancelled` **com** `dateFrom` e `dateTo`.

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| Débito (saídas CFOP 5, 6, 7) e crédito (entradas 1, 2, 3), sem canceladas | `TDashFisRepository:taxSql` |
| ISS (notas de serviço) | `TDashFisRepository:iss` |
| ICMS ST e DIFAL | `TDashFisRepository:sumField` |
| Canceladas (pela data de cancelamento, uma por nota) | `TDashFisRepository:cancelledFrom` |
| Centralização: débito e crédito de cada tributo por dia, somados no mês | `TDashFisRepository:ledgerMonths`, `reformSql`, `readLedger` |
| Tributos da centralização, total sem CBS e IBS, situação, carga tributária | `tdash.fis.u_ledgerTaxes`, `u_ledgerTotals`, `u_ledgerStatus`, `u_taxBurden` (testadas) |
| Tabela por filial e de todas as filiais | `u_ledgerLines`, `u_branchLines` (testadas); filiais do usuário em `userBranches` |
| Participantes e NCM por tributos | `TDashFisRepository:topParties`, `topNcm`; rótulo do NCM em `u_ncmLabel` |

### Métodos da API (`TDashFisApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/fis/catalog |
| `getKpis()` | GET /tdash/v1/fis/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy Todos os indicadores são de período e aceitam comparação |
| `getSeries()` | GET /tdash/v1/fis/series/:id?dateFrom&dateTo Débito e crédito do imposto por mês: séries "debit" (saídas) e "credit" (entradas) |
| `getBreakdown()` | GET /tdash/v1/fis/breakdown/:id?top=10&dateFrom&dateTo fis.by_cfop: valor contábil por CFOP |
| `getList()` | GET /tdash/v1/fis/list/fis.cancelled?dateFrom&dateTo&page=1&pageSize=20 Notas fiscais canceladas no período (pela data de cancelamento); GET /tdash/v1/fis/list/fis.ledger?dateFrom&dateTo&scope=branch\|all centralização de débitos e créditos |
| `ledger(dFrom as date, dTo as date) as array` | Centralização da filial do app por mês, guardada na requisição |
| `ledgerList(cScope as character, dFrom as date, dTo as date) as json` | Tabela da centralização (filial ou todas as filiais) |
| `static userBranches() as array` | Filiais da empresa do app liberadas ao usuário |
| `kpiValue(cId as character, dFrom as date, dTo as date) as numeric` | Calcula o valor de um cartão |
| `static fisCatalog() as array` | Catálogo de Livros Fiscais: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashFisRepository`)

| Método | O que faz |
|---|---|
| `taxTotals(cTax as character, dFrom as date, dTo as date) as array` | Débito (saídas) e crédito (entradas) de um imposto no período |
| `taxByDay(cTax as character, dFrom as date, dTo as date) as array` | Débito e crédito de um imposto por dia (a API agrupa em semanas ou meses) |
| `iss(dFrom as date, dTo as date) as numeric` | ISS do período: soma de F3_VALICM das notas de serviço (F3_TIPO = 'S'), sem as canceladas |
| `sumField(cField as character, dFrom as date, dTo as date) as numeric` | Soma de um campo do livro (F3_ICMSRET ou F3_DIFAL) no período, sem serviços e sem canceladas |
| `byCfop(dFrom as date, dTo as date) as array` | Valor contábil (F3_VALCONT) por CFOP no período, do maior para o menor, sem as canceladas |
| `byState(dFrom as date, dTo as date) as array` | Valor contábil das saídas (CFOP 5, 6 ou 7) por UF, do maior para o menor, sem as canceladas |
| `cancelled(dFrom as date, dTo as date) as numeric` | Quantidade de notas fiscais canceladas no período (pela data de cancelamento, F3_DTCANC) |
| `cancelledItems(dFrom as date, dTo as date, nPage as numeric, nPageSize as numeric) as json` | Notas canceladas no período, da mais recente para a mais antiga, paginadas |
| `taxSql(cTax as character, lByDay as logical) as character` | Consulta de débito e crédito de um imposto (3 binds: filial, data inicial, data final) |
| `taxTable(cTax as character) as character` | Tabela de origem do imposto (para a filial do bind) |
| `cancelledFrom() as character` | FROM/WHERE das notas canceladas (alias F3) |
| `bindPeriod(oQuery as object, cTable as character, dFrom as date, dTo as date)` | Binds filial + período (posições 1 a 3) de qualquer consulta deste repositório |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |

## Contabilidade — `CTB`

- **Rotas:** `/tdash/v1/ctb/...`, com `x-erp-module: CTB`.
- **Abas no app:** DRE · Balanço.
- **Fontes:** `src/ctb/tdash.ctb.api.tlpp`, `src/ctb/tdash.ctb.repository.tlpp`, `src/ctb/tdash.ctb.months.tlpp`, `src/ctb/tdash.ctb.rollup.tlpp`.

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `ctb.views` | list | Visões gerenciais | `COUNT` | `neutral` | 12 h |
| `ctb.view_lines` | list | Linhas da visão | `COUNT` | `neutral` | 12 h |
| `ctb.income_statement` | breakdown | DRE | `BRL` | `neutral` | 12 h |
| `ctb.balance_sheet` | breakdown | Balanço patrimonial | `BRL` | `neutral` | 12 h |

A Contabilidade publica só `catalog`, `breakdown` (DRE e Balanço) e `list` (visões e linhas, para as
Configurações). As rotas `kpis` e `series` ficam para a etapa 2.

**O que a tela chama**

- **Configurações:** lista `ctb.views` (`pageSize=100`) para o usuário escolher as visões.
- **DRE:** `breakdown` de `ctb.income_statement` com `view`, o período e `compare=prev`.
- **Balanço:** `breakdown` de `ctb.balance_sheet`, com os mesmos parâmetros.

Os itens trazem `level`, `kind` e `previous`, e a resposta traz `warnings`, `dateFrom`, `dateTo`, `compareFrom` e
`compareTo` (ver [02](02-contrato-de-resposta.md#get-módbreakdownid)).

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| Período em meses inteiros e comparação em meses | `tdash.ctb.u_monthPeriod` (`tdash.ctb.months.tlpp`) |
| Saldos por linha (CQ0 sem centro de custo, CQ2 com centro de custo; DRE sem apuração `LP` S e Z) | `TDashCtbRepository:balanceRows` e `accountBalances` |
| Sinal pela natureza da linha | `statementValues` em `tdash.ctb.api.tlpp` |
| Totalização da hierarquia (subtotais, natureza oposta subtrai) | `tdash.ctb.u_rollup` (`tdash.ctb.rollup.tlpp`) |
| Visões oferecidas (só as com linhas analíticas por faixa de conta) | `TDashCtbRepository:views` e `viewExists` |
| Sem visão ou visão desconhecida: `422` | `TDashCtbApi:configError` |

### Métodos da API (`TDashCtbApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/ctb/catalog |
| `getBreakdown()` | GET /tdash/v1/ctb/breakdown/ctb.income_statement?view=100&dateFrom&dateTo&compare=none\|prev\|yoy GET /tdash/v1/ctb/breakdown/ctb.balance_sheet?view=003&dateTo&compare=none\|prev\|yoy DRE: movimento do período, sem lançamentos de apuração |
| `getList()` | GET /tdash/v1/ctb/list/ctb.views?page=1&pageSize=50 GET /tdash/v1/ctb/list/ctb.view_lines?view=100 Apoio às Configurações do app: visões gerenciais calculáveis da filial e as linhas de uma visão |
| `configError(cMessage as character)` | Responde 422: a visão gerencial não foi escolhida ou não existe na filial |
| `static statementValues(oRepo as object, aLines as array, cView as character, cMode as character, dFrom as date, dTo as date) as array` | Valor, na natureza da linha, de cada linha da visão: saldo das analíticas totalizado pelas sintéticas |
| `static isoDate(dDate as date) as character` | Data no formato AAAA-MM-DD |
| `static ctbCatalog() as array` | Catálogo da Contabilidade: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashCtbRepository`)

| Método | O que faz |
|---|---|
| `views() as array` | Visões gerenciais da filial que têm linhas analíticas com faixa de conta (as demais, como o fluxo de caixa, não são calculáveis a partir dos saldos) |
| `viewExists(cView as character) as logical` | Diz se a visão existe na filial e é calculável (ver views) |
| `viewLines(cView as character) as array` | Linhas da visão na ordem de CTS_ORDEM, uma por CTS_CONTAG (as faixas de uma mesma linha são agrupadas) |
| `accountBalances(cView as character, cMode as character, dFrom as date, dTo as date) as array` | Débito e crédito de cada linha analítica da visão |
| `unsupportedLines(cView as character) as numeric` | Quantidade de linhas analíticas da visão que usam faixa de item contábil ou de classe de valor, ainda não calculadas |
| `balanceRows(lByCostCenter as logical, cView as character, cMode as character, dFrom as date, dTo as date) as array` | Uma passada de saldos: faixas sem centro de custo (CQ0) ou com centro de custo (CQ2) |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo |

### Regras puras (`tdash.ctb.months.tlpp`)

| Função | O que faz |
|---|---|
| `u_monthPeriod(dFrom as date, dTo as date, cCompare as character) as array` | Período das demonstrações em meses inteiros |

### Regras puras (`tdash.ctb.rollup.tlpp`)

| Função | O que faz |
|---|---|
| `u_rollup(aLines as array) as array` | Totaliza as linhas de uma Visão Gerencial |
| `static lineValue(aLines as array, nIdx as numeric, nDepth as numeric) as numeric` | Valor de uma linha: o saldo próprio (analítica) ou a soma das filhas com o sinal pela natureza (sintética) |
| `static lineLevel(aLines as array, nIdx as numeric) as numeric` | Nível de uma linha: quantas linhas superiores existem acima dela |

## Recursos Humanos — `GPE`

- **Rotas:** `/tdash/v1/gpe/...`, com `x-erp-module: GPE`.
- **Abas no app:** Quadro · Folha · Afastamentos.
- **Fontes:** `src/gpe/tdash.gpe.api.tlpp`, `src/gpe/tdash.gpe.repository.tlpp`, `src/gpe/tdash.gpe.rules.tlpp`.

### Catálogo

| id | Tipos | Título | Unidade | Sentido | Validade |
|---|---|---|---|---|---|
| `gpe.headcount` | kpi, breakdown | Funcionários ativos | `COUNT` | `neutral` | 12 h |
| `gpe.hires` | kpi | Admissões | `COUNT` | `neutral` | 12 h |
| `gpe.terminations` | kpi | Desligamentos | `COUNT` | `down_is_good` | 12 h |
| `gpe.turnover` | kpi | Turnover | `PCT` | `down_is_good` | 12 h |
| `gpe.movements` | series | Admissões e desligamentos | `COUNT` | `neutral` | 12 h |
| `gpe.absenteeism` | kpi, breakdown | Absenteísmo | `PCT` | `down_is_good` | 12 h |
| `gpe.payroll` | kpi, series | Folha de pagamento | `BRL` | `neutral` | 12 h |
| `gpe.payroll_by_cc` | breakdown | Folha por centro de custo | `BRL` | `neutral` | 12 h |
| `gpe.overtime` | kpi, series | Horas extras | `BRL` | `down_is_good` | 12 h |
| `gpe.overtime_hours` | kpi | Horas extras (horas) | `HOURS` | `down_is_good` | 12 h |
| `gpe.demographics` | breakdown | Perfil do quadro | `COUNT` | `neutral` | 12 h |
| `gpe.payroll_codes` | list | Verbas de provento | `COUNT` | `neutral` | 12 h |

No RH, os cartões são calculados pelo método privado `kpi`, que devolve o JSON pronto: ele precisa montar
`hidden` e o título com a competência.

**O que a tela chama**

- **Quadro:**
  - `kpis`: `gpe.headcount`, `gpe.hires`, `gpe.terminations`, `gpe.turnover`;
  - série `gpe.movements` (12 meses, `hires` e `terminations`);
  - `breakdown` de `gpe.headcount` (`dimension=cc|role`) e `gpe.demographics` (`dimension=age|tenure|sex`).
- **Folha:**
  - `kpis` de `gpe.payroll`, e de `gpe.overtime` e `gpe.overtime_hours` com `overtimeCodes` (só quando o usuário
    escolheu as verbas);
  - séries `gpe.payroll` e `gpe.overtime` (12 meses);
  - `breakdown` de `gpe.payroll_by_cc`.
- **Afastamentos:** `kpis` e `breakdown` de `gpe.absenteeism`.
- **Configurações:** lista `gpe.payroll_codes` (até 10 páginas de 100) para escolher as verbas de hora extra.

**LGPD:**

- Toda quebra passa por `tdash.gpe.u_lgpdGroups`: grupos com menos de `MV_TDMINGR` pessoas vão para "Outros", e
  "Outros" nunca fica abaixo do mínimo.
- Total abaixo do mínimo devolve `items` vazio e um aviso em `warnings`.
- Folha e hora extra de grupo pequeno saem com `hidden: true`.
- Não existe lista de pessoas. Não crie uma.

**Onde fica cada regra**

| Regra | Onde |
|---|---|
| Quem é ativo (admissão, demissão, categorias de `MV_TDCATEX`) | `TDashGpeRepository:activeWhere` e `bindActive` |
| Admissões e desligamentos (sem transferência RAIS 30 e 31) | `movementFrom` em `tdash.gpe.repository.tlpp` |
| Ausências que contam (RCM_TIPOAF 1 e 2) | `TDashGpeRepository:absences` |
| Dias de ausência no período | `tdash.gpe.u_absenceDays` |
| Folha (proventos da SRD, sem os roteiros de `MV_TDROTEX`) | `TDashGpeRepository:payrollFrom` |
| Competências fechadas e comparação | `tdash.gpe.u_payrollMonths` e `TDashGpeRepository:lastClosedMonth` |
| Horas extras (verbas do app; horas só de `RD_TIPO1 = 'H'`) | `overtimeFrom` e `TDashGpeRepository:overtime` |
| Faixas de idade e tempo de casa | `tdash.gpe.u_ageBand`, `u_tenureBand` |
| Turnover e absenteísmo (fórmulas) | `turnover` e `absenteeism` em `tdash.gpe.api.tlpp` |

### Métodos da API (`TDashGpeApi` e funções do fonte)

| Método | O que faz |
|---|---|
| `getCatalog()` | GET /tdash/v1/gpe/catalog |
| `getKpis()` | GET /tdash/v1/gpe/kpis?ids=a,b&dateFrom=AAAAMMDD&dateTo=AAAAMMDD&compare=none\|prev\|yoy&overtimeCodes=179,181 Quadro na data final; admissões, desligamentos, turnover e absenteísmo no período; folha e horas extras nas competências fechadas (u_payrollMonths) |
| `getSeries()` | GET /tdash/v1/gpe/series/:id?dateFrom&dateTo&grain=day\|week\|month[&overtimeCodes=...] gpe.movements: séries "hires" (admissões) e "terminations" (desligamentos) |
| `getBreakdown()` | GET /tdash/v1/gpe/breakdown/gpe.headcount?dimension=cc\|role&top=10&dateTo GET /tdash/v1/gpe/breakdown/gpe.demographics?dimension=age\|tenure\|sex&dateTo GET /tdash/v1/gpe/breakdown/gpe.absenteeism?dateFrom&dateTo&top=10 (dias por tipo de ausência) GET /tdash/v1/gpe/breakdown/gpe.payroll_by_cc?dateFrom&dateTo&top=10 (competências fechadas, em dateFrom/dateTo) Todos passam pelo agrupamento da LGPD (u_lgpdGroups); total abaixo do mínimo devolve lista vazia e um aviso |
| `getList()` | GET /tdash/v1/gpe/list/gpe.payroll_codes?page=1&pageSize=100 Verbas de provento, para escolher as de hora extra |
| `kpi(aDef as array, oPeriod as object, oRepo as object, aCodes as array, nMin as numeric, cTimestamp as character) as json` | Cartão de um indicador do RH, com comparação e proteção da LGPD |
| `configError(cMessage as character)` | Responde 422 quando falta um parâmetro que o usuário escolhe no app (verbas de hora extra) |
| `static minGroup() as numeric` | Tamanho mínimo de grupo da LGPD (MV_TDMINGR, padrão 5) |
| `static averageHeadcount(oRepo as object, dFrom as date, dTo as date) as numeric` | Quadro médio do período: média entre a véspera do início e o fim |
| `static turnover(oRepo as object, dFrom as date, dTo as date) as numeric` | Turnover (%): média de admissões e desligamentos ÷ quadro médio |
| `static absenteeism(oRepo as object, dFrom as date, dTo as date) as numeric` | Absenteísmo (%): dias de ausência no período ÷ (quadro médio × dias do período), em dias corridos |
| `static moneyValues(oRepo as object, cId as character, aCodes as array, cFrom as character, cTo as character) as array` | Valor e quantidade de pessoas de folha ou hora extra nas competências |
| `static demographicRows(aPeople as array, cDimension as character, dRef as date) as array` | Conta os ativos por faixa etária, tempo de casa ou sexo, na ordem das faixas |
| `static sexBand(cSex as character) as array` | Grupo por sexo (RA_SEXO) |
| `static absenceRows(aAbsences as array, dFrom as date, dTo as date) as array` | Dias de ausência no período por tipo, com a quantidade de pessoas de cada tipo |
| `static gpeCatalog() as array` | Catálogo do RH: { id, tipos, título, unidade, sentido, ttl } |

### Métodos do repositório (`TDashGpeRepository`)

| Método | O que faz |
|---|---|
| `headcount(dDate as date) as numeric` | Funcionários ativos na data: admitidos até ela e sem demissão (ou demitidos depois) |
| `headcountBy(cDimension as character, dDate as date) as array` | Ativos na data por centro de custo ou por função, do maior grupo para o menor |
| `activePeople(dDate as date) as array` | Nascimento, admissão e sexo dos ativos na data, para as faixas do perfil do quadro (sem identificação) |
| `movements(cEvent as character, dFrom as date, dTo as date) as numeric` | Admissões ou desligamentos no período (transferências entre filiais não contam como desligamento) |
| `movementsByDay(cEvent as character, dFrom as date, dTo as date) as array` | Admissões ou desligamentos por dia |
| `absences(dFrom as date, dTo as date) as array` | Ausências (afastamentos e outras ausências) que tocam o período, de pessoas fora das categorias excluídas |
| `lastClosedMonth(cUpTo as character) as character` | Última competência fechada (SRD) até a competência informada |
| `payroll(cFrom as character, cTo as character) as array` | Folha (proventos) das competências |
| `payrollByMonth(cFrom as character, cTo as character) as array` | Folha (proventos) por competência |
| `payrollByCc(cFrom as character, cTo as character) as array` | Folha (proventos) por centro de custo do lançamento |
| `overtime(aCodes as array, cFrom as character, cTo as character) as array` | Horas extras das verbas escolhidas pelo usuário, nas competências |
| `overtimeByMonth(aCodes as array, cFrom as character, cTo as character) as array` | Valor das horas extras por competência |
| `countCodes(aCodes as array) as numeric` | Quantas das verbas informadas existem na SRV da filial |
| `payrollCodes(nPage as numeric, nPageSize as numeric) as json` | Verbas de provento cadastradas (para o usuário escolher as de hora extra), paginadas |
| `activeWhere() as character` | WHERE dos ativos na data (alias RA) |
| `bindActive(oQuery as object, nBind as numeric, dDate as date) as numeric` | Binds de activeWhere a partir da posição nBind |
| `payrollFrom(lCostCenter as logical) as character` | FROM/WHERE da folha: proventos da SRD nas competências, fora os roteiros excluídos |
| `bindPayroll(oQuery as object, cFrom as character, cTo as character, lCostCenter as logical)` | Binds de payrollFrom, na ordem do SQL |
| `numberOf(cAlias as character, cField as character) as numeric` | Valor numérico de um campo da linha atual; 0 quando nulo (ex.: SUM sem linhas) |
| `static codeList(cValue as character) as array` | Lista "A,B,C" de um parâmetro em array; nunca vazia (um NOT IN vazio quebraria o SQL) |
| `static movementFrom(cEvent as character) as character` | FROM/WHERE de admissões ou desligamentos |
| `static bindMovement(oQuery as object, aCategories as array, dFrom as date, dTo as date)` | Binds de movementFrom |
| `static overtimeFrom() as character` | FROM/WHERE das horas extras |
| `static bindOvertime(oQuery as object, aCodes as array, aRoutines as array, cFrom as character, cTo as character)` | Binds de overtimeFrom |

### Regras puras (`tdash.gpe.rules.tlpp`)

| Função | O que faz |
|---|---|
| `u_lgpdGroups(aRows as array, nMin as numeric, nTop as numeric) as array` | Agrupamento com proteção da LGPD: nenhum grupo devolvido representa menos de nMin pessoas |
| `u_completedYears(dStart as date, dRef as date) as numeric` | Anos completos entre duas datas (idade, tempo de casa) |
| `u_ageBand(dBirth as date, dRef as date) as array` | Faixa etária |
| `u_tenureBand(dAdmission as date, dRef as date) as array` | Faixa de tempo de casa |
| `u_absenceDays(dStart as date, dEnd as date, dFrom as date, dTo as date) as numeric` | Dias corridos de uma ausência dentro do período |
| `u_monthShift(cMonth as character, nDelta as numeric) as character` | Soma (ou subtrai) meses de uma competência AAAAMM |
| `u_payrollMonths(cFrom as character, cTo as character, cLast as character, cCompare as character) as array` | Competências da folha |
| `u_monthLabel(cFrom as character, cTo as character) as character` | Rótulo de competências: "set/2026" ou "jul/2026 a set/2026" |
