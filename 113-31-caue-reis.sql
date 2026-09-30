/*
	Avaliação - Sistema de Gestão de Matrículas Escolares
	Aluno: Caue Reis
	Data: 30/09/2026
*/

/*
============== VIEWS ==============
*/

-- VIEW 1 

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND TYPE = 'V' )
    DROP VIEW [dbo].[VW_MatriculasAtivas]
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
  AS
  /*
      Documentacao

      Arquivo fonte............: VW_MatriculasAtivas.sql
      Objetivo.................: Exibir todas matriculas ativas (IdSituacaoMatricula = 1)
      Autor....................: Caue Reis
      Data.....................: 30/09/2026
      Exemplo..................:
                                  SELECT *
                                    FROM [dbo].[VW_MatriculasAtivas]

  */
    SELECT  m.Id AS IdMatricula,
            m.DataMatricula,
            sm.Descricao AS SituacaoMatricula,
            a.Nome AS NomeAluno,
            a.Cpf,
            c.Nome AS Curso,
            t.Codigo AS CodigoTurma
        FROM [dbo].[Matricula] AS m WITH(NOLOCK)
            JOIN [dbo].[Aluno] AS a WITH(NOLOCK)
                ON a.Id = m.IdAluno
            JOIN [dbo].[Turma] AS t WITH(NOLOCK)
                ON t.Id = m.IdTurma
            JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = m.IdSituacaoMatricula
            JOIN [dbo].[Curso] AS c WITH(NOLOCK)
                ON c.Id = t.IdCurso
        WHERE m.IdSituacaoMatricula = 1

GO

-- VIEW 2

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND TYPE = 'V' )
    DROP VIEW [dbo].[VW_SituacaoFinanceira]
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
    AS
    /*
        Documentacao

        Arquivo fonte............: VW_SituacaoFinanceira.sql
        Objetivo.................: Exibe o total de parcelas pagas, vencidas, abertas e canceladas de cada estudante
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:
                                    SELECT *
                                    FROM [dbo].[VW_SituacaoFinanceira]
    */
    SELECT m.Id AS IdMatricula,
        a.Nome AS NomeAluno,
        COUNT(p.Id) AS TotalParcelas,
        COUNT(CASE WHEN p.IdSituacaoParcela = 3 THEN 1 END) AS TotalPagas,
        COUNT(CASE WHEN p.IdSituacaoParcela IN (1, 2) THEN 1 END) AS TotalPendentes,
        COUNT(CASE WHEN p.IdSituacaoParcela IN (1, 2)
                    AND p.DataVencimento < CAST(GETDATE() AS DATE) THEN 1 END) AS TotalVencidas,
        ISNULL(SUM(CASE WHEN p.IdSituacaoParcela IN (1, 2) THEN p.ValorOriginal END), 0) AS ValorPendente
        FROM [dbo].[Matricula] AS m WITH(NOLOCK)
            JOIN [dbo].[Aluno] AS a WITH(NOLOCK)
                ON a.Id = m.IdAluno
            LEFT JOIN [dbo].[Parcela] AS p WITH(NOLOCK)
                ON p.IdMatricula = m.Id
        GROUP BY m.Id, a.Nome
GO

/*
============== FUNCTIONS ==============
*/

-- FUNCTION 1

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_VagasDisponiveis]') AND TYPE = 'FN' )
    DROP FUNCTION [dbo].[FNC_VagasDisponiveis]
GO

CREATE FUNCTION [dbo].[FNC_VagasDisponiveis] (
                                                @IdTurma INT
                                             )
    RETURNS INT
    AS
    /*
        Documentacao

        Arquivo fonte............: FNC_VagasDisponiveis.sql
        Objetivo.................: Retornar quantidade de vagas em determinada turma
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT;

                                        SELECT @Retorno = [dbo].[FNC_VagasDisponiveis](1)

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execu��o (ms)';
                                    ROLLBACK TRAN

        Retornos: INT Positivo - Sucesso
    */
    BEGIN
        
        DECLARE @TotalDeAlunosComMatricula     INT =    (SELECT COUNT(Id) 
                                                            FROM [dbo].[Matricula] WITH(NOLOCK)
                                                            WHERE IdTurma = @IdTurma
                                                                AND IdSituacaoMatricula = 1
                                                         )

        DECLARE @TotalDeAlunosMatriculaReserva INT =    (SELECT COUNT(Id) 
                                                            FROM [dbo].[ReservaMatricula] WITH(NOLOCK) 
                                                            WHERE IdSituacaoReserva = 1 
                                                                AND DataExpiracao >= CAST(GETDATE() AS DATE)
                                                                AND IdTurma = @IdTurma 
                                                         )

        RETURN ((SELECT Capacidade FROM [dbo].[Turma] WHERE Id = @IdTurma) - (@TotalDeAlunosComMatricula + @TotaldeAlunosMatriculaReserva))

    END;
GO

-- FUNCTION 2

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_CalcularParcelaData]') AND TYPE = 'FN' )
    DROP FUNCTION [dbo].[FNC_CalcularParcelaData]
GO

CREATE FUNCTION [dbo].[FNC_CalcularParcelaData] (
                                            @IdParcela INT,
                                            @DataReferencia DATE
                                                )
    RETURNS DECIMAL(10,2)
    AS
    /*
        Documentacao

        Arquivo fonte............: FNC_CalcularParcelaData.sql
        Objetivo.................: Calcula o valor de uma parcela em uma data especifica
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:    
                                      DBCC FREEPROCCACHE
                                      DBCC DROPCLEANBUFFERS

                                      BEGIN TRAN
                                          DECLARE @DataInicial DATETIME = GETDATE(),
                                                  @Retorno DECIMAL(15,2);

                                          SELECT @Retorno = [dbo].[FNC_CalcularParcelaData](13, GETDATE())

                                          SELECT  @Retorno AS Retorno,
                                                  DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execu��o (ms)';
                                      ROLLBACK TRAN

        Retornos: DECIMAL(10,2) - Sucesso
    */
    BEGIN
        DECLARE @Vencimento DATE,
                @Original   DECIMAL(14,2),
                @Meses      INT = 0;

        SELECT @Vencimento = DataVencimento,
                @Original   = ValorOriginal
            FROM [dbo].[Parcela] WITH(NOLOCK)
            WHERE Id = @IdParcela;

        IF @DataReferencia > @Vencimento
            BEGIN
                SET @Meses = DATEDIFF(MONTH, @Vencimento, @DataReferencia);

                IF DATEADD(MONTH, @Meses, @Vencimento) < @DataReferencia
                    SET @Meses = @Meses + 1
            END
        RETURN @Original * (1 + 0.01 * @Meses);
    END
GO

/*
============== PROCEDURES ==============
*/

-- PROCEDURE 1

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_ReservarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
    @IdAluno INT,
    @IdTurma INT
    AS
    /*
        Documentacao

        Arquivo fonte............: SP_ReservarMatricula.sql
        Objetivo.................: Realizar reserva de uma matricula, recebendo o @IdAluno e o @IdTurma
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_ReservarMatricula] 12, 3

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execu��o (ms)';
                                    ROLLBACK TRAN

        Retornos.................: Id Inserido  - Sucesso
                                   -1           - Erro: Aluno Inexistente
                                   -2           - Erro: Aluno Inativo
                                   -3           - Erro: Turma inexistente/inativa
                                   -4           - Erro: Turma nao tem vagas disponiveis
                                   -5           - Erro: Aluno ja possui reserva na turma informada
                                   -6           - Erro: Aluno ja matriculado na turma informada
                                   -7           - Erro: Erro ao inserir
    */
    BEGIN

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Aluno] WITH(NOLOCK) WHERE Id = @IdAluno)
            RETURN - 1 -- Aluno Inexistente

        IF (SELECT Ativo FROM [dbo].[Aluno] WITH(NOLOCK) WHERE Id = @IdAluno) = 0
            RETURN - 2 -- Aluno Inativo

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Turma] WITH(NOLOCK) WHERE Id = @IdTurma AND Ativo = 1)
            RETURN - 3 -- Turma inativa ou inexistente

        IF ([dbo].[FNC_VagasDisponiveis](@IdTurma)) <= 0
            RETURN - 4 -- Turma nao tem vagas disponiveis

        IF EXISTS (SELECT 1 FROM [dbo].[ReservaMatricula] WITH(NOLOCK) WHERE IdTurma = @IdTurma AND IdAluno = @IdAluno AND IdSituacaoReserva = 1 AND DataExpiracao >= CAST(GETDATE() AS DATE))
            RETURN - 5 -- Aluno ja possui reserva na turma informada

        IF EXISTS (SELECT 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE IdTurma = @IdTurma AND IdAluno = @IdAluno AND IdSituacaoMatricula = 1)
            RETURN - 6 -- Aluno ja matriculado na turma informada

        INSERT INTO [dbo].[ReservaMatricula](IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
            VALUES (@IdAluno, @IdTurma, 1, GETDATE(), DATEADD(DAY, 7, GETDATE()))

        DECLARE @IdInserido INT = SCOPE_IDENTITY();

        IF @@ERROR <> 0
            RETURN - 7 -- Erro insercao

        RETURN @IdInserido
    END
GO

-- PROCEDURE 2

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
    @IdReserva INT
    AS
    /*
        Documentacao

        Arquivo fonte............: SP_EfetivarMatricula.sql
        Objetivo.................: Efetivar uma matricula recebendo o @IdReserva, fazendo todas validacoes necessarias
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 2

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execu��o (ms)';
                                    ROLLBACK TRAN

        Retornos.................: Id da matricula gerada   - Sucesso
                                   -1                       - Erro: Reserva inexistente
                                   -2                       - Erro: Situacao da reserva nao permite efetivar matricula
                                   -3                       - Erro: Reserva expirada
                                   -4                       - Erro: Erro de insercao na tabela de Matricula
                                   -5                       - Erro: Erro de atualizacao na tabela de Reserva
                                   -6                       - Erro: Erro de insercao na tabela de Parcela
    */
    BEGIN

        IF NOT EXISTS (SELECT 1 FROM [dbo].[ReservaMatricula] WITH(NOLOCK) WHERE Id = @IdReserva)
            RETURN - 1 -- Reserva nao existe

        DECLARE @IdSituacaoReserva INT,
                @IdTurma INT,
                @IdAluno INT,
                @DataExpiracao DATE,
                @ValorMensalidade DECIMAL(14,2);

        DECLARE @DataHoraHoje DATETIME = GETDATE();

        SELECT  @IdSituacaoReserva = IdSituacaoReserva,
                @IdTurma = IdTurma,
                @IdAluno = IdAluno,
                @DataExpiracao = DataExpiracao
            FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
            WHERE Id = @IdReserva

        SELECT @ValorMensalidade = c.ValorMensalidade
            FROM [dbo].[Turma] AS t WITH(NOLOCK)
                JOIN [dbo].[Curso] AS c WITH(NOLOCK)
                    ON c.Id = t.IdCurso
            WHERE t.Id = @IdTurma

        IF (@IdSituacaoReserva) <> 1
            RETURN - 2 -- Situacao da reserva nao permite efetivar matricula

        IF @DataExpiracao < CAST(@DataHoraHoje AS DATE)
            RETURN - 3 --  Reserva expirada

        BEGIN TRANSACTION

            INSERT INTO [dbo].[Matricula](IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
                VALUES(@IdReserva, @IdAluno, @IdTurma, 1, @DataHoraHoje, @ValorMensalidade)

            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN - 4 -- Erro de insercao
                END

            DECLARE @IdMatriculaGerado INT = SCOPE_IDENTITY()

            UPDATE [dbo].[ReservaMatricula]
                SET IdSituacaoReserva = 2
                WHERE Id = @IdReserva

            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN - 5 -- Erro de atualizacao
                END

            DECLARE @Contador INT = 1;
            DECLARE @DataValidade DATE = DATEFROMPARTS(YEAR(@DataHoraHoje), MONTH(@DataHoraHoje), 10);

            WHILE (@Contador <= 12)
                BEGIN
                    INSERT INTO [dbo].[Parcela](IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
                        VALUES(@IdMatriculaGerado, 1, @Contador, @ValorMensalidade, DATEADD(MONTH, @Contador, @DataValidade))
                    SET @Contador = @Contador + 1
                    IF @@ERROR <> 0
                        BEGIN
                            ROLLBACK TRANSACTION
                            RETURN - 6 -- Erro na criacao de parcela
                        END
                END

        COMMIT TRANSACTION

        RETURN @IdMatriculaGerado

    END
GO

-- PROCEDURE 3

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_RegistrarPagamento]
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
    @IdParcela INT,
    @ValorPago DECIMAL(14,2)
    AS
    /*
        Documentacao

        Arquivo fonte............: SP_RegistrarPagamento.sql
        Objetivo.................: Regitrar pagamento de uma parcela, validando se o valor informado � suficiente
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:    
                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS

                                        BEGIN TRAN
                                            DECLARE @DataInicial DATETIME = GETDATE(),
                                            @Retorno INT;

                                            EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 1, 1000

                                            SELECT	@Retorno AS Retorno,
                                                    DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execu��o (ms)';
                                        ROLLBACK TRAN

        Retornos.................: Id do pagamento gerado   - Sucesso
                                   -1                       - Erro: Parcela inexistente
                                   -2                       - Erro: Parcela j� paga ou cancelada
                                   -3                       - Erro: Valor informado � insuficiente para efetuar pagamento
                                   -4                       - Erro: Erro de insercao na tabela de pagamento
    */
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Parcela] WITH(NOLOCK) WHERE Id = @IdParcela)
            RETURN - 1 -- Parcela inexistente

        DECLARE @IdSituacaoParcela INT,
                @IdGerado INT,
                @Agora DATETIME;

        SELECT  @IdSituacaoParcela = IdSituacaoParcela,
                @Agora = GETDATE()
            FROM [dbo].[Parcela] WITH(NOLOCK)
            WHERE Id = @IdParcela

        IF (@IdSituacaoParcela <> 1) AND (@IdSituacaoParcela <> 2)
            RETURN - 2 -- Parcela paga/cancelada

        IF ([dbo].[FNC_CalcularParcelaData](@IdParcela, @Agora)) > @ValorPago
            RETURN - 3 -- Valor da parcela � maior que o valor pago

        INSERT INTO [dbo].[Pagamento](IdParcela, DataPagamento, ValorPago)
            VALUES(@IdParcela, @Agora, @ValorPago)

        IF @@ERROR <> 0
            RETURN - 4 -- Erro na insercao

        SET @IdGerado = SCOPE_IDENTITY()

        RETURN @IdGerado
        
    END
GO

-- PROCEDURE 4

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_CancelarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
    @IdMatricula INT
    AS
    /*
        Documentacao

        Arquivo fonte............: SP_CancelarMatricula.sql
        Objetivo.................: Cancelar uma matricula, recebendo @IdMatricula, validando se n�o h� alguma pendencia
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_CancelarMatricula] 2

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execu��o (ms)';
                                    ROLLBACK TRAN

        Retornos.................:  0  - Sucesso
                                   -1  - Erro: Matricula inexistente
                                   -2  - Erro: Situacao da matricula nao permite cancelamento
                                   -3  - Erro: Existem parcelas pendentes com negociacao nao quitada
                                   -4  - Erro: Nao foi possivel realizar atualizacao
    */
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE Id = @IdMatricula)
            RETURN - 1 -- Matricula inexistente

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE Id = @IdMatricula AND IdSituacaoMatricula = 1)
            RETURN - 2 -- Situacao da matricula nao permite cancelamento

        IF EXISTS (SELECT 1 FROM [dbo].[Parcela] WITH(NOLOCK) WHERE IdMatricula = @IdMatricula 
                                                                AND (IdSituacaoParcela = 1 
                                                                OR IdSituacaoParcela = 2))
            AND NOT EXISTS (SELECT 1 FROM [dbo].[Negociacao] WITH(NOLOCK) WHERE IdMatricula = @IdMatricula 
                                                                            AND IdSituacaoNegociacao = 2)
            RETURN - 3 -- Existem parcelas pendentes com negociacao nao quitada
            
            UPDATE [dbo].[Matricula]
                SET IdSituacaoMatricula = 2
                WHERE Id = @IdMatricula;

            IF @@ERROR <> 0
                RETURN - 4 -- Erro de atualizacao

            RETURN 0

    END
GO

/*
============== TRIGGER ==============
*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaAposPagamento]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1 )
    DROP TRIGGER [dbo].[TRG_AtualizarParcelaAposPagamento]
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaAposPagamento]
    ON [dbo].[Pagamento]
    AFTER INSERT
    AS
    /*
        Documentacao

        Arquivo fonte............: TRG_AtualizarParcelaAposPagamento.sql
        Objetivo.................: Atualizar a situacao apos ser realizado um pagamento
        Autor....................: Caue Reis
        Data.....................: 30/09/2026
    */
    BEGIN
        BEGIN TRY
            UPDATE p
                SET p.IdSituacaoParcela = 3
                FROM [dbo].[Parcela] AS p
                    JOIN inserted AS i 
                        ON i.IdParcela = p.Id
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 
                ROLLBACK TRANSACTION;
            THROW;
       END CATCH
    END
GO

/*
============== Testes ==============
*/

-- 1 - Reserva valida

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_ReservarMatricula] 12, 3

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO
-- 2 - Reserva em turma sem vaga

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC [dbo].[SP_ReservarMatricula] 12, 3
    EXEC @Retorno = [dbo].[SP_ReservarMatricula] 8, 3

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 3 - Reserva duplicada 
BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_ReservarMatricula] 1, 1

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 4 - Reserva com aluno inativo

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_ReservarMatricula] 13, 1

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 5 - Efetivacao valida

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 2

    SELECT * FROM Parcela WHERE IdMatricula = @Retorno

ROLLBACK TRANSACTION
GO

-- 6 - Efetivar reserva ja efetivada
   
BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 6

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 7 - Efetivar reserva com data expirada

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 10

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 8 - Pagamento dentro do vencimento

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 34, 1000

    SELECT * FROM [dbo].[Pagamento] WHERE Id = @Retorno

ROLLBACK TRANSACTION
GO

-- 9 - Pagamento fora do vencimento

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 3, 1000

    SELECT * FROM [dbo].[Pagamento] WHERE Id = @Retorno

ROLLBACK TRANSACTION
GO

-- 10 - Pagamento de parcela ja paga

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 1, 1000

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 11 - Teste trigger

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    SELECT * FROM Parcela WHERE Id = 34 

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 34, 1000

    SELECT * FROM Parcela WHERE Id = 34

ROLLBACK TRANSACTION
GO

-- 12 - Teste trigger varias linhas

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    SELECT * FROM Parcela WHERE Id = 34 OR Id = 36

    INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
        VALUES (34, GETDATE(), 10000),
               (36, GETDATE(), 10000) 

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 34, 1000
 
    SELECT * FROM Parcela WHERE Id = 34 OR Id = 36

ROLLBACK TRANSACTION
GO

-- 13 - Tentativa de cancelamento com parcela pendente

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_CancelarMatricula] 1

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 14 - Cancelamento valido sem parcelas pendentes

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_CancelarMatricula] 4

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 15 - Cancelamento com negociacao quitada

BEGIN TRANSACTION

    DECLARE @Retorno INT;
    
    EXEC @Retorno = [dbo].[SP_CancelarMatricula] 2

    SELECT @Retorno AS Retorno

ROLLBACK TRANSACTION
GO

-- 16 - Consulta view 1 

SELECT * 
    FROM [dbo].[VW_MatriculasAtivas]

-- 17 - Consulta view 2

SELECT *
    FROM [dbo].[VW_SituacaoFinanceira]

-- 18 - Chamada function 1

DECLARE @Retorno INT;

SELECT @Retorno = [dbo].[FNC_VagasDisponiveis](1)

SELECT @Retorno AS Retorno

GO

-- 19 - Chamda function 2

DECLARE @Retorno INT;

SELECT @Retorno = [dbo].[FNC_CalcularParcelaData](13, GETDATE())

SELECT @Retorno AS Retorno

GO
