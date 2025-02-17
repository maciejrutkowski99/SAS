proc import datafile='adsl.csv' out=ADSL dbms=csv replace;
guessingrows=max;
run;   /* Import ADSL */

data ADSL_poprawione;
set ADSL;
where SAFFL= 'Y';
run;  /* Modify ADSL */

proc import datafile='adae.csv' out=ADAE dbms=csv replace;
guessingrows=max; /* Import ADAE */
run;

data ADAE_poprawione;
set ADAE;
where SAFFL = 'Y';
run; /* Modify ADAE */


proc sql;
select count(distinct USUBJID) from ADAE_poprawione;
quit; /* Check the number of patiens - for my own information */


proc freq data=ADSL_poprawione;
	tables ARM / out=freq nocum nopercent; 
run;


data ARMS;
	set freq;
	kolumna=catx(' ', arm, 'N=', put(count, 8.), '(', put(percent, 5.1), '%)');
run;

/* Second row of the table: ANY_AE */
proc sql;
create table ANY_AE_n as
	select ARM, count(distinct USUBJID) as n from ADAE_poprawione group by ARM;
quit;

proc sql;
create table ANY_AE_iteration_1 as
select FREQ.ARM, FREQ.COUNT as N, ANY_AE_n.n as ni, (ANY_AE_N.n/FREQ.COUNT * 100) as percent, 'Any AE' as nazwa_wiersza from  ANY_AE_N join FREQ on ANY_AE_N.ARM=FREQ.ARM;
quit;

data ANY_AE_iteration_2;
	set ANY_AE_iteration_1;
	combined=catx(' ', ni, '(', put(percent, 5.1), '%)');
	keep ARM combined nazwa_wiersza;
run;

proc transpose data=ANY_AE_iteration_2 out=ANY_AE_iteration_3;
var combined;
by nazwa_wiersza;
run;

data ANY_AE_final;
	set ANY_AE_iteration_3;
	keep nazwa_wiersza COL1 COL2 COL3;
run;


/* Third row of the table: Internal Organ Class 1 */
proc sql;
create table Internal1_n as
	select ARM, count(distinct USUBJID) as n from ADAE_poprawione where AETERM='DIARRHOEA' group by ARM;
quit;

proc sql;
create table Internal1_iteration_1 as
	select FREQ.ARM, FREQ.COUNT as N, Internal1_n.n as ni, (Internal1_n.n/FREQ.COUNT * 100) as percent, 'GASTROINTESTINAL DISORDERS' as nazwa_wiersza from Internal1_n join FREQ on Internal1_n.ARM=FREQ.ARM;
quit;

data Internal1_iteration_2;
	set Internal1_iteration_1;
	combined=catx(' ', ni, '(', put(percent, 5.1), '%)');
	keep ARM combined nazwa_wiersza;
run;

proc transpose data=Internal1_iteration_2 out=Internal1_iteration_3;
var combined;
by nazwa_wiersza;
run;

data Internal1_final;
	set Internal1_iteration_3;
	drop _NAME_;
run;

/* Fourth row of the table: Diarrhoea */
proc sql;
create table Diarrhoea_n as
	select ARM, count(distinct USUBJID) as n from ADAE_poprawione where AETERM='DIARRHOEA' group by ARM;
quit;

proc sql;
create table Diarrhoea_iteration_1 as
	select FREQ.ARM, FREQ.COUNT as N, Diarrhoea_n.n as ni, (Diarrhoea_n.n/FREQ.COUNT * 100) as percent, 'Diarrhoea' as nazwa_wiersza from Diarrhoea_n join FREQ on Diarrhoea_n.ARM=FREQ.ARM;
quit;

data Diarrhoea_iteration_2;
	set Diarrhoea_iteration_1;
	combined=catx(' ', ni, '(', put(percent, 5.1), '%)');
	keep ARM combined nazwa_wiersza;
run;

proc transpose data=Diarrhoea_iteration_2 out=Diarrhoea_iteration_3;
var combined;
by nazwa_wiersza;
run;

data Diarrhoea_final;
	set Diarrhoea_iteration_3;
	drop _NAME_;
run;


/* Fifth row of the table: GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS */
proc sql;
create table Internal2_n as
	select ARM, count(distinct USUBJID) as n from ADAE_poprawione where AETERM='FATIGUE' group by ARM;
quit;

proc sql;
create table Internal2_iteration_1 as
	select FREQ.ARM, FREQ.COUNT as N, Internal2_n.n as ni, (Internal2_n.n/FREQ.COUNT * 100) as percent, 'GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS	' as nazwa_wiersza from Internal2_n join FREQ on Internal2_n.ARM=FREQ.ARM;
quit;

data Internal2_iteration_2;
	set Internal2_iteration_1;
	combined=catx(' ', ni, '(', put(percent, 5.1), '%)');
	keep ARM combined nazwa_wiersza;
run;

proc transpose data=Internal2_iteration_2 out=Internal2_iteration_3;
var combined;
by nazwa_wiersza;
run;

data Internal2_final;
	set Internal2_iteration_3;
	drop _NAME_;
run;


/* Sixth row of the table - FATIGUE */

proc sql;
create table Fatigue_n as
	select ARM, count(distinct USUBJID) as n from ADAE_poprawione where AETERM='FATIGUE' group by ARM;
quit;

proc sql;
create table Fatigue_iteration_1 as
	select FREQ.ARM, FREQ.COUNT as N, Fatigue_n.n as ni, (Fatigue_n.n/FREQ.COUNT * 100) as percent, 'Fatigue' as nazwa_wiersza from Fatigue_n join FREQ on Fatigue_n.ARM=FREQ.ARM;
quit;

data Fatigue_iteration_2;
	set Fatigue_iteration_1;
	combined=catx(' ', ni, '(', put(percent, 5.1), '%)');
	keep ARM combined nazwa_wiersza;
run;

proc transpose data=Fatigue_iteration_2 out=Fatigue_iteration_3;
var combined;
by nazwa_wiersza;
run;

data Fatigue_final;
	set Fatigue_iteration_3;
	drop _NAME_;
run;


/* Table Creation */
proc sql;
create table GRAND_FINALE as
(
select * from ANY_AE_final
union ALL
select * from Internal1_final
union ALL
select * from Diarrhoea_final
union ALL 
select * from Internal2_final
union ALL
select * from Fatigue_final);
quit;

ODS PDF file='/home/u63977047/EPG1V2/data/raport.pdf';
options nodate nonumber;

proc report data=GRAND_FINALE;
	title 'Selected Adverse Events by SOC and PT - summary (Safety Analysis Set)';
	column nazwa_wiersza COL2 COL3 COL1;
	define nazwa_wiersza / display ' ';
	define COL1 / display 'Placebo N=86';
	define COL2 / display 'Xanomeline High Dose N=84';
	define COL3 / display 'Xanomeline High Dose N=84';
quit;

ODS PDF text="Percentages are based on number of subjects in treatment arm.";
ODS PDF text="N - number of subjects in treatment arm, n - number of subjects in the anaysis, SOC - System Organ Class, PT - Prefered Term";

ODS PDF CLOSE;
