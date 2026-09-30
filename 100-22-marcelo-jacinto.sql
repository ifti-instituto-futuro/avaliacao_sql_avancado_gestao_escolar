/* =====================================================================
    ESTAGIARIO: MARCELO JACINTO FERREIRA
    MATRICULA: 100-22
   =====================================================================*/

/* =====================================================================
                             VIEWS
   =====================================================================*/
-- VIEWS --01
IF EXISTS (SELECT TOP 1 1  FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
    DROP VIEW [dbo].[VW_MatriculasAtivas]
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
    AS
    /*
        Documentacao
        Arquivo Fonte............:  VW_MatriculasAtivas.sql
        Objetivo.................:  Apresentar as matriculas ativas com aluno, curso e turma
        Autor....................:  Marcelo Jacinto Ferreira
        Data.....................:  30/09/2026
        EX.......................:  DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    SELECT * FROM [dbo].[VW_MatriculasAtivas]
    */

    SELECT  ma.Id as IdMatricula,
            al.Nome as NomeAluno,
            al.Cpf as Cpf,
            cu.Nome as NomeCurso,
            tu.Codigo as CodigoTurma,
            ma.DataMatricula as DataMatricula
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                    INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                        ON ma.IdAluno = al.Id
                    INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                        ON ma.IdTurma = tu.Id
                    INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
                        ON tu.IdCurso = cu.Id
            WHERE ma.IdSituacaoMatricula = 1;
GO

-- VIEW 02 --
IF EXISTS (SELECT TOP 1 1  FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
    DROP VIEW [dbo].[VW_SituacaoFinanceira]
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
    AS
    /*
        Documentacao
        Arquivo Fonte............:  VW_SituacaoFinanceira.sql
        Objetivo.................:  Apresentar a situacao financeira das parcelas de cada matricula
        Autor....................:  Marcelo Jacinto Ferreira
        Data.....................:  30/09/2026
        EX.......................:  DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    SELECT * FROM [dbo].[VW_SituacaoFinanceira]
    */

    SELECT  ma.Id as IdMatricula,
            al.Nome as NomeAluno,
            COUNT(pa.Id) as TotalParcelas,
            SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2) THEN 1 ELSE 0 END) as ParcelasPendentes,
            SUM(CASE WHEN pa.IdSituacaoParcela = 2
                OR (pa.IdSituacaoParcela = 1 AND pa.DataVencimento < CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END) as ParcelasVencidas,
            SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2) THEN pa.ValorOriginal ELSE 0 END) as ValorTotalPendente
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                        ON ma.IdAluno = al.Id
                LEFT JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                        ON ma.Id = pa.IdMatricula
            GROUP BY ma.Id, al.Nome;
GO

/* =====================================================================
                             FUNCTIONS
   =====================================================================*/

-- FUCTION 01 --
IF EXISTS (SELECT  TOP 1 1  FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[FNC_ObterVagasDisponiveis]') AND OBJECTPROPERTY(Id, N'IsScalarFunction') = 1)
    DROP FUNCTION [dbo].[FNC_ObterVagasDisponiveis]
GO

CREATE FUNCTION [dbo].[FNC_ObterVagasDisponiveis] (@IdTurma INT)
	RETURNS INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	FNC_ObterVagasDisponiveis.sql
		Objetivo.................:	Retornar a quantidade de vagas disponiveis de uma turma
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
		EX.......................:	DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS
                                    SELECT [dbo].[FNC_ObterVagasDisponiveis](1) as VagasDisponiveis
		Retornos.................:	@Vagas - Sucesso
									-1 - Erro: Turma inexistente
                                    -2 - Erro: Turma sem vagas
                                    -3 - Erro: vagas abaixo de zero
	*/
	BEGIN
		DECLARE @Vagas INT;

        -- Se turma existe
        IF NOT EXISTS (
                       SELECT  TOP 1 1
                           FROM [dbo].[Turma] WITH(NOLOCK)
                           WHERE Id = @IdTurma
                      )
            RETURN -1;

		-- Busca a capacidade da turma
		SELECT	@Vagas = tu.Capacidade
			FROM [dbo].[Turma] AS tu WITH(NOLOCK)
			WHERE tu.Id = @IdTurma;

        -- se ja esta sem vagas
        if @Vagas <= 0
            RETURN -2;

		-- Desconta as matriculas ativas
		SELECT	@Vagas = @Vagas - COUNT(ma.Id)
			FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			WHERE ma.IdTurma = @IdTurma
				AND ma.IdSituacaoMatricula = 1;

		-- Desconta as reservas vigentes
		SELECT	@Vagas = @Vagas - COUNT(re.Id)
			FROM [dbo].[ReservaMatricula] AS re
			WHERE re.IdTurma = @IdTurma
				AND re.IdSituacaoReserva = 1
				AND re.DataExpiracao >= CAST(GETDATE() AS DATE);

		-- Se está abaixo de zero
		IF @Vagas < 0
			RETURN -3;

		RETURN @Vagas;
	END
GO

-- FUNCTION 02 --

IF EXISTS (SELECT  TOP 1 1 FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[FNC_CalcularValorAtualizadoParcela]') AND OBJECTPROPERTY(Id, N'IsScalarFunction') = 1)
    DROP FUNCTION [dbo].[FNC_CalcularValorAtualizadoParcela]
GO

CREATE FUNCTION [dbo].[FNC_CalcularValorAtualizadoParcela] (@IdParcela INT, @DataReferencia DATE)
	RETURNS DECIMAL(18,2)
	AS
	/*
		Documentacao
		Arquivo Fonte............:	FNC_CalcularValorAtualizadoParcela.sql
		Objetivo.................:	Retornar o valor da parcela com juros de atraso na data de referencia
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
		EX.......................:	SELECT [dbo].[FNC_CalcularValorAtualizadoParcela](25, '2026-09-30') as ValorAtualizado
		Retornos.................:	Parcela - Sucesso
									-1 - Erro: Parcela inexistente
                                    -2 - Erro: Valor inexistente
	*/
	BEGIN
		DECLARE @ValorOriginal DECIMAL(18,2),
				@DataVencimento DATE,
				@Meses INT;

		-- Verifica se parcela existe
        IF NOT EXISTS (
                       SELECT TOP 1 1 
                           FROM [dbo].[Parcela] WITH(NOLOCK)
                           WHERE Id = @IdParcela
                      )
            RETURN -1;

		-- Busca a parcela
		SELECT	@ValorOriginal = pa.ValorOriginal,
				@DataVencimento = pa.DataVencimento
			FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
			WHERE pa.Id = @IdParcela;

		-- Se existe valor de parcela
		IF @ValorOriginal IS NULL
			RETURN -2;

		-- Sem atraso
		IF @DataReferencia <= @DataVencimento
			RETURN @ValorOriginal;

		-- Conta os meses iniciados apos o vencimento
		SET @Meses = DATEDIFF(MONTH, @DataVencimento, @DataReferencia);

		IF DATEADD(MONTH, @Meses, @DataVencimento) < @DataReferencia
			SET @Meses = @Meses + 1

		RETURN CAST(@ValorOriginal + @ValorOriginal * 0.01 * @Meses AS DECIMAL(18,2));
	END
GO

/* =====================================================================
                             PROCEDURES
   =====================================================================*/

-- PROCEDURE 01 --

IF EXISTS (SELECT TOP 1 1 FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[SP_ReservarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
	@IdAluno INT,
	@IdTurma INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	SP_ReservarMatricula.sql
		Objetivo.................:	Registrar a reserva de vaga de um aluno em uma turma por 7 dias
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
		EX.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @Retorno INT,
											@DataInicio DATETIME = GETDATE()

									EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 9, @IdTurma = 3

									SELECT	@Retorno as Retorno,
											DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo
		Retornos.................:	IdReserva - Sucesso
									-1 - Erro: aluno inexistente
									-2 - Erro: turma inexistente
									-3 - Erro: aluno inativo
									-4 - Erro: turma inativa
									-5 - Erro: reserva ja existe
									-6 - Erro: matricula tiva ja existente
									-7 - Erro: turma sem vaga disponivel
									-8 - Erro: falha na insercao no banco
									
	*/
	BEGIN
    
		DECLARE @AlunoAtivo BIT,
				@TurmaAtiva BIT,
				@DataReserva DATETIME = GETDATE();

		-- Se aluno existe
		IF NOT EXISTS (
                       SELECT TOP 1 1 
                           FROM [dbo].[Aluno] WITH(NOLOCK)
                           WHERE Id = @IdAluno
                      )
			RETURN -1;

         -- Se turma existe
		IF NOT EXISTS (
                       SELECT TOP 1 1 
                           FROM [dbo].[Turma] WITH(NOLOCK)
                           WHERE Id = @IdTurma
                      )
            RETURN -2;

		-- Busca o aluno
		SELECT	@AlunoAtivo = al.Ativo
			FROM [dbo].[Aluno] AS al WITH(NOLOCK)
			WHERE al.Id = @IdAluno;

		-- Se aluno esta inativo
		IF @AlunoAtivo = 0
			RETURN -3;

		-- Busca a turma
		SELECT	@TurmaAtiva = tu.Ativo
			FROM [dbo].[Turma] AS tu WITH(NOLOCK)
			WHERE tu.Id = @IdTurma;

		-- Se turma esta inativa
		IF @TurmaAtiva = 0
			RETURN -4;

		-- Se reserva ja existente
        IF EXISTS (
                   SELECT  TOP 1 1
                       FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
                       WHERE re.IdAluno = @IdAluno
                           AND re.IdTurma = @IdTurma
                           AND re.IdSituacaoReserva = 1 
                           AND re.DataExpiracao >= CAST(@DataReserva AS DATE)
                  )
			RETURN -5;

		-- Matricula ativa ja existente
        IF EXISTS (
                   SELECT	TOP 1 1
                       FROM [dbo].[Matricula] AS mat WITH(NOLOCK)
                       WHERE mat.IdAluno = @IdAluno
                           AND mat.IdTurma = @IdTurma
                           AND mat.IdSituacaoMatricula = 1 
                  )
			RETURN -6;

		-- Se turma esta sem vaga
		IF [dbo].[FNC_ObterVagasDisponiveis](@IdTurma) < 0
			RETURN -7;

		-- Grava a reserva por 7 dias
		INSERT INTO [dbo].[ReservaMatricula] (IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
			SELECT	@IdAluno,
					@IdTurma,
					1,
					@DataReserva,
					DATEADD(DAY, 7, CAST(@DataReserva AS DATE))
				WHERE NOT EXISTS (
                                  SELECT	TOP 1 1
                                      FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
                                      WHERE re.IdAluno = @IdAluno
                                          AND re.IdTurma = @IdTurma
                                          AND re.IdSituacaoReserva = 1 
                                          AND re.DataExpiracao >= CAST(@DataReserva AS DATE)
								 )
					AND [dbo].[FNC_ObterVagasDisponiveis](@IdTurma) > 0;

        -- Se insert na ReservaMatricula falhou
		IF @@ERROR <> 0 OR @@ROWCOUNT = 0
			RETURN -8;

		RETURN SCOPE_IDENTITY();
	END
GO

-- PROCEDURE 02 --
IF EXISTS (SELECT   top 1 1 FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
	@IdReserva INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	SP_EfetivarMatricula.sql
		Objetivo.................:	Efetivar a reserva em matricula ativa e gerar as 12 parcelas
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
		EX.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @Retorno INT,
											@DataInicio DATETIME = GETDATE()

									EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 1

									SELECT	@Retorno as Retorno,
											DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo
		Retornos.................:	IdMatricula - Sucesso
									-1 - Erro: reserva inexistente
									-2 - Erro: reserva nao esta RESERVADA
									-3 - Erro: reserva expirada
									-4 - Erro na alteracao da reserva
									-5 - Erro na gravacao da matricula
									-6 - Erro na geracao das parcelas
								 
	*/
	BEGIN
		DECLARE @IdAluno INT,
				@IdTurma INT,
				@IdSituacaoReserva TINYINT,
				@DataExpiracao DATE,
				@ValorMensalidade DECIMAL(18,2),
				@DataMatricula DATETIME = GETDATE(),
				@IdMatricula INT;

		 -- Se reserva existe
		IF NOT EXISTS (
                       SELECT TOP 1 1 
                           FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                           WHERE Id = @IdReserva
                      )
            RETURN -1;

		-- Busca a reserva com a mensalidade atual do curso
		SELECT	@IdAluno = re.IdAluno,
				@IdTurma = re.IdTurma,
				@IdSituacaoReserva = re.IdSituacaoReserva,
				@DataExpiracao = re.DataExpiracao,
				@ValorMensalidade = cu.ValorMensalidade
			FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
				INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
					ON re.IdTurma = tu.Id
				INNER JOIN [Curso] AS cu WITH(NOLOCK)
					ON tu.IdCurso = cu.Id
			WHERE re.Id = @IdReserva;

		-- Se reserva esta como reservada
		IF @IdSituacaoReserva <> 1
			RETURN -2;

		-- Se reserva esta expirada
		IF @DataExpiracao < CAST(@DataMatricula AS DATE)
			RETURN -3;

		BEGIN TRANSACTION;

			-- Efetiva a reserva
			UPDATE [dbo].[ReservaMatricula]
				SET IdSituacaoReserva = 2 
				WHERE Id = @IdReserva
					AND IdSituacaoReserva = 1; 

            -- Se deu erro no update
			IF @@ERROR <> 0 OR @@ROWCOUNT = 0
				BEGIN
					ROLLBACK TRANSACTION;
					RETURN -4;
				END

			-- Grava a matricula ativa
			INSERT INTO [dbo].[Matricula] (IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
				VALUES (@IdReserva, @IdAluno, @IdTurma, 1, @DataMatricula, @ValorMensalidade);

            -- Se deu erro na insercao
			IF @@ERROR <> 0 OR @@ROWCOUNT = 0
				BEGIN
					ROLLBACK TRANSACTION;
					RETURN -5;
				END

			SET @IdMatricula = SCOPE_IDENTITY();

			-- Gera as 12 parcelas abertas
			INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
				SELECT	@IdMatricula,
						1,
						Numeros.Numero,
						@ValorMensalidade,
						DATEADD(MONTH, Numeros.Numero, DATEFROMPARTS(YEAR(@DataMatricula), MONTH(@DataMatricula), 10))
					FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12)) AS Numeros (Numero);

            -- se deu erro no insert
			IF @@ERROR <> 0 OR @@ROWCOUNT <> 12
				BEGIN
					ROLLBACK TRANSACTION;
					RETURN -6;
				END

		COMMIT TRANSACTION;

		RETURN @IdMatricula;
	END
GO

-- PROCEDURE 03 --

IF EXISTS (SELECT  TOP 1 1 FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[SP_RegistrarPagamento]
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
	@IdParcela		INT,
	@DataPagamento	DATETIME,
	@ValorPago		DECIMAL(18,2)
	AS
	/*
		Documentacao
		Arquivo Fonte............:	SP_RegistrarPagamento.sql
		Objetivo.................:	Registrar o pagamento de uma parcela pelo valor atualizado
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
		EX.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @Retorno INT,
											@DataInicio DATETIME = GETDATE()

									EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 28, @DataPagamento = '2026-10-05', @ValorPago = 600.00

									SELECT	@Retorno as Retorno,
											DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo
		Retornos.................:	IdPagamento - Sucesso
									-1 - Erro: parcela inexistente
									-2 - Erro: parcela ja paga
									-3 - Erro: parcela cancelada
									-4 - Erro: valor pago menor
									-5 - Erro na gravacao do pagamento
									
	*/
	BEGIN
		DECLARE @IdSituacaoParcela TINYINT;

		-- Se parcela existe
		IF	NOT EXISTS (
                        SELECT  TOP 1 1 
                            FROM [dbo].[Parcela] WITH(NOLOCK)
                            WHERE Id = @IdParcela
                       )
			RETURN -1;

		-- Busca a parcela
		SELECT	@IdSituacaoParcela = pa.IdSituacaoParcela
			FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
			WHERE pa.Id = @IdParcela;

		-- Se parcela esta paga
		IF @IdSituacaoParcela = 3
			RETURN -2;

		-- Parcela cancelada
		IF @IdSituacaoParcela NOT IN (1, 2)
			RETURN -3;

		-- Se valor é abaixo do atualizado
		IF @ValorPago < [dbo].[FNC_CalcularValorAtualizadoParcela](@IdParcela, @DataPagamento)
			RETURN -4;

		-- Grava o pagamento
		INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
			SELECT	@IdParcela,
					@DataPagamento,
					@ValorPago
				WHERE EXISTS	(
								 SELECT	TOP 1 1
									 FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
									 WHERE pa.Id = @IdParcela
										 AND pa.IdSituacaoParcela IN (1, 2)
								);
        -- se houve erro no insert
		IF @@ERROR <> 0 OR @@ROWCOUNT = 0
			RETURN -5;

		RETURN SCOPE_IDENTITY();
	END
GO

-- PROCEDURE 04 --
IF EXISTS (SELECT * FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[SP_CancelarMatricula]
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
	@IdMatricula INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	SP_CancelarMatricula.sql
		Objetivo.................:	Cancelar a matricula ativa conforme a situacao financeira
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
		EX.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @Retorno INT,
											@DataInicio DATETIME = GETDATE()

									EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2

									SELECT	@Retorno as Retorno,
											DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo
		Retornos.................:	0 - Sucesso
									1 - Erro: matricula inexistente
									2 - Erro: matricula nao esta ATIVA
									3 - Erro: parcelas pendentes sem negociacao QUITADA
									4 - Erro na alteracao da matricula
	*/
	BEGIN
		DECLARE @IdSituacaoMatricula TINYINT;

		-- Se matricula existe
		IF NOT EXISTS (
                       SELECT  TOP 1 1 
                           FROM [dbo].[Matricula] WITH(NOLOCK)
                           WHERE Id = @IdMatricula
                      )
            RETURN 1;

		-- Busca a matricula
		SELECT	@IdSituacaoMatricula = ma.IdSituacaoMatricula
			FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			WHERE ma.Id = @IdMatricula;

		-- Matricula fora de Ativa
		IF @IdSituacaoMatricula <> 1
			RETURN 2;

		-- Pendencia sem negociacao quitada
		IF EXISTS	(
					 SELECT	TOP 1 1
						 FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
						 WHERE pa.IdMatricula = @IdMatricula
							 AND pa.IdSituacaoParcela IN (1, 2) 
					)
			AND NOT EXISTS	(
							 SELECT	TOP 1 1
								 FROM [dbo].[Negociacao] AS ne WITH(NOLOCK)
								 WHERE ne.IdMatricula = @IdMatricula
									 AND ne.IdSituacaoNegociacao = 2 
							)
			RETURN 3;

		-- Cancela a matricula
		UPDATE [dbo].[Matricula]
			SET IdSituacaoMatricula = 2 
			WHERE Id = @IdMatricula
				AND IdSituacaoMatricula = 1;

        -- Se update foi efetuado
		IF @@ERROR <> 0 OR @@ROWCOUNT = 0
			RETURN 4;

		RETURN 0;
	END
GO

/* =====================================================================
                             TRIGGERS
   =====================================================================*/

-- TRIGGER --
IF EXISTS (SELECT  TOP 1 1 FROM sysobjects WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaPaga]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1)
    DROP TRIGGER [dbo].[TRG_AtualizarParcelaPaga]
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaPaga]
	ON [dbo].[Pagamento]
	AFTER INSERT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	TRG_AtualizarParcelaPaga.sql
		Objetivo.................:	Marcar como PAGA as parcelas abertas ou vencidas que receberam pagamento
		Autor....................:	Marcelo Jacinto Ferreira
		Data.....................:	30/09/2026
	*/
	BEGIN
		-- Marca as parcelas pagas
		UPDATE	pa
			SET	pa.IdSituacaoParcela = 3 
			FROM [dbo].[Parcela] AS pa
				INNER JOIN Inserted AS ir
				ON pa.Id = ir.IdParcela
			WHERE pa.IdSituacaoParcela IN (1, 2);
	END
GO


/* =====================================================================
                             TESTES
   =====================================================================*/

-- VIEW 01 --
SELECT	* FROM [dbo].[VW_MatriculasAtivas];
GO

-- VIEW 02 --
SELECT	* FROM [dbo].[VW_SituacaoFinanceira] AS vs WITH(NOLOCK);
GO

-- FUCTION 01 --
SELECT	[dbo].[FNC_ObterVagasDisponiveis](1) as VagasTurma1,
		[dbo].[FNC_ObterVagasDisponiveis](2) as VagasTurma2,
		[dbo].[FNC_ObterVagasDisponiveis](3) as VagasTurma3;
GO

-- FUCTION 02 --

SELECT	[dbo].[FNC_CalcularValorAtualizadoParcela](25, '2026-07-10') as ValorNoVencimento,
		[dbo].[FNC_CalcularValorAtualizadoParcela](25, '2026-07-11') as ValorUmDiaDeAtraso,
		[dbo].[FNC_CalcularValorAtualizadoParcela](25, '2026-08-10') as ValorUmMesDeAtraso,
		[dbo].[FNC_CalcularValorAtualizadoParcela](25, '2026-08-11') as ValorUmMesEUmDia;
GO

-- PROCEDURE 01 --

DECLARE @Retorno INT;

BEGIN TRANSACTION;

	-- Reserva valida com reserva anterior expirada
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 9, @IdTurma = 3;

	SELECT	@Retorno as ReservaValida;

	-- Turma sem vaga
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 10, @IdTurma = 3;

	SELECT	@Retorno as ReservaSemVaga;

	-- Reserva duplicada
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 1, @IdTurma = 1;

	SELECT	@Retorno as ReservaDuplicada;

	-- Aluno inativo
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 13, @IdTurma = 1;

	SELECT	@Retorno as AlunoInativo;

	-- Turma inativa
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 10, @IdTurma = 4;

	SELECT	@Retorno as TurmaInativa;

ROLLBACK TRANSACTION;
GO

-- PROCEDURE 02 --
DECLARE @Retorno INT;

BEGIN TRANSACTION;

	-- Efetivacao valida
	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 1;

	SELECT	@Retorno as IdMatricula;

	-- Confere as 12 parcelas
	SELECT	pa.Numero as Numero,
			pa.ValorOriginal as ValorOriginal,
			pa.DataVencimento as DataVencimento,
			pa.IdSituacaoParcela as IdSituacaoParcela
		FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
		WHERE pa.IdMatricula = @Retorno;

	-- Reserva ja efetivada
	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 6;

	SELECT	@Retorno as ReservaJaEfetivada;

	-- Reserva com expiracao vencida
	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReserva = 10;

	SELECT	@Retorno as ReservaExpirada;

ROLLBACK TRANSACTION;
GO

-- PROCEDURE 03 --
DECLARE @Retorno INT;

BEGIN TRANSACTION;

	-- Pagamento dentro do vencimento
	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 28, @DataPagamento = '2026-10-05', @ValorPago = 600.00;

	SELECT	@Retorno as PagamentoNoPrazo;

	-- Pagamento em atraso sem os juros
	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 25, @DataPagamento = '2026-09-30', @ValorPago = 600.00;

	SELECT	@Retorno as PagamentoSemJuros;

	-- Pagamento em atraso com os juros
	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 25, @DataPagamento = '2026-09-30', @ValorPago = 618.00;

	SELECT	@Retorno as PagamentoEmAtraso;

	-- Parcela ja paga
	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 1, @DataPagamento = '2026-09-30', @ValorPago = 500.00;

	SELECT	@Retorno as ParcelaJaPaga;

ROLLBACK TRANSACTION;
GO

-- PROCEDURE 04 --
DECLARE @Retorno INT;

BEGIN TRANSACTION;

	-- Pendencias com negociacao aberta
	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 1;

	SELECT	@Retorno as NegociacaoAberta;

	-- Pendencias sem negociacao
	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 3;

	SELECT	@Retorno as SemNegociacao;

	-- Pendencias com negociacao quitada
	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2;

	SELECT	@Retorno as NegociacaoQuitada;

	-- Sem parcelas pendentes
	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4;

	SELECT	@Retorno as SemPendencias;

	-- Confere as matriculas canceladas
	SELECT	ma.Id as IdMatricula,
			ma.IdSituacaoMatricula as IdSituacaoMatricula
		FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
		WHERE ma.Id IN (2, 4);

ROLLBACK TRANSACTION;
GO

-- TRIGGER --
BEGIN TRANSACTION;

	-- Situacao antes dos pagamentos
	SELECT	pa.Id as IdParcela,
			pa.IdSituacaoParcela as IdSituacaoParcela
		FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
		WHERE pa.Id IN (28, 29, 30);

	-- Pagamento de uma parcela
	INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
		VALUES (28, '2026-10-05', 600.00);

	SELECT	pa.Id as IdParcela,
			pa.IdSituacaoParcela as IdSituacaoParcela
		FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
		WHERE pa.Id = 28;

	-- Pagamentos de varias parcelas numa instrucao
	INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
		VALUES	(29, '2026-11-05', 600.00),
				(30, '2026-12-05', 600.00);

	SELECT	pa.Id as IdParcela,
			pa.IdSituacaoParcela as IdSituacaoParcela
		FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
		WHERE pa.Id IN (29, 30);

ROLLBACK TRANSACTION;
