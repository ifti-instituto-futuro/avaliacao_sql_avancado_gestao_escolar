/*
    BANCO DE DADOS AVANÇADO - AVALIAÇÃO 09/2026
    CENÁRIO: GESTÃO ESCOLAR
    ARQUIVO: 02_dados_iniciais_escola_sqlserver.sql

    Executar após 01_estrutura_escola_sqlserver.sql.
*/

SET NOCOUNT ON;
GO

INSERT dbo.Curso (Nome, ValorMensalidade, Ativo) VALUES
('Ciência da Computação', 600.00, 1),
('Sistemas de Informação', 550.00, 1),
('Análise e Desenvolvimento de Sistemas', 500.00, 1);
GO

INSERT dbo.Turma (IdCurso, Codigo, AnoLetivo, Semestre, Capacidade, Ativo) VALUES
(1, 'CC-2026.2-A', 2026, 2, 5, 1),
(2, 'SI-2026.2-A', 2026, 2, 4, 1),
(3, 'ADS-2026.2-A', 2026, 2, 3, 1),
(1, 'CC-2025.2-H', 2025, 2, 5, 0);
GO

INSERT dbo.Aluno (Nome, CPF, Email, Ativo) VALUES
('Ana Lima',       '10000000001', 'ana.lima@exemplo.edu.br', 1),
('Bruno Alves',    '10000000002', 'bruno.alves@exemplo.edu.br', 1),
('Carla Souza',    '10000000003', 'carla.souza@exemplo.edu.br', 1),
('Diego Santos',   '10000000004', 'diego.santos@exemplo.edu.br', 1),
('Elisa Rocha',    '10000000005', 'elisa.rocha@exemplo.edu.br', 1),
('Fabio Melo',     '10000000006', 'fabio.melo@exemplo.edu.br', 1),
('Gabriela Reis',  '10000000007', 'gabriela.reis@exemplo.edu.br', 1),
('Henrique Luz',   '10000000008', 'henrique.luz@exemplo.edu.br', 1),
('Isabela Costa',  '10000000009', 'isabela.costa@exemplo.edu.br', 1),
('Joao Nunes',     '10000000010', 'joao.nunes@exemplo.edu.br', 1),
('Karen Freitas',  '10000000011', 'karen.freitas@exemplo.edu.br', 1),
('Lucas Moura',    '10000000012', 'lucas.moura@exemplo.edu.br', 1);
GO

-- Reservas para cenários de disponibilidade.
INSERT dbo.ReservaMatricula (IdAluno, IdTurma, DataReserva, DataExpiracao, Situacao) VALUES
(1, 1, '2026-09-01T09:00:00', '2026-10-15', 'RESERVADA'),
(2, 1, '2026-09-02T09:00:00', '2026-10-15', 'RESERVADA'),
(3, 1, '2026-08-15T09:00:00', '2026-08-30', 'EXPIRADA'),
(4, 2, '2026-09-03T09:00:00', '2026-10-15', 'RESERVADA'),
(5, 2, '2026-09-04T09:00:00', '2026-10-15', 'CANCELADA'),
(6, 3, '2026-09-05T09:00:00', '2026-10-15', 'EFETIVADA'),
(7, 3, '2026-09-06T09:00:00', '2026-10-15', 'EFETIVADA'),
(8, 1, '2026-09-07T09:00:00', '2026-10-15', 'EFETIVADA');
GO

INSERT dbo.Matricula (IdReserva, IdAluno, IdTurma, DataMatricula, ValorMensalidade, Situacao) VALUES
(6, 6, 3, '2026-09-06T10:00:00', 500.00, 'ATIVA'),
(7, 7, 3, '2026-09-07T10:00:00', 500.00, 'ATIVA'),
(8, 8, 1, '2026-09-08T10:00:00', 600.00, 'ATIVA');
GO

-- 12 parcelas para cada matrícula existente.
;WITH N AS (
    SELECT 1 AS Numero
    UNION ALL SELECT Numero + 1 FROM N WHERE Numero < 12
)
INSERT dbo.Parcela (IdMatricula, Numero, ValorOriginal, DataVencimento, Situacao)
SELECT M.Id,
       N.Numero,
       M.ValorMensalidade,
       DATEADD(MONTH, N.Numero - 1, CAST('2026-07-10' AS DATE)),
       CASE
           WHEN M.Id = 1 AND N.Numero <= 2 THEN 'PAGA'
           WHEN M.Id = 2 AND N.Numero = 1 THEN 'PAGA'
           WHEN DATEADD(MONTH, N.Numero - 1, CAST('2026-07-10' AS DATE)) < CAST('2026-09-26' AS DATE)
                THEN 'VENCIDA'
           ELSE 'ABERTA'
       END
FROM dbo.Matricula M
CROSS JOIN N
OPTION (MAXRECURSION 12);
GO

-- Pagamentos já realizados. O Trigger da avaliação ainda não existe neste momento.
INSERT dbo.Pagamento (IdParcela, DataPagamento, ValorPago)
SELECT P.Id,
       DATEADD(DAY, -2, CAST(P.DataVencimento AS DATETIME2(0))),
       P.ValorOriginal
FROM dbo.Parcela P
WHERE (P.IdMatricula = 1 AND P.Numero IN (1,2))
   OR (P.IdMatricula = 2 AND P.Numero = 1);
GO

-- Cenários de negociação prontos para testar cancelamento.
INSERT dbo.Negociacao (IdMatricula, DataNegociacao, ValorNegociado, Situacao) VALUES
(1, '2026-09-20T10:00:00', 5000.00, 'ABERTA'),
(2, '2026-09-21T10:00:00', 5500.00, 'QUITADA');
GO

-- Conferências básicas da carga.
SELECT 'Alunos' AS Entidade, COUNT(*) AS Quantidade FROM dbo.Aluno
UNION ALL SELECT 'Cursos', COUNT(*) FROM dbo.Curso
UNION ALL SELECT 'Turmas', COUNT(*) FROM dbo.Turma
UNION ALL SELECT 'Reservas', COUNT(*) FROM dbo.ReservaMatricula
UNION ALL SELECT 'Matriculas', COUNT(*) FROM dbo.Matricula
UNION ALL SELECT 'Parcelas', COUNT(*) FROM dbo.Parcela
UNION ALL SELECT 'Pagamentos', COUNT(*) FROM dbo.Pagamento
UNION ALL SELECT 'Negociacoes', COUNT(*) FROM dbo.Negociacao;
GO
