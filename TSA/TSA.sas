/* import phase */
%let path=~/ECRB94/data;
libname cr "&path";
libname TSA "/home/u63977047/TSA";

ods graphics on;

options validvarname=v7;

proc import datafile="&path/TSAClaims2002_2017.csv" dbms=csv out=TSA.unmodified;
	guessingrows=max;
run;

proc sort data=tsa.unmodified nodupkey out=tsa.nodups;
	by _all_;
run;
/* exploration phase - duplicates removed so calculations are faster */

proc print data=TSA.nodups(obs=30);
run;

proc means data=TSA.nodups;
run;

proc freq data=TSA.modified;
	table Disposition;
run;

proc univariate data=TSA.nodups;
run;


/* preparation phase */

data TSA.modified;
	set TSA.nodups;
	
	Claim_Type = Scan(Claim_Type, 1, "/");
	
	if Claim_Type in ("","-") then Claim_Type="Unknown";
	if Claim_Site in ("","-") then Claim_Site="Unknown";
	if Disposition in ("","-") then Disposition="Unknown";
	
	if Disposition = "Closed: Canceled" then Disposition = "Closed:Canceled";
	if Disposition = "losed: Contractor Claim" then Disposition = "Closed:Contractor Claim";
	
	StateName = Propcase(StateName);
	State = Upcase(State);
run;

data TSA.modified2;
	
	set TSA.modified;
	drop County City;
	format Close_Amount dollar8.2 Date_Received Incident_Date date9.;
	
	where (Claim_Type in ("Bus Terminal", "Complaint", "Compliment","Employee Loss (MPCECA)",
	"Missed Flight", "Motor Vehicle", "Not Provided", "Passenger Property Loss", "Passenger Theft",
	"Personal Injury", "Property Damage", "Property Loss", "Unknown", "Wrongful Death")
	and Claim_Site in ("Bus Station", "Checked Baggage", "Checkpoint", "Motor Vehicle",
	"Not Provided", "Other", "Pre-Check", "Unknown")
	and Disposition in ("*Insufficient", "Approve in Full", "Closed:Canceled",
	"Closed:Contractor Claim", "Deny", "In Review", "Pending Payment", "Received", "Settle", 
	"Unknown"));
	
	if Incident_Date = . or Date_Received = . or 
	YEAR(Incident_Date) < 2002 or YEAR(Incident_Date) > 2017 or Year(Date_Received) < 2002 or Year (Date_Received) > 2017 or
	Date_Received < Incident_Date then
	Date_Issues = "Needs Review";
run;

proc sort data=tsa.modified2 out=tsa.final;
	by Incident_Date;
run;

data tsa.analysis;
	set tsa.final;
	where Date_Issues is missing;
run;
/* analysis phase */

%let State = CA;

ods pdf file="/home/u63977047/TSA/summary.pdf";


proc freq data=tsa.analysis;
	table Incident_Date / plots=freqplot;
	format Incident_Date year.;
run;

title "State: &State";
proc freq data=tsa.analysis;
	where State = "&State";
	Tables Claim_Type Claim_Site Disposition;
run;

proc means data=tsa.analysis mean min max sum maxdec=0;
	where State = "&State";
	var Close_Amount;
run;
title;
	
ods pdf close;

ods graphics off;