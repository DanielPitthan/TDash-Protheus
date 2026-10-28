# 09 — Painel personalizado

Um painel personalizado é um endpoint REST seu, no mesmo Protheus, que devolve um JSON padronizado. No app, o usuário
cadastra o painel (nome, caminho, módulo) e o app monta sozinho os cartões de KPI, os gráficos e as tabelas, **na
ordem em que vêm no JSON**. Visual, tamanho e cores são do app. Publicar um painel novo **não exige versão nova do
app**: basta compilar o fonte e cadastrar o caminho.

- [Como funciona](#como-funciona)
- [Contrato do JSON (v1)](#contrato-do-json-v1)
- [Criar seu painel a partir do exemplo](#criar-seu-painel-a-partir-do-exemplo)
- [TDashPanelBuilder](#tdashpanelbuilder)
- [Testar com curl](#testar-com-curl)
- [Limites e erros](#limites-e-erros)

## Como funciona

```text
App (Módulos > Painéis personalizados > Adicionar painel: nome, caminho, módulo, usa período)
  │  GET https://<servidor>:<porta>/<raiz REST>{caminho}[?dateFrom=AAAAMMDD&dateTo=AAAAMMDD]
  │  Authorization: Basic …   tenantid: {empresa},{filial atual}   x-erp-module: {módulo escolhido}
  ▼
REST do Protheus (valida usuário, filial e módulo, como em qualquer rota do TDash)
  ▼
Sua classe com @Get (ex.: TDashCustomMockApi) → TDashPanelBuilder → JSON { title, ttl, widgets }
```

- **Caminho:** relativo à raiz do REST configurada no app, por exemplo `/tdash/v1/custom/mock`. O app não aceita
  endereço com outro servidor (`https://…`), `..` nem `#`, porque a senha do usuário vai junto. Um `?param=valor`
  fixo é aceito e enviado como está.
- **Rotas sugeridas:** `/tdash/v1/custom/<nome>`, namespace `tdash.custom`, pasta `src/custom/`.
- **Módulo:** o app envia no `x-erp-module` o módulo escolhido no cadastro. Para um dos oito módulos do TDash, o
  painel só aparece a quem pode ver esse módulo ([acesso por módulo](02-contrato-de-resposta.md#get-coremodules)).
  Na opção **Outro**, o usuário informa a sigla de qualquer módulo do Protheus (ex.: `MNT`, `GFE`, `TMS`; 2 a 6 letras
  ou números). Esse painel aparece para todos, e o REST do Protheus confere o acesso ao módulo em cada chamada
  (`403` quando o usuário não tem o módulo).
- **Período:** com "Usa período" ligado, o app mostra a barra de período e envia `dateFrom`/`dateTo`. Leia com
  `TDashRequest` + `TDashPeriod`, como nas outras rotas.
- **Cache:** o app guarda a resposta pelo `ttl` (segundos) e mostra o último dado, marcado como desatualizado,
  quando o servidor não responde.
- O painel é cadastrado **no aparelho**, por servidor e empresa. Cada usuário cadastra os painéis que quer ver.

## Contrato do JSON (v1)

```json
{
  "title": "Vendas x Devoluções",
  "ttl": 300,
  "generatedAt": "2026-10-23T14:32:05",
  "widgets": [
    { "type": "kpi", "name": "Faturado", "value": 100, "target": 120, "unit": "BRL", "direction": "up_is_good" },
    { "type": "columnChart", "name": "Por mês", "axisX": "Mês", "axisY": "R$", "unit": "BRL",
      "categories": ["Jan", "Fev", "Mar"],
      "series": [ { "name": "Faturado", "data": [44, 55, 57] } ] },
    { "type": "barChart", "name": "Por vendedor", "categories": ["Ago"], "series": [ { "name": "João", "data": [44] } ] },
    { "type": "table", "name": "Top clientes",
      "columns": [ { "label": "Cliente", "unit": "" }, { "label": "Valor", "unit": "BRL" } ],
      "data": [ ["ACME", 1200.5] ] }
  ]
}
```

**Raiz**

| Campo | Tipo | Obrigatório | Uso no app |
|---|---|---|---|
| `title` | texto | não | Subtítulo do painel; vazio usa só o nome cadastrado |
| `ttl` | número | não | Segundos de cache; ausente = 300 |
| `generatedAt` | texto ISO | não | Informativo |
| `widgets` | lista | **sim** | Blocos da tela, **na ordem da lista** |

**Comum a todos os widgets:** `type` (obrigatório) e `name` (título do bloco).

| `type` | Campos | Como aparece |
|---|---|---|
| `kpi` | `value` (número, obrigatório), `target` (número, opcional), `unit`, `direction` | Cartão com o valor. Com meta: "Meta R$ …", percentual atingido e cor pelo `direction` |
| `columnChart` | `categories` (textos), `series` (`[{ name, data: [números] }]`), `axisX`, `axisY`, `unit` | Colunas verticais, uma cor por série, legenda embaixo |
| `barChart` | os mesmos de `columnChart` | Barras horizontais |
| `table` | `columns` (`[{ label, unit }]` ou só textos), `data` (linhas de textos ou números) | Tabela com rolagem lateral; números formatados pela `unit` da coluna |

- `unit`: as mesmas do restante da API: `BRL`, `PCT`, `DAYS`, `HOURS`, `TIMES`, `PER_HOUR`, `QTY`, `COUNT`
  ([02](02-contrato-de-resposta.md#unidades-unit-e-sentido-direction)). Vazia ou desconhecida = número sem símbolo.
- `direction`: `up_is_good` (padrão), `down_is_good` ou `neutral`. Com meta, "bom" é atingir a meta no sentido
  indicado (`down_is_good`: ficar na meta ou abaixo dela).
- Em `series[].data`, o valor da posição *n* é o da categoria *n*. Série com menos valores que categorias fica com os
  que tem; valores a mais são ignorados.
- Use **camelCase** e números como números (não texto), como no resto da API.

O JSON exato devolvido pelo exemplo `/tdash/v1/custom/mock` está em
[`exemplos/painel-mock.json`](exemplos/painel-mock.json) (o app usa esse arquivo nos testes).

## Criar seu painel a partir do exemplo

1. Copie `src/custom/tdash.custom.mock.tlpp` para `src/custom/tdash.custom.<nome>.tlpp`.
2. Troque o nome da classe (`TDashCustomMockApi` → `TDashCustom<Nome>Api`) e a rota do `@Get`
   (`/tdash/v1/custom/<nome>`). Classe e rota precisam ser únicas no RPO.
3. Troque os valores fixos pelas suas consultas, num repositório (`TDashQuery` com bind, `RetSqlName`, `FWxFilial`,
   `D_E_L_E_T_`), como em [05 — receita 3.3](05-customizacao.md#33-consulta-srcfattdashfatrepositorytlpp).
   O exemplo `src/custom/tdash.custom.exemplo.tlpp` mostra isso reaproveitando as consultas do Faturamento.
4. Valide os parâmetros **antes** do `TRY` (`badRequest`) e não use `return` dentro do `TRY`.
5. Compile o fonte (Windows-1252) e teste com `curl` (abaixo).
6. No app: **Módulos > Painéis personalizados > Adicionar painel**, informe nome, caminho e módulo e toque em
   **Testar**. O app mostra quantos blocos leu, ou o erro.

## TDashPanelBuilder

Classe do núcleo (`src/core/tdash.core.panel.tlpp`, namespace `tdash.core`). Não acessa banco.

| Método | Widget |
|---|---|
| `new(cTitle, nTtl)` | Painel vazio |
| `addKpi(cName, nValue, cUnit)` | `kpi` sem meta |
| `addKpiTarget(cName, nValue, nTarget, cUnit, cDirection)` | `kpi` com meta; `cDirection` inválido vira `up_is_good` |
| `addColumnChart(cName, cAxisX, cAxisY, cUnit, aCategories, aSeries)` | `columnChart`; `aSeries` = `{ { "Faturado", { 44, 55 } }, ... }` |
| `addBarChart(...)` | `barChart`, mesmos parâmetros |
| `addTable(cName, aColumns, aRows)` | `table`; `aColumns` = `{ { "Cliente", "" }, { "Valor", "BRL" } }`, `aRows` = `{ { "ACME", 10.5 }, ... }` |
| `widgetCount()` | Quantidade de widgets |
| `getJson()` | Corpo `{ title, ttl, generatedAt, widgets }` para `TDashResponseHelper:getResponse` |

```text
oPanel := tdash.core.TDashPanelBuilder():new("Meu painel", 300)
oPanel:addKpiTarget("Faturado", nValor, nMeta, "BRL", "up_is_good")
oPanel:addColumnChart("Por mês", "Mês", "R$", "BRL", { "Ago", "Set" }, { { "Faturado", { 10, 20 } } })
oHelper:setCacheHeaders(300)
oRest:setResponse(oHelper:getResponse(oPanel:getJson()))
```

Testes PROBAT: `tests/core/test_tdash_core_panel.tlpp`.

## Testar com curl

```bash
curl -u usuario -H "tenantid: 01,1001" -H "x-erp-module: FAT" "https://<servidor>:<porta>/<raiz REST>/tdash/v1/custom/mock?dateFrom=20261001&dateTo=20261023"
```

Compare com [`exemplos/painel-mock.json`](exemplos/painel-mock.json): mesmos widgets, na mesma ordem. Só `title` (o
período) e `generatedAt` mudam. O smoke test chama `custom/mock` e `custom/exemplo`.

## Limites e erros

| Situação | O que o app faz |
|---|---|
| `type` desconhecido | Cartão "Tipo não suportado: …"; os outros blocos aparecem |
| Widget sem campo obrigatório (`value`, `series`, `columns`…) | Cartão de erro do bloco; os outros aparecem |
| Mais de 30 widgets, 10 séries, 60 categorias ou 200 linhas | Mostra até o limite e avisa que cortou |
| JSON sem `widgets` ou inválido | Mensagem "Resposta inválida do painel" |
| `400`, `401`, `403`, `404`, `500` | Mesmas mensagens das outras rotas ([02 — Erros](02-contrato-de-resposta.md#erros)); `404` = caminho errado ou fonte não compilado |

Painéis com muitos dados ficam lentos no celular: prefira agregados (como os indicadores do TDash) a listas longas.
