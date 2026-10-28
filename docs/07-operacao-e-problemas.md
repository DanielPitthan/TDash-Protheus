# 07 — Operação, implantação e solução de problemas

Guia para quem instala o TDash num cliente, publica uma versão nova das APIs ou investiga um número errado ou uma
tela com erro.

## Implantação num cliente novo

| Passo | O que fazer | Onde |
|---|---|---|
| 1 | Conferir a versão do Protheus (12.1.2410 ou mais nova) e se o REST do AppServer está ativo com autenticação Basic | INI do AppServer REST |
| 2 | Compilar `src/core` e depois as pastas dos módulos no RPO | TDS-VSCode |
| 3 | Rodar o smoke test em homologação | `tools/smoke-test.ps1` |
| 4 | Contabilidade: rodar os diagnósticos da visão gerencial e combinar com a contabilidade quais visões usar | `tools/diagnostico-visao-gerencial*.sql` |
| 5 | RH: rodar o diagnóstico e conferir categorias, roteiros e verbas de hora extra | `tools/diagnostico-rh.sql` |
| 6 | Criar no SX6 só os parâmetros `MV_TD...` cujo padrão não serve | [01 — Parâmetros](01-arquitetura.md#parâmetros-do-protheus-sx6) |
| 7 | Conferir números de cada módulo contra os relatórios padrão (lista abaixo) | Protheus |
| 8 | Passar ao usuário o endereço do REST (ex.: `https://cliente.protheus.cloudtotvs.com.br:1557/api`) | App > Configurações |
| 9 | No app: escolher a visão da DRE, a do Balanço e as verbas de hora extra | App > Configurações |
| 10 | Conferir os módulos de um usuário comum e de um usuário com grupo (ver [Acesso por módulo](#acesso-por-módulo)) | `tools/diagnostico-acesso.tlpp` |

### Conferência com o Protheus

| Módulo | Indicador do TDash | Compare com |
|---|---|---|
| Financeiro | A receber/pagar em aberto e vencido | Posição de títulos (FINR130/FINR150) |
| Financeiro | Entradas e saídas realizadas | Movimentação bancária (FINR620) |
| Financeiro | Posição do cliente/fornecedor | Consultas FINC010 e FINC030 |
| Faturamento | Faturamento do mês | Relação de faturamento (MATR550 ou equivalente) |
| Compras | Volume comprado | Relação de notas de entrada |
| Estoque | Valor em estoque | Posição de estoque (MATR460) |
| Produção | OPs atrasadas, produção do período | Relação de OPs e consulta de movimentos internos (SD3) |
| Produção | Matéria-prima de uma OP | Empenhos da OP (SD4) e requisições/devoluções (SD3) da mesma OP |
| Livros Fiscais | Débito e crédito de ICMS | Apuração de ICMS (MATA953) |
| Contabilidade | DRE e Balanço | Relatórios da mesma visão gerencial |
| RH | Quadro e folha | Relação de funcionários ativos e resumo da folha |

Compare sempre na **mesma filial** e no **mesmo período**. O TDash consulta uma filial por vez (a do `tenantid`).

## Acesso por módulo

O app mostra só os módulos liberados na aba **Menus** do cadastro do usuário (SIGACFG > Usuário > Senhas >
Usuários) e dos grupos dele. Para liberar um painel, libere o módulo no cadastro (ou no grupo) e peça ao usuário para
sair e entrar de novo no app.

- Módulo marcado como sem acesso (`X` no menu) não aparece.
- "Priorizar configuração do grupo" marcado: valem só os menus dos grupos.
- **Release 12.1.2610:** usuário novo entra no grupo Default (todas as rotinas negadas) e os privilégios liberam
  rotinas. Isso **não** muda o que o TDash mostra, porque o TDash lê módulos, não privilégios.
- As rotas `/core` usam `x-erp-module: FAT`. Se o REST do ambiente exigir o módulo do header, um usuário sem o
  Faturamento não consegue entrar no app. Esse comportamento já existia; se acontecer, libere o FAT ao usuário.

## Publicar uma versão nova das APIs

1. Compile em **homologação**, na ordem `src/core` e depois os módulos alterados.
2. Rode os testes PROBAT (`tests/`) no ambiente de desenvolvimento, se houver.
3. Rode o smoke test com `-Module` dos módulos alterados.
4. Compile em **produção** na mesma ordem.
5. Se a versão do app também mudou, publique o app **depois** da API. Um app novo pedindo um indicador que a API
   ainda não tem recebe `404`, e o cartão fica sem valor.

Não é preciso reiniciar nada no app: cada resposta tem validade (`ttl`). O usuário vê o número novo quando a
validade vence ou quando toca em "atualizar".

## Smoke test

```powershell
.\tools\smoke-test.ps1 -BaseUrl "https://<cliente>.protheus.cloudtotvs.com.br:1557/api" -User "usuario" -Company "01" -Branch "0101"
```

| Parâmetro | Para quê |
|---|---|
| `-Module "FIN,PCP"` | Só as rotas destes módulos |
| `-IncomeView` / `-BalanceView` | Testa a DRE e o Balanço com as visões do cliente |
| `-OvertimeCodes "179,181"` | Testa as horas extras do RH |
| `-CustomerCode` / `-SupplierCode` | Testa a posição do cliente e do fornecedor |
| `-PartySearch "TEXTO"` | Texto da busca de clientes e fornecedores (padrão `LTDA`) |
| `-OutDir` | Pasta dos resultados (padrão `.\smoke-results`) |

- A senha é pedida no terminal e não é gravada. Se a primeira chamada devolver `401`, o script para, para não
  bloquear o usuário.
- Cada resposta vai para um arquivo `.json` e o resumo para `resumo.csv` (status e tempo).
- Quando uma chamada de `kpis` devolve `500`, o script repete um indicador por vez e mostra qual falhou.
- A pasta de resultados tem dados do cliente: não versione nem envie por canais abertos.

## Log

Erros vão para o `console.log` do AppServer que atende o REST, com `FWLogMsg` no grupo **`TDASH`**. Procure por
`TDASH` e pelo contexto `Classe:rota` (ex.: `TDashPcpApi:kpis`, `TDashQuery:open`). A mensagem traz o erro do banco
ou da execução. O app nunca recebe esse detalhe: ele vê só "Erro ao consultar o Protheus."

## Erros na resposta da API

| Status | Código | Causa comum | O que fazer |
|---|---|---|---|
| `401` | (do REST) | Usuário ou senha errados, ou usuário bloqueado | Conferir o usuário no Configurador. O app mostra "Usuário ou senha inválidos." |
| `403` | (do REST) | Usuário sem acesso à filial ou ao módulo | Liberar o acesso no Configurador |
| `404` | `TDASH-404-INDICATOR` | Indicador fora do catálogo: API desatualizada em relação ao app, ou id digitado errado | Compilar a versão das APIs que acompanha o app |
| `404` | `TDASH-404-PARTY` | Cliente ou fornecedor inexistente na filial | Conferir o código e a loja |
| `404` | (do REST, HTML) | Rota inexistente: os fontes não foram compilados, ou a raiz do REST está errada | Conferir a compilação e o endereço (`.../api`) |
| `400` | `TDASH-400-PARAM` | Parâmetro inválido: data, período maior que 24 meses, `top`, `page`, código | Ver a mensagem; o app normalmente não envia isso |
| `422` | `TDASH-422-CONFIG` | Falta configuração: visão gerencial ou verbas de hora extra | Escolher em Configurações no app |
| `500` | `TDASH-500` | Erro de execução ou de SQL | Procurar `TDASH` no log do AppServer |

## Mensagens que o usuário vê no app

| Mensagem no app | Origem | O que verificar |
|---|---|---|
| "Configure o endereço do servidor Protheus." | Endereço vazio | App > Configurações |
| "O endereço precisa começar com https://" | Endereço `http://` em versão de produção | Usar o endereço HTTPS do REST |
| "Não foi possível conectar a {servidor}." | Rede, DNS, porta fechada, certificado inválido | Internet do aparelho, porta do REST, certificado |
| "O servidor demorou para responder." | Mais de 30 s sem resposta | Desempenho da consulta (índices, período muito longo) |
| "Usuário ou senha inválidos." | `401` | Usuário no Protheus |
| "As APIs do TDash não foram encontradas neste servidor." | `404` sem corpo TDash | Fontes compilados e raiz do REST |
| "Resposta inválida do servidor. Confira se as APIs do TDash estão atualizadas no Protheus." | JSON fora do contrato | API e app de versões diferentes, ou erro no JSON montado |
| "Sem conexão com o Protheus. Mostrando dados de dd/MM HH:mm." | Falha ao atualizar, com dado guardado | O app mostra o último dado; corrija a causa e toque em atualizar |
| "Escolha em Configurações a visão gerencial..." / "Configure as verbas de hora extra" | `422` | Configurações do app |
| "Seu usuário não tem acesso a nenhum módulo do TDash." | `/core/modules` sem nenhum módulo liberado | Aba Menus do usuário e dos grupos; rodar `tdAcessoDiag` |

## Erros de compilação e do linter TLPP

| Mensagem | Causa | Correção |
|---|---|---|
| "Incompatible types between N and D" | Data menos data (`dTo - dFrom`) | `tdash.core.u_daysBetween(dDe, dAte)` (com sinal) ou `DateDiffDay` (sem sinal). Data menos número (`Date() - 30`) é permitido |
| SonarQube CA4000 | Uso de `IIf()` | Trocar por `if ... else ... endIf` |
| "Syntax Error" numa linha com `Classe():new():metodo(...)` | O linter não aceita chamar um método direto na criação do objeto | Guardar o objeto numa variável antes: `oRepo := TDashFinRepository():new()` e depois `oRepo:metodo(...)` |
| Caracteres trocados (`Ã§`, `Ã£`) no fonte ou nas mensagens | Arquivo salvo em UTF-8 | Salvar em Windows-1252. O Git entrega certo no checkout; o problema aparece quando o arquivo é copiado de outro lugar |
| "Variable does not exist: oRest" | Método de rota chamado fora de uma requisição REST | Testar pela rota, não chamando o método direto |
| Função não encontrada (`U_...`) | Fonte do núcleo não compilado, ou compilado depois do módulo | Compilar `src/core` primeiro |
| "Type mismatch" num `local ... as json` | Valor de outro tipo atribuído | Conferir o tipo declarado. Não use `as variant`, que não é tipo do TLPP; deixe a variável sem tipo quando ela recebe mais de um tipo |

## Desempenho

- **Período:** a API recusa períodos de mais de 24 meses. Séries de um ano por dia são pesadas; o app pede por mês
  quando o período é um ano.
- **Índices:** os filtros principais seguem os índices padrão (filial + data). Consultas novas devem começar pela
  filial e pela data, que são os campos dos índices.
- **Cache:** cada resposta tem validade (`ttl`). Indicadores pesados devem usar `TTL_TAT` ou `TTL_EST`, não
  `TTL_OP`.
- **Balanço de matéria-prima:** faz uma consulta às OPs encerradas e três agrupadas por OP (produção, empenho e
  consumo). Na mesma requisição, os cartões reaproveitam o resultado (`TDashPcpApi:materials`).
- **Timeout do app:** 30 segundos por chamada. Uma consulta mais lenta que isso aparece como "O servidor demorou para
  responder."

## Diagnósticos (somente leitura)

| Script | Para quê |
|---|---|
| `tools/diagnostico-visao-gerencial.sql` e `-2.sql` | Conhecer as visões gerenciais (CVE/CTS) e os saldos da CQ0 do cliente |
| `tools/diagnostico-rh.sql` | Categorias, motivos de desligamento, tipos de ausência, roteiros e verbas que parecem hora extra |
| `tools/diagnostico-acesso.tlpp` | Menus do usuário e dos grupos e os módulos que o TDash libera para ele |

Os scripts SQL só fazem `SELECT` e não trazem dado de pessoa. Troque o sufixo da empresa (`010`) e os códigos indicados no
cabeçalho de cada script.

O diagnóstico de acesso é um fonte TLPP: compile e execute pelo Configurador > Fórmulas (ou outra tela que execute
uma expressão) `tdash.tools.u_tdAcessoDiag("login.do.usuario")`. Ele mostra os menus (`PswRet()[3]`), os grupos, os
menus de cada grupo (`FWGrpMenu`), os números de módulo lidos e as siglas liberadas, no console do AppServer e numa
janela. Não altera nada.
