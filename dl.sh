curl -s --user frank.keenan:wltncrs40 "https://dws-dps.idm.fr/api/v1/projects/EN_MERGEDDICT_A2361_00001/entries/export/allInternalAttributesAndAdditionalMetadata"  | perl lose_suppressed.pl > /data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps.xml 
cat /data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps.xml | perl get_ode.pl > /data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps_ode.xml
cat /data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps.xml | perl get_noad.pl > /data_c/Projects/OL/EN_MERGEDDICT_A2361_00001/dps_noad.xml
