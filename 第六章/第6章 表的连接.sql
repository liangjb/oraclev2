脚本6-1  研究Nested Loops Join访问次数前准备
DROP TABLE t1 CASCADE CONSTRAINTS PURGE; 
DROP TABLE t2 CASCADE CONSTRAINTS PURGE; 
CREATE TABLE t1 (
     id NUMBER NOT NULL,
     n NUMBER,
     contents VARCHAR2(4000)
   )
   ; 
CREATE TABLE t2 (
     id NUMBER NOT NULL,
     t1_id NUMBER NOT NULL,
     n NUMBER,
     contents VARCHAR2(4000)
   )
   ; 
execute dbms_random.seed(0); 
INSERT INTO t1
     SELECT  rownum,  rownum, dbms_random.string('a', 50)
       FROM dual
     CONNECT BY level <= 100
      ORDER BY dbms_random.random; 
INSERT INTO t2 SELECT rownum, rownum, rownum, dbms_random.string('b', 50) FROM dual CONNECT BY level <= 100000
    ORDER BY dbms_random.random; 
COMMIT; 
select count(*) from t1;
select count(*) from t2;




脚本6-2  研究Nested Loops Join，T2表被访问100次
SELECT /*+ leading(t1) use_nl(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id;

接下来，我们用设置statistics_level=all的方式来观察如下表连接语句的执行计划：

Set linesize 1000
alter session set statistics_level=all ;
SELECT /*+ leading(t1) use_nl(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id;
--略去记录结果
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-3  换个语句，这次T2表被访问2次
Set linesize 1000
alter session set statistics_level=all ;
SELECT /*+ leading(t1) use_nl(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n in(17, 19);
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-4  继续换个语句，这次T2表被访问1次
Set linesize 1000
alter session set statistics_level=all ;
SELECT /*+ leading(t1) use_nl(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
SQL> select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-5  改写到最后，T2表居然被访问0次
SELECT /*+ leading(t1) use_nl(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 999999999;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));


脚本6-6  分析T2表被访问次数不同的原因
---解释T2表为啥被访问100次
select count(*) from t1;
---解释T2表为啥被访问2次
select count(*) from t1 where t1.n in (17,19);
---解释T2表为啥被访问1次
select count(*) from t1 where t1.n = 19;
---解释T2表为啥被访问0次
select count(*) from t1 where t1.n = 999999999;




脚本6-7  Hash Join中 T2表只会被访问1次或0次
SELECT /*+ leading(t1) use_hash(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));


脚本6-8  Hash Join中T2表被访问0次的情况
SELECT /*+ leading(t1) use_hash(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=999999999;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));


脚本6-9  Hash Join中T1和T2表都访问0次的情况
SELECT /*+ leading(t1) use_hash(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and 1=2;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));


脚本6-10  Merge Sort Join访问情况和Hash Join一样
SELECT /*+ ordered use_merge(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));


脚本6-11  嵌套循环连接的t1表先访问的情况
alter session set statistics_level=all;
SELECT /*+ leading(t1) use_nl(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-12  Nested Loops Join的t2表先访问的情况
alter session set statistics_level=all;
SELECT /*+ leading(t2) use_nl(t1)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-13  HASH连接的t1表先访问的情况
alter session set statistics_level=all;
SELECT /*+ leading(t1) use_hash(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-14  Hash Join的t2表先访问情况
SELECT /*+ leading(t2) use_hash(t1)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-15  Merge Sort Join的t1表先访问情况
alter session set statistics_level=all;
SELECT /*+ leading(t1) use_merge(t2)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-16  Merge Sort Join的t2表先访问情况
SELECT /*+ leading(t2) use_merge(t1)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=19;

select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-17  Merge Sort Join取所有字段的情况
alter session set statistics_level=all ;
SELECT /*+ leading(t2) use_merge(t1)*/ *
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-18  Merge Sort Join取部分字段的情况
SELECT /*+ leading(t2) use_merge(t1)*/ t1.id
FROM t1, t2
WHERE t1.id = t2.t1_id
and t1.n=19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));




脚本6-19  Hash Join不支持不等值连接条件
explain plan for
    SELECT /*+ leading(t1) use_hash(t2)*/ *
    FROM t1, t2
    WHERE t1.id <> t2.t1_id
    AND t1.n = 19;

SELECT * FROM table(dbms_xplan.display);



脚本6-20  Hash Join不支持大于或者小于的连接条件
explain plan for
    SELECT /*+ leading(t1) use_hash(t2)*/ *
    FROM t1, t2
    WHERE t1.id > t2.t1_id
    AND t1.n = 19;

SELECT * FROM table(dbms_xplan.display);



脚本6-21  Hash Join不支持LIKE的连接条件
explain plan for
    SELECT /*+ leading(t1) use_hash(t2)*/ *
    FROM t1, t2
    WHERE t1.id like t2.t1_id
    AND t1.n = 19;

SELECT * FROM table(dbms_xplan.display);



脚本6-22  Merge Sort Join不支持不等于的连接条件
explain plan for
    SELECT /*+ leading(t1) use_merge(t2)*/ *
    FROM t1, t2
    WHERE t1.id<> t2.t1_id
    AND t1.n = 19;

SELECT * FROM table(dbms_xplan.display);



脚本6-23  Merge Sort Join支持大于或者小于的连接条件
explain plan for
    SELECT /*+ leading(t1) use_merge(t2)*/ *
    FROM t1, t2
    WHERE t1.id>t2.t1_id
    AND t1.n = 19;

SELECT * FROM table(dbms_xplan.display);




脚本6-24  Merge Sort Join不支持LIKE的连接条件
explain plan for
    SELECT /*+ leading(t1) use_merge(t2)*/ *
    FROM t1, t2
    WHERE t1.id like t2.t1_id
    AND t1.n = 19;
SELECT * FROM table(dbms_xplan.display);




脚本6-25  Nested Loops Join两表无索引试验
alter session set statistics_level=all ;
SELECT /*+ leading(t1) use_nl(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-26  两表无索引场合如果不用HINT，一般走Hash Join
alter session set statistics_level=all ;
SELECT *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));




脚本6-27  动手优化，对t1表的限制条件建索引
CREATE INDEX t1_n ON t1 (n);



脚本6-28  有了限制条件的索引，Nested Loops Join性能略有提升
alter session set statistics_level=all ;
SELECT /*+ leading(t1) use_nl(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-29  再次动手优化，这次对t1表的连接条件建索引
CREATE INDEX t2_t1_id ON t2(t1_id);



脚本6-30  连接条件的索引导致表连接性能有了大幅度提升
alter session set statistics_level=all ;
SELECT /*+ leading(t1) use_nl(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-31  增加了索引后Oracle不用HINT，依然选择Nested Loops Join
alter session set statistics_level=all ;
SELECT *
FROM t1, t2
WHERE t1.id = t2.t1_id
AND t1.n = 19;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-32  连接条件未建索引，Merge Sort Join的排序不可避免
alter session set statistics_level=all ;
SELECT /*+ ordered use_merge(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));



脚本6-33  连接条件建索引后，Merge Sort Join的排序减少一次
--然后建索引
create index idx_t1_id on t1(id);
--有索引情况下继续观察
SELECT /*+ ordered use_merge(t2) */ *
FROM t1, t2
WHERE t1.id = t2.t1_id;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
