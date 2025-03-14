/* Library creation */
libname trial "/home/u63977047/ADSL-ADAE";

/* Import and modify ADSL to only include observations with the Safety Analysis Flag */
proc import datafile="/home/u63977047/EPG1V2/data/adsl.csv"
			out=trial.ADSL
			dbms=csv
			replace;
			guessingrows=max;
run;

data trial.ADSL_SAFFL;
	 set trial.ADSL;
	 where SAFFL = 'Y';
run;

/* Import and modify ADAE to only include observations with the Safety Analysis Flag, use proc sort to remove duplicate observations of patient+AE, i.e. one patient with two
instances of diarrhea should only have one observation for diarrhea after proc sort */
proc import datafile="/home/u63977047/EPG1V2/data/adae.csv"
			out=trial.ADAE
			dbms=csv
			replace;
			guessingrows=max;
run;

data trial.ADAE_SAFFL (drop=AETERM rename=(temp_aeterm=AETERM)); /* Need to increase AETERM length as we will be adding longer AESOC strings to that column later */
	 length temp_aeterm $70;
	 set trial.ADAE;
	 temp_aeterm = AETERM;
	 where SAFFL = 'Y';
run;

proc sort data=trial.ADAE_SAFFL nodupkey;
	by USUBJID AETERM;
run;

/* This is the playground where we can explore the data */
proc means data=trial.ADAE_SAFFL;
var AESEQ;
run;

proc freq data=trial.ADAE_SAFFL order=freq;
table AETERM / nocol norow nocum nopercent;
run;

/* End of the playground */

/* Combine ADAE and ADSL to get a simplified dataset with only the needed variables*/
data trial.combined;
	merge trial.ADAE_SAFFL(in=in_ADAE keep=USUBJID AETERM AESOC) trial.ADSL_SAFFL(in=in_ADSL keep=USUBJID ARM) ;
	by USUBJID;
	if in_ADAE=1 and in_ADSL=1;
run;

/* Get a table of frequencies - perhaps this step would be clearer with just AETERM*ARM and adding the dropped AESOC column after transposing but this is more concise */
proc freq data=trial.combined noprint;
	tables AETERM*AESOC*ARM / nocum norow nocol nopercent out=trial.AE_freq (drop=percent replace=yes);
run;

/* Transpose the table to make it look more like the desired report and change missing values to zeros and change Adverse Event names to propcase - rows with AE will be propcase and rows with
AESOC will be upcase, which will let us distinguish them easily */ 
proc transpose 	data=trial.AE_freq out=trial.AE_transposed (replace=yes);
	by AETERM AESOC;
	id ARM;
	var COUNT;
run;
	
data trial.AE_transposed_with_zeros replace;
	drop _Name_ _Label_;
	set trial.AE_transposed;
	if 'Xanomeline High Dose'n = . then 'Xanomeline High Dose'n = 0;
	if 'Xanomeline Low Dose'n = . then 'Xanomeline Low Dose'n = 0;
	if Placebo = . then Placebo = 0;
	AETERM = Propcase(AETERM);
run;

/* Here we choose which Adverse Events we want in the report */
%LET aelist = "Diarrhoea", "Hiatus Hernia", "Fatigue", "Eye Allergy", "Eye Pruritus";

/* Limit the observations only to the chosen ones */
data trial.limited_AE;
	set trial.AE_transposed_with_zeros;
	where AETERM in (&aelist);
run;

/* We have rows for Adverse Events in the desired form, what's left to do is add the AESOC rows, 'Any AE' row and
make cosmetic changes, like adding % and labels to the report */

/* Create the AESOC rows, analogous to the creation of AETERM rows */
proc sort data=trial.combined out=trial.AESOC nodupkey;
	by USUBJID AESOC;
	where propcase(AETERM) in (&aelist);
run;

/* Here we can't use AETERM*AESOC*ARM, since for every AESOC there are multiple AETERMS,
which would corrupt the results */
proc freq data=trial.AESOC noprint;
	tables AESOC*ARM / nocum norow nocol nopercent out=trial.AESOC_freq (drop=percent replace=yes);
run; 

proc transpose 	data=trial.AESOC_freq out=trial.AESOC_transposed (replace=yes);
	by AESOC;
	id ARM;
	var COUNT;
run;

/* the is_AESOC flag will be used later to to achieve the desired order of rows	*/
data trial.AESOC_transposed_with_zeros replace;
	drop _Name_ _Label_;
	set trial.AESOC_transposed;
	if 'Xanomeline High Dose'n = . then 'Xanomeline High Dose'n = 0;
	if 'Xanomeline Low Dose'n = . then 'Xanomeline Low Dose'n = 0;
	if Placebo = . then Placebo = 0;
	AETERM = AESOC;
	is_AESOC = 1;
run;

/* Combine AE and AESOC rows */

data trial.AE_with_AESOC replace;
	set trial.limited_AE trial.AESOC_transposed_with_zeros;
run;

/* We will sort these and use a subsetting if statement to only leave AESOC rows we need */
proc sort data=trial.AE_with_AESOC out=trial.AE_with_AESOC_ordered;
	by AESOC DESCENDING is_AESOC;
run;

data trial.limited_AE_with_AESOC replace;
	set trial.AE_with_AESOC_ordered;
	by AESOC;
	if first.AESOC = 0 or last.AESOC = 0; /* don't output the AESOC rows that appear only once in the dataset (meaning they have no corresponding AE rows and shouldn't be in the report) */
run;


/* Create 'Any AE' row - first we need to remove duplicate observations of USUBJID  */
proc sort data=trial.combined out=trial.any_ae_creation nodupkey;
	by USUBJID;
run;

proc freq data=trial.any_ae_creation;
	tables ARM / nocum nopercent out=trial.any_ae_freq (drop=percent replace=yes);
run;

proc transpose data=trial.any_ae_freq out=trial.any_ae(drop=_NAME_ _LABEL_);
id ARM;
run;

/* Append the 'Any AE' row to our table */
data trial.with_any_ae;
	retain AETERM;
	set trial.any_ae trial.limited_ae_with_aesoc;
	drop AESOC is_AESOC ;
	if _N_ = 1 then AETERM = "Any AE";
run;

/* Top row arm numbers creation */
proc freq data=trial.ADSL_SAFFL;
	tables ARM / nocum nopercent out=trial.top_row (drop=percent replace=yes); 
run;

proc transpose data=trial.top_row out=trial.top_row_transposed;
	id ARM;
run;

/* Store the top row arm numbers in macro variables - we'll use these to add the numbers to the top row with ARMs and to count percentages in the report*/
data _null_;
    set trial.top_row_transposed;
    call symputx('placebo_number', Placebo); /* Store in macro variable */
    call symputx('high_dose_number', 'Xanomeline High Dose'n); /* Store in macro variable */
    call symputx('low_dose_number', 'Xanomeline Low Dose'n); /* Store in macro variable */
run;


/* We have all we need to create the report now, since the variables are numeric, we'll create new character versions of these */

data trial.report;
	retain AETERM XHD_char XLD_char Placebo_char;
	drop 'Xanomeline High Dose'n 'Xanomeline Low Dose'n Placebo;
	set trial.with_any_ae;
	
	label AETERM = "Adverse Event";
	label XHD_char = "Xanomeline High Dose N=&high_dose_number n (%)";
	label XLD_char = "Xanomeline Low Dose N=&low_dose_number n (%)";
	label Placebo_char = "Placebo N=&placebo_number n (%)";
	
	XHD_char = catx("", 'Xanomeline High Dose'n, " (", put('Xanomeline High Dose'n / input("&high_dose_number", 8.) * 100, 8.1), "%)");
	XLD_char = catx("", 'Xanomeline Low Dose'n, " (", put('Xanomeline Low Dose'n / input("&low_dose_number", 8.) * 100, 8.1), "%)");
	Placebo_char = catx("", Placebo, " (", put(Placebo / input("&placebo_number", 8.) * 100, 8.1), "%)");
run;



ods pdf file="/home/u63977047/ADSL-ADAE/Report.pdf" ;
options nodate nonumber;

title "Selected Adverse Events by SOC and PT - summary (Safety Analysis Set)";

proc print data=trial.report noobs label;
run;

ods pdf text = "Percentages are based on number of subjects in treatment arm.";
ods pdf text = "N - number of subjects in treatment arm, n - number of subjects in the analysis, SOC - System Organ Class, PT - Prefered Term.";

ods pdf close;




