USE [Escola];
GO

SELECT DB_NAME() AS BancoAtual;
GO

/*================================================== 
    3.1 Views ( 1 e 2)
====================================================*/

-- VIEW 01

IF OBJECT_ID(N'[dbo].[VW_MatriculasAtivas]',N'V') IS NOT NULL
    DROP VIEW [dbo].[VW_MatriculasAtivas]
GO

CREATE VIEW [dbo].[VW_MatriculasAtivas]
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Listar Matriculas Ativas,identificando aluno, curso, turma, data da matrícula e situação
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................: SELECT * FROM [dbo].[VW_MatriculasAtivas]
*/
(
    SELECT  al.Nome as NomeAluno,
            al.Cpf as CpfAluno,
            cs.Nome as NomeCurso,
            tm.Codigo as CodigoTurma,
            mt.DataMatricula as DataMatricula,
            sm.Descricao as SituacaoMatricula
        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
            INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON al.Id = mt.IdAluno
            INNER JOIN [dbo].[Turma] AS tm WITH(NOLOCK)
                ON tm.Id = mt.IdTurma
            INNER JOIN [dbo].[Curso] AS cs WITH(NOLOCK)
                ON cs.Id = tm.IdCurso
            INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = mt.IdSituacaoMatricula AND sm.Id = 1
)
GO

-- VIEW 02

IF OBJECT_ID(N'[dbo].[VW_SituacaoFinanceira]',N'V') IS NOT NULL
    DROP VIEW [dbo].[VW_SituacaoFinanceira]
GO

CREATE VIEW [dbo].[VW_SituacaoFinanceira]
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................:  Apresentar uma linha por matrícula, com o aluno, o total de
                                parcelas, as quantidades de parcelas pagas, pendentes e vencidas (RN07) e o valor total ainda
                                pendente
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................: SELECT * FROM [dbo].[VW_SituacaoFinanceira]
*/

(
    SELECT  mt.Id as IdMatricula,
            al.Nome as NomeAluno,
            COUNT(pc.Id) as TotalParcelas,
            SUM(CASE 
                    WHEN sp.Descricao = 'Paga' THEN 1 
                ELSE 0 END) as ParcelasPagas,
            SUM(CASE 
                    WHEN sp.Descricao IN ('Aberta', 'Vencida') THEN 1 
                ELSE 0 END) as ParcelasPendentes,
            SUM(CASE
                    WHEN sp.Descricao = 'Vencida'
                        OR (sp.Descricao = 'Aberta' 
                        AND pc.DataVencimento < CAST(GETDATE() AS DATE))THEN 1 
                ELSE 0 END) as ParcelasVencidas,
            SUM(CASE
                    WHEN sp.Descricao IN ('Aberta', 'Vencida') THEN pc.ValorOriginal
                ELSE 0
            END) as ValorTotalPendente
        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
            INNER JOIN [dbo].[Aluno] AS al WITH(NOLOCK)
                ON al.Id = mt.IdAluno
            LEFT JOIN [dbo].[Parcela] AS pc WITH(NOLOCK)
                ON  pc.IdMatricula = mt.Id
            LEFT JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                ON sp.Id = pc.IdSituacaoParcela
        GROUP BY mt.Id, al.Id, al.Nome
)
GO


/*================================================== 
    3.2 Function ( 1 e 2)
====================================================*/

-- FUNCTION 01

IF OBJECT_ID(N'[dbo].[FNC_DisponibilidadeDeVagas]', N'FN') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_DisponibilidadeDeVagas];
GO

CREATE FUNCTION [dbo].[FNC_DisponibilidadeDeVagas]
(
    @IdTurma INT
)
RETURNS INT
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Retornar as vagas disponiveis da turma conforme a RN02
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................: SELECT [dbo].[FNC_DisponibilidadeDeVagas](1) AS VagasDisponiveis;
    Retornos.................:  0 ou positivo - Quantidade de vagas disponiveis
                               -1 - Parametro informado eh nulo
                               -2 - Turma inexistente ou capacidade nao cadastrada
*/
BEGIN
    -- Valida se a turma foi informada
    IF @IdTurma IS NULL
        RETURN -1;

    -- Declara Variaveis 
    DECLARE @Capacidade INT;
    DECLARE @MatriculasAtivas INT;
    DECLARE @ReservasVigentes INT;
    DECLARE @VagasDisponiveis INT;

    -- Atribui Valor a @Capacidade 
    SELECT @Capacidade = tm.Capacidade
        FROM [dbo].[Turma] AS tm WITH(NOLOCK)
        WHERE @IdTurma = tm.Id;

    -- Valida se a turma existe e possui capacidade cadastrada
    IF @Capacidade IS NULL
        RETURN -2;

    -- Conta as matriculas ativas que ocupam vagas
    SELECT @MatriculasAtivas = COUNT(*)
        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = mt.IdSituacaoMatricula
        WHERE @IdTurma = mt.IdTurma
            AND sm.Descricao = 'Ativa';

    -- Conta somente as reservas que ainda nao expiraram
    SELECT @ReservasVigentes = COUNT(*)
        FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoReserva] AS sr WITH(NOLOCK)
                ON sr.Id = rm.IdSituacaoReserva
        WHERE @IdTurma = rm.IdTurma
            AND sr.Descricao = 'Reservada'
            AND rm.DataExpiracao >= CAST(GETDATE() AS DATE);

    -- Desconta as vagas ocupadas da capacidade da turma
    SET @VagasDisponiveis = @Capacidade - @MatriculasAtivas - @ReservasVigentes;

    -- Impede que a quantidade de vagas seja negativa
    IF @VagasDisponiveis < 0
        SET @VagasDisponiveis = 0;

    RETURN @VagasDisponiveis;
END;
GO


-- FUNCTION 02

IF OBJECT_ID(N'[dbo].[FNC_ValorAtualizadoDaParcela]', N'FN') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_ValorAtualizadoDaParcela];
GO

CREATE FUNCTION [dbo].[FNC_ValorAtualizadoDaParcela]
(
    @IdParcela INT,
    @DataReferencia DATE
)
RETURNS DECIMAL(18,2)
AS

/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Retornar o valor da parcela na data de referencia, com
                               juros simples de 1% por mes de atraso iniciado
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................: 
                                SELECT [dbo].[FNC_ValorAtualizadoDaParcela](pc.Id, '20260711') AS ValorAtualizado
                                   FROM [dbo].[Parcela] AS pc
                                   WHERE pc.IdMatricula = 3 AND pc.Numero = 1;

    Retornos.................: Positivo - Valor original acrescido dos juros, em reais
                               -1 - Parcela ou data de referencia informada eh nula
                               -2 - Parcela inexistente
*/

BEGIN
    -- Valida se a parcela e a data foram informadas
    IF @IdParcela IS NULL OR @DataReferencia IS NULL
        RETURN -1;

    -- Declara Variaveis 
    DECLARE @ValorOriginal DECIMAL(14,2);
    DECLARE @DataVencimento DATE;
    DECLARE @MesesAtraso INT;

    -- Atribui valores as variaveis @ValorOriginal e @DataVencimento
    SELECT @ValorOriginal = pc.ValorOriginal,
           @DataVencimento = pc.DataVencimento
        FROM [dbo].[Parcela] AS pc WITH(NOLOCK)
        WHERE @IdParcela = pc.Id;

    -- Valida se a parcela existe
    IF @ValorOriginal IS NULL
        RETURN -2;

    -- Retorna o valor original quando nao ha atraso
    IF @DataReferencia <= @DataVencimento
        RETURN @ValorOriginal;

    -- Calcula a diferenca entre os meses das duas datas
    SET @MesesAtraso = DATEDIFF(MONTH, @DataVencimento, @DataReferencia);

    -- Conta o periodo mensal iniciado apos o vencimento
    IF DATEADD(MONTH, @MesesAtraso, @DataVencimento) < @DataReferencia
        SET @MesesAtraso = @MesesAtraso + 1;

    -- Aplica juros simples de 1% por mes de atraso iniciado
    RETURN CAST(@ValorOriginal * (1 + @MesesAtraso * 0.01) AS DECIMAL(18,2));
END;
GO


/*================================================== 
    3.3 Stored Procedures (1 a 4)
====================================================*/

-- PROCEDURE 01

IF OBJECT_ID(N'[dbo].[SP_ReservarMatricula]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[SP_ReservarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_ReservarMatricula]
    @IdAluno INT,
    @IdTurma INT
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Validar aluno, turma, duplicidade e vagas conforme RN01 e RN02,
                               registrando uma reserva com prazo de sete dias
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................:
                                DBCC FREEPROCCACHE
                                DBCC DROPCLEANBUFFERS

                                BEGIN TRANSACTION;

                                DECLARE @Retorno INT;
                                DECLARE @Inicio DATETIME = GETDATE();

                                EXEC @Retorno = [dbo].[SP_ReservarMatricula]
                                    @IdAluno = 1,
                                    @IdTurma = 2;

                                SELECT @Retorno AS Retorno,
                                       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

                                ROLLBACK TRANSACTION;

    Retornos.................:  0 - Reserva registrada com sucesso
                               -1 - Aluno ou turma informado eh nulo
                               -2 - Aluno inexistente
                               -3 - Aluno inativo
                               -4 - Turma inexistente
                               -5 - Turma inativa
                               -6 - Aluno ja possui reserva vigente para a turma
                               -7 - Aluno ja possui matricula ativa para a turma
                               -8 - Turma sem vagas disponiveis
                               -9 - Situacao Reservada ou Ativa nao cadastrada
                              -10 - Falha ao registar a Reserva
*/
BEGIN
    -- Valida se o aluno e a turma foram informados.
    IF @IdAluno IS NULL OR @IdTurma IS NULL
        RETURN -1;

    -- Declara Variaveis
    DECLARE @AlunoAtivo BIT;
    DECLARE @TurmaAtiva BIT;
    DECLARE @IdSituacaoReserva TINYINT;
    DECLARE @IdSituacaoMatricula TINYINT;
    DECLARE @DataReserva DATETIME;

    -- Atribui valor a variavel @AlunoAtivo
    SELECT @AlunoAtivo = al.Ativo
        FROM [dbo].[Aluno] AS al WITH(NOLOCK)
        WHERE @IdAluno = al.Id;

    -- Valida se o aluno existe
    IF @AlunoAtivo IS NULL
        RETURN -2;

    -- Valida se o aluno esta ativo
    IF @AlunoAtivo = 0
        RETURN -3;

    -- Atribui valor para @TurmaAtiva
    SELECT @TurmaAtiva = tm.Ativo
        FROM [dbo].[Turma] AS tm WITH(NOLOCK)
        WHERE @IdTurma = tm.Id;

    -- Valida se a turma existe
    IF @TurmaAtiva IS NULL
        RETURN -4;

    -- Valida se a turma esta ativa
    IF @TurmaAtiva = 0
        RETURN -5;

    -- Atribui valor para @IdSituacaoReserva
    SELECT @IdSituacaoReserva = sr.Id
        FROM [dbo].[SituacaoReserva] AS sr WITH(NOLOCK)
        WHERE sr.Descricao = 'Reservada';

    -- Atribui Valor para @IdSituacaoMatricula
    SELECT @IdSituacaoMatricula = sm.Id
        FROM [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
        WHERE sm.Descricao = 'Ativa';

    -- Valida se as situacoes necessarias estao cadastradas
    IF @IdSituacaoReserva IS NULL OR @IdSituacaoMatricula IS NULL
        RETURN -9;

    SET @DataReserva = GETDATE();

    -- Impede outra reserva vigente do aluno na mesma turma
    IF EXISTS (
                    SELECT  TOP 1 1
                        FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
                        WHERE @IdAluno = rm.IdAluno
                            AND @IdTurma = rm.IdTurma
                            AND rm.IdSituacaoReserva = @IdSituacaoReserva
                            AND rm.DataExpiracao >= CAST(@DataReserva AS DATE)
                    )
        RETURN -6;

    -- Impede reserva quando o aluno ja possui matricula ativa na turma
    IF EXISTS (
                    SELECT  TOP 1 1
                        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
                        WHERE @IdAluno = mt.IdAluno
                            AND @IdTurma = mt.IdTurma
                            AND mt.IdSituacaoMatricula = @IdSituacaoMatricula
                    )
        RETURN -7;

    -- Valida se a turma possui pelo menos uma vaga disponivel
    IF [dbo].[FNC_DisponibilidadeDeVagas](@IdTurma) <= 0
        RETURN -8;

    -- Registra a reserva com prazo de sete dias.
    INSERT INTO [dbo].[ReservaMatricula](IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
        VALUES (@IdAluno, @IdTurma, @IdSituacaoReserva, @DataReserva,
                DATEADD(DAY, 7, CAST(@DataReserva AS DATE)));

    -- Verifica se a reserva foi gravada sem erro
    IF @@ERROR <> 0 OR @@ROWCOUNT = 0
        RETURN -10;

    -- informa que a reserva foi registrada com sucesso
    RETURN 0;
END;
GO

-- PROCEDURE 02

IF OBJECT_ID(N'[dbo].[SP_EfetivarMatricula]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[SP_EfetivarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_EfetivarMatricula]
    @IdReservaMatricula INT
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Efetivar uma reserva vigente, criar a matricula ativa e gerar
                               exatamente 12 parcelas conforme RN03 e RN04
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................:
                                DBCC FREEPROCCACHE
                                DBCC DROPCLEANBUFFERS

                                BEGIN TRANSACTION;

                                DECLARE @Retorno INT;
                                DECLARE @Inicio DATETIME = GETDATE();

                                EXEC @Retorno = [dbo].[SP_EfetivarMatricula]
                                    @IdReservaMatricula = 1;

                                SELECT @Retorno AS Retorno,
                                       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

                                SELECT * FROM [dbo].[Matricula] WHERE IdReservaMatricula = 1;
                                SELECT pc.* FROM [dbo].[Parcela] AS pc
                                    INNER JOIN [dbo].[Matricula] AS mt ON mt.Id = pc.IdMatricula
                                    WHERE mt.IdReservaMatricula = 1;

                                ROLLBACK TRANSACTION;

    Retornos.................:  0 - Matricula efetivada com 12 parcelas
                               -1 - Reserva informada eh nula
                               -2 - Reserva inexistente
                               -3 - Reserva nao esta na situacao Reservada
                               -4 - Reserva expirada
                               -5 - Reserva ja possui matricula
                               -6 - Situacoes necessarias nao cadastradas
                               -7 - Curso ou valor da mensalidade invalido
                               -8 - Falha ao registrar a matricula
                               -9 - Falha ao efetivar a reserva
                              -10 - Falha ao gerar as parcelas
*/

BEGIN
    -- Valida se a reserva foi informada
    IF @IdReservaMatricula IS NULL
        RETURN -1;

    -- Declarando as Variaveis 
    DECLARE @IdAluno INT;
    DECLARE @IdTurma INT;
    DECLARE @SituacaoReserva VARCHAR(50);
    DECLARE @DataExpiracao DATE;
    DECLARE @IdSituacaoReserva TINYINT;
    DECLARE @IdSituacaoMatricula TINYINT;
    DECLARE @IdSituacaoParcela TINYINT;
    DECLARE @ValorMensalidade DECIMAL(14,2);
    DECLARE @IdMatricula INT;
    DECLARE @DataMatricula DATETIME = GETDATE();
    DECLARE @PrimeiroVencimento DATE;
    DECLARE @NumeroParcela TINYINT = 1;

    -- Atribuindo valor as Variaveis
    SELECT @IdAluno = rm.IdAluno,
           @IdTurma = rm.IdTurma,
           @SituacaoReserva = sr.Descricao,
           @DataExpiracao = rm.DataExpiracao
        FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoReserva] AS sr WITH(NOLOCK)
                ON sr.Id = rm.IdSituacaoReserva
        WHERE @IdReservaMatricula = rm.Id;

    -- Valida se a reserva existe
    IF @IdAluno IS NULL
        RETURN -2;

    -- Permite efetivar somente uma reserva na situacao Reservada
    IF @SituacaoReserva <> 'Reservada'
        RETURN -3;

    -- Impede a efetivacao depois do prazo final da reserva
    IF @DataExpiracao < CAST(@DataMatricula AS DATE)
        RETURN -4;

    -- Impede outra matricula para a mesma reserva
    IF EXISTS   (
                    SELECT  TOP 1 1
                        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
                        WHERE @IdReservaMatricula = mt.IdReservaMatricula
                )
        RETURN -5;

    -- Atribuindo valor a variavel @IdSituacaoReserva
    SELECT @IdSituacaoReserva = sr.Id
        FROM [dbo].[SituacaoReserva] AS sr WITH(NOLOCK)
        WHERE sr.Descricao = 'Efetivada';

    -- Atribuindo valor a variavel @IdSituacaoMatricula
    SELECT @IdSituacaoMatricula = sm.Id
        FROM [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
        WHERE sm.Descricao = 'Ativa';

    -- Atribuindo valor a variavel @IdSituacaoParcela
    SELECT @IdSituacaoParcela = sp.Id
        FROM [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
        WHERE sp.Descricao = 'Aberta';

    -- Valida se as situacoes necessarias estao cadastradas
    IF @IdSituacaoReserva IS NULL OR @IdSituacaoMatricula IS NULL OR @IdSituacaoParcela IS NULL
        RETURN -6;

    -- Atribuindo valor a variavel @ValorMensalidade
    SELECT @ValorMensalidade = cs.ValorMensalidade
        FROM [dbo].[Turma] AS tm
            INNER JOIN [dbo].[Curso] AS cs
                ON cs.Id = tm.IdCurso
        WHERE @IdTurma = tm.Id;

    -- Valida o valor atual do curso da turma.
    IF @ValorMensalidade IS NULL OR @ValorMensalidade <= 0
        RETURN -7;

    -- Define o dia 10 do mes seguinte como o primeiro vencimento
    SET @PrimeiroVencimento = DATEADD(MONTH, 1,
        DATEFROMPARTS(YEAR(@DataMatricula), MONTH(@DataMatricula), 10));

    BEGIN TRANSACTION;

    -- Registra a matricula com o valor atual da mensalidade
    INSERT INTO [dbo].[Matricula]
        (IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
        VALUES (@IdReservaMatricula, @IdAluno, @IdTurma, @IdSituacaoMatricula,
                @DataMatricula, @ValorMensalidade);

    -- Desfaz a operacao se a matricula nao foi gravada
    IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
    BEGIN
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;

        RETURN -8;
    END;

    -- Registra Id Matricula referente ao dado passado na Proc
    SET @IdMatricula = CAST(SCOPE_IDENTITY() AS INT);

    -- Altera a reserva para Efetivada se ela continua vigente
    UPDATE rm
        SET IdSituacaoReserva = @IdSituacaoReserva
        FROM [dbo].[ReservaMatricula] AS rm WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoReserva] AS sr WITH(NOLOCK)
                ON sr.Id = rm.IdSituacaoReserva
        WHERE @IdReservaMatricula = rm.Id
            AND sr.Descricao = 'Reservada'
            AND rm.DataExpiracao >= CAST(@DataMatricula AS DATE);

    -- Desfaz a matricula se a reserva nao foi atualizada.
    IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
    BEGIN
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;

        RETURN -9;
    END;

    -- Gera 12 parcelas abertas, com vencimentos mensais e o valor da matricula.
    WHILE @NumeroParcela <= 12
    BEGIN
        INSERT INTO [dbo].[Parcela]
            (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
            VALUES (@IdMatricula, @IdSituacaoParcela, @NumeroParcela, @ValorMensalidade,
                    DATEADD(MONTH, @NumeroParcela - 1, @PrimeiroVencimento));

        -- Desfaz todas as etapas se uma parcela nao foi gravada.
        IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
        BEGIN
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            RETURN -10;
        END;

        SET @NumeroParcela = @NumeroParcela + 1;
    END;

    -- Confirma as gravacoes e informa o sucesso.
    COMMIT TRANSACTION;

    RETURN 0;
END;
GO

-- PROCEDURE 03

IF OBJECT_ID(N'[dbo].[SP_RegistrarPagamento]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[SP_RegistrarPagamento];
GO

CREATE PROCEDURE [dbo].[SP_RegistrarPagamento]
    @IdParcela INT,
    @DataPagamento DATETIME,
    @ValorPago DECIMAL(14,2)
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Validar a parcela e o valor atualizado antes de registrar o
                               pagamento conforme RN05 e RN06. A trigger altera a parcela para paga
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................:

                                DBCC FREEPROCCACHE
                                DBCC DROPCLEANBUFFERS

                                BEGIN TRANSACTION;

                                DECLARE @Retorno INT;
                                DECLARE @Inicio DATETIME = GETDATE();
                                DECLARE @IdParcela INT;
                                DECLARE @ValorPago DECIMAL(14,2);
                                DECLARE @DataPagamento DATETIME = GETDATE();

                                SELECT @IdParcela = pc.Id
                                    FROM [dbo].[Parcela] AS pc
                                    WHERE pc.IdMatricula = 3 AND pc.Numero = 1;

                                SET @ValorPago = [dbo].[FNC_ValorAtualizadoDaParcela]
                                    (@IdParcela, CAST(@DataPagamento AS DATE));

                                EXEC @Retorno = [dbo].[SP_RegistrarPagamento]
                                    @IdParcela = @IdParcela,
                                    @DataPagamento = @DataPagamento,
                                    @ValorPago = @ValorPago;

                                SELECT @Retorno AS Retorno,
                                       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

                                ROLLBACK TRANSACTION;

    Retornos.................:  0 - Pagamento registrado com sucesso
                               -1 - Parcela, data ou valor informado eh nulo
                               -2 - Parcela inexistente
                               -3 - Parcela nao esta Aberta nem Vencida
                               -4 - Valor pago deve ser positivo
                               -5 - Nao foi possivel calcular o valor atualizado
                               -6 - Valor pago inferior ao valor atualizado
                               -7 - Falha ao registrar o pagamento
*/

BEGIN
    -- Valida se a parcela, a data e o valor foram informados
    IF @IdParcela IS NULL OR @DataPagamento IS NULL OR @ValorPago IS NULL
        RETURN -1;

    -- declarando as variaveis da procedure
    DECLARE @SituacaoParcela VARCHAR(50);
    DECLARE @ValorAtualizado DECIMAL(18,2);

    SELECT @SituacaoParcela = sp.Descricao
        FROM [dbo].[Parcela] AS pc WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                ON sp.Id = pc.IdSituacaoParcela
        WHERE @IdParcela = pc.Id;

    -- Valida se a parcela existe
    IF @SituacaoParcela IS NULL
        RETURN -2;

    -- Permite pagamento somente de parcela Aberta ou Vencida
    IF @SituacaoParcela NOT IN ('Aberta', 'Vencida')
        RETURN -3;

    -- Valida se o valor pago eh positivo
    IF @ValorPago <= 0
        RETURN -4;

    SET @ValorAtualizado = [dbo].[FNC_ValorAtualizadoDaParcela]
        (@IdParcela, CAST(@DataPagamento AS DATE));

    -- Valida o resultado do calculo da parcela
    IF @ValorAtualizado IS NULL OR @ValorAtualizado <= 0
        RETURN -5;

    -- Impede pagamento inferior ao valor original acrescido dos juros
    IF @ValorPago < @ValorAtualizado
        RETURN -6;

    -- Registra o pagamento; a trigger atualiza a situacao da parcela
    INSERT INTO [dbo].[Pagamento]
        (IdParcela, DataPagamento, ValorPago)
        VALUES (@IdParcela, @DataPagamento, @ValorPago);

    -- Verifica se o pagamento foi gravado sem erro
    IF @@ERROR <> 0 OR @@ROWCOUNT = 0
        RETURN -7;

    RETURN 0;
END;
GO


-- PROCEDURE 04

IF OBJECT_ID(N'[dbo].[SP_CancelarMatricula]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[SP_CancelarMatricula];
GO

CREATE PROCEDURE [dbo].[SP_CancelarMatricula]
    @IdMatricula INT
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Cancelar uma matricula ativa quando nao houver parcelas pendentes
                               ou existir uma negociacao Quitada, preservando o historico (RN08)
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................:
                                BEGIN TRANSACTION;

                                DECLARE @Retorno INT;
                                DECLARE @Inicio DATETIME = GETDATE();

                                EXEC @Retorno = [dbo].[SP_CancelarMatricula]
                                    @IdMatricula = 2;

                                SELECT @Retorno AS Retorno,
                                       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

                                SELECT * FROM [dbo].[Matricula] WHERE Id = 2;

                                IF @@TRANCOUNT > 0
                                    ROLLBACK TRANSACTION;

    Retornos.................:  0 - Matricula cancelada com sucesso
                               -1 - Matricula informada eh nula
                               -2 - Matricula inexistente
                               -3 - Matricula nao esta Ativa
                               -4 - Situacao Cancelada nao cadastrada
                               -5 - Parcelas pendentes sem negociacao Quitada
                               -6 - Falha ao cancelar a matricula
*/

BEGIN
    -- Valida se a matricula foi informada
    IF @IdMatricula IS NULL
        RETURN -1;

    DECLARE @SituacaoMatricula VARCHAR(50);
    DECLARE @IdSituacaoCancelada TINYINT;

    SELECT @SituacaoMatricula = sm.Descricao
        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = mt.IdSituacaoMatricula
        WHERE @IdMatricula = mt.Id;

    -- Valida se a matricula existe
    IF @SituacaoMatricula IS NULL
        RETURN -2;

    -- Permite cancelar somente uma matricula ativa
    IF @SituacaoMatricula <> 'Ativa'
        RETURN -3;

    SELECT @IdSituacaoCancelada = sm.Id
        FROM [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
        WHERE sm.Descricao = 'Cancelada';

    -- Valida se a situacao Cancelada esta cadastrada
    IF @IdSituacaoCancelada IS NULL
        RETURN -4;

    -- Bloqueia parcelas pendentes quando nao existe negociacao Quitada
    IF EXISTS       (
                        SELECT  TOP 1 1
                            FROM [dbo].[Parcela] AS pc WITH(NOLOCK)
                                INNER JOIN [dbo].[SituacaoParcela] AS sp WITH(NOLOCK)
                                    ON sp.Id = pc.IdSituacaoParcela
                            WHERE @IdMatricula = pc.IdMatricula
                                AND sp.Descricao IN ('Aberta', 'Vencida')
                    )
        AND NOT EXISTS 
                    (
                        SELECT  TOP 1 1
                            FROM [dbo].[Negociacao] AS ng WITH(NOLOCK)
                                INNER JOIN [dbo].[SituacaoNegociacao] AS sn WITH(NOLOCK)
                                    ON sn.Id = ng.IdSituacaoNegociacao
                            WHERE @IdMatricula = ng.IdMatricula
                                AND sn.Descricao = 'Quitada'
                    )
        RETURN -5;

    -- Altera somente a situacao da matricula, preservando o historico
    UPDATE mt
        SET IdSituacaoMatricula = @IdSituacaoCancelada
        FROM [dbo].[Matricula] AS mt WITH(NOLOCK)
            INNER JOIN [dbo].[SituacaoMatricula] AS sm WITH(NOLOCK)
                ON sm.Id = mt.IdSituacaoMatricula
        WHERE @IdMatricula = mt.Id
            AND sm.Descricao = 'Ativa';

    -- Verifica se a matricula foi cancelada sem erro
    IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
        RETURN -6;

    RETURN 0;
END;
GO

/*================================================== 
    4. Trigger ( 1 )
====================================================*/

-- TRIGGER 01

IF OBJECT_ID(N'[dbo].[TRG_AtualizarParcelaAposPagamento]', N'TR') IS NOT NULL
    DROP TRIGGER [dbo].[TRG_AtualizarParcelaAposPagamento];
GO

CREATE TRIGGER [dbo].[TRG_AtualizarParcelaAposPagamento]
ON [dbo].[Pagamento]
AFTER INSERT
AS
/*
    Documentacao
    Arquivo Fonte............: 089-50-gabriel-merces.sql
    Objetivo.................: Alterar para Paga todas as parcelas dos pagamentos registrados,
                               utilizando inserted mesmo quando o INSERT possui varias linhas.
    Autor....................: Gabriel Merces
    Data.....................: 30/09/2026
    Ex.......................:
                                BEGIN TRANSACTION;

                                DECLARE @DataPagamento DATETIME = GETDATE();

                                INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
                                    SELECT pc.Id, @DataPagamento,
                                           [dbo].[FNC_ValorAtualizadoDaParcela]
                                               (pc.Id, CAST(@DataPagamento AS DATE))
                                        FROM [dbo].[Parcela] AS pc
                                            INNER JOIN [dbo].[SituacaoParcela] AS sp
                                                ON sp.Id = pc.IdSituacaoParcela
                                        WHERE pc.IdMatricula = 3 AND pc.Numero IN (1, 2)
                                            AND sp.Descricao IN ('Aberta', 'Vencida');

                                SELECT pc.Id, pc.Numero, sp.Descricao AS SituacaoParcela
                                    FROM [dbo].[Parcela] AS pc
                                        INNER JOIN [dbo].[SituacaoParcela] AS sp
                                            ON sp.Id = pc.IdSituacaoParcela
                                    WHERE pc.IdMatricula = 3 AND pc.Numero IN (1, 2);

                                    ROLLBACK TRANSACTION;

    Retornos.................: Nao possui codigo de retorno nem result set.
                               RAISERROR se a situacao Paga nao existir ou a atualizacao falhar.
*/
BEGIN
    -- Encerra quando o INSERT nao gravou nenhuma linha.
    IF @@ROWCOUNT = 0
        RETURN;

    DECLARE @IdSituacaoPaga TINYINT;

    SELECT @IdSituacaoPaga = sp.Id
        FROM [dbo].[SituacaoParcela] AS sp 
        WHERE sp.Descricao = 'Paga';

    -- Impede o pagamento quando a situacao Paga nao esta cadastrada.
    IF @IdSituacaoPaga IS NULL
    BEGIN
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        RAISERROR(N'Situacao Paga nao cadastrada.', 16, 1);
        RETURN;
    END;

    -- Atualiza todas as parcelas relacionadas aos pagamentos inseridos.
    UPDATE pc
        SET IdSituacaoParcela = @IdSituacaoPaga
        FROM [dbo].[Parcela] AS pc 
            INNER JOIN inserted AS ins
                ON ins.IdParcela = pc.Id;

    -- Desfaz o pagamento se as parcelas nao foram atualizadas.
    IF @@ERROR <> 0 OR @@ROWCOUNT = 0
    BEGIN
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        RAISERROR(N'Falha ao atualizar a situacao das parcelas.', 16, 2);
        RETURN;
    END;
END;
GO

/*================================================== 
    6. Testes
====================================================*/

-- TESTES PROCEDURE 1

-- TESTE 01: Reserva valida ( 0 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_ReservarMatricula]
    @IdAluno = 1,
    @IdTurma = 2;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

SELECT * FROM [dbo].[ReservaMatricula]
    WHERE IdAluno = 1 AND IdTurma = 2;

ROLLBACK TRANSACTION;
GO

-- TESTE 02: Aluno inativo ( -3 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_ReservarMatricula]
    @IdAluno = 13,
    @IdTurma = 1;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

ROLLBACK TRANSACTION;
GO

-- TESTE 03: Turma inativa ( -5 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_ReservarMatricula]
    @IdAluno = 1,
    @IdTurma = 4;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

ROLLBACK TRANSACTION;
GO

-- TESTE 04: Aluno ja possui reserva vigente para a turma ( -6 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_ReservarMatricula]
    @IdAluno = 2,
    @IdTurma = 1;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

ROLLBACK TRANSACTION;
GO

-- TESTE 05: Aluno ou turma informado eh nulo ( -1 ) 

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_ReservarMatricula]
    @IdAluno = null,
    @IdTurma = 1;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

ROLLBACK TRANSACTION;
GO

-- TESTE 06: Aluno inexistente ( -2 ) 

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_ReservarMatricula]
    @IdAluno = 14,
    @IdTurma = 1;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

ROLLBACK TRANSACTION;
GO

-- TESTE 07: Turma inexistente ( -4 ) 

-- TESTE 08: Aluno ja possui matricula ativa para a turma ( -7 )  

-- TESTE: Turma sem vagas disponiveis ( -8 )

-- NAO EXISTE ESSE CENARIO NA MASSA: NENHUMA TURMA ESTA LOTADA.


-- TESTE: Situacao Reservada ou Ativa nao cadastrada ( -9 )

-- NAO EXISTE ESSE CENARIO NA MASSA: AS SITUACOES ESTAO CADASTRADAS.


-- TESTES PROCEDURE 2

-- TESTE 09: Efetivacao valida e conferencia das 12 parcelas ( 0 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_EfetivarMatricula]
    @IdReservaMatricula = 1;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

SELECT COUNT(pc.Id) AS TotalParcelas,
       COUNT(DISTINCT pc.Numero) AS NumerosDistintos,
       MIN(pc.Numero) AS PrimeiraParcela,
       MAX(pc.Numero) AS UltimaParcela
    FROM [dbo].[Parcela] AS pc
        INNER JOIN [dbo].[Matricula] AS mt ON mt.Id = pc.IdMatricula
    WHERE mt.IdReservaMatricula = 1;

ROLLBACK TRANSACTION;
GO

-- TESTE 10: Reserva ja EFETIVADA ( -3 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_EfetivarMatricula]
    @IdReservaMatricula = 6;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

ROLLBACK TRANSACTION;
GO

-- TESTE 11: Reserva com data de expiracao vencida ( -4 ) 

-- TESTE 12: Reserva informada eh nula ( -1 ) 

-- TESTES PROCEDURE 3 E TRIGGER

-- TESTE 13: Pagamento dentro do vencimento e trigger alterando para PAGA ( 0 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();
DECLARE @IdParcela INT;
DECLARE @DataPagamento DATETIME = '20260710';
DECLARE @ValorPago DECIMAL(14,2) = 600.00;

SELECT @IdParcela = pc.Id
    FROM [dbo].[Parcela] AS pc
    WHERE pc.IdMatricula = 3 AND pc.Numero = 1;

EXEC @Retorno = [dbo].[SP_RegistrarPagamento]
    @IdParcela = @IdParcela,
    @DataPagamento = @DataPagamento,
    @ValorPago = @ValorPago;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

SELECT * FROM [dbo].[Pagamento] WHERE IdParcela = @IdParcela;

SELECT pc.Id, pc.Numero, sp.Descricao AS SituacaoParcela
    FROM [dbo].[Parcela] AS pc
        INNER JOIN [dbo].[SituacaoParcela] AS sp
            ON sp.Id = pc.IdSituacaoParcela
    WHERE pc.Id = @IdParcela;

ROLLBACK TRANSACTION;
GO

-- TESTE 14: Pagamento em atraso com juros ( 0 ) 

-- TESTE 15: Tentativa de pagamento de parcela ja PAGA ( -3 ) 

-- TESTE: Trigger com varias linhas em um unico INSERT.

-- NAO TESTADO: EXIGE QUE EU MANIPULE O BANCO E NAS REGRAS DIZEM PARA NAO FAZER O MESMO, POR ISSO NAO FOI TESTADO

-- TESTES PROCEDURE 4

-- TESTE 16: Cancelamento bloqueado com parcelas pendentes e sem negociacao QUITADA ( -5 )

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

BEGIN TRANSACTION;

DECLARE @Retorno INT;
DECLARE @Inicio DATETIME = GETDATE();

EXEC @Retorno = [dbo].[SP_CancelarMatricula]
    @IdMatricula = 1;

SELECT @Retorno AS Retorno,
       DATEDIFF(MILLISECOND, @Inicio, GETDATE()) AS TempoExecucao;

SELECT * FROM [dbo].[Matricula] WHERE Id = 1;

ROLLBACK TRANSACTION;
GO

-- TESTE 17: Cancelamento permitido com negociacao QUITADA ( 0 ) 

-- TESTE 18: Cancelamento permitido sem parcelas pendentes ( 0 ) 

-- TESTES VIEWS

-- TESTE 19: Consultas as duas Views.

SELECT * FROM [dbo].[VW_MatriculasAtivas];
SELECT * FROM [dbo].[VW_SituacaoFinanceira];
GO

-- TESTES FUNCTIONS

-- TESTE 20: Chamadas das duas Functions.

SELECT [dbo].[FNC_DisponibilidadeDeVagas](1) AS VagasDisponiveis;

SELECT [dbo].[FNC_ValorAtualizadoDaParcela](pc.Id, '20260711') AS ValorAtualizado
    FROM [dbo].[Parcela] AS pc
    WHERE pc.IdMatricula = 3 AND pc.Numero = 1;
GO
