%macro get_domain(domain=, version=);

  filename jsonf "&project_folder/&subfolder/json/sdtmig_&version.-%lowcase(&domain).json";

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
  * libname jsontmp "%sysfunc(pathname(work))/jsontmp";
  libname jsontmp "&project_folder/&subfolder/data/%lowcase(&domain)";

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

libname meta "&project_folder/test/metadata";


%let _cstStandard=CDISC-DEFINE-XML;
%let _cstStandardVersion=2.1; 
%let _cstTrgStandard=%str(CDISC-SDTM);
%let _cstTrgStandardVersion=3.3;
%let _cstCDISCStandardVersion = %sysfunc(translate(&_cstTrgStandardVersion, %str(-), %str(.)));
%let _cstStudyVersion=%str(MDV.CDISC01.SDTMIG.3.3.SDTM.1.7);


%let excel_file=&project_folder/test/mdr_metadata.xlsx;
%ReadExcel(file=&excel_file, range=Datasets$, dsout=mdr_datasets);
%ReadExcel(file=&excel_file, range=Variables$, dsout=mdr_variables);

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=study,_cstOutputDS=meta.source_study
  );
proc sql;
  insert into meta.source_study(sasref, fileoid, studyoid, originator, context,
                                 studyname, studydescription, protocolname, comment,
                                 metadataversionname, metadataversiondescription,
                                 studyversion, standard, standardversion)
    values("SRCDATA", "www.cdisc.org/StudyCDISC01_1/1/Define-XML_2.1.0", "STDY.www.cdisc.org.CDISC01_1", "", "Submission",
           "CDISC01", "CDISC Test Study", "CDISC01", "",
           "Study CDISC01_1, Data Definitions V-1", "Data Definitions for CDISC01-01 SDTM datasets",
           "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
  ;
  quit;
run;

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=standard,_cstOutputDS=meta.source_standards
  );
proc sql;
  insert into meta.source_standards(sasref, cdiscstandard, cdiscstandardversion, type, publishingset, order, status, comment,
                                    studyversion, standard, standardversion)
    values("SRCDATA", "SDTMIG", "&_cstTrgStandardVersion", "IG", "", 1, "Final", "", "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
    values("SRCDATA", "CDISC/NCI", "2023-06-30", "CT", "SDTM", 2, "Final", "", "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
    values("SRCDATA", "CDISC/NCI", "2022-12-16", "CT", "DEFINE-XML", 3, "Final", "", "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
  ;
  quit;
run;

%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=table,_cstOutputDS=meta.source_tables
  );
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=column,_cstOutputDS=meta.source_columns
  );
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=value,_cstOutputDS=meta.source_values
  );
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=codelist,_cstOutputDS=meta.source_codelists
  );
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=document,_cstOutputDS=meta.source_documents
  );



%macro add_domain(clib_domain, order);

  %get_domain(domain=&clib_domain, version=&_cstCDISCStandardVersion); 

  libname clib "&project_folder/test/data/&clib_domain";

  data mdr_datasets_&clib_domain(keep=dataset class key_variables repeating reference_data);
    set mdr_datasets(where=(dataset=upcase("&clib_domain")));
  run;

  data mdr_variables_&clib_domain(keep=dataset variable data_type length significant_digits format mandatory codelist origin);
    set mdr_variables(where=(dataset=upcase("&clib_domain")));
  run;

  data work.valuelists (keep=ordinal_datasetVariables _valueList rename=(_valuelist=valuelist));
    length _valueList $200;
    set clib.datasetvariables_valuelist;
    array c{*} valueList:;
    _valueList = c[1];
    x = dim(c); put x=;
    do i = 2 to dim(c);
      _valueList = cats(";", _valueList, c[i]);
    end;
  run;

  proc sql;
    create table source_tables as select 
      root.name as table,
      root.name as domain,
      root.label as label,
      /* root.description as table_description, */
      root.datasetStructure as structure,
      translate(mdr.key_variables, " ", ",") as keys length=200,
      mdr.class length=40,
      cats(lowcase(name), ".xpt") as xmlpath,
      cats(lowcase(name), ".xpt") as xmltitle,
      "Tabulation" as purpose,
      mdr.repeating length=3,
      mdr.reference_data as isReferenceData length=3
    from clib.root root
      left join work.mdr_datasets_&clib_domain mdr
    on (root.name = mdr.dataset)  
    ;
    create table source_columns as select 
      root.name as table,
      t1.name as column,
      t1.label,
      input(t1.ordinal, best.) as order,
      input(mdr.length, best.) as length,
      mdr.format as displayformat,
      input(mdr.significant_digits, best.) as significantdigits,
      mdr.data_type as xmldatatype length=18,

      mdr.codelist as xmlcodelist_,
      scan(t3.href, -1, "/") as codelist_ccode,

      t1.core,
      mdr.mandatory length=3,
      put(mdr.origin, $origtyp.) as origintype,
      t1.role
  /*
      t1.simpleDatatype,
      t1.describedValuedomain,
      t2.valueList,
      t1.description,
  */
    from clib.root root
      inner join clib.datasetvariables t1 
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

  data meta.source_tables;
    set meta.source_tables source_tables(in=intable);
    sasref="SRCDATA";
    studyversion="&_cstStudyVersion";
    standard="&_cstTrgStandard";
    standardversion="&_cstTrgStandardVersion";
    cdiscstandard = "SDTMIG";
    cdiscstandardversion="3.2";
    if intable then order=&order;
  run;  

  data meta.source_columns;
    set meta.source_columns source_columns;
    sasref="SRCDATA";
    studyversion="&_cstStudyVersion";
    standard="&_cstTrgStandard";
    standardversion="&_cstTrgStandardVersion";
    if origintype="CRF" then origintype="Collected";
    originsource = put(origintype, $origsrc.);
    
    if column="RSCAT" and codelist_ccode = "C124298" then delete; /* HARD UPDATE */
  run;  

  libname clib clear;

%mend add_domain;

%add_domain(rs, 1);
%add_domain(tr, 2);
%add_domain(tu, 3);

proc print data=meta.source_columns;
  var table column xmlcodelist_ codelist_ccode;
  where ((missing(xmlcodelist_) or missing(codelist_ccode)) and not (missing(xmlcodelist_) and missing(codelist_ccode)));
run;  