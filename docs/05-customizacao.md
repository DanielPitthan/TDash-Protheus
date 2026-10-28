# 05 — Customização

Receitas para as mudanças mais comuns. Antes de cada uma, veja na [04](04-modulos.md) o fonte e o método da
regra, e na [02](02-contrato-de-resposta.md) o formato que o app espera.

## Antes de começar

- **Editor:** TDS-VSCode, com a codificação do arquivo em **Windows 1252**. O Git entrega os `.tlpp` em CP1252 com
  CRLF (ver [01](01-arquitetura.md#convenções-de-código)).
- **Ordem de compilação:** `src/core` primeiro, depois os módulos. Mudou só um módulo? Compile só a pasta dele.
- **Ambiente:** teste em homologação antes de produção. O smoke test (`tools/smoke-test.ps1`)
  confere as rotas em minutos.
- **Documentação:** mudou uma regra de negócio? Atualize também [`10-catalogo-de-indicadores.md`](10-catalogo-de-indicadores.md), para a próxima
  pessoa saber o porquê.

## O que exige nova versão do app

| Mudança | Só TLPP | TLPP + app |
|---|---|---|
| Regra de cálculo de um indicador existente | ✔ | |
| Título, unidade, sentido ou validade de um **cartão** | ✔ | |
| Colunas, rótulos ou tipos de uma **lista** existente | ✔ | |
| Novo `dimension` num `breakdown` que a tela já usa | | ✔ (o botão da quebra fica na tela) |
| Indicador novo (cartão, gráfico, barras ou lista) | | ✔ |
| Novo nome de série num gráfico | | ✔ |
| Parâmetro que o usuário escolhe no app | | ✔ |
| Módulo novo | | ✔ |
| **Painel personalizado** (KPIs, colunas, barras e tabelas montados pelo app) | ✔ ([09](09-painel-personalizado.md)) | |

Para um processo customizado do cliente, o caminho mais curto é um **painel personalizado**: um endpoint que devolve
o JSON de [09](09-painel-personalizado.md), cadastrado pelo usuário no app. Comece copiando
`src/custom/tdash.custom.mock.tlpp`.

## 1. Mudar a regra de um indicador existente

Exemplo: o cliente quer que o faturamento conte também as notas de complemento de preço (`D2_TIPO = 'C'`).

1. **Ache a regra.** Na [04](04-modulos.md#faturamento--fat), o faturamento está em
   `TDashFatRepository:salesFrom`.
2. **Mude o SQL**, mantendo os binds na mesma ordem:

   ```
   // antes
   cFrom += " AND D2.D2_TIPO = 'N' "
   // depois
   cFrom += " AND D2.D2_TIPO IN ('N', 'C') "
   ```

   O `salesFrom` é usado por faturamento, ticket médio, série e rankings. A mudança vale para todos eles, e é o que
   se quer aqui. Se a regra valesse só para um indicador, crie um método novo em vez de mudar o compartilhado.
3. **Se a regra vier de fora do código** (como um valor que muda por cliente), não deixe o valor fixo: use um
   parâmetro (receita 6) e passe por bind.
4. **Compile** `src/fat`, rode o smoke test com `-Module FAT` e confira o valor contra o relatório padrão do
   Protheus.
5. **Documente** a decisão no catálogo de indicadores.

O app só vê o valor novo quando a validade do cache vence, ou quando o usuário toca em "atualizar".

## 2. Mudar título, unidade, sentido ou validade de um cartão

Tudo isso está na linha do catálogo do módulo (função estática `<mód>Catalog()` no fonte da API):

```
{ "fat.revenue", { "kpi", "series" }, "Faturamento bruto", "BRL", "up_is_good", TTL_OP }
//  id (não mude)   tipos               título exibido       unid.   sentido       validade
```

- **Título:** aparece no cartão exatamente como está aqui.
- **Unidade:** muda o formato do valor (`BRL`, `PCT`, `DAYS`, `HOURS`, `PER_HOUR`, `TIMES`, `QTY`, `COUNT`).
- **Sentido:** muda a cor da variação.
- **Validade:** muda de quanto em quanto tempo o app volta ao servidor.
- **Cuidado com a unidade:** se ela mudar, o **valor** precisa estar na nova unidade. Por exemplo, `PCT` exige um
  número de 0 a 100.

## 3. Criar um cartão (KPI) novo num módulo existente

Exemplo completo: **quantidade vendida** no Faturamento (`fat.items_sold`, Σ `D2_QUANT` das mesmas notas do
faturamento).

### 3.1 Catálogo (`src/fat/tdash.fat.api.tlpp`, função `fatCatalog`)

Acrescente a linha. O id segue o padrão `<mód>.<nome_em_ingles>`:

```
    { "fat.items_sold",       { "kpi" },             "Quantidade vendida",     "QTY",   "up_is_good",   TTL_TAT },;
```

A última linha da lista não leva vírgula depois do `}`. Confira o fechamento `}` da função.

### 3.2 Cálculo (`TDashFatApi:kpiValue`)

```
        case cId == "fat.items_sold"
            nValue := oRepo:itemsSold(dFrom, dTo)
```

`kpiValue` recebe o período já validado. Com `compare=prev` ou `yoy`, a API chama `kpiValue` de novo com o período
de comparação e monta a variação sozinha (`u_kpiItem`).

### 3.3 Consulta (`src/fat/tdash.fat.repository.tlpp`)

Declare o método na classe:

```
    public method itemsSold(dFrom as date, dTo as date) as numeric
```

E implemente reaproveitando o `FROM`/`WHERE` do faturamento:

```
/*/{Protheus.doc} itemsSold
Quantidade vendida no período (D2_QUANT), com o mesmo filtro do faturamento (salesFrom).
@type method
@author <seu nome>
@since <data>
@param dFrom, date, início (D2_EMISSAO)
@param dTo, date, fim
@return numeric, quantidade
/*/
method itemsSold(dFrom as date, dTo as date) as numeric class TDashFatRepository
    local nTotal := 0 as numeric
    local oQuery as object

    oQuery := tdash.core.TDashQuery():new(" SELECT SUM(D2.D2_QUANT) TOTAL " + ::salesFrom(""))
    ::bindSales(oQuery, dFrom, dTo)
    if oQuery:open()
        nTotal := ::numberOf(oQuery:getAlias(), "TOTAL")
        oQuery:close()
    endIf
return nTotal
```

### 3.4 Teste da API

```bash
curl -u USUARIO:SENHA -H "x-erp-module: FAT" -H "tenantid: 01,1001" "https://<servidor>/api/tdash/v1/fat/kpis?ids=fat.items_sold&dateFrom=20261001&dateTo=20261031&compare=prev"
```

Esperado: `200` com um item `{"id":"fat.items_sold","title":"Quantidade vendida","unit":"QTY",...}`. Acrescente a
chamada no smoke test (receita 9).

### 3.5 Cartão no app

Exibir o indicador num painel padrão do app exige uma versão nova do app: peça pelas issues do GitHub ou pelo e-mail administrativo@azsistemas.tech. Sem esperar, mostre o indicador num [painel personalizado](09-painel-personalizado.md).

**Importante:** publique a API **antes** do app. Um app novo pedindo um id que a API ainda não tem recebe `404`:
os cartões daquele grupo ficam sem valor e a tela mostra o erro.

## 4. Criar uma quebra (barras) ou uma série (gráfico)

**Quebra:**

- Marque o tipo `breakdown` no catálogo.
- Trate o id em `getBreakdown`.
- Devolva `{ key, label, value }` com as funções do núcleo:

```
aItems := tdash.core.u_rowsToItems(oRepo:salesByCity(oPeriod:dFrom, oPeriod:dTo))   // { { chave, rótulo, valor } }
aItems := tdash.core.u_applyShares(tdash.core.u_topWithOthers(aItems, nTop, "Outros"))
```

Com mais de uma quebra (`dimension`):

- valide os valores aceitos e responda `400` para os outros (veja `est.stock_value`);
- trate a quebra padrão quando `dimension` vier vazio.

**Série:**

- Marque o tipo `series` no catálogo.
- Trate o id em `getSeries`.
- Agrupe as linhas `{ data AAAAMMDD, valor }` com `u_groupRows(aLinhas, cGrain)` e monte os pontos com
  `u_jsonPoint(chave, valor, "<nome>")`.
- O nome da série (`s`) é o que o app vai procurar. Escolha um nome curto em inglês e não mude depois.

Nos painéis padrão, barras e gráficos novos precisam de uma versão nova do app. Num painel personalizado, use `addBarChart` e `addColumnChart` ([09](09-painel-personalizado.md)).

## 5. Criar uma lista (detalhe paginado)

1. **Catálogo:** marque o tipo `list`.
2. **`getList`:** defina as colunas com `u_jsonColumn` e chame um método do repositório que devolva
   `{ items, total, hasNext }`.
3. **Colunas:** use `document` e `party` para o título do cartão. Use `dueDate` (data) ou `daysLate` (dias) quando
   o atraso deve pintar a faixa lateral.
4. **Paginação:** siga o padrão dos repositórios:
   - conte o total com `COUNT(*)`;
   - na consulta dos itens, pule `(nPage - 1) * nPageSize` registros com `DbSkip`;
   - leia até `nPageSize` itens;
   - `hasNext := (nPage * nPageSize) < nTotal`.
5. **Valores:**
   - datas em `AAAA-MM-DD` (`Transform(cData, "@R 9999-99-99")`);
   - data vazia como `Nil`;
   - números arredondados.
6. **App:** sem registro no app, uma lista nova aparece com textos genéricos ("Detalhes", "itens"). Exibir o indicador num painel padrão do app exige uma versão nova do app: peça pelas issues do GitHub ou pelo e-mail administrativo@azsistemas.tech. Sem esperar, mostre o indicador num [painel personalizado](09-painel-personalizado.md).

## 6. Criar um parâmetro do Protheus (`MV_TD...`)

Use quando a regra muda de cliente para cliente e quem decide é a TI ou a área, não o usuário do app.

```
static function minDays() as numeric
    local nDays := Val(cValToChar(SuperGetMV("MV_TDXXXXX", .F., 30))) as numeric

    if nDays < 1 .or. nDays > 3650
        nDays := 30
    endIf
return nDays
```

- **Padrão no código:** sempre tenha um valor padrão. O parâmetro só precisa existir no SX6 para mudar o padrão.
- **Faixa:** valide a faixa e volte ao padrão se vier lixo.
- **Listas:** para listas ("A,P"), quebre com `StrTokArr2` e passe por `setIn`. Nunca concatene no SQL. Veja
  `codeList` no repositório do RH.
- **Documentação:** registre o parâmetro na tabela da [01](01-arquitetura.md#parâmetros-do-protheus-sx6), no
  catálogo de indicadores.

## 7. Parâmetro escolhido pelo usuário no app

É o caso da visão gerencial (`view`) e das verbas de hora extra (`overtimeCodes`).

- **Na API:**
  - valide o formato com `u_isSafeCode` ou `u_parseCodeList`;
  - confira se o código existe no Protheus (por exemplo, `viewExists` e `countCodes`);
  - sem o parâmetro, ou com código inexistente, responda `422` com `TDASH-422-CONFIG` e uma mensagem que diga ao
    usuário o que configurar.
- **No app:** a escolha fica em Configurações e é guardada por servidor e empresa.
  É preciso uma tela de escolha, que normalmente lê uma lista de apoio da própria API (`ctb.views`,
  `gpe.payroll_codes`).

## 8. Criar um módulo novo

1. **Pasta e fontes:** crie `src/<mód>` com `tdash.<mód>.api.tlpp` (namespace `tdash.<mód>`) e
   `tdash.<mód>.repository.tlpp`.
2. **Classe da API:** classe `TDash<Mód>Api` com as rotas de que precisar:

   ```
   @Get("/tdash/v1/<mód>/catalog")
   public method getCatalog()
   @Get("/tdash/v1/<mód>/kpis")
   public method getKpis()
   ...
   ```

3. **Modelo:** copie a estrutura de um módulo parecido. O Estoque é um bom ponto de partida: tem as cinco rotas e
   parâmetros de dimensão.
4. **Módulo do ERP:** use a sigla do módulo do Protheus no `x-erp-module`. O REST abre o ambiente do módulo e
   confere o acesso do usuário.
5. **App:** um módulo novo precisa de uma versão nova do app. Até lá, publique os indicadores dele como [painel personalizado](09-painel-personalizado.md), com o módulo **Outro** e a sigla do ERP.

## 9. Testes

**PROBAT (funções sem banco).** Toda regra que dá para escrever sem SQL deve virar `User Function` num fonte de
regras e ganhar teste. Modelo:

```
#include "tlpp-core.th"
#include "tlpp-probat.th"

namespace tests.<mód>

@TestFixture()
Class test_tdash_<mód>_<regra>
    Public Method New() as Object

    @Test('<função>: <o que o teste garante>')
    Public Method funcao_Cenario_Resultado() as Logical
EndClass

Method New() as Object Class test_tdash_<mód>_<regra>
Return Self

Method funcao_Cenario_Resultado() as Logical Class test_tdash_<mód>_<regra>
    tlpp.probat.assertEquals(tdash.<mód>.u_<funcao>(<entrada>), <esperado>)
Return .T.
```

Execução: `appserver.exe -console -consolelog -run=tlpp.probat.run -env=<AMBIENTE>`.

**Smoke test.** Acrescente a chamada nova em `tools/smoke-test.ps1`, no bloco do módulo:

```powershell
$calls += ,@{ Name = "80-fat-quantidade"; Module = "FAT"; Path = "fat/kpis?ids=fat.items_sold&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
```

Rode só o módulo com `-Module FAT`. Quando um `kpis` responde `500`, o script repete um indicador por vez e mostra
qual falhou.

**Conferência.** Compare o número com o relatório padrão do Protheus, na mesma filial e no mesmo período. É o teste
que importa.

## 10. Compilar e publicar

Os passos de compilação, REST e `curl` estão em [`../README.md`](../README.md#publicação). Resumo:

1. Compile no RPO, na ordem `src/core` e depois os módulos alterados.
2. Rode o smoke test em homologação.
3. Compile em produção.
4. Se houver mudança no app, publique a versão nova **depois** da API.

## 11. Indicador sobre uma entidade escolhida (cliente, fornecedor, produto)

Modelo: a **posição do cliente e do fornecedor** (`fin.party_*`). Use quando a tela mostra os números de **um**
registro escolhido pelo usuário, e não da filial inteira.

1. **Parâmetros na query string**, não rotas novas: `type`, `code` e `store` entram nas rotas `kpis`, `series`,
   `breakdown` e `list` do módulo. O app manda os parâmetros e eles entram na chave do cache.
2. **Classe própria**, sem anotações REST, que a API do módulo chama quando o id tem o prefixo da família:

   ```
   // em TDashFinApi:getSeries (o mesmo em getKpis, getBreakdown e getList)
   if tdash.fin.u_isPartyId(cId)
       oParty := TDashFinParty():new()
       return oParty:series(cId, oRequest, oHelper)
   endIf
   ```

   Guarde o objeto numa variável antes de chamar o método: `TDashFinParty():new():series(...)` dá "Syntax Error"
   no linter do TLPP.

   A classe tem o seu catálogo (`partyCatalog`), valida os parâmetros uma vez (`readParty`) e usa `oRest` e
   `oHelper` como a API do módulo.
3. **Validação:** código e loja só com letras e números e até o tamanho do campo (`TamSX3`), conferidos com
   `u_validPartyKey`. Complete com `PadR` no tamanho do campo antes do bind. Registro inexistente responde `404`
   com código próprio (`TDASH-404-PARTY`) e mensagem para o usuário.
4. **Busca:** uma lista (`fin.party_search`) com `search` de 3 a 40 caracteres, `LIKE` com bind
   (`'%' + texto + '%'`), no máximo 20 resultados e `hasNext` para pedir uma busca mais específica.
5. **Reaproveite as regras do módulo.** A posição usa os mesmos tipos excluídos e os mesmos filtros de caixa do
   painel (`excludedTypes`, `cashWhere`), que por isso ficaram públicos. Assim os números da posição batem com os
   do painel.

Para uma "posição do produto" no Estoque, por exemplo: `est.product_*`, uma classe `TDashEstProduct`, parâmetro
`code` com `B1_COD` e a mesma estrutura.

## 12. Ligar tabelas e escrever SQL que roda em qualquer banco

O Protheus roda em SQL Server, Oracle e PostgreSQL. `ChangeQuery` traduz parte do SQL, mas não tudo.

| Precisa de | Use | Evite |
|---|---|---|
| Concatenar campos (ex.: chave da OP `C2_NUM + C2_ITEM + C2_SEQUEN + C2_ITEMGRD` contra `D3_OP`) | `MatiConcat()` para o operador do banco (veja `TDashPcpRepository:closedJoin`) | `+` ou `||` fixos |
| Valor nulo vira zero | `COALESCE(SUM(...), 0)` | `ISNULL`, `NVL` |
| Condição dentro da soma | `SUM(CASE WHEN ... THEN ... ELSE 0 END)` | Funções específicas do banco |
| Valor negativo numa soma | `0 - campo` | Funções de sinal específicas |
| Diferença de datas | Leia as datas e calcule em TLPP com `tdash.core.u_daysBetween` | `DATEDIFF`, data menos data no SQL |
| Lista de valores (tipos, códigos) | `IN (?)` + `oQuery:setIn(n, aValores)` | Montar a lista no texto do SQL |

Ligações entre tabelas sempre com a filial de cada uma (`FWxFilial("SB1")`, `FWxFilial("SC2")`...) e
`D_E_L_E_T_ = ' '` em cada tabela do `JOIN`.

Quando várias consultas precisam ser cruzadas por uma chave (ex.: produzido, empenhado e consumido por OP), faça uma
consulta agrupada por tabela e junte em TLPP com um índice em `jsonObject` (`jIndex[cChave] := nPosição`), como em
`TDashPcpRepository:mergeOrders`. É mais simples de manter que um `SELECT` com várias subconsultas.

## 13. Datas, horas e tipos

- **Data menos data** é recusado pelo linter ("Incompatible types between N and D"). Use
  `tdash.core.u_daysBetween(dDe, dAte)` (com sinal; data vazia vale 0) ou `DateDiffDay` (sem sinal). Data menos
  número (`Date() - 30`) é permitido.
- **Datas que vêm do SQL** chegam como texto `AAAAMMDD`: converta com `SToD`. Para a resposta, use
  `Transform(cData, "@R 9999-99-99")`; data vazia continua vazia.
- **Horas em texto** (`H6_TEMPO`): use `tdash.pcp.u_timeToHours(cTempo, lCentesimal)` e decida o formato com
  `u_isCentesimal(H6_TIPOTEM, MV_TPHR)`. Hora centesimal "01:50" é 1,5 h; normal é 1 h 50 min.
- **`IIf()`** é proibido (SonarQube CA4000): use `if ... else ... endIf`.
- **`as variant`** não é tipo do TLPP: deixe a variável sem tipo quando ela recebe valores de tipos diferentes
  (ex.: `local xValor`).
- **Parâmetro opcional:** este projeto não usa `default`. Faça o parâmetro obrigatório e passe o valor em quem chama.

## 14. Exemplos de regras novas pedidas por clientes

### Matéria-prima: considerar só componentes do tipo MP

Em `TDashPcpRepository:closedOrderMaterials`, nas consultas de **empenho e de consumo**, troque:

```
" ... AND B1.B1_TIPO <> 'MO' ... "
```

por um bind com a lista de tipos (para o cliente poder mudar sem compilar):

```
" ... AND B1.B1_TIPO IN (?) ... "
// e no bind, na posição certa:
oQuery:setIn(4, StrTokArr2(SuperGetMV("MV_TDTIPMP", .F., "MP"), ",", .F.))
```

Ajuste as posições dos binds seguintes, documente o `MV_TDTIPMP` e mude a ajuda da aba Matéria-prima.

### Posição do cliente: descontar pedidos em carteira do crédito disponível

Em `TDashFinParty:kpiValue`, no caso `fin.party_credit_available`, subtraia também o saldo de pedidos liberados
(`A1_SALPEDL`, somado das lojas do escopo, ou a carteira da SC6 por cliente). Mude o texto do cartão no app
("Limite − em aberto − pedidos") e a ajuda `fin.md`.

### Horas: separar as improdutivas por motivo

1. Em `TDashPcpRepository:timeEntries`, acrescente `H6.H6_MOTIVO` ao `SELECT` e ao `GROUP BY` e devolva o motivo na
   linha.
2. Crie a quebra `pcp.unproductive_by_reason` (catálogo + `getBreakdown`) somando só as linhas improdutivas por
   motivo (rótulo do motivo na tabela de motivos do ambiente).
3. No app, um `BarList` com `Unit="HOURS"` na aba Apontamentos.

### Faturamento: contar complemento de preço

Em `TDashFatRepository:salesFrom`, troque `D2_TIPO = 'N'` por `D2_TIPO IN ('N', 'C')`. Vale para faturamento,
ticket médio, série e rankings (todos usam `salesFrom`).

## Checklist antes de publicar

- [ ] Todo valor que vem da requisição entra por bind (`?` + `set...`), nunca concatenado no SQL.
- [ ] Toda consulta filtra filial (`FWxFilial`) e `D_E_L_E_T_ = ' '`.
- [ ] Ids existentes não mudaram. Os nomes de série (`s`) não mudaram.
- [ ] Números como número, datas `AAAA-MM-DD`, percentuais de 0 a 100, valores arredondados.
- [ ] `ttl` em toda resposta de `kpis`, `series` e `breakdown`.
- [ ] Nenhum `return` dentro de `TRY ... CATCH`. Erros inesperados passam por `oHelper:serverError`.
- [ ] Mensagens de erro em português, para o usuário final, sem SQL nem detalhe técnico.
- [ ] RH: nenhum número de grupo com menos de `MV_TDMINGR` pessoas e nenhuma lista de pessoas.
- [ ] Fonte em CP1252, sem caracteres fora do CP1252, com `Protheus.doc` em cada método e função.
- [ ] Sem `IIf()`, sem data menos data, sem `as variant`; concatenação de campos no SQL com `MatiConcat()`.
- [ ] Teste PROBAT para a regra pura nova; chamada nova no smoke test.
- [ ] Catálogo de indicadores, ajuda da tela e esta documentação atualizados.
