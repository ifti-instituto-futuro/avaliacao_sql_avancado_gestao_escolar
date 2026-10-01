-- View -----------------------------------------------------------------------------------------------

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[VW_ListarMatriculasAtivas]')
				AND OBJECTPROPERTY(Id, N'IsVIEW') = 1)

			DROP VIEW [dbo].[VW_ListarMatriculasAtivas]
			GO

			CREATE VIEW [dbo].[VW_ListarMatriculasAtivas]
				AS
				/*
					Documentacao
					Arquivo Fonte............: VW_ListarMatriculasAtivas
					Objetivos................: Listar matriculas ativas
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @DataInicio DATETIME = GETDATE()

											   SELECT * FROM [VW_ListarMatriculasAtivas]

											   SELECT DATEDIFF(MILLISECOND, @DataInicio, GETDATE())
				*/
					SELECT al.Nome as NomeAluno,
						   cu.Nome as CursoNome,
						   tu.Codigo as CodigoTurma,
						   ma.DataMatricula as DataMatricula,
						   sm.Descricao as Situacao
						FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
							INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
								ON al.Id = ma.IdAluno
							INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
								ON tu.Id = ma.IdTurma
							INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
								ON cu.Id = tu.IdCurso
							INNER JOIN SituacaoMatricula AS sm WITH(NOLOCK)
								ON sm.Id = ma.IdSituacaoMatricula
							WHERE sm.Descricao = 'Ativa'
					GO
					
IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[VW_ListarSituacaoFinanceira]')
				AND OBJECTPROPERTY(Id, N'IsVIEW') = 1)

			DROP VIEW [dbo].[VW_ListarSituacaoFinanceira]
			GO

			CREATE VIEW [dbo].[VW_ListarSituacaoFinanceira]
				AS
				/*
					Documentacao
					Arquivo Fonte............: VW_ListarSituacaoFinanceira
					Objetivos................: Listar a situacao financeira
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @DataInicio DATETIME = GETDATE()

											   SELECT * FROM [VW_ListarSituacaoFinanceira]

											   SELECT DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo
				*/
					  SELECT al.Nome as Aluno,
							 COUNT(pa.Numero) as QuantidadeParcelaTotal,
							 SUM(CASE 
								     WHEN pa.IdSituacaoParcela = 1 THEN 1 ELSE 0 
								 END) as QuantidadeParcelasPagas,
							 SUM(CASE 
								     WHEN pa.DataVencimento > GETDATE() THEN 1 ELSE 0 
								 END) as QuantidadeParcelasPendente,
							 SUM(CASE 
								     WHEN pa.IdSituacaoParcela = 2 OR (pa.DataVencimento < CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 
								 END) as QuantidadeParcelasCanceladas,
                             ISNULL(SUM(CASE 
										    WHEN pa.IdSituacaoParcela IN (1, 2) THEN pa.ValorOriginal 
									    END), 0) as ValorPendenteRestante
						 FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
							JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
							   ON al.Id = ma.IdAluno
							 LEFT JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
							   ON pa.IdMatricula = ma.Id
						GROUP BY ma.Id, al.Nome
					GO

-- FUNCTION -----------------------------------------------------------------------------------------------

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[FNC_VerificarVagasDisponiveisTurma]')
				AND OBJECTPROPERTY(Id, N'IsFUNCTION') = 1)

			DROP FUNCTION [dbo].[FNC_VerificarVagasDisponiveisTurma]
			GO

			CREATE FUNCTION [dbo].[FNC_VerificarVagasDisponiveisTurma] (@IdTurma INT)
				RETURNS INT
				AS
				/*
					Documentacao
					Arquivo Fonte............: FNC_VerificarVagasDisponiveisTurma
					Objetivo.................: Verificar quantas vagas disponiveis uma turma possui
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @Retorno INT,
													   @DataInicio DATETIME = GETDATE()

											   SELECT @Retorno = [dbo].[FNC_VerificarVagasDisponiveisTurma]
																	 (2)

											   SELECT @Retorno AS Retorno,
													  DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo

					Retorno..................: Quantidade de vagas - Sucesso
											  -1 - Erro: o id da function é valido
											  -2 - Erro: quantidade de alunos na turma ja é o limite 
				*/
				BEGIN
					-- verficar se o id da function é valido
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Turma] AS tu WITH(NOLOCK)
										WHERE tu.Id = @IdTurma
								  )
						BEGIN
							RETURN -1
						END

					-- verificar se a quantidade de alunos na turma ja é o limite 
					IF (
						SELECT COUNT(ma.Id) as QuantidadeMatricula
						   FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
						   WHERE ma.IdTurma = @IdTurma
					   ) = (
							 SELECT tu.Capacidade as Capacidade
								FROM [dbo].[Turma] AS tu WITH(NOLOCK)
								WHERE tu.Id = @IdTurma
						   )
						BEGIN
							RETURN -2
						END

						-- retornar a quantidade de vagas disponivel
						RETURN (
								 SELECT tu.Capacidade - (
														  SELECT COUNT(ma.Id) as QuantidadeMatricula
															 FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
															 WHERE ma.IdTurma = @IdTurma
														)
									 FROM [dbo].[Turma] AS tu WITH(NOLOCK)
									 WHERE tu.Id = @IdTurma
							   )

					END
				GO

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[FNC_CalcularJurosParcela]')
				AND OBJECTPROPERTY(Id, N'IsFUNCTION') = 1)

			DROP FUNCTION [dbo].[FNC_CalcularJurosParcela]
			GO

			CREATE FUNCTION [dbo].[FNC_CalcularJurosParcela] (@IdParcela INT, @DataReferencia DATE)
				RETURNS DECIMAL(10, 2)
				AS
				/*
					Documentacao
					Arquivo Fonte............: FNC_CalcularJurosParcela
					Objetivo.................: Calcular o juros de uma parcela
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @Retorno INT,
													   @DataInicio DATETIME = GETDATE()

											   SELECT @Retorno = [dbo].[FNC_CalcularJurosParcela]
																	 (2, '20260923')

											   SELECT @Retorno AS Retorno,
													  DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo

					Retorno..................: ValorCalculado - Sucesso
											  -1 - Erro: parcela nao existe 
				*/
				BEGIN
					-- validar se a parcela existe
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
										WHERE pa.Id = @IdParcela
								  )
						BEGIN
							RETURN -1
						END
					-- se a data de referencia for maior que a data de vencimento retornar com o caluclo
					IF @DataReferencia > (
										   SELECT pa.DataVencimento
											  FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
											  WHERE pa.Id = @IdParcela
										 )
						BEGIN
							DECLARE @MesVencido INT = 0

							-- verificar se o mes é vencido
							IF (
								 SELECT pa.DataVencimento
									FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
									WHERE pa.Id = @IdParcela
							   ) < @DataReferencia
								BEGIN
									SET @MesVencido = 1
								END

							RETURN (
									 SELECT pa.ValorOriginal + (pa.ValorOriginal * ((DATEDIFF(MONTH, pa.DataVencimento, @DataReferencia) + @MesVencido) * 0.01 ))
									    FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
									    WHERE pa.Id = @IdParcela
								   )
						END

					-- retornar o valor original se a parcela nao precisar receber juros
					RETURN (
							 SELECT pa.ValorOriginal
								FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
								WHERE pa.Id = @IdParcela
						   )
				END
			GO

-- PROCEDURE -----------------------------------------------------------------------------------------------

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id = 
			OBJECT_ID(N'[dbo].[SP_ReservarMatricula]')
				AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)

			DROP PROCEDURE [dbo].[SP_ReservarMatricula]
			GO

			CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
				@IdAluno INT,
				@IdTurma INT,
				@DataMatricula DATETIME
				AS
				/*
					Documentacao
					Arquivo Fonte............: SP_ReservarMatricula
					Objetivo.................: Realizar uma reserva de matricula
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @Retorno INT,
													   @DataInicio DATETIME = GETDATE()

											   EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 1, 
																							@IdTurma = 2, 
																							@DataMatricula = '20261111'
																						
											  SELECT @Retorno AS Retorno,
													  DATEDIFF(MILLISECOND, @DataInicio, GETDATE())

				    Retorno..................: 0 - Sucesso
											  -1 - Erro: aluno já existe no registro
											  -2 - Erro: turma já existe no registro
											  -3 - Erro: turma nao possui vagas
											  -4 - Erro: aluno nao esta na tabela reserva
											  -5 - Erro: aluno nao tem matricula ativa na turma
				*/
				BEGIN
					-- verificar se o aluno existe no registro
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Aluno] AS al WITH(NOLOCK)
										WHERE @IdAluno = al.Id
											AND al.Ativo = 1
							      )
						BEGIN
							RETURN -1
						END
					
					-- verificar se a turma existe no registro
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Turma] AS tu WITH(NOLOCK)
										WHERE @IdTurma = tu.Id
											AND tu.Ativo = 1
							      )
						BEGIN
							RETURN -2
						END

					-- verificar com a function se a turma tem ao menos 1 vaga
					IF [dbo].[FNC_VerificarVagasDisponiveisTurma] (@IdTurma) = 0
						BEGIN
							RETURN -3
						END

					-- verificar se o aluno esta na tabela reserva
					IF EXISTS (
								SELECT TOP 1 1
									FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
									WHERE re.DataExpiracao > CAST(GETDATE() AS DATE)
										AND re.IdAluno = @IdAluno
										AND re.IdTurma = @IdTurma
										
 							  )
						BEGIN
							RETURN -4
						END

					-- verificar se o aluno tem matricula ativa na turma
					IF EXISTS (
								SELECT TOP 1 1
									FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
									WHERE ma.IdAluno = @IdAluno
										AND ma.IdTurma = @IdTurma
										AND ma.IdSituacaoMatricula = 1
							  )
						BEGIN
							RETURN -5
						END

					-- inserir na reservaMatricula a pre matricula para confirmacao
					INSERT INTO [dbo].[ReservaMatricula]
						VALUES (@IdAluno, @IdTurma, 1, @DataMatricula, DATEADD(DAY, 7, @DataMatricula))

					RETURN 0
				END
			GO

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id = 
			OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]')
				AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)

			DROP PROCEDURE [dbo].[SP_EfetivarMatricula]
			GO

			CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
				@IdReservaMatricula INT
				AS
				/*
					Documentacao
					Arquivo Fonte............: SP_EfetivarMatricula
					Objetivo.................: Efetivar matricula
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @Retorno INT,
													   @DataInicio DATETIME = GETDATE()

											   EXEC @Retorno = [dbo].[SP_EfetivarMatricula] 1

											   SELECT @Retorno AS Retorno,
													  DATEDIFF(MILLISECOND, @DataInicio, GETDATE())

					Retorno..................: 0 - Sucesso
				*/
				BEGIN
					-- verificar se a reserva matricula existe
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
										WHERE re.Id = @IdReservaMatricula
								  )
						BEGIN
							RETURN -1
						END

					-- verifica se a reserva esta dentro do prazo de expiracao
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)
										WHERE re.IdSituacaoReserva = 1
											AND re.DataExpiracao < CAST(GETDATE() AS DATE)
								  )
						BEGIN
							RETURN -2
						END

					BEGIN TRANSACTION
					-- insere na matricula a reservaMatricula aprovada
						INSERT INTO [dbo].[Matricula]
							SELECT @IdReservaMatricula,
								   re.IdAluno,
								   re.IdTurma,
								   1,
								   GETDATE(),
								   (
									 SELECT cu.ValorMensalidade
										FROM [dbo].[Turma] AS tu WITH(NOLOCK)
											INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
												ON cu.Id = tu.IdCurso
										WHERE re.IdTurma = tu.Id
								   )
								FROM [dbo].[ReservaMatricula] AS re WITH(NOLOCK)

						-- atualiza o status da reserva
						UPDATE ReservaMatricula
							SET IdSituacaoReserva = 2
							WHERE Id = @IdReservaMatricula

						DECLARE @Repeticao INT = 12

						-- verifica se houve algum erro durante a manipulacao dos updates e inserts
						IF @@ERROR != 0 OR @@ROWCOUNT = 0
							BEGIN
								ROLLBACK TRANSACTION
								RETURN -3
							END
							
						COMMIT TRANSACTION
						RETURN 0
					END
			GO

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]')
				AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)

			DROP PROCEDURE [dbo].[SP_RegistrarPagamento]
			GO

			CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
				@IdParcela INT,
				@DataPagamento DATETIME,
				@ValorPagamento DECIMAL(10, 2)
				AS
				/*
					Documentacao
					Arquivo Fonte............: SP_RegistrarPagamento
					Objetivo.................: Registrar o pagamento da parcela
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @Retorno INT,
													   @DataInicio DATETIME = GETDATE()

											   EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
																							 @DataPagamento = '20260810',
																							 @ValorPagamento = 550.00

											   SELECT @Retorno AS Retorno,
													  DATEDIFF(MILLISECOND, @DataInicio, GETDATE())

					Retorno...................: 0 - Sucesso
											   -1 - Erro: parcela nao existe
											   -2 - Erro: parcela esta cancelada ou paga
											   -3 - Erro: valor do pagamento é menor do que o da parcela
											   -4 - Erro: pagamento registrado na tabela de pagamento
				*/
				BEGIN
					-- verificar se a parcela existe
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
										WHERE pa.Id = @IdParcela
								  )
						BEGIN
							RETURN -1
						END

					-- verificar se a parcela esta cancelada ou paga
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Parcela] AS pa
										WHERE pa.IdSituacaoParcela IN (1, 2)
								  )
						BEGIN
							RETURN -2
						END

					-- verifica se o valor do pagamento é menor ao da parcela
					IF @ValorPagamento < (
										   SELECT pa.ValorOriginal
											  FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
											  WHERE @IdParcela = pa.Id
										 )
						BEGIN
							RETURN -3
						END

					-- verificar se existe o pagamento registrado na tabela de pagamento
					IF EXISTS (
							    SELECT TOP 1 1
								   FROM [dbo].[Pagamento] AS pa WITH(NOLOCK)
								   WHERE pa.IdParcela = @IdParcela
							  )
						BEGIN
							RETURN -4
						END

					-- inserir em pagamento o pagamento da parcela
					INSERT INTO Pagamento
						VALUES (@IdParcela, @DataPagamento, @ValorPagamento)

					RETURN 0
				END
			GO

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[SP_CancelarMatricula]')
				AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)

			DROP PROCEDURE [dbo].[SP_CancelarMatricula]
			GO

			CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
				@IdMatricula INT
				AS
				/*
					Documentacao
					Arquivo Fonte............: SP_CancelarMatricula
					Objetivo.................: Cancelar a matricula
					Autor....................: Vinicius Souza
					Data.....................: 30/09/2026
					Ex.......................: DBCC FREEPROCCACHE
											   DBCC DROPCLEANBUFFERS

											   DECLARE @Retorno INT,
													   @DataInicio DATETIME = GETDATE()

											   EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 1
											   
											   SELECT @Retorno AS Retorno,
													  DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as Tempo

					Retorno..................: 0 - Sucesso
											  -1 - Erro: matricula nao existe ou/e nao esta ativa
											  -2 - Erro: matricula nao possui alguma negociacao
				*/
				BEGIN
					-- verificar se a matricula existe e esta ativa
					IF NOT EXISTS (
									SELECT TOP 1 1
										FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
										WHERE ma.Id = @IdMatricula
											AND ma.IdSituacaoMatricula = 1
								  )
						BEGIN
							RETURN -1
						END

					-- verificar se as parcelas sao pendentes
					IF NOT EXISTS (
								    SELECT TOP 1 1
									   FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
									   WHERE pa.IdSituacaoParcela IN (1, 2)
							      )
						BEGIN
							-- verifica se a matricula possui alguma negociacao
							IF NOT EXISTS (
										    SELECT TOP 1 1
											   FROM [dbo].[Negociacao] AS ne WITH(NOLOCK)
											   WHERE @IdMatricula = ne.IdMatricula
											       AND ne.IdSituacaoNegociacao != 2
									      )
								BEGIN
									RETURN -2
								END
						END

					-- atualiza a matricula
					UPDATE Matricula
						SET IdSituacaoMatricula = 2
						WHERE Id = @IdMatricula

					RETURN 0
				END

-- Trigger -----------------------------------------------------------------------------------------

IF EXISTS (
			SELECT * FROM SYSOBJECTS
			WHERE Id =
			OBJECT_ID(N'[dbo].[TRG_AtualizarParcela]')
				AND OBJECTPROPERTY(Id, N'IsTrigger') = 1)

			DROP TRIGGER [dbo].[TRG_AtualizarParcela]
			GO

			CREATE TRIGGER [dbo].[TRG_AtualizarParcela]
				ON [dbo].[Pagamento]
				AFTER INSERT
				AS
				/*
					Documentacao
					Arquivo Fonte............: TRG_AtualizarParcela
					Objetivo.................: Atualizar a parcela depos de inserida em pagamento
					Autor....................: Vinicius Souza
					Data.....................: 31/09/2026
				*/
				BEGIN
					-- atualiza a parcela para paga
					UPDATE Parcela
						SET IdSituacaoParcela = 3
						WHERE Id IN (
									  SELECT ins.IdParcela
										 FROM inserted AS ins
								    )

					-- cancelar a atualizacao se algo erro ocorrer no update
					IF @@ERROR != 0 OR @@ROWCOUNT = 0
						BEGIN
							ROLLBACK TRANSACTION
							RAISERROR('a atualizacao de status em alguma parcela nao foi possivel', 1, 16)
							RETURN
						END
				END
			GO

-- Testes --------------------------------------------------------------------------------------------

-- 1 

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

DECLARE @Retorno INT,
		@DataInicio DATETIME = GETDATE()

EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 1, 
											 @IdTurma = 2, 
											 @DataMatricula = '20261111'
																						
SELECT @Retorno AS Retorno,
DATEDIFF(MILLISECOND, @DataInicio, GETDATE())

-- 2

-- 3

-- 4

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

DECLARE @Retorno4 INT,
	    @DataInicio4 DATETIME = GETDATE()

EXEC @Retorno4 = [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
											   @DataPagamento = '20260810',
										       @ValorPagamento = 550.00
SELECT @Retorno4 AS Retorno,
	   DATEDIFF(MILLISECOND, @DataInicio4, GETDATE()) as Tempo

-- 5

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

DECLARE @Retorno5 INT,
		@DataInicio5 DATETIME = GETDATE()

EXEC @Retorno5 = [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
											  @DataPagamento = '20260810',
											  @ValorPagamento = 550.00

SELECT @Retorno5 AS Retorno,
DATEDIFF(MILLISECOND, @DataInicio5, GETDATE()) as Tempo

-- 6

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

DECLARE @Retorno6 INT,
		@DataInicio6 DATETIME = GETDATE()

EXEC @Retorno6 = [dbo].[SP_RegistrarPagamento] @IdParcela = 5,
											   @DataPagamento = '20270810',
											   @ValorPagamento = 600.00

SELECT @Retorno6 AS Retorno,
DATEDIFF(MILLISECOND, @DataInicio6, GETDATE()) as Tempo

-- rodando novamente o teste acima você consegue a prova que a parcela mudou para o status Pago

-- 7

-- 8

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

DECLARE @Retorno8 INT,
		@DataInicio8 DATETIME = GETDATE()

EXEC @Retorno8 = [dbo].[SP_CancelarMatricula] @IdMatricula = 1
											   
SELECT @Retorno8 AS Retorno,
DATEDIFF(MILLISECOND, @DataInicio8, GETDATE()) as Tempo
