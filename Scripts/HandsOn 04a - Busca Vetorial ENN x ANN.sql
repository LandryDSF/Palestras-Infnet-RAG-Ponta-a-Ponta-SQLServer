/*
===============================================================================
Palestra Infnet 202609
RAG de Ponta a Ponta no SQL Server 2025

Hands On: Busca Vetorial ENN x ANN

Objetivo:
Demonstrar a diferença entre Busca Vetorial ENN (Exact Nearest Neighbor)
utilizando a função VECTOR_DISTANCE() e ANN (Approximate Nearest Neighbor) 
utilizando a função VECTOR_SEARCH().

Ambiente:
- SQL Server 2025
- Ollama
- Caddy

Autor: Landry Duailibe | SQL Server Expert
===============================================================================
*/
use Aula
go

/*******************************************************
 Autor: Landry Duailibe

 Demo: diferença entre busca exata (ENN) e aproximada (ANN)
 Mostra que ANN pode não retornar todos os resultados idênticos
*********************************************************/

-- Cria tabela demo sem índice
DROP TABLE IF exists dbo.BuscaVetor_ENN
go
CREATE TABLE dbo.BuscaVetor_ENN (
Id int identity CONSTRAINT pk_BuscaVetor_ENN PRIMARY KEY,
Rotulo varchar(50),
Vetor vector(3))
go

-- Insere vetores de teste — 4 linhas idênticas + vizinhos
INSERT dbo.BuscaVetor_ENN (Rotulo, Vetor) VALUES
('Idêntico 1', '[0.5, 0.5, 0.5]'),
('Idêntico 2', '[0.5, 0.5, 0.5]'),
('Idêntico 3', '[0.5, 0.5, 0.5]'),
('Idêntico 4', '[0.5, 0.5, 0.5]'),
('Próximo A',  '[0.4, 0.5, 0.6]'),
('Próximo B',  '[0.6, 0.4, 0.5]'),
('Distante',   '[0.1, 0.9, 0.2]')
go

-- Cria tabela indexada com os mesmos dados
DROP TABLE IF exists dbo.BuscaVetor_ANN
go
SELECT * INTO dbo.BuscaVetor_ANN FROM dbo.BuscaVetor_ENN
go

ALTER TABLE dbo.BuscaVetor_ANN ADD CONSTRAINT pk_BuscaVetor_ANN PRIMARY KEY (Id)
go

CREATE VECTOR INDEX IX_BuscaVetor_ANN
ON dbo.BuscaVetor_ANN (Vetor)
WITH (METRIC = 'cosine', TYPE = 'diskann')
go

-- =============================================
-- Busca EXATA (sem índice)
-- Retorna TODAS as linhas idênticas
-- =============================================
go
DECLARE @Busca vector(3) = convert(vector(3), '[0.5, 0.5, 0.5]')

SELECT d.Rotulo,
vector_distance('cosine', d.Vetor, @Busca) as Distancia, 
'Busca Exata (ENN)' as Metodo
FROM dbo.BuscaVetor_ENN d
ORDER BY Distancia
go

-- =============================================
-- Busca APROXIMADA (com índice DiskANN)
-- Pode não retornar todas as linhas idênticas
-- =============================================
go
DECLARE @Busca vector(3) = convert(vector(3), '[0.5, 0.5, 0.5]')

SELECT d.Rotulo, vs.distance as Distancia, 'Busca Aproximada (ANN)' as Metodo
FROM vector_search(
    TABLE  = dbo.BuscaVetor_ANN AS d,
    COLUMN = Vetor,
    SIMILAR_TO = @Busca,
    METRIC = 'cosine',
    TOP_N  = 10
) AS vs
ORDER BY vs.distance
go

-- =============================================
-- Apaga tabelas
-- =============================================
DROP TABLE IF exists dbo.BuscaVetor_ENN
go
DROP TABLE IF exists dbo.BuscaVetor_ANN
go