/* program to calculate generic outcomes given:

1. a set of condition-specific (and possibly age-specific) hazard ratios (i.e. the model)
$tmp/hr_[full|simp]_[cts|dis]

2. a set of prevalences
$tmp/prev_india, $tmp/prev_uk_os, $tmp/prev_uk_nhs, $tmp/prev_uk_nhs_matched

3. a population distribution
[later]

Outcomes
---------
1. age-specific mortality curve (Fig. 2A)
1A. age-specific health contribution to mortality curve
2. share of deaths under age 60
3. total number of deaths given a mortality rate for women aged 50-59.

*/

local hr full_cts
local prev india

/* loop over prevalence files -- nhs is age-specific, o/s is just pop means */
/* uk_nhs_matched is the UK one we use for everything. */
foreach prev in india uk_os uk_nhs uk_nhs_matched {

  /* loop over hazard ratio sets -- cts means age is cts and not in bins */
  /* full_cts is the main one that we use. */
  foreach hr in simp_dis full_dis simp_cts full_cts ny nycu {

    /* show which entry we are on */
    disp_nice "`prev'-`hr'"
    
    /* open the hazard ratio file */
    use $tmp/hr_`hr', clear
    
    /* merge the prevalence file */
    merge 1:1 age using $tmp/prev_`prev', nogen
    
    /* calculate the risk factor at each age, multiplying prevalence by hazard ratio */
    gen prr_health = 1
    foreach v in male $hr_biomarker_vars $hr_gbd_vars $hr_os_only_vars {

      /* rf <-- rf * (prev_X * hr_X + (1 - prev_X) * hr_notX), but hr_notX is always 1 */
      gen prr_`v' = prev_`v' * hr_`v' + (1 - prev_`v')
      qui replace prr_health = prr_health * prr_`v'
      qui sum prr_health
      di "`v': " %5.2f `r(mean)'
    }

    /* normalize the cts age hazard ratio around age 50 */
    if strpos("`hr'", "cts") {
      qui sum hr_age if age == 50
      qui replace hr_age = hr_age / `r(mean)'
    }
    
    /* create another one that has age */
    gen prr_all = prr_health * hr_age
    
    save $tmp/prr_`prev'_`hr', replace

    /* save a version on iec for santosh */
    export delimited using ~/iec/output/pn/prr_`prev'_`hr'.csv, replace
  }
}

/* combine the joint risk factors */
clear
set obs 82
gen age = _n + 17
foreach prev in india uk_os uk_nhs uk_nhs_matched {
  foreach hr in simp_dis full_dis simp_cts full_cts ny nycu {
    merge 1:1 age using $tmp/prr_`prev'_`hr', keepusing(prr_all prr_health) nogen
    ren prr_all prr_all_`prev'_`hr'
    ren prr_health prr_h_`prev'_`hr'
  }
}

/* bring in population shares */
merge 1:1 age using $tmp/india_pop, keep(master match) nogen keepusing(india_pop)
merge 1:1 age using $tmp/uk_pop, keep(master match) nogen keepusing(uk_pop)

/* save an analysis file */
save $tmp/como_analysis, replace

/*****************************************/
/* compare health condition risk factors */
/*****************************************/
/* compare India and UK health condition risk factors */
// scp prr_h_india_full_cts prr_h_uk_os_full_cts prr_h_uk_nhs_matched_full_cts prr_h_uk_nhs_full_cts, ///
//     ytitle("Aggregate Contribution to Mortality from Risk Factors") ///
//     legend(lab(1 "India") lab(2 "UK OpenSafely Coefs") lab(3 "UK full matched") lab(4 "UK full full")) name(prr_health_all)

/* india vs. uk matched */
sort age
twoway ///
    (line prr_h_india_full_cts age, lwidth(medthick) lcolor(black)) ///
    (line prr_h_uk_nhs_matched_full_cts age, lwidth(medthick) lcolor(orange)), ///
    ytitle("Aggregate Contribution to Mortality from Risk Factors") xtitle("Age") ///
    legend(lab(1 "India") lab(2 "England") ring(0) pos(5) cols(1) size(small) symxsize(5) bm(tiny) region(lcolor(black))) ///
    name(prr_health, replace)  ylabel(1(.5)4) 
graphout prr_health

/* NY hazard ratios */
sort age
twoway ///
    (line prr_h_india_ny age, lwidth(medthick) lcolor(black)) ///
    (line prr_h_uk_nhs_matched_ny age, lwidth(medthick) lcolor(gs8) lpattern(-)), ///
    title("NY State Hazard Ratios") ytitle("Risk Factor from Population Health Conditions") xtitle("Age") ///
    legend(lab(1 "India") lab(2 "England") ring(0) pos(5) cols(1) region(lcolor(black))) ///
    name(prr_health_ny, replace)  ylabel(1(.5)4)
graphout prr_health_ny

/* NY-Cummings HRs */
sort age
twoway ///
    (line prr_h_india_nycu age, lwidth(medthick) lcolor(black)) ///
    (line prr_h_uk_nhs_matched_nycu age, lwidth(medthick) lcolor(gs8) lpattern(-)), ///
    title("NY (Cummings) Hazard Ratios") ytitle("Risk Factor from Population Health Conditions") xtitle("Age") ///
    legend(lab(1 "India") lab(2 "England") ring(0) pos(5) cols(1) region(lcolor(black))) ///
    name(prr_health_nycu, replace)  ylabel(1(.5)6)
graphout prr_health_nycu

// graph combine prr_health prr_health_ny prr_health_nycu, cols(3) ycommon
// graphout prr_combined


// /*************************************/
// /* compare age * health risk factors */
// /*************************************/
// /* compare three UK models: OS fixed age, full-prevalences, simp */
// sc prr_all_uk_os_simp_cts prr_all_uk_os_full_cts prr_all_uk_nhs_matched_full_cts prr_all_uk_nhs_full_cts, ///
//     legend(lab(1 "Simp") lab(2 "Full O.S. coefs") lab(3 "Full (matched conditions)") lab(4 "Full (all conditions)")) name(prr_uk_compare) yscale(log)
// 
// /* full vs. full, India vs. UK */
// sc prr_all_india_full_cts prr_all_uk_nhs_matched_full_cts, ///
//     name(prr_all_full) yscale(log) legend(lab(1 "India") lab(2 "UK"))
// 
// /* simp vs. simp, India vs. UK */
// sc prr_all_india_simp_cts prr_all_uk_nhs_simp_cts, ///
//     name(prr_all_simp) yscale(log) legend(lab(1 "India") lab(2 "UK"))

/*****************************/
/* compare density of deaths */
/*****************************/
/* rename the models to make life easier */
ren *india_full_cts* *india_full*
ren *uk_nhs_matched_full_cts* *uk_full*
ren *uk_nhs_matched_ny* *uk_ny*
ren *india_simp_cts* *india_simp*
ren *uk_nhs_simp_cts* *uk_simp*

global modellist india_full uk_full india_simp uk_simp india_ny uk_ny india_nycu uk_nycu

/* Calculate the distribution of deaths in the model */
global mortrate 1
foreach model in full simp ny nycu {
  foreach country in uk india {
    gen `country'_`model'_deaths = $mortrate * `country'_pop * prr_all_`country'_`model'
  }
}

global sim_n 1

/* rescale so there are 100,000 deaths in each model */
foreach model in $modellist {
  local v `model'_deaths
  sum `v'
  replace `v' = `v' / (`r(mean)' * `r(N)') * $sim_n
}

// /* plot uk vs. india death density, simp */
// sort age
// label var age "Age"
// twoway ///
//     (line uk_simp_deaths    age, lcolor(orange) lwidth(medium) lpattern(.-))     ///
//     (line india_simp_deaths age, lcolor(gs8) lpattern(-) lwidth(medthick))       ///
//     , ytitle("Distribution of Deaths" "Normalized population: 100,000") xtitle(Age)  ///
//     legend(lab(1 "England (simp)") ///
//     lab(2 "India (simp)"))
// graphout mort_density_simp

/* smooth the deaths series */
sort age
gen x = 1
xtset x age
foreach v of varlist *deaths {
  replace `v' = (L2.`v' + L1.`v' + `v' + F.`v' + F2.`v') / 5 if !mi(L2.`v') & !mi(F2.`v')
  replace `v' = (L1.`v' + `v' + F.`v' + F2.`v') / 4 if mi(L2.`v') & !mi(F2.`v') & !mi(L1.`v')
  replace `v' = (L2.`v' + L1.`v' + `v' + F.`v') / 4 if mi(F2.`v') & !mi(L2.`v') & !mi(F1.`v')
}

/* add a line representing india's total deaths as of April 30
   source: https://pib.gov.in/PressReleaseIframePage.aspx?PRID=1619609 */
gen in_deaths_old = 0
/* 18 - 45 year olds */
replace in_deaths_old = $sim_n * 0.14 / (45 - 18 + 1) if inrange(age, 18, 44)
/* 45 - 60 year olds */
replace in_deaths_old = $sim_n * 0.348 / 15 if inrange(age, 45, 59)
/* 60 - 75 */
replace in_deaths_old = $sim_n * 0.42 / 15 if inrange(age, 60, 74)
/* 75 +  */
replace in_deaths_old = $sim_n * 0.092 / 25 if inrange(age, 75, 99)

/* add a line representing india's total deaths as of May 21
   source: https://pib.gov.in/PressReleseDetailm.aspx?PRID=1625744 */
gen in_deaths = 0
/* 15-30 year olds */
replace in_deaths = $sim_n * 0.03 / (30 - 18 + 1) if inrange(age, 18, 30)
/* 30-45 year olds */
replace in_deaths = $sim_n * 0.114 / 15 if inrange(age, 31, 45)
/* 45 - 60 */
replace in_deaths = $sim_n * 0.351 / 15 if inrange(age, 46, 60)
/* 60 - 75 this age bracket doesn't exist but we used the fraction from the April 30 report of 60-75/60+ */
replace in_deaths = $sim_n * 0.414 / 15 if inrange(age, 61, 75)
/* 75 +  */
replace in_deaths = $sim_n * 0.091 / 25 if inrange(age, 76, 99)

/* add a line representing maharashtra's data in the May 8 report */
gen mh_deaths = 0
/* total deaths: 540. Total years: 89-18+1=72 */
/* 18-29: 12 deaths  */
replace mh_deaths = $sim_n * 16/540 / (30 - 18 + 1) if inrange(age, 18, 30)
/* 30-39: 27 */
replace mh_deaths = $sim_n * 35/540 / 10 if inrange(age, 31, 40)
/* ... */
replace mh_deaths = $sim_n * 92/540  / 10 if inrange(age, 41, 50)
replace mh_deaths = $sim_n * 166/540 / 10 if inrange(age, 51, 60)
replace mh_deaths = $sim_n * 146/540 / 10 if inrange(age, 61, 70)
replace mh_deaths = $sim_n * 68/540  / 10 if inrange(age, 71, 80)
replace mh_deaths = $sim_n * 17/540  / 20 if inrange(age, 81, 99)

/* prepare a line for an England model */
gen en_deaths = 0
replace en_deaths = $sim_n * 49/5683 / (40 - 18 + 1) if inrange(age, 18, 40)
replace en_deaths = $sim_n * 94/5683  / 10 if inrange(age, 40, 49)
replace en_deaths = $sim_n * 355/5683 / 10 if inrange(age, 50, 59)
replace en_deaths = $sim_n * 693/5683 / 10 if inrange(age, 60, 69)
replace en_deaths = $sim_n * 1560/5683  / 10 if inrange(age, 70, 79)
replace en_deaths = $sim_n * 2941/5683  / 20 if inrange(age, 80, 99)

/* same graph, full model */
twoway ///
    (line india_full_deaths age if age <= 89, lcolor(black) lpattern(solid) lwidth(thick))       ///
    (line uk_full_deaths    age if age <= 89, lcolor(orange) lwidth(thick) lpattern(solid))     ///
    (line in_deaths_old     age if age <= 89, lcolor(black) lwidth(medium) lpattern(-))     ///
    (line en_deaths         age if age <= 89, lcolor(orange) lwidth(medium) lpattern(-))     ///
    , ytitle("Density Function of Deaths (%)") xtitle(Age)  ///
    legend(lab(1 "India (model)") ///
    lab(2 "England (model)") lab(3 "India (reported)") lab(4 "England (reported)") ///
    ring(0) pos(11) cols(2) region(lcolor(black)) size(small) symxsize(5) bm(tiny)) ///
    xscale(range(18 90)) xlabel(20 40 60 80) ylabel(.01 .02 .03 .04 .044) 
graphout mort_density_full

// /* all 4 lines */
// twoway ///
//     (line uk_simp_deaths    age, lcolor(orange) lwidth(medium) lpattern(-))        ///
//     (line india_simp_deaths age, lcolor(gs8) lpattern(-) lwidth(medthick))         ///
//     (line uk_full_deaths      age, lcolor(orange) lwidth(medium) lpattern(solid))    ///
//     (line india_full_deaths   age, lcolor(gs8) lpattern(solid) lwidth(medthick))     ///
//     , ytitle("Distribution of Deaths" "Normalized population: 100,000") xtitle(Age)  ///
//     legend(lab(1 "England (simp)") lab(2 "India (simp)") ///
//     lab(3 "England (full)") lab(4 "India (full)"))
// graphout mort_density_all

/* graph ny and nycu results  */
twoway ///
    (line uk_ny_deaths    age if age <= 89, lcolor(gs8) lwidth(medium) lpattern(-))     ///
    (line india_ny_deaths age if age <= 89, lcolor(black) lpattern(solid) lwidth(medthick))       ///
    (line mh_deaths         age if age <= 89, lcolor(orange) lwidth(medium) lpattern(.-))     ///
    (line en_deaths         age if age <= 89, lcolor(gs14) lwidth(medium) lpattern(.-))     ///
    , ytitle("Density Function of Deaths (%)") xtitle(Age)  ///
    title("NY State Age-specific ORs") legend(lab(1 "England (model)") ///
    lab(2 "India (model)") lab(3 "Maharasthra (reported)") lab(4 "England (reported)") ///
    ring(0) pos(11) cols(1) region(lcolor(black))) ///
    xscale(range(18 90)) xlabel(20 40 60 80) ylabel(.01 .02 .03 .04 .044)
graphout mort_density_ny
twoway ///
    (line uk_nycu_deaths    age if age <= 89, lcolor(gs8) lwidth(medium) lpattern(-))     ///
    (line india_nycu_deaths age if age <= 89, lcolor(black) lpattern(solid) lwidth(medthick))       ///
    (line mh_deaths         age if age <= 89, lcolor(orange) lwidth(medium) lpattern(.-))     ///
    (line en_deaths         age if age <= 89, lcolor(gs14) lwidth(medium) lpattern(.-))     ///
    , ytitle("Density Function of Deaths (%)") xtitle(Age)  ///
    title("NY (Cummings) HRs") legend(lab(1 "England (model)") ///
    lab(2 "India (model)") lab(3 "Maharasthra (reported)") lab(4 "England (reported)") ///
    ring(0) pos(11) cols(1) region(lcolor(black))) ///
    xscale(range(18 90)) xlabel(20 40 60 80) ylabel(.01 .02 .03 .04 .044)
graphout mort_density_nycu

// graph combine density density_ny density_nycu, rows(1)
// graphout mort_combined

/******************************************/
/* calculate share of deaths under age 60 */
/******************************************/
foreach model in $modellist {
  qui sum `model'_deaths if age < 60
  di %25s "`model': " %5.1f (`r(N)' * `r(mean)' * 100)
}

/**********************************************************/
/* compare UK health conditions and risk factors to India */
/**********************************************************/
use $tmp/prr_india_full_cts, clear
ren prev* iprev*
ren prr* iprr*
merge 1:1 age using $tmp/prr_uk_nhs_matched_full_cts, nogen
ren prev* uprev*
ren prr* uprr*

/* calculate relative difference in prevalence and risk factor for each condition */
foreach v in male $hr_biomarker_vars $hr_gbd_vars $hr_os_only_vars {
  gen rfdiff_`v' = iprr_`v' / uprr_`v'
  gen prevdiff_`v' = iprev_`v' / uprev_`v'
}

/* report */
foreach v in male $hr_biomarker_vars $hr_gbd_vars $hr_os_only_vars {
  qui sum rfdiff_`v' if age == 50
  local rfd `r(mean)'
  qui sum prevdiff_`v' if age == 50
  local prevd `r(mean)'
  
  di %40s "`v' : " %5.2f `rfd' %10.2f `prevd'
}

/* calculate aggregate risk factor diffs between india and uk */
merge 1:1 age using $tmp/india_pop, keep(master match) nogen keepusing(india_pop)
merge 1:1 age using $tmp/uk_pop, keep(master match) nogen keepusing(uk_pop)

/* Show final results and save to file */

/* create csv file */
cap !rm -f $ddl/covid/como/a/covid_como_sumstats.csv

local t 1
foreach v in male $hr_biomarker_vars $hr_gbd_vars health {

  /* show title only if it's the first pass thru the loop */
  if `t' {
    di %25s " " "  UK    India   India/UK"
    di %25s " " "------------------------"
    }
  local t 0
  
  /* UK aggregate risk factor */
  qui sum uprr_`v' [aw=uk_pop]
  local umean = `r(mean)'
  
  /* India aggregate risk factor */
  qui sum iprr_`v' [aw=india_pop]
  local imean = `r(mean)'

  /* percent difference India over UK */
  local perc = (`imean'/`umean' - 1) * 100

  /* Get the sign on the % */
  if `perc' > 0 local sign " +"
  else local sign " "

  /* show everything */
  di %25s "`v': " %5.2f (`umean') "  " %5.2f (`imean') "  `sign'" %2.1f (`perc') "%"

  /* save everying in csv for table */
  insert_into_file using $ddl/covid/como/a/covid_como_sumstats.csv, key(uk_`v'_risk) value("`umean'") format(%3.2f)  
  insert_into_file using $ddl/covid/como/a/covid_como_sumstats.csv, key(india_`v'_risk) value("`imean'") format(%3.2f)
  insert_into_file using $ddl/covid/como/a/covid_como_sumstats.csv, key(`v'_ratio_sign) value("`sign'")
  insert_into_file using $ddl/covid/como/a/covid_como_sumstats.csv, key(`v'_ratio) value("`perc'") format(%3.2f)  
}
