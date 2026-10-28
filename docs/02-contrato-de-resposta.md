# 02 — Contrato de resposta: o que o app espera

Este documento descreve, rota por rota, o JSON que o app TDash lê e o que ele faz com cada campo. Customizações
que mudam o formato descrito aqui quebram o app. Customizações que mudam só os **valores** (a regra de cálculo)
não quebram.

## Sumário

- [Requisição](#requisição)
- [Parâmetros](#parâmetros)
- [Regras gerais do JSON](#regras-gerais-do-json)
- [Unidades e sentido](#unidades-unit-e-sentido-direction)
- [GET /core/branches](#get-corebranches)
- [GET /core/modules](#get-coremodules)
- [GET /{mód}/catalog](#get-módcatalog)
- [GET /{mód}/kpis](#get-módkpis)
- [GET /{mód}/series/{id}](#get-módseriesid)
- [GET /{mód}/breakdown/{id}](#get-módbreakdownid)
- [GET /{mód}/list/{id}](#get-módlistid)
- [Erros](#erros)
- [Cache e validade](#cache-e-validade)
- [O que quebra o app](#o-que-quebra-o-app)

## Requisição

- **Método:** sempre `GET`.
- **Endereço:** `{endereço do REST configurado no app}/tdash/v1/{rota}`. Exemplo:
  `https://cliente.protheus.cloudtotvs.com.br:1557/api/tdash/v1/fin/kpis?...`
- **Tempo limite:** 30 segundos. Depois disso o app mostra "O servidor demorou para responder" e usa o cache, se
  houver.

Headers enviados em toda chamada:

| Header | Exemplo | Observação |
|---|---|---|
| `Authorization` | `Basic dXN1YXJpbzpzZW5oYQ==` | Usuário e senha do Protheus. A senha fica só em memória no app |
| `tenantid` | `01,1001` | Empresa e filial escolhidas pelo usuário (o código da filial exatamente como veio de `/core/branches`) |
| `x-erp-module` | `FIN` | Sigla do módulo da rota. As rotas `/core` usam `FAT` |
| `Accept` | `application/json` | |

| Módulo | Segmento da rota | `x-erp-module` |
|---|---|---|
| Financeiro | `fin` | `FIN` |
| Compras | `com` | `COM` |
| Faturamento | `fat` | `FAT` |
| Produção | `pcp` | `PCP` |
| Estoque e Custos | `est` | `EST` |
| Recursos Humanos | `gpe` | `GPE` |
| Contabilidade | `ctb` | `CTB` |
| Livros Fiscais | `fis` | `FIS` |

## Parâmetros

Todos vão na query string. Valor inválido responde `400` (`TDASH-400-PARAM`) com a mensagem do problema.

| Parâmetro | Rotas | Formato e limites | Padrão |
|---|---|---|---|
| `ids` | `kpis` | Ids separados por vírgula, de 1 a 20. Todos precisam estar no catálogo do módulo, senão `404` | — |
| `dateFrom`, `dateTo` | `kpis`, `series`, `breakdown`, listas de período | `AAAAMMDD`, data existente; `dateFrom` ≤ `dateTo`; no máximo 24 meses de calendário | 1º dia do mês atual e hoje (data do servidor) |
| `compare` | `kpis`, demonstrações da Contabilidade | `none`, `prev` ou `yoy` | `none` |
| `grain` | `series` | `day`, `week` ou `month` | `day` (RH: `month`) |
| `top` | `breakdown` | Inteiro de 1 a 50 | 10 |
| `dimension` | `breakdown` de alguns indicadores | Lista fechada por indicador (ver [04](04-modulos.md)) | A primeira da lista |
| `page`, `pageSize` | `list` | `page` ≥ 1; `pageSize` de 1 a 100 | 1 e 20 |
| `view` | Contabilidade | Código da visão gerencial (3 caracteres) | Obrigatório, senão `422` |
| `overtimeCodes` | `gpe.overtime`, `gpe.overtime_hours` | Até 30 verbas (`RV_COD`, 3 caracteres) separadas por vírgula | Obrigatório, senão `422` |

**O período que o app manda** é o intervalo de calendário da escolha no topo da tela:

| Escolha | `dateFrom` | `dateTo` |
|---|---|---|
| Dia | O dia | O dia |
| Mês | 1º dia do mês | Último dia do mês, mesmo que ainda não tenha chegado |
| Ano | 1º de janeiro | 31 de dezembro |

**Comparação:**

- `prev`: o período imediatamente anterior, com a mesma quantidade de **dias**. Para outubro inteiro, é de 31/08 a
  30/09.
- `yoy`: as mesmas datas do ano anterior.

As exceções são as que trabalham por **mês inteiro**, porque os saldos são mensais:

- **Demonstrações da Contabilidade:** ver [04](04-modulos.md#contabilidade--ctb).
- **Folha do RH:** ver [04](04-modulos.md#recursos-humanos--gpe).

As séries de alguns gráficos não usam o período do topo. O app pede um intervalo próprio, por exemplo os últimos 6
ou 12 meses, com `grain=month`.

## Regras gerais do JSON

- **Codificação:** UTF-8, com `Content-Type: application/json; charset=utf-8`. Use
  `oHelper:getResponse(jBody)`, que já faz o `EncodeUTF8`.
- **Nomes de campo:** use exatamente os do contrato, em camelCase (`value`, `generatedAt`, `hasNext`). O app até
  aceita outra caixa de letras, mas o contrato é este.
- **Números:**
  - número JSON (`1234.5`), não texto;
  - valores monetários e percentuais com 2 casas (`Round(nValor, 2)`);
  - percentual vai como número de 0 a 100 (`8.4` = 8,4%), não como fração.
- **Datas:**
  - texto `AAAA-MM-DD` (`Transform(DToS(dData), "@R 9999-99-99")`);
  - data/hora de geração: `AAAA-MM-DDThh:mm:ss` (`oHelper:timestamp()`).
- **Nulos:** só onde o contrato permite (por exemplo `compare`, `deltaPct`, `previous`). Data vazia em lista vai
  como `null`.
- **Campos extras:** o app ignora. Dá para incluir informação para outros consumidores sem quebrar o app.
- **Campos obrigatórios:** se faltar um, ou vier com o tipo errado, o app mostra "Resposta inválida do servidor.
  Confira se as APIs do TDash estão atualizadas no Protheus." e usa o último dado guardado.

## Unidades (`unit`) e sentido (`direction`)

| `unit` | Cartão (resumido) | Lista e detalhe (completo) |
|---|---|---|
| `BRL` | `R$ 1,28 mi`, `R$ 820 mil`, `R$ 9.500` | `R$ 48.300,00` |
| `PCT` | `8,4%` | `8,45%` |
| `DAYS` | `34 dias` (`1 dia`) | `34 dias` |
| `HOURS` | `12,5 h` | `1.240,5 h` |
| `TIMES` | `3,2x` | `3,2x` |
| `PER_HOUR` | `245,4/h`, `18 mil/h` | `1.245,38/h` |
| `QTY` | `48 mil` | `48.200,125` (até 3 casas) |
| `COUNT` | `1.284`, `15 mil` | `1.284` |

Uma unidade fora da lista aparece como número sem símbolo.

| `direction` | Cor da variação |
|---|---|
| `up_is_good` | Subir é verde, cair é vermelho |
| `down_is_good` | Cair é verde, subir é vermelho |
| `neutral` | Sempre cinza |

## GET /core/branches

Empresas e filiais do usuário. É a primeira chamada do login: se responder `401`, o app mostra "Usuário ou senha
inválidos". Se vier sem filiais, mostra "Seu usuário não tem acesso a nenhuma filial".

```json
{
  "items": [
    { "company": "01", "branch": "1001", "name": "MATRIZ", "companyName": "EMPRESA EXEMPLO S/A", "cnpj": "12345678000190" }
  ]
}
```

| Campo | Tipo | Uso no app |
|---|---|---|
| `items[].company` | texto | Empresa: primeira parte do `tenantid` |
| `items[].branch` | texto | Filial, **sem aparar espaços**: segunda parte do `tenantid` |
| `items[].name` | texto | Nome da filial na lista e no Início |
| `items[].companyName` | texto | Agrupamento da lista de filiais |
| `items[].cnpj` | texto | Exibido na lista de filiais |

## GET /core/modules

Módulos do TDash e se o usuário pode vê-los. É a segunda chamada do login, logo depois de `/core/branches`
(mesmos headers, `x-erp-module: FAT`, sem `tenantid`). O app mostra só os módulos com `allowed: true` em Módulos, no
Início e nos favoritos; rota direta para um módulo bloqueado volta para Módulos.

```json
{
  "items": [
    { "code": "FIN", "allowed": true },
    { "code": "COM", "allowed": false }
  ],
  "ttl": 300
}
```

| Campo | Tipo | Uso no app |
|---|---|---|
| `items[].code` | texto | Sigla do módulo (FIN, COM, FAT, PCP, EST, GPE, CTB, FIS). Sigla desconhecida é ignorada |
| `items[].allowed` | lógico | `true` = o módulo aparece no app |

- A regra fica em `tdash.core.u_userModules`: aba **Menus** do cadastro do usuário e dos grupos dele (ver
  [03](03-referencia-core.md#acesso-por-módulo-tdashcoreaccesstlpp)). Administrador vê todos.
- **É filtro de exibição, não segurança:** o REST do Protheus continua validando usuário, filial e módulo em cada
  chamada.
- Nenhum módulo liberado: o login para com "Seu usuário não tem acesso a nenhum módulo do TDash".
- Servidor sem esta rota (`404`, APIs anteriores a 23/10/2026): o app mostra todos os módulos, como antes.

## GET /{mód}/catalog

Indicadores publicados pelo módulo. **O app não usa esta rota hoje**: ela serve para o smoke test e para quem
quiser conferir o que o módulo oferece.

```json
{ "items": [ { "id": "fin.bank_balance", "kinds": ["kpi", "breakdown"], "title": "Saldo bancário", "unit": "BRL", "direction": "up_is_good", "ttl": 300 } ] }
```

## GET /{mód}/kpis

Cartões de indicadores. É uma chamada por grupo de cartões da tela.

```json
{
  "items": [
    {
      "id": "fin.receivable_overdue",
      "title": "A receber vencido",
      "unit": "BRL",
      "direction": "down_is_good",
      "value": 1284300.55,
      "compare": { "mode": "prev", "value": 1150000.00, "deltaPct": 11.68 },
      "generatedAt": "2026-10-21T10:15:00",
      "ttl": 300
    },
    {
      "id": "gpe.payroll",
      "title": "Folha de pagamento (set/2026)",
      "unit": "BRL",
      "direction": "neutral",
      "value": 0,
      "compare": null,
      "generatedAt": "2026-10-21T10:15:00",
      "ttl": 43200,
      "hidden": true
    }
  ]
}
```

| Campo | Tipo | Obrigatório | Uso no app |
|---|---|---|---|
| `items` | lista | sim | Um item por id pedido. A ordem não importa: o app procura cada cartão pelo `id` |
| `id` | texto | sim | Liga o valor ao cartão da tela. **Não mude o id de um indicador existente** |
| `title` | texto | sim | Texto do cartão, exibido como veio da API. Dá para acrescentar contexto, como "(set/2026)" ou "(sem consumo no período)" |
| `unit` | texto | sim | Formato do valor (ver [Unidades](#unidades-unit-e-sentido-direction)) |
| `direction` | texto | sim | Cor da variação |
| `value` | número | sim | Valor do cartão |
| `compare` | objeto ou `null` | sim | `null` quando não há comparação: o cartão mostra o texto de apoio da tela no lugar da variação |
| `compare.mode` | texto | sim | `prev` ou `yoy`; o app escreve "vs. período anterior" ou "vs. ano anterior" |
| `compare.value` | número | sim | Valor do período de comparação |
| `compare.deltaPct` | número ou `null` | sim | Variação %. `null` quando a base é zero: o cartão fica sem seta |
| `generatedAt` | texto | sim | Data/hora da geração no servidor |
| `ttl` | inteiro | sim | Validade em segundos. Na chamada inteira vale o **menor** `ttl` dos cartões |
| `hidden` | lógico | não | `true` quando o valor não pode ser mostrado (LGPD). O cartão mostra "—" e "Protegido pela LGPD" |

Monte cada item com `tdash.core.u_kpiItem(aDef, nValue, lCompare, cMode, nPrevious, cTimestamp)`. Ele preenche
todos os campos acima, menos `hidden`, e calcula o `deltaPct`.

**Atenção:** um id fora do catálogo faz a chamada inteira responder `404`: nenhum cartão do grupo recebe valor.

### `hidden` e LGPD

No RH, quando um valor de folha ou hora extra representa menos pessoas que `MV_TDMINGR`, a API devolve
`"value": 0`, `"compare": null` e `"hidden": true`. O app **nunca** mostra o valor de um cartão com
`hidden: true`.

## GET /{mód}/series/{id}

Pontos dos gráficos.

```json
{
  "id": "fin.cash_realized",
  "unit": "BRL",
  "grain": "day",
  "series": ["in", "out"],
  "points": [
    { "x": "2026-10-01", "y": 210000.00, "s": "in" },
    { "x": "2026-10-01", "y": 180500.10, "s": "out" },
    { "x": "2026-10-02", "y": 95000.00,  "s": "in" }
  ],
  "generatedAt": "2026-10-21T10:15:00",
  "ttl": 1800
}
```

| Campo | Tipo | Obrigatório | Uso no app |
|---|---|---|---|
| `id` | texto | sim | Conferência |
| `unit` | texto | sim | Informativo. A escala do eixo é definida pela tela |
| `grain` | texto | sim | `day`, `week` ou `month` |
| `series` | lista de texto | não | Nomes das séries. É **obrigatória** nas séries de produtos (`com.price_evolution`, `est.avg_cost_evolution`), em que o app monta um cartão por nome |
| `points` | lista | sim | Pontos, em ordem crescente de `x`. Lista vazia mostra "Nenhum … no período" |
| `points[].x` | texto | sim | Chave do eixo: `AAAA-MM-DD` para `day` e `week` (a segunda-feira da semana), `AAAA-MM` para `month`. O app escreve "22/10" ou "out/26" |
| `points[].y` | número | sim | Valor |
| `points[].s` | texto | sim | Nome da série. **Precisa ser exatamente o nome que a tela procura** (tabela abaixo) |
| `generatedAt`, `ttl` | | sim | Como em `kpis` |

Use `tdash.core.u_groupRows(aLinhas, cGrain)` para agrupar linhas `{ data AAAAMMDD, valor }` na chave certa e
`tdash.core.u_jsonPoint(cX, nY, cSerie)` para cada ponto. O app **não** preenche dias sem movimento: o dia sem
ponto não aparece no gráfico.

**Nomes de série que o app procura:**

| Indicador | Séries (`s`) |
|---|---|
| `fin.cashflow_projection` | `receivable`, `payable`, `balance` |
| `fin.cash_realized` | `in`, `out` |
| `fat.revenue` | `revenue`, `returns` |
| `com.purchases` | `purchases` |
| `com.price_evolution` | Uma por produto: o nome é o rótulo exibido ("MP0001 RESINA") |
| `est.cogs` | `cogs` |
| `est.avg_cost_evolution` | Uma por produto: o nome é o rótulo exibido |
| `pcp.production_daily` | `production` |
| `pcp.losses` | `losses` |
| `fis.icms_balance`, `fis.ipi_balance`, `fis.pis_cofins` | `debit`, `credit` |
| `gpe.movements` | `hires`, `terminations` |
| `gpe.payroll` | `payroll` |
| `gpe.overtime` | `overtime` |

## GET /{mód}/breakdown/{id}

Composições e rankings, exibidos em barras horizontais. A Contabilidade usa a mesma rota para a DRE e o Balanço.

```json
{
  "id": "fin.top_debtors",
  "unit": "BRL",
  "items": [
    { "key": "000123", "label": "COMERCIAL ALFA", "value": 212000.00, "share": 0.4021 },
    { "key": "others", "label": "Outros (12)",   "value": 64000.00,  "share": 0.1214 }
  ],
  "generatedAt": "2026-10-21T10:15:00",
  "ttl": 1800
}
```

| Campo | Tipo | Obrigatório | Uso no app |
|---|---|---|---|
| `id`, `unit` | texto | sim | Conferência. A unidade das barras é definida pela tela |
| `items` | lista | sim | Barras, **na ordem recebida** (a API ordena). Lista vazia mostra o texto de "nada a mostrar" da tela |
| `items[].key` | texto | sim | Chave do grupo. `others` é a convenção para o grupo "Outros" |
| `items[].label` | texto | sim | Rótulo da barra (cortado com "…" se for longo) |
| `items[].value` | número | sim | Tamanho da barra, proporcional ao maior valor absoluto, e valor exibido |
| `items[].share` | número | sim | Participação de 0 a 1 (`u_applyShares`). O app não usa hoje; mantenha para compatibilidade |
| `items[].level` | inteiro | não | Só demonstrações: nível na hierarquia (0 = topo) |
| `items[].kind` | texto | não | Só demonstrações: `detail`, `subtotal` ou `total` |
| `items[].previous` | número ou `null` | não | Só demonstrações com comparação: valor do período anterior |
| `warnings` | lista de texto | não | Avisos mostrados acima das barras (Contabilidade e RH), por exemplo "Menos de 5 pessoas: dados protegidos pela LGPD." |
| `dateFrom`, `dateTo` | texto `AAAA-MM-DD` | não | Período efetivo usado, quando é diferente do pedido. O app mostra os meses ("outubro/2026") |
| `compareFrom`, `compareTo` | texto `AAAA-MM-DD` | não | Período efetivo da comparação (demonstrações) |
| `generatedAt`, `ttl` | | sim | Como em `kpis` |

**Cores por posição:** em alguns gráficos a cor da barra depende da **posição** do item, e não da chave.

- Faixas de atraso: 5 faixas, da menor para a maior.
- Curva ABC: 3 itens, na ordem A, B, C.

Mantenha a quantidade e a ordem desses itens.

**Demonstrações (DRE e Balanço):** cada item é uma linha da visão gerencial, na ordem da visão.

- **Resumo:** só `subtotal` e `total`.
- **Detalhado:** tudo, menos as linhas `detail` zeradas nos dois períodos.
- **Recuo:** na DRE, o recuo vem do `kind`; no Balanço, do `level`.

## GET /{mód}/list/{id}

Detalhe paginado, exibido como cartões, com "Carregar mais" no fim.

```json
{
  "columns": [
    { "key": "document", "label": "Título",     "type": "text" },
    { "key": "party",    "label": "Cliente",    "type": "text" },
    { "key": "dueDate",  "label": "Vencimento", "type": "date" },
    { "key": "daysLate", "label": "Atraso",     "type": "DAYS" },
    { "key": "balance",  "label": "Saldo",      "type": "BRL" }
  ],
  "items": [
    { "document": "NF 001234/1", "party": "COMERCIAL ALFA", "dueDate": "2026-08-10", "daysLate": 72, "balance": 48300.00 }
  ],
  "total": 37,
  "hasNext": true
}
```

| Campo | Tipo | Obrigatório | Uso no app |
|---|---|---|---|
| `columns` | lista | sim | Define o que aparece e como cada valor é formatado |
| `columns[].key` | texto | sim | Nome do campo em cada item |
| `columns[].label` | texto | sim | Rótulo exibido |
| `columns[].type` | texto | sim | `text`, `date` (`AAAA-MM-DD` → `dd/mm/aaaa`) ou uma unidade (`BRL`, `QTY`, `DAYS`, `COUNT`, `PCT`, `HOURS`, `PER_HOUR`), formatada como valor completo |
| `items` | lista | sim | Um objeto por linha, com os campos de `columns`. Valor vazio (`null` ou ausente) aparece como "—" |
| `total` | inteiro | sim | Total de linhas, exibido no topo ("37 títulos") |
| `hasNext` | lógico | sim | `true` mostra "Carregar mais" e pede `page + 1` |

**Como o app monta cada cartão da lista:**

- **Título do cartão:** as colunas `document` e `party`, juntas com " · ".
- **Linhas abaixo do título:** as outras colunas `text`.
- **Pares rótulo/valor, dois por linha:** as colunas que não são `text` (datas e números).
- **Cor da faixa lateral:**
  - Com a coluna numérica `daysLate`: mais de 60 dias é vermelho, qualquer atraso é âmbar, sem atraso é azul.
  - Sem `daysLate`, nas listas em que o app trata `dueDate` como prazo (vencimento, entrega), os dias desde
    `dueDate` até hoje fazem o mesmo papel.

Use `tdash.core.u_jsonColumn(cKey, cLabel, cType)` para cada coluna. O título, os textos e a ordem de cada lista
conhecida ficam no app. Uma lista nova funciona, mas com textos genéricos ("Detalhes",
"itens") até o app registrá-la.

Listas não têm `ttl`: o app sempre pede de novo ao servidor e só usa a cópia guardada quando o servidor falha.

## Erros

Todo erro vem no modelo TOTVS. Monte com `oHelper:getErrorResponse(cCode, cMessage, cDetail)` ou com os atalhos
`badRequest`, `notFound` e `serverError`.

```json
{ "code": "TDASH-422-CONFIG", "message": "Escolha as verbas de hora extra nas Configurações do app.", "detailedMessage": "Configure as verbas em Configurações > Parâmetros dos indicadores.", "helpUrl": "" }
```

| Status | `code` | Quando | O que o app faz |
|---|---|---|---|
| `400` | `TDASH-400-PARAM` | Parâmetro inválido (`oHelper:badRequest`) | Mostra o `message` no aviso de erro da tela |
| `401` | (do REST) | Usuário ou senha recusados | "Usuário ou senha inválidos." No login, não entra |
| `403` | (do REST) | Sem acesso ao módulo ou à filial | Mostra o `message`, ou "Usuário sem permissão para esta consulta." |
| `404` | `TDASH-404-INDICATOR` | Id fora do catálogo (`oHelper:notFound`) | Mostra o `message`. Sem `message` no corpo (rota inexistente, fonte não compilado): "As APIs do TDash não foram encontradas neste servidor" |
| `422` | `TDASH-422-CONFIG` | Falta uma configuração que o usuário faz no app (visão gerencial, verbas) | Mostra o `message`. As telas de Contabilidade e RH já mostram o cartão "Configure…" antes de chamar |
| `500` | `TDASH-500` | Erro inesperado (`oHelper:serverError`) | Mostra o `message` e usa o último dado guardado, marcado como desatualizado |
| outros | | | "O servidor Protheus respondeu com erro (código)." |

O app mostra o **`message`**. Escreva para o usuário final, em português, sem jargão técnico. O
`detailedMessage` é uma dica de ação; detalhe técnico vai para o log (`serverError` registra com `FWLogMsg`).

## Cache e validade

- **Validade:** vem do campo **`ttl` do corpo da resposta**, não do header:
  - `series` e `breakdown` usam o `ttl` da raiz;
  - `kpis` usa o menor `ttl` dos itens;
  - `list` e `core/branches` não têm `ttl`, então valem zero segundos.
- **Header:** a API também manda `Cache-Control: private, max-age={ttl}` (`oHelper:setCacheHeaders`) para outros
  consumidores. O app não depende dele.
- **Chave do cache:** servidor + empresa + filial + módulo + rota com todos os parâmetros.
- **Dentro da validade:** o app usa a cópia guardada e não chama o servidor. O botão "atualizar" força uma nova
  chamada.
- **Servidor fora ou erro:** o app mostra a última cópia guardada com o aviso "Sem conexão com o Protheus. Mostrando
  dados de dd/mm hh:mm".
- **Limpeza:** cópias com mais de 7 dias são apagadas. Logout e troca de servidor apagam tudo.

Consequência para a customização: depois de publicar uma mudança de regra, o app só vê o novo valor quando a
validade vence ou quando o usuário toca em "atualizar".

## O que quebra o app

| Se a API… | No app… |
|---|---|
| Mudar o `id` de um indicador que a tela pede | A chamada responde `404`: os cartões do grupo ficam sem valor e a tela mostra o erro |
| Tirar um campo obrigatório ou mudar o tipo (texto no lugar de número) | "Resposta inválida do servidor", e o app usa o cache |
| Mudar o nome de uma série (`s`) | O gráfico fica vazio |
| Mudar a quantidade ou a ordem das faixas de atraso ou da curva ABC | As cores das barras ficam trocadas |
| Devolver percentual como fração (0,084) | O cartão mostra "0,1%" no lugar de "8,4%" |
| Devolver data fora de `AAAA-MM-DD` | A data aparece crua, sem formatação |
| Mandar `hasNext: true` sem ter próxima página | "Carregar mais" traz página vazia |
| Mandar o valor de um grupo pequeno no RH | Expõe dado pessoal. Use `hidden` e `u_lgpdGroups` |
| Responder 500 com SQL no `message` | O usuário vê detalhe técnico. Use `serverError`, que só registra no log |
