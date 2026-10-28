# 01 — Arquitetura das APIs TDash

## Visão geral

```
App Android (TDash)
   │  GET https://<servidor>:<porta>/<raiz REST>/tdash/v1/{módulo}/{rota}
   │  Authorization: Basic …   tenantid: {empresa},{filial}   x-erp-module: {FIN|FAT|...}
   ▼
REST do AppServer (Protheus 12.1.2410+)
   │  valida usuário e senha, acesso à empresa/filial e ao módulo; abre o ambiente na filial do tenantid
   ▼
Classe de API do módulo (TDash<Mód>Api, rotas @Get)       src/<mód>/tdash.<mód>.api.tlpp
   │  valida os parâmetros, escolhe o indicador no catálogo, monta o JSON de resposta
   ▼
Repositório do módulo (TDash<Mód>Repository)                src/<mód>/tdash.<mód>.repository.tlpp
   │  consultas SQL com bind (TDashQuery), sempre por filial e sem registros deletados
   ▼
Banco do Protheus
```

As **regras puras** ficam em fontes próprios, testados com PROBAT: classificação ABC, conversão de horas,
totalização da visão gerencial, período em meses, agrupamento da LGPD e outras. São funções que não acessam o
banco.

## Caminho de uma requisição

Exemplo: `GET /tdash/v1/fin/kpis?ids=fin.receivable_open&dateFrom=20261001&dateTo=20261031&compare=prev`.

1. **REST do Protheus:**
   - confere o Basic Auth e, se a senha estiver errada, devolve `401` sem chegar ao TDash;
   - troca para a empresa e a filial de `tenantid`;
   - abre o módulo de `x-erp-module`.
2. **Rota:** o REST encontra a rota pela anotação `@Get("/tdash/v1/fin/kpis")` na classe `TDashFinApi` e chama
   `getKpis()`.
3. **Validação:** `getKpis()` lê os parâmetros com `TDashRequest` e confere:
   - quantidade de ids;
   - datas e comparação, com `TDashPeriod`;
   - se cada id existe no catálogo, com `u_findIndicator`.

   O que estiver errado responde `400` ou `404` na hora (ver [02](02-contrato-de-resposta.md#erros)).
4. **Cálculo:** dentro de `TRY ... CATCH`, a API pede os valores ao repositório (`TDashFinRepository`), monta cada
   cartão com `u_kpiItem` e define o `Cache-Control` pela validade do indicador.
5. **Resposta:** `oRest:setResponse(oHelper:getResponse(jBody))` grava o JSON em UTF-8.
6. **Erro inesperado:** o `CATCH` chama `oHelper:serverError(...)`. Ele registra o erro no log do AppServer e
   responde `500` com uma mensagem genérica.

## Organização dos fontes

```
TDash-Protheus/
  src/core/   núcleo comum a todos os módulos (namespace tdash.core)
  src/fin/    Financeiro       src/fat/  Faturamento     src/com/  Compras
  src/est/    Estoque/Custos   src/pcp/  Produção        src/fis/  Livros Fiscais
  src/ctb/    Contabilidade    src/gpe/  Recursos Humanos
  src/custom/ painéis personalizados (namespace tdash.custom; ver 09-painel-personalizado.md)
  tests/      testes PROBAT das funções sem banco (mesma divisão por módulo)
  tools/      smoke test (PowerShell) e SQLs de diagnóstico (somente leitura)
```

Cada módulo segue o mesmo padrão:

| Fonte | Conteúdo |
|---|---|
| `tdash.<mód>.api.tlpp` | Classe `TDash<Mód>Api` com as rotas (`@Get`), a função estática `<mód>Catalog()` (o catálogo) e o método privado que calcula cada KPI (`kpiValue`, ou `kpi` no RH) |
| `tdash.<mód>.repository.tlpp` | Classe `TDash<Mód>Repository`, uma consulta por método. Não monta JSON de resposta, só devolve números, arrays ou páginas |
| `tdash.<mód>.<regra>.tlpp` | `User Function`s de regra pura (quando existem): `est.abc`, `pcp.time`, `pcp.material`, `ctb.rollup`, `ctb.months`, `gpe.rules`, `fin.party.rules` |

O Financeiro tem também a família de indicadores da **posição do cliente e do fornecedor**, em três fontes próprios
(`tdash.fin.party.api.tlpp`, `.party.repository.tlpp` e `.party.rules.tlpp`). A classe `TDashFinParty` não tem
rotas: a `TDashFinApi` repassa para ela os ids `fin.party_*` (ver [05, receita 11](05-customizacao.md#11-indicador-sobre-uma-entidade-escolhida-cliente-fornecedor-produto)).

Mais detalhes por módulo em [04 — Módulos](04-modulos.md).

## Namespaces e chamadas

Cada pasta tem o seu namespace: `tdash.core`, `tdash.fin`, `tdash.fat`, `tdash.com`, `tdash.est`, `tdash.pcp`,
`tdash.fis`, `tdash.ctb` e `tdash.gpe`.

```
// Classe do núcleo, chamada de um módulo
local oQuery := tdash.core.TDashQuery():new(cQry) as object

// User Function do núcleo
jItem := tdash.core.u_kpiItem(aDef, nValue, lCompare, oPeriod:cCompare, nPrev, oHelper:timestamp())

// Classe do mesmo namespace
local oRepo := TDashFinRepository():new() as object

// User Function de regra do próprio módulo (pode ser chamada com o namespace completo)
aGroups := tdash.gpe.u_lgpdGroups(aRows, nMin, nTop)
```

## Convenções de código

- **Linguagem:** TLPP com tipagem (`local cNome := "" as character`) e prefixo húngaro nos nomes (`c`, `n`, `l`,
  `d`, `a`, `j`, `o`).
- **Tipos de função:**
  - só `User Function` (funções públicas reutilizáveis e testáveis) e `static function` (auxiliares do fonte);
  - nada de `Function` sem prefixo;
  - as rotas são métodos de classe com anotação `@Get`.
- **Consultas:**
  - sempre por `tdash.core.TDashQuery`, que usa `FWPreparedStatement`, `ChangeQuery` e `MPSysOpenQuery`;
  - todo valor que vem da requisição entra por **bind** (`?`), nunca concatenado no SQL;
  - o nome da tabela vem de `RetSqlName()`, e a filial de `FWxFilial()`;
  - **cada tabela recebe a filial do seu próprio `FWxFilial("XXX")`, por bind.** O tamanho da filial muda de cliente
    para cliente (2, 4, 8, 10…) e o compartilhamento também: nunca fixe tamanho nem valor, e não ligue tabelas de
    famílias diferentes por `A.X_FILIAL = B.Y_FILIAL` (ex.: SC1 × SC7, SR8 × SRA). Essa comparação só é aceita entre
    cabeçalho e itens do mesmo documento (SF2 × SD2) ou na mesma tabela;
  - toda consulta filtra `D_E_L_E_T_ = ' '`.
- **Proibidos pelo linter e pelo SonarQube:**
  - `IIf()` (regra CA4000): use `if ... else ... endIf`;
  - data menos data ("Incompatible types between N and D"): use `tdash.core.u_daysBetween` ou `DateDiffDay`;
  - `as variant` (não é tipo do TLPP): deixe a variável sem tipo.
- **SQL portável:** concatenação de campos com `MatiConcat()`, nulos com `COALESCE`, condições com `CASE WHEN`
  (ver [05, receita 12](05-customizacao.md#12-ligar-tabelas-e-escrever-sql-que-roda-em-qualquer-banco)).
- **`return` dentro de `TRY ... CATCH`:** não use. Valide os parâmetros e responda os erros antes do `TRY`. Dentro
  dele, use variáveis de controle (veja `getBreakdown` da Contabilidade).
- **Chamadas em `local`:** declare as variáveis primeiro e chame os métodos depois das declarações quando a
  inicialização depende de outro objeto ou de parâmetro do sistema.
- **Codificação:**
  - no repositório Git os fontes ficam em UTF-8;
  - no checkout, o `.gitattributes` entrega em **Windows-1252 (CP1252) com CRLF**, porque o compilador do Protheus
    só aceita CP1252;
  - não use caracteres fora do CP1252 (como `Σ`, `≥` ou emojis), nem em comentários.
- **Documentação:**
  - todo método e função tem cabeçalho `Protheus.doc` com o que faz, `@param` e `@return`;
  - a regra de negócio está descrita no cabeçalho da classe do repositório e no catálogo de indicadores.

## Segurança

- **Usuário, filial e módulo:** o REST do Protheus valida antes de chamar a API. As APIs TDash **não** repetem
  essa validação.
- **Parâmetros recebidos:**
  - datas: `u_parseDate`, que recusa datas inexistentes;
  - números: `u_parseInt`, com faixa;
  - códigos: `u_isSafeCode` e `u_parseCodeList`, só letras, dígitos, ponto, hífen e espaço, até o tamanho do campo;
  - ids: só os do catálogo.
- **Erros:** nunca levam SQL, nome de tabela ou pilha de execução para o app. O detalhe vai para o log.
- **RH:** só devolve números agrupados, com o mínimo de pessoas de `MV_TDMINGR` (ver
  [02](02-contrato-de-resposta.md#hidden-e-lgpd) e [04](04-modulos.md#recursos-humanos--gpe)).

## Log

Erros de consulta e de execução vão para o `console.log` do AppServer REST com `FWLogMsg`, no grupo **`TDASH`**. O
contexto é `Classe:rota`, por exemplo `TDashEstApi:kpis` ou `TDashQuery:open`. Para investigar um `500`, procure
`TDASH` no log do AppServer que atende o REST.

## Parâmetros do Protheus (SX6)

Todos têm valor padrão no código. Só crie no SX6 se precisar mudar o padrão.

| Parâmetro | Padrão | Lido em | Uso |
|---|---|---|---|
| `MV_TDSEMMV` | 180 | `tdash.est.api.tlpp` | Dias sem movimento (estoque parado) |
| `MV_TDVALID` | 30 | `tdash.est.api.tlpp` | Janela de lotes a vencer (dias) |
| `MV_TDMINGR` | 5 | `tdash.gpe.api.tlpp` | Tamanho mínimo de grupo no RH (LGPD) |
| `MV_TDCATEX` | `A,P` | `tdash.gpe.repository.tlpp` | Categorias (`RA_CATFUNC`) fora do quadro do RH |
| `MV_TDROTEX` | `ADI,131,AUT` | `tdash.gpe.repository.tlpp` | Roteiros (`RD_ROTEIR`) fora da folha |

Parâmetros padrão do Protheus que o TDash lê (não crie: eles já existem no ambiente):

| Parâmetro | Padrão no código | Lido em | Uso |
|---|---|---|---|
| `MV_TPHR` | `C` | `tdash.pcp.repository.tlpp` (`timeEntries`) | Formato do tempo da SH6 quando o apontamento não tem `H6_TIPOTEM` (C = centesimal, N = normal) |
| `MV_CREDCLI` | `L` | `tdash.fin.party.api.tlpp` | Limite de crédito por loja (`L`) ou por cliente (`C`) na posição do cliente |

O Financeiro lê as variáveis do próprio Financeiro (`MVABATIM`, `MVPROVIS`, `MVRECANT`, `MVPAGANT`, `MV_CRNEG`,
`MV_CPNEG`) para saber quais tipos de título não são dívida. Os prazos de 30 dias do Financeiro ("a vencer" e
inadimplência) são constantes no fonte (`DEFAULT_DUE_DAYS`, `DEFAULT_LATE_DAYS`).

## Validade das respostas (cache)

Cada indicador tem uma validade, em segundos, no catálogo:

| Constante | Segundos | Uso |
|---|---|---|
| `TTL_OP` | 300 (5 min) | Operacional: saldo bancário, faturamento do dia, OPs atrasadas |
| `TTL_TAT` | 1.800 (30 min) | Tático: mês corrente, carteira, estoque |
| `TTL_EST` | 43.200 (12 h) | Estratégico: contábil, fiscal, RH |

O app guarda cada resposta pelo prazo do campo `ttl` e só volta ao servidor depois disso, ou quando o usuário
toca em "atualizar". Veja [02 — Cache](02-contrato-de-resposta.md#cache-e-validade).
