%if %symexist(_debug)=0 %then %do;
  %global _debug;
  %let _debug=0;
%end;  

options sasautos = ("&project_folder/macros", "/library/sas", %sysfunc(compress(%sysfunc(getoption(sasautos)),%str(%(%)))));


%* Get credentials from environment variables;
%let api_key_prod=%sysget(CDISC_LIBRARY_API_KEY);
%let api_key=%sysget(CDISC_LIBRARY_API_KEY_DEV);

%let base_url=https://library.cdisc.org/api;
%let base_url_cosmos=https://library.cdisc.org/api/cosmos/v2;
%let base_url_cosmos=https://dev.cdisclibrary.org/api/cosmos/v2;

%let rest_debug=%str(OUTPUT_TEXT NO_REQUEST_HEADERS NO_REQUEST_BODY RESPONSE_HEADERS NO_RESPONSE_BODY);

libname data "&project_folder/data";
libname metadata "&project_folder/metadata";

