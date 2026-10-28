-- TDash: diagnóstico do RH (SRA, SR8, RCM, SRD, SRC, SRV)
--
-- SOMENTE LEITURA: só SELECT, nada é criado nem alterado.
-- Objetivo: decidir quem conta no quadro, quais ausências entram no absenteísmo e quais roteiros formam a folha.
-- LGPD: todas as consultas devolvem só contagens e totais. Nenhuma traz nome, matrícula ou valor de uma pessoa.
--
-- Antes de rodar:
--   * Troque o sufixo 010 (empresa 01) pelo da empresa que o TDash vai usar (SRA010, SR8010, RCM010...).
--   * Escrito para SQL Server.

-- 1) Quadro por filial, situação na folha e categoria (ativos = sem data de demissão)
SELECT RA_FILIAL AS FILIAL, RA_SITFOLH AS SITUACAO, RA_CATFUNC AS CATEGORIA,
       COUNT(*) AS CADASTROS,
       SUM(CASE WHEN RA_DEMISSA = ' ' THEN 1 ELSE 0 END) AS SEM_DEMISSAO
FROM SRA010
WHERE D_E_L_E_T_ = ' '
GROUP BY RA_FILIAL, RA_SITFOLH, RA_CATFUNC
ORDER BY RA_FILIAL, RA_SITFOLH, RA_CATFUNC;

-- 2) Desligamentos dos últimos 24 meses por código de rescisão RAIS (30 e 31 = transferência)
SELECT RA_FILIAL AS FILIAL, RA_RESCRAI AS RESCISAO_RAIS, RA_SITFOLH AS SITUACAO, COUNT(*) AS DESLIGAMENTOS
FROM SRA010
WHERE D_E_L_E_T_ = ' '
  AND RA_DEMISSA >= CONVERT(CHAR(8), DATEADD(MONTH, -24, GETDATE()), 112)
GROUP BY RA_FILIAL, RA_RESCRAI, RA_SITFOLH
ORDER BY RA_FILIAL, RA_RESCRAI, RA_SITFOLH;

-- 3) Admissões e desligamentos por mês (últimos 13 meses), para conferir o turnover
SELECT 'ADMISSAO' AS EVENTO, SUBSTRING(RA_ADMISSA, 1, 6) AS MES, COUNT(*) AS PESSOAS
FROM SRA010
WHERE D_E_L_E_T_ = ' '
  AND RA_ADMISSA >= CONVERT(CHAR(8), DATEADD(MONTH, -13, GETDATE()), 112)
GROUP BY SUBSTRING(RA_ADMISSA, 1, 6)
UNION ALL
SELECT 'DESLIGAMENTO', SUBSTRING(RA_DEMISSA, 1, 6), COUNT(*)
FROM SRA010
WHERE D_E_L_E_T_ = ' '
  AND RA_DEMISSA >= CONVERT(CHAR(8), DATEADD(MONTH, -13, GETDATE()), 112)
GROUP BY SUBSTRING(RA_DEMISSA, 1, 6)
ORDER BY EVENTO, MES;

-- 4) Tipos de ausência usados nos últimos 12 meses (RCM_TIPOAF: 1 afastamento, 2 outras ausências,
--    3 informativo, 4 controle de dias de direito)
SELECT R8.R8_TIPOAFA AS CODIGO, MAX(RCM.RCM_DESCRI) AS DESCRICAO, MAX(RCM.RCM_TIPOAF) AS TIPO,
       COUNT(*) AS REGISTROS, SUM(R8.R8_DURACAO) AS DIAS
FROM SR8010 R8
LEFT JOIN RCM010 RCM ON RCM.RCM_TIPO = R8.R8_TIPOAFA AND RCM.D_E_L_E_T_ = ' '
WHERE R8.D_E_L_E_T_ = ' '
  AND R8.R8_DATAINI >= CONVERT(CHAR(8), DATEADD(MONTH, -12, GETDATE()), 112)
GROUP BY R8.R8_TIPOAFA
ORDER BY DIAS DESC;

-- 5) Folha fechada (SRD) por competência e roteiro, últimos 13 meses: proventos, descontos e bases
SELECT RD.RD_DATARQ AS COMPETENCIA, RD.RD_ROTEIR AS ROTEIRO,
       COUNT(DISTINCT RD.RD_FILIAL + RD.RD_MAT) AS PESSOAS,
       SUM(CASE WHEN RV.RV_TIPOCOD = '1' THEN RD.RD_VALOR ELSE 0 END) AS PROVENTOS,
       SUM(CASE WHEN RV.RV_TIPOCOD = '2' THEN RD.RD_VALOR ELSE 0 END) AS DESCONTOS,
       SUM(CASE WHEN RV.RV_TIPOCOD IN ('3', '4') THEN RD.RD_VALOR ELSE 0 END) AS BASES
FROM SRD010 RD
LEFT JOIN SRV010 RV ON RV.RV_COD = RD.RD_PD AND RV.D_E_L_E_T_ = ' '
WHERE RD.D_E_L_E_T_ = ' '
  AND RD.RD_DATARQ >= CONVERT(CHAR(6), DATEADD(MONTH, -13, GETDATE()), 112)
GROUP BY RD.RD_DATARQ, RD.RD_ROTEIR
ORDER BY RD.RD_DATARQ DESC, RD.RD_ROTEIR;

-- 6) Movimento do período em aberto (SRC): qual período e roteiro estão abertos
SELECT RC_PERIODO AS PERIODO, RC_ROTEIR AS ROTEIRO, COUNT(DISTINCT RC_FILIAL + RC_MAT) AS PESSOAS, COUNT(*) AS LANCAMENTOS
FROM SRC010
WHERE D_E_L_E_T_ = ' '
GROUP BY RC_PERIODO, RC_ROTEIR
ORDER BY RC_PERIODO DESC, RC_ROTEIR;

-- 7) Verbas que parecem hora extra (para conferir as que o usuário vai escolher no app)
SELECT RV_COD AS VERBA, RV_DESC AS DESCRICAO, RV_TIPOCOD AS TIPO
FROM SRV010
WHERE D_E_L_E_T_ = ' '
  AND (UPPER(RV_DESC) LIKE '%EXTRA%' OR UPPER(RV_DESC) LIKE '%H.E%' OR UPPER(RV_DESC) LIKE '%HE %')
ORDER BY RV_COD;

-- 8) Tamanho dos centros de custo (ativos): quantos grupos ficariam abaixo do mínimo da LGPD (5 pessoas)
SELECT FAIXA, COUNT(*) AS CENTROS_DE_CUSTO, SUM(PESSOAS) AS PESSOAS
FROM (
    SELECT RA_FILIAL, RA_CC, COUNT(*) AS PESSOAS,
           CASE WHEN COUNT(*) < 5 THEN '1) menos de 5'
                WHEN COUNT(*) < 20 THEN '2) 5 a 19'
                ELSE '3) 20 ou mais' END AS FAIXA
    FROM SRA010
    WHERE D_E_L_E_T_ = ' ' AND RA_DEMISSA = ' '
    GROUP BY RA_FILIAL, RA_CC
) GRUPOS
GROUP BY FAIXA
ORDER BY FAIXA;
