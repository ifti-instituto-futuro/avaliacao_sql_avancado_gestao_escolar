/*
Documentacao
Arquivo Fonte............:  02_dados_iniciais_escola_sqlserver_padrao.sql
Objetivo.................:  Carregar a massa inicial de dados da avaliacao de Banco de Dados Avancado (Gestao Escolar)
Autor....................:  Instituto Futuro
Data.....................:  26/09/2026
Schema...................:  dbo
Observacoes..............:
                        Executar apos 01_estrutura_escola_sqlserver_padrao.sql
                        Versao reescrita de 02_dados_iniciais_escola_sqlserver.sql conforme o padrao da empresa
                        Os Ids das tabelas de dominio sao fixos pela ordem da carga no inicio deste script
                        Massa preparada para a prova entre 29/09/2026 e 01/10/2026
                        As reservas vigentes expiram em 02/10/2026 (data da reserva + 7 dias)
                        Para restaurar a massa, executar novamente o script 01 e depois este script
*/

USE Escola;
GO

SET NOCOUNT ON;
GO

--------------------------------------------------------------------------------
-- TABELAS DE DOMINIO
--------------------------------------------------------------------------------

-- Inserir situacoes da reserva
INSERT INTO [dbo].[SituacaoReserva] (Descricao)
    VALUES  ('Reservada'),
            ('Efetivada'),
            ('Cancelada'),
            ('Expirada');
GO

-- Inserir situacoes da matricula
INSERT INTO [dbo].[SituacaoMatricula] (Descricao)
    VALUES  ('Ativa'),
            ('Cancelada'),
            ('Concluida');
GO

-- Inserir situacoes da parcela
INSERT INTO [dbo].[SituacaoParcela] (Descricao)
    VALUES  ('Aberta'),
            ('Vencida'),
            ('Paga'),
            ('Cancelada');
GO

-- Inserir situacoes da negociacao
INSERT INTO [dbo].[SituacaoNegociacao] (Descricao)
    VALUES  ('Aberta'),
            ('Quitada'),
            ('Cancelada');
GO

--------------------------------------------------------------------------------
-- CADASTROS BASICOS
--------------------------------------------------------------------------------

-- Inserir cursos (a mensalidade de ADS foi reajustada de 500,00 para 520,00 depois das matriculas de junho)
INSERT INTO [dbo].[Curso] (Nome, ValorMensalidade, Ativo)
    VALUES  ('Ciencia da Computacao', 600.00, 1),
            ('Sistemas de Informacao', 550.00, 1),
            ('Analise e Desenvolvimento de Sistemas', 520.00, 1);
GO

-- Inserir turmas, sendo a ultima inativa
INSERT INTO [dbo].[Turma] (IdCurso, Codigo, AnoLetivo, Semestre, Capacidade, Ativo)
    VALUES  (1, 'CC-2026.2-A', 2026, 2, 5, 1),
            (2, 'SI-2026.2-A', 2026, 2, 4, 1),
            (3, 'ADS-2026.2-A', 2026, 2, 3, 1),
            (1, 'CC-2025.2-H', 2025, 2, 5, 0);
GO

-- Inserir alunos, sendo o ultimo inativo
INSERT INTO [dbo].[Aluno] (Nome, Cpf, Email, Ativo)
    VALUES  ('Ana Lima', '10000000001', 'ana.lima@exemplo.edu.br', 1),
            ('Bruno Alves', '10000000002', 'bruno.alves@exemplo.edu.br', 1),
            ('Carla Souza', '10000000003', 'carla.souza@exemplo.edu.br', 1),
            ('Diego Santos', '10000000004', 'diego.santos@exemplo.edu.br', 1),
            ('Elisa Rocha', '10000000005', 'elisa.rocha@exemplo.edu.br', 1),
            ('Fabio Melo', '10000000006', 'fabio.melo@exemplo.edu.br', 1),
            ('Gabriela Reis', '10000000007', 'gabriela.reis@exemplo.edu.br', 1),
            ('Henrique Luz', '10000000008', 'henrique.luz@exemplo.edu.br', 1),
            ('Isabela Costa', '10000000009', 'isabela.costa@exemplo.edu.br', 1),
            ('Joao Nunes', '10000000010', 'joao.nunes@exemplo.edu.br', 1),
            ('Karen Freitas', '10000000011', 'karen.freitas@exemplo.edu.br', 1),
            ('Lucas Moura', '10000000012', 'lucas.moura@exemplo.edu.br', 1),
            ('Mariana Dias', '10000000013', 'mariana.dias@exemplo.edu.br', 0);
GO

--------------------------------------------------------------------------------
-- RESERVAS E MATRICULAS
--------------------------------------------------------------------------------

-- Inserir reservas para os cenarios de vagas, expiracao e efetivacao
INSERT INTO [dbo].[ReservaMatricula] (IdAluno, IdTurma, IdSituacaoReserva, DataReserva, DataExpiracao)
    VALUES  (1, 1, 1, '2026-09-25T09:00:00', '2026-10-02'),
            (2, 1, 1, '2026-09-25T10:00:00', '2026-10-02'),
            (3, 1, 4, '2026-08-15T09:00:00', '2026-08-22'),
            (4, 2, 1, '2026-09-25T11:00:00', '2026-10-02'),
            (5, 2, 3, '2026-09-04T09:00:00', '2026-09-11'),
            (6, 3, 2, '2026-06-01T09:00:00', '2026-06-08'),
            (7, 3, 2, '2026-06-02T09:00:00', '2026-06-09'),
            (8, 1, 2, '2026-06-03T09:00:00', '2026-06-10'),
            (12, 2, 2, '2026-06-04T09:00:00', '2026-06-11'),
            (9, 3, 1, '2026-09-10T09:00:00', '2026-09-17');
GO

-- Inserir matriculas ativas das reservas efetivadas
INSERT INTO [dbo].[Matricula] (IdReservaMatricula, IdAluno, IdTurma, IdSituacaoMatricula, DataMatricula, ValorMensalidade)
    VALUES  (6, 6, 3, 1, '2026-06-05T10:00:00', 500.00),
            (7, 7, 3, 1, '2026-06-06T10:00:00', 500.00),
            (8, 8, 1, 1, '2026-06-07T10:00:00', 600.00),
            (9, 12, 2, 1, '2026-06-08T10:00:00', 550.00);
GO

--------------------------------------------------------------------------------
-- FINANCEIRO
--------------------------------------------------------------------------------

-- Gerar 12 parcelas para cada matricula, com a 1a vencendo no dia 10 do mes seguinte a matricula
WITH Numeros AS (
    SELECT  1 AS Numero
    UNION ALL
    SELECT  Numero + 1
        FROM Numeros
        WHERE Numero < 12
)
INSERT INTO [dbo].[Parcela] (IdMatricula, IdSituacaoParcela, Numero, ValorOriginal, DataVencimento)
    SELECT  m.Id,
            CASE
                WHEN m.Id = 1 AND n.Numero <= 2 THEN 3
                WHEN m.Id = 2 AND n.Numero = 1 THEN 3
                WHEN m.Id = 4 THEN 3
                WHEN v.DataVencimento < CAST(GETDATE() AS DATE) THEN 2
                ELSE 1
            END,
            n.Numero,
            m.ValorMensalidade,
            v.DataVencimento
        FROM [dbo].[Matricula] m WITH(NOLOCK)
            CROSS JOIN Numeros n
            CROSS APPLY (SELECT DATEADD(MONTH, n.Numero, DATEFROMPARTS(YEAR(m.DataMatricula), MONTH(m.DataMatricula), 10)) AS DataVencimento) v
        ORDER BY m.Id, n.Numero
    OPTION (MAXRECURSION 12);
GO

-- Inserir pagamentos ja realizados
INSERT INTO [dbo].[Pagamento] (IdParcela, DataPagamento, ValorPago)
    SELECT  p.Id,
            CASE
                WHEN p.IdMatricula = 4 THEN CAST('2026-06-20T10:00:00' AS DATETIME2(3))
                ELSE DATEADD(DAY, -2, CAST(p.DataVencimento AS DATETIME2(3)))
            END,
            p.ValorOriginal
        FROM [dbo].[Parcela] p WITH(NOLOCK)
        WHERE p.IdSituacaoParcela = 3;
GO

-- Inserir negociacoes para os cenarios de cancelamento
INSERT INTO [dbo].[Negociacao] (IdMatricula, IdSituacaoNegociacao, DataNegociacao, ValorNegociado)
    SELECT  p.IdMatricula,
            CASE WHEN p.IdMatricula = 1 THEN 1 ELSE 2 END,
            CASE WHEN p.IdMatricula = 1 THEN CAST('2026-09-20T10:00:00' AS DATETIME2(3)) ELSE CAST('2026-09-21T10:00:00' AS DATETIME2(3)) END,
            SUM(p.ValorOriginal)
        FROM [dbo].[Parcela] p WITH(NOLOCK)
        WHERE p.IdMatricula IN (1, 2)
            AND p.IdSituacaoParcela IN (1, 2)
        GROUP BY p.IdMatricula;
GO

--------------------------------------------------------------------------------
-- CONFERENCIA DA CARGA
--------------------------------------------------------------------------------

-- Conferir a quantidade de registros por tabela
SELECT  'Alunos' AS Entidade,
        COUNT(*) AS Quantidade
    FROM [dbo].[Aluno] WITH(NOLOCK)
UNION ALL
SELECT  'Cursos',
        COUNT(*)
    FROM [dbo].[Curso] WITH(NOLOCK)
UNION ALL
SELECT  'Turmas',
        COUNT(*)
    FROM [dbo].[Turma] WITH(NOLOCK)
UNION ALL
SELECT  'Reservas',
        COUNT(*)
    FROM [dbo].[ReservaMatricula] WITH(NOLOCK)
UNION ALL
SELECT  'Matriculas',
        COUNT(*)
    FROM [dbo].[Matricula] WITH(NOLOCK)
UNION ALL
SELECT  'Parcelas',
        COUNT(*)
    FROM [dbo].[Parcela] WITH(NOLOCK)
UNION ALL
SELECT  'Pagamentos',
        COUNT(*)
    FROM [dbo].[Pagamento] WITH(NOLOCK)
UNION ALL
SELECT  'Negociacoes',
        COUNT(*)
    FROM [dbo].[Negociacao] WITH(NOLOCK);
GO
