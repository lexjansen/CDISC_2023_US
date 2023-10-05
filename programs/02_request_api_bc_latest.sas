%global project_folder;
%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;
%let subfolder=json;

%* Generic configuration;
%include "&project_folder/programs/config.sas";

filename jsonfile "&project_folder/&subfolder/biomedicalconcepts_latest.json";

%get_api_response(
    baseurl=&base_url_cosmos,
    endpoint=/mdr/bc/biomedicalconcepts,
    response_fileref=jsonfile
  );
  
filename mapfile "%sysfunc(pathname(work))/package.map";
libname jsonfile json map=mapfile automap=create fileref=jsonfile noalldata ordinalcount=none;

data _null_;
  set jsonfile._links_biomedicalconcepts;
  length code $4096 response_file $1024 biomedicalconceptId $64;
  baseurl="&base_url_cosmos";
  biomedicalconceptId = scan(href, -1, "\/");
  response_file=cats("&project_folder/json/bc/", biomedicalconceptId, ".json");
  response_file=lowcase(response_file);
  code=cats('%get_api_response(baseurl=', baseurl, ', endpoint=', href, ', response_file=', response_file, ');');
  call execute (code);
run;

filename jsonfile clear;
libname jsonfile clear;
filename mapfile clear;

%put %sysfunc(dcreate(jsontmp, %sysfunc(pathname(work))));
libname jsontmp "%sysfunc(pathname(work))/jsontmp";
* libname jsontmp "&project_folder/_temp";

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

data work.biomedical_concepts;
  set work.bc__:;
run;

proc sort data=biomedical_concepts out=data.biomedical_concepts;
  by conceptId order;
run;  

