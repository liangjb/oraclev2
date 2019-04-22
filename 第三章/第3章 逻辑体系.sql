脚本3-1  查看Oracle 块的大小
sqlplus "/ as sysdba"
show parameter db_block_size
select block_size
 from dba_tablespaces 
where tablespace_name='SYSTEM';

脚本3-2  查看Oracle 数据、临时、回滚、系统表空间情况
sqlplus "/ as sysdba"
create tablespace TBS_LJB
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_01.DBF'  size 100M
extent management local
segment space management auto;
col file_name format a50
set linesize 366
SELECT file_name, tablespace_name, autoextensible,bytes
        FROM DBA_DATA_FILES
       WHERE TABLESPACE_NAME = 'TBS_LJB'
       order by substr(file_name, -12);
       
---临时表空间（语法有些特别，有TEMPORARY及TEMPFILE的关键字）
CREATE TEMPORARY TABLESPACE  temp_ljb
     TEMPFILE 'E:\ORADATA\ORA10\DATAFILE\TMP_LJB.DBF' SIZE 100M;
SELECT FILE_NAME,BYTES,AUTOEXTENSIBLE FROM DBA_TEMP_FILES where tablespace_name='TEMP_LJB';

---回滚段表空间（语法有些特别，有UNDO的关键字）
create undo tablespace undotbs2 datafile 'E:\ORADATA\ORA10\DATAFILE\UNDOTBS2.DBF' size 100M;
SELECT file_name,
 tablespace_name, 
autoextensible,
bytes/1024/1024 
     FROM DBA_DATA_FILES
     WHERE TABLESPACE_NAME = 'UNDOTBS2'
       order by substr(file_name, -12); 

---系统表空间（Oracle 10g的系统表空间还增加了SYSAUX作为辅助系统表空间使用）
SELECT file_name, 
tablespace_name,
 autoextensible,bytes/1024/1024
FROM DBA_DATA_FILES
WHERE TABLESPACE_NAME LIKE 'SYS%'
 order by substr(file_name, -12);

---系统表空间和用户表空间都属于永久保留内容的表空间
select tablespace_name,
contents                                
  from dba_tablespaces                                         
 where tablespace_name in                                      
       ('TBS_LJB', 'TEMP_LJB', 'UNDOTBS2', 'SYSTEM', 'SYSAUX');




脚本3-3  Oracle 建用户和授权简单体验
---sysdba用户登录，假如ljb用户存在，先删除
sqlplus "/ as sysdba"
drop user ljb cascade;
---建用户，并将先前建的表空间tbs_ljb和临时表空间temp_ljb作为ljb用户的默认使用空间。
create user ljb 
identified by ljb 
default tablespace tbs_ljb 
temporary tablespace temp_ljb;
---授权，暂且给最大权限给ljb用户（大家切记只能在非生产环境做实验）
grant dba to ljb;
--可以登录ljb用户了
connect ljb/ljb


脚本3-4  Oracle 的extent体会
---构造t（注，如果没有指明表空间，就是用户ljb的默认表空间）
sqlplus ljb/ljb
drop table t purge;
create table t (id int)  tablespace tbs_ljb;
---查询数据字典获取extent相关信息
select segment_name,
extent_id,
tablespace_name,
bytes/1024/1024,blocks 
from user_extents 
where segment_name='T'  

----插入数据后继续观察,发现由原来的1个区增加为28个区
insert into t select rownum from dual connect by level<=1000000;
commit;
select segment_name,
extent_id,
bytes/1024/1024,blocks 
from user_extents 
where segment_name='T' ; 


脚本3-5  Oracle 的segment体会
---构造t表
sqlplus ljb/ljb
drop table t purge;
create table t (id int) tablespace tbs_ljb;

---查询数据字典获取segment相关信息
select segment_name, 
segment_type,
tablespace_name,
blocks,
extents,bytes/1024/1024 
from user_segments  
where segment_name = 'T';

---插入数据后继续观察
insert into t select rownum from dual connect by level<=1000000;
commit;

---插入大量记录后，发现确实有变化，BLOCKS和EXTENTS都增加了，区从1个增加为28个，块个数由原来的8个增加为1664个，段的大小从0.0625MB增长为13MB，具体如下：
select segment_name, segment_type,tablespace_name,blocks,extents,bytes/1024/1024 
from user_segments  where segment_name = 'T';

---观察索引段（其中IDX_ID这个段的segment_type 为INDEX）
create index idx_id on t(id);

select segment_name, 
segment_type,
tablespace_name,
blocks,
extents,
bytes/1024/1024 
from user_segments  
where segment_name = 'IDX_ID';

select count(*) from   user_extents  WHERE segment_name='IDX_ID';


脚本3-6  Oracle可启用不同大小的块
show parameter cache_size

脚本3-7  启用BLOCK_SIZE为16K的块
alter system set db_16k_cache_size=100M;
show parameter 16k

脚本3-8  启动大小为16K的块新建表空间
create tablespace TBS_LJB_16k 
blocksize 16K
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_16k_01.DBF' size 100M  
autoextend on  
extent management local 
segment space management auto;
----观察发现，TBS_LJB_16K这个表空间果然不同于原来的TBS_LJB2表空间的，块的大小果然为16K
select tablespace_name,
block_size
 from dba_tablespaces 
where tablespace_name in ('TBS_LJB2','TBS_LJB_16K');


脚本3-9  建UNIFORM SIZE为10M的表空间
create tablespace TBS_LJB2 
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB2_01.DBF'  size 100M  
extent management local 
uniform size 10M 
segment space management auto;

脚本3-10  观察UNIFORM SIZE为10M的表空间的分配情况
sqlplus ljb/ljb
create table t2 (id int ) tablespace TBS_LJB2;
select segment_name,
extent_id,
tablespace_name,
bytes/1024/1024,blocks 
from user_extents 
where segment_name='T2';
--接下来继续插入数据
insert into t2 select rownum from dual connect by level<=1000000;
commit;
--再观察EXTENT的分配情况
select segment_name,
extent_id,
tablespace_name,
bytes/1024/1024,blocks 
from user_extents 
where segment_name='T2';


脚本3-11  观察表空间的剩余情况
select sum(bytes) / 1024 / 1024
     from dba_free_space
     where tablespace_name = 'TBS_LJB';
     
脚本3-12  观察表空间的总体分配情况
select  sum(bytes) / 1024 / 1024
  from dba_data_files
  where tablespace_name = 'TBS_LJB' ;

脚本3-13  不断插入记录，模拟表空间不足的场景
insert into t select rownum from dual connect by level<=1000000;
commit;
insert into t select rownum from dual connect by level<=1000000;

脚本3-14  表空间不足报错时再观察一下表空间剩余情况
select sum(bytes) / 1024 / 1024
      from dba_free_space
     where tablespace_name = 'TBS_LJB';


脚本3-15  表空间扩大的方法
ALTER TABLESPACE  TBS_LJB 
    ADD DATAFILE  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_02.DBF' SIZE  100M;
     

脚本3-16  表空间扩大后继续观察剩余空间情况
select sum(bytes) / 1024 / 1024
      from dba_free_space
      where tablespace_name = 'TBS_LJB';

脚本3-17  观察表空间是否是自动扩展的
col file_name format a50
SELECT file_name, 
      tablespace_name,
      autoextensible,bytes/1024/1024                          
           FROM DBA_DATA_FILES                                                      
         WHERE TABLESPACE_NAME = 'TBS_LJB';


脚本3-18  将表空间属性更改为自动扩展
alter database datafile 'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_02.DBF'  autoextend on;


脚本3-19  继续查看表空间属性，发现已经更改为自动扩展
col file_name format a50                                                         
SELECT file_name,
tablespace_name, 
autoextensible,
bytes/1024/1024                          
  FROM DBA_DATA_FILES                                                      
  WHERE TABLESPACE_NAME = 'TBS_LJB';


脚本3-20  自动扩展后不用担心表空间不足，不过也要小心磁盘空间情况
insert into t select rownum from dual connect by level<=1000000;
insert into t select rownum from dual connect by level<=1000000;
insert into t select rownum from dual connect by level<=1000000;
insert into t select rownum from dual connect by level<=1000000;
commit;
SELECT file_name,
tablespace_name, 
autoextensible,
bytes/1024/1024                          
 FROM DBA_DATA_FILES                                                      
WHERE TABLESPACE_NAME = 'TBS_LJB'; 


脚本3-21  删除表空间自动删除数据文件方法 
drop tablespace TBS_LJB 
including contents and datafiles;

create tablespace TBS_LJB 
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_01.DBF' size 100M  
autoextend on  
extent management local 
segment space management auto;


脚本3-22  建自动扩展表空间可控制最大扩展到多少
create tablespace TBS_LJB3 
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB3_01.DBF' size 100M  
autoextend on  
next 64k
maxsize 5G;


脚本3-23  查看数据库当前在用回滚段
sqlplus "/ as sysdba"
 show parameter undo
 
 
脚本3-24  查看数据库有几个回滚段
select tablespace_name, 
      sum(bytes) / 1024 / 1024
      from dba_data_files
      where tablespace_name in ('UNDOTBS1', 'UNDOTBS2')
      group by tablespace_name;

脚本3-25  查看数据库有几个回滚段，并得出它们的大小
select tablespace_name, 
      sum(bytes) / 1024 / 1024
      from dba_data_files
      where tablespace_name in ('UNDOTBS1', 'UNDOTBS2')
      group by tablespace_name;


脚本3-26  切换回滚段的方法
alter system set undo_tablespace=undotbs2 scope=both;

脚本3-27  切换回滚段后，再查看当前回滚段是那一个
show parameter undo


脚本3-28  当前在用回滚段无法删除
drop tablespace undotbs2;
drop tablespace undotbs1 including contents and datafiles;

脚本3-29  查看临时表空间大小
select tablespace_name, 
      sum(bytes) / 1024 / 1024
      from dba_temp_files
     group by tablespace_name;


脚本3-30  建用户时可指定表空间和临时表空间
create user ljb 
identified by ljb 
default tablespace tbs_ljb 
temporary tablespace temp_ljb;


脚本3-31  查看用户的默认表空间和临时表空间
select DEFAULT_TABLESPACE,TEMPORARY_TABLESPACE from dba_users where username='LJB';


脚本3-32  查看其他用户的临时表空间
select default_tablespace,
      temporary_tablespace 
      from dba_users 
where username='SYSTEM';


脚本3-33  指定SYSTEM用户切换到指定的临时表空间
sqlplus "/ as sysdba"
alter user system temporary tablespace TEMP_LJB;
select default_tablespace,
       temporary_tablespace 
  from dba_users 
  where username='SYSTEM';



脚本3-34  观察不同用户在不同临时表空间的分配情况
select TEMPORARY_TABLESPACE,COUNT(*) 
  from dba_users 
  GROUP BY TEMPORARY_TABLESPACE; 


脚本3-35  切换所有用户到指定临时表空间
alter database default temporary tablespace temp_ljb;


脚本3-36  所有用户默认临时表空间都被切换到TEMP_LJB
select TEMPORARY_TABLESPACE,COUNT(*) 
  from dba_users 
  GROUP BY TEMPORARY_TABLESPACE;


脚本3-37  查询临时表空间情况
select * from dba_tablespace_groups;


脚本3-38  新建临时表空间组
create temporary tablespace temp1_1 tempfile  'E:\ORADATA\ORA10\DATAFILE\TMP1_1.DBF'  size 100M  tablespace group tmp_grp1;
create temporary tablespace temp1_2 tempfile  'E:\ORADATA\ORA10\DATAFILE\TMP1_2.DBF'  size 100M  tablespace group tmp_grp1;
create temporary tablespace temp1_3 tempfile  'E:\ORADATA\ORA10\DATAFILE\TMP1_3.DBF'  size 100M  tablespace group tmp_grp1;


脚本3-39  再查看临时表空间组情况，增加了3个成员
select * from dba_tablespace_groups;


脚本3-40  可指定某临时表空间移到临时表空间组
alter tablespace temp_ljb tablespace group tmp_grp1;


脚本3-41  移动临时表空间后，继续查看临时表空间组
select * from dba_tablespace_groups;
      

脚本3-42  将用户指定到临时表空间
alter user LJB temporary tablespace  tmp_grp1;


脚本3-43  查看指定用户的临时表空间
select temporary_tablespace 
  from dba_users 
  where username='LJB';


脚本3-44  该SQL执行会引发排序
select a.table_name, b.table_name
  from all_tables a, all_tables b
 order by a.table_name;

脚本3-45  多进程执行大量排序的SQL
SELECT USERNAME,
      SESSION_NUM,
      TABLESPACE 
  FROM V$SORT_USAGE;
  
脚本3-46  查看排序后各SESSION使用的临时表空间情况
SELECT USERNAME,
    SESSION_NUM,
    TABLESPACE 
  FROM V$SORT_USAGE;


脚本3-47  临时表空间组也可以设置多个
create temporary tablespace temp2_1 tempfile  'E:\ORADATA\ORA10\DATAFILE\TMP2_1.DBF'  size 100M  tablespace group tmp_grp2;
create temporary tablespace temp2_2 tempfile  'E:\ORADATA\ORA10\DATAFILE\TMP2_2.DBF'  size 100M  tablespace group tmp_grp2;
create temporary tablespace temp2_3 tempfile  'E:\ORADATA\ORA10\DATAFILE\TMP2_3.DBF'  size 100M  tablespace group tmp_grp2;
alter user YXL temporary tablespace  tmp_grp2;
  

脚本3-48  分别建统一尺寸和自动扩展的两个表空间
set timing on
drop tablespace tbs_ljb_a including contents and datafiles;
drop tablespace tbs_ljb_b including contents and datafiles;
create tablespace TBS_LJB_A datafile  'D:\ORA11G\DATAFILE\TBS_LJB_A.DBF' size 1M autoextend on uniform size 64k;
create tablespace TBS_LJB_B datafile  'D:\ORA11G\DATAFILE\TBS_LJB_B.DBF' size 2G ;


脚本3-49  分别在两个不同表空间建表
connect ljb/ljb
set timing on
CREATE TABLE t_a (id int) tablespace TBS_LJB_A; 
CREATE TABLE t_b (id int) tablespace TBS_LJB_B;


脚本3-50  分别比较插入的速度差异
insert into t_a select rownum from dual connect by level<=10000000;
insert into t_b select rownum from dual connect by level<=10000000;

脚本3-51  速度差异的原因
select count(*) from user_extents where segment_name='T_A';
select count(*) from user_extents where segment_name='T_B';


脚本3-52  表在uniform为64K的tablespace的插入情况
create tablespace TBS_LJB_C datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_C_01.DBF' size 2G autoextend on uniform size 64k;
connect ljb/ljb
CREATE TABLE t_c (id int) tablespace TBS_LJB_C;
insert into t_c select rownum from dual connect by level<=10000000;


脚本3-53  PCTFREE试验准备之建表
DROP TABLE EMPLOYEES PURGE;
CREATE TABLE EMPLOYEES AS SELECT * FROM HR.EMPLOYEES ;
desc EMPLOYEES;

脚本3-54  PCTFREE试验准备之扩大字段
alter table EMPLOYEES modify FIRST_NAME VARCHAR2(2000);
alter table EMPLOYEES modify LAST_NAME  VARCHAR2(2000);
alter table EMPLOYEES modify EMAIL VARCHAR2(2000);
alter table EMPLOYEES modify PHONE_NUMBER  VARCHAR2(2000);


脚本3-55  PCTFREE试验准备之更新表
UPDATE EMPLOYEES
  SET FIRST_NAME = LPAD('1', 2000, '*'), LAST_NAME = LPAD('1', 2000, '*'), EMAIL = LPAD('1', 2000, '*'),
  PHONE_NUMBER = LPAD('1', 2000, '*');
COMMIT;


脚本3-56  PCTFREE试验准备之查看逻辑读情况
SET AUTOTRACE TRACEONLY
set linesize 1000
select * from EMPLOYEES;
 
 
脚本3-57  PCTFREE试验准备之消除行迁移后的逻辑读情况 
CREATE TABLE EMPLOYEES_BK AS select * from EMPLOYEES;
SET AUTOTRACE TRACEONLY
set linesize 1000
select * from EMPLOYEES_BK;

脚本3-58  查看EMPLOYEES的PCTREE值
select pct_free from user_tables where table_name='EMPLOYEES';

脚本3-59  调整PCTFREE的方法
alter table EMPLOYEES  pctfree 20 ;
select pct_free from user_tables where table_name='EMPLOYEES';


脚本3-60  发现存在行迁移的方法
--首先建chaind_rows相关表，这是必需的步骤
--sqlplus "/ as sysdba"
sqlplus ljb/ljb
@?/rdbms/admin/utlchain.sql
----以下命令针对EMPLOYEES表和EMPLOYEES_BK做分析，将产生行迁移的记录插入到chained_rows表中
analyze table EMPLOYEES list chained rows into chained_rows;
analyze table EMPLOYEES_BK list chained rows into chained_rows;
select count(*)  from chained_rows where table_name='EMPLOYEES';
select count(*)  from chained_rows where table_name='EMPLOYEES_BK';

注：重要说明！可能由于环境的问题，如果上述两个语句的值没有区别，可考虑用如下方法来确认：
drop table EMPLOYEES_TMP;
create table EMPLOYEES_TMP as select * from EMPLOYEES where rowid in (select head_rowid from chained_rows);
Delete from EMPLOYEES where rowid in (select head_rowid from chained_rows);
Insert into EMPLOYEES_BK select * from EMPLOYEES_TMP;
analyze table EMPLOYEES list chained rows into chained_rows;
select count(*)  from chained_rows where table_name='EMPLOYEES';
--这时的取值一定为0，用这种方法做行迁移消除，肯定是没问题的！
---------------------------------------------------------------------------------

脚本3-61  检查所有表是否存在行迁移的脚本
select 'analyze table '|| table_name ||' list chained rows into chained_rows;' from user_tables;
select * from chained_rows;


脚本3-62  块的大小应用环境工作（分别建8K和16K的表空间）
drop tablespace TBS_LJB INCLUDING CONTENTS AND DATAFILES;
create tablespace TBS_LJB 
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_01.DBF'  size 1G;  

drop tablespace TBS_LJB_16K INCLUDING CONTENTS AND DATAFILES;
create tablespace TBS_LJB_16K
blocksize 16K 
datafile  'E:\ORADATA\ORA10\DATAFILE\TBS_LJB_16k_01.DBF'  size 1G; 


脚本3-63  块的大小应用准备工作（在16K表空间建表）
drop table t_16k purge;
create table t_16k tablespace tbs_ljb_16k as select * from dba_objects ;
insert into t_16k  select * from t_16k;
insert into t_16k  select * from t_16k;
insert into t_16k  select * from t_16k;
insert into t_16k  select * from t_16k;
insert into t_16k  select * from t_16k;
insert into t_16k  select * from t_16k;
commit;
update t_16k set object_id=rownum ;
commit;
create index idx_object_id on t_16k(object_id);


脚本3-64  块的大小应用准备工作（在8K表空间建表）
drop table t_8k purge;
create table t_8k tablespace  tbs_ljb as select * from dba_objects ;
insert into t_8k  select * from t_8k;
insert into t_8k  select * from t_8k;
insert into t_8k  select * from t_8k;
insert into t_8k  select * from t_8k;
insert into t_8k  select * from t_8k;
insert into t_8k  select * from t_8k;
commit;
update t_8k set object_id=rownum ;
commit;
create index idx_object_id_8k on t_8k(object_id);


脚本3-65  BLOCK为16K表的空间全表扫性能
set linesize 1000
set timing on
select count(*) from t_16k;


脚本3-66  BLOCK为 8K的表空间的全表扫性能
select count(*) from t_8k;

脚本3-67  BLOCK大小为 8K的表空间的索引读性能
select * from t_8k where object_id=29;


脚本3-68  BLOCK大小为 16K的表空间的索引读性能
select * from t_16k where object_id=29;
