Para usar o **DBCC CHECKDB** no SQL Server, siga estes passos:  

### 1. Verificar a integridade do banco de dados  
Execute o comando abaixo para verificar a integridade do banco de dados (por exemplo, `VendasDB`):  
```sql 
DBCC CHECKDB (VendasDB) WITH NO_INFOMSGS, TABLERESULTS 
```  
- Esse comando verifica a consistência lógica e física das páginas, tabelas e índices do banco. 
- O parâmetro `WITH NO_INFOMSGS` suprime mensagens informativas. 
- O parâmetro `TABLERESULTS` retorna os resultados em formato de tabela.  


### 2. Reparar corrupção (caso necessário)  
Se o comando acima identificar corrupção e você **não tiver backup**, pode tentar reparar (com risco de perda de dados):  
```sql 
ALTER DATABASE VendasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE 
DBCC CHECKDB (VendasDB, REPAIR_ALLOW_DATA_LOSS) 
ALTER DATABASE VendasDB SET MULTI_USER 
```  

> **Atenção:** O modo `REPAIR_ALLOW_DATA_LOSS` pode causar perda de dados. Use apenas como último recurso.  

### 3. Consultar páginas suspeitas  
Você pode consultar o histórico de páginas suspeitas detectadas:  
```sql 
SELECT * FROM msdb..suspect_pages 
```  

---  **Resumo:**   
- Use `DBCC CHECKDB (NomeDoBanco)` para verificar integridade. 
- Use opções de reparo apenas se não houver backup e ciente dos riscos. 
- Consulte páginas suspeitas em `msdb..suspect_pages`.  

Se precisar de mais detalhes sobre opções do comando, informe!