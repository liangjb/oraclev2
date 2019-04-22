脚本11-1  判断过长的SQL
select sql_id, count(*)
  from v$sqltext
 group by sql_id
having count(*) >= 100
 order by count(*) desc;


脚本11-2  使用Nest Loop Join但是未用到索引的，比较可疑
drop table t purge;
create table t as select * from v$sql_plan;  
     
select *
  from t
 where sql_id not in (select sql_id
                    from t
                   where sql_id in (select sql_id from t where operation = 'NESTED LOOPS' )
                     and (operation like '%INDEX%' or object_owner like '%SYS%'))
   and sql_id in
       (select sql_id from t where sql_id in (select sql_id from t where operation = 'NESTED LOOPS'));   


脚本11-3  找出非SYS用户用HINT的所有SQL来分析
select sql_text,
       sql_id,
       module,
       t.service,
       first_load_time,
       last_load_time,
       executions
  from v$sql t
 where sql_text like '%/*+%'
 and t.SERVICE not like 'SYS$%';


脚本11-4  找出被设置成并行属性的表和索引，并修正
select t.owner, t.table_name, degree
  from dba_tables t
 where t.degree > '1';
 
select t.owner, t.table_name, index_name, degree, status
  from dba_indexes t
 where owner in ('LJB')
   and t.degree > '1';

--有问题就要处理，比如索引有并行，就处理如下：
select 'alter index '|| t.owner||'.'||index_name || ' noparallel;'
      from dba_indexes t
     where owner in ('LJB')
       and t.degree >'1';


脚本11-5  属性未设并行，但是HINT设并行的SQL
select sql_text,
        sql_id,
        module,
        .service,
        first_load_time,
        last_load_time,
        executions
  from v$sql t
 where sql_text like '%parall%'
   and t.SERVICE not like 'SYS$%';


脚本11-6  捞取对列进行运算的SQL

select sql_text,
        sql_id,
         module,
        t.service,
        first_load_time,
        last_load_time,
        executions
  from v$sql t
 where (upper(sql_text) like '%TRUNC%' 
     or upper(sql_text) like '%TO_DATE%' 
     or upper(sql_text) like '%SUBSTR%')
   and t.SERVICE not like 'SYS$%';


脚本11-7  捞取注释少于代码十分之一的程序

select * from (
  select name,
       t.type,
       sum(case when text like '%--%' then 1 else 0 end) / count(*) rate
     from user_source t
    where type in ('package body', 'procedure', 'function')---包头就算了
     group by name, type
     having sum(case when text like '%--%' then 1 else 0 end) / count(*)<=1/10)
 order by  rate;



脚本11-8  动态SQL未用USING有可能未用绑定变量
select *
  from user_source
 where name  in
       (select name from user_source where name in (select name from user_source where UPPER(text) like '%EXECUTE IMMEDIATE%'))
       and name in
       (select name from user_source where name in (select name from user_source where UPPER(text) like '%||%')) 
       and name not in 
       (select name from user_source where name in (select name from user_source where upper(text) not like '%USING%')) ;



脚本11-9  查询提交次数过多的SESSION
 select t1.sid, t1.value, t2.name
   from v$sesstat t1, v$statname t2
 --where t2.name like '%commit%'
  where t2.name like '%user commits%' --可以只选user commits，其他系统级的先不关心
    and t1.STATISTIC# = t2.STATISTIC#
    and value >= 10000
  order by value desc;



脚本11-10  查询未用包的程序逻辑
select distinct name, type
  from user_source
 where type in ('PROCEDURE', 'FUNCTION')
 order by type;



脚本11-11  大小超过10GB未建分区的表

--表大小超过10GB未建分区的
select owner,
 segment_name,
 segment_type,
 sum(bytes) / 1024 / 1024 / 1024 object_size
 from dba_segments
 WHERE  segment_type = 'TABLE' ---此处说明是普通表，不是分区表，如果是分区表，类型是TABLE PARTITION
 group by owner, segment_name, segment_type
having sum(bytes) / 1024 / 1024 / 1024 >= 10
 order by object_size desc;



脚本11-12  查询分区个数超过100的表
--分区个数超过100个的表
select table_owner, table_name, count(*) cnt
 from user_tab_partitions
 WHERE dba_owner in ('LJB')
 having count(*)>=100
 group by table_owner, table_name
 order by cnt desc;



脚本11-13  表大小超过10GB，有时间字段，可考虑在该列建分区
---超过10GB的大表没有时间字段

select T1.*, t2.column_name, t2.data_type
  from (select segment_name,
               segment_type,
               sum(bytes) / 1024 / 1024 / 1024 object_size
          from user_segments
         WHERE segment_type = 'TABLE' ---此处说明是普通表，不是分区表，如果是分区表，类型是TABLE PARTITION
         group by segment_name, segment_type
        having sum(bytes) / 1024 / 1024 / 1024 >= 0.01
         order by object_size desc) t1,
       user_tab_columns t2
 where t1.segment_name = t2.table_name(+)
   and t2.DATA_TYPE = 'DATE' ;     --来说明这个大表有时间列
 
---上述语句和下面的语句进行观察比较
select segment_name,
               segment_type,
               sum(bytes) / 1024 / 1024 / 1024 object_size
          from user_segments
         WHERE segment_type = 'TABLE' ---此处说明是普通表，不是分区表，如果是分区表，类型是TABLE PARTITION
         group by segment_name, segment_type
        having sum(bytes) / 1024 / 1024 / 1024 >= 0.01
         order by object_size desc;



脚本11-14  找出有建触发器的表，同时观察该表多大
select trigger_name, table_name, tab_size
  from user_triggers t1,
       (select segment_name, sum(bytes / 1024 / 1024 / 1024)  tab_size
          from user_segments t
         where t.segment_type='TABLE'
         group by segment_name) t2
where t1.TABLE_NAME=t2.segment_name;




脚本11-15  查询那些表未做注释
col COMMENTS for a40;
select TABLE_NAME,T.TABLE_TYPE
  from USER_TAB_COMMENTS T
 where table_name not like 'BIN$%'
   and comments is null
order by table_name;





脚本11-16  查询那些列未做注释（仅供参考）
select TABLE_NAME,COLUMN_NAME
  from USER_COL_COMMENTS
 where table_name not like'BIN$%'
   and comments isnull
order by table_name;




脚本11-17  查询那些列是LONG类型
 SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
    FROM user_tab_columns
   WHERE DATA_TYPE = 'LONG'
ORDER BY 1, 2;




脚本11-18  查询那些列是CHAR类型
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
    FROM user_tab_columns
   WHERE DATA_TYPE = 'CHAR'
ORDER BY 1, 2;




脚本11-19  查询那些索引是函数索引
select
       t.index_name,
       t.index_type,
       t.status,
       t.blevel,
       t.leaf_blocks
  from user_indexes t
 where index_type in ('FUNCTION-BASED NORMAL');



脚本11-20  查询那些索引是位图索引
select
       t.index_name,
       t.index_type,
       t.status,
       t.blevel,
       t.leaf_blocks
  from user_indexes t
 where index_type in ('BITMAP');



脚本11-21  查询外键未建索引的表有哪些
select table_name,
       constraint_name,
       cname1 || nvl2(cname2, ',' || cname2, null) ||
       nvl2(cname3, ',' || cname3, null) ||
       nvl2(cname4, ',' || cname4, null) ||
       nvl2(cname5, ',' || cname5, null) ||
       nvl2(cname6, ',' || cname6, null) ||
       nvl2(cname7, ',' || cname7, null) ||
       nvl2(cname8, ',' || cname8, null) columns
  from (select b.table_name,
               b.constraint_name,
               max(decode(position, 1, column_name, null)) cname1,
               max(decode(position, 2, column_name, null)) cname2,
               max(decode(position, 3, column_name, null)) cname3,
               max(decode(position, 4, column_name, null)) cname4,
               max(decode(position, 5, column_name, null)) cname5,
               max(decode(position, 6, column_name, null)) cname6,
               max(decode(position, 7, column_name, null)) cname7,
               max(decode(position, 8, column_name, null)) cname8,
               count(*) col_cnt
          from (select substr(table_name, 1, 30) table_name,
                       substr(constraint_name, 1, 30) constraint_name,
                       substr(column_name, 1, 30) column_name,
                       position
                  from user_cons_columns) a,
               user_constraints b
         where a.constraint_name = b.constraint_name
           and b.constraint_type = 'R'
         group by b.table_name, b.constraint_name) cons
 where col_cnt > ALL
 (select count(*)
          from user_ind_columns i
         where i.table_name = cons.table_name
           and i.column_name in (cname1, cname2, cname3, cname4, cname5,
                cname6, cname7, cname8)
           and i.column_position <= cons.col_cnt
         group by i.index_name);



脚本11-22  将有不等值查询的SQL捞取出来分析
select sql_text,
       sql_id,
       service,
       module,
       t. first_load_time
       t. last_load_time
  from v$sql t
 where (sql_text like '%>%' or sql_text like '%<%' or sql_text like '%<>%')
   and sql_text not like '%=>%'
   and service not like 'SYS$%';
   
   
   
   
脚本11-23  捞取超过4个字段组合的联合索引
select table_name, index_name, count(*)
  from user_ind_columns
 group by table_name, index_name
having count(*) >= 4
 order by count(*) desc;




脚本11-24  单表的索引个数超过5个，需注意
select table_name, count(*)
  from user_indexes
 group by table_name
having count(*) >= 5
 order by count(*) desc;



脚本11-25  跟踪索引的使用情况，控制索引的数量
select 'alter index '||index_name||' monitoring usage;'
from user_indexes;
然后观察：
set linesize 166
col INDEX_NAME for a10
col TABLE_NAME for a10
col START_MONITORING for a25
col END_MONITORING for a25
select * from v$object_usage;
--停止对索引的监控，观察v$object_usage状态变化（以某索引IDX——OBJECT——ID为例）
alter index IDX_OBJECT_ID nomonitoring usage;





脚本11-26  查询无任何索引的表
select table_name
  from user_tables
 where table_name not in (select table_name from user_indexes);





脚本11-27  查询失效的普通索引
select index_name, table_name, tablespace_name, index_type
  from user_indexes
 where status = 'UNUSABLE';




脚本11-28  查询失效的分区局部索引
select  t1.index_name,                         
       t1.partition_name,                     
       t1.global_stats,                       
       t2.table_name,                         
       t2.table_type                          
  from user_ind_partitions t1, user_indexes t2
 where t2.index_name = t1.index_name          
   and t1.status = 'UNUSABLE'; 

   

脚本11-29  查询表的前缀是否以T打头
select * from user_tables where substr(table_name,1,2)<>'T_' ;


脚本11-30  查询视图的前缀是否以V打头
select view_name from user_views where substr(view_name,1,2)<>'V_' ;


脚本11-32  查询簇表的前缀是否以c打头
select t.cluster_name,t.cluster_type
  from user_clusters t
 where substr(cluster_name, 1, 2) <> 'C_';


脚本11-33  查询序列的前缀是否以seq打头或结尾
select sequence_name,cache_size
  from user_sequences
 where sequence_name not like '%SEQ%';


脚本11-34  查询存储过程是否以p打头
select object_name,procedure_name
  from user_procedures
 where object_type = 'PROCEDURE'
   and substr(object_name, 1, 2) <> 'P_';


脚本11-35  查询函数是否以f打头
select object_name,procedure_name
  from user_procedures
 where object_type = 'FUNCTION'
   and substr(object_name, 1, 2) <> 'F_';



脚本11-36  查询包是否以pkg打头
select object_name,procedure_name
  from user_procedures
 where object_type = 'PACKAGE'
   and substr(object_name, 1, 4) <> 'PKG_';



脚本11-37 查询类是否以typ打头
select object_name,procedure_name
  from user_procedures
 where object_type = 'TYPE'
   and substr(object_name, 1, 4) <> 'TYP_';


脚本11-38  查询主键是否以pk打头
select constraint_name, table_name
  from user_constraints
 where constraint_type = 'P'
   and substr(constraint_name, 1, 3) <> 'PK_'
   and constraint_name not like 'BIN$%';


脚本11-39  查询外键是否以fk打头
select constraint_name,table_name
  from user_constraints
 where constraint_type = 'R'
   and substr(constraint_name, 1, 3) <> 'FK_'
   and constraint_name not like 'BIN$%';


脚本11-40  查询唯一索引是否以ux打头
select constraint_name,table_name
  from user_constraints
 where constraint_type = 'U'
   and substr(constraint_name, 1, 3) <> 'UX_'
   and table_name not like 'BIN$%';


脚本11-41  查询普通索引是否以idx打头
select index_name,table_name
  from user_indexes 
 where index_type='NORMAL'
   and uniqueness='NONUNIQUE'
   and substr(index_name, 1, 4) <> 'IDX_'
   and table_name not like 'BIN$%';


脚本11-42  查询位图索引是否以bx打头
select index_name,table_name
  from user_indexes
 where index_type LIKE'%BIT%'
   and substr(index_name, 1, 3) <>'BX_'
   and table_name notlike'BIN$%';


脚本11-43  查询函数索引是否以fx打头
select index_name,table_name
  from user_indexes
 where index_type='FUNCTION-BASED NORMAL'
   and substr(index_name, 1, 3) <>'FX_'
   and table_name notlike'BIN$%';
