curl -s --user frank.keenan:wltncrs40 "https://dws-dps.idm.fr/api/v1/projects/EN_MERGEDDICT_A2361_00001/entries/export/allInternalAttributesAndAdditionalMetadata"  | perl oneline.pl | perl lose_suppressed.pl > /data/data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps.xml 
cat /data/data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps.xml | perl get_ode.pl > /data/data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps_ode.xml
cat /data/data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps.xml | perl get_noad.pl > /data/data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps_noad.xml
perl check_internal_xrefs.pl -r "NOAD_fail_xrefs.xlsx" dps_noad.xml
perl check_internal_xrefs.pl -r "ODE_fail_xrefs.xlsx" dps_ode.xml

