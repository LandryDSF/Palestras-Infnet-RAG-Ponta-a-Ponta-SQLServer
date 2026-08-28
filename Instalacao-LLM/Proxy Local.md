## Workshop SQL Server Expert - 4ª Edição
### Construa Soluções com IA Dentro do SQL Server 2025

### ▶️ Instalando e Configurando Proxy Local Candy

**Proxy Caddy**
Fazer download do Proxy Caddy utilizando o link abaixo, salve o arquivo "caddy_windows_amd64.exe" em uma pasta local, por exemplo "C:\Caddy"
https://caddyserver.com/download

Em seguida crie um arquivo sem extensão chamado "Caddyfile." na mesma pasta onde está o executável do Caddy e salve o script abaixo no arquivo.

```text
{
  admin localhost:2019
}

localhost, 127.0.0.1 {
  tls internal

  @ollama path /api/* /v1/*
  reverse_proxy 127.0.0.1:11434 {
    flush_interval -1
  }

  @preflight {
    method OPTIONS
    path /api/* /v1/*
  }
  respond @preflight 204

  header @ollama {
    Access-Control-Allow-Origin  *
    Access-Control-Allow-Methods "GET, POST, OPTIONS"
    Access-Control-Allow-Headers "Content-Type, Authorization"
    Access-Control-Expose-Headers "*"
  }

  respond / "Caddy is running with HTTPS on localhost" 200

  log {
    output file C:\caddy\logs\ollama-local.log
    format console
  }
}
```

**Carregando o Candy**

Agora em uma janela de **Prompt (Command Window)** execute a partir da mesma pasta do arquivo criado acima. Aparecendo uma janela confirmando a instalação de um certificado local responda "Yes".
```text
.\caddy_windows_amd64.exe run --config Caddyfile
```

**Instalando Certificado**

Em outra janela de **Prompt (Command Window)**, para garantir a criação do certificado local, execute o comando abaixo:
```text
.\caddy_windows_amd64.exe trust
```

***Janela PowerShell:*** Agora precisamos importar o Certificado gerado para o Trusted Root do Windows, utilize o comando PowerShell abaixo para confirmar a localização do certificado:

```text
Get-ChildItem -Path "$env:APPDATA\Caddy\pki\authorities\local\" -ErrorAction SilentlyContinue
```

***Janela PowerShell:*** No comando abaixo importamos o certificado para o Trusted Root do Windows, utilizar janela PowerShell como administrador!

```text
Import-Certificate `
    -FilePath "$env:APPDATA\Caddy\pki\authorities\local\root.crt" `
    -CertStoreLocation Cert:\LocalMachine\Root
```

***Janela PowerShell:*** Para verificar a importação do certificado utilizar o comando PowerShell abaixo:

```text
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Caddy*" }
```


**Command Prompt:** Teste utilizando Modelo de Chat via Proxy Caddy com pergunta sobre índices.
```cmd
curl --ssl-no-revoke -H "Content-Type: application/json" -d "{\"model\":\"llama3.2:1b\",\"messages\":[{\"role\":\"system\",\"content\":\"Você é um assistente que explica conceitos do banco de dados Microsoft SQL Server de forma clara e objetiva.\"},{\"role\":\"user\",\"content\":\"Explique a diferença entre índices clusterizados e índices não clusterizados no SQL Server.\"}],\"stream\":false}" https://localhost/api/chat
```


**Testando do SQL Server**
Agora vamos testar o acesso a LLM via Caddy de dentro do SQL Server.
Abra o **Management Studio**, em uma janela de Query, cole e execute o comando abaixo:

```sql
use Landry_Blogs
go

-- Habilitar preview features (necessário no SQL Server 2025)
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON

-- Habilitar as Funcionalidades de AI
EXECUTE sp_configure 'external AI runtimes enabled', 1
RECONFIGURE WITH OVERRIDE

EXECUTE sp_configure 'external rest endpoint enabled', 1
RECONFIGURE WITH OVERRIDE

-- Chamada a LLM Local
DECLARE @payload NVARCHAR(MAX) = N'{
    "model": "llama3.2:1b",
    "options": {"temperature":0.3},
    "messages": [
        {"role": "system", "content": "Você é um assistente especialista em SQL Server."},
        {"role": "user",   "content": "Explique o que é TempDB"}
    ],
    "stream": false
}'

DECLARE @response NVARCHAR(MAX)

EXEC sp_invoke_external_rest_endpoint
@url      = 'https://localhost/api/chat',
@method   = 'POST',
@headers  = '{"Content-Type":"application/json"}',
@payload  = @payload,
@timeout  = 120,
@response = @response OUTPUT

SELECT JSON_VALUE(@response, '$.result.message.content') AS Resposta
```
