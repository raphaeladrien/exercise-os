SET @column_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE table_schema = 'company' AND table_name = 'employees' AND column_name = 'ACTUAL_SALARY');

SET @sql = IF(@column_exists = 0, 
              'ALTER TABLE employees ADD COLUMN ACTUAL_SALARY DECIMAL(10,2) GENERATED ALWAYS AS (SALARY + (SALARY * COMMISSION_PCT)) STORED', 
              'SELECT "Column already exists"');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
