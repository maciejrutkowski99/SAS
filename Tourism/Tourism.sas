libname tourism "/home/u63977047/Tourism";

data tourism.base;
	set cr.tourism;
run;

data tourism.clean;
	set tourism.base  (rename=(Country = Category));
	label Category="Category";
	drop _1995--_2014;
	length Country_Name $ 55;
	retain Country_Name;
	if A ne . then Country_Name = Category;
	
	length Tourism_Type $ 20;
	retain Tourism_Type;
	if Category = "Inbound tourism" then Tourism_Type = Category;
	else if Category = "Outbound tourism" then Tourism_Type = Category;
	
	Series = Upcase(Series);
	if Series = ".." then Series = "";
	
	if _2014 = ".." then _2014 = "";
	
	format Y2014 comma17.;
	if scan(Category, -1) = "Mn" then Y2014 = input(_2014, 6.) * 1000000;
	else Y2014 = input(_2014, 6.) * 1000;
	
	if A = . and Tourism_Type ne Category then output;
run;


proc sort data=cr.country_info;
	by Country;
run;

proc sort data=tourism.clean;
	by Country_Name;
run;

proc format;
	value hehe 1 = "North America"
		       2 = "South America"
		       3 = "Europe"
		       4 = "Africa"
		       5 = "Asia"
		       6 = "Oceania"
		       7 = "Antarctica";
run;

data tourism.final_tourism tourism.nocountryfound;
	drop A;
	merge tourism.clean (in=pierwsze) cr.country_info(rename=(Country=Country_Name) in=drugie);
	by Country_Name;
	format Continent hehe.;
	
	if pierwsze = 1 and drugie = 1 then output tourism.final_tourism;
	else output tourism.nocountryfound;
run;






proc sort data=tourism.final_tourism;
	by Continent;
run;
	
proc means data=tourism.final_tourism mean;
	where Category = "Tourism expenditure in other countries - US$ Mn";
run;

proc freq data=tourism.clean;
	table _all_;
run;


	