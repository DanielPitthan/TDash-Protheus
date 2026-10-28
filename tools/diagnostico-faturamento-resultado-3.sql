-- TDash: diagnostico do Faturamento (parte 3) - nome dos tributos do Configurador (TR0001, TR0002, TR0003...)
--
-- SOMENTE LEITURA: so SELECT, nada e criado nem alterado. Sem dado de pessoa.
-- Objetivo: descobrir de onde vem o NOME de cada tributo generico (F2D_TRIB) para o app mostrar "CBS" e "IBS" separados
-- sem fixar os codigos TR0001/TR0002 no programa (o codigo muda de um cliente para outro). F2D_IDCAD aponta para o
-- cadastro do tributo.
--
-- Antes de rodar: troque o sufixo 010 (empresa 01) pelo da empresa que o TDash vai usar.
-- Escrito para SQL Server. Mande o resultado de cada consulta numerada.

-- 1) Tabelas do Configurador de Tributos no dicionario (F2A a F2Z e CJ*)
SELECT RTRIM(X2_CHAVE) AS TABELA, RTRIM(X2_NOME) AS NOME
FROM SX2010
WHERE D_E_L_E_T_ = ' ' AND (X2_CHAVE LIKE 'F2[A-Z0-9]' OR X2_CHAVE LIKE 'CJ[A-Z0-9]' OR RTRIM(X2_NOME) LIKE '%Tribut%')
ORDER BY X2_CHAVE;

-- 2) Para cada tributo da F2D: o ID do cadastro (F2D_IDCAD) e quantas linhas usam
SELECT F2D_TRIB AS TRIBUTO, F2D_IDCAD AS ID_CADASTRO, F2D_IDALIQ AS ID_ALIQUOTA, COUNT(*) AS LINHAS, MAX(F2D_ALIQ) AS ALIQUOTA
FROM F2D010
WHERE D_E_L_E_T_ = ' ' AND F2D_TABELA IN ('SD2', 'SD1')
GROUP BY F2D_TRIB, F2D_IDCAD, F2D_IDALIQ
ORDER BY F2D_TRIB, LINHAS DESC;

-- 3) Campos do provavel cadastro de tributos (F2B). Se a tabela nao existir, a consulta volta vazia.
SELECT RTRIM(X3_ARQUIVO) AS TABELA, RTRIM(X3_CAMPO) AS CAMPO, RTRIM(X3_TITULO) AS TITULO, RTRIM(X3_DESCRIC) AS DESCRICAO,
       X3_TIPO AS TIPO, X3_TAMANHO AS TAMANHO
FROM SX3010
WHERE D_E_L_E_T_ = ' ' AND X3_ARQUIVO IN ('F2B', 'F2C', 'F2E', 'F2F', 'F2G', 'F2H')
ORDER BY X3_ARQUIVO, X3_ORDEM;

-- 4) Conteudo do cadastro F2B (so se existir): os primeiros 30 registros, todas as colunas
IF OBJECT_ID('F2B010') IS NOT NULL
  EXEC('SELECT TOP 30 * FROM F2B010 WHERE D_E_L_E_T_ = '' ''');
ELSE
  SELECT 'F2B010 nao existe nesta base' AS AVISO;

-- 5) Procura o ID do cadastro dos tributos usados nas tabelas candidatas (acha qual tabela tem F2D_IDCAD como chave)
DECLARE @IDCAD VARCHAR(36) = (SELECT TOP 1 F2D_IDCAD FROM F2D010 WHERE D_E_L_E_T_ = ' ' AND F2D_TRIB = 'TR0001' AND F2D_IDCAD <> ' ');
SELECT @IDCAD AS ID_CADASTRO_DE_TR0001;

DECLARE @T TABLE (TABELA VARCHAR(3), CAMPO VARCHAR(10), ACHOU INT);
DECLARE @tab VARCHAR(3), @cmp VARCHAR(10), @sql NVARCHAR(MAX), @n INT;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
  SELECT RTRIM(X3_ARQUIVO), RTRIM(X3_CAMPO) FROM SX3010
  WHERE D_E_L_E_T_ = ' ' AND X3_TIPO = 'C' AND X3_TAMANHO = 36 AND X3_ARQUIVO LIKE 'F2[A-Z0-9]' AND RTRIM(X3_CAMPO) LIKE '%[_]ID';
OPEN c; FETCH NEXT FROM c INTO @tab, @cmp;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'SELECT @n = COUNT(*) FROM ' + @tab + N'010 WHERE D_E_L_E_T_ = '' '' AND ' + @cmp + N' = @id';
  BEGIN TRY
    EXEC sp_executesql @sql, N'@id VARCHAR(36), @n INT OUTPUT', @id = @IDCAD, @n = @n OUTPUT;
    INSERT INTO @T VALUES (@tab, @cmp, @n);
  END TRY
  BEGIN CATCH
    INSERT INTO @T VALUES (@tab, @cmp, -1);
  END CATCH
  FETCH NEXT FROM c INTO @tab, @cmp;
END
CLOSE c; DEALLOCATE c;
SELECT TABELA, CAMPO, ACHOU AS REGISTROS_COM_O_ID FROM @T ORDER BY ACHOU DESC, TABELA;
