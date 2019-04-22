脚本5-1  做索引高度较低应用试验前的构造表
drop table t1 purge;
drop table t2 purge;
drop table t3 purge;
drop table t4 purge;
drop table t5 purge;
drop table t6 purge;
drop table t7 purge;
create table t1 as select rownum as id ,rownum+1 as id2 from dual connect by level<=5;
create table t2 as select rownum as id ,rownum+1 as id2 from dual connect by level<=50;
create table t3 as select rownum as id ,rownum+1 as id2 from dual connect by level<=500;
create table t4 as select rownum as id ,rownum+1 as id2 from dual connect by level<=5000;
create table t5 as select rownum as id ,rownum+1 as id2 from dual connect by level<=50000;
create table t6 as select rownum as id ,rownum+1 as id2 from dual connect by level<=500000;
create table t7 as select rownum as id ,rownum+1 as id2 from dual connect by level<=5000000;



脚本5-2  继续完成建索引的准备工作
create index idx_id_t1 on t1(id);
create index idx_id_t2 on t2(id);
create index idx_id_t3 on t3(id);
create index idx_id_t4 on t4(id);
create index idx_id_t5 on t5(id);
create index idx_id_t6 on t6(id);
create index idx_id_t7 on t7(id);



脚本5-3  观察比较各个索引的大小
select segment_name, bytes/1024                                             
      from user_segments                                                        
     where segment_name in ('IDX_ID_T1', 'IDX_ID_T2', 'IDX_ID_T3', 'IDX_ID_T4', 
            'IDX_ID_T5', 'IDX_ID_T6', 'IDX_ID_T7');     


脚本5-4  观察比较各个索引的高度
select index_name,
              blevel,
              leaf_blocks,
              num_rows,
              distinct_keys,
              clustering_factor
         from user_ind_statistics
        where table_name in( 'T1','T2','T3','T4','T5','T6','T7');


脚本5-5  观察上述与t6表相关的索引扫描的性能
set autotrace traceonly
set linesize 1000
set timing on
select * from t6 where id=10;



脚本5-6  观察上述与t7表相关的索引扫描的性能
select * from t7 where id=10;



脚本5-7  再次测试与t6表相关的全表扫描查询的性能
drop index IDX_ID_T6 ;
select * from t6 where id=10;



脚本5-8  再次测试与t7表相关的全表扫描查询的性能
drop index IDX_ID_T7 ;
select * from t7 where id=10;



脚本5-9  分区索引相关试验的准备工作
drop table part_tab purge;
create table part_tab (id int,col2 int,col3 int)
           partition by range (id)
           (
           partition p1 values less than (10000),
           partition p2 values less than (20000),
           partition p3 values less than (30000),
           partition p4 values less than (40000),
           partition p5 values less than (50000),
           partition p6 values less than (60000),
           partition p7 values less than (70000),
           partition p8 values less than (80000),
           partition p9 values less than (90000),
           partition p10 values less than (100000),
           partition p11 values less than (maxvalue)
           )
           ;
insert into part_tab select rownum,rownum+1,rownum+2 from dual connect by rownum <=110000;
commit;
create  index idx_par_tab_col2 on part_tab(col2) local;
create  index idx_par_tab_col3 on part_tab(col3) ;



脚本5-10  分区索引情况查看
col segment_name format a20
select segment_name, partition_name, segment_type
      from user_segments
     where segment_name = 'PART_TAB';

select segment_name, partition_name, segment_type
      from user_segments
     where segment_name = 'IDX_PAR_TAB_COL2';


select segment_name, partition_name, segment_type
      from user_segments
     where segment_name = 'IDX_PAR_TAB_COL3';



脚本5-11  继续做准备工作，构建普通表及索引
drop table norm_tab purge;
create table norm_tab (id int,col2 int,col3 int);
insert into norm_tab select rownum,rownum+1,rownum+2 from dual connect by rownum <=110000;。
commit;
create  index idx_nor_tab_col2 on norm_tab(col2) ;
create  index idx_nor_tab_col3 on norm_tab(col3) ;



脚本5-12  全分区索引扫描产生大量逻辑读
set autotrace traceonly
set linesize 1000
set timing on
select * from part_tab where col2=8 ;



脚本5-13  普通表索引扫描逻辑读少的多
select * from norm_tab where col2=8 ;



脚本5-14  分别观察分区表和普通表的索引高度
select index_name,
         blevel,
         leaf_blocks,
         num_rows,
         distinct_keys,
clustering_factor 
FROM USER_IND_PARTITIONS
 where index_name='IDX_PAR_TAB_COL2';

select index_name,
               blevel,
               leaf_blocks,
               num_rows,
               distinct_keys,
               clustering_factor
          from user_ind_statistics
         where index_name ='IDX_NOR_TAB_COL2';


脚本5-15  分区索引扫描仅落在某一分区，性能大幅提升
select * from part_tab where col2=8 and id=7;




脚本5-16  COUNT(*)优化试验前的建表及索引
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);
select count(*) from t;



脚本5-17  COUNT(*)在索引列有空值时无法用到索引
---重要说明：在11g的某些版本下，T表建出的object_id列可能属性是not null，这种情况下，可考虑执行alter table T modify object_id  null后再做试验
set autotrace on
set linesize 1000
set timing on
select count(*) from t;



脚本5-18  明确索引列非空，即可让COUNT(*)用到索引
set autotrace on
set linesize 1000
set timing on
select count(*) from t where object_id is not null;



脚本5-19  查看T表的列是否为空
desc t;   


脚本5-20  修改object_id列为非空
SQL> alter table t modify OBJECT_ID not null;



脚本5-21  这下不改SQL，让count(*)用到索引
set autotrace on
set linesize 1000
set timing on
select count(*) from t ;




脚本5-22  object_id列为主键，也可说明了非空属性
drop table t purge;
create table t as select * from dba_objects;
alter table t add constraint pk1_object_id primary key (OBJECT_ID);
set autotrace on
set linesize 1000
set timing on
select count(*) from t;




脚本5-23  SUM/AVG优化试验准备之表及索引构建
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);



脚本5-24  SUM/AVG用不到索引（因为列允许为空）
---重要说明：在11g的某些版本下，T表建出的object_id列可能属性是not null，这种情况下，可考虑执行alter table T modify object_id  null后再做试验
set autotrace on
set linesize 1000
set timing on
select sum(object_id) from t;



脚本5-25  在说明索引列非空后，SUM/AVG可用到索引
set autotrace on
set linesize 1000
select sum(object_id) from t where object_id is not null;



脚本5-26  SUM、AVG、COUNT综合写法试验
select sum(object_id) ,avg(object_id),count(*) from t where object_id is not null;



脚本5-27  MAX/MIN试验前的准备工作
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);



脚本5-28  MAX/MIN语句应用索引非常高效
select max(object_id) from t;



脚本5-29  测MAX性能前的准备，构建一张大表
create table t_max as select * from dba_objects；
create index idx_t_max_obj on t_max(object_id);
   insert into t_max select * from t_max;
   insert into t_max select * from t_max;
   insert into t_max select * from t_max;
   insert into t_max select * from t_max;
   insert into t_max select * from t_max;
commit;
select count(*) from t_max;




脚本5-30  表大小差异明显，MAX/MIN的性能却几无差异
set autotrace on
set linesize 1000
select max(object_id) from t_max;
select min(object_id) from t_max;



脚本5-31  MIN和MAX同时写的优化（空值导致用不到索引）
set autotrace on
set linesize 1000
select min(object_id),max(object_id) from t ;


脚本5-32  MIN和MAX同时写的优化（无法用INDEX FULL SCAN (MIN/MAX)）
set autotrace on
set linesize 1000
select min(object_id),max(object_id) from t  where object_id is not null;


脚本5-33  有趣的改写，完成了MAX/MIN同时写的最佳优化
set autotrace on
set linesize 1000
set timing on 
 select max, min
      from (select max(object_id) max from t ) a, (select min(object_id) min from t) b;
注：另一写法供参考，效率是一样的
SELECT (select max(object_id) max from t) max_id
     , (select min(object_id) min from t) min_id
  FROM DUAL;



脚本5-34  索引回表读（TABLE ACCESS BY INDEX ROWID）的例子
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
set timing on
select * from t where object_id<=5;


脚本5-35  比较消除TABLE ACCESS BY INDEX ROWID的性能
set autotrace traceonly
set linesize 1000
set timing on
select object_id from t where object_id<=5;



脚本5-36  再观察一个TABLE ACCESS BY INDEX ROWID的例子
set autotrace traceonly
set linesize 1000
select object_id,object_name from t where object_id<=5;



脚本5-37  准备工作，对t表建联合索引
create index idx_un_objid_objname on t(object_id,object_name);



脚本5-38  联合索引消除了TABLE ACCESS BY INDEX ROWID
select object_id,object_name from t where object_id<=5


脚本5-39  聚合因子试验准备，分别建两张有序和无序的表
drop table t_colocated purge;
create table t_colocated ( id number, col2 varchar2(100) );
begin
        for i in 1 .. 100000
        loop
            insert into t_colocated(id,col2)
            values (i, rpad(dbms_random.random,95,'*') );
        end loop;
    end;
    /

alter table t_colocated add constraint pk_t_colocated primary key(id);
drop table t_disorganized purge;
create table t_disorganized
     as
    select id,col2
    from t_colocated
    order by col2;

alter table t_disorganized add constraint pk_t_disorg primary key (id);




脚本5-40  分别分析两张表的聚合因子层度
set linesize 1000                                                          
select index_name,                                                         
              blevel,                                                          
              leaf_blocks,                                                     
              num_rows,                                                        
              distinct_keys,                                                   
              clustering_factor                                                
         from user_ind_statistics                                              
        where table_name in( 'T_COLOCATED','T_DISORGANIZED');        


脚本5-41  首先观察有序表的查询性能
set linesize 1000
alter session set statistics_level=all;

select /*+index(t)*/ * from  t_colocated t  where id>=20000 and id<=40000;
---此处略去2万行记录的输出翻屏过程
SELECT * FROM table(dbms_xplan.display_cursor(NULL,NULL,'runstats_last')); 



脚本5-42  再观察无序表的查询性能
select /*+index(t)*/ * from  t_disorganized t  where id>=20000 and id<=40000;
SELECT * FROM table(dbms_xplan.display_cursor(NULL,NULL,'runstats_last')); 



脚本5-43  未排序前的性能开销（COST）较低
set autotrace traceonly
set linesize 1000
drop table t purge;
create table t as select * from dba_objects;
set autotrace traceonly
select * from t where object_id>2;



脚本5-44  排序后的性能开销（COST）增大
select * from t where object_id>2 order by object_id;



脚本5-45  观察排序试验的建索引准备工作
create index idx_t_object_id on t(object_id);


脚本5-46  当排序列是索引列时，排序居然消除了
set linesize 1000
set autotrace traceonly
select * from t where object_id>2 order by object_id;



脚本5-47  消除TABLE ACCESS BY INDEX ROWID后COST更低了
select object_id from t where object_id>2 order by object_id;



脚本5-48  DISTINCT测试前的准备
drop table t purge;
create table t as select * from dba_objects;
alter table T modify OBJECT_ID not null;
update t set object_id=2;
update t set object_id=3 where rownum<=25000;
commit;




脚本5-49  发现DISTINCT会产生排序
set autotrace traceonly
select  distinct object_id from t ;



脚本5-50  SQL去掉DISTINCT后，排序立即消失
set autotrace traceonly
select object_id from t ;


脚本5-51  DISTINCT遇到等值查询时略显特殊
SQL> select  distinct object_id from t where object_id=2;



脚本5-52  为T表的object_id列建索引
create index idx_t_object_id on t(object_id);



脚本5-53  该列建索引，DISTINCT引发的排序即可消除
select  /*+index(t)*/ distinct object_id from t ;



脚本5-54  INDEX FAST FULL SCAN（可让逻辑读少，但是无法消除排序）
set linesize 1000
set autotrace traceonly
select  distinct object_id from t ;



脚本5-55  INDEX FULL SCAN（可消除排序，但逻辑读比索引快速全扫描多）
select object_id from t order by object_id;



脚本5-56  UNION 是需要排序的
drop table t1 purge;
create table t1 as select * from dba_objects;
alter table t1 modify OBJECT_ID not null;
drop table t2 purge;
create table t2 as select * from dba_objects;
alter table t2 modify OBJECT_ID not null;
set linesize 1000
set autotrace traceonly
select object_id from t1
    union
    select object_id from t2;



脚本5-57  索引无法消除UNION 排序（INDEX FAST FULL SCAN）
create index idx_t1_object_id on t1(object_id);
索引已创建。
create index idx_t2_object_id on t2(object_id);
set autotrace traceonly
set linesize 1000
select  object_id from t1
    union
    select  object_id from t2;



脚本5-58  INDEX FULL SCAN的索引依然无法消除UNION排序
select /*+index(t1)*/ object_id from t1
    union
    select /*+index(t2)*/  object_id from t2;



脚本5-59  外键索引性能研究之准备
drop table t_p cascade constraints purge;
drop table t_c cascade constraints purge;
CREATE TABLE T_P (ID NUMBER, NAME VARCHAR2(30));
ALTER TABLE T_P ADD CONSTRAINT  T_P_ID_PK  PRIMARY KEY (ID);
CREATE TABLE T_C (ID NUMBER, FID NUMBER, NAME VARCHAR2(30));
ALTER TABLE T_C ADD CONSTRAINT FK_T_C FOREIGN KEY (FID) REFERENCES T_P (ID);
INSERT INTO T_P SELECT ROWNUM, TABLE_NAME FROM ALL_TABLES;
INSERT INTO T_C SELECT ROWNUM, MOD(ROWNUM, 1000) + 1, OBJECT_NAME  FROM ALL_OBJECTS;
COMMIT;


脚本5-60  外键未建索引前的表连接性能分析
set autotrace traceonly
set linesize 1000
SELECT A.ID, A.NAME, B.NAME FROM T_P A, T_C B WHERE A.ID = B.FID AND A.ID = 880;



脚本5-61  外键建索引后的表连接性能分析
CREATE INDEX IND_T_C_FID ON T_C (FID);
SELECT A.ID, A.NAME, B.NAME FROM T_P A, T_C B WHERE A.ID = B.FID AND A.ID = 880;



脚本5-62  外键有索引，没有死锁情况产生
--首先开启会话1
select sid from v$mystat where rownum=1;
DELETE T_C WHERE ID = 2;

--接下来开启会话2，也就是开启一个新的连接
select sid from v$mystat where rownum=1;
DELETE T_P WHERE ID = 2000;



脚本5-63  外键索引先删除
drop index  IND_T_C_FID;



脚本5-64  外键索引删除后，立即有锁相关问题
--首先开启会话1
select sid from v$mystat where rownum=1;
DELETE T_C WHERE ID = 2;
--接下来开启会话2，也就是开启一个新的连接
select sid from v$mystat where rownum=1;
 
--然后执行如下进行观察
DELETE T_P WHERE ID = 2000;
--居然发现卡住半天不动了！



脚本5-65  删除主键所在表的记录失败
DELETE T_P WHERE ID = 2;

        
        
脚本5-66  外键关联表的对应记录没删除
select count(*) from T_C WHERE FID=2;



脚本5-67  外键所在表的相关记录删除后，操作成功
delete from T_C WHERE FID=2;
COMMIT;
DELETE T_P WHERE ID = 2;
COMMIT;



脚本5-68  级联删除设置
alter table T_C drop constraint FK_T_C;
ALTER TABLE T_C ADD CONSTRAINT FK_T_C FOREIGN KEY (FID) REFERENCES T_P (ID) ON DELETE CASCADE;



脚本5-69  果然可以通过级联自动删除
SELECT COUNT(*) FROM T_C WHERE FID=3;
DELETE FROM T_P WHERE ID=3;
COMMIT;
SELECT COUNT(*) FROM T_C WHERE FID=3;



脚本5-70  在表T的ID列建普通索引
drop table t cascade constraints purge;
CREATE TABLE T (ID NUMBER, NAME VARCHAR2(30));
INSERT INTO T SELECT ROWNUM, TABLE_NAME FROM ALL_TABLES;
COMMIT;
CREATE INDEX IDX_T_ID ON t(ID);



脚本5-71  为ID列增加主键约束，即成主键
alter table t add constraint t_id_pk primary key (ID);



脚本5-72  观察object_id,object_type 顺序的组合索引
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id,object_type);
create index idx2_object_id on t(object_type,object_id);
set autotrace traceonly
set linesize 1000
select /*+index(t,idx1_object_id)*/ * from  t  where object_id=20  and object_type='TABLE';



脚本5-73  观察object_type, object_id顺序的组合索引
set autotrace traceonly
set linesize 1000
select /*+index(t,idx2_object_id)*/ * from  t  where object_id=20  and object_type='TABLE';



脚本5-74  此例中，用到dx1_object_id性能更低
set autotrace traceonly
set linesize 1000
select /*+index(t,idx1_object_id)*/ *  from  t where object_id>=20 and object_id<2000  and object_type='TABLE';



脚本5-75  此例中，用到dx2_object_id性能更高
set autotrace traceonly
set linesize 1000
select /*+index(t,idx2_object_id)*/ *  from  t where object_id>=20 and object_id<2000   and object_type='TABLE';



脚本5-76  in的优化之建表准备
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum ;
UPDATE t SET OBJECT_ID=20 WHERE ROWNUM<=26000;
UPDATE t SET OBJECT_ID=21 WHERE OBJECT_ID<>20;
commit;
create index idx1_object_id on t(object_id,object_type);



脚本5-77  in的优化的记录准备
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum ;
UPDATE t SET OBJECT_ID=20 WHERE ROWNUM<=26000;
UPDATE t SET OBJECT_ID=21 WHERE OBJECT_ID<>20;
commit;
create index idx1_object_id on t(object_id,object_type);



脚本5-78  范围查询性能较低
set autotrace traceonly
set linesize 1000
select  /*+index(t,idx1_object_id)*/ * from t  where object_TYPE='TABLE'  AND OBJECT_ID >= 20 AND OBJECT_ID<= 21;



脚本5-79  范围查询改造为IN写法后，性能提升
select  /*+index(t,idx1_object_id)*/ * from t t where object_TYPE='TABLE'  AND  OBJECT_ID IN (20,21);


脚本5-80  组合索引的前缀与单列索引一致
drop table t purge;
create table t as select * from dba_objects;
create index idx_object_id on t(object_id,object_type);
set autotrace traceonly
set linesize 1000
select * from t where object_id=19;



脚本5-81  组合索引的前缀与单列索引不一致
drop index idx_object_id;
create index idx_object_id on t(object_type, object_id);
select * from t where object_id=19;



脚本5-82  做索引个数与插入速度试验前的准备
drop table t_no_idx purge;
drop table t_1_idx purge;
drop table t_2_idx purge;
drop table t_3_idx purge;
drop table t_n_idx purge;
create table t_no_idx as select * from dba_objects;
insert into t_no_idx select * from t_no_idx;
insert into t_no_idx select * from t_no_idx;
insert into t_no_idx select * from t_no_idx;
insert into t_no_idx select * from t_no_idx;
insert into t_no_idx select * from t_no_idx;
commit;
select count(*) from t_no_idx;
create table t_1_idx as select * from t_no_idx;
create index idx_1_1 on t_1_idx(object_id);
create table t_2_idx as select * from t_no_idx;
create index idx_2_1 on t_2_idx(object_id);
create index idx_2_2 on t_2_idx(object_name);
create table t_3_idx as select * from t_no_idx;
create index idx_3_1 on t_3_idx(object_id);
create index idx_3_2 on t_3_idx(object_name);
create index idx_3_3 on t_3_idx(object_type);



脚本5-83  索引个数与插入速度快慢关系紧密
set timing on
insert into t_no_idx select * from t_no_idx where rownum<=100000;
insert into t_1_idx select * from t_1_idx where rownum<=100000;
commit;
insert into t_2_idx select * from t_2_idx where rownum<=100000;
insert into t_3_idx select * from t_3_idx where rownum<=100000;



脚本5-84 有序插入影响更大
set timing on
insert into t_no_idx select * from t_no_idx where rownum<=100000 order by dbms_random.random
commit;
insert into t_1_idx select * from t_1_idx where rownum<=100000 order by dbms_random.random;
commit;
insert into t_2_idx select * from t_1_idx where rownum<=100000 order by dbms_random.random;
commit;
insert into t_3_idx select * from t_3_idx where rownum<=100000 order by dbms_random.random;




脚本5-85  假如索引最后建，可巧妙提升性能
set timing on
create index idx_no_1 on t_no_idx(object_id);
create index idx_no_2 on t_no_idx(object_name);
create index idx_no_3 on t_no_idx(object_type);



脚本5-86  索引监控的查询脚本
drop table t purge;
create table t as select * from dba_objects;
create index idx_t_id on t (object_id);
create index idx_t_name on t (object_name);
---未监控索引时，v$object_usage查询不到任何记录
select * from v$object_usage;
--接下来对idx_t_id和idx_t_name两列索引做监控



脚本5-87  索引监控的实施
alter index idx_t_id monitoring usage;
alter index idx_t_name monitoring usage;
set linesize 166
col INDEX_NAME for a10
col TABLE_NAME for a10
col MONITORING for a10
col USED for a10
col START_MONITORING for a25
col END_MONITORING for a25
select * from v$object_usage;



脚本5-88  索引监控的跟踪
--以下查询必然用到object_id列的索引
select object_id from t where object_id=19;
--观察分析，果然发现IDX_T_ID列的索引的USED果然更改为YES
select * from v$object_usage;



脚本5-89  位图索引跟踪前准备
drop table t purge;
create table t as select * from dba_objects;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
update t set object_id=rownum;
commit;



脚本5-90  观察COUNT(*)全表扫描的代价
set autotrace on
set linesize 1000
select count(*) from t;
         
         

脚本5-91  观察COUNT(*)用普通索引的代价
create index idx_t_obj on t(object_id);
alter table T modify object_id not null;
set autotrace on
select count(*) from t;



脚本5-92  观察COUNT(*)用位图索引的代价
create bitmap index idx_bitm_t_status on t(status);
select count(*) from t;



脚本5-93  做位图索引与即席查询试验前的准备
SQL> drop table t purge;
SQL>create table t 
(name_id,
 gender not null,
 location not null,
 age_group not null,
 data
 )
 as
 select rownum,
        decode(ceil(dbms_random.value(0,2)),
               1,'M',
               2,'F')gender,
        ceil(dbms_random.value(1,50)) location,
        decode(ceil(dbms_random.value(0,3)),
               1,'child',
               2,'young',
               3,'middle_age',
               4,'old'),
         rpad('*',20,'*')
from dual
connect by rownum<=100000;



脚本5-94  查询即席查询中应用全表扫描的代价
set linesize 1000
set autotrace traceonly
select *
    from t
    where gender='M'
    and location in (1,10,30)
    and age_group='child';



脚本5-95  发现即席查询中，Oracle不选择组合索引
create index idx_union on t(gender,location,age_group);
select *
    from t
    where gender='M'
    and location in (1,10,30)
    and age_group='child';




脚本5-96  强制即席查询使用组合索引性能更糟
select /*+index(t,idx_union)*/ *
    from t
    where gender='M'
    and location in (1,10,30)
    and age_group='child';



脚本5-97 即席查询应用到位图索引，性能有飞跃
create bitmap index gender_idx on t(gender);
create bitmap index location_idx on t(location);
create bitmap index age_group_idx on t(age_group);
select *
    from t
    where gender='M'
    and location in (1,10,30)
    and age_group='41 and over';



脚本5-98  位图索引遭遇锁困扰试验步骤1
sqlplus ljb/ljb
select sid from v$mystat where rownum=1;
insert into t(name_id,gender,location ,age_group ,data) values (100001,'M',45,'child',rpad('*',20,'*'));



脚本5-99 位图索引遭遇锁困扰试验步骤2
sqlplus ljb/ljb
select sid from v$mystat where rownum=1;
insert into t(name_id,gender,location ,age_group ,data) values (100002,'M',46, 'young', rpad('*',20,'*'));



脚本5-100 位图索引遭遇锁困扰试验步骤3
select sid from v$mystat where rownum=1;
insert into t(name_id,gender,location ,age_group ,data) values (100003,'F',47, 'middle_age', rpad('*',20,'*'));



脚本5-101  位图索引遭遇锁困扰试验步骤4
select sid from v$mystat where rownum=1;
insert into t(name_id,gender,location ,age_group ,data) values (100003,'F',48, ' old', rpad('*',20,'*'));




脚本5-102  暂且删除location和age_group列的位图索引，为下一试验做准备
--分别进刚才几个SESSION执行如下操作，完成回退
rollback;
--删除location和age_group列的位图索引
drop index location_idx;
drop index age_group_idx;




脚本5-103  请读者自行测试锁的情况
位图索引之锁持有者的DELETE的实验

--SESSION 1（持有者）
DELETE FROM T WHERE GENDER='M' AND LOCATION=25;
---SESSION 2(其他会话) 插入带M的记录就立即被阻挡，以下三条语句都会被阻止
insert  into t (name_id,gender,location ,age_group ,data) values (100001,'M',78, 'young','TTT');
update t set gender='M' WHERE LOCATION=25;
delete from T WHERE GENDER='M';

--以下是可以进行不受阻碍的
insert  into t (name_id,gender,location ,age_group ,data) values (100001,'F',78, 'young','TTT');
delete from  t where gender='F' ;
UPDATE T SET LOCATION=100 WHERE ROWID NOT IN ( SELECT ROWID FROM T WHERE GENDER='F' AND LOCATION=25) ; --update只要不更新位图索引所在的列即可
        
        

脚本5-104  测试位图索引重复度前准备工作
drop table t purge;
create table t as select * from dba_objects;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
update t set object_id=rownum;
commit;



脚本5-105  COUNT(*)在列重复度低时居然不使用位图索引
create bitmap index idx_bit_object_id on t(object_id);
select count(*) from t;



脚本5-106  强制COUNT(*)用位图索引则性能更低
select /*+index(t,idx_bit_object_id)*/ count(*) from t;



脚本5-107  测函数索引前准备
drop table t purge;
create table t as select * from dba_objects;
create index idx_object_id on t(object_id);
create index idx_object_name on t(object_name);
create index idx_created on t(created);
select count(*) from t;



脚本5-108  对列做UPPER操作，无法用到索引
set autotrace traceonly
set linesize 1000
select * from t  where upper(object_name)='T' ;



脚本5-109  去掉列的UPPER操作后立即用索引
select * from t  where  object_name='T' ;



脚本5-110  建函数索引后，对列做UPPER操作也可用到索引
create index idx_upper_obj_name on t(upper(object_name));
select * from t  where upper(object_name)='T' ;



脚本5-111  观察该函数索引的类型
select index_name, index_type from user_indexes where table_name='T';



脚本5-112  比较where object_id-10<=30和where object_id<=40写法的性能
set autotrace traceonly
set linesize 1000
select * from t where object_id-10<=30;



脚本5-113  你也可以让where object_id-10<=30用到索引
create index idx_object_id_2 on t(object_id-10);
select * from t where object_id-10<=30;






