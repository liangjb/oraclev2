脚本2-1  SQL语句首次查询的情况
drop table t ;
create table t as select * from all_objects;
create index idx_object_id on t(object_id);
set autotrace on
set linesize 1000
set timing on
select object_name from t where object_id=29;

脚本2-2  同一SQL再次查询后性能提升
select object_name from t where object_id=29;

脚本2-3  故意强制走全表扫描的情况
set autotrace on 
set linesize 1000
set timing on 
select /*+full(t)*/ object_name from t where object_id=29;
---以下是故意再执行一遍
select /*+full(t)*/ object_name from t where object_id=29;


脚本2-4  查看SGA及PGA的分配大小
sqlplus "/ as sysdba"
--10g
show parameter sga
--11g
show parameter memory


脚本2-5  查看共享池和数据缓冲池的分配大小
show parameter shared_pool_size
show parameter db_cache_size  


脚本2-6  从操作系统层面来感受SAG分配情况
ipcs -m

脚本2-7  查看日志缓冲区的分配大小
show parameter log_buffer

脚本2-8  修改SGA大小(scope=spfile方式)
show parameter sga
alter system set sga_target=2000M scope=spfile;

脚本2-9  修改SGA大小(scope=both方式)
show parameter sga
alter system set sga_target=2000M scope=both;
show parameter sga

脚本2-10  修改LOG_BUFFER参数
show parameter log_buffer;
alter system set log_buffer=15000000  scope=memory ; 
alter system set log_buffer=15000000  scope=both;
alter system set  log_buffer=15000000  scope=spfile;
show parameter log_buffer;

脚本2-11  查看Oracle实例名
show parameter instance_name


脚本2-12  查看Oracle归档进程
ps -ef |grep arc

脚本2-13  查看Oracle归档是否开启
sqlplus "/ as sysdba"
archive log list;

脚本2-14  将Oracle归档开启方法
shutdown immediate
startup mount;
alter database archivelog;
alter database open;


脚本2-15  查看开启是否成功
archive log list;


脚本2-16  查看Oracle归档进程
ps -ef |grep arc

脚本2-17  查看Oracle的spfile参数情况
show parameter spfile

脚本2-18  Oracle启动三步骤
startup nomount
alter database mount;
alter database open;

脚本2-19  Oracle关闭
shutdown immediate

脚本2-20  观察Oracle关闭后的共享内存情况
ipcs -m

脚本2-21  观察Oracle进程情况
ps -ef |grep itsmtest

脚本2-22  启动Oracle到nomount状态
sqlplus "/ as sysdba"
startup nomount


脚本2-23  观察Oracle启动后内存分配和进程情况
ipcs -m
ps -ef |grep itmtest
 
 
脚本2-24  查看参数、控制、数据、日志、归档、告警文件
show parameter spfile;
show parameter control
sqlplus "/ as sysdba"
select file_name from dba_data_files;
select group#,member from v$logfile ; 
show parameter recovery
set linesize 1000
show parameter dump
--以下路径请读者根据实际情况自行调整
cd /home/oracle/admin/itmtest/bdump
ls -lart alert*


脚本2-25  查看监听状态
lsnrctl status


脚本2-26  关闭Oracle监听
lsnrctl stop
 
 
脚本2-27  查看关闭Oracle监听后的情况 
lsnrctl status


脚本2-28  开启Oracle监听
lsnrctl start


脚本2-29  单车到飞船试验前的准备工作
sqlplus ljb/ljb
drop table t purge;
create table t ( x int );
--将共享池清空
alter system flush shared_pool;


脚本2-30  单车到飞船试验前构造proc1
create or replace procedure proc1
as
begin
    for i in 1 .. 100000
    loop
        execute immediate
        'insert into t values ( '||i||')';
    commit;
    end loop;
end;
/ 


脚本2-31  首次试验42秒完成，仅是单车速度
connect ljb/ljb
drop table t purge;
create table t ( x int );
alter system flush shared_pool;
set timing on
exec proc1 ;
select count(*) from t;


脚本2-32  原来是因为未用绑定变量
select t.sql_text, t.sql_id,t.PARSE_CALLS, t.EXECUTIONS
  from v$sql t
 where sql_text like '%insert into t values%';


脚本2-33 第2次改进，将proc1改造成有绑定变量的proc2
create or replace procedure proc2
as
begin
    for i in 1 .. 100000
    loop
        execute immediate
        'insert into t values ( :x )' using i;   
        commit;
    end loop;
end;
/


脚本2-34  第2次改进后8秒完成，单车变摩托
drop table t purge;
create table t ( x int );
alter system flush shared_pool;
set timing on
exec proc2;
select count(*) from t;


脚本2-35  第3次改进，将proc2改造成静态SQL的proc3
create or replace procedure proc3
as
begin
    for i in 1 .. 100000
    loop
     insert into t values (i);   
     commit;
    end loop;
end;
/


脚本2-36  第3次改进后6秒完成，摩托变汽车
drop table t purge;
create table t ( x int );
alter system flush shared_pool;
set timing on
exec proc3;
select count(*) from t;
 
脚本2-37 第4次改进，将proc3改造成提交在循环外的proc4
create or replace procedure proc4
as
begin
    for i in 1 .. 100000
    loop
     insert into t values (i);   
    end loop;
  commit;
end;
/


脚本2-38  第4次改进后2秒完成，汽车变动车
drop table t purge;
create table t ( x int );
alter system flush shared_pool;
set timing on
exec proc4;
select count(*) from t;


脚本2-39  第5次用集合写法后0.25秒完成，动车变飞机
drop table t purge;
create table t ( x int );
alter system flush shared_pool;
set timing on
insert into t select rownum from dual connect by level<=100000;
commit;
select count(*) from t;
 

脚本2-40  试验准备，将集合写法的试验数据量放大100倍
connect ljb/ljb
drop table t purge;
create table t ( x int );
alter system flush shared_pool;
set timing on
insert into t select rownum from dual connect by level<=10000000;
commit;


脚本2-41  第6次改进，直接路径让飞机变火箭
drop table t purge;
alter system flush shared_pool;
set timing on
create table t as select rownum x from dual connect by level<=10000000;


脚本2-42  第7次改进，并行原理让火箭变飞船
drop table t purge;
alter system flush shared_pool;
set timing on 
create table t nologging parallel 64 
as select rownum x from dual connect by level<=10000000;
