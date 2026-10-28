<#
.SYNOPSIS
    Teste rápido das APIs TDash publicadas no REST do Protheus.

.DESCRIPTION
    Chama /core/branches, /core/modules, os painéis personalizados de exemplo (/custom) e as rotas do Financeiro, Faturamento, Compras, Estoque, Produção, Livros Fiscais, Contabilidade e RH e grava cada resposta (status + JSON)
    em uma pasta de resultados. A senha é pedida no terminal, não aparece na tela e não é gravada
    em nenhum arquivo. Os arquivos de resultado não contêm credenciais e podem ser compartilhados.

    Quando uma chamada de KPIs devolve 500, o teste repete um indicador por vez e mostra qual falhou.

.EXAMPLE
    .\smoke-test.ps1 -BaseUrl "https://cliente.protheus.cloudtotvs.com.br:1557/api" -User "usuario" -Company "01" -Branch "0101" -IncomeView "100" -BalanceView "003" -OvertimeCodes "179,181,184"

.EXAMPLE
    .\smoke-test.ps1 -BaseUrl "https://cliente.protheus.cloudtotvs.com.br:1557/api" -User "usuario" -Company "01" -Branch "0101" -Module "EST,CTB" -IncomeView "100" -BalanceView "003"
#>
param(
    [Parameter(Mandatory = $true)] [string] $BaseUrl,
    [Parameter(Mandatory = $true)] [string] $User,
    [Parameter(Mandatory = $true)] [string] $Company,
    [Parameter(Mandatory = $true)] [string] $Branch,
    [string] $OutDir = ".\smoke-results",
    # Visões gerenciais (CTS_CODPLA) da DRE e do Balanço; sem elas, a Contabilidade testa só catálogo e lista de visões
    [string] $IncomeView = "",
    [string] $BalanceView = "",
    # Verbas de hora extra do RH (ex.: "179,181,184"); sem elas, o RH testa só o 422 de "configure as verbas"
    [string] $OvertimeCodes = "",
    # Cliente e fornecedor para a posição financeira (código, sem loja); sem eles, testa só a busca
    [string] $CustomerCode = "",
    [string] $SupplierCode = "",
    [string] $PartySearch = "LTDA",
    # Só as rotas destes módulos (ex.: "EST" ou "EST,CTB"); vazio = todos
    [string] $Module = ""
)

$ErrorActionPreference = "Stop"
$securePassword = Read-Host -Prompt "Senha do usuário $User (não será exibida nem gravada)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${User}:${plain}"))
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Variable plain -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$api = $BaseUrl.TrimEnd('/') + "/tdash/v1"
$tenant = "$Company,$Branch"
$today = Get-Date
$monthStart = (Get-Date -Day 1).ToString("yyyyMMdd")
$todayText = $today.ToString("yyyyMMdd")
$yearStart = (Get-Date -Month 1 -Day 1).ToString("yyyyMMdd")
$sixMonthsStart = (Get-Date -Day 1).AddMonths(-5).ToString("yyyyMMdd")

$calls = @(
    @{ Name = "01-core-branches";            Module = "FAT"; Path = "core/branches";                                 Tenant = $false },
    @{ Name = "01b-core-modules";            Module = "FAT"; Path = "core/modules";                                  Tenant = $false },
    @{ Name = "02-fin-catalog";              Module = "FIN"; Path = "fin/catalog";                                   Tenant = $true },
    @{ Name = "03-fin-kpis-receber";         Module = "FIN"; Path = "fin/kpis?ids=fin.receivable_open,fin.receivable_overdue,fin.receivable_due,fin.default_rate&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "04-fin-kpis-pagar";           Module = "FIN"; Path = "fin/kpis?ids=fin.payable_open,fin.payable_overdue,fin.payable_due&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "05-fin-kpis-prazos";          Module = "FIN"; Path = "fin/kpis?ids=fin.dso,fin.dpo&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "06-fin-kpis-banco";           Module = "FIN"; Path = "fin/kpis?ids=fin.bank_balance";                Tenant = $true },
    @{ Name = "07-fin-aging-receber";        Module = "FIN"; Path = "fin/breakdown/fin.aging_receivable";           Tenant = $true },
    @{ Name = "08-fin-aging-pagar";          Module = "FIN"; Path = "fin/breakdown/fin.aging_payable";              Tenant = $true },
    @{ Name = "09-fin-top-devedores";        Module = "FIN"; Path = "fin/breakdown/fin.top_debtors?top=5";          Tenant = $true },
    @{ Name = "10-fin-top-credores";         Module = "FIN"; Path = "fin/breakdown/fin.top_creditors?top=5";        Tenant = $true },
    @{ Name = "11-fin-saldo-por-conta";      Module = "FIN"; Path = "fin/breakdown/fin.bank_balance";               Tenant = $true },
    @{ Name = "12-fin-caixa-por-conta";      Module = "FIN"; Path = "fin/breakdown/fin.cash_by_bank?dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "13-fin-fluxo-projetado";      Module = "FIN"; Path = "fin/series/fin.cashflow_projection?grain=week"; Tenant = $true },
    @{ Name = "14-fin-caixa-realizado";      Module = "FIN"; Path = "fin/series/fin.cash_realized?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "15-fin-vencidos-receber";     Module = "FIN"; Path = "fin/list/fin.overdue_receivables?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "16-fin-vencidos-pagar";       Module = "FIN"; Path = "fin/list/fin.overdue_payables?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "17-fin-indicador-inexistente"; Module = "FIN"; Path = "fin/kpis?ids=fin.nao_existe";                 Tenant = $true },
    @{ Name = "17a-fin-busca-cliente";       Module = "FIN"; Path = "fin/list/fin.party_search?type=customer&search=$([uri]::EscapeDataString($PartySearch))"; Tenant = $true },
    @{ Name = "17b-fin-busca-fornecedor";    Module = "FIN"; Path = "fin/list/fin.party_search?type=supplier&search=$([uri]::EscapeDataString($PartySearch))"; Tenant = $true },
    @{ Name = "18-fat-kpis";                 Module = "FAT"; Path = "fat/kpis?ids=fat.revenue,fat.revenue_net,fat.invoice_count,fat.avg_ticket,fat.returns,fat.target_attainment,fat.backlog&dateFrom=$monthStart&dateTo=$todayText&compare=yoy"; Tenant = $true },
    @{ Name = "19-fat-serie-faturamento";    Module = "FAT"; Path = "fat/series/fat.revenue?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "20-fat-top-clientes";         Module = "FAT"; Path = "fat/breakdown/fat.top_customers?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "21-fat-top-produtos";         Module = "FAT"; Path = "fat/breakdown/fat.top_products?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "22-fat-por-vendedor";         Module = "FAT"; Path = "fat/breakdown/fat.by_seller?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "23-fat-por-uf";               Module = "FAT"; Path = "fat/breakdown/fat.by_state?top=10&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "24-fat-carteira";             Module = "FAT"; Path = "fat/list/fat.backlog?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "24b-fat-resultado";           Module = "FAT"; Path = "fat/kpis?ids=fat.gross_profit,fat.net_profit,fat.taxes&dateFrom=$monthStart&dateTo=$todayText&compare=yoy"; Tenant = $true },
    @{ Name = "24c-fat-resultado-reforma";   Module = "FAT"; Path = "fat/kpis?ids=fat.net_profit,fat.taxes&dateFrom=$monthStart&dateTo=$todayText&compare=none&taxRegime=reform"; Tenant = $true },
    @{ Name = "24d-fat-resultado-serie";     Module = "FAT"; Path = "fat/series/fat.result?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "24e-fat-impostos-por-tipo";   Module = "FAT"; Path = "fat/breakdown/fat.taxes_by_type?dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "25-com-kpis";                 Module = "COM"; Path = "com/kpis?ids=com.purchases,com.po_open,com.po_late,com.po_awaiting_approval,com.pr_pending,com.lead_time_request,com.lead_time_delivery&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "26-com-serie-compras";        Module = "COM"; Path = "com/series/com.purchases?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "27-com-preco-medio";          Module = "COM"; Path = "com/series/com.price_evolution?dateFrom=$yearStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "28-com-top-fornecedores";     Module = "COM"; Path = "com/breakdown/com.top_suppliers?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "29-com-pedidos-atrasados";    Module = "COM"; Path = "com/list/com.po_late?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "30-com-solicitacoes";         Module = "COM"; Path = "com/list/com.pr_pending?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "30b-com-acompanhamento";      Module = "COM"; Path = "com/kpis?ids=com.trace_requested,com.trace_ordered,com.trace_delivered,com.trace_unordered&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "30c-com-acompanhamento-serie"; Module = "COM"; Path = "com/series/com.trace?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "30d-com-acompanhamento-itens"; Module = "COM"; Path = "com/list/com.trace_items?page=1&pageSize=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "31-est-catalog";              Module = "EST"; Path = "est/catalog";                                   Tenant = $true },
    @{ Name = "32-est-kpis";                 Module = "EST"; Path = "est/kpis?ids=est.stock_value,est.below_reorder,est.coverage_days,est.turnover,est.no_movement,est.lots_expiring,est.cogs&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "33-est-valor-por-armazem";    Module = "EST"; Path = "est/breakdown/est.stock_value?dimension=local&top=5";  Tenant = $true },
    @{ Name = "34-est-valor-por-tipo";       Module = "EST"; Path = "est/breakdown/est.stock_value?dimension=type&top=5";   Tenant = $true },
    @{ Name = "35-est-valor-por-grupo";      Module = "EST"; Path = "est/breakdown/est.stock_value?dimension=group&top=5";  Tenant = $true },
    @{ Name = "36-est-curva-abc";            Module = "EST"; Path = "est/breakdown/est.abc_curve";                   Tenant = $true },
    @{ Name = "37-est-cmv-serie";            Module = "EST"; Path = "est/series/est.cogs?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "38-est-custo-medio";          Module = "EST"; Path = "est/series/est.avg_cost_evolution?dateFrom=$yearStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "39-est-abaixo-ponto-pedido";  Module = "EST"; Path = "est/list/est.below_reorder?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "40-est-sem-movimento";        Module = "EST"; Path = "est/list/est.no_movement?page=1&pageSize=5";   Tenant = $true },
    @{ Name = "41-est-lotes";                Module = "EST"; Path = "est/list/est.lots_expiring?page=1&pageSize=5"; Tenant = $true },
    @{ Name = "42-est-indicador-inexistente"; Module = "EST"; Path = "est/kpis?ids=est.nao_existe";                 Tenant = $true },
    @{ Name = "43-pcp-catalog";              Module = "PCP"; Path = "pcp/catalog";                                   Tenant = $true },
    @{ Name = "44-pcp-kpis";                 Module = "PCP"; Path = "pcp/kpis?ids=pcp.po_open,pcp.po_late,pcp.po_closed,pcp.plan_attainment,pcp.losses&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "45-pcp-producao-diaria";      Module = "PCP"; Path = "pcp/series/pcp.production_daily?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "46-pcp-perdas";               Module = "PCP"; Path = "pcp/series/pcp.losses?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "47-pcp-top-produtos";         Module = "PCP"; Path = "pcp/breakdown/pcp.top_products?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "48-pcp-horas-recurso";        Module = "PCP"; Path = "pcp/breakdown/pcp.hours_by_resource?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "48a-pcp-horas-serie";         Module = "PCP"; Path = "pcp/series/pcp.hours?grain=day&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "48b-pcp-produtividade";       Module = "PCP"; Path = "pcp/breakdown/pcp.productivity?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "48c-pcp-materia-prima-kpis";  Module = "PCP"; Path = "pcp/kpis?ids=pcp.hours,pcp.material_reserved,pcp.material_consumed,pcp.material_produced,pcp.material_loss,pcp.material_loss_rate,pcp.material_returned&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "48d-pcp-perda-por-produto";   Module = "PCP"; Path = "pcp/breakdown/pcp.material_loss_by_product?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "48e-pcp-materia-prima-ops";   Module = "PCP"; Path = "pcp/list/pcp.material_orders?page=1&pageSize=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "49-pcp-ops-atrasadas";        Module = "PCP"; Path = "pcp/list/pcp.po_late?page=1&pageSize=5";       Tenant = $true },
    @{ Name = "50-pcp-indicador-inexistente"; Module = "PCP"; Path = "pcp/kpis?ids=pcp.nao_existe";                 Tenant = $true },
    @{ Name = "51-fis-catalog";              Module = "FIS"; Path = "fis/catalog";                                   Tenant = $true },
    @{ Name = "52-fis-kpis";                 Module = "FIS"; Path = "fis/kpis?ids=fis.icms_balance,fis.ipi_balance,fis.pis_cofins,fis.iss,fis.icms_st,fis.difal,fis.cancelled&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "53-fis-icms-serie";           Module = "FIS"; Path = "fis/series/fis.icms_balance?dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "54-fis-ipi-serie";            Module = "FIS"; Path = "fis/series/fis.ipi_balance?dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "55-fis-pis-cofins-serie";     Module = "FIS"; Path = "fis/series/fis.pis_cofins?dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "56-fis-por-cfop";             Module = "FIS"; Path = "fis/breakdown/fis.by_cfop?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "57-fis-por-uf";               Module = "FIS"; Path = "fis/breakdown/fis.by_state?top=10&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58a-fis-visao-geral-kpis";    Module = "FIS"; Path = "fis/kpis?ids=fis.tax_burden,fis.ledger_balance,fis.ledger_debit,fis.ledger_credit&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true },
    @{ Name = "58b-fis-debitos-creditos";    Module = "FIS"; Path = "fis/series/fis.ledger_trend?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58c-fis-centralizacao";       Module = "FIS"; Path = "fis/list/fis.ledger?scope=branch&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58d-fis-centralizacao-filiais"; Module = "FIS"; Path = "fis/list/fis.ledger?scope=all&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58e-fis-participantes";       Module = "FIS"; Path = "fis/breakdown/fis.top_parties?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58f-fis-ncm";                 Module = "FIS"; Path = "fis/breakdown/fis.top_ncm?top=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58g-fis-entradas-por-uf";     Module = "FIS"; Path = "fis/breakdown/fis.by_state_in?top=27&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "58-fis-canceladas";           Module = "FIS"; Path = "fis/list/fis.cancelled?page=1&pageSize=5&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true },
    @{ Name = "59-fis-indicador-inexistente"; Module = "FIS"; Path = "fis/kpis?ids=fis.nao_existe";                 Tenant = $true }
)

# Contabilidade: as rotas de demonstração dependem das visões informadas
$calls += ,@{ Name = "60-ctb-catalog";  Module = "CTB"; Path = "ctb/catalog"; Tenant = $true }
$calls += ,@{ Name = "61-ctb-visoes";   Module = "CTB"; Path = "ctb/list/ctb.views?page=1&pageSize=50"; Tenant = $true }
if ($IncomeView) {
    $calls += ,@{ Name = "62-ctb-linhas-dre"; Module = "CTB"; Path = "ctb/list/ctb.view_lines?view=$IncomeView&page=1&pageSize=100"; Tenant = $true }
    $calls += ,@{ Name = "63-ctb-dre";        Module = "CTB"; Path = "ctb/breakdown/ctb.income_statement?view=$IncomeView&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true }
}
if ($BalanceView) {
    $calls += ,@{ Name = "64-ctb-balanco";    Module = "CTB"; Path = "ctb/breakdown/ctb.balance_sheet?view=$BalanceView&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true }
}
$calls += ,@{ Name = "65-ctb-visao-inexistente"; Module = "CTB"; Path = "ctb/breakdown/ctb.income_statement?view=ZZZ&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }

# Recursos Humanos: só números agrupados; as horas extras dependem das verbas informadas
$calls += ,@{ Name = "66-gpe-catalog";          Module = "GPE"; Path = "gpe/catalog"; Tenant = $true }
$calls += ,@{ Name = "67-gpe-kpis";             Module = "GPE"; Path = "gpe/kpis?ids=gpe.headcount,gpe.hires,gpe.terminations,gpe.turnover,gpe.absenteeism,gpe.payroll&dateFrom=$monthStart&dateTo=$todayText&compare=prev"; Tenant = $true }
$calls += ,@{ Name = "68-gpe-movimentos";       Module = "GPE"; Path = "gpe/series/gpe.movements?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "69-gpe-folha-mensal";     Module = "GPE"; Path = "gpe/series/gpe.payroll?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "70-gpe-quadro-cc";        Module = "GPE"; Path = "gpe/breakdown/gpe.headcount?dimension=cc&top=10&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "71-gpe-quadro-funcao";    Module = "GPE"; Path = "gpe/breakdown/gpe.headcount?dimension=role&top=10&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "72-gpe-perfil-idade";     Module = "GPE"; Path = "gpe/breakdown/gpe.demographics?dimension=age&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "73-gpe-perfil-tempo";     Module = "GPE"; Path = "gpe/breakdown/gpe.demographics?dimension=tenure&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "74-gpe-ausencias";        Module = "GPE"; Path = "gpe/breakdown/gpe.absenteeism?top=10&dateFrom=$sixMonthsStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "75-gpe-folha-cc";         Module = "GPE"; Path = "gpe/breakdown/gpe.payroll_by_cc?top=10&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
$calls += ,@{ Name = "76-gpe-verbas";           Module = "GPE"; Path = "gpe/list/gpe.payroll_codes?page=1&pageSize=100"; Tenant = $true }
$calls += ,@{ Name = "77-gpe-horas-extras-sem-verbas"; Module = "GPE"; Path = "gpe/kpis?ids=gpe.overtime&dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }
if ($CustomerCode) {
    $party = "type=customer&code=$CustomerCode"
    $calls += ,@{ Name = "17c-fin-posicao-cliente";        Module = "FIN"; Path = "fin/kpis?ids=fin.party_open,fin.party_overdue,fin.party_not_due,fin.party_settled,fin.party_credit_limit,fin.party_credit_available&dateFrom=$monthStart&dateTo=$todayText&compare=prev&$party"; Tenant = $true }
    $calls += ,@{ Name = "17d-fin-posicao-cliente-aging";  Module = "FIN"; Path = "fin/breakdown/fin.party_aging?$party"; Tenant = $true }
    $calls += ,@{ Name = "17e-fin-posicao-cliente-serie";  Module = "FIN"; Path = "fin/series/fin.party_settled?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText&$party"; Tenant = $true }
    $calls += ,@{ Name = "17f-fin-posicao-cliente-titulos"; Module = "FIN"; Path = "fin/list/fin.party_titles?page=1&pageSize=5&$party"; Tenant = $true }
    $calls += ,@{ Name = "17g-fin-posicao-cliente-lojas";  Module = "FIN"; Path = "fin/list/fin.party_stores?page=1&pageSize=100&$party"; Tenant = $true }
}
if ($SupplierCode) {
    $party = "type=supplier&code=$SupplierCode"
    $calls += ,@{ Name = "17h-fin-posicao-fornecedor";       Module = "FIN"; Path = "fin/kpis?ids=fin.party_open,fin.party_overdue,fin.party_not_due,fin.party_settled&dateFrom=$monthStart&dateTo=$todayText&compare=prev&$party"; Tenant = $true }
    $calls += ,@{ Name = "17i-fin-posicao-fornecedor-lojas"; Module = "FIN"; Path = "fin/list/fin.party_stores?page=1&pageSize=100&$party"; Tenant = $true }
}
if ($OvertimeCodes) {
    $calls += ,@{ Name = "78-gpe-horas-extras";       Module = "GPE"; Path = "gpe/kpis?ids=gpe.overtime,gpe.overtime_hours&dateFrom=$monthStart&dateTo=$todayText&compare=prev&overtimeCodes=$OvertimeCodes"; Tenant = $true }
    $calls += ,@{ Name = "79-gpe-horas-extras-serie"; Module = "GPE"; Path = "gpe/series/gpe.overtime?grain=month&dateFrom=$sixMonthsStart&dateTo=$todayText&overtimeCodes=$OvertimeCodes"; Tenant = $true }
}

# Painéis personalizados de exemplo (09-painel-personalizado.md); filtre com -Module CUSTOM
$calls += ,@{ Name = "90-custom-mock";    Module = "CUSTOM"; ErpModule = "FAT"; Path = "custom/mock?dateFrom=$monthStart&dateTo=$todayText";    Tenant = $true }
$calls += ,@{ Name = "91-custom-exemplo"; Module = "CUSTOM"; ErpModule = "FAT"; Path = "custom/exemplo?dateFrom=$monthStart&dateTo=$todayText"; Tenant = $true }

if ($Module) {
    $wanted = $Module.ToUpper().Split(',') | ForEach-Object { $_.Trim() }
    $calls = @($calls | Where-Object { $wanted -contains $_.Module })
}

# Uma chamada GET: devolve status, corpo e tempo. Falha de conexão vira status 0.
function Invoke-TDashCall([string] $Path, [string] $ErpModule, [bool] $WithTenant) {
    $headers = @{ "Authorization" = "Basic $basic"; "x-erp-module" = $ErpModule; "Accept" = "application/json" }
    if ($WithTenant) { $headers["tenantid"] = $tenant }

    $watch = [Diagnostics.Stopwatch]::StartNew()
    $status = 0
    $body = ""
    try {
        $response = Invoke-WebRequest -Uri "$api/$Path" -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 60
        $status = [int]$response.StatusCode
        $body = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
    }
    catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            # PowerShell 5.1 já consumiu o stream do erro; o corpo fica em ErrorDetails
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $body = $_.ErrorDetails.Message
            }
            else {
                $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $body = $reader.ReadToEnd()
            }
        }
        else {
            $body = "FALHA DE CONEXÃO: $($_.Exception.Message)"
        }
    }
    $watch.Stop()
    return [pscustomobject]@{ Status = $status; Body = $body; Ms = $watch.ElapsedMilliseconds }
}

$summary = @()
foreach ($call in $calls) {
    # Module filtra as chamadas (-Module); ErpModule, quando existe, vai no header x-erp-module
    $erpModule = $call.Module
    if ($call.ErpModule) { $erpModule = $call.ErpModule }
    $result = Invoke-TDashCall $call.Path $erpModule $call.Tenant

    Set-Content -Path (Join-Path $OutDir "$($call.Name).json") -Value $result.Body -Encoding utf8
    $summary += [pscustomobject]@{ Teste = $call.Name; Status = $result.Status; Ms = $result.Ms; Rota = $call.Path.Split('?')[0] }
    Write-Host ("{0,-32} {1,4}  {2,6} ms" -f $call.Name, $result.Status, $result.Ms)

    # Usuário ou senha recusados: parar já, para não acumular tentativas e bloquear o usuário
    if ($result.Status -eq 401) {
        Write-Host ""
        Write-Host "401 em $($call.Name): o REST recusou o usuário ou a senha. Teste interrompido." -ForegroundColor Red
        Write-Host "Confira o usuário e a senha (a digitação não aparece) e se o usuário não está bloqueado." -ForegroundColor Red
        break
    }

    # KPIs com erro 500: repete um indicador por vez para mostrar qual falhou
    if ($result.Status -eq 500 -and $call.Path -match 'kpis\?ids=([^&]+)') {
        foreach ($id in $Matches[1].Split(',')) {
            $single = $call.Path -replace 'ids=[^&]+', "ids=$id"
            $part = Invoke-TDashCall $single $erpModule $call.Tenant
            $partName = "$($call.Name).$id"
            Set-Content -Path (Join-Path $OutDir "$partName.json") -Value $part.Body -Encoding utf8
            $summary += [pscustomobject]@{ Teste = $partName; Status = $part.Status; Ms = $part.Ms; Rota = $single.Split('?')[0] }
            Write-Host ("  {0,-30} {1,4}  {2,6} ms" -f $id, $part.Status, $part.Ms)
        }
    }
}

$basic = $null
$summary | Export-Csv -Path (Join-Path $OutDir "resumo.csv") -NoTypeInformation -Encoding utf8
Write-Host ""
Write-Host "Resultados em $((Resolve-Path $OutDir).Path) (sem credenciais)."
if ($summary | Where-Object { $_.Status -eq 500 }) {
    Write-Host "Erro 500: o detalhe fica no console.log do AppServer REST (procure por TDASH)." -ForegroundColor Yellow
}
Write-Host "Esperado: 200 em todos, exceto 17-fin-indicador-inexistente, 42-est-indicador-inexistente, 50-pcp-indicador-inexistente e 59-fis-indicador-inexistente = 404; 65-ctb-visao-inexistente e 77-gpe-horas-extras-sem-verbas = 422."
