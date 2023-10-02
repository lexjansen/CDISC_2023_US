%macro get_domain(domain=, version=);

  filename jsonf "&project_folder/json/clib/sdtmig_&version.-%lowcase(&domain).json";

  %if not %sysfunc(fileexist(%sysfunc(pathname(jsonf)))) %then %do;
    %get_api_response(
      baseurl=&base_url,
      endpoint=/mdr/sdtmig/&version/datasets/%upcase(&domain),
      response_fileref=jsonf
    );
  %end;

  filename mpfile "%sysfunc(pathname(work))/package.map";
  libname jsonf json map=mpfile automap=create fileref=jsonf noalldata;

  %put %sysfunc(dcreate(jsontmp, %sysfunc(pathname(work))));
  libname jsontmp "%sysfunc(pathname(work))/&domain";
  * libname jsontmp "&project_folder/&subfolder/data/%lowcase(&domain)";

  proc datasets library=jsontmp kill nolist;
  quit;

  proc copy in=jsonf out=jsontmp;
  run;

  filename jsonf clear;
  filename mpfile clear;
  libname jsonf clear;
  libname jsontmp clear;

%mend get_domain;


proc format;
  value $origtyp
   /* Maps from Define-XML v22 values to Define-XML v21 values */
   "CRF"="Collected"
   "eDT"="Collected"
   "COLLECTED" = "Collected"
   "DERIVED" = "Derived"
   "OTHER" = "Other"
   "NOT AVAILABLE" = "Not Available"
  ;
  value $origsrc
   "Derived" = "Sponsor"
   "Assigned" = "Sponsor"
   "Protocol" = "Sponsor"
   "Collected" = "Investigator"
   ;
run;

/*******************************************************************************/

%global project_folder;

%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;
%let subfolder=test;

%* Generic configuration;
%include "&project_folder/programs/config.sas";
options dlcreatedir;

%let _cstStandard=CDISC-DEFINE-XML;
%let _cstStandardVersion=2.1;
%let _cstTrgStandard=%str(CDISC-SDTM);
%let _cstTrgStandardVersion=3.3;
%let _cstCDISCStandardVersion = %sysfunc(translate(&_cstTrgStandardVersion, %str(-), %str(.)));
%let _cstStudyVersion=%str(MDV.CDISC01.SDTMIG.3.3.SDTM.1.7);


%let excel_file=&project_folder/resources/mdr_metadata.xlsx;
%ReadExcel(file=&excel_file, range=Datasets$, dsout=work.mdr_datasets);
%ReadExcel(file=&excel_file, range=Variables$, dsout=work.mdr_variables);


%let excel_file=&project_folder/resources/Non-Standard-SDTMIG.xls;
%ReadExcel(file=&excel_file, range=%str(NSVs$), dsout=work.nsv_metadata);

proc sort data=work.nsv_metadata;
  by domain variable Source_s_;
run;  

data work.nsv_metadata(
  rename=(Simple_Datatype=simpleDatatype Define_XML_Datatype=xmldatatype)
  where = (domain in ("RS" "TR" "TU"))
  );
  length variable $ 32;
  set work.nsv_metadata;
  by domain variable;
  if index(Codelist_Reference, "evs.nci.nih.gov") then codelist_ccode = scan(scan(Codelist_Reference, 2, '"'), -2, ".");
  if last.variable;
run;  

proc sql;
  create table work.source_columns_nsv as select
    t1.*,
    input(t3.length, best.) as length,
      t3.format as displayformat,
      input(t3.significant_digits, best.) as significantdigits,
    t3.mandatory length=3,
    put(t3.origin, $origtyp.) as origintype,
    t3.codelist as xmlcodelist_
  from 
    work.nsv_metadata t1, 
    data.sdtm_specializations t2,
    work.mdr_variables t3      
    where (t1.domain = t2.domain and t1.domain = t3.dataset and 
           t1.variable = t2.name and t1.variable = t3.variable and 
           t2.IsNonStandard = 1)
  ;  
quit;  

proc contents data=work.source_columns_nsv varnum;
run;  

ods listing close;
ods html5 file="&project_folder/programs/03_request_api_sdtm_domains.html";
proc print data=work.source_columns_nsv;
  var domain variable label Source_s_ role xmldatatype codelist_ccode;
run;
ods html5 close;
ods listing;

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=table,_cstOutputDS=metadata.source_tables
  );
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=column,_cstOutputDS=metadata.source_columns
  );

data work.source_columns_template;
  set metadata.source_columns;
run;  

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=value,_cstOutputDS=metadata.source_values
  );

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=codelist,_cstOutputDS=metadata.source_codelists
  );

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=document,_cstOutputDS=metadata.source_documents
  );



%macro add_domain(clib_domain=, order=, suppdomain=);

  %get_domain(domain=&clib_domain, version=&_cstCDISCStandardVersion);

  libname clib "%sysfunc(pathname(work))/&clib_domain";

  data mdr_datasets_&clib_domain(keep=dataset description class key_variables repeating reference_data);
    set mdr_datasets(where=(dataset=upcase("&clib_domain") or dataset=upcase("SUPP&suppdomain")));
  run;

  data mdr_variables_&clib_domain(keep=dataset variable label data_type length significant_digits format mandatory codelist origin role);
    set mdr_variables(where=(dataset=upcase("&clib_domain") or dataset=upcase("SUPP&suppdomain")));
  run;

  %if %sysfunc(exist(clib.datasetvariables_valuelist)) %then %do;
    data work.valuelists (keep=ordinal_datasetVariables _valueList rename=(_valuelist=valuelist));
      length _valueList $200;
      set clib.datasetvariables_valuelist;
      array c{*} valueList:;
      _valueList = c[1];
      x = dim(c);
      do i = 2 to dim(c);
        _valueList = cats(";", _valueList, c[i]);
      end;
    run;
  %end;
  %else %do;
    proc sql;
      create table work.valuelists
        (
         ordinal_datasetVariables num,
         valuelist char(200)
        );
    quit;
  %end;

  data work.root;
    length domain $32;
    set clib.root;
    domain=name;
    %if %sysevalf(%superq(suppdomain)=, boolean)=0 %then %do;
      name = "SUPP&suppdomain";
      domain="&suppdomain";
    %end;

  run;

  data work.datasetvariables;
    set clib.datasetvariables;
    %if %sysevalf(%superq(suppdomain)=, boolean)=0 %then %do;
    %end;
  run;


  proc sql;
    create table work.source_tables as select
      root.name as table,
      root.domain,
      root.label as label,
      mdrfull.description as domaindescription,
      /* root.description as table_description, */
      root.datasetStructure as structure,
      translate(mdr.key_variables, " ", ",") as keys length=200,
      mdr.class length=40,
      cats(lowcase(name), ".xpt") as xmlpath,
      cats(lowcase(name), ".xpt") as xmltitle,
      "Tabulation" as purpose,
      mdr.repeating length=3,
      mdr.reference_data as isReferenceData length=3
    from work.root root
      left join work.mdr_datasets_&clib_domain mdr
    on (root.name = mdr.dataset)
      left join work.mdr_datasets mdrfull
    on (mdrfull.dataset = "&suppdomain")
    ;
    create table work.source_columns as select
      root.name as table,
      t1.name as column,
      t1.label,
      mdr.label as label_mdr,      
      input(t1.ordinal, best.) as order,
      input(mdr.length, best.) as length,
      mdr.format as displayformat,
      input(mdr.significant_digits, best.) as significantdigits,
      substr(t1.simpleDatatype, 1, 1) as type length=1,
      mdr.data_type as xmldatatype length=18,

      mdr.codelist as xmlcodelist_,
      scan(t3.href, -1, "/") as codelist_ccode,

      t1.core,
      mdr.mandatory length=3,
      put(mdr.origin, $origtyp.) as origintype,
      t1.role,
      mdr.role as role_mdr
  /*
      t1.simpleDatatype,
      t1.describedValuedomain,
      t2.valueList,
      t1.description,
  */
    from work.root root
      inner join work.datasetvariables t1
    on (root.ordinal_root = t1.ordinal_root)
      left join work.valuelists t2
    on (t1.ordinal_datasetVariables = t2.ordinal_datasetVariables)
      left join clib._links_codelist t3
    on (t1.ordinal_datasetVariables = t3.ordinal__links)
      left join work.mdr_variables_&clib_domain mdr
    on (root.name = mdr.dataset and t1.name = mdr.variable)
    order by order;
    ;
  quit;

  data metadata.source_tables(label="Source Table Metadata");
    set metadata.source_tables 
        work.source_tables(in=intable);
    sasref="SRCDATA";
    studyversion="&_cstStudyVersion";
    standard="&_cstTrgStandard";
    standardversion="&_cstTrgStandardVersion";
    cdiscstandard = "SDTMIG";
    cdiscstandardversion="&_cstTrgStandardVersion";
    date=put(date(), e8601da10.);
    if intable then order=&order;
    %if %sysevalf(%superq(suppdomain)=, boolean)=0 %then %do;
      if table = "SUPP&suppdomain" then label = tranwrd(label, "[domain name]", "&suppdomain");
    %end;

  run;

  data work.source_columns_nsv_&clib_domain;
    set work.source_columns_nsv(
      where=(domain=upcase("&clib_domain"))
    );
  run;
  
  data work.source_columns;
    set work.source_columns_template
        work.source_columns
        work.source_columns_nsv_&clib_domain(
          rename=(variable = column domain=table)
          in=nsv
        );
    sasref="SRCDATA";
    studyversion="&_cstStudyVersion";
    standard="&_cstTrgStandard";
    standardversion="&_cstTrgStandardVersion";
    if origintype="CRF" then origintype="Collected";
    originsource = put(origintype, $origsrc.);

    if column="RSCAT" and codelist_ccode = "C124298" then delete; /* HARD UPDATE */
    
    if nsv then do;
      type = substr(simpleDatatype, 1, 1);
      isNonStandard = "Yes";
      order = _n_;
      if missing(xmlcodelist) then xmlcodelist = xmlcodelist_; 
    end;  
  run;
   
  data metadata.source_columns(
      label="Source Column Metadata"
    );
    set metadata.source_columns 
        work.source_columns; 
  run;

  libname clib clear;

%mend add_domain;

%add_domain(clib_domain=rs, order=1);
%add_domain(clib_domain=tr, order=2);
%add_domain(clib_domain=tu, order=3);
%*add_domain(clib_domain=suppqual, order=4, suppdomain=TU);

proc print data=metadata.source_columns;
  var table column xmlcodelist_ codelist_ccode;
  where ((missing(xmlcodelist_) or missing(codelist_ccode)) and not (missing(xmlcodelist_) and missing(codelist_ccode)));
run;
