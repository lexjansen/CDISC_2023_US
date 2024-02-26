%global project_folder;
%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;
%* Generic configuration;
%include "&project_folder/programs/config.sas";

%let domains="RS" "TR" "TU";
%let tables="RS" "TR" "TU";

*******************************************************************************;
* Create VLM metadata                                                         *;
*******************************************************************************;

proc sql noprint;
  select max(wc) into :max_whereclauses separated by ' '
  	from (select sum(not missing(comparator)) as wc
            from data.sdtm_specializations
            group by datasetSpecializationId
          );
quit;

%put &=max_whereclauses;

data whereclause(keep=datasetSpecializationId domain _whereclause:);
  array whereclause{&max_whereclauses} $ 1024 _whereclause1 - _whereclause&max_whereclauses;
  retain _whereclause: j max;
  set data.sdtm_specializations(where=(domain in (&domains))) end=end;
  by datasetSpecializationId notsorted;
  if first.datasetSpecializationId then do;
    do i=1 to dim(whereclause); whereclause(i) = ""; end;
    j = 1;
  end;
  if comparator = "EQ" then do;
    whereclause(j) = catx(" ", name, comparator, cats('"', assigned_value, '"'));
    j = j + 1;
  end;
  if comparator = "IN" then do;
    whereclause(j) = catx(" ", name, comparator, cats('("', tranwrd(value_list, ";", '","'), '")'));
    j = j + 1;
  end;
  if last.datasetSpecializationId then do;
    if j > max then max = j;
    put datasetSpecializationId @30 @;
    do i=1 to dim(whereclause); if (not missing(whereclause(i))) then put @20 whereclause(i)=; end;
    output whereclause;
  end;
run;

proc sort data=whereclause;
  by domain datasetSpecializationId;
run;

ods listing close;
ods html5 file="&project_folder/programs/03_create_vlm_from_sdtm_specializations.html";

  proc print data=whereclause;
    var domain datasetSpecializationId _whereclause:;
  run;

ods html5 close;
ods listing;



data sdtm_specializations(drop = vlmTarget shortName);
  retain datasetSpecializationId domain name shortName;
  length label $ 200;
  set data.sdtm_specializations(
    where = ((vlmTarget = 1) and domain in (&domains))
    keep = datasetSpecializationId domain shortName name codelist codelist_submission_value subsetcodelist
           value_list assigned_term assigned_value role datatype length format significantdigits
           origintype originsource mandatoryValue vlmTarget

    );
    label = shortName;
    rename domain=table name=column format=displayformat datatype=xmldatatype codelist_submission_value=xmlcodelist;
run;


%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.1,
  _cstType=studymetadata,_cstSubType=value,_cstOutputDS=work.source_values_template
  );

 data sdtm_specializations(drop=mandatoryValue);
   set work.source_values_template sdtm_specializations;
   if mandatoryValue then mandatory="Yes";
                      else mandatory="No";
 run;

proc sql;
  create table source_values as
  select
    sdtm.*,
    col.xmldatatype as parent_xmldatatype,
    col.length as parent_length,
    wc._whereclause1,
    wc._whereclause2,
    wc._whereclause3,
    wc._whereclause4
  from sdtm_specializations sdtm
    left join whereclause wc
  on (sdtm.table = wc.domain and sdtm.datasetSpecializationId = wc.datasetSpecializationId)
    left join metadata.source_columns col
  on (sdtm.table = col.table and sdtm.column = col.column)
  order by table, column, datasetSpecializationId
  ;
quit;

data source_values(drop = datasetSpecializationId codelist subsetcodelist value_list assigned_term assigned_value _whereclause:);
  set source_values;

   whereclause = cats("(", _whereclause1, ")");
   name = datasetSpecializationId;  

  if table in (&tables) then do;

    if (not missing(_whereclause2)) then do;
      whereclause = catx(' ', whereclause, 'AND',  cats("(", _whereclause2, ")"));
      name = "";
    end;
    if (not missing(_whereclause3)) then do;
      whereclause = catx(' ', whereclause, 'AND',  cats("(", _whereclause3, ")"));
      name = "";
    end;
    if (not missing(_whereclause4)) then do;
      whereclause = catx(' ', whereclause, 'AND',  cats("(", _whereclause4, ")"));
      name = "";
    end;

  end;

  /* Assign codelists */
  if (not missing(xmlcodelist)) and (not missing(assigned_value)) and prxmatch('/.*ORRES$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_OR_", datasetSpecializationId);
  if (not missing(xmlcodelist)) and (not missing(value_list)) and prxmatch('/.*ORRES$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_OR_", datasetSpecializationId);

  if (not missing(xmlcodelist)) and (not missing(assigned_value)) and prxmatch('/.*ORRESU$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_ORU_", datasetSpecializationId);
  if (not missing(xmlcodelist)) and (not missing(value_list)) and prxmatch('/.*ORRESU$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_ORU_", datasetSpecializationId);

  if (not missing(xmlcodelist)) and (not missing(assigned_value)) and prxmatch('/.*STRESC$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_STC_", datasetSpecializationId);
  if (not missing(xmlcodelist)) and (not missing(value_list)) and prxmatch('/.*STRESC$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_STC_", datasetSpecializationId);

  if (not missing(xmlcodelist)) and (not missing(assigned_value)) and prxmatch('/.*STRESU$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_STU_", datasetSpecializationId);
  if (not missing(xmlcodelist)) and (not missing(value_list)) and prxmatch('/.*STRESU$/i',strip(column))
    then xmlcodelist = cats(xmlcodelist, "_STU_", datasetSpecializationId);

  if (not missing(value_list)) and (not missing(subsetcodelist)) then xmlcodelist = subsetcodelist;
run;

%let _cstStudyVersion=;
%let _cstStandard=;
%let _cstStandardVersion=;
proc sql noprint;
 select StudyVersion, Standard, StandardVersion into :_cstStudyVersion, :_cstStandard, :_cstStandardVersion separated by ', '
 from metadata.source_study;
quit;

data data.source_values_sdtm(drop=parent_xmldatatype parent_length label="Source Value Metadata");
  set source_values;
  by table column notsorted;
  order = _n_;
  sasref="SRCDATA";
  studyversion="&_cstStudyVersion";
  standard="&_cstStandard";
  standardversion="&_cstStandardVersion";
  if missing(xmldatatype) then xmldatatype=parent_xmldatatype;
  if missing(length) and xmldatatype="text" then length=parent_length;
run;

ods listing close;
ods html5 file="&project_folder/data/source_values_sdtm.html";
ods excel file="&project_folder/data/source_values_sdtm.xlsx" options(sheet_name="VLM" flow="tables" autofilter = 'all');

  proc print data=data.source_values_sdtm;
  run;

ods excel close;
ods html5 close;
ods listing;
