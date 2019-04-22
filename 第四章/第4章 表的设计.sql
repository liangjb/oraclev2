脚本4-1  查看产生多少日志
select a.name,b.value
    from v$statname a,v$mystat b
    where a.statistic#=b.statistic#
    and a.name='redo size';


脚本4-2  试验准备工作，建观察redo的视图
sqlplus "/ as sysdba"
grant all on v_$mystat to ljb;
grant all on v_$statname to ljb;
connect  ljb/ljb
drop table t purge;
create table t as select * from dba_objects ;
--以下创建视图，方便后续直接用select * from v_redo_size进行查询
create or replace view v_redo_size as
    select a.name,b.value
    from v$statname a,v$mystat b
    where a.statistic#=b.statistic#
    and a.name='redo size';


脚本4-3  观察删除记录产生多少redo
select * from v_redo_size;
delete from t ;
select * from v_redo_size;


脚本4-4  观察插入记录产生多少redo
insert into t select * from dba_objects;
select * from v_redo_size;


脚本4-5  观察更新记录产生多少redo
update t set object_id=rownum;
select * from v_redo_size;


脚本4-6  观察未删除表时产生的逻辑读
drop table t purge;
create table t as select * from dba_objects ;
set autotrace on
select count(*) from t;


脚本4-7  观察delete删除t表所有记录后，居然逻辑读不变
set autotrace off
delete from t ;
commit;
set autotrace on
select count(*) from t;


脚本4-8  truncate清空表后，逻辑读终于大幅度下降了
truncate table t;
select count(*) from t;

脚本4-9  观察TABLE ACCESS BY INDEX ROWID 产生的开销
drop table t purge;
create table t as select * from dba_objects where rownum<=200;
create index idx_obj_id on t(object_id);
set linesize 1000
set autotrace traceonly
select * from t where object_id<=10;

脚本4-10  观察如果消除TABLE ACCESS BY INDEX ROWID的开销情况
select object_id from t where object_id<=10;

脚本4-11  测试表记录顺序插入却难以否保证顺序读出
drop table t purge;
create table t
  (a int,
   b varchar2(4000) default  rpad('*',4000,'*'),
   c varchar2(3000) default  rpad('*',3000,'*')
   );
insert into t (a) values (1); 
insert into t (a) values (2);
insert into t (a) values (3);
select A from t;
delete from t where a=2;
insert into t (a) values (4);
commit;
select A from t;

脚本4-12  比较有无order by 语句在执行计划、开销的差异
set linesize 1000
set autotrace traceonly
select A from t;
select A from t order by A;

脚本4-13  建基于事务和SESSION的全局临时表
drop table t_tmp_session purge;
drop table t_tmp_transaction purge ;
create global temporary table T_TMP_session on commit preserve rows as select  * from dba_objects where 1=2;
select table_name,temporary,duration from user_tables  where table_name='T_TMP_SESSION';
create global temporary table t_tmp_transaction on commit delete rows as select * from dba_objects where 1=2;
select table_name, temporary, DURATION from user_tables  where table_name='T_TMP_TRANSACTION';

脚本4-14  分别观察两种全局临时表针对各类DML语句产生的REDO量
select * from v_redo_size;
insert  into  t_tmp_transaction select * from dba_objects;
select * from v_redo_size;
insert  into  t_tmp_session select * from dba_objects;
select * from v_redo_size;
update t_tmp_transaction set object_id=rownum;
select * from v_redo_size;
update t_tmp_session set object_id=rownum;
delete from t_tmp_session;
select * from v_redo_size;
delete from t_tmp_transaction;
select * from v_redo_size;


脚本4-15  全局临时表和普通表产生日志情况的比较
drop table t purge;
create  table t  as select * from dba_objects where 1=2;
select * from v_redo_size;
insert into  t  select * from dba_objects;
select * from v_redo_size;
update t set object_id=rownum ;
select * from v_redo_size;
delete from t;
select * from v_redo_size; 


脚本4-16  基于事务的全局临时表的高效删除
select count(*) from t_tmp_transaction;
select * from v_redo_size;
insert into t_tmp_transaction select * from dba_objects;
commit;
select * from v_redo_size;
select count(*) from t_tmp_transaction;

脚本4-17  基于SESSION的全局临时表COMMIT并不清空记录
select * from v_redo_size;
insert into t_tmp_session select * from dba_objects;
select * from v_redo_size;
commit;
select count(*) from t_tmp_session;
select * from v_redo_size;


脚本4-18  基于SESSION的全局临时表退出后再登入，观察记录情况
exit
sqlplus ljb/ljb
select count(*) from  t_tmp_session;


脚本4-19  基于全局临时表的会话独立性之观察第1个SESSION
sqlplus ljb/ljb
select * from v$mystat where rownum=1;
select * from t_tmp_session;
insert  into  t_tmp_session select * from dba_objects;
commit;
select count(*) from t_tmp_session;


脚本4-20  基于全局临时表的会话独立性之观察第2个SESSION
sqlplus ljb/ljb
select * from v$mystat where rownum=1;
select count(*) from t_tmp_session;
insert into t_tmp_session select * from  dba_objects where rownum=1;
commit;
select count(*) from t_tmp_session;


脚本4-21  范围分区示例
drop table range_part_tab purge;
--注意，此分区为范围分区
create table range_part_tab (id number,deal_date date,area_code number,contents varchar2(4000))
           partition by range (deal_date)
           (
           partition p1 values less than (TO_DATE('2012-02-01', 'YYYY-MM-DD')),
           partition p2 values less than (TO_DATE('2012-03-01', 'YYYY-MM-DD')),
           partition p3 values less than (TO_DATE('2012-04-01', 'YYYY-MM-DD')),
           partition p4 values less than (TO_DATE('2012-05-01', 'YYYY-MM-DD')),
           partition p5 values less than (TO_DATE('2012-06-01', 'YYYY-MM-DD')),
           partition p6 values less than (TO_DATE('2012-07-01', 'YYYY-MM-DD')),
           partition p7 values less than (TO_DATE('2012-08-01', 'YYYY-MM-DD')),
           partition p8 values less than (TO_DATE('2012-09-01', 'YYYY-MM-DD')),
           partition p9 values less than (TO_DATE('2012-10-01', 'YYYY-MM-DD')),
           partition p10 values less than (TO_DATE('2012-11-01', 'YYYY-MM-DD')),
           partition p11 values less than (TO_DATE('2012-12-01', 'YYYY-MM-DD')),
           partition p12 values less than (TO_DATE('2013-01-01', 'YYYY-MM-DD')),
           partition p_max values less than (maxvalue)
           )
           ;

--以下是插入2012年一整年日期随机数和表示福建地区号含义（591到599）的随机数记录，共有10万条，如下：
insert into range_part_tab (id,deal_date,area_code,contents)
      select rownum,
             to_date( to_char(sysdate-365,'J')+TRUNC(DBMS_RANDOM.VALUE(0,365)),'J'),
             ceil(dbms_random.value(590,599)),
             rpad('*',400,'*')
        from dual
      connect by rownum <= 100000;
commit;





脚本4-22  列表分区示例
drop table list_part_tab purge;
--注意，此分区为列表分区
create table list_part_tab (id number,deal_date date,area_code number,contents varchar2(4000))
           partition by list (area_code)
           (
           partition p_591 values  (591),
           partition p_592 values  (592),
           partition p_593 values  (593),
           partition p_594 values  (594),
           partition p_595 values  (595),
           partition p_596 values  (596),
           partition p_597 values  (597),
           partition p_598 values  (598),
           partition p_599 values  (599),
           partition p_other values  (DEFAULT)
           )
           ;

--以下是插入2012年一整年日期随机数和表示福建地区号含义（591到599）的随机数记录，共有10万条，如下：
insert into list_part_tab (id,deal_date,area_code,contents)
      select rownum,
             to_date( to_char(sysdate-365,'J')+TRUNC(DBMS_RANDOM.VALUE(0,365)),'J'),
             ceil(dbms_random.value(590,599)),
             rpad('*',400,'*')
        from dual
      connect by rownum <= 100000;
commit;



脚本4-23  散列分区示例
drop table hash_part_tab purge;
--注意，此分区HASH分区
create table hash_part_tab (id number,deal_date date,area_code number,contents varchar2(4000))
            partition by hash (deal_date)
            PARTITIONS 12
            ;
--以下是插入2012年一整年日期随机数和表示福建地区号含义（591到599）的随机数记录，共有10万条，如下：
insert into hash_part_tab(id,deal_date,area_code,contents)
      select rownum,
             to_date( to_char(sysdate-365,'J')+TRUNC(DBMS_RANDOM.VALUE(0,365)),'J'),
             ceil(dbms_random.value(590,599)),
             rpad('*',400,'*')
        from dual
      connect by rownum <= 100000;
commit;



脚本4-24  组合分区示例
drop table range_list_part_tab purge;
--注意，此分区为范围分区
create table range_list_part_tab (id number,deal_date date,area_code number,contents varchar2(4000))
           partition by range (deal_date)
             subpartition by list (area_code)
             subpartition TEMPLATE
             (subpartition p_591 values  (591),
              subpartition p_592 values  (592),
              subpartition p_593 values  (593),
              subpartition p_594 values  (594),
              subpartition p_595 values  (595),
              subpartition p_596 values  (596),
              subpartition p_597 values  (597),
              subpartition p_598 values  (598),
              subpartition p_599 values  (599),
              subpartition p_other values (DEFAULT))
           (
            partition p1 values less than (TO_DATE('2012-02-01', 'YYYY-MM-DD')),
            partition p2 values less than (TO_DATE('2012-03-01', 'YYYY-MM-DD')),
            partition p3 values less than (TO_DATE('2012-04-01', 'YYYY-MM-DD')),
            partition p4 values less than (TO_DATE('2012-05-01', 'YYYY-MM-DD')),
            partition p5 values less than (TO_DATE('2012-06-01', 'YYYY-MM-DD')),
            partition p6 values less than (TO_DATE('2012-07-01', 'YYYY-MM-DD')),
            partition p7 values less than (TO_DATE('2012-08-01', 'YYYY-MM-DD')),
            partition p8 values less than (TO_DATE('2012-09-01', 'YYYY-MM-DD')),
            partition p9 values less than (TO_DATE('2012-10-01', 'YYYY-MM-DD')),
            partition p10 values less than (TO_DATE('2012-11-01', 'YYYY-MM-DD')),
            partition p11 values less than (TO_DATE('2012-12-01', 'YYYY-MM-DD')),
            partition p12 values less than (TO_DATE('2013-01-01', 'YYYY-MM-DD')),
            partition p_max values less than (maxvalue)
           )
           ;

--以下是插入2012年一整年日期随机数和表示福建地区号含义（591到599）的随机数记录，共有10万条，如下：
insert into range_list_part_tab(id,deal_date,area_code,contents)
      select rownum,
             to_date( to_char(sysdate-365,'J')+TRUNC(DBMS_RANDOM.VALUE(0,365)),'J'),
             ceil(dbms_random.value(590,599)),
             rpad('*',400,'*')
        from dual
      connect by rownum <= 100000;
commit;



脚本4-25  分区原理分析之普通表插入
drop table norm_tab purge;
create table norm_tab (id number,deal_date date,area_code number,contents varchar2(4000));
insert into norm_tab(id,deal_date,area_code,contents)
      select rownum,
             to_date( to_char(sysdate-365,'J')+TRUNC(DBMS_RANDOM.VALUE(0,365)),'J'),
             ceil(dbms_random.value(590,599)),
             rpad('*',400,'*')
        from dual
      connect by rownum <= 100000;
commit;




脚本4-26  分区原理分析之普通表与分区表在段分配上的差异
SET LINESIZE 666
set pagesize 5000
column segment_name format a20
column partition_name format a20
column segment_type format a20
select segment_name,
       partition_name,
       segment_type,
       bytes / 1024 / 1024 "字节数(M)",
       tablespace_name
  from user_segments
 where segment_name IN('RANGE_PART_TAB','NORM_TAB');



脚本4-27  观察HASH分区的段分配情况
SET LINESIZE 666
set pagesize 5000
column segment_name format a20
column partition_name format a20
column segment_type format a20
select segment_name,
       partition_name,
       segment_type,
       bytes / 1024 / 1024 "字节数(M)",
       tablespace_name
  from user_segments
 where segment_name IN('HASH_PART_TAB');



脚本4-28  观察组合分区的段分配的个数
select count(*)
      from user_segments
     where segment_name ='RANGE_LIST_PART_TAB';


脚本4-29  观察范围分区表的分区消除带来的性能优势
set linesize 1000
set autotrace traceonly
set timing on
select *
      from range_part_tab
     where deal_date >= TO_DATE('2012-09-04', 'YYYY-MM-DD')
       and deal_date <= TO_DATE('2012-09-07', 'YYYY-MM-DD');


脚本4-30  比较相同语句，普通表无法用到DEAL_DATE条件进行分区消除的情况
select *
      from norm_tab
     where deal_date >= TO_DATE('2012-09-04', 'YYYY-MM-DD')
       and deal_date <= TO_DATE('2012-09-07', 'YYYY-MM-DD');


脚本4-31  观察LIST分区表的分区条件的分区消除
set autotrace traceonly
set linesize 1000
select *
      from range_list_part_tab
     where deal_date >= TO_DATE('2012-09-04', 'YYYY-MM-DD')
       and deal_date <= TO_DATE('2012-09-07', 'YYYY-MM-DD')
       and area_code=591;


脚本4-32  比较相同语句，普通表无法用area_code条件进行分区消除的情况
select *
      from norm_tab
     where deal_date >= TO_DATE('2012-09-04', 'YYYY-MM-DD')
       and deal_date <= TO_DATE('2012-09-07', 'YYYY-MM-DD')
       and area_code=591;


脚本4-33  分区清除的方便例子
delete from norm_tab where deal_date>=TO_DATE('2012-09-01', 'YYYY-MM-DD')  and deal_date <= TO_DATE('2012-09-30', 'YYYY-MM-DD');
--为了后续章节试验的方便，本处暂且将删除的记录回退。
rollback;
alter table range_part_tab truncate partition p9;
select count(*) from range_part_tab where deal_date>=TO_DATE('2012-09-01', 'YYYY-MM-DD')  and deal_date <= TO_DATE('2012-09-30', 'YYYY-MM-DD');


脚本4-34  分区交换的神奇例子
drop table mid_table purge;
create table mid_table (id number deal_date date,area_code number,contents varchar2(4000));
select count(*) from mid_table ;
select count(*) from range_part_tab partition(p8);
---当然，除了上述用partition(p8)的指定分区名查询外，也可以采用分区条件代入查询：
select count(*) from range_part_tab where deal_date>=TO_DATE('2012-08-01', 'YYYY-MM-DD')  and deal_date <= TO_DATE('2012-08-31', 'YYYY-MM-DD');
--以下命令就是经典的分区交换：
alter table range_part_tab exchange partition p8 with table mid_table;
--查询发现分区8数据不见了。
select count(*) from range_part_tab partition(p8);
---而普通表记录由刚才的0条变为8628条了，果然实现了交换。
select count(*) from mid_table ;


脚本4-35  分区交换（从普通表交换到分区表）
alter table range_part_tab exchange partition p8 with table mid_table;
select count(*) from range_part_tab partition(p8);
select count(*) from mid_table ;

脚本4-36  分区切割
alter table range_part_tab split partition p_max  at (TO_DATE('2013-02-01', 'YYYY-MM-DD')) into (PARTITION p2013_01 ,PARTITION P_MAX);
alter table range_part_tab split partition p_max  at (TO_DATE('2013-03-01', 'YYYY-MM-DD')) into (PARTITION p2013_02 ,PARTITION P_MAX);

脚本4-37  观察分区切割情况
SQL> column segment_name format a20
SQL> column partition_name format a20
SQL> column segment_type format a20
SQL> select segment_name,
           partition_name,
           segment_type,
           bytes / 1024 / 1024 "字节数(M)",
           tablespace_name
      from user_segments
     where segment_name IN('RANGE_PART_TAB');


脚本4-38  分区合并例子
SQL> alter table range_part_tab  merge partitions p2013_02, P_MAX INTO PARTITION P_MAX;
表已更改。
SQL> alter table range_part_tab  merge partitions p2013_01, P_MAX INTO PARTITION P_MAX;
表已更改。


脚本4-39  观察分区合并情况
SQL> column segment_name format a20
SQL> column partition_name format a20
SQL> column segment_type format a20
SQL> select segment_name,
           partition_name,
           segment_type,
           bytes / 1024 / 1024 "字节数(M)",
           tablespace_name
      from user_segments
     where segment_name IN('RANGE_PART_TAB');


脚本4-40  最后一个分区是maxvalue，不允许追加，只允许split
alter table range_part_tab add partition  p2013_01 values less than (TO_DATE('2013-02-01', 'YYYY-MM-DD'));
alter table range_part_tab add partition  p2013_01 values less than (TO_DATE('2013-02-01', 'YYYY-MM-DD'))




脚本4-41  可以删除maxvalue，进行分区追加
alter table range_part_tab drop partition  p_max;
alter table range_part_tab add partition  p2013_01 values less than (TO_DATE('2013-02-01', 'YYYY-MM-DD'));
alter table range_part_tab add partition  p2013_02 values less than (TO_DATE('2013-03-01', 'YYYY-MM-DD'));


脚本4-42  全局索引与局部索引
-----以下是对deal_date列建全局索引
create  index idx_part_tab_date on range_part_tab(deal_date) ;
-----以下是对area_code列建一个局部索引
create  index idx_part_tab_area on range_part_tab(area_code) local;



脚本4-43  全局索引段分配情况
column partition_name format a20
column segment_type format a20
select segment_name,
           partition_name,
           segment_type,
           bytes / 1024 / 1024 "字节数(M)",
           tablespace_name
      from user_segments
     where segment_name IN('IDX_PART_TAB_DATE');


脚本4-44  局部索引段分配情况
SET LINESIZE 666
set pagesize 5000
column segment_name format a20
column partition_name format a20
column segment_type format a20
select segment_name,
           partition_name,
           segment_type,
           bytes / 1024 / 1024 "字节数(M)",
           tablespace_name
      from user_segments
     where segment_name IN('IDX_PART_TAB_AREA');



脚本4-45  观察全局和局部索引的状态
select index_name, status
      from user_indexes
     where index_name in('IDX_PART_TAB_DATE', 'IDX_PART_TAB_AREA');

select index_name, partition_name, status
     from user_ind_partitions
    where index_name = 'IDX_PART_TAB_AREA';


脚本4-46  做分区truncate后全局索引失效，局部索引未失效
select count(*) from range_part_tab partition(p1);
alter table range_part_tab truncate partition p1;
select count(*) from range_part_tab partition(p2);

select index_name, status
      from user_indexes
     where index_name in('IDX_PART_TAB_DATE', 'IDX_PART_TAB_AREA');

select index_name, partition_name, status
      from user_ind_partitions
     where index_name = 'IDX_PART_TAB_AREA';



脚本4-47  对失效的全局索引进行重建
alter index IDX_PART_TAB_DATE rebuild;
select index_name, status from user_indexes where index_name ='IDX_PART_TAB_DATE';



脚本4-48  update global indexes关键字可避免全局索引失效
select count(*) from range_part_tab partition(p2);
alter table range_part_tab truncate partition p2 update global indexes;
select count(*) from range_part_tab partition(p2);
select index_name, status from user_indexes where index_name ='IDX_PART_TAB_DATE';


脚本4-49  应用分区表的局部索引产生的逻辑读很大
create  index idx_range_list_tab_date on range_list_part_tab(id) local;
set autotrace traceonly
set linesize 1000
select * from range_list_part_tab where id=100000;



脚本4-50  应用普通表的普通索引产生的逻辑读很小
create  index idx_norm_tab_date on norm_tab(id);
set autotrace traceonly
set linesize 1000
select * from norm_tab where id=100000;


脚本4-51  分区表设计要考虑语句中有效的用到分区条件，有无差别巨大
select *
      from range_list_part_tab
     where id=100000
     and deal_date >= sysdate-1
     and area_code=591;



脚本4-52  分别建索引组织表和普通表进行试验
drop table heap_addresses purge;
drop table iot_addresses purge;
create table heap_addresses
   (empno    number(10),
    addr_type varchar2(10),
    street    varchar2(10),
    city      varchar2(10),
    state     varchar2(2),
    zip       number,
    primary key (empno)
   )
/

create table iot_addresses
   (empno    number(10),
    addr_type varchar2(10),
    street    varchar2(10),
    city      varchar2(10),
    state     varchar2(2),
    zip       number,
   primary key (empno)
   )
   organization index
/
insert into heap_addresses
   select object_id,'WORK','123street','washington','DC',20123
   from all_objects;
insert into iot_addresses
    select object_id,'WORK','123street','washington','DC',20123
    from all_objects;
commit;





脚本4-53  分别比较索引组织表和普通表的查询性能
set linesize 1000
set autotrace traceonly
select * from heap_addresses where empno=22;
select * from iot address where empno=22;




脚本4-54  簇表设计好，可避免排序
Drop table cust_orders;
Drop cluster shc;


CREATE CLUSTER shc
    (
       cust_id     NUMBER,
       order_dt    timestamp SORT
    )
    HASHKEYS 10000
    HASH IS cust_id
    SIZE  8192
/

CREATE TABLE cust_orders
   (  	cust_id       	number,
      	order_dt      	timestamp SORT,
      	order_number 	number,
      	username    	varchar2(30),
      	ship_addr     	number,
      	bill_addr     	number,
      	invoice_num  	number
   )
   CLUSTER shc ( cust_id, order_dt )
/


---开始执行分析
set autotrace traceonly explain
variable x number
select cust_id, order_dt, order_number
     from cust_orders
     where cust_id = :x
     order by order_dt;


