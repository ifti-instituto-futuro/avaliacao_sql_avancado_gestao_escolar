/*
Documentacao
Arquivo Fonte............:  01_estrutura_escola_sqlserver_padrao.sql
Objetivo.................:  Criar a estrutura fisica oficial da avaliacao de Banco de Dados Avancado (Gestao Escolar)
Autor....................:  Instituto Futuro
Data.....................:  26/09/2026
Schema...................:  dbo
Observacoes..............:
                        Estrutura fisica oficial da avaliacao 09/2026 - nao alterar tabelas ou colunas para adaptar a solucao
                        Versao reescrita de 01_estrutura_escola_sqlserver.sql conforme o padrao de modelagem da empresa
                        Cria o banco Escola quando ele ainda nao existir
                        Os objetos sao qualificados com [dbo] e escritos sem colchetes
                        Todas as chaves estrangeiras possuem indice NONCLUSTERED explicito, exceto quando ja lideram um UNIQUE
                        As situacoes (reserva, matricula, parcela e negociacao) sao tabelas de dominio em TINYINT
                        A carga das tabelas de dominio fica em 02_dados_iniciais_escola_sqlserver_padrao.sql
*/

--------------------------------------------------------------------------------
-- CRIACAO DO BANCO DE DADOS
--------------------------------------------------------------------------------

-- Criar o banco de dados da avaliacao caso ainda nao exista
IF DB_ID('Escola') IS NULL
    CREATE DATABASE Escola;
GO

USE Escola;
GO

SET NOCOUNT ON;
GO

--------------------------------------------------------------------------------
-- REMOCAO DAS TABELAS PARA REEXECUCAO DO SCRIPT
--------------------------------------------------------------------------------

-- Remover tabelas em ordem inversa de dependencia
DROP TABLE IF EXISTS [dbo].[Negociacao];
DROP TABLE IF EXISTS [dbo].[Pagamento];
DROP TABLE IF EXISTS [dbo].[Parcela];
DROP TABLE IF EXISTS [dbo].[Matricula];
DROP TABLE IF EXISTS [dbo].[ReservaMatricula];
DROP TABLE IF EXISTS [dbo].[Turma];
DROP TABLE IF EXISTS [dbo].[Curso];
DROP TABLE IF EXISTS [dbo].[Aluno];
DROP TABLE IF EXISTS [dbo].[SituacaoNegociacao];
DROP TABLE IF EXISTS [dbo].[SituacaoParcela];
DROP TABLE IF EXISTS [dbo].[SituacaoMatricula];
DROP TABLE IF EXISTS [dbo].[SituacaoReserva];
GO

--------------------------------------------------------------------------------
-- TABELAS DE DOMINIO
--------------------------------------------------------------------------------

-- Criar tabela de situacoes da reserva de matricula
CREATE TABLE [dbo].[SituacaoReserva] (
    Id TINYINT IDENTITY (1,1) NOT NULL,
    Descricao VARCHAR(50) NOT NULL,

    CONSTRAINT PK_SituacaoReserva PRIMARY KEY (Id),
    CONSTRAINT UQ_SituacaoReserva_Descricao UNIQUE (Descricao)
);
GO

-- Criar tabela de situacoes da matricula
CREATE TABLE [dbo].[SituacaoMatricula] (
    Id TINYINT IDENTITY (1,1) NOT NULL,
    Descricao VARCHAR(50) NOT NULL,

    CONSTRAINT PK_SituacaoMatricula PRIMARY KEY (Id),
    CONSTRAINT UQ_SituacaoMatricula_Descricao UNIQUE (Descricao)
);
GO

-- Criar tabela de situacoes da parcela
CREATE TABLE [dbo].[SituacaoParcela] (
    Id TINYINT IDENTITY (1,1) NOT NULL,
    Descricao VARCHAR(50) NOT NULL,

    CONSTRAINT PK_SituacaoParcela PRIMARY KEY (Id),
    CONSTRAINT UQ_SituacaoParcela_Descricao UNIQUE (Descricao)
);
GO

-- Criar tabela de situacoes da negociacao
CREATE TABLE [dbo].[SituacaoNegociacao] (
    Id TINYINT IDENTITY (1,1) NOT NULL,
    Descricao VARCHAR(50) NOT NULL,

    CONSTRAINT PK_SituacaoNegociacao PRIMARY KEY (Id),
    CONSTRAINT UQ_SituacaoNegociacao_Descricao UNIQUE (Descricao)
);
GO

--------------------------------------------------------------------------------
-- ENTIDADES PRINCIPAIS
--------------------------------------------------------------------------------

-- Criar tabela de alunos
CREATE TABLE [dbo].[Aluno] (
    Id INT IDENTITY (1,1) NOT NULL,
    Nome VARCHAR(120) NOT NULL,
    Cpf VARCHAR(11) NOT NULL,
    Email VARCHAR(150) NOT NULL,
    DataCriacao DATETIME2(3) NOT NULL CONSTRAINT DF_Aluno_DataCriacao DEFAULT (GETDATE()),
    Ativo BIT NOT NULL CONSTRAINT DF_Aluno_Ativo DEFAULT (1),

    CONSTRAINT PK_Aluno PRIMARY KEY (Id),
    CONSTRAINT UQ_Aluno_Cpf UNIQUE (Cpf),
    CONSTRAINT UQ_Aluno_Email UNIQUE (Email),
    CONSTRAINT CK_Aluno_CpfSomenteDigitos CHECK (LEN(Cpf) = 11 AND Cpf NOT LIKE '%[^0-9]%')
);
GO

-- Criar tabela de cursos
CREATE TABLE [dbo].[Curso] (
    Id INT IDENTITY (1,1) NOT NULL,
    Nome VARCHAR(120) NOT NULL,
    ValorMensalidade DECIMAL(14,2) NOT NULL,
    Ativo BIT NOT NULL CONSTRAINT DF_Curso_Ativo DEFAULT (1),

    CONSTRAINT PK_Curso PRIMARY KEY (Id),
    CONSTRAINT UQ_Curso_Nome UNIQUE (Nome),
    CONSTRAINT CK_Curso_ValorMensalidadePositivo CHECK (ValorMensalidade > 0)
);
GO

-- Criar tabela de turmas
CREATE TABLE [dbo].[Turma] (
    Id INT IDENTITY (1,1) NOT NULL,
    IdCurso INT NOT NULL,
    Codigo VARCHAR(20) NOT NULL,
    AnoLetivo SMALLINT NOT NULL,
    Semestre TINYINT NOT NULL,
    Capacidade SMALLINT NOT NULL,
    Ativo BIT NOT NULL CONSTRAINT DF_Turma_Ativo DEFAULT (1),

    CONSTRAINT PK_Turma PRIMARY KEY (Id),
    CONSTRAINT FK_IdCurso_Turma FOREIGN KEY (IdCurso) REFERENCES Curso (Id),
    CONSTRAINT UQ_Turma_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Turma_SemestreValido CHECK (Semestre IN (1, 2)),
    CONSTRAINT CK_Turma_CapacidadePositiva CHECK (Capacidade > 0)
);
GO

--------------------------------------------------------------------------------
-- RESERVA E MATRICULA
--------------------------------------------------------------------------------

-- Criar tabela de reservas de matricula
CREATE TABLE [dbo].[ReservaMatricula] (
    Id INT IDENTITY (1,1) NOT NULL,
    IdAluno INT NOT NULL,
    IdTurma INT NOT NULL,
    IdSituacaoReserva TINYINT NOT NULL,
    DataReserva DATETIME2(3) NOT NULL CONSTRAINT DF_ReservaMatricula_DataReserva DEFAULT (GETDATE()),
    DataExpiracao DATE NOT NULL,

    CONSTRAINT PK_ReservaMatricula PRIMARY KEY (Id),
    CONSTRAINT FK_IdAluno_ReservaMatricula FOREIGN KEY (IdAluno) REFERENCES Aluno (Id),
    CONSTRAINT FK_IdTurma_ReservaMatricula FOREIGN KEY (IdTurma) REFERENCES Turma (Id),
    CONSTRAINT FK_IdSituacaoReserva_ReservaMatricula FOREIGN KEY (IdSituacaoReserva) REFERENCES SituacaoReserva (Id),
    CONSTRAINT CK_ReservaMatricula_DataExpiracaoValida CHECK (DataExpiracao >= CAST(DataReserva AS DATE))
);
GO

-- Criar tabela de matriculas
CREATE TABLE [dbo].[Matricula] (
    Id INT IDENTITY (1,1) NOT NULL,
    IdReservaMatricula INT NOT NULL,
    IdAluno INT NOT NULL,
    IdTurma INT NOT NULL,
    IdSituacaoMatricula TINYINT NOT NULL,
    DataMatricula DATETIME2(3) NOT NULL CONSTRAINT DF_Matricula_DataMatricula DEFAULT (GETDATE()),
    ValorMensalidade DECIMAL(14,2) NOT NULL,

    CONSTRAINT PK_Matricula PRIMARY KEY (Id),
    CONSTRAINT FK_IdReservaMatricula_Matricula FOREIGN KEY (IdReservaMatricula) REFERENCES ReservaMatricula (Id),
    CONSTRAINT FK_IdAluno_Matricula FOREIGN KEY (IdAluno) REFERENCES Aluno (Id),
    CONSTRAINT FK_IdTurma_Matricula FOREIGN KEY (IdTurma) REFERENCES Turma (Id),
    CONSTRAINT FK_IdSituacaoMatricula_Matricula FOREIGN KEY (IdSituacaoMatricula) REFERENCES SituacaoMatricula (Id),
    CONSTRAINT UQ_Matricula_IdReservaMatricula UNIQUE (IdReservaMatricula),
    CONSTRAINT CK_Matricula_ValorMensalidadePositivo CHECK (ValorMensalidade > 0)
);
GO

--------------------------------------------------------------------------------
-- FINANCEIRO
--------------------------------------------------------------------------------

-- Criar tabela de parcelas
CREATE TABLE [dbo].[Parcela] (
    Id INT IDENTITY (1,1) NOT NULL,
    IdMatricula INT NOT NULL,
    IdSituacaoParcela TINYINT NOT NULL,
    Numero TINYINT NOT NULL,
    ValorOriginal DECIMAL(14,2) NOT NULL,
    DataVencimento DATE NOT NULL,

    CONSTRAINT PK_Parcela PRIMARY KEY (Id),
    CONSTRAINT FK_IdMatricula_Parcela FOREIGN KEY (IdMatricula) REFERENCES Matricula (Id),
    CONSTRAINT FK_IdSituacaoParcela_Parcela FOREIGN KEY (IdSituacaoParcela) REFERENCES SituacaoParcela (Id),
    CONSTRAINT UQ_Parcela_IdMatriculaNumero UNIQUE (IdMatricula, Numero),
    CONSTRAINT CK_Parcela_NumeroValido CHECK (Numero BETWEEN 1 AND 12),
    CONSTRAINT CK_Parcela_ValorOriginalPositivo CHECK (ValorOriginal > 0)
);
GO

-- Criar tabela de pagamentos
CREATE TABLE [dbo].[Pagamento] (
    Id INT IDENTITY (1,1) NOT NULL,
    IdParcela INT NOT NULL,
    DataPagamento DATETIME2(3) NOT NULL CONSTRAINT DF_Pagamento_DataPagamento DEFAULT (GETDATE()),
    ValorPago DECIMAL(14,2) NOT NULL,

    CONSTRAINT PK_Pagamento PRIMARY KEY (Id),
    CONSTRAINT FK_IdParcela_Pagamento FOREIGN KEY (IdParcela) REFERENCES Parcela (Id),
    CONSTRAINT CK_Pagamento_ValorPagoPositivo CHECK (ValorPago > 0)
);
GO

-- Criar tabela de negociacoes
CREATE TABLE [dbo].[Negociacao] (
    Id INT IDENTITY (1,1) NOT NULL,
    IdMatricula INT NOT NULL,
    IdSituacaoNegociacao TINYINT NOT NULL,
    DataNegociacao DATETIME2(3) NOT NULL CONSTRAINT DF_Negociacao_DataNegociacao DEFAULT (GETDATE()),
    ValorNegociado DECIMAL(14,2) NOT NULL,

    CONSTRAINT PK_Negociacao PRIMARY KEY (Id),
    CONSTRAINT FK_IdMatricula_Negociacao FOREIGN KEY (IdMatricula) REFERENCES Matricula (Id),
    CONSTRAINT FK_IdSituacaoNegociacao_Negociacao FOREIGN KEY (IdSituacaoNegociacao) REFERENCES SituacaoNegociacao (Id),
    CONSTRAINT CK_Negociacao_ValorNegociadoPositivo CHECK (ValorNegociado > 0)
);
GO

--------------------------------------------------------------------------------
-- INDICES DAS CHAVES ESTRANGEIRAS
--------------------------------------------------------------------------------

-- Criar indices da tabela Turma
CREATE NONCLUSTERED INDEX IX_Turma_IdCurso ON [dbo].[Turma] (IdCurso);
GO

-- Criar indices da tabela ReservaMatricula
CREATE NONCLUSTERED INDEX IX_ReservaMatricula_IdAluno ON [dbo].[ReservaMatricula] (IdAluno);
GO
CREATE NONCLUSTERED INDEX IX_ReservaMatricula_IdTurma ON [dbo].[ReservaMatricula] (IdTurma);
GO
CREATE NONCLUSTERED INDEX IX_ReservaMatricula_IdSituacaoReserva ON [dbo].[ReservaMatricula] (IdSituacaoReserva);
GO

-- Criar indices da tabela Matricula (IdReservaMatricula ja e coberto por UQ_Matricula_IdReservaMatricula)
CREATE NONCLUSTERED INDEX IX_Matricula_IdAluno ON [dbo].[Matricula] (IdAluno);
GO
CREATE NONCLUSTERED INDEX IX_Matricula_IdTurma ON [dbo].[Matricula] (IdTurma);
GO
CREATE NONCLUSTERED INDEX IX_Matricula_IdSituacaoMatricula ON [dbo].[Matricula] (IdSituacaoMatricula);
GO

-- Criar indices da tabela Parcela (IdMatricula ja e coberto por UQ_Parcela_IdMatriculaNumero)
CREATE NONCLUSTERED INDEX IX_Parcela_IdSituacaoParcela ON [dbo].[Parcela] (IdSituacaoParcela);
GO

-- Criar indices da tabela Pagamento
CREATE NONCLUSTERED INDEX IX_Pagamento_IdParcela ON [dbo].[Pagamento] (IdParcela);
GO

-- Criar indices da tabela Negociacao
CREATE NONCLUSTERED INDEX IX_Negociacao_IdMatricula ON [dbo].[Negociacao] (IdMatricula);
GO
CREATE NONCLUSTERED INDEX IX_Negociacao_IdSituacaoNegociacao ON [dbo].[Negociacao] (IdSituacaoNegociacao);
GO
