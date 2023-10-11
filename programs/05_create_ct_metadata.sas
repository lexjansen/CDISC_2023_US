%global project_folder;
%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;
%* Generic configuration;
%include "&project_folder/programs/config.sas";

%let domains="RS" "TR" "TU";

*******************************************************************************;
* Create CT metadata                                                          *;
*******************************************************************************;

data sdtm_specializations_ct(drop=i countwords);
  length term $100;
  set data.sdtm_specializations(
    keep=datasetSpecializationId shortname vlmTarget domain name codelist codelist_submission_value subsetcodelist value_list assigned_term assigned_value
    where=((domain in (&domains)) and (not missing(codelist)))
    );
  if not missing(value_list) then do;
    countwords=countw(value_list, ";");
    do i=1 to countwords;
      term=strip(scan(value_list, i, ";"));
      if not missing(term) then output;
    end;
  end;
  else do;
    term  = assigned_value;
    output;
  end;  
run;  

proc sort data=sdtm_specializations_ct;
  by codelist;
run;
  
data sdtm_specializations_ct;
  set sdtm_specializations_ct;
  length xmlcodelist $200;
  /* Assign codelists */

  xmlcodelist = codelist_submission_value;
  if (not missing(codelist_submission_value)) and (not missing(assigned_value)) and prxmatch('/.*ORRES$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_OR_", datasetSpecializationId);
  if (not missing(codelist_submission_value)) and (not missing(value_list)) and prxmatch('/.*ORRES$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_OR_", datasetSpecializationId);

  if (not missing(codelist_submission_value)) and (not missing(assigned_value)) and prxmatch('/.*ORRESU$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_ORU_", datasetSpecializationId);
  if (not missing(codelist_submission_value)) and (not missing(value_list)) and prxmatch('/.*ORRESU$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_ORU_", datasetSpecializationId);

  if (not missing(codelist_submission_value)) and (not missing(assigned_value)) and prxmatch('/.*STRESC$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_STC_", datasetSpecializationId);
  if (not missing(codelist_submission_value)) and (not missing(value_list)) and prxmatch('/.*STRESC$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_STC_", datasetSpecializationId);

  if (not missing(codelist_submission_value)) and (not missing(assigned_value)) and prxmatch('/.*STRESU$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_STU_", datasetSpecializationId);
  if (not missing(codelist_submission_value)) and (not missing(value_list)) and prxmatch('/.*STRESU$/i',strip(name))
    then xmlcodelist = cats(codelist_submission_value, "_STU_", datasetSpecializationId);

  if (not missing(value_list)) and (not missing(subsetcodelist)) then do;
    output;
    xmlcodelist = subsetcodelist;
  end;  

  output;  
/*
  if (not missing(codelist_submission_value)) and (not missing(value_list)) and name in ("VSORRES" "LBORRES")
    then xmlcodelist = cats(codelist_submission_value, "_OR_", datasetSpecializationId);
  if (not missing(codelist_submission_value)) and (not missing(value_list)) and name in ("VSSTRESC" "LBSTRESC")
    then xmlcodelist = cats(codelist_submission_value, "_ST_", datasetSpecializationId);
*/
run;

ods listing close;
ods html5 file="&project_folder/programs/05_create_ct_metadata.html";
ods excel file="&project_folder/programs/05_create_ct_metadata.xlsx" options(sheet_name="CT" flow="tables" autofilter = 'all');

  proc print data=sdtm_specializations_ct;
  var domain datasetSpecializationId name codelist codelist_submission_value xmlcodelist subsetcodelist term assigned_term assigned_value value_list;
  run;

ods excel close;
ods html5 close;
ods listing;

proc sort data=sdtm_specializations_ct;
  by codelist xmlcodelist term;
run;  
  

proc sql;
  create table work.source_codelists_sdtm as
  select 
      sdtm_ct.*,
      ct_vlm.xmlcodelist as xmlcodelist__,
      ct_vlm.term as term__,
      ct_vlm.shortname,
      ct_vlm.subsetcodelist,
      ct_vlm.name as column,
      ct_vlm.datasetSpecializationId      
  from data.sdtm_ct sdtm_ct, sdtm_specializations_ct ct_vlm
  where (sdtm_ct.codelistncicode = ct_vlm.codelist) and 
        (not missing(ct_vlm.xmlcodelist)) and
        ((sdtm_ct.codedvaluechar = ct_vlm.term) or (sdtm_ct.codedvaluencicode = ct_vlm.assigned_term) or (missing(ct_vlm.term) and missing (ct_vlm.assigned_term))) 
  ;
quit;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.1,
  _cstType=studymetadata,_cstSubType=codelist,_cstOutputDS=work.source_codelist_template
  );

%let _cstStudyVersion=;
%let _cstStandard=;
%let _cstStandardVersion=;
proc sql noprint;
 select StudyVersion, Standard, StandardVersion into :_cstStudyVersion, :_cstStandard, :_cstStandardVersion separated by ', '
 from metadata.source_study;
quit;

data work.source_codelists_sdtm(drop=datasetSpecializationId column shortname subsetcodelist code_synonym term__);
  length codelistname $ 200;
  set work.source_codelist_template work.source_codelists_sdtm(drop=codelist rename=(xmlcodelist__=codelist));
  sasref="SRCDATA";
  studyversion="&_cstStudyVersion";
  standard="&_cstStandard";
  standardversion="&_cstStandardVersion";
  codelistdatatype="text";
  if index(codelist, '_ORU_') or index(column, "ORRESU") then codelistname = catx(' ', cats(codelistname, ","),  "subset for", shortname, "-", "Original");
  if index(codelist, '_STU_') or index(column, "STRESU") then codelistname = catx(' ', cats(codelistname, ","),  "subset for", shortname, "-", "Standardized");
  
  if index(codelist, '_OR_') or (index(column, "ORRES") and index(column, "ORRESU")=0 )then codelistname = catx(' ', cats(codelistname, ","),  "subset for", shortname, "-", "Original (Res)");
  if index(codelist, '_STC_') or index(column, "STRESC") then codelistname = catx(' ', cats(codelistname, ","),  "subset for", shortname, "-", "Standardized (Char Res)");

  decodetext="";
  if index(codelist, "TESTCD") or index(codelist, "ONCRTSCD") or index(codelist, "NY") or index(codelist, "ONCRSR")
     then do;
      if not missing(code_synonym) then do;
        if index(code_synonym, ";")=0 then decodetext = code_synonym;
      end;  
      if missing(decodetext) and (not missing(preferredterm)) then decodetext = preferredterm;
      if missing(decodetext) then decodetext = codedvaluechar;
    end;
    else decodetext="";

  if index(codelistname, "subset")=0 and not missing(term__) then codelistname = catx(' ', cats(codelistname, ","), "subset");
run;

proc sort data=work.source_codelists_sdtm out=data.source_codelists_sdtm(label="Source Codelist Metadata") NODUPRECS;
  by _ALL_;
run;  

ods listing close;
ods html5 file="&project_folder/data/source_codelists_sdtm.html";
ods excel file="&project_folder/data/source_codelists_sdtm.xlsx" options(sheet_name="CT" flow="tables" autofilter = 'all');

  proc print data=data.source_codelists_sdtm;
  run;  
  
ods excel close;
ods html5 close;
ods listing;



data col_ct(keep=xmlcodelist);
  set metadata.source_columns(where=(not missing(xmlcodelist)));
run;
proc sort data=col_ct nodupkey;
  by xmlcodelist;
run;  

proc sql noprint;
  select t1.xmlcodelist into :xmlcodelists separated by '" "'
  from work.col_ct t1 
    left join data.source_codelists_sdtm t2
    on t1.xmlcodelist = t2.codelist
    where missing(t2.codelist)
  ;
quit;   

%put xmlcodelists = "&xmlcodelists";

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.1,
  _cstType=studymetadata,_cstSubType=codelist,_cstOutputDS=work.source_codelists_template
  );

data metadata.source_codelists(drop=code_synonym);
  length codelistname $ 200;
  set work.source_codelists_template 
      data.sdtm_ct(where=(codelist in ("&xmlcodelists")));
  sasref="SRCDATA";
  studyversion="&_cstStudyVersion";
  standard="&_cstStandard";
  standardversion="&_cstStandardVersion";
  codelistdatatype="text";
run;
  