USE Escola;
GO

-- VIEW 01 — Matrículas ativas: identificar aluno, curso, turma, data e situação da matrícula.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]')
                    AND TYPE = 'V'
          )
    DROP VIEW [dbo].[VW_MatriculasAtivas];
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Retornar por meio da view as matrículas ativas identificando: aluno, curso, turma, data e situação da matrícula
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: SELECT * FROM [dbo].[VW_MatriculasAtivas];  
    */
    SELECT  al.Nome As Aluno,
            cu.Nome As Curso,
            tu.Codigo As Turma,
            ma.DataMatricula,
            sm.Descricao As SituacaoMatricula
        FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
            INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON al.Id = ma.IdAluno AND al.Ativo = 1
            INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                ON tu.Id = ma.IdTurma AND tu.Ativo = 1
            INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
                ON cu.Id = tu.IdCurso AND cu.Ativo = 1
            INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = ma.IdSituacaoMatricula
        WHERE sm.Descricao = 'ATIVA';
GO

-- VIEW 02 — Situação financeira: por matrícula, apresentar aluno, total de parcelas, parcelas pagas, pendentes, vencidas e valor total pendente.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]')
                    AND TYPE = 'V'
          )
    DROP VIEW [dbo].[VW_SituacaoFinanceira];
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Retornar por meio da view a situação financeira apresentando: matrícula, aluno, total de parcelas, parcelas pagas, pendentes, vencidas e valor total pendente
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: SELECT * FROM [dbo].[VW_SituacaoFinanceira];  
    */
    WITH CTe_SituacaoFinanceira AS (   
                                       SELECT  ma.Id As Matricula,
                                               al.Nome As Aluno,
                                               COUNT(pa.IdMatricula) As TotalParcelas,
                                               COUNT(
                                                      CASE WHEN pa.IdSituacaoParcela = 3 THEN 1
                                                      END
                                                    ) As ParcelasPagas,
                                               COUNT(
                                                      CASE WHEN pa.IdSituacaoParcela = 1 AND pa.DataVencimento > CAST(GETDATE() AS DATE) THEN 1
                                                      END
                                                    ) As ParcelasPendentes,
                                               COUNT(
                                                      CASE WHEN pa.IdSituacaoParcela = 2 OR (pa.DataVencimento < CAST(GETDATE() AS DATE) AND pa.IdSituacaoParcela = 1) THEN 1
                                                      END
                                                    ) As ParcelasVencidas,
                                               pa.ValorOriginal
                                           FROM [dbo].[Matricula] AS ma WITH(NOLOCK)
                                               INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                                                   ON al.Id = ma.IdAluno AND al.Ativo = 1
                                               INNER JOIN [dbo].[Parcela] AS pa WITH(NOLOCK)  
                                                   ON pa.IdMatricula = ma.Id
                                           WHERE ma.IdSituacaoMatricula = 1
                                           GROUP BY ma.Id, al.Nome, pa.ValorOriginal
                                    )
        SELECT Matricula,
               Aluno,
               TotalParcelas,
               ParcelasPagas,
               ParcelasPendentes,
               ParcelasVencidas,
               ValorOriginal * (ParcelasPendentes + ParcelasVencidas) As ValorTotalPendente
            FROM CTe_SituacaoFinanceira;      
GO

-- FUNCTION 01 — Disponibilidade de vagas: receber uma turma e retornar a quantidade de vagas disponíveis conforme RN02.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[FNC_DisponibilidadeDeVagas]')
                    AND TYPE = 'FN'
          )
    DROP FUNCTION [dbo].[FNC_DisponibilidadeDeVagas];
GO

CREATE FUNCTION [dbo].[FNC_DisponibilidadeDeVagas] (@IdTurma INT)
    RETURNS SMALLINT
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Função escalar para retornar a quantidade de vagas disponivel em uma turma.
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: DBCC FREEPROCCACHE 
                                   DBCC DROPCLEANBUFFERS

                                   DECLARE @DataInicio DATETIME = GETDATE();
                                           
                                   SELECT  [dbo].[FNC_DisponibilidadeDeVagas] (1) As RetornoFuncao,
                                           DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) As TempoExecucao;

        Retorno..................: @QuantidadeVagasDisponivel - Sucesso
                                   -1 - Erro: Não é permitido que os parâmetros sejam nulos
                                   -2 - Erro: A Turma informada não existe
    */
    BEGIN
        -- Validar se o parâmetro informado é nulo
        IF @IdTurma IS NULL 
            RETURN -1

        -- Validar se a turma existe
        IF NOT EXISTS (
                         SELECT  TOP 1 1
                             FROM [dbo].[Turma] WITH(NOLOCK)
                             WHERE Id = @IdTurma
                      )
            RETURN -2

        -- Declarar variável para armazenar a quantidade de vagas disponível e data de hoje para ser usado na validação do case when
         DECLARE @DataHoje DATE = CAST(GETDATE() AS DATE),
                 @VagasDisponivel INT;

        -- Consultar vagas disponíveis 
        WITH CTe_VagasDisponivel AS (
                                       SELECT  tu.Capacidade,
                                               COUNT(CASE WHEN rm.IdSituacaoReserva = 1 AND rm.DataExpiracao > @DataHoje THEN 1
                                                     END) As MatriculasReservadas,
                                               COUNT(CASE WHEN ma.IdSituacaoMatricula = 1 THEN 1
                                                     END) As MatriculasAtivas
                                           FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                                               LEFT JOIN [dbo].[Matricula] AS ma WITH(NOLOCK)   
                                                   ON ma.IdReservaMatricula = rm.Id
                                               LEFT JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                                                   ON tu.Id = rm.IdTurma AND tu.Ativo = 1
                                           WHERE tu.Id = @IdTurma
                                           GROUP BY tu.Codigo, tu.Capacidade
                                    )
            SELECT  @VagasDisponivel = Capacidade - (MatriculasReservadas + MatriculasAtivas) -- Calculo para o valor final da capacidade
                FROM CTe_VagasDisponivel;

        RETURN @VagasDisponivel;
    END
GO

-- FUNCTION 02 — Valor atualizado da parcela: receber uma parcela e uma data de referência e retornar o valor atualizado conforme RN06 e RN07.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[FNC_ValorAtualizadoParcela]')
                    AND TYPE = 'FN'
          )
    DROP FUNCTION [dbo].[FNC_ValorAtualizadoParcela];
GO

CREATE FUNCTION [dbo].[FNC_ValorAtualizadoParcela] (@IdParcela INT, @DataReferencia DATE)
    RETURNS DECIMAL(14,2)
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Função escalar para retornar o valor atualizado de uma parcela a partir de uma data referência.
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: DBCC FREEPROCCACHE 
                                   DBCC DROPCLEANBUFFERS

                                   DECLARE @DataInicio DATETIME = GETDATE();
                                           
                                   SELECT  [dbo].[FNC_ValorAtualizadoParcela] (3, '30/09/2026') As RetornoFuncao,
                                           DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) As TempoExecucao;

        Retorno..................: @ValorParcelaAtualizado - Sucesso
                                   -1 - Erro: Não é permitido que os parâmetros sejam nulos
                                   -2 - Erro: A Parcela informada não existe
                                   -3 - Erro: A data informada não pode ser menor que o vencimento da parcela informada
    */
    BEGIN
        -- Validar se existe alguma entrada nula
        IF @IdParcela IS NULL OR @DataReferencia IS NULL
            RETURN -1

        -- Validar se a parcela existe
        IF NOT EXISTS (
                         SELECT  TOP 1 1   
                             FROM [dbo].[Parcela] WITH(NOLOCK)
                             WHERE Id = @IdParcela
                      )
            RETURN -2

        -- Validar se a data é válida em relacão à parcela
        IF @DataReferencia < (
                                SELECT  DataVencimento   
                                    FROM [dbo].[Parcela] WITH(NOLOCK)
                                    WHERE Id = @IdParcela
                             )
            RETURN -3
        
        -- Armazenar o mês de vencimento da parcela
        DECLARE @MesVencimentoParcela DATE = (
                                                SELECT  DataVencimento   
                                                    FROM [dbo].[Parcela] WITH(NOLOCK)
                                                    WHERE Id = @IdParcela
                                             );

        -- Armazenar a diferença entre os meses
        DECLARE @DiferencaMeses INT = (SELECT DATEDIFF(MONTH, @MesVencimentoParcela, @DataReferencia));

        -- Validar se o dia da DataRefenrencia é menor que 11 para armazenar o mês exato de juros
        IF DAY(@DataReferencia) < 11
            SET @DiferencaMeses = @DiferencaMeses - 1;

        -- Validar vencimento do mesmo mês
        IF @DiferencaMeses = 0
            AND (
                     SELECT  IdSituacaoParcela = 2
                         FROM [dbo].[Parcela] WITH(NOLOCK)
                         WHERE Id = @IdParcela
                ) = 2
            AND MONTH(@DataReferencia) = MONTH(GETDATE())
            SET @DiferencaMeses = 1;
        
        -- Armazenar o valor original da parcela
        DECLARE @ValorOriginal DECIMAL(14,2) = (
                                                  SELECT ValorOriginal 
                                                      FROM [dbo].[Parcela] WITH(NOLOCK) 
                                                      WHERE Id = @IdParcela
                                               );

        -- Declarar variável para armazenar o juros
        DECLARE @ValorJuros DECIMAL(14,2);

        -- Descobrir valor do juros
        SELECT  @ValorJuros = (@ValorOriginal * 1 * @DiferencaMeses) / 100

        -- Declarar o valor atualizado
        DECLARE @ValorParcelaAtualizado DECIMAL(14,2) = @ValorJuros + @ValorOriginal;

        RETURN @ValorParcelaAtualizado
    END
GO

-- PROCEDURE 01 — Reservar matrícula: validar RN01/RN02, registrar a reserva e retornar código de sucesso/erro.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarReservaMatricula]')
                    AND TYPE = 'P'
          )
    DROP PROCEDURE [dbo].[SP_RegistrarReservaMatricula];
GO

CREATE PROCEDURE [dbo].[SP_RegistrarReservaMatricula]
    @IdAluno INT,
    @IdTurma INT
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Realizar o cadastro de uma reserva de matrícula
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION 

                                       DBCC FREEPROCCACHE 
                                       DBCC DROPCLEANBUFFERS

                                       DECLARE @DataInicio DATETIME = GETDATE(),
                                               @Retorno INT,
                                               @IdBaseReseed INT = (SELECT TOP 1 Id FROM [dbo].[ReservaMatricula] ORDER BY Id DESC);
                                   
                                       IF @IdBaseReseed IS NULL
                                           SET @IdBaseReseed = 0;
                                   
                                       EXEC @Retorno = [dbo].[SP_RegistrarReservaMatricula] @IdAluno = 3,
                                                                                            @IdTurma = 1;
                                                                                            
                                       SELECT  @Retorno As Retorno,
                                               DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) As TempoExecucao;

                                   ROLLBACK TRANSACTION

                                   DBCC CHECKIDENT('ReservaMatricula', RESEED, @IdBaseReseed);

        Retorno..................: @IdNovaReserva - Sucesso
                                   -1 - Erro: Não é permitido que os parâmetros sejam nulos
                                   -2 - Erro: Aluno não cadastrado
                                   -3 - Erro: Aluno não está ativo
                                   -4 - Erro: Turma não cadastrada
                                   -5 - Erro: Turma não está ativa
                                   -6 - Erro: Aluno já tem uma RESERVA para a Turma selecionada
                                   -7 - Erro: Aluno já está ativo na Turma 
                                   -8 - Erro: A Tuma já atingiu a capacidade máxima
                                   -9 - Erro: Falha na inserção da Reserva da Matrícula
    */
    BEGIN
        -- Validar se existe algum campo nulo
        IF @IdAluno IS NULL OR @IdTurma IS NULL
            RETURN -1

        -- Validar se o Aluno existe
        IF NOT EXISTS (
                         SELECT  TOP 1 1
                             FROM [dbo].[Aluno] WITH(NOLOCK)
                             WHERE Id = @IdAluno
                      )
            RETURN -2

        -- Validar se o Aluno está ativo
        IF 1 <> (
                    SELECT  TOP 1 Ativo
                        FROM [dbo].[Aluno] WITH(NOLOCK)
                        WHERE Id = @IdAluno
                )
            RETURN -3

        -- Validar se a Turma existe
        IF NOT EXISTS (
                         SELECT  TOP 1 1
                             FROM [dbo].[Turma] WITH(NOLOCK)
                             WHERE Id = @IdTurma
                      )
            RETURN -4

        -- Validar se a Turma está ativa
        IF 1 <> (
                    SELECT  TOP 1 Ativo
                        FROM [dbo].[Turma] WITH(NOLOCK)
                        WHERE Id = @IdTurma
                )
            RETURN -5

        -- Validar se o aluno não tem outra reserva RESERVADA para a mesma turma.
        IF EXISTS (
                    SELECT  TOP 1 1 IdAluno
                        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                        WHERE IdAluno = @IdAluno
                            AND (IdSituacaoReserva = 1 AND IdTurma = @IdTurma)
                   )
            RETURN -6

        -- Validar se o aluno não tem outra matrícula ATIVA para a mesma turma.
        IF EXISTS (
                    SELECT  TOP 1 1 IdAluno
                        FROM [dbo].[Matricula] WITH(NOLOCK)
                        WHERE IdAluno = @IdAluno
                            AND (IdSituacaoMatricula = 1 AND IdTurma = @IdTurma) 
                  )
            RETURN -7

        -- Validar a capacidade da turma
        IF (SELECT [dbo].[FNC_DisponibilidadeDeVagas](@IdTurma)) = 0
            RETURN -8

        -- Declarar data de hoje
        DECLARE @DataHoje DATE = CAST(GETDATE() AS DATE);

        -- Declarar data de eexpiração 
        DECLARE @DataExpiracao DATE = DATEADD(DAY, 7, @Datahoje);

        -- Inserir a reserva de matricula
        BEGIN TRANSACTION

            INSERT INTO [dbo].[ReservaMatricula] (IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
                VALUES (@IdAluno, @IdTurma, 1, @DataHoje, @DataExpiracao);

            -- Validar se houve algum erro
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -9
                END

        COMMIT TRANSACTION

        -- Armazenar o Id da nova Reserva de matricula
        DECLARE @IdNovaReserva INT = SCOPE_IDENTITY();

        RETURN @IdNovaReserva
    END
GO

-- PROCEDURE 02 — Efetivar matrícula: validar a reserva, criar matrícula, alterar a reserva e gerar as 12 parcelas. Deve possuir controle transacional.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]')
                    AND TYPE = 'P'
          )
    DROP PROCEDURE [dbo].[SP_EfetivarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
    @IdReservaMatricula INT
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Efetivar o cadastro de uma Matrícula e criar as Parcelas referentes a ela.
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION 

                                       DBCC FREEPROCCACHE 
                                       DBCC DROPCLEANBUFFERS

                                       DECLARE @DataInicio DATETIME = GETDATE(),
                                               @Retorno INT,
                                               @IdBaseReseedMatricula INT = (SELECT TOP 1 Id FROM [dbo].[Matricula] ORDER BY Id DESC),
                                               @IdBaseReseedParcela INT = (SELECT TOP 1 Id FROM [dbo].[Parcela] ORDER BY Id DESC);
                                               
                                       DECLARE @IdReservaMatricula INT = 1;
                                   
                                       IF @IdBaseReseedMatricula IS NULL
                                           SET @IdBaseReseedMatricula = 0;
                                       
                                       IF @IdBaseReseedParcela IS NULL
                                           SET @IdBaseReseedParcela = 0;

                                       SELECT  TOP 1 *
                                           FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                                           WHERE Id = @IdReservaMatricula;
                                   
                                       EXEC @Retorno = [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = @IdReservaMatricula;

                                       SELECT  TOP 1 *
                                           FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                                           WHERE Id =@IdReservaMatricula;
                                       
                                       SELECT  TOP 1 *
                                           FROM [dbo].[Matricula] WITH(NOLOCK)
                                           WHERE IdReservaMatricula = @IdReservaMatricula;
                                           
                                      SELECT  TOP 12 *
                                          FROM [dbo].[Parcela] WITH(NOLOCK)
                                          WHERE IdMatricula = (SELECT TOP 1 Id FROM [dbo].[Matricula] ORDER BY Id DESC);

                                       SELECT  @Retorno As Retorno,
                                               DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) As TempoExecucao;

                                   ROLLBACK TRANSACTION

                                   DBCC CHECKIDENT('Matricula', RESEED, @IdBaseReseedMatricula);
                                   DBCC CHECKIDENT('Parcela', RESEED, @IdBaseReseedParcela);

        Retorno..................:  0 - Sucesso
                                   -1 - Erro: Não é permitido que os parâmetros sejam nulos
                                   -2 - Erro: Reserva não cadastrada
                                   -3 - Erro: Reserva expirada
                                   -4 - Erro: A situação da reserva é diferente de RESERVADA
                                   -5 - Erro: Falha atualização da ReservaMatricula
                                   -6 - Erro: Falha na criação da Matricula
                                   -7 - Erro: Falha na criação da Parcela
    */
    BEGIN
        -- Armazenar data de hoje
        DECLARE @DataHoje DATE = CAST(GETDATE() AS DATE);

        -- Validar se o existe parâmetro nulo
        IF @IdReservaMatricula IS NULL
            RETURN -1

        -- Validar se a Reserva existe
        IF NOT EXISTS (
                           SELECT  TOP 1 1
                               FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                               WHERE Id = @IdReservaMatricula
                      )
            RETURN -2

        -- Validar se a reserva não expirou 
        IF @DataHoje > (
                            SELECT  TOP 1 DataExpiracao
                                FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                                WHERE Id = @IdReservaMatricula
                       )
            RETURN -3 

        -- Validar se a situação da reserva
        IF 1 <> (
                     SELECT  TOP 1 IdSituacaoReserva
                                FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
                                WHERE Id = @IdReservaMatricula
                )
            RETURN -4

         -- Atualizar a reserva de matrícula
         BEGIN TRANSACTION
            
            UPDATE [dbo].[ReservaMatricula] 
                SET IdSituacaoReserva = 2
                WHERE Id = @IdReservaMatricula 
            
            -- Valida se houve algum erro na atualização
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -5
                END
         
         COMMIT TRANSACTION

         -- Armazenar o ValorMensalidade
         DECLARE @ValorMensalidade DECIMAL(14,2) = ( 
                                                        SELECT  TOP 1 cu.ValorMensalidade
                                                            FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                                                                INNER JOIN [dbo].[Turma] AS tu WITH(NOLOCK)
                                                                    ON tu.Id = rm.IdTurma
                                                                INNER JOIN [dbo].[Curso] AS cu WITH(NOLOCK)
                                                                    ON cu.Id = tu.IdCurso
                                                            WHERE rm.Id = @IdReservaMatricula 
                                                   );

         -- Criar uma Matricula
         BEGIN TRANSACTION            
            
            INSERT INTO [dbo].[Matricula] (IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
                SELECT  1,
                        rm.IdAluno,
                        rm.IdTurma,
                        1,
                        GETDATE(),
                        @ValorMensalidade
                    FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                    WHERE rm.Id = 1;
            
            -- Validar se houve algum erro na criação
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -6
                END

         COMMIT TRANSACTION
         
         -- Armazenar o id criado da matricula
         DECLARE @IdNovaMatricula INT = SCOPE_IDENTITY();

         -- Criar as parcelas
         BEGIN TRANSACTION
            
            -- Contador de meses
            DECLARE @Contador TINYINT = 1;

            WHILE @Contador <= 12
                BEGIN 
                    INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
                       VALUES (
                                @IdNovaMatricula,
                                1,
                                @Contador,
                                @ValorMensalidade,
                                DATEADD(MONTH, @Contador, DATEFROMPARTS(YEAR(@DataHoje), MONTH(@DataHoje), 10))
                              );  

                    -- Validar se houve erro na criação das parcelas
                    IF @@ERROR <> 0
                        BEGIN
                            ROLLBACK TRANSACTION
                            RETURN -7
                        END
                    
                    -- Incrementa contador
                    SET @Contador = @Contador + 1;
                END

            -- Validar se houve erro na criação das parcelas
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -7
                END

         COMMIT TRANSACTION

        RETURN 0
    END
GO

-- PROCEDURE 03 — Registrar pagamento: validar a parcela e o valor, calcular o valor atualizado e inserir o pagamento. 
-- A atualização da situação da parcela será responsabilidade do Trigger obrigatório.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]')
                    AND TYPE = 'P'
          )
    DROP PROCEDURE [dbo].[SP_RegistrarPagamento];
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
    @IdParcela INT,
    @ValorPago DECIMAL(14,2)
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Realizar o pagamento de um Parcela;
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION 

                                       DBCC FREEPROCCACHE 
                                       DBCC DROPCLEANBUFFERS

                                       DECLARE @DataInicio DATETIME = GETDATE(),
                                               @Retorno INT,
                                               @IdBaseReseedPagamento INT = (SELECT TOP 1 Id FROM [dbo].[Pagamento] ORDER BY Id DESC);
                                       
                                       IF @IdBaseReseedPagamento IS NULL
                                           SET @IdBaseReseedPagamento = 0;
                                   
                                       EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
                                                                                     @ValorPago = 1000.00;
                                       
                                       SELECT  TOP 1 *
                                           FROM [dbo].[Pagamento] WITH(NOLOCK)
                                           WHERE IdParcela = 3;

                                       SELECT  @Retorno As Retorno,
                                               DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) As TempoExecucao;

                                   ROLLBACK TRANSACTION

                                   DBCC CHECKIDENT('Pagamento', RESEED, @IdBaseReseedPagamento);

        Retorno..................:  0 - Sucesso
                                   -1 - Erro: Não é permitido que os parâmetros sejam nulos
                                   -2 - Erro: Parcela não cadastrada
                                   -3 - Erro: A situação da parcela é diferente de ABERTA ou VENCIDA
                                   -4 - Erro: A Parcela já foi paga
                                   -5 - Erro: Valor insuficiente para pagamento
                                   -6 - Erro: Falha no registro do Pagamento
    */
    BEGIN
        -- Validar parâmetro nulos
        IF @IdParcela IS NULL
            RETURN -1

        -- Validar se a parcela existe
        IF NOT EXISTS (
                           SELECT  TOP 1 1
                               FROM [dbo].[Parcela] WITH(NOLOCK)
                               WHERE Id = @IdParcela
                      )
            RETURN -2 

        -- Validar a situação dela
        IF (
                SELECT  IdSituacaoParcela
                    FROM [dbo].[Parcela] WITH (NOLOCK)
                    WHERE Id = @IdParcela
           ) NOT IN (1,2)
            RETURN -3

        -- Validar se a Parcela já foi paga
        IF (
                SELECT  IdSituacaoParcela
                    FROM [dbo].[Parcela] WITH (NOLOCK)
                    WHERE Id = @IdParcela
           ) = 3
            RETURN -4

        -- Armazenar a data de hoje
        DECLARE @DataHoje DATE = CAST(GETDATE() AS DATE);

        -- Cria variável para armazenar o valor a ser pago
        DECLARE @ValorParaPagamento DECIMAL(14,2);

        -- Armazena o valor original para pagamento
        SET @ValorParaPagamento = (
                                    SELECT  TOP 1 ValorOriginal
                                        FROM [dbo].[Parcela] WITH(NOLOCK)
                                        WHERE Id = @IdParcela
                                  );

        -- Validar se a parcela está vencida
        IF @DataHoje > (
                            SELECT  DataVencimento
                                FROM [dbo].[Parcela] WITH(NOLOCK)
                                WHERE Id = @IdParcela
                       )
            SET @ValorParaPagamento = (SELECT [dbo].[FNC_ValorAtualizadoParcela](@IdParcela, @DataHoje));         

        -- Valida se o valor pago é suficiente para o pagamento 
        IF @ValorPago < @ValorParaPagamento
            RETURN -5

        -- Inserir Pagamento
        BEGIN TRANSACTION
            
            INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
                VALUES (@IdParcela, GETDATE(), @ValorParaPagamento);

            -- Valida se hove algum erro
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -6
                END

        COMMIT TRANSACTION
        
        RETURN 0
    END
GO

-- PROCEDURE 04 — Cancelar matrícula: aplicar RN08 e alterar a situação para CANCELADA quando permitido.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[SP_CancelarMatricula]')
                    AND TYPE = 'P'
          )
    DROP PROCEDURE [dbo].[SP_CancelarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
    @IdMatricula INT
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Realizar o cancelamento de uma Matricula;
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
        Ex.......................: BEGIN TRANSACTION 

                                       DBCC FREEPROCCACHE 
                                       DBCC DROPCLEANBUFFERS

                                       DECLARE @DataInicio DATETIME = GETDATE(),
                                               @Retorno INT;                                               
                                       
                                       IF @IdBaseReseedPagamento IS NULL
                                           SET @IdBaseReseedPagamento = 0;
                                   
                                       EXEC @Retorno = [dbo].[SP_CancelarMatricula] @IdMatricula = 4;

                                       SELECT  *
                                           FROM [dbo].[Parcela] WITH (NOLOCK)
                                           WHERE IdMatricula = 4;
                                       
                                       SELECT  *
                                           FROM [dbo].[Matricula] WITH(NOLOCK)
                                           WHERE Id = 4;
                                       
                                       SELECT  @Retorno As Retorno,
                                               DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) As TempoExecucao;

                                   ROLLBACK TRANSACTION

        Retorno..................:  0 - Sucesso
                                   -1 - Erro: Não é permitido que os parâmetros sejam nulos
                                   -2 - Erro: Matricula não cadastrada
                                   -3 - Erro: Cancelamento anulado por existir parcelas vencidas
                                   -4 - Erro: Cancelamento anulado por existir negociações em aberto
                                   -5 - Erro: Erro no cancelamento das Parcelas
                                   -6 - Erro: Erro no cancelamento da Matricula
    */
    BEGIN
        -- Validar parâmetro nulos
        IF @IdMatricula IS NULL
            RETURN -1

        -- Validar se a matricula está ativa
        IF NOT EXISTS (
                           SELECT  TOP 1 1
                               FROM [dbo].[Matricula] WITH(NOLOCK)
                               WHERE Id = @IdMatricula
                      )
            RETURN -2
        
        -- Validar status das parcelas
        IF EXISTS (
                       SELECT TOP 1 1
                           FROM [dbo].[Parcela] WITH(NOLOCK)
                           WHERE IdMatricula = @IdMatricula
                             AND IdSituacaoParcela = 2
                  )
            RETURN -3
        
        -- Armazenar a data de hoje
        DECLARE @DataHoje DATE = CAST(GETDATE() AS DATE);

        -- Valida se existe uma negociação em aberto com data vencimento 
       IF EXISTS (
                    SELECT  TOP 1 1
                        FROM [dbo].[Parcela] 
                        WHERE IdMatricula = @IdMatricula
                            AND (IdSituacaoParcela = 1 AND @DataHoje > DataVencimento)
                 )
            RETURN -3

        -- Validar negociação
        IF EXISTS (
                       SELECT TOP 1 1
                           FROM [dbo].[Negociacao] WITH(NOLOCK)
                           WHERE IdMatricula = @IdMatricula
                             AND IdSituacaoNegociacao NOT IN (2, 3)
                  )
            RETURN -4 

        -- Cancelar as parcelas em aberto 
        BEGIN TRANSACTION
            UPDATE Parcela
                SET IdSituacaoParcela = 4
                WHERE IdMatricula = @IdMatricula
                    AND IdSituacaoParcela = 1

            -- Valida se hove algum erro
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -5
                END

        COMMIT TRANSACTION

        -- Cancelamento de Matricula
        BEGIN TRANSACTION
            UPDATE Matricula
                SET IdSituacaoMatricula = 2
                WHERE Id = @IdMatricula

            -- Valida se hove algum erro
            IF @@ERROR <> 0
                BEGIN
                    ROLLBACK TRANSACTION
                    RETURN -6
                END

        COMMIT TRANSACTION
        
        RETURN 0
    END
GO

-- TRIGGER 01 — Atualização de parcela após pagamento: após INSERT em Pagamento, atualizar para PAGA as parcelas correspondentes aos pagamentos registrados.

IF EXISTS (
             SELECT  1
                 FROM [dbo].[sysobjects]
                 WHERE Id = OBJECT_ID(N'[dbo].[TRG_AtualizacaoPagamento]')
                    AND TYPE = 'TR'
          )
    DROP TRIGGER [dbo].[TRG_AtualizacaoPagamento];
GO

CREATE TRIGGER [dbo].[TRG_AtualizacaoPagamento]
    ON [dbo].[Pagamento]
    AFTER INSERT
    AS
    /*
        Documentacao
        Arquivo Fonte............: 106-48-gabriel-felix.sql
        Objetivo.................: Realizar a atualização da situação de uma Parcela para Paga;
        Autor....................: Gabriel Felix
        Data.....................: 30/09/2026
    */
    BEGIN
        BEGIN TRANSACTION

            UPDATE pa
                SET pa.IdSituacaoParcela = 3
                FROM inserted AS it
                    INNER JOIN [dbo].[Parcela] AS pa
                        ON pa.Id = it.IdParcela
                WHERE pa.Id = it.IdParcela;
            
            -- Valida se hove algum erro
            IF @@ERROR <> 0
                BEGIN
                    RAISERROR('Falha na atualização da Parcela', 1, 1)
                    ROLLBACK TRANSACTION
                    RETURN
                END

        COMMIT TRANSACTION
    END
GO

/* ===================== Teste ===================== */

-- Reserva válida e tentativa de reserva sem vaga ou duplicada.

BEGIN TRANSACTION 

    DECLARE @IdBaseReseed INT = (SELECT TOP 1 Id FROM [dbo].[ReservaMatricula] ORDER BY Id DESC);
                                   
    IF @IdBaseReseed IS NULL
        SET @IdBaseReseed = 0;

    -- Cadastrao com sucesso                                 
    EXEC [dbo].[SP_RegistrarReservaMatricula] @IdAluno = 3,
                                              @IdTurma = 1;

    SELECT  *
        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
        WHERE Id = SCOPE_IDENTITY();                                                                                        

    -- Cadastro com falha
    EXEC [dbo].[SP_RegistrarReservaMatricula] @IdAluno = 99,
                                              @IdTurma = 1;

    SELECT  *
        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
        WHERE Id = SCOPE_IDENTITY();                                                                                            

ROLLBACK TRANSACTION
DBCC CHECKIDENT('ReservaMatricula', RESEED, @IdBaseReseed);

-- Efetivação válida e conferência das 12 parcelas.

BEGIN TRANSACTION 

    DECLARE @IdBaseReseedMatricula INT = (SELECT TOP 1 Id FROM [dbo].[Matricula] ORDER BY Id DESC),
            @IdBaseReseedParcela INT = (SELECT TOP 1 Id FROM [dbo].[Parcela] ORDER BY Id DESC);
                                               
    DECLARE @IdReservaMatricula INT = 1;
                                   
    IF @IdBaseReseedMatricula IS NULL
        SET @IdBaseReseedMatricula = 0;
                                       
    IF @IdBaseReseedParcela IS NULL
        SET @IdBaseReseedParcela = 0;

    SELECT  TOP 1 *
        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
        WHERE Id = @IdReservaMatricula;
                                   
    EXEC [dbo].[SP_EfetivarMatricula] @IdReservaMatricula = @IdReservaMatricula;

    SELECT  TOP 1 *
        FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
        WHERE Id =@IdReservaMatricula;
                                       
    SELECT  TOP 1 *
        FROM [dbo].[Matricula] WITH(NOLOCK)
        WHERE IdReservaMatricula = @IdReservaMatricula;
                                           
    SELECT  TOP 12 *
        FROM [dbo].[Parcela] WITH(NOLOCK)
        WHERE IdMatricula = (SELECT TOP 1 Id FROM [dbo].[Matricula] ORDER BY Id DESC);

ROLLBACK TRANSACTION
DBCC CHECKIDENT('Matricula', RESEED, @IdBaseReseedMatricula);
DBCC CHECKIDENT('Parcela', RESEED, @IdBaseReseedParcela);

-- Pagamento dentro do vencimento e pagamento em atraso.

BEGIN TRANSACTION 

    DECLARE @IdBaseReseedPagamento INT = (SELECT TOP 1 Id FROM [dbo].[Pagamento] ORDER BY Id DESC);
                                       
    IF @IdBaseReseedPagamento IS NULL
        SET @IdBaseReseedPagamento = 0;
       
    -- Pagamento no vencimento
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
                                       @ValorPago = 1000.00;
                                       
    SELECT  TOP 1 *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        WHERE IdParcela = 3;
    
    -- Pagamento fora do vencimento
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 4,
                                       @ValorPago = 1000.00;
                                       
    SELECT  TOP 1 *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        WHERE IdParcela = 4;

ROLLBACK TRANSACTION
DBCC CHECKIDENT('Pagamento', RESEED, @IdBaseReseedPagamento);

-- Tentativa de pagamento de parcela já paga
BEGIN TRANSACTION 

    DECLARE @Retorno INT,
            @IdBaseReseedPagamento1 INT = (SELECT TOP 1 Id FROM [dbo].[Pagamento] ORDER BY Id DESC);
                                       
    IF @IdBaseReseedPagamento1 IS NULL
        SET @IdBaseReseedPagamento1 = 0;
       
    -- Pagamento já quitado
    EXEC @Retorno = [dbo].[SP_RegistrarPagamento] @IdParcela = 1,
                                                  @ValorPago = 1000.00;
                                       
    SELECT  TOP 1 *
        FROM [dbo].[Pagamento] WITH(NOLOCK)
        WHERE IdParcela = 3;
    

    SELECT  @Retorno As Retorno;

ROLLBACK TRANSACTION
DBCC CHECKIDENT('Pagamento', RESEED, @IdBaseReseedPagamento1);

-- Teste do Trigger comprovando alteração da parcela para PAGA.

BEGIN TRANSACTION 

    DECLARE @IdBaseReseedPagamento2 INT = (SELECT TOP 1 Id FROM [dbo].[Pagamento] ORDER BY Id DESC);
                                       
    IF @IdBaseReseedPagamento2 IS NULL
        SET @IdBaseReseedPagamento2 = 0;
    
    -- Parcela sem atualização
    SELECT  *
        FROM [dbo].[Parcela]
        WHERE Id = 3;

    -- Pagamento da parcela em aberto
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
                                       @ValorPago = 1000.00;
    -- Parcela atualizada                                 
    SELECT  *
        FROM [dbo].[Parcela]
        WHERE Id = 3;    

ROLLBACK TRANSACTION
DBCC CHECKIDENT('Pagamento', RESEED, @IdBaseReseedPagamento2);

-- Teste multi-row do Trigger, inserindo pagamentos para mais de uma parcela em uma única instrução.

BEGIN TRANSACTION 

    DECLARE @IdBaseReseedPagamento3 INT = (SELECT TOP 1 Id FROM [dbo].[Pagamento] ORDER BY Id DESC);
                                       
    IF @IdBaseReseedPagamento3 IS NULL
        SET @IdBaseReseedPagamento3 = 0;
    
    -- Parcela sem atualização
    SELECT  *
        FROM [dbo].[Parcela]
        WHERE Id BETWEEN 3 AND 6;

    -- Pagamento da parcela em aberto
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 3,
                                                  @ValorPago = 1000.00;
    
    -- Pagamento da parcela em aberto
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 4,
                                                  @ValorPago = 1000.00;
    
    -- Pagamento da parcela em aberto
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 5,
                                                  @ValorPago = 1000.00;
    
    -- Pagamento da parcela em aberto
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 6,
                                                  @ValorPago = 1000.00;

    -- Parcela atualizada                                 
    SELECT  *
        FROM [dbo].[Parcela]
        WHERE Id BETWEEN 3 AND 6;    

ROLLBACK TRANSACTION
DBCC CHECKIDENT('Pagamento', RESEED, @IdBaseReseedPagamento3);

-- Tentativa de cancelamento com pendências e sem negociação quitada.

BEGIN TRANSACTION                                       
    
    DECLARE @Retorno1 INT;

    -- Tentativa de cancelamento
    EXEC @Retorno1 = [dbo].[SP_CancelarMatricula] @IdMatricula = 1;

    SELECT @Retorno1 As Retono;

    SELECT  *
        FROM [dbo].[Parcela] WITH (NOLOCK)
        WHERE IdMatricula = 1;
                                       
    SELECT  *
        FROM [dbo].[Matricula] WITH(NOLOCK)
        WHERE Id = 1;

ROLLBACK TRANSACTION

-- Cancelamento permitido com negociação QUITADA

BEGIN TRANSACTION                                       
    
    DECLARE @Retorno2 INT;

    -- Tentativa de cancelamento - Erro
    EXEC @Retorno2 = [dbo].[SP_CancelarMatricula] @IdMatricula = 2;

    -- Pagamento de faturas em aberto
    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 14,
                                       @ValorPago = 1000.00;

    EXEC [dbo].[SP_RegistrarPagamento] @IdParcela = 15,
                                       @ValorPago = 1000.00; 

    -- Tentativa de cancelamento - Sucesso
    EXEC @Retorno2 = [dbo].[SP_CancelarMatricula] @IdMatricula = 2;

    SELECT  *
        FROM [dbo].[Parcela] WITH (NOLOCK)
        WHERE IdMatricula = 2;
          
    SELECT  *
        FROM [dbo].[Matricula] WITH(NOLOCK)
        WHERE Id = 2;

    SELECT  *
        FROM [dbo].[Negociacao] WITH(NOLOCK)
        WHERE IdMatricula = 2;

    SELECT @Retorno2 As Retono;

ROLLBACK TRANSACTION

-- Consultas às duas Views e chamadas das duas Functions.

-- View 01:  
    SELECT * FROM [dbo].[VW_MatriculasAtivas];  

-- View 02:
    SELECT * FROM [dbo].[VW_SituacaoFinanceira];

-- Function 01:
    SELECT  [dbo].[FNC_DisponibilidadeDeVagas] (1) As RetornoFuncao

-- Function 02: 
    SELECT  [dbo].[FNC_ValorAtualizadoParcela] (3, '30/09/2026') As RetornoFuncao
