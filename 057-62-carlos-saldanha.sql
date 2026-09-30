/* =====================================================
   Estagiario: Carlos Guilherme Saldanha Da Silva
   Avaliacao: Banco de Dados Avancado - Gestao Escolar
   ===================================================== */

USE Escola;
GO

/* =====================================================
   VIEW 01
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
	DROP VIEW [dbo].[VW_MatriculasAtivas];
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Listar somente as matriculas ATIVAS, identificando aluno, curso,
									turma, data da matricula e situacao.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	SELECT * FROM [dbo].[VW_MatriculasAtivas]
	*/

	SELECT	ma.Id as IdMatricula,
			al.Nome as NomeAluno,
			al.Cpf as CpfAluno,
			cu.Nome as NomeCurso,
			tu.Codigo as CodigoTurma,
			ma.DataMatricula as DataMatricula,
			sm.Descricao as SituacaoMatricula
		FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
				ON al.Id = ma.IdAluno
			INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
				ON tu.Id = ma.IdTurma
			INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
				ON sm.Id = ma.IdSituacaoMatricula
			INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
				ON cu.Id = tu.IdCurso
		WHERE ma.IdSituacaoMatricula = 1
GO

/* =====================================================
   VIEW 02
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
	DROP VIEW [dbo].[VW_SituacaoFinanceira];
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Apresentar uma linha por matricula, com o aluno, o total de parcelas,
									as quantidades de parcelas pagas, pendentes e vencidas (RN07)
									e o valor total ainda pendente.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	SELECT * FROM [dbo].[VW_SituacaoFinanceira]
	*/

	SELECT	ma.Id as IdMatricula,
			al.Nome as NomeAluno,
			COUNT(pa.Id) as TotalParcelas,
			SUM(CASE WHEN pa.IdSituacaoParcela = 3 THEN 1 ELSE 0 END) as ParcelasPagas,
			SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2) THEN 1 ELSE 0 END) as ParcelasPendentes,
			SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2)
						AND pa.DataVencimento < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END) as ParcelasVencidas,
			ISNULL(SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2) THEN pa.ValorOriginal ELSE 0 END), 0) as ValorPendente
		FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
				ON al.Id = ma.IdAluno
			LEFT JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
				ON pa.IdMatricula = ma.Id
		GROUP BY ma.Id, al.Nome
GO

/* =====================================================
   FUNCTION 01
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_VagasDisponiveis]') AND OBJECTPROPERTY(Id, N'IsScalarFunction') = 1)
	DROP FUNCTION [dbo].[FNC_VagasDisponiveis];
GO

CREATE FUNCTION [dbo].[FNC_VagasDisponiveis] (@IdTurma INT)
	RETURNS INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Receber uma turma e retornar quantas vagas ela ainda possui (RN02)
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @DataInicial DATETIME = GETDATE(),
											@Retorno INT;

									SELECT @Retorno = [dbo].[FNC_VagasDisponiveis](1)

									SELECT	@Retorno AS Retorno,
											DATEDIFF(ms, @DataInicial, GETDATE()) AS TempoExecucao
		Retornos.................:	Quantidade de vagas disponiveis na turma
	*/
	BEGIN
		DECLARE @Capacidade INT,
				@Matriculas INT,
				@Reservas INT;

		-- Capacidade da turma
		SELECT	@Capacidade = Capacidade
			FROM [dbo].[Turma] WITH(NOLOCK)
			WHERE Id = @IdTurma;

		-- Matriculas ativas na turma
		SELECT	@Matriculas = COUNT(Id)
			FROM [dbo].[Matricula] WITH(NOLOCK)
			WHERE IdTurma = @IdTurma
				AND IdSituacaoMatricula = 1;

		-- Reservas que ainda nao expiraram
		SELECT	@Reservas = COUNT(Id)
			FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
			WHERE IdTurma = @IdTurma
				AND IdSituacaoReserva = 1
				AND DataExpiracao >= CAST(GETDATE() AS DATE);

		RETURN @Capacidade - (@Matriculas + @Reservas);
	END
GO

/* =====================================================
   FUNCTION 02
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_ValorAtualizadoParcela]') AND OBJECTPROPERTY(Id, N'IsScalarFunction') = 1)
	DROP FUNCTION [dbo].[FNC_ValorAtualizadoParcela];
GO

CREATE FUNCTION [dbo].[FNC_ValorAtualizadoParcela] (@IdParcela INT, @DataReferencia DATE)
	RETURNS DECIMAL(14, 2)
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Receber uma parcela e uma data de referencia e retornar quanto a parcela
									vale nessa data, com juros de 1% por mes de atraso (RN06 e RN07)
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @DataInicial DATETIME = GETDATE(),
											@Retorno DECIMAL(14, 2);

									SELECT @Retorno = [dbo].[FNC_ValorAtualizadoParcela](25, '20260811')

									SELECT	@Retorno AS Retorno,
											DATEDIFF(ms, @DataInicial, GETDATE()) AS TempoExecucao
		Retornos.................:	Valor da parcela na data informada
	*/
	BEGIN
		DECLARE @ValorOriginal DECIMAL(14, 2),
				@DataVencimento DATE,
				@MesesAtraso INT = 0;

		SELECT	@ValorOriginal = ValorOriginal,
				@DataVencimento = DataVencimento
			FROM [dbo].[Parcela] WITH(NOLOCK)
			WHERE Id = @IdParcela;

		-- Conta os meses de atraso, considerando mes iniciado como mes inteiro
		IF @DataReferencia > @DataVencimento
			BEGIN
				SET @MesesAtraso = DATEDIFF(MONTH, @DataVencimento, @DataReferencia);

				IF DATEADD(MONTH, @MesesAtraso, @DataVencimento) < @DataReferencia
					SET @MesesAtraso = @MesesAtraso + 1;
			END

		RETURN @ValorOriginal * (1 + 0.01 * @MesesAtraso);
	END
GO

/* =====================================================
   PROCEDURE 01
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_ReservarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
	@IdAluno INT,
	@IdTurma INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Validar a RN01 e a RN02 e registrar a reserva da matricula
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									BEGIN TRAN
										DECLARE @DataInicial DATETIME = GETDATE(),
												@Retorno INT;

										EXEC @Retorno = [dbo].[SP_ReservarMatricula] 10, 2

										SELECT	@Retorno AS Retorno,
												DATEDIFF(ms, @DataInicial, GETDATE()) AS TempoExecucao
									ROLLBACK TRAN
		Retornos.................:	 0 - Sucesso
									-1 - Erro: aluno inexistente
									-2 - Erro: aluno inativo
									-3 - Erro: turma inexistente
									-4 - Erro: turma inativa
									-5 - Erro: aluno ja possui reserva nesta turma
									-6 - Erro: aluno ja possui matricula ativa nesta turma
									-7 - Erro: turma sem vaga disponivel
									-8 - Erro: falha ao inserir a reserva
	*/
	BEGIN
		-- Valida se o aluno existe
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Aluno] WITH(NOLOCK) WHERE Id = @IdAluno)
			RETURN -1;

		-- Valida se o aluno esta ativo
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Aluno] WITH(NOLOCK) WHERE Id = @IdAluno AND Ativo = 1)
			RETURN -2;

		-- Valida se a turma existe
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Turma] WITH(NOLOCK) WHERE Id = @IdTurma)
			RETURN -3;

		-- Valida se a turma esta ativa
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Turma] WITH(NOLOCK) WHERE Id = @IdTurma AND Ativo = 1)
			RETURN -4;

		-- Impede reserva duplicada na mesma turma
		IF EXISTS (SELECT TOP 1 1 FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
						WHERE IdAluno = @IdAluno
							AND IdTurma = @IdTurma
							AND IdSituacaoReserva = 1
							AND DataExpiracao >= CAST(GETDATE() AS DATE))
			RETURN -5;

		-- Impede reserva se o aluno ja esta matriculado na turma
		IF EXISTS (SELECT TOP 1 1 FROM [dbo].[Matricula] WITH(NOLOCK)
						WHERE IdAluno = @IdAluno
							AND IdTurma = @IdTurma
							AND IdSituacaoMatricula = 1)
			RETURN -6;

		-- Valida se a turma tem vaga
		IF [dbo].[FNC_VagasDisponiveis](@IdTurma) <= 0
			RETURN -7;

		INSERT INTO [dbo].[ReservaMatricula] (IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
			VALUES (@IdAluno, @IdTurma, 1, GETDATE(), DATEADD(DAY, 7, CAST(GETDATE() AS DATE)));

		IF @@ERROR <> 0
			RETURN -8;

		RETURN 0;
	END
GO

/* =====================================================
   PROCEDURE 02
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_EfetivarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
	@IdReservaMatricula INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Validar a reserva, criar a matricula, alterar a situacao da reserva
									e gerar as 12 parcelas (RN03 e RN04)
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									BEGIN TRAN
										DECLARE @DataInicial DATETIME = GETDATE(),
												@Retorno INT;

										EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 4

										SELECT	@Retorno AS Retorno,
												DATEDIFF(ms, @DataInicial, GETDATE()) AS TempoExecucao
									ROLLBACK TRAN
		Retornos.................:	 0 - Sucesso
									-1 - Erro: reserva inexistente
									-2 - Erro: reserva nao esta RESERVADA
									-3 - Erro: reserva expirada
									-4 - Erro: falha ao inserir a matricula
									-5 - Erro: falha ao atualizar a reserva
									-6 - Erro: falha ao gerar as parcelas
	*/
	BEGIN
		DECLARE @IdAluno INT,
				@IdTurma INT,
				@IdSituacaoReserva INT,
				@DataExpiracao DATE,
				@ValorMensalidade DECIMAL(14, 2),
				@IdMatricula INT,
				@DataMatricula DATETIME = GETDATE(),
				@PrimeiroVencimento DATE,
				@Contador INT = 1;

		-- Valida se a reserva existe
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[ReservaMatricula] WITH(NOLOCK) WHERE Id = @IdReservaMatricula)
			RETURN -1;

		SELECT	@IdAluno = IdAluno,
				@IdTurma = IdTurma,
				@IdSituacaoReserva = IdSituacaoReserva,
				@DataExpiracao = DataExpiracao
			FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
			WHERE Id = @IdReservaMatricula;

		-- So efetiva reserva na situacao RESERVADA
		IF @IdSituacaoReserva <> 1
			RETURN -2;

		-- Valida se a reserva nao expirou
		IF @DataExpiracao < CAST(@DataMatricula AS DATE)
			RETURN -3;

		SELECT	@ValorMensalidade = cu.ValorMensalidade
			FROM [dbo].[Turma] AS tu WITH(NOLOCK)
				INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
					ON cu.Id = tu.IdCurso
			WHERE tu.Id = @IdTurma;

		-- Primeiro vencimento no dia 10 do mes seguinte
		SET @PrimeiroVencimento = DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@DataMatricula), MONTH(@DataMatricula), 10));

		BEGIN TRANSACTION

			INSERT INTO [dbo].[Matricula] (IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
				VALUES (@IdReservaMatricula, @IdAluno, @IdTurma, 1, @DataMatricula, @ValorMensalidade);

			IF @@ERROR <> 0
				BEGIN
					ROLLBACK TRANSACTION
					RETURN -4;
				END

			SET @IdMatricula = SCOPE_IDENTITY();

			UPDATE [dbo].[ReservaMatricula]
				SET IdSituacaoReserva = 2
				WHERE Id = @IdReservaMatricula;

			IF @@ERROR <> 0
				BEGIN
					ROLLBACK TRANSACTION
					RETURN -5;
				END

			-- Gera as 12 parcelas
			WHILE @Contador <= 12
				BEGIN
					INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
						VALUES (@IdMatricula, 1, @Contador, @ValorMensalidade, DATEADD(MONTH, @Contador - 1, @PrimeiroVencimento));

					IF @@ERROR <> 0
						BEGIN
							ROLLBACK TRANSACTION
							RETURN -6;
						END

					SET @Contador = @Contador + 1;
				END

		COMMIT TRANSACTION

		RETURN 0;
	END
GO

/* =====================================================
   PROCEDURE 03
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_RegistrarPagamento];
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
	@IdParcela INT,
	@ValorPago DECIMAL(14, 2),
	@DataPagamento DATETIME = NULL
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Validar a parcela e o valor pago e registrar o pagamento (RN05 e RN06).
									A situacao da parcela e alterada pela trigger.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									BEGIN TRAN
										DECLARE @DataInicial DATETIME = GETDATE(),
												@Retorno INT;

										EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 25, 618.00, '20260930'

										SELECT	@Retorno AS Retorno,
												DATEDIFF(ms, @DataInicial, GETDATE()) AS TempoExecucao
									ROLLBACK TRAN
		Retornos.................:	 0 - Sucesso
									-1 - Erro: parcela inexistente
									-2 - Erro: parcela ja paga ou cancelada
									-3 - Erro: valor pago menor que o valor atualizado
									-4 - Erro: falha ao inserir o pagamento
	*/
	BEGIN
		DECLARE @IdSituacaoParcela INT;

		IF @DataPagamento IS NULL
			SET @DataPagamento = GETDATE();

		-- Valida se a parcela existe
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Parcela] WITH(NOLOCK) WHERE Id = @IdParcela)
			RETURN -1;

		SELECT	@IdSituacaoParcela = IdSituacaoParcela
			FROM [dbo].[Parcela] WITH(NOLOCK)
			WHERE Id = @IdParcela;

		-- So aceita pagamento de parcela ABERTA ou VENCIDA
		IF @IdSituacaoParcela NOT IN (1, 2)
			RETURN -2;

		-- Valor pago nao pode ser menor que o valor com juros
		IF @ValorPago < [dbo].[FNC_ValorAtualizadoParcela](@IdParcela, CAST(@DataPagamento AS DATE))
			RETURN -3;

		INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
			VALUES (@IdParcela, @DataPagamento, @ValorPago);

		IF @@ERROR <> 0
			RETURN -4;

		RETURN 0;
	END
GO

/* =====================================================
   PROCEDURE 04
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_CancelarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
	@IdMatricula INT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Aplicar a RN08 e, quando permitido, alterar a situacao da matricula para CANCELADA
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									BEGIN TRAN
										DECLARE @DataInicial DATETIME = GETDATE(),
												@Retorno INT;

										EXEC @Retorno = [dbo].[SP_CancelarMatricula] 2

										SELECT	@Retorno AS Retorno,
												DATEDIFF(ms, @DataInicial, GETDATE()) AS TempoExecucao
									ROLLBACK TRAN
		Retornos.................:	 0 - Sucesso
									-1 - Erro: matricula inexistente
									-2 - Erro: matricula nao esta ATIVA
									-3 - Erro: parcelas pendentes sem negociacao QUITADA
									-4 - Erro: falha ao atualizar a matricula
	*/
	BEGIN
		-- Valida se a matricula existe
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE Id = @IdMatricula)
			RETURN -1;

		-- So cancela matricula ATIVA
		IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Matricula] WITH(NOLOCK) WHERE Id = @IdMatricula AND IdSituacaoMatricula = 1)
			RETURN -2;

		-- Bloqueia se tiver parcela pendente e nenhuma negociacao quitada
		IF EXISTS (SELECT TOP 1 1 FROM [dbo].[Parcela] WITH(NOLOCK)
						WHERE IdMatricula = @IdMatricula
							AND IdSituacaoParcela IN (1, 2))
			AND NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[Negociacao] WITH(NOLOCK)
								WHERE IdMatricula = @IdMatricula
									AND IdSituacaoNegociacao = 2)
			RETURN -3;

		UPDATE [dbo].[Matricula]
			SET IdSituacaoMatricula = 2
			WHERE Id = @IdMatricula;

		IF @@ERROR <> 0
			RETURN -4;

		RETURN 0;
	END
GO

/* =====================================================
   TRIGGER 01
   ===================================================== */

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaPagamento]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1)
	DROP TRIGGER [dbo].[TRG_AtualizarParcelaPagamento];
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaPagamento]
	ON [dbo].[Pagamento]
	AFTER INSERT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Apos INSERT na tabela de pagamentos, alterar para PAGA as parcelas
									dos pagamentos registrados, usando a tabela inserted
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
	*/
	BEGIN
		SET NOCOUNT ON;

		BEGIN TRY
			UPDATE pa
				SET pa.IdSituacaoParcela = 3
				FROM [dbo].[Parcela] AS pa
					INNER JOIN inserted AS ins
						ON ins.IdParcela = pa.Id;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
			THROW;
		END CATCH
	END
GO

/* =====================================================
   TESTES
   ===================================================== */

-- 1 - Reserva valida

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] 9, 3

	SELECT @Retorno AS Retorno -- 0 Sucesso

ROLLBACK TRANSACTION
GO

-- 2 - Reserva em turma sem vaga

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC [dbo].[SP_ReservarMatricula] 9, 3
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] 10, 3

	SELECT @Retorno AS Retorno -- -7 Turma sem vaga disponivel

ROLLBACK TRANSACTION
GO

-- 3 - Reserva duplicada

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] 1, 1

	SELECT @Retorno AS Retorno -- -5 Aluno ja possui reserva nesta turma

ROLLBACK TRANSACTION
GO

-- 4 - Reserva com aluno inativo

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] 13, 1

	SELECT @Retorno AS Retorno -- -2 Aluno inativo

ROLLBACK TRANSACTION
GO

-- 5 - Reserva com turma inativa

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] 10, 4

	SELECT @Retorno AS Retorno -- -4 Turma inativa

ROLLBACK TRANSACTION
GO

-- 6 - Efetivacao valida e conferencia das 12 parcelas

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 4

	SELECT @Retorno AS Retorno -- 0 Sucesso

	SELECT pa.*
		FROM [dbo].[Parcela] AS pa
			INNER JOIN [dbo].[Matricula] AS ma
				ON ma.Id = pa.IdMatricula
		WHERE ma.IdReservaMatricula = 4
		ORDER BY pa.Numero -- 12 parcelas vencendo todo dia 10

ROLLBACK TRANSACTION
GO

-- 7 - Efetivar reserva ja efetivada

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 6

	SELECT @Retorno AS Retorno -- -2 Reserva nao esta RESERVADA

ROLLBACK TRANSACTION
GO

-- 8 - Efetivar reserva com data de expiracao vencida

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 10

	SELECT @Retorno AS Retorno -- -3 Reserva expirada

ROLLBACK TRANSACTION
GO

-- 9 - Pagamento dentro do vencimento

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 28, 600.00, '20261005'

	SELECT @Retorno AS Retorno -- 0 Sucesso

	SELECT * FROM [dbo].[Pagamento] WHERE IdParcela = 28

ROLLBACK TRANSACTION
GO

-- 10 - Pagamento em atraso com juros

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 25, 618.00, '20260930'

	SELECT @Retorno AS Retorno -- 0 Sucesso (600.00 + 3 meses de juros = 618.00)

	SELECT * FROM [dbo].[Pagamento] WHERE IdParcela = 25

ROLLBACK TRANSACTION
GO

-- 11 - Pagamento de parcela ja paga

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 1, 500.00

	SELECT @Retorno AS Retorno -- -2 Parcela ja paga ou cancelada

ROLLBACK TRANSACTION
GO

-- 12 - Teste trigger

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	SELECT * FROM [dbo].[Parcela] WHERE Id = 28 -- ABERTA

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 28, 600.00, '20261005'

	SELECT * FROM [dbo].[Parcela] WHERE Id = 28 -- PAGA

ROLLBACK TRANSACTION
GO

-- 13 - Teste trigger varias linhas

BEGIN TRANSACTION

	SELECT * FROM [dbo].[Parcela] WHERE Id IN (26, 27) -- VENCIDA

	INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
		VALUES	(26, '20260930', 612.00),
				(27, '20260930', 606.00)

	SELECT * FROM [dbo].[Parcela] WHERE Id IN (26, 27) -- PAGA nas duas

ROLLBACK TRANSACTION
GO

-- 14 - Tentativa de cancelamento com parcela pendente

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_CancelarMatricula] 3

	SELECT @Retorno AS Retorno -- -3 Parcelas pendentes sem negociacao QUITADA

ROLLBACK TRANSACTION
GO

-- 15 - Cancelamento com negociacao quitada

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_CancelarMatricula] 2

	SELECT @Retorno AS Retorno -- 0 Sucesso

ROLLBACK TRANSACTION
GO

-- 16 - Cancelamento valido sem parcelas pendentes

BEGIN TRANSACTION

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_CancelarMatricula] 4

	SELECT @Retorno AS Retorno -- 0 Sucesso

ROLLBACK TRANSACTION
GO

-- 17 - Consulta view 1

SELECT * FROM [dbo].[VW_MatriculasAtivas]
GO

-- 18 - Consulta view 2

SELECT * FROM [dbo].[VW_SituacaoFinanceira]
GO

-- 19 - Chamada function 1

SELECT [dbo].[FNC_VagasDisponiveis](1) AS VagasTurma1 -- Quantidade de vagas
GO

-- 20 - Chamada function 2

SELECT [dbo].[FNC_ValorAtualizadoParcela](25, '20260811') AS ValorParcela25 -- Valor com juros
GO
