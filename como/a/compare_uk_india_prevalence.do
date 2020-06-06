/***********************************************************/
/* sc: a function to compare multiple prevalences over age */
/***********************************************************/
cap prog drop scp
prog def scp

  syntax varlist, [name(string) yscale(passthru) yline(passthru)]
  tokenize `varlist'

  /* set a default yscale (or not) */
  if mi("`yscale'") local yscale

  /* set a default name */
  if mi("`name'") local name euripides
  
  /* loop over the outcome vars */
  while (!mi("`1'")) {

    /* store the variable label */
    local label : variable label `1'

    /* add the line plot for this variable to the twoway command string */
    local command `command' (line `1' age, `yscale' xtitle("`label'") ytitle("Prevalence") lwidth(medthick) )

    /* get the next variable in the list */
    mac shift
  }

  /* draw the graph */
  twoway `command', `yline'
  graphout `name'
end
/****************** end sc *********************** */


use $health/dlhs/data/dlhs_ahs_covid_comorbidities, clear

collapse (mean) diabetes_both diabetes_uncontr bp_high chronic_resp_dz, by(age)

/* merge UK prevalences from various sources */
merge 1:1 age using $tmp/uk_prevalences, keep(match) nogen

/* merge India and UK GBD data */
merge 1:1 age using $health/gbd/gbd_nhs_conditions_uk, keep(match) nogen
drop *upper *lower
ren gbd_* gbd_uk_*
merge 1:1 age using $health/gbd/gbd_nhs_conditions_india, keep(match) nogen
drop *upper *lower
ren gbd_* gbd_india_*
ren gbd_india_uk_* gbd_uk_*

/* label india microdata vars */
label var diabetes_both "Diabetes (India)"
label var bp_high "BP High (India)"
label var chronic_resp_dz "Chronic Respiratory (India)"

/* label UK summary report vars */
label var uk_prev_diabetes "Diabetes (UK)"
label var uk_prev_hypertension "Hypertension (UK)"
label var uk_prev_asthma "Asthma (UK)"
label var uk_prev_copd "COPD (UK)"

/* label GBD vars */
label var gbd_india_chronic_resp_dz "COPD (GBD-India)"
label var gbd_india_diabetes "Diabetes (GBD-India)"
label var gbd_india_asthma_ocs "Asthma (GBD-India)"
label var gbd_india_chronic_heart_dz "Heart Disease (GBD-India)"

label var gbd_uk_chronic_resp_dz "COPD (GBD-UK)"
label var gbd_uk_diabetes "Diabetes (GBD-UK)"
label var gbd_uk_asthma_ocs "Asthma (GBD-UK)"
label var gbd_uk_chronic_heart_dz "Heart Disease (GBD-UK)"

sort age

save $tmp/uk_india, replace
use $tmp/uk_india, clear

/* apply a smoother to the India microdata conditions */
tsset age
foreach v in diabetes_both diabetes_uncontr bp_high chronic_resp_dz {
  replace `v' = (L2.`v' + L1.`v' + `v' + F1.`v' + F2.`v') / 5 if !mi(L2.`v') & !mi(F2.`v')
  replace `v' = (L1.`v' + `v' + F1.`v') / 3 if (mi(L2.`v') | mi(F2.`v')) & !mi(L1.`v') & !mi(F1.`v')
}

sort age

/* respiratory disease */
scp chronic_resp_dz uk_prev_copd gbd_uk_chronic_resp gbd_india_chronic_resp, name(copd) yline(.041)

/* asthma */
scp uk_prev_asthma gbd_*_asthma*, name(asthma) yline(.017)

/* heart disease */
scp gbd_uk_chronic_heart_dz gbd_india_chronic_heart_dz, name(heart) yline(.067)

/* diabetes */
scp diabetes_both uk_prev_diabetes gbd_uk_diabetes gbd_india_diabetes, name(diabetes) yline(.088)

/* high blood pressure */
scp bp_high uk_prev

twoway (line diabetes age, lwidth(medthick)) (line uk_prev_diabetes age, lwidth(medthick)), name(d, replace) yline(.028)
graphout diabetes_uk_india

twoway (line bp_high age, lwidth(medthick)) (line uk_prev_hypertension age, lwidth(medthick)), name(bp, replace) yline(.342)
graphout bp_uk_india

twoway (line resp_chronic age, lwidth(medthick)) (line uk_prev_asthma age, lwidth(medthick)) (line uk_prev_copd age, lwidth(medthick)), name(resp, replace) yline(.142 .041)
graphout resp_uk_india


