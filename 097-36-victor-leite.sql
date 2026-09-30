--avaliacao_sql_victor-leite/ 
--├── Views/        
--→ VIEW 01
USE Escola;
GO

IF EXISTS(SELECT * FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND TYPE = 'V')
	DROP VIEW [dbo].[VW_MatriculasAtivas];
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
AS
/*
Documentacao
Arquivo Fonte............: VW_MatriculasAtivas.sql
Objetivo.................: Lista matriculas ativas
Autor....................: Victor Leite
Data.....................: 30/09/2026
Ex.......................: 
								DBCC FREEPROCCACHE
								DBCC DROPCLEANBUFFERS

								DECLARE @DataAgora DATETIME = GETDATE()

								SELECT * from [dbo].[VW_MatriculasAtivas]

								SELECT  DATEDIFF(MS, @DataAgora, GETDATE())
*/
	SELECT  al.Nome as NomeAluno,
			cu.Nome as Curso,
			tu.Codigo as CodigoTurma,
			ma.DataMatricula as DataMatricula,
			sm.Descricao as SituacaoMatricula
		FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
			INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
				ON ma.IdAluno = al.Id
			INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
				ON ma.IdTurma = tu.Id
			INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
				ON tu.IdCurso = cu.Id
			INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
				ON ma.IdSituacaoMatricula = sm.Id
		WHERE ma.IdSituacaoMatricula = 1
GO
--→VIEW 02 
USE Escola;
GO

IF EXISTS(SELECT * FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND TYPE = 'V')
	DROP VIEW [dbo].[VW_SituacaoFinanceira];
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
AS
/*
Documentacao
Arquivo Fonte............: VW_SituacaoFinanceira.sql
Objetivo.................: Apresenta uma linha por matrícula, com o aluno, o total de parcelas,
						   as quantidades de parcelas pagas, pendentes e vencidas e o valor total ainda pendente. 
Autor....................: Victor Leite
Data.....................: 30/09/2026
Ex.......................: 
							DBCC FREEPROCCACHE
							DBCC DROPCLEANBUFFERS

							DECLARE @DataAgora DATETIME = GETDATE()

							SELECT * from [dbo].[VW_SituacaoFinanceira]

							SELECT  DATEDIFF(MS, @DataAgora, GETDATE()) as TempoMs

*/
		SELECT	ma.Id as IdMatricula,
				al.Nome as NomeAluno,
				COUNT(pa.Id) as ParcelasTotais,
				SUM(CASE WHEN pa.IdSituacaoParcela = 3 THEN 1 ELSE 0 END) as ParcelasPagas,
				SUM(CASE WHEN pa.IdSituacaoParcela = 1 OR pa.IdSituacaoParcela = 2 THEN 1 ELSE 0 END) as ParcelasPendentes,
				SUM(CASE WHEN pa.IdSituacaoParcela = 2 THEN 1 ELSE 0 END) as ParcelasVencidas,
				SUM(CASE WHEN pa.IdSituacaoParcela = 1 OR pa.IdSituacaoParcela = 2 THEN pa.ValorOriginal ELSE 0 END) as ValorTotalPendente
			FROM [dbo].[Aluno] AS al WITH(NOLOCK)
				INNER JOIN [dbo].[Matricula] AS ma WITH(NOLOCK)
					ON al.Id = ma.IdAluno
				INNER JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
					ON pa.IdMatricula = ma.Id
				INNER JOIN [dbo].[SituacaoParcela] AS st WITH(NOLOCK)
					ON st.Id = pa.IdSituacaoParcela
			GROUP BY ma.Id, al.Nome
GO
--├── Functions/    
--→ FUNCTION 01
USE Escola;
GO

IF EXISTS (SELECT * FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FN_VerificaDisponibilidadeDeVagas]') AND TYPE = 'FN')
	DROP FUNCTION [dbo].[FN_VerificaDisponibilidadeDeVagas];
GO

CREATE FUNCTION [dbo].[FN_VerificaDisponibilidadeDeVagas](@IdTurma INT)
RETURNS INT
AS
/*
Documentacao
Arquivo Fonte............: FNC_VerificaDisponibilidadeDeVagas.sql
Objetivo.................: Verifica quantas vagas a turma ainda possui.
Autor....................: Victor Leite
Data.....................: 30/09/2026
Ex.......................:  
							DBCC FREEPROCCACHE
							DBCC DROPCLEANBUFFERS

							DECLARE @DataAgora DATETIME = GETDATE()

							SELECT  [dbo].[FN_VerificaDisponibilidadeDeVagas] (1) as QuantidadeDeVagas,
									DATEDIFF(MS, @DataAgora, GETDATE()) as TempoMs

							
Retornos.................: Maior ou igual a 0 - Sucesso(QUANTIDADE DE VAGAS)
						    -1 - Turma inexistente
*/
BEGIN
	--Verifica se a turma existe
	IF NOT EXISTS (
					SELECT 1 
						FROM [dbo].[Turma] WITH(NOLOCK)
						WHERE Id = @IdTurma
				  )
		RETURN -1

	--Verifica a quantidade de ReservaMatriculas disponiveis.
	DECLARE @QuantidadeReservaMatriculas INT = (
													SELECT  COUNT(*)
														FROM [dbo].[ReservaMatricula] as rm WITH(NOLOCK)
														WHERE rm.IdTurma = @IdTurma 
															AND rm.IdSituacaoReserva = 1
															AND rm.DataExpiracao > GETDATE()
											   )

	--Verifica as matriculas ativas dessa turma
	DECLARE @QuantidadeMatriculasAtivas INT = (
												SELECT  COUNT(*)
													FROM [dbo].[Matricula] as ma WITH(NOLOCK)
													WHERE ma.IdTurma = @IdTurma
														AND ma.IdSituacaoMatricula = 1
											  )
	
	RETURN (
			SELECT  Capacidade - @QuantidadeReservaMatriculas - @QuantidadeMatriculasAtivas 
				FROM [dbo].[Turma] WITH(NOLOCK)
				WHERE Id = @IdTurma
		   )
END
GO
--→ FUNCTION 02 
USE Escola;
GO

IF EXISTS(SELECT * FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[FNC_VerificaValorAtualizadoParcela]') AND TYPE = 'FN')
	DROP FUNCTION [dbo].[FNC_VerificaValorAtualizadoParcela];
GO

CREATE FUNCTION [dbo].[FNC_VerificaValorAtualizadoParcela](@IdParcela INT, @DataReferencia DATE)
	RETURNS DECIMAL(14,2)
	AS
	/*
	Documentacao
	Arquivo Fonte............: FNC_VerificaValorAtualizadoParcela.sql
	Objetivo.................: Calcula o valor da parcela para pagamento na data informada.
	Autor....................: Victor Leite
	Data.....................: 30/09/2026
	Ex.......................: 
								DBCC FREEPROCCACHE
								DBCC DROPCLEANBUFFERS

								SELECT [dbo].[FNC_VerificaValorAtualizadoParcela] (4, '2026-09-30')
								
	Retornos.................: Valor da parcela - Sucesso
											 -1 - Parcela inexistente.
	*/
	BEGIN
		-- Verifica se a parcela existe.
		IF NOT EXISTS (
						SELECT 1
							FROM [dbo].[Parcela] WITH(NOLOCK)
							WHERE Id = @IdParcela
					  )
			RETURN -1

        DECLARE @ValorParcela DECIMAL(14,2),
                @DataVencimento DATE,
                @MesesAtraso INT = 0,
                @ValorComJuros DECIMAL(14,2)
        
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

        -- Sem nao tem atraso, retorna o valor normal da parcela
        IF @MesesAtraso = 0
            RETURN @ValorParcela

        -- Se tem atraso, retorna o valor com juros
		SET @ValorComJuros = @ValorParcela + (@ValorParcela * @MesesAtraso / 100)
    
        RETURN @ValorComJuros
	END
GO

--├── Procedures/ 
--PROCEDURE 01
USE Escola;
GO
IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_ReservarMatricula]
GO
CREATE PROCEDURE [dbo].[SP_ReservarMatricula] @IdAluno INT, @IdTurma INT
	AS
	/*
	Documentacao
	Arquivo Fonte............: SP_ReservarMatricula.sql
	Objetivo.................: Reservar matricula se todos os parametros atenderem aos requisitos.
	Autor....................: Victor Leite
	Data.....................: 30/09/2026
	Ex.......................: BEGIN TRANSACTION
								  DBCC FREEPROCCACHE
								  DBCC DROPCLEANBUFFERS
								  
								  DECLARE @Retorno INT,
										  @DataAgora DATETIME = GETDATE()

								  EXEC @Retorno = [dbo].[SP_ReservarMatricula] 1, 2

								  SELECT @Retorno as Retorno,
								         DATEDIFF(MS, @DataAgora, GETDATE()) as TempoMs
       						   ROLLBACK TRANSACTION

	Retornos.................: @IdReservaMatricula - Reserva Matricula feita com sucesso
						      -1 - Aluno nao existe no cadastro do sistema.
							  -2 - Turma nao existe ou nao esta ativa.
							  -3 - Turma nao possui vagas no momento.
							  -4 - Aluno ja possui reserva nessa turma.
							  -5 - Aluno ja cadastrado na turma.
							  -6 - Erro ao inserir dados da ReservaMatricula
	*/
	BEGIN
		-- Verifica se IdAluno existe
		IF NOT EXISTS (
					   SELECT 1 
						   FROM [dbo].[Aluno] WITH(NOLOCK)
						   WHERE Id = @IdAluno
					  )
		    RETURN -1

		-- Verifica se turma existe e esta ativa.
		IF NOT EXISTS (
					   SELECT 1
						   FROM [dbo].[Turma] WITH(NOLOCK)
						   WHERE Id = @IdTurma
							   AND Ativo = 1
					  )
		    RETURN -2

		-- Verifica se turma tem pelo menos uma Vaga.
		IF (SELECT  [dbo].[FN_VerificaDisponibilidadeDeVagas](@IdTurma)) < 1
			RETURN -3

		-- Armazero a data de hoje.
		DECLARE @DataHoje DATE = GETDATE()

		--O aluno não pode ter, para a mesma turma, outra reserva na situação RESERVADA  
		IF EXISTS (
				   SELECT 1
					  FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
					  WHERE IdAluno = @IdAluno
						  AND IdTurma = @IdTurma
						  AND IdSituacaoReserva = 1
						  AND DataExpiracao > @DataHoje
				  )
		    RETURN -4

		--O Aluno nao pode ter para a mesma turma, uma matrícula na situação ATIVA.
		IF EXISTS (
				   SELECT 1
					   FROM [dbo].[Matricula] WITH(NOLOCK)
					   WHERE IdTurma = @IdTurma
						   AND IdAluno = @IdAluno 
						   AND IdSituacaoMatricula = 1
				  )
		    RETURN -5

		-- Aqui insere os dados da ReservaMatricula
		INSERT INTO [dbo].[ReservaMatricula](IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
			VALUES(@IdAluno, @IdTurma, 1, @DataHoje, DATEADD(DAY, 7, @DataHoje))
		
		IF @@ERROR <> 0
			RETURN -6

		RETURN SCOPE_IDENTITY()
	END
GO
 
--PROCEDURE 02 
USE Escola;
GO
IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
GO
CREATE PROCEDURE [dbo].[SP_EfetivarMatricula] @IdReservaMatricula INT
	AS
	/*
	Documentacao
	Arquivo Fonte............: SP_EfetivarMatricula.sql
	Objetivo.................: Efetivar Matricula do aluno com a turma.
	Autor....................: Victor Leite
	Data.....................: 30/09/2026
	Ex.......................: BEGIN TRANSACTION
								   DBCC FREEPROCCACHE
								   DBCC DROPCLEANBUFFERS

								   DECLARE @Retorno INT,
										  @DataAgora DATETIME = GETDATE()

								   EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 4

								   SELECT @Retorno as Retorno,
								          DATEDIFF(MS, @DataAgora, GETDATE()) as TempoMs

							   ROLLBACK TRANSACTION 

	Retornos.................: 0 - Matricula efetivada com sucesso.
							  -1 - ReservaMatricula informada nao existe
							  -2 - Situacao Reserva tem que ser 'Reservada'
							  -3 - Reserva expirada
							  -4 - Erro ao criar a matricula.
							  -5 - Erro ao atualizar situacao da reserva.
							  -6 - erro ao criar as 12 parcelas.
	*/
	BEGIN
	SET XACT_ABORT ON

	DECLARE @IdReserva INT,
			@IdSituacaoReserva INT,
			@DataExpiracao DATE,
			@DataHoje DATE = GETDATE(),
			@ValorMensalidade DECIMAL(14,2)

	SELECT @IdReserva = rm.Id,
			@IdSituacaoReserva = rm.IdSituacaoReserva,
			@DataExpiracao = rm.DataExpiracao,
			@ValorMensalidade = cu.ValorMensalidade
		FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
			INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
				ON rm.IdTurma = tu.Id
			INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
				ON tu.IdCurso = cu.Id								
		WHERE rm.Id = @IdReservaMatricula

	-- Valida se a ReservaMatricula existe
	IF @IdReserva IS NULL
		RETURN -1
	
	-- Verifica se a situacao da reserva é diferente de 'Reservada' 
	IF @IdSituacaoReserva <> 1
		RETURN -2

	--Verifica se a DataExpiracao é maior que hoje
	IF @DataExpiracao < @DataHoje
		RETURN -3

	BEGIN TRANSACTION
		-- cria a matrícula
		INSERT INTO [dbo].[Matricula](IdAluno, IdReservaMatricula, IdSituacaoMatricula, IdTurma, ValorMensalidade, DataMatricula)
			SELECT  rm.IdAluno,
					@IdReservaMatricula,
					1,
					rm.IdTurma,
					cu.ValorMensalidade,
					GETDATE()
				FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
					INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
						ON rm.IdTurma = tu.Id
					INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
						ON tu.IdCurso = cu.Id
				WHERE rm.Id = @IdReservaMatricula
		
		IF @@ERROR <> 0 
		BEGIN
			ROLLBACK TRANSACTION
			RETURN -4
		END

		DECLARE @IdMatricula INT = SCOPE_IDENTITY()

		-- Atualiza situacao reserva de ReservaMatricula para 2(Efetivada)
		UPDATE [dbo].[ReservaMatricula]
			SET IdSituacaoReserva = 2
			WHERE Id = @IdReservaMatricula
		
		IF @@ERROR <> 0 
		BEGIN
			ROLLBACK TRANSACTION
			RETURN -5
		END

		DECLARE @Contador INT = 1

		-- Cria as 12 parcelas.
		WHILE @Contador <= 12
		BEGIN
			INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
				VALUES (
						@IdMatricula, 
						1, 
						@Contador,
						@ValorMensalidade,
						DATEADD(MONTH, @Contador, CAST(DATEFROMPARTS(YEAR(@DataHoje), MONTH(@DataHoje), 10) AS DATE))
						)

			IF @@ERROR <> 0
			BEGIN
				ROLLBACK TRANSACTION
				RETURN -6
			END
		    SET @Contador = @Contador + 1
		END
	COMMIT TRANSACTION
			
	RETURN 0
	END
GO

--PROCEDURE 03
USE Escola;
GO

IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_RegistrarPagamento]
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento] @IdParcela INT, @ValorPagamento DECIMAL(14,2)
	AS
	/*
	Documentacao
	Arquivo Fonte............: SP_RegistrarPagamente.sql
	Objetivo.................: Registrar pagamento
	Autor....................: Victor Leite
	Data.....................: 30/09/2026
	Ex.......................:  BEGIN TRANSACTION
									DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @Retorno INT,
										    @DataAgora DATETIME = GETDATE()

									EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 4, 500

									SELECT @Retorno as Retorno,
								           DATEDIFF(MS, @DataAgora, GETDATE()) as TempoMs

								ROLLBACK TRANSACTION
	Retornos.................: IdPagamento - Sucesso
										-1 - Parcela nao existe ou ja foi paga.
										-2 - Erro ao usar a funcao de atualizar valor do saldo.
										-3 - Valor Pago inferior ao valor da parcela.
										-4 - Erro ao inserir dados na tabela Pagamento.
	*/
	BEGIN
		--Valida se a parcela existe
		IF NOT EXISTS (
						SELECT *
							FROM [dbo].[Parcela] WITH(NOLOCK)
							WHERE Id = @IdParcela
								AND IdSituacaoParcela NOT IN (3, 4)
					  )
			RETURN -1

		DECLARE @ValorParcelaAtualizado DECIMAL(14,2)
		
		--Usa a funcao para pegar o valor atualizado da parcela.
		SELECT @ValorParcelaAtualizado = [dbo].[FNC_VerificaValorAtualizadoParcela] (@IdParcela, CAST(GETDATE() AS DATE))

		--Verifica se o valor veio certo
		IF @ValorParcelaAtualizado < 0
			RETURN -2

		-- Verifica se o valor informado é menor do valor da parcela atualizado.
		IF @ValorPagamento < @ValorParcelaAtualizado
			RETURN -3

		--Registrando pagamento.
		INSERT INTO [dbo].[Pagamento] (IdParcela, ValorPago, DataPagamento)
			VALUES(@IdParcela, @ValorPagamento, GETDATE())

		IF @@ERROR <> 0
			RETURN -4

		RETURN SCOPE_IDENTITY()
	END
GO
--PROCEDURE 04 
USE Escola;
GO
IF EXISTS (SELECT TOP 1 1 FROM [dbo].[sysobjects] WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[SP_CancelarMatricula]
GO
CREATE PROCEDURE [dbo].[SP_CancelarMatricula] @IdMatricula INT
	AS
	/*
	Documentacao
	Arquivo Fonte............: SP_CancelarMatricula.sql
	Objetivo.................: Cancelar matricula
	Autor....................: Victor Leite
	Data.....................: 30/09/2026
	Ex.......................: BEGIN TRANSACTION
									DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									DECLARE @Retorno INT,
											@DataAgora DATETIME = GETDATE()

									EXEC @Retorno = [dbo].[SP_CancelarMatricula] 1

									SELECT @Retorno as Retorno,
										DATEDIFF(MS, @DataAgora, GETDATE())

							ROLLBACK TRANSACTION
	Retornos.................:   0 - Cancelo com sucesso!
								-1 - IdMatricula inexistente ou com status diferente de Ativo.
								-2 - Nao pode cancelar Matricula com Parcelas pendentes e sem Negociacao.
								-3 - Erro ao atualizar Situacao da conta.

	*/
	BEGIN
	-- verifica se matricula existe e esta ativa.
	IF NOT EXISTS (
					SELECT 1
						FROM [dbo].[Matricula] WITH(NOLOCK)
						WHERE Id = @IdMatricula
							AND IdSituacaoMatricula = 1
					)
		RETURN -1


	-- Se tiver parcelas abertas ou vencidas nao pode cancelar matricula. 
	IF (
		SELECT  COUNT(*)
			FROM [dbo].[Parcela]
			WHERE IdMatricula = @IdMatricula
				AND IdSituacaoParcela NOT IN (3, 4)
		) > 0
		BEGIN
			-- Verifica se tem negociacao QUITADA.
			IF NOT EXISTS (
							SELECT 1
								FROM [dbo].[Negociacao]
								WHERE IdMatricula = @IdMatricula
									AND IdSituacaoNegociacao = 2
							)
				RETURN -2
		END

		--Atualiza Situacao matricula para Cancelada.
		UPDATE [dbo].[Matricula]
			SET IdSituacaoMatricula = 2
			WHERE Id = @IdMatricula

		IF @@ERROR <> 0
			RETURN -3

		RETURN 0
	END
GO
--├── Triggers/     
--→ TRIGGER 01 
USE Escola;
GO

IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_AtualizaParcelaAposPagamento]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1)
	DROP TRIGGER [dbo].[SP_AtualizaParcelaAposPagamento];
GO

CREATE TRIGGER [dbo].[SP_AtualizaParcelaAposPagamento]
	ON [dbo].[Pagamento]
	AFTER INSERT
	AS
	/*
	Documentacao
	Arquivo Fonte............: SP_AtualizaParcelaAposPagamento.sql
	Objetivo.................: Atualizar situacao da parcela para paga apos a efetivacao do pagamento.
	Autor....................: Victor Leite
	Data.....................: 30/09/2026
	Exemplo..................:  
								BEGIN TRANSACTION
									DBCC FREEPROCCACHE
									DBCC DROPCLEANBUFFERS

									SELECT * 
										FROM [dbo].[Parcela] WHERE Id = 4

									DECLARE @Retorno INT

									EXEC @Retorno = [dbo].[SP_RegistrarPagamento] 4, 500

									SELECT @Retorno as Retorno

									
									SELECT * 
										FROM [dbo].[Parcela] WHERE Id = 4

								ROLLBACK TRANSACTION

	*/
	BEGIN
	    -- atualiza situacao parcela para Paga
		UPDATE pa
			SET pa.IdSituacaoParcela = 3
			FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
				INNER JOIN inserted AS i
					ON pa.Id = i.IdParcela
			WHERE pa.IdSituacaoParcela <> 4

		 IF @@ERROR <> 0
            BEGIN
                RAISERROR('Erro ao atualizar o status da parcela.', 16, 1)
                RETURN
            END
	END
GO


--└── Testes/       
--→ testes ativos do item 6

--• Reserva válida e tentativas de reserva em turma sem vaga, de reserva duplicada (mesmo aluno e 
--mesma turma) e de reserva com aluno ou turma inativos. 

BEGIN TRANSACTION
	-- RESERVA VÁLIDA.
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS
								  
	DECLARE @Retorno INT

	EXEC @Retorno = [dbo].[SP_ReservarMatricula] 1, 2

	SELECT @Retorno as Retorno
	
	--TENTANDO RESERVA DUPLICADA
	DECLARE @Retorno2 INT

	EXEC @Retorno2 = [dbo].[SP_ReservarMatricula] 1, 2

	SELECT @Retorno2 as Retorno2

	--INSERT PARA COMPLETAR AS VAGAS DA TURMA
	DECLARE @Retorno3 INT

	EXEC @Retorno3 = [dbo].[SP_ReservarMatricula] 2, 2

	SELECT @Retorno3 as Retorno3

	--TENTANDO COLOCAR ALUNO EM TURMA LOTADA (ERRO -3)
	DECLARE @Retorno4 INT

	EXEC @Retorno4 = [dbo].[SP_ReservarMatricula] 3, 2

	SELECT @Retorno4 as Retorno4
	--TENTANDO COLOCAR ALUNO EM TURMA INATIVA
	DECLARE @Retorno5 INT

	EXEC @Retorno5 = [dbo].[SP_ReservarMatricula] 1, 4

	SELECT @Retorno5 as Retorno5

ROLLBACK TRANSACTION


--• Efetivação válida, conferindo se as 12 parcelas foram geradas com números, valores e 
--vencimentos corretos. 
BEGIN TRANSACTION
	DECLARE @Retorno6 INT

	SELECT *--TOP 12 *
		FROM [dbo].[Parcela] WITH(NOLOCK)
		ORDER BY Id DESC

	EXEC @Retorno6 = [dbo].[SP_EfetivarMatricula] 1

	SELECT @Retorno6 as Retorno

	SELECT *--TOP 12 *
		FROM [dbo].[Parcela] WITH(NOLOCK)
		ORDER BY Id DESC
ROLLBACK TRANSACTION

--• Tentativas de efetivar uma reserva já EFETIVADA e uma reserva com a data de expiração vencida. 
BEGIN TRANSACTION
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS

	-- Reserva ja EFETIVADA (esperado -2)
	DECLARE @Retorno7 INT

	EXEC @Retorno7 = [dbo].[SP_EfetivarMatricula] 6

	SELECT @Retorno7 as Retorno7

	-- Reserva RESERVADA com data de expiracao vencida (esperado -3)
	UPDATE [dbo].[ReservaMatricula]
		SET DataExpiracao = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
		WHERE Id = 4

	DECLARE @Retorno8 INT

	EXEC @Retorno8 = [dbo].[SP_EfetivarMatricula] 4

	SELECT @Retorno8 as Retorno8

ROLLBACK TRANSACTION 

--• Pagamento dentro do vencimento e pagamento em atraso (com juros). 
	
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS
	--Pagamento Dentro do vencimento
	SELECT [dbo].[FNC_VerificaValorAtualizadoParcela] (4, '2026-10-01')
	--Pagamento apos o vencimento
	SELECT [dbo].[FNC_VerificaValorAtualizadoParcela] (4, '2026-11-19')


--• Tentativa de pagamento de parcela já PAGA. 

BEGIN TRANSACTION
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS

	DECLARE @Retorno9 INT,
			@DataAgora DATETIME = GETDATE()

	EXEC @Retorno9 = [dbo].[SP_RegistrarPagamento] 1, 500

	SELECT @Retorno9 as Retorno,
			DATEDIFF(MS, @DataAgora, GETDATE()) as TempoMs

ROLLBACK TRANSACTION

--• Teste do Trigger, comprovando que a parcela passou para PAGA após o pagamento.

BEGIN TRANSACTION
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS

	SELECT * 
		FROM [dbo].[Parcela] WHERE Id = 4

	DECLARE @Retorno10 INT

	EXEC @Retorno10 = [dbo].[SP_RegistrarPagamento] 4, 500

	SELECT @Retorno10 as Retorno
						
	SELECT * 
		FROM [dbo].[Parcela] WHERE Id = 4

ROLLBACK TRANSACTION


--• Teste do Trigger com várias linhas: uma única instrução INSERT registrando pagamentos de mais 
--de uma parcela, comprovando que todas foram atualizadas. 
BEGIN TRANSACTION
	SELECT * 
		FROM [dbo].[Parcela] WHERE Id IN (4, 5, 6)

INSERT INTO [dbo].[Pagamento] (IdParcela, ValorPago, DataPagamento)
			VALUES (4, 500, GETDATE()),
				   (5, 500, GETDATE()),
				   (6, 500, GETDATE())
				   

	SELECT * 
		FROM [dbo].[Parcela] WHERE Id IN (4, 5, 6)
ROLLBACK TRANSACTION

--• Tentativa de cancelamento com parcelas pendentes e sem negociação QUITADA (deve ser 
--bloqueada). 

BEGIN TRANSACTION
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS

	DECLARE @Retorno11 INT

	EXEC @Retorno11 = [dbo].[SP_CancelarMatricula] 1

	SELECT @Retorno11 as Retorno

ROLLBACK TRANSACTION

--• Cancelamento permitido com negociação QUITADA e cancelamento permitido de matrícula sem 
--parcelas pendentes. 

BEGIN TRANSACTION
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS

	DECLARE @Retorno12 INT

	EXEC @Retorno12 = [dbo].[SP_CancelarMatricula] 2

	SELECT @Retorno12 as Retorno

ROLLBACK TRANSACTION

-- Matricula sem parcelas pendentes (todas pagas)
BEGIN TRANSACTION
	DBCC FREEPROCCACHE
	DBCC DROPCLEANBUFFERS

	DECLARE @Retorno13 INT

	EXEC @Retorno13 = [dbo].[SP_CancelarMatricula] 4

	SELECT @Retorno13 as Retorno

ROLLBACK TRANSACTION

--• Consultas às duas Views e chamadas das duas Functions.

SELECT * FROM [dbo].[VW_MatriculasAtivas]

SELECT * FROM [dbo].[VW_SituacaoFinanceira]

SELECT [dbo].[FN_VerificaDisponibilidadeDeVagas] (1) as VagasTurma1,
	   [dbo].[FN_VerificaDisponibilidadeDeVagas] (2) as VagasTurma2

SELECT [dbo].[FNC_VerificaValorAtualizadoParcela] (4, '2026-10-01') as ValorNoPrazo,
	   [dbo].[FNC_VerificaValorAtualizadoParcela] (4, '2026-11-19') as ValorComJuros

