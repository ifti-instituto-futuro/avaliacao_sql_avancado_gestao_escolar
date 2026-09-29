/*
    BANCO DE DADOS AVANÇADO - AVALIAÇÃO 09/2026
    CENÁRIO: GESTÃO ESCOLAR
    ARQUIVO: 01_estrutura_escola_sqlserver.sql

    IMPORTANTE:
    - Estrutura física oficial da avaliação.
    - Não alterar tabelas/colunas para adaptar a solução.
    - SGBD: Microsoft SQL Server.
*/

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.Negociacao', 'U') IS NOT NULL DROP TABLE dbo.Negociacao;
IF OBJECT_ID('dbo.Pagamento', 'U') IS NOT NULL DROP TABLE dbo.Pagamento;
IF OBJECT_ID('dbo.Parcela', 'U') IS NOT NULL DROP TABLE dbo.Parcela;
IF OBJECT_ID('dbo.Matricula', 'U') IS NOT NULL DROP TABLE dbo.Matricula;
IF OBJECT_ID('dbo.ReservaMatricula', 'U') IS NOT NULL DROP TABLE dbo.ReservaMatricula;
IF OBJECT_ID('dbo.Turma', 'U') IS NOT NULL DROP TABLE dbo.Turma;
IF OBJECT_ID('dbo.Curso', 'U') IS NOT NULL DROP TABLE dbo.Curso;
IF OBJECT_ID('dbo.Aluno', 'U') IS NOT NULL DROP TABLE dbo.Aluno;
GO

CREATE TABLE dbo.Aluno (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Aluno PRIMARY KEY,
    Nome            VARCHAR(120) NOT NULL,
    CPF             VARCHAR(11) NOT NULL CONSTRAINT UQ_Aluno_CPF UNIQUE,
    Email           VARCHAR(150) NOT NULL,
    Ativo           BIT NOT NULL CONSTRAINT DF_Aluno_Ativo DEFAULT (1),
    DataCadastro    DATETIME2(0) NOT NULL CONSTRAINT DF_Aluno_DataCadastro DEFAULT (SYSDATETIME())
);
GO

CREATE TABLE dbo.Curso (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Curso PRIMARY KEY,
    Nome            VARCHAR(120) NOT NULL,
    ValorMensalidade DECIMAL(10,2) NOT NULL,
    Ativo           BIT NOT NULL CONSTRAINT DF_Curso_Ativo DEFAULT (1),
    CONSTRAINT CK_Curso_Valor CHECK (ValorMensalidade > 0)
);
GO

CREATE TABLE dbo.Turma (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Turma PRIMARY KEY,
    IdCurso         INT NOT NULL,
    Codigo          VARCHAR(20) NOT NULL CONSTRAINT UQ_Turma_Codigo UNIQUE,
    AnoLetivo       SMALLINT NOT NULL,
    Semestre        TINYINT NOT NULL,
    Capacidade      INT NOT NULL,
    Ativo           BIT NOT NULL CONSTRAINT DF_Turma_Ativo DEFAULT (1),
    CONSTRAINT FK_Turma_Curso FOREIGN KEY (IdCurso) REFERENCES dbo.Curso(Id),
    CONSTRAINT CK_Turma_Semestre CHECK (Semestre IN (1,2)),
    CONSTRAINT CK_Turma_Capacidade CHECK (Capacidade > 0)
);
GO

CREATE TABLE dbo.ReservaMatricula (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReservaMatricula PRIMARY KEY,
    IdAluno         INT NOT NULL,
    IdTurma         INT NOT NULL,
    DataReserva     DATETIME2(0) NOT NULL CONSTRAINT DF_Reserva_Data DEFAULT (SYSDATETIME()),
    DataExpiracao   DATE NOT NULL,
    Situacao        VARCHAR(12) NOT NULL,
    CONSTRAINT FK_Reserva_Aluno FOREIGN KEY (IdAluno) REFERENCES dbo.Aluno(Id),
    CONSTRAINT FK_Reserva_Turma FOREIGN KEY (IdTurma) REFERENCES dbo.Turma(Id),
    CONSTRAINT CK_Reserva_Situacao CHECK (Situacao IN ('RESERVADA','EFETIVADA','CANCELADA','EXPIRADA'))
);
GO

CREATE TABLE dbo.Matricula (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Matricula PRIMARY KEY,
    IdReserva       INT NOT NULL CONSTRAINT UQ_Matricula_Reserva UNIQUE,
    IdAluno         INT NOT NULL,
    IdTurma         INT NOT NULL,
    DataMatricula   DATETIME2(0) NOT NULL CONSTRAINT DF_Matricula_Data DEFAULT (SYSDATETIME()),
    ValorMensalidade DECIMAL(10,2) NOT NULL,
    Situacao        VARCHAR(12) NOT NULL,
    CONSTRAINT FK_Matricula_Reserva FOREIGN KEY (IdReserva) REFERENCES dbo.ReservaMatricula(Id),
    CONSTRAINT FK_Matricula_Aluno FOREIGN KEY (IdAluno) REFERENCES dbo.Aluno(Id),
    CONSTRAINT FK_Matricula_Turma FOREIGN KEY (IdTurma) REFERENCES dbo.Turma(Id),
    CONSTRAINT CK_Matricula_Valor CHECK (ValorMensalidade > 0),
    CONSTRAINT CK_Matricula_Situacao CHECK (Situacao IN ('ATIVA','CANCELADA','CONCLUIDA'))
);
GO

CREATE TABLE dbo.Parcela (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Parcela PRIMARY KEY,
    IdMatricula     INT NOT NULL,
    Numero          TINYINT NOT NULL,
    ValorOriginal   DECIMAL(10,2) NOT NULL,
    DataVencimento  DATE NOT NULL,
    Situacao        VARCHAR(10) NOT NULL,
    CONSTRAINT FK_Parcela_Matricula FOREIGN KEY (IdMatricula) REFERENCES dbo.Matricula(Id),
    CONSTRAINT UQ_Parcela_Matricula_Numero UNIQUE (IdMatricula, Numero),
    CONSTRAINT CK_Parcela_Numero CHECK (Numero BETWEEN 1 AND 12),
    CONSTRAINT CK_Parcela_Valor CHECK (ValorOriginal > 0),
    CONSTRAINT CK_Parcela_Situacao CHECK (Situacao IN ('ABERTA','VENCIDA','PAGA','CANCELADA'))
);
GO

CREATE TABLE dbo.Pagamento (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pagamento PRIMARY KEY,
    IdParcela       INT NOT NULL,
    DataPagamento   DATETIME2(0) NOT NULL CONSTRAINT DF_Pagamento_Data DEFAULT (SYSDATETIME()),
    ValorPago       DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_Pagamento_Parcela FOREIGN KEY (IdParcela) REFERENCES dbo.Parcela(Id),
    CONSTRAINT CK_Pagamento_Valor CHECK (ValorPago > 0)
);
GO

CREATE TABLE dbo.Negociacao (
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Negociacao PRIMARY KEY,
    IdMatricula     INT NOT NULL,
    DataNegociacao  DATETIME2(0) NOT NULL CONSTRAINT DF_Negociacao_Data DEFAULT (SYSDATETIME()),
    ValorNegociado  DECIMAL(10,2) NOT NULL,
    Situacao        VARCHAR(10) NOT NULL,
    CONSTRAINT FK_Negociacao_Matricula FOREIGN KEY (IdMatricula) REFERENCES dbo.Matricula(Id),
    CONSTRAINT CK_Negociacao_Valor CHECK (ValorNegociado > 0),
    CONSTRAINT CK_Negociacao_Situacao CHECK (Situacao IN ('ABERTA','QUITADA','CANCELADA'))
);
GO
