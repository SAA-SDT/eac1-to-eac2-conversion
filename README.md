# eac1-to-eac2-conversion
Transformation files to convert EAC 1.x valid records into EAC 2.0 records

Requirements:  XSLT 3 processor, such as Saxon 9 or 10 HE (e.g.https://github.com/SAA-SDT/eac-cpf-schema/tree/development/vendor/SaxonHE10-1J)

Steps:

1. Take any valid EAC 1.x file;
1. Convert using the "eac1-to-eac2.xml" file;
1. Check the validity of the output.

A few sample files are provided as an example. All of the files localted in sample-files/input are valid EAC 1.0 files. The corresponding files in sameple-files/output have been converted to EAC 2.0 using the provided transformation file.



