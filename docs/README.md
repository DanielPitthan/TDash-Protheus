# TDash — Documentação técnica das APIs (TLPP)

Para quem vai manter ou customizar as APIs do TDash no Protheus. Mostra:

- como as APIs estão organizadas;
- o JSON exato que o app espera em cada rota;
- como mudar uma regra ou criar um indicador sem quebrar o app.

| Documento | Conteúdo |
|---|---|
| [01 — Arquitetura](01-arquitetura.md) | Camadas, caminho de uma requisição, organização dos fontes, convenções, segurança, log e parâmetros |
| [02 — Contrato de resposta](02-contrato-de-resposta.md) | **O que o app espera**: parâmetros, JSON de cada rota, tipos, unidades, erros e cache |
| [03 — Referência do núcleo](03-referencia-core.md) | Classes e funções de `src/core`, com assinatura, retorno e exemplo |
| [04 — Módulos](04-modulos.md) | Por módulo: fontes, indicadores, o que cada tela do app chama e onde fica cada regra |
| [05 — Customização](05-customizacao.md) | Passo a passo para mudar uma regra, criar um indicador, uma lista, um parâmetro ou um módulo; indicador sobre uma entidade (posição), SQL portável, datas e horas, exemplos de regras novas; testes, publicação e checklist |
| [06 — Mapa de regras](06-mapa-de-regras.md) | **Cada regra de negócio de cada módulo**: onde está, como mudar e o que muda junto; parâmetros que mudam regras sem compilar |
| [07 — Operação e problemas](07-operacao-e-problemas.md) | Implantação num cliente, conferência com os relatórios do Protheus, publicação, smoke test, log, erros da API, mensagens do app, erros do linter, desempenho |
| [08 — Histórico](08-historico.md) | O que mudou em cada versão |
| [09 — Painel personalizado](09-painel-personalizado.md) | **Painel montado pelo app a partir do seu endpoint**: contrato do JSON (`widgets`), `TDashPanelBuilder`, exemplo com dados fictícios para copiar |
| [10 — Catálogo de indicadores](10-catalogo-de-indicadores.md) | **Regra de negócio de cada indicador**: fórmula, campos, decisões |

## Outras referências

- **Regras de negócio** de cada indicador (fórmula, campos, decisões tomadas com o cliente):
  [`10-catalogo-de-indicadores.md`](10-catalogo-de-indicadores.md).
- **Contrato em OpenAPI:** [`../openapi/tdash-v1.yaml`](../openapi/tdash-v1.yaml).
- **Compilação, publicação e smoke test:** [`../README.md`](../README.md).
- **Site com manual do usuário e manual técnico:** <https://danielpitthan.github.io/TDash-Protheus/>.

## Por onde começar

| Quero... | Leia |
|---|---|
| Entender como as APIs funcionam | [01](01-arquitetura.md), depois [02](02-contrato-de-resposta.md) |
| Mudar como um número é calculado | [06](06-mapa-de-regras.md), depois a receita 1 da [05](05-customizacao.md) |
| Criar um indicador novo | Receitas 3 a 5 da [05](05-customizacao.md) |
| Publicar um painel de um processo customizado, sem versão nova do app | [09](09-painel-personalizado.md) |
| Implantar num cliente novo | [07](07-operacao-e-problemas.md) |
| Investigar um erro ou número diferente | [07](07-operacao-e-problemas.md) e [06](06-mapa-de-regras.md) |

## Resumo em uma página

- **Rotas:** cada módulo expõe as mesmas cinco rotas abaixo de `/tdash/v1/{módulo}`: `catalog`, `kpis`,
  `series/:id`, `breakdown/:id` e `list/:id`. O `id` do indicador precisa estar no **catálogo** do módulo; fora
  dele, a resposta é 404.
- **Requisição:** o app manda `Authorization: Basic`, `tenantid: {empresa},{filial}` e `x-erp-module`. O REST do
  Protheus valida tudo isso antes de chegar ao TDash, e a API não repete a validação.
- **Resposta:**
  - sempre JSON em UTF-8, com os nomes de campo do contrato (camelCase);
  - números como número JSON, datas como texto `AAAA-MM-DD`;
  - campo `ttl` (segundos), que o app usa como validade do cache.
- **Erros:** vêm no modelo TOTVS `{ code, message, detailedMessage, helpUrl }`, e o app mostra o `message`.
  Nunca devolva SQL ou detalhe técnico ao app: isso vai para o log do AppServer (grupo `TDASH`).
- **O que muda sem nova versão do app:**
  - nos cartões (`kpis`): título, unidade, sentido da cor e validade;
  - nas listas: colunas, rótulos e tipos;
  - os avisos (`warnings`) das quebras em que a tela já mostra avisos (Contabilidade e RH).

  Isso vem da API e aparece no app sem atualizá-lo. Nas barras e nos gráficos, a unidade de exibição é fixada pela
  tela do app.
- **O que exige nova versão do app:** indicador novo, tela nova e nome de série novo, porque a tela do app pede
  ids e séries pelo nome.
