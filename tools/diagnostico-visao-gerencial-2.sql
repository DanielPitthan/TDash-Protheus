-- TDash: diagnóstico 2 das Visões Gerenciais (segunda rodada, já preenchido para as visões 003 e 100)
--
-- SOMENTE LEITURA: só SELECT, nada é criado nem alterado.
-- Na primeira rodada, 147 das 148 linhas analíticas do Balanço (003) e 126 das 135 da DRE (100) apareceram com
-- centro de custo, item ou classe de valor preenchidos. Estas consultas mostram O QUE está preenchido:
-- se é um filtro de verdade (o saldo não vem da CQ0) ou só a faixa "todos".
--
-- Troque o sufixo 010 pela empresa, se for outra. Escrito para SQL Server.

-- 6) Faixas de centro de custo, item e classe de valor das linhas analíticas (o mais importante)
SELECT CTS_CODPLA AS VISAO,
       CTS_CTTINI, CTS_CTTFIM, CTS_CTDINI, CTS_CTDFIM, CTS_CTHINI, CTS_CTHFIM,
       COUNT(*) AS LINHAS
FROM CTS010
WHERE D_E_L_E_T_ = ' '
  AND CTS_CODPLA IN ('003', '100')
  AND CTS_CLASSE = '2'
GROUP BY CTS_CODPLA, CTS_CTTINI, CTS_CTTFIM, CTS_CTDINI, CTS_CTDFIM, CTS_CTHINI, CTS_CTHFIM
ORDER BY CTS_CODPLA, LINHAS DESC;

-- 7) Linhas sintéticas (subtotais e totais) das duas visões: mostra a hierarquia
SELECT CTS_CODPLA AS VISAO, CTS_ORDEM, CTS_CONTAG, CTS_CTASUP, CTS_DESCCG, CTS_IDENT, CTS_NORMAL
FROM CTS010
WHERE D_E_L_E_T_ = ' '
  AND CTS_CODPLA IN ('003', '100')
  AND CTS_CLASSE = '1'
ORDER BY CTS_CODPLA, CTS_ORDEM;

-- 8) As primeiras 20 linhas de cada visão, em ordem (todas as classes): mostra como analíticas e sintéticas se misturam
SELECT TOP 20 CTS_CODPLA AS VISAO, CTS_ORDEM, CTS_CONTAG, CTS_CTASUP, CTS_DESCCG, CTS_CLASSE, CTS_IDENT, CTS_NORMAL,
       CTS_CT1INI, CTS_CT1FIM, CTS_CTTINI, CTS_CTTFIM
FROM CTS010
WHERE D_E_L_E_T_ = ' ' AND CTS_CODPLA = '003'
ORDER BY CTS_ORDEM;

SELECT TOP 20 CTS_CODPLA AS VISAO, CTS_ORDEM, CTS_CONTAG, CTS_CTASUP, CTS_DESCCG, CTS_CLASSE, CTS_IDENT, CTS_NORMAL,
       CTS_CT1INI, CTS_CT1FIM, CTS_CTTINI, CTS_CTTFIM
FROM CTS010
WHERE D_E_L_E_T_ = ' ' AND CTS_CODPLA = '100'
ORDER BY CTS_ORDEM;

-- 9) Em que filiais as visões existem (a CVE tem 10 e 20; confirma na CTS)
SELECT CTS_FILIAL, CTS_CODPLA AS VISAO, COUNT(*) AS LINHAS
FROM CTS010
WHERE D_E_L_E_T_ = ' ' AND CTS_CODPLA IN ('003', '100')
GROUP BY CTS_FILIAL, CTS_CODPLA
ORDER BY CTS_CODPLA, CTS_FILIAL;

-- 10) Saldos de dezembro de 2025 por sinalizador de apuração (lucros e perdas) e status, só moeda 01 e saldo real
SELECT CQ0_LP AS LUCROS_PERDAS, CQ0_STATUS AS STATUS, COUNT(*) AS REGISTROS,
       SUM(CQ0_DEBITO) AS DEBITO, SUM(CQ0_CREDIT) AS CREDITO
FROM CQ0010
WHERE D_E_L_E_T_ = ' '
  AND CQ0_MOEDA = '01'
  AND CQ0_TPSALD = '1'
  AND CQ0_DATA BETWEEN '20251201' AND '20251231'
GROUP BY CQ0_LP, CQ0_STATUS
ORDER BY CQ0_LP, CQ0_STATUS;
