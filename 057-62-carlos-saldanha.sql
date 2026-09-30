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
			tu.Id as IdTurma,
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
		Objetivo.................:	apresentar uma linha por matrícula, com o aluno, o total de parcelas,
									as quantidades de parcelas pagas,
									pendentes e vencidas (RN07) e o valor total ainda pendente.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	SELECT * FROM [dbo].[VW_SituacaoFinanceira] WHERE IdMatricula = 3
	*/

	SELECT	ma.Id as IdMatricula,
			al.Nome as NomeAluno,
			al.Cpf as CpfAluno,
			sm.Descricao as SituacaoMatricula,
			COUNT(pa.Id) as TotalParcelas,
			SUM(CASE WHEN pa.IdSituacaoParcela = 3 THEN 1 ELSE 0 END) as ParcelasPagas,
			SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2) THEN 1 ELSE 0 END) as ParcelasPendentes,
			SUM(CASE
					WHEN pa.IdSituacaoParcela = 2 THEN 1
					WHEN pa.IdSituacaoParcela = 1 AND pa.DataVencimento < CAST(GETDATE() AS DATE) THEN 1
					ELSE 0
				END) as ParcelasVencidas,
			ISNULL(SUM(CASE WHEN pa.IdSituacaoParcela IN (1, 2) THEN pa.ValorOriginal ELSE 0 END), 0) as ValorPendente
		FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
				ON al.Id = ma.IdAluno
			INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
				ON sm.Id = ma.IdSituacaoMatricula
			LEFT JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
				ON pa.IdMatricula = ma.Id
		GROUP BY ma.Id,
				 al.Nome,
				 al.Cpf,
				 sm.Descricao
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
		Objetivo.................:	Receber uma turma e retornar quantas vagas ela ainda possui,
									conforme a RN02.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	SELECT [dbo].[FNC_VagasDisponiveis](3) as VagasDisponiveis
		Retornos.................:	>= 0 - Quantidade de vagas disponiveis na turma
									0    - Turma sem vaga ou turma inexistente
	*/
	BEGIN
		DECLARE @Capacidade INT,
				@Matriculas INT,
				@Reservas INT,
				@Vagas INT;

		SELECT	@Capacidade = tu.Capacidade
			FROM [dbo].[Turma] AS tu WITH(NOLOCK)
			WHERE tu.Id = @IdTurma;

		SELECT	@Matriculas = COUNT(*)
			FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			WHERE ma.IdTurma = @IdTurma
				AND ma.IdSituacaoMatricula = 1;

		SELECT	@Reservas = COUNT(*)
			FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
			WHERE rm.IdTurma = @IdTurma
				AND rm.IdSituacaoReserva = 1
				AND rm.DataExpiracao >= CAST(GETDATE() AS DATE);

		SET @Vagas = @Capacidade - @Matriculas - @Reservas;

		IF @Vagas IS NULL OR @Vagas < 0
			RETURN 0;

		RETURN @Vagas;
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
		Objetivo.................:	Receber uma parcela e uma data de referência e retornar quanto a parcela vale nessa data,
									com os juros de atraso quando houver (RN06 e RN07).
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	SELECT [dbo].[FNC_ValorAtualizadoParcela](25, '20260811') as ValorAtualizado
		Retornos.................:	Valor original  - pagamento ate o dia do vencimento
									Valor com juros - pagamento apos o vencimento
									NULL            - parcela inexistente ou data de referencia nao informada
	*/
	BEGIN
		DECLARE @ValorOriginal DECIMAL(14, 2),
				@DataVencimento DATE,
				@MesesAtraso INT,
				@ValorAtualizado DECIMAL(14, 2);

		SELECT	@ValorOriginal = pa.ValorOriginal,
				@DataVencimento = pa.DataVencimento
			FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
			WHERE pa.Id = @IdParcela;

		IF @ValorOriginal IS NULL OR @DataReferencia IS NULL
			RETURN NULL;

		IF @DataReferencia <= @DataVencimento
			RETURN @ValorOriginal;

		SET @MesesAtraso = DATEDIFF(MONTH, @DataVencimento, @DataReferencia);

		IF DATEADD(MONTH, @MesesAtraso, @DataVencimento) < @DataReferencia
			SET @MesesAtraso = @MesesAtraso + 1;

		SET @ValorAtualizado = ROUND(@ValorOriginal + (@ValorOriginal * 0.01 * @MesesAtraso), 2);

		RETURN @ValorAtualizado;
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
	@IdTurma INT,
	@IdReservaGerada INT = NULL OUTPUT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Validar a RN01 e a RN02, registrar a reserva e retornar um código
									que indique o sucesso ou o motivo do erro.
									Atencao: o exemplo abaixo GRAVA uma reserva de verdade; para so
									testar, execute-o entre BEGIN TRANSACTION e ROLLBACK.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DECLARE @Retorno INT,
											@IdReserva INT

									EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 10,
																				 @IdTurma = 2,
																				 @IdReservaGerada = @IdReserva OUTPUT

									SELECT @Retorno as Retorno, @IdReserva as IdReservaGerada
		Retornos.................:	 0 - Sucesso (Id da reserva devolvido em @IdReservaGerada)
									-1 - Erro: aluno nao encontrado
									-2 - Erro: aluno inativo
									-3 - Erro: turma nao encontrada
									-4 - Erro: turma inativa
									-5 - Erro: aluno ja possui reserva RESERVADA e nao expirada nesta turma
									-6 - Erro: aluno ja possui matricula ATIVA nesta turma
									-7 - Erro: turma sem vaga disponivel
									-8 - Erro: falha na gravacao da reserva
	*/
	BEGIN
		SET NOCOUNT ON;

		DECLARE @DataReserva DATETIME2(3),
				@DataExpiracao DATE;

		SET @DataReserva = GETDATE();
		SET @DataExpiracao = DATEADD(DAY, 7, CAST(@DataReserva AS DATE));
		SET @IdReservaGerada = NULL;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Aluno] AS al WITH(NOLOCK)
								WHERE al.Id = @IdAluno
						)
			RETURN -1;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Aluno] AS al WITH(NOLOCK)
								WHERE al.Id = @IdAluno
									AND al.Ativo = 1
						)
			RETURN -2;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Turma] AS tu WITH(NOLOCK)
								WHERE tu.Id = @IdTurma
						)
			RETURN -3;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Turma] AS tu WITH(NOLOCK)
								WHERE tu.Id = @IdTurma
									AND tu.Ativo = 1
						)
			RETURN -4;

		IF EXISTS	(
						SELECT TOP 1 1
							FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
							WHERE rm.IdAluno = @IdAluno
								AND rm.IdTurma = @IdTurma
								AND rm.IdSituacaoReserva = 1
								AND rm.DataExpiracao >= CAST(@DataReserva AS DATE)
					)
			RETURN -5;

		IF EXISTS	(
						SELECT TOP 1 1
							FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
							WHERE ma.IdAluno = @IdAluno
								AND ma.IdTurma = @IdTurma
								AND ma.IdSituacaoMatricula = 1
					)
			RETURN -6;

		IF [dbo].[FNC_VagasDisponiveis](@IdTurma) <= 0
			RETURN -7;

		BEGIN TRY
			INSERT INTO [dbo].[ReservaMatricula] (IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
				VALUES (@IdAluno, @IdTurma, 1, @DataReserva, @DataExpiracao);

			SET @IdReservaGerada = SCOPE_IDENTITY();
		END TRY
		BEGIN CATCH
			RETURN -8;
		END CATCH

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
	@IdReservaMatricula INT,
	@IdMatriculaGerada INT = NULL OUTPUT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	validar a reserva, criar a matrícula, alterar a situação da reserva e gerar as 12 parcelas
									(RN03 e RN04), com controle transacional.
									Atencao: o exemplo abaixo GRAVA de verdade; para so testar,
									execute-o entre BEGIN TRANSACTION e ROLLBACK.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DECLARE @Retorno INT,
											@IdMatricula INT

									EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 4,
																				 @IdMatriculaGerada = @IdMatricula OUTPUT

									SELECT @Retorno as Retorno, @IdMatricula as IdMatriculaGerada
		Retornos.................:	 0 - Sucesso (Id da matricula devolvido em @IdMatriculaGerada)
									-1 - Erro: reserva nao encontrada
									-2 - Erro: reserva nao esta RESERVADA (efetivada, cancelada ou expirada)
									-3 - Erro: reserva com data de expiracao vencida
									-4 - Erro: reserva ja possui matricula
									-5 - Erro: falha na gravacao (nada foi gravado - ROLLBACK)
	*/
	BEGIN
		SET NOCOUNT ON;

		DECLARE @IdAluno INT,
				@IdTurma INT,
				@IdCurso INT,
				@ValorMensalidade DECIMAL(14, 2),
				@DataMatricula DATETIME2(3),
				@PrimeiroVencimento DATE;

		SET @DataMatricula = GETDATE();
		SET @PrimeiroVencimento = DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@DataMatricula), MONTH(@DataMatricula), 10));
		SET @IdMatriculaGerada = NULL;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
								WHERE rm.Id = @IdReservaMatricula
						)
			RETURN -1;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
								WHERE rm.Id = @IdReservaMatricula
									AND rm.IdSituacaoReserva = 1
						)
			RETURN -2;

		IF EXISTS	(
						SELECT TOP 1 1
							FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
							WHERE rm.Id = @IdReservaMatricula
								AND rm.DataExpiracao < CAST(@DataMatricula AS DATE)
					)
			RETURN -3;

		IF EXISTS	(
						SELECT TOP 1 1
							FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
							WHERE ma.IdReservaMatricula = @IdReservaMatricula
					)
			RETURN -4;

		SELECT	@IdAluno = rm.IdAluno,
				@IdTurma = rm.IdTurma
			FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
			WHERE rm.Id = @IdReservaMatricula;

		SELECT	@IdCurso = tu.IdCurso
			FROM [dbo].[Turma] AS tu WITH(NOLOCK)
			WHERE tu.Id = @IdTurma;

		SELECT	@ValorMensalidade = cu.ValorMensalidade
			FROM [dbo].[Curso] AS cu WITH(NOLOCK)
			WHERE cu.Id = @IdCurso;

		BEGIN TRY
			BEGIN TRANSACTION;

				INSERT INTO [dbo].[Matricula] (IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
					VALUES (@IdReservaMatricula, @IdAluno, @IdTurma, 1, @DataMatricula, @ValorMensalidade);

				SET @IdMatriculaGerada = SCOPE_IDENTITY();

				UPDATE [dbo].[ReservaMatricula]
					SET IdSituacaoReserva = 2
					WHERE Id = @IdReservaMatricula
						AND IdSituacaoReserva = 1;

				IF @@ROWCOUNT <> 1
					THROW 50001, 'Falha ao alterar a situacao da reserva para EFETIVADA.', 1;

				INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
					SELECT	@IdMatriculaGerada,
							1,
							nu.Numero,
							@ValorMensalidade,
							DATEADD(MONTH, nu.Numero - 1, @PrimeiroVencimento)
						FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12)) AS nu (Numero);

				IF @@ROWCOUNT <> 12
					THROW 50002, 'Falha ao gerar as 12 parcelas da matricula.', 1;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			SET @IdMatriculaGerada = NULL;

			RETURN -5;
		END CATCH

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
	@DataPagamento DATETIME2(3) = NULL,
	@ValorAtualizado DECIMAL(14, 2) = NULL OUTPUT
	AS
	/*
		Documentacao
		Arquivo Fonte............:	057-62-carlos-saldanha.sql
		Objetivo.................:	Validar a parcela e o valor pago, calcular o valor
									atualizado e registrar o pagamento (RN05 e RN06).
									A situação da parcela não é alterada aqui: isso é responsabilidade do Trigger.
									Atencao: o exemplo abaixo GRAVA de verdade; para so testar,
									execute-o entre BEGIN TRANSACTION e ROLLBACK.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DECLARE @Retorno INT,
											@Valor DECIMAL(14, 2)

									EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 25,
																				  @ValorPago = 618.00,
																				  @ValorAtualizado = @Valor OUTPUT

									SELECT @Retorno as Retorno, @Valor as ValorAtualizado
		Retornos.................:	 0 - Sucesso (valor calculado devolvido em @ValorAtualizado)
									-1 - Erro: parcela nao encontrada
									-2 - Erro: parcela ja PAGA
									-3 - Erro: parcela nao esta ABERTA nem VENCIDA (cancelada)
									-4 - Erro: valor pago nao informado ou inferior ao valor atualizado
									-5 - Erro: falha na gravacao do pagamento
	*/
	BEGIN
		SET NOCOUNT ON;

		IF @DataPagamento IS NULL
			SET @DataPagamento = GETDATE();

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
								WHERE pa.Id = @IdParcela
						)
			RETURN -1;

		IF EXISTS	(
						SELECT TOP 1 1
							FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
							WHERE pa.Id = @IdParcela
								AND pa.IdSituacaoParcela = 3
					)
			RETURN -2;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
								WHERE pa.Id = @IdParcela
									AND pa.IdSituacaoParcela IN (1, 2)
						)
			RETURN -3;

		SET @ValorAtualizado = [dbo].[FNC_ValorAtualizadoParcela](@IdParcela, CAST(@DataPagamento AS DATE));

		IF @ValorPago IS NULL OR @ValorPago < @ValorAtualizado
			RETURN -4;

		BEGIN TRY
			INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
				VALUES (@IdParcela, @DataPagamento, @ValorPago);
		END TRY
		BEGIN CATCH
			IF XACT_STATE() = -1
				ROLLBACK TRANSACTION;

			RETURN -5;
		END CATCH

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
		Objetivo.................:	Aplicar a RN08 e, quando permitido, alterar a situação da matrícula para CANCELADA.
									Atencao: o exemplo abaixo GRAVA de verdade; para so testar,
									execute-o entre BEGIN TRANSACTION e ROLLBACK.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	DECLARE @Retorno INT

									EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2

									SELECT @Retorno as Retorno
		Retornos.................:	 0 - Sucesso
									-1 - Erro: matricula nao encontrada
									-2 - Erro: matricula nao esta ATIVA
									-3 - Erro: parcelas pendentes sem negociacao QUITADA
									-4 - Erro: falha na alteracao da matricula
	*/
	BEGIN
		SET NOCOUNT ON;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
								WHERE ma.Id = @IdMatricula
						)
			RETURN -1;

		IF NOT EXISTS	(
							SELECT TOP 1 1
								FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
								WHERE ma.Id = @IdMatricula
									AND ma.IdSituacaoMatricula = 1
						)
			RETURN -2;

		IF EXISTS	(
						SELECT TOP 1 1
							FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
							WHERE pa.IdMatricula = @IdMatricula
								AND pa.IdSituacaoParcela IN (1, 2)
					)
			AND NOT EXISTS	(
								SELECT TOP 1 1
									FROM [dbo].[Negociacao] AS ne WITH(NOLOCK)
									WHERE ne.IdMatricula = @IdMatricula
										AND ne.IdSituacaoNegociacao = 2
							)
			RETURN -3;

		BEGIN TRY
			UPDATE [dbo].[Matricula]
				SET IdSituacaoMatricula = 2
				WHERE Id = @IdMatricula
					AND IdSituacaoMatricula = 1;

			IF @@ROWCOUNT <> 1
				RETURN -4;
		END TRY
		BEGIN CATCH
			RETURN -4;
		END CATCH

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
		Objetivo.................:	após INSERT na tabela de pagamentos, alterar para PAGA as parcelas correspondentes
									aos pagamentos registrados.
									Deve utilizar a tabela lógica inserted.
									Deve funcionar quando um único INSERT registrar pagamentos de mais de
									uma parcela: nunca assuma que inserted contém apenas uma linha.
									Se a atualização da parcela falhar, o pagamento que a originou
									também não pode permanecer gravado.
		Autor....................:	Carlos Guilherme Saldanha Da Silva
		Data.....................:	30/09/2026
		Ex.......................:	BEGIN TRANSACTION

									INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
										VALUES (26, GETDATE(), 612.00),
											   (27, GETDATE(), 606.00)

									SELECT Id, IdSituacaoParcela FROM [dbo].[Parcela] WHERE Id IN (26, 27)

									ROLLBACK TRANSACTION
		Erros....................:	Se o UPDATE das parcelas falhar, ou se a quantidade de parcelas
									atualizadas for diferente da quantidade de parcelas distintas em
									inserted, o trigger lanca o erro 50010 (THROW). Um erro dentro do
									trigger desfaz a transacao inteira: o pagamento que o originou
									tambem nao fica gravado.
	*/
	BEGIN
		SET NOCOUNT ON;

		DECLARE @ParcelasAtualizadas INT,
				@ParcelasPagas INT;

		UPDATE pa
			SET pa.IdSituacaoParcela = 3
			FROM [dbo].[Parcela] AS pa
			WHERE pa.Id IN	(
								SELECT ins.IdParcela
									FROM inserted AS ins
							);

		SET @ParcelasAtualizadas = @@ROWCOUNT;

		SELECT	@ParcelasPagas = COUNT(DISTINCT ins.IdParcela)
			FROM inserted AS ins;

		IF @ParcelasAtualizadas <> @ParcelasPagas
			THROW 50010, 'Falha ao atualizar a parcela para PAGA: o pagamento foi desfeito.', 1;
	END
GO

/* =====================================================
   TESTES
   ===================================================== */

-- 1 - Reserva valida

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 9, @IdTurma = 3;

	SELECT @Retorno as Retorno -- 0 Sucesso

ROLLBACK TRANSACTION;
GO

-- 2 - Reserva em turma sem vaga

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC [dbo].[SP_ReservarMatricula] @IdAluno = 9, @IdTurma = 3;
	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 10, @IdTurma = 3;

	SELECT @Retorno as Retorno -- -7 Turma sem vaga disponivel

ROLLBACK TRANSACTION;
GO

-- 3 - Reserva duplicada

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 1, @IdTurma = 1;

	SELECT @Retorno as Retorno -- -5 Aluno ja possui reserva RESERVADA nesta turma

ROLLBACK TRANSACTION;
GO

-- 4 - Reserva com aluno inativo

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 13, @IdTurma = 1;

	SELECT @Retorno as Retorno -- -2 Aluno inativo

ROLLBACK TRANSACTION;
GO

-- 5 - Reserva com turma inativa

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 10, @IdTurma = 4;

	SELECT @Retorno as Retorno -- -4 Turma inativa

ROLLBACK TRANSACTION;
GO

-- 6 - Efetivacao valida e conferencia das 12 parcelas

BEGIN TRANSACTION;

	DECLARE @Retorno INT,
			@IdMatricula INT;

	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 4, @IdMatriculaGerada = @IdMatricula OUTPUT;

	SELECT @Retorno as Retorno -- 0 Sucesso

	SELECT	pa.Numero as Numero,
			pa.ValorOriginal as ValorOriginal,
			pa.DataVencimento as DataVencimento,
			pa.IdSituacaoParcela as IdSituacaoParcela
		FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
		WHERE pa.IdMatricula = @IdMatricula
		ORDER BY pa.Numero -- 12 parcelas de 550.00, vencendo todo dia 10, situacao 1 (ABERTA)

ROLLBACK TRANSACTION;
GO

-- 7 - Efetivar reserva ja efetivada

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 6;

	SELECT @Retorno as Retorno -- -2 Reserva nao esta RESERVADA

ROLLBACK TRANSACTION;
GO

-- 8 - Efetivar reserva com data de expiracao vencida

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 10;

	SELECT @Retorno as Retorno -- -3 Reserva com data de expiracao vencida

ROLLBACK TRANSACTION;
GO

-- 9 - Pagamento dentro do vencimento

BEGIN TRANSACTION;

	DECLARE @Retorno INT,
			@Valor DECIMAL(14, 2);

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 28, @ValorPago = 600.00, @DataPagamento = '20261005', @ValorAtualizado = @Valor OUTPUT;

	SELECT @Retorno as Retorno, @Valor as ValorAtualizado -- 0 Sucesso e 600.00 sem juros

ROLLBACK TRANSACTION;
GO

-- 10 - Pagamento em atraso com juros

BEGIN TRANSACTION;

	DECLARE @Retorno INT,
			@Valor DECIMAL(14, 2);

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 25, @ValorPago = 618.00, @DataPagamento = '20260930', @ValorAtualizado = @Valor OUTPUT;

	SELECT @Retorno as Retorno, @Valor as ValorAtualizado -- 0 Sucesso e 618.00 com 3 meses de juros

ROLLBACK TRANSACTION;
GO

-- 11 - Pagamento de parcela ja paga

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 1, @ValorPago = 500.00;

	SELECT @Retorno as Retorno -- -2 Parcela ja PAGA

ROLLBACK TRANSACTION;
GO

-- 12 - Teste trigger

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	SELECT pa.Id as IdParcela, pa.IdSituacaoParcela as IdSituacaoParcela FROM [dbo].[Parcela] AS pa WITH(NOLOCK) WHERE pa.Id = 28 -- 1 ABERTA

	EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 28, @ValorPago = 600.00, @DataPagamento = '20261005';

	SELECT pa.Id as IdParcela, pa.IdSituacaoParcela as IdSituacaoParcela FROM [dbo].[Parcela] AS pa WITH(NOLOCK) WHERE pa.Id = 28 -- 3 PAGA

ROLLBACK TRANSACTION;
GO

-- 13 - Teste trigger varias linhas

BEGIN TRANSACTION;

	SELECT pa.Id as IdParcela, pa.IdSituacaoParcela as IdSituacaoParcela FROM [dbo].[Parcela] AS pa WITH(NOLOCK) WHERE pa.Id IN (26, 27) -- 2 VENCIDA

	INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
		VALUES	(26, '20260930', 612.00),
				(27, '20260930', 606.00);

	SELECT pa.Id as IdParcela, pa.IdSituacaoParcela as IdSituacaoParcela FROM [dbo].[Parcela] AS pa WITH(NOLOCK) WHERE pa.Id IN (26, 27) -- 3 PAGA nas duas

ROLLBACK TRANSACTION;
GO

-- 14 - Tentativa de cancelamento com parcela pendente e sem negociacao quitada

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 3;

	SELECT @Retorno as Retorno -- -3 Parcelas pendentes sem negociacao QUITADA

ROLLBACK TRANSACTION;
GO

-- 15 - Cancelamento com negociacao quitada

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2;

	SELECT @Retorno as Retorno -- 0 Sucesso

ROLLBACK TRANSACTION;
GO

-- 16 - Cancelamento valido sem parcelas pendentes

BEGIN TRANSACTION;

	DECLARE @Retorno INT;

	EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4;

	SELECT @Retorno as Retorno -- 0 Sucesso

ROLLBACK TRANSACTION;
GO

-- 17 - Consulta view 1

SELECT * FROM [dbo].[VW_MatriculasAtivas];
GO

-- 18 - Consulta view 2

SELECT * FROM [dbo].[VW_SituacaoFinanceira];
GO

-- 19 - Chamada function 1

SELECT [dbo].[FNC_VagasDisponiveis](1) as VagasTurma1 -- 2 vagas
GO

-- 20 - Chamada function 2

SELECT [dbo].[FNC_ValorAtualizadoParcela](25, '20260811') as ValorParcela25 -- 612.00
GO
