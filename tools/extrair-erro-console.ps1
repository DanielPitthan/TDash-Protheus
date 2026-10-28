<#
.SYNOPSIS
    TDash: copia do console.log do AppServer as linhas de erro do TDash (somente leitura).
.DESCRIPTION
    Procura as linhas com TDASH / TDashComApi / THREAD ERROR e grava cada ocorrencia com 30 linhas depois
    em tdash-erros.txt (na pasta atual). Mande esse arquivo para analise.
.EXAMPLE
    .\extrair-erro-console.ps1 -ConsoleLog "C:\TOTVS\Protheus\bin\appserver\console.log"
#>
param(
    [Parameter(Mandatory = $true)] [string] $ConsoleLog,
    [int] $Last = 20,
    [string] $Out = ".\tdash-erros.txt"
)

$hits = Select-String -Path $ConsoleLog -Pattern 'TDASH|TDashComApi|tdash\.com|THREAD ERROR' -Context 2, 30 |
    Select-Object -Last $Last
if (-not $hits) {
    Write-Host "Nenhuma linha do TDash encontrada em $ConsoleLog. Confira o caminho (chave ConsoleFile do appserver.ini)."
    return
}
$hits | ForEach-Object { "==== linha $($_.LineNumber)"; $_.Context.PreContext; $_.Line; $_.Context.PostContext } |
    Set-Content -Path $Out -Encoding UTF8
Write-Host "Gravado $Out com $($hits.Count) ocorrencias."
