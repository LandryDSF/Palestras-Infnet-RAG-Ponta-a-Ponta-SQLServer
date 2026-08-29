/*
===============================================================================
Palestra Infnet 202609
RAG de Ponta a Ponta no SQL Server 2025

Hands On: Chunking e Embeddings

Objetivo:
Demonstrar a geração de chunks e embeddings utilizando as funções nativas
AI_GENERATE_CHUNKS() e AI_GENERATE_EMBEDDINGS() do SQL Server 2025,
preparando os dados para consultas por Busca Vetorial.

Ambiente:
- SQL Server 2025
- Ollama
- Caddy

Autor: Landry Duailibe
===============================================================================
*/
use master
go

/*************************************************
 Banco de dados "Landry_Blogs"
 -  Banco de dados foi gerado utilizando alguns 
    Posts do Blog SQL Server Expert:
    https://sqlserver-expert.hashnode.dev/

 Restaurando o banco de dados "Landry_Blogs":
 1- O Backup do banco "Landry_Blogs" se encontra
    no repositório na pasta "Banco".

 2- Copiar o arquivo "Landry_Blogs.bak" para pasta
    local, por exemplo "E:\Backup".

 3- Altere o comando RESTORE abaixo para 
    path da sua máquina.
**************************************************/

RESTORE DATABASE Landry_Blogs FROM DISK = 'E:\Backup\Landry_Blogs.bak' WITH recovery,
move 'Landry_Blogs' to 'E:\MSSQL_Data\Landry_Blogs.mdf',
move 'Landry_Blogs_log' to 'F:\MSSQL_Data\Landry_Blogs_log.ldf'

/********************************************
 Habilitando no Banco recursos de IA
*********************************************/
use Landry_Blogs
go

-- Habilitar preview features (necessário no SQL Server 2025)
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON

-- Se ainda não habilitou na instância do SQL Server
EXECUTE sp_configure 'external AI runtimes enabled', 1
RECONFIGURE WITH OVERRIDE

EXECUTE sp_configure 'external rest endpoint enabled', 1
RECONFIGURE WITH OVERRIDE

/*******************************
 Modelo de Embedding
********************************/
-- DROP EXTERNAL MODEL EmbeddingGemma
CREATE EXTERNAL MODEL EmbeddingGemma
WITH (
LOCATION = 'https://localhost/api/embed',
API_FORMAT = 'Ollama',
MODEL_TYPE = EMBEDDINGS,
MODEL = 'embeddinggemma'
)

-- Consultando Metadata
SELECT * FROM sys.external_models


/****************************************
 Tabelas com os Chunks
*****************************************/
DROP TABLE IF exists dbo.BlogChunks_PorTamanho
go
CREATE TABLE dbo.BlogChunks_PorTamanho (
ChunkId int identity(1,1) CONSTRAINT pk_BlogChunks_PorTamanho PRIMARY KEY,
PostId int NOT NULL,
Chunk_Indice int NOT NULL, -- ordem do chunk dentro do post (0, 1, 2...)
Chunk_Texto nvarchar(MAX) NOT NULL, -- texto do chunk
Embedding vector(768) NULL -- 768 dimensões para modelo embeddinggemma
)
go

ALTER TABLE dbo.BlogChunks_PorTamanho ADD CONSTRAINT uq_BlogChunks_PorTamanho_Post_Chunk 
UNIQUE (PostId, Chunk_Indice)

ALTER TABLE dbo.BlogChunks_PorTamanho ADD CONSTRAINT fk_BlogChunks_PorTamanho_BlogPosts 
FOREIGN KEY (PostId) REFERENCES dbo.BlogPosts(PostId)
go

/************************************
 Gerar chunks de todos os posts
 - Modelo embeddinggemma
*************************************/
INSERT INTO dbo.BlogChunks_PorTamanho (PostId, Chunk_Indice, Chunk_Texto)

SELECT bp.PostId, c.chunk_order, c.chunk
FROM dbo.BlogPosts bp
CROSS APPLY AI_GENERATE_CHUNKS(
source     = bp.Conteudo,
chunk_type = FIXED,
chunk_size = 1000,
overlap    = 15
) as c
WHERE NOT EXISTS (SELECT 1 FROM dbo.BlogChunks_PorTamanho bc WHERE bc.PostId = bp.PostId)


SELECT * FROM dbo.BlogChunks_PorTamanho
ORDER BY PostId, Chunk_Indice

-- Validar distribuição de chunks por post
SELECT bp.Titulo,
count(bc.ChunkId) as Total_Chunks,
min(len(bc.Chunk_Texto)) as Menor_Chunk,
max(len(bc.Chunk_Texto)) as Maior_Chunk,
avg(len(bc.Chunk_Texto)) as Media_Chunk
FROM dbo.BlogPosts bp
JOIN dbo.BlogChunks_PorTamanho bc ON bc.PostId = bp.PostId
GROUP BY bp.Titulo
ORDER BY Total_Chunks DESC

/*****************************************
 Gerar embeddings para todos os chunks
******************************************/
-- Modelo embeddinggemma
-- Leva +- 6 minutos
UPDATE dbo.BlogChunks_PorTamanho
SET Embedding = ai_generate_embeddings(Chunk_Texto USE MODEL EmbeddingGemma)
WHERE Embedding is null

-- Monitorar progresso em outra aba
SELECT count(*) as Total_Chunks,
count(Embedding) as Com_Embedding,
count(*) - count(Embedding) as Sem_Embedding,
cast(count(Embedding) * 100.0 / count(*) as decimal(5,1)) as Percentual
FROM dbo.BlogChunks_PorTamanho with (nolock)

SELECT * FROM dbo.BlogChunks_PorTamanho with (nolock)

