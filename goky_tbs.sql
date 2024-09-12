----|TBS Durum Sorgulama|--
SELECT tablespace_name, doluluk_orani FROM (SELECT a.tablespace_name,ROUND (a.bytes_alloc / 1024 / 1024, 2)megs_alloc,ROUND (NVL (b.bytes_free, 0) / 1024 / 1024, 2)megs_free,ROUND ((a.bytes_alloc - NVL (b.bytes_free, 0)) / 1024 / 1024,2)megs_used,
ROUND ((NVL (b.bytes_free, 0) / a.bytes_alloc) * 100, 2)Pct_Free,100- ROUND ((NVL (b.bytes_free, 0) / a.bytes_alloc) * 100, 2)Pct_used,ROUND ((a.bytes_alloc - NVL (b.bytes_free, 0))* 100/ maxbytes,2)doluluk_orani,ROUND (maxbytes / 1048576, 2)
MAX FROM (  SELECT f.tablespace_name,SUM (f.bytes)bytes_alloc,SUM (DECODE (f.autoextensible,'YES', f.maxbytes,'NO', f.bytes)) maxbytes FROM dba_data_files f GROUP BY tablespace_name) a,(  SELECT f.tablespace_name, SUM (f.bytes) bytes_free FROM 
dba_free_space f GROUP BY tablespace_name) b WHERE a.tablespace_name = b.tablespace_name(+)) order by 2 desc;

--DDL History Loglarımız
select /*+parallel (8) */ ACTION_DATE,DDL, OBJECT_OWNER, OBJECT_NAME, OBJECT_TYPE, ACTION_USERNAME, ACTION_OSUSER, ACTION_TERMINAL,CLIENT_INFO,dbms_lob.substr(ddl_sql,4000,1)"SORGU" from    dbmain.ddl_history_log where 1=1 
and upper(object_name) like '%SYSAUX%' order by action_date desc;

--Safe and easy:
ALTER TABLESPACE INSERT_COIN_HERE ADD DATAFILE SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE UNLIMITED;

----------------------- tablespace ----------------- diskgroup-------df lokasyonu: show parameter db_create_file_dest => Oracle OMF                    
--ALTER TABLESPACE KRY_DATA ADD DATAFILE '+DATA' SIZE 100M AUTOEXTEND ON  NEXT 100M MAXSIZE UNLIMITED;

--Pandora'ya özel. Df eklemek yerine TBS resize ediyoruz? => Schema Browser'dan TBS'e çift tıklıyoruz. TBS_DATA06 için size 10 TB görünüyor. Onu 10.2 sonra 10.4 yapıyoruz arttıracağımız zaman.
--Üst limit TBS(Big file) başı 32 TB. Bunu geçme => ALTER DATABASE DATAFILE '+DATA/PANDORA/DATAFILE/tbs_data09.293.1005704801' RESIZE 24678G;
--TEMP alanı büyütmek için => ALTER TABLESPACE TEMP ADD TEMPFILE '+DATA_ASOS' SIZE 4G AUTOEXTEND ON  NEXT 100M MAXSIZE UNLIMITED

------------------DB / ASM Size Raporları Başlıyor------------------

--ASM diskgroup durumu:
SELECT SYSDATE AS REPORT_DATE,(SELECT NAME FROM V$DATABASE) AS DB_NAME,NAME AS DISK_GROUP,CAST (total_mb / 1024 AS INT) AS total_gb,CAST (total_mb / 1024 - free_mb / 1024 AS INT) AS used_gb,CAST (free_mb / 1024 AS INT) AS free_gb,
CONCAT ('%',CAST ((CAST (total_mb / 1024 - free_mb / 1024 AS INT) * 100) / CAST (total_mb / 1024 AS INT) AS INT)) AS percentage FROM v$asm_diskgroup WHERE 1 = 1 and total_mb>0 and free_mb>0;

--Legacy diskgroup historik yapımız:
select * from	dbmain.DISKGROUP_USAGE where 1=1	 and upper(disk_group) like '%DATA%' order by 1 desc,used_gb desc;

--3 aylık periyotla 1 yıllık disk değişimi:
select 'DÜN' "NE_ZAMAN",a.* from dbmain.DISKGROUP_USAGE a where 1=1  and upper(disk_group) like '%DATA%' and trunc(report_date)=trunc(sysdate-1) union all select '3_AY' "NE_ZAMAN",a.* from dbmain.DISKGROUP_USAGE a where 1=1  and upper(disk_group) like '%DATA%' and trunc(report_date)=trunc(sysdate-93)
union all select '6_AY' "NE_ZAMAN",a.* from dbmain.DISKGROUP_USAGE a where 1=1  and upper(disk_group) like '%DATA%' and trunc(report_date)=trunc(sysdate-185) union all select '9_AY' "NE_ZAMAN",a.* from dbmain.DISKGROUP_USAGE a where 1=1  and upper(disk_group) like '%DATA%' and trunc(report_date)=trunc(sysdate-276)
union all select '12_AY' "NE_ZAMAN",a.* from dbmain.DISKGROUP_USAGE a where 1=1  and upper(disk_group) like '%DATA%' and trunc(report_date)=trunc(sysdate-367) order by 2 desc;

--DB Size: Used Size ve Allocated Size:
select (select DB_UNIQUE_NAME from v$database)"DB_NAME_GB",substr(rtime, 1, 10)"DATE",round((sum(tablespace_size) * 8192) / 1024 / 1024 / 1024)"USED_DB_SIZE_GB",round((sum(tablespace_usedsize) * 8192) / 1024 / 1024 / 1024)"ALLOCATED_DB_SIZE_GB"
from DBA_HIST_TBSPC_SPACE_USAGE where substr(rtime, 12,5)='00:00' group by substr(rtime, 1, 10) order by substr(rtime, 1, 10) desc;

--DB Allocated Size by Owner:
select coalesce(owner,'TOTAL')"USER", cast(sum(bytes)/1024/1024/1024 as int) Size_GB from dba_segments group  by rollup(owner) having cast(sum(bytes)/1024/1024/1024 as int)>0 order by 2 desc;

------------------DB / ASM Size Raporları Bitiyor------------------

------------------RMAN Kontrolleri Başlıyor------------------

--Displays the finished RMAN jobs :
select start_time,INPUT_TYPE,OUTPUT_DEVICE_TYPE,STATUS,end_time,substr((elapsed_seconds/3600),0,5) HOURS ,INPUT_BYTES_DISPLAY, OUTPUT_BYTES_DISPLAY  from V$RMAN_BACKUP_JOB_DETAILS order by end_time desc;

--RMAN geçmişi sorgumuz:
select START_TIME,END_TIME,OBJECT_TYPE,OPERATION,ROW_TYPE,STATUS, OUTPUT_DEVICE_TYPE,round(MBYTES_PROCESSED/1024,2) "GB_PROCESSED" from	v$rman_status where 1=1	
and object_type in('ARCHIVELOG','DB FULL','DB INCR')  /*degistirebilir*/ and operation='BACKUP'  /*degistirebilir*/ order by start_time desc;

------------------RMAN Kontrolleri Bitti------------------

------------------ASM-Fragmantasyon-Corruption Kontrolleri Başlıyor------------------

--FRAGMANTASYON - ASM DISK RESIZE KONTROLÜ:
--MB cinsinden ne kadarlık ASM disk resize edilerek yer kazanılacağını gösteriyor. 
--TS'de purge sonrası boş yer çok olur. Temizlemek için gün içerisinde çalıştırılabilir. UNDO,SYSAUX;SYS alanlarını resize etmeden dikkatlice gün içerisinde çalıştırılabilir:
SELECT * FROM    (
SELECT CEIL( BLOCKS*(A.BLOCKSIZE)/1024/1024) "Current Size",CEIL( (NVL(HWM,1)*(A.BLOCKSIZE))/1024/1024 ) "Smallest Poss.",CEIL( BLOCKS*(A.BLOCKSIZE)/1024/1024)-CEIL( (NVL(HWM,1)*(A.BLOCKSIZE))/1024/1024 ) "Savings",
'alter database datafile '''|| FILE_NAME || ''' resize ' || CEIL((NVL(HWM,1)*(A.BLOCKSIZE))/1024/1024/100)*100  || 'm;' "KOMUT"FROM (SELECT A.*, P.VALUE BLOCKSIZE FROM DBA_DATA_FILES A JOIN V$PARAMETER P ON P.NAME='db_block_size') A
LEFT JOIN (SELECT FILE_ID, MAX(BLOCK_ID+BLOCKS-1) HWM FROM DBA_EXTENTS GROUP BY FILE_ID ) B ON A.FILE_ID = B.FILE_ID WHERE CEIL( BLOCKS*(A.BLOCKSIZE)/1024/1024)-CEIL( (NVL(HWM,1)*(A.BLOCKSIZE))/1024/1024 )>100 /* Minimum MB it must shrink by to be considered. */
ORDER BY "Savings" DESC)WHERE 1=1    
AND UPPER(KOMUT) NOT LIKE '%/UNDO%' /*Burayı bilerek çıkartıyoruz gün içerisinde çalıştırıken sorun olmasın diye*/
AND UPPER(KOMUT) NOT LIKE '%/SYSAUX%' /*Burayı bilerek çıkartıyoruz gün içerisinde çalıştırıken sorun olmasın diye*/
AND UPPER(KOMUT) NOT LIKE '%/SYS%' /*Burayı bilerek çıkartıyoruz gün içerisinde çalıştırıken sorun olmasın diye*/;

--FRAGMANTASYON KONTROLÜ: Birinci gerçek boyut. İkinci row sayısına göre olması gereken. Üçüncü de aradaki fark.
--Fark %10-%20 arası olması gerekir. Fazlaysa TBS move, table recreate vb yapılması lazım
--Ya tabloya çok sık DML yapılmıştır, ya da append hint’i kullanılmıştır. Bulk ve büyük bir datayı tek seferde basıyorsanız append uygun olabilir. Ancak, küçük ve satır sayısı az olan veriyi sürekli arka arkaya basıyorsanız burada append kullanmamalısınız.
select OWNER,TABLE_NAME, TABLESPACE_NAME,SIZE_GB, ACTUAL_DATA_GB, WASTED_SPACE_GB, round((WASTED_SPACE_GB*100/(SIZE_GB+0.000000000001)),2)"YUZDE" from(select OWNER,TABLE_NAME, TABLESPACE_NAME,
round(SIZE_KB/1024/1024,2)"SIZE_GB", round(ACTUAL_DATA_KB/1024/1024,2)"ACTUAL_DATA_GB",  round(WASTED_SPACE_KB/1024/1024,2)"WASTED_SPACE_GB" from(select OWNER,table_name,TABLESPACE_NAME,round((blocks*8),2)
"SIZE_KB",round((num_rows*avg_row_len/1024),2) "ACTUAL_DATA_KB",(round((blocks*8),2) - round((num_rows*avg_row_len/1024),2)) "WASTED_SPACE_KB" from dba_tables where 1=1 and (round((blocks*8),2) > round((num_rows*avg_row_len/1024),2)) ))where 1=1	
--and owner like 'NNO%'
--and tablespace_name like '%EUS%'
order by WASTED_SPACE_GB desc;

--CORRUPTION KONTROLÜ:
--CORRUPTION_TYPE	VARCHAR2(9)	Type of block corruption in the datafile:
--ALL ZERO - Block header on disk contained only zeros. The block may be valid if it was never filled and if it is in an Oracle7 file. The buffer will be reformatted to the Oracle8 standard for an empty block.
--FRACTURED - Block header looks reasonable, but the front and back of the block are different versions.
--CHECKSUM - optional check value shows that the block is not self-consistent. It is impossible to determine exactly why the check value fails, but it probably fails because sectors in the middle of the block are from different versions.
--CORRUPT - Block is wrongly identified or is not a data block (for example, the data block address is missing)
--LOGICAL - Specifies the range is for logically corrupt blocks. CORRUPTION_CHANGE# will have a nonzero value.
SELECT /*+parallel (8) */distinct owner ||'.'||segment_name"OBJECT_NAME",segment_type,CORRUPTION_TYPE,tablespace_name FROM (SELECT CORRUPTION_TYPE,file# "FILE_ID", block# "BLOCK_NUM",SCN_TO_TIMESTAMP (CORRUPTION_CHANGE#) 
FROM v$database_block_corruption WHERE 1=1 /*and 2CORRUPTION_TYPE in ('FRACTURED','ALL ZERO')*/) corruption_blocks,(SELECT OWNER,SEGMENT_NAME,PARTITION_NAME,SEGMENT_TYPE,TABLESPACE_NAME,EXTENT_ID,FILE_ID,BLOCK_ID,BYTES,
BLOCKS,RELATIVE_FNO,block_id + blocks - 1 "GOKY_VALUE" FROM dba_extents) calc_value WHERE 1 = 1 AND corruption_blocks.FILE_ID = calc_value.FILE_ID AND block_num BETWEEN calc_value.block_id AND calc_value.goky_value order by 1;

------------------ASM-Fragmantasyon-Corruption Kontrolleri Bitti------------------ 

--Detay bazlı disk durumumuz. Çalışma öncesinde exportu alınmalı. DB ayakta degilse bile sqlasm ile bakabilirsin:
select inst_id,group_number,disk_number,nvl(name,'NAME_YOK')"NAME",nvl(path,'PATH_YOK')"PATH",header_status,mode_status,mount_status,state,CAST (total_mb / 1024 AS INT) AS TOTAL_GB,CAST (free_mb / 1024 AS INT) AS FREE_GB,create_date 
from gv$asm_disk order by name,path;

--Ongoing ASM Operations. Bu view'e bakmak için +ASM instance'a geç (grid user ile)
select * from v$asm_operation;

--Set edilen db_reco_file_dest_size ile FRA uyumu kontrolu
--FRA'da yer olmasına rağmen db_recor_file_dest_size parametren dolmuşsa patlarsın
select 'DB_RECOVERY_FILE_DEST_SIZE' as "TITLE",round(VALUE/1024/1024,0)"SIZE_MB" from V$PARAMETER where 1=1 and name='db_recovery_file_dest_size'union all select 'CURRENT FRA TOTAL SIZE' as "TITLE", TOTAL_MB from v$asm_diskgroup 
where 1=1 and name like '%FRA%';

--db_recovery_file_dest_size parametresinin izin verdiği ölçüde arşivde kalan yerin.
--FRA'da yer olmasına rağmen patlarsın eğer bu dolarsa.
select name, round((100*space_used)/space_limit,2) pct_full from V$RECOVERY_FILE_DEST;

--Tablespace Size and Percentage. Key metrics: MAX_SIZE_GB, USED_GB, % USED OF MAX--BIZIM_DOLULUK
--Çünkü tek bir datafile ekleyince 100 MB değil maxsize olan 32 GB kadar ekliyor. Sen içerisini extend ede ede dolduruyorsun.
--Daha detaylı görmek için * ile bakılabilir.
SELECT TABLESPACE_NAME, AUTO_EXT,CURR_TS_GB_SIZE"SIZE_GB",USED_TS_GB_SIZE"USED_GB",FREE_TS_GB_SIZE"FREE_GB",TS_PCT_USED"% USED",null "SONRASI_DETAY",MAX_TS_GB_SIZE"MAX_SIZE_GB",MAX_TS_PCT_USED"% USED OF MAX--BIZIM_DOLULUK" from (
SELECT DF.TABLESPACE_NAME TABLESPACE_NAME,MAX(DF.AUTOEXTENSIBLE) AUTO_EXT,ROUND(DF.MAXBYTES / (1024 * 1024 * 1024), 2) MAX_TS_GB_SIZE,ROUND(DF.BYTES / (1024 * 1024 * 1024), 2) CURR_TS_GB_SIZE,ROUND((DF.BYTES - SUM(FS.BYTES)) / (DF.MAXBYTES) * 100, 2) MAX_TS_PCT_USED,
ROUND((DF.BYTES - SUM(FS.BYTES)) / (1024 * 1024 * 1024), 2) USED_TS_GB_SIZE,ROUND(SUM(FS.BYTES) / (1024 * 1024 * 1024), 2) FREE_TS_GB_SIZE,NVL(ROUND(SUM(FS.BYTES) * 100 / DF.BYTES), 2) TS_PCT_FREE,
ROUND((DF.BYTES-SUM(FS.BYTES)) * 100 / DF.BYTES, 2) TS_PCT_USED FROM DBA_FREE_SPACE FS,(SELECT TABLESPACE_NAME,SUM(BYTES) BYTES,SUM(DECODE(MAXBYTES, 0, BYTES, MAXBYTES)) MAXBYTES,MAX(AUTOEXTENSIBLE) AUTOEXTENSIBLE FROM DBA_DATA_FILES
GROUP BY TABLESPACE_NAME) DF WHERE FS.TABLESPACE_NAME (+) = DF.TABLESPACE_NAME GROUP BY DF.TABLESPACE_NAME, DF.BYTES, DF.MAXBYTES
UNION ALL
SELECT DF.TABLESPACE_NAME TABLESPACE_NAME,MAX(DF.AUTOEXTENSIBLE) AUTO_EXT,ROUND(DF.MAXBYTES / (1024 * 1024 * 1024), 2) MAX_TS_SIZE,ROUND((DF.BYTES - SUM(FS.BYTES)) / (DF.MAXBYTES) * 100, 2) MAX_TS_PCT_USED,
ROUND(DF.BYTES / (1024 * 1024 * 1024), 2) CURR_TS_SIZE,ROUND((DF.BYTES - SUM(FS.BYTES)) / (1024 * 1024 * 1024), 2) USED_TS_GB_SIZE,ROUND(SUM(FS.BYTES) / (1024 * 1024 * 1024), 2) FREE_TS_GB_SIZE,NVL(ROUND(SUM(FS.BYTES) * 100 / DF.BYTES), 2) TS_PCT_FREE,
ROUND((DF.BYTES-SUM(FS.BYTES)) * 100 / DF.BYTES, 2) TS_PCT_USED FROM (SELECT TABLESPACE_NAME, BYTES_USED BYTES FROM V$TEMP_SPACE_HEADER
GROUP BY TABLESPACE_NAME, BYTES_FREE, BYTES_USED) FS,(SELECT TABLESPACE_NAME,SUM(BYTES) BYTES,SUM(DECODE(MAXBYTES, 0, BYTES, MAXBYTES)) MAXBYTES,MAX(AUTOEXTENSIBLE) AUTOEXTENSIBLE FROM DBA_TEMP_FILES
GROUP BY TABLESPACE_NAME) DF WHERE FS.TABLESPACE_NAME (+) = DF.TABLESPACE_NAME GROUP BY DF.TABLESPACE_NAME, DF.BYTES, DF.MAXBYTES ORDER BY 4 DESC
)
WHERE 1=1	
--AND TABLESPACE_NAME='EUS_DATA'
order by 3 desc;

--Tablespace detayı ve kaç df barındırdığı:
select FILE_NAME,TABLESPACE_NAME,STATUS,AUTOEXTENSIBLE,ONLINE_STATUS,ROUND(MAXBYTES / (1024 * 1024 * 1024), 2)"DF_MAX_GB_SIZE",ROUND(BYTES / (1024 * 1024 * 1024), 2)"DF_GB_SIZE" from DBA_DATA_FILES WHERE 1=1	
AND TABLESPACE_NAME='EUS_DATA' order by DF_GB_SIZE;

--TBS ARTIS TREND--
select * from DBMAIN.DB_SIZE order by timedate desc;

select * from DBMAIN.DB_TABLESPACE_SIZE where tablespace_name='' order by timedate desc;

select * from DBMAIN.DB_TABLE_SIZE where table_name='' order by timedate desc;

select * from DBMAIN.DB_TABLE_SIZE_GUNLUK where table_name='' order by timedate desc;

select table_name,timedate,sum(tpl_size)/(1024 * 1024*1024) size_gb from DBMAIN.DB_TABLE_SIZE_GUNLUK where table_name='QUEUE_LOG' group by table_name,timedate order by timedate desc;

----------------------TBS ve Şema Doluluk Durumları Başlıyor---------------------- 

---Userlara ait tabloları görmek
                  SELECT owner, segment_name, tablespace_name, SUM (size_Gb) size_Gb
                    FROM (  SELECT CASE
                                      WHEN x.segment_type IN ('LOBSEGMENT', 'LOB PARTITION')
                                      THEN
                                         (SELECT table_name FROM dba_lobs y WHERE y.segment_name = trim(x.segment_name)and Y.OWNER=x.owner)
                                      WHEN x.segment_type = 'LOBINDEX'
                                      THEN
                                         (SELECT table_name FROM dba_lobs y
                                           WHERE y.index_name = trim(x.segment_name) and Y.OWNER=x.owner)
                                      WHEN x.segment_type IN
                                              ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
                                      THEN
                                         (SELECT y.table_name FROM dba_indexes y WHERE y.index_name = trim(x.segment_name)and Y.OWNER=x.owner)
                                      WHEN x.segment_type IN ('TABLE SUBPARTITION', 'TABLE PARTITION', 'TABLE')
                                     THEN
                                         x.segment_name
                                   END
                                      segment_name,
                                   x.tablespace_name,owner,
                                   ROUND (SUM (x.bytes) / (1024 * 1024*1024), 2) size_Gb
                              FROM dba_segments x
                             WHERE x.owner = 'FCBSADM_ARCH'
                          GROUP BY x.segment_name, x.tablespace_name, x.segment_type,x.owner)
                GROUP BY segment_name, tablespace_name, owner
ORDER BY size_Gb DESC;

--Schema Size-----------
select sum(GB_SIZE) from	(select  owner,SEGMENT_NAME,count(1)"OBJECT_COUNT", cast( sum(bytes/1024/1024/1024)as int) "GB_SIZE"  from  dba_segments  where 1=1	
and owner='FCBSADM'
group by owner,SEGMENT_NAME order by 4 desc);

---tablespace leri sizeları ile---
SELECT owner, segment_name, tablespace_name, SUM (size_Gb) size_Gb
                    FROM (  SELECT CASE
                                      WHEN x.segment_type IN ('LOBSEGMENT', 'LOB PARTITION')
                                      THEN
                                         (SELECT table_name FROM dba_lobs y WHERE y.segment_name = trim(x.segment_name)and Y.OWNER=x.owner)
                                      WHEN x.segment_type = 'LOBINDEX'     
                                      THEN
                                         (SELECT table_name FROM dba_lobs y WHERE y.index_name = trim(x.segment_name) and Y.OWNER=x.owner)
                                      WHEN x.segment_type IN
                                              ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
                                      THEN
                                         (SELECT y.table_name FROM dba_indexes y WHERE y.index_name = trim(x.segment_name)and Y.OWNER=x.owner)
                                      WHEN x.segment_type IN
                                              ('TABLE SUBPARTITION', 'TABLE PARTITION', 'TABLE')
                                      THEN
                                         x.segment_name
                                   END
                                      segment_name,
                                   x.tablespace_name,owner,
                                   ROUND (SUM (x.bytes) / (1024 * 1024*1024), 2) size_Gb
                              FROM dba_segments x
                             WHERE x.tablespace_name = 'BAYI_PORTAL_DATA'
                          GROUP BY x.segment_name, x.tablespace_name, x.segment_type,x.owner)
                GROUP BY segment_name, tablespace_name, owner
ORDER BY size_Gb DESC;

----------------------TBS ve Şema Doluluk Durumları Bitti---------------------- 

----------------------Şema-Tablo Doluluk Raporlarımız Başlıyor----------------------

--Tırnak arasındakiler hariç userları getiriyor.. (UYGULAMA USERLAR İÇİN)
SELECT owner, COUNT(owner) "Number of Objects", ROUND(SUM(bytes) / 1024 / 1024 /1024, 2) "Total Size in GB" FROM   sys.dba_segments
WHERE OWNER NOT IN ('ANONYMOUS', 'CTXSYS','DBSNMP', 'EXFSYS', 'LBACSYS', 'MDSYS','MGMT_VIEW','OLAPSYS','OWBSYS', 'ORDPLUGINS', 'ORDSYS', 'OUTLN','SI_INFORMTN_SCHEMA','SYS', 'SYSMAN','SYSTEM','TSMSYS','WK_TEST', 'WKSYS','WKPROXY','WMSYS','XDB',
'APEX_PUBLIC_USER','DIP','FLOWS_30000','FLOWS_FILES','MDDATA', 'ORACLE_OCM','PUBLIC','SPATIAL_CSW_ADMIN_USER', 'SPATIAL_WFS_ADMIN_USR','XS$NULL','APPQOSSYS','APEX_030200','EXPDB','SPATIAL_CSW_ADMIN_USR','DMSYS','DBMAIN')
GROUP BY owner order by 3 desc;

--End user'ların son 2 günde yarattıkları tablolar ve boyutları:
select object_owner,object_name,action_username,action_osuser,action_date,client_info,cast(bytes/1024/1024 as int)"MB_SIZE" from	DBMAIN.DDL_HISTORY_LOG a, dba_segments b where 1=1	and A.OBJECT_OWNER=B.OWNER(+)
and A.OBJECT_NAME=b.SEGMENT_NAME(+) and b.segment_type in ('TABLE PARTITION','TABLE','TABLE SUBPARTITION') /*Segment type */ and action_date>=trunc(sysdate-2) and ddl='CREATE' and object_type='TABLE'
and TABLESPACE_NAME='EUS_DATA'and (action_username like '%EUS%' or action_username='DB_MIG') order by mb_size desc;

----------------------Şema-Tablo Doluluk Raporlarımız Bitti----------------------

--Table Size (by Partitions and Subpartitions)
select cast(sum(MB_SIZE)/1024 as int) "GB_SIZE"  from	(
select owner,segment_name,partition_name,segment_type,tablespace_name,cast(bytes/1024/1024 as int)"MB_SIZE" from	dba_segments where 1=1	
and segment_name='ECOOVERLAYRESULT' /*Table name*/
and owner='PROD20_SMP'
--and segment_type in ('TABLE PARTITION','TABLE','TABLE SUBPARTITION') /*Segment type  (LOB segmentler için kapatıldı. Duruma göre açılabilir.) */
order by 6 desc);

--LOB segment size: Gerçek size=Tablo size + LOB segment size
SELECT OWNER,SEGMENT_NAME,ROUND (SUM (BYTES) / 1024 / 1024 / 1024)	  "LOB size (GB)" FROM DBA_SEGMENTS WHERE	 1=1
and SEGMENT_NAME IN (SELECT SEGMENT_NAME FROM DBA_LOBS WHERE TABLE_NAME = 'ECOOVERLAYRESULT') AND OWNER = 'PROD20_SMP' 
GROUP BY OWNER, SEGMENT_NAME ORDER BY 3 desc,1,2;

--İndex sizes ve last_used bilgisi. Bu last_used bilgisine her zaman güven olmaz. Mutlaka öncesinde trace açarak kullanılmadığından emin ol:
select a.owner, a.segment_name, a.segment_type,sum(cast(a.bytes/1024/1024/1024 as int)) gb_size,LAST_USED from dba_segments a, dba_index_usage b where 1=1
and a.owner=b.owner(+) and a.segment_name=b.name(+)
and upper(a.segment_type) like '%INDEX%'
--and a.segment_name='UI_DEVICE_02'
group by a.owner, a.segment_name, a.segment_type,LAST_USED order by 4 desc;

--Invalid object control:
select owner,object_name,status,object_type,CREATED, LAST_DDL_TIME from	dba_objects  where 1=1	
and status<>'VALID' order by 1,2;

--Invalid index control:
SELECT owner, index_name, UNIQUENESS, table_name, tablespace_name FROM   dba_indexes where 1=1	
and status NOT IN ('VALID', 'N/A') order by 1,2;

--Invalid indesleri toplu halde rebuild etmek için.
--"COMPUTE STATISTICS" (index'e analiz geçer) ve "ONLINE" özelliklerini ekleyebilirsin duruma göre:
SELECT 'ALTER INDEX ' || OWNER || '.' ||INDEX_NAME || ' REBUILD ' ||'TABLESPACE ' || TABLESPACE_NAME || ';' FROM DBA_INDEXES WHERE STATUS='UNUSABLE' UNION SELECT 'ALTER INDEX ' || INDEX_OWNER || '.' ||INDEX_NAME ||' REBUILD PARTITION ' 
|| PARTITION_NAME || 'TABLESPACE ' || TABLESPACE_NAME || ';' FROM DBA_IND_PARTITIONS WHERE STATUS='UNUSABLE' UNION SELECT 'ALTER INDEX ' || INDEX_OWNER || '.' || INDEX_NAME || ' REBUILD SUBPARTITION '||SUBPARTITION_NAME||'TABLESPACE ' 
|| TABLESPACE_NAME || ';'FROM DBA_IND_SUBPARTITIONS WHERE STATUS='UNUSABLE';

--snapler arasındaki block change değişiklikleri kontrol etmek için:
select a.snap_id,b.BEGIN_INTERVAL_TIME,b.END_INTERVAL_TIME,a.instance_number,dbc "Db block changes" from (select snap_id, instance_number, sum(db_block_changes_delta) dbc from dba_hist_seg_stat group by snap_id, instance_number
order by snap_id desc) a,dba_hist_snapshot b where a.snap_id = b.snap_id and a.instance_number = b.instance_number order by dbc desc;
   
--Oracle Flashback Query: Recovering at the Row Level
select * from	dbmain.DBA_LONG_RUNNING_QUERIES as of timestamp to_date ('16-04-2020 11:00:00', 'dd-mm-yyyy hh24:mi:ss')