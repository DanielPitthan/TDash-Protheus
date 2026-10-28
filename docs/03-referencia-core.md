# 03 — Referência do núcleo (`src/core`, namespace `tdash.core`)

O núcleo tem o que é comum a todos os módulos. Para customizar, use estas peças: elas já seguem o contrato da
[02](02-contrato-de-resposta.md).

| Fonte | Conteúdo |
|---|---|
| `tdash.core.request.tlpp` | `TDashRequest`: leitura da query string e do path |
| `tdash.core.period.tlpp` | `TDashPeriod`: período, comparação e validação das datas |
| `tdash.core.query.tlpp` | `TDashQuery`: consultas com bind |
| `tdash.core.responsehelper.tlpp` | `TDashResponseHelper`: JSON de sucesso e de erro, cache, data/hora |
| `tdash.core.indicators.tlpp` | Catálogo, cartão, item, ponto, coluna, top N + "Outros", participação |
| `tdash.core.series.tlpp` | Agrupamento das séries por dia, semana ou mês |
| `tdash.core.params.tlpp` | Validação de datas, inteiros e códigos |
| `tdash.core.api.tlpp` | Rota `/core/branches` |

## TDashRequest

```
local oRequest := tdash.core.TDashRequest():new() as object
local cId      := oRequest:path("id") as character        // GET .../breakdown/:id
local cTop     := oRequest:query("top") as character      // ?top=10
```

| Método | Retorno |
|---|---|
| `new()` | Lê a query string e os parâmetros do caminho do `oRest` da requisição atual |
| `query(cName)` | `character`: valor do parâmetro sem espaços nas pontas; vazio quando não veio |
| `path(cName)` | `character`: valor do parâmetro do caminho (`:id`); vazio quando não veio |

Os valores chegam sempre como texto. Converta e valide com as funções de `tdash.core.params.tlpp`.

## TDashPeriod

```
local oPeriod := tdash.core.TDashPeriod():new() as object

if !oPeriod:fromQuery(oRequest:query("dateFrom"), oRequest:query("dateTo"), oRequest:query("compare"), Date())
    oHelper:badRequest(oPeriod:cError)
    return .T.
endIf
// oPeriod:dFrom, oPeriod:dTo, oPeriod:cCompare, oPeriod:compareFrom(), oPeriod:compareTo()
```

| Membro | Tipo | Descrição |
|---|---|---|
| `fromQuery(cFrom, cTo, cCompare, dToday)` | `logical` | Preenche o período. Sem datas: do 1º dia do mês de `dToday` até `dToday`. Recusa data inválida, `dateFrom` > `dateTo` e período com mais de 24 meses. `.F.` deixa a mensagem em `cError` |
| `dFrom`, `dTo` | `date` | Período pedido |
| `cCompare` | `character` | `none`, `prev` ou `yoy` |
| `cError` | `character` | Mensagem do problema (para o `badRequest`) |
| `hasCompare()` | `logical` | `.T.` com `prev` ou `yoy` |
| `compareFrom()`, `compareTo()` | `date` | `prev`: o período imediatamente anterior, com a mesma quantidade de dias. `yoy`: as mesmas datas do ano anterior. Sem comparação: data vazia |

Para períodos em **meses inteiros**, use as regras do módulo: `tdash.ctb.u_monthPeriod` (Contabilidade) e
`tdash.gpe.u_payrollMonths` (RH).

## TDashQuery

Executa um `SELECT` com `FWPreparedStatement`, `ChangeQuery`, `GetFixQuery` e `MPSysOpenQuery`. Todo valor
variável entra por **bind**: cada `?` do SQL recebe um `set...` na mesma ordem em que aparece no texto, contando
os `JOIN` antes do `WHERE`.

```
local nTotal := 0 as numeric
local cQry   := "" as character
local cAlias := "" as character
local oQuery as object

cQry := " SELECT SUM(SE1.E1_SALDO) TOTAL "
cQry += " FROM " + RetSqlName("SE1") + " SE1 "
cQry += " WHERE SE1.E1_FILIAL = ? "
cQry += " AND SE1.E1_VENCREA < ? "
cQry += " AND SE1.E1_TIPO NOT IN (?) "
cQry += " AND SE1.D_E_L_E_T_ = ' ' "

oQuery := tdash.core.TDashQuery():new(cQry)
oQuery:setString(1, FWxFilial("SE1"))
oQuery:setString(2, DToS(Date()))
oQuery:setIn(3, { "RA ", "NCC" })
if oQuery:open()
    cAlias := oQuery:getAlias()
    if !(cAlias)->(Eof()) .and. valType((cAlias)->TOTAL) == "N"
        nTotal := (cAlias)->TOTAL
    endIf
    oQuery:close()
endIf
```

| Método | Descrição |
|---|---|
| `new(cQry)` | Prepara o statement (aplica `ChangeQuery`) |
| `setString(nPos, cValor)` | Bind de texto. Datas vão como texto `AAAAMMDD` (`DToS`) |
| `setNumeric(nPos, nValor)` | Bind numérico |
| `setDate(nPos, dValor)` | Bind de data |
| `setIn(nPos, aValores)` | Bind de uma lista para `IN (?)` ou `NOT IN (?)`. A lista não pode ser vazia: use um valor que nunca existe (`{"#"}`) |
| `open()` | `logical`. Monta a consulta e abre a área de trabalho. Em erro de SQL devolve `.F.`, guarda a mensagem em `cError` e registra no log (`TDashQuery:open`) |
| `getAlias()` | `character`: alias da área aberta |
| `close()` | Fecha a área de trabalho. Chame sempre depois de ler |

**Atenção:** `SUM` sem linhas volta nulo. Os repositórios usam um método `numberOf(cAlias, cCampo)` que devolve 0
nesse caso. Copie esse padrão.

## TDashResponseHelper

```
local oHelper := tdash.core.TDashResponseHelper():new() as object
local jBody   := jsonObject():new() as json

jBody["items"] := aItems
oHelper:setCacheHeaders(aDef[6])
oRest:setResponse(oHelper:getResponse(jBody))
```

| Método | Descrição |
|---|---|
| `getResponse(jBody)` | JSON de sucesso em UTF-8, com `Content-Type` |
| `getErrorResponse(cCode, cMessage, cDetail)` | JSON de erro `{ code, message, detailedMessage, helpUrl }` em UTF-8, com `Cache-Control: no-store`. Defina o status antes com `oRest:setStatusCode()` |
| `setCacheHeaders(nTtl)` | `Cache-Control: private, max-age=nTtl` (ou `no-store` com 0). O app usa o campo `ttl` do corpo; o header serve a outros consumidores |
| `timestamp()` | `character`: data e hora do servidor, `AAAA-MM-DDThh:mm:ss` (campo `generatedAt`) |
| `badRequest(cMessage)` | Responde `400` com `TDASH-400-PARAM` |
| `notFound(cId, cModulo)` | Responde `404` com `TDASH-404-INDICATOR` |
| `serverError(cContexto, cDetalhe)` | Registra o detalhe no log (`FWLogMsg`, grupo `TDASH`) e responde `500` com `TDASH-500` e mensagem genérica |

Para `422` (configuração que o usuário faz no app), os módulos têm um método `configError(cMessage)` que responde
`TDASH-422-CONFIG`. Veja a Contabilidade e o RH.

## Catálogo e montagem de JSON (`tdash.core.indicators.tlpp`)

Cada módulo tem uma função estática que devolve o catálogo. Cada linha do catálogo é:

```
{ id, { tipos }, título, unidade, sentido, ttl }
{ "fin.bank_balance", { "kpi", "breakdown" }, "Saldo bancário", "BRL", "up_is_good", TTL_OP }
```

- **Tipos:** `kpi`, `series`, `breakdown`, `list`. O tipo diz em quais rotas o id é aceito.
- **Unidade e sentido:** ver [02](02-contrato-de-resposta.md#unidades-unit-e-sentido-direction).
- **ttl:** validade em segundos.

| Função | Retorno | Descrição |
|---|---|---|
| `u_findIndicator(aCatalogo, cId, cTipo)` | `array` | A linha do catálogo, ou `{}` se o id não existe ou não aceita o tipo. Use para responder `404` |
| `u_catalogItems(aCatalogo)` | `array` de json | Itens da rota `/catalog` |
| `u_kpiItem(aDef, nValor, lCompara, cModo, nAnterior, cTimestamp)` | `json` | Cartão completo de `kpis`: `id`, `title`, `unit`, `direction`, `value` (2 casas), `compare` (com `deltaPct`, `null` quando a base é 0), `generatedAt`, `ttl` |
| `u_jsonItem(cChave, cRotulo, nValor)` | `json` | Item de `breakdown` `{ key, label, value }` (aparados, valor com 2 casas) |
| `u_jsonPoint(cX, nY, cSerie)` | `json` | Ponto de série `{ x, y, s }` |
| `u_jsonColumn(cChave, cRotulo, cTipo)` | `json` | Coluna de lista `{ key, label, type }` |
| `u_rowsToItems(aLinhas)` | `array` de json | Converte `{ chave, rótulo, valor }` em itens de `breakdown` |
| `u_topWithOthers(aItens, nTop, cRotuloOutros)` | `array` de json | Tira os zerados, ordena pelo valor absoluto, mantém `nTop` e soma o resto em `{ key: "others", label: "Outros (n)" }` |
| `u_applyShares(aItens)` | `array` de json | Preenche `share` (0 a 1) pelo valor absoluto |
| `u_sumColumn(aLinhas, nColuna)` | `numeric` | Soma uma coluna |

Exemplo de `breakdown` com os 10 maiores e "Outros":

```
aItems := tdash.core.u_rowsToItems(oRepo:topCustomers(oPeriod:dFrom, oPeriod:dTo))   // { { chave, rótulo, valor } }
aItems := tdash.core.u_applyShares(tdash.core.u_topWithOthers(aItems, nTop, "Outros"))
jBody["items"] := aItems
```

## Séries (`tdash.core.series.tlpp`)

| Função | Retorno | Descrição |
|---|---|---|
| `u_bucketKey(cData, cGrain)` | `character` | Chave do eixo: `day` → `AAAA-MM-DD`; `week` → segunda-feira da semana (`AAAA-MM-DD`); `month` → `AAAA-MM`. `cData` em `AAAAMMDD` |
| `u_groupRows(aLinhas, cGrain)` | `array` | Soma linhas `{ data AAAAMMDD, valor }` pela chave da granularidade. Devolve `{ { chave, valor } }` em ordem crescente |
| `u_mergeKeys(aPrimeiro, aSegundo)` | `array` | Chaves dos dois agrupamentos, sem repetição e em ordem (para séries com dois nomes) |
| `u_valueOf(aGrupos, cChave)` | `numeric` | Valor de uma chave, ou 0 |

Exemplo de série com duas linhas, como entradas e saídas:

```
aIn   := tdash.core.u_groupRows(oRepo:inByDay(oPeriod:dFrom, oPeriod:dTo), cGrain)
aOut  := tdash.core.u_groupRows(oRepo:outByDay(oPeriod:dFrom, oPeriod:dTo), cGrain)
aKeys := tdash.core.u_mergeKeys(aIn, aOut)
for nX := 1 to Len(aKeys)
    aAdd(aPoints, tdash.core.u_jsonPoint(aKeys[nX], tdash.core.u_valueOf(aIn, aKeys[nX]), "in"))
    aAdd(aPoints, tdash.core.u_jsonPoint(aKeys[nX], tdash.core.u_valueOf(aOut, aKeys[nX]), "out"))
next nX
```

## Validação de parâmetros (`tdash.core.params.tlpp`)

Funções sem acesso a banco, cobertas por testes PROBAT.

| Função | Retorno | Descrição |
|---|---|---|
| `u_parseDate(cValor)` | `date` | `AAAAMMDD` em data; data vazia quando o formato é inválido ou a data não existe (`20260231`) |
| `u_parseInt(cValor, nPadrao, nMin, nMax)` | `numeric` | Inteiro dentro da faixa; `nPadrao` quando vazio; **-1** quando inválido ou fora da faixa |
| `u_isDigits(cValor)` | `logical` | Só dígitos |
| `u_monthsBetween(dDe, dAte)` | `numeric` | Meses de calendário cobertos pelo período, contando os dois extremos |
| `u_isSafeCode(cValor, nTamanhoMax)` | `logical` | Código aceito para bind: letras, dígitos, ponto, hífen e espaço, até o tamanho do campo (`X3_TAMANHO`) |
| `u_parseCodeList(cCsv, nTamanhoMax, nMaxItens)` | `array` | Lista "A,B,C" validada e sem repetição; **vazia** se algum código for inválido ou passar do máximo |
| `u_parseRoleLines(cValor, aPapeis, nTamanhoMax, jLinhas)` | `logical` | Lê `papel:linha,papel:linha` (indicadores da Contabilidade da etapa 2) |

Padrão de validação de um parâmetro numérico:

```
nTop := tdash.core.u_parseInt(oRequest:query("top"), DEFAULT_TOP, 1, 50)
if nTop < 0
    oHelper:badRequest("top deve estar entre 1 e 50.")
    return .T.
endIf
```

## Rota /core/branches (`TDashCoreApi`)

Usa `FWLoadSM0(.T., .T.)` e devolve só as filiais em que `SM0_USEROK` é verdadeiro para o usuário da requisição.
Formato em [02](02-contrato-de-resposta.md#get-corebranches). Validade: 1 hora (`TTL_BRANCHES`).

## Rota /core/modules (`TDashCoreApi`)

Chama `u_userModules(RetCodUsr())` e devolve os oito módulos de `u_moduleCodes` com `allowed`. Formato em
[02](02-contrato-de-resposta.md#get-coremodules). Validade: 5 minutos (`TTL_MODULES`).

## Acesso por módulo (`tdash.core.access.tlpp`)

| Função | O que faz |
|---|---|
| `u_moduleCodes()` | Tabela fixa sigla → número do módulo no Protheus: FIN 6, COM 2, FAT 5, PCP 10, EST 4, GPE 7, CTB 34, FIS 9 |
| `u_menuModules(aMenus)` | Pura (tem PROBAT). Lê entradas de menu `"MMN\caminho\menu.xnu"`: `MM` = módulo, `N` = nível ou `X` (sem acesso). Ignora entrada vazia, sem menu ou fora do padrão |
| `u_userMenus(cUserId)` | Menus que valem para o usuário: `PswOrder(1)` + `PswSeek` + `PswRet()`. Menus próprios em `[3]`, grupos em `[1][10]`, "Priorizar configuração do grupo" em `[2][11]`; menus de cada grupo com `FWGrpMenu` |
| `u_userModules(cUserId)` | Siglas liberadas. Administrador (`FWIsAdmin`) vê todos |

Regra de grupo: com "Priorizar configuração do grupo" marcado (e o usuário em algum grupo), valem só os menus dos
grupos; senão, os menus do usuário **somados** aos dos grupos. Um módulo liberado em qualquer menu que vale conta como
liberado.

**Privilégios (release 12.1.2610):** a partir da 2610 os usuários novos entram no grupo **Default**, que nega todas
as rotinas, e os privilégios liberam rotina por rotina. Privilégio não libera nem bloqueia **módulo**: o módulo
continua vindo da aba Menus. Por isso o TDash não lê privilégios; um usuário com o módulo e sem nenhum privilégio
ainda vê o painel (os dados são consultas agregadas, não rotinas do Protheus).

Para conferir o formato real no ambiente, use o diagnóstico `tools/diagnostico-acesso.tlpp`
([07](07-operacao-e-problemas.md#diagnósticos-somente-leitura)).
