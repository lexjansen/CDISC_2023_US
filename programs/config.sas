%if %symexist(_debug)=0 %then %do;
  %global _debug;
  %let _debug=0;
%end;  

options sasautos = ("&project_folder/macros", "/library/sas", %sysfunc(compress(%sysfunc(getoption(sasautos)),%str(%(%)))));

%* This file contains the credentials;
%*let credentials_file=&project_folder/programs/credentials.cfg;

%*read_config_file(
  config_file=&credentials_file, 
  sections=%str("cdisclibrary")
);

%read_config_file(
  config_file=%sysget(CREDENTIALS_FILE), 
  sections=%str("cdisclibrary")
);

%let env=prod;  
%let api_key=&&cdisc_api_&env._key;
%let base_url=https://library.cdisc.org/api;
%let base_url_cosmos=https://library.cdisc.org/api/cosmos/v2;


%let rest_debug=%str(OUTPUT_TEXT NO_REQUEST_HEADERS NO_REQUEST_BODY RESPONSE_HEADERS NO_RESPONSE_BODY);

libname data "&project_folder/data";
libname metadata "&project_folder/metadata";

