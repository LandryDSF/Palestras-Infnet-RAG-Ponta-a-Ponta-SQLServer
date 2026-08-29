/*
===============================================================================
Palestra Infnet 202609
RAG de Ponta a Ponta no SQL Server 2025

Hands On: Acessando LLM do SQL Server

Objetivo:
Demonstrar o uso dos prompts de sistema e usuário em chamadas para uma
LLM local utilizando SQL Server, Ollama e Caddy.

Ambiente:
- SQL Server 2025
- Ollama
- Caddy

Autor: Landry Duailibe
===============================================================================
*/
use Aula
go

/***********************************************
 Habilitando recursos de IA no banco corrente
************************************************/
-- Habilitar preview features (necessário no SQL Server 2025)
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON

-- Habilitar as Funcionalidades de AI
EXECUTE sp_configure 'external AI runtimes enabled', 1
RECONFIGURE WITH OVERRIDE

EXECUTE sp_configure 'external rest endpoint enabled', 1
RECONFIGURE WITH OVERRIDE

/*****************************************
 Chamada Chat com LLM Local
 - Execute o Proxy Local Caddy antes
 c:\caddy\caddy_windows_amd64.exe run --config c:\caddy\Caddyfile
*****************************************/
go
DECLARE @pSystem nvarchar(max) = 'Você é um professor especializado em Microsoft SQL Server.
Explique os conceitos em português, utilizando linguagem clara e objetiva.
Sempre que possível, utilize exemplos relacionados ao trabalho de DBAs e desenvolvedores SQL.'

DECLARE @pUser nvarchar(max) = '
Explique o que é o banco de dados de sistema TempDB para um desenvolvedor SQL iniciante.

Inclua:
- sua finalidade;
- os principais objetos armazenados;
- exemplos de uso;
- cuidados básicos de configuração.

Organize a resposta em tópicos e finalize com um resumo.'

DECLARE @Modelo nvarchar(200) = N'llama3.2:1b'
DECLARE @Temp nvarchar(4) = N'0.3'
DECLARE @Timeout int = 230

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





