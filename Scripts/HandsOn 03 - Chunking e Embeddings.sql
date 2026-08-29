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

/********************************
 Métodos de Chuncking
*********************************/
SELECT * FROM dbo.BlogPosts
-- https://sqlserver-expert.hashnode.dev/

SELECT * FROM dbo.BlogChunks_PorTamanho
WHERE PostId = 1
ORDER BY PostId, Chunk_Indice

/*
Você já se deparou com este cenário?  * Arquivo de **log da TempDB** crescendo sem parar.      * Arquivos de dados da TempDB praticamente do mesmo tamanho.       Foi exatamente isso que aconteceu em um ambiente de produção:   uma estação de trabalho travou no meio de uma consulta grande, o SQL Server continuou esperando o cliente, a sessão ficou em SUSPENDED e a **tempdb foi quem pagou a conta**. O arquivo de log foi crescendo… crescendo… por sorte minha rotina que monitora crescimento da TempDB alertou e iniciei o processo de investigação.  Neste post vou mostrar **como diagnostiquei o problema, identifiquei a sessão e dei KILL** com segurança, parando o crescimento do log da TempDB.  ## **1\. Sintomas**  ![](https://cdn.hashnode.com/res/hashnode/image/upload/v1765298543542/5d551561-beca-43b6-9f06-8a331ffce2b4.png align="center")  Veja que o arquivo de Log da TempDB estava lotado internament e crescendo, mas os arquivos de dados não estavam crescendo, como a TempDB possui o Recovery m

ue o arquivo de Log da TempDB estava lotado internament e crescendo, mas os arquivos de dados não estavam crescendo, como a TempDB possui o Recovery model SIMPLE, algo estava segurando o “truncar” do Log.  Para constatar este cenário utilizei o comando abaixo, que retornou ACTIVE\_TRANSACTION:  ```sql SELECT  name, log_reuse_wait_desc FROM sys.databases WHERE database_id = 2  -- tempdb ```  A mensagem era clara: **alguma transação ainda estava “segurando” o log da tempdb.**  ## **2\. Identificando a Transação**  Executando o DBCC OPENTRANS na TempDB identifiquei a sessão que estava prendendo o Log da TempDB!  ![](https://cdn.hashnode.com/res/hashnode/image/upload/v1765298961688/5ce742c7-5837-45ce-8da6-8bd55b6b6765.png align="center")  Uma consulta em tabelas grandes e ORDER BY teve que utilizar a TempDB para ordenar, mas a estação de trabalho congelou no meio da execução, resultado o SQL Server estava enviando os dados para estação, ela “sumiu” e o SQL Server ficou aguardando para cont
*/

-- Chunks variáveis
SELECT * FROM dbo.BlogChunks
WHERE PostId = 1
ORDER BY PostId, Chunk_Indice

/*
# Diagnóstico de Crescimento Anormal do Log da tempdb no SQL Server  ## Introdução  Você já se deparou com este cenário?  * Arquivo de **log da TempDB** crescendo sem parar.  * Arquivos de dados da TempDB praticamente do mesmo tamanho.   Foi exatamente isso que aconteceu em um ambiente de produção: uma estação de trabalho travou no meio de uma consulta grande, o SQL Server continuou esperando o cliente, a sessão ficou em SUSPENDED e a **tempdb foi quem pagou a conta**. O arquivo de log foi crescendo… crescendo… por sorte minha rotina que monitora crescimento da TempDB alertou e iniciei o processo de investigação.  Neste post vou mostrar **como diagnostiquei o problema, identifiquei a sessão e dei KILL** com segurança, parando o crescimento do log da TempDB.

# Diagnóstico de Crescimento Anormal do Log da tempdb no SQL Server  ## 1. Sintomas  Veja que o arquivo de Log da TempDB estava lotado internament e crescendo, mas os arquivos de dados não estavam crescendo, como a TempDB possui o Recovery model SIMPLE, algo estava segurando o “truncar” do Log.  Para constatar este cenário utilizei o comando abaixo, que retornou ACTIVE_TRANSACTION:  SELECT  name, log_reuse_wait_desc FROM sys.databases WHERE database_id = 2  -- tempdb  A mensagem era clara: **alguma transação ainda estava “segurando” o log da tempdb.**
*/
