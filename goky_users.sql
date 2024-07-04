----|Login Hata Sorgulama|--
select error_date, a.* from dbmain.db_error_log a  where 1=1 and ERRORNO in (604,4088)  and error_date>sysdate-1
--and osuser='' 
order by a.error_date desc;

--EUS user'ları için IP'ye bakmıyor(CLIENT_INFO daha önemli) trigger. Uygulama user'ları için IP'ye bakıyor.
--MAVNA gibi kritik sistemlerde TRIGGER_CONTROL='FALSE' var uygulama userları için. Onu kontrol et mutlaka kritik sistemler için
Insert into DBMAIN.DB_LOGIN_PARAMS 
(USERNAME, OSUSER, IP_ADDRESS, MACHINE, DB, TRIGGER_CONTROL, INSERT_DATE,client_info) Values
('EUS_IHOPE_OPR', '26475362', '', 'TURKTELEKOM_N0343844', (select DB_UNIQUE_NAME from v$database), 'AKTIF', sysdate,'');

--Bulk işlem Logon Trigger insert:
create table	dbmain.db_login_TEMP as  select USERNAME,OSUSER,IP_ADDRESS,MACHINE from	dbmain.db_login_params where 1=2;

--TEMP tabloya data bas ve ateşle
insert into DBMAIN.DB_LOGIN_PARAMS
(USERNAME, OSUSER, IP_ADDRESS, MACHINE, DB, TRIGGER_CONTROL, INSERT_DATE,client_info)
select USERNAME, OSUSER, IP_ADDRESS, MACHINE,(select DB_UNIQUE_NAME from v$database), 'AKTIF', sysdate,'' from	dbmain.db_login_TEMP;

--Bulk olarak white_list eklemek için. Buradaki OSUSER ve USERNAME komboları direkt giriş yapabilecek.
CREATE TABLE DBMAIN.WHITE_LIST AS SELECT OSUSER,USERNAME FROM	DBMAIN.DB_LOGIN_OS_MACHINE_PAR WHERE 1=2;

----TEMP tabloya data bas ve ateşle
insert into	DBMAIN.DB_LOGIN_OS_MACHINE_PAR
(OSUSER,USERNAME,INSERT_DATE)
select OSUSER,USERNAME,SYSDATE from DBMAIN.WHITE_LIST;

--Eğer yeni white list özelliğine sahip logon trigger devreye alındıysa bu tabloya username ve osuser ekleyerek içeriye herkesi alabilirsin
select * from	DBMAIN.DB_LOGIN_OS_MACHINE_PAR;

--Sabit IDM - EUS User ve Role Mapping:
select distinct KULLANICI_ID, MAPPING, ROL, GLOBAL_ROLE from	LIVE3OIM_OIM.EUS_ROLE_MAPPING where 1=1	
and upper(KULLANICI_ID) like '%AA70230%' order by 3;

--İlgili tablo için select hakkı barındıran bir role var mı? 
select * from   DBA_TAB_PRIVS where 1=1   
and owner='IHOPE'
and privilege='SELECT'
and upper(table_name) = 'DOSYA_BORC' order by 1;

--TTXSB uygulamasına yetkisi olan global roller. Taşımalarda işe yarar:
select * from    DBA_ROLE_PRIVS where 1=1    
and granted_role like '%TTXSB%'
and grantee like 'G_%' order by 1;

--DB ye son 90 gündür login olmayan kullanıcılar:
select distinct username from	dba_users where 1=1	
and username not in (select distinct username from	dbmain.db_login_log where 1=1	and status='S'and logon_time>sysdate-91)
and username not in ('RMAN','SYSMAN','DBMAIN','SYSTEM','SYS','XDB','ANONYMOUS','CTXSYS','OUTLN','APPQOSSYS','WMSYS','DIP','MGMT_VIEW','ORAACS','ORDSYS','ORDDATA',
'ORDPLUGINS','MDSYS','MDDATA','DBSNMP','SI_INFORMTN_SCHEMA')
and username not like 'OLAPSYS%'and username not like '%$%'and username not like 'DBA%'and username not like '%_OCM%'and username not like 'EUS_%'
and username not like 'TTNET%'and username not like 'SQLTX%'and username not like 'APEX_%'and username not like 'SPATIAL_%' order by 1