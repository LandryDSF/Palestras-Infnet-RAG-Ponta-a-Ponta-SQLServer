/*
===============================================================================
Palestra Infnet 202609
RAG de Ponta a Ponta no SQL Server 2025

Hands On: Tipo Vector no SQL Server

Objetivo:
Demonstrar, na prática, como representar informações utilizando vetores no
SQL Server 2025, armazenando-os no tipo de dado VECTOR e utilizando funções
nativas para consultar suas propriedades e medir a similaridade entre vetores.

Ambiente:
- SQL Server 2025
- Ollama
- Caddy

Autor: Landry Duailibe
===============================================================================
*/
use Aula
go

DROP TABLE IF exists dbo.Animais
go
CREATE TABLE dbo.Animais (
Animal varchar(20),
Caracteristicas vector(8))
go

INSERT dbo.Animais VALUES
('Cachorro', '[1,0,1,0,0,0,1,0]'),
('Gato',      '[1,0,0,1,0,0,1,0]'),
('Leão',      '[1,0,0,0,0,0,0,0]'),
('Águia',     '[0,1,0,0,1,1,0,1]'),
('Papagaio',  '[0,1,0,0,1,1,1,1]');
go

SELECT * FROM dbo.Animais

-- Consultando Metadata
SELECT c.name AS Coluna,
type_name(c.user_type_id) AS Tipo,
c.vector_dimensions AS Dimensoes,
c.vector_base_type_desc AS TipoBase
FROM sys.columns AS c
WHERE c.object_id = object_id(N'dbo.Animais')
and c.name = N'Caracteristicas'


SELECT Animal, Caracteristicas,
VECTORPROPERTY(Caracteristicas, 'Dimensions') AS Dimensoes,
VECTORPROPERTY(Caracteristicas, 'BaseType') AS TipoBase
FROM dbo.Animais

/******************************************************
 A função VECTOR_DISTANCE calcula a distância 
 exata entre dois vetores. Quanto menor o resultado, 
 mais próximos eles estão segundo a métrica escolhida.
*******************************************************/
DECLARE @Cachorro vector(8), @Gato vector(8)

SELECT @Cachorro = Caracteristicas
FROM dbo.Animais
WHERE Animal = 'Cachorro'

SELECT @Gato = Caracteristicas
FROM dbo.Animais
WHERE Animal = 'Gato'

-- Cachorro X Gato: 0,333333313465118
SELECT VECTOR_DISTANCE('cosine', @Cachorro, @Gato) AS Distancia

-- Comparando Cachorro com demais animais
SELECT Animal, Caracteristicas,
VECTOR_DISTANCE( 'cosine', @Cachorro, Caracteristicas) AS Distancia
FROM dbo.Animais
WHERE Animal <> 'Cachorro'
ORDER BY Distancia
