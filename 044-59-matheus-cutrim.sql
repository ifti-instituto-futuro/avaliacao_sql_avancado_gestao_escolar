/*-------------------------------------------------------------------------------------------------
    Prova SQL Avançado | Matheus Cutrim
-------------------------------------------------------------------------------------------------*/

/*-------------------------------------------------------------------------------------------------
	VIEW 1 - Matrículas ativas
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND TYPE = 'V' )
    DROP VIEW [dbo].[VW_MatriculasAtivas]
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
    AS
    /*
        Documentacao

        Arquivo Fonte..........: 044-59-matheus-cutrim.sql
        Objetivo...............: Exibir apenas asm matrículas de atunos com o status de ativa
        Autor..................: Matheus Cutrim
        Data...................: 30/09/2026
        Exemplo................:
                                SELECT *
                                FROM [dbo].[VW_MatriculasAtivas]
    */
    SELECT  al.Nome as Aluno,
            cu.Nome as Curso,
            tu.Codigo as Turma,
            ma.DataMatricula as DataMatricula,
            sm.Descricao as SituacaoMatricula
        FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON ma.IdSituacaoMatricula = sm.Id
            JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON ma.IdAluno = al.Id
            JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                ON ma.IdTurma = tu.Id
            JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
                ON tu.IdCurso = cu.Id
        WHERE sm.Descricao = 'Ativa'
GO

/*-------------------------------------------------------------------------------------------------
	VIEW 2 - Situação financeira
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND TYPE = 'V' )
    DROP VIEW [dbo].[VW_SituacaoFinanceira]
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
    AS
    /*
        Documentacao

        Arquivo Fonte..........: 044-59-matheus-cutrim.sql
        Objetivo...............: Exibir a situação financeira de cada aluno pela sua matrícula
        Autor..................: Matheus Cutrim
        Data...................: 30/09/2026
        Exemplo................:
                                SELECT *
                                FROM [dbo].[VW_SituacaoFinanceira]
    */
    WITH ParcelasTotais AS (
        SELECT  ma.Id as Matricula,
                al.Nome as Aluno,
                COUNT(pa.Id) as TotalParcelas
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                    ON ma.Id = pa.IdMatricula
                JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                    ON pa.IdSituacaoParcela = sp.Id
                JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                    ON ma.IdAluno = al.Id
            GROUP BY ma.Id, al.Nome
    ),
    ParcelasPagas AS (
        SELECT  ma.Id,
                COUNT(pa.Id) as ParcelasPagas
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                    ON ma.Id = pa.IdMatricula
                JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                    ON pa.IdSituacaoParcela = sp.Id
            GROUP BY ma.Id, sp.Descricao
            HAVING sp.Descricao = 'Paga'
    ),
    ParcelasPendentes AS (
        SELECT  ma.Id,
                COUNT(pa.Id) as ParcelasPendentes
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                    ON ma.Id = pa.IdMatricula
                JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                    ON pa.IdSituacaoParcela = sp.Id
            GROUP BY ma.Id, sp.Descricao
            HAVING sp.Descricao = 'Aberta'
    ),
    ParcelasVencidas AS (
        SELECT  ma.Id,
                COUNT(pa.Id) as ParcelasVencidas
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                    ON ma.Id = pa.IdMatricula
                JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                    ON pa.IdSituacaoParcela = sp.Id
            GROUP BY ma.Id, sp.Descricao
            HAVING sp.Descricao = 'Vencida'
    )
    SELECT  Aluno,
            TotalParcelas,
            ParcelasPagas,
            ParcelasPendentes,
            ParcelasVencidas
        FROM ParcelasTotais AS pt
            LEFT JOIN ParcelasPagas AS pp
                ON pt.Matricula = pp.Id
            LEFT JOIN ParcelasPendentes AS pd
                ON pt.Matricula = pd.Id
            LEFT JOIN ParcelasVencidas AS pv
                ON pt.Matricula = pv.Id
GO

/*-------------------------------------------------------------------------------------------------
	FUNCTION 1 - Disponibilidade de vagas
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_DisponibilidadeVagas]') AND TYPE = 'FN' )
    DROP FUNCTION [dbo].[FNC_DisponibilidadeVagas]
GO

CREATE FUNCTION [dbo].[FNC_DisponibilidadeVagas] (
                                                    @IdTurma INT
                                                 )
    RETURNS INT
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Mostrar quantas vagas uma determinada turma ainda possui
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
        Exemplo..................: SELECT [dbo].[FNC_DisponibilidadeVagas] (1)
        Retornos.................: Disponibilidade - Sucesso
                                                -1 - Erro: Turma Inexistente
                                                -2 - Erro: Turma Inativa
    */
    BEGIN
        DECLARE @QuantidadeVagas INT;
        DECLARE @MatriculasAtivas INT;
        DECLARE @ReservasReservadas INT;
        DECLARE @Disponibilidade INT;

        -- Validacao de existencia de turma
        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[Turma] WITH(NOLOCK)
                            WHERE Id = @IdTurma
                      )
            RETURN -1;

        IF @IdTurma = ( SELECT Id
                            FROM [dbo].[Turma] 
                            WHERE Ativo = 0
                      )
            RETURN -2;

        -- Consulta de vagas disponíveis
        SELECT  @QuantidadeVagas = tu.Capacidade
            FROM [dbo].[Turma] AS tu WITH(NOLOCK)
            WHERE tu.Id = @IdTurma

        SELECT  @MatriculasAtivas = COUNT(ma.Id)
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                    ON ma.IdTurma = tu.Id
            WHERE ma.IdSituacaoMatricula = 1
            GROUP BY ma.Id
              
        SELECT  @ReservasReservadas = COUNT(rm.Id)
            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                    ON rm.IdTurma = tu.Id
            WHERE  rm.IdSituacaoReserva = 1
                AND rm.DataExpiracao > GETDATE()
            GROUP BY rm.Id
                
        SET @Disponibilidade = @QuantidadeVagas - ( @MatriculasAtivas + @ReservasReservadas )
       
        -- Validacao de quantidade menor ou igual a zero
        IF @Disponibilidade <= 0          
            RETURN 0

        RETURN @Disponibilidade;

    END;
GO

/*-------------------------------------------------------------------------------------------------
	FUNCTION 2 - Valor atualizado da parcela
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_ValorAtualizadoParcela]') AND TYPE = 'FN' )
    DROP FUNCTION [dbo].[FNC_ValorAtualizadoParcela]
GO

CREATE FUNCTION [dbo].[FNC_ValorAtualizadoParcela]  (
                                                        @IdParcela INT,
                                                        @DataReferencia DATE
                                                    )
    RETURNS DECIMAL(10,2)
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Mostrar o valor de uma parcela específica em uma determinada data
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
        Exemplo..................: SELECT [dbo].[FNC_ValorAtualizadoParcela] ( 10, '05-10-2027' )
        Retornos.................: ValorParcela - Sucesso
                                             -1 - Erro: Parcela Inexistente
                                             -2 - Erro: Data de Referencia é antes do da data da criação das parcelas
    */
    BEGIN

        DECLARE @ValorParcela DECIMAL(14,2);

        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[Parcela]
                            WHERE Id = @IdParcela
                      )
            RETURN -1;

        IF @DataReferencia < ( SELECT DataMatricula
                                   FROM [dbo].[Matricula] )
            RETURN -2;

        -- Consulta de valor atualizado da parcela

        SET @ValorParcela = CASE
                                WHEN pa.DataVencimento < @DataReferencia THEN (pa.ValorOriginal * (1 + ((DATEDIFF(MONTH, pa.DataVencimento, @DataReferencia) * 0.01))))
                                ELSE pa.ValorOriginal
                            END as ValorParcela
            FROM [dbo].[Parcela] AS pa WITH(NOLOCK) 
            WHERE pa.Id = @IdParcela     

        RETURN @ValorParcela

    END;
GO

/*-------------------------------------------------------------------------------------------------
	PROCEDURE 1 - Reservar matrícula
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservaMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_ReservaMatricula]
GO

CREATE PROCEDURE [dbo].[SP_ReservaMatricula]
    @IdAluno INT,
    @IdTurma INT
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Reservar uma Matrícula em uma Turma
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_ReservaMatricula] @IdAluno = 1,
                                                                                    @IdTurma = 1

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
                                    ROLLBACK TRAN

        Retornos.................: IdReservaMatricula - Sucesso
                                                   -1 - Erro: Turma Inexistente
                                                   -2 - Erro: Turma Inativa
                                                   -3 - Erro: Aluno Inexistente
                                                   -4 - Erro: Aluno Inativo
                                                   -5 - Erro: Turma Indisponivel
                                                   -6 - Erro: Reserva já existente
                                                   -7 - Erro: erro ao cadastrar a reserva da matrícula
    */
    BEGIN

        DECLARE @DisponibilidadeTurma INT = [dbo].[FNC_DisponibilidadeVagas] (@IdTurma);

        IF @DisponibilidadeTurma = -1
            RETURN -1

        IF @DisponibilidadeTurma = -2
            RETURN -2

        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[Aluno] WITH(NOLOCK)
                            WHERE Id = @IdAluno
                      )
            RETURN -3

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[Aluno] WITH(NOLOCK)
                        WHERE Id = @IdAluno
                            AND Ativo = 0
                  )
            RETURN -4;

        IF @DisponibilidadeTurma = 0
            RETURN -5

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[ReservaMatricula]
                        WHERE IdAluno = @IdAluno
                            AND IdTurma = @IdTurma
                  )
            RETURN -6

        -- Cadastrando Reserva
        INSERT INTO [dbo].[ReservaMatricula] ( IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao )
            VALUES ( @IdAluno, @IdTurma, 1, GETDATE(), DATEADD(DAY, 7, GETDATE()) )

        IF @@ERROR <> 0
        BEGIN
            RAISERROR('Erro: erro ao cadastrar a reserva da matrícula', 16, 1)
            RETURN -7
        END

        DECLARE @IdReservaMatricula INT = SCOPE_IDENTITY()

        RETURN @IdReservaMatricula
    END
GO

/*-------------------------------------------------------------------------------------------------
	PROCEDURE 2 - Efetivar matrícula
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
    @IdReservaMatricula INT,
    @IdAluno INT,
    @IdTurma INT
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Confirmar a matrícula de acordo com os requisitos
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 1,
                                                                                     @IdAluno = 1,
                                                                                     @IdTurma = 1

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
                                    ROLLBACK TRAN

        Retornos.................: IdMatricula - Sucesso
                                            -1 - Erro: Reserva Inexistente
                                            -2 - Erro: Status de Reserva Inválido 
                                            -3 - Erro: Reserva Expirada
                                            -4 - Erro: erro ao efetivar a matrícula.
                                            -5 - Erro: erro ao alterar os status da reserva.
                                            -6 - Erro: erro ao criar parcelas
    */
    BEGIN
        
        DECLARE @Contador INT = 1;
        DECLARE @DataVencimento DATE;

        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[ReservaMatricula] 
                            WHERE Id = @IdReservaMatricula
                      )
            RETURN -1;

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[ReservaMatricula]
                        WHERE Id = @IdReservaMatricula
                            AND IdSituacaoReserva != 1
                   )
            RETURN -2

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[ReservaMatricula] 
                        WHERE Id = @IdReservaMatricula
                            AND DataExpiracao < GETDATE()
                            AND IdSituacaoReserva <> 2
                  )
            RETURN -3;

        -- Atribuindo valor para as variáveis
        
        SELECT  @IdAluno = al.Id,
                @IdTurma = tu.Id
            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                    ON rm.IdAluno = al.Id
                JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                    ON rm.IdTurma = tu.Id
            WHERE rm.Id = @IdReservaMatricula

        -- Cadastrando Matrícula

        BEGIN TRANSACTION

        INSERT INTO [dbo].[Matricula] ( IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade )
            VALUES ( @IdReservaMatricula, @IdAluno, @IdTurma, 1, GETDATE(), 500.00 )

        IF @@ERROR <> 0
        BEGIN
            RAISERROR('Erro: erro ao efetivar a matrícula.', 16, 1)
            RETURN -4
            ROLLBACK TRANSACTION
        END

         DECLARE @IdMatricula INT = SCOPE_IDENTITY();

        -- Alterando Status da Reserva para 'Efetivado'

        UPDATE [dbo].[ReservaMatricula]
        SET IdSituacaoReserva = 2
        WHERE Id = @IdReservaMatricula

        IF @@ERROR <> 0
        BEGIN
            RAISERROR('Erro: erro ao alterar os status da reserva.', 16, 1)
            RETURN -5
            ROLLBACK TRANSACTION
        END

        -- Gerando 12 Parcelas

        SET @DataVencimento = DATEADD(MONTH, 1, (DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 10)))

        WHILE @Contador <= 12
        BEGIN

        INSERT INTO [dbo].[Parcela] ( IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento ) 
            VALUES ( @IdMatricula, 1, 1, 500, DATEADD(MONTH, @Contador, @DataVencimento ))

        SET @Contador = @Contador + 1

        END

        IF @@ERROR <> 0
        BEGIN
            RAISERROR('Erro: erro ao criar parcelas', 16, 1)
            RETURN -6
            ROLLBACK TRANSACTION
        END

        RETURN @IdMatricula

    END
GO

/*-------------------------------------------------------------------------------------------------
	PROCEDURE 3 - Registrar pagamento
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_RegistrarPagamento]
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
    @IdParcela INT,
    @ValorPagamento DECIMAL(14,2)
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Registrar um pagamento de parcela
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 20,
                                                                                      @ValorPagamento = 500.00

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
                                    ROLLBACK TRAN

        Retornos.................: IdPagamento - Sucesso
                                            -1 - Erro: Parcela Inexistente
                                            -2 - Erro: Parcela com status inválido
                                            -3 - Erro: Parcela já está paga
                                            -4 - Erro: Valor pago é menor do que o valor da parcela
                                            -5 - Erro: erro ao registrar pagamento de parcela
    */
    BEGIN
                
        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[Parcela]
                            WHERE Id = @IdParcela
                      )
            RETURN -1

        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[Parcela]
                            WHERE Id = @IdParcela
                                AND ( IdSituacaoParcela != 1
                                OR IdSituacaoParcela != 2 )
                       )
            RETURN -2

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[Parcela]
                        WHERE Id = @IdParcela
                            AND IdSituacaoParcela = 3
                  )
            RETURN -3

        IF @ValorPagamento < ( SELECT ValorOriginal
                                   FROM [dbo].[Parcela] )
            RETURN -4

        -- Registrando Pagamento

        INSERT INTO [dbo].[Pagamento] ( IdParcela, DataPagamento, ValorPago )
            VALUES ( @IdParcela, GETDATE(), @ValorPagamento )

        IF @@ERROR <> 0
        BEGIN
            RAISERROR('Erro: erro ao registrar pagamento de parcela', 16, 1)
            RETURN -5
        END

        DECLARE @IdPagamento INT = SCOPE_IDENTITY()

        RETURN @IdPagamento

    END
GO

/*-------------------------------------------------------------------------------------------------
	PROCEDURE 4 - Cancelar matrícula
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1 )
    DROP PROCEDURE [dbo].[SP_CancelarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
    @IdMatricula INT
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Cancelar uma determinada matrícula
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
        Exemplo..................:    
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    BEGIN TRAN
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                        @Retorno INT;

                                        EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4

                                        SELECT	@Retorno AS Retorno,
                                                DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
                                    ROLLBACK TRAN

        Retornos.................: 0 - Sucesso
                                  -1 - Erro: Matricula Inexistente
                                  -2 - Erro: Status de Matrícula inválido
                                  -3 - Erro: Status de Parcela está pendente e não há nenhuma negociação quitada
                                  -4 - Erro: erro ao cancelar a matrícula
    */
    BEGIN
       
        IF NOT EXISTS ( SELECT TOP 1 1
                            FROM [dbo].[Matricula]
                            WHERE Id = @IdMatricula
                      )
            RETURN -1

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[Matricula] WITH(NOLOCK)
                        WHERE Id = @IdMatricula
                            AND IdSituacaoMatricula != 1
                  )
            RETURN -2

        IF EXISTS ( SELECT TOP 1 1
                        FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
                            JOIN [dbo].[Matricula] AS ma WITH(NOLOCK)
                                ON pa.IdMatricula = ma.Id
                            JOIN [dbo].[Negociacao] AS ne WITH(NOLOCK)
                                ON ma.Id = ne.IdMatricula
                        WHERE ma.Id = @IdMatricula
                            AND ( IdSituacaoParcela = 1
                            OR IdSituacaoParcela = 2 )
                            AND IdSituacaoNegociacao <> 2
                  )
            RETURN -3

        -- Cancelando a matricula

        UPDATE [dbo].[Matricula]
        SET IdSituacaoMatricula = 2
        WHERE Id = @IdMatricula

        IF @@ERROR <> 0
        BEGIN
            RAISERROR('Erro: erro ao cancelar a matrícula', 16, 1)
            RETURN -4
        END

        RETURN 0               

    END
GO

/*-------------------------------------------------------------------------------------------------
    TRIGGER - Atualização da parcela após pagamento
-------------------------------------------------------------------------------------------------*/

IF EXISTS ( SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaPosPagamento]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1 )
    DROP TRIGGER [dbo].[TRG_AtualizarParcelaPosPagamento]
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaPosPagamento]
    ON [dbo].[Pagamento]
    AFTER INSERT
    AS
    /*
        Documentacao

        Arquivo Fonte............: 044-59-matheus-cutrim.sql
        Objetivo.................: Atualizar o status da parcela pos pagamento
        Autor....................: Matheus Cutrim
        Data.....................: 30/09/2026
    */
    BEGIN

        UPDATE [dbo].[Parcela]
        SET IdSituacaoParcela = 3
        WHERE EXISTS ( SELECT TOP 1 1
                           FROM [dbo].[Pagamento]
                           WHERE DataPagamento IS NOT NULL )
    END
GO

/*-------------------------------------------------------------------------------------------------
    TESTES
-------------------------------------------------------------------------------------------------*/

-- Reserva válida

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_ReservaMatricula] @IdAluno = 1,
                                                @IdTurma = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Reserva em turma sem vaga

BEGIN TRAN

    DECLARE @Contador INT = 1
    DECLARE @IdSituacaoMatricula INT = 1

    WHILE @Contador < 4
    BEGIN
        INSERT INTO [dbo].[Matricula] ( IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade )
            VALUES ( @Contador, @Contador, 1, @IdSituacaoMatricula, GETDATE(), 500)

        SET @Contador = @Contador + 1
    END

    DECLARE @DataInicial2 DATETIME = GETDATE(),
            @Retorno2 INT;

    EXEC @Retorno2 = [dbo].[SP_ReservaMatricula] @IdAluno = 1,
                                                 @IdTurma = 3

    SELECT	@Retorno2 AS Retorno,
            DATEDIFF(ms, @DataInicial2, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Reserva Duplicada

BEGIN TRAN
    DECLARE @DataInicial3 DATETIME = GETDATE(),
            @Retorno3 INT;

    EXEC @Retorno3 = [dbo].[SP_ReservaMatricula] @IdAluno = 2,
                                                @IdTurma = 1

    SELECT	@Retorno3 AS Retorno,
            DATEDIFF(ms, @DataInicial3, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Reserva com aluno ou turma inativos

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_ReservaMatricula] @IdAluno = 13,
                                                @IdTurma = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Efetivação válida

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 2,
                                                 @IdAluno = 2,
                                                 @IdTurma = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Efetivar uma reserva já efetivada

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
    @Retorno INT;

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 9,
                                                    @IdAluno = 1,
                                                    @IdTurma = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Efetivar uma reserva com data de expiração vencida

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
    @Retorno INT;

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 10,
                                                    @IdAluno = 1,
                                                    @IdTurma = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Pagamento de parcela dentro do vencimento

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 20,
                                                  @ValorPagamento = 500.00

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Pagamento em atraso

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 1,
                                                  @ValorPagamento = 500.00

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Pagamento de parcela já paga

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
                                                  @ValorPagamento = 500.00

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Teste da TRIGGER, comprovando que a parcela passou para PAGA após o pagamento.

-

-- Teste da TRIGGER com várias linhas: uma única instrução INSERT registrando pagamentos de mais de uma parcela, 
-- comprovando que todas foram atualizadas.

-

-- Tentativa de cancelamento com parcelas pendentes

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
            @Retorno INT;

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 1

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Cancelamento permitido com negociacao quitada

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
    @Retorno INT;

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Cancelamento sem parcelas pendentes

BEGIN TRAN
    DECLARE @DataInicial DATETIME = GETDATE(),
    @Retorno INT;

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4

    SELECT	@Retorno AS Retorno,
            DATEDIFF(ms, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';
ROLLBACK TRAN

-- Consulta das Views e das Functions

SELECT *
FROM [dbo].[VW_MatriculasAtivas]

SELECT *
FROM [dbo].[VW_SituacaoFinanceira]

SELECT [dbo].[FNC_DisponibilidadeVagas] (1)

SELECT [dbo].[FNC_ValorAtualizadoParcela] ( 10, '05-10-2027' )

