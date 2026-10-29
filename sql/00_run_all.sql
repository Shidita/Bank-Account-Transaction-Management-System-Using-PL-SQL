-- Runs everything in the right order (SQL*Plus, or "Run Script" / F5 in SQL Developer).
-- Start it from the project folder:   @sql/00_run_all.sql
-- Use 07_reset.sql first if the objects already exist.
SET SERVEROUTPUT ON;
@sql/01_create_tables.sql
@sql/02_sample_data.sql
@sql/03_package.sql
@sql/04_triggers.sql
@sql/05_views_reports.sql
@sql/06_demo_execution.sql
