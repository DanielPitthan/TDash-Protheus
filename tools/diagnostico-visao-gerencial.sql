-- TDash: diagnóstico das Visões Gerenciais (CVE/CTS) e dos saldos contábeis (CQ0/CQ1)
--
-- SOMENTE LEITURA: só SELECT, nada é criado nem alterado.
-- Objetivo: ver como as visões do cliente são feitas, para decidir como o TDash calcula a DRE e o Balanço.
-- Os resultados não têm dados de pessoas; podem ser compartilhados.
--
-- Antes de rodar:
--   * Troque o sufixo 010 (empresa 01) pelo da empresa que o TDash vai usar (CVE010, CTS010, CQ0010, CQ1010).
--   * Escrito para SQL Server. Em outro banco, troque SUBSTRING por SUBSTR (Oracle).
--   * Nas consultas 3 e 4, troque 'XXX' pelo código da visão da DRE e do Balanço (resultado da consulta 1).

-- 1) Visões cadastradas
SELECT CVE_FILIAL, CVE_CODIGO, CVE_DESCRI
FROM CVE010
WHERE D_E_L_E_T_ = ' '
ORDER BY CVE_CODIGO;

-- 2) Perfil das linhas de cada visão: quantas são sintéticas/analíticas e quantas usam recursos que o TDash
--    ainda não calcula (centro de custo, item, classe de valor, fórmula, tipo de saldo diferente de real)
SELECT CTS_CODPLA AS VISAO,
       COUNT(*) AS LINHAS,
       SUM(CASE WHEN CTS_CLASSE = '1' THEN 1 ELSE 0 END) AS SINTETICAS,
       SUM(CASE WHEN CTS_CLASSE = '2' THEN 1 ELSE 0 END) AS ANALITICAS,
       SUM(CASE WHEN CTS_CT1INI <> ' ' THEN 1 ELSE 0 END) AS COM_FAIXA_DE_CONTA,
       SUM(CASE WHEN CTS_CTTINI <> ' ' OR CTS_CTDINI <> ' ' OR CTS_CTHINI <> ' ' THEN 1 ELSE 0 END) AS COM_CC_ITEM_OU_CLVL,
       SUM(CASE WHEN CTS_FORMUL <> ' ' THEN 1 ELSE 0 END) AS COM_FORMULA,
       SUM(CASE WHEN CTS_TPSALD NOT IN (' ', '1') THEN 1 ELSE 0 END) AS COM_SALDO_NAO_REAL
FROM CTS010
WHERE D_E_L_E_T_ = ' '
GROUP BY CTS_CODPLA
ORDER BY CTS_CODPLA;

-- 2b) Identificador das linhas (normal, negrito, total, separador...) por visão
SELECT CTS_CODPLA AS VISAO, CTS_IDENT AS IDENTIFICADOR, CTS_CLASSE AS CLASSE, COUNT(*) AS LINHAS
FROM CTS010
WHERE D_E_L_E_T_ = ' '
GROUP BY CTS_CODPLA, CTS_IDENT, CTS_CLASSE
ORDER BY CTS_CODPLA, CTS_IDENT, CTS_CLASSE;

-- 3) Linhas de uma visão, na ordem (rode uma vez para a DRE e outra para o Balanço)
SELECT CTS_ORDEM, CTS_CONTAG, CTS_CTASUP, CTS_DESCCG, CTS_CLASSE, CTS_IDENT, CTS_NORMAL,
       CTS_CT1INI, CTS_CT1FIM, CTS_CTTINI, CTS_CTDINI, CTS_CTHINI, CTS_FORMUL, CTS_TPSALD
FROM CTS010
WHERE D_E_L_E_T_ = ' '
  AND CTS_CODPLA = 'XXX'
ORDER BY CTS_ORDEM;

-- 4) Saldos disponíveis por mês, moeda e tipo de saldo (CQ0 é o saldo por conta)
SELECT SUBSTRING(CQ0_DATA, 1, 6) AS MES, CQ0_MOEDA AS MOEDA, CQ0_TPSALD AS TIPO_SALDO,
       COUNT(*) AS REGISTROS, SUM(CQ0_DEBITO) AS DEBITO, SUM(CQ0_CREDIT) AS CREDITO
FROM CQ0010
WHERE D_E_L_E_T_ = ' '
GROUP BY SUBSTRING(CQ0_DATA, 1, 6), CQ0_MOEDA, CQ0_TPSALD
ORDER BY MES DESC, MOEDA, TIPO_SALDO;

-- 5) Quantos registros há nas tabelas de saldo por conta (mês e dia)
SELECT 'CQ0 (mês)' AS TABELA, COUNT(*) AS REGISTROS FROM CQ0010 WHERE D_E_L_E_T_ = ' '
UNION ALL
SELECT 'CQ1 (dia)', COUNT(*) FROM CQ1010 WHERE D_E_L_E_T_ = ' ';
