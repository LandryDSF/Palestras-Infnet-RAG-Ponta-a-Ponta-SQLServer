/*
===============================================================================
Palestra Infnet 202609
RAG de Ponta a Ponta no SQL Server 2025

Hands On: Stored Procedure spAI_Chat_Ollama

Ambiente:
- SQL Server 2025
- Ollama
- Caddy

Autor: Landry Duailibe
===============================================================================
*/
use Landry_Blogs
go


/***********************************************
 Cria SP para Chamada Chat com LLM Local

EXEC dbo.spAI_Chat_Ollama
@pSystem = 'Você é um assistente especializado em bancos de dados Microsoft SQL Server que explica conceitos de forma clara e objetiva',
@pUser = 'Explique o que é o Banco de Dados de Sistema TempDB'
************************************************/

go
CREATE or ALTER PROC dbo.spAI_Chat_Ollama
@pSystem nvarchar(max),
@pUser nvarchar(max),
@Modelo nvarchar(200) = N'llama3.2:1b',
@Temp nvarchar(4) = N'0.3',
@Timeout int = 230
as
set nocount on

DECLARE @payload nvarchar(MAX) = N'{
    "model": "' + STRING_ESCAPE(@Modelo, 'json') + N'",
    "options": {"temperature":' + @Temp + N'},
    "messages": [
        {"role": "system", "content": "' + STRING_ESCAPE(@pSystem, 'json') + N'"},
        {"role": "user",   "content": "' + STRING_ESCAPE(@pUser, 'json') + N'"}
    ],
    "stream": false
}'

DECLARE @response nvarchar(MAX)

EXEC sp_invoke_external_rest_endpoint
@url      = 'https://localhost/api/chat',
@method   = 'POST',
@headers  = '{"Content-Type":"application/json"}',
@payload  = @payload,
@timeout  = @Timeout,
@response = @response OUTPUT

SELECT JSON_VALUE(@response, '$.result.message.content') AS Resposta
go
/********************** FIM SP *********************/

