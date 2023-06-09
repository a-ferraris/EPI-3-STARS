### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 
# Author: Augusto Ferraris, MD - UBA / MPH(C) - University of Washington, Seattle
# Contact information: aferra@uw.edu
# Date: June 2023
#
# Background:Opioids are commonly prescribed to patients with Chronic Obstructive Pulmonary Disease (COPD). 
# Likewise, patients with depressive disorders are prescribed opioids more frequently than those without. 
# Opioid use is associated with poor clinical outcomes in both populations. However, the risk of opioid use among individuals with both COPD and depressive disorders has not been evaluated. 
#
# Aim: This study evaluated the prevalence of opioid use among individuals living with COPD comparing those with and without depressive disorders.
#
# We analyzed pooled cross-sectional data from the Behavioral and Risk Factor Surveillance System in Washington State 2019-2021. We fitted a multivariate Poisson regression model to estimate weighted Prevalence Ratios (PR). 
# In addition, we assessed for effect modification of the association between depressive disorders and opioid use by urbanicity of residence and ays of poor mental health. 
#
# Program outline:
# 1. Data import. libraries. Data merging
# 2. Data cleaning, labeling, factorizing variables
# 3. Preparing for analysis: creating dataset with extreme case scenarios. 
# 4. Data weighting: Weighting prevalences and estimating proportions 
# 5. Data analysis: main analysis and sensitivity analyses 
#    a) crude analysis, b)adjusted mainanalysis, c)interaction models, d)sensitivity analysis
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 
#
# Code starts
# 1. Data import. libraries. Data merging ----
rm(list=ls())
setwd("C:/Users/Augusto/OneDrive/r_projects/EPI 514/datasets")
library(haven) # importing data from SAS to R
library(epiR) # MH analyses
library(tidyverse) # subsetting filtering. 
library(table1) # required for exporting tables in appropriate formatting 
library(survey) # weighting proportions for table 1.
library(lmtest) # to run poisson with weights

# a. loading year 2019
# data is loaded twice to deal with the underscore that some variables present in their labels.
# by doing so we avoid the use of variables with quotes and send to lower case
brfss<-read_dta("WA_BRFSS_2019.dta")
write.csv(brfss, "wa_brfss_2019.csv", row.names = FALSE)
brfss<-read.csv("wa_brfss_2019.csv", stringsAsFactors = FALSE)

columns_interest<-c("age", "X_race", "X_impsex", "X_incomg", "X_psu",
                    "X_phys14d", "X_ment14d", "X_michd", "cvdstrk3", "chcocncr",  
                    "X_drdxar2","chckdny2", "diabete4", "smoke100", 
                    "alcday5", "op_any", "X_ststr", "X_llcpwt", "rural2", 
                    "chccopd2", "addepev3", "genhlth","physhlth", "menthlth") # we create a vector of the 22 column names to simplify the merging of the data.

copd<-brfss[,columns_interest] # selecting columns of interest.

copd$X_llcpwt<-copd$X_llcpwt*12993/39037 # adjusting the weight to the number of observations/total
copd$X_ststr<-copd$X_ststr+19000000 # we create a variable that adds the year to the stratum of the survey

# b. loading year 2020 
brfss<-read_dta("WA_BRFSS_2020.dta")
write.csv(brfss, "wa_brfss_2020.csv", row.names = FALSE)
brfss<-read.csv("wa_brfss_2020.csv", stringsAsFactors = FALSE)

brfss<-brfss[,columns_interest]

brfss$X_llcpwt<-brfss$X_llcpwt*12902/39037 # adjusting weight to the number of individuals in final sample
brfss$X_ststr<-brfss$X_ststr+20000000 # we add the year to the stratum of the survey

copd<-rbind(copd, brfss)

# c. loading year 2021
brfss<-read_dta("WA_BRFSS_2021.dta")
write.csv(brfss, "wa_brfss_2021.csv", row.names = FALSE)
brfss<-read.csv("wa_brfss_2021.csv", stringsAsFactors = FALSE)

brfss$X_llcpwt<-brfss$X_llcpwt*13142/39037 # adjusting variable weight to the total final n of individuals. 
brfss$X_ststr<-brfss$X_ststr+21000000 # we add the year to the stratum of the survey

# some column names have changed for year 2021. I create new variables with the prior names to simplify the task:
# the columns are x_incomg1, X_drdxar3, and chccopd3
brfss$X_incomg<-brfss$X_incomg1
brfss$X_drdxar2<-brfss$X_drdxar3
brfss$chccopd2<-brfss$chccopd3

brfss<-brfss[,columns_interest]
copd<-rbind(copd, brfss) # final merge
rm(brfss, columns_interest)

# 2. Data cleaning, labeling, factorizing variables ----
copd<-copd[copd$chccopd2==1,] # filtering patients, keeping only those with a diagnosis of COPD

# renaming columns 
colnames(copd)<-c("age", "race", "male", "income_cat", "psu", "phys_14", "ment_14", "coronary_mi", 
                  "stroke", "cancer",  "arthritis", "ckd", "diabetes", "smoking_100", 
                  "drinking_any","op_any", "ststr_year", "llcpwt", "urban", "copd", "depressive", "general_health",
                  "phys_health", "ment_health")

# cleaning and factorizing variables. 
copd$age[copd$age==7 |copd$age==9]<-NA

copd$race[copd$race==9]<-NA # re-coding missing as NA
copd$race<-factor(copd$race, 
                  levels= 1:8, 
                  labels= c("White", "Black", "Native American", "Asian", "Pacific Islander", 
                            "Other", "Multiracial", "Hispanic")) # re-coding as factor variable using codebook

copd$male[copd$male==2]<-0 # re-coding 2 as 0 (females)
copd$male<-factor(copd$male, 
                  levels=0:1, 
                  labels=c("Female", "Male")) # re-coding as factor variable Female vs Male

copd$income_cat[copd$income_cat==9]<-NA # re-coding missing as NA
copd$income_cat[copd$income_cat==6|copd$income_cat==7]<-5 # variables 6 and 7 were introduced in 2021, corresponding to >100 and 200000 us dollars
                                                          # since they are not available in previous years, they are re-coded to agree the format. 

copd$income_cat<-factor(copd$income_cat, 
                        level=1:5, 
                        labels=c("<15k", "15 to =25k","25+ to =35k", "35+ to =50", "50+k")) # re-coding as factor variable using codebook

copd$phys_14[copd$phys_14==9]<-NA # re-coding missing as NA
copd$phys_14<-copd$phys_14-1 # re-coding the variable as factor with 3 levels, 0:2
copd$phys_14<-factor(copd$phys_14, 
                     levels=0:2, 
                     labels=c("Zero days", "1 to 13 days", "14 or more days")) # re-coding following codebooks

copd$ment_14[copd$ment_14==9]<-NA
copd$ment_14<-copd$ment_14-1
copd$ment_14<-factor(copd$ment_14, 
                     levels=0:2, 
                     labels=c("Zero days", "1 to 13 days", "14 or more days"))

copd$coronary_mi[copd$coronary_mi==2]<-0 # re-coding to 0/1 format
copd$coronary_mi<-factor(copd$coronary_mi, 
                         levels=0:1, 
                         labels=c("No", "Yes")) # re-coding following codebook 

copd$stroke[copd$stroke==7|copd$stroke==9]<-NA # re-coding NAs
copd$stroke[copd$stroke==2]<-0 # re-coding to 0/1 format
copd$stroke<-factor(copd$stroke, 
                    levels=0:1, 
                    labels=c("No", "Yes")) # re-coding according to codebook

copd$cancer[copd$cancer==7 |copd$cancer==9]<-NA # re-coding missing 
copd$cancer[copd$cancer==2]<-0 # re-coding to 0/1 format
copd$cancer<-factor(copd$cancer, 
                    levels=0:1, 
                    labels=c("No", "Yes")) # re-coding according to codebook

copd$arthritis[copd$arthritis==2]<-0 # re-coding to 0/1 format
copd$arthritis<-factor(copd$arthritis, 
                       levels=0:1,
                       labels=c("No", "Yes")) # re-coding according to codebook

copd$ckd[copd$ckd==7|copd$ckd==9]<-NA # re-coding refused or unsure as NAs
copd$ckd[copd$ckd==2]<-0
copd$ckd<-factor(copd$ckd, 
                 levels=0:1, 
                 labels=c("No", "Yes")) #re-coding according to codebook

copd$diabetes[copd$diabetes==2|copd$diabetes==3|copd$diabetes==4]<-0 # re-coding gestational, borderline and no as 0/1 variable
copd$diabetes[copd$diabetes==7]<-NA # re-coding NA
copd$diabetes<-factor(copd$diabetes, 
                      levels=0:1, 
                      labels=c("No", "Yes")) # re-coding according to codebook

copd$smoking_100[copd$smoking_100==7|copd$smoking_100==9]<-NA # re-coding NA
copd$smoking_100[copd$smoking_100==2]<-0 # re-coding as 0/1
copd$smoking_100<-factor(copd$smoking_100, 
                         levels=0:1,
                         labels=c("No", "Yes"))

copd$drinking_any[copd$drinking_any==999|copd$drinking_any==777]<-NA
copd$drinking_any[copd$drinking_any==888]<-0 # re-coding as 0/1
copd$drinking_any[copd$drinking_any>0]<-1 # recoding as 0/1
copd$drinking_any<-factor(copd$drinking_any, 
                          levels=0:1, 
                          labels=c("No", "Yes"))

copd$op_any[copd$op_any==7|copd$op_any==9]<-NA # re-coding missing data
copd$op_any[copd$op_any==2]<-0 # re coding to 0/1 format
copd$op_any<-factor(copd$op_any, 
                      levels=0:1, 
                      labels = c("No", "Yes")) # this variable stays in 1/2 format to fit in epi.2by2() function

copd$urban[copd$urban==2]<-0
copd$urban<-factor(copd$urban, 
                   levels=0:1, 
                   labels = c("Rural", "Urban"))

copd$depressive[copd$depressive==7|copd$depressive==9]<-NA # re-coding refused or unsure as NA
copd$depressive[copd$depressive==2]<-0 # recoding to 0/1 format
copd$depressive<-factor(copd$depressive, 
                        levels = 0:1, 
                        labels= c("No", "Yes")) # this variable stays in 1/2 format to fit in epi.2by2() function

table(copd$depressive, copd$op_any, deparse.level = 2, useNA = 'always')

copd$general_health[copd$general_health==7|copd$general_health==9]<-NA
copd$general_health<-copd$general_health-1
copd$general_health<-factor(copd$general_health, 
                            levels=0:4, 
                            labels=c("Excellent", "Very good", "Good", 
                                     "Fair", "Poor"))

copd$any_chronic[copd$diabetes=="No"& copd$cancer=="No" & copd$arthritis=="No" & copd$ckd=="No"&
                   copd$coronary_mi=="No" & copd$stroke=="No"]<-0 # if all are negative, the any_chronic is 0

copd$any_chronic[copd$diabetes=="Yes" | copd$cancer=="Yes" | copd$arthritis=="Yes" | copd$ckd=="Yes" |
                   copd$coronary_mi=="Yes" | copd$stroke=="Yes"]<-1 # if any of the variables is positive, the any_comorb is positive

copd$any_chronic<-factor(copd$any_chronic, 
                         levels=0:1, 
                         labels=c("No", "Yes"))

copd$phys_health[copd$phys_health==99|copd$phys_health==77]<-NA # re-coding NA
copd$phys_health[copd$phys_health==77]<-0 # formating from 0 to 30

copd$ment_health[copd$ment_health==99|copd$ment_health==77]<-NA # re-coding NA
copd$ment_health[copd$ment_health==88]<-0 # formating from 0 to 30

copd$copd<-NULL

copd$ment_binary[copd$ment_14=="1 to 13 days"|copd$ment_14=="Zero days"]<-0
copd$ment_binary[copd$ment_14=="14 or more days"]<-1

# to run poisson later, we create some variables that will be used for analysis
copd$op_numeric[copd$op_any=="No"]<-0
copd$op_numeric[copd$op_any=="Yes"]<-1

copd$depressive_numeric[copd$depressive=="No"]<-0
copd$depressive_numeric[copd$depressive=="Yes"]<-1

copd$rural[copd$urban=="Urban"]<-0
copd$rural[copd$urban=="Rural"]<-1

# 3. Preparing for analysis: creating dataset with extreme case scenarios ----
most<-copd
least<-copd

# most conservative scenario: here the patients with missing data on opioid use
# and depressive disorders present, are considered as not having the outcome. Conversely, 
# patients with missing data on opioids and no depressive disorders are considered having the outcome
most$op_numeric[most$depressive_numeric==1 & is.na(most$op_numeric)==TRUE]<-0
most$op_numeric[most$depressive_numeric==0 & is.na(most$op_numeric)==TRUE]<-1

most<-most[!is.na(most$depressive)==T,]

least$op_numeric[least$depressive_numeric==1 & is.na(least$op_numeric)==TRUE]<-1
least$op_numeric[least$depressive_numeric==0 & is.na(least$op_numeric)==TRUE]<-0

copd<-copd[!is.na(copd$depressive)==T & !is.na(copd$op_any)==T,] # keeping observations without missing data for main exposure and outcome. 

# 4. creating table 1
# table_one<-table1(~age+race+male+income_cat+urban+coronary_mi+stroke+cancer+arthritis+
#                    diabetes+ckd+smoking_100+drinking_any+phys_14+ment_14+any_chronic|depressive, data=copd)
# table_one

# income has >5% of missing data. so we create a variable with missing as a category
copd$income_na<-as.numeric(copd$income_cat) # creating new var as numeric
copd$income_na[is.na(copd$income_na)==TRUE]<-9 # replacing missing as 9 category to be weighted later

# 4. Data weighting: Weighting prevalences and estimating proportions ----
options(survey.lonely.psu = 'adjust') # survey design features. 

svy_design<-svydesign(data=copd, 
                      id= ~1, strata= ~ststr_year, weights = ~llcpwt, 
                      nest=TRUE) # setting survey design

design_most<-svydesign(data=most, 
                        id=~1, strata= ~ststr_year, weights= ~llcpwt, 
                        nest=TRUE)

design_least<-svydesign(data=least, 
                       id=~1, strata= ~ststr_year, weights= ~llcpwt, 
                       nest=TRUE)


# to obtain weighted %, we use a loop function:
# this for loop function runs the function svytable across the columns of interest. 
for (i in names(copd[,c(1:4,6:16,19,21:22)])){ # selecting columns of interest to run the loop
  print(i) # points the name of the variable that is being addressed
  formula_str<-paste("~depressive+", i) # First, we create a string object to merge with the name of the column
  formula_obj<-as.formula(formula_str) # to svytable() to work, we need to convert the strings in formulas/objects
  print(
    prop.table(
      svytable(formula_obj, design = svy_design),  # running function of interest
      margin=1) 
  )
  rm(formula_str, formula_obj,i) # removing objects created.
}

# separate procedure for income categories including NAs. 
prop.table(svytable(~depressive+income_na,design=svy_design), margin=1) # Weighted % to be used in the table 1. 
prop.table(svytable(~income_na,design=svy_design)) # Weighted % to be used in the table 1. 
prop.table(svytable(~rural+op_any,design=svy_design)) # Weighted % to be used in the table 1. 

rm(table_one)
# 5. Data analysis: main analysis and sensitivity analyses ----
# storing results in a object type "list"
results<-list()

# a. crude. ----
# to run poisson, we must convert some variables to numeric back again: 
results$models$poisson_crude <- svyglm(op_numeric~depressive_numeric,
                                       family=poisson, design = svy_design)

results$pr$crude<-exp(cbind(coef(results$models$poisson_crude), 
                            coefci(results$models$poisson_crude)))

# b. main analysis: adjusted fully ----
results$models$poisson_adj <- svyglm(op_numeric~depressive_numeric+factor(male)+age+
                                       factor(stroke)+ factor(rural)+
                                       factor(coronary_mi)+phys_health+ment_health+
                                       factor(cancer)+factor(arthritis)+factor(ckd)+factor(diabetes)+
                                       factor(smoking_100)+factor(drinking_any),
                                       family=poisson, design = svy_design)

results$pr$poisson_adj<-exp(cbind(coef(results$models$poisson_adj), 
                                  coefci(results$models$poisson_adj)))

# c. interaction models ----
results$models$int_rural <- svyglm(op_numeric~depressive_numeric*rural+factor(male)+age+
                                     factor(stroke)+
                                     factor(coronary_mi)+phys_health+ment_health+
                                     factor(cancer)+factor(arthritis)+factor(ckd)+factor(diabetes)+
                                     factor(smoking_100)+factor(drinking_any),
                                     family=poisson, design = svy_design)

stratum<-data.frame(exp(svycontrast(results$models$int_rural, contrasts=c(0,1,0,0,0,
                                                                          0,0,0,0,0,
                                                                          0,0,0,0,0,
                                                                          1)) # rural stratum-specific PR for depressive-opioid
))

results$pr$int_rural_rural<-cbind(stratum[,1], 
                                  stratum[,1]-1.96*stratum[,2], 
                                  stratum[,1]+1.96*stratum[,2]) # gettin 95% CI with SE used.

# for urban
stratum<-data.frame(exp(svycontrast(results$models$int_rural, contrasts=c(0,1,0,0,0,
                                                                          0,0,0,0,0,
                                                                          0,0,0,0,0,
                                                                          0)) # urban stratum-specific PR for depressive-opioid
))

results$pr$int_rural_urban<-cbind(stratum[,1], 
                                  stratum[,1]-1.96*stratum[,2], 
                                  stratum[,1]+1.96*stratum[,2])

# Interaction model with 14+ days of mental health. 

results$models$int_mental <- svyglm(op_numeric~depressive_numeric*ment_binary+factor(male)+age+
                                     factor(stroke)+factor(rural)+
                                     factor(coronary_mi)+phys_health+
                                     factor(cancer)+factor(arthritis)+factor(ckd)+factor(diabetes)+
                                     factor(smoking_100)+factor(drinking_any),
                                     family=poisson, design = svy_design)

stratum<-data.frame(exp(svycontrast(results$models$int_mental, contrasts=c(0,1,0,0,0,
                                                                          0,0,0,0,0,
                                                                          0,0,0,0,0,
                                                                          0)) # individuals with zero to 13 days of poor ment health
))

results$pr$int_mental_zero<-cbind(stratum[,1], 
                                  stratum[,1]-1.96*stratum[,2], 
                                  stratum[,1]+1.96*stratum[,2])

stratum<-data.frame(exp(svycontrast(results$models$int_mental, contrasts=c(0,1,0,0,0,
                                                                           0,0,0,0,0,
                                                                           0,0,0,0,0,
                                                                           1)) # individuals with 14+ days of poor ment health
))

results$pr$int_mental_14plus<-cbind(stratum[,1], 
                                  stratum[,1]-1.96*stratum[,2], 
                                  stratum[,1]+1.96*stratum[,2])

# d. sensitivity analyses: least and most----
# least scenario
results$models$poisson_least <- svyglm(op_numeric~depressive_numeric+factor(male)+age+
                                       factor(stroke)+ factor(rural)+
                                       factor(coronary_mi)+phys_health+ment_health+
                                       factor(cancer)+factor(arthritis)+factor(ckd)+factor(diabetes)+
                                       factor(smoking_100)+factor(drinking_any),
                                       family=poisson, design = design_least)

results$pr$poisson_least<-exp(cbind(coef(results$models$poisson_least), 
                                  coefci(results$models$poisson_least)))

# most scenario
results$models$poisson_most <- svyglm(op_numeric~depressive_numeric+factor(male)+age+
                                         factor(stroke)+ factor(rural)+
                                         factor(coronary_mi)+phys_health+ment_health+
                                         factor(cancer)+factor(arthritis)+factor(ckd)+factor(diabetes)+
                                         factor(smoking_100)+factor(drinking_any),
                                         family=poisson, design = design_most)

results$pr$poisson_most<-exp(cbind(coef(results$models$poisson_most), 
                                    coefci(results$models$poisson_most)))