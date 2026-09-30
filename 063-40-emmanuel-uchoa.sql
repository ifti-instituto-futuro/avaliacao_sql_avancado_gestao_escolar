/*  AVALIAÇÃO SQL
    Emmanuel Uchoa Lira Barros
    063-40
*/

/* ---------- VIEWS ----------*/


-- VIEW 01

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND TYPE = 'V')
		DROP VIEW [dbo].[VW_HistoricoReservas]
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
AS
	/*
		Documentacao
		Arquivo fonte............:	VW_MatriculasAtivas.sql
		Objetivo.................:	Exibir dados de alunos com matriculas ativas
		Autor....................:	Emmanuel Uchoa
		Data.....................:	30/09/2026
		Ex.......................:  SELECT * FROM [dbo].[VW_MatriculasAtivas]
	*/


	SELECT	al.Id as IdentificacaoAluno,
			al.Nome as NomeAluno,
			cs.Nome as Curso,
			tu.Codigo as CodigoTurma,
			ma.DataMatricula as DataMatricula,
			sm.Descricao as SituacaoMatricula
		FROM [dbo].[Aluno] AS al WITH(NOLOCK)
			INNER JOIN [dbo].[Matricula] AS ma WITH(NOLOCK)
				ON al.Id = ma.IdAluno AND ma.IdSituacaoMatricula = 1
			INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
				ON ma.IdTurma = tu.Id
			INNER JOIN [dbo].[Curso] AS cs WITH(NOLOCK)
				ON cs.Id = tu.IdCurso
			INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
				ON ma.IdSituacaoMatricula = sm.Id


-- VIEW 02

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceiraMatricula]') AND TYPE = 'V')
		DROP VIEW [dbo].[VW_SituacaoFinanceiraMatricula]
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceiraMatricula]
AS
	/*
		Documentacao
		Arquivo fonte............:	VW_SituacaoFinanceiraMatricula.sql
		Objetivo.................:	Exibir dados das questões financeiras por matriculas
		Autor....................:	Emmanuel Uchoa
		Data.....................:	30/09/2026
		Ex.......................:  SELECT * FROM [dbo].[VW_SituacaoFinanceiraMatricula]
	*/

	SELECT	ma.Id as Matricula,
			al.Nome as Aluno,
			COUNT(pa.Id) as TotalParcelas,
			SUM(CASE WHEN pa.IdSituacaoParcela = 3 THEN 1 ELSE 0 END) as QuantidadeParcelasPaga,
			SUM(CASE WHEN pa.IdSituacaoParcela = 1 OR pa.IdSituacaoParcela = 2 THEN 1 ELSE 0 END) as QuantidadeParcelasPendentes,
			SUM(CASE WHEN pa.IdSituacaoParcela = 2 THEN 1 ELSE 0 END) as QuantidadeParcelasVencidas,
			SUM(CASE WHEN pa.IdSituacaoParcela = 1 OR pa.IdSituacaoParcela = 2 THEN pa.ValorOriginal ELSE 0 END) as ValorTotalPendente
		FROM [dbo].[Aluno] AS al WITH(NOLOCK)
			INNER JOIN [dbo].[Matricula] AS ma WITH(NOLOCK)
				ON al.Id = ma.IdAluno
			INNER JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
				ON pa.IdMatricula = ma.Id
			INNER JOIN [dbo].[SituacaoParcela] AS st WITH(NOLOCK)
				ON st.Id = pa.IdSituacaoParcela
		GROUP BY ma.Id, al.Nome


/* ---------- FUNCTIONS ----------- */

--FUNTION 01

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FN_VerificarQuantidadeVagas]') AND TYPE = 'FN')
		DROP FUNCTION [dbo].[FN_VerificarQuantidadeVagas]
GO
CREATE FUNCTION [dbo].[FN_VerificarQuantidadeVagas] (@IdTurma INT)
    RETURNS INT
    AS
    /*
        Documentacao

        Arquivo fonte............:  FN_VerificarQuantidadeVagas.sql
        Objetivo.................:  Retorna o quantidade de vagas disponiveis na turma solicitada
        Autor....................:  Emmanuel Uchoa
        Data.....................:  30/09/2026
        Exemplo..................:  
                                    BEGIN TRANSACTION

                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS
                                                                            
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT;

                                        SELECT @Retorno = [dbo].[FN_VerificarQuantidadeVagas](1)

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(MILLISECOND, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                    ROLLBACK TRANSACTION
        
        Retorno..................: @Vagas - Sucesso
                                       -1 - Erro: Entrada de dados inválida
                                       -2 - Erro: Turma não existente
    */
    BEGIN
        
        -- Verifica a entrada de dados
        IF @IdTurma IS NULL
            RETURN -1

        -- Verifica se existe a turma
        IF NOT EXISTS (
                        SELECT TOP 1 1
                            FROM [dbo].[Turma]
                            WHERE Id = @IdTurma
                      )
            RETURN -2

        -- Declara as variaveis que serão usadas
        DECLARE @CapacidadeTurma INT,
                @Vagas INT,
                @MatriculasAtivas INT,
                @ReservasValidas INT
        
        -- Setamos a capacidade da turma
        SELECT  @CapacidadeTurma = Capacidade
            FROM [dbo].[Turma] WITH(NOLOCK)
            WHERE Id = @IdTurma
        
        -- Contamos as matriculas ativas
        SELECT  @MatriculasAtivas = COUNT(*) 
            FROM [dbo].[Matricula] WITH(NOLOCK)
            WHERE IdSituacaoMatricula = 1 
                AND IdTurma = @IdTurma

        -- Calculamos as reservas validas
        SELECT  @ReservasValidas = COUNT(*)
            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
            WHERE rm.IdTurma = @IdTurma
                AND rm.DataExpiracao >= CAST(GETDATE() AS DATE)
                AND rm.IdSituacaoReserva = 1

        SET @Vagas = @CapacidadeTurma - @MatriculasAtivas - @ReservasValidas

        IF @Vagas < 0
            SET @Vagas = 0

        RETURN @Vagas
    END


-- FUNCTION 02

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FN_AtualizarParcela]') AND TYPE = 'FN')
		DROP FUNCTION [dbo].[FN_AtualizarParcela]
GO
CREATE FUNCTION [dbo].[FN_AtualizarParcela] (@IdParcela INT, @DataReferencia DATE)
    RETURNS INT
    AS
    /*
        Documentacao

        Arquivo fonte............:  FN_AtualizarParcela.sql
        Objetivo.................:  Retorna o quantidade de vagas disponiveis na turma solicitada
        Autor....................:  Emmanuel Uchoa
        Data.....................:  30/09/2026
        Exemplo..................:  
                                    BEGIN TRANSACTION
                        
                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS
                                                                            
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT;

                                        SELECT @Retorno = [dbo].[FN_AtualizarParcela](1, '20260930')

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(MILLISECOND, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                    ROLLBACK TRANSACTION
        
        Retorno..................: @ValorParcela - Sucesso
                                              -1 - Erro: Entrada de dados inválida
                                              -2 - Erro: Parcela não existente
    */
    BEGIN

        -- Validar se a entrada dos dados de parcela é valido
        IF @IdParcela IS NULL OR @DataReferencia IS NULL
            RETURN -1

        -- Validar se existe essa parcela
        IF NOT EXISTS (
                        SELECT TOP 1 1 
                            FROM [dbo].[Parcela] WITH(NOLOCK)
                            WHERE Id = @IdParcela
                      )
            RETURN -2

        -- Declara as variaveis que serão utilizadas
        DECLARE @ValorParcela DECIMAL(10,2),
                @DataVencimento DATE,
                @MesesAtraso INT = 0,
                @NovoValorParcela DECIMAL(10,2)
        
        SELECT  @ValorParcela = ValorOriginal,
                @DataVencimento = DataVencimento
            FROM [dbo].[Parcela] WITH(NOLOCK)
            WHERE @IdParcela = Id
        
        -- Verifica se realmente existe o atraso
        IF @DataReferencia > @DataVencimento
            BEGIN
                SET @MesesAtraso = DATEDIFF(MONTH, @DataVencimento, @DataReferencia)

                IF DAY(@DataReferencia) > DAY(@DataVencimento)
                    SET @MesesAtraso = @MesesAtraso + 1
            END

        -- Sem atraso, retorna o valor normal da parcela
        IF @MesesAtraso = 0
            RETURN @ValorParcela

        -- Com atraso, entra em uma nova variavel o valor
        SET @NovoValorParcela = ROUND(@ValorParcela + (@ValorParcela * 0.1 * @MesesAtraso), 2)

        RETURN @NovoValorParcela

    END

/* ---------- PROCEDURES ----------- */

-- PROCEDURE 01

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
		DROP PROCEDURE [dbo].[SP_ReservarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
	@IdAluno INT, 
	@IdTurma INT
    AS
	/*
		Documentacao

        Arquivo fonte............:  SP_ReservarMatricula.sql
        Objetivo.................:  Reservar uma matricula de aluno em uma turma
        Autor....................:  Emmanuel Uchoa
        Data.....................:  30/09/2026
        Exemplo..................:  
                                    BEGIN TRANSACTION
                                    
                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS
                                                                    
                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT;

                                        SELECT TOP 2 * FROM [dbo].[ReservaMatricula] ORDER BY Id DESC

                                        Exec @Retorno = [dbo].[SP_ReservarMatricula] 1, 1

                                        SELECT TOP 2 * FROM [dbo].[ReservaMatricula] ORDER BY Id DESC

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(MILLISECOND, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                    ROLLBACK TRANSACTION
        
        Retorno..................: 0 - Sucesso
                                  -1 - Erro: Aluno não existente
                                  -2 - Erro: Turma não existente
                                  -3 - Erro: Aluno com reserva já realizada
                                  -4 - Erro: Aluno já matriculado
                                  -5 - Erro: Turma lotada
                                  -6 - Erro: Dados não inseridos 

    */
	BEGIN

        -- Validar a existencia do aluno
        IF NOT EXISTS (
                        SELECT TOP 1 1 
                            FROM [dbo].[Aluno] WITH(NOLOCK)
                            WHERE Id = @IdAluno
                      )
            RETURN -1

        -- Validar a existencia da turma
        IF NOT EXISTS (
                        SELECT TOP 1 1 
                            FROM [dbo].[Turma] WITH(NOLOCK)
                            WHERE Id = @IdTurma
                      )
            RETURN -2

        -- Validar se já existe reserva para esse aluno nessa mesma turma
        IF EXISTS (
                    SELECT TOP 1 1
                        FROM [dbo].[ReservaMatricula]
                        WHERE IdAluno = @IdAluno
                            AND IdTurma = @IdTurma
                            AND IdSituacaoReserva = 1
                            AND DataExpiracao >= CAST(GETDATE() AS DATE)
                   )
            RETURN -3
	
        -- Validar se o aluno ja nao esta matriculado nessa turma
        IF EXISTS (
                    SELECT TOP 1 1
                        FROM [dbo].[Matricula]
                        WHERE IdAluno = @IdAluno
                            AND IdTurma = @IdTurma
                            AND IdSituacaoMatricula = 1
                  )
            RETURN -4

        -- Validar se a turma tem vaga disponivel
        IF (SELECT [dbo].[FN_VerificarQuantidadeVagas](@IdTurma)) <= 0
            RETURN -5

        DECLARE @IdReserva INT,
                @DataReserva DATE = CAST(GETDATE() AS DATE),
                @DataExpiracao DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE))

        -- Insercoes no banco
        INSERT INTO ReservaMatricula(IdAluno, IdTurma, DataReserva, DataExpiracao, IdSituacaoReserva)
            VALUES (@IdAluno, @IdTurma, @DataReserva, @DataExpiracao, 1)

            IF @@ERROR <>0
                RETURN -6

        SET @IdReserva = SCOPE_IDENTITY()

        RETURN @IdReserva

	END

-- PROCEDURE 02

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
		DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
	@IdReserva INT
    AS
	/*
		Documentacao

        Arquivo fonte............:  SP_EfetivarMatricula.sql
        Objetivo.................:  Efetua uma matricula de aluno que tem uma reserva ja realizada
        Autor....................:  Emmanuel Uchoa
        Data.....................:  30/09/2026
        Exemplo..................:  
                                    BEGIN TRANSACTION
                                    
                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS

                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT;

                                        SELECT TOP 2 * FROM [dbo].[Matricula] ORDER BY Id DESC

                                        Exec @Retorno = [dbo].[SP_EfetivarMatricula] 1

                                        SELECT TOP 2 * FROM [dbo].[Matricula] ORDER BY Id DESC

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(MILLISECOND, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                    ROLLBACK TRANSACTION
        
        Retorno..................: @IdMatricula - Sucesso
                                             -1 - Erro: Reserva não existente
                                             -2 - Erro: Status de reserva não de reservada
                                             -3 - Erro: Reserva expirada
                                             -4 - Erro: Não foi possivel atualizar a tabela de Matricula
                                             -5 - Erro: Não foi possivel atualizar a tabela de Reserva
                                             -6 - Erro: Não foi possivel atualizar a tabela de Parcela
    */
	BEGIN

        IF NOT EXISTS (
                        SELECT TOP 1 1
                            FROM [dbo].[ReservaMatricula]
                               WHERE Id = @IdReserva
                      )
            RETURN -1

        DECLARE @IdAluno INT,
                @IdTurma INT,
                @IdMatricula INT, 
                @ValorParcela DECIMAL(10,2),
                @SituacaoReserva INT,
                @DataExpiracao DATE,
                @DataMatricula DATE = GETDATE(),
                @VencimentoParcelaUm DATE,
                @Numero INT = 1

        SELECT  @IdAluno = rm.IdAluno,
                @IdTurma = rm.IdTurma,
                @SituacaoReserva = rm.IdSituacaoReserva,
                @DataExpiracao = rm.DataExpiracao,
                @ValorParcela = cs.ValorMensalidade
            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                    ON rm.IdTurma = tu.Id
                INNER JOIN [dbo].[Curso] AS cs WITH(NOLOCK)
                    ON cs.Id = tu.IdCurso

        IF @SituacaoReserva <> 1
            RETURN -2

        IF @DataExpiracao < CAST(GETDATE() AS DATE)
            RETURN -3

        
        SET @VencimentoParcelaUm = CAST(DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@DataMatricula), MONTH(@DataMatricula), 10)) AS DATE)

        BEGIN TRANSACTION

            INSERT INTO [dbo].[Matricula](IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
                VALUES (@IdReserva, @IdAluno, @IdTurma, 1, @DataMatricula, @ValorParcela)

            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -4
                END

            SET @IdMatricula = SCOPE_IDENTITY()

             UPDATE [dbo].[ReservaMatricula]
                SET IdSituacaoReserva = 2
                WHERE Id = @IdReserva
                    AND IdSituacaoReserva = 1
    
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -5
                END

            WHILE @Numero <= 12
                BEGIN
                    INSERT INTO [dbo].[Parcela] (IdMatricula, Numero, DataVencimento, ValorOriginal, IdSituacaoParcela)
                        VALUES (@IdMatricula, @Numero, DATEADD(MONTH, @Numero - 1, @VencimentoParcelaUm), @ValorParcela, 1)

                    IF @@ERROR <> 0 
                        BEGIN
                            ROLLBACK TRANSACTION
                            RETURN -6
                        END

                    SET @Numero = @Numero + 1
                END
    
        COMMIT TRANSACTION
    
        RETURN @IdMatricula

    END

-- PROCEDURE 03

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
		DROP PROCEDURE [dbo].[SP_RegistrarPagamento]
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
	@IdParcela INT,
    @DataPagamento DATE,
    @ValorPago DECIMAL(10,2)
    AS
	/*
		Documentacao

        Arquivo fonte............:  SP_RegistrarPagamento.sql
        Objetivo.................:  Registra o pagamento de um parcela.
        Autor....................:  Emmanuel Uchoa
        Data.....................:  30/09/2026
        Exemplo..................:  
                                    BEGIN TRANSACTION

                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS

                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT;

                                        SELECT TOP 4 * FROM [dbo].[Pagamento] ORDER BY Id DESC

                                        Exec @Retorno = [dbo].[SP_RegistrarPagamento] 1, '20261015', 750.00

                                        SELECT TOP 4 * FROM [dbo].[Pagamento] ORDER BY Id DESC

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(MILLISECOND, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                    ROLLBACK TRANSACTION
        
        Retorno..................: @IdPagamento - Sucesso
                                             -1 - Erro: Parcela não encontrada
                                             -2 - Erro: Data para pagamento inválido
                                             -3 - Erro: Parcela já paga
                                             -4 - Erro: Parcela Cancelada
                                             -5 - Erro: Valor pago menor que a parcela
                                             -6 - Erro: Não foi possivel inserir os dados na tabela pagamento
    */
	BEGIN

        -- Validar se a parcela existe
        IF NOT EXISTS (
                        SELECT TOP 1 1
                            FROM [dbo].[Parcela]
                            WHERE Id = @IdParcela
                      )
            RETURN -1

        -- Validar se a data para pagamento é valida
        IF @DataPagamento < CAST(GETDATE() AS DATE)
            RETURN -2

        -- Declarar as variaveis
        DECLARE @SituacaoParcela INT,
                @ValorParcela DECIMAL (10,2),
                @IdPagamento INT

        SELECT @SituacaoParcela = IdSituacaoParcela
            FROM [dbo].[Parcela]
            WHERE Id = @IdParcela

        -- Validar se a parcela ja nao foi paga
        IF @SituacaoParcela = 3 
            RETURN -3

        -- Validar se a parcela nao foi cancelada
        IF @SituacaoParcela = 4
            RETURN -4

        SET @ValorParcela = [dbo].[FN_AtualizarParcela](@IdParcela, @DataPagamento)

        IF @ValorPago < @ValorParcela
            RETURN -5
 
        -- Faz a inserção dos dados
        INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
            VALUES (@IdParcela, @DataPagamento, @ValorParcela)
 
        IF @@ERROR <> 0
            RETURN -6
 
        SET @IdPagamento = SCOPE_IDENTITY()
 
        RETURN @IdPagamento

    END

-- PROCEDURE 04

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
		DROP PROCEDURE [dbo].[SP_CancelarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
	@IdMatricula INT
    AS
	/*
		Documentacao

        Arquivo fonte............:  SP_CancelarMatricula.sql
        Objetivo.................:  Cancela a matrícula de um aluno.
        Autor....................:  Emmanuel Uchoa
        Data.....................:  30/09/2026
        Ex.......................:  
                                    BEGIN TRANSACTION

                                        DBCC FREEPROCCACHE
                                        DBCC DROPCLEANBUFFERS

                                        DECLARE @DataInicial DATETIME = GETDATE(),
                                                @Retorno INT,
                                                @IdMatricula INT = 1;

                                        SELECT * FROM [dbo].[Matricula] WHERE Id = @IdMatricula

                                        Exec @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula

                                        SELECT * FROM [dbo].[Matricula] WHERE Id = @IdMatricula

                                        SELECT  @Retorno AS Retorno,
                                                DATEDIFF(MILLISECOND, @DataInicial, GETDATE()) AS 'Tempo execução (ms)';

                                    ROLLBACK TRANSACTION
        
        Retorno..................: 0 - Sucesso
                                  -1 - Erro: Parcela não encontrada
                                  -2 - Erro: Matricula não ativa
                                  -3 - Erro: Nunca teve negociação ou tem negociações em aberto
                                  -4 - Erro: Não possivel fazer o update de cancelamento na matricula
    */
    BEGIN

        --Validar se matricula existe
        IF NOT EXISTS (
                        SELECT TOP 1 1
                         FROM [dbo].[Matricula] WITH(NOLOCK)
                         WHERE Id = @IdMatricula
                      )
            RETURN -1

        DECLARE @StatusMatricula INT,
                @ParcelasPendentes INT,
                @StatusNegociacao INT

        SELECT  @StatusMatricula = IdSituacaoMatricula
            FROM [dbo].[Matricula]WITH(NOLOCK)
            WHERE Id = @IdMatricula

        -- Validar se o aluno ta com matricula ativa
        IF @StatusMatricula <> 1
            RETURN -2

        SELECT  @ParcelasPendentes = COUNT(*)
            FROM [dbo].[Parcela] WITH(NOLOCK)
            WHERE IdMatricula = @IdMatricula
                AND IdSituacaoParcela IN (1 , 2)
        
        -- Validar se existe negociacoes pendentes
        IF @ParcelasPendentes > 0
            BEGIN
                SELECT TOP 1 @StatusNegociacao = IdSituacaoNegociacao
                    FROM [dbo].[Negociacao] WITH(NOLOCK)
                    WHERE IdMatricula = @IdMatricula
                        AND IdSituacaoNegociacao = 2

                -- Caso nunca tenha negociocao
                IF @StatusNegociacao IS NULL
                    RETURN -3

            END
 
        UPDATE [dbo].[Matricula]
            SET IdSituacaoMatricula = 2
            WHERE Id = @IdMatricula
                AND IdSituacaoMatricula = 1
 
        IF @@ERROR <> 0
            RETURN -4
 
        RETURN 0

    END

/* ---------- TRIGGER ---------- */

-- TRIGGER 01

IF EXISTS (SELECT 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarStatusParcela]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1)
	DROP TRIGGER [dbo].[TRG_AtualizarStatusParcela]
GO

CREATE TRIGGER [dbo].[TRG_AtualizarStatusParcela]
	ON [dbo].[Pagamento]
	AFTER INSERT
	AS
	/*
		Documentacao

		Arquivo Fonte............:	TRG_AtualizarStatusParcela.sql
		Objetivo.................:	Atualiza [dbo].[Parcela] automaticamente o status da parcela, após inserção do pagamento na tabela [dbo].[Pagamento]
		Autor....................:	Emmanuel Uchoa
		Data Criação.............:	30/09/2026
	*/

	BEGIN

        -- Validar se tem parcela com status de paga ou cancelada na tabela inserted
        IF EXISTS(SELECT TOP 1 1
                        FROM inserted AS ins
                            JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                                ON pa.Id = ins.IdParcela
                        WHERE pa.IdSituacaoParcela NOT IN (1 , 2)
                 )
            BEGIN
                RAISERROR('Parcela paga ou cancelada, não pode efetuar a ação', 16, 1)
                ROLLBACK TRANSACTION
                RETURN
            END

        -- Atualizar o status para paga
        UPDATE pa
            SET pa.IdSituacaoParcela = 3
            FROM [dbo].[Parcela] AS pa
                JOIN inserted AS ins
                    ON ins.IdParcela = pa.Id
            WHERE pa.IdSituacaoParcela IN (1 ,2)

        IF @@ERROR <> 0
            BEGIN
                RAISERROR('Erro ao atualizar o status da parcela.', 16, 1)
                ROLLBACK TRANSACTION
                RETURN
            END
    END

/* -------- TESTES -------- */

-- Teste 01

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    EXEC [dbo].[SP_ReservarMatricula] @IdAluno = 5,
                                      @IdTurma = 1

    EXEC [dbo].[SP_ReservarMatricula] @IdAluno = 5,
                                      @IdTurma = 1

    EXEC [dbo].[SP_ReservarMatricula] @IdAluno = 13,
                                      @IdTurma = 1

ROLLBACK TRANSACTION
GO


-- Teste 02

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @Retorno INT

    EXEC @Retorno =  [dbo].[SP_EfetivarMatricula] 1

    SELECT  *
        FROM [dbo].[Matricula] WITH(NOLOCK) 
        WHERE Id = @Retorno

    SELECT Id, IdSituacaoReserva
        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
        WHERE Id = @Retorno

    SELECT  *
        FROM [dbo].[Parcela]  WITH(NOLOCK)
        WHERE IdMatricula = @Retorno
        ORDER BY Numero

ROLLBACK TRANSACTION
GO

-- Teste 03

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS


    EXEC [dbo].[SP_ReservarMatricula] @IdAluno = 6,
                                      @IdTurma = 3

    EXEC [dbo].[SP_ReservarMatricula] @IdAluno = 5,
                                      @IdTurma = 2

ROLLBACK TRANSACTION
GO

-- Teste 04

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @Retorno INT,
            @IdParcela INT = 4

    SELECT [dbo].[FN_AtualizarParcela](@IdParcela, '20261005') AS ValorAtualizado

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento]   @IdParcela = @IdParcela,
                                                    @DataPagamento = '20261005',
                                                    @ValorPago = 700.00
    SELECT *
        FROM [dbo].[Parcela] WITH(NOLOCK) 
        WHERE Id = @IdParcela

ROLLBACK TRANSACTION
GO

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @IdParcela INT = 25,
            @Retorno INT
  

    SELECT [dbo].[FN_AtualizarParcela](@IdParcela, '20261005') AS ValorAtualizado

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento]  @IdParcela = @IdParcela,
                                                    @DataPagamento = '20261005',
                                                    @ValorPago = 618.00

    SELECT * 
        FROM [dbo].[Parcela] WITH(NOLOCK) 
        WHERE Id = @IdParcela

ROLLBACK TRANSACTION
GO

-- Teste 05

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @IdParcela INT = 3,
            @Retorno INT
  

    SELECT [dbo].[FN_AtualizarParcela](@IdParcela, '20261015') AS ValorAtualizado

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento]  @IdParcela = @IdParcela,
                                                    @DataPagamento = '20261015',
                                                    @ValorPago = 618.00

    SELECT * 
        FROM [dbo].[Parcela] WITH(NOLOCK) 
        WHERE Id = @IdParcela

ROLLBACK TRANSACTION
GO

-- Teste 06

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    SELECT *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        WHERE Id = 4

    INSERT INTO [dbo].[Pagamento](IdParcela, ValorPago, DataPagamento)
        VALUES (4, 500.00, '20261001')

      SELECT *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        WHERE Id = 4

ROLLBACK TRANSACTION
GO

-- Teste 07

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    SELECT TOP 5 *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        ORDER BY Id DESC

    INSERT INTO [dbo].[Pagamento](IdParcela, ValorPago, DataPagamento)
        VALUES (4, 500.00, '20261001'),(5, 500.00,'20261030'),(6, 500.00, '20261105')

      SELECT TOP 5 *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        ORDER BY Id DESC

ROLLBACK TRANSACTION
GO

-- Teste 08

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @Retorno INT

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2

    SELECT * 
    FROM [dbo].[Matricula] WITH(NOLOCK) 
    WHERE Id = 2

ROLLBACK TRANSACTION
GO

-- Teste 09

BEGIN TRANSACTION

    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @Retorno INT

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 1

    SELECT * 
    FROM [dbo].[Matricula] WITH(NOLOCK)
    WHERE Id = 1

ROLLBACK TRANSACTION
GO

-- Teste 10

SELECT * FROM [dbo].[VW_MatriculasAtivas]

SELECT * FROM [dbo].[VW_SituacaoFinanceiraMatricula]

SELECT [dbo].[FN_VerificarQuantidadeVagas](1) as VagasTurma01

SELECT [dbo].[FN_AtualizarParcela](22, '20261012')


