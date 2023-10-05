%global project_folder;
%let project_folder=/_CDISC/COSMoS/CDISC_2023_US;

%* Generic configuration;
%include "&project_folder/programs/config.sas";

%let _cstStandard=CDISC-DEFINE-XML;
%let _cstStandardVersion=2.1;
%let _cstTrgStandard=%str(CDISC-SDTM);
%let _cstTrgStandardVersion=3.3;
%let _cstStudyVersion=%str(MDV.CDISC01.SDTMIG.3.3.SDTM.1.7);

*** Create study meta data *;
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=study,_cstOutputDS=work.source_study
  );
proc sql;
  insert into work.source_study(sasref, fileoid, studyoid, originator, context,
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

data metadata.source_study;
  set work.source_study;
  comment="This Define-XML document is based on basic RS, TR and TU dataset and column metadata.
Value level metadata (VLM) and codelists were programmatically created by
extracting metadata from CDISC SDTM Dataset Specializations and the CDISC Library.";
run;


*** Create standards meta data *;
%cst_createdsfromtemplate(
  _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=&_cstStandardVersion,
  _cstType=studymetadata,_cstSubType=standard,_cstOutputDS=work.source_standards
  );
proc sql;
  insert into work.source_standards(sasref, cdiscstandard, cdiscstandardversion, type, publishingset, order, status, comment,
                                    studyversion, standard, standardversion)
    values("SRCDATA", "SDTMIG", "&_cstTrgStandardVersion", "IG", "", 1, "Final", "", "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
    values("SRCDATA", "CDISC/NCI", "2023-09-29", "CT", "SDTM", 2, "Final", "", "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
    values("SRCDATA", "CDISC/NCI", "2022-12-16", "CT", "DEFINE-XML", 3, "Final", "", "&_cstStudyVersion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
  ;
  quit;
run;

data metadata.source_standards;
  set work.source_standards;
run;
