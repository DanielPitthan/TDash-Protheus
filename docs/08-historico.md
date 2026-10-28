# 08 — Histórico de mudanças das APIs

Do mais recente para o mais antigo. Cada linha diz o que mudou para quem mantém os fontes. O porquê de cada regra
está no [catálogo de indicadores](10-catalogo-de-indicadores.md).

## 2026-10-28

| Módulo | Mudança |
|---|---|
| Todos | Fontes publicados neste repositório aberto, com o site de documentação em <https://danielpitthan.github.io/TDash-Protheus/> |

## 2026-10-27

| Módulo | Mudança | Fontes |
|---|---|---|
| EST + GPE | **Erro 500 na Reposição do Estoque**: contas com data passadas direto como parâmetro (`Date() - 90 + 1`) chegavam como número ("Mismatched parameters type ... expected D->N"). Trocadas por `DaySub`/`DaySum` no Estoque (cobertura, giro, sem movimento, lotes) e no RH (quadro médio) | `est/tdash.est.api`, `gpe/tdash.gpe.api` |
| FIS | **Visão geral e Centralização de débitos e créditos**: débito, crédito e saldo de ICMS, ICMS-ST, DIFAL/FCP, IPI, PIS, COFINS, ISS próprio, ISS retido, CBS e IBS (CBS/IBS fora do total), da filial ou de todas as filiais do usuário; carga tributária, débitos × créditos em 12 meses, saídas e entradas por UF, participantes e NCM por tributos | `fis/tdash.fis.ledger` (novo), `fis/tdash.fis.repository` (`ledgerMonths`, `topParties`, `topNcm`, `byState` com sentido), `fis/tdash.fis.api`; teste `tests/fis/test_tdash_fis_ledger` |

## 2026-10-26

| Módulo | Mudança | Fontes |
|---|---|---|
| FAT | **Custo incompleto sem TES que não movimenta estoque**: venda com `F4_ESTOQUE = 'N'` (energia, serviço, sucata) não conta mais como venda sem custo no aviso do Resultado; continua na venda e no lucro | `fat/tdash.fat.repository` (`resultRows`) |
| COM + núcleo | **Erro 500 no Acompanhamento**: a série `com.trace` passava texto para `u_mergeKeys` ("variable is not array"). Erro 500 e falha de consulta também no console.log (`ConOut`) | `com/tdash.com.api`, `core/tdash.core.responsehelper`, `core/tdash.core.query` |
| FAT | **Resultado: lucro bruto, lucro líquido e impostos**: cartões, série de 12 meses e impostos por tipo com **CBS e IBS separados** (F2D + F2B). Aviso de custo incompleto (> 2% da venda sem custo) | `fat/tdash.fat.result` (novo), `fat/tdash.fat.repository` (`resultRows`, `reformTaxes`), `fat/tdash.fat.api`; teste `tests/fat/test_tdash_fat_result` |

## 2026-10-25

| Módulo | Mudança | Fontes |
|---|---|---|
| COM | **Acompanhamento solicitado × pedido × entregue**: cartões em R$ (solicitado pelo preço do pedido, pedido em reais, entregue pelas notas), série mensal e lista por item com quantidades e percentuais. Ligação SC1 → SC7 por `C7_NUMSC`/`C7_ITEMSC`/produto e SC7 → SD1 por pedido, item, produto, fornecedor e loja | `com/tdash.com.trace` (novo), `com/tdash.com.repository` (`traceRows`), `com/tdash.com.api`; teste `tests/com/test_tdash_com_trace` |
| COM | **Pedido em moeda estrangeira em reais**: pedidos em aberto, atrasados e aguardando aprovação passam a multiplicar o preço pela taxa do pedido (`C7_TXMOEDA`, quando `C7_MOEDA > 1`). Antes um pedido em dólar entrava ~5 vezes menor | `com/tdash.com.repository`, `com/tdash.com.rules` (novo); teste `tests/com/test_tdash_com_rules` |

## 2026-10-23

| Módulo | Mudança | Fontes |
|---|---|---|
| Núcleo + custom | **Painel personalizado**: `TDashPanelBuilder` monta o JSON `{ title, ttl, widgets }`; exemplos `/custom/mock` (dados fictícios, modelo para copiar) e `/custom/exemplo` (consultas do Faturamento). Contrato em [09](09-painel-personalizado.md) | `core/tdash.core.panel` (novo), `custom/tdash.custom.mock`, `custom/tdash.custom.exemplo` (novos); teste `tests/core/test_tdash_core_panel` |
| Núcleo | **Acesso por módulo**: rota `/core/modules`; o app mostra só os módulos liberados na aba Menus do usuário e dos grupos. Diagnóstico `u_tdAcessoDiag` | `core/tdash.core.access` (novo), `core/tdash.core.api`, `tools/diagnostico-acesso`; teste `tests/core/test_tdash_core_access` |

## 2026-10-22

| Módulo | Mudança | Fontes |
|---|---|---|
| Núcleo, FIN, COM | `tdash.core.u_daysBetween` (diferença de datas com sinal) no lugar de "data menos data", que o linter recusa. Mesmo resultado | `core/tdash.core.params`, `fin/tdash.fin.repository`, `com/tdash.com.repository`; teste `tests/core/test_tdash_core_dates` |
| FIN | **Posição do cliente e do fornecedor** (como FINC010/FINC030): busca, em aberto, vencido, a vencer, limite e crédito disponível (`MV_CREDCLI`), recebido/pago (SE5), aging, títulos em aberto e cadastro por loja. Indicadores `fin.party_*`, atendidos por `TDashFinParty` | `fin/tdash.fin.party.api`, `.party.repository`, `.party.rules`, `fin/tdash.fin.api`; teste `tests/fin/test_tdash_fin_party` |
| PCP | **Horas apontadas** (produtivas × improdutivas) e **produção por hora** por recurso (unidade nova `PER_HOUR`). Tempo da SH6 lido como normal ou centesimal (`H6_TIPOTEM`/`MV_TPHR`). **Balanço de matéria-prima** das OPs encerradas: empenhado (SD4), consumido (SD3 RE − DE), produzido, perda de material e devolvido | `pcp/tdash.pcp.api`, `.repository`, `.time`, `.material` (novo); testes `tests/pcp/*` |
| GPE | `DateDiffDay` no lugar de data menos data; `if` no lugar de `IIf` | `gpe/*` |

## 2026-10-21

| Módulo | Mudança |
|---|---|
| Docs | Documentação técnica (`docs/`) e OpenAPI 1.1.0 |
| GPE | Recursos Humanos com LGPD (grupos mínimos e `hidden`) |
| CTB | Demonstrações em meses inteiros (`u_monthPeriod`) |

## Versões anteriores

| Etapa | Entrega |
|---|---|
| 5 | Contabilidade (DRE e Balanço pela visão gerencial) e Livros Fiscais |
| 4 | Estoque e Custos, Produção |
| 3 | Faturamento e Compras, lista genérica |
| 2 | Financeiro (piloto do padrão: catálogo, KPIs, séries, quebras, listas, cache) |
| 1 | Núcleo (`/core/branches`, `TDashQuery`, `TDashPeriod`, respostas e erros) |
