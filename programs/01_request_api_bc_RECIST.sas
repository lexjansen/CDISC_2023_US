%global project_folder;
%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;
%let subfolder=json;

%* Generic configuration;
%include "&project_folder/programs/config.sas";

%macro get_bc_by_category(category);
  
  filename jsonfile "&project_folder/&subfolder/biomedical_concepts_latest_%lowcase(&category).json";

  %get_api_response(
      baseurl=&base_url_cosmos,
      endpoint=/mdr/bc/biomedicalconcepts?category=&category,
      response_fileref=jsonfile
    );
    
  filename mapfile "%sysfunc(pathname(work))/api.map";
  libname jsonfile json map=mapfile automap=create fileref=jsonfile noalldata ordinalcount=none;

  data _null_;
    set jsonfile._links_biomedicalconcepts;
    length code $4096 response_file $1024 conceptId $64;
    baseurl="&base_url_cosmos";
    conceptId = scan(href, -1, "\/");
    response_file=cats("&project_folder/json/bc/", conceptId, ".json");
    response_file=lowcase(response_file);
    code=cats('%get_api_response(baseurl=', baseurl, ', endpoint=', href, ', response_file=', response_file, ');');
    call execute (code);
  run;

  filename jsonfile clear;
  libname jsonfile clear;
  filename mapfile clear;

%mend get_bc_by_category;

%get_bc_by_category(RECIST 1.1);

%put %sysfunc(dcreate(jsontmp, %sysfunc(pathname(work))));
libname jsontmp "%sysfunc(pathname(work))/jsontmp";

%create_template(type=bc, out=work.bc__template);

data _null_;
  length fref $8 name $64 jsonpath $200 code $400;
  did = filename(fref,"&project_folder/json/bc");
  did = dopen(fref);
  if did ne 0 then do;
    do i = 1 to dnum(did);
      if index(dread(did,i), "json") then do;
        name=scan(dread(did,i), 1, ".");
        jsonpath=cats("&project_folder/json/bc/", name, ".json");
        code=cats('%nrstr(%read_bc_from_json(',
                            'json_path=', jsonpath, ', ',
                            'out=work.bc__', name, ', ', 
                            'jsonlib=jsontmp, ',
                            'template=work.bc__template',
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
data work.biomedical_concepts;
  set work.bc_:;
run;
/*********************************************************************************************************************/
/*********************************************************************************************************************/

proc sort data=biomedical_concepts out=data.biomedical_concepts;
  by conceptId;
run;  

ods listing close;
ods html5 file="&project_folder/data/biomedical_concepts.html";
ods excel options(sheet_name="Bomedical_Concepts" flow="tables" autofilter = 'all') file="&project_folder/data/biomedical_concepts.xlsx";

  proc report data=biomedical_concepts;
    title "Bomedical Concepts (generated on %sysfunc(datetime(), is8601dt.))";
    columns packageDate categories href conceptId ncitCode parentConceptId shortName synonyms resultScales definition system systemName code
            dec_href dec_ConceptId dec_ncitCode dec_ShortName dec_dataType dec_exampleSet;
    
    define href / noprint; 
    define dec_href / noprint;
               
    compute ncitCode;
      if not missing(ncitCode) then do;
        call define (_col_, 'url', href);
        call define (_col_, "style","style={textdecoration=underline color=#0000FF}");
      end;  
    endcomp;

    compute dec_ncitCode;
      if not missing(dec_ncitCode) then do;
        call define (_col_, 'url', dec_href);
        call define (_col_, "style","style={textdecoration=underline color=#0000FF}");
      end;  
    endcomp;

    compute parentConceptId;
      if not missing(parentConceptId) then do;
        call define (_col_, 'url', cats('https://ncithesaurus.nci.nih.gov/ncitbrowser/ConceptReport.jsp?dictionary=NCI_Thesaurus&ns=ncit&code=', parentConceptId));
        call define (_col_, "style","style={textdecoration=underline color=#0000FF}");
      end;  
    endcomp;

  run;  

ods html5 close;
ods excel close;
ods listing;
