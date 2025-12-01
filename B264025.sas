/*STEP 1: Data Wrangling for Earnings*/

/*Import data related to the monthly earning of each region in England region*/
PROC IMPORT 
	datafile='/home/u64380250/Assignment/rtisanov2025.xlsx' /*Data related to earnings*/
	dbms=xlsx
	out=earnings
	replace;
	sheet='9. Mean pay (NUTS1)';
RUN;

/*Keep only data from row 7 and onwards*/
DATA earnings;
    set earnings;
    if _n_ >= 7; 											/*There is no data from row 1-7*/
RUN;													

/*Create macro for printing first five rows*/
%macro print(dataset);
    proc print data=&dataset(obs=5);						/*Validate that the first five rows of data is appropriate*/
        title "First 5 Rows of &dataset";	
    run;
%mend print;

/*Call the dataaset*/
%print(earnings);

/*Validate the collumn name*/
PROC CONTENTS data=earnings; 
RUN;

/*Keep only data from first collumn to tenth collumn for England region*/
DATA earnings;
	set earnings;
	keep '9. Mean pay from PAYE RTI'n B C D E F G H I J; 	/*Only keep data within our scope of analysis*/
RUN;

/*Rename the variable into appropriate field name*/
DATA data_earnings;
    set earnings;
    rename													/*Rename based on the row means*/
    	'9. Mean pay from PAYE RTI'n=Date					
    	B=North_East
    	C=North_West
    	D=Yorkshire_and_The_Humber
    	E=East_Midlands
    	F=West_Midlands_Region
    	G=East_of_England
    	H=London
    	I=South_East
    	J=South_West
    ;
RUN;

/*Change the format of the date*/
DATA data_earnings;
    set data_earnings;
    /*Make the month comes from the first word and
    the year from the second word in the date variable*/
    month_str = scan(Date, 1, ' ');
    year_str = scan(Date, 2, ' ');

    /*Create mapping from the month in the date section*/
    if upcase(month_str) = 'JANUARY' then month = 1;
    else if upcase(month_str) = 'FEBRUARY' then month = 2;
    else if upcase(month_str) = 'MARCH' then month = 3;
    else if upcase(month_str) = 'APRIL' then month = 4;
    else if upcase(month_str) = 'MAY' then month = 5;
    else if upcase(month_str) = 'JUNE' then month = 6;
    else if upcase(month_str) = 'JULY' then month = 7;
    else if upcase(month_str) = 'AUGUST' then month = 8;
    else if upcase(month_str) = 'SEPTEMBER' then month = 9;
    else if upcase(month_str) = 'OCTOBER' then month = 10;
    else if upcase(month_str) = 'NOVEMBER' then month = 11;
    else if upcase(month_str) = 'DECEMBER' then month = 12;
    else month = .;
	
	/*Create definition for the year, which is four characters in the year_str*/
    year = input(year_str, 4.);

	/*Check for missing variable*/
    if month ne . and year ne . then do;
        Date_Final = mdy(month, 1, year);
    end;
    else do;
        Date_Final = .;
    end;

	/*Create format for the date*/
    format Date_Final yymmdd10.;

	/*Remove unneccesary variables*/
    drop Date month_str year_str month year;
RUN;

/*Filter selected period: January 2015 - December 2024*/
DATA data_earnings;
	set data_earnings;
 	where '01JAN2015'd <= Date_Final <= '31DEC2024'd;
RUN;

/*Call the dataset*/
%print(data_earnings);									/*Validate that the first five rows of data is appropriate*/

/*Transpose the data*/
PROC TRANSPOSE data=data_earnings 
	out=final_data_earnings name=Region; 				/*Transpose to merge with the other dataset*/
	by Date_Final;
	var North_East North_West Yorkshire_and_The_Humber 
	East_Midlands West_Midlands_Region East_of_England 
	London South_East South_West;
RUN;

DATA final_data_earnings;
    set final_data_earnings;
    rename COL1 = Monthly_Salary; 						/*Replace with proper variable name*/
    drop _LABEL_;
RUN;

/*Create a new variable as identifier*/
DATA final_data_earnings;
	length identifier $32;
	set final_data_earnings;
	StringDate_Earning = substr(put
	(Date_Final, yymmdd10.), 1, 7);						/*Select the first seven characters (YYYY-MM)*/
	Identifier = catt(StringDate_Earning,Region);		/*Concatenate the date and region*/
RUN;

/*Call the dataset*/
%print(final_data_earnings);


/*STEP 2: Data Wrangling for Average Price of Property*/

/*Import data related to the average price of property of each region in England region*/
/*Importing the first file*/
PROC IMPORT 
	datafile='/home/u64380250/Assignment/ukhpi-comparison-all-
	avg-east-of-england-from-2015-01-01-to-2025-10-01.csv'
	dbms=csv
	out=price_1
	replace;
RUN;

/*Macro for length*/
%macro change_name_length(ds_in=, ds_out=, length=);
    %if &length ne %then %do;
        data &ds_out;
            length name $&length;
            set &ds_in(rename=(name=old_name));
            name = old_name;
            drop old_name;
        run;
    %end;
    %else %do;
        data &ds_out;
            set &ds_in;
        run;
    %end;
%mend change_name_length;

/*Ensure the length is in accordance with number of character*/
%change_name_length(ds_in=price_1, ds_out=price_1_final, length=32);

/*Importing the second file*/
PROC IMPORT 
	datafile='/home/u64380250/Assignment/ukhpi-comparison-all
	-avg-north-east-from-2015-01-01-to-2025-10-01.csv'
	dbms=csv
	out=price_2
	replace;
RUN;

/*Ensure the length is in accordance with number of character*/
%change_name_length(ds_in=price_2, ds_out=price_2_final, length=32);

/*Stack both data*/
DATA data_price;
    set price_1_final price_2_final;
    drop URI period 'Region GSS Code'n 
    'Sales volume'n 'Reporting period'n;				/*Remove any unnecessary variable*/
RUN;

/*Filter selected period: January 2015 - December 2024*/
DATA data_price;
	set data_price;
 	if '01JAN2015'd <= 'Pivotable Date'n <= '31DEC2024'd;
RUN;

/*Ensure the unique value data of region*/
PROC FREQ data=data_price;
    tables name / nocum noprint out=unique_names;
RUN;

/*Match the naming of region with the earning data*/
%macro map_region_dynamic(ds_in=, ds_out=);
    data &ds_out;
        length region $32;
        set &ds_in;
        region = translate(strip(name), '_', ' '); 		/*Replace space with underscore*/
    run;
%mend map_region_dynamic;

/*Use macro for naming change*/
%map_region_dynamic(ds_in=data_price, ds_out=data_price);

/*Create an identifier for both of the data*/
DATA final_data_price;
	length identifier $32;
	set Data_price;
	StringDate_Price = substr(put('Pivotable Date'n,
	yymmdd10.), 1, 7);									/*Select the first seven characters (YYYY-MM)*/
	Identifier = catt(StringDate_Price,Region);			/*Concatenate the date and region*/
RUN;

/*STEP 3: Combine both data to be in one dataset*/

/*Sort the data before interleaving*/
PROC SORT data = final_data_earnings;
	by Identifier;
RUN;
PROC SORT data = final_data_price;
	by Identifier;
RUN;

/*Merge both data*/
DATA combined_dataset;
    merge final_data_earnings final_data_price;
    by identifier;
    label date_final = Period of Data;
    label 'Average price All property type'n = Average of Property Price in England;
    label monthly_salary = Monthly Earnings of Individual;
    label identifier = Unique Identifier for Matching Purposes;
    label region = Region in the England;
    drop stringdate_earning name 'pivotable date'n stringdate_price;
RUN;

/*Validate contents of combined data*/
PROC CONTENTS data=combined_dataset;
RUN;

/*Change the data type of salary from char to numeric*/
DATA combined_dataset;
	set combined_dataset;
    monthly_salary_num = input(monthly_salary, best12.);/*Change of data type*/
    drop monthly_salary;
    rename monthly_salary_num = monthly_salary; 
RUN;

/*STEP 4: Ensure there is no data that is double*/

/*Validate the uniqueness of identifier*/
PROC FREQ DATA=combined_dataset; 
  table identifier / OUT = check;						/*Each identifier must only equal to 1*/
RUN;

/*Print those with count > 1*/
PROC PRINT data=check;
  Where count > 1;
RUN; 													/*There is no data with frequency above 1, 
														all data is unique*/

/*STEP 4: Descriptive Analytics*/

/*Analyze the Average of Earnings in the whole dataset*/
PROC UNIVARIATE data=combined_dataset;
    var monthly_salary;
RUN;

/*Mean and median is close. However, skewness is above 1.*/

/*Further validate the normality using quantiles. 
The distribution appear to be normally distributed.
There is mild right skeness because the upper half distances are a bit larger.
There is no extreme jumps in tails and spacing is relatively smooth.*/

/*Analyze the Average Price of Property in the whole dataset*/
PROC UNIVARIATE data=combined_dataset;
    var 'Average price All property type'n;
RUN;
/*Mean and median is not as close. Furthermore, skewness is above 1.*/

/*Further validate the normality using quantiles. 
The distribution does not appear to be normally distributed.
The distances between Q1-median-Q3 are not equal.
There is a large jumps in tails that suggest heavy tails or outliers.*/

/*Checked based on the region.*/
PROC SORT data=combined_dataset;
    by Region;
RUN;

PROC MEANS data=combined_dataset mean stddev median skew kurtosis min max;
    by Region;
    var monthly_salary;
RUN;

/*When we validate it based on the region, 
the mean and median appear to be closer with lower skewness.*/

PROC MEANS data=combined_dataset mean stddev median skew kurtosis min max;
    by Region;
    var 'Average price All property type'n;
RUN;

/*When we validate it based on the region, 
the mean and median appear to be closer with lower skewness.*/

/*Validate further using a vertical boxplot*/
PROC SGPLOT data=combined_dataset;
    title 'Plotting the Monthly Salary';
    vbox monthly_salary / 
        category=region
        connect=mean
        connectattrs=(color="lightgreen" pattern=mediumdash thickness=4)
        datalabel=monthly_salary;
RUN;

/*Data visualization shows that the mean and median is not close with a lot of outliers*/

/*Analysis: The boxplot shows that the monthly salary is not symmetric,
with several outliers and not balanced sread on both sides of the median.
The mean and median is not close, and the whiskers do not extend evenly,
all of which support the conclusion that the distribution is not close to normal*/

PROC SGPLOT data=combined_dataset;
    title 'Plotting the Average Price of Property';
    vbox 'Average price All property type'n / 
        category=region
        connect=mean
        connectattrs=(color="lightgreen" pattern=mediumdash thickness=4)
        datalabel='Average price All property type'n;
RUN;

/*Data visualization shows that the mean and median is not close with a lot of outliers*/

/*Analysis: The boxplot shows that the average price of property is not symmetric,
with several outliers and not balanced sread on both sides of the median.
The mean and median is not close, and the whiskers do not extend evenly,
all of which support the conclusion that the distribution is not close to normal*/

/*STEP 5: Validate the Normality of The Data*/

/*Confidence interval for the population mean*/
/*Use the means procedure:*/
PROC MEANS data=combined_dataset MEAN CLM ALPHA=0.05; /*Confidence level of 95%*/
	var monthly_salary 'Average price All property type'n;
	by region;
	title 'Confidence interval for the mean of Monthly Salary and Average Property Price';
RUN;

/*Use the ttest procedure*/
PROC TTEST data=combined_dataset ALPHA=0.05; /*Confidence level of 95%*/
	var monthly_salary 'Average price All property type'n;
	by region;
	title 'PROC ttest result for Monthly salary and Average Property Price';
RUN;

/*Analysis for monthly salary:
Based on the Q-Q Plot, data appear to not be normal
and salary show moderate variation that can 
be seen through moderate standard deviation

Analysis for average price for property: 
Based on the Q-Q Plot, data appear to not be normal 
and property priced vary a lot that can be seen through high standard deviation*/

/*STEP 5: Multiple Linear Regression*/

/*Scatter Plot*/
PROC SGPLOT data=combined_dataset;
    scatter y="Average price All property type"n
            x=monthly_salary
            / group=Region;
    title "Correlation between Monthly Salary and Average Property Price";
RUN;
/*Data of certain region appear to be linear*/

/*Validate the correlation*/
PROC CORR data=combined_dataset;
	by region;
	var "Average price All property type"n monthly_salary;
RUN;

/*Based on the pearson correlation coefficient,
Monthly salary and property prices are very related for all region.*/

/*Analysis using VIF and tol*/
PROC REG data=combined_dataset outest=combination;
    title 'Fitting the Regression by Region';
    by region;
    model "Average price All property type"n = monthly_salary / vif tol collin;
RUN;
/*No VIF is above or equal to 5, meaning there is no concern for collinearity*/

/*Making predictions*/
PROC PRINT data=combination;
RUN;

/*Analysis: Each region has a different relationship between salary and property price
with varying intercepts and slopes, which reflect the local market conditions.*/

/*Use PROC SCORE to apply the regression model to every observation.
Predict the average property price by monthly salary and region.*/
PROC SCORE 
	data=combined_dataset 
	score=combination 
	out=pred_combined_dataset 
	type=parms
	predict;
	by region; 
	var monthly_salary;
RUN;

/*Validate the difference of prediction with actual price*/
DATA pred_combined_dataset;
    set pred_combined_dataset;
    Diff = 'Average price All property type'n - model1; /*Calculate difference*/
RUN;

/*Minimum and Maximum difference*/
PROC MEANS data=pred_combined_dataset min max;
    var diff;
run;

/*Exporting any data needed for the report*/

/*Vertical Box*/
ods pdf file="/home/u64380250/Assignment/vbox.pdf";
PROC SGPLOT data=combined_dataset;
    title 'Plotting the Monthly Salary';
    vbox monthly_salary / 
        category=region/* add a categorical variable here if you want to group by category */
        connect=mean
        connectattrs=(color="lightgreen" pattern=mediumdash thickness=4)
        datalabel=monthly_salary;
RUN;

PROC SGPLOT data=combined_dataset;
    title 'Plotting the Average Price of Property';
    vbox 'Average price All property type'n / 
        category=region/* add a categorical variable here if you want to group by category */
        connect=mean
        connectattrs=(color="lightgreen" pattern=mediumdash thickness=4)
        datalabel='Average price All property type'n;
RUN;
ods pdf close;

/*Normality Testing*/
ods pdf file="/home/u64380250/Assignment/normality.pdf";
PROC TTEST data=combined_dataset ALPHA=0.05; /*Confidence level of 95%*/
	var monthly_salary 'Average price All property type'n;
	by region;
	title 'PROC ttest result for Monthly salary and Average Property Price';
RUN;
ods pdf close;

/*Scatter Plot*/
ods pdf file="/home/u64380250/Assignment/scatter_plot.pdf";
PROC SORT data=combined_dataset;
    by region;
RUN;

PROC REG data=combined_dataset;
	title 'Correlation Between Variables'
    by region;
    model 'Average price All property type'n = monthly_salary;
RUN;
QUIT;
ods pdf close;

/*End*/