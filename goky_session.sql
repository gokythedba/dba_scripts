--||DB Monitoring:--
select logon_time,a.username"USER",a.osuser, a.MACHINE,status, a.INST_ID"INST", a.SID,a.sql_id,a.last_call_et"SEC",cast(a.last_call_et/60as int)"MIN",round(a.last_call_et/60/60,2)"HOUR",a.BLOCKING_INSTANCE"B_INST", a.BLOCKING_SESSION"B_SID",
a.EVENT, wc.WAIT_CLASS,(select b.SQL_TEXT from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) sql_text, (select b.sql_profile from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) sql_profile, (select b.PLAN_HASH_VALUE from v$sqlarea b where 
a.sql_id = b.sql_id and rownum = 1) sql_plan,(select b.SQL_FULLTEXT from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) SQL_FULLTEXT,a.row_wait_obj#,a.row_wait_row#,a.row_wait_block#,a.module,
a.PROGRAM,a.service_name,client_info, 'ALTER SYSTEM KILL SESSION ''' || a.sid || ',' || a.serial# || ', @' || a.inst_id || ''''||';' kill_rac,'kill -9 ' || spid "KILL_OS" from gv$session a, gv$process c, GV$SESSION_WAIT_CLASS wc where 1=1 and 
a.PADDR = c.ADDR and a.INST_ID = c.INST_ID  and a.WAIT_CLASS_ID=wc.WAIT_CLASS_ID and a.inst_id=wc.inst_id and a.sid=wc.SID and event not like 'LogMiner%' and type <> 'BACKGROUND' and a.username not in ('ACTION', 'GOLDENG')
and a.status = 'ACTIVE'
--and blocking_session is not null
--and a.username = 'EUS_DBA' /*Goldengate user: GGATE */
--and osuser='010204'
--and a.inst_id=1  
--and a.sid=292 
--and a.sql_id='06c4vabpgjvu2' 
--and a.client_info='MT41260'
--and module like '%MTS_180%'--GG kontrolü. Replikata(MTS_180) ait session için=>lock? wait? event? ROW_WAIT_OBJ kolonu?/
order by last_call_et desc;

--||Su an hangi userlar aktif olarak çalýþýyor? SQL bazlý görmek istersen sql_id,sql_text kolonlarýný ekle ve group by yap:||
select username,status,count(1),'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE" from (select logon_time,'kill -9 ' || spid "KILL_OS", status, a.INST_ID, a.SID, a.username, a.BLOCKING_INSTANCE,a.BLOCKING_SESSION,a.last_call_et,
cast(a.last_call_et/60as int)"MINUTE",round(a.last_call_et/60/60,2)"HOUR",a.EVENT, a.sql_id,a.module, (select b.sql_profile from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) sql_profile,(select b.PLAN_HASH_VALUE from v$sqlarea b 
where a.sql_id = b.sql_id and rownum = 1) sql_plan,(select b.SQL_TEXT from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) sql_text,a.row_wait_obj#,a.row_wait_row#,a.row_wait_block#,(select b.SQL_FULLTEXT from v$sqlarea b where 
a.sql_id = b.sql_id and rownum = 1) SQL_FULLTEXT,a.PROGRAM,a.osuser, a.MACHINE,a.service_name,client_info,'ALTER SYSTEM KILL SESSION ''' || a.sid || ',' || a.serial# || ', @' || a.inst_id || ''''||';' kill_rac from gv$session a, gv$process c 
where 1=1 and a.PADDR = c.ADDR and a.INST_ID = c.INST_ID and event not like 'LogMiner%' and type <> 'BACKGROUND' and a.username not in ('ACTION', 'GOLDENG') 
and a.status = 'ACTIVE') group by username,status order by count(1) desc;

--||DB'deki session bazli event dagilimi?||
select event,inst_id,status,count(1),'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE" from	(select logon_time,'kill -9 ' || spid "KILL_OS", status, a.INST_ID, a.SID, a.username, a.BLOCKING_INSTANCE, a.BLOCKING_SESSION,a.last_call_et,
cast(a.last_call_et/60as int)"MINUTE",round(a.last_call_et/60/60,2)"HOUR",a.EVENT, a.sql_id,a.module, (select b.sql_profile from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) sql_profile,(select b.PLAN_HASH_VALUE from v$sqlarea b 
where a.sql_id = b.sql_id and rownum = 1) sql_plan,(select b.SQL_TEXT from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) sql_text,a.row_wait_obj#,a.row_wait_row#,a.row_wait_block#,(select b.SQL_FULLTEXT from v$sqlarea b where 
a.sql_id = b.sql_id and rownum = 1) SQL_FULLTEXT,a.PROGRAM,a.osuser, a.MACHINE,a.service_name,client_info,'ALTER SYSTEM KILL SESSION ''' || a.sid || ',' || a.serial# || ', @' || a.inst_id || ''''||';' kill_rac from gv$session a, gv$process c
where 1=1and a.PADDR = c.ADDR and a.INST_ID = c.INST_ID and event not like 'LogMiner%' and type <> 'BACKGROUND' and a.username not in ('ACTION', 'GOLDENG')
and a.status = 'ACTIVE'
--and a.inst_id=1
) group by event,inst_id,status order by count(1) desc;

--DB Alert Logs:
select /*+parallel (4) */* from (select * from table(gv$(cursor(select module_id,ORIGINATING_TIMESTAMP,HOST_ID,replace(replace(message_text, chr(10), ' '), chr(30))"ERROR_TEXT",message_text"FULL_MESSAGE" from v$diag_alert_ext where 1=1	
and ORIGINATING_TIMESTAMP>=trunc(sysdate)
--and upper(host_id) like '%01%' /*Hangi node'u görmek istersen ona göre deðiþebilir*/
and (upper(message_text) like '%ORA-%' or upper(message_text) like '%WARNING%' or upper(message_text) like '%CRITIC%' or upper(message_text) like '%FATAL%' or upper(message_text) like '%ABORT%' or upper(message_text) like '%ERROR%')
order by ORIGINATING_TIMESTAMP desc)))) order by ORIGINATING_TIMESTAMP desc;

--Anlýk DB error log durumu:
select error_date,username,osuser,terminal,HOST_IP,error_text,STATEMENT,client_info from	dbmain.db_error_log where 1=1 and error_Date>=trunc(sysdate) order by error_date desc;

--Process sayýsý(event bazlý) ACTIVE/INACTIVE olarak ayrý ayrý incelenebilir.
select b.event,b.inst_id,status,count(a.tracefile)"PROCESS_COUNT" from	gv$process a, gv$session b where 1=1 and a.addr=B.PADDR(+)
--and status='INACTIVE'
and a.inst_id=b.inst_id(+) group by b.event,b.inst_id,status order by count(a.tracefile) desc,status;

--Beklemede olan sessionlarin event dagilimi:
select inst_id,event, state, count(*) from gv$session_wait group by inst_id,event, state order by 4 desc;

--DB'de açýk kalan transactionlar. Commit/rollback olmayý bekleyen sessionlar. Goldengate burayý her türlü bekler!
select a.sid || ',' || a.serial# SID_SERIAL,substr(a.username,1,12) username,substr(a.program,1,12) program,substr(a.machine,1,18) machine,b.start_time,decode(a.command, 0,'No Command', 1,'Create Table', 2,'Insert', 3,'Select', 6,'Update', 7,'Delete', 9,
'Create Index', 15,'Alter Table', 21,'Create View', 23,'Validate Index', 35,'Alter Database', 39,'Create Tablespace', 41,'Drop Tablespace', 40,'Alter Tablespace', 53,'Drop User', 62,'Analyze Table', 63,'Analyze Index', a.command||': Other') command
from gv$session a, gv$transaction b where a.taddr = b.addr order by b.start_time; 

--TMP / TEMP alan dolduran sessionlar:
SELECT   S.sid || ',' || S.serial# sid_serial,S.username,status,T.blocks * 8192 / 1024 / 1024 mb_used,T.tablespace,Q.sql_fulltext,q.sql_id FROM gv$sort_usage T join gv$session S on T.session_addr = S.saddr left join gv$sqlarea Q on T.sqladdr = Q.address
ORDER BY mb_used desc, sid_serial;

--- Session bazli PGA kullanimini verir 
SELECT DECODE(TRUNC(SYSDATE - LOGON_TIME), 0, NULL, TRUNC(SYSDATE - LOGON_TIME) || ' Days' || ' + ') || TO_CHAR(TO_DATE(TRUNC(MOD(SYSDATE-LOGON_TIME,1) * 86400), 'SSSSS'), 'HH24:MI:SS') LOGON,SID, GV$SESSION.INST_ID ,
gv$session.SERIAL#, gv$process.SPID , ROUND(gv$process.pga_used_mem/(1024*1024), 2) PGA_MB_USED, gv$session.USERNAME, STATUS, OSUSER, MACHINE, gv$session.PROGRAM, MODULE FROM gv$session, gv$process  WHERE gv$session.paddr=gv$process.addr  and GV$SESSION.INST_ID=GV$PROCESS.INST_ID
--and status = 'ACTIVE' 
ORDER BY pga_used_mem DESC;

--Su an açik cursor sayisi
select a.value, s.username, s.sid, s.serial# from v$sesstat a, v$statname b, v$session s where a.statistic# = b.statistic#  and s.sid=a.sid and b.name = 'opened cursors current' 
--and s.username='FCBSOPF'  
order by value desc;

--RAC ortamlar için interconnect IP listesi ve network interface isimleri
select * from	GV$CLUSTER_INTERCONNECTS order by inst_id,ip_address,name;

------------------SQL tuning ve inceleme baþlýyor------------------

--||Kullanicilara sorgu iletme kisayolu:||--
select a.INST_ID,a.SID,logon_time,a.USERNAME,a.OSUSER,a.MACHINE,SERVICE_NAME,SQL_ID,event,round(a.last_call_et/60/60,2)"HOUR",module,a.PROGRAM,(select b.SQL_FULLTEXT from v$sqlarea b where a.sql_id = b.sql_id and rownum = 1) SQL_FULLTEXT
from gv$session a, gv$process c where 1=1and a.PADDR = c.ADDR and a.INST_ID = c.INST_ID and event not like 'LogMiner%' and type <> 'BACKGROUND' and a.username not in ('ACTION', 'GOLDENG')
and a.status = 'ACTIVE'
and sql_id='djap0464g9fvn'
order by logon_time desc;

-- Manual SQL Plan setlenmiþ sorgular:
select sql_id,inst_id,PLAN_HASH_VALUE,sql_profile from	gv$sql where 1=1	
--and sql_id='8nuhz2bvpv4dg'
and sql_profile is not null order by 1,2,3;

--FIXED edilerek sabitlenen(baseline edilen) sql profiller. Genel olarak; sql profilleri plan garantilemez. Sadece plan çýkarýlýrken doðru þekilde çýkarmak için ekstra bilgidir.
--Plan stability baseline'lar ile saðlanabilir. Ýyi çalýþan plan için baselin oluþturup fixed=YES yapabiliriz. Bu þekilde yapýlan sql'ler aþaðýda görünecektir.
--Bu iþlemden sonra baþka planla çalýþmaz. Daha önce farklý planlarla saçma sapan çalýþmasýnýn bir sebebi de optimizer_adaptive_plans parametresinin TRUE kalmýþ olmasý. FALSE yapýlmasý öneririm.
select b.sql_id,sql_handle,a.sql_text,plan_name,origin,created,last_modified,autopurge,fixed,enabled,accepted
from dba_sql_plan_baselines a, gv$sql b where 1=1 and dbms_lob.substr(a.sql_text)=b.sql_text order by 1;

--Manual execution plan görmek için:
select * from gV$SQL_PLAN where 1=1	
and sql_id='6f0x537dy8pq0';

--SQL PLAN kontrol sorgumuz:
select INST_ID, SQL_TEXT, SQL_FULLTEXT, SQL_ID,PLAN_HASH_VALUE"SQL_PLAN" from	gv$sqlarea where 1=1	
and sql_id='7thwvgm6utu72';

--Bizim loglarýmýza göre hangi servis ile geldiði:
select TIMEDATE,USERNAME,OSUSER,MACHINE,PROGRAM,SERVICE_NAME, EVENT,SQL_ID, SQL_TEXT, SQL_FULLTEXT from	dbmain.db_active_session where 1=1	and timedate>sysdate-3
and sql_id='3vacy603t2whg' order by timedate desc;

--SQL Genel Durum:
select inst_id,parsing_schema_name"USER",sql_id,sql_text,plan_hash_value,service,module,action,first_load_time,last_active_time,dbms_lob.substr(sql_fulltext,8000,1)"SORGU" from	gv$sql where sql_id='dtkuwk4w43udp';

--SQL_ID bazýnda çalýþma süresi kontrolü:
select to_char(begin_interval_time,'dd-mm-yyyy hh24:mi:ss') TIME,round(ELAPSED_TIME_delta/1000000/greatest(executions_delta,1),4) "avg duration (sec)",abs(extract(minute from (end_interval_time-begin_interval_time)) + extract(hour from (end_interval_time-begin_interval_time))*60 + extract(day from (end_interval_time-begin_interval_time))*24*60) 
minutes,executions_delta executions,sql_id,a.plan_hash_value,a.instance_number inst_id,(select PARSING_SCHEMA_NAME from gv$sql where sql_id = a.sql_id and rownum = 1) SCHEMA,(select dbms_lob.substr(sql_text,4000,1) from gv$sql where sql_id = a.sql_id and rownum = 1) SQL_TEXT from dba_hist_SQLSTAT a, dba_hist_snapshot b 
where sql_id='031su891d12dx' and a.snap_id=b.snap_id and a.instance_number=b.instance_number and begin_interval_time>sysdate-7 order by a.snap_id desc, a.instance_number;

--SQL Monitoring Report: Ýlgili sql_id bitmiþ olsa da gv$SQL_MONITOR ve gv$SQL_PLAN_MONITOR  view'larýnda varsa çalýþýr:
--CLOB kolonu .hmtl uzantýsý ile kayýt edilerek rapor haline getirilir.
SELECT DBMS_SQLTUNE.report_sql_monitor(sql_id =>'4qd9wmvfy92rw',type=> 'HTML') AS report FROM dual;

--Planý bozuk SQL listesi. Aslýnda daha iyi alternatif execution planlarý bulunan SQL listesini veriyor.
--Bunlarý inceleyip, sorun görürsek carlos scripti ile en iyi execution planlara sabitleyebiliriz: 
select * from (select distinct row_data.*, sql.parsing_schema_name,coalesce(sql.sql_text,'SQL_YOK')"SQL_TEXT",coalesce(dbms_lob.substr(sql.sql_fulltext,4000,1),'SQL_FULLTEXT YOK')"SQL_FULLTEXT" from (
WITH snaps  AS (SELECT /*+  materialize */ dbid, SNAP_ID FROM dba_hist_snapshot s WHERE (begin_interval_time BETWEEN sysdate-4 AND sysdate)) select * from (SELECT t.*, row_number () over (order by impact_secs desc ) seq#
FROM (SELECT DISTINCT  sql_id, FIRST_VALUE (plan_hash_value) OVER (PARTITION BY sql_id ORDER BY pln_avg DESC) worst_plan, FIRST_VALUE (plan_hash_value) OVER (PARTITION BY sql_id ORDER BY pln_avg ASC) best_plan, execs executions
,ROUND (MAX (pln_avg) OVER (PARTITION BY sql_id), 2) worst_plan_et_secs, ROUND (MIN (pln_avg) OVER (PARTITION BY sql_id), 2) best_plan_et_secs, ROUND ( (MAX (pln_avg) OVER (PARTITION BY sql_id) - MIN (pln_avg) OVER (PARTITION BY sql_id)) * execs) impact_secs
,ROUND (MAX (pln_avg) OVER (PARTITION BY sql_id) / MIN (pln_avg) OVER (PARTITION BY sql_id), 2) times_faster FROM (SELECT PARSING_SCHEMA_NAME, sql_id, plan_hash_value, AVG (elapsed_time_delta / 1000000 / executions_delta) OVER (PARTITION BY sql_id, plan_hash_value) pln_avg
,SUM (executions_delta) OVER (PARTITION BY sql_id) execs FROM DBA_HIST_SQLSTAT h WHERE     (dbid, SNAP_ID) IN (SELECT dbid, SNAP_ID FROM snaps) AND NVL (h.executions_delta, 0) > 0)) t)where seq# < 11 
)row_data, gv$sql sql where 1=1 and row_data.sql_id=sql.sql_id(+) and worst_plan_et_secs>0 and best_plan_et_secs>0 and worst_plan_et_secs>best_plan_et_secs ORDER BY seq#) where executions>100;

--Yukarýdan yola çýkarak: Genel uzun süren sorgu kontrolü:Yangýn tespiti için kullanýlýr. Son 3 saatte 3000'den fazla çalýþmýþ SQL'lerin bu aralýktaki ortalama tamamlanma süresi:
select 'Son 3 saatte 3000 seferden fazla çalýþan SQL listesi' "INFO",sql_id,round(avg(avg_dur),4)"AVG_DUR" ,sum(executions)"TOTAL_EXECS"from	(select /*+parallel (2) */ to_char(begin_interval_time,'dd-mm-yyyy hh24:mi:ss') TIME,round(ELAPSED_TIME_delta/1000000
/greatest(executions_delta,1),4) "AVG_DUR",abs(extract(minute from (end_interval_time-begin_interval_time)) + extract(hour from (end_interval_time-begin_interval_time))*60 + extract(day from (end_interval_time-begin_interval_time))*24*60) minutes,
executions_delta executions,sql_id,a.plan_hash_value,a.instance_number inst_id,a.snap_id from dba_hist_SQLSTAT a, dba_hist_snapshot b where 1=1 and a.snap_id=b.snap_id and a.instance_number=b.instance_number and begin_interval_time>=
SYSDATE-3/24 /*son 3  saat*/ order by snap_id desc, a.instance_number) where 1=1 and avg_dur is not null and executions>=3000 group by sql_id order by 3 desc,4 desc;

--Cluster wait time'i yüksek sorgular:
SELECT sql_id,round(SUM (cluster_wait_time / 1000000)) total_cluster_time,round((sum(elapsed_time) / 1000000)) total_elaped_time,round((sum(elapsed_time) / 1000000) / COUNT (*)) elaped_per_exec ,round(SUM (cluster_wait_time / 1000000)
/COUNT (*)) cluster_time_per_exec,ROUND (SUM (buffer_gets) / COUNT (*)) buffer_gets_per_exec, COUNT (*) FROM gv$sql_monitor WHERE sql_exec_start > SYSDATE - 1 / 72 AND cluster_wait_time > 1000000 group by sql_id ORDER BY 7 DESC;

------------------SQL tuning ve inceleme bitti------------------

------------------Analiz Meselesi Baþlýyor------------------

--DB'deki tüm tablolarýn yüzde kaçýnýn istatistikleri stale konumda. DB'de ne kadar tablonun analiz geçilmeye ihtyiacý var? Genel resmi görmek için:
select case when(stale_stats = 'YES' or stale_stats is null) then 'STALE' else 'NOT_STALE' end"STALE_STATUS",count(1),'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE"  from	dba_tab_statistics
group by case when(stale_stats = 'YES' or stale_stats is null) then 'STALE' else 'NOT_STALE' end order by 3 desc;

--STALE durumunda olan TABLOLARIN þema sahipliði daðýlýmý:
select * from	(select owner,case when(stale_stats = 'YES' or stale_stats is null) then 'STALE' else 'NOT_STALE' end"STALE_STATUS",count(1),'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE"  from	dba_tab_statistics where 1=1	
and owner not in ('RMAN','SYSMAN','DBMAIN','SYSTEM','SYS','XDB','ANONYMOUS','CTXSYS','OUTLN','APPQOSSYS','WMSYS','DIP','MGMT_VIEW','ORAACS','ORDSYS','ORDDATA','ORDPLUGINS','MDSYS','MDDATA','DBSNMP','SI_INFORMTN_SCHEMA') 
and owner not like 'OLAPSYS%'and owner not like '%$%'and owner not like 'DBA%'and owner not like '%_OCM%'and owner not like 'EUS_%' and owner not like 'TTNET%'and owner not like 'SQLTX%'and owner not like 'APEX_%'
and owner not like 'SPATIAL_%' group by case when(stale_stats = 'YES' or stale_stats is null) then 'STALE' else 'NOT_STALE' end,owner ) where 1=1 and stale_status='STALE' order by 4 desc;

----STALE statüde olan INDEKSLERÝN þema sahipliði daðýlýmý:
select * from	(select owner,case when(stale_stats = 'YES' or stale_stats is null) then 'STALE' else 'NOT_STALE' end"STALE_STATUS",count(1),'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE"  from	dba_ind_statistics where 1=1	
and owner not in ('RMAN','SYSMAN','DBMAIN','SYSTEM','SYS','XDB','ANONYMOUS','CTXSYS','OUTLN','APPQOSSYS','WMSYS','DIP','MGMT_VIEW','ORAACS','ORDSYS','ORDDATA','ORDPLUGINS','MDSYS','MDDATA','DBSNMP','SI_INFORMTN_SCHEMA') 
and owner not like 'OLAPSYS%'and owner not like '%$%'and owner not like 'DBA%'and owner not like '%_OCM%'and owner not like 'EUS_%' and owner not like 'TTNET%'and owner not like 'SQLTX%'and owner not like 'APEX_%'
and owner not like 'SPATIAL_%' group by case when(stale_stats = 'YES' or stale_stats is null) then 'STALE' else 'NOT_STALE' end,owner )  where 1=1 and stale_status='STALE' order by 4 desc;

--STALE durumunda olan TABLOLARIN son analiz tarihine göre daðýlýmý. Ýstenirse saat kýrýlýmý eklenebilir:
select to_char (LAST_ANALYZED, 'dd-mm-yyyy')"LAST_ANALYZED_TARIH",count(1)"STALE_TABLE_COUNT",'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE"	from	dba_tab_statistics where 1=1	
and (stale_stats = 'YES' or stale_stats is null) group by to_char (LAST_ANALYZED, 'dd-mm-yyyy') order by count(1) desc;

--Ýstatiskleri stale ya da eksik olan tüm TABLOLARIN listesi. Þema bazlý ya da tablo bazlý bakýlabilir: 
--Toplu halde analiz geçmek için kullanýlabilir
select OWNER, TABLE_NAME, OBJECT_TYPE,GB_SIZE,NUM_ROWS,STALE_STATS, LAST_ANALYZED,GLOBAL_STATS, USER_STATS, STATTYPE_LOCKED, PARTITION_NAME, PARTITION_POSITION, SUBPARTITION_NAME, SUBPARTITION_POSITION, 
'begin dbms_stats.gather_table_stats( ownname=> '''||owner||''', tabname=> '''||table_name||''',estimate_percent=>dbms_stats.auto_sample_size, degree=> 64); end;'  "KOMUT" from (select a.OWNER,TABLE_NAME,OBJECT_TYPE,STALE_STATS,LAST_ANALYZED,
NUM_ROWS,GLOBAL_STATS,USER_STATS,STATTYPE_LOCKED,a.PARTITION_NAME,PARTITION_POSITION, SUBPARTITION_NAME,SUBPARTITION_POSITION,sum(cast(bytes/1024/1024/1024 as int))"GB_SIZE"from dba_tab_statistics a,dba_segments b where 1=1 
and a.owner=a.owner and a.table_name=b.segment_name and object_type='TABLE' and (stale_stats = 'YES' or stale_stats is null) 
and a.owner like '%NNO%' 
group by a.OWNER,a.TABLE_NAME,OBJECT_TYPE,STALE_STATS,LAST_ANALYZED,NUM_ROWS,GLOBAL_STATS,USER_STATS,STATTYPE_LOCKED,a.PARTITION_NAME,PARTITION_POSITION, SUBPARTITION_NAME,SUBPARTITION_POSITION
having sum(cast(bytes/1024/1024/1024 as int))>0 order by gb_size desc);

--Ýstatiskleri stale ya da eksik olan tüm INDEKSLERÝN listesi. Þema bazlý ya da tablo bazlý bakýlabilir:
select OWNER||'.'||INDEX_NAME"INDEX_NAME",OWNER||'.'||TABLE_NAME"TABLE_NAME",OBJECT_TYPE,STALE_STATS,LAST_ANALYZED,NUM_ROWS,GLOBAL_STATS,USER_STATS,STATTYPE_LOCKED,PARTITION_NAME,PARTITION_POSITION,
SUBPARTITION_NAME,SUBPARTITION_POSITION from dba_ind_statistics where 1=1
and owner like '%NNO%'
--and INDEX_NAME='H4C_CELL'
--and table_name='TASKPERIODS'
and (stale_stats = 'YES' or stale_stats is null) order by LAST_ANALYZED;

--Automated Maintenance Tasks'lar açýk mý deðil mi bakabiliyoruz:
select * from	DBA_AUTOTASK_OPERATION;

--Auto Stats joblarýnýn çalýþma loglarý:
select * from	DBA_AUTOTASK_JOB_HISTORY
where 1=1	
and client_name='auto optimizer stats collection' order by JOB_START_TIME desc;

--Auto Stats joblarýnýn çalýþma günlük özet. Baþarýlý/baþarýsýz biten object sayýsý:
select * from	DBA_AUTO_STAT_EXECUTIONS where 1=1 order by start_time desc; 

--Object bazýnda Auto Stats job logu ve detayý:
select * from	dba_optstat_operation_tasks where 1=1	
and target like '%H3P_67109378_H%' /*object(tablo) adý*/ order by start_time desc;

--FAILED statüsünde kalan auto stats operasyonlarýnýn aldýðý ORA hatalarý:
--Auto stats hata alanlarýn dökümü. Burada TIMED OUT olanlarýn start ve end saati ayný ise demek ki ayrýlan WINDOW yetmiyor. 
--Bu durumda auto stat için ayrýlan WINDOW aralýðýný geniþletmen lazým. Ancak dikkat et analiz job'u CPU harcar!
select * from	dba_optstat_operation_tasks where 1=1	
and start_time>sysdate-7
and upper(status)<>'COMPLETED'
and upper(notes) like '%ORA-%' order by start_Time desc;

--Buradaki window yetmiyor ise bunu geniþlet. Ancak dikkat et analiz job'u CPU harcar!
select * from dba_scheduler_windows order by 2;

--In that case, the priority is to gather statistics. That can be long. Then I run the job manually:
exec dbms_auto_task_immediate.gather_optimizer_stats;

--If I want to kill the manual job, because one table takes really too long and I decide to skip it for the moment, here is my query to find it:
select 'alter system kill session '''||sid||','||serial#||',@'||inst_id||''' /* '||action||' started on '||logon_time||'*/;' "Kill me with this:" from gv$session where module='DBMS_SCHEDULER' and action like 'ORA$AT^_OS^_MANUAL^_%' escape '^' ;

--Before killing, I’ll check the long queries from it with the goal to find a solution for it:
select executions,users_executing,round(elapsed_time/1e6/60/60,1) hours,substr(coalesce(info,sql_text),1,60) info,sql_id from gv$sql natural left outer join (select address,hash_value,sql_id,plan_hash_value,child_address,child_number,id,
rtrim(operation||' '||object_owner||' '||object_name) info from gv$sql_plan where object_name is not null) where elapsed_time>1e6*10*60 and action like 'ORA$AT_OS_%' order by last_active_time,id;


--Table full analyze: Tabloya analiz geçmek DDL veya DML lock koymaz ancak üzerinden mevcut operasyonlarý yavaþlatabilir. O yüzden ya gece ya müsait zaman yapýlmasýnda fayda var. Analiz iþleri UNDO alanda doluluða sebep olabilir.
begin
dbms_stats.gather_table_stats( ownname=> 'DM', tabname=> 'MV_CUSTOMER_PROFILING',estimate_percent=>dbms_stats.auto_sample_size, degree=> 16);
end;

--Partition bazlý analyze: Tabloya analiz geçmek DDL veya DML lock koymaz ancak üzerinden mevcut operasyonlarý yavaþlatabilir. O yüzden ya gece ya müsait zaman yapýlmasýnda fayda var. Analiz iþleri UNDO alanda doluluða sebep olabilir.
begin
dbms_stats.gather_table_stats( ownname=> 'DM', tabname=> 'FACT_UNR_SUBS_BTS_MONTHLY' ,estimate_percent=>dbms_stats.auto_sample_size, degree=> 32,granularity=>'PARTITION', partname=>'PTI_201212');
end;

--Tabloya istatistik lock'ý koyup / kaldýrmak için:
exec dbms_stats.unlock_table_stats('DBMAIN', 'GOKY_DENEME');
exec dbms_stats.lock_table_stats('DBMAIN', 'GOKY_DENEME');

------------------Analiz Meselesi Bitiyor------------------

------------------Rollback ve Recovery Olaylarý Baþlýyor------------------

--||Sessions|--
--Bir kodu (update mesela) cancel ettigimizde asagidaki kod ile rollback'in bitip bitmedigini görebiliyoruz. Yeni processe(update'e mesela) hazir olup olmadigini görebiliyoruz.
--Eðer bir session'ý kill ediyorsan, ya da disconnect session basýyorsan(ki sunucu üstünden pid ile kill etmekle ayný) ve gitmiyorsa KILLED olarak kalýyorsa tabloda rollback vardýr. Onu bekliyordur:
SELECT logon_time,ORACLE_USERNAME,O.OWNER||'.'||O.OBJECT_NAME OBJECT,sql_id,l.inst_id,SID,S.serial#,P.SPID OS_PID,DECODE(L.LOCKED_MODE, 0,'NONE',1,'NULL',2,'ROW SHARE',3,'ROW EXCLUSIVE',4,'SHARE',5,'SHARE ROW EXCLUSIVE',6,'EXCLUSIVE',
NULL) LOCK_MODE FROM sys.GV_$LOCKED_OBJECT L, DBA_OBJECTS O, sys.GV_$SESSION S, sys.GV_$PROCESS P WHERE L.OBJECT_ID = O.OBJECT_ID and l.inst_id = s.inst_id AND L.SESSION_ID = S.SID and s.inst_id = p.inst_id AND S.PADDR = P.ADDR(+) order by 3,1 desc;

--Rollback'in bitmesine ne kadar kaldý? Ýlk kolon 0'a yaklaþtýkca bitiyor rollback
SELECT t.USED_UBLK, s.username, s.machine, s.program FROM V$TRANSACTION t, v$session s where t.addr = s.taddr;

--Displays information about the progress of the transactions that Oracle is recovering
--DML sonrasinda rollback'e bagli recover yapiliyorsa buradan kontrol edilebilir:
select inst_id,usn,pid,state,undoblockstotal "Total",undoblocksdone "Done",undoblockstotal - undoblocksdone "ToDo",cputime,xid,pxid,rcvservers,decode(cputime,0,'unknown',sysdate + (((undoblockstotal - undoblocksdone) /decode((undoblocksdone / cputime),0,1,
(undoblocksdone / cputime))) / 86400)) "Estimated time to complete"  from gv$fast_start_transactions  order by 12 desc;

------------------Rollback ve Recovery Olaylarý Bitti------------------

------------------REDO Log Analizleri Baþlýyor------------------

--log switch üretme trendi. Yüksek DML oldugunda yüksek sayida log dosyasi görürüz:
select to_char(FIRST_TIME,'DY, DD-MON-YYYY') day,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'00',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'00',1,0))) d_0,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'01',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'01',1,0))) d_1,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'02',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'02',1,0))) d_2,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'03',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'03',1,0))) d_3,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'04',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'04',1,0))) d_4,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'05',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'05',1,0))) d_5,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'06',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'06',1,0))) d_6,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'07',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'07',1,0))) d_7,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'08',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'08',1,0))) d_8,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'09',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'09',1,0))) d_9,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'10',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'10',1,0))) d_10,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'11',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'11',1,0))) d_11,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'12',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'12',1,0))) d_12,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'13',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'13',1,0))) d_13,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'14',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'14',1,0))) d_14,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'15',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'15',1,0))) d_15,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'16',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'16',1,0))) d_16,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'17',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'17',1,0))) d_17,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'18',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'18',1,0))) d_18,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'19',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'19',1,0))) d_19,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'20',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'20',1,0))) d_20,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'21',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'21',1,0))) d_21,decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'22',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'22',1,0))) d_22,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'23',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'23',1,0))) d_23,count(trunc(FIRST_TIME)) "Total" from v$log_history group by to_char(FIRST_TIME,'DY, DD-MON-YYYY')order by to_date(substr(to_char(FIRST_TIME,'DY, DD-MON-YYYY'),5,15) ) desc;

--Redo Log Size Kontrolü:
select a.inst_id,a.group#,thread#,member,a.status,bytes/1024/1024 mb from gv$log a, gv$logfile b where 1=1	 and a.inst_id=b.inst_id and b.group#=a.group# order by 2,1;
 
 --Saatlik kaç GB arþiv üremiþ: (RAC ortamda gv ayrýmý ?)
select coalesce(to_char (first_time, 'yyyy-mm-dd-hh24'),'SUM')"SAAT",sum(round(blocks*block_size/1024/1024/1024,0)) "REDO_SIZE_GB" from v$archived_log 
where first_time>=trunc(sysdate) and dest_id=1  group by rollup(to_char (first_time, 'yyyy-mm-dd-hh24')) order by 1 desc;
 
--Who is generating redo logs now?
select b.inst_id, lpad((b.SID || ',' || lpad(b.serial#,5)),11) sid_serial, b.username, machine, b.osuser, b.status, a.redo_mb from (select n.inst_id, sid, round(value/1024/1024) redo_mb from gv$statname n, gv$sesstat s
where n.inst_id=s.inst_id and n.name = 'redo size' and s.statistic# = n.statistic# order by value desc) a, gv$session b where b.inst_id=a.inst_id and a.sid = b.sid and rownum <= 30 order by redo_mb desc;

--Anlýk REDO üreten sorgular:
select logon_time,a.inst_id,a.sid,sql_id,status,username,osuser,machine,round(value/1024/1024,2) redo_mb from gv$session a,gv$sesstat S,gv$statname n where 1=1	 and a.sid=s.sid and a.inst_id=s.inst_id and n.statistic#=s.statistic# and n.inst_id
=s.inst_id and a.event not like 'LogMiner%' and a.type <> 'BACKGROUND' and a.username not in ('ACTION','GOLDENG','GGATE')and a.status = 'ACTIVE' and n.name='redo size' and round(value/1024/1024,2)>0 order by redo_mb desc;

--Which objects/segments are generating redo logs? (for Today)
SELECT to_char(begin_interval_time,'DD.MM.YYYY HH24:MI') snap_time,dhso.object_name,sum(db_block_changes_delta) BLOCK_CHANGED FROM dba_hist_seg_stat dhss,dba_hist_seg_stat_obj dhso,dba_hist_snapshot dhs
WHERE dhs.snap_id = dhss.snap_id AND dhs.instance_number = dhss.instance_number AND dhss.obj# = dhso.obj# AND dhss.dataobj# = dhso.dataobj# AND begin_interval_time>=trunc(sysdate) GROUP BY to_char(begin_interval_time,'DD.MM.YYYY HH24:MI'), 
dhso.object_name HAVING sum(db_block_changes_delta) > 0 ORDER BY sum(db_block_changes_delta) desc;

--What SQL was causing redo log generation (for Today)
SELECT to_char(begin_interval_time,'DD.MM.YYYY HH24:MI') WHEN,dhss.instance_number INST_ID,dhss.sql_id,executions_delta exec_delta,rows_processed_delta rows_proc_delta,dbms_lob.substr(sql_text,1000,1) SQL FROM dba_hist_sqlstat dhss,
dba_hist_snapshot dhs,dba_hist_sqltext dhst WHERE /*upper(dhst.sql_text) LIKE '%USR_RACUNI_MV%' */ ltrim(upper(dhst.sql_text)) NOT LIKE 'SELECT%' AND dhss.snap_id=dhs.snap_id AND dhss.instance_number=dhs.instance_number AND dhss.sql_id=dhst.sql_id
AND begin_interval_time>=trunc(sysdate) and rows_processed_delta is not null order by ROWS_PROC_DELTA desc;

--Query based on segment directly (for Today)
SELECT to_char(begin_interval_time,'dd-mm-yyyy hh24:mi:ss') snap_time, sum(db_block_changes_delta) FROM dba_hist_seg_stat dhss,dba_hist_seg_stat_obj dhso,dba_hist_snapshot dhs WHERE dhs.snap_id = dhss.snap_id AND dhs.instance_number=dhss.instance_number 
AND dhss.obj# = dhso.obj# AND dhss.dataobj# = dhso.dataobj# and begin_interval_time>=trunc(sysdate) AND dhso.object_name = 'HT_HATIRLATICI' GROUP BY to_char(begin_interval_time,'dd-mm-yyyy hh24:mi:ss') ORDER BY to_char(begin_interval_time,'dd-mm-yyyy hh24:mi:ss') desc;

------------------REDO Log Analizleri Bitiyor------------------

------------------gv$active_session_history ve DBA_HIST_ACTIVE_SESS_HISTORY olaylarý baþlýyor------------------

--RAC analizlerinin anasý bu view! DBA_HIST_ACTIVE_SESS_HISTORY'den daha üstün. Çünkü DBA_HIST_ACTIVE_SESS_HISTORY 10 sn'den bir sample alýyor.
--Bundan ötürü DBA_HIST_ACTIVE_SESS_HISTORY'dan yapýlan analizler biraz havada kalýyoýr. Yapýlabiliyorsa aþaðýdaki view'dan bakýlmalý. Çok data tutmamasý tek negatif yönü.
select * from	gv$active_session_history;

--Ýlgili gün için gc wait event sayýlarýnýn saatlik daðýlýmý. RAC ortamlarda interconnect dolayýsýyla NW problemlerini analiz etmekte kullanýlýr:
select to_char (sample_time, 'yyyy-mm-dd--hh24')"SAAT",count(1),'%'||substr(count(*) / sum(count(*)) over ()*100,0,5)"YUZDE"	 from	DBA_HIST_ACTIVE_SESS_HISTORY where 1=1	
and sample_time>=to_date ('03-11-2022 00:00:00', 'dd-mm-yyyy hh24:mi:ss')
and sample_time<to_date ('04-11-2022 00:00:00', 'dd-mm-yyyy hh24:mi:ss')	
and lower(event) LIKE '%gc%' 
group by to_char (sample_time, 'yyyy-mm-dd--hh24') order by 1;

--Yukaridaki gc wait event analizin servis bazlý kýrýlýmý:
--Sonrasýnda detaylý analiz etmek için yapýlan iþlem türü için(UPDATE/SELECT) saat bazlý count bakýlabilir:
select name"SERVICE",INSTANCE_NUMBER,SQL_OPNAME,machine,count(1) from	DBA_HIST_ACTIVE_SESS_HISTORY a, GV$SERVICES b where 1=1	
and a.service_hash=b.name_hash and a.instance_number=b.inst_id
and sample_time>=to_date ('12-11-2022 00:00:00', 'dd-mm-yyyy hh24:mi:ss')
and sample_time<to_date ('12-11-2022 01:00:00', 'dd-mm-yyyy hh24:mi:ss')	
and lower(event) LIKE '%gc%'
group by name,INSTANCE_NUMBER,SQL_OPNAME,machine order by count(1) desc;

--Ýlgili tarih aralýðýnda çalýþan ve SELECT harici operasyon yapan schedule job sessionlarý:
select /*+parallel (4) */sorgu.SERVICE, USERNAME"USER", INSTANCE_NUMBER"INST", SQL_OPNAME, MACHINE, sorgu.MODULE, PROGRAM, sorgu.ACTION, sorgu.sql_id,COUNTX,nvl(SQL_TEXT,'SQL_YOK')"SQL_TEXT" from	(
select name"SERVICE",username,INSTANCE_NUMBER,SQL_OPNAME,machine,module,program,action,sql_id,count(1)"COUNTX" from	DBA_HIST_ACTIVE_SESS_HISTORY a, GV$SERVICES b, dba_users c where 1=1 and a.service_hash=b.name_hash 
and a.instance_number=b.inst_id and a.user_id=c.user_id
and sample_time>=to_date ('21-11-2022 23:00:00', 'dd-mm-yyyy hh24:mi:ss')
and sample_time<to_date ('21-11-2022 23:59:00', 'dd-mm-yyyy hh24:mi:ss')	
and module='DBMS_SCHEDULER'
and sql_opname<>'SELECT'
--and lower(event) LIKE '%gc%'
group by name,username,INSTANCE_NUMBER,SQL_OPNAME,machine,module,program,action,sql_id) sorgu,gv$sql b where sorgu.instance_number=b.inst_id(+) and sorgu.sql_id=b.sql_id(+) group by sorgu.SERVICE, USERNAME, INSTANCE_NUMBER, 
SQL_OPNAME, MACHINE, sorgu.MODULE, PROGRAM, sorgu.ACTION, sorgu.sql_id,COUNTX,nvl(SQL_TEXT,'SQL_YOK')order by COUNTX desc;

------------------gv$active_session_history ve DBA_HIST_ACTIVE_SESS_HISTORY olaylarý bitti------------------

------------------Raporlar baþlýyor------------------

--||Geriye dönük hata analizleri raporumuz:||
select username,osuser,host_ip,terminal,count(1)"COUNT",error_text,STATEMENT from	dbmain.db_error_log where 1=1	
and error_Date>=trunc(sysdate)-15
--and errorno=60 /*hangi hata kodu araniyorsa*/
--and USERNAME='HDABI_USER'
group by username,osuser,host_ip,terminal,error_text,STATEMENT order by count(1) desc;

--Geriye dönük DB'ye kim ne geliyor standart raporumuz:
select username,osuser,machine,ip_address,status,count(1) from  DBMAIN.DB_LOGIN_LOG where 1=1	
and logon_time>=trunc(sysdate)-31	
and logon_time<trunc(sysdate)
and status='S' /* Status success olanlar */
and username not in ('SYS','DBMAIN','DBSNMP','GOLDENG')
--and username not like '%EUS%' /*Son kullanicilar elensin*/
--and username not like 'DBA%' /*DBAler elensin*/
group by username,osuser,machine,ip_address,status order by count(1) desc,username,machine;

--Belirli bir user için belirli bir tarih araligindaki tüm aktif sessionlarin geçmisi raporu:
select TIMEDATE,username,INST_ID,SID,sql_id,last_call_et"SECONDS",SQL_TEXT,PROGRAM, OSUSER, MACHINE, SERVICE_NAME from	DBMAIN.DB_ACTIVE_SESSION where 1=1	
and timedate>=to_date ('20-04-2020 10:30:00', 'dd-mm-yyyy hh24:mi:ss')	
and timedate<=to_date ('20-04-2020 12:00:00', 'dd-mm-yyyy hh24:mi:ss')
and username='UP_TT_CC_READ'
order by TIMEDATE;

------------------Raporlar bitti------------------