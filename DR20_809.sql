----------------------DR20-809--------------------------------
--An “Other primaries” flag:
--Ans: 28
--Multiple curated NSCLC dx (note, we don’t want to include patients here with just an early dx and an adv/met dx – we’re looking for patients with either multiple curated early NSCLC dx OR multiple curated adv/met dx):
--Ans: 30
--Multiple curated histologies -30 days or anytime after initial NSCLC dx:
--Ans: 114

set search_path = 'c3_pt360_202106_nsclc';

---Table 1-----------------
drop table if exists #nsclc_pts
select distinct chai_patient_id
into #nsclc_pts from condition
where diagnosis_code_code = '254637007'
and curation_indicator = 1
;

---Table 2----------------
--Table containing patients with multiple assessment_value_name for a specific date
drop table if exists #dup_pts
select A.chai_patient_id, assessment_date, count(*)
into #dup_pts from disease_status A
inner join #nsclc_pts B
on A.chai_patient_id = B.chai_patient_id
group by A.chai_patient_id, assessment_date
having count(distinct assessment_value_name) > 1
;

---Table 3
--Table containing distinct NSCLC diagnosis patients with a tumor progression (419835002) record and one other response on the same date
drop table if exists #dup_tum_prog ;
select distinct A.chai_patient_id
into #dup_tum_prog
from disease_status A
inner join #dup_pts B
on A.chai_patient_id = B.chai_patient_id and A.assessment_date = B.assessment_date
where assessment_value_code = '419835002'
;

--count of NSCLC diagnosis patients with a tumor progression record and one other response on the same date
select count(distinct chai_patient_id) from #dup_tum_prog ;
--1051

drop table if exists #dup_prim ;
select A.chai_patient_id
into #dup_prim
from condition A
inner join #dup_tum_prog B
on A.chai_patient_id = B.chai_patient_id
where diagnosis_type_name  = 'Primary malignant neoplasm of independent multiple sites'
;

--Number of patients with an “Other primaries” flag
select count(distinct chai_patient_id)
from #dup_prim ;
--28

select * from #dup_prim ;
select * from condition where chai_patient_id in (select chai_patient_id from #dup_prim)
and diagnosis_type_name  = 'Primary malignant neoplasm of independent multiple sites'
order by chai_patient_id desc ;

select * from disease_status where chai_patient_id in (select chai_patient_id from #dup_prim) ;



--2
--Patients with multiple curated early stage NSCLC dx
--30
set search_path = 'c3_pt360_202106_nsclc';

drop table if exists #multiple_early_stg_pts ;
select distinct a.chai_patient_id
into #multiple_early_stg_pts
from
(select * from staging where curation_indicator = 1) a
join
(select * from staging where curation_indicator = 1) b
on a.chai_patient_id = b.chai_patient_id
where upper(a.stage_group_name) like '%STAGE 1%'
and upper(b.stage_group_name) like '%STAGE 2%' ;

drop table if exists #multiple_early_response_pts ;
select distinct a.chai_patient_id
into #multiple_early_response_pts
from #dup_tum_prog a
inner join #multiple_early_stg_pts b
on a.chai_patient_id = b.chai_patient_id ;

select count(distinct chai_patient_id)  from #multiple_early_response_pts ;
--4

select * from staging where chai_patient_id in (select chai_patient_id from #multiple_early_response_pts)
and curation_indicator = 1
order by chai_patient_id asc, stage_date asc, stage_group_name asc ;

---------------Patients with multiple curated adv/met stage NSCLC dx-------------------------------------------
drop table if exists #multiple_late_stg_pts ;
select distinct a.chai_patient_id
into #multiple_late_stg_pts
from
(select * from staging where curation_indicator = 1) a
join
(select * from staging where curation_indicator = 1) b
on a.chai_patient_id = b.chai_patient_id
where upper(a.stage_group_name) like '%STAGE 3%'
and upper(b.stage_group_name) like '%STAGE 4%' ;

drop table if exists #multiple_late_response_pts ;
select distinct a.chai_patient_id
into #multiple_late_response_pts
from #dup_tum_prog a
inner join #multiple_late_stg_pts b
on a.chai_patient_id = b.chai_patient_id ;

select count(distinct chai_patient_id)  from #multiple_late_response_pts ;
--26

select * from staging where chai_patient_id in (select chai_patient_id from #multiple_late_response_pts)
and curation_indicator = 1
order by chai_patient_id asc, stage_date asc, stage_group_name asc ;

select distinct chai_patient_id
into #all_multiple_stage_pts
from (
                  select distinct chai_patient_id
                  from #multiple_early_response_pts
                  union
                  select distinct chai_patient_id
                  from #multiple_late_response_pts
              );

select count(distinct chai_patient_id) from #all_multiple_stage_pts ;
--30

select * from staging where chai_patient_id = 'PT000040358' and curation_indicator = 1 ;



--3
--Multiple curated histologies -30 days or anytime after initial NSCLC dx
--114
set search_path = 'c3_pt360_202106_nsclc';

--Step 1
--First generate table with date of initial diagnosis for each patient
DROP TABLE IF EXISTS #initial_dx;
SELECT chai_patient_id, MIN(diagnosis_date) AS initial_dx_date
into #initial_dx
    FROM condition
    WHERE diagnosis_code_code = '254637007'
    AND diagnosis_date IS NOT NULL
    AND curation_indicator = 1
    GROUP BY chai_patient_id
;

--Step 2
--Then generate containing patients with curated histologies -30 days or anytime after initial NSCLC dx.
DROP TABLE IF EXISTS #histo_30days_pts ;
WITH histology_gap AS
    (SELECT dx.chai_patient_id, exam.tumor_histology_code AS histology,
        exam.curation_indicator,
        DATEDIFF(day, dx.initial_dx_date, exam.exam_date) as dx_gap
    FROM #initial_dx dx
    LEFT JOIN tumor_exam exam
    ON dx.chai_patient_id = exam.chai_patient_id)
SELECT *
into #histo_30days_pts
FROM histology_gap
WHERE dx_gap >= -30 and curation_indicator = 1 ;

select count(distinct chai_patient_id) from #histo_30days_pts ;

--Patients with MULTIPLE curated histologies -30 days or anytime after initial NSCLC dx
DROP TABLE IF EXISTS #multiple_histo_pts ;
select chai_patient_id, count(*)
into #multiple_histo_pts
from #histo_30days_pts
group by chai_patient_id
having count(distinct histology) > 1 ;

select count(distinct chai_patient_id) from #multiple_histo_pts ;

--Distinct count of patients with conflicting tumor response and multiple curated histologies -30 days or anytime after initial NSCLC dx
DROP TABLE IF EXISTS #multiple_histo_response_pts ;
select A.chai_patient_id
into #multiple_histo_response_pts
from #multiple_histo_pts A
inner join #dup_tum_prog B
on A.chai_patient_id = B.chai_patient_id ;

select count(distinct chai_patient_id) from #multiple_histo_response_pts ;

select * from tumor_exam where chai_patient_id in (select chai_patient_id from #multiple_histo_response_pts)
and curation_indicator = 1
order by chai_patient_id asc, exam_date asc;

--3b
-----all curated histologies for these 1051 patients -30 days or anytime after NSCLC dx-----------------------
select A.*
from #histo_30days_pts A
inner join #dup_tum_prog B
on A.chai_patient_id = B.chai_patient_id
order by A.chai_patient_id desc ;
