--|DATAGUARD SCRIPTS|--
--If you want to learn which of database is Standby and which of database is Primary, you can execute below query.
SELECT database_role, open_mode FROM gv$database;

--Standby (FKM) tarafında çalıştırılır:
--DG Controlfile Time sorgumuz. Dataguard'in saati. Bu degisiyorsa ve güncelse sorun yok demek:
select name, controlfile_time from gv$database; 

--Primary(prod) tarafta çalıştırılır:
--Dataguard durum kontrol, hata takip:
select * from	gv$dataguard_status where 1=1	 and timestamp>sysdate-1 order by timestamp desc;

--Primary(prod) ortamda çalıştırılır:
--Primary ortamdan kaç tane node varsa, hangisinden en son hangi arşiv üremiş ve bunların hangileri standy'da apply edilmiş onu gösterir.
--Node sayısı decode olarak 2 verilmiş ama pandora gibi sistemlerde 6 node olduğu için 6 sonuç döndürür haliyle.
--Prod ile standby arasındaki SEQUENCE# farkı 2 den büyük se => olarak görünecek fark kolonu.
--The query below shows the latest archives on Primary and Standby. It shows the last archive produced in Primary and the last archive applied to Standby
SELECT a.resetlogs_id, DECODE (a.thread#, 1, 'node1', 2, 'node2') HOST, b.last_seq prmy_last_file,
      a.applied_seq stdby_last_file, CASE WHEN b.last_seq - a.applied_seq > 2 THEN '=>' ELSE to_char(b.last_seq - a.applied_seq) END archive_difference, TO_CHAR (a.latest_apply_time, 'dd/mm/yyyy hh24:mi:ss') stdby_latest_time
 FROM (SELECT   resetlogs_id, thread#, MAX (sequence#) applied_seq, MAX (next_time) latest_apply_time
           FROM v$archived_log
          WHERE applied = 'YES'
       GROUP BY resetlogs_id, thread#) a,
      (SELECT   resetlogs_id, thread#, MAX (sequence#) last_seq
           FROM v$archived_log
       GROUP BY resetlogs_id, thread#) b
WHERE a.thread# = b.thread#
ORDER BY a.thread#;

--Standby(FKM) tarafta çalıştırılır.
--Your dataguard is running but is there any lag ? You can learn below script.
select name,value from gv$dataguard_stats;

--Standby (FKM) ortamda çalıştırılır.
--Transport lag ve apply lag görebilirsin:
SELECT time_computed time_computed,MAX (CASE name WHEN 'transport lag' THEN VALUE ELSE NULL END)AS transport_lag,
MAX (CASE name WHEN 'apply lag' THEN VALUE ELSE NULL END)AS apply_lag,
MAX (CASE name WHEN 'apply finish time' THEN VALUE ELSE NULL END) AS apply_finish_time 
FROM gv$dataguard_stats GROUP BY time_computed;

--Standby (FKM) tarafında çalıştırılır. 
--Hangi prod node'dan en son hangi SEQUENCE# üremiş ve bunun ne kadarı standy'da apply edilmiş, aradaki fark nedir sorgusu:
--If you want to know which archive sequence number comes from Piramary database lastly and which is lasp applied in Standby:
SELECT ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last in Sequence", APPL.SEQUENCE# "Last Applied Sequence", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "Difference"
FROM (SELECT THREAD# ,SEQUENCE# FROM V$ARCHIVED_LOG WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$ARCHIVED_LOG GROUP BY THREAD#)) ARCH,
(SELECT THREAD# ,SEQUENCE# FROM V$LOG_HISTORY WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$LOG_HISTORY GROUP BY THREAD#)) APPL
WHERE ARCH.THREAD# = APPL.THREAD# ORDER BY 1;

--Dataguard Compact-1
--Bu sorguyu ise prod(primary) ortamda çalıştır. Buradaki SEQUENCE$'ler standby'a da ship edilmiş olmalı.
--Bir eksiklik varsa böyle bulabilirsin. dest_id standby'ın kayıtlı olduğu yere göre değişecek haliyle:
--Buradaki en gücel sequence# aşağıdaki managed_standby sorgusunda işlenmiş olması gerekir.
select * from gv$archived_log
--where dest_id=12 /*optional => dest_id=12 DRIHOPE içindi*/
--and thread#=1 /*optional*/
order by sequence# desc;

--Dataguard Compact-2
--Bu sorguyu MRP'nin çalıştığı dataguard ortamda çalıştır. PROCESS ismi MRP,RFS,ARCH olanlara bakılır.
--Yukarıda bulduğumuz en güncel SEQUENCE# burda işlenmiş ve bir sonraki yeni SEQUENCE# değerine geçilmiş olması ve BLOCK# değerinin de sürekli güncellenmesi gerekir normalde.
--Değişmiyorsa ya da o #SEQUENCE hiç yoksa ,o zaman o sequence'e ait dosya ile ilgili problem olabilir. ASM üzerinden bak, eğer yoksa manual olarak standby'a taşıyıp sonra db'ye register etmek gerekebilir:
SELECT thread#, process, pid, status, client_process, client_pid, sequence#, block#, GROUP# ,active_agents, known_agents,DELAY_MINS FROM gv$managed_standby
--where STATUS<>'IDLE' -- keep in mind RFS is %99 idle when you query
where CLIENT_PROCESS<>'UNKNOWN' --rfs lgwr is seen in that condition
--ORDER BY thread#, process;
order by sequence# desc;

--Dataguard Compact-3
--Bu sorguyu MRP'nin çalıştığı dataguard ortamda çalıştır.
--Burada en çok hangi event'lerde beklediğini görüyoruz. Beklediği yere göre de aksiyon planımızı çıkartıyoruz.
--Örneğin checkpoint completed event'inde en çok bekleme görünüyorsa buna iyileştirme yapmak için LGWR processlerinde bir iyileştirme gerekir.
--Çünkü checkpoint sıkışması demek log writer'da sıkışma demek. Logları yazabilsin ki checkpoint tamamlanabilsin. dataguard ortamda db_writer_processes parametresini 12'den 16'ya çıkartmak gibi bir aksiyon alınabilir.
select * from (  select a.event_id, e.name, sum(a.time_waited) total_time_waited  from gv$active_session_history a, gv$event_name e  where a.event_id = e.event_id and a.inst_id=e.inst_id and a.program like '%(PR%'  
and a.SAMPLE_TIME>=(sysdate-30/(24*60))  group by a.event_id, e.name order by 3 desc)  where rownum < 11;

--Dataguard Compact-4
--Bu sorguyu MRP'nin çalıştığı dataguard ortamda çalıştır.
--Average Apply Rate ile Data guard'ın hangi hız ile apply ettiğini görebiliyoruz. Average bakıyoruz çünkü daha stabil bir bilgi veriyor.
select * from	gv$recovery_progress where 1=1	
--and item='Average Apply Rate'
order by item;

--Hepsini birleştiren tek sorgu: COMPACT
--Bu sorguyu MRP'nin çalıştığı dataguard ortamda çalıştır.
select /*+parallel (4) */ sysdate"REPORT_DATE",NAME,DB_UNIQUE_NAME,LOG_MODE,open_mode,DATABASE_ROLE,CONTROLFILE_TIME, round((sysdate-CONTROLFILE_TIME)*24,1) "LAG_HOURS",(select TRANSPORT_LAG from (SELECT MAX (CASE name WHEN 'transport lag' THEN VALUE ELSE NULL END)AS transport_lag, MAX (CASE name WHEN 'apply lag' THEN VALUE ELSE NULL END)AS apply_lag 
FROM gv$dataguard_stats GROUP BY time_computed) where 1=1      and (TRANSPORT_LAG is not null and APPLY_LAG is not null))"TRANSPORT_LAG",(select APPLY_LAG from       (SELECT MAX (CASE name WHEN 'transport lag' THEN VALUE ELSE NULL END)AS transport_lag, MAX (CASE name WHEN 'apply lag' THEN VALUE ELSE NULL END)AS apply_lag 
FROM gv$dataguard_stats GROUP BY time_computed) where 1=1      and (TRANSPORT_LAG is not null and APPLY_LAG is not null))"APPLY_LAG",(select avg(SOFAR)||' '||UNITS from         gv$recovery_progress where 1=1 and item='Average Apply Rate' group by UNITS)"AVG_APPLY_RATE",(select sum(DIFFERENCE) from     (SELECT ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last in Sequence", APPL.SEQUENCE# "Last Applied Sequence", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "DIFFERENCE"FROM 
(SELECT THREAD# ,SEQUENCE# FROM V$ARCHIVED_LOG WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$ARCHIVED_LOG GROUP BY THREAD#)) ARCH, (SELECT THREAD# ,
SEQUENCE# FROM V$LOG_HISTORY WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$LOG_HISTORY GROUP BY THREAD#)) APPL WHERE ARCH.THREAD# = APPL.THREAD# ))"MISSING_#OF_FILES",(select  LISTAGG(TOP_EVENTS, ' - ') WITHIN GROUP (ORDER BY TOP_EVENTS) from (select rownum||'.'||name||'('||TOTAL_TIME_WAITED||')' "TOP_EVENTS" from ( select a.event_id, e.name, sum(a.time_waited) total_time_waited  
from gv$active_session_history a, gv$event_name e  where a.event_id = e.event_id and a.inst_id=e.inst_id and a.program like '%(PR%' and a.SAMPLE_TIME>=(sysdate-30/(24*60))  group by a.event_id, e.name order by 3 desc)  where rownum <=3))"TOP_EVENTS_DG"
from v$database order by 1 desc,2,3,8 desc;

--EMDB'de kurduğumuz otomatik rapor. 28 tane DG için özet durum bilgisi veriyor:
select rownum"DG_NO(28)",a.* from	(select * from		DBMAIN.DATA_GUARD_CONTROL order by CONTROLFILE_TIME)a;
