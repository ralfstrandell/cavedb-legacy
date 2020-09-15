# cavedb-legacy

This repository contains shell scripts to generate activityJSON which is an extension to geoJSON. Source data is in text format. The scripts are written for Bourne Again Shell (bash).

The source database itself comprises a number of fixed format UTF8 text files without BOM. 14 lines per record. This data format (text file) was chosen as it is an efficient format for typing. 900 records or 13100 lines of data had to be entered mostly by typing. Almost all of it was on paper in a difficult-to-convert format. Entering the data using a web form (fields, mouse clicks) was totally out of the question: too much work. Entering the data directly into a JSON format still in development would have been even more problematic. Developing an OCR-based workflow was considered but it would have offered a partial relief only in exchange for lots of development work.

Various versions of the text data exist. Hence more than one set of scripts.

These files support e.g. https://luolaseura.fi/luolakanta/kartta.html
which uses the psgeo library and activityJSON, both of which are in development.
