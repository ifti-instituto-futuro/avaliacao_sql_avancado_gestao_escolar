-------------------------------------------------------------------------------------------------------------------
--VIEWS

--01.VW_MatriculasAtivas
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]') AND TYPE = 'V')
  DROP VIEW [dbo].[VW_MatriculasAtivas];
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
    AS
    /*
        Documentacao
        Arquivo Fonte............: VW_MatriculasAtivas.sql
        Objetivo.................: Mostrar as matrículas ativas
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: SELECT * FROM [dbo].[VW_MatriculasAtivas]
    */
    SELECT  ma.Id as IdMatricula,
            al.Nome as Aluno,
            cu.Nome as Curso,
            tu.Codigo as Turma,
            ma.DataMatricula as DataMatricula,
            sm.Descricao as Situacao
        FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON ma.IdAluno = al.Id
            JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                ON tu.Id = ma.IdTurma
            JOIN [Curso] AS cu WITH(NOLOCK)
                ON cu.Id = tu.IdCurso
            JOIN [SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = ma.IdSituacaoMatricula
        WHERE sm.Descricao = 'Ativa'

GO

--02.VW_SituacaoFinanceira.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]') AND OBJECTPROPERTY(Id, N'IsView') = 1)
    DROP VIEW [dbo].[VW_SituacaoFinanceira];
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
    AS
    /*
        Documentacao
        Arquivo Fonte............: VW_SituacaoFinanceira.sql
        Objetivo.................: Exibir, por matricula, a situação financeira
        Autor....................: Rodrigo Diniz Araújo
        Data.....................: 29/09/2026
        Ex.......................: SELECT * FROM [dbo].[VW_SituacaoFinanceira]
    */

    SELECT  ma.Id as IdMatricula,
            al.Nome as Aluno,
            COUNT(pa.Numero) as TotalParcelas,
            SUM(CASE WHEN sp.Descricao = 'Paga' THEN 1 ELSE 0 END) as ParcelasPagas,
            SUM(CASE WHEN sp.Descricao IN ('Aberta','Vencida') THEN 1 ELSE 0 END) as ParcelasPendentes,
            SUM(CASE WHEN sp.Descricao = 'Vencida' OR (sp.Descricao = 'Aberta' AND pa.DataVencimento < CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END) as ParcelasVencidas,
            ISNULL(SUM(CASE WHEN sp.Descricao IN ('Aberta','Vencida') THEN pa.ValorOriginal END), 0) as ValorTotalPendente
        FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON al.Id = ma.IdAluno
            LEFT JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)
                ON pa.IdMatricula = ma.Id
            LEFT JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                ON sp.Id = pa.IdSituacaoParcela
        GROUP BY ma.Id, al.Nome
GO

-------------------------------------------------------------------------------------------------------------------
--FUNCTIONS

--01.FNC_DisponibilidadeDeVagas.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[FNC_DisponibilidadeDeVagas]') AND TYPE = 'FN')
  DROP FUNCTION [dbo].[FNC_DisponibilidadeDeVagas];
GO

CREATE FUNCTION [dbo].[FNC_DisponibilidadeDeVagas](@IdTurma INT)
    RETURNS INT
    AS
    /*
        Documentacao
        Arquivo Fonte............: FNC_DisponibilidadeDeVagas.sql
        Objetivo.................: Verificar se há vagas na turma
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: 
        
                                    DECLARE @DataInicio DATETIME = GETDATE()

                                    SELECT [dbo].[FNC_DisponibilidadeDeVagas](1) as VagasDisponiveis

                                    SELECT DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao
        
        Retornos.................: @Vagas - Sucesso,
                                   -1 - Turma não encontrada
    */
    BEGIN
        IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[Turma] AS tu WITH(NOLOCK) WHERE tu.Id = @IdTurma)
            RETURN -1

        DECLARE @Vagas INT
        DECLARE @CapacidadeTurma INT
        DECLARE @MatriculasAtivas INT
        DECLARE @Reservadas INT

        SELECT  @CapacidadeTurma = tu.Capacidade
            FROM [dbo].[Turma] AS tu WITH(NOLOCK)
            WHERE tu.Id = @IdTurma

        SELECT  @MatriculasAtivas = COUNT(ma.Id)
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                    ON ma.IdSituacaoMatricula = ma.Id
            WHERE ma.IdTurma = @IdTurma
                AND sm.Descricao = 'Ativa'
     
        SELECT  @Reservadas = COUNT(rm.Id)
            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                JOIN [dbo].[SituacaoReserva] AS sr WITH(NOLOCK) 
                    ON rm.IdSituacaoReserva = sr.Id
            WHERE rm.IdTurma = @IdTurma
                AND sr.Descricao = 'Reservada'
                AND rm.DataExpiracao >= CAST(GETDATE() AS DATE)

        SET @Vagas = @CapacidadeTurma - @MatriculasAtivas - @Reservadas

        IF @Vagas < 0
            SET @Vagas = 0

        RETURN @Vagas
    END
GO

--02.FNC_ValorAtualizadoParcela.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[FNC_ValorAtualizadoParcela]') AND TYPE = 'FN')
  DROP FUNCTION [dbo].[FNC_ValorAtualizadoParcela];
GO

CREATE FUNCTION [dbo].[FNC_ValorAtualizadoParcela](@IdParcela INT, @DataReferencia DATE)
    RETURNS DECIMAL(14,2)
    AS
    /*
        Documentacao
        Arquivo Fonte............: FNC_ValorAtualizadoParcela.sql
        Objetivo.................: Calcular o valor atualizado da parcela, aplicando juros de 1% em cada mês de atraso
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: 
                                   DECLARE @DataInicio DATETIME = GETDATE()
        
                                   SELECT [dbo].[FNC_ValorAtualizadoParcela](3, '2026-09-30') as ValorParcelaAtualizado

                                   SELECT DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

        Retornos.................: @ValorParcelaAtualizado - Sucesso,
                                   -1 - Parcela não encontrada
                                   
    */
    BEGIN
        IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[Parcela] AS pa WITH(NOLOCK) WHERE pa.Id = @IdParcela)
            RETURN -1

        DECLARE @ValorParcela DECIMAL(14,2)
        DECLARE @Vencimento DATE
        DECLARE @MesesAtrasados INT
        DECLARE @ValorParcelaAtualizado DECIMAL(14,2)

        SELECT  @ValorParcela = pa.ValorOriginal,
                @Vencimento = pa.DataVencimento
            FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
                JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                    ON pa.IdSituacaoParcela = sp.Id
            WHERE pa.Id = @IdParcela

        SET @MesesAtrasados = 0

        IF @DataReferencia > @Vencimento
            BEGIN
                SET @MesesAtrasados = DATEDIFF(MONTH, @Vencimento, @DataReferencia)

                IF DAY(@DataReferencia) > DAY(@Vencimento) 
                    SET @MesesAtrasados = @MesesAtrasados + 1
            END

        SET @ValorParcelaAtualizado = ROUND(@ValorParcela + (@ValorParcela * 0.01 * @MesesAtrasados), 2)

        RETURN @ValorParcelaAtualizado
    END
GO

-------------------------------------------------------------------------------------------------------------------
--PROCEDURES

--01.ReservarMatricula.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_ReservarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
  DROP PROCEDURE [dbo].[SP_ReservarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
    @IdAluno INT,
    @IdTurma INT,
    @DataReserva DATETIME
    AS
    /*
        Documentacao
        Arquivo Fonte............: ReservarMatricula.sql
        Objetivo.................: Reservar uma matricula
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    DECLARE @DataInicio DATETIME = GETDATE(),
                                            @Retorno INT

                                    EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 1,
                                                                                 @IdTurma = 1,
                                                                                 @DataReserva = @DataInicio

                                    SELECT  @Retorno as Retorno,
                                            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

                                    ROLLBACK TRANSACTION
        Retornos.................: @IdReservaMatricula - Sucesso,
                                   -1 - Aluno não encontrado ou Inativo,
                                   -2 - Turma não encontrada,
                                   -3 - O aluno não pode ter, para a mesma turma, uma matrícula na situação ATIVA,
                                   -4 - O aluno não pode ter, para a mesma turma, outra reserva na situação RESERVADA,
                                   -5 - Não há vagas para essa turma,
                                   -6 - Erro ao inserir dados no banco
    */
    BEGIN
        IF NOT EXISTS(
                       SELECT TOP 1 1 
                           FROM [dbo].[Aluno] AS al WITH(NOLOCK) 
                           WHERE al.Id = @IdAluno
                               AND al.Ativo = 1
            )
            RETURN -1

        IF NOT EXISTS(
                      SELECT TOP 1 1 
                          FROM [dbo].[Turma] AS tu WITH(NOLOCK) 
                          WHERE tu.Id = @IdTurma
                              AND tu.Ativo = 1
            )
            RETURN -2

        IF EXISTS(
                  SELECT TOP 1 1
                      FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                      WHERE ma.IdAluno = @IdAluno
                          AND ma.IdTurma = @IdTurma
                          AND ma.IdSituacaoMatricula = 1
            )
            RETURN -3

        IF EXISTS(
                  SELECT TOP 1 1
                      FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                      WHERE rm.IdTurma = @IdTurma
                          AND rm.IdAluno = @IdAluno
                          AND rm.IdSituacaoReserva = 1
                          AND rm.DataExpiracao >= CAST(GETDATE() AS DATE)
            )
            RETURN -4

        IF (SELECT [dbo].[FNC_DisponibilidadeDeVagas](@IdTurma)) <= 0
            RETURN -5

        DECLARE @DataExpiracao DATE = DATEADD(DAY, 7, @DataReserva)
        DECLARE @IdReservaMatricula INT
        DECLARE @IdSituacaoReserva INT

        SELECT  @IdSituacaoReserva = sr.Id FROM [dbo].[SituacaoReserva] AS sr WITH(NOLOCK) WHERE sr.Descricao = 'Reservada'

        INSERT INTO [dbo].[ReservaMatricula](IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
            VALUES(@IdAluno, @IdTurma, @IdSituacaoReserva, @DataReserva, @DataExpiracao)

        IF @@ERROR <> 0
            RETURN -6

        SET @IdReservaMatricula = SCOPE_IDENTITY()

        RETURN @IdReservaMatricula
    END
GO

--02.EfetivarMatricula.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
  DROP PROCEDURE [dbo].[SP_EfetivarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
    @IdReservaMatricula INT
    AS
    /*
        Documentacao
        Arquivo Fonte............: EfetivarMatricula.sql
        Objetivo.................: Matricular aluno pelo Id da reserva
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    DECLARE @DataInicio DATETIME = GETDATE(),
                                            @Retorno INT

                                    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 1 

                                    SELECT  @Retorno as Retorno,
                                            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

                                    ROLLBACK TRANSACTION
        Retornos.................: @IdMatricula - Sucesso,
                                   -1 - Reserva não encontrada,
                                   -2 - Reserva não se encontra mais com situação de Reservada,
                                   -3 - Reserva expirada,
                                   -4 - Mensalidade não encontrada,
                                   -5 - Erro ao inserir dados no banco,
                                   -6 - Erro ao atualizar situação da reserva,
                                   -7 - Erro ao gerar parcelas

    */
    BEGIN
        IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK) WHERE rm.Id = @IdReservaMatricula)
            RETURN -1

        DECLARE @IdAluno INT
        DECLARE @IdTurma INT
        DECLARE @IdSituacaoReserva TINYINT
        DECLARE @DataExpiracao DATE
        DECLARE @DataMatricula DATE
        DECLARE @ValorMensalidade DECIMAL(14,2)
        DECLARE @PrimeiroVencimento DATE
        DECLARE @IdSituacaoMatricula TINYINT
        DECLARE @IdMatricula INT

        SELECT  @IdAluno = rm.IdAluno,
                @IdTurma = rm.IdTurma,
                @IdSituacaoReserva = rm.IdSituacaoReserva,
                @DataExpiracao = rm.DataExpiracao
            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
            WHERE rm.Id = @IdReservaMatricula

        IF @IdSituacaoReserva <> 1
            RETURN -2

        IF @DataExpiracao < CAST(GETDATE() AS DATE)
            RETURN -3
 
        SELECT  @ValorMensalidade = cu.ValorMensalidade
            FROM [dbo].[Turma] AS tu WITH(NOLOCK)
                JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
                    ON tu.IdCurso = cu.Id
            WHERE tu.Id = @IdTurma

        IF @ValorMensalidade IS NULL
            RETURN -4

        SET @DataMatricula = CAST(GETDATE() AS DATE)
        SET @PrimeiroVencimento = DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(@DataMatricula), MONTH(@DataMatricula), 10))

        SELECT  @IdSituacaoMatricula = sm.Id FROM [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK) WHERE sm.Descricao = 'Ativa'

        BEGIN TRANSACTION

            INSERT INTO [dbo].[Matricula](IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
                VALUES(@IdReservaMatricula, @IdAluno, @IdTurma, @IdSituacaoMatricula, @DataMatricula, @ValorMensalidade)

            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -5
                END

            SET @IdMatricula = SCOPE_IDENTITY()

            UPDATE rm
                SET rm.IdSituacaoReserva  = 2
                FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                WHERE rm.Id = @IdReservaMatricula
                    AND rm.IdSituacaoReserva = 1

            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -6
                END

            DECLARE @IdSituacaoParcela TINYINT
            DECLARE @Numero INT = 1

            SELECT  @IdSituacaoParcela = sp.Id FROM [dbo].[SituacaoParcela] AS sp WITH(NOLOCK) WHERE sp.Descricao = 'Aberta'

            WHILE @Numero <= 12
                BEGIN
                    INSERT INTO [dbo].[Parcela](IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
                        VALUES(@IdMatricula, @IdSituacaoParcela, @Numero, @ValorMensalidade, DATEADD(MONTH, @Numero -1, @PrimeiroVencimento))

                    IF @@ERROR <> 0 OR @@ROWCOUNT = 0
                        BEGIN
                            ROLLBACK TRANSACTION
                            RETURN -7
                        END

                    SET @Numero = @Numero + 1
                END

        COMMIT TRANSACTION 

        RETURN @IdMatricula
    END
GO

--03. RegistrarPagamento.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
  DROP PROCEDURE [dbo].[SP_RegistrarPagamento];
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
    @IdParcela INT,
    @DataPagamento DATETIME,
    @ValorPago DECIMAL(14,2)
    AS
    /*
        Documentacao
        Arquivo Fonte............: RegistrarPagamento.sql
        Objetivo.................: Registrar pagamento da parcela aberta ou vencida
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    DECLARE @DataInicio DATETIME = GETDATE(),
                                            @Retorno INT

                                    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 1,
                                                                                  @DataPagamento = @DataInicio,
                                                                                  @ValorPago = 100.00

                                    SELECT  @Retorno as Retorno,
                                            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

                                    ROLLBACK TRANSACTION
        Retornos.................: @IdPagamento - Sucesso,
                                   -1 - Parcela não encontrada,
                                   -2 - Parcela já está paga,
                                   -3 - Parcela não está aberta ou vencida,
                                   -4 - Valor pago é menor que o valor da parcela,
                                   -5 - Erro ao inserir dados no sistema
    */
    BEGIN
        IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[Parcela] AS pa WITH(NOLOCK) WHERE pa.Id = @IdParcela)
            RETURN -1

        DECLARE @SituacaoParcela TINYINT
        DECLARE @ValorAtualizado DECIMAL(14,2)

        SELECT  @SituacaoParcela = pa.IdSituacaoParcela
            FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
            WHERE pa.Id = @IdParcela

        IF @SituacaoParcela = 3
            RETURN -2

        IF @SituacaoParcela NOT IN (1,2)
            RETURN -3

        SET @ValorAtualizado = [dbo].[FNC_ValorAtualizadoParcela](@IdParcela, @DataPagamento)

        IF @ValorPago < @ValorAtualizado
            RETURN -4

        DECLARE @IdPagamento INT

        INSERT INTO [dbo].[Pagamento](IdParcela, DataPagamento, ValorPago)
            VALUES(@IdParcela, @DataPagamento, @ValorPago)

        IF @@ERROR <> 0
            RETURN -5

        SET @IdPagamento = SCOPE_IDENTITY()

        RETURN @IdPagamento
    END
GO

--04.CancelarMatricula.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
  DROP PROCEDURE [dbo].[SP_CancelarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
    @IdMatricula INT
    AS
    /*
        Documentacao
        Arquivo Fonte............: CancelarMatricula.sql
        Objetivo.................: Cancelar matriculas
        Autor....................: Rodrigo Diniz
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION
                                    DBCC FREEPROCCACHE
                                    DBCC DROPCLEANBUFFERS

                                    DECLARE @DataInicio DATETIME = GETDATE(),
                                            @Retorno INT

                                    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4

                                    SELECT  @Retorno as Retorno,
                                            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

                                    ROLLBACK TRANSACTION
        Retornos.................: 0 - Matricula cancelada com sucesso,
                                  -1 - Matricula não encontrada,
                                  -2 - Matricula não está ativa,
                                  -3 - Matricula tem parcelas pendentes e não tem negociações,
                                  -4 - Matricula tem parcelas pendentes e negociação não está quitada
    */
    BEGIN
        IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[Matricula] AS ma WITH(NOLOCK) WHERE ma.Id = @IdMatricula)
            RETURN -1

        IF NOT EXISTS(
                      SELECT TOP 1 1 
                          FROM [dbo].[Matricula] AS ma WITH(NOLOCK) 
                          WHERE ma.Id = @IdMatricula
                              AND ma.IdSituacaoMatricula = 1
            )
            RETURN -2

        DECLARE @ParcelasPendentes INT
        DECLARE @SituacaoNegociacao TINYINT

        SELECT  @ParcelasPendentes = COUNT(pa.Id)
            FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
            WHERE pa.IdMatricula = @IdMatricula
                AND pa.IdSituacaoParcela IN (1,2)

        IF @ParcelasPendentes > 0
            BEGIN
                SELECT TOP 1 @SituacaoNegociacao = ne.IdSituacaoNegociacao
                    FROM [dbo].[Negociacao] AS ne WITH(NOLOCK)
                    WHERE ne.IdMatricula = @IdMatricula
                    ORDER BY ne.Id DESC
 
                IF @SituacaoNegociacao IS NULL
                    RETURN -3
 
                IF @SituacaoNegociacao <> 2
                    RETURN -4
            END

        UPDATE ma
            SET ma.IdSituacaoMatricula = 2
            FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            WHERE ma.Id = @IdMatricula
                AND ma.IdSituacaoMatricula = 1
    END
GO

-------------------------------------------------------------------------------------------------------------------
--TRIGGER

--01.TRG_AtualizarParcelaAposPagamento.sql
IF EXISTS(SELECT * FROM dbo.sysobjects WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaAposPagamento]') AND OBJECTPROPERTY(Id, N'IsTrigger') = 1)
  DROP TRIGGER [dbo].[TRG_AtualizarParcelaAposPagamento];
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaAposPagamento]
  ON [dbo].[Pagamento]
  AFTER INSERT
  AS
  /*
    Documentacao
    Arquivo Fonte............: TRG_AtualizarParcelaAposPagamento.sql
    Objetivo.................: Alterar para paga as parcelas correspondentes ao pagamento
    Autor....................: Rodrigo Diniz
    Data.....................: 30/09/2026
    Ex.......................: BEGIN TRANSACTION
                                DBCC FREEPROCCACHE
                                DBCC DROPCLEANBUFFERS

                               ROLLBACK TRANSACTION
  */
  BEGIN
    IF EXISTS(
                 SELECT TOP 1 1
                    FROM [dbo].[Parcela] AS pa 
                        JOIN inserted AS i
                            ON i.IdParcela = pa.Id
                    WHERE pa.IdSituacaoParcela NOT IN (1,2)
        )
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Nao e permitido registrar pagamento para parcela PAGA ou CANCELADA.', 16, 1)
            RETURN
        END

    UPDATE pa
        SET pa.IdSituacaoParcela = 3
        FROM [dbo].[Parcela] AS pa WITH(NOLOCK)
            JOIN inserted AS i
                ON pa.Id = i.IdParcela
        WHERE pa.IdSituacaoParcela IN (1,2)

        IF @@ERROR <> 0
            BEGIN
                RAISERROR('Erro ao atualizar a situacao da parcela para PAGA.', 16, 1)
                ROLLBACK TRANSACTION
                RETURN
            END
  END
GO

-------------------------------------------------------------------------------------------------------------------
--TESTES

--Reserva válida  
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 8,
                                                    @IdTurma = 3,
                                                    @DataReserva = @DataInicio

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Tentativa de reserva em turma sem vaga 
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 10,
                                                @IdTurma = 3,
                                                @DataReserva = @DataInicio

    
    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao
ROLLBACK TRANSACTION

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_ReservarMatricula]  @IdAluno = 12,
                                                    @IdTurma = 3,
                                                    @DataReserva = @DataInicio


    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Tentativa de reserva duplicada (mesmo aluno e mesma turma)
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_ReservarMatricula] @IdAluno = 4,
                                                    @IdTurma = 2,
                                                    @DataReserva = @DataInicio

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Tentativa de reserva com aluno ou turma inativos.

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_ReservarMatricula]    @IdAluno = 13,
                                                    @IdTurma = 3,
                                                    @DataReserva = @DataInicio

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Efetivação válida, conferindo se as 12 parcelas foram geradas com números, valores e vencimentos corretos.
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 2 

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

    SELECT TOP 12 pa.IdMatricula,
                    pa.IdSituacaoParcela,
                    pa.Numero,
                    pa.ValorOriginal, 
                    pa.DataVencimento
        FROM Parcela AS pa
        ORDER BY pa.IdMatricula DESC, pa.Numero ASC, pa.DataVencimento ASC

ROLLBACK TRANSACTION

--Tentativas de efetivar uma reserva já EFETIVADA.

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 3 

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

    SELECT TOP 12 pa.IdMatricula,
                    pa.IdSituacaoParcela,
                    pa.Numero,
                    pa.ValorOriginal, 
                    pa.DataVencimento
        FROM Parcela AS pa
        ORDER BY pa.IdMatricula DESC, pa.Numero ASC, pa.DataVencimento ASC

ROLLBACK TRANSACTION

--Tentativas de efetivar uma reserva com a data de expiração vencida.

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = 10

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

    SELECT TOP 12 pa.IdMatricula,
                    pa.IdSituacaoParcela,
                    pa.Numero,
                    pa.ValorOriginal, 
                    pa.DataVencimento
        FROM Parcela AS pa
        ORDER BY pa.IdMatricula DESC, pa.Numero ASC, pa.DataVencimento ASC

ROLLBACK TRANSACTION

--Pagamento dentro do vencimento 

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 4,
                                                    @DataPagamento = @DataInicio,
                                                    @ValorPago = 500.00

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Pagamento em atraso (com juros).
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 25,
                                                    @DataPagamento = @DataInicio,
                                                    @ValorPago = 800.00

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

-- Tentativa de pagamento de parcela já PAGA.
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 1,
                                                    @DataPagamento = @DataInicio,
                                                    @ValorPago = 800.00

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Teste do Trigger, comprovando que a parcela passou para PAGA após o pagamento
BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    SELECT  pa.Id,
            sp.Descricao
        FROM [dbo].[Parcela] AS pa
            JOIN [dbo].[SituacaoParcela] AS sp
                ON pa.IdSituacaoParcela = sp.Id
        WHERE pa.Id = 7

    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 7,
                                                    @DataPagamento = @DataInicio,
                                                    @ValorPago = 500.00

    SELECT  pa.Id,
            sp.Descricao
        FROM [dbo].[Parcela] AS pa
            JOIN [dbo].[SituacaoParcela] AS sp
                ON pa.IdSituacaoParcela = sp.Id
        WHERE pa.Id = 7

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Teste do Trigger com várias linhas: uma única instrução INSERT registrando pagamentos de mais
--de uma parcela, comprovando que todas foram atualizadas.

    BEGIN TRANSACTION
        DBCC FREEPROCCACHE
        DBCC DROPCLEANBUFFERS

        DECLARE @DataInicio DATETIME = GETDATE(),
                @Retorno INT,
                @Retorno2 INT

        SELECT  pa.Id,
                sp.Descricao
            FROM [dbo].[Parcela] AS pa
                JOIN [dbo].[SituacaoParcela] AS sp
                    ON pa.IdSituacaoParcela = sp.Id
            WHERE pa.Id IN (16,30)

        EXEC @Retorno = [dbo].[SP_RegistrarPagamento]   @IdParcela = 16,
                                                        @DataPagamento = @DataInicio,
                                                        @ValorPago = 500.00

        EXEC @Retorno2 = [dbo].[SP_RegistrarPagamento]  @IdParcela = 30,
                                                        @DataPagamento = @DataInicio,
                                                        @ValorPago = 800.00
        SELECT  pa.Id,
                sp.Descricao
            FROM [dbo].[Parcela] AS pa
                JOIN [dbo].[SituacaoParcela] AS sp
                    ON pa.IdSituacaoParcela = sp.Id
            WHERE pa.Id IN (16,30)

        SELECT  @Retorno as Retorno,
                @Retorno2 as Retorno2,
                DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

    ROLLBACK TRANSACTION

--Tentativa de cancelamento com parcelas pendentes e sem negociação QUITADA (deve ser bloqueada).

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 3

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Cancelamento permitido com negociação QUITADA 

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 2

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION


--Cancelamento permitido de matrícula sem parcelas pendentes

BEGIN TRANSACTION
    DBCC FREEPROCCACHE
    DBCC DROPCLEANBUFFERS

    DECLARE @DataInicio DATETIME = GETDATE(),
            @Retorno INT

    EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4

    SELECT  @Retorno as Retorno,
            DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) as TempoExecucao

ROLLBACK TRANSACTION

--Chamada VIEW VW_MatriculasAtivas.sql

SELECT * FROM [dbo].[VW_MatriculasAtivas]

--Chamada VIEW VW_SituacaoFinanceira.sql

SELECT * FROM [dbo].[VW_SituacaoFinanceira]

--Chamada FUNCTION FNC_DisponibilidadeDeVagas.sql

SELECT [dbo].[FNC_DisponibilidadeDeVagas](3) as VagasDisponiveis

--Chamada FUNCTION FNC_ValorAtualizadoParcela.sql

SELECT [dbo].[FNC_ValorAtualizadoParcela](3, '2026-09-30') as ValorParcelaAtualizado
