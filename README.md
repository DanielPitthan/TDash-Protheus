# TDash Protheus — APIs TLPP

Programas TLPP (AdvPL moderno) que publicam os indicadores do TOTVS Protheus (12.1.2410+) para o app
**TDash**, que mostra no celular os números de gestão: Financeiro, Faturamento, Compras, Estoque e Custos, Produção,
Livros Fiscais, Contabilidade e RH.

O código é aberto: baixe, compile no RPO da sua empresa, confira cada regra e customize o que precisar. O app TDash
está na [Google Play](https://play.google.com/store/apps/details?id=br.com.tdash.app).

- **Site, manual do usuário e manual técnico:** <https://danielpitthan.github.io/TDash-Protheus/>
- **Documentação técnica para customização** (o JSON que o app espera, núcleo, módulos, receitas, mapa de regras,
  operação e histórico): [`docs/`](docs/README.md)
- **Regras de negócio de cada indicador:** [`docs/10-catalogo-de-indicadores.md`](docs/10-catalogo-de-indicadores.md)
- **Contrato:** [`openapi/tdash-v1.yaml`](openapi/tdash-v1.yaml)

## Instalação rápida

1. Clone o repositório (o Git entrega os fontes em Windows-1252, ver [Codificação](#codificação)):

   ```bash
   git clone https://github.com/DanielPitthan/TDash-Protheus.git
   ```

2. Compile no RPO, com o TDS-VSCode: `src/core` primeiro, depois as pastas dos módulos e `src/custom`.
3. Confira as rotas com o [smoke test](#teste-rápido-das-rotas-smoke-test).
4. No app TDash, informe o endereço do REST do Protheus e entre com o usuário do Protheus.

Dúvidas, sugestões e erros: abra uma [issue](https://github.com/DanielPitthan/TDash-Protheus/issues) ou escreva para
administrativo@azsistemas.tech.

## Fontes

| Arquivo | Conteúdo |
|---|---|
| `src/core/tdash.core.api.tlpp` | Classe `TDashCoreApi`: `GET /tdash/v1/core/branches` e `GET /tdash/v1/core/modules` |
| `src/core/tdash.core.access.tlpp` | `User Function`s do acesso por módulo: menus do usuário e dos grupos (`PswRet`, `FWGrpMenu`) |
| `src/core/tdash.core.panel.tlpp` | Classe `TDashPanelBuilder`: JSON do painel personalizado ([09](docs/09-painel-personalizado.md)) |
| `src/custom/tdash.custom.mock.tlpp` | Classe `TDashCustomMockApi`: `GET /tdash/v1/custom/mock`, painel de exemplo com dados fictícios (modelo para copiar) |
| `src/custom/tdash.custom.exemplo.tlpp` | Classe `TDashCustomExemploApi`: `GET /tdash/v1/custom/exemplo`, painel de exemplo com as consultas do Faturamento |
| `src/core/tdash.core.responsehelper.tlpp` | Classe `TDashResponseHelper`: JSON de sucesso, erro no modelo TOTVS, `Cache-Control` |
| `src/core/tdash.core.query.tlpp` | Classe `TDashQuery`: `FWPreparedStatement` + `GetFixQuery` + `MPSysOpenQuery`, sempre com bind |
| `src/core/tdash.core.period.tlpp` | Classe `TDashPeriod`: período e comparação (`prev` / `yoy`) |
| `src/core/tdash.core.params.tlpp` | `User Function`s de validação de parâmetros (datas, códigos, linhas da visão gerencial) |
| `src/core/tdash.core.request.tlpp` | Classe `TDashRequest`: leitura de query string e path params |
| `src/fin/tdash.fin.api.tlpp` | Classe `TDashFinApi`: `GET /tdash/v1/fin/{catalog,kpis,series/:id,breakdown/:id,list/:id}` |
| `src/fin/tdash.fin.repository.tlpp` | Classe `TDashFinRepository`: consultas SE1, SE2, SE5, SE8, SA6 |
| `src/fin/tdash.fin.party.api.tlpp` | Classe `TDashFinParty`: posição do cliente e do fornecedor (indicadores `fin.party_*`, chamados pela `TDashFinApi`); lê `MV_CREDCLI` |
| `src/fin/tdash.fin.party.repository.tlpp` | Classe `TDashFinPartyRepository`: SA1, SA2, SE1, SE2, SE5 do cliente ou fornecedor |
| `src/fin/tdash.fin.party.rules.tlpp` | `User Function`s sem banco: faixas de atraso, validação do código, junção das lojas |
| `src/fat/tdash.fat.api.tlpp` | Classe `TDashFatApi`: `GET /tdash/v1/fat/{catalog,kpis,series/:id,breakdown/:id,list/:id}` |
| `src/fat/tdash.fat.repository.tlpp` | Classe `TDashFatRepository`: SD2, SF2, SF4, SD1, SC6, SCT, SA1, SA3, SB1 |
| `src/com/tdash.com.api.tlpp` | Classe `TDashComApi`: `GET /tdash/v1/com/{catalog,kpis,series/:id,breakdown/:id,list/:id}` |
| `src/com/tdash.com.repository.tlpp` | Classe `TDashComRepository`: SD1, SF4, SC7, SC1, SA2, SB1 |
| `src/est/tdash.est.api.tlpp` | Classe `TDashEstApi`: `GET /tdash/v1/est/{catalog,kpis,series/:id,breakdown/:id,list/:id}`; lê `MV_TDSEMMV` e `MV_TDVALID` |
| `src/est/tdash.est.repository.tlpp` | Classe `TDashEstRepository`: SB1, SB2, SB8, SB9, SBM, SD2, SD3, SF4 |
| `src/est/tdash.est.abc.tlpp` | `User Function` da classificação ABC (80/15/5%) |
| `src/pcp/tdash.pcp.api.tlpp` | Classe `TDashPcpApi`: `GET /tdash/v1/pcp/{catalog,kpis,series/:id,breakdown/:id,list/:id}` |
| `src/pcp/tdash.pcp.repository.tlpp` | Classe `TDashPcpRepository`: SC2, SD3, SD4, SH6, SH1, SB1; lê `MV_TPHR` |
| `src/pcp/tdash.pcp.time.tlpp` | `User Function`s que convertem o tempo da SH6 ("HH:MM", normal ou centesimal) em horas |
| `src/pcp/tdash.pcp.material.tlpp` | `User Function`s do balanço de matéria-prima (perda, devolvido, OPs fora da conta) |
| `src/fis/tdash.fis.api.tlpp` | Classe `TDashFisApi`: `GET /tdash/v1/fis/{catalog,kpis,series/:id,breakdown/:id,list/:id}` |
| `src/fis/tdash.fis.repository.tlpp` | Classe `TDashFisRepository`: SF3 (livro por nota) e SFT (livro por item) |
| `src/ctb/tdash.ctb.api.tlpp` | Classe `TDashCtbApi`: `GET /tdash/v1/ctb/{catalog,breakdown/:id,list/:id}` (DRE, Balanço e apoio às Configurações) |
| `src/ctb/tdash.ctb.repository.tlpp` | Classe `TDashCtbRepository`: CVE, CTS (visões gerenciais), CQ0 e CQ2 (saldos) |
| `src/ctb/tdash.ctb.rollup.tlpp` | `User Function` que totaliza a hierarquia das linhas da visão |
| `src/ctb/tdash.ctb.months.tlpp` | `User Function` do período em meses inteiros das demonstrações |
| `src/gpe/tdash.gpe.api.tlpp` | Classe `TDashGpeApi`: `GET /tdash/v1/gpe/{catalog,kpis,series/:id,breakdown/:id,list/:id}`; lê `MV_TDMINGR` |
| `src/gpe/tdash.gpe.repository.tlpp` | Classe `TDashGpeRepository`: SRA, SR8, RCM, SRD, SRV, CTT, SRJ; lê `MV_TDCATEX` e `MV_TDROTEX` |
| `src/gpe/tdash.gpe.rules.tlpp` | `User Function`s do RH sem banco: agrupamento da LGPD, faixas, dias de ausência, competências |
| `src/core/tdash.core.indicators.tlpp` | `User Function`s comuns: catálogo, cartão, item, ponto, coluna, top N + "Outros" |
| `src/core/tdash.core.series.tlpp` | `User Function`s de agrupamento das séries (dia, semana, mês) |
| `tests/core/test_tdash_core.tlpp` | 12 testes PROBAT das funções que não acessam banco |
| `tests/core/test_tdash_core_series.tlpp` | 6 testes PROBAT do agrupamento das séries |
| `tests/core/test_tdash_core_indicators.tlpp` | 7 testes PROBAT das funções comuns de indicadores |
| `tests/core/test_tdash_core_dates.tlpp` | 3 testes PROBAT da diferença de datas com sinal (`u_daysBetween`) |
| `tests/est/test_tdash_est_abc.tlpp` | 5 testes PROBAT da classificação ABC |
| `tests/pcp/test_tdash_pcp_time.tlpp` | 6 testes PROBAT da conversão de tempo da SH6 (normal e centesimal) |
| `tests/pcp/test_tdash_pcp_material.tlpp` | 4 testes PROBAT do balanço de matéria-prima |
| `tests/fin/test_tdash_fin_party.tlpp` | 5 testes PROBAT da posição do cliente e do fornecedor |
| `tests/ctb/test_tdash_ctb_rollup.tlpp` | 6 testes PROBAT da totalização das linhas da visão gerencial |
| `tests/ctb/test_tdash_ctb_months.tlpp` | 5 testes PROBAT do período em meses inteiros |
| `tests/gpe/test_tdash_gpe_rules.tlpp` | 13 testes PROBAT das regras do RH |

Usuário, módulo (`x-erp-module`) e filial (`tenantid`) são validados pelo próprio REST do Protheus;
as APIs TDash não repetem essa checagem.

## Codificação

O compilador do Protheus só aceita **Windows-1252**. O `.gitattributes` cuida disso: no
repositório os `.tlpp` ficam em UTF-8 e no checkout o Git entrega em CP1252 com CRLF. No VS Code
(TDS-VSCode), mantenha a codificação do arquivo como `Windows 1252`.

## Publicação

1. Compile `src/core`, `src/fin`, `src/fat`, `src/com`, `src/est`, `src/pcp`, `src/fis`, `src/ctb`, `src/gpe` e `src/custom` (`*.tlpp`) no RPO do ambiente (TDS-VSCode). `src/custom` depende de `src/core` e `src/fat`.
2. O REST do AppServer precisa estar ativo com autenticação Basic. As rotas ficam abaixo da raiz do
   REST. Exemplo no TOTVS Cloud: `https://<cliente>.protheus.cloudtotvs.com.br:1557/api/tdash/v1/core/branches`.
3. Teste com `curl`. Nas rotas `/core` envie `x-erp-module: FAT` (o REST usa o header para abrir o ambiente):

```bash
curl -u USUARIO:SENHA -H "x-erp-module: FAT" https://<cliente>.protheus.cloudtotvs.com.br:1557/api/tdash/v1/core/branches
```

Resposta esperada: `200` com `items` (empresa, filial, nome, CNPJ). Senha errada: `401` (devolvido
pelo próprio REST).

Financeiro (envie a filial em `tenantid` e `x-erp-module: FIN`):

```bash
curl -u USUARIO:SENHA -H "x-erp-module: FIN" -H "tenantid: 01,0101" "https://<cliente>.protheus.cloudtotvs.com.br:1557/api/tdash/v1/fin/kpis?ids=fin.receivable_open,fin.receivable_overdue,fin.bank_balance"
```

Outras rotas: `/fin/catalog`, `/fin/series/fin.cashflow_projection?grain=week`,
`/fin/breakdown/fin.aging_receivable`, `/fin/list/fin.overdue_receivables?page=1&pageSize=20`.

## Teste rápido das rotas (smoke test)

Depois de compilar, rode no PowerShell (a senha é pedida no terminal, não aparece e não é gravada):

```powershell
.\tools\smoke-test.ps1 -BaseUrl "https://<cliente>.protheus.cloudtotvs.com.br:1557/api" -User "usuario" -Company "01" -Branch "0101"
```

Ele chama `/core/branches` e as rotas do Financeiro, Faturamento, Compras, Estoque, Produção, Livros Fiscais, Contabilidade e RH (74 chamadas; com `-IncomeView`, `-BalanceView` e `-OvertimeCodes`, 79) e grava cada
resposta em `smoke-results\` (com `resumo.csv` de status e tempo). Esperado: 200 em todas, exceto os quatro testes de
indicador inexistente (17, 42, 50 e 59), que devolvem 404, e os da visão inexistente (65) e das horas extras sem verbas (77), que devolvem 422. Se a primeira chamada devolver 401 (usuário ou senha recusados),
o script para na hora, para não bloquear o usuário. A pasta fica fora do git porque contém dados do cliente.

A pasta `smoke-results\` é criada relativa ao local onde o script roda. Para gravar sempre no mesmo lugar, passe
`-OutDir "C:\TDash-Protheus\tools\smoke-results"`.

Para testar só alguns módulos, passe `-Module` (ex.: `-Module "EST,CTB"`; `-Module CUSTOM` testa só os painéis personalizados de exemplo). Quando uma chamada de KPIs devolve 500, o
script repete um indicador por vez e mostra qual falhou (arquivos `32-est-kpis.<indicador>.json`). O detalhe do erro
fica no `console.log` do AppServer REST, nas linhas com `TDASH`.

## Diagnóstico da Visão Gerencial (Contabilidade)

Para conhecer as visões gerenciais de um cliente novo, rode `tools/diagnostico-visao-gerencial.sql` e depois
`tools/diagnostico-visao-gerencial-2.sql` na base dele. São só leitura (SELECT) e mostram como as visões (CVE/CTS) são
feitas: linhas sintéticas e analíticas, fórmulas, faixas de centro de custo, item e classe de valor, e quais saldos
existem na CQ0. Troque o sufixo `010` pela empresa e o `XXX` (ou os códigos `003` e `100` da segunda rodada) pelas
visões do cliente. Os resultados não têm dados de pessoas.

## Testes PROBAT

Compile também `tests/core/*.tlpp`, `tests/fin/*.tlpp`, `tests/est/*.tlpp`, `tests/pcp/*.tlpp`, `tests/ctb/*.tlpp` e `tests/gpe/*.tlpp` (em ambiente de desenvolvimento) e rode:

```bash
appserver.exe -console -consolelog -run=tlpp.probat.run -env=NOME_DO_AMBIENTE
```

## Parâmetros opcionais (SX6)

Todos têm valor padrão no código e só precisam ser criados para mudar o padrão: `MV_TDINADD`,
`MV_TDDIASV`, `MV_TDTOPN`, `MV_TDSEMMV`, `MV_TDVALID`, `MV_TDMINGR`, `MV_TDCATEX` e `MV_TDROTEX` (ver o catálogo de
indicadores). Hoje a API lê:

- no Estoque, `MV_TDSEMMV` (dias sem movimento, padrão 180) e `MV_TDVALID` (janela de lotes a vencer, padrão 30);
- no RH, `MV_TDMINGR` (grupo mínimo da LGPD, padrão 5), `MV_TDCATEX` (categorias fora do quadro, padrão `A,P`) e
  `MV_TDROTEX` (roteiros fora da folha, padrão `ADI,131,AUT`).

Os demais entram junto com os indicadores que dependem deles.

## Diagnóstico do RH

Antes de ligar o RH num cliente novo, rode `tools/diagnostico-rh.sql` (só leitura, só contagens e totais, sem dado de
pessoa). Ele mostra categorias, motivos de desligamento, tipos de ausência, roteiros da folha e verbas que parecem
hora extra, para conferir `MV_TDCATEX`, `MV_TDROTEX` e as verbas a escolher no app.

## Marcas

TOTVS e Protheus são marcas da TOTVS S.A. O TDash não é um produto oficial da TOTVS.
