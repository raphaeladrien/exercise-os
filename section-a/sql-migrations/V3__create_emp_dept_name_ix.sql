SET @table_schema = 'company';
SET @table_name = 'employees';
SET @index_name = 'EMP_DEPT_NAME_IX';
SET @sql_query = 'CREATE INDEX EMP_DEPT_NAME_IX ON employees (DEPARTMENT_ID, FIRST_NAME, LAST_NAME)';

SET @index_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE table_schema = @table_schema AND table_name = @table_name AND index_name = @index_name);

SET @sql = IF(@index_exists = 0, 
              @sql_query, 
              'SELECT "Column already exists"');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
