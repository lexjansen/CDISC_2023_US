%global project_folder;
%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;
%let subfolder=json;

%* Generic configuration;
%include "&project_folder/programs/config.sas";

%macro get_sdtm_specs_by_domain(domain);
  
  filename jsonfile "&project_folder/&subfolder/datasetspecialization_latest_%lowcase(&domain).json";

  %get_api_response(
      baseurl=&base_url_cosmos,
      endpoint=/mdr/specializations/sdtm/datasetspecializations?domain=&domain,
      response_fileref=jsonfile
    );
    
  filename mapfile "%sysfunc(pathname(work))/package.map";
  libname jsonfile json map=mapfile automap=create fileref=jsonfile noalldata ordinalcount=none;

  data _null_;
    set jsonfile._links_datasetspecializations;
    length code $4096 response_file $1024 datasetSpecializationId $64;
    baseurl="&base_url_cosmos";
    datasetSpecializationId = scan(href, -1, "\/");
    response_file=cats("&project_folder/json/sdtm/", datasetSpecializationId, ".json");
    response_file=lowcase(response_file);
    code=cats('%get_api_response(baseurl=', baseurl, ', endpoint=', href, ', response_file=', response_file, ');');
    call execute (code);
  run;

  filename jsonfile clear;
  libname jsonfile clear;
  filename mapfile clear;

%mend get_sdtm_specs_by_domain;

%get_sdtm_specs_by_domain(RS);
%get_sdtm_specs_by_domain(TR);
%get_sdtm_specs_by_domain(TU);

%put %sysfunc(dcreate(jsontmp, %sysfunc(pathname(work))));
libname jsontmp "%sysfunc(pathname(work))/jsontmp";

%create_template(type=sdtm, out=work.sdtm__template);

data _null_;
  length fref $8 name name_short $64 jsonpath $200 code $400;
  did = filename(fref,"&project_folder/json/sdtm");
  did = dopen(fref);
  if did ne 0 then do;
    do i = 1 to dnum(did);
      if index(dread(did,i), "json") then do;
        name=scan(dread(did,i), 1, ".");
        jsonpath=cats("&project_folder/json/sdtm/", name, ".json");
        name_short = name;
        if length(name_short) gt 22 then name_short = substr(name, 1, 22);
        code=cats('%nrstr(%read_sdtm_from_json(',
                            'json_path=', jsonpath, ', ',
                            'out=work.sdtm__', name_short, ', ', 
                            'jsonlib=jsontmp, ',
                            'template=work.sdtm__template',
                          ');)');
        call execute(code);
      end;
    end;
  end;
  did = dclose(did);
  did = filename(fref);
run;

libname jsontmp clear;

/*********************************************************************************************************************/
/* fix some issues                                                                                                   */
/*********************************************************************************************************************/
data work.sdtm_specializations;
  set work.sdtm__:;
  
  /* xxTEST variables shoukd not be used in the whereclauses */
  if length(name) >= 4 and substr(name, length(name)-3, 4) = "TEST" and (not missing(comparator)) then do;
    putlog 'WAR' 'NING: ' datasetSpecializationId= name= comparator=;
    comparator="";
  end;  
  
  /* Variables should only be used in an EQ whereclause whwn they have an asssigned_value */
  if (not missing(comparator)) and comparator = "EQ" and missing(assigned_value) then do;
    putlog 'WAR' 'NING: ' datasetSpecializationId= name= comparator= assigned_value=;
    comparator="";    
  end;
  /* Variables should only be used in an IN whereclause whwn they have an value_list */
  if (not missing(comparator)) and comparator = "IN" and missing(value_list) then do;
    putlog 'WAR' 'NING: ' datasetSpecializationId= name= comparator= value_list=;
    comparator="";
  end;
  /* Variables should be used either in a whereclause or be a VLM target */
  if (not missing(comparator)) and (not missing(vlmTarget)) then do;
    putlog 'WAR' 'NING: ' datasetSpecializationId= name= comparator= vlmTarget=;
  end;
  
run;
/*********************************************************************************************************************/
/*********************************************************************************************************************/

proc sort data=sdtm_specializations out=data.sdtm_specializations;
  by datasetSpecializationId;
  /* where name ne 'EPOCH'; */
run;  

ods listing close;
ods html5 file="&project_folder/data/sdtm_specializations.html";
ods excel options(sheet_name="SDTM_DatasetSpecializations" flow="tables" autofilter = 'all') file="&project_folder/data/sdtm_specializations.xlsx";

  title "SDTM Specializations (generated on %sysfunc(datetime(), is8601dt.))";
  proc report data=data.sdtm_specializations;
    columns packageDate biomedicalConceptId dataElementConceptId sdtmigStartVersion sdtmigEndVersion domain source datasetSpecializationId
            shortName name isNonStandard codelist_href codelist codelist_submission_value subsetCodelist
            value_list assigned_term assigned_value role subject linkingPhrase predicateTerm object 
            dataType length format significantDigits mandatoryVariable mandatoryValue originType originSource comparator vlmTarget;
    
    define codelist_href / noprint; 
               
    compute dataElementConceptId;
      if not missing(dataElementConceptId) then do;
        call define (_col_, 'url', cats('https://ncithesaurus.nci.nih.gov/ncitbrowser/ConceptReport.jsp?dictionary=NCI_Thesaurus&ns=ncit&code=', dataElementConceptId));
        call define (_col_, "style","style={textdecoration=underline color=#0000FF}");
      end;  
    endcomp;

    compute codelist;
      if not missing(codelist) then do;
        call define (_col_, 'url', codelist_href);
        call define (_col_, "style","style={textdecoration=underline color=#0000FF}");
      end;  
    endcomp;
  run;

ods html5 close;
ods excel close;
ods listing;
