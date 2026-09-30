/*  ========================================================================
    AVALIAÇÃO BANCO DE DADOS AVANÇADO
    Aluno: Djefferson dos Santos Lima
    Matrícula: 711-50
    ========================================================================    */

USE Escola;
GO

/*  ========================================================================
    1. VIEWS
    ========================================================================    */

-- Matrículas ativas -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
    DROP VIEW [dbo].[VW_MatriculasAtivas]
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
    AS
    /*
        Documentacao

        Arquivo fonte..........: 711-50-djefferson-dos-santos.sql
        Objetivo...............: listar as matrículas ATIVAS, identificando aluno, curso, turma, data da matrícula e situação.
        Autor..................: Djefferson dos Santos Lima
        Data...................: 30/09/2026
        Exemplo................:
                                  SELECT *
                                    FROM [dbo].[VW_MatriculasAtivas]
    */
        SELECT
            ma.Id as IdMatricula,
            ma.DataMatricula,
            ma.ValorMensalidade,
            si.Descricao as Situacao,
            ma.IdAluno,
            al.Nome as NomeAluno,
            al.Cpf,
            ma.IdTurma,
            tu.Codigo as CodigoTurma,
            tu.AnoLetivo,
            tu.IdCurso,
            cu.Nome as NomeCurso
        FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoMatricula] AS si WITH(NOLOCK)
                ON ma.IdSituacaoMatricula = si.Id
            INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON ma.IdAluno = al.Id
            INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                ON ma.IdTurma = tu.Id
            INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
                ON tu.IdCurso = cu.Id
        WHERE IdSituacaoMatricula = 1
    GO

-- Situação financeira -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
    DROP VIEW [dbo].[VW_SituacaoFinanceira]
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
    AS
    /*
        Documentacao

        Arquivo fonte..........: 711-50-djefferson-dos-santos.sql
        Objetivo...............: apresentar uma linha por matrícula, com o aluno, o total de parcelas, 
                                 as quantidades de parcelas pagas, pendentes e vencidas
        Autor..................: Djefferson dos Santos Lima
        Data...................: 30/09/2026
        Exemplo................:
                                  SELECT *
                                    FROM [dbo].[VW_SituacaoFinanceira]
    */
        SELECT
            ma.Id as IdMatricula,
            al.Id as IdAluno,
            al.Nome as NomeAluno,
            al.Cpf,
            COUNT(pa.Id) as QuantidadeParcelas,
            SUM(
                    CASE 
                        WHEN pa.IdSituacaoParcela = 3 THEN 1
                        ELSE 0
                    END
                ) as ParcelasPagas,
            SUM(
                    CASE
                        WHEN pa.IdSituacaoParcela NOT IN (3, 4)
                            THEN 1
                        ELSE 0
                    END
               ) as ParcelasPendentes,
            SUM(
                    CASE
                        WHEN pa.IdSituacaoParcela NOT IN (3, 4) AND pa.DataVencimento < CAST(GETDATE() AS DATE)
                            THEN 1
                        ELSE 0
                    END
               ) as ParcelasVencidas,
            SUM( 
                    CASE
                        WHEN pa.IdSituacaoParcela IN (3, 4) 
                            THEN 0
                        WHEN pa.DataVencimento >= CAST(GETDATE() AS DATE)
                            THEN ma.ValorMensalidade
                        WHEN MONTH(pa.DataVencimento) = MONTH(GETDATE())
                            THEN pa.ValorOriginal * 1.01
                        WHEN DAY(GETDATE()) <= 10
                            THEN pa.ValorOriginal + (pa.ValorOriginal * 0.01 * (DATEDIFF(MONTH, pa.DataVencimento, GETDATE()) - 1)) 
                        ELSE 
                            pa.ValorOriginal + (pa.ValorOriginal * 0.01 * DATEDIFF(MONTH, pa.DataVencimento, GETDATE()))
                    END
               ) as ValorTotalPendente
        FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON ma.IdAluno = al.Id
            INNER JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                ON ma.Id = pa.IdMatricula
        GROUP BY ma.Id, al.Id, al.Nome, al.Cpf
    GO

/*  ========================================================================
    2. FUNCTIONS
    ========================================================================    */

-- Disponibilidade de vagas -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_VagasDisponiveisNaTurma]') AND TYPE = N'FN' )
    DROP FUNCTION [dbo].[FNC_VagasDisponiveisNaTurma]
GO

CREATE FUNCTION [dbo].[FNC_VagasDisponiveisNaTurma] (
                                                        @IdTurma INT
                                                    )
    RETURNS INT
    AS
    /*
        Documentacao

        Arquivo fonte..........: 711-50-djefferson-dos-santos.sql
        Objetivo...............: receber uma turma e retornar quantas vagas nao ocupadas ela ainda possui
        Autor..................: Djefferson dos Santos Lima
        Data...................: 30/09/2026
        Exemplo................:    
                                  DBCC FREEPROCCACHE
                                  DBCC DROPCLEANBUFFERS

                                      DECLARE @DataInicial DATETIME = GETDATE();

                                      SELECT dbo.FNC_VagasDisponiveisNaTurma(1) as Retorno

                                      SELECT DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
        Retornos...............: Resultado > 0 - Quantidade de vagas disponíveis
                                 -1            - Turma nao encontrada no sistema
                                 -2            - A turma esta inativa
    */
    BEGIN
        DECLARE @QuantidadeVagasDisponiveis INT,
                @VagasMaximas INT,
                @SituacaoTurma BIT
                
        SELECT @VagasMaximas = Capacidade,
                @SituacaoTurma = Ativo
            FROM [dbo].[Turma] WITH(NOLOCK)
            WHERE Id = @IdTurma 

        IF @VagasMaximas IS NULL
            RETURN -1 -- Turma nao encontrada no sistema

        IF @SituacaoTurma <> 1
            RETURN -2 -- A turma esta inativa

        SELECT @QuantidadeVagasDisponiveis = @VagasMaximas -
                    SUM(
                            CASE 
                                WHEN re.DataExpiracao < GETDATE() 
                                    AND re.IdSituacaoReserva IN (1, 3)
                                    THEN 0 -- Verifica se a vaga está expirada, deixando ela livre caso sim
                                WHEN re.IdSituacaoReserva IN (1, 2) 
                                    AND ISNULL(ma.IdSituacaoMatricula, 1) = 1 -- Se a matricula é null considera ela ativa
                                    THEN 1
                                ELSE 0
                            END
                       ) 
            FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
                LEFT JOIN [dbo].[Matricula] AS ma WITH(NOLOCK) -- Retorna as Reservas que ainda não possuem matricula 
                    ON re.Id = ma.IdReservaMatricula
            WHERE re.IdTurma = @IdTurma

        RETURN @QuantidadeVagasDisponiveis
    END;
GO

-- Valor atualizado da parcela -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_ValorAtualizadoParcela]') AND TYPE = N'FN' )
    DROP FUNCTION [dbo].[FNC_ValorAtualizadoParcela]
GO

CREATE FUNCTION [dbo].[FNC_ValorAtualizadoParcela]  (
                                                        @IdParcela INT,
                                                        @DataReferencia DATE = NULL
                                                    )
    RETURNS DECIMAL(14,2)
    AS
    /*
        Documentacao

        Arquivo fonte..........: 711-50-djefferson-dos-santos.sql
        Objetivo...............: eceber uma parcela e uma data de referência e retornar quanto 
                                 a parcela vale nessa data, com os juros de atraso quando houver 
        Autor..................: Djefferson dos Santos Lima
        Data...................: 30/09/2026
        Exemplo................:    
                                  DBCC FREEPROCCACHE
                                  DBCC DROPCLEANBUFFERS

                                  BEGIN TRAN
                                      DECLARE @DataInicial DATETIME = GETDATE();

                                      SELECT dbo.FNC_ValorAtualizadoParcela(1, '30-09-2026') 

                                      SELECT DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
                                  ROLLBACK TRAN
        Retornos...............: Valor positivo - Valor da parcela naquela data
                                 -1             - Parcela nao localizada no sistema
    */
    BEGIN

        DECLARE @ValorOriginal DECIMAL(14,2),
                @DataVencimento DATE,
                @ValorFinal DECIMAL(14,2);

        SELECT @ValorOriginal = ValorOriginal,
               @DataVencimento = DataVencimento
            FROM [dbo].[Parcela] WITH(NOLOCK)
            WHERE Id = @IdParcela

        IF @ValorOriginal IS NULL
            RETURN -1 -- Parcela nao localizada no sistema
        -- A atividade pede para retornar o valor apenas, então nao considerei a situacao da parcela
        IF @DataReferencia IS NULL
            SET @DataReferencia = GETDATE()

        SET @ValorOriginal = CASE
                                WHEN @DataVencimento >= @DataReferencia
                                    THEN @ValorOriginal
                                WHEN MONTH(@DataVencimento) = MONTH(@DataReferencia)
                                    THEN @ValorOriginal * 1.01
                                WHEN DAY(@DataReferencia) <= 10
                                    THEN @ValorOriginal + (@ValorOriginal * 0.01 ) * (DATEDIFF(MONTH, @DataVencimento, @DataReferencia) - 1) 
                                ELSE
                                     @ValorOriginal + (@ValorOriginal * 0.01 ) * DATEDIFF(MONTH, @DataVencimento, @DataReferencia)
                             END 



        RETURN @ValorOriginal;
    END;
GO

/*  ========================================================================
    3. PROCEDURES
    ========================================================================    */

-- Reservar matrícula -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_RealizarReserva]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_RealizarReserva]
GO

CREATE PROCEDURE [dbo].[SP_RealizarReserva]
    @IdAluno INT,
    @IdTurma INT,
    @DataReservada DATETIME
    AS
    /*
        Documentacao

        Arquivo fonte...........: 711-50-djefferson-dos-santos.sql
        Objetivo................: registrar a reserva e retornar um código que indique o sucesso ou o motivo do erro.
        Autor...................: Djefferson dos Santos Lima
        Data....................: 30/09/2026
        Exemplo.................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_RealizarReserva]  @IdAluno = 1,
                                                                                    @IdTurma = 3,
                                                                                    @DataReservada = @DataInicial

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                        SELECT * FROM [dbo].[ReservaMatricula] WHERE Id = @Retorno
                                    ROLLBACK TRAN

        Retornos................: 0  - Id da nova reserva
                                  -1 - Aluno nao pode ser localizado no sistema
                                  -2 - O aluno nao esta ativo 
                                  -3 - Esta turma nao esta ativa
                                  -4 - Turma nao encontrada no sistema
                                  -5 - Vagas insuficientes nesta turma
                                  -6 - A data reservada nao pode ser anterior a data atual
                                  -7 - O aluno já possui uma reserva ativa nesta turma
                                  -8 - O aluno já possui uma matrícula ativa nesta turma
                                  -9 - Erro ao tentar inserir Reserva no sistema
    */
    BEGIN
        DECLARE @SituacaoAluno BIT;
            
        SELECT @SituacaoAluno = Ativo
            FROM [dbo].[Aluno] WITH(NOLOCK) 
            WHERE Id = @IdAluno 

        IF @SituacaoAluno IS NULL
            RETURN -1 -- Aluno nao pode ser localizado no sistema

        IF @SituacaoAluno <> 1
            RETURN -2 -- O aluno nao esta ativo 

        IF NOT EXISTS ( SELECT TOP 1 1 FROM [dbo].[Turma] WITH(NOLOCK) WHERE Id = @IdTurma AND Ativo = 1 )
            RETURN -3 -- Esta turma nao esta ativa

        IF dbo.FNC_VagasDisponiveisNaTurma(@IdTurma) = -1
            RETURN -4 -- Turma nao encontrada no sistema

        IF dbo.FNC_VagasDisponiveisNaTurma(@IdTurma) = 0
            RETURN -5 -- Vagas insuficientes nesta turma

        IF @DataReservada < CAST(GETDATE() AS DATE)
            RETURN -6 -- A data reservada nao pode ser anterior a data atual

        IF EXISTS ( 
                    SELECT TOP 1 1 
                        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                        WHERE IdAluno = @IdAluno 
                            AND IdTurma = @IdTurma 
                            AND IdSituacaoReserva = 1
                            AND DataExpiracao > GETDATE()
                   )

            RETURN -7 -- O aluno já possui uma reserva ativa nesta turma

        IF EXISTS ( 
                    SELECT TOP 1 1
                        FROM [dbo].[Matricula] WITH(NOLOCK)
                        WHERE IdAluno = @IdAluno 
                            AND IdTurma = @IdTurma 
                            AND IdSituacaoMatricula = 1
                  )
            RETURN -8 -- O aluno já possui uma matrícula ativa nesta turma
        
        BEGIN TRAN
            INSERT INTO [dbo].[ReservaMatricula] ( IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao )
                VALUES( @IdAluno, @IdTurma, 1, @DataReservada, DATEADD(DAY, 7, @DataReservada))

            IF @@ERROR <> 0 
                BEGIN
                    ROLLBACK TRAN
                    RETURN -9 -- Erro ao tentar inserir Reserva no sistema
                END
            
            COMMIT TRAN
           
        RETURN SCOPE_IDENTITY()
    END
GO

-- Efetivar matrícula -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
    @IdReserva INT
    AS
    /*
        Documentacao

        Arquivo fonte...........: 711-50-djefferson-dos-santos.sql
        Objetivo................: 
        Autor...................: Djefferson dos Santos Lima
        Data....................: 30/09/2026
        Exemplo.................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 4

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                        SELECT * FROM [dbo].[Matricula] WHERE Id = @Retorno
                                        SELECT * FROM [dbo].[Parcela] WHERE IdMatricula = @Retorno
                                    ROLLBACK TRAN

        Retornos................: 0  - Id da matricula gerada
                                  -1 - Nao foi possivel localizar esta reserva no sistema
                                  -2 - Ja existe uma matricula referente a esta reserva no sistema
                                  -3 - A situacao desta reserva nao permite efetivar a matricula
                                  -4 - Erro ao tentar inserir matricula no sistema
                                  -5 - Erro ao tentar inserir uma parcela
    */
    BEGIN
        DECLARE @IdAluno INT,
                @IdTurma INT, 
                @IdSituacaoReserva INT,
                @DataExpiracaoReserva DATE

        SELECT @IdAluno = IdAluno,
               @IdTurma = IdTurma,
               @IdSituacaoReserva = IdSituacaoReserva,
               @DataExpiracaoReserva = DataExpiracao
            FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
            WHERE Id = @IdReserva

        IF @IdAluno IS NULL
            RETURN -1 -- Nao foi possivel localizar esta reserva no sistema

        IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE IdReservaMatricula = @IdReserva )
            RETURN -2 -- Ja existe uma matricula referente a esta reserva no sistema

        IF @IdSituacaoReserva <> 1 OR @DataExpiracaoReserva < CAST(GETDATE() AS DATE)
            RETURN -3 -- A situacao desta reserva nao permite efetivar a matricula

        DECLARE @ValorMensalidade DECIMAL(14, 2) = ( 
                                                        SELECT TOP 1 cu.ValorMensalidade
                                                            FROM [dbo].[Turma] AS tu WITH(NOLOCK)
                                                                INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK) 
                                                                    ON tu.IdCurso = cu.Id
                                                            WHERE tu.Id = @IdTurma
                                                    )                                                  
        BEGIN TRAN

            INSERT INTO [dbo].[Matricula] ( IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade )
                VALUES ( @IdReserva, @IdAluno, @IdTurma, 1, GETDATE(), @ValorMensalidade)

            IF @@ERROR <> 0
                BEGIN
                    RETURN -4 -- Erro ao tentar inserir matricula no sistema
                    ROLLBACK TRAN
                END

            DECLARE @IdMatriculaGerada INT = SCOPE_IDENTITY(),
                    @NumeroParcela INT = 1,
                    @DataVencimento DATE = DATEFROMPARTS( YEAR(GETDATE()), MONTH(GETDATE()), 10);

                    
            WHILE @NumeroParcela <= 12
                BEGIN
                    INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
                        VALUES ( @IdMatriculaGerada, 1, @NumeroParcela, @ValorMensalidade, DATEADD(MONTH, @NumeroParcela, @DataVencimento) )

                    IF @@ERROR <> 0
                        BEGIN
                            RETURN -5 -- Erro ao tentar inserir uma parcela
                            ROLLBACK TRAN
                        END

                    SET @NumeroParcela = @NumeroParcela + 1
                END

            COMMIT TRAN

        RETURN @IdMatriculaGerada 
    END
GO

-- Registrar pagamento -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_PagarParcela]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_PagarParcela]
GO

CREATE PROCEDURE [dbo].[SP_PagarParcela]
    @IdParcela INT,
    @ValorPago DECIMAL (14, 2)
    AS
    /*
        Documentacao

        Arquivo fonte...........: 711-50-djefferson-dos-santos.sql
        Objetivo................: Realizar o pagamento de uma parcela
        Autor...................: Djefferson dos Santos Lima
        Data....................: 30/09/2026
        Exemplo.................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT,
                                                @ValorAPagar DECIMAL(14,2) = dbo.FNC_ValorAtualizadoParcela(25, NULL);

                                        EXEC @Retorno = [dbo].[SP_PagarParcela] @IdParcela = 25,
                                                                                @ValorPago = @ValorAPagar

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                        SELECT * FROM [dbo].[Pagamento] WHERE Id = @Retorno
                                    ROLLBACK TRAN

        Retornos................: IdPagamento  - Sucesso
                                  -1           - Nao foi possivel localizar parcela no sistema
                                  -2           - O status atual da parcela nao permite o pagamento
                                  -3           - O valor pago precisa ser igual ao valor atual da parcela (Contando juros quando aplicável)
                                  -4           - Erro ao inserir pagamento no banco
    */
    BEGIN
        DECLARE @IdSituacaoParcela INT

        SELECT @IdSituacaoParcela = IdSituacaoParcela
            FROM [dbo].[Parcela] WITH(NOLOCK) 
            WHERE Id = @IdParcela 
        
        IF @IdSituacaoParcela IS NULL
            RETURN -1 -- Nao foi possivel localizar parcela no sistema

        IF @IdSituacaoParcela NOT IN (1, 2)
            RETURN -2 -- O status atual da parcela nao permite o pagamento

        IF @ValorPago <> dbo.FNC_ValorAtualizadoParcela(@IdParcela, NULL)
            RETURN -3 -- O valor pago precisa ser igual ao valor atual da parcela (Contando juros quando aplicável)

        BEGIN TRAN 
            INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago )
                VALUES ( @IdParcela, GETDATE(), @ValorPago )

            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRAN
                    RETURN -4 -- Erro ao inserir pagamento no banco
                END

            COMMIT TRAN

        RETURN SCOPE_IDENTITY()

    END
GO

-- Cancelar matricula -------------------------------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_CancelarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
    @IdMatricula INT
    AS
    /*
        Documentacao

        Arquivo fonte...........: 711-50-djefferson-dos-santos.sql
        Objetivo................: Cancela uma matricula elegível do sistema
        Autor...................: Djefferson dos Santos Lima
        Data....................: 30/09/2026
        Exemplo.................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = SP_CancelarMatricula @IdMatricula = 2

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                        SELECT * FROM [dbo].[Matricula] WHERE Id = 2
                                    ROLLBACK TRAN

        Retornos................: 0  - Sucesso
                                  -1 - Esta matricula nao foi localizada no sistema
                                  -2 - A matricula precisa estar ativa para ser cancelada
                                  -3 - Ainda existem parcelas pendentes para essa matricula
                                  -4 - Erro ao tentar atualizar a matricula
                                  -5 - Erro ao tentar atualizar parcelas
    */
    BEGIN
        IF NOT EXISTS ( SELECT TOP 1 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE Id = @IdMatricula )
            RETURN -1 -- Esta matricula nao foi localizada no sistema

        IF NOT EXISTS ( SELECT TOP 1 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE Id = @IdMatricula AND IdSituacaoMatricula = 1 )
            RETURN -2 -- A matricula precisa estar ativa para ser cancelada

        IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[Parcela] WITH(NOLOCK) WHERE IdMatricula = @IdMatricula AND IdSituacaoParcela IN (1, 2) )
            BEGIN
                IF NOT EXISTS ( SELECT TOP 1 1 FROM [dbo].[Negociacao] WITH(NOLOCK) WHERE IdMatricula = @IdMatricula AND IdSituacaoNegociacao = 2 )
                    RETURN -3 -- Ainda existem parcelas pendentes para essa matricula
            END

        BEGIN TRAN

            UPDATE [dbo].[Matricula]
                SET IdSituacaoMatricula = 2
                    WHERE Id = @IdMatricula

            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRAN
                    RETURN -4 -- Erro ao tentar atualizar a matricula
                END
        /*
            -- Nao ficou claro se as parcelas deveriam ser atualizadas ou nao
            -- Ou se elas seriam atualizadas pela negociacao
            -- Como em nenhum momento isso e explicitado, adicionei de forma comentada para fim das dúvidas.

            UPDATE [dbo].[Parcela] 
                SET IdSituacaoParcela = 4
                    WHERE IdMatricula = @IdMatricula
                        AND IdSituacaoParcela NOT IN (3, 4)

            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRAN
                    RETURN -5 -- Erro ao tentar atualizar parcelas
                END
        */
            COMMIT TRAN
            RETURN 0

    END
GO
/*  ========================================================================
    4. TRIGGER
    ========================================================================    */

-- Atualização da parcela após pagamento -----------------------------------

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaParaPaga]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1 )
    DROP TRIGGER [dbo].[TRG_AtualizarParcelaParaPaga]
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaParaPaga]
    ON [dbo].[Pagamento]
    AFTER INSERT
    AS
    /*
        Documentacao

        Arquivo fonte...........: 711-50-djefferson-dos-santos.sql
        Objetivo................: Atualizar o status da parcela para paga quando elegivel
        Autor...................: Djefferson dos Santos Lima
        Data....................: 30/09/2026
    */
    BEGIN
        UPDATE pa
            SET IdSituacaoParcela = 3
                FROM [dbo].[Parcela] AS pa
                    INNER JOIN inserted AS i
                        ON pa.Id = i.IdParcela -- Nao precisa de where pois a tabela inserted já filtra

        -- O ROLLBACK da Procedure já refaz a trigger em caso de erro.
        -- Se erro em insert manual, a trigger não irá rodar.
    END
GO



/*  ========================================================================
    4. TESTES
    ========================================================================    */

-- Reserva válida

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_RealizarReserva]  @IdAluno = 1,
                                                @IdTurma = 3,
                                                @DataReservada = @DataInicial

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[ReservaMatricula] WHERE Id = @Retorno
    -- RETORNO ESPERADO: Id da reserva
ROLLBACK TRAN
GO

-- tentativas de reserva em turma sem vaga

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC [dbo].[SP_RealizarReserva] @IdAluno = 5,
                                    @IdTurma = 3,
                                    @DataReservada = @DataInicial

    EXEC @Retorno = [dbo].[SP_RealizarReserva]  @IdAluno = 1,
                                                @IdTurma = 3,
                                                @DataReservada = @DataInicial

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    -- RETORNO ESPERADO -5
ROLLBACK TRAN
GO 

-- reserva duplicada
BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC [dbo].[SP_RealizarReserva] @IdAluno = 1,
                                    @IdTurma = 2,
                                    @DataReservada = @DataInicial

    EXEC @Retorno = [dbo].[SP_RealizarReserva]  @IdAluno = 1,
                                                @IdTurma = 2,
                                                @DataReservada = @DataInicial

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    -- RETORNO ESPERADO: -7
ROLLBACK TRAN
GO

-- reserva com aluno ou turma inativos
BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_RealizarReserva]  @IdAluno = 1,
                                                @IdTurma = 4,
                                                @DataReservada = @DataInicial

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    --RETORNO ESPERADO: -4
ROLLBACK TRAN
GO

-- Efetivação válida

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 4

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Matricula] WHERE Id = @Retorno
    SELECT * FROM [dbo].[Parcela] WHERE IdMatricula = @Retorno
    --RETORNO ESPERADO: Id da nova matricula
ROLLBACK TRAN
GO

-- Tentativas de efetivar uma reserva já EFETIVADA

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
    @Retorno INT;
    EXEC [dbo].[SP_EfetivarMatricula] @IdReserva = 4
    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 4

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    -- RETORNO ESPERADO: -2
ROLLBACK TRAN
GO

-- Uma reserva com a data de expiração vencida

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
    @Retorno INT;
    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 10

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    -- RETORNO ESPERADO: -3
ROLLBACK TRAN
GO

--Pagamento dentro do vencimento

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT,
            @ValorAPagar DECIMAL(14,2) = dbo.FNC_ValorAtualizadoParcela(4, NULL);

    EXEC @Retorno = [dbo].[SP_PagarParcela] @IdParcela = 4,
                                            @ValorPago = @ValorAPagar

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Pagamento] WHERE Id = @Retorno

    --RETORNO ESPERADO: Id do pagamento
ROLLBACK TRAN
GO

--pagamento em atraso (com juros).
 
 BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT,
            @ValorAPagar DECIMAL(14,2) = dbo.FNC_ValorAtualizadoParcela(25, NULL);

    EXEC @Retorno = [dbo].[SP_PagarParcela] @IdParcela = 25,
                                            @ValorPago = @ValorAPagar

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Pagamento] WHERE Id = @Retorno

    --RETORNO ESPERADO: Id do pagamento
ROLLBACK TRAN
GO

-- Tentativa de pagamento de parcela já PAGA.
BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT,
            @ValorAPagar DECIMAL(14,2) = dbo.FNC_ValorAtualizadoParcela(1, NULL);

    EXEC @Retorno = [dbo].[SP_PagarParcela] @IdParcela = 1,
                                            @ValorPago = @ValorAPagar

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    -- RETORNO ESPERADO: -2
ROLLBACK TRAN
GO

-- Teste do Trigger, comprovando que a parcela passou para PAGA após o pagamento.

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT,
            @ValorAPagar DECIMAL(14,2) = dbo.FNC_ValorAtualizadoParcela(25, NULL);

    EXEC @Retorno = [dbo].[SP_PagarParcela] @IdParcela = 25,
                                            @ValorPago = @ValorAPagar

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Pagamento] WHERE Id = @Retorno
    SELECT * FROM [dbo].[Parcela] WHERE Id = 25

    -- RETORNO ESPERADO: Id Pagamento
ROLLBACK TRAN
GO

-- Teste do Trigger com várias linhas

BEGIN TRAN
    INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago )
        VALUES ( 3, GETDATE(), DBO.FNC_ValorAtualizadoParcela(3, NULL)),
               ( 4, GETDATE(), DBO.FNC_ValorAtualizadoParcela(4, NULL)),
               ( 5, GETDATE(), DBO.FNC_ValorAtualizadoParcela(5, NULL)),
               ( 6, GETDATE(), DBO.FNC_ValorAtualizadoParcela(6, NULL))

    SELECT * 
        FROM [dbo].[Parcela]
        WHERE Id IN (3, 4, 5, 6)

    -- RETORNO ESPERADO: Linhas com parcelas atualizadas
ROLLBACK TRAN
GO

-- Tentativa de cancelamento com parcelas pendentes e sem negociação QUITADA (deve ser bloqueada).

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = SP_CancelarMatricula @IdMatricula = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Matricula] WHERE Id = 1

    -- RETORNO ESPERADO: -3
ROLLBACK TRAN
GO

-- Cancelamento permitido com negociação QUITADA

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = SP_CancelarMatricula @IdMatricula = 2

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Matricula] WHERE Id = 2

    -- RETORNO ESPERADO: 0
ROLLBACK TRAN
GO

-- cancelamento permitido de matrícula sem parcelas pendentes.

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = SP_CancelarMatricula @IdMatricula = 4

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

    SELECT * FROM [dbo].[Matricula] WHERE Id = 4

    -- RETORNO ESPERADO: 0
ROLLBACK TRAN
GO

-- Consultas às duas Views e chamadas das duas Functions.

SELECT *
    FROM [dbo].[VW_MatriculasAtivas]

SELECT *
    FROM [dbo].[VW_SituacaoFinanceira]

SELECT dbo.FNC_VagasDisponiveisNaTurma(1) as VagasDisponiveis

SELECT dbo.FNC_ValorAtualizadoParcela(1, NULL) as ValorAtualizado
